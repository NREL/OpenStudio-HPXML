# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'

class HPXMLtoOpenStudioMiscLoadsTest < MiniTest::Test
  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def get_kwh_per_year(model, name)
    model.getElectricEquipments.each do |ee|
      next unless ee.name.to_s.include?(name)

      hrs = Schedule.annual_equivalent_full_load_hrs(model.yearDescription.get.assumedYear, ee.schedule.get)
      kwh_yr = UnitConversions.convert(hrs * ee.designLevel.get * ee.multiplier * ee.space.get.multiplier, 'Wh', 'kWh')
      return kwh_yr
    end
    return
  end

  def get_therm_per_year(model, name)
    model.getOtherEquipments.each do |oe|
      next unless oe.name.to_s.include?(name)

      hrs = Schedule.annual_equivalent_full_load_hrs(model.yearDescription.get.assumedYear, oe.schedule.get)
      therm_yr = UnitConversions.convert(hrs * oe.definition.to_OtherEquipmentDefinition.get.designLevel.get * oe.multiplier * oe.space.get.multiplier, 'Wh', 'therm')
      return therm_yr
    end
    return
  end

  def test_misc_loads
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-misc-large-uncommon-loads.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check misc plug loads
    pl_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameMiscPlugLoads)
    assert_in_delta(2454, pl_kwh_yr, 1.0)

    # Check television
    tv_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameMiscTelevision)
    assert_in_delta(619, tv_kwh_yr, 1.0)

    # Check vehicle
    vehicle_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameMiscVehicle)
    assert_in_epsilon(1500, vehicle_kwh_yr, 0.1)

    # Check well pump
    wp_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameMiscWellPump)
    assert_in_epsilon(475, wp_kwh_yr, 0.1)

    # Check pool pump
    pp_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameMiscPoolPump)
    assert_in_epsilon(2700, pp_kwh_yr, 0.1)

    # Check pool electric heater
    ph_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameMiscPoolHeater)
    assert_in_epsilon(2100, ph_kwh_yr, 0.1)

    # Check hot tub pump
    htp_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameMiscHotTubPump)
    assert_in_epsilon(1000, htp_kwh_yr, 0.1)

    # Check hot tub electric heater
    hth_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameMiscHotTubHeater)
    assert_in_epsilon(1300, hth_kwh_yr, 0.1)

    # Check propane grill
    pg_therm_yr = get_therm_per_year(model, Constants.ObjectNameMiscGrill)
    assert_in_epsilon(25, pg_therm_yr, 0.1)

    # Check gas lighting
    gl_therm_yr = get_therm_per_year(model, Constants.ObjectNameMiscLighting)
    assert_in_epsilon(28, gl_therm_yr, 0.1)

    # Check wood fireplace
    wf_therm_yr = get_therm_per_year(model, Constants.ObjectNameMiscFireplace)
    assert_in_epsilon(55, wf_therm_yr, 0.1)
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
