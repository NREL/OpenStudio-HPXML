start_time = Time.now

require 'fileutils'
require 'optparse'
require 'pathname'
require_relative '../hpxml-measures/HPXMLtoOpenStudio/resources/meta_measure'
require_relative '../hpxml-measures/HPXMLtoOpenStudio/resources/unit_conversions'
require_relative 'hescore_lib'

basedir = File.expand_path(File.dirname(__FILE__))

def rm_path(path)
  if Dir.exist?(path)
    FileUtils.rm_r(path)
  end
  while true
    break if not Dir.exist?(path)

    sleep(0.01)
  end
end

def get_designdir(output_dir, design)
  return File.join(output_dir, design.gsub(' ', ''))
end

def get_output_hpxml_path(resultsdir, designdir)
  return File.join(resultsdir, File.basename(designdir) + '.xml')
end

def run_design(basedir, designdir, design, resultsdir, hpxml, debug, skip_simulation)
  puts 'Creating input...'
  create_idf(design, basedir, designdir, resultsdir, hpxml, debug, skip_simulation)

  return if skip_simulation

  puts 'Running simulation...'
  run_energyplus(design, designdir)

  # Create output
  create_output(designdir, resultsdir)
end

def create_idf(design, basedir, designdir, resultsdir, hpxml, debug, skip_simulation)
  Dir.mkdir(designdir)

  OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Fatal)

  output_hpxml_path = get_output_hpxml_path(resultsdir, designdir)

  model = OpenStudio::Model::Model.new
  runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
  measures_dir = File.join(basedir, '..')

  measures = {}

  # Add HEScore measure to workflow
  measure_subdir = 'rulesets/HEScoreRuleset'
  args = {}
  args['hpxml_path'] = hpxml
  args['hpxml_output_path'] = output_hpxml_path
  update_args_hash(measures, measure_subdir, args)

  if not skip_simulation
    # Add HPXML translator measure to workflow
    measure_subdir = 'hpxml-measures/HPXMLtoOpenStudio'
    args = {}
    args['hpxml_path'] = output_hpxml_path
    args['weather_dir'] = File.absolute_path(File.join(basedir, '..', 'weather'))
    args['epw_output_path'] = File.join(designdir, 'in.epw')
    if debug
      args['osm_output_path'] = File.join(designdir, 'in.osm')
    end
    update_args_hash(measures, measure_subdir, args)
  end

  # Apply measures
  success = apply_measures(measures_dir, measures, runner, model)

  # Report warnings/errors
  File.open(File.join(designdir, 'run.log'), 'w') do |f|
    if debug
      runner.result.stepInfo.each do |s|
        f << "Info: #{s}\n"
      end
    end
    runner.result.stepWarnings.each do |s|
      f << "Warning: #{s}\n"
    end
    runner.result.stepErrors.each do |s|
      f << "Error: #{s}\n"
    end
  end

  return if skip_simulation

  if not success
    fail "Simulation unsuccessful for #{design}."
  end

  # Add monthly output requests
  get_output_meter_requests.each do |hes_key, ep_meters|
    ep_meters.each do |ep_meter|
      output_meter = OpenStudio::Model::OutputMeter.new(model)
      output_meter.setName(ep_meter)
      output_meter.setReportingFrequency('monthly')
    end
  end

  # Add monthly hot water output request
  outputVariable = OpenStudio::Model::OutputVariable.new('Water Use Equipment Hot Water Volume', model)
  outputVariable.setReportingFrequency('monthly')
  outputVariable.setKeyValue('*')

  # Translate model to IDF
  forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
  forward_translator.setExcludeLCCObjects(true)
  model_idf = forward_translator.translateModel(model)

  # Report warnings/errors
  File.open(File.join(designdir, 'run.log'), 'a') do |f|
    forward_translator.warnings.each do |s|
      f << "FT Warning: #{s.logMessage}\n"
    end
    forward_translator.errors.each do |s|
      f << "FT Error: #{s.logMessage}\n"
    end
  end

  # Write IDF to file
  File.open(File.join(designdir, 'in.idf'), 'w') { |f| f << model_idf.to_s }
end

def run_energyplus(design, rundir)
  # getEnergyPlusDirectory can be unreliable, using getOpenStudioCLI instead
  ep_path = File.absolute_path(File.join(OpenStudio.getOpenStudioCLI.to_s, '..', '..', 'EnergyPlus', 'energyplus'))
  command = "cd #{rundir} && #{ep_path} -w in.epw in.idf > stdout-energyplus"
  system(command, err: File::NULL)
end

