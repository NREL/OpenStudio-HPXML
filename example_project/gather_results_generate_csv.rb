require 'fileutils'
require 'openstudio'

# expects single argument with path to directory that contains dataoints
# script is setup to run from the directory than contains the script
#path_datapoints = 'run/MyProject'
path_datapoints = ARGV[0]
#path_datapoints = "single-family-detached_buffalo"

outputs_vars = []
outputs_vars << "total_site_energy"
outputs_vars << "total_site_eui"
outputs_vars << "total_building_area"
outputs_vars << "unmet_hours_during_occupied_heating"
outputs_vars << "unmet_hours_during_occupied_cooling"
outputs_vars << "end_use_heating"
outputs_vars << "end_use_cooling"
outputs_vars << "end_use_interior_lighting"
outputs_vars << "end_use_exterior_lighting"
outputs_vars << "end_use_interior_equipment"
outputs_vars << "end_use_exterior_equipment"
outputs_vars << "end_use_fans"
outputs_vars << "end_use_pumps"
outputs_vars << "end_use_heat_rejection"
outputs_vars << "end_use_humidification"
outputs_vars << "end_use_heat_recovery"
outputs_vars << "end_use_water_systems"
outputs_vars << "end_use_refrigeration"
outputs_vars << "end_use_generators"
outputs_vars << "fuel_electricity"
outputs_vars << "fuel_natural_gas"
outputs_vars << "fuel_additional_fuel"
outputs_vars << "fuel_district_cooling"
outputs_vars << "fuel_district_heating"
outputs_vars << "number_of_measures_with_warnings"
outputs_vars << "number_warnings"

# todo - create a hash to contain all results data vs. simple CSV rows
results_hash = {}

# loop through resoruce files
results_directories = Dir.glob("run/#{path_datapoints}/*")
results_directories.sort.each do |results_directory|

  row_data = {}

	# load the test model
  # todo - update to get from idf vs. osm
	translator = OpenStudio::OSVersion::VersionTranslator.new
	path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/#{results_directory}/in.osm")
	model = translator.loadModel(path)
  if not model.is_initialized
    puts "#{results_directory} has not been run"
    next
  end
	model = model.get

  # get building name
  building_name = model.getBuilding.name.to_s

  puts "#{building_name} is in directory (#{results_directory})"

  # load OSW to get information from argument values
  osw_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/#{results_directory}/out.osw")
  osw = OpenStudio::WorkflowJSON.load(osw_path).get
  runner = OpenStudio::Measure::OSRunner.new(osw)

  # store high level information about datapoint
  short_dir = results_directory.to_s.gsub("run/#{path_datapoints}/","feature_")
  row_data["feature"] = short_dir
  row_data["building_name"] = building_name
  #row_data["description"] = runner.workflow.description
  row_data["status"] = runner.workflow.completedStatus.get

  runner.workflow.workflowSteps.each do |step|
    if step.to_MeasureStep.is_initialized

      measure_step = step.to_MeasureStep.get
      measure_dir_name = measure_step.measureDirName

      # for manual PAT projects I want to pass in the measure dir name as the header instead of the measure opiton name
      measure_step_name = measure_dir_name.downcase.gsub(" ","_").to_sym
      next if ! measure_step.result.is_initialized
      next if ! measure_step.result.get.stepResult.is_initialized
      measure_step_result = measure_step.result.get.stepResult.get.valueName

      # populate registerValue objects
      result = measure_step.result.get
      next if result.stepValues.size == 0
      #row_data[measure_step_name] = measure_step_result
      result.stepValues.each do |value|
        next if ! outputs_vars.include?(value.name.to_s) # this will make csv smaller
        # populate feature_hash (there is issue filed with value.units)
        row_data["#{measure_step_name}.#{value.name}"] = value.valueAsVariant.to_s
      end

      # populate results_hash
      results_hash[results_directory] = row_data

    else
      #puts "This step is not a measure"
    end

  end

end

# populate csv header
headers = []
results_hash.each do |k,v|
  v.each do |k2,v2|
    if ! headers.include? k2
      headers << k2
    end
  end
end
headers = headers.sort

# populate csv
require "csv"
csv_rows = []
results_hash.each do |k,v|
  arr_row = []
  headers.each {|header| arr_row.push(v.key?(header) ? v[header] : nil)}
  csv_row = CSV::Row.new(headers, arr_row)
  csv_rows.push(csv_row)
end

# save csv
csv_table = CSV::Table.new(csv_rows)
path_report = "run/#{path_datapoints}/workflow_results.csv"
puts "saving csv file to #{path_report}"
File.open(path_report, 'w'){|file| file << csv_table.to_s}
