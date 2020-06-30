# frozen_string_literal: true

class HEScoreRuleset
  def self.apply_ruleset(orig_hpxml)
    # Create new HPXML object
    new_hpxml = HPXML.new
    new_hpxml.header.xml_type = orig_hpxml.header.xml_type
    new_hpxml.header.xml_generated_by = 'OpenStudio-HEScore'
    new_hpxml.header.transaction = orig_hpxml.header.transaction
    new_hpxml.header.building_id = orig_hpxml.header.building_id
    new_hpxml.header.event_type = orig_hpxml.header.event_type

    # BuildingSummary
    set_summary(orig_hpxml, new_hpxml)

    # ClimateAndRiskZones
    set_climate(orig_hpxml, new_hpxml)

    # Enclosure
    set_enclosure_air_infiltration(orig_hpxml, new_hpxml)
    set_enclosure_roofs(orig_hpxml, new_hpxml)
    set_enclosure_rim_joists(orig_hpxml, new_hpxml)
    set_enclosure_walls(orig_hpxml, new_hpxml)
    set_enclosure_foundation_walls(orig_hpxml, new_hpxml)
    set_enclosure_framefloors(orig_hpxml, new_hpxml)
    set_enclosure_slabs(orig_hpxml, new_hpxml)
    set_enclosure_windows(orig_hpxml, new_hpxml)
    set_enclosure_skylights(orig_hpxml, new_hpxml)
    set_enclosure_doors(orig_hpxml, new_hpxml)

    # Systems
    set_systems_hvac(orig_hpxml, new_hpxml)
    set_systems_mechanical_ventilation(orig_hpxml, new_hpxml)
    set_systems_water_heater(orig_hpxml, new_hpxml)
    set_systems_water_heating_use(orig_hpxml, new_hpxml)
    set_systems_photovoltaics(orig_hpxml, new_hpxml)

    # Appliances
    set_appliances_clothes_washer(orig_hpxml, new_hpxml)
    set_appliances_clothes_dryer(orig_hpxml, new_hpxml)
    set_appliances_dishwasher(orig_hpxml, new_hpxml)
    set_appliances_refrigerator(orig_hpxml, new_hpxml)
    set_appliances_cooking_range_oven(orig_hpxml, new_hpxml)

    # Lighting
    set_lighting(orig_hpxml, new_hpxml)
    set_ceiling_fans(orig_hpxml, new_hpxml)

    # MiscLoads
    set_misc_plug_loads(orig_hpxml, new_hpxml)
    set_misc_television(orig_hpxml, new_hpxml)

    return new_hpxml
  end

  def self.set_summary(orig_hpxml, new_hpxml)
    # Get HPXML values
    @bldg_orient = orig_hpxml.site.orientation_of_front_of_home
    @bldg_azimuth = orientation_to_azimuth(@bldg_orient)

    @year_built = orig_hpxml.building_construction.year_built
    @nbeds = orig_hpxml.building_construction.number_of_bedrooms
    @cfa = orig_hpxml.building_construction.conditioned_floor_area # ft^2
    @is_townhouse = (orig_hpxml.building_construction.residential_facility_type == HPXML::ResidentialTypeSFA)
    @fnd_areas = get_foundation_areas(orig_hpxml)
    @ducts = get_ducts_details(orig_hpxml)
    @cfa_basement = @fnd_areas[HPXML::LocationBasementConditioned]
    @cfa_basement = 0 if @cfa_basement.nil?
    @ncfl_ag = orig_hpxml.building_construction.number_of_conditioned_floors_above_grade
    @ceil_height = orig_hpxml.building_construction.average_ceiling_height # ft

    # Calculate geometry
    @has_cond_bsmnt = @fnd_areas.key?(HPXML::LocationBasementConditioned)
    @has_uncond_bsmnt = @fnd_areas.key?(HPXML::LocationBasementUnconditioned)
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
    @roof_angle_rad = UnitConversions.convert(@roof_angle, 'deg', 'rad') # radians
    @cvolume = calc_conditioned_volume(orig_hpxml)

    new_hpxml.site.fuels = [HPXML::FuelTypeElectricity] # TODO Check if changing this would ever influence results; if it does, talk to Leo
    new_hpxml.site.shelter_coefficient = Airflow.get_default_shelter_coefficient()

    # Neighboring buildings to left/right, 12ft offset, same height as building.
    # FIXME: Verify. What about townhouses?
    new_hpxml.neighbor_buildings.add(azimuth: sanitize_azimuth(@bldg_azimuth + 90.0),
                                     distance: 20.0,
                                     height: 12.0)
    new_hpxml.neighbor_buildings.add(azimuth: sanitize_azimuth(@bldg_azimuth - 90.0),
                                     distance: 20.0,
                                     height: 12.0)

    new_hpxml.building_occupancy.number_of_residents = Geometry.get_occupancy_default_num(@nbeds)

    new_hpxml.building_construction.number_of_conditioned_floors = @ncfl
    new_hpxml.building_construction.number_of_conditioned_floors_above_grade = @ncfl_ag
    new_hpxml.building_construction.number_of_bedrooms = @nbeds
    new_hpxml.building_construction.conditioned_floor_area = @cfa
    new_hpxml.building_construction.conditioned_building_volume = @cvolume
  end

  def self.set_climate(orig_hpxml, new_hpxml)
    new_hpxml.climate_and_risk_zones.weather_station_id = orig_hpxml.climate_and_risk_zones.weather_station_id
    new_hpxml.climate_and_risk_zones.weather_station_name = orig_hpxml.climate_and_risk_zones.weather_station_name
    new_hpxml.climate_and_risk_zones.weather_station_wmo = orig_hpxml.climate_and_risk_zones.weather_station_wmo
    @iecc_zone = orig_hpxml.climate_and_risk_zones.iecc_zone
  end

  def self.set_enclosure_air_infiltration(orig_hpxml, new_hpxml)
    orig_hpxml.air_infiltration_measurements.each do |orig_infil_measurement|
      cfm50 = orig_infil_measurement.air_leakage
      desc = orig_infil_measurement.leakiness_description

      # Convert to ACH50
      if not cfm50.nil?
        ach50 = cfm50 * 60.0 / @cvolume
      else
        ach50 = calc_ach50(@ncfl_ag, @cfa, @ceil_height, @cvolume, desc, @year_built, @iecc_zone, @fnd_areas, @ducts)
      end

      new_hpxml.air_infiltration_measurements.add(id: orig_infil_measurement.id,
                                                  house_pressure: 50,
                                                  unit_of_measure: HPXML::UnitsACH,
                                                  air_leakage: ach50)
    end
  end

  def self.set_enclosure_roofs(orig_hpxml, new_hpxml)
    orig_hpxml.attics.each do |orig_attic|
      attic_location = orig_attic.to_location

      orig_attic.attached_roofs.each do |orig_roof|
        # Roof: Two surfaces per HES zone_roof
        roof_area = orig_roof.area
        roof_solar_abs = orig_roof.solar_absorptance
        if roof_solar_abs.nil?
          roof_solar_abs = get_roof_solar_absorptance(orig_roof.roof_color)
        end
        roof_r = get_roof_assembly_r(orig_roof.insulation_cavity_r_value,
                                     orig_roof.insulation_continuous_r_value,
                                     orig_roof.roof_type,
                                     orig_roof.radiant_barrier)
        if roof_area.nil?
          orig_attic.attached_frame_floors.each do |orig_frame_floor|
            roof_area = orig_frame_floor.area / (2. * Math.cos(@roof_angle_rad))
          end
        end
        if @is_townhouse
          roof_azimuths = [@bldg_azimuth + 90, @bldg_azimuth + 270]
        else
          roof_azimuths = [@bldg_azimuth, @bldg_azimuth + 180]
        end
        roof_azimuths.each_with_index do |roof_azimuth, idx|
          new_hpxml.roofs.add(id: "#{orig_roof.id}_#{idx}",
                              interior_adjacent_to: attic_location,
                              area: roof_area / 2.0,
                              azimuth: sanitize_azimuth(roof_azimuth),
                              solar_absorptance: roof_solar_abs,
                              emittance: 0.9,
                              pitch: Math.tan(@roof_angle_rad) * 12,
                              radiant_barrier: false,
                              insulation_assembly_r_value: roof_r)
        end
      end
    end
  end

  def self.set_enclosure_rim_joists(orig_hpxml, new_hpxml)
    # No rim joists
  end

  def self.set_enclosure_walls(orig_hpxml, new_hpxml)
    # Above-grade walls
    orig_hpxml.walls.each do |orig_wall|
      wall_area = nil
      if (@bldg_orient == orig_wall.orientation) || (@bldg_orient == reverse_orientation(orig_wall.orientation))
        wall_area = @ceil_height * @bldg_length_front * @ncfl_ag # FIXME: Verify
      else
        wall_area = @ceil_height * @bldg_length_side * @ncfl_ag # FIXME: Verify
      end

      if orig_wall.wall_type == HPXML::WallTypeWoodStud
        wall_r = get_wood_stud_wall_assembly_r(orig_wall.insulation_cavity_r_value,
                                               orig_wall.insulation_continuous_r_value,
                                               orig_wall.siding,
                                               orig_wall.optimum_value_engineering)
      elsif orig_wall.wall_type == HPXML::WallTypeBrick
        wall_r = get_structural_block_wall_assembly_r(orig_wall.insulation_continuous_r_value)
      elsif orig_wall.wall_type == HPXML::WallTypeCMU
        wall_r = get_concrete_block_wall_assembly_r(orig_wall.insulation_cavity_r_value,
                                                    orig_wall.siding)
      elsif orig_wall.wall_type == HPXML::WallTypeStrawBale
        wall_r = get_straw_bale_wall_assembly_r(orig_wall.siding)
      else
        fail "Unexpected wall type '#{orig_wall.wall_type}'."
      end

      new_hpxml.walls.add(id: orig_wall.id,
                          exterior_adjacent_to: HPXML::LocationOutside,
                          interior_adjacent_to: HPXML::LocationLivingSpace,
                          wall_type: orig_wall.wall_type,
                          area: wall_area,
                          azimuth: orientation_to_azimuth(orig_wall.orientation),
                          solar_absorptance: 0.75,
                          emittance: 0.9,
                          insulation_assembly_r_value: wall_r)
    end
  end

  def self.set_enclosure_foundation_walls(orig_hpxml, new_hpxml)
    orig_hpxml.foundations.each do |orig_foundation|
      fnd_location = orig_foundation.to_location
      fnd_area = orig_foundation.area
      next unless [HPXML::LocationBasementUnconditioned, HPXML::LocationBasementConditioned, HPXML::LocationCrawlspaceVented, HPXML::LocationCrawlspaceUnvented].include? fnd_location

      orig_foundation.attached_foundation_walls.each do |orig_foundation_wall|
        if [HPXML::LocationBasementUnconditioned, HPXML::LocationBasementConditioned].include? fnd_location
          fndwall_height = 8.0
        else
          fndwall_height = 2.5
        end

        new_hpxml.foundation_walls.add(id: orig_foundation_wall.id,
                                       exterior_adjacent_to: HPXML::LocationGround,
                                       interior_adjacent_to: fnd_location,
                                       height: fndwall_height,
                                       area: fndwall_height * get_foundation_perimeter(orig_hpxml, orig_foundation),
                                       thickness: 10,
                                       depth_below_grade: fndwall_height - 1.0,
                                       insulation_interior_r_value: 0,
                                       insulation_interior_distance_to_top: 0,
                                       insulation_interior_distance_to_bottom: 0,
                                       insulation_exterior_r_value: orig_foundation_wall.insulation_r_value,
                                       insulation_exterior_distance_to_top: 0,
                                       insulation_exterior_distance_to_bottom: fndwall_height)
      end
    end
  end

  def self.set_enclosure_framefloors(orig_hpxml, new_hpxml)
    # Floors above foundation
    orig_hpxml.foundations.each do |orig_foundation|
      fnd_location = orig_foundation.to_location
      orig_foundation.attached_frame_floors.each do |orig_frame_floor|
        next unless [HPXML::LocationBasementUnconditioned, HPXML::LocationCrawlspaceVented, HPXML::LocationCrawlspaceUnvented].include? fnd_location

        framefloor_r = get_floor_assembly_r(orig_frame_floor.insulation_cavity_r_value)

        new_hpxml.frame_floors.add(id: orig_frame_floor.id,
                                   exterior_adjacent_to: fnd_location,
                                   interior_adjacent_to: HPXML::LocationLivingSpace,
                                   area: orig_frame_floor.area,
                                   insulation_assembly_r_value: framefloor_r)
      end
    end

    # Floors below attic
    orig_hpxml.attics.each do |orig_attic|
      attic_location = orig_attic.to_location
      fail "Unvented attics shouldn't exist in HEScore." if attic_location == HPXML::LocationAtticUnvented
      next unless attic_location == HPXML::LocationAtticVented

      orig_attic.attached_frame_floors.each do |orig_frame_floor|
        framefloor_r = get_ceiling_assembly_r(orig_frame_floor.insulation_cavity_r_value)

        new_hpxml.frame_floors.add(id: orig_frame_floor.id,
                                   exterior_adjacent_to: attic_location,
                                   interior_adjacent_to: HPXML::LocationLivingSpace,
                                   area: orig_frame_floor.area,
                                   insulation_assembly_r_value: framefloor_r)
      end
    end
  end

  def self.set_enclosure_slabs(orig_hpxml, new_hpxml)
    orig_hpxml.foundations.each do |orig_foundation|
      fnd_location = orig_foundation.to_location
      fnd_type = orig_foundation.foundation_type
      fnd_area = orig_foundation.area

      # Slab
      slab_id = nil
      slab_area = nil
      slab_thickness = nil
      slab_depth_below_grade = nil
      slab_perimeter_insulation_r_value = nil
      if fnd_type == HPXML::FoundationTypeSlab
        orig_foundation.attached_slabs.each do |orig_slab|
          slab_id = orig_slab.id
          slab_area = orig_slab.area
          slab_perimeter_insulation_r_value = orig_slab.perimeter_insulation_r_value
          slab_depth_below_grade = 0
          slab_thickness = 4
        end
      elsif fnd_type.include?('Basement') || fnd_type.include?('Crawlspace')
        orig_foundation.attached_frame_floors.each do |orig_frame_floor|
          slab_id = "#{orig_foundation.id}_slab"
          slab_area = orig_frame_floor.area
          slab_perimeter_insulation_r_value = 0
          if fnd_type.include?('Basement')
            slab_thickness = 4
          else
            slab_thickness = 0
          end
        end
      else
        fail "Unexpected foundation type: #{fnd_type}"
      end

      new_hpxml.slabs.add(id: slab_id,
                          interior_adjacent_to: fnd_location,
                          area: slab_area,
                          thickness: slab_thickness,
                          exposed_perimeter: get_foundation_perimeter(orig_hpxml, orig_foundation),
                          perimeter_insulation_depth: 2,
                          under_slab_insulation_width: 0,
                          depth_below_grade: slab_depth_below_grade,
                          carpet_fraction: 1.0,
                          carpet_r_value: 2.1,
                          perimeter_insulation_r_value: slab_perimeter_insulation_r_value,
                          under_slab_insulation_r_value: 0)
    end
  end

  def self.set_enclosure_windows(orig_hpxml, new_hpxml)
    orig_hpxml.windows.each do |orig_window|
      ufactor = orig_window.ufactor
      shgc = orig_window.shgc
      if ufactor.nil?
        window_frame_type = orig_window.frame_type
        ufactor, shgc = get_window_ufactor_shgc(window_frame_type,
                                                orig_window.aluminum_thermal_break,
                                                orig_window.glass_layers,
                                                orig_window.glass_type,
                                                orig_window.gas_fill)
      end

      interior_shading_factor_summer, interior_shading_factor_winter = Constructions.get_default_interior_shading_factors()
      if orig_window.exterior_shading == 'solar screens'
        interior_shading_factor_summer = 0.29
      end

      # Add one HPXML window per side of the house with only the overhangs from the roof.
      new_hpxml.windows.add(id: orig_window.id,
                            area: orig_window.area,
                            azimuth: orientation_to_azimuth(orig_window.orientation),
                            ufactor: ufactor,
                            shgc: shgc,
                            overhangs_depth: 1.0,
                            overhangs_distance_to_top_of_window: 0.0,
                            overhangs_distance_to_bottom_of_window: @ceil_height * @ncfl_ag,
                            wall_idref: orig_window.wall_idref,
                            interior_shading_factor_summer: interior_shading_factor_summer,
                            interior_shading_factor_winter: interior_shading_factor_winter)
    end
  end

  def self.set_enclosure_skylights(orig_hpxml, new_hpxml)
    orig_hpxml.skylights.each do |orig_skylight|
      ufactor = orig_skylight.ufactor
      shgc = orig_skylight.shgc
      if ufactor.nil?
        skylight_frame_type = orig_skylight.frame_type
        ufactor, shgc = get_skylight_ufactor_shgc(skylight_frame_type,
                                                  orig_skylight.aluminum_thermal_break,
                                                  orig_skylight.glass_layers,
                                                  orig_skylight.glass_type,
                                                  orig_skylight.gas_fill)
      end

      if orig_skylight.exterior_shading == 'solar screens'
        shgc *= 0.29
      end

      new_hpxml.roofs.each do |new_roof|
        next unless new_roof.id.start_with?(orig_skylight.roof_idref)

        skylight_area = orig_skylight.area / 2.0
        new_hpxml.skylights.add(id: "#{orig_skylight.id}_#{new_roof.id}",
                                area: skylight_area,
                                azimuth: new_roof.azimuth,
                                ufactor: ufactor,
                                shgc: shgc,
                                roof_idref: new_roof.id)
      end
    end
  end

  def self.set_enclosure_doors(orig_hpxml, new_hpxml)
    front_wall = nil
    orig_hpxml.walls.each do |orig_wall|
      next if orig_wall.orientation != @bldg_orient

      front_wall = orig_wall
    end
    fail 'Could not find front wall.' if front_wall.nil?

    new_hpxml.doors.add(id: 'Door',
                        wall_idref: front_wall.id,
                        area: 40,
                        azimuth: orientation_to_azimuth(@bldg_orient),
                        r_value: 1.0 / 0.51)
  end

  def self.set_systems_hvac(orig_hpxml, new_hpxml)
    additional_hydronic_ids = []

    # HeatingSystem
    orig_hpxml.heating_systems.each do |orig_heating|
      heating_capacity = -1 # Use Manual J auto-sizing
      distribution_system_idref = orig_heating.distribution_system_idref
      heating_system_type = orig_heating.heating_system_type
      heating_system_fuel = orig_heating.heating_system_fuel
      heating_efficiency_afue = orig_heating.heating_efficiency_afue
      heating_efficiency_percent = orig_heating.heating_efficiency_percent
      year_installed = orig_heating.year_installed
      energy_star = orig_heating.energy_star
      fraction_heat_load_served = orig_heating.fraction_heat_load_served

      # Need to create hydronic distribution system?
      if (heating_system_type == HPXML::HVACTypeBoiler) && distribution_system_idref.nil?
        distribution_system_idref = orig_heating.id + '_dist'
        additional_hydronic_ids << distribution_system_idref
      end

      if [HPXML::HVACTypeFurnace, HPXML::HVACTypeWallFurnace].include? heating_system_type
        if not heating_efficiency_afue.nil?
          # Do nothing, we already have the AFUE
        elsif heating_system_fuel == HPXML::FuelTypeElectricity
          heating_efficiency_afue = 0.98
        elsif energy_star && (heating_system_type == HPXML::HVACTypeFurnace)
          heating_efficiency_afue = lookup_hvac_efficiency(year_installed,
                                                           heating_system_type,
                                                           heating_system_fuel,
                                                           'AFUE',
                                                           'energy_star',
                                                           orig_hpxml.header.state_code)
        elsif not year_installed.nil?
          heating_efficiency_afue = lookup_hvac_efficiency(year_installed,
                                                           heating_system_type,
                                                           heating_system_fuel,
                                                           'AFUE')
        end

      elsif heating_system_type == HPXML::HVACTypeBoiler
        if not heating_efficiency_afue.nil?
          # Do nothing, we already have the AFUE
        elsif heating_system_fuel == HPXML::FuelTypeElectricity
          heating_efficiency_afue = 0.98
        elsif energy_star
          heating_efficiency_afue = lookup_hvac_efficiency(year_installed,
                                                           heating_system_type,
                                                           heating_system_fuel,
                                                           'AFUE',
                                                           'energy_star')
        elsif not year_installed.nil?
          heating_efficiency_afue = lookup_hvac_efficiency(year_installed,
                                                           heating_system_type,
                                                           heating_system_fuel,
                                                           'AFUE')
        end

      elsif heating_system_type == HPXML::HVACTypeElectricResistance
        if heating_efficiency_percent.nil?
          heating_efficiency_percent = 0.98
        end

      elsif heating_system_type == HPXML::HVACTypeStove
        if not heating_efficiency_percent.nil?
          # Do nothing, we already have the heating efficiency percent
        elsif heating_system_fuel == HPXML::FuelTypeWood
          heating_efficiency_percent = 0.60
        elsif heating_system_fuel == HPXML::FuelTypeWoodPellets
          heating_efficiency_percent = 0.78
        end
      end

      new_hpxml.heating_systems.add(id: orig_heating.id,
                                    distribution_system_idref: distribution_system_idref,
                                    heating_system_type: heating_system_type,
                                    heating_system_fuel: heating_system_fuel,
                                    heating_capacity: heating_capacity,
                                    heating_efficiency_afue: heating_efficiency_afue,
                                    heating_efficiency_percent: heating_efficiency_percent,
                                    fraction_heat_load_served: fraction_heat_load_served)
    end

    # CoolingSystem
    orig_hpxml.cooling_systems.each do |orig_cooling|
      distribution_system_idref = orig_cooling.distribution_system_idref
      cooling_system_type = orig_cooling.cooling_system_type
      cooling_system_fuel = HPXML::FuelTypeElectricity
      cooling_efficiency_seer = orig_cooling.cooling_efficiency_seer
      cooling_efficiency_eer = orig_cooling.cooling_efficiency_eer
      year_installed = orig_cooling.year_installed
      energy_star = orig_cooling.energy_star
      fraction_cool_load_served = orig_cooling.fraction_cool_load_served
      cooling_capacity = nil
      if cooling_system_type != HPXML::HVACTypeEvaporativeCooler
        cooling_capacity = -1 # Use Manual J auto-sizing
      end

      if cooling_system_type == HPXML::HVACTypeCentralAirConditioner
        if not cooling_efficiency_seer.nil?
          # Do nothing, we already have the SEER
        elsif energy_star
          cooling_efficiency_seer = lookup_hvac_efficiency(year_installed,
                                                           cooling_system_type,
                                                           cooling_system_fuel,
                                                           'SEER',
                                                           'energy_star')
        elsif not year_installed.nil?
          cooling_efficiency_seer = lookup_hvac_efficiency(year_installed,
                                                           cooling_system_type,
                                                           cooling_system_fuel,
                                                           'SEER')
        end

      elsif cooling_system_type == HPXML::HVACTypeRoomAirConditioner
        if not cooling_efficiency_eer.nil?
          # Do nothing, we already have the EER
        elsif energy_star
          cooling_efficiency_eer = lookup_hvac_efficiency(year_installed,
                                                          cooling_system_type,
                                                          cooling_system_fuel,
                                                          'EER',
                                                          'energy_star')
        elsif not year_installed.nil?
          cooling_efficiency_eer = lookup_hvac_efficiency(year_installed,
                                                          cooling_system_type,
                                                          cooling_system_fuel,
                                                          'EER')
        end
      end

      new_hpxml.cooling_systems.add(id: orig_cooling.id,
                                    distribution_system_idref: distribution_system_idref,
                                    cooling_system_type: cooling_system_type,
                                    cooling_system_fuel: cooling_system_fuel,
                                    cooling_capacity: cooling_capacity,
                                    fraction_cool_load_served: fraction_cool_load_served,
                                    cooling_efficiency_seer: cooling_efficiency_seer,
                                    cooling_efficiency_eer: cooling_efficiency_eer)
    end

    # HeatPump
    orig_hpxml.heat_pumps.each do |orig_hp|
      heat_pump_fuel = HPXML::FuelTypeElectricity
      cooling_capacity = -1 # Use Manual J auto-sizing
      heating_capacity = -1 # Use Manual J auto-sizing
      backup_heating_fuel = HPXML::FuelTypeElectricity
      backup_heating_capacity = -1 # Use Manual J auto-sizing
      backup_heating_efficiency_percent = 1.0
      heat_pump_type = orig_hp.heat_pump_type
      cooling_efficiency_seer = orig_hp.cooling_efficiency_seer
      cooling_efficiency_eer = orig_hp.cooling_efficiency_eer
      heating_efficiency_hspf = orig_hp.heating_efficiency_hspf
      heating_efficiency_cop = orig_hp.heating_efficiency_cop
      distribution_system_idref = orig_hp.distribution_system_idref
      year_installed = orig_hp.year_installed
      energy_star = orig_hp.energy_star
      fraction_cool_load_served = orig_hp.fraction_cool_load_served
      fraction_heat_load_served = orig_hp.fraction_heat_load_served

      if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpMiniSplit].include? heat_pump_type
        if not cooling_efficiency_seer.nil?
          # Do nothing, we have the SEER
        elsif energy_star
          cooling_efficiency_seer = lookup_hvac_efficiency(year_installed,
                                                           heat_pump_type,
                                                           heat_pump_fuel,
                                                           'SEER',
                                                           'energy_star')
        elsif not year_installed.nil?
          cooling_efficiency_seer = lookup_hvac_efficiency(year_installed,
                                                           heat_pump_type,
                                                           heat_pump_fuel,
                                                           'SEER')
        end
        if not heating_efficiency_hspf.nil?
          # Do nothing, we have the HSPF
        elsif energy_star
          heating_efficiency_hspf = lookup_hvac_efficiency(year_installed,
                                                           heat_pump_type,
                                                           heat_pump_fuel,
                                                           'HSPF',
                                                           'energy_star')
        elsif not year_installed.nil?
          heating_efficiency_hspf = lookup_hvac_efficiency(year_installed,
                                                           heat_pump_type,
                                                           heat_pump_fuel,
                                                           'HSPF')
        end
      end

      # If heat pump has no cooling/heating load served, assign arbitrary value for cooling/heating efficiency value
      if (fraction_cool_load_served == 0) && cooling_efficiency_seer.nil? && cooling_efficiency_eer.nil?
        if heat_pump_type == HPXML::HVACTypeHeatPumpGroundToAir
          cooling_efficiency_eer = 16.6
        else
          cooling_efficiency_seer = 13.0
        end
      end
      if (fraction_heat_load_served == 0) && heating_efficiency_hspf.nil? && heating_efficiency_cop.nil?
        if heat_pump_type == HPXML::HVACTypeHeatPumpGroundToAir
          heating_efficiency_cop = 3.6
        else
          heating_efficiency_hspf = 7.7
        end
      end

      new_hpxml.heat_pumps.add(id: orig_hp.id,
                               distribution_system_idref: distribution_system_idref,
                               heat_pump_type: heat_pump_type,
                               heat_pump_fuel: heat_pump_fuel,
                               heating_capacity: heating_capacity,
                               cooling_capacity: cooling_capacity,
                               backup_heating_fuel: backup_heating_fuel,
                               backup_heating_capacity: backup_heating_capacity,
                               backup_heating_efficiency_percent: backup_heating_efficiency_percent,
                               fraction_heat_load_served: fraction_heat_load_served,
                               fraction_cool_load_served: fraction_cool_load_served,
                               cooling_efficiency_seer: cooling_efficiency_seer,
                               cooling_efficiency_eer: cooling_efficiency_eer,
                               heating_efficiency_hspf: heating_efficiency_hspf,
                               heating_efficiency_cop: heating_efficiency_cop)
    end

    # HVACControl
    control_type = HPXML::HVACControlTypeManual
    htg_sp, htg_setback_sp, htg_setback_hrs_per_week, htg_setback_start_hr = HVAC.get_default_heating_setpoint(control_type)
    clg_sp, clg_setup_sp, clg_setup_hrs_per_week, clg_setup_start_hr = HVAC.get_default_cooling_setpoint(control_type)
    new_hpxml.hvac_controls.add(id: 'HVACControl',
                                control_type: control_type,
                                heating_setpoint_temp: htg_sp,
                                cooling_setpoint_temp: clg_sp)

    # HVACDistribution
    orig_hpxml.hvac_distributions.each do |orig_dist|
      new_hpxml.hvac_distributions.add(id: orig_dist.id,
                                       distribution_system_type: HPXML::HVACDistributionTypeAir)

      # Calculate ConditionedFloorAreaServed
      fractions_load_served = []
      orig_dist.hvac_systems.each do |hvac_system|
        if hvac_system.respond_to? :fraction_heat_load_served
          fractions_load_served << hvac_system.fraction_heat_load_served unless hvac_system.fraction_heat_load_served == 0
        end
        if hvac_system.respond_to? :fraction_cool_load_served
          fractions_load_served << hvac_system.fraction_cool_load_served unless hvac_system.fraction_cool_load_served == 0
        end
      end
      fractions_load_served.uniq!
      if fractions_load_served.size != 1
        fail 'Could not calculate ConditionedFloorAreaServed for distribution system.'
      end
      new_hpxml.hvac_distributions[-1].conditioned_floor_area_served = fractions_load_served[0]

      frac_inside = 0.0
      orig_dist.ducts.each do |orig_duct|
        next unless orig_duct.duct_location == HPXML::LocationLivingSpace

        frac_inside += orig_duct.duct_fraction_area
      end

      sealed = orig_dist.duct_system_sealed
      lto_s, lto_r, uncond_area_s, uncond_area_r = calc_duct_values(@ncfl_ag, @cfa, sealed, frac_inside)

      # Supply duct leakage to the outside
      new_hpxml.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                                     duct_leakage_units: HPXML::UnitsPercent,
                                                                     duct_leakage_value: lto_s,
                                                                     duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)

      # Return duct leakage to the outside
      new_hpxml.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                                     duct_leakage_units: HPXML::UnitsPercent,
                                                                     duct_leakage_value: lto_r,
                                                                     duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)

      orig_dist.ducts.each do |orig_duct|
        next if orig_duct.duct_location == HPXML::LocationLivingSpace

        if orig_duct.duct_location == HPXML::LocationAtticUnconditioned
          orig_duct.duct_location = HPXML::LocationAtticVented
        end

        if orig_duct.duct_insulation_material == HPXML::DuctInsulationMaterialUnknown
          duct_rvalue = 6
        elsif orig_duct.duct_insulation_material == HPXML::DuctInsulationMaterialNone
          duct_rvalue = 0
        else
          fail "Unexpected duct insulation material '#{orig_duct.duct_insulation_material}'."
        end

        supply_duct_surface_area = uncond_area_s * orig_duct.duct_fraction_area / (1.0 - frac_inside)
        return_duct_surface_area = uncond_area_r * orig_duct.duct_fraction_area / (1.0 - frac_inside)

        # Supply duct
        new_hpxml.hvac_distributions[-1].ducts.add(duct_type: HPXML::DuctTypeSupply,
                                                   duct_insulation_r_value: duct_rvalue,
                                                   duct_location: orig_duct.duct_location,
                                                   duct_surface_area: supply_duct_surface_area)

        # Return duct
        new_hpxml.hvac_distributions[-1].ducts.add(duct_type: HPXML::DuctTypeReturn,
                                                   duct_insulation_r_value: duct_rvalue,
                                                   duct_location: orig_duct.duct_location,
                                                   duct_surface_area: return_duct_surface_area)
      end
    end

    additional_hydronic_ids.each do |hydronic_id|
      new_hpxml.hvac_distributions.add(id: hydronic_id,
                                       distribution_system_type: HPXML::HVACDistributionTypeHydronic)
    end
  end

  def self.set_systems_mechanical_ventilation(orig_hpxml, new_hpxml)
    # No mechanical ventilation
  end

  def self.set_systems_water_heater(orig_hpxml, new_hpxml)
    orig_hpxml.water_heating_systems.each do |orig_water_heater|
      energy_factor = orig_water_heater.energy_factor
      uniform_energy_factor = orig_water_heater.uniform_energy_factor
      fuel_type = orig_water_heater.fuel_type
      water_heater_type = orig_water_heater.water_heater_type
      year_installed = orig_water_heater.year_installed
      energy_star = orig_water_heater.energy_star

      if (not energy_factor.nil?) || (not uniform_energy_factor.nil?)
        # Do nothing, we already have the energy factor
      elsif energy_star
        energy_factor = lookup_water_heater_efficiency(year_installed,
                                                       fuel_type,
                                                       'energy_star')
      elsif not year_installed.nil?
        energy_factor = lookup_water_heater_efficiency(year_installed,
                                                       fuel_type)
      end

      fail 'Water Heater Type must be provided' if water_heater_type.nil?
      fail 'Electric water heaters must be heat pump water heaters to be Energy Star qualified' if energy_star && (fuel_type == HPXML::FuelTypeElectricity) && (water_heater_type != HPXML::WaterHeaterTypeHeatPump)

      heating_capacity = nil
      if water_heater_type == HPXML::WaterHeaterTypeStorage
        heating_capacity = get_default_water_heater_capacity(fuel_type)
      end
      recovery_efficiency = nil
      if (water_heater_type == HPXML::WaterHeaterTypeStorage) && (fuel_type != HPXML::FuelTypeElectricity)
        ef = energy_factor
        if ef.nil?
          ef = 0.9066 * uniform_energy_factor + 0.0711 # RESNET equation for Consumer Gas-Fired Water Heater
        end
        recovery_efficiency = get_default_water_heater_re(fuel_type, ef)
      end
      tank_volume = nil
      if water_heater_type == HPXML::WaterHeaterTypeCombiStorage
        tank_volume = get_default_water_heater_volume(HPXML::FuelTypeElectricity)
      # Set default fuel_type to call function : get_default_water_heater_volume, not passing this input to EP-HPXML
      elsif (water_heater_type != HPXML::WaterHeaterTypeTankless) && (water_heater_type != HPXML::WaterHeaterTypeCombiTankless)
        tank_volume = get_default_water_heater_volume(fuel_type)
      end

      # Water heater location
      if @has_cond_bsmnt
        water_heater_location = HPXML::LocationBasementConditioned
      elsif @has_uncond_bsmnt
        water_heater_location = HPXML::LocationBasementUnconditioned
      else
        water_heater_location = HPXML::LocationLivingSpace
      end

      new_hpxml.water_heating_systems.add(id: orig_water_heater.id,
                                          fuel_type: fuel_type,
                                          water_heater_type: water_heater_type,
                                          location: water_heater_location,
                                          tank_volume: tank_volume,
                                          fraction_dhw_load_served: 1.0,
                                          heating_capacity: heating_capacity,
                                          energy_factor: energy_factor,
                                          uniform_energy_factor: uniform_energy_factor,
                                          recovery_efficiency: recovery_efficiency,
                                          related_hvac_idref: orig_water_heater.related_hvac_idref)
    end
  end

  def self.set_systems_water_heating_use(orig_hpxml, new_hpxml)
    new_hpxml.hot_water_distributions.add(id: 'HotWaterDistribution',
                                          system_type: HPXML::DHWDistTypeStandard,
                                          pipe_r_value: 0)

    new_hpxml.water_fixtures.add(id: 'ShowerHead',
                                 water_fixture_type: HPXML::WaterFixtureTypeShowerhead,
                                 low_flow: false)
  end

  def self.set_systems_photovoltaics(orig_hpxml, new_hpxml)
    return if orig_hpxml.pv_systems.size == 0

    orig_pv_system = orig_hpxml.pv_systems[0]

    max_power_output = orig_pv_system.max_power_output
    if max_power_output.nil?
      # Estimate from year and # modules
      module_power = PV.calc_module_power_from_year(orig_pv_system.year_modules_manufactured) # W/panel
      max_power_output = orig_pv_system.number_of_panels * module_power
    end

    new_hpxml.pv_systems.add(id: 'PVSystem',
                             location: HPXML::LocationRoof,
                             module_type: HPXML::PVModuleTypeStandard,
                             tracking: HPXML::PVTrackingTypeFixed,
                             array_azimuth: orientation_to_azimuth(orig_pv_system.array_orientation),
                             array_tilt: @roof_angle,
                             max_power_output: max_power_output,
                             year_modules_manufactured: orig_pv_system.year_modules_manufactured)
  end

  def self.set_appliances_clothes_washer(orig_hpxml, new_hpxml)
    new_hpxml.clothes_washers.add(id: 'ClothesWasher')
  end

  def self.set_appliances_clothes_dryer(orig_hpxml, new_hpxml)
    new_hpxml.clothes_dryers.add(id: 'ClothesDryer',
                                 fuel_type: HPXML::FuelTypeElectricity)
  end

  def self.set_appliances_dishwasher(orig_hpxml, new_hpxml)
    new_hpxml.dishwashers.add(id: 'Dishwasher')
  end

  def self.set_appliances_refrigerator(orig_hpxml, new_hpxml)
    new_hpxml.refrigerators.add(id: 'Refrigerator')
  end

  def self.set_appliances_cooking_range_oven(orig_hpxml, new_hpxml)
    new_hpxml.cooking_ranges.add(id: 'CookingRange',
                                 fuel_type: HPXML::FuelTypeElectricity)

    new_hpxml.ovens.add(id: 'Oven')
  end

  def self.set_lighting(orig_hpxml, new_hpxml)
    ltg_fracs = Lighting.get_default_fractions()
    ltg_fracs.each_with_index do |(key, fraction), i|
      location, lighting_type = key
      new_hpxml.lighting_groups.add(id: "LightingGroup#{i + 1}",
                                    location: location,
                                    fraction_of_units_in_location: fraction,
                                    lighting_type: lighting_type)
    end
  end

  def self.set_ceiling_fans(orig_hpxml, new_hpxml)
    # No ceiling fans
  end

  def self.set_misc_plug_loads(orig_hpxml, new_hpxml)
    new_hpxml.plug_loads.add(id: 'PlugLoadOther',
                             plug_load_type: HPXML::PlugLoadTypeOther)
  end

  def self.set_misc_television(orig_hpxml, new_hpxml)
    new_hpxml.plug_loads.add(id: 'PlugLoadTV',
                             plug_load_type: HPXML::PlugLoadTypeTelevision)
  end

  def self.get_foundation_perimeter(orig_hpxml, foundation)
    n_foundations = orig_hpxml.foundations.size
    if n_foundations == 1
      return @bldg_perimeter
    elsif n_foundations == 2
      fnd_area = foundation.area
      long_side = [@bldg_length_front, @bldg_length_side].max
      short_side = [@bldg_length_front, @bldg_length_side].min
      total_foundation_area = 0
      orig_hpxml.foundations.each do |a_foundation|
        total_foundation_area += a_foundation.area
      end
      fnd_frac = fnd_area / total_foundation_area
      return short_side + 2 * long_side * fnd_frac
    else
      fail 'Only one or two foundations is allowed.'
    end
  end
