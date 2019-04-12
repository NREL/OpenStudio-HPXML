class PV
  def self.apply(model, runner, obj_name, size_w, module_type, system_losses,
                 inverter_eff, tilt_abs, azimuth_abs, array_type)

    generator = OpenStudio::Model::GeneratorPVWatts.new(model, size_w)
    generator.setName("#{obj_name} generator")
    generator.setModuleType(module_type)
    generator.setSystemLosses(system_losses)
    generator.setTiltAngle(tilt_abs)
    generator.setAzimuthAngle(azimuth_abs)
    generator.setArrayType(array_type)

    electric_load_center_dist = generator.electricLoadCenterDistribution.get
    electric_load_center_dist.setName("#{obj_name} elec load center dist")

    inverter = OpenStudio::Model::ElectricLoadCenterInverterPVWatts.new(model)
    inverter.setName("#{obj_name} inverter")
    inverter.setInverterEfficiency(inverter_eff)

    electric_load_center_dist.addGenerator(generator)
    electric_load_center_dist.setInverter(inverter)

    return true
  end
end
