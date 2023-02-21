# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'openstudio'
require 'pathname'
require 'oga'
Dir["#{File.dirname(__FILE__)}/resources/*.rb"].each do |resource_file|
  require resource_file
end
Dir["#{File.dirname(__FILE__)}/../HPXMLtoOpenStudio/resources/*.rb"].each do |resource_file|
  next if resource_file.include? 'minitest_helper.rb'

  require resource_file
end

# start the measure
class BuildResidentialScheduleFile < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Schedule File Builder'
  end

  # human readable description
  def description
    return 'Builds a residential schedule file.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Generates a CSV of schedules at the specified file path, and inserts the CSV schedule file path into the output HPXML file (or overwrites it if one already exists). Stochastic schedules are generated using time-inhomogeneous Markov chains derived from American Time Use Survey data, and supplemented with sampling duration and power level from NEEA RBSA data as well as DHW draw duration and flow rate from Aquacraft/AWWA data.'
  end

  # define the arguments that the user will input
  def arguments(model) # rubocop:disable Lint/UnusedMethodArgument
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hpxml_path', true)
    arg.setDisplayName('HPXML File Path')
    arg.setDescription('Absolute/relative path of the HPXML file.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('schedules_column_names', false)
    arg.setDisplayName('Schedules: Column Names')
    arg.setDescription("A comma-separated list of the column names to generate. If not provided, defaults to all columns. Possible column names are: #{ScheduleGenerator.export_columns.join(', ')}.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('schedules_random_seed', false)
    arg.setDisplayName('Schedules: Random Seed')
    arg.setUnits('#')
    arg.setDescription("This numeric field is the seed for the random number generator. Only applies if the schedules type is 'stochastic'.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('schedules_peak_period', false)
    arg.setDisplayName('Schedules: Peak Period')
    arg.setDescription('Specifies the peak period. Enter a time like "15 - 18" (start hour can be 0 through 23 and end hour can be 1 through 24).')
    arg.setDefaultValue('15 - 18')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('schedules_peak_period_delay', false)
    arg.setDisplayName('Schedules: Peak Period Delay')
    arg.setUnits('hr')
    arg.setDescription('The number of hours after peak period end.')
    arg.setDefaultValue(0)
    args << arg

    schedules_affected = Schedule.get_schedules_affected
    ScheduleGenerator.export_columns.each do |col_name|
      next if !Schedule.affected_by_peak_shift(col_name, schedules_affected)

      arg = OpenStudio::Measure::OSArgument::makeBoolArgument("schedules_peak_period_#{col_name}", false)
      arg.setDisplayName("Schedules: Peak Period #{col_name}")
      arg.setDescription("Whether to shift the #{col_name} schedule during the peak period.")
      arg.setDefaultValue(false)
      args << arg
    end

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('output_csv_path', true)
    arg.setDisplayName('Schedules: Output CSV Path')
    arg.setDescription('Absolute/relative path of the CSV file containing occupancy schedules. Relative paths are relative to the HPXML output path.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hpxml_output_path', true)
    arg.setDisplayName('HPXML Output File Path')
    arg.setDescription('Absolute/relative output path of the HPXML file. This HPXML file will include the output CSV path.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('debug', false)
    arg.setDisplayName('Debug Mode?')
    arg.setDescription('Applicable when schedules type is stochastic. If true: Write extra state column(s).')
    arg.setDefaultValue(false)
    args << arg

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    args = get_argument_values(runner, arguments(model), user_arguments)
    args = Hash[args.collect { |k, v| [k.to_sym, v] }]

    hpxml_path = args[:hpxml_path]
    unless (Pathname.new hpxml_path).absolute?
      hpxml_path = File.expand_path(hpxml_path)
    end
    unless File.exist?(hpxml_path) && hpxml_path.downcase.end_with?('.xml')
      fail "'#{hpxml_path}' does not exist or is not an .xml file."
    end

    hpxml_output_path = args[:hpxml_output_path]
    unless (Pathname.new hpxml_output_path).absolute?
      hpxml_output_path = File.expand_path(hpxml_output_path)
    end
    args[:hpxml_output_path] = hpxml_output_path

    hpxml = HPXML.new(hpxml_path: hpxml_path)

    # exit if number of occupants is zero
    if hpxml.building_occupancy.number_of_residents == 0
      runner.registerInfo('Number of occupants set to zero; skipping generation of stochastic schedules.')
      return true
    end

    # check peak shifts against fuel types
    if args[:schedules_peak_period].is_initialized
      if args[:schedules_peak_period_clothes_dryer].is_initialized && args[:schedules_peak_period_clothes_dryer].get
        if not hpxml.clothes_dryers.empty?
          clothes_dryer = hpxml.clothes_dryers[0]
          runner.registerInfo("Applying peak period shift to '#{SchedulesFile::ColumnClothesDryer}' schedule with '#{clothes_dryer.fuel_type}' fuel type.") if clothes_dryer.fuel_type != HPXML::FuelTypeElectricity
        end
      end
      if args[:schedules_peak_period_cooking_range].is_initialized && args[:schedules_peak_period_cooking_range].get
        if not hpxml.cooking_ranges.empty?
          cooking_range = hpxml.cooking_ranges[0]
          runner.registerInfo("Applying peak period shift to '#{SchedulesFile::ColumnCookingRange}' schedule with '#{clothes_dryer.fuel_type}' fuel type.") if cooking_range.fuel_type != HPXML::FuelTypeElectricity
        end
      end
    end

    # create EpwFile object
    epw_path = Location.get_epw_path(hpxml, hpxml_path)
    epw_file = OpenStudio::EpwFile.new(epw_path)

    # create the schedules
    success = create_schedules(runner, hpxml, epw_file, args)
    return false if not success

    # modify the hpxml with the schedules path
    doc = XMLHelper.parse_file(hpxml_path)
    extension = XMLHelper.create_elements_as_needed(XMLHelper.get_element(doc, '/HPXML'), ['SoftwareInfo', 'extension'])
    schedules_filepaths = XMLHelper.get_values(extension, 'SchedulesFilePath', :string)
    if !schedules_filepaths.include?(args[:output_csv_path])
      XMLHelper.add_element(extension, 'SchedulesFilePath', args[:output_csv_path], :string)
    end

    # write out the modified hpxml
    if (hpxml_path != hpxml_output_path) || !schedules_filepaths.include?(args[:output_csv_path])
      XMLHelper.write_file(doc, hpxml_output_path)
      runner.registerInfo("Wrote file: #{hpxml_output_path}")
    end

    return true
  end

  def create_schedules(runner, hpxml, epw_file, args)
    info_msgs = []

    get_simulation_parameters(hpxml, epw_file, args)
    get_generator_inputs(hpxml, epw_file, args)

    args[:resources_path] = File.join(File.dirname(__FILE__), 'resources')
    schedule_generator = ScheduleGenerator.new(runner: runner, epw_file: epw_file, **args)

    success = schedule_generator.create(args: args)
    return false if not success

    output_csv_path = args[:output_csv_path]
    unless (Pathname.new output_csv_path).absolute?
      output_csv_path = File.expand_path(File.join(File.dirname(args[:hpxml_output_path]), output_csv_path))
    end

    success = schedule_generator.export(schedules_path: output_csv_path)
    return false if not success

    info_msgs << "SimYear=#{args[:sim_year]}"
    info_msgs << "MinutesPerStep=#{args[:minutes_per_step]}"
    info_msgs << "State=#{args[:state]}"
    info_msgs << "RandomSeed=#{args[:random_seed]}" if args[:schedules_random_seed].is_initialized
    info_msgs << "GeometryNumOccupants=#{args[:geometry_num_occupants]}"
    info_msgs << "ColumnNames=#{args[:column_names]}" if args[:schedules_column_names].is_initialized
    if args[:schedules_peak_period].is_initialized
      if (args[:schedules_peak_period_dishwasher].is_initialized && args[:schedules_peak_period_dishwasher].get) ||
         (args[:schedules_peak_period_clothes_dryer].is_initialized && args[:schedules_peak_period_clothes_dryer].get)
        info_msgs << "PeakPeriod=#{args[:peak_period]}"
      end
    end

    runner.registerInfo("Created stochastic schedule with #{info_msgs.join(', ')}")

    return true
  end

  def get_simulation_parameters(hpxml, epw_file, args)
    args[:minutes_per_step] = 60
    if !hpxml.header.timestep.nil?
      args[:minutes_per_step] = hpxml.header.timestep
    end
    args[:steps_in_day] = 24 * 60 / args[:minutes_per_step]
    args[:mkc_ts_per_day] = 96
    args[:mkc_ts_per_hour] = args[:mkc_ts_per_day] / 24

    calendar_year = Location.get_sim_calendar_year(hpxml.header.sim_calendar_year, epw_file)
    args[:sim_year] = calendar_year
    args[:sim_start_day] = DateTime.new(args[:sim_year], 1, 1)
    args[:total_days_in_year] = Constants.NumDaysInYear(calendar_year)
  end

  def get_generator_inputs(hpxml, epw_file, args)
    args[:state] = 'CO'
    args[:state] = epw_file.stateProvinceRegion if Constants.StateCodesMap.keys.include?(epw_file.stateProvinceRegion)
    args[:state] = hpxml.header.state_code if !hpxml.header.state_code.nil?

    args[:random_seed] = args[:schedules_random_seed].get if args[:schedules_random_seed].is_initialized
    args[:column_names] = args[:schedules_column_names].get.split(',').map(&:strip) if args[:schedules_column_names].is_initialized

    if hpxml.building_occupancy.number_of_residents.nil?
      args[:geometry_num_occupants] = Geometry.get_occupancy_default_num(hpxml.building_construction.number_of_bedrooms)
    else
      args[:geometry_num_occupants] = hpxml.building_occupancy.number_of_residents
    end
    args[:geometry_num_occupants] = Float(Integer(args[:geometry_num_occupants]))

    args[:peak_period] = args[:schedules_peak_period].get if args[:schedules_peak_period].is_initialized
    args[:peak_period_delay] = args[:schedules_peak_period_delay].get if args[:schedules_peak_period_delay].is_initialized

    schedules_affected = Schedule.get_schedules_affected
    ScheduleGenerator.export_columns.each do |col_name|
      next if !Schedule.affected_by_peak_shift(col_name, schedules_affected)

      args["peak_period_#{col_name}".to_sym] = args["schedules_peak_period_#{col_name}".to_sym].get if args["schedules_peak_period_#{col_name}".to_sym].is_initialized
    end

    debug = false
    if args[:debug].is_initialized
      debug = args[:debug].get
    end
    args[:debug] = debug
  end
end

# register the measure to be used by the application
BuildResidentialScheduleFile.new.registerWithApplication
