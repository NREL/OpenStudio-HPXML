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

    hpxml_doc = REXML::Document.new(File.read(hpxml_path))

    # Check for invalid HPXML file up front?
    if not skip_validation
      if not validate_hpxml(runner, hpxml_path, hpxml_doc, schemas_dir)
        return false
      end
    end

    begin
      # Weather file
      weather_wmo = XMLHelper.get_value(hpxml_doc, "/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/WMO")
      epw_path = nil
      CSV.foreach(File.join(weather_dir, "data.csv"), headers: true) do |row|
        next if row["wmo"] != weather_wmo

        epw_path = File.join(weather_dir, row["filename"])
        if not File.exists?(epw_path)
          runner.registerError("'#{epw_path}' could not be found. Perhaps you need to run: openstudio energy_rating_index.rb --download-weather")
          return false
        end
        cache_path = epw_path.gsub('.epw', '.cache')
        if not File.exists?(cache_path)
          runner.registerError("'#{cache_path}' could not be found. Perhaps you need to run: openstudio energy_rating_index.rb --download-weather")
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

    @eri_version = XMLHelper.get_value(hpxml_doc, "/HPXML/SoftwareInfo/extension/ERICalculation/Version")
    fail "Could not find ERI Version" if @eri_version.nil?

    building = hpxml_doc.elements["/HPXML/Building"]
    @cfa = Float(XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedFloorArea"))
    @ncfl = Float(XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloors"))
    @nbeds = Float(XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/BuildingConstruction/NumberofBedrooms"))
    @garage_present = Boolean(XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/BuildingConstruction/GaragePresent"))
    @has_uncond_bsmnt = (not building.elements["BuildingDetails/Enclosure/Foundations/FoundationType/Basement[Conditioned='false']"].nil?)
    @iecc_zone_2006 = XMLHelper.get_value(building, "BuildingDetails/ClimateandRiskZones/ClimateZoneIECC[Year='2006']/ClimateZone")

    loop_hvacs = {} # mapping between HPXML HVAC systems and model air/plant loops
    zone_hvacs = {} # mapping between HPXML HVAC systems and model zonal HVACs
    loop_dhws = {}  # mapping between HPXML Water Heating systems and plant loops

    use_only_ideal_air = XMLHelper.get_value(building, "BuildingDetails/Systems/HVAC/extension/UseOnlyIdealAirSystem")
    if use_only_ideal_air.nil?
      use_only_ideal_air = false
    else
      use_only_ideal_air = Boolean(use_only_ideal_air)
    end

    # Geometry/Envelope

    spaces = {}
    success, unit = add_geometry_envelope(runner, model, building, weather, spaces)
    return false if not success

    # Bedrooms, Occupants

    success = add_num_bedrooms_occupants(model, building, runner)
    return false if not success

    # Hot Water

    success = add_hot_water_and_appliances(runner, model, building, unit, weather, spaces, loop_dhws)
    return false if not success

    # HVAC

    success = add_cooling_system(runner, model, building, unit, loop_hvacs, zone_hvacs, use_only_ideal_air)
    return false if not success

    success = add_heating_system(runner, model, building, unit, loop_hvacs, zone_hvacs, use_only_ideal_air)
    return false if not success

    success = add_heat_pump(runner, model, building, unit, weather, loop_hvacs, zone_hvacs, use_only_ideal_air)
    return false if not success

    success = add_residual_hvac(runner, model, building, unit, use_only_ideal_air)
    return false if not success

    success = add_setpoints(runner, model, building, weather)
    return false if not success

    success = add_ceiling_fans(runner, model, building, unit)
    return false if not success

    # FIXME: remove the following logic eventually
    load_distribution = XMLHelper.get_value(building, "BuildingDetails/Systems/HVAC/extension/LoadDistributionScheme")
    if not load_distribution.nil?
      if not ["UniformLoad", "SequentialLoad"].include? load_distribution
        fail "Unexpected load distribution scheme #{load_distribution}."
      end

      thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)
      control_slave_zones_hash = HVAC.get_control_and_slave_zones(thermal_zones)
      control_slave_zones_hash.each do |control_zone, slave_zones|
        ([control_zone] + slave_zones).each do |zone|
          HVAC.prioritize_zone_hvac(model, runner, zone, load_distribution)
        end
      end
    end

    # Plug Loads & Lighting

    success = add_mels(runner, model, building, unit, spaces)
    return false if not success

    success = add_lighting(runner, model, building, unit, weather)
    return false if not success

    # Other

    success = add_airflow(runner, model, building, unit, loop_hvacs)
    return false if not success

    success = add_hvac_sizing(runner, model, unit, weather)
    return false if not success

    success = add_fuel_heating_eae(runner, model, building, loop_hvacs, zone_hvacs)
    return false if not success

    success = add_photovoltaics(runner, model, building)
    return false if not success

    success = add_building_output_variables(runner, model, loop_hvacs, zone_hvacs, loop_dhws, map_tsv_dir)
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
    subsurface_areas = get_subsurface_areas(building)

    heating_season, cooling_season = HVAC.calc_heating_and_cooling_seasons(model, weather, runner)
    return false if heating_season.nil? or cooling_season.nil?

    success, unit = add_building_info(model, building)
    return false if not success

    success = add_foundations(runner, model, building, spaces, subsurface_areas)
    return false if not success

    success = add_walls(runner, model, building, spaces, subsurface_areas)
    return false if not success

    success = add_rim_joists(runner, model, building, spaces)
    return false if not success

    success = add_windows(runner, model, building, spaces, subsurface_areas, weather, cooling_season)
    return false if not success

    success = add_doors(runner, model, building, spaces, subsurface_areas)
    return false if not success

    success = add_skylights(runner, model, building, spaces, subsurface_areas, weather, cooling_season)
    return false if not success

    success = add_attics(runner, model, building, spaces, subsurface_areas)
    return false if not success

    success = add_finished_floor_area(runner, model, building, spaces)
    return false if not success

    success = add_thermal_mass(runner, model, building)
    return false if not success

    success = check_for_errors(runner, model)
    return false if not success

    success = set_zone_volumes(runner, model, building)
    return false if not success

    success = explode_surfaces(runner, model)
    return false if not success

    return true, unit
  end

  def self.set_zone_volumes(runner, model, building)
    total_conditioned_volume = Float(XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedBuildingVolume"))
    thermal_zones = model.getThermalZones

    # Init
    living_volume = total_conditioned_volume
    zones_updated = 0

    # Basements, crawl, garage
    thermal_zones.each do |thermal_zone|
      if Geometry.is_finished_basement(thermal_zone) or Geometry.is_unfinished_basement(thermal_zone) or Geometry.is_crawl(thermal_zone) or Geometry.is_garage(thermal_zone)
        zones_updated += 1

        zone_volume = Geometry.get_height_of_spaces(thermal_zone.spaces) * Geometry.get_floor_area_from_spaces(thermal_zone.spaces)
        if zone_volume <= 0
          fail "Calculated volume for #{thermal_zone.name} zone (#{zone_volume}) is not greater than zero."
        end

        thermal_zone.setVolume(UnitConversions.convert(zone_volume, "ft^3", "m^3"))

        if Geometry.is_finished_basement(thermal_zone)
          living_volume = total_conditioned_volume - zone_volume
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
      if Geometry.is_unfinished_attic(thermal_zone)
        zones_updated += 1

        zone_surfaces = []
        thermal_zone.spaces.each do |space|
          space.surfaces.each do |surface|
            zone_surfaces << surface
          end
        end

        # Assume square hip roof for volume calculations; energy results are very insensitive to actual volume
        zone_area = Geometry.get_floor_area_from_spaces(thermal_zone.spaces)
        zone_length = zone_area**0.5
        zone_height = Math.tan(UnitConversions.convert(Geometry.get_roof_pitch(zone_surfaces), "deg", "rad")) * zone_length / 2.0
        zone_volume = [zone_area * zone_height / 3.0, 0.01].max
        thermal_zone.setVolume(UnitConversions.convert(zone_volume, "ft^3", "m^3"))
      end
    end

    if zones_updated != thermal_zones.size
      fail "Unhandled volume calculations for thermal zones."
    end

    return true
  end

  def self.explode_surfaces(runner, model)
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

      surfaces << surface
      azimuth = surface.additionalProperties.getFeatureAsDouble("Azimuth").get
      if azimuth_lengths[azimuth].nil?
        azimuth_lengths[azimuth] = 0.0
      end
      azimuth_lengths[azimuth] += surface.additionalProperties.getFeatureAsDouble("Length").get + gap_distance
    end
    max_azimuth_length = azimuth_lengths.values.max

    # Initial distance of shifts at 90-degrees to horizontal outward
    azimuth_side_shifts = {}
    azimuth_lengths.each do |key, value|
      azimuth_side_shifts[key] = max_azimuth_length / 2.0
    end

    # Explode walls, windows, doors, roofs, and skylights
    surfaces_moved = []

    surfaces.sort.each do |surface|
      if surface.adjacentSurface.is_initialized
        next if surfaces_moved.include? surface.adjacentSurface.get
      end

      azimuth = surface.additionalProperties.getFeatureAsDouble("Azimuth").get
      azimuth_rad = UnitConversions.convert(azimuth, "deg", "rad")

      # Push out horizontally
      distance = max_azimuth_length
      if surface.surfaceType.downcase == "roofceiling"
        # Ensure pitched surfaces are positioned outward justified with walls, etc.
        roof_tilt = surface.additionalProperties.getFeatureAsDouble("Tilt").get
        roof_width = surface.additionalProperties.getFeatureAsDouble("Width").get
        distance -= 0.5 * Math.cos(Math.atan(roof_tilt)) * roof_width
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
      n_floors = 0
      n_roofceilings = 0
      n_exteriors = 0
      zone.spaces.each do |space|
        space.surfaces.each do |surface|
          if ["outdoors", "foundation"].include? surface.outsideBoundaryCondition.downcase
            n_exteriors += 1
          end
          if surface.surfaceType.downcase == "floor"
            n_floors += 1
          elsif surface.surfaceType.downcase == "roofceiling"
            n_roofceilings += 1
          end
        end
      end

      if n_floors == 0
        runner.registerError("Thermal zone '#{zone.name}' must have at least one floor surface.")
      end
      if n_roofceilings == 0
        runner.registerError("Thermal zone '#{zone.name}' must have at least one roof/ceiling surface.")
      end
      if n_exteriors == 0
        runner.registerError("Thermal zone '#{zone.name}' must have at least one surface adjacent to outside/ground.")
      end
      if n_floors == 0 or n_roofceilings == 0 or n_exteriors == 0
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

      model.getBuildingUnits.each do |unit|
        space.setBuildingUnit(unit)
      end

      st = OpenStudio::Model::SpaceType.new(model)
      st.setStandardsSpaceType(space_type)
      space.setSpaceType(st)

      space.setThermalZone(thermal_zone)
      spaces[space_type] = space
    end
  end

  def self.add_building_info(model, building)
    # Store building unit information
    unit = OpenStudio::Model::BuildingUnit.new(model)
    unit.setBuildingUnitType(Constants.BuildingUnitTypeResidential)
    unit.setName(Constants.ObjectNameBuildingUnit)

    # Store number of units
    model.getBuilding.setStandardsNumberOfLivingUnits(1)

    # Store number of stories
    num_stories = Integer(XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloors"))
    model.getBuilding.setStandardsNumberOfStories(num_stories)
    num_stories_above_grade = Integer(XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloorsAboveGrade"))
    model.getBuilding.setStandardsNumberOfAboveGroundStories(num_stories_above_grade)

    # Store info for HVAC Sizing measure
    if @garage_present
      unit.additionalProperties.setFeature(Constants.SizingInfoGarageFracUnderFinishedSpace, 0.5) # FIXME: assumption
    end

    return true, unit
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

  def self.net_wall_area(gross_wall_area, wall_subsurface_areas, wall_id)
    if wall_subsurface_areas.keys.include? wall_id
      return gross_wall_area - wall_subsurface_areas[wall_id]
    end

    return gross_wall_area
  end

  def self.add_num_bedrooms_occupants(model, building, runner)
    # Bedrooms
    num_bedrooms = Integer(XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/BuildingConstruction/NumberofBedrooms"))
    num_bathrooms = 3.0 # Arbitrary, no impact on results since water heater capacity is required
    success = Geometry.process_beds_and_baths(model, runner, [num_bedrooms], [num_bathrooms])
    return false if not success

    # Occupants
    num_occ = XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/BuildingOccupancy/NumberofResidents")
    if num_occ.nil?
      num_occ = Geometry.get_occupancy_default_num(num_bedrooms)
    else
      num_occ = Float(num_occ)
    end
    if num_occ > 0
      occ_gain, hrs_per_day, sens_frac, lat_frac = Geometry.get_occupancy_default_values()
      weekday_sch = "1.00000, 1.00000, 1.00000, 1.00000, 1.00000, 1.00000, 1.00000, 0.88310, 0.40861, 0.24189, 0.24189, 0.24189, 0.24189, 0.24189, 0.24189, 0.24189, 0.29498, 0.55310, 0.89693, 0.89693, 0.89693, 1.00000, 1.00000, 1.00000" # TODO: Normalize schedule based on hrs_per_day
      weekend_sch = weekday_sch
      monthly_sch = "1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0"
      success = Geometry.process_occupants(model, runner, num_occ.to_s, occ_gain, sens_frac, lat_frac, weekday_sch, weekend_sch, monthly_sch)
      return false if not success
    end

    return true
  end

  def self.get_subsurface_areas(building)
    subsurface_areas = {}

    # Windows
    building.elements.each("BuildingDetails/Enclosure/Windows/Window") do |window|
      wall_id = window.elements["AttachedToWall"].attributes["idref"]
      if not subsurface_areas.keys.include? wall_id
        subsurface_areas[wall_id] = 0
      end
      window_area = Float(XMLHelper.get_value(window, "Area"))
      subsurface_areas[wall_id] += window_area
    end

    # Skylights
    building.elements.each("BuildingDetails/Enclosure/Skylights/Skylight") do |skylight|
      roof_id = skylight.elements["AttachedToRoof"].attributes["idref"]
      if not subsurface_areas.keys.include? roof_id
        subsurface_areas[roof_id] = 0
      end
      skylight_area = Float(XMLHelper.get_value(skylight, "Area"))
      subsurface_areas[roof_id] += skylight_area
    end

    # Doors
    building.elements.each("BuildingDetails/Enclosure/Doors/Door") do |door|
      wall_id = door.elements["AttachedToWall"].attributes["idref"]
      if not subsurface_areas.keys.include? wall_id
        subsurface_areas[wall_id] = 0
      end
      door_area = XMLHelper.get_value(door, "Area")
      if not door_area.nil?
        door_area = Float(door_area)
      else
        door_area = SubsurfaceConstructions.get_default_door_area()
      end
      subsurface_areas[wall_id] += door_area
    end

    return subsurface_areas
  end

  def self.create_or_get_space(model, spaces, spacetype)
    if spaces[spacetype].nil?
      create_space_and_zone(model, spaces, spacetype)
    end
    return spaces[spacetype]
  end

  def self.add_foundations(runner, model, building, spaces, subsurface_areas)
    building.elements.each("BuildingDetails/Enclosure/Foundations/Foundation") do |foundation|
      foundation_id = foundation.elements["SystemIdentifier"].attributes["id"]
      foundation_type = foundation.elements["FoundationType"]
      interior_adjacent_to = get_foundation_adjacent_to(foundation_type)

      # Foundation slab surfaces
      slab_surface = nil
      perim_exp = 0.0
      slab_ext_r, slab_ext_depth, slab_perim_r, slab_perim_width, slab_gap_r = nil
      slab_whole_r, slab_concrete_thick_in = nil
      num_slabs = 0
      foundation.elements.each("Slab") do |fnd_slab|
        num_slabs += 1
        slab_id = fnd_slab.elements["SystemIdentifier"].attributes["id"]

        slab_perim = Float(XMLHelper.get_value(fnd_slab, "ExposedPerimeter"))
        perim_exp += slab_perim
        slab_area = Float(XMLHelper.get_value(fnd_slab, "Area"))
        # Calculate length/width given perimeter/area
        sqrt_term = slab_perim**2 - 16.0 * slab_area
        if sqrt_term < 0
          slab_length = slab_perim / 4.0
          slab_width = slab_perim / 4.0
        else
          slab_length = slab_perim / 4.0 + Math.sqrt(sqrt_term) / 4.0
          slab_width = slab_perim / 4.0 - Math.sqrt(sqrt_term) / 4.0
        end

        z_origin = -1 * Float(XMLHelper.get_value(fnd_slab, "DepthBelowGrade"))

        surface = OpenStudio::Model::Surface.new(add_floor_polygon(slab_length, slab_width, z_origin), model)

        surface.setName(slab_id)
        surface.setSurfaceType("Floor")
        surface.setOutsideBoundaryCondition("Foundation")
        set_surface_interior(model, spaces, surface, slab_id, interior_adjacent_to)
        surface.setSunExposure("NoSun")
        surface.setWindExposure("NoWind")
        slab_surface = surface

        slab_gap_r = 0.0 # FIXME
        slab_whole_r = 0.0 # FIXME
        slab_concrete_thick_in = Float(XMLHelper.get_value(fnd_slab, "Thickness"))

        fnd_slab_perim = fnd_slab.elements["PerimeterInsulation/Layer[InstallationType='continuous']"]
        slab_ext_r = Float(XMLHelper.get_value(fnd_slab_perim, "NominalRValue"))
        slab_ext_depth = Float(XMLHelper.get_value(fnd_slab, "PerimeterInsulationDepth"))
        if not slab_ext_r.nil? and not slab_ext_depth.nil?
          slab_ext_r = Float(slab_ext_r)
          slab_ext_depth = Float(slab_ext_depth)
        else
          slab_ext_r, slab_ext_depth = FloorConstructions.get_default_slab_perimeter_rvalue_depth(@iecc_zone_2006)
        end
        if slab_ext_r == 0 or slab_ext_depth == 0
          slab_ext_r = 0
          slab_ext_depth = 0
        end

        fnd_slab_under = fnd_slab.elements["UnderSlabInsulation/Layer[InstallationType='continuous']"]
        slab_perim_r = Float(XMLHelper.get_value(fnd_slab_under, "NominalRValue"))
        slab_perim_width = Float(XMLHelper.get_value(fnd_slab, "UnderSlabInsulationWidth"))
        if not slab_perim_r.nil? and not slab_perim_width.nil?
          slab_perim_r = Float(slab_perim_r)
          slab_perim_width = Float(slab_perim_width)
        else
          slab_perim_r, slab_perim_width = FloorConstructions.get_default_slab_under_rvalue_width()
        end
        if slab_perim_r == 0 or slab_perim_width == 0
          slab_perim_r = 0
          slab_perim_width = 0
        end
      end
      if num_slabs > 1
        fail "Cannot currently handle multiple Foundation/Slab elements." # FIXME
      end

      # Foundation wall surfaces

      fnd_id = foundation.elements["SystemIdentifier"].attributes["id"]
      wall_surface = nil
      wall_height, wall_cav_r, wall_cav_depth, wall_grade, wall_ff, wall_cont_height, wall_cont_r = nil
      wall_cont_depth, walls_filled_cavity, walls_drywall_thick_in, walls_concrete_thick_in = nil
      wall_assembly_r, wall_film_r = nil
      num_walls = 0
      foundation.elements.each("FoundationWall") do |fnd_wall|
        num_walls += 1
        wall_id = fnd_wall.elements["SystemIdentifier"].attributes["id"]

        exterior_adjacent_to = XMLHelper.get_value(fnd_wall, "AdjacentTo")

        wall_height = Float(XMLHelper.get_value(fnd_wall, "Height"))
        wall_gross_area = Float(XMLHelper.get_value(fnd_wall, "Area"))
        wall_net_area = net_wall_area(wall_gross_area, subsurface_areas, fnd_id)
        if wall_net_area <= 0
          fail "Calculated a negative net surface area for Wall '#{wall_id}'."
        end

        wall_length = wall_net_area / wall_height

        z_origin = -1 * Float(XMLHelper.get_value(fnd_wall, "DepthBelowGrade"))

        wall_azimuth = XMLHelper.get_value(fnd_wall, "Azimuth")
        if not wall_azimuth.nil?
          wall_azimuth = Float(wall_azimuth)
        else
          wall_azimuth = 0.0 # TODO
        end

        surface = OpenStudio::Model::Surface.new(add_wall_polygon(wall_length, wall_height, z_origin,
                                                                  wall_azimuth), model)

        surface.additionalProperties.setFeature("Length", wall_length)
        surface.additionalProperties.setFeature("Azimuth", wall_azimuth)
        surface.setName(wall_id)
        surface.setSurfaceType("Wall")
        set_surface_interior(model, spaces, surface, wall_id, interior_adjacent_to)
        set_surface_exterior(model, spaces, surface, wall_id, exterior_adjacent_to)
        wall_surface = surface

        if is_external_thermal_boundary(interior_adjacent_to, exterior_adjacent_to)
          walls_drywall_thick_in = 0.5
        else
          walls_drywall_thick_in = 0.0
        end
        walls_filled_cavity = true
        walls_concrete_thick_in = Float(XMLHelper.get_value(fnd_wall, "Thickness"))
        wall_assembly_r = XMLHelper.get_value(fnd_wall, "Insulation/AssemblyEffectiveRValue")
        if not wall_assembly_r.nil?
          wall_assembly_r = Float(wall_assembly_r)
        else
          wall_assembly_r = 1.0 / FoundationConstructions.get_default_basement_wall_ufactor(@iecc_zone_2006)
        end
        wall_film_r = Material.AirFilmVertical.rvalue
        wall_cav_r = 0.0
        wall_cav_depth = 0.0
        wall_grade = 1
        wall_ff = 0.0
        wall_cont_height = Float(XMLHelper.get_value(fnd_wall, "Height"))
        wall_cont_r = wall_assembly_r - Material.Concrete(walls_concrete_thick_in).rvalue - Material.GypsumWall(walls_drywall_thick_in).rvalue - wall_film_r
        if wall_cont_r < 0 # Try without drywall
          walls_drywall_thick_in = 0.0
          wall_cont_r = wall_assembly_r - Material.Concrete(walls_concrete_thick_in).rvalue - Material.GypsumWall(walls_drywall_thick_in).rvalue - wall_film_r
        end
        wall_cont_depth = 1.0
      end
      if num_walls > 1
        fail "Cannot currently handle multiple Foundation/FoundationWall elements." # FIXME
      end

      # Foundation ceiling surfaces

      ceiling_surfaces = []
      floor_cav_r, floor_cav_depth, floor_grade, floor_ff, floor_cont_r = nil
      plywood_thick_in, mat_floor_covering, mat_carpet = nil
      floor_assembly_r, floor_film_r = nil
      foundation.elements.each("FrameFloor") do |fnd_floor|
        floor_id = fnd_floor.elements["SystemIdentifier"].attributes["id"]

        exterior_adjacent_to = XMLHelper.get_value(fnd_floor, "AdjacentTo")

        framefloor_area = Float(XMLHelper.get_value(fnd_floor, "Area"))
        framefloor_width = Math::sqrt(framefloor_area)
        framefloor_length = framefloor_area / framefloor_width

        if foundation_type.elements["Ambient"]
          z_origin = 2.0
        elsif foundation_type.elements["SlabOnGrade"]
          z_origin = 0.0
        elsif foundation_type.elements["Basement"] or foundation_type.elements["Crawlspace"]
          z_origin = -1 * Float(XMLHelper.get_value(foundation, "FoundationWall/DepthBelowGrade")) +
                     Float(XMLHelper.get_value(foundation, "FoundationWall/Height"))
        end

        surface = OpenStudio::Model::Surface.new(add_floor_polygon(framefloor_length, framefloor_width, z_origin), model)

        surface.setName(floor_id)
        if interior_adjacent_to == "outside" # pier & beam foundation
          surface.setSurfaceType("Floor")
          set_surface_interior(model, spaces, surface, floor_id, exterior_adjacent_to)
          set_surface_exterior(model, spaces, surface, floor_id, interior_adjacent_to)
        else
          surface.setSurfaceType("RoofCeiling")
          set_surface_interior(model, spaces, surface, floor_id, interior_adjacent_to)
          set_surface_exterior(model, spaces, surface, floor_id, exterior_adjacent_to)
        end
        surface.setSunExposure("NoSun")
        surface.setWindExposure("NoWind")
        ceiling_surfaces << surface

        floor_film_r = 2.0 * Material.AirFilmFloorReduced.rvalue

        floor_assembly_r = XMLHelper.get_value(fnd_floor, "Insulation/AssemblyEffectiveRValue")
        if not floor_assembly_r.nil?
          floor_assembly_r = Float(floor_assembly_r)
        else
          floor_assembly_r = 1.0 / FloorConstructions.get_default_floor_ufactor(@iecc_zone_2006)
        end
        constr_sets = [
          WoodStudConstructionSet.new(Material.Stud2x6, 0.10, 0.0, 0.75, 0.0, Material.CoveringBare), # 2x6, 24" o.c.
          WoodStudConstructionSet.new(Material.Stud2x4, 0.13, 0.0, 0.5, 0.0, Material.CoveringBare),  # 2x4, 16" o.c.
          WoodStudConstructionSet.new(Material.Stud2x4, 0.01, 0.0, 0.0, 0.0, nil),                    # Fallback
        ]
        floor_constr_set, floor_cav_r = pick_wood_stud_construction_set(floor_assembly_r, constr_sets, floor_film_r, "foundation framefloor #{floor_id}")

        mat_floor_covering = nil
        mat_carpet = floor_constr_set.exterior_material
        plywood_thick_in = floor_constr_set.osb_thick_in
        floor_cav_depth = floor_constr_set.stud.thick_in
        floor_ff = floor_constr_set.framing_factor
        floor_cont_r = floor_constr_set.rigid_r
        floor_grade = 1
      end

      # Apply constructions

      if wall_surface.nil? and slab_surface.nil?

        # nop

      elsif wall_surface.nil?

        # Foundation slab only

        success = FoundationConstructions.apply_slab(runner, model, slab_surface, "SlabConstruction",
                                                     slab_perim_r, slab_perim_width, slab_gap_r, slab_ext_r, slab_ext_depth,
                                                     slab_whole_r, slab_concrete_thick_in, mat_carpet,
                                                     false, perim_exp, nil)
        return false if not success

        # FIXME: Temporary code for sizing
        slab_surface.additionalProperties.setFeature(Constants.SizingInfoSlabRvalue, 5.0)

      else

        # Foundation slab, walls, and ceilings

        if slab_surface.nil?
          # Handle crawlspace without a slab (i.e., dirt floor)
        end

        success = FoundationConstructions.apply_walls_and_slab(runner, model, [wall_surface], "FndWallConstruction",
                                                               wall_cont_height, wall_cav_r, wall_grade,
                                                               wall_cav_depth, walls_filled_cavity, wall_ff,
                                                               wall_cont_r, walls_drywall_thick_in, walls_concrete_thick_in,
                                                               wall_height, slab_surface, "SlabConstruction",
                                                               slab_whole_r, slab_concrete_thick_in, perim_exp)
        return false if not success

        if not wall_assembly_r.nil?
          check_surface_assembly_rvalue(wall_surface, wall_film_r, wall_assembly_r)
        end

      end

      # Foundation ceiling
      success = FloorConstructions.apply_foundation_ceiling(runner, model, ceiling_surfaces, "FndCeilingConstruction",
                                                            floor_cav_r, floor_grade,
                                                            floor_ff, floor_cav_depth,
                                                            plywood_thick_in, mat_floor_covering,
                                                            mat_carpet)
      return false if not success

      if not floor_assembly_r.nil?
        check_surface_assembly_rvalue(ceiling_surfaces[0], floor_film_r, floor_assembly_r)
      end
    end

    return true
  end

  def self.add_finished_floor_area(runner, model, building, spaces)
    ffa = Float(XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedFloorArea")).round(1)

    # First check if we need to add a finished basement ceiling
    foundation_top = get_foundation_top(model)

    model.getThermalZones.each do |zone|
      next if not Geometry.is_finished_basement(zone)

      floor_area = Geometry.get_finished_floor_area_from_spaces(zone.spaces).round(1)
      ceiling_area = 0.0
      zone.spaces.each do |space|
        space.surfaces.each do |surface|
          next if surface.surfaceType.downcase.to_s != "roofceiling"

          ceiling_area += UnitConversions.convert(surface.grossArea, "m^2", "ft^2")
        end
      end
      addtl_ffa = floor_area - ceiling_area
      if addtl_ffa > 0
        runner.registerWarning("Adding finished basement adiabatic ceiling with #{addtl_ffa.to_s} ft^2.")

        finishedfloor_width = Math::sqrt(addtl_ffa)
        finishedfloor_length = addtl_ffa / finishedfloor_width
        z_origin = foundation_top

        surface = OpenStudio::Model::Surface.new(add_ceiling_polygon(-finishedfloor_width, -finishedfloor_length, z_origin), model)

        surface.setSunExposure("NoSun")
        surface.setWindExposure("NoWind")
        surface.setName("inferred finished basement ceiling")
        surface.setSurfaceType("RoofCeiling")
        surface.setSpace(zone.spaces[0])
        surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeLiving))

        # Apply Construction
        success = apply_adiabatic_construction(runner, model, [surface], "floor")
        return false if not success
      end
    end

    # Next check if we need to add floors between finished spaces (e.g., 2-story buildings).

    # Calculate ffa already added to model
    model_ffa = Geometry.get_finished_floor_area_from_spaces(model.getSpaces).round(1)
    nstories_ag = Float(XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloorsAboveGrade"))

    if model_ffa > ffa
      runner.registerError("Sum of conditioned floor surface areas #{model_ffa.to_s} is greater than ConditionedFloorArea specified #{ffa.to_s}.")
      return false
    end

    addtl_ffa = ffa - model_ffa
    return true unless addtl_ffa > 0

    runner.registerWarning("Adding adiabatic conditioned floor with #{addtl_ffa.to_s} ft^2 to preserve building total conditioned floor area.")

    finishedfloor_width = Math::sqrt(addtl_ffa)
    finishedfloor_length = addtl_ffa / finishedfloor_width
    z_origin = foundation_top + 8.0 * (nstories_ag - 1)

    surface = OpenStudio::Model::Surface.new(add_floor_polygon(-finishedfloor_width, -finishedfloor_length, z_origin), model)

    surface.setSunExposure("NoSun")
    surface.setWindExposure("NoWind")
    surface.setName("inferred finished floor")
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
    partition_frac_of_ffa = 1.0
    success = ThermalMassConstructions.apply_partition_walls(runner, model, [],
                                                             "PartitionWallConstruction",
                                                             drywall_thick_in, partition_frac_of_ffa)
    return false if not success

    # FIXME ?
    furniture_frac_of_ffa = 1.0
    mass_lb_per_sqft = 8.0
    density_lb_per_cuft = 40.0
    mat = BaseMaterial.Wood
    success = ThermalMassConstructions.apply_furniture(runner, model, furniture_frac_of_ffa,
                                                       mass_lb_per_sqft, density_lb_per_cuft, mat)
    return false if not success

    return true
  end

  def self.add_walls(runner, model, building, spaces, subsurface_areas)
    foundation_top = get_foundation_top(model)
    nstories_ag = Float(XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloorsAboveGrade"))

    building.elements.each("BuildingDetails/Enclosure/Walls/Wall") do |wall|
      interior_adjacent_to = XMLHelper.get_value(wall, "InteriorAdjacentTo")
      exterior_adjacent_to = XMLHelper.get_value(wall, "ExteriorAdjacentTo")

      wall_id = wall.elements["SystemIdentifier"].attributes["id"]

      wall_gross_area = Float(XMLHelper.get_value(wall, "Area"))
      wall_net_area = net_wall_area(wall_gross_area, subsurface_areas, wall_id)
      if wall_net_area <= 0
        fail "Calculated a negative net surface area for Wall '#{wall_id}'."
      end

      wall_height = 8.0 * nstories_ag
      wall_length = wall_net_area / wall_height
      z_origin = foundation_top
      wall_azimuth = XMLHelper.get_value(wall, "Azimuth")
      if not wall_azimuth.nil?
        wall_azimuth = Float(wall_azimuth)
      else
        wall_azimuth = 0.0 # TODO
      end

      surface = OpenStudio::Model::Surface.new(add_wall_polygon(wall_length, wall_height, z_origin,
                                                                wall_azimuth), model)

      surface.additionalProperties.setFeature("Length", wall_length)
      surface.additionalProperties.setFeature("Azimuth", wall_azimuth)
      surface.setName(wall_id)
      surface.setSurfaceType("Wall")
      set_surface_interior(model, spaces, surface, wall_id, interior_adjacent_to)
      set_surface_exterior(model, spaces, surface, wall_id, exterior_adjacent_to)
      if exterior_adjacent_to != "outside"
        surface.setSunExposure("NoSun")
        surface.setWindExposure("NoWind")
      end

      # Apply construction
      # The code below constructs a reasonable wall construction based on the
      # wall type while ensuring the correct assembly R-value.

      if is_external_thermal_boundary(interior_adjacent_to, exterior_adjacent_to)
        drywall_thick_in = 0.5
      else
        drywall_thick_in = 0.0
      end
      if exterior_adjacent_to == "outside"
        film_r = Material.AirFilmVertical.rvalue + Material.AirFilmOutside.rvalue
        mat_ext_finish = Material.ExtFinishWoodLight
      else
        film_r = 2.0 * Material.AirFilmVertical.rvalue
        mat_ext_finish = nil
      end
      solar_abs = Float(XMLHelper.get_value(wall, "SolarAbsorptance"))
      emitt = Float(XMLHelper.get_value(wall, "Emittance"))
      assembly_r = XMLHelper.get_value(wall, "Insulation/AssemblyEffectiveRValue")
      wall_type = XMLHelper.get_child_name(wall, "WallType")

      apply_wall_construction(runner, model, surface, wall_id, wall_type, assembly_r,
                              drywall_thick_in, film_r, mat_ext_finish, solar_abs, emitt)
    end

    return true
  end

  def self.add_rim_joists(runner, model, building, spaces)
    foundation_top = get_foundation_top(model)

    building.elements.each("BuildingDetails/Enclosure/RimJoists/RimJoist") do |rim_joist|
      interior_adjacent_to = XMLHelper.get_value(rim_joist, "InteriorAdjacentTo")
      exterior_adjacent_to = XMLHelper.get_value(rim_joist, "ExteriorAdjacentTo")

      rim_joist_id = rim_joist.elements["SystemIdentifier"].attributes["id"]

      rim_joist_area = Float(XMLHelper.get_value(rim_joist, "Area"))
      rim_joist_height = 1.0
      rim_joist_length = rim_joist_area / rim_joist_height
      z_origin = foundation_top
      rim_joist_azimuth = XMLHelper.get_value(rim_joist, "Azimuth")
      if not rim_joist_azimuth.nil?
        rim_joist_azimuth = Float(rim_joist_azimuth)
      else
        rim_joist_azimuth = 0.0 # TODO
      end

      surface = OpenStudio::Model::Surface.new(add_wall_polygon(rim_joist_length, rim_joist_height, z_origin,
                                                                rim_joist_azimuth), model)

      surface.additionalProperties.setFeature("Length", rim_joist_length)
      surface.additionalProperties.setFeature("Azimuth", rim_joist_azimuth)
      surface.setName(rim_joist_id)
      surface.setSurfaceType("Wall")
      set_surface_interior(model, spaces, surface, rim_joist_id, interior_adjacent_to)
      set_surface_exterior(model, spaces, surface, rim_joist_id, exterior_adjacent_to)
      if exterior_adjacent_to != "outside"
        surface.setSunExposure("NoSun")
        surface.setWindExposure("NoWind")
      end

      # Apply construction

      if is_external_thermal_boundary(interior_adjacent_to, exterior_adjacent_to)
        drywall_thick_in = 0.5
      else
        drywall_thick_in = 0.0
      end
      if exterior_adjacent_to == "outside"
        film_r = Material.AirFilmVertical.rvalue + Material.AirFilmOutside.rvalue
        mat_ext_finish = Material.ExtFinishWoodLight
      else
        film_r = 2.0 * Material.AirFilmVertical.rvalue
        mat_ext_finish = nil
      end
      solar_abs = 0.75
      emitt = 0.9

      assembly_r = Float(XMLHelper.get_value(rim_joist, "Insulation/AssemblyEffectiveRValue"))

      constr_sets = [
        WoodStudConstructionSet.new(Material.Stud2x(2.0), 0.17, 10.0, 2.0, drywall_thick_in, mat_ext_finish),  # 2x4 + R10
        WoodStudConstructionSet.new(Material.Stud2x(2.0), 0.17, 5.0, 2.0, drywall_thick_in, mat_ext_finish),   # 2x4 + R5
        WoodStudConstructionSet.new(Material.Stud2x(2.0), 0.17, 0.0, 2.0, drywall_thick_in, mat_ext_finish),   # 2x4
        WoodStudConstructionSet.new(Material.Stud2x(2.0), 0.01, 0.0, 0.0, 0.0, nil),                           # Fallback
      ]
      constr_set, cavity_r = pick_wood_stud_construction_set(assembly_r, constr_sets, film_r, "rim joist #{rim_joist_id}")
      install_grade = 1

      success = WallConstructions.apply_rim_joist(runner, model, [surface],
                                                  "RimJoistConstruction",
                                                  cavity_r, install_grade, constr_set.framing_factor,
                                                  constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                                  constr_set.rigid_r, constr_set.exterior_material)
      return false if not success

      check_surface_assembly_rvalue(surface, film_r, assembly_r)

      apply_solar_abs_emittance_to_construction(surface, solar_abs, emitt)
    end

    return true
  end

  def self.add_attics(runner, model, building, spaces, subsurface_areas)
    walls_top = get_walls_top(model)

    building.elements.each("BuildingDetails/Enclosure/Attics/Attic") do |attic|
      attic_type = XMLHelper.get_value(attic, "AtticType")
      interior_adjacent_to = get_attic_adjacent_to(attic_type)

      # Attic floors
      attic.elements.each("Floors/Floor") do |floor|
        floor_id = floor.elements["SystemIdentifier"].attributes["id"]
        exterior_adjacent_to = XMLHelper.get_value(floor, "AdjacentTo")

        floor_area = Float(XMLHelper.get_value(floor, "Area"))
        floor_width = Math::sqrt(floor_area)
        floor_length = floor_area / floor_width
        z_origin = walls_top

        surface = OpenStudio::Model::Surface.new(add_floor_polygon(floor_length, floor_width, z_origin), model)

        surface.setSunExposure("NoSun")
        surface.setWindExposure("NoWind")
        surface.setName(floor_id)
        surface.setSurfaceType("Floor")
        set_surface_interior(model, spaces, surface, floor_id, interior_adjacent_to)
        set_surface_exterior(model, spaces, surface, floor_id, exterior_adjacent_to)

        # Apply construction

        if is_external_thermal_boundary(interior_adjacent_to, exterior_adjacent_to)
          drywall_thick_in = 0.5
        else
          drywall_thick_in = 0.0
        end
        film_r = 2 * Material.AirFilmFloorAverage.rvalue

        assembly_r = XMLHelper.get_value(floor, "Insulation/AssemblyEffectiveRValue")
        if not assembly_r.nil?
          assembly_r = Float(assembly_r)
        else
          assembly_r = FloorConstructions.get_default_ceiling_ufactor(@iecc_zone_2006)
        end
        constr_sets = [
          WoodStudConstructionSet.new(Material.Stud2x6, 0.11, 0.0, 0.0, drywall_thick_in, nil), # 2x6, 24" o.c.
          WoodStudConstructionSet.new(Material.Stud2x4, 0.24, 0.0, 0.0, drywall_thick_in, nil), # 2x4, 16" o.c.
          WoodStudConstructionSet.new(Material.Stud2x4, 0.01, 0.0, 0.0, 0.0, nil),              # Fallback
        ]

        constr_set, ceiling_r = pick_wood_stud_construction_set(assembly_r, constr_sets, film_r, "attic floor #{floor_id}")
        ceiling_joist_height_in = constr_set.stud.thick_in
        ceiling_ins_thick_in = ceiling_joist_height_in
        ceiling_framing_factor = constr_set.framing_factor
        ceiling_drywall_thick_in = constr_set.drywall_thick_in
        ceiling_install_grade = 1

        success = FloorConstructions.apply_unfinished_attic(runner, model, [surface],
                                                            "FloorConstruction",
                                                            ceiling_r, ceiling_install_grade,
                                                            ceiling_ins_thick_in,
                                                            ceiling_framing_factor,
                                                            ceiling_joist_height_in,
                                                            ceiling_drywall_thick_in)
        return false if not success

        check_surface_assembly_rvalue(surface, film_r, assembly_r)
      end

      # Attic roofs
      attic.elements.each("Roofs/Roof") do |roof|
        roof_id = roof.elements["SystemIdentifier"].attributes["id"]

        roof_gross_area = Float(XMLHelper.get_value(roof, "Area"))
        roof_net_area = net_wall_area(roof_gross_area, subsurface_areas, roof_id)
        if roof_net_area <= 0
          fail "Calculated a negative net surface area for Roof '#{roof_id}'."
        end

        roof_width = Math::sqrt(roof_net_area)
        roof_length = roof_net_area / roof_width
        roof_tilt = Float(XMLHelper.get_value(roof, "Pitch")) / 12.0
        z_origin = walls_top + 0.5 * Math.sin(Math.atan(roof_tilt)) * roof_width
        roof_azimuth = XMLHelper.get_value(roof, "Azimuth")
        if not roof_azimuth.nil?
          roof_azimuth = Float(roof_azimuth)
        else
          roof_azimuth = 0.0 # TODO
        end

        surface = OpenStudio::Model::Surface.new(add_roof_polygon(roof_length, roof_width, z_origin,
                                                                  roof_azimuth, roof_tilt), model)

        surface.additionalProperties.setFeature("Length", roof_length)
        surface.additionalProperties.setFeature("Width", roof_width)
        surface.additionalProperties.setFeature("Tilt", roof_tilt)
        surface.additionalProperties.setFeature("Azimuth", roof_azimuth)
        surface.setName(roof_id)
        surface.setSurfaceType("RoofCeiling")
        surface.setOutsideBoundaryCondition("Outdoors")
        set_surface_interior(model, spaces, surface, roof_id, interior_adjacent_to)

        # Apply construction
        if is_external_thermal_boundary(interior_adjacent_to, "outside")
          drywall_thick_in = 0.5
        else
          drywall_thick_in = 0.0
        end
        film_r = Material.AirFilmOutside.rvalue + Material.AirFilmRoof(Geometry.get_roof_pitch([surface])).rvalue
        mat_roofing = Material.RoofingAsphaltShinglesDark
        solar_abs = Float(XMLHelper.get_value(roof, "SolarAbsorptance"))
        emitt = Float(XMLHelper.get_value(roof, "Emittance"))

        assembly_r = Float(XMLHelper.get_value(roof, "Insulation/AssemblyEffectiveRValue"))
        constr_sets = [
          WoodStudConstructionSet.new(Material.Stud2x(8.0), 0.07, 10.0, 0.75, drywall_thick_in, mat_roofing), # 2x8, 24" o.c. + R10
          WoodStudConstructionSet.new(Material.Stud2x(8.0), 0.07, 5.0, 0.75, drywall_thick_in, mat_roofing),  # 2x8, 24" o.c. + R5
          WoodStudConstructionSet.new(Material.Stud2x(8.0), 0.07, 0.0, 0.75, drywall_thick_in, mat_roofing),  # 2x8, 24" o.c.
          WoodStudConstructionSet.new(Material.Stud2x6, 0.07, 0.0, 0.75, drywall_thick_in, mat_roofing),      # 2x6, 24" o.c.
          WoodStudConstructionSet.new(Material.Stud2x4, 0.07, 0.0, 0.5, drywall_thick_in, mat_roofing),       # 2x4, 16" o.c.
          WoodStudConstructionSet.new(Material.Stud2x4, 0.01, 0.0, 0.0, 0.0, mat_roofing),                    # Fallback
        ]
        constr_set, roof_cavity_r = pick_wood_stud_construction_set(assembly_r, constr_sets, film_r, "attic roof #{roof_id}")

        roof_install_grade = 1

        if drywall_thick_in > 0
          success = RoofConstructions.apply_finished_roof(runner, model, [surface],
                                                          "RoofConstruction",
                                                          roof_cavity_r, roof_install_grade,
                                                          constr_set.stud.thick_in,
                                                          true, constr_set.framing_factor,
                                                          constr_set.drywall_thick_in,
                                                          constr_set.osb_thick_in, constr_set.rigid_r,
                                                          constr_set.exterior_material)
        else
          has_radiant_barrier = false # TODO
          success = RoofConstructions.apply_unfinished_attic(runner, model, [surface],
                                                             "RoofConstruction",
                                                             roof_cavity_r, roof_install_grade,
                                                             constr_set.stud.thick_in,
                                                             constr_set.framing_factor,
                                                             constr_set.stud.thick_in,
                                                             constr_set.osb_thick_in, constr_set.rigid_r,
                                                             constr_set.exterior_material, has_radiant_barrier)
          return false if not success
        end

        check_surface_assembly_rvalue(surface, film_r, assembly_r)

        apply_solar_abs_emittance_to_construction(surface, solar_abs, emitt)
      end

      # Attic walls
      attic.elements.each("Walls/Wall") do |wall|
        exterior_adjacent_to = XMLHelper.get_value(wall, "AdjacentTo")

        wall_id = wall.elements["SystemIdentifier"].attributes["id"]

        wall_gross_area = Float(XMLHelper.get_value(wall, "Area"))
        wall_net_area = net_wall_area(wall_gross_area, subsurface_areas, wall_id)
        if wall_net_area <= 0
          fail "Calculated a negative net surface area for Wall '#{wall_id}'."
        end

        wall_height = 8.0
        wall_length = wall_net_area / wall_height
        z_origin = walls_top
        wall_azimuth = XMLHelper.get_value(wall, "Azimuth")
        if not wall_azimuth.nil?
          wall_azimuth = Float(wall_azimuth)
        else
          wall_azimuth = 0.0 # TODO
        end

        surface = OpenStudio::Model::Surface.new(add_wall_polygon(wall_length, wall_height, z_origin,
                                                                  wall_azimuth), model)

        surface.additionalProperties.setFeature("Length", wall_length)
        surface.additionalProperties.setFeature("Azimuth", wall_azimuth)
        surface.setName(wall_id)
        surface.setSurfaceType("Wall")
        set_surface_interior(model, spaces, surface, wall_id, interior_adjacent_to)
        set_surface_exterior(model, spaces, surface, wall_id, exterior_adjacent_to)
        if exterior_adjacent_to != "outside"
          surface.setSunExposure("NoSun")
          surface.setWindExposure("NoWind")
        end

        # Apply construction

        if is_external_thermal_boundary(interior_adjacent_to, exterior_adjacent_to)
          drywall_thick_in = 0.5
        else
          drywall_thick_in = 0.0
        end
        if exterior_adjacent_to == "outside"
          film_r = Material.AirFilmVertical.rvalue + Material.AirFilmOutside.rvalue
          mat_ext_finish = Material.ExtFinishWoodLight
        else
          film_r = 2.0 * Material.AirFilmVertical.rvalue
          mat_ext_finish = nil
        end
        solar_abs = Float(XMLHelper.get_value(wall, "SolarAbsorptance"))
        emitt = Float(XMLHelper.get_value(wall, "Emittance"))
        wall_type = XMLHelper.get_child_name(wall, "WallType")
        assembly_r = Float(XMLHelper.get_value(wall, "Insulation/AssemblyEffectiveRValue"))

        apply_wall_construction(runner, model, surface, wall_id, wall_type, assembly_r,
                                drywall_thick_in, film_r, mat_ext_finish, solar_abs, emitt)
      end
    end

    return true
  end

  def self.add_windows(runner, model, building, spaces, subsurface_areas, weather, cooling_season)
    foundation_top = get_foundation_top(model)

    surfaces = []
    building.elements.each("BuildingDetails/Enclosure/Windows/Window") do |window|
      window_id = window.elements["SystemIdentifier"].attributes["id"]

      window_height = 4.0 # ft, default
      overhang_depth = nil
      if not window.elements["Overhangs"].nil?
        overhang_depth = Float(XMLHelper.get_value(window, "Overhangs/Depth"))
        overhang_distance_to_top = Float(XMLHelper.get_value(window, "Overhangs/DistanceToTopOfWindow"))
        overhang_distance_to_bottom = Float(XMLHelper.get_value(window, "Overhangs/DistanceToBottomOfWindow"))
        window_height = overhang_distance_to_bottom - overhang_distance_to_top
      end

      window_area = Float(XMLHelper.get_value(window, "Area"))
      window_width = window_area / window_height
      z_origin = foundation_top
      window_azimuth = Float(XMLHelper.get_value(window, "Azimuth"))

      surface = OpenStudio::Model::Surface.new(add_wall_polygon(window_width, window_height, z_origin,
                                                                window_azimuth, [0, 0.001, 0.001 * 2, 0.001]), model) # offsets B, L, T, R

      surface.additionalProperties.setFeature("Length", window_width)
      surface.additionalProperties.setFeature("Azimuth", window_azimuth)
      surface.setName("surface #{window_id}")
      surface.setSurfaceType("Wall")
      surface_space = nil
      building.elements.each("BuildingDetails/Enclosure/Walls/Wall") do |wall|
        next unless wall.elements["SystemIdentifier"].attributes["id"] == window.elements["AttachedToWall"].attributes["idref"]

        interior_adjacent_to = XMLHelper.get_value(wall, "InteriorAdjacentTo")
        set_surface_interior(model, spaces, surface, window_id, interior_adjacent_to)
      end
      if not surface.space.is_initialized
        fail "Attached wall '#{window.elements['AttachedToWall'].attributes['idref']}' not found for window '#{window_id}'."
      end

      surface.setOutsideBoundaryCondition("Outdoors") # cannot be adiabatic or OS won't create subsurface
      surfaces << surface

      sub_surface = OpenStudio::Model::SubSurface.new(add_wall_polygon(window_width, window_height, z_origin,
                                                                       window_azimuth, [-0.001, 0, 0.001, 0]), model) # offsets B, L, T, R
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
      ufactor = Float(XMLHelper.get_value(window, "UFactor"))
      shgc = Float(XMLHelper.get_value(window, "SHGC"))
      default_shade_summer, default_shade_winter = SubsurfaceConstructions.get_default_interior_shading_factors()
      cool_shade_mult = XMLHelper.get_value(window, "extension/InteriorShadingFactorSummer")
      if cool_shade_mult.nil?
        cool_shade_mult = default_shade_summer
      else
        cool_shade_mult = Float(cool_shade_mult)
      end
      heat_shade_mult = XMLHelper.get_value(window, "extension/InteriorShadingFactorWinter")
      if heat_shade_mult.nil?
        heat_shade_mult = default_shade_winter
      else
        heat_shade_mult = Float(heat_shade_mult)
      end
      success = SubsurfaceConstructions.apply_window(runner, model, [sub_surface],
                                                     "WindowConstruction",
                                                     weather, cooling_season, ufactor, shgc,
                                                     heat_shade_mult, cool_shade_mult)
      return false if not success
    end

    success = apply_adiabatic_construction(runner, model, surfaces, "wall")
    return false if not success

    return true
  end

  def self.add_skylights(runner, model, building, spaces, subsurface_areas, weather, cooling_season)
    walls_top = get_walls_top(model)

    surfaces = []
    building.elements.each("BuildingDetails/Enclosure/Skylights/Skylight") do |skylight|
      skylight_id = skylight.elements["SystemIdentifier"].attributes["id"]

      # Obtain skylight tilt from attached roof
      skylight_tilt = nil
      building.elements.each("BuildingDetails/Enclosure/Attics/Attic") do |attic|
        attic_type = XMLHelper.get_value(attic, "AtticType")
        attic.elements.each("Roofs/Roof") do |roof|
          next unless roof.elements["SystemIdentifier"].attributes["id"] == skylight.elements["AttachedToRoof"].attributes["idref"]

          skylight_tilt = Float(XMLHelper.get_value(roof, "Pitch")) / 12.0
        end
      end
      if skylight_tilt.nil?
        fail "Attached roof '#{skylight.elements['AttachedToRoof'].attributes['idref']}' not found for skylight '#{skylight_id}'."
      end

      skylight_area = Float(XMLHelper.get_value(skylight, "Area"))
      skylight_height = Math::sqrt(skylight_area)
      skylight_width = skylight_area / skylight_height
      z_origin = walls_top + 0.5 * Math.sin(Math.atan(skylight_tilt)) * skylight_height
      skylight_azimuth = Float(XMLHelper.get_value(skylight, "Azimuth"))

      surface = OpenStudio::Model::Surface.new(add_roof_polygon(skylight_width + 0.001, skylight_height + 0.001, z_origin,
                                                                skylight_azimuth, skylight_tilt), model) # base surface must be at least slightly larger than subsurface

      surface.additionalProperties.setFeature("Length", skylight_width)
      surface.additionalProperties.setFeature("Width", skylight_height)
      surface.additionalProperties.setFeature("Tilt", skylight_tilt)
      surface.additionalProperties.setFeature("Azimuth", skylight_azimuth)
      surface.setName("surface #{skylight_id}")
      surface.setSurfaceType("RoofCeiling")
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeLiving)) # Ensures it is included in Manual J sizing
      surface.setOutsideBoundaryCondition("Outdoors") # cannot be adiabatic or OS won't create subsurface
      surfaces << surface

      sub_surface = OpenStudio::Model::SubSurface.new(add_roof_polygon(skylight_width, skylight_height, z_origin,
                                                                       skylight_azimuth, skylight_tilt), model)
      sub_surface.setName(skylight_id)
      sub_surface.setSurface(surface)
      sub_surface.setSubSurfaceType("Skylight")

      # Apply construction
      ufactor = Float(XMLHelper.get_value(skylight, "UFactor"))
      shgc = Float(XMLHelper.get_value(skylight, "SHGC"))
      cool_shade_mult = 1.0
      heat_shade_mult = 1.0
      success = SubsurfaceConstructions.apply_skylight(runner, model, [sub_surface],
                                                       "SkylightConstruction",
                                                       weather, cooling_season, ufactor, shgc,
                                                       heat_shade_mult, cool_shade_mult)
      return false if not success
    end

    success = apply_adiabatic_construction(runner, model, surfaces, "roof")
    return false if not success

    return true
  end

  def self.add_doors(runner, model, building, spaces, subsurface_areas)
    foundation_top = get_foundation_top(model)

    surfaces = []
    building.elements.each("BuildingDetails/Enclosure/Doors/Door") do |door|
      door_id = door.elements["SystemIdentifier"].attributes["id"]

      door_area = XMLHelper.get_value(door, "Area")
      if not door_area.nil?
        door_area = Float(door_area)
      else
        door_area = SubsurfaceConstructions.get_default_door_area()
      end

      door_height = 6.67 # ft
      door_width = door_area / door_height
      z_origin = foundation_top
      door_azimuth = Float(XMLHelper.get_value(door, "Azimuth"))

      surface = OpenStudio::Model::Surface.new(add_wall_polygon(door_width, door_height, z_origin,
                                                                door_azimuth, [0, 0.001, 0.001, 0.001]), model) # offsets B, L, T, R

      surface.additionalProperties.setFeature("Length", door_width)
      surface.additionalProperties.setFeature("Azimuth", door_azimuth)
      surface.setName("surface #{door_id}")
      surface.setSurfaceType("Wall")
      surface_space = nil
      building.elements.each("BuildingDetails/Enclosure/Walls/Wall") do |wall|
        next unless wall.elements["SystemIdentifier"].attributes["id"] == door.elements["AttachedToWall"].attributes["idref"]

        interior_adjacent_to = XMLHelper.get_value(wall, "InteriorAdjacentTo")
        set_surface_interior(model, spaces, surface, door_id, interior_adjacent_to)
      end
      if not surface.space.is_initialized
        fail "Attached wall '#{door.elements['AttachedToWall'].attributes['idref']}' not found for door '#{door_id}'."
      end

      surface.setOutsideBoundaryCondition("Outdoors") # cannot be adiabatic or OS won't create subsurface
      surfaces << surface

      sub_surface = OpenStudio::Model::SubSurface.new(add_wall_polygon(door_width, door_height, z_origin,
                                                                       door_azimuth, [0, 0, 0, 0]), model) # offsets B, L, T, R
      sub_surface.setName(door_id)
      sub_surface.setSurface(surface)
      sub_surface.setSubSurfaceType("Door")

      # Apply construction
      name = door.elements["SystemIdentifier"].attributes["id"]
      rvalue = XMLHelper.get_value(door, "RValue")
      if not rvalue.nil?
        ufactor = 1.0 / Float(rvalue)
      else
        ufactor, shgc = SubsurfaceConstructions.get_default_ufactor_shgc(@iecc_zone_2006)
      end

      success = SubsurfaceConstructions.apply_door(runner, model, [sub_surface], "Door", ufactor)
      return false if not success
    end

    success = apply_adiabatic_construction(runner, model, surfaces, "wall")
    return false if not success

    return true
  end

  def self.apply_adiabatic_construction(runner, model, surfaces, type)
    # Arbitrary constructions, only heat capacitance matters
    # Used for surfaces that solely contain subsurfaces (windows, doors, skylights)

    if type == "wall"

      framing_factor = Constants.DefaultFramingFactorInterior
      cavity_r = 0.0
      install_grade = 1
      cavity_depth_in = 3.5
      cavity_filled = false
      rigid_r = 0.0
      drywall_thick_in = 0.5
      mat_ext_finish = Material.ExtFinishStuccoMedDark
      success = WallConstructions.apply_wood_stud(runner, model, surfaces,
                                                  "AdiabaticWallConstruction",
                                                  cavity_r, install_grade, cavity_depth_in,
                                                  cavity_filled, framing_factor,
                                                  drywall_thick_in, 0, rigid_r, mat_ext_finish)
      return false if not success

    elsif type == "floor"

      plywood_thick_in = 0.75
      drywall_thick_in = 0.0
      mat_floor_covering = Material.FloorWood
      mat_carpet = Material.CoveringBare
      success = FloorConstructions.apply_uninsulated(runner, model, surfaces,
                                                     "AdiabaticFloorConstruction",
                                                     plywood_thick_in, drywall_thick_in,
                                                     mat_floor_covering, mat_carpet)
      return false if not success

    elsif type == "roof"

      framing_thick_in = 7.25
      framing_factor = 0.07
      osb_thick_in = 0.75
      mat_roofing = Material.RoofingAsphaltShinglesMed
      success = RoofConstructions.apply_uninsulated_roofs(runner, model, surfaces,
                                                          "AdiabaticRoofConstruction",
                                                          framing_thick_in, framing_factor,
                                                          osb_thick_in, mat_roofing)
      return false if not success

    end

    return true
  end

  def self.add_hot_water_and_appliances(runner, model, building, unit, weather, spaces, loop_dhws)
    wh = building.elements["BuildingDetails/Systems/WaterHeating"]

    # Clothes Washer
    cw = building.elements["BuildingDetails/Appliances/ClothesWasher"]
    if not cw.nil?
      cw_location = XMLHelper.get_value(cw, "Location")
      cw_space = get_space_from_location(cw_location, "ClothesWasher", model, spaces)
      cw_mef = XMLHelper.get_value(cw, "ModifiedEnergyFactor")
      cw_imef = XMLHelper.get_value(cw, "IntegratedModifiedEnergyFactor")
      if cw_mef.nil? and cw_imef.nil?
        cw_mef = HotWaterAndAppliances.get_clothes_washer_reference_mef()
        cw_ler = HotWaterAndAppliances.get_clothes_washer_reference_ler()
        cw_elec_rate = HotWaterAndAppliances.get_clothes_washer_reference_elec_rate()
        cw_gas_rate = HotWaterAndAppliances.get_clothes_washer_reference_gas_rate()
        cw_agc = HotWaterAndAppliances.get_clothes_washer_reference_agc()
        cw_cap = HotWaterAndAppliances.get_clothes_washer_reference_cap()
      else
        if not cw_mef.nil?
          cw_mef = Float(cw_mef)
        elsif not cw_imef.nil?
          cw_mef = HotWaterAndAppliances.calc_clothes_washer_mef_from_imef(Float(cw_imef))
        end
        cw_ler = Float(XMLHelper.get_value(cw, "RatedAnnualkWh"))
        cw_elec_rate = Float(XMLHelper.get_value(cw, "LabelElectricRate"))
        cw_gas_rate = Float(XMLHelper.get_value(cw, "LabelGasRate"))
        cw_agc = Float(XMLHelper.get_value(cw, "LabelAnnualGasCost"))
        cw_cap = Float(XMLHelper.get_value(cw, "Capacity"))
      end
    else
      cw_mef = cw_ler = cw_elec_rate = cw_gas_rate = cw_agc = cw_cap = nil
    end

    # Clothes Dryer
    cd = building.elements["BuildingDetails/Appliances/ClothesDryer"]
    if not cd.nil?
      cd_location = XMLHelper.get_value(cd, "Location")
      cd_space = get_space_from_location(cd_location, "ClothesDryer", model, spaces)
      cd_fuel = to_beopt_fuel(XMLHelper.get_value(cd, "FuelType"))
      cd_ef = XMLHelper.get_value(cd, "EnergyFactor")
      cd_cef = XMLHelper.get_value(cd, "CombinedEnergyFactor")
      if cd_ef.nil? and cd_cef.nil?
        cd_ef = HotWaterAndAppliances.get_clothes_dryer_reference_ef(cd_fuel)
        cd_control = HotWaterAndAppliances.get_clothes_dryer_reference_control()
      else
        if not cd_ef.nil?
          cd_ef = Float(cd_ef)
        elsif not cd_cef.nil?
          cd_ef = HotWaterAndAppliances.calc_clothes_dryer_ef_from_cef(Float(cd_cef))
        end
        cd_control = XMLHelper.get_value(cd, "ControlType")
      end
    else
      cd_ef = cd_control = cd_fuel = nil
    end

    # Dishwasher
    dw = building.elements["BuildingDetails/Appliances/Dishwasher"]
    if not dw.nil?
      dw_ef = XMLHelper.get_value(dw, "EnergyFactor")
      dw_annual_kwh = XMLHelper.get_value(dw, "RatedAnnualkWh")
      if dw_ef.nil? and dw_annual_kwh.nil?
        dw_ef = HotWaterAndAppliances.get_dishwasher_reference_ef()
        dw_cap = HotWaterAndAppliances.get_dishwasher_reference_cap()
      else
        if not dw_ef.nil?
          dw_ef = Float(dw_ef)
        elsif not dw_annual_kwh.nil?
          dw_ef = HotWaterAndAppliances.calc_dishwasher_ef_from_annual_kwh(Float(dw_annual_kwh))
        end
        dw_cap = Float(XMLHelper.get_value(dw, "PlaceSettingCapacity"))
      end
    else
      dw_ef = dw_cap = nil
    end

    # Refrigerator
    fridge = building.elements["BuildingDetails/Appliances/Refrigerator"]
    if not fridge.nil?
      fridge_location = XMLHelper.get_value(fridge, "Location")
      fridge_space = get_space_from_location(fridge_location, "Refrigerator", model, spaces)
      fridge_annual_kwh = XMLHelper.get_value(fridge, "RatedAnnualkWh")
      if fridge_annual_kwh.nil?
        fridge_annual_kwh = HotWaterAndAppliances.get_refrigerator_reference_annual_kwh(@nbeds)
      else
        fridge_annual_kwh = Float(fridge_annual_kwh)
      end
    else
      fridge_annual_kwh = nil
    end

    # Cooking Range/Oven
    cook = building.elements["BuildingDetails/Appliances/CookingRange"]
    oven = building.elements["BuildingDetails/Appliances/Oven"]
    if not cook.nil? and not oven.nil?
      cook_fuel_type = to_beopt_fuel(XMLHelper.get_value(cook, "FuelType"))
      cook_is_induction = XMLHelper.get_value(cook, "IsInduction")
      if cook_is_induction.nil?
        cook_is_induction = HotWaterAndAppliances.get_range_oven_reference_is_induction()
        oven_is_convection = HotWaterAndAppliances.get_range_oven_reference_is_convection()
      else
        cook_is_induction = Boolean(cook_is_induction)
        oven_is_convection = Boolean(XMLHelper.get_value(oven, "IsConvection"))
      end
    else
      cook_fuel_type = cook_is_induction = oven_is_convection = nil
    end

    # Fixtures
    has_low_flow_fixtures = false
    if not wh.nil?
      low_flow_fixtures_list = []
      wh.elements.each("WaterFixture[WaterFixtureType='shower head' or WaterFixtureType='faucet']") do |wf|
        low_flow_fixtures_list << Boolean(XMLHelper.get_value(wf, "LowFlow"))
      end
      low_flow_fixtures_list.uniq!
      if low_flow_fixtures_list.size == 1 and low_flow_fixtures_list[0]
        has_low_flow_fixtures = true
      end
    end

    # Distribution
    if not wh.nil?
      dist = wh.elements["HotWaterDistribution"]
      dist_type = XMLHelper.get_child_name(dist, "SystemType").downcase
      if dist_type == "standard"
        std_pipe_length = XMLHelper.get_value(dist, "SystemType/Standard/PipingLength")
        if std_pipe_length.nil?
          std_pipe_length = HotWaterAndAppliances.get_default_std_pipe_length(@has_uncond_bsmnt, @cfa, @ncfl)
        else
          std_pipe_length = Float(std_pipe_length)
        end
        recirc_loop_length = nil
        recirc_branch_length = nil
        recirc_control_type = nil
        recirc_pump_power = nil
      elsif dist_type == "recirculation"
        recirc_loop_length = XMLHelper.get_value(dist, "SystemType/Recirculation/RecirculationPipingLoopLength")
        if recirc_loop_length.nil?
          std_pipe_length = HotWaterAndAppliances.get_default_std_pipe_length(@has_uncond_bsmnt, @cfa, @ncfl)
          recirc_loop_length = HotWaterAndAppliances.get_default_recirc_loop_length(std_pipe_length)
        else
          recirc_loop_length = Float(recirc_loop_length)
        end
        recirc_branch_length = Float(XMLHelper.get_value(dist, "SystemType/Recirculation/BranchPipingLoopLength"))
        recirc_control_type = XMLHelper.get_value(dist, "SystemType/Recirculation/ControlType")
        recirc_pump_power = Float(XMLHelper.get_value(dist, "SystemType/Recirculation/PumpPower"))
        std_pipe_length = nil
      end
      pipe_r = Float(XMLHelper.get_value(dist, "PipeInsulation/PipeRValue"))
    end

    # Drain Water Heat Recovery
    dwhr_present = false
    dwhr_facilities_connected = nil
    dwhr_is_equal_flow = nil
    dwhr_efficiency = nil
    if not wh.nil?
      if XMLHelper.has_element(dist, "DrainWaterHeatRecovery")
        dwhr_present = true
        dwhr_facilities_connected = XMLHelper.get_value(dist, "DrainWaterHeatRecovery/FacilitiesConnected")
        dwhr_is_equal_flow = Boolean(XMLHelper.get_value(dist, "DrainWaterHeatRecovery/EqualFlow"))
        dwhr_efficiency = Float(XMLHelper.get_value(dist, "DrainWaterHeatRecovery/Efficiency"))
      end
    end

    # Water Heater
    dhw_loop_fracs = {}
    if not wh.nil?
      wh.elements.each("WaterHeatingSystem") do |dhw|
        orig_plant_loops = model.getPlantLoops

        location = XMLHelper.get_value(dhw, "Location")
        space = get_space_from_location(location, "WaterHeatingSystem", model, spaces)
        setpoint_temp = Waterheater.get_default_hot_water_temperature(@eri_version)
        wh_type = XMLHelper.get_value(dhw, "WaterHeaterType")
        fuel = XMLHelper.get_value(dhw, "FuelType")

        ef = XMLHelper.get_value(dhw, "EnergyFactor")
        if ef.nil?
          uef = Float(XMLHelper.get_value(dhw, "UniformEnergyFactor"))
          ef = Waterheater.calc_ef_from_uef(uef, to_beopt_wh_type(wh_type), to_beopt_fuel(fuel))
        else
          ef = Float(ef)
        end
        ef_adj = XMLHelper.get_value(dhw, "extension/EnergyFactorMultiplier")
        if ef_adj.nil?
          ef_adj = Waterheater.get_ef_multiplier(to_beopt_wh_type(wh_type))
        else
          ef_adj = Float(ef_adj)
        end
        ec_adj = HotWaterAndAppliances.get_dist_energy_consumption_adjustment(@has_uncond_bsmnt, @cfa, @ncfl,
                                                                              dist_type, recirc_control_type,
                                                                              pipe_r, std_pipe_length, recirc_loop_length)

        dhw_load_frac = Float(XMLHelper.get_value(dhw, "FractionDHWLoadServed"))

        if wh_type == "storage water heater"

          tank_vol = Float(XMLHelper.get_value(dhw, "TankVolume"))
          if fuel != "electricity"
            re = Float(XMLHelper.get_value(dhw, "RecoveryEfficiency"))
          else
            re = 0.98
          end
          capacity_kbtuh = Float(XMLHelper.get_value(dhw, "HeatingCapacity")) / 1000.0
          oncycle_power = 0.0
          offcycle_power = 0.0
          success = Waterheater.apply_tank(model, unit, runner, nil, space, to_beopt_fuel(fuel),
                                           capacity_kbtuh, tank_vol, ef * ef_adj, re, setpoint_temp,
                                           oncycle_power, offcycle_power, ec_adj)
          return false if not success

        elsif wh_type == "instantaneous water heater"

          capacity_kbtuh = 100000000.0
          oncycle_power = 0.0
          offcycle_power = 0.0
          cycling_derate = 1.0 - ef_adj
          success = Waterheater.apply_tankless(model, unit, runner, nil, space, to_beopt_fuel(fuel),
                                               capacity_kbtuh, ef, cycling_derate,
                                               setpoint_temp, oncycle_power, offcycle_power, ec_adj)
          return false if not success

        elsif wh_type == "heat pump water heater"

          tank_vol = Float(XMLHelper.get_value(dhw, "TankVolume"))
          e_cap = 4.5 # FIXME
          min_temp = 45.0 # FIXME
          max_temp = 120.0 # FIXME
          cap = 0.5 # FIXME
          cop = 2.8 # FIXME
          shr = 0.88 # FIXME
          airflow_rate = 181.0 # FIXME
          fan_power = 0.0462 # FIXME
          parasitics = 3.0 # FIXME
          tank_ua = 3.9 # FIXME
          int_factor = 1.0 # FIXME
          temp_depress = 0.0 # FIXME
          ducting = "none"
          # FIXME: Use ef, ef_adj, ec_adj
          success = Waterheater.apply_heatpump(model, unit, runner, nil, space, weather,
                                               e_cap, tank_vol, setpoint_temp, min_temp, max_temp,
                                               cap, cop, shr, airflow_rate, fan_power,
                                               parasitics, tank_ua, int_factor, temp_depress,
                                               ducting, 0)
          return false if not success

        else

          fail "Unhandled water heater (#{wh_type})."

        end

        new_plant_loop = (model.getPlantLoops - orig_plant_loops)[0]
        dhw_loop_fracs[new_plant_loop] = dhw_load_frac

        update_loop_dhws(loop_dhws, model, dhw, orig_plant_loops)
      end
    end

    success = HotWaterAndAppliances.apply(model, unit, runner, weather,
                                          @cfa, @nbeds, @ncfl, @has_uncond_bsmnt,
                                          cw_mef, cw_ler, cw_elec_rate, cw_gas_rate,
                                          cw_agc, cw_cap, cw_space, cd_fuel, cd_ef, cd_control,
                                          cd_space, dw_ef, dw_cap, fridge_annual_kwh, fridge_space,
                                          cook_fuel_type, cook_is_induction, oven_is_convection,
                                          has_low_flow_fixtures, dist_type, pipe_r,
                                          std_pipe_length, recirc_loop_length,
                                          recirc_branch_length, recirc_control_type,
                                          recirc_pump_power, dwhr_present,
                                          dwhr_facilities_connected, dwhr_is_equal_flow,
                                          dwhr_efficiency, dhw_loop_fracs, @eri_version)
    return false if not success

    return true
  end

  def self.add_cooling_system(runner, model, building, unit, loop_hvacs, zone_hvacs, use_only_ideal_air)
    return true if use_only_ideal_air

    building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem") do |clgsys|
      clg_type = XMLHelper.get_value(clgsys, "CoolingSystemType")

      cool_capacity_btuh = Float(XMLHelper.get_value(clgsys, "CoolingCapacity"))
      if cool_capacity_btuh <= 0.0
        cool_capacity_btuh = Constants.SizingAuto
      end

      load_frac = Float(XMLHelper.get_value(clgsys, "FractionCoolLoadServed"))

      dse_heat, dse_cool, has_dse = get_dse(building, clgsys)

      orig_air_loops = model.getAirLoopHVACs
      orig_plant_loops = model.getPlantLoops
      orig_zone_hvacs = get_zone_hvacs(model)

      if clg_type == "central air conditioning"

        # FIXME: Generalize
        seer = Float(XMLHelper.get_value(clgsys, "AnnualCoolingEfficiency[Units='SEER']/Value"))
        num_speeds = get_ac_num_speeds(seer)
        crankcase_kw = 0.0
        crankcase_temp = 55.0

        if num_speeds == "1-Speed"

          eers = [0.82 * seer + 0.64]
          shrs = [0.73]
          fan_power_rated = 0.365
          fan_power_installed = 0.5
          eer_capacity_derates = [1.0, 1.0, 1.0, 1.0, 1.0]
          success = HVAC.apply_central_ac_1speed(model, unit, runner, seer, eers, shrs,
                                                 fan_power_rated, fan_power_installed,
                                                 crankcase_kw, crankcase_temp,
                                                 eer_capacity_derates, cool_capacity_btuh,
                                                 dse_cool, load_frac)
          return false if not success

        elsif num_speeds == "2-Speed"

          eers = [0.83 * seer + 0.15, 0.56 * seer + 3.57]
          shrs = [0.71, 0.73]
          capacity_ratios = [0.72, 1.0]
          fan_speed_ratios = [0.86, 1.0]
          fan_power_rated = 0.14
          fan_power_installed = 0.3
          eer_capacity_derates = [1.0, 1.0, 1.0, 1.0, 1.0]
          success = HVAC.apply_central_ac_2speed(model, unit, runner, seer, eers, shrs,
                                                 capacity_ratios, fan_speed_ratios,
                                                 fan_power_rated, fan_power_installed,
                                                 crankcase_kw, crankcase_temp,
                                                 eer_capacity_derates, cool_capacity_btuh,
                                                 dse_cool, load_frac)
          return false if not success

        elsif num_speeds == "Variable-Speed"

          eers = [0.80 * seer, 0.75 * seer, 0.65 * seer, 0.60 * seer]
          shrs = [0.98, 0.82, 0.745, 0.77]
          capacity_ratios = [0.36, 0.64, 1.0, 1.16]
          fan_speed_ratios = [0.51, 0.84, 1.0, 1.19]
          fan_power_rated = 0.14
          fan_power_installed = 0.3
          eer_capacity_derates = [1.0, 1.0, 1.0, 1.0, 1.0]
          success = HVAC.apply_central_ac_4speed(model, unit, runner, seer, eers, shrs,
                                                 capacity_ratios, fan_speed_ratios,
                                                 fan_power_rated, fan_power_installed,
                                                 crankcase_kw, crankcase_temp,
                                                 eer_capacity_derates, cool_capacity_btuh,
                                                 dse_cool, load_frac)
          return false if not success

        else

          fail "Unexpected number of speeds (#{num_speeds}) for cooling system."

        end

      elsif clg_type == "room air conditioner"

        eer = Float(XMLHelper.get_value(clgsys, "AnnualCoolingEfficiency[Units='EER']/Value"))
        shr = 0.65
        airflow_rate = 350.0

        success = HVAC.apply_room_ac(model, unit, runner, eer, shr,
                                     airflow_rate, cool_capacity_btuh, load_frac)
        return false if not success

      end

      update_loop_hvacs(loop_hvacs, zone_hvacs, model, clgsys, orig_air_loops, orig_plant_loops, orig_zone_hvacs)
    end

    return true
  end

  def self.add_heating_system(runner, model, building, unit, loop_hvacs, zone_hvacs, use_only_ideal_air)
    return true if use_only_ideal_air

    building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem") do |htgsys|
      fuel = to_beopt_fuel(XMLHelper.get_value(htgsys, "HeatingSystemFuel"))

      heat_capacity_btuh = Float(XMLHelper.get_value(htgsys, "HeatingCapacity"))
      if heat_capacity_btuh <= 0.0
        heat_capacity_btuh = Constants.SizingAuto
      end
      htg_type = XMLHelper.get_child_name(htgsys, "HeatingSystemType")

      load_frac = Float(XMLHelper.get_value(htgsys, "FractionHeatLoadServed"))

      dse_heat, dse_cool, has_dse = get_dse(building, htgsys)

      orig_air_loops = model.getAirLoopHVACs
      orig_plant_loops = model.getPlantLoops
      orig_zone_hvacs = get_zone_hvacs(model)

      if htg_type == "Furnace"

        afue = Float(XMLHelper.get_value(htgsys, "AnnualHeatingEfficiency[Units='AFUE']/Value"))
        fan_power = 0.5 # For fuel furnaces, will be overridden by EAE later
        attached_to_multispeed_ac = get_attached_to_multispeed_ac(htgsys, building)
        success = HVAC.apply_furnace(model, unit, runner, fuel, afue,
                                     heat_capacity_btuh, fan_power, dse_heat,
                                     load_frac, attached_to_multispeed_ac)
        return false if not success

      elsif htg_type == "WallFurnace"

        efficiency = Float(XMLHelper.get_value(htgsys, "AnnualHeatingEfficiency[Units='AFUE']/Value"))
        fan_power = 0.0
        airflow_rate = 0.0
        # TODO: Allow DSE
        success = HVAC.apply_unit_heater(model, unit, runner, fuel,
                                         efficiency, heat_capacity_btuh, fan_power,
                                         airflow_rate, load_frac)
        return false if not success

      elsif htg_type == "Boiler"

        system_type = Constants.BoilerTypeForcedDraft
        afue = Float(XMLHelper.get_value(htgsys, "AnnualHeatingEfficiency[Units='AFUE']/Value"))
        oat_reset_enabled = false
        oat_high = nil
        oat_low = nil
        oat_hwst_high = nil
        oat_hwst_low = nil
        design_temp = 180.0
        success = HVAC.apply_boiler(model, unit, runner, fuel, system_type, afue,
                                    oat_reset_enabled, oat_high, oat_low, oat_hwst_high, oat_hwst_low,
                                    heat_capacity_btuh, design_temp, dse_heat, load_frac)
        return false if not success

      elsif htg_type == "ElectricResistance"

        efficiency = Float(XMLHelper.get_value(htgsys, "AnnualHeatingEfficiency[Units='Percent']/Value"))
        # TODO: Allow DSE
        success = HVAC.apply_electric_baseboard(model, unit, runner, efficiency,
                                                heat_capacity_btuh, load_frac)
        return false if not success

      elsif htg_type == "Stove"

        efficiency = Float(XMLHelper.get_value(htgsys, "AnnualHeatingEfficiency[Units='Percent']/Value"))
        airflow_rate = 125.0 # cfm/ton; doesn't affect energy consumption
        fan_power = 0.5 # For fuel equipment, will be overridden by EAE later
        # TODO: Allow DSE
        success = HVAC.apply_unit_heater(model, unit, runner, fuel,
                                         efficiency, heat_capacity_btuh, fan_power,
                                         airflow_rate, load_frac)
        return false if not success

      end

      update_loop_hvacs(loop_hvacs, zone_hvacs, model, htgsys, orig_air_loops, orig_plant_loops, orig_zone_hvacs)
    end

    return true
  end

  def self.add_heat_pump(runner, model, building, unit, weather, loop_hvacs, zone_hvacs, use_only_ideal_air)
    return true if use_only_ideal_air

    building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/HeatPump") do |hp|
      hp_type = XMLHelper.get_value(hp, "HeatPumpType")

      cool_capacity_btuh = XMLHelper.get_value(hp, "CoolingCapacity")
      if cool_capacity_btuh.nil?
        cool_capacity_btuh = Constants.SizingAuto
      else
        cool_capacity_btuh = Float(cool_capacity_btuh)
      end

      load_frac_heat = Float(XMLHelper.get_value(hp, "FractionHeatLoadServed"))
      load_frac_cool = Float(XMLHelper.get_value(hp, "FractionCoolLoadServed"))

      backup_heat_capacity_btuh = XMLHelper.get_value(hp, "BackupHeatingCapacity") # TODO: Require in ERI Use Case?
      if backup_heat_capacity_btuh.nil?
        backup_heat_capacity_btuh = Constants.SizingAuto
      else
        backup_heat_capacity_btuh = Float(backup_heat_capacity_btuh)
      end

      dse_heat, dse_cool, has_dse = get_dse(building, hp)
      if dse_heat != dse_cool
        # TODO: Can we remove this since we use separate airloops for
        # heating and cooling?
        fail "Cannot handle different distribution system efficiency (DSE) values for heating and cooling."
      end

      orig_air_loops = model.getAirLoopHVACs
      orig_plant_loops = model.getPlantLoops
      orig_zone_hvacs = get_zone_hvacs(model)

      if hp_type == "air-to-air"

        seer = Float(XMLHelper.get_value(hp, "AnnualCoolingEfficiency[Units='SEER']/Value"))
        hspf = Float(XMLHelper.get_value(hp, "AnnualHeatingEfficiency[Units='HSPF']/Value"))
        num_speeds = get_ashp_num_speeds(seer)

        crankcase_kw = 0.02
        crankcase_temp = 55.0

        if num_speeds == "1-Speed"

          eers = [0.80 * seer + 1.0]
          cops = [0.45 * seer - 0.34]
          shrs = [0.73]
          fan_power_rated = 0.365
          fan_power_installed = 0.5
          min_temp = 0.0
          eer_capacity_derates = [1.0, 1.0, 1.0, 1.0, 1.0]
          cop_capacity_derates = [1.0, 1.0, 1.0, 1.0, 1.0]
          supplemental_efficiency = 1.0
          success = HVAC.apply_central_ashp_1speed(model, unit, runner, seer, hspf, eers, cops, shrs,
                                                   fan_power_rated, fan_power_installed, min_temp,
                                                   crankcase_kw, crankcase_temp,
                                                   eer_capacity_derates, cop_capacity_derates,
                                                   cool_capacity_btuh, supplemental_efficiency,
                                                   backup_heat_capacity_btuh, dse_heat,
                                                   load_frac_heat, load_frac_cool)
          return false if not success

        elsif num_speeds == "2-Speed"

          eers = [0.78 * seer + 0.6, 0.68 * seer + 1.0]
          cops = [0.60 * seer - 1.40, 0.50 * seer - 0.94]
          shrs = [0.71, 0.724]
          capacity_ratios = [0.72, 1.0]
          fan_speed_ratios_cooling = [0.86, 1.0]
          fan_speed_ratios_heating = [0.8, 1.0]
          fan_power_rated = 0.14
          fan_power_installed = 0.3
          min_temp = 0.0
          eer_capacity_derates = [1.0, 1.0, 1.0, 1.0, 1.0]
          cop_capacity_derates = [1.0, 1.0, 1.0, 1.0, 1.0]
          supplemental_efficiency = 1.0
          success = HVAC.apply_central_ashp_2speed(model, unit, runner, seer, hspf, eers, cops, shrs,
                                                   capacity_ratios, fan_speed_ratios_cooling,
                                                   fan_speed_ratios_heating,
                                                   fan_power_rated, fan_power_installed, min_temp,
                                                   crankcase_kw, crankcase_temp,
                                                   eer_capacity_derates, cop_capacity_derates,
                                                   cool_capacity_btuh, supplemental_efficiency,
                                                   backup_heat_capacity_btuh, dse_heat,
                                                   load_frac_heat, load_frac_cool)
          return false if not success

        elsif num_speeds == "Variable-Speed"

          eers = [0.80 * seer, 0.75 * seer, 0.65 * seer, 0.60 * seer]
          cops = [0.48 * seer, 0.45 * seer, 0.39 * seer, 0.39 * seer]
          shrs = [0.84, 0.79, 0.76, 0.77]
          capacity_ratios = [0.49, 0.67, 1.0, 1.2]
          fan_speed_ratios_cooling = [0.7, 0.9, 1.0, 1.26]
          fan_speed_ratios_heating = [0.74, 0.92, 1.0, 1.22]
          fan_power_rated = 0.14
          fan_power_installed = 0.3
          min_temp = 0.0
          eer_capacity_derates = [1.0, 1.0, 1.0, 1.0, 1.0]
          cop_capacity_derates = [1.0, 1.0, 1.0, 1.0, 1.0]
          supplemental_efficiency = 1.0
          success = HVAC.apply_central_ashp_4speed(model, unit, runner, seer, hspf, eers, cops, shrs,
                                                   capacity_ratios, fan_speed_ratios_cooling,
                                                   fan_speed_ratios_heating,
                                                   fan_power_rated, fan_power_installed, min_temp,
                                                   crankcase_kw, crankcase_temp,
                                                   eer_capacity_derates, cop_capacity_derates,
                                                   cool_capacity_btuh, supplemental_efficiency,
                                                   backup_heat_capacity_btuh, dse_heat,
                                                   load_frac_heat, load_frac_cool)
          return false if not success

        else

          fail "Unexpected number of speeds (#{num_speeds}) for heat pump system."

        end

      elsif hp_type == "mini-split"

        # FIXME: Generalize
        seer = Float(XMLHelper.get_value(hp, "AnnualCoolingEfficiency[Units='SEER']/Value"))
        hspf = Float(XMLHelper.get_value(hp, "AnnualHeatingEfficiency[Units='HSPF']/Value"))
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
        supplemental_efficiency = 1.0
        success = HVAC.apply_mshp(model, unit, runner, seer, hspf, shr,
                                  min_cooling_capacity, max_cooling_capacity,
                                  min_cooling_airflow_rate, max_cooling_airflow_rate,
                                  min_heating_capacity, max_heating_capacity,
                                  min_heating_airflow_rate, max_heating_airflow_rate,
                                  heating_capacity_offset, cap_retention_frac,
                                  cap_retention_temp, pan_heater_power, fan_power,
                                  is_ducted, cool_capacity_btuh,
                                  supplemental_efficiency, backup_heat_capacity_btuh,
                                  dse_heat, load_frac_heat, load_frac_cool)
        return false if not success

      elsif hp_type == "ground-to-air"

        # FIXME: Generalize
        cop = Float(XMLHelper.get_value(hp, "AnnualHeatingEfficiency[Units='COP']/Value"))
        eer = Float(XMLHelper.get_value(hp, "AnnualCoolingEfficiency[Units='EER']/Value"))
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
        heat_pump_capacity = cool_capacity_btuh
        supplemental_efficiency = 1
        supplemental_capacity = backup_heat_capacity_btuh
        success = HVAC.apply_gshp(model, unit, runner, weather, cop, eer, shr,
                                  ground_conductivity, grout_conductivity,
                                  bore_config, bore_holes, bore_depth,
                                  bore_spacing, bore_diameter, pipe_size,
                                  ground_diffusivity, fluid_type, frac_glycol,
                                  design_delta_t, pump_head,
                                  u_tube_leg_spacing, u_tube_spacing_type,
                                  fan_power, heat_pump_capacity, supplemental_efficiency,
                                  supplemental_capacity, dse_heat,
                                  load_frac_heat, load_frac_cool)
        return false if not success

      end

      update_loop_hvacs(loop_hvacs, zone_hvacs, model, hp, orig_air_loops, orig_plant_loops, orig_zone_hvacs)
    end

    return true
  end

  def self.add_residual_hvac(runner, model, building, unit, use_only_ideal_air)
    if use_only_ideal_air
      success = HVAC.apply_ideal_air_loads_heating(model, unit, runner, 1)
      return false if not success

      success = HVAC.apply_ideal_air_loads_cooling(model, unit, runner, 1)
      return false if not success

      return true
    end

    # Residual heating
    htg_load_frac = building.elements["sum(BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/FractionHeatLoadServed)"]
    htg_load_frac += building.elements["sum(BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/FractionHeatLoadServed)"]
    residual_htg_load_frac = 1.0 - htg_load_frac
    if residual_htg_load_frac > 0.02 and residual_htg_load_frac < 1 # TODO: Ensure that E+ will re-normalize if == 0.01
      success = HVAC.apply_ideal_air_loads_heating(model, unit, runner, residual_htg_load_frac)
      return false if not success
    end

    # Residual cooling
    clg_load_frac = building.elements["sum(BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem/FractionCoolLoadServed)"]
    clg_load_frac += building.elements["sum(BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/FractionCoolLoadServed)"]
    residual_clg_load_frac = 1.0 - clg_load_frac
    if residual_clg_load_frac > 0.02 and residual_clg_load_frac < 1 # TODO: Ensure that E+ will re-normalize if == 0.01
      success = HVAC.apply_ideal_air_loads_cooling(model, unit, runner, residual_clg_load_frac)
      return false if not success
    end

    return true
  end

  def self.add_setpoints(runner, model, building, weather)
    control = building.elements["BuildingDetails/Systems/HVAC/HVACControl"]
    return true if control.nil?

    control_type = XMLHelper.get_value(control, "ControlType")

    heating_temp = XMLHelper.get_value(control, "SetpointTempHeatingSeason")
    if not heating_temp.nil? # Use provided value
      htg_weekday_setpoints = [[Float(heating_temp)] * 24] * 12
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
                                           htg_use_auto_season, htg_season_start_month, htg_season_end_month)
    return false if not success

    cooling_temp = XMLHelper.get_value(control, "SetpointTempCoolingSeason")
    if not cooling_temp.nil? # Use provided value
      clg_weekday_setpoints = [[Float(cooling_temp)] * 24] * 12
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
                                           clg_use_auto_season, clg_season_start_month, clg_season_end_month)
    return false if not success

    return true
  end

  def self.add_ceiling_fans(runner, model, building, unit)
    cf = building.elements["BuildingDetails/Lighting/CeilingFan"]
    return true if cf.nil?

    medium_cfm = 3000.0
    weekday_sch = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0]
    weekend_sch = weekday_sch
    hrs_per_day = weekday_sch.inject { |sum, n| sum + n }

    cfm_per_w = XMLHelper.get_value(cf, "Airflow[FanSpeed='medium']/Efficiency")
    if cfm_per_w.nil?
      fan_power_w = HVAC.get_default_ceiling_fan_power()
      cfm_per_w = medium_cfm / fan_power_w
    else
      cfm_per_w = Float(cfm_per_w)
    end
    quantity = XMLHelper.get_value(cf, "Quantity")
    if quantity.nil?
      quantity = HVAC.get_default_ceiling_fan_quantity(@nbeds)
    else
      quantity = Float(quantity)
    end
    annual_kwh = UnitConversions.convert(quantity * medium_cfm / cfm_per_w * hrs_per_day * 365.0, "Wh", "kWh")

    success = HVAC.apply_eri_ceiling_fans(model, unit, runner, annual_kwh, weekday_sch, weekend_sch)
    return false if not success

    return true
  end

  def self.get_dse(building, system)
    if system.elements["DistributionSystem"].nil? # No distribution system
      return 1.0, 1.0, false
    end

    # Get attached distribution system
    ducts = nil
    duct_id = system.elements["DistributionSystem"].attributes["idref"]
    building.elements.each("BuildingDetails/Systems/HVAC/HVACDistribution") do |dist|
      next if duct_id != dist.elements["SystemIdentifier"].attributes["id"]
      next if dist.elements["DistributionSystemType[Other='DSE']"].nil?

      ducts = dist
    end
    if ducts.nil? # No attached DSEs for system
      return 1.0, 1.0, false
    end

    dse_cool = Float(XMLHelper.get_value(ducts, "AnnualCoolingDistributionSystemEfficiency"))
    dse_heat = Float(XMLHelper.get_value(ducts, "AnnualHeatingDistributionSystemEfficiency"))
    return dse_heat, dse_cool, true
  end

  def self.get_zone_hvacs(model)
    zone_hvacs = []
    model.getThermalZones.each do |zone|
      zone.equipment.each do |zone_hvac|
        next unless zone_hvac.to_ZoneHVACComponent.is_initialized

        zone_hvacs << zone_hvac
      end
    end
    return zone_hvacs
  end

  def self.update_loop_hvacs(loop_hvacs, zone_hvacs, model, sys, orig_air_loops, orig_plant_loops, orig_zone_hvacs)
    sys_id = sys.elements["SystemIdentifier"].attributes["id"]
    loop_hvacs[sys_id] = []
    zone_hvacs[sys_id] = []

    model.getAirLoopHVACs.each do |air_loop|
      next if orig_air_loops.include? air_loop # Only include newly added air loops

      loop_hvacs[sys_id] << air_loop
    end

    model.getPlantLoops.each do |plant_loop|
      next if orig_plant_loops.include? plant_loop # Only include newly added plant loops

      loop_hvacs[sys_id] << plant_loop
    end

    get_zone_hvacs(model).each do |zone_hvac|
      next if orig_zone_hvacs.include? zone_hvac

      zone_hvacs[sys_id] << zone_hvac
    end

    loop_hvacs.each do |sys_id, loops|
      next if not loops.empty?

      loop_hvacs.delete(sys_id)
    end

    zone_hvacs.each do |sys_id, hvacs|
      next if not hvacs.empty?

      zone_hvacs.delete(sys_id)
    end
  end

  def self.update_loop_dhws(loop_dhws, model, sys, orig_plant_loops)
    sys_id = sys.elements["SystemIdentifier"].attributes["id"]
    loop_dhws[sys_id] = []

    model.getPlantLoops.each do |plant_loop|
      next if orig_plant_loops.include? plant_loop # Only include newly added plant loops

      loop_dhws[sys_id] << plant_loop
    end

    loop_dhws.each do |sys_id, loops|
      next if not loops.empty?

      loop_dhws.delete(sys_id)
    end
  end

  def self.add_mels(runner, model, building, unit, spaces)
    living_space = create_or_get_space(model, spaces, Constants.SpaceTypeLiving)

    # Misc
    misc = building.elements["BuildingDetails/MiscLoads/PlugLoad[PlugLoadType='other']"]
    if not misc.nil?
      misc_annual_kwh = XMLHelper.get_value(building, "BuildingDetails/MiscLoads/PlugLoad[PlugLoadType='other']/Load[Units='kWh/year']/Value")
      if misc_annual_kwh.nil?
        misc_annual_kwh = MiscLoads.get_residual_mels_values(@cfa)[0]
      else
        misc_annual_kwh = Float(misc_annual_kwh)
      end

      misc_sens_frac = XMLHelper.get_value(building, "BuildingDetails/MiscLoads/PlugLoad[PlugLoadType='other']/extension/FracSensible")
      if misc_sens_frac.nil?
        misc_sens_frac = MiscLoads.get_residual_mels_values(@cfa)[1]
      else
        misc_sens_frac = Float(misc_sens_frac)
      end

      misc_lat_frac = XMLHelper.get_value(building, "BuildingDetails/MiscLoads/PlugLoad[PlugLoadType='other']/extension/FracLatent")
      if misc_lat_frac.nil?
        misc_lat_frac = MiscLoads.get_residual_mels_values(@cfa)[2]
      else
        misc_lat_frac = Float(misc_lat_frac)
      end

      misc_weekday_sch = XMLHelper.get_value(building, "BuildingDetails/MiscLoads/extension/WeekdayScheduleFractions")
      if misc_weekday_sch.nil?
        misc_weekday_sch = "0.04, 0.037, 0.037, 0.036, 0.033, 0.036, 0.043, 0.047, 0.034, 0.023, 0.024, 0.025, 0.024, 0.028, 0.031, 0.032, 0.039, 0.053, 0.063, 0.067, 0.071, 0.069, 0.059, 0.05"
      end

      misc_weekend_sch = XMLHelper.get_value(building, "BuildingDetails/MiscLoads/extension/WeekendScheduleFractions")
      if misc_weekend_sch.nil?
        misc_weekend_sch = "0.04, 0.037, 0.037, 0.036, 0.033, 0.036, 0.043, 0.047, 0.034, 0.023, 0.024, 0.025, 0.024, 0.028, 0.031, 0.032, 0.039, 0.053, 0.063, 0.067, 0.071, 0.069, 0.059, 0.05"
      end

      misc_monthly_sch = XMLHelper.get_value(building, "BuildingDetails/MiscLoads/extension/MonthlyScheduleMultipliers")
      if misc_monthly_sch.nil?
        misc_monthly_sch = "1.248, 1.257, 0.993, 0.989, 0.993, 0.827, 0.821, 0.821, 0.827, 0.99, 0.987, 1.248"
      end

      success, sch = MiscLoads.apply_plug(model, unit, runner, misc_annual_kwh,
                                          misc_sens_frac, misc_lat_frac, misc_weekday_sch,
                                          misc_weekend_sch, misc_monthly_sch, nil)
      return false if not success
    end

    # Television
    tv = building.elements["BuildingDetails/MiscLoads/PlugLoad[PlugLoadType='TV other']"]
    if not tv.nil?
      tv_annual_kwh = XMLHelper.get_value(building, "BuildingDetails/MiscLoads/PlugLoad[PlugLoadType='TV other']/Load[Units='kWh/year']/Value")
      if tv_annual_kwh.nil?
        tv_annual_kwh, tv_sens_frac, tv_lat_frac = MiscLoads.get_televisions_values(@cfa, @nbeds)
      else
        tv_annual_kwh = Float(tv_annual_kwh)
      end

      success = MiscLoads.apply_tv(model, unit, runner, tv_annual_kwh, sch, living_space)
      return false if not success
    end

    return true
  end

  def self.add_lighting(runner, model, building, unit, weather)
    return true if building.elements["BuildingDetails/Lighting"].nil?

    lighting_fractions = building.elements["BuildingDetails/Lighting/LightingFractions"]
    if lighting_fractions.nil?
      fFI_int, fFI_ext, fFI_grg, fFII_int, fFII_ext, fFII_grg = Lighting.get_reference_fractions()
    else
      fFI_int = Float(XMLHelper.get_value(lighting_fractions, "extension/FractionQualifyingTierIFixturesInterior"))
      fFI_ext = Float(XMLHelper.get_value(lighting_fractions, "extension/FractionQualifyingTierIFixturesExterior"))
      fFI_grg = Float(XMLHelper.get_value(lighting_fractions, "extension/FractionQualifyingTierIFixturesGarage"))
      fFII_int = Float(XMLHelper.get_value(lighting_fractions, "extension/FractionQualifyingTierIIFixturesInterior"))
      fFII_ext = Float(XMLHelper.get_value(lighting_fractions, "extension/FractionQualifyingTierIIFixturesExterior"))
      fFII_grg = Float(XMLHelper.get_value(lighting_fractions, "extension/FractionQualifyingTierIIFixturesGarage"))
    end
    int_kwh, ext_kwh, grg_kwh = Lighting.calc_lighting_energy(@eri_version, @cfa, @garage_present, fFI_int, fFI_ext, fFI_grg, fFII_int, fFII_ext, fFII_grg)

    success, sch = Lighting.apply_interior(model, unit, runner, weather, nil, int_kwh)
    return false if not success

    success = Lighting.apply_garage(model, runner, sch, grg_kwh)
    return false if not success

    success = Lighting.apply_exterior(model, runner, sch, ext_kwh)
    return false if not success

    return true
  end

  def self.add_airflow(runner, model, building, unit, loop_hvacs)
    # Infiltration
    infiltration = building.elements["BuildingDetails/Enclosure/AirInfiltration"]
    infil_ach50 = XMLHelper.get_value(infiltration, "AirInfiltrationMeasurement[HousePressure='50']/BuildingAirLeakage[UnitofMeasure='ACH']/AirLeakage")
    infil_const_ach = XMLHelper.get_value(infiltration, "AirInfiltrationMeasurement/extension/ConstantACHnatural")
    if not infil_ach50.nil?
      infil_ach50 = Float(infil_ach50)
    elsif not infil_const_ach.nil?
      infil_const_ach = Float(infil_const_ach)
    end

    # Vented crawl SLA
    vented_crawl_area = 0.0
    vented_crawl_sla_area = 0.0
    building.elements.each("BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/Crawlspace[Vented='true']]") do |vented_crawl|
      area = REXML::XPath.first(vented_crawl, "sum(FrameFloor/Area)")
      vented_crawl_sla = XMLHelper.get_value(vented_crawl, "extension/CrawlspaceSpecificLeakageArea")
      if not vented_crawl_sla.nil?
        vented_crawl_sla = Float(vented_crawl_sla)
      else
        vented_crawl_sla = Airflow.get_default_vented_crawl_sla()
      end
      vented_crawl_sla_area += (vented_crawl_sla * area)
      vented_crawl_area += area
    end
    if vented_crawl_area > 0
      crawl_sla = vented_crawl_sla_area / vented_crawl_area
    else
      crawl_sla = 0.0
    end

    # Vented attic SLA
    vented_attic_area = 0.0
    vented_attic_sla_area = 0.0
    vented_attic_const_ach = nil
    building.elements.each("BuildingDetails/Enclosure/Attics/Attic[AtticType='vented attic']") do |vented_attic|
      area = REXML::XPath.first(vented_attic, "sum(Floors/Floor/Area)")
      vented_attic_sla = XMLHelper.get_value(vented_attic, "extension/AtticSpecificLeakageArea")
      vented_attic_const_ach = XMLHelper.get_value(vented_attic, "extension/AtticConstantACHnatural")
      if not vented_attic_sla.nil?
        vented_attic_sla = Float(vented_attic_sla)
        vented_attic_sla_area += (vented_attic_sla * area)
      elsif not vented_attic_const_ach.nil?
        vented_attic_const_ach = Float(vented_attic_const_ach)
      else
        vented_attic_sla = Airflow.get_default_vented_attic_sla()
        vented_attic_sla_area += (vented_attic_sla * area)
      end
      vented_attic_area += area
    end
    if vented_attic_area == 0
      attic_sla = 0
      attic_const_ach = nil
    elsif vented_attic_sla_area > 0
      attic_sla = vented_attic_sla_area / vented_attic_area
      attic_const_ach = nil
    else
      attic_sla = nil
      attic_const_ach = vented_attic_const_ach
    end

    living_ach50 = infil_ach50
    living_constant_ach = infil_const_ach
    garage_ach50 = infil_ach50
    finished_basement_ach = 0 # TODO: Need to handle above-grade basement
    unfinished_basement_ach = 0.1 # TODO: Need to handle above-grade basement
    crawl_ach = crawl_sla # FIXME: sla vs ach
    pier_beam_ach = 100
    shelter_coef = XMLHelper.get_value(building, "BuildingDetails/BuildingSummary/Site/extension/ShelterCoefficient")
    if shelter_coef.nil?
      shelter_coef = Airflow.get_default_shelter_coefficient()
    else
      shelter_coef = Float(shelter_coef)
    end
    has_flue_chimney = false
    is_existing_home = false
    terrain = Constants.TerrainSuburban
    infil = Infiltration.new(living_ach50, living_constant_ach, shelter_coef, garage_ach50, crawl_ach, attic_sla, attic_const_ach, unfinished_basement_ach,
                             finished_basement_ach, pier_beam_ach, has_flue_chimney, is_existing_home, terrain)

    # Mechanical Ventilation
    whole_house_fan = building.elements["BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation='true']"]
    if whole_house_fan.nil?
      mech_vent_type = Constants.VentTypeNone
      mech_vent_total_efficiency = 0.0
      mech_vent_sensible_efficiency = 0.0
      mech_vent_fan_power = 0.0
      mech_vent_cfm = 0.0
    else
      # FIXME: HoursInOperation isn't hooked up
      # FIXME: AttachedToHVACDistributionSystem isn't hooked up
      fan_type = XMLHelper.get_value(whole_house_fan, "FanType")
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
        mech_vent_sensible_efficiency = Float(XMLHelper.get_value(whole_house_fan, "SensibleRecoveryEfficiency"))
      end
      if fan_type == "energy recovery ventilator"
        mech_vent_total_efficiency = Float(XMLHelper.get_value(whole_house_fan, "TotalRecoveryEfficiency"))
      end
      mech_vent_cfm = Float(XMLHelper.get_value(whole_house_fan, "RatedFlowRate"))
      mech_vent_w = Float(XMLHelper.get_value(whole_house_fan, "FanPower"))
      mech_vent_fan_power = mech_vent_w / mech_vent_cfm / num_fans
    end
    mech_vent_ashrae_std = '2013'
    mech_vent_infil_credit = true
    mech_vent_cfis_open_time = 20.0
    mech_vent_cfis_airflow_frac = 1.0
    clothes_dryer_exhaust = 0.0
    range_exhaust = 0.0
    range_exhaust_hour = 16
    bathroom_exhaust = 0.0
    bathroom_exhaust_hour = 5
    mech_vent = MechanicalVentilation.new(mech_vent_type, mech_vent_infil_credit, mech_vent_total_efficiency,
                                          nil, mech_vent_cfm, mech_vent_fan_power, mech_vent_sensible_efficiency,
                                          mech_vent_ashrae_std, clothes_dryer_exhaust, range_exhaust,
                                          range_exhaust_hour, bathroom_exhaust, bathroom_exhaust_hour)
    # FIXME: AttachedToHVACDistributionSystem isn't hooked up
    cfis = CFIS.new(mech_vent_cfis_open_time, mech_vent_cfis_airflow_frac)
    cfis_systems = { cfis => model.getAirLoopHVACs }

    # Natural Ventilation
    disable_nat_vent = XMLHelper.get_value(building, "BuildingDetails/Enclosure/extension/DisableNaturalVentilation")
    if not disable_nat_vent.nil? and Boolean(disable_nat_vent)
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
    location_map = { 'living space' => Constants.SpaceTypeLiving,
                     'basement - conditioned' => Constants.SpaceTypeFinishedBasement,
                     'basement - unconditioned' => Constants.SpaceTypeUnfinishedBasement,
                     'crawlspace - vented' => Constants.SpaceTypeCrawl,
                     'crawlspace - unvented' => Constants.SpaceTypeCrawl,
                     'attic - vented' => Constants.SpaceTypeUnfinishedAttic,
                     'attic - unvented' => Constants.SpaceTypeUnfinishedAttic,
                     'attic - conditioned' => Constants.SpaceTypeLiving,
                     'garage' => Constants.SpaceTypeGarage }
    building.elements.each("BuildingDetails/Systems/HVAC/HVACDistribution") do |hvac_distribution|
      air_distribution = hvac_distribution.elements["DistributionSystemType/AirDistribution"]
      next if air_distribution.nil?

      # Ducts
      # FIXME: Values below
      supply_cfm25 = Float(XMLHelper.get_value(air_distribution, "DuctLeakageMeasurement[DuctType='supply']/DuctLeakage[Units='CFM25' and TotalOrToOutside='to outside']/Value"))
      return_cfm25 = Float(XMLHelper.get_value(air_distribution, "DuctLeakageMeasurement[DuctType='return']/DuctLeakage[Units='CFM25' and TotalOrToOutside='to outside']/Value"))
      supply_r = Float(XMLHelper.get_value(air_distribution, "Ducts[DuctType='supply']/DuctInsulationRValue"))
      return_r = Float(XMLHelper.get_value(air_distribution, "Ducts[DuctType='return']/DuctInsulationRValue"))
      supply_area = Float(XMLHelper.get_value(air_distribution, "Ducts[DuctType='supply']/DuctSurfaceArea"))
      return_area = Float(XMLHelper.get_value(air_distribution, "Ducts[DuctType='return']/DuctSurfaceArea"))
      duct_location = location_map[XMLHelper.get_value(air_distribution, "Ducts[DuctType='supply']/DuctLocation")]
      duct_total_leakage = 0.3
      duct_supply_frac = 0.6
      duct_return_frac = 0.067
      duct_ah_supply_frac = 0.067
      duct_ah_return_frac = 0.267
      duct_location_frac = 1.0
      duct_num_returns = 1
      duct_supply_area_mult = supply_area / 100.0
      duct_return_area_mult = return_area / 100.0
      duct_r = 4.0
      duct_norm_leakage_25pa = nil

      ducts = Ducts.new(duct_total_leakage, duct_norm_leakage_25pa, duct_supply_area_mult, duct_return_area_mult, duct_r,
                        duct_supply_frac, duct_return_frac, duct_ah_supply_frac, duct_ah_return_frac, duct_location_frac,
                        duct_num_returns, duct_location)

      # Connect AirLoopHVACs to ducts
      systems_for_this_duct = []
      duct_id = hvac_distribution.elements["SystemIdentifier"].attributes["id"]
      building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[FractionHeatLoadServed > 0] |
                              BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[FractionCoolLoadServed > 0] |
                              BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[FractionHeatLoadServed > 0 && FractionCoolLoadServed > 0]") do |sys|
        next if sys.elements["DistributionSystem"].nil? or duct_id != sys.elements["DistributionSystem"].attributes["idref"]

        sys_id = sys.elements["SystemIdentifier"].attributes["id"]
        loop_hvacs[sys_id].each do |loop|
          next if not loop.is_a? OpenStudio::Model::AirLoopHVAC

          systems_for_this_duct << loop
        end
      end

      duct_systems[ducts] = systems_for_this_duct
    end

    # Set no ducts for HVAC without duct systems
    systems_for_no_duct = []
    no_ducts = Ducts.new(0.0, nil, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, Constants.Auto, Constants.Auto, "none")
    loop_hvacs.each do |sys_id, loops|
      loops.each do |loop|
        next if not loop.is_a? OpenStudio::Model::AirLoopHVAC

        # Look for loop already associated with a duct system
        loop_found = false
        duct_systems.keys.each do |duct_system|
          if duct_systems[duct_system].include? loop
            loop_found = true
          end
        end
        next if loop_found

        # Loop has no associated ducts; associate with no duct system
        systems_for_no_duct << loop
      end
    end
    if not systems_for_no_duct.empty?
      duct_systems[no_ducts] = systems_for_no_duct
    end

    # FIXME: Throw error if, e.g., multiple heating systems connected to same distribution system?

    success = Airflow.apply(model, runner, infil, mech_vent, nat_vent, duct_systems, cfis_systems)
    return false if not success

    return true
  end

  def self.add_hvac_sizing(runner, model, unit, weather)
    success = HVACSizing.apply(model, unit, runner, weather, false)
    return false if not success

    return true
  end

  def self.add_fuel_heating_eae(runner, model, building, loop_hvacs, zone_hvacs)
    # Needs to come after HVAC sizing (needs heating capacity and airflow rate)

    building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[FractionHeatLoadServed > 0]") do |htgsys|
      htg_type = XMLHelper.get_child_name(htgsys, "HeatingSystemType")
      next if not ["Furnace", "WallFurnace", "Stove", "Boiler"].include? htg_type

      fuel = to_beopt_fuel(XMLHelper.get_value(htgsys, "HeatingSystemFuel"))
      next if fuel == Constants.FuelTypeElectric

      fuel_eae = XMLHelper.get_value(htgsys, "ElectricAuxiliaryEnergy")
      if not fuel_eae.nil?
        fuel_eae = Float(fuel_eae)
      end

      load_frac = Float(XMLHelper.get_value(htgsys, "FractionHeatLoadServed"))

      dse_heat, dse_cool, has_dse = get_dse(building, htgsys)

      sys_id = htgsys.elements["SystemIdentifier"].attributes["id"]

      eae_loop_hvac = nil
      eae_zone_hvacs = nil
      eae_loop_hvac_cool = nil
      if loop_hvacs.keys.include? sys_id
        eae_loop_hvac = loop_hvacs[sys_id][0]
        has_furnace = (htg_type == "Furnace")
        has_boiler = (htg_type == "Boiler")

        if has_furnace
          # Check for cooling system on the same supply fan
          htgdist = htgsys.elements["DistributionSystem"]
          building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[FractionCoolLoadServed > 0]") do |clgsys|
            clgdist = clgsys.elements["DistributionSystem"]
            next if htgdist.nil? or clgdist.nil?
            next if clgdist.attributes["idref"] != htgdist.attributes["idref"]

            eae_loop_hvac_cool = loop_hvacs[clgsys.elements["SystemIdentifier"].attributes["id"]][0]
          end
        end
      elsif zone_hvacs.keys.include? sys_id
        eae_zone_hvacs = zone_hvacs[sys_id]
      end

      success = HVAC.apply_eae_to_heating_fan(runner, eae_loop_hvac, eae_zone_hvacs, fuel_eae, fuel, dse_heat,
                                              has_furnace, has_boiler, load_frac, eae_loop_hvac_cool)
      return false if not success
    end

    return true
  end

  def self.add_photovoltaics(runner, model, building)
    return true if building.elements["BuildingDetails/Systems/Photovoltaics/PVSystem"].nil?

    modules_map = { "standard" => Constants.PVModuleTypeStandard,
                    "premium" => Constants.PVModuleTypePremium,
                    "thin film" => Constants.PVModuleTypeThinFilm }

    arrays_map = { "fixed open rack" => Constants.PVArrayTypeFixedOpenRack,
                   "fixed roof mount" => Constants.PVArrayTypeFixedRoofMount,
                   "1-axis" => Constants.PVArrayTypeFixed1Axis,
                   "1-axis backtracked" => Constants.PVArrayTypeFixed1AxisBacktracked,
                   "2-axis" => Constants.PVArrayTypeFixed2Axis }

    building.elements.each("BuildingDetails/Systems/Photovoltaics/PVSystem") do |pvsys|
      pv_id = pvsys.elements["SystemIdentifier"].attributes["id"]
      module_type = modules_map[XMLHelper.get_value(pvsys, "ModuleType")]
      array_type = arrays_map[XMLHelper.get_value(pvsys, "ArrayType")]
      az = Float(XMLHelper.get_value(pvsys, "ArrayAzimuth"))
      tilt = Float(XMLHelper.get_value(pvsys, "ArrayTilt"))
      power_w = Float(XMLHelper.get_value(pvsys, "MaxPowerOutput"))
      inv_eff = Float(XMLHelper.get_value(pvsys, "InverterEfficiency"))
      system_losses = Float(XMLHelper.get_value(pvsys, "SystemLossesFraction"))

      success = PV.apply(model, runner, pv_id, power_w, module_type,
                         system_losses, inv_eff, tilt, az, array_type)
      return false if not success
    end

    return true
  end

  def self.add_building_output_variables(runner, model, loop_hvacs, zone_hvacs, loop_dhws, map_tsv_dir)
    htg_mapping = {}
    clg_mapping = {}
    dhw_mapping = {}

    # AirLoopHVAC systems
    loop_hvacs.each do |sys_id, loops|
      htg_mapping[sys_id] = []
      clg_mapping[sys_id] = []
      loops.each do |loop|
        next unless loop.is_a? OpenStudio::Model::AirLoopHVAC

        loop.supplyComponents.each do |comp|
          next unless comp.to_AirLoopHVACUnitarySystem.is_initialized

          unitary_system = comp.to_AirLoopHVACUnitarySystem.get
          if unitary_system.coolingCoil.is_initialized
            # Cooling system: Cooling coil, supply fan
            clg_mapping[sys_id] << HVAC.get_coil_from_hvac_component(unitary_system.coolingCoil.get)
            clg_mapping[sys_id] << unitary_system.supplyFan.get.to_FanOnOff.get
          elsif unitary_system.heatingCoil.is_initialized
            # Heating system: Heating coil, supply fan, supplemental coil
            htg_mapping[sys_id] << HVAC.get_coil_from_hvac_component(unitary_system.heatingCoil.get)
            htg_mapping[sys_id] << unitary_system.supplyFan.get.to_FanOnOff.get
            if unitary_system.supplementalHeatingCoil.is_initialized
              htg_mapping[sys_id] << HVAC.get_coil_from_hvac_component(unitary_system.supplementalHeatingCoil.get)
            end
          end
        end
      end
    end

    zone_hvacs.each do |sys_id, hvacs|
      htg_mapping[sys_id] = []
      clg_mapping[sys_id] = []
      hvacs.each do |hvac|
        next unless hvac.to_ZoneHVACComponent.is_initialized

        if hvac.to_AirLoopHVACUnitarySystem.is_initialized

          unitary_system = hvac.to_AirLoopHVACUnitarySystem.get
          if unitary_system.coolingCoil.is_initialized
            # Cooling system: Cooling coil, supply fan
            clg_mapping[sys_id] << HVAC.get_coil_from_hvac_component(unitary_system.coolingCoil.get)
            clg_mapping[sys_id] << unitary_system.supplyFan.get.to_FanOnOff.get
          elsif unitary_system.heatingCoil.is_initialized
            # Heating system: Heating coil, supply fan
            htg_mapping[sys_id] << HVAC.get_coil_from_hvac_component(unitary_system.heatingCoil.get)
            htg_mapping[sys_id] << unitary_system.supplyFan.get.to_FanOnOff.get
          end

        elsif hvac.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized

          ptac = hvac.to_ZoneHVACPackagedTerminalAirConditioner.get
          clg_mapping[sys_id] << HVAC.get_coil_from_hvac_component(ptac.coolingCoil)

        elsif hvac.to_ZoneHVACBaseboardConvectiveElectric.is_initialized

          htg_mapping[sys_id] << hvac.to_ZoneHVACBaseboardConvectiveElectric.get

        elsif hvac.to_ZoneHVACBaseboardConvectiveWater.is_initialized

          baseboard = hvac.to_ZoneHVACBaseboardConvectiveWater.get
          baseboard.heatingCoil.plantLoop.get.components.each do |comp|
            next unless comp.to_BoilerHotWater.is_initialized

            htg_mapping[sys_id] << comp.to_BoilerHotWater.get
          end

        end
      end
    end

    loop_dhws.each do |sys_id, loops|
      dhw_mapping[sys_id] = []
      loops.each do |loop|
        loop.supplyComponents.each do |comp|
          if comp.to_WaterHeaterMixed.is_initialized

            water_heater = comp.to_WaterHeaterMixed.get
            dhw_mapping[sys_id] << water_heater

          elsif comp.to_WaterHeaterStratified.is_initialized

            hpwh_tank = comp.to_WaterHeaterStratified.get
            dhw_mapping[sys_id] << hpwh_tank

            model.getWaterHeaterHeatPumpWrappedCondensers.each do |hpwh|
              next if hpwh.tank.name.to_s != hpwh_tank.name.to_s

              water_heater_coil = hpwh.dXCoil.to_CoilWaterHeatingAirToWaterHeatPumpWrapped.get
              dhw_mapping[sys_id] << water_heater_coil
            end

          end
        end

        recirc_pump_name = loop.additionalProperties.getFeatureAsString("PlantLoopRecircPump")
        if recirc_pump_name.is_initialized
          recirc_pump_name = recirc_pump_name.get
          model.getElectricEquipments.each do |ee|
            next unless ee.name.to_s == recirc_pump_name

            dhw_mapping[sys_id] << ee
          end
        end

        loop.demandComponents.each do |comp|
          if comp.to_WaterUseConnections.is_initialized

            water_use_connections = comp.to_WaterUseConnections.get
            dhw_mapping[sys_id] << water_use_connections

          end
        end
      end
    end

    htg_mapping.each do |sys_id, htg_equip_list|
      add_output_variables(model, OutputVars.SpaceHeatingElectricity, htg_equip_list)
      add_output_variables(model, OutputVars.SpaceHeatingFuel, htg_equip_list)
      add_output_variables(model, OutputVars.SpaceHeatingLoad, htg_equip_list)
    end
    clg_mapping.each do |sys_id, clg_equip_list|
      add_output_variables(model, OutputVars.SpaceCoolingElectricity, clg_equip_list)
      add_output_variables(model, OutputVars.SpaceCoolingLoad, clg_equip_list)
    end
    dhw_mapping.each do |sys_id, dhw_equip_list|
      add_output_variables(model, OutputVars.WaterHeatingElectricity, dhw_equip_list)
      add_output_variables(model, OutputVars.WaterHeatingElectricityRecircPump, dhw_equip_list)
      add_output_variables(model, OutputVars.WaterHeatingFuel, dhw_equip_list)
      add_output_variables(model, OutputVars.WaterHeatingLoad, dhw_equip_list)
    end

    if map_tsv_dir.is_initialized
      map_tsv_dir = map_tsv_dir.get
      write_mapping(htg_mapping, File.join(map_tsv_dir, "map_hvac_heating.tsv"))
      write_mapping(clg_mapping, File.join(map_tsv_dir, "map_hvac_cooling.tsv"))
      write_mapping(dhw_mapping, File.join(map_tsv_dir, "map_water_heating.tsv"))
    end

    return true
  end

  def self.add_output_variables(model, vars, objects)
    if objects.nil?
      vars[nil].each do |object_var|
        outputVariable = OpenStudio::Model::OutputVariable.new(object_var, model)
        outputVariable.setReportingFrequency('runperiod')
        outputVariable.setKeyValue('*')
      end
    else
      objects.each do |object|
        if vars[object.class.to_s].nil?
          fail "Unexpected object type #{object.class.to_s}."
        end

        vars[object.class.to_s].each do |object_var|
          outputVariable = OpenStudio::Model::OutputVariable.new(object_var, model)
          outputVariable.setReportingFrequency('runperiod')
          outputVariable.setKeyValue(object.name.to_s)
        end
      end
    end
  end

  def self.write_mapping(mapping, map_tsv_path)
    # Write simple mapping TSV file for use by ERI calculation. Mapping file correlates
    # EnergyPlus object name to a HPXML object name.

    CSV.open(map_tsv_path, 'w', col_sep: "\t") do |tsv|
      # Header
      tsv << ["HPXML Name", "E+ Name(s)"]

      mapping.each do |sys_id, objects|
        out_data = [sys_id]
        objects.each do |object|
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
      if not assembly_r.nil?
        assembly_r = Float(assembly_r)
      else
        assembly_r = 1.0 / WallConstructions.get_default_frame_wall_ufactor(@iecc_zone_2006)
      end
      install_grade = 1
      cavity_filled = true

      constr_sets = [
        WoodStudConstructionSet.new(Material.Stud2x6, 0.20, 10.0, 0.5, drywall_thick_in, mat_ext_finish), # 2x6, 24" o.c. + R10
        WoodStudConstructionSet.new(Material.Stud2x6, 0.20, 5.0, 0.5, drywall_thick_in, mat_ext_finish),  # 2x6, 24" o.c. + R5
        WoodStudConstructionSet.new(Material.Stud2x6, 0.20, 0.0, 0.5, drywall_thick_in, mat_ext_finish),  # 2x6, 24" o.c.
        WoodStudConstructionSet.new(Material.Stud2x4, 0.23, 0.0, 0.5, drywall_thick_in, mat_ext_finish),  # 2x4, 16" o.c.
        WoodStudConstructionSet.new(Material.Stud2x4, 0.01, 0.0, 0.0, 0.0, nil),                          # Fallback
      ]
      constr_set, cavity_r = pick_wood_stud_construction_set(assembly_r, constr_sets, film_r, "wall #{wall_id}")

      success = WallConstructions.apply_wood_stud(runner, model, [surface], "WallConstruction",
                                                  cavity_r, install_grade, constr_set.stud.thick_in,
                                                  cavity_filled, constr_set.framing_factor,
                                                  constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                                  constr_set.rigid_r, constr_set.exterior_material)
      return false if not success

    elsif wall_type == "SteelFrame"
      assembly_r = Float(assembly_r)
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

      success = WallConstructions.apply_steel_stud(runner, model, [surface], "WallConstruction",
                                                   cavity_r, install_grade, constr_set.cavity_thick_in,
                                                   cavity_filled, constr_set.framing_factor,
                                                   constr_set.corr_factor, constr_set.drywall_thick_in,
                                                   constr_set.osb_thick_in, constr_set.rigid_r,
                                                   constr_set.exterior_material)
      return false if not success

    elsif wall_type == "DoubleWoodStud"
      assembly_r = Float(assembly_r)
      install_grade = 1
      is_staggered = false

      constr_sets = [
        DoubleStudConstructionSet.new(Material.Stud2x4, 0.23, 24.0, 0.0, 0.5, drywall_thick_in, mat_ext_finish),  # 2x4, 24" o.c.
        DoubleStudConstructionSet.new(Material.Stud2x4, 0.01, 16.0, 0.0, 0.0, 0.0, nil),                          # Fallback
      ]
      constr_set, cavity_r = pick_double_stud_construction_set(assembly_r, constr_sets, film_r, "wall #{wall_id}")

      success = WallConstructions.apply_double_stud(runner, model, [surface], "WallConstruction",
                                                    cavity_r, install_grade, constr_set.stud.thick_in,
                                                    constr_set.stud.thick_in, constr_set.framing_factor,
                                                    constr_set.framing_spacing, is_staggered,
                                                    constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                                    constr_set.rigid_r, constr_set.exterior_material)
      return false if not success

    elsif wall_type == "ConcreteMasonryUnit"
      assembly_r = Float(assembly_r)
      density = 119.0 # lb/ft^3
      furring_r = 0
      furring_cavity_depth_in = 0 # in
      furring_spacing = 0

      constr_sets = [
        CMUConstructionSet.new(8.0, 1.4, 0.08, 0.5, drywall_thick_in, mat_ext_finish),  # 8" perlite-filled CMU
        CMUConstructionSet.new(6.0, 5.29, 0.01, 0.0, 0.0, nil),                         # Fallback (6" hollow CMU)
      ]
      constr_set, rigid_r = pick_cmu_construction_set(assembly_r, constr_sets, film_r, "wall #{wall_id}")

      success = WallConstructions.apply_cmu(runner, model, [surface], "WallConstruction",
                                            constr_set.thick_in, constr_set.cond_in, density,
                                            constr_set.framing_factor, furring_r,
                                            furring_cavity_depth_in, furring_spacing,
                                            constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                            rigid_r, constr_set.exterior_material)
      return false if not success

    elsif wall_type == "StructurallyInsulatedPanel"
      assembly_r = Float(assembly_r)
      sheathing_thick_in = 0.44
      sheathing_type = Constants.MaterialOSB

      constr_sets = [
        SIPConstructionSet.new(10.0, 0.16, 0.0, sheathing_thick_in, 0.5, drywall_thick_in, mat_ext_finish), # 10" SIP core
        SIPConstructionSet.new(5.0, 0.16, 0.0, sheathing_thick_in, 0.5, drywall_thick_in, mat_ext_finish),  # 5" SIP core
        SIPConstructionSet.new(1.0, 0.01, 0.0, sheathing_thick_in, 0.0, 0.0, nil),                          # Fallback
      ]
      constr_set, cavity_r = pick_sip_construction_set(assembly_r, constr_sets, film_r, "wall #{wall_id}")

      success = WallConstructions.apply_sip(runner, model, [surface], "WallConstruction",
                                            cavity_r, constr_set.thick_in, constr_set.framing_factor,
                                            sheathing_type, constr_set.sheath_thick_in,
                                            constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                            constr_set.rigid_r, constr_set.exterior_material)
      return false if not success

    elsif wall_type == "InsulatedConcreteForms"
      assembly_r = Float(assembly_r)

      constr_sets = [
        ICFConstructionSet.new(2.0, 4.0, 0.08, 0.0, 0.5, drywall_thick_in, mat_ext_finish), # ICF w/4" concrete and 2" rigid ins layers
        ICFConstructionSet.new(1.0, 1.0, 0.01, 0.0, 0.0, 0.0, nil),                         # Fallback
      ]
      constr_set, icf_r = pick_icf_construction_set(assembly_r, constr_sets, film_r, "wall #{wall_id}")

      success = WallConstructions.apply_icf(runner, model, [surface], "WallConstruction",
                                            icf_r, constr_set.ins_thick_in,
                                            constr_set.concrete_thick_in, constr_set.framing_factor,
                                            constr_set.drywall_thick_in, constr_set.osb_thick_in,
                                            constr_set.rigid_r, constr_set.exterior_material)
      return false if not success

    elsif ["SolidConcrete", "StructuralBrick", "StrawBale", "Stone", "LogWall"].include? wall_type
      assembly_r = Float(assembly_r)

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

      success = WallConstructions.apply_generic(runner, model, [surface], "WallConstruction",
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
      fail "Unexpected object." if not constr_set.is_a? WoodStudConstructionSet

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
      fail "Unexpected object." if not constr_set.is_a? SteelStudConstructionSet

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
      fail "Unexpected object." if not constr_set.is_a? DoubleStudConstructionSet

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
      fail "Unexpected object." if not constr_set.is_a? SIPConstructionSet

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
      fail "Unexpected object." if not constr_set.is_a? CMUConstructionSet

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
      fail "Unexpected object." if not constr_set.is_a? ICFConstructionSet

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
      fail "Unexpected object." if not constr_set.is_a? GenericConstructionSet

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

  def self.get_attached_to_multispeed_ac(htgsys, building)
    attached_to_multispeed_ac = false
    building.elements.each("BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem") do |clgsys|
      next unless XMLHelper.get_value(clgsys, "CoolingSystemType") == "central air conditioning"
      next unless htgsys.elements["DistributionSystem"].attributes["idref"] == clgsys.elements["DistributionSystem"].attributes["idref"]
      next unless get_ac_num_speeds(Float(XMLHelper.get_value(clgsys, "AnnualCoolingEfficiency[Units='SEER']/Value"))) != "1-Speed"

      attached_to_multispeed_ac = true
    end

    return attached_to_multispeed_ac
  end

  def self.set_surface_interior(model, spaces, surface, surface_id, interior_adjacent_to)
    if ["living space"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeLiving))
    elsif ["garage"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeGarage))
    elsif ["basement - unconditioned"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeUnfinishedBasement))
    elsif ["basement - conditioned"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeFinishedBasement))
    elsif ["crawlspace - vented", "crawlspace - unvented"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeCrawl))
    elsif ["attic - unvented", "attic - vented"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeUnfinishedAttic))
    elsif ["attic - conditioned"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeFinishedAttic))
    elsif ["flat roof", "cathedral ceiling"].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, Constants.SpaceTypeLiving))
    else
      fail "Unhandled AdjacentTo value (#{interior_adjacent_to}) for surface '#{surface_id}'."
    end
  end

  def self.set_surface_exterior(model, spaces, surface, surface_id, exterior_adjacent_to)
    if ["outside"].include? exterior_adjacent_to
      surface.setOutsideBoundaryCondition("Outdoors")
    elsif ["ground"].include? exterior_adjacent_to
      surface.setOutsideBoundaryCondition("Foundation")
    elsif ["living space"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeLiving))
    elsif ["garage"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeGarage))
    elsif ["basement - unconditioned"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeUnfinishedBasement))
    elsif ["basement - conditioned"].include? interior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeFinishedBasement))
    elsif ["crawlspace - vented", "crawlspace - unvented"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeCrawl))
    elsif ["attic - unvented", "attic - vented"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeUnfinishedAttic))
    elsif ["attic - conditioned"].include? exterior_adjacent_to
      surface.createAdjacentSurface(create_or_get_space(model, spaces, Constants.SpaceTypeFinishedAttic))
    else
      fail "Unhandled AdjacentTo value (#{exterior_adjacent_to}) for surface '#{surface_id}'."
    end
  end

  def self.get_foundation_top(model)
    # Get top of foundation surfaces
    foundation_top = -9999
    model.getSpaces.each do |space|
      next unless Geometry.space_is_below_grade(space)

      space.surfaces.each do |surface|
        surface.vertices.each do |v|
          next if v.z < foundation_top

          foundation_top = v.z
        end
      end
    end

    if foundation_top == -9999
      foundation_top = 9999
      # Pier & beam foundation; get lowest floor vertex
      model.getSpaces.each do |space|
        space.surfaces.each do |surface|
          next unless surface.surfaceType.downcase == "floor"

          surface.vertices.each do |v|
            next if v.z > foundation_top

            foundation_top = v.z
          end
        end
      end
    end

    if foundation_top == 9999
      fail "Could not calculate foundation top."
    end

    return UnitConversions.convert(foundation_top, "m", "ft")
  end

  def self.get_walls_top(model)
    # Get top of wall surfaces
    walls_top = -9999
    model.getSpaces.each do |space|
      space.surfaces.each do |surface|
        next unless surface.surfaceType.downcase == "wall"
        next unless surface.subSurfaces.size == 0

        surface.vertices.each do |v|
          next if v.z < walls_top

          walls_top = v.z
        end
      end
    end

    if walls_top == -9999
      fail "Could not calculate walls top."
    end

    return UnitConversions.convert(walls_top, "m", "ft")
  end

  def self.get_space_from_location(location, object_name, model, spaces)
    if location.nil? or location == 'living space'
      return create_or_get_space(model, spaces, Constants.SpaceTypeLiving)
    elsif location == 'basement - conditioned'
      return create_or_get_space(model, spaces, Constants.SpaceTypeFinishedBasement)
    elsif location == 'basement - unconditioned'
      return create_or_get_space(model, spaces, Constants.SpaceTypeUnfinishedBasement)
    elsif location == 'garage'
      return create_or_get_space(model, spaces, Constants.SpaceTypeGarage)
    elsif location == 'attic - unvented' or location == 'attic - vented'
      return create_or_get_space(model, spaces, Constants.SpaceTypeUnfinishedAttic)
    elsif location == 'crawlspace - unvented' or location == 'crawlspace - vented'
      return create_or_get_space(model, spaces, Constants.SpaceTypeCrawl)
    end

    fail "Unhandled #{object_name} location: #{location}."
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
           "electricity" => Constants.FuelTypeElectric }[fuel]
