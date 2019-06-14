# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'openstudio'
require 'rexml/document'
require 'rexml/xpath'
require 'pathname'
require 'csv'
require_relative "resources/EPvalidator"
require_relative "resources/airflow"
require_relative "resources/constants"
require_relative "resources/constructions"
require_relative "resources/geometry"
require_relative "resources/hotwater_appliances"
require_relative "resources/hvac"
require_relative "resources/hvac_sizing"
require_relative "resources/lighting"
require_relative "resources/location"
require_relative "resources/misc_loads"
require_relative "resources/pv"
require_relative "resources/unit_conversions"
require_relative "resources/util"
require_relative "resources/waterheater"
require_relative "resources/xmlhelper"
require_relative "resources/hpxml"

# start the measure
class HPXMLTranslator < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return "HPXML Translator"
  end

  # human readable description
  def description
    return "Translates HPXML file to OpenStudio Model"
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Measure::OSArgument.makeStringArgument("hpxml_path", true)
    arg.setDisplayName("HPXML File Path")
    arg.setDescription("Absolute (or relative) path of the HPXML file.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument("weather_dir", true)
    arg.setDisplayName("Weather Directory")
    arg.setDescription("Absolute path of the weather directory.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument("schemas_dir", false)
    arg.setDisplayName("HPXML Schemas Directory")
    arg.setDescription("Absolute path of the hpxml schemas directory.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument("epw_output_path", false)
    arg.setDisplayName("EPW Output File Path")
    arg.setDescription("Absolute (or relative) path of the output EPW file.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument("osm_output_path", false)
    arg.setDisplayName("OSM Output File Path")
    arg.setDescription("Absolute (or relative) path of the output OSM file.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument("skip_validation", true)
    arg.setDisplayName("Skip HPXML validation")
    arg.setDescription("If true, only checks for and reports HPXML validation issues if an error occurs during processing. Used for faster runtime.")
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument("map_tsv_dir", false)
    arg.setDisplayName("Map TSV Directory")
    arg.setDescription("Creates TSV files in the specified directory that map some HPXML object names to EnergyPlus object names. Required for ERI calculation.")
    args << arg

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Check for correct versions of OS
    os_version = "2.8.1"
    if OpenStudio.openStudioVersion != os_version
      fail "OpenStudio version #{os_version} is required."
    end

    # assign the user inputs to variables
    hpxml_path = runner.getStringArgumentValue("hpxml_path", user_arguments)
    weather_dir = runner.getStringArgumentValue("weather_dir", user_arguments)
    schemas_dir = runner.getOptionalStringArgumentValue("schemas_dir", user_arguments)
    epw_output_path = runner.getOptionalStringArgumentValue("epw_output_path", user_arguments)
    osm_output_path = runner.getOptionalStringArgumentValue("osm_output_path", user_arguments)
    skip_validation = runner.getBoolArgumentValue("skip_validation", user_arguments)
    map_tsv_dir = runner.getOptionalStringArgumentValue("map_tsv_dir", user_arguments)

    unless (Pathname.new hpxml_path).absolute?
      hpxml_path = File.expand_path(File.join(File.dirname(__FILE__), hpxml_path))
    end
    unless File.exists?(hpxml_path) and hpxml_path.downcase.end_with? ".xml"
      runner.registerError("'#{hpxml_path}' does not exist or is not an .xml file.")
      return false
    end

    hpxml_doc = XMLHelper.parse_file(hpxml_path)

    # Check for invalid HPXML file up front?
    if not skip_validation
      if not validate_hpxml(runner, hpxml_path, hpxml_doc, schemas_dir)
        return false
      end
    end

    begin
      # Weather file
      climate_and_risk_zones_values = HPXML.get_climate_and_risk_zones_values(climate_and_risk_zones: hpxml_doc.elements["/HPXML/Building/BuildingDetails/ClimateandRiskZones"])
      weather_wmo = climate_and_risk_zones_values[:weather_station_wmo]
      epw_path = nil
      CSV.foreach(File.join(weather_dir, "data.csv"), headers: true) do |row|
        next if row["wmo"] != weather_wmo

        epw_path = File.join(weather_dir, row["filename"])
        if not File.exists?(epw_path)
          runner.registerError("'#{epw_path}' could not be found.")
          return false
        end
        cache_path = epw_path.gsub('.epw', '.cache')
        if not File.exists?(cache_path)
          runner.registerError("'#{cache_path}' could not be found.")
          return false
        end
        break
      end
      if epw_path.nil?
        runner.registerError("Weather station WMO '#{weather_wmo}' could not be found in weather/data.csv.")
        return false
      end
      if epw_output_path.is_initialized
        FileUtils.cp(epw_path, epw_output_path.get)
      end

      # Apply Location to obtain weather data
      success, weather = Location.apply(model, runner, epw_path, "NA", "NA")
      return false if not success

      # Create OpenStudio model
      if not OSModel.create(hpxml_doc, runner, model, weather, map_tsv_dir)
        runner.registerError("Unsuccessful creation of OpenStudio model.")
        return false
      end
    rescue Exception => e
      if skip_validation
        # Something went wrong, check for invalid HPXML file now. This was previously
        # skipped to reduce runtime (see https://github.com/NREL/OpenStudio-ERI/issues/47).
        validate_hpxml(runner, hpxml_path, hpxml_doc, schemas_dir)
      end

      # Report exception
      runner.registerError("#{e.message}\n#{e.backtrace.join("\n")}")
      return false
    end

    if osm_output_path.is_initialized
      File.write(osm_output_path.get, model.to_s)
      runner.registerInfo("Wrote file: #{osm_output_path.get}")
    end

    return true
  end

  def validate_hpxml(runner, hpxml_path, hpxml_doc, schemas_dir)
    is_valid = true

    if schemas_dir.is_initialized
      schemas_dir = schemas_dir.get
      unless (Pathname.new schemas_dir).absolute?
        schemas_dir = File.expand_path(File.join(File.dirname(__FILE__), schemas_dir))
      end
      unless Dir.exists?(schemas_dir)
        runner.registerError("'#{schemas_dir}' does not exist.")
        return false
      end
    else
      schemas_dir = nil
    end

    # Validate input HPXML against schema
    if not schemas_dir.nil?
      XMLHelper.validate(hpxml_doc.to_s, File.join(schemas_dir, "HPXML.xsd"), runner).each do |error|
        runner.registerError("#{hpxml_path}: #{error.to_s}")
        is_valid = false
      end
      runner.registerInfo("#{hpxml_path}: Validated against HPXML schema.")
    else
      runner.registerWarning("#{hpxml_path}: No schema dir provided, no HPXML validation performed.")
    end

    # Validate input HPXML against EnergyPlus Use Case
    errors = EnergyPlusValidator.run_validator(hpxml_doc)
    errors.each do |error|
      runner.registerError("#{hpxml_path}: #{error}")
      is_valid = false
    end
    runner.registerInfo("#{hpxml_path}: Validated against HPXML EnergyPlus Use Case.")

    return is_valid
  end
end

class OSModel
  def self.create(hpxml_doc, runner, model, weather, map_tsv_dir)
    # Simulation parameters
    success = add_simulation_params(runner, model)
    return false if not success

    hpxml = hpxml_doc.elements["HPXML"]
    hpxml_values = HPXML.get_hpxml_values(hpxml: hpxml)
    building = hpxml_doc.elements["/HPXML/Building"]
    enclosure = building.elements["BuildingDetails/Enclosure"]

    @eri_version = hpxml_values[:eri_calculation_version]
    fail "Could not find ERI Version" if @eri_version.nil?

    # Global variables
    construction_values = HPXML.get_building_construction_values(building_construction: building.elements["BuildingDetails/BuildingSummary/BuildingConstruction"])
    @cfa = construction_values[:conditioned_floor_area]
    @cfa_ag = @cfa
    enclosure.elements.each("Slabs/Slab[InteriorAdjacentTo='basement - conditioned']") do |slab|
      slab_values = HPXML.get_slab_values(slab: slab)
      @cfa_ag -= slab_values[:area]
    end
    @gfa = 0 # garage floor area
    enclosure.elements.each("Slabs/Slab[InteriorAdjacentTo='garage']") do |garage_slab|
      slab_values = HPXML.get_slab_values(slab: garage_slab)
      @gfa += slab_values[:area]
    end
    @cvolume = construction_values[:conditioned_building_volume]
    @ncfl = construction_values[:number_of_conditioned_floors]
    @ncfl_ag = construction_values[:number_of_conditioned_floors_above_grade]
    @nbeds = construction_values[:number_of_bedrooms]
    @nbaths = construction_values[:number_of_bathrooms]
    if @nbaths.nil?
      @nbaths = Waterheater.get_default_num_bathrooms(@nbeds)
    end
    @has_uncond_bsmnt = !enclosure.elements["*/*[InteriorAdjacentTo='basement - unconditioned' or ExteriorAdjacentTo='basement - unconditioned']"].nil?
    @has_vented_attic = !enclosure.elements["*/*[InteriorAdjacentTo='attic - vented' or ExteriorAdjacentTo='attic - vented']"].nil?
    @has_vented_crawl = !enclosure.elements["*/*[InteriorAdjacentTo='crawlspace - vented' or ExteriorAdjacentTo='crawlspace - vented']"].nil?
    @subsurface_areas_by_surface = calc_subsurface_areas_by_surface(building)
    @default_azimuth = get_default_azimuth(building)
    @min_neighbor_distance = get_min_neighbor_distance(building)

    @hvac_map = {} # mapping between HPXML HVAC systems and model objects
    @dhw_map = {}  # mapping between HPXML Water Heating systems and model objects

    @use_only_ideal_air = false
    if not construction_values[:use_only_ideal_air_system].nil?
      @use_only_ideal_air = construction_values[:use_only_ideal_air_system]
    end

    # Geometry/Envelope

    spaces = {}
    success = add_geometry_envelope(runner, model, building, weather, spaces)
    return false if not success

    # Bedrooms, Occupants

    success = add_num_occupants(runner, model, building)
    return false if not success

    # Hot Water

    success = add_hot_water_and_appliances(runner, model, building, weather, spaces)
    return false if not success

    # HVAC

    @total_frac_remaining_heat_load_served = 1.0
    @total_frac_remaining_cool_load_served = 1.0

    control_zone = get_space_of_type(spaces, Constants.SpaceTypeLiving).thermalZone.get
    slave_zones = get_spaces_of_type(spaces, [Constants.SpaceTypeConditionedBasement]).map { |z| z.thermalZone.get }.compact
    @control_slave_zones_hash = { control_zone => slave_zones }

    success = add_cooling_system(runner, model, building)
    return false if not success

    success = add_heating_system(runner, model, building)
    return false if not success

    success = add_heat_pump(runner, model, building, weather)
    return false if not success

    success = add_residual_hvac(runner, model, building)
    return false if not success

    success = add_setpoints(runner, model, building, weather, spaces)
    return false if not success

    success = add_ceiling_fans(runner, model, building, spaces)
    return false if not success

    # Plug Loads & Lighting

    success = add_mels(runner, model, building, spaces)
    return false if not success

    success = add_lighting(runner, model, building, weather, spaces)
    return false if not success

    # Other

    success = add_airflow(runner, model, building, spaces)
    return false if not success

    success = add_hvac_sizing(runner, model, weather)
    return false if not success

    success = add_fuel_heating_eae(runner, model, building)
    return false if not success

    success = add_photovoltaics(runner, model, building)
    return false if not success

    success = add_building_output_variables(runner, model, map_tsv_dir)
    return false if not success

    return true
  end

  private

  def self.add_simulation_params(runner, model)
    sim = model.getSimulationControl
    sim.setRunSimulationforSizingPeriods(false)

    tstep = model.getTimestep
    tstep.setNumberOfTimestepsPerHour(1)

    shad = model.getShadowCalculation
    shad.setCalculationFrequency(20)
    shad.setMaximumFiguresInShadowOverlapCalculations(200)

    outsurf = model.getOutsideSurfaceConvectionAlgorithm
    outsurf.setAlgorithm('DOE-2')

    insurf = model.getInsideSurfaceConvectionAlgorithm
    insurf.setAlgorithm('TARP')

    zonecap = model.getZoneCapacitanceMultiplierResearchSpecial
    zonecap.setHumidityCapacityMultiplier(15)

    convlim = model.getConvergenceLimits
    convlim.setMinimumSystemTimestep(0)

    return true
  end

  def self.add_geometry_envelope(runner, model, building, weather, spaces)
    @foundation_top, @walls_top = get_foundation_and_walls_top(building)

    heating_season, cooling_season = HVAC.calc_heating_and_cooling_seasons(model, weather, runner)
    return false if heating_season.nil? or cooling_season.nil?

    success = add_roofs(runner, model, building, spaces)
    return false if not success

    success = add_walls(runner, model, building, spaces)
    return false if not success

    success = add_rim_joists(runner, model, building, spaces)
    return false if not success

    success = add_framefloors(runner, model, building, spaces)
    return false if not success

    success = add_foundation_walls_slabs(runner, model, building, spaces)
    return false if not success

    success = add_windows(runner, model, building, spaces, weather, cooling_season)
    return false if not success

    success = add_doors(runner, model, building, spaces)
    return false if not success

    success = add_skylights(runner, model, building, spaces, weather, cooling_season)
    return false if not success

    success = add_conditioned_floor_area(runner, model, building, spaces)
    return false if not success

    success = add_thermal_mass(runner, model, building)
    return false if not success

    success = check_for_errors(runner, model)
    return false if not success

    success = set_zone_volumes(runner, model, building)
    return false if not success

    success = explode_surfaces(runner, model, building)
    return false if not success

    return true
  end

  def self.set_zone_volumes(runner, model, building)
    # TODO: Use HPXML values not Model values
    thermal_zones = model.getThermalZones

    # Init
    living_volume = @cvolume
    zones_updated = 0

    # Basements, crawl, garage
    thermal_zones.each do |thermal_zone|
      if Geometry.is_conditioned_basement(thermal_zone) or Geometry.is_unconditioned_basement(thermal_zone) or Geometry.is_unvented_crawl(thermal_zone) or
         Geometry.is_vented_crawl(thermal_zone) or Geometry.is_garage(thermal_zone)
        zones_updated += 1

        zone_floor_area = 0.0
        thermal_zone.spaces.each do |space|
          space.surfaces.each do |surface|
            if surface.surfaceType.downcase == "floor"
              zone_floor_area += UnitConversions.convert(surface.grossArea, "m^2", "ft^2")
            end
          end
        end

        zone_volume = Geometry.get_height_of_spaces(thermal_zone.spaces) * zone_floor_area
        if zone_volume <= 0
          fail "Calculated volume for #{thermal_zone.name} zone (#{zone_volume}) is not greater than zero."
        end

        thermal_zone.setVolume(UnitConversions.convert(zone_volume, "ft^3", "m^3"))

        if Geometry.is_conditioned_basement(thermal_zone)
          living_volume = @cvolume - zone_volume
        end

      end
    end

    # Conditioned living
    thermal_zones.each do |thermal_zone|
      if Geometry.is_living(thermal_zone)
        zones_updated += 1

        if living_volume <= 0
          fail "Calculated volume for living zone (#{living_volume}) is not greater than zero."
        end

        thermal_zone.setVolume(UnitConversions.convert(living_volume, "ft^3", "m^3"))
      end
    end

    # Attic
    thermal_zones.each do |thermal_zone|
      if Geometry.is_vented_attic(thermal_zone) or Geometry.is_unvented_attic(thermal_zone)
        zones_updated += 1

        zone_surfaces = []
        zone_floor_area = 0.0
        thermal_zone.spaces.each do |space|
          space.surfaces.each do |surface|
            zone_surfaces << surface
            if surface.surfaceType.downcase == "floor"
              zone_floor_area += UnitConversions.convert(surface.grossArea, "m^2", "ft^2")
            end
          end
        end

        # Assume square hip roof for volume calculations; energy results are very insensitive to actual volume
        zone_length = zone_floor_area**0.5
        zone_height = Math.tan(UnitConversions.convert(Geometry.get_roof_pitch(zone_surfaces), "deg", "rad")) * zone_length / 2.0
        zone_volume = [zone_floor_area * zone_height / 3.0, 0.01].max
        thermal_zone.setVolume(UnitConversions.convert(zone_volume, "ft^3", "m^3"))
      end
    end

    if zones_updated != thermal_zones.size
      fail "Unhandled volume calculations for thermal zones."
    end

    return true
  end

  def self.explode_surfaces(runner, model, building)
    # Re-position surfaces so as to not shade each other and to make it easier to visualize the building.
    # FUTURE: Might be able to use the new self-shading options in E+ 8.9 ShadowCalculation object?

    gap_distance = UnitConversions.convert(10.0, "ft", "m") # distance between surfaces of the same azimuth
    rad90 = UnitConversions.convert(90, "deg", "rad")

    # Determine surfaces to shift and distance with which to explode surfaces horizontally outward
    surfaces = []
    azimuth_lengths = {}
    model.getSurfaces.sort.each do |surface|
      next unless ["wall", "roofceiling"].include? surface.surfaceType.downcase
      next unless ["outdoors", "foundation"].include? surface.outsideBoundaryCondition.downcase
      next if surface.additionalProperties.getFeatureAsDouble("Tilt").get <= 0 # skip flat roofs

      surfaces << surface
      azimuth = surface.additionalProperties.getFeatureAsInteger("Azimuth").get
      if azimuth_lengths[azimuth].nil?
        azimuth_lengths[azimuth] = 0.0
      end
      azimuth_lengths[azimuth] += surface.additionalProperties.getFeatureAsDouble("Length").get + gap_distance
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
    nsides = (360.0 / min_azimuth_diff).ceil
    nsides = 4 if nsides < 4 # assume rectangle at the minimum
    explode_distance = max_azimuth_length / (2.0 * Math.tan(UnitConversions.convert(180.0 / nsides, "deg", "rad")))

    success = add_neighbors(runner, model, building, max_azimuth_length)
    return false if not success

    # Initial distance of shifts at 90-degrees to horizontal outward
    azimuth_side_shifts = {}
    azimuth_lengths.keys.each do |azimuth|
      azimuth_side_shifts[azimuth] = max_azimuth_length / 2.0
    end

    # Explode neighbors
    model.getShadingSurfaceGroups.each do |shading_surface_group|
      next if shading_surface_group.name.to_s != Constants.ObjectNameNeighbors

      shading_surface_group.shadingSurfaces.each do |shading_surface|
        azimuth = shading_surface.additionalProperties.getFeatureAsInteger("Azimuth").get
        azimuth_rad = UnitConversions.convert(azimuth, "deg", "rad")
        distance = shading_surface.additionalProperties.getFeatureAsDouble("Distance").get

        unless azimuth_lengths.keys.include? azimuth
          runner.registerError("A neighbor building has an azimuth (#{azimuth}) not equal to the azimuth of any wall.")
          return false
        end

        # Push out horizontally
        distance += explode_distance
        transformation = get_surface_transformation(distance, Math::sin(azimuth_rad), Math::cos(azimuth_rad), 0)

        shading_surface.setVertices(transformation * shading_surface.vertices)
      end
    end

    # Explode walls, windows, doors, roofs, and skylights
    surfaces_moved = []

    surfaces.sort.each do |surface|
      next if surface.additionalProperties.getFeatureAsDouble("Tilt").get <= 0 # skip flat roofs

      if surface.adjacentSurface.is_initialized
        next if surfaces_moved.include? surface.adjacentSurface.get
      end

      azimuth = surface.additionalProperties.getFeatureAsInteger("Azimuth").get
      azimuth_rad = UnitConversions.convert(azimuth, "deg", "rad")

      # Push out horizontally
      distance = explode_distance

      if surface.surfaceType.downcase == "roofceiling"
        # Ensure pitched surfaces are positioned outward justified with walls, etc.
        tilt = surface.additionalProperties.getFeatureAsDouble("Tilt").get
        width = surface.additionalProperties.getFeatureAsDouble("Width").get
        distance -= 0.5 * Math.cos(Math.atan(tilt)) * width
      end
      transformation = get_surface_transformation(distance, Math::sin(azimuth_rad), Math::cos(azimuth_rad), 0)

      surface.setVertices(transformation * surface.vertices)
      if surface.adjacentSurface.is_initialized
        surface.adjacentSurface.get.setVertices(transformation * surface.adjacentSurface.get.vertices)
      end
      surface.subSurfaces.each do |subsurface|
        subsurface.setVertices(transformation * subsurface.vertices)
        next unless subsurface.subSurfaceType.downcase == "fixedwindow"

        subsurface.shadingSurfaceGroups.each do |overhang_group|
          overhang_group.shadingSurfaces.each do |overhang|
            overhang.setVertices(transformation * overhang.vertices)
          end
        end
      end

      # Shift at 90-degrees to previous transformation
      azimuth_side_shifts[azimuth] -= surface.additionalProperties.getFeatureAsDouble("Length").get / 2.0
      transformation_shift = get_surface_transformation(azimuth_side_shifts[azimuth], Math::sin(azimuth_rad + rad90), Math::cos(azimuth_rad + rad90), 0)

      surface.setVertices(transformation_shift * surface.vertices)
      if surface.adjacentSurface.is_initialized
        surface.adjacentSurface.get.setVertices(transformation_shift * surface.adjacentSurface.get.vertices)
      end
      surface.subSurfaces.each do |subsurface|
        subsurface.setVertices(transformation_shift * subsurface.vertices)
        next unless subsurface.subSurfaceType.downcase == "fixedwindow"

        subsurface.shadingSurfaceGroups.each do |overhang_group|
          overhang_group.shadingSurfaces.each do |overhang|
            overhang.setVertices(transformation_shift * overhang.vertices)
          end
        end
      end

      azimuth_side_shifts[azimuth] -= (surface.additionalProperties.getFeatureAsDouble("Length").get / 2.0 + gap_distance)

      surfaces_moved << surface
    end

    return true
  end

  def self.check_for_errors(runner, model)
    # Check every thermal zone has:
    # 1. At least one floor surface
    # 2. At least one roofceiling surface
    # 3. At least one surface adjacent to outside/ground
    model.getThermalZones.each do |zone|
      n_floorsroofsceilings = 0
      n_exteriors = 0
      zone.spaces.each do |space|
        space.surfaces.each do |surface|
          if ["outdoors", "foundation"].include? surface.outsideBoundaryCondition.downcase
            n_exteriors += 1
          end
          if ["floor", "roofceiling"].include? surface.surfaceType.downcase
            n_floorsroofsceilings += 1
          end
        end
      end

      if n_floorsroofsceilings < 1
        runner.registerError("Thermal zone '#{zone.name}' must have at least two floor/roof/ceiling surfaces.")
        return false
      end
      if n_exteriors == 0
        runner.registerError("Thermal zone '#{zone.name}' must have at least one surface adjacent to outside/ground.")
        return false
      end
    end

    return true
  end

  def self.create_space_and_zone(model, spaces, space_type)
    if not spaces.keys.include? space_type
      thermal_zone = OpenStudio::Model::ThermalZone.new(model)
      thermal_zone.setName(space_type)

      space = OpenStudio::Model::Space.new(model)
      space.setName(space_type)

      st = OpenStudio::Model::SpaceType.new(model)
      st.setStandardsSpaceType(space_type)
      space.setSpaceType(st)

      space.setThermalZone(thermal_zone)
      spaces[space_type] = space
    end
  end

  def self.get_surface_transformation(offset, x, y, z)
    x = UnitConversions.convert(x, "ft", "m")
    y = UnitConversions.convert(y, "ft", "m")
    z = UnitConversions.convert(z, "ft", "m")

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

  def self.add_floor_polygon(x, y, z)
    x = UnitConversions.convert(x, "ft", "m")
    y = UnitConversions.convert(y, "ft", "m")
    z = UnitConversions.convert(z, "ft", "m")

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new(0 - x / 2, 0 - y / 2, z)
    vertices << OpenStudio::Point3d.new(0 - x / 2, y / 2, z)
    vertices << OpenStudio::Point3d.new(x / 2, y / 2, z)
    vertices << OpenStudio::Point3d.new(x / 2, 0 - y / 2, z)

    return vertices
  end

  def self.add_wall_polygon(x, y, z, azimuth = 0, offsets = [0] * 4)
    x = UnitConversions.convert(x, "ft", "m")
    y = UnitConversions.convert(y, "ft", "m")
    z = UnitConversions.convert(z, "ft", "m")

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new(0 - (x / 2) - offsets[1], 0, z - offsets[0])
    vertices << OpenStudio::Point3d.new(0 - (x / 2) - offsets[1], 0, z + y + offsets[2])
    vertices << OpenStudio::Point3d.new(x - (x / 2) + offsets[3], 0, z + y + offsets[2])
    vertices << OpenStudio::Point3d.new(x - (x / 2) + offsets[3], 0, z - offsets[0])

    # Rotate about the z axis
    azimuth_rad = UnitConversions.convert(azimuth, "deg", "rad")
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

  def self.add_roof_polygon(x, y, z, azimuth = 0, tilt = 0.5)
    x = UnitConversions.convert(x, "ft", "m")
    y = UnitConversions.convert(y, "ft", "m")
    z = UnitConversions.convert(z, "ft", "m")

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new(x / 2, -y / 2, 0)
    vertices << OpenStudio::Point3d.new(x / 2, y / 2, 0)
    vertices << OpenStudio::Point3d.new(-x / 2, y / 2, 0)
    vertices << OpenStudio::Point3d.new(-x / 2, -y / 2, 0)

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
    azimuth_rad = UnitConversions.convert(azimuth, "deg", "rad")
    rad180 = UnitConversions.convert(180, "deg", "rad")
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
      new_vertices << OpenStudio::Point3d.new(vertex.x, vertex.y, vertex.z + z)
    end

    return new_vertices
  end

  def self.add_ceiling_polygon(x, y, z)
    return OpenStudio::reverse(add_floor_polygon(x, y, z))
  end

  def self.net_surface_area(gross_area, surface_id, surface_type)
    net_area = gross_area
    if @subsurface_areas_by_surface.keys.include? surface_id
      net_area -= @subsurface_areas_by_surface[surface_id]
    end

    if net_area <= 0
      fail "Calculated a negative net surface area for #{surface_type} '#{surface_id}'."
    end

    return net_area
  end

  def self.add_num_occupants(runner, model, building)
    building_occupancy_values = HPXML.get_building_occupancy_values(building_occupancy: building.elements["BuildingDetails/BuildingSummary/BuildingOccupancy"])

    # Occupants
    num_occ = Geometry.get_occupancy_default_num(@nbeds)
    unless building_occupancy_values.nil?
      unless building_occupancy_values[:number_of_residents].nil?
        num_occ = building_occupancy_values[:number_of_residents]
      end
    end
    if num_occ > 0
      occ_gain, hrs_per_day, sens_frac, lat_frac = Geometry.get_occupancy_default_values()
      weekday_sch = "1.00000, 1.00000, 1.00000, 1.00000, 1.00000, 1.00000, 1.00000, 0.88310, 0.40861, 0.24189, 0.24189, 0.24189, 0.24189, 0.24189, 0.24189, 0.24189, 0.29498, 0.55310, 0.89693, 0.89693, 0.89693, 1.00000, 1.00000, 1.00000" # TODO: Normalize schedule based on hrs_per_day
      weekday_sch_sum = weekday_sch.split(",").map(&:to_f).inject { |sum, n| sum + n }
      if (weekday_sch_sum - hrs_per_day).abs > 0.1
        runner.registerError("Occupancy schedule inconsistent with hrs_per_day.")
        return false
      end
      weekend_sch = weekday_sch
      monthly_sch = "1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0"
      success = Geometry.process_occupants(model, runner, num_occ, occ_gain, sens_frac, lat_frac, weekday_sch, weekend_sch, monthly_sch, @cfa, @nbeds)
      return false if not success
    end

    return true
  end

  def self.calc_subsurface_areas_by_surface(building)
    # Returns a hash with the amount of subsurface (window/skylight/door)
    # area for each surface. Used to convert gross surface area to net surface
    # area for a given surface.
    subsurface_areas = {}

    # Windows
    building.elements.each("BuildingDetails/Enclosure/Windows/Window") do |window|
      window_values = HPXML.get_window_values(window: window)
      wall_id = window_values[:wall_idref]
      subsurface_areas[wall_id] = 0.0 if subsurface_areas[wall_id].nil?
      subsurface_areas[wall_id] += window_values[:area]
    end

    # Skylights
    building.elements.each("BuildingDetails/Enclosure/Skylights/Skylight") do |skylight|
      skylight_values = HPXML.get_skylight_values(skylight: skylight)
      roof_id = skylight_values[:roof_idref]
      subsurface_areas[roof_id] = 0.0 if subsurface_areas[roof_id].nil?
      subsurface_areas[roof_id] += skylight_values[:area]
    end

    # Doors
    building.elements.each("BuildingDetails/Enclosure/Doors/Door") do |door|
      door_values = HPXML.get_door_values(door: door)
      wall_id = door_values[:wall_idref]
      subsurface_areas[wall_id] = 0.0 if subsurface_areas[wall_id].nil?
      subsurface_areas[wall_id] += door_values[:area]
    end

    return subsurface_areas
  end

  def self.get_default_azimuth(building)
    building.elements.each("BuildingDetails/Enclosure//Azimuth") do |azimuth|
      return Integer(azimuth.text)
    end
    return 90
  end

  def self.create_or_get_space(model, spaces, spacetype)
    if spaces[spacetype].nil?
      create_space_and_zone(model, spaces, spacetype)
    end
    return spaces[spacetype]
  end

  def self.add_roofs(runner, model, building, spaces)
    building.elements.each("BuildingDetails/Enclosure/Roofs/Roof") do |roof|
      roof_values = HPXML.get_roof_values(roof: roof)

      net_area = net_surface_area(roof_values[:area], roof_values[:id], "Roof")
      width = Math::sqrt(net_area)
      length = net_area / width
      tilt = roof_values[:pitch] / 12.0
      z_origin = @walls_top + 0.5 * Math.sin(Math.atan(tilt)) * width
      azimuth = @default_azimuth
      if not roof_values[:azimuth].nil?
        azimuth = roof_values[:azimuth]
      end

      surface = OpenStudio::Model::Surface.new(add_roof_polygon(length, width, z_origin, azimuth, tilt), model)
      surface.additionalProperties.setFeature("Length", length)
      surface.additionalProperties.setFeature("Width", width)
      surface.additionalProperties.setFeature("Azimuth", azimuth)
      surface.additionalProperties.setFeature("Tilt", tilt)
      surface.setName(roof_values[:id])
      surface.setSurfaceType("RoofCeiling")
      surface.setOutsideBoundaryCondition("Outdoors")
      set_surface_interior(model, spaces, surface, roof_values[:id], roof_values[:interior_adjacent_to])

      # Apply construction
      if is_thermal_boundary(roof_values)
        drywall_thick_in = 0.5
      else
        drywall_thick_in = 0.0
      end
      film_r = Material.AirFilmOutside.rvalue + Material.AirFilmRoof(Geometry.get_roof_pitch([surface])).rvalue
      mat_roofing = Material.RoofingAsphaltShinglesDark
      solar_abs = roof_values[:solar_absorptance]
      emitt = roof_values[:emittance]
      has_radiant_barrier = roof_values[:radiant_barrier]

      assembly_r = roof_values[:insulation_assembly_r_value]
      constr_sets = [
        WoodStudConstructionSet.new(Material.Stud2x(8.0), 0.07, 10.0, 0.75, drywall_thick_in, mat_roofing), # 2x8, 24" o.c. + R10
        WoodStudConstructionSet.new(Material.Stud2x(8.0), 0.07, 5.0, 0.75, drywall_thick_in, mat_roofing),  # 2x8, 24" o.c. + R5
        WoodStudConstructionSet.new(Material.Stud2x(8.0), 0.07, 0.0, 0.75, drywall_thick_in, mat_roofing),  # 2x8, 24" o.c.
        WoodStudConstructionSet.new(Material.Stud2x6, 0.07, 0.0, 0.75, drywall_thick_in, mat_roofing),      # 2x6, 24" o.c.
        WoodStudConstructionSet.new(Material.Stud2x4, 0.07, 0.0, 0.5, drywall_thick_in, mat_roofing),       # 2x4, 16" o.c.
        WoodStudConstructionSet.new(Material.Stud2x4, 0.01, 0.0, 0.0, 0.0, mat_roofing),                    # Fallback
      ]
      constr_set, cavity_r = pick_wood_stud_construction_set(assembly_r, constr_sets, film_r, roof_values[:id])

      install_grade = 1

      success = Constructions.apply_closed_cavity_roof(runner, model, [surface], "#{roof_values[:id]} construction",
                                                       cavity_r, install_grade,
                                                       constr_set.stud.thick_in,
                                                       true, constr_set.framing_factor,
                                                       constr_set.drywall_thick_in,
                                                       constr_set.osb_thick_in, constr_set.rigid_r,
                                                       constr_set.exterior_material)
      return false if not success

      check_surface_assembly_rvalue(surface, film_r, assembly_r)

      apply_solar_abs_emittance_to_construction(surface, solar_abs, emitt)
    end

    return true
  end

  def self.add_walls(runner, model, building, spaces)
    building.elements.each("BuildingDetails/Enclosure/Walls/Wall") do |wall|
      wall_values = HPXML.get_wall_values(wall: wall)

      net_area = net_surface_area(wall_values[:area], wall_values[:id], "Wall")
      height = 8.0 * @ncfl_ag
      length = net_area / height
      z_origin = @foundation_top
      azimuth = @default_azimuth
      if not wall_values[:azimuth].nil?
        azimuth = wall_values[:azimuth]
      end

      surface = OpenStudio::Model::Surface.new(add_wall_polygon(length, height, z_origin, azimuth), model)
      surface.additionalProperties.setFeature("Length", length)
      surface.additionalProperties.setFeature("Azimuth", azimuth)
      surface.additionalProperties.setFeature("Tilt", 90.0)
      surface.setName(wall_values[:id])
      surface.setSurfaceType("Wall")
      set_surface_interior(model, spaces, surface, wall_values[:id], wall_values[:interior_adjacent_to])
      set_surface_exterior(model, spaces, surface, wall_values[:id], wall_values[:exterior_adjacent_to])
      if wall_values[:exterior_adjacent_to] != "outside"
        surface.setSunExposure("NoSun")
        surface.setWindExposure("NoWind")
      end

      # Apply construction
      # The code below constructs a reasonable wall construction based on the
      # wall type while ensuring the correct assembly R-value.

      if is_thermal_boundary(wall_values)
        drywall_thick_in = 0.5
      else
        drywall_thick_in = 0.0
      end
      if wall_values[:exterior_adjacent_to] == "outside"
        film_r = Material.AirFilmVertical.rvalue + Material.AirFilmOutside.rvalue
        mat_ext_finish = Material.ExtFinishWoodLight
      else
        film_r = 2.0 * Material.AirFilmVertical.rvalue
        mat_ext_finish = nil
      end

      success = apply_wall_construction(runner, model, surface, wall_values[:id], wall_values[:wall_type], wall_values[:insulation_assembly_r_value],
                                        drywall_thick_in, film_r, mat_ext_finish, wall_values[:solar_absorptance], wall_values[:emittance])
      return false if not success
    end

    return true
  end

  def self.add_rim_joists(runner, model, building, spaces)
    building.elements.each("BuildingDetails/Enclosure/RimJoists/RimJoist") do |rim_joist|
      rim_joist_values = HPXML.get_rim_joist_values(rim_joist: rim_joist)

      height = 1.0
      length = rim_joist_values[:area] / height
      z_origin = @foundation_top
      azimuth = @default_azimuth
      if not rim_joist_values[:azimuth].nil?
        azimuth = rim_joist_values[:azimuth]
      end

      surface = OpenStudio::Model::Surface.new(add_wall_polygon(length, height, z_origin, azimuth), model)
      surface.additionalProperties.setFeature("Length", length)
      surface.additionalProperties.setFeature("Azimuth", azimuth)
      surface.additionalProperties.setFeature("Tilt", 90.0)
      surface.setName(rim_joist_values[:id])
      surface.setSurfaceType("Wall")
      set_surface_interior(model, spaces, surface, rim_joist_values[:id], rim_joist_values[:interior_adjacent_to])
      set_surface_exterior(model, spaces, surface, rim_joist_values[:id], rim_joist_values[:exterior_adjacent_to])
      if rim_joist_values[:exterior_adjacent_to] != "outside"
        surface.setSunExposure("NoSun")
        surface.setWindExposure("NoWind")
      end

      # Apply construction

      if is_thermal_boundary(rim_joist_values)
        drywall_thick_in = 0.5
      else
        drywall_thick_in = 0.0
      end
      if rim_joist_values[:exterior_adjacent_to] == "outside"
        film_r = Material.AirFilmVertical.rvalue + Material.AirFilmOutside.rvalue
        mat_ext_finish = Material.ExtFinishWoodLight
      else
        film_r = 2.0 * Material.AirFilmVertical.rvalue
        mat_ext_finish = nil
      end
      solar_abs = rim_joist_values[:solar_absorptance]
      emitt = rim_joist_values[:emittance]

      assembly_r = rim_joist_values[:insulation_assembly_r_value]

      constr_sets = [
        WoodStudConstructionSet.new(Material.Stud2x(2.0), 0.17, 10.0, 2.0, drywall_thick_in, mat_ext_finish),  # 2x4 + R10
        WoodStudConstructionSet.new(Material.Stud2x(2.0), 0.17, 5.0, 2.0, drywall_thick_in, mat_ext_finish),   # 2x4 + R5
        WoodStudConstructionSet.new(Material.Stud2x(2.0), 0.17, 0.0, 2.0, drywall_thick_in, mat_ext_finish),   # 2x4
        WoodStudConstructionSet.new(Material.Stud2x(2.0), 0.01, 0.0, 0.0, 0.0, nil),                           # Fallback
      ]
      constr_set, cavity_r = pick_wood_stud_construction_set(assembly_r, constr_sets, film_r, rim_joist_values[:id])
      install_grade = 1

      success = Constructions.apply_rim_joist(runner, model, [surface], "#{rim_joist_values[:id]} construction",
                                              cavity_r, install_grade, constr_set.framing_factor,
                                              constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                              constr_set.rigid_r, constr_set.exterior_material)
      return false if not success

      check_surface_assembly_rvalue(surface, film_r, assembly_r)

      apply_solar_abs_emittance_to_construction(surface, solar_abs, emitt)
    end

    return true
  end

  def self.add_framefloors(runner, model, building, spaces)
    building.elements.each("BuildingDetails/Enclosure/FrameFloors/FrameFloor") do |framefloor|
      framefloor_values = HPXML.get_framefloor_values(framefloor: framefloor)

      area = framefloor_values[:area]
      width = Math::sqrt(area)
      length = area / width
      if framefloor_values[:interior_adjacent_to].include? "attic" or framefloor_values[:exterior_adjacent_to].include? "attic"
        z_origin = @walls_top
      else
        z_origin = @foundation_top
      end

      if framefloor_values[:exterior_adjacent_to].include? "attic"
        surface = OpenStudio::Model::Surface.new(add_ceiling_polygon(length, width, z_origin), model)
      else
        surface = OpenStudio::Model::Surface.new(add_floor_polygon(length, width, z_origin), model)
      end
      set_surface_interior(model, spaces, surface, framefloor_values[:id], framefloor_values[:interior_adjacent_to])
      set_surface_exterior(model, spaces, surface, framefloor_values[:id], framefloor_values[:exterior_adjacent_to])
      surface.setName(framefloor_values[:id])
      surface.setSunExposure("NoSun")
      surface.setWindExposure("NoWind")

      # Apply construction

      if is_thermal_boundary(framefloor_values)
        drywall_thick_in = 0.5
      else
        drywall_thick_in = 0.0
      end
      film_r = 2.0 * Material.AirFilmFloorReduced.rvalue
      assembly_r = framefloor_values[:insulation_assembly_r_value]

      constr_sets = [
        WoodStudConstructionSet.new(Material.Stud2x6, 0.10, 10.0, 0.75, 0.0, Material.CoveringBare), # 2x6, 24" o.c. + R10
        WoodStudConstructionSet.new(Material.Stud2x6, 0.10, 0.0, 0.75, 0.0, Material.CoveringBare),  # 2x6, 24" o.c.
        WoodStudConstructionSet.new(Material.Stud2x4, 0.13, 0.0, 0.5, 0.0, Material.CoveringBare),   # 2x4, 16" o.c.
        WoodStudConstructionSet.new(Material.Stud2x4, 0.01, 0.0, 0.0, 0.0, nil),                     # Fallback
      ]
      constr_set, cavity_r = pick_wood_stud_construction_set(assembly_r, constr_sets, film_r, framefloor_values[:id])

      mat_floor_covering = nil
      install_grade = 1

      # Floor
      success = Constructions.apply_floor(runner, model, [surface], "#{framefloor_values[:id]} construction",
                                          cavity_r, install_grade,
                                          constr_set.framing_factor, constr_set.stud.thick_in,
                                          constr_set.osb_thick_in, constr_set.rigid_r,
                                          mat_floor_covering, constr_set.exterior_material)
      return false if not success

      if not assembly_r.nil?
        check_surface_assembly_rvalue(surface, film_r, assembly_r)
      end
    end

    return true
  end

  def self.add_foundation_walls_slabs(runner, model, building, spaces)
    # Get foundation types
    foundation_types = []
    building.elements.each("BuildingDetails/Enclosure/Slabs/Slab/InteriorAdjacentTo") do |int_adjacent_to|
      next if foundation_types.include? int_adjacent_to.text

      foundation_types << int_adjacent_to.text
    end

    foundation_types.each do |foundation_type|
      # Create Kiva foundation for each type

      # Get attached foundation walls/slabs
      fnd_walls = []
      slabs = []
      building.elements.each("BuildingDetails/Enclosure/FoundationWalls/FoundationWall[InteriorAdjacentTo='#{foundation_type}']") do |fnd_wall|
        fnd_walls << fnd_wall
      end
      building.elements.each("BuildingDetails/Enclosure/Slabs/Slab[InteriorAdjacentTo='#{foundation_type}']") do |slab|
        slabs << slab
      end

      # Calculate sum of exterior foundation wall lengths
      sum_wall_length = 0.0
      fnd_walls.each do |fnd_wall|
        fnd_wall_values = HPXML.get_foundation_wall_values(foundation_wall: fnd_wall)
        next unless fnd_wall_values[:exterior_adjacent_to] == "ground"

        net_area = net_surface_area(fnd_wall_values[:area], fnd_wall_values[:id], "Wall")
        sum_wall_length += net_area / fnd_wall_values[:height]
      end

      # Obtain the exposed perimeter for each slab
      slabs_perimeter_exposed = {}
      slabs.each do |slab|
        slab_values = HPXML.get_slab_values(slab: slab)
        slabs_perimeter_exposed[slab_values[:id]] = slab_values[:exposed_perimeter]
      end

      # Exterior foundation wall surfaces
      foundation_object = {}
      fnd_walls.each do |fnd_wall|
        fnd_wall_values = HPXML.get_foundation_wall_values(foundation_wall: fnd_wall)
        next unless fnd_wall_values[:exterior_adjacent_to] == "ground"

        height = fnd_wall_values[:height]
        net_area = net_surface_area(fnd_wall_values[:area], fnd_wall_values[:id], "Wall")
        height_ag = height - fnd_wall_values[:depth_below_grade]
        z_origin = -1 * fnd_wall_values[:depth_below_grade]
        total_length = net_area / height

        azimuth = @default_azimuth # don't split up surface due to the Kiva runtime impact
        if not fnd_wall_values[:azimuth].nil?
          azimuth = fnd_wall_values[:azimuth]
        end

        # Attach a portion of the foundation wall to each slab. This is
        # needed if there are multiple Slab elements defined for the foundation.
        slabs_perimeter_exposed.each do |slab_id, slab_perimeter_exposed|
          # Calculate exposed section of wall based on slab's total exposed perimeter.
          # Apportioned to each foundation wall.
          length = total_length * slab_perimeter_exposed / sum_wall_length

          surface = OpenStudio::Model::Surface.new(add_wall_polygon(length, height, z_origin, azimuth), model)
          surface.additionalProperties.setFeature("Length", length)
          surface.additionalProperties.setFeature("Azimuth", azimuth)
          surface.additionalProperties.setFeature("Tilt", 90.0)
          surface.setName(fnd_wall_values[:id])
          surface.setSurfaceType("Wall")
          set_surface_interior(model, spaces, surface, fnd_wall_values[:id], fnd_wall_values[:interior_adjacent_to])
          set_surface_exterior(model, spaces, surface, fnd_wall_values[:id], fnd_wall_values[:exterior_adjacent_to])

          if is_thermal_boundary(fnd_wall_values)
            drywall_thick_in = 0.5
          else
            drywall_thick_in = 0.0
          end
          filled_cavity = true
          concrete_thick_in = fnd_wall_values[:thickness]
          cavity_r = 0.0
          cavity_depth_in = 0.0
          install_grade = 1
          framing_factor = 0.0
          assembly_r = fnd_wall_values[:insulation_assembly_r_value]
          if not assembly_r.nil?
            rigid_height = height
            film_r = Material.AirFilmVertical.rvalue
            rigid_r = assembly_r - Material.Concrete(concrete_thick_in).rvalue - Material.GypsumWall(drywall_thick_in).rvalue - film_r
            if rigid_r < 0 # Try without drywall
              drywall_thick_in = 0.0
              rigid_r = assembly_r - Material.Concrete(concrete_thick_in).rvalue - Material.GypsumWall(drywall_thick_in).rvalue - film_r
            end
          else
            rigid_height = fnd_wall_values[:insulation_distance_to_bottom]
            rigid_r = fnd_wall_values[:insulation_r_value]
          end

          foundation = foundation_object[slab_id]

          # TODO: Currently assumes all walls have the same height, insulation height, etc.
          success = Constructions.apply_foundation_wall(runner, model, [surface], "#{fnd_wall_values[:id]} construction",
                                                        rigid_height, cavity_r, install_grade,
                                                        cavity_depth_in, filled_cavity, framing_factor,
                                                        rigid_r, drywall_thick_in, concrete_thick_in,
                                                        height, height_ag, foundation)
          return false if not success

          if not assembly_r.nil?
            check_surface_assembly_rvalue(surface, film_r, assembly_r)
          end

          foundation_object[slab_id] = surface.adjacentFoundation.get
        end
      end

      # Foundation slab surfaces
      slabs.each do |slab|
        slab_values = HPXML.get_slab_values(slab: slab)

        # Need to ensure surface perimeter >= user-specified exposed perimeter
        # (for Kiva) and surface area == user-specified area.
        exp_perim = slab_values[:exposed_perimeter]
        tot_perim = exp_perim
        if tot_perim**2 - 16.0 * slab_values[:area] <= 0
          # Cannot construct rectangle with this perimeter/area. Some of the
          # perimeter is presumably not exposed, so bump up perimeter value.
          tot_perim = Math.sqrt(16.0 * slab_values[:area])
        end
        sqrt_term = tot_perim**2 - 16.0 * slab_values[:area]
        length = tot_perim / 4.0 + Math.sqrt(sqrt_term) / 4.0
        width = tot_perim / 4.0 - Math.sqrt(sqrt_term) / 4.0

        z_origin = -1 * slab_values[:depth_below_grade]

        surface = OpenStudio::Model::Surface.new(add_floor_polygon(length, width, z_origin), model)
        surface.setName(slab_values[:id])
        surface.setSurfaceType("Floor")
        surface.setOutsideBoundaryCondition("Foundation")
        set_surface_interior(model, spaces, surface, slab_values[:id], slab_values[:interior_adjacent_to])
        surface.setSunExposure("NoSun")
        surface.setWindExposure("NoWind")

        perim_r = slab_values[:perimeter_insulation_r_value]
        perim_depth = slab_values[:perimeter_insulation_depth]
        if perim_r == 0 or perim_depth == 0
          perim_r = 0
          perim_depth = 0
        end

        if slab_values[:under_slab_insulation_spans_entire_slab]
          whole_r = slab_values[:under_slab_insulation_r_value]
          under_r = 0
          under_width = 0
        else
          under_r = slab_values[:under_slab_insulation_r_value]
          under_width = slab_values[:under_slab_insulation_width]
          if under_r == 0 or under_width == 0
            under_r = 0
            under_width = 0
          end
          whole_r = 0
        end
        slab_gap_r = under_r

        mat_carpet = nil
        if slab_values[:carpet_fraction] > 0 and slab_values[:carpet_r_value] > 0
          mat_carpet = Material.CoveringBare(slab_values[:carpet_fraction],
                                             slab_values[:carpet_r_value])
        end

        foundation = foundation_object[slab_values[:id]]

        success = Constructions.apply_foundation_slab(runner, model, surface, "#{slab_values[:id]} construction",
                                                      under_r, under_width, slab_gap_r, perim_r,
                                                      perim_depth, whole_r, slab_values[:thickness],
                                                      exp_perim, mat_carpet, foundation)
        return false if not success

        # FIXME: Temporary code for sizing
        surface.additionalProperties.setFeature(Constants.SizingInfoSlabRvalue, 5.0)
      end

      # Interior foundation wall surfaces
      # The above-grade portion of the walls are modeled as EnergyPlus surfaces with standard adjacency.
      # The below-grade portion of the walls (in contact with ground) are not modeled, as Kiva does not
      # calculate heat flow between two zones through the ground.
      fnd_walls.each do |fnd_wall|
        fnd_wall_values = HPXML.get_foundation_wall_values(foundation_wall: fnd_wall)
        next unless fnd_wall_values[:exterior_adjacent_to] != "ground"

        ag_height = fnd_wall_values[:height] - fnd_wall_values[:depth_below_grade]
        ag_net_area = net_surface_area(fnd_wall_values[:area], fnd_wall_values[:id], "Wall") * ag_height / fnd_wall_values[:height]
        length = ag_net_area / ag_height
        z_origin = -1 * ag_height
        azimuth = @default_azimuth
        if not fnd_wall_values[:azimuth].nil?
          azimuth = fnd_wall_values[:azimuth]
        end

        surface = OpenStudio::Model::Surface.new(add_wall_polygon(length, ag_height, z_origin, azimuth), model)
        surface.additionalProperties.setFeature("Length", length)
        surface.additionalProperties.setFeature("Azimuth", azimuth)
        surface.additionalProperties.setFeature("Tilt", 90.0)
        surface.setName(fnd_wall_values[:id])
        surface.setSurfaceType("Wall")
        set_surface_interior(model, spaces, surface, fnd_wall_values[:id], fnd_wall_values[:interior_adjacent_to])
        set_surface_exterior(model, spaces, surface, fnd_wall_values[:id], fnd_wall_values[:exterior_adjacent_to])
        surface.setSunExposure("NoSun")
        surface.setWindExposure("NoWind")

        # Apply construction

        wall_type = "SolidConcrete"
        solar_absorptance = 0.75
        emittance = 0.9
        if is_thermal_boundary(fnd_wall_values)
          drywall_thick_in = 0.5
        else
          drywall_thick_in = 0.0
        end
        film_r = 2.0 * Material.AirFilmVertical.rvalue
        assembly_r = fnd_wall_values[:insulation_assembly_r_value]
        if assembly_r.nil?
          concrete_thick_in = fnd_wall_values[:thickness]
          assembly_r = fnd_wall_values[:insulation_r_value] + Material.Concrete(concrete_thick_in).rvalue + Material.GypsumWall(drywall_thick_in).rvalue + film_r
        end
        mat_ext_finish = nil

        success = apply_wall_construction(runner, model, surface, fnd_wall_values[:id], wall_type, assembly_r,
                                          drywall_thick_in, film_r, mat_ext_finish, solar_absorptance, emittance)
        return false if not success
      end
    end
  end

  def self.add_conditioned_floor_area(runner, model, building, spaces)
    # FIXME: Simplify this.
    # TODO: Use HPXML values not Model values
    cfa = @cfa.round(1)

    model.getThermalZones.each do |zone|
      next if not Geometry.is_conditioned_basement(zone)

      floor_area = 0.0
      ceiling_area = 0.0
      zone.spaces.each do |space|
        space.surfaces.each do |surface|
          if surface.surfaceType.downcase.to_s == "floor"
            floor_area += UnitConversions.convert(surface.grossArea, "m^2", "ft^2").round(2)
          elsif surface.surfaceType.downcase.to_s == "roofceiling"
            ceiling_area += UnitConversions.convert(surface.grossArea, "m^2", "ft^2").round(2)
          end
        end
      end

      addtl_cfa = floor_area - ceiling_area
      if addtl_cfa > 0
        runner.registerWarning("Adding conditioned basement adiabatic ceiling with #{addtl_cfa.to_s} ft^2.")

        conditioned_floor_width = Math::sqrt(addtl_cfa)
        conditioned_floor_length = addtl_cfa / conditioned_floor_width
        z_origin = @foundation_top

        surface = OpenStudio::Model::Surface.new(add_ceiling_polygon(-conditioned_floor_width, -conditioned_floor_length, z_origin), model)

        surface.setSunExposure("NoSun")
        surface.setWindExposure("NoWind")
        surface.setName("inferred conditioned basement ceiling")
        surface.setSurfaceType("RoofCeiling")
        surface.setSpace(zone.spaces[0])
        surface.setOutsideBoundaryCondition("Adiabatic")

        # Apply Construction
        success = apply_adiabatic_construction(runner, model, [surface], "floor")
        return false if not success
      end
    end

    # Next check if we need to add floors between conditioned spaces (e.g., 2-story buildings).

    # Calculate cfa already added to model
    model_cfa = 0.0
    model.getSpaces.each do |space|
      next unless Geometry.space_is_conditioned(space)

      space.surfaces.each do |surface|
        next unless surface.surfaceType.downcase.to_s == "floor"

        model_cfa += UnitConversions.convert(surface.grossArea, "m^2", "ft^2").round(2)
      end
    end

    if model_cfa > cfa
      runner.registerError("Sum of conditioned floor surface areas #{model_cfa.to_s} is greater than ConditionedFloorArea specified #{cfa.to_s}.")
      return false
    end

    addtl_cfa = cfa - model_cfa
    return true unless addtl_cfa > 0

    runner.registerWarning("Adding adiabatic conditioned floor with #{addtl_cfa.to_s} ft^2 to preserve building total conditioned floor area.")

    conditioned_floor_width = Math::sqrt(addtl_cfa)
    conditioned_floor_length = addtl_cfa / conditioned_floor_width
    z_origin = @foundation_top + 8.0 * (@ncfl_ag - 1)

    surface = OpenStudio::Model::Surface.new(add_floor_polygon(-conditioned_floor_width, -conditioned_floor_length, z_origin), model)

    surface.setSunExposure("NoSun")
    surface.setWindExposure("NoWind")
    surface.setName("inferred conditioned floor")
    surface.setSurfaceType("Floor")
    surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeLiving))
    surface.setOutsideBoundaryCondition("Adiabatic")

    # Apply Construction
    success = apply_adiabatic_construction(runner, model, [surface], "floor")
    return false if not success

    return true
  end

  def self.add_thermal_mass(runner, model, building)
    drywall_thick_in = 0.5
    partition_frac_of_cfa = 1.0
    success = Constructions.apply_partition_walls(runner, model, [],
                                                  "PartitionWallConstruction",
                                                  drywall_thick_in, partition_frac_of_cfa)
    return false if not success

    # FIXME ?
    furniture_frac_of_cfa = 1.0
    mass_lb_per_sqft = 8.0
    density_lb_per_cuft = 40.0
    mat = BaseMaterial.Wood
    success = Constructions.apply_furniture(runner, model, furniture_frac_of_cfa,
                                            mass_lb_per_sqft, density_lb_per_cuft, mat)
    return false if not success

    return true
  end

  def self.add_neighbors(runner, model, building, length)
    # Get the max z-value of any model surface
    height = -9e99
    model.getSpaces.each do |space|
      z_origin = space.zOrigin
      space.surfaces.each do |surface|
        surface.vertices.each do |vertex|
          surface_z = vertex.z + z_origin
          next if surface_z < height

          height = surface_z
        end
      end
    end
    height = UnitConversions.convert(height, "m", "ft")
    z_origin = 0 # shading surface always starts at grade

    shading_surfaces = []
    building.elements.each("BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding") do |neighbor_building|
      neighbor_building_values = HPXML.get_neighbor_building_values(neighbor_building: neighbor_building)
      azimuth = neighbor_building_values[:azimuth]
      distance = neighbor_building_values[:distance]

      shading_surface = OpenStudio::Model::ShadingSurface.new(add_wall_polygon(length, height, z_origin, azimuth), model)
      shading_surface.additionalProperties.setFeature("Azimuth", azimuth)
      shading_surface.additionalProperties.setFeature("Distance", distance)
      shading_surface.setName("Neighbor azimuth #{azimuth} distance #{distance}")

      shading_surfaces << shading_surface
    end

    unless shading_surfaces.empty?
      shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
      shading_surface_group.setName(Constants.ObjectNameNeighbors)
      shading_surfaces.each do |shading_surface|
        shading_surface.setShadingSurfaceGroup(shading_surface_group)
      end
    end

    return true
  end

  def self.add_windows(runner, model, building, spaces, weather, cooling_season)
    surfaces = []
    building.elements.each("BuildingDetails/Enclosure/Windows/Window") do |window|
      window_values = HPXML.get_window_values(window: window)

      window_id = window_values[:id]

      window_height = 4.0 # ft, default
      overhang_depth = nil
      if not window.elements["Overhangs"].nil?
        overhang_depth = window_values[:overhangs_depth]
        overhang_distance_to_top = window_values[:overhangs_distance_to_top_of_window]
        overhang_distance_to_bottom = window_values[:overhangs_distance_to_bottom_of_window]
        window_height = overhang_distance_to_bottom - overhang_distance_to_top
      end

      window_area = window_values[:area]
      window_width = window_area / window_height
      z_origin = @foundation_top
      window_azimuth = window_values[:azimuth]

      # Create parent surface slightly bigger than window
      surface = OpenStudio::Model::Surface.new(add_wall_polygon(window_width, window_height, z_origin,
                                                                window_azimuth, [0, 0.001, 0.001, 0.001]), model)

      surface.additionalProperties.setFeature("Length", window_width)
      surface.additionalProperties.setFeature("Azimuth", window_azimuth)
      surface.additionalProperties.setFeature("Tilt", 90.0)
      surface.setName("surface #{window_id}")
      surface.setSurfaceType("Wall")
      assign_space_to_subsurface(surface, window_id, window_values[:wall_idref], building, spaces, model, "window")
      surface.setOutsideBoundaryCondition("Outdoors") # cannot be adiabatic because subsurfaces won't be created
      surfaces << surface

      sub_surface = OpenStudio::Model::SubSurface.new(add_wall_polygon(window_width, window_height, z_origin,
                                                                       window_azimuth, [-0.001, 0, 0.001, 0]), model)
      sub_surface.setName(window_id)
      sub_surface.setSurface(surface)
      sub_surface.setSubSurfaceType("FixedWindow")

      if not overhang_depth.nil?
        overhang = sub_surface.addOverhang(UnitConversions.convert(overhang_depth, "ft", "m"), UnitConversions.convert(overhang_distance_to_top, "ft", "m"))
        overhang.get.setName("#{sub_surface.name} - #{Constants.ObjectNameOverhangs}")

        sub_surface.additionalProperties.setFeature(Constants.SizingInfoWindowOverhangDepth, overhang_depth)
        sub_surface.additionalProperties.setFeature(Constants.SizingInfoWindowOverhangOffset, overhang_distance_to_top)
      end

      # Apply construction
      ufactor = window_values[:ufactor]
      shgc = window_values[:shgc]
      default_shade_summer, default_shade_winter = Constructions.get_default_interior_shading_factors()
      cool_shade_mult = default_shade_summer
      if not window_values[:interior_shading_factor_summer].nil?
        cool_shade_mult = window_values[:interior_shading_factor_summer]
      end
      heat_shade_mult = default_shade_winter
      if not window_values[:interior_shading_factor_winter].nil?
        heat_shade_mult = window_values[:interior_shading_factor_winter]
      end
      success = Constructions.apply_window(runner, model, [sub_surface],
                                           "WindowConstruction",
                                           weather, cooling_season, ufactor, shgc,
                                           heat_shade_mult, cool_shade_mult)
      return false if not success
    end

    success = apply_adiabatic_construction(runner, model, surfaces, "wall")
    return false if not success

    return true
  end

  def self.add_skylights(runner, model, building, spaces, weather, cooling_season)
    surfaces = []
    building.elements.each("BuildingDetails/Enclosure/Skylights/Skylight") do |skylight|
      skylight_values = HPXML.get_skylight_values(skylight: skylight)

      skylight_id = skylight_values[:id]

      # Obtain skylight tilt from attached roof
      skylight_tilt = nil
      building.elements.each("BuildingDetails/Enclosure/Roofs/Roof") do |roof|
        roof_values = HPXML.get_roof_values(roof: roof)
        next unless roof_values[:id] == skylight_values[:roof_idref]

        skylight_tilt = roof_values[:pitch] / 12.0
      end
      if skylight_tilt.nil?
        fail "Attached roof '#{skylight_values[:roof_idref]}' not found for skylight '#{skylight_id}'."
      end

      skylight_area = skylight_values[:area]
      skylight_height = Math::sqrt(skylight_area)
      skylight_width = skylight_area / skylight_height
      z_origin = @walls_top + 0.5 * Math.sin(Math.atan(skylight_tilt)) * skylight_height
      skylight_azimuth = skylight_values[:azimuth]

      # Create parent surface slightly bigger than skylight
      surface = OpenStudio::Model::Surface.new(add_roof_polygon(skylight_width + 0.001, skylight_height + 0.001, z_origin,
                                                                skylight_azimuth, skylight_tilt), model)

      surface.additionalProperties.setFeature("Length", skylight_width)
      surface.additionalProperties.setFeature("Width", skylight_height)
      surface.additionalProperties.setFeature("Azimuth", skylight_azimuth)
      surface.additionalProperties.setFeature("Tilt", skylight_tilt)
      surface.setName("surface #{skylight_id}")
      surface.setSurfaceType("RoofCeiling")
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeLiving)) # Ensures it is included in Manual J sizing
      surface.setOutsideBoundaryCondition("Outdoors") # cannot be adiabatic because subsurfaces won't be created
      surfaces << surface

      sub_surface = OpenStudio::Model::SubSurface.new(add_roof_polygon(skylight_width, skylight_height, z_origin,
                                                                       skylight_azimuth, skylight_tilt), model)
      sub_surface.setName(skylight_id)
      sub_surface.setSurface(surface)
      sub_surface.setSubSurfaceType("Skylight")

      # Apply construction
      ufactor = skylight_values[:ufactor]
      shgc = skylight_values[:shgc]
      cool_shade_mult = 1.0
      heat_shade_mult = 1.0
      success = Constructions.apply_skylight(runner, model, [sub_surface],
                                             "SkylightConstruction",
                                             weather, cooling_season, ufactor, shgc,
                                             heat_shade_mult, cool_shade_mult)
      return false if not success
    end

    success = apply_adiabatic_construction(runner, model, surfaces, "roof")
    return false if not success

    return true
  end

  def self.add_doors(runner, model, building, spaces)
    surfaces = []
    building.elements.each("BuildingDetails/Enclosure/Doors/Door") do |door|
      door_values = HPXML.get_door_values(door: door)
      door_id = door_values[:id]

      door_area = door_values[:area]
      door_azimuth = door_values[:azimuth]

      door_height = 6.67 # ft
      door_width = door_area / door_height
      z_origin = @foundation_top

      # Create parent surface slightly bigger than door
      surface = OpenStudio::Model::Surface.new(add_wall_polygon(door_width, door_height, z_origin,
                                                                door_azimuth, [0, 0.001, 0.001, 0.001]), model)

      surface.additionalProperties.setFeature("Length", door_width)
      surface.additionalProperties.setFeature("Azimuth", door_azimuth)
      surface.additionalProperties.setFeature("Tilt", 90.0)
      surface.setName("surface #{door_id}")
      surface.setSurfaceType("Wall")
      assign_space_to_subsurface(surface, door_id, door_values[:wall_idref], building, spaces, model, "door")
      surface.setOutsideBoundaryCondition("Outdoors") # cannot be adiabatic because subsurfaces won't be created
      surfaces << surface

      sub_surface = OpenStudio::Model::SubSurface.new(add_wall_polygon(door_width, door_height, z_origin,
                                                                       door_azimuth, [0, 0, 0, 0]), model)
      sub_surface.setName(door_id)
      sub_surface.setSurface(surface)
      sub_surface.setSubSurfaceType("Door")

      # Apply construction
      ufactor = 1.0 / door_values[:r_value]

      success = Constructions.apply_door(runner, model, [sub_surface], "Door", ufactor)
      return false if not success
    end

    success = apply_adiabatic_construction(runner, model, surfaces, "wall")
    return false if not success

    return true
  end

  def self.apply_adiabatic_construction(runner, model, surfaces, type)
    # Arbitrary construction for heat capacitance.
    # Only applies to surfaces where outside boundary conditioned is
    # adiabatic or surface net area is near zero.

    if type == "wall"

      success = Constructions.apply_wood_stud_wall(runner, model, surfaces, "AdiabaticWallConstruction",
                                                   0, 1, 3.5, true, 0.1, 0.5, 0, 999,
                                                   Material.ExtFinishStuccoMedDark)
      return false if not success

    elsif type == "floor"

      success = Constructions.apply_floor(runner, model, surfaces, "AdiabaticFloorConstruction",
                                          0, 1, 0.07, 5.5, 0.75, 999,
                                          Material.FloorWood, Material.CoveringBare)
      return false if not success

    elsif type == "roof"

      success = Constructions.apply_open_cavity_roof(runner, model, surfaces, "AdiabaticRoofConstruction",
                                                     0, 1, 7.25, 0.07, 7.25, 0.75, 999,
                                                     Material.RoofingAsphaltShinglesMed, false)
      return false if not success

    end

    return true
  end

  def self.add_hot_water_and_appliances(runner, model, building, weather, spaces)
    # Clothes Washer
    clothes_washer_values = HPXML.get_clothes_washer_values(clothes_washer: building.elements["BuildingDetails/Appliances/ClothesWasher"])
    if not clothes_washer_values.nil?
      cw_space = get_space_from_location(clothes_washer_values[:location], "ClothesWasher", model, spaces)
      cw_ler = clothes_washer_values[:rated_annual_kwh]
      cw_elec_rate = clothes_washer_values[:label_electric_rate]
      cw_gas_rate = clothes_washer_values[:label_gas_rate]
      cw_agc = clothes_washer_values[:label_annual_gas_cost]
      cw_cap = clothes_washer_values[:capacity]
      cw_mef = clothes_washer_values[:modified_energy_factor]
      if cw_mef.nil?
        cw_mef = HotWaterAndAppliances.calc_clothes_washer_mef_from_imef(clothes_washer_values[:integrated_modified_energy_factor])
      end
    else
      cw_mef = cw_ler = cw_elec_rate = cw_gas_rate = cw_agc = cw_cap = cw_space = nil
    end

    # Clothes Dryer
    clothes_dryer_values = HPXML.get_clothes_dryer_values(clothes_dryer: building.elements["BuildingDetails/Appliances/ClothesDryer"])
    if not clothes_dryer_values.nil?
      cd_space = get_space_from_location(clothes_dryer_values[:location], "ClothesDryer", model, spaces)
      cd_fuel = to_beopt_fuel(clothes_dryer_values[:fuel_type])
      cd_control = clothes_dryer_values[:control_type]
      cd_ef = clothes_dryer_values[:energy_factor]
      if cd_ef.nil?
        cd_ef = HotWaterAndAppliances.calc_clothes_dryer_ef_from_cef(clothes_dryer_values[:combined_energy_factor])
      end
    else
      cd_ef = cd_control = cd_fuel = cd_space = nil
    end

    # Dishwasher
    dishwasher_values = HPXML.get_dishwasher_values(dishwasher: building.elements["BuildingDetails/Appliances/Dishwasher"])
    if not dishwasher_values.nil?
      dw_cap = dishwasher_values[:place_setting_capacity]
      dw_ef = dishwasher_values[:energy_factor]
      if dw_ef.nil?
        dw_ef = HotWaterAndAppliances.calc_dishwasher_ef_from_annual_kwh(dishwasher_values[:rated_annual_kwh])
      end
    else
      dw_ef = dw_cap = nil
    end

    # Refrigerator
    refrigerator_values = HPXML.get_refrigerator_values(refrigerator: building.elements["BuildingDetails/Appliances/Refrigerator"])
    if not refrigerator_values.nil?
      fridge_space = get_space_from_location(refrigerator_values[:location], "Refrigerator", model, spaces)
      fridge_annual_kwh = refrigerator_values[:rated_annual_kwh]
    else
      fridge_annual_kwh = fridge_space = nil
    end

    # Cooking Range/Oven
    cooking_range_values = HPXML.get_cooking_range_values(cooking_range: building.elements["BuildingDetails/Appliances/CookingRange"])
    oven_values = HPXML.get_oven_values(oven: building.elements["BuildingDetails/Appliances/Oven"])
    if not cooking_range_values.nil? and not oven_values.nil?
      cook_fuel_type = to_beopt_fuel(cooking_range_values[:fuel_type])
      cook_is_induction = cooking_range_values[:is_induction]
      oven_is_convection = oven_values[:is_convection]
    else
      cook_fuel_type = cook_is_induction = oven_is_convection = nil
    end

    wh = building.elements["BuildingDetails/Systems/WaterHeating"]

    # Fixtures
    has_low_flow_fixtures = false
    if not wh.nil?
      low_flow_fixtures_list = []
      wh.elements.each("WaterFixture[WaterFixtureType='shower head' or WaterFixtureType='faucet']") do |wf|
        water_fixture_values = HPXML.get_water_fixture_values(water_fixture: wf)
        low_flow_fixtures_list << water_fixture_values[:low_flow]
      end
      low_flow_fixtures_list.uniq!
      if low_flow_fixtures_list.size == 1 and low_flow_fixtures_list[0]
        has_low_flow_fixtures = true
      end
    end

    # Distribution
    if not wh.nil?
      dist = wh.elements["HotWaterDistribution"]
      hot_water_distribution_values = HPXML.get_hot_water_distribution_values(hot_water_distribution: wh.elements["HotWaterDistribution"])
      dist_type = hot_water_distribution_values[:system_type].downcase
      if dist_type == "standard"
        std_pipe_length = hot_water_distribution_values[:standard_piping_length]
        recirc_loop_length = nil
        recirc_branch_length = nil
        recirc_control_type = nil
        recirc_pump_power = nil
      elsif dist_type == "recirculation"
        recirc_loop_length = hot_water_distribution_values[:recirculation_piping_length]
        recirc_branch_length = hot_water_distribution_values[:recirculation_branch_piping_length]
        recirc_control_type = hot_water_distribution_values[:recirculation_control_type]
        recirc_pump_power = hot_water_distribution_values[:recirculation_pump_power]
        std_pipe_length = nil
      end
      pipe_r = hot_water_distribution_values[:pipe_r_value]
    end

    # Drain Water Heat Recovery
    dwhr_present = false
    dwhr_facilities_connected = nil
    dwhr_is_equal_flow = nil
    dwhr_efficiency = nil
    if not wh.nil?
      if XMLHelper.has_element(dist, "DrainWaterHeatRecovery")
        dwhr_present = true
        dwhr_facilities_connected = hot_water_distribution_values[:dwhr_facilities_connected]
        dwhr_is_equal_flow = hot_water_distribution_values[:dwhr_equal_flow]
        dwhr_efficiency = hot_water_distribution_values[:dwhr_efficiency]
      end
    end

    # Water Heater
    dhw_loop_fracs = {}
    water_heater_spaces = {}
    if not wh.nil?
      wh.elements.each("WaterHeatingSystem") do |dhw|
        water_heating_system_values = HPXML.get_water_heating_system_values(water_heating_system: dhw)

        sys_id = water_heating_system_values[:id]

        space = get_space_from_location(water_heating_system_values[:location], "WaterHeatingSystem", model, spaces)
        water_heater_spaces[sys_id] = space
        setpoint_temp = Waterheater.get_default_hot_water_temperature(@eri_version)
        wh_type = water_heating_system_values[:water_heater_type]
        fuel = water_heating_system_values[:fuel_type]

        ef = water_heating_system_values[:energy_factor]
        if ef.nil?
          uef = water_heating_system_values[:uniform_energy_factor]
          ef = Waterheater.calc_ef_from_uef(uef, to_beopt_wh_type(wh_type), to_beopt_fuel(fuel))
        end

        ec_adj = HotWaterAndAppliances.get_dist_energy_consumption_adjustment(@has_uncond_bsmnt, @cfa, @ncfl,
                                                                              dist_type, recirc_control_type,
                                                                              pipe_r, std_pipe_length, recirc_loop_length)

        dhw_load_frac = water_heating_system_values[:fraction_dhw_load_served]

        @dhw_map[sys_id] = []

        if wh_type == "storage water heater"

          tank_vol = water_heating_system_values[:tank_volume]
          if fuel != "electricity"
            re = water_heating_system_values[:recovery_efficiency]
          else
            re = 0.98
          end
          capacity_kbtuh = water_heating_system_values[:heating_capacity] / 1000.0
          oncycle_power = 0.0
          offcycle_power = 0.0
          success = Waterheater.apply_tank(model, runner, space, to_beopt_fuel(fuel),
                                           capacity_kbtuh, tank_vol, ef, re, setpoint_temp,
                                           oncycle_power, offcycle_power, ec_adj,
                                           @nbeds, @dhw_map, sys_id)
          return false if not success

        elsif wh_type == "instantaneous water heater"

          cycling_derate = water_heating_system_values[:performance_adjustment]
          if cycling_derate.nil?
            cycling_derate = Waterheater.get_tankless_cycling_derate()
          end

          capacity_kbtuh = 100000000.0
          oncycle_power = 0.0
          offcycle_power = 0.0
          success = Waterheater.apply_tankless(model, runner, space, to_beopt_fuel(fuel),
                                               capacity_kbtuh, ef, cycling_derate,
                                               setpoint_temp, oncycle_power, offcycle_power, ec_adj,
                                               @nbeds, @dhw_map, sys_id)
          return false if not success

        elsif wh_type == "heat pump water heater"

          tank_vol = water_heating_system_values[:tank_volume]
          success = Waterheater.apply_heatpump(model, runner, space, weather, setpoint_temp, tank_vol, ef, ec_adj,
                                               @nbeds, @dhw_map, sys_id)

          return false if not success

        else

          fail "Unhandled water heater (#{wh_type})."

        end

        dhw_loop_fracs[sys_id] = dhw_load_frac
      end
    end

    wh_setpoint = Waterheater.get_default_hot_water_temperature(@eri_version)
    living_space = get_space_of_type(spaces, Constants.SpaceTypeLiving)
    success = HotWaterAndAppliances.apply(model, runner, weather, living_space,
                                          @cfa, @nbeds, @ncfl, @has_uncond_bsmnt, wh_setpoint,
                                          cw_mef, cw_ler, cw_elec_rate, cw_gas_rate,
                                          cw_agc, cw_cap, cw_space, cd_fuel, cd_ef, cd_control,
                                          cd_space, dw_ef, dw_cap, fridge_annual_kwh, fridge_space,
                                          cook_fuel_type, cook_is_induction, oven_is_convection,
                                          has_low_flow_fixtures, dist_type, pipe_r,
                                          std_pipe_length, recirc_loop_length,
                                          recirc_branch_length, recirc_control_type,
                                          recirc_pump_power, dwhr_present,
                                          dwhr_facilities_connected, dwhr_is_equal_flow,
                                          dwhr_efficiency, dhw_loop_fracs, @eri_version,
                                          @dhw_map)
    return false if not success

    solar_thermal_values = HPXML.get_solar_thermal_system_values(solar_thermal_system: building.elements["BuildingDetails/Systems/SolarThermal/SolarThermalSystem"])
    if not solar_thermal_values.nil?
      collector_area = solar_thermal_values[:collector_area]
      frta = solar_thermal_values[:collector_frta]
      frul = solar_thermal_values[:collector_frul]
      iam = 0.1 # TODO: Review. Incident angle modifier coefficient
      storage_vol = solar_thermal_values[:storage_volume]
      tank_r = 10.0 # TODO: Review
      fluid_type = Constants.FluidPropyleneGlycol # TODO: Review
      heat_ex_eff = 0.7 # TODO: Review
      pump_power = 0.8 * collector_area # TODO: Review
      azimuth = Float(solar_thermal_values[:collector_azimuth]) # FIXME: Test
      tilt = solar_thermal_values[:collector_tilt] # FIXME: Test
      dhw_system_idref = solar_thermal_values[:water_heating_system_idref]
      space = water_heater_spaces[dhw_system_idref]

      dhw_loop = nil
      if @dhw_map.keys.include? dhw_system_idref
        @dhw_map[dhw_system_idref].each do |dhw_object|
          next unless dhw_object.is_a? OpenStudio::Model::PlantLoop

          dhw_loop = dhw_object
        end
      else
        fail "ConnectedTo '#{dhw_system_idref}' not found for solar thermal system '#{solar_thermal_values[:id]}'."
      end

      success = Waterheater.apply_solar_thermal(model, runner, space, collector_area, frta,
                                                frul, iam, storage_vol, tank_r, fluid_type,
                                                heat_ex_eff, pump_power, azimuth, tilt,
                                                dhw_loop, @dhw_map, dhw_system_idref)
      return false if not success
    end

    return true
  end

  def self.add_cooling_system(runner, model, building)
    return true if @use_only_ideal_air

    building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem") do |clgsys|
      cooling_system_values = HPXML.get_cooling_system_values(cooling_system: clgsys)

      clg_type = cooling_system_values[:cooling_system_type]

      cool_capacity_btuh = cooling_system_values[:cooling_capacity]
      if cool_capacity_btuh < 0
        cool_capacity_btuh = Constants.SizingAuto
      end

      load_frac = cooling_system_values[:fraction_cool_load_served]
      sequential_load_frac = load_frac / @total_frac_remaining_cool_load_served # Fraction of remaining load served by this system
      @total_frac_remaining_cool_load_served -= load_frac

      dse_heat, dse_cool, has_dse = get_dse(building, cooling_system_values)

      sys_id = cooling_system_values[:id]
      @hvac_map[sys_id] = []

      if clg_type == "central air conditioning"

        # FIXME: Generalize
        seer = cooling_system_values[:cooling_efficiency_seer]
        num_speeds = get_ac_num_speeds(seer)
        crankcase_kw = 0.05 # From RESNET Publication No. 002-2017
        crankcase_temp = 50.0 # From RESNET Publication No. 002-2017

        if num_speeds == "1-Speed"

          shrs = [0.73]
          fan_power_installed = get_fan_power_installed(seer)
          success = HVAC.apply_central_ac_1speed(model, runner, seer, shrs,
                                                 fan_power_installed, crankcase_kw, crankcase_temp,
                                                 cool_capacity_btuh, dse_cool, load_frac,
                                                 sequential_load_frac, @control_slave_zones_hash,
                                                 @hvac_map, sys_id)
          return false if not success

        elsif num_speeds == "2-Speed"

          shrs = [0.71, 0.73]
          fan_power_installed = get_fan_power_installed(seer)
          success = HVAC.apply_central_ac_2speed(model, runner, seer, shrs,
                                                 fan_power_installed, crankcase_kw, crankcase_temp,
                                                 cool_capacity_btuh, dse_cool, load_frac,
                                                 sequential_load_frac, @control_slave_zones_hash,
                                                 @hvac_map, sys_id)
          return false if not success

        elsif num_speeds == "Variable-Speed"

          shrs = [0.87, 0.80, 0.79, 0.78]
          fan_power_installed = get_fan_power_installed(seer)
          success = HVAC.apply_central_ac_4speed(model, runner, seer, shrs,
                                                 fan_power_installed, crankcase_kw, crankcase_temp,
                                                 cool_capacity_btuh, dse_cool, load_frac,
                                                 sequential_load_frac, @control_slave_zones_hash,
                                                 @hvac_map, sys_id)
          return false if not success

        else

          fail "Unexpected number of speeds (#{num_speeds}) for cooling system."

        end

      elsif clg_type == "room air conditioner"

        eer = cooling_system_values[:cooling_efficiency_eer]
        shr = 0.65
        airflow_rate = 350.0
        success = HVAC.apply_room_ac(model, runner, eer, shr,
                                     airflow_rate, cool_capacity_btuh, load_frac,
                                     sequential_load_frac, @control_slave_zones_hash,
                                     @hvac_map, sys_id)
        return false if not success

      end
    end

    return true
  end

  def self.add_heating_system(runner, model, building)
    return true if @use_only_ideal_air

    # We need to process furnaces attached to ACs before any other heating system
    # such that the sequential load heating fraction is properly applied.

    [true, false].each do |only_furnaces_attached_to_cooling|
      building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem") do |htgsys|
        heating_system_values = HPXML.get_heating_system_values(heating_system: htgsys)

        htg_type = heating_system_values[:heating_system_type]

        dse_heat, dse_cool, has_dse = get_dse(building, heating_system_values)

        attached_clg_system = get_attached_system(heating_system_values, building,
                                                  "CoolingSystem", has_dse)

        if only_furnaces_attached_to_cooling
          next unless htg_type == "Furnace" and not attached_clg_system.nil?
        else
          next if htg_type == "Furnace" and not attached_clg_system.nil?
        end

        fuel = to_beopt_fuel(heating_system_values[:heating_system_fuel])

        heat_capacity_btuh = heating_system_values[:heating_capacity]
        if heat_capacity_btuh < 0
          heat_capacity_btuh = Constants.SizingAuto
        end

        load_frac = heating_system_values[:fraction_heat_load_served]
        sequential_load_frac = load_frac / @total_frac_remaining_heat_load_served # Fraction of remaining load served by this system
        @total_frac_remaining_heat_load_served -= load_frac

        sys_id = heating_system_values[:id]
        @hvac_map[sys_id] = []

        if htg_type == "Furnace"

          afue = heating_system_values[:heating_efficiency_afue]
          fan_power = 0.5 # For fuel furnaces, will be overridden by EAE later
          success = HVAC.apply_furnace(model, runner, fuel, afue,
                                       heat_capacity_btuh, fan_power, dse_heat,
                                       load_frac, sequential_load_frac,
                                       attached_clg_system, @control_slave_zones_hash,
                                       @hvac_map, sys_id)
          return false if not success

        elsif htg_type == "WallFurnace"

          afue = heating_system_values[:heating_efficiency_afue]
          fan_power = 0.0
          airflow_rate = 0.0
          success = HVAC.apply_unit_heater(model, runner, fuel,
                                           afue, heat_capacity_btuh, fan_power,
                                           airflow_rate, load_frac,
                                           sequential_load_frac, @control_slave_zones_hash,
                                           @hvac_map, sys_id)
          return false if not success

        elsif htg_type == "Boiler"

          system_type = Constants.BoilerTypeForcedDraft
          afue = heating_system_values[:heating_efficiency_afue]
          oat_reset_enabled = false
          oat_high = nil
          oat_low = nil
          oat_hwst_high = nil
          oat_hwst_low = nil
          design_temp = 180.0
          success = HVAC.apply_boiler(model, runner, fuel, system_type, afue,
                                      oat_reset_enabled, oat_high, oat_low, oat_hwst_high, oat_hwst_low,
                                      heat_capacity_btuh, design_temp, dse_heat, load_frac,
                                      sequential_load_frac, @control_slave_zones_hash,
                                      @hvac_map, sys_id)
          return false if not success

        elsif htg_type == "ElectricResistance"

          efficiency = heating_system_values[:heating_efficiency_percent]
          success = HVAC.apply_electric_baseboard(model, runner, efficiency,
                                                  heat_capacity_btuh, load_frac,
                                                  sequential_load_frac, @control_slave_zones_hash,
                                                  @hvac_map, sys_id)
          return false if not success

        elsif htg_type == "Stove"

          efficiency = heating_system_values[:heating_efficiency_percent]
          airflow_rate = 125.0 # cfm/ton; doesn't affect energy consumption
          fan_power = 0.5 # For fuel equipment, will be overridden by EAE later
          success = HVAC.apply_unit_heater(model, runner, fuel,
                                           efficiency, heat_capacity_btuh, fan_power,
                                           airflow_rate, load_frac,
                                           sequential_load_frac, @control_slave_zones_hash,
                                           @hvac_map, sys_id)
          return false if not success

        end
      end
    end

    return true
  end

  def self.add_heat_pump(runner, model, building, weather)
    return true if @use_only_ideal_air

    building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/HeatPump") do |hp|
      heat_pump_values = HPXML.get_heat_pump_values(heat_pump: hp)

      hp_type = heat_pump_values[:heat_pump_type]

      cool_capacity_btuh = heat_pump_values[:cooling_capacity]
      if cool_capacity_btuh < 0
        cool_capacity_btuh = Constants.SizingAuto
      end

      load_frac_heat = heat_pump_values[:fraction_heat_load_served]
      sequential_load_frac_heat = load_frac_heat / @total_frac_remaining_heat_load_served # Fraction of remaining load served by this system
      @total_frac_remaining_heat_load_served -= load_frac_heat

      load_frac_cool = heat_pump_values[:fraction_cool_load_served]
      sequential_load_frac_cool = load_frac_cool / @total_frac_remaining_cool_load_served # Fraction of remaining load served by this system
      @total_frac_remaining_cool_load_served -= load_frac_cool

      backup_heat_fuel = heat_pump_values[:backup_heating_fuel]
      if not backup_heat_fuel.nil?
        backup_heat_capacity_btuh = heat_pump_values[:backup_heating_capacity]
        if backup_heat_capacity_btuh < 0
          backup_heat_capacity_btuh = Constants.SizingAuto
        end
        backup_heat_efficiency = heat_pump_values[:backup_heating_efficiency_percent]
      else
        backup_heat_capacity_btuh = 0.0
        backup_heat_efficiency = 1.0
      end

      dse_heat, dse_cool, has_dse = get_dse(building, heat_pump_values)
      if dse_heat != dse_cool
        # FUTURE: Remove this when available in E+
        fail "Cannot handle different distribution system efficiency (DSE) values for heating and cooling."
      end

      sys_id = heat_pump_values[:id]
      @hvac_map[sys_id] = []

      if hp_type == "air-to-air"

        seer = heat_pump_values[:cooling_efficiency_seer]
        hspf = heat_pump_values[:heating_efficiency_hspf]

        if load_frac_cool > 0
          num_speeds = get_ashp_num_speeds_by_seer(seer)
        else
          num_speeds = get_ashp_num_speeds_by_hspf(hspf)
        end

        crankcase_kw = 0.05 # From RESNET Publication No. 002-2017
        crankcase_temp = 50.0 # From RESNET Publication No. 002-2017
        min_temp = 0.0 # FIXME

        if num_speeds == "1-Speed"

          shrs = [0.73]
          fan_power_installed = get_fan_power_installed(seer)
          success = HVAC.apply_central_ashp_1speed(model, runner, seer, hspf, shrs,
                                                   fan_power_installed, min_temp, crankcase_kw, crankcase_temp,
                                                   cool_capacity_btuh, backup_heat_efficiency,
                                                   backup_heat_capacity_btuh, dse_heat,
                                                   load_frac_heat, load_frac_cool,
                                                   sequential_load_frac_heat, sequential_load_frac_cool,
                                                   @control_slave_zones_hash, @hvac_map, sys_id)
          return false if not success

        elsif num_speeds == "2-Speed"

          shrs = [0.71, 0.724]
          fan_power_installed = get_fan_power_installed(seer)
          success = HVAC.apply_central_ashp_2speed(model, runner, seer, hspf, shrs,
                                                   fan_power_installed, min_temp, crankcase_kw, crankcase_temp,
                                                   cool_capacity_btuh, backup_heat_efficiency,
                                                   backup_heat_capacity_btuh, dse_heat,
                                                   load_frac_heat, load_frac_cool,
                                                   sequential_load_frac_heat, sequential_load_frac_cool,
                                                   @control_slave_zones_hash, @hvac_map, sys_id)
          return false if not success

        elsif num_speeds == "Variable-Speed"

          shrs = [0.87, 0.80, 0.79, 0.78]
          fan_power_installed = get_fan_power_installed(seer)
          success = HVAC.apply_central_ashp_4speed(model, runner, seer, hspf, shrs,
                                                   fan_power_installed, min_temp, crankcase_kw, crankcase_temp,
                                                   cool_capacity_btuh, backup_heat_efficiency,
                                                   backup_heat_capacity_btuh, dse_heat,
                                                   load_frac_heat, load_frac_cool,
                                                   sequential_load_frac_heat, sequential_load_frac_cool,
                                                   @control_slave_zones_hash, @hvac_map, sys_id)
          return false if not success

        else

          fail "Unexpected number of speeds (#{num_speeds}) for heat pump system."

        end

      elsif hp_type == "mini-split"

        # FIXME: Generalize
        seer = heat_pump_values[:cooling_efficiency_seer]
        hspf = heat_pump_values[:heating_efficiency_hspf]
        shr = 0.73
        min_cooling_capacity = 0.4
        max_cooling_capacity = 1.2
        min_cooling_airflow_rate = 200.0
        max_cooling_airflow_rate = 425.0
        min_heating_capacity = 0.3
        max_heating_capacity = 1.2
        min_heating_airflow_rate = 200.0
        max_heating_airflow_rate = 400.0
        heating_capacity_offset = 2300.0
        cap_retention_frac = 0.25
        cap_retention_temp = -5.0
        pan_heater_power = 0.0
        fan_power = 0.07
        is_ducted = (XMLHelper.has_element(hp, "DistributionSystem") and not has_dse)
        success = HVAC.apply_mshp(model, runner, seer, hspf, shr,
                                  min_cooling_capacity, max_cooling_capacity,
                                  min_cooling_airflow_rate, max_cooling_airflow_rate,
                                  min_heating_capacity, max_heating_capacity,
                                  min_heating_airflow_rate, max_heating_airflow_rate,
                                  heating_capacity_offset, cap_retention_frac,
                                  cap_retention_temp, pan_heater_power, fan_power,
                                  is_ducted, cool_capacity_btuh,
                                  backup_heat_efficiency, backup_heat_capacity_btuh,
                                  dse_heat, load_frac_heat, load_frac_cool,
                                  sequential_load_frac_heat, sequential_load_frac_cool,
                                  @control_slave_zones_hash, @hvac_map, sys_id)
        return false if not success

      elsif hp_type == "ground-to-air"

        # FIXME: Generalize
        eer = heat_pump_values[:cooling_efficiency_eer]
        cop = heat_pump_values[:heating_efficiency_cop]
        shr = 0.732
        ground_conductivity = 0.6
        grout_conductivity = 0.4
        bore_config = Constants.SizingAuto
        bore_holes = Constants.SizingAuto
        bore_depth = Constants.SizingAuto
        bore_spacing = 20.0
        bore_diameter = 5.0
        pipe_size = 0.75
        ground_diffusivity = 0.0208
        fluid_type = Constants.FluidPropyleneGlycol
        frac_glycol = 0.3
        design_delta_t = 10.0
        pump_head = 50.0
        u_tube_leg_spacing = 0.9661
        u_tube_spacing_type = "b"
        fan_power = 0.5
        success = HVAC.apply_gshp(model, runner, weather, cop, eer, shr,
                                  ground_conductivity, grout_conductivity,
                                  bore_config, bore_holes, bore_depth,
                                  bore_spacing, bore_diameter, pipe_size,
                                  ground_diffusivity, fluid_type, frac_glycol,
                                  design_delta_t, pump_head,
                                  u_tube_leg_spacing, u_tube_spacing_type,
                                  fan_power, cool_capacity_btuh, backup_heat_efficiency,
                                  backup_heat_capacity_btuh, dse_heat,
                                  load_frac_heat, load_frac_cool,
                                  sequential_load_frac_heat, sequential_load_frac_cool,
                                  @control_slave_zones_hash, @hvac_map, sys_id)
        return false if not success

      end
    end

    return true
  end

  def self.add_residual_hvac(runner, model, building)
    if @use_only_ideal_air
      success = HVAC.apply_ideal_air_loads(model, runner, 1, 1, 1, 1, @control_slave_zones_hash)
      return false if not success

      return true
    end

    @total_frac_remaining_cool_load_served = 0 if @total_frac_remaining_cool_load_served >= 0.99
    @total_frac_remaining_heat_load_served = 0 if @total_frac_remaining_heat_load_served >= 0.99

    # Only add ideal air if heating/cooling system doesn't meet entire load
    if @total_frac_remaining_heat_load_served > 0.01 or @total_frac_remaining_cool_load_served > 0.01
      if @total_frac_remaining_cool_load_served > 0.01
        sequential_cool_load_frac = 1
      else
        sequential_cool_load_frac = 0
      end

      if @total_frac_remaining_heat_load_served > 0.01
        sequential_heat_load_frac = 1
      else
        sequential_heat_load_frac = 0
      end
      success = HVAC.apply_ideal_air_loads(model, runner,
                                           @total_frac_remaining_cool_load_served,
                                           @total_frac_remaining_heat_load_served,
                                           sequential_cool_load_frac,
                                           sequential_heat_load_frac,
                                           @control_slave_zones_hash)
      return false if not success
    end

    return true
  end

  def self.add_setpoints(runner, model, building, weather, spaces)
    hvac_control_values = HPXML.get_hvac_control_values(hvac_control: building.elements["BuildingDetails/Systems/HVAC/HVACControl"])
    return true if hvac_control_values.nil?

    conditioned_zones = get_spaces_of_type(spaces, [Constants.SpaceTypeLiving, Constants.SpaceTypeConditionedBasement]).map { |z| z.thermalZone.get }.compact

    control_type = hvac_control_values[:control_type]
    heating_temp = hvac_control_values[:setpoint_temp_heating_season]
    if not heating_temp.nil? # Use provided value
      htg_weekday_setpoints = [[heating_temp] * 24] * 12
    else # Use ERI default
      htg_sp, htg_setback_sp, htg_setback_hrs_per_week, htg_setback_start_hr = HVAC.get_default_heating_setpoint(control_type)
      if htg_setback_sp.nil?
        htg_weekday_setpoints = [[htg_sp] * 24] * 12
      else
        htg_weekday_setpoints = [[htg_sp] * 24] * 12
        (0..11).to_a.each do |m|
          for hr in htg_setback_start_hr..htg_setback_start_hr + Integer(htg_setback_hrs_per_week / 7.0) - 1
            htg_weekday_setpoints[m][hr % 24] = htg_setback_sp
          end
        end
      end
    end
    htg_weekend_setpoints = htg_weekday_setpoints
    htg_use_auto_season = false
    htg_season_start_month = 1
    htg_season_end_month = 12
    success = HVAC.apply_heating_setpoints(model, runner, weather, htg_weekday_setpoints, htg_weekend_setpoints,
                                           htg_use_auto_season, htg_season_start_month, htg_season_end_month,
                                           conditioned_zones)
    return false if not success

    cooling_temp = hvac_control_values[:setpoint_temp_cooling_season]
    if not cooling_temp.nil? # Use provided value
      clg_weekday_setpoints = [[cooling_temp] * 24] * 12
    else # Use ERI default
      clg_sp, clg_setup_sp, clg_setup_hrs_per_week, clg_setup_start_hr = HVAC.get_default_cooling_setpoint(control_type)
      if clg_setup_sp.nil?
        clg_weekday_setpoints = [[clg_sp] * 24] * 12
      else
        clg_weekday_setpoints = [[clg_sp] * 24] * 12
        (0..11).to_a.each do |m|
          for hr in clg_setup_start_hr..clg_setup_start_hr + Integer(clg_setup_hrs_per_week / 7.0) - 1
            clg_weekday_setpoints[m][hr % 24] = clg_setup_sp
          end
        end
      end
    end
    # Apply ceiling fan offset?
    if not building.elements["BuildingDetails/Lighting/CeilingFan"].nil?
      cooling_setpoint_offset = 0.5 # deg-F
      monthly_avg_temp_control = 63.0 # deg-F
      weather.data.MonthlyAvgDrybulbs.each_with_index do |val, m|
        next unless val > monthly_avg_temp_control

        clg_weekday_setpoints[m] = [clg_weekday_setpoints[m], Array.new(24, cooling_setpoint_offset)].transpose.map { |i| i.reduce(:+) }
      end
    end
    clg_weekend_setpoints = clg_weekday_setpoints
    clg_use_auto_season = false
    clg_season_start_month = 1
    clg_season_end_month = 12
    success = HVAC.apply_cooling_setpoints(model, runner, weather, clg_weekday_setpoints, clg_weekend_setpoints,
                                           clg_use_auto_season, clg_season_start_month, clg_season_end_month,
                                           conditioned_zones)
    return false if not success

    return true
  end

  def self.add_ceiling_fans(runner, model, building, spaces)
    ceiling_fan_values = HPXML.get_ceiling_fan_values(ceiling_fan: building.elements["BuildingDetails/Lighting/CeilingFan"])
    return true if ceiling_fan_values.nil?

    medium_cfm = 3000.0
    weekday_sch = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0]
    weekend_sch = weekday_sch
    hrs_per_day = weekday_sch.inject { |sum, n| sum + n }

    cfm_per_w = ceiling_fan_values[:efficiency]
    if cfm_per_w.nil?
      fan_power_w = HVAC.get_default_ceiling_fan_power()
      cfm_per_w = medium_cfm / fan_power_w
    end
    quantity = ceiling_fan_values[:quantity]
    if quantity.nil?
      quantity = HVAC.get_default_ceiling_fan_quantity(@nbeds)
    end
    annual_kwh = UnitConversions.convert(quantity * medium_cfm / cfm_per_w * hrs_per_day * 365.0, "Wh", "kWh")

    conditioned_spaces = get_spaces_of_type(spaces, [Constants.SpaceTypeLiving, Constants.SpaceTypeConditionedBasement])
    success = HVAC.apply_ceiling_fans(model, runner, annual_kwh, weekday_sch, weekend_sch,
                                      @cfa, conditioned_spaces)
    return false if not success

    return true
  end

  def self.get_dse(building, system_values)
    dist_id = system_values[:distribution_system_idref]
    if dist_id.nil? # No distribution system
      return 1.0, 1.0, false
    end

    # Get attached distribution system
    attached_dist = nil
    found_attached_dist = nil
    annual_cooling_dse = nil
    annual_heating_dse = nil
    building.elements.each("BuildingDetails/Systems/HVAC/HVACDistribution") do |dist|
      hvac_distribution_values = HPXML.get_hvac_distribution_values(hvac_distribution: dist)
      next if dist_id != hvac_distribution_values[:id]

      found_attached_dist = true
      next if hvac_distribution_values[:distribution_system_type] != 'DSE'

      attached_dist = dist
      annual_cooling_dse = hvac_distribution_values[:annual_cooling_dse]
      annual_heating_dse = hvac_distribution_values[:annual_heating_dse]
    end

    if not found_attached_dist
      fail "Attached HVAC distribution system '#{dist_id}' cannot be found for HVAC system '#{system_values[:id]}'."
    end

    if attached_dist.nil? # No attached DSEs for system
      return 1.0, 1.0, false
    end

    dse_cool = annual_cooling_dse
    dse_heat = annual_heating_dse
    return dse_heat, dse_cool, true
  end

  def self.add_mels(runner, model, building, spaces)
    # Misc
    plug_load_values = HPXML.get_plug_load_values(plug_load: building.elements["BuildingDetails/MiscLoads/PlugLoad[PlugLoadType='other']"])
    if not plug_load_values.nil?
      misc_annual_kwh = plug_load_values[:kWh_per_year]
      if misc_annual_kwh.nil?
        misc_annual_kwh = MiscLoads.get_residual_mels_values(@cfa)[0]
      end

      misc_sens_frac = plug_load_values[:frac_sensible]
      if misc_sens_frac.nil?
        misc_sens_frac = MiscLoads.get_residual_mels_values(@cfa)[1]
      end

      misc_lat_frac = plug_load_values[:frac_latent]
      if misc_lat_frac.nil?
        misc_lat_frac = MiscLoads.get_residual_mels_values(@cfa)[2]
      end

      misc_loads_schedule_values = HPXML.get_misc_loads_schedule_values(misc_loads: building.elements["BuildingDetails/MiscLoads"])
      misc_weekday_sch = misc_loads_schedule_values[:weekday_fractions]
      if misc_weekday_sch.nil?
        misc_weekday_sch = "0.04, 0.037, 0.037, 0.036, 0.033, 0.036, 0.043, 0.047, 0.034, 0.023, 0.024, 0.025, 0.024, 0.028, 0.031, 0.032, 0.039, 0.053, 0.063, 0.067, 0.071, 0.069, 0.059, 0.05"
      end

      misc_weekend_sch = misc_loads_schedule_values[:weekend_fractions]
      if misc_weekend_sch.nil?
        misc_weekend_sch = "0.04, 0.037, 0.037, 0.036, 0.033, 0.036, 0.043, 0.047, 0.034, 0.023, 0.024, 0.025, 0.024, 0.028, 0.031, 0.032, 0.039, 0.053, 0.063, 0.067, 0.071, 0.069, 0.059, 0.05"
      end

      misc_monthly_sch = misc_loads_schedule_values[:monthly_multipliers]
      if misc_monthly_sch.nil?
        misc_monthly_sch = "1.248, 1.257, 0.993, 0.989, 0.993, 0.827, 0.821, 0.821, 0.827, 0.99, 0.987, 1.248"
      end
    else
      misc_annual_kwh = 0
    end

    # Television
    plug_load_values = HPXML.get_plug_load_values(plug_load: building.elements["BuildingDetails/MiscLoads/PlugLoad[PlugLoadType='TV other']"])
    if not plug_load_values.nil?
      tv_annual_kwh = plug_load_values[:kWh_per_year]
      if tv_annual_kwh.nil?
        tv_annual_kwh, tv_sens_frac, tv_lat_frac = MiscLoads.get_televisions_values(@cfa, @nbeds)
      end
    else
      tv_annual_kwh = 0
    end

    conditioned_spaces = get_spaces_of_type(spaces, [Constants.SpaceTypeLiving, Constants.SpaceTypeConditionedBasement])
    success, sch = MiscLoads.apply_plug(model, runner, misc_annual_kwh, misc_sens_frac, misc_lat_frac,
                                        misc_weekday_sch, misc_weekend_sch, misc_monthly_sch, tv_annual_kwh,
                                        @cfa, conditioned_spaces)
    return false if not success

    return true
  end

  def self.add_lighting(runner, model, building, weather, spaces)
    lighting = building.elements["BuildingDetails/Lighting"]
    return true if lighting.nil?

    lighting_values = HPXML.get_lighting_values(lighting: lighting)

    if lighting_values[:fraction_tier_i_interior] + lighting_values[:fraction_tier_ii_interior] > 1
      fail "Fraction of qualifying interior lighting fixtures #{lighting_values[:fraction_tier_i_interior] + lighting_values[:fraction_tier_ii_interior]} is greater than 1."
    end
    if lighting_values[:fraction_tier_i_exterior] + lighting_values[:fraction_tier_ii_exterior] > 1
      fail "Fraction of qualifying exterior lighting fixtures #{lighting_values[:fraction_tier_i_exterior] + lighting_values[:fraction_tier_ii_exterior]} is greater than 1."
    end
    if lighting_values[:fraction_tier_i_garage] + lighting_values[:fraction_tier_ii_garage] > 1
      fail "Fraction of qualifying garage lighting fixtures #{lighting_values[:fraction_tier_i_garage] + lighting_values[:fraction_tier_ii_garage]} is greater than 1."
    end

    int_kwh, ext_kwh, grg_kwh = Lighting.calc_lighting_energy(@eri_version, @cfa, @gfa,
                                                              lighting_values[:fraction_tier_i_interior],
                                                              lighting_values[:fraction_tier_i_exterior],
                                                              lighting_values[:fraction_tier_i_garage],
                                                              lighting_values[:fraction_tier_ii_interior],
                                                              lighting_values[:fraction_tier_ii_exterior],
                                                              lighting_values[:fraction_tier_ii_garage])

    conditioned_spaces = get_spaces_of_type(spaces, [Constants.SpaceTypeLiving, Constants.SpaceTypeConditionedBasement])
    garage_spaces = get_spaces_of_type(spaces, [Constants.SpaceTypeGarage])
    success, sch = Lighting.apply(model, runner, weather, int_kwh, grg_kwh, ext_kwh, @cfa, @gfa,
                                  conditioned_spaces, garage_spaces)
    return false if not success

    return true
  end

  def self.add_airflow(runner, model, building, spaces)
    # Infiltration
    infilvolume = nil
    building.elements.each("BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement") do |air_infiltration_measurement|
      air_infiltration_measurement_values = HPXML.get_air_infiltration_measurement_values(air_infiltration_measurement: air_infiltration_measurement)
      infilvolume = air_infiltration_measurement_values[:infiltration_volume] unless air_infiltration_measurement_values[:infiltration_volume].nil?
    end
    if infilvolume.nil?
      infilvolume = @cvolume
    end

    infil_ach50 = nil
    infil_const_ach = nil
    building.elements.each("BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement") do |air_infiltration_measurement|
      air_infiltration_measurement_values = HPXML.get_air_infiltration_measurement_values(air_infiltration_measurement: air_infiltration_measurement)
      if air_infiltration_measurement_values[:house_pressure] == 50 and air_infiltration_measurement_values[:unit_of_measure] == "ACH"
        infil_ach50 = air_infiltration_measurement_values[:air_leakage]
      elsif air_infiltration_measurement_values[:house_pressure] == 50 and air_infiltration_measurement_values[:unit_of_measure] == "CFM"
        infil_ach50 = air_infiltration_measurement_values[:air_leakage] * 60.0 / infilvolume # Convert CFM50 to ACH50
      else
        infil_const_ach = air_infiltration_measurement_values[:constant_ach_natural]
      end
    end

    vented_attic_sla = nil
    vented_attic_const_ach = nil
    if @has_vented_attic
      building.elements.each("BuildingDetails/Enclosure/Attics/Attic[AtticType/Attic[Vented='true']]") do |vented_attic|
        vented_attic_values = HPXML.get_attic_values(attic: vented_attic)
        vented_attic_sla = vented_attic_values[:vented_attic_sla]
        vented_attic_const_ach = vented_attic_values[:vented_attic_constant_ach]
      end
      if vented_attic_sla.nil? and vented_attic_const_ach.nil?
        vented_attic_sla = Airflow.get_default_vented_attic_sla()
      end
    else
      vented_attic_sla = 0.0
    end

    vented_crawl_sla = nil
    if @has_vented_crawl
      building.elements.each("BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/Crawlspace[Vented='true']]") do |vented_crawl|
        vented_crawl_values = HPXML.get_foundation_values(foundation: vented_crawl)
        vented_crawl_sla = vented_crawl_values[:vented_crawlspace_sla]
      end
      if vented_crawl_sla.nil?
        vented_crawl_sla = Airflow.get_default_vented_crawl_sla()
      end
    else
      vented_crawl_sla = 0.0
    end

    living_ach50 = infil_ach50
    living_constant_ach = infil_const_ach
    garage_ach50 = infil_ach50
    conditioned_basement_ach = 0
    unconditioned_basement_ach = 0.1
    unvented_crawl_sla = 0
    unvented_attic_sla = 0
    site_values = HPXML.get_site_values(site: building.elements["BuildingDetails/BuildingSummary/Site"])
    shelter_coef = site_values[:shelter_coefficient]
    if shelter_coef.nil?
      shelter_coef = Airflow.get_default_shelter_coefficient()
    end
    has_flue_chimney = false
    terrain = Constants.TerrainSuburban
    infil = Infiltration.new(living_ach50, living_constant_ach, shelter_coef, garage_ach50, vented_crawl_sla, unvented_crawl_sla,
                             vented_attic_sla, unvented_attic_sla, vented_attic_const_ach, unconditioned_basement_ach,
                             conditioned_basement_ach, has_flue_chimney, terrain)

    # Mechanical Ventilation
    whole_house_fan = building.elements["BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation='true']"]
    whole_house_fan_values = HPXML.get_ventilation_fan_values(ventilation_fan: whole_house_fan)
    mech_vent_type = Constants.VentTypeNone
    mech_vent_total_efficiency = 0.0
    mech_vent_sensible_efficiency = 0.0
    mech_vent_fan_w = 0.0
    mech_vent_cfm = 0.0
    cfis_open_time = 0.0
    if not whole_house_fan_values.nil?
      fan_type = whole_house_fan_values[:fan_type]
      if fan_type == "supply only"
        mech_vent_type = Constants.VentTypeSupply
        num_fans = 1.0
      elsif fan_type == "exhaust only"
        mech_vent_type = Constants.VentTypeExhaust
        num_fans = 1.0
      elsif fan_type == "central fan integrated supply"
        mech_vent_type = Constants.VentTypeCFIS
        num_fans = 1.0
      elsif ["balanced", "energy recovery ventilator", "heat recovery ventilator"].include? fan_type
        mech_vent_type = Constants.VentTypeBalanced
        num_fans = 2.0
      end
      mech_vent_total_efficiency = 0.0
      mech_vent_sensible_efficiency = 0.0
      if fan_type == "energy recovery ventilator" or fan_type == "heat recovery ventilator"
        mech_vent_sensible_efficiency = whole_house_fan_values[:sensible_recovery_efficiency]
      end
      if fan_type == "energy recovery ventilator"
        mech_vent_total_efficiency = whole_house_fan_values[:total_recovery_efficiency]
      end
      mech_vent_cfm = whole_house_fan_values[:rated_flow_rate]
      mech_vent_fan_w = whole_house_fan_values[:fan_power]
      if mech_vent_type == Constants.VentTypeCFIS
        # CFIS: Specify minimum open time in minutes
        cfis_open_time = whole_house_fan_values[:hours_in_operation] / 24.0 * 60.0
      else
        # Other: Adjust CFM based on hours/day of operation
        mech_vent_cfm *= (whole_house_fan_values[:hours_in_operation] / 24.0)
      end
    end
    cfis_airflow_frac = 1.0
    clothes_dryer_exhaust = 0.0
    range_exhaust = 0.0
    range_exhaust_hour = 16
    bathroom_exhaust = 0.0
    bathroom_exhaust_hour = 5

    # Get AirLoop associated with CFIS
    cfis_airloop = nil
    if mech_vent_type == Constants.VentTypeCFIS
      # Get HVAC distribution system CFIS is attached to
      cfis_hvac_dist = nil
      building.elements.each("BuildingDetails/Systems/HVAC/HVACDistribution") do |hvac_dist|
        next unless hvac_dist.elements["SystemIdentifier"].attributes["id"] == whole_house_fan.elements["AttachedToHVACDistributionSystem"].attributes["idref"]

        cfis_hvac_dist = hvac_dist
      end
      if cfis_hvac_dist.nil?
        fail "Attached HVAC distribution system '#{whole_house_fan.elements['AttachedToHVACDistributionSystem'].attributes['idref']}' not found for mechanical ventilation '#{whole_house_fan.elements["SystemIdentifier"].attributes["id"]}'."
      end

      cfis_hvac_dist_values = HPXML.get_hvac_distribution_values(hvac_distribution: cfis_hvac_dist)
      if cfis_hvac_dist_values[:distribution_system_type] == 'HydronicDistribution'
        fail "Attached HVAC distribution system '#{whole_house_fan.elements['AttachedToHVACDistributionSystem'].attributes['idref']}' cannot be hydronic for mechanical ventilation '#{whole_house_fan.elements["SystemIdentifier"].attributes["id"]}'."
      end

      # Get HVAC systems attached to this distribution system
      cfis_sys_ids = []
      hvac_plant = building.elements["BuildingDetails/Systems/HVAC/HVACPlant"]
      hvac_plant.elements.each("HeatingSystem | CoolingSystem | HeatPump") do |hvac|
        next unless XMLHelper.has_element(hvac, "DistributionSystem")
        next unless cfis_hvac_dist.elements["SystemIdentifier"].attributes["id"] == hvac.elements["DistributionSystem"].attributes["idref"]

        cfis_sys_ids << hvac.elements["SystemIdentifier"].attributes["id"]
      end

      # Get AirLoopHVACs associated with these HVAC systems
      @hvac_map.each do |sys_id, hvacs|
        next unless cfis_sys_ids.include? sys_id

        hvacs.each do |loop|
          next unless loop.is_a? OpenStudio::Model::AirLoopHVAC
          next if cfis_airloop == loop # already assigned

          fail "Two airloops found for CFIS. Aborting..." unless cfis_airloop.nil?

          cfis_airloop = loop
        end
      end
    end

    mech_vent = MechanicalVentilation.new(mech_vent_type, mech_vent_total_efficiency, mech_vent_cfm,
                                          mech_vent_fan_w, mech_vent_sensible_efficiency,
                                          clothes_dryer_exhaust, range_exhaust,
                                          range_exhaust_hour, bathroom_exhaust, bathroom_exhaust_hour,
                                          cfis_open_time, cfis_airflow_frac, cfis_airloop)

    # Natural Ventilation
    site_values = HPXML.get_site_values(site: building.elements["BuildingDetails/BuildingSummary/Site"])
    disable_nat_vent = site_values[:disable_natural_ventilation]
    if not disable_nat_vent.nil? and disable_nat_vent
      nat_vent_htg_offset = 0
      nat_vent_clg_offset = 0
      nat_vent_ovlp_offset = 0
      nat_vent_htg_season = false
      nat_vent_clg_season = false
      nat_vent_ovlp_season = false
      nat_vent_num_weekdays = 0
      nat_vent_num_weekends = 0
      nat_vent_frac_windows_open = 0
      nat_vent_frac_window_area_openable = 0
      nat_vent_max_oa_hr = 0.0115
      nat_vent_max_oa_rh = 0.7
    else
      nat_vent_htg_offset = 1.0
      nat_vent_clg_offset = 1.0
      nat_vent_ovlp_offset = 1.0
      nat_vent_htg_season = true
      nat_vent_clg_season = true
      nat_vent_ovlp_season = true
      nat_vent_num_weekdays = 5
      nat_vent_num_weekends = 2
      nat_vent_frac_windows_open = 0.33
      nat_vent_frac_window_area_openable = 0.2
      nat_vent_max_oa_hr = 0.0115
      nat_vent_max_oa_rh = 0.7
    end
    nat_vent = NaturalVentilation.new(nat_vent_htg_offset, nat_vent_clg_offset, nat_vent_ovlp_offset, nat_vent_htg_season,
                                      nat_vent_clg_season, nat_vent_ovlp_season, nat_vent_num_weekdays,
                                      nat_vent_num_weekends, nat_vent_frac_windows_open, nat_vent_frac_window_area_openable,
                                      nat_vent_max_oa_hr, nat_vent_max_oa_rh)

    # Ducts
    duct_systems = {}
    side_map = { 'supply' => Constants.DuctSideSupply,
                 'return' => Constants.DuctSideReturn }
    building.elements.each("BuildingDetails/Systems/HVAC/HVACDistribution") do |hvac_distribution|
      hvac_distribution_values = HPXML.get_hvac_distribution_values(hvac_distribution: hvac_distribution)
      air_distribution = hvac_distribution.elements["DistributionSystemType/AirDistribution"]
      next if air_distribution.nil?

      air_ducts = []

      # Duct leakage
      leakage_to_outside_cfm25 = { Constants.DuctSideSupply => 0.0,
                                   Constants.DuctSideReturn => 0.0 }
      air_distribution.elements.each("DuctLeakageMeasurement") do |duct_leakage_measurement|
        duct_leakage_values = HPXML.get_duct_leakage_measurement_values(duct_leakage_measurement: duct_leakage_measurement)
        next unless duct_leakage_values[:duct_leakage_units] == "CFM25" and duct_leakage_values[:duct_leakage_total_or_to_outside] == "to outside"

        duct_side = side_map[duct_leakage_values[:duct_type]]
        leakage_to_outside_cfm25[duct_side] = duct_leakage_values[:duct_leakage_value]
      end

      # Duct location, Rvalue, Area
      total_duct_area = { Constants.DuctSideSupply => 0.0,
                          Constants.DuctSideReturn => 0.0 }
      air_distribution.elements.each("Ducts") do |ducts|
        ducts_values = HPXML.get_ducts_values(ducts: ducts)
        next if ['living space', 'basement - conditioned'].include? ducts_values[:duct_location]

        # Calculate total duct area in unconditioned spaces
        duct_side = side_map[ducts_values[:duct_type]]
        total_duct_area[duct_side] += ducts_values[:duct_surface_area]
      end

      air_distribution.elements.each("Ducts") do |ducts|
        ducts_values = HPXML.get_ducts_values(ducts: ducts)
        next if ['living space', 'basement - conditioned'].include? ducts_values[:duct_location]

        duct_side = side_map[ducts_values[:duct_type]]
        duct_area = ducts_values[:duct_surface_area]
        duct_space = get_space_from_location(ducts_values[:duct_location], "Duct", model, spaces)
        # Apportion leakage to individual ducts by surface area
        duct_leakage_cfm = (leakage_to_outside_cfm25[duct_side] *
                            duct_area / total_duct_area[duct_side])

        air_ducts << Duct.new(duct_side, duct_space, nil, duct_leakage_cfm, duct_area, ducts_values[:duct_insulation_r_value])
      end

      # Connect AirLoopHVACs to ducts
      dist_id = hvac_distribution_values[:id]
      heating_systems_attached = []
      cooling_systems_attached = []
      ['HeatingSystem', 'CoolingSystem', 'HeatPump'].each do |hpxml_sys|
        building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/#{hpxml_sys}") do |sys|
          next if sys.elements["DistributionSystem"].nil? or dist_id != sys.elements["DistributionSystem"].attributes["idref"]

          sys_id = sys.elements["SystemIdentifier"].attributes["id"]
          heating_systems_attached << sys_id if ['HeatingSystem', 'HeatPump'].include? hpxml_sys and Float(XMLHelper.get_value(sys, "FractionHeatLoadServed")) > 0
          cooling_systems_attached << sys_id if ['CoolingSystem', 'HeatPump'].include? hpxml_sys and Float(XMLHelper.get_value(sys, "FractionCoolLoadServed")) > 0

          @hvac_map[sys_id].each do |loop|
            next unless loop.is_a? OpenStudio::Model::AirLoopHVAC
            next if duct_systems[air_ducts] == loop # already assigned

            duct_systems[air_ducts] = loop
          end
        end
      end

      fail "Multiple cooling systems found attached to distribution system '#{dist_id}'." if cooling_systems_attached.size > 1
      fail "Multiple heating systems found attached to distribution system '#{dist_id}'." if heating_systems_attached.size > 1
    end

    window_area = 0.0
    building.elements.each("BuildingDetails/Enclosure/Windows/Window") do |window|
      window_values = HPXML.get_window_values(window: window)
      window_area += window_values[:area]
    end

    success = Airflow.apply(model, runner, infil, mech_vent, nat_vent, duct_systems,
                            @cfa, infilvolume, @nbeds, @nbaths, @ncfl, @ncfl_ag, window_area,
                            @min_neighbor_distance)
    return false if not success

    return true
  end

  def self.add_hvac_sizing(runner, model, weather)
    success = HVACSizing.apply(model, runner, weather, @cfa, @nbeds, @min_neighbor_distance, false)
    return false if not success

    return true
  end

  def self.add_fuel_heating_eae(runner, model, building)
    # Needs to come after HVAC sizing (needs heating capacity and airflow rate)
    # FUTURE: Could remove this method and simplify everything if we could autosize via the HPXML file

    building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[FractionHeatLoadServed > 0]") do |htgsys|
      heating_system_values = HPXML.get_heating_system_values(heating_system: htgsys)
      htg_type = heating_system_values[:heating_system_type]
      next unless ["Furnace", "WallFurnace", "Stove", "Boiler"].include? htg_type

      fuel = to_beopt_fuel(heating_system_values[:heating_system_fuel])
      next if fuel == Constants.FuelTypeElectric

      fuel_eae = heating_system_values[:electric_auxiliary_energy]
      load_frac = heating_system_values[:fraction_heat_load_served]
      dse_heat, dse_cool, has_dse = get_dse(building, heating_system_values)
      sys_id = heating_system_values[:id]

      success = HVAC.apply_eae_to_heating_fan(runner, @hvac_map[sys_id], fuel_eae, fuel, dse_heat, load_frac, htg_type)
      return false if not success
    end

    return true
  end

  def self.add_photovoltaics(runner, model, building)
    pv_system_values = HPXML.get_pv_system_values(pv_system: building.elements["BuildingDetails/Systems/Photovoltaics/PVSystem"])
    return true if pv_system_values.nil?

    modules_map = { "standard" => Constants.PVModuleTypeStandard,
                    "premium" => Constants.PVModuleTypePremium,
                    "thin film" => Constants.PVModuleTypeThinFilm }

    building.elements.each("BuildingDetails/Systems/Photovoltaics/PVSystem") do |pvsys|
      pv_system_values = HPXML.get_pv_system_values(pv_system: pvsys)
      pv_id = pv_system_values[:id]
      module_type = modules_map[pv_system_values[:module_type]]
      if pv_system_values[:tracking] == 'fixed' and pv_system_values[:location] == 'roof'
        array_type = Constants.PVArrayTypeFixedRoofMount
      elsif pv_system_values[:tracking] == 'fixed' and pv_system_values[:location] == 'ground'
        array_type = Constants.PVArrayTypeFixedOpenRack
      elsif pv_system_values[:tracking] == '1-axis'
        array_type = Constants.PVArrayTypeFixed1Axis
      elsif pv_system_values[:tracking] == '1-axis backtracked'
        array_type = Constants.PVArrayTypeFixed1AxisBacktracked
      elsif pv_system_values[:tracking] == '2-axis'
        array_type = Constants.PVArrayTypeFixed2Axis
      end
      az = pv_system_values[:array_azimuth]
      tilt = pv_system_values[:array_tilt]
      power_w = pv_system_values[:max_power_output]
      inv_eff = pv_system_values[:inverter_efficiency]
      system_losses = pv_system_values[:system_losses_fraction]

      success = PV.apply(model, runner, pv_id, power_w, module_type,
                         system_losses, inv_eff, tilt, az, array_type)
      return false if not success
    end

    return true
  end

  def self.add_building_output_variables(runner, model, map_tsv_dir)
    hvac_output_vars = [OutputVars.SpaceHeatingElectricity,
                        OutputVars.SpaceHeatingFuel,
                        OutputVars.SpaceHeatingLoad,
                        OutputVars.SpaceCoolingElectricity,
                        OutputVars.SpaceCoolingLoad]

    dhw_output_vars = [OutputVars.WaterHeatingElectricity,
                       OutputVars.WaterHeatingElectricityRecircPump,
                       OutputVars.WaterHeatingElectricitySolarThermalPump,
                       OutputVars.WaterHeatingFuel,
                       OutputVars.WaterHeatingLoad]

    # Remove objects that are not referenced by output vars and are not
    # EMS output vars.
    { @hvac_map => hvac_output_vars,
      @dhw_map => dhw_output_vars }.each do |map, vars|
      all_vars = vars.reduce({}, :merge)
      map.each do |sys_id, objects|
        objects_to_delete = []
        objects.each do |object|
          next if object.is_a? OpenStudio::Model::EnergyManagementSystemOutputVariable
          next unless all_vars[object.class.to_s].nil? # Referenced?

          objects_to_delete << object
        end
        objects_to_delete.uniq.each do |object|
          map[sys_id].delete object
        end
      end
    end

    # Add output variables to model
    @hvac_map.each do |sys_id, hvac_objects|
      hvac_output_vars.each do |hvac_output_var|
        add_output_variables(model, hvac_output_var, hvac_objects)
      end
    end
    @dhw_map.each do |sys_id, dhw_objects|
      dhw_output_vars.each do |dhw_output_var|
        add_output_variables(model, dhw_output_var, dhw_objects)
      end
    end

    if map_tsv_dir.is_initialized
      # Write maps to file
      map_tsv_dir = map_tsv_dir.get
      write_mapping(@hvac_map, File.join(map_tsv_dir, "map_hvac.tsv"))
      write_mapping(@dhw_map, File.join(map_tsv_dir, "map_water_heating.tsv"))
    end

    return true
  end

  def self.add_output_variables(model, vars, objects)
    objects.each do |object|
      if object.is_a? OpenStudio::Model::EnergyManagementSystemOutputVariable
        outputVariable = OpenStudio::Model::OutputVariable.new(object.name.to_s, model)
        outputVariable.setReportingFrequency('runperiod')
        outputVariable.setKeyValue('*')
      else
        next if vars[object.class.to_s].nil?

        vars[object.class.to_s].each do |object_var|
          outputVariable = OpenStudio::Model::OutputVariable.new(object_var, model)
          outputVariable.setReportingFrequency('runperiod')
          outputVariable.setKeyValue(object.name.to_s)
        end
      end
    end
  end

  def self.write_mapping(map, map_tsv_path)
    # Write simple mapping TSV file for use by ERI calculation. Mapping file correlates
    # EnergyPlus object name to a HPXML object name.

    CSV.open(map_tsv_path, 'w', col_sep: "\t") do |tsv|
      # Header
      tsv << ["HPXML Name", "E+ Name(s)"]

      map.each do |sys_id, objects|
        out_data = [sys_id]
        objects.uniq.each do |object|
          out_data << object.name.to_s
        end
        tsv << out_data if out_data.size > 1
      end
    end
  end

  def self.calc_non_cavity_r(film_r, constr_set)
    # Calculate R-value for all non-cavity layers
    non_cavity_r = film_r
    if not constr_set.exterior_material.nil?
      non_cavity_r += constr_set.exterior_material.rvalue
    end
    if not constr_set.rigid_r.nil?
      non_cavity_r += constr_set.rigid_r
    end
    if not constr_set.osb_thick_in.nil?
      non_cavity_r += Material.Plywood(constr_set.osb_thick_in).rvalue
    end
    if not constr_set.drywall_thick_in.nil?
      non_cavity_r += Material.GypsumWall(constr_set.drywall_thick_in).rvalue
    end
    return non_cavity_r
  end

  def self.apply_wall_construction(runner, model, surface, wall_id, wall_type, assembly_r,
                                   drywall_thick_in, film_r, mat_ext_finish, solar_abs, emitt)
    if wall_type == "WoodStud"
      install_grade = 1
      cavity_filled = true

      constr_sets = [
        WoodStudConstructionSet.new(Material.Stud2x6, 0.20, 10.0, 0.5, drywall_thick_in, mat_ext_finish), # 2x6, 24" o.c. + R10
        WoodStudConstructionSet.new(Material.Stud2x6, 0.20, 5.0, 0.5, drywall_thick_in, mat_ext_finish),  # 2x6, 24" o.c. + R5
        WoodStudConstructionSet.new(Material.Stud2x6, 0.20, 0.0, 0.5, drywall_thick_in, mat_ext_finish),  # 2x6, 24" o.c.
        WoodStudConstructionSet.new(Material.Stud2x4, 0.23, 0.0, 0.5, drywall_thick_in, mat_ext_finish),  # 2x4, 16" o.c.
        WoodStudConstructionSet.new(Material.Stud2x4, 0.01, 0.0, 0.0, 0.0, nil),                          # Fallback
      ]
      constr_set, cavity_r = pick_wood_stud_construction_set(assembly_r, constr_sets, film_r, wall_id)

      success = Constructions.apply_wood_stud_wall(runner, model, [surface], "#{wall_id} construction",
                                                   cavity_r, install_grade, constr_set.stud.thick_in,
                                                   cavity_filled, constr_set.framing_factor,
                                                   constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                                   constr_set.rigid_r, constr_set.exterior_material)
      return false if not success

    elsif wall_type == "SteelFrame"
      install_grade = 1
      cavity_filled = true
      corr_factor = 0.45

      constr_sets = [
        SteelStudConstructionSet.new(5.5, corr_factor, 0.20, 10.0, 0.5, drywall_thick_in, mat_ext_finish), # 2x6, 24" o.c. + R10
        SteelStudConstructionSet.new(5.5, corr_factor, 0.20, 5.0, 0.5, drywall_thick_in, mat_ext_finish),  # 2x6, 24" o.c. + R5
        SteelStudConstructionSet.new(5.5, corr_factor, 0.20, 0.0, 0.5, drywall_thick_in, mat_ext_finish),  # 2x6, 24" o.c.
        SteelStudConstructionSet.new(3.5, corr_factor, 0.23, 0.0, 0.5, drywall_thick_in, mat_ext_finish),  # 2x4, 16" o.c.
        SteelStudConstructionSet.new(3.5, 1.0, 0.01, 0.0, 0.0, 0.0, nil),                                  # Fallback
      ]
      constr_set, cavity_r = pick_steel_stud_construction_set(assembly_r, constr_sets, film_r, "wall #{wall_id}")

      success = Constructions.apply_steel_stud_wall(runner, model, [surface], "WallConstruction",
                                                    cavity_r, install_grade, constr_set.cavity_thick_in,
                                                    cavity_filled, constr_set.framing_factor,
                                                    constr_set.corr_factor, constr_set.drywall_thick_in,
                                                    constr_set.osb_thick_in, constr_set.rigid_r,
                                                    constr_set.exterior_material)
      return false if not success

    elsif wall_type == "DoubleWoodStud"
      install_grade = 1
      is_staggered = false

      constr_sets = [
        DoubleStudConstructionSet.new(Material.Stud2x4, 0.23, 24.0, 0.0, 0.5, drywall_thick_in, mat_ext_finish),  # 2x4, 24" o.c.
        DoubleStudConstructionSet.new(Material.Stud2x4, 0.01, 16.0, 0.0, 0.0, 0.0, nil),                          # Fallback
      ]
      constr_set, cavity_r = pick_double_stud_construction_set(assembly_r, constr_sets, film_r, "wall #{wall_id}")

      success = Constructions.apply_double_stud_wall(runner, model, [surface], "WallConstruction",
                                                     cavity_r, install_grade, constr_set.stud.thick_in,
                                                     constr_set.stud.thick_in, constr_set.framing_factor,
                                                     constr_set.framing_spacing, is_staggered,
                                                     constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                                     constr_set.rigid_r, constr_set.exterior_material)
      return false if not success

    elsif wall_type == "ConcreteMasonryUnit"
      density = 119.0 # lb/ft^3
      furring_r = 0
      furring_cavity_depth_in = 0 # in
      furring_spacing = 0

      constr_sets = [
        CMUConstructionSet.new(8.0, 1.4, 0.08, 0.5, drywall_thick_in, mat_ext_finish),  # 8" perlite-filled CMU
        CMUConstructionSet.new(6.0, 5.29, 0.01, 0.0, 0.0, nil),                         # Fallback (6" hollow CMU)
      ]
      constr_set, rigid_r = pick_cmu_construction_set(assembly_r, constr_sets, film_r, "wall #{wall_id}")

      success = Constructions.apply_cmu_wall(runner, model, [surface], "WallConstruction",
                                             constr_set.thick_in, constr_set.cond_in, density,
                                             constr_set.framing_factor, furring_r,
                                             furring_cavity_depth_in, furring_spacing,
                                             constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                             rigid_r, constr_set.exterior_material)
      return false if not success

    elsif wall_type == "StructurallyInsulatedPanel"
      sheathing_thick_in = 0.44
      sheathing_type = Constants.MaterialOSB

      constr_sets = [
        SIPConstructionSet.new(10.0, 0.16, 0.0, sheathing_thick_in, 0.5, drywall_thick_in, mat_ext_finish), # 10" SIP core
        SIPConstructionSet.new(5.0, 0.16, 0.0, sheathing_thick_in, 0.5, drywall_thick_in, mat_ext_finish),  # 5" SIP core
        SIPConstructionSet.new(1.0, 0.01, 0.0, sheathing_thick_in, 0.0, 0.0, nil),                          # Fallback
      ]
      constr_set, cavity_r = pick_sip_construction_set(assembly_r, constr_sets, film_r, "wall #{wall_id}")

      success = Constructions.apply_sip_wall(runner, model, [surface], "WallConstruction",
                                             cavity_r, constr_set.thick_in, constr_set.framing_factor,
                                             sheathing_type, constr_set.sheath_thick_in,
                                             constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                             constr_set.rigid_r, constr_set.exterior_material)
      return false if not success

    elsif wall_type == "InsulatedConcreteForms"
      constr_sets = [
        ICFConstructionSet.new(2.0, 4.0, 0.08, 0.0, 0.5, drywall_thick_in, mat_ext_finish), # ICF w/4" concrete and 2" rigid ins layers
        ICFConstructionSet.new(1.0, 1.0, 0.01, 0.0, 0.0, 0.0, nil),                         # Fallback
      ]
      constr_set, icf_r = pick_icf_construction_set(assembly_r, constr_sets, film_r, "wall #{wall_id}")

      success = Constructions.apply_icf_wall(runner, model, [surface], "WallConstruction",
                                             icf_r, constr_set.ins_thick_in,
                                             constr_set.concrete_thick_in, constr_set.framing_factor,
                                             constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                             constr_set.rigid_r, constr_set.exterior_material)
      return false if not success

    elsif ["SolidConcrete", "StructuralBrick", "StrawBale", "Stone", "LogWall"].include? wall_type
      constr_sets = [
        GenericConstructionSet.new(10.0, 0.5, drywall_thick_in, mat_ext_finish), # w/R-10 rigid
        GenericConstructionSet.new(0.0, 0.5, drywall_thick_in, mat_ext_finish),  # Standard
        GenericConstructionSet.new(0.0, 0.0, 0.0, nil),                          # Fallback
      ]
      constr_set, layer_r = pick_generic_construction_set(assembly_r, constr_sets, film_r, "wall #{wall_id}")

      if wall_type == "SolidConcrete"
        thick_in = 6.0
        base_mat = BaseMaterial.Concrete
      elsif wall_type == "StructuralBrick"
        thick_in = 8.0
        base_mat = BaseMaterial.Brick
      elsif wall_type == "StrawBale"
        thick_in = 23.0
        base_mat = BaseMaterial.StrawBale
      elsif wall_type == "Stone"
        thick_in = 6.0
        base_mat = BaseMaterial.Stone
      elsif wall_type == "LogWall"
        thick_in = 6.0
        base_mat = BaseMaterial.Wood
      end
      thick_ins = [thick_in]
      conds = [thick_in / layer_r]
      denss = [base_mat.rho]
      specheats = [base_mat.cp]

      success = Constructions.apply_generic_layered_wall(runner, model, [surface], "WallConstruction",
                                                         thick_ins, conds, denss, specheats,
                                                         constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                                         constr_set.rigid_r, constr_set.exterior_material)
      return false if not success

    else

      fail "Unexpected wall type '#{wall_type}'."

    end

    check_surface_assembly_rvalue(surface, film_r, assembly_r)

    apply_solar_abs_emittance_to_construction(surface, solar_abs, emitt)
  end

  def self.pick_wood_stud_construction_set(assembly_r, constr_sets, film_r, surface_name)
    # Picks a construction set from supplied constr_sets for which a positive R-value
    # can be calculated for the unknown insulation to achieve the assembly R-value.

    constr_sets.each do |constr_set|
      fail "Unexpected object." unless constr_set.is_a? WoodStudConstructionSet

      non_cavity_r = calc_non_cavity_r(film_r, constr_set)

      # Calculate effective cavity R-value
      # Assumes installation quality 1
      cavity_frac = 1.0 - constr_set.framing_factor
      cavity_r = cavity_frac / (1.0 / assembly_r - constr_set.framing_factor / (constr_set.stud.rvalue + non_cavity_r)) - non_cavity_r
      if cavity_r > 0 # Choose this construction set
        return constr_set, cavity_r
      end
    end

    fail "Unable to calculate a construction for '#{surface_name}' using the provided assembly R-value (#{assembly_r})."
  end

  def self.pick_steel_stud_construction_set(assembly_r, constr_sets, film_r, surface_name)
    # Picks a construction set from supplied constr_sets for which a positive R-value
    # can be calculated for the unknown insulation to achieve the assembly R-value.

    constr_sets.each do |constr_set|
      fail "Unexpected object." unless constr_set.is_a? SteelStudConstructionSet

      non_cavity_r = calc_non_cavity_r(film_r, constr_set)

      # Calculate effective cavity R-value
      # Assumes installation quality 1
      cavity_r = (assembly_r - non_cavity_r) / constr_set.corr_factor
      if cavity_r > 0 # Choose this construction set
        return constr_set, cavity_r
      end
    end

    fail "Unable to calculate a construction for '#{surface_name}' using the provided assembly R-value (#{assembly_r})."
  end

  def self.pick_double_stud_construction_set(assembly_r, constr_sets, film_r, surface_name)
    # Picks a construction set from supplied constr_sets for which a positive R-value
    # can be calculated for the unknown insulation to achieve the assembly R-value.

    constr_sets.each do |constr_set|
      fail "Unexpected object." unless constr_set.is_a? DoubleStudConstructionSet

      non_cavity_r = calc_non_cavity_r(film_r, constr_set)

      # Calculate effective cavity R-value
      # Assumes installation quality 1, not staggered, gap depth == stud depth
      # Solved in Wolfram Alpha: https://www.wolframalpha.com/input/?i=1%2FA+%3D+B%2F(2*C%2Bx%2BD)+%2B+E%2F(3*C%2BD)+%2B+(1-B-E)%2F(3*x%2BD)
      stud_frac = 1.5 / constr_set.framing_spacing
      misc_framing_factor = constr_set.framing_factor - stud_frac
      cavity_frac = 1.0 - (2 * stud_frac + misc_framing_factor)
      a = assembly_r
      b = stud_frac
      c = constr_set.stud.rvalue
      d = non_cavity_r
      e = misc_framing_factor
      cavity_r = ((3 * c + d) * Math.sqrt(4 * a**2 * b**2 + 12 * a**2 * b * e + 4 * a**2 * b + 9 * a**2 * e**2 - 6 * a**2 * e + a**2 - 48 * a * b * c - 16 * a * b * d - 36 * a * c * e + 12 * a * c - 12 * a * d * e + 4 * a * d + 36 * c**2 + 24 * c * d + 4 * d**2) + 6 * a * b * c + 2 * a * b * d + 3 * a * c * e + 3 * a * c + 3 * a * d * e + a * d - 18 * c**2 - 18 * c * d - 4 * d**2) / (2 * (-3 * a * e + 9 * c + 3 * d))
      cavity_r = 3 * cavity_r
      if cavity_r > 0 # Choose this construction set
        return constr_set, cavity_r
      end
    end

    fail "Unable to calculate a construction for '#{surface_name}' using the provided assembly R-value (#{assembly_r})."
  end

  def self.pick_sip_construction_set(assembly_r, constr_sets, film_r, surface_name)
    # Picks a construction set from supplied constr_sets for which a positive R-value
    # can be calculated for the unknown insulation to achieve the assembly R-value.

    constr_sets.each do |constr_set|
      fail "Unexpected object." unless constr_set.is_a? SIPConstructionSet

      non_cavity_r = calc_non_cavity_r(film_r, constr_set)
      non_cavity_r += Material.new(nil, constr_set.sheath_thick_in, BaseMaterial.Wood).rvalue

      # Calculate effective SIP core R-value
      # Solved in Wolfram Alpha: https://www.wolframalpha.com/input/?i=1%2FA+%3D+B%2F(C%2BD)+%2B+E%2F(2*F%2BG%2FH*x%2BD)+%2B+(1-B-E)%2F(x%2BD)
      spline_thick_in = 0.5 # in
      ins_thick_in = constr_set.thick_in - (2.0 * spline_thick_in) # in
      framing_r = Material.new(nil, constr_set.thick_in, BaseMaterial.Wood).rvalue
      spline_r = Material.new(nil, spline_thick_in, BaseMaterial.Wood).rvalue
      spline_frac = 4.0 / 48.0 # One 4" spline for every 48" wide panel
      cavity_frac = 1.0 - (spline_frac + constr_set.framing_factor)
      a = assembly_r
      b = constr_set.framing_factor
      c = framing_r
      d = non_cavity_r
      e = spline_frac
      f = spline_r
      g = ins_thick_in
      h = constr_set.thick_in
      cavity_r = (Math.sqrt((a * b * c * g - a * b * d * h - 2 * a * b * f * h + a * c * e * g - a * c * e * h - a * c * g + a * d * e * g - a * d * e * h - a * d * g + c * d * g + c * d * h + 2 * c * f * h + d**2 * g + d**2 * h + 2 * d * f * h)**2 - 4 * (-a * b * g + c * g + d * g) * (a * b * c * d * h + 2 * a * b * c * f * h - a * c * d * h + 2 * a * c * e * f * h - 2 * a * c * f * h - a * d**2 * h + 2 * a * d * e * f * h - 2 * a * d * f * h + c * d**2 * h + 2 * c * d * f * h + d**3 * h + 2 * d**2 * f * h)) - a * b * c * g + a * b * d * h + 2 * a * b * f * h - a * c * e * g + a * c * e * h + a * c * g - a * d * e * g + a * d * e * h + a * d * g - c * d * g - c * d * h - 2 * c * f * h - g * d**2 - d**2 * h - 2 * d * f * h) / (2 * (-a * b * g + c * g + d * g))
      if cavity_r > 0 # Choose this construction set
        return constr_set, cavity_r
      end
    end

    fail "Unable to calculate a construction for '#{surface_name}' using the provided assembly R-value (#{assembly_r})."
  end

  def self.pick_cmu_construction_set(assembly_r, constr_sets, film_r, surface_name)
    # Picks a construction set from supplied constr_sets for which a positive R-value
    # can be calculated for the unknown insulation to achieve the assembly R-value.

    constr_sets.each do |constr_set|
      fail "Unexpected object." unless constr_set.is_a? CMUConstructionSet

      non_cavity_r = calc_non_cavity_r(film_r, constr_set)

      # Calculate effective other CMU R-value
      # Assumes no furring strips
      # Solved in Wolfram Alpha: https://www.wolframalpha.com/input/?i=1%2FA+%3D+B%2F(C%2BE%2Bx)+%2B+(1-B)%2F(D%2BE%2Bx)
      a = assembly_r
      b = constr_set.framing_factor
      c = Material.new(nil, constr_set.thick_in, BaseMaterial.Wood).rvalue # Framing
      d = Material.new(nil, constr_set.thick_in, BaseMaterial.Concrete, constr_set.cond_in).rvalue # Concrete
      e = non_cavity_r
      rigid_r = 0.5 * (Math.sqrt(a**2 - 4 * a * b * c + 4 * a * b * d + 2 * a * c - 2 * a * d + c**2 - 2 * c * d + d**2) + a - c - d - 2 * e)
      if rigid_r > 0 # Choose this construction set
        return constr_set, rigid_r
      end
    end

    fail "Unable to calculate a construction for '#{surface_name}' using the provided assembly R-value (#{assembly_r})."
  end

  def self.pick_icf_construction_set(assembly_r, constr_sets, film_r, surface_name)
    # Picks a construction set from supplied constr_sets for which a positive R-value
    # can be calculated for the unknown insulation to achieve the assembly R-value.

    constr_sets.each do |constr_set|
      fail "Unexpected object." unless constr_set.is_a? ICFConstructionSet

      non_cavity_r = calc_non_cavity_r(film_r, constr_set)

      # Calculate effective ICF rigid ins R-value
      # Solved in Wolfram Alpha: https://www.wolframalpha.com/input/?i=1%2FA+%3D+B%2F(C%2BE)+%2B+(1-B)%2F(D%2BE%2B2*x)
      a = assembly_r
      b = constr_set.framing_factor
      c = Material.new(nil, 2 * constr_set.ins_thick_in + constr_set.concrete_thick_in, BaseMaterial.Wood).rvalue # Framing
      d = Material.new(nil, constr_set.concrete_thick_in, BaseMaterial.Concrete).rvalue # Concrete
      e = non_cavity_r
      icf_r = (a * b * c - a * b * d - a * c - a * e + c * d + c * e + d * e + e**2) / (2 * (a * b - c - e))
      if icf_r > 0 # Choose this construction set
        return constr_set, icf_r
      end
    end

    fail "Unable to calculate a construction for '#{surface_name}' using the provided assembly R-value (#{assembly_r})."
  end

  def self.pick_generic_construction_set(assembly_r, constr_sets, film_r, surface_name)
    # Picks a construction set from supplied constr_sets for which a positive R-value
    # can be calculated for the unknown insulation to achieve the assembly R-value.

    constr_sets.each do |constr_set|
      fail "Unexpected object." unless constr_set.is_a? GenericConstructionSet

      non_cavity_r = calc_non_cavity_r(film_r, constr_set)

      # Calculate effective ins layer R-value
      layer_r = assembly_r - non_cavity_r
      if layer_r > 0 # Choose this construction set
        return constr_set, layer_r
      end
    end

    fail "Unable to calculate a construction for '#{surface_name}' using the provided assembly R-value (#{assembly_r})."
  end

  def self.apply_solar_abs_emittance_to_construction(surface, solar_abs, emitt)
    # Applies the solar absorptance and emittance to the construction's exterior layer
    exterior_material = surface.construction.get.to_LayeredConstruction.get.layers[0].to_StandardOpaqueMaterial.get
    exterior_material.setThermalAbsorptance(emitt)
    exterior_material.setSolarAbsorptance(solar_abs)
    exterior_material.setVisibleAbsorptance(solar_abs)
  end

  def self.check_surface_assembly_rvalue(surface, film_r, assembly_r)
    # Verify that the actual OpenStudio construction R-value matches our target assembly R-value

    constr_r = UnitConversions.convert(1.0 / surface.construction.get.uFactor(0.0).get, 'm^2*k/w', 'hr*ft^2*f/btu') + film_r

    if surface.adjacentFoundation.is_initialized
      foundation = surface.adjacentFoundation.get
      if foundation.interiorVerticalInsulationMaterial.is_initialized
        int_mat = foundation.interiorVerticalInsulationMaterial.get.to_StandardOpaqueMaterial.get
        constr_r += UnitConversions.convert(int_mat.thickness, "m", "ft") / UnitConversions.convert(int_mat.thermalConductivity, "W/(m*K)", "Btu/(hr*ft*R)")
      end
      if foundation.exteriorVerticalInsulationMaterial.is_initialized
        ext_mat = foundation.exteriorVerticalInsulationMaterial.get.to_StandardOpaqueMaterial.get
        constr_r += UnitConversions.convert(ext_mat.thickness, "m", "ft") / UnitConversions.convert(ext_mat.thermalConductivity, "W/(m*K)", "Btu/(hr*ft*R)")
      end
    end

    if (assembly_r - constr_r).abs > 0.01
      fail "Construction R-value (#{constr_r}) does not match Assembly R-value (#{assembly_r}) for '#{surface.name.to_s}'."
    end
  end

  def self.get_attached_system(system_values, building, system_to_search, has_dse)
    return nil if system_values[:distribution_system_idref].nil?
    return nil if has_dse

    # Finds the OpenStudio object of the heating (or cooling) system attached (i.e., on the same
    # distribution system) to the current cooling (or heating) system.
    building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/#{system_to_search}") do |other_sys|
      if system_to_search == "CoolingSystem"
        attached_system_values = HPXML.get_cooling_system_values(cooling_system: other_sys)
      elsif system_to_search == "HeatingSystem"
        attached_system_values = HPXML.get_heating_system_values(heating_system: other_sys)
      end
      next unless system_values[:distribution_system_idref] == attached_system_values[:distribution_system_idref]

      @hvac_map[attached_system_values[:id]].each do |hvac_object|
        next unless hvac_object.is_a? OpenStudio::Model::AirLoopHVACUnitarySystem

        return hvac_object
      end
    end

    return nil
  end

  def self.set_surface_interior(model, spaces, surface, surface_id, interior_adjacent_to)
    if ["living space"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeLiving))
    elsif ["garage"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeGarage))
    elsif ["basement - unconditioned"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeUnconditionedBasement))
    elsif ["basement - conditioned"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeConditionedBasement))
    elsif ["crawlspace - vented"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeVentedCrawl))
    elsif ["crawlspace - unvented"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeUnventedCrawl))
    elsif ["attic - vented"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeVentedAttic))
    elsif ["attic - unvented"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeUnventedAttic))
    else
      fail "Unhandled AdjacentTo value (#{interior_adjacent_to}) for surface '#{surface_id}'."
    end
  end

  def self.set_surface_exterior(model, spaces, surface, surface_id, exterior_adjacent_to)
    if ["outside"].include? exterior_adjacent_to
      surface.setOutsideBoundaryCondition("Outdoors")
    elsif ["ground"].include? exterior_adjacent_to
      surface.setOutsideBoundaryCondition("Foundation")
    elsif ["other housing unit"].include? exterior_adjacent_to
      surface.setOutsideBoundaryCondition("Adiabatic")
    elsif ["living space"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeLiving))
    elsif ["garage"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeGarage))
    elsif ["basement - unconditioned"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeUnconditionedBasement))
    elsif ["basement - conditioned"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeConditionedBasement))
    elsif ["crawlspace - vented"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeVentedCrawl))
    elsif ["crawlspace - unvented"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeUnventedCrawl))
    elsif ["attic - vented"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeVentedAttic))
    elsif ["attic - unvented"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeUnventedAttic))
    else
      fail "Unhandled AdjacentTo value (#{exterior_adjacent_to}) for surface '#{surface_id}'."
    end
  end

  def self.get_space_from_location(location, object_name, model, spaces)
    num_orig_spaces = spaces.size

    space = nil
    if location == 'living space'
      space = create_or_get_space(model, spaces, Constants.SpaceTypeLiving)
    elsif location == 'basement - conditioned'
      space = create_or_get_space(model, spaces, Constants.SpaceTypeConditionedBasement)
    elsif location == 'basement - unconditioned'
      space = create_or_get_space(model, spaces, Constants.SpaceTypeUnconditionedBasement)
    elsif location == 'garage'
      space = create_or_get_space(model, spaces, Constants.SpaceTypeGarage)
    elsif location == 'attic - vented'
      space = create_or_get_space(model, spaces, Constants.SpaceTypeVentedAttic)
    elsif location == 'attic - unvented'
      space = create_or_get_space(model, spaces, Constants.SpaceTypeUnventedAttic)
    elsif location == 'crawlspace - vented'
      space = create_or_get_space(model, spaces, Constants.SpaceTypeVentedCrawl)
    elsif location == 'crawlspace - unvented'
      space = create_or_get_space(model, spaces, Constants.SpaceTypeUnventedCrawl)
    end

    if space.nil?
      fail "Unhandled #{object_name} location: #{location}."
    end

    if spaces.size != num_orig_spaces
      fail "#{object_name} location is '#{location}' but building does not have this location specified."
    end

    return space
  end

  def self.get_spaces_of_type(spaces, space_types_list)
    spaces_of_type = []
    space_types_list.each do |space_type|
      spaces_of_type << spaces[space_type] unless spaces[space_type].nil?
    end
    return spaces_of_type
  end

  def self.get_space_of_type(spaces, space_type)
    spaces_of_type = self.get_spaces_of_type(spaces, [space_type])
    if spaces_of_type.size > 1
      fail "Unexpected number of spaces."
    elsif spaces_of_type.size == 1
      return spaces_of_type[0]
    end

    return nil
  end

  def self.assign_space_to_subsurface(surface, subsurface_id, wall_idref, building, spaces, model, subsurface_type)
    # Check walls
    building.elements.each("BuildingDetails/Enclosure/Walls/Wall") do |wall|
      wall_values = HPXML.get_wall_values(wall: wall)
      next unless wall_values[:id] == wall_idref

      set_surface_interior(model, spaces, surface, subsurface_id, wall_values[:interior_adjacent_to])
      return
    end

    # Check foundation walls
    building.elements.each("BuildingDetails/Enclosure/FoundationWalls/FoundationWall") do |fnd_wall|
      fnd_wall_values = HPXML.get_foundation_wall_values(foundation_wall: fnd_wall)
      next unless fnd_wall_values[:id] == wall_idref

      set_surface_interior(model, spaces, surface, subsurface_id, fnd_wall_values[:interior_adjacent_to])
      return
    end

    if not surface.space.is_initialized
      fail "Attached wall '#{wall_idref}' not found for #{subsurface_type} '#{subsurface_id}'."
    end
  end

  def self.get_min_neighbor_distance(building)
    min_neighbor_distance = nil
    building.elements.each("BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding") do |neighbor_building|
      neighbor_building_values = HPXML.get_neighbor_building_values(neighbor_building: neighbor_building)
      if min_neighbor_distance.nil?
        min_neighbor_distance = 9e99
      end
      if neighbor_building_values[:distance] < min_neighbor_distance
        min_neighbor_distance = neighbor_building_values[:distance]
      end
    end
    return min_neighbor_distance
  end
