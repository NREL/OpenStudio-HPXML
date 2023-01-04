# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'msgpack'
require_relative '../HPXMLtoOpenStudio/resources/constants.rb'
require_relative '../HPXMLtoOpenStudio/resources/energyplus.rb'
require_relative '../HPXMLtoOpenStudio/resources/hpxml.rb'
require_relative '../HPXMLtoOpenStudio/resources/output.rb'
require_relative '../HPXMLtoOpenStudio/resources/unit_conversions.rb'

# start the measure
class ReportSimulationOutput < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'HPXML Simulation Output Report'
  end

  # human readable description
  def description
    return 'Reports simulation outputs for residential HPXML-based models.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Processes EnergyPlus simulation outputs in order to generate an annual output file and an optional timeseries output file.'
  end

  # define the arguments that the user will input
  def arguments(model) # rubocop:disable Lint/UnusedMethodArgument
    args = OpenStudio::Measure::OSArgumentVector.new

    format_chs = OpenStudio::StringVector.new
    format_chs << 'csv'
    format_chs << 'json'
    format_chs << 'msgpack'
    format_chs << 'csv_dview'
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('output_format', format_chs, false)
    arg.setDisplayName('Output Format')
    arg.setDescription("The file format of the annual (and timeseries, if requested) outputs. If 'csv_dview' is selected, the timeseries CSV file will include header rows that facilitate opening the file in the DView application.")
    arg.setDefaultValue('csv')
    args << arg

    timeseries_frequency_chs = OpenStudio::StringVector.new
    timeseries_frequency_chs << 'none'
    timeseries_frequency_chs << 'timestep'
    timeseries_frequency_chs << 'hourly'
    timeseries_frequency_chs << 'daily'
    timeseries_frequency_chs << 'monthly'
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('timeseries_frequency', timeseries_frequency_chs, false)
    arg.setDisplayName('Timeseries Reporting Frequency')
    arg.setDescription("The frequency at which to report timeseries output data. Using 'none' will disable timeseries outputs.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_total_consumptions', false)
    arg.setDisplayName('Generate Timeseries Output: Total Consumptions')
    arg.setDescription('Generates timeseries energy consumptions for building total.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_fuel_consumptions', false)
    arg.setDisplayName('Generate Timeseries Output: Fuel Consumptions')
    arg.setDescription('Generates timeseries energy consumptions for each fuel type.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_end_use_consumptions', false)
    arg.setDisplayName('Generate Timeseries Output: End Use Consumptions')
    arg.setDescription('Generates timeseries energy consumptions for each end use.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_emissions', false)
    arg.setDisplayName('Generate Timeseries Output: Emissions')
    arg.setDescription('Generates timeseries emissions. Requires the appropriate HPXML inputs to be specified.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_emission_fuels', false)
    arg.setDisplayName('Generate Timeseries Output: Emissions')
    arg.setDescription('Generates timeseries emissions for each fuel type. Requires the appropriate HPXML inputs to be specified.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_emission_end_uses', false)
    arg.setDisplayName('Generate Timeseries Output: Emission End Uses')
    arg.setDescription('Generates timeseries emissions for each end use. Requires the appropriate HPXML inputs to be specified.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_hot_water_uses', false)
    arg.setDisplayName('Generate Timeseries Output: Hot Water Uses')
    arg.setDescription('Generates timeseries hot water usages for each end use.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_total_loads', false)
    arg.setDisplayName('Generate Timeseries Output: Total Loads')
    arg.setDescription('Generates timeseries total heating, cooling, and hot water loads.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_component_loads', false)
    arg.setDisplayName('Generate Timeseries Output: Component Loads')
    arg.setDescription('Generates timeseries heating and cooling loads disaggregated by component type.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_unmet_hours', false)
    arg.setDisplayName('Generate Timeseries Output: Unmet Hours')
    arg.setDescription('Generates timeseries unmet hours for heating and cooling.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_zone_temperatures', false)
    arg.setDisplayName('Generate Timeseries Output: Zone Temperatures')
    arg.setDescription('Generates timeseries temperatures for each thermal zone.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_airflows', false)
    arg.setDisplayName('Generate Timeseries Output: Airflows')
    arg.setDescription('Generates timeseries airflows.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_weather', false)
    arg.setDisplayName('Generate Timeseries Output: Weather')
    arg.setDescription('Generates timeseries weather data.')
    arg.setDefaultValue(false)
    args << arg

    timestamp_chs = OpenStudio::StringVector.new
    timestamp_chs << 'start'
    timestamp_chs << 'end'
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('timeseries_timestamp_convention', timestamp_chs, false)
    arg.setDisplayName('Generate Timeseries Output: Timestamp Convention')
    arg.setDescription("Determines whether timeseries timestamps use the start-of-period or end-of-period convention. Doesn't apply if the output format is 'csv_dview'.")
    arg.setDefaultValue('start')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('timeseries_num_decimal_places', false)
    arg.setDisplayName('Generate Timeseries Output: Number of Decimal Places')
    arg.setDescription('Allows overriding the default number of decimal places for timeseries output.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('add_timeseries_dst_column', false)
    arg.setDisplayName('Generate Timeseries Output: Add TimeDST Column')
    arg.setDescription('Optionally add, in addition to the default local standard Time column, a local clock TimeDST column. Requires that daylight saving time is enabled.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('add_timeseries_utc_column', false)
    arg.setDisplayName('Generate Timeseries Output: Add TimeUTC Column')
    arg.setDescription('Optionally add, in addition to the default local standard Time column, a local clock TimeUTC column. If the time zone UTC offset is not provided in the HPXML file, the time zone in the EPW header will be used.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('user_output_variables', false)
    arg.setDisplayName('Generate Timeseries Output: EnergyPlus Output Variables')
    arg.setDescription('Optionally generates timeseries EnergyPlus output variables. If multiple output variables are desired, use a comma-separated list. Do not include key values; by default all key values will be requested. Example: "Zone People Occupant Count, Zone People Total Heating Energy"')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('generate_eri_outputs', false)
    arg.setDisplayName('Generate ERI Outputs')
    arg.setDescription('Optionally generate additional outputs needed for Energy Rating Index (ERI) calculations.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('annual_output_file_name', false)
    arg.setDisplayName('Annual Output File Name')
    arg.setDescription("If not provided, defaults to 'results_annual.csv' (or 'results_annual.json' or 'results_annual.msgpack').")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('timeseries_output_file_name', false)
    arg.setDisplayName('Timeseries Output File Name')
    arg.setDescription("If not provided, defaults to 'results_timeseries.csv' (or 'results_timeseries.json' or 'results_timeseries.msgpack').")
    args << arg

    return args
  end

  # define the outputs that the measure will create
  def outputs
    outs = OpenStudio::Measure::OSOutputVector.new

    setup_outputs(true)

    all_outputs = []
    all_outputs << @totals
    all_outputs << @fuels
    all_outputs << @end_uses
    all_outputs << @loads
    all_outputs << @unmet_hours
    all_outputs << @peak_fuels
    all_outputs << @peak_loads
    all_outputs << @component_loads
    all_outputs << @hot_water_uses

    output_names = []
    all_outputs.each do |outputs|
      outputs.values.each do |obj|
        output_names << get_runner_output_name(obj.name, obj.annual_units)
      end
    end

    output_names.each do |output_name|
      outs << OpenStudio::Measure::OSOutput.makeDoubleOutput(output_name)
    end

    return outs
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
    if !runner.validateUserArguments(arguments(@model), user_arguments)
      return result
    end

    unmet_hours_program = @model.getModelObjectByName(Constants.ObjectNameUnmetHoursProgram.gsub(' ', '_')).get.to_EnergyManagementSystemProgram.get
    total_loads_program = @model.getModelObjectByName(Constants.ObjectNameTotalLoadsProgram.gsub(' ', '_')).get.to_EnergyManagementSystemProgram.get
    comp_loads_program = @model.getModelObjectByName(Constants.ObjectNameComponentLoadsProgram.gsub(' ', '_'))
    if comp_loads_program.is_initialized
      comp_loads_program = comp_loads_program.get.to_EnergyManagementSystemProgram.get
    else
      comp_loads_program = nil
    end
    has_heating = @model.getBuilding.additionalProperties.getFeatureAsBoolean('has_heating').get
    has_cooling = @model.getBuilding.additionalProperties.getFeatureAsBoolean('has_cooling').get

    timeseries_frequency = runner.getStringArgumentValue('timeseries_frequency', user_arguments)
    if timeseries_frequency != 'none'
      include_timeseries_total_consumptions = runner.getOptionalBoolArgumentValue('include_timeseries_total_consumptions', user_arguments)
      include_timeseries_fuel_consumptions = runner.getOptionalBoolArgumentValue('include_timeseries_fuel_consumptions', user_arguments)
      include_timeseries_end_use_consumptions = runner.getOptionalBoolArgumentValue('include_timeseries_end_use_consumptions', user_arguments)
      include_timeseries_emissions = runner.getOptionalBoolArgumentValue('include_timeseries_emissions', user_arguments)
      include_timeseries_emission_fuels = runner.getOptionalBoolArgumentValue('include_timeseries_emission_fuels', user_arguments)
      include_timeseries_emission_end_uses = runner.getOptionalBoolArgumentValue('include_timeseries_emission_end_uses', user_arguments)
      include_timeseries_hot_water_uses = runner.getOptionalBoolArgumentValue('include_timeseries_hot_water_uses', user_arguments)
      include_timeseries_total_loads = runner.getOptionalBoolArgumentValue('include_timeseries_total_loads', user_arguments)
      include_timeseries_component_loads = runner.getOptionalBoolArgumentValue('include_timeseries_component_loads', user_arguments)
      include_timeseries_unmet_hours = runner.getOptionalBoolArgumentValue('include_timeseries_unmet_hours', user_arguments)
      include_timeseries_zone_temperatures = runner.getOptionalBoolArgumentValue('include_timeseries_zone_temperatures', user_arguments)
      include_timeseries_airflows = runner.getOptionalBoolArgumentValue('include_timeseries_airflows', user_arguments)
      include_timeseries_weather = runner.getOptionalBoolArgumentValue('include_timeseries_weather', user_arguments)
      user_output_variables = runner.getOptionalStringArgumentValue('user_output_variables', user_arguments)

      include_timeseries_total_consumptions = include_timeseries_total_consumptions.is_initialized ? include_timeseries_total_consumptions.get : false
      include_timeseries_fuel_consumptions = include_timeseries_fuel_consumptions.is_initialized ? include_timeseries_fuel_consumptions.get : false
      include_timeseries_end_use_consumptions = include_timeseries_end_use_consumptions.is_initialized ? include_timeseries_end_use_consumptions.get : false
      include_timeseries_emissions = include_timeseries_emissions.is_initialized ? include_timeseries_emissions.get : false
      include_timeseries_emission_fuels = include_timeseries_emission_fuels.is_initialized ? include_timeseries_emission_fuels.get : false
      include_timeseries_emission_end_uses = include_timeseries_emission_end_uses.is_initialized ? include_timeseries_emission_end_uses.get : false
      include_timeseries_hot_water_uses = include_timeseries_hot_water_uses.is_initialized ? include_timeseries_hot_water_uses.get : false
      include_timeseries_total_loads = include_timeseries_total_loads.is_initialized ? include_timeseries_total_loads.get : false
      include_timeseries_component_loads = include_timeseries_component_loads.is_initialized ? include_timeseries_component_loads.get : false
      include_timeseries_unmet_hours = include_timeseries_unmet_hours.is_initialized ? include_timeseries_unmet_hours.get : false
      include_timeseries_zone_temperatures = include_timeseries_zone_temperatures.is_initialized ? include_timeseries_zone_temperatures.get : false
      include_timeseries_airflows = include_timeseries_airflows.is_initialized ? include_timeseries_airflows.get : false
      include_timeseries_weather = include_timeseries_weather.is_initialized ? include_timeseries_weather.get : false
      user_output_variables = user_output_variables.is_initialized ? user_output_variables.get : nil
    end

    setup_outputs(false, user_output_variables)

    # To calculate timeseries emissions or timeseries fuel consumption, we also need to select timeseries
    # end use consumption because EnergyPlus results may be post-processed due to HVAC DSE.
    # TODO: This could be removed if we could account for DSE inside EnergyPlus.
    if not @emissions.empty?
      include_hourly_electric_end_use_consumptions = true # Need hourly electricity values for Cambium
      if include_timeseries_emissions || include_timeseries_emission_end_uses || include_timeseries_emission_fuels
        include_timeseries_fuel_consumptions = true
      end
    end
    if include_timeseries_total_consumptions
      include_timeseries_fuel_consumptions = true
    end
    if include_timeseries_fuel_consumptions
      include_timeseries_end_use_consumptions = true
    end

    has_electricity_production = false
    if @end_uses.select { |_key, end_use| end_use.is_negative && end_use.variables.size > 0 }.size > 0
      has_electricity_production = true
    end

    has_electricity_storage = false
    if @end_uses.select { |_key, end_use| end_use.is_storage && end_use.variables.size > 0 }.size > 0
      has_electricity_storage = true
    end

    # Fuel outputs
    @fuels.each do |_fuel_type, fuel|
      fuel.meters.each do |meter|
        result << OpenStudio::IdfObject.load("Output:Meter,#{meter},runperiod;").get
        if include_timeseries_fuel_consumptions
          result << OpenStudio::IdfObject.load("Output:Meter,#{meter},#{timeseries_frequency};").get
        end
      end
    end
    if has_electricity_production || has_electricity_storage
      result << OpenStudio::IdfObject.load('Output:Meter,ElectricityProduced:Facility,runperiod;').get # Used for error checking
    end
    if has_electricity_storage
      result << OpenStudio::IdfObject.load('Output:Meter,ElectricStorage:ElectricityProduced,runperiod;').get # Used for error checking
      if include_timeseries_fuel_consumptions
        result << OpenStudio::IdfObject.load("Output:Meter,ElectricStorage:ElectricityProduced,#{timeseries_frequency};").get
      end
    end

    # End Use/Hot Water Use/Ideal Load outputs
    { @end_uses => include_timeseries_end_use_consumptions,
      @hot_water_uses => include_timeseries_hot_water_uses,
      @ideal_system_loads => false }.each do |uses, include_timeseries|
      uses.each do |key, use|
        use.variables.each do |_sys_id, varkey, var|
          result << OpenStudio::IdfObject.load("Output:Variable,#{varkey},#{var},runperiod;").get
          if include_timeseries
            result << OpenStudio::IdfObject.load("Output:Variable,#{varkey},#{var},#{timeseries_frequency};").get
          end
          next unless use.is_a?(EndUse)

          fuel_type, _end_use = key
          if fuel_type == FT::Elec && include_hourly_electric_end_use_consumptions
            result << OpenStudio::IdfObject.load("Output:Variable,#{varkey},#{var},hourly;").get
          end
        end
      end
    end

    # Peak Fuel outputs (annual only)
    @peak_fuels.values.each do |peak_fuel|
      peak_fuel.meters.each do |meter|
        result << OpenStudio::IdfObject.load("Output:Table:Monthly,#{peak_fuel.report},2,#{meter},HoursPositive,Electricity:Facility,MaximumDuringHoursShown;").get
      end
    end

    # Peak Load outputs (annual only)
    @peak_loads.values.each do |peak_load|
      result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{peak_load.ems_variable}_peakload_outvar,#{peak_load.ems_variable},Summed,ZoneTimestep,#{total_loads_program.name},J;").get
      result << OpenStudio::IdfObject.load("Output:Table:Monthly,#{peak_load.report},2,#{peak_load.ems_variable}_peakload_outvar,Maximum;").get
    end

    # Unmet Hours (annual only)
    @unmet_hours.each do |_key, unmet_hour|
      result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{unmet_hour.ems_variable}_annual_outvar,#{unmet_hour.ems_variable},Summed,ZoneTimestep,#{unmet_hours_program.name},hr;").get
      result << OpenStudio::IdfObject.load("Output:Variable,*,#{unmet_hour.ems_variable}_annual_outvar,runperiod;").get
      if include_timeseries_unmet_hours
        result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{unmet_hour.ems_variable}_timeseries_outvar,#{unmet_hour.ems_variable},Summed,ZoneTimestep,#{unmet_hours_program.name},hr;").get
        result << OpenStudio::IdfObject.load("Output:Variable,*,#{unmet_hour.ems_variable}_timeseries_outvar,#{timeseries_frequency};").get
      end
    end

    # Component Load outputs
    @component_loads.values.each do |comp_load|
      next if comp_loads_program.nil?

      result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{comp_load.ems_variable}_annual_outvar,#{comp_load.ems_variable},Summed,ZoneTimestep,#{comp_loads_program.name},J;").get
      result << OpenStudio::IdfObject.load("Output:Variable,*,#{comp_load.ems_variable}_annual_outvar,runperiod;").get
      if include_timeseries_component_loads
        result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{comp_load.ems_variable}_timeseries_outvar,#{comp_load.ems_variable},Summed,ZoneTimestep,#{comp_loads_program.name},J;").get
        result << OpenStudio::IdfObject.load("Output:Variable,*,#{comp_load.ems_variable}_timeseries_outvar,#{timeseries_frequency};").get
      end
    end

    # Total Load outputs
    @loads.values.each do |load|
      if not load.ems_variable.nil?
        result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{load.ems_variable}_annual_outvar,#{load.ems_variable},Summed,ZoneTimestep,#{total_loads_program.name},J;").get
        result << OpenStudio::IdfObject.load("Output:Variable,*,#{load.ems_variable}_annual_outvar,runperiod;").get
        if include_timeseries_total_loads
          result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{load.ems_variable}_timeseries_outvar,#{load.ems_variable},Summed,ZoneTimestep,#{total_loads_program.name},J;").get
          result << OpenStudio::IdfObject.load("Output:Variable,*,#{load.ems_variable}_timeseries_outvar,#{timeseries_frequency};").get
        end
      end
      load.variables.each do |_sys_id, varkey, var|
        result << OpenStudio::IdfObject.load("Output:Variable,#{varkey},#{var},runperiod;").get
        if include_timeseries_total_loads
          result << OpenStudio::IdfObject.load("Output:Variable,#{varkey},#{var},#{timeseries_frequency};").get
        end
      end
    end

    # Temperature outputs (timeseries only)
    if include_timeseries_zone_temperatures
      result << OpenStudio::IdfObject.load("Output:Variable,*,Zone Mean Air Temperature,#{timeseries_frequency};").get
      # For reporting temperature-scheduled spaces timeseries temperatures.
      keys = [HPXML::LocationOtherHeatedSpace,
              HPXML::LocationOtherMultifamilyBufferSpace,
              HPXML::LocationOtherNonFreezingSpace,
              HPXML::LocationOtherHousingUnit,
              HPXML::LocationExteriorWall,
              HPXML::LocationUnderSlab]
      keys.each do |key|
        next if @model.getScheduleConstants.select { |o| o.name.to_s == key }.size == 0

        result << OpenStudio::IdfObject.load("Output:Variable,#{key},Schedule Value,#{timeseries_frequency};").get
      end
      # Also report thermostat setpoints
      if has_heating
        result << OpenStudio::IdfObject.load("Output:Variable,#{HPXML::LocationLivingSpace.upcase},Zone Thermostat Heating Setpoint Temperature,#{timeseries_frequency};").get
      end
      if has_cooling
        result << OpenStudio::IdfObject.load("Output:Variable,#{HPXML::LocationLivingSpace.upcase},Zone Thermostat Cooling Setpoint Temperature,#{timeseries_frequency};").get
      end
    end

    # Airflow outputs (timeseries only)
    if include_timeseries_airflows
      @airflows.values.each do |airflow|
        ems_program = @model.getModelObjectByName(airflow.ems_program.gsub(' ', '_')).get.to_EnergyManagementSystemProgram.get
        airflow.ems_variables.each do |ems_variable|
          result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{ems_variable}_timeseries_outvar,#{ems_variable},Averaged,ZoneTimestep,#{ems_program.name},m^3/s;").get
          result << OpenStudio::IdfObject.load("Output:Variable,*,#{ems_variable}_timeseries_outvar,#{timeseries_frequency};").get
        end
      end
    end

    # Weather outputs (timeseries only)
    if include_timeseries_weather
      @weather.values.each do |weather_data|
        result << OpenStudio::IdfObject.load("Output:Variable,*,#{weather_data.variable},#{timeseries_frequency};").get
      end
    end

    # Optional output variables (timeseries only)
    @output_variables_requests.each do |output_variable_name, _output_variable|
      result << OpenStudio::IdfObject.load("Output:Variable,*,#{output_variable_name},#{timeseries_frequency};").get
    end

    # Dual-fuel heat pump loads
    if not @object_variables_by_key[[LT, LT::Heating]].nil?
      @object_variables_by_key[[LT, LT::Heating]].each do |vals|
        _sys_id, key, var = vals
        result << OpenStudio::IdfObject.load("Output:Variable,#{key},#{var},runperiod;").get
      end
    end

    return result.uniq
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

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(@model), user_arguments)
      return false
    end

    output_format = runner.getStringArgumentValue('output_format', user_arguments)
    if output_format == 'csv_dview'
      output_format = 'csv'
      use_dview_format = true
    end
    timeseries_frequency = runner.getStringArgumentValue('timeseries_frequency', user_arguments)
    if timeseries_frequency != 'none'
      include_timeseries_total_consumptions = runner.getOptionalBoolArgumentValue('include_timeseries_total_consumptions', user_arguments)
      include_timeseries_fuel_consumptions = runner.getOptionalBoolArgumentValue('include_timeseries_fuel_consumptions', user_arguments)
      include_timeseries_end_use_consumptions = runner.getOptionalBoolArgumentValue('include_timeseries_end_use_consumptions', user_arguments)
      include_timeseries_emissions = runner.getOptionalBoolArgumentValue('include_timeseries_emissions', user_arguments)
      include_timeseries_emission_fuels = runner.getOptionalBoolArgumentValue('include_timeseries_emission_fuels', user_arguments)
      include_timeseries_emission_end_uses = runner.getOptionalBoolArgumentValue('include_timeseries_emission_end_uses', user_arguments)
      include_timeseries_hot_water_uses = runner.getOptionalBoolArgumentValue('include_timeseries_hot_water_uses', user_arguments)
      include_timeseries_total_loads = runner.getOptionalBoolArgumentValue('include_timeseries_total_loads', user_arguments)
      include_timeseries_component_loads = runner.getOptionalBoolArgumentValue('include_timeseries_component_loads', user_arguments)
      include_timeseries_unmet_hours = runner.getOptionalBoolArgumentValue('include_timeseries_unmet_hours', user_arguments)
      include_timeseries_zone_temperatures = runner.getOptionalBoolArgumentValue('include_timeseries_zone_temperatures', user_arguments)
      include_timeseries_airflows = runner.getOptionalBoolArgumentValue('include_timeseries_airflows', user_arguments)
      include_timeseries_weather = runner.getOptionalBoolArgumentValue('include_timeseries_weather', user_arguments)
      use_timestamp_start_convention = (runner.getStringArgumentValue('timeseries_timestamp_convention', user_arguments) == 'start')
      add_timeseries_dst_column = runner.getOptionalBoolArgumentValue('add_timeseries_dst_column', user_arguments)
      add_timeseries_utc_column = runner.getOptionalBoolArgumentValue('add_timeseries_utc_column', user_arguments)
      user_output_variables = runner.getOptionalStringArgumentValue('user_output_variables', user_arguments)

      include_timeseries_total_consumptions = include_timeseries_total_consumptions.is_initialized ? include_timeseries_total_consumptions.get : false
      include_timeseries_fuel_consumptions = include_timeseries_fuel_consumptions.is_initialized ? include_timeseries_fuel_consumptions.get : false
      include_timeseries_end_use_consumptions = include_timeseries_end_use_consumptions.is_initialized ? include_timeseries_end_use_consumptions.get : false
      include_timeseries_emissions = include_timeseries_emissions.is_initialized ? include_timeseries_emissions.get : false
      include_timeseries_emission_fuels = include_timeseries_emission_fuels.is_initialized ? include_timeseries_emission_fuels.get : false
      include_timeseries_emission_end_uses = include_timeseries_emission_end_uses.is_initialized ? include_timeseries_emission_end_uses.get : false
      include_timeseries_hot_water_uses = include_timeseries_hot_water_uses.is_initialized ? include_timeseries_hot_water_uses.get : false
      include_timeseries_total_loads = include_timeseries_total_loads.is_initialized ? include_timeseries_total_loads.get : false
      include_timeseries_component_loads = include_timeseries_component_loads.is_initialized ? include_timeseries_component_loads.get : false
      include_timeseries_unmet_hours = include_timeseries_unmet_hours.is_initialized ? include_timeseries_unmet_hours.get : false
      include_timeseries_zone_temperatures = include_timeseries_zone_temperatures.is_initialized ? include_timeseries_zone_temperatures.get : false
      include_timeseries_airflows = include_timeseries_airflows.is_initialized ? include_timeseries_airflows.get : false
      include_timeseries_weather = include_timeseries_weather.is_initialized ? include_timeseries_weather.get : false
      user_output_variables = user_output_variables.is_initialized ? user_output_variables.get : nil
    end
    generate_eri_outputs = runner.getOptionalBoolArgumentValue('generate_eri_outputs', user_arguments)
    generate_eri_outputs = generate_eri_outputs.is_initialized ? generate_eri_outputs.get : false
    annual_output_file_name = runner.getOptionalStringArgumentValue('annual_output_file_name', user_arguments)
    timeseries_output_file_name = runner.getOptionalStringArgumentValue('timeseries_output_file_name', user_arguments)
    timeseries_num_decimal_places = runner.getOptionalIntegerArgumentValue('timeseries_num_decimal_places', user_arguments)
    timeseries_num_decimal_places = timeseries_num_decimal_places.is_initialized ? Integer(timeseries_num_decimal_places.get) : nil

    output_dir = File.dirname(runner.lastEpwFilePath.get.to_s)

    hpxml_defaults_path = @model.getBuilding.additionalProperties.getFeatureAsString('hpxml_defaults_path').get
    building_id = @model.getBuilding.additionalProperties.getFeatureAsString('building_id').get
    @hpxml = HPXML.new(hpxml_path: hpxml_defaults_path, building_id: building_id)
    HVAC.apply_shared_systems(@hpxml) # Needed for ERI shared HVAC systems

    setup_outputs(false, user_output_variables)

    if not File.exist? File.join(output_dir, 'eplusout.msgpack')
      runner.registerError('Cannot find eplusout.msgpack.')
      return false
    end
    @msgpackData = MessagePack.unpack(File.read(File.join(output_dir, 'eplusout.msgpack'), mode: 'rb'))
    @msgpackDataRunPeriod = MessagePack.unpack(File.read(File.join(output_dir, 'eplusout_runperiod.msgpack'), mode: 'rb'))
    msgpack_timeseries_path = File.join(output_dir, "eplusout_#{timeseries_frequency}.msgpack")
    if File.exist? msgpack_timeseries_path
      @msgpackDataTimeseries = MessagePack.unpack(File.read(msgpack_timeseries_path, mode: 'rb'))
    end
    if not @emissions.empty?
      @msgpackDataHourly = MessagePack.unpack(File.read(File.join(output_dir, 'eplusout_hourly.msgpack'), mode: 'rb'))
    end

    # Set paths
    if annual_output_file_name.is_initialized
      annual_output_path = File.join(output_dir, annual_output_file_name.get)
    else
      annual_output_path = File.join(output_dir, "results_annual.#{output_format}")
    end
    if timeseries_output_file_name.is_initialized
      timeseries_output_path = File.join(output_dir, timeseries_output_file_name.get)
    else
      timeseries_output_path = File.join(output_dir, "results_timeseries.#{output_format}")
    end

    if timeseries_frequency != 'none'
      add_dst_column = (add_timeseries_dst_column.is_initialized ? add_timeseries_dst_column.get : false)
      add_utc_column = (add_timeseries_utc_column.is_initialized ? add_timeseries_utc_column.get : false)
      @timestamps, timestamps_dst, timestamps_utc = get_timestamps(@msgpackDataTimeseries, @hpxml, use_timestamp_start_convention,
                                                                   add_dst_column, add_utc_column, use_dview_format, timeseries_frequency)
    end

    # Retrieve outputs
    outputs = get_outputs(runner, timeseries_frequency,
                          include_timeseries_total_consumptions,
                          include_timeseries_fuel_consumptions,
                          include_timeseries_end_use_consumptions,
                          include_timeseries_emissions,
                          include_timeseries_emission_fuels,
                          include_timeseries_emission_end_uses,
                          include_timeseries_hot_water_uses,
                          include_timeseries_total_loads,
                          include_timeseries_component_loads,
                          include_timeseries_unmet_hours,
                          include_timeseries_zone_temperatures,
                          include_timeseries_airflows,
                          include_timeseries_weather)

    if not check_for_errors(runner, outputs)
      return false
    end

    # Set rounding precision for run period (e.g., annual) outputs.
    # Note: Make sure to round outputs with sufficient resolution for the worst case -- i.e., 1 day instead of a full year.
    runperiod_n_digits = 3 # Default for annual (or near-annual) data
    sim_n_days = (Schedule.get_day_num_from_month_day(2000, @hpxml.header.sim_end_month, @hpxml.header.sim_end_day) -
                  Schedule.get_day_num_from_month_day(2000, @hpxml.header.sim_begin_month, @hpxml.header.sim_begin_day))
    if sim_n_days <= 10 # 10 days or less; add two decimal places
      runperiod_n_digits += 2
    elsif sim_n_days <= 100 # 100 days or less; add one decimal place
      runperiod_n_digits += 1
    end

    # Write/report results
    report_runperiod_output_results(runner, outputs, output_format, annual_output_path, runperiod_n_digits, generate_eri_outputs)
    report_timeseries_output_results(runner, outputs, output_format,
                                     timeseries_output_path,
                                     timeseries_frequency,
                                     timeseries_num_decimal_places,
                                     include_timeseries_total_consumptions,
                                     include_timeseries_fuel_consumptions,
                                     include_timeseries_end_use_consumptions,
                                     include_timeseries_emissions,
                                     include_timeseries_emission_fuels,
                                     include_timeseries_emission_end_uses,
                                     include_timeseries_hot_water_uses,
                                     include_timeseries_total_loads,
                                     include_timeseries_component_loads,
                                     include_timeseries_unmet_hours,
                                     include_timeseries_zone_temperatures,
                                     include_timeseries_airflows,
                                     include_timeseries_weather,
                                     add_dst_column,
                                     add_utc_column,
                                     timestamps_dst,
                                     timestamps_utc,
                                     use_dview_format)

    return true
  end

  def get_timestamps(msgpackData, hpxml, use_timestamp_start_convention, add_dst_column = false, add_utc_column = false,
                     use_dview_format = false, timeseries_frequency = nil)
    return if msgpackData.nil?

    ep_timestamps = msgpackData['Rows'].map { |r| r.keys[0] }

    if add_dst_column || use_dview_format
      dst_start_ts = Time.utc(hpxml.header.sim_calendar_year, hpxml.header.dst_begin_month, hpxml.header.dst_begin_day, 2)
      dst_end_ts = Time.utc(hpxml.header.sim_calendar_year, hpxml.header.dst_end_month, hpxml.header.dst_end_day, 1)
    end
    if add_utc_column
      utc_offset = hpxml.header.time_zone_utc_offset
      utc_offset *= 3600 # seconds
    end

    timestamps = []
    timestamps_dst = [] if add_dst_column || use_dview_format
    timestamps_utc = [] if add_utc_column
    year = hpxml.header.sim_calendar_year
    ep_timestamps.each do |ep_timestamp|
      month_day, hour_minute = ep_timestamp.split(' ')
      month, day = month_day.split('/').map(&:to_i)
      hour, minute, _ = hour_minute.split(':').map(&:to_i)

      # Convert from EnergyPlus default (end-of-timestep) to start-of-timestep convention
      if use_timestamp_start_convention
        if timeseries_frequency == 'timestep'
          ts_offset = hpxml.header.timestep * 60 # seconds
        elsif timeseries_frequency == 'hourly'
          ts_offset = 60 * 60 # seconds
        elsif timeseries_frequency == 'daily'
          ts_offset = 60 * 60 * 24 # seconds
        elsif timeseries_frequency == 'monthly'
          ts_offset = Constants.NumDaysInMonths(year)[month - 1] * 60 * 60 * 24 # seconds
        else
          fail 'Unexpected timeseries_frequency/'
        end
      end

      ts = Time.utc(year, month, day, hour, minute)
      ts -= ts_offset unless ts_offset.nil?

      timestamps << ts.iso8601.delete('Z')

      if add_dst_column || use_dview_format
        if (ts >= dst_start_ts) && (ts < dst_end_ts)
          ts_dst = ts + 3600 # 1 hr shift forward
        else
          ts_dst = ts
        end
        timestamps_dst << ts_dst.iso8601.delete('Z')
      end

      if add_utc_column
        ts_utc = ts - utc_offset
        timestamps_utc << ts_utc.iso8601
      end
    end

    return timestamps, timestamps_dst, timestamps_utc
  end

  def get_outputs(runner, timeseries_frequency,
                  include_timeseries_total_consumptions,
                  include_timeseries_fuel_consumptions,
                  include_timeseries_end_use_consumptions,
                  include_timeseries_emissions,
                  include_timeseries_emission_fuels,
                  include_timeseries_emission_end_uses,
                  include_timeseries_hot_water_uses,
                  include_timeseries_total_loads,
                  include_timeseries_component_loads,
                  include_timeseries_unmet_hours,
                  include_timeseries_zone_temperatures,
                  include_timeseries_airflows,
                  include_timeseries_weather)
    outputs = {}

    # To calculate timeseries emissions or timeseries fuel consumption, we also need to select timeseries
    # end use consumption because EnergyPlus results may be post-processed due to, e.g., HVAC DSE.
    # TODO: This could be removed if we could account for DSE inside EnergyPlus.
    if not @emissions.empty?
      include_hourly_electric_end_use_consumptions = true # For annual Cambium calculation
      if include_timeseries_emissions || include_timeseries_emission_end_uses || include_timeseries_emission_fuels
        include_timeseries_fuel_consumptions = true
      end
    end
    if include_timeseries_total_consumptions
      include_timeseries_fuel_consumptions = true
    end
    if include_timeseries_fuel_consumptions
      include_timeseries_end_use_consumptions = true
    end

    # Fuel Uses
    @fuels.each do |fuel_type, fuel|
      fuel.annual_output = get_report_meter_data_annual(fuel.meters)
      fuel.annual_output -= get_report_meter_data_annual(['ElectricStorage:ElectricityProduced']) if fuel_type == FT::Elec # We add Electric Storage onto the annual Electricity fuel meter

      next unless include_timeseries_fuel_consumptions

      fuel.timeseries_output = get_report_meter_data_timeseries(fuel.meters, UnitConversions.convert(1.0, 'J', fuel.timeseries_units), 0, timeseries_frequency)
      fuel.timeseries_output = fuel.timeseries_output.zip(get_report_meter_data_timeseries(['ElectricStorage:ElectricityProduced'], UnitConversions.convert(1.0, 'J', fuel.timeseries_units), 0, timeseries_frequency)).map { |x, y| x - y } if fuel_type == FT::Elec # We add Electric Storage onto the timeseries Electricity fuel meter
    end

    # Peak Electricity Consumption
    @peak_fuels.each do |_key, peak_fuel|
      peak_fuel.annual_output = get_tabular_data_value(peak_fuel.report.upcase, 'Meter', 'Custom Monthly Report', ['Maximum of Months'], 'ELECTRICITY:FACILITY {MAX FOR HOURS SHOWN}', peak_fuel.annual_units)
    end

    # Total loads
    @loads.each do |load_type, load|
      if not load.ems_variable.nil?
        # Obtain from EMS output variable
        load.annual_output = get_report_variable_data_annual(['EMS'], ["#{load.ems_variable}_annual_outvar"])
        if include_timeseries_total_loads
          load.timeseries_output = get_report_variable_data_timeseries(['EMS'], ["#{load.ems_variable}_timeseries_outvar"], UnitConversions.convert(1.0, 'J', load.timeseries_units), 0, timeseries_frequency, ems_shift: true)
        end
      elsif load.variables.size > 0
        # Obtain from output variable
        load.variables.map { |v| v[0] }.uniq.each do |sys_id|
          keys = load.variables.select { |v| v[0] == sys_id }.map { |v| v[1] }
          vars = load.variables.select { |v| v[0] == sys_id }.map { |v| v[2] }

          load.annual_output_by_system[sys_id] = get_report_variable_data_annual(keys, vars, is_negative: load.is_negative)
          if include_timeseries_total_loads && (load_type == LT::HotWaterDelivered)
            load.timeseries_output_by_system[sys_id] = get_report_variable_data_timeseries(keys, vars, UnitConversions.convert(1.0, 'J', load.timeseries_units), 0, timeseries_frequency, is_negative: load.is_negative, ems_shift: true)
          end
        end
      end
    end

    # Component Loads
    @component_loads.each do |_key, comp_load|
      comp_load.annual_output = get_report_variable_data_annual(['EMS'], ["#{comp_load.ems_variable}_annual_outvar"])
      if include_timeseries_component_loads
        comp_load.timeseries_output = get_report_variable_data_timeseries(['EMS'], ["#{comp_load.ems_variable}_timeseries_outvar"], UnitConversions.convert(1.0, 'J', comp_load.timeseries_units), 0, timeseries_frequency, ems_shift: true)
      end
    end

    # Unmet Hours
    @unmet_hours.each do |_key, unmet_hour|
      unmet_hour.annual_output = get_report_variable_data_annual(['EMS'], ["#{unmet_hour.ems_variable}_annual_outvar"], 1.0)
      if include_timeseries_unmet_hours
        unmet_hour.timeseries_output = get_report_variable_data_timeseries(['EMS'], ["#{unmet_hour.ems_variable}_timeseries_outvar"], 1.0, 0, timeseries_frequency)
      end
    end

    # Ideal system loads (expected fraction of loads that are not met by partial HVAC (e.g., room AC that meets 30% of load))
    @ideal_system_loads.each do |_load_type, ideal_load|
      ideal_load.variables.map { |v| v[0] }.uniq.each do |sys_id|
        keys = ideal_load.variables.select { |v| v[0] == sys_id }.map { |v| v[1] }
        vars = ideal_load.variables.select { |v| v[0] == sys_id }.map { |v| v[2] }

        ideal_load.annual_output = get_report_variable_data_annual(keys, vars)
      end
    end

    # Peak Building Space Heating/Cooling Loads (total heating/cooling energy delivered including backup ideal air system)
    @peak_loads.each do |_load_type, peak_load|
      peak_load.annual_output = UnitConversions.convert(get_tabular_data_value(peak_load.report.upcase, 'EMS', 'Custom Monthly Report', ['Maximum of Months'], "#{peak_load.ems_variable.upcase}_PEAKLOAD_OUTVAR {Maximum}", 'W'), 'W', peak_load.annual_units)
    end

    # End Uses
    @end_uses.each do |key, end_use|
      fuel_type, _end_use_type = key

      end_use.variables.map { |v| v[0] }.uniq.each do |sys_id|
        keys = end_use.variables.select { |v| v[0] == sys_id }.map { |v| v[1] }
        vars = end_use.variables.select { |v| v[0] == sys_id }.map { |v| v[2] }

        end_use.annual_output_by_system[sys_id] = get_report_variable_data_annual(keys, vars, is_negative: (end_use.is_negative || end_use.is_storage))

        if include_timeseries_end_use_consumptions
          end_use.timeseries_output_by_system[sys_id] = get_report_variable_data_timeseries(keys, vars, UnitConversions.convert(1.0, 'J', end_use.timeseries_units), 0, timeseries_frequency, is_negative: (end_use.is_negative || end_use.is_storage))
        end
        if include_hourly_electric_end_use_consumptions && fuel_type == FT::Elec
          end_use.hourly_output_by_system[sys_id] = get_report_variable_data_timeseries(keys, vars, UnitConversions.convert(1.0, 'J', end_use.timeseries_units), 0, 'hourly', is_negative: (end_use.is_negative || end_use.is_storage))
        end
      end
    end

    # Disaggregate 8760 GSHP shared pump energy into heating vs cooling by
    # applying proportionally to the GSHP heating & cooling fan/pump energy use.
    gshp_shared_loop_end_use = @end_uses[[FT::Elec, 'TempGSHPSharedPump']]
    htg_fan_pump_end_use = @end_uses[[FT::Elec, EUT::HeatingFanPump]]
    clg_fan_pump_end_use = @end_uses[[FT::Elec, EUT::CoolingFanPump]]
    gshp_shared_loop_end_use.annual_output_by_system.keys.each do |sys_id|
      # Calculate heating & cooling fan/pump end use multiplier
      htg_energy = htg_fan_pump_end_use.annual_output_by_system[sys_id]
      clg_energy = clg_fan_pump_end_use.annual_output_by_system[sys_id]
      shared_pump_energy = gshp_shared_loop_end_use.annual_output_by_system[sys_id]
      energy_multiplier = (htg_energy + clg_energy + shared_pump_energy) / (htg_energy + clg_energy)
      # Apply multiplier
      apply_multiplier_to_output(htg_fan_pump_end_use, nil, sys_id, energy_multiplier)
      apply_multiplier_to_output(clg_fan_pump_end_use, nil, sys_id, energy_multiplier)
    end
    @end_uses.delete([FT::Elec, 'TempGSHPSharedPump'])

    # Hot Water Uses
    @hot_water_uses.each do |_hot_water_type, hot_water|
      hot_water.variables.map { |v| v[0] }.uniq.each do |sys_id|
        keys = hot_water.variables.select { |v| v[0] == sys_id }.map { |v| v[1] }
        vars = hot_water.variables.select { |v| v[0] == sys_id }.map { |v| v[2] }

        hot_water.annual_output_by_system[sys_id] = get_report_variable_data_annual(keys, vars, UnitConversions.convert(1.0, 'm^3', hot_water.annual_units))
        if include_timeseries_hot_water_uses
          hot_water.timeseries_output_by_system[sys_id] = get_report_variable_data_timeseries(keys, vars, UnitConversions.convert(1.0, 'm^3', hot_water.timeseries_units), 0, timeseries_frequency)
        end
      end
    end

    # Apply Heating/Cooling DSEs
    (@hpxml.heating_systems + @hpxml.heat_pumps).each do |htg_system|
      next unless (htg_system.is_a?(HPXML::HeatingSystem) && htg_system.is_heat_pump_backup_system) || htg_system.fraction_heat_load_served > 0
      next if htg_system.distribution_system_idref.nil?
      next unless htg_system.distribution_system.distribution_system_type == HPXML::HVACDistributionTypeDSE
      next if htg_system.distribution_system.annual_heating_dse.nil?

      dse = htg_system.distribution_system.annual_heating_dse
      @fuels.each do |fuel_type, fuel|
        [EUT::Heating, EUT::HeatingHeatPumpBackup, EUT::HeatingFanPump].each do |end_use_type|
          end_use = @end_uses[[fuel_type, end_use_type]]
          next if end_use.nil?

          if not end_use.annual_output_by_system[htg_system.id].nil?
            apply_multiplier_to_output(end_use, fuel, htg_system.id, 1.0 / dse)
          end
          if not end_use.annual_output_by_system[htg_system.id + '_DFHPBackup'].nil?
            apply_multiplier_to_output(end_use, fuel, htg_system.id + '_DFHPBackup', 1.0 / dse)
          end
        end
      end
    end
    (@hpxml.cooling_systems + @hpxml.heat_pumps).each do |clg_system|
      next unless clg_system.fraction_cool_load_served > 0
      next if clg_system.distribution_system_idref.nil?
      next unless clg_system.distribution_system.distribution_system_type == HPXML::HVACDistributionTypeDSE
      next if clg_system.distribution_system.annual_cooling_dse.nil?

      dse = clg_system.distribution_system.annual_cooling_dse
      @fuels.each do |fuel_type, fuel|
        [EUT::Cooling, EUT::CoolingFanPump].each do |end_use_type|
          end_use = @end_uses[[fuel_type, end_use_type]]
          next if end_use.nil?
          next if end_use.annual_output_by_system[clg_system.id].nil?

          apply_multiplier_to_output(end_use, fuel, clg_system.id, 1.0 / dse)
        end
      end
    end

    # Apply solar fraction to load for simple solar water heating systems
    @hpxml.solar_thermal_systems.each do |solar_system|
      next if solar_system.solar_fraction.nil?

      @loads[LT::HotWaterSolarThermal].annual_output = 0.0 if @loads[LT::HotWaterSolarThermal].annual_output.nil?
      @loads[LT::HotWaterSolarThermal].timeseries_output = [0.0] * @timestamps.size if @loads[LT::HotWaterSolarThermal].timeseries_output.nil?

      if not solar_system.water_heating_system.nil?
        dhw_ids = [solar_system.water_heating_system.id]
      else # Apply to all water heating systems
        dhw_ids = @hpxml.water_heating_systems.map { |dhw| dhw.id }
      end
      dhw_ids.each do |dhw_id|
        apply_multiplier_to_output(@loads[LT::HotWaterDelivered], @loads[LT::HotWaterSolarThermal], dhw_id, 1.0 / (1.0 - solar_system.solar_fraction))
      end
    end

    # Calculate aggregated values from per-system values as needed
    (@end_uses.values + @loads.values + @hot_water_uses.values).each do |obj|
      # Annual
      if obj.annual_output.nil?
        if not obj.annual_output_by_system.empty?
          obj.annual_output = obj.annual_output_by_system.values.sum(0.0)
        else
          obj.annual_output = 0.0
        end
      end

      # Timeseries
      if obj.timeseries_output.empty? && (not obj.timeseries_output_by_system.empty?)
        obj.timeseries_output = obj.timeseries_output_by_system.values[0]
        obj.timeseries_output_by_system.values[1..-1].each do |values|
          obj.timeseries_output = obj.timeseries_output.zip(values).map { |x, y| x + y }
        end
      end

      # Hourly Electricity (for Cambium)
      next unless obj.is_a?(EndUse) && obj.hourly_output.empty? && (not obj.hourly_output_by_system.empty?)

      obj.hourly_output = obj.hourly_output_by_system.values[0]
      obj.hourly_output_by_system.values[1..-1].each do |values|
        obj.hourly_output = obj.hourly_output.zip(values).map { |x, y| x + y }
      end
    end

    # Total/Net Electricity (Net includes, e.g., PV and generators)
    outputs[:elec_prod_annual] = @end_uses.select { |k, eu| k[0] == FT::Elec && eu.is_negative }.map { |_k, eu| eu.annual_output.to_f }.sum(0.0) # Negative value
    outputs[:elec_net_annual] = @fuels[FT::Elec].annual_output.to_f + outputs[:elec_prod_annual]
    if include_timeseries_fuel_consumptions
      outputs[:elec_prod_timeseries] = [0.0] * @timestamps.size # Negative values
      @end_uses.select { |k, eu| k[0] == FT::Elec && eu.is_negative && eu.timeseries_output.size > 0 }.each do |_key, end_use|
        outputs[:elec_prod_timeseries] = outputs[:elec_prod_timeseries].zip(end_use.timeseries_output).map { |x, y| x + y }
      end
      outputs[:elec_net_timeseries] = @fuels[FT::Elec].timeseries_output.zip(outputs[:elec_prod_timeseries]).map { |x, y| x + y }
    end

    # Total/Net Energy (Net includes, e.g., PV and generators)
    @totals[TE::Total].annual_output = 0.0
    @fuels.each do |_fuel_type, fuel|
      @totals[TE::Total].annual_output += fuel.annual_output
      next unless include_timeseries_total_consumptions && fuel.timeseries_output.sum != 0.0

      @totals[TE::Total].timeseries_output = [0.0] * @timestamps.size if @totals[TE::Total].timeseries_output.empty?
      unit_conv = UnitConversions.convert(1.0, fuel.timeseries_units, @totals[TE::Total].timeseries_units)
      @totals[TE::Total].timeseries_output = @totals[TE::Total].timeseries_output.zip(fuel.timeseries_output).map { |x, y| x + y * unit_conv }
    end
    @totals[TE::Net].annual_output = @totals[TE::Total].annual_output + outputs[:elec_prod_annual]
    if include_timeseries_total_consumptions
      unit_conv = UnitConversions.convert(1.0, get_timeseries_units_from_fuel_type(FT::Elec), @totals[TE::Total].timeseries_units)
      @totals[TE::Net].timeseries_output = @totals[TE::Total].timeseries_output.zip(outputs[:elec_prod_timeseries]).map { |x, y| x + y * unit_conv }
    end

    # Zone temperatures
    if include_timeseries_zone_temperatures
      zone_names = []
      scheduled_temperature_names = []
      @model.getThermalZones.each do |zone|
        if zone.floorArea > 1
          zone_names << zone.name.to_s.upcase
        end
      end
      @model.getScheduleConstants.each do |schedule|
        next unless [HPXML::LocationOtherHeatedSpace, HPXML::LocationOtherMultifamilyBufferSpace, HPXML::LocationOtherNonFreezingSpace,
                     HPXML::LocationOtherHousingUnit, HPXML::LocationExteriorWall, HPXML::LocationUnderSlab].include? schedule.name.to_s

        scheduled_temperature_names << schedule.name.to_s.upcase
      end
      zone_names.sort.each do |zone_name|
        @zone_temps[zone_name] = ZoneTemp.new
        @zone_temps[zone_name].name = "Temperature: #{zone_name.split.map(&:capitalize).join(' ')}"
        @zone_temps[zone_name].timeseries_units = 'F'
        @zone_temps[zone_name].timeseries_output = get_report_variable_data_timeseries([zone_name], ['Zone Mean Air Temperature'], 9.0 / 5.0, 32.0, timeseries_frequency)
      end
      scheduled_temperature_names.sort.each do |scheduled_temperature_name|
        @zone_temps[scheduled_temperature_name] = ZoneTemp.new
        @zone_temps[scheduled_temperature_name].name = "Temperature: #{scheduled_temperature_name.split.map(&:capitalize).join(' ')}"
        @zone_temps[scheduled_temperature_name].timeseries_units = 'F'
        @zone_temps[scheduled_temperature_name].timeseries_output = get_report_variable_data_timeseries([scheduled_temperature_name], ['Schedule Value'], 9.0 / 5.0, 32.0, timeseries_frequency)
      end
      { 'Heating Setpoint' => 'Zone Thermostat Heating Setpoint Temperature',
        'Cooling Setpoint' => 'Zone Thermostat Cooling Setpoint Temperature' }.each do |sp_name, sp_var|
        @zone_temps[sp_name] = ZoneTemp.new
        @zone_temps[sp_name].name = "Temperature: #{sp_name}"
        @zone_temps[sp_name].timeseries_units = 'F'
        @zone_temps[sp_name].timeseries_output = get_report_variable_data_timeseries([HPXML::LocationLivingSpace.upcase], [sp_var], 9.0 / 5.0, 32.0, timeseries_frequency)
      end
    end

    # Airflows
    if include_timeseries_airflows
      @airflows.each do |_airflow_type, airflow|
        airflow.timeseries_output = get_report_variable_data_timeseries(['EMS'], airflow.ems_variables.map { |var| "#{var}_timeseries_outvar" }, UnitConversions.convert(1.0, 'm^3/s', 'cfm'), 0, timeseries_frequency)
      end
    end

    # Weather
    if include_timeseries_weather
      @weather.each do |_weather_type, weather_data|
        if weather_data.timeseries_units == 'F'
          unit_conv = 9.0 / 5.0
          unit_adder = 32.0
        else
          unit_conv = UnitConversions.convert(1.0, weather_data.variable_units, weather_data.timeseries_units)
          unit_adder = 0
        end
        weather_data.timeseries_output = get_report_variable_data_timeseries(['Environment'], [weather_data.variable], unit_conv, unit_adder, timeseries_frequency)
      end
    end

    @output_variables = {}
    @output_variables_requests.each do |output_variable_name, _output_variable|
      key_values, units = get_report_variable_data_timeseries_key_values_and_units(output_variable_name)
      runner.registerWarning("Request for output variable '#{output_variable_name}' returned no key values.") if key_values.empty?
      key_values.each do |key_value|
        @output_variables[[output_variable_name, key_value]] = OutputVariable.new
        @output_variables[[output_variable_name, key_value]].name = "#{output_variable_name}: #{key_value.split.map(&:capitalize).join(' ')}"
        @output_variables[[output_variable_name, key_value]].timeseries_units = units
        @output_variables[[output_variable_name, key_value]].timeseries_output = get_report_variable_data_timeseries([key_value], [output_variable_name], 1, 0, timeseries_frequency)
      end
    end

    # Emissions
    if not @emissions.empty?
      kwh_to_mwh = UnitConversions.convert(1.0, 'kWh', 'MWh')

      # Calculate for each scenario
      @hpxml.header.emissions_scenarios.each do |scenario|
        key = [scenario.emissions_type, scenario.name]

        # Get hourly electricity factors
        if not scenario.elec_schedule_filepath.nil?
          # Obtain Cambium hourly factors for the simulation run period
          num_header_rows = scenario.elec_schedule_number_of_header_rows
          col_index = scenario.elec_schedule_column_number - 1
          data = File.readlines(scenario.elec_schedule_filepath)[num_header_rows, 8760]
          hourly_elec_factors = data.map { |x| x.split(',')[col_index].strip }
          begin
            hourly_elec_factors = hourly_elec_factors.map { |x| Float(x) }
          rescue
            fail 'Emissions File has non-numeric values.'
          end
        elsif not scenario.elec_value.nil?
          # Use annual value for all hours
          hourly_elec_factors = [scenario.elec_value] * 8760
        end
        year = 1999 # Try non-leap year for calculations
        sim_start_day_of_year, sim_end_day_of_year, sim_start_hour, sim_end_hour = get_sim_times_of_year(year)
        hourly_elec_factors = hourly_elec_factors[sim_start_hour..sim_end_hour]

        # Calculate annual/timeseries emissions for each end use
        @end_uses.each do |eu_key, end_use|
          fuel_type, _end_use_type = eu_key
          next unless fuel_type == FT::Elec
          next unless end_use.hourly_output.size > 0

          hourly_elec = end_use.hourly_output

          if hourly_elec.size == hourly_elec_factors[sim_start_hour..sim_end_hour].size + 24
            # Use leap-year for calculations
            year = 2000
            sim_start_day_of_year, sim_end_day_of_year, sim_start_hour, sim_end_hour = get_sim_times_of_year(year)
            # Duplicate Feb 28 Cambium values for Feb 29
            hourly_elec_factors = hourly_elec_factors[0..1415] + hourly_elec_factors[1392..1415] + hourly_elec_factors[1416..8759]
          end
          hourly_elec_factors = hourly_elec_factors[sim_start_hour..sim_end_hour] # Trim to sim period

          fail 'Unexpected failure for emissions calculations.' if hourly_elec_factors.size != hourly_elec.size

          # Calculate annual emissions for end use
          if scenario.elec_units == HPXML::EmissionsScenario::UnitsKgPerMWh
            elec_units_mult = UnitConversions.convert(1.0, 'kg', 'lbm')
          elsif scenario.elec_units == HPXML::EmissionsScenario::UnitsLbPerMWh
            elec_units_mult = 1.0
          end
          @emissions[key].annual_output_by_end_use[eu_key] = hourly_elec.zip(hourly_elec_factors).map { |x, y| x * y * kwh_to_mwh * elec_units_mult }.sum

          next unless include_timeseries_emissions || include_timeseries_emission_end_uses || include_timeseries_emission_fuels

          # Calculate timeseries emissions for end use

          if timeseries_frequency == 'timestep' && @hpxml.header.timestep != 60
            timeseries_elec = nil
            end_use.timeseries_output_by_system.each do |_sys_id, timeseries_output|
              timeseries_elec = [0.0] * timeseries_output.size if timeseries_elec.nil?
              timeseries_elec = timeseries_elec.zip(timeseries_output.map { |x| x * kwh_to_mwh }).map { |x, y| x + y }
            end
          else
            # Need to perform calculations hourly at a minimum
            timeseries_elec = end_use.hourly_output.map { |x| x * kwh_to_mwh }
          end

          if timeseries_frequency == 'timestep'
            n_timesteps_per_hour = Integer(60.0 / @hpxml.header.timestep)
            timeseries_elec_factors = hourly_elec_factors.flat_map { |y| [y] * n_timesteps_per_hour }
          else
            timeseries_elec_factors = hourly_elec_factors.dup
          end
          fail 'Unexpected failure for emissions calculations.' if timeseries_elec_factors.size != timeseries_elec.size

          @emissions[key].timeseries_output_by_end_use[eu_key] = timeseries_elec.zip(timeseries_elec_factors).map { |n, f| n * f * elec_units_mult }

          # Aggregate up from hourly to the desired timeseries frequency
          next unless ['daily', 'monthly'].include? timeseries_frequency

          if timeseries_frequency == 'daily'
            n_hours_per_period = [24] * (sim_end_day_of_year - sim_start_day_of_year + 1)
          elsif timeseries_frequency == 'monthly'
            n_days_per_month = Constants.NumDaysInMonths(year)
            n_days_per_period = n_days_per_month[@hpxml.header.sim_begin_month - 1..@hpxml.header.sim_end_month - 1]
            n_days_per_period[0] -= @hpxml.header.sim_begin_day - 1
            n_days_per_period[-1] = @hpxml.header.sim_end_day
            n_hours_per_period = n_days_per_period.map { |x| x * 24 }
          end
          fail 'Unexpected failure for emissions calculations.' if n_hours_per_period.sum != @emissions[key].timeseries_output_by_end_use[eu_key].size

          timeseries_output = []
          start_hour = 0
          n_hours_per_period.each do |n_hours|
            timeseries_output << @emissions[key].timeseries_output_by_end_use[eu_key][start_hour..start_hour + n_hours - 1].sum()
            start_hour += n_hours
          end
          @emissions[key].timeseries_output_by_end_use[eu_key] = timeseries_output
        end

        # Calculate emissions for fossil fuels
        @end_uses.each do |eu_key, end_use|
          fuel_type, _end_use_type = eu_key
          next if fuel_type == FT::Elec

          fuel_map = { FT::Gas => [scenario.natural_gas_units, scenario.natural_gas_value],
                       FT::Propane => [scenario.propane_units, scenario.propane_value],
                       FT::Oil => [scenario.fuel_oil_units, scenario.fuel_oil_value],
                       FT::Coal => [scenario.coal_units, scenario.coal_value],
                       FT::WoodCord => [scenario.wood_units, scenario.wood_value],
                       FT::WoodPellets => [scenario.wood_pellets_units, scenario.wood_pellets_value] }
          fuel_units, fuel_factor = fuel_map[fuel_type]
          if fuel_factor.nil?
            if end_use.annual_output != 0
              runner.registerWarning("No emissions factor found for Scenario=#{scenario.name}, Type=#{scenario.emissions_type}, Fuel=#{fuel_type}.")
            end
            fuel_factor = 0.0
            fuel_units_mult = 0.0
          elsif fuel_units == HPXML::EmissionsScenario::UnitsKgPerMBtu
            fuel_units_mult = UnitConversions.convert(1.0, 'kg', 'lbm')
          elsif fuel_units == HPXML::EmissionsScenario::UnitsLbPerMBtu
            fuel_units_mult = 1.0
          end

          @emissions[key].annual_output_by_end_use[eu_key] = UnitConversions.convert(end_use.annual_output, end_use.annual_units, 'MBtu') * fuel_factor * fuel_units_mult
          next unless include_timeseries_emissions || include_timeseries_emission_end_uses || include_timeseries_emission_fuels

          fuel_to_mbtu = UnitConversions.convert(1.0, end_use.timeseries_units, 'MBtu')

          end_use.timeseries_output_by_system.each do |_sys_id, timeseries_output|
            @emissions[key].timeseries_output_by_end_use[eu_key] = [0.0] * timeseries_output.size if @emissions[key].timeseries_output_by_end_use[eu_key].nil?
            @emissions[key].timeseries_output_by_end_use[eu_key] = @emissions[key].timeseries_output_by_end_use[eu_key].zip(timeseries_output.map { |f| f * fuel_to_mbtu * fuel_factor * fuel_units_mult }).map { |x, y| x + y }
          end
        end

        # Roll up end use emissions to fuel emissions
        @fuels.each do |fuel_type, _fuel|
          @emissions[key].annual_output_by_fuel[fuel_type] = 0.0
          @emissions[key].annual_output_by_end_use.keys.each do |eu_key|
            next unless eu_key[0] == fuel_type
            next if @emissions[key].annual_output_by_end_use[eu_key] == 0

            @emissions[key].annual_output_by_fuel[fuel_type] += @emissions[key].annual_output_by_end_use[eu_key]

            next unless include_timeseries_emissions || include_timeseries_emission_end_uses || include_timeseries_emission_fuels

            @emissions[key].timeseries_output_by_fuel[fuel_type] = [0.0] * @emissions[key].timeseries_output_by_end_use[eu_key].size if @emissions[key].timeseries_output_by_fuel[fuel_type].nil?
            @emissions[key].timeseries_output_by_fuel[fuel_type] = @emissions[key].timeseries_output_by_fuel[fuel_type].zip(@emissions[key].timeseries_output_by_end_use[eu_key]).map { |x, y| x + y }
          end
        end

        # Sum individual fuel results for total
        @emissions[key].annual_output = @emissions[key].annual_output_by_fuel.values.sum()
        next unless not @emissions[key].timeseries_output_by_fuel.empty?

        @emissions[key].timeseries_output = @emissions[key].timeseries_output_by_fuel.first[1]
        @emissions[key].timeseries_output_by_fuel.each_with_index do |(_fuel, timeseries_output), i|
          next if i == 0

          @emissions[key].timeseries_output = @emissions[key].timeseries_output.zip(timeseries_output).map { |x, y| x + y }
        end
      end
    end

    return outputs
  end

  def get_sim_times_of_year(year)
    sim_start_day_of_year = Schedule.get_day_num_from_month_day(year, @hpxml.header.sim_begin_month, @hpxml.header.sim_begin_day)
    sim_end_day_of_year = Schedule.get_day_num_from_month_day(year, @hpxml.header.sim_end_month, @hpxml.header.sim_end_day)
    sim_start_hour = (sim_start_day_of_year - 1) * 24
    sim_end_hour = sim_end_day_of_year * 24 - 1
    return sim_start_day_of_year, sim_end_day_of_year, sim_start_hour, sim_end_hour
  end

  def check_for_errors(runner, outputs)
    tol = 0.1

    # ElectricityProduced:Facility contains:
    # - Generator Produced DC Electricity Energy
    # - Inverter Conversion Loss Decrement Energy
    # - Electric Storage Production Decrement Energy
    # - Electric Storage Discharge Energy
    # - Converter Electricity Loss Decrement Energy (should always be zero since efficiency=1.0)
    # ElectricStorage:ElectricityProduced contains:
    # - Electric Storage Production Decrement Energy
    # - Electric Storage Discharge Energy
    # So, we need to subtract ElectricStorage:ElectricityProduced from ElectricityProduced:Facility
    meter_elec_produced = -1 * get_report_meter_data_annual(['ElectricityProduced:Facility'])
    meter_elec_produced += get_report_meter_data_annual(['ElectricStorage:ElectricityProduced'])

    # Check if simulation successful
    all_total = @fuels.values.map { |x| x.annual_output.to_f }.sum(0.0)
    all_total += @ideal_system_loads.values.map { |x| x.annual_output.to_f }.sum(0.0)
    if all_total == 0
      runner.registerError('Simulation unsuccessful.')
      return false
    elsif all_total.infinite?
      runner.registerError('Simulation used infinite energy; double-check inputs.')
      return false
    end

    # Check sum of electricity produced end use outputs match total output from meter
    if (outputs[:elec_prod_annual] - meter_elec_produced).abs > tol
      runner.registerError("#{FT::Elec} produced category end uses (#{outputs[:elec_prod_annual].round(3)}) do not sum to total (#{meter_elec_produced.round(3)}).")
      return false
    end

    # Check sum of end use outputs match fuel outputs from meters
    @fuels.keys.each do |fuel_type|
      sum_categories = @end_uses.select { |k, _eu| k[0] == fuel_type }.map { |_k, eu| eu.annual_output.to_f }.sum(0.0)
      meter_fuel_total = @fuels[fuel_type].annual_output.to_f
      if fuel_type == FT::Elec
        meter_fuel_total += meter_elec_produced
      end

      if (sum_categories - meter_fuel_total).abs > tol
        runner.registerError("#{fuel_type} category end uses (#{sum_categories.round(3)}) do not sum to total (#{meter_fuel_total.round(3)}).")
        return false
      end
    end

    # Check sum of timeseries outputs match annual outputs
    { @totals => 'Total',
      @end_uses => 'End Use',
      @fuels => 'Fuel',
      @emissions => 'Emissions',
      @loads => 'Load',
      @component_loads => 'Component Load' }.each do |outputs, output_type|
      outputs.each do |key, obj|
        next if obj.timeseries_output.empty?

        sum_timeseries = UnitConversions.convert(obj.timeseries_output.sum(0.0), obj.timeseries_units, obj.annual_units)
        annual_total = obj.annual_output.to_f
        if (annual_total - sum_timeseries).abs > tol
          runner.registerError("Timeseries outputs (#{sum_timeseries.round(3)}) do not sum to annual output (#{annual_total.round(3)}) for #{output_type}: #{key}.")
          return false
        end
      end
    end

    return true
  end

  def report_runperiod_output_results(runner, outputs, output_format, annual_output_path, n_digits, generate_eri_outputs)
    line_break = nil

    results_out = []
    @totals.each do |_energy_type, total_energy|
      results_out << ["#{total_energy.name} (#{total_energy.annual_units})", total_energy.annual_output.to_f.round(n_digits)]
    end
    results_out << [line_break]
    @fuels.each do |fuel_type, fuel|
      results_out << ["#{fuel.name} (#{fuel.annual_units})", fuel.annual_output.to_f.round(n_digits)]
      if fuel_type == FT::Elec
        results_out << ['Fuel Use: Electricity: Net (MBtu)', outputs[:elec_net_annual].round(n_digits)]
      end
    end
    results_out << [line_break]
    @end_uses.each do |_key, end_use|
      results_out << ["#{end_use.name} (#{end_use.annual_units})", end_use.annual_output.to_f.round(n_digits)]
    end
    if not @emissions.empty?
      results_out << [line_break]
      @emissions.each do |_scenario_key, emission|
        # Emissions total
        results_out << ["#{emission.name}: Total (#{emission.annual_units})", emission.annual_output.to_f.round(2)]
        # Emissions by fuel
        emission.annual_output_by_fuel.each do |fuel, annual_output|
          next if annual_output.to_f == 0

          results_out << ["#{emission.name}: #{fuel}: Total (#{emission.annual_units})", annual_output.to_f.round(2)]
          # Emissions by end use
          emission.annual_output_by_end_use.each do |key, eu_annual_output|
            fuel_type, end_use_type = key
            next unless fuel_type == fuel
            next if eu_annual_output.to_f == 0

            results_out << ["#{emission.name}: #{fuel_type}: #{end_use_type} (#{emission.annual_units})", eu_annual_output.to_f.round(2)]
          end
        end
      end
    end
    results_out << [line_break]
    @loads.each do |_load_type, load|
      results_out << ["#{load.name} (#{load.annual_units})", load.annual_output.to_f.round(n_digits)]
    end
    results_out << [line_break]
    @unmet_hours.each do |_load_type, unmet_hour|
      results_out << ["#{unmet_hour.name} (#{unmet_hour.annual_units})", unmet_hour.annual_output.to_f.round(n_digits)]
    end
    results_out << [line_break]
    @peak_fuels.each do |_key, peak_fuel|
      results_out << ["#{peak_fuel.name} (#{peak_fuel.annual_units})", peak_fuel.annual_output.to_f.round(n_digits - 2)]
    end
    results_out << [line_break]
    @peak_loads.each do |_load_type, peak_load|
      results_out << ["#{peak_load.name} (#{peak_load.annual_units})", peak_load.annual_output.to_f.round(n_digits)]
    end
    if @component_loads.values.map { |load| load.annual_output.to_f }.sum != 0 # Skip if component loads not calculated
      results_out << [line_break]
      @component_loads.each do |_load_type, load|
        results_out << ["#{load.name} (#{load.annual_units})", load.annual_output.to_f.round(n_digits)]
      end
    end
    results_out << [line_break]
    @hot_water_uses.each do |_hot_water_type, hot_water|
      results_out << ["#{hot_water.name} (#{hot_water.annual_units})", hot_water.annual_output.to_f.round(n_digits - 2)]
    end

    results_out = append_sizing_results(results_out, line_break)
    if generate_eri_outputs
      results_out = append_eri_results(results_out, line_break)
    end

    if ['csv'].include? output_format
      CSV.open(annual_output_path, 'wb') { |csv| results_out.to_a.each { |elem| csv << elem } }
    elsif ['json', 'msgpack'].include? output_format
      h = {}
      results_out.each do |out|
        next if out == [line_break]

        grp, name = out[0].split(':', 2)
        h[grp] = {} if h[grp].nil?
        h[grp][name.strip] = out[1]
      end

      if output_format == 'json'
        require 'json'
        File.open(annual_output_path, 'w') { |json| json.write(JSON.pretty_generate(h)) }
      elsif output_format == 'msgpack'
        File.open(annual_output_path, 'w') { |json| h.to_msgpack(json) }
      end
    end
    runner.registerInfo("Wrote annual output results to #{annual_output_path}.")

    results_out.each do |name, value|
      next if name.nil? || value.nil?

      name = OpenStudio::toUnderscoreCase(name).chomp('_')

      runner.registerValue(name, value)
      runner.registerInfo("Registering #{value} for #{name}.")
    end
  end

  def get_runner_output_name(name, annual_units)
    return "#{name} #{annual_units}"
  end

  def append_sizing_results(results_out, line_break)
    # Summary HVAC capacities
    htg_cap, clg_cap, hp_backup_cap = 0.0, 0.0, 0.0
    @hpxml.hvac_systems.each do |hvac_system|
      if hvac_system.is_a? HPXML::HeatingSystem
        next if hvac_system.is_heat_pump_backup_system

        htg_cap += hvac_system.heating_capacity.to_f
      elsif hvac_system.is_a? HPXML::CoolingSystem
        clg_cap += hvac_system.cooling_capacity.to_f
        if hvac_system.has_integrated_heating
          htg_cap += hvac_system.integrated_heating_system_capacity.to_f
        end
      elsif hvac_system.is_a? HPXML::HeatPump
        htg_cap += hvac_system.heating_capacity.to_f
        clg_cap += hvac_system.cooling_capacity.to_f
        if hvac_system.backup_type == HPXML::HeatPumpBackupTypeIntegrated
          hp_backup_cap += hvac_system.backup_heating_capacity.to_f
        elsif hvac_system.backup_type == HPXML::HeatPumpBackupTypeSeparate
          hp_backup_cap += hvac_system.backup_system.heating_capacity.to_f
        end
      end
    end
    results_out << [line_break]
    results_out << ['HVAC Capacity: Heating (Btu/h)', htg_cap.round(1)]
    results_out << ['HVAC Capacity: Cooling (Btu/h)', clg_cap.round(1)]
    results_out << ['HVAC Capacity: Heat Pump Backup (Btu/h)', hp_backup_cap.round(1)]

    # HVAC design temperatures
    results_out << [line_break]
    results_out << ['HVAC Design Temperature: Heating (F)', @hpxml.hvac_plant.temp_heating.round(2)]
    results_out << ['HVAC Design Temperature: Cooling (F)', @hpxml.hvac_plant.temp_cooling.round(2)]

    # HVAC design loads
    results_out << [line_break]
    results_out << ['HVAC Design Load: Heating: Total (Btu/h)', @hpxml.hvac_plant.hdl_total.round(1)]
    results_out << ['HVAC Design Load: Heating: Ducts (Btu/h)', @hpxml.hvac_plant.hdl_ducts.round(1)]
    results_out << ['HVAC Design Load: Heating: Windows (Btu/h)', @hpxml.hvac_plant.hdl_windows.round(1)]
    results_out << ['HVAC Design Load: Heating: Skylights (Btu/h)', @hpxml.hvac_plant.hdl_skylights.round(1)]
    results_out << ['HVAC Design Load: Heating: Doors (Btu/h)', @hpxml.hvac_plant.hdl_doors.round(1)]
    results_out << ['HVAC Design Load: Heating: Walls (Btu/h)', @hpxml.hvac_plant.hdl_walls.round(1)]
    results_out << ['HVAC Design Load: Heating: Roofs (Btu/h)', @hpxml.hvac_plant.hdl_roofs.round(1)]
    results_out << ['HVAC Design Load: Heating: Floors (Btu/h)', @hpxml.hvac_plant.hdl_floors.round(1)]
    results_out << ['HVAC Design Load: Heating: Slabs (Btu/h)', @hpxml.hvac_plant.hdl_slabs.round(1)]
    results_out << ['HVAC Design Load: Heating: Ceilings (Btu/h)', @hpxml.hvac_plant.hdl_ceilings.round(1)]
    results_out << ['HVAC Design Load: Heating: Infiltration/Ventilation (Btu/h)', @hpxml.hvac_plant.hdl_infilvent.round(1)]
    results_out << ['HVAC Design Load: Cooling Sensible: Total (Btu/h)', @hpxml.hvac_plant.cdl_sens_total.round(1)]
    results_out << ['HVAC Design Load: Cooling Sensible: Ducts (Btu/h)', @hpxml.hvac_plant.cdl_sens_ducts.round(1)]
    results_out << ['HVAC Design Load: Cooling Sensible: Windows (Btu/h)', @hpxml.hvac_plant.cdl_sens_windows.round(1)]
    results_out << ['HVAC Design Load: Cooling Sensible: Skylights (Btu/h)', @hpxml.hvac_plant.cdl_sens_skylights.round(1)]
    results_out << ['HVAC Design Load: Cooling Sensible: Doors (Btu/h)', @hpxml.hvac_plant.cdl_sens_doors.round(1)]
    results_out << ['HVAC Design Load: Cooling Sensible: Walls (Btu/h)', @hpxml.hvac_plant.cdl_sens_walls.round(1)]
    results_out << ['HVAC Design Load: Cooling Sensible: Roofs (Btu/h)', @hpxml.hvac_plant.cdl_sens_roofs.round(1)]
    results_out << ['HVAC Design Load: Cooling Sensible: Floors (Btu/h)', @hpxml.hvac_plant.cdl_sens_floors.round(1)]
    results_out << ['HVAC Design Load: Cooling Sensible: Slabs (Btu/h)', @hpxml.hvac_plant.cdl_sens_slabs.round(1)]
    results_out << ['HVAC Design Load: Cooling Sensible: Ceilings (Btu/h)', @hpxml.hvac_plant.cdl_sens_ceilings.round(1)]
    results_out << ['HVAC Design Load: Cooling Sensible: Infiltration/Ventilation (Btu/h)', @hpxml.hvac_plant.cdl_sens_infilvent.round(1)]
    results_out << ['HVAC Design Load: Cooling Sensible: Internal Gains (Btu/h)', @hpxml.hvac_plant.cdl_sens_intgains.round(1)]
    results_out << ['HVAC Design Load: Cooling Latent: Total (Btu/h)', @hpxml.hvac_plant.cdl_lat_total.round(1)]
    results_out << ['HVAC Design Load: Cooling Latent: Ducts (Btu/h)', @hpxml.hvac_plant.cdl_lat_ducts.round(1)]
    results_out << ['HVAC Design Load: Cooling Latent: Infiltration/Ventilation (Btu/h)', @hpxml.hvac_plant.cdl_lat_infilvent.round(1)]
    results_out << ['HVAC Design Load: Cooling Latent: Internal Gains (Btu/h)', @hpxml.hvac_plant.cdl_lat_intgains.round(1)]

    return results_out
  end

  def append_eri_results(results_out, line_break)
    def ordered_values(hash, sys_ids)
      vals = []
      sys_ids.each do |sys_id|
        if not hash[sys_id].nil?
          if hash[sys_id].is_a? Float
            vals << hash[sys_id].round(3)
          else
            vals << hash[sys_id]
          end
        else
          vals << 0.0
        end
      end
      return if vals.empty?

      return vals.join(',')
    end

    def get_eec_value_numerator(unit)
      if ['HSPF', 'HSPF2', 'SEER', 'SEER2', 'EER', 'CEER'].include? unit
        return 3.413
      elsif ['AFUE', 'COP', 'Percent', 'EF'].include? unit
        return 1.0
      end
    end

    def get_ids(ids, seed_id_map = {})
      new_ids = ids.map { |id| seed_id_map[id].nil? ? id : seed_id_map[id] }
      return if new_ids.empty?

      return new_ids.join(',')
    end

    # Retrieve info from HPXML object
    htg_ids, clg_ids, dhw_ids, prehtg_ids, preclg_ids = [], [], [], [], []
    htg_eecs, clg_eecs, dhw_eecs, prehtg_eecs, preclg_eecs = {}, {}, {}, {}, {}
    htg_fuels, clg_fuels, dhw_fuels, prehtg_fuels, preclg_fuels = {}, {}, {}, {}, {}
    htg_seed_id_map, clg_seed_id_map = {}, {}
    @hpxml.heating_systems.each do |htg_system|
      next unless htg_system.fraction_heat_load_served > 0

      htg_ids << htg_system.id
      htg_seed_id_map[htg_system.id] = htg_system.htg_seed_id
      htg_fuels[htg_system.id] = htg_system.heating_system_fuel
      if not htg_system.heating_efficiency_afue.nil?
        htg_eecs[htg_system.id] = get_eec_value_numerator('AFUE') / htg_system.heating_efficiency_afue
      elsif not htg_system.heating_efficiency_percent.nil?
        htg_eecs[htg_system.id] = get_eec_value_numerator('Percent') / htg_system.heating_efficiency_percent
      end
    end
    @hpxml.cooling_systems.each do |clg_system|
      if clg_system.has_integrated_heating && clg_system.integrated_heating_system_fraction_heat_load_served > 0
        # Cooling system w/ integrated heating (e.g., Room AC w/ electric resistance heating)
        htg_ids << clg_system.id
        htg_seed_id_map[clg_system.id] = clg_system.htg_seed_id
        htg_fuels[clg_system.id] = clg_system.integrated_heating_system_fuel
        htg_eecs[clg_system.id] = get_eec_value_numerator('Percent') / clg_system.integrated_heating_system_efficiency_percent
      end

      next unless clg_system.fraction_cool_load_served > 0

      clg_ids << clg_system.id
      clg_seed_id_map[clg_system.id] = clg_system.clg_seed_id
      clg_fuels[clg_system.id] = clg_system.cooling_system_fuel
      if not clg_system.cooling_efficiency_seer.nil?
        clg_eecs[clg_system.id] = get_eec_value_numerator('SEER') / clg_system.cooling_efficiency_seer
      elsif not clg_system.cooling_efficiency_seer2.nil?
        clg_eecs[clg_system.id] = get_eec_value_numerator('SEER2') / clg_system.cooling_efficiency_seer2
      elsif not clg_system.cooling_efficiency_eer.nil?
        clg_eecs[clg_system.id] = get_eec_value_numerator('EER') / clg_system.cooling_efficiency_eer
      elsif not clg_system.cooling_efficiency_ceer.nil?
        clg_eecs[clg_system.id] = get_eec_value_numerator('CEER') / clg_system.cooling_efficiency_ceer
      end
      if clg_system.cooling_system_type == HPXML::HVACTypeEvaporativeCooler
        clg_eecs[clg_system.id] = get_eec_value_numerator('SEER') / 15.0 # Arbitrary
      end
    end
    @hpxml.heat_pumps.each do |heat_pump|
      if heat_pump.fraction_heat_load_served > 0
        htg_ids << heat_pump.id
        htg_seed_id_map[heat_pump.id] = heat_pump.htg_seed_id
        htg_fuels[heat_pump.id] = heat_pump.heat_pump_fuel
        if not heat_pump.heating_efficiency_hspf.nil?
          htg_eecs[heat_pump.id] = get_eec_value_numerator('HSPF') / heat_pump.heating_efficiency_hspf
        elsif not heat_pump.heating_efficiency_hspf2.nil?
          htg_eecs[heat_pump.id] = get_eec_value_numerator('HSPF2') / heat_pump.heating_efficiency_hspf2
        elsif not heat_pump.heating_efficiency_cop.nil?
          htg_eecs[heat_pump.id] = get_eec_value_numerator('COP') / heat_pump.heating_efficiency_cop
        end
      end
      next unless heat_pump.fraction_cool_load_served > 0

      clg_ids << heat_pump.id
      clg_seed_id_map[heat_pump.id] = heat_pump.clg_seed_id
      clg_fuels[heat_pump.id] = heat_pump.heat_pump_fuel
      if not heat_pump.cooling_efficiency_seer.nil?
        clg_eecs[heat_pump.id] = get_eec_value_numerator('SEER') / heat_pump.cooling_efficiency_seer
      elsif not heat_pump.cooling_efficiency_seer2.nil?
        clg_eecs[heat_pump.id] = get_eec_value_numerator('SEER2') / heat_pump.cooling_efficiency_seer2
      elsif not heat_pump.cooling_efficiency_eer.nil?
        clg_eecs[heat_pump.id] = get_eec_value_numerator('EER') / heat_pump.cooling_efficiency_eer
      end
    end
    @hpxml.water_heating_systems.each do |dhw_system|
      dhw_ids << dhw_system.id
      ef_or_uef = nil
      ef_or_uef = dhw_system.energy_factor unless dhw_system.energy_factor.nil?
      ef_or_uef = dhw_system.uniform_energy_factor unless dhw_system.uniform_energy_factor.nil?
      if ef_or_uef.nil?
        # Get assumed EF for combi system
        @model.getWaterHeaterMixeds.each do |wh|
          dhw_id = wh.additionalProperties.getFeatureAsString('HPXML_ID')
          next unless (dhw_id.is_initialized && dhw_id.get == dhw_system.id)

          ef_or_uef = wh.additionalProperties.getFeatureAsDouble('EnergyFactor').get
        end
      end
      value_adj = 1.0
      value_adj = dhw_system.performance_adjustment if dhw_system.water_heater_type == HPXML::WaterHeaterTypeTankless
      if (not ef_or_uef.nil?) && (not value_adj.nil?)
        dhw_eecs[dhw_system.id] = get_eec_value_numerator('EF') / (Float(ef_or_uef) * Float(value_adj))
      end
      if [HPXML::WaterHeaterTypeCombiTankless, HPXML::WaterHeaterTypeCombiStorage].include? dhw_system.water_heater_type
        dhw_fuels[dhw_system.id] = dhw_system.related_hvac_system.heating_system_fuel
      else
        dhw_fuels[dhw_system.id] = dhw_system.fuel_type
      end
    end
    @hpxml.ventilation_fans.each do |vent_fan|
      next unless vent_fan.used_for_whole_building_ventilation
      next if vent_fan.is_cfis_supplemental_fan?

      if not vent_fan.preheating_fuel.nil?
        prehtg_ids << vent_fan.id
        prehtg_fuels[vent_fan.id] = vent_fan.preheating_fuel
        prehtg_eecs[vent_fan.id] = get_eec_value_numerator('COP') / vent_fan.preheating_efficiency_cop
      end
      next unless not vent_fan.precooling_fuel.nil?

      preclg_ids << vent_fan.id
      preclg_fuels[vent_fan.id] = vent_fan.precooling_fuel
      preclg_eecs[vent_fan.id] = get_eec_value_numerator('COP') / vent_fan.precooling_efficiency_cop
    end

    # Apportion ERI Reference loads to systems
    (@hpxml.heating_systems + @hpxml.heat_pumps).each do |htg_system|
      next unless htg_ids.include? htg_system.id

      @loads[LT::Heating].annual_output_by_system[htg_system.id] = htg_system.fraction_heat_load_served * @loads[LT::Heating].annual_output
    end
    (@hpxml.cooling_systems + @hpxml.heat_pumps).each do |clg_system|
      if clg_ids.include? clg_system.id
        @loads[LT::Cooling].annual_output_by_system[clg_system.id] = clg_system.fraction_cool_load_served * @loads[LT::Cooling].annual_output
      end
      next unless (clg_system.is_a? HPXML::CoolingSystem) && clg_system.has_integrated_heating # Cooling system w/ integrated heating (e.g., Room AC w/ electric resistance heating)

      if htg_ids.include? clg_system.id
        @loads[LT::Heating].annual_output_by_system[clg_system.id] = clg_system.integrated_heating_system_fraction_heat_load_served * @loads[LT::Heating].annual_output
      end
    end

    # Handle dual-fuel heat pumps
    @hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.is_dual_fuel

      # Create separate dual fuel heat pump backup system
      dfhp_backup_id = heat_pump.id + '_DFHPBackup'
      htg_ids << dfhp_backup_id
      htg_seed_id_map[dfhp_backup_id] = heat_pump.htg_seed_id + '_DFHPBackup'
      htg_fuels[dfhp_backup_id] = heat_pump.backup_heating_fuel
      if not heat_pump.backup_heating_efficiency_afue.nil?
        htg_eecs[dfhp_backup_id] = get_eec_value_numerator('AFUE') / heat_pump.backup_heating_efficiency_afue
      elsif not heat_pump.backup_heating_efficiency_percent.nil?
        htg_eecs[dfhp_backup_id] = get_eec_value_numerator('Percent') / heat_pump.backup_heating_efficiency_percent
      end

      # Apportion heating load for the two systems
      primary_load, backup_load = nil
      @object_variables_by_key[[LT, LT::Heating]].each do |vals|
        sys_id, key_name, var_name = vals
        if sys_id == heat_pump.id
          primary_load = get_report_variable_data_annual([key_name], [var_name])
        elsif sys_id == heat_pump.id + '_DFHPBackup'
          backup_load = get_report_variable_data_annual([key_name], [var_name])
        end
      end
      fail 'Could not obtain DFHP loads.' if primary_load.nil? || backup_load.nil?

      total_load = @loads[LT::Heating].annual_output_by_system[heat_pump.id]
      backup_ratio = backup_load / (primary_load + backup_load)
      @loads[LT::Heating].annual_output_by_system[dfhp_backup_id] = total_load * backup_ratio
      @loads[LT::Heating].annual_output_by_system[heat_pump.id] = total_load * (1.0 - backup_ratio)
    end

    # Collect final ERI Reference loads by system
    htg_loads, clg_loads, dhw_loads = {}, {}, {}
    @loads.each do |load_type, load|
      if load_type == LT::Heating
        htg_loads = load.annual_output_by_system
      elsif load_type == LT::Cooling
        clg_loads = load.annual_output_by_system
      elsif load_type == LT::HotWaterDelivered
        dhw_loads = load.annual_output_by_system
      end
    end

    # Collect energy consumption (EC) by system
    htg_ecs, clg_ecs, dhw_ecs, prehtg_ecs, preclg_ecs = {}, {}, {}, {}, {}
    eut_map = { EUT::Heating => htg_ecs,
                EUT::HeatingHeatPumpBackup => htg_ecs,
                EUT::HeatingFanPump => htg_ecs,
                EUT::Cooling => clg_ecs,
                EUT::CoolingFanPump => clg_ecs,
                EUT::HotWater => dhw_ecs,
                EUT::HotWaterRecircPump => dhw_ecs,
                EUT::HotWaterSolarThermalPump => dhw_ecs,
                EUT::MechVentPreheat => prehtg_ecs,
                EUT::MechVentPrecool => preclg_ecs }
    @end_uses.each do |key, end_use|
      _fuel_type, end_use_type = key
      ec_obj = eut_map[end_use_type]
      next if ec_obj.nil?

      end_use.annual_output_by_system.each do |sys_id, val|
        ec_obj[sys_id] = 0.0 if ec_obj[sys_id].nil?
        ec_obj[sys_id] += val
      end
    end

    results_out << [line_break]

    # Building
    results_out << ['ERI: Building: CFA', @hpxml.building_construction.conditioned_floor_area]
    results_out << ['ERI: Building: NumBedrooms', @hpxml.building_construction.number_of_bedrooms]
    results_out << ['ERI: Building: NumStories', @hpxml.building_construction.number_of_conditioned_floors_above_grade]
    results_out << ['ERI: Building: Type', @hpxml.building_construction.residential_facility_type]

    # Heating
    results_out << ['ERI: Heating: ID', get_ids(htg_ids, htg_seed_id_map)]
    results_out << ['ERI: Heating: FuelType', ordered_values(htg_fuels, htg_ids)]
    results_out << ['ERI: Heating: EC', ordered_values(htg_ecs, htg_ids)]
    results_out << ['ERI: Heating: EEC', ordered_values(htg_eecs, htg_ids)]
    results_out << ['ERI: Heating: Load', ordered_values(htg_loads, htg_ids)]

    # Cooling
    results_out << ['ERI: Cooling: ID', get_ids(clg_ids, clg_seed_id_map)]
    results_out << ['ERI: Cooling: FuelType', ordered_values(clg_fuels, clg_ids)]
    results_out << ['ERI: Cooling: EC', ordered_values(clg_ecs, clg_ids)]
    results_out << ['ERI: Cooling: EEC', ordered_values(clg_eecs, clg_ids)]
    results_out << ['ERI: Cooling: Load', ordered_values(clg_loads, clg_ids)]

    # Hot Water
    results_out << ['ERI: Hot Water: ID', get_ids(dhw_ids)]
    results_out << ['ERI: Hot Water: FuelType', ordered_values(dhw_fuels, dhw_ids)]
    results_out << ['ERI: Hot Water: EC', ordered_values(dhw_ecs, dhw_ids)]
    results_out << ['ERI: Hot Water: EEC', ordered_values(dhw_eecs, dhw_ids)]
    results_out << ['ERI: Hot Water: Load', ordered_values(dhw_loads, dhw_ids)]

    # Mech Vent Preheat
    results_out << ['ERI: Mech Vent Preheating: ID', get_ids(prehtg_ids)]
    results_out << ['ERI: Mech Vent Preheating: FuelType', ordered_values(prehtg_fuels, prehtg_ids)]
    results_out << ['ERI: Mech Vent Preheating: EC', ordered_values(prehtg_ecs, prehtg_ids)]
    results_out << ['ERI: Mech Vent Preheating: EEC', ordered_values(prehtg_eecs, prehtg_ids)]

    # Mech Vent Precool
    results_out << ['ERI: Mech Vent Precooling: ID', get_ids(preclg_ids)]
    results_out << ['ERI: Mech Vent Precooling: FuelType', ordered_values(preclg_fuels, preclg_ids)]
    results_out << ['ERI: Mech Vent Precooling: EC', ordered_values(preclg_ecs, preclg_ids)]
    results_out << ['ERI: Mech Vent Precooling: EEC', ordered_values(preclg_eecs, preclg_ids)]

    return results_out
  end

  def report_timeseries_output_results(runner, outputs, output_format,
                                       timeseries_output_path,
                                       timeseries_frequency,
                                       timeseries_num_decimal_places,
                                       include_timeseries_total_consumptions,
                                       include_timeseries_fuel_consumptions,
                                       include_timeseries_end_use_consumptions,
                                       include_timeseries_emissions,
                                       include_timeseries_emission_fuels,
                                       include_timeseries_emission_end_uses,
                                       include_timeseries_hot_water_uses,
                                       include_timeseries_total_loads,
                                       include_timeseries_component_loads,
                                       include_timeseries_unmet_hours,
                                       include_timeseries_zone_temperatures,
                                       include_timeseries_airflows,
                                       include_timeseries_weather,
                                       add_dst_column,
                                       add_utc_column,
                                       timestamps_dst,
                                       timestamps_utc,
                                       use_dview_format)
    return if @timestamps.nil?

    if not ['timestep', 'hourly', 'daily', 'monthly'].include? timeseries_frequency
      fail "Unexpected timeseries_frequency: #{timeseries_frequency}."
    end

    if not timeseries_num_decimal_places.nil?
      n_digits = timeseries_num_decimal_places
    else
      # Set rounding precision for timeseries (e.g., hourly) outputs.
      # Note: Make sure to round outputs with sufficient resolution for the worst case -- i.e., 1 minute date instead of hourly data.
      n_digits = 3 # Default for hourly (or longer) data
      if timeseries_frequency == 'timestep'
        if @hpxml.header.timestep <= 2 # 2-minute timesteps or shorter; add two decimal places
          n_digits += 2
        elsif @hpxml.header.timestep <= 15 # 15-minute timesteps or shorter; add one decimal place
          n_digits += 1
        end
      end
    end

    # Initial output data w/ Time column(s)
    data = ['Time', nil] + @timestamps
    if add_dst_column
      timestamps2 = [['TimeDST', nil] + timestamps_dst]
    else
      timestamps2 = []
    end
    if add_utc_column
      timestamps3 = [['TimeUTC', nil] + timestamps_utc]
    else
      timestamps3 = []
    end

    if include_timeseries_total_consumptions
      total_energy_data = []
      [TE::Total, TE::Net].each do |energy_type|
        next if (energy_type == TE::Net) && (outputs[:elec_prod_timeseries].sum(0.0) == 0)

        total_energy_data << [@totals[energy_type].name, @totals[energy_type].timeseries_units] + @totals[energy_type].timeseries_output.map { |v| v.round(n_digits) }
      end
    else
      total_energy_data = []
    end
    if include_timeseries_fuel_consumptions
      fuel_data = @fuels.values.select { |x| x.timeseries_output.sum(0.0) != 0 }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(n_digits) } }

      # Also add Net Electricity
      if outputs[:elec_prod_annual] != 0.0
        fuel_data.insert(1, ['Fuel Use: Electricity: Net', get_timeseries_units_from_fuel_type(FT::Elec)] + outputs[:elec_net_timeseries].map { |v| v.round(n_digits) })
      end
    else
      fuel_data = []
    end
    if include_timeseries_end_use_consumptions
      end_use_data = @end_uses.values.select { |x| x.timeseries_output.sum(0.0) != 0 }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(n_digits) } }
    else
      end_use_data = []
    end
    if include_timeseries_emissions
      emissions_data = []
      @emissions.values.each do |emission|
        next if emission.timeseries_output.sum(0.0) == 0

        emissions_data << ["#{emission.name}: Total", emission.timeseries_units] + emission.timeseries_output.map { |v| v.round(5) }
      end
    else
      emissions_data = []
    end
    if include_timeseries_emission_fuels
      emission_fuel_data = []
      @emissions.values.each do |emission|
        emission.timeseries_output_by_fuel.each do |fuel, timeseries_output|
          next if timeseries_output.sum(0.0) == 0

          emission_fuel_data << ["#{emission.name}: #{fuel}: Total", emission.timeseries_units] + timeseries_output.map { |v| v.round(5) }
        end
      end
    else
      emission_fuel_data = []
    end
    if include_timeseries_emission_end_uses
      emission_end_use_data = []
      @emissions.values.each do |emission|
        emission.timeseries_output_by_end_use.each do |key, timeseries_output|
          next if timeseries_output.sum(0.0) == 0

          fuel_type, end_use_type = key
          emission_end_use_data << ["#{emission.name}: #{fuel_type}: #{end_use_type}", emission.timeseries_units] + timeseries_output.map { |v| v.round(5) }
        end
      end
    else
      emission_end_use_data = []
    end
    if include_timeseries_hot_water_uses
      hot_water_use_data = @hot_water_uses.values.select { |x| x.timeseries_output.sum(0.0) != 0 }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(n_digits) } }
    else
      hot_water_use_data = []
    end
    if include_timeseries_total_loads
      total_loads_data = @loads.values.select { |x| x.timeseries_output.sum(0.0) != 0 }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(n_digits) } }
    else
      total_loads_data = {}
    end
    if include_timeseries_component_loads
      comp_loads_data = @component_loads.values.select { |x| x.timeseries_output.sum(0.0) != 0 }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(n_digits) } }
    else
      comp_loads_data = []
    end
    if include_timeseries_unmet_hours
      unmet_hours_data = @unmet_hours.values.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(n_digits) } }
    else
      unmet_hours_data = []
    end
    if include_timeseries_zone_temperatures
      zone_temps_data = @zone_temps.values.select { |x| x.timeseries_output.sum(0.0) != 0 }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(n_digits) } }
    else
      zone_temps_data = []
    end
    if include_timeseries_airflows
      airflows_data = @airflows.values.select { |x| x.timeseries_output.sum(0.0) != 0 }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(n_digits) } }
    else
      airflows_data = []
    end
    if include_timeseries_weather
      weather_data = @weather.values.select { |x| x.timeseries_output.sum(0.0) != 0 }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(n_digits) } }
    else
      weather_data = []
    end

    # EnergyPlus output variables
    if not @output_variables.empty?
      output_variables_data = @output_variables.values.map { |x| [x.name, x.timeseries_units] + x.timeseries_output }
    else
      output_variables_data = []
    end

    return if (total_energy_data.size + fuel_data.size + end_use_data.size + emissions_data.size + emission_fuel_data.size +
               emission_end_use_data.size + hot_water_use_data.size + total_loads_data.size + comp_loads_data.size + unmet_hours_data.size +
               zone_temps_data.size + airflows_data.size + weather_data.size + output_variables_data.size) == 0

    fail 'Unable to obtain timestamps.' if @timestamps.empty?

    if ['csv'].include? output_format
      # Assemble data
      data = data.zip(*timestamps2, *timestamps3, *total_energy_data, *fuel_data, *end_use_data, *emissions_data,
                      *emission_fuel_data, *emission_end_use_data, *hot_water_use_data, *total_loads_data, *comp_loads_data,
                      *unmet_hours_data, *zone_temps_data, *airflows_data, *weather_data, *output_variables_data)

      # Error-check
      n_elements = []
      data.each do |data_array|
        n_elements << data_array.size
      end
      if n_elements.uniq.size > 1
        fail "Inconsistent number of array elements: #{n_elements.uniq}."
      end

      if use_dview_format
        # Remove Time column(s)
        while data[0][0].include? 'Time'
          data = data.map { |a| a[1..-1] }
        end

        # Add header per DataFileTemplate.pdf; see https://github.com/NREL/wex/wiki/DView
        year = @hpxml.header.sim_calendar_year
        start_day = Schedule.get_day_num_from_month_day(year, @hpxml.header.sim_begin_month, @hpxml.header.sim_begin_day)
        start_hr = (start_day - 1) * 24
        if timeseries_frequency == 'timestep'
          interval_hrs = @hpxml.header.timestep / 60.0
        elsif timeseries_frequency == 'hourly'
          interval_hrs = 1.0
        elsif timeseries_frequency == 'daily'
          interval_hrs = 24.0
        elsif timeseries_frequency == 'monthly'
          interval_hrs = Constants.NumDaysInYear(year) * 24.0 / 12
        end
        header_data = [['wxDVFileHeaderVer.1'],
                       data[0].map { |d| d.sub(':', '|') }, # Series name (series can be organized into groups by entering Group Name|Series Name)
                       data[0].map { |_d| start_hr + interval_hrs / 2.0 }, # Start time of the first data point; 0.5 implies average over the first hour
                       data[0].map { |_d| interval_hrs }, # Time interval in hours
                       data[1]] # Units
        data.delete_at(1) # Remove units, added to header data above
        data.delete_at(0) # Remove series name, added to header data above

        # Apply daylight savings
        if timeseries_frequency == 'timestep' || timeseries_frequency == 'hourly'
          if @hpxml.header.dst_enabled
            dst_start_ix, dst_end_ix = get_dst_start_end_indexes(@timestamps, timestamps_dst)
            dst_end_ix.downto(dst_start_ix + 1) do |i|
              data[i + 1] = data[i]
            end
          end
        end

        data.insert(0, *header_data) # Add header data to beginning
      end

      # Write file
      CSV.open(timeseries_output_path, 'wb') { |csv| data.to_a.each { |elem| csv << elem } }
    elsif ['json', 'msgpack'].include? output_format
      # Assemble data
      h = {}
      h['Time'] = data[2..-1]
      h['TimeDST'] = timestamps2[2..-1] if timestamps_dst
      h['TimeUTC'] = timestamps3[2..-1] if timestamps_utc

      [total_energy_data, fuel_data, end_use_data, emissions_data, emission_fuel_data,
       emission_end_use_data, hot_water_use_data, total_loads_data, comp_loads_data, unmet_hours_data,
       zone_temps_data, airflows_data, weather_data, output_variables_data].each do |d|
        d.each do |o|
          grp, name = o[0].split(':', 2)
          h[grp] = {} if h[grp].nil?
          h[grp]["#{name.strip} (#{o[1]})"] = o[2..-1]
        end
      end

      # Write file
      if output_format == 'json'
        require 'json'
        File.open(timeseries_output_path, 'w') { |json| json.write(JSON.pretty_generate(h)) }
      elsif output_format == 'msgpack'
        File.open(timeseries_output_path, 'w') { |json| h.to_msgpack(json) }
      end
    end
    runner.registerInfo("Wrote timeseries output results to #{timeseries_output_path}.")
  end

  def get_dst_start_end_indexes(timestamps, timestamps_dst)
    dst_start_ix = nil
    dst_end_ix = nil
    timestamps.zip(timestamps_dst).each_with_index do |ts, i|
      dst_start_ix = i if ts[0] != ts[1] && dst_start_ix.nil?
      dst_end_ix = i if ts[0] == ts[1] && dst_end_ix.nil? && !dst_start_ix.nil?
    end

    dst_end_ix = timestamps.size - 1 if dst_end_ix.nil? # run period ends before DST ends

    return dst_start_ix, dst_end_ix
  end

  def get_report_meter_data_annual(meter_names, unit_conv = UnitConversions.convert(1.0, 'J', 'MBtu'))
    return 0.0 if meter_names.empty?

    cols = @msgpackData['MeterData']['RunPeriod']['Cols']
    timestamp = @msgpackData['MeterData']['RunPeriod']['Rows'][0].keys[0]
    row = @msgpackData['MeterData']['RunPeriod']['Rows'][0][timestamp]
    indexes = cols.each_index.select { |i| meter_names.include? cols[i]['Variable'] }
    val = row.each_index.select { |i| indexes.include? i }.map { |i| row[i] }.sum(0.0) * unit_conv

    return val
  end

  def get_report_variable_data_annual(key_values, variables, unit_conv = UnitConversions.convert(1.0, 'J', 'MBtu'), is_negative: false)
    return 0.0 if variables.empty?

    neg = is_negative ? -1.0 : 1.0
    keys_vars = key_values.zip(variables).map { |k, v| "#{k}:#{v}" }
    cols = @msgpackDataRunPeriod['Cols']
    timestamp = @msgpackDataRunPeriod['Rows'][0].keys[0]
    row = @msgpackDataRunPeriod['Rows'][0][timestamp]
    indexes = cols.each_index.select { |i| keys_vars.include? cols[i]['Variable'] }
    val = row.each_index.select { |i| indexes.include? i }.map { |i| row[i] }.sum(0.0) * unit_conv * neg

    return val
  end

  def get_report_meter_data_timeseries(meter_names, unit_conv, unit_adder, timeseries_frequency)
    return [0.0] * @timestamps.size if meter_names.empty?

    msgpack_timeseries_name = { 'timestep' => 'TimeStep',
                                'hourly' => 'Hourly',
                                'daily' => 'Daily',
                                'monthly' => 'Monthly' }[timeseries_frequency]
    cols = @msgpackData['MeterData'][msgpack_timeseries_name]['Cols']
    rows = @msgpackData['MeterData'][msgpack_timeseries_name]['Rows']
    indexes = cols.each_index.select { |i| meter_names.include? cols[i]['Variable'] }
    vals = []
    rows.each_with_index do |row, _idx|
      row = row[row.keys[0]]
      val = 0.0
      indexes.each do |i|
        val += row[i] * unit_conv + unit_adder
      end
      vals << val
    end
    return vals
  end

  def get_report_variable_data_timeseries(key_values, variables, unit_conv, unit_adder, timeseries_frequency, is_negative: false, ems_shift: false)
    return [0.0] * @timestamps.size if variables.empty?

    if key_values.uniq.size > 1 && key_values.include?('EMS') && ems_shift
      # Split into EMS and non-EMS queries so that the EMS values shift occurs for just the EMS query
      # Remove this code if we ever figure out a better way to handle when EMS output should shift
      values = get_report_variable_data_timeseries(['EMS'], variables, unit_conv, unit_adder, timeseries_frequency, is_negative: is_negative, ems_shift: ems_shift)
      sum_values = values.zip(get_report_variable_data_timeseries(key_values.select { |k| k != 'EMS' }, variables, unit_conv, unit_adder, timeseries_frequency, is_negative: is_negative, ems_shift: ems_shift)).map { |x, y| x + y }
      return sum_values
    end

    if (timeseries_frequency == 'hourly') && (not @msgpackDataHourly.nil?)
      msgpack_data = @msgpackDataHourly
    else
      msgpack_data = @msgpackDataTimeseries
    end
    neg = is_negative ? -1.0 : 1.0
    keys_vars = key_values.zip(variables).map { |k, v| "#{k}:#{v}" }
    cols = msgpack_data['Cols']
    rows = msgpack_data['Rows']
    indexes = cols.each_index.select { |i| keys_vars.include? cols[i]['Variable'] }
    vals = []
    rows.each_with_index do |row, _idx|
      row = row[row.keys[0]]
      val = 0.0
      indexes.each do |i|
        val += (row[i] * unit_conv + unit_adder) * neg
      end
      vals << val
    end

    return vals unless ems_shift

    # Remove this code if we ever figure out a better way to handle when EMS output should shift
    if (key_values.size == 1) && (key_values[0] == 'EMS') && (@timestamps.size > 0)
      if (timeseries_frequency == 'timestep' || (timeseries_frequency == 'hourly' && @model.getTimestep.numberOfTimestepsPerHour == 1))
        # Shift all values by 1 timestep due to EMS reporting lag
        return vals[1..-1] + [vals[0]]
      end
    end

    return vals
  end

  def get_report_variable_data_timeseries_key_values_and_units(var)
    keys = []
    units = ''
    if not @msgpackDataTimeseries.nil?
      @msgpackDataTimeseries['Cols'].each do |col|
        next unless col['Variable'].end_with? ":#{var}"

        keys << col['Variable'].split(':')[0..-2].join(':')
        units = col['Units']
      end
    end

    return keys, units
  end

  def get_tabular_data_value(report_name, report_for_string, table_name, row_names, col_name, units)
    vals = []
    @msgpackData['TabularReports'].each do |tabular_report|
      next if tabular_report['ReportName'] != report_name
      next if tabular_report['For'] != report_for_string

      tabular_report['Tables'].each do |table|
        next if table['TableName'] != table_name

        cols = table['Cols']
        index = cols.each_index.select { |i| cols[i] == "#{col_name} [#{units}]" }[0]
        row_names.each do |row_name|
          vals << table['Rows'][row_name][index].to_f
        end
      end
    end

    return vals.sum(0.0)
  end

  def apply_multiplier_to_output(obj, sync_obj, sys_id, mult)
    # Annual
    orig_value = obj.annual_output_by_system[sys_id]
    obj.annual_output_by_system[sys_id] = orig_value * mult
    if not sync_obj.nil?
      sync_obj.annual_output += (orig_value * mult - orig_value)
    end

    # Timeseries
    if not obj.timeseries_output_by_system.empty?
      orig_values = obj.timeseries_output_by_system[sys_id]
      obj.timeseries_output_by_system[sys_id] = obj.timeseries_output_by_system[sys_id].map { |x| x * mult }
      diffs = obj.timeseries_output_by_system[sys_id].zip(orig_values).map { |x, y| x - y }
      if not sync_obj.nil?
        sync_obj.timeseries_output = sync_obj.timeseries_output.zip(diffs).map { |x, y| x + y }
      end
    end

    # Hourly Electricity (for Cambium)
    if obj.is_a?(EndUse) && (not obj.hourly_output_by_system.empty?)
      obj.hourly_output_by_system[sys_id] = obj.hourly_output_by_system[sys_id].map { |x| x * mult }
    end
  end

  def create_all_object_variables_by_key
    @object_variables_by_key = {}
    return if @model.nil?

    @model.getModelObjects.each do |object|
      next if object.to_AdditionalProperties.is_initialized

      [EUT, HWT, LT, ILT].each do |class_name|
        vars_by_key = get_object_output_variables_by_key(@model, object, class_name)
        next if vars_by_key.size == 0

        sys_id = object.additionalProperties.getFeatureAsString('HPXML_ID')
        if sys_id.is_initialized
          sys_id = sys_id.get
        else
          sys_id = nil
        end

        vars_by_key.each do |key, output_vars|
          output_vars.each do |output_var|
            if object.to_EnergyManagementSystemOutputVariable.is_initialized
              varkey = 'EMS'
            else
              varkey = object.name.to_s.upcase
            end
            hash_key = [class_name, key]
            @object_variables_by_key[hash_key] = [] if @object_variables_by_key[hash_key].nil?
            next if @object_variables_by_key[hash_key].include? [sys_id, varkey, output_var]

            @object_variables_by_key[hash_key] << [sys_id, varkey, output_var]
          end
        end
      end
    end
  end

  def get_object_variables(class_name, key)
    hash_key = [class_name, key]
    vars = @object_variables_by_key[hash_key]
    vars = [] if vars.nil?
    return vars
  end

  class BaseOutput
    def initialize()
      @timeseries_output = []
    end
    attr_accessor(:name, :annual_output, :timeseries_output, :annual_units, :timeseries_units)
  end

  class TotalEnergy < BaseOutput
    def initialize
      super()
    end
    attr_accessor()
  end

  class Fuel < BaseOutput
    def initialize(meters: [])
      super()
      @meters = meters
      @timeseries_output_by_system = {}
    end
    attr_accessor(:meters, :timeseries_output_by_system)
  end

  class EndUse < BaseOutput
    def initialize(variables: [], is_negative: false, is_storage: false)
      super()
      @variables = variables
      @is_negative = is_negative
      @is_storage = is_storage
      @timeseries_output_by_system = {}
      @annual_output_by_system = {}
      # These outputs used to apply Cambium hourly electricity factors
      @hourly_output = []
      @hourly_output_by_system = {}
    end
    attr_accessor(:variables, :is_negative, :is_storage, :annual_output_by_system, :timeseries_output_by_system,
                  :hourly_output, :hourly_output_by_system)
  end

  class Emission < BaseOutput
    def initialize()
      super()
      @timeseries_output_by_end_use = {}
      @timeseries_output_by_fuel = {}
      @annual_output_by_fuel = {}
      @annual_output_by_end_use = {}
    end
    attr_accessor(:annual_output_by_fuel, :annual_output_by_end_use, :timeseries_output_by_fuel, :timeseries_output_by_end_use)
  end

  class HotWater < BaseOutput
    def initialize(variables: [])
      super()
      @variables = variables
      @timeseries_output_by_system = {}
      @annual_output_by_system = {}
    end
    attr_accessor(:variables, :annual_output_by_system, :timeseries_output_by_system)
  end

  class PeakFuel < BaseOutput
    def initialize(meters:, report:)
      super()
      @meters = meters
      @report = report
    end
    attr_accessor(:meters, :report)
  end

  class Load < BaseOutput
    def initialize(variables: [], ems_variable: nil, is_negative: false)
      super()
      @variables = variables
      @ems_variable = ems_variable
      @is_negative = is_negative
      @timeseries_output_by_system = {}
      @annual_output_by_system = {}
    end
    attr_accessor(:variables, :ems_variable, :is_negative, :annual_output_by_system, :timeseries_output_by_system)
  end

  class ComponentLoad < BaseOutput
    def initialize(ems_variable:)
      super()
      @ems_variable = ems_variable
    end
    attr_accessor(:ems_variable)
  end

  class UnmetHours < BaseOutput
    def initialize(ems_variable:)
      super()
      @ems_variable = ems_variable
    end
    attr_accessor(:ems_variable)
  end

  class IdealLoad < BaseOutput
    def initialize(variables: [])
      super()
      @variables = variables
    end
    attr_accessor(:variables)
  end

  class PeakLoad < BaseOutput
    def initialize(ems_variable:, report:)
      super()
      @ems_variable = ems_variable
      @report = report
    end
    attr_accessor(:ems_variable, :report)
  end

  class ZoneTemp < BaseOutput
    def initialize
      super()
    end
    attr_accessor()
  end

  class Airflow < BaseOutput
    def initialize(ems_program:, ems_variables:)
      super()
      @ems_program = ems_program
      @ems_variables = ems_variables
    end
    attr_accessor(:ems_program, :ems_variables)
  end

  class Weather < BaseOutput
    def initialize(variable:, variable_units:, timeseries_units:)
      super()
      @variable = variable
      @variable_units = variable_units
      @timeseries_units = timeseries_units
    end
    attr_accessor(:variable, :variable_units)
  end

  class OutputVariable < BaseOutput
    def initialize
      super()
    end
    attr_accessor()
  end

  def setup_outputs(called_from_outputs_method, user_output_variables = nil)
    def get_timeseries_units_from_fuel_type(fuel_type)
      if fuel_type == FT::Elec
        return 'kWh'
      end

      return 'kBtu'
    end

    # End Uses

    # NOTE: Some end uses are obtained from meters, others are rolled up from
    # output variables so that we can have more control.

    create_all_object_variables_by_key()

    @end_uses = {}
    @end_uses[[FT::Elec, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Heating]))
    @end_uses[[FT::Elec, EUT::HeatingHeatPumpBackup]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HeatingHeatPumpBackup]))
    @end_uses[[FT::Elec, EUT::HeatingFanPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HeatingFanPump]))
    @end_uses[[FT::Elec, EUT::Cooling]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Cooling]))
    @end_uses[[FT::Elec, EUT::CoolingFanPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::CoolingFanPump]))
    @end_uses[[FT::Elec, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HotWater]))
    @end_uses[[FT::Elec, EUT::HotWaterRecircPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HotWaterRecircPump]))
    @end_uses[[FT::Elec, EUT::HotWaterSolarThermalPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HotWaterSolarThermalPump]))
    @end_uses[[FT::Elec, EUT::LightsInterior]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::LightsInterior]))
    @end_uses[[FT::Elec, EUT::LightsGarage]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::LightsGarage]))
    @end_uses[[FT::Elec, EUT::LightsExterior]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::LightsExterior]))
    @end_uses[[FT::Elec, EUT::MechVent]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::MechVent]))
    @end_uses[[FT::Elec, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::MechVentPreheat]))
    @end_uses[[FT::Elec, EUT::MechVentPrecool]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::MechVentPrecool]))
    @end_uses[[FT::Elec, EUT::WholeHouseFan]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::WholeHouseFan]))
    @end_uses[[FT::Elec, EUT::Refrigerator]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Refrigerator]))
    @end_uses[[FT::Elec, EUT::Freezer]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Freezer]))
    @end_uses[[FT::Elec, EUT::Dehumidifier]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Dehumidifier]))
    @end_uses[[FT::Elec, EUT::Dishwasher]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Dishwasher]))
    @end_uses[[FT::Elec, EUT::ClothesWasher]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::ClothesWasher]))
    @end_uses[[FT::Elec, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::ClothesDryer]))
    @end_uses[[FT::Elec, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::RangeOven]))
    @end_uses[[FT::Elec, EUT::CeilingFan]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::CeilingFan]))
    @end_uses[[FT::Elec, EUT::Television]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Television]))
    @end_uses[[FT::Elec, EUT::PlugLoads]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::PlugLoads]))
    @end_uses[[FT::Elec, EUT::Vehicle]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Vehicle]))
    @end_uses[[FT::Elec, EUT::WellPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::WellPump]))
    @end_uses[[FT::Elec, EUT::PoolHeater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::PoolHeater]))
    @end_uses[[FT::Elec, EUT::PoolPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::PoolPump]))
    @end_uses[[FT::Elec, EUT::HotTubHeater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HotTubHeater]))
    @end_uses[[FT::Elec, EUT::HotTubPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HotTubPump]))
    @end_uses[[FT::Elec, EUT::PV]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::PV]),
                                                is_negative: true)
    @end_uses[[FT::Elec, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Generator]),
                                                       is_negative: true)
    @end_uses[[FT::Elec, EUT::Battery]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Battery]),
                                                     is_storage: true)
    @end_uses[[FT::Gas, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::Heating]))
    @end_uses[[FT::Gas, EUT::HeatingHeatPumpBackup]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::HeatingHeatPumpBackup]))
    @end_uses[[FT::Gas, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::HotWater]))
    @end_uses[[FT::Gas, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::ClothesDryer]))
    @end_uses[[FT::Gas, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::RangeOven]))
    @end_uses[[FT::Gas, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::MechVentPreheat]))
    @end_uses[[FT::Gas, EUT::PoolHeater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::PoolHeater]))
    @end_uses[[FT::Gas, EUT::HotTubHeater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::HotTubHeater]))
    @end_uses[[FT::Gas, EUT::Grill]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::Grill]))
    @end_uses[[FT::Gas, EUT::Lighting]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::Lighting]))
    @end_uses[[FT::Gas, EUT::Fireplace]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::Fireplace]))
    @end_uses[[FT::Gas, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::Generator]))
    @end_uses[[FT::Oil, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::Heating]))
    @end_uses[[FT::Oil, EUT::HeatingHeatPumpBackup]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::HeatingHeatPumpBackup]))
    @end_uses[[FT::Oil, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::HotWater]))
    @end_uses[[FT::Oil, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::ClothesDryer]))
    @end_uses[[FT::Oil, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::RangeOven]))
    @end_uses[[FT::Oil, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::MechVentPreheat]))
    @end_uses[[FT::Oil, EUT::Grill]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::Grill]))
    @end_uses[[FT::Oil, EUT::Lighting]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::Lighting]))
    @end_uses[[FT::Oil, EUT::Fireplace]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::Fireplace]))
    @end_uses[[FT::Oil, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::Generator]))
    @end_uses[[FT::Propane, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::Heating]))
    @end_uses[[FT::Propane, EUT::HeatingHeatPumpBackup]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::HeatingHeatPumpBackup]))
    @end_uses[[FT::Propane, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::HotWater]))
    @end_uses[[FT::Propane, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::ClothesDryer]))
    @end_uses[[FT::Propane, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::RangeOven]))
    @end_uses[[FT::Propane, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::MechVentPreheat]))
    @end_uses[[FT::Propane, EUT::Grill]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::Grill]))
    @end_uses[[FT::Propane, EUT::Lighting]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::Lighting]))
    @end_uses[[FT::Propane, EUT::Fireplace]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::Fireplace]))
    @end_uses[[FT::Propane, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::Generator]))
    @end_uses[[FT::WoodCord, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::Heating]))
    @end_uses[[FT::WoodCord, EUT::HeatingHeatPumpBackup]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::HeatingHeatPumpBackup]))
    @end_uses[[FT::WoodCord, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::HotWater]))
    @end_uses[[FT::WoodCord, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::ClothesDryer]))
    @end_uses[[FT::WoodCord, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::RangeOven]))
    @end_uses[[FT::WoodCord, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::MechVentPreheat]))
    @end_uses[[FT::WoodCord, EUT::Grill]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::Grill]))
    @end_uses[[FT::WoodCord, EUT::Lighting]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::Lighting]))
    @end_uses[[FT::WoodCord, EUT::Fireplace]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::Fireplace]))
    @end_uses[[FT::WoodCord, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::Generator]))
    @end_uses[[FT::WoodPellets, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::Heating]))
    @end_uses[[FT::WoodPellets, EUT::HeatingHeatPumpBackup]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::HeatingHeatPumpBackup]))
    @end_uses[[FT::WoodPellets, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::HotWater]))
    @end_uses[[FT::WoodPellets, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::ClothesDryer]))
    @end_uses[[FT::WoodPellets, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::RangeOven]))
    @end_uses[[FT::WoodPellets, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::MechVentPreheat]))
    @end_uses[[FT::WoodPellets, EUT::Grill]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::Grill]))
    @end_uses[[FT::WoodPellets, EUT::Lighting]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::Lighting]))
    @end_uses[[FT::WoodPellets, EUT::Fireplace]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::Fireplace]))
    @end_uses[[FT::WoodPellets, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::Generator]))
    @end_uses[[FT::Coal, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::Heating]))
    @end_uses[[FT::Coal, EUT::HeatingHeatPumpBackup]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::HeatingHeatPumpBackup]))
    @end_uses[[FT::Coal, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::HotWater]))
    @end_uses[[FT::Coal, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::ClothesDryer]))
    @end_uses[[FT::Coal, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::RangeOven]))
    @end_uses[[FT::Coal, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::MechVentPreheat]))
    @end_uses[[FT::Coal, EUT::Grill]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::Grill]))
    @end_uses[[FT::Coal, EUT::Lighting]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::Lighting]))
    @end_uses[[FT::Coal, EUT::Fireplace]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::Fireplace]))
    @end_uses[[FT::Coal, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::Generator]))
    if not called_from_outputs_method
      # Temporary end use to disaggregate 8760 GSHP shared loop pump energy into heating vs cooling.
      # This end use will not appear in output data/files.
      @end_uses[[FT::Elec, 'TempGSHPSharedPump']] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, 'TempGSHPSharedPump']))
    end
    @end_uses.each do |key, end_use|
      fuel_type, end_use_type = key
      end_use.name = "End Use: #{fuel_type}: #{end_use_type}"
      end_use.annual_units = 'MBtu'
      end_use.timeseries_units = get_timeseries_units_from_fuel_type(fuel_type)
    end

    # Fuels

    @fuels = {}
    @fuels[FT::Elec] = Fuel.new(meters: ["#{EPlus::FuelTypeElectricity}:Facility"])
    @fuels[FT::Gas] = Fuel.new(meters: ["#{EPlus::FuelTypeNaturalGas}:Facility"])
    @fuels[FT::Oil] = Fuel.new(meters: ["#{EPlus::FuelTypeOil}:Facility"])
    @fuels[FT::Propane] = Fuel.new(meters: ["#{EPlus::FuelTypePropane}:Facility"])
    @fuels[FT::WoodCord] = Fuel.new(meters: ["#{EPlus::FuelTypeWoodCord}:Facility"])
    @fuels[FT::WoodPellets] = Fuel.new(meters: ["#{EPlus::FuelTypeWoodPellets}:Facility"])
    @fuels[FT::Coal] = Fuel.new(meters: ["#{EPlus::FuelTypeCoal}:Facility"])

    @fuels.each do |fuel_type, fuel|
      fuel.name = "Fuel Use: #{fuel_type}: Total"
      fuel.annual_units = 'MBtu'
      fuel.timeseries_units = get_timeseries_units_from_fuel_type(fuel_type)
      if @end_uses.select { |key, end_use| key[0] == fuel_type && end_use.variables.size > 0 }.size == 0
        fuel.meters = []
      end
    end

    # Total Energy
    @totals = {}
    [TE::Total, TE::Net].each do |energy_type|
      @totals[energy_type] = TotalEnergy.new
      @totals[energy_type].name = "Energy Use: #{energy_type}"
      @totals[energy_type].annual_units = 'MBtu'
      @totals[energy_type].timeseries_units = get_timeseries_units_from_fuel_type(FT::Gas)
    end

    # Emissions
    @emissions = {}
    if not @model.nil?
      emissions_scenario_names = eval(@model.getBuilding.additionalProperties.getFeatureAsString('emissions_scenario_names').get)
      emissions_scenario_types = eval(@model.getBuilding.additionalProperties.getFeatureAsString('emissions_scenario_types').get)
      emissions_scenario_names.each_with_index do |scenario_name, i|
        scenario_type = emissions_scenario_types[i]
        @emissions[[scenario_type, scenario_name]] = Emission.new()
        @emissions[[scenario_type, scenario_name]].name = "Emissions: #{scenario_type}: #{scenario_name}"
        @emissions[[scenario_type, scenario_name]].annual_units = 'lb'
        @emissions[[scenario_type, scenario_name]].timeseries_units = 'lb'
      end
    end

    # Hot Water Uses
    @hot_water_uses = {}
    @hot_water_uses[HWT::ClothesWasher] = HotWater.new(variables: get_object_variables(HWT, HWT::ClothesWasher))
    @hot_water_uses[HWT::Dishwasher] = HotWater.new(variables: get_object_variables(HWT, HWT::Dishwasher))
    @hot_water_uses[HWT::Fixtures] = HotWater.new(variables: get_object_variables(HWT, HWT::Fixtures))
    @hot_water_uses[HWT::DistributionWaste] = HotWater.new(variables: get_object_variables(HWT, HWT::DistributionWaste))

    @hot_water_uses.each do |hot_water_type, hot_water|
      hot_water.name = "Hot Water: #{hot_water_type}"
      hot_water.annual_units = 'gal'
      hot_water.timeseries_units = 'gal'
    end

    # Peak Fuels
    # Using meters for energy transferred in conditioned space only (i.e., excluding ducts) to determine winter vs summer.
    @peak_fuels = {}
    @peak_fuels[[FT::Elec, PFT::Winter]] = PeakFuel.new(meters: ["Heating:EnergyTransfer:Zone:#{HPXML::LocationLivingSpace.upcase}"], report: 'Peak Electricity Winter Total')
    @peak_fuels[[FT::Elec, PFT::Summer]] = PeakFuel.new(meters: ["Cooling:EnergyTransfer:Zone:#{HPXML::LocationLivingSpace.upcase}"], report: 'Peak Electricity Summer Total')

    @peak_fuels.each do |key, peak_fuel|
      fuel_type, peak_fuel_type = key
      peak_fuel.name = "Peak #{fuel_type}: #{peak_fuel_type} Total"
      peak_fuel.annual_units = 'W'
    end

    # Loads

    @loads = {}
    @loads[LT::Heating] = Load.new(ems_variable: 'loads_htg_tot')
    @loads[LT::Cooling] = Load.new(ems_variable: 'loads_clg_tot')
    @loads[LT::HotWaterDelivered] = Load.new(variables: get_object_variables(LT, LT::HotWaterDelivered))
    @loads[LT::HotWaterTankLosses] = Load.new(variables: get_object_variables(LT, LT::HotWaterTankLosses),
                                              is_negative: true)
    @loads[LT::HotWaterDesuperheater] = Load.new(variables: get_object_variables(LT, LT::HotWaterDesuperheater))
    @loads[LT::HotWaterSolarThermal] = Load.new(variables: get_object_variables(LT, LT::HotWaterSolarThermal),
                                                is_negative: true)

    @loads.each do |load_type, load|
      load.name = "Load: #{load_type}"
      load.annual_units = 'MBtu'
      load.timeseries_units = 'kBtu'
    end

    # Component Loads

    @component_loads = {}
    @component_loads[[LT::Heating, CLT::Roofs]] = ComponentLoad.new(ems_variable: 'loads_htg_roofs')
    @component_loads[[LT::Heating, CLT::Ceilings]] = ComponentLoad.new(ems_variable: 'loads_htg_ceilings')
    @component_loads[[LT::Heating, CLT::Walls]] = ComponentLoad.new(ems_variable: 'loads_htg_walls')
    @component_loads[[LT::Heating, CLT::RimJoists]] = ComponentLoad.new(ems_variable: 'loads_htg_rim_joists')
    @component_loads[[LT::Heating, CLT::FoundationWalls]] = ComponentLoad.new(ems_variable: 'loads_htg_foundation_walls')
    @component_loads[[LT::Heating, CLT::Doors]] = ComponentLoad.new(ems_variable: 'loads_htg_doors')
    @component_loads[[LT::Heating, CLT::Windows]] = ComponentLoad.new(ems_variable: 'loads_htg_windows')
    @component_loads[[LT::Heating, CLT::Skylights]] = ComponentLoad.new(ems_variable: 'loads_htg_skylights')
    @component_loads[[LT::Heating, CLT::Floors]] = ComponentLoad.new(ems_variable: 'loads_htg_floors')
    @component_loads[[LT::Heating, CLT::Slabs]] = ComponentLoad.new(ems_variable: 'loads_htg_slabs')
    @component_loads[[LT::Heating, CLT::InternalMass]] = ComponentLoad.new(ems_variable: 'loads_htg_internal_mass')
    @component_loads[[LT::Heating, CLT::Infiltration]] = ComponentLoad.new(ems_variable: 'loads_htg_infil')
    @component_loads[[LT::Heating, CLT::NaturalVentilation]] = ComponentLoad.new(ems_variable: 'loads_htg_natvent')
    @component_loads[[LT::Heating, CLT::MechanicalVentilation]] = ComponentLoad.new(ems_variable: 'loads_htg_mechvent')
    @component_loads[[LT::Heating, CLT::WholeHouseFan]] = ComponentLoad.new(ems_variable: 'loads_htg_whf')
    @component_loads[[LT::Heating, CLT::Ducts]] = ComponentLoad.new(ems_variable: 'loads_htg_ducts')
    @component_loads[[LT::Heating, CLT::InternalGains]] = ComponentLoad.new(ems_variable: 'loads_htg_intgains')
    @component_loads[[LT::Cooling, CLT::Roofs]] = ComponentLoad.new(ems_variable: 'loads_clg_roofs')
    @component_loads[[LT::Cooling, CLT::Ceilings]] = ComponentLoad.new(ems_variable: 'loads_clg_ceilings')
    @component_loads[[LT::Cooling, CLT::Walls]] = ComponentLoad.new(ems_variable: 'loads_clg_walls')
    @component_loads[[LT::Cooling, CLT::RimJoists]] = ComponentLoad.new(ems_variable: 'loads_clg_rim_joists')
    @component_loads[[LT::Cooling, CLT::FoundationWalls]] = ComponentLoad.new(ems_variable: 'loads_clg_foundation_walls')
    @component_loads[[LT::Cooling, CLT::Doors]] = ComponentLoad.new(ems_variable: 'loads_clg_doors')
    @component_loads[[LT::Cooling, CLT::Windows]] = ComponentLoad.new(ems_variable: 'loads_clg_windows')
    @component_loads[[LT::Cooling, CLT::Skylights]] = ComponentLoad.new(ems_variable: 'loads_clg_skylights')
    @component_loads[[LT::Cooling, CLT::Floors]] = ComponentLoad.new(ems_variable: 'loads_clg_floors')
    @component_loads[[LT::Cooling, CLT::Slabs]] = ComponentLoad.new(ems_variable: 'loads_clg_slabs')
    @component_loads[[LT::Cooling, CLT::InternalMass]] = ComponentLoad.new(ems_variable: 'loads_clg_internal_mass')
    @component_loads[[LT::Cooling, CLT::Infiltration]] = ComponentLoad.new(ems_variable: 'loads_clg_infil')
    @component_loads[[LT::Cooling, CLT::NaturalVentilation]] = ComponentLoad.new(ems_variable: 'loads_clg_natvent')
    @component_loads[[LT::Cooling, CLT::MechanicalVentilation]] = ComponentLoad.new(ems_variable: 'loads_clg_mechvent')
    @component_loads[[LT::Cooling, CLT::WholeHouseFan]] = ComponentLoad.new(ems_variable: 'loads_clg_whf')
    @component_loads[[LT::Cooling, CLT::Ducts]] = ComponentLoad.new(ems_variable: 'loads_clg_ducts')
    @component_loads[[LT::Cooling, CLT::InternalGains]] = ComponentLoad.new(ems_variable: 'loads_clg_intgains')

    @component_loads.each do |key, comp_load|
      load_type, comp_load_type = key
      comp_load.name = "Component Load: #{load_type.gsub(': Delivered', '')}: #{comp_load_type}"
      comp_load.annual_units = 'MBtu'
      comp_load.timeseries_units = 'kBtu'
    end

    # Unmet Hours
    @unmet_hours = {}
    @unmet_hours[UHT::Heating] = UnmetHours.new(ems_variable: 'htg_unmet_hours')
    @unmet_hours[UHT::Cooling] = UnmetHours.new(ems_variable: 'clg_unmet_hours')

    @unmet_hours.each do |load_type, unmet_hour|
      unmet_hour.name = "Unmet Hours: #{load_type}"
      unmet_hour.annual_units = 'hr'
      unmet_hour.timeseries_units = 'hr'
    end

    # Ideal System Loads (expected load that is not met by the HVAC systems)
    @ideal_system_loads = {}
    @ideal_system_loads[ILT::Heating] = IdealLoad.new(variables: get_object_variables(ILT, ILT::Heating))
    @ideal_system_loads[ILT::Cooling] = IdealLoad.new(variables: get_object_variables(ILT, ILT::Cooling))

    @ideal_system_loads.each do |load_type, ideal_load|
      ideal_load.name = "Ideal System Load: #{load_type}"
      ideal_load.annual_units = 'MBtu'
    end

    # Peak Loads
    @peak_loads = {}
    @peak_loads[PLT::Heating] = PeakLoad.new(ems_variable: 'loads_htg_tot', report: 'Peak Heating Load')
    @peak_loads[PLT::Cooling] = PeakLoad.new(ems_variable: 'loads_clg_tot', report: 'Peak Cooling Load')

    @peak_loads.each do |load_type, peak_load|
      peak_load.name = "Peak Load: #{load_type}"
      peak_load.annual_units = 'kBtu/hr'
    end

    # Zone Temperatures
    @zone_temps = {}

    # Airflows
    @airflows = {}
    @airflows[AFT::Infiltration] = Airflow.new(ems_program: Constants.ObjectNameInfiltration + ' program', ems_variables: [(Constants.ObjectNameInfiltration + ' flow act').gsub(' ', '_')])
    @airflows[AFT::MechanicalVentilation] = Airflow.new(ems_program: Constants.ObjectNameInfiltration + ' program', ems_variables: ['Qfan'])
    @airflows[AFT::NaturalVentilation] = Airflow.new(ems_program: Constants.ObjectNameNaturalVentilation + ' program', ems_variables: [(Constants.ObjectNameNaturalVentilation + ' flow act').gsub(' ', '_')])
    @airflows[AFT::WholeHouseFan] = Airflow.new(ems_program: Constants.ObjectNameNaturalVentilation + ' program', ems_variables: [(Constants.ObjectNameWholeHouseFan + ' flow act').gsub(' ', '_')])

    @airflows.each do |airflow_type, airflow|
      airflow.name = "Airflow: #{airflow_type}"
      airflow.timeseries_units = 'cfm'
    end

    # Weather
    @weather = {}
    @weather[WT::DrybulbTemp] = Weather.new(variable: 'Site Outdoor Air Drybulb Temperature', variable_units: 'C', timeseries_units: 'F')
    @weather[WT::WetbulbTemp] = Weather.new(variable: 'Site Outdoor Air Wetbulb Temperature', variable_units: 'C', timeseries_units: 'F')
    @weather[WT::RelativeHumidity] = Weather.new(variable: 'Site Outdoor Air Relative Humidity', variable_units: '%', timeseries_units: '%')
    @weather[WT::WindSpeed] = Weather.new(variable: 'Site Wind Speed', variable_units: 'm/s', timeseries_units: 'mph')
    @weather[WT::DiffuseSolar] = Weather.new(variable: 'Site Diffuse Solar Radiation Rate per Area', variable_units: 'W/m^2', timeseries_units: 'Btu/(hr*ft^2)')
    @weather[WT::DirectSolar] = Weather.new(variable: 'Site Direct Solar Radiation Rate per Area', variable_units: 'W/m^2', timeseries_units: 'Btu/(hr*ft^2)')

    @weather.each do |weather_type, weather_data|
      weather_data.name = "Weather: #{weather_type}"
    end

    # Output Variables
    @output_variables_requests = {}
    if not user_output_variables.nil?
      output_variables = user_output_variables.split(',').map(&:strip)
      output_variables.each do |output_variable|
        @output_variables_requests[output_variable] = OutputVariable.new
      end
    end
  end

  def is_heat_pump_backup(sys_id)
    return false if @hpxml.nil?

    # Integrated backup?
    @hpxml.heat_pumps.each do |heat_pump|
      next if sys_id != heat_pump.id

      return true
    end

    # Separate backup system?
    @hpxml.heating_systems.each do |heating_system|
      next if sys_id != heating_system.id
      next unless heating_system.is_heat_pump_backup_system

      return true
    end

    if sys_id.include? '_DFHPBackup'
      return true
    end

    return false
  end

  def get_object_output_variables_by_key(model, object, class_name)
    to_ft = { EPlus::FuelTypeElectricity => FT::Elec,
              EPlus::FuelTypeNaturalGas => FT::Gas,
              EPlus::FuelTypeOil => FT::Oil,
              EPlus::FuelTypePropane => FT::Propane,
              EPlus::FuelTypeWoodCord => FT::WoodCord,
              EPlus::FuelTypeWoodPellets => FT::WoodPellets,
              EPlus::FuelTypeCoal => FT::Coal }

    # For a given object, returns the output variables to be requested and associates
    # them with the appropriate keys (e.g., [FT::Elec, EUT::Heating]).

    sys_id = object.additionalProperties.getFeatureAsString('HPXML_ID')
    if sys_id.is_initialized
      sys_id = sys_id.get
    else
      sys_id = nil
    end

    if class_name == EUT

      # End uses

      if object.to_CoilHeatingDXSingleSpeed.is_initialized || object.to_CoilHeatingDXMultiSpeed.is_initialized
        return { [FT::Elec, EUT::Heating] => ["Heating Coil #{EPlus::FuelTypeElectricity} Energy", "Heating Coil Crankcase Heater #{EPlus::FuelTypeElectricity} Energy", "Heating Coil Defrost #{EPlus::FuelTypeElectricity} Energy"] }

      elsif object.to_CoilHeatingElectric.is_initialized
        if not is_heat_pump_backup(sys_id)
          return { [FT::Elec, EUT::Heating] => ["Heating Coil #{EPlus::FuelTypeElectricity} Energy"] }
        else
          return { [FT::Elec, EUT::HeatingHeatPumpBackup] => ["Heating Coil #{EPlus::FuelTypeElectricity} Energy"] }
        end

      elsif object.to_CoilHeatingGas.is_initialized
        fuel = object.to_CoilHeatingGas.get.fuelType
        if not is_heat_pump_backup(sys_id)
          return { [to_ft[fuel], EUT::Heating] => ["Heating Coil #{fuel} Energy"] }
        else
          return { [to_ft[fuel], EUT::HeatingHeatPumpBackup] => ["Heating Coil #{fuel} Energy"] }
        end

      elsif object.to_CoilHeatingWaterToAirHeatPumpEquationFit.is_initialized
        return { [FT::Elec, EUT::Heating] => ["Heating Coil #{EPlus::FuelTypeElectricity} Energy"] }

      elsif object.to_ZoneHVACBaseboardConvectiveElectric.is_initialized
        if not is_heat_pump_backup(sys_id)
          return { [FT::Elec, EUT::Heating] => ["Baseboard #{EPlus::FuelTypeElectricity} Energy"] }
        else
          return { [FT::Elec, EUT::HeatingHeatPumpBackup] => ["Baseboard #{EPlus::FuelTypeElectricity} Energy"] }
        end

      elsif object.to_BoilerHotWater.is_initialized
        is_combi_boiler = false
        if object.additionalProperties.getFeatureAsBoolean('IsCombiBoiler').is_initialized
          is_combi_boiler = object.additionalProperties.getFeatureAsBoolean('IsCombiBoiler').get
        end
        if not is_combi_boiler # Exclude combi boiler, whose heating & dhw energy is handled separately via EMS
          fuel = object.to_BoilerHotWater.get.fuelType
          if not is_heat_pump_backup(sys_id)
            return { [to_ft[fuel], EUT::Heating] => ["Boiler #{fuel} Energy"] }
          else
            return { [to_ft[fuel], EUT::HeatingHeatPumpBackup] => ["Boiler #{fuel} Energy"] }
          end
        else
          fuel = object.to_BoilerHotWater.get.fuelType
          return { [to_ft[fuel], EUT::HotWater] => ["Boiler #{fuel} Energy"] }
        end

      elsif object.to_CoilCoolingDXSingleSpeed.is_initialized || object.to_CoilCoolingDXMultiSpeed.is_initialized
        vars = { [FT::Elec, EUT::Cooling] => ["Cooling Coil #{EPlus::FuelTypeElectricity} Energy"] }
        parent = model.getAirLoopHVACUnitarySystems.select { |u| u.coolingCoil.is_initialized && u.coolingCoil.get.handle.to_s == object.handle.to_s }
        if (not parent.empty?) && parent[0].heatingCoil.is_initialized
          htg_coil = parent[0].heatingCoil.get
        end
        if parent.empty?
          parent = model.getZoneHVACPackagedTerminalAirConditioners.select { |u| u.coolingCoil.handle.to_s == object.handle.to_s }
          if not parent.empty?
            htg_coil = parent[0].heatingCoil
          end
        end
        if parent.empty?
          fail 'Could not find parent object.'
        end

        if htg_coil.nil? || (not (htg_coil.to_CoilHeatingDXSingleSpeed.is_initialized || htg_coil.to_CoilHeatingDXMultiSpeed.is_initialized))
          # Crankcase variable only available if no DX heating coil on parent
          vars[[FT::Elec, EUT::Cooling]] << "Cooling Coil Crankcase Heater #{EPlus::FuelTypeElectricity} Energy"
        end
        return vars

      elsif object.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
        return { [FT::Elec, EUT::Cooling] => ["Cooling Coil #{EPlus::FuelTypeElectricity} Energy"] }

      elsif object.to_EvaporativeCoolerDirectResearchSpecial.is_initialized
        return { [FT::Elec, EUT::Cooling] => ["Evaporative Cooler #{EPlus::FuelTypeElectricity} Energy"] }

      elsif object.to_CoilWaterHeatingAirToWaterHeatPumpWrapped.is_initialized
        return { [FT::Elec, EUT::HotWater] => ["Cooling Coil Water Heating #{EPlus::FuelTypeElectricity} Energy"] }

      elsif object.to_FanSystemModel.is_initialized
        if object.name.to_s.start_with? Constants.ObjectNameWaterHeater
          return { [FT::Elec, EUT::HotWater] => ["Fan #{EPlus::FuelTypeElectricity} Energy"] }
        end

      elsif object.to_PumpConstantSpeed.is_initialized
        if object.name.to_s.start_with? Constants.ObjectNameSolarHotWater
          return { [FT::Elec, EUT::HotWaterSolarThermalPump] => ["Pump #{EPlus::FuelTypeElectricity} Energy"] }
        end

      elsif object.to_WaterHeaterMixed.is_initialized
        fuel = object.to_WaterHeaterMixed.get.heaterFuelType
        return { [to_ft[fuel], EUT::HotWater] => ["Water Heater #{fuel} Energy", "Water Heater Off Cycle Parasitic #{EPlus::FuelTypeElectricity} Energy", "Water Heater On Cycle Parasitic #{EPlus::FuelTypeElectricity} Energy"] }

      elsif object.to_WaterHeaterStratified.is_initialized
        fuel = object.to_WaterHeaterStratified.get.heaterFuelType
        return { [to_ft[fuel], EUT::HotWater] => ["Water Heater #{fuel} Energy", "Water Heater Off Cycle Parasitic #{EPlus::FuelTypeElectricity} Energy", "Water Heater On Cycle Parasitic #{EPlus::FuelTypeElectricity} Energy"] }

      elsif object.to_ExteriorLights.is_initialized
        return { [FT::Elec, EUT::LightsExterior] => ["Exterior Lights #{EPlus::FuelTypeElectricity} Energy"] }

      elsif object.to_Lights.is_initialized
        end_use = { Constants.ObjectNameInteriorLighting => EUT::LightsInterior,
                    Constants.ObjectNameGarageLighting => EUT::LightsGarage }[object.to_Lights.get.endUseSubcategory]
        return { [FT::Elec, end_use] => ["Lights #{EPlus::FuelTypeElectricity} Energy"] }

      elsif object.to_ElectricLoadCenterInverterPVWatts.is_initialized
        return { [FT::Elec, EUT::PV] => ['Inverter Conversion Loss Decrement Energy'] }

      elsif object.to_GeneratorPVWatts.is_initialized
        return { [FT::Elec, EUT::PV] => ["Generator Produced DC #{EPlus::FuelTypeElectricity} Energy"] }

      elsif object.to_GeneratorMicroTurbine.is_initialized
        fuel = object.to_GeneratorMicroTurbine.get.fuelType
        return { [FT::Elec, EUT::Generator] => ["Generator Produced AC #{EPlus::FuelTypeElectricity} Energy"],
                 [to_ft[fuel], EUT::Generator] => ["Generator #{fuel} HHV Basis Energy"] }

      elsif object.to_ElectricLoadCenterStorageLiIonNMCBattery.is_initialized
        # return { [FT::Elec, EUT::Battery] => ['Electric Storage Production Decrement Energy', 'Electric Storage Discharge Energy', 'Electric Storage Thermal Loss Energy'] }
        return { [FT::Elec, EUT::Battery] => ['Electric Storage Production Decrement Energy', 'Electric Storage Discharge Energy'] }

      elsif object.to_ElectricEquipment.is_initialized
        end_use = { Constants.ObjectNameHotWaterRecircPump => EUT::HotWaterRecircPump,
                    Constants.ObjectNameGSHPSharedPump => 'TempGSHPSharedPump',
                    Constants.ObjectNameClothesWasher => EUT::ClothesWasher,
                    Constants.ObjectNameClothesDryer => EUT::ClothesDryer,
                    Constants.ObjectNameDishwasher => EUT::Dishwasher,
                    Constants.ObjectNameRefrigerator => EUT::Refrigerator,
                    Constants.ObjectNameFreezer => EUT::Freezer,
                    Constants.ObjectNameCookingRange => EUT::RangeOven,
                    Constants.ObjectNameCeilingFan => EUT::CeilingFan,
                    Constants.ObjectNameWholeHouseFan => EUT::WholeHouseFan,
                    Constants.ObjectNameMechanicalVentilation => EUT::MechVent,
                    Constants.ObjectNameMiscPlugLoads => EUT::PlugLoads,
                    Constants.ObjectNameMiscTelevision => EUT::Television,
                    Constants.ObjectNameMiscPoolHeater => EUT::PoolHeater,
                    Constants.ObjectNameMiscPoolPump => EUT::PoolPump,
                    Constants.ObjectNameMiscHotTubHeater => EUT::HotTubHeater,
                    Constants.ObjectNameMiscHotTubPump => EUT::HotTubPump,
                    Constants.ObjectNameMiscElectricVehicleCharging => EUT::Vehicle,
                    Constants.ObjectNameMiscWellPump => EUT::WellPump }[object.to_ElectricEquipment.get.endUseSubcategory]
        if not end_use.nil?
          return { [FT::Elec, end_use] => ["Electric Equipment #{EPlus::FuelTypeElectricity} Energy"] }
        end

      elsif object.to_OtherEquipment.is_initialized
        fuel = object.to_OtherEquipment.get.fuelType
        end_use = { Constants.ObjectNameClothesDryer => EUT::ClothesDryer,
                    Constants.ObjectNameCookingRange => EUT::RangeOven,
                    Constants.ObjectNameMiscGrill => EUT::Grill,
                    Constants.ObjectNameMiscLighting => EUT::Lighting,
                    Constants.ObjectNameMiscFireplace => EUT::Fireplace,
                    Constants.ObjectNameMiscPoolHeater => EUT::PoolHeater,
                    Constants.ObjectNameMiscHotTubHeater => EUT::HotTubHeater,
                    Constants.ObjectNameMechanicalVentilationPreheating => EUT::MechVentPreheat,
                    Constants.ObjectNameMechanicalVentilationPrecooling => EUT::MechVentPrecool }[object.to_OtherEquipment.get.endUseSubcategory]
        if not end_use.nil?
          return { [to_ft[fuel], end_use] => ["Other Equipment #{fuel} Energy"] }
        end

      elsif object.to_ZoneHVACDehumidifierDX.is_initialized
        return { [FT::Elec, EUT::Dehumidifier] => ["Zone Dehumidifier #{EPlus::FuelTypeElectricity} Energy"] }

      elsif object.to_EnergyManagementSystemOutputVariable.is_initialized
        if object.name.to_s.end_with? Constants.ObjectNameFanPumpDisaggregatePrimaryHeat
          return { [FT::Elec, EUT::HeatingFanPump] => [object.name.to_s] }
        elsif object.name.to_s.end_with? Constants.ObjectNameFanPumpDisaggregateBackupHeat
          return { [FT::Elec, EUT::HeatingFanPump] => [object.name.to_s] }
        elsif object.name.to_s.end_with? Constants.ObjectNameFanPumpDisaggregateCool
          return { [FT::Elec, EUT::CoolingFanPump] => [object.name.to_s] }
        elsif object.name.to_s.include? Constants.ObjectNameWaterHeaterAdjustment(nil)
          fuel = object.additionalProperties.getFeatureAsString('FuelType').get
          return { [to_ft[fuel], EUT::HotWater] => [object.name.to_s] }
        elsif object.name.to_s.include? Constants.ObjectNameBatteryLossesAdjustment(nil)
          return { [FT::Elec, EUT::Battery] => [object.name.to_s] }
        else
          return { ems: [object.name.to_s] }
        end

      end

    elsif class_name == HWT

      # Hot Water Use

      if object.to_WaterUseEquipment.is_initialized
        hot_water_use = { Constants.ObjectNameFixtures => HWT::Fixtures,
                          Constants.ObjectNameDistributionWaste => HWT::DistributionWaste,
                          Constants.ObjectNameClothesWasher => HWT::ClothesWasher,
                          Constants.ObjectNameDishwasher => HWT::Dishwasher }[object.to_WaterUseEquipment.get.waterUseEquipmentDefinition.endUseSubcategory]
        return { hot_water_use => ['Water Use Equipment Hot Water Volume'] }

      end

    elsif class_name == LT

      # Load

      if object.to_WaterHeaterMixed.is_initialized || object.to_WaterHeaterStratified.is_initialized
        if object.to_WaterHeaterMixed.is_initialized
          capacity = object.to_WaterHeaterMixed.get.heaterMaximumCapacity.get
        else
          capacity = object.to_WaterHeaterStratified.get.heater1Capacity.get
        end
        is_combi_boiler = false
        if object.additionalProperties.getFeatureAsBoolean('IsCombiBoiler').is_initialized
          is_combi_boiler = object.additionalProperties.getFeatureAsBoolean('IsCombiBoiler').get
        end
        if capacity == 0 && object.name.to_s.include?(Constants.ObjectNameSolarHotWater)
          return { LT::HotWaterSolarThermal => ['Water Heater Use Side Heat Transfer Energy'] }
        elsif capacity > 0 || is_combi_boiler # Active water heater only (e.g., exclude desuperheater and solar thermal storage tanks)
          return { LT::HotWaterTankLosses => ['Water Heater Heat Loss Energy'] }
        end

      elsif object.to_WaterUseConnections.is_initialized
        return { LT::HotWaterDelivered => ['Water Use Connections Plant Hot Water Energy'] }

      elsif object.to_CoilWaterHeatingDesuperheater.is_initialized
        return { LT::HotWaterDesuperheater => ['Water Heater Heating Energy'] }

      elsif object.to_CoilHeatingDXSingleSpeed.is_initialized || object.to_CoilHeatingDXMultiSpeed.is_initialized || object.to_CoilHeatingGas.is_initialized
        # Needed to apportion heating loads for dual-fuel heat pumps
        return { LT::Heating => ['Heating Coil Heating Energy'] }

      end

    elsif class_name == ILT

      # Ideal Load

      if object.to_ZoneHVACIdealLoadsAirSystem.is_initialized
        if object.name.to_s == Constants.ObjectNameIdealAirSystem
          return { ILT::Heating => ['Zone Ideal Loads Zone Sensible Heating Energy'],
                   ILT::Cooling => ['Zone Ideal Loads Zone Sensible Cooling Energy'] }
        end

      end

    end

    return {}
  end
end

# register the measure to be used by the application
ReportSimulationOutput.new.registerWithApplication
