# frozen_string_literal: true

class MiscLoads
  def self.apply_plug(model, plug_load, obj_name, cfa, living_space)
    kwh = 0
    if not plug_load.nil?
      kwh = plug_load.kWh_per_year * plug_load.usage_multiplier
      sch = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', plug_load.weekday_fractions, plug_load.weekend_fractions, plug_load.monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    end

    return if kwh <= 0

    sens_frac = plug_load.frac_sensible
    lat_frac = plug_load.frac_latent

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

    if plug_load.location == HPXML::LocationExterior
      # Set all heat gain as lost
      sens_frac = 0.0
      lat_fract = 0.0
    end

    space_design_level = sch.calcDesignLevelFromDailykWh(kwh / 365.0)

    # Add electric equipment for the mel
    mel_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    mel = OpenStudio::Model::ElectricEquipment.new(mel_def)
    mel.setName(obj_name)
    mel.setEndUseSubcategory(obj_name)
    mel.setSpace(living_space)
    mel_def.setName(obj_name)
    mel_def.setDesignLevel(space_design_level)
    mel_def.setFractionRadiant(0.6 * sens_frac)
    mel_def.setFractionLatent(lat_frac)
    mel_def.setFractionLost(1 - sens_frac - lat_frac)
    mel.setSchedule(sch.schedule)
  end

  def self.apply_fuel(model, fuel_load, obj_name, living_space)
    therm = 0
    if not fuel_load.nil?
      therm = fuel_load.therm_per_year * fuel_load.usage_multiplier
      sch = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', fuel_load.weekday_fractions, fuel_load.weekend_fractions, fuel_load.monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    end

    return if therm <= 0

    sens_frac = fuel_load.frac_sensible
    lat_frac = fuel_load.frac_latent

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

    if fuel_load.location == HPXML::LocationExterior
      # Set all heat gain as lost
      sens_frac = 0.0
      lat_fract = 0.0
    end

    space_design_level = sch.calcDesignLevelFromDailyTherm(therm / 365.0)

    # Add other equipment for the mfl
    mfl_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
    mfl = OpenStudio::Model::OtherEquipment.new(mfl_def)
    mfl.setName(obj_name)
    mfl.setEndUseSubcategory(obj_name)
    mfl.setFuelType(EPlus.input_fuel_map(fuel_load.fuel_type))
    mfl.setSpace(living_space)
    mfl_def.setName(obj_name)
    mfl_def.setDesignLevel(space_design_level)
    mfl_def.setFractionRadiant(0.6 * sens_frac)
    mfl_def.setFractionLatent(lat_frac)
    mfl_def.setFractionLost(1 - sens_frac - lat_frac)
    mfl.setSchedule(sch.schedule)
  end

  def self.apply_pool_or_hot_tub_heater(model, pool_or_hot_tub, obj_name, living_space)
    heater_kwh = 0
    heater_therm = 0
    heater_sch = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', pool_or_hot_tub.heater_weekday_fractions, pool_or_hot_tub.heater_weekend_fractions, pool_or_hot_tub.heater_monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    if pool_or_hot_tub.heater_load_units == HPXML::UnitsKwhPerYear
      heater_kwh = pool_or_hot_tub.heater_load_value * pool_or_hot_tub.heater_usage_multiplier
    elsif pool_or_hot_tub.heater_load_units == HPXML::UnitsThermPerYear
      heater_therm = pool_or_hot_tub.heater_load_value * pool_or_hot_tub.heater_usage_multiplier
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
    pump_sch = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', pool_or_hot_tub.pump_weekday_fractions, pool_or_hot_tub.pump_weekend_fractions, pool_or_hot_tub.pump_monthly_multipliers, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)
    if not pool_or_hot_tub.pump_kwh_per_year.nil?
      pump_kwh = pool_or_hot_tub.pump_kwh_per_year * pool_or_hot_tub.pump_usage_multiplier
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

  private

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

  def self.get_pool_pump_default_values(cfa, nbeds)
    return 158.6 / 0.070 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # kWh/yr
  end

  def self.get_pool_heater_default_values(cfa, nbeds, type)
    load_units = nil
    load_value = nil
    if [HPXML::HeaterTypeElectricResistance, HPXML::HeaterTypeHeatPump].include? type
      load_units = HPXML::UnitsKwhPerYear
      load_value = 8.3 / 0.004 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # kWh/yr
      if type == HPXML::HeaterTypeHeatPump
        load_value /= 5.0 # Assume seasonal COP of 5.0 per https://www.energy.gov/energysaver/heat-pump-swimming-pool-heaters
      end
    elsif type == HPXML::HeaterTypeGas
      load_units = HPXML::UnitsThermPerYear
      load_value = 3.0 / 0.014 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # therm/yr
    end
    return load_units, load_value
  end

  def self.get_hot_tub_pump_default_values(cfa, nbeds)
    return 59.5 / 0.059 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # kWh/yr
  end

  def self.get_hot_tub_heater_default_values(cfa, nbeds, type)
    load_units = nil
    load_value = nil
    if [HPXML::HeaterTypeElectricResistance, HPXML::HeaterTypeHeatPump].include? type
      load_units = HPXML::UnitsKwhPerYear
      load_value = 49.0 / 0.048 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # kWh/yr
      if type == HPXML::HeaterTypeHeatPump
        load_value /= 5.0 # Assume seasonal COP of 5.0 per https://www.energy.gov/energysaver/heat-pump-swimming-pool-heaters
      end
    elsif type == HPXML::HeaterTypeGas
      load_units = HPXML::UnitsThermPerYear
      load_value = 0.87 / 0.011 * (0.5 + 0.25 * nbeds / 3.0 + 0.25 * cfa / 1920.0) # therm/yr
    end
    return load_units, load_value
  end

  def self.get_electric_vehicle_charging_default_values
    ev_charger_efficiency = 0.9
    ev_battery_efficiency = 0.9
    vehicle_annual_miles_driven = 4500.0
    vehicle_kWh_per_mile = 0.3
    return vehicle_annual_miles_driven * vehicle_kWh_per_mile / (ev_charger_efficiency * ev_battery_efficiency) # kWh/yr
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
