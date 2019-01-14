require_relative "../../HPXMLtoOpenStudio/resources/airflow"
require_relative "../../HPXMLtoOpenStudio/resources/geometry"
require_relative "../../HPXMLtoOpenStudio/resources/xmlhelper"
require_relative "../../HPXMLtoOpenStudio/resources/hpxml"

class HEScoreRuleset
  def self.apply_ruleset(hpxml_doc)
    hpxml_doc.elements["/HPXML"].attributes["schemaVersion"] = '3.0'

    # Add ERI version
    software_info = hpxml_doc.elements["/HPXML/SoftwareInfo"]
    XMLHelper.add_element(software_info, "extension/ERICalculation/Version", "2014AEG") # FIXME: Verify

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
    # FIXME: Verify. Does this change for shape=townhouse?
    @cfa_basement = 0.0
    orig_details.elements.each("Enclosure/Foundations/Foundation[FoundationType/Basement[Conditioned='true']]") do |cond_basement|
      @cfa_basement += Float(XMLHelper.get_value(cond_basement, "FrameFloor/Area"))
    end
    @bldg_footprint = (@cfa - @cfa_basement) / @ncfl_ag
    @bldg_length = (3.0 * @bldg_footprint / 5.0)**0.5
    @bldg_width = (5.0 / 3.0) * @bldg_length
    @bldg_perimeter = 2.0 * @bldg_length + 2.0 * @bldg_width
    @cvolume = @cfa * @ceil_height # FIXME: Verify. Should this change for cathedral ceiling, conditioned basement, etc.?

    # BuildingSummary
    new_summary = XMLHelper.add_element(new_details, "BuildingSummary")
    set_summary(new_summary)

    # ClimateAndRiskZones
    new_climate = XMLHelper.add_element(new_details, "ClimateandRiskZones")
    set_climate(new_climate)

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
    set_systems_water_heating_use(new_systems)
    set_systems_photovoltaics(new_systems, orig_details)

    # Appliances
    new_appliances = XMLHelper.add_element(new_details, "Appliances")
    set_appliances_clothes_washer(new_appliances)
    set_appliances_clothes_dryer(new_appliances)
    set_appliances_dishwasher(new_appliances)
    set_appliances_refrigerator(new_appliances)
    set_appliances_cooking_range_oven(new_appliances)

    # Lighting
    new_lighting = XMLHelper.add_element(new_details, "Lighting")
    set_lighting(new_lighting, orig_details)
    set_ceiling_fans(new_lighting, orig_details)

    # MiscLoads
    new_misc_loads = XMLHelper.add_element(new_details, "MiscLoads")
    set_misc_plug_loads(new_misc_loads)
    set_misc_television(new_misc_loads)
  end

  def self.set_summary(new_summary)
    HPXML.add_site(building_summary: new_summary,
                   fuels: ["electricity"],
                   shelter_coefficient: Airflow.get_default_shelter_coefficient())

    HPXML.add_building_occupancy(building_summary: new_summary,
                                 number_of_residents: Geometry.get_occupancy_default_num(@nbeds))

    HPXML.add_building_construction(building_summary: new_summary,
                                    number_of_conditioned_floors: Integer(@ncfl),
                                    number_of_conditioned_floors_above_grade: Integer(@ncfl_ag),
                                    number_of_bedrooms: Integer(@nbeds),
                                    conditioned_floor_area: @cfa,
                                    conditioned_building_volume: @cvolume,
                                    garage_present: false)
  end

  def self.set_climate(new_climate)
    HPXML.add_climate_zone_iecc(climate_and_risk_zones: new_climate,
                                year: 2006,
                                climate_zone: "1A") # FIXME: Hard-coded
    HPXML.add_weather_station(climate_and_risk_zones: new_climate,
                              id: "WeatherStation",
                              name: "Miami, FL", # FIXME: Hard-coded
                              wmo: 722020) # FIXME: Hard-coded
  end

  def self.set_enclosure_air_infiltration(new_enclosure, orig_details)
    cfm50 = XMLHelper.get_value(orig_details, "Enclosure/AirInfiltration/AirInfiltrationMeasurement[HousePressure='50']/BuildingAirLeakage[UnitofMeasure='CFM']/AirLeakage")
    desc = XMLHelper.get_value(orig_details, "Enclosure/AirInfiltration/AirInfiltrationMeasurement/LeakinessDescription")

    if not cfm50.nil?
      ach50 = Float(cfm50) * 60.0 / @cvolume
    else
      # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/infiltration/infiltration
      if desc == "tight"
        ach50 = 15.0 # FIXME: Hard-coded
      elsif desc == "average"
        ach50 = 5.0 # FIXME: Hard-coded
      end
    end

    new_air_infil = XMLHelper.add_element(new_enclosure, "AirInfiltration")
    HPXML.add_air_infiltration_measurement(air_infiltration: new_air_infil,
                                           id: "AirInfiltrationMeasurement",
                                           house_pressure: 50,
                                           unit_of_measure: "ACH",
                                           air_leakage: ach50)
  end

  def self.set_enclosure_attics_roofs(new_enclosure, orig_details)
    new_attics = XMLHelper.add_element(new_enclosure, "Attics")

    orig_details.elements.each("Enclosure/AtticAndRoof/Attics/Attic") do |orig_attic|
      attic_id = orig_attic.elements["SystemIdentifier"].attributes["id"]
      attic_type = XMLHelper.get_value(orig_attic, "AtticType")
      orig_roof = get_attached(orig_attic.elements["AttachedToRoof"].attributes["idref"], orig_details, "Enclosure/AtticAndRoof/Roofs/Roof")

      new_attic = HPXML.add_attic(attics: new_attics,
                                  id: attic_id,
                                  attic_type: attic_type)

      # Roof
      roof_r_cavity = Integer(XMLHelper.get_value(orig_attic, "AtticRoofInsulation/Layer[InstallationType='cavity']/NominalRValue"))
      roof_r_cont = XMLHelper.get_value(orig_attic, "AtticRoofInsulation/Layer[InstallationType='continuous']/NominalRValue").to_i
      roof_material = XMLHelper.get_value(orig_roof, "RoofType")
      roof_has_radiant_barrier = Boolean(XMLHelper.get_value(orig_roof, "RadiantBarrier"))
      roof_color = XMLHelper.get_value(orig_roof, "RoofColor")
      roof_solar_abs = XMLHelper.get_value(orig_roof, "SolarAbsorptance")
      roof_solar_abs = get_roof_solar_absorptance(roof_color) if roof_solar_abs.nil?
      # FIXME: Get roof area; is roof area for cathedral and ceiling area for attic?

      new_roofs = XMLHelper.add_element(new_attic, "Roofs")
      # FIXME: Should be two (or four?) roofs per HES zone_roof?
      new_roof = HPXML.add_roof(roofs: new_roofs,
                                id: orig_roof.elements["SystemIdentifier"].attributes["id"],
                                area: 1000, # FIXME: Hard-coded
                                azimuth: 0, # FIXME: Hard-coded
                                solar_absorptance: roof_solar_abs,
                                emittance: 0.9, # FIXME: Verify. Make optional element and remove from here.
                                pitch: Math.tan(UnitConversions.convert(30, "deg", "rad")) * 12, # FIXME: Verify. From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                                radiant_barrier: false) # FIXME: Verify. Setting to false because it's included in the assembly R-value
      orig_attic_roof_ins = orig_attic.elements["AtticRoofInsulation"]
      HPXML.add_insulation(parent: new_roof,
                           id: orig_attic_roof_ins.elements["SystemIdentifier"].attributes["id"],
                           assembly_effective_r_value: get_roof_assembly_r(roof_r_cavity, roof_r_cont, roof_material, roof_has_radiant_barrier))

      # Floor
      if ["unvented attic", "vented attic"].include? attic_type
        floor_r_cavity = Integer(XMLHelper.get_value(orig_attic, "AtticFloorInsulation/Layer[InstallationType='cavity']/NominalRValue"))

        new_floors = XMLHelper.add_element(new_attic, "Floors")
        new_floor = HPXML.add_floor(floors: new_floors,
                                    id: "#{attic_id}_floor",
                                    adjacent_to: "living space",
                                    area: XMLHelper.get_value(orig_attic, "Area")) # FIXME: Verify. This is the attic floor area and not the roof area?
        orig_attic_floor_ins = orig_attic.elements["AtticFloorInsulation"]
        attic_floor_ins_id = orig_attic_floor_ins.elements["SystemIdentifier"].attributes["id"]
        HPXML.add_insulation(parent: new_floor,
                             id: attic_floor_ins_id,
                             assembly_effective_r_value: get_ceiling_assembly_r(floor_r_cavity))
      end
      # FIXME: Should be zero (or two?) gable walls per HES zone_roof?
      # Uses ERI Reference Home for vented attic specific leakage area
    end
  end

  def self.set_enclosure_foundations(new_enclosure, orig_details)
    new_foundations = XMLHelper.add_element(new_enclosure, "Foundations")

    orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
      foundation_id = orig_foundation.elements["SystemIdentifier"].attributes["id"]
      fnd_type = XMLHelper.get_child_name(orig_foundation, "FoundationType")
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

      new_foundation = HPXML.add_foundation(foundations: new_foundations,
                                            id: foundation_id,
                                            foundation_type: fnd_type)

      # FrameFloor
      if ["UnconditionedBasement", "VentedCrawlspace", "UnventedCrawlspace"].include? fnd_type
        orig_framefloor = orig_foundation.elements["FrameFloor"]
        floor_id = orig_framefloor.elements["SystemIdentifier"].attributes["id"]
        floor_r_cavity = Integer(XMLHelper.get_value(orig_foundation, "FrameFloor/Insulation/Layer[InstallationType='cavity']/NominalRValue"))
        floor_r = get_floor_assembly_r(floor_r_cavity)
        floor_area = XMLHelper.get_value(orig_framefloor, "Area")

        new_framefloor = HPXML.add_frame_floor(foundation: new_foundation,
                                               id: floor_id,
                                               adjacent_to: "living space",
                                               area: floor_area)

        orig_framefloor_ins = orig_framefloor.elements["Insulation"]
        framefloor_ins_id = orig_framefloor_ins.elements["SystemIdentifier"].attributes["id"]
        HPXML.add_insulation(parent: new_framefloor,
                             id: framefloor_ins_id,
                             assembly_effective_r_value: floor_r)

      end

      # FoundationWall
      if ["UnconditionedBasement", "ConditionedBasement", "VentedCrawlspace", "UnventedCrawlspace"].include? fnd_type
        orig_fndwall = orig_foundation.elements["FoundationWall"]
        wall_id = orig_fndwall.elements["SystemIdentifier"].attributes["id"]
        wall_r = 10 # FIXME: Hard-coded

        # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/doe2-inputs-assumptions-and-calculations/the-doe2-model
        if ["UnconditionedBasement", "ConditionedBasement"].include? fnd_type
          wall_height = 8.0 # FIXME: Verify
        else
          wall_height = 2.5 # FIXME: Verify
        end

        new_fndwall = HPXML.add_foundation_wall(foundation: new_foundation,
                                                id: wall_id,
                                                height: wall_height,
                                                area: wall_height * @bldg_perimeter, # FIXME: Verify
                                                thickness: 8, # FIXME: Verify
                                                depth_below_grade: wall_height, # FIXME: Verify
                                                adjacent_to: "ground")

        orig_fndwall_ins = orig_fndwall.elements["Insulation"]
        fndwall_ins_id = orig_fndwall_ins.elements["SystemIdentifier"].attributes["id"]
        HPXML.add_insulation(parent: new_fndwall,
                             id: fndwall_ins_id,
                             assembly_effective_r_value: wall_r) # FIXME: need to convert from insulation R-value to assembly R-value

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
      new_slab = HPXML.add_slab(foundation: new_foundation,
                                id: slab_id,
                                area: slab_area,
                                thickness: 4,
                                exposed_perimeter: @bldg_perimeter, # FIXME: Verify
                                perimeter_insulation_depth: 1, # FIXME: Hard-coded
                                under_slab_insulation_width: 0, # FIXME: Verify
                                depth_below_grade: 0) # FIXME: Verify

      new_slab_perim_ins = HPXML.add_perimeter_insulation(slab: new_slab,
                                                          id: slab_perim_id)

      HPXML.add_layer(insulation: new_slab_perim_ins,
                      installation_type: "continuous",
                      nominal_r_value: slab_perim_r)

      new_slab_under_ins = HPXML.add_under_slab_insulation(slab: new_slab,
                                                           id: slab_under_id)

      HPXML.add_layer(insulation: new_slab_under_ins,
                      installation_type: "continuous",
                      nominal_r_value: 0)

      HPXML.add_extension(parent: new_slab,
                          extensions: { "CarpetFraction": 0.5, # FIXME: Hard-coded
                                        "CarpetRValue": 2 }) # FIXME: Hard-coded

      # Uses ERI Reference Home for vented crawlspace specific leakage area
    end
  end

  def self.set_enclosure_rim_joists(new_enclosure, orig_details)
    # No rim joists
  end

  def self.set_enclosure_walls(new_enclosure, orig_details)
    new_walls = XMLHelper.add_element(new_enclosure, "Walls")

    orig_details.elements.each("Enclosure/Walls/Wall") do |orig_wall|
      wall_id = orig_wall.elements["SystemIdentifier"].attributes["id"]
      wall_type = XMLHelper.get_child_name(orig_wall, "WallType")
      wall_orient = XMLHelper.get_value(orig_wall, "Orientation")
      wall_area = nil
      if @bldg_orient == wall_orient or @bldg_orient == reverse_orientation(wall_orient)
        wall_area = @ceil_height * @bldg_width # FIXME: Verify
      else
        wall_area = @ceil_height * @bldg_length # FIXME: Verify
      end

      if wall_type == "WoodStud"
        wall_siding = XMLHelper.get_value(orig_wall, "Siding")
        wall_r_cavity = Integer(XMLHelper.get_value(orig_wall, "Insulation/Layer[InstallationType='cavity']/NominalRValue"))
        wall_r_cont = XMLHelper.get_value(orig_wall, "Insulation/Layer[InstallationType='continuous']/NominalRValue").to_i
        wall_ove = Boolean(XMLHelper.get_value(orig_wall, "WallType/WoodStud/OptimumValueEngineering"))

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
      else
        fail "Unexpected wall type '#{wall_type}'."
      end

      new_wall = HPXML.add_wall(walls: new_walls,
                                id: wall_id,
                                exterior_adjacent_to: "outside",
                                interior_adjacent_to: "living space",
                                wall_type: wall_type,
                                area: wall_area,
                                azimuth: 0, # FIXME: Hard-coded
                                solar_absorptance: 0.75, # FIXME: Verify. Make optional element and remove from here.
                                emittance: 0.9) # FIXME: Verify. Make optional element and remove from here.

      orig_wall_ins = orig_wall.elements["Insulation"]
      wall_ins_id = orig_wall_ins.elements["SystemIdentifier"].attributes["id"]
      new_wall_ins = HPXML.add_insulation(parent: new_wall,
                                          id: wall_ins_id,
                                          assembly_effective_r_value: wall_r)
    end
  end

  def self.set_enclosure_windows(new_enclosure, orig_details)
    new_windows = XMLHelper.add_element(new_enclosure, "Windows")

    orig_details.elements.each("Enclosure/Windows/Window") do |orig_window|
      win_id = orig_window.elements["SystemIdentifier"].attributes["id"]
      wall_id = orig_window.elements["AttachedToWall"].attributes["idref"]
      orig_wall = get_attached(wall_id, orig_details, "Enclosure/Walls/Wall")
      win_area = XMLHelper.get_value(orig_window, "Area")
      win_orient = XMLHelper.get_value(orig_wall, "Orientation")
      win_ufactor = XMLHelper.get_value(orig_window, "UFactor")
      # FIXME: Solar screen (add R-0.1 and multiply SHGC by 0.85?)

      if not win_ufactor.nil?
        win_ufactor = Float(win_ufactor)
        win_shgc = Float(XMLHelper.get_value(orig_window, "SHGC"))
      else
        win_frame_type = XMLHelper.get_child_name(orig_window, "FrameType")
        if win_frame_type == "Aluminum" and Boolean(XMLHelper.get_value(orig_window, "FrameType/Aluminum/ThermalBreak"))
          win_frame_type += "ThermalBreak"
        end
        win_glass_layers = XMLHelper.get_value(orig_window, "GlassLayers")
        win_glass_type = XMLHelper.get_value(orig_window, "GlassType")
        win_gas_fill = XMLHelper.get_value(orig_window, "GasFill")

        win_ufactor, win_shgc = get_window_ufactor_shgc(win_frame_type, win_glass_layers, win_glass_type, win_gas_fill)
      end

      new_window = HPXML.add_window(windows: new_windows,
                                    id: win_id,
                                    area: win_area,
                                    azimuth: orientation_to_azimuth(win_orient),
                                    ufactor: win_ufactor,
                                    shgc: win_shgc,
                                    idref: wall_id)
      # No overhangs FIXME: Verify
      # No neighboring buildings FIXME: Verify
      # Uses ERI Reference Home for interior shading
    end
  end

  def self.set_enclosure_skylights(new_enclosure, orig_details)
    return if not XMLHelper.has_element(new_enclosure, "Skylights")

    new_skylights = XMLHelper.add_element(new_enclosure, "Skylights")

    orig_details.elements.each("Enclosure/Skylights/Skylight") do |orig_skylight|
      sky_id = orig_skylight.elements["SystemIdentifier"].attributes["id"]
      roof_id = orig_skylight.elements["AttachedToRoof"].attributes["idref"]
      sky_ufactor = XMLHelper.get_value(orig_skylight, "UFactor")

      if not sky_ufactor.nil?
        sky_ufactor = Float(sky_ufactor)
        sky_shgc = Float(XMLHelper.get_value(orig_skylight, "SHGC"))
      else
        sky_frame_type = XMLHelper.get_child_name(orig_skylight, "FrameType")
        if sky_frame_type == "Aluminum" and Boolean(XMLHelper.get_value(orig_skylight, "FrameType/Aluminum/ThermalBreak"))
          sky_frame_type += "ThermalBreak"
        end
        sky_glass_layers = XMLHelper.get_value(orig_skylight, "GlassLayers")
        sky_glass_type = XMLHelper.get_value(orig_skylight, "GlassType")
        sky_gas_fill = XMLHelper.get_value(orig_skylight, "GasFill")

        sky_ufactor, sky_shgc = get_skylight_ufactor_shgc(sky_frame_type, sky_glass_layers, sky_glass_type, sky_gas_fill)
      end

      new_skylight = HPXML.add_skylight(skylights: new_skylights,
                                        id: sky_id,
                                        area: sky_area,
                                        azimuth: orientation_to_azimuth(0), # FIXME: Hard-coded
                                        ufactor: sky_ufactor,
                                        shgc: sky_shgc,
                                        idref: roof_id)
      # No overhangs
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

    wall_id = front_wall.elements["SystemIdentifier"].attributes["id"]
    new_door = HPXML.add_door(doors: new_doors,
                              id: "Door",
                              idref: wall_id,
                              azimuth: orientation_to_azimuth(@bldg_orient))
    # Uses ERI Reference Home for Area
    # Uses ERI Reference Home for RValue
  end

  def self.set_systems_hvac(new_systems, orig_details)
    new_hvac = XMLHelper.add_element(new_systems, "HVAC")
    new_hvac_plant = XMLHelper.add_element(new_hvac, "HVACPlant")

    # HeatingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatingSystem") do |orig_heating|
      hvac_id = orig_heating.elements["SystemIdentifier"].attributes["id"]
      distribution_system_id = nil
      if XMLHelper.has_element(orig_heating, "DistributionSystem")
        distribution_system_id = orig_heating.elements["DistributionSystem"].attributes["idref"]
      end
      hvac_type = XMLHelper.get_child_name(orig_heating, "HeatingSystemType")
      hvac_fuel = XMLHelper.get_value(orig_heating, "HeatingSystemFuel")
      hvac_frac = XMLHelper.get_value(orig_heating, "FractionHeatLoadServed")
      hvac_units = nil
      hvac_value = nil
      if ["Furnace", "WallFurnace", "Boiler"].include? hvac_type
        hvac_year = XMLHelper.get_value(orig_heating, "YearInstalled")
        hvac_value = XMLHelper.get_value(orig_heating, "AnnualHeatingEfficiency[Units='AFUE']/Value")
        hvac_units = "AFUE"
        if not hvac_year.nil?
          if ["Furnace", "WallFurnace"].include? hvac_type
            hvac_value = get_default_furnace_afue(Integer(hvac_year), hvac_type, hvac_fuel)
          else
            hvac_value = get_default_boiler_afue(Integer(hvac_year), hvac_type, hvac_fuel)
          end
        else
          hvac_value = Float(hvac_value)
        end
      elsif hvac_type == "ElectricResistance"
        # FIXME: Verify
        # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/heating-and-cooling-equipment/heating-and-cooling-equipment-efficiencies
        hvac_units = "Percent"
        hvac_value = 0.98
      elsif hvac_type == "Stove"
        # FIXME: Verify
        # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/heating-and-cooling-equipment/heating-and-cooling-equipment-efficiencies
        hvac_units = "Percent"
        if hvac_fuel == "wood"
          hvac_value = 0.60
        elsif hvac_fuel == "wood pellets"
          hvac_value = 0.78
        else
          fail "Unexpected fuel type '#{hvac_fuel}' for stove heating system."
        end
      else
        fail "Unexpected heating system type '#{hvac_type}'."
      end

      new_heating = HPXML.add_heating_system(hvac_plant: new_hvac_plant,
                                             id: hvac_id,
                                             idref: distribution_system_id,
                                             heating_system_type: hvac_type,
                                             heating_system_fuel: hvac_fuel,
                                             heating_capacity: -1, # Use Manual J auto-sizing
                                             annual_heating_efficiency_units: hvac_units,
                                             annual_heating_efficiency_value: hvac_value,
                                             fraction_heat_load_served: hvac_frac)
    end

    # CoolingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/CoolingSystem") do |orig_cooling|
      hvac_id = orig_cooling.elements["SystemIdentifier"].attributes["id"]
      distribution_system_id = nil
      if XMLHelper.has_element(orig_cooling, "DistributionSystem")
        distribution_system_id = orig_cooling.elements["DistributionSystem"].attributes["idref"]
      end
      hvac_type = XMLHelper.get_value(orig_cooling, "CoolingSystemType")
      hvac_frac = XMLHelper.get_value(orig_cooling, "FractionCoolLoadServed")
      hvac_units = nil
      hvac_value = nil
      if hvac_type == "central air conditioning"
        hvac_year = XMLHelper.get_value(orig_cooling, "YearInstalled")
        hvac_value = XMLHelper.get_value(orig_cooling, "AnnualCoolingEfficiency[Units='SEER']/Value")
        hvac_units = "SEER"
        if not hvac_year.nil?
          hvac_value = get_default_central_ac_seer(Integer(hvac_year))
        else
          hvac_value = Float(hvac_value)
        end
      elsif hvac_type == "room air conditioner"
        hvac_year = XMLHelper.get_value(orig_cooling, "YearInstalled")
        hvac_value = XMLHelper.get_value(orig_cooling, "AnnualCoolingEfficiency[Units='EER']/Value")
        hvac_units = "EER"
        if not hvac_year.nil?
          hvac_value = get_default_room_ac_eer(Integer(hvac_year))
        else
          hvac_value = Float(hvac_value)
        end
      else
        fail "Unexpected cooling system type '#{hvac_type}'."
      end

      new_cooling = HPXML.add_cooling_system(hvac_plant: new_hvac_plant,
                                             id: hvac_id,
                                             idref: distribution_system_id,
                                             cooling_system_type: hvac_type,
                                             cooling_system_fuel: "electricity",
                                             cooling_capacity: -1, # Use Manual J auto-sizing
                                             fraction_cool_load_served: hvac_frac,
                                             annual_cooling_efficiency_units: hvac_units,
                                             annual_cooling_efficiency_value: hvac_value)
    end

    # HeatPump
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatPump") do |orig_hp|
      hvac_id = orig_hp.elements["SystemIdentifier"].attributes["id"]
      distribution_system_id = nil
      if XMLHelper.has_element(orig_hp, "DistributionSystem")
        distribution_system_id = orig_hp.elements["DistributionSystem"].attributes["idref"]
      end
      hvac_type = XMLHelper.get_value(orig_hp, "HeatPumpType")
      hvac_frac_heat = XMLHelper.get_value(orig_hp, "FractionHeatLoadServed")
      hvac_frac_cool = XMLHelper.get_value(orig_hp, "FractionCoolLoadServed")
      hvac_units_heat = nil
      hvac_value_heat = nil
      hvac_units_cool = nil
      hvac_value_cool = nil
      if ["air-to-air", "mini-split"].include? hvac_type
        hvac_year = XMLHelper.get_value(orig_hp, "YearInstalled")
        hvac_value_cool = XMLHelper.get_value(orig_hp, "AnnualCoolingEfficiency[Units='SEER']/Value")
        hvac_value_heat = XMLHelper.get_value(orig_hp, "AnnualHeatingEfficiency[Units='HSPF']/Value")
        hvac_units_cool = "SEER"
        hvac_units_heat = "HSPF"
        if not hvac_year.nil?
          hvac_value_cool, hvac_value_heat = get_default_ashp_seer_hspf(Integer(hvac_year))
        else
          hvac_value_cool = Float(hvac_value_cool)
          hvac_value_heat = Float(hvac_value_heat)
        end
      elsif hvac_type == "ground-to-air"
        hvac_year = XMLHelper.get_value(orig_hp, "YearInstalled")
        hvac_value_cool = XMLHelper.get_value(orig_hp, "AnnualCoolingEfficiency[Units='EER']/Value")
        hvac_value_heat = XMLHelper.get_value(orig_hp, "AnnualHeatingEfficiency[Units='COP']/Value")
        hvac_units_cool = "EER"
        hvac_units_heat = "COP"
        if not hvac_year.nil?
          hvac_value_cool, hvac_value_heat = get_default_gshp_eer_cop(Integer(hvac_year))
        else
          hvac_value_cool = Float(hvac_value_cool)
          hvac_value_heat = Float(hvac_value_heat)
        end
      else
        fail "Unexpected peat pump system type '#{hvac_type}'."
      end

      new_hp = HPXML.add_heat_pump(hvac_plant: new_hvac_plant,
                                   id: hvac_id,
                                   idref: distribution_system_id,
                                   heat_pump_type: hvac_type,
                                   heating_capacity: -1, # Use Manual J auto-sizing
                                   cooling_capacity: -1, # Use Manual J auto-sizing
                                   fraction_heat_load_served: hvac_frac_heat,
                                   fraction_cool_load_served: hvac_frac_cool,
                                   annual_heating_efficiency_units: hvac_units_heat,
                                   annual_heating_efficiency_value: hvac_value_heat,
                                   annual_cooling_efficiency_units: hvac_units_cool,
                                   annual_cooling_efficiency_value: hvac_value_cool)
    end

    # HVACControl
    new_hvac_control = HPXML.add_hvac_control(hvac: new_hvac,
                                              id: "HVACControl",
                                              control_type: "manual thermostat")

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

      dist_id = orig_dist.elements["SystemIdentifier"].attributes["id"]
      new_dist = HPXML.add_hvac_distribution(hvac: new_hvac,
                                             id: dist_id)
      new_air_dist = XMLHelper.add_element(new_dist, "DistributionSystemType/AirDistribution")

      # Supply duct leakage
      new_supply_measurement = HPXML.add_duct_leakage_measurement(air_distribution: new_air_dist,
                                                                  duct_type: "supply",
                                                                  duct_leakage_units: "CFM25",
                                                                  duct_leakage_value: 100, # FIXME: Hard-coded
                                                                  duct_leakage_total_or_to_outside: "to outside") # FIXME: Hard-coded

      # Return duct leakage
      new_return_measurement = HPXML.add_duct_leakage_measurement(air_distribution: new_air_dist,
                                                                  duct_type: "return",
                                                                  duct_leakage_units: "CFM25",
                                                                  duct_leakage_value: 100, # FIXME: Hard-coded
                                                                  duct_leakage_total_or_to_outside: "to outside") # FIXME: Hard-coded

      orig_dist.elements.each("DistributionSystemType/AirDistribution/Ducts") do |orig_duct|
        hpxml_v23_to_v30_map = { "conditioned space" => "living space",
                                 "unconditioned basement" => "basement - unconditioned",
                                 "unvented crawlspace" => "crawlspace - unvented",
                                 "vented crawlspace" => "crawlspace - vented",
                                 "unconditioned attic" => "attic - vented" } # FIXME: Change to "attic - unconditioned"
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
        new_supply_duct = HPXML.add_ducts(air_distribution: new_air_dist,
                                          duct_type: "supply",
                                          duct_insulation_r_value: duct_rvalue,
                                          duct_location: hpxml_v23_to_v30_map[duct_location],
                                          duct_surface_area: duct_frac_area * supply_duct_area)

        # Return duct
        new_supply_duct = HPXML.add_ducts(air_distribution: new_air_dist,
                                          duct_type: "return",
                                          duct_insulation_r_value: duct_rvalue,
                                          duct_location: hpxml_v23_to_v30_map[duct_location],
                                          duct_surface_area: duct_frac_area * return_duct_area)
      end
    end
  end

  def self.set_systems_mechanical_ventilation(new_systems, orig_details)
    # No mechanical ventilation
  end

  def self.set_systems_water_heater(new_systems, orig_details)
    new_water_heating = XMLHelper.add_element(new_systems, "WaterHeating")

    orig_details.elements.each("Systems/WaterHeating/WaterHeatingSystem") do |orig_wh_sys|
      wh_id = orig_wh_sys.elements["SystemIdentifier"].attributes["id"]
      wh_year = XMLHelper.get_value(orig_wh_sys, "YearInstalled")
      wh_ef = XMLHelper.get_value(orig_wh_sys, "EnergyFactor")
      wh_fuel = XMLHelper.get_value(orig_wh_sys, "FuelType")
      wh_type = XMLHelper.get_value(orig_wh_sys, "WaterHeaterType")

      if not wh_year.nil?
        wh_ef = get_default_water_heater_ef(Integer(wh_year), wh_fuel)
      else
        wh_ef = Float(wh_ef)
      end

      wh_capacity = nil
      if wh_type == "storage water heater"
        wh_capacity = get_default_water_heater_capacity(wh_fuel)
      end
      wh_recovery_efficiency = nil
      if wh_type == "storage water heater" and XMLHelper.get_value(orig_wh_sys, "FuelType") != "electricity"
        wh_recovery_efficiency = get_default_water_heater_re(wh_fuel)
      end
      new_wh_sys = HPXML.add_water_heating_system(water_heating: new_water_heating,
                                                  id: wh_id,
                                                  fuel_type: wh_fuel,
                                                  water_heater_type: wh_type,
                                                  location: "living space", # FIXME: Verify
                                                  tank_volume: get_default_water_heater_volume(wh_fuel),
                                                  fraction_dhw_load_served: 1.0,
                                                  heating_capacity: wh_capacity,
                                                  energy_factor: wh_ef,
                                                  recovery_efficiency: wh_recovery_efficiency)
    end
  end

  def self.set_systems_water_heating_use(new_systems)
    new_water_heating = new_systems.elements["WaterHeating"]

    new_hw_dist = HPXML.add_hot_water_distribution(water_heating: new_water_heating,
                                                   id: "HotWaterDistribution",
                                                   system_type: "Standard", # FIXME: Verify
                                                   pipe_r_value: 0) # FIXME: Verify

    new_fixture = HPXML.add_water_fixture(water_heating: new_water_heating,
                                          id: "ShowerHead",
                                          water_fixture_type: "shower head",
                                          low_flow: false) # FIXME: Verify
  end

  def self.set_systems_photovoltaics(new_systems, orig_details)
    return if not XMLHelper.has_element(orig_details, "Systems/Photovoltaics")

    pv_power = XMLHelper.get_value(orig_details, "Systems/Photovoltaics/PVSystem/MaxPowerOutput")
    pv_num_panels = XMLHelper.get_value(orig_details, "Systems/Photovoltaics/PVSystem/extension/hescore_num_panels")
    pv_orientation = XMLHelper.get_value(orig_details, "Systems/Photovoltaics/PVSystem/ArrayOrientation")

    if not pv_power.nil?
      pv_power = Float(pv_power)
    else
      pv_power = Float(pv_num_panels) * 300.0 # FIXME: Hard-coded
    end

    new_pvs = XMLHelper.add_element(new_systems, "Photovoltaics")
    new_pv = HPXML.add_pv_system(photovoltaics: new_pvs,
                                 id: "PVSystem",
                                 module_type: "standard", # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                                 array_type: "fixed roof mount", # FIXME: Verify. HEScore was using "fixed open rack"??
                                 array_azimuth: orientation_to_azimuth(pv_orientation),
                                 array_tilt: 30, # FIXME: Verify. From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                                 max_power_output: pv_power,
                                 inverter_efficiency: 0.96, # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                                 system_losses_fraction: 0.14) # FIXME: Verify
  end

  def self.set_appliances_clothes_washer(new_appliances)
    new_washer = HPXML.add_clothes_washer(appliances: new_appliances,
                                          id: "ClothesWasher")
    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_clothes_dryer(new_appliances)
    new_dryer = HPXML.add_clothes_dryer(appliances: new_appliances,
                                        id: "ClothesDryer",
                                        fuel_type: "electricity") # FIXME: Verify
    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_dishwasher(new_appliances)
    new_dishwasher = HPXML.add_dishwasher(appliances: new_appliances,
                                          id: "Dishwasher")
    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_refrigerator(new_appliances)
    new_fridge = HPXML.add_refrigerator(appliances: new_appliances,
                                        id: "Refrigerator")
    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_cooking_range_oven(new_appliances)
    new_range = HPXML.add_cooking_range(appliances: new_appliances,
                                        id: "CookingRange",
                                        fuel_type: "electricity") # FIXME: Verify

    new_oven = HPXML.add_oven(appliances: new_appliances,
                              id: "Oven")
    # Uses ERI Reference Home for performance
  end

  def self.set_lighting(new_lighting, orig_details)
    # Uses ERI Reference Home
  end

  def self.set_ceiling_fans(new_lighting, orig_details)
    # No ceiling fans
  end

  def self.set_misc_plug_loads(new_misc_loads)
    new_plug_load = HPXML.add_plug_load(misc_loads: new_misc_loads,
                                        id: "PlugLoadOther",
                                        plug_load_type: "other")
    # Uses ERI Reference Home for performance
  end

  def self.set_misc_television(new_misc_loads)
    new_plug_load = HPXML.add_plug_load(misc_loads: new_misc_loads,
                                        id: "PlugLoadTV",
                                        plug_load_type: "TV other")
    # Uses ERI Reference Home for performance
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
    val = { 0 => [4.6, 3.2, 3.8, 3.7, 4.7],                                # ewwf00wo, ewwf00st, ewwf00vi, ewwf00al, ewwf00br
            3 => [7.0, 5.8, 6.3, 6.2, 7.1],                                # ewwf03wo, ewwf03st, ewwf03vi, ewwf03al, ewwf03br
            7 => [9.7, 8.5, 9.0, 8.8, 9.8],                                # ewwf07wo, ewwf07st, ewwf07vi, ewwf07al, ewwf07br
            11 => [11.5, 10.2, 10.8, 10.6, 11.6],                          # ewwf11wo, ewwf11st, ewwf11vi, ewwf11al, ewwf11br
            13 => [12.5, 11.1, 11.6, 11.5, 12.5],                          # ewwf13wo, ewwf13st, ewwf13vi, ewwf13al, ewwf13br
            15 => [13.3, 11.9, 12.5, 12.3, 13.3],                          # ewwf15wo, ewwf15st, ewwf15vi, ewwf15al, ewwf15br
            19 => [16.9, 15.4, 16.1, 15.9, 16.9],                          # ewwf19wo, ewwf19st, ewwf19vi, ewwf19al, ewwf19br
            21 => [17.5, 16.1, 16.9, 16.7, 17.9] }[r_cavity][siding_index] # ewwf21wo, ewwf21st, ewwf21vi, ewwf21al, ewwf21br
  elsif r_cont == 5 and not ove
    val = { 11 => [16.7, 15.4, 15.9, 15.9, 16.9],                          # ewps11wo, ewps11st, ewps11vi, ewps11al, ewps11br
            13 => [17.9, 16.4, 16.9, 16.9, 17.9],                          # ewps13wo, ewps13st, ewps13vi, ewps13al, ewps13br
            15 => [18.5, 17.2, 17.9, 17.9, 18.9],                          # ewps15wo, ewps15st, ewps15vi, ewps15al, ewps15br
            19 => [22.2, 20.8, 21.3, 21.3, 22.2],                          # ewps19wo, ewps19st, ewps19vi, ewps19al, ewps19br
            21 => [22.7, 21.7, 22.2, 22.2, 23.3] }[r_cavity][siding_index] # ewps21wo, ewps21st, ewps21vi, ewps21al, ewps21br
  elsif r_cont == 0 and ove
    val = { 19 => [19.2, 17.9, 18.5, 18.2, 19.2],                          # ewov19wo, ewov19st, ewov19vi, ewov19al, ewov19br
            21 => [20.4, 18.9, 19.6, 19.6, 20.4],                          # ewov21wo, ewov21st, ewov21vi, ewov21al, ewov21br
            27 => [25.6, 24.4, 25.0, 24.4, 25.6],                          # ewov27wo, ewov27st, ewov27vi, ewov27al, ewov27br
            33 => [30.3, 29.4, 29.4, 29.4, 30.3],                          # ewov33wo, ewov33st, ewov33vi, ewov33al, ewov33br
            38 => [34.5, 33.3, 34.5, 34.5, 34.5] }[r_cavity][siding_index] # ewov38wo, ewov38st, ewov38vi, ewov38al, ewov38br
  elsif r_cont == 5 and ove
    val = { 19 => [24.4, 23.3, 23.8, 23.3, 24.4],                          # ewop19wo, ewop19st, ewop19vi, ewop19al, ewop19br
            21 => [25.6, 24.4, 25.0, 25.0, 25.6] }[r_cavity][siding_index] # ewop21wo, ewop21st, ewop21vi, ewop21al, ewop21br
  end
  return val if not val.nil?

  fail "Could not get default wood stud wall assembly R-value for R-cavity '#{r_cavity}' and R-cont '#{r_cont}' and siding '#{siding}' and ove '#{ove}'"
end

def get_structural_block_wall_assembly_r(r_cavity)
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  val = { 0 => 2.9,              # ewbr00nn
          5 => 7.9,              # ewbr05nn
          10 => 12.8 }[r_cavity] # ewbr10nn
  return val if not val.nil?

  fail "Could not get default structural block wall assembly R-value for R-cavity '#{r_cavity}'"
end

def get_concrete_block_wall_assembly_r(r_cavity, siding)
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  sidings = ["stucco", "brick veneer", nil]
  siding_index = sidings.index(siding)
  val = { 0 => [4.1, 5.6, 4.0],                           # ewcb00st, ewcb00br, ewcb00nn
          3 => [5.7, 7.2, 5.6],                           # ewcb03st, ewcb03br, ewcb03nn
          6 => [8.5, 10.0, 8.3] }[r_cavity][siding_index] # ewcb06st, ewcb06br, ewcb06nn
  return val if not val.nil?

  fail "Could not get default concrete block wall assembly R-value for R-cavity '#{r_cavity}' and siding '#{siding}'"
end

def get_straw_bale_wall_assembly_r(siding)
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  return 58.8 if siding == "stucco" # ewsb00st

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
    val = { 0 => [3.3, 4.0, 3.4, 3.4, 3.7],                                 # rfwf00co, rfwf00wo, rfwf00rc, rfwf00lc, rfwf00tg
            11 => [13.5, 14.3, 13.7, 13.5, 13.9],                           # rfwf11co, rfwf11wo, rfwf11rc, rfwf11lc, rfwf11tg
            13 => [14.9, 15.6, 15.2, 14.9, 15.4],                           # rfwf13co, rfwf13wo, rfwf13rc, rfwf13lc, rfwf13tg
            15 => [16.4, 16.9, 16.4, 16.4, 16.7],                           # rfwf15co, rfwf15wo, rfwf15rc, rfwf15lc, rfwf15tg
            19 => [20.0, 20.8, 20.4, 20.4, 20.4],                           # rfwf19co, rfwf19wo, rfwf19rc, rfwf19lc, rfwf19tg
            21 => [21.7, 22.2, 21.7, 21.3, 21.7],                           # rfwf21co, rfwf21wo, rfwf21rc, rfwf21lc, rfwf21tg
            27 => [nil, 27.8, 27.0, 27.0, 27.0] }[r_cavity][material_index] # rfwf27co, rfwf27wo, rfwf27rc, rfwf27lc, rfwf27tg
  elsif r_cont == 0 and has_radiant_barrier
    val = { 0 => [5.6, 6.3, 5.7, 5.6, 6.0] }[r_cavity][material_index]      # rfrb00co, rfrb00wo, rfrb00rc, rfrb00lc, rfrb00tg
  elsif r_cont == 5 and not has_radiant_barrier
    val = { 0 => [8.3, 9.0, 8.4, 8.3, 8.7],                                 # rfps00co, rfps00wo, rfps00rc, rfps00lc, rfps00tg
            11 => [18.5, 19.2, 18.5, 18.5, 18.9],                           # rfps11co, rfps11wo, rfps11rc, rfps11lc, rfps11tg
            13 => [20.0, 20.8, 20.0, 20.0, 20.4],                           # rfps13co, rfps13wo, rfps13rc, rfps13lc, rfps13tg
            15 => [21.3, 22.2, 21.3, 21.3, 21.7],                           # rfps15co, rfps15wo, rfps15rc, rfps15lc, rfps15tg
            19 => [nil, 25.6, 25.6, 25.0, 25.6],                            # rfps19co, rfps19wo, rfps19rc, rfps19lc, rfps19tg
            21 => [nil, 27.0, 27.0, 26.3, 27.0] }[r_cavity][material_index] # rfps21co, rfps21wo, rfps21rc, rfps21lc, rfps21tg
  end
  return val if not val.nil?

  fail "Could not get default roof assembly R-value for R-cavity '#{r_cavity}' and R-cont '#{r_cont}' and material '#{material}' and radiant barrier '#{has_radiant_barrier}'"
end

def get_ceiling_assembly_r(r_cavity)
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/ceiling-construction-types
  val = { 0 => 2.2,              # ecwf00
          3 => 5.0,              # ecwf03
          6 => 7.6,              # ecwf06
          9 => 10.0,             # ecwf09
          11 => 10.9,            # ecwf11
          19 => 19.2,            # ecwf19
          21 => 21.3,            # ecwf21
          25 => 25.6,            # ecwf25
          30 => 30.3,            # ecwf30
          38 => 38.5,            # ecwf38
          44 => 43.5,            # ecwf44
          49 => 50.0,            # ecwf49
          60 => 58.8 }[r_cavity] # ecwf60
  return val if not val.nil?

  fail "Could not get default ceiling assembly R-value for R-cavity '#{r_cavity}'"
end

def get_floor_assembly_r(r_cavity)
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/floor-construction-types
  val = { 0 => 5.9,              # efwf00ca
          11 => 15.6,            # efwf11ca
          13 => 17.2,            # efwf13ca
          15 => 18.5,            # efwf15ca
          19 => 22.2,            # efwf19ca
          21 => 23.8,            # efwf21ca
          25 => 27.0,            # efwf25ca
          30 => 31.3,            # efwf30ca
          38 => 37.0 }[r_cavity] # efwf38ca
  return val if not val.nil?

  fail "Could not get default floor assembly R-value for R-cavity '#{r_cavity}'"
end

def get_window_ufactor_shgc(frame_type, glass_layers, glass_type, gas_fill)
  # FIXME: Verify
  # https://docs.google.com/spreadsheets/d/1joG39BeiRj1mV0Lge91P_dkL-0-94lSEY5tJzGvpc2A/edit#gid=909262753
  key = [frame_type, glass_layers, glass_type, gas_fill]
  vals = { ["Aluminum", "single-pane", nil, nil] => [1.27, 0.75],                               # scna
           ["Wood", "single-pane", nil, nil] => [0.89, 0.64],                                   # scnw
           ["Aluminum", "single-pane", "tinted/reflective", nil] => [1.27, 0.64],               # stna
           ["Wood", "single-pane", "tinted/reflective", nil] => [0.89, 0.54],                   # stnw
           ["Aluminum", "double-pane", nil, "air"] => [0.81, 0.67],                             # dcaa
           ["AluminumThermalBreak", "double-pane", nil, "air"] => [0.60, 0.67],                 # dcab
           ["Wood", "double-pane", nil, "air"] => [0.51, 0.56],                                 # dcaw
           ["Aluminum", "double-pane", "tinted/reflective", "air"] => [0.81, 0.55],             # dtaa
           ["AluminumThermalBreak", "double-pane", "tinted/reflective", "air"] => [0.60, 0.55], # dtab
           ["Wood", "double-pane", "tinted/reflective", "air"] => [0.51, 0.46],                 # dtaw
           ["Wood", "double-pane", "low-e", "air"] => [0.42, 0.52],                             # dpeaw
           ["AluminumThermalBreak", "double-pane", "low-e", "argon"] => [0.47, 0.62],           # dpeaab
           ["Wood", "double-pane", "low-e", "argon"] => [0.39, 0.52],                           # dpeaaw
           ["Aluminum", "double-pane", "reflective", "air"] => [0.67, 0.37],                    # dseaa
           ["AluminumThermalBreak", "double-pane", "reflective", "air"] => [0.47, 0.37],        # dseab
           ["Wood", "double-pane", "reflective", "air"] => [0.39, 0.31],                        # dseaw
           ["Wood", "double-pane", "reflective", "argon"] => [0.36, 0.31],                      # dseaaw
           ["Wood", "triple-pane", "low-e", "argon"] => [0.27, 0.31] }[key]                     # thmabw
  return vals if not vals.nil?

  fail "Could not get default window U/SHGC for frame type '#{frame_type}' and glass layers '#{glass_layers}' and glass type '#{glass_type}' and gas fill '#{gas_fill}'"
end

def get_skylight_ufactor_shgc(frame_type, glass_layers, glass_type, gas_fill)
  # FIXME: Verify
  # https://docs.google.com/spreadsheets/d/1joG39BeiRj1mV0Lge91P_dkL-0-94lSEY5tJzGvpc2A/edit#gid=909262753
  key = [frame_type, glass_layers, glass_type, gas_fill]
  vals = { ["Aluminum", "single-pane", nil, nil] => [1.98, 0.75],                               # scna
           ["Wood", "single-pane", nil, nil] => [1.47, 0.64],                                   # scnw
           ["Aluminum", "single-pane", "tinted/reflective", nil] => [1.98, 0.64],               # stna
           ["Wood", "single-pane", "tinted/reflective", nil] => [1.47, 0.54],                   # stnw
           ["Aluminum", "double-pane", nil, "air"] => [1.30, 0.67],                             # dcaa
           ["AluminumThermalBreak", "double-pane", nil, "air"] => [1.10, 0.67],                 # dcab
           ["Wood", "double-pane", nil, "air"] => [0.84, 0.56],                                 # dcaw
           ["Aluminum", "double-pane", "tinted/reflective", "air"] => [1.30, 0.55],             # dtaa
           ["AluminumThermalBreak", "double-pane", "tinted/reflective", "air"] => [1.10, 0.55], # dtab
           ["Wood", "double-pane", "tinted/reflective", "air"] => [0.84, 0.46],                 # dtaw
           ["Wood", "double-pane", "low-e", "air"] => [0.74, 0.52],                             # dpeaw
           ["AluminumThermalBreak", "double-pane", "low-e", "argon"] => [0.95, 0.62],           # dpeaab
           ["Wood", "double-pane", "low-e", "argon"] => [0.68, 0.52],                           # dpeaaw
           ["Aluminum", "double-pane", "reflective", "air"] => [1.17, 0.37],                    # dseaa
           ["AluminumThermalBreak", "double-pane", "reflective", "air"] => [0.98, 0.37],        # dseab
           ["Wood", "double-pane", "reflective", "air"] => [0.71, 0.31],                        # dseaw
           ["Wood", "double-pane", "reflective", "argon"] => [0.65, 0.31],                      # dseaaw
           ["Wood", "triple-pane", "low-e", "argon"] => [0.47, 0.31] }[key]                     # thmabw
  return vals if not vals.nil?

  fail "Could not get default skylight U/SHGC for frame type '#{frame_type}' and glass layers '#{glass_layers}' and glass type '#{glass_type}' and gas fill '#{gas_fill}'"
end

def get_roof_solar_absorptance(roof_color)
  # FIXME: Verify
  # https://docs.google.com/spreadsheets/d/1joG39BeiRj1mV0Lge91P_dkL-0-94lSEY5tJzGvpc2A/edit#gid=1325866208
  val = { "reflective" => 0.40,
          "white" => 0.50,
          "light" => 0.65,
          "medium" => 0.75,
          "medium dark" => 0.85,
          "dark" => 0.95 }[roof_color]
  return val if not val.nil?

  fail "Could not get roof absorptance for color '#{roof_color}'"
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
