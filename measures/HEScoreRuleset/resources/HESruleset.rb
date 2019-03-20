require_relative "../../HPXMLtoOpenStudio/resources/airflow"
require_relative "../../HPXMLtoOpenStudio/resources/geometry"
require_relative "../../HPXMLtoOpenStudio/resources/hpxml"

class HEScoreRuleset
  def self.apply_ruleset(hpxml_doc)
    orig_details = hpxml_doc.elements["/HPXML/Building/BuildingDetails"]

    # Create new HPXML doc
    hpxml_values = HPXML.get_hpxml_values(hpxml: hpxml_doc.elements["/HPXML"])
    hpxml_values[:eri_calculation_version] = "2014AEG" # FIXME: Verify
    hpxml_doc = HPXML.create_hpxml(**hpxml_values)

    hpxml = hpxml_doc.elements["HPXML"]

    fnd_types, @cfa_basement = get_foundation_details(orig_details)

    # Global variables
    orig_building_construction_values = HPXML.get_building_construction_values(building_construction: orig_details.elements["BuildingSummary/BuildingConstruction"])
    orig_site_values = HPXML.get_site_values(site: orig_details.elements["BuildingSummary/Site"])
    @year_built = orig_building_construction_values[:year_built]
    @nbeds = orig_building_construction_values[:number_of_bedrooms]
    @cfa = orig_building_construction_values[:conditioned_floor_area] # ft^2
    @ncfl_ag = orig_building_construction_values[:number_of_conditioned_floors_above_grade]
    @ncfl = @ncfl_ag # Number above-grade stories plus any conditioned basement
    if fnd_types.include? "ConditionedBasement"
      @ncfl += 1
    end
    @nfl = @ncfl_ag # Number above-grade stories plus any basement
    if fnd_types.include? "ConditionedBasement" or fnd_types.include? "UnconditionedBasement"
      @nfl += 1
    end
    @ceil_height = orig_building_construction_values[:average_ceiling_height] # ft
    @bldg_orient = orig_site_values[:orientation_of_front_of_home]
    @bldg_azimuth = orientation_to_azimuth(@bldg_orient)

    # Calculate geometry
    # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope
    # FIXME: Verify. Does this change for shape=townhouse? Maybe ridge changes to front-back instead of left-right
    @bldg_footprint = (@cfa - @cfa_basement) / @ncfl_ag # ft^2
    @bldg_length_side = (3.0 * @bldg_footprint / 5.0)**0.5 # ft
    @bldg_length_front = (5.0 / 3.0) * @bldg_length_side # ft
    @bldg_perimeter = 2.0 * @bldg_length_front + 2.0 * @bldg_length_side # ft
    @cvolume = @cfa * @ceil_height # ft^3 FIXME: Verify. Should this change for cathedral ceiling, conditioned basement, etc.?
    @height = @ceil_height * @ncfl_ag # ft FIXME: Verify. Used for infiltration.
    @roof_angle = 30.0 # deg

    # BuildingSummary
    set_summary(hpxml)

    # ClimateAndRiskZones
    set_climate(orig_details, hpxml)

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
    # TODO: Neighboring buildings to left/right, 12ft offset, same height as building; what about townhouses?
    HPXML.add_site(hpxml: hpxml,
                   fuels: ["electricity"], # TODO Check if changing this would ever influence results; if it does, talk to Leo
                   shelter_coefficient: Airflow.get_default_shelter_coefficient())
    HPXML.add_building_occupancy(hpxml: hpxml,
                                 number_of_residents: Geometry.get_occupancy_default_num(@nbeds))
    HPXML.add_building_construction(hpxml: hpxml,
                                    number_of_conditioned_floors: @ncfl,
                                    number_of_conditioned_floors_above_grade: @ncfl_ag,
                                    number_of_bedrooms: @nbeds,
                                    conditioned_floor_area: @cfa,
                                    conditioned_building_volume: @cvolume,
                                    garage_present: false)
  end

  def self.set_climate(orig_details, hpxml)
    iecc_values = HPXML.get_climate_zone_iecc_values(climate_zone_iecc: orig_details.elements["ClimateandRiskZones/ClimateZoneIECC"])
    HPXML.add_climate_zone_iecc(hpxml: hpxml,
                                year: 2006,
                                climate_zone: iecc_values[:climate_zone])
    HPXML.add_climate_zone_iecc(hpxml: hpxml,
                                year: 2012,
                                climate_zone: iecc_values[:climate_zone])
    @iecc_zone = iecc_values[:climate_zone]

    weather_station_values = HPXML.get_weather_station_values(weather_station: orig_details.elements["ClimateandRiskZones/WeatherStation"])
    HPXML.add_weather_station(hpxml: hpxml, **weather_station_values)
  end

  def self.set_enclosure_air_infiltration(orig_details, hpxml)
    air_infil_values = HPXML.get_air_infiltration_measurement_values(air_infiltration_measurement: orig_details.elements["Enclosure/AirInfiltration/AirInfiltrationMeasurement"])
    cfm50 = air_infil_values[:air_leakage]
    desc = air_infil_values[:leakiness_description]

    # Convert to ACH50
    if not cfm50.nil?
      ach50 = cfm50 * 60.0 / @cvolume
    else
      ach50 = calc_ach50(@ncfl_ag, @cfa, @height, @cvolume, desc, @year_built, @iecc_zone, orig_details)
    end

    HPXML.add_air_infiltration_measurement(hpxml: hpxml,
                                           id: air_infil_values[:id],
                                           house_pressure: 50,
                                           unit_of_measure: "ACH",
                                           air_leakage: ach50)
  end

  def self.set_enclosure_attics_roofs(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Attics/Attic") do |orig_attic|
      attic_values = HPXML.get_attic_values(attic: orig_attic)
      new_attic = HPXML.add_attic(hpxml: hpxml, **attic_values)

      # Roof: Two surfaces per HES zone_roof
      roof_values = HPXML.get_attic_roof_values(roof: orig_attic.elements["Roofs/Roof"])
      if roof_values[:solar_absorptance].nil?
        roof_values[:solar_absorptance] = get_roof_solar_absorptance(roof_values[:roof_color])
      end
      roof_r = get_roof_assembly_r(roof_values[:insulation_cavity_r_value],
                                   roof_values[:insulation_continuous_r_value],
                                   roof_values[:roof_type],
                                   roof_values[:radiant_barrier])

      roof_azimuths = [@bldg_azimuth, @bldg_azimuth + 180] # FIXME: Verify
      roof_azimuths.each_with_index do |roof_azimuth, idx|
        HPXML.add_attic_roof(attic: new_attic,
                             id: "#{roof_values[:id]}_#{idx}",
                             area: 1000.0 / 2, # FIXME: Hard-coded. Use input if cathedral ceiling or conditioned attic, otherwise calculate default?
                             azimuth: sanitize_azimuth(roof_azimuth),
                             solar_absorptance: roof_values[:solar_absorptance],
                             emittance: 0.9, # ERI assumption; TODO get values from method
                             pitch: Math.tan(UnitConversions.convert(@roof_angle, "deg", "rad")) * 12,
                             radiant_barrier: false, # FIXME: Verify. Setting to false because it's included in the assembly R-value
                             insulation_id: "#{roof_values[:insulation_id]}_#{idx}",
                             insulation_assembly_r_value: roof_r)
      end

      # Floor
      if ["UnventedAttic", "VentedAttic"].include? attic_values[:attic_type]
        floor_values = HPXML.get_attic_floor_values(floor: orig_attic.elements["Floors/Floor"])
        floor_r = get_ceiling_assembly_r(floor_values[:insulation_cavity_r_value])

        HPXML.add_attic_floor(attic: new_attic,
                              id: "#{floor_values[:id]}_floor",
                              adjacent_to: "living space",
                              area: 1000.0, # FIXME: Hard-coded. Use input if vented attic, otherwise calculate default?
                              insulation_id: floor_values[:insulation_id],
                              insulation_assembly_r_value: floor_r)
      end

      # Gable wall: Two surfaces per HES zone_roof
      # FIXME: Do we want gable walls even for cathedral ceiling and conditioned attic where roof area is provided by the user?
      gable_height = @bldg_length_side / 2 * Math.sin(UnitConversions.convert(@roof_angle, "deg", "rad"))
      gable_area = @bldg_length_side / 2 * gable_height
      gable_azimuths = [@bldg_azimuth + 90, @bldg_azimuth + 270] # FIXME: Verify
      gable_azimuths.each_with_index do |gable_azimuth, idx|
        HPXML.add_attic_wall(attic: new_attic,
                             id: "#{roof_values[:id]}_gable_#{idx}",
                             adjacent_to: "outside",
                             wall_type: "WoodStud",
                             area: gable_area, # FIXME: Verify
                             azimuth: sanitize_azimuth(gable_azimuth),
                             solar_absorptance: 0.75, # ERI assumption; TODO get values from method
                             emittance: 0.9, # ERI assumption; TODO get values from method
                             insulation_id: "#{roof_values[:insulation_id]}_gable_#{idx}",
                             insulation_assembly_r_value: 4.0) # FIXME: Hard-coded
      end

      # Uses ERI Reference Home for vented attic specific leakage area
    end
  end

  def self.set_enclosure_foundations(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
      foundation_values = HPXML.get_foundation_values(foundation: orig_foundation)

      new_foundation = HPXML.add_foundation(hpxml: hpxml, **foundation_values)

      # FrameFloor
      framefloor_area = nil
      if ["UnconditionedBasement", "VentedCrawlspace", "UnventedCrawlspace"].include? foundation_values[:foundation_type]
        framefloor_values = HPXML.get_frame_floor_values(floor: orig_foundation.elements["FrameFloor"])
        framefloor_area = framefloor_values[:area]
        floor_r = get_floor_assembly_r(framefloor_values[:insulation_cavity_r_value])

        HPXML.add_frame_floor(foundation: new_foundation,
                              id: framefloor_values[:id],
                              adjacent_to: "living space",
                              area: framefloor_values[:area],
                              insulation_id: framefloor_values[:insulation_id],
                              insulation_assembly_r_value: floor_r)
      end

      # FoundationWall
      if ["UnconditionedBasement", "ConditionedBasement", "VentedCrawlspace", "UnventedCrawlspace"].include? foundation_values[:foundation_type]
        fndwall_values = HPXML.get_foundation_wall_values(foundation_wall: orig_foundation.elements["FoundationWall"])
        # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/doe2-inputs-assumptions-and-calculations/the-doe2-model
        if ["UnconditionedBasement", "ConditionedBasement"].include? foundation_values[:foundation_type]
          fndwall_height = 8.0 # FIXME: Verify
        else
          fndwall_height = 2.5 # FIXME: Verify
        end

        HPXML.add_foundation_wall(foundation: new_foundation,
                                  id: fndwall_values[:id],
                                  height: fndwall_height,
                                  area: fndwall_height * @bldg_perimeter, # FIXME: Verify
                                  thickness: 8, # FIXME: Verify
                                  depth_below_grade: fndwall_height, # FIXME: Verify
                                  adjacent_to: "ground",
                                  insulation_id: fndwall_values[:insulation_id],
                                  insulation_assembly_r_value: fndwall_values[:insulation_continuous_r_value] + 3.0) # FIXME: need to convert from insulation R-value to assembly R-value
      end

      # Slab
      if foundation_values[:foundation_type] == "SlabOnGrade"
        slab_values = HPXML.get_slab_values(slab: orig_foundation.elements["Slab"])
      else
        slab_values = {}
        slab_values[:id] = "#{foundation_values[:id]}_slab"
        slab_values[:area] = framefloor_area
        slab_values[:perimeter_insulation_id] = "#{slab_values[:id]}_perim_insulation"
        slab_values[:perimeter_insulation_r_value] = 0
      end

      HPXML.add_slab(foundation: new_foundation,
                     id: slab_values[:id],
                     area: slab_values[:area],
                     thickness: 4,
                     exposed_perimeter: @bldg_perimeter, # FIXME: Verify
                     perimeter_insulation_depth: 1, # FIXME: Hard-coded
                     under_slab_insulation_width: 0, # FIXME: Verify
                     depth_below_grade: 0, # FIXME: Verify
                     carpet_fraction: 0.5, # FIXME: Hard-coded
                     carpet_r_value: 2, # FIXME: Hard-coded
                     perimeter_insulation_id: slab_values[:perimeter_insulation_id],
                     perimeter_insulation_r_value: slab_values[:perimeter_insulation_r_value],
                     under_slab_insulation_id: "#{slab_values[:id]}_under_insulation",
                     under_slab_insulation_r_value: 0)

      # Uses ERI Reference Home for vented crawlspace specific leakage area
    end
  end

  def self.set_enclosure_rim_joists(orig_details, hpxml)
    # No rim joists
  end

  def self.set_enclosure_walls(orig_details, hpxml)
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
                     insulation_id: "#{wall_values[:id]}_insulation",
                     insulation_assembly_r_value: wall_r)
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

      if window_values[:exterior_shading] == "solar screens"
        # FIXME: Solar screen (add R-0.1 and multiply SHGC by 0.85?)
      end

      # Add one HPXML window per story (for this facade) to accommodate different overhang distances
      window_height = 4.0 # FIXME: Hard-coded
      for story in 1..@ncfl_ag
        HPXML.add_window(hpxml: hpxml,
                         id: "#{window_values[:id]}_story#{story}",
                         area: window_values[:area] / @ncfl_ag,
                         azimuth: orientation_to_azimuth(window_values[:orientation]),
                         ufactor: window_values[:ufactor],
                         shgc: window_values[:shgc],
                         overhangs_depth: 1.0, # FIXME: Verify
                         overhangs_distance_to_top_of_window: 2.0, # FIXME: Hard-coded
                         overhangs_distance_to_bottom_of_window: 6.0, # FIXME: Hard-coded
                         wall_idref: window_values[:wall_idref])
      end
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
        # FIXME: Solar screen (add R-0.1 and multiply SHGC by 0.85?)
      end

      HPXML.add_skylight(hpxml: hpxml,
                         id: skylight_values[:id],
                         area: skylight_values[:area],
                         azimuth: orientation_to_azimuth(@bldg_orient), # FIXME: Hard-coded
                         ufactor: skylight_values[:ufactor],
                         shgc: skylight_values[:shgc],
                         roof_idref: "#{skylight_values[:roof_idref]}_0") # FIXME: Hard-coded
      # No overhangs
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

    front_wall_values = HPXML.get_wall_values(wall: front_wall)
    HPXML.add_door(hpxml: hpxml,
                   id: "Door",
                   wall_idref: front_wall_values[:id],
                   azimuth: orientation_to_azimuth(@bldg_orient))
    # Uses ERI Reference Home for Area
    # Uses ERI Reference Home for RValue
  end

  def self.set_systems_hvac(orig_details, hpxml)
    additional_hydronic_ids = []

    # HeatingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatingSystem") do |orig_heating|
      heating_values = HPXML.get_heating_system_values(heating_system: orig_heating)

      distribution_system_id = heating_values[:distribution_system_idref]
      if heating_values[:heating_system_type] == "Boiler" and distribution_system_id.nil?
        # Need to create hydronic distribution system
        distribution_system_id = heating_values[:id] + "_dist"
        additional_hydronic_ids << distribution_system_id
      end
      hvac_units = nil
      hvac_value = nil
      if ["Furnace", "WallFurnace"].include? heating_values[:heating_system_type]
        hvac_units = "AFUE"
        if heating_values[:heating_system_fuel] == "electricity"
          hvac_value = 0.98
        else
          if heating_values[:year_installed].nil?
            hvac_value = heating_values[:heating_efficiency_value]
          else
            hvac_value = get_default_furnace_afue(heating_values[:year_installed], heating_values[:heating_system_fuel])
          end
        end
      elsif heating_values[:heating_system_type] == "Boiler"
        hvac_units = "AFUE"
        if heating_values[:heating_system_fuel] == "electricity"
          hvac_value = 0.98
        else
          if heating_values[:year_installed].nil?
            hvac_value = heating_values[:heating_efficiency_value]
          else
            hvac_value = get_default_boiler_afue(heating_values[:year_installed], heating_values[:heating_system_fuel])
          end
        end
      elsif heating_values[:heating_system_type] == "ElectricResistance"
        hvac_units = "Percent"
        hvac_value = 0.98
      elsif heating_values[:heating_system_type] == "Stove"
        hvac_units = "Percent"
        if heating_values[:heating_system_fuel] == "wood"
          hvac_value = 0.60
        elsif heating_values[:heating_system_fuel] == "wood pellets"
          hvac_value = 0.78
        else
          fail "Unexpected fuel type '#{heating_values[:heating_system_fuel]}' for stove heating system."
        end
      else
        fail "Unexpected heating system type '#{heating_values[:heating_system_type]}'."
      end

      HPXML.add_heating_system(hpxml: hpxml,
                               id: heating_values[:id],
                               distribution_system_idref: distribution_system_id,
                               heating_system_type: heating_values[:heating_system_type],
                               heating_system_fuel: heating_values[:heating_system_fuel],
                               heating_capacity: -1, # Use Manual J auto-sizing
                               heating_efficiency_units: hvac_units,
                               heating_efficiency_value: hvac_value,
                               fraction_heat_load_served: heating_values[:fraction_heat_load_served])
    end

    # CoolingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/CoolingSystem") do |orig_cooling|
      cooling_values = HPXML.get_cooling_system_values(cooling_system: orig_cooling)

      distribution_system_id = cooling_values[:distribution_system_idref]
      hvac_units = nil
      hvac_value = nil
      if cooling_values[:cooling_system_type] == "central air conditioning"
        hvac_units = "SEER"
        if cooling_values[:year_installed].nil?
          hvac_value = cooling_values[:cooling_efficiency_value]
        else
          hvac_value = get_default_central_ac_seer(cooling_values[:year_installed])
        end
      elsif cooling_values[:cooling_system_type] == "room air conditioner"
        hvac_units = "EER"
        if cooling_values[:year_installed].nil?
          hvac_value = cooling_values[:cooling_efficiency_value]
        else
          hvac_value = get_default_room_ac_eer(cooling_values[:year_installed])
        end
      else
        fail "Unexpected cooling system type '#{cooling_values[:cooling_system_type]}'."
      end

      HPXML.add_cooling_system(hpxml: hpxml,
                               id: cooling_values[:id],
                               distribution_system_idref: distribution_system_id,
                               cooling_system_type: cooling_values[:cooling_system_type],
                               cooling_system_fuel: "electricity",
                               cooling_capacity: -1, # Use Manual J auto-sizing
                               fraction_cool_load_served: cooling_values[:fraction_cool_load_served],
                               cooling_efficiency_units: hvac_units,
                               cooling_efficiency_value: hvac_value)
    end

    # HeatPump
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatPump") do |orig_hp|
      hp_values = HPXML.get_heat_pump_values(heat_pump: orig_hp)

      distribution_system_id = hp_values[:distribution_system_idref]
      hvac_units_heat = nil
      hvac_value_heat = nil
      hvac_units_cool = nil
      hvac_value_cool = nil
      if hp_values[:heat_pump_type] == "air-to-air"
        hvac_units_cool = "SEER"
        hvac_units_heat = "HSPF"
        if hp_values[:year_installed].nil?
          hvac_value_cool = hp_values[:cooling_efficiency_value]
          hvac_value_heat = hp_values[:heating_efficiency_value]
        else
          hvac_value_cool, hvac_value_heat = get_default_ashp_seer_hspf(hp_values[:year_installed])
        end
      elsif hp_values[:heat_pump_type] == "mini-split"
        hvac_units_cool = "SEER"
        hvac_units_heat = "HSPF"
        hvac_value_cool = hp_values[:cooling_efficiency_value]
        hvac_value_heat = hp_values[:heating_efficiency_value]
      elsif hp_values[:heat_pump_type] == "ground-to-air"
        hvac_units_cool = "EER"
        hvac_units_heat = "COP"
        hvac_value_cool = hp_values[:cooling_efficiency_value]
        hvac_value_heat = hp_values[:heating_efficiency_value]
      else
        fail "Unexpected peat pump system type '#{hp_values[:heat_pump_type]}'."
      end
      if hp_values[:fraction_cool_load_served] == 0 and hvac_value_cool.nil?
        hvac_value_cool = 14.0 # Arbitrary value; not used
      end
      if hp_values[:fraction_heat_load_served] == 0 and hvac_value_heat.nil?
        hvac_value_heat = 5.0 # Arbitrary value; not used
      end

      HPXML.add_heat_pump(hpxml: hpxml,
                          id: hp_values[:id],
                          distribution_system_idref: distribution_system_id,
                          heat_pump_type: hp_values[:heat_pump_type],
                          heat_pump_fuel: "electricity",
                          heating_capacity: -1, # Use Manual J auto-sizing
                          cooling_capacity: -1, # Use Manual J auto-sizing
                          fraction_heat_load_served: hp_values[:fraction_heat_load_served],
                          fraction_cool_load_served: hp_values[:fraction_cool_load_served],
                          heating_efficiency_units: hvac_units_heat,
                          heating_efficiency_value: hvac_value_heat,
                          cooling_efficiency_units: hvac_units_cool,
                          cooling_efficiency_value: hvac_value_cool)
    end

    # HVACControl
    HPXML.add_hvac_control(hpxml: hpxml,
                           id: "HVACControl",
                           control_type: "manual thermostat")

    # HVACDistribution
    orig_details.elements.each("Systems/HVAC/HVACDistribution") do |orig_dist|
      dist_values = HPXML.get_hvac_distribution_values(hvac_distribution: orig_dist)

      # Leakage fraction of total air handler flow
      # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/thermal-distribution-efficiency/thermal-distribution-efficiency
      # FIXME: Verify. Total or to the outside?
      # FIXME: Or 10%/25%? See https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI/edit#gid=1042407563
      if dist_values[:duct_system_sealed]
        leakage_frac = 0.03
      else
        leakage_frac = 0.15
      end

      # FIXME: Verify
      # Surface areas outside conditioned space
      # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/thermal-distribution-efficiency/thermal-distribution-efficiency
      supply_duct_area = 0.27 * @cfa
      return_duct_area = 0.05 * @nfl * @cfa

      new_dist = HPXML.add_hvac_distribution(hpxml: hpxml,
                                             id: dist_values[:id],
                                             distribution_system_type: "AirDistribution")
      new_air_dist = new_dist.elements["DistributionSystemType/AirDistribution"]

      # Supply duct leakage
      HPXML.add_duct_leakage_measurement(air_distribution: new_air_dist,
                                         duct_type: "supply",
                                         duct_leakage_value: 100) # FIXME: Hard-coded

      # Return duct leakage
      HPXML.add_duct_leakage_measurement(air_distribution: new_air_dist,
                                         duct_type: "return",
                                         duct_leakage_value: 100) # FIXME: Hard-coded

      orig_dist.elements.each("DistributionSystemType/AirDistribution/Ducts") do |orig_duct|
        duct_values = HPXML.get_ducts_values(ducts: orig_duct)

        # FIXME: Verify nominal insulation and not assembly
        if duct_values[:hescore_ducts_insulated]
          duct_rvalue = 6
        else
          duct_rvalue = 0
        end

        # Supply duct
        HPXML.add_ducts(air_distribution: new_air_dist,
                        duct_type: "supply",
                        duct_insulation_r_value: duct_rvalue,
                        duct_location: duct_values[:duct_location],
                        duct_surface_area: duct_values[:duct_fraction_area] * supply_duct_area)

        # Return duct
        HPXML.add_ducts(air_distribution: new_air_dist,
                        duct_type: "return",
                        duct_insulation_r_value: duct_rvalue,
                        duct_location: duct_values[:duct_location],
                        duct_surface_area: duct_values[:duct_fraction_area] * return_duct_area)
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

      if not wh_sys_values[:year_installed].nil?
        wh_sys_values[:energy_factor] = get_default_water_heater_ef(wh_sys_values[:year_installed],
                                                                    wh_sys_values[:fuel_type])
      end

      wh_capacity = nil
      if wh_sys_values[:water_heater_type] == "storage water heater"
        wh_capacity = get_default_water_heater_capacity(wh_sys_values[:fuel_type])
      end
      wh_recovery_efficiency = nil
      if wh_sys_values[:water_heater_type] == "storage water heater" and wh_sys_values[:fuel_type] != "electricity"
        wh_recovery_efficiency = get_default_water_heater_re(wh_sys_values[:fuel_type])
      end
      wh_tank_volume = nil
      if wh_sys_values[:water_heater_type] != "instantaneous water heater"
        wh_tank_volume = get_default_water_heater_volume(wh_sys_values[:fuel_type])
      end
      HPXML.add_water_heating_system(hpxml: hpxml,
                                     id: wh_sys_values[:id],
                                     fuel_type: wh_sys_values[:fuel_type],
                                     water_heater_type: wh_sys_values[:water_heater_type],
                                     location: "living space", # FIXME: To be decided later
                                     tank_volume: wh_tank_volume,
                                     fraction_dhw_load_served: 1.0,
                                     heating_capacity: wh_capacity,
                                     energy_factor: wh_sys_values[:energy_factor],
                                     uniform_energy_factor: wh_sys_values[:uniform_energy_factor],
                                     recovery_efficiency: wh_recovery_efficiency)
    end
  end

  def self.set_systems_water_heating_use(hpxml)
    HPXML.add_hot_water_distribution(hpxml: hpxml,
                                     id: "HotWaterDistribution",
                                     system_type: "Standard",
                                     pipe_r_value: 0)

    HPXML.add_water_fixture(hpxml: hpxml,
                            id: "ShowerHead",
                            water_fixture_type: "shower head",
                            low_flow: false)
  end

  def self.set_systems_photovoltaics(orig_details, hpxml)
    pv_system_values = HPXML.get_pv_system_values(pv_system: orig_details.elements["Systems/Photovoltaics/PVSystem"])
    return if pv_system_values.nil?

    if pv_system_values[:max_power_output].nil?
      pv_system_values[:max_power_output] = pv_system_values[:number_of_panels] * 300.0 # FIXME: Hard-coded
    end

    HPXML.add_pv_system(hpxml: hpxml,
                        id: "PVSystem",
                        module_type: "standard", # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                        array_type: "fixed roof mount", # FIXME: Verify. HEScore was using "fixed open rack"??
                        array_azimuth: orientation_to_azimuth(pv_system_values[:array_orientation]),
                        array_tilt: @roof_angle,
                        max_power_output: pv_system_values[:max_power_output],
                        inverter_efficiency: 0.96, # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                        system_losses_fraction: 0.14) # FIXME: Needs to be calculated
  end

  def self.set_appliances_clothes_washer(hpxml)
    HPXML.add_clothes_washer(hpxml: hpxml,
                             id: "ClothesWasher")
    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_clothes_dryer(hpxml)
    HPXML.add_clothes_dryer(hpxml: hpxml,
                            id: "ClothesDryer",
                            fuel_type: "electricity")
    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_dishwasher(hpxml)
    HPXML.add_dishwasher(hpxml: hpxml,
                         id: "Dishwasher")
    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_refrigerator(hpxml)
    HPXML.add_refrigerator(hpxml: hpxml,
                           id: "Refrigerator")
    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_cooking_range_oven(hpxml)
    HPXML.add_cooking_range(hpxml: hpxml,
                            id: "CookingRange",
                            fuel_type: "electricity")

    HPXML.add_oven(hpxml: hpxml,
                   id: "Oven")
    # Uses ERI Reference Home for performance
  end

  def self.set_lighting(orig_details, hpxml)
    HPXML.add_lighting(hpxml: hpxml)
    # Uses ERI Reference Home
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

def get_default_furnace_afue(year, fuel)
  # Furnace AFUE by year/fuel
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
  # Boiler AFUE by year/fuel
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
  # Central Air Conditioner SEER by year
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
  # Room Air Conditioner EER by year
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
  # Air Source Heat Pump SEER/HSPF by year
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

def get_default_water_heater_ef(year, fuel)
  # Water Heater Energy Factor by year/fuel
  # FIXME: Verify
  # TODO: Pull out methods and make available for ERI use case
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_efs = { "electricity" => [0.86, 0.86, 0.86, 0.86, 0.86, 0.87, 0.88, 0.92],
                  "natural gas" => [0.50, 0.50, 0.50, 0.50, 0.55, 0.56, 0.56, 0.59],
                  "propane" => [0.50, 0.50, 0.50, 0.50, 0.55, 0.56, 0.56, 0.59],
                  "fuel oil" => [0.47, 0.47, 0.47, 0.48, 0.49, 0.54, 0.56, 0.51] }[fuel]
  ending_years.zip(default_efs).each do |ending_year, default_ef|
    next if year > ending_year

    return default_ef
  end
  fail "Could not get default water heater EF for year '#{year}' and fuel '#{fuel}'"
end

def get_default_water_heater_volume(fuel)
  # Water Heater Tank Volume by fuel
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
  # Water Heater Recovery Efficiency by fuel
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
  # Water Heater Rated Input Capacity by fuel
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
  # Walls Wood Stud Assembly R-value
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  sidings = ["wood siding", "stucco", "vinyl siding", "aluminum siding", "brick veneer"]
  siding_index = sidings.index(siding)
  if r_cont.nil? and not ove
    val = { 0.0 => [4.6, 3.2, 3.8, 3.7, 4.7],                                # ewwf00wo, ewwf00st, ewwf00vi, ewwf00al, ewwf00br
            3.0 => [7.0, 5.8, 6.3, 6.2, 7.1],                                # ewwf03wo, ewwf03st, ewwf03vi, ewwf03al, ewwf03br
            7.0 => [9.7, 8.5, 9.0, 8.8, 9.8],                                # ewwf07wo, ewwf07st, ewwf07vi, ewwf07al, ewwf07br
            11.0 => [11.5, 10.2, 10.8, 10.6, 11.6],                          # ewwf11wo, ewwf11st, ewwf11vi, ewwf11al, ewwf11br
            13.0 => [12.5, 11.1, 11.6, 11.5, 12.5],                          # ewwf13wo, ewwf13st, ewwf13vi, ewwf13al, ewwf13br
            15.0 => [13.3, 11.9, 12.5, 12.3, 13.3],                          # ewwf15wo, ewwf15st, ewwf15vi, ewwf15al, ewwf15br
            19.0 => [16.9, 15.4, 16.1, 15.9, 16.9],                          # ewwf19wo, ewwf19st, ewwf19vi, ewwf19al, ewwf19br
            21.0 => [17.5, 16.1, 16.9, 16.7, 17.9] }[r_cavity][siding_index] # ewwf21wo, ewwf21st, ewwf21vi, ewwf21al, ewwf21br
  elsif not r_cont.nil? and not ove
    val = { 11.0 => [16.7, 15.4, 15.9, 15.9, 16.9],                          # ewps11wo, ewps11st, ewps11vi, ewps11al, ewps11br
            13.0 => [17.9, 16.4, 16.9, 16.9, 17.9],                          # ewps13wo, ewps13st, ewps13vi, ewps13al, ewps13br
            15.0 => [18.5, 17.2, 17.9, 17.9, 18.9],                          # ewps15wo, ewps15st, ewps15vi, ewps15al, ewps15br
            19.0 => [22.2, 20.8, 21.3, 21.3, 22.2],                          # ewps19wo, ewps19st, ewps19vi, ewps19al, ewps19br
            21.0 => [22.7, 21.7, 22.2, 22.2, 23.3] }[r_cavity][siding_index] # ewps21wo, ewps21st, ewps21vi, ewps21al, ewps21br
  elsif r_cont.nil? and ove
    val = { 19.0 => [19.2, 17.9, 18.5, 18.2, 19.2],                          # ewov19wo, ewov19st, ewov19vi, ewov19al, ewov19br
            21.0 => [20.4, 18.9, 19.6, 19.6, 20.4],                          # ewov21wo, ewov21st, ewov21vi, ewov21al, ewov21br
            27.0 => [25.6, 24.4, 25.0, 24.4, 25.6],                          # ewov27wo, ewov27st, ewov27vi, ewov27al, ewov27br
            33.0 => [30.3, 29.4, 29.4, 29.4, 30.3],                          # ewov33wo, ewov33st, ewov33vi, ewov33al, ewov33br
            38.0 => [34.5, 33.3, 34.5, 34.5, 34.5] }[r_cavity][siding_index] # ewov38wo, ewov38st, ewov38vi, ewov38al, ewov38br
  elsif not r_cont.nil? and ove
    val = { 19.0 => [24.4, 23.3, 23.8, 23.3, 24.4],                          # ewop19wo, ewop19st, ewop19vi, ewop19al, ewop19br
            21.0 => [25.6, 24.4, 25.0, 25.0, 25.6] }[r_cavity][siding_index] # ewop21wo, ewop21st, ewop21vi, ewop21al, ewop21br
  end
  return val if not val.nil?

  fail "Could not get default wood stud wall assembly R-value for R-cavity '#{r_cavity}' and R-cont '#{r_cont}' and siding '#{siding}' and ove '#{ove}'"
end

def get_structural_block_wall_assembly_r(r_cont)
  # Walls Structural Block Assembly R-value
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  val = { nil => 2.9, # ewbr00nn
          5.0 => 7.9,            # ewbr05nn
          10.0 => 12.8 }[r_cont] # ewbr10nn
  return val if not val.nil?

  fail "Could not get default structural block wall assembly R-value for R-cavity '#{r_cont}'"
end

def get_concrete_block_wall_assembly_r(r_cavity, siding)
  # Walls Concrete Block Assembly R-value
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  sidings = ["stucco", "brick veneer", nil]
  siding_index = sidings.index(siding)
  val = { 0.0 => [4.1, 5.6, 4.0],                           # ewcb00st, ewcb00br, ewcb00nn
          3.0 => [5.7, 7.2, 5.6],                           # ewcb03st, ewcb03br, ewcb03nn
          6.0 => [8.5, 10.0, 8.3] }[r_cavity][siding_index] # ewcb06st, ewcb06br, ewcb06nn
  return val if not val.nil?

  fail "Could not get default concrete block wall assembly R-value for R-cavity '#{r_cavity}' and siding '#{siding}'"
end

def get_straw_bale_wall_assembly_r(siding)
  # Walls Straw Bale Assembly R-value
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  return 58.8 if siding == "stucco" # ewsb00st

  fail "Could not get default straw bale assembly R-value for siding '#{siding}'"
end

def get_roof_assembly_r(r_cavity, r_cont, material, has_radiant_barrier)
  # Roof Assembly R-value
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/roof-construction-types
  materials = ["asphalt or fiberglass shingles",
               "wood shingles or shakes",
               "slate or tile shingles",
               "concrete",
               "plastic/rubber/synthetic sheeting"]
  material_index = materials.index(material)
  if r_cont.nil? and not has_radiant_barrier
    val = { 0.0 => [3.3, 4.0, 3.4, 3.4, 3.7],                                 # rfwf00co, rfwf00wo, rfwf00rc, rfwf00lc, rfwf00tg
            11.0 => [13.5, 14.3, 13.7, 13.5, 13.9],                           # rfwf11co, rfwf11wo, rfwf11rc, rfwf11lc, rfwf11tg
            13.0 => [14.9, 15.6, 15.2, 14.9, 15.4],                           # rfwf13co, rfwf13wo, rfwf13rc, rfwf13lc, rfwf13tg
            15.0 => [16.4, 16.9, 16.4, 16.4, 16.7],                           # rfwf15co, rfwf15wo, rfwf15rc, rfwf15lc, rfwf15tg
            19.0 => [20.0, 20.8, 20.4, 20.4, 20.4],                           # rfwf19co, rfwf19wo, rfwf19rc, rfwf19lc, rfwf19tg
            21.0 => [21.7, 22.2, 21.7, 21.3, 21.7],                           # rfwf21co, rfwf21wo, rfwf21rc, rfwf21lc, rfwf21tg
            27.0 => [nil, 27.8, 27.0, 27.0, 27.0] }[r_cavity][material_index] # rfwf27co, rfwf27wo, rfwf27rc, rfwf27lc, rfwf27tg
  elsif r_cont.nil? and has_radiant_barrier
    val = { 0.0 => [5.6, 6.3, 5.7, 5.6, 6.0] }[r_cavity][material_index]      # rfrb00co, rfrb00wo, rfrb00rc, rfrb00lc, rfrb00tg
  elsif not r_cont.nil? and not has_radiant_barrier
    val = { 0.0 => [8.3, 9.0, 8.4, 8.3, 8.7],                                 # rfps00co, rfps00wo, rfps00rc, rfps00lc, rfps00tg
            11.0 => [18.5, 19.2, 18.5, 18.5, 18.9],                           # rfps11co, rfps11wo, rfps11rc, rfps11lc, rfps11tg
            13.0 => [20.0, 20.8, 20.0, 20.0, 20.4],                           # rfps13co, rfps13wo, rfps13rc, rfps13lc, rfps13tg
            15.0 => [21.3, 22.2, 21.3, 21.3, 21.7],                           # rfps15co, rfps15wo, rfps15rc, rfps15lc, rfps15tg
            19.0 => [nil, 25.6, 25.6, 25.0, 25.6],                            # rfps19co, rfps19wo, rfps19rc, rfps19lc, rfps19tg
            21.0 => [nil, 27.0, 27.0, 26.3, 27.0] }[r_cavity][material_index] # rfps21co, rfps21wo, rfps21rc, rfps21lc, rfps21tg
  end
  return val if not val.nil?

  fail "Could not get default roof assembly R-value for R-cavity '#{r_cavity}' and R-cont '#{r_cont}' and material '#{material}' and radiant barrier '#{has_radiant_barrier}'"
end

def get_ceiling_assembly_r(r_cavity)
  # Ceiling Assembly R-value
  # FIXME: Verify
  # FIXME: Does this include air films?
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
  # FIXME: Verify
  # FIXME: Does this include air films?
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
  # Window U-factor/SHGC
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
  val = { "reflective" => 0.40,
          "white" => 0.50,
          "light" => 0.65,
          "medium" => 0.75,
          "medium dark" => 0.85,
          "dark" => 0.95 }[roof_color]
  return val if not val.nil?

  fail "Could not get roof absorptance for color '#{roof_color}'"
end

def calc_ach50(ncfl_ag, cfa, height, cvolume, desc, year_built, iecc_cz, orig_details)
  # FIXME: Verify
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/infiltration/infiltration
  c_floor_area = -2.08E-03
  c_height = 6.38E-02

  c_vintage = nil
  if year_built < 1960
    c_vintage = -2.50E-01
  elsif year_built <= 1969
    c_vintage = -4.33E-01
  elsif year_built <= 1979
    c_vintage = -4.52E-01
  elsif year_built <= 1989
    c_vintage = -6.54E-01
  elsif year_built <= 1999
    c_vintage = -9.15E-01
  elsif year_built >= 2000
    c_vintage = -1.06E+00
  end
  fail "Could not look up infiltration c_vintage." if c_vintage.nil?

  # FIXME: A-7 vs AK-7?
  c_iecc = nil
  if iecc_cz == "1A" or iecc_cz == "2A"
    c_iecc = 4.73E-01
  elsif iecc_cz == "3A"
    c_iecc = 2.53E-01
  elsif iecc_cz == "4A"
    c_iecc = 3.26E-01
  elsif iecc_cz == "5A"
    c_iecc = 1.12E-01
  elsif iecc_cz == "6A" or iecc_cz == "7"
    c_iecc = 0.0
  elsif iecc_cz == "2B" or iecc_cz == "3B"
    c_iecc = -3.76E-02
  elsif iecc_cz == "4B" or iecc_cz == "5B"
    c_iecc = -8.77E-03
  elsif iecc_cz == "6B"
    c_iecc = 1.94E-02
  elsif iecc_cz == "3C"
    c_iecc = 4.83E-02
  elsif iecc_cz == "4C"
    c_iecc = 2.58E-01
  elsif iecc_cz == "8"
    c_iecc = -5.12E-01
  end
  fail "Could not look up infiltration c_iecc." if c_iecc.nil?

  # FIXME: How to handle multiple foundations?
  c_foundation = nil
  foundation_type = "SlabOnGrade" # FIXME: Connect to input
  if foundation_type == "SlabOnGrade"
    c_foundation = -0.036992
  elsif foundation_type == "ConditionedBasement" or foundation_type == "UnventedCrawlspace"
    c_foundation = 0.108713
  elsif foundation_type == "UnconditionedBasement" or foundation_type == "VentedCrawlspace"
    c_foundation = 0.180352
  end
  fail "Could not look up infiltration c_foundation." if c_foundation.nil?

  # FIXME: How to handle no ducts or multiple duct locations?
  # FIXME: How to handle ducts in unvented crawlspace?
  c_duct = nil
  duct_location = "living space" # FIXME: Connect to input
  if duct_location == "living space"
    c_duct = -0.12381
  elsif duct_location == "attic - unconditioned" or duct_location == "basement - unconditioned"
    c_duct = 0.07126
  elsif duct_location == "crawlspace - vented"
    c_duct = 0.18072
  end
  fail "Could not look up infiltration c_duct." if c_duct.nil?

  c_sealed = nil
  if desc == "tight"
    c_sealed = -0.384 # FIXME: Hard-coded. Not included in Table 1
  elsif desc == "average"
    c_sealed = 0.0
  end
  fail "Could not look up infiltration c_sealed." if c_sealed.nil?

  floor_area_m2 = UnitConversions.convert(cfa, "ft^2", "m^2")
  height_m = UnitConversions.convert(height, "ft", "m")

  # Normalized leakage
  nl = Math.exp(floor_area_m2 * c_floor_area +
                height_m * c_height +
                c_sealed + c_vintage + c_iecc + c_foundation + c_duct)

  # Specific Leakage Area
  sla = nl / 1000.0 * ncfl_ag**0.3

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
    azimtuh += 360
  end
  while azimuth >= 360
    azimuth -= 360
  end
  return azimuth
end

def get_attached(attached_name, orig_details, search_in)
  orig_details.elements.each(search_in) do |other_element|
    next if attached_name != HPXML.get_id(other_element)

    return other_element
  end
  fail "Could not find attached element for '#{attached_name}'."
end

def get_foundation_details(orig_details)
  fnd_types = []
  fnd_cfa = 0.0
  orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
    foundation_values = HPXML.get_foundation_values(foundation: orig_foundation)
    fnd_types << foundation_values[:foundation_type]
    if foundation_values[:foundation_type] == "ConditionedBasement"
      framefloor_values = HPXML.get_frame_floor_values(floor: orig_foundation.elements["FrameFloor"])
      fnd_cfa += framefloor_values[:area]
    end
  end
  return fnd_types, fnd_cfa
end