end

def to_beopt_wh_type(type)
  return { 'storage water heater' => Constants.WaterHeaterTypeTank,
           'instantaneous water heater' => Constants.WaterHeaterTypeTankless,
           'heat pump water heater' => Constants.WaterHeaterTypeHeatPump }[type]
end

def get_foundation_adjacent_to(fnd_type)
  if fnd_type.elements["Basement[Conditioned='true']"]
    return "basement - conditioned"
  elsif fnd_type.elements["Basement[Conditioned='false']"]
    return "basement - unconditioned"
  elsif fnd_type.elements["Crawlspace[Vented='true']"]
    return "crawlspace - vented"
  elsif fnd_type.elements["Crawlspace[Vented='false']"]
    return "crawlspace - unvented"
  elsif fnd_type.elements["SlabOnGrade"]
    return "living space"
  elsif fnd_type.elements["Ambient"]
    return "outside"
  end

  fail "Unexpected foundation type."
end

def get_attic_adjacent_to(attic_type)
  if attic_type == "unvented attic"
    return "attic - unvented"
  elsif attic_type == "vented attic"
    return "attic - vented"
  elsif attic_type == "cape cod"
    return "attic - conditioned"
  elsif attic_type == "cathedral ceiling"
    return "living space"
  elsif attic_type == "flat roof"
    return "living space"
  end

  fail "Unexpected attic type."