end

def lookup_hvac_efficiency(year, hvac_type, fuel_type, units, performance_id = 'shipment_weighted', state_code = nil)
  year = 0 if year.nil?

  type_id = { HPXML::HVACTypeCentralAirConditioner => 'split_dx',
              HPXML::HVACTypeRoomAirConditioner => 'packaged_dx',
              HPXML::HVACTypeHeatPumpAirToAir => 'heat_pump',
              HPXML::HVACTypeHeatPumpMiniSplit => 'mini_split',
              HPXML::HVACTypeFurnace => 'central_furnace',
              HPXML::HVACTypeWallFurnace => 'wall_furnace',
              HPXML::HVACTypeBoiler => 'boiler' }[hvac_type]
  fail "Unexpected hvac_type #{hvac_type}." if type_id.nil?

  fuel_primary_id = hpxml_to_hescore_fuel(fuel_type)
  fail "Unexpected fuel_type #{fuel_type}." if fuel_primary_id.nil?

  metric_id = units.downcase

  fail "Invalid performance_id for HVAC lookup #{performance_id}." if not ['shipment_weighted', 'energy_star'].include?(performance_id)

  region_id = nil
  if (performance_id == 'energy_star') && (type_id == 'central_furnace') && ['lpg', 'natural_gas'].include?(fuel_primary_id)
    fail 'state_code required for Energy Star central furnaces' if state_code.nil?

    CSV.foreach(File.join(File.dirname(__FILE__), 'lu_es_furnace_region.csv'), headers: true) do |row|
      next unless row['state_code'] == state_code

      region_id = row['furnace_region']
      break
    end
    fail "Could not lookup Energy Star furnace region for state #{state_code}." if region_id.nil?
  end

  value = nil
  lookup_year = 0
  CSV.foreach(File.join(File.dirname(__FILE__), 'lu_hvac_equipment_efficiency.csv'), headers: true) do |row|
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
  fail 'Could not lookup default HVAC efficiency.' if value.nil?

  return value
