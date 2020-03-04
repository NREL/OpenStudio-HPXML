require_relative 'xmlhelper'

class HPXML
  @data = nil

  def initialize(hpxml_path: nil, hpxml_data: nil)
    if not hpxml_path.nil?
      @data = _convert_file_to_data(hpxml_path)
    elsif not hpxml_data.nil?
      @data = hpxml_data
    else
      @data = _convert_file_to_data(nil)
    end
  end

  def method_missing(method_name, *args, &block)
    # TODO: Allow "add_foo" methods
    if @data.keys.include? method_name
      return @data[method_name.to_sym]
    else
      super
    end
  end

  def collapse_enclosure()
    # TODO: Always do this automatically in initialize?
    _collapse_enclosure()
  end

  def to_object()
    return _convert_data_to_object()
  end

  private

  def _convert_file_to_data(hpxml_path)
    data = {}

    hpxml = nil
    if not hpxml_path.nil?
      hpxml = XMLHelper.parse_file(hpxml_path).elements['/HPXML']
    end

    data[:header] = _get_object_header_values(hpxml: hpxml)
    data[:site] = _get_object_site_values(hpxml: hpxml)
    data[:neighbor_buildings] = _get_object_neighbor_buildings_values(hpxml: hpxml)
    data[:building_occupants] = _get_object_building_occupancy_values(hpxml: hpxml)
    data[:building_construction] = _get_object_building_construction_values(hpxml: hpxml)
    data[:climate_and_risk_zones] = _get_object_climate_and_risk_zones_values(hpxml: hpxml)
    data[:air_infiltration_measurements] = _get_object_air_infiltration_measurements_values(hpxml: hpxml)
    data[:attics] = _get_object_attics_values(hpxml: hpxml)
    data[:foundations] = _get_object_foundations_values(hpxml: hpxml)
    data[:roofs] = _get_object_roofs_values(hpxml: hpxml)
    data[:rim_joists] = _get_object_rim_joists_values(hpxml: hpxml)
    data[:walls] = _get_object_walls_values(hpxml: hpxml)
    data[:foundation_walls] = _get_object_foundation_walls_values(hpxml: hpxml)
    data[:frame_floors] = _get_object_frame_floors_values(hpxml: hpxml)
    data[:slabs] = _get_object_slabs_values(hpxml: hpxml)
    data[:windows] = _get_object_windows_values(hpxml: hpxml)
    data[:skylights] = _get_object_skylights_values(hpxml: hpxml)
    data[:doors] = _get_object_doors_values(hpxml: hpxml)
    data[:heating_systems] = _get_object_heating_systems_values(hpxml: hpxml)
    data[:cooling_systems] = _get_object_cooling_systems_values(hpxml: hpxml)
    data[:heat_pumps] = _get_object_heat_pumps_values(hpxml: hpxml)
    data[:hvac_control] = _get_object_hvac_control_values(hpxml: hpxml)
    data[:hvac_distributions] = _get_object_hvac_distributions_values(hpxml: hpxml)
    data[:ventilation_fans] = _get_object_ventilation_fans_values(hpxml: hpxml)
    data[:water_heating_systems] = _get_object_water_heating_systems_values(hpxml: hpxml)
    data[:hot_water_distribution] = _get_object_hot_water_distribution_values(hpxml: hpxml)
    data[:water_fixtures] = _get_object_water_fixtures_values(hpxml: hpxml)
    data[:solar_thermal_system] = _get_object_solar_thermal_system_values(hpxml: hpxml)
    data[:pv_systems] = _get_object_pv_systems_values(hpxml: hpxml)
    data[:clothes_washer] = _get_object_clothes_washer_values(hpxml: hpxml)
    data[:clothes_dryer] = _get_object_clothes_dryer_values(hpxml: hpxml)
    data[:dishwasher] = _get_object_dishwasher_values(hpxml: hpxml)
    data[:refrigerator] = _get_object_refrigerator_values(hpxml: hpxml)
    data[:cooking_range] = _get_object_cooking_range_values(hpxml: hpxml)
    data[:oven] = _get_object_oven_values(hpxml: hpxml)
    data[:lighting] = _get_object_lighting_values(hpxml: hpxml)
    data[:ceiling_fans] = _get_object_ceiling_fans_values(hpxml: hpxml)
    data[:plug_loads] = _get_object_plug_loads_values(hpxml: hpxml)
    data[:misc_load_schedule] = _get_object_misc_loads_schedule_values(hpxml: hpxml)

    return data
  end

  def _convert_data_to_object()
    @object = _create_object(**@data[:header])
    _add_object_site(**@data[:site]) unless @data[:site].nil?
    @data[:neighbor_buildings].each do |neighbor_building_values|
      _add_object_neighbor_building(**neighbor_building_values)
    end
    _add_object_building_occupancy(**@data[:building_occupants]) unless @data[:building_occupants].empty?
    _add_object_building_construction(**@data[:building_construction])
    _add_object_climate_and_risk_zones(**@data[:climate_and_risk_zones])
    @data[:air_infiltration_measurements].each do |air_infiltration_measurement_values|
      _add_object_air_infiltration_measurement(**air_infiltration_measurement_values)
    end
    @data[:attics].each do |attic_values|
      _add_object_attic(**attic_values)
    end
    @data[:foundations].each do |foundation_values|
      _add_object_foundation(**foundation_values)
    end
    @data[:roofs].each do |roof_values|
      _add_object_roof(**roof_values)
    end
    @data[:rim_joists].each do |rim_joist_values|
      _add_object_rim_joist(**rim_joist_values)
    end
    @data[:walls].each do |wall_values|
      _add_object_wall(**wall_values)
    end
    @data[:foundation_walls].each do |foundation_wall_values|
      _add_object_foundation_wall(**foundation_wall_values)
    end
    @data[:frame_floors].each do |frame_floor_values|
      _add_object_frame_floor(**frame_floor_values)
    end
    @data[:slabs].each do |slab_values|
      _add_object_slab(**slab_values)
    end
    @data[:windows].each do |window_values|
      _add_object_window(**window_values)
    end
    @data[:skylights].each do |skylight_values|
      _add_object_skylight(**skylight_values)
    end
    @data[:doors].each do |door_values|
      _add_object_door(**door_values)
    end
    @data[:heating_systems].each do |heating_system_values|
      _add_object_heating_system(**heating_system_values)
    end
    @data[:cooling_systems].each do |cooling_system_values|
      _add_object_cooling_system(**cooling_system_values)
    end
    @data[:heat_pumps].each do |heat_pump_values|
      _add_object_heat_pump(**heat_pump_values)
    end
    _add_object_hvac_control(**@data[:hvac_control]) unless @data[:hvac_control].empty?
    @data[:hvac_distributions].each_with_index do |hvac_distribution_values, i|
      hvac_distribution = _add_object_hvac_distribution(**hvac_distribution_values)
    end
    @data[:ventilation_fans].each do |ventilation_fan_values|
      _add_object_ventilation_fan(**ventilation_fan_values)
    end
    @data[:water_heating_systems].each do |water_heating_system_values|
      _add_object_water_heating_system(**water_heating_system_values)
    end
    _add_object_hot_water_distribution(**@data[:hot_water_distribution]) unless @data[:hot_water_distribution].empty?
    @data[:water_fixtures].each do |water_fixture_values|
      _add_object_water_fixture(**water_fixture_values)
    end
    _add_object_solar_thermal_system(**@data[:solar_thermal_system]) unless @data[:solar_thermal_system].empty?
    @data[:pv_systems].each do |pv_system_values|
      _add_object_pv_system(**pv_system_values)
    end
    _add_object_clothes_washer(**@data[:clothes_washer]) unless @data[:clothes_washer].empty?
    _add_object_clothes_dryer(**@data[:clothes_dryer]) unless @data[:clothes_dryer].empty?
    _add_object_dishwasher(**@data[:dishwasher]) unless @data[:dishwasher].empty?
    _add_object_refrigerator(**@data[:refrigerator]) unless @data[:refrigerator].empty?
    _add_object_cooking_range(**@data[:cooking_range]) unless @data[:cooking_range].empty?
    _add_object_oven(**@data[:oven]) unless @data[:oven].empty?
    _add_object_lighting(**@data[:lighting]) unless @data[:lighting].empty?
    @data[:ceiling_fans].each do |ceiling_fan_values|
      _add_object_ceiling_fan(**ceiling_fan_values)
    end
    @data[:plug_loads].each do |plug_load_values|
      _add_object_plug_load(**plug_load_values)
    end
    _add_object_misc_loads_schedule(**@data[:misc_load_schedule]) unless @data[:misc_load_schedule].empty?
    return @object
  end

  def _create_object(xml_type:,
                     xml_generated_by:,
                     transaction:,
                     software_program_used: nil,
                     software_program_version: nil,
                     eri_calculation_version: nil,
                     eri_design: nil,
                     timestep: nil,
                     building_id:,
                     event_type:,
                     created_date_and_time: nil)
    doc = XMLHelper.create_doc(version = "1.0", encoding = "UTF-8")
    hpxml = XMLHelper.add_element(doc, "HPXML")
    XMLHelper.add_attribute(hpxml, "xmlns", "http://hpxmlonline.com/2019/10")
    XMLHelper.add_attribute(hpxml, "xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance")
    XMLHelper.add_attribute(hpxml, "xsi:schemaLocation", "http://hpxmlonline.com/2019/10")
    XMLHelper.add_attribute(hpxml, "schemaVersion", "3.0")

    header = XMLHelper.add_element(hpxml, "XMLTransactionHeaderInformation")
    XMLHelper.add_element(header, "XMLType", xml_type)
    XMLHelper.add_element(header, "XMLGeneratedBy", xml_generated_by)
    if not created_date_and_time.nil?
      XMLHelper.add_element(header, "CreatedDateAndTime", created_date_and_time)
    else
      XMLHelper.add_element(header, "CreatedDateAndTime", Time.now.strftime("%Y-%m-%dT%H:%M:%S%:z"))
    end
    XMLHelper.add_element(header, "Transaction", transaction)

    software_info = XMLHelper.add_element(hpxml, "SoftwareInfo")
    XMLHelper.add_element(software_info, "SoftwareProgramUsed", software_program_used) unless software_program_used.nil?
    XMLHelper.add_element(software_info, "SoftwareProgramVersion", software_program_version) unless software_program_version.nil?
    _add_object_extension(parent: software_info,
                          extensions: { "ERICalculation/Version" => eri_calculation_version,
                                        "ERICalculation/Design" => eri_design,
                                        "SimulationControl/Timestep" => _to_integer_or_nil(timestep) })

    building = XMLHelper.add_element(hpxml, "Building")
    building_building_id = XMLHelper.add_element(building, "BuildingID")
    XMLHelper.add_attribute(building_building_id, "id", building_id)
    project_status = XMLHelper.add_element(building, "ProjectStatus")
    XMLHelper.add_element(project_status, "EventType", event_type)

    return doc
  end

  def _get_object_header_values(hpxml:)
    return {} if hpxml.nil?

    vals = {}
    vals[:schema_version] = hpxml.attributes["schemaVersion"]
    vals[:xml_type] = XMLHelper.get_value(hpxml, "XMLTransactionHeaderInformation/XMLType")
    vals[:xml_generated_by] = XMLHelper.get_value(hpxml, "XMLTransactionHeaderInformation/XMLGeneratedBy")
    vals[:created_date_and_time] = XMLHelper.get_value(hpxml, "XMLTransactionHeaderInformation/CreatedDateAndTime")
    vals[:transaction] = XMLHelper.get_value(hpxml, "XMLTransactionHeaderInformation/Transaction")
    vals[:software_program_used] = XMLHelper.get_value(hpxml, "SoftwareInfo/SoftwareProgramUsed")
    vals[:software_program_version] = XMLHelper.get_value(hpxml, "SoftwareInfo/SoftwareProgramVersion")
    vals[:eri_calculation_version] = XMLHelper.get_value(hpxml, "SoftwareInfo/extension/ERICalculation/Version")
    vals[:eri_design] = XMLHelper.get_value(hpxml, "SoftwareInfo/extension/ERICalculation/Design")
    vals[:timestep] = _to_integer_or_nil(XMLHelper.get_value(hpxml, "SoftwareInfo/extension/SimulationControl/Timestep"))
    vals[:building_id] = _get_object_id(hpxml, "Building/BuildingID")
    vals[:event_type] = XMLHelper.get_value(hpxml, "Building/ProjectStatus/EventType")
    return vals
  end

  def _add_object_site(fuels: [],
                       shelter_coefficient: nil)
    site = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "BuildingSummary", "Site"])
    unless fuels.empty?
      fuel_types_available = XMLHelper.add_element(site, "FuelTypesAvailable")
      fuels.each do |fuel|
        XMLHelper.add_element(fuel_types_available, "Fuel", fuel)
      end
    end
    _add_object_extension(parent: site,
                          extensions: { "ShelterCoefficient" => _to_float_or_nil(shelter_coefficient) })

    return site
  end

  def _get_object_site_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    site = hpxml.elements["Building/BuildingDetails/BuildingSummary/Site"]
    return vals if site.nil?

    vals[:surroundings] = XMLHelper.get_value(site, "Surroundings")
    vals[:orientation_of_front_of_home] = XMLHelper.get_value(site, "OrientationOfFrontOfHome")
    vals[:fuels] = XMLHelper.get_values(site, "FuelTypesAvailable/Fuel")
    vals[:shelter_coefficient] = _to_float_or_nil(XMLHelper.get_value(site, "extension/ShelterCoefficient"))
    return vals
  end

  def _add_object_neighbor_building(azimuth:,
                                    distance:,
                                    height: nil)
    neighbors = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "BuildingSummary", "Site", "extension", "Neighbors"])
    neighbor_building = XMLHelper.add_element(neighbors, "NeighborBuilding")
    XMLHelper.add_element(neighbor_building, "Azimuth", Integer(azimuth))
    XMLHelper.add_element(neighbor_building, "Distance", Float(distance))
    XMLHelper.add_element(neighbor_building, "Height", Float(height)) unless height.nil?

    return neighbor_building
  end

  def _get_object_neighbor_buildings_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding") do |neighbor_building|
      child_vals = {}
      child_vals[:azimuth] = _to_integer_or_nil(XMLHelper.get_value(neighbor_building, "Azimuth"))
      child_vals[:distance] = _to_float_or_nil(XMLHelper.get_value(neighbor_building, "Distance"))
      child_vals[:height] = _to_float_or_nil(XMLHelper.get_value(neighbor_building, "Height"))
      vals << child_vals
    end
    return vals
  end

  def _add_object_building_occupancy(number_of_residents: nil)
    building_occupancy = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "BuildingSummary", "BuildingOccupancy"])
    XMLHelper.add_element(building_occupancy, "NumberofResidents", Float(number_of_residents)) unless number_of_residents.nil?

    return building_occupancy
  end

  def _get_object_building_occupancy_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    building_occupancy = hpxml.elements["Building/BuildingDetails/BuildingSummary/BuildingOccupancy"]
    return vals if building_occupancy.nil?

    vals[:number_of_residents] = _to_float_or_nil(XMLHelper.get_value(building_occupancy, "NumberofResidents"))
    return vals
  end

  def _add_object_building_construction(number_of_conditioned_floors:,
                                        number_of_conditioned_floors_above_grade:,
                                        number_of_bedrooms:,
                                        number_of_bathrooms: nil,
                                        conditioned_floor_area:,
                                        conditioned_building_volume:,
                                        fraction_of_operable_window_area: nil,
                                        use_only_ideal_air_system: nil)
    building_construction = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "BuildingSummary", "BuildingConstruction"])
    XMLHelper.add_element(building_construction, "NumberofConditionedFloors", Integer(number_of_conditioned_floors))
    XMLHelper.add_element(building_construction, "NumberofConditionedFloorsAboveGrade", Integer(number_of_conditioned_floors_above_grade))
    XMLHelper.add_element(building_construction, "NumberofBedrooms", Integer(number_of_bedrooms))
    XMLHelper.add_element(building_construction, "NumberofBathrooms", Integer(number_of_bathrooms)) unless number_of_bathrooms.nil?
    XMLHelper.add_element(building_construction, "ConditionedFloorArea", Float(conditioned_floor_area))
    XMLHelper.add_element(building_construction, "ConditionedBuildingVolume", Float(conditioned_building_volume))
    _add_object_extension(parent: building_construction,
                          extensions: { "FractionofOperableWindowArea" => _to_float_or_nil(fraction_of_operable_window_area),
                                        "UseOnlyIdealAirSystem" => _to_bool_or_nil(use_only_ideal_air_system) })

    return building_construction
  end

  def _get_object_building_construction_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    building_construction = hpxml.elements["Building/BuildingDetails/BuildingSummary/BuildingConstruction"]
    return vals if building_construction.nil?

    vals[:year_built] = _to_integer_or_nil(XMLHelper.get_value(building_construction, "YearBuilt"))
    vals[:number_of_conditioned_floors] = _to_integer_or_nil(XMLHelper.get_value(building_construction, "NumberofConditionedFloors"))
    vals[:number_of_conditioned_floors_above_grade] = _to_integer_or_nil(XMLHelper.get_value(building_construction, "NumberofConditionedFloorsAboveGrade"))
    vals[:average_ceiling_height] = _to_float_or_nil(XMLHelper.get_value(building_construction, "AverageCeilingHeight"))
    vals[:number_of_bedrooms] = _to_integer_or_nil(XMLHelper.get_value(building_construction, "NumberofBedrooms"))
    vals[:number_of_bathrooms] = _to_integer_or_nil(XMLHelper.get_value(building_construction, "NumberofBathrooms"))
    vals[:conditioned_floor_area] = _to_float_or_nil(XMLHelper.get_value(building_construction, "ConditionedFloorArea"))
    vals[:conditioned_building_volume] = _to_float_or_nil(XMLHelper.get_value(building_construction, "ConditionedBuildingVolume"))
    vals[:use_only_ideal_air_system] = _to_bool_or_nil(XMLHelper.get_value(building_construction, "extension/UseOnlyIdealAirSystem"))
    vals[:residential_facility_type] = XMLHelper.get_value(building_construction, "ResidentialFacilityType")
    vals[:fraction_of_operable_window_area] = _to_float_or_nil(XMLHelper.get_value(building_construction, "extension/FractionofOperableWindowArea"))
    return vals
  end

  def _add_object_climate_and_risk_zones(iecc2006: nil,
                                         iecc2012: nil,
                                         weather_station_id:,
                                         weather_station_name:,
                                         weather_station_wmo: nil,
                                         weather_station_epw_filename: nil)
    climate_and_risk_zones = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "ClimateandRiskZones"])

    climate_zones = { 2006 => iecc2006,
                      2012 => iecc2012 }
    climate_zones.each do |year, zone|
      next if zone.nil?

      climate_zone_iecc = XMLHelper.add_element(climate_and_risk_zones, "ClimateZoneIECC")
      XMLHelper.add_element(climate_zone_iecc, "Year", Integer(year)) unless year.nil?
      XMLHelper.add_element(climate_zone_iecc, "ClimateZone", zone) unless zone.nil?
    end

    weather_station = XMLHelper.add_element(climate_and_risk_zones, "WeatherStation")
    sys_id = XMLHelper.add_element(weather_station, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", weather_station_id)
    XMLHelper.add_element(weather_station, "Name", weather_station_name)
    XMLHelper.add_element(weather_station, "WMO", weather_station_wmo) unless weather_station_wmo.nil?
    _add_object_extension(parent: weather_station,
                          extensions: { "EPWFileName" => weather_station_epw_filename })

    return climate_and_risk_zones
  end

  def _get_object_climate_and_risk_zones_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    climate_and_risk_zones = hpxml.elements["Building/BuildingDetails/ClimateandRiskZones"]
    return vals if climate_and_risk_zones.nil?

    vals[:iecc2006] = XMLHelper.get_value(climate_and_risk_zones, "ClimateZoneIECC[Year=2006]/ClimateZone")
    vals[:iecc2012] = XMLHelper.get_value(climate_and_risk_zones, "ClimateZoneIECC[Year=2012]/ClimateZone")
    weather_station = climate_and_risk_zones.elements["WeatherStation"]
    if not weather_station.nil?
      vals[:weather_station_id] = _get_object_id(weather_station)
      vals[:weather_station_name] = XMLHelper.get_value(weather_station, "Name")
      vals[:weather_station_wmo] = XMLHelper.get_value(weather_station, "WMO")
      vals[:weather_station_epw_filename] = XMLHelper.get_value(weather_station, "extension/EPWFileName")
    end
    return vals
  end

  def _collapse_enclosure()
    # Collapses like surfaces into a single surface with, e.g., aggregate surface area.
    # This can significantly speed up performance for HPXML files with lots of individual
    # surfaces (e.g., windows).

    surf_types = [:roofs,
                  :walls,
                  :rim_joists,
                  :foundation_walls,
                  :frame_floors,
                  :slabs,
                  :windows,
                  :skylights,
                  :doors]

    keys_to_ignore = [:id,
                      :insulation_id,
                      :perimeter_insulation_id,
                      :under_slab_insulation_id,
                      :area,
                      :exposed_perimeter]

    # Look for pairs of surfaces that can be collapsed
    area_adjustments = {}
    exposed_perimeter_adjustments = {}
    surf_types.each do |surf_type|
      area_adjustments[surf_type] = {}
      exposed_perimeter_adjustments[surf_type] = {}
      for i in 0..@data[surf_type].size - 1
        surf_values = @data[surf_type][i]
        next if surf_values.nil?

        area_adjustments[surf_type][i] = 0
        exposed_perimeter_adjustments[surf_type][i] = 0

        for j in (@data[surf_type].size - 1).downto(i + 1)
          surf_values2 = @data[surf_type][j]
          next if surf_values2.nil?
          next unless surf_values.keys.sort == surf_values2.keys.sort

          match = true
          surf_values.keys.each do |key|
            next if keys_to_ignore.include? key
            next if surf_type == :foundation_walls and key == :azimuth # Azimuth of foundation walls is irrelevant
            next if surf_values[key] == surf_values2[key]

            match = false
          end
          next unless match

          # Update Area/ExposedPerimeter
          area_adjustments[surf_type][i] += surf_values2[:area]
          if not surf_values[:exposed_perimeter].nil?
            exposed_perimeter_adjustments[surf_type][i] += surf_values2[:exposed_perimeter]
          end

          # Update subsurface idrefs as appropriate
          if [:walls, :foundation_walls].include? surf_type
            [:windows, :doors].each do |subsurf_type|
              @data[subsurf_type].each_with_index do |subsurf_values, idx|
                next unless subsurf_values[:wall_idref] == surf_values2[:id]

                @data[subsurf_type][idx][:wall_idref] = surf_values[:id]
              end
            end
          elsif [:roofs].include? surf_type
            [:skylights].each do |subsurf_type|
              @data[subsurf_type].each_with_index do |subsurf_values, idx|
                next unless subsurf_values[:roof_idref] == surf_values2[:id]

                @data[subsurf_type][idx][:roof_idref] = surf_values[:id]
              end
            end
          end

          # Remove old surface
          @data[surf_type].delete_at(j)
        end
      end
    end

    area_adjustments.keys.each do |surf_type|
      area_adjustments[surf_type].each do |idx, area_adjustment|
        next unless area_adjustment > 0

        @data[surf_type][idx][:area] += area_adjustment
      end
    end
    exposed_perimeter_adjustments.keys.each do |surf_type|
      exposed_perimeter_adjustments[surf_type].each do |idx, exposed_perimeter_adjustment|
        next unless exposed_perimeter_adjustment > 0

        @data[surf_type][idx][:exposed_perimeter] += exposed_perimeter_adjustment
      end
    end
  end

  def _add_object_air_infiltration_measurement(id:,
                                               house_pressure: nil,
                                               unit_of_measure: nil,
                                               air_leakage: nil,
                                               effective_leakage_area: nil,
                                               constant_ach_natural: nil,
                                               infiltration_volume: nil)
    air_infiltration = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Enclosure", "AirInfiltration"])
    air_infiltration_measurement = XMLHelper.add_element(air_infiltration, "AirInfiltrationMeasurement")
    sys_id = XMLHelper.add_element(air_infiltration_measurement, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(air_infiltration_measurement, "HousePressure", Float(house_pressure)) unless house_pressure.nil?
    if not unit_of_measure.nil? and not air_leakage.nil?
      building_air_leakage = XMLHelper.add_element(air_infiltration_measurement, "BuildingAirLeakage")
      XMLHelper.add_element(building_air_leakage, "UnitofMeasure", unit_of_measure)
      XMLHelper.add_element(building_air_leakage, "AirLeakage", Float(air_leakage))
    end
    XMLHelper.add_element(air_infiltration_measurement, "EffectiveLeakageArea", Float(effective_leakage_area)) unless effective_leakage_area.nil?
    XMLHelper.add_element(air_infiltration_measurement, "InfiltrationVolume", Float(infiltration_volume)) unless infiltration_volume.nil?
    _add_object_extension(parent: air_infiltration_measurement,
                          extensions: { "ConstantACHnatural" => _to_float_or_nil(constant_ach_natural) })

    return air_infiltration_measurement
  end

  def _get_object_air_infiltration_measurements_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement") do |air_infiltration_measurement|
      child_vals = {}
      child_vals[:id] = _get_object_id(air_infiltration_measurement)
      child_vals[:house_pressure] = _to_float_or_nil(XMLHelper.get_value(air_infiltration_measurement, "HousePressure"))
      child_vals[:unit_of_measure] = XMLHelper.get_value(air_infiltration_measurement, "BuildingAirLeakage/UnitofMeasure")
      child_vals[:air_leakage] = _to_float_or_nil(XMLHelper.get_value(air_infiltration_measurement, "BuildingAirLeakage/AirLeakage"))
      child_vals[:effective_leakage_area] = _to_float_or_nil(XMLHelper.get_value(air_infiltration_measurement, "EffectiveLeakageArea"))
      child_vals[:infiltration_volume] = _to_float_or_nil(XMLHelper.get_value(air_infiltration_measurement, "InfiltrationVolume"))
      child_vals[:constant_ach_natural] = _to_float_or_nil(XMLHelper.get_value(air_infiltration_measurement, "extension/ConstantACHnatural"))
      child_vals[:leakiness_description] = XMLHelper.get_value(air_infiltration_measurement, "LeakinessDescription")
      vals << child_vals
    end
    return vals
  end

  def _add_object_attic(id:,
                        attic_type:,
                        vented_attic_sla: nil,
                        vented_attic_constant_ach: nil)
    attics = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Enclosure", "Attics"])
    attic = XMLHelper.add_element(attics, "Attic")
    sys_id = XMLHelper.add_element(attic, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless attic_type.nil?
      attic_type_e = XMLHelper.add_element(attic, "AtticType")
      if attic_type == "UnventedAttic"
        attic_type_attic = XMLHelper.add_element(attic_type_e, "Attic")
        XMLHelper.add_element(attic_type_attic, "Vented", false)
      elsif attic_type == "VentedAttic"
        attic_type_attic = XMLHelper.add_element(attic_type_e, "Attic")
        XMLHelper.add_element(attic_type_attic, "Vented", true)
        if not vented_attic_sla.nil?
          ventilation_rate = XMLHelper.add_element(attic, "VentilationRate")
          XMLHelper.add_element(ventilation_rate, "UnitofMeasure", "SLA")
          XMLHelper.add_element(ventilation_rate, "Value", Float(vented_attic_sla))
        elsif not vented_attic_constant_ach.nil?
          XMLHelper.add_element(attic, "extension/ConstantACHnatural", Float(vented_attic_constant_ach))
        end
      elsif attic_type == "FlatRoof" or attic_type == "CathedralCeiling"
        XMLHelper.add_element(attic_type_e, attic_type)
      else
        fail "Unhandled attic type '#{attic_type}'."
      end
    end

    return attic
  end

  def _get_object_attics_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Enclosure/Attics/Attic") do |attic|
      child_vals = {}
      child_vals[:id] = _get_object_id(attic)
      if XMLHelper.has_element(attic, "AtticType/Attic[Vented='false']")
        child_vals[:attic_type] = "UnventedAttic"
      elsif XMLHelper.has_element(attic, "AtticType/Attic[Vented='true']")
        child_vals[:attic_type] = "VentedAttic"
      elsif XMLHelper.has_element(attic, "AtticType/Attic[Conditioned='true']")
        child_vals[:attic_type] = "ConditionedAttic"
      elsif XMLHelper.has_element(attic, "AtticType/FlatRoof")
        child_vals[:attic_type] = "FlatRoof"
      elsif XMLHelper.has_element(attic, "AtticType/CathedralCeiling")
        child_vals[:attic_type] = "CathedralCeiling"
      end
      child_vals[:vented_attic_sla] = _to_float_or_nil(XMLHelper.get_value(attic, "[AtticType/Attic[Vented='true']]VentilationRate[UnitofMeasure='SLA']/Value"))
      child_vals[:vented_attic_constant_ach] = _to_float_or_nil(XMLHelper.get_value(attic, "[AtticType/Attic[Vented='true']]extension/ConstantACHnatural"))
      vals << child_vals
    end
    return vals
  end

  def _add_object_foundation(id:,
                             foundation_type:,
                             vented_crawlspace_sla: nil,
                             unconditioned_basement_thermal_boundary: nil)
    foundations = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Enclosure", "Foundations"])
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
        XMLHelper.add_element(foundation, "ThermalBoundary", unconditioned_basement_thermal_boundary)
      elsif foundation_type == "VentedCrawlspace"
        crawlspace = XMLHelper.add_element(foundation_type_e, "Crawlspace")
        XMLHelper.add_element(crawlspace, "Vented", true)
        if not vented_crawlspace_sla.nil?
          ventilation_rate = XMLHelper.add_element(foundation, "VentilationRate")
          XMLHelper.add_element(ventilation_rate, "UnitofMeasure", "SLA")
          XMLHelper.add_element(ventilation_rate, "Value", Float(vented_crawlspace_sla))
        end
      elsif foundation_type == "UnventedCrawlspace"
        crawlspace = XMLHelper.add_element(foundation_type_e, "Crawlspace")
        XMLHelper.add_element(crawlspace, "Vented", false)
      else
        fail "Unhandled foundation type '#{foundation_type}'."
      end
    end

    return foundation
  end

  def _get_object_foundations_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Enclosure/Foundations/Foundation") do |foundation|
      child_vals = {}
      child_vals[:id] = _get_object_id(foundation)
      if XMLHelper.has_element(foundation, "FoundationType/SlabOnGrade")
        child_vals[:foundation_type] = "SlabOnGrade"
      elsif XMLHelper.has_element(foundation, "FoundationType/Basement[Conditioned='false']")
        child_vals[:foundation_type] = "UnconditionedBasement"
      elsif XMLHelper.has_element(foundation, "FoundationType/Basement[Conditioned='true']")
        child_vals[:foundation_type] = "ConditionedBasement"
      elsif XMLHelper.has_element(foundation, "FoundationType/Crawlspace[Vented='false']")
        child_vals[:foundation_type] = "UnventedCrawlspace"
      elsif XMLHelper.has_element(foundation, "FoundationType/Crawlspace[Vented='true']")
        child_vals[:foundation_type] = "VentedCrawlspace"
      elsif XMLHelper.has_element(foundation, "FoundationType/Ambient")
        child_vals[:foundation_type] = "Ambient"
      end
      child_vals[:vented_crawlspace_sla] = _to_float_or_nil(XMLHelper.get_value(foundation, "[FoundationType/Crawlspace[Vented='true']]VentilationRate[UnitofMeasure='SLA']/Value"))
      child_vals[:unconditioned_basement_thermal_boundary] = XMLHelper.get_value(foundation, "[FoundationType/Basement[Conditioned='false']]ThermalBoundary")
      vals << child_vals
    end
    return vals
  end

  def _add_object_roof(id:,
                       interior_adjacent_to:,
                       area:,
                       azimuth: nil,
                       solar_absorptance:,
                       emittance:,
                       pitch:,
                       radiant_barrier:,
                       insulation_id: nil,
                       insulation_assembly_r_value:)
    roofs = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Enclosure", "Roofs"])
    roof = XMLHelper.add_element(roofs, "Roof")
    sys_id = XMLHelper.add_element(roof, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(roof, "InteriorAdjacentTo", interior_adjacent_to)
    XMLHelper.add_element(roof, "Area", Float(area))
    XMLHelper.add_element(roof, "Azimuth", Integer(azimuth)) unless azimuth.nil?
    XMLHelper.add_element(roof, "SolarAbsorptance", Float(solar_absorptance))
    XMLHelper.add_element(roof, "Emittance", Float(emittance))
    XMLHelper.add_element(roof, "Pitch", Float(pitch))
    XMLHelper.add_element(roof, "RadiantBarrier", Boolean(radiant_barrier))
    insulation = XMLHelper.add_element(roof, "Insulation")
    sys_id = XMLHelper.add_element(insulation, "SystemIdentifier")
    unless insulation_id.nil?
      XMLHelper.add_attribute(sys_id, "id", insulation_id)
    else
      XMLHelper.add_attribute(sys_id, "id", id + "Insulation")
    end
    XMLHelper.add_element(insulation, "AssemblyEffectiveRValue", Float(insulation_assembly_r_value))

    return roof
  end

  def _get_object_roofs_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Enclosure/Roofs/Roof") do |roof|
      child_vals = {}
      child_vals[:id] = _get_object_id(roof)
      child_vals[:exterior_adjacent_to] = "outside"
      child_vals[:interior_adjacent_to] = XMLHelper.get_value(roof, "InteriorAdjacentTo")
      child_vals[:area] = _to_float_or_nil(XMLHelper.get_value(roof, "Area"))
      child_vals[:azimuth] = _to_integer_or_nil(XMLHelper.get_value(roof, "Azimuth"))
      child_vals[:roof_type] = XMLHelper.get_value(roof, "RoofType")
      child_vals[:roof_color] = XMLHelper.get_value(roof, "RoofColor")
      child_vals[:solar_absorptance] = _to_float_or_nil(XMLHelper.get_value(roof, "SolarAbsorptance"))
      child_vals[:emittance] = _to_float_or_nil(XMLHelper.get_value(roof, "Emittance"))
      child_vals[:pitch] = _to_float_or_nil(XMLHelper.get_value(roof, "Pitch"))
      child_vals[:radiant_barrier] = _to_bool_or_nil(XMLHelper.get_value(roof, "RadiantBarrier"))
      insulation = roof.elements["Insulation"]
      if not insulation.nil?
        child_vals[:insulation_id] = _get_object_id(insulation)
        child_vals[:insulation_assembly_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "AssemblyEffectiveRValue"))
        child_vals[:insulation_cavity_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='cavity']/NominalRValue"))
        child_vals[:insulation_continuous_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='continuous']/NominalRValue"))
      end
      vals << child_vals
    end
    return vals
  end

  def _add_object_rim_joist(id:,
                            exterior_adjacent_to:,
                            interior_adjacent_to:,
                            area:,
                            azimuth: nil,
                            solar_absorptance:,
                            emittance:,
                            insulation_id: nil,
                            insulation_assembly_r_value:)
    rim_joists = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Enclosure", "RimJoists"])
    rim_joist = XMLHelper.add_element(rim_joists, "RimJoist")
    sys_id = XMLHelper.add_element(rim_joist, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(rim_joist, "ExteriorAdjacentTo", exterior_adjacent_to)
    XMLHelper.add_element(rim_joist, "InteriorAdjacentTo", interior_adjacent_to)
    XMLHelper.add_element(rim_joist, "Area", Float(area))
    XMLHelper.add_element(rim_joist, "Azimuth", Integer(azimuth)) unless azimuth.nil?
    XMLHelper.add_element(rim_joist, "SolarAbsorptance", Float(solar_absorptance))
    XMLHelper.add_element(rim_joist, "Emittance", Float(emittance))
    insulation = XMLHelper.add_element(rim_joist, "Insulation")
    sys_id = XMLHelper.add_element(insulation, "SystemIdentifier")
    unless insulation_id.nil?
      XMLHelper.add_attribute(sys_id, "id", insulation_id)
    else
      XMLHelper.add_attribute(sys_id, "id", id + "Insulation")
    end
    XMLHelper.add_element(insulation, "AssemblyEffectiveRValue", Float(insulation_assembly_r_value))

    return rim_joist
  end

  def _get_object_rim_joists_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Enclosure/RimJoists/RimJoist") do |rim_joist|
      child_vals = {}
      child_vals[:id] = _get_object_id(rim_joist)
      child_vals[:exterior_adjacent_to] = XMLHelper.get_value(rim_joist, "ExteriorAdjacentTo")
      child_vals[:interior_adjacent_to] = XMLHelper.get_value(rim_joist, "InteriorAdjacentTo")
      child_vals[:area] = _to_float_or_nil(XMLHelper.get_value(rim_joist, "Area"))
      child_vals[:azimuth] = _to_integer_or_nil(XMLHelper.get_value(rim_joist, "Azimuth"))
      child_vals[:solar_absorptance] = _to_float_or_nil(XMLHelper.get_value(rim_joist, "SolarAbsorptance"))
      child_vals[:emittance] = _to_float_or_nil(XMLHelper.get_value(rim_joist, "Emittance"))
      insulation = rim_joist.elements["Insulation"]
      if not insulation.nil?
        child_vals[:insulation_id] = _get_object_id(insulation)
        child_vals[:insulation_assembly_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "AssemblyEffectiveRValue"))
      end
      vals << child_vals
    end
    return vals
  end

  def _add_object_wall(id:,
                       exterior_adjacent_to:,
                       interior_adjacent_to:,
                       wall_type:,
                       area:,
                       azimuth: nil,
                       solar_absorptance:,
                       emittance:,
                       insulation_id: nil,
                       insulation_assembly_r_value:)
    walls = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Enclosure", "Walls"])
    wall = XMLHelper.add_element(walls, "Wall")
    sys_id = XMLHelper.add_element(wall, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(wall, "ExteriorAdjacentTo", exterior_adjacent_to)
    XMLHelper.add_element(wall, "InteriorAdjacentTo", interior_adjacent_to)
    wall_type_e = XMLHelper.add_element(wall, "WallType")
    XMLHelper.add_element(wall_type_e, wall_type)
    XMLHelper.add_element(wall, "Area", Float(area))
    XMLHelper.add_element(wall, "Azimuth", Integer(azimuth)) unless azimuth.nil?
    XMLHelper.add_element(wall, "SolarAbsorptance", Float(solar_absorptance))
    XMLHelper.add_element(wall, "Emittance", Float(emittance))
    insulation = XMLHelper.add_element(wall, "Insulation")
    sys_id = XMLHelper.add_element(insulation, "SystemIdentifier")
    unless insulation_id.nil?
      XMLHelper.add_attribute(sys_id, "id", insulation_id)
    else
      XMLHelper.add_attribute(sys_id, "id", id + "Insulation")
    end
    XMLHelper.add_element(insulation, "AssemblyEffectiveRValue", Float(insulation_assembly_r_value))

    return wall
  end

  def _get_object_walls_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Enclosure/Walls/Wall") do |wall|
      child_vals = {}
      child_vals[:id] = _get_object_id(wall)
      child_vals[:exterior_adjacent_to] = XMLHelper.get_value(wall, "ExteriorAdjacentTo")
      child_vals[:interior_adjacent_to] = XMLHelper.get_value(wall, "InteriorAdjacentTo")
      child_vals[:wall_type] = XMLHelper.get_child_name(wall, "WallType")
      child_vals[:optimum_value_engineering] = _to_bool_or_nil(XMLHelper.get_value(wall, "WallType/WoodStud/OptimumValueEngineering"))
      child_vals[:area] = _to_float_or_nil(XMLHelper.get_value(wall, "Area"))
      child_vals[:orientation] = XMLHelper.get_value(wall, "Orientation")
      child_vals[:azimuth] = _to_integer_or_nil(XMLHelper.get_value(wall, "Azimuth"))
      child_vals[:siding] = XMLHelper.get_value(wall, "Siding")
      child_vals[:solar_absorptance] = _to_float_or_nil(XMLHelper.get_value(wall, "SolarAbsorptance"))
      child_vals[:emittance] = _to_float_or_nil(XMLHelper.get_value(wall, "Emittance"))
      insulation = wall.elements["Insulation"]
      if not insulation.nil?
        child_vals[:insulation_id] = _get_object_id(insulation)
        child_vals[:insulation_assembly_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "AssemblyEffectiveRValue"))
        child_vals[:insulation_cavity_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='cavity']/NominalRValue"))
        child_vals[:insulation_continuous_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='continuous']/NominalRValue"))
      end
      vals << child_vals
    end
    return vals
  end

  def _add_object_foundation_wall(id:,
                                  exterior_adjacent_to:,
                                  interior_adjacent_to:,
                                  height:,
                                  area:,
                                  azimuth: nil,
                                  thickness:,
                                  depth_below_grade:,
                                  insulation_id: nil,
                                  insulation_interior_r_value: nil,
                                  insulation_interior_distance_to_top: nil,
                                  insulation_interior_distance_to_bottom: nil,
                                  insulation_exterior_r_value: nil,
                                  insulation_exterior_distance_to_top: nil,
                                  insulation_exterior_distance_to_bottom: nil,
                                  insulation_assembly_r_value: nil)
    foundation_walls = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Enclosure", "FoundationWalls"])
    foundation_wall = XMLHelper.add_element(foundation_walls, "FoundationWall")
    sys_id = XMLHelper.add_element(foundation_wall, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(foundation_wall, "ExteriorAdjacentTo", exterior_adjacent_to)
    XMLHelper.add_element(foundation_wall, "InteriorAdjacentTo", interior_adjacent_to)
    XMLHelper.add_element(foundation_wall, "Height", Float(height))
    XMLHelper.add_element(foundation_wall, "Area", Float(area))
    XMLHelper.add_element(foundation_wall, "Azimuth", Integer(azimuth)) unless azimuth.nil?
    XMLHelper.add_element(foundation_wall, "Thickness", Float(thickness))
    XMLHelper.add_element(foundation_wall, "DepthBelowGrade", Float(depth_below_grade))
    insulation = XMLHelper.add_element(foundation_wall, "Insulation")
    sys_id = XMLHelper.add_element(insulation, "SystemIdentifier")
    unless insulation_id.nil?
      XMLHelper.add_attribute(sys_id, "id", insulation_id)
    else
      XMLHelper.add_attribute(sys_id, "id", id + "Insulation")
    end
    XMLHelper.add_element(insulation, "AssemblyEffectiveRValue", Float(insulation_assembly_r_value)) unless insulation_assembly_r_value.nil?
    unless insulation_exterior_r_value.nil?
      layer = XMLHelper.add_element(insulation, "Layer")
      XMLHelper.add_element(layer, "InstallationType", "continuous - exterior")
      XMLHelper.add_element(layer, "NominalRValue", Float(insulation_exterior_r_value))
      _add_object_extension(parent: layer,
                            extensions: { "DistanceToTopOfInsulation" => _to_float_or_nil(insulation_exterior_distance_to_top),
                                          "DistanceToBottomOfInsulation" => _to_float_or_nil(insulation_exterior_distance_to_bottom) })
    end
    unless insulation_interior_r_value.nil?
      layer = XMLHelper.add_element(insulation, "Layer")
      XMLHelper.add_element(layer, "InstallationType", "continuous - interior")
      XMLHelper.add_element(layer, "NominalRValue", Float(insulation_interior_r_value))
      _add_object_extension(parent: layer,
                            extensions: { "DistanceToTopOfInsulation" => _to_float_or_nil(insulation_interior_distance_to_top),
                                          "DistanceToBottomOfInsulation" => _to_float_or_nil(insulation_interior_distance_to_bottom) })
    end

    return foundation_wall
  end

  def _get_object_foundation_walls_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall") do |foundation_wall|
      child_vals = {}
      child_vals[:id] = _get_object_id(foundation_wall)
      child_vals[:exterior_adjacent_to] = XMLHelper.get_value(foundation_wall, "ExteriorAdjacentTo")
      child_vals[:interior_adjacent_to] = XMLHelper.get_value(foundation_wall, "InteriorAdjacentTo")
      child_vals[:height] = _to_float_or_nil(XMLHelper.get_value(foundation_wall, "Height"))
      child_vals[:area] = _to_float_or_nil(XMLHelper.get_value(foundation_wall, "Area"))
      child_vals[:azimuth] = _to_integer_or_nil(XMLHelper.get_value(foundation_wall, "Azimuth"))
      child_vals[:thickness] = _to_float_or_nil(XMLHelper.get_value(foundation_wall, "Thickness"))
      child_vals[:depth_below_grade] = _to_float_or_nil(XMLHelper.get_value(foundation_wall, "DepthBelowGrade"))
      insulation = foundation_wall.elements["Insulation"]
      if not insulation.nil?
        child_vals[:insulation_id] = _get_object_id(insulation)
        child_vals[:insulation_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='continuous']/NominalRValue"))
        child_vals[:insulation_interior_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='continuous - interior']/NominalRValue"))
        child_vals[:insulation_interior_distance_to_top] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='continuous - interior']/extension/DistanceToTopOfInsulation"))
        child_vals[:insulation_interior_distance_to_bottom] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='continuous - interior']/extension/DistanceToBottomOfInsulation"))
        child_vals[:insulation_exterior_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='continuous - exterior']/NominalRValue"))
        child_vals[:insulation_exterior_distance_to_top] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='continuous - exterior']/extension/DistanceToTopOfInsulation"))
        child_vals[:insulation_exterior_distance_to_bottom] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='continuous - exterior']/extension/DistanceToBottomOfInsulation"))
        child_vals[:insulation_assembly_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "AssemblyEffectiveRValue"))
      end
      vals << child_vals
    end
    return vals
  end

  def _add_object_frame_floor(id:,
                              exterior_adjacent_to:,
                              interior_adjacent_to:,
                              area:,
                              insulation_id: nil,
                              insulation_assembly_r_value:)
    frame_floors = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Enclosure", "FrameFloors"])
    frame_floor = XMLHelper.add_element(frame_floors, "FrameFloor")
    sys_id = XMLHelper.add_element(frame_floor, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(frame_floor, "ExteriorAdjacentTo", exterior_adjacent_to)
    XMLHelper.add_element(frame_floor, "InteriorAdjacentTo", interior_adjacent_to)
    XMLHelper.add_element(frame_floor, "Area", Float(area))
    insulation = XMLHelper.add_element(frame_floor, "Insulation")
    sys_id = XMLHelper.add_element(insulation, "SystemIdentifier")
    unless insulation_id.nil?
      XMLHelper.add_attribute(sys_id, "id", insulation_id)
    else
      XMLHelper.add_attribute(sys_id, "id", id + "Insulation")
    end
    XMLHelper.add_element(insulation, "AssemblyEffectiveRValue", Float(insulation_assembly_r_value))

    return frame_floor
  end

  def _get_object_frame_floors_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor") do |frame_floor|
      child_vals = {}
      child_vals[:id] = _get_object_id(frame_floor)
      child_vals[:exterior_adjacent_to] = XMLHelper.get_value(frame_floor, "ExteriorAdjacentTo")
      child_vals[:interior_adjacent_to] = XMLHelper.get_value(frame_floor, "InteriorAdjacentTo")
      child_vals[:area] = _to_float_or_nil(XMLHelper.get_value(frame_floor, "Area"))
      insulation = frame_floor.elements["Insulation"]
      if not insulation.nil?
        child_vals[:insulation_id] = _get_object_id(insulation)
        child_vals[:insulation_assembly_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "AssemblyEffectiveRValue"))
        child_vals[:insulation_cavity_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='cavity']/NominalRValue"))
        child_vals[:insulation_continuous_r_value] = _to_float_or_nil(XMLHelper.get_value(insulation, "Layer[InstallationType='continuous']/NominalRValue"))
      end
      vals << child_vals
    end
    return vals
  end

  def _add_object_slab(id:,
                       interior_adjacent_to:,
                       area:,
                       thickness:,
                       exposed_perimeter:,
                       perimeter_insulation_depth:,
                       under_slab_insulation_width: nil,
                       under_slab_insulation_spans_entire_slab: nil,
                       depth_below_grade: nil,
                       carpet_fraction:,
                       carpet_r_value:,
                       perimeter_insulation_id: nil,
                       perimeter_insulation_r_value:,
                       under_slab_insulation_id: nil,
                       under_slab_insulation_r_value:)
    slabs = foundation_walls = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Enclosure", "Slabs"])
    slab = XMLHelper.add_element(slabs, "Slab")
    sys_id = XMLHelper.add_element(slab, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(slab, "InteriorAdjacentTo", interior_adjacent_to)
    XMLHelper.add_element(slab, "Area", Float(area))
    XMLHelper.add_element(slab, "Thickness", Float(thickness))
    XMLHelper.add_element(slab, "ExposedPerimeter", Float(exposed_perimeter))
    XMLHelper.add_element(slab, "PerimeterInsulationDepth", Float(perimeter_insulation_depth))
    XMLHelper.add_element(slab, "UnderSlabInsulationWidth", Float(under_slab_insulation_width)) unless under_slab_insulation_width.nil?
    XMLHelper.add_element(slab, "UnderSlabInsulationSpansEntireSlab", Boolean(under_slab_insulation_spans_entire_slab)) unless under_slab_insulation_spans_entire_slab.nil?
    XMLHelper.add_element(slab, "DepthBelowGrade", Float(depth_below_grade)) unless depth_below_grade.nil?
    insulation = XMLHelper.add_element(slab, "PerimeterInsulation")
    sys_id = XMLHelper.add_element(insulation, "SystemIdentifier")
    unless perimeter_insulation_id.nil?
      XMLHelper.add_attribute(sys_id, "id", perimeter_insulation_id)
    else
      XMLHelper.add_attribute(sys_id, "id", id + "PerimeterInsulation")
    end
    layer = XMLHelper.add_element(insulation, "Layer")
    XMLHelper.add_element(layer, "InstallationType", "continuous")
    XMLHelper.add_element(layer, "NominalRValue", Float(perimeter_insulation_r_value))
    insulation = XMLHelper.add_element(slab, "UnderSlabInsulation")
    sys_id = XMLHelper.add_element(insulation, "SystemIdentifier")
    unless under_slab_insulation_id.nil?
      XMLHelper.add_attribute(sys_id, "id", under_slab_insulation_id)
    else
      XMLHelper.add_attribute(sys_id, "id", id + "UnderSlabInsulation")
    end
    layer = XMLHelper.add_element(insulation, "Layer")
    XMLHelper.add_element(layer, "InstallationType", "continuous")
    XMLHelper.add_element(layer, "NominalRValue", Float(under_slab_insulation_r_value))
    _add_object_extension(parent: slab,
                          extensions: { "CarpetFraction" => _to_float_or_nil(carpet_fraction),
                                        "CarpetRValue" => _to_float_or_nil(carpet_r_value) })

    return slab
  end

  def _get_object_slabs_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Enclosure/Slabs/Slab") do |slab|
      child_vals = {}
      child_vals[:id] = _get_object_id(slab)
      child_vals[:interior_adjacent_to] = XMLHelper.get_value(slab, "InteriorAdjacentTo")
      child_vals[:exterior_adjacent_to] = "outside"
      child_vals[:area] = _to_float_or_nil(XMLHelper.get_value(slab, "Area"))
      child_vals[:thickness] = _to_float_or_nil(XMLHelper.get_value(slab, "Thickness"))
      child_vals[:exposed_perimeter] = _to_float_or_nil(XMLHelper.get_value(slab, "ExposedPerimeter"))
      child_vals[:perimeter_insulation_depth] = _to_float_or_nil(XMLHelper.get_value(slab, "PerimeterInsulationDepth"))
      child_vals[:under_slab_insulation_width] = _to_float_or_nil(XMLHelper.get_value(slab, "UnderSlabInsulationWidth"))
      child_vals[:under_slab_insulation_spans_entire_slab] = _to_bool_or_nil(XMLHelper.get_value(slab, "UnderSlabInsulationSpansEntireSlab"))
      child_vals[:depth_below_grade] = _to_float_or_nil(XMLHelper.get_value(slab, "DepthBelowGrade"))
      child_vals[:carpet_fraction] = _to_float_or_nil(XMLHelper.get_value(slab, "extension/CarpetFraction"))
      child_vals[:carpet_r_value] = _to_float_or_nil(XMLHelper.get_value(slab, "extension/CarpetRValue"))
      perimeter_insulation = slab.elements["PerimeterInsulation"]
      if not perimeter_insulation.nil?
        child_vals[:perimeter_insulation_id] = _get_object_id(perimeter_insulation)
        child_vals[:perimeter_insulation_r_value] = _to_float_or_nil(XMLHelper.get_value(perimeter_insulation, "Layer[InstallationType='continuous']/NominalRValue"))
      end
      under_slab_insulation = slab.elements["UnderSlabInsulation"]
      if not under_slab_insulation.nil?
        child_vals[:under_slab_insulation_id] = _get_object_id(under_slab_insulation)
        child_vals[:under_slab_insulation_r_value] = _to_float_or_nil(XMLHelper.get_value(under_slab_insulation, "Layer[InstallationType='continuous']/NominalRValue"))
      end
      vals << child_vals
    end
    return vals
  end

  def _add_object_window(id:,
                         area:,
                         azimuth:,
                         ufactor:,
                         shgc:,
                         overhangs_depth: nil,
                         overhangs_distance_to_top_of_window: nil,
                         overhangs_distance_to_bottom_of_window: nil,
                         interior_shading_factor_summer: nil,
                         interior_shading_factor_winter: nil,
                         wall_idref:)
    windows = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Enclosure", "Windows"])
    window = XMLHelper.add_element(windows, "Window")
    sys_id = XMLHelper.add_element(window, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(window, "Area", Float(area))
    XMLHelper.add_element(window, "Azimuth", Integer(azimuth))
    XMLHelper.add_element(window, "UFactor", Float(ufactor))
    XMLHelper.add_element(window, "SHGC", Float(shgc))
    if not interior_shading_factor_summer.nil? or not interior_shading_factor_winter.nil?
      interior_shading = XMLHelper.add_element(window, "InteriorShading")
      sys_id = XMLHelper.add_element(interior_shading, "SystemIdentifier")
      XMLHelper.add_attribute(sys_id, "id", "#{id}InteriorShading")
      XMLHelper.add_element(interior_shading, "SummerShadingCoefficient", Float(interior_shading_factor_summer)) unless interior_shading_factor_summer.nil?
      XMLHelper.add_element(interior_shading, "WinterShadingCoefficient", Float(interior_shading_factor_winter)) unless interior_shading_factor_winter.nil?
    end
    if not overhangs_depth.nil? or not overhangs_distance_to_top_of_window.nil? or not overhangs_distance_to_bottom_of_window.nil?
      overhangs = XMLHelper.add_element(window, "Overhangs")
      XMLHelper.add_element(overhangs, "Depth", Float(overhangs_depth))
      XMLHelper.add_element(overhangs, "DistanceToTopOfWindow", Float(overhangs_distance_to_top_of_window))
      XMLHelper.add_element(overhangs, "DistanceToBottomOfWindow", Float(overhangs_distance_to_bottom_of_window))
    end
    attached_to_wall = XMLHelper.add_element(window, "AttachedToWall")
    XMLHelper.add_attribute(attached_to_wall, "idref", wall_idref)

    return window
  end

  def _get_object_windows_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Enclosure/Windows/Window") do |window|
      child_vals = {}
      child_vals[:id] = _get_object_id(window)
      child_vals[:area] = _to_float_or_nil(XMLHelper.get_value(window, "Area"))
      child_vals[:azimuth] = _to_integer_or_nil(XMLHelper.get_value(window, "Azimuth"))
      child_vals[:orientation] = XMLHelper.get_value(window, "Orientation")
      child_vals[:frame_type] = XMLHelper.get_child_name(window, "FrameType")
      child_vals[:aluminum_thermal_break] = _to_bool_or_nil(XMLHelper.get_value(window, "FrameType/Aluminum/ThermalBreak"))
      child_vals[:glass_layers] = XMLHelper.get_value(window, "GlassLayers")
      child_vals[:glass_type] = XMLHelper.get_value(window, "GlassType")
      child_vals[:gas_fill] = XMLHelper.get_value(window, "GasFill")
      child_vals[:ufactor] = _to_float_or_nil(XMLHelper.get_value(window, "UFactor"))
      child_vals[:shgc] = _to_float_or_nil(XMLHelper.get_value(window, "SHGC"))
      child_vals[:interior_shading_factor_summer] = _to_float_or_nil(XMLHelper.get_value(window, "InteriorShading/SummerShadingCoefficient"))
      child_vals[:interior_shading_factor_winter] = _to_float_or_nil(XMLHelper.get_value(window, "InteriorShading/WinterShadingCoefficient"))
      child_vals[:exterior_shading] = XMLHelper.get_value(window, "ExteriorShading/Type")
      child_vals[:overhangs_depth] = _to_float_or_nil(XMLHelper.get_value(window, "Overhangs/Depth"))
      child_vals[:overhangs_distance_to_top_of_window] = _to_float_or_nil(XMLHelper.get_value(window, "Overhangs/DistanceToTopOfWindow"))
      child_vals[:overhangs_distance_to_bottom_of_window] = _to_float_or_nil(XMLHelper.get_value(window, "Overhangs/DistanceToBottomOfWindow"))
      child_vals[:wall_idref] = _get_object_idref(window, "AttachedToWall")
      vals << child_vals
    end
    return vals
  end

  def _add_object_skylight(id:,
                           area:,
                           azimuth:,
                           ufactor:,
                           shgc:,
                           roof_idref:)
    skylights = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Enclosure", "Skylights"])
    skylight = XMLHelper.add_element(skylights, "Skylight")
    sys_id = XMLHelper.add_element(skylight, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(skylight, "Area", Float(area))
    XMLHelper.add_element(skylight, "Azimuth", Integer(azimuth))
    XMLHelper.add_element(skylight, "UFactor", Float(ufactor))
    XMLHelper.add_element(skylight, "SHGC", Float(shgc))
    attached_to_roof = XMLHelper.add_element(skylight, "AttachedToRoof")
    XMLHelper.add_attribute(attached_to_roof, "idref", roof_idref)

    return skylight
  end

  def _get_object_skylights_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Enclosure/Skylights/Skylight") do |skylight|
      child_vals = {}
      child_vals[:id] = _get_object_id(skylight)
      child_vals[:area] = _to_float_or_nil(XMLHelper.get_value(skylight, "Area"))
      child_vals[:azimuth] = _to_integer_or_nil(XMLHelper.get_value(skylight, "Azimuth"))
      child_vals[:orientation] = XMLHelper.get_value(skylight, "Orientation")
      child_vals[:frame_type] = XMLHelper.get_child_name(skylight, "FrameType")
      child_vals[:aluminum_thermal_break] = _to_bool_or_nil(XMLHelper.get_value(skylight, "FrameType/Aluminum/ThermalBreak"))
      child_vals[:glass_layers] = XMLHelper.get_value(skylight, "GlassLayers")
      child_vals[:glass_type] = XMLHelper.get_value(skylight, "GlassType")
      child_vals[:gas_fill] = XMLHelper.get_value(skylight, "GasFill")
      child_vals[:ufactor] = _to_float_or_nil(XMLHelper.get_value(skylight, "UFactor"))
      child_vals[:shgc] = _to_float_or_nil(XMLHelper.get_value(skylight, "SHGC"))
      child_vals[:exterior_shading] = XMLHelper.get_value(skylight, "ExteriorShading/Type")
      child_vals[:roof_idref] = _get_object_idref(skylight, "AttachedToRoof")
      vals << child_vals
    end
    return vals
  end

  def _add_object_door(id:,
                       wall_idref:,
                       area:,
                       azimuth:,
                       r_value:)
    doors = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Enclosure", "Doors"])
    door = XMLHelper.add_element(doors, "Door")
    sys_id = XMLHelper.add_element(door, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    attached_to_wall = XMLHelper.add_element(door, "AttachedToWall")
    XMLHelper.add_attribute(attached_to_wall, "idref", wall_idref)
    XMLHelper.add_element(door, "Area", Float(area))
    XMLHelper.add_element(door, "Azimuth", Integer(azimuth))
    XMLHelper.add_element(door, "RValue", Float(r_value))

    return door
  end

  def _get_object_doors_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Enclosure/Doors/Door") do |door|
      child_vals = {}
      child_vals[:id] = _get_object_id(door)
      child_vals[:wall_idref] = _get_object_idref(door, "AttachedToWall")
      child_vals[:area] = _to_float_or_nil(XMLHelper.get_value(door, "Area"))
      child_vals[:azimuth] = _to_integer_or_nil(XMLHelper.get_value(door, "Azimuth"))
      child_vals[:r_value] = _to_float_or_nil(XMLHelper.get_value(door, "RValue"))
      vals << child_vals
    end
    return vals
  end

  def _add_object_heating_system(id:,
                                 distribution_system_idref: nil,
                                 heating_system_type:,
                                 heating_system_fuel:,
                                 heating_capacity:,
                                 heating_efficiency_afue: nil,
                                 heating_efficiency_percent: nil,
                                 fraction_heat_load_served:,
                                 electric_auxiliary_energy: nil,
                                 heating_cfm: nil)
    hvac_plant = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Systems", "HVAC", "HVACPlant"])
    heating_system = XMLHelper.add_element(hvac_plant, "HeatingSystem")
    sys_id = XMLHelper.add_element(heating_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless distribution_system_idref.nil?
      distribution_system = XMLHelper.add_element(heating_system, "DistributionSystem")
      XMLHelper.add_attribute(distribution_system, "idref", distribution_system_idref)
    end
    heating_system_type_e = XMLHelper.add_element(heating_system, "HeatingSystemType")
    XMLHelper.add_element(heating_system_type_e, heating_system_type)
    XMLHelper.add_element(heating_system, "HeatingSystemFuel", heating_system_fuel)
    XMLHelper.add_element(heating_system, "HeatingCapacity", Float(heating_capacity))

    efficiency_units = nil
    efficiency_value = nil
    if ["Furnace", "WallFurnace", "Boiler"].include? heating_system_type
      efficiency_units = "AFUE"
      efficiency_value = heating_efficiency_afue
    elsif ["ElectricResistance", "Stove", "PortableHeater"].include? heating_system_type
      efficiency_units = "Percent"
      efficiency_value = heating_efficiency_percent
    end
    if not efficiency_value.nil?
      annual_efficiency = XMLHelper.add_element(heating_system, "AnnualHeatingEfficiency")
      XMLHelper.add_element(annual_efficiency, "Units", efficiency_units)
      XMLHelper.add_element(annual_efficiency, "Value", Float(efficiency_value))
    end

    XMLHelper.add_element(heating_system, "FractionHeatLoadServed", Float(fraction_heat_load_served))
    XMLHelper.add_element(heating_system, "ElectricAuxiliaryEnergy", Float(electric_auxiliary_energy)) unless electric_auxiliary_energy.nil?
    _add_object_extension(parent: heating_system,
                          extensions: { "HeatingFlowRate" => _to_float_or_nil(heating_cfm) })

    return heating_system
  end

  def _get_object_heating_systems_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem") do |heating_system|
      child_vals = {}
      child_vals[:id] = _get_object_id(heating_system)
      child_vals[:distribution_system_idref] = _get_object_idref(heating_system, "DistributionSystem")
      child_vals[:year_installed] = _to_integer_or_nil(XMLHelper.get_value(heating_system, "YearInstalled"))
      child_vals[:heating_system_type] = XMLHelper.get_child_name(heating_system, "HeatingSystemType")
      child_vals[:heating_system_fuel] = XMLHelper.get_value(heating_system, "HeatingSystemFuel")
      child_vals[:heating_capacity] = _to_float_or_nil(XMLHelper.get_value(heating_system, "HeatingCapacity"))
      child_vals[:heating_efficiency_afue] = _to_float_or_nil(XMLHelper.get_value(heating_system, "[HeatingSystemType[Furnace | WallFurnace | Boiler]]AnnualHeatingEfficiency[Units='AFUE']/Value"))
      child_vals[:heating_efficiency_percent] = _to_float_or_nil(XMLHelper.get_value(heating_system, "[HeatingSystemType[ElectricResistance | Stove | PortableHeater]]AnnualHeatingEfficiency[Units='Percent']/Value"))
      child_vals[:fraction_heat_load_served] = _to_float_or_nil(XMLHelper.get_value(heating_system, "FractionHeatLoadServed"))
      child_vals[:electric_auxiliary_energy] = _to_float_or_nil(XMLHelper.get_value(heating_system, "ElectricAuxiliaryEnergy"))
      child_vals[:heating_cfm] = _to_float_or_nil(XMLHelper.get_value(heating_system, "extension/HeatingFlowRate"))
      child_vals[:energy_star] = XMLHelper.get_values(heating_system, "ThirdPartyCertification").include?("Energy Star")
      vals << child_vals
    end
    return vals
  end

  def _add_object_cooling_system(id:,
                                 distribution_system_idref: nil,
                                 cooling_system_type:,
                                 cooling_system_fuel:,
                                 compressor_type: nil,
                                 cooling_capacity: nil,
                                 fraction_cool_load_served:,
                                 cooling_efficiency_seer: nil,
                                 cooling_efficiency_eer: nil,
                                 cooling_shr: nil,
                                 cooling_cfm: nil)
    hvac_plant = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Systems", "HVAC", "HVACPlant"])
    cooling_system = XMLHelper.add_element(hvac_plant, "CoolingSystem")
    sys_id = XMLHelper.add_element(cooling_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless distribution_system_idref.nil?
      distribution_system = XMLHelper.add_element(cooling_system, "DistributionSystem")
      XMLHelper.add_attribute(distribution_system, "idref", distribution_system_idref)
    end
    XMLHelper.add_element(cooling_system, "CoolingSystemType", cooling_system_type)
    XMLHelper.add_element(cooling_system, "CoolingSystemFuel", cooling_system_fuel)
    XMLHelper.add_element(cooling_system, "CoolingCapacity", Float(cooling_capacity)) unless cooling_capacity.nil?
    XMLHelper.add_element(cooling_system, "CompressorType", compressor_type) unless compressor_type.nil?
    XMLHelper.add_element(cooling_system, "FractionCoolLoadServed", Float(fraction_cool_load_served))

    efficiency_units = nil
    efficiency_value = nil
    if ["central air conditioner"].include? cooling_system_type
      efficiency_units = "SEER"
      efficiency_value = cooling_efficiency_seer
    elsif ["room air conditioner"].include? cooling_system_type
      efficiency_units = "EER"
      efficiency_value = cooling_efficiency_eer
    end
    if not efficiency_value.nil?
      annual_efficiency = XMLHelper.add_element(cooling_system, "AnnualCoolingEfficiency")
      XMLHelper.add_element(annual_efficiency, "Units", efficiency_units)
      XMLHelper.add_element(annual_efficiency, "Value", Float(efficiency_value))
    end

    XMLHelper.add_element(cooling_system, "SensibleHeatFraction", Float(cooling_shr)) unless cooling_shr.nil?
    _add_object_extension(parent: cooling_system,
                          extensions: { "CoolingFlowRate" => _to_float_or_nil(cooling_cfm) })

    return cooling_system
  end

  def _get_object_cooling_systems_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem") do |cooling_system|
      child_vals = {}
      child_vals[:id] = _get_object_id(cooling_system)
      child_vals[:distribution_system_idref] = _get_object_idref(cooling_system, "DistributionSystem")
      child_vals[:year_installed] = _to_integer_or_nil(XMLHelper.get_value(cooling_system, "YearInstalled"))
      child_vals[:cooling_system_type] = XMLHelper.get_value(cooling_system, "CoolingSystemType")
      child_vals[:cooling_system_fuel] = XMLHelper.get_value(cooling_system, "CoolingSystemFuel")
      child_vals[:cooling_capacity] = _to_float_or_nil(XMLHelper.get_value(cooling_system, "CoolingCapacity"))
      child_vals[:compressor_type] = XMLHelper.get_value(cooling_system, "CompressorType")
      child_vals[:fraction_cool_load_served] = _to_float_or_nil(XMLHelper.get_value(cooling_system, "FractionCoolLoadServed"))
      child_vals[:cooling_efficiency_seer] = _to_float_or_nil(XMLHelper.get_value(cooling_system, "[CoolingSystemType='central air conditioner']AnnualCoolingEfficiency[Units='SEER']/Value"))
      child_vals[:cooling_efficiency_eer] = _to_float_or_nil(XMLHelper.get_value(cooling_system, "[CoolingSystemType='room air conditioner']AnnualCoolingEfficiency[Units='EER']/Value"))
      child_vals[:cooling_shr] = _to_float_or_nil(XMLHelper.get_value(cooling_system, "SensibleHeatFraction"))
      child_vals[:cooling_cfm] = _to_float_or_nil(XMLHelper.get_value(cooling_system, "extension/CoolingFlowRate"))
      child_vals[:energy_star] = XMLHelper.get_values(cooling_system, "ThirdPartyCertification").include?("Energy Star")
      vals << child_vals
    end
    return vals
  end

  def _add_object_heat_pump(id:,
                            distribution_system_idref: nil,
                            heat_pump_type:,
                            heat_pump_fuel:,
                            compressor_type: nil,
                            heating_capacity: nil,
                            heating_capacity_17F: nil,
                            cooling_capacity:,
                            cooling_shr: nil,
                            backup_heating_fuel: nil,
                            backup_heating_capacity: nil,
                            backup_heating_efficiency_percent: nil,
                            backup_heating_efficiency_afue: nil,
                            backup_heating_switchover_temp: nil,
                            fraction_heat_load_served:,
                            fraction_cool_load_served:,
                            cooling_efficiency_seer: nil,
                            cooling_efficiency_eer: nil,
                            heating_efficiency_hspf: nil,
                            heating_efficiency_cop: nil)
    hvac_plant = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Systems", "HVAC", "HVACPlant"])
    heat_pump = XMLHelper.add_element(hvac_plant, "HeatPump")
    sys_id = XMLHelper.add_element(heat_pump, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    unless distribution_system_idref.nil?
      distribution_system = XMLHelper.add_element(heat_pump, "DistributionSystem")
      XMLHelper.add_attribute(distribution_system, "idref", distribution_system_idref)
    end
    XMLHelper.add_element(heat_pump, "HeatPumpType", heat_pump_type)
    XMLHelper.add_element(heat_pump, "HeatPumpFuel", heat_pump_fuel)
    XMLHelper.add_element(heat_pump, "HeatingCapacity", Float(heating_capacity)) unless heating_capacity.nil?
    XMLHelper.add_element(heat_pump, "HeatingCapacity17F", Float(heating_capacity_17F)) unless heating_capacity_17F.nil?
    XMLHelper.add_element(heat_pump, "CoolingCapacity", Float(cooling_capacity))
    XMLHelper.add_element(heat_pump, "CompressorType", compressor_type) unless compressor_type.nil?
    XMLHelper.add_element(heat_pump, "CoolingSensibleHeatFraction", Float(cooling_shr)) unless cooling_shr.nil?
    if not backup_heating_fuel.nil?
      XMLHelper.add_element(heat_pump, "BackupSystemFuel", backup_heating_fuel)
      efficiencies = { "Percent" => backup_heating_efficiency_percent,
                       "AFUE" => backup_heating_efficiency_afue }
      efficiencies.each do |units, value|
        next if value.nil?

        backup_eff = XMLHelper.add_element(heat_pump, "BackupAnnualHeatingEfficiency")
        XMLHelper.add_element(backup_eff, "Units", units)
        XMLHelper.add_element(backup_eff, "Value", Float(value))
      end
      XMLHelper.add_element(heat_pump, "BackupHeatingCapacity", Float(backup_heating_capacity))
      XMLHelper.add_element(heat_pump, "BackupHeatingSwitchoverTemperature", Float(backup_heating_switchover_temp)) unless backup_heating_switchover_temp.nil?
    end
    XMLHelper.add_element(heat_pump, "FractionHeatLoadServed", Float(fraction_heat_load_served))
    XMLHelper.add_element(heat_pump, "FractionCoolLoadServed", Float(fraction_cool_load_served))

    clg_efficiency_units = nil
    clg_efficiency_value = nil
    htg_efficiency_units = nil
    htg_efficiency_value = nil
    if ["air-to-air", "mini-split"].include? heat_pump_type
      clg_efficiency_units = "SEER"
      clg_efficiency_value = cooling_efficiency_seer
      htg_efficiency_units = "HSPF"
      htg_efficiency_value = heating_efficiency_hspf
    elsif ["ground-to-air"].include? heat_pump_type
      clg_efficiency_units = "EER"
      clg_efficiency_value = cooling_efficiency_eer
      htg_efficiency_units = "COP"
      htg_efficiency_value = heating_efficiency_cop
    end
    if not clg_efficiency_value.nil?
      annual_efficiency = XMLHelper.add_element(heat_pump, "AnnualCoolingEfficiency")
      XMLHelper.add_element(annual_efficiency, "Units", clg_efficiency_units)
      XMLHelper.add_element(annual_efficiency, "Value", Float(clg_efficiency_value))
    end
    if not htg_efficiency_value.nil?
      annual_efficiency = XMLHelper.add_element(heat_pump, "AnnualHeatingEfficiency")
      XMLHelper.add_element(annual_efficiency, "Units", htg_efficiency_units)
      XMLHelper.add_element(annual_efficiency, "Value", Float(htg_efficiency_value))
    end

    return heat_pump
  end

  def _get_object_heat_pumps_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump") do |heat_pump|
      child_vals = {}
      child_vals[:id] = _get_object_id(heat_pump)
      child_vals[:distribution_system_idref] = _get_object_idref(heat_pump, "DistributionSystem")
      child_vals[:year_installed] = _to_integer_or_nil(XMLHelper.get_value(heat_pump, "YearInstalled"))
      child_vals[:heat_pump_type] = XMLHelper.get_value(heat_pump, "HeatPumpType")
      child_vals[:heat_pump_fuel] = XMLHelper.get_value(heat_pump, "HeatPumpFuel")
      child_vals[:heating_capacity] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "HeatingCapacity"))
      child_vals[:heating_capacity_17F] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "HeatingCapacity17F"))
      child_vals[:cooling_capacity] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "CoolingCapacity"))
      child_vals[:compressor_type] = XMLHelper.get_value(heat_pump, "CompressorType")
      child_vals[:cooling_shr] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "CoolingSensibleHeatFraction"))
      child_vals[:backup_heating_fuel] = XMLHelper.get_value(heat_pump, "BackupSystemFuel")
      child_vals[:backup_heating_capacity] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "BackupHeatingCapacity"))
      child_vals[:backup_heating_efficiency_percent] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "BackupAnnualHeatingEfficiency[Units='Percent']/Value"))
      child_vals[:backup_heating_efficiency_afue] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "BackupAnnualHeatingEfficiency[Units='AFUE']/Value"))
      child_vals[:backup_heating_switchover_temp] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "BackupHeatingSwitchoverTemperature"))
      child_vals[:fraction_heat_load_served] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "FractionHeatLoadServed"))
      child_vals[:fraction_cool_load_served] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "FractionCoolLoadServed"))
      child_vals[:cooling_efficiency_seer] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "[HeatPumpType='air-to-air' or HeatPumpType='mini-split']AnnualCoolingEfficiency[Units='SEER']/Value"))
      child_vals[:cooling_efficiency_eer] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "[HeatPumpType='ground-to-air']AnnualCoolingEfficiency[Units='EER']/Value"))
      child_vals[:heating_efficiency_hspf] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "[HeatPumpType='air-to-air' or HeatPumpType='mini-split']AnnualHeatingEfficiency[Units='HSPF']/Value"))
      child_vals[:heating_efficiency_cop] = _to_float_or_nil(XMLHelper.get_value(heat_pump, "[HeatPumpType='ground-to-air']AnnualHeatingEfficiency[Units='COP']/Value"))
      child_vals[:energy_star] = XMLHelper.get_values(heat_pump, "ThirdPartyCertification").include?("Energy Star")
      vals << child_vals
    end
    return vals
  end

  def _add_object_hvac_control(id:,
                               control_type: nil,
                               heating_setpoint_temp: nil,
                               heating_setback_temp: nil,
                               heating_setback_hours_per_week: nil,
                               heating_setback_start_hour: nil,
                               cooling_setpoint_temp: nil,
                               cooling_setup_temp: nil,
                               cooling_setup_hours_per_week: nil,
                               cooling_setup_start_hour: nil,
                               ceiling_fan_cooling_setpoint_temp_offset: nil)
    hvac = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Systems", "HVAC"])
    hvac_control = XMLHelper.add_element(hvac, "HVACControl")
    sys_id = XMLHelper.add_element(hvac_control, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(hvac_control, "ControlType", control_type) unless control_type.nil?
    XMLHelper.add_element(hvac_control, "SetpointTempHeatingSeason", Float(heating_setpoint_temp)) unless heating_setpoint_temp.nil?
    XMLHelper.add_element(hvac_control, "SetbackTempHeatingSeason", Float(heating_setback_temp)) unless heating_setback_temp.nil?
    XMLHelper.add_element(hvac_control, "TotalSetbackHoursperWeekHeating", Integer(heating_setback_hours_per_week)) unless heating_setback_hours_per_week.nil?
    XMLHelper.add_element(hvac_control, "SetupTempCoolingSeason", Float(cooling_setup_temp)) unless cooling_setup_temp.nil?
    XMLHelper.add_element(hvac_control, "SetpointTempCoolingSeason", Float(cooling_setpoint_temp)) unless cooling_setpoint_temp.nil?
    XMLHelper.add_element(hvac_control, "TotalSetupHoursperWeekCooling", Integer(cooling_setup_hours_per_week)) unless cooling_setup_hours_per_week.nil?
    _add_object_extension(parent: hvac_control,
                          extensions: { "SetbackStartHourHeating" => _to_integer_or_nil(heating_setback_start_hour),
                                        "SetupStartHourCooling" => _to_integer_or_nil(cooling_setup_start_hour),
                                        "CeilingFanSetpointTempCoolingSeasonOffset" => _to_float_or_nil(ceiling_fan_cooling_setpoint_temp_offset) })

    return hvac_control
  end

  def _get_object_hvac_control_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    hvac_control = hpxml.elements["Building/BuildingDetails/Systems/HVAC/HVACControl"]
    return vals if hvac_control.nil?

    vals[:id] = _get_object_id(hvac_control)
    vals[:control_type] = XMLHelper.get_value(hvac_control, "ControlType")
    vals[:heating_setpoint_temp] = _to_float_or_nil(XMLHelper.get_value(hvac_control, "SetpointTempHeatingSeason"))
    vals[:heating_setback_temp] = _to_float_or_nil(XMLHelper.get_value(hvac_control, "SetbackTempHeatingSeason"))
    vals[:heating_setback_hours_per_week] = _to_integer_or_nil(XMLHelper.get_value(hvac_control, "TotalSetbackHoursperWeekHeating"))
    vals[:heating_setback_start_hour] = _to_integer_or_nil(XMLHelper.get_value(hvac_control, "extension/SetbackStartHourHeating"))
    vals[:cooling_setpoint_temp] = _to_float_or_nil(XMLHelper.get_value(hvac_control, "SetpointTempCoolingSeason"))
    vals[:cooling_setup_temp] = _to_float_or_nil(XMLHelper.get_value(hvac_control, "SetupTempCoolingSeason"))
    vals[:cooling_setup_hours_per_week] = _to_integer_or_nil(XMLHelper.get_value(hvac_control, "TotalSetupHoursperWeekCooling"))
    vals[:cooling_setup_start_hour] = _to_integer_or_nil(XMLHelper.get_value(hvac_control, "extension/SetupStartHourCooling"))
    vals[:ceiling_fan_cooling_setpoint_temp_offset] = _to_float_or_nil(XMLHelper.get_value(hvac_control, "extension/CeilingFanSetpointTempCoolingSeasonOffset"))
    return vals
  end

  def _add_object_hvac_distribution(id:,
                                    distribution_system_type:,
                                    annual_heating_dse: nil,
                                    annual_cooling_dse: nil,
                                    duct_leakage_measurements:,
                                    ducts:)
    hvac = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Systems", "HVAC"])
    hvac_distribution = XMLHelper.add_element(hvac, "HVACDistribution")
    sys_id = XMLHelper.add_element(hvac_distribution, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    distribution_system_type_e = XMLHelper.add_element(hvac_distribution, "DistributionSystemType")
    if ["AirDistribution", "HydronicDistribution"].include? distribution_system_type
      XMLHelper.add_element(distribution_system_type_e, distribution_system_type)
    elsif ["DSE"].include? distribution_system_type
      XMLHelper.add_element(distribution_system_type_e, "Other", distribution_system_type)
      XMLHelper.add_element(hvac_distribution, "AnnualHeatingDistributionSystemEfficiency", Float(annual_heating_dse)) unless annual_heating_dse.nil?
      XMLHelper.add_element(hvac_distribution, "AnnualCoolingDistributionSystemEfficiency", Float(annual_cooling_dse)) unless annual_cooling_dse.nil?
    else
      fail "Unexpected distribution_system_type '#{distribution_system_type}'."
    end

    air_distribution = hvac_distribution.elements["DistributionSystemType/AirDistribution"]
    return hvac_distribution if air_distribution.nil?

    duct_leakage_measurements.each do |duct_leakage_measurement_values|
      duct_leakage_measurement_el = XMLHelper.add_element(air_distribution, "DuctLeakageMeasurement")
      XMLHelper.add_element(duct_leakage_measurement_el, "DuctType", duct_leakage_measurement_values[:duct_type])
      duct_leakage_el = XMLHelper.add_element(duct_leakage_measurement_el, "DuctLeakage")
      XMLHelper.add_element(duct_leakage_el, "Units", duct_leakage_measurement_values[:duct_leakage_units])
      XMLHelper.add_element(duct_leakage_el, "Value", Float(duct_leakage_measurement_values[:duct_leakage_value]))
      XMLHelper.add_element(duct_leakage_el, "TotalOrToOutside", "to outside")
    end

    ducts.each do |duct_values|
      ducts_el = XMLHelper.add_element(air_distribution, "Ducts")
      XMLHelper.add_element(ducts_el, "DuctType", duct_values[:duct_type])
      XMLHelper.add_element(ducts_el, "DuctInsulationRValue", Float(duct_values[:duct_insulation_r_value]))
      XMLHelper.add_element(ducts_el, "DuctLocation", duct_values[:duct_location])
      XMLHelper.add_element(ducts_el, "DuctSurfaceArea", Float(duct_values[:duct_surface_area]))
    end

    return hvac_distribution
  end

  def _get_object_hvac_distributions_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Systems/HVAC/HVACDistribution") do |hvac_distribution|
      child_vals = {}
      child_vals[:id] = _get_object_id(hvac_distribution)
      child_vals[:distribution_system_type] = XMLHelper.get_child_name(hvac_distribution, "DistributionSystemType")
      if child_vals[:distribution_system_type] == "Other"
        child_vals[:distribution_system_type] = XMLHelper.get_value(hvac_distribution.elements["DistributionSystemType"], "Other")
      end
      child_vals[:annual_heating_dse] = _to_float_or_nil(XMLHelper.get_value(hvac_distribution, "AnnualHeatingDistributionSystemEfficiency"))
      child_vals[:annual_cooling_dse] = _to_float_or_nil(XMLHelper.get_value(hvac_distribution, "AnnualCoolingDistributionSystemEfficiency"))
      child_vals[:duct_system_sealed] = _to_bool_or_nil(XMLHelper.get_value(hvac_distribution, "HVACDistributionImprovement/DuctSystemSealed"))

      child_vals[:duct_leakage_measurements] = []
      hvac_distribution.elements.each("DistributionSystemType/AirDistribution/DuctLeakageMeasurement") do |duct_leakage_measurement|
        child2_vals = {}
        child2_vals[:duct_type] = XMLHelper.get_value(duct_leakage_measurement, "DuctType")
        child2_vals[:duct_leakage_test_method] = XMLHelper.get_value(duct_leakage_measurement, "DuctLeakageTestMethod")
        child2_vals[:duct_leakage_units] = XMLHelper.get_value(duct_leakage_measurement, "DuctLeakage/Units")
        child2_vals[:duct_leakage_value] = _to_float_or_nil(XMLHelper.get_value(duct_leakage_measurement, "DuctLeakage/Value"))
        child2_vals[:duct_leakage_total_or_to_outside] = XMLHelper.get_value(duct_leakage_measurement, "DuctLeakage/TotalOrToOutside")
        child_vals[:duct_leakage_measurements] << child2_vals
      end

      child_vals[:ducts] = []
      hvac_distribution.elements.each("DistributionSystemType/AirDistribution/Ducts") do |ducts|
        child2_vals = {}
        child2_vals[:duct_type] = XMLHelper.get_value(ducts, "DuctType")
        child2_vals[:duct_insulation_r_value] = _to_float_or_nil(XMLHelper.get_value(ducts, "DuctInsulationRValue"))
        child2_vals[:duct_insulation_material] = XMLHelper.get_child_name(ducts, "DuctInsulationMaterial")
        child2_vals[:duct_location] = XMLHelper.get_value(ducts, "DuctLocation")
        child2_vals[:duct_fraction_area] = _to_float_or_nil(XMLHelper.get_value(ducts, "FractionDuctArea"))
        child2_vals[:duct_surface_area] = _to_float_or_nil(XMLHelper.get_value(ducts, "DuctSurfaceArea"))
        child_vals[:ducts] << child2_vals
      end

      vals << child_vals
    end
    return vals
  end

  def _add_object_ventilation_fan(id:,
                                  fan_type: nil,
                                  rated_flow_rate: nil,
                                  tested_flow_rate: nil,
                                  hours_in_operation: nil,
                                  used_for_whole_building_ventilation: nil,
                                  used_for_seasonal_cooling_load_reduction: nil,
                                  total_recovery_efficiency: nil,
                                  total_recovery_efficiency_adjusted: nil,
                                  sensible_recovery_efficiency: nil,
                                  sensible_recovery_efficiency_adjusted: nil,
                                  fan_power: nil,
                                  distribution_system_idref: nil)
    ventilation_fans = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Systems", "MechanicalVentilation", "VentilationFans"])
    ventilation_fan = XMLHelper.add_element(ventilation_fans, "VentilationFan")
    sys_id = XMLHelper.add_element(ventilation_fan, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(ventilation_fan, "FanType", fan_type) unless fan_type.nil?
    XMLHelper.add_element(ventilation_fan, "RatedFlowRate", Float(rated_flow_rate)) unless rated_flow_rate.nil?
    XMLHelper.add_element(ventilation_fan, "TestedFlowRate", Float(tested_flow_rate)) unless tested_flow_rate.nil?
    XMLHelper.add_element(ventilation_fan, "HoursInOperation", Float(hours_in_operation)) unless hours_in_operation.nil?
    XMLHelper.add_element(ventilation_fan, "UsedForWholeBuildingVentilation", Boolean(used_for_whole_building_ventilation)) unless used_for_whole_building_ventilation.nil?
    XMLHelper.add_element(ventilation_fan, "UsedForSeasonalCoolingLoadReduction", Boolean(used_for_seasonal_cooling_load_reduction)) unless used_for_seasonal_cooling_load_reduction.nil?
    XMLHelper.add_element(ventilation_fan, "TotalRecoveryEfficiency", Float(total_recovery_efficiency)) unless total_recovery_efficiency.nil?
    XMLHelper.add_element(ventilation_fan, "SensibleRecoveryEfficiency", Float(sensible_recovery_efficiency)) unless sensible_recovery_efficiency.nil?
    XMLHelper.add_element(ventilation_fan, "AdjustedTotalRecoveryEfficiency", Float(total_recovery_efficiency_adjusted)) unless total_recovery_efficiency_adjusted.nil?
    XMLHelper.add_element(ventilation_fan, "AdjustedSensibleRecoveryEfficiency", Float(sensible_recovery_efficiency_adjusted)) unless sensible_recovery_efficiency_adjusted.nil?
    XMLHelper.add_element(ventilation_fan, "FanPower", Float(fan_power)) unless fan_power.nil?
    unless distribution_system_idref.nil?
      attached_to_hvac_distribution_system = XMLHelper.add_element(ventilation_fan, "AttachedToHVACDistributionSystem")
      XMLHelper.add_attribute(attached_to_hvac_distribution_system, "idref", distribution_system_idref)
    end

    return ventilation_fan
  end

  def _get_object_ventilation_fans_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan") do |ventilation_fan|
      child_vals = {}
      child_vals[:id] = _get_object_id(ventilation_fan)
      child_vals[:fan_type] = XMLHelper.get_value(ventilation_fan, "FanType")
      child_vals[:rated_flow_rate] = _to_float_or_nil(XMLHelper.get_value(ventilation_fan, "RatedFlowRate"))
      child_vals[:tested_flow_rate] = _to_float_or_nil(XMLHelper.get_value(ventilation_fan, "TestedFlowRate"))
      child_vals[:hours_in_operation] = _to_float_or_nil(XMLHelper.get_value(ventilation_fan, "HoursInOperation"))
      child_vals[:used_for_whole_building_ventilation] = _to_bool_or_nil(XMLHelper.get_value(ventilation_fan, "UsedForWholeBuildingVentilation"))
      child_vals[:used_for_seasonal_cooling_load_reduction] = _to_bool_or_nil(XMLHelper.get_value(ventilation_fan, "UsedForSeasonalCoolingLoadReduction"))
      child_vals[:total_recovery_efficiency] = _to_float_or_nil(XMLHelper.get_value(ventilation_fan, "TotalRecoveryEfficiency"))
      child_vals[:total_recovery_efficiency_adjusted] = _to_float_or_nil(XMLHelper.get_value(ventilation_fan, "AdjustedTotalRecoveryEfficiency"))
      child_vals[:sensible_recovery_efficiency] = _to_float_or_nil(XMLHelper.get_value(ventilation_fan, "SensibleRecoveryEfficiency"))
      child_vals[:sensible_recovery_efficiency_adjusted] = _to_float_or_nil(XMLHelper.get_value(ventilation_fan, "AdjustedSensibleRecoveryEfficiency"))
      child_vals[:fan_power] = _to_float_or_nil(XMLHelper.get_value(ventilation_fan, "FanPower"))
      child_vals[:distribution_system_idref] = _get_object_idref(ventilation_fan, "AttachedToHVACDistributionSystem")
      vals << child_vals
    end
    return vals
  end

  def _add_object_water_heating_system(id:,
                                       fuel_type: nil,
                                       water_heater_type:,
                                       location:,
                                       performance_adjustment: nil,
                                       tank_volume: nil,
                                       fraction_dhw_load_served:,
                                       heating_capacity: nil,
                                       energy_factor: nil,
                                       uniform_energy_factor: nil,
                                       recovery_efficiency: nil,
                                       uses_desuperheater: nil,
                                       jacket_r_value: nil,
                                       temperature: nil,
                                       related_hvac: nil,
                                       standby_loss: nil)
    water_heating = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Systems", "WaterHeating"])
    water_heating_system = XMLHelper.add_element(water_heating, "WaterHeatingSystem")
    sys_id = XMLHelper.add_element(water_heating_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(water_heating_system, "FuelType", fuel_type) unless fuel_type.nil?
    XMLHelper.add_element(water_heating_system, "WaterHeaterType", water_heater_type)
    XMLHelper.add_element(water_heating_system, "Location", location)
    XMLHelper.add_element(water_heating_system, "PerformanceAdjustment", Float(performance_adjustment)) unless performance_adjustment.nil?
    XMLHelper.add_element(water_heating_system, "TankVolume", Float(tank_volume)) unless tank_volume.nil?
    XMLHelper.add_element(water_heating_system, "FractionDHWLoadServed", Float(fraction_dhw_load_served))
    XMLHelper.add_element(water_heating_system, "HeatingCapacity", Float(heating_capacity)) unless heating_capacity.nil?
    XMLHelper.add_element(water_heating_system, "EnergyFactor", Float(energy_factor)) unless energy_factor.nil?
    XMLHelper.add_element(water_heating_system, "UniformEnergyFactor", Float(uniform_energy_factor)) unless uniform_energy_factor.nil?
    XMLHelper.add_element(water_heating_system, "RecoveryEfficiency", Float(recovery_efficiency)) unless recovery_efficiency.nil?
    unless jacket_r_value.nil?
      water_heater_insulation = XMLHelper.add_element(water_heating_system, "WaterHeaterInsulation")
      jacket = XMLHelper.add_element(water_heater_insulation, "Jacket")
      XMLHelper.add_element(jacket, "JacketRValue", jacket_r_value)
    end
    XMLHelper.add_element(water_heating_system, "StandbyLoss", Float(standby_loss)) unless standby_loss.nil?
    XMLHelper.add_element(water_heating_system, "HotWaterTemperature", Float(temperature)) unless temperature.nil?
    XMLHelper.add_element(water_heating_system, "UsesDesuperheater", Boolean(uses_desuperheater)) unless uses_desuperheater.nil?
    unless related_hvac.nil?
      related_hvac_el = XMLHelper.add_element(water_heating_system, "RelatedHVACSystem")
      XMLHelper.add_attribute(related_hvac_el, "idref", related_hvac)
    end

    return water_heating_system
  end

  def _get_object_water_heating_systems_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem") do |water_heating_system|
      child_vals = {}
      child_vals[:id] = _get_object_id(water_heating_system)
      child_vals[:year_installed] = _to_integer_or_nil(XMLHelper.get_value(water_heating_system, "YearInstalled"))
      child_vals[:fuel_type] = XMLHelper.get_value(water_heating_system, "FuelType")
      child_vals[:water_heater_type] = XMLHelper.get_value(water_heating_system, "WaterHeaterType")
      child_vals[:location] = XMLHelper.get_value(water_heating_system, "Location")
      child_vals[:performance_adjustment] = _to_float_or_nil(XMLHelper.get_value(water_heating_system, "PerformanceAdjustment"))
      child_vals[:tank_volume] = _to_float_or_nil(XMLHelper.get_value(water_heating_system, "TankVolume"))
      child_vals[:fraction_dhw_load_served] = _to_float_or_nil(XMLHelper.get_value(water_heating_system, "FractionDHWLoadServed"))
      child_vals[:heating_capacity] = _to_float_or_nil(XMLHelper.get_value(water_heating_system, "HeatingCapacity"))
      child_vals[:energy_factor] = _to_float_or_nil(XMLHelper.get_value(water_heating_system, "EnergyFactor"))
      child_vals[:uniform_energy_factor] = _to_float_or_nil(XMLHelper.get_value(water_heating_system, "UniformEnergyFactor"))
      child_vals[:recovery_efficiency] = _to_float_or_nil(XMLHelper.get_value(water_heating_system, "RecoveryEfficiency"))
      child_vals[:uses_desuperheater] = _to_bool_or_nil(XMLHelper.get_value(water_heating_system, "UsesDesuperheater"))
      child_vals[:jacket_r_value] = _to_float_or_nil(XMLHelper.get_value(water_heating_system, "WaterHeaterInsulation/Jacket/JacketRValue"))
      child_vals[:related_hvac] = _get_object_idref(water_heating_system, "RelatedHVACSystem")
      child_vals[:energy_star] = XMLHelper.get_values(water_heating_system, "ThirdPartyCertification").include?("Energy Star")
      child_vals[:standby_loss] = _to_float_or_nil(XMLHelper.get_value(water_heating_system, "StandbyLoss"))
      child_vals[:temperature] = _to_float_or_nil(XMLHelper.get_value(water_heating_system, "HotWaterTemperature"))
      vals << child_vals
    end
    return vals
  end

  def _add_object_hot_water_distribution(id:,
                                         system_type:,
                                         pipe_r_value:,
                                         standard_piping_length: nil,
                                         recirculation_control_type: nil,
                                         recirculation_piping_length: nil,
                                         recirculation_branch_piping_length: nil,
                                         recirculation_pump_power: nil,
                                         dwhr_facilities_connected: nil,
                                         dwhr_equal_flow: nil,
                                         dwhr_efficiency: nil)
    water_heating = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Systems", "WaterHeating"])
    hot_water_distribution = XMLHelper.add_element(water_heating, "HotWaterDistribution")
    sys_id = XMLHelper.add_element(hot_water_distribution, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    system_type_e = XMLHelper.add_element(hot_water_distribution, "SystemType")
    if system_type == "Standard"
      standard = XMLHelper.add_element(system_type_e, system_type)
      XMLHelper.add_element(standard, "PipingLength", Float(standard_piping_length))
    elsif system_type == "Recirculation"
      recirculation = XMLHelper.add_element(system_type_e, system_type)
      XMLHelper.add_element(recirculation, "ControlType", recirculation_control_type)
      XMLHelper.add_element(recirculation, "RecirculationPipingLoopLength", Float(recirculation_piping_length))
      XMLHelper.add_element(recirculation, "BranchPipingLoopLength", Float(recirculation_branch_piping_length))
      XMLHelper.add_element(recirculation, "PumpPower", Float(recirculation_pump_power))
    else
      fail "Unhandled hot water distribution type '#{system_type}'."
    end
    pipe_insulation = XMLHelper.add_element(hot_water_distribution, "PipeInsulation")
    XMLHelper.add_element(pipe_insulation, "PipeRValue", Float(pipe_r_value))
    if not dwhr_facilities_connected.nil? or not dwhr_equal_flow.nil? or not dwhr_efficiency.nil?
      drain_water_heat_recovery = XMLHelper.add_element(hot_water_distribution, "DrainWaterHeatRecovery")
      XMLHelper.add_element(drain_water_heat_recovery, "FacilitiesConnected", dwhr_facilities_connected)
      XMLHelper.add_element(drain_water_heat_recovery, "EqualFlow", Boolean(dwhr_equal_flow))
      XMLHelper.add_element(drain_water_heat_recovery, "Efficiency", Float(dwhr_efficiency))
    end

    return hot_water_distribution
  end

  def _get_object_hot_water_distribution_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    hot_water_distribution = hpxml.elements["Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution"]
    return vals if hot_water_distribution.nil?

    vals[:id] = _get_object_id(hot_water_distribution)
    vals[:system_type] = XMLHelper.get_child_name(hot_water_distribution, "SystemType")
    vals[:pipe_r_value] = _to_float_or_nil(XMLHelper.get_value(hot_water_distribution, "PipeInsulation/PipeRValue"))
    vals[:standard_piping_length] = _to_float_or_nil(XMLHelper.get_value(hot_water_distribution, "SystemType/Standard/PipingLength"))
    vals[:recirculation_control_type] = XMLHelper.get_value(hot_water_distribution, "SystemType/Recirculation/ControlType")
    vals[:recirculation_piping_length] = _to_float_or_nil(XMLHelper.get_value(hot_water_distribution, "SystemType/Recirculation/RecirculationPipingLoopLength"))
    vals[:recirculation_branch_piping_length] = _to_float_or_nil(XMLHelper.get_value(hot_water_distribution, "SystemType/Recirculation/BranchPipingLoopLength"))
    vals[:recirculation_pump_power] = _to_float_or_nil(XMLHelper.get_value(hot_water_distribution, "SystemType/Recirculation/PumpPower"))
    vals[:dwhr_facilities_connected] = XMLHelper.get_value(hot_water_distribution, "DrainWaterHeatRecovery/FacilitiesConnected")
    vals[:dwhr_equal_flow] = _to_bool_or_nil(XMLHelper.get_value(hot_water_distribution, "DrainWaterHeatRecovery/EqualFlow"))
    vals[:dwhr_efficiency] = _to_float_or_nil(XMLHelper.get_value(hot_water_distribution, "DrainWaterHeatRecovery/Efficiency"))
    return vals
  end

  def _add_object_water_fixture(id:,
                                water_fixture_type:,
                                low_flow:)
    water_heating = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Systems", "WaterHeating"])
    water_fixture = XMLHelper.add_element(water_heating, "WaterFixture")
    sys_id = XMLHelper.add_element(water_fixture, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(water_fixture, "WaterFixtureType", water_fixture_type)
    XMLHelper.add_element(water_fixture, "LowFlow", Boolean(low_flow))

    return water_fixture
  end

  def _get_object_water_fixtures_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("BuildingDetails/Systems/WaterHeating/WaterFixture") do |water_fixture|
      child_vals = {}
      child_vals[:id] = _get_object_id(water_fixture)
      child_vals[:water_fixture_type] = XMLHelper.get_value(water_fixture, "WaterFixtureType")
      child_vals[:low_flow] = _to_bool_or_nil(XMLHelper.get_value(water_fixture, "LowFlow"))
      vals << child_vals
    end
    return vals
  end

  def _add_object_solar_thermal_system(id:,
                                       system_type:,
                                       collector_area: nil,
                                       collector_loop_type: nil,
                                       collector_azimuth: nil,
                                       collector_type: nil,
                                       collector_tilt: nil,
                                       collector_frta: nil,
                                       collector_frul: nil,
                                       storage_volume: nil,
                                       water_heating_system_idref:,
                                       solar_fraction: nil)

    solar_thermal = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Systems", "SolarThermal"])
    solar_thermal_system = XMLHelper.add_element(solar_thermal, "SolarThermalSystem")
    sys_id = XMLHelper.add_element(solar_thermal_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(solar_thermal_system, "SystemType", system_type)
    XMLHelper.add_element(solar_thermal_system, "CollectorArea", Float(collector_area)) unless collector_area.nil?
    XMLHelper.add_element(solar_thermal_system, "CollectorLoopType", collector_loop_type) unless collector_loop_type.nil?
    XMLHelper.add_element(solar_thermal_system, "CollectorType", collector_type) unless collector_type.nil?
    XMLHelper.add_element(solar_thermal_system, "CollectorAzimuth", Integer(collector_azimuth)) unless collector_azimuth.nil?
    XMLHelper.add_element(solar_thermal_system, "CollectorTilt", Float(collector_tilt)) unless collector_tilt.nil?
    XMLHelper.add_element(solar_thermal_system, "CollectorRatedOpticalEfficiency", Float(collector_frta)) unless collector_frta.nil?
    XMLHelper.add_element(solar_thermal_system, "CollectorRatedThermalLosses", Float(collector_frul)) unless collector_frul.nil?
    XMLHelper.add_element(solar_thermal_system, "StorageVolume", Float(storage_volume)) unless storage_volume.nil?
    connected_to = XMLHelper.add_element(solar_thermal_system, "ConnectedTo")
    XMLHelper.add_attribute(connected_to, "idref", water_heating_system_idref)
    XMLHelper.add_element(solar_thermal_system, "SolarFraction", Float(solar_fraction)) unless solar_fraction.nil?

    return solar_thermal_system
  end

  def _get_object_solar_thermal_system_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    solar_thermal_system = hpxml.elements["Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem"]
    return vals if solar_thermal_system.nil?

    vals[:id] = _get_object_id(solar_thermal_system)
    vals[:system_type] = XMLHelper.get_value(solar_thermal_system, "SystemType")
    vals[:collector_area] = _to_float_or_nil(XMLHelper.get_value(solar_thermal_system, "CollectorArea"))
    vals[:collector_loop_type] = XMLHelper.get_value(solar_thermal_system, "CollectorLoopType")
    vals[:collector_azimuth] = _to_integer_or_nil(XMLHelper.get_value(solar_thermal_system, "CollectorAzimuth"))
    vals[:collector_type] = XMLHelper.get_value(solar_thermal_system, "CollectorType")
    vals[:collector_tilt] = _to_float_or_nil(XMLHelper.get_value(solar_thermal_system, "CollectorTilt"))
    vals[:collector_frta] = _to_float_or_nil(XMLHelper.get_value(solar_thermal_system, "CollectorRatedOpticalEfficiency"))
    vals[:collector_frul] = _to_float_or_nil(XMLHelper.get_value(solar_thermal_system, "CollectorRatedThermalLosses"))
    vals[:storage_volume] = _to_float_or_nil(XMLHelper.get_value(solar_thermal_system, "StorageVolume"))
    vals[:water_heating_system_idref] = _get_object_idref(solar_thermal_system, "ConnectedTo")
    vals[:solar_fraction] = _to_float_or_nil(XMLHelper.get_value(solar_thermal_system, "SolarFraction"))
    return vals
  end

  def _add_object_pv_system(id:,
                            location:,
                            module_type:,
                            tracking:,
                            array_azimuth:,
                            array_tilt:,
                            max_power_output:,
                            inverter_efficiency:,
                            system_losses_fraction:)
    photovoltaics = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Systems", "Photovoltaics"])
    pv_system = XMLHelper.add_element(photovoltaics, "PVSystem")
    sys_id = XMLHelper.add_element(pv_system, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(pv_system, "Location", location)
    XMLHelper.add_element(pv_system, "ModuleType", module_type)
    XMLHelper.add_element(pv_system, "Tracking", tracking)
    XMLHelper.add_element(pv_system, "ArrayAzimuth", Integer(array_azimuth))
    XMLHelper.add_element(pv_system, "ArrayTilt", Float(array_tilt))
    XMLHelper.add_element(pv_system, "MaxPowerOutput", Float(max_power_output))
    XMLHelper.add_element(pv_system, "InverterEfficiency", Float(inverter_efficiency))
    XMLHelper.add_element(pv_system, "SystemLossesFraction", Float(system_losses_fraction))

    return pv_system
  end

  def _get_object_pv_systems_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Systems/Photovoltaics/PVSystem") do |pv_system|
      child_vals = {}
      child_vals[:id] = _get_object_id(pv_system)
      child_vals[:location] = XMLHelper.get_value(pv_system, "Location")
      child_vals[:module_type] = XMLHelper.get_value(pv_system, "ModuleType")
      child_vals[:tracking] = XMLHelper.get_value(pv_system, "Tracking")
      child_vals[:array_orientation] = XMLHelper.get_value(pv_system, "ArrayOrientation")
      child_vals[:array_azimuth] = _to_integer_or_nil(XMLHelper.get_value(pv_system, "ArrayAzimuth"))
      child_vals[:array_tilt] = _to_float_or_nil(XMLHelper.get_value(pv_system, "ArrayTilt"))
      child_vals[:max_power_output] = _to_float_or_nil(XMLHelper.get_value(pv_system, "MaxPowerOutput"))
      child_vals[:inverter_efficiency] = _to_float_or_nil(XMLHelper.get_value(pv_system, "InverterEfficiency"))
      child_vals[:system_losses_fraction] = _to_float_or_nil(XMLHelper.get_value(pv_system, "SystemLossesFraction"))
      child_vals[:number_of_panels] = _to_integer_or_nil(XMLHelper.get_value(pv_system, "NumberOfPanels"))
      child_vals[:year_modules_manufactured] = _to_integer_or_nil(XMLHelper.get_value(pv_system, "YearModulesManufactured"))
      vals << child_vals
    end
    return vals
  end

  def _add_object_clothes_washer(id:,
                                 location:,
                                 modified_energy_factor: nil,
                                 integrated_modified_energy_factor: nil,
                                 rated_annual_kwh:,
                                 label_electric_rate:,
                                 label_gas_rate:,
                                 label_annual_gas_cost:,
                                 capacity:)
    appliances = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Appliances"])
    clothes_washer = XMLHelper.add_element(appliances, "ClothesWasher")
    sys_id = XMLHelper.add_element(clothes_washer, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(clothes_washer, "Location", location)
    if not modified_energy_factor.nil?
      XMLHelper.add_element(clothes_washer, "ModifiedEnergyFactor", Float(modified_energy_factor))
    elsif not integrated_modified_energy_factor.nil?
      XMLHelper.add_element(clothes_washer, "IntegratedModifiedEnergyFactor", Float(integrated_modified_energy_factor))
    else
      fail "Either modified_energy_factor or integrated_modified_energy_factor must be provided."
    end
    XMLHelper.add_element(clothes_washer, "RatedAnnualkWh", Float(rated_annual_kwh))
    XMLHelper.add_element(clothes_washer, "LabelElectricRate", Float(label_electric_rate))
    XMLHelper.add_element(clothes_washer, "LabelGasRate", Float(label_gas_rate))
    XMLHelper.add_element(clothes_washer, "LabelAnnualGasCost", Float(label_annual_gas_cost))
    XMLHelper.add_element(clothes_washer, "Capacity", Float(capacity))

    return clothes_washer
  end

  def _get_object_clothes_washer_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    clothes_washer = hpxml.elements["Building/BuildingDetails/Appliances/ClothesWasher"]
    return vals if clothes_washer.nil?

    vals[:id] = _get_object_id(clothes_washer)
    vals[:location] = XMLHelper.get_value(clothes_washer, "Location")
    vals[:modified_energy_factor] = _to_float_or_nil(XMLHelper.get_value(clothes_washer, "ModifiedEnergyFactor"))
    vals[:integrated_modified_energy_factor] = _to_float_or_nil(XMLHelper.get_value(clothes_washer, "IntegratedModifiedEnergyFactor"))
    vals[:rated_annual_kwh] = _to_float_or_nil(XMLHelper.get_value(clothes_washer, "RatedAnnualkWh"))
    vals[:label_electric_rate] = _to_float_or_nil(XMLHelper.get_value(clothes_washer, "LabelElectricRate"))
    vals[:label_gas_rate] = _to_float_or_nil(XMLHelper.get_value(clothes_washer, "LabelGasRate"))
    vals[:label_annual_gas_cost] = _to_float_or_nil(XMLHelper.get_value(clothes_washer, "LabelAnnualGasCost"))
    vals[:capacity] = _to_float_or_nil(XMLHelper.get_value(clothes_washer, "Capacity"))
    return vals
  end

  def _add_object_clothes_dryer(id:,
                                location:,
                                fuel_type:,
                                energy_factor: nil,
                                combined_energy_factor: nil,
                                control_type:)
    appliances = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Appliances"])
    clothes_dryer = XMLHelper.add_element(appliances, "ClothesDryer")
    sys_id = XMLHelper.add_element(clothes_dryer, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(clothes_dryer, "Location", location)
    XMLHelper.add_element(clothes_dryer, "FuelType", fuel_type)
    if not energy_factor.nil?
      XMLHelper.add_element(clothes_dryer, "EnergyFactor", Float(energy_factor))
    elsif not combined_energy_factor.nil?
      XMLHelper.add_element(clothes_dryer, "CombinedEnergyFactor", Float(combined_energy_factor))
    else
      fail "Either energy_factor or combined_energy_factor must be provided."
    end
    XMLHelper.add_element(clothes_dryer, "ControlType", control_type)

    return clothes_dryer
  end

  def _get_object_clothes_dryer_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    clothes_dryer = hpxml.elements["Building/BuildingDetails/Appliances/ClothesDryer"]
    return vals if clothes_dryer.nil?

    vals[:id] = _get_object_id(clothes_dryer)
    vals[:location] = XMLHelper.get_value(clothes_dryer, "Location")
    vals[:fuel_type] = XMLHelper.get_value(clothes_dryer, "FuelType")
    vals[:energy_factor] = _to_float_or_nil(XMLHelper.get_value(clothes_dryer, "EnergyFactor"))
    vals[:combined_energy_factor] = _to_float_or_nil(XMLHelper.get_value(clothes_dryer, "CombinedEnergyFactor"))
    vals[:control_type] = XMLHelper.get_value(clothes_dryer, "ControlType")
    return vals
  end

  def _add_object_dishwasher(id:,
                             energy_factor: nil,
                             rated_annual_kwh: nil,
                             place_setting_capacity:)
    appliances = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Appliances"])
    dishwasher = XMLHelper.add_element(appliances, "Dishwasher")
    sys_id = XMLHelper.add_element(dishwasher, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    if not energy_factor.nil?
      XMLHelper.add_element(dishwasher, "EnergyFactor", Float(energy_factor))
    elsif not rated_annual_kwh.nil?
      XMLHelper.add_element(dishwasher, "RatedAnnualkWh", Float(rated_annual_kwh))
    else
      fail "Either energy_factor or rated_annual_kwh must be provided."
    end
    XMLHelper.add_element(dishwasher, "PlaceSettingCapacity", Integer(place_setting_capacity)) unless place_setting_capacity.nil?

    return dishwasher
  end

  def _get_object_dishwasher_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    dishwasher = hpxml.elements["Building/BuildingDetails/Appliances/Dishwasher"]
    return vals if dishwasher.nil?

    vals[:id] = _get_object_id(dishwasher)
    vals[:energy_factor] = _to_float_or_nil(XMLHelper.get_value(dishwasher, "EnergyFactor"))
    vals[:rated_annual_kwh] = _to_float_or_nil(XMLHelper.get_value(dishwasher, "RatedAnnualkWh"))
    vals[:place_setting_capacity] = _to_integer_or_nil(XMLHelper.get_value(dishwasher, "PlaceSettingCapacity"))
    return vals
  end

  def _add_object_refrigerator(id:,
                               location:,
                               rated_annual_kwh: nil,
                               adjusted_annual_kwh: nil)
    appliances = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Appliances"])
    refrigerator = XMLHelper.add_element(appliances, "Refrigerator")
    sys_id = XMLHelper.add_element(refrigerator, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(refrigerator, "Location", location)
    XMLHelper.add_element(refrigerator, "RatedAnnualkWh", Float(rated_annual_kwh)) unless rated_annual_kwh.nil?
    _add_object_extension(parent: refrigerator,
                          extensions: { "AdjustedAnnualkWh" => _to_float_or_nil(adjusted_annual_kwh) })

    return refrigerator
  end

  def _get_object_refrigerator_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    refrigerator = hpxml.elements["Building/BuildingDetails/Appliances/Refrigerator"]
    return vals if refrigerator.nil?

    vals[:id] = _get_object_id(refrigerator)
    vals[:location] = XMLHelper.get_value(refrigerator, "Location")
    vals[:rated_annual_kwh] = _to_float_or_nil(XMLHelper.get_value(refrigerator, "RatedAnnualkWh"))
    vals[:adjusted_annual_kwh] = _to_float_or_nil(XMLHelper.get_value(refrigerator, "extension/AdjustedAnnualkWh"))
    return vals
  end

  def _add_object_cooking_range(id:,
                                fuel_type:,
                                is_induction:)
    appliances = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Appliances"])
    cooking_range = XMLHelper.add_element(appliances, "CookingRange")
    sys_id = XMLHelper.add_element(cooking_range, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(cooking_range, "FuelType", fuel_type)
    XMLHelper.add_element(cooking_range, "IsInduction", Boolean(is_induction))

    return cooking_range
  end

  def _get_object_cooking_range_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    cooking_range = hpxml.elements["Building/BuildingDetails/Appliances/CookingRange"]
    return vals if cooking_range.nil?

    vals[:id] = _get_object_id(cooking_range)
    vals[:fuel_type] = XMLHelper.get_value(cooking_range, "FuelType")
    vals[:is_induction] = _to_bool_or_nil(XMLHelper.get_value(cooking_range, "IsInduction"))
    return vals
  end

  def _add_object_oven(id:,
                       is_convection:)
    appliances = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Appliances"])
    oven = XMLHelper.add_element(appliances, "Oven")
    sys_id = XMLHelper.add_element(oven, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(oven, "IsConvection", Boolean(is_convection))

    return oven
  end

  def _get_object_oven_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    oven = hpxml.elements["Building/BuildingDetails/Appliances/Oven"]
    return vals if oven.nil?

    vals[:id] = _get_object_id(oven)
    vals[:is_convection] = _to_bool_or_nil(XMLHelper.get_value(oven, "IsConvection"))
    return vals
  end

  def _add_object_lighting(fraction_tier_i_interior:,
                           fraction_tier_i_exterior:,
                           fraction_tier_i_garage:,
                           fraction_tier_ii_interior:,
                           fraction_tier_ii_exterior:,
                           fraction_tier_ii_garage:)
    lighting = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Lighting"])

    lighting_group = XMLHelper.add_element(lighting, "LightingGroup")
    sys_id = XMLHelper.add_element(lighting_group, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Lighting_TierI_Interior")
    XMLHelper.add_element(lighting_group, "Location", "interior")
    XMLHelper.add_element(lighting_group, "FractionofUnitsInLocation", Float(fraction_tier_i_interior))
    XMLHelper.add_element(lighting_group, "ThirdPartyCertification", "ERI Tier I")

    lighting_group = XMLHelper.add_element(lighting, "LightingGroup")
    sys_id = XMLHelper.add_element(lighting_group, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Lighting_TierI_Exterior")
    XMLHelper.add_element(lighting_group, "Location", "exterior")
    XMLHelper.add_element(lighting_group, "FractionofUnitsInLocation", Float(fraction_tier_i_exterior))
    XMLHelper.add_element(lighting_group, "ThirdPartyCertification", "ERI Tier I")

    lighting_group = XMLHelper.add_element(lighting, "LightingGroup")
    sys_id = XMLHelper.add_element(lighting_group, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Lighting_TierI_Garage")
    XMLHelper.add_element(lighting_group, "Location", "garage")
    XMLHelper.add_element(lighting_group, "FractionofUnitsInLocation", Float(fraction_tier_i_garage))
    XMLHelper.add_element(lighting_group, "ThirdPartyCertification", "ERI Tier I")

    lighting_group = XMLHelper.add_element(lighting, "LightingGroup")
    sys_id = XMLHelper.add_element(lighting_group, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Lighting_TierII_Interior")
    XMLHelper.add_element(lighting_group, "Location", "interior")
    XMLHelper.add_element(lighting_group, "FractionofUnitsInLocation", Float(fraction_tier_ii_interior))
    XMLHelper.add_element(lighting_group, "ThirdPartyCertification", "ERI Tier II")

    lighting_group = XMLHelper.add_element(lighting, "LightingGroup")
    sys_id = XMLHelper.add_element(lighting_group, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Lighting_TierII_Exterior")
    XMLHelper.add_element(lighting_group, "Location", "exterior")
    XMLHelper.add_element(lighting_group, "FractionofUnitsInLocation", Float(fraction_tier_ii_exterior))
    XMLHelper.add_element(lighting_group, "ThirdPartyCertification", "ERI Tier II")

    lighting_group = XMLHelper.add_element(lighting, "LightingGroup")
    sys_id = XMLHelper.add_element(lighting_group, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Lighting_TierII_Garage")
    XMLHelper.add_element(lighting_group, "Location", "garage")
    XMLHelper.add_element(lighting_group, "FractionofUnitsInLocation", Float(fraction_tier_ii_garage))
    XMLHelper.add_element(lighting_group, "ThirdPartyCertification", "ERI Tier II")

    return lighting_group
  end

  def _get_object_lighting_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    lighting = hpxml.elements["Building/BuildingDetails/Lighting"]
    return vals if lighting.nil?

    vals[:fraction_tier_i_interior] = _to_float_or_nil(XMLHelper.get_value(lighting, "LightingGroup[ThirdPartyCertification='ERI Tier I' and Location='interior']/FractionofUnitsInLocation"))
    vals[:fraction_tier_i_exterior] = _to_float_or_nil(XMLHelper.get_value(lighting, "LightingGroup[ThirdPartyCertification='ERI Tier I' and Location='exterior']/FractionofUnitsInLocation"))
    vals[:fraction_tier_i_garage] = _to_float_or_nil(XMLHelper.get_value(lighting, "LightingGroup[ThirdPartyCertification='ERI Tier I' and Location='garage']/FractionofUnitsInLocation"))
    vals[:fraction_tier_ii_interior] = _to_float_or_nil(XMLHelper.get_value(lighting, "LightingGroup[ThirdPartyCertification='ERI Tier II' and Location='interior']/FractionofUnitsInLocation"))
    vals[:fraction_tier_ii_exterior] = _to_float_or_nil(XMLHelper.get_value(lighting, "LightingGroup[ThirdPartyCertification='ERI Tier II' and Location='exterior']/FractionofUnitsInLocation"))
    vals[:fraction_tier_ii_garage] = _to_float_or_nil(XMLHelper.get_value(lighting, "LightingGroup[ThirdPartyCertification='ERI Tier II' and Location='garage']/FractionofUnitsInLocation"))
    return vals
  end

  def _add_object_ceiling_fan(id:,
                              efficiency: nil,
                              quantity: nil)
    lighting = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "Lighting"])
    ceiling_fan = XMLHelper.add_element(lighting, "CeilingFan")
    sys_id = XMLHelper.add_element(ceiling_fan, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    if not efficiency.nil?
      airflow = XMLHelper.add_element(ceiling_fan, "Airflow")
      XMLHelper.add_element(airflow, "FanSpeed", "medium")
      XMLHelper.add_element(airflow, "Efficiency", Float(efficiency))
    end
    XMLHelper.add_element(ceiling_fan, "Quantity", Integer(quantity)) unless quantity.nil?

    return ceiling_fan
  end

  def _get_object_ceiling_fans_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/Lighting/CeilingFan") do |ceiling_fan|
      child_vals = {}
      child_vals[:id] = _get_object_id(ceiling_fan)
      child_vals[:efficiency] = _to_float_or_nil(XMLHelper.get_value(ceiling_fan, "Airflow[FanSpeed='medium']/Efficiency"))
      child_vals[:quantity] = _to_integer_or_nil(XMLHelper.get_value(ceiling_fan, "Quantity"))
      vals << child_vals
    end
    return vals
  end

  def _add_object_plug_load(id:,
                            plug_load_type: nil,
                            kWh_per_year: nil,
                            frac_sensible: nil,
                            frac_latent: nil)
    misc_loads = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "MiscLoads"])
    plug_load = XMLHelper.add_element(misc_loads, "PlugLoad")
    sys_id = XMLHelper.add_element(plug_load, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", id)
    XMLHelper.add_element(plug_load, "PlugLoadType", plug_load_type) unless plug_load_type.nil?
    if not kWh_per_year.nil?
      load = XMLHelper.add_element(plug_load, "Load")
      XMLHelper.add_element(load, "Units", "kWh/year")
      XMLHelper.add_element(load, "Value", Float(kWh_per_year))
    end
    _add_object_extension(parent: plug_load,
                          extensions: { "FracSensible" => _to_float_or_nil(frac_sensible),
                                        "FracLatent" => _to_float_or_nil(frac_latent) })

    return plug_load
  end

  def _get_object_plug_loads_values(hpxml:)
    vals = []
    return vals if hpxml.nil?

    hpxml.elements.each("Building/BuildingDetails/MiscLoads/PlugLoad") do |plug_load|
      child_vals = {}
      child_vals[:id] = _get_object_id(plug_load)
      child_vals[:plug_load_type] = XMLHelper.get_value(plug_load, "PlugLoadType")
      child_vals[:kWh_per_year] = _to_float_or_nil(XMLHelper.get_value(plug_load, "Load[Units='kWh/year']/Value"))
      child_vals[:frac_sensible] = _to_float_or_nil(XMLHelper.get_value(plug_load, "extension/FracSensible"))
      child_vals[:frac_latent] = _to_float_or_nil(XMLHelper.get_value(plug_load, "extension/FracLatent"))
      vals << child_vals
    end
    return vals
  end

  def _add_object_misc_loads_schedule(weekday_fractions: nil,
                                      weekend_fractions: nil,
                                      monthly_multipliers: nil)
    misc_loads = XMLHelper.create_elements_as_needed(@object, ["HPXML", "Building", "BuildingDetails", "MiscLoads"])
    _add_object_extension(parent: misc_loads,
                          extensions: { "WeekdayScheduleFractions" => weekday_fractions,
                                        "WeekendScheduleFractions" => weekend_fractions,
                                        "MonthlyScheduleMultipliers" => monthly_multipliers })

    return misc_loads
  end

  def _get_object_misc_loads_schedule_values(hpxml:)
    vals = {}
    return vals if hpxml.nil?

    misc_loads = hpxml.elements["Building/BuildingDetails/MiscLoads"]
    return vals if misc_loads.nil?

    vals[:weekday_fractions] = XMLHelper.get_value(misc_loads, "extension/WeekdayScheduleFractions")
    vals[:weekend_fractions] = XMLHelper.get_value(misc_loads, "extension/WeekendScheduleFractions")
    vals[:monthly_multipliers] = XMLHelper.get_value(misc_loads, "extension/MonthlyScheduleMultipliers")
    return vals
  end

  def _add_object_extension(parent:,
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

  def _get_object_id(parent, element_name = "SystemIdentifier")
    return parent.elements[element_name].attributes["id"]
  end

  def _get_object_idref(parent, element_name)
    element = parent.elements[element_name]
    return if element.nil?

    return element.attributes["idref"]
  end

  def _to_float_or_nil(value)
    return nil if value.nil?

    return Float(value)
  end

  def _to_integer_or_nil(value)
    return nil if value.nil?

    return Integer(Float(value))
  end

  def _to_bool_or_nil(value)
    return nil if value.nil?

    return Boolean(value)
  end
end

# Helper methods

def is_thermal_boundary(surface_values)
  if ["other housing unit", "other housing unit above", "other housing unit below"].include? surface_values[:exterior_adjacent_to]
    return false # adiabatic
  end

  interior_conditioned = is_adjacent_to_conditioned(surface_values[:interior_adjacent_to])
  exterior_conditioned = is_adjacent_to_conditioned(surface_values[:exterior_adjacent_to])
  return (interior_conditioned != exterior_conditioned)
end

def is_adjacent_to_conditioned(adjacent_to)
  if ["living space", "basement - conditioned"].include? adjacent_to
    return true
  end

  return false
end

def hpxml_frame_floor_is_ceiling(floor_interior_adjacent_to, floor_exterior_adjacent_to)
  if ["attic - vented", "attic - unvented"].include? floor_interior_adjacent_to
    return true
  elsif ["attic - vented", "attic - unvented", "other housing unit above"].include? floor_exterior_adjacent_to
    return true
  end

  return false
end
