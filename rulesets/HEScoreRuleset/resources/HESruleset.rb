require 'csv'
require_relative "../../../hpxml-measures/HPXMLtoOpenStudio/resources/airflow"
require_relative "../../../hpxml-measures/HPXMLtoOpenStudio/resources/constructions"
require_relative "../../../hpxml-measures/HPXMLtoOpenStudio/resources/geometry"
require_relative "../../../hpxml-measures/HPXMLtoOpenStudio/resources/hotwater_appliances"
require_relative "../../../hpxml-measures/HPXMLtoOpenStudio/resources/hpxml"
require_relative "../../../hpxml-measures/HPXMLtoOpenStudio/resources/lighting"
require_relative "../../../hpxml-measures/HPXMLtoOpenStudio/resources/pv"

class HEScoreRuleset
  def self.apply_ruleset(hpxml_doc)
    orig_details = hpxml_doc.elements["/HPXML/Building/BuildingDetails"]

    # Create new HPXML doc
    hpxml_values = HPXML.get_hpxml_values(hpxml: hpxml_doc.elements["/HPXML"])
    hpxml_doc = HPXML.create_hpxml(xml_type: hpxml_values[:xml_type],
                                   xml_generated_by: hpxml_values[:xml_generated_by],
                                   transaction: hpxml_values[:transaction],
                                   eri_calculation_version: "2014AEG",
                                   building_id: hpxml_values[:building_id],
                                   event_type: hpxml_values[:event_type])
    hpxml = hpxml_doc.elements["HPXML"]

    # BuildingSummary
    set_summary(orig_details, hpxml)

    # ClimateAndRiskZones
    set_climate(orig_details, hpxml)

    # Enclosure
    set_enclosure_air_infiltration(orig_details, hpxml)
    set_enclosure_roofs(orig_details, hpxml)
    set_enclosure_rim_joists(orig_details, hpxml)
    set_enclosure_walls(orig_details, hpxml)
    set_enclosure_foundation_walls(orig_details, hpxml)
    set_enclosure_framefloors(orig_details, hpxml)
    set_enclosure_slabs(orig_details, hpxml)
    set_enclosure_windows(orig_details, hpxml)
    set_enclosure_skylights(orig_details, hpxml)
    set_enclosure_doors(orig_details, hpxml)

    # Systems
    set_systems_hvac(orig_details, hpxml)
    set_systems_mechanical_ventilation(orig_details, hpxml)
    set_systems_water_heater(orig_details, hpxml)
    set_systems_water_heating_use(orig_details, hpxml)
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

  def self.set_summary(orig_details, hpxml)
    # Get HPXML values
    @state_code = orig_details.root().elements["/HPXML/Building/Site/Address/StateCode"].text

    orig_site_values = HPXML.get_site_values(site: orig_details.elements["BuildingSummary/Site"])
    @bldg_orient = orig_site_values[:orientation_of_front_of_home]
    @bldg_azimuth = orientation_to_azimuth(@bldg_orient)

    orig_building_construction_values = HPXML.get_building_construction_values(building_construction: orig_details.elements["BuildingSummary/BuildingConstruction"])
    @year_built = orig_building_construction_values[:year_built]
    @nbeds = orig_building_construction_values[:number_of_bedrooms]
    @cfa = orig_building_construction_values[:conditioned_floor_area] # ft^2
    @is_townhouse = (orig_building_construction_values[:residential_facility_type] == 'single-family attached')
    @fnd_types = get_foundation_details(orig_details)
    @ducts = get_ducts_details(orig_details)
    @cfa_basement = @fnd_types["basement - conditioned"]
    @cfa_basement = 0 if @cfa_basement.nil?
    @ncfl_ag = orig_building_construction_values[:number_of_conditioned_floors_above_grade]
    @ceil_height = orig_building_construction_values[:average_ceiling_height] # ft

    # Calculate geometry
    # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope
    @has_cond_bsmnt = @fnd_types.keys.include?("basement - conditioned")
    @has_uncond_bsmnt = @fnd_types.keys.include?("basement - unconditioned")
    @ncfl = @ncfl_ag + (@has_cond_bsmnt ? 1 : 0)
    @nfl = @ncfl + (@has_uncond_bsmnt ? 1 : 0)
    @bldg_footprint = (@cfa - @cfa_basement) / @ncfl_ag # ft^2
    @bldg_length_side = (3.0 * @bldg_footprint / 5.0)**0.5 # ft
    @bldg_length_front = (5.0 / 3.0) * @bldg_length_side # ft
    if @is_townhouse
      @bldg_length_front, @bldg_length_side = @bldg_length_side, @bldg_length_front
    end
    @bldg_perimeter = 2.0 * @bldg_length_front + 2.0 * @bldg_length_side # ft
    @roof_angle = 30.0 # deg
    @roof_angle_rad = UnitConversions.convert(@roof_angle, "deg", "rad") # radians
    @cvolume = @cfa * @ceil_height
    orig_details.elements.each("Enclosure/Attics/Attic") do |orig_attic|
      is_conditioned_attic = XMLHelper.has_element(orig_attic, "AtticType/Attic[Conditioned='true']")
      is_cathedral_ceiling = XMLHelper.has_element(orig_attic, "AtticType/CathedralCeiling")
      if is_conditioned_attic or is_cathedral_ceiling
        roof_id = HPXML.get_idref(orig_attic, "AttachedToRoof")
        roof = orig_details.elements["Enclosure/Roofs/Roof[SystemIdentifier[@id='#{roof_id}']]"]
        roof_values = HPXML.get_roof_values(roof: roof)

        # Half of the length of short side of the house
        a = 0.5 * [@bldg_length_front, @bldg_length_side].min
        # Ridge height
        b = a * Math.tan(@roof_angle_rad)
        # The hypotenuse
        c = a / Math.cos(@roof_angle_rad)
        # The depth this attic area goes back on the non-gable side
        d = 0.5 * roof_values[:area] / c

        if is_conditioned_attic
          # Remove erroneous full height volume from the conditioned volume
          @cvolume -= @ceil_height * 2 * a * d
        end

        # Add the volume under the roof and above the "ceiling"
        @cvolume += d * a * b
      end
    end

    HPXML.add_site(hpxml: hpxml,
                   fuels: ["electricity"], # TODO Check if changing this would ever influence results; if it does, talk to Leo
                   shelter_coefficient: Airflow.get_default_shelter_coefficient())

    # Neighboring buildings to left/right, 12ft offset, same height as building.
    # FIXME: Verify. What about townhouses?
    HPXML.add_site_neighbor(hpxml: hpxml,
                            azimuth: sanitize_azimuth(@bldg_azimuth + 90.0),
                            distance: 20.0,
                            height: 12.0)
    HPXML.add_site_neighbor(hpxml: hpxml,
                            azimuth: sanitize_azimuth(@bldg_azimuth - 90.0),
                            distance: 20.0,
                            height: 12.0)

    HPXML.add_building_occupancy(hpxml: hpxml,
                                 number_of_residents: Geometry.get_occupancy_default_num(@nbeds))

    HPXML.add_building_construction(hpxml: hpxml,
                                    number_of_conditioned_floors: @ncfl,
                                    number_of_conditioned_floors_above_grade: @ncfl_ag,
                                    number_of_bedrooms: @nbeds,
                                    conditioned_floor_area: @cfa,
                                    conditioned_building_volume: @cvolume)
  end

  def self.set_climate(orig_details, hpxml)
    climate_values = HPXML.get_climate_and_risk_zones_values(climate_and_risk_zones: orig_details.elements["ClimateandRiskZones"])
    HPXML.add_climate_and_risk_zones(hpxml: hpxml,
                                     weather_station_id: climate_values[:weather_station_id],
                                     weather_station_name: climate_values[:weather_station_name],
                                     weather_station_wmo: climate_values[:weather_station_wmo])
    @iecc_zone = climate_values[:iecc2012]
  end

  def self.set_enclosure_air_infiltration(orig_details, hpxml)
    air_infil_values = HPXML.get_air_infiltration_measurement_values(air_infiltration_measurement: orig_details.elements["Enclosure/AirInfiltration/AirInfiltrationMeasurement"])
    cfm50 = air_infil_values[:air_leakage]
    desc = air_infil_values[:leakiness_description]

    # Convert to ACH50
    if not cfm50.nil?
      ach50 = cfm50 * 60.0 / @cvolume
    else
      ach50 = calc_ach50(@ncfl_ag, @cfa, @ceil_height, @cvolume, desc, @year_built, @iecc_zone, @fnd_types, @ducts)
    end

    HPXML.add_air_infiltration_measurement(hpxml: hpxml,
                                           id: air_infil_values[:id],
                                           house_pressure: 50,
                                           unit_of_measure: "ACH",
                                           air_leakage: ach50)
  end

  def self.set_enclosure_roofs(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Attics/Attic") do |orig_attic|
      attic_adjacent = get_attic_adjacent(orig_attic)

      # Roof: Two surfaces per HES zone_roof
      roof_id = HPXML.get_idref(orig_attic, "AttachedToRoof")
      roof = orig_details.elements["Enclosure/Roofs/Roof[SystemIdentifier[@id='#{roof_id}']]"]
      roof_values = HPXML.get_roof_values(roof: roof)
      roof_area = roof_values[:area]
      if roof_values[:solar_absorptance].nil?
        roof_values[:solar_absorptance] = get_roof_solar_absorptance(roof_values[:roof_color])
      end
      roof_r = get_roof_assembly_r(roof_values[:insulation_cavity_r_value],
                                   roof_values[:insulation_continuous_r_value],
                                   roof_values[:roof_type],
                                   roof_values[:radiant_barrier])
      if roof_area.nil?
        floor_id = HPXML.get_idref(orig_attic, "AttachedToFrameFloor")
        frame_floor_area = Float(orig_details.elements["Enclosure/FrameFloors/FrameFloor[SystemIdentifier/@id='#{floor_id}']/Area/text()"].to_s)
        roof_area = frame_floor_area / (2. * Math.cos(@roof_angle_rad)) if roof_area.nil?
      end
      if @is_townhouse
        roof_azimuths = [@bldg_azimuth + 90, @bldg_azimuth + 270]
      else
        roof_azimuths = [@bldg_azimuth, @bldg_azimuth + 180]
      end
      roof_azimuths.each_with_index do |roof_azimuth, idx|
        HPXML.add_roof(hpxml: hpxml,
                       id: "#{roof_values[:id]}_#{idx}",
                       interior_adjacent_to: attic_adjacent,
                       area: roof_area / 2.0,
                       azimuth: sanitize_azimuth(roof_azimuth),
                       solar_absorptance: roof_values[:solar_absorptance],
                       emittance: 0.9, # ERI assumption; TODO get values from method
                       pitch: Math.tan(@roof_angle_rad) * 12,
                       radiant_barrier: false,
                       insulation_assembly_r_value: roof_r)
      end
    end
  end

  def self.set_enclosure_rim_joists(orig_details, hpxml)
    # No rim joists
  end

  def self.set_enclosure_walls(orig_details, hpxml)
    # Above-grade walls
    orig_details.elements.each("Enclosure/Walls/Wall") do |orig_wall|
      wall_values = HPXML.get_wall_values(wall: orig_wall)

      wall_area = nil
      if @bldg_orient == wall_values[:orientation] or @bldg_orient == reverse_orientation(wall_values[:orientation])
        wall_area = @ceil_height * @bldg_length_front * @ncfl_ag # FIXME: Verify
      else
        wall_area = @ceil_height * @bldg_length_side * @ncfl_ag # FIXME: Verify
      end

      if wall_values[:wall_type] == "WoodStud"
        wall_r = get_wood_stud_wall_assembly_r(wall_values[:insulation_cavity_r_value],
                                               wall_values[:insulation_continuous_r_value],
                                               wall_values[:siding],
                                               wall_values[:optimum_value_engineering])
      elsif wall_values[:wall_type] == "StructuralBrick"
        wall_r = get_structural_block_wall_assembly_r(wall_values[:insulation_continuous_r_value])
      elsif wall_values[:wall_type] == "ConcreteMasonryUnit"
        wall_r = get_concrete_block_wall_assembly_r(wall_values[:insulation_cavity_r_value],
                                                    wall_values[:siding])
      elsif wall_values[:wall_type] == "StrawBale"
        wall_r = get_straw_bale_wall_assembly_r(wall_values[:siding])
      else
        fail "Unexpected wall type '#{wall_values[:wall_type]}'."
      end

      HPXML.add_wall(hpxml: hpxml,
                     id: wall_values[:id],
                     exterior_adjacent_to: "outside",
                     interior_adjacent_to: "living space",
                     wall_type: wall_values[:wall_type],
                     area: wall_area,
                     azimuth: orientation_to_azimuth(wall_values[:orientation]),
                     solar_absorptance: 0.75, # ERI assumption; TODO get values from method
                     emittance: 0.9, # ERI assumption; TODO get values from method
                     insulation_assembly_r_value: wall_r)
    end
  end

  def self.get_foundation_perimeter(foundation)
    n_foundations = foundation.parent.elements.size
    if n_foundations == 1
      return @bldg_perimeter
    elsif n_foundations == 2
      fnd_area = get_foundation_area(foundation)
      long_side = [@bldg_length_front, @bldg_length_side].max
      short_side = [@bldg_length_front, @bldg_length_side].min
      total_foundation_area = 0
      foundation.parent.elements.each do |a_foundation|
        total_foundation_area += get_foundation_area(a_foundation)
      end
      fnd_frac = fnd_area / total_foundation_area
      return short_side + 2 * long_side * fnd_frac
    else
      fail "Only one or two foundations is allowed."
    end
  end

  def self.set_enclosure_foundation_walls(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
      fnd_adjacent = get_foundation_adjacent(orig_foundation)
      fnd_area = get_foundation_area(orig_foundation)

      if ["basement - unconditioned", "basement - conditioned", "crawlspace - vented", "crawlspace - unvented"].include? fnd_adjacent
        fndwall_id = HPXML.get_idref(orig_foundation, "AttachedToFoundationWall")
        fndwall = orig_details.elements["Enclosure/FoundationWalls/FoundationWall[SystemIdentifier[@id='#{fndwall_id}']]"]
        fndwall_values = HPXML.get_foundation_wall_values(foundation_wall: fndwall)
        # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/doe2-inputs-assumptions-and-calculations/the-doe2-model
        if ["basement - unconditioned", "basement - conditioned"].include? fnd_adjacent
          fndwall_height = 8.0
        else
          fndwall_height = 2.5
        end

        HPXML.add_foundation_wall(hpxml: hpxml,
                                  id: fndwall_values[:id],
                                  exterior_adjacent_to: "ground",
                                  interior_adjacent_to: fnd_adjacent,
                                  height: fndwall_height,
                                  area: fndwall_height * get_foundation_perimeter(orig_foundation),
                                  thickness: 10,
                                  depth_below_grade: fndwall_height - 1.0,
                                  insulation_interior_r_value: 0,
                                  insulation_interior_distance_to_top: 0,
                                  insulation_interior_distance_to_bottom: 0,
                                  insulation_exterior_r_value: fndwall_values[:insulation_r_value],
                                  insulation_exterior_distance_to_top: 0,
                                  insulation_exterior_distance_to_bottom: fndwall_height)
      end
    end
  end

  def self.set_enclosure_framefloors(orig_details, hpxml)
    # Floors above foundation
    orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
      fnd_adjacent = get_foundation_adjacent(orig_foundation)

      framefloor_id = HPXML.get_idref(orig_foundation, "AttachedToFrameFloor")
      framefloor = orig_details.elements["Enclosure/FrameFloors/FrameFloor[SystemIdentifier[@id='#{framefloor_id}']]"]
      framefloor_values = HPXML.get_framefloor_values(framefloor: framefloor)
      if ["basement - unconditioned", "crawlspace - vented", "crawlspace - unvented"].include? fnd_adjacent
        framefloor_r = get_floor_assembly_r(framefloor_values[:insulation_cavity_r_value])

        HPXML.add_framefloor(hpxml: hpxml,
                             id: framefloor_values[:id],
                             exterior_adjacent_to: fnd_adjacent,
                             interior_adjacent_to: "living space",
                             area: framefloor_values[:area],
                             insulation_assembly_r_value: framefloor_r)
      end
    end

    # Floors below attic
    orig_details.elements.each("Enclosure/Attics/Attic") do |orig_attic|
      attic_adjacent = get_attic_adjacent(orig_attic)

      fail "Unvented attics should't exist in HEScore." if attic_adjacent == "attic - unvented"

      if attic_adjacent == "attic - vented"
        framefloor_id = HPXML.get_idref(orig_attic, "AttachedToFrameFloor")
        framefloor = orig_details.elements["Enclosure/FrameFloors/FrameFloor[SystemIdentifier[@id='#{framefloor_id}']]"]
        framefloor_values = HPXML.get_framefloor_values(framefloor: framefloor)
        framefloor_r = get_ceiling_assembly_r(framefloor_values[:insulation_cavity_r_value])

        HPXML.add_framefloor(hpxml: hpxml,
                             id: framefloor_values[:id],
                             exterior_adjacent_to: attic_adjacent,
                             interior_adjacent_to: "living space",
                             area: framefloor_values[:area],
                             insulation_assembly_r_value: framefloor_r)
      end
    end
  end

  def self.set_enclosure_slabs(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
      fnd_adjacent = get_foundation_adjacent(orig_foundation)
      fnd_type = XMLHelper.get_child_name(orig_foundation, "FoundationType")
      fnd_area = get_foundation_area(orig_foundation)

      # Slab
      if fnd_type == "SlabOnGrade"
        slab_id = HPXML.get_idref(orig_foundation, "AttachedToSlab")
        slab = orig_details.elements["Enclosure/Slabs/Slab[SystemIdentifier[@id='#{slab_id}']]"]
        slab_values = HPXML.get_slab_values(slab: slab)
        slab_values[:depth_below_grade] = 0
        slab_values[:thickness] = 4
      elsif fnd_type == "Basement"
        framefloor_id = HPXML.get_idref(orig_foundation, "AttachedToFrameFloor")
        framefloor = orig_details.elements["Enclosure/FrameFloors/FrameFloor[SystemIdentifier[@id='#{framefloor_id}']]"]
        framefloor_values = HPXML.get_framefloor_values(framefloor: framefloor)

        slab_values = {}
        slab_values[:id] = "#{HPXML.get_id(orig_foundation)}_slab"
        slab_values[:area] = framefloor_values[:area]
        slab_values[:perimeter_insulation_r_value] = 0
        slab_values[:thickness] = 4
      elsif fnd_type == "Crawlspace"
        framefloor_id = HPXML.get_idref(orig_foundation, "AttachedToFrameFloor")
        framefloor = orig_details.elements["Enclosure/FrameFloors/FrameFloor[SystemIdentifier[@id='#{framefloor_id}']]"]
        framefloor_values = HPXML.get_framefloor_values(framefloor: framefloor)

        slab_values = {}
        slab_values[:id] = "#{HPXML.get_id(orig_foundation)}_slab"
        slab_values[:area] = framefloor_values[:area]
        slab_values[:perimeter_insulation_r_value] = 0
        slab_values[:thickness] = 0
      else
        fail "Unexpected foundation type: #{fnd_type}"
      end

      HPXML.add_slab(hpxml: hpxml,
                     id: slab_values[:id],
                     interior_adjacent_to: fnd_adjacent,
                     area: slab_values[:area],
                     thickness: slab_values[:thickness],
                     exposed_perimeter: get_foundation_perimeter(orig_foundation),
                     perimeter_insulation_depth: 2,
                     under_slab_insulation_width: 0,
                     depth_below_grade: slab_values[:depth_below_grade],
                     carpet_fraction: 1.0,
                     carpet_r_value: 2.1,
                     perimeter_insulation_r_value: slab_values[:perimeter_insulation_r_value],
                     under_slab_insulation_r_value: 0)
    end
  end

  def self.set_enclosure_windows(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Windows/Window") do |orig_window|
      window_values = HPXML.get_window_values(window: orig_window)

      if window_values[:ufactor].nil?
        window_frame_type = window_values[:frame_type]
        if window_frame_type == "Aluminum" and window_values[:aluminum_thermal_break]
          window_frame_type = "AluminumThermalBreak"
        end
        window_values[:ufactor], window_values[:shgc] = get_window_ufactor_shgc(window_frame_type,
                                                                                window_values[:glass_layers],
                                                                                window_values[:glass_type],
                                                                                window_values[:gas_fill])
      end

      interior_shading_factor_summer, interior_shading_factor_winter = Constructions.get_default_interior_shading_factors()
      if window_values[:exterior_shading] == "solar screens"
        interior_shading_factor_summer = 0.29
      end

      # Add one HPXML window per side of the house with only the overhangs from the roof.
      HPXML.add_window(
        hpxml: hpxml,
        id: window_values[:id],
        area: window_values[:area],
        azimuth: orientation_to_azimuth(window_values[:orientation]),
        ufactor: window_values[:ufactor],
        shgc: window_values[:shgc],
        overhangs_depth: 1.0,
        overhangs_distance_to_top_of_window: 0.0,
        overhangs_distance_to_bottom_of_window: @ceil_height * @ncfl_ag,
        wall_idref: window_values[:wall_idref],
        interior_shading_factor_summer: interior_shading_factor_summer,
        interior_shading_factor_winter: interior_shading_factor_winter
      )
      # Uses ERI Reference Home for interior shading
    end
  end

  def self.set_enclosure_skylights(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Skylights/Skylight") do |orig_skylight|
      skylight_values = HPXML.get_skylight_values(skylight: orig_skylight)

      if skylight_values[:ufactor].nil?
        skylight_frame_type = skylight_values[:frame_type]
        if skylight_frame_type == "Aluminum" and skylight_values[:aluminum_thermal_break]
          skylight_frame_type = "AluminumThermalBreak"
        end
        skylight_values[:ufactor], skylight_values[:shgc] = get_skylight_ufactor_shgc(skylight_frame_type,
                                                                                      skylight_values[:glass_layers],
                                                                                      skylight_values[:glass_type],
                                                                                      skylight_values[:gas_fill])
      end

      if skylight_values[:exterior_shading] == "solar screens"
        skylight_values[:shgc] *= 0.29
      end

      hpxml.elements.each('Building/BuildingDetails/Enclosure/Roofs/Roof') do |roof|
        roof_values = HPXML.get_roof_values(roof: roof)
        next unless roof_values[:id].start_with?(skylight_values[:roof_idref])

        skylight_area = skylight_values[:area] / 2.0
        HPXML.add_skylight(hpxml: hpxml,
                           id: "#{skylight_values[:id]}_#{roof_values[:id]}",
                           area: skylight_area,
                           azimuth: roof_values[:azimuth],
                           ufactor: skylight_values[:ufactor],
                           shgc: skylight_values[:shgc],
                           roof_idref: roof_values[:id])
      end
    end
  end

  def self.set_enclosure_doors(orig_details, hpxml)
    front_wall = nil
    orig_details.elements.each("Enclosure/Walls/Wall") do |orig_wall|
      wall_values = HPXML.get_wall_values(wall: orig_wall)
      next if wall_values[:orientation] != @bldg_orient

      front_wall = orig_wall
    end
    fail "Could not find front wall." if front_wall.nil?

    ufactor, shgc = Constructions.get_default_ufactor_shgc(@iecc_zone)

    front_wall_values = HPXML.get_wall_values(wall: front_wall)
    HPXML.add_door(hpxml: hpxml,
                   id: "Door",
                   wall_idref: front_wall_values[:id],
                   area: Constructions.get_default_door_area(),
                   azimuth: orientation_to_azimuth(@bldg_orient),
                   r_value: 1.0 / ufactor)
  end

  def self.set_systems_hvac(orig_details, hpxml)
    additional_hydronic_ids = []

    # HeatingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatingSystem") do |orig_heating|
      heating_values = HPXML.get_heating_system_values(heating_system: orig_heating)
      heating_values[:heating_capacity] = -1 # Use Manual J auto-sizing

      # Need to create hydronic distribution system?
      if heating_values[:heating_system_type] == "Boiler" and heating_values[:distribution_system_idref].nil?
        heating_values[:distribution_system_idref] = heating_values[:id] + "_dist"
        additional_hydronic_ids << heating_values[:distribution_system_idref]
      end

      if ["Furnace", "WallFurnace"].include? heating_values[:heating_system_type]
        if not heating_values[:heating_efficiency_afue].nil?
          # Do nothing, we already have the AFUE
        elsif heating_values[:heating_system_fuel] == "electricity"
          heating_values[:heating_efficiency_afue] = 0.98
        elsif heating_values[:energy_star] and heating_values[:heating_system_type] == "Furnace"
          heating_values[:heating_efficiency_afue] = lookup_hvac_efficiency(
            heating_values[:year_installed],
            heating_values[:heating_system_type],
            heating_values[:heating_system_fuel],
            "AFUE",
            "energy_star",
            @state_code
          )
        elsif not heating_values[:year_installed].nil?
          heating_values[:heating_efficiency_afue] = lookup_hvac_efficiency(
            heating_values[:year_installed],
            heating_values[:heating_system_type],
            heating_values[:heating_system_fuel],
            "AFUE"
          )
        end

      elsif heating_values[:heating_system_type] == "Boiler"
        if not heating_values[:heating_efficiency_afue].nil?
          # Do nothing, we already have the AFUE
        elsif heating_values[:heating_system_fuel] == "electricity"
          heating_values[:heating_efficiency_afue] = 0.98
        elsif heating_values[:energy_star]
          heating_values[:heating_efficiency_afue] = lookup_hvac_efficiency(
            heating_values[:year_installed],
            heating_values[:heating_system_type],
            heating_values[:heating_system_fuel],
            "AFUE",
            "energy_star"
          )
        elsif not heating_values[:year_installed].nil?
          heating_values[:heating_efficiency_afue] = lookup_hvac_efficiency(
            heating_values[:year_installed],
            heating_values[:heating_system_type],
            heating_values[:heating_system_fuel],
            "AFUE"
          )
        end

      elsif heating_values[:heating_system_type] == "ElectricResistance"
        if heating_values[:heating_efficiency_percent].nil?
          heating_values[:heating_efficiency_percent] = 0.98
        end

      elsif heating_values[:heating_system_type] == "Stove"
        if not heating_values[:heating_efficiency_percent].nil?
          # Do nothing, we already have the heating efficiency percent
        elsif heating_values[:heating_system_fuel] == "wood"
          heating_values[:heating_efficiency_percent] = 0.60
        elsif heating_values[:heating_system_fuel] == "wood pellets"
          heating_values[:heating_efficiency_percent] = 0.78
        end
      end

      HPXML.add_heating_system(hpxml: hpxml,
                               id: heating_values[:id],
                               distribution_system_idref: heating_values[:distribution_system_idref],
                               heating_system_type: heating_values[:heating_system_type],
                               heating_system_fuel: heating_values[:heating_system_fuel],
                               heating_capacity: heating_values[:heating_capacity],
                               heating_efficiency_afue: heating_values[:heating_efficiency_afue],
                               heating_efficiency_percent: heating_values[:heating_efficiency_percent],
                               fraction_heat_load_served: heating_values[:fraction_heat_load_served])
    end

    # CoolingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/CoolingSystem") do |orig_cooling|
      cooling_values = HPXML.get_cooling_system_values(cooling_system: orig_cooling)
      cooling_values[:cooling_system_fuel] = "electricity"
      if cooling_values[:cooling_system_type] != "evaporative cooler"
        cooling_values[:cooling_capacity] = -1 # Use Manual J auto-sizing
      end

      if cooling_values[:cooling_system_type] == "central air conditioner"
        if not cooling_values[:cooling_efficiency_seer].nil?
          # Do nothing, we already have the SEER
        elsif cooling_values[:energy_star]
          cooling_values[:cooling_efficiency_seer] = lookup_hvac_efficiency(
            cooling_values[:year_installed],
            cooling_values[:cooling_system_type],
            cooling_values[:cooling_system_fuel],
            "SEER",
            "energy_star"
          )
        elsif not cooling_values[:year_installed].nil?
          cooling_values[:cooling_efficiency_seer] = lookup_hvac_efficiency(
            cooling_values[:year_installed],
            cooling_values[:cooling_system_type],
            cooling_values[:cooling_system_fuel],
            "SEER"
          )
        end

      elsif cooling_values[:cooling_system_type] == "room air conditioner"
        if not cooling_values[:cooling_efficiency_eer].nil?
          # Do nothing, we already have the EER
        elsif cooling_values[:energy_star]
          cooling_values[:cooling_efficiency_eer] = lookup_hvac_efficiency(
            cooling_values[:year_installed],
            cooling_values[:cooling_system_type],
            cooling_values[:cooling_system_fuel],
            "EER",
            "energy_star"
          )
        elsif not cooling_values[:year_installed].nil?
          cooling_values[:cooling_efficiency_eer] = lookup_hvac_efficiency(
            cooling_values[:year_installed],
            cooling_values[:cooling_system_type],
            cooling_values[:cooling_system_fuel],
            "EER"
          )
        end
      end

      HPXML.add_cooling_system(hpxml: hpxml,
                               id: cooling_values[:id],
                               distribution_system_idref: cooling_values[:distribution_system_idref],
                               cooling_system_type: cooling_values[:cooling_system_type],
                               cooling_system_fuel: cooling_values[:cooling_system_fuel],
                               cooling_capacity: cooling_values[:cooling_capacity],
                               fraction_cool_load_served: cooling_values[:fraction_cool_load_served],
                               cooling_efficiency_seer: cooling_values[:cooling_efficiency_seer],
                               cooling_efficiency_eer: cooling_values[:cooling_efficiency_eer])
    end

    # HeatPump
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatPump") do |orig_hp|
      hp_values = HPXML.get_heat_pump_values(heat_pump: orig_hp)
      hp_values[:heat_pump_fuel] = "electricity"
      hp_values[:cooling_capacity] = -1 # Use Manual J auto-sizing
      hp_values[:heating_capacity] = -1 # Use Manual J auto-sizing
      hp_values[:backup_heating_fuel] = "electricity"
      hp_values[:backup_heating_capacity] = -1 # Use Manual J auto-sizing
      hp_values[:backup_heating_efficiency_percent] = 1.0

      if hp_values[:heat_pump_type] == "air-to-air"
        if not hp_values[:cooling_efficiency_seer].nil?
          # Do nothing, we have the SEER
        elsif hp_values[:energy_star]
          hp_values[:cooling_efficiency_seer] = lookup_hvac_efficiency(
            hp_values[:year_installed],
            hp_values[:heat_pump_type],
            hp_values[:heat_pump_fuel],
            "SEER",
            "energy_star"
          )
        elsif not hp_values[:year_installed].nil?
          hp_values[:cooling_efficiency_seer] = lookup_hvac_efficiency(
            hp_values[:year_installed],
            hp_values[:heat_pump_type],
            hp_values[:heat_pump_fuel],
            "SEER"
          )
        end
        if not hp_values[:heating_efficiency_hspf].nil?
          # Do nothing, we have the HSPF
        elsif hp_values[:energy_star]
          hp_values[:heating_efficiency_hspf] = lookup_hvac_efficiency(
            hp_values[:year_installed],
            hp_values[:heat_pump_type],
            hp_values[:heat_pump_fuel],
            "HSPF",
            "energy_star"
          )
        elsif not hp_values[:year_installed].nil?
          hp_values[:heating_efficiency_hspf] = lookup_hvac_efficiency(
            hp_values[:year_installed],
            hp_values[:heat_pump_type],
            hp_values[:heat_pump_fuel],
            "HSPF"
          )
        end
      end

      # If heat pump has no cooling/heating load served, assign arbitrary value for cooling/heating efficiency value
      if hp_values[:fraction_cool_load_served] == 0 and hp_values[:cooling_efficiency_seer].nil? and hp_values[:cooling_efficiency_eer].nil?
        if hp_values[:heat_pump_type] == "ground-to-air"
          hp_values[:cooling_efficiency_eer] = 16.6
        else
          hp_values[:cooling_efficiency_seer] = 13.0
        end
      end
      if hp_values[:fraction_heat_load_served] == 0 and hp_values[:heating_efficiency_hspf].nil? and hp_values[:heating_efficiency_cop].nil?
        if hp_values[:heat_pump_type] == "ground-to-air"
          hp_values[:heating_efficiency_cop] = 3.6
        else
          hp_values[:heating_efficiency_hspf] = 7.7
        end
      end

      HPXML.add_heat_pump(hpxml: hpxml,
                          id: hp_values[:id],
                          distribution_system_idref: hp_values[:distribution_system_idref],
                          heat_pump_type: hp_values[:heat_pump_type],
                          heat_pump_fuel: hp_values[:heat_pump_fuel],
                          heating_capacity: hp_values[:heating_capacity],
                          cooling_capacity: hp_values[:cooling_capacity],
                          backup_heating_fuel: hp_values[:backup_heating_fuel],
                          backup_heating_capacity: hp_values[:backup_heating_capacity],
                          backup_heating_efficiency_percent: hp_values[:backup_heating_efficiency_percent],
                          fraction_heat_load_served: hp_values[:fraction_heat_load_served],
                          fraction_cool_load_served: hp_values[:fraction_cool_load_served],
                          cooling_efficiency_seer: hp_values[:cooling_efficiency_seer],
                          cooling_efficiency_eer: hp_values[:cooling_efficiency_eer],
                          heating_efficiency_hspf: hp_values[:heating_efficiency_hspf],
                          heating_efficiency_cop: hp_values[:heating_efficiency_cop])
    end

    # HVACControl
    control_type = "manual thermostat"
    htg_sp, htg_setback_sp, htg_setback_hrs_per_week, htg_setback_start_hr = HVAC.get_default_heating_setpoint(control_type)
    clg_sp, clg_setup_sp, clg_setup_hrs_per_week, clg_setup_start_hr = HVAC.get_default_cooling_setpoint(control_type)
    HPXML.add_hvac_control(hpxml: hpxml,
                           id: "HVACControl",
                           control_type: control_type,
                           heating_setpoint_temp: htg_sp,
                           cooling_setpoint_temp: clg_sp)

    # HVACDistribution
    orig_details.elements.each("Systems/HVAC/HVACDistribution") do |orig_dist|
      dist_values = HPXML.get_hvac_distribution_values(hvac_distribution: orig_dist)

      new_dist = HPXML.add_hvac_distribution(hpxml: hpxml,
                                             id: dist_values[:id],
                                             distribution_system_type: "AirDistribution")
      new_air_dist = new_dist.elements["DistributionSystemType/AirDistribution"]

      frac_inside = 0.0
      orig_dist.elements.each("DistributionSystemType/AirDistribution/Ducts") do |orig_duct|
        duct_values = HPXML.get_ducts_values(ducts: orig_duct)
        next unless duct_values[:duct_location] == "living space"

        frac_inside += duct_values[:duct_fraction_area]
      end

      sealed = dist_values[:duct_system_sealed]
      lto_s, lto_r, uncond_area_s, uncond_area_r = calc_duct_values(@ncfl_ag, @cfa, sealed, frac_inside)

      # Supply duct leakage to the outside
      HPXML.add_duct_leakage_measurement(air_distribution: new_air_dist,
                                         duct_type: "supply",
                                         duct_leakage_units: "Percent",
                                         duct_leakage_value: lto_s)

      # Return duct leakage to the outside
      HPXML.add_duct_leakage_measurement(air_distribution: new_air_dist,
                                         duct_type: "return",
                                         duct_leakage_units: "Percent",
                                         duct_leakage_value: lto_r)

      orig_dist.elements.each("DistributionSystemType/AirDistribution/Ducts") do |orig_duct|
        duct_values = HPXML.get_ducts_values(ducts: orig_duct)
        next if duct_values[:duct_location] == "living space"

        if duct_values[:duct_location] == "attic - unconditioned"
          duct_values[:duct_location] = "attic - vented"
        end

        if duct_values[:duct_insulation_material] == "Unknown"
          duct_rvalue = 6
        elsif duct_values[:duct_insulation_material] == "None"
          duct_rvalue = 0
        else
          fail "Unexpected duct insulation material '#{duct_values[:duct_insulation_material]}'."
        end

        supply_duct_surface_area = uncond_area_s * duct_values[:duct_fraction_area] / (1.0 - frac_inside)
        return_duct_surface_area = uncond_area_r * duct_values[:duct_fraction_area] / (1.0 - frac_inside)

        # Supply duct
        HPXML.add_ducts(air_distribution: new_air_dist,
                        duct_type: "supply",
                        duct_insulation_r_value: duct_rvalue,
                        duct_location: duct_values[:duct_location],
                        duct_surface_area: supply_duct_surface_area)

        # Return duct
        HPXML.add_ducts(air_distribution: new_air_dist,
                        duct_type: "return",
                        duct_insulation_r_value: duct_rvalue,
                        duct_location: duct_values[:duct_location],
                        duct_surface_area: return_duct_surface_area)
      end
    end

    additional_hydronic_ids.each do |hydronic_id|
      HPXML.add_hvac_distribution(hpxml: hpxml,
                                  id: hydronic_id,
                                  distribution_system_type: "HydronicDistribution")
    end
  end

  def self.set_systems_mechanical_ventilation(orig_details, hpxml)
    # No mechanical ventilation
  end

  def self.set_systems_water_heater(orig_details, hpxml)
    orig_details.elements.each("Systems/WaterHeating/WaterHeatingSystem") do |orig_wh_sys|
      wh_sys_values = HPXML.get_water_heating_system_values(water_heating_system: orig_wh_sys)

      if not wh_sys_values[:energy_factor].nil? or not wh_sys_values[:uniform_energy_factor].nil?
        # Do nothing, we already have the energy factor
      elsif wh_sys_values[:energy_star]
        wh_sys_values[:energy_factor] = lookup_water_heater_efficiency(
          wh_sys_values[:year_installed],
          wh_sys_values[:fuel_type],
          "energy_star"
        )
      elsif not wh_sys_values[:year_installed].nil?
        wh_sys_values[:energy_factor] = lookup_water_heater_efficiency(
          wh_sys_values[:year_installed],
          wh_sys_values[:fuel_type]
        )
      end

      fail "Water Heater Type must be provided" if wh_sys_values[:water_heater_type].nil?
      fail "Electric water heaters must be heat pump water heaters to be Energy Star qualified" if wh_sys_values[:energy_star] and wh_sys_values[:fuel_type] == 'electricity' and wh_sys_values[:water_heater_type] != 'heat pump water heater'

      wh_capacity = nil
      if wh_sys_values[:water_heater_type] == "storage water heater"
        wh_capacity = get_default_water_heater_capacity(wh_sys_values[:fuel_type])
      end
      wh_recovery_efficiency = nil
      if wh_sys_values[:water_heater_type] == "storage water heater" and wh_sys_values[:fuel_type] != "electricity"
        ef = wh_sys_values[:energy_factor]
        if ef.nil?
          ef = 0.9066 * wh_sys_values[:uniform_energy_factor] + 0.0711 # RESNET equation for Consumer Gas-Fired Water Heater
        end
        wh_recovery_efficiency = get_default_water_heater_re(wh_sys_values[:fuel_type], ef)
      end
      wh_tank_volume = nil
      if wh_sys_values[:water_heater_type] == "space-heating boiler with storage tank"
        wh_tank_volume = get_default_water_heater_volume("electricity")
      # Set default fuel_type to call function : get_default_water_heater_volume, not passing this input to EP-HPXML
      elsif wh_sys_values[:water_heater_type] != "instantaneous water heater" and wh_sys_values[:water_heater_type] != "space-heating boiler with tankless coil"
        wh_tank_volume = get_default_water_heater_volume(wh_sys_values[:fuel_type])
      end

      # Water heater location
      if @has_cond_bsmnt
        water_heater_location = "basement - conditioned"
      elsif @has_uncond_bsmnt
        water_heater_location = "basement - unconditioned"
      else
        water_heater_location = "living space"
      end
      HPXML.add_water_heating_system(hpxml: hpxml,
                                     id: wh_sys_values[:id],
                                     fuel_type: wh_sys_values[:fuel_type],
                                     water_heater_type: wh_sys_values[:water_heater_type],
                                     location: water_heater_location,
                                     tank_volume: wh_tank_volume,
                                     fraction_dhw_load_served: 1.0,
                                     heating_capacity: wh_capacity,
                                     energy_factor: wh_sys_values[:energy_factor],
                                     uniform_energy_factor: wh_sys_values[:uniform_energy_factor],
                                     recovery_efficiency: wh_recovery_efficiency,
                                     related_hvac: wh_sys_values[:related_hvac])
    end
  end

  def self.set_systems_water_heating_use(orig_details, hpxml)
    # Hot water piping length
    piping_length = HotWaterAndAppliances.get_default_std_pipe_length(@has_uncond_bsmnt, @cfa, @ncfl)

    HPXML.add_hot_water_distribution(hpxml: hpxml,
                                     id: "HotWaterDistribution",
                                     system_type: "Standard",
                                     pipe_r_value: 0,
                                     standard_piping_length: piping_length)

    HPXML.add_water_fixture(hpxml: hpxml,
                            id: "ShowerHead",
                            water_fixture_type: "shower head",
                            low_flow: false)
  end

  def self.set_systems_photovoltaics(orig_details, hpxml)
    pv_values = HPXML.get_pv_system_values(pv_system: orig_details.elements["Systems/Photovoltaics/PVSystem"])
    return if pv_values.nil?

    if pv_values[:max_power_output].nil?
      # Estimate from year and # modules
      module_power = PV.calc_module_power_from_year(pv_values[:year_modules_manufactured]) # W/panel
      pv_values[:max_power_output] = pv_values[:number_of_panels] * module_power
    end

    # Estimate PV panel losses from year
    losses_fraction = PV.calc_losses_fraction_from_year(pv_values[:year_modules_manufactured])

    HPXML.add_pv_system(hpxml: hpxml,
                        id: "PVSystem",
                        location: "roof",
                        module_type: "standard", # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                        tracking: "fixed",
                        array_azimuth: orientation_to_azimuth(pv_values[:array_orientation]),
                        array_tilt: @roof_angle,
                        max_power_output: pv_values[:max_power_output],
                        inverter_efficiency: 0.96, # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                        system_losses_fraction: losses_fraction)
  end

  def self.set_appliances_clothes_washer(hpxml)
    HPXML.add_clothes_washer(hpxml: hpxml,
                             id: "ClothesWasher",
                             location: "living space",
                             integrated_modified_energy_factor: HotWaterAndAppliances.get_clothes_washer_reference_imef(),
                             rated_annual_kwh: HotWaterAndAppliances.get_clothes_washer_reference_ler(),
                             label_electric_rate: HotWaterAndAppliances.get_clothes_washer_reference_elec_rate(),
                             label_gas_rate: HotWaterAndAppliances.get_clothes_washer_reference_gas_rate(),
                             label_annual_gas_cost: HotWaterAndAppliances.get_clothes_washer_reference_agc(),
                             capacity: HotWaterAndAppliances.get_clothes_washer_reference_cap())
  end

  def self.set_appliances_clothes_dryer(hpxml)
    HPXML.add_clothes_dryer(hpxml: hpxml,
                            id: "ClothesDryer",
                            location: "living space",
                            fuel_type: "electricity",
                            combined_energy_factor: HotWaterAndAppliances.get_clothes_dryer_reference_cef('electricity'),
                            control_type: HotWaterAndAppliances.get_clothes_dryer_reference_control())
  end

  def self.set_appliances_dishwasher(hpxml)
    HPXML.add_dishwasher(hpxml: hpxml,
                         id: "Dishwasher",
                         energy_factor: HotWaterAndAppliances.get_dishwasher_reference_ef(),
                         place_setting_capacity: HotWaterAndAppliances.get_dishwasher_reference_cap())
  end

  def self.set_appliances_refrigerator(hpxml)
    HPXML.add_refrigerator(hpxml: hpxml,
                           id: "Refrigerator",
                           location: "living space",
                           rated_annual_kwh: HotWaterAndAppliances.get_refrigerator_reference_annual_kwh(@nbeds))
  end

  def self.set_appliances_cooking_range_oven(hpxml)
    HPXML.add_cooking_range(hpxml: hpxml,
                            id: "CookingRange",
                            fuel_type: "electricity",
                            is_induction: HotWaterAndAppliances.get_range_oven_reference_is_induction())

    HPXML.add_oven(hpxml: hpxml,
                   id: "Oven",
                   is_convection: HotWaterAndAppliances.get_range_oven_reference_is_convection())
  end

  def self.set_lighting(orig_details, hpxml)
    fFI_int, fFI_ext, fFI_grg, fFII_int, fFII_ext, fFII_grg = Lighting.get_reference_fractions()
    HPXML.add_lighting(hpxml: hpxml,
                       fraction_tier_i_interior: fFI_int,
                       fraction_tier_i_exterior: fFI_ext,
                       fraction_tier_i_garage: fFI_grg,
                       fraction_tier_ii_interior: fFII_int,
                       fraction_tier_ii_exterior: fFII_ext,
                       fraction_tier_ii_garage: fFII_grg)
  end

  def self.set_ceiling_fans(orig_details, hpxml)
    # No ceiling fans
  end

  def self.set_misc_plug_loads(hpxml)
    HPXML.add_plug_load(hpxml: hpxml,
                        id: "PlugLoadOther",
                        plug_load_type: "other")
    # Uses ERI Reference Home for performance
  end

  def self.set_misc_television(hpxml)
    HPXML.add_plug_load(hpxml: hpxml,
                        id: "PlugLoadTV",
                        plug_load_type: "TV other")
    # Uses ERI Reference Home for performance
  end
end

def lookup_hvac_efficiency(year, hvac_type, fuel_type, units, performance_id = 'shipment_weighted', state_code = nil)
  year = 0 if year.nil?

  type_id = { 'central air conditioner' => 'split_dx',
              'room air conditioner' => 'packaged_dx',
              'air-to-air' => 'heat_pump',
              'Furnace' => 'central_furnace',
              'WallFurnace' => 'wall_furnace',
              'Boiler' => 'boiler' }[hvac_type]
  fail "Unexpected hvac_type #{hvac_type}." if type_id.nil?

  fuel_primary_id = hpxml_to_hescore_fuel(fuel_type)
  fail "Unexpected fuel_type #{fuel_type}." if fuel_primary_id.nil?

  metric_id = units.downcase

  fail "Invalid performance_id for HVAC lookup #{performance_id}." if not ['shipment_weighted', 'energy_star'].include?(performance_id)

  region_id = nil
  if performance_id == 'energy_star' and type_id == 'central_furnace' and ['lpg', 'natural_gas'].include? fuel_primary_id
    fail "state_code required for Energy Star central furnaces" if state_code.nil?

    CSV.foreach(File.join(File.dirname(__FILE__), "lu_es_furnace_region.csv"), headers: true) do |row|
      next unless row['state_code'] == state_code

      region_id = row['furnace_region']
      break
    end
    fail "Could not lookup Energy Star furnace region for state #{state_code}." if region_id.nil?
  end

  value = nil
  lookup_year = 0
  CSV.foreach(File.join(File.dirname(__FILE__), "lu_hvac_equipment_efficiency.csv"), headers: true) do |row|
    next unless row['performance_id'] == performance_id
    next unless row['type_id'] == type_id
    next unless row['fuel_primary_id'] == fuel_primary_id
    next unless row['metric_id'] == metric_id
    next unless row['region_id'] == region_id

    row_year = Integer(row['year'])
    if (row_year - year).abs <= (lookup_year - year).abs
      lookup_year = row_year
      value = Float(row['value'])
    end
  end
  fail "Could not lookup default HVAC efficiency." if value.nil?

  return value
end

def lookup_water_heater_efficiency(year, fuel_type, performance_id = 'shipment_weighted')
  year = 0 if year.nil?

  fuel_primary_id = hpxml_to_hescore_fuel(fuel_type)
  fail "Unexpected fuel_type #{fuel_type}." if fuel_primary_id.nil?

  fail "Invalid performance_id for water heater lookup #{performance_id}." if not ['shipment_weighted', 'energy_star'].include?(performance_id)

  value = nil
  lookup_year = 0
  CSV.foreach(File.join(File.dirname(__FILE__), "lu_water_heater_efficiency.csv"), headers: true) do |row|
    next unless row['performance_id'] == performance_id
    next unless row['fuel_primary_id'] == fuel_primary_id

    row_year = Integer(row['year'])
    if (row_year - year).abs <= (lookup_year - year).abs
      lookup_year = row_year
      value = Float(row['value'])
    end
  end
  fail "Could not lookup default water heating efficiency." if value.nil?

  return value
end

def get_default_water_heater_volume(fuel)
  # Water Heater Tank Volume by fuel
  val = { "electricity" => 50,
          "natural gas" => 40,
          "propane" => 40,
          "fuel oil" => 32 }[fuel]
  return val if not val.nil?

  fail "Could not get default water heater volume for fuel '#{fuel}'"
end

def get_default_water_heater_re(fuel, ef)
  # Water Heater Recovery Efficiency by fuel and energy factor
  val = nil
  if fuel == "electricity"
    val = 0.98
  elsif ef >= 0.75
    val = 0.778114 * ef + 0.276679
  else
    val = 0.252117 * ef + 0.607997
  end
  return val if not val.nil?

  fail "Could not get default water heater RE for fuel '#{fuel}'"
end

def get_default_water_heater_capacity(fuel)
  # Water Heater Rated Input Capacity by fuel
  val = { "electricity" => 15400,
          "natural gas" => 38000,
          "propane" => 38000,
          "fuel oil" => 90000 }[fuel]
  return val if not val.nil?

  fail "Could not get default water heater capacity for fuel '#{fuel}'"
end

def get_wall_effective_r_from_doe2code(doe2code)
  val = nil
  CSV.foreach(File.join(File.dirname(__FILE__), "lu_wall_eff_rvalue.csv"), headers: true) do |row|
    next unless row["doe2code"] == doe2code

    val = Float(row["Eff-R-value"])
    break
  end
  return val
end

$siding_map = {
  "wood siding" => "wo",
  "stucco" => "st",
  "vinyl siding" => "vi",
  "aluminum siding" => "al",
  "brick veneer" => "br",
  nil => "nn"
}

def get_wood_stud_wall_assembly_r(r_cavity, r_cont, siding, ove)
  # Walls Wood Stud Assembly R-value
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  has_r_cont = !r_cont.nil?
  if not has_r_cont and not ove
    # Wood Frame
    doe2walltype = "wf"
  elsif has_r_cont and not ove
    # Wood Frame with Rigid Foam Sheathing
    doe2walltype = "ps"
  elsif not has_r_cont and ove
    # Wood Frame with Optimal Value Engineering
    doe2walltype = "ov"
  end
  doe2code = "ew%s%02.0f%s" % [doe2walltype, r_cavity, $siding_map[siding]]
  val = get_wall_effective_r_from_doe2code(doe2code)
  return val if not val.nil?

  fail "Could not get default wood stud wall assembly R-value for R-cavity '#{r_cavity}' and R-cont '#{r_cont}' and siding '#{siding}' and ove '#{ove}'"
end

def get_structural_block_wall_assembly_r(r_cont)
  # Walls Structural Block Assembly R-value
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  doe2code = "ewbr%02.0fnn" % (r_cont.nil? ? 0.0 : r_cont)
  val = get_wall_effective_r_from_doe2code(doe2code)
  return val if not val.nil?

  fail "Could not get default structural block wall assembly R-value for R-cavity '#{r_cont}'"
end

def get_concrete_block_wall_assembly_r(r_cavity, siding)
  # Walls Concrete Block Assembly R-value
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  doe2code = "ewcb%02.0f%s" % [r_cavity, $siding_map[siding]]
  val = get_wall_effective_r_from_doe2code(doe2code)
  return val if not val.nil?

  fail "Could not get default concrete block wall assembly R-value for R-cavity '#{r_cavity}' and siding '#{siding}'"
end

def get_straw_bale_wall_assembly_r(siding)
  # Walls Straw Bale Assembly R-value
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  doe2code = "ewsb00%s" % $siding_map[siding]
  val = get_wall_effective_r_from_doe2code(doe2code)
  return val if not val.nil?

  fail "Could not get default straw bale assembly R-value for siding '#{siding}'"
end

def get_roof_effective_r_from_doe2code(doe2code)
  val = nil
  CSV.foreach(File.join(File.dirname(__FILE__), "lu_roof_eff_rvalue.csv"), headers: true) do |row|
    next unless row["doe2code"] == doe2code

    val = Float(row["Eff-R-value"])
    break
  end
  return val
end

def get_roof_assembly_r(r_cavity, r_cont, material, has_radiant_barrier)
  # Roof Assembly R-value
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/roof-construction-types
  materials_map = {
    "asphalt or fiberglass shingles" => "co",    # Composition Shingles
    "wood shingles or shakes" => "wo",           # Wood Shakes
    "slate or tile shingles" => "rc",            # Clay Tile
    "concrete" => "lc",                          # Concrete Tile
    "plastic/rubber/synthetic sheeting" => "tg"  # Tar and Gravel
  }
  has_r_cont = !r_cont.nil?
  if not has_r_cont and not has_radiant_barrier
    # Wood Frame
    doe2rooftype = "wf"
  elsif not has_r_cont and has_radiant_barrier
    # Wood Frame with Radiant Barrier
    doe2rooftype = "rb"
  elsif has_r_cont and not has_radiant_barrier
    # Wood Frame with Rigid Foam Sheathing
    doe2rooftype = "ps"
  end

  doe2code = "rf%s%02.0f%s" % [doe2rooftype, r_cavity, materials_map[material]]
  val = get_roof_effective_r_from_doe2code(doe2code)

  return val if not val.nil?

  fail "Could not get default roof assembly R-value for R-cavity '#{r_cavity}' and R-cont '#{r_cont}' and material '#{material}' and radiant barrier '#{has_radiant_barrier}'"
end

def get_ceiling_assembly_r(r_cavity)
  # Ceiling Assembly R-value
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/ceiling-construction-types
  val = { 0.0 => 2.2,              # ecwf00
          3.0 => 5.0,              # ecwf03
          6.0 => 7.6,              # ecwf06
          9.0 => 10.0,             # ecwf09
          11.0 => 10.9,            # ecwf11
          19.0 => 19.2,            # ecwf19
          21.0 => 21.3,            # ecwf21
          25.0 => 25.6,            # ecwf25
          30.0 => 30.3,            # ecwf30
          38.0 => 38.5,            # ecwf38
          44.0 => 43.5,            # ecwf44
          49.0 => 50.0,            # ecwf49
          60.0 => 58.8 }[r_cavity] # ecwf60
  return val if not val.nil?

  fail "Could not get default ceiling assembly R-value for R-cavity '#{r_cavity}'"
end

def get_floor_assembly_r(r_cavity)
  # Floor Assembly R-value
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/floor-construction-types
  val = { 0.0 => 5.9,              # efwf00ca
          11.0 => 15.6,            # efwf11ca
          13.0 => 17.2,            # efwf13ca
          15.0 => 18.5,            # efwf15ca
          19.0 => 22.2,            # efwf19ca
          21.0 => 23.8,            # efwf21ca
          25.0 => 27.0,            # efwf25ca
          30.0 => 31.3,            # efwf30ca
          38.0 => 37.0 }[r_cavity] # efwf38ca
  return val if not val.nil?

  fail "Could not get default floor assembly R-value for R-cavity '#{r_cavity}'"
end

def get_window_ufactor_shgc(frame_type, glass_layers, glass_type, gas_fill)
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
  # Skylight U-factor/SHGC
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
  val = { "reflective" => 0.35,
          "light" => 0.55,
          "medium" => 0.7,
          "medium dark" => 0.8,
          "dark" => 0.9 }[roof_color]
  return val if not val.nil?

  fail "Could not get roof absorptance for color '#{roof_color}'"
end

def calc_duct_values(ncfl_ag, cfa, is_sealed, frac_inside)
  # Total leakage fraction of air handler flow
  if is_sealed
    total_leakage_frac = 0.10
  else
    total_leakage_frac = 0.25
  end

  # Fraction of ducts that are outside conditioned space
  if frac_inside > 0
    f_out_s = 1.0 - frac_inside
  else
    # Make assumption
    if ncfl_ag == 1
      f_out_s = 1.0
    else
      f_out_s = 0.65
    end
  end
  if frac_inside == 1
    f_out_r = 0.0
  else
    f_out_r = 1.0
  end

  # Duct leakages to the outside (assume total leakage equally split between supply/return)
  lto_s = total_leakage_frac / 2.0 * f_out_s
  lto_r = total_leakage_frac / 2.0 * f_out_r

  # Duct surface areas that are outside conditioned space
  uncond_area_s = 0.27 * f_out_s * cfa
  uncond_area_r = 0.05 * ncfl_ag * f_out_r * cfa

  return lto_s.round(5), lto_r.round(5), uncond_area_s.round(2), uncond_area_r.round(2)
end

def calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/infiltration/infiltration

  # Constants
  c_floor_area = -0.002078
  c_height = 0.06375

  # Vintage
  c_vintage = nil
  if year_built < 1960
    c_vintage = -0.2498
  elsif year_built <= 1969
    c_vintage = -0.4327
  elsif year_built <= 1979
    c_vintage = -0.4521
  elsif year_built <= 1989
    c_vintage = -0.6536
  elsif year_built <= 1999
    c_vintage = -0.9152
  elsif year_built >= 2000
    c_vintage = -1.058
  else
    fail "Unexpected vintage: #{year_built}"
  end

  # Climate zone
  c_iecc = nil
  if iecc_cz == "1A" or iecc_cz == "2A"
    c_iecc = 0.4727
  elsif iecc_cz == "3A"
    c_iecc = 0.2529
  elsif iecc_cz == "4A"
    c_iecc = 0.3261
  elsif iecc_cz == "5A"
    c_iecc = 0.1118
  elsif iecc_cz == "6A" or iecc_cz == "7"
    c_iecc = 0.0
  elsif iecc_cz == "2B" or iecc_cz == "3B"
    c_iecc = -0.03755
  elsif iecc_cz == "4B" or iecc_cz == "5B"
    c_iecc = -0.008774
  elsif iecc_cz == "6B"
    c_iecc = 0.01944
  elsif iecc_cz == "3C"
    c_iecc = 0.04827
  elsif iecc_cz == "4C"
    c_iecc = 0.2584
  elsif iecc_cz == "8"
    c_iecc = -0.5119
  else
    fail "Unexpected IECC climate zone: #{c_iecc}"
  end

  # Foundation type (weight by area)
  c_foundation = 0.0
  sum_fnd_area = 0.0
  fnd_types.each do |fnd_type, area|
    sum_fnd_area += area
    if fnd_type == "living space"
      c_foundation += -0.036992 * area
    elsif fnd_type == "basement - conditioned" or fnd_type == "crawlspace - unvented"
      c_foundation += 0.108713 * area
    elsif fnd_type == "basement - unconditioned" or fnd_type == "crawlspace - vented"
      c_foundation += 0.180352 * area
    else
      fail "Unexpected foundation type: #{fnd_type}"
    end
  end
  c_foundation /= sum_fnd_area

  # Ducts (weighted by duct fraction and hvac fraction)
  c_duct = 0.0
  ducts.each do |hvac_frac, duct_frac, duct_location|
    if duct_location == "living space"
      c_duct += -0.12381 * duct_frac * hvac_frac
    elsif duct_location == "attic - unconditioned" or duct_location == "basement - unconditioned"
      c_duct += 0.07126 * duct_frac * hvac_frac
    elsif duct_location == "crawlspace - vented"
      c_duct += 0.18072 * duct_frac * hvac_frac
    elsif duct_location == "crawlspace - unvented"
      c_duct += 0.07126 * duct_frac * hvac_frac
    else
      fail "Unexpected duct location: #{duct_location}"
    end
  end

  c_sealed = nil
  if desc == "tight"
    c_sealed = -0.288
  elsif desc == "average"
    c_sealed = 0.0
  else
    fail "Unexpected air leakage description: #{desc}"
  end

  floor_area_m2 = UnitConversions.convert(cfa, "ft^2", "m^2")
  height_m = UnitConversions.convert(ncfl_ag * ceil_height, "ft", "m") + 0.5

  # Normalized leakage
  nl = Math.exp(floor_area_m2 * c_floor_area +
                height_m * c_height +
                c_sealed + c_vintage + c_iecc + c_foundation + c_duct)

  # Specific Leakage Area
  sla = nl / (1000.0 * ncfl_ag**0.3)

  ach50 = Airflow.get_infiltration_ACH50_from_SLA(sla, 0.65, cfa, cvolume)

  return ach50
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

def reverse_orientation(orientation)
  # Converts, e.g., "northwest" to "southeast"
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

def sanitize_azimuth(azimuth)
  # Ensure 0 <= orientation < 360
  while azimuth < 0
    azimuth += 360
  end
  while azimuth >= 360
    azimuth -= 360
  end
  return azimuth
end

def hpxml_to_hescore_fuel(fuel_type)
  return { 'electricity' => 'electric',
           'natural gas' => 'natural_gas',
           'fuel oil' => 'fuel_oil',
           'propane' => 'lpg' }[fuel_type]
end

def get_foundation_details(orig_details)
  # Returns a hash of foundation_type => area
  fnd_types = {}
  orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
    fnd_adjacent = get_foundation_adjacent(orig_foundation)
    framefloor_id = HPXML.get_idref(orig_foundation, "AttachedToFrameFloor")
    if not framefloor_id.nil?
      framefloor = orig_details.elements["Enclosure/FrameFloors/FrameFloor[SystemIdentifier[@id='#{framefloor_id}']]"]
      framefloor_values = HPXML.get_framefloor_values(framefloor: framefloor)
      fnd_area = framefloor_values[:area]
    else
      slab_id = HPXML.get_idref(orig_foundation, "AttachedToSlab")
      slab = orig_details.elements["Enclosure/Slabs/Slab[SystemIdentifier[@id='#{slab_id}']]"]
      slab_values = HPXML.get_slab_values(slab: slab)
      fnd_area = slab_values[:area]
    end
    fnd_types[fnd_adjacent] = fnd_area
  end
  return fnd_types
end

def get_ducts_details(orig_details)
  # Returns a list of [hvac_frac, duct_frac, duct_location]
  ducts = []
  orig_details.elements.each("Systems/HVAC/HVACDistribution") do |orig_dist|
    dist_values = HPXML.get_hvac_distribution_values(hvac_distribution: orig_dist)
    hvac_frac = get_hvac_fraction(orig_details, dist_values[:id])

    orig_dist.elements.each("DistributionSystemType/AirDistribution/Ducts") do |orig_duct|
      duct_values = HPXML.get_ducts_values(ducts: orig_duct)
      ducts << [hvac_frac, duct_values[:duct_fraction_area], duct_values[:duct_location]]
    end
  end
  return ducts
end

def get_hvac_fraction(orig_details, dist_id)
  orig_details.elements.each("Systems/HVAC/HVACPlant/HeatingSystem") do |orig_heating|
    heating_values = HPXML.get_heating_system_values(heating_system: orig_heating)
    next unless heating_values[:distribution_system_idref] == dist_id

    return heating_values[:fraction_heat_load_served]
  end
  orig_details.elements.each("Systems/HVAC/HVACPlant/CoolingSystem") do |orig_cooling|
    cooling_values = HPXML.get_cooling_system_values(cooling_system: orig_cooling)
    next unless cooling_values[:distribution_system_idref] == dist_id

    return cooling_values[:fraction_cool_load_served]
  end
  orig_details.elements.each("Systems/HVAC/HVACPlant/HeatPump") do |orig_hp|
    hp_values = HPXML.get_heat_pump_values(heat_pump: orig_hp)
    next unless hp_values[:distribution_system_idref] == dist_id

    return hp_values[:fraction_cool_load_served]
  end
  return nil
end

def get_attic_adjacent(attic)
  attic_adjacent = nil
  if XMLHelper.has_element(attic, "AtticType/Attic[Vented='false']")
    attic_adjacent = "attic - unvented"
  elsif XMLHelper.has_element(attic, "AtticType/Attic[Vented='true']")
    attic_adjacent = "attic - vented"
  elsif XMLHelper.has_element(attic, "AtticType/Attic[Conditioned='true']")
    attic_adjacent = "living space"
  elsif XMLHelper.has_element(attic, "AtticType/FlatRoof")
    attic_adjacent = "living space"
  elsif XMLHelper.has_element(attic, "AtticType/CathedralCeiling")
    attic_adjacent = "living space"
  else
    fail "Unexpected attic type."
  end
  return attic_adjacent
end

def get_foundation_adjacent(foundation)
  foundation_adjacent = nil
  if XMLHelper.has_element(foundation, "FoundationType/SlabOnGrade")
    foundation_adjacent = "living space"
  elsif XMLHelper.has_element(foundation, "FoundationType/Basement[Conditioned='false']")
    foundation_adjacent = "basement - unconditioned"
  elsif XMLHelper.has_element(foundation, "FoundationType/Basement[Conditioned='true']")
    foundation_adjacent = "basement - conditioned"
  elsif XMLHelper.has_element(foundation, "FoundationType/Crawlspace[Vented='false']")
    foundation_adjacent = "crawlspace - unvented"
  elsif XMLHelper.has_element(foundation, "FoundationType/Crawlspace[Vented='true']")
    foundation_adjacent = "crawlspace - vented"
  else
    fail "Unexpected foundation type."
  end
  return foundation_adjacent
end

def get_foundation_area(foundation)
  foundation_type = XMLHelper.get_child_name(foundation, "FoundationType")
  if foundation_type == "SlabOnGrade"
    slab_id = foundation.elements["AttachedToSlab/@idref"].value
    fail "Reference to slab required for SlabOnGrade foundation type." if slab_id.nil?

    area = REXML::XPath.first(
      foundation,
      "//Slab[SystemIdentifier/@id=$slabid]/Area/text()",
      { "" => foundation.namespace },
      { "slabid" => slab_id }
    )
    fail "Area required for Slab: #{slab_id}." if area.nil?
  elsif ["Basement", "Crawlspace"].include?(foundation_type)
    frame_floor_id = foundation.elements["AttachedToFrameFloor/@idref"].value
    fail "Reference to foundation floor required for #{foundation_type}." if frame_floor_id.nil?

    area = REXML::XPath.first(
      foundation,
      "//FrameFloor[SystemIdentifier/@id=$floorid]/Area/text()",
      { "" => foundation.namespace },
      { "floorid" => frame_floor_id }
    )
    fail "Area required for FrameFloor: #{frame_floor_id}." if area.nil?
  else
    fail "Unexpected foundation type: #{foundation_type}."
  end
  return Float(area.value)
end