end

def lookup_water_heater_efficiency(year, fuel_type, performance_id = 'shipment_weighted')
  year = 0 if year.nil?

  fuel_primary_id = hpxml_to_hescore_fuel(fuel_type)
  fail "Unexpected fuel_type #{fuel_type}." if fuel_primary_id.nil?

  fail "Invalid performance_id for water heater lookup #{performance_id}." if not ['shipment_weighted', 'energy_star'].include?(performance_id)

  value = nil
  lookup_year = 0
  CSV.foreach(File.join(File.dirname(__FILE__), 'lu_water_heater_efficiency.csv'), headers: true) do |row|
    next unless row['performance_id'] == performance_id
    next unless row['fuel_primary_id'] == fuel_primary_id

    row_year = Integer(row['year'])
    if (row_year - year).abs <= (lookup_year - year).abs
      lookup_year = row_year
      value = Float(row['value'])
    end
  end
  fail 'Could not lookup default water heating efficiency.' if value.nil?

  return value
end

def get_default_water_heater_volume(fuel)
  # Water Heater Tank Volume by fuel
  val = { HPXML::FuelTypeElectricity => 50,
          HPXML::FuelTypeNaturalGas => 40,
          HPXML::FuelTypePropane => 40,
          HPXML::FuelTypeOil => 32 }[fuel]
  return val if not val.nil?

  fail "Could not get default water heater volume for fuel '#{fuel}'"