def create_output(designdir, resultsdir)
  puts 'Compiling outputs...'
  sql_path = File.join(designdir, 'eplusout.sql')
  if not File.exist?(sql_path)
    fail 'Processing output unsuccessful.'
  end

  sqlFile = OpenStudio::SqlFile.new(sql_path, false)

  # Initialize
  results = {}
  results_gj = {}
  get_output_meter_requests.each do |hes_key, ep_meters|
    results[hes_key] = [0.0] * 12
    results_gj[hes_key] = [0.0] * 12
  end

  # Retrieve outputs
  get_output_meter_requests.each do |hes_key, ep_meters|
    hes_end_use, hes_resource_type = hes_key
    to_units = get_fuel_site_units(hes_resource_type)

    ep_meters.each do |ep_meter|
      query = "SELECT VariableValue FROM ReportMeterData WHERE ReportMeterDataDictionaryIndex=(SELECT ReportMeterDataDictionaryIndex FROM ReportMeterDataDictionary WHERE VariableName='#{ep_meter}' AND ReportingFrequency='Monthly' AND VariableUnits='J') ORDER BY TimeIndex"
      sql_result = sqlFile.execAndReturnVectorOfDouble(query)
      next unless sql_result.is_initialized

      sql_result = sql_result.get
      for i in 1..12
        next if sql_result[i - 1].nil?

        result = UnitConversions.convert(sql_result[i - 1], 'J', to_units) # convert from J to site energy units
        result_gj = sql_result[i - 1] / 1000000000.0 # convert from J to GJ

        results[hes_key][i - 1] += result
        results_gj[hes_key][i - 1] += result_gj

        next unless hes_end_use == 'large_appliance'

        # Subtract out from small appliance end use
        results[['small_appliance', hes_resource_type]][i - 1] -= result
        results_gj[['small_appliance', hes_resource_type]][i - 1] -= result_gj
      end
    end
  end

  # Subtract out disaggregated heating/cooling fan and pump energy from hot water electricity end use
  hes_resource_type = 'electric'
  to_units = get_fuel_site_units(hes_resource_type)
  hes_end_uses = { 'heating' => [Constants.ObjectNameFanPumpDisaggregatePrimaryHeat, Constants.ObjectNameFanPumpDisaggregateBackupHeat],
                   'cooling' => [Constants.ObjectNameFanPumpDisaggregateCool] }
  hes_end_uses.each do |hes_end_use, var_names|
    for i in 1..12
      total = 0.0
      var_names.each do |var_name|
        query = "SELECT SUM(VariableValue) FROM ReportVariableData WHERE ReportVariableDataDictionaryIndex IN (SELECT ReportVariableDataDictionaryIndex FROM ReportVariableDataDictionary WHERE VariableName LIKE '%#{var_name}' AND ReportingFrequency='Monthly' AND VariableUnits='J') AND TimeIndex='#{i}'"
        sql_result = sqlFile.execAndReturnFirstDouble(query)
        next unless sql_result.is_initialized

        total += sql_result.get
      end

      result = UnitConversions.convert(total, 'J', to_units) # convert from J to site energy units
      result_gj = total / 1000000000.0 # convert from J to GJ

      # Add to heating/cooling end use
      results[[hes_end_use, hes_resource_type]][i - 1] += result
      results_gj[[hes_end_use, hes_resource_type]][i - 1] += result_gj

      # Subtract from hot water end use
      results[['hot_water', hes_resource_type]][i - 1] -= result
      results_gj[['hot_water', hes_resource_type]][i - 1] -= result_gj
    end
  end

  # Add hot water volume output
  hes_end_use = 'hot_water'
  hes_resource_type = 'hot_water'
  to_units = get_fuel_site_units(hes_resource_type)
  for i in 1..12
    query = "SELECT SUM(VariableValue) FROM ReportVariableData WHERE ReportVariableDataDictionaryIndex IN (SELECT ReportVariableDataDictionaryIndex FROM ReportVariableDataDictionary WHERE VariableName='Water Use Equipment Hot Water Volume' AND ReportingFrequency='Monthly' AND VariableUnits='m3') AND TimeIndex='#{i}'"
    sql_result = sqlFile.execAndReturnFirstDouble(query)
    next unless sql_result.is_initialized

    sql_result = sql_result.get

    result = UnitConversions.convert(sql_result, 'm^3', 'gal')

    results[[hes_end_use, hes_resource_type]][i - 1] = result
  end

  # Error-checking
  net_energy_gj = sqlFile.netSiteEnergy.get - sqlFile.districtHeatingHeating.get - sqlFile.districtCoolingCooling.get
  sum_energy_gj = 0
  results_gj.each do |hes_key, values|
    hes_end_use, hes_resource_type = hes_key
    if hes_end_use == 'generation'
      sum_energy_gj -= values.inject(0, :+)
    else
      sum_energy_gj += values.inject(0, :+)
    end
  end
  if (net_energy_gj - sum_energy_gj).abs > 0.1
    fail "Sum of retrieved outputs #{sum_energy_gj} does not match total net value #{net_energy_gj}."
  end

  sqlFile.close

  # Write results to JSON
  data = { 'end_use' => [] }
  results.each do |hes_key, values|
    hes_end_use, hes_resource_type = hes_key
    to_units = get_fuel_site_units(hes_resource_type)
    annual_value = values.inject(0, :+)
    next if annual_value <= 0.01

    values.each_with_index do |value, idx|
      end_use = { 'quantity' => value,
                  'period_type' => 'month',
                  'period_number' => (idx + 1).to_s,
                  'end_use' => hes_end_use,
                  'resource_type' => hes_resource_type,
                  'units' => to_units }
      data['end_use'] << end_use
    end
  end

  File.open(File.join(resultsdir, 'results.json'), 'w') do |f|
    f.write(data.to_s.gsub('=>', ':')) # Much faster than requiring JSON to use pretty_generate
  end
