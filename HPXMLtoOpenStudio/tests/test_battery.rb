# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'

class HPXMLtoOpenStudioBatterTest < MiniTest::Test
  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def get_battery(model, name)
    generator = nil
    model.getElectricLoadCenterStorageLiIonNMCBatterys.each do |b|
      next unless b.name.to_s.start_with? "#{name} "

      return b
    end
  end

  def test_battery
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-pv-battery.xml'))
    model, hpxml = _test_measure(args_hash)

    hpxml.batteries.each do |hpxml_battery|
      battery = get_battery(model, hpxml_battery.id)

      # Check object
      assert_equal(HPXML::BatteryLifetimeModelNone, battery.lifetimeModel)
      assert_in_epsilon(14, battery.numberofCellsinSeries, 0.01)
      assert_in_epsilon(62, battery.numberofStringsinParallel, 0.01)
      assert_in_epsilon(99, battery.batteryMass, 0.01)
      assert_in_epsilon(1.42, battery.batterySurfaceArea, 0.01)
    end
  end

  def _test_measure(args_hash)
    # create an instance of the measure
    measure = HPXMLtoOpenStudio.new

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    model = OpenStudio::Model::Model.new

    # get arguments
    args_hash['output_dir'] = 'tests'
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

    File.delete(File.join(File.dirname(__FILE__), 'in.xml'))

    return model, hpxml
  end
end
