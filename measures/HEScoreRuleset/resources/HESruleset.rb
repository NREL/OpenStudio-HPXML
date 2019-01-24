require_relative "../../HPXMLtoOpenStudio/resources/airflow"
require_relative "../../HPXMLtoOpenStudio/resources/geometry"
require_relative "../../HPXMLtoOpenStudio/resources/xmlhelper"
require_relative "../../HPXMLtoOpenStudio/resources/hpxml"

class HEScoreRuleset
  def self.apply_ruleset(hpxml_doc)
    building = hpxml_doc.elements["/HPXML/Building"]

    orig_details = hpxml_doc.elements["/HPXML/Building/BuildingDetails"]

    xml_transaction_header_information_values = HPXML.get_xml_transaction_header_information_values(xml_transaction_header_information: hpxml_doc.elements["/HPXML/XMLTransactionHeaderInformation"])
    software_info_values = HPXML.get_software_info_values(software_info: hpxml_doc.elements["/HPXML/SoftwareInfo"])
    building_values = HPXML.get_building_values(building: hpxml_doc.elements["/HPXML/Building"])
    project_status_values = HPXML.get_project_status_values(project_status: hpxml_doc.elements["/HPXML/Building/ProjectStatus"])

    hpxml_doc = HPXML.create_hpxml(xml_type: xml_transaction_header_information_values[:xml_type],
                                   xml_generated_by: xml_transaction_header_information_values[:xml_generated_by],
                                   transaction: xml_transaction_header_information_values[:transaction],
                                   software_program_used: software_info_values[:software_program_used],
                                   software_program_version: software_info_values[:software_program_version],
                                   eri_calculation_version: "2014AEG",
                                   building_id: building_values[:id],
                                   event_type: project_status_values[:event_type])

    hpxml = hpxml_doc.elements["HPXML"]

    # Global variables
    orig_building_construction = building.elements["BuildingDetails/BuildingSummary/BuildingConstruction"]
    orig_building_construction_values = HPXML.get_building_construction_values(building_construction: orig_building_construction)
    orig_site = building.elements["BuildingDetails/BuildingSummary/Site"]
    orig_site_values = HPXML.get_site_values(site: orig_site)
    @nbeds = Float(orig_building_construction_values[:number_of_bedrooms])
    @cfa = Float(orig_building_construction_values[:conditioned_floor_area])
    @ncfl_ag = Float(orig_building_construction_values[:number_of_conditioned_floors_above_grade])
    @ncfl = @ncfl_ag # Number above-grade stories plus any conditioned basement
    if not XMLHelper.get_value(orig_details, "Enclosure/Foundations/Foundation/FoundationType/Basement[Conditioned='true']").nil?
      @ncfl += 1
    end
    @nfl = @ncfl_ag # Number above-grade stories plus any basement
    if not XMLHelper.get_value(orig_details, "Enclosure/Foundations/Foundation/FoundationType/Basement").nil?
      @nfl += 1
    end
    @ceil_height = Float(orig_building_construction_values[:average_ceiling_height])
    @bldg_orient = orig_site_values[:orientation_of_front_of_home]

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
    set_summary(hpxml)

    # ClimateAndRiskZones
    set_climate(hpxml)

    # Enclosure
    set_enclosure_air_infiltration(orig_details, hpxml)
    set_enclosure_attics_roofs(orig_details, hpxml)
    set_enclosure_foundations(orig_details, hpxml)
    set_enclosure_rim_joists(orig_details, hpxml)
    set_enclosure_walls(orig_details, hpxml)
    set_enclosure_windows(orig_details, hpxml)
    set_enclosure_skylights(orig_details, hpxml)
    set_enclosure_doors(orig_details, hpxml)

    # Systems
    set_systems_hvac(orig_details, hpxml)
    set_systems_mechanical_ventilation(orig_details, hpxml)
    set_systems_water_heater(orig_details, hpxml)
    set_systems_water_heating_use(hpxml)
    set_systems_photovoltaics(orig_details, hpxml)

    # Appliances
    set_appliances_clothes_washer(hpxml)
    set_appliances_clothes_dryer(hpxml)
    set_appliances_dishwasher(hpxml)
    set_appliances_refrigerator(hpxml)
    set_appliances_cooking_range_oven(hpxml)

    # Lighting
    set_lighting(orig_details, hpxml)
    set_ceiling_fans(orig_details, hpxml)

    # MiscLoads
    set_misc_plug_loads(hpxml)
    set_misc_television(hpxml)

    return hpxml_doc
  end

  def self.set_summary(hpxml)
    HPXML.add_site(hpxml: hpxml,
                   fuels: ["electricity"],
                   shelter_coefficient: Airflow.get_default_shelter_coefficient())
    HPXML.add_building_occupancy(hpxml: hpxml,
                                 number_of_residents: Geometry.get_occupancy_default_num(@nbeds))
    HPXML.add_building_construction(hpxml: hpxml,
                                    number_of_conditioned_floors: Integer(@ncfl),
                                    number_of_conditioned_floors_above_grade: Integer(@ncfl_ag),
                                    number_of_bedrooms: Integer(@nbeds),
                                    conditioned_floor_area: @cfa,
                                    conditioned_building_volume: @cvolume,
                                    garage_present: false)
  end

  def self.set_climate(hpxml)
    HPXML.add_climate_zone_iecc(hpxml: hpxml,
                                year: 2006,
                                climate_zone: "1A") # FIXME: Hard-coded
    HPXML.add_weather_station(hpxml: hpxml,
                              id: "WeatherStation",
                              name: "Miami, FL", # FIXME: Hard-coded
                              wmo: 722020) # FIXME: Hard-coded
  end

  def self.set_enclosure_air_infiltration(orig_details, hpxml)
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

    HPXML.add_air_infiltration_measurement(hpxml: hpxml,
                                           id: "AirInfiltrationMeasurement",
                                           house_pressure: 50,
                                           unit_of_measure: "ACH",
                                           air_leakage: ach50)
  end

  def self.set_enclosure_attics_roofs(orig_details, hpxml)
    orig_details.elements.each("Enclosure/AtticAndRoof/Attics/Attic") do |orig_attic|
      orig_attic_values = HPXML.get_attic_values(attic: orig_attic)
      orig_roof = get_attached(HPXML.get_idref(orig_attic, "AttachedToRoof"), orig_details, "Enclosure/AtticAndRoof/Roofs/Roof")
      orig_roof_values = HPXML.get_roof_values(roof: orig_roof)

      new_attic = HPXML.add_attic(hpxml: hpxml,
                                  id: orig_attic_values[:id],
                                  attic_type: orig_attic_values[:attic_type])

      # Roof
      roof_r_cavity = Integer(XMLHelper.get_value(orig_attic, "AtticRoofInsulation/Layer[InstallationType='cavity']/NominalRValue"))
      roof_r_cont = XMLHelper.get_value(orig_attic, "AtticRoofInsulation/Layer[InstallationType='continuous']/NominalRValue").to_i
      roof_solar_abs = orig_roof_values[:solar_absorptance]
      roof_solar_abs = get_roof_solar_absorptance(orig_roof_values[:roof_color]) if orig_roof_values[:solar_absorptance].nil?
      # FIXME: Get roof area; is roof area for cathedral and ceiling area for attic?

      # FIXME: Should be two (or four?) roofs per HES zone_roof?
      new_roof = HPXML.add_attic_roof(attic: new_attic,
                                      id: orig_roof_values[:id],
                                      area: 1000, # FIXME: Hard-coded
                                      azimuth: 0, # FIXME: Hard-coded
                                      solar_absorptance: roof_solar_abs,
                                      emittance: 0.9, # FIXME: Verify. Make optional element and remove from here.
                                      pitch: Math.tan(UnitConversions.convert(30, "deg", "rad")) * 12, # FIXME: Verify. From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                                      radiant_barrier: false) # FIXME: Verify. Setting to false because it's included in the assembly R-value
      orig_attic_roof_ins = orig_attic.elements["AtticRoofInsulation"]
      orig_attic_roof_ins_values = HPXML.get_insulation_values(insulation: orig_attic_roof_ins)
      HPXML.add_insulation(parent: new_roof,
                           id: orig_attic_roof_ins_values[:id],
                           assembly_effective_r_value: get_roof_assembly_r(roof_r_cavity, roof_r_cont, orig_roof_values[:roof_type], Boolean(orig_roof_values[:radiant_barrier])))

      # Floor
      if ["unvented attic", "vented attic"].include? orig_attic_values[:attic_type]
        floor_r_cavity = Integer(XMLHelper.get_value(orig_attic, "AtticFloorInsulation/Layer[InstallationType='cavity']/NominalRValue"))

        new_floor = HPXML.add_attic_floor(attic: new_attic,
                                          id: "#{orig_attic_values[:id]}_floor",
                                          adjacent_to: "living space",
                                          area: XMLHelper.get_value(orig_attic, "Area")) # FIXME: Verify. This is the attic floor area and not the roof area?
        orig_attic_floor_ins = orig_attic.elements["AtticFloorInsulation"]
        orig_attic_floor_ins_values = HPXML.get_insulation_values(insulation: orig_attic_floor_ins)
        HPXML.add_insulation(parent: new_floor,
                             id: orig_attic_floor_ins_values[:id],
                             assembly_effective_r_value: get_ceiling_assembly_r(floor_r_cavity))
      end
      # FIXME: Should be zero (or two?) gable walls per HES zone_roof?
      # Uses ERI Reference Home for vented attic specific leakage area
    end
  end

  def self.set_enclosure_foundations(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
      orig_foundation_values = HPXML.get_foundation_values(foundation: orig_foundation)
      fnd_type = orig_foundation_values[:foundation_type]

      new_foundation = HPXML.add_foundation(hpxml: hpxml,
                                            id: orig_foundation_values[:id],
                                            foundation_type: fnd_type)

      # FrameFloor
      if ["UnconditionedBasement", "VentedCrawlspace", "UnventedCrawlspace"].include? fnd_type
        orig_framefloor = orig_foundation.elements["FrameFloor"]
        orig_frameflooor_values = HPXML.get_floor_values(floor: orig_framefloor)
        floor_r_cavity = Integer(XMLHelper.get_value(orig_foundation, "FrameFloor/Insulation/Layer[InstallationType='cavity']/NominalRValue"))
        floor_r = get_floor_assembly_r(floor_r_cavity)

        new_framefloor = HPXML.add_frame_floor(foundation: new_foundation,
                                               id: orig_framefloor_values[:id],
                                               adjacent_to: "living space",
                                               area: orig_framefloor_values[:area])

        orig_framefloor_ins = orig_framefloor.elements["Insulation"]
        orig_framefloor_ins_values = HPXML.get_insulation_values(insulation: orig_framefloor_ins)
        HPXML.add_insulation(parent: new_framefloor,
                             id: orig_framefloor_ins_values[:id],
                             assembly_effective_r_value: floor_r)

      end

      # FoundationWall
      if ["UnconditionedBasement", "ConditionedBasement", "VentedCrawlspace", "UnventedCrawlspace"].include? fnd_type
        orig_fndwall = orig_foundation.elements["FoundationWall"]
        orig_fndwall_values = HPXML.get_foundation_wall_values(foundation_wall: orig_fndwall)
        wall_r = 10 # FIXME: Hard-coded

        # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/doe2-inputs-assumptions-and-calculations/the-doe2-model
        if ["UnconditionedBasement", "ConditionedBasement"].include? fnd_type
          wall_height = 8.0 # FIXME: Verify
        else
          wall_height = 2.5 # FIXME: Verify
        end

        new_fndwall = HPXML.add_foundation_wall(foundation: new_foundation,
                                                id: orig_fndwall_values[:id],
                                                height: wall_height,
                                                area: wall_height * @bldg_perimeter, # FIXME: Verify
                                                thickness: 8, # FIXME: Verify
                                                depth_below_grade: wall_height, # FIXME: Verify
                                                adjacent_to: "ground")

        orig_fndwall_ins = orig_fndwall.elements["Insulation"]
        orig_fndwall_ins_values = HPXML.get_insulation_values(insulation: orig_fndwall_ins)
        HPXML.add_insulation(parent: new_fndwall,
                             id: orig_fndwall_ins_values[:id],
                             assembly_effective_r_value: wall_r) # FIXME: need to convert from insulation R-value to assembly R-value

      end

      # Slab
      if fnd_type == "SlabOnGrade"
        slab_perim_r = Integer(XMLHelper.get_value(orig_foundation, "Slab/PerimeterInsulation/Layer[InstallationType='continuous']/NominalRValue"))
        slab_area = XMLHelper.get_value(orig_foundation, "Slab/Area")
        fnd_id = orig_foundation_values[:id]
        slab_id = orig_foundation.elements["Slab/SystemIdentifier"].attributes["id"]
        slab_perim_id = orig_foundation.elements["Slab/PerimeterInsulation/SystemIdentifier"].attributes["id"]
        slab_under_id = "#{fnd_id}_slab_under_insulation"
      else
        slab_perim_r = 0
        slab_area = Float(XMLHelper.get_value(orig_foundation, "FrameFloor/Area"))
        slab_id = "#{orig_foundation_values[:id]}_slab"
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

  def self.set_enclosure_rim_joists(orig_details, hpxml)
    # No rim joists
  end

  def self.set_enclosure_walls(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Walls/Wall") do |orig_wall|
      orig_wall_values = HPXML.get_wall_values(wall: orig_wall)

      wall_type = orig_wall_values[:wall_type]
      wall_orient = orig_wall_values[:orientation]
      wall_area = nil
      if @bldg_orient == wall_orient or @bldg_orient == reverse_orientation(wall_orient)
        wall_area = @ceil_height * @bldg_width # FIXME: Verify
      else
        wall_area = @ceil_height * @bldg_length # FIXME: Verify
      end

      if wall_type == "WoodStud"
        wall_r_cavity = Integer(XMLHelper.get_value(orig_wall, "Insulation/Layer[InstallationType='cavity']/NominalRValue"))
        wall_r_cont = XMLHelper.get_value(orig_wall, "Insulation/Layer[InstallationType='continuous']/NominalRValue").to_i
        wall_ove = Boolean(XMLHelper.get_value(orig_wall, "WallType/WoodStud/OptimumValueEngineering"))

        wall_r = get_wood_stud_wall_assembly_r(wall_r_cavity, wall_r_cont, orig_wall_values[:siding], wall_ove)
      elsif wall_type == "StructuralBrick"
        wall_r_cavity = Integer(XMLHelper.get_value(orig_wall, "Insulation/Layer[InstallationType='cavity']/NominalRValue"))

        wall_r = get_structural_block_wall_assembly_r(wall_r_cavity)
      elsif wall_type == "ConcreteMasonryUnit"
        wall_r_cavity = Integer(XMLHelper.get_value(orig_wall, "Insulation/Layer[InstallationType='cavity']/NominalRValue"))

        wall_r = get_concrete_block_wall_assembly_r(wall_r_cavity, orig_wall_values[:siding])
      elsif wall_type == "StrawBale"
        wall_r = get_straw_bale_wall_assembly_r(orig_wall_values[:siding])
      else
        fail "Unexpected wall type '#{wall_type}'."
      end

      new_wall = HPXML.add_wall(hpxml: hpxml,
                                id: orig_wall_values[:id],
                                exterior_adjacent_to: "outside",
                                interior_adjacent_to: "living space",
                                wall_type: wall_type,
                                area: wall_area,
                                azimuth: 0, # FIXME: Hard-coded
                                solar_absorptance: 0.75, # FIXME: Verify. Make optional element and remove from here.
                                emittance: 0.9) # FIXME: Verify. Make optional element and remove from here.

      orig_wall_ins = orig_wall.elements["Insulation"]
      wall_ins_id = HPXML.get_id(orig_wall_ins)
      new_wall_ins = HPXML.add_insulation(parent: new_wall,
                                          id: wall_ins_id,
                                          assembly_effective_r_value: wall_r)
    end
  end

  def self.set_enclosure_windows(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Windows/Window") do |orig_window|
      orig_window_values = HPXML.get_window_values(window: orig_window)
      win_ufactor = orig_window_values[:ufactor]
      win_shgc = orig_window_values[:shgc]
      # FIXME: Solar screen (add R-0.1 and multiply SHGC by 0.85?)

      if not win_ufactor.nil?
        win_ufactor = Float(win_ufactor)
        win_shgc = Float(win_shgc)
      else
        win_frame_type = orig_window_values[:frame_type]
        if win_frame_type == "Aluminum" and Boolean(XMLHelper.get_value(orig_window, "FrameType/Aluminum/ThermalBreak"))
          win_frame_type += "ThermalBreak"
        end

        win_ufactor, win_shgc = get_window_ufactor_shgc(win_frame_type, orig_window_values[:glass_layers], orig_window_values[:glass_type], orig_window_values[:gas_fill])
      end

      new_window = HPXML.add_window(hpxml: hpxml,
                                    id: orig_window_values[:id],
                                    area: orig_window_values[:area],
                                    azimuth: orientation_to_azimuth(orig_window_values[:orientation]),
                                    ufactor: win_ufactor,
                                    shgc: win_shgc,
                                    wall_idref: orig_window_values[:wall_idref])
      # No overhangs FIXME: Verify
      # No neighboring buildings FIXME: Verify
      # Uses ERI Reference Home for interior shading
    end
  end

  def self.set_enclosure_skylights(orig_details, hpxml)
    return if not XMLHelper.has_element(orig_details, "Enclosure/Skylights")

    orig_details.elements.each("Enclosure/Skylights/Skylight") do |orig_skylight|
      orig_skylight_values = HPXML.get_skylight_values(skylight: orig_skylight)
      sky_ufactor = orig_skylight_values[:ufactor]
      sky_shgc = orig_skylight_values[:shgc]

      if not sky_ufactor.nil?
        sky_ufactor = Float(sky_ufactor)
        sky_shgc = Float(sky_shgc)
      else
        sky_frame_type = orig_skylight_values[:frame_type]
        if sky_frame_type == "Aluminum" and Boolean(XMLHelper.get_value(orig_skylight, "FrameType/Aluminum/ThermalBreak"))
          sky_frame_type += "ThermalBreak"
        end
        sky_ufactor, sky_shgc = get_skylight_ufactor_shgc(sky_frame_type, orig_skylight_values[:glass_layers], orig_skylight_values[:glass_type], orig_skylight_values[:gas_fill])
      end

      new_skylight = HPXML.add_skylight(hpxml: hpxml,
                                        id: orig_skylight_values[:id],
                                        area: orig_skylight_values[:area],
                                        azimuth: orientation_to_azimuth("north"), # FIXME: Hard-coded
                                        ufactor: sky_ufactor,
                                        shgc: sky_shgc,
                                        roof_idref: orig_skylight_values[:roof_idref])
      # No overhangs
    end
  end

  def self.set_enclosure_doors(orig_details, hpxml)
    front_wall = nil
    orig_details.elements.each("Enclosure/Walls/Wall") do |orig_wall|
      orig_wall_values = HPXML.get_wall_values(wall: orig_wall)
      next if orig_wall_values[:orientation] != @bldg_orient

      front_wall = orig_wall
      break
    end

    front_wall_values = HPXML.get_wall_values(wall: front_wall)
    new_door = HPXML.add_door(hpxml: hpxml,
                              id: "Door",
                              wall_idref: front_wall_values[:id],
                              azimuth: orientation_to_azimuth(@bldg_orient))
    # Uses ERI Reference Home for Area
    # Uses ERI Reference Home for RValue
  end

  def self.set_systems_hvac(orig_details, hpxml)
    # HeatingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatingSystem") do |orig_heating|
      orig_heating_values = HPXML.get_heating_system_values(heating_system: orig_heating)

      distribution_system_id = nil
      if XMLHelper.has_element(orig_heating, "DistributionSystem")
        distribution_system_id = orig_heating_values[:distribution_system_idref]
      end
      hvac_type = orig_heating_values[:heating_system_type]
      hvac_fuel = orig_heating_values[:heating_system_fuel]
      hvac_frac = orig_heating_values[:fraction_heat_load_served]
      hvac_units = nil
      hvac_value = nil
      if ["Furnace", "WallFurnace", "Boiler"].include? hvac_type
        hvac_year = orig_heating_values[:year_installed]
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

      new_heating = HPXML.add_heating_system(hpxml: hpxml,
                                             id: orig_heating_values[:id],
                                             distribution_system_idref: distribution_system_id,
                                             heating_system_type: hvac_type,
                                             heating_system_fuel: hvac_fuel,
                                             heating_capacity: -1, # Use Manual J auto-sizing
                                             annual_heating_efficiency_units: hvac_units,
                                             annual_heating_efficiency_value: hvac_value,
                                             fraction_heat_load_served: hvac_frac)
    end

    # CoolingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/CoolingSystem") do |orig_cooling|
      orig_cooling_values = HPXML.get_cooling_system_values(cooling_system: orig_cooling)

      distribution_system_id = nil
      if XMLHelper.has_element(orig_cooling, "DistributionSystem")
        distribution_system_id = orig_cooling_values[:distribution_system_idref]
      end
      hvac_type = orig_cooling_values[:cooling_system_type]
      hvac_frac = orig_cooling_values[:fraction_cool_load_served]
      hvac_units = nil
      hvac_value = nil
      if hvac_type == "central air conditioning"
        hvac_year = orig_cooling_values[:year_installed]
        hvac_value = XMLHelper.get_value(orig_cooling, "AnnualCoolingEfficiency[Units='SEER']/Value")
        hvac_units = "SEER"
        if not hvac_year.nil?
          hvac_value = get_default_central_ac_seer(Integer(hvac_year))
        else
          hvac_value = Float(hvac_value)
        end
      elsif hvac_type == "room air conditioner"
        hvac_year = orig_cooling_values[:year_installed]
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

      new_cooling = HPXML.add_cooling_system(hpxml: hpxml,
                                             id: orig_cooling_values[:id],
                                             distribution_system_idref: distribution_system_id,
                                             cooling_system_type: hvac_type,
                                             cooling_system_fuel: "electricity",
                                             cooling_capacity: -1, # Use Manual J auto-sizing
                                             fraction_cool_load_served: hvac_frac,
                                             annual_cooling_efficiency_units: hvac_units,
                                             annual_cooling_efficiency_value: hvac_value)
    end

    # HeatPump
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatPump") do |orig_hp|
      orig_hp_values = HPXML.get_heat_pump_values(heat_pump: orig_hp)

      distribution_system_id = nil
      if XMLHelper.has_element(orig_hp, "DistributionSystem")
        distribution_system_id = orig_hp_values[:distribution_system_idref]
      end
      hvac_type = orig_hp_values[:heat_pump_type]
      hvac_frac_heat = orig_hp_values[:fraction_heat_load_served]
      hvac_frac_cool = orig_hp_values[:fraction_cool_load_served]
      hvac_units_heat = nil
      hvac_value_heat = nil
      hvac_units_cool = nil
      hvac_value_cool = nil
      if ["air-to-air", "mini-split"].include? hvac_type
        hvac_year = orig_hp_values[:year_installed]
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
        hvac_year = orig_hp_values[:year_installed]
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

      new_hp = HPXML.add_heat_pump(hpxml: hpxml,
                                   id: orig_hp_values[:id],
                                   distribution_system_idref: distribution_system_id,
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
    new_hvac_control = HPXML.add_hvac_control(hpxml: hpxml,
                                              id: "HVACControl",
                                              control_type: "manual thermostat")

    # HVACDistribution
    orig_details.elements.each("Systems/HVAC/HVACDistribution") do |orig_dist|
      orig_dist_values = HPXML.get_hvac_distribution_values(hvac_distribution: orig_dist)
      ducts_sealed = Boolean(orig_dist_values[:duct_system_sealed])

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

      dist_id = HPXML.get_id(orig_dist)
      new_dist = HPXML.add_hvac_distribution(hpxml: hpxml,
                                             id: dist_id,
                                             distribution_system_type: "AirDistribution")
      new_air_dist = new_dist.elements["DistributionSystemType/AirDistribution"]
      
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
        orig_duct_values = HPXML.get_ducts_values(ducts: orig_duct)
        hpxml_v23_to_v30_map = { "conditioned space" => "living space",
                                 "unconditioned basement" => "basement - unconditioned",
                                 "unvented crawlspace" => "crawlspace - unvented",
                                 "vented crawlspace" => "crawlspace - vented",
                                 "unconditioned attic" => "attic - vented" } # FIXME: Change to "attic - unconditioned"
        duct_location = orig_duct_values[:duct_location]
        duct_insulated = Boolean(orig_duct_values[:hescore_ducts_insulated])

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
                                          duct_surface_area: Float(orig_duct_values[:duct_fraction_area]) * supply_duct_area)

        # Return duct
        new_supply_duct = HPXML.add_ducts(air_distribution: new_air_dist,
                                          duct_type: "return",
                                          duct_insulation_r_value: duct_rvalue,
                                          duct_location: hpxml_v23_to_v30_map[duct_location],
                                          duct_surface_area: Float(orig_duct_values[:duct_fraction_area]) * return_duct_area)
      end
    end
  end

  def self.set_systems_mechanical_ventilation(orig_details, hpxml)
    # No mechanical ventilation
  end

  def self.set_systems_water_heater(orig_details, hpxml)
    orig_details.elements.each("Systems/WaterHeating/WaterHeatingSystem") do |orig_wh_sys|
      orig_wh_sys_values = HPXML.get_water_heating_system_values(water_heating_system: orig_wh_sys)
      wh_year = orig_wh_sys_values[:year_installed]
      wh_ef = orig_wh_sys_values[:energy_factor]
      wh_fuel = orig_wh_sys_values[:fuel_type]
      wh_type = orig_wh_sys_values[:water_heater_type]

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
      if wh_type == "storage water heater" and wh_fuel != "electricity"
        wh_recovery_efficiency = get_default_water_heater_re(wh_fuel)
      end
      new_wh_sys = HPXML.add_water_heating_system(hpxml: hpxml,
                                                  id: orig_wh_sys_values[:id],
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

  def self.set_systems_water_heating_use(hpxml)
    new_hw_dist = HPXML.add_hot_water_distribution(hpxml: hpxml,
                                                   id: "HotWaterDistribution",
                                                   system_type: "Standard", # FIXME: Verify
                                                   pipe_r_value: 0) # FIXME: Verify

    new_fixture = HPXML.add_water_fixture(hpxml: hpxml,
                                          id: "ShowerHead",
                                          water_fixture_type: "shower head",
                                          low_flow: false) # FIXME: Verify
  end

  def self.set_systems_photovoltaics(orig_details, hpxml)
    return if not XMLHelper.has_element(orig_details, "Systems/Photovoltaics")

    orig_pv_system_values = HPXML.get_pv_system_values(pv_system: orig_details.elements["Systems/Photovoltaics/PVSystem"])
    pv_power = orig_pv_system_values[:max_power_output]
    pv_num_panels = orig_pv_system_values[:hescore_num_panels]

    if not pv_power.nil?
      pv_power = Float(pv_power)
    else
      pv_power = Float(pv_num_panels) * 300.0 # FIXME: Hard-coded
    end

    new_pv = HPXML.add_pv_system(hpxml: hpxml,
                                 id: "PVSystem",
                                 module_type: "standard", # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                                 array_type: "fixed roof mount", # FIXME: Verify. HEScore was using "fixed open rack"??
                                 array_azimuth: orientation_to_azimuth(orig_pv_system_values[:array_orientation]),
                                 array_tilt: 30, # FIXME: Verify. From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                                 max_power_output: pv_power,
                                 inverter_efficiency: 0.96, # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                                 system_losses_fraction: 0.14) # FIXME: Verify
  end

  def self.set_appliances_clothes_washer(hpxml)
    new_washer = HPXML.add_clothes_washer(hpxml: hpxml,
                                          id: "ClothesWasher")
    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_clothes_dryer(hpxml)
    new_dryer = HPXML.add_clothes_dryer(hpxml: hpxml,
                                        id: "ClothesDryer",
                                        fuel_type: "electricity") # FIXME: Verify
    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_dishwasher(hpxml)
    new_dishwasher = HPXML.add_dishwasher(hpxml: hpxml,
                                          id: "Dishwasher")
    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_refrigerator(hpxml)
    new_fridge = HPXML.add_refrigerator(hpxml: hpxml,
                                        id: "Refrigerator")
    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_cooking_range_oven(hpxml)
    new_range = HPXML.add_cooking_range(hpxml: hpxml,
                                        id: "CookingRange",
                                        fuel_type: "electricity") # FIXME: Verify

    new_oven = HPXML.add_oven(hpxml: hpxml,
                              id: "Oven")
    # Uses ERI Reference Home for performance
  end

  def self.set_lighting(orig_details, hpxml)
    # Uses ERI Reference Home
  end

  def self.set_ceiling_fans(orig_details, hpxml)
    # No ceiling fans
  end

  def self.set_misc_plug_loads(hpxml)
    new_plug_load = HPXML.add_plug_load(hpxml: hpxml,
                                        id: "PlugLoadOther",
                                        plug_load_type: "other")
    # Uses ERI Reference Home for performance
  end

  def self.set_misc_television(hpxml)
    new_plug_load = HPXML.add_plug_load(hpxml: hpxml,
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
    next if attached_name != HPXML.get_id(other_element)

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
