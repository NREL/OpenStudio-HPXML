# frozen_string_literal: true

class MiscLoads
  def self.apply_plug(model, plug_load_misc, plug_load_tv,
                      plug_load_vehicle, plug_load_well_pump,
                      cfa, living_space)

    misc_kwh = 0
    if not plug_load_misc.nil?
      misc_kwh = plug_load_misc.kWh_per_year * plug_load_misc.usage_multiplier
      misc_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameMiscPlugLoads + ' schedule', plug_load_misc.weekday_fractions, plug_load_misc.weekend_fractions, plug_load_misc.monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    end
    tv_kwh = 0
    if not plug_load_tv.nil?
      tv_kwh = plug_load_tv.kWh_per_year * plug_load_tv.usage_multiplier
      tv_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameMiscPlugLoads + ' schedule', plug_load_tv.weekday_fractions, plug_load_tv.weekend_fractions, plug_load_tv.monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    end
    vehicle_kwh = 0
    if not plug_load_vehicle.nil?
      vehicle_kwh = plug_load_vehicle.kWh_per_year * plug_load_vehicle.usage_multiplier
      vehicle_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameMiscPlugLoads + ' schedule', plug_load_vehicle.weekday_fractions, plug_load_vehicle.weekend_fractions, plug_load_vehicle.monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    end
    well_pump_kwh = 0
    if not plug_load_well_pump.nil?
      well_pump_kwh = plug_load_well_pump.kWh_per_year * plug_load_well_pump.usage_multiplier
      well_pump_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameMiscPlugLoads + ' schedule', plug_load_well_pump.weekday_fractions, plug_load_well_pump.weekend_fractions, plug_load_well_pump.monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    end

    return if misc_kwh + tv_kwh + vehicle_kwh + well_pump_kwh <= 0

    sens_frac = plug_load_misc.frac_sensible
    lat_frac = plug_load_misc.frac_latent

    # check for valid inputs
    if (sens_frac < 0) || (sens_frac > 1)
      fail 'Sensible fraction must be greater than or equal to 0 and less than or equal to 1.'
    end
    if (lat_frac < 0) || (lat_frac > 1)
      fail 'Latent fraction must be greater than or equal to 0 and less than or equal to 1.'
    end
    if lat_frac + sens_frac > 1
      fail 'Sum of sensible and latent fractions must be less than or equal to 1.'
    end

    # Misc plug loads
    if misc_kwh > 0
      space_design_level = misc_sch.calcDesignLevelFromDailykWh(misc_kwh / 365.0)

      # Add electric equipment for the mel
      mel_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      mel = OpenStudio::Model::ElectricEquipment.new(mel_def)
      mel.setName(Constants.ObjectNameMiscPlugLoads)
      mel.setEndUseSubcategory(Constants.ObjectNameMiscPlugLoads)
      mel.setSpace(living_space)
      mel_def.setName(Constants.ObjectNameMiscPlugLoads)
      mel_def.setDesignLevel(space_design_level)
      mel_def.setFractionRadiant(0.6 * sens_frac)
      mel_def.setFractionLatent(lat_frac)
      mel_def.setFractionLost(1 - sens_frac - lat_frac)
      mel.setSchedule(misc_sch.schedule)
    end

    # Television
    sens_frac = 1.0
    lat_frac = 0.0

    if tv_kwh > 0
      space_design_level = tv_sch.calcDesignLevelFromDailykWh(tv_kwh / 365.0)

      # Add electric equipment for the television
      mel_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      mel = OpenStudio::Model::ElectricEquipment.new(mel_def)
      mel.setName(Constants.ObjectNameMiscTelevision)
      mel.setEndUseSubcategory(Constants.ObjectNameMiscTelevision)
      mel.setSpace(living_space)
      mel_def.setName(Constants.ObjectNameMiscTelevision)
      mel_def.setDesignLevel(space_design_level)
      mel_def.setFractionRadiant(0.6 * sens_frac)
      mel_def.setFractionLatent(lat_frac)
      mel_def.setFractionLost(1 - sens_frac - lat_frac)
      mel.setSchedule(tv_sch.schedule)
    end

    # Vehicle / Well Pump
    [[vehicle_kwh, vehicle_sch, Constants.ObjectNameMiscVehicle], [well_pump_kwh, well_pump_sch, Constants.ObjectNameMiscWellPump]].each do |kwh, sch, name|
      next unless kwh > 0
      space_design_level = sch.calcDesignLevelFromDailykWh(kwh / 365.0)

      # Add electric equipment for the television
      mel_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      mel = OpenStudio::Model::ElectricEquipment.new(mel_def)
      mel.setName(name)
      mel.setEndUseSubcategory(name)
      mel.setSpace(living_space)
      mel_def.setName(name)
      mel_def.setDesignLevel(space_design_level)
      mel_def.setFractionRadiant(0)
      mel_def.setFractionLatent(0)
      mel_def.setFractionLost(1)
      mel.setSchedule(sch.schedule)
    end
  end

  def self.get_residual_mels_default_values(cfa)
    annual_kwh = 0.91 * cfa
    frac_lost = 0.10
    frac_sens = (1.0 - frac_lost) * 0.95
    frac_lat = 1.0 - frac_sens - frac_lost
    return annual_kwh, frac_sens, frac_lat
  end

  def self.get_televisions_default_values(cfa, nbeds)
    annual_kwh = 413.0 + 0.0 * cfa + 69.0 * nbeds
    frac_lost = 0.0
    frac_sens = (1.0 - frac_lost) * 1.0
    frac_lat = 1.0 - frac_sens - frac_lost
    return annual_kwh, frac_sens, frac_lat
  end

  def self.apply_fuel(model, fuel_load_grill, fuel_load_lighting, fuel_load_fireplace,
                      living_space)

    grill_therm = 0
    if not fuel_load_grill.nil?
      grill_therm = fuel_load_grill.therm_per_year * fuel_load_grill.usage_multiplier
      grill_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameMiscGasGrill + ' schedule', fuel_load_grill.weekday_fractions, fuel_load_grill.weekend_fractions, fuel_load_grill.monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    end
    lighting_therm = 0
    if not fuel_load_lighting.nil?
      lighting_therm = fuel_load_lighting.therm_per_year * fuel_load_lighting.usage_multiplier
      lighting_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameMiscGasLighting + ' schedule', fuel_load_lighting.weekday_fractions, fuel_load_lighting.weekend_fractions, fuel_load_lighting.monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    end
    fireplace_therm = 0
    if not fuel_load_fireplace.nil?
      fireplace_therm = fuel_load_fireplace.therm_per_year * fuel_load_fireplace.usage_multiplier
      fireplace_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameMiscGasFireplace + ' schedule', fuel_load_fireplace.weekday_fractions, fuel_load_fireplace.weekend_fractions, fuel_load_fireplace.monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    end

    # Misc fuel loads
    [[grill_therm, grill_sch, Constants.ObjectNameMiscGasGrill], [lighting_therm, lighting_sch, Constants.ObjectNameMiscGasLighting], [fireplace_therm, fireplace_sch, Constants.ObjectNameMiscGasFireplace]].each do |therm, sch, name|
      next unless therm > 0
      space_design_level = sch.calcDesignLevelFromDailyTherm(therm / 365.0)

      # Add electric equipment for the mel
      mel_def = OpenStudio::Model::GasEquipmentDefinition.new(model)
      mel = OpenStudio::Model::GasEquipment.new(mel_def)
      mel.setName(name)
      mel.setEndUseSubcategory(name)
      mel.setSpace(living_space)
      mel_def.setName(name)
      mel_def.setDesignLevel(space_design_level)
      mel_def.setFractionRadiant(0)
      mel_def.setFractionLatent(0)
      mel_def.setFractionLost(1)
      mel.setSchedule(sch.schedule)
    end
  end

  def self.apply_pool_or_hot_tub_heater(model, pool_or_hot_tub, obj_name, living_space)
    heater_kwh = 0
    heater_therm = 0
    if pool_or_hot_tub.heater_type == HPXML::HeaterTypeElectric
      heater_kwh = pool_or_hot_tub.heater_kwh_per_year * pool_or_hot_tub.heater_usage_multiplier
      heater_sch = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', pool_or_hot_tub.weekday_fractions, pool_or_hot_tub.weekend_fractions, pool_or_hot_tub.monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    elsif pool_or_hot_tub.heater_type == HPXML::HeaterTypeGas
      heater_therm = pool_or_hot_tub.heater_therm_per_year * pool_or_hot_tub.heater_usage_multiplier
      heater_sch = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', pool_or_hot_tub.weekday_fractions, pool_or_hot_tub.weekend_fractions, pool_or_hot_tub.monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    end

    if heater_kwh > 0
      space_design_level = heater_sch.calcDesignLevelFromDailykWh(heater_kwh / 365.0)

      mel_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      mel = OpenStudio::Model::ElectricEquipment.new(mel_def)
      mel.setName(obj_name)
      mel.setEndUseSubcategory(obj_name)
      mel.setSpace(living_space)
      mel_def.setName(obj_name)
      mel_def.setDesignLevel(space_design_level)
      mel_def.setFractionRadiant(0)
      mel_def.setFractionLatent(0)
      mel_def.setFractionLost(1)
      mel.setSchedule(heater_sch.schedule)
    end

    if heater_therm > 0
      space_design_level = heater_sch.calcDesignLevelFromDailyTherm(heater_therm / 365.0)

      mel_def = OpenStudio::Model::GasEquipmentDefinition.new(model)
      mel = OpenStudio::Model::GasEquipment.new(mel_def)
      mel.setName(obj_name)
      mel.setEndUseSubcategory(obj_name)
      mel.setSpace(living_space)
      mel_def.setName(obj_name)
      mel_def.setDesignLevel(space_design_level)
      mel_def.setFractionRadiant(0)
      mel_def.setFractionLatent(0)
      mel_def.setFractionLost(1)
      mel.setSchedule(heater_sch.schedule)
    end
  end

  def self.apply_pool_or_hot_tub_pump(model, pool_or_hot_tub, obj_name, living_space)
    pump_kwh = 0
    if not pool_or_hot_tub.pump_kwh_per_year.nil?
      pump_kwh = pool_or_hot_tub.pump_kwh_per_year * pool_or_hot_tub.pump_usage_multiplier
      pump_sch = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', pool_or_hot_tub.weekday_fractions, pool_or_hot_tub.weekend_fractions, pool_or_hot_tub.monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    end

    if pump_kwh > 0
      space_design_level = pump_sch.calcDesignLevelFromDailykWh(pump_kwh / 365.0)

      mel_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      mel = OpenStudio::Model::ElectricEquipment.new(mel_def)
      mel.setName(obj_name)
      mel.setEndUseSubcategory(obj_name)
      mel.setSpace(living_space)
      mel_def.setName(obj_name)
      mel_def.setDesignLevel(space_design_level)
      mel_def.setFractionRadiant(0)
      mel_def.setFractionLatent(0)
      mel_def.setFractionLost(1)
      mel.setSchedule(pump_sch.schedule)
    end
  end

  def self.get_pool_pump_default_values(cfa, nbeds)
    return 158.6 / 0.070 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # kWh/yr
  end

  def self.get_pool_heater_electric_default_values(cfa, nbeds)
    return 8.3 / 0.004 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # kWh/yr
  end

  def self.get_pool_heater_gas_default_values(cfa, nbeds)
    return 3.0 / 0.014 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # therm/yr
  end

  def self.get_hot_tub_pump_default_values(cfa, nbeds)
    return 59.5 / 0.059 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # kWh/yr
  end

  def self.get_hot_tub_heater_electric_default_values(cfa, nbeds)
    return 49.0 / 0.048 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # kWh/yr
  end

  def self.get_hot_tub_heater_gas_default_values(cfa, nbeds)
    return 0.87 / 0.011 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # therm/yr
  end

  def self.get_well_pump_default_values(cfa, nbeds)
    return 50.8 / 0.127 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # kWh/yr
  end

  def self.get_gas_grill_default_values(cfa, nbeds)
    return 0.87 / 0.029 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # therm/yr
  end

  def self.get_gas_lighting_default_values(cfa, nbeds)
    return 0.22 / 0.012 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # therm/yr
  end

  def self.get_gas_fireplace_default_values(cfa, nbeds)
    return 1.95 / 0.032 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # therm/yr
  end
end
