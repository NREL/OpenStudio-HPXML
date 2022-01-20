# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require_relative 'resources/util.rb'
require_relative '../HPXMLtoOpenStudio/resources/meta_measure.rb'
require_relative '../ReportSimulationOutput/resources/constants.rb'

# start the measure
class ReportUtilityBills < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Utility Bills Report'
  end

  # human readable description
  def description
    return 'TODO'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'TODO'
  end

  # define the arguments that the user will input
  def arguments(model = nil)
    args = OpenStudio::Measure::OSArgumentVector.new

    format_chs = OpenStudio::StringVector.new
    format_chs << 'csv'
    format_chs << 'json'
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('output_format', format_chs, false)
    arg.setDisplayName('Output Format')
    arg.setDescription('The file format of the annual (and timeseries, if requested) outputs.')
    arg.setDefaultValue('csv')
    args << arg

    electricity_bill_type_choices = OpenStudio::StringVector.new
    electricity_bill_type_choices << 'Simple'
    electricity_bill_type_choices << 'Detailed'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('electricity_bill_type', electricity_bill_type_choices, true)
    arg.setDisplayName('Electricity: Simple or Detailed')
    arg.setDescription("Choose either 'Simple' or 'Detailed'. If 'Simple' is selected, electric utility bills are calculated based on user-defined fixed charge and marginal rate. If 'Detailed' is selected, electric utility bills are calculated based on either: a tariff from the OpenEI Utility Rate Database (URDB), or a real-time pricing rate.")
    arg.setDefaultValue('Simple')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('electricity_fixed_charge', true)
    arg.setDisplayName('Electricity: Fixed Charge')
    arg.setUnits('$/month')
    arg.setDescription('Monthly fixed charge for electricity.')
    arg.setDefaultValue(12.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('electricity_marginal_rate', true)
    arg.setDisplayName('Electricity: Marginal Rate')
    arg.setUnits('$/kWh')
    arg.setDescription("Price per kilowatt-hour for electricity. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('natural_gas_fixed_charge', true)
    arg.setDisplayName('Natural Gas: Fixed Charge')
    arg.setUnits('$/month')
    arg.setDescription('Monthly fixed charge for natural gas.')
    arg.setDefaultValue(8.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('natural_gas_marginal_rate', true)
    arg.setDisplayName('Natural Gas: Marginal Rate')
    arg.setUnits('$/therm')
    arg.setDescription("Price per therm for natural gas. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('fuel_oil_marginal_rate', true)
    arg.setDisplayName('Fuel Oil: Marginal Rate')
    arg.setUnits('$/gal')
    arg.setDescription("Price per gallon for fuel oil. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('propane_marginal_rate', true)
    arg.setDisplayName('Propane: Marginal Rate')
    arg.setUnits('$/gal')
    arg.setDescription("Price per gallon for propane. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('wood_cord_marginal_rate', true)
    arg.setDisplayName('Wood Cord: Marginal Rate')
    arg.setUnits('$/kBtu')
    arg.setDescription("Price per kBtu for wood cord. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('wood_pellets_marginal_rate', true)
    arg.setDisplayName('Wood Pellets: Marginal Rate')
    arg.setUnits('$/kBtu')
    arg.setDescription("Price per kBtu for wood pellets. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('coal_marginal_rate', true)
    arg.setDisplayName('Coal: Marginal Rate')
    arg.setUnits('$/kBtu')
    arg.setDescription("Price per kBtu for coal. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    pv_compensation_type_choices = OpenStudio::StringVector.new
    pv_compensation_type_choices << 'Net Metering'
    pv_compensation_type_choices << 'Feed-In Tariff'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_compensation_type', pv_compensation_type_choices, true)
    arg.setDisplayName('PV: Compensation Type')
    arg.setDescription('The type of compensation for PV.')
    arg.setDefaultValue('Net Metering')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_feed_in_tariff_rate', true)
    arg.setDisplayName('PV: Feed-In Tariff Rate')
    arg.setUnits('$/kWh')
    arg.setDescription("The annual full/gross tariff rate for PV. Only applies if the PV compensation type is 'Feed-In Tariff'.")
    arg.setDefaultValue(0.12)
    args << arg

    return args
  end

  def setup_outputs()
    def get_timeseries_units_from_fuel_type(fuel_type)
      if fuel_type == FT::Elec
        return 'kWh'
      elsif fuel_type == FT::Gas
        return 'therm'
      end

      return 'kBtu'
    end

    @fuels = {}
    @fuels[FT::Elec] = Fuel.new(meters: ["#{EPlus::FuelTypeElectricity}:Facility"])
    @fuels[FT::Gas] = Fuel.new(meters: ["#{EPlus::FuelTypeNaturalGas}:Facility"])
    @fuels[FT::Oil] = Fuel.new(meters: ["#{EPlus::FuelTypeOil}:Facility"])
    @fuels[FT::Propane] = Fuel.new(meters: ["#{EPlus::FuelTypePropane}:Facility"])
    @fuels[FT::WoodCord] = Fuel.new(meters: ["#{EPlus::FuelTypeWoodCord}:Facility"])
    @fuels[FT::WoodPellets] = Fuel.new(meters: ["#{EPlus::FuelTypeWoodPellets}:Facility"])
    @fuels[FT::Coal] = Fuel.new(meters: ["#{EPlus::FuelTypeCoal}:Facility"])

    @fuels.each do |fuel_type, fuel|
      fuel.timeseries_units = get_timeseries_units_from_fuel_type(fuel_type)
    end

    @utility_bills = {}
    @utility_bills[FT::Elec] = BaseOutput.new
    @utility_bills[FT::Gas] = BaseOutput.new
    @utility_bills[FT::Oil] = BaseOutput.new
    @utility_bills[FT::Propane] = BaseOutput.new
    @utility_bills[FT::WoodCord] = BaseOutput.new
    @utility_bills[FT::WoodPellets] = BaseOutput.new
    @utility_bills[FT::Coal] = BaseOutput.new
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

    # assign the user inputs to variables
    args = get_argument_values(runner, arguments(model), user_arguments)
    args = Hash[args.collect { |k, v| [k.to_sym, v] }]

    output_format = args[:output_format].get

    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError('Cannot find EnergyPlus sql file.')
      return false
    end
    @sqlFile = sqlFile.get
    if not @sqlFile.connectionOpen
      runner.registerError('EnergyPlus simulation failed.')
      return false
    end
    @model.setSqlFile(@sqlFile)

    hpxml_defaults_path = @model.getBuilding.additionalProperties.getFeatureAsString('hpxml_defaults_path').get
    hpxml = HPXML.new(hpxml_path: hpxml_defaults_path)

    # Require full year
    if !(hpxml.header.sim_begin_month == 1 && hpxml.header.sim_begin_day == 1 && hpxml.header.sim_end_month == 12 && hpxml.header.sim_end_day == 31)
      runner.registerWarning('A full annual simulation is required for calculating utility bills.')
      return true
    end

    # Set paths
    output_dir = File.dirname(@sqlFile.path.to_s)
    output_path = File.join(output_dir, "results_bills.#{output_format}")

    setup_outputs()

    timeseries_frequency = 'monthly'
    @timestamps = [0] * 12 # size is used but not contents

    get_outputs(timeseries_frequency)

    # Utility bills
    @utility_bills.each do |fuel_type, utility_bill|
      if fuel_type == FT::Elec
        fixed_charge = args[:electricity_fixed_charge]
        marginal_rate = args[:electricity_marginal_rate]

        if @total_elec_produced_timeseries.sum != 0
          pv_feed_in_tariff_rate = args[:pv_feed_in_tariff_rate] if args[:pv_compensation_type] == 'Feed-In Tariff'
        end
      elsif fuel_type == FT::Gas
        fixed_charge = args[:natural_gas_fixed_charge]
        marginal_rate = args[:natural_gas_marginal_rate]
      elsif fuel_type == FT::Oil
        marginal_rate = args[:fuel_oil_marginal_rate]
      elsif fuel_type == FT::Propane
        marginal_rate = args[:propane_marginal_rate]
      elsif fuel_type == FT::WoodCord
        marginal_rate = args[:wood_cord_marginal_rate]
      elsif fuel_type == FT::WoodPellets
        marginal_rate = args[:wood_pellets_marginal_rate]
      elsif fuel_type == FT::Coal
        marginal_rate = args[:coal_marginal_rate]
      end

      if marginal_rate == Constants.Auto
        if [FT::Elec, FT::Gas, FT::Oil, FT::Propane].include? fuel_type
          marginal_rate = get_state_average_marginal_rate(hpxml.header.state_code, fuel_type, fixed_charge)
        elsif [FT::WoodCord, FT::WoodPellets, FT::Coal].include? fuel_type
          marginal_rate = 0.1 # FIXME: can we get these somewhere?
        end
      else
        marginal_rate = Float(marginal_rate)
      end

      UtilityBill.calculate_simple(@fuels, fuel_type, utility_bill, fixed_charge, marginal_rate, @total_elec_produced_timeseries, pv_feed_in_tariff_rate)
    end

    # Report results
    @utility_bills.each do |fuel_type, utility_bill|
      utility_bill_type_str = OpenStudio::toUnderscoreCase("#{fuel_type} #{utility_bill.units}")
      utility_bill = utility_bill.total.round(2)
      runner.registerValue(utility_bill_type_str, utility_bill)
    end

    # Write results
    write_output(runner, @utility_bills, output_format, output_path)

    teardown()
    return true
  end

  def get_state_average_marginal_rate(state_code, fuel_type, fixed_charge = nil)
    cols = CSV.read("#{File.dirname(__FILE__)}/resources/#{fuel_type}.csv", { encoding: 'ISO-8859-1' })[3..-1].transpose
    cols[0].each_with_index do |rate_state, i|
      next if rate_state != state_code

      average_rate = Float(cols[1][i])
      if [FT::Elec, FT::Gas].include? fuel_type
        household_consumption = Float(cols[2][i])
        marginal_rate = average_rate - 12.0 * fixed_charge / household_consumption
      elsif [FT::Oil, FT::Propane].include? fuel_type
        marginal_rate = average_rate
      end
      return marginal_rate
    end
  end

  def teardown
    @sqlFile.close()

    # Ensure sql file is immediately freed; otherwise we can get
    # errors on Windows when trying to delete this file.
    GC.start()
  end

  def get_outputs(timeseries_frequency)
    @fuels.each do |fuel_type, fuel|
      unit_conv = UnitConversions.convert(1.0, 'J', fuel.timeseries_units)
      unit_conv /= 139.0 if fuel_type == FT::Oil
      unit_conv /= 91.6 if fuel_type == FT::Propane

      fuel.timeseries_output = get_report_meter_data_timeseries(fuel.meters, unit_conv, 0, timeseries_frequency)
    end
    @total_elec_produced_timeseries = get_report_meter_data_timeseries(['ElectricityProduced:Facility'], UnitConversions.convert(1.0, 'J', get_timeseries_units_from_fuel_type(FT::Elec)), 0, timeseries_frequency)
  end

  def reporting_frequency_map
    return {
      'timestep' => 'Zone Timestep',
      'hourly' => 'Hourly',
      'daily' => 'Daily',
      'monthly' => 'Monthly',
    }
  end

  def get_report_meter_data_timeseries(meter_names, unit_conv, unit_adder, timeseries_frequency)
    return [0.0] * @timestamps.size if meter_names.empty?

    vars = "'" + meter_names.uniq.join("','") + "'"
    query = "SELECT SUM(VariableValue*#{unit_conv}+#{unit_adder}) FROM ReportMeterData WHERE ReportMeterDataDictionaryIndex IN (SELECT ReportMeterDataDictionaryIndex FROM ReportMeterDataDictionary WHERE VariableName IN (#{vars}) AND ReportingFrequency='#{reporting_frequency_map[timeseries_frequency]}' AND VariableUnits='J') GROUP BY TimeIndex ORDER BY TimeIndex"
    values = @sqlFile.execAndReturnVectorOfDouble(query)
    fail "Query error: #{query}" unless values.is_initialized

    values = values.get
    values += [0.0] * @timestamps.size if values.size == 0
    return values
  end

  def write_output(runner, utility_bills, output_format, output_path)
    line_break = nil

    segment, _ = utility_bills.keys[0].split(':', 2)
    segment = segment.strip
    results_out = []
    utility_bills.each do |key, utility_bill|
      new_segment, _ = key.split(':', 2)
      new_segment = new_segment.strip
      if new_segment != segment
        results_out << [line_break]
        segment = new_segment
      end
      results_out << ["#{key}: Fixed (#{utility_bill.units})", utility_bill.fixed.round(2)] if [FT::Elec, FT::Gas].include? key
      results_out << ["#{key}: Marginal (#{utility_bill.units})", utility_bill.marginal.round(2)] if [FT::Elec, FT::Gas].include? key
      results_out << ["#{key}: Total (#{utility_bill.units})", utility_bill.total.round(2)]
    end

    if output_format == 'csv'
      CSV.open(output_path, 'wb') { |csv| results_out.to_a.each { |elem| csv << elem } }
    elsif output_format == 'json'
      h = {}
      results_out.each do |out|
        next if out == [line_break]

        grp, name = out[0].split(':', 2)
        h[grp] = {} if h[grp].nil?
        h[grp][name.strip] = out[1]
      end

      require 'json'
      File.open(output_path, 'w') { |json| json.write(JSON.pretty_generate(h)) }
    end
    runner.registerInfo("Wrote bills output to #{output_path}.")
  end

  class BaseOutput
    def initialize()
      @fixed = 0.0
      @marginal = 0.0
      @total = 0.0
      @units = '$'
    end
    attr_accessor(:fixed, :marginal, :total, :units)
  end

  class Fuel
    def initialize(meters: [])
      @meters = meters
      @timeseries_output = []
    end
    attr_accessor(:meters, :timeseries_output, :timeseries_units)
  end
end

# register the measure to be used by the application
ReportUtilityBills.new.registerWithApplication
