# frozen_string_literal: true

# Collection of methods to get, add, assign, create, etc. geometry-related OpenStudio objects.
module Geometry
  # Get the largest z difference for a surface.
  #
  # @param surface [OpenStudio::Model::Surface] an OpenStudio::Model::Surface object
  # @return [Double] the max z value minus the min x value
  def self.get_surface_height(surface:)
    zvalues = get_surface_z_values(surfaceArray: [surface])
    zrange = zvalues.max - zvalues.min
    return zrange
  end

  # Return an array of x values for surfaces passed in.
  # The values will be relative to the parent origin.
  # This was intended for spaces.
  #
  # @param surfaceArray [Array<OpenStudio::Model::Surface>] array of OpenStudio::Model::Surface objects
  # @return [Array<Double>] array of x-coordinates (ft)
  def self.get_surface_x_values(surfaceArray:)
    xValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        xValueArray << UnitConversions.convert(vertex.x, 'm', 'ft').round(5)
      end
    end
    return xValueArray
  end

  # Return an array of y values for surfaces passed in.
  # The values will be relative to the parent origin.
  # This was intended for spaces.
  #
  # @param surfaceArray [Array<OpenStudio::Model::Surface>] array of OpenStudio::Model::Surface objects
  # @return [Array<Double>] array of y-coordinates (ft)
  def self.get_surface_y_values(surfaceArray:)
    yValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        yValueArray << UnitConversions.convert(vertex.y, 'm', 'ft').round(5)
      end
    end
    return yValueArray
  end

  # Return an array of z values for surfaces passed in.
  # The values will be relative to the parent origin.
  # This was intended for spaces.
  #
  # @param surfaceArray [Array<OpenStudio::Model::Surface>] array of OpenStudio::Model::Surface objects
  # @return [Array<Double>] array of z-coordinates (ft)
  def self.get_surface_z_values(surfaceArray:)
    # Return an array of z values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
    zValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        zValueArray << UnitConversions.convert(vertex.z, 'm', 'ft').round(5)
      end
    end
    return zValueArray
  end

  # Get the default number of occupants.
  #
  # @param nbeds [Integer] Number of bedrooms in the dwelling unit
  # @return [Double] Number of occupants in the dwelling unit
  def self.get_occupancy_default_num(nbeds:)
    return Float(nbeds) # Per ANSI 301 for an asset calculation
  end

  # Create space and zone based on contents of spaces and value of location.
  # Set a "dwelling unit multiplier" equal to the number of similar units represented.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param spaces [Hash] keys are locations and values are OpenStudio::Model::Space objects
  # @param location [String] HPXML location
  # @param zone_multiplier [Integer] the number of similar zones represented
  # @return [OpenStudio::Model::Space, nil] updated spaces hash if location is not already a key
  def self.create_space_and_zone(model:,
                                 spaces:,
                                 location:,
                                 zone_multiplier:)
    if not spaces.keys.include? location
      thermal_zone = OpenStudio::Model::ThermalZone.new(model)
      thermal_zone.setName(location)
      thermal_zone.additionalProperties.setFeature('ObjectType', location)
      thermal_zone.setMultiplier(zone_multiplier)

      space = OpenStudio::Model::Space.new(model)
      space.setName(location)

      space.setThermalZone(thermal_zone)
      spaces[location] = space
    end
  end

  # TODO
  #
  # @param length [TODO] TODO
  # @param width [TODO] TODO
  # @param z_origin [TODO] TODO
  # @param azimuth [TODO] TODO
  # @param tilt [TODO] TODO
  # @param add_buffer [TODO] TODO
  # @return [TODO] TODO
  def self.create_roof_vertices(length:,
                                width:,
                                z_origin:,
                                azimuth:,
                                tilt:,
                                add_buffer: false)
    length = UnitConversions.convert(length, 'ft', 'm')
    width = UnitConversions.convert(width, 'ft', 'm')
    z_origin = UnitConversions.convert(z_origin, 'ft', 'm')

    if add_buffer
      buffer = calculate_subsurface_parent_buffer(length: length, width: width)
      buffer /= 2.0 # Buffer on each side
    else
      buffer = 0
    end

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new(length / 2 + buffer, -width / 2 - buffer, 0)
    vertices << OpenStudio::Point3d.new(length / 2 + buffer, width / 2 + buffer, 0)
    vertices << OpenStudio::Point3d.new(-length / 2 - buffer, width / 2 + buffer, 0)
    vertices << OpenStudio::Point3d.new(-length / 2 - buffer, -width / 2 - buffer, 0)

    # Rotate about the x axis
    m = OpenStudio::Matrix.new(4, 4, 0)
    m[0, 0] = 1
    m[1, 1] = Math::cos(Math::atan(tilt))
    m[1, 2] = -Math::sin(Math::atan(tilt))
    m[2, 1] = Math::sin(Math::atan(tilt))
    m[2, 2] = Math::cos(Math::atan(tilt))
    m[3, 3] = 1
    transformation = OpenStudio::Transformation.new(m)
    vertices = transformation * vertices

    # Rotate about the z axis
    azimuth_rad = UnitConversions.convert(azimuth, 'deg', 'rad')
    rad180 = UnitConversions.convert(180, 'deg', 'rad')
    m = OpenStudio::Matrix.new(4, 4, 0)
    m[0, 0] = Math::cos(rad180 - azimuth_rad)
    m[1, 1] = Math::cos(rad180 - azimuth_rad)
    m[0, 1] = -Math::sin(rad180 - azimuth_rad)
    m[1, 0] = Math::sin(rad180 - azimuth_rad)
    m[2, 2] = 1
    m[3, 3] = 1
    transformation = OpenStudio::Transformation.new(m)
    vertices = transformation * vertices

    # Shift up by z
    new_vertices = OpenStudio::Point3dVector.new
    vertices.each do |vertex|
      new_vertices << OpenStudio::Point3d.new(vertex.x, vertex.y, vertex.z + z_origin)
    end

    return new_vertices
  end

  # For an array of roof surfaces, get the maximum tilt.
  #
  # @param surfaces [Array<OpenStudio::Model::Surface>] array of OpenStudio::Model::Surface objects
  # @return [Double] the maximum of surface tilts (degrees)
  def self.get_roof_pitch(surfaces)
    tilts = []
    surfaces.each do |surface|
      next if surface.surfaceType != EPlus::SurfaceTypeRoofCeiling
      next if (surface.outsideBoundaryCondition != EPlus::BoundaryConditionOutdoors) && (surface.outsideBoundaryCondition != EPlus::BoundaryConditionAdiabatic)

      tilts << surface.tilt
    end
    return UnitConversions.convert(tilts.max, 'rad', 'deg')
  end

  # Create vertices for a vertical plane based on length, height, z origin, azimuth, presence of a buffer, and any subsurface area.
  #
  # @param length [Double] length of the wall (ft)
  # @param height [Double] height of the wall (ft)
  # @param z_origin [Double] The z-coordinate for which the length and height are relative (ft)
  # @param azimuth [Double] azimuth (degrees)
  # @param add_buffer [Boolean] whether to use a buffer on each side of a subsurface
  # @param subsurface_area [Double] the area of a subsurface within the parent surface (ft2)
  # @return [OpenStudio::Point3dVector] an array of points
  def self.create_wall_vertices(length:,
                                height:,
                                z_origin:,
                                azimuth:,
                                add_buffer: false,
                                subsurface_area: 0)
    length = UnitConversions.convert(length, 'ft', 'm')
    height = UnitConversions.convert(height, 'ft', 'm')
    z_origin = UnitConversions.convert(z_origin, 'ft', 'm')

    if add_buffer
      buffer = calculate_subsurface_parent_buffer(length: length, width: height)
      buffer /= 2.0 # Buffer on each side
    else
      buffer = 0
    end

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new(-length / 2 - buffer, 0, z_origin - buffer)
    vertices << OpenStudio::Point3d.new(-length / 2 - buffer, 0, z_origin + height + buffer)
    if subsurface_area > 0
      subsurface_area = UnitConversions.convert(subsurface_area, 'ft^2', 'm^2')
      sub_length = length / 10.0
      sub_height = subsurface_area / sub_length
      if sub_height >= height
        sub_height = height - 0.1
        sub_length = subsurface_area / sub_height
      end
      vertices << OpenStudio::Point3d.new(length / 2 - sub_length + buffer, 0, z_origin + height + buffer)
      vertices << OpenStudio::Point3d.new(length / 2 - sub_length + buffer, 0, z_origin + height - sub_height + buffer)
      vertices << OpenStudio::Point3d.new(length / 2 + buffer, 0, z_origin + height - sub_height + buffer)
    else
      vertices << OpenStudio::Point3d.new(length / 2 + buffer, 0, z_origin + height + buffer)
    end
    vertices << OpenStudio::Point3d.new(length / 2 + buffer, 0, z_origin - buffer)

    # Rotate about the z axis
    azimuth_rad = UnitConversions.convert(azimuth, 'deg', 'rad')
    m = OpenStudio::Matrix.new(4, 4, 0)
    m[0, 0] = Math::cos(-azimuth_rad)
    m[1, 1] = Math::cos(-azimuth_rad)
    m[0, 1] = -Math::sin(-azimuth_rad)
    m[1, 0] = Math::sin(-azimuth_rad)
    m[2, 2] = 1
    m[3, 3] = 1
    transformation = OpenStudio::Transformation.new(m)

    return transformation * vertices
  end

  # Reverse the vertices after calling create_floor_vertices with the same argument values.
  #
  # @param length [TODO] TODO
  # @param width [TODO] TODO
  # @param z_origin [Double] The z-coordinate for which the length and width are relative (ft)
  # @param default_azimuths [TODO] TODO
  # @return [TODO] TODO
  def self.create_ceiling_vertices(length:,
                                   width:,
                                   z_origin:,
                                   default_azimuths:)
    return OpenStudio::reverse(create_floor_vertices(length: length, width: width, z_origin: z_origin, default_azimuths: default_azimuths))
  end

  # TODO
  #
  # @param length [TODO] TODO
  # @param width [TODO] TODO
  # @param z_origin [Double] The z-coordinate for which the length and width are relative (ft)
  # @param default_azimuths [TODO] TODO
  # @return [TODO] TODO
  def self.create_floor_vertices(length:,
                                 width:,
                                 z_origin:,
                                 default_azimuths:)
    length = UnitConversions.convert(length, 'ft', 'm')
    width = UnitConversions.convert(width, 'ft', 'm')
    z_origin = UnitConversions.convert(z_origin, 'ft', 'm')

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new(-length / 2, -width / 2, z_origin)
    vertices << OpenStudio::Point3d.new(-length / 2, width / 2, z_origin)
    vertices << OpenStudio::Point3d.new(length / 2, width / 2, z_origin)
    vertices << OpenStudio::Point3d.new(length / 2, -width / 2, z_origin)

    # Rotate about the z axis
    # This is not strictly needed, but will make the floor edges
    # parallel to the walls for a better geometry rendering.
    azimuth_rad = UnitConversions.convert(default_azimuths[0], 'deg', 'rad')
    m = OpenStudio::Matrix.new(4, 4, 0)
    m[0, 0] = Math::cos(-azimuth_rad)
    m[1, 1] = Math::cos(-azimuth_rad)
    m[0, 1] = -Math::sin(-azimuth_rad)
    m[1, 0] = Math::sin(-azimuth_rad)
    m[2, 2] = 1
    m[3, 3] = 1
    transformation = OpenStudio::Transformation.new(m)

    return transformation * vertices
  end

  # Set calculated zone volumes for HPXML locations on OpenStudio Thermal Zone and Space objects.
  # TODO why? for reporting?
  #
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param apply_ashrae140_assumptions [Boolean] TODO
  # @return [nil]
  def self.set_zone_volumes(spaces:,
                            hpxml_bldg:,
                            apply_ashrae140_assumptions:)
    # Conditioned space
    volume = UnitConversions.convert(hpxml_bldg.building_construction.conditioned_building_volume, 'ft^3', 'm^3')
    spaces[HPXML::LocationConditionedSpace].thermalZone.get.setVolume(volume)
    spaces[HPXML::LocationConditionedSpace].setVolume(volume)

    # Basement, crawlspace, garage
    spaces.keys.each do |location|
      next unless [HPXML::LocationBasementUnconditioned, HPXML::LocationCrawlspaceUnvented, HPXML::LocationCrawlspaceVented, HPXML::LocationGarage].include? location

      volume = UnitConversions.convert(calculate_zone_volume(hpxml_bldg: hpxml_bldg, location: location), 'ft^3', 'm^3')
      spaces[location].thermalZone.get.setVolume(volume)
      spaces[location].setVolume(volume)
    end

    # Attic
    spaces.keys.each do |location|
      next unless [HPXML::LocationAtticUnvented, HPXML::LocationAtticVented].include? location

      if apply_ashrae140_assumptions
        volume = UnitConversions.convert(3463, 'ft^3', 'm^3') # Hardcode the attic volume to match ASHRAE 140 Table 7-2 specification
      else
        volume = UnitConversions.convert(calculate_zone_volume(hpxml_bldg: hpxml_bldg, location: location), 'ft^3', 'm^3')
      end

      spaces[location].thermalZone.get.setVolume(volume)
      spaces[location].setVolume(volume)
    end
  end

  # Re-position surfaces so as to not shade each other and to make it easier to visualize the building.
  # Horizontally pushes out OpenStudio::Model::Surface, OpenStudio::Model::SubSurface, and OpenStudio::Model::ShadingSurface objects.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param walls_top [Double] the total height of the dwelling unit
  # @return [nil]
  def self.explode_surfaces(model:,
                            hpxml_bldg:,
                            walls_top:)
    gap_distance = UnitConversions.convert(10.0, 'ft', 'm') # distance between surfaces of the same azimuth
    rad90 = UnitConversions.convert(90, 'deg', 'rad')

    # Determine surfaces to shift and distance with which to explode surfaces horizontally outward
    surfaces = []
    azimuth_lengths = {}
    model.getSurfaces.sort.each do |surface|
      next unless [EPlus::SurfaceTypeWall, EPlus::SurfaceTypeRoofCeiling].include? surface.surfaceType
      next unless [EPlus::BoundaryConditionOutdoors, EPlus::BoundaryConditionFoundation, EPlus::BoundaryConditionAdiabatic, EPlus::BoundaryConditionCoefficients].include? surface.outsideBoundaryCondition
      next if surface.additionalProperties.getFeatureAsDouble('Tilt').get <= 0 # skip flat roofs

      surfaces << surface
      azimuth = surface.additionalProperties.getFeatureAsInteger('Azimuth').get
      if azimuth_lengths[azimuth].nil?
        azimuth_lengths[azimuth] = 0.0
      end
      azimuth_lengths[azimuth] += surface.additionalProperties.getFeatureAsDouble('Length').get + gap_distance
    end
    max_azimuth_length = azimuth_lengths.values.max

    # Using the max length for a given azimuth, calculate the apothem (radius of the incircle) of a regular
    # n-sided polygon to create the smallest polygon possible without self-shading. The number of polygon
    # sides is defined by the minimum difference between two azimuths.
    min_azimuth_diff = 360
    azimuths_sorted = azimuth_lengths.keys.sort
    azimuths_sorted.each_with_index do |az, idx|
      diff1 = (az - azimuths_sorted[(idx + 1) % azimuths_sorted.size]).abs
      diff2 = 360.0 - diff1 # opposite direction
      if diff1 < min_azimuth_diff
        min_azimuth_diff = diff1
      end
      if diff2 < min_azimuth_diff
        min_azimuth_diff = diff2
      end
    end
    if min_azimuth_diff > 0
      nsides = [(360.0 / min_azimuth_diff).ceil, 4].max # assume rectangle at the minimum
    else
      nsides = 4
    end
    explode_distance = max_azimuth_length / (2.0 * Math.tan(UnitConversions.convert(180.0 / nsides, 'deg', 'rad')))

    add_neighbor_shading(model: model, length: max_azimuth_length, hpxml_bldg: hpxml_bldg, walls_top: walls_top)

    # Initial distance of shifts at 90-degrees to horizontal outward
    azimuth_side_shifts = {}
    azimuth_lengths.keys.each do |azimuth|
      azimuth_side_shifts[azimuth] = max_azimuth_length / 2.0
    end

    # Explode neighbors
    model.getShadingSurfaceGroups.each do |shading_group|
      next unless shading_group.name.to_s == Constants::ObjectTypeNeighbors

      shading_group.shadingSurfaces.each do |shading_surface|
        azimuth = shading_surface.additionalProperties.getFeatureAsInteger('Azimuth').get
        azimuth_rad = UnitConversions.convert(azimuth, 'deg', 'rad')
        distance = shading_surface.additionalProperties.getFeatureAsDouble('Distance').get

        unless azimuth_lengths.keys.include? azimuth
          fail "A neighbor building has an azimuth (#{azimuth}) not equal to the azimuth of any wall."
        end

        # Push out horizontally
        distance += explode_distance
        transformation = get_surface_transformation(offset: distance, x: Math::sin(azimuth_rad), y: Math::cos(azimuth_rad), z: 0)

        shading_surface.setVertices(transformation * shading_surface.vertices)
      end
    end

    # Explode walls, windows, doors, roofs, and skylights
    surfaces_moved = []

    surfaces.sort.each do |surface|
      next if surface.additionalProperties.getFeatureAsDouble('Tilt').get <= 0 # skip flat roofs

      if surface.adjacentSurface.is_initialized
        next if surfaces_moved.include? surface.adjacentSurface.get
      end

      azimuth = surface.additionalProperties.getFeatureAsInteger('Azimuth').get
      azimuth_rad = UnitConversions.convert(azimuth, 'deg', 'rad')

      # Get associated shading surfaces (e.g., overhangs, interior shading surfaces)
      overhang_surfaces = []
      shading_surfaces = []
      surface.subSurfaces.each do |subsurface|
        next unless subsurface.subSurfaceType == EPlus::SubSurfaceTypeWindow

        subsurface.shadingSurfaceGroups.each do |overhang_group|
          overhang_group.shadingSurfaces.each do |overhang|
            overhang_surfaces << overhang
          end
        end
      end

      # Push out horizontally
      distance = explode_distance

      if surface.surfaceType == EPlus::SurfaceTypeRoofCeiling
        # Ensure pitched surfaces are positioned outward justified with walls, etc.
        tilt = surface.additionalProperties.getFeatureAsDouble('Tilt').get
        width = surface.additionalProperties.getFeatureAsDouble('Width').get
        distance -= 0.5 * Math.cos(Math.atan(tilt)) * width
      end
      transformation = get_surface_transformation(offset: distance, x: Math::sin(azimuth_rad), y: Math::cos(azimuth_rad), z: 0)
      transformation_shade = get_surface_transformation(offset: distance + 0.001, x: Math::sin(azimuth_rad), y: Math::cos(azimuth_rad), z: 0) # Offset slightly from window

      ([surface] + surface.subSurfaces + overhang_surfaces).each do |s|
        s.setVertices(transformation * s.vertices)
      end
      shading_surfaces.each do |s|
        s.setVertices(transformation_shade * s.vertices)
      end
      if surface.adjacentSurface.is_initialized
        surface.adjacentSurface.get.setVertices(transformation * surface.adjacentSurface.get.vertices)
      end

      # Shift at 90-degrees to previous transformation, so surfaces don't overlap and shade each other
      azimuth_side_shifts[azimuth] -= surface.additionalProperties.getFeatureAsDouble('Length').get / 2.0
      transformation_shift = get_surface_transformation(offset: azimuth_side_shifts[azimuth], x: Math::sin(azimuth_rad + rad90), y: Math::cos(azimuth_rad + rad90), z: 0)

      ([surface] + surface.subSurfaces + overhang_surfaces + shading_surfaces).each do |s|
        s.setVertices(transformation_shift * s.vertices)
      end
      if surface.adjacentSurface.is_initialized
        surface.adjacentSurface.get.setVertices(transformation_shift * surface.adjacentSurface.get.vertices)
      end

      azimuth_side_shifts[azimuth] -= (surface.additionalProperties.getFeatureAsDouble('Length').get / 2.0 + gap_distance)

      surfaces_moved << surface
    end
  end

  # Shift units so they aren't right on top and shade each other.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param unit_number [Integer] index number corresponding to an HPXML Building object
  # @return [nil]
  def self.shift_surfaces(model, unit_number)
    y_shift = 200.0 * unit_number # meters

    # shift the unit so it's not right on top of the previous one
    model.getSpaces.sort.each do |space|
      space.setYOrigin(y_shift)
    end

    # shift shading surfaces
    m = OpenStudio::Matrix.new(4, 4, 0)
    m[0, 0] = 1
    m[1, 1] = 1
    m[2, 2] = 1
    m[3, 3] = 1
    m[1, 3] = y_shift
    t = OpenStudio::Transformation.new(m)

    model.getShadingSurfaceGroups.each do |shading_surface_group|
      next if shading_surface_group.space.is_initialized # already got shifted

      shading_surface_group.shadingSurfaces.each do |shading_surface|
        shading_surface.setVertices(t * shading_surface.vertices)
      end
    end
  end

  # TODO
  #
  # @param zone [TODO] TODO
  # @return [TODO] TODO
  def self.get_z_origin_for_zone(zone:)
    z_origins = []
    zone.spaces.each do |space|
      z_origins << UnitConversions.convert(space.zOrigin, 'm', 'ft')
    end
    return z_origins.min
  end

  # Get the surface transformation using the translation matrix defined by an offset multiplied by 3D translation vector (x, y, z).
  # Applying the affine transformation will shift a set of vertices.
  #
  # @param offset [Double] the magnitude of the vector (ft)
  # @param x [Double] the x-coordinate of the translation vector
  # @param y [Double] the y-coordinate of the translation vector
  # @param z [Double] the z-coordinate of the translation vector
  # @return [OpenStudio::Transformation] the OpenStudio transformation object
  def self.get_surface_transformation(offset:,
                                      x:,
                                      y:,
                                      z:)
    x = UnitConversions.convert(x, 'ft', 'm')
    y = UnitConversions.convert(y, 'ft', 'm')
    z = UnitConversions.convert(z, 'ft', 'm')

    m = OpenStudio::Matrix.new(4, 4, 0)
    m[0, 0] = 1
    m[1, 1] = 1
    m[2, 2] = 1
    m[3, 3] = 1
    m[0, 3] = x * offset
    m[1, 3] = y * offset
    m[2, 3] = z.abs * offset

    return OpenStudio::Transformation.new(m)
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param length [TODO] TODO
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param walls_top [TODO] TODO
  # @return [nil]
  def self.add_neighbor_shading(model:,
                                length:,
                                hpxml_bldg:,
                                walls_top:)
    z_origin = 0 # shading surface always starts at grade

    shading_surfaces = []
    hpxml_bldg.neighbor_buildings.each do |neighbor_building|
      height = neighbor_building.height.nil? ? walls_top : neighbor_building.height

      vertices = create_wall_vertices(length: length, height: height, z_origin: z_origin, azimuth: neighbor_building.azimuth)
      shading_surface = OpenStudio::Model::ShadingSurface.new(vertices, model)
      shading_surface.additionalProperties.setFeature('Azimuth', neighbor_building.azimuth)
      shading_surface.additionalProperties.setFeature('Distance', neighbor_building.distance)
      shading_surface.setName("Neighbor azimuth #{neighbor_building.azimuth} distance #{neighbor_building.distance}")

      shading_surfaces << shading_surface
    end

    unless shading_surfaces.empty?
      shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
      shading_surface_group.setName(Constants::ObjectTypeNeighbors)
      shading_surfaces.each do |shading_surface|
        shading_surface.setShadingSurfaceGroup(shading_surface_group)
      end
    end
  end

  # TODO
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param location [String] the location of interest (HPXML::LocationXXX)
  # @return [Double] TODO
  def self.calculate_zone_volume(hpxml_bldg:,
                                 location:)
    if [HPXML::LocationBasementUnconditioned,
        HPXML::LocationCrawlspaceUnvented,
        HPXML::LocationCrawlspaceVented,
        HPXML::LocationGarage].include? location
      floor_area = hpxml_bldg.slabs.select { |s| s.interior_adjacent_to == location }.map { |s| s.area }.sum(0.0)
      height = hpxml_bldg.foundation_walls.select { |w| w.interior_adjacent_to == location }.map { |w| w.height }.max
      if height.nil? # No foundation walls, need to make assumption because HPXML Wall elements don't have a height
        height = { HPXML::LocationBasementUnconditioned => 8,
                   HPXML::LocationCrawlspaceUnvented => 3,
                   HPXML::LocationCrawlspaceVented => 3,
                   HPXML::LocationGarage => 8 }[location]
      end
      return floor_area * height
    elsif [HPXML::LocationAtticUnvented,
           HPXML::LocationAtticVented].include? location
      floor_area = hpxml_bldg.floors.select { |f| [f.interior_adjacent_to, f.exterior_adjacent_to].include? location }.map { |s| s.area }.sum(0.0)
      roofs = hpxml_bldg.roofs.select { |r| r.interior_adjacent_to == location }
      avg_pitch = roofs.map { |r| r.pitch }.sum(0.0) / roofs.size
      # Assume square hip roof for volume calculation
      length = floor_area**0.5
      height = 0.5 * Math.sin(Math.atan(avg_pitch / 12.0)) * length
      return [floor_area * height / 3.0, 0.01].max
    end
  end

  # TODO
  #
  # @param location [String] the general HPXML location
  # @return [Hash] TODO
  def self.get_temperature_scheduled_space_values(location:)
    if location == HPXML::LocationOtherHeatedSpace
      # Average of indoor/outdoor temperatures with minimum of heating setpoint
      return { temp_min: 68,
               indoor_weight: 0.5,
               outdoor_weight: 0.5,
               ground_weight: 0.0,
               f_regain: 0.0 }
    elsif location == HPXML::LocationOtherMultifamilyBufferSpace
      # Average of indoor/outdoor temperatures with minimum of 50 F
      return { temp_min: 50,
               indoor_weight: 0.5,
               outdoor_weight: 0.5,
               ground_weight: 0.0,
               f_regain: 0.0 }
    elsif location == HPXML::LocationOtherNonFreezingSpace
      # Floating with outdoor air temperature with minimum of 40 F
      return { temp_min: 40,
               indoor_weight: 0.0,
               outdoor_weight: 1.0,
               ground_weight: 0.0,
               f_regain: 0.0 }
    elsif location == HPXML::LocationOtherHousingUnit
      # Indoor air temperature
      return { temp_min: nil,
               indoor_weight: 1.0,
               outdoor_weight: 0.0,
               ground_weight: 0.0,
               f_regain: 0.0 }
    elsif location == HPXML::LocationExteriorWall
      # Average of indoor/outdoor temperatures
      return { temp_min: nil,
               indoor_weight: 0.5,
               outdoor_weight: 0.5,
               ground_weight: 0.0,
               f_regain: 0.5 } # From LBNL's "Technical Background for default values used for Forced Air Systems in Proposed ASHRAE Standard 152P"
    elsif location == HPXML::LocationUnderSlab
      # Ground temperature
      return { temp_min: nil,
               indoor_weight: 0.0,
               outdoor_weight: 0.0,
               ground_weight: 1.0,
               f_regain: 0.83 } # From LBNL's "Technical Background for default values used for Forced Air Systems in Proposed ASHRAE Standard 152P"
    elsif location == HPXML::LocationManufacturedHomeBelly
      # From LBNL's "Technical Background for default values used for Forced Air Systems in Proposed ASHRAE Standard 152P"
      # 3.5 Manufactured House Belly Pan Temperatures
      # FUTURE: Consider modeling the belly as a separate thermal zone so that we dynamically calculate temperatures.
      return { temp_min: nil,
               indoor_weight: 1.0,
               outdoor_weight: 0.0,
               ground_weight: 0.0,
               f_regain: 0.62 }
    end
    fail "Unhandled location: #{location}."
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param surface [OpenStudio::Model::Surface] an OpenStudio::Model::Surface object
  # @param hpxml_surface [HPXML::Wall or HPXML::Roof or HPXML::RimJoist or HPXML::FoundationWall or HPXML::Slab] any HPXML surface
  # @return [nil]
  def self.set_surface_interior(model, spaces, surface, hpxml_surface, hpxml_bldg)
    interior_adjacent_to = hpxml_surface.interior_adjacent_to
    if HPXML::conditioned_below_grade_locations.include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, HPXML::LocationConditionedSpace, hpxml_bldg))
    else
      surface.setSpace(create_or_get_space(model, spaces, interior_adjacent_to, hpxml_bldg))
    end
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param surface [OpenStudio::Model::Surface] an OpenStudio::Model::Surface object
  # @param hpxml_surface [HPXML::Wall or HPXML::Roof or HPXML::RimJoist or HPXML::FoundationWall or HPXML::Slab] any HPXML surface
  # @return [nil]
  def self.set_surface_exterior(model, spaces, surface, hpxml_surface, hpxml_bldg)
    exterior_adjacent_to = hpxml_surface.exterior_adjacent_to
    is_adiabatic = hpxml_surface.is_adiabatic
    if [HPXML::LocationOutside, HPXML::LocationManufacturedHomeUnderBelly].include? exterior_adjacent_to
      surface.setOutsideBoundaryCondition(EPlus::BoundaryConditionOutdoors)
    elsif exterior_adjacent_to == HPXML::LocationGround
      surface.setOutsideBoundaryCondition(EPlus::BoundaryConditionFoundation)
    elsif is_adiabatic
      surface.setOutsideBoundaryCondition(EPlus::BoundaryConditionAdiabatic)
    elsif [HPXML::LocationOtherHeatedSpace, HPXML::LocationOtherMultifamilyBufferSpace,
           HPXML::LocationOtherNonFreezingSpace, HPXML::LocationOtherHousingUnit].include? exterior_adjacent_to
      set_surface_otherside_coefficients(surface, exterior_adjacent_to, model, spaces)
    elsif HPXML::conditioned_below_grade_locations.include? exterior_adjacent_to
      adjacent_surface = surface.createAdjacentSurface(create_or_get_space(model, spaces, HPXML::LocationConditionedSpace, hpxml_bldg)).get
      adjacent_surface.additionalProperties.setFeature('SurfaceType', surface.additionalProperties.getFeatureAsString('SurfaceType').get)
    else
      adjacent_surface = surface.createAdjacentSurface(create_or_get_space(model, spaces, exterior_adjacent_to, hpxml_bldg)).get
      adjacent_surface.additionalProperties.setFeature('SurfaceType', surface.additionalProperties.getFeatureAsString('SurfaceType').get)
    end
  end

  # Set its parent surface outside boundary condition, which will be also applied to subsurfaces through OS
  # The parent surface is entirely comprised of the subsurface.
  #
  # @param surface [OpenStudio::Model::Surface] an OpenStudio::Model::Surface object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param hpxml_surface [HPXML::Wall or HPXML::Roof or HPXML::RimJoist or HPXML::FoundationWall or HPXML::Slab] any HPXML surface
  # @return [nil]
  def self.set_subsurface_exterior(surface, spaces, model, hpxml_surface, hpxml_bldg)
    # Subsurface on foundation wall, set it to be adjacent to outdoors
    if hpxml_surface.exterior_adjacent_to == HPXML::LocationGround
      surface.setOutsideBoundaryCondition(EPlus::BoundaryConditionOutdoors)
    else
      set_surface_exterior(model, spaces, surface, hpxml_surface, hpxml_bldg)
    end
  end

  # TODO
  #
  # @param surface [OpenStudio::Model::Surface] an OpenStudio::Model::Surface object
  # @param exterior_adjacent_to [String] Exterior adjacent to location (HPXML::LocationXXX)
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @return [nil]
  def self.set_surface_otherside_coefficients(surface, exterior_adjacent_to, model, spaces)
    otherside_coeffs = nil
    model.getSurfacePropertyOtherSideCoefficientss.each do |c|
      next unless c.name.to_s == exterior_adjacent_to

      otherside_coeffs = c
    end
    if otherside_coeffs.nil?
      # Create E+ other side coefficient object
      otherside_coeffs = OpenStudio::Model::SurfacePropertyOtherSideCoefficients.new(model)
      otherside_coeffs.setName(exterior_adjacent_to)
      otherside_coeffs.setCombinedConvectiveRadiativeFilmCoefficient(UnitConversions.convert(1.0 / Material.AirFilmVertical.rvalue, 'Btu/(hr*ft^2*F)', 'W/(m^2*K)'))
      # Schedule of space temperature, can be shared with water heater/ducts
      sch = get_space_temperature_schedule(model, exterior_adjacent_to, spaces)
      otherside_coeffs.setConstantTemperatureSchedule(sch)
    end
    surface.setSurfacePropertyOtherSideCoefficients(otherside_coeffs)
    surface.setSunExposure(EPlus::SurfaceSunExposureNo)
    surface.setWindExposure(EPlus::SurfaceWindExposureNo)
  end

  # Create outside boundary schedules to be actuated by EMS,
  # can be shared by any surface, duct adjacent to / located in those spaces.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param location [String] the location of interest (HPXML::LocationXXX)
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @return [OpenStudio::Model::ScheduleConstant] OpenStudio ScheduleConstant object
  def self.get_space_temperature_schedule(model, location, spaces)
    # return if already exists
    model.getScheduleConstants.each do |sch|
      next unless sch.name.to_s == location

      return sch
    end

    sch = OpenStudio::Model::ScheduleConstant.new(model)
    sch.setName(location)
    sch.additionalProperties.setFeature('ObjectType', location)

    space_values = get_temperature_scheduled_space_values(location: location)

    htg_weekday_setpoints, htg_weekend_setpoints = HVAC.get_default_heating_setpoint(HPXML::HVACControlTypeManual, @eri_version)
    if htg_weekday_setpoints.split(', ').uniq.size == 1 && htg_weekend_setpoints.split(', ').uniq.size == 1 && htg_weekday_setpoints.split(', ').uniq == htg_weekend_setpoints.split(', ').uniq
      default_htg_sp = htg_weekend_setpoints.split(', ').uniq[0].to_f # F
    else
      fail 'Unexpected heating setpoints.'
    end

    clg_weekday_setpoints, clg_weekend_setpoints = HVAC.get_default_cooling_setpoint(HPXML::HVACControlTypeManual, @eri_version)
    if clg_weekday_setpoints.split(', ').uniq.size == 1 && clg_weekend_setpoints.split(', ').uniq.size == 1 && clg_weekday_setpoints.split(', ').uniq == clg_weekend_setpoints.split(', ').uniq
      default_clg_sp = clg_weekend_setpoints.split(', ').uniq[0].to_f # F
    else
      fail 'Unexpected cooling setpoints.'
    end

    if location == HPXML::LocationOtherHeatedSpace
      if spaces[HPXML::LocationConditionedSpace].thermalZone.get.thermostatSetpointDualSetpoint.is_initialized
        # Create a sensor to get dynamic heating setpoint
        htg_sch = spaces[HPXML::LocationConditionedSpace].thermalZone.get.thermostatSetpointDualSetpoint.get.heatingSetpointTemperatureSchedule.get
        sensor_htg_spt = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
        sensor_htg_spt.setName('htg_spt')
        sensor_htg_spt.setKeyName(htg_sch.name.to_s)
        space_values[:temp_min] = sensor_htg_spt.name.to_s
      else
        # No HVAC system; use the defaulted heating setpoint.
        space_values[:temp_min] = default_htg_sp # F
      end
    end

    # Schedule type limits compatible
    schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
    schedule_type_limits.setUnitType('Temperature')
    sch.setScheduleTypeLimits(schedule_type_limits)

    # Sensors
    if space_values[:indoor_weight] > 0
      if not spaces[HPXML::LocationConditionedSpace].thermalZone.get.thermostatSetpointDualSetpoint.is_initialized
        # No HVAC system; use the average of defaulted heating/cooling setpoints.
        sensor_ia = UnitConversions.convert((default_htg_sp + default_clg_sp) / 2.0, 'F', 'C')
      else
        sensor_ia = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Air Temperature')
        sensor_ia.setName('cond_zone_temp')
        sensor_ia.setKeyName(spaces[HPXML::LocationConditionedSpace].thermalZone.get.name.to_s)
        sensor_ia = sensor_ia.name
      end
    end

    if space_values[:outdoor_weight] > 0
      sensor_oa = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Drybulb Temperature')
      sensor_oa.setName('oa_temp')
    end

    if space_values[:ground_weight] > 0
      sensor_gnd = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Surface Ground Temperature')
      sensor_gnd.setName('ground_temp')
    end

    actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(sch, *EPlus::EMSActuatorScheduleConstantValue)
    actuator.setName("#{location.gsub(' ', '_').gsub('-', '_')}_temp_sch")

    # EMS to actuate schedule
    program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    program.setName("#{location.gsub('-', '_')} Temperature Program")
    program.addLine("Set #{actuator.name} = 0.0")
    if not sensor_ia.nil?
      program.addLine("Set #{actuator.name} = #{actuator.name} + (#{sensor_ia} * #{space_values[:indoor_weight]})")
    end
    if not sensor_oa.nil?
      program.addLine("Set #{actuator.name} = #{actuator.name} + (#{sensor_oa.name} * #{space_values[:outdoor_weight]})")
    end
    if not sensor_gnd.nil?
      program.addLine("Set #{actuator.name} = #{actuator.name} + (#{sensor_gnd.name} * #{space_values[:ground_weight]})")
    end
    if not space_values[:temp_min].nil?
      if space_values[:temp_min].is_a? String
        min_temp_c = space_values[:temp_min]
      else
        min_temp_c = UnitConversions.convert(space_values[:temp_min], 'F', 'C')
      end
      program.addLine("If #{actuator.name} < #{min_temp_c}")
      program.addLine("Set #{actuator.name} = #{min_temp_c}")
      program.addLine('EndIf')
    end

    program_cm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_cm.setName("#{program.name} calling manager")
    program_cm.setCallingPoint('EndOfSystemTimestepAfterHVACReporting')
    program_cm.addProgram(program)

    return sch
  end

  # Returns an OS:Space, or temperature OS:Schedule for a MF space, or nil if outside
  # Should be called when the object's energy use is sensitive to ambient temperature
  # (e.g., water heaters, ducts, and refrigerators).
  #
  # @param location [String] the location of interest (HPXML::LocationXXX)
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @return [OpenStudio::Model::Space or OpenStudio::Model::ScheduleConstant] OpenStudio Space or Schedule object
  def self.get_space_or_schedule_from_location(location, model, spaces)
    return if [HPXML::LocationOtherExterior,
               HPXML::LocationOutside,
               HPXML::LocationRoofDeck].include? location

    sch = nil
    space = nil
    if [HPXML::LocationOtherHeatedSpace,
        HPXML::LocationOtherHousingUnit,
        HPXML::LocationOtherMultifamilyBufferSpace,
        HPXML::LocationOtherNonFreezingSpace,
        HPXML::LocationExteriorWall,
        HPXML::LocationUnderSlab].include? location
      # if located in spaces where we don't model a thermal zone, create and return temperature schedule
      sch = get_space_temperature_schedule(model, location, spaces)
    else
      space = get_space_from_location(location, spaces)
    end

    return space, sch
  end

  # Returns an OS:Space, or nil if a MF space or outside
  # Should be called when the object's energy use is NOT sensitive to ambient temperature
  # (e.g., appliances).
  #
  # @param location [String] the location of interest (HPXML::LocationXXX)
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @return [OpenStudio::Model::Space] OpenStudio Space object
  def self.get_space_from_location(location, spaces)
    return if [HPXML::LocationOutside,
               HPXML::LocationOtherHeatedSpace,
               HPXML::LocationOtherHousingUnit,
               HPXML::LocationOtherMultifamilyBufferSpace,
               HPXML::LocationOtherNonFreezingSpace].include? location

    if HPXML::conditioned_locations.include? location
      location = HPXML::LocationConditionedSpace
    end

    return spaces[location]
  end

  # Calculates space heights as the max z coordinate minus the min z coordinate.
  #
  # @param spaces [Array<OpenStudio::Model::Space>] array of OpenStudio::Model::Space objects
  # @return [Double] max z coordinate minus min z coordinate for a collection of spaces (ft)
  def self.get_height_of_spaces(spaces:)
    minzs = []
    maxzs = []
    spaces.each do |space|
      zvalues = get_surface_z_values(surfaceArray: space.surfaces)
      minzs << zvalues.min + UnitConversions.convert(space.zOrigin, 'm', 'ft')
      maxzs << zvalues.max + UnitConversions.convert(space.zOrigin, 'm', 'ft')
    end
    return maxzs.max - minzs.min
  end

  # TODO
  #
  # @param surface [OpenStudio::Model::Surface] an OpenStudio::Model::Surface object
  # @return [TODO] TODO
  def self.get_surface_length(surface:)
    xvalues = get_surface_x_values(surfaceArray: [surface])
    yvalues = get_surface_y_values(surfaceArray: [surface])
    xrange = xvalues.max - xvalues.min
    yrange = yvalues.max - yvalues.min
    if xrange > yrange
      return xrange
    end

    return yrange
  end

  # Calculates the minimum buffer distance that the parent surface
  # needs relative to the subsurface in order to prevent E+ warnings
  # about "Very small surface area".
  #
  # @param length [Double] length of the subsurface (m)
  # @param width [Double] width of the subsurface (m)
  # @return [Double] minimum needed buffer distance (m)
  def self.calculate_subsurface_parent_buffer(length:,
                                              width:)
    min_surface_area = 0.005 # m^2
    return 0.5 * (((length + width)**2 + 4.0 * min_surface_area)**0.5 - length - width)
  end

  # For a provided HPXML Location, create an OpenStudio Space and Thermal Zone if the provided spaces hash doesn't already contain the OpenStudio Space.
  # Otherwise, return the already-created OpenStudio Space for the provided HPXML Location.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param location [String] the location of interest (HPXML::LocationXXX)
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @return [OpenStudio::Model::Space] the OpenStudio::Model::Space object corresponding to HPXML::LocationXXX
  def self.create_or_get_space(model, spaces, location, hpxml_bldg)
    if spaces[location].nil?
      create_space_and_zone(model: model, spaces: spaces, location: location, zone_multiplier: hpxml_bldg.building_construction.number_of_units)
    end
    return spaces[location]
  end
end