end

def get_default_water_heater_re(fuel, ef)
  # Water Heater Recovery Efficiency by fuel and energy factor
  val = nil
  if fuel == HPXML::FuelTypeElectricity
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
  val = { HPXML::FuelTypeElectricity => 15400,
          HPXML::FuelTypeNaturalGas => 38000,
          HPXML::FuelTypePropane => 38000,
          HPXML::FuelTypeOil => 90000 }[fuel]
  return val if not val.nil?

  fail "Could not get default water heater capacity for fuel '#{fuel}'"
end

def get_wall_effective_r_from_doe2code(doe2code)
  val = nil
  CSV.foreach(File.join(File.dirname(__FILE__), 'lu_wall_eff_rvalue.csv'), headers: true) do |row|
    next unless row['doe2code'] == doe2code

    val = Float(row['Eff-R-value'])
    break
  end
  return val
end

$siding_map = {
  HPXML::SidingTypeWood => 'wo',
  HPXML::SidingTypeStucco => 'st',
  HPXML::SidingTypeVinyl => 'vi',
  HPXML::SidingTypeAluminum => 'al',
  HPXML::SidingTypeBrick => 'br',
  nil => 'nn'
}

def get_wood_stud_wall_assembly_r(r_cavity, r_cont, siding, ove)
  # Walls Wood Stud Assembly R-value
  has_r_cont = !r_cont.nil?
  if (not has_r_cont) && (not ove)
    # Wood Frame
    doe2walltype = 'wf'
  elsif has_r_cont && (not ove)
    # Wood Frame with Rigid Foam Sheathing
    doe2walltype = 'ps'
  elsif (not has_r_cont) && ove
    # Wood Frame with Optimal Value Engineering
    doe2walltype = 'ov'
  end
  doe2code = 'ew%s%02.0f%s' % [doe2walltype, r_cavity, $siding_map[siding]]
  val = get_wall_effective_r_from_doe2code(doe2code)
  return val if not val.nil?

  fail "Could not get default wood stud wall assembly R-value for R-cavity '#{r_cavity}' and R-cont '#{r_cont}' and siding '#{siding}' and ove '#{ove}'"
