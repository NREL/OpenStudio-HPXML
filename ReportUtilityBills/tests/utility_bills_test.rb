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
  # BEopt 2.8.0.0:
  # - Standard, New Construction, Single-Family Detached
  # - 600 sq ft (30 x 20)
  # - EPW Location: USA_CO_Denver.Intl.AP.725650_TMY3.epw
  # - Cooking Range: Propane
  # - Water Heater: Oil Standard
  # - PV System: None, 1.0 kW, 10.0 kW
  # - Timestep: 10 min
  # - User-Specified rates (calculated using Constants.Auto):
  #   - Electricity: 0.1313 $/kWh
  #   - Natural Gas: 0.8596819457436857 $/therm
  #   - Oil: 3.495346153846154 $/gal
  #   - Propane: 2.4532692307692305 $/gal
  # - All other options left at default values
  # Then retrieve 1.csv from output folder, copy it, rename it

  def setup
    @args_hash = {}
    @args_hash['electricity_fixed_charge'] = 8.0
    @args_hash['electricity_marginal_rate'] = Constants.Auto
    @args_hash['natural_gas_fixed_charge'] = 8.0
    @args_hash['natural_gas_marginal_rate'] = Constants.Auto
    @args_hash['fuel_oil_marginal_rate'] = Constants.Auto
    @args_hash['propane_marginal_rate'] = Constants.Auto
    # @args_hash['wood_cord_marginal_rate'] = ''
    # @args_hash['wood_pellets_marginal_rate'] = ''
    # @args_hash['coal_marginal_rate'] = ''
    @args_hash['pv_compensation_type'] = 'Net Metering'
    @args_hash['pv_annual_excess_sellback_rate_type'] = 'User-Specified'
    @args_hash['pv_net_metering_annual_excess_sellback_rate'] = 0.03
    @args_hash['pv_feed_in_tariff_rate'] = 0.12
    @args_hash['pv_grid_connection_fee_units'] = '$/kW'
    @args_hash['pv_monthly_grid_connection_fee'] = 0.0

    # From BEopt Output screen (Utility Bills $/yr)
    @expected_bills = {
      'Electricity: Fixed ($)' => 96,
      'Electricity: Marginal ($)' => 691,
      'Electricity: PV Credit ($)' => 0,
      'Electricity: Total ($)' => 787,
      'Natural Gas: Fixed ($)' => 96,
      'Natural Gas: Marginal ($)' => 171,
      'Natural Gas: Total ($)' => 267,
      'Fuel Oil: Total ($)' => 462,
      'Propane: Total ($)' => 76,
      'Wood Cord: Total ($)' => 0,
      'Wood Pellets: Total ($)' => 0,
      'Coal: Total ($)' => 0,
      'Total ($)' => 1593,
    }

    @measure = ReportUtilityBills.new
    @hpxml = HPXML.new(hpxml_path: File.join(File.dirname(__FILE__), '../../workflow/sample_files/base-pv.xml'))
  end

  def test_simple_calculations_pv_none
    fuels, utility_rates, utility_bills = @measure.setup_outputs()
    _load_timeseries(fuels, '../tests/PV_None.csv')
    bills_csv = _bill_calcs(fuels, utility_rates, utility_bills, @hpxml.header.state_code, [], 2007)
    assert(File.exist?(bills_csv))
    actual_bills = _get_actual_bills(bills_csv)
    _check_bills(@expected_bills, actual_bills)
  end

  def test_simple_calculations_pv_1kW
    fuels, utility_rates, utility_bills = @measure.setup_outputs()
    _load_timeseries(fuels, '../tests/PV_1kW.csv')
    @hpxml.pv_systems.each { |pv_system| pv_system.max_power_output = 500 }
    bills_csv = _bill_calcs(fuels, utility_rates, utility_bills, @hpxml.header.state_code, @hpxml.pv_systems, 2007)
    assert(File.exist?(bills_csv))
    actual_bills = _get_actual_bills(bills_csv)
    @expected_bills['Electricity: PV Credit ($)'] = -195
    @expected_bills['Electricity: Total ($)'] = 592
    @expected_bills['Total ($)'] = 1398
    _check_bills(@expected_bills, actual_bills)
  end

  def test_simple_calculations_pv_10kW
    fuels, utility_rates, utility_bills = @measure.setup_outputs()
    _load_timeseries(fuels, '../tests/PV_10kW.csv')
    @hpxml.pv_systems.each { |pv_system| pv_system.max_power_output = 5000 }
    bills_csv = _bill_calcs(fuels, utility_rates, utility_bills, @hpxml.header.state_code, @hpxml.pv_systems, 2007)
    assert(File.exist?(bills_csv))
    actual_bills = _get_actual_bills(bills_csv)
    @expected_bills['Electricity: PV Credit ($)'] = -980
    @expected_bills['Electricity: Total ($)'] = -193
    @expected_bills['Total ($)'] = 613
    _check_bills(@expected_bills, actual_bills)
  end

  def test_simple_calculations_pv_10kW_retail
    @args_hash['pv_annual_excess_sellback_rate_type'] = 'Retail Electricity Cost'
    fuels, utility_rates, utility_bills = @measure.setup_outputs()
    _load_timeseries(fuels, '../tests/PV_10kW.csv')
    @hpxml.pv_systems.each { |pv_system| pv_system.max_power_output = 5000 }
    bills_csv = _bill_calcs(fuels, utility_rates, utility_bills, @hpxml.header.state_code, @hpxml.pv_systems, 2007)
    assert(File.exist?(bills_csv))
    actual_bills = _get_actual_bills(bills_csv)
    @expected_bills['Electricity: PV Credit ($)'] = -1954
    @expected_bills['Electricity: Total ($)'] = -1167
    @expected_bills['Total ($)'] = -361
    _check_bills(@expected_bills, actual_bills)
  end

  def test_simple_calculations_pv_1kW_feed_in_tariff
    @args_hash['pv_compensation_type'] = 'Feed-In Tariff'
    fuels, utility_rates, utility_bills = @measure.setup_outputs()
    _load_timeseries(fuels, '../tests/PV_1kW.csv')
    @hpxml.pv_systems.each { |pv_system| pv_system.max_power_output = 500 }
    bills_csv = _bill_calcs(fuels, utility_rates, utility_bills, @hpxml.header.state_code, @hpxml.pv_systems, 2007)
    assert(File.exist?(bills_csv))
    actual_bills = _get_actual_bills(bills_csv)
    @expected_bills['Electricity: PV Credit ($)'] = -178
    @expected_bills['Electricity: Total ($)'] = 609
    @expected_bills['Total ($)'] = 1415
    _check_bills(@expected_bills, actual_bills)
  end

  def test_simple_calculations_pv_10kW_feed_in_tariff
    @args_hash['pv_compensation_type'] = 'Feed-In Tariff'
    fuels, utility_rates, utility_bills = @measure.setup_outputs()
    _load_timeseries(fuels, '../tests/PV_10kW.csv')
    @hpxml.pv_systems.each { |pv_system| pv_system.max_power_output = 5000 }
    bills_csv = _bill_calcs(fuels, utility_rates, utility_bills, @hpxml.header.state_code, @hpxml.pv_systems, 2007)
    assert(File.exist?(bills_csv))
    actual_bills = _get_actual_bills(bills_csv)
    @expected_bills['Electricity: PV Credit ($)'] = -1786
    @expected_bills['Electricity: Total ($)'] = -999
    @expected_bills['Total ($)'] = -193
    _check_bills(@expected_bills, actual_bills)
  end

  def test_simple_calculations_pv_1kW_grid_fee_dollars_per_kW
    @args_hash['pv_monthly_grid_connection_fee'] = 2.50
    fuels, utility_rates, utility_bills = @measure.setup_outputs()
    _load_timeseries(fuels, '../tests/PV_1kW.csv')
    @hpxml.pv_systems.each { |pv_system| pv_system.max_power_output = 500 }
    bills_csv = _bill_calcs(fuels, utility_rates, utility_bills, @hpxml.header.state_code, @hpxml.pv_systems, 2007)
    assert(File.exist?(bills_csv))
    actual_bills = _get_actual_bills(bills_csv)
    @expected_bills['Electricity: Fixed ($)'] = 126
    @expected_bills['Electricity: PV Credit ($)'] = -195
    @expected_bills['Electricity: Total ($)'] = 622
    @expected_bills['Total ($)'] = 1428
    _check_bills(@expected_bills, actual_bills)
  end

  def test_simple_calculations_pv_1kW_grid_fee_dollars
    @args_hash['pv_grid_connection_fee_units'] = '$'
    @args_hash['pv_monthly_grid_connection_fee'] = 7.50
    fuels, utility_rates, utility_bills = @measure.setup_outputs()
    _load_timeseries(fuels, '../tests/PV_1kW.csv')
    @hpxml.pv_systems.each { |pv_system| pv_system.max_power_output = 500 }
    bills_csv = _bill_calcs(fuels, utility_rates, utility_bills, @hpxml.header.state_code, @hpxml.pv_systems, 2007)
    assert(File.exist?(bills_csv))
    actual_bills = _get_actual_bills(bills_csv)
    @expected_bills['Electricity: Fixed ($)'] = 186
    @expected_bills['Electricity: PV Credit ($)'] = -195
    @expected_bills['Electricity: Total ($)'] = 682
    @expected_bills['Total ($)'] = 1488
    _check_bills(@expected_bills, actual_bills)
  end

  def test_workflow_wood_cord
    # expected values not from BEopt
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-hvac-furnace-wood-only.xml'
    @args_hash['wood_cord_marginal_rate'] = 0.0500
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    actual_bills = _get_actual_bills(bills_csv)
    @expected_bills['Electricity: Fixed ($)'] = 96
    @expected_bills['Electricity: Marginal ($)'] = 1186
    @expected_bills['Electricity: Total ($)'] = 1282
    @expected_bills['Natural Gas: Fixed ($)'] = 0
    @expected_bills['Natural Gas: Marginal ($)'] = 0
    @expected_bills['Natural Gas: Total ($)'] = 0
    @expected_bills['Fuel Oil: Total ($)'] = 0
    @expected_bills['Propane: Total ($)'] = 0
    @expected_bills['Wood Cord: Total ($)'] = 753
    @expected_bills['Total ($)'] = 2035
    _check_bills(@expected_bills, actual_bills)
  end

  def test_workflow_wood_pellets
    # expected values not from BEopt
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-hvac-stove-wood-pellets-only.xml'
    @args_hash['wood_pellets_marginal_rate'] = 0.0500
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    actual_bills = _get_actual_bills(bills_csv)
    @expected_bills['Electricity: Fixed ($)'] = 96
    @expected_bills['Electricity: Marginal ($)'] = 1172
    @expected_bills['Electricity: Total ($)'] = 1268
    @expected_bills['Natural Gas: Fixed ($)'] = 0
    @expected_bills['Natural Gas: Marginal ($)'] = 0
    @expected_bills['Natural Gas: Total ($)'] = 0
    @expected_bills['Fuel Oil: Total ($)'] = 0
    @expected_bills['Propane: Total ($)'] = 0
    @expected_bills['Wood Pellets: Total ($)'] = 713
    @expected_bills['Total ($)'] = 1981
    _check_bills(@expected_bills, actual_bills)
  end

  def test_workflow_coal
    # expected values not from BEopt
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-hvac-furnace-coal-only.xml'
    @args_hash['coal_marginal_rate'] = 0.0500
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    actual_bills = _get_actual_bills(bills_csv)
    @expected_bills['Electricity: Fixed ($)'] = 96
    @expected_bills['Electricity: Marginal ($)'] = 1186
    @expected_bills['Electricity: Total ($)'] = 1282
    @expected_bills['Natural Gas: Fixed ($)'] = 0
    @expected_bills['Natural Gas: Marginal ($)'] = 0
    @expected_bills['Natural Gas: Total ($)'] = 0
    @expected_bills['Fuel Oil: Total ($)'] = 0
    @expected_bills['Propane: Total ($)'] = 0
    @expected_bills['Coal: Total ($)'] = 753
    @expected_bills['Total ($)'] = 2035
    _check_bills(@expected_bills, actual_bills)
  end

  def test_workflow_leap_year
    # expected values not from BEopt
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-location-AMY-2012.xml'
    bills_csv = _test_measure()
    assert(File.exist?(bills_csv))
    actual_bills = _get_actual_bills(bills_csv)
    @expected_bills['Electricity: Fixed ($)'] = 96
    @expected_bills['Electricity: Marginal ($)'] = 1339
    @expected_bills['Electricity: Total ($)'] = 1435
    @expected_bills['Natural Gas: Fixed ($)'] = 96
    @expected_bills['Natural Gas: Marginal ($)'] = 182
    @expected_bills['Natural Gas: Total ($)'] = 278
    @expected_bills['Fuel Oil: Total ($)'] = 0
    @expected_bills['Propane: Total ($)'] = 0
    @expected_bills['Total ($)'] = 1713
    _check_bills(@expected_bills, actual_bills)
  end

  def test_warning_region
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-appliances-oil-location-miami-fl.xml'
    expected_warning = 'Could not find state average Fuel Oil rate based on Florida; using region (PADD 1C) average.'
    bills_csv = _test_measure(expected_warning: expected_warning)
    assert(File.exist?(bills_csv))
  end

  def test_warning_national
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-appliances-propane-location-portland-or.xml'
    expected_warning = 'Could not find state average Propane rate based on Oregon; using national average.'
    bills_csv = _test_measure(expected_warning: expected_warning)
    assert(File.exist?(bills_csv))
  end

  def test_error_semi_annual_run_period
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-simcontrol-runperiod-1-month.xml'
    expected_error = 'A full annual simulation is required for calculating utility bills.'
    bills_csv = _test_measure(expected_error: expected_error)
    assert(!File.exist?(bills_csv))
  end

  def test_error_user_specified_but_no_rates
    skip
    @args_hash['electricity_bill_type'] = 'Detailed'
    @args_hash['electricity_utility_rate_type'] = 'User-Specified'
    expected_error = 'Must specify a utility rate json path when choosing User-Specified utility rate type.'
    bills_csv = _test_measure(expected_error: expected_error)
    assert(!File.exist?(bills_csv))
  end

  def test_error_dse
    @args_hash['hpxml_path'] = '../workflow/sample_files/base-hvac-dse.xml'
    expected_error = 'DSE is not currently supported when calculating utility bills.'
    bills_csv = _test_measure(expected_error: expected_error)
    assert(!File.exist?(bills_csv))
  end

  def _check_bills(expected_bills, actual_bills)
    bills = expected_bills.keys | actual_bills.keys
    bills.each do |bill|
      assert(expected_bills.keys.include?(bill))
      assert(actual_bills.keys.include?(bill))
      assert_in_delta(expected_bills[bill], actual_bills[bill], 1) # within a dollar
    end
  end

  def _get_actual_bills(bills_csv)
    actual_bills = {}
    File.readlines(bills_csv).each do |line|
      next if line.strip.empty?

      key, value = line.split(',').map { |x| x.strip }
      actual_bills[key] = Float(value)
    end
    return actual_bills
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
      fuel.timeseries = [0] * fuels[[FT::Elec, false]].timeseries.size if fuel.timeseries.empty?
    end
  end

  def _bill_calcs(fuels, utility_rates, utility_bills, state_code, pv_systems, sim_calendar_year)
    args = Hash[@args_hash.collect { |k, v| [k.to_sym, v] }]
    args[:electricity_bill_type] = 'Simple'
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    output_format = 'csv'
    output_path = File.join(File.dirname(__FILE__), "results_bills.#{output_format}")

    @measure.get_utility_rates(fuels, utility_rates, args, state_code, pv_systems)
    net_elec = @measure.get_utility_bills(fuels, utility_rates, utility_bills, args, sim_calendar_year)
    @measure.annual_true_up(utility_rates, utility_bills, net_elec)
    @measure.get_annual_bills(utility_bills)

    @measure.write_output(runner, utility_bills, output_format, output_path)

    bills_csv = File.join(File.dirname(__FILE__), 'results_bills.csv')

    return bills_csv
  end

  def _test_measure(expected_error: nil, expected_warning: nil)
    # Run measure via OSW
    require 'json'
    template_osw = File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'template.osw')
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
    command = "#{OpenStudio.getOpenStudioCLI} run -w #{osw_path}"
    cli_output = `#{command}`

    # Cleanup
    File.delete(osw_path)

    bills_csv = File.join(File.dirname(template_osw), 'run', 'results_bills.csv')

    # check warnings/errors
    if not expected_error.nil?
      assert(cli_output.include?(expected_error))
    end
    if not expected_warning.nil?
      assert(cli_output.include?(expected_warning))
    end

    return bills_csv
  end
end
