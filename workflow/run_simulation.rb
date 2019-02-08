start_time = Time.now

require 'optparse'
require 'json'
require 'pathname'
require_relative "../measures/HPXMLtoOpenStudio/resources/meta_measure"
require_relative "../measures/HPXMLtoOpenStudio/resources/unit_conversions"

basedir = File.expand_path(File.dirname(__FILE__))

def rm_path(path)
  if Dir.exists?(path)
    FileUtils.rm_r(path)
  end
  while true
    break if not Dir.exists?(path)

    sleep(0.01)
  end
end

def get_designdir(basedir, design)
  return File.join(basedir, design.gsub(' ', ''))
end

def get_output_hpxml_path(resultsdir, designdir)
  return File.join(resultsdir, File.basename(designdir) + ".xml")
end

def run_design(designdir, design, resultsdir, hpxml, debug, skip_validation)
  puts "Creating input..."
  create_idf(design, designdir, resultsdir, hpxml, debug, skip_validation)

  puts "Running simulation..."
  run_energyplus(design, designdir)
end

def get_fuel_site_units(hes_resource_type)
  return { :electric => 'kWh',
           :natural_gas => 'kBtu',
           :lpg => 'kBtu',
           :fuel_oil => 'kBtu' }[hes_resource_type]
end

def get_output_meter_requests
  # Mapping between HEScore output [end_use, resource_type] and a list of E+ output meters
  # TODO: Add hot water and cold water resource_types? Anything else?
  return { [:heating, :electric] => ["Heating:Electricity"],
           [:heating, :natural_gas] => ['Heating:Gas'],
           [:heating, :lpg] => ['Heating:Propane'],
           [:heating, :fuel_oil] => ['Heating:FuelOil#1'],

           [:cooling, :electric] => ["Cooling:Electricity"],
           [:cooling, :natural_gas] => ['Cooling:Gas'],
           [:cooling, :lpg] => ["Cooling:Propane"],
           [:cooling, :fuel_oil] => ['Cooling:FuelOil#1'],

           [:hot_water, :electric] => ["WaterSystems:Electricity"],
           [:hot_water, :natural_gas] => ["WaterSystems:Gas"],
           [:hot_water, :lpg] => ["WaterSystems:Propane"],
           [:hot_water, :fuel_oil] => ["WaterSystems:FuelOil#1"],

           # Note: Large appliances include Refrigerator, Dishwasher, Clothes Washer, and Clothes Dryer per LBNL
           [:large_appliance, :electric] => ["#{Constants.ObjectNameRefrigerator}:InteriorEquipment:Electricity",
                                             "#{Constants.ObjectNameDishwasher}:InteriorEquipment:Electricity",
                                             "#{Constants.ObjectNameClothesWasher}:InteriorEquipment:Electricity",
                                             "#{Constants.ObjectNameClothesDryer(Constants.FuelTypeElectric)}:InteriorEquipment:Electricity"],
           [:large_appliance, :natural_gas] => ["#{Constants.ObjectNameClothesDryer(Constants.FuelTypeGas)}:InteriorEquipment:Gas"],
           [:large_appliance, :lpg] => ["#{Constants.ObjectNameClothesDryer(Constants.FuelTypePropane)}:InteriorEquipment:Propane",
                                        "#{Constants.ObjectNameCookingRange(Constants.FuelTypePropane)}:InteriorEquipment:Propane"],
           [:large_appliance, :fuel_oil] => ["#{Constants.ObjectNameClothesDryer(Constants.FuelTypeOil)}:InteriorEquipment:FuelOil#1"],

           # Note: large appliances are subtracted out from small appliances later
           [:small_appliance, :electric] => ["InteriorEquipment:Electricity"],
           [:small_appliance, :natural_gas] => ["InteriorEquipment:Gas"],
           [:small_appliance, :lpg] => ["InteriorEquipment:Propane"],
           [:small_appliance, :fuel_oil] => ["InteriorEquipment:FuelOil#1"],

           [:lighting, :electric] => ["InteriorLights:Electricity",
                                      "ExteriorLights:Electricity"],
           [:lighting, :natural_gas] => ["InteriorLights:Gas"],
           [:lighting, :lpg] => ["InteriorLights:Propane"],
           [:lighting, :fuel_oil] => ["InteriorLights:FuelOil#1"],

           [:circulation, :electric] => ["Fans:Electricity",
                                         "Pumps:Electricity"],
           [:circulation, :natural_gas] => [],
           [:circulation, :lpg] => [],
           [:circulation, :fuel_oil] => [],

           [:generation, :electric] => ["ElectricityProduced:Facility"],
           [:generation, :natural_gas] => [],
           [:generation, :lpg] => [],
           [:generation, :fuel_oil] => [] }
end