end

def is_external_thermal_boundary(interior_adjacent_to, exterior_adjacent_to)
  interior_conditioned = is_adjacent_to_conditioned(interior_adjacent_to)
  exterior_conditioned = is_adjacent_to_conditioned(exterior_adjacent_to)
  return (interior_conditioned != exterior_conditioned)
end

def is_adjacent_to_conditioned(adjacent_to)
  if adjacent_to == "living space"
    return true
  elsif adjacent_to == "garage"
    return false
  elsif adjacent_to == "attic - vented"
    return false
  elsif adjacent_to == "attic - unvented"
    return false
  elsif adjacent_to == "attic - conditioned"
    return true
  elsif adjacent_to == "basement - unconditioned"
    return false
  elsif adjacent_to == "basement - conditioned"
    return true
  elsif adjacent_to == "crawlspace - vented"
    return false
  elsif adjacent_to == "crawlspace - unvented"
    return false
  elsif adjacent_to == "outside"
    return false
  elsif adjacent_to == "ground"
    return false
  end

  fail "Unexpected adjacent_to (#{adjacent_to})."
end

def get_ac_num_speeds(seer)
  if seer <= 15
    return "1-Speed"
  elsif seer <= 21
    return "2-Speed"
  else
    return "Variable-Speed"
  end
