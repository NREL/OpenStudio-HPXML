class HPXML
  def self.add_site(building_summary:,
                    fuels: [],
                    shelter_coefficient: nil)
    site = XMLHelper.add_element(building_summary, "Site")
    unless fuels.empty?
      fuel_types_available = XMLHelper.add_element(site, "FuelTypesAvailable")
      fuels.each do |fuel|
        XMLHelper.add_element(fuel_types_available, "Fuel", fuel)
      end
    end
    unless shelter_coefficient.nil?
      HPXML.add_extension(parent: site,
                          extensions: { "ShelterCoefficient": shelter_coefficient })
    end

    return site
  end

  def self.add_building_occupancy(building_summary:,
                                  number_of_residents: nil)
    building_occupancy = XMLHelper.add_element(building_summary, "BuildingOccupancy")
    XMLHelper.add_element(building_occupancy, "NumberofResidents", number_of_residents) unless number_of_residents.nil?

    return building_occupancy
  end

  def self.add_building_construction(building_summary:,
                                     number_of_conditioned_floors: nil,
                                     number_of_conditioned_floors_above_grade: nil,
                                     number_of_bedrooms: nil,
                                     conditioned_floor_area: nil,
                                     conditioned_building_volume: nil,
                                     garage_present: nil)
    building_construction = XMLHelper.add_element(building_summary, "BuildingConstruction")
    XMLHelper.add_element(building_construction, "NumberofConditionedFloors", number_of_conditioned_floors) unless number_of_conditioned_floors.nil?
    XMLHelper.add_element(building_construction, "NumberofConditionedFloorsAboveGrade", number_of_conditioned_floors_above_grade) unless number_of_conditioned_floors_above_grade.nil?
    XMLHelper.add_element(building_construction, "NumberofBedrooms", number_of_bedrooms) unless number_of_bedrooms.nil?
    XMLHelper.add_element(building_construction, "ConditionedFloorArea", conditioned_floor_area) unless conditioned_floor_area.nil?
    XMLHelper.add_element(building_construction, "ConditionedBuildingVolume", conditioned_building_volume) unless conditioned_building_volume.nil?
    XMLHelper.add_element(building_construction, "GaragePresent", garage_present) unless garage_present.nil?

    return building_construction
  end

  def self.add_climate_zone_iecc(climate_and_risk_zones:,
                                 year: nil,
                                 climate_zone: nil)
    climate_zone_iecc = XMLHelper.add_element(climate_and_risk_zones, "ClimateZoneIECC")
    XMLHelper.add_element(climate_zone_iecc, "Year", year) unless year.nil?
    XMLHelper.add_element(climate_zone_iecc, "ClimateZone", climate_zone) unless climate_zone.nil?

    return climate_zone_iecc
  end

  def self.add_weather_station(climate_and_risk_zones:,
                               id:,
                               name: nil,
                               wmo: nil)
    weather_station = XMLHelper.add_element(climate_and_risk_zones, "WeatherStation")
    sys_id = XMLHelper.add_element(weather_station, "SystemIdentifiersInfo")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(weather_station, "Name", name) unless name.nil?
    XMLHelper.add_element(weather_station, "WMO", wmo) unless wmo.nil?

    return weather_station
  end

  def self.add_air_infiltration_measurement(air_infiltration:,
                                            id:,
                                            house_pressure: nil,
                                            unit_of_measure: nil,
                                            air_leakage: nil,
                                            effective_leakage_area: nil)
    air_infiltration_measurement = XMLHelper.add_element(air_infiltration, "AirInfiltrationMeasurement")
    sys_id = XMLHelper.add_element(air_infiltration_measurement, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(air_infiltration_measurement, "HousePressure", house_pressure) unless house_pressure.nil?
    if not unit_of_measure.nil? and not air_leakage.nil?
      building_air_leakage = XMLHelper.add_element(air_infiltration_measurement, "BuildingAirLeakage")
      XMLHelper.add_element(building_air_leakage, "UnitofMeasure", unit_of_measure)
      XMLHelper.add_element(building_air_leakage, "AirLeakage", air_leakage)
    end
    XMLHelper.add_element(air_infiltration_measurement, "EffectiveLeakageArea", effective_leakage_area) unless effective_leakage_area.nil?

    return air_infiltration_measurement
  end

  def self.add_attic(attics:,
                     id:,
                     attic_type: nil)
    attic = XMLHelper.add_element(attics, "Attic")
    sys_id = XMLHelper.add_element(attic, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(attic, "AtticType", attic_type) unless attic_type.nil?

    return attic
  end

  def self.add_roof(roofs:,
                    id:,
                    area: nil,
                    azimuth: nil,
                    solar_absorptance: nil,
                    emittance: nil,
                    pitch: nil,
                    radiant_barrier: nil)
    roof = XMLHelper.add_element(roofs, "Roof")
    sys_id = XMLHelper.add_element(roof, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(roof, "Area", area) unless area.nil?
    XMLHelper.add_element(roof, "Azimuth", azimuth) unless azimuth.nil?
    XMLHelper.add_element(roof, "SolarAbsorptance", solar_absorptance) unless solar_absorptance.nil?
    XMLHelper.add_element(roof, "Emittance", emittance) unless emittance.nil?
    XMLHelper.add_element(roof, "Pitch", pitch) unless pitch.nil?
    XMLHelper.add_element(roof, "RadiantBarrier", radiant_barrier) unless radiant_barrier.nil?

    return roof
  end

  def self.add_insulation(parent:,
                          id:,
                          assembly_effective_r_value: nil)
    insulation = XMLHelper.add_element(parent, "Insulation")
    sys_id = XMLHelper.add_element(insulation, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(insulation, "AssemblyEffectiveRValue", assembly_effective_r_value) unless assembly_effective_r_value.nil?

    return insulation
  end

  def self.add_floor(floors:,
                     id:,
                     adjacent_to: nil,
                     area: nil)
    floor = XMLHelper.add_element(floors, "Floor")
    sys_id = XMLHelper.add_element(floor, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(floor, "AdjacentTo", adjacent_to) unless adjacent_to.nil?
    XMLHelper.add_element(floor, "Area", area) unless area.nil?

    return floor
  end

  def self.add_foundation(foundations:,
                          id:,
                          foundation_type: nil)
    foundation = XMLHelper.add_element(foundations, "Foundation")
    sys_id = XMLHelper.add_element(foundation, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless foundation_type.nil?
      foundation_type_e = XMLHelper.add_element(foundation, "FoundationType")
      if ["SlabOnGrade", "Ambient"].include? foundation_type
        XMLHelper.add_element(foundation_type_e, foundation_type)
      elsif foundation_type == "ConditionedBasement"
        basement = XMLHelper.add_element(foundation_type_e, "Basement")
        XMLHelper.add_element(basement, "Conditioned", true)
      elsif foundation_type == "UnconditionedBasement"
        basement = XMLHelper.add_element(foundation_type_e, "Basement")
        XMLHelper.add_element(basement, "Conditioned", false)
      elsif foundation_type == "VentedCrawlspace"
        crawlspace = XMLHelper.add_element(foundation_type_e, "Crawlspace")
        XMLHelper.add_element(crawlspace, "Vented", true)
      elsif foundation_type == "UnventedCrawlspace"
        crawlspace = XMLHelper.add_element(foundation_type_e, "Crawlspace")
        XMLHelper.add_element(crawlspace, "Vented", false)
      else
        fail "Unhandled foundation type '#{foundation_type}'."
      end
    end

    return foundation
  end

  def self.add_frame_floor(foundation:,
                           id:,
                           adjacent_to: nil,
                           area: nil)
    frame_floor = XMLHelper.add_element(foundation, "FrameFloor")
    sys_id = XMLHelper.add_element(frame_floor, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(frame_floor, "AdjacentTo", adjacent_to) unless adjacent_to.nil?
    XMLHelper.add_element(frame_floor, "Area", area) unless area.nil?

    return frame_floor
  end

  def self.add_foundation_wall(foundation:,
                               id:,
                               height: nil,
                               area: nil,
                               thickness: nil,
                               depth_below_grade: nil,
                               adjacent_to: nil)
    foundation_wall = XMLHelper.add_element(foundation, "FoundationWall")
    sys_id = XMLHelper.add_element(foundation_wall, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(foundation_wall, "Height", height) unless height.nil?
    XMLHelper.add_element(foundation_wall, "Area", area) unless area.nil?
    XMLHelper.add_element(foundation_wall, "Thickness", thickness) unless thickness.nil?
    XMLHelper.add_element(foundation_wall, "DepthBelowGrade", depth_below_grade) unless depth_below_grade.nil?
    XMLHelper.add_element(foundation_wall, "AdjacentTo", adjacent_to) unless adjacent_to.nil?

    return foundation_wall
  end

  def self.add_slab(foundation:,
                    id:,
                    area: nil,
                    thickness: nil,
                    exposed_perimeter: nil,
                    perimeter_insulation_depth: nil,
                    under_slab_insulation_width: nil,
                    depth_below_grade: nil,
                    carpet_fraction: nil,
                    carpet_r_value: nil)
    slab = XMLHelper.add_element(foundation, "Slab")
    sys_id = XMLHelper.add_element(slab, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(slab, "Area", area) unless area.nil?
    XMLHelper.add_element(slab, "Thickness", thickness) unless thickness.nil?
    XMLHelper.add_element(slab, "ExposedPerimeter", exposed_perimeter) unless exposed_perimeter.nil?
    XMLHelper.add_element(slab, "PerimeterInsulationDepth", perimeter_insulation_depth) unless perimeter_insulation_depth.nil?
    XMLHelper.add_element(slab, "UnderSlabInsulationWidth", under_slab_insulation_width) unless under_slab_insulation_width.nil?
    XMLHelper.add_element(slab, "DepthBelowGrade", depth_below_grade) unless depth_below_grade.nil?
    if not carpet_fraction.nil? and not carpet_r_value.nil?
      HPXML.add_extension(parent: slab,
                          extensions: { "CarpetFraction": carpet_fraction,
                                        "CarpetRValue": carpet_r_value })
    end

    return slab
  end

  def self.add_perimeter_insulation(slab:,
                                    id:)
    perimeter_insulation = XMLHelper.add_element(slab, "PerimeterInsulation")
    sys_id = XMLHelper.add_element(perimeter_insulation, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)

    return perimeter_insulation
  end

  def self.add_under_slab_insulation(slab:,
                                     id:)
    under_slab_insulation = XMLHelper.add_element(slab, "UnderSlabInsulation")
    sys_id = XMLHelper.add_element(under_slab_insulation, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)

    return under_slab_insulation
  end

  def self.add_layer(insulation:,
                     installation_type: nil,
                     nominal_r_value: nil)
    layer = XMLHelper.add_element(insulation, "Layer")
    XMLHelper.add_element(layer, "InstallationType", installation_type) unless installation_type.nil?
    XMLHelper.add_element(layer, "NominalRValue", nominal_r_value) unless nominal_r_value.nil?

    return layer
  end

  def self.add_extension(parent:,
                         extensions: {})
    extension = nil
    unless extensions.empty?
      extensions.each do |name, value|
        next if value.nil?

        extension = parent.elements["extension"]
        if extension.nil?
          extension = XMLHelper.add_element(parent, "extension")
        end
        XMLHelper.add_element(extension, "#{name}", value) unless value.nil?
      end
    end

    return extension
  end

  def self.add_rim_joist(rim_joists:,
                         id:,
                         exterior_adjacent_to: nil,
                         interior_adjacent_to: nil,
                         area: nil)
    rim_joist = XMLHelper.add_element(rim_joists, "RimJoist")
    sys_id = XMLHelper.add_element(rim_joist, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(rim_joist, "ExteriorAdjacentTo", exterior_adjacent_to) unless exterior_adjacent_to.nil?
    XMLHelper.add_element(rim_joist, "InteriorAdjacentTo", interior_adjacent_to) unless interior_adjacent_to.nil?
    XMLHelper.add_element(rim_joist, "Area", area) unless area.nil?

    return rim_joist
  end

  def self.add_wall(walls:,
                    id:,
                    exterior_adjacent_to: nil,
                    interior_adjacent_to: nil,
                    adjacent_to: nil,
                    wall_type: nil,
                    area: nil,
                    azimuth: nil,
                    solar_absorptance: nil,
                    emittance: nil)
    wall = XMLHelper.add_element(walls, "Wall")
    sys_id = XMLHelper.add_element(wall, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(wall, "ExteriorAdjacentTo", exterior_adjacent_to) unless exterior_adjacent_to.nil?
    XMLHelper.add_element(wall, "InteriorAdjacentTo", interior_adjacent_to) unless interior_adjacent_to.nil?
    XMLHelper.add_element(wall, "AdjacentTo", adjacent_to) unless adjacent_to.nil?
    unless wall_type.nil?
      wall_type_e = XMLHelper.add_element(wall, "WallType")
      XMLHelper.add_element(wall_type_e, wall_type)
    end
    XMLHelper.add_element(wall, "Area", area) unless area.nil?
    XMLHelper.add_element(wall, "Azimuth", azimuth) unless azimuth.nil?
    XMLHelper.add_element(wall, "SolarAbsorptance", solar_absorptance) unless solar_absorptance.nil?
    XMLHelper.add_element(wall, "Emittance", emittance) unless emittance.nil?

    return wall
  end

  def self.add_window(windows:,
                      id:,
                      area: nil,
                      azimuth: nil,
                      ufactor: nil,
                      shgc: nil,
                      overhangs_depth: nil,
                      overhangs_distance_to_top_of_window: nil,
                      overhangs_distance_to_bottom_of_window: nil,
                      idref: nil)
    window = XMLHelper.add_element(windows, "Window")
    sys_id = XMLHelper.add_element(window, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(window, "Area", area) unless area.nil?
    XMLHelper.add_element(window, "Azimuth", azimuth) unless azimuth.nil?
    XMLHelper.add_element(window, "UFactor", ufactor) unless ufactor.nil?
    XMLHelper.add_element(window, "SHGC", shgc) unless shgc.nil?
    if not overhangs_depth.nil? or not overhangs_distance_to_top_of_window.nil? or not overhangs_distance_to_bottom_of_window.nil?
      overhangs = XMLHelper.add_element(window, "Overhangs")
      XMLHelper.add_element(overhangs, "Depth", overhangs_depth) unless overhangs_depth.nil?
      XMLHelper.add_element(overhangs, "DistanceToTopOfWindow", overhangs_distance_to_top_of_window) unless overhangs_distance_to_top_of_window.nil?
      XMLHelper.add_element(overhangs, "DistanceToBottomOfWindow", overhangs_distance_to_bottom_of_window) unless overhangs_distance_to_bottom_of_window.nil?
    end
    unless idref.nil?
      attached_to_wall = XMLHelper.add_element(window, "AttachedToWall")
      XMLHelper.add_attribute(attached_to_wall, "idref", idref)
    end

    return window
  end

  def self.add_skylight(skylights:,
                        id:,
                        area: nil,
                        azimuth: nil,
                        ufactor: nil,
                        shgc: nil,
                        idref: nil)
    skylight = XMLHelper.add_element(skylights, "Skylight")
    sys_id = XMLHelper.add_element(skylight, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(skylight, "Area", area) unless area.nil?
    XMLHelper.add_element(skylight, "Azimuth", azimuth) unless azimuth.nil?
    XMLHelper.add_element(skylight, "UFactor", ufactor) unless ufactor.nil?
    XMLHelper.add_element(skylight, "SHGC", shgc) unless shgc.nil?
    unless idref.nil?
      attached_to_roof = XMLHelper.add_element(skylight, "AttachedToRoof")
      XMLHelper.add_attribute(attached_to_roof, "idref", idref)
    end

    return skylight
  end

  def self.add_door(doors:,
                    id:,
                    idref: nil,
                    area: nil,
                    azimuth: nil,
                    r_value: nil)
    door = XMLHelper.add_element(doors, "Door")
    sys_id = XMLHelper.add_element(door, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless idref.nil?
      attached_to_wall = XMLHelper.add_element(door, "AttachedToWall")
      XMLHelper.add_attribute(attached_to_wall, "idref", idref)
    end
    XMLHelper.add_element(door, "Area", area) unless area.nil?
    XMLHelper.add_element(door, "Azimuth", azimuth) unless azimuth.nil?
    XMLHelper.add_element(door, "RValue", r_value) unless r_value.nil?

    return door
  end

  def self.add_heating_system(hvac_plant:,
                              id:,
                              idref: nil,
                              heating_system_type: nil,
                              heating_system_fuel: nil,
                              heating_capacity: nil,
                              annual_heating_efficiency_units: nil,
                              annual_heating_efficiency_value: nil,
                              fraction_heat_load_served: nil)
    heating_system = XMLHelper.add_element(hvac_plant, "HeatingSystem")
    sys_id = XMLHelper.add_element(heating_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless idref.nil?
      distribution_system = XMLHelper.add_element(heating_system, "DistributionSystem")
      XMLHelper.add_attribute(distribution_system, "idref", idref)
    end
    unless heating_system_type.nil?
      heating_system_type_e = XMLHelper.add_element(heating_system, "HeatingSystemType")
      XMLHelper.add_element(heating_system_type_e, heating_system_type)
    end
    XMLHelper.add_element(heating_system, "HeatingSystemFuel", heating_system_fuel) unless heating_system_fuel.nil?
    XMLHelper.add_element(heating_system, "HeatingCapacity", heating_capacity) unless heating_capacity.nil?
    if not annual_heating_efficiency_units.nil? and not annual_heating_efficiency_value.nil?
      annual_heating_efficiency = XMLHelper.add_element(heating_system, "AnnualHeatingEfficiency")
      XMLHelper.add_element(annual_heating_efficiency, "Units", annual_heating_efficiency_units)
      XMLHelper.add_element(annual_heating_efficiency, "Value", annual_heating_efficiency_value)
    end
    XMLHelper.add_element(heating_system, "FractionHeatLoadServed", fraction_heat_load_served) unless fraction_heat_load_served.nil?

    return heating_system
  end

  def self.add_cooling_system(hvac_plant:,
                              id:,
                              idref: nil,
                              cooling_system_type: nil,
                              cooling_system_fuel: nil,
                              cooling_capacity: nil,
                              fraction_cool_load_served: nil,
                              annual_cooling_efficiency_units: nil,
                              annual_cooling_efficiency_value: nil)
    cooling_system = XMLHelper.add_element(hvac_plant, "CoolingSystem")
    sys_id = XMLHelper.add_element(cooling_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless idref.nil?
      distribution_system = XMLHelper.add_element(cooling_system, "DistributionSystem")
      XMLHelper.add_attribute(distribution_system, "idref", idref)
    end
    XMLHelper.add_element(cooling_system, "CoolingSystemType", cooling_system_type) unless cooling_system_type.nil?
    XMLHelper.add_element(cooling_system, "CoolingSystemFuel", cooling_system_fuel) unless cooling_system_fuel.nil?
    XMLHelper.add_element(cooling_system, "CoolingCapacity", cooling_capacity) unless cooling_capacity.nil?
    XMLHelper.add_element(cooling_system, "FractionCoolLoadServed", fraction_cool_load_served) unless fraction_cool_load_served.nil?
    if not annual_cooling_efficiency_units.nil? and not annual_cooling_efficiency_value.nil?
      annual_cooling_efficiency = XMLHelper.add_element(cooling_system, "AnnualCoolingEfficiency")
      XMLHelper.add_element(annual_cooling_efficiency, "Units", annual_cooling_efficiency_units)
      XMLHelper.add_element(annual_cooling_efficiency, "Value", annual_cooling_efficiency_value)
    end

    return cooling_system
  end

  def self.add_heat_pump(hvac_plant:,
                         id:,
                         idref: nil,
                         heat_pump_type: nil,
                         heating_capacity: nil,
                         cooling_capacity: nil,
                         fraction_heat_load_served: nil,
                         fraction_cool_load_served: nil,
                         annual_heating_efficiency_units: nil,
                         annual_heating_efficiency_value: nil,
                         annual_cooling_efficiency_units: nil,
                         annual_cooling_efficiency_value: nil)
    heat_pump = XMLHelper.add_element(hvac_plant, "HeatPump")
    sys_id = XMLHelper.add_element(heat_pump, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless idref.nil?
      distribution_system = XMLHelper.add_element(heat_pump, "DistributionSystem")
      XMLHelper.add_attribute(distribution_system, "idref", idref)
    end
    XMLHelper.add_element(heat_pump, "HeatPumpType", heat_pump_type) unless heat_pump_type.nil?
    XMLHelper.add_element(heat_pump, "HeatingCapacity", heating_capacity) unless heating_capacity.nil?
    XMLHelper.add_element(heat_pump, "CoolingCapacity", cooling_capacity) unless cooling_capacity.nil?
    XMLHelper.add_element(heat_pump, "FractionHeatLoadServed", fraction_heat_load_served) unless fraction_heat_load_served.nil?
    XMLHelper.add_element(heat_pump, "FractionCoolLoadServed", fraction_cool_load_served) unless fraction_cool_load_served.nil?
    if not annual_cooling_efficiency_units.nil? and not annual_cooling_efficiency_value.nil?
      annual_cooling_efficiency = XMLHelper.add_element(heat_pump, "AnnualCoolingEfficiency")
      XMLHelper.add_element(annual_cooling_efficiency, "Units", annual_cooling_efficiency_units)
      XMLHelper.add_element(annual_cooling_efficiency, "Value", annual_cooling_efficiency_value)
    end
    if not annual_heating_efficiency_units.nil? and not annual_heating_efficiency_value.nil?
      annual_heating_efficiency = XMLHelper.add_element(heat_pump, "AnnualHeatingEfficiency")
      XMLHelper.add_element(annual_heating_efficiency, "Units", annual_heating_efficiency_units)
      XMLHelper.add_element(annual_heating_efficiency, "Value", annual_heating_efficiency_value)
    end

    return heat_pump
  end

  def self.add_hvac_control(hvac:,
                            id:,
                            control_type: nil)
    hvac_control = XMLHelper.add_element(hvac, "HVACControl")
    sys_id = XMLHelper.add_element(hvac_control, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(hvac_control, "ControlType", control_type) unless control_type.nil?

    return hvac_control
  end

  def self.add_hvac_distribution(hvac:,
                                 id:,
                                 distribution_system_type: nil,
                                 annual_heating_distribution_system_efficiency: nil,
                                 annual_cooling_distribution_system_efficiency: nil)
    hvac_distribution = XMLHelper.add_element(hvac, "HVACDistribution")
    sys_id = XMLHelper.add_element(hvac_distribution, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless distribution_system_type.nil?
      distribution_system_type_e = XMLHelper.add_element(hvac_distribution, "DistributionSystemType")
      if ["AirDistribution", "HydronicDistribution"].include? distribution_system_type
        XMLHelper.add_element(distribution_system_type_e, distribution_system_type)
      else
        XMLHelper.add_element(distribution_system_type_e, "Other", distribution_system_type)
      end      
      
    end
    XMLHelper.add_element(hvac_distribution, "AnnualHeatingDistributionSystemEfficiency", annual_heating_distribution_system_efficiency) unless annual_heating_distribution_system_efficiency.nil?
    XMLHelper.add_element(hvac_distribution, "AnnualCoolingDistributionSystemEfficiency", annual_cooling_distribution_system_efficiency) unless annual_cooling_distribution_system_efficiency.nil?

    return hvac_distribution
  end

  def self.add_duct_leakage_measurement(air_distribution:,
                                        duct_type: nil,
                                        duct_leakage_units: nil,
                                        duct_leakage_value: nil,
                                        duct_leakage_total_or_to_outside: nil)
    duct_leakage_measurement = XMLHelper.add_element(air_distribution, "DuctLeakageMeasurement")
    XMLHelper.add_element(duct_leakage_measurement, "DuctType", duct_type) unless duct_type.nil?
    if not duct_leakage_units.nil? and not duct_leakage_value.nil? and not duct_leakage_total_or_to_outside.nil?
      duct_leakage = XMLHelper.add_element(duct_leakage_measurement, "DuctLeakage")
      XMLHelper.add_element(duct_leakage, "Units", duct_leakage_units) unless duct_leakage_units.nil?
      XMLHelper.add_element(duct_leakage, "Value", duct_leakage_value) unless duct_leakage_value.nil?
      XMLHelper.add_element(duct_leakage, "TotalOrToOutside", duct_leakage_total_or_to_outside) unless duct_leakage_total_or_to_outside.nil?
    end

    return duct_leakage_measurement
  end

  def self.add_ducts(air_distribution:,
                     duct_type: nil,
                     duct_insulation_r_value: nil,
                     duct_location: nil,
                     duct_surface_area: nil)
    ducts = XMLHelper.add_element(air_distribution, "Ducts")
    XMLHelper.add_element(ducts, "DuctType", duct_type) unless duct_type.nil?
    XMLHelper.add_element(ducts, "DuctInsulationRValue", duct_insulation_r_value) unless duct_insulation_r_value.nil?
    XMLHelper.add_element(ducts, "DuctLocation", duct_location) unless duct_location.nil?
    XMLHelper.add_element(ducts, "DuctSurfaceArea", duct_surface_area) unless duct_surface_area.nil?

    return ducts
  end

  def self.add_ventilation_fan(ventilation_fans:,
                               id:,
                               fan_type: nil,
                               rated_flow_rate: nil,
                               hours_in_operation: nil,
                               used_for_whole_building_ventilation: nil,
                               total_recovery_efficiency: nil,
                               sensible_recovery_efficiency: nil,
                               fan_power: nil,
                               idref: nil)
    ventilation_fan = XMLHelper.add_element(ventilation_fans, "VentilationFan")
    sys_id = XMLHelper.add_element(ventilation_fan, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(ventilation_fan, "FanType", fan_type) unless fan_type.nil?
    XMLHelper.add_element(ventilation_fan, "RatedFlowRate", rated_flow_rate) unless rated_flow_rate.nil?
    XMLHelper.add_element(ventilation_fan, "HoursInOperation", hours_in_operation) unless hours_in_operation.nil?
    XMLHelper.add_element(ventilation_fan, "UsedForWholeBuildingVentilation", used_for_whole_building_ventilation) unless used_for_whole_building_ventilation.nil?
    XMLHelper.add_element(ventilation_fan, "TotalRecoveryEfficiency", total_recovery_efficiency) unless total_recovery_efficiency.nil?
    XMLHelper.add_element(ventilation_fan, "SensibleRecoveryEfficiency", sensible_recovery_efficiency) unless sensible_recovery_efficiency.nil?
    XMLHelper.add_element(ventilation_fan, "FanPower", fan_power) unless fan_power.nil?
    unless idref.nil?
      attached_to_hvac_distribution_system = XMLHelper.add_element(ventilation_fan, "AttachedToHVACDistributionSystem")
      XMLHelper.add_attribute(attached_to_hvac_distribution_system, "idref", idref)
    end

    return ventilation_fan
  end

  def self.add_water_heating_system(water_heating:,
                                    id:,
                                    fuel_type: nil,
                                    water_heater_type: nil,
                                    location: nil,
                                    tank_volume: nil,
                                    fraction_dhw_load_served: nil,
                                    heating_capacity: nil,
                                    energy_factor: nil,
                                    recovery_efficiency: nil)
    water_heating_system = XMLHelper.add_element(water_heating, "WaterHeatingSystem")
    sys_id = XMLHelper.add_element(water_heating_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(water_heating_system, "FuelType", fuel_type) unless fuel_type.nil?
    XMLHelper.add_element(water_heating_system, "WaterHeaterType", water_heater_type) unless water_heater_type.nil?
    XMLHelper.add_element(water_heating_system, "Location", location) unless location.nil?
    XMLHelper.add_element(water_heating_system, "TankVolume", tank_volume) unless tank_volume.nil?
    XMLHelper.add_element(water_heating_system, "FractionDHWLoadServed", fraction_dhw_load_served) unless fraction_dhw_load_served.nil?
    XMLHelper.add_element(water_heating_system, "HeatingCapacity", heating_capacity) unless heating_capacity.nil?
    XMLHelper.add_element(water_heating_system, "EnergyFactor", energy_factor) unless energy_factor.nil?
    XMLHelper.add_element(water_heating_system, "RecoveryEfficiency", recovery_efficiency) unless recovery_efficiency.nil?

    return water_heating_system
  end

  def self.add_hot_water_distribution(water_heating:,
                                      id:,
                                      system_type: nil,
                                      pipe_r_value: nil,
                                      standard_piping_length: nil,
                                      recirculation_control_type: nil,
                                      recirculation_piping_loop_length: nil,
                                      recirculation_branch_piping_loop_length: nil,
                                      recirculation_pump_power: nil,
                                      drain_water_heat_recovery_facilities_connected: nil,
                                      drain_water_heat_recovery_equal_flow: nil,
                                      drain_water_heat_recovery_efficiency: nil)
    hot_water_distribution = XMLHelper.add_element(water_heating, "HotWaterDistribution")
    sys_id = XMLHelper.add_element(hot_water_distribution, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless system_type.nil?
      system_type_e = XMLHelper.add_element(hot_water_distribution, "SystemType")
      if system_type == "Standard"
        standard = XMLHelper.add_element(system_type_e, system_type)
        XMLHelper.add_element(standard, "PipingLength", standard_piping_length) unless standard_piping_length.nil?
      elsif system_type == "Recirculation"
        recirculation = XMLHelper.add_element(system_type_e, system_type)
        XMLHelper.add_element(recirculation, "ControlType", recirculation_control_type) unless recirculation_control_type.nil?
        XMLHelper.add_element(recirculation, "RecirculationPipingLoopLength", recirculation_piping_loop_length) unless recirculation_piping_loop_length.nil?
        XMLHelper.add_element(recirculation, "BranchPipingLoopLength", recirculation_branch_piping_loop_length) unless recirculation_branch_piping_loop_length.nil?
        XMLHelper.add_element(recirculation, "PumpPower", recirculation_pump_power) unless recirculation_pump_power.nil?
      else
        fail "Unhandled hot water system type '#{system_type}'."
      end
    end
    unless pipe_r_value.nil?
      pipe_insulation = XMLHelper.add_element(hot_water_distribution, "PipeInsulation")
      XMLHelper.add_element(pipe_insulation, "PipeRValue", pipe_r_value)
    end
    if not drain_water_heat_recovery_facilities_connected.nil? or not drain_water_heat_recovery_equal_flow.nil? or not drain_water_heat_recovery_efficiency.nil?
      drain_water_heat_recovery = XMLHelper.add_element(hot_water_distribution, "DrainWaterHeatRecovery")
      XMLHelper.add_element(drain_water_heat_recovery, "FacilitiesConnected", drain_water_heat_recovery_facilities_connected) unless drain_water_heat_recovery_facilities_connected.nil?
      XMLHelper.add_element(drain_water_heat_recovery, "EqualFlow", drain_water_heat_recovery_equal_flow) unless drain_water_heat_recovery_equal_flow.nil?
      XMLHelper.add_element(drain_water_heat_recovery, "Efficiency", drain_water_heat_recovery_efficiency) unless drain_water_heat_recovery_efficiency.nil?
    end

    return hot_water_distribution
  end

  def self.add_water_fixture(water_heating:,
                             id:,
                             water_fixture_type: nil,
                             low_flow: nil)
    water_fixture = XMLHelper.add_element(water_heating, "WaterFixture")
    sys_id = XMLHelper.add_element(water_fixture, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(water_fixture, "WaterFixtureType", water_fixture_type) unless water_fixture_type.nil?
    XMLHelper.add_element(water_fixture, "LowFlow", low_flow) unless low_flow.nil?

    return water_fixture
  end

  def self.add_pv_system(photovoltaics:,
                         id:,
                         module_type: nil,
                         array_type: nil,
                         array_azimuth: nil,
                         array_tilt: nil,
                         max_power_output: nil,
                         inverter_efficiency: nil,
                         system_losses_fraction: nil)
    pv_system = XMLHelper.add_element(photovoltaics, "PVSystem")
    sys_id = XMLHelper.add_element(pv_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(pv_system, "ModuleType", module_type) unless module_type.nil?
    XMLHelper.add_element(pv_system, "ArrayType", array_type) unless array_type.nil?
    XMLHelper.add_element(pv_system, "ArrayAzimuth", array_azimuth) unless array_azimuth.nil?
    XMLHelper.add_element(pv_system, "ArrayTilt", array_tilt) unless array_tilt.nil?
    XMLHelper.add_element(pv_system, "MaxPowerOutput", max_power_output) unless max_power_output.nil?
    XMLHelper.add_element(pv_system, "InverterEfficiency", inverter_efficiency) unless inverter_efficiency.nil?
    XMLHelper.add_element(pv_system, "SystemLossesFraction", system_losses_fraction) unless system_losses_fraction.nil?

    return pv_system
  end

  def self.add_clothes_washer(appliances:,
                              id:,
                              location: nil,
                              modified_energy_factor: nil,
                              integrated_modified_energy_factor: nil,
                              rated_annual_kwh: nil,
                              label_electric_rate: nil,
                              label_gas_rate: nil,
                              label_annual_gas_cost: nil,
                              capacity: nil)
    clothes_washer = XMLHelper.add_element(appliances, "ClothesWasher")
    sys_id = XMLHelper.add_element(clothes_washer, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(clothes_washer, "Location", location) unless location.nil?
    XMLHelper.add_element(clothes_washer, "ModifiedEnergyFactor", modified_energy_factor) unless modified_energy_factor.nil?
    XMLHelper.add_element(clothes_washer, "IntegratedModifiedEnergyFactor", integrated_modified_energy_factor) unless integrated_modified_energy_factor.nil?
    XMLHelper.add_element(clothes_washer, "RatedAnnualkWh", rated_annual_kwh) unless rated_annual_kwh.nil?
    XMLHelper.add_element(clothes_washer, "LabelElectricRate", label_electric_rate) unless label_electric_rate.nil?
    XMLHelper.add_element(clothes_washer, "LabelGasRate", label_gas_rate) unless label_gas_rate.nil?
    XMLHelper.add_element(clothes_washer, "LabelAnnualGasCost", label_annual_gas_cost) unless label_annual_gas_cost.nil?
    XMLHelper.add_element(clothes_washer, "Capacity", capacity) unless capacity.nil?

    return clothes_washer
  end

  def self.add_clothes_dryer(appliances:,
                             id:,
                             location: nil,
                             fuel_type: nil,
                             energy_factor: nil,
                             combined_energy_factor: nil,
                             control_type: nil)
    clothes_dryer = XMLHelper.add_element(appliances, "ClothesDryer")
    sys_id = XMLHelper.add_element(clothes_dryer, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(clothes_dryer, "Location", location) unless location.nil?
    XMLHelper.add_element(clothes_dryer, "FuelType", fuel_type) unless fuel_type.nil?
    XMLHelper.add_element(clothes_dryer, "EnergyFactor", energy_factor) unless energy_factor.nil?
    XMLHelper.add_element(clothes_dryer, "CombinedEnergyFactor", combined_energy_factor) unless combined_energy_factor.nil?
    XMLHelper.add_element(clothes_dryer, "ControlType", control_type) unless control_type.nil?

    return clothes_dryer
  end

  def self.add_dishwasher(appliances:,
                          id:,
                          energy_factor: nil,
                          rated_annual_kwh: nil,
                          place_setting_capacity: nil)

    dishwasher = XMLHelper.add_element(appliances, "Dishwasher")
    sys_id = XMLHelper.add_element(dishwasher, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(dishwasher, "EnergyFactor", energy_factor) unless energy_factor.nil?
    XMLHelper.add_element(dishwasher, "RatedAnnualkWh", rated_annual_kwh) unless rated_annual_kwh.nil?
    XMLHelper.add_element(dishwasher, "PlaceSettingCapacity", place_setting_capacity) unless place_setting_capacity.nil?

    return dishwasher
  end

  def self.add_refrigerator(appliances:,
                            id:,
                            location: nil,
                            rated_annual_kwh: nil)
    refrigerator = XMLHelper.add_element(appliances, "Refrigerator")
    sys_id = XMLHelper.add_element(refrigerator, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(refrigerator, "Location", location) unless location.nil?
    XMLHelper.add_element(refrigerator, "RatedAnnualkWh", rated_annual_kwh) unless rated_annual_kwh.nil?

    return refrigerator
  end

  def self.add_cooking_range(appliances:,
                             id:,
                             fuel_type: nil,
                             is_induction: nil)
    cooking_range = XMLHelper.add_element(appliances, "CookingRange")
    sys_id = XMLHelper.add_element(cooking_range, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(cooking_range, "FuelType", fuel_type)
    XMLHelper.add_element(cooking_range, "IsInduction", is_induction) unless is_induction.nil?

    return cooking_range
  end

  def self.add_oven(appliances:,
                    id:,
                    is_convection: nil)
    oven = XMLHelper.add_element(appliances, "Oven")
    sys_id = XMLHelper.add_element(oven, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(oven, "IsConvection", is_convection) unless is_convection.nil?

    return oven
  end

  def self.add_lighting_fractions(lighting:,
                                  fraction_qualifying_tier_i_fixtures_interior: nil,
                                  fraction_qualifying_tier_i_fixtures_exterior: nil,
                                  fraction_qualifying_tier_i_fixtures_garage: nil,
                                  fraction_qualifying_tier_ii_fixtures_interior: nil,
                                  fraction_qualifying_tier_ii_fixtures_exterior: nil,
                                  fraction_qualifying_tier_ii_fixtures_garage: nil)
    lighting_fractions = XMLHelper.add_element(lighting, "LightingFractions")
    HPXML.add_extension(parent: lighting_fractions,
                        extensions: { "FractionQualifyingTierIFixturesInterior": fraction_qualifying_tier_i_fixtures_interior,
                                      "FractionQualifyingTierIFixturesExterior": fraction_qualifying_tier_i_fixtures_exterior,
                                      "FractionQualifyingTierIFixturesGarage": fraction_qualifying_tier_i_fixtures_garage,
                                      "FractionQualifyingTierIIFixturesInterior": fraction_qualifying_tier_ii_fixtures_interior,
                                      "FractionQualifyingTierIIFixturesExterior": fraction_qualifying_tier_ii_fixtures_exterior,
                                      "FractionQualifyingTierIIFixturesGarage": fraction_qualifying_tier_ii_fixtures_garage })

    return lighting_fractions
  end

  def self.add_ceiling_fan(lighting:,
                           id:,
                           fan_speed: nil,
                           efficiency: nil,
                           quantity: nil)

    ceiling_fan = XMLHelper.add_element(lighting, "CeilingFan")
    sys_id = XMLHelper.add_element(ceiling_fan, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    if not fan_speed.nil? or not efficiency.nil?
      airflow = XMLHelper.add_element(ceiling_fan, "Airflow")
      XMLHelper.add_element(airflow, "FanSpeed", fan_speed) unless fan_speed.nil?
      XMLHelper.add_element(airflow, "Efficiency", efficiency) unless efficiency.nil?
    end
    XMLHelper.add_element(ceiling_fan, "Quantity", quantity) unless quantity.nil?

    return ceiling_fan
  end

  def self.add_plug_load(misc_loads:,
                         id:,
                         plug_load_type: nil)
    plug_load = XMLHelper.add_element(misc_loads, "PlugLoad")
    sys_id = XMLHelper.add_element(plug_load, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(plug_load, "PlugLoadType", plug_load_type) unless plug_load_type.nil?

    return plug_load
  end

  def self.get_id(parent)
    return if parent.nil?
    return parent.elements["SystemIdentifier"].attributes["id"]
  end

  def self.get_idref(parent, element_name)
    return if parent.nil?
    element = parent.elements[element_name]
    return if element.nil?
    return element.attributes["idref"]
  end
end
