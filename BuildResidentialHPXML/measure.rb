# frozen_string_literal: true

# Require all gems up front; this is much faster than multiple resource
# files lazy loading as needed, as it prevents multiple lookups for the
# same gem.
require 'openstudio'
require 'pathname'
require 'csv'
require 'oga'
Dir["#{File.dirname(__FILE__)}/resources/*.rb"].each do |resource_file|
  require resource_file
end
Dir["#{File.dirname(__FILE__)}/../HPXMLtoOpenStudio/resources/*.rb"].each do |resource_file|
  next if resource_file.include? 'minitest_helper.rb'

  require resource_file
end

# start the measure
class BuildResidentialHPXML < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'HPXML Builder'
  end

  # human readable description
  def description
    return 'Builds a residential HPXML file.'
  end

  # human readable description of modeling approach
  def modeler_description
    return "Note: OS-HPXML default values can be found in the OS-HPXML documentation or can be seen by using the 'apply_defaults' argument."
  end

  # define the arguments that the user will input
  def arguments(model) # rubocop:disable Lint/UnusedMethodArgument
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hpxml_path', true)
    arg.setDisplayName('HPXML File Path')
    arg.setDescription('Absolute/relative path of the HPXML file.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('software_info_program_used', false)
    arg.setDisplayName('Software Info: Program Used')
    arg.setDescription('The name of the software program used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('software_info_program_version', false)
    arg.setDisplayName('Software Info: Program Version')
    arg.setDescription('The version of the software program used.')
    args << arg

    occupancy_calculation_type_choices = OpenStudio::StringVector.new
    occupancy_calculation_type_choices << HPXML::OccupancyCalculationTypeAsset
    occupancy_calculation_type_choices << HPXML::OccupancyCalculationTypeOperational

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('occupancy_calculation_type', occupancy_calculation_type_choices, false)
    arg.setDisplayName('Occupancy Calculation Type')
    arg.setDescription("The type of occupancy calculation type. If '#{HPXML::OccupancyCalculationTypeAsset}' is chosen, various end uses (e.g., clothes washer) are calculated using number of bedrooms and/or conditioned floor area. If '#{HPXML::OccupancyCalculationTypeOperational}' is chosen, end uses based on number of bedrooms are adjusted for the number of occupants. If not provided, the OS-HPXML default is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('schedules_filepaths', false)
    arg.setDisplayName('Schedules: CSV File Paths')
    arg.setDescription('Absolute/relative paths of csv files containing user-specified detailed schedules. If multiple files, use a comma-separated list.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('simulation_control_timestep', false)
    arg.setDisplayName('Simulation Control: Timestep')
    arg.setUnits('min')
    arg.setDescription('Value must be a divisor of 60. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('simulation_control_run_period', false)
    arg.setDisplayName('Simulation Control: Run Period')
    arg.setDescription('Enter a date like "Jan 1 - Dec 31". If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('simulation_control_run_period_calendar_year', false)
    arg.setDisplayName('Simulation Control: Run Period Calendar Year')
    arg.setUnits('year')
    arg.setDescription('This numeric field should contain the calendar year that determines the start day of week. If you are running simulations using AMY weather files, the value entered for calendar year will not be used; it will be overridden by the actual year found in the AMY weather file. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('simulation_control_daylight_saving_enabled', false)
    arg.setDisplayName('Simulation Control: Daylight Saving Enabled')
    arg.setDescription('Whether to use daylight saving. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('simulation_control_daylight_saving_period', false)
    arg.setDisplayName('Simulation Control: Daylight Saving Period')
    arg.setDescription('Enter a date like "Mar 15 - Dec 15". If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('simulation_control_temperature_capacitance_multiplier', false)
    arg.setDisplayName('Simulation Control: Temperature Capacitance Multiplier')
    arg.setDescription('Affects the transient calculation of indoor air temperatures. If not provided, the OS-HPXML default is used.')
    args << arg

    site_type_choices = OpenStudio::StringVector.new
    site_type_choices << HPXML::SiteTypeSuburban
    site_type_choices << HPXML::SiteTypeUrban
    site_type_choices << HPXML::SiteTypeRural

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('site_type', site_type_choices, false)
    arg.setDisplayName('Site: Type')
    arg.setDescription('The type of site. If not provided, the OS-HPXML default is used.')
    args << arg

    site_shielding_of_home_choices = OpenStudio::StringVector.new
    site_shielding_of_home_choices << HPXML::ShieldingExposed
    site_shielding_of_home_choices << HPXML::ShieldingNormal
    site_shielding_of_home_choices << HPXML::ShieldingWellShielded

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('site_shielding_of_home', site_shielding_of_home_choices, false)
    arg.setDisplayName('Site: Shielding of Home')
    arg.setDescription('Presence of nearby buildings, trees, obstructions for infiltration model. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('site_ground_conductivity', false)
    arg.setDisplayName('Site: Ground Conductivity')
    arg.setDescription('Conductivity of the ground soil. If not provided, the OS-HPXML default is used.')
    arg.setUnits('Btu/hr-ft-F')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('site_zip_code', false)
    arg.setDisplayName('Site: Zip Code')
    arg.setDescription('Zip code of the home address.')
    args << arg

    site_iecc_zone_choices = OpenStudio::StringVector.new
    Constants.IECCZones.each do |iz|
      site_iecc_zone_choices << iz
    end

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('site_iecc_zone', site_iecc_zone_choices, false)
    arg.setDisplayName('Site: IECC Zone')
    arg.setDescription('IECC zone of the home address.')
    args << arg

    site_state_code_choices = OpenStudio::StringVector.new
    Constants.StateCodesMap.keys.each do |sc|
      site_state_code_choices << sc
    end

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('site_state_code', site_state_code_choices, false)
    arg.setDisplayName('Site: State Code')
    arg.setDescription('State code of the home address.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('site_time_zone_utc_offset', false)
    arg.setDisplayName('Site: Time Zone UTC Offset')
    arg.setDescription('Time zone UTC offset of the home address. Must be between -12 and 14.')
    arg.setUnits('hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('weather_station_epw_filepath', true)
    arg.setDisplayName('Weather Station: EnergyPlus Weather (EPW) Filepath')
    arg.setDescription('Path of the EPW file.')
    arg.setDefaultValue('USA_CO_Denver.Intl.AP.725650_TMY3.epw')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('year_built', false)
    arg.setDisplayName('Building Construction: Year Built')
    arg.setDescription('The year the building was built.')
    args << arg

    unit_type_choices = OpenStudio::StringVector.new
    unit_type_choices << HPXML::ResidentialTypeSFD
    unit_type_choices << HPXML::ResidentialTypeSFA
    unit_type_choices << HPXML::ResidentialTypeApartment

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_unit_type', unit_type_choices, true)
    arg.setDisplayName('Geometry: Unit Type')
    arg.setDescription("The type of dwelling unit. Use #{HPXML::ResidentialTypeSFA} for a dwelling unit with 1 or more stories, attached units to one or both sides, and no units above/below. Use #{HPXML::ResidentialTypeApartment} for a dwelling unit with 1 story, attached units to one, two, or three sides, and units above and/or below.")
    arg.setDefaultValue(HPXML::ResidentialTypeSFD)
    args << arg

    level_choices = OpenStudio::StringVector.new
    level_choices << 'Bottom'
    level_choices << 'Middle'
    level_choices << 'Top'

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('geometry_unit_left_wall_is_adiabatic', true)
    arg.setDisplayName('Geometry: Unit Left Wall Is Adiabatic')
    arg.setDescription('Presence of an adiabatic left wall.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('geometry_unit_right_wall_is_adiabatic', true)
    arg.setDisplayName('Geometry: Unit Right Wall Is Adiabatic')
    arg.setDescription('Presence of an adiabatic right wall.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('geometry_unit_front_wall_is_adiabatic', true)
    arg.setDisplayName('Geometry: Unit Front Wall Is Adiabatic')
    arg.setDescription('Presence of an adiabatic front wall, for example, the unit is adjacent to a conditioned corridor.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('geometry_unit_back_wall_is_adiabatic', true)
    arg.setDisplayName('Geometry: Unit Back Wall Is Adiabatic')
    arg.setDescription('Presence of an adiabatic back wall.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('geometry_unit_num_floors_above_grade', true)
    arg.setDisplayName('Geometry: Unit Number of Floors Above Grade')
    arg.setUnits('#')
    arg.setDescription("The number of floors above grade in the unit. Attic type #{HPXML::AtticTypeConditioned} is included. Assumed to be 1 for #{HPXML::ResidentialTypeApartment}s.")
    arg.setDefaultValue(2)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_unit_cfa', true)
    arg.setDisplayName('Geometry: Unit Conditioned Floor Area')
    arg.setUnits('ft^2')
    arg.setDescription("The total floor area of the unit's conditioned space (including any conditioned basement floor area).")
    arg.setDefaultValue(2000.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_unit_aspect_ratio', true)
    arg.setDisplayName('Geometry: Unit Aspect Ratio')
    arg.setUnits('Frac')
    arg.setDescription('The ratio of front/back wall length to left/right wall length for the unit, excluding any protruding garage wall area.')
    arg.setDefaultValue(2.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_unit_orientation', true)
    arg.setDisplayName('Geometry: Unit Orientation')
    arg.setUnits('degrees')
    arg.setDescription("The unit's orientation is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).")
    arg.setDefaultValue(180.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('geometry_unit_num_bedrooms', true)
    arg.setDisplayName('Geometry: Unit Number of Bedrooms')
    arg.setUnits('#')
    arg.setDescription('The number of bedrooms in the unit. Used to determine the energy usage of appliances and plug loads, hot water usage, etc.')
    arg.setDefaultValue(3)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('geometry_unit_num_bathrooms', false)
    arg.setDisplayName('Geometry: Unit Number of Bathrooms')
    arg.setUnits('#')
    arg.setDescription('The number of bathrooms in the unit. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_unit_num_occupants', false)
    arg.setDisplayName('Geometry: Unit Number of Occupants')
    arg.setUnits('#')
    arg.setDescription("The number of occupants in the unit. If not provided, the OS-HPXML default is used. Required if Occupancy Calculation Type is '#{HPXML::OccupancyCalculationTypeOperational}'.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('geometry_building_num_units', false)
    arg.setDisplayName('Geometry: Building Number of Units')
    arg.setUnits('#')
    arg.setDescription("The number of units in the building. Required for #{HPXML::ResidentialTypeSFA} and #{HPXML::ResidentialTypeApartment}s.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_average_ceiling_height', true)
    arg.setDisplayName('Geometry: Average Ceiling Height')
    arg.setUnits('ft')
    arg.setDescription('Average distance from the floor to the ceiling.')
    arg.setDefaultValue(8.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_garage_width', true)
    arg.setDisplayName('Geometry: Garage Width')
    arg.setUnits('ft')
    arg.setDescription("The width of the garage. Enter zero for no garage. Only applies to #{HPXML::ResidentialTypeSFD} units.")
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_garage_depth', true)
    arg.setDisplayName('Geometry: Garage Depth')
    arg.setUnits('ft')
    arg.setDescription("The depth of the garage. Only applies to #{HPXML::ResidentialTypeSFD} units.")
    arg.setDefaultValue(20.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_garage_protrusion', true)
    arg.setDisplayName('Geometry: Garage Protrusion')
    arg.setUnits('Frac')
    arg.setDescription("The fraction of the garage that is protruding from the living space. Only applies to #{HPXML::ResidentialTypeSFD} units.")
    arg.setDefaultValue(0.0)
    args << arg

    garage_position_choices = OpenStudio::StringVector.new
    garage_position_choices << 'Right'
    garage_position_choices << 'Left'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_garage_position', garage_position_choices, true)
    arg.setDisplayName('Geometry: Garage Position')
    arg.setDescription("The position of the garage. Only applies to #{HPXML::ResidentialTypeSFD} units.")
    arg.setDefaultValue('Right')
    args << arg

    foundation_type_choices = OpenStudio::StringVector.new
    foundation_type_choices << HPXML::FoundationTypeSlab
    foundation_type_choices << HPXML::FoundationTypeCrawlspaceVented
    foundation_type_choices << HPXML::FoundationTypeCrawlspaceUnvented
    foundation_type_choices << HPXML::FoundationTypeCrawlspaceConditioned
    foundation_type_choices << HPXML::FoundationTypeBasementUnconditioned
    foundation_type_choices << HPXML::FoundationTypeBasementConditioned
    foundation_type_choices << HPXML::FoundationTypeAmbient
    foundation_type_choices << HPXML::FoundationTypeAboveApartment # I.e., adiabatic

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_foundation_type', foundation_type_choices, true)
    arg.setDisplayName('Geometry: Foundation Type')
    arg.setDescription("The foundation type of the building. Foundation types #{HPXML::FoundationTypeBasementConditioned} and #{HPXML::FoundationTypeCrawlspaceConditioned} are not allowed for #{HPXML::ResidentialTypeApartment}s.")
    arg.setDefaultValue(HPXML::FoundationTypeSlab)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_foundation_height', true)
    arg.setDisplayName('Geometry: Foundation Height')
    arg.setUnits('ft')
    arg.setDescription('The height of the foundation (e.g., 3ft for crawlspace, 8ft for basement). Only applies to basements/crawlspaces.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_foundation_height_above_grade', true)
    arg.setDisplayName('Geometry: Foundation Height Above Grade')
    arg.setUnits('ft')
    arg.setDescription('The depth above grade of the foundation wall. Only applies to basements/crawlspaces.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_rim_joist_height', false)
    arg.setDisplayName('Geometry: Rim Joist Height')
    arg.setUnits('in')
    arg.setDescription('The height of the rim joists. Only applies to basements/crawlspaces.')
    args << arg

    attic_type_choices = OpenStudio::StringVector.new
    attic_type_choices << HPXML::AtticTypeFlatRoof
    attic_type_choices << HPXML::AtticTypeVented
    attic_type_choices << HPXML::AtticTypeUnvented
    attic_type_choices << HPXML::AtticTypeConditioned
    attic_type_choices << HPXML::AtticTypeBelowApartment # I.e., adiabatic

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_attic_type', attic_type_choices, true)
    arg.setDisplayName('Geometry: Attic Type')
    arg.setDescription("The attic type of the building. Attic type #{HPXML::AtticTypeConditioned} is not allowed for #{HPXML::ResidentialTypeApartment}s.")
    arg.setDefaultValue(HPXML::AtticTypeVented)
    args << arg

    roof_type_choices = OpenStudio::StringVector.new
    roof_type_choices << 'gable'
    roof_type_choices << 'hip'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_roof_type', roof_type_choices, true)
    arg.setDisplayName('Geometry: Roof Type')
    arg.setDescription('The roof type of the building. Ignored if the building has a flat roof.')
    arg.setDefaultValue('gable')
    args << arg

    roof_pitch_choices = OpenStudio::StringVector.new
    roof_pitch_choices << '1:12'
    roof_pitch_choices << '2:12'
    roof_pitch_choices << '3:12'
    roof_pitch_choices << '4:12'
    roof_pitch_choices << '5:12'
    roof_pitch_choices << '6:12'
    roof_pitch_choices << '7:12'
    roof_pitch_choices << '8:12'
    roof_pitch_choices << '9:12'
    roof_pitch_choices << '10:12'
    roof_pitch_choices << '11:12'
    roof_pitch_choices << '12:12'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_roof_pitch', roof_pitch_choices, true)
    arg.setDisplayName('Geometry: Roof Pitch')
    arg.setDescription('The roof pitch of the attic. Ignored if the building has a flat roof.')
    arg.setDefaultValue('6:12')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_eaves_depth', true)
    arg.setDisplayName('Geometry: Eaves Depth')
    arg.setUnits('ft')
    arg.setDescription('The eaves depth of the roof.')
    arg.setDefaultValue(2.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('geometry_has_flue_or_chimney', false)
    arg.setDisplayName('Geometry: Has Flue or Chimney')
    arg.setDescription('Presence of flue or chimney for infiltration model. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_front_distance', true)
    arg.setDisplayName('Neighbor: Front Distance')
    arg.setUnits('ft')
    arg.setDescription('The distance between the unit and the neighboring building to the front (not including eaves). A value of zero indicates no neighbors. Used for shading.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_back_distance', true)
    arg.setDisplayName('Neighbor: Back Distance')
    arg.setUnits('ft')
    arg.setDescription('The distance between the unit and the neighboring building to the back (not including eaves). A value of zero indicates no neighbors. Used for shading.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_left_distance', true)
    arg.setDisplayName('Neighbor: Left Distance')
    arg.setUnits('ft')
    arg.setDescription('The distance between the unit and the neighboring building to the left (not including eaves). A value of zero indicates no neighbors. Used for shading.')
    arg.setDefaultValue(10.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_right_distance', true)
    arg.setDisplayName('Neighbor: Right Distance')
    arg.setUnits('ft')
    arg.setDescription('The distance between the unit and the neighboring building to the right (not including eaves). A value of zero indicates no neighbors. Used for shading.')
    arg.setDefaultValue(10.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_front_height', false)
    arg.setDisplayName('Neighbor: Front Height')
    arg.setUnits('ft')
    arg.setDescription('The height of the neighboring building to the front. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_back_height', false)
    arg.setDisplayName('Neighbor: Back Height')
    arg.setUnits('ft')
    arg.setDescription('The height of the neighboring building to the back. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_left_height', false)
    arg.setDisplayName('Neighbor: Left Height')
    arg.setUnits('ft')
    arg.setDescription('The height of the neighboring building to the left. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_right_height', false)
    arg.setDisplayName('Neighbor: Right Height')
    arg.setUnits('ft')
    arg.setDescription('The height of the neighboring building to the right. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('floor_over_foundation_assembly_r', true)
    arg.setDisplayName('Floor: Over Foundation Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value for the floor over the foundation. Ignored if the building has a slab-on-grade foundation.')
    arg.setDefaultValue(28.1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('floor_over_garage_assembly_r', true)
    arg.setDisplayName('Floor: Over Garage Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value for the floor over the garage. Ignored unless the building has a garage under conditioned space.')
    arg.setDefaultValue(28.1)
    args << arg

    floor_type_choices = OpenStudio::StringVector.new
    floor_type_choices << HPXML::FloorTypeWoodFrame
    floor_type_choices << HPXML::FloorTypeSIP
    floor_type_choices << HPXML::FloorTypeConcrete
    floor_type_choices << HPXML::FloorTypeSteelFrame

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('floor_type', floor_type_choices, true)
    arg.setDisplayName('Floor: Type')
    arg.setDescription('The type of floors.')
    arg.setDefaultValue(HPXML::FloorTypeWoodFrame)
    args << arg

    foundation_wall_type_choices = OpenStudio::StringVector.new
    foundation_wall_type_choices << HPXML::FoundationWallTypeSolidConcrete
    foundation_wall_type_choices << HPXML::FoundationWallTypeConcreteBlock
    foundation_wall_type_choices << HPXML::FoundationWallTypeConcreteBlockFoamCore
    foundation_wall_type_choices << HPXML::FoundationWallTypeConcreteBlockPerliteCore
    foundation_wall_type_choices << HPXML::FoundationWallTypeConcreteBlockVermiculiteCore
    foundation_wall_type_choices << HPXML::FoundationWallTypeConcreteBlockSolidCore
    foundation_wall_type_choices << HPXML::FoundationWallTypeDoubleBrick
    foundation_wall_type_choices << HPXML::FoundationWallTypeWood

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('foundation_wall_type', foundation_wall_type_choices, false)
    arg.setDisplayName('Foundation Wall: Type')
    arg.setDescription('The material type of the foundation wall. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('foundation_wall_thickness', false)
    arg.setDisplayName('Foundation Wall: Thickness')
    arg.setUnits('in')
    arg.setDescription('The thickness of the foundation wall. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('foundation_wall_insulation_r', true)
    arg.setDisplayName('Foundation Wall: Insulation Nominal R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Nominal R-value for the foundation wall insulation. Only applies to basements/crawlspaces.')
    arg.setDefaultValue(0)
    args << arg

    wall_ins_location_choices = OpenStudio::StringVector.new
    wall_ins_location_choices << 'interior'
    wall_ins_location_choices << 'exterior'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('foundation_wall_insulation_location', wall_ins_location_choices, false)
    arg.setDisplayName('Foundation Wall: Insulation Location')
    arg.setUnits('ft')
    arg.setDescription('Whether the insulation is on the interior or exterior of the foundation wall. Only applies to basements/crawlspaces.')
    arg.setDefaultValue('exterior')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('foundation_wall_insulation_distance_to_top', false)
    arg.setDisplayName('Foundation Wall: Insulation Distance To Top')
    arg.setUnits('ft')
    arg.setDescription('The distance from the top of the foundation wall to the top of the foundation wall insulation. Only applies to basements/crawlspaces. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('foundation_wall_insulation_distance_to_bottom', false)
    arg.setDisplayName('Foundation Wall: Insulation Distance To Bottom')
    arg.setUnits('ft')
    arg.setDescription('The distance from the top of the foundation wall to the bottom of the foundation wall insulation. Only applies to basements/crawlspaces. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('foundation_wall_assembly_r', false)
    arg.setDisplayName('Foundation Wall: Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value for the foundation walls. Only applies to basements/crawlspaces. If provided, overrides the previous foundation wall insulation inputs. If not provided, it is ignored.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('rim_joist_assembly_r', false)
    arg.setDisplayName('Rim Joist: Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value for the rim joists. Only applies to basements/crawlspaces. Required if a rim joist height is provided.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('slab_perimeter_insulation_r', true)
    arg.setDisplayName('Slab: Perimeter Insulation Nominal R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Nominal R-value of the vertical slab perimeter insulation. Applies to slab-on-grade foundations and basement/crawlspace floors.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('slab_perimeter_depth', true)
    arg.setDisplayName('Slab: Perimeter Insulation Depth')
    arg.setUnits('ft')
    arg.setDescription('Depth from grade to bottom of vertical slab perimeter insulation. Applies to slab-on-grade foundations and basement/crawlspace floors.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('slab_under_insulation_r', true)
    arg.setDisplayName('Slab: Under Slab Insulation Nominal R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Nominal R-value of the horizontal under slab insulation. Applies to slab-on-grade foundations and basement/crawlspace floors.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('slab_under_width', true)
    arg.setDisplayName('Slab: Under Slab Insulation Width')
    arg.setUnits('ft')
    arg.setDescription('Width from slab edge inward of horizontal under-slab insulation. Enter 999 to specify that the under slab insulation spans the entire slab. Applies to slab-on-grade foundations and basement/crawlspace floors.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('slab_thickness', false)
    arg.setDisplayName('Slab: Thickness')
    arg.setUnits('in')
    arg.setDescription('The thickness of the slab. Zero can be entered if there is a dirt floor instead of a slab. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('slab_carpet_fraction', false)
    arg.setDisplayName('Slab: Carpet Fraction')
    arg.setUnits('Frac')
    arg.setDescription('Fraction of the slab floor area that is carpeted. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('slab_carpet_r', false)
    arg.setDisplayName('Slab: Carpet R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('R-value of the slab carpet. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_assembly_r', true)
    arg.setDisplayName('Ceiling: Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value for the ceiling (attic floor).')
    arg.setDefaultValue(31.6)
    args << arg

    roof_material_type_choices = OpenStudio::StringVector.new
    roof_material_type_choices << HPXML::RoofTypeAsphaltShingles
    roof_material_type_choices << HPXML::RoofTypeConcrete
    roof_material_type_choices << HPXML::RoofTypeCool
    roof_material_type_choices << HPXML::RoofTypeClayTile
    roof_material_type_choices << HPXML::RoofTypeEPS
    roof_material_type_choices << HPXML::RoofTypeMetal
    roof_material_type_choices << HPXML::RoofTypePlasticRubber
    roof_material_type_choices << HPXML::RoofTypeShingles
    roof_material_type_choices << HPXML::RoofTypeWoodShingles

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('roof_material_type', roof_material_type_choices, false)
    arg.setDisplayName('Roof: Material Type')
    arg.setDescription('The material type of the roof. If not provided, the OS-HPXML default is used.')
    args << arg

    color_choices = OpenStudio::StringVector.new
    color_choices << HPXML::ColorDark
    color_choices << HPXML::ColorLight
    color_choices << HPXML::ColorMedium
    color_choices << HPXML::ColorMediumDark
    color_choices << HPXML::ColorReflective

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('roof_color', color_choices, false)
    arg.setDisplayName('Roof: Color')
    arg.setDescription('The color of the roof. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('roof_assembly_r', true)
    arg.setDisplayName('Roof: Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value of the roof.')
    arg.setDefaultValue(2.3)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('roof_radiant_barrier', true)
    arg.setDisplayName('Roof: Has Radiant Barrier')
    arg.setDescription('Presence of a radiant barrier in the attic.')
    arg.setDefaultValue(false)
    args << arg

    roof_radiant_barrier_grade_choices = OpenStudio::StringVector.new
    roof_radiant_barrier_grade_choices << '1'
    roof_radiant_barrier_grade_choices << '2'
    roof_radiant_barrier_grade_choices << '3'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('roof_radiant_barrier_grade', roof_radiant_barrier_grade_choices, true)
    arg.setDisplayName('Roof: Radiant Barrier Grade')
    arg.setDescription('The grade of the radiant barrier, if it exists.')
    arg.setDefaultValue('1')
    args << arg

    wall_type_choices = OpenStudio::StringVector.new
    wall_type_choices << HPXML::WallTypeWoodStud
    wall_type_choices << HPXML::WallTypeCMU
    wall_type_choices << HPXML::WallTypeDoubleWoodStud
    wall_type_choices << HPXML::WallTypeICF
    wall_type_choices << HPXML::WallTypeLog
    wall_type_choices << HPXML::WallTypeSIP
    wall_type_choices << HPXML::WallTypeConcrete
    wall_type_choices << HPXML::WallTypeSteelStud
    wall_type_choices << HPXML::WallTypeStone
    wall_type_choices << HPXML::WallTypeStrawBale
    wall_type_choices << HPXML::WallTypeBrick

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('wall_type', wall_type_choices, true)
    arg.setDisplayName('Wall: Type')
    arg.setDescription('The type of walls.')
    arg.setDefaultValue(HPXML::WallTypeWoodStud)
    args << arg

    wall_siding_type_choices = OpenStudio::StringVector.new
    wall_siding_type_choices << HPXML::SidingTypeAluminum
    wall_siding_type_choices << HPXML::SidingTypeAsbestos
    wall_siding_type_choices << HPXML::SidingTypeBrick
    wall_siding_type_choices << HPXML::SidingTypeCompositeShingle
    wall_siding_type_choices << HPXML::SidingTypeFiberCement
    wall_siding_type_choices << HPXML::SidingTypeMasonite
    wall_siding_type_choices << HPXML::SidingTypeNone
    wall_siding_type_choices << HPXML::SidingTypeStucco
    wall_siding_type_choices << HPXML::SidingTypeSyntheticStucco
    wall_siding_type_choices << HPXML::SidingTypeVinyl
    wall_siding_type_choices << HPXML::SidingTypeWood

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('wall_siding_type', wall_siding_type_choices, false)
    arg.setDisplayName('Wall: Siding Type')
    arg.setDescription('The siding type of the walls. Also applies to rim joists. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('wall_color', color_choices, false)
    arg.setDisplayName('Wall: Color')
    arg.setDescription('The color of the walls. Also applies to rim joists. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('wall_assembly_r', true)
    arg.setDisplayName('Wall: Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value of the walls.')
    arg.setDefaultValue(11.9)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_front_wwr', true)
    arg.setDisplayName('Windows: Front Window-to-Wall Ratio')
    arg.setUnits('Frac')
    arg.setDescription("The ratio of window area to wall area for the unit's front facade. Enter 0 if specifying Front Window Area instead.")
    arg.setDefaultValue(0.18)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_back_wwr', true)
    arg.setDisplayName('Windows: Back Window-to-Wall Ratio')
    arg.setUnits('Frac')
    arg.setDescription("The ratio of window area to wall area for the unit's back facade. Enter 0 if specifying Back Window Area instead.")
    arg.setDefaultValue(0.18)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_left_wwr', true)
    arg.setDisplayName('Windows: Left Window-to-Wall Ratio')
    arg.setUnits('Frac')
    arg.setDescription("The ratio of window area to wall area for the unit's left facade (when viewed from the front). Enter 0 if specifying Left Window Area instead.")
    arg.setDefaultValue(0.18)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_right_wwr', true)
    arg.setDisplayName('Windows: Right Window-to-Wall Ratio')
    arg.setUnits('Frac')
    arg.setDescription("The ratio of window area to wall area for the unit's right facade (when viewed from the front). Enter 0 if specifying Right Window Area instead.")
    arg.setDefaultValue(0.18)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_area_front', true)
    arg.setDisplayName('Windows: Front Window Area')
    arg.setUnits('ft^2')
    arg.setDescription("The amount of window area on the unit's front facade. Enter 0 if specifying Front Window-to-Wall Ratio instead.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_area_back', true)
    arg.setDisplayName('Windows: Back Window Area')
    arg.setUnits('ft^2')
    arg.setDescription("The amount of window area on the unit's back facade. Enter 0 if specifying Back Window-to-Wall Ratio instead.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_area_left', true)
    arg.setDisplayName('Windows: Left Window Area')
    arg.setUnits('ft^2')
    arg.setDescription("The amount of window area on the unit's left facade (when viewed from the front). Enter 0 if specifying Left Window-to-Wall Ratio instead.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_area_right', true)
    arg.setDisplayName('Windows: Right Window Area')
    arg.setUnits('ft^2')
    arg.setDescription("The amount of window area on the unit's right facade (when viewed from the front). Enter 0 if specifying Right Window-to-Wall Ratio instead.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_aspect_ratio', true)
    arg.setDisplayName('Windows: Aspect Ratio')
    arg.setUnits('Frac')
    arg.setDescription('Ratio of window height to width.')
    arg.setDefaultValue(1.333)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_fraction_operable', false)
    arg.setDisplayName('Windows: Fraction Operable')
    arg.setUnits('Frac')
    arg.setDescription('Fraction of windows that are operable. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('window_natvent_availability', false)
    arg.setDisplayName('Windows: Natural Ventilation Availability')
    arg.setUnits('Days/week')
    arg.setDescription('For operable windows, the number of days/week that windows can be opened by occupants for natural ventilation. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_ufactor', true)
    arg.setDisplayName('Windows: U-Factor')
    arg.setUnits('Btu/hr-ft^2-R')
    arg.setDescription('Full-assembly NFRC U-factor.')
    arg.setDefaultValue(0.37)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_shgc', true)
    arg.setDisplayName('Windows: SHGC')
    arg.setDescription('Full-assembly NFRC solar heat gain coefficient.')
    arg.setDefaultValue(0.3)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_interior_shading_winter', false)
    arg.setDisplayName('Windows: Winter Interior Shading')
    arg.setUnits('Frac')
    arg.setDescription('Interior shading multiplier for the heating season. 1.0 indicates no reduction in solar gain, 0.85 indicates 15% reduction, etc. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_interior_shading_summer', false)
    arg.setDisplayName('Windows: Summer Interior Shading')
    arg.setUnits('Frac')
    arg.setDescription('Interior shading multiplier for the cooling season. 1.0 indicates no reduction in solar gain, 0.85 indicates 15% reduction, etc. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_exterior_shading_winter', false)
    arg.setDisplayName('Windows: Winter Exterior Shading')
    arg.setUnits('Frac')
    arg.setDescription('Exterior shading multiplier for the heating season. 1.0 indicates no reduction in solar gain, 0.85 indicates 15% reduction, etc. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_exterior_shading_summer', false)
    arg.setDisplayName('Windows: Summer Exterior Shading')
    arg.setUnits('Frac')
    arg.setDescription('Exterior shading multiplier for the cooling season. 1.0 indicates no reduction in solar gain, 0.85 indicates 15% reduction, etc. If not provided, the OS-HPXML default is used.')
    args << arg

    storm_window_type_choices = OpenStudio::StringVector.new
    storm_window_type_choices << HPXML::WindowGlassTypeClear
    storm_window_type_choices << HPXML::WindowGlassTypeLowE

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('window_storm_type', storm_window_type_choices, false)
    arg.setDisplayName('Windows: Storm Type')
    arg.setDescription('The type of storm, if present. If not provided, assumes there is no storm.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_front_depth', true)
    arg.setDisplayName('Overhangs: Front Depth')
    arg.setUnits('ft')
    arg.setDescription('The depth of overhangs for windows for the front facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_front_distance_to_top_of_window', true)
    arg.setDisplayName('Overhangs: Front Distance to Top of Window')
    arg.setUnits('ft')
    arg.setDescription('The overhangs distance to the top of window for the front facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_front_distance_to_bottom_of_window', true)
    arg.setDisplayName('Overhangs: Front Distance to Bottom of Window')
    arg.setUnits('ft')
    arg.setDescription('The overhangs distance to the bottom of window for the front facade.')
    arg.setDefaultValue(4)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_back_depth', true)
    arg.setDisplayName('Overhangs: Back Depth')
    arg.setUnits('ft')
    arg.setDescription('The depth of overhangs for windows for the back facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_back_distance_to_top_of_window', true)
    arg.setDisplayName('Overhangs: Back Distance to Top of Window')
    arg.setUnits('ft')
    arg.setDescription('The overhangs distance to the top of window for the back facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_back_distance_to_bottom_of_window', true)
    arg.setDisplayName('Overhangs: Back Distance to Bottom of Window')
    arg.setUnits('ft')
    arg.setDescription('The overhangs distance to the bottom of window for the back facade.')
    arg.setDefaultValue(4)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_left_depth', true)
    arg.setDisplayName('Overhangs: Left Depth')
    arg.setUnits('ft')
    arg.setDescription('The depth of overhangs for windows for the left facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_left_distance_to_top_of_window', true)
    arg.setDisplayName('Overhangs: Left Distance to Top of Window')
    arg.setUnits('ft')
    arg.setDescription('The overhangs distance to the top of window for the left facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_left_distance_to_bottom_of_window', true)
    arg.setDisplayName('Overhangs: Left Distance to Bottom of Window')
    arg.setUnits('ft')
    arg.setDescription('The overhangs distance to the bottom of window for the left facade.')
    arg.setDefaultValue(4)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_right_depth', true)
    arg.setDisplayName('Overhangs: Right Depth')
    arg.setUnits('ft')
    arg.setDescription('The depth of overhangs for windows for the right facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_right_distance_to_top_of_window', true)
    arg.setDisplayName('Overhangs: Right Distance to Top of Window')
    arg.setUnits('ft')
    arg.setDescription('The overhangs distance to the top of window for the right facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_right_distance_to_bottom_of_window', true)
    arg.setDisplayName('Overhangs: Right Distance to Bottom of Window')
    arg.setUnits('ft')
    arg.setDescription('The overhangs distance to the bottom of window for the right facade.')
    arg.setDefaultValue(4)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_area_front', true)
    arg.setDisplayName('Skylights: Front Roof Area')
    arg.setUnits('ft^2')
    arg.setDescription("The amount of skylight area on the unit's front conditioned roof facade.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_area_back', true)
    arg.setDisplayName('Skylights: Back Roof Area')
    arg.setUnits('ft^2')
    arg.setDescription("The amount of skylight area on the unit's back conditioned roof facade.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_area_left', true)
    arg.setDisplayName('Skylights: Left Roof Area')
    arg.setUnits('ft^2')
    arg.setDescription("The amount of skylight area on the unit's left conditioned roof facade (when viewed from the front).")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_area_right', true)
    arg.setDisplayName('Skylights: Right Roof Area')
    arg.setUnits('ft^2')
    arg.setDescription("The amount of skylight area on the unit's right conditioned roof facade (when viewed from the front).")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_ufactor', true)
    arg.setDisplayName('Skylights: U-Factor')
    arg.setUnits('Btu/hr-ft^2-R')
    arg.setDescription('Full-assembly NFRC U-factor.')
    arg.setDefaultValue(0.33)
    args << arg

    skylight_shgc = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_shgc', true)
    skylight_shgc.setDisplayName('Skylights: SHGC')
    skylight_shgc.setDescription('Full-assembly NFRC solar heat gain coefficient.')
    skylight_shgc.setDefaultValue(0.45)
    args << skylight_shgc

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('skylight_storm_type', storm_window_type_choices, false)
    arg.setDisplayName('Skylights: Storm Type')
    arg.setDescription('The type of storm, if present. If not provided, assumes there is no storm.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('door_area', true)
    arg.setDisplayName('Doors: Area')
    arg.setUnits('ft^2')
    arg.setDescription('The area of the opaque door(s).')
    arg.setDefaultValue(20.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('door_rvalue', true)
    arg.setDisplayName('Doors: R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('R-value of the opaque door(s).')
    arg.setDefaultValue(4.4)
    args << arg

    air_leakage_units_choices = OpenStudio::StringVector.new
    air_leakage_units_choices << HPXML::UnitsACH
    air_leakage_units_choices << HPXML::UnitsCFM
    air_leakage_units_choices << HPXML::UnitsACHNatural

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('air_leakage_units', air_leakage_units_choices, true)
    arg.setDisplayName('Air Leakage: Units')
    arg.setDescription('The unit of measure for the air leakage.')
    arg.setDefaultValue(HPXML::UnitsACH)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('air_leakage_house_pressure', true)
    arg.setDisplayName('Air Leakage: House Pressure')
    arg.setUnits('Pa')
    arg.setDescription("The house pressure relative to outside. Required when units are #{HPXML::UnitsACH} or #{HPXML::UnitsCFM}.")
    arg.setDefaultValue(50)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('air_leakage_value', true)
    arg.setDisplayName('Air Leakage: Value')
    arg.setDescription('Air exchange rate value.')
    arg.setDefaultValue(3)
    args << arg

    heating_system_type_choices = OpenStudio::StringVector.new
    heating_system_type_choices << 'none'
    heating_system_type_choices << HPXML::HVACTypeFurnace
    heating_system_type_choices << HPXML::HVACTypeWallFurnace
    heating_system_type_choices << HPXML::HVACTypeFloorFurnace
    heating_system_type_choices << HPXML::HVACTypeBoiler
    heating_system_type_choices << HPXML::HVACTypeElectricResistance
    heating_system_type_choices << HPXML::HVACTypeStove
    heating_system_type_choices << HPXML::HVACTypePortableHeater
    heating_system_type_choices << HPXML::HVACTypeFireplace
    heating_system_type_choices << HPXML::HVACTypeFixedHeater
    heating_system_type_choices << "Shared #{HPXML::HVACTypeBoiler} w/ Baseboard"
    heating_system_type_choices << "Shared #{HPXML::HVACTypeBoiler} w/ Ductless Fan Coil"

    heating_system_fuel_choices = OpenStudio::StringVector.new
    heating_system_fuel_choices << HPXML::FuelTypeElectricity
    heating_system_fuel_choices << HPXML::FuelTypeNaturalGas
    heating_system_fuel_choices << HPXML::FuelTypeOil
    heating_system_fuel_choices << HPXML::FuelTypePropane
    heating_system_fuel_choices << HPXML::FuelTypeWoodCord
    heating_system_fuel_choices << HPXML::FuelTypeWoodPellets
    heating_system_fuel_choices << HPXML::FuelTypeCoal

    cooling_system_type_choices = OpenStudio::StringVector.new
    cooling_system_type_choices << 'none'
    cooling_system_type_choices << HPXML::HVACTypeCentralAirConditioner
    cooling_system_type_choices << HPXML::HVACTypeRoomAirConditioner
    cooling_system_type_choices << HPXML::HVACTypeEvaporativeCooler
    cooling_system_type_choices << HPXML::HVACTypeMiniSplitAirConditioner
    cooling_system_type_choices << HPXML::HVACTypePTAC

    cooling_efficiency_type_choices = OpenStudio::StringVector.new
    cooling_efficiency_type_choices << HPXML::UnitsSEER
    cooling_efficiency_type_choices << HPXML::UnitsSEER2
    cooling_efficiency_type_choices << HPXML::UnitsEER
    cooling_efficiency_type_choices << HPXML::UnitsCEER

    compressor_type_choices = OpenStudio::StringVector.new
    compressor_type_choices << HPXML::HVACCompressorTypeSingleStage
    compressor_type_choices << HPXML::HVACCompressorTypeTwoStage
    compressor_type_choices << HPXML::HVACCompressorTypeVariableSpeed

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heating_system_type', heating_system_type_choices, true)
    arg.setDisplayName('Heating System: Type')
    arg.setDescription("The type of heating system. Use 'none' if there is no heating system or if there is a heat pump serving a heating load.")
    arg.setDefaultValue(HPXML::HVACTypeFurnace)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heating_system_fuel', heating_system_fuel_choices, true)
    arg.setDisplayName('Heating System: Fuel Type')
    arg.setDescription("The fuel type of the heating system. Ignored for #{HPXML::HVACTypeElectricResistance}.")
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_heating_efficiency', true)
    arg.setDisplayName('Heating System: Rated AFUE or Percent')
    arg.setUnits('Frac')
    arg.setDescription('The rated heating efficiency value of the heating system.')
    arg.setDefaultValue(0.78)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_heating_capacity', false)
    arg.setDisplayName('Heating System: Heating Capacity')
    arg.setDescription('The output heating capacity of the heating system. If not provided, the OS-HPXML autosized default is used.')
    arg.setUnits('Btu/hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_fraction_heat_load_served', true)
    arg.setDisplayName('Heating System: Fraction Heat Load Served')
    arg.setDescription('The heating load served by the heating system.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_airflow_defect_ratio', false)
    arg.setDisplayName('Heating System: Airflow Defect Ratio')
    arg.setDescription("The airflow defect ratio, defined as (InstalledAirflow - DesignAirflow) / DesignAirflow, of the heating system per ANSI/RESNET/ACCA Standard 310. A value of zero means no airflow defect. Applies only to #{HPXML::HVACTypeFurnace}. If not provided, assumes no defect.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('cooling_system_type', cooling_system_type_choices, true)
    arg.setDisplayName('Cooling System: Type')
    arg.setDescription("The type of cooling system. Use 'none' if there is no cooling system or if there is a heat pump serving a cooling load.")
    arg.setDefaultValue(HPXML::HVACTypeCentralAirConditioner)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('cooling_system_cooling_efficiency_type', cooling_efficiency_type_choices, true)
    arg.setDisplayName('Cooling System: Efficiency Type')
    arg.setDescription("The efficiency type of the cooling system. System types #{HPXML::HVACTypeCentralAirConditioner} and #{HPXML::HVACTypeMiniSplitAirConditioner} use #{HPXML::UnitsSEER} or #{HPXML::UnitsSEER2}. System types #{HPXML::HVACTypeRoomAirConditioner} and #{HPXML::HVACTypePTAC} use #{HPXML::UnitsEER} or #{HPXML::UnitsCEER}. Ignored for system type #{HPXML::HVACTypeEvaporativeCooler}.")
    arg.setDefaultValue(HPXML::UnitsSEER)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_cooling_efficiency', true)
    arg.setDisplayName('Cooling System: Efficiency')
    arg.setDescription("The rated efficiency value of the cooling system. Ignored for #{HPXML::HVACTypeEvaporativeCooler}.")
    arg.setDefaultValue(13.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('cooling_system_cooling_compressor_type', compressor_type_choices, false)
    arg.setDisplayName('Cooling System: Cooling Compressor Type')
    arg.setDescription("The compressor type of the cooling system. Only applies to #{HPXML::HVACTypeCentralAirConditioner}. If not provided, the OS-HPXML default is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_cooling_sensible_heat_fraction', false)
    arg.setDisplayName('Cooling System: Cooling Sensible Heat Fraction')
    arg.setDescription("The sensible heat fraction of the cooling system. Ignored for #{HPXML::HVACTypeEvaporativeCooler}. If not provided, the OS-HPXML default is used.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_cooling_capacity', false)
    arg.setDisplayName('Cooling System: Cooling Capacity')
    arg.setDescription('The output cooling capacity of the cooling system. If not provided, the OS-HPXML autosized default is used.')
    arg.setUnits('Btu/hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_fraction_cool_load_served', true)
    arg.setDisplayName('Cooling System: Fraction Cool Load Served')
    arg.setDescription('The cooling load served by the cooling system.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('cooling_system_is_ducted', true)
    arg.setDisplayName('Cooling System: Is Ducted')
    arg.setDescription("Whether the cooling system is ducted or not. Only used for #{HPXML::HVACTypeMiniSplitAirConditioner} and #{HPXML::HVACTypeEvaporativeCooler}. It's assumed that #{HPXML::HVACTypeCentralAirConditioner} is ducted, and #{HPXML::HVACTypeRoomAirConditioner} and #{HPXML::HVACTypePTAC} are not ducted.")
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_airflow_defect_ratio', false)
    arg.setDisplayName('Cooling System: Airflow Defect Ratio')
    arg.setDescription("The airflow defect ratio, defined as (InstalledAirflow - DesignAirflow) / DesignAirflow, of the cooling system per ANSI/RESNET/ACCA Standard 310. A value of zero means no airflow defect. Applies only to #{HPXML::HVACTypeCentralAirConditioner} and ducted #{HPXML::HVACTypeMiniSplitAirConditioner}. If not provided, assumes no defect.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_charge_defect_ratio', false)
    arg.setDisplayName('Cooling System: Charge Defect Ratio')
    arg.setDescription("The refrigerant charge defect ratio, defined as (InstalledCharge - DesignCharge) / DesignCharge, of the cooling system per ANSI/RESNET/ACCA Standard 310. A value of zero means no refrigerant charge defect. Applies only to #{HPXML::HVACTypeCentralAirConditioner} and #{HPXML::HVACTypeMiniSplitAirConditioner}. If not provided, assumes no defect.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('cooling_system_integrated_heating_system_fuel', heating_system_fuel_choices, false)
    arg.setDisplayName('Cooling System: Integrated Heating System Fuel Type')
    arg.setDescription("The fuel type of the heating system integrated into cooling system. Only used for #{HPXML::HVACTypePTAC} and #{HPXML::HVACTypeRoomAirConditioner}.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_integrated_heating_system_efficiency_percent', false)
    arg.setDisplayName('Cooling System: Integrated Heating System Efficiency')
    arg.setUnits('Frac')
    arg.setDescription("The rated heating efficiency value of the heating system integrated into cooling system. Only used for #{HPXML::HVACTypePTAC} and #{HPXML::HVACTypeRoomAirConditioner}.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_integrated_heating_system_capacity', false)
    arg.setDisplayName('Cooling System: Integrated Heating System Heating Capacity')
    arg.setDescription("The output heating capacity of the heating system integrated into cooling system. If not provided, the OS-HPXML autosized default is used. Only used for #{HPXML::HVACTypePTAC} and #{HPXML::HVACTypeRoomAirConditioner}.")
    arg.setUnits('Btu/hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_integrated_heating_system_fraction_heat_load_served', false)
    arg.setDisplayName('Cooling System: Integrated Heating System Fraction Heat Load Served')
    arg.setDescription("The heating load served by the heating system integrated into cooling system. Only used for #{HPXML::HVACTypePTAC} and #{HPXML::HVACTypeRoomAirConditioner}.")
    arg.setUnits('Frac')
    args << arg

    heat_pump_type_choices = OpenStudio::StringVector.new
    heat_pump_type_choices << 'none'
    heat_pump_type_choices << HPXML::HVACTypeHeatPumpAirToAir
    heat_pump_type_choices << HPXML::HVACTypeHeatPumpMiniSplit
    heat_pump_type_choices << HPXML::HVACTypeHeatPumpGroundToAir
    heat_pump_type_choices << HPXML::HVACTypeHeatPumpPTHP
    heat_pump_type_choices << HPXML::HVACTypeHeatPumpRoom

    heat_pump_heating_efficiency_type_choices = OpenStudio::StringVector.new
    heat_pump_heating_efficiency_type_choices << HPXML::UnitsHSPF
    heat_pump_heating_efficiency_type_choices << HPXML::UnitsHSPF2
    heat_pump_heating_efficiency_type_choices << HPXML::UnitsCOP

    heat_pump_fuel_choices = OpenStudio::StringVector.new
    heat_pump_fuel_choices << HPXML::FuelTypeElectricity

    heat_pump_backup_type_choices = OpenStudio::StringVector.new
    heat_pump_backup_type_choices << 'none'
    heat_pump_backup_type_choices << HPXML::HeatPumpBackupTypeIntegrated
    heat_pump_backup_type_choices << HPXML::HeatPumpBackupTypeSeparate

    heat_pump_backup_fuel_choices = OpenStudio::StringVector.new
    heat_pump_backup_fuel_choices << HPXML::FuelTypeElectricity
    heat_pump_backup_fuel_choices << HPXML::FuelTypeNaturalGas
    heat_pump_backup_fuel_choices << HPXML::FuelTypeOil
    heat_pump_backup_fuel_choices << HPXML::FuelTypePropane

    heat_pump_sizing_choices = OpenStudio::StringVector.new
    heat_pump_sizing_choices << HPXML::HeatPumpSizingACCA
    heat_pump_sizing_choices << HPXML::HeatPumpSizingHERS
    heat_pump_sizing_choices << HPXML::HeatPumpSizingMaxLoad

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heat_pump_type', heat_pump_type_choices, true)
    arg.setDisplayName('Heat Pump: Type')
    arg.setDescription("The type of heat pump. Use 'none' if there is no heat pump.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heat_pump_heating_efficiency_type', heat_pump_heating_efficiency_type_choices, true)
    arg.setDisplayName('Heat Pump: Heating Efficiency Type')
    arg.setDescription("The heating efficiency type of heat pump. System types #{HPXML::HVACTypeHeatPumpAirToAir} and #{HPXML::HVACTypeHeatPumpMiniSplit} use #{HPXML::UnitsHSPF} or #{HPXML::UnitsHSPF2}. System types #{HPXML::HVACTypeHeatPumpGroundToAir}, #{HPXML::HVACTypeHeatPumpPTHP} and #{HPXML::HVACTypeHeatPumpRoom} use #{HPXML::UnitsCOP}.")
    arg.setDefaultValue(HPXML::UnitsHSPF)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_heating_efficiency', true)
    arg.setDisplayName('Heat Pump: Heating Efficiency')
    arg.setDescription('The rated heating efficiency value of the heat pump.')
    arg.setDefaultValue(7.7)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heat_pump_cooling_efficiency_type', cooling_efficiency_type_choices, true)
    arg.setDisplayName('Heat Pump: Cooling Efficiency Type')
    arg.setDescription("The cooling efficiency type of heat pump. System types #{HPXML::HVACTypeHeatPumpAirToAir} and #{HPXML::HVACTypeHeatPumpMiniSplit} use #{HPXML::UnitsSEER} or #{HPXML::UnitsSEER2}. System types #{HPXML::HVACTypeHeatPumpGroundToAir}, #{HPXML::HVACTypeHeatPumpPTHP} and #{HPXML::HVACTypeHeatPumpRoom} use #{HPXML::UnitsEER}.")
    arg.setDefaultValue(HPXML::UnitsSEER)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_cooling_efficiency', true)
    arg.setDisplayName('Heat Pump: Cooling Efficiency')
    arg.setDescription('The rated cooling efficiency value of the heat pump.')
    arg.setDefaultValue(13.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heat_pump_cooling_compressor_type', compressor_type_choices, false)
    arg.setDisplayName('Heat Pump: Cooling Compressor Type')
    arg.setDescription("The compressor type of the heat pump. Only applies to #{HPXML::HVACTypeHeatPumpAirToAir}. If not provided, the OS-HPXML default is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_cooling_sensible_heat_fraction', false)
    arg.setDisplayName('Heat Pump: Cooling Sensible Heat Fraction')
    arg.setDescription('The sensible heat fraction of the heat pump. If not provided, the OS-HPXML default is used.')
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_heating_capacity', false)
    arg.setDisplayName('Heat Pump: Heating Capacity')
    arg.setDescription('The output heating capacity of the heat pump. If not provided, the OS-HPXML autosized default is used.')
    arg.setUnits('Btu/hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_heating_capacity_17_f', false)
    arg.setDisplayName('Heat Pump: Heating Capacity 17F')
    arg.setDescription("The output heating capacity of the heat pump at 17F. Only applies to #{HPXML::HVACTypeHeatPumpAirToAir} and #{HPXML::HVACTypeHeatPumpMiniSplit}. If not provided, the OS-HPXML default is used.")
    arg.setUnits('Btu/hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_cooling_capacity', false)
    arg.setDisplayName('Heat Pump: Cooling Capacity')
    arg.setDescription('The output cooling capacity of the heat pump. If not provided, the OS-HPXML autosized default is used.')
    arg.setUnits('Btu/hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_fraction_heat_load_served', true)
    arg.setDisplayName('Heat Pump: Fraction Heat Load Served')
    arg.setDescription('The heating load served by the heat pump.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_fraction_cool_load_served', true)
    arg.setDisplayName('Heat Pump: Fraction Cool Load Served')
    arg.setDescription('The cooling load served by the heat pump.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heat_pump_backup_type', heat_pump_backup_type_choices, true)
    arg.setDisplayName('Heat Pump: Backup Type')
    arg.setDescription("The backup type of the heat pump. If '#{HPXML::HeatPumpBackupTypeIntegrated}', represents e.g. built-in electric strip heat or dual-fuel integrated furnace. If '#{HPXML::HeatPumpBackupTypeSeparate}', represents e.g. electric baseboard or boiler based on the Heating System 2 specified below. Use 'none' if there is no backup heating.")
    arg.setDefaultValue(HPXML::HeatPumpBackupTypeIntegrated)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heat_pump_backup_fuel', heat_pump_backup_fuel_choices, true)
    arg.setDisplayName('Heat Pump: Backup Fuel Type')
    arg.setDescription("The backup fuel type of the heat pump. Only applies if Backup Type is '#{HPXML::HeatPumpBackupTypeIntegrated}'.")
    arg.setDefaultValue(HPXML::FuelTypeElectricity)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_backup_heating_efficiency', true)
    arg.setDisplayName('Heat Pump: Backup Rated Efficiency')
    arg.setDescription("The backup rated efficiency value of the heat pump. Percent for electricity fuel type. AFUE otherwise. Only applies if Backup Type is '#{HPXML::HeatPumpBackupTypeIntegrated}'.")
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_backup_heating_capacity', false)
    arg.setDisplayName('Heat Pump: Backup Heating Capacity')
    arg.setDescription("The backup output heating capacity of the heat pump. If not provided, the OS-HPXML autosized default is used. Only applies if Backup Type is '#{HPXML::HeatPumpBackupTypeIntegrated}'.")
    arg.setUnits('Btu/hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_backup_heating_switchover_temp', false)
    arg.setDisplayName('Heat Pump: Backup Heating Switchover Temperature')
    arg.setDescription("The temperature at which the heat pump stops operating and the backup heating system starts running. Only applies to #{HPXML::HVACTypeHeatPumpAirToAir} and #{HPXML::HVACTypeHeatPumpMiniSplit}. If not provided, backup heating will operate as needed when heat pump capacity is insufficient. Applies if Backup Type is either '#{HPXML::HeatPumpBackupTypeIntegrated}' or '#{HPXML::HeatPumpBackupTypeSeparate}'. Both Switchover Temperature and Lockout Temperature cannot be specified.")
    arg.setUnits('deg-F')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_backup_heating_lockout_temp', false)
    arg.setDisplayName('Heat Pump: Backup Heating Lockout Temperature')
    arg.setDescription("The temperature above which the backup system is disabled in order to prevent backup heating operation during, e.g., a thermostat heating setback recovery event. If not provided, backup heating will operate as needed when heat pump capacity is insufficient. Only applies if Backup Type is '#{HPXML::HeatPumpBackupTypeIntegrated}'. Both Switchover Temperature and Lockout Temperature cannot be specified.")
    arg.setUnits('deg-F')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heat_pump_sizing_methodology', heat_pump_sizing_choices, false)
    arg.setDisplayName('Heat Pump: Sizing Methodology')
    arg.setDescription('The auto-sizing methodology to use when the heat pump capacity is not provided. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('heat_pump_is_ducted', false)
    arg.setDisplayName('Heat Pump: Is Ducted')
    arg.setDescription("Whether the heat pump is ducted or not. Only used for #{HPXML::HVACTypeHeatPumpMiniSplit}. It's assumed that #{HPXML::HVACTypeHeatPumpAirToAir} and #{HPXML::HVACTypeHeatPumpGroundToAir} are ducted. If not provided, assumes not ducted.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_airflow_defect_ratio', false)
    arg.setDisplayName('Heat Pump: Airflow Defect Ratio')
    arg.setDescription("The airflow defect ratio, defined as (InstalledAirflow - DesignAirflow) / DesignAirflow, of the heat pump per ANSI/RESNET/ACCA Standard 310. A value of zero means no airflow defect. Applies only to #{HPXML::HVACTypeHeatPumpAirToAir}, ducted #{HPXML::HVACTypeHeatPumpMiniSplit}, and #{HPXML::HVACTypeHeatPumpGroundToAir}. If not provided, assumes no defect.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_charge_defect_ratio', false)
    arg.setDisplayName('Heat Pump: Charge Defect Ratio')
    arg.setDescription('The refrigerant charge defect ratio, defined as (InstalledCharge - DesignCharge) / DesignCharge, of the heat pump per ANSI/RESNET/ACCA Standard 310. A value of zero means no refrigerant charge defect. Applies to all heat pump types. If not provided, assumes no defect.')
    arg.setUnits('Frac')
    args << arg

    heating_system_2_type_choices = OpenStudio::StringVector.new
    heating_system_2_type_choices << 'none'
    heating_system_2_type_choices << HPXML::HVACTypeWallFurnace
    heating_system_2_type_choices << HPXML::HVACTypeFloorFurnace
    heating_system_2_type_choices << HPXML::HVACTypeBoiler
    heating_system_2_type_choices << HPXML::HVACTypeElectricResistance
    heating_system_2_type_choices << HPXML::HVACTypeStove
    heating_system_2_type_choices << HPXML::HVACTypePortableHeater
    heating_system_2_type_choices << HPXML::HVACTypeFireplace

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heating_system_2_type', heating_system_2_type_choices, true)
    arg.setDisplayName('Heating System 2: Type')
    arg.setDescription('The type of the second heating system.')
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heating_system_2_fuel', heating_system_fuel_choices, true)
    arg.setDisplayName('Heating System 2: Fuel Type')
    arg.setDescription("The fuel type of the second heating system. Ignored for #{HPXML::HVACTypeElectricResistance}.")
    arg.setDefaultValue(HPXML::FuelTypeElectricity)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_2_heating_efficiency', true)
    arg.setDisplayName('Heating System 2: Rated AFUE or Percent')
    arg.setUnits('Frac')
    arg.setDescription('The rated heating efficiency value of the second heating system.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_2_heating_capacity', false)
    arg.setDisplayName('Heating System 2: Heating Capacity')
    arg.setDescription('The output heating capacity of the second heating system. If not provided, the OS-HPXML autosized default is used.')
    arg.setUnits('Btu/hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_2_fraction_heat_load_served', true)
    arg.setDisplayName('Heating System 2: Fraction Heat Load Served')
    arg.setDescription('The heat load served fraction of the second heating system. Ignored if this heating system serves as a backup system for a heat pump.')
    arg.setUnits('Frac')
    arg.setDefaultValue(0.25)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('hvac_control_heating_weekday_setpoint', false)
    arg.setDisplayName('HVAC Control: Heating Weekday Setpoint Schedule')
    arg.setDescription('Specify the constant or 24-hour comma-separated weekday heating setpoint schedule. Required unless a detailed CSV schedule is provided.')
    arg.setUnits('deg-F')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('hvac_control_heating_weekend_setpoint', false)
    arg.setDisplayName('HVAC Control: Heating Weekend Setpoint Schedule')
    arg.setDescription('Specify the constant or 24-hour comma-separated weekend heating setpoint schedule. Required unless a detailed CSV schedule is provided.')
    arg.setUnits('deg-F')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('hvac_control_cooling_weekday_setpoint', false)
    arg.setDisplayName('HVAC Control: Cooling Weekday Setpoint Schedule')
    arg.setDescription('Specify the constant or 24-hour comma-separated weekday cooling setpoint schedule. Required unless a detailed CSV schedule is provided.')
    arg.setUnits('deg-F')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('hvac_control_cooling_weekend_setpoint', false)
    arg.setDisplayName('HVAC Control: Cooling Weekend Setpoint Schedule')
    arg.setDescription('Specify the constant or 24-hour comma-separated weekend cooling setpoint schedule. Required unless a detailed CSV schedule is provided.')
    arg.setUnits('deg-F')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('hvac_control_heating_season_period', false)
    arg.setDisplayName('HVAC Control: Heating Season Period')
    arg.setDescription("Enter a date like 'Nov 1 - Jun 30'. If not provided, the OS-HPXML default is used. Can also provide '#{HPXML::BuildingAmerica}' to use automatic seasons from the Building America House Simulation Protocols.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('hvac_control_cooling_season_period', false)
    arg.setDisplayName('HVAC Control: Cooling Season Period')
    arg.setDescription("Enter a date like 'Jun 1 - Oct 31'. If not provided, the OS-HPXML default is used. Can also provide '#{HPXML::BuildingAmerica}' to use automatic seasons from the Building America House Simulation Protocols.")
    args << arg

    duct_leakage_units_choices = OpenStudio::StringVector.new
    duct_leakage_units_choices << HPXML::UnitsCFM25
    duct_leakage_units_choices << HPXML::UnitsCFM50
    duct_leakage_units_choices << HPXML::UnitsPercent

    duct_location_choices = OpenStudio::StringVector.new
    duct_location_choices << HPXML::LocationLivingSpace
    duct_location_choices << HPXML::LocationBasementConditioned
    duct_location_choices << HPXML::LocationBasementUnconditioned
    duct_location_choices << HPXML::LocationCrawlspaceVented
    duct_location_choices << HPXML::LocationCrawlspaceUnvented
    duct_location_choices << HPXML::LocationCrawlspaceConditioned
    duct_location_choices << HPXML::LocationAtticVented
    duct_location_choices << HPXML::LocationAtticUnvented
    duct_location_choices << HPXML::LocationGarage
    duct_location_choices << HPXML::LocationExteriorWall
    duct_location_choices << HPXML::LocationUnderSlab
    duct_location_choices << HPXML::LocationRoofDeck
    duct_location_choices << HPXML::LocationOutside
    duct_location_choices << HPXML::LocationOtherHousingUnit
    duct_location_choices << HPXML::LocationOtherHeatedSpace
    duct_location_choices << HPXML::LocationOtherMultifamilyBufferSpace
    duct_location_choices << HPXML::LocationOtherNonFreezingSpace

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('ducts_leakage_units', duct_leakage_units_choices, true)
    arg.setDisplayName('Ducts: Leakage Units')
    arg.setDescription('The leakage units of the ducts.')
    arg.setDefaultValue(HPXML::UnitsPercent)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ducts_supply_leakage_to_outside_value', true)
    arg.setDisplayName('Ducts: Supply Leakage to Outside Value')
    arg.setDescription('The leakage value to outside for the supply ducts.')
    arg.setDefaultValue(0.1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ducts_return_leakage_to_outside_value', true)
    arg.setDisplayName('Ducts: Return Leakage to Outside Value')
    arg.setDescription('The leakage value to outside for the return ducts.')
    arg.setDefaultValue(0.1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('ducts_supply_location', duct_location_choices, false)
    arg.setDisplayName('Ducts: Supply Location')
    arg.setDescription('The location of the supply ducts. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ducts_supply_insulation_r', true)
    arg.setDisplayName('Ducts: Supply Insulation R-Value')
    arg.setDescription('The insulation r-value of the supply ducts excluding air films.')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ducts_supply_surface_area', false)
    arg.setDisplayName('Ducts: Supply Surface Area')
    arg.setDescription('The surface area of the supply ducts. If not provided, the OS-HPXML default is used.')
    arg.setUnits('ft^2')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('ducts_return_location', duct_location_choices, false)
    arg.setDisplayName('Ducts: Return Location')
    arg.setDescription('The location of the return ducts. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ducts_return_insulation_r', true)
    arg.setDisplayName('Ducts: Return Insulation R-Value')
    arg.setDescription('The insulation r-value of the return ducts excluding air films.')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ducts_return_surface_area', false)
    arg.setDisplayName('Ducts: Return Surface Area')
    arg.setDescription('The surface area of the return ducts. If not provided, the OS-HPXML default is used.')
    arg.setUnits('ft^2')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('ducts_number_of_return_registers', false)
    arg.setDisplayName('Ducts: Number of Return Registers')
    arg.setDescription('The number of return registers of the ducts. Only used to calculate default return duct surface area. If not provided, the OS-HPXML default is used.')
    arg.setUnits('#')
    args << arg

    mech_vent_fan_type_choices = OpenStudio::StringVector.new
    mech_vent_fan_type_choices << 'none'
    mech_vent_fan_type_choices << HPXML::MechVentTypeExhaust
    mech_vent_fan_type_choices << HPXML::MechVentTypeSupply
    mech_vent_fan_type_choices << HPXML::MechVentTypeERV
    mech_vent_fan_type_choices << HPXML::MechVentTypeHRV
    mech_vent_fan_type_choices << HPXML::MechVentTypeBalanced
    mech_vent_fan_type_choices << HPXML::MechVentTypeCFIS

    mech_vent_recovery_efficiency_type_choices = OpenStudio::StringVector.new
    mech_vent_recovery_efficiency_type_choices << 'Unadjusted'
    mech_vent_recovery_efficiency_type_choices << 'Adjusted'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('mech_vent_fan_type', mech_vent_fan_type_choices, true)
    arg.setDisplayName('Mechanical Ventilation: Fan Type')
    arg.setDescription("The type of the mechanical ventilation. Use 'none' if there is no mechanical ventilation system.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_flow_rate', false)
    arg.setDisplayName('Mechanical Ventilation: Flow Rate')
    arg.setDescription('The flow rate of the mechanical ventilation. If not provided, the OS-HPXML default is used.')
    arg.setUnits('CFM')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_hours_in_operation', false)
    arg.setDisplayName('Mechanical Ventilation: Hours In Operation')
    arg.setDescription('The hours in operation of the mechanical ventilation. If not provided, the OS-HPXML default is used.')
    arg.setUnits('hrs/day')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('mech_vent_recovery_efficiency_type', mech_vent_recovery_efficiency_type_choices, true)
    arg.setDisplayName('Mechanical Ventilation: Total Recovery Efficiency Type')
    arg.setDescription('The total recovery efficiency type of the mechanical ventilation.')
    arg.setDefaultValue('Unadjusted')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_total_recovery_efficiency', true)
    arg.setDisplayName('Mechanical Ventilation: Total Recovery Efficiency')
    arg.setDescription("The Unadjusted or Adjusted total recovery efficiency of the mechanical ventilation. Applies to #{HPXML::MechVentTypeERV}.")
    arg.setUnits('Frac')
    arg.setDefaultValue(0.48)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_sensible_recovery_efficiency', true)
    arg.setDisplayName('Mechanical Ventilation: Sensible Recovery Efficiency')
    arg.setDescription("The Unadjusted or Adjusted sensible recovery efficiency of the mechanical ventilation. Applies to #{HPXML::MechVentTypeERV} and #{HPXML::MechVentTypeHRV}.")
    arg.setUnits('Frac')
    arg.setDefaultValue(0.72)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_fan_power', false)
    arg.setDisplayName('Mechanical Ventilation: Fan Power')
    arg.setDescription('The fan power of the mechanical ventilation. If not provided, the OS-HPXML default is used.')
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('mech_vent_num_units_served', true)
    arg.setDisplayName('Mechanical Ventilation: Number of Units Served')
    arg.setDescription("Number of dwelling units served by the mechanical ventilation system. Must be 1 if #{HPXML::ResidentialTypeSFD}. Used to apportion flow rate and fan power to the unit.")
    arg.setUnits('#')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_shared_frac_recirculation', false)
    arg.setDisplayName('Shared Mechanical Ventilation: Fraction Recirculation')
    arg.setDescription('Fraction of the total supply air that is recirculated, with the remainder assumed to be outdoor air. The value must be 0 for exhaust only systems. Required for a shared mechanical ventilation system.')
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('mech_vent_shared_preheating_fuel', heating_system_fuel_choices, false)
    arg.setDisplayName('Shared Mechanical Ventilation: Preheating Fuel')
    arg.setDescription('Fuel type of the preconditioning heating equipment. Only used for a shared mechanical ventilation system. If not provided, assumes no preheating.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_shared_preheating_efficiency', false)
    arg.setDisplayName('Shared Mechanical Ventilation: Preheating Efficiency')
    arg.setDescription('Efficiency of the preconditioning heating equipment. Only used for a shared mechanical ventilation system. If not provided, assumes no preheating.')
    arg.setUnits('COP')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_shared_preheating_fraction_heat_load_served', false)
    arg.setDisplayName('Shared Mechanical Ventilation: Preheating Fraction Ventilation Heat Load Served')
    arg.setDescription('Fraction of heating load introduced by the shared ventilation system that is met by the preconditioning heating equipment. If not provided, assumes no preheating.')
    arg.setUnits('Frac')
    args << arg

    cooling_system_fuel_choices = OpenStudio::StringVector.new
    cooling_system_fuel_choices << HPXML::FuelTypeElectricity

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('mech_vent_shared_precooling_fuel', cooling_system_fuel_choices, false)
    arg.setDisplayName('Shared Mechanical Ventilation: Precooling Fuel')
    arg.setDescription('Fuel type of the preconditioning cooling equipment. Only used for a shared mechanical ventilation system. If not provided, assumes no precooling.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_shared_precooling_efficiency', false)
    arg.setDisplayName('Shared Mechanical Ventilation: Precooling Efficiency')
    arg.setDescription('Efficiency of the preconditioning cooling equipment. Only used for a shared mechanical ventilation system. If not provided, assumes no precooling.')
    arg.setUnits('COP')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_shared_precooling_fraction_cool_load_served', false)
    arg.setDisplayName('Shared Mechanical Ventilation: Precooling Fraction Ventilation Cool Load Served')
    arg.setDescription('Fraction of cooling load introduced by the shared ventilation system that is met by the preconditioning cooling equipment. If not provided, assumes no precooling.')
    arg.setUnits('Frac')
    args << arg

    mech_vent_2_fan_type_choices = OpenStudio::StringVector.new
    mech_vent_2_fan_type_choices << 'none'
    mech_vent_2_fan_type_choices << HPXML::MechVentTypeExhaust
    mech_vent_2_fan_type_choices << HPXML::MechVentTypeSupply
    mech_vent_2_fan_type_choices << HPXML::MechVentTypeERV
    mech_vent_2_fan_type_choices << HPXML::MechVentTypeHRV
    mech_vent_2_fan_type_choices << HPXML::MechVentTypeBalanced

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('mech_vent_2_fan_type', mech_vent_2_fan_type_choices, true)
    arg.setDisplayName('Mechanical Ventilation 2: Fan Type')
    arg.setDescription("The type of the second mechanical ventilation. Use 'none' if there is no second mechanical ventilation system.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_2_flow_rate', true)
    arg.setDisplayName('Mechanical Ventilation 2: Flow Rate')
    arg.setDescription('The flow rate of the second mechanical ventilation.')
    arg.setUnits('CFM')
    arg.setDefaultValue(110)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_2_hours_in_operation', true)
    arg.setDisplayName('Mechanical Ventilation 2: Hours In Operation')
    arg.setDescription('The hours in operation of the second mechanical ventilation.')
    arg.setUnits('hrs/day')
    arg.setDefaultValue(24)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('mech_vent_2_recovery_efficiency_type', mech_vent_recovery_efficiency_type_choices, true)
    arg.setDisplayName('Mechanical Ventilation 2: Total Recovery Efficiency Type')
    arg.setDescription('The total recovery efficiency type of the second mechanical ventilation.')
    arg.setDefaultValue('Unadjusted')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_2_total_recovery_efficiency', true)
    arg.setDisplayName('Mechanical Ventilation 2: Total Recovery Efficiency')
    arg.setDescription("The Unadjusted or Adjusted total recovery efficiency of the second mechanical ventilation. Applies to #{HPXML::MechVentTypeERV}.")
    arg.setUnits('Frac')
    arg.setDefaultValue(0.48)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_2_sensible_recovery_efficiency', true)
    arg.setDisplayName('Mechanical Ventilation 2: Sensible Recovery Efficiency')
    arg.setDescription("The Unadjusted or Adjusted sensible recovery efficiency of the second mechanical ventilation. Applies to #{HPXML::MechVentTypeERV} and #{HPXML::MechVentTypeHRV}.")
    arg.setUnits('Frac')
    arg.setDefaultValue(0.72)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_2_fan_power', true)
    arg.setDisplayName('Mechanical Ventilation 2: Fan Power')
    arg.setDescription('The fan power of the second mechanical ventilation.')
    arg.setUnits('W')
    arg.setDefaultValue(30)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('kitchen_fans_quantity', false)
    arg.setDisplayName('Kitchen Fans: Quantity')
    arg.setDescription('The quantity of the kitchen fans. If not provided, the OS-HPXML default is used.')
    arg.setUnits('#')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('kitchen_fans_flow_rate', false)
    arg.setDisplayName('Kitchen Fans: Flow Rate')
    arg.setDescription('The flow rate of the kitchen fan. If not provided, the OS-HPXML default is used.')
    arg.setUnits('CFM')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('kitchen_fans_hours_in_operation', false)
    arg.setDisplayName('Kitchen Fans: Hours In Operation')
    arg.setDescription('The hours in operation of the kitchen fan. If not provided, the OS-HPXML default is used.')
    arg.setUnits('hrs/day')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('kitchen_fans_power', false)
    arg.setDisplayName('Kitchen Fans: Fan Power')
    arg.setDescription('The fan power of the kitchen fan. If not provided, the OS-HPXML default is used.')
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('kitchen_fans_start_hour', false)
    arg.setDisplayName('Kitchen Fans: Start Hour')
    arg.setDescription('The start hour of the kitchen fan. If not provided, the OS-HPXML default is used.')
    arg.setUnits('hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('bathroom_fans_quantity', false)
    arg.setDisplayName('Bathroom Fans: Quantity')
    arg.setDescription('The quantity of the bathroom fans. If not provided, the OS-HPXML default is used.')
    arg.setUnits('#')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('bathroom_fans_flow_rate', false)
    arg.setDisplayName('Bathroom Fans: Flow Rate')
    arg.setDescription('The flow rate of the bathroom fans. If not provided, the OS-HPXML default is used.')
    arg.setUnits('CFM')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('bathroom_fans_hours_in_operation', false)
    arg.setDisplayName('Bathroom Fans: Hours In Operation')
    arg.setDescription('The hours in operation of the bathroom fans. If not provided, the OS-HPXML default is used.')
    arg.setUnits('hrs/day')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('bathroom_fans_power', false)
    arg.setDisplayName('Bathroom Fans: Fan Power')
    arg.setDescription('The fan power of the bathroom fans. If not provided, the OS-HPXML default is used.')
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('bathroom_fans_start_hour', false)
    arg.setDisplayName('Bathroom Fans: Start Hour')
    arg.setDescription('The start hour of the bathroom fans. If not provided, the OS-HPXML default is used.')
    arg.setUnits('hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('whole_house_fan_present', true)
    arg.setDisplayName('Whole House Fan: Present')
    arg.setDescription('Whether there is a whole house fan.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('whole_house_fan_flow_rate', false)
    arg.setDisplayName('Whole House Fan: Flow Rate')
    arg.setDescription('The flow rate of the whole house fan. If not provided, the OS-HPXML default is used.')
    arg.setUnits('CFM')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('whole_house_fan_power', false)
    arg.setDisplayName('Whole House Fan: Fan Power')
    arg.setDescription('The fan power of the whole house fan. If not provided, the OS-HPXML default is used.')
    arg.setUnits('W')
    args << arg

    water_heater_type_choices = OpenStudio::StringVector.new
    water_heater_type_choices << 'none'
    water_heater_type_choices << HPXML::WaterHeaterTypeStorage
    water_heater_type_choices << HPXML::WaterHeaterTypeTankless
    water_heater_type_choices << HPXML::WaterHeaterTypeHeatPump
    water_heater_type_choices << HPXML::WaterHeaterTypeCombiStorage
    water_heater_type_choices << HPXML::WaterHeaterTypeCombiTankless

    water_heater_fuel_choices = OpenStudio::StringVector.new
    water_heater_fuel_choices << HPXML::FuelTypeElectricity
    water_heater_fuel_choices << HPXML::FuelTypeNaturalGas
    water_heater_fuel_choices << HPXML::FuelTypeOil
    water_heater_fuel_choices << HPXML::FuelTypePropane
    water_heater_fuel_choices << HPXML::FuelTypeWoodCord
    water_heater_fuel_choices << HPXML::FuelTypeCoal

    water_heater_location_choices = OpenStudio::StringVector.new
    water_heater_location_choices << HPXML::LocationLivingSpace
    water_heater_location_choices << HPXML::LocationBasementConditioned
    water_heater_location_choices << HPXML::LocationBasementUnconditioned
    water_heater_location_choices << HPXML::LocationGarage
    water_heater_location_choices << HPXML::LocationAtticVented
    water_heater_location_choices << HPXML::LocationAtticUnvented
    water_heater_location_choices << HPXML::LocationCrawlspaceVented
    water_heater_location_choices << HPXML::LocationCrawlspaceUnvented
    water_heater_location_choices << HPXML::LocationCrawlspaceConditioned
    water_heater_location_choices << HPXML::LocationOtherExterior
    water_heater_location_choices << HPXML::LocationOtherHousingUnit
    water_heater_location_choices << HPXML::LocationOtherHeatedSpace
    water_heater_location_choices << HPXML::LocationOtherMultifamilyBufferSpace
    water_heater_location_choices << HPXML::LocationOtherNonFreezingSpace

    water_heater_efficiency_type_choices = OpenStudio::StringVector.new
    water_heater_efficiency_type_choices << 'EnergyFactor'
    water_heater_efficiency_type_choices << 'UniformEnergyFactor'

    water_heater_usage_bin_choices = OpenStudio::StringVector.new
    water_heater_usage_bin_choices << HPXML::WaterHeaterUsageBinVerySmall
    water_heater_usage_bin_choices << HPXML::WaterHeaterUsageBinLow
    water_heater_usage_bin_choices << HPXML::WaterHeaterUsageBinMedium
    water_heater_usage_bin_choices << HPXML::WaterHeaterUsageBinHigh

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('water_heater_type', water_heater_type_choices, true)
    arg.setDisplayName('Water Heater: Type')
    arg.setDescription("The type of water heater. Use 'none' if there is no water heater.")
    arg.setDefaultValue(HPXML::WaterHeaterTypeStorage)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('water_heater_fuel_type', water_heater_fuel_choices, true)
    arg.setDisplayName('Water Heater: Fuel Type')
    arg.setDescription("The fuel type of water heater. Ignored for #{HPXML::WaterHeaterTypeHeatPump}.")
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('water_heater_location', water_heater_location_choices, false)
    arg.setDisplayName('Water Heater: Location')
    arg.setDescription('The location of water heater. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('water_heater_tank_volume', false)
    arg.setDisplayName('Water Heater: Tank Volume')
    arg.setDescription("Nominal volume of water heater tank. Only applies to #{HPXML::WaterHeaterTypeStorage}, #{HPXML::WaterHeaterTypeHeatPump}, and #{HPXML::WaterHeaterTypeCombiStorage}. If not provided, the OS-HPXML default is used.")
    arg.setUnits('gal')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('water_heater_efficiency_type', water_heater_efficiency_type_choices, true)
    arg.setDisplayName('Water Heater: Efficiency Type')
    arg.setDescription('The efficiency type of water heater. Does not apply to space-heating boilers.')
    arg.setDefaultValue('EnergyFactor')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('water_heater_efficiency', true)
    arg.setDisplayName('Water Heater: Efficiency')
    arg.setDescription('Rated Energy Factor or Uniform Energy Factor. Does not apply to space-heating boilers.')
    arg.setDefaultValue(0.67)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('water_heater_usage_bin', water_heater_usage_bin_choices, false)
    arg.setDisplayName('Water Heater: Usage Bin')
    arg.setDescription("The usage of the water heater. Only applies if Efficiency Type is UniformEnergyFactor and Type is not #{HPXML::WaterHeaterTypeTankless}. Does not apply to space-heating boilers. If not provided, the OS-HPXML default is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('water_heater_recovery_efficiency', false)
    arg.setDisplayName('Water Heater: Recovery Efficiency')
    arg.setDescription('Ratio of energy delivered to water heater to the energy content of the fuel consumed by the water heater. Only used for non-electric storage water heaters. If not provided, the OS-HPXML default is used.')
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('water_heater_heating_capacity', false)
    arg.setDisplayName('Water Heater: Heating Capacity')
    arg.setDescription("Heating capacity. Only applies to #{HPXML::WaterHeaterTypeStorage}. If not provided, the OS-HPXML default is used.")
    arg.setUnits('Btu/hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('water_heater_standby_loss', false)
    arg.setDisplayName('Water Heater: Standby Loss')
    arg.setDescription('The standby loss of water heater. Only applies to space-heating boilers. If not provided, the OS-HPXML default is used.')
    arg.setUnits('deg-F/hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('water_heater_jacket_rvalue', false)
    arg.setDisplayName('Water Heater: Jacket R-value')
    arg.setDescription("The jacket R-value of water heater. Doesn't apply to #{HPXML::WaterHeaterTypeTankless} or #{HPXML::WaterHeaterTypeCombiTankless}. If not provided, defaults to no jacket insulation.")
    arg.setUnits('h-ft^2-R/Btu')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('water_heater_setpoint_temperature', false)
    arg.setDisplayName('Water Heater: Setpoint Temperature')
    arg.setDescription('The setpoint temperature of water heater. If not provided, the OS-HPXML default is used.')
    arg.setUnits('deg-F')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('water_heater_num_units_served', true)
    arg.setDisplayName('Water Heater: Number of Units Served')
    arg.setDescription("Number of dwelling units served (directly or indirectly) by the water heater. Must be 1 if #{HPXML::ResidentialTypeSFD}. Used to apportion water heater tank losses to the unit.")
    arg.setUnits('#')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('water_heater_uses_desuperheater', false)
    arg.setDisplayName('Water Heater: Uses Desuperheater')
    arg.setDescription("Requires that the dwelling unit has a #{HPXML::HVACTypeHeatPumpAirToAir}, #{HPXML::HVACTypeHeatPumpMiniSplit}, or #{HPXML::HVACTypeHeatPumpGroundToAir} heat pump or a #{HPXML::HVACTypeCentralAirConditioner} or #{HPXML::HVACTypeMiniSplitAirConditioner} air conditioner. If not provided, assumes no desuperheater.")
    args << arg

    water_heater_tank_model_type_choices = OpenStudio::StringVector.new
    water_heater_tank_model_type_choices << HPXML::WaterHeaterTankModelTypeMixed
    water_heater_tank_model_type_choices << HPXML::WaterHeaterTankModelTypeStratified

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('water_heater_tank_model_type', water_heater_tank_model_type_choices, false)
    arg.setDisplayName('Water Heater: Tank Type')
    arg.setDescription("Type of tank model to use. The '#{HPXML::WaterHeaterTankModelTypeStratified}' tank generally provide more accurate results, but may significantly increase run time. Applies only to #{HPXML::WaterHeaterTypeStorage}. If not provided, the OS-HPXML default is used.")
    args << arg

    water_heater_operating_mode_choices = OpenStudio::StringVector.new
    water_heater_operating_mode_choices << HPXML::WaterHeaterOperatingModeStandard
    water_heater_operating_mode_choices << HPXML::WaterHeaterOperatingModeHeatPumpOnly

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('water_heater_operating_mode', water_heater_operating_mode_choices, false)
    arg.setDisplayName('Water Heater: Operating Mode')
    arg.setDescription("The water heater operating mode. The '#{HPXML::WaterHeaterOperatingModeHeatPumpOnly}' option only uses the heat pump, while '#{HPXML::WaterHeaterOperatingModeStandard}' allows the backup electric resistance to come on in high demand situations. This is ignored if a scheduled operating mode type is selected. Applies only to #{HPXML::WaterHeaterTypeHeatPump}. If not provided, the OS-HPXML default is used.")
    args << arg

    hot_water_distribution_system_type_choices = OpenStudio::StringVector.new
    hot_water_distribution_system_type_choices << HPXML::DHWDistTypeStandard
    hot_water_distribution_system_type_choices << HPXML::DHWDistTypeRecirc

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('hot_water_distribution_system_type', hot_water_distribution_system_type_choices, true)
    arg.setDisplayName('Hot Water Distribution: System Type')
    arg.setDescription('The type of the hot water distribution system.')
    arg.setDefaultValue(HPXML::DHWDistTypeStandard)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_water_distribution_standard_piping_length', false)
    arg.setDisplayName('Hot Water Distribution: Standard Piping Length')
    arg.setUnits('ft')
    arg.setDescription("If the distribution system is #{HPXML::DHWDistTypeStandard}, the length of the piping. If not provided, the OS-HPXML default is used.")
    args << arg

    recirculation_control_type_choices = OpenStudio::StringVector.new
    recirculation_control_type_choices << HPXML::DHWRecirControlTypeNone
    recirculation_control_type_choices << HPXML::DHWRecirControlTypeTimer
    recirculation_control_type_choices << HPXML::DHWRecirControlTypeTemperature
    recirculation_control_type_choices << HPXML::DHWRecirControlTypeSensor
    recirculation_control_type_choices << HPXML::DHWRecirControlTypeManual

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('hot_water_distribution_recirc_control_type', recirculation_control_type_choices, true)
    arg.setDisplayName('Hot Water Distribution: Recirculation Control Type')
    arg.setDescription("If the distribution system is #{HPXML::DHWDistTypeRecirc}, the type of hot water recirculation control, if any.")
    arg.setDefaultValue(HPXML::DHWRecirControlTypeNone)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_water_distribution_recirc_piping_length', false)
    arg.setDisplayName('Hot Water Distribution: Recirculation Piping Length')
    arg.setUnits('ft')
    arg.setDescription("If the distribution system is #{HPXML::DHWDistTypeRecirc}, the length of the recirculation piping. If not provided, the OS-HPXML default is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_water_distribution_recirc_branch_piping_length', false)
    arg.setDisplayName('Hot Water Distribution: Recirculation Branch Piping Length')
    arg.setUnits('ft')
    arg.setDescription("If the distribution system is #{HPXML::DHWDistTypeRecirc}, the length of the recirculation branch piping. If not provided, the OS-HPXML default is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_water_distribution_recirc_pump_power', false)
    arg.setDisplayName('Hot Water Distribution: Recirculation Pump Power')
    arg.setUnits('W')
    arg.setDescription("If the distribution system is #{HPXML::DHWDistTypeRecirc}, the recirculation pump power. If not provided, the OS-HPXML default is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_water_distribution_pipe_r', false)
    arg.setDisplayName('Hot Water Distribution: Pipe Insulation Nominal R-Value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Nominal R-value of the pipe insulation. If not provided, the OS-HPXML default is used.')
    args << arg

    dwhr_facilities_connected_choices = OpenStudio::StringVector.new
    dwhr_facilities_connected_choices << 'none'
    dwhr_facilities_connected_choices << HPXML::DWHRFacilitiesConnectedOne
    dwhr_facilities_connected_choices << HPXML::DWHRFacilitiesConnectedAll

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('dwhr_facilities_connected', dwhr_facilities_connected_choices, true)
    arg.setDisplayName('Drain Water Heat Recovery: Facilities Connected')
    arg.setDescription("Which facilities are connected for the drain water heat recovery. Use 'none' if there is no drain water heat recovery system.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('dwhr_equal_flow', true)
    arg.setDisplayName('Drain Water Heat Recovery: Equal Flow')
    arg.setDescription('Whether the drain water heat recovery has equal flow.')
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dwhr_efficiency', true)
    arg.setDisplayName('Drain Water Heat Recovery: Efficiency')
    arg.setUnits('Frac')
    arg.setDescription('The efficiency of the drain water heat recovery.')
    arg.setDefaultValue(0.55)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('water_fixtures_shower_low_flow', true)
    arg.setDisplayName('Hot Water Fixtures: Is Shower Low Flow')
    arg.setDescription('Whether the shower fixture is low flow.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('water_fixtures_sink_low_flow', true)
    arg.setDisplayName('Hot Water Fixtures: Is Sink Low Flow')
    arg.setDescription('Whether the sink fixture is low flow.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('water_fixtures_usage_multiplier', false)
    arg.setDisplayName('Hot Water Fixtures: Usage Multiplier')
    arg.setDescription('Multiplier on the hot water usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    solar_thermal_system_type_choices = OpenStudio::StringVector.new
    solar_thermal_system_type_choices << 'none'
    solar_thermal_system_type_choices << HPXML::SolarThermalSystemType

    solar_thermal_collector_loop_type_choices = OpenStudio::StringVector.new
    solar_thermal_collector_loop_type_choices << HPXML::SolarThermalLoopTypeDirect
    solar_thermal_collector_loop_type_choices << HPXML::SolarThermalLoopTypeIndirect
    solar_thermal_collector_loop_type_choices << HPXML::SolarThermalLoopTypeThermosyphon

    solar_thermal_collector_type_choices = OpenStudio::StringVector.new
    solar_thermal_collector_type_choices << HPXML::SolarThermalTypeEvacuatedTube
    solar_thermal_collector_type_choices << HPXML::SolarThermalTypeSingleGlazing
    solar_thermal_collector_type_choices << HPXML::SolarThermalTypeDoubleGlazing
    solar_thermal_collector_type_choices << HPXML::SolarThermalTypeICS

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('solar_thermal_system_type', solar_thermal_system_type_choices, true)
    arg.setDisplayName('Solar Thermal: System Type')
    arg.setDescription("The type of solar thermal system. Use 'none' if there is no solar thermal system.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('solar_thermal_collector_area', true)
    arg.setDisplayName('Solar Thermal: Collector Area')
    arg.setUnits('ft^2')
    arg.setDescription('The collector area of the solar thermal system.')
    arg.setDefaultValue(40.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('solar_thermal_collector_loop_type', solar_thermal_collector_loop_type_choices, true)
    arg.setDisplayName('Solar Thermal: Collector Loop Type')
    arg.setDescription('The collector loop type of the solar thermal system.')
    arg.setDefaultValue(HPXML::SolarThermalLoopTypeDirect)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('solar_thermal_collector_type', solar_thermal_collector_type_choices, true)
    arg.setDisplayName('Solar Thermal: Collector Type')
    arg.setDescription('The collector type of the solar thermal system.')
    arg.setDefaultValue(HPXML::SolarThermalTypeEvacuatedTube)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('solar_thermal_collector_azimuth', true)
    arg.setDisplayName('Solar Thermal: Collector Azimuth')
    arg.setUnits('degrees')
    arg.setDescription('The collector azimuth of the solar thermal system. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).')
    arg.setDefaultValue(180)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('solar_thermal_collector_tilt', true)
    arg.setDisplayName('Solar Thermal: Collector Tilt')
    arg.setUnits('degrees')
    arg.setDescription('The collector tilt of the solar thermal system. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.')
    arg.setDefaultValue('RoofPitch')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('solar_thermal_collector_rated_optical_efficiency', true)
    arg.setDisplayName('Solar Thermal: Collector Rated Optical Efficiency')
    arg.setUnits('Frac')
    arg.setDescription('The collector rated optical efficiency of the solar thermal system.')
    arg.setDefaultValue(0.5)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('solar_thermal_collector_rated_thermal_losses', true)
    arg.setDisplayName('Solar Thermal: Collector Rated Thermal Losses')
    arg.setUnits('Btu/hr-ft^2-R')
    arg.setDescription('The collector rated thermal losses of the solar thermal system.')
    arg.setDefaultValue(0.2799)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('solar_thermal_storage_volume', false)
    arg.setDisplayName('Solar Thermal: Storage Volume')
    arg.setUnits('gal')
    arg.setDescription('The storage volume of the solar thermal system. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('solar_thermal_solar_fraction', true)
    arg.setDisplayName('Solar Thermal: Solar Fraction')
    arg.setUnits('Frac')
    arg.setDescription('The solar fraction of the solar thermal system. If provided, overrides all other solar thermal inputs.')
    arg.setDefaultValue(0)
    args << arg

    pv_system_module_type_choices = OpenStudio::StringVector.new
    pv_system_module_type_choices << HPXML::PVModuleTypeStandard
    pv_system_module_type_choices << HPXML::PVModuleTypePremium
    pv_system_module_type_choices << HPXML::PVModuleTypeThinFilm

    pv_system_location_choices = OpenStudio::StringVector.new
    pv_system_location_choices << HPXML::LocationRoof
    pv_system_location_choices << HPXML::LocationGround

    pv_system_tracking_choices = OpenStudio::StringVector.new
    pv_system_tracking_choices << HPXML::PVTrackingTypeFixed
    pv_system_tracking_choices << HPXML::PVTrackingType1Axis
    pv_system_tracking_choices << HPXML::PVTrackingType1AxisBacktracked
    pv_system_tracking_choices << HPXML::PVTrackingType2Axis

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('pv_system_present', true)
    arg.setDisplayName('PV System: Present')
    arg.setDescription('Whether there is a PV system present.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_system_module_type', pv_system_module_type_choices, false)
    arg.setDisplayName('PV System: Module Type')
    arg.setDescription('Module type of the PV system. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_system_location', pv_system_location_choices, false)
    arg.setDisplayName('PV System: Location')
    arg.setDescription('Location of the PV system. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_system_tracking', pv_system_tracking_choices, false)
    arg.setDisplayName('PV System: Tracking')
    arg.setDescription('Type of tracking for the PV system. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_array_azimuth', true)
    arg.setDisplayName('PV System: Array Azimuth')
    arg.setUnits('degrees')
    arg.setDescription('Array azimuth of the PV system. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).')
    arg.setDefaultValue(180)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('pv_system_array_tilt', true)
    arg.setDisplayName('PV System: Array Tilt')
    arg.setUnits('degrees')
    arg.setDescription('Array tilt of the PV system. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.')
    arg.setDefaultValue('RoofPitch')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_max_power_output', true)
    arg.setDisplayName('PV System: Maximum Power Output')
    arg.setUnits('W')
    arg.setDescription('Maximum power output of the PV system. For a shared system, this is the total building maximum power output.')
    arg.setDefaultValue(4000)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_inverter_efficiency', false)
    arg.setDisplayName('PV System: Inverter Efficiency')
    arg.setUnits('Frac')
    arg.setDescription('Inverter efficiency of the PV system. If there are two PV systems, this will apply to both. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_system_losses_fraction', false)
    arg.setDisplayName('PV System: System Losses Fraction')
    arg.setUnits('Frac')
    arg.setDescription('System losses fraction of the PV system. If there are two PV systems, this will apply to both. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('pv_system_num_bedrooms_served', false)
    arg.setDisplayName('PV System: Number of Bedrooms Served')
    arg.setDescription("Number of bedrooms served by PV system. Required if #{HPXML::ResidentialTypeSFA} or #{HPXML::ResidentialTypeApartment}. Used to apportion PV generation to the unit of a SFA/MF building. If there are two PV systems, this will apply to both.")
    arg.setUnits('#')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('pv_system_2_present', true)
    arg.setDisplayName('PV System 2: Present')
    arg.setDescription('Whether there is a second PV system present.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_system_2_module_type', pv_system_module_type_choices, false)
    arg.setDisplayName('PV System 2: Module Type')
    arg.setDescription('Module type of the second PV system. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_system_2_location', pv_system_location_choices, false)
    arg.setDisplayName('PV System 2: Location')
    arg.setDescription('Location of the second PV system. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_system_2_tracking', pv_system_tracking_choices, false)
    arg.setDisplayName('PV System 2: Tracking')
    arg.setDescription('Type of tracking for the second PV system. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_2_array_azimuth', true)
    arg.setDisplayName('PV System 2: Array Azimuth')
    arg.setUnits('degrees')
    arg.setDescription('Array azimuth of the second PV system. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).')
    arg.setDefaultValue(180)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('pv_system_2_array_tilt', true)
    arg.setDisplayName('PV System 2: Array Tilt')
    arg.setUnits('degrees')
    arg.setDescription('Array tilt of the second PV system. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.')
    arg.setDefaultValue('RoofPitch')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_2_max_power_output', true)
    arg.setDisplayName('PV System 2: Maximum Power Output')
    arg.setUnits('W')
    arg.setDescription('Maximum power output of the second PV system. For a shared system, this is the total building maximum power output.')
    arg.setDefaultValue(4000)
    args << arg

    battery_location_choices = OpenStudio::StringVector.new
    battery_location_choices << HPXML::LocationLivingSpace
    battery_location_choices << HPXML::LocationBasementConditioned
    battery_location_choices << HPXML::LocationBasementUnconditioned
    battery_location_choices << HPXML::LocationCrawlspaceVented
    battery_location_choices << HPXML::LocationCrawlspaceUnvented
    battery_location_choices << HPXML::LocationCrawlspaceConditioned
    battery_location_choices << HPXML::LocationAtticVented
    battery_location_choices << HPXML::LocationAtticUnvented
    battery_location_choices << HPXML::LocationGarage
    battery_location_choices << HPXML::LocationOutside

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('battery_present', true)
    arg.setDisplayName('Battery: Present')
    arg.setDescription('Whether there is a lithium ion battery present.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('battery_location', battery_location_choices, false)
    arg.setDisplayName('Battery: Location')
    arg.setDescription('The space type for the lithium ion battery location. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('battery_power', false)
    arg.setDisplayName('Battery: Rated Power Output')
    arg.setDescription('The rated power output of the lithium ion battery. If not provided, the OS-HPXML default is used.')
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('battery_capacity', false)
    arg.setDisplayName('Battery: Nominal Capacity')
    arg.setDescription('The nominal capacity of the lithium ion battery. If not provided, the OS-HPXML default is used.')
    arg.setUnits('kWh')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('battery_usable_capacity', false)
    arg.setDisplayName('Battery: Usable Capacity')
    arg.setDescription('The usable capacity of the lithium ion battery. If not provided, the OS-HPXML default is used.')
    arg.setUnits('kWh')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('battery_round_trip_efficiency', false)
    arg.setDisplayName('Battery: Round Trip Efficiency')
    arg.setDescription('The round trip efficiency of the lithium ion battery. If not provided, the OS-HPXML default is used.')
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('lighting_present', true)
    arg.setDisplayName('Lighting: Present')
    arg.setDescription('Whether there is lighting energy use.')
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_interior_fraction_cfl', true)
    arg.setDisplayName('Lighting: Interior Fraction CFL')
    arg.setDescription('Fraction of all lamps (interior) that are compact fluorescent. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_interior_fraction_lfl', true)
    arg.setDisplayName('Lighting: Interior Fraction LFL')
    arg.setDescription('Fraction of all lamps (interior) that are linear fluorescent. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_interior_fraction_led', true)
    arg.setDisplayName('Lighting: Interior Fraction LED')
    arg.setDescription('Fraction of all lamps (interior) that are light emitting diodes. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_interior_usage_multiplier', false)
    arg.setDisplayName('Lighting: Interior Usage Multiplier')
    arg.setDescription('Multiplier on the lighting energy usage (interior) that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_exterior_fraction_cfl', true)
    arg.setDisplayName('Lighting: Exterior Fraction CFL')
    arg.setDescription('Fraction of all lamps (exterior) that are compact fluorescent. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_exterior_fraction_lfl', true)
    arg.setDisplayName('Lighting: Exterior Fraction LFL')
    arg.setDescription('Fraction of all lamps (exterior) that are linear fluorescent. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_exterior_fraction_led', true)
    arg.setDisplayName('Lighting: Exterior Fraction LED')
    arg.setDescription('Fraction of all lamps (exterior) that are light emitting diodes. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_exterior_usage_multiplier', false)
    arg.setDisplayName('Lighting: Exterior Usage Multiplier')
    arg.setDescription('Multiplier on the lighting energy usage (exterior) that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_garage_fraction_cfl', true)
    arg.setDisplayName('Lighting: Garage Fraction CFL')
    arg.setDescription('Fraction of all lamps (garage) that are compact fluorescent. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_garage_fraction_lfl', true)
    arg.setDisplayName('Lighting: Garage Fraction LFL')
    arg.setDescription('Fraction of all lamps (garage) that are linear fluorescent. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_garage_fraction_led', true)
    arg.setDisplayName('Lighting: Garage Fraction LED')
    arg.setDescription('Fraction of all lamps (garage) that are light emitting diodes. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_garage_usage_multiplier', false)
    arg.setDisplayName('Lighting: Garage Usage Multiplier')
    arg.setDescription('Multiplier on the lighting energy usage (garage) that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('holiday_lighting_present', true)
    arg.setDisplayName('Holiday Lighting: Present')
    arg.setDescription('Whether there is holiday lighting.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('holiday_lighting_daily_kwh', false)
    arg.setDisplayName('Holiday Lighting: Daily Consumption')
    arg.setUnits('kWh/day')
    arg.setDescription('The daily energy consumption for holiday lighting (exterior). If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('holiday_lighting_period', false)
    arg.setDisplayName('Holiday Lighting: Period')
    arg.setDescription('Enter a date like "Nov 25 - Jan 5". If not provided, the OS-HPXML default is used.')
    args << arg

    dehumidifier_type_choices = OpenStudio::StringVector.new
    dehumidifier_type_choices << 'none'
    dehumidifier_type_choices << HPXML::DehumidifierTypePortable
    dehumidifier_type_choices << HPXML::DehumidifierTypeWholeHome

    dehumidifier_efficiency_type_choices = OpenStudio::StringVector.new
    dehumidifier_efficiency_type_choices << 'EnergyFactor'
    dehumidifier_efficiency_type_choices << 'IntegratedEnergyFactor'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('dehumidifier_type', dehumidifier_type_choices, true)
    arg.setDisplayName('Dehumidifier: Type')
    arg.setDescription('The type of dehumidifier.')
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('dehumidifier_efficiency_type', dehumidifier_efficiency_type_choices, true)
    arg.setDisplayName('Dehumidifier: Efficiency Type')
    arg.setDescription('The efficiency type of dehumidifier.')
    arg.setDefaultValue('IntegratedEnergyFactor')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dehumidifier_efficiency', true)
    arg.setDisplayName('Dehumidifier: Efficiency')
    arg.setUnits('liters/kWh')
    arg.setDescription('The efficiency of the dehumidifier.')
    arg.setDefaultValue(1.5)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dehumidifier_capacity', true)
    arg.setDisplayName('Dehumidifier: Capacity')
    arg.setDescription('The capacity (water removal rate) of the dehumidifier.')
    arg.setUnits('pint/day')
    arg.setDefaultValue(40)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dehumidifier_rh_setpoint', true)
    arg.setDisplayName('Dehumidifier: Relative Humidity Setpoint')
    arg.setDescription('The relative humidity setpoint of the dehumidifier.')
    arg.setUnits('Frac')
    arg.setDefaultValue(0.5)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dehumidifier_fraction_dehumidification_load_served', true)
    arg.setDisplayName('Dehumidifier: Fraction Dehumidification Load Served')
    arg.setDescription('The dehumidification load served fraction of the dehumidifier.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    appliance_location_choices = OpenStudio::StringVector.new
    appliance_location_choices << HPXML::LocationLivingSpace
    appliance_location_choices << HPXML::LocationBasementConditioned
    appliance_location_choices << HPXML::LocationBasementUnconditioned
    appliance_location_choices << HPXML::LocationGarage
    appliance_location_choices << HPXML::LocationOtherHousingUnit
    appliance_location_choices << HPXML::LocationOtherHeatedSpace
    appliance_location_choices << HPXML::LocationOtherMultifamilyBufferSpace
    appliance_location_choices << HPXML::LocationOtherNonFreezingSpace

    clothes_washer_efficiency_type_choices = OpenStudio::StringVector.new
    clothes_washer_efficiency_type_choices << 'ModifiedEnergyFactor'
    clothes_washer_efficiency_type_choices << 'IntegratedModifiedEnergyFactor'

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('clothes_washer_present', true)
    arg.setDisplayName('Clothes Washer: Present')
    arg.setDescription('Whether there is a clothes washer present.')
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('clothes_washer_location', appliance_location_choices, false)
    arg.setDisplayName('Clothes Washer: Location')
    arg.setDescription('The space type for the clothes washer location. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('clothes_washer_efficiency_type', clothes_washer_efficiency_type_choices, true)
    arg.setDisplayName('Clothes Washer: Efficiency Type')
    arg.setDescription('The efficiency type of the clothes washer.')
    arg.setDefaultValue('IntegratedModifiedEnergyFactor')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_washer_efficiency', false)
    arg.setDisplayName('Clothes Washer: Efficiency')
    arg.setUnits('ft^3/kWh-cyc')
    arg.setDescription('The efficiency of the clothes washer. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_washer_rated_annual_kwh', false)
    arg.setDisplayName('Clothes Washer: Rated Annual Consumption')
    arg.setUnits('kWh/yr')
    arg.setDescription('The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_washer_label_electric_rate', false)
    arg.setDisplayName('Clothes Washer: Label Electric Rate')
    arg.setUnits('$/kWh')
    arg.setDescription('The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_washer_label_gas_rate', false)
    arg.setDisplayName('Clothes Washer: Label Gas Rate')
    arg.setUnits('$/therm')
    arg.setDescription('The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_washer_label_annual_gas_cost', false)
    arg.setDisplayName('Clothes Washer: Label Annual Cost with Gas DHW')
    arg.setUnits('$')
    arg.setDescription('The annual cost of using the system under test conditions. Input is obtained from the EnergyGuide label. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_washer_label_usage', false)
    arg.setDisplayName('Clothes Washer: Label Usage')
    arg.setUnits('cyc/wk')
    arg.setDescription('The clothes washer loads per week. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_washer_capacity', false)
    arg.setDisplayName('Clothes Washer: Drum Volume')
    arg.setUnits('ft^3')
    arg.setDescription("Volume of the washer drum. Obtained from the EnergyStar website or the manufacturer's literature. If not provided, the OS-HPXML default is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_washer_usage_multiplier', false)
    arg.setDisplayName('Clothes Washer: Usage Multiplier')
    arg.setDescription('Multiplier on the clothes washer energy and hot water usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('clothes_dryer_present', true)
    arg.setDisplayName('Clothes Dryer: Present')
    arg.setDescription('Whether there is a clothes dryer present.')
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('clothes_dryer_location', appliance_location_choices, false)
    arg.setDisplayName('Clothes Dryer: Location')
    arg.setDescription('The space type for the clothes dryer location. If not provided, the OS-HPXML default is used.')
    args << arg

    clothes_dryer_fuel_choices = OpenStudio::StringVector.new
    clothes_dryer_fuel_choices << HPXML::FuelTypeElectricity
    clothes_dryer_fuel_choices << HPXML::FuelTypeNaturalGas
    clothes_dryer_fuel_choices << HPXML::FuelTypeOil
    clothes_dryer_fuel_choices << HPXML::FuelTypePropane
    clothes_dryer_fuel_choices << HPXML::FuelTypeWoodCord
    clothes_dryer_fuel_choices << HPXML::FuelTypeCoal

    clothes_dryer_efficiency_type_choices = OpenStudio::StringVector.new
    clothes_dryer_efficiency_type_choices << 'EnergyFactor'
    clothes_dryer_efficiency_type_choices << 'CombinedEnergyFactor'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('clothes_dryer_fuel_type', clothes_dryer_fuel_choices, true)
    arg.setDisplayName('Clothes Dryer: Fuel Type')
    arg.setDescription('Type of fuel used by the clothes dryer.')
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('clothes_dryer_efficiency_type', clothes_dryer_efficiency_type_choices, true)
    arg.setDisplayName('Clothes Dryer: Efficiency Type')
    arg.setDescription('The efficiency type of the clothes dryer.')
    arg.setDefaultValue('CombinedEnergyFactor')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_dryer_efficiency', false)
    arg.setDisplayName('Clothes Dryer: Efficiency')
    arg.setUnits('lb/kWh')
    arg.setDescription('The efficiency of the clothes dryer. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_dryer_vented_flow_rate', false)
    arg.setDisplayName('Clothes Dryer: Vented Flow Rate')
    arg.setDescription('The exhaust flow rate of the vented clothes dryer. If not provided, the OS-HPXML default is used.')
    arg.setUnits('CFM')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_dryer_usage_multiplier', false)
    arg.setDisplayName('Clothes Dryer: Usage Multiplier')
    arg.setDescription('Multiplier on the clothes dryer energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('dishwasher_present', true)
    arg.setDisplayName('Dishwasher: Present')
    arg.setDescription('Whether there is a dishwasher present.')
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('dishwasher_location', appliance_location_choices, false)
    arg.setDisplayName('Dishwasher: Location')
    arg.setDescription('The space type for the dishwasher location. If not provided, the OS-HPXML default is used.')
    args << arg

    dishwasher_efficiency_type_choices = OpenStudio::StringVector.new
    dishwasher_efficiency_type_choices << 'RatedAnnualkWh'
    dishwasher_efficiency_type_choices << 'EnergyFactor'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('dishwasher_efficiency_type', dishwasher_efficiency_type_choices, true)
    arg.setDisplayName('Dishwasher: Efficiency Type')
    arg.setDescription('The efficiency type of dishwasher.')
    arg.setDefaultValue('RatedAnnualkWh')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dishwasher_efficiency', false)
    arg.setDisplayName('Dishwasher: Efficiency')
    arg.setUnits('RatedAnnualkWh or EnergyFactor')
    arg.setDescription('The efficiency of the dishwasher. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dishwasher_label_electric_rate', false)
    arg.setDisplayName('Dishwasher: Label Electric Rate')
    arg.setUnits('$/kWh')
    arg.setDescription('The label electric rate of the dishwasher. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dishwasher_label_gas_rate', false)
    arg.setDisplayName('Dishwasher: Label Gas Rate')
    arg.setUnits('$/therm')
    arg.setDescription('The label gas rate of the dishwasher. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dishwasher_label_annual_gas_cost', false)
    arg.setDisplayName('Dishwasher: Label Annual Gas Cost')
    arg.setUnits('$')
    arg.setDescription('The label annual gas cost of the dishwasher. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dishwasher_label_usage', false)
    arg.setDisplayName('Dishwasher: Label Usage')
    arg.setUnits('cyc/wk')
    arg.setDescription('The dishwasher loads per week. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('dishwasher_place_setting_capacity', false)
    arg.setDisplayName('Dishwasher: Number of Place Settings')
    arg.setUnits('#')
    arg.setDescription("The number of place settings for the unit. Data obtained from manufacturer's literature. If not provided, the OS-HPXML default is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dishwasher_usage_multiplier', false)
    arg.setDisplayName('Dishwasher: Usage Multiplier')
    arg.setDescription('Multiplier on the dishwasher energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('refrigerator_present', true)
    arg.setDisplayName('Refrigerator: Present')
    arg.setDescription('Whether there is a refrigerator present.')
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('refrigerator_location', appliance_location_choices, false)
    arg.setDisplayName('Refrigerator: Location')
    arg.setDescription('The space type for the refrigerator location. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('refrigerator_rated_annual_kwh', false)
    arg.setDisplayName('Refrigerator: Rated Annual Consumption')
    arg.setUnits('kWh/yr')
    arg.setDescription('The EnergyGuide rated annual energy consumption for a refrigerator. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('refrigerator_usage_multiplier', false)
    arg.setDisplayName('Refrigerator: Usage Multiplier')
    arg.setDescription('Multiplier on the refrigerator energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('extra_refrigerator_present', true)
    arg.setDisplayName('Extra Refrigerator: Present')
    arg.setDescription('Whether there is an extra refrigerator present.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('extra_refrigerator_location', appliance_location_choices, false)
    arg.setDisplayName('Extra Refrigerator: Location')
    arg.setDescription('The space type for the extra refrigerator location. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('extra_refrigerator_rated_annual_kwh', false)
    arg.setDisplayName('Extra Refrigerator: Rated Annual Consumption')
    arg.setUnits('kWh/yr')
    arg.setDescription('The EnergyGuide rated annual energy consumption for an extra rrefrigerator. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('extra_refrigerator_usage_multiplier', false)
    arg.setDisplayName('Extra Refrigerator: Usage Multiplier')
    arg.setDescription('Multiplier on the extra refrigerator energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('freezer_present', true)
    arg.setDisplayName('Freezer: Present')
    arg.setDescription('Whether there is a freezer present.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('freezer_location', appliance_location_choices, false)
    arg.setDisplayName('Freezer: Location')
    arg.setDescription('The space type for the freezer location. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('freezer_rated_annual_kwh', false)
    arg.setDisplayName('Freezer: Rated Annual Consumption')
    arg.setUnits('kWh/yr')
    arg.setDescription('The EnergyGuide rated annual energy consumption for a freezer. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('freezer_usage_multiplier', false)
    arg.setDisplayName('Freezer: Usage Multiplier')
    arg.setDescription('Multiplier on the freezer energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    cooking_range_oven_fuel_choices = OpenStudio::StringVector.new
    cooking_range_oven_fuel_choices << HPXML::FuelTypeElectricity
    cooking_range_oven_fuel_choices << HPXML::FuelTypeNaturalGas
    cooking_range_oven_fuel_choices << HPXML::FuelTypeOil
    cooking_range_oven_fuel_choices << HPXML::FuelTypePropane
    cooking_range_oven_fuel_choices << HPXML::FuelTypeWoodCord
    cooking_range_oven_fuel_choices << HPXML::FuelTypeCoal

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('cooking_range_oven_present', true)
    arg.setDisplayName('Cooking Range/Oven: Present')
    arg.setDescription('Whether there is a cooking range/oven present.')
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('cooking_range_oven_location', appliance_location_choices, false)
    arg.setDisplayName('Cooking Range/Oven: Location')
    arg.setDescription('The space type for the cooking range/oven location. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('cooking_range_oven_fuel_type', cooking_range_oven_fuel_choices, true)
    arg.setDisplayName('Cooking Range/Oven: Fuel Type')
    arg.setDescription('Type of fuel used by the cooking range/oven.')
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('cooking_range_oven_is_induction', false)
    arg.setDisplayName('Cooking Range/Oven: Is Induction')
    arg.setDescription('Whether the cooking range is induction. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('cooking_range_oven_is_convection', false)
    arg.setDisplayName('Cooking Range/Oven: Is Convection')
    arg.setDescription('Whether the oven is convection. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooking_range_oven_usage_multiplier', false)
    arg.setDisplayName('Cooking Range/Oven: Usage Multiplier')
    arg.setDescription('Multiplier on the cooking range/oven energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('ceiling_fan_present', true)
    arg.setDisplayName('Ceiling Fan: Present')
    arg.setDescription('Whether there are any ceiling fans.')
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_fan_efficiency', false)
    arg.setDisplayName('Ceiling Fan: Efficiency')
    arg.setUnits('CFM/W')
    arg.setDescription('The efficiency rating of the ceiling fan(s) at medium speed. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('ceiling_fan_quantity', false)
    arg.setDisplayName('Ceiling Fan: Quantity')
    arg.setUnits('#')
    arg.setDescription('Total number of ceiling fans. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_fan_cooling_setpoint_temp_offset', false)
    arg.setDisplayName('Ceiling Fan: Cooling Setpoint Temperature Offset')
    arg.setUnits('deg-F')
    arg.setDescription('The setpoint temperature offset during cooling season for the ceiling fan(s). Only applies if ceiling fan quantity is greater than zero. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('misc_plug_loads_television_present', true)
    arg.setDisplayName('Misc Plug Loads: Television Present')
    arg.setDescription('Whether there are televisions.')
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_plug_loads_television_annual_kwh', false)
    arg.setDisplayName('Misc Plug Loads: Television Annual kWh')
    arg.setDescription('The annual energy consumption of the television plug loads. If not provided, the OS-HPXML default is used.')
    arg.setUnits('kWh/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_plug_loads_television_usage_multiplier', false)
    arg.setDisplayName('Misc Plug Loads: Television Usage Multiplier')
    arg.setDescription('Multiplier on the television energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_plug_loads_other_annual_kwh', false)
    arg.setDisplayName('Misc Plug Loads: Other Annual kWh')
    arg.setDescription('The annual energy consumption of the other residual plug loads. If not provided, the OS-HPXML default is used.')
    arg.setUnits('kWh/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_plug_loads_other_frac_sensible', false)
    arg.setDisplayName('Misc Plug Loads: Other Sensible Fraction')
    arg.setDescription("Fraction of other residual plug loads' internal gains that are sensible. If not provided, the OS-HPXML default is used.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_plug_loads_other_frac_latent', false)
    arg.setDisplayName('Misc Plug Loads: Other Latent Fraction')
    arg.setDescription("Fraction of other residual plug loads' internal gains that are latent. If not provided, the OS-HPXML default is used.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_plug_loads_other_usage_multiplier', false)
    arg.setDisplayName('Misc Plug Loads: Other Usage Multiplier')
    arg.setDescription('Multiplier on the other energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('misc_plug_loads_well_pump_present', true)
    arg.setDisplayName('Misc Plug Loads: Well Pump Present')
    arg.setDescription('Whether there is a well pump.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_plug_loads_well_pump_annual_kwh', false)
    arg.setDisplayName('Misc Plug Loads: Well Pump Annual kWh')
    arg.setDescription('The annual energy consumption of the well pump plug loads. If not provided, the OS-HPXML default is used.')
    arg.setUnits('kWh/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_plug_loads_well_pump_usage_multiplier', false)
    arg.setDisplayName('Misc Plug Loads: Well Pump Usage Multiplier')
    arg.setDescription('Multiplier on the well pump energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('misc_plug_loads_vehicle_present', true)
    arg.setDisplayName('Misc Plug Loads: Vehicle Present')
    arg.setDescription('Whether there is an electric vehicle.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_plug_loads_vehicle_annual_kwh', false)
    arg.setDisplayName('Misc Plug Loads: Vehicle Annual kWh')
    arg.setDescription('The annual energy consumption of the electric vehicle plug loads. If not provided, the OS-HPXML default is used.')
    arg.setUnits('kWh/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_plug_loads_vehicle_usage_multiplier', false)
    arg.setDisplayName('Misc Plug Loads: Vehicle Usage Multiplier')
    arg.setDescription('Multiplier on the electric vehicle energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    misc_fuel_loads_fuel_choices = OpenStudio::StringVector.new
    misc_fuel_loads_fuel_choices << HPXML::FuelTypeNaturalGas
    misc_fuel_loads_fuel_choices << HPXML::FuelTypeOil
    misc_fuel_loads_fuel_choices << HPXML::FuelTypePropane
    misc_fuel_loads_fuel_choices << HPXML::FuelTypeWoodCord
    misc_fuel_loads_fuel_choices << HPXML::FuelTypeWoodPellets

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('misc_fuel_loads_grill_present', true)
    arg.setDisplayName('Misc Fuel Loads: Grill Present')
    arg.setDescription('Whether there is a fuel loads grill.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('misc_fuel_loads_grill_fuel_type', misc_fuel_loads_fuel_choices, true)
    arg.setDisplayName('Misc Fuel Loads: Grill Fuel Type')
    arg.setDescription('The fuel type of the fuel loads grill.')
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_fuel_loads_grill_annual_therm', false)
    arg.setDisplayName('Misc Fuel Loads: Grill Annual therm')
    arg.setDescription('The annual energy consumption of the fuel loads grill. If not provided, the OS-HPXML default is used.')
    arg.setUnits('therm/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_fuel_loads_grill_usage_multiplier', false)
    arg.setDisplayName('Misc Fuel Loads: Grill Usage Multiplier')
    arg.setDescription('Multiplier on the fuel loads grill energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('misc_fuel_loads_lighting_present', true)
    arg.setDisplayName('Misc Fuel Loads: Lighting Present')
    arg.setDescription('Whether there is fuel loads lighting.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('misc_fuel_loads_lighting_fuel_type', misc_fuel_loads_fuel_choices, true)
    arg.setDisplayName('Misc Fuel Loads: Lighting Fuel Type')
    arg.setDescription('The fuel type of the fuel loads lighting.')
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_fuel_loads_lighting_annual_therm', false)
    arg.setDisplayName('Misc Fuel Loads: Lighting Annual therm')
    arg.setDescription('The annual energy consumption of the fuel loads lighting. If not provided, the OS-HPXML default is used.')
    arg.setUnits('therm/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_fuel_loads_lighting_usage_multiplier', false)
    arg.setDisplayName('Misc Fuel Loads: Lighting Usage Multiplier')
    arg.setDescription('Multiplier on the fuel loads lighting energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('misc_fuel_loads_fireplace_present', true)
    arg.setDisplayName('Misc Fuel Loads: Fireplace Present')
    arg.setDescription('Whether there is fuel loads fireplace.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('misc_fuel_loads_fireplace_fuel_type', misc_fuel_loads_fuel_choices, true)
    arg.setDisplayName('Misc Fuel Loads: Fireplace Fuel Type')
    arg.setDescription('The fuel type of the fuel loads fireplace.')
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_fuel_loads_fireplace_annual_therm', false)
    arg.setDisplayName('Misc Fuel Loads: Fireplace Annual therm')
    arg.setDescription('The annual energy consumption of the fuel loads fireplace. If not provided, the OS-HPXML default is used.')
    arg.setUnits('therm/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_fuel_loads_fireplace_frac_sensible', false)
    arg.setDisplayName('Misc Fuel Loads: Fireplace Sensible Fraction')
    arg.setDescription("Fraction of fireplace residual fuel loads' internal gains that are sensible. If not provided, the OS-HPXML default is used.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_fuel_loads_fireplace_frac_latent', false)
    arg.setDisplayName('Misc Fuel Loads: Fireplace Latent Fraction')
    arg.setDescription("Fraction of fireplace residual fuel loads' internal gains that are latent. If not provided, the OS-HPXML default is used.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('misc_fuel_loads_fireplace_usage_multiplier', false)
    arg.setDisplayName('Misc Fuel Loads: Fireplace Usage Multiplier')
    arg.setDescription('Multiplier on the fuel loads fireplace energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    heater_type_choices = OpenStudio::StringVector.new
    heater_type_choices << HPXML::TypeNone
    heater_type_choices << HPXML::HeaterTypeElectricResistance
    heater_type_choices << HPXML::HeaterTypeGas
    heater_type_choices << HPXML::HeaterTypeHeatPump

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('pool_present', true)
    arg.setDisplayName('Pool: Present')
    arg.setDescription('Whether there is a pool.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_pump_annual_kwh', false)
    arg.setDisplayName('Pool: Pump Annual kWh')
    arg.setDescription('The annual energy consumption of the pool pump. If not provided, the OS-HPXML default is used.')
    arg.setUnits('kWh/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_pump_usage_multiplier', false)
    arg.setDisplayName('Pool: Pump Usage Multiplier')
    arg.setDescription('Multiplier on the pool pump energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pool_heater_type', heater_type_choices, true)
    arg.setDisplayName('Pool: Heater Type')
    arg.setDescription("The type of pool heater. Use '#{HPXML::TypeNone}' if there is no pool heater.")
    arg.setDefaultValue(HPXML::TypeNone)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_heater_annual_kwh', false)
    arg.setDisplayName('Pool: Heater Annual kWh')
    arg.setDescription("The annual energy consumption of the #{HPXML::HeaterTypeElectricResistance} pool heater. If not provided, the OS-HPXML default is used.")
    arg.setUnits('kWh/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_heater_annual_therm', false)
    arg.setDisplayName('Pool: Heater Annual therm')
    arg.setDescription("The annual energy consumption of the #{HPXML::HeaterTypeGas} pool heater. If not provided, the OS-HPXML default is used.")
    arg.setUnits('therm/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_heater_usage_multiplier', false)
    arg.setDisplayName('Pool: Heater Usage Multiplier')
    arg.setDescription('Multiplier on the pool heater energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('hot_tub_present', true)
    arg.setDisplayName('Hot Tub: Present')
    arg.setDescription('Whether there is a hot tub.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_pump_annual_kwh', false)
    arg.setDisplayName('Hot Tub: Pump Annual kWh')
    arg.setDescription('The annual energy consumption of the hot tub pump. If not provided, the OS-HPXML default is used.')
    arg.setUnits('kWh/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_pump_usage_multiplier', false)
    arg.setDisplayName('Hot Tub: Pump Usage Multiplier')
    arg.setDescription('Multiplier on the hot tub pump energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('hot_tub_heater_type', heater_type_choices, true)
    arg.setDisplayName('Hot Tub: Heater Type')
    arg.setDescription("The type of hot tub heater. Use '#{HPXML::TypeNone}' if there is no hot tub heater.")
    arg.setDefaultValue(HPXML::TypeNone)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_heater_annual_kwh', false)
    arg.setDisplayName('Hot Tub: Heater Annual kWh')
    arg.setDescription("The annual energy consumption of the #{HPXML::HeaterTypeElectricResistance} hot tub heater. If not provided, the OS-HPXML default is used.")
    arg.setUnits('kWh/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_heater_annual_therm', false)
    arg.setDisplayName('Hot Tub: Heater Annual therm')
    arg.setDescription("The annual energy consumption of the #{HPXML::HeaterTypeGas} hot tub heater. If not provided, the OS-HPXML default is used.")
    arg.setUnits('therm/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_heater_usage_multiplier', false)
    arg.setDisplayName('Hot Tub: Heater Usage Multiplier')
    arg.setDescription('Multiplier on the hot tub heater energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default is used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('emissions_scenario_names', false)
    arg.setDisplayName('Emissions: Scenario Names')
    arg.setDescription('Names of emissions scenarios. If multiple scenarios, use a comma-separated list. If not provided, no emissions scenarios are calculated.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('emissions_types', false)
    arg.setDisplayName('Emissions: Types')
    arg.setDescription('Types of emissions (e.g., CO2e, NOx, etc.). If multiple scenarios, use a comma-separated list.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('emissions_electricity_units', false)
    arg.setDisplayName('Emissions: Electricity Units')
    arg.setDescription('Electricity emissions factors units. If multiple scenarios, use a comma-separated list. Only lb/MWh and kg/MWh are allowed.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('emissions_electricity_values_or_filepaths', false)
    arg.setDisplayName('Emissions: Electricity Values or File Paths')
    arg.setDescription('Electricity emissions factors values, specified as either an annual factor or an absolute/relative path to a file with hourly factors. If multiple scenarios, use a comma-separated list.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('emissions_electricity_number_of_header_rows', false)
    arg.setDisplayName('Emissions: Electricity Files Number of Header Rows')
    arg.setDescription('The number of header rows in the electricity emissions factor file. Only applies when an electricity filepath is used. If multiple scenarios, use a comma-separated list.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('emissions_electricity_column_numbers', false)
    arg.setDisplayName('Emissions: Electricity Files Column Numbers')
    arg.setDescription('The column number in the electricity emissions factor file. Only applies when an electricity filepath is used. If multiple scenarios, use a comma-separated list.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('emissions_fossil_fuel_units', false)
    arg.setDisplayName('Emissions: Fossil Fuel Units')
    arg.setDescription('Fossil fuel emissions factors units. If multiple scenarios, use a comma-separated list. Only lb/MBtu and kg/MBtu are allowed.')
    args << arg

    Constants.FossilFuels.each do |fossil_fuel|
      underscore_case = OpenStudio::toUnderscoreCase(fossil_fuel)
      all_caps_case = fossil_fuel.split(' ').map(&:capitalize).join(' ')
      cap_case = fossil_fuel.capitalize

      arg = OpenStudio::Measure::OSArgument.makeStringArgument("emissions_#{underscore_case}_values", false)
      arg.setDisplayName("Emissions: #{all_caps_case} Values")
      arg.setDescription("#{cap_case} emissions factors values, specified as an annual factor. If multiple scenarios, use a comma-separated list.")
      args << arg
    end

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('utility_bill_scenario_names', false)
    arg.setDisplayName('Utility Bills: Scenario Names')
    arg.setDescription('Names of utility bill scenarios. If multiple scenarios, use a comma-separated list. If not provided, no utility bills scenarios are calculated.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('utility_bill_electricity_filepaths', false)
    arg.setDisplayName('Utility Bills: Electricity File Paths')
    arg.setDescription('Electricity tariff file specified as an absolute/relative path to a file with utility rate structure information. Tariff file must be formatted to OpenEI API version 7. If multiple scenarios, use a comma-separated list.')
    args << arg

    ([HPXML::FuelTypeElectricity] + Constants.FossilFuels).each do |fuel|
      underscore_case = OpenStudio::toUnderscoreCase(fuel)
      all_caps_case = fuel.split(' ').map(&:capitalize).join(' ')
      cap_case = fuel.capitalize

      arg = OpenStudio::Measure::OSArgument.makeStringArgument("utility_bill_#{underscore_case}_fixed_charges", false)
      arg.setDisplayName("Utility Bills: #{all_caps_case} Fixed Charges")
      arg.setDescription("#{cap_case} utility bill monthly fixed charges. If multiple scenarios, use a comma-separated list.")
      args << arg
    end

    ([HPXML::FuelTypeElectricity] + Constants.FossilFuels).each do |fuel|
      underscore_case = OpenStudio::toUnderscoreCase(fuel)
      all_caps_case = fuel.split(' ').map(&:capitalize).join(' ')
      cap_case = fuel.capitalize

      arg = OpenStudio::Measure::OSArgument.makeStringArgument("utility_bill_#{underscore_case}_marginal_rates", false)
      arg.setDisplayName("Utility Bills: #{all_caps_case} Marginal Rates")
      arg.setDescription("#{cap_case} utility bill marginal rates. If multiple scenarios, use a comma-separated list.")
      args << arg
    end

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('utility_bill_pv_compensation_types', false)
    arg.setDisplayName('Utility Bills: PV Compensation Types')
    arg.setDescription('Utility bill PV compensation types. If multiple scenarios, use a comma-separated list.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('utility_bill_pv_net_metering_annual_excess_sellback_rate_types', false)
    arg.setDisplayName('Utility Bills: PV Net Metering Annual Excess Sellback Rate Types')
    arg.setDescription("Utility bill PV net metering annual excess sellback rate types. Only applies if the PV compensation type is '#{HPXML::PVCompensationTypeNetMetering}'. If multiple scenarios, use a comma-separated list.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('utility_bill_pv_net_metering_annual_excess_sellback_rates', false)
    arg.setDisplayName('Utility Bills: PV Net Metering Annual Excess Sellback Rates')
    arg.setDescription("Utility bill PV net metering annual excess sellback rates. Only applies if the PV compensation type is '#{HPXML::PVCompensationTypeNetMetering}' and the PV annual excess sellback rate type is '#{HPXML::PVAnnualExcessSellbackRateTypeUserSpecified}'. If multiple scenarios, use a comma-separated list.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('utility_bill_pv_feed_in_tariff_rates', false)
    arg.setDisplayName('Utility Bills: PV Feed-In Tariff Rates')
    arg.setDescription("Utility bill PV annual full/gross feed-in tariff rates. Only applies if the PV compensation type is '#{HPXML::PVCompensationTypeFeedInTariff}'. If multiple scenarios, use a comma-separated list.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('utility_bill_pv_monthly_grid_connection_fee_units', false)
    arg.setDisplayName('Utility Bills: PV Monthly Grid Connection Fee Units')
    arg.setDescription('Utility bill PV monthly grid connection fee units. If multiple scenarios, use a comma-separated list.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('utility_bill_pv_monthly_grid_connection_fees', false)
    arg.setDisplayName('Utility Bills: PV Monthly Grid Connection Fees')
    arg.setDescription('Utility bill PV monthly grid connection fees. If multiple scenarios, use a comma-separated list.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('additional_properties', false)
    arg.setDisplayName('Additional Properties')
    arg.setDescription("Additional properties specified as key-value pairs (i.e., key=value). If multiple additional properties, use a |-separated list. For example, 'LowIncome=false|Remodeled|Description=2-story home in Denver'. These properties will be stored in the HPXML file under /HPXML/SoftwareInfo/extension/AdditionalProperties.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('apply_defaults', false)
    arg.setDisplayName('Apply Default Values?')
    arg.setDescription('If true, applies OS-HPXML default values to the HPXML output file.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('apply_validation', false)
    arg.setDisplayName('Apply Validation?')
    arg.setDescription('If true, validates the HPXML output file. Set to false for faster performance. Note that validation is not needed if the HPXML file will be validated downstream (e.g., via the HPXMLtoOpenStudio measure).')
    arg.setDefaultValue(false)
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

    Geometry.tear_down_model(model, runner)

    Version.check_openstudio_version()

    # assign the user inputs to variables
    args = get_argument_values(runner, arguments(model), user_arguments)
    args = Hash[args.collect { |k, v| [k.to_sym, v] }]

    # Argument error checks
    warnings, errors = validate_arguments(args)
    unless warnings.empty?
      warnings.each do |warning|
        runner.registerWarning(warning)
      end
    end
    unless errors.empty?
      errors.each do |error|
        runner.registerError(error)
      end
      return false
    end

    # Create EpwFile object
    epw_path = args[:weather_station_epw_filepath]
    if not File.exist? epw_path
      epw_path = File.join(File.expand_path(File.join(File.dirname(__FILE__), '..', 'weather')), epw_path) # a filename was entered for weather_station_epw_filepath
    end
    if not File.exist? epw_path
      runner.registerError("Could not find EPW file at '#{epw_path}'.")
      return false
    end
    epw_file = OpenStudio::EpwFile.new(epw_path)

    # Create HPXML file
    hpxml_doc = HPXMLFile.create(runner, model, args, epw_file)
    if not hpxml_doc
      runner.registerError('Unsuccessful creation of HPXML file.')
      return false
    end

    hpxml_path = args[:hpxml_path]
    unless (Pathname.new hpxml_path).absolute?
      hpxml_path = File.expand_path(hpxml_path)
    end

    XMLHelper.write_file(hpxml_doc, hpxml_path)
    runner.registerInfo("Wrote file: #{hpxml_path}")

    # Check for invalid HPXML file
    if args[:apply_validation].is_initialized && args[:apply_validation].get
      if not validate_hpxml(runner, hpxml_path, hpxml_doc)
        return false
      end
    end

    # Uncomment for debugging purposes
    # File.write(hpxml_path.gsub('.xml', '.osm'), model.to_s)

    return true
  end

  def validate_arguments(args)
    warnings = argument_warnings(args)
    errors = argument_errors(args)

    return warnings, errors
  end

  def argument_warnings(args)
    warnings = []

    warning = ([HPXML::WaterHeaterTypeHeatPump].include?(args[:water_heater_type]) && (args[:water_heater_fuel_type] != HPXML::FuelTypeElectricity))
    warnings << 'Cannot model a heat pump water heater with non-electric fuel type.' if warning

    warning = [HPXML::FoundationTypeSlab, HPXML::FoundationTypeAboveApartment].include?(args[:geometry_foundation_type]) && (args[:geometry_foundation_height] > 0)
    warnings << "Foundation type of '#{args[:geometry_foundation_type]}' cannot have a non-zero height. Assuming height is zero." if warning

    warning = (args[:geometry_foundation_type] == HPXML::FoundationTypeSlab) && (args[:geometry_foundation_height_above_grade] > 0)
    warnings << 'Specified a slab foundation type with a non-zero height above grade.' if warning

    warning = (args[:heating_system_2_type] != 'none') && (args[:heating_system_2_fraction_heat_load_served] >= 0.5) && (args[:heating_system_2_fraction_heat_load_served] < 1.0)
    warnings << 'The fraction of heat load served by the second heating system is greater than or equal to 50%.' if warning

    warning = [HPXML::FoundationTypeCrawlspaceVented, HPXML::FoundationTypeCrawlspaceUnvented, HPXML::FoundationTypeBasementUnconditioned].include?(args[:geometry_foundation_type]) && ((args[:foundation_wall_insulation_r] > 0) || args[:foundation_wall_assembly_r].is_initialized) && (args[:floor_over_foundation_assembly_r] > 2.1)
    warnings << 'Home with unconditioned basement/crawlspace foundation type has both foundation wall insulation and floor insulation.' if warning

    warning = [HPXML::AtticTypeVented, HPXML::AtticTypeUnvented].include?(args[:geometry_attic_type]) && (args[:ceiling_assembly_r] > 2.1) && (args[:roof_assembly_r] > 2.3)
    warnings << 'Home with unconditioned attic type has both ceiling insulation and roof insulation.' if warning

    warning = (args[:geometry_foundation_type] == HPXML::FoundationTypeBasementConditioned) && (args[:floor_over_foundation_assembly_r] > 2.1)
    warnings << 'Home with conditioned basement has floor insulation.' if warning

    warning = (args[:geometry_attic_type] == HPXML::AtticTypeConditioned) && (args[:ceiling_assembly_r] > 2.1)
    warnings << 'Home with conditioned attic has ceiling insulation.' if warning

    return warnings
  end

  def argument_errors(args)
    errors = []

    error = (args[:heating_system_type] != 'none') && (args[:heat_pump_type] != 'none') && (args[:heating_system_fraction_heat_load_served] > 0) && (args[:heat_pump_fraction_heat_load_served] > 0)
    errors << 'Multiple central heating systems are not currently supported.' if error

    error = (args[:cooling_system_type] != 'none') && (args[:heat_pump_type] != 'none') && (args[:cooling_system_fraction_cool_load_served] > 0) && (args[:heat_pump_fraction_cool_load_served] > 0)
    errors << 'Multiple central cooling systems are not currently supported.' if error

    error = ![HPXML::FoundationTypeSlab, HPXML::FoundationTypeAboveApartment].include?(args[:geometry_foundation_type]) && (args[:geometry_foundation_height] == 0)
    errors << "Foundation type of '#{args[:geometry_foundation_type]}' cannot have a height of zero." if error

    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeApartment) && ([HPXML::FoundationTypeBasementConditioned, HPXML::FoundationTypeCrawlspaceConditioned].include? args[:geometry_foundation_type])
    errors << 'Conditioned basement/crawlspace foundation type for apartment units is not currently supported.' if error

    error = (args[:ducts_supply_location].is_initialized != args[:ducts_supply_surface_area].is_initialized) || (args[:ducts_return_location].is_initialized != args[:ducts_return_surface_area].is_initialized)
    errors << 'Duct location and surface area not both defaulted or not both specified.' if error

    error = (args[:heating_system_2_type] != 'none') && (args[:heating_system_2_fraction_heat_load_served] == 1.0)
    errors << 'The fraction of heat load served by the second heating system is 100%.' if error

    error = (args[:heating_system_type] == 'none') && (args[:heat_pump_type] == 'none') && (args[:heating_system_2_type] != 'none')
    errors << 'A second heating system was specified without a primary heating system.' if error

    error = [HPXML::ResidentialTypeSFA, HPXML::ResidentialTypeApartment].include?(args[:geometry_unit_type]) && !args[:geometry_building_num_units].is_initialized
    errors << 'Did not specify the number of units in the building for single-family attached or apartment units.' if error

    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeApartment) && (args[:geometry_unit_num_floors_above_grade] > 1)
    errors << 'Apartment units can only have one above-grade floor.' if error

    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeSFD) && (args[:geometry_unit_left_wall_is_adiabatic] || args[:geometry_unit_right_wall_is_adiabatic] || args[:geometry_unit_front_wall_is_adiabatic] || args[:geometry_unit_back_wall_is_adiabatic] || (args[:geometry_attic_type] == HPXML::AtticTypeBelowApartment) || (args[:geometry_foundation_type] == HPXML::FoundationTypeAboveApartment))
    errors << 'No adiabatic surfaces can be applied to single-family detached homes.' if error

    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeApartment) && (args[:geometry_attic_type] == HPXML::AtticTypeConditioned)
    errors << 'Conditioned attic type for apartment units is not currently supported.' if error

    error = (args[:geometry_unit_num_floors_above_grade] == 1 && args[:geometry_attic_type] == HPXML::AtticTypeConditioned)
    errors << 'Units with a conditioned attic must have at least two above-grade floors.' if error

    error = ((args[:water_heater_type] == HPXML::WaterHeaterTypeCombiStorage) || (args[:water_heater_type] == HPXML::WaterHeaterTypeCombiTankless)) && (args[:heating_system_type] != HPXML::HVACTypeBoiler)
    errors << 'Must specify a boiler when modeling an indirect water heater type.' if error

    error = (args[:geometry_unit_num_bedrooms] <= 0)
    errors << 'Number of bedrooms must be greater than zero.' if error

    error = [HPXML::ResidentialTypeSFD].include?(args[:geometry_unit_type]) && args[:heating_system_type].include?('Shared')
    errors << 'Specified a shared system for a single-family detached unit.' if error

    error = args[:geometry_rim_joist_height].is_initialized && !args[:rim_joist_assembly_r].is_initialized
    errors << 'Specified a rim joist height but no rim joist assembly R-value.' if error

    error = args[:rim_joist_assembly_r].is_initialized && !args[:geometry_rim_joist_height].is_initialized
    errors << 'Specified a rim joist assembly R-value but no rim joist height.' if error

    emissions_args_initialized = [args[:emissions_scenario_names].is_initialized,
                                  args[:emissions_types].is_initialized,
                                  args[:emissions_electricity_units].is_initialized,
                                  args[:emissions_electricity_values_or_filepaths].is_initialized]
    error = (emissions_args_initialized.uniq.size != 1)
    errors << 'Did not specify all required emissions arguments.' if error

    Constants.FossilFuels.each do |fossil_fuel|
      underscore_case = OpenStudio::toUnderscoreCase(fossil_fuel)

      if args["emissions_#{underscore_case}_values".to_sym].is_initialized
        error = !args[:emissions_fossil_fuel_units].is_initialized
        errors << "Did not specify fossil fuel emissions units for #{fossil_fuel} emissions values." if error
      end
    end

    if emissions_args_initialized.uniq.size == 1 && emissions_args_initialized.uniq[0]
      emissions_scenario_lengths = [args[:emissions_scenario_names].get.count(','),
                                    args[:emissions_types].get.count(','),
                                    args[:emissions_electricity_units].get.count(','),
                                    args[:emissions_electricity_values_or_filepaths].get.count(',')]

      emissions_scenario_lengths += [args[:emissions_electricity_number_of_header_rows].get.count(',')] if args[:emissions_electricity_number_of_header_rows].is_initialized
      emissions_scenario_lengths += [args[:emissions_electricity_column_numbers].get.count(',')] if args[:emissions_electricity_column_numbers].is_initialized

      Constants.FossilFuels.each do |fossil_fuel|
        underscore_case = OpenStudio::toUnderscoreCase(fossil_fuel)

        emissions_scenario_lengths += [args["emissions_#{underscore_case}_values".to_sym].get.count(',')] if args["emissions_#{underscore_case}_values".to_sym].is_initialized
      end

      error = (emissions_scenario_lengths.uniq.size != 1)
      errors << 'One or more emissions arguments does not have enough comma-separated elements specified.' if error
    end

    bills_args_initialized = [args[:utility_bill_scenario_names].is_initialized]
    if bills_args_initialized.uniq[0]
      bills_scenario_lengths = [args[:utility_bill_scenario_names].get.count(',')]
      ([HPXML::FuelTypeElectricity] + Constants.FossilFuels).each do |fuel|
        underscore_case = OpenStudio::toUnderscoreCase(fuel)

        bills_scenario_lengths += [args["utility_bill_#{underscore_case}_fixed_charges".to_sym].get.count(',')] if args["utility_bill_#{underscore_case}_fixed_charges".to_sym].is_initialized
        bills_scenario_lengths += [args["utility_bill_#{underscore_case}_marginal_rates".to_sym].get.count(',')] if args["utility_bill_#{underscore_case}_marginal_rates".to_sym].is_initialized
      end

      error = (bills_scenario_lengths.uniq.size != 1)
      errors << 'One or more utility bill arguments does not have enough comma-separated elements specified.' if error
    end

    error = (args[:geometry_unit_aspect_ratio] <= 0)
    errors << 'Aspect ratio must be greater than zero.' if error

    error = (args[:geometry_foundation_height] < 0)
    errors << 'Foundation height cannot be negative.' if error

    error = (args[:geometry_unit_num_floors_above_grade] > 6)
    errors << 'Number of above-grade floors must be six or less.' if error

    error = (args[:geometry_garage_protrusion] < 0) || (args[:geometry_garage_protrusion] > 1)
    errors << 'Garage protrusion fraction must be between zero and one.' if error

    error = (args[:geometry_unit_left_wall_is_adiabatic] && args[:geometry_unit_right_wall_is_adiabatic] && args[:geometry_unit_front_wall_is_adiabatic] && args[:geometry_unit_back_wall_is_adiabatic])
    errors << 'At least one wall must be set to non-adiabatic.' if error

    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeSFA) && (args[:geometry_foundation_type] == HPXML::FoundationTypeAboveApartment)
    errors << 'Single-family attached units cannot be above another unit.' if error

    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeSFA) && (args[:geometry_attic_type] == HPXML::AtticTypeBelowApartment)
    errors << 'Single-family attached units cannot be below another unit.' if error

    error = (args[:geometry_garage_protrusion] > 0) && (args[:geometry_roof_type] == 'hip') && (args[:geometry_garage_width] * args[:geometry_garage_depth] > 0)
    errors << 'Cannot handle protruding garage and hip roof.' if error

    error = (args[:geometry_garage_protrusion] > 0) && (args[:geometry_unit_aspect_ratio] < 1) && (args[:geometry_garage_width] * args[:geometry_garage_depth] > 0) && (args[:geometry_roof_type] == 'gable')
    errors << 'Cannot handle protruding garage and attic ridge running from front to back.' if error

    error = (args[:geometry_foundation_type] == HPXML::FoundationTypeAmbient) && (args[:geometry_garage_width] * args[:geometry_garage_depth] > 0)
    errors << 'Cannot handle garages with an ambient foundation type.' if error

    error = (args[:door_area] < 0)
    errors << 'Door area cannot be negative.' if error

    error = (args[:window_aspect_ratio] <= 0)
    errors << 'Window aspect ratio must be greater than zero.' if error

    return errors
  end

  def validate_hpxml(runner, hpxml_path, hpxml_doc)
    is_valid = true

    # Validate input HPXML against schema
    schema_dir = File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources/hpxml_schema')
    schema_path = File.join(schema_dir, 'HPXML.xsd')
    xsd_errors, xsd_warnings = XMLValidator.validate_against_schema(hpxml_path, schema_path)

    # Validate input HPXML against schematron docs
    schematron_dir = File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources/hpxml_schematron')
    schematron_path = File.join(schematron_dir, 'EPvalidator.xml')
    sct_errors, sct_warnings = XMLValidator.validate_against_schematron(hpxml_path, schematron_path, hpxml_doc)

    # Handle errors/warnings
    (xsd_errors + sct_errors).each do |error|
      runner.registerError("#{hpxml_path}: #{error}")
      is_valid = false
    end
    (xsd_warnings + sct_warnings).each do |warning|
      runner.registerWarning("#{hpxml_path}: #{warning}")
    end

    return is_valid
  end
end

class HPXMLFile
  def self.create(runner, model, args, epw_file)
    if (args[:hvac_control_heating_season_period].to_s == HPXML::BuildingAmerica) || (args[:hvac_control_cooling_season_period].to_s == HPXML::BuildingAmerica) || (args[:apply_defaults].is_initialized && args[:apply_defaults].get)
      OpenStudio::Model::WeatherFile.setWeatherFile(model, epw_file)
      weather = WeatherProcess.new(model, runner)
    end

    success = create_geometry_envelope(runner, model, args)
    return false if not success

    @surface_ids = {}

    # Sorting of objects to make the measure deterministic
    sorted_surfaces = model.getSurfaces.sort_by { |s| s.additionalProperties.getFeatureAsInteger('Index').get }
    sorted_subsurfaces = model.getSubSurfaces.sort_by { |ss| ss.additionalProperties.getFeatureAsInteger('Index').get }

    hpxml = HPXML.new

    set_header(hpxml, args)
    set_site(hpxml, args)
    set_neighbor_buildings(hpxml, args)
    set_building_occupancy(hpxml, args)
    set_building_construction(hpxml, args)
    set_climate_and_risk_zones(hpxml, args)
    set_air_infiltration_measurements(hpxml, args)
    set_roofs(hpxml, args, sorted_surfaces)
    set_rim_joists(hpxml, model, args, sorted_surfaces)
    set_walls(hpxml, model, args, sorted_surfaces)
    set_foundation_walls(hpxml, model, args, sorted_surfaces)
    set_floors(hpxml, args, sorted_surfaces)
    set_slabs(hpxml, model, args, sorted_surfaces)
    set_windows(hpxml, model, args, sorted_subsurfaces)
    set_skylights(hpxml, args, sorted_subsurfaces)
    set_doors(hpxml, model, args, sorted_subsurfaces)
    set_attics(hpxml, args)
    set_foundations(hpxml, args)
    set_heating_systems(hpxml, args)
    set_cooling_systems(hpxml, args)
    set_heat_pumps(hpxml, args)
    set_secondary_heating_systems(hpxml, args)
    set_hvac_distribution(hpxml, args)
    set_hvac_control(hpxml, args, epw_file, weather)
    set_ventilation_fans(hpxml, args)
    set_water_heating_systems(hpxml, args)
    set_hot_water_distribution(hpxml, args)
    set_water_fixtures(hpxml, args)
    set_solar_thermal(hpxml, args, epw_file)
    set_pv_systems(hpxml, args, epw_file)
    set_battery(hpxml, args)
    set_lighting(hpxml, args)
    set_dehumidifier(hpxml, args)
    set_clothes_washer(hpxml, args)
    set_clothes_dryer(hpxml, args)
    set_dishwasher(hpxml, args)
    set_refrigerator(hpxml, args)
    set_extra_refrigerator(hpxml, args)
    set_freezer(hpxml, args)
    set_cooking_range_oven(hpxml, args)
    set_ceiling_fans(hpxml, args)
    set_misc_plug_loads_television(hpxml, args)
    set_misc_plug_loads_other(hpxml, args)
    set_misc_plug_loads_vehicle(hpxml, args)
    set_misc_plug_loads_well_pump(hpxml, args)
    set_misc_fuel_loads_grill(hpxml, args)
    set_misc_fuel_loads_lighting(hpxml, args)
    set_misc_fuel_loads_fireplace(hpxml, args)
    set_pool(hpxml, args)
    set_hot_tub(hpxml, args)

    # Collapse surfaces so that we don't get, e.g., individual windows
    # or the front wall split because of the door. Exclude foundation walls
    # from the list so we get all 4 foundation walls.
    hpxml.collapse_enclosure_surfaces([:roofs, :walls, :rim_joists, :floors,
                                       :slabs, :windows, :skylights, :doors])

    # After surfaces are collapsed, round all areas
    (hpxml.roofs +
     hpxml.rim_joists +
     hpxml.walls +
     hpxml.foundation_walls +
     hpxml.floors +
     hpxml.slabs +
     hpxml.windows +
     hpxml.skylights +
     hpxml.doors).each do |s|
      s.area = s.area.round(1)
    end

    # Check for errors in the HPXML object
    if args[:apply_validation].is_initialized && args[:apply_validation].get
      errors = hpxml.check_for_errors()
      if errors.size > 0
        fail "ERROR: Invalid HPXML object produced.\n#{errors}"
      end
    end

    if args[:apply_defaults].is_initialized && args[:apply_defaults].get
      eri_version = Constants.ERIVersions[-1]
      HPXMLDefaults.apply(runner, hpxml, eri_version, weather, epw_file: epw_file)
    end

    hpxml_doc = hpxml.to_oga()

    return hpxml_doc
  end

  def self.create_geometry_envelope(runner, model, args)
    args[:geometry_roof_pitch] = { '1:12' => 1.0 / 12.0,
                                   '2:12' => 2.0 / 12.0,
                                   '3:12' => 3.0 / 12.0,
                                   '4:12' => 4.0 / 12.0,
                                   '5:12' => 5.0 / 12.0,
                                   '6:12' => 6.0 / 12.0,
                                   '7:12' => 7.0 / 12.0,
                                   '8:12' => 8.0 / 12.0,
                                   '9:12' => 9.0 / 12.0,
                                   '10:12' => 10.0 / 12.0,
                                   '11:12' => 11.0 / 12.0,
                                   '12:12' => 12.0 / 12.0 }[args[:geometry_roof_pitch]]

    if args[:geometry_rim_joist_height].is_initialized
      args[:geometry_rim_joist_height] = args[:geometry_rim_joist_height].get / 12.0
    else
      args[:geometry_rim_joist_height] = 0.0
    end

    if args[:geometry_foundation_type] == HPXML::FoundationTypeSlab
      args[:geometry_foundation_height] = 0.0
      args[:geometry_foundation_height_above_grade] = 0.0
      args[:geometry_rim_joist_height] = 0.0
    elsif args[:geometry_foundation_type] == HPXML::FoundationTypeAmbient
      args[:geometry_rim_joist_height] = 0.0
    end

    if model.getSpaces.size > 0
      runner.registerError('Starting model is not empty.')
      return false
    end

    if args[:geometry_unit_type] == HPXML::ResidentialTypeSFD
      success = Geometry.create_single_family_detached(runner: runner, model: model, **args)
    elsif args[:geometry_unit_type] == HPXML::ResidentialTypeSFA
      success = Geometry.create_single_family_attached(model: model, **args)
    elsif args[:geometry_unit_type] == HPXML::ResidentialTypeApartment
      success = Geometry.create_apartment(model: model, **args)
    end
    return false if not success

    success = Geometry.create_doors(runner: runner, model: model, **args)
    return false if not success

    success = Geometry.create_windows_and_skylights(runner: runner, model: model, **args)
    return false if not success

    return true
  end

  def self.set_header(hpxml, args)
    hpxml.header.xml_type = 'HPXML'
    hpxml.header.xml_generated_by = 'BuildResidentialHPXML'
    hpxml.header.transaction = 'create'

    if args[:occupancy_calculation_type].is_initialized
      hpxml.header.occupancy_calculation_type = args[:occupancy_calculation_type].get
    end
    if args[:window_natvent_availability].is_initialized
      hpxml.header.natvent_days_per_week = args[:window_natvent_availability].get
    end
    if args[:schedules_filepaths].is_initialized
      hpxml.header.schedules_filepaths = args[:schedules_filepaths].get.split(',').map(&:strip)
    end

    if args[:software_info_program_used].is_initialized
      hpxml.header.software_program_used = args[:software_info_program_used].get
    end
    if args[:software_info_program_version].is_initialized
      hpxml.header.software_program_version = args[:software_info_program_version].get
    end

    if args[:simulation_control_timestep].is_initialized
      hpxml.header.timestep = args[:simulation_control_timestep].get
    end

    if args[:simulation_control_run_period].is_initialized
      begin_month, begin_day, end_month, end_day = Schedule.parse_date_range(args[:simulation_control_run_period].get)
      hpxml.header.sim_begin_month = begin_month
      hpxml.header.sim_begin_day = begin_day
      hpxml.header.sim_end_month = end_month
      hpxml.header.sim_end_day = end_day
    end

    if args[:simulation_control_run_period_calendar_year].is_initialized
      hpxml.header.sim_calendar_year = args[:simulation_control_run_period_calendar_year].get
    end

    if args[:simulation_control_daylight_saving_enabled].is_initialized
      hpxml.header.dst_enabled = args[:simulation_control_daylight_saving_enabled].get
    end
    if args[:simulation_control_daylight_saving_period].is_initialized
      begin_month, begin_day, end_month, end_day = Schedule.parse_date_range(args[:simulation_control_daylight_saving_period].get)
      hpxml.header.dst_begin_month = begin_month
      hpxml.header.dst_begin_day = begin_day
      hpxml.header.dst_end_month = end_month
      hpxml.header.dst_end_day = end_day
    end

    if args[:simulation_control_temperature_capacitance_multiplier].is_initialized
      hpxml.header.temperature_capacitance_multiplier = args[:simulation_control_temperature_capacitance_multiplier].get
    end

    hpxml.header.building_id = 'MyBuilding'
    hpxml.header.event_type = 'proposed workscope'

    if args[:site_zip_code].is_initialized
      hpxml.header.zip_code = args[:site_zip_code].get
    end

    if args[:site_state_code].is_initialized
      hpxml.header.state_code = args[:site_state_code].get
    end

    if args[:site_time_zone_utc_offset].is_initialized
      hpxml.header.time_zone_utc_offset = args[:site_time_zone_utc_offset].get
    end

    if args[:emissions_scenario_names].is_initialized
      emissions_scenario_names = args[:emissions_scenario_names].get.split(',').map(&:strip)
      emissions_types = args[:emissions_types].get.split(',').map(&:strip)
      emissions_electricity_units = args[:emissions_electricity_units].get.split(',').map(&:strip)
      emissions_electricity_values_or_filepaths = args[:emissions_electricity_values_or_filepaths].get.split(',').map(&:strip)

      if args[:emissions_electricity_number_of_header_rows].is_initialized
        emissions_electricity_number_of_header_rows = args[:emissions_electricity_number_of_header_rows].get.split(',').map(&:strip)
      else
        emissions_electricity_number_of_header_rows = [nil] * emissions_scenario_names.size
      end
      if args[:emissions_electricity_column_numbers].is_initialized
        emissions_electricity_column_numbers = args[:emissions_electricity_column_numbers].get.split(',').map(&:strip)
      else
        emissions_electricity_column_numbers = [nil] * emissions_scenario_names.size
      end
      if args[:emissions_fossil_fuel_units].is_initialized
        fuel_units = args[:emissions_fossil_fuel_units].get.split(',').map(&:strip)
      else
        fuel_units = [nil] * emissions_scenario_names.size
      end

      fuel_values = {}
      Constants.FossilFuels.each do |fossil_fuel|
        underscore_case = OpenStudio::toUnderscoreCase(fossil_fuel)

        if args["emissions_#{underscore_case}_values".to_sym].is_initialized
          fuel_values[fossil_fuel] = args["emissions_#{underscore_case}_values".to_sym].get.split(',').map(&:strip)
        else
          fuel_values[fossil_fuel] = [nil] * emissions_scenario_names.size
        end
      end

      emissions_scenarios = emissions_scenario_names.zip(emissions_types,
                                                         emissions_electricity_units,
                                                         emissions_electricity_values_or_filepaths,
                                                         emissions_electricity_number_of_header_rows,
                                                         emissions_electricity_column_numbers,
                                                         fuel_units,
                                                         fuel_values[HPXML::FuelTypeNaturalGas],
                                                         fuel_values[HPXML::FuelTypePropane],
                                                         fuel_values[HPXML::FuelTypeOil],
                                                         fuel_values[HPXML::FuelTypeCoal],
                                                         fuel_values[HPXML::FuelTypeWoodCord],
                                                         fuel_values[HPXML::FuelTypeWoodPellets])
      emissions_scenarios.each do |emissions_scenario|
        name, emissions_type, elec_units, elec_value_or_schedule_filepath, elec_num_headers, elec_column_num, fuel_units, natural_gas_value, propane_value, fuel_oil_value, coal_value, wood_value, wood_pellets_value = emissions_scenario
        elec_value = Float(elec_value_or_schedule_filepath) rescue nil
        if elec_value.nil?
          elec_schedule_filepath = elec_value_or_schedule_filepath
          elec_num_headers = Integer(elec_num_headers) rescue nil
          elec_column_num = Integer(elec_column_num) rescue nil
        end
        natural_gas_value = Float(natural_gas_value) rescue nil
        propane_value = Float(propane_value) rescue nil
        fuel_oil_value = Float(fuel_oil_value) rescue nil
        coal_value = Float(coal_value) rescue nil
        wood_value = Float(wood_value) rescue nil
        wood_pellets_value = Float(wood_pellets_value) rescue nil

        hpxml.header.emissions_scenarios.add(name: name,
                                             emissions_type: emissions_type,
                                             elec_units: elec_units,
                                             elec_value: elec_value,
                                             elec_schedule_filepath: elec_schedule_filepath,
                                             elec_schedule_number_of_header_rows: elec_num_headers,
                                             elec_schedule_column_number: elec_column_num,
                                             natural_gas_units: fuel_units,
                                             natural_gas_value: natural_gas_value,
                                             propane_units: fuel_units,
                                             propane_value: propane_value,
                                             fuel_oil_units: fuel_units,
                                             fuel_oil_value: fuel_oil_value,
                                             coal_units: fuel_units,
                                             coal_value: coal_value,
                                             wood_units: fuel_units,
                                             wood_value: wood_value,
                                             wood_pellets_units: fuel_units,
                                             wood_pellets_value: wood_pellets_value)
      end
    end

    if args[:utility_bill_scenario_names].is_initialized
      bills_scenario_names = args[:utility_bill_scenario_names].get.split(',').map(&:strip)

      if args[:utility_bill_electricity_filepaths].is_initialized
        bills_electricity_filepaths = args[:utility_bill_electricity_filepaths].get.split(',').map(&:strip)
      else
        bills_electricity_filepaths = [nil] * bills_scenario_names.size
      end

      fixed_charges = {}
      ([HPXML::FuelTypeElectricity] + Constants.FossilFuels).each do |fuel|
        underscore_case = OpenStudio::toUnderscoreCase(fuel)

        if args["utility_bill_#{underscore_case}_fixed_charges".to_sym].is_initialized
          fixed_charges[fuel] = args["utility_bill_#{underscore_case}_fixed_charges".to_sym].get.split(',').map(&:strip)
        else
          fixed_charges[fuel] = [nil] * bills_scenario_names.size
        end
      end

      marginal_rates = {}
      ([HPXML::FuelTypeElectricity] + Constants.FossilFuels).each do |fuel|
        underscore_case = OpenStudio::toUnderscoreCase(fuel)

        if args["utility_bill_#{underscore_case}_marginal_rates".to_sym].is_initialized
          marginal_rates[fuel] = args["utility_bill_#{underscore_case}_marginal_rates".to_sym].get.split(',').map(&:strip)
        else
          marginal_rates[fuel] = [nil] * bills_scenario_names.size
        end
      end

      if args[:utility_bill_pv_compensation_types].is_initialized
        bills_pv_compensation_types = args[:utility_bill_pv_compensation_types].get.split(',').map(&:strip)
      else
        bills_pv_compensation_types = [nil] * bills_scenario_names.size
      end

      if args[:utility_bill_pv_net_metering_annual_excess_sellback_rate_types].is_initialized
        bills_pv_net_metering_annual_excess_sellback_rate_types = args[:utility_bill_pv_net_metering_annual_excess_sellback_rate_types].get.split(',').map(&:strip)
      else
        bills_pv_net_metering_annual_excess_sellback_rate_types = [nil] * bills_scenario_names.size
      end

      if args[:utility_bill_pv_net_metering_annual_excess_sellback_rates].is_initialized
        bills_pv_net_metering_annual_excess_sellback_rates = args[:utility_bill_pv_net_metering_annual_excess_sellback_rates].get.split(',').map(&:strip)
      else
        bills_pv_net_metering_annual_excess_sellback_rates = [nil] * bills_scenario_names.size
      end

      if args[:utility_bill_pv_feed_in_tariff_rates].is_initialized
        bills_pv_feed_in_tariff_rates = args[:utility_bill_pv_feed_in_tariff_rates].get.split(',').map(&:strip)
      else
        bills_pv_feed_in_tariff_rates = [nil] * bills_scenario_names.size
      end

      if args[:utility_bill_pv_monthly_grid_connection_fee_units].is_initialized
        bills_pv_monthly_grid_connection_fee_units = args[:utility_bill_pv_monthly_grid_connection_fee_units].get.split(',').map(&:strip)
      else
        bills_pv_monthly_grid_connection_fee_units = [nil] * bills_scenario_names.size
      end

      if args[:utility_bill_pv_monthly_grid_connection_fees].is_initialized
        bills_pv_monthly_grid_connection_fees = args[:utility_bill_pv_monthly_grid_connection_fees].get.split(',').map(&:strip)
      else
        bills_pv_monthly_grid_connection_fees = [nil] * bills_scenario_names.size
      end

      bills_scenarios = bills_scenario_names.zip(bills_electricity_filepaths,
                                                 fixed_charges[HPXML::FuelTypeElectricity],
                                                 fixed_charges[HPXML::FuelTypeNaturalGas],
                                                 fixed_charges[HPXML::FuelTypePropane],
                                                 fixed_charges[HPXML::FuelTypeOil],
                                                 fixed_charges[HPXML::FuelTypeCoal],
                                                 fixed_charges[HPXML::FuelTypeWoodCord],
                                                 fixed_charges[HPXML::FuelTypeWoodPellets],
                                                 marginal_rates[HPXML::FuelTypeElectricity],
                                                 marginal_rates[HPXML::FuelTypeNaturalGas],
                                                 marginal_rates[HPXML::FuelTypePropane],
                                                 marginal_rates[HPXML::FuelTypeOil],
                                                 marginal_rates[HPXML::FuelTypeCoal],
                                                 marginal_rates[HPXML::FuelTypeWoodCord],
                                                 marginal_rates[HPXML::FuelTypeWoodPellets],
                                                 bills_pv_compensation_types,
                                                 bills_pv_net_metering_annual_excess_sellback_rate_types,
                                                 bills_pv_net_metering_annual_excess_sellback_rates,
                                                 bills_pv_feed_in_tariff_rates,
                                                 bills_pv_monthly_grid_connection_fee_units,
                                                 bills_pv_monthly_grid_connection_fees)

      bills_scenarios.each do |bills_scenario|
        name, elec_tariff_filepath, elec_fixed_charge, natural_gas_fixed_charge, propane_fixed_charge, fuel_oil_fixed_charge, coal_fixed_charge, wood_fixed_charge, wood_pellets_fixed_charge, elec_marginal_rate, natural_gas_marginal_rate, propane_marginal_rate, fuel_oil_marginal_rate, coal_marginal_rate, wood_marginal_rate, wood_pellets_marginal_rate, pv_compensation_type, pv_net_metering_annual_excess_sellback_rate_type, pv_net_metering_annual_excess_sellback_rate, pv_feed_in_tariff_rate, pv_monthly_grid_connection_fee_unit, pv_monthly_grid_connection_fee = bills_scenario
        elec_tariff_filepath = (elec_tariff_filepath.to_s.include?('.') ? elec_tariff_filepath : nil)
        elec_fixed_charge = Float(elec_fixed_charge) rescue nil
        natural_gas_fixed_charge = Float(natural_gas_fixed_charge) rescue nil
        propane_fixed_charge = Float(propane_fixed_charge) rescue nil
        fuel_oil_fixed_charge = Float(fuel_oil_fixed_charge) rescue nil
        coal_fixed_charge = Float(coal_fixed_charge) rescue nil
        wood_fixed_charge = Float(wood_fixed_charge) rescue nil
        wood_pellets_fixed_charge = Float(wood_pellets_fixed_charge) rescue nil
        elec_marginal_rate = Float(elec_marginal_rate) rescue nil
        natural_gas_marginal_rate = Float(natural_gas_marginal_rate) rescue nil
        propane_marginal_rate = Float(propane_marginal_rate) rescue nil
        fuel_oil_marginal_rate = Float(fuel_oil_marginal_rate) rescue nil
        coal_marginal_rate = Float(coal_marginal_rate) rescue nil
        wood_marginal_rate = Float(wood_marginal_rate) rescue nil
        wood_pellets_marginal_rate = Float(wood_pellets_marginal_rate) rescue nil

        if pv_compensation_type == HPXML::PVCompensationTypeNetMetering
          if pv_net_metering_annual_excess_sellback_rate_type == HPXML::PVAnnualExcessSellbackRateTypeUserSpecified
            pv_net_metering_annual_excess_sellback_rate = Float(pv_net_metering_annual_excess_sellback_rate) rescue nil
          else
            pv_net_metering_annual_excess_sellback_rate = nil
          end
          pv_feed_in_tariff_rate = nil
        elsif pv_compensation_type == HPXML::PVCompensationTypeFeedInTariff
          pv_feed_in_tariff_rate = Float(pv_feed_in_tariff_rate) rescue nil
          pv_net_metering_annual_excess_sellback_rate_type = nil
          pv_net_metering_annual_excess_sellback_rate = nil
        end

        if pv_monthly_grid_connection_fee_unit == HPXML::UnitsDollarsPerkW
          pv_monthly_grid_connection_fee_dollars_per_kw = Float(pv_monthly_grid_connection_fee) rescue nil
        elsif pv_monthly_grid_connection_fee_unit == HPXML::UnitsDollars
          pv_monthly_grid_connection_fee_dollars = Float(pv_monthly_grid_connection_fee) rescue nil
        end

        hpxml.header.utility_bill_scenarios.add(name: name,
                                                elec_tariff_filepath: elec_tariff_filepath,
                                                elec_fixed_charge: elec_fixed_charge,
                                                natural_gas_fixed_charge: natural_gas_fixed_charge,
                                                propane_fixed_charge: propane_fixed_charge,
                                                fuel_oil_fixed_charge: fuel_oil_fixed_charge,
                                                coal_fixed_charge: coal_fixed_charge,
                                                wood_fixed_charge: wood_fixed_charge,
                                                wood_pellets_fixed_charge: wood_pellets_fixed_charge,
                                                elec_marginal_rate: elec_marginal_rate,
                                                natural_gas_marginal_rate: natural_gas_marginal_rate,
                                                propane_marginal_rate: propane_marginal_rate,
                                                fuel_oil_marginal_rate: fuel_oil_marginal_rate,
                                                coal_marginal_rate: coal_marginal_rate,
                                                wood_marginal_rate: wood_marginal_rate,
                                                wood_pellets_marginal_rate: wood_pellets_marginal_rate,
                                                pv_compensation_type: pv_compensation_type,
                                                pv_net_metering_annual_excess_sellback_rate_type: pv_net_metering_annual_excess_sellback_rate_type,
                                                pv_net_metering_annual_excess_sellback_rate: pv_net_metering_annual_excess_sellback_rate,
                                                pv_feed_in_tariff_rate: pv_feed_in_tariff_rate,
                                                pv_monthly_grid_connection_fee_dollars_per_kw: pv_monthly_grid_connection_fee_dollars_per_kw,
                                                pv_monthly_grid_connection_fee_dollars: pv_monthly_grid_connection_fee_dollars)
      end
    end

    if args[:additional_properties].is_initialized
      extension_properties = {}
      additional_properties = args[:additional_properties].get.split('|').map(&:strip)
      additional_properties.each do |additional_property|
        key, value = additional_property.split('=').map(&:strip)
        extension_properties[key] = value
      end
      hpxml.header.extension_properties = extension_properties
    end
  end

  def self.set_site(hpxml, args)
    if args[:site_shielding_of_home].is_initialized
      hpxml.site.shielding_of_home = args[:site_shielding_of_home].get
    end

    if args[:site_ground_conductivity].is_initialized
      hpxml.site.ground_conductivity = args[:site_ground_conductivity].get
    end

    if args[:site_type].is_initialized
      hpxml.site.site_type = args[:site_type].get
    end

    adb_walls = [args[:geometry_unit_left_wall_is_adiabatic], args[:geometry_unit_right_wall_is_adiabatic], args[:geometry_unit_front_wall_is_adiabatic], args[:geometry_unit_back_wall_is_adiabatic]]
    n_walls_attached = adb_walls.count(true)

    if [HPXML::ResidentialTypeSFA, HPXML::ResidentialTypeApartment].include? args[:geometry_unit_type]
      if n_walls_attached == 3
        hpxml.site.surroundings = HPXML::SurroundingsThreeSides
      elsif n_walls_attached == 2
        hpxml.site.surroundings = HPXML::SurroundingsTwoSides
      elsif n_walls_attached == 1
        hpxml.site.surroundings = HPXML::SurroundingsOneSide
      else
        hpxml.site.surroundings = HPXML::SurroundingsStandAlone
      end
      if args[:geometry_attic_type] == HPXML::AtticTypeBelowApartment
        if args[:geometry_foundation_type] == HPXML::FoundationTypeAboveApartment
          hpxml.site.vertical_surroundings = HPXML::VerticalSurroundingsAboveAndBelow
        else
          hpxml.site.vertical_surroundings = HPXML::VerticalSurroundingsAbove
        end
      else
        if args[:geometry_foundation_type] == HPXML::FoundationTypeAboveApartment
          hpxml.site.vertical_surroundings = HPXML::VerticalSurroundingsBelow
        else
          hpxml.site.vertical_surroundings = HPXML::VerticalSurroundingsNoAboveOrBelow
        end
      end
    elsif [HPXML::ResidentialTypeSFD].include? args[:geometry_unit_type]
      hpxml.site.surroundings = HPXML::SurroundingsStandAlone
      hpxml.site.vertical_surroundings = HPXML::VerticalSurroundingsNoAboveOrBelow
    end

    hpxml.site.azimuth_of_front_of_home = args[:geometry_unit_orientation]
  end

  def self.set_neighbor_buildings(hpxml, args)
    nbr_map = { Constants.FacadeFront => [args[:neighbor_front_distance], args[:neighbor_front_height]],
                Constants.FacadeBack => [args[:neighbor_back_distance], args[:neighbor_back_height]],
                Constants.FacadeLeft => [args[:neighbor_left_distance], args[:neighbor_left_height]],
                Constants.FacadeRight => [args[:neighbor_right_distance], args[:neighbor_right_height]] }

    nbr_map.each do |facade, data|
      distance, neighbor_height = data
      next if distance == 0

      azimuth = Geometry.get_azimuth_from_facade(facade: facade, orientation: args[:geometry_unit_orientation])

      if (distance > 0) && neighbor_height.is_initialized
        height = neighbor_height.get
      end

      hpxml.neighbor_buildings.add(azimuth: azimuth,
                                   distance: distance,
                                   height: height)
    end
  end

  def self.set_building_occupancy(hpxml, args)
    if args[:geometry_unit_num_occupants].is_initialized
      hpxml.building_occupancy.number_of_residents = args[:geometry_unit_num_occupants].get
    end
  end

  def self.set_building_construction(hpxml, args)
    if args[:geometry_unit_type] == HPXML::ResidentialTypeApartment
      args[:geometry_unit_num_floors_above_grade] = 1
    end
    number_of_conditioned_floors_above_grade = args[:geometry_unit_num_floors_above_grade]
    number_of_conditioned_floors = number_of_conditioned_floors_above_grade
    if args[:geometry_foundation_type] == HPXML::FoundationTypeBasementConditioned
      number_of_conditioned_floors += 1
    end

    if args[:geometry_unit_num_bathrooms].is_initialized
      number_of_bathrooms = args[:geometry_unit_num_bathrooms].get
    end

    conditioned_building_volume = args[:geometry_unit_cfa] * args[:geometry_average_ceiling_height]

    hpxml.building_construction.number_of_conditioned_floors = number_of_conditioned_floors
    hpxml.building_construction.number_of_conditioned_floors_above_grade = number_of_conditioned_floors_above_grade
    hpxml.building_construction.number_of_bedrooms = args[:geometry_unit_num_bedrooms]
    hpxml.building_construction.number_of_bathrooms = number_of_bathrooms
    hpxml.building_construction.conditioned_floor_area = args[:geometry_unit_cfa]
    hpxml.building_construction.conditioned_building_volume = conditioned_building_volume
    hpxml.building_construction.average_ceiling_height = args[:geometry_average_ceiling_height]
    hpxml.building_construction.residential_facility_type = args[:geometry_unit_type]

    if args[:year_built].is_initialized
      hpxml.building_construction.year_built = args[:year_built].get
    end
    if args[:geometry_has_flue_or_chimney].is_initialized
      hpxml.building_construction.has_flue_or_chimney = args[:geometry_has_flue_or_chimney].get
    end
  end

  def self.set_climate_and_risk_zones(hpxml, args)
    hpxml.climate_and_risk_zones.weather_station_id = 'WeatherStation'

    if args[:site_iecc_zone].is_initialized
      hpxml.climate_and_risk_zones.climate_zone_ieccs.add(zone: args[:site_iecc_zone].get,
                                                          year: 2006)
    end

    weather_station_name = File.basename(args[:weather_station_epw_filepath]).gsub('.epw', '')
    hpxml.climate_and_risk_zones.weather_station_name = weather_station_name
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = args[:weather_station_epw_filepath]
  end

  def self.set_air_infiltration_measurements(hpxml, args)
    if args[:air_leakage_units] == HPXML::UnitsACH
      house_pressure = args[:air_leakage_house_pressure]
      unit_of_measure = HPXML::UnitsACH
    elsif args[:air_leakage_units] == HPXML::UnitsCFM
      house_pressure = args[:air_leakage_house_pressure]
      unit_of_measure = HPXML::UnitsCFM
    elsif args[:air_leakage_units] == HPXML::UnitsACHNatural
      house_pressure = nil
      unit_of_measure = HPXML::UnitsACHNatural
    end
    infiltration_volume = hpxml.building_construction.conditioned_building_volume

    hpxml.air_infiltration_measurements.add(id: "AirInfiltrationMeasurement#{hpxml.air_infiltration_measurements.size + 1}",
                                            house_pressure: house_pressure,
                                            unit_of_measure: unit_of_measure,
                                            air_leakage: args[:air_leakage_value],
                                            infiltration_volume: infiltration_volume)
  end

  def self.set_roofs(hpxml, args, sorted_surfaces)
    args[:geometry_roof_pitch] *= 12.0
    if (args[:geometry_attic_type] == HPXML::AtticTypeFlatRoof) || (args[:geometry_attic_type] == HPXML::AtticTypeBelowApartment)
      args[:geometry_roof_pitch] = 0.0
    end

    sorted_surfaces.each do |surface|
      next unless ['Outdoors'].include? surface.outsideBoundaryCondition
      next if surface.surfaceType != 'RoofCeiling'

      interior_adjacent_to = Geometry.get_adjacent_to(surface: surface)
      next if [HPXML::LocationOtherHousingUnit].include? interior_adjacent_to

      if args[:roof_material_type].is_initialized
        roof_type = args[:roof_material_type].get
      end

      if args[:roof_color].is_initialized
        roof_color = args[:roof_color].get
      end

      radiant_barrier = args[:roof_radiant_barrier]
      if args[:roof_radiant_barrier]
        radiant_barrier_grade = args[:roof_radiant_barrier_grade]
      end

      if args[:geometry_attic_type] == HPXML::AtticTypeFlatRoof
        azimuth = nil
      else
        azimuth = Geometry.get_surface_azimuth(surface: surface, orientation: args[:geometry_unit_orientation])
      end

      hpxml.roofs.add(id: "Roof#{hpxml.roofs.size + 1}",
                      interior_adjacent_to: Geometry.get_adjacent_to(surface: surface),
                      azimuth: azimuth,
                      area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2'),
                      roof_type: roof_type,
                      roof_color: roof_color,
                      pitch: args[:geometry_roof_pitch],
                      radiant_barrier: radiant_barrier,
                      radiant_barrier_grade: radiant_barrier_grade,
                      insulation_assembly_r_value: args[:roof_assembly_r])
      @surface_ids[surface.name.to_s] = hpxml.roofs[-1].id
    end
  end

  def self.set_rim_joists(hpxml, model, args, sorted_surfaces)
    sorted_surfaces.each do |surface|
      next if surface.surfaceType != 'Wall'
      next unless ['Outdoors', 'Adiabatic'].include? surface.outsideBoundaryCondition
      next unless Geometry.surface_is_rim_joist(surface, args[:geometry_rim_joist_height])

      interior_adjacent_to = Geometry.get_adjacent_to(surface: surface)
      next unless [HPXML::LocationBasementConditioned,
                   HPXML::LocationBasementUnconditioned,
                   HPXML::LocationCrawlspaceUnvented,
                   HPXML::LocationCrawlspaceVented,
                   HPXML::LocationCrawlspaceConditioned].include? interior_adjacent_to

      exterior_adjacent_to = HPXML::LocationOutside
      if surface.outsideBoundaryCondition == 'Adiabatic' # can be adjacent to foundation space
        adjacent_surface = Geometry.get_adiabatic_adjacent_surface(model: model, surface: surface)
        if adjacent_surface.nil? # adjacent to a space that is not explicitly in the model
          unless [HPXML::ResidentialTypeSFD].include?(args[:geometry_unit_type])
            exterior_adjacent_to = interior_adjacent_to
            if exterior_adjacent_to == HPXML::LocationLivingSpace # living adjacent to living
              exterior_adjacent_to = HPXML::LocationOtherHousingUnit
            end
          end
        else # adjacent to a space that is explicitly in the model
          exterior_adjacent_to = Geometry.get_adjacent_to(surface: adjacent_surface)
        end
      end

      if exterior_adjacent_to == HPXML::LocationOutside && args[:wall_siding_type].is_initialized
        siding = args[:wall_siding_type].get
      end

      if args[:wall_color].is_initialized
        color = args[:wall_color].get
      end

      if interior_adjacent_to == exterior_adjacent_to
        insulation_assembly_r_value = 4.0 # Uninsulated
      else
        insulation_assembly_r_value = args[:rim_joist_assembly_r].get
      end

      azimuth = Geometry.get_surface_azimuth(surface: surface, orientation: args[:geometry_unit_orientation])

      hpxml.rim_joists.add(id: "RimJoist#{hpxml.rim_joists.size + 1}",
                           exterior_adjacent_to: exterior_adjacent_to,
                           interior_adjacent_to: interior_adjacent_to,
                           azimuth: azimuth,
                           area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2'),
                           siding: siding,
                           color: color,
                           insulation_assembly_r_value: insulation_assembly_r_value)
      @surface_ids[surface.name.to_s] = hpxml.rim_joists[-1].id
    end
  end

  def self.set_walls(hpxml, model, args, sorted_surfaces)
    sorted_surfaces.each do |surface|
      next if surface.surfaceType != 'Wall'
      next if Geometry.surface_is_rim_joist(surface, args[:geometry_rim_joist_height])

      interior_adjacent_to = Geometry.get_adjacent_to(surface: surface)
      next unless [HPXML::LocationLivingSpace, HPXML::LocationAtticUnvented, HPXML::LocationAtticVented, HPXML::LocationGarage].include? interior_adjacent_to

      exterior_adjacent_to = HPXML::LocationOutside
      if surface.adjacentSurface.is_initialized
        exterior_adjacent_to = Geometry.get_adjacent_to(surface: surface.adjacentSurface.get)
      elsif surface.outsideBoundaryCondition == 'Adiabatic' # can be adjacent to living space, attic
        adjacent_surface = Geometry.get_adiabatic_adjacent_surface(model: model, surface: surface)
        if adjacent_surface.nil? # adjacent to a space that is not explicitly in the model
          exterior_adjacent_to = interior_adjacent_to
          if exterior_adjacent_to == HPXML::LocationLivingSpace # living adjacent to living
            exterior_adjacent_to = HPXML::LocationOtherHousingUnit
          end
        else # adjacent to a space that is explicitly in the model
          exterior_adjacent_to = Geometry.get_adjacent_to(surface: adjacent_surface)
        end
      end

      next if exterior_adjacent_to == HPXML::LocationLivingSpace # already captured these surfaces

      attic_locations = [HPXML::LocationAtticUnconditioned, HPXML::LocationAtticUnvented, HPXML::LocationAtticVented]
      attic_wall_type = nil
      if (attic_locations.include? interior_adjacent_to) && (exterior_adjacent_to == HPXML::LocationOutside)
        attic_wall_type = HPXML::AtticWallTypeGable
      end

      wall_type = args[:wall_type]
      if attic_locations.include? interior_adjacent_to
        wall_type = HPXML::WallTypeWoodStud
      end

      if exterior_adjacent_to == HPXML::LocationOutside && args[:wall_siding_type].is_initialized
        if (attic_locations.include? interior_adjacent_to) && (args[:wall_siding_type].get == HPXML::SidingTypeNone)
          siding = nil
        else
          siding = args[:wall_siding_type].get
        end
      end

      if args[:wall_color].is_initialized
        color = args[:wall_color].get
      end

      azimuth = Geometry.get_surface_azimuth(surface: surface, orientation: args[:geometry_unit_orientation])

      hpxml.walls.add(id: "Wall#{hpxml.walls.size + 1}",
                      exterior_adjacent_to: exterior_adjacent_to,
                      interior_adjacent_to: interior_adjacent_to,
                      azimuth: azimuth,
                      wall_type: wall_type,
                      attic_wall_type: attic_wall_type,
                      siding: siding,
                      color: color,
                      area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2'))
      @surface_ids[surface.name.to_s] = hpxml.walls[-1].id

      is_uncond_attic_roof_insulated = false
      if attic_locations.include? interior_adjacent_to
        hpxml.roofs.each do |roof|
          next unless (roof.interior_adjacent_to == interior_adjacent_to) && (roof.insulation_assembly_r_value > 4.0)

          is_uncond_attic_roof_insulated = true
        end
      end

      if hpxml.walls[-1].is_thermal_boundary || is_uncond_attic_roof_insulated # Assume wall is insulated if roof is insulated
        hpxml.walls[-1].insulation_assembly_r_value = args[:wall_assembly_r]
      else
        hpxml.walls[-1].insulation_assembly_r_value = 4.0 # Uninsulated
      end
    end
  end

  def self.set_foundation_walls(hpxml, model, args, sorted_surfaces)
    sorted_surfaces.each do |surface|
      next if surface.surfaceType != 'Wall'
      next unless ['Foundation', 'Adiabatic'].include? surface.outsideBoundaryCondition
      next if Geometry.surface_is_rim_joist(surface, args[:geometry_rim_joist_height])

      interior_adjacent_to = Geometry.get_adjacent_to(surface: surface)
      next unless [HPXML::LocationBasementConditioned,
                   HPXML::LocationBasementUnconditioned,
                   HPXML::LocationCrawlspaceUnvented,
                   HPXML::LocationCrawlspaceVented,
                   HPXML::LocationCrawlspaceConditioned].include? interior_adjacent_to

      exterior_adjacent_to = HPXML::LocationGround
      if surface.outsideBoundaryCondition == 'Adiabatic' # can be adjacent to foundation space
        adjacent_surface = Geometry.get_adiabatic_adjacent_surface(model: model, surface: surface)
        if adjacent_surface.nil? # adjacent to a space that is not explicitly in the model
          unless [HPXML::ResidentialTypeSFD].include?(args[:geometry_unit_type])
            exterior_adjacent_to = interior_adjacent_to
            if exterior_adjacent_to == HPXML::LocationLivingSpace # living adjacent to living
              exterior_adjacent_to = HPXML::LocationOtherHousingUnit
            end
          end
        else # adjacent to a space that is explicitly in the model
          exterior_adjacent_to = Geometry.get_adjacent_to(surface: adjacent_surface)
        end
      end

      foundation_wall_insulation_location = 'exterior' # default
      if args[:foundation_wall_insulation_location].is_initialized
        foundation_wall_insulation_location = args[:foundation_wall_insulation_location].get
      end

      if args[:foundation_wall_assembly_r].is_initialized && (args[:foundation_wall_assembly_r].get > 0)
        insulation_assembly_r_value = args[:foundation_wall_assembly_r].get
      else
        insulation_interior_r_value = 0
        insulation_exterior_r_value = 0
        if interior_adjacent_to == exterior_adjacent_to # E.g., don't insulate wall between basement and neighbor basement
          # nop
        elsif foundation_wall_insulation_location == 'interior'
          insulation_interior_r_value = args[:foundation_wall_insulation_r]
          if insulation_interior_r_value > 0
            if args[:foundation_wall_insulation_distance_to_top].is_initialized
              insulation_interior_distance_to_top = args[:foundation_wall_insulation_distance_to_top].get
            end
            if args[:foundation_wall_insulation_distance_to_bottom].is_initialized
              insulation_interior_distance_to_bottom = args[:foundation_wall_insulation_distance_to_bottom].get
            end
          end
        elsif foundation_wall_insulation_location == 'exterior'
          insulation_exterior_r_value = args[:foundation_wall_insulation_r]
          if insulation_exterior_r_value > 0
            if args[:foundation_wall_insulation_distance_to_top].is_initialized
              insulation_exterior_distance_to_top = args[:foundation_wall_insulation_distance_to_top].get
            end
            if args[:foundation_wall_insulation_distance_to_bottom].is_initialized
              insulation_exterior_distance_to_bottom = args[:foundation_wall_insulation_distance_to_bottom].get
            end
          end
        end
      end

      if args[:foundation_wall_thickness].is_initialized
        thickness = args[:foundation_wall_thickness].get
      end

      if args[:foundation_wall_type].is_initialized
        type = args[:foundation_wall_type].get
      end

      azimuth = Geometry.get_surface_azimuth(surface: surface, orientation: args[:geometry_unit_orientation])

      hpxml.foundation_walls.add(id: "FoundationWall#{hpxml.foundation_walls.size + 1}",
                                 exterior_adjacent_to: exterior_adjacent_to,
                                 interior_adjacent_to: interior_adjacent_to,
                                 type: type,
                                 azimuth: azimuth,
                                 height: args[:geometry_foundation_height],
                                 area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2'),
                                 thickness: thickness,
                                 depth_below_grade: args[:geometry_foundation_height] - args[:geometry_foundation_height_above_grade],
                                 insulation_assembly_r_value: insulation_assembly_r_value,
                                 insulation_interior_r_value: insulation_interior_r_value,
                                 insulation_interior_distance_to_top: insulation_interior_distance_to_top,
                                 insulation_interior_distance_to_bottom: insulation_interior_distance_to_bottom,
                                 insulation_exterior_r_value: insulation_exterior_r_value,
                                 insulation_exterior_distance_to_top: insulation_exterior_distance_to_top,
                                 insulation_exterior_distance_to_bottom: insulation_exterior_distance_to_bottom)
      @surface_ids[surface.name.to_s] = hpxml.foundation_walls[-1].id
    end
  end

  def self.set_floors(hpxml, args, sorted_surfaces)
    if [HPXML::FoundationTypeBasementConditioned,
        HPXML::FoundationTypeCrawlspaceConditioned].include?(args[:geometry_foundation_type]) && (args[:floor_over_foundation_assembly_r] > 2.1)
      args[:floor_over_foundation_assembly_r] = 2.1 # Uninsulated
    end

    if [HPXML::AtticTypeConditioned].include?(args[:geometry_attic_type]) && (args[:ceiling_assembly_r] > 2.1)
      args[:ceiling_assembly_r] = 2.1 # Uninsulated
    end

    sorted_surfaces.each do |surface|
      next if surface.outsideBoundaryCondition == 'Foundation'
      next unless ['Floor', 'RoofCeiling'].include? surface.surfaceType

      interior_adjacent_to = Geometry.get_adjacent_to(surface: surface)
      next unless [HPXML::LocationLivingSpace, HPXML::LocationGarage].include? interior_adjacent_to

      exterior_adjacent_to = HPXML::LocationOutside
      if surface.adjacentSurface.is_initialized
        exterior_adjacent_to = Geometry.get_adjacent_to(surface: surface.adjacentSurface.get)
      elsif surface.outsideBoundaryCondition == 'Adiabatic'
        exterior_adjacent_to = HPXML::LocationOtherHousingUnit
        if surface.surfaceType == 'Floor'
          floor_or_ceiling = HPXML::FloorOrCeilingFloor
        elsif surface.surfaceType == 'RoofCeiling'
          floor_or_ceiling = HPXML::FloorOrCeilingCeiling
        end
      end

      next if interior_adjacent_to == exterior_adjacent_to
      next if (surface.surfaceType == 'RoofCeiling') && (exterior_adjacent_to == HPXML::LocationOutside)
      next if [HPXML::LocationLivingSpace,
               HPXML::LocationBasementConditioned,
               HPXML::LocationCrawlspaceConditioned].include? exterior_adjacent_to

      hpxml.floors.add(id: "Floor#{hpxml.floors.size + 1}",
                       exterior_adjacent_to: exterior_adjacent_to,
                       interior_adjacent_to: interior_adjacent_to,
                       floor_type: args[:floor_type],
                       area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2'),
                       floor_or_ceiling: floor_or_ceiling)
      if hpxml.floors[-1].floor_or_ceiling.nil?
        if hpxml.floors[-1].is_floor
          hpxml.floors[-1].floor_or_ceiling = HPXML::FloorOrCeilingFloor
        elsif hpxml.floors[-1].is_ceiling
          hpxml.floors[-1].floor_or_ceiling = HPXML::FloorOrCeilingCeiling
        end
      end
      @surface_ids[surface.name.to_s] = hpxml.floors[-1].id

      if hpxml.floors[-1].is_thermal_boundary
        if [HPXML::LocationAtticUnvented, HPXML::LocationAtticVented].include? exterior_adjacent_to
          hpxml.floors[-1].insulation_assembly_r_value = args[:ceiling_assembly_r]
        elsif [HPXML::LocationGarage].include? exterior_adjacent_to
          hpxml.floors[-1].insulation_assembly_r_value = args[:floor_over_garage_assembly_r]
        else
          hpxml.floors[-1].insulation_assembly_r_value = args[:floor_over_foundation_assembly_r]
        end
      else
        hpxml.floors[-1].insulation_assembly_r_value = 2.1 # Uninsulated
      end
    end
  end

  def self.set_slabs(hpxml, model, args, sorted_surfaces)
    sorted_surfaces.each do |surface|
      next unless ['Foundation'].include? surface.outsideBoundaryCondition
      next if surface.surfaceType != 'Floor'

      interior_adjacent_to = Geometry.get_adjacent_to(surface: surface)
      next if [HPXML::LocationOutside, HPXML::LocationOtherHousingUnit].include? interior_adjacent_to

      has_foundation_walls = false
      if [HPXML::LocationCrawlspaceVented,
          HPXML::LocationCrawlspaceUnvented,
          HPXML::LocationCrawlspaceConditioned,
          HPXML::LocationBasementUnconditioned,
          HPXML::LocationBasementConditioned].include? interior_adjacent_to
        has_foundation_walls = true
      end
      exposed_perimeter = Geometry.calculate_exposed_perimeter(model, [surface], has_foundation_walls).round(1)
      next if exposed_perimeter == 0

      if [HPXML::LocationCrawlspaceVented,
          HPXML::LocationCrawlspaceUnvented,
          HPXML::LocationCrawlspaceConditioned,
          HPXML::LocationBasementUnconditioned,
          HPXML::LocationBasementConditioned].include? interior_adjacent_to
        exposed_perimeter -= Geometry.get_unexposed_garage_perimeter(**args)
      end

      if [HPXML::LocationLivingSpace, HPXML::LocationGarage].include? interior_adjacent_to
        depth_below_grade = 0
      end

      if args[:slab_under_width] == 999
        under_slab_insulation_spans_entire_slab = true
      else
        under_slab_insulation_width = args[:slab_under_width]
      end

      if args[:slab_thickness].is_initialized
        thickness = args[:slab_thickness].get
      end

      if args[:slab_carpet_fraction].is_initialized
        carpet_fraction = args[:slab_carpet_fraction].get
      end

      if args[:slab_carpet_r].is_initialized
        carpet_r_value = args[:slab_carpet_r].get
      end

      hpxml.slabs.add(id: "Slab#{hpxml.slabs.size + 1}",
                      interior_adjacent_to: interior_adjacent_to,
                      area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2'),
                      thickness: thickness,
                      exposed_perimeter: exposed_perimeter,
                      perimeter_insulation_depth: args[:slab_perimeter_depth],
                      under_slab_insulation_width: under_slab_insulation_width,
                      perimeter_insulation_r_value: args[:slab_perimeter_insulation_r],
                      under_slab_insulation_r_value: args[:slab_under_insulation_r],
                      under_slab_insulation_spans_entire_slab: under_slab_insulation_spans_entire_slab,
                      depth_below_grade: depth_below_grade,
                      carpet_fraction: carpet_fraction,
                      carpet_r_value: carpet_r_value)
      @surface_ids[surface.name.to_s] = hpxml.slabs[-1].id

      next unless interior_adjacent_to == HPXML::LocationCrawlspaceConditioned

      # Increase Conditioned Building Volume & Infiltration Volume
      conditioned_crawlspace_volume = hpxml.slabs[-1].area * args[:geometry_foundation_height]
      hpxml.building_construction.conditioned_building_volume += conditioned_crawlspace_volume
      hpxml.air_infiltration_measurements[0].infiltration_volume += conditioned_crawlspace_volume
    end
  end

  def self.set_windows(hpxml, model, args, sorted_subsurfaces)
    sorted_subsurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType != 'FixedWindow'

      surface = sub_surface.surface.get

      sub_surface_height = Geometry.get_surface_height(sub_surface)
      sub_surface_facade = Geometry.get_facade_for_surface(sub_surface)

      if (sub_surface_facade == Constants.FacadeFront) && ((args[:overhangs_front_depth] > 0) || args[:overhangs_front_distance_to_top_of_window] > 0)
        overhangs_depth = args[:overhangs_front_depth]
        overhangs_distance_to_top_of_window = args[:overhangs_front_distance_to_top_of_window]
        overhangs_distance_to_bottom_of_window = args[:overhangs_front_distance_to_bottom_of_window]
      elsif (sub_surface_facade == Constants.FacadeBack) && ((args[:overhangs_back_depth] > 0) || args[:overhangs_back_distance_to_top_of_window] > 0)
        overhangs_depth = args[:overhangs_back_depth]
        overhangs_distance_to_top_of_window = args[:overhangs_back_distance_to_top_of_window]
        overhangs_distance_to_bottom_of_window = args[:overhangs_back_distance_to_bottom_of_window]
      elsif (sub_surface_facade == Constants.FacadeLeft) && ((args[:overhangs_left_depth] > 0) || args[:overhangs_left_distance_to_top_of_window] > 0)
        overhangs_depth = args[:overhangs_left_depth]
        overhangs_distance_to_top_of_window = args[:overhangs_left_distance_to_top_of_window]
        overhangs_distance_to_bottom_of_window = args[:overhangs_left_distance_to_bottom_of_window]
      elsif (sub_surface_facade == Constants.FacadeRight) && ((args[:overhangs_right_depth] > 0) || args[:overhangs_right_distance_to_top_of_window] > 0)
        overhangs_depth = args[:overhangs_right_depth]
        overhangs_distance_to_top_of_window = args[:overhangs_right_distance_to_top_of_window]
        overhangs_distance_to_bottom_of_window = args[:overhangs_right_distance_to_bottom_of_window]
      elsif args[:geometry_eaves_depth] > 0
        # Get max z coordinate of eaves
        eaves_z = args[:geometry_average_ceiling_height] * args[:geometry_unit_num_floors_above_grade] + args[:geometry_rim_joist_height]
        if args[:geometry_attic_type] == HPXML::AtticTypeConditioned
          eaves_z += Geometry.get_conditioned_attic_height(model.getSpaces)
        end
        if args[:geometry_foundation_type] == HPXML::FoundationTypeAmbient
          eaves_z += args[:geometry_foundation_height]
        end

        # Get max z coordinate of this window
        sub_surface_z = Geometry.getSurfaceZValues([sub_surface]).max + UnitConversions.convert(sub_surface.space.get.zOrigin, 'm', 'ft')

        overhangs_depth = args[:geometry_eaves_depth]
        overhangs_distance_to_top_of_window = eaves_z - sub_surface_z # difference between max z coordinates of eaves and this window
        overhangs_distance_to_bottom_of_window = (overhangs_distance_to_top_of_window + sub_surface_height).round(1)
      end

      azimuth = Geometry.get_azimuth_from_facade(facade: sub_surface_facade, orientation: args[:geometry_unit_orientation])

      if args[:window_interior_shading_winter].is_initialized
        interior_shading_factor_winter = args[:window_interior_shading_winter].get
      end

      if args[:window_interior_shading_summer].is_initialized
        interior_shading_factor_summer = args[:window_interior_shading_summer].get
      end

      if args[:window_exterior_shading_winter].is_initialized
        exterior_shading_factor_winter = args[:window_exterior_shading_winter].get
      end

      if args[:window_exterior_shading_summer].is_initialized
        exterior_shading_factor_summer = args[:window_exterior_shading_summer].get
      end

      if args[:window_fraction_operable].is_initialized
        fraction_operable = args[:window_fraction_operable].get
      end

      if args[:window_storm_type].is_initialized
        window_storm_type = args[:window_storm_type].get
      end

      wall_idref = @surface_ids[surface.name.to_s]
      next if wall_idref.nil?

      hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                        area: UnitConversions.convert(sub_surface.grossArea, 'm^2', 'ft^2'),
                        azimuth: azimuth,
                        ufactor: args[:window_ufactor],
                        shgc: args[:window_shgc],
                        storm_type: window_storm_type,
                        overhangs_depth: overhangs_depth,
                        overhangs_distance_to_top_of_window: overhangs_distance_to_top_of_window,
                        overhangs_distance_to_bottom_of_window: overhangs_distance_to_bottom_of_window,
                        interior_shading_factor_winter: interior_shading_factor_winter,
                        interior_shading_factor_summer: interior_shading_factor_summer,
                        exterior_shading_factor_winter: exterior_shading_factor_winter,
                        exterior_shading_factor_summer: exterior_shading_factor_summer,
                        fraction_operable: fraction_operable,
                        wall_idref: wall_idref)
    end
  end

  def self.set_skylights(hpxml, args, sorted_subsurfaces)
    sorted_subsurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType != 'Skylight'

      surface = sub_surface.surface.get

      sub_surface_facade = Geometry.get_facade_for_surface(sub_surface)
      azimuth = Geometry.get_azimuth_from_facade(facade: sub_surface_facade, orientation: args[:geometry_unit_orientation])

      if args[:skylight_storm_type].is_initialized
        skylight_storm_type = args[:skylight_storm_type].get
      end

      roof_idref = @surface_ids[surface.name.to_s]
      next if roof_idref.nil?

      hpxml.skylights.add(id: "Skylight#{hpxml.skylights.size + 1}",
                          area: UnitConversions.convert(sub_surface.grossArea, 'm^2', 'ft^2'),
                          azimuth: azimuth,
                          ufactor: args[:skylight_ufactor],
                          shgc: args[:skylight_shgc],
                          storm_type: skylight_storm_type,
                          roof_idref: roof_idref)
    end
  end

  def self.set_doors(hpxml, model, args, sorted_subsurfaces)
    sorted_subsurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType != 'Door'

      surface = sub_surface.surface.get

      interior_adjacent_to = Geometry.get_adjacent_to(surface: surface)

      if [HPXML::LocationOtherHousingUnit].include?(interior_adjacent_to)
        adjacent_surface = Geometry.get_adiabatic_adjacent_surface(model: model, surface: surface)
        next if adjacent_surface.nil?
      end

      wall_idref = @surface_ids[surface.name.to_s]
      next if wall_idref.nil?

      hpxml.doors.add(id: "Door#{hpxml.doors.size + 1}",
                      wall_idref: wall_idref,
                      area: UnitConversions.convert(sub_surface.grossArea, 'm^2', 'ft^2'),
                      azimuth: args[:geometry_unit_orientation],
                      r_value: args[:door_rvalue])
    end
  end

  def self.set_attics(hpxml, args)
    surf_ids = { 'roofs' => { 'surfaces' => hpxml.roofs, 'ids' => [] },
                 'walls' => { 'surfaces' => hpxml.walls, 'ids' => [] },
                 'floors' => { 'surfaces' => hpxml.floors, 'ids' => [] } }

    attic_locations = [HPXML::LocationAtticUnconditioned, HPXML::LocationAtticUnvented, HPXML::LocationAtticVented]
    surf_ids.values.each do |surf_hash|
      surf_hash['surfaces'].each do |surface|
        next if (not attic_locations.include? surface.interior_adjacent_to) &&
                (not attic_locations.include? surface.exterior_adjacent_to)

        surf_hash['ids'] << surface.id
      end
    end

    # Add attached roofs for cathedral ceiling
    living_space = HPXML::LocationLivingSpace
    surf_ids['roofs']['surfaces'].each do |surface|
      next if (living_space != surface.interior_adjacent_to) &&
              (living_space != surface.exterior_adjacent_to)

      surf_ids['roofs']['ids'] << surface.id
    end

    hpxml.attics.add(id: "Attic#{hpxml.attics.size + 1}",
                     attic_type: args[:geometry_attic_type],
                     attached_to_roof_idrefs: surf_ids['roofs']['ids'],
                     attached_to_wall_idrefs: surf_ids['walls']['ids'],
                     attached_to_floor_idrefs: surf_ids['floors']['ids'])
  end

  def self.set_foundations(hpxml, args)
    surf_ids = { 'slabs' => { 'surfaces' => hpxml.slabs, 'ids' => [] },
                 'floors' => { 'surfaces' => hpxml.floors, 'ids' => [] },
                 'foundation_walls' => { 'surfaces' => hpxml.foundation_walls, 'ids' => [] },
                 'walls' => { 'surfaces' => hpxml.walls, 'ids' => [] },
                 'rim_joists' => { 'surfaces' => hpxml.rim_joists, 'ids' => [] }, }

    foundation_locations = [HPXML::LocationBasementConditioned,
                            HPXML::LocationBasementUnconditioned,
                            HPXML::LocationCrawlspaceUnvented,
                            HPXML::LocationCrawlspaceVented,
                            HPXML::LocationCrawlspaceConditioned]

    surf_ids.each do |surf_type, surf_hash|
      surf_hash['surfaces'].each do |surface|
        next unless (foundation_locations.include? surface.interior_adjacent_to) ||
                    (foundation_locations.include? surface.exterior_adjacent_to) ||
                    (surf_type == 'slabs' && surface.interior_adjacent_to == HPXML::LocationLivingSpace) ||
                    (surf_type == 'floors' && surface.exterior_adjacent_to == HPXML::LocationOutside)

        surf_hash['ids'] << surface.id
      end
    end

    hpxml.foundations.add(id: "Foundation#{hpxml.foundations.size + 1}",
                          foundation_type: args[:geometry_foundation_type],
                          attached_to_slab_idrefs: surf_ids['slabs']['ids'],
                          attached_to_floor_idrefs: surf_ids['floors']['ids'],
                          attached_to_foundation_wall_idrefs: surf_ids['foundation_walls']['ids'],
                          attached_to_wall_idrefs: surf_ids['walls']['ids'],
                          attached_to_rim_joist_idrefs: surf_ids['rim_joists']['ids'])
  end

  def self.set_heating_systems(hpxml, args)
    heating_system_type = args[:heating_system_type]

    return if heating_system_type == 'none'

    if args[:heating_system_heating_capacity].is_initialized
      heating_capacity = args[:heating_system_heating_capacity].get
    end

    if [HPXML::HVACTypeElectricResistance].include? heating_system_type
      heating_system_fuel = HPXML::FuelTypeElectricity
    else
      heating_system_fuel = args[:heating_system_fuel]
    end

    if [HPXML::HVACTypeFurnace,
        HPXML::HVACTypeWallFurnace,
        HPXML::HVACTypeFloorFurnace].include?(heating_system_type) || heating_system_type.include?(HPXML::HVACTypeBoiler)
      heating_efficiency_afue = args[:heating_system_heating_efficiency]
    elsif [HPXML::HVACTypeElectricResistance,
           HPXML::HVACTypeStove,
           HPXML::HVACTypePortableHeater,
           HPXML::HVACTypeFireplace,
           HPXML::HVACTypeFixedHeater].include?(heating_system_type)
      heating_efficiency_percent = args[:heating_system_heating_efficiency]
    end

    if args[:heating_system_airflow_defect_ratio].is_initialized
      if [HPXML::HVACTypeFurnace].include? heating_system_type
        airflow_defect_ratio = args[:heating_system_airflow_defect_ratio].get
      end
    end

    fraction_heat_load_served = args[:heating_system_fraction_heat_load_served]

    if heating_system_type.include?('Shared')
      is_shared_system = true
      number_of_units_served = args[:geometry_building_num_units].get
      heating_capacity = nil
    end

    if heating_system_type.include?(HPXML::HVACTypeBoiler)
      heating_system_type = HPXML::HVACTypeBoiler
    end

    hpxml.heating_systems.add(id: "HeatingSystem#{hpxml.heating_systems.size + 1}",
                              heating_system_type: heating_system_type,
                              heating_system_fuel: heating_system_fuel,
                              heating_capacity: heating_capacity,
                              fraction_heat_load_served: fraction_heat_load_served,
                              heating_efficiency_afue: heating_efficiency_afue,
                              heating_efficiency_percent: heating_efficiency_percent,
                              airflow_defect_ratio: airflow_defect_ratio,
                              is_shared_system: is_shared_system,
                              number_of_units_served: number_of_units_served,
                              primary_system: true)
  end

  def self.set_cooling_systems(hpxml, args)
    cooling_system_type = args[:cooling_system_type]

    return if cooling_system_type == 'none'

    if args[:cooling_system_cooling_capacity].is_initialized
      cooling_capacity = args[:cooling_system_cooling_capacity].get
    end

    if args[:cooling_system_cooling_compressor_type].is_initialized
      if cooling_system_type == HPXML::HVACTypeCentralAirConditioner
        compressor_type = args[:cooling_system_cooling_compressor_type].get
      end
    end

    if args[:cooling_system_cooling_sensible_heat_fraction].is_initialized
      if cooling_system_type != HPXML::HVACTypeEvaporativeCooler
        cooling_shr = args[:cooling_system_cooling_sensible_heat_fraction].get
      end
    end

    if cooling_system_type != HPXML::HVACTypeEvaporativeCooler
      if args[:cooling_system_cooling_efficiency_type] == HPXML::UnitsSEER
        cooling_efficiency_seer = args[:cooling_system_cooling_efficiency]
      elsif args[:cooling_system_cooling_efficiency_type] == HPXML::UnitsSEER2
        cooling_efficiency_seer2 = args[:cooling_system_cooling_efficiency]
      elsif args[:cooling_system_cooling_efficiency_type] == HPXML::UnitsEER
        cooling_efficiency_eer = args[:cooling_system_cooling_efficiency]
      elsif args[:cooling_system_cooling_efficiency_type] == HPXML::UnitsCEER
        cooling_efficiency_ceer = args[:cooling_system_cooling_efficiency]
      end
    end

    if args[:cooling_system_airflow_defect_ratio].is_initialized
      if [HPXML::HVACTypeCentralAirConditioner].include?(cooling_system_type) || ([HPXML::HVACTypeMiniSplitAirConditioner].include?(cooling_system_type) && (args[:cooling_system_is_ducted]))
        airflow_defect_ratio = args[:cooling_system_airflow_defect_ratio].get
      end
    end

    if args[:cooling_system_charge_defect_ratio].is_initialized
      if [HPXML::HVACTypeCentralAirConditioner, HPXML::HVACTypeMiniSplitAirConditioner].include?(cooling_system_type)
        charge_defect_ratio = args[:cooling_system_charge_defect_ratio].get
      end
    end

    if [HPXML::HVACTypePTAC, HPXML::HVACTypeRoomAirConditioner].include?(cooling_system_type)
      if args[:cooling_system_integrated_heating_system_fuel].is_initialized
        integrated_heating_system_fuel = args[:cooling_system_integrated_heating_system_fuel].get
      end

      if args[:cooling_system_integrated_heating_system_fraction_heat_load_served].is_initialized
        integrated_heating_system_fraction_heat_load_served = args[:cooling_system_integrated_heating_system_fraction_heat_load_served].get
      end

      if args[:cooling_system_integrated_heating_system_capacity].is_initialized
        integrated_heating_system_capacity = args[:cooling_system_integrated_heating_system_capacity].get
      end

      if args[:cooling_system_integrated_heating_system_efficiency_percent].is_initialized
        integrated_heating_system_efficiency_percent = args[:cooling_system_integrated_heating_system_efficiency_percent].get
      end
    end

    hpxml.cooling_systems.add(id: "CoolingSystem#{hpxml.cooling_systems.size + 1}",
                              cooling_system_type: cooling_system_type,
                              cooling_system_fuel: HPXML::FuelTypeElectricity,
                              cooling_capacity: cooling_capacity,
                              fraction_cool_load_served: args[:cooling_system_fraction_cool_load_served],
                              compressor_type: compressor_type,
                              cooling_shr: cooling_shr,
                              cooling_efficiency_seer: cooling_efficiency_seer,
                              cooling_efficiency_seer2: cooling_efficiency_seer2,
                              cooling_efficiency_eer: cooling_efficiency_eer,
                              cooling_efficiency_ceer: cooling_efficiency_ceer,
                              airflow_defect_ratio: airflow_defect_ratio,
                              charge_defect_ratio: charge_defect_ratio,
                              primary_system: true,
                              integrated_heating_system_fuel: integrated_heating_system_fuel,
                              integrated_heating_system_capacity: integrated_heating_system_capacity,
                              integrated_heating_system_efficiency_percent: integrated_heating_system_efficiency_percent,
                              integrated_heating_system_fraction_heat_load_served: integrated_heating_system_fraction_heat_load_served)
  end

  def self.set_heat_pumps(hpxml, args)
    heat_pump_type = args[:heat_pump_type]

    return if heat_pump_type == 'none'

    if args[:heat_pump_heating_capacity].is_initialized
      heating_capacity = args[:heat_pump_heating_capacity].get
    end

    if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpMiniSplit].include? heat_pump_type
      if args[:heat_pump_heating_capacity_17_f].is_initialized
        heating_capacity_17F = args[:heat_pump_heating_capacity_17_f].get
      end
    end

    if args[:heat_pump_backup_type] == HPXML::HeatPumpBackupTypeIntegrated
      backup_type = args[:heat_pump_backup_type]
      backup_heating_fuel = args[:heat_pump_backup_fuel]

      if args[:heat_pump_backup_heating_capacity].is_initialized
        backup_heating_capacity = args[:heat_pump_backup_heating_capacity].get
      end

      if backup_heating_fuel == HPXML::FuelTypeElectricity
        backup_heating_efficiency_percent = args[:heat_pump_backup_heating_efficiency]
      else
        backup_heating_efficiency_afue = args[:heat_pump_backup_heating_efficiency]
      end
    elsif args[:heat_pump_backup_type] == HPXML::HeatPumpBackupTypeSeparate
      if args[:heating_system_2_type] == 'none'
        fail "Heat pump backup type specified as '#{args[:heat_pump_backup_type]}' but no heating system provided."
      end

      backup_type = args[:heat_pump_backup_type]
      backup_system_idref = "HeatingSystem#{hpxml.heating_systems.size + 1}"
    end

    if args[:heat_pump_backup_type] != 'none'
      if args[:heat_pump_backup_heating_switchover_temp].is_initialized
        if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpMiniSplit].include? heat_pump_type
          backup_heating_switchover_temp = args[:heat_pump_backup_heating_switchover_temp].get
        end
      end
    end

    if args[:heat_pump_backup_type] == HPXML::HeatPumpBackupTypeIntegrated
      if args[:heat_pump_backup_heating_lockout_temp].is_initialized
        backup_heating_lockout_temp = args[:heat_pump_backup_heating_lockout_temp].get
      end
    end

    if args[:heat_pump_cooling_capacity].is_initialized
      cooling_capacity = args[:heat_pump_cooling_capacity].get
    end

    if args[:heat_pump_cooling_compressor_type].is_initialized
      if [HPXML::HVACTypeHeatPumpAirToAir].include? heat_pump_type
        compressor_type = args[:heat_pump_cooling_compressor_type].get
      end
    end

    if args[:heat_pump_cooling_sensible_heat_fraction].is_initialized
      cooling_shr = args[:heat_pump_cooling_sensible_heat_fraction].get
    end

    if args[:heat_pump_heating_efficiency_type] == HPXML::UnitsHSPF
      heating_efficiency_hspf = args[:heat_pump_heating_efficiency]
    elsif args[:heat_pump_heating_efficiency_type] == HPXML::UnitsHSPF2
      heating_efficiency_hspf2 = args[:heat_pump_heating_efficiency]
    elsif args[:heat_pump_heating_efficiency_type] == HPXML::UnitsCOP
      heating_efficiency_cop = args[:heat_pump_heating_efficiency]
    end

    if args[:heat_pump_cooling_efficiency_type] == HPXML::UnitsSEER
      cooling_efficiency_seer = args[:heat_pump_cooling_efficiency]
    elsif args[:heat_pump_cooling_efficiency_type] == HPXML::UnitsSEER2
      cooling_efficiency_seer2 = args[:heat_pump_cooling_efficiency]
    elsif args[:heat_pump_cooling_efficiency_type] == HPXML::UnitsEER
      cooling_efficiency_eer = args[:heat_pump_cooling_efficiency]
    end

    if args[:heat_pump_airflow_defect_ratio].is_initialized
      if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpGroundToAir].include?(heat_pump_type) || ([HPXML::HVACTypeHeatPumpMiniSplit].include?(heat_pump_type) && (args[:heat_pump_is_ducted]))
        airflow_defect_ratio = args[:heat_pump_airflow_defect_ratio].get
      end
    end

    if args[:heat_pump_charge_defect_ratio].is_initialized
      charge_defect_ratio = args[:heat_pump_charge_defect_ratio].get
    end

    fraction_heat_load_served = args[:heat_pump_fraction_heat_load_served]
    fraction_cool_load_served = args[:heat_pump_fraction_cool_load_served]

    if fraction_heat_load_served > 0
      primary_heating_system = true
    end

    if fraction_cool_load_served > 0
      primary_cooling_system = true
    end

    if args[:heat_pump_sizing_methodology].is_initialized
      hpxml.header.heat_pump_sizing_methodology = args[:heat_pump_sizing_methodology].get
    end

    hpxml.heat_pumps.add(id: "HeatPump#{hpxml.heat_pumps.size + 1}",
                         heat_pump_type: heat_pump_type,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         heating_capacity: heating_capacity,
                         heating_capacity_17F: heating_capacity_17F,
                         compressor_type: compressor_type,
                         cooling_shr: cooling_shr,
                         cooling_capacity: cooling_capacity,
                         fraction_heat_load_served: fraction_heat_load_served,
                         fraction_cool_load_served: fraction_cool_load_served,
                         backup_type: backup_type,
                         backup_system_idref: backup_system_idref,
                         backup_heating_fuel: backup_heating_fuel,
                         backup_heating_capacity: backup_heating_capacity,
                         backup_heating_efficiency_afue: backup_heating_efficiency_afue,
                         backup_heating_efficiency_percent: backup_heating_efficiency_percent,
                         backup_heating_switchover_temp: backup_heating_switchover_temp,
                         backup_heating_lockout_temp: backup_heating_lockout_temp,
                         heating_efficiency_hspf: heating_efficiency_hspf,
                         heating_efficiency_hspf2: heating_efficiency_hspf2,
                         cooling_efficiency_seer: cooling_efficiency_seer,
                         cooling_efficiency_seer2: cooling_efficiency_seer2,
                         heating_efficiency_cop: heating_efficiency_cop,
                         cooling_efficiency_eer: cooling_efficiency_eer,
                         airflow_defect_ratio: airflow_defect_ratio,
                         charge_defect_ratio: charge_defect_ratio,
                         primary_heating_system: primary_heating_system,
                         primary_cooling_system: primary_cooling_system)
  end

  def self.set_secondary_heating_systems(hpxml, args)
    heating_system_type = args[:heating_system_2_type]
    heating_system_is_heatpump_backup = (args[:heat_pump_type] != 'none' && args[:heat_pump_backup_type] == HPXML::HeatPumpBackupTypeSeparate)

    return if heating_system_type == 'none' && (not heating_system_is_heatpump_backup)

    if args[:heating_system_2_heating_capacity].is_initialized
      heating_capacity = args[:heating_system_2_heating_capacity].get
    end

    if args[:heating_system_2_fuel] == HPXML::HVACTypeElectricResistance
      heating_system_fuel = HPXML::FuelTypeElectricity
    else
      heating_system_fuel = args[:heating_system_2_fuel]
    end

    if [HPXML::HVACTypeFurnace, HPXML::HVACTypeWallFurnace, HPXML::HVACTypeFloorFurnace].include?(heating_system_type) || heating_system_type.include?(HPXML::HVACTypeBoiler)
      heating_efficiency_afue = args[:heating_system_2_heating_efficiency]
    elsif [HPXML::HVACTypeElectricResistance, HPXML::HVACTypeStove, HPXML::HVACTypePortableHeater, HPXML::HVACTypeFireplace].include?(heating_system_type)
      heating_efficiency_percent = args[:heating_system_2_heating_efficiency]
    end

    if heating_system_type.include?(HPXML::HVACTypeBoiler)
      heating_system_type = HPXML::HVACTypeBoiler
    end

    if not heating_system_is_heatpump_backup
      fraction_heat_load_served = args[:heating_system_2_fraction_heat_load_served]
    end

    hpxml.heating_systems.add(id: "HeatingSystem#{hpxml.heating_systems.size + 1}",
                              heating_system_type: heating_system_type,
                              heating_system_fuel: heating_system_fuel,
                              heating_capacity: heating_capacity,
                              fraction_heat_load_served: fraction_heat_load_served,
                              heating_efficiency_afue: heating_efficiency_afue,
                              heating_efficiency_percent: heating_efficiency_percent)
  end

  def self.set_hvac_distribution(hpxml, args)
    # HydronicDistribution?
    hpxml.heating_systems.each do |heating_system|
      next unless [heating_system.heating_system_type].include?(HPXML::HVACTypeBoiler)
      next if args[:heating_system_type].include?('Fan Coil')

      hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                   distribution_system_type: HPXML::HVACDistributionTypeHydronic,
                                   hydronic_type: HPXML::HydronicTypeBaseboard)
      heating_system.distribution_system_idref = hpxml.hvac_distributions[-1].id
    end

    # AirDistribution?
    air_distribution_systems = []
    hpxml.heating_systems.each do |heating_system|
      if [HPXML::HVACTypeFurnace].include?(heating_system.heating_system_type)
        air_distribution_systems << heating_system
      end
    end
    hpxml.cooling_systems.each do |cooling_system|
      if [HPXML::HVACTypeCentralAirConditioner].include?(cooling_system.cooling_system_type)
        air_distribution_systems << cooling_system
      elsif [HPXML::HVACTypeEvaporativeCooler, HPXML::HVACTypeMiniSplitAirConditioner].include?(cooling_system.cooling_system_type) && args[:cooling_system_is_ducted]
        air_distribution_systems << cooling_system
      end
    end
    hpxml.heat_pumps.each do |heat_pump|
      if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpGroundToAir].include? heat_pump.heat_pump_type
        air_distribution_systems << heat_pump
      elsif [HPXML::HVACTypeHeatPumpMiniSplit].include?(heat_pump.heat_pump_type)
        if args[:heat_pump_is_ducted].is_initialized
          air_distribution_systems << heat_pump if args[:heat_pump_is_ducted].get
        end
      end
    end

    # FanCoil?
    fan_coil_distribution_systems = []
    hpxml.heating_systems.each do |heating_system|
      if args[:heating_system_type].include?('Fan Coil')
        fan_coil_distribution_systems << heating_system
      end
    end

    return if air_distribution_systems.size == 0 && fan_coil_distribution_systems.size == 0

    if args[:ducts_number_of_return_registers].is_initialized
      number_of_return_registers = args[:ducts_number_of_return_registers].get
    end

    if [HPXML::HVACTypeEvaporativeCooler].include?(args[:cooling_system_type]) && hpxml.heating_systems.size == 0 && hpxml.heat_pumps.size == 0
      number_of_return_registers = nil
      if args[:cooling_system_is_ducted]
        number_of_return_registers = 0
      end
    end

    if air_distribution_systems.size > 0
      hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                   distribution_system_type: HPXML::HVACDistributionTypeAir,
                                   air_type: HPXML::AirTypeRegularVelocity,
                                   number_of_return_registers: number_of_return_registers)
      air_distribution_systems.each do |hvac_system|
        hvac_system.distribution_system_idref = hpxml.hvac_distributions[-1].id
      end
      set_duct_leakages(args, hpxml.hvac_distributions[-1])
      set_ducts(args, hpxml.hvac_distributions[-1])
    end

    if fan_coil_distribution_systems.size > 0
      hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                   distribution_system_type: HPXML::HVACDistributionTypeAir,
                                   air_type: HPXML::AirTypeFanCoil)
      fan_coil_distribution_systems.each do |hvac_system|
        hvac_system.distribution_system_idref = hpxml.hvac_distributions[-1].id
      end
    end
  end

  def self.set_duct_leakages(args, hvac_distribution)
    hvac_distribution.duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                    duct_leakage_units: args[:ducts_leakage_units],
                                                    duct_leakage_value: args[:ducts_supply_leakage_to_outside_value],
                                                    duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)

    hvac_distribution.duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                    duct_leakage_units: args[:ducts_leakage_units],
                                                    duct_leakage_value: args[:ducts_return_leakage_to_outside_value],
                                                    duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
  end

  def self.set_ducts(args, hvac_distribution)
    if args[:ducts_supply_location].is_initialized
      ducts_supply_location = args[:ducts_supply_location].get
    end

    if args[:ducts_return_location].is_initialized
      ducts_return_location = args[:ducts_return_location].get
    end

    if args[:ducts_supply_surface_area].is_initialized
      ducts_supply_surface_area = args[:ducts_supply_surface_area].get
    end

    if args[:ducts_return_surface_area].is_initialized
      ducts_return_surface_area = args[:ducts_return_surface_area].get
    end

    hvac_distribution.ducts.add(id: "Ducts#{hvac_distribution.ducts.size + 1}",
                                duct_type: HPXML::DuctTypeSupply,
                                duct_insulation_r_value: args[:ducts_supply_insulation_r],
                                duct_location: ducts_supply_location,
                                duct_surface_area: ducts_supply_surface_area)

    if not ([HPXML::HVACTypeEvaporativeCooler].include?(args[:cooling_system_type]) && args[:cooling_system_is_ducted])
      hvac_distribution.ducts.add(id: "Ducts#{hvac_distribution.ducts.size + 1}",
                                  duct_type: HPXML::DuctTypeReturn,
                                  duct_insulation_r_value: args[:ducts_return_insulation_r],
                                  duct_location: ducts_return_location,
                                  duct_surface_area: ducts_return_surface_area)
    end

    # If duct surface areas are defaulted, set CFA served
    if hvac_distribution.ducts.select { |d| d.duct_surface_area.nil? }.size > 0
      hvac_distribution.conditioned_floor_area_served = args[:geometry_unit_cfa]
    end
  end

  def self.set_hvac_control(hpxml, args, epw_file, weather)
    return if (args[:heating_system_type] == 'none') && (args[:cooling_system_type] == 'none') && (args[:heat_pump_type] == 'none')

    # Heating
    if hpxml.total_fraction_heat_load_served > 0

      if args[:hvac_control_heating_weekday_setpoint].is_initialized && args[:hvac_control_heating_weekend_setpoint].is_initialized
        if args[:hvac_control_heating_weekday_setpoint].get == args[:hvac_control_heating_weekend_setpoint].get && !args[:hvac_control_heating_weekday_setpoint].get.include?(',')
          heating_setpoint_temp = Float(args[:hvac_control_heating_weekday_setpoint].get)
        else
          weekday_heating_setpoints = args[:hvac_control_heating_weekday_setpoint].get
          weekend_heating_setpoints = args[:hvac_control_heating_weekend_setpoint].get
        end
      end

      if args[:hvac_control_heating_season_period].is_initialized
        hvac_control_heating_season_period = args[:hvac_control_heating_season_period].get
        if hvac_control_heating_season_period == HPXML::BuildingAmerica
          heating_months, _cooling_months = HVAC.get_default_heating_and_cooling_seasons(weather)
          sim_calendar_year = Location.get_sim_calendar_year(hpxml.header.sim_calendar_year, epw_file)
          begin_month, begin_day, end_month, end_day = Schedule.get_begin_and_end_dates_from_monthly_array(heating_months, sim_calendar_year)
        else
          begin_month, begin_day, end_month, end_day = Schedule.parse_date_range(hvac_control_heating_season_period)
        end
        seasons_heating_begin_month = begin_month
        seasons_heating_begin_day = begin_day
        seasons_heating_end_month = end_month
        seasons_heating_end_day = end_day
      end

    end

    # Cooling
    if hpxml.total_fraction_cool_load_served > 0

      if args[:hvac_control_cooling_weekday_setpoint].is_initialized && args[:hvac_control_cooling_weekend_setpoint].is_initialized
        if args[:hvac_control_cooling_weekday_setpoint].get == args[:hvac_control_cooling_weekend_setpoint].get && !args[:hvac_control_cooling_weekday_setpoint].get.include?(',')
          cooling_setpoint_temp = Float(args[:hvac_control_cooling_weekday_setpoint].get)
        else
          weekday_cooling_setpoints = args[:hvac_control_cooling_weekday_setpoint].get
          weekend_cooling_setpoints = args[:hvac_control_cooling_weekend_setpoint].get
        end
      end

      if args[:ceiling_fan_cooling_setpoint_temp_offset].is_initialized
        ceiling_fan_cooling_setpoint_temp_offset = args[:ceiling_fan_cooling_setpoint_temp_offset].get
      end

      if args[:hvac_control_cooling_season_period].is_initialized
        hvac_control_cooling_season_period = args[:hvac_control_cooling_season_period].get
        if hvac_control_cooling_season_period == HPXML::BuildingAmerica
          _heating_months, cooling_months = HVAC.get_default_heating_and_cooling_seasons(weather)
          sim_calendar_year = Location.get_sim_calendar_year(hpxml.header.sim_calendar_year, epw_file)
          begin_month, begin_day, end_month, end_day = Schedule.get_begin_and_end_dates_from_monthly_array(cooling_months, sim_calendar_year)
        else
          begin_month, begin_day, end_month, end_day = Schedule.parse_date_range(args[:hvac_control_cooling_season_period].get)
        end
        seasons_cooling_begin_month = begin_month
        seasons_cooling_begin_day = begin_day
        seasons_cooling_end_month = end_month
        seasons_cooling_end_day = end_day
      end

    end

    hpxml.hvac_controls.add(id: "HVACControl#{hpxml.hvac_controls.size + 1}",
                            heating_setpoint_temp: heating_setpoint_temp,
                            cooling_setpoint_temp: cooling_setpoint_temp,
                            weekday_heating_setpoints: weekday_heating_setpoints,
                            weekend_heating_setpoints: weekend_heating_setpoints,
                            weekday_cooling_setpoints: weekday_cooling_setpoints,
                            weekend_cooling_setpoints: weekend_cooling_setpoints,
                            ceiling_fan_cooling_setpoint_temp_offset: ceiling_fan_cooling_setpoint_temp_offset,
                            seasons_heating_begin_month: seasons_heating_begin_month,
                            seasons_heating_begin_day: seasons_heating_begin_day,
                            seasons_heating_end_month: seasons_heating_end_month,
                            seasons_heating_end_day: seasons_heating_end_day,
                            seasons_cooling_begin_month: seasons_cooling_begin_month,
                            seasons_cooling_begin_day: seasons_cooling_begin_day,
                            seasons_cooling_end_month: seasons_cooling_end_month,
                            seasons_cooling_end_day: seasons_cooling_end_day)
  end

  def self.set_ventilation_fans(hpxml, args)
    if args[:mech_vent_fan_type] != 'none'

      if [HPXML::MechVentTypeERV].include?(args[:mech_vent_fan_type])
        if args[:mech_vent_recovery_efficiency_type] == 'Unadjusted'
          total_recovery_efficiency = args[:mech_vent_total_recovery_efficiency]
          sensible_recovery_efficiency = args[:mech_vent_sensible_recovery_efficiency]
        elsif args[:mech_vent_recovery_efficiency_type] == 'Adjusted'
          total_recovery_efficiency_adjusted = args[:mech_vent_total_recovery_efficiency]
          sensible_recovery_efficiency_adjusted = args[:mech_vent_sensible_recovery_efficiency]
        end
      elsif [HPXML::MechVentTypeHRV].include?(args[:mech_vent_fan_type])
        if args[:mech_vent_recovery_efficiency_type] == 'Unadjusted'
          sensible_recovery_efficiency = args[:mech_vent_sensible_recovery_efficiency]
        elsif args[:mech_vent_recovery_efficiency_type] == 'Adjusted'
          sensible_recovery_efficiency_adjusted = args[:mech_vent_sensible_recovery_efficiency]
        end
      end

      distribution_system_idref = nil
      if args[:mech_vent_fan_type] == HPXML::MechVentTypeCFIS
        hpxml.hvac_distributions.each do |hvac_distribution|
          next unless hvac_distribution.distribution_system_type == HPXML::HVACDistributionTypeAir
          next if hvac_distribution.air_type != HPXML::AirTypeRegularVelocity

          distribution_system_idref = hvac_distribution.id
        end
        cfis_addtl_runtime_operating_mode = HPXML::CFISModeAirHandler
      end

      if args[:mech_vent_num_units_served] > 1
        is_shared_system = true
        in_unit_flow_rate = args[:mech_vent_flow_rate].get / args[:mech_vent_num_units_served].to_f
        fraction_recirculation = args[:mech_vent_shared_frac_recirculation].get
        if args[:mech_vent_shared_preheating_fuel].is_initialized && args[:mech_vent_shared_preheating_efficiency].is_initialized && args[:mech_vent_shared_preheating_fraction_heat_load_served].is_initialized
          preheating_fuel = args[:mech_vent_shared_preheating_fuel].get
          preheating_efficiency_cop = args[:mech_vent_shared_preheating_efficiency].get
          preheating_fraction_load_served = args[:mech_vent_shared_preheating_fraction_heat_load_served].get
        end
        if args[:mech_vent_shared_precooling_fuel].is_initialized && args[:mech_vent_shared_precooling_efficiency].is_initialized && args[:mech_vent_shared_precooling_fraction_cool_load_served].is_initialized
          precooling_fuel = args[:mech_vent_shared_precooling_fuel].get
          precooling_efficiency_cop = args[:mech_vent_shared_precooling_efficiency].get
          precooling_fraction_load_served = args[:mech_vent_shared_precooling_fraction_cool_load_served].get
        end
      end

      if args[:mech_vent_hours_in_operation].is_initialized
        hours_in_operation = args[:mech_vent_hours_in_operation].get
      end

      if args[:mech_vent_fan_power].is_initialized
        fan_power = args[:mech_vent_fan_power].get
      end

      if args[:mech_vent_flow_rate].is_initialized
        rated_flow_rate = args[:mech_vent_flow_rate].get
      end

      hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                                 fan_type: args[:mech_vent_fan_type],
                                 cfis_addtl_runtime_operating_mode: cfis_addtl_runtime_operating_mode,
                                 rated_flow_rate: rated_flow_rate,
                                 hours_in_operation: hours_in_operation,
                                 used_for_whole_building_ventilation: true,
                                 total_recovery_efficiency: total_recovery_efficiency,
                                 total_recovery_efficiency_adjusted: total_recovery_efficiency_adjusted,
                                 sensible_recovery_efficiency: sensible_recovery_efficiency,
                                 sensible_recovery_efficiency_adjusted: sensible_recovery_efficiency_adjusted,
                                 fan_power: fan_power,
                                 distribution_system_idref: distribution_system_idref,
                                 is_shared_system: is_shared_system,
                                 in_unit_flow_rate: in_unit_flow_rate,
                                 fraction_recirculation: fraction_recirculation,
                                 preheating_fuel: preheating_fuel,
                                 preheating_efficiency_cop: preheating_efficiency_cop,
                                 preheating_fraction_load_served: preheating_fraction_load_served,
                                 precooling_fuel: precooling_fuel,
                                 precooling_efficiency_cop: precooling_efficiency_cop,
                                 precooling_fraction_load_served: precooling_fraction_load_served)
    end

    if args[:mech_vent_2_fan_type] != 'none'

      if [HPXML::MechVentTypeERV].include?(args[:mech_vent_2_fan_type])

        if args[:mech_vent_2_recovery_efficiency_type] == 'Unadjusted'
          total_recovery_efficiency = args[:mech_vent_2_total_recovery_efficiency]
          sensible_recovery_efficiency = args[:mech_vent_2_sensible_recovery_efficiency]
        elsif args[:mech_vent_2_recovery_efficiency_type] == 'Adjusted'
          total_recovery_efficiency_adjusted = args[:mech_vent_2_total_recovery_efficiency]
          sensible_recovery_efficiency_adjusted = args[:mech_vent_2_sensible_recovery_efficiency]
        end
      elsif [HPXML::MechVentTypeHRV].include?(args[:mech_vent_2_fan_type])
        if args[:mech_vent_2_recovery_efficiency_type] == 'Unadjusted'
          sensible_recovery_efficiency = args[:mech_vent_2_sensible_recovery_efficiency]
        elsif args[:mech_vent_2_recovery_efficiency_type] == 'Adjusted'
          sensible_recovery_efficiency_adjusted = args[:mech_vent_2_sensible_recovery_efficiency]
        end
      end

      hours_in_operation = args[:mech_vent_2_hours_in_operation]
      fan_power = args[:mech_vent_2_fan_power]

      hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                                 fan_type: args[:mech_vent_2_fan_type],
                                 rated_flow_rate: args[:mech_vent_2_flow_rate],
                                 hours_in_operation: hours_in_operation,
                                 used_for_whole_building_ventilation: true,
                                 total_recovery_efficiency: total_recovery_efficiency,
                                 total_recovery_efficiency_adjusted: total_recovery_efficiency_adjusted,
                                 sensible_recovery_efficiency: sensible_recovery_efficiency,
                                 sensible_recovery_efficiency_adjusted: sensible_recovery_efficiency_adjusted,
                                 fan_power: fan_power)
    end

    if !args[:kitchen_fans_quantity].is_initialized || (args[:kitchen_fans_quantity].get > 0)
      if args[:kitchen_fans_flow_rate].is_initialized
        rated_flow_rate = args[:kitchen_fans_flow_rate].get
      end

      if args[:kitchen_fans_power].is_initialized
        fan_power = args[:kitchen_fans_power].get
      end

      if args[:kitchen_fans_hours_in_operation].is_initialized
        hours_in_operation = args[:kitchen_fans_hours_in_operation].get
      end

      if args[:kitchen_fans_start_hour].is_initialized
        start_hour = args[:kitchen_fans_start_hour].get
      end

      if args[:kitchen_fans_quantity].is_initialized
        quantity = args[:kitchen_fans_quantity].get
      end

      hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                                 rated_flow_rate: rated_flow_rate,
                                 used_for_local_ventilation: true,
                                 hours_in_operation: hours_in_operation,
                                 fan_location: HPXML::LocationKitchen,
                                 fan_power: fan_power,
                                 start_hour: start_hour,
                                 quantity: quantity)
    end

    if !args[:bathroom_fans_quantity].is_initialized || (args[:bathroom_fans_quantity].get > 0)
      if args[:bathroom_fans_flow_rate].is_initialized
        rated_flow_rate = args[:bathroom_fans_flow_rate].get
      end

      if args[:bathroom_fans_power].is_initialized
        fan_power = args[:bathroom_fans_power].get
      end

      if args[:bathroom_fans_hours_in_operation].is_initialized
        hours_in_operation = args[:bathroom_fans_hours_in_operation].get
      end

      if args[:bathroom_fans_start_hour].is_initialized
        start_hour = args[:bathroom_fans_start_hour].get
      end

      if args[:bathroom_fans_quantity].is_initialized
        quantity = args[:bathroom_fans_quantity].get
      end

      hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                                 rated_flow_rate: rated_flow_rate,
                                 used_for_local_ventilation: true,
                                 hours_in_operation: hours_in_operation,
                                 fan_location: HPXML::LocationBath,
                                 fan_power: fan_power,
                                 start_hour: start_hour,
                                 quantity: quantity)
    end

    if args[:whole_house_fan_present]
      if args[:whole_house_fan_flow_rate].is_initialized
        rated_flow_rate = args[:whole_house_fan_flow_rate].get
      end

      if args[:whole_house_fan_power].is_initialized
        fan_power = args[:whole_house_fan_power].get
      end

      hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                                 rated_flow_rate: rated_flow_rate,
                                 used_for_seasonal_cooling_load_reduction: true,
                                 fan_power: fan_power)
    end
  end

  def self.set_water_heating_systems(hpxml, args)
    water_heater_type = args[:water_heater_type]
    return if water_heater_type == 'none'

    if water_heater_type != HPXML::WaterHeaterTypeHeatPump
      fuel_type = args[:water_heater_fuel_type]
    else
      fuel_type = HPXML::FuelTypeElectricity
    end

    if args[:water_heater_location].is_initialized
      location = args[:water_heater_location].get
    end

    if args[:water_heater_tank_volume].is_initialized
      tank_volume = args[:water_heater_tank_volume].get
    end

    if args[:water_heater_setpoint_temperature].is_initialized
      temperature = args[:water_heater_setpoint_temperature].get
    end

    if not [HPXML::WaterHeaterTypeCombiStorage, HPXML::WaterHeaterTypeCombiTankless].include? water_heater_type
      if args[:water_heater_efficiency_type] == 'EnergyFactor'
        energy_factor = args[:water_heater_efficiency]
      elsif args[:water_heater_efficiency_type] == 'UniformEnergyFactor'
        uniform_energy_factor = args[:water_heater_efficiency]
        if water_heater_type != HPXML::WaterHeaterTypeTankless
          usage_bin = args[:water_heater_usage_bin].get if args[:water_heater_usage_bin].is_initialized
        end
      end
    end

    if (fuel_type != HPXML::FuelTypeElectricity) && (water_heater_type == HPXML::WaterHeaterTypeStorage)
      if args[:water_heater_recovery_efficiency].is_initialized
        recovery_efficiency = args[:water_heater_recovery_efficiency].get
      end
    end

    if [HPXML::WaterHeaterTypeTankless, HPXML::WaterHeaterTypeCombiTankless].include? water_heater_type
      tank_volume = nil
    end

    if [HPXML::WaterHeaterTypeTankless].include? water_heater_type
      heating_capacity = nil
      recovery_efficiency = nil
    elsif [HPXML::WaterHeaterTypeCombiTankless, HPXML::WaterHeaterTypeCombiStorage].include? water_heater_type
      fuel_type = nil
      heating_capacity = nil
      energy_factor = nil
      if hpxml.heating_systems.size > 0
        related_hvac_idref = hpxml.heating_systems[0].id
      end
    end

    if [HPXML::WaterHeaterTypeCombiTankless, HPXML::WaterHeaterTypeCombiStorage].include? water_heater_type
      if args[:water_heater_standby_loss].is_initialized
        if args[:water_heater_standby_loss].get > 0
          standby_loss_units = HPXML::UnitsDegFPerHour
          standby_loss_value = args[:water_heater_standby_loss].get
        end
      end
    end

    if not [HPXML::WaterHeaterTypeTankless, HPXML::WaterHeaterTypeCombiTankless].include? water_heater_type
      if args[:water_heater_jacket_rvalue].is_initialized
        if args[:water_heater_jacket_rvalue].get > 0
          jacket_r_value = args[:water_heater_jacket_rvalue].get
        end
      end
    end

    if args[:water_heater_num_units_served] > 1
      is_shared_system = true
      number_of_units_served = args[:water_heater_num_units_served]
    end
    if args[:water_heater_uses_desuperheater].is_initialized
      uses_desuperheater = args[:water_heater_uses_desuperheater].get
      if uses_desuperheater
        related_hvac_idref = nil
        hpxml.cooling_systems.each do |cooling_system|
          next unless [HPXML::HVACTypeCentralAirConditioner,
                       HPXML::HVACTypeMiniSplitAirConditioner].include? cooling_system.cooling_system_type

          related_hvac_idref = cooling_system.id
        end
        hpxml.heat_pumps.each do |heat_pump|
          next unless [HPXML::HVACTypeHeatPumpAirToAir,
                       HPXML::HVACTypeHeatPumpMiniSplit,
                       HPXML::HVACTypeHeatPumpGroundToAir].include? heat_pump.heat_pump_type

          related_hvac_idref = heat_pump.id
        end
      end
    end

    if [HPXML::WaterHeaterTypeStorage].include? water_heater_type
      if args[:water_heater_heating_capacity].is_initialized
        heating_capacity = args[:water_heater_heating_capacity].get
      end

      if args[:water_heater_tank_model_type].is_initialized
        tank_model_type = args[:water_heater_tank_model_type].get
      end
    elsif [HPXML::WaterHeaterTypeHeatPump].include? water_heater_type
      if args[:water_heater_operating_mode].is_initialized
        operating_mode = args[:water_heater_operating_mode].get
      end
    end

    hpxml.water_heating_systems.add(id: "WaterHeatingSystem#{hpxml.water_heating_systems.size + 1}",
                                    water_heater_type: water_heater_type,
                                    fuel_type: fuel_type,
                                    location: location,
                                    tank_volume: tank_volume,
                                    fraction_dhw_load_served: 1.0,
                                    energy_factor: energy_factor,
                                    uniform_energy_factor: uniform_energy_factor,
                                    usage_bin: usage_bin,
                                    recovery_efficiency: recovery_efficiency,
                                    uses_desuperheater: uses_desuperheater,
                                    related_hvac_idref: related_hvac_idref,
                                    standby_loss_units: standby_loss_units,
                                    standby_loss_value: standby_loss_value,
                                    jacket_r_value: jacket_r_value,
                                    temperature: temperature,
                                    heating_capacity: heating_capacity,
                                    is_shared_system: is_shared_system,
                                    number_of_units_served: number_of_units_served,
                                    tank_model_type: tank_model_type,
                                    operating_mode: operating_mode)
  end

  def self.set_hot_water_distribution(hpxml, args)
    return if args[:water_heater_type] == 'none'

    if args[:dwhr_facilities_connected] != 'none'
      dwhr_facilities_connected = args[:dwhr_facilities_connected]
      dwhr_equal_flow = args[:dwhr_equal_flow]
      dwhr_efficiency = args[:dwhr_efficiency]
    end

    if args[:hot_water_distribution_system_type] == HPXML::DHWDistTypeStandard
      if args[:hot_water_distribution_standard_piping_length].is_initialized
        standard_piping_length = args[:hot_water_distribution_standard_piping_length].get
      end
    else
      recirculation_control_type = args[:hot_water_distribution_recirc_control_type]

      if args[:hot_water_distribution_recirc_piping_length].is_initialized
        recirculation_piping_length = args[:hot_water_distribution_recirc_piping_length].get
      end

      if args[:hot_water_distribution_recirc_branch_piping_length].is_initialized
        recirculation_branch_piping_length = args[:hot_water_distribution_recirc_branch_piping_length].get
      end

      if args[:hot_water_distribution_recirc_pump_power].is_initialized
        recirculation_pump_power = args[:hot_water_distribution_recirc_pump_power].get
      end
    end

    if args[:hot_water_distribution_pipe_r].is_initialized
      pipe_r_value = args[:hot_water_distribution_pipe_r].get
    end

    hpxml.hot_water_distributions.add(id: "HotWaterDistribution#{hpxml.hot_water_distributions.size + 1}",
                                      system_type: args[:hot_water_distribution_system_type],
                                      standard_piping_length: standard_piping_length,
                                      recirculation_control_type: recirculation_control_type,
                                      recirculation_piping_length: recirculation_piping_length,
                                      recirculation_branch_piping_length: recirculation_branch_piping_length,
                                      recirculation_pump_power: recirculation_pump_power,
                                      pipe_r_value: pipe_r_value,
                                      dwhr_facilities_connected: dwhr_facilities_connected,
                                      dwhr_equal_flow: dwhr_equal_flow,
                                      dwhr_efficiency: dwhr_efficiency)
  end

  def self.set_water_fixtures(hpxml, args)
    return if args[:water_heater_type] == 'none'

    hpxml.water_fixtures.add(id: "WaterFixture#{hpxml.water_fixtures.size + 1}",
                             water_fixture_type: HPXML::WaterFixtureTypeShowerhead,
                             low_flow: args[:water_fixtures_shower_low_flow])

    hpxml.water_fixtures.add(id: "WaterFixture#{hpxml.water_fixtures.size + 1}",
                             water_fixture_type: HPXML::WaterFixtureTypeFaucet,
                             low_flow: args[:water_fixtures_sink_low_flow])

    if args[:water_fixtures_usage_multiplier].is_initialized
      hpxml.water_heating.water_fixtures_usage_multiplier = args[:water_fixtures_usage_multiplier].get
    end
  end

  def self.set_solar_thermal(hpxml, args, epw_file)
    return if args[:solar_thermal_system_type] == 'none'

    if args[:solar_thermal_solar_fraction] > 0
      solar_fraction = args[:solar_thermal_solar_fraction]
    else
      collector_area = args[:solar_thermal_collector_area]
      collector_loop_type = args[:solar_thermal_collector_loop_type]
      collector_type = args[:solar_thermal_collector_type]
      collector_azimuth = args[:solar_thermal_collector_azimuth]
      collector_tilt = Geometry.get_absolute_tilt(args[:solar_thermal_collector_tilt], args[:geometry_roof_pitch], epw_file)
      collector_frta = args[:solar_thermal_collector_rated_optical_efficiency]
      collector_frul = args[:solar_thermal_collector_rated_thermal_losses]

      if args[:solar_thermal_storage_volume].is_initialized
        storage_volume = args[:solar_thermal_storage_volume].get
      end
    end

    if hpxml.water_heating_systems.size == 0
      fail 'Solar thermal system specified but no water heater found.'
    end

    hpxml.solar_thermal_systems.add(id: "SolarThermalSystem#{hpxml.solar_thermal_systems.size + 1}",
                                    system_type: args[:solar_thermal_system_type],
                                    collector_area: collector_area,
                                    collector_loop_type: collector_loop_type,
                                    collector_type: collector_type,
                                    collector_azimuth: collector_azimuth,
                                    collector_tilt: collector_tilt,
                                    collector_frta: collector_frta,
                                    collector_frul: collector_frul,
                                    storage_volume: storage_volume,
                                    water_heating_system_idref: hpxml.water_heating_systems[0].id,
                                    solar_fraction: solar_fraction)
  end

  def self.set_pv_systems(hpxml, args, epw_file)
    [args[:pv_system_present], args[:pv_system_2_present]].each_with_index do |pv_system_present, i|
      next unless pv_system_present

      if [args[:pv_system_module_type], args[:pv_system_2_module_type]][i].is_initialized
        module_type = [args[:pv_system_module_type], args[:pv_system_2_module_type]][i].get
      end

      if [args[:pv_system_location], args[:pv_system_2_location]][i].is_initialized
        location = [args[:pv_system_location], args[:pv_system_2_location]][i].get
      end

      if [args[:pv_system_tracking], args[:pv_system_2_tracking]][i].is_initialized
        tracking = [args[:pv_system_tracking], args[:pv_system_2_tracking]][i].get
      end

      max_power_output = [args[:pv_system_max_power_output], args[:pv_system_2_max_power_output]][i]

      if args[:pv_system_inverter_efficiency].is_initialized
        inverter_efficiency = args[:pv_system_inverter_efficiency].get
      end

      if args[:pv_system_system_losses_fraction].is_initialized
        system_losses_fraction = args[:pv_system_system_losses_fraction].get
      end

      if [HPXML::ResidentialTypeSFA, HPXML::ResidentialTypeApartment].include? args[:geometry_unit_type]
        if args[:pv_system_num_bedrooms_served].get > args[:geometry_unit_num_bedrooms]
          is_shared_system = true
          number_of_bedrooms_served = args[:pv_system_num_bedrooms_served].get
        end
      end

      hpxml.pv_systems.add(id: "PVSystem#{hpxml.pv_systems.size + 1}",
                           location: location,
                           module_type: module_type,
                           tracking: tracking,
                           array_azimuth: [args[:pv_system_array_azimuth], args[:pv_system_2_array_azimuth]][i],
                           array_tilt: Geometry.get_absolute_tilt([args[:pv_system_array_tilt], args[:pv_system_2_array_tilt]][i], args[:geometry_roof_pitch], epw_file),
                           max_power_output: max_power_output,
                           inverter_efficiency: inverter_efficiency,
                           system_losses_fraction: system_losses_fraction,
                           is_shared_system: is_shared_system,
                           number_of_bedrooms_served: number_of_bedrooms_served)
    end
  end

  def self.set_battery(hpxml, args)
    return unless args[:battery_present]

    if args[:battery_location].is_initialized
      location = args[:battery_location].get
    end

    if args[:battery_power].is_initialized
      rated_power_output = args[:battery_power].get
    end

    if args[:battery_capacity].is_initialized
      nominal_capacity_kwh = args[:battery_capacity].get
    end

    if args[:battery_usable_capacity].is_initialized
      usable_capacity_kwh = args[:battery_usable_capacity].get
    end

    if args[:battery_round_trip_efficiency].is_initialized
      round_trip_efficiency = args[:battery_round_trip_efficiency].get
    end

    hpxml.batteries.add(id: "Battery#{hpxml.batteries.size + 1}",
                        type: HPXML::BatteryTypeLithiumIon,
                        location: location,
                        rated_power_output: rated_power_output,
                        nominal_capacity_kwh: nominal_capacity_kwh,
                        usable_capacity_kwh: usable_capacity_kwh,
                        round_trip_efficiency: round_trip_efficiency)
  end

  def self.set_lighting(hpxml, args)
    return unless args[:lighting_present] || args[:ceiling_fan_present] # If ceiling fans present but not lighting present, need to continue and use lighting multipliers = 0 instead

    hpxml.lighting_groups.add(id: "LightingGroup#{hpxml.lighting_groups.size + 1}",
                              location: HPXML::LocationInterior,
                              fraction_of_units_in_location: args[:lighting_interior_fraction_cfl],
                              lighting_type: HPXML::LightingTypeCFL)
    hpxml.lighting_groups.add(id: "LightingGroup#{hpxml.lighting_groups.size + 1}",
                              location: HPXML::LocationExterior,
                              fraction_of_units_in_location: args[:lighting_exterior_fraction_cfl],
                              lighting_type: HPXML::LightingTypeCFL)
    hpxml.lighting_groups.add(id: "LightingGroup#{hpxml.lighting_groups.size + 1}",
                              location: HPXML::LocationGarage,
                              fraction_of_units_in_location: args[:lighting_garage_fraction_cfl],
                              lighting_type: HPXML::LightingTypeCFL)
    hpxml.lighting_groups.add(id: "LightingGroup#{hpxml.lighting_groups.size + 1}",
                              location: HPXML::LocationInterior,
                              fraction_of_units_in_location: args[:lighting_interior_fraction_lfl],
                              lighting_type: HPXML::LightingTypeLFL)
    hpxml.lighting_groups.add(id: "LightingGroup#{hpxml.lighting_groups.size + 1}",
                              location: HPXML::LocationExterior,
                              fraction_of_units_in_location: args[:lighting_exterior_fraction_lfl],
                              lighting_type: HPXML::LightingTypeLFL)
    hpxml.lighting_groups.add(id: "LightingGroup#{hpxml.lighting_groups.size + 1}",
                              location: HPXML::LocationGarage,
                              fraction_of_units_in_location: args[:lighting_garage_fraction_lfl],
                              lighting_type: HPXML::LightingTypeLFL)
    hpxml.lighting_groups.add(id: "LightingGroup#{hpxml.lighting_groups.size + 1}",
                              location: HPXML::LocationInterior,
                              fraction_of_units_in_location: args[:lighting_interior_fraction_led],
                              lighting_type: HPXML::LightingTypeLED)
    hpxml.lighting_groups.add(id: "LightingGroup#{hpxml.lighting_groups.size + 1}",
                              location: HPXML::LocationExterior,
                              fraction_of_units_in_location: args[:lighting_exterior_fraction_led],
                              lighting_type: HPXML::LightingTypeLED)
    hpxml.lighting_groups.add(id: "LightingGroup#{hpxml.lighting_groups.size + 1}",
                              location: HPXML::LocationGarage,
                              fraction_of_units_in_location: args[:lighting_garage_fraction_led],
                              lighting_type: HPXML::LightingTypeLED)

    if args[:lighting_present]
      if args[:lighting_interior_usage_multiplier].is_initialized
        hpxml.lighting.interior_usage_multiplier = args[:lighting_interior_usage_multiplier].get
      end

      if args[:lighting_exterior_usage_multiplier].is_initialized
        hpxml.lighting.exterior_usage_multiplier = args[:lighting_exterior_usage_multiplier].get
      end

      if args[:lighting_garage_usage_multiplier].is_initialized
        hpxml.lighting.garage_usage_multiplier = args[:lighting_garage_usage_multiplier].get
      end
    elsif args[:ceiling_fan_present]
      hpxml.lighting.interior_usage_multiplier = 0.0
      hpxml.lighting.exterior_usage_multiplier = 0.0
      hpxml.lighting.garage_usage_multiplier = 0.0
    end

    return unless args[:holiday_lighting_present]

    hpxml.lighting.holiday_exists = true

    if args[:holiday_lighting_daily_kwh].is_initialized
      hpxml.lighting.holiday_kwh_per_day = args[:holiday_lighting_daily_kwh].get
    end

    if args[:holiday_lighting_period].is_initialized
      begin_month, begin_day, end_month, end_day = Schedule.parse_date_range(args[:holiday_lighting_period].get)
      hpxml.lighting.holiday_period_begin_month = begin_month
      hpxml.lighting.holiday_period_begin_day = begin_day
      hpxml.lighting.holiday_period_end_month = end_month
      hpxml.lighting.holiday_period_end_day = end_day
    end
  end

  def self.set_dehumidifier(hpxml, args)
    return if args[:dehumidifier_type] == 'none'

    if args[:dehumidifier_efficiency_type] == 'EnergyFactor'
      energy_factor = args[:dehumidifier_efficiency]
    elsif args[:dehumidifier_efficiency_type] == 'IntegratedEnergyFactor'
      integrated_energy_factor = args[:dehumidifier_efficiency]
    end

    hpxml.dehumidifiers.add(id: "Dehumidifier#{hpxml.dehumidifiers.size + 1}",
                            type: args[:dehumidifier_type],
                            capacity: args[:dehumidifier_capacity],
                            energy_factor: energy_factor,
                            integrated_energy_factor: integrated_energy_factor,
                            rh_setpoint: args[:dehumidifier_rh_setpoint],
                            fraction_served: args[:dehumidifier_fraction_dehumidification_load_served],
                            location: HPXML::LocationLivingSpace)
  end

  def self.set_clothes_washer(hpxml, args)
    return if args[:water_heater_type] == 'none'
    return unless args[:clothes_washer_present]

    if args[:clothes_washer_rated_annual_kwh].is_initialized
      rated_annual_kwh = args[:clothes_washer_rated_annual_kwh].get
    end

    if args[:clothes_washer_location].is_initialized
      location = args[:clothes_washer_location].get
    end

    if args[:clothes_washer_efficiency].is_initialized
      if args[:clothes_washer_efficiency_type] == 'ModifiedEnergyFactor'
        modified_energy_factor = args[:clothes_washer_efficiency].get
      elsif args[:clothes_washer_efficiency_type] == 'IntegratedModifiedEnergyFactor'
        integrated_modified_energy_factor = args[:clothes_washer_efficiency].get
      end
    end

    if args[:clothes_washer_label_electric_rate].is_initialized
      label_electric_rate = args[:clothes_washer_label_electric_rate].get
    end

    if args[:clothes_washer_label_gas_rate].is_initialized
      label_gas_rate = args[:clothes_washer_label_gas_rate].get
    end

    if args[:clothes_washer_label_annual_gas_cost].is_initialized
      label_annual_gas_cost = args[:clothes_washer_label_annual_gas_cost].get
    end

    if args[:clothes_washer_label_usage].is_initialized
      label_usage = args[:clothes_washer_label_usage].get
    end

    if args[:clothes_washer_capacity].is_initialized
      capacity = args[:clothes_washer_capacity].get
    end

    if args[:clothes_washer_usage_multiplier].is_initialized
      usage_multiplier = args[:clothes_washer_usage_multiplier].get
    end

    hpxml.clothes_washers.add(id: "ClothesWasher#{hpxml.clothes_washers.size + 1}",
                              location: location,
                              modified_energy_factor: modified_energy_factor,
                              integrated_modified_energy_factor: integrated_modified_energy_factor,
                              rated_annual_kwh: rated_annual_kwh,
                              label_electric_rate: label_electric_rate,
                              label_gas_rate: label_gas_rate,
                              label_annual_gas_cost: label_annual_gas_cost,
                              label_usage: label_usage,
                              capacity: capacity,
                              usage_multiplier: usage_multiplier)
  end

  def self.set_clothes_dryer(hpxml, args)
    return if args[:water_heater_type] == 'none'
    return unless args[:clothes_washer_present]
    return unless args[:clothes_dryer_present]

    if args[:clothes_dryer_efficiency].is_initialized
      if args[:clothes_dryer_efficiency_type] == 'EnergyFactor'
        energy_factor = args[:clothes_dryer_efficiency].get
      elsif args[:clothes_dryer_efficiency_type] == 'CombinedEnergyFactor'
        combined_energy_factor = args[:clothes_dryer_efficiency].get
      end
    end

    if args[:clothes_dryer_location].is_initialized
      location = args[:clothes_dryer_location].get
    end

    if args[:clothes_dryer_vented_flow_rate].is_initialized
      is_vented = false
      if args[:clothes_dryer_vented_flow_rate].get > 0
        is_vented = true
        vented_flow_rate = args[:clothes_dryer_vented_flow_rate].get
      end
    end

    if args[:clothes_dryer_usage_multiplier].is_initialized
      usage_multiplier = args[:clothes_dryer_usage_multiplier].get
    end

    hpxml.clothes_dryers.add(id: "ClothesDryer#{hpxml.clothes_dryers.size + 1}",
                             location: location,
                             fuel_type: args[:clothes_dryer_fuel_type],
                             energy_factor: energy_factor,
                             combined_energy_factor: combined_energy_factor,
                             is_vented: is_vented,
                             vented_flow_rate: vented_flow_rate,
                             usage_multiplier: usage_multiplier)
  end

  def self.set_dishwasher(hpxml, args)
    return if args[:water_heater_type] == 'none'
    return unless args[:dishwasher_present]

    if args[:dishwasher_location].is_initialized
      location = args[:dishwasher_location].get
    end

    if args[:dishwasher_efficiency_type] == 'RatedAnnualkWh'
      if args[:dishwasher_efficiency].is_initialized
        rated_annual_kwh = args[:dishwasher_efficiency].get
      end
    elsif args[:dishwasher_efficiency_type] == 'EnergyFactor'
      if args[:dishwasher_efficiency].is_initialized
        energy_factor = args[:dishwasher_efficiency].get
      end
    end

    if args[:dishwasher_label_electric_rate].is_initialized
      label_electric_rate = args[:dishwasher_label_electric_rate].get
    end

    if args[:dishwasher_label_gas_rate].is_initialized
      label_gas_rate = args[:dishwasher_label_gas_rate].get
    end

    if args[:dishwasher_label_annual_gas_cost].is_initialized
      label_annual_gas_cost = args[:dishwasher_label_annual_gas_cost].get
    end

    if args[:dishwasher_label_usage].is_initialized
      label_usage = args[:dishwasher_label_usage].get
    end

    if args[:dishwasher_place_setting_capacity].is_initialized
      place_setting_capacity = args[:dishwasher_place_setting_capacity].get
    end

    if args[:dishwasher_usage_multiplier].is_initialized
      usage_multiplier = args[:dishwasher_usage_multiplier].get
    end

    hpxml.dishwashers.add(id: "Dishwasher#{hpxml.dishwashers.size + 1}",
                          location: location,
                          rated_annual_kwh: rated_annual_kwh,
                          energy_factor: energy_factor,
                          label_electric_rate: label_electric_rate,
                          label_gas_rate: label_gas_rate,
                          label_annual_gas_cost: label_annual_gas_cost,
                          label_usage: label_usage,
                          place_setting_capacity: place_setting_capacity,
                          usage_multiplier: usage_multiplier)
  end

  def self.set_refrigerator(hpxml, args)
    return unless args[:refrigerator_present]

    if args[:refrigerator_rated_annual_kwh].is_initialized
      rated_annual_kwh = args[:refrigerator_rated_annual_kwh].get
    end

    if args[:refrigerator_location].is_initialized
      location = args[:refrigerator_location].get
    end

    if args[:refrigerator_usage_multiplier].is_initialized
      usage_multiplier = args[:refrigerator_usage_multiplier].get
    end

    hpxml.refrigerators.add(id: "Refrigerator#{hpxml.refrigerators.size + 1}",
                            location: location,
                            rated_annual_kwh: rated_annual_kwh,
                            primary_indicator: true,
                            usage_multiplier: usage_multiplier)
  end

  def self.set_extra_refrigerator(hpxml, args)
    return unless args[:extra_refrigerator_present]

    if args[:extra_refrigerator_rated_annual_kwh].is_initialized
      rated_annual_kwh = args[:extra_refrigerator_rated_annual_kwh].get
    end

    if args[:extra_refrigerator_location].is_initialized
      location = args[:extra_refrigerator_location].get
    end

    if args[:extra_refrigerator_usage_multiplier].is_initialized
      usage_multiplier = args[:extra_refrigerator_usage_multiplier].get
    end

    hpxml.refrigerators.add(id: "Refrigerator#{hpxml.refrigerators.size + 1}",
                            location: location,
                            rated_annual_kwh: rated_annual_kwh,
                            primary_indicator: false,
                            usage_multiplier: usage_multiplier)
  end

  def self.set_freezer(hpxml, args)
    return unless args[:freezer_present]

    if args[:freezer_rated_annual_kwh].is_initialized
      rated_annual_kwh = args[:freezer_rated_annual_kwh].get
    end

    if args[:freezer_location].is_initialized
      location = args[:freezer_location].get
    end

    if args[:freezer_usage_multiplier].is_initialized
      usage_multiplier = args[:freezer_usage_multiplier].get
    end

    hpxml.freezers.add(id: "Freezer#{hpxml.freezers.size + 1}",
                       location: location,
                       rated_annual_kwh: rated_annual_kwh,
                       usage_multiplier: usage_multiplier)
  end

  def self.set_cooking_range_oven(hpxml, args)
    return unless args[:cooking_range_oven_present]

    if args[:cooking_range_oven_location].is_initialized
      location = args[:cooking_range_oven_location].get
    end

    if args[:cooking_range_oven_is_induction].is_initialized
      is_induction = args[:cooking_range_oven_is_induction].get
    end

    if args[:cooking_range_oven_usage_multiplier].is_initialized
      usage_multiplier = args[:cooking_range_oven_usage_multiplier].get
    end

    hpxml.cooking_ranges.add(id: "CookingRange#{hpxml.cooking_ranges.size + 1}",
                             location: location,
                             fuel_type: args[:cooking_range_oven_fuel_type],
                             is_induction: is_induction,
                             usage_multiplier: usage_multiplier)

    if args[:cooking_range_oven_is_convection].is_initialized
      is_convection = args[:cooking_range_oven_is_convection].get
    end

    hpxml.ovens.add(id: "Oven#{hpxml.ovens.size + 1}",
                    is_convection: is_convection)
  end

  def self.set_ceiling_fans(hpxml, args)
    return unless args[:ceiling_fan_present]

    if args[:ceiling_fan_efficiency].is_initialized
      efficiency = args[:ceiling_fan_efficiency].get
    end

    if args[:ceiling_fan_quantity].is_initialized
      quantity = args[:ceiling_fan_quantity].get
    end

    hpxml.ceiling_fans.add(id: "CeilingFan#{hpxml.ceiling_fans.size + 1}",
                           efficiency: efficiency,
                           quantity: quantity)
  end

  def self.set_misc_plug_loads_television(hpxml, args)
    return unless args[:misc_plug_loads_television_present]

    if args[:misc_plug_loads_television_annual_kwh].is_initialized
      kWh_per_year = args[:misc_plug_loads_television_annual_kwh].get
    end

    if args[:misc_plug_loads_television_usage_multiplier].is_initialized
      usage_multiplier = args[:misc_plug_loads_television_usage_multiplier].get
    end

    hpxml.plug_loads.add(id: "PlugLoad#{hpxml.plug_loads.size + 1}",
                         plug_load_type: HPXML::PlugLoadTypeTelevision,
                         kWh_per_year: kWh_per_year,
                         usage_multiplier: usage_multiplier)
  end

  def self.set_misc_plug_loads_other(hpxml, args)
    if args[:misc_plug_loads_other_annual_kwh].is_initialized
      kWh_per_year = args[:misc_plug_loads_other_annual_kwh].get
    end

    if args[:misc_plug_loads_other_frac_sensible].is_initialized
      frac_sensible = args[:misc_plug_loads_other_frac_sensible].get
    end

    if args[:misc_plug_loads_other_frac_latent].is_initialized
      frac_latent = args[:misc_plug_loads_other_frac_latent].get
    end

    if args[:misc_plug_loads_other_usage_multiplier].is_initialized
      usage_multiplier = args[:misc_plug_loads_other_usage_multiplier].get
    end

    hpxml.plug_loads.add(id: "PlugLoad#{hpxml.plug_loads.size + 1}",
                         plug_load_type: HPXML::PlugLoadTypeOther,
                         kWh_per_year: kWh_per_year,
                         frac_sensible: frac_sensible,
                         frac_latent: frac_latent,
                         usage_multiplier: usage_multiplier)
  end

  def self.set_misc_plug_loads_well_pump(hpxml, args)
    return unless args[:misc_plug_loads_well_pump_present]

    if args[:misc_plug_loads_well_pump_annual_kwh].is_initialized
      kWh_per_year = args[:misc_plug_loads_well_pump_annual_kwh].get
    end

    if args[:misc_plug_loads_well_pump_usage_multiplier].is_initialized
      usage_multiplier = args[:misc_plug_loads_well_pump_usage_multiplier].get
    end

    hpxml.plug_loads.add(id: "PlugLoad#{hpxml.plug_loads.size + 1}",
                         plug_load_type: HPXML::PlugLoadTypeWellPump,
                         kWh_per_year: kWh_per_year,
                         usage_multiplier: usage_multiplier)
  end

  def self.set_misc_plug_loads_vehicle(hpxml, args)
    return unless args[:misc_plug_loads_vehicle_present]

    if args[:misc_plug_loads_vehicle_annual_kwh].is_initialized
      kWh_per_year = args[:misc_plug_loads_vehicle_annual_kwh].get
    end

    if args[:misc_plug_loads_vehicle_usage_multiplier].is_initialized
      usage_multiplier = args[:misc_plug_loads_vehicle_usage_multiplier].get
    end

    hpxml.plug_loads.add(id: "PlugLoad#{hpxml.plug_loads.size + 1}",
                         plug_load_type: HPXML::PlugLoadTypeElectricVehicleCharging,
                         kWh_per_year: kWh_per_year,
                         usage_multiplier: usage_multiplier)
  end

  def self.set_misc_fuel_loads_grill(hpxml, args)
    return unless args[:misc_fuel_loads_grill_present]

    if args[:misc_fuel_loads_grill_annual_therm].is_initialized
      therm_per_year = args[:misc_fuel_loads_grill_annual_therm].get
    end

    if args[:misc_fuel_loads_grill_usage_multiplier].is_initialized
      usage_multiplier = args[:misc_fuel_loads_grill_usage_multiplier].get
    end

    hpxml.fuel_loads.add(id: "FuelLoad#{hpxml.fuel_loads.size + 1}",
                         fuel_load_type: HPXML::FuelLoadTypeGrill,
                         fuel_type: args[:misc_fuel_loads_grill_fuel_type],
                         therm_per_year: therm_per_year,
                         usage_multiplier: usage_multiplier)
  end

  def self.set_misc_fuel_loads_lighting(hpxml, args)
    return unless args[:misc_fuel_loads_lighting_present]

    if args[:misc_fuel_loads_lighting_annual_therm].is_initialized
      therm_per_year = args[:misc_fuel_loads_lighting_annual_therm].get
    end

    if args[:misc_fuel_loads_lighting_usage_multiplier].is_initialized
      usage_multiplier = args[:misc_fuel_loads_lighting_usage_multiplier].get
    end

    hpxml.fuel_loads.add(id: "FuelLoad#{hpxml.fuel_loads.size + 1}",
                         fuel_load_type: HPXML::FuelLoadTypeLighting,
                         fuel_type: args[:misc_fuel_loads_lighting_fuel_type],
                         therm_per_year: therm_per_year,
                         usage_multiplier: usage_multiplier)
  end

  def self.set_misc_fuel_loads_fireplace(hpxml, args)
    return unless args[:misc_fuel_loads_fireplace_present]

    if args[:misc_fuel_loads_fireplace_annual_therm].is_initialized
      therm_per_year = args[:misc_fuel_loads_fireplace_annual_therm].get
    end

    if args[:misc_fuel_loads_fireplace_frac_sensible].is_initialized
      frac_sensible = args[:misc_fuel_loads_fireplace_frac_sensible].get
    end

    if args[:misc_fuel_loads_fireplace_frac_latent].is_initialized
      frac_latent = args[:misc_fuel_loads_fireplace_frac_latent].get
    end

    if args[:misc_fuel_loads_fireplace_usage_multiplier].is_initialized
      usage_multiplier = args[:misc_fuel_loads_fireplace_usage_multiplier].get
    end

    hpxml.fuel_loads.add(id: "FuelLoad#{hpxml.fuel_loads.size + 1}",
                         fuel_load_type: HPXML::FuelLoadTypeFireplace,
                         fuel_type: args[:misc_fuel_loads_fireplace_fuel_type],
                         therm_per_year: therm_per_year,
                         frac_sensible: frac_sensible,
                         frac_latent: frac_latent,
                         usage_multiplier: usage_multiplier)
  end

  def self.set_pool(hpxml, args)
    return unless args[:pool_present]

    if args[:pool_pump_annual_kwh].is_initialized
      pump_kwh_per_year = args[:pool_pump_annual_kwh].get
    end

    if args[:pool_pump_usage_multiplier].is_initialized
      pump_usage_multiplier = args[:pool_pump_usage_multiplier].get
    end

    pool_heater_type = args[:pool_heater_type]

    if [HPXML::HeaterTypeElectricResistance, HPXML::HeaterTypeHeatPump].include?(pool_heater_type)
      if args[:pool_heater_annual_kwh].is_initialized
        heater_load_units = HPXML::UnitsKwhPerYear
        heater_load_value = args[:pool_heater_annual_kwh].get
      end
    end

    if [HPXML::HeaterTypeGas].include?(pool_heater_type)
      if args[:pool_heater_annual_therm].is_initialized
        heater_load_units = HPXML::UnitsThermPerYear
        heater_load_value = args[:pool_heater_annual_therm].get
      end
    end

    if args[:pool_heater_usage_multiplier].is_initialized
      heater_usage_multiplier = args[:pool_heater_usage_multiplier].get
    end

    hpxml.pools.add(id: "Pool#{hpxml.pools.size + 1}",
                    type: HPXML::TypeUnknown,
                    pump_type: HPXML::TypeUnknown,
                    pump_kwh_per_year: pump_kwh_per_year,
                    pump_usage_multiplier: pump_usage_multiplier,
                    heater_type: pool_heater_type,
                    heater_load_units: heater_load_units,
                    heater_load_value: heater_load_value,
                    heater_usage_multiplier: heater_usage_multiplier)
  end

  def self.set_hot_tub(hpxml, args)
    return unless args[:hot_tub_present]

    if args[:hot_tub_pump_annual_kwh].is_initialized
      pump_kwh_per_year = args[:hot_tub_pump_annual_kwh].get
    end

    if args[:hot_tub_pump_usage_multiplier].is_initialized
      pump_usage_multiplier = args[:hot_tub_pump_usage_multiplier].get
    end

    hot_tub_heater_type = args[:hot_tub_heater_type]

    if [HPXML::HeaterTypeElectricResistance, HPXML::HeaterTypeHeatPump].include?(hot_tub_heater_type)
      if args[:hot_tub_heater_annual_kwh].is_initialized
        heater_load_units = HPXML::UnitsKwhPerYear
        heater_load_value = args[:hot_tub_heater_annual_kwh].get
      end
    end

    if [HPXML::HeaterTypeGas].include?(hot_tub_heater_type)
      if args[:hot_tub_heater_annual_therm].is_initialized
        heater_load_units = HPXML::UnitsThermPerYear
        heater_load_value = args[:hot_tub_heater_annual_therm].get
      end
    end

    if args[:hot_tub_heater_usage_multiplier].is_initialized
      heater_usage_multiplier = args[:hot_tub_heater_usage_multiplier].get
    end

    hpxml.hot_tubs.add(id: "HotTub#{hpxml.hot_tubs.size + 1}",
                       type: HPXML::TypeUnknown,
                       pump_type: HPXML::TypeUnknown,
                       pump_kwh_per_year: pump_kwh_per_year,
                       pump_usage_multiplier: pump_usage_multiplier,
                       heater_type: hot_tub_heater_type,
                       heater_load_units: heater_load_units,
                       heater_load_value: heater_load_value,
                       heater_usage_multiplier: heater_usage_multiplier)
  end
end

# register the measure to be used by the application
BuildResidentialHPXML.new.registerWithApplication