end

def get_structural_block_wall_assembly_r(r_cont)
  # Walls Structural Block Assembly R-value
  doe2code = 'ewbr%02.0fnn' % (r_cont.nil? ? 0.0 : r_cont)
  val = get_wall_effective_r_from_doe2code(doe2code)
  return val if not val.nil?

  fail "Could not get default structural block wall assembly R-value for R-cavity '#{r_cont}'"
end

def get_concrete_block_wall_assembly_r(r_cavity, siding)
  # Walls Concrete Block Assembly R-value
  doe2code = 'ewcb%02.0f%s' % [r_cavity, $siding_map[siding]]
  val = get_wall_effective_r_from_doe2code(doe2code)
  return val if not val.nil?

  fail "Could not get default concrete block wall assembly R-value for R-cavity '#{r_cavity}' and siding '#{siding}'"
end

def get_straw_bale_wall_assembly_r(siding)
  # Walls Straw Bale Assembly R-value
  doe2code = 'ewsb00%s' % $siding_map[siding]
  val = get_wall_effective_r_from_doe2code(doe2code)
  return val if not val.nil?

  fail "Could not get default straw bale assembly R-value for siding '#{siding}'"
end

def get_roof_effective_r_from_doe2code(doe2code)
  val = nil
  CSV.foreach(File.join(File.dirname(__FILE__), 'lu_roof_eff_rvalue.csv'), headers: true) do |row|
    next unless row['doe2code'] == doe2code

    val = Float(row['Eff-R-value'])
    break
  end
  return val
