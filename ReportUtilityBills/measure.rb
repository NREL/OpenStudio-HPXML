# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'msgpack'
require_relative 'resources/util.rb'
require_relative '../HPXMLtoOpenStudio/resources/constants.rb'
require_relative '../HPXMLtoOpenStudio/resources/location.rb'
require_relative '../HPXMLtoOpenStudio/resources/meta_measure.rb'
require_relative '../HPXMLtoOpenStudio/resources/output.rb'
require_relative '../HPXMLtoOpenStudio/resources/util'

# start the measure
class ReportUtilityBills < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Utility Bills Report'
  end

  # human readable description
  def description
    return 'Calculates and reports utility bills for residential HPXML-based models.'
  end

  # human readable description of modeling approach
  def modeler_description
    return "Calculate electric/gas utility bills based on monthly fixed charges and marginal rates. Calculate other utility bills based on marginal rates for oil, propane, wood cord, wood pellets, and coal. User can specify PV compensation types of 'Net-Metering' or 'Feed-In Tariff', along with corresponding rates and connection fees."
  end

  # define the arguments that the user will input
  def arguments(model = nil) # rubocop:disable Lint/UnusedMethodArgument
    args = OpenStudio::Measure::OSArgumentVector.new

    format_chs = OpenStudio::StringVector.new
    format_chs << 'csv'
    format_chs << 'json'
    format_chs << 'msgpack'
    # format_chs << 'csv_dview': # TODO: support this
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('output_format', format_chs, false)
    arg.setDisplayName('Output Format')
    arg.setDescription('The file format of the annual (and timeseries, if requested) outputs.')
    arg.setDefaultValue('csv')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_annual_bills', false)
    arg.setDisplayName('Generate Annual Utility Bills')
    arg.setDescription('Generates annual utility bills.')
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_monthly_bills', false)
    arg.setDisplayName('Generate Monthly Utility Bills')
    arg.setDescription('Generates monthly utility bills.')
    arg.setDefaultValue(true)
    args << arg

    timestamp_chs = OpenStudio::StringVector.new
    timestamp_chs << 'start'
    timestamp_chs << 'end'
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('monthly_timestamp_convention', timestamp_chs, false)
    arg.setDisplayName('Generate Monthly Output: Timestamp Convention')
    arg.setDescription('Determines whether monthly timestamps use the start-of-period or end-of-period convention.')
    arg.setDefaultValue('start')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('annual_output_file_name', false)
    arg.setDisplayName('Annual Output File Name')
    arg.setDescription("If not provided, defaults to 'results_bills.csv' (or 'results_bills.json' or 'results_bills.msgpack').")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('monthly_output_file_name', false)
    arg.setDisplayName('Monthly Output File Name')
    arg.setDescription("If not provided, defaults to 'results_bills_monthly.csv' (or 'results_bills_monthly.json' or 'results_bills_monthly.msgpack').")
    args << arg

    return args
  end

  def check_for_return_type_warnings()
    warnings = []

    # Require full annual simulation if PV
    if !(@hpxml_header.sim_begin_month == 1 && @hpxml_header.sim_begin_day == 1 && @hpxml_header.sim_end_month == 12 && @hpxml_header.sim_end_day == 31)
      if @hpxml_buildings.select { |hpxml_bldg| !hpxml_bldg.pv_systems.empty? }.size > 0
        warnings << 'A full annual simulation is required for calculating utility bills for homes with PV.'
      end
    end

    # Require not DSE
    @hpxml_buildings.each do |hpxml_bldg|
      (hpxml_bldg.heating_systems + hpxml_bldg.heat_pumps).each do |htg_system|
        next unless (htg_system.is_a?(HPXML::HeatingSystem) && htg_system.is_heat_pump_backup_system) || htg_system.fraction_heat_load_served > 0
        next if htg_system.distribution_system_idref.nil?
        next unless htg_system.distribution_system.distribution_system_type == HPXML::HVACDistributionTypeDSE
        next if htg_system.distribution_system.annual_heating_dse.nil?
        next if htg_system.distribution_system.annual_heating_dse == 1

        warnings << 'DSE is not currently supported when calculating utility bills.'
      end
      (hpxml_bldg.cooling_systems + hpxml_bldg.heat_pumps).each do |clg_system|
        next unless clg_system.fraction_cool_load_served > 0
        next if clg_system.distribution_system_idref.nil?
        next unless clg_system.distribution_system.distribution_system_type == HPXML::HVACDistributionTypeDSE
        next if clg_system.distribution_system.annual_cooling_dse.nil?
        next if clg_system.distribution_system.annual_cooling_dse == 1

        warnings << 'DSE is not currently supported when calculating utility bills.'
      end
    end

    return warnings.uniq
  end

  def check_for_next_type_warnings(utility_bill_scenario)
    warnings = []

    # Require full annual simulation if 'Detailed'
    if !(@hpxml_header.sim_begin_month == 1 && @hpxml_header.sim_begin_day == 1 && @hpxml_header.sim_end_month == 12 && @hpxml_header.sim_end_day == 31)
      if !utility_bill_scenario.elec_tariff_filepath.nil?
        warnings << 'A full annual simulation is required for calculating detailed utility bills.'
      end
    end

    return warnings.uniq
  end

  def get_arguments(runner, arguments, user_arguments)
    args = get_argument_values(runner, arguments, user_arguments)
    args.each do |k, val|
      if val.respond_to?(:is_initialized) && val.is_initialized
        args[k] = val.get
      elsif k.start_with?('include_annual')
        args[k] = true # default if not provided
      elsif k.start_with?('include_monthly')
        args[k] = true # default if not provided
      else
        args[k] = nil # default if not provided
      end
    end
    return args
  end

  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    result = OpenStudio::IdfObjectVector.new
    return result if runner.halted

    model = runner.lastOpenStudioModel
    if model.empty?
      return result
    end

    @model = model.get

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return result
    end

    hpxml_defaults_path = @model.getBuilding.additionalProperties.getFeatureAsString('hpxml_defaults_path').get
    building_id = @model.getBuilding.additionalProperties.getFeatureAsString('building_id').get
    hpxml = HPXML.new(hpxml_path: hpxml_defaults_path, building_id: building_id)

    @hpxml_header = hpxml.header
    @hpxml_buildings = hpxml.buildings
    if @hpxml_header.utility_bill_scenarios.has_detailed_electric_rates
      uses_unit_multipliers = @hpxml_buildings.select { |hpxml_bldg| hpxml_bldg.building_construction.number_of_units > 1 }.size > 0
      if uses_unit_multipliers || (@hpxml_buildings.size > 1 && building_id == 'ALL')
        return result
      end
    end

    warnings = check_for_return_type_warnings()
    return result if !warnings.empty?

    fuels = setup_fuel_outputs()

    hpxml_fuel_map = { FT::Elec => HPXML::FuelTypeElectricity,
                       FT::Gas => HPXML::FuelTypeNaturalGas,
                       FT::Oil => HPXML::FuelTypeOil,
                       FT::Propane => HPXML::FuelTypePropane,
                       FT::WoodCord => HPXML::FuelTypeWoodCord,
                       FT::WoodPellets => HPXML::FuelTypeWoodPellets,
                       FT::Coal => HPXML::FuelTypeCoal }

    # Check for presence of fuels once
    has_fuel = hpxml.has_fuels(Constants.FossilFuels, hpxml.to_doc)
    has_fuel[HPXML::FuelTypeElectricity] = true

    # Fuel outputs
    has_pv = @hpxml_buildings.select { |hpxml_bldg| !hpxml_bldg.pv_systems.empty? }.size > 0
    fuels.each do |(fuel_type, is_production), fuel|
      fuel.meters.each do |meter|
        next unless has_fuel[hpxml_fuel_map[fuel_type]]
        next if is_production && !has_pv

        result << OpenStudio::IdfObject.load("Output:Meter,#{meter},monthly;").get
        if fuel_type == FT::Elec && @hpxml_header.utility_bill_scenarios.has_detailed_electric_rates
          result << OpenStudio::IdfObject.load("Output:Meter,#{meter},hourly;").get
        else
          result << OpenStudio::IdfObject.load("Output:Meter,#{meter},monthly;").get
        end
      end
    end

    return result.uniq
  end

  def register_warnings(runner, warnings)
    return false if warnings.empty?

    warnings.each do |warning|
      runner.registerWarning(warning)
    end
    return true
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find OpenStudio model.')
      return false
    end
    @model = model.get

    # use the built-in error checking (need model)
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    args = get_arguments(runner, arguments(model), user_arguments)

    hpxml_path = @model.getBuilding.additionalProperties.getFeatureAsString('hpxml_path').get
    hpxml_defaults_path = @model.getBuilding.additionalProperties.getFeatureAsString('hpxml_defaults_path').get
    output_dir = File.dirname(hpxml_defaults_path)
    building_id = @model.getBuilding.additionalProperties.getFeatureAsString('building_id').get
    hpxml = HPXML.new(hpxml_path: hpxml_defaults_path, building_id: building_id)

    @hpxml_header = hpxml.header
    @hpxml_buildings = hpxml.buildings
    if @hpxml_header.utility_bill_scenarios.has_detailed_electric_rates
      uses_unit_multipliers = @hpxml_buildings.select { |hpxml_bldg| hpxml_bldg.building_construction.number_of_units > 1 }.size > 0
      if uses_unit_multipliers || @hpxml_buildings.size > 1
        runner.registerWarning('Cannot currently calculate utility bills based on detailed electric rates for an HPXML with unit multipliers or multiple Building elements.')
        return false
      end
    end

    return true if @hpxml_header.utility_bill_scenarios.empty?

    if not File.exist? File.join(output_dir, 'eplusout.msgpack')
      runner.registerError('Cannot find eplusout.msgpack.')
      return false
    end
    @msgpackData = MessagePack.unpack(File.read(File.join(output_dir, 'eplusout.msgpack'), mode: 'rb'))

    warnings = check_for_return_type_warnings()
    if register_warnings(runner, warnings)
      return true
    end

    # Set paths
    if not args[:annual_output_file_name].nil?
      annual_output_path = File.join(output_dir, args[:annual_output_file_name])
    else
      annual_output_path = File.join(output_dir, "results_bills.#{args[:output_format]}")
    end
    if not args[:monthly_output_file_name].nil?
      monthly_output_path = File.join(output_dir, args[:monthly_output_file_name])
    else
      monthly_output_path = File.join(output_dir, "results_bills_monthly.#{args[:output_format]}")
    end

    if args[:include_monthly_bills]
      @timestamps = get_timestamps(args)
    end

    num_units = @hpxml_buildings.collect { |hpxml_bldg| hpxml_bldg.building_construction.number_of_units }.sum

    monthly_data = []
    @hpxml_header.utility_bill_scenarios.each do |utility_bill_scenario|
      warnings = check_for_next_type_warnings(utility_bill_scenario)
      if register_warnings(runner, warnings)
        next
      end

      # Setup fuel outputs
      fuels = setup_fuel_outputs()

      # Get outputs
      get_outputs(fuels, utility_bill_scenario)

      # Setup utility outputs
      utility_rates, utility_bills = setup_utility_outputs()

      # Get PV monthly fee
      monthly_fee = get_monthly_fee(utility_bill_scenario, @hpxml_buildings)

      # Get utility rates
      warnings = get_utility_rates(hpxml_path, fuels, utility_rates, utility_bill_scenario, monthly_fee, num_units)
      if register_warnings(runner, warnings)
        next
      end

      # Calculate utility bills
      get_utility_bills(fuels, utility_rates, utility_bills, utility_bill_scenario, @hpxml_header)

      # Write/report runperiod results
      report_runperiod_output_results(runner, args, utility_bills, annual_output_path, utility_bill_scenario.name)

      # Get monthly results
      get_monthly_output_results(args, utility_bills, utility_bill_scenario.name, monthly_data, @hpxml_header)
    end

    # Write/report monthly results
    report_monthly_output_results(runner, args, @timestamps, monthly_data, monthly_output_path)

    return true
  end

  def get_monthly_fee(bill_scenario, hpxml_buildings)
    monthly_fee = 0.0
    if not bill_scenario.pv_monthly_grid_connection_fee_dollars_per_kw.nil?
      hpxml_buildings.each do |hpxml_bldg|
        hpxml_bldg.pv_systems.each do |pv_system|
          max_power_output_kW = UnitConversions.convert(pv_system.max_power_output, 'W', 'kW')
          monthly_fee += bill_scenario.pv_monthly_grid_connection_fee_dollars_per_kw * max_power_output_kW
          monthly_fee *= hpxml_bldg.building_construction.number_of_units if !hpxml_bldg.building_construction.number_of_units.nil?
        end
      end
    elsif not bill_scenario.pv_monthly_grid_connection_fee_dollars.nil?
      monthly_fee = bill_scenario.pv_monthly_grid_connection_fee_dollars
    end

    return monthly_fee
  end

  def get_timestamps(args)
    ep_timestamps = @msgpackData['MeterData']['Monthly']['Rows'].map { |r| r.keys[0] }

    timestamps = []
    year = @hpxml_header.sim_calendar_year
    ep_timestamps.each do |ep_timestamp|
      month_day, hour_minute = ep_timestamp.split(' ')
      month, day = month_day.split('/').map(&:to_i)
      hour, minute, _ = hour_minute.split(':').map(&:to_i)

      # Convert from EnergyPlus default (end-of-timestep) to start-of-timestep convention
      if args[:monthly_timestamp_convention] == 'start'
        ts_offset = Constants.NumDaysInMonths(year)[month - 1] * 60 * 60 * 24 # seconds
      end

      ts = Time.utc(year, month, day, hour, minute)
      ts -= ts_offset unless ts_offset.nil?

      timestamps << ts.iso8601.delete('Z')
    end

    return timestamps
  end

  def report_runperiod_output_results(runner, args, utility_bills, annual_output_path, bill_scenario_name)
    return unless args[:include_annual_bills]

    results_out = []
    results_out << ["#{bill_scenario_name}: Total (USD)", utility_bills.values.sum { |bill| bill.annual_total.round(2) }.round(2)]

    utility_bills.each do |fuel_type, bill|
      results_out << ["#{bill_scenario_name}: #{fuel_type}: Fixed (USD)", bill.annual_fixed_charge.round(2)]
      results_out << ["#{bill_scenario_name}: #{fuel_type}: Energy (USD)", bill.annual_energy_charge.round(2)]
      results_out << ["#{bill_scenario_name}: #{fuel_type}: PV Credit (USD)", bill.annual_production_credit.round(2)] if [FT::Elec].include?(fuel_type)
      results_out << ["#{bill_scenario_name}: #{fuel_type}: Total (USD)", bill.annual_total.round(2)]
    end

    line_break = nil
    results_out << [line_break]

    if ['csv'].include? args[:output_format]
      CSV.open(annual_output_path, 'a') { |csv| results_out.to_a.each { |elem| csv << elem } }
    elsif ['json', 'msgpack'].include? args[:output_format]
      h = {}
      results_out.each do |out|
        next if out == [line_break]

        if out[0].include? ':'
          grp, name = out[0].split(':', 2)
          h[grp] = {} if h[grp].nil?
          h[grp][name.strip] = out[1]
        else
          h[out[0]] = out[1]
        end
      end

      if args[:output_format] == 'json'
        require 'json'
        File.open(annual_output_path, 'a') { |json| json.write(JSON.pretty_generate(h)) }
      elsif args[:output_format] == 'msgpack'
        File.open(annual_output_path, 'a') { |json| h.to_msgpack(json) }
      end
    end
    runner.registerInfo("Wrote annual bills output to #{annual_output_path}.")

    results_out.each do |name, value|
      next if name.nil? || value.nil?

      name = OpenStudio::toUnderscoreCase(name).chomp('_')

      runner.registerValue(name, value)
      runner.registerInfo("Registering #{value} for #{name}.")
    end
  end

  def get_monthly_output_results(args, utility_bills, bill_scenario_name, monthly_data, header)
    run_period = (header.sim_begin_month - 1)..(header.sim_end_month - 1)
    monthly_data << ["#{bill_scenario_name}: Total", 'USD'] + ([0.0] * run_period.size)
    total_ix = monthly_data.size - 1

    if args[:include_monthly_bills]
      utility_bills.each do |fuel_type, bill|
        monthly_data[total_ix][2..-1] = monthly_data[total_ix][2..-1].zip(bill.monthly_total[run_period].map { |v| v.round(2) }).map { |x, y| x + y }
        monthly_data << ["#{bill_scenario_name}: #{fuel_type}: Fixed", 'USD'] + bill.monthly_fixed_charge[run_period].map { |v| v.round(2) }
        monthly_data << ["#{bill_scenario_name}: #{fuel_type}: Energy", 'USD'] + bill.monthly_energy_charge[run_period].map { |v| v.round(2) }
        monthly_data << ["#{bill_scenario_name}: #{fuel_type}: PV Credit", 'USD'] + bill.monthly_production_credit[run_period].map { |v| v.round(2) } if [FT::Elec].include?(fuel_type)
        monthly_data << ["#{bill_scenario_name}: #{fuel_type}: Total", 'USD'] + bill.monthly_total[run_period].map { |v| v.round(2) }
      end
    end
  end

  def report_monthly_output_results(runner, args, timestamps, monthly_data, monthly_output_path)
    return if timestamps.nil?

    # Initial output data w/ Time column(s)
    data = ['Time', nil] + timestamps

    return if (monthly_data.size) == 0

    fail 'Unable to obtain timestamps.' if timestamps.empty?

    if ['csv'].include? args[:output_format]
      # Assemble data
      data = data.zip(*monthly_data)

      # Write file
      CSV.open(monthly_output_path, 'wb') { |csv| data.to_a.each { |elem| csv << elem } }
    elsif ['json', 'msgpack'].include? args[:output_format]
      h = {}
      h['Time'] = data[2..-1]

      [monthly_data].each do |d|
        d.each do |o|
          grp, name = o[0].split(':', 2)
          h[grp] = {} if h[grp].nil?
          h[grp]["#{name.strip} (#{o[1]})"] = o[2..-1]
        end
      end

      if args[:output_format] == 'json'
        require 'json'
        File.open(monthly_output_path, 'w') { |json| json.write(JSON.pretty_generate(h)) }
      elsif args[:output_format] == 'msgpack'
        File.open(monthly_output_path, 'w') { |json| h.to_msgpack(json) }
      end
    end
    runner.registerInfo("Wrote monthly bills output to #{monthly_output_path}.")
  end

  def get_utility_rates(hpxml_path, fuels, utility_rates, bill_scenario, monthly_fee, num_units = 1)
    warnings = []
    utility_rates.each do |fuel_type, rate|
      next if fuels[[fuel_type, false]].timeseries.sum == 0

      if fuel_type == FT::Elec
        if bill_scenario.elec_tariff_filepath.nil?
          rate.fixedmonthlycharge = bill_scenario.elec_fixed_charge
          rate.flatratebuy = bill_scenario.elec_marginal_rate
        else
          require 'json'

          filepath = FilePath.check_path(bill_scenario.elec_tariff_filepath,
                                         File.dirname(hpxml_path),
                                         'Tariff File')

          tariff = JSON.parse(File.read(filepath), symbolize_names: true)
          tariff = tariff[:items][0]
          fields = tariff.keys

          rate.fixedmonthlycharge = 0.0
          if fields.include?(:fixedchargeunits)
            if tariff[:fixedchargeunits] == '$/month'
              rate.fixedmonthlycharge += tariff[:fixedchargefirstmeter] if fields.include?(:fixedchargefirstmeter)
              rate.fixedmonthlycharge += tariff[:fixedchargeeaaddl] if fields.include?(:fixedchargeeaaddl)
            else
              warnings << 'Fixed charge units must be $/month.'
            end
          end

          if fields.include?(:minchargeunits)
            if tariff[:minchargeunits] == '$/month'
              rate.minmonthlycharge = tariff[:mincharge] if fields.include?(:mincharge)
            elsif tariff[:minchargeunits] == '$/year'
              rate.minannualcharge = tariff[:mincharge] if fields.include?(:mincharge)
            else
              warnings << 'Min charge units must be either $/month or $/year.'
            end
          end

          if fields.include?(:realtimepricing)
            rate.realtimeprice = tariff[:realtimepricing]

          else
            if !fields.include?(:energyweekdayschedule) || !fields.include?(:energyweekendschedule) || !fields.include?(:energyratestructure)
              warnings << 'Tariff file must contain energyweekdayschedule, energyweekendschedule, and energyratestructure fields.'
            end

            if fields.include?(:demandweekdayschedule) || fields.include?(:demandweekendschedule) || fields.include?(:demandratestructure) || fields.include?(:flatdemandstructure)
              warnings << 'Demand charges are not currently supported when calculating detailed utility bills.'
            end

            rate.energyratestructure = tariff[:energyratestructure]
            rate.energyweekdayschedule = tariff[:energyweekdayschedule]
            rate.energyweekendschedule = tariff[:energyweekendschedule]

            if rate.energyratestructure.collect { |r| r.collect { |s| s.keys.include?(:rate) } }.flatten.any? { |t| !t }
              warnings << 'Every tier must contain a rate.'
            end

            if rate.energyratestructure.collect { |r| r.collect { |s| s.keys } }.flatten.uniq.include?(:sell)
              warnings << 'No tier may contain a sell key.'
            end

            if rate.energyratestructure.collect { |r| r.collect { |s| s.keys.include?(:unit) } }.flatten.any? { |t| !t }
              warnings << 'Every tier must contain a unit'
            end

            if rate.energyratestructure.collect { |r| r.collect { |s| s[:unit] == 'kWh' } }.flatten.any? { |t| !t }
              warnings << 'All rates must be in units of kWh.'
            end
          end
        end

        # Net Metering
        rate.net_metering_excess_sellback_type = bill_scenario.pv_net_metering_annual_excess_sellback_rate_type if bill_scenario.pv_compensation_type == HPXML::PVCompensationTypeNetMetering
        rate.net_metering_user_excess_sellback_rate = bill_scenario.pv_net_metering_annual_excess_sellback_rate if rate.net_metering_excess_sellback_type == HPXML::PVAnnualExcessSellbackRateTypeUserSpecified

        # Feed-In Tariff
        rate.feed_in_tariff_rate = bill_scenario.pv_feed_in_tariff_rate if bill_scenario.pv_compensation_type == HPXML::PVCompensationTypeFeedInTariff
      elsif fuel_type == FT::Gas
        rate.fixedmonthlycharge = bill_scenario.natural_gas_fixed_charge
        rate.flatratebuy = bill_scenario.natural_gas_marginal_rate
      elsif fuel_type == FT::Oil
        rate.fixedmonthlycharge = bill_scenario.fuel_oil_fixed_charge
        rate.flatratebuy = bill_scenario.fuel_oil_marginal_rate
      elsif fuel_type == FT::Propane
        rate.fixedmonthlycharge = bill_scenario.propane_fixed_charge
        rate.flatratebuy = bill_scenario.propane_marginal_rate
      elsif fuel_type == FT::WoodCord
        rate.fixedmonthlycharge = bill_scenario.wood_fixed_charge
        rate.flatratebuy = bill_scenario.wood_marginal_rate
      elsif fuel_type == FT::WoodPellets
        rate.fixedmonthlycharge = bill_scenario.wood_pellets_fixed_charge
        rate.flatratebuy = bill_scenario.wood_pellets_marginal_rate
      elsif fuel_type == FT::Coal
        rate.fixedmonthlycharge = bill_scenario.coal_fixed_charge
        rate.flatratebuy = bill_scenario.coal_marginal_rate
      end
      rate.fixedmonthlycharge *= num_units if !rate.fixedmonthlycharge.nil?

      warnings << "Could not find a marginal #{fuel_type} rate." if rate.flatratebuy.nil?

      # Grid connection fee
      next unless fuel_type == FT::Elec

      rate.fixedmonthlycharge += monthly_fee
    end
    return warnings
  end

  def get_utility_bills(fuels, utility_rates, utility_bills, utility_bill_scenario, header)
    net_elec = 0

    # Simple
    fuels.each do |(fuel_type, is_production), fuel|
      rate = utility_rates[fuel_type]
      bill = utility_bills[fuel_type]

      if fuel_type == FT::Elec
        if utility_bill_scenario.elec_tariff_filepath.nil?
          net_elec = CalculateUtilityBill.simple(fuel_type, header, fuel.timeseries, is_production, rate, bill, net_elec)
        end
      else
        net_elec = CalculateUtilityBill.simple(fuel_type, header, fuel.timeseries, is_production, rate, bill, net_elec)
      end
    end

    # Detailed
    if !utility_bill_scenario.elec_tariff_filepath.nil?
      rate = utility_rates[FT::Elec]
      bill = utility_bills[FT::Elec]

      CalculateUtilityBill.detailed_electric(header, fuels, rate, bill)
    end

    # Calculate totals
    utility_bills.values.each do |bill|
      if bill.annual_production_credit != 0
        bill.annual_production_credit *= -1

        # Report the PV credit at the end of the year for all scenarios.
        for month in 0..10
          bill.monthly_production_credit[month] = 0.0
        end
        bill.monthly_production_credit[11] = bill.annual_production_credit
      end

      bill.annual_total = bill.annual_fixed_charge + bill.annual_energy_charge + bill.annual_production_credit
      bill.monthly_total = [bill.monthly_fixed_charge, bill.monthly_energy_charge, bill.monthly_production_credit].transpose.map { |x| x.reduce(:+) }
    end
  end

  def setup_fuel_outputs()
    def get_timeseries_units_from_fuel_type(fuel_type)
      if fuel_type == FT::Elec
        return 'kWh'
      elsif fuel_type == FT::Gas
        return 'therm'
      end

      return 'kBtu'
    end

    fuels = {}
    fuels[[FT::Elec, false]] = Fuel.new(meters: ["#{EPlus::FuelTypeElectricity}:Facility"])
    fuels[[FT::Elec, true]] = Fuel.new(meters: ["#{EPlus::FuelTypeElectricity}Produced:Facility"])
    fuels[[FT::Gas, false]] = Fuel.new(meters: ["#{EPlus::FuelTypeNaturalGas}:Facility"])
    fuels[[FT::Oil, false]] = Fuel.new(meters: ["#{EPlus::FuelTypeOil}:Facility"])
    fuels[[FT::Propane, false]] = Fuel.new(meters: ["#{EPlus::FuelTypePropane}:Facility"])
    fuels[[FT::WoodCord, false]] = Fuel.new(meters: ["#{EPlus::FuelTypeWoodCord}:Facility"])
    fuels[[FT::WoodPellets, false]] = Fuel.new(meters: ["#{EPlus::FuelTypeWoodPellets}:Facility"])
    fuels[[FT::Coal, false]] = Fuel.new(meters: ["#{EPlus::FuelTypeCoal}:Facility"])

    fuels.each do |(fuel_type, _is_production), fuel|
      fuel.units = get_timeseries_units_from_fuel_type(fuel_type)
    end

    return fuels
  end

  def setup_utility_outputs()
    utility_rates = {}
    utility_rates[FT::Elec] = UtilityRate.new
    utility_rates[FT::Gas] = UtilityRate.new
    utility_rates[FT::Oil] = UtilityRate.new
    utility_rates[FT::Propane] = UtilityRate.new
    utility_rates[FT::WoodCord] = UtilityRate.new
    utility_rates[FT::WoodPellets] = UtilityRate.new
    utility_rates[FT::Coal] = UtilityRate.new

    utility_bills = {}
    utility_bills[FT::Elec] = UtilityBill.new
    utility_bills[FT::Gas] = UtilityBill.new
    utility_bills[FT::Oil] = UtilityBill.new
    utility_bills[FT::Propane] = UtilityBill.new
    utility_bills[FT::WoodCord] = UtilityBill.new
    utility_bills[FT::WoodPellets] = UtilityBill.new
    utility_bills[FT::Coal] = UtilityBill.new

    return utility_rates, utility_bills
  end

  def get_outputs(fuels, utility_bill_scenario)
    fuels.each do |(fuel_type, _is_production), fuel|
      unit_conv = UnitConversions.convert(1.0, 'J', fuel.units)
      unit_conv /= 139.0 if fuel_type == FT::Oil
      unit_conv /= 91.6 if fuel_type == FT::Propane

      timeseries_freq = 'monthly'
      timeseries_freq = 'hourly' if fuel_type == FT::Elec && !utility_bill_scenario.elec_tariff_filepath.nil?
      fuel.timeseries = get_report_meter_data_timeseries(fuel.meters, unit_conv, 0, timeseries_freq)
    end
  end

  def get_report_meter_data_timeseries(meter_names, unit_conv, unit_adder, timeseries_freq)
    msgpack_timeseries_name = { 'hourly' => 'Hourly',
                                'monthly' => 'Monthly' }[timeseries_freq]
    begin
      data = @msgpackData['MeterData'][msgpack_timeseries_name]
      cols = data['Cols']
      rows = data['Rows']
    rescue
      return [0.0]
    end
    indexes = cols.each_index.select { |i| meter_names.include? cols[i]['Variable'] }
    vals = []
    rows.each do |row|
      row = row[row.keys[0]]
      val = 0.0
      indexes.each do |i|
        val += row[i] * unit_conv + unit_adder
      end
      vals << val
    end
    return vals
  end
end

# register the measure to be used by the application
ReportUtilityBills.new.registerWithApplication