def create_idf(design, designdir, resultsdir, hpxml, debug, skip_validation)
  Dir.mkdir(designdir)

  OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Fatal)

  output_hpxml_path = get_output_hpxml_path(resultsdir, designdir)

  model = OpenStudio::Model::Model.new
  runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
  measures_dir = File.join(File.dirname(__FILE__), "../measures")

  measures = {}

  # Add HEScore measure to workflow
  measure_subdir = "HEScoreRuleset"
  args = {}
  args['hpxml_path'] = hpxml
  args['hpxml_output_path'] = output_hpxml_path
  args['skip_validation'] = skip_validation
  update_args_hash(measures, measure_subdir, args)

  # Add HPXML translator measure to workflow
  measure_subdir = "HPXMLtoOpenStudio"
  args = {}
  args['hpxml_path'] = output_hpxml_path
  args['weather_dir'] = File.absolute_path(File.join(designdir, "..", "..", "weather"))
  args['epw_output_path'] = File.join(designdir, "in.epw")
  if debug
    args['osm_output_path'] = File.join(designdir, "in.osm")
  end
  args['skip_validation'] = skip_validation
  update_args_hash(measures, measure_subdir, args)

  # Apply measures
  success = apply_measures(measures_dir, measures, runner, model, nil, nil, true)

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

  # Translate model to IDF
  forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
  model_idf = forward_translator.translateModel(model)

  # Write IDF to file
  File.open(File.join(designdir, "in.idf"), 'w') { |f| f << model_idf.to_s }
end

def run_energyplus(design, rundir)
  # getEnergyPlusDirectory can be unreliable, using getOpenStudioCLI instead
  ep_path = File.absolute_path(File.join(OpenStudio.getOpenStudioCLI.to_s, '..', '..', 'EnergyPlus', 'energyplus'))
  command = "cd #{rundir} && #{ep_path} -w in.epw in.idf > stdout-energyplus"
  system(command, :err => File::NULL)
end

def create_output(designdir, resultsdir)
  puts "Compiling outputs..."
  sql_path = File.join(designdir, "eplusout.sql")
  if not File.exists?(sql_path)
    fail "Processing output unsuccessful."
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

        result = UnitConversions.convert(sql_result[i - 1], "J", to_units) # convert from J to site energy units
        result_gj = sql_result[i - 1] / 1000000000.0 # convert from J to GJ

        results[hes_key][i - 1] += result
        results_gj[hes_key][i - 1] += result_gj

        if hes_end_use == :large_appliance
          # Subtract out from small appliance end use
          results[[:small_appliance, hes_resource_type]][i - 1] -= result
          results_gj[[:small_appliance, hes_resource_type]][i - 1] -= result_gj
        end
      end
    end
  end

  # Error-checking
  net_energy_gj = sqlFile.netSiteEnergy.get
  sum_energy_gj = 0
  results_gj.each do |hes_key, values|
    hes_end_use, hes_resource_type = hes_key
    if hes_end_use == :generation
      sum_energy_gj -= values.inject(0, :+)
    else
      sum_energy_gj += values.inject(0, :+)
    end
  end
  if (net_energy_gj - sum_energy_gj).abs > 0.1
    fail "Sum of retrieved outputs #{sum_energy_gj} does not match total net value #{net_energy_gj}."
  end

  sqlFile.close

  # Write results to XML
  data = { "end_use" => [] }
  results.each do |hes_key, values|
    hes_end_use, hes_resource_type = hes_key
    to_units = get_fuel_site_units(hes_resource_type)
    values.each_with_index do |value, idx|
      end_use = { "quantity" => value,
                  "period_type" => "month",
                  "period_number" => idx.to_s,
                  "end_use" => hes_end_use,
                  "resource_type" => hes_resource_type,
                  "units" => to_units }
      data["end_use"] << end_use
    end
  end

  File.open(File.join(resultsdir, "results.json"), "w") do |f|
    f.write(JSON.pretty_generate(data))
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} -x building.xml\n e.g., #{File.basename(__FILE__)} -s -x sample_files/valid.xml\n"

  opts.on('-x', '--xml <FILE>', 'HPXML file') do |t|
    options[:hpxml] = t
  end

  options[:debug] = false
  opts.on('-d', '--debug') do |t|
    options[:debug] = true
  end

  options[:skip_validation] = false
  opts.on('-s', '--skip-validation') do |t|
    options[:skip_validation] = true
  end

  opts.on_tail('-h', '--help', 'Display help') do
    puts opts
    exit!
  end
end.parse!

if not options[:hpxml]
  fail "HPXML argument is required. Call #{File.basename(__FILE__)} -h for usage."
end

unless (Pathname.new options[:hpxml]).absolute?
  options[:hpxml] = File.expand_path(options[:hpxml])
end
unless File.exists?(options[:hpxml]) and options[:hpxml].downcase.end_with? ".xml"
  fail "'#{options[:hpxml]}' does not exist or is not an .xml file."
end

# Check for correct versions of OS
os_version = "2.7.1"
if OpenStudio.openStudioVersion != os_version
  fail "OpenStudio version #{os_version} is required."
end

# Create results dir
resultsdir = File.join(basedir, "results")
rm_path(resultsdir)
Dir.mkdir(resultsdir)

# Run design
puts "HPXML: #{options[:hpxml]}"
design = "HEScoreDesign"
designdir = get_designdir(basedir, design)
rm_path(designdir)
rundir = run_design(designdir, design, resultsdir, options[:hpxml], options[:debug], options[:skip_validation])

# Create output
create_output(designdir, resultsdir)

puts "Completed in #{(Time.now - start_time).round(1)} seconds."