end

def get_ashp_num_speeds(seer)
  if seer <= 15
    num_speeds = "1-Speed"
  elsif seer <= 21
    num_speeds = "2-Speed"
  else
    num_speeds = "Variable-Speed"
  end
end

class OutputVars
  def self.SpaceHeatingElectricity
    return { 'OpenStudio::Model::CoilHeatingDXSingleSpeed' => ['Heating Coil Electric Energy', 'Heating Coil Crankcase Heater Electric Energy', 'Heating Coil Defrost Electric Energy'],
             'OpenStudio::Model::CoilHeatingDXMultiSpeed' => ['Heating Coil Electric Energy', 'Heating Coil Crankcase Heater Electric Energy', 'Heating Coil Defrost Electric Energy'],
             'OpenStudio::Model::CoilHeatingElectric' => ['Heating Coil Electric Energy', 'Heating Coil Crankcase Heater Electric Energy', 'Heating Coil Defrost Electric Energy'],
             'OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit' => ['Heating Coil Electric Energy', 'Heating Coil Crankcase Heater Electric Energy', 'Heating Coil Defrost Electric Energy'],
             'OpenStudio::Model::CoilHeatingGas' => [],
             'OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric' => ['Baseboard Electric Energy'],
             'OpenStudio::Model::BoilerHotWater' => ['Boiler Electric Energy'],
             'OpenStudio::Model::FanOnOff' => ['Fan Electric Energy'] }
  end

  def self.SpaceHeatingFuel
    return { 'OpenStudio::Model::CoilHeatingDXSingleSpeed' => [],
             'OpenStudio::Model::CoilHeatingDXMultiSpeed' => [],
             'OpenStudio::Model::CoilHeatingElectric' => [],
             'OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit' => [],
             'OpenStudio::Model::CoilHeatingGas' => ['Heating Coil Gas Energy', 'Heating Coil Propane Energy', 'Heating Coil FuelOil#1 Energy'],
             'OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric' => ['Baseboard Gas Energy', 'Baseboard Propane Energy', 'Baseboard FuelOil#1 Energy'],
             'OpenStudio::Model::BoilerHotWater' => ['Boiler Gas Energy', 'Boiler Propane Energy', 'Boiler FuelOil#1 Energy'],
             'OpenStudio::Model::FanOnOff' => [] }
  end

  def self.SpaceHeatingLoad
    return { 'OpenStudio::Model::CoilHeatingDXSingleSpeed' => ['Heating Coil Heating Energy'],
             'OpenStudio::Model::CoilHeatingDXMultiSpeed' => ['Heating Coil Heating Energy'],
             'OpenStudio::Model::CoilHeatingElectric' => ['Heating Coil Heating Energy'],
             'OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit' => ['Heating Coil Heating Energy'],
             'OpenStudio::Model::CoilHeatingGas' => ['Heating Coil Heating Energy'],
             'OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric' => ['Baseboard Total Heating Energy'],
             'OpenStudio::Model::BoilerHotWater' => ['Boiler Heating Energy'],
             'OpenStudio::Model::FanOnOff' => ['Fan Electric Energy'] }
  end

  def self.SpaceCoolingElectricity
    return { 'OpenStudio::Model::CoilCoolingDXSingleSpeed' => ['Cooling Coil Electric Energy', 'Cooling Coil Crankcase Heater Electric Energy'],
             'OpenStudio::Model::CoilCoolingDXMultiSpeed' => ['Cooling Coil Electric Energy', 'Cooling Coil Crankcase Heater Electric Energy'],
             'OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit' => ['Cooling Coil Electric Energy', 'Cooling Coil Crankcase Heater Electric Energy'],
             'OpenStudio::Model::FanOnOff' => ['Fan Electric Energy'] }
  end

  def self.SpaceCoolingLoad
    return { 'OpenStudio::Model::CoilCoolingDXSingleSpeed' => ['Cooling Coil Total Cooling Energy'],
             'OpenStudio::Model::CoilCoolingDXMultiSpeed' => ['Cooling Coil Total Cooling Energy'],
             'OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit' => ['Cooling Coil Total Cooling Energy'],
             'OpenStudio::Model::FanOnOff' => ['Fan Electric Energy'] }
  end

  def self.WaterHeatingElectricity
    return { 'OpenStudio::Model::WaterHeaterMixed' => ['Water Heater Electric Energy', 'Water Heater Off Cycle Parasitic Electric Energy', 'Water Heater On Cycle Parasitic Electric Energy'],
             'OpenStudio::Model::WaterHeaterStratified' => ['Water Heater Electric Energy', 'Water Heater Off Cycle Parasitic Electric Energy', 'Water Heater On Cycle Parasitic Electric Energy'],
             'OpenStudio::Model::CoilWaterHeatingAirToWaterHeatPumpWrapped' => ['Cooling Coil Water Heating Electric Energy'],
             'OpenStudio::Model::WaterUseConnections' => [],
             'OpenStudio::Model::ElectricEquipment' => [] }
  end

  def self.WaterHeatingElectricityRecircPump
    return { 'OpenStudio::Model::WaterHeaterMixed' => [],
             'OpenStudio::Model::WaterHeaterStratified' => [],
             'OpenStudio::Model::CoilWaterHeatingAirToWaterHeatPumpWrapped' => [],
             'OpenStudio::Model::WaterUseConnections' => [],
             'OpenStudio::Model::ElectricEquipment' => ['Electric Equipment Electric Energy'] }
  end

  def self.WaterHeatingFuel
    return { 'OpenStudio::Model::WaterHeaterMixed' => ['Water Heater Gas Energy', 'Water Heater Propane Energy', 'Water Heater FuelOil#1 Energy'],
             'OpenStudio::Model::WaterHeaterStratified' => ['Water Heater Gas Energy', 'Water Heater Propane Energy', 'Water Heater FuelOil#1 Energy'],
             'OpenStudio::Model::CoilWaterHeatingAirToWaterHeatPumpWrapped' => [],
             'OpenStudio::Model::WaterUseConnections' => [],
             'OpenStudio::Model::ElectricEquipment' => [] }
  end

  def self.WaterHeatingLoad
    return { 'OpenStudio::Model::WaterHeaterMixed' => [],
             'OpenStudio::Model::WaterHeaterStratified' => [],
             'OpenStudio::Model::CoilWaterHeatingAirToWaterHeatPumpWrapped' => [],
             'OpenStudio::Model::WaterUseConnections' => ['Water Use Connections Plant Hot Water Energy'],
             'OpenStudio::Model::ElectricEquipment' => [] }
  end
end

# register the measure to be used by the application
HPXMLTranslator.new.registerWithApplication
