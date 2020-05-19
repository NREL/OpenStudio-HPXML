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
    
    duct_surface_area_expected = [729.0, 270.0]
    hpxml.hvac_distributions.each do |hvac_distribution|
      hvac_distribution.ducts.each_with_index do |duct, idx|
        assert_equal(duct.duct_location, 'basement - conditioned')
        assert_in_epsilon(duct.duct_surface_area, duct_surface_area_expected[idx], 0.01)
      end
    end
        
    default_hpxml('base-foundation-multiple.xml')
    model, hpxml = _test_measure(@args_hash)

    duct_surface_area_expected = [364.5, 67.5]
    hpxml.hvac_distributions.each do |hvac_distribution|
      hvac_distribution.ducts.each_with_index do |duct, idx|
        assert_equal(duct.duct_location, 'basement - unconditioned')
        assert_in_epsilon(duct.duct_surface_area, duct_surface_area_expected[idx], 0.01)
      end
    end
        
    default_hpxml('base-foundation-ambient.xml')
    model, hpxml = _test_measure(@args_hash)

    duct_surface_area_expected = [364.5, 67.5]
    hpxml.hvac_distributions.each do |hvac_distribution|
      hvac_distribution.ducts.each_with_index do |duct, idx|
        assert_equal(duct.duct_location, 'attic - unvented')
        assert_in_epsilon(duct.duct_surface_area, duct_surface_area_expected[idx], 0.01)
      end
    end
  end

  def test_furnace_gas_and_central_air_conditioner_ncflag_2
    default_hpxml('base-enclosure-2stories.xml')
    model, hpxml = _test_measure(@args_hash)

    duct_location_expected = ['basement - conditioned', 'basement - conditioned', 'living space', 'living space']
    duct_surface_area_expected = [820.125, 455.625, 273.375, 151.875]
    hpxml.hvac_distributions.each do |hvac_distribution|
      hvac_distribution.ducts.each_with_index do |duct, idx|
        assert_equal(duct.duct_location, duct_location_expected[idx])
        assert_in_epsilon(duct.duct_surface_area, duct_surface_area_expected[idx], 0.01)
      end
    end
  end

  def test_multiple_hvac
    hpxml_files = ['base-hvac-multiple.xml',
                   'base-hvac-multiple2.xml']
    hpxml_files.each do |hpxml_file|
      default_hpxml(hpxml_file)
      model, hpxml = _test_measure(@args_hash)

      duct_surface_area_expected = [91.125, 91.125, 33.75, 33.75]
      hpxml.hvac_distributions.each do |hvac_distribution|
        next unless hvac_distribution.distribution_system_type == HPXML::HVACDistributionTypeAir

        hvac_distribution.ducts.each_with_index do |duct, idx|
          assert_equal(duct.duct_location, 'basement - conditioned')
          assert_in_epsilon(duct.duct_surface_area, duct_surface_area_expected[idx], 0.01)
        end
      end
    end
  end

  def test_multiple_ducts_ncflag_2
    default_hpxml('base-hvac-multiple.xml')
    hpxml = HPXML.new(hpxml_path: @tmp_hpxml_path)
    hpxml.building_construction.number_of_conditioned_floors_above_grade = 2
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)

    duct_location_expected = ['basement - conditioned', 'basement - conditioned', 'basement - conditioned', 'basement - conditioned', 'living space', 'living space', 'living space', 'living space']
    duct_surface_area_expected = [68.34375, 68.34375, 25.3125, 25.3125, 22.78125, 22.78125, 8.4375, 8.4375]
    hpxml.hvac_distributions.each do |hvac_distribution|
      next unless hvac_distribution.distribution_system_type == HPXML::HVACDistributionTypeAir

      hvac_distribution.ducts.each_with_index do |duct, idx|
        assert_equal(duct.duct_location, duct_location_expected[idx])
        assert_in_epsilon(duct.duct_surface_area, duct_surface_area_expected[idx], 0.01)
      end
    end
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