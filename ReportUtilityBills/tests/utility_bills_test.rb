# frozen_string_literal: true

require 'oga'
require_relative '../../HPXMLtoOpenStudio/resources/minitest_helper'
require_relative '../../HPXMLtoOpenStudio/resources/constants'
require_relative '../../HPXMLtoOpenStudio/resources/energyplus'
require_relative '../../HPXMLtoOpenStudio/resources/hpxml'
require_relative '../../HPXMLtoOpenStudio/resources/schedules'
require_relative '../../HPXMLtoOpenStudio/resources/unit_conversions'
require_relative '../../HPXMLtoOpenStudio/resources/xmlhelper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require_relative '../measure.rb'
require 'csv'

class ReportUtilityBillsTest < MiniTest::Test
  # BEopt building:
  # - 600 sq ft (30 x 20), Denver EPW
  # - Propane cooking range
  # - Oil Standard water heater
  # - USA_CO_Denver.Intl.AP EPW location
  # - All other options left at default values
  # Then retrieve 1.csv from output folder, change headers to OpenStudio headers, and subtract Produced column from Facility column

  def setup
    @args_hash = {}
    @args_hash['hpxml_path'] = '../workflow/sample_files/base.xml'
    @args_hash['electricity_fixed_charge'] = 8.0
    @args_hash['electricity_marginal_rate'] = '0.1080'
    @args_hash['natural_gas_fixed_charge'] = 8.0
    @args_hash['natural_gas_marginal_rate'] = '0.6472'
    @args_hash['fuel_oil_marginal_rate'] = '2.6000'
    @args_hash['propane_marginal_rate'] = '1.9900'
    @args_hash['wood_cord_marginal_rate'] = ''
    @args_hash['wood_pellets_marginal_rate'] = ''
    @args_hash['coal_marginal_rate'] = ''
    @args_hash['pv_compensation_type'] = 'Net Metering'
    @args_hash['pv_feed_in_tariff_rate'] = 0.12
    @args_hash['pv_grid_connection_fee_units'] = '$/kW'
    @args_hash['pv_monthly_grid_connection_fee'] = 0.0

    @expected_bills = {
      'Electricity: Fixed ($)' => 96.0,
      'Electricity: Marginal ($)' => 568.69,
      'Electricity: PV Credit ($)' => 0.0,
      'Electricity: Total ($)' => 664.69,
      'Natural Gas: Fixed ($)' => 96.0,
      'Natural Gas: Marginal ($)' => 129.09,
      'Natural Gas: Total ($)' => 225.09,
      'Fuel Oil: Total ($)' => 343.55,
      'Propane: Total ($)' => 61.97,
      'Wood Cord: Total ($)' => 0.0,
      'Wood Pellets: Total ($)' => 0.0,
      'Coal: Total ($)' => 0.0
    }

    @measure = ReportUtilityBills.new
  end

  def test_simple_calculations_pv_none
    fuels, utility_rates, utility_bills = @measure.setup_outputs()

    _load_timeseries(fuels, '../tests/PV_None.csv')

    bills_csv = _custom_calcs(fuels, utility_rates, utility_bills, 2007)
    assert(File.exist?(bills_csv))
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_pv_1kW
    fuels, utility_rates, utility_bills = @measure.setup_outputs()

    _load_timeseries(fuels, '../tests/PV_1kW.csv')

    bills_csv = _custom_calcs(fuels, utility_rates, utility_bills, 2007)
    assert(File.exist?(bills_csv))
    actual_bills = get_actual_bills(bills_csv)
    @expected_bills['Electricity: PV Credit ($)'] = -160.22
    @expected_bills['Electricity: Total ($)'] = 504.48
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_pv_10kW
    fuels, utility_rates, utility_bills = @measure.setup_outputs()

    _load_timeseries(fuels, '../tests/PV_10kW.csv')

    bills_csv = _custom_calcs(fuels, utility_rates, utility_bills, 2007)
    assert(File.exist?(bills_csv))
    actual_bills = get_actual_bills(bills_csv)
    @expected_bills['Electricity: PV Credit ($)'] = -1607.48
    @expected_bills['Electricity: Total ($)'] = -942.79
    assert_equal(@expected_bills, actual_bills)
  end

  def _load_timeseries(fuels, path)
    columns = CSV.read(File.join(File.dirname(__FILE__), path)).transpose
    columns.each do |col|
      col_name = col[0]
      next if col_name == 'Date/Time'

      values = col[1..-1].map { |v| Float(v) }

      if col_name == 'ELECTRICITY:UNIT_1 [J](Hourly)'
        fuel = fuels[[FT::Elec, false]]
        unit_conv = UnitConversions.convert(1.0, 'J', fuel.units)
        fuel.timeseries = values.map { |v| v * unit_conv }
      elsif col_name == 'GAS:UNIT_1 [J](Hourly)'
        fuel = fuels[[FT::Gas, false]]
        unit_conv = UnitConversions.convert(1.0, 'J', fuel.units)
        fuel.timeseries = values.map { |v| v * unit_conv }
      elsif col_name == 'Appl_1:ExteriorEquipment:Propane [J](Hourly)'
        fuel = fuels[[FT::Propane, false]]
        unit_conv = UnitConversions.convert(1.0, 'J', fuel.units) / 91.6
        fuel.timeseries = values.map { |v| v * unit_conv }
      elsif col_name == 'FUELOIL:UNIT_1 [m3](Hourly)'
        fuel = fuels[[FT::Oil, false]]
        unit_conv = UnitConversions.convert(1.0, 'm^3', 'gal')
        fuel.timeseries = values.map { |v| v * unit_conv }
      elsif col_name == 'PV:ELECTRICITY_1 [J](Hourly) '
        fuel = fuels[[FT::Elec, true]]
        unit_conv = UnitConversions.convert(1.0, 'J', fuel.units)
        fuel.timeseries = values.map { |v| v * unit_conv }
      end
    end

    fuels.each do |(fuel_type, is_production), fuel|
      fuel.timeseries = [0] * 8760 if fuel.timeseries.empty? # FIXME
    end
  end

  def _custom_calcs(fuels, utility_rates, utility_bills, sim_calendar_year)
    args = Hash[@args_hash.collect { |k, v| [k.to_sym, v] }]
    args[:electricity_bill_type] = 'Simple' # TODO: support Detailed
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    output_format = 'csv'
    output_path = File.join(File.dirname(__FILE__), "results_bills.#{output_format}")

    hpxml = HPXML.new(hpxml_path: File.join(File.dirname(__FILE__), '..', args[:hpxml_path]))

    @measure.get_utility_rates(fuels, utility_rates, args, hpxml.header.state_code, hpxml.pv_systems)
    net_elec = @measure.get_utility_bills(fuels, utility_rates, utility_bills, args, sim_calendar_year)
    @measure.annual_true_up(utility_rates, utility_bills, net_elec)
    @measure.get_annual_bills(utility_bills)

    @measure.write_output(runner, utility_bills, output_format, output_path)

    bills_csv = File.join(File.dirname(__FILE__), 'results_bills.csv')

    return bills_csv
  end

  def test_simple_calculations_auto_rates
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 144.0
    @expected_bills['Electricity: Marginal ($)'] = 1046.85
    @expected_bills['Electricity: Total ($)'] = 1190.85
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 94.01
    @expected_bills['Natural Gas: Total ($)'] = 190.01
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_specified_rates
    @args_hash['electricity_marginal_rate'] = '0.1'
    @args_hash['natural_gas_marginal_rate'] = '1.0'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 144.0
    @expected_bills['Electricity: Marginal ($)'] = 1025.04
    @expected_bills['Electricity: Total ($)'] = 1169.04
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 145.27
    @expected_bills['Natural Gas: Total ($)'] = 241.27
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_fuel_oil
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-hvac-furnace-oil-only.xml'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 144.0
    @expected_bills['Electricity: Marginal ($)'] = 922.31
    @expected_bills['Electricity: Total ($)'] = 1066.31
    @expected_bills['Fuel Oil: Total ($)'] = 281.66
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_propane
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-hvac-furnace-propane-only.xml'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 144.0
    @expected_bills['Electricity: Marginal ($)'] = 922.31
    @expected_bills['Electricity: Total ($)'] = 1066.31
    @expected_bills['Propane: Total ($)'] = 327.14
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_wood_cord
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-hvac-furnace-wood-only.xml'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 144.0
    @expected_bills['Electricity: Marginal ($)'] = 922.31
    @expected_bills['Electricity: Total ($)'] = 1066.31
    @expected_bills['Wood Cord: Total ($)'] = 1505.81
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_wood_pellets
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-hvac-stove-wood-pellets-only.xml'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 144.0
    @expected_bills['Electricity: Marginal ($)'] = 911.9
    @expected_bills['Electricity: Total ($)'] = 1055.9
    @expected_bills['Wood Pellets: Total ($)'] = 1426.89
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_coal
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-hvac-furnace-coal-only.xml'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 144.0
    @expected_bills['Electricity: Marginal ($)'] = 922.31
    @expected_bills['Electricity: Total ($)'] = 1066.31
    @expected_bills['Coal: Total ($)'] = 1505.81
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_auto_rates_pv_net_metering_user
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-pv.xml'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 144.0
    @expected_bills['Electricity: Marginal ($)'] = 1046.85
    @expected_bills['Electricity: Credit ($)'] = 804.72
    @expected_bills['Electricity: Total ($)'] = 386.12
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 94.01
    @expected_bills['Natural Gas: Total ($)'] = 190.01
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_auto_rates_pv_net_metering_user_net_producer
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-pv-2.xml'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 144.0
    @expected_bills['Electricity: Marginal ($)'] = 1046.85
    @expected_bills['Electricity: Credit ($)'] = 1123.08
    @expected_bills['Electricity: Total ($)'] = 67.77
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 94.01
    @expected_bills['Natural Gas: Total ($)'] = 190.01
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_auto_rates_pv_net_metering_retail
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-pv.xml'
    @args_hash['pv_annual_excess_sellback_rate_type'] = 'Retail Electricity Cost'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 144.0
    @expected_bills['Electricity: Marginal ($)'] = 1046.85
    @expected_bills['Electricity: Credit ($)'] = 804.72
    @expected_bills['Electricity: Total ($)'] = 386.12
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 94.01
    @expected_bills['Natural Gas: Total ($)'] = 190.01
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_auto_rates_pv_net_metering_retail_net_producer
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-pv-2.xml'
    @args_hash['pv_annual_excess_sellback_rate_type'] = 'Retail Electricity Cost'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 144.0
    @expected_bills['Electricity: Marginal ($)'] = 1046.85
    @expected_bills['Electricity: Credit ($)'] = 1306.37
    @expected_bills['Electricity: Total ($)'] = -115.52
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 94.01
    @expected_bills['Natural Gas: Total ($)'] = 190.01
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_simple_calculations_auto_rates_pv_feed_in_tariff
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-pv.xml'
    @args_hash['pv_compensation_type'] = 'Feed-In Tariff'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 144.0
    @expected_bills['Electricity: Marginal ($)'] = 1046.85
    @expected_bills['Electricity: Credit ($)'] = 945.56
    @expected_bills['Electricity: Total ($)'] = 245.29
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 94.01
    @expected_bills['Natural Gas: Total ($)'] = 190.01
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_detailed_electric_calculations_real_time_pricing
    @args_hash['electricity_bill_type'] = 'Detailed'
    @args_hash['electricity_utility_rate_type'] = 'Sample Real-Time Pricing Rate'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 108.0
    @expected_bills['Electricity: Marginal ($)'] = 689.34
    @expected_bills['Electricity: Total ($)'] = 797.34
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 94.01
    @expected_bills['Natural Gas: Total ($)'] = 190.01
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_detailed_electric_calculations_real_time_pricing_leap_year
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-location-AMY-2012.xml'
    @args_hash['electricity_bill_type'] = 'Detailed'
    @args_hash['electricity_utility_rate_type'] = 'Sample Real-Time Pricing Rate'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 108.0
    @expected_bills['Electricity: Marginal ($)'] = 678.08
    @expected_bills['Electricity: Total ($)'] = 786.08
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 137.43
    @expected_bills['Natural Gas: Total ($)'] = 233.43
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_detailed_electric_calculations_tiered_rate
    @args_hash['electricity_bill_type'] = 'Detailed'
    @args_hash['electricity_utility_rate_type'] = 'Sample Tiered Rate'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 0.0
    @expected_bills['Electricity: Marginal ($)'] = 0.0
    @expected_bills['Electricity: Total ($)'] = 0.0
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 94.01
    @expected_bills['Natural Gas: Total ($)'] = 190.01
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_detailed_electric_calculations_time_of_use_rate
    @args_hash['electricity_bill_type'] = 'Detailed'
    @args_hash['electricity_utility_rate_type'] = 'Sample Time-of-Use Rate'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 0.0
    @expected_bills['Electricity: Marginal ($)'] = 0.0
    @expected_bills['Electricity: Total ($)'] = 0.0
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 94.01
    @expected_bills['Natural Gas: Total ($)'] = 190.01
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_detailed_electric_calculations_tiered_time_of_use_rate
    @args_hash['electricity_bill_type'] = 'Detailed'
    @args_hash['electricity_utility_rate_type'] = 'Sample Tiered Time-of-Use Rate'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 0.0
    @expected_bills['Electricity: Marginal ($)'] = 0.0
    @expected_bills['Electricity: Total ($)'] = 0.0
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 94.01
    @expected_bills['Natural Gas: Total ($)'] = 190.01
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_detailed_electric_calculations_user_specified_rate
    skip
    @args_hash['electricity_bill_type'] = 'Detailed'
    @args_hash['electricity_utility_rate_type'] = 'User-Specified'
    @args_hash['electricity_utility_rate_user_specified'] = '../../ReportUtilityBills/resources/Data/CustomRates/Sample Tiered Rate.json'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    @expected_bills['Electricity: Fixed ($)'] = 0.0
    @expected_bills['Electricity: Marginal ($)'] = 0.0
    @expected_bills['Electricity: Total ($)'] = 0.0
    @expected_bills['Natural Gas: Fixed ($)'] = 96.0
    @expected_bills['Natural Gas: Marginal ($)'] = 94.01
    @expected_bills['Natural Gas: Total ($)'] = 190.01
    actual_bills = get_actual_bills(bills_csv)
    assert_equal(@expected_bills, actual_bills)
  end

  def test_warning_semi_annual_run_period
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-simcontrol-runperiod-1-month.xml'
    expected_warning = 'A full annual simulation is required for calculating utility bills.'
    bills_csv = _test_measure(expected_warning: expected_warning)
    assert(!File.exist?(bills_csv))
  end

  def test_error_user_specified_but_no_rates
    @args_hash['electricity_bill_type'] = 'Detailed'
    @args_hash['electricity_utility_rate_type'] = 'User-Specified'
    expected_error = 'Must specify a utility rate json path when choosing User-Specified utility rate type.'
    bills_csv = _test_measure(expected_error: expected_error)
    assert(!File.exist?(bills_csv))
  end

  def test_error_dse
    # TODO
  end

  def get_actual_bills(bills_csv)
    actual_bills = {}
    File.readlines(bills_csv).each do |line|
      next if line.strip.empty?

      key, value = line.split(',').map { |x| x.strip }
      actual_bills[key] = Float(value)
    end
    return actual_bills
  end

  def _test_measure(expected_error: nil, expected_warning: nil)
    # Run measure via OSW
    require 'json'
    template_osw = File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'template-report-utility-bills.osw')
    workflow = OpenStudio::WorkflowJSON.new(template_osw)
    json = JSON.parse(workflow.to_s)

    # Update measure args
    steps = OpenStudio::WorkflowStepVector.new
    found_args = []
    json['steps'].each do |json_step|
      step = OpenStudio::MeasureStep.new(json_step['measure_dir_name'])
      json_step['arguments'].each do |json_arg_name, json_arg_val|
        if @args_hash.keys.include? json_arg_name
          # Override value
          found_args << json_arg_name
          json_arg_val = @args_hash[json_arg_name]
        end
        step.setArgument(json_arg_name, json_arg_val)
      end
      steps.push(step)
    end
    workflow.setWorkflowSteps(steps)
    osw_path = File.join(File.dirname(template_osw), 'test.osw')
    workflow.saveAs(osw_path)
    assert_equal(@args_hash.size, found_args.size)

    # Run OSW
    success = system("#{OpenStudio.getOpenStudioCLI} run -w #{osw_path}")
    if not success
      flunk 'Error: Unknown.' if expected_error.nil?
    end

    # Cleanup
    File.delete(osw_path)

    bills_csv = File.join(File.dirname(template_osw), 'run', 'results_bills.csv')

    # check warnings/errors
    log_lines = File.readlines(File.join(File.dirname(bills_csv), 'run.log'))
    if not expected_error.nil?
      assert(log_lines.any? { |log_line| log_line.include?(expected_error) })
    end
    if not expected_warning.nil?
      assert(log_lines.any? { |log_line| log_line.include?(expected_warning) })
    end

    return bills_csv
  end
end
