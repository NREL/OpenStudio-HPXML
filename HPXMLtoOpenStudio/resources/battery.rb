# frozen_string_literal: true

class Battery
  def self.apply(model, battery)
    obj_name = battery.id

    capacity = battery.capacity
    voltage = battery.voltage

    return if capacity <= 0 || voltage <= 0

    is_outside = (battery.location == HPXML::LocationOutside)
    if not is_outside
      frac_sens = 1.0
    else # Internal gains outside unit
      frac_sens = 0.0
    end

    number_of_cells_in_series = Integer((voltage / 3.6).round)
    number_of_strings_in_parallel = Integer(((capacity * 1000.0) / (voltage * 3.2)).round)
    battery_mass = (capacity / 10.0) * 99.0
    battery_surface_area = 0.306 * (capacity**(2.0 / 3.0))

    elcs = OpenStudio::Model::ElectricLoadCenterStorageLiIonNMCBattery.new(model, number_of_cells_in_series, number_of_strings_in_parallel, battery_mass, battery_surface_area)
    elcs.setName("#{obj_name} li ion")
    unless is_outside
      space = battery.additional_properties.space
      thermal_zone = space.thermalZone.get
      elcs.setThermalZone(thermal_zone)
    end
    elcs.setRadiativeFraction(0.6 * frac_sens)
    elcs.setLifetimeModel(battery.lifetime_model)
    elcs.setNumberofCellsinSeries(number_of_cells_in_series)
    elcs.setNumberofStringsinParallel(number_of_strings_in_parallel)
    elcs.setBatteryMass(battery_mass)
    elcs.setBatterySurfaceArea(battery_surface_area)
    elcs.setFractionofCellCapacityRemovedattheEndofExponentialZone(2.584)
    elcs.setFractionofCellCapacityRemovedattheEndofNominalZone(3.126)

    elcds = model.getElectricLoadCenterDistributions

    if elcds.size == 0
      elcd = OpenStudio::Model::ElectricLoadCenterDistribution.new(model)
      elcd.setName("#{obj_name} elec load center dist")
    end

    elcds.each_with_index do |elcd, i|
      elcd.setElectricalBussType('DirectCurrentWithInverterDCStorage')
      if i == 0
        elcd.setElectricalStorage(elcs)
      else
        elcd.setElectricalStorage(elcs.clone.to_ElectricLoadCenterStorageLiIonNMCBattery.get)
      end
    end
  end
end