end

def get_roof_assembly_r(r_cavity, r_cont, material, has_radiant_barrier)
  # Roof Assembly R-value
  materials_map = {
    HPXML::RoofMaterialAsphaltShingles => 'co',  # Composition Shingles
    HPXML::RoofMaterialWoodShingles => 'wo',     # Wood Shakes
    HPXML::RoofMaterialClayTile => 'rc',         # Clay Tile
    HPXML::RoofMaterialConcrete => 'lc',         # Concrete Tile
    HPXML::RoofMaterialPlasticRubber => 'tg'     # Tar and Gravel
  }
  has_r_cont = !r_cont.nil?
  if (not has_r_cont) && (not has_radiant_barrier)
    # Wood Frame
    doe2rooftype = 'wf'
  elsif (not has_r_cont) && has_radiant_barrier
    # Wood Frame with Radiant Barrier
    doe2rooftype = 'rb'
  elsif has_r_cont && (not has_radiant_barrier)
    # Wood Frame with Rigid Foam Sheathing
    doe2rooftype = 'ps'
  end

  doe2code = 'rf%s%02.0f%s' % [doe2rooftype, r_cavity, materials_map[material]]
  val = get_roof_effective_r_from_doe2code(doe2code)

  return val if not val.nil?

  fail "Could not get default roof assembly R-value for R-cavity '#{r_cavity}' and R-cont '#{r_cont}' and material '#{material}' and radiant barrier '#{has_radiant_barrier}'"
