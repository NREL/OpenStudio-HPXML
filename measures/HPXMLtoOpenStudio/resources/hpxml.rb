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
      extension = XMLHelper.add_element(site, "extension")
      XMLHelper.add_element(extension, "ShelterCoefficient", shelter_coefficient)
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
                               id: nil,
                               name: nil,
                               wmo: nil)
    weather_station = XMLHelper.add_element(climate_and_risk_zones, "WeatherStation")
    sys_id = XMLHelper.add_element(weather_station, "SystemIdentifiersInfo")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    XMLHelper.add_element(weather_station, "Name", name) unless name.nil?
    XMLHelper.add_element(weather_station, "WMO", wmo) unless wmo.nil?

    return weather_station
  end

  def self.add_air_infiltration_measurement(air_infiltration:,
                                            id: nil,
                                            house_pressure: nil,
                                            unit_of_measure: nil,
                                            air_leakage: nil)
    air_infiltration_measurement = XMLHelper.add_element(air_infiltration, "AirInfiltrationMeasurement")
    sys_id = XMLHelper.add_element(air_infiltration_measurement, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    XMLHelper.add_element(air_infiltration_measurement, "HousePressure", house_pressure) unless house_pressure.nil?
    if not unit_of_measure.nil? and not air_leakage.nil?
      building_air_leakage = XMLHelper.add_element(air_infiltration_measurement, "BuildingAirLeakage")
      XMLHelper.add_element(building_air_leakage, "UnitofMeasure", unit_of_measure)
      XMLHelper.add_element(building_air_leakage, "AirLeakage", air_leakage)
    end

    return air_infiltration_measurement
  end

  def self.add_attic(attics:,
                     id: nil,
                     attic_type: nil)
    attic = XMLHelper.add_element(attics, "Attic")
    sys_id = XMLHelper.add_element(attic, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    XMLHelper.add_element(attic, "AtticType", attic_type) unless attic_type.nil?

    return attic
  end

  def self.add_roof(roofs:,
                    id: nil,
                    area: nil,
                    azimuth: nil,
                    solar_absorptance: nil,
                    emittance: nil,
                    pitch: nil,
                    radiant_barrier: nil)
    roof = XMLHelper.add_element(roofs, "Roof") # FIXME: Should be two (or four?) roofs per HES zone_roof?
    sys_id = XMLHelper.add_element(roof, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    XMLHelper.add_element(roof, "Area", area) unless area.nil?
    XMLHelper.add_element(roof, "Azimuth", azimuth) unless azimuth.nil?
    XMLHelper.add_element(roof, "SolarAbsorptance", solar_absorptance) unless solar_absorptance.nil?
    XMLHelper.add_element(roof, "Emittance", emittance) unless emittance.nil?
    XMLHelper.add_element(roof, "Pitch", pitch) unless pitch.nil?
    XMLHelper.add_element(roof, "RadiantBarrier", radiant_barrier) unless radiant_barrier.nil?

    return roof
  end

  def self.add_insulation(parent:,
                          id: nil,
                          assembly_effective_r_value: nil)
    insulation = XMLHelper.add_element(parent, "Insulation")
    sys_id = XMLHelper.add_element(insulation, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    XMLHelper.add_element(insulation, "AssemblyEffectiveRValue", assembly_effective_r_value) unless assembly_effective_r_value.nil?

    return insulation
  end

  def self.add_floor(floors:,
                     id: nil,
                     adjacent_to: nil,
                     area: nil)
    floor = XMLHelper.add_element(floors, "Floor")
    sys_id = XMLHelper.add_element(floor, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    XMLHelper.add_element(floor, "AdjacentTo", adjacent_to) unless adjacent_to.nil?
    XMLHelper.add_element(floor, "Area", area) unless area.nil?

    return floor
  end

  def self.add_foundation(foundations:,
                          id: nil,
                          foundation_type: nil)
    foundation = XMLHelper.add_element(foundations, "Foundation")
    sys_id = XMLHelper.add_element(foundation, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    unless foundation_type.nil?
      foundation_type_e = XMLHelper.add_element(foundation, "FoundationType")
      if foundation_type == "SlabOnGrade"
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
      end
    end

    return foundation
  end

  def self.add_frame_floor(foundation:,
                           id: nil,
                           adjacent_to: nil,
                           area: nil)
    frame_floor = XMLHelper.add_element(foundation, "FrameFloor")
    sys_id = XMLHelper.add_element(frame_floor, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    XMLHelpher.add_element(frame_floor, "AdjacentTo", adjacent_to) unless adjacent_to.nil?
    XMLHelper.add_element(frame_floor, "Area", area) unless area.nil?

    return frame_floor
  end

  def self.add_foundation_wall(foundation:,
                               id: nil,
                               height: nil,
                               area: nil,
                               thickness: nil,
                               depth_below_grade: nil,
                               adjacent_to: nil)
    foundation_wall = XMLHelper.add_element(foundation, "FoundationWall")
    sys_id = XMLHelper.add_element(foundation_wall, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    XMLHelper.add_element(foundation_wall, "Height", height) unless height.nil?
    XMLHelper.add_element(foundation_wall, "Area", area) unless area.nil?
    XMLHelper.add_element(foundation_wall, "Thickness", thickness) unless thickness.nil?
    XMLHelper.add_element(foundation_wall, "DepthBelowGrade", depth_below_grade) unless depth_below_grade.nil?
    XMLHelper.add_element(foundation_wall, "AdjacentTo", adjacent_to) unless adjacent_to.nil?

    return foundation_wall
  end

  def self.add_slab(foundation:,
                    id: nil,
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
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    XMLHelper.add_element(slab, "Area", area) unless area.nil?
    XMLHelper.add_element(slab, "Thickness", thickness) unless thickness.nil?
    XMLHelper.add_element(slab, "ExposedPerimeter", exposed_perimeter) unless exposed_perimeter.nil?
    XMLHelper.add_element(slab, "PerimeterInsulationDepth", perimeter_insulation_depth) unless perimeter_insulation_depth.nil?
    XMLHelper.add_element(slab, "UnderSlabInsulationWidth", under_slab_insulation_width) unless under_slab_insulation_width.nil?
    XMLHelper.add_element(slab, "DepthBelowGrade", depth_below_grade) unless depth_below_grade.nil?
    if not carpet_fraction.nil? and not carpet_r_value.nil?
      extension = XMLHelper.add_element(slab, "extension")
      XMLHelper.add_element(extension, "CarpetFraction", carpet_fraction)
      XMLHelper.add_element(extension, "CarpetRValue", carpet_r_value)
    end

    return slab
  end

  def self.add_perimeter_insulation(slab:,
                                    id: nil)
    perimeter_insulation = XMLHelper.add_element(slab, "PerimeterInsulation")
    sys_id = XMLHelper.add_element(perimeter_insulation, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?

    return perimeter_insulation
  end

  def self.add_under_slab_insulation(slab:,
                                     id: nil)
    under_slab_insulation = XMLHelper.add_element(slab, "UnderSlabInsulation")
    sys_id = XMLHelper.add_element(under_slab_insulation, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?

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
    unless extensions.empty?
      extension = XMLHelper.add_element(parent, "extension")
      extensions.each do |name, text|
        XMLHelper.add_element(extension, "#{name}", text) unless text.nil?
      end
    end

    return extension
  end

  def self.add_wall(walls:,
                    id: nil,
                    exterior_adjacent_to: nil,
                    interior_adjacent_to: nil,
                    wall_type: nil,
                    area: nil,
                    azimuth: nil,
                    solar_absorptance: nil,
                    emittance: nil)
    wall = XMLHelper.add_element(walls, "Wall")
    sys_id = XMLHelper.add_element(wall, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    XMLHelper.add_element(wall, "ExteriorAdjacentTo", exterior_adjacent_to) unless exterior_adjacent_to.nil?
    XMLHelper.add_element(wall, "InteriorAdjacentTo", interior_adjacent_to) unless interior_adjacent_to.nil?
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
                      id: nil,
                      area: nil,
                      azimuth: nil,
                      ufactor: nil,
                      shgc: nil,
                      idref: nil)
    window = XMLHelper.add_element(windows, "Window")
    sys_id = XMLHelper.add_element(window, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    XMLHelper.add_element(window, "Area", area) unless area.nil?
    XMLHelper.add_element(window, "Azimuth", azimuth) unless azimuth.nil?
    XMLHelper.add_element(window, "UFactor", ufactor) unless ufactor.nil?
    XMLHelper.add_element(window, "SHGC", shgc) unless shgc.nil?
    unless idref.nil?
      attached_to_wall = XMLHelper.add_element(window, "AttachedToWall")
      XMLHelper.add_attribute(attached_to_wall, "idref", idref)
    end

    return window
  end

  def self.add_skylight(skylights:,
                        id: nil,
                        area: nil,
                        azimuth: nil,
                        ufactor: nil,
                        shgc: nil,
                        idref: nil)
    skylight = XMLHelper.add_element(skylights, "Skylight")
    sys_id = XMLHelper.add_element(skylight, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
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
                    id: nil,
                    idref: nil,
                    azimuth: nil)
    door = XMLHelper.add_element(doors, "Door")
    sys_id = XMLHelper.add_element(door, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    unless idref.nil?
      attached_to_wall = XMLHelper.add_element(door, "AttachedToWall")
      XMLHelper.add_attribute(attached_to_wall, "idref", idref)
    end
    XMLHelper.add_element(door, "Azimuth", azimuth) unless azimuth.nil?

    return door
  end

  def self.add_heating_system(hvac_plant:,
                              id: nil,
                              idref: nil,
                              heating_system_type: nil,
                              heating_system_fuel: nil,
                              heating_capacity: nil,
                              annual_heating_efficiency_units: nil,
                              annual_heating_efficiency_value: nil,
                              fraction_heat_load_served: nil)
    heating_system = XMLHelper.add_element(hvac_plant, "HeatingSystem")
    sys_id = XMLHelper.add_element(heating_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
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
                              id: nil,
                              idref: nil,
                              cooling_system_type: nil,
                              cooling_system_fuel: nil,
                              cooling_capacity: nil,
                              fraction_cool_load_served: nil,
                              annual_cooling_efficiency_units: nil,
                              annual_cooling_efficiency_value: nil)
    cooling_system = XMLHelper.add_element(hvac_plant, "CoolingSystem")
    sys_id = XMLHelper.add_element(cooling_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
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
                         id: nil,
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
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
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
    if not anunal_heating_efficiency_units.nil? and not annual_heating_efficiency_value.nil?
      annual_heating_efficiency = XMLHelper.add_element(heat_pump, "AnnualHeatingEfficiency")
      XMLHelper.add_element(annual_heating_efficiency, "Units", annual_heating_efficiency_units)
      XMLHelper.add_element(annual_heating_efficiency, "Value", fraction_heat_load_served)
    end

    return heat_pump
  end

  def self.add_hvac_control(hvac:,
                            id: nil,
                            control_type: nil)
    hvac_control = XMLHelper.add_element(hvac, "HVACControl")
    sys_id = XMLHelper.add_element(hvac_control, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?
    XMLHelper.add_element(hvac_control, "ControlType", control_type) unless control_type.nil?

    return hvac_control
  end

  def self.add_hvac_distribution(hvac:,
                                 id: nil)
    hvac_distribution = XMLHelper.add_element(hvac, "HVACDistribution")
    sys_id = XMLHelper.add_element(hvac_distribution, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id) unless id.nil?

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

end