# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'

class HPXMLtoOpenStudioSimControlsTest < MiniTest::Test
  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def get_run_period_month_and_days(model)
    run_period = model.getRunPeriod
    begin_month = run_period.getBeginMonth
    begin_day = run_period.getBeginDayOfMonth
    end_month = run_period.getEndMonth
    end_day = run_period.getEndDayOfMonth
    return begin_month, begin_day, end_month, end_day
  end

  def test_run_period_year
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))
    model, hpxml = _test_measure(args_hash)

    begin_month, begin_day, end_month, end_day = get_run_period_month_and_days(model)
    assert_equal(1, begin_month)
    assert_equal(1, begin_day)
    assert_equal(12, end_month)
    assert_equal(31, end_day)
  end

  def test_run_period_1month
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-simcontrol-runperiod-1-month.xml'))
    model, hpxml = _test_measure(args_hash)

    begin_month, begin_day, end_month, end_day = get_run_period_month_and_days(model)
    assert_equal(1, begin_month)
    assert_equal(1, begin_day)
    assert_equal(1, end_month)
    assert_equal(31, end_day)
  end

  def test_timestep_1hour
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))
    model, hpxml = _test_measure(args_hash)

    assert_equal(1, model.getTimestep.numberOfTimestepsPerHour)
  end

  def test_timestep_10min
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-simcontrol-timestep-10-mins.xml'))
    model, hpxml = _test_measure(args_hash)

    assert_equal(6, model.getTimestep.numberOfTimestepsPerHour)
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
