# frozen_string_literal: true

class Battery
  def self.apply(model, battery)
    obj_name = battery.id

    # TODO

    battery = OpenStudio::Model::ElectricLoadCenterStorageLiIonNMCBattery.new(model)
    battery.setName("#{obj_name} battery")

    elcd = OpenStudio::Model::ElectricLoadCenterDistribution.new(model)
    elcd.setName("#{obj_name} elec load center dist")
    elcd.setElectricalBussType('AlternatingCurrentWithStorage')
    elcd.setElectricalStorage(battery)
  end
end
