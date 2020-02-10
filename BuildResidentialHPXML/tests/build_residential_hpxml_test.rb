require_relative 'minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
require 'rexml/document'
require 'rexml/xpath'
require 'nokogiri/diff'
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
      Dir["#{test_dir}/base.osw"].sort.each do |osw|
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
        # begin
          _check_hpxmls(workflow_dir, built_dir, hpxml_path)
        # rescue Exception => e
          # puts e
        # end
      end
    end
  end

  private

  def _check_hpxmls(workflow_dir, built_dir, hpxml_path)
    hpxml_path = {
      "Rakefile" => File.join(workflow_dir, File.basename(hpxml_path)),
      "BuildResidentialHPXML" => File.join(built_dir, File.basename(hpxml_path))
    }

    hpxml_doc = {
      "Rakefile" => XMLHelper.parse_file(hpxml_path["Rakefile"]),
      "BuildResidentialHPXML" => XMLHelper.parse_file(hpxml_path["Rakefile"])
    }

    enclosure = {
      "Rakefile" => hpxml_doc["Rakefile"].elements["HPXML/Building/BuildingDetails/Enclosure"],
      "BuildResidentialHPXML" => hpxml_doc["BuildResidentialHPXML"].elements["HPXML/Building/BuildingDetails/Enclosure"]
    }

    HPXML.collapse_enclosure(enclosure["BuildResidentialHPXML"])

    hpxml_doc = {
      "Rakefile" => Nokogiri::XML(hpxml_doc["Rakefile"].to_s).remove_namespaces!,
      "BuildResidentialHPXML" => Nokogiri::XML(hpxml_doc["BuildResidentialHPXML"].to_s).remove_namespaces!
    }

    hpxml_doc["Rakefile"].diff(hpxml_doc["BuildResidentialHPXML"]) do |change, node|
      puts "#{change} #{node.to_xml}".ljust(30) + node.parent.path
    end
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