end

class WoodStudConstructionSet
  def initialize(stud, framing_factor, rigid_r, osb_thick_in, drywall_thick_in, exterior_material)
    @stud = stud
    @framing_factor = framing_factor
    @rigid_r = rigid_r
    @osb_thick_in = osb_thick_in
    @drywall_thick_in = drywall_thick_in
    @exterior_material = exterior_material
  end
  attr_accessor(:stud, :framing_factor, :rigid_r, :osb_thick_in, :drywall_thick_in, :exterior_material)
end

class SteelStudConstructionSet
  def initialize(cavity_thick_in, corr_factor, framing_factor, rigid_r, osb_thick_in, drywall_thick_in, exterior_material)
    @cavity_thick_in = cavity_thick_in
    @corr_factor = corr_factor
    @framing_factor = framing_factor
    @rigid_r = rigid_r
    @osb_thick_in = osb_thick_in
    @drywall_thick_in = drywall_thick_in
    @exterior_material = exterior_material
  end
  attr_accessor(:cavity_thick_in, :corr_factor, :framing_factor, :rigid_r, :osb_thick_in, :drywall_thick_in, :exterior_material)
end

class DoubleStudConstructionSet
  def initialize(stud, framing_factor, framing_spacing, rigid_r, osb_thick_in, drywall_thick_in, exterior_material)
    @stud = stud
    @framing_factor = framing_factor
    @framing_spacing = framing_spacing
    @rigid_r = rigid_r
    @osb_thick_in = osb_thick_in
    @drywall_thick_in = drywall_thick_in
    @exterior_material = exterior_material
  end
  attr_accessor(:stud, :framing_factor, :framing_spacing, :rigid_r, :osb_thick_in, :drywall_thick_in, :exterior_material)
