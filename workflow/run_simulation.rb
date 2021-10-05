# frozen_string_literal: true

start_time = Time.now

require 'fileutils'
require 'optparse'
require 'pathname'
require 'csv'
require_relative '../hpxml-measures/HPXMLtoOpenStudio/resources/meta_measure'
require_relative '../hpxml-measures/HPXMLtoOpenStudio/resources/version'
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

def get_rundir(output_dir, design)
  return File.join(output_dir, design.gsub(' ', ''))
end

def get_output_hpxml_path(resultsdir, rundir)
  return File.join(resultsdir, File.basename(rundir) + '.xml')
end

def run_design(basedir, rundir, design, resultsdir, json, debug, skip_simulation)
  measures_dir = File.join(basedir, '..')
  output_hpxml_path = get_output_hpxml_path(resultsdir, rundir)

  measures = {}

  # Add HEScore measure to workflow
  measure_subdir = 'rulesets/HEScoreRuleset'
  args = {}
  args['json_path'] = json
  args['hpxml_output_path'] = output_hpxml_path
  update_args_hash(measures, measure_subdir, args)

  if not skip_simulation
    # Add HPXML translator measure to workflow
    measure_subdir = 'hpxml-measures/HPXMLtoOpenStudio'
    args = {}
    args['hpxml_path'] = output_hpxml_path
    args['output_dir'] = rundir
    args['debug'] = debug
    args['add_component_loads'] = false
    args['skip_validation'] = !debug
    update_args_hash(measures, measure_subdir, args)

    # Add reporting measure to workflow
    measure_subdir = 'hpxml-measures/ReportSimulationOutput'
    args = {}
    args['timeseries_frequency'] = 'monthly'
    args['include_timeseries_fuel_consumptions'] = false
    args['include_timeseries_end_use_consumptions'] = true
    args['include_timeseries_hot_water_uses'] = true
    args['include_timeseries_total_loads'] = false
    args['include_timeseries_component_loads'] = false
    args['include_timeseries_zone_temperatures'] = false
    args['include_timeseries_airflows'] = false
    args['include_timeseries_weather'] = false
    update_args_hash(measures, measure_subdir, args)
  end

  results = run_hpxml_workflow(rundir, measures, measures_dir,
                               debug: debug, run_measures_only: skip_simulation)

  return results[:success] if skip_simulation
  return results[:success] unless results[:success]

  # Gather monthly outputs for results JSON
  timeseries_csv_path = File.join(rundir, 'results_timeseries.csv')
  return false unless File.exist? timeseries_csv_path

  units_map = get_units_map()
  output_map = get_output_map()
  outputs = {}
  output_map.each do |ep_output, hes_output|
    outputs[hes_output] = []
  end
  row_index = {}
  units = nil
  CSV.foreach(timeseries_csv_path).with_index do |row, row_num|
    if row_num == 0 # Header
      output_map.each do |ep_output, hes_output|
        row_index[ep_output] = row.index(ep_output)
      end
    elsif row_num == 1 # Units
      units = row
    else # Data
      # Init for month
      outputs.keys.each do |k|
        outputs[k] << 0.0
      end
      # Add values
      output_map.each do |ep_output, hes_output|
        col = row_index[ep_output]
        next if col.nil?

        outputs[hes_output][-1] += UnitConversions.convert(Float(row[col]), units[col], units_map[hes_output[1]].gsub('gallons', 'gal')).abs
      end
      # Make sure there aren't any end uses with positive values that aren't mapped to HES
      row.each_with_index do |val, col|
        next if col.nil?
        next if col == 0 # Skip time column
        next if row_index.values.include? col

        fail "Missed value (#{val}) in row=#{row_num}, col=#{col}." if Float(val) > 0
      end
    end
  end

  # Write results to JSON
  data = { 'end_use' => [] }
  outputs.each do |hes_key, values|
    hes_end_use, hes_resource_type = hes_key
    to_units = units_map[hes_resource_type]
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

  require 'json'
  File.open(File.join(resultsdir, 'results.json'), 'w') do |f|
    f.write(JSON.pretty_generate(data))
  end

  return results[:success]
end

def download_epws
  require_relative '../hpxml-measures/HPXMLtoOpenStudio/resources/util'

  weather_dir = File.join(File.dirname(__FILE__), '..', 'weather')

  num_epws_expected = 1011
  num_epws_actual = Dir[File.join(weather_dir, '*.epw')].count
  num_cache_expcted = num_epws_expected
  num_cache_actual = Dir[File.join(weather_dir, '*-cache.csv')].count
  if (num_epws_actual == num_epws_expected) && (num_cache_actual == num_cache_expcted)
    puts 'Weather directory is already up-to-date.'
    puts "#{num_epws_actual} weather files are available in the weather directory."
    puts 'Completed.'
    exit!
  end

  require 'tempfile'
  tmpfile = Tempfile.new('epw')

  UrlResolver.fetch('https://data.nrel.gov/system/files/128/tmy3s-cache-csv.zip', tmpfile)

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
  opts.banner = "Usage: #{File.basename(__FILE__)} -j building.xml\n e.g., #{File.basename(__FILE__)} -j regression_files/Base.json\n"

  opts.on('-j', '--json <FILE>', 'JSON file') do |t|
    options[:json] = t
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

if not options[:json]
  fail "JSON argument is required. Call #{File.basename(__FILE__)} -h for usage."
end

unless (Pathname.new options[:json]).absolute?
  options[:json] = File.expand_path(options[:json])
end
unless File.exist?(options[:json]) && options[:json].downcase.end_with?('.json')
  fail "'#{options[:json]}' does not exist or is not an .json file."
end

# Check for correct versions of OS
Version.check_openstudio_version()

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
puts "JSON: #{options[:json]}"
design = 'HEScoreDesign'
rundir = get_rundir(options[:output_dir], design)

success = run_design(basedir, rundir, design, resultsdir, options[:json], options[:debug], options[:skip_simulation])

if not success
  exit! 1
end

puts "Completed in #{(Time.now - start_time).round(1)} seconds."
