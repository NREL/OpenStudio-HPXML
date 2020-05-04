# frozen_string_literal: true

require_relative '../../HPXMLtoOpenStudio/resources/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require_relative '../measure.rb'

class HPXMLtoOpenStudioTest < MiniTest::Test
  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def test_hvac_central_ac_1_speed
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-hvac-central-ac-only-1-speed.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    cooling_system = hpxml.cooling_systems[0]
    seer = cooling_system.cooling_efficiency_seer
    capacity = UnitConversions.convert(cooling_system.cooling_capacity, 'Btu/hr', 'W')

    # Check cooling coil
    assert_equal(1, model.getCoilCoolingDXSingleSpeeds.size)
    clg_coil = model.getCoilCoolingDXSingleSpeeds[0]
    net_eer = 11.2 # Expected value
    gross_cop = 1.0 / HVAC.calc_eir_from_eer(net_eer, HVAC.get_fan_power_rated(seer))
    assert_in_epsilon(gross_cop, clg_coil.ratedCOP.get, 0.01)
    assert_in_epsilon(capacity, clg_coil.ratedTotalCoolingCapacity.get, 0.01)
  end

  def test_hvac_central_ac_2_speed
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-hvac-central-ac-only-2-speed.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    cooling_system = hpxml.cooling_systems[0]
    seer = cooling_system.cooling_efficiency_seer
    capacity = UnitConversions.convert(cooling_system.cooling_capacity, 'Btu/hr', 'W')

    # Check cooling coil
    assert_equal(1, model.getCoilCoolingDXMultiSpeeds.size)
    clg_coil = model.getCoilCoolingDXMultiSpeeds[0]
    assert_equal(2, clg_coil.stages.size)
    net_eers = [15.5, 14.5] # Expected values
    fan_power_rated = HVAC.get_fan_power_rated(seer)
    net_eers.each_with_index do |net_eer, i|
      gross_cop = 1.0 / HVAC.calc_eir_from_eer(net_eer, fan_power_rated)
      assert_in_epsilon(gross_cop, clg_coil.stages[i].grossRatedCoolingCOP, 0.01)
    end
    assert_in_epsilon(capacity, clg_coil.stages[-1].grossRatedTotalCoolingCapacity.get, 0.01)
  end

  def test_hvac_central_ac_var_speed
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-hvac-central-ac-only-var-speed.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    cooling_system = hpxml.cooling_systems[0]
    seer = cooling_system.cooling_efficiency_seer
    capacity = UnitConversions.convert(cooling_system.cooling_capacity, 'Btu/hr', 'W')

    # Check cooling coil
    assert_equal(1, model.getCoilCoolingDXMultiSpeeds.size)
    clg_coil = model.getCoilCoolingDXMultiSpeeds[0]
    assert_equal(4, clg_coil.stages.size)
    net_eers = [19.1, 19.8, 19.3, 17.9] # Expected values
    fan_power_rated = HVAC.get_fan_power_rated(seer)
    net_eers.each_with_index do |net_eer, i|
      gross_cop = 1.0 / HVAC.calc_eir_from_eer(net_eer, fan_power_rated)
      assert_in_epsilon(gross_cop, clg_coil.stages[i].grossRatedCoolingCOP, 0.01)
    end
    assert_in_epsilon(capacity, clg_coil.stages[-1].grossRatedTotalCoolingCapacity.get, 0.01)
  end

  def test_hvac_central_ashp_1_speed
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-hvac-air-to-air-heat-pump-1-speed.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    heat_pump = hpxml.heat_pumps[0]
    seer = heat_pump.cooling_efficiency_seer
    backup_efficiency = heat_pump.backup_heating_efficiency_percent
    clg_capacity = UnitConversions.convert(heat_pump.cooling_capacity, 'Btu/hr', 'W')
    htg_capacity = UnitConversions.convert(heat_pump.heating_capacity, 'Btu/hr', 'W')
    supp_htg_capacity = UnitConversions.convert(heat_pump.backup_heating_capacity, 'Btu/hr', 'W')

    # Check cooling coil
    assert_equal(1, model.getCoilCoolingDXSingleSpeeds.size)
    clg_coil = model.getCoilCoolingDXSingleSpeeds[0]
    net_eer = 11.31 # Expected value
    fan_power_rated = HVAC.get_fan_power_rated(seer)
    gross_cop = 1.0 / HVAC.calc_eir_from_eer(net_eer, fan_power_rated)
    assert_in_epsilon(gross_cop, clg_coil.ratedCOP.get, 0.01)
    assert_in_epsilon(clg_capacity, clg_coil.ratedTotalCoolingCapacity.get, 0.01)

    # Check heating coil
    assert_equal(1, model.getCoilHeatingDXSingleSpeeds.size)
    htg_coil = model.getCoilHeatingDXSingleSpeeds[0]
    net_cop = 3.09 # Expected value
    gross_cop = 1.0 / HVAC.calc_eir_from_cop(net_cop, fan_power_rated)
    assert_in_epsilon(gross_cop, htg_coil.ratedCOP, 0.01)
    assert_in_epsilon(htg_capacity, htg_coil.ratedTotalHeatingCapacity.get, 0.01)

    # Check supp heating coil
    assert_equal(1, model.getCoilHeatingElectrics.size)
    supp_htg_coil = model.getCoilHeatingElectrics[0]
    assert_in_epsilon(backup_efficiency, supp_htg_coil.efficiency, 0.01)
    assert_in_epsilon(supp_htg_capacity, supp_htg_coil.nominalCapacity.get, 0.01)
  end

  def test_hvac_central_ashp_2_speed
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-hvac-air-to-air-heat-pump-2-speed.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    heat_pump = hpxml.heat_pumps[0]
    seer = heat_pump.cooling_efficiency_seer
    backup_efficiency = heat_pump.backup_heating_efficiency_percent
    clg_capacity = UnitConversions.convert(heat_pump.cooling_capacity, 'Btu/hr', 'W')
    htg_capacity = UnitConversions.convert(heat_pump.heating_capacity, 'Btu/hr', 'W')
    supp_htg_capacity = UnitConversions.convert(heat_pump.backup_heating_capacity, 'Btu/hr', 'W')

    # Check cooling coil
    assert_equal(1, model.getCoilCoolingDXMultiSpeeds.size)
    clg_coil = model.getCoilCoolingDXMultiSpeeds[0]
    assert_equal(2, clg_coil.stages.size)
    net_eers = [14.9, 13.9] # Expected values
    fan_power_rated = HVAC.get_fan_power_rated(seer)
    net_eers.each_with_index do |net_eer, i|
      gross_cop = 1.0 / HVAC.calc_eir_from_eer(net_eer, fan_power_rated)
      assert_in_epsilon(gross_cop, clg_coil.stages[i].grossRatedCoolingCOP, 0.01)
    end
    assert_in_epsilon(clg_capacity, clg_coil.stages[-1].grossRatedTotalCoolingCapacity.get, 0.01)

    # Check heating coil
    assert_equal(1, model.getCoilHeatingDXMultiSpeeds.size)
    htg_coil = model.getCoilHeatingDXMultiSpeeds[0]
    assert_equal(2, htg_coil.stages.size)
    net_cops = [4.24, 3.83] # Expected values
    net_cops.each_with_index do |net_cop, i|
      gross_cop = 1.0 / HVAC.calc_eir_from_cop(net_cop, fan_power_rated)
      assert_in_epsilon(gross_cop, htg_coil.stages[i].grossRatedHeatingCOP, 0.01)
    end
    assert_in_epsilon(htg_capacity, htg_coil.stages[-1].grossRatedHeatingCapacity.get, 0.01)

    # Check supp heating coil
    assert_equal(1, model.getCoilHeatingElectrics.size)
    supp_htg_coil = model.getCoilHeatingElectrics[0]
    assert_in_epsilon(backup_efficiency, supp_htg_coil.efficiency, 0.01)
    assert_in_epsilon(supp_htg_capacity, supp_htg_coil.nominalCapacity.get, 0.01)
  end

  def test_hvac_central_ashp_var_speed
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-hvac-air-to-air-heat-pump-var-speed.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    heat_pump = hpxml.heat_pumps[0]
    seer = heat_pump.cooling_efficiency_seer
    backup_efficiency = heat_pump.backup_heating_efficiency_percent
    clg_capacity = UnitConversions.convert(heat_pump.cooling_capacity, 'Btu/hr', 'W')
    htg_capacity = UnitConversions.convert(heat_pump.heating_capacity, 'Btu/hr', 'W')
    supp_htg_capacity = UnitConversions.convert(heat_pump.backup_heating_capacity, 'Btu/hr', 'W')

    # Check cooling coil
    assert_equal(1, model.getCoilCoolingDXMultiSpeeds.size)
    clg_coil = model.getCoilCoolingDXMultiSpeeds[0]
    assert_equal(4, clg_coil.stages.size)
    net_eers = [17.49, 18.09, 17.64, 16.43] # Expected values
    fan_power_rated = HVAC.get_fan_power_rated(seer)
    net_eers.each_with_index do |net_eer, i|
      gross_cop = 1.0 / HVAC.calc_eir_from_eer(net_eer, fan_power_rated)
      assert_in_epsilon(gross_cop, clg_coil.stages[i].grossRatedCoolingCOP, 0.01)
    end
    assert_in_epsilon(clg_capacity, clg_coil.stages[-1].grossRatedTotalCoolingCapacity.get, 0.01)

    # Check heating coil
    assert_equal(1, model.getCoilHeatingDXMultiSpeeds.size)
    htg_coil = model.getCoilHeatingDXMultiSpeeds[0]
    assert_equal(4, htg_coil.stages.size)
    net_cops = [5.09, 4.40, 3.76, 3.60] # Expected values
    net_cops.each_with_index do |net_cop, i|
      gross_cop = 1.0 / HVAC.calc_eir_from_cop(net_cop, fan_power_rated)
      assert_in_epsilon(gross_cop, htg_coil.stages[i].grossRatedHeatingCOP, 0.01)
    end
    assert_in_epsilon(htg_capacity, htg_coil.stages[-2].grossRatedHeatingCapacity.get, 0.01)

    # Check supp heating coil
    assert_equal(1, model.getCoilHeatingElectrics.size)
    supp_htg_coil = model.getCoilHeatingElectrics[0]
    assert_in_epsilon(backup_efficiency, supp_htg_coil.efficiency, 0.01)
    assert_in_epsilon(supp_htg_capacity, supp_htg_coil.nominalCapacity.get, 0.01)
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

    hpxml = HPXML.new(hpxml_path: args_hash['hpxml_path'])

    return model, hpxml
  end
end
