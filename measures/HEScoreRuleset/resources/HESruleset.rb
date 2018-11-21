require "#{File.dirname(__FILE__)}/../../HPXMLtoOpenStudio/resources/airflow"
require "#{File.dirname(__FILE__)}/../../HPXMLtoOpenStudio/resources/geometry"
require "#{File.dirname(__FILE__)}/../../HPXMLtoOpenStudio/resources/xmlhelper"

class HEScoreRuleset
  def self.apply_ruleset(hpxml_doc)
    hpxml_doc.elements["/HPXML"].attributes["schemaVersion"] = '3.0'

    # Create new BuildingDetails element
    building = hpxml_doc.elements["/HPXML/Building"]
    orig_details = XMLHelper.delete_element(building, "BuildingDetails")
    new_details = XMLHelper.add_element(building, "BuildingDetails")

    # Global variables
    @nbeds = Float(XMLHelper.get_value(orig_details, "BuildingSummary/BuildingConstruction/NumberofBedrooms"))
    @cfa = Float(XMLHelper.get_value(orig_details, "BuildingSummary/BuildingConstruction/ConditionedFloorArea"))
    @ncfl_ag = Float(XMLHelper.get_value(orig_details, "BuildingSummary/BuildingConstruction/NumberofConditionedFloorsAboveGrade"))
    @ncfl = @ncfl_ag # Number above-grade stories plus any conditioned basement
    if not XMLHelper.get_value(orig_details, "Enclosure/Foundations/Foundation/FoundationType/Basement[Conditioned='true']").nil?
      @ncfl += 1
    end
    @nfl = @ncfl_ag # Number above-grade stories plus any basement
    if not XMLHelper.get_value(orig_details, "Enclosure/Foundations/Foundation/FoundationType/Basement").nil?
      @nfl += 1
    end
    @ceil_height = Float(XMLHelper.get_value(orig_details, "BuildingSummary/BuildingConstruction/AverageCeilingHeight"))
    @bldg_orient = XMLHelper.get_value(orig_details, "BuildingSummary/Site/OrientationOfFrontOfHome")

    # Calculate geometry
    # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope
    cfa_basement = 0.0
    orig_details.elements.each("Enclosure/Foundations/Foundation[FoundationType/Basement[Conditioned='true']]") do |cond_basement|
      cfa_basement += Float(XMLHelper.get_value(cond_basement, "FrameFloor/Area"))
    end
    footprint_area = (@cfa - cfa_basement) / @ncfl_ag
    @bldg_length = (3.0 * footprint_area / 5.0)**0.5
    @bldg_width = (5.0 / 3.0) * @bldg_length
    @bldg_perimeter = 2.0 * @bldg_length + 2.0 * @bldg_width

    # BuildingSummary
    new_summary = XMLHelper.add_element(new_details, "BuildingSummary")
    set_summary(new_summary, orig_details)

    # ClimateAndRiskZones
    XMLHelper.copy_element(new_details, orig_details, "ClimateandRiskZones")

    # Enclosure
    new_enclosure = XMLHelper.add_element(new_details, "Enclosure")
    set_enclosure_air_infiltration(new_enclosure, orig_details)
    set_enclosure_attics_roofs(new_enclosure, orig_details)
    set_enclosure_foundations(new_enclosure, orig_details)
    set_enclosure_rim_joists(new_enclosure, orig_details)
    set_enclosure_walls(new_enclosure, orig_details)
    set_enclosure_windows(new_enclosure, orig_details)
    set_enclosure_skylights(new_enclosure, orig_details)
    set_enclosure_doors(new_enclosure, orig_details)

    # Systems
    new_systems = XMLHelper.add_element(new_details, "Systems")
    set_systems_hvac(new_systems, orig_details)
    set_systems_mechanical_ventilation(new_systems, orig_details)
    set_systems_water_heater(new_systems, orig_details)
    set_systems_water_heating_use(new_systems, orig_details)
    set_systems_photovoltaics(new_systems, orig_details)

    # Appliances
    new_appliances = XMLHelper.add_element(new_details, "Appliances")
    set_appliances_clothes_washer(new_appliances, orig_details)
    set_appliances_clothes_dryer(new_appliances, orig_details)
    set_appliances_dishwasher(new_appliances, orig_details)
    set_appliances_refrigerator(new_appliances, orig_details)
    set_appliances_cooking_range_oven(new_appliances, orig_details)

    # Lighting
    new_lighting = XMLHelper.add_element(new_details, "Lighting")
    set_lighting(new_lighting, orig_details)
    set_ceiling_fans(new_lighting, orig_details)
  end

  def self.set_summary(new_summary, orig_details)
    new_site = XMLHelper.add_element(new_summary, "Site")
    orig_site = orig_details.elements["BuildingSummary/Site"]
    XMLHelper.copy_element(new_site, orig_site, "FuelTypesAvailable") # FIXME: Need assumption
    extension = XMLHelper.add_element(new_site, "extension")
    XMLHelper.add_element(extension, "ShelterCoefficient", Airflow.get_default_shelter_coefficient())

    new_occupancy = XMLHelper.add_element(new_summary, "BuildingOccupancy")
    orig_occupancy = orig_details.elements["BuildingSummary/BuildingOccupancy"]
    XMLHelper.add_element(new_occupancy, "NumberofResidents", Geometry.get_occupancy_default_num(@nbeds))

    new_construction = XMLHelper.add_element(new_summary, "BuildingConstruction")
    orig_construction = orig_details.elements["BuildingSummary/BuildingConstruction"]
    XMLHelper.add_element(new_construction, "NumberofConditionedFloors", @ncfl)
    XMLHelper.add_element(new_construction, "NumberofConditionedFloorsAboveGrade", @ncfl_ag)
    XMLHelper.add_element(new_construction, "NumberofBedrooms", Integer(@nbeds))
    XMLHelper.add_element(new_construction, "ConditionedFloorArea", @cfa)
    XMLHelper.add_element(new_construction, "ConditionedBuildingVolume", @cfa * @ceil_height) # FIXME: Verify
    XMLHelper.add_element(new_construction, "GaragePresent", false)
  end

  def self.set_enclosure_air_infiltration(new_enclosure, orig_details)
    cfm50 = XMLHelper.get_value(orig_details, "Enclosure/AirInfiltration/AirInfiltrationMeasurement[HousePressure='50']/BuildingAirLeakage[UnitofMeasure='CFM']/AirLeakage")
    desc = XMLHelper.get_value(orig_details, "Enclosure/AirInfiltration/AirInfiltrationMeasurement/LeakinessDescription")

    if not cfm50.nil?
      cfm50 = Float(cfm50)
    else
      # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/infiltration/infiltration
      if desc == "tight"
        # TODO
      elsif desc == "average"
        # TODO
      end
    end

    # TODO
  end

  def self.set_enclosure_attics_roofs(new_enclosure, orig_details)
    new_attic_roof = XMLHelper.add_element(new_enclosure, "AtticAndRoof")
    new_attics = XMLHelper.add_element(new_attic_roof, "Attics")

    orig_details.elements.each("Enclosure/AtticAndRoof/Attics/Attic") do |orig_attic|
      orig_roof = get_attached(orig_attic.elements["AttachedToRoof"].attributes["idref"], orig_details, "Enclosure/AtticAndRoof/Roofs/Roof")
      attic_type = XMLHelper.get_value(orig_attic, "AtticType")
      attic_id = orig_attic.elements["SystemIdentifier"].attributes["id"]

      new_attic = XMLHelper.add_element(new_attics, "Attic")
      XMLHelper.copy_element(new_attic, orig_attic, "SystemIdentifier")
      XMLHelper.copy_element(new_attic, orig_attic, "AtticType")

      # Roofs
      roof_r_cavity = Integer(XMLHelper.get_value(orig_attic, "AtticRoofInsulation/Layer[InstallationType='cavity']/NominalRValue"))
      roof_r_cont = XMLHelper.get_value(orig_attic, "AtticRoofInsulation/Layer[InstallationType='continuous']/NominalRValue").to_i
      roof_material = XMLHelper.get_value(orig_roof, "RoofType")
      roof_has_radiant_barrier = Boolean(XMLHelper.get_value(orig_roof, "RadiantBarrier"))

      roof_r = get_roof_assembly_r(roof_r_cavity, roof_r_cont, roof_material, roof_has_radiant_barrier)

      new_roofs = XMLHelper.add_element(new_attic, "Roofs")
      new_roof = XMLHelper.add_element(new_roofs, "Roof")
      XMLHelper.copy_element(new_roof, orig_roof, "SystemIdentifier")
      XMLHelper.copy_element(new_roof, orig_roof, "Area", 1000) # FIXME: Hard-coded
      XMLHelper.copy_element(new_roof, orig_roof, "SolarAbsorptance")
      XMLHelper.add_element(new_roof, "Emittance", 0.9) # FIXME: Hard-coded
      XMLHelper.add_element(new_roof, "Pitch", 5) # FIXME: Hard-coded
      XMLHelper.add_element(new_roof, "RadiantBarrier", false) # FIXME: Verify. Setting to false because it's included in the assembly R-value
      new_roof_ins = XMLHelper.add_element(new_roof, "Insulation")
      XMLHelper.copy_element(new_roof_ins, orig_attic, "AtticRoofInsulation/SystemIdentifier")
      XMLHelper.add_element(new_roof_ins, "AssemblyEffectiveRValue", roof_r)

      # Floors
      if ["unvented attic", "vented attic"].include? attic_type
        floor_r_cavity = Integer(XMLHelper.get_value(orig_attic, "AtticFloorInsulation/Layer[InstallationType='cavity']/NominalRValue"))

        floor_r = get_ceiling_assembly_r(floor_r_cavity)

        new_floors = XMLHelper.add_element(new_attic, "Floors")
        new_floor = XMLHelper.add_element(new_floors, "Floor")
        sys_id = XMLHelper.add_element(new_floor, "SystemIdentifier")
        XMLHelper.add_attribute(sys_id, "id", "#{attic_id}_floor")
        XMLHelper.copy_element(new_floor, orig_attic, "Area") # FIXME: Verify. This is the attic floor area and not the roof area?
        new_floor_ins = XMLHelper.add_element(new_floor, "Insulation")
        XMLHelper.copy_element(new_floor_ins, orig_attic, "AtticFloorInsulation/SystemIdentifier")
        XMLHelper.add_element(new_floor_ins, "AssemblyEffectiveRValue", floor_r)
      end

      # FIXME: Verify no gable walls assumed

      # Uses ERI Reference Home for vented attic specific leakage area
    end
  end

  def self.set_enclosure_foundations(new_enclosure, orig_details)
    new_foundations = XMLHelper.add_element(new_enclosure, "Foundations")

    orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
      fnd_type = orig_foundation.elements["FoundationType"].elements[1].name
      if fnd_type == "Basement"
        if Boolean(XMLHelper.get_value(orig_foundation, "FoundationType/Basement/Conditioned"))
          fnd_type = "ConditionedBasement"
        else
          fnd_type = "UnconditionedBasement"
        end
      elsif fnd_type == "Crawlspace"
        if Boolean(XMLHelper.get_value(orig_foundation, "FoundationType/Crawlspace/Vented"))
          fnd_type = "VentedCrawlspace"
        else
          fnd_type = "UnventedCrawlspace"
        end
      end

      new_foundation = XMLHelper.add_element(new_foundations, "Foundation")
      XMLHelper.copy_element(new_foundation, orig_foundation, "SystemIdentifier")
      XMLHelper.copy_element(new_foundation, orig_foundation, "FoundationType")

      # FrameFloor
      if ["UnconditionedBasement", "VentedCrawlspace", "UnventedCrawlspace"].include? fnd_type
        floor_r_cavity = Integer(XMLHelper.get_value(orig_foundation, "FrameFloor/Insulation/Layer[InstallationType='cavity']/NominalRValue"))

        floor_r = get_floor_assembly_r(floor_r_cavity)

        new_framefloor = XMLHelper.add_element(new_foundation, "FrameFloor")
        XMLHelper.copy_element(new_framefloor, orig_foundation, "FrameFloor/SystemIdentifier")
        XMLHelper.copy_element(new_framefloor, "Area")
        new_framefloor_ins = XMLHelper.add_element(new_framefloor, "Insulation")
        XMLHelper.copy_element(new_framefloor_ins, orig_foundation, "FrameFloor/Insulation/SystemIdentifier")
        XMLHelper.add_element(new_framefloor_ins, "AssemblyEffectiveRValue", floor_r)
        extension = XMLHelper.add_element(new_framefloor, "extension")
        XMLHelper.add_element(extension, "ExteriorAdjacentTo", "living space")
      end

      # FoundationWall
      if ["UnconditionedBasement", "ConditionedBasement", "VentedCrawlspace", "UnventedCrawlspace"].include? fnd_type
        wall_r = 10 # FIXME: Hard-coded

        new_fndwall = XMLHelper.add_element(new_foundation, "FoundationWall")
        XMLHelper.copy_element(new_fndwall, orig_foundation, "FoundationWall/SystemIdentifier")
        XMLHelper.add_element(new_fndwall, "Height", @ceil_height) # FIXME: Verify
        XMLHelper.add_element(new_fndwall, "Area", @ceil_height * @bldg_perimeter) # FIXME: Verify
        XMLHelper.add_element(new_fndwall, "Thickness", 8) # FIXME: Verify
        XMLHelper.add_element(new_fndwall, "DepthBelowGrade", @ceil_height) # FIXME: Verify
        new_fndwall_ins = XMLHelper.add_element(new_fndwall, "Insulation")
        XMLHelper.copy_element(new_fndwall_ins, orig_foundation, "FoundationWall/Insulation/SystemIdentifier")
        XMLHelper.add_element(new_fndwall_ins, "AssemblyEffectiveRValue", wall_r)
        extension = XMLHelper.add_element(new_fndwall, "extension")
        XMLHelper.add_element(extension, "ExteriorAdjacentTo", "ground")
      end

      # Slab
      if fnd_type == "SlabOnGrade"
        slab_perim_r = Integer(XMLHelper.get_value(orig_foundation, "Slab/PerimeterInsulation/Layer[InstallationType='continuous']/NominalRValue"))
        slab_area = XMLHelper.get_value(orig_foundation, "Slab/Area")
        fnd_id = orig_foundation.elements["SystemIdentifier"].attributes["id"]
        slab_id = orig_foundation.elements["Slab/SystemIdentifier"].attributes["id"]
        slab_perim_id = orig_foundation.elements["Slab/PerimeterInsulation/SystemIdentifier"].attributes["id"]
        slab_under_id = "#{fnd_id}_slab_under_insulation"
      else
        slab_perim_r = 0
        slab_area = Float(XMLHelper.get_value(orig_foundation, "FrameFloor/Area"))
        fnd_id = orig_foundation.elements["SystemIdentifier"].attributes["id"]
        slab_id = "#{fnd_id}_slab"
        slab_perim_id = "#{fnd_id}_slab_perim_insulation"
        slab_under_id = "#{fnd_id}_slab_under_insulation"
      end
      new_slab = XMLHelper.add_element(new_foundation, "Slab")
      sys_id = XMLHelper.add_element(new_slab, "SystemIdentifier")
      XMLHelper.add_attribute(sys_id, "id", slab_id)
      XMLHelper.add_element(new_slab, "Area", slab_area)
      XMLHelper.add_element(new_slab, "Thickness", 4) # FIXME: Verify
      XMLHelper.add_element(new_slab, "ExposedPerimeter", @bldg_perimeter) # FIXME: Verify
      XMLHelper.add_element(new_slab, "PerimeterInsulationDepth", 1) # FIXME: Hard-coded
      XMLHelper.add_element(new_slab, "UnderSlabInsulationWidth", 0) # FIXME: Verify
      XMLHelper.add_element(new_slab, "DepthBelowGrade", 0) # FIXME: Verify
      new_slab_perim_ins = XMLHelper.add_element(new_slab, "PerimeterInsulation")
      new_slab_perim_sys_id = XMLHelper.add_element(new_slab_perim_ins, "SystemIdentifier")
      XMLHelper.add_attribute(new_slab_perim_sys_id, "id", slab_perim_id)
      new_slab_perim_layer = XMLHelper.add_element(new_slab_perim_ins, "Layer")
      XMLHelper.add_element(new_slab_perim_layer, "InstallationType", "continuous")
      XMLHelper.add_element(new_slab_perim_layer, "NominalRValue", slab_perim_r)
      new_slab_under_ins = XMLHelper.add_element(new_slab, "UnderSlabInsulation")
      new_slab_under_sys_id = XMLHelper.add_element(new_slab_under_ins, "SystemIdentifier")
      XMLHelper.add_attribute(new_slab_under_sys_id, "id", slab_under_id)
      new_slab_under_layer = XMLHelper.add_element(new_slab_under_ins, "Layer")
      XMLHelper.add_element(new_slab_under_layer, "InstallationType", "continuous")
      XMLHelper.add_element(new_slab_under_layer, "NominalRValue", 0)
      extension = XMLHelper.add_element(new_slab, "extension")
      XMLHelper.add_element(extension, "CarpetFraction", 0.5) # FIXME: Hard-coded
      XMLHelper.add_element(extension, "CarpetRValue", 2) # FIXME: Hard-coded

      # Uses ERI Reference Home for vented crawlspace specific leakage area
    end
  end

  def self.set_enclosure_rim_joists(new_enclosure, orig_details)
    # No rim joists
  end

  def self.set_enclosure_walls(new_enclosure, orig_details)
    new_walls = XMLHelper.add_element(new_enclosure, "Walls")

    orig_details.elements.each("Enclosure/Walls/Wall") do |orig_wall|
      wall_type = orig_wall.elements["WallType"].elements[1].name
      wall_orient = XMLHelper.get_value(orig_wall, "Orientation")

      if wall_type == "WoodStud"
        wall_siding = XMLHelper.get_value(orig_wall, "Siding")
        wall_r_cavity = Integer(XMLHelper.get_value(orig_wall, "Insulation/Layer[InstallationType='cavity']/NominalRValue"))
        wall_r_cont = XMLHelper.get_value(orig_wall, "Insulation/Layer[InstallationType='continuous']/NominalRValue").to_i
        wall_ove = Boolean(XMLHelper.get_value(orig_wall, "OptimumValueEngineering"))

        wall_r = get_wood_stud_wall_assembly_r(wall_r_cavity, wall_r_cont, wall_siding, wall_ove)
      elsif wall_type == "StructuralBrick"
        wall_r_cavity = Integer(XMLHelper.get_value(orig_wall, "Insulation/Layer[InstallationType='cavity']/NominalRValue"))

        wall_r = get_structural_block_wall_assembly_r(wall_r_cavity)
      elsif wall_type == "ConcreteMasonryUnit"
        wall_siding = XMLHelper.get_value(orig_wall, "Siding")
        wall_r_cavity = Integer(XMLHelper.get_value(orig_wall, "Insulation/Layer[InstallationType='cavity']/NominalRValue"))

        wall_r = get_concrete_block_wall_assembly_r(wall_r_cavity, wall_siding)
      elsif wall_type == "StrawBale"
        wall_siding = XMLHelper.get_value(orig_wall, "Siding")

        wall_r = get_straw_bale_wall_assembly_r(wall_siding)
      end

      new_wall = XMLHelper.add_element(new_walls, "Wall")
      XMLHelper.copy_element(new_wall, orig_wall, "SystemIdentifier")
      XMLHelper.copy_element(new_wall, orig_wall, "WallType")
      if @bldg_orient == wall_orient or @bldg_orient == reverse_orientation(wall_orient)
        XMLHelper.add_element(new_wall, "Area", @ceil_height * @bldg_width) # FIXME: Verify
      else
        XMLHelper.add_element(new_wall, "Area", @ceil_height * @bldg_length) # FIXME: Verify
      end
      XMLHelper.add_element(new_wall, "SolarAbsorptance", 0) # FIXME: Hard-coded
      XMLHelper.add_element(new_wall, "Emittance", 0) # FIXME: Hard-coded
      new_wall_ins = XMLHelper.add_element(new_wall, "Insulation")
      XMLHelper.copy_element(new_wall_ins, orig_wall, "Insulation/SystemIdentifier")
      XMLHelper.add_element(new_wall_ins, "AssemblyEffectiveRValue", wall_r)
      wall_ext = XMLHelper.add_element(new_wall, "extension")
      XMLHelper.add_element(wall_ext, "InteriorAdjacentTo", "living space")
      XMLHelper.add_element(wall_ext, "ExteriorAdjacentTo", "ambient")
    end
  end

  def self.set_enclosure_windows(new_enclosure, orig_details)
    new_windows = XMLHelper.add_element(new_enclosure, "Windows")

    orig_details.elements.each("Enclosure/Windows/Window") do |orig_window|
      orig_wall = get_attached(orig_window.elements["AttachedToWall"].attributes["idref"], orig_details, "Enclosure/Walls/Wall")
      win_orient = XMLHelper.get_value(orig_wall, "Orientation")
      win_ufactor = XMLHelper.get_value(orig_window, "UFactor")

      if not win_ufactor.nil?
        win_ufactor = Float(win_ufactor)
        win_shgc = Float(XMLHelper.get_value(orig_window, "SHGC"))
      else
        win_frame_type = orig_window.elements["FrameType"].elements[1].name
        if win_frame_type == "Aluminum" and Boolean(XMLHelper.get_value(orig_window, "FrameType/Aluminum/ThermalBreak"))
          win_frame_type += "ThermalBreak"
        end
        win_glass_layers = XMLHelper.get_value(orig_window, "GlassLayers")
        win_glass_type = XMLHelper.get_value(orig_window, "GlassType")
        win_gas_fill = XMLHelper.get_value(orig_window, "GasFill")

        win_ufactor, win_shgc = get_window_ufactor_shgc(win_frame_type, win_glass_layers, win_glass_type, win_gas_fill)
      end

      new_window = XMLHelper.add_element(new_windows, "Window")
      XMLHelper.copy_element(new_window, orig_window, "SystemIdentifier")
      XMLHelper.copy_element(new_window, orig_window, "Area")
      XMLHelper.add_element(new_window, "Azimuth", orientation_to_azimuth(win_orient))
      XMLHelper.add_element(new_window, "UFactor", win_ufactor)
      XMLHelper.add_element(new_window, "SHGC", win_shgc)
      # No overhangs
      XMLHelper.copy_element(new_window, orig_window, "AttachedToWall")
      # Uses ERI Reference Home for interior shading
    end
  end

  def self.set_enclosure_skylights(new_enclosure, orig_details)
    return if not XMLHelper.has_element(new_enclosure, "Skylights")

    new_skylights = XMLHelper.add_element(new_enclosure, "Skylights")

    orig_details.elements.each("Enclosure/Skylights/Skylight") do |orig_skylight|
      sky_orient = XMLHelper.get_value(orig_skylight, "Orientation")
      sky_ufactor = XMLHelper.get_value(orig_skylight, "UFactor")

      if not sky_ufactor.nil?
        sky_ufactor = Float(sky_ufactor)
        sky_shgc = Float(XMLHelper.get_value(orig_skylight, "SHGC"))
      else
        sky_frame_type = orig_skylight.elements["FrameType"].elements[1].name
        if sky_frame_type == "Aluminum" and Boolean(XMLHelper.get_value(orig_skylight, "FrameType/Aluminum/ThermalBreak"))
          sky_frame_type += "ThermalBreak"
        end
        sky_glass_layers = XMLHelper.get_value(orig_skylight, "GlassLayers")
        sky_glass_type = XMLHelper.get_value(orig_skylight, "GlassType")
        sky_gas_fill = XMLHelper.get_value(orig_skylight, "GasFill")

        sky_ufactor, sky_shgc = get_skylight_ufactor_shgc(sky_frame_type, sky_glass_layers, sky_glass_type, sky_gas_fill)
      end

      new_skylight = XMLHelper.add_element(new_skylights, "Skylight")
      XMLHelper.copy_element(new_skylight, orig_skylight, "SystemIdentifier")
      XMLHelper.copy_element(new_skylight, orig_skylight, "Area")
      XMLHelper.add_element(new_skylight, "Azimuth", orientation_to_azimuth(sky_orient))
      XMLHelper.add_element(new_skylight, "UFactor", sky_ufactor)
      XMLHelper.add_element(new_skylight, "SHGC", sky_shgc)
      # No overhangs
      XMLHelper.copy_element(new_skylight, orig_skylight, "AttachedToRoof")
      # Uses ERI Reference Home for interior shading
    end
  end

  def self.set_enclosure_doors(new_enclosure, orig_details)
    new_doors = XMLHelper.add_element(new_enclosure, "Doors")

    front_wall = nil
    orig_details.elements.each("Enclosure/Walls/Wall") do |wall|
      next if XMLHelper.get_value(wall, "Orientation") != @bldg_orient

      front_wall = wall
      break
    end

    new_door = XMLHelper.add_element(new_doors, "Door")
    sys_id = XMLHelper.add_element(new_door, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Door")
    attwall = XMLHelper.add_element(new_door, "AttachedToWall")
    XMLHelper.add_attribute(attwall, "idref", front_wall.elements["SystemIdentifier"].attributes["id"])
    # Uses ERI Reference Home for Area
    XMLHelper.add_element(new_door, "Azimuth", orientation_to_azimuth(@bldg_orient))
    # Uses ERI Reference Home for RValue
  end

  def self.set_systems_hvac(new_systems, orig_details)
    new_hvac = XMLHelper.add_element(new_systems, "HVAC")
    new_hvac_plant = XMLHelper.add_element(new_hvac, "HVACPlant")

    # HeatingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatingSystem") do |orig_heating|
      hvac_type = orig_heating.elements["HeatingSystemType"].elements[1].name
      hvac_fuel = XMLHelper.get_value(orig_heating, "HeatingSystemFuel")

      new_heating = XMLHelper.add_element(new_hvac_plant, "HeatingSystem")
      XMLHelper.copy_element(new_heating, orig_heating, "SystemIdentifier")
      XMLHelper.copy_element(new_heating, orig_heating, "DistributionSystem")
      XMLHelper.copy_element(new_heating, orig_heating, "HeatingSystemType")
      XMLHelper.add_element(new_heating, "HeatingSystemFuel", hvac_fuel)
      XMLHelper.add_element(new_heating, "HeatingCapacity", -1) # Use Manual J auto-sizing
      heat_eff = XMLHelper.add_element(new_heating, "AnnualHeatingEfficiency")
      if ["Furnace", "WallFurnace", "Boiler"].include? hvac_type
        hvac_year = XMLHelper.get_value(orig_heating, "YearInstalled")
        hvac_afue = XMLHelper.get_value(orig_heating, "AnnualHeatingEfficiency[Units='AFUE']/Value")

        if not hvac_year.nil?
          if ["Furnace", "WallFurnace"].include? hvac_type
            hvac_afue = get_default_furnace_afue(Integer(hvac_year), hvac_type, hvac_fuel)
          else
            hvac_afue = get_default_boiler_afue(Integer(hvac_year), hvac_type, hvac_fuel)
          end
        else
          hvac_afue = Float(hvac_afue)
        end

        XMLHelper.add_element(heat_eff, "Units", "AFUE")
        XMLHelper.add_element(heat_eff, "Value", hvac_afue)
      else
        # FIXME: Verify
        # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/heating-and-cooling-equipment/heating-and-cooling-equipment-efficiencies
        if hvac_type == "ElectricResistance"
          XMLHelper.add_element(heat_eff, "Units", "Percent")
          XMLHelper.add_element(heat_eff, "Value", 0.98)
        elsif hvac_type == "Stove"
          XMLHelper.add_element(heat_eff, "Units", "Percent")
          if hvac_fuel == "wood"
            XMLHelper.add_element(heat_eff, "Value", 0.60)
          elsif hvac_fuel == "wood pellets"
            XMLHelper.add_element(heat_eff, "Value", 0.78)
          end
        end
      end
      XMLHelper.copy_element(new_heating, orig_heating, "FractionHeatLoadServed")
    end

    # CoolingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/CoolingSystem") do |orig_cooling|
      hvac_type = XMLHelper.get_value(orig_cooling, "CoolingSystemType")

      new_cooling = XMLHelper.add_element(new_hvac_plant, "CoolingSystem")
      XMLHelper.copy_element(new_cooling, orig_cooling, "SystemIdentifier")
      XMLHelper.copy_element(new_cooling, orig_cooling, "DistributionSystem")
      XMLHelper.add_element(new_cooling, "CoolingSystemType", hvac_type)
      XMLHelper.add_element(new_cooling, "CoolingSystemFuel", "electricity")
      XMLHelper.add_element(new_cooling, "CoolingCapacity", -1) # Use Manual J auto-sizing
      XMLHelper.copy_element(new_cooling, orig_cooling, "FractionCoolLoadServed")
      if hvac_type == "central air conditioning"
        hvac_year = XMLHelper.get_value(orig_cooling, "YearInstalled")
        hvac_seer = XMLHelper.get_value(orig_cooling, "AnnualCoolingEfficiency[Units='SEER']/Value")

        if not hvac_year.nil?
          hvac_seer = get_default_central_ac_seer(Integer(hvac_year))
        else
          hvac_seer = Float(hvac_seer)
        end

        cool_eff = XMLHelper.add_element(new_cooling, "AnnualCoolingEfficiency")
        XMLHelper.add_element(cool_eff, "Units", "SEER")
        XMLHelper.add_element(cool_eff, "Value", hvac_seer)
      elsif hvac_type == "room air conditioning"
        hvac_year = XMLHelper.get_value(orig_cooling, "YearInstalled")
        hvac_eer = XMLHelper.get_value(orig_cooling, "AnnualCoolingEfficiency[Units='EER']/Value")

        if not hvac_year.nil?
          hvac_eer = get_default_room_ac_eer(Integer(hvac_year))
        else
          hvac_eer = Float(hvac_eer)
        end

        cool_eff = XMLHelper.add_element(new_cooling, "AnnualCoolingEfficiency")
        XMLHelper.add_element(cool_eff, "Units", "EER")
        XMLHelper.add_element(cool_eff, "Value", hvac_eer)
      end
    end

    # HeatPump
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatPump") do |orig_hp|
      hvac_type = XMLHelper.get_value(orig_hp, "HeatPumpType")

      new_hp = XMLHelper.add_element(new_hvac_plant, "HeatPump")
      XMLHelper.copy_element(new_hp, orig_hp, "SystemIdentifier")
      XMLHelper.copy_element(new_hp, orig_hp, "DistributionSystem")
      XMLHelper.add_element(new_hp, "HeatPumpType", hvac_type)
      XMLHelper.add_element(new_hp, "HeatingCapacity", -1) # Use Manual J auto-sizing
      XMLHelper.add_element(new_hp, "CoolingCapacity", -1) # Use Manual J auto-sizing
      XMLHelper.copy_element(new_hp, orig_hp, "FractionHeatLoadServed")
      XMLHelper.copy_element(new_hp, orig_hp, "FractionCoolLoadServed")
      cool_eff = XMLHelper.add_element(new_hp, "AnnualCoolingEfficiency")
      heat_eff = XMLHelper.add_element(new_hp, "AnnualHeatingEfficiency")
      if ["air-to-air", "mini-split"].include? hvac_type
        hvac_year = XMLHelper.get_value(orig_hp, "YearInstalled")
        hvac_seer = XMLHelper.get_value(orig_hp, "AnnualCoolingEfficiency[Units='SEER']/Value")
        hvac_hspf = XMLHelper.get_value(orig_hp, "AnnualHeatingEfficiency[Units='HSPF']/Value")

        if not hvac_year.nil?
          hvac_seer, hvac_hspf = get_default_ashp_seer_hspf(Integer(hvac_year))
        else
          hvac_seer = Float(hvac_seer)
          hvac_hspf = Float(hvac_hspf)
        end

        XMLHelper.add_element(cool_eff, "Units", "SEER")
        XMLHelper.add_element(cool_eff, "Value", hvac_seer)
        XMLHelper.add_element(heat_eff, "Units", "HSPF")
        XMLHelper.add_element(heat_eff, "Value", hvac_hspf)
      elsif hvac_type == "ground-to-air"
        hvac_year = XMLHelper.get_value(orig_hp, "YearInstalled")
        hvac_eer = XMLHelper.get_value(orig_hp, "AnnualCoolingEfficiency[Units='EER']/Value")
        hvac_cop = XMLHelper.get_value(orig_hp, "AnnualHeatingEfficiency[Units='COP']/Value")

        if not hvac_year.nil?
          hvac_eer, hvac_cop = get_default_gshp_eer_cop(Integer(hvac_year))
        else
          hvac_eer = Float(hvac_eer)
          hvac_cop = Float(hvac_cop)
        end

        XMLHelper.add_element(cool_eff, "Units", "EER")
        XMLHelper.add_element(cool_eff, "Value", hvac_eer)
        XMLHelper.add_element(heat_eff, "Units", "COP")
        XMLHelper.add_element(heat_eff, "Value", hvac_cop)
      end
    end

    # HVACControl
    new_hvac_control = XMLHelper.add_element(new_hvac, "HVACControl")
    sys_id = XMLHelper.add_element(new_hvac_control, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "HVACControl")
    XMLHelper.add_element(new_hvac_control, "ControlType", "manual thermostat")

    # HVACDistribution
    orig_details.elements.each("Systems/HVAC/HVACDistribution") do |orig_dist|
      ducts_sealed = Boolean(XMLHelper.get_value(orig_dist, "HVACDistributionImprovement/DuctSystemSealed"))

      # Leakage fraction of total air handler flow
      # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/thermal-distribution-efficiency/thermal-distribution-efficiency
      # FIXME: Verify. Total or to the outside?
      # FIXME: Or 10%/25%? See https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI/edit#gid=1042407563
      if ducts_sealed
        leakage_frac = 0.03
      else
        leakage_frac = 0.15
      end

      # FIXME: Verify
      # Surface areas outside conditioned space
      # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/thermal-distribution-efficiency/thermal-distribution-efficiency
      supply_duct_area = 0.27 * @cfa
      return_duct_area = 0.05 * @nfl * @cfa

      new_dist = XMLHelper.add_element(new_hvac, "HVACDistribution")
      XMLHelper.copy_element(new_dist, orig_dist, "SystemIdentifier")
      new_air_dist = XMLHelper.add_element(new_dist, "DistributionSystemType/AirDistribution")

      # Supply duct leakage
      new_supply_measurement = XMLHelper.add_element(new_air_dist, "DuctLeakageMeasurement")
      XMLHelper.add_element(new_supply_measurement, "DuctType", "supply")
      new_supply_leakage = XMLHelper.add_element(new_supply_measurement, "DuctLeakage")
      XMLHelper.add_element(new_supply_leakage, "Units", "CFM25")
      XMLHelper.add_element(new_supply_leakage, "Value", 100) # FIXME: Hard-coded
      XMLHelper.add_element(new_supply_leakage, "TotalOrToOutside", "to outside") # FIXME: Hard-coded

      # Return duct leakage
      new_return_measurement = XMLHelper.add_element(new_air_dist, "DuctLeakageMeasurement")
      XMLHelper.add_element(new_return_measurement, "DuctType", "return")
      new_return_leakage = XMLHelper.add_element(new_return_measurement, "DuctLeakage")
      XMLHelper.add_element(new_return_leakage, "Units", "CFM25")
      XMLHelper.add_element(new_return_leakage, "Value", 100) # FIXME: Hard-coded
      XMLHelper.add_element(new_return_leakage, "TotalOrToOutside", "to outside") # FIXME: Hard-coded

      orig_dist.elements.each("DistributionSystemType/AirDistribution/Ducts") do |orig_duct|
        duct_location = XMLHelper.get_value(orig_duct, "DuctLocation")
        duct_frac_area = Float(XMLHelper.get_value(orig_duct, "FractionDuctArea"))
        duct_insulated = Boolean(XMLHelper.get_value(orig_duct, "extension/hescore_ducts_insulated"))

        next if duct_location == "conditioned space"

        # FIXME: Verify. Includes air film?
        if duct_insulated
          duct_rvalue = 6
        else
          duct_rvalue = 0
        end

        # Supply duct
        new_supply_duct = XMLHelper.add_element(new_air_dist, "Ducts")
        XMLHelper.add_element(new_supply_duct, "DuctType", "supply")
        XMLHelper.add_element(new_supply_duct, "DuctInsulationRValue", duct_rvalue)
        XMLHelper.add_element(new_supply_duct, "DuctLocation", duct_location)
        XMLHelper.add_element(new_supply_duct, "DuctSurfaceArea", duct_frac_area * supply_duct_area)

        # Return duct
        new_return_duct = XMLHelper.add_element(new_air_dist, "Ducts")
        XMLHelper.add_element(new_return_duct, "DuctType", "return")
        XMLHelper.add_element(new_return_duct, "DuctInsulationRValue", duct_rvalue)
        XMLHelper.add_element(new_return_duct, "DuctLocation", duct_location)
        XMLHelper.add_element(new_return_duct, "DuctSurfaceArea", duct_frac_area * return_duct_area)
      end
    end
  end

  def self.set_systems_mechanical_ventilation(new_systems, orig_details)
    # No mechanical ventilation
  end

  def self.set_systems_water_heater(new_systems, orig_details)
    new_water_heating = XMLHelper.add_element(new_systems, "WaterHeating")

    orig_details.elements.each("Systems/WaterHeating/WaterHeatingSystem") do |orig_wh_sys|
      wh_year = XMLHelper.get_value(orig_wh_sys, "YearInstalled")
      wh_ef = XMLHelper.get_value(orig_wh_sys, "EnergyFactor")
      wh_fuel = XMLHelper.get_value(orig_wh_sys, "FuelType")
      wh_type = XMLHelper.get_value(orig_wh_sys, "WaterHeaterType")

      if not wh_year.nil?
        wh_ef = get_default_water_heater_ef(Integer(wh_year), wh_fuel)
      else
        wh_ef = Float(wh_ef)
      end

      new_wh_sys = XMLHelper.add_element(new_water_heating, "WaterHeatingSystem")
      XMLHelper.copy_element(new_wh_sys, orig_wh_sys, "SystemIdentifier")
      XMLHelper.add_element(new_wh_sys, "FuelType", wh_fuel)
      XMLHelper.add_element(new_wh_sys, "WaterHeaterType", wh_type)
      XMLHelper.add_element(new_wh_sys, "Location", "conditioned space") # FIXME: Verify
      XMLHelper.add_element(new_wh_sys, "TankVolume", get_default_water_heater_volume(wh_fuel))
      XMLHelper.add_element(new_wh_sys, "FractionDHWLoadServed", 1.0)
      if wh_type == "storage water heater"
        XMLHelper.add_element(new_wh_sys, "HeatingCapacity", get_default_water_heater_capacity(wh_fuel))
      end
      XMLHelper.add_element(new_wh_sys, "EnergyFactor", wh_ef)
      if wh_type == "storage water heater" and XMLHelper.get_value(orig_wh_sys, "FuelType") != "electricity"
        XMLHelper.add_element(new_wh_sys, "RecoveryEfficiency", get_default_water_heater_re(wh_fuel))
      end
    end
  end

  def self.set_systems_water_heating_use(new_systems, orig_details)
    new_water_heating = new_systems.elements["WaterHeating"]

    new_hw_dist = XMLHelper.add_element(new_water_heating, "HotWaterDistribution")
    sys_id = XMLHelper.add_element(new_hw_dist, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "HotWaterDistribution")
    XMLHelper.add_element(new_hw_dist, "SystemType/Standard") # FIXME: Verify
    XMLHelper.add_element(new_hw_dist, "PipeInsulation/PipeRValue", 0) # FIXME: Verify

    new_fixture = XMLHelper.add_element(new_water_heating, "WaterFixture")
    sys_id = XMLHelper.add_element(new_fixture, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "ShowerHead")
    XMLHelper.add_element(new_fixture, "WaterFixtureType", "shower head")
    XMLHelper.add_element(new_fixture, "LowFlow", false) # FIXME: Verify
  end

  def self.set_systems_photovoltaics(new_systems, orig_details)
    pv_power = XMLHelper.get_value(orig_details, "Systems/Photovoltaics/PVSystem/MaxPowerOutput")
    pv_num_panels = XMLHelper.get_value(orig_details, "Systems/Photovoltaics/PVSystem/extension/hescore_num_panels")
    pv_orientation = XMLHelper.get_value(orig_details, "Systems/Photovoltaics/PVSystem/ArrayOrientation")

    if not pv_power.nil?
      pv_power = Float(pv_power)
    else
      pv_power = 3000.0 # FIXME: Hard-coded
    end

    new_pvs = XMLHelper.add_element(new_systems, "Photovoltaics")
    new_pv = XMLHelper.add_element(new_pvs, "PVSystem")
    sys_id = XMLHelper.add_element(new_pv, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "PVSystem")
    XMLHelper.add_element(new_pv, "ModuleType", "standard") # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
    XMLHelper.add_element(new_pv, "ArrayType", "fixed roof mount") # FIXME: Verify. HEScore was using "fixed open rack"??
    XMLHelper.add_element(new_pv, "ArrayAzimuth", orientation_to_azimuth(pv_orientation))
    XMLHelper.add_element(new_pv, "ArrayTilt", 30) # FIXME: Verify. From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
    XMLHelper.add_element(new_pv, "MaxPowerOutput", pv_power)
    XMLHelper.add_element(new_pv, "InverterEfficiency", 0.96) # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
    XMLHelper.add_element(new_pv, "SystemLossesFraction", 0.14) # FIXME: Verify
  end

  def self.set_appliances_clothes_washer(new_appliances, orig_details)
    new_washer = XMLHelper.add_element(new_appliances, "ClothesWasher")
    sys_id = XMLHelper.add_element(new_washer, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "ClothesWasher")

    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_clothes_dryer(new_appliances, orig_details)
    new_dryer = XMLHelper.add_element(new_appliances, "ClothesDryer")
    sys_id = XMLHelper.add_element(new_dryer, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "ClothesDryer")
    XMLHelper.add_element(new_dryer, "FuelType", "electricity") # FIXME: Verify

    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_dishwasher(new_appliances, orig_details)
    new_dishwasher = XMLHelper.add_element(new_appliances, "Dishwasher")
    sys_id = XMLHelper.add_element(new_dishwasher, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Dishwasher")

    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_refrigerator(new_appliances, orig_details)
    new_fridge = XMLHelper.add_element(new_appliances, "Refrigerator")
    sys_id = XMLHelper.add_element(new_fridge, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Refrigerator")

    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_cooking_range_oven(new_appliances, orig_details)
    new_range = XMLHelper.add_element(new_appliances, "CookingRange")
    sys_id = XMLHelper.add_element(new_range, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "CookingRange")
    XMLHelper.add_element(new_range, "FuelType", "electricity") # FIXME: Verify

    new_oven = XMLHelper.add_element(new_appliances, "Oven")
    sys_id = XMLHelper.add_element(new_oven, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Oven")

    # Uses ERI Reference Home for performance
  end

  def self.set_lighting(new_lighting, orig_details)
    # Uses ERI Reference Home
  end

  def self.set_ceiling_fans(new_lighting, orig_details)
    # No ceiling fans
  end
end

def get_default_furnace_afue(year, fuel)
  # FIXME: Verify
  # TODO: Pull out methods and make available for ERI use case
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_afues = { "electricity" => [0.98, 0.98, 0.98, 0.98, 0.98, 0.98, 0.98, 0.98],
                    "natural gas" => [0.72, 0.72, 0.72, 0.72, 0.72, 0.76, 0.78, 0.78],
                    "propane" => [0.72, 0.72, 0.72, 0.72, 0.72, 0.76, 0.78, 0.78],
                    "fuel oil" => [0.60, 0.65, 0.72, 0.75, 0.80, 0.80, 0.80, 0.80] }[fuel]
  ending_years.zip(default_afues).each do |ending_year, default_afue|
    next if year > ending_year

    return default_afue
  end
  fail "Could not get default furnace AFUE for year '#{year}' and fuel '#{fuel}'"
end

def get_default_boiler_afue(year, fuel)
  # FIXME: Verify
  # TODO: Pull out methods and make available for ERI use case
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_afues = { "electricity" => [0.98, 0.98, 0.98, 0.98, 0.98, 0.98, 0.98, 0.98],
                    "natural gas" => [0.60, 0.60, 0.65, 0.65, 0.70, 0.77, 0.80, 0.80],
                    "propane" => [0.60, 0.60, 0.65, 0.65, 0.70, 0.77, 0.80, 0.80],
                    "fuel oil" => [0.60, 0.65, 0.72, 0.75, 0.80, 0.80, 0.80, 0.80] }[fuel]
  ending_years.zip(default_afues).each do |ending_year, default_afue|
    next if year > ending_year

    return default_afue
  end
  fail "Could not get default boiler AFUE for year '#{year}' and fuel '#{fuel}'"
end

def get_default_central_ac_seer(year)
  # FIXME: Verify
  # TODO: Pull out methods and make available for ERI use case
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_seers = [9.0, 9.0, 9.0, 9.0, 9.0, 9.40, 10.0, 13.0]
  ending_years.zip(default_seers).each do |ending_year, default_seer|
    next if year > ending_year

    return default_seer
  end
  fail "Could not get default central air conditioner SEER for year '#{year}'"
end

def get_default_room_ac_eer(year)
  # FIXME: Verify
  # TODO: Pull out methods and make available for ERI use case
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_eers = [8.0, 8.0, 8.0, 8.0, 8.0, 8.10, 8.5, 8.5]
  ending_years.zip(default_eers).each do |ending_year, default_eer|
    next if year > ending_year

    return default_eer
  end
  fail "Could not get default room air conditioner EER for year '#{year}'"
end

def get_default_ashp_seer_hspf(year)
  # FIXME: Verify
  # TODO: Pull out methods and make available for ERI use case
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_seers = [9.0, 9.0, 9.0, 9.0, 9.0, 9.40, 10.0, 13.0]
  default_hspfs = [6.5, 6.5, 6.5, 6.5, 6.5, 6.80, 6.80, 7.7]
  ending_years.zip(default_seers, default_hspfs).each do |ending_year, default_seer, default_hspf|
    next if year > ending_year

    return default_seer, default_hspf
  end
  fail "Could not get default air source heat pump SEER/HSPF for year '#{year}'"
end

def get_default_gshp_eer_cop(year)
  # FIXME: Verify
  # TODO: Pull out methods and make available for ERI use case
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_eers = [8.00, 8.00, 8.00, 11.00, 11.00, 12.00, 14.0, 13.4]
  default_cops = [2.30, 2.30, 2.30, 2.50, 2.60, 2.70, 3.00, 3.1]
  ending_years.zip(default_eers, default_cops).each do |ending_year, default_eer, default_cop|
    next if year > ending_year

    return default_eer, default_cop
  end
  fail "Could not get default ground source heat pump EER/COP for year '#{year}'"
end

def get_default_water_heater_ef(year, fuel)
  # FIXME: Verify
  # TODO: Pull out methods and make available for ERI use case
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_efs = { "electricity" => [0.86, 0.86, 0.86, 0.86, 0.86, 0.87, 0.88, 0.92],
                  "natural gas" => [0.50, 0.50, 0.50, 0.50, 0.55, 0.56, 0.56, 0.59],
                  "propane" => [0.50, 0.50, 0.50, 0.50, 0.55, 0.56, 0.56, 0.59],
                  "fuel oil" => [0.47, 0.47, 0.47, 0.48, 0.49, 0.54, 0.56, 0.51] }[fuel]
  ending_years.zip(defaults_efs).each do |ending_year, default_ef|
    next if year > ending_year

    return default_ef
  end
  fail "Could not get default water heater EF for year '#{year}' and fuel '#{fuel}'"
end

def get_default_water_heater_volume(fuel)
  # FIXME: Verify
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/water-heater-energy-consumption/user-inputs-to-the-water-heater-model
  val = { "electricity" => 50,
          "natural gas" => 40,
          "propane" => 40,
          "fuel oil" => 32 }[fuel]
  return val if not val.nil?

  fail "Could not get default water heater volume for fuel '#{fuel}'"
end

def get_default_water_heater_re(fuel)
  # FIXME: Verify
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/water-heater-energy-consumption/user-inputs-to-the-water-heater-model
  val = { "electricity" => 0.98,
          "natural gas" => 0.76,
          "propane" => 0.76,
          "fuel oil" => 0.76 }[fuel]
  return val if not val.nil?

  fail "Could not get default water heater RE for fuel '#{fuel}'"
end

def get_default_water_heater_capacity(fuel)
  # FIXME: Verify
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/water-heater-energy-consumption/user-inputs-to-the-water-heater-model
  val = { "electricity" => UnitConversions.convert(4.5, "kwh", "btu"),
          "natural gas" => 38000,
          "propane" => 38000,
          "fuel oil" => UnitConversions.convert(0.65, "gal", "btu", Constants.FuelTypeOil) }[fuel]
  return val if not val.nil?

  fail "Could not get default water heater capacity for fuel '#{fuel}'"
end

def get_wood_stud_wall_assembly_r(r_cavity, r_cont, siding, ove)
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  sidings = ["wood siding", "stucco", "vinyl siding", "aluminum siding", "brick veneer"]
  siding_index = sidings.index(siding)
  if r_cont == 0 and not ove
    val = { 0 => [4.6, 3.2, 3.8, 3.7, 4.7],
            3 => [7.0, 5.8, 6.3, 6.2, 7.1],
            7 => [9.7, 8.5, 9.0, 8.8, 9.8],
            11 => [11.5, 10.2, 10.8, 10.6, 11.6],
            13 => [12.5, 11.1, 11.6, 11.5, 12.5],
            15 => [13.3, 11.9, 12.5, 12.3, 13.3],
            19 => [16.9, 15.4, 16.1, 15.9, 16.9],
            21 => [17.5, 16.1, 16.9, 16.7, 17.9] }[r_cavity][siding_index]
  elsif r_cont == 5 and not ove
    val = { 11 => [16.7, 15.4, 15.9, 15.9, 16.9],
            13 => [17.9, 16.4, 16.9, 16.9, 17.9],
            15 => [18.5, 17.2, 17.9, 17.9, 18.9],
            19 => [22.2, 20.8, 21.3, 21.3, 22.2],
            21 => [22.7, 21.7, 22.2, 22.2, 23.3] }[r_cavity][siding_index]
  elsif r_cont == 0 and ove
    val = { 19 => [19.2, 17.9, 18.5, 18.2, 19.2],
            21 => [20.4, 18.9, 19.6, 19.6, 20.4],
            27 => [25.6, 24.4, 25.0, 24.4, 25.6],
            33 => [30.3, 29.4, 29.4, 29.4, 30.3],
            38 => [34.5, 33.3, 34.5, 34.5, 34.5] }[r_cavity][siding_index]
  elsif r_cont == 5 and ove
    val = { 19 => [24.4, 23.3, 23.8, 23.3, 24.4],
            21 => [25.6, 24.4, 25.0, 25.0, 25.6] }[r_cavity][siding_index]
  end
  return val if not val.nil?

  fail "Could not get default wood stud wall assembly R-value for R-cavity '#{r_cavity}' and R-cont '#{r_cont}' and siding '#{siding}' and ove '#{ove}'"
end

def get_structural_block_wall_assembly_r(r_cavity)
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  val = { 0 => 2.9,
          5 => 7.9,
          10 => 12.8 }[r_cavity]
  return val if not val.nil?

  fail "Could not get default structural block wall assembly R-value for R-cavity '#{r_cavity}'"
end

def get_concrete_block_wall_assembly_r(r_cavity, siding)
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  sidings = ["stucco", "brick veneer", nil]
  siding_index = sidings.index(siding)
  val = { 0 => [4.1, 5.6, 4.0],
          3 => [5.7, 7.2, 5.6],
          6 => [8.5, 10.0, 8.3] }[r_cavity][siding_index]
  return val if not val.nil?

  fail "Could not get default concrete block wall assembly R-value for R-cavity '#{r_cavity}' and siding '#{siding}'"
end

def get_straw_bale_wall_assembly_r(siding)
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  return 58.8 if siding == "stucco"

  fail "Could not get default straw bale assembly R-value for siding '#{siding}'"
end

def get_roof_assembly_r(r_cavity, r_cont, material, has_radiant_barrier)
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/roof-construction-types
  materials = ["asphalt or fiberglass shingles",
               "wood shingles or shakes",
               "slate or tile shingles",
               "concrete",
               "plastic/rubber/synthetic sheeting"]
  material_index = materials.index(material)
  if r_cont == 0 and not has_radiant_barrier
    val = { 0 => [3.3, 4.0, 3.4, 3.4, 3.7],
            11 => [13.5, 14.3, 13.7, 13.5, 13.9],
            13 => [14.9, 15.6, 15.2, 14.9, 15.4],
            15 => [16.4, 16.9, 16.4, 16.4, 16.7],
            19 => [20.0, 20.8, 20.4, 20.4, 20.4],
            21 => [21.7, 22.2, 21.7, 21.3, 21.7],
            27 => [nil, 27.8, 27.0, 27.0, 27.0] }[r_cavity][material_index]
  elsif r_cont == 0 and has_radiant_barrier
    val = { 0 => [5.6, 6.3, 5.7, 5.6, 6.0] }[r_cavity][material_index]
  elsif r_cont == 5 and not has_radiant_barrier
    val = { 0 => [8.3, 9.0, 8.4, 8.3, 8.7],
            11 => [18.5, 19.2, 18.5, 18.5, 18.9],
            13 => [20.0, 20.8, 20.0, 20.0, 20.4],
            15 => [21.3, 22.2, 21.3, 21.3, 21.7],
            19 => [nil, 25.6, 25.6, 25.0, 25.6],
            21 => [nil, 27.0, 27.0, 26.3, 27.0] }[r_cavity][material_index]
  end
  return val if not val.nil?

  fail "Could not get default roof assembly R-value for R-cavity '#{r_cavity}' and R-cont '#{r_cont}' and material '#{material}' and radiant barrier '#{has_radiant_barrier}'"
end

def get_ceiling_assembly_r(r_cavity)
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/ceiling-construction-types
  val = { 0 => 2.2,
          3 => 5.0,
          6 => 7.6,
          9 => 10.0,
          11 => 10.9,
          19 => 19.2,
          21 => 21.3,
          25 => 25.6,
          30 => 30.3,
          38 => 38.5,
          44 => 43.5,
          49 => 50.0,
          60 => 58.8 }[r_cavity]
  return val if not val.nil?

  fail "Could not get default ceiling assembly R-value for R-cavity '#{r_cavity}'"
end

def get_floor_assembly_r(r_cavity)
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/floor-construction-types
  val = { 0 => 5.9,
          11 => 15.6,
          13 => 17.2,
          15 => 18.5,
          19 => 22.2,
          21 => 23.8,
          25 => 27.0,
          30 => 31.3,
          38 => 37.0 }[r_cavity]
  return val if not val.nil?

  fail "Could not get default floor assembly R-value for R-cavity '#{r_cavity}'"
end

def get_window_ufactor_shgc(frame_type, glass_layers, glass_type, gas_fill)
  # FIXME: Verify
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/window-construction-types/window-skylight-construction-types
  key = [frame_type, glass_layers, glass_type, gas_fill]
  vals = { ["Aluminum", "single-pane", nil, nil] => [1.19, 0.78],
           ["Wood", "single-pane", nil, nil] => [0.92, 0.72],
           ["Aluminum", "single-pane", "tinted/reflective", nil] => [1.19, 0.67],
           ["Wood", "single-pane", nil, nil] => [0.92, 0.72], # FIXME: Same as 2nd item?
           ["Aluminum", "double-pane", nil, "air"] => [0.77, 0.7],
           ["AluminumThermalBreak", "double-pane", nil, "air"] => [0.57, 0.67],
           ["Wood", "double-pane", nil, "air"] => [0.52, 0.64],
           ["Aluminum", "double-pane", "tinted/reflective", "air"] => [0.75, 0.58],
           ["AluminumThermalBreak", "double-pane", "tinted/reflective", "air"] => [0.55, 0.55],
           ["Wood", "double-pane", "tinted/reflective", "air"] => [0.5, 0.53],
           ["Wood", "double-pane", "low-e", "air"] => [0.36, 0.56],
           ["AluminumThermalBreak", "double-pane", "low-e", "argon"] => [0.37, 0.59],
           ["Wood", "double-pane", "low-e", "argon"] => [0.33, 0.57],
           ["Aluminum", "double-pane", "reflective", "air"] => [0.59, 0.28],
           ["AluminumThermalBreak", "double-pane", "reflective", "argon"] => [0.4, 0.25], # FIXME: Not labeled as argon, but should be? See https://docs.google.com/spreadsheets/d/1Tr8ajqz-p-BhS9cRx8H3566k8C5-OD68m-tiRtE5Wvg/edit#gid=2115766420
           ["Wood", "double-pane", "reflective", "argon"] => [0.35, 0.24], # FIXME: Not labeled as argon, but should be? See https://docs.google.com/spreadsheets/d/1Tr8ajqz-p-BhS9cRx8H3566k8C5-OD68m-tiRtE5Wvg/edit#gid=2115766420
           ["Wood", "double-pane", "reflective", "argon"] => [0.26, 0.23],
           ["Wood", "triple-pane", "low-e", "argon"] => [0.17, 0.21] }[key]
  return vals if not vals.nil?

  fail "Could not get default window U/SHGC for frame type '#{frame_type}' and glass layers '#{glass_layers}' and glass type '#{glass_type}' and gas fill '#{gas_fill}'"
end

def get_skylight_ufactor_shgc(frame_type, glass_layers, glass_type, gas_fill)
  # FIXME: Verify
  # FIXME: Table says 20 deg but Scoring Tool roof pitch is 30 deg?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/window-construction-types/window-skylight-construction-types
  key = [frame_type, glass_layers, glass_type, gas_fill]
  vals = { ["Aluminum", "single-pane", nil, nil] => [1.35, 0.78],
           ["Wood", "single-pane", nil, nil] => [1.08, 0.72],
           ["Aluminum", "single-pane", "tinted/reflective", nil] => [1.35, 0.68],
           ["Wood", "single-pane", nil, nil] => [1.08, 0.72], # FIXME: Same as 2nd item?
           ["Aluminum", "double-pane", nil, "air"] => [0.82, 0.7],
           ["AluminumThermalBreak", "double-pane", nil, "air"] => [0.62, 0.67],
           ["Wood", "double-pane", nil, "air"] => [0.57, 0.64],
           ["Aluminum", "double-pane", "tinted/reflective", "air"] => [0.83, 0.58],
           ["AluminumThermalBreak", "double-pane", "tinted/reflective", "air"] => [0.63, 0.56],
           ["Wood", "double-pane", "tinted/reflective", "air"] => [0.58, 0.53],
           ["Wood", "double-pane", "low-e", "air"] => [0.47, 0.57],
           ["AluminumThermalBreak", "double-pane", "low-e", "argon"] => [0.47, 0.6],
           ["Wood", "double-pane", "low-e", "argon"] => [0.42, 0.57],
           ["Aluminum", "double-pane", "reflective", "air"] => [0.71, 0.28],
           ["AluminumThermalBreak", "double-pane", "reflective", "argon"] => [0.51, 0.26], # FIXME: Not labeled as argon, but should be? See https://docs.google.com/spreadsheets/d/1Tr8ajqz-p-BhS9cRx8H3566k8C5-OD68m-tiRtE5Wvg/edit#gid=2115766420
           ["Wood", "double-pane", "reflective", "argon"] => [0.46, 0.24], # FIXME: Not labeled as argon, but should be? See https://docs.google.com/spreadsheets/d/1Tr8ajqz-p-BhS9cRx8H3566k8C5-OD68m-tiRtE5Wvg/edit#gid=2115766420
           ["Wood", "double-pane", "reflective", "argon"] => [0.36, 0.24],
           ["Wood", "triple-pane", "low-e", "argon"] => [0.2, 0.21] }[key]
  return vals if not vals.nil?

  fail "Could not get default skylight U/SHGC for frame type '#{frame_type}' and glass layers '#{glass_layers}' and glass type '#{glass_type}' and gas fill '#{gas_fill}'"
end

def orientation_to_azimuth(orientation)
  return { "northeast" => 45,
           "east" => 90,
           "southeast" => 135,
           "south" => 180,
           "southwest" => 225,
           "west" => 270,
           "northwest" => 315,
           "north" => 0 }[orientation]
end

def get_attached(attached_name, orig_details, search_in)
  orig_details.elements.each(search_in) do |other_element|
    next if attached_name != other_element.elements["SystemIdentifier"].attributes["id"]

    return other_element
  end
  fail "Could not find attached element for '#{attached_name}'."
end

def reverse_orientation(orientation)
  reverse = orientation
  if reverse.include? "north"
    reverse = reverse.gsub("north", "south")
  else
    reverse = reverse.gsub("south", "north")
  end
  if reverse.include? "east"
    reverse = reverse.gsub("east", "west")
  else
    reverse = reverse.gsub("west", "east")
  end
  return reverse
end