end

class SIPConstructionSet
  def initialize(thick_in, framing_factor, rigid_r, sheath_thick_in, osb_thick_in, drywall_thick_in, exterior_material)
    @thick_in = thick_in
    @framing_factor = framing_factor
    @rigid_r = rigid_r
    @sheath_thick_in = sheath_thick_in
    @osb_thick_in = osb_thick_in
    @drywall_thick_in = drywall_thick_in
    @exterior_material = exterior_material
  end
  attr_accessor(:thick_in, :framing_factor, :rigid_r, :sheath_thick_in, :osb_thick_in, :drywall_thick_in, :exterior_material)
end

class CMUConstructionSet
  def initialize(thick_in, cond_in, framing_factor, osb_thick_in, drywall_thick_in, exterior_material)
    @thick_in = thick_in
    @cond_in = cond_in
    @framing_factor = framing_factor
    @osb_thick_in = osb_thick_in
    @drywall_thick_in = drywall_thick_in
    @exterior_material = exterior_material
    @rigid_r = nil # solved for
  end
  attr_accessor(:thick_in, :cond_in, :framing_factor, :rigid_r, :osb_thick_in, :drywall_thick_in, :exterior_material)
end

class ICFConstructionSet
  def initialize(ins_thick_in, concrete_thick_in, framing_factor, rigid_r, osb_thick_in, drywall_thick_in, exterior_material)
    @ins_thick_in = ins_thick_in
    @concrete_thick_in = concrete_thick_in
    @framing_factor = framing_factor
    @rigid_r = rigid_r
    @osb_thick_in = osb_thick_in
    @drywall_thick_in = drywall_thick_in
    @exterior_material = exterior_material
  end
  attr_accessor(:ins_thick_in, :concrete_thick_in, :framing_factor, :rigid_r, :osb_thick_in, :drywall_thick_in, :exterior_material)
