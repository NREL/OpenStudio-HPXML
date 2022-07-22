# frozen_string_literal: true

class Battery
  def self.apply(model, battery, schedules_file)
    obj_name = battery.id

    rated_power_output = battery.rated_power_output # W
    nominal_voltage = battery.nominal_voltage # V
    if not battery.nominal_capacity_kwh.nil?
      if battery.usable_capacity_kwh.nil?
        fail "UsableCapacity and NominalCapacity for Battery '#{battery.id}' must be in the same units."
      end

      nominal_capacity_kwh = battery.nominal_capacity_kwh # kWh
      usable_fraction = battery.usable_capacity_kwh / nominal_capacity_kwh
    else
      if battery.usable_capacity_ah.nil?
        fail "UsableCapacity and NominalCapacity for Battery '#{battery.id}' must be in the same units."
      end

      nominal_capacity_kwh = get_kWh_from_Ah(battery.nominal_capacity_ah, nominal_voltage) # kWh
      usable_fraction = battery.usable_capacity_ah / battery.nominal_capacity_ah
    end

    return if rated_power_output <= 0 || nominal_capacity_kwh <= 0 || nominal_voltage <= 0

    is_outside = (battery.location == HPXML::LocationOutside)
    if not is_outside
      frac_sens = 1.0
    else # Internal gains outside unit
      frac_sens = 0.0
    end

    default_nominal_cell_voltage = 3.342 # V, EnergyPlus default
    default_cell_capacity = 3.2 # Ah, EnergyPlus default

    number_of_cells_in_series = Integer((nominal_voltage / default_nominal_cell_voltage).round)
    number_of_strings_in_parallel = Integer(((nominal_capacity_kwh * 1000.0) / ((default_nominal_cell_voltage * number_of_cells_in_series) * default_cell_capacity)).round)
    battery_mass = (nominal_capacity_kwh / 10.0) * 99.0 # kg
    battery_surface_area = 0.306 * (nominal_capacity_kwh**(2.0 / 3.0)) # m^2

    # Assuming 3/4 of unusable charge is minimum SOC and 1/4 of unusable charge is maximum SOC, based on SAM defaults
    minimum_storage_state_of_charge_fraction = 0.75 * (1.0 - usable_fraction)
    maximum_storage_state_of_charge_fraction = 1.0 - 0.25 * (1.0 - usable_fraction)

    elcs = OpenStudio::Model::ElectricLoadCenterStorageLiIonNMCBattery.new(model, number_of_cells_in_series, number_of_strings_in_parallel, battery_mass, battery_surface_area)
    elcs.setName("#{obj_name} li ion")
    unless is_outside
      space = battery.additional_properties.space
      thermal_zone = space.thermalZone.get
      elcs.setThermalZone(thermal_zone)
    end
    elcs.setRadiativeFraction(0.9 * frac_sens)
    elcs.setLifetimeModel(battery.lifetime_model)
    elcs.setNumberofCellsinSeries(number_of_cells_in_series)
    elcs.setNumberofStringsinParallel(number_of_strings_in_parallel)
    elcs.setInitialFractionalStateofCharge(0.0)
    elcs.setBatteryMass(battery_mass)
    elcs.setBatterySurfaceArea(battery_surface_area)
    elcs.setDefaultNominalCellVoltage(default_nominal_cell_voltage)
    elcs.setCellVoltageatEndofNominalZone(default_nominal_cell_voltage)
    elcs.setFullyChargedCellCapacity(default_cell_capacity)

    elcds = model.getElectricLoadCenterDistributions
    if elcds.empty?
      elcd = OpenStudio::Model::ElectricLoadCenterDistribution.new(model)
      elcd.setName('Battery elec load center dist')
      elcd.setElectricalBussType('AlternatingCurrentWithStorage') # AlternatingCurrentWithStorage, DirectCurrentWithInverterDCStorage, DirectCurrentWithInverterACStorage

      # TrackFacilityElectricDemandStoreExcessOnSite
      # TrackMeterDemandStoreExcessOnSite
      # TrackChargeDischargeSchedules
      # FacilityDemandLeveling

      # TrackMeterDemandStoreExcessOnSite
      # elcd.setStorageOperationScheme('TrackMeterDemandStoreExcessOnSite')
      # elcd.setStorageControlTrackMeterName()

      # TrackChargeDischargeSchedules
      # elcd.setStorageOperationScheme('TrackChargeDischargeSchedules')
      # elcd.setStorageChargePowerFractionSchedule(model.alwaysOnDiscreteSchedule)
      # elcd.setStorageDischargePowerFractionSchedule(model.alwaysOnDiscreteSchedule)

      # FacilityDemandLeveling
      # elcd.setStorageOperationScheme('FacilityDemandLeveling')
      # elcd.setStorageControlUtilityDemandTarget(7500)
      # elcd.setStorageControlUtilityDemandTargetFractionSchedule(model.alwaysOnDiscreteSchedule)

      # elcsc = OpenStudio::Model::ElectricLoadCenterStorageConverter.new(model)
      # elcd.setStorageConverter(elcsc)
    else
      elcd = elcds[0]
      return unless elcd.inverter.is_initialized # return if not PV (i.e., a generator)

      elcd.setElectricalBussType('DirectCurrentWithInverterDCStorage')
      elcd.setStorageOperationScheme('TrackFacilityElectricDemandStoreExcessOnSite')
    end

    elcd.setMinimumStorageStateofChargeFraction(minimum_storage_state_of_charge_fraction)
    elcd.setMaximumStorageStateofChargeFraction(maximum_storage_state_of_charge_fraction)
    elcd.setElectricalStorage(elcs)
    elcd.setDesignStorageControlDischargePower(rated_power_output)
    elcd.setDesignStorageControlChargePower(rated_power_output)

    if not schedules_file.nil?
      charging_schedule = schedules_file.create_schedule_file(col_name: SchedulesFile::ColumnBatteryCharging)
      discharging_schedule = schedules_file.create_schedule_file(col_name: SchedulesFile::ColumnBatteryDischarging)

      if (not charging_schedule.nil?) && (not discharging_schedule.nil?)
        elcd.setStorageOperationScheme('TrackChargeDischargeSchedules')
        elcd.setStorageChargePowerFractionSchedule(charging_schedule)
        elcd.setStorageDischargePowerFractionSchedule(discharging_schedule)

        elcd.setDesignStorageControlDischargePower(1000)
        elcd.setDesignStorageControlChargePower(1000)

        elcsc = OpenStudio::Model::ElectricLoadCenterStorageConverter.new(model)
        elcd.setStorageConverter(elcsc)
      end
    end
  end

  def self.get_battery_default_values()
    return { location: HPXML::LocationOutside,
             lifetime_model: HPXML::BatteryLifetimeModelNone,
             nominal_capacity_kwh: 10.0,
             nominal_voltage: 50.0,
             usable_fraction: 0.9 } # Fraction of usable capacity to nominal capacity
  end

  def self.get_Ah_from_kWh(nominal_capacity_kwh, nominal_voltage)
    return nominal_capacity_kwh * 1000.0 / nominal_voltage
  end

  def self.get_kWh_from_Ah(nominal_capacity_ah, nominal_voltage)
    return nominal_capacity_ah * nominal_voltage / 1000.0
  end
end