end

def get_ceiling_assembly_r(r_cavity)
  # Ceiling Assembly R-value
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

def get_window_ufactor_shgc(frame_type, thermal_break, glass_layers, glass_type, gas_fill)
  key = [frame_type, thermal_break, glass_layers, glass_type, gas_fill]
  vals = { [HPXML::WindowFrameTypeAluminum, false, HPXML::WindowLayersSinglePane, nil, nil] => [1.27, 0.75], # scna
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersSinglePane, nil, nil] => [0.89, 0.64], # scnw
           [HPXML::WindowFrameTypeAluminum, false, HPXML::WindowLayersSinglePane, HPXML::WindowGlazingTintedReflective, nil] => [1.27, 0.64], # stna
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersSinglePane, HPXML::WindowGlazingTintedReflective, nil] => [0.89, 0.54], # stnw
           [HPXML::WindowFrameTypeAluminum, false, HPXML::WindowLayersDoublePane, nil, HPXML::WindowGasAir] => [0.81, 0.67], # dcaa
           [HPXML::WindowFrameTypeAluminum, true, HPXML::WindowLayersDoublePane, nil, HPXML::WindowGasAir] => [0.60, 0.67], # dcab
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersDoublePane, nil, HPXML::WindowGasAir] => [0.51, 0.56], # dcaw
           [HPXML::WindowFrameTypeAluminum, false, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingTintedReflective, HPXML::WindowGasAir] => [0.81, 0.55], # dtaa
           [HPXML::WindowFrameTypeAluminum, true, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingTintedReflective, HPXML::WindowGasAir] => [0.60, 0.55], # dtab
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingTintedReflective, HPXML::WindowGasAir] => [0.51, 0.46], # dtaw
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingLowE, HPXML::WindowGasAir] => [0.42, 0.52], # dpeaw
           [HPXML::WindowFrameTypeAluminum, true, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingLowE, HPXML::WindowGasArgon] => [0.47, 0.62], # dpeaab
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingLowE, HPXML::WindowGasArgon] => [0.39, 0.52], # dpeaaw
           [HPXML::WindowFrameTypeAluminum, false, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingReflective, HPXML::WindowGasAir] => [0.67, 0.37], # dseaa
           [HPXML::WindowFrameTypeAluminum, true, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingReflective, HPXML::WindowGasAir] => [0.47, 0.37], # dseab
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingReflective, HPXML::WindowGasAir] => [0.39, 0.31], # dseaw
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingReflective, HPXML::WindowGasArgon] => [0.36, 0.31], # dseaaw
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersTriplePane, HPXML::WindowGlazingLowE, HPXML::WindowGasArgon] => [0.27, 0.31] }[key] # thmabw
  return vals if not vals.nil?

  fail "Could not get default window U/SHGC for frame type '#{frame_type}' and glass layers '#{glass_layers}' and glass type '#{glass_type}' and gas fill '#{gas_fill}'"
end

def get_skylight_ufactor_shgc(frame_type, thermal_break, glass_layers, glass_type, gas_fill)
  # Skylight U-factor/SHGC
  # FIXME: Verify
  key = [frame_type, thermal_break, glass_layers, glass_type, gas_fill]
  vals = { [HPXML::WindowFrameTypeAluminum, false, HPXML::WindowLayersSinglePane, nil, nil] => [1.98, 0.75], # scna
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersSinglePane, nil, nil] => [1.47, 0.64], # scnw
           [HPXML::WindowFrameTypeAluminum, false, HPXML::WindowLayersSinglePane, HPXML::WindowGlazingTintedReflective, nil] => [1.98, 0.64], # stna
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersSinglePane, HPXML::WindowGlazingTintedReflective, nil] => [1.47, 0.54], # stnw
           [HPXML::WindowFrameTypeAluminum, false, HPXML::WindowLayersDoublePane, nil, HPXML::WindowGasAir] => [1.30, 0.67], # dcaa
           [HPXML::WindowFrameTypeAluminum, true, HPXML::WindowLayersDoublePane, nil, HPXML::WindowGasAir] => [1.10, 0.67], # dcab
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersDoublePane, nil, HPXML::WindowGasAir] => [0.84, 0.56], # dcaw
           [HPXML::WindowFrameTypeAluminum, false, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingTintedReflective, HPXML::WindowGasAir] => [1.30, 0.55], # dtaa
           [HPXML::WindowFrameTypeAluminum, true, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingTintedReflective, HPXML::WindowGasAir] => [1.10, 0.55], # dtab
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingTintedReflective, HPXML::WindowGasAir] => [0.84, 0.46], # dtaw
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingLowE, HPXML::WindowGasAir] => [0.74, 0.52], # dpeaw
           [HPXML::WindowFrameTypeAluminum, true, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingLowE, HPXML::WindowGasArgon] => [0.95, 0.62], # dpeaab
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingLowE, HPXML::WindowGasArgon] => [0.68, 0.52], # dpeaaw
           [HPXML::WindowFrameTypeAluminum, false, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingReflective, HPXML::WindowGasAir] => [1.17, 0.37], # dseaa
           [HPXML::WindowFrameTypeAluminum, true, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingReflective, HPXML::WindowGasAir] => [0.98, 0.37], # dseab
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingReflective, HPXML::WindowGasAir] => [0.71, 0.31], # dseaw
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersDoublePane, HPXML::WindowGlazingReflective, HPXML::WindowGasArgon] => [0.65, 0.31], # dseaaw
           [HPXML::WindowFrameTypeWood, nil, HPXML::WindowLayersTriplePane, HPXML::WindowGlazingLowE, HPXML::WindowGasArgon] => [0.47, 0.31] }[key] # thmabw
  return vals if not vals.nil?

  fail "Could not get default skylight U/SHGC for frame type '#{frame_type}' and glass layers '#{glass_layers}' and glass type '#{glass_type}' and gas fill '#{gas_fill}'"
