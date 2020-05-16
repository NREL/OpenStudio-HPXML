# frozen_string_literal: true

class Geometry
  # Calculates space heights as the max z coordinate minus the min z coordinate
  def self.get_height_of_spaces(spaces)
    minzs = []
    maxzs = []
    spaces.each do |space|
      zvalues = getSurfaceZValues(space.surfaces)
      minzs << zvalues.min + UnitConversions.convert(space.zOrigin, 'm', 'ft')
      maxzs << zvalues.max + UnitConversions.convert(space.zOrigin, 'm', 'ft')
    end
    return maxzs.max - minzs.min
  end

  def self.get_max_z_of_spaces(spaces)
    maxzs = []
    spaces.each do |space|
      zvalues = getSurfaceZValues(space.surfaces)
      maxzs << zvalues.max + UnitConversions.convert(space.zOrigin, 'm', 'ft')
    end
    return maxzs.max
  end

  def self.space_is_conditioned(space)
    unless space.isPlenum
      if space.spaceType.is_initialized
        if space.spaceType.get.standardsSpaceType.is_initialized
          return is_conditioned_space_type(space.spaceType.get.standardsSpaceType.get)
        end
      end
    end
    return false
  end

  def self.is_conditioned_space_type(space_type)
    if [HPXML::LocationLivingSpace].include? space_type
      return true
    end

    return false
  end

  def self.get_space_from_location(model, location, location_hierarchy)
    if location == Constants.Auto
      location_hierarchy.each do |space_type|
        model.getSpaces.each do |space|
          next if not space_is_of_type(space, space_type)

          return space
        end
      end
    else
      model.getSpaces.each do |space|
        next if not space.spaceType.is_initialized
        next if not space.spaceType.get.standardsSpaceType.is_initialized
        next if space.spaceType.get.standardsSpaceType.get != location

        return space
      end
    end
    return
  end

  # Return an array of z values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
  def self.getSurfaceZValues(surfaceArray)
    zValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        zValueArray << UnitConversions.convert(vertex.z, 'm', 'ft')
      end
    end
    return zValueArray
  end

  def self.get_z_origin_for_zone(zone)
    z_origins = []
    zone.spaces.each do |space|
      z_origins << UnitConversions.convert(space.zOrigin, 'm', 'ft')
    end
    return z_origins.min
  end

  # Takes in a list of spaces and returns the total above grade wall area
  def self.calculate_above_grade_wall_area(spaces)
    wall_area = 0
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != 'wall'
        next if surface.outsideBoundaryCondition.downcase == 'foundation'

        wall_area += UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2')
      end
    end
    return wall_area
  end

  def self.calculate_above_grade_exterior_wall_area(spaces)
    wall_area = 0
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != 'wall'
        next if surface.outsideBoundaryCondition.downcase != 'outdoors'
        next if surface.outsideBoundaryCondition.downcase == 'foundation'
        next unless space_is_conditioned(surface.space.get)

        wall_area += UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2')
      end
    end
    return wall_area
  end

  def self.get_roof_pitch(surfaces)
    tilts = []
    surfaces.each do |surface|
      next if surface.surfaceType.downcase != 'roofceiling'
      next if (surface.outsideBoundaryCondition.downcase != 'outdoors') && (surface.outsideBoundaryCondition.downcase != 'adiabatic')

      tilts << surface.tilt
    end
    return UnitConversions.convert(tilts.max, 'rad', 'deg')
  end

  # TODO: Remove these methods
  def self.is_living(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, HPXML::LocationLivingSpace)
  end

  def self.is_vented_crawl(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, HPXML::LocationCrawlspaceVented)
  end

  def self.is_unvented_crawl(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, HPXML::LocationCrawlspaceUnvented)
  end

  def self.is_unconditioned_basement(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, HPXML::LocationBasementUnconditioned)
  end

  def self.is_vented_attic(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, HPXML::LocationAtticVented)
  end

  def self.is_unvented_attic(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, HPXML::LocationAtticUnvented)
  end

  def self.is_garage(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, HPXML::LocationGarage)
  end

  def self.space_or_zone_is_of_type(space_or_zone, space_type)
    if space_or_zone.is_a? OpenStudio::Model::Space
      return space_is_of_type(space_or_zone, space_type)
    elsif space_or_zone.is_a? OpenStudio::Model::ThermalZone
      return zone_is_of_type(space_or_zone, space_type)
    end
  end

  def self.space_is_of_type(space, space_type)
    unless space.isPlenum
      if space.spaceType.is_initialized
        if space.spaceType.get.standardsSpaceType.is_initialized
          return true if space.spaceType.get.standardsSpaceType.get == space_type
        end
      end
    end
    return false
  end

  def self.zone_is_of_type(zone, space_type)
    zone.spaces.each do |space|
      return space_is_of_type(space, space_type)
    end
  end

  def self.process_occupants(model, num_occ, occ_gain, sens_frac, lat_frac, weekday_sch, weekend_sch, monthly_sch,
                             cfa, nbeds, space)

    # Error checking
    if (sens_frac < 0) || (sens_frac > 1)
      fail 'Sensible fraction must be greater than or equal to 0 and less than or equal to 1.'
    end
    if (lat_frac < 0) || (lat_frac > 1)
      fail 'Latent fraction must be greater than or equal to 0 and less than or equal to 1.'
    end
    if lat_frac + sens_frac > 1
      fail 'Sum of sensible and latent fractions must be less than or equal to 1.'
    end

    activity_per_person = UnitConversions.convert(occ_gain, 'Btu/hr', 'W')

    # Hard-coded convective, radiative, latent, and lost fractions
    occ_lat = lat_frac
    occ_sens = sens_frac
    occ_conv = 0.442 * occ_sens
    occ_rad = 0.558 * occ_sens
    occ_lost = 1 - occ_lat - occ_conv - occ_rad

    space_obj_name = "#{Constants.ObjectNameOccupants}"
    space_num_occ = num_occ * UnitConversions.convert(space.floorArea, 'm^2', 'ft^2') / cfa

    # Create schedule
    people_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameOccupants + ' schedule', weekday_sch, weekend_sch, monthly_sch, 1.0, 1.0, true, true, Constants.ScheduleTypeLimitsFraction)

    # Create schedule
    activity_sch = OpenStudio::Model::ScheduleRuleset.new(model, activity_per_person)

    # Add people definition for the occ
    occ_def = OpenStudio::Model::PeopleDefinition.new(model)
    occ = OpenStudio::Model::People.new(occ_def)
    occ.setName(space_obj_name)
    occ.setSpace(space)
    occ_def.setName(space_obj_name)
    occ_def.setNumberOfPeopleCalculationMethod('People', 1)
    occ_def.setNumberofPeople(space_num_occ)
    occ_def.setFractionRadiant(occ_rad)
    occ_def.setSensibleHeatFraction(occ_sens)
    occ_def.setMeanRadiantTemperatureCalculationType('ZoneAveraged')
    occ_def.setCarbonDioxideGenerationRate(0)
    occ_def.setEnableASHRAE55ComfortWarnings(false)
    occ.setActivityLevelSchedule(activity_sch)
    occ.setNumberofPeopleSchedule(people_sch.schedule)
  end

  def self.get_occupancy_default_num(nbeds)
    return Float(nbeds)
  end

  def self.get_occupancy_default_values()
    # Table 4.2.2(3). Internal Gains for Reference Homes
    hrs_per_day = 16.5 # hrs/day
    sens_gains = 3716.0 # Btu/person/day
    lat_gains = 2884.0 # Btu/person/day
    tot_gains = sens_gains + lat_gains
    heat_gain = tot_gains / hrs_per_day # Btu/person/hr
    sens = sens_gains / tot_gains
    lat = lat_gains / tot_gains
    return heat_gain, hrs_per_day, sens, lat
  end
end
