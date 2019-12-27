require_relative "constants"
require_relative "unit_conversions"
require_relative "util"

class Geometry
  def self.get_zone_volume(zone)
    if zone.isVolumeAutocalculated or not zone.volume.is_initialized
      # Calculate volume from spaces
      volume = 0
      zone.spaces.each do |space|
        volume += UnitConversions.convert(space.volume, "m^3", "ft^3")
      end
    else
      volume = UnitConversions.convert(zone.volume.get, "m^3", "ft^3")
    end
    if volume <= 0
      fail "Could not find any volume."
    end

    return volume
  end

  # Calculates space heights as the max z coordinate minus the min z coordinate
  def self.get_height_of_spaces(spaces)
    minzs = []
    maxzs = []
    spaces.each do |space|
      zvalues = self.getSurfaceZValues(space.surfaces)
      minzs << zvalues.min + UnitConversions.convert(space.zOrigin, "m", "ft")
      maxzs << zvalues.max + UnitConversions.convert(space.zOrigin, "m", "ft")
    end
    return maxzs.max - minzs.min
  end

  def self.get_max_z_of_spaces(spaces)
    maxzs = []
    spaces.each do |space|
      zvalues = self.getSurfaceZValues(space.surfaces)
      maxzs << zvalues.max + UnitConversions.convert(space.zOrigin, "m", "ft")
    end
    return maxzs.max
  end

  # Return an array of z values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
  def self.getSurfaceZValues(surfaceArray)
    zValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        zValueArray << UnitConversions.convert(vertex.z, "m", "ft")
      end
    end
    return zValueArray
  end

  # Takes in a list of spaces and returns the total above grade wall area
  def self.calculate_above_grade_wall_area(building)
    wall_area = 0

    building.elements.each("BuildingDetails/Enclosure/Walls/Wall") do |wall|
      wall_values = HPXML.get_wall_values(wall: wall)
      wall_area += wall_values[:area]
    end

    building.elements.each("BuildingDetails/Enclosure/FoundationWalls/FoundationWall") do |fnd_wall|
      fnd_wall_values = HPXML.get_foundation_wall_values(foundation_wall: fnd_wall)
      height = fnd_wall_values[:height]
      area = fnd_wall_values[:area]
      depth_below_grade = fnd_wall_values[:depth_below_grade]
      width = area / height
      wall_area += width * (height - depth_below_grade)
    end

    building.elements.each("BuildingDetails/Enclosure/RimJoists/RimJoist") do |rim_joist|
      rim_joist_values = HPXML.get_rim_joist_values(rim_joist: rim_joist)
      wall_area += rim_joist_values[:area]
    end

    return wall_area
  end

  def self.calculate_above_grade_exterior_wall_area(building)
    wall_area = 0

    building.elements.each("BuildingDetails/Enclosure/Walls/Wall") do |wall|
      wall_values = HPXML.get_wall_values(wall: wall)

      next unless ["living space", "attic - conditioned", "basement - conditioned", "crawlspace - conditioned", "garage - conditioned"].include? wall_values[:interior_adjacent_to]
      next if wall_values[:exterior_adjacent_to] != "outside"

      wall_area += wall_values[:area]
    end

    building.elements.each("BuildingDetails/Enclosure/FoundationWalls/FoundationWall") do |fnd_wall|
      fnd_wall_values = HPXML.get_foundation_wall_values(foundation_wall: fnd_wall)

      next unless ["living space", "attic - conditioned", "basement - conditioned", "crawlspace - conditioned", "garage - conditioned"].include? fnd_wall_values[:interior_adjacent_to]
      next if fnd_wall_values[:exterior_adjacent_to] != "ground"

      height = fnd_wall_values[:height]
      area = fnd_wall_values[:area]
      depth_below_grade = fnd_wall_values[:depth_below_grade]
      width = area / height
      wall_area += width * (height - depth_below_grade)
    end

    building.elements.each("BuildingDetails/Enclosure/RimJoists/RimJoist") do |rim_joist|
      rim_joist_values = HPXML.get_rim_joist_values(rim_joist: rim_joist)

      next unless ["living space", "attic - conditioned", "basement - conditioned", "crawlspace - conditioned", "garage - conditioned"].include? rim_joist_values[:interior_adjacent_to]
      next if rim_joist_values[:exterior_adjacent_to] != "outside"

      wall_area += rim_joist_values[:area]
    end

    return wall_area
  end

  def self.get_space_type(space_or_zone)
    if space_or_zone.is_a? OpenStudio::Model::Space
      return space_or_zone.spaceType.get.standardsSpaceType.get
    elsif space_or_zone.is_a? OpenStudio::Model::ThermalZone
      return space_or_zone.spaces[0].spaceType.get.standardsSpaceType.get
    end
  end

  def self.process_occupants(model, num_occ, occ_gain, sens_frac, lat_frac, weekday_sch, weekend_sch, monthly_sch,
                             cfa, nbeds, space)

    # Error checking
    if sens_frac < 0 or sens_frac > 1
      fail "Sensible fraction must be greater than or equal to 0 and less than or equal to 1."
    end
    if lat_frac < 0 or lat_frac > 1
      fail "Latent fraction must be greater than or equal to 0 and less than or equal to 1."
    end
    if lat_frac + sens_frac > 1
      fail "Sum of sensible and latent fractions must be less than or equal to 1."
    end

    activity_per_person = UnitConversions.convert(occ_gain, "Btu/hr", "W")

    # Hard-coded convective, radiative, latent, and lost fractions
    occ_lat = lat_frac
    occ_sens = sens_frac
    occ_conv = 0.442 * occ_sens
    occ_rad = 0.558 * occ_sens
    occ_lost = 1 - occ_lat - occ_conv - occ_rad

    space_obj_name = "#{Constants.ObjectNameOccupants}"
    space_num_occ = num_occ * UnitConversions.convert(space.floorArea, "m^2", "ft^2") / cfa

    # Create schedule
    people_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameOccupants + " schedule", weekday_sch, weekend_sch, monthly_sch, mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = true, create_sch_object = true, schedule_type_limits_name = Constants.ScheduleTypeLimitsFraction)

    # Create schedule
    activity_sch = OpenStudio::Model::ScheduleRuleset.new(model, activity_per_person)

    # Add people definition for the occ
    occ_def = OpenStudio::Model::PeopleDefinition.new(model)
    occ = OpenStudio::Model::People.new(occ_def)
    occ.setName(space_obj_name)
    occ.setSpace(space)
    occ_def.setName(space_obj_name)
    occ_def.setNumberOfPeopleCalculationMethod("People", 1)
    occ_def.setNumberofPeople(space_num_occ)
    occ_def.setFractionRadiant(occ_rad)
    occ_def.setSensibleHeatFraction(occ_sens)
    occ_def.setMeanRadiantTemperatureCalculationType("ZoneAveraged")
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
