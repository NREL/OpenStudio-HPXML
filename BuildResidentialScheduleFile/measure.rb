# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'openstudio'

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
    return ''
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hpxml_path', true)
    arg.setDisplayName('HPXML File Path')
    arg.setDescription('Absolute/relative path of the HPXML file.')
    args << arg

    schedules_type_choices = OpenStudio::StringVector.new
    schedules_type_choices << 'default'
    schedules_type_choices << 'stochastic'

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('schedules_type', schedules_type_choices, true)
    arg.setDisplayName('Schedules: Type')
    arg.setDescription("The type of occupant-related schedules to use. Schedules corresponding to 'default' are average (e.g., Building America). Schedules corresponding to 'stochastic' are generated using time-inhomogeneous Markov chains derived from American Time Use Survey data, and supplemented with sampling duration and power level from NEEA RBSA data as well as DHW draw duration and flow rate from Aquacraft/AWWA data.")
    arg.setDefaultValue('default')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('schedules_vacancy_period', false)
    arg.setDisplayName('Schedules: Vacancy Period')
    arg.setDescription("Specifies the vacancy period. Only applies if the schedules type is 'stochastic'. Enter a date like \"Dec 15 - Jan 15\".")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('schedules_random_seed', false)
    arg.setDisplayName('Schedules: Random Seed')
    arg.setUnits('#')
    arg.setDescription("This numeric field is the seed for the random number generator. Only applies if the schedules type is 'stochastic'.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('output_csv_path', true)
    arg.setDisplayName('Schedules: Path')
    arg.setDescription('Absolute (or relative) path of the csv file containing user-specified occupancy schedules.')
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

    # Create EpwFile object
    epw_path = args[:weather_station_epw_filepath]
    if not File.exist? epw_path
      epw_path = File.join(File.expand_path(File.join(File.dirname(__FILE__), '..', 'weather')), epw_path) # a filename was entered for weather_station_epw_filepath
    end
    if not File.exist? epw_path
      runner.registerError("Could not find EPW file at '#{epw_path}'.")
      return false
    end
    epw_file = OpenStudio::EpwFile.new(epw_path)

    success = create_schedules(runner, model, epw_file, args)
    return false if not success

    return true
  end

  def create_schedules(runner, model, epw_file, args)
    info_msgs = []

    # set the calendar year
    year_description = model.getYearDescription
    year_description.setCalendarYear(2007) # default to TMY
    if args[:simulation_control_run_period_calendar_year].is_initialized
      year_description.setCalendarYear(args[:simulation_control_run_period_calendar_year].get)
    end
    if epw_file.startDateActualYear.is_initialized # AMY
      year_description.setCalendarYear(epw_file.startDateActualYear.get)
    end
    info_msgs << "CalendarYear=#{year_description.calendarYear}"

    # set the timestep
    timestep = model.getTimestep
    timestep.setNumberOfTimestepsPerHour(1)
    if args[:simulation_control_timestep].is_initialized
      timestep.setNumberOfTimestepsPerHour(60 / args[:simulation_control_timestep].get)
    end
    info_msgs << "NumberOfTimestepsPerHour=#{timestep.numberOfTimestepsPerHour}"

    # get the seed
    random_seed = args[:schedules_random_seed].get if args[:schedules_random_seed].is_initialized

    # instantiate the generator
    schedule_generator = ScheduleGenerator.new(runner: runner, model: model, epw_file: epw_file, random_seed: random_seed)

    # create the schedule
    if args[:geometry_num_occupants] == Constants.Auto
      args[:geometry_num_occupants] = Geometry.get_occupancy_default_num(args[:geometry_num_bedrooms])
    else
      args[:geometry_num_occupants] = Integer(args[:geometry_num_occupants])
    end
    args[:resources_path] = File.join(File.dirname(__FILE__), 'resources')
    if args[:schedules_vacancy_period].is_initialized
      begin_month, begin_day, end_month, end_day = parse_date_range(args[:schedules_vacancy_period].get)
      args[:schedules_vacancy_begin_month] = begin_month
      args[:schedules_vacancy_begin_day] = begin_day
      args[:schedules_vacancy_end_month] = end_month
      args[:schedules_vacancy_end_day] = end_day
    end
    success = schedule_generator.create(args: args)
    return false if not success

    # export the schedule
    success = schedule_generator.export(schedules_path: File.expand_path(args[:output_csv_path]))
    return false if not success

    runner.registerInfo("Created schedule with #{info_msgs.join(', ')}")

    return true
  end
end

# register the measure to be used by the application
BuildResidentialScheduleFile.new.registerWithApplication