end

class GenericConstructionSet
  def initialize(rigid_r, osb_thick_in, drywall_thick_in, exterior_material)
    @rigid_r = rigid_r
    @osb_thick_in = osb_thick_in
    @drywall_thick_in = drywall_thick_in
    @exterior_material = exterior_material
  end
  attr_accessor(:rigid_r, :osb_thick_in, :drywall_thick_in, :exterior_material)
end

def to_beopt_fuel(fuel)
  return { "natural gas" => Constants.FuelTypeGas,
           "fuel oil" => Constants.FuelTypeOil,
           "propane" => Constants.FuelTypePropane,
           "electricity" => Constants.FuelTypeElectric,
           "wood" => Constants.FuelTypeWood,
           "wood pellets" => Constants.FuelTypeWoodPellets }[fuel]
end

def to_beopt_wh_type(type)
  return { 'storage water heater' => Constants.WaterHeaterTypeTank,
           'instantaneous water heater' => Constants.WaterHeaterTypeTankless,
           'heat pump water heater' => Constants.WaterHeaterTypeHeatPump }[type]
end

def is_thermal_boundary(surface_values)
  if surface_values[:exterior_adjacent_to] == "other housing unit"
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

def hpxml_floor_is_ceiling(floor_interior_adjacent_to, floor_exterior_adjacent_to)
  if floor_interior_adjacent_to.include? "attic"
    return true
  elsif floor_exterior_adjacent_to.include? "attic"
    return true
  end

  return false
