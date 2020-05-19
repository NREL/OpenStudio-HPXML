# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'

class HPXMLtoOpenStudioDuctsTest < MiniTest::Test
  def before_setup
    @root_path = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
    @tmp_hpxml_path = File.join(@root_path, 'workflow', 'sample_files', 'tmp.xml')
    @tmp_output_path = File.join(@root_path, 'workflow', 'sample_files', 'tmp_output')
    @tmp_output_hpxml_path = File.join(@tmp_output_path, 'in.xml')
    FileUtils.mkdir_p(@tmp_output_path)

    @args_hash = {}
    @args_hash['hpxml_path'] = File.absolute_path(@tmp_hpxml_path)
    @args_hash['debug'] = true
    @args_hash['output_dir'] = File.absolute_path(@tmp_output_path)
  end
  
  def after_teardown
    File.delete(@tmp_hpxml_path) if File.exist? @tmp_hpxml_path
    FileUtils.rm_rf(@tmp_output_path)
  end

  def test_furnace_gas_and_central_air_conditioner
    default_hpxml('base.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_locations = ['basement - conditioned', 'basement - conditioned']
    expected_areas = [729.0, 270.0]
    _test_default_duct_values(hpxml, expected_locations, expected_areas)

    default_hpxml('base-foundation-multiple.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_locations = ['basement - unconditioned', 'basement - unconditioned']
    expected_areas = [364.5, 67.5]
    _test_default_duct_values(hpxml, expected_locations, expected_areas)

    default_hpxml('base-foundation-ambient.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_locations = ['attic - unvented', 'attic - unvented']
    expected_areas = [364.5, 67.5]
    _test_default_duct_values(hpxml, expected_locations, expected_areas)

    default_hpxml('base-enclosure-other-housing-unit.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_locations = ['living space', 'living space']
    expected_areas = [364.5, 67.5]
    _test_default_duct_values(hpxml, expected_locations, expected_areas)
  end

  def test_furnace_gas_and_central_air_conditioner_ncflag_2
    default_hpxml('base-enclosure-2stories.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_locations = ['basement - conditioned', 'basement - conditioned', 'living space', 'living space']
    expected_areas = [820.125, 455.625, 273.375, 151.875]
    _test_default_duct_values(hpxml, expected_locations, expected_areas)
  end

  def test_multiple_hvac
    hpxml_files = ['base-hvac-multiple.xml',
                   'base-hvac-multiple2.xml']
    hpxml_files.each do |hpxml_file|
      default_hpxml(hpxml_file)
      model, hpxml = _test_measure(@args_hash)
      expected_locations = ['basement - conditioned', 'basement - conditioned', 'basement - conditioned', 'basement - conditioned']
      expected_areas = [91.125, 91.125, 33.75, 33.75]
      _test_default_duct_values(hpxml, expected_locations, expected_areas)
    end
  end

  def test_multiple_ducts_ncflag_2
    default_hpxml('base-hvac-multiple.xml')
    hpxml = HPXML.new(hpxml_path: @tmp_hpxml_path)
    hpxml.building_construction.number_of_conditioned_floors_above_grade = 2
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_locations = ['basement - conditioned', 'basement - conditioned', 'basement - conditioned', 'basement - conditioned', 'living space', 'living space', 'living space', 'living space']
    expected_areas = [68.34375, 68.34375, 25.3125, 25.3125, 22.78125, 22.78125, 8.4375, 8.4375]
    _test_default_duct_values(hpxml, expected_locations, expected_areas)
  end

  def _test_measure(args_hash)
    # create an instance of the measure
    measure = HPXMLtoOpenStudio.new

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    model = OpenStudio::Model::Model.new

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
    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)

    hpxml = HPXML.new(hpxml_path: @tmp_output_hpxml_path)

    return model, hpxml
  end

  def _test_default_duct_values(hpxml, expected_locations, expected_areas)
    hpxml.hvac_distributions.each do |hvac_distribution|
      hvac_distribution.ducts.each_with_index do |duct, idx|
        assert_equal(duct.duct_location, expected_locations[idx])
        assert_in_epsilon(duct.duct_surface_area, expected_areas[idx], 0.01)
      end
    end
  end

  def default_hpxml(hpxml_name)
    hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))

    hpxml.hvac_distributions.each do |hvac_distribution|
      hvac_distribution.ducts.each do |duct|
        duct.duct_location = nil
        duct.duct_surface_area = nil
      end
    end

    # save new file
    hpxml_name = File.basename(@tmp_hpxml_path)
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    return hpxml_name
  end
end