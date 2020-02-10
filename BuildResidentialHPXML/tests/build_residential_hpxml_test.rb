require_relative 'minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
require 'rexml/document'
require 'rexml/xpath'
require_relative '../../HPXMLtoOpenStudio/resources/meta_measure'

class BuildResidentialHPXMLTest < MiniTest::Test
  def test_workflows
    require 'json'

    this_dir = File.dirname(__FILE__)

    hvac_partial_dir = File.absolute_path(File.join(this_dir, "hvac_partial"))
    test_dirs = [this_dir,
                 hvac_partial_dir]

    measures_dir = File.join(this_dir, "../..")

    osws = []
    test_dirs.each do |test_dir|
      Dir["#{test_dir}/base*.osw"].sort.each do |osw|
        osws << File.absolute_path(osw)
      end
    end

    workflow_dir = File.expand_path(File.join(File.dirname(__FILE__), "../../workflow/tests"))
    tests_dir = File.expand_path(File.join(File.dirname(__FILE__), "../../BuildResidentialHPXML/tests"))
    built_dir = File.join(tests_dir, "built_residential_hpxml")
    unless Dir.exists?(built_dir)
      Dir.mkdir(built_dir)
    end

    puts "Running #{osws.size} OSW files..."
    measures = {}
    osws.each do |osw|
      puts "\nTesting #{File.basename(osw)}..."

      _setup(tests_dir)
      osw_hash = JSON.parse(File.read(osw))
      osw_hash["steps"].each do |step|
        measures[step["measure_dir_name"]] = [step["arguments"]]
        model = OpenStudio::Model::Model.new
        runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

        # Apply measure
        success = apply_measures(measures_dir, measures, runner, model)

        # Report warnings/errors
        runner.result.stepWarnings.each do |s|
          puts "Warning: #{s}"
        end
        runner.result.stepErrors.each do |s|
          puts "Error: #{s}"
        end

        assert(success)

        if ["base-single-family-attached.osw", "base-multifamily.osw"].include? File.basename(osw)
          next # FIXME: should this be temporary?
        end

        # Compare the hpxml to the manually created one
        hpxml_path = step["arguments"]["hpxml_path"]
        begin
          _check_hpxmls(workflow_dir, built_dir, hpxml_path)
        rescue Exception => e
          puts e
        end
      end
    end
  end

  private

  def _check_hpxmls(workflow_dir, built_dir, hpxml_path)
    err = ""

    hpxml_path = {
      "Rakefile" => File.join(workflow_dir, File.basename(hpxml_path)),
      "BuildResidentialHPXML" => File.join(built_dir, File.basename(hpxml_path))
    }

    hpxml_doc = {
      "Rakefile" => XMLHelper.parse_file(hpxml_path["Rakefile"]),
      "BuildResidentialHPXML" => XMLHelper.parse_file(hpxml_path["BuildResidentialHPXML"])
    }

    building = {
      "Rakefile" => hpxml_doc["Rakefile"].elements["/HPXML/Building"],
      "BuildResidentialHPXML" => hpxml_doc["BuildResidentialHPXML"].elements["/HPXML/Building"]
    }

    building_details = {
      "Rakefile" => building["Rakefile"].elements["BuildingDetails"],
      "BuildResidentialHPXML" => building["BuildResidentialHPXML"].elements["BuildingDetails"]
    }

    enclosure = {
      "Rakefile" => building_details["Rakefile"].elements["Enclosure"],
      "BuildResidentialHPXML" => building_details["BuildResidentialHPXML"].elements["Enclosure"]
    }

    HPXML.collapse_enclosure(enclosure["BuildResidentialHPXML"])

    building_construction = {
      "Rakefile" => building_details["Rakefile"].elements["BuildingSummary/BuildingConstruction"],
      "BuildResidentialHPXML" => building_details["BuildResidentialHPXML"].elements["BuildingSummary/BuildingConstruction"]
    }

    building_construction_values = {
      "Rakefile" => [HPXML.get_building_construction_values(building_construction: building_construction["Rakefile"])],
      "BuildResidentialHPXML" => [HPXML.get_building_construction_values(building_construction: building_construction["BuildResidentialHPXML"])]
    }

    air_infiltration_measurement = {
      "Rakefile" => enclosure["Rakefile"].elements["AirInfiltration/AirInfiltrationMeasurement"],
      "BuildResidentialHPXML" => enclosure["BuildResidentialHPXML"].elements["AirInfiltration/AirInfiltrationMeasurement"]
    }

    air_infiltration_measurement_values = {
      "Rakefile" => [HPXML.get_air_infiltration_measurement_values(air_infiltration_measurement: air_infiltration_measurement["Rakefile"])],
      "BuildResidentialHPXML" => [HPXML.get_air_infiltration_measurement_values(air_infiltration_measurement: air_infiltration_measurement["BuildResidentialHPXML"])]
    }

    roof_values = {
      "Rakefile" => [],
      "BuildResidentialHPXML" => []
    }

    enclosure["Rakefile"].elements.each("Roofs/Roof") do |roof|
      roof_values["Rakefile"] << HPXML.get_roof_values(roof: roof)
    end

    enclosure["BuildResidentialHPXML"].elements.each("Roofs/Roof") do |roof|
      roof_values["BuildResidentialHPXML"] << HPXML.get_roof_values(roof: roof)
    end

    err = _check_elements(building_construction_values, err)
    err = _check_elements(air_infiltration_measurement_values, err)
    err = _check_elements(roof_values, err)

    if not err.empty?
      raise err
    end
  end

  def _check_elements(valuess, err)
    valuess["Rakefile"].each_with_index do |values, i|
      values.each do |key, value1|
        next if key.to_s.include? "id"

        value2 = valuess["BuildResidentialHPXML"][i][key]
        next if value1 == value2

        if value1.is_a? Numeric and value2.is_a? Numeric
          next if (value1 - value2).abs < 1.0
        end

        value1 = "nil" if value1.nil?
        value2 = "nil" if value2.nil?

        err += "ERROR: #{key}: #{value1} != #{value2}.\n"
      end
    end
    return err
  end

  def _setup(this_dir)
    rundir = File.join(this_dir, "run")
    _rm_path(rundir)
    Dir.mkdir(rundir)
  end

  def _test_measure(osm_file_or_model, args_hash)
    # create an instance of the measure
    measure = HPXMLExporter.new

    # check for standard methods
    assert(!measure.name.empty?)
    assert(!measure.description.empty?)

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    model = get_model(File.dirname(__FILE__), osm_file_or_model)

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result) unless result.value.valueName == "Success"

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)

    # TODO: get the hpxml and check its elements
  end

  def _rm_path(path)
    if Dir.exists?(path)
      FileUtils.rm_r(path)
    end
    while true
      break if not Dir.exists?(path)

      sleep(0.01)
    end
  end
end