end

def get_foundation_and_walls_top(building)
  foundation_top = 0
  building.elements.each("BuildingDetails/Enclosure/FoundationWalls/FoundationWall") do |fnd_wall|
    fnd_wall_values = HPXML.get_foundation_wall_values(foundation_wall: fnd_wall)
    top = -1 * fnd_wall_values[:depth_below_grade] + fnd_wall_values[:height]
    foundation_top = top if top > foundation_top
  end
  walls_top = foundation_top + 8.0 * @ncfl_ag
  return foundation_top, walls_top
end

def get_ac_num_speeds(seer)
  if seer <= 15
    return "1-Speed"
  elsif seer <= 21
    return "2-Speed"
  elsif seer > 21
    return "Variable-Speed"
  end
end

def get_ashp_num_speeds_by_seer(seer)
  if seer <= 15
    return "1-Speed"
  elsif seer <= 21
    return "2-Speed"
  elsif seer > 21
    return "Variable-Speed"
  end
end

def get_ashp_num_speeds_by_hspf(hspf)
  if hspf <= 8.5
    return "1-Speed"
  elsif hspf <= 9.5
    return "2-Speed"
  elsif hspf > 9.5
    return "Variable-Speed"
  end
end

def get_fan_power_installed(seer)
  if seer <= 15
    return 0.365 # W/cfm
  else
    return 0.14 # W/cfm
  end
