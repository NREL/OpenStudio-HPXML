# frozen_string_literal: true

class Battery
  def self.apply(runner, model, battery)
    obj_name = battery.id

    power = battery.rated_power_output # W
    voltage = battery.nominal_voltage # V
    if not battery.nominal_capacity_kwh.nil?
      capacity = battery.nominal_capacity_kwh # kWh
    else
      capacity = get_kWh_from_Ah(battery.nominal_capacity_ah, voltage) # kWh
    end

    return if power <= 0 || capacity <= 0 || voltage <= 0

    is_outside = (battery.location == HPXML::LocationOutside)
    if not is_outside
      frac_sens = 1.0
    else # Internal gains outside unit
      frac_sens = 0.0
    end

    # The following calculations are from Rohit C.
    number_of_cells_in_series = Integer((voltage / 3.6).round)
    number_of_strings_in_parallel = Integer(((capacity * 1000.0) / (voltage * 3.2)).round)
    battery_mass = (capacity / 10.0) * 99.0 # kg
    battery_surface_area = 0.306 * (capacity**(2.0 / 3.0)) # m^2

    minimum_storage_state_of_charge_fraction = 0.15 # from SAM
    maximum_storage_state_of_charge_fraction = 0.95 # from SAM
    initial_fractional_state_of_charge = 0.5 # from SAM

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
    elcs.setInitialFractionalStateofCharge(initial_fractional_state_of_charge)
    elcs.setBatteryMass(battery_mass)
    elcs.setBatterySurfaceArea(battery_surface_area)

    model.getElectricLoadCenterDistributions.each do |elcd|
      next unless elcd.inverter.is_initialized

      elcd.setElectricalBussType('DirectCurrentWithInverterDCStorage')
      elcd.setMinimumStorageStateofChargeFraction(minimum_storage_state_of_charge_fraction)
      elcd.setMaximumStorageStateofChargeFraction(maximum_storage_state_of_charge_fraction)
      elcd.setStorageOperationScheme('TrackFacilityElectricDemandStoreExcessOnSite')
      elcd.setElectricalStorage(elcs)
      runner.registerWarning("Due to an OpenStudio bug, the battery's rated power output will not be honored; the simulation will proceed without a maximum charge/discharge limit.")
      elcd.setDesignStorageControlDischargePower(power)
      elcd.setDesignStorageControlChargePower(power)
    end
  end

  def self.get_battery_default_values()
    return { location: HPXML::LocationOutside,
             lifetime_model: HPXML::BatteryLifetimeModelNone,
             rated_power_output: 5000.0,
             nominal_capacity_kwh: 10.0,
             nominal_voltage: 50.0 }
  end

  def self.get_Ah_from_kWh(capacity, voltage)
    return capacity * 1000.0 / voltage
  end

  def self.get_kWh_from_Ah(capacity, voltage)
    return capacity * voltage / 1000.0
  end
end
