# frozen_string_literal: true

class Battery
  def self.apply(model, battery)
    obj_name = battery.id

    number_of_cells_in_series = Integer((battery.voltage / 3.6).round)
    number_of_strings_in_parallel = Integer(((battery.capacity * 1000.0) / (battery.voltage * 3.2)).round)
    # FIXME: calculate the following from capacity/voltage
    battery_mass = 99
    battery_surface_area = 1.42

    if battery.location != HPXML::LocationOutside
      fail ''
    end

    elcs = OpenStudio::Model::ElectricLoadCenterStorageLiIonNMCBattery.new(model, number_of_cells_in_series, number_of_strings_in_parallel, battery_mass, battery_surface_area)
    elcs.setName("#{obj_name} li ion")
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