end

class OutputVars
  def self.SpaceHeatingElectricity
    return { 'OpenStudio::Model::CoilHeatingDXSingleSpeed' => ['Heating Coil Electric Energy', 'Heating Coil Crankcase Heater Electric Energy', 'Heating Coil Defrost Electric Energy'],
             'OpenStudio::Model::CoilHeatingDXMultiSpeed' => ['Heating Coil Electric Energy', 'Heating Coil Crankcase Heater Electric Energy', 'Heating Coil Defrost Electric Energy'],
             'OpenStudio::Model::CoilHeatingElectric' => ['Heating Coil Electric Energy', 'Heating Coil Crankcase Heater Electric Energy', 'Heating Coil Defrost Electric Energy'],
             'OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit' => ['Heating Coil Electric Energy', 'Heating Coil Crankcase Heater Electric Energy', 'Heating Coil Defrost Electric Energy'],
             'OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric' => ['Baseboard Electric Energy'],
             'OpenStudio::Model::BoilerHotWater' => ['Boiler Electric Energy'] }
  end

  def self.SpaceHeatingFuel
    return { 'OpenStudio::Model::CoilHeatingGas' => ['Heating Coil Gas Energy', 'Heating Coil Propane Energy', 'Heating Coil FuelOil#1 Energy'],
             'OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric' => ['Baseboard Gas Energy', 'Baseboard Propane Energy', 'Baseboard FuelOil#1 Energy'],
             'OpenStudio::Model::BoilerHotWater' => ['Boiler Gas Energy', 'Boiler Propane Energy', 'Boiler FuelOil#1 Energy'] }
  end

  def self.SpaceHeatingLoad
    return { 'OpenStudio::Model::CoilHeatingDXSingleSpeed' => ['Heating Coil Heating Energy'],
             'OpenStudio::Model::CoilHeatingDXMultiSpeed' => ['Heating Coil Heating Energy'],
             'OpenStudio::Model::CoilHeatingElectric' => ['Heating Coil Heating Energy'],
             'OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit' => ['Heating Coil Heating Energy'],
             'OpenStudio::Model::CoilHeatingGas' => ['Heating Coil Heating Energy'],
             'OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric' => ['Baseboard Total Heating Energy'],
             'OpenStudio::Model::BoilerHotWater' => ['Boiler Heating Energy'] }
  end

  def self.SpaceCoolingElectricity
    return { 'OpenStudio::Model::CoilCoolingDXSingleSpeed' => ['Cooling Coil Electric Energy', 'Cooling Coil Crankcase Heater Electric Energy'],
             'OpenStudio::Model::CoilCoolingDXMultiSpeed' => ['Cooling Coil Electric Energy', 'Cooling Coil Crankcase Heater Electric Energy'],
             'OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit' => ['Cooling Coil Electric Energy', 'Cooling Coil Crankcase Heater Electric Energy'] }
  end

  def self.SpaceCoolingLoad
    return { 'OpenStudio::Model::CoilCoolingDXSingleSpeed' => ['Cooling Coil Total Cooling Energy'],
             'OpenStudio::Model::CoilCoolingDXMultiSpeed' => ['Cooling Coil Total Cooling Energy'],
             'OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit' => ['Cooling Coil Total Cooling Energy'] }
  end

  def self.WaterHeatingElectricity
    return { 'OpenStudio::Model::WaterHeaterMixed' => ['Water Heater Electric Energy', 'Water Heater Off Cycle Parasitic Electric Energy', 'Water Heater On Cycle Parasitic Electric Energy'],
             'OpenStudio::Model::WaterHeaterStratified' => ['Water Heater Electric Energy', 'Water Heater Off Cycle Parasitic Electric Energy', 'Water Heater On Cycle Parasitic Electric Energy'],
             'OpenStudio::Model::CoilWaterHeatingAirToWaterHeatPumpWrapped' => ['Cooling Coil Water Heating Electric Energy'] }
  end

  def self.WaterHeatingElectricitySolarThermalPump
    return { 'OpenStudio::Model::PumpConstantSpeed' => ['Pump Electric Energy'] }
  end

  def self.WaterHeatingElectricityRecircPump
    return { 'OpenStudio::Model::ElectricEquipment' => ['Electric Equipment Electric Energy'] }
  end

  def self.WaterHeatingFuel
    return { 'OpenStudio::Model::WaterHeaterMixed' => ['Water Heater Gas Energy', 'Water Heater Propane Energy', 'Water Heater FuelOil#1 Energy'],
             'OpenStudio::Model::WaterHeaterStratified' => ['Water Heater Gas Energy', 'Water Heater Propane Energy', 'Water Heater FuelOil#1 Energy'] }
  end

  def self.WaterHeatingLoad
    return { 'OpenStudio::Model::WaterUseConnections' => ['Water Use Connections Plant Hot Water Energy'] }
  end
end

# register the measure to be used by the application
HPXMLTranslator.new.registerWithApplication
