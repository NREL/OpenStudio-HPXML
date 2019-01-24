class HPXML
  def self.create_hpxml(xml_type: nil,
                        xml_generated_by: nil,
                        transaction: nil,
                        software_program_used: nil,
                        software_program_version: nil,
                        eri_calculation_version: nil,
                        building_id: nil,
                        event_type: nil)
    doc = XMLHelper.create_doc(version = "1.0", encoding = "UTF-8")
    doc.add_element "HPXML"
    hpxml = doc.elements["HPXML"]
    XMLHelper.add_attribute(hpxml, "xmlns", "http://hpxmlonline.com/2014/6")
    XMLHelper.add_attribute(hpxml, "xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance")
    XMLHelper.add_attribute(hpxml, "xsi:schemaLocation", "http://hpxmlonline.com/2014/6")
    XMLHelper.add_attribute(hpxml, "schemaVersion", "3.0")

    add_xml_transaction_header_information(hpxml: hpxml,
                                           xml_type: xml_type,
                                           xml_generated_by: xml_generated_by,
                                           transaction: transaction)

    add_software_info(hpxml: hpxml,
                      software_program_used: software_program_used,
                      software_program_version: software_program_version,
                      eri_calculation_version: eri_calculation_version)

    add_building(hpxml: hpxml,
                 id: building_id,
                 event_type: event_type)

    return doc
  end

  def self.get_hpxml_version(hpxml:)
    return nil if hpxml.nil?

    return { :schema_version => hpxml.attributes["schemaVersion"] }
  end

  def self.get_hpxml_values(doc)
    values = {}

    hpxml = doc.elements["HPXML"]

    values[:xml_transaction_header_information] = get_xml_transaction_header_information_values(xml_transaction_header_information: hpxml.elements["XMLTransactionHeaderInformation"])
    values[:software_info] = get_software_info_values(software_info: hpxml.elements["SoftwareInfo"])
    values[:building] = get_building_values(building: hpxml.elements["Building"])
    values[:project_status] = get_project_status_values(project_status: hpxml.elements["Building/ProjectStatus"])
    values[:site] = get_site_values(site: hpxml.elements["Building/BuildingDetails/BuildingSummary/Site"])
    values[:building_occupancy] = get_building_occupancy_values(building_occupancy: hpxml.elements["Building/BuildingDetails/BuildingSummary/BuildingOccupancy"])
    values[:building_construction] = get_building_construction_values(building_construction: hpxml.elements["Building/BuildingDetails/BuildingSummary/BuildingConstruction"])
    values[:climate_zone_iecc] = []
    hpxml.elements.each("Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC") do |climate_zone_iecc|
      values[:climate_zone_iecc] << get_climate_zone_iecc_values(climate_zone_iecc: climate_zone_iecc)
    end
    values[:weather_station] = get_weather_station_values(weather_station: hpxml.elements["Building/BuildingDetails/ClimateandRiskZones/WeatherStation"])
    values[:air_infiltration_measurement] = []
    hpxml.elements.each("Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement") do |air_infiltration_measurement|
      values[:air_infiltration_measurement] << get_air_infiltration_measurement_values(air_infiltration_measurement: air_infiltration_measurement)
    end
    # TODO: ...

    return values
  end

  def self.add_xml_transaction_header_information(hpxml:,
                                                  xml_type: nil,
                                                  xml_generated_by: nil,
                                                  transaction: nil)
    xml_transaction_header_information = XMLHelper.add_element(hpxml, "XMLTransactionHeaderInformation")
    XMLHelper.add_element(xml_transaction_header_information, "XMLType", xml_type)
    XMLHelper.add_element(xml_transaction_header_information, "XMLGeneratedBy", xml_generated_by) unless xml_generated_by.nil?
    XMLHelper.add_element(xml_transaction_header_information, "CreatedDateAndTime", "2014-11-17T15:17:17.128-07:00") # TODO: get current date and time
    XMLHelper.add_element(xml_transaction_header_information, "Transaction", transaction) unless transaction.nil?

    return xml_transaction_header_information
  end

  def self.get_xml_transaction_header_information_values(xml_transaction_header_information:)
    return nil if xml_transaction_header_information.nil?

    return { :xml_type => XMLHelper.get_value(xml_transaction_header_information, "XMLType"),
             :xml_generated_by => XMLHelper.get_value(xml_transaction_header_information, "XMLGeneratedBy"),
             :created_date_and_time => XMLHelper.get_value(xml_transaction_header_information, "CreatedDateAndTime"),
             :transaction => XMLHelper.get_value(xml_transaction_header_information, "Transaction") }
  end

  def self.add_software_info(hpxml:,
                             software_program_used: nil,
                             software_program_version: nil,
                             eri_calculation_version: nil)
    software_info = XMLHelper.add_element(hpxml, "SoftwareInfo")
    XMLHelper.add_element(software_info, "SoftwareProgramUsed", software_program_used) unless software_program_used.nil?
    XMLHelper.add_element(software_info, "SoftwareProgramVersion", software_program_version) unless software_program_version.nil?
    unless eri_calculation_version.nil?
      eri_calculation = XMLHelper.add_element(software_info, "extension/ERICalculation")
      XMLHelper.add_element(eri_calculation, "Version", eri_calculation_version)
    end

    return software_info
  end

  def self.get_software_info_values(software_info:)
    return nil if software_info.nil?

    return { :software_program_used => XMLHelper.get_value(software_info, "SoftwareProgramUsed"),
             :software_program_version => XMLHelper.get_value(software_info, "SoftwareProgramVersion"),
             :eri_calculation_version => XMLHelper.get_value(software_info, "extension/ERICalculation/Version") }
  end

  def self.add_building(hpxml:,
                        id: nil,
                        event_type: nil)
    building = XMLHelper.add_element(hpxml, "Building")
    building_id = XMLHelper.add_element(building, "BuildingID")
    XMLHelper.add_attribute(building_id, "id", id)

    add_project_status(hpxml: hpxml,
                       event_type: event_type)

    XMLHelper.add_element(building, "BuildingDetails/BuildingSummary")

    return building
  end

  def self.get_building_values(building:)
    return nil if building.nil?

    return { :id => building.elements["BuildingID"].attributes["id"] }
  end

  def self.add_project_status(hpxml:,
                              event_type: nil)
    building = hpxml.elements["Building"]
    project_status = XMLHelper.add_element(building, "ProjectStatus")
    XMLHelper.add_element(project_status, "EventType", event_type) unless event_type.nil?

    return project_status
  end

  def self.get_project_status_values(project_status:)
    return nil if project_status.nil?

    return { :event_type => XMLHelper.get_value(project_status, "EventType") }
  end

  def self.add_site(hpxml:,
                    surroundings: nil,
                    orientation_of_front_of_home: nil,
                    fuels: [],
                    shelter_coefficient: nil)
    building_summary = hpxml.elements["Building/BuildingDetails/BuildingSummary"]
    if building_summary.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      building_summary = XMLHelper.add_element(building_details, "BuildingSummary")
    end
    site = XMLHelper.add_element(building_summary, "Site")
    XMLHelper.add_element(site, "Surroundings", surroundings) unless surroundings.nil?
    XMLHelper.add_element(site, "OrientationOfFrontOfHome", orientation_of_front_of_home) unless orientation_of_front_of_home.nil?
    unless fuels.empty?
      fuel_types_available = XMLHelper.add_element(site, "FuelTypesAvailable")
      fuels.each do |fuel|
        XMLHelper.add_element(fuel_types_available, "Fuel", fuel)
      end
    end
    HPXML.add_extension(parent: site,
                        extensions: { "ShelterCoefficient": shelter_coefficient })

    return site
  end

  def self.get_site_values(site:)
    return nil if site.nil?

    return { :surroundings => XMLHelper.get_value(site, "Surroundings"),
             :orientation_of_front_of_home => XMLHelper.get_value(site, "OrientationOfFrontOfHome"),
             :fuels => XMLHelper.get_values(site, "FuelTypesAvailable/Fuel"),
             :shelter_coefficient => XMLHelper.get_value(site, "extension/ShelterCoefficient") }
  end

  def self.add_building_occupancy(hpxml:,
                                  number_of_residents: nil)
    building_summary = hpxml.elements["Building/BuildingDetails/BuildingSummary"]
    if building_summary.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      building_summary = XMLHelper.add_element(building_details, "BuildingSummary")
    end
    building_occupancy = XMLHelper.add_element(building_summary, "BuildingOccupancy")
    XMLHelper.add_element(building_occupancy, "NumberofResidents", number_of_residents) unless number_of_residents.nil?

    return building_occupancy
  end

  def self.get_building_occupancy_values(building_occupancy:)
    return nil if building_occupancy.nil?

    return { :number_of_residents => XMLHelper.get_value(building_occupancy, "NumberofResidents") }
  end

  def self.add_building_construction(hpxml:,
                                     number_of_conditioned_floors: nil,
                                     number_of_conditioned_floors_above_grade: nil,
                                     average_ceiling_height: nil,
                                     number_of_bedrooms: nil,
                                     conditioned_floor_area: nil,
                                     conditioned_building_volume: nil,
                                     garage_present: nil)
    building_summary = hpxml.elements["Building/BuildingDetails/BuildingSummary"]
    if building_summary.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      building_summary = XMLHelper.add_element(building_details, "BuildingSummary")
    end
    building_construction = XMLHelper.add_element(building_summary, "BuildingConstruction")
    XMLHelper.add_element(building_construction, "NumberofConditionedFloors", number_of_conditioned_floors) unless number_of_conditioned_floors.nil?
    XMLHelper.add_element(building_construction, "NumberofConditionedFloorsAboveGrade", number_of_conditioned_floors_above_grade) unless number_of_conditioned_floors_above_grade.nil?
    XMLHelper.add_element(building_construction, "AverageCeilingHeight", average_ceiling_height) unless average_ceiling_height.nil?    
    XMLHelper.add_element(building_construction, "NumberofBedrooms", number_of_bedrooms) unless number_of_bedrooms.nil?
    XMLHelper.add_element(building_construction, "ConditionedFloorArea", conditioned_floor_area) unless conditioned_floor_area.nil?
    XMLHelper.add_element(building_construction, "ConditionedBuildingVolume", conditioned_building_volume) unless conditioned_building_volume.nil?
    XMLHelper.add_element(building_construction, "GaragePresent", garage_present) unless garage_present.nil?

    return building_construction
  end

  def self.get_building_construction_values(building_construction:)
    return nil if building_construction.nil?

    return { :number_of_conditioned_floors => XMLHelper.get_value(building_construction, "NumberofConditionedFloors"),
             :number_of_conditioned_floors_above_grade => XMLHelper.get_value(building_construction, "NumberofConditionedFloorsAboveGrade"),
             :average_ceiling_height => XMLHelper.get_value(building_construction, "AverageCeilingHeight"),
             :number_of_bedrooms => XMLHelper.get_value(building_construction, "NumberofBedrooms"),
             :conditioned_floor_area => XMLHelper.get_value(building_construction, "ConditionedFloorArea"),
             :conditioned_building_volume => XMLHelper.get_value(building_construction, "ConditionedBuildingVolume"),
             :garage_present => XMLHelper.get_value(building_construction, "GaragePresent") }
  end

  def self.add_climate_zone_iecc(hpxml:,
                                 year: nil,
                                 climate_zone: nil)
    climate_and_risk_zones = hpxml.elements["Building/BuildingDetails/ClimateandRiskZones"]
    if climate_and_risk_zones.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      climate_and_risk_zones = XMLHelper.add_element(building_details, "ClimateandRiskZones")
    end
    climate_zone_iecc = XMLHelper.add_element(climate_and_risk_zones, "ClimateZoneIECC")
    XMLHelper.add_element(climate_zone_iecc, "Year", year) unless year.nil?
    XMLHelper.add_element(climate_zone_iecc, "ClimateZone", climate_zone) unless climate_zone.nil?

    return climate_zone_iecc
  end

  def self.get_climate_zone_iecc_values(climate_zone_iecc:)
    return nil if climate_zone_iecc.nil?

    return { :year => XMLHelper.get_value(climate_zone_iecc, "Year"),
             :climate_zone => XMLHelper.get_value(climate_zone_iecc, "ClimateZone") }
  end

  def self.add_weather_station(hpxml:,
                               id:,
                               name: nil,
                               wmo: nil)
    climate_and_risk_zones = hpxml.elements["Building/BuildingDetails/ClimateandRiskZones"]
    if climate_and_risk_zones.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      climate_and_risk_zones = XMLHelper.add_element(building_details, "ClimateandRiskZones")
    end
    weather_station = XMLHelper.add_element(climate_and_risk_zones, "WeatherStation")
    sys_id = XMLHelper.add_element(weather_station, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(weather_station, "Name", name) unless name.nil?
    XMLHelper.add_element(weather_station, "WMO", wmo) unless wmo.nil?

    return weather_station
  end

  def self.get_weather_station_values(weather_station:)
    return nil if weather_station.nil?

    return { :id => HPXML.get_id(weather_station),
             :name => XMLHelper.get_value(weather_station, "Name"),
             :wmo => XMLHelper.get_value(weather_station, "WMO") }
  end

  def self.add_air_infiltration_measurement(hpxml:,
                                            id:,
                                            house_pressure: nil,
                                            unit_of_measure: nil,
                                            air_leakage: nil,
                                            effective_leakage_area: nil)
    air_infiltration = hpxml.elements["Building/BuildingDetails/Enclosure/AirInfiltration"]
    if air_infiltration.nil?
      enclosure = hpxml.elements["Building/BuildingDetails/Enclosure"]
      if enclosure.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        enclosure = XMLHelper.add_element(building_details, "Enclosure")
      end
      air_infiltration = XMLHelper.add_element(enclosure, "AirInfiltration")
    end
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

  def self.get_air_infiltration_measurement_values(air_infiltration_measurement:)
    return nil if air_infiltration_measurement.nil?

    return { :id => HPXML.get_id(air_infiltration_measurement),
             :house_pressure => XMLHelper.get_value(air_infiltration_measurement, "HousePressure"),
             :unit_of_measure => XMLHelper.get_value(air_infiltration_measurement, "BuildingAirLeakage/UnitofMeasure"),
             :air_leakage => XMLHelper.get_value(air_infiltration_measurement, "BuildingAirLeakage/AirLeakage"),
             :effective_leakage_area => XMLHelper.get_value(air_infiltration_measurement, "EffectiveLeakageArea") }
  end

  def self.add_attic(hpxml:,
                     id:,
                     attic_type: nil)
    attics = hpxml.elements["Building/BuildingDetails/Enclosure/Attics"]
    if attics.nil?
      enclosure = hpxml.elements["Building/BuildingDetails/Enclosure"]
      if enclosure.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        enclosure = XMLHelper.add_element(building_details, "Enclosure")
      end
      attics = XMLHelper.add_element(enclosure, "Attics")
    end
    attic = XMLHelper.add_element(attics, "Attic")
    sys_id = XMLHelper.add_element(attic, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(attic, "AtticType", attic_type) unless attic_type.nil?

    return attic
  end

  def self.get_attic_values(attic:)
    return nil if attic.nil?

    return { :id => HPXML.get_id(attic),
             :attic_type => XMLHelper.get_value(attic, "AtticType") }
  end

  def self.add_attic_roof(attic:,
                          id:,
                          area: nil,
                          azimuth: nil,
                          roof_type: nil,
                          roof_color: nil,
                          solar_absorptance: nil,
                          emittance: nil,
                          pitch: nil,
                          radiant_barrier: nil)
    roofs = attic.elements["Roofs"]
    if roofs.nil?
      roofs = XMLHelper.add_element(attic, "Roofs")
    end
    roof = XMLHelper.add_element(roofs, "Roof")
    sys_id = XMLHelper.add_element(roof, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(roof, "Area", area) unless area.nil?
    XMLHelper.add_element(roof, "Azimuth", azimuth) unless azimuth.nil?
    XMLHelper.add_element(roof, "RoofType", roof_type) unless roof_type.nil?
    XMLHelper.add_element(roof, "RoofColor", roof_color) unless roof_color.nil?
    XMLHelper.add_element(roof, "SolarAbsorptance", solar_absorptance) unless solar_absorptance.nil?
    XMLHelper.add_element(roof, "Emittance", emittance) unless emittance.nil?
    XMLHelper.add_element(roof, "Pitch", pitch) unless pitch.nil?
    XMLHelper.add_element(roof, "RadiantBarrier", radiant_barrier) unless radiant_barrier.nil?

    return roof
  end

  def self.get_roof_values(roof:)
    return nil if roof.nil?

    return { :id => HPXML.get_id(roof),
             :area => XMLHelper.get_value(roof, "Area"),
             :azimuth => XMLHelper.get_value(roof, "Azimuth"),
             :roof_type => XMLHelper.get_value(roof, "RoofType"),
             :roof_color => XMLHelper.get_value(roof, "RoofColor"),
             :solar_absorptance => XMLHelper.get_value(roof, "SolarAbsorptance"),
             :emittance => XMLHelper.get_value(roof, "Emittance"),
             :pitch => XMLHelper.get_value(roof, "Pitch"),
             :radiant_barrier => XMLHelper.get_value(roof, "RadiantBarrier") }
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

  def self.get_insulation_values(insulation:)
    return nil if insulation.nil?

    return { :id => HPXML.get_id(insulation),
             :assembly_effective_r_value => XMLHelper.get_value(insulation, "AssemblyEffectiveRValue") }
  end

  def self.add_attic_floor(attic:,
                           id:,
                           adjacent_to: nil,
                           area: nil)
    floors = attic.elements["Floors"]
    if floors.nil?
      floors = XMLHelper.add_element(attic, "Floors")
    end
    floor = XMLHelper.add_element(floors, "Floor")
    sys_id = XMLHelper.add_element(floor, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(floor, "AdjacentTo", adjacent_to) unless adjacent_to.nil?
    XMLHelper.add_element(floor, "Area", area) unless area.nil?

    return floor
  end

  def self.get_floor_values(floor:)
    return nil if floor.nil?

    return { :id => HPXML.get_id(floor),
             :adjacent_to => XMLHelper.get_value(floor, "AdjacentTo"),
             :area => XMLHelper.get_value(floor, "Area") }
  end

  def self.add_attic_wall(attic:,
                          id:,
                          exterior_adjacent_to: nil,
                          interior_adjacent_to: nil,
                          adjacent_to: nil,
                          wall_type: nil,
                          area: nil,
                          azimuth: nil,
                          solar_absorptance: nil,
                          emittance: nil)
    walls = attic.elements["Walls"]
    if walls.nil?
      walls = XMLHelper.add_element(attic, "Walls")
    end
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

  def self.add_foundation(hpxml:,
                          id:,
                          foundation_type: nil,
                          crawlspace_specific_leakage_area: nil)
    foundations = hpxml.elements["Building/BuildingDetails/Enclosure/Foundations"]
    if foundations.nil?
      enclosure = hpxml.elements["Building/BuildingDetails/Enclosure"]
      if enclosure.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        enclosure = XMLHelper.add_element(building_details, "Enclosure")
      end
      foundations = XMLHelper.add_element(enclosure, "Foundations")
    end
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
    HPXML.add_extension(parent: foundation,
                        extensions: { "CrawlspaceSpecificLeakageArea": crawlspace_specific_leakage_area })

    return foundation
  end

  def self.get_foundation_values(foundation:)
    return nil if foundation.nil?

    foundation_type = nil
    if XMLHelper.has_element(foundation, "FoundationType/SlabOnGrade")
      foundation_type = "SlabOnGrade"
    elsif XMLHelper.has_element(foundation, "FoundationType/Basement[Conditioned='false']")
      foundation_type = "UnconditionedBasement"
    elsif XMLHelper.has_element(foundation, "FoundationType/Basement[Conditioned='true']")
      foundation_type = "ConditionedBasement"
    elsif XMLHelper.has_element(foundation, "FoundationType/Crawlspace[Vented='false']")
      foundation_type = "UnventedCrawlspace"
    elsif XMLHelper.has_element(foundation, "FoundationType/Crawlspace[Vented='true']")
      foundation_type = "VentedCrawlspace"
    elsif XMLHelper.has_element(foundation, "FoundationType/Ambient")
      foundation_type = "Ambient"
    end

    return { :id => HPXML.get_id(foundation),
             :foundation_type => foundation_type,
             :crawlspace_specific_leakage_area => XMLHelper.get_value(foundation, "extension/CrawlspaceSpecificLeakageArea") }
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

  def self.get_foundation_wall_values(foundation_wall:)
    return nil if foundation_wall.nil?

    return { :id => HPXML.get_id(foundation_wall),
             :height => XMLHelper.get_value(foundation_wall, "Height"),
             :area => XMLHelper.get_value(foundation_wall, "Area"),
             :thickness => XMLHelper.get_value(foundation_wall, "Thickness"),
             :depth_below_grade => XMLHelper.get_value(foundation_wall, "DepthBelowGrade"),
             :adjacent_to => XMLHelper.get_value(foundation_wall, "AdjacentTo") }
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
    HPXML.add_extension(parent: slab,
                        extensions: { "CarpetFraction": carpet_fraction,
                                      "CarpetRValue": carpet_r_value })

    return slab
  end

  def self.get_slab_values(slab:)
    return nil if slab.nil?

    return { :id => HPXML.get_id(slab),
             :area => XMLHelper.get_value(slab, "Area"),
             :thickness => XMLHelper.get_value(slab, "Thickness"),
             :exposed_perimeter => XMLHelper.get_value(slab, "ExposedPerimeter"),
             :perimeter_insulation_depth => XMLHelper.get_value(slab, "PerimeterInsulationDepth"),
             :under_slab_insulation_width => XMLHelper.get_value(slab, "UnderSlabInsulationWidth"),
             :depth_below_grade => XMLHelper.get_value(slab, "DepthBelowGrade"),
             :carpet_fraction => XMLHelper.get_value(slab, "extension/CarpetFraction"),
             :carpet_r_value => XMLHelper.get_value(slab, "extension/CarpetRValue") }
  end

  def self.add_perimeter_insulation(slab:,
                                    id:)
    perimeter_insulation = XMLHelper.add_element(slab, "PerimeterInsulation")
    sys_id = XMLHelper.add_element(perimeter_insulation, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)

    return perimeter_insulation
  end

  def self.get_perimeter_insulation_values(perimeter_insulation:)
    return nil if perimeter_insulation.nil?

    return { :id => HPXML.get_id(perimeter_insulation) }
  end

  def self.add_under_slab_insulation(slab:,
                                     id:)
    under_slab_insulation = XMLHelper.add_element(slab, "UnderSlabInsulation")
    sys_id = XMLHelper.add_element(under_slab_insulation, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)

    return under_slab_insulation
  end

  def self.get_under_slab_insulation_values(under_slab_insulation:)
    return nil if under_slab_insulation.nil?

    return { :id => HPXML.get_id(under_slab_insulation) }
  end

  def self.add_layer(insulation:,
                     installation_type: nil,
                     nominal_r_value: nil)
    layer = XMLHelper.add_element(insulation, "Layer")
    XMLHelper.add_element(layer, "InstallationType", installation_type) unless installation_type.nil?
    XMLHelper.add_element(layer, "NominalRValue", nominal_r_value) unless nominal_r_value.nil?

    return layer
  end

  def self.get_layer_values(layer:)
    return nil if layer.nil?

    return { :installation_type => XMLHelper.get_value(layer, "InstallationType"),
             :nominal_r_value => XMLHelper.get_value(layer, "NominalRValue") }
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

  def self.add_rim_joist(hpxml:,
                         id:,
                         exterior_adjacent_to: nil,
                         interior_adjacent_to: nil,
                         area: nil)
    rim_joists = hpxml.elements["Building/BuildingDetails/Enclosure/RimJoists"]
    if rim_joists.nil?
      enclosure = hpxml.elements["Building/BuildingDetails/Enclosure"]
      if enclosure.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        enclosure = XMLHelper.add_element(building_details, "Enclosure")
      end
      rim_joists = XMLHelper.add_element(enclosure, "RimJoists")
    end
    rim_joist = XMLHelper.add_element(rim_joists, "RimJoist")
    sys_id = XMLHelper.add_element(rim_joist, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(rim_joist, "ExteriorAdjacentTo", exterior_adjacent_to) unless exterior_adjacent_to.nil?
    XMLHelper.add_element(rim_joist, "InteriorAdjacentTo", interior_adjacent_to) unless interior_adjacent_to.nil?
    XMLHelper.add_element(rim_joist, "Area", area) unless area.nil?

    return rim_joist
  end

  def self.get_rim_joist_values(rim_joist:)
    return nil if rim_joist.nil?

    return { :id => HPXML.get_id(rim_joist),
             :exterior_adjacent_to => XMLHelper.get_value(rim_joist, "ExteriorAdjacentTo"),
             :interior_adjacent_to => XMLHelper.get_value(rim_joist, "InteriorAdjacentTo"),
             :area => XMLHelper.get_value(rim_joist, "Area") }
  end

  def self.add_wall(hpxml:,
                    id:,
                    exterior_adjacent_to: nil,
                    interior_adjacent_to: nil,
                    adjacent_to: nil,
                    wall_type: nil,
                    area: nil,
                    orientation: nil,
                    azimuth: nil,
                    siding: nil,
                    solar_absorptance: nil,
                    emittance: nil)
    walls = hpxml.elements["Building/BuildingDetails/Enclosure/Walls"]
    if walls.nil?
      enclosure = hpxml.elements["Building/BuildingDetails/Enclosure"]
      if enclosure.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        enclosure = XMLHelper.add_element(building_details, "Enclosure")
      end
      walls = XMLHelper.add_element(enclosure, "Walls")
    end
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
    XMLHelper.add_element(wall, "Orientation", orientation) unless orientation.nil?
    XMLHelper.add_element(wall, "Azimuth", azimuth) unless azimuth.nil?
    XMLHelper.add_element(wall, "Siding", siding) unless siding.nil?
    XMLHelper.add_element(wall, "SolarAbsorptance", solar_absorptance) unless solar_absorptance.nil?
    XMLHelper.add_element(wall, "Emittance", emittance) unless emittance.nil?

    return wall
  end

  def self.get_wall_values(wall:)
    return nil if wall.nil?

    return { :id => HPXML.get_id(wall),
             :exterior_adjacent_to => XMLHelper.get_value(wall, "ExteriorAdjacentTo"),
             :interior_adjacent_to => XMLHelper.get_value(wall, "InteriorAdjacentTo"),
             :adjacent_to => XMLHelper.get_value(wall, "AdjacentTo"),
             :wall_type => XMLHelper.get_child_name(wall, "WallType"),
             :area => XMLHelper.get_value(wall, "Area"),
             :orientation => XMLHelper.get_value(wall, "Orientation"),
             :azimuth => XMLHelper.get_value(wall, "Azimuth"),
             :siding => XMLHelper.get_value(wall, "Siding"),
             :solar_absorptance => XMLHelper.get_value(wall, "SolarAbsorptance"),
             :emittance => XMLHelper.get_value(wall, "Emittance") }
  end

  def self.add_window(hpxml:,
                      id:,
                      area: nil,
                      azimuth: nil,
                      orientation: nil,
                      frame_type: nil,
                      glass_layers: nil,
                      glass_type: nil,
                      gas_fill: nil,
                      ufactor: nil,
                      shgc: nil,
                      overhangs_depth: nil,
                      overhangs_distance_to_top_of_window: nil,
                      overhangs_distance_to_bottom_of_window: nil,
                      wall_idref: nil)
    windows = hpxml.elements["Building/BuildingDetails/Enclosure/Windows"]
    if windows.nil?
      enclosure = hpxml.elements["Building/BuildingDetails/Enclosure"]
      if enclosure.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        enclosure = XMLHelper.add_element(building_details, "Enclosure")
      end
      windows = XMLHelper.add_element(enclosure, "Windows")
    end
    window = XMLHelper.add_element(windows, "Window")
    sys_id = XMLHelper.add_element(window, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(window, "Area", area) unless area.nil?
    XMLHelper.add_element(window, "Azimuth", azimuth) unless azimuth.nil?
    XMLHelper.add_element(window, "Orientation", orientation) unless orientation.nil?
    unless frame_type.nil?
      frame_type_e = XMLHelper.add_element(window, "FrameType")
      XMLHelper.add_element(frame_type_e, frame_type)
    end
    XMLHelper.add_element(window, "GlassLayers", glass_layers) unless glass_layers.nil?
    XMLHelper.add_element(window, "GlassType", glass_type) unless glass_type.nil?
    XMLHelper.add_element(window, "GasFill", gas_fill) unless gas_fill.nil?
    XMLHelper.add_element(window, "UFactor", ufactor) unless ufactor.nil?
    XMLHelper.add_element(window, "SHGC", shgc) unless shgc.nil?
    if not overhangs_depth.nil? or not overhangs_distance_to_top_of_window.nil? or not overhangs_distance_to_bottom_of_window.nil?
      overhangs = XMLHelper.add_element(window, "Overhangs")
      XMLHelper.add_element(overhangs, "Depth", overhangs_depth) unless overhangs_depth.nil?
      XMLHelper.add_element(overhangs, "DistanceToTopOfWindow", overhangs_distance_to_top_of_window) unless overhangs_distance_to_top_of_window.nil?
      XMLHelper.add_element(overhangs, "DistanceToBottomOfWindow", overhangs_distance_to_bottom_of_window) unless overhangs_distance_to_bottom_of_window.nil?
    end
    unless wall_idref.nil?
      attached_to_wall = XMLHelper.add_element(window, "AttachedToWall")
      XMLHelper.add_attribute(attached_to_wall, "idref", wall_idref)
    end

    return window
  end

  def self.get_window_values(window:)
    return nil if window.nil?

    frame_type = window.elements["FrameType"]
    unless frame_type.nil?
      frame_type = XMLHelper.get_child_name(window, "FrameType")
    end

    return { :id => HPXML.get_id(window),
             :area => XMLHelper.get_value(window, "Area"),
             :azimuth => XMLHelper.get_value(window, "Azimuth"),
             :orientation => XMLHelper.get_value(window, "Orientation"),
             :frame_type => frame_type,
             :glass_layers => XMLHelper.get_value(window, "GlassLayers"),
             :glass_type => XMLHelper.get_value(window, "GlassType"),
             :gas_fill => XMLHelper.get_value(window, "GasFill"),
             :ufactor => XMLHelper.get_value(window, "UFactor"),
             :shgc => XMLHelper.get_value(window, "SHGC"),
             :overhangs_depth => XMLHelper.get_value(window, "Overhangs/Depth"),
             :overhangs_distance_to_top_of_window => XMLHelper.get_value(window, "Overhangs/DistanceToTopOfWindow"),
             :overhangs_distance_to_bottom_of_window => XMLHelper.get_value(window, "Overhangs/DistanceToBottomOfWindow"),
             :wall_idref => HPXML.get_idref(window, "AttachedToWall") }
  end

  def self.add_skylight(hpxml:,
                        id:,
                        area: nil,
                        azimuth: nil,
                        orientation: nil,
                        frame_type: nil,
                        glass_layers: nil,
                        glass_type: nil,
                        gas_fill: nil,
                        ufactor: nil,
                        shgc: nil,
                        roof_idref: nil)
    skylights = hpxml.elements["Building/BuildingDetails/Enclosure/Skylights"]
    if skylights.nil?
      enclosure = hpxml.elements["Building/BuildingDetails/Enclosure"]
      if enclosure.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        enclosure = XMLHelper.add_element(building_details, "Enclosure")
      end
      skylights = XMLHelper.add_element(enclosure, "Skylights")
    end
    skylight = XMLHelper.add_element(skylights, "Skylight")
    sys_id = XMLHelper.add_element(skylight, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(skylight, "Area", area) unless area.nil?
    XMLHelper.add_element(skylight, "Azimuth", azimuth) unless azimuth.nil?
    XMLHelper.add_element(skylight, "Orientation", orientation) unless orientation.nil?
    unless frame_type.nil?
      frame_type_e = XMLHelper.add_element(skylight, "FrameType")
      XMLHelper.add_element(frame_type_e, frame_type)
    end
    XMLHelper.add_element(skylight, "GlassLayers", glass_layers) unless glass_layers.nil?
    XMLHelper.add_element(skylight, "GlassType", glass_type) unless glass_type.nil?
    XMLHelper.add_element(skylight, "GasFill", gas_fill) unless gas_fill.nil?
    XMLHelper.add_element(skylight, "UFactor", ufactor) unless ufactor.nil?
    XMLHelper.add_element(skylight, "SHGC", shgc) unless shgc.nil?
    unless roof_idref.nil?
      attached_to_roof = XMLHelper.add_element(skylight, "AttachedToRoof")
      XMLHelper.add_attribute(attached_to_roof, "idref", roof_idref)
    end

    return skylight
  end

  def self.get_skylight_values(skylight:)
    return nil if skylight.nil?

    frame_type = skylight.elements["FrameType"]
    unless frame_type.nil?
      frame_type = XMLHelper.get_child_name(skylight, "FrameType")
    end

    return { :id => HPXML.get_id(skylight),
             :area => XMLHelper.get_value(skylight, "Area"),
             :azimuth => XMLHelper.get_value(skylight, "Azimuth"),
             :orientation => XMLHelper.get_value(skylight, "Orientation"),
             :frame_type => frame_type,
             :glass_layers => XMLHelper.get_value(skylight, "GlassLayers"),
             :glass_type => XMLHelper.get_value(skylight, "GlassType"),
             :gas_fill => XMLHelper.get_value(skylight, "GasFill"),
             :ufactor => XMLHelper.get_value(skylight, "UFactor"),
             :shgc => XMLHelper.get_value(skylight, "SHGC"),
             :roof_idref => HPXML.get_idref(skylight, "AttachedToRoof") }
  end

  def self.add_door(hpxml:,
                    id:,
                    wall_idref: nil,
                    area: nil,
                    azimuth: nil,
                    r_value: nil)
    doors = hpxml.elements["Building/BuildingDetails/Enclosure/Doors"]
    if doors.nil?
      enclosure = hpxml.elements["Building/BuildingDetails/Enclosure"]
      if enclosure.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        enclosure = XMLHelper.add_element(building_details, "Enclosure")
      end
      doors = XMLHelper.add_element(enclosure, "Doors")
    end
    door = XMLHelper.add_element(doors, "Door")
    sys_id = XMLHelper.add_element(door, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless wall_idref.nil?
      attached_to_wall = XMLHelper.add_element(door, "AttachedToWall")
      XMLHelper.add_attribute(attached_to_wall, "idref", wall_idref)
    end
    XMLHelper.add_element(door, "Area", area) unless area.nil?
    XMLHelper.add_element(door, "Azimuth", azimuth) unless azimuth.nil?
    XMLHelper.add_element(door, "RValue", r_value) unless r_value.nil?

    return door
  end

  def self.get_door_values(door:)
    return nil if door.nil?

    return { :id => HPXML.get_id(door),
             :wall_idref => HPXML.get_idref(door, "AttachedToWall"),
             :area => XMLHelper.get_value(door, "Area"),
             :azimuth => XMLHelper.get_value(door, "Azimuth"),
             :r_value => XMLHelper.get_value(door, "RValue") }
  end

  def self.add_heating_system(hpxml:,
                              id:,
                              distribution_system_idref: nil,
                              year_installed: nil,
                              heating_system_type: nil,
                              heating_system_fuel: nil,
                              heating_capacity: nil,
                              annual_heating_efficiency_units: nil,
                              annual_heating_efficiency_value: nil,
                              fraction_heat_load_served: nil)
    hvac_plant = hpxml.elements["Building/BuildingDetails/Systems/HVAC/HVACPlant"]
    if hvac_plant.nil?
      hvac = hpxml.elements["Building/BuildingDetails/Systems/HVAC"]
      if hvac.nil?
        systems = hpxml.elements["Building/BuildingDetails/Systems"]
        if systems.nil?
          building_details = hpxml.elements["Building/BuildingDetails"]
          systems = XMLHelper.add_element(building_details, "Systems")
        end
        hvac = XMLHelper.add_element(systems, "HVAC")
      end
      hvac_plant = XMLHelper.add_element(hvac, "HVACPlant")
    end
    heating_system = XMLHelper.add_element(hvac_plant, "HeatingSystem")
    sys_id = XMLHelper.add_element(heating_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless distribution_system_idref.nil?
      distribution_system = XMLHelper.add_element(heating_system, "DistributionSystem")
      XMLHelper.add_attribute(distribution_system, "idref", distribution_system_idref)
    end
    XMLHelper.add_element(heating_system, "YearInstalled", year_installed) unless year_installed.nil?
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

  def self.get_heating_system_values(heating_system:)
    return nil if heating_system.nil?

    return { :id => HPXML.get_id(heating_system),
             :distribution_system_idref => HPXML.get_idref(heating_system, "DistributionSystem"),
             :year_installed => XMLHelper.get_value(heating_system, "YearInstalled"),
             :heating_system_type => XMLHelper.get_child_name(heating_system, "HeatingSystemType"),
             :heating_system_fuel => XMLHelper.get_value(heating_system, "HeatingSystemFuel"),
             :heating_capacity => XMLHelper.get_value(heating_system, "HeatingCapacity"),
             :annual_heating_efficiency_units => XMLHelper.get_value(heating_system, "AnnualHeatingEfficiency/Units"),
             :annual_heating_efficiency_value => XMLHelper.get_value(heating_system, "AnnualHeatingEfficiency/Value"),
             :fraction_heat_load_served => XMLHelper.get_value(heating_system, "FractionHeatLoadServed") }
  end

  def self.add_cooling_system(hpxml:,
                              id:,
                              distribution_system_idref: nil,
                              year_installed: nil,
                              cooling_system_type: nil,
                              cooling_system_fuel: nil,
                              cooling_capacity: nil,
                              fraction_cool_load_served: nil,
                              annual_cooling_efficiency_units: nil,
                              annual_cooling_efficiency_value: nil)
    hvac_plant = hpxml.elements["Building/BuildingDetails/Systems/HVAC/HVACPlant"]
    if hvac_plant.nil?
      hvac = hpxml.elements["Building/BuildingDetails/Systems/HVAC"]
      if hvac.nil?
        systems = hpxml.elements["Building/BuildingDetails/Systems"]
        if systems.nil?
          building_details = hpxml.elements["Building/BuildingDetails"]
          systems = XMLHelper.add_element(building_details, "Systems")
        end
        hvac = XMLHelper.add_element(systems, "HVAC")
      end
      hvac_plant = XMLHelper.add_element(hvac, "HVACPlant")
    end
    cooling_system = XMLHelper.add_element(hvac_plant, "CoolingSystem")
    sys_id = XMLHelper.add_element(cooling_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless distribution_system_idref.nil?
      distribution_system = XMLHelper.add_element(cooling_system, "DistributionSystem")
      XMLHelper.add_attribute(distribution_system, "idref", distribution_system_idref)
    end
    XMLHelper.add_element(cooling_system, "YearInstalled", year_installed) unless year_installed.nil?
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

  def self.get_cooling_system_values(cooling_system:)
    return nil if cooling_system.nil?

    return { :id => HPXML.get_id(cooling_system),
             :distribution_system_idref => HPXML.get_idref(cooling_system, "DistributionSystem"),
             :year_installed => XMLHelper.get_value(cooling_system, "YearInstalled"),
             :cooling_system_type => XMLHelper.get_value(cooling_system, "CoolingSystemType"),
             :cooling_system_fuel => XMLHelper.get_value(cooling_system, "CoolingSystemFuel"),
             :cooling_capacity => XMLHelper.get_value(cooling_system, "CoolingCapacity"),
             :fraction_cool_load_served => XMLHelper.get_value(cooling_system, "FractionCoolLoadServed"),
             :annual_cooling_efficiency_units => XMLHelper.get_value(cooling_system, "AnnualCoolingEfficiency/Units"),
             :annual_cooling_efficiency_value => XMLHelper.get_value(cooling_system, "AnnualCoolingEfficiency/Value") }
  end

  def self.add_heat_pump(hpxml:,
                         id:,
                         distribution_system_idref: nil,
                         year_installed: nil,
                         heat_pump_type: nil,
                         heat_pump_fuel: nil,
                         heating_capacity: nil,
                         cooling_capacity: nil,
                         fraction_heat_load_served: nil,
                         fraction_cool_load_served: nil,
                         annual_heating_efficiency_units: nil,
                         annual_heating_efficiency_value: nil,
                         annual_cooling_efficiency_units: nil,
                         annual_cooling_efficiency_value: nil)
    hvac_plant = hpxml.elements["Building/BuildingDetails/Systems/HVAC/HVACPlant"]
    if hvac_plant.nil?
      hvac = hpxml.elements["Building/BuildingDetails/Systems/HVAC"]
      if hvac.nil?
        systems = hpxml.elements["Building/BuildingDetails/Systems"]
        if systems.nil?
          building_details = hpxml.elements["Building/BuildingDetails"]
          systems = XMLHelper.add_element(building_details, "Systems")
        end
        hvac = XMLHelper.add_element(systems, "HVAC")
      end
      hvac_plant = XMLHelper.add_element(hvac, "HVACPlant")
    end
    heat_pump = XMLHelper.add_element(hvac_plant, "HeatPump")
    sys_id = XMLHelper.add_element(heat_pump, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless distribution_system_idref.nil?
      distribution_system = XMLHelper.add_element(heat_pump, "DistributionSystem")
      XMLHelper.add_attribute(distribution_system, "idref", distribution_system_idref)
    end
    XMLHelper.add_element(heat_pump, "YearInstalled", year_installed) unless year_installed.nil?
    XMLHelper.add_element(heat_pump, "HeatPumpType", heat_pump_type) unless heat_pump_type.nil?
    XMLHelper.add_element(heat_pump, "HeatPumpFuel", heat_pump_fuel) unless heat_pump_fuel.nil?
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

  def self.get_heat_pump_values(heat_pump:)
    return nil if heat_pump.nil?

    return { :id => HPXML.get_id(heat_pump),
             :distribution_system_idref => HPXML.get_idref(heat_pump, "DistributionSystem"),
             :year_installed => XMLHelper.get_value(heat_pump, "YearInstalle"),
             :heat_pump_type => XMLHelper.get_value(heat_pump, "HeatPumpType"),
             :heat_pump_fuel => XMLHelper.get_value(heat_pump, "HeatPumpFuel"),
             :heating_capacity => XMLHelper.get_value(heat_pump, "HeatingCapacity"),
             :cooling_capacity => XMLHelper.get_value(heat_pump, "CoolingCapacity"),
             :fraction_heat_load_served => XMLHelper.get_value(heat_pump, "FractionHeatLoadServed"),
             :fraction_cool_load_served => XMLHelper.get_value(heat_pump, "FractionCoolLoadServed"),
             :annual_heating_efficiency_units => XMLHelper.get_value(heat_pump, "AnnualHeatingEfficiency/Units"),
             :annual_heating_efficiency_value => XMLHelper.get_value(heat_pump, "AnnualHeatingEfficiency/Value"),
             :annual_cooling_efficiency_units => XMLHelper.get_value(heat_pump, "AnnualCoolingEfficiency/Units"),
             :annual_cooling_efficiency_value => XMLHelper.get_value(heat_pump, "AnnualCoolingEfficiency/Value") }
  end

  def self.add_hvac_control(hpxml:,
                            id:,
                            control_type: nil)
    hvac = hpxml.elements["Building/BuildingDetails/Systems/HVAC"]
    if hvac.nil?
      systems = hpxml.elements["Building/BuildingDetails/Systems"]
      if systems.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        systems = XMLHelper.add_element(building_details, "Systems")
      end
      hvac = XMLHelper.add_element(systems, "HVAC")
    end
    hvac_control = XMLHelper.add_element(hvac, "HVACControl")
    sys_id = XMLHelper.add_element(hvac_control, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(hvac_control, "ControlType", control_type) unless control_type.nil?

    return hvac_control
  end

  def self.get_hvac_control_values(hvac_control:)
    return nil if hvac_control.nil?

    return { :id => HPXML.get_id(hvac_control),
             :control_type => XMLHelper.get_value(hvac_control, "ControlType") }
  end

  def self.add_hvac_distribution(hpxml:,
                                 id:,
                                 distribution_system_type: nil,
                                 annual_heating_distribution_system_efficiency: nil,
                                 annual_cooling_distribution_system_efficiency: nil,
                                 duct_system_sealed: nil)
    hvac = hpxml.elements["Building/BuildingDetails/Systems/HVAC"]
    if hvac.nil?
      systems = hpxml.elements["Building/BuildingDetails/Systems"]
      if systems.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        systems = XMLHelper.add_element(building_details, "Systems")
      end
      hvac = XMLHelper.add_element(systems, "HVAC")
    end
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
    unless duct_system_sealed.nil?
      hvac_distribution_improvement = XMLHelper.add_element(hvac_distribution, "HVACDistributionImprovement")
      XMLHelper.add_element(hvac_distribution_improvement, "DuctSystemSealed", duct_system_sealed)
    end

    return hvac_distribution
  end

  def self.get_hvac_distribution_values(hvac_distribution:)
    return nil if hvac_distribution.nil?

    distribution_system_type = XMLHelper.get_child_name(hvac_distribution, "DistributionSystemType")
    if distribution_system_type == "Other"
      distribution_system_type = XMLHelper.get_value(hvac_distribution.elements["DistributionSystemType"], "Other")
    end

    return { :id => HPXML.get_id(hvac_distribution),
             :distribution_system_type => distribution_system_type,
             :annual_heating_distribution_system_efficiency => XMLHelper.get_value(hvac_distribution, "AnnualHeatingDistributionSystemEfficiency"),
             :annual_cooling_distribution_system_efficiency => XMLHelper.get_value(hvac_distribution, "AnnualCoolingDistributionSystemEfficiency"),
             :duct_system_sealed => XMLHelper.get_value(hvac_distribution, "HVACDistributionImprovement/DuctSystemSealed") }
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

  def self.get_duct_leakage_measurement_values(duct_leakage_measurement:)
    return nil if duct_leakage_measurement.nil?

    return { :duct_type => XMLHelper.get_value(duct_leakage_measurement, "DuctType"),
             :duct_leakage_units => XMLHelper.get_value(duct_leakage_measurement, "DuctLeakage/Units"),
             :duct_leakage_value => XMLHelper.get_value(duct_leakage_measurement, "DuctLeakage/Value"),
             :duct_leakage_total_or_to_outside => XMLHelper.get_value(duct_leakage_measurement, "DuctLeakage/TotalOrToOutside") }
  end

  def self.add_ducts(air_distribution:,
                     duct_type: nil,
                     duct_insulation_r_value: nil,
                     duct_location: nil,
                     duct_fraction_area: nil,
                     duct_surface_area: nil,
                     hescore_ducts_insulated: nil)
    ducts = XMLHelper.add_element(air_distribution, "Ducts")
    XMLHelper.add_element(ducts, "DuctType", duct_type) unless duct_type.nil?
    XMLHelper.add_element(ducts, "DuctInsulationRValue", duct_insulation_r_value) unless duct_insulation_r_value.nil?
    XMLHelper.add_element(ducts, "DuctLocation", duct_location) unless duct_location.nil?
    XMLHelper.add_element(ducts, "FractionDuctArea", duct_fraction_area) unless duct_fraction_area.nil?
    XMLHelper.add_element(ducts, "DuctSurfaceArea", duct_surface_area) unless duct_surface_area.nil?
    HPXML.add_extension(parent: ducts,
                        extensions: { "hescore_ducts_insulated": hescore_ducts_insulated })

    return ducts
  end

  def self.get_ducts_values(ducts:)
    return nil if ducts.nil?

    return { :duct_type => XMLHelper.get_value(ducts, "DuctType"),
             :duct_insulation_r_value => XMLHelper.get_value(ducts, "DuctInsulationRValue"),
             :duct_location => XMLHelper.get_value(ducts, "DuctLocation"),
             :duct_fraction_area => XMLHelper.get_value(ducts, "FractionDuctArea"),
             :duct_surface_area => XMLHelper.get_value(ducts, "DuctSurfaceArea"),
             :hescore_ducts_insulated => XMLHelper.get_value(ducts, "extension/hescore_ducts_insulated") }
  end

  def self.add_ventilation_fan(hpxml:,
                               id:,
                               fan_type: nil,
                               rated_flow_rate: nil,
                               hours_in_operation: nil,
                               used_for_whole_building_ventilation: nil,
                               total_recovery_efficiency: nil,
                               sensible_recovery_efficiency: nil,
                               fan_power: nil,
                               distribution_system_idref: nil)
    ventilation_fans = hpxml.elements["Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans"]
    if ventilation_fans.nil?
      mechanical_ventilation = hpxml.elements["Building/BuildingDetails/Systems/MechanicalVentilation"]
      if mechanical_ventilation.nil?
        systems = hpxml.elements["Building/BuildingDetails/Systems"]
        if systems.nil?
          building_details = hpxml.elements["Buidling/BuildingDetails"]
          systems = XMLHelper.add_element(building_details, "Systems")
        end
        mechanical_ventilation = XMLHelper.add_element(systems, "MechanicalVentilation")
      end
      ventilation_fans = XMLHelper.add_element(mechanical_ventilation, "VentilationFans")
    end
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
    unless distribution_system_idref.nil?
      attached_to_hvac_distribution_system = XMLHelper.add_element(ventilation_fan, "AttachedToHVACDistributionSystem")
      XMLHelper.add_attribute(attached_to_hvac_distribution_system, "idref", distribution_system_idref)
    end

    return ventilation_fan
  end

  def self.get_ventilation_fan_values(ventilation_fan:)
    return nil if ventilation_fan.nil?

    return { :id => HPXML.get_id(ventilation_fan),
             :fan_type => XMLHelper.get_value(ventilation_fan, "FanType"),
             :rated_flow_rate => XMLHelper.get_value(ventilation_fan, "RatedFlowRate"),
             :hours_in_operation => XMLHelper.get_value(ventilation_fan, "HoursInOperation"),
             :used_for_whole_building_ventilation => XMLHelper.get_value(ventilation_fan, "UsedForWholeBuildingVentilation"),
             :total_recovery_efficiency => XMLHelper.get_value(ventilation_fan, "TotalRecoveryEfficiency"),
             :sensible_recovery_efficiency => XMLHelper.get_value(ventilation_fan, "SensibleRecoveryEfficiency"),
             :fan_power => XMLHelper.get_value(ventilation_fan, "FanPower"),
             :distribution_system_idref => HPXML.get_idref(ventilation_fan, "AttachedToHVACDistributionSystem") }
  end

  def self.add_water_heating_system(hpxml:,
                                    id:,
                                    year_installed: nil,
                                    fuel_type: nil,
                                    water_heater_type: nil,
                                    location: nil,
                                    tank_volume: nil,
                                    fraction_dhw_load_served: nil,
                                    heating_capacity: nil,
                                    energy_factor: nil,
                                    uniform_energy_factor: nil,
                                    recovery_efficiency: nil)
    water_heating = hpxml.elements["Building/BuildingDetails/Systems/WaterHeating"]
    if water_heating.nil?
      systems = hpxml.elements["Building/BuildingDetails/Systems"]
      if systems.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        systems = XMLHelper.add_element(building_details, "Systems")
      end
      water_heating = XMLHelper.add_element(systems, "WaterHeating")
    end
    water_heating_system = XMLHelper.add_element(water_heating, "WaterHeatingSystem")
    sys_id = XMLHelper.add_element(water_heating_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(water_heating_system, "YearInstalled", year_installed) unless year_installed.nil?
    XMLHelper.add_element(water_heating_system, "FuelType", fuel_type) unless fuel_type.nil?
    XMLHelper.add_element(water_heating_system, "WaterHeaterType", water_heater_type) unless water_heater_type.nil?
    XMLHelper.add_element(water_heating_system, "Location", location) unless location.nil?
    XMLHelper.add_element(water_heating_system, "TankVolume", tank_volume) unless tank_volume.nil?
    XMLHelper.add_element(water_heating_system, "FractionDHWLoadServed", fraction_dhw_load_served) unless fraction_dhw_load_served.nil?
    XMLHelper.add_element(water_heating_system, "HeatingCapacity", heating_capacity) unless heating_capacity.nil?
    XMLHelper.add_element(water_heating_system, "EnergyFactor", energy_factor) unless energy_factor.nil?
    XMLHelper.add_element(water_heating_system, "UniformEnergyFactor", uniform_energy_factor) unless uniform_energy_factor.nil?
    XMLHelper.add_element(water_heating_system, "RecoveryEfficiency", recovery_efficiency) unless recovery_efficiency.nil?

    return water_heating_system
  end

  def self.get_water_heating_system_values(water_heating_system:)
    return nil if water_heating_system.nil?

    return { :id => HPXML.get_id(water_heating_system),
             :year_installed => XMLHelper.get_value(water_heating_system, "YearInstalled"),
             :fuel_type => XMLHelper.get_value(water_heating_system, "FuelType"),
             :water_heater_type => XMLHelper.get_value(water_heating_system, "WaterHeaterType"),
             :location => XMLHelper.get_value(water_heating_system, "Location"),
             :tank_volume => XMLHelper.get_value(water_heating_system, "TankVolume"),
             :fraction_dhw_load_served => XMLHelper.get_value(water_heating_system, "FractionDHWLoadServed"),
             :heating_capacity => XMLHelper.get_value(water_heating_system, "HeatingCapacity"),
             :energy_factor => XMLHelper.get_value(water_heating_system, "EnergyFactor"),
             :uniform_energy_factor => XMLHelper.get_value(water_heating_system, "UniformEnergyFactor"),
             :recovery_efficiency => XMLHelper.get_value(water_heating_system, "RecoveryEfficiency") }
  end

  def self.add_hot_water_distribution(hpxml:,
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
    water_heating = hpxml.elements["Building/BuildingDetails/Systems/WaterHeating"]
    if water_heating.nil?
      systems = hpxml.elements["Building/BuildingDetails/Systems"]
      if systems.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        systems = XMLHelper.add_element(building_details, "Systems")
      end
      water_heating = XMLHelper.add_element(systems, "WaterHeating")
    end
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

  def self.get_hot_water_distribution_values(hot_water_distribution:)
    return nil if hot_water_distribution.nil?

    return { :id => HPXML.get_id(hot_water_distribution),
             :system_type => XMLHelper.get_child_name(hot_water_distribution, "SystemType"),
             :pipe_r_value => XMLHelper.get_value(hot_water_distribution, "PipeInsulation/PipeRValue"),
             :standard_piping_length => XMLHelper.get_value(hot_water_distribution, "SystemType/Standard/PipingLength"),
             :recirculation_control_type => XMLHelper.get_value(hot_water_distribution, "SystemType/Recirculation/ControlType"),
             :recirculation_piping_loop_length => XMLHelper.get_value(hot_water_distribution, "SystemType/Recirculation/RecirculationPipingLoopLength"),
             :recirculation_branch_piping_loop_length => XMLHelper.get_value(hot_water_distribution, "SystemType/Recirculation/BranchPipingLoopLength"),
             :recirculation_pump_power => XMLHelper.get_value(hot_water_distribution, "SystemType/Recirculation/PumpPower"),
             :drain_water_heat_recovery_facilities_connected => XMLHelper.get_value(hot_water_distribution, "DrainWaterHeatRecovery/FacilitiesConnected"),
             :drain_water_heat_recovery_equal_flow => XMLHelper.get_value(hot_water_distribution, "DrainWaterHeatRecovery/EqualFlow"),
             :drain_water_heat_recovery_efficiency => XMLHelper.get_value(hot_water_distribution, "DrainWaterHeatRecovery/Efficiency") }
  end

  def self.add_water_fixture(hpxml:,
                             id:,
                             water_fixture_type: nil,
                             low_flow: nil)
    water_heating = hpxml.elements["Building/BuildingDetails/Systems/WaterHeating"]
    if water_heating.nil?
      systems = hpxml.elements["Building/BuildingDetails/Systems"]
      if systems.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        systems = XMLHelper.add_element(building_details, "Systems")
      end
      water_heating = XMLHelper.add_element(systems, "WaterHeating")
    end
    water_fixture = XMLHelper.add_element(water_heating, "WaterFixture")
    sys_id = XMLHelper.add_element(water_fixture, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(water_fixture, "WaterFixtureType", water_fixture_type) unless water_fixture_type.nil?
    XMLHelper.add_element(water_fixture, "LowFlow", low_flow) unless low_flow.nil?

    return water_fixture
  end

  def self.get_water_fixture_values(water_fixture:)
    return nil if water_fixture.nil?

    return { :id => HPXML.get_id(water_fixture),
             :water_fixture_type => XMLHelper.get_value(water_fixture, "WaterFixtureType"),
             :low_flow => XMLHelper.get_value(water_fixture, "LowFlow") }
  end

  def self.add_pv_system(hpxml:,
                         id:,
                         module_type: nil,
                         array_type: nil,
                         array_orientation: nil,
                         array_azimuth: nil,
                         array_tilt: nil,
                         max_power_output: nil,
                         inverter_efficiency: nil,
                         system_losses_fraction: nil,
                         hescore_num_panels: nil)
    photovoltaics = hpxml.elements["Building/BuildingDetails/Systems/Photovoltaics"]
    if photovoltaics.nil?
      systems = hpxml.elements["Building/BuildingDetails/Systems"]
      if systems.nil?
        building_details = hpxml.elements["Building/BuildingDetails"]
        systems = XMLHelper.add_element(building_details, "Systems")
      end
      photovoltaics = XMLHelper.add_element(systems, "Photovoltaics")
    end
    pv_system = XMLHelper.add_element(photovoltaics, "PVSystem")
    sys_id = XMLHelper.add_element(pv_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(pv_system, "ModuleType", module_type) unless module_type.nil?
    XMLHelper.add_element(pv_system, "ArrayType", array_type) unless array_type.nil?
    XMLHelper.add_element(pv_system, "ArrayOrientation", array_orientation) unless array_orientation.nil?
    XMLHelper.add_element(pv_system, "ArrayAzimuth", array_azimuth) unless array_azimuth.nil?
    XMLHelper.add_element(pv_system, "ArrayTilt", array_tilt) unless array_tilt.nil?
    XMLHelper.add_element(pv_system, "MaxPowerOutput", max_power_output) unless max_power_output.nil?
    XMLHelper.add_element(pv_system, "InverterEfficiency", inverter_efficiency) unless inverter_efficiency.nil?
    XMLHelper.add_element(pv_system, "SystemLossesFraction", system_losses_fraction) unless system_losses_fraction.nil?
    HPXML.add_extension(parent: pv_system,
                        extensions: { "hescore_num_panels": hescore_num_panels })

    return pv_system
  end

  def self.get_pv_system_values(pv_system:)
    return nil if pv_system.nil?

    return { :id => HPXML.get_id(pv_system),
             :module_type => XMLHelper.get_value(pv_system, "ModuleType"),
             :array_type => XMLHelper.get_value(pv_system, "ArrayType"),
             :array_orientation => XMLHelper.get_value(pv_system, "ArrayOrientation"),
             :array_azimuth => XMLHelper.get_value(pv_system, "ArrayAzimuth"),
             :array_tilt => XMLHelper.get_value(pv_system, "ArrayTilt"),
             :max_power_output => XMLHelper.get_value(pv_system, "MaxPowerOutput"),
             :inverter_efficiency => XMLHelper.get_value(pv_system, "InverterEfficiency"),
             :system_losses_fraction => XMLHelper.get_value(pv_system, "SystemLossesFraction"),
             :hescore_num_panels => XMLHelper.get_value(pv_system, "extension/hescore_num_panels") }
  end

  def self.add_clothes_washer(hpxml:,
                              id:,
                              location: nil,
                              modified_energy_factor: nil,
                              integrated_modified_energy_factor: nil,
                              rated_annual_kwh: nil,
                              label_electric_rate: nil,
                              label_gas_rate: nil,
                              label_annual_gas_cost: nil,
                              capacity: nil)
    appliances = hpxml.elements["Building/BuildingDetails/Appliances"]
    if appliances.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      appliances = XMLHelper.add_element(building_details, "Appliances")
    end
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

  def self.get_clothes_washer_values(clothes_washer:)
    return nil if clothes_washer.nil?

    return { :id => HPXML.get_id(clothes_washer),
             :location => XMLHelper.get_value(clothes_washer, "Location"),
             :modified_energy_factor => XMLHelper.get_value(clothes_washer, "ModifiedEnergyFactor"),
             :integrated_modified_energy_factor => XMLHelper.get_value(clothes_washer, "IntegratedModifiedEnergyFactor"),
             :rated_annual_kwh => XMLHelper.get_value(clothes_washer, "RatedAnnualkWh"),
             :label_electric_rate => XMLHelper.get_value(clothes_washer, "LabelElectricRate"),
             :label_gas_rate => XMLHelper.get_value(clothes_washer, "LabelGasRate"),
             :label_annual_gas_cost => XMLHelper.get_value(clothes_washer, "LabelAnnualGasCost"),
             :capacity => XMLHelper.get_value(clothes_washer, "Capacity") }
  end

  def self.add_clothes_dryer(hpxml:,
                             id:,
                             location: nil,
                             fuel_type: nil,
                             energy_factor: nil,
                             combined_energy_factor: nil,
                             control_type: nil)
    appliances = hpxml.elements["Building/BuildingDetails/Appliances"]
    if appliances.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      appliances = XMLHelper.add_element(building_details, "Appliances")
    end
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

  def self.get_clothes_dryer_values(clothes_dryer:)
    return nil if clothes_dryer.nil?

    return { :id => HPXML.get_id(clothes_dryer),
             :location => XMLHelper.get_value(clothes_dryer, "Location"),
             :fuel_type => XMLHelper.get_value(clothes_dryer, "FuelType"),
             :energy_factor => XMLHelper.get_value(clothes_dryer, "EnergyFactor"),
             :combined_energy_factor => XMLHelper.get_value(clothes_dryer, "CombinedEnergyFactor"),
             :control_type => XMLHelper.get_value(clothes_dryer, "ControlType") }
  end

  def self.add_dishwasher(hpxml:,
                          id:,
                          energy_factor: nil,
                          rated_annual_kwh: nil,
                          place_setting_capacity: nil)
    appliances = hpxml.elements["Building/BuildingDetails/Appliances"]
    if appliances.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      appliances = XMLHelper.add_element(building_details, "Appliances")
    end
    dishwasher = XMLHelper.add_element(appliances, "Dishwasher")
    sys_id = XMLHelper.add_element(dishwasher, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(dishwasher, "EnergyFactor", energy_factor) unless energy_factor.nil?
    XMLHelper.add_element(dishwasher, "RatedAnnualkWh", rated_annual_kwh) unless rated_annual_kwh.nil?
    XMLHelper.add_element(dishwasher, "PlaceSettingCapacity", place_setting_capacity) unless place_setting_capacity.nil?

    return dishwasher
  end

  def self.get_dishwasher_values(dishwasher:)
    return nil if dishwasher.nil?

    return { :id => HPXML.get_id(dishwasher),
             :energy_factor => XMLHelper.get_value(dishwasher, "EnergyFactor"),
             :rated_annual_kwh => XMLHelper.get_value(dishwasher, "RatedAnnualkWh"),
             :place_setting_capacity => XMLHelper.get_value(dishwasher, "PlaceSettingCapacity") }
  end

  def self.add_refrigerator(hpxml:,
                            id:,
                            location: nil,
                            rated_annual_kwh: nil)
    appliances = hpxml.elements["Building/BuildingDetails/Appliances"]
    if appliances.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      appliances = XMLHelper.add_element(building_details, "Appliances")
    end
    refrigerator = XMLHelper.add_element(appliances, "Refrigerator")
    sys_id = XMLHelper.add_element(refrigerator, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(refrigerator, "Location", location) unless location.nil?
    XMLHelper.add_element(refrigerator, "RatedAnnualkWh", rated_annual_kwh) unless rated_annual_kwh.nil?

    return refrigerator
  end

  def self.get_refrigerator_values(refrigerator:)
    return nil if refrigerator.nil?

    return { :id => HPXML.get_id(refrigerator),
             :location => XMLHelper.get_value(refrigerator, "Location"),
             :rated_annual_kwh => XMLHelper.get_value(refrigerator, "RatedAnnualkWh") }
  end

  def self.add_cooking_range(hpxml:,
                             id:,
                             fuel_type: nil,
                             is_induction: nil)
    appliances = hpxml.elements["Building/BuildingDetails/Appliances"]
    if appliances.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      appliances = XMLHelper.add_element(building_details, "Appliances")
    end
    cooking_range = XMLHelper.add_element(appliances, "CookingRange")
    sys_id = XMLHelper.add_element(cooking_range, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(cooking_range, "FuelType", fuel_type)
    XMLHelper.add_element(cooking_range, "IsInduction", is_induction) unless is_induction.nil?

    return cooking_range
  end

  def self.get_cooking_range_values(cooking_range:)
    return nil if cooking_range.nil?

    return { :id => HPXML.get_id(cooking_range),
             :fuel_type => XMLHelper.get_value(cooking_range, "FuelType"),
             :is_induction => XMLHelper.get_value(cooking_range, "IsInduction") }
  end

  def self.add_oven(hpxml:,
                    id:,
                    is_convection: nil)
    appliances = hpxml.elements["Building/BuildingDetails/Appliances"]
    if appliances.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      appliances = XMLHelper.add_element(building_details, "Appliances")
    end
    oven = XMLHelper.add_element(appliances, "Oven")
    sys_id = XMLHelper.add_element(oven, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(oven, "IsConvection", is_convection) unless is_convection.nil?

    return oven
  end

  def self.get_oven_values(oven:)
    return nil if oven.nil?

    return { :id => HPXML.get_id(oven),
             :is_convection => XMLHelper.get_value(oven, "IsConvection") }
  end

  def self.add_lighting_fractions(hpxml:,
                                  fraction_qualifying_tier_i_fixtures_interior: nil,
                                  fraction_qualifying_tier_i_fixtures_exterior: nil,
                                  fraction_qualifying_tier_i_fixtures_garage: nil,
                                  fraction_qualifying_tier_ii_fixtures_interior: nil,
                                  fraction_qualifying_tier_ii_fixtures_exterior: nil,
                                  fraction_qualifying_tier_ii_fixtures_garage: nil)
    lighting = hpxml.elements["Building/BuildingDetails/Lighting"]
    if lighting.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      lighting = XMLHelper.add_element(building_details, "Lighting")
    end
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

  def self.get_lighting_fractions_values(lighting_fractions:)
    return nil if lighting_fractions.nil?

    return { :fraction_qualifying_tier_i_fixtures_interior => XMLHelper.get_value(lighting_fractions, "extension/FractionQualifyingTierIFixturesInterior"),
             :fraction_qualifying_tier_i_fixtures_exterior => XMLHelper.get_value(lighting_fractions, "extension/FractionQualifyingTierIFixturesExterior"),
             :fraction_qualifying_tier_i_fixtures_garage => XMLHelper.get_value(lighting_fractions, "extension/FractionQualifyingTierIFixturesGarage"),
             :fraction_qualifying_tier_ii_fixtures_interior => XMLHelper.get_value(lighting_fractions, "extension/FractionQualifyingTierIIFixturesInterior"),
             :fraction_qualifying_tier_ii_fixtures_exterior => XMLHelper.get_value(lighting_fractions, "extension/FractionQualifyingTierIIFixturesExterior"),
             :fraction_qualifying_tier_ii_fixtures_garage => XMLHelper.get_value(lighting_fractions, "extension/FractionQualifyingTierIIFixturesGarage") }
  end

  def self.add_ceiling_fan(hpxml:,
                           id:,
                           fan_speed: nil,
                           efficiency: nil,
                           quantity: nil)
    lighting = hpxml.elements["Building/BuildingDetails/Lighting"]
    if lighting.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      lighting = XMLHelper.add_element(building_details, "Lighting")
    end
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

  def self.get_ceiling_fan_values(ceiling_fan:)
    return nil if ceiling_fan.nil?

    return { :id => HPXML.get_id(ceiling_fan),
             :fan_speed => XMLHelper.get_value(ceiling_fan, "Airflow/FanSpeed"),
             :efficiency => XMLHelper.get_value(ceiling_fan, "Airflow/Efficiency"),
             :quantity => XMLHelper.get_value(ceiling_fan, "Quantity") }
  end

  def self.add_plug_load(hpxml:,
                         id:,
                         plug_load_type: nil)
    misc_loads = hpxml.elements["Building/BuildingDetails/MiscLoads"]
    if misc_loads.nil?
      building_details = hpxml.elements["Building/BuildingDetails"]
      misc_loads = XMLHelper.add_element(building_details, "MiscLoads")
    end
    plug_load = XMLHelper.add_element(misc_loads, "PlugLoad")
    sys_id = XMLHelper.add_element(plug_load, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(plug_load, "PlugLoadType", plug_load_type) unless plug_load_type.nil?

    return plug_load
  end

  def self.get_plug_load_values(plug_load:)
    return nil if plug_load.nil?

    return { :id => HPXML.get_id(plug_load),
             :plug_load_type => XMLHelper.get_value(plug_load, "PlugLoadType") }
  end

  def self.get_id(parent)
    return parent.elements["SystemIdentifier"].attributes["id"]
  end

  def self.get_idref(parent, element_name)
    element = parent.elements[element_name]
    return if element.nil?

    return element.attributes["idref"]
  end
end