end

def get_roof_solar_absorptance(roof_color)
  # FIXME: Verify
  val = { HPXML::WindowGlazingReflective => 0.35,
          HPXML::RoofColorLight => 0.55,
          HPXML::RoofColorMedium => 0.7,
          HPXML::RoofColorMediumDark => 0.8,
          HPXML::RoofColorDark => 0.9 }[roof_color]
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
  if (iecc_cz == '1A') || (iecc_cz == '2A')
    c_iecc = 0.4727
  elsif iecc_cz == '3A'
    c_iecc = 0.2529
  elsif iecc_cz == '4A'
    c_iecc = 0.3261
  elsif iecc_cz == '5A'
    c_iecc = 0.1118
  elsif (iecc_cz == '6A') || (iecc_cz == '7')
    c_iecc = 0.0
  elsif (iecc_cz == '2B') || (iecc_cz == '3B')
    c_iecc = -0.03755
  elsif (iecc_cz == '4B') || (iecc_cz == '5B')
    c_iecc = -0.008774
  elsif iecc_cz == '6B'
    c_iecc = 0.01944
  elsif iecc_cz == '3C'
    c_iecc = 0.04827
  elsif iecc_cz == '4C'
    c_iecc = 0.2584
  elsif iecc_cz == '8'
    c_iecc = -0.5119
  else
    fail "Unexpected IECC climate zone: #{c_iecc}"
  end

  # Foundation type (weight by area)
  c_foundation = 0.0
  sum_fnd_area = 0.0
  fnd_types.each do |fnd_type, area|
    sum_fnd_area += area
    if fnd_type == HPXML::LocationLivingSpace
      c_foundation += -0.036992 * area
    elsif (fnd_type == HPXML::LocationBasementConditioned) || (fnd_type == HPXML::LocationCrawlspaceUnvented)
      c_foundation += 0.108713 * area
    elsif (fnd_type == HPXML::LocationBasementUnconditioned) || (fnd_type == HPXML::LocationCrawlspaceVented)
      c_foundation += 0.180352 * area
    else
      fail "Unexpected foundation type: #{fnd_type}"
    end
  end
  c_foundation /= sum_fnd_area

  # Ducts (weighted by duct fraction and hvac fraction)
  c_duct = 0.0
  ducts.each do |hvac_frac, duct_frac, duct_location|
    if duct_location == HPXML::LocationLivingSpace
      c_duct += -0.12381 * duct_frac * hvac_frac
    elsif (duct_location == HPXML::LocationAtticUnconditioned) || (duct_location == HPXML::LocationBasementUnconditioned)
      c_duct += 0.07126 * duct_frac * hvac_frac
    elsif duct_location == HPXML::LocationCrawlspaceVented
      c_duct += 0.18072 * duct_frac * hvac_frac
    elsif duct_location == HPXML::LocationCrawlspaceUnvented
      c_duct += 0.07126 * duct_frac * hvac_frac
    else
      fail "Unexpected duct location: #{duct_location}"
    end
  end

  c_sealed = nil
  if desc == HPXML::LeakinessTight
    c_sealed = -0.288
  elsif desc == HPXML::LeakinessAverage
    c_sealed = 0.0
  else
    fail "Unexpected air leakage description: #{desc}"
  end

  floor_area_m2 = UnitConversions.convert(cfa, 'ft^2', 'm^2')
  height_m = UnitConversions.convert(ncfl_ag * ceil_height, 'ft', 'm') + 0.5

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
  return { HPXML::OrientationNortheast => 45,
           HPXML::OrientationEast => 90,
           HPXML::OrientationSoutheast => 135,
           HPXML::OrientationSouth => 180,
           HPXML::OrientationSouthwest => 225,
           HPXML::OrientationWest => 270,
           HPXML::OrientationNorthwest => 315,
           HPXML::OrientationNorth => 0 }[orientation]
end

def reverse_orientation(orientation)
  # Converts, e.g., "northwest" to "southeast"
  reverse = orientation
  if reverse.include? HPXML::OrientationNorth
    reverse = reverse.gsub(HPXML::OrientationNorth, HPXML::OrientationSouth)
  else
    reverse = reverse.gsub(HPXML::OrientationSouth, HPXML::OrientationNorth)
  end
  if reverse.include? HPXML::OrientationEast
    reverse = reverse.gsub(HPXML::OrientationEast, HPXML::OrientationWest)
  else
    reverse = reverse.gsub(HPXML::OrientationWest, HPXML::OrientationEast)
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
  return { HPXML::FuelTypeElectricity => 'electric',
           HPXML::FuelTypeNaturalGas => 'natural_gas',
           HPXML::FuelTypeOil => 'fuel_oil',
           HPXML::FuelTypePropane => 'lpg' }[fuel_type]
end

def get_foundation_areas(orig_hpxml)
  # Returns a hash of foundation location => area
  fnd_types = {}
  orig_hpxml.foundations.each do |orig_foundation|
    fnd_types[orig_foundation.to_location] = orig_foundation.area
  end
  return fnd_types
end

def get_ducts_details(orig_hpxml)
  # Returns a list of [hvac_frac, duct_frac, duct_location]
  ducts = []
  orig_hpxml.hvac_distributions.each do |orig_dist|
    hvac_frac = get_hvac_fraction(orig_hpxml, orig_dist.id)

    orig_dist.ducts.each do |orig_duct|
      ducts << [hvac_frac, orig_duct.duct_fraction_area, orig_duct.duct_location]
    end
  end
  return ducts
end

def get_hvac_fraction(orig_hpxml, dist_id)
  orig_hpxml.heating_systems.each do |orig_heating|
    next unless orig_heating.distribution_system_idref == dist_id

    return orig_heating.fraction_heat_load_served
  end
  orig_hpxml.cooling_systems.each do |orig_cooling|
    next unless orig_cooling.distribution_system_idref == dist_id

    return orig_cooling.fraction_cool_load_served
  end
  orig_hpxml.heat_pumps.each do |orig_hp|
    next unless orig_hp.distribution_system_idref == dist_id

    return orig_hp.fraction_cool_load_served
  end
  return
end

def calc_conditioned_volume(orig_hpxml)
  cvolume = @cfa * @ceil_height
  orig_hpxml.attics.each do |orig_attic|
    is_conditioned_attic = (orig_attic.attic_type == HPXML::AtticTypeConditioned)
    is_cathedral_ceiling = (orig_attic.attic_type == HPXML::AtticTypeCathedral)
    next unless is_conditioned_attic || is_cathedral_ceiling

    orig_attic.attached_roofs.each do |orig_roof|
      # Half of the length of short side of the house
      a = 0.5 * [@bldg_length_front, @bldg_length_side].min
      # Ridge height
      b = a * Math.tan(@roof_angle_rad)
      # The hypotenuse
      c = a / Math.cos(@roof_angle_rad)
      # The depth this attic area goes back on the non-gable side
      d = 0.5 * orig_roof.area / c

      if is_conditioned_attic
        # Remove erroneous full height volume from the conditioned volume
        cvolume -= @ceil_height * 2 * a * d
      end

      # Add the volume under the roof and above the "ceiling"
      cvolume += d * a * b
    end
  end
  return cvolume
end