end

def download_epws
  weather_dir = File.join(File.dirname(__FILE__), '..', 'weather')

  num_epws_expected = File.readlines(File.join(weather_dir, 'data.csv')).size - 1
  num_epws_actual = Dir[File.join(weather_dir, '*.epw')].count
  num_cache_expcted = num_epws_expected
  num_cache_actual = Dir[File.join(weather_dir, '*-cache.csv')].count
  if (num_epws_actual == num_epws_expected) && (num_cache_actual == num_cache_expcted)
    puts 'Weather directory is already up-to-date.'
    puts "#{num_epws_actual} weather files are available in the weather directory."
    puts 'Completed.'
    exit!
  end

  require 'net/http'
  require 'tempfile'

  tmpfile = Tempfile.new('epw')

  url = URI.parse('https://data.nrel.gov/files/128/tmy3s-cache-csv.zip')
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  params = { 'User-Agent' => 'curl/7.43.0', 'Accept-Encoding' => 'identity' }
  request = Net::HTTP::Get.new(url.path, params)
  request.content_type = 'application/zip, application/octet-stream'

  http.request request do |response|
    total = response.header['Content-Length'].to_i
    if total == 0
      fail 'Did not successfully download zip file.'
    end

    size = 0
    progress = 0
    open tmpfile, 'wb' do |io|
      response.read_body do |chunk|
        io.write chunk
        size += chunk.size
        new_progress = (size * 100) / total
        unless new_progress == progress
          puts 'Downloading %s (%3d%%) ' % [url.path, new_progress]
        end
        progress = new_progress
      end
    end
  end

  puts 'Extracting weather files...'
  unzip_file = OpenStudio::UnzipFile.new(tmpfile.path.to_s)
  unzip_file.extractAllFiles(OpenStudio::toPath(weather_dir))

  num_epws_actual = Dir[File.join(weather_dir, '*.epw')].count
  puts "#{num_epws_actual} weather files are available in the weather directory."
  puts 'Completed.'
  exit!
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} -x building.xml\n e.g., #{File.basename(__FILE__)} -x sample_files/valid.xml\n"

  opts.on('-x', '--xml <FILE>', 'HPXML file') do |t|
    options[:hpxml] = t
  end

  opts.on('-o', '--output-dir <DIR>', 'Output directory') do |t|
    options[:output_dir] = t
  end

  opts.on('-w', '--download-weather', 'Downloads all weather files') do |t|
    options[:epws] = t
  end

  options[:skip_simulation] = false
  opts.on('--skip-simulation', 'Skip the EnergyPlus simulation') do |t|
    options[:skip_simulation] = true
  end

  options[:debug] = false
  opts.on('-d', '--debug') do |t|
    options[:debug] = true
  end

  opts.on_tail('-h', '--help', 'Display help') do
    puts opts
    exit!
  end
end.parse!

if options[:epws]
  download_epws
end

if not options[:hpxml]
  fail "HPXML argument is required. Call #{File.basename(__FILE__)} -h for usage."
end

unless (Pathname.new options[:hpxml]).absolute?
  options[:hpxml] = File.expand_path(options[:hpxml])
end
unless File.exist?(options[:hpxml]) && options[:hpxml].downcase.end_with?('.xml')
  fail "'#{options[:hpxml]}' does not exist or is not an .xml file."
end

# Check for correct versions of OS
os_version = '2.9.1'
if OpenStudio.openStudioVersion != os_version
  fail "OpenStudio version #{os_version} is required."
end

if options[:output_dir].nil?
  options[:output_dir] = basedir # default
end
options[:output_dir] = File.expand_path(options[:output_dir])

unless Dir.exist?(options[:output_dir])
  FileUtils.mkdir_p(options[:output_dir])
end

# Create results dir
resultsdir = File.join(options[:output_dir], 'results')
rm_path(resultsdir)
Dir.mkdir(resultsdir)

# Run design
puts "HPXML: #{options[:hpxml]}"
design = 'HEScoreDesign'
designdir = get_designdir(options[:output_dir], design)
rm_path(designdir)
rundir = run_design(basedir, designdir, design, resultsdir, options[:hpxml], options[:debug], options[:skip_simulation])

puts "Completed in #{(Time.now - start_time).round(1)} seconds."
