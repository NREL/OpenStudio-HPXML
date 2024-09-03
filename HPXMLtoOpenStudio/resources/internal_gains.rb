# frozen_string_literal: true

# TODO
module InternalGains
  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param num_occ [Double] Number of occupants in the dwelling unit
  # @param space [OpenStudio::Model::Space] an OpenStudio::Model::Space object
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @param unavailable_periods [HPXML::UnavailablePeriods] Object that defines periods for, e.g., power outages or vacancies
  # @param apply_ashrae140_assumptions [Boolean] TODO
  # @return [nil]
  def self.apply(model, runner, hpxml_bldg, num_occ, space, schedules_file, unavailable_periods, apply_ashrae140_assumptions)
    apply_building_occupancy(model, runner, hpxml_bldg, num_occ, space, schedules_file, unavailable_periods)
    apply_general_water_use(model, runner, hpxml_bldg, space, schedules_file, unavailable_periods, apply_ashrae140_assumptions)
  end

  # Create an OpenStudio People object using number of occupants and people/activity schedules.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param num_occ [Double] Number of occupants in the dwelling unit
  # @param space [OpenStudio::Model::Space] an OpenStudio::Model::Space object
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @param unavailable_periods [HPXML::UnavailablePeriods] Object that defines periods for, e.g., power outages or vacancies
  # @return [nil]
  def self.apply_building_occupancy(model, runner, hpxml_bldg, num_occ, space, schedules_file, unavailable_periods)
    return if num_occ <= 0

    occ_gain, _hrs_per_day, sens_frac, _lat_frac = get_occupancy_default_values()
    activity_per_person = UnitConversions.convert(occ_gain, 'Btu/hr', 'W')

    # Hard-coded convective, radiative, latent, and lost fractions
    occ_sens = sens_frac
    occ_rad = 0.558 * occ_sens

    # Create schedule
    people_sch = nil
    people_col_name = SchedulesFile::Columns[:Occupants].name
    if not schedules_file.nil?
      people_sch = schedules_file.create_schedule_file(model, col_name: people_col_name)
    end
    if people_sch.nil?
      people_unavailable_periods = Schedule.get_unavailable_periods(runner, people_col_name, unavailable_periods)
      weekday_sch = hpxml_bldg.building_occupancy.weekday_fractions.split(',').map(&:to_f)
      weekday_sch = weekday_sch.map { |v| v / weekday_sch.max }.join(',')
      weekend_sch = hpxml_bldg.building_occupancy.weekend_fractions.split(',').map(&:to_f)
      weekend_sch = weekend_sch.map { |v| v / weekend_sch.max }.join(',')
      monthly_sch = hpxml_bldg.building_occupancy.monthly_multipliers
      people_sch = MonthWeekdayWeekendSchedule.new(model, Constants::ObjectTypeOccupants + ' schedule', weekday_sch, weekend_sch, monthly_sch, EPlus::ScheduleTypeLimitsFraction, unavailable_periods: people_unavailable_periods)
      people_sch = people_sch.schedule
    else
      runner.registerWarning("Both '#{people_col_name}' schedule file and weekday fractions provided; the latter will be ignored.") if !hpxml_bldg.building_occupancy.weekday_fractions.nil?
      runner.registerWarning("Both '#{people_col_name}' schedule file and weekend fractions provided; the latter will be ignored.") if !hpxml_bldg.building_occupancy.weekend_fractions.nil?
      runner.registerWarning("Both '#{people_col_name}' schedule file and monthly multipliers provided; the latter will be ignored.") if !hpxml_bldg.building_occupancy.monthly_multipliers.nil?
    end

    # Create schedule
    activity_sch = OpenStudio::Model::ScheduleConstant.new(model)
    activity_sch.setValue(activity_per_person)
    activity_sch.setName(Constants::ObjectTypeOccupants + ' activity schedule')

    # Add people definition for the occ
    occ_def = OpenStudio::Model::PeopleDefinition.new(model)
    occ = OpenStudio::Model::People.new(occ_def)
    occ.setName(Constants::ObjectTypeOccupants)
    occ.setSpace(space)
    occ_def.setName(Constants::ObjectTypeOccupants)
    occ_def.setNumberofPeople(num_occ)
    occ_def.setFractionRadiant(occ_rad)
    occ_def.setSensibleHeatFraction(occ_sens)
    occ_def.setMeanRadiantTemperatureCalculationType('ZoneAveraged')
    occ_def.setCarbonDioxideGenerationRate(0)
    occ_def.setEnableASHRAE55ComfortWarnings(false)
    occ.setActivityLevelSchedule(activity_sch)
    occ.setNumberofPeopleSchedule(people_sch)
  end

  # Table 4.2.2(3). Internal Gains for Reference Homes
  #
  # @return [Array<Double, Double, Double, Double>] TODO
  def self.get_occupancy_default_values()
    hrs_per_day = 16.5 # hrs/day
    sens_gains = 3716.0 # Btu/person/day
    lat_gains = 2884.0 # Btu/person/day
    tot_gains = sens_gains + lat_gains
    heat_gain = tot_gains / hrs_per_day # Btu/person/hr
    sens_frac = sens_gains / tot_gains
    lat_frac = lat_gains / tot_gains
    return heat_gain, hrs_per_day, sens_frac, lat_frac
  end

  # Set calendar year on the OpenStudio YearDescription object.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param apply_ashrae140_assumptions [Boolean] TODO
  # @return [nil]
  def self.apply_general_water_use(model, runner, hpxml_bldg, space, schedules_file, unavailable_periods, apply_ashrae140_assumptions)
    general_water_use_usage_multiplier = hpxml_bldg.building_occupancy.general_water_use_usage_multiplier
    nbeds_eq = hpxml_bldg.building_construction.additional_properties.equivalent_number_of_bedrooms

    if not apply_ashrae140_assumptions
      # General water use internal gains
      # Floor mopping, shower evaporation, water films on showers, tubs & sinks surfaces, plant watering, etc.
      water_sens_btu, water_lat_btu = get_water_gains_sens_lat(nbeds_eq, general_water_use_usage_multiplier)

      # Create schedule
      water_schedule = nil
      water_col_name = SchedulesFile::Columns[:GeneralWaterUse].name
      water_obj_name = Constants::ObjectTypeGeneralWaterUse
      if not schedules_file.nil?
        water_design_level_sens = schedules_file.calc_design_level_from_daily_kwh(col_name: SchedulesFile::Columns[:GeneralWaterUse].name, daily_kwh: UnitConversions.convert(water_sens_btu, 'Btu', 'kWh') / 365.0)
        water_design_level_lat = schedules_file.calc_design_level_from_daily_kwh(col_name: SchedulesFile::Columns[:GeneralWaterUse].name, daily_kwh: UnitConversions.convert(water_lat_btu, 'Btu', 'kWh') / 365.0)
        water_schedule = schedules_file.create_schedule_file(model, col_name: water_col_name, schedule_type_limits_name: EPlus::ScheduleTypeLimitsFraction)
      end
      if water_schedule.nil?
        water_unavailable_periods = Schedule.get_unavailable_periods(runner, water_col_name, unavailable_periods)
        water_weekday_sch = hpxml_bldg.building_occupancy.general_water_use_weekday_fractions
        water_weekend_sch = hpxml_bldg.building_occupancy.general_water_use_weekend_fractions
        water_monthly_sch = hpxml_bldg.building_occupancy.general_water_use_monthly_multipliers
        water_schedule_obj = MonthWeekdayWeekendSchedule.new(model, water_obj_name + ' schedule', water_weekday_sch, water_weekend_sch, water_monthly_sch, EPlus::ScheduleTypeLimitsFraction, unavailable_periods: water_unavailable_periods)
        water_design_level_sens = water_schedule_obj.calc_design_level_from_daily_kwh(UnitConversions.convert(water_sens_btu, 'Btu', 'kWh') / 365.0)
        water_design_level_lat = water_schedule_obj.calc_design_level_from_daily_kwh(UnitConversions.convert(water_lat_btu, 'Btu', 'kWh') / 365.0)
        water_schedule = water_schedule_obj.schedule
      else
        runner.registerWarning("Both '#{water_col_name}' schedule file and weekday fractions provided; the latter will be ignored.") if !hpxml_bldg.building_occupancy.general_water_use_weekday_fractions.nil?
        runner.registerWarning("Both '#{water_col_name}' schedule file and weekend fractions provided; the latter will be ignored.") if !hpxml_bldg.building_occupancy.general_water_use_weekend_fractions.nil?
        runner.registerWarning("Both '#{water_col_name}' schedule file and monthly multipliers provided; the latter will be ignored.") if !hpxml_bldg.building_occupancy.general_water_use_monthly_multipliers.nil?
      end
      HotWaterAndAppliances.add_other_equipment(model, Constants::ObjectTypeGeneralWaterUseSensible, space, water_design_level_sens, 1.0, 0.0, water_schedule, nil)
      HotWaterAndAppliances.add_other_equipment(model, Constants::ObjectTypeGeneralWaterUseLatent, space, water_design_level_lat, 0.0, 1.0, water_schedule, nil)
    end
  end

  # TODO
  #
  # @param nbeds_eq [Integer] Number of bedrooms (or equivalent bedrooms, as adjusted by the number of occupants) in the dwelling unit
  # @param general_water_use_usage_multiplier [TODO] TODO
  # @return [TODO] TODO
  def self.get_water_gains_sens_lat(nbeds_eq, general_water_use_usage_multiplier = 1.0)
    # Table 4.2.2(3). Internal Gains for Reference Homes
    sens_gains = (-1227.0 - 409.0 * nbeds_eq) * general_water_use_usage_multiplier # Btu/day
    lat_gains = (1245.0 + 415.0 * nbeds_eq) * general_water_use_usage_multiplier # Btu/day
    return sens_gains * 365.0, lat_gains * 365.0
  end
end
