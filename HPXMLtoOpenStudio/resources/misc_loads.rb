# frozen_string_literal: true

# Collection of methods related to miscellaneous plug/fuel loads.
module MiscLoads
  # Adds any HPXML Plug Loads to the OpenStudio model.
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param hpxml_header [HPXML::Header] HPXML Header object (one per HPXML file)
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @return [nil]
  def self.apply_plug_loads(runner, model, spaces, hpxml_bldg, hpxml_header, schedules_file)
    hpxml_bldg.plug_loads.each do |plug_load|
      if plug_load.plug_load_type == HPXML::PlugLoadTypeOther
        obj_name = Constants::ObjectTypeMiscPlugLoads
      elsif plug_load.plug_load_type == HPXML::PlugLoadTypeTelevision
        obj_name = Constants::ObjectTypeMiscTelevision
      elsif plug_load.plug_load_type == HPXML::PlugLoadTypeElectricVehicleCharging
        obj_name = Constants::ObjectTypeMiscElectricVehicleCharging
      elsif plug_load.plug_load_type == HPXML::PlugLoadTypeWellPump
        obj_name = Constants::ObjectTypeMiscWellPump
      end
      if obj_name.nil?
        runner.registerWarning("Unexpected plug load type '#{plug_load.plug_load_type}'. The plug load will not be modeled.")
        next
      end

      apply_plug_load(runner, model, plug_load, obj_name, spaces, schedules_file,
                      hpxml_header.unavailable_periods, hpxml_header.apply_ashrae140_assumptions)
    end
  end

  # Adds the HPXML Plug Load to the OpenStudio model.
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param plug_load [TODO] TODO
  # @param obj_name [String] Name for the OpenStudio object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @param unavailable_periods [HPXML::UnavailablePeriods] Object that defines periods for, e.g., power outages or vacancies
  # @param apply_ashrae140_assumptions [TODO] TODO
  # @return [nil]
  def self.apply_plug_load(runner, model, plug_load, obj_name, spaces, schedules_file, unavailable_periods, apply_ashrae140_assumptions)
    kwh = 0
    if not plug_load.nil?
      kwh = plug_load.kwh_per_year * plug_load.usage_multiplier
    end

    return if kwh <= 0

    # Create schedule
    sch = nil
    if plug_load.plug_load_type == HPXML::PlugLoadTypeOther
      col_name = SchedulesFile::Columns[:PlugLoadsOther].name
    elsif plug_load.plug_load_type == HPXML::PlugLoadTypeTelevision
      col_name = SchedulesFile::Columns[:PlugLoadsTV].name
    elsif plug_load.plug_load_type == HPXML::PlugLoadTypeElectricVehicleCharging
      col_name = SchedulesFile::Columns[:PlugLoadsVehicle].name
    elsif plug_load.plug_load_type == HPXML::PlugLoadTypeWellPump
      col_name = SchedulesFile::Columns[:PlugLoadsWellPump].name
    end
    if not schedules_file.nil?
      space_design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: kwh)
      sch = schedules_file.create_schedule_file(model, col_name: col_name)
    end
    if sch.nil?
      col_unavailable_periods = Schedule.get_unavailable_periods(runner, col_name, unavailable_periods)
      sch = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', plug_load.weekday_fractions, plug_load.weekend_fractions, plug_load.monthly_multipliers, EPlus::ScheduleTypeLimitsFraction, unavailable_periods: col_unavailable_periods)
      space_design_level = sch.calc_design_level_from_daily_kwh(kwh / 365.0)
      sch = sch.schedule
    else
      runner.registerWarning("Both '#{col_name}' schedule file and weekday fractions provided; the latter will be ignored.") if !plug_load.weekday_fractions.nil?
      runner.registerWarning("Both '#{col_name}' schedule file and weekend fractions provided; the latter will be ignored.") if !plug_load.weekend_fractions.nil?
      runner.registerWarning("Both '#{col_name}' schedule file and monthly multipliers provided; the latter will be ignored.") if !plug_load.monthly_multipliers.nil?
    end

    sens_frac = plug_load.frac_sensible
    lat_frac = plug_load.frac_latent

    if apply_ashrae140_assumptions
      # ASHRAE 140, Table 7-9. Sensible loads are 70% radiative and 30% convective.
      rad_frac = 0.7 * sens_frac
    else
      rad_frac = 0.6 * sens_frac
    end

    Model.add_electric_equipment(
      model,
      name: obj_name,
      end_use: obj_name,
      space: spaces[HPXML::LocationConditionedSpace],
      design_level: space_design_level,
      frac_radiant: rad_frac,
      frac_latent: lat_frac,
      frac_lost: 1 - sens_frac - lat_frac,
      schedule: sch
    )
  end

  # Adds any HPXML Fuel Loads to the OpenStudio model.
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param hpxml_header [HPXML::Header] HPXML Header object (one per HPXML file)
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @return [nil]
  def self.apply_fuel_loads(runner, model, spaces, hpxml_bldg, hpxml_header, schedules_file)
    hpxml_bldg.fuel_loads.each do |fuel_load|
      if fuel_load.fuel_load_type == HPXML::FuelLoadTypeGrill
        obj_name = Constants::ObjectTypeMiscGrill
      elsif fuel_load.fuel_load_type == HPXML::FuelLoadTypeLighting
        obj_name = Constants::ObjectTypeMiscLighting
      elsif fuel_load.fuel_load_type == HPXML::FuelLoadTypeFireplace
        obj_name = Constants::ObjectTypeMiscFireplace
      end
      if obj_name.nil?
        runner.registerWarning("Unexpected fuel load type '#{fuel_load.fuel_load_type}'. The fuel load will not be modeled.")
        next
      end

      apply_fuel_load(runner, model, fuel_load, obj_name, spaces, schedules_file,
                      hpxml_header.unavailable_periods)
    end
  end

  # Adds the HPXML Fuel Load to the OpenStudio model.
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param fuel_load [TODO] TODO
  # @param obj_name [String] Name for the OpenStudio object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @param unavailable_periods [HPXML::UnavailablePeriods] Object that defines periods for, e.g., power outages or vacancies
  # @return [nil]
  def self.apply_fuel_load(runner, model, fuel_load, obj_name, spaces, schedules_file, unavailable_periods)
    therm = 0
    if not fuel_load.nil?
      therm = fuel_load.therm_per_year * fuel_load.usage_multiplier
    end

    return if therm <= 0

    # Create schedule
    sch = nil
    if fuel_load.fuel_load_type == HPXML::FuelLoadTypeGrill
      col_name = SchedulesFile::Columns[:FuelLoadsGrill].name
    elsif fuel_load.fuel_load_type == HPXML::FuelLoadTypeLighting
      col_name = SchedulesFile::Columns[:FuelLoadsLighting].name
    elsif fuel_load.fuel_load_type == HPXML::FuelLoadTypeFireplace
      col_name = SchedulesFile::Columns[:FuelLoadsFireplace].name
    end
    if not schedules_file.nil?
      space_design_level = schedules_file.calc_design_level_from_annual_therm(col_name: col_name, annual_therm: therm)
      sch = schedules_file.create_schedule_file(model, col_name: col_name)
    end
    if sch.nil?
      col_unavailable_periods = Schedule.get_unavailable_periods(runner, col_name, unavailable_periods)
      sch = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', fuel_load.weekday_fractions, fuel_load.weekend_fractions, fuel_load.monthly_multipliers, EPlus::ScheduleTypeLimitsFraction, unavailable_periods: col_unavailable_periods)
      space_design_level = sch.calc_design_level_from_daily_therm(therm / 365.0)
      sch = sch.schedule
    else
      runner.registerWarning("Both '#{col_name}' schedule file and weekday fractions provided; the latter will be ignored.") if !fuel_load.weekday_fractions.nil?
      runner.registerWarning("Both '#{col_name}' schedule file and weekend fractions provided; the latter will be ignored.") if !fuel_load.weekend_fractions.nil?
      runner.registerWarning("Both '#{col_name}' schedule file and monthly multipliers provided; the latter will be ignored.") if !fuel_load.monthly_multipliers.nil?
    end

    sens_frac = fuel_load.frac_sensible
    lat_frac = fuel_load.frac_latent

    Model.add_other_equipment(
      model,
      name: obj_name,
      end_use: obj_name,
      space: spaces[HPXML::LocationConditionedSpace],
      design_level: space_design_level,
      frac_radiant: 0.6 * sens_frac,
      frac_latent: lat_frac,
      frac_lost: 1 - sens_frac - lat_frac,
      schedule: sch,
      fuel_type: fuel_load.fuel_type
    )
  end

  # Adds any HPXML Pools and Permanent Spas to the OpenStudio model.
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param hpxml_header [HPXML::Header] HPXML Header object (one per HPXML file)
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @return [nil]
  def self.apply_pools_and_permanent_spas(runner, model, spaces, hpxml_bldg, hpxml_header, schedules_file)
    (hpxml_bldg.pools + hpxml_bldg.permanent_spas).each do |pool_or_spa|
      next if pool_or_spa.type == HPXML::TypeNone

      apply_pool_or_permanent_spa_heater(runner, model, pool_or_spa, spaces,
                                         schedules_file, hpxml_header.unavailable_periods)
      next if pool_or_spa.pump_type == HPXML::TypeNone

      apply_pool_or_permanent_spa_pump(runner, model, pool_or_spa, spaces,
                                       schedules_file, hpxml_header.unavailable_periods)
    end
  end

  # Adds the HPXML Pool or Permanent Spa Heater to the OpenStudio model.
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param pool_or_spa [TODO] TODO
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @param unavailable_periods [HPXML::UnavailablePeriods] Object that defines periods for, e.g., power outages or vacancies
  # @return [nil]
  def self.apply_pool_or_permanent_spa_heater(runner, model, pool_or_spa, spaces, schedules_file, unavailable_periods)
    return if pool_or_spa.heater_type == HPXML::TypeNone

    heater_kwh = 0
    heater_therm = 0
    if pool_or_spa.heater_load_units == HPXML::UnitsKwhPerYear
      heater_kwh = pool_or_spa.heater_load_value * pool_or_spa.heater_usage_multiplier
    elsif pool_or_spa.heater_load_units == HPXML::UnitsThermPerYear
      heater_therm = pool_or_spa.heater_load_value * pool_or_spa.heater_usage_multiplier
    end

    return if (heater_kwh <= 0) && (heater_therm <= 0)

    # Create schedule
    heater_sch = nil
    if pool_or_spa.is_a? HPXML::Pool
      obj_name = Constants::ObjectTypeMiscPoolHeater
      col_name = 'pool_heater'
    else
      obj_name = Constants::ObjectTypeMiscPermanentSpaHeater
      col_name = 'permanent_spa_heater'
    end
    if not schedules_file.nil?
      heater_sch = schedules_file.create_schedule_file(model, col_name: col_name)
    end
    if heater_sch.nil?
      col_unavailable_periods = Schedule.get_unavailable_periods(runner, col_name, unavailable_periods)
      heater_sch = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', pool_or_spa.heater_weekday_fractions, pool_or_spa.heater_weekend_fractions, pool_or_spa.heater_monthly_multipliers, EPlus::ScheduleTypeLimitsFraction, unavailable_periods: col_unavailable_periods)
    else
      runner.registerWarning("Both '#{col_name}' schedule file and weekday fractions provided; the latter will be ignored.") if !pool_or_spa.heater_weekday_fractions.nil?
      runner.registerWarning("Both '#{col_name}' schedule file and weekend fractions provided; the latter will be ignored.") if !pool_or_spa.heater_weekend_fractions.nil?
      runner.registerWarning("Both '#{col_name}' schedule file and monthly multipliers provided; the latter will be ignored.") if !pool_or_spa.heater_monthly_multipliers.nil?
    end

    if heater_kwh > 0
      if not schedules_file.nil?
        space_design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: heater_kwh)
      end
      if space_design_level.nil?
        space_design_level = heater_sch.calc_design_level_from_daily_kwh(heater_kwh / 365.0)
        heater_sch = heater_sch.schedule
      end

      Model.add_electric_equipment(
        model,
        name: obj_name,
        end_use: obj_name,
        space: spaces[HPXML::LocationConditionedSpace], # no heat gain, so assign the equipment to an arbitrary space
        design_level: space_design_level,
        frac_radiant: 0,
        frac_latent: 0,
        frac_lost: 1,
        schedule: heater_sch
      )

    end

    if heater_therm > 0
      if not schedules_file.nil?
        space_design_level = schedules_file.calc_design_level_from_annual_therm(col_name: col_name, annual_therm: heater_therm)
      end
      if space_design_level.nil?
        space_design_level = heater_sch.calc_design_level_from_daily_therm(heater_therm / 365.0)
        heater_sch = heater_sch.schedule
      end

      Model.add_other_equipment(
        model,
        name: obj_name,
        end_use: obj_name,
        space: spaces[HPXML::LocationConditionedSpace], # no heat gain, so assign the equipment to an arbitrary space
        design_level: space_design_level,
        frac_radiant: 0,
        frac_latent: 0,
        frac_lost: 1,
        schedule: heater_sch,
        fuel_type: HPXML::FuelTypeNaturalGas
      )
    end
  end

  # Adds the HPXML Pool or Permanent Spa Pump to the OpenStudio model.
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param pool_or_spa [TODO] TODO
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @param unavailable_periods [HPXML::UnavailablePeriods] Object that defines periods for, e.g., power outages or vacancies
  # @return [nil]
  def self.apply_pool_or_permanent_spa_pump(runner, model, pool_or_spa, spaces, schedules_file, unavailable_periods)
    pump_kwh = 0
    if not pool_or_spa.pump_kwh_per_year.nil?
      pump_kwh = pool_or_spa.pump_kwh_per_year * pool_or_spa.pump_usage_multiplier
    end

    return if pump_kwh <= 0

    # Create schedule
    pump_sch = nil
    if pool_or_spa.is_a? HPXML::Pool
      obj_name = Constants::ObjectTypeMiscPoolPump
      col_name = 'pool_pump'
    else
      obj_name = Constants::ObjectTypeMiscPermanentSpaPump
      col_name = 'permanent_spa_pump'
    end
    if not schedules_file.nil?
      pump_sch = schedules_file.create_schedule_file(model, col_name: col_name)
    end
    if pump_sch.nil?
      col_unavailable_periods = Schedule.get_unavailable_periods(runner, col_name, unavailable_periods)
      pump_sch = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', pool_or_spa.pump_weekday_fractions, pool_or_spa.pump_weekend_fractions, pool_or_spa.pump_monthly_multipliers, EPlus::ScheduleTypeLimitsFraction, unavailable_periods: col_unavailable_periods)
    else
      runner.registerWarning("Both '#{col_name}' schedule file and weekday fractions provided; the latter will be ignored.") if !pool_or_spa.pump_weekday_fractions.nil?
      runner.registerWarning("Both '#{col_name}' schedule file and weekend fractions provided; the latter will be ignored.") if !pool_or_spa.pump_weekend_fractions.nil?
      runner.registerWarning("Both '#{col_name}' schedule file and monthly multipliers provided; the latter will be ignored.") if !pool_or_spa.pump_monthly_multipliers.nil?
    end

    if not schedules_file.nil?
      space_design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: pump_kwh)
    end
    if space_design_level.nil?
      space_design_level = pump_sch.calc_design_level_from_daily_kwh(pump_kwh / 365.0)
      pump_sch = pump_sch.schedule
    end

    Model.add_electric_equipment(
      model,
      name: obj_name,
      end_use: obj_name,
      space: spaces[HPXML::LocationConditionedSpace], # no heat gain, so assign the equipment to an arbitrary space
      design_level: space_design_level,
      frac_radiant: 0,
      frac_latent: 0,
      frac_lost: 1,
      schedule: pump_sch
    )
  end
end
