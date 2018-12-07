require_relative "constants"
require_relative "unit_conversions"
require_relative "schedules"

class MiscLoads
  def self.apply_plug(model, unit, runner, annual_energy, sens_frac, lat_frac,
                      weekday_sch, weekend_sch, monthly_sch, sch)

    # check for valid inputs
    if annual_energy < 0
      runner.registerError("Annual energy use must be greater than or equal to 0.")
      return false
    end
    if sens_frac < 0 or sens_frac > 1
      runner.registerError("Sensible fraction must be greater than or equal to 0 and less than or equal to 1.")
      return false
    end
    if lat_frac < 0 or lat_frac > 1
      runner.registerError("Latent fraction must be greater than or equal to 0 and less than or equal to 1.")
      return false
    end
    if lat_frac + sens_frac > 1
      runner.registerError("Sum of sensible and latent fractions must be less than or equal to 1.")
      return false
    end

    # Get unit ffa
    ffa = Geometry.get_finished_floor_area_from_spaces(unit.spaces, false, runner)
    if ffa.nil?
      return false
    end

    unit.spaces.each do |space|
      next if Geometry.space_is_unfinished(space)

      obj_name = Constants.ObjectNameMiscPlugLoads(unit.name.to_s)
      space_obj_name = "#{obj_name}|#{space.name.to_s}"

      # Remove any existing mels
      objects_to_remove = []
      space.electricEquipment.each do |space_equipment|
        next if space_equipment.name.to_s != space_obj_name

        objects_to_remove << space_equipment
        objects_to_remove << space_equipment.electricEquipmentDefinition
        if space_equipment.schedule.is_initialized
          objects_to_remove << space_equipment.schedule.get
        end
      end
      if objects_to_remove.size > 0
        runner.registerInfo("Removed existing plug loads from space '#{space.name.to_s}'.")
      end
      objects_to_remove.uniq.each do |object|
        begin
          object.remove
        rescue
          # no op
        end
      end

      if annual_energy > 0

        if sch.nil?
          # Create schedule
          sch = MonthWeekdayWeekendSchedule.new(model, runner, Constants.ObjectNameMiscPlugLoads + " schedule", weekday_sch, weekend_sch, monthly_sch)
          if not sch.validated?
            return false
          end
        end

        space_mel_ann = annual_energy * UnitConversions.convert(space.floorArea, "m^2", "ft^2") / ffa
        space_design_level = sch.calcDesignLevelFromDailykWh(space_mel_ann / 365.0)

        # Add electric equipment for the mel
        mel_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
        mel = OpenStudio::Model::ElectricEquipment.new(mel_def)
        mel.setName(space_obj_name)
        mel.setEndUseSubcategory(obj_name)
        mel.setSpace(space)
        mel_def.setName(space_obj_name)
        mel_def.setDesignLevel(space_design_level)
        mel_def.setFractionRadiant(0.6 * sens_frac)
        mel_def.setFractionLatent(lat_frac)
        mel_def.setFractionLost(1 - sens_frac - lat_frac)
        mel.setSchedule(sch.schedule)

      end
    end

    return true, sch
  end

  def self.apply_electric(model, unit, runner, annual_energy, mult,
                          weekday_sch, weekend_sch, monthly_sch, sch, space,
                          unit_obj_name, scale_energy)

    # check for valid inputs
    if annual_energy < 0
      runner.registerError("Annual energy must be greater than or equal to 0.")
      return false
    end
    if mult < 0
      runner.registerError("Energy multiplier must be greater than or equal to 0.")
      return false
    end

    # Calculate annual energy use
    ann_e = annual_energy * mult # kWh/yr

    if scale_energy
      # Get unit beds/baths
      nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
      if nbeds.nil? or nbaths.nil?
        return false
      end

      # Get unit ffa
      ffa = Geometry.get_finished_floor_area_from_spaces(unit.spaces, false, runner)
      if ffa.nil?
        return false
      end

      # Scale energy use by num beds and floor area
      constant = 1.0 / 2
      nbr_coef = 1.0 / 4 / 3
      ffa_coef = 1.0 / 4 / 1920
      ann_e = ann_e * (constant + nbr_coef * nbeds + ffa_coef * ffa) # kWh/yr
    end

    if ann_e > 0

      if sch.nil?
        # Create schedule
        sch = MonthWeekdayWeekendSchedule.new(model, runner, unit_obj_name + " schedule", weekday_sch, weekend_sch, monthly_sch)
        if not sch.validated?
          return false
        end
      end

      design_level = sch.calcDesignLevelFromDailykWh(ann_e / 365.0)

      # Add electric equipment for the load
      load_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      load = OpenStudio::Model::ElectricEquipment.new(load_def)
      load.setName(unit_obj_name)
      load.setEndUseSubcategory(unit_obj_name)
      if space.nil?
        # Use arbitrary space with FractionLost=1
        load.setSpace(model.getSpaces[0])
        load_def.setFractionLost(1)
      else
        load.setSpace(space)
        load_def.setFractionLost(0)
      end
      load_def.setFractionRadiant(0)
      load_def.setFractionLatent(0)
      load_def.setName(unit_obj_name)
      load_def.setDesignLevel(design_level)
      load.setSchedule(sch.schedule)

    end

    return true, ann_e, sch
  end

  def self.apply_gas(model, unit, runner, annual_energy, mult,
                     weekday_sch, weekend_sch, monthly_sch, sch, space,
                     unit_obj_name, scale_energy)

    # check for valid inputs
    if annual_energy < 0
      runner.registerError("Annual energy must be greater than or equal to 0.")
      return false
    end
    if mult < 0
      runner.registerError("Energy multiplier must be greater than or equal to 0.")
      return false
    end

    # Calculate annual energy use
    ann_g = annual_energy * mult # therm/yr

    if scale_energy
      # Get unit beds/baths
      nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
      if nbeds.nil? or nbaths.nil?
        return false
      end

      # Get unit ffa
      ffa = Geometry.get_finished_floor_area_from_spaces(unit.spaces, false, runner)
      if ffa.nil?
        return false
      end

      # Scale energy use by num beds and floor area
      constant = 1.0 / 2
      nbr_coef = 1.0 / 4 / 3
      ffa_coef = 1.0 / 4 / 1920
      ann_g = ann_g * (constant + nbr_coef * nbeds + ffa_coef * ffa) # therm/yr
    end

    if ann_g > 0

      if sch.nil?
        # Create schedule
        sch = MonthWeekdayWeekendSchedule.new(model, runner, unit_obj_name + " schedule", weekday_sch, weekend_sch, monthly_sch)
        if not sch.validated?
          return false
        end
      end

      design_level = sch.calcDesignLevelFromDailyTherm(ann_g / 365.0)

      # Add gas equipment for the load
      load_def = OpenStudio::Model::GasEquipmentDefinition.new(model)
      load = OpenStudio::Model::GasEquipment.new(load_def)
      load.setName(unit_obj_name)
      load.setEndUseSubcategory(unit_obj_name)
      if space.nil?
        # Use arbitrary space with FractionLost=1
        load.setSpace(model.getSpaces[0])
        load_def.setFractionLost(1)
      else
        load.setSpace(space)
        load_def.setFractionLost(0)
      end
      load_def.setFractionRadiant(0)
      load_def.setFractionLatent(0)
      load_def.setName(unit_obj_name)
      load_def.setDesignLevel(design_level)
      load.setSchedule(sch.schedule)

    end

    return true, ann_g, sch
  end

  def self.remove(runner, space, obj_names)
    # Remove any existing large, uncommon loads
    objects_to_remove = []
    space.electricEquipment.each do |space_equipment|
      found = false
      obj_names.each do |obj_name|
        next if not space_equipment.name.to_s.start_with? obj_name

        found = true
      end
      next if not found

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.electricEquipmentDefinition
      if space_equipment.schedule.is_initialized
        objects_to_remove << space_equipment.schedule.get
      end
    end
    space.gasEquipment.each do |space_equipment|
      found = false
      obj_names.each do |obj_name|
        next if not space_equipment.name.to_s.start_with? obj_name

        found = true
      end
      next if not found

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.gasEquipmentDefinition
      if space_equipment.schedule.is_initialized
        objects_to_remove << space_equipment.schedule.get
      end
    end
    if objects_to_remove.size > 0
      runner.registerInfo("Removed existing large, uncommon loads from space '#{space.name.to_s}'.")
    end
    objects_to_remove.uniq.each do |object|
      begin
        object.remove
      rescue
        # no op
      end
    end
  end

  def self.apply_tv(model, unit, runner, annual_energy, sch, space)
    name = Constants.ObjectNameMiscTelevision(unit.name.to_s)
    design_level = sch.calcDesignLevelFromDailykWh(annual_energy / 365.0)
    sens_frac = 1.0
    lat_frac = 0.0

    # Add electric equipment for the mel
    mel_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    mel = OpenStudio::Model::ElectricEquipment.new(mel_def)
    mel.setName(name)
    mel.setEndUseSubcategory(name)
    mel.setSpace(space)
    mel_def.setName(name)
    mel_def.setDesignLevel(design_level)
    mel_def.setFractionRadiant(0.6 * sens_frac)
    mel_def.setFractionLatent(lat_frac)
    mel_def.setFractionLost(1 - sens_frac - lat_frac)
    mel.setSchedule(sch.schedule)

    return true
  end

  def self.get_residual_mels_values(cfa)
    # Table 4.2.2.5(1) Lighting, Appliance and Miscellaneous Electric Loads in electric Reference Homes
    annual_kwh = 0.91 * cfa

    # Table 4.2.2(3). Internal Gains for Reference Homes
    load_sens = 7.27 * cfa # Btu/day
    load_lat = 0.38 * cfa # Btu/day
    total = UnitConversions.convert(annual_kwh, "kWh", "Btu") / 365.0 # Btu/day

    return annual_kwh, load_sens / total, load_lat / total
  end

  def self.get_televisions_values(cfa, nbeds)
    # Table 4.2.2.5(1) Lighting, Appliance and Miscellaneous Electric Loads in electric Reference Homes
    annual_kwh = 413.0 + 0.0 * cfa + 69.0 * nbeds

    # Table 4.2.2(3). Internal Gains for Reference Homes
    load_sens = 3861.0 + 645.0 * nbeds # Btu/day
    load_lat = 0.0 # Btu/day
    total = UnitConversions.convert(annual_kwh, "kWh", "Btu") / 365.0 # Btu/day

    return annual_kwh, load_sens / total, load_lat / total
  end
end
