# frozen_string_literal: true

class Battery
  def self.apply(model, battery)
    obj_name = battery.id

    voltage = battery.nominal_voltage # V
    capacity = battery.nominal_capacity # kWh

    return if capacity <= 0 || voltage <= 0

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

    minimum_storage_state_of_charge_fraction = 0.1
    maximum_storage_state_of_charge_fraction = 0.9
    initial_fractional_state_of_charge = minimum_storage_state_of_charge_fraction

    elcds = model.getElectricLoadCenterDistributions
    if elcds.empty?
      elcd = OpenStudio::Model::ElectricLoadCenterDistribution.new(model)
      elcd.setName('Battery elec load center dist')
      elcd.setElectricalBussType('AlternatingCurrentWithStorage')
    else # has PV
      elcd = elcds[0]

      if elcd.inverter.is_initialized
        elcd.setElectricalBussType('DirectCurrentWithInverterDCStorage')
        initial_fractional_state_of_charge = (minimum_storage_state_of_charge_fraction + maximum_storage_state_of_charge_fraction) / 2.0
      end
    end

    elcd.setMinimumStorageStateofChargeFraction(minimum_storage_state_of_charge_fraction)
    elcd.setMaximumStorageStateofChargeFraction(maximum_storage_state_of_charge_fraction)
    # elcd.setGeneratorOperationSchemeType('TrackElectrical')
    # elcd.setDemandLimitSchemePurchasedElectricDemandLimit(0)
    # elcd.setStorageOperationScheme('TrackFacilityElectricDemandStoreExcessOnSite')

    elcs = OpenStudio::Model::ElectricLoadCenterStorageLiIonNMCBattery.new(model, number_of_cells_in_series, number_of_strings_in_parallel, battery_mass, battery_surface_area)
    elcs.setName("#{obj_name} li ion")
    unless is_outside
      space = battery.additional_properties.space
      thermal_zone = space.thermalZone.get
      elcs.setThermalZone(thermal_zone)
    end
    elcs.setRadiativeFraction(0.9 * frac_sens) # from Rohit C.
    elcs.setLifetimeModel(battery.lifetime_model)
    elcs.setNumberofCellsinSeries(number_of_cells_in_series)
    elcs.setNumberofStringsinParallel(number_of_strings_in_parallel)
    elcs.setInitialFractionalStateofCharge(initial_fractional_state_of_charge)
    elcs.setBatteryMass(battery_mass)
    elcs.setBatterySurfaceArea(battery_surface_area)
    elcs.setFractionofCellCapacityRemovedattheEndofExponentialZone(2.584) # from Rohit C.
    elcs.setFractionofCellCapacityRemovedattheEndofNominalZone(3.126) # from Rohit C.

    elcd.setElectricalStorage(elcs)
  end

  def self.get_battery_default_values()
    return { location: HPXML::LocationOutside,
             lifetime_model: HPXML::BatteryLifetimeModelNone,
             nominal_capacity: 10.0,
             nominal_voltage: 50.0 }
  end

  def self.get_Ah_from_kWh(capacity, voltage)
    return capacity * 1000.0 / voltage
  end

  def self.get_kWh_from_Ah(capacity, voltage)
    return capacity * voltage / 1000.0
  end
end
