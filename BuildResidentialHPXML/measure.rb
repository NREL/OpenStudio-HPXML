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
    return "The measure handles geometry by 1) translating high-level geometry inputs (conditioned floor area, number of stories, etc.) to 3D closed-form geometry in an OpenStudio model and then 2) mapping the OpenStudio surfaces to HPXML surfaces (using surface type, boundary condition, area, orientation, etc.). Like surfaces are collapsed into a single surface with aggregate surface area. Note: OS-HPXML default values can be found in the documentation or can be seen by using the 'apply_defaults' argument."
  end

  # Define the arguments that the user will input.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @return [OpenStudio::Measure::OSArgumentVector] an OpenStudio::Measure::OSArgumentVector object
  def arguments(model) # rubocop:disable Lint/UnusedMethodArgument
    docs_base_url = "https://openstudio-hpxml.readthedocs.io/en/v#{Version::OS_HPXML_Version}/workflow_inputs.html"

    args = OpenStudio::Measure::OSArgumentVector.new

    # Get Hash of all option name choices for all TSV files in the resources/options/ dir.
    # For example, choices:enclosure_air_leakage] = ['Tight', 'Leaky', etc']
    choices = {}
    Dir["#{File.dirname(__FILE__)}/resources/options/*.tsv"].each do |tsv_filepath|
      tsv_filename = File.basename(tsv_filepath)
      arg_name = File.basename(tsv_filename, File.extname(tsv_filename)).to_sym
      choices[arg_name] = get_option_names(tsv_filename)
    end

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hpxml_path', true)
    arg.setDisplayName('HPXML File Path')
    arg.setDescription('Absolute/relative path of the HPXML file.')
    arg.setDefaultValue('hpxml.xml')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('software_info_program_used', false)
    arg.setDisplayName('Software Info: Program Used')
    arg.setDescription('The name of the software program used.')
    arg.setDefaultValue('BuildResidentialHPXML measure')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('software_info_program_version', false)
    arg.setDisplayName('Software Info: Program Version')
    arg.setDescription('The version of the software program used.')
    arg.setDefaultValue(Version::OS_HPXML_Version)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('simulation_control_timestep', false)
    arg.setDisplayName('Simulation Control: Timestep')
    arg.setUnits('min')
    arg.setDescription('Value must be a divisor of 60.')
    arg.setDefaultValue(60)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('simulation_control_run_period', false)
    arg.setDisplayName('Simulation Control: Run Period')
    arg.setDescription("Enter a date range like 'Mar 1 - May 31'. Defaults to the entire year.")
    arg.setDefaultValue('Jan 1 - Dec 31')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('location_zip_code', false)
    arg.setDisplayName('Location: Zip Code')
    arg.setDescription('Zip code of the home address. Either this or the EnergyPlus Weather (EPW) Filepath input below must be provided.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('location_epw_filepath', false)
    arg.setDisplayName('Location: EnergyPlus Weather (EPW) Filepath')
    arg.setDescription('Path to the EPW file. Either this or the Zip Code input above must be provided.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('location_site_type', choices[:location_site_type], false)
    arg.setDisplayName('Location: Site Type')
    arg.setDescription("The terrain/shielding of the home, for the infiltration model. Defaults to 'Suburban, Normal' for single-family detached and manufactured home and 'Suburban, Well-Shielded' for single-family attached and apartment units.")
    arg.setDefaultValue('Default')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('location_soil_type', choices[:location_soil_type], false)
    arg.setDisplayName('Location: Soil Type')
    arg.setDescription('The soil and moisture type.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('building_year_built', false)
    arg.setDisplayName('Building Construction: Year Built')
    arg.setDescription('The year the building was built.')
    arg.setDefaultValue(Date.today.year)
    args << arg

    unit_type_choices = OpenStudio::StringVector.new
    unit_type_choices << HPXML::ResidentialTypeSFD
    unit_type_choices << HPXML::ResidentialTypeSFA
    unit_type_choices << HPXML::ResidentialTypeApartment
    unit_type_choices << HPXML::ResidentialTypeManufactured

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('building_unit_multiplier', false)
    arg.setDisplayName('Building Construction: Unit Multiplier')
    arg.setDescription('The number of similar dwelling units. EnergyPlus simulation results will be multiplied this value.')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('geometry_unit_type', unit_type_choices, true)
    arg.setDisplayName('Geometry: Unit Type')
    arg.setDescription("The type of dwelling unit. Use #{HPXML::ResidentialTypeSFA} for a dwelling unit with 1 or more stories, attached units to one or both sides, and no units above/below. Use #{HPXML::ResidentialTypeApartment} for a dwelling unit with 1 story, attached units to one, two, or three sides, and units above and/or below.")
    arg.setDefaultValue(HPXML::ResidentialTypeSFD)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('geometry_attached_walls', choices[:geometry_attached_walls], false)
    arg.setDisplayName('Geometry: Unit Attached Walls')
    arg.setDescription("The location of the attached walls if a dwelling unit of type '#{HPXML::ResidentialTypeSFA}' or '#{HPXML::ResidentialTypeApartment}'.")
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('geometry_unit_num_floors_above_grade', true)
    arg.setDisplayName('Geometry: Unit Number of Floors Above Grade')
    arg.setUnits('#')
    arg.setDescription("The number of floors above grade in the unit. Attic type #{HPXML::AtticTypeConditioned} is included. Assumed to be 1 for #{HPXML::ResidentialTypeApartment}s.")
    arg.setDefaultValue(2)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('geometry_unit_cfa', true)
    arg.setDisplayName('Geometry: Unit Conditioned Floor Area')
    arg.setUnits('ft2')
    arg.setDescription("The total floor area of the unit's conditioned space (including any conditioned basement floor area).")
    arg.setDefaultValue(2000.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('geometry_unit_aspect_ratio', true)
    arg.setDisplayName('Geometry: Unit Aspect Ratio')
    arg.setUnits('Frac')
    arg.setDescription('The ratio of front/back wall length to left/right wall length for the unit, excluding any protruding garage wall area.')
    arg.setDefaultValue(2.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('geometry_unit_orientation', true)
    arg.setDisplayName('Geometry: Unit Orientation')
    arg.setUnits('degrees')
    arg.setDescription("The unit's orientation is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).")
    arg.setDefaultValue(180.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('geometry_unit_num_bedrooms', true)
    arg.setDisplayName('Geometry: Unit Number of Bedrooms')
    arg.setUnits('#')
    arg.setDescription('The number of bedrooms in the unit.')
    arg.setDefaultValue(3)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('geometry_unit_num_bathrooms', false)
    arg.setDisplayName('Geometry: Unit Number of Bathrooms')
    arg.setUnits('#')
    arg.setDescription('The number of bathrooms in the unit. If not provided, defaults to NumberofBedrooms/2 + 0.5.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('geometry_unit_num_occupants', false)
    arg.setDisplayName('Geometry: Unit Number of Occupants')
    arg.setUnits('#')
    arg.setDescription('The number of occupants in the unit. If not provided, an *asset* calculation is performed assuming standard occupancy, in which various end use defaults (e.g., plug loads, appliances, and hot water usage) are calculated based on Number of Bedrooms and Conditioned Floor Area per ANSI/RESNET/ICC 301. If provided, an *operational* calculation is instead performed in which the end use defaults to reflect real-world data (where possible).')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('geometry_building_num_units', false)
    arg.setDisplayName('Geometry: Building Number of Units')
    arg.setUnits('#')
    arg.setDescription("The number of units in the building. Required for #{HPXML::ResidentialTypeSFA} and #{HPXML::ResidentialTypeApartment}s.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('geometry_average_ceiling_height', true)
    arg.setDisplayName('Geometry: Average Ceiling Height')
    arg.setUnits('ft')
    arg.setDescription('Average distance from the floor to the ceiling.')
    arg.setDefaultValue(8.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('geometry_garage_type', choices[:geometry_garage_type], false)
    arg.setDisplayName('Geometry: Attached Garage')
    arg.setDescription("The type of attached garage. Only applies to #{HPXML::ResidentialTypeSFD} units.")
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('geometry_foundation_type', choices[:geometry_foundation_type], true)
    arg.setDisplayName('Geometry: Foundation Type')
    arg.setDescription('The foundation type of the building. Garages are assumed to be over slab-on-grade.')
    arg.setDefaultValue('Crawlspace, Vented')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('geometry_attic_type', choices[:geometry_attic_type], true)
    arg.setDisplayName('Geometry: Attic Type')
    arg.setDescription('The attic/roof type of the building.')
    arg.setDefaultValue('Attic, Vented, Gable')
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

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('geometry_roof_pitch', roof_pitch_choices, true)
    arg.setDisplayName('Geometry: Roof Pitch')
    arg.setDescription('The roof pitch of the attic. Ignored if the building has a flat roof.')
    arg.setDefaultValue('6:12')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('geometry_eaves', choices[:geometry_eaves], false)
    arg.setDisplayName('Geometry: Eaves')
    arg.setDescription('The type of eaves extending from the roof.')
    arg.setDefaultValue('2 ft')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('geometry_neighbor_buildings', choices[:geometry_neighbor_buildings], false)
    arg.setDisplayName('Geometry: Neighbor Buildings')
    arg.setDescription('The presence and geometry of neighboring buildings, for shading purposes.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_floor_over_foundation', choices[:enclosure_floor_over_foundation], false)
    arg.setDisplayName('Enclosure: Floor Over Foundation')
    arg.setDescription('The type and insulation level of the floor over the foundation (e.g., crawlspace or basement).')
    arg.setDefaultValue('Wood Frame, Uninsulated')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_floor_over_garage', choices[:enclosure_floor_over_garage], false)
    arg.setDisplayName('Enclosure: Floor Over Garage')
    arg.setDescription('The type and insulation level of the floor over the garage.')
    arg.setDefaultValue('Wood Frame, Uninsulated')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_foundation_wall', choices[:enclosure_foundation_wall], false)
    arg.setDisplayName('Enclosure: Foundation Wall')
    arg.setDescription('The type and insulation level of the foundation walls.')
    arg.setDefaultValue('Solid Concrete, Uninsulated')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_rim_joist', choices[:enclosure_rim_joist], false)
    arg.setDisplayName('Enclosure: Rim Joists')
    arg.setDescription('The type and insulation level of the rim joists.')
    arg.setDefaultValue('Uninsulated')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_slab', choices[:enclosure_slab], false)
    arg.setDisplayName('Enclosure: Slab')
    arg.setDescription('The type and insulation level of the slab. Applies to slab-on-grade as well as basement/crawlspace foundations. Under Slab insulation is placed horizontally from the edge of the slab inward. Perimeter insulation is placed vertically from the top of the slab downward. Whole Slab insulation is placed horizontally below the entire slab area.')
    arg.setDefaultValue('Uninsulated')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_ceiling', choices[:enclosure_ceiling], true)
    arg.setDisplayName('Enclosure: Ceiling')
    arg.setDescription('The type and insulation level of the ceiling (attic floor).')
    arg.setDefaultValue('R-30')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_roof', choices[:enclosure_roof], true)
    arg.setDisplayName('Enclosure: Roof')
    arg.setDescription('The type and insulation level of the roof.')
    arg.setDefaultValue('Uninsulated')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_roof_material', choices[:enclosure_roof_material], false)
    arg.setDisplayName('Enclosure: Roof Material')
    arg.setDescription('The material type and color of the roof.')
    arg.setDefaultValue('Asphalt/Fiberglass Shingles, Medium')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_radiant_barrier', choices[:enclosure_radiant_barrier], false)
    arg.setDisplayName('Enclosure: Radiant Barrier')
    arg.setDescription('The type of radiant barrier in the attic.')
    arg.setDefaultValue(choices[:enclosure_radiant_barrier][0])
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_wall', choices[:enclosure_wall], true)
    arg.setDisplayName('Enclosure: Walls')
    arg.setDescription('The type and insulation level of the walls.')
    arg.setDefaultValue('Wood Stud, R-13')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_wall_continuous_insulation', choices[:enclosure_wall_continuous_insulation], false)
    arg.setDisplayName('Enclosure: Wall Continuous Insulation')
    arg.setDescription('The insulation level of the wall continuous insulation. The R-value of the continuous insulation will be ignored if a wall option with an IECC U-factor is selected.')
    arg.setDefaultValue('Uninsulated')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_wall_siding', choices[:enclosure_wall_siding], false)
    arg.setDisplayName('Enclosure: Wall Siding')
    arg.setDescription('The type, color, and insulation level of the wall siding. The R-value of the siding will be ignored if a wall option with an IECC U-factor is selected.')
    arg.setDefaultValue('Wood, Medium')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_window', choices[:enclosure_window], true)
    arg.setDisplayName('Enclosure: Windows')
    arg.setDescription('The type of windows.')
    arg.setDefaultValue('Double, Clear, Metal, Air')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('enclosure_window_area_or_wwr_front', true)
    arg.setDisplayName('Enclosure: Window Front Area or WWR')
    arg.setUnits('ft2 or frac')
    arg.setDescription("The amount of window area on the unit's front facade. Enter a fraction to specify a Window-to-Wall Ratio instead. If the front wall is adiabatic, the value will be ignored.")
    arg.setDefaultValue(0.15)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('enclosure_window_area_or_wwr_back', true)
    arg.setDisplayName('Enclosure: Window Back Area or WWR')
    arg.setUnits('ft2 or frac')
    arg.setDescription("The amount of window area on the unit's back facade. Enter a fraction to specify a Window-to-Wall Ratio instead. If the back wall is adiabatic, the value will be ignored.")
    arg.setDefaultValue(0.15)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('enclosure_window_area_or_wwr_left', true)
    arg.setDisplayName('Enclosure: Window Left Area or WWR')
    arg.setUnits('ft2 or frac')
    arg.setDescription("The amount of window area on the unit's left facade (when viewed from the front). Enter a fraction to specify a Window-to-Wall Ratio instead. If the left wall is adiabatic, the value will be ignored.")
    arg.setDefaultValue(0.15)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('enclosure_window_area_or_wwr_right', true)
    arg.setDisplayName('Enclosure: Window Right Area or WWR')
    arg.setUnits('ft2 or frac')
    arg.setDescription("The amount of window area on the unit's right facade (when viewed from the front). Enter a fraction to specify a Window-to-Wall Ratio instead. If the right wall is adiabatic, the value will be ignored.")
    arg.setDefaultValue(0.15)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_window_natural_ventilation', choices[:enclosure_window_natural_ventilation], false)
    arg.setDisplayName('Enclosure: Window Natural Ventilation')
    arg.setDescription('The amount of natural ventilation from occupants opening operable windows when outdoor conditions are favorable.')
    arg.setDefaultValue('67% Operable Windows, 3 Days/Week')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_window_interior_shading', choices[:enclosure_window_interior_shading], false)
    arg.setDisplayName('Enclosure: Window Interior Shading')
    arg.setDescription('The type of window interior shading. If shading coefficients are selected, note they indicate the reduction in solar gain (e.g., 0.7 indicates 30% reduction).')
    arg.setDefaultValue('Curtains, Light')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_window_exterior_shading', choices[:enclosure_window_exterior_shading], false)
    arg.setDisplayName('Enclosure: Window Exterior Shading')
    arg.setDescription('The type of window exterior shading. If shading coefficients are selected, note they indicate the reduction in solar gain (e.g., 0.7 indicates 30% reduction).')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_window_insect_screens', choices[:enclosure_window_insect_screens], false)
    arg.setDisplayName('Enclosure: Window Insect Screens')
    arg.setDescription('The type of window insect screens.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_window_storm', choices[:enclosure_window_storm], false)
    arg.setDisplayName('Enclosure: Window Storm')
    arg.setDescription('The type of storm window.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_overhangs', choices[:enclosure_overhangs], false)
    arg.setDisplayName('Enclosure: Window Overhangs')
    arg.setDescription('The type of window overhangs.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_skylight', choices[:enclosure_skylight], false)
    arg.setDisplayName('Enclosure: Skylights')
    arg.setDescription('The type of skylights.')
    arg.setDefaultValue('Single, Clear, Metal')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('enclosure_skylight_area_front', false)
    arg.setDisplayName('Enclosure: Skylight Front Area')
    arg.setUnits('ft2')
    arg.setDescription("The amount of skylight area on the unit's front-facing roof.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('enclosure_skylight_area_back', false)
    arg.setDisplayName('Enclosure: Skylight Back Area')
    arg.setUnits('ft2')
    arg.setDescription("The amount of skylight area on the unit's back-facing roof.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('enclosure_skylight_area_left', false)
    arg.setDisplayName('Enclosure: Skylight Left Area')
    arg.setUnits('ft2')
    arg.setDescription("The amount of skylight area on the unit's left-facing roof (when viewed from the front).")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('enclosure_skylight_area_right', false)
    arg.setDisplayName('Enclosure: Skylight Right Area')
    arg.setUnits('ft2')
    arg.setDescription("The amount of skylight area on the unit's right-facing roof (when viewed from the front).")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_door', choices[:enclosure_door], false)
    arg.setDisplayName('Enclosure: Doors')
    arg.setDescription('The type of doors.')
    arg.setDefaultValue('Solid Wood, R-2')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('enclosure_door_area', true)
    arg.setDisplayName('Enclosure: Doors Area')
    arg.setUnits('ft2')
    arg.setDescription('The area of the opaque door(s).')
    arg.setDefaultValue(20.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('enclosure_air_leakage', choices[:enclosure_air_leakage], false)
    arg.setDisplayName('Enclosure: Air Leakage')
    arg.setDescription("The amount of air leakage coming from outside. If a qualitative leakiness description (e.g., 'Average') is selected, the Year Built of the home is also required.")
    arg.setDefaultValue('Average')
    args << arg

    heating_system_fuel_choices = OpenStudio::StringVector.new
    heating_system_fuel_choices << HPXML::FuelTypeElectricity
    heating_system_fuel_choices << HPXML::FuelTypeNaturalGas
    heating_system_fuel_choices << HPXML::FuelTypeOil
    heating_system_fuel_choices << HPXML::FuelTypePropane
    heating_system_fuel_choices << HPXML::FuelTypeWoodCord
    heating_system_fuel_choices << HPXML::FuelTypeWoodPellets
    heating_system_fuel_choices << HPXML::FuelTypeCoal

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_heating_system', choices[:hvac_heating_system], true)
    arg.setDisplayName('HVAC: Heating System')
    arg.setDescription("The type and efficiency of the heating system. Use 'None' if there is no heating system or if there is a heat pump serving a heating load.")
    arg.setDefaultValue('Fuel Furnace, 78% AFUE')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_heating_system_fuel', heating_system_fuel_choices, true)
    arg.setDisplayName('HVAC: Heating System Fuel Type')
    arg.setDescription("The fuel type of the heating system. Ignored for #{HPXML::HVACTypeElectricResistance}.")
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_heating_system_capacity', choices[:hvac_heating_system_capacity], false)
    arg.setDisplayName('HVAC: Heating System Capacity')
    arg.setDescription('The output capacity of the heating system.')
    arg.setDefaultValue('Autosize')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('hvac_heating_system_fraction_heat_load_served', true)
    arg.setDisplayName('HVAC: Heating System Fraction Heat Load Served')
    arg.setDescription('The heating load served by the heating system.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_cooling_system', choices[:hvac_cooling_system], true)
    arg.setDisplayName('HVAC: Cooling System')
    arg.setDescription("The type and efficiency of the cooling system. Use 'None' if there is no cooling system or if there is a heat pump serving a cooling load.")
    arg.setDefaultValue('Central AC, SEER 13')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_cooling_system_capacity', choices[:hvac_cooling_system_capacity], false)
    arg.setDisplayName('HVAC: Cooling System Capacity')
    arg.setDescription('The output capacity of the cooling system.')
    arg.setDefaultValue('Autosize')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('hvac_cooling_system_fraction_cool_load_served', true)
    arg.setDisplayName('HVAC: Cooling System Fraction Cool Load Served')
    arg.setDescription('The cooling load served by the cooling system.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_cooling_system_integrated_heating_capacity', choices[:hvac_cooling_system_integrated_heating_capacity], false)
    arg.setDisplayName('HVAC: Cooling System Integrated Heating Capacity')
    arg.setDescription("The output capacity of the cooling system's integrated heating system. Only used for #{HPXML::HVACTypePTAC} and #{HPXML::HVACTypeRoomAirConditioner} systems with integrated heating.")
    arg.setDefaultValue('Autosize')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('hvac_cooling_system_integrated_heating_fraction_heat_load_served', false)
    arg.setDisplayName('HVAC: Cooling System Integrated Heating Fraction Heat Load Served')
    arg.setDescription("The heating load served by the heating system integrated into cooling system. Only used for #{HPXML::HVACTypePTAC} and #{HPXML::HVACTypeRoomAirConditioner} systems with integrated heating.")
    arg.setUnits('Frac')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_heat_pump', choices[:hvac_heat_pump], true)
    arg.setDisplayName('HVAC: Heat Pump')
    arg.setDescription('The type and efficiency of the heat pump.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_heat_pump_capacity', choices[:hvac_heat_pump_capacity], false)
    arg.setDisplayName('HVAC: Heat Pump Capacity')
    arg.setDescription('The output capacity of the heat pump.')
    arg.setDefaultValue('Autosize')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('hvac_heat_pump_fraction_heat_load_served', true)
    arg.setDisplayName('HVAC: Heat Pump Fraction Heat Load Served')
    arg.setDescription('The heating load served by the heat pump.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('hvac_heat_pump_fraction_cool_load_served', true)
    arg.setDisplayName('HVAC: Heat Pump Fraction Cool Load Served')
    arg.setDescription('The cooling load served by the heat pump.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_heat_pump_temperatures', choices[:hvac_heat_pump_temperatures], false)
    arg.setDisplayName('HVAC: Heat Pump Temperatures')
    arg.setDescription('Specifies the minimum compressor temperature and/or maximum HP backup temperature. If both are the same, a binary switchover temperature is used.')
    arg.setDefaultValue('Default')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_heat_pump_backup', choices[:hvac_heat_pump_backup], true)
    arg.setDisplayName('HVAC: Heat Pump Backup Type')
    arg.setDescription("The type and efficiency of the heat pump backup. Use 'None' if there is no backup heating. If Backup Type is Separate Heating System, Heating System 2 is used to specify the backup.")
    arg.setDefaultValue('Integrated, Electricity, 100% Efficiency')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_heat_pump_backup_capacity', choices[:hvac_heat_pump_backup_capacity], false)
    arg.setDisplayName('HVAC: Heat Pump Backup Capacity')
    arg.setDescription('The output capacity of the heat pump backup if there is integrated backup heating.')
    arg.setDefaultValue('Autosize')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_geothermal_loop', choices[:hvac_geothermal_loop], false)
    arg.setDisplayName('HVAC: Geothermal Loop')
    arg.setDescription("The geothermal loop configuration if there's a #{HPXML::HVACTypeHeatPumpGroundToAir} heat pump.")
    arg.setDefaultValue('Default')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_heating_system_2', choices[:hvac_heating_system_2], false)
    arg.setDisplayName('HVAC: Heating System 2')
    arg.setDescription("The type and efficiency of the second heating system. If a heat pump is specified and the backup type is '#{HPXML::HeatPumpBackupTypeSeparate}', this heating system represents the '#{HPXML::HeatPumpBackupTypeSeparate}' backup heating.")
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_heating_system_2_fuel', heating_system_fuel_choices, true)
    arg.setDisplayName('HVAC: Heating System 2 Fuel Type')
    arg.setDescription("The fuel type of the second heating system. Ignored for #{HPXML::HVACTypeElectricResistance}.")
    arg.setDefaultValue(HPXML::FuelTypeElectricity)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_heating_system_2_capacity', choices[:hvac_heating_system_2_capacity], false)
    arg.setDisplayName('HVAC: Heating System 2 Capacity')
    arg.setDescription('The output capacity of the second heating system.')
    arg.setDefaultValue('Autosize')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('hvac_heating_system_2_fraction_heat_load_served', true)
    arg.setDisplayName('HVAC: Heating System 2 Fraction Heat Load Served')
    arg.setDescription('The heat load served fraction of the second heating system. Ignored if this heating system serves as a backup system for a heat pump.')
    arg.setUnits('Frac')
    arg.setDefaultValue(0.25)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hvac_control_heating_weekday_setpoint', false)
    arg.setDisplayName('HVAC Control: Heating Weekday Setpoint Schedule')
    arg.setDescription('Specify the constant or 24-hour comma-separated weekday heating setpoint schedule. Required unless a detailed CSV schedule is provided.')
    arg.setUnits('F')
    arg.setDefaultValue(68)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hvac_control_heating_weekend_setpoint', false)
    arg.setDisplayName('HVAC Control: Heating Weekend Setpoint Schedule')
    arg.setDescription('Specify the constant or 24-hour comma-separated weekend heating setpoint schedule. Required unless a detailed CSV schedule is provided.')
    arg.setUnits('F')
    arg.setDefaultValue(68)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hvac_control_cooling_weekday_setpoint', false)
    arg.setDisplayName('HVAC Control: Cooling Weekday Setpoint Schedule')
    arg.setDescription('Specify the constant or 24-hour comma-separated weekday cooling setpoint schedule. Required unless a detailed CSV schedule is provided.')
    arg.setUnits('F')
    arg.setDefaultValue(78)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hvac_control_cooling_weekend_setpoint', false)
    arg.setDisplayName('HVAC Control: Cooling Weekend Setpoint Schedule')
    arg.setDescription('Specify the constant or 24-hour comma-separated weekend cooling setpoint schedule. Required unless a detailed CSV schedule is provided.')
    arg.setUnits('F')
    arg.setDefaultValue(78)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hvac_control_heating_season_period', false)
    arg.setDisplayName('HVAC Control: Heating Season Period')
    arg.setDescription("Enter a date range like 'Nov 1 - Jun 30'. Defaults to year-round heating availability.")
    arg.setDefaultValue('Jan 1 - Dec 31')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hvac_control_cooling_season_period', false)
    arg.setDisplayName('HVAC Control: Cooling Season Period')
    arg.setDescription("Enter a date range like 'Jun 1 - Oct 31'. Defaults to year-round cooling availability.")
    arg.setDefaultValue('Jan 1 - Dec 31')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('hvac_blower_fan_watts_per_cfm', false)
    arg.setDisplayName('HVAC Blower: Fan Efficiency')
    arg.setDescription("The blower fan efficiency at maximum fan speed. Applies only to split (not packaged) systems (i.e., applies to ducted systems as well as ductless #{HPXML::HVACTypeHeatPumpMiniSplit} systems). If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#hpxml-heating-systems'>HPXML Heating Systems</a>, <a href='#{docs_base_url}#hpxml-cooling-systems'>HPXML Cooling Systems</a>, <a href='#{docs_base_url}#hpxml-heat-pumps'>HPXML Heat Pumps</a>) is used.")
    arg.setUnits('W/CFM')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_installation_defects', choices[:hvac_installation_defects], false)
    arg.setDisplayName('HVAC Installation Defects')
    arg.setDescription('Specifies whether the HVAC system has airflow and/or refrigerant charge installation defects. Applies to central furnaces and central/mini-split ACs and HPs.')
    arg.setDefaultValue('None')
    args << arg

    duct_location_choices = OpenStudio::StringVector.new
    duct_location_choices << HPXML::LocationConditionedSpace
    duct_location_choices << HPXML::LocationBasementConditioned
    duct_location_choices << HPXML::LocationBasementUnconditioned
    duct_location_choices << HPXML::LocationCrawlspace
    duct_location_choices << HPXML::LocationCrawlspaceVented
    duct_location_choices << HPXML::LocationCrawlspaceUnvented
    duct_location_choices << HPXML::LocationCrawlspaceConditioned
    duct_location_choices << HPXML::LocationAttic
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
    duct_location_choices << HPXML::LocationManufacturedHomeBelly

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_ducts', choices[:hvac_ducts], true)
    arg.setDisplayName('HVAC Ducts')
    arg.setDescription('The supply duct leakage to outside, nominal insulation r-value, buried insulation level, surface area, and fraction rectangular.')
    arg.setDefaultValue('15% Leakage to Outside, Uninsulated')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_ducts_supply_location', duct_location_choices, false)
    arg.setDisplayName('HVAC Ducts: Supply Location')
    arg.setDescription('The location of the supply ducts. If not provided, defaults based on the foundation/attic type and presence of garage.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('hvac_ducts_supply_surface_area_fraction', false)
    arg.setDisplayName('HVAC Ducts: Supply Area Fraction')
    arg.setDescription('The fraction of supply ducts surface area in the given location. If the fraction is less than 1, the remaining duct area is assumed to be in conditioned space. If not provided, defaults to 0.75 if number of conditioned floors above-grade is greater than 1, otherwise 1.')
    arg.setUnits('frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('hvac_ducts_supply_leakage_fraction', false)
    arg.setDisplayName('HVAC Ducts: Supply Leakage Fraction')
    arg.setDescription('The fraction of duct leakage associated with the supply ducts; the remainder is associated with the return ducts.')
    arg.setUnits('frac')
    arg.setDefaultValue(0.5)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_ducts_return_location', duct_location_choices, false)
    arg.setDisplayName('HVAC Ducts: Return Location')
    arg.setDescription('The location of the return ducts. If not provided, defaults based on the foundation/attic type and presence of garage.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('hvac_ducts_return_surface_area_fraction', false)
    arg.setDisplayName('HVAC Ducts: Return Area Fraction')
    arg.setDescription('The fraction of return ducts surface area in the given location. If the fraction is less than 1, the remaining duct area is assumed to be in conditioned space. If not provided, defaults to 0.75 if number of conditioned floors above-grade is greater than 1, otherwise 1.')
    arg.setUnits('frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('hvac_ducts_number_of_return_registers', false)
    arg.setDisplayName('HVAC Ducts: Number of Return Registers')
    arg.setDescription('The number of return registers of the ducts. Only used to calculate default return duct surface area. If not provided, defaults to one return register per conditioned floor.')
    arg.setUnits('#')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('ventilation_mechanical', choices[:ventilation_mechanical], false)
    arg.setDisplayName('Ventilation Fans: Mechanical Ventilation')
    arg.setDescription('The type of mechanical ventilation system used for whole building ventilation.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('ventilation_kitchen', choices[:ventilation_kitchen], false)
    arg.setDisplayName('Ventilation Fans: Kitchen Exhaust Fan')
    arg.setDescription('The type of kitchen exhaust fan used for local ventilation.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('ventilation_bathroom', choices[:ventilation_bathroom], false)
    arg.setDisplayName('Ventilation Fans: Bathroom Exhaust Fans')
    arg.setDescription('The type of bathroom exhaust fans used for local ventilation.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('ventilation_whole_house_fan', choices[:ventilation_whole_house_fan], false)
    arg.setDisplayName('Ventilation Fans: Whole House Fan')
    arg.setDescription('The type of whole house fans used for seasonal cooling load reduction.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('dhw_water_heater', choices[:dhw_water_heater], true)
    arg.setDisplayName('DHW: Water Heater')
    arg.setDescription('The type and efficiency of the water heater.')
    arg.setDefaultValue('Electricity, Tank, UEF=0.92')
    args << arg

    water_heater_location_choices = OpenStudio::StringVector.new
    water_heater_location_choices << HPXML::LocationConditionedSpace
    water_heater_location_choices << HPXML::LocationBasementConditioned
    water_heater_location_choices << HPXML::LocationBasementUnconditioned
    water_heater_location_choices << HPXML::LocationGarage
    water_heater_location_choices << HPXML::LocationAttic
    water_heater_location_choices << HPXML::LocationAtticVented
    water_heater_location_choices << HPXML::LocationAtticUnvented
    water_heater_location_choices << HPXML::LocationCrawlspace
    water_heater_location_choices << HPXML::LocationCrawlspaceVented
    water_heater_location_choices << HPXML::LocationCrawlspaceUnvented
    water_heater_location_choices << HPXML::LocationCrawlspaceConditioned
    water_heater_location_choices << HPXML::LocationOtherExterior
    water_heater_location_choices << HPXML::LocationOtherHousingUnit
    water_heater_location_choices << HPXML::LocationOtherHeatedSpace
    water_heater_location_choices << HPXML::LocationOtherMultifamilyBufferSpace
    water_heater_location_choices << HPXML::LocationOtherNonFreezingSpace

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('dhw_water_heater_location', water_heater_location_choices, false)
    arg.setDisplayName('DHW: Water Heater Location')
    arg.setDescription('The location of water heater. If not provided, defaults based on the foundation type and presence of garage.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('dhw_water_heater_jacket', choices[:dhw_water_heater_jacket], false)
    arg.setDisplayName('DHW: Water Heater Jacket Insulation')
    arg.setDescription("The type of water heater jacket/blanket insulation. Doesn't apply to tankless systems or space-heating boilers.")
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('dhw_water_heater_uses_desuperheater', false)
    arg.setDisplayName('DHW: Water Heater Uses Desuperheater')
    arg.setDescription("Whether the water heater uses a desuperheater. Requires that the dwelling unit has a #{HPXML::HVACTypeHeatPumpAirToAir}, #{HPXML::HVACTypeHeatPumpMiniSplit}, or #{HPXML::HVACTypeHeatPumpGroundToAir} heat pump or a #{HPXML::HVACTypeCentralAirConditioner} or #{HPXML::HVACTypeMiniSplitAirConditioner} air conditioner.")
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('dhw_distribution', choices[:dhw_distribution], false)
    arg.setDisplayName('DHW: Hot Water Distribution')
    arg.setDescription('The type of domestic hot water distrubtion.')
    arg.setDefaultValue('Uninsulated, Standard')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('dhw_fixtures', choices[:dhw_fixtures], false)
    arg.setDisplayName('DHW: Hot Water Fixtures')
    arg.setDescription('The type of domestic hot water fixtures.')
    arg.setDefaultValue('Standard')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('dhw_drain_water_heat_recovery', choices[:dhw_drain_water_heat_recovery], false)
    arg.setDisplayName('DHW: Drain Water Heat Reovery')
    arg.setDescription('The type of drain water heater recovery.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('dhw_water_fixtures_usage_multiplier', false)
    arg.setDisplayName('DHW: Hot Water Fixtures Usage Multiplier')
    arg.setDescription('Multiplier on the hot water usage that can reflect, e.g., high/low usage occupants.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('dhw_solar_thermal', choices[:dhw_solar_thermal], false)
    arg.setDisplayName('DHW: Solar Thermal')
    arg.setDescription('The size and type of solar thermal system for domestic hot water.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('dhw_solar_thermal_collector_azimuth', false)
    arg.setDisplayName('DHW: Solar Thermal Collector Azimuth')
    arg.setUnits('degrees')
    arg.setDescription('The azimuth of the solar thermal system collectors. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).')
    arg.setDefaultValue(180)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('dhw_solar_thermal_collector_tilt', false)
    arg.setDisplayName('DHW: Solar Thermal Collector Tilt')
    arg.setUnits('degrees')
    arg.setDescription('The tilt of the solar thermal system collectors. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.')
    arg.setDefaultValue('RoofPitch')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('pv_system', choices[:pv_system], false)
    arg.setDisplayName('PV System')
    arg.setDescription('The size and type of PV system.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('pv_system_array_azimuth', false)
    arg.setDisplayName('PV System: Array Azimuth')
    arg.setUnits('degrees')
    arg.setDescription('The azimuth of the PV system array. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).')
    arg.setDefaultValue(180)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('pv_system_array_tilt', false)
    arg.setDisplayName('PV System: Array Tilt')
    arg.setUnits('degrees')
    arg.setDescription('The tilt of the PV system array. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.')
    arg.setDefaultValue('RoofPitch')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('pv_system_2', choices[:pv_system_2], false)
    arg.setDisplayName('PV System 2')
    arg.setDescription('The size and type of the second PV system.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('pv_system_2_array_azimuth', false)
    arg.setDisplayName('PV System 2: Array Azimuth')
    arg.setUnits('degrees')
    arg.setDescription('The azimuth of the second PV system array. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).')
    arg.setDefaultValue(180)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('pv_system_2_array_tilt', false)
    arg.setDisplayName('PV System 2: Array Tilt')
    arg.setUnits('degrees')
    arg.setDescription('The tilt of the second PV system array. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.')
    arg.setDefaultValue('RoofPitch')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('electric_panel_service_feeders_load_calculation_types', false)
    arg.setDisplayName('Electric Panel: Service/Feeders Load Calculation Types')
    arg.setDescription("Types of electric panel service/feeder load calculations. These calculations are experimental research features. Possible types are: #{HPXML::ElectricPanelLoadCalculationType2023ExistingDwellingLoadBased}, #{HPXML::ElectricPanelLoadCalculationType2023ExistingDwellingMeterBased}. If multiple types, use a comma-separated list. If not provided, no electric panel loads are calculated.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_baseline_peak_power', false)
    arg.setDisplayName('Electric Panel: Baseline Peak Power')
    arg.setDescription("Specifies the baseline peak power. Used for #{HPXML::ElectricPanelLoadCalculationType2023ExistingDwellingMeterBased}. If not provided, assumed to be zero.")
    arg.setUnits('W')
    args << arg

    electric_panel_voltage_choices = OpenStudio::StringVector.new
    electric_panel_voltage_choices << HPXML::ElectricPanelVoltage120
    electric_panel_voltage_choices << HPXML::ElectricPanelVoltage240

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('electric_panel_service_voltage', electric_panel_voltage_choices, false)
    arg.setDisplayName('Electric Panel: Service Voltage')
    arg.setDescription("The service voltage of the electric panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#hpxml-electric-panels'>HPXML Electric Panels</a>) is used.")
    arg.setUnits('V')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_service_max_current_rating', false)
    arg.setDisplayName('Electric Panel: Service Max Current Rating')
    arg.setDescription("The service max current rating of the electric panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#hpxml-electric-panels'>HPXML Electric Panels</a>) is used.")
    arg.setUnits('A')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('electric_panel_breaker_spaces_headroom', false)
    arg.setDisplayName('Electric Panel: Breaker Spaces Headroom')
    arg.setDescription("The unoccupied number of breaker spaces on the electric panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#hpxml-electric-panels'>HPXML Electric Panels</a>) is used.")
    arg.setUnits('#')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('electric_panel_breaker_spaces_rated_total', false)
    arg.setDisplayName('Electric Panel: Breaker Spaces Rated Total')
    arg.setDescription("The rated total number of breaker spaces on the electric panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#hpxml-electric-panels'>HPXML Electric Panels</a>) is used.")
    arg.setUnits('#')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_heating_system_power_rating', false)
    arg.setDisplayName('Electric Panel: Heating System Power Rating')
    arg.setDescription("Specifies the panel load heating system power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_heating_system_new_load', false)
    arg.setDisplayName('Electric Panel: Heating System New Load')
    arg.setDescription("Whether the heating system is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_cooling_system_power_rating', false)
    arg.setDisplayName('Electric Panel: Cooling System Power Rating')
    arg.setDescription("Specifies the panel load cooling system power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_cooling_system_new_load', false)
    arg.setDisplayName('Electric Panel: Cooling System New Load')
    arg.setDescription("Whether the cooling system is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_heat_pump_power_rating', false)
    arg.setDisplayName('Electric Panel: Heat Pump Power Rating')
    arg.setDescription("Specifies the panel load heat pump power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_heat_pump_new_load', false)
    arg.setDisplayName('Electric Panel: Heat Pump New Load')
    arg.setDescription("Whether the heat pump is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_heating_system_2_power_rating', false)
    arg.setDisplayName('Electric Panel: Heating System 2 Power Rating')
    arg.setDescription("Specifies the panel load second heating system power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_heating_system_2_new_load', false)
    arg.setDisplayName('Electric Panel: Heating System 2 New Load')
    arg.setDescription("Whether the second heating system is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_mech_vent_power_rating', false)
    arg.setDisplayName('Electric Panel: Mechanical Ventilation Power Rating')
    arg.setDescription("Specifies the panel load mechanical ventilation power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_mech_vent_fan_new_load', false)
    arg.setDisplayName('Electric Panel: Mechanical Ventilation New Load')
    arg.setDescription("Whether the mechanical ventilation is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_whole_house_fan_power_rating', false)
    arg.setDisplayName('Electric Panel: Whole House Fan Power Rating')
    arg.setDescription("Specifies the panel load whole house fan power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_whole_house_fan_new_load', false)
    arg.setDisplayName('Electric Panel: Whole House Fan New Load')
    arg.setDescription("Whether the whole house fan is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_kitchen_fans_power_rating', false)
    arg.setDisplayName('Electric Panel: Kitchen Fans Power Rating')
    arg.setDescription("Specifies the panel load kitchen fans power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_kitchen_fans_new_load', false)
    arg.setDisplayName('Electric Panel: Kitchen Fans New Load')
    arg.setDescription("Whether the kitchen fans is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_bathroom_fans_power_rating', false)
    arg.setDisplayName('Electric Panel: Bathroom Fans Power Rating')
    arg.setDescription("Specifies the panel load bathroom fans power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_bathroom_fans_new_load', false)
    arg.setDisplayName('Electric Panel: Bathroom Fans New Load')
    arg.setDescription("Whether the bathroom fans is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_electric_water_heater_power_rating', false)
    arg.setDisplayName('Electric Panel: Electric Water Heater Power Rating')
    arg.setDescription("Specifies the panel load water heater power rating. Only applies to electric water heater. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('electric_panel_load_electric_water_heater_voltage', electric_panel_voltage_choices, false)
    arg.setDisplayName('Electric Panel: Electric Water Heater Voltage')
    arg.setDescription("Specifies the panel load water heater voltage. Only applies to electric water heater. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('V')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_electric_water_heater_new_load', false)
    arg.setDisplayName('Electric Panel: Electric Water Heater New Load')
    arg.setDescription("Whether the water heater is a new panel load addition to an existing service panel. Only applies to electric water heater. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_electric_clothes_dryer_power_rating', false)
    arg.setDisplayName('Electric Panel: Electric Clothes Dryer Power Rating')
    arg.setDescription("Specifies the panel load clothes dryer power rating. Only applies to electric clothes dryer. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('electric_panel_load_electric_clothes_dryer_voltage', electric_panel_voltage_choices, false)
    arg.setDisplayName('Electric Panel: Electric Clothes Dryer Voltage')
    arg.setDescription("Specifies the panel load clothes dryer voltage. Only applies to electric clothes dryer. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('V')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_electric_clothes_dryer_new_load', false)
    arg.setDisplayName('Electric Panel: Electric Clothes Dryer New Load')
    arg.setDescription("Whether the clothes dryer is a new panel load addition to an existing service panel. Only applies to electric clothes dryer. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_dishwasher_power_rating', false)
    arg.setDisplayName('Electric Panel: Dishwasher Power Rating')
    arg.setDescription("Specifies the panel load dishwasher power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_dishwasher_new_load', false)
    arg.setDisplayName('Electric Panel: Dishwasher New Load')
    arg.setDescription("Whether the dishwasher is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_electric_cooking_range_power_rating', false)
    arg.setDisplayName('Electric Panel: Electric Cooking Range/Oven Power Rating')
    arg.setDescription("Specifies the panel load cooking range/oven power rating. Only applies to electric cooking range/oven. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('electric_panel_load_electric_cooking_range_voltage', electric_panel_voltage_choices, false)
    arg.setDisplayName('Electric Panel: Electric Cooking Range/Oven Voltage')
    arg.setDescription("Specifies the panel load cooking range/oven voltage. Only applies to electric cooking range/oven. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('V')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_electric_cooking_range_new_load', false)
    arg.setDisplayName('Electric Panel: Electric Cooking Range/Oven New Load')
    arg.setDescription("Whether the cooking range is a new panel load addition to an existing service panel. Only applies to electric cooking range/oven. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_misc_plug_loads_well_pump_power_rating', false)
    arg.setDisplayName('Electric Panel: Misc Plug Loads Well Pump Power Rating')
    arg.setDescription("Specifies the panel load well pump power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_misc_plug_loads_well_pump_new_load', false)
    arg.setDisplayName('Electric Panel: Misc Plug Loads Well Pump New Load')
    arg.setDescription("Whether the well pump is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_misc_plug_loads_vehicle_power_rating', false)
    arg.setDisplayName('Electric Panel: Misc Plug Loads Vehicle Power Rating')
    arg.setDescription("Specifies the panel load electric vehicle power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('electric_panel_load_misc_plug_loads_vehicle_voltage', electric_panel_voltage_choices, false)
    arg.setDisplayName('Electric Panel: Misc Plug Loads Vehicle Voltage')
    arg.setDescription("Specifies the panel load electric vehicle voltage. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('V')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_misc_plug_loads_vehicle_new_load', false)
    arg.setDisplayName('Electric Panel: Misc Plug Loads Vehicle New Load')
    arg.setDescription("Whether the electric vehicle is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_pool_pump_power_rating', false)
    arg.setDisplayName('Electric Panel: Pool Pump Power Rating')
    arg.setDescription("Specifies the panel load pool pump power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_pool_pump_new_load', false)
    arg.setDisplayName('Electric Panel: Pool Pump New Load')
    arg.setDescription("Whether the panel load pool pump is an addition. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setDescription("Whether the pool pump is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_electric_pool_heater_power_rating', false)
    arg.setDisplayName('Electric Panel: Electric Pool Heater Power Rating')
    arg.setDescription("Specifies the panel load pool heater power rating. Only applies to electric pool heater. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_electric_pool_heater_new_load', false)
    arg.setDisplayName('Electric Panel: Electric Pool Heater New Load')
    arg.setDescription("Whether the pool heater is a new panel load addition to an existing service panel. Only applies to electric pool heater. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_permanent_spa_pump_power_rating', false)
    arg.setDisplayName('Electric Panel: Permanent Spa Pump Power Rating')
    arg.setDescription("Specifies the panel load permanent spa pump power rating. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_permanent_spa_pump_new_load', false)
    arg.setDisplayName('Electric Panel: Permanent Spa Pump New Load')
    arg.setDescription("Whether the spa pump is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_electric_permanent_spa_heater_power_rating', false)
    arg.setDisplayName('Electric Panel: Electric Permanent Spa Heater Power Rating')
    arg.setDescription("Specifies the panel load permanent spa heater power rating. Only applies to electric permanent spa heater. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_electric_permanent_spa_heater_new_load', false)
    arg.setDisplayName('Electric Panel: Electric Permanent Spa Heater New Load')
    arg.setDescription("Whether the spa heater is a new panel load addition to an existing service panel. Only applies to electric permanent spa heater. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_panel_load_other_power_rating', false)
    arg.setDisplayName('Electric Panel: Other Power Rating')
    arg.setDescription("Specifies the panel load other power rating. This represents the total of all other electric loads that are fastened in place, permanently connected, or located on a specific circuit. For example, garbage disposal, built-in microwave. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    arg.setUnits('W')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('electric_panel_load_other_new_load', false)
    arg.setDisplayName('Electric Panel: Other New Load')
    arg.setDescription("Whether the other load is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='#{docs_base_url}#service-feeders'>Service Feeders</a>) is used.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('battery', choices[:battery], false)
    arg.setDisplayName('Battery')
    arg.setDescription('The size and type of battery storage.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('electric_vehicle', choices[:electric_vehicle], false)
    arg.setDisplayName('Electric Vehicle')
    arg.setDescription('The type of battery electric vehicle.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_vehicle_miles_driven_per_year', false)
    arg.setDisplayName('Electric Vehicle: Miles Driven Per Year')
    arg.setDescription('The annual miles the vehicle is driven. If not provided, defaults to 10900.')
    arg.setUnits('miles')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('electric_vehicle_charger', choices[:electric_vehicle_charger], false)
    arg.setDisplayName('Electric Vehicle: Charger')
    arg.setDescription('The type and usage of electric vehicle charger.')
    arg.setDefaultValue('None')
    args << arg

    appliance_location_choices = OpenStudio::StringVector.new
    appliance_location_choices << HPXML::LocationConditionedSpace
    appliance_location_choices << HPXML::LocationBasementConditioned
    appliance_location_choices << HPXML::LocationBasementUnconditioned
    appliance_location_choices << HPXML::LocationGarage
    appliance_location_choices << HPXML::LocationOtherHousingUnit
    appliance_location_choices << HPXML::LocationOtherHeatedSpace
    appliance_location_choices << HPXML::LocationOtherMultifamilyBufferSpace
    appliance_location_choices << HPXML::LocationOtherNonFreezingSpace

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_clothes_washer', choices[:appliance_clothes_washer], false)
    arg.setDisplayName('Appliances: Clothes Washer')
    arg.setDescription('The type of clothes washer.')
    arg.setDefaultValue('Standard, 2008-2017')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_clothes_washer_location', appliance_location_choices, false)
    arg.setDisplayName('Appliances: Clothes Washer Location')
    arg.setDescription('The space type for the clothes washer location. If not provided, defaults to conditioned space.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('appliance_clothes_washer_usage_multiplier', false)
    arg.setDisplayName('Appliances: Clothes Washer Usage Multiplier')
    arg.setDescription('Multiplier on the clothes washer energy and hot water usage that can reflect, e.g., high/low usage occupants.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_clothes_dryer', choices[:appliance_clothes_dryer], false)
    arg.setDisplayName('Appliances: Clothes Dryer')
    arg.setDescription('The type of clothes dryer.')
    arg.setDefaultValue('Electricity, Standard')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_clothes_dryer_location', appliance_location_choices, false)
    arg.setDisplayName('Appliances: Clothes Dryer Location')
    arg.setDescription('The space type for the clothes dryer location. If not provided, defaults to conditioned space.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('appliance_clothes_dryer_usage_multiplier', false)
    arg.setDisplayName('Appliances: Clothes Dryer Usage Multiplier')
    arg.setDescription('Multiplier on the clothes dryer energy usage that can reflect, e.g., high/low usage occupants.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_dishwasher', choices[:appliance_dishwasher], false)
    arg.setDisplayName('Appliances: Dishwasher')
    arg.setDescription('The type of dishwasher.')
    arg.setDefaultValue('Federal Minimum, Standard')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_dishwasher_location', appliance_location_choices, false)
    arg.setDisplayName('Appliances: Dishwasher Location')
    arg.setDescription('The space type for the dishwasher location. If not provided, defaults to conditioned space.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('appliance_dishwasher_usage_multiplier', false)
    arg.setDisplayName('Appliances: Dishwasher Usage Multiplier')
    arg.setDescription('Multiplier on the dishwasher energy usage that can reflect, e.g., high/low usage occupants.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_refrigerator', choices[:appliance_refrigerator], false)
    arg.setDisplayName('Appliances: Refrigerator')
    arg.setDescription('The type of refrigerator.')
    arg.setDefaultValue('434 kWh/yr')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_refrigerator_location', appliance_location_choices, false)
    arg.setDisplayName('Appliances: Refrigerator Location')
    arg.setDescription('The space type for the refrigerator location. If not provided, defaults to conditioned space.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('appliance_refrigerator_usage_multiplier', false)
    arg.setDisplayName('Appliances: Refrigerator Usage Multiplier')
    arg.setDescription('Multiplier on the refrigerator energy usage that can reflect, e.g., high/low usage occupants.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_extra_refrigerator', choices[:appliance_extra_refrigerator], false)
    arg.setDisplayName('Appliances: Extra Refrigerator')
    arg.setDescription('The type of extra refrigerator.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_extra_refrigerator_location', appliance_location_choices, false)
    arg.setDisplayName('Appliances: Extra Refrigerator Location')
    arg.setDescription('The space type for the extra refrigerator location. If not provided, defaults based on the foundation type and presence of garage.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('appliance_extra_refrigerator_usage_multiplier', false)
    arg.setDisplayName('Appliances: Extra Refrigerator Usage Multiplier')
    arg.setDescription('Multiplier on the extra refrigerator energy usage that can reflect, e.g., high/low usage occupants.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_freezer', choices[:appliance_freezer], false)
    arg.setDisplayName('Appliances: Freezer')
    arg.setDescription('The type of freezer.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_freezer_location', appliance_location_choices, false)
    arg.setDisplayName('Appliances: Freezer Location')
    arg.setDescription('The space type for the freezer location. If not provided, defaults based on the foundation type and presence of garage.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('appliance_freezer_usage_multiplier', false)
    arg.setDisplayName('Appliances: Freezer Usage Multiplier')
    arg.setDescription('Multiplier on the freezer energy usage that can reflect, e.g., high/low usage occupants.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_cooking_range_oven', choices[:appliance_cooking_range_oven], false)
    arg.setDisplayName('Appliances: Cooking Range/Oven')
    arg.setDescription('The type of cooking range/oven.')
    arg.setDefaultValue('Electricity, Standard, Non-Convection Oven')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_cooking_range_oven_location', appliance_location_choices, false)
    arg.setDisplayName('Appliances: Cooking Range/Oven Location')
    arg.setDescription('The space type for the cooking range/oven location. If not provided, defaults to conditioned space.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('appliance_cooking_range_oven_usage_multiplier', false)
    arg.setDisplayName('Appliances: Cooking Range/Oven Usage Multiplier')
    arg.setDescription('Multiplier on the cooking range/oven energy usage that can reflect, e.g., high/low usage occupants.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('appliance_dehumidifier', choices[:appliance_dehumidifier], false)
    arg.setDisplayName('Appliances: Dehumidifier')
    arg.setDescription('The type of dehumidifier.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('appliance_dehumidifier_rh_setpoint', false)
    arg.setDisplayName('Appliances: Dehumidifier Relative Humidity Setpoint')
    arg.setDescription("The dehumidifier's relative humidity setpoint.")
    arg.setUnits('Frac')
    arg.setDefaultValue(0.5)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('lighting', choices[:lighting], true)
    arg.setDisplayName('Lighting')
    arg.setDescription('The type of lighting.')
    arg.setDefaultValue('10% CFL')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('lighting_interior_usage_multiplier', false)
    arg.setDisplayName('Lighting: Interior Usage Multiplier')
    arg.setDescription('Multiplier on the lighting energy usage (interior) that can reflect, e.g., high/low usage occupants.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('lighting_exterior_usage_multiplier', false)
    arg.setDisplayName('Lighting: Exterior Usage Multiplier')
    arg.setDescription('Multiplier on the lighting energy usage (exterior) that can reflect, e.g., high/low usage occupants.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('lighting_garage_usage_multiplier', false)
    arg.setDisplayName('Lighting: Garage Usage Multiplier')
    arg.setDescription('Multiplier on the lighting energy usage (garage) that can reflect, e.g., high/low usage occupants.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('ceiling_fans', choices[:ceiling_fans], false)
    arg.setDisplayName('Ceiling Fans')
    arg.setDescription('The type of ceiling fans.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('misc_television', choices[:misc_television], false)
    arg.setDisplayName('Misc: Television')
    arg.setDescription('The amount of television usage, relative to the national average.')
    arg.setDefaultValue('100%')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('misc_plug_loads', choices[:misc_plug_loads], false)
    arg.setDisplayName('Misc: Plug Loads')
    arg.setDescription('The amount of additional plug load usage, relative to the national average.')
    arg.setDefaultValue('100%')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('misc_well_pump', choices[:misc_well_pump], false)
    arg.setDisplayName('Misc: Well Pump')
    arg.setDescription('The amount of well pump usage, relative to the national average.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('misc_electric_vehicle_charging', choices[:misc_electric_vehicle_charging], false)
    arg.setDisplayName('Misc: Electric Vehicle Charging')
    arg.setDescription('The amount of EV charging usage, relative to the national average. Only use this if a detailed EV & EV charger were not otherwise specified.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('misc_grill', choices[:misc_grill], false)
    arg.setDisplayName('Misc: Gas Grill')
    arg.setDescription('The amount of outdoor gas grill usage, relative to the national average.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('misc_gas_lighting', choices[:misc_gas_lighting], false)
    arg.setDisplayName('Misc: Gas Lighting')
    arg.setDescription('The amount of gas lighting usage, relative to the national average.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('misc_fireplace', choices[:misc_fireplace], false)
    arg.setDisplayName('Misc: Fireplace')
    arg.setDescription('The amount of fireplace usage, relative to the national average. Fireplaces can also be specified as heating systems that meet a portion of the heating load.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('misc_pool', choices[:misc_pool], false)
    arg.setDisplayName('Misc: Pool')
    arg.setDescription('The type of pool (pump & heater).')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('misc_permanent_spa', choices[:misc_permanent_spa], false)
    arg.setDisplayName('Misc: Permanent Spa')
    arg.setDescription('The type of permanent spa (pump & heater).')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('schedules_filepaths', false)
    arg.setDisplayName('Schedules: CSV File Paths')
    arg.setDescription('Absolute/relative paths of csv files containing user-specified detailed schedules. If multiple files, use a comma-separated list.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('schedules_unavailable_period_types', false)
    arg.setDisplayName('Schedules: Unavailable Period Types')
    arg.setDescription("Specifies the unavailable period types. Possible types are column names defined in unavailable_periods.csv: #{Schedule.unavailable_period_types.join(', ')}. If multiple periods, use a comma-separated list.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('schedules_unavailable_period_dates', false)
    arg.setDisplayName('Schedules: Unavailable Period Dates')
    arg.setDescription('Specifies the unavailable period date ranges. Enter a date range like "Dec 15 - Jan 15". Optionally, can enter hour of the day like "Dec 15 2 - Jan 15 20" (start hour can be 0 through 23 and end hour can be 1 through 24). If multiple periods, use a comma-separated list.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('schedules_unavailable_period_window_natvent_availabilities', false)
    arg.setDisplayName('Schedules: Unavailable Period Window Natural Ventilation Availabilities')
    arg.setDescription("The availability of the natural ventilation schedule during unavailable periods. Valid choices are: #{[HPXML::ScheduleRegular, HPXML::ScheduleAvailable, HPXML::ScheduleUnavailable].join(', ')}. If multiple periods, use a comma-separated list. If not provided, defaults to '#{HPXML::ScheduleRegular}'.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('advanced_feature', choices[:advanced_feature], false)
    arg.setDisplayName('Advanced Feature')
    arg.setDescription('Select an advanced research feature to use in the model, if desired.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('advanced_feature_2', choices[:advanced_feature_2], false)
    arg.setDisplayName('Advanced Feature 2')
    arg.setDescription('Select a second advanced research feature to use in the model, if desired.')
    arg.setDefaultValue('None')
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

    HPXML::fossil_fuels.each do |fossil_fuel|
      underscore_case = OpenStudio::toUnderscoreCase(fossil_fuel)
      all_caps_case = fossil_fuel.split(' ').map(&:capitalize).join(' ')
      cap_case = fossil_fuel.capitalize

      arg = OpenStudio::Measure::OSArgument.makeStringArgument("emissions_#{underscore_case}_values", false)
      arg.setDisplayName("Emissions: #{all_caps_case} Values")
      arg.setDescription("#{cap_case} emissions factors values, specified as an annual factor. If multiple scenarios, use a comma-separated list.")
      args << arg
    end

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('utility_bill_scenario', choices[:utility_bill_scenario], false)
    arg.setDisplayName('Utility Bill Secnario')
    arg.setDescription('The type of utility bill calculations to perform.')
    arg.setDefaultValue('Default (EIA Average Rates)')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('utility_bill_scenario_2', choices[:utility_bill_scenario_2], false)
    arg.setDisplayName('Utility Bill Secnario 2')
    arg.setDescription('The second type of utility bill calculations to perform, if desired.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('utility_bill_scenario_3', choices[:utility_bill_scenario_3], false)
    arg.setDisplayName('Utility Bill Secnario 3')
    arg.setDescription('The third type of utility bill calculations to perform, if desired.')
    arg.setDefaultValue('None')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('additional_properties', false)
    arg.setDisplayName('Additional Properties')
    arg.setDescription("Additional properties specified as key-value pairs (i.e., key=value). If multiple additional properties, use a |-separated list. For example, 'LowIncome=false|Remodeled|Description=2-story home in Denver'. These properties will be stored in the HPXML file under /HPXML/SoftwareInfo/extension/AdditionalProperties.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('whole_sfa_or_mf_building_sim', false)
    arg.setDisplayName('Whole SFA/MF Building Simulation?')
    arg.setDescription('If the HPXML file represents a single family-attached/multifamily building with multiple dwelling units defined, specifies whether to run the HPXML file as a single whole building model.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('whole_sfa_or_mf_existing_hpxml_path', false)
    arg.setDisplayName('Whole SFA/MF Building Simulation: Existing HPXML File Path')
    arg.setDescription('Absolute/relative path of the existing HPXML file. If not provided, a new HPXML file with one Building element is created. If provided, a new Building element will be appended to this HPXML file (e.g., to create a multifamily HPXML file describing multiple dwelling units).')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('combine_like_surfaces', false)
    arg.setDisplayName('Combine like surfaces?')
    arg.setDescription('If true, combines like surfaces to simplify the HPXML file generated.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('apply_defaults', false)
    arg.setDisplayName('Apply Default Values?')
    arg.setDescription('If true, applies OS-HPXML default values to the HPXML output file. Setting to true will also force validation of the HPXML output file before applying OS-HPXML default values.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('apply_validation', false)
    arg.setDisplayName('Apply Validation?')
    arg.setDescription('If true, validates the HPXML output file. Set to false for faster performance. Note that validation is not needed if the HPXML file will be validated downstream (e.g., via the HPXMLtoOpenStudio measure).')
    arg.setDefaultValue(false)
    args << arg

    return args
  end

  # Define what happens when the measure is run.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param user_arguments [OpenStudio::Measure::OSArgumentMap] OpenStudio measure arguments
  # @return [Boolean] true if successful
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    Model.reset(runner, model)

    Version.check_openstudio_version()

    args = runner.getArgumentValues(arguments(model), user_arguments)

    # Get all option properties for all TSV files in the resources/options/ dir.
    # Properties will be like :<tsv_name>_<column_name>
    # For example, :air_leakage_leakiness_description
    Dir["#{File.dirname(__FILE__)}/resources/options/*.tsv"].each do |tsv_filepath|
      tsv_filename = File.basename(tsv_filepath)
      arg_name = File.basename(tsv_filename, File.extname(tsv_filename)).to_sym
      get_option_properties(args, tsv_filename, args[arg_name])
    end

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

    if args[:location_epw_filepath].nil? && args[:location_zip_code].nil?
      runner.registerError('Either EPW filepath or site zip code is required.')
      return false
    end

    # Create HPXML file
    hpxml_path = args[:hpxml_path]
    unless (Pathname.new hpxml_path).absolute?
      hpxml_path = File.expand_path(hpxml_path)
    end

    # Existing HPXML File
    existing_hpxml_path = args[:whole_sfa_or_mf_existing_hpxml_path]
    if not existing_hpxml_path.nil?
      unless (Pathname.new existing_hpxml_path).absolute?
        existing_hpxml_path = File.expand_path(existing_hpxml_path)
      end
    end

    hpxml_doc = create(runner, model, args, hpxml_path, existing_hpxml_path)
    if not hpxml_doc
      runner.registerError('Unsuccessful creation of HPXML file.')
      return false
    end

    runner.registerInfo("Wrote file: #{hpxml_path}")

    # Uncomment for debugging purposes
    # File.write(hpxml_path.gsub('.xml', '.osm'), model.to_s)

    return true
  end

  # Issue warnings or errors for certain combinations of argument values.
  #
  # @param args [Hash] Map of :argument_name => value
  # @return [Array<String>, Array<String>] arrays of warnings and errors
  def validate_arguments(args)
    warnings = argument_warnings(args)
    errors = argument_errors(args)

    return warnings, errors
  end

  # Collection of warning checks on combinations of user argument values.
  # Warnings are registered to the runner, but do not exit the measure.
  #
  # @param args [Hash] Map of :argument_name => value
  # @return [Array<String>] array of warnings
  def argument_warnings(args)
    warnings = []

    warning = [HPXML::FoundationTypeSlab, HPXML::FoundationTypeAboveApartment].include?(args[:geometry_foundation_type_type]) && (args[:geometry_foundation_type_height] > 0)
    warnings << "Foundation type of '#{args[:geometry_foundation_type_type]}' cannot have a non-zero height. Assuming height is zero." if warning

    warning = (args[:geometry_foundation_type_type] == HPXML::FoundationTypeSlab) && (args[:geometry_foundation_type_height_above_grade] > 0)
    warnings << 'Specified a slab foundation type with a non-zero height above grade.' if warning

    warning = [HPXML::FoundationTypeCrawlspaceVented, HPXML::FoundationTypeCrawlspaceUnvented, HPXML::FoundationTypeBasementUnconditioned].include?(args[:geometry_foundation_type_type]) && ((args[:enclosure_foundation_wall_insulation_nominal_r_value].to_f > 0) || !args[:enclosure_foundation_wall_assembly_r_value].nil?) && !args[:enclosure_floor_over_foundation].include?('Uninsulated')
    warnings << 'Home with unconditioned basement/crawlspace foundation type has both foundation wall insulation and floor insulation.' if warning

    warning = [HPXML::AtticTypeVented, HPXML::AtticTypeUnvented].include?(args[:geometry_attic_type_attic_type]) && !args[:enclosure_ceiling].include?('Uninsulated') && !args[:enclosure_roof].include?('Uninsulated')
    warnings << 'Home with unconditioned attic type has both ceiling insulation and roof insulation.' if warning

    warning = (args[:geometry_foundation_type_type] == HPXML::FoundationTypeBasementConditioned) && !args[:enclosure_floor_over_foundation].include?('Uninsulated')
    warnings << 'Home with conditioned basement has floor insulation.' if warning

    warning = (args[:geometry_attic_type_attic_type] == HPXML::AtticTypeConditioned) && !args[:enclosure_ceiling].include?('Uninsulated')
    warnings << 'Home with conditioned attic has ceiling insulation.' if warning

    return warnings
  end

  # Collection of error checks on combinations of user argument values.
  # Errors are registered to the runner, and exit the measure.
  #
  # @param args [Hash] Map of :argument_name => value
  # @return [Array<String>] array of errors
  def argument_errors(args)
    errors = []

    error = (args[:hvac_heating_system] != 'None') && (args[:hvac_heat_pump] != 'None') && (args[:hvac_heating_system_fraction_heat_load_served] > 0) && (args[:hvac_heat_pump_fraction_heat_load_served] > 0)
    errors << 'Multiple central heating systems are not currently supported.' if error

    error = (args[:hvac_cooling_system] != 'None') && (args[:hvac_heat_pump] != 'None') && (args[:hvac_cooling_system_fraction_cool_load_served] > 0) && (args[:hvac_heat_pump_fraction_cool_load_served] > 0)
    errors << 'Multiple central cooling systems are not currently supported.' if error

    error = ![HPXML::FoundationTypeSlab, HPXML::FoundationTypeAboveApartment].include?(args[:geometry_foundation_type_type]) && (args[:geometry_foundation_type_height] == 0)
    errors << "Foundation type of '#{args[:geometry_foundation_type_type]}' cannot have a height of zero." if error

    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeApartment) && ([HPXML::FoundationTypeBasementConditioned, HPXML::FoundationTypeCrawlspaceConditioned].include? args[:geometry_foundation_type_type])
    errors << 'Conditioned basement/crawlspace foundation type for apartment units is not currently supported.' if error

    error = (args[:hvac_heating_system] == 'None') && (args[:hvac_heat_pump] == 'None') && (args[:hvac_heating_system_2] != 'None')
    errors << 'A second heating system was specified without a primary heating system.' if error

    if ((args[:hvac_heat_pump_backup_type] == HPXML::HeatPumpBackupTypeSeparate) && (args[:hvac_heating_system_2_type] == HPXML::HVACTypeFurnace)) # separate ducted backup
      if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpGroundToAir].include?(args[:hvac_heat_pump_type]) ||
         ((args[:hvac_heat_pump_type] == HPXML::HVACTypeHeatPumpMiniSplit) && args[:hvac_heat_pump_is_ducted]) # ducted heat pump
        errors << "A ducted heat pump with '#{HPXML::HeatPumpBackupTypeSeparate}' ducted backup is not supported."
      end
    end

    error = [HPXML::ResidentialTypeSFA, HPXML::ResidentialTypeApartment].include?(args[:geometry_unit_type]) && args[:geometry_building_num_units].nil?
    errors << 'Did not specify the number of units in the building for single-family attached or apartment units.' if error

    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeApartment) && (args[:geometry_unit_num_floors_above_grade] > 1)
    errors << 'Apartment units can only have one above-grade floor.' if error

    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeSFD) && (args[:geometry_attached_walls_front_wall_is_adiabatic] || args[:geometry_attached_walls_back_wall_is_adiabatic] || args[:geometry_attached_walls_left_wall_is_adiabatic] || args[:geometry_attached_walls_right_wall_is_adiabatic] || (args[:geometry_attic_type_attic_type] == HPXML::AtticTypeBelowApartment) || (args[:geometry_foundation_type_type] == HPXML::FoundationTypeAboveApartment))
    errors << 'No adiabatic surfaces can be applied to single-family detached homes.' if error

    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeApartment) && (args[:geometry_attic_type_attic_type] == HPXML::AtticTypeConditioned)
    errors << 'Conditioned attic type for apartment units is not currently supported.' if error

    error = (args[:geometry_unit_num_floors_above_grade] == 1 && args[:geometry_attic_type_attic_type] == HPXML::AtticTypeConditioned)
    errors << 'Units with a conditioned attic must have at least two above-grade floors.' if error

    error = [HPXML::WaterHeaterTypeCombiStorage, HPXML::WaterHeaterTypeCombiTankless].include?(args[:dhw_water_heater_type]) && !args[:hvac_heating_system_type].include?(HPXML::HVACTypeBoiler)
    errors << 'Must specify a boiler when modeling an indirect water heater type.' if error

    error = [HPXML::ResidentialTypeSFD].include?(args[:geometry_unit_type]) && args[:hvac_heating_system_type].include?('Shared')
    errors << 'Specified a shared system for a single-family detached unit.' if error

    error = args[:geometry_foundation_type_rim_joist_height].to_f > 0 && args[:enclosure_rim_joist_assembly_r_value].nil?
    errors << 'Specified a rim joist height but no rim joist assembly R-value.' if error

    schedules_unavailable_period_args_initialized = [!args[:schedules_unavailable_period_types].nil?,
                                                     !args[:schedules_unavailable_period_dates].nil?]
    error = (schedules_unavailable_period_args_initialized.uniq.size != 1)
    errors << 'Did not specify all required unavailable period arguments.' if error

    if schedules_unavailable_period_args_initialized.uniq.size == 1 && schedules_unavailable_period_args_initialized.uniq[0]
      schedules_unavailable_period_lengths = [args[:schedules_unavailable_period_types].count(','),
                                              args[:schedules_unavailable_period_dates].count(',')]

      if !args[:schedules_unavailable_period_window_natvent_availabilities].nil?
        schedules_unavailable_period_lengths.concat([args[:schedules_unavailable_period_window_natvent_availabilities].count(',')])
      end

      error = (schedules_unavailable_period_lengths.uniq.size != 1)
      errors << 'One or more unavailable period arguments does not have enough comma-separated elements specified.' if error
    end

    if !args[:schedules_unavailable_period_window_natvent_availabilities].nil?
      natvent_availabilities = args[:schedules_unavailable_period_window_natvent_availabilities].split(',').map(&:strip)
      natvent_availabilities.each do |natvent_availability|
        next if natvent_availability.empty?

        error = ![HPXML::ScheduleRegular, HPXML::ScheduleAvailable, HPXML::ScheduleUnavailable].include?(natvent_availability)
        errors << "Window natural ventilation availability '#{natvent_availability}' during an unavailable period is invalid." if error
      end
    end

    if [HPXML::HVACTypeCentralAirConditioner, HPXML::HVACTypeMiniSplitAirConditioner].include? args[:cooling_system_type]
      compressor_type = args[:cooling_system_compressor_type]
    elsif [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpMiniSplit].include? args[:heat_pump_type]
      compressor_type = args[:heat_pump_compressor_type]
    end

    hvac_perf_data_heating_args_initialized = [!args[:hvac_perf_data_heating_outdoor_temperatures].nil?,
                                               !args[:hvac_perf_data_heating_nom_speed_capacities].nil?,
                                               !args[:hvac_perf_data_heating_nom_speed_cops].nil?]
    if [HPXML::HVACCompressorTypeTwoStage, HPXML::HVACCompressorTypeVariableSpeed].include? compressor_type
      hvac_perf_data_heating_args_initialized << !args[:hvac_perf_data_heating_min_speed_capacities].nil?
      hvac_perf_data_heating_args_initialized << !args[:hvac_perf_data_heating_min_speed_cops].nil?
    end
    if [HPXML::HVACCompressorTypeVariableSpeed].include? compressor_type
      hvac_perf_data_heating_args_initialized << !args[:hvac_perf_data_heating_max_speed_capacities].nil?
      hvac_perf_data_heating_args_initialized << !args[:hvac_perf_data_heating_max_speed_cops].nil?
    end
    error = (hvac_perf_data_heating_args_initialized.uniq.size != 1)
    errors << 'Did not specify all required heating detailed performance data arguments.' if error

    hvac_perf_data_cooling_args_initialized = [!args[:hvac_perf_data_cooling_outdoor_temperatures].nil?,
                                               !args[:hvac_perf_data_cooling_nom_speed_capacities].nil?,
                                               !args[:hvac_perf_data_cooling_nom_speed_cops].nil?]
    if [HPXML::HVACCompressorTypeTwoStage, HPXML::HVACCompressorTypeVariableSpeed].include? compressor_type
      hvac_perf_data_cooling_args_initialized << !args[:hvac_perf_data_cooling_min_speed_capacities].nil?
      hvac_perf_data_cooling_args_initialized << !args[:hvac_perf_data_cooling_min_speed_cops].nil?
    end
    if [HPXML::HVACCompressorTypeVariableSpeed].include? compressor_type
      hvac_perf_data_cooling_args_initialized << !args[:hvac_perf_data_cooling_max_speed_capacities].nil?
      hvac_perf_data_cooling_args_initialized << !args[:hvac_perf_data_cooling_max_speed_cops].nil?
    end
    error = (hvac_perf_data_cooling_args_initialized.uniq.size != 1)
    errors << 'Did not specify all required cooling detailed performance data arguments.' if error

    emissions_args_initialized = [!args[:emissions_scenario_names].nil?,
                                  !args[:emissions_types].nil?,
                                  !args[:emissions_electricity_units].nil?,
                                  !args[:emissions_electricity_values_or_filepaths].nil?]
    error = (emissions_args_initialized.uniq.size != 1)
    errors << 'Did not specify all required emissions arguments.' if error

    HPXML::fossil_fuels.each do |fossil_fuel|
      underscore_case = OpenStudio::toUnderscoreCase(fossil_fuel)

      if !args["emissions_#{underscore_case}_values".to_sym].nil?
        error = args[:emissions_fossil_fuel_units].nil?
        errors << "Did not specify fossil fuel emissions units for #{fossil_fuel} emissions values." if error
      end
    end

    if emissions_args_initialized.uniq.size == 1 && emissions_args_initialized.uniq[0]
      emissions_scenario_lengths = [args[:emissions_scenario_names].count(','),
                                    args[:emissions_types].count(','),
                                    args[:emissions_electricity_units].count(','),
                                    args[:emissions_electricity_values_or_filepaths].count(',')]

      emissions_scenario_lengths.concat([args[:emissions_electricity_number_of_header_rows].count(',')]) unless args[:emissions_electricity_number_of_header_rows].nil?
      emissions_scenario_lengths.concat([args[:emissions_electricity_column_numbers].count(',')]) unless args[:emissions_electricity_column_numbers].nil?

      HPXML::fossil_fuels.each do |fossil_fuel|
        underscore_case = OpenStudio::toUnderscoreCase(fossil_fuel)

        emissions_scenario_lengths.concat([args["emissions_#{underscore_case}_values".to_sym].count(',')]) unless args["emissions_#{underscore_case}_values".to_sym].nil?
      end

      error = (emissions_scenario_lengths.uniq.size != 1)
      errors << 'One or more emissions arguments does not have enough comma-separated elements specified.' if error
    end

    error = (args[:geometry_unit_num_floors_above_grade] > 6)
    errors << 'Number of above-grade floors must be six or less.' if error

    error = (args[:geometry_garage_type_protrusion] < 0) || (args[:geometry_garage_type_protrusion] > 1)
    errors << 'Garage protrusion fraction must be between zero and one.' if error

    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeSFA) && (args[:geometry_foundation_type_type] == HPXML::FoundationTypeAboveApartment)
    errors << 'Single-family attached units cannot be above another unit.' if error

    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeSFA) && (args[:geometry_attic_type_attic_type] == HPXML::AtticTypeBelowApartment)
    errors << 'Single-family attached units cannot be below another unit.' if error

    error = (args[:geometry_garage_type_protrusion] > 0) && (args[:geometry_attic_type_roof_type] == Constants::RoofTypeHip) && (args[:geometry_garage_type_width] * args[:geometry_garage_type_depth] > 0)
    errors << 'Cannot handle protruding garage and hip roof.' if error

    error = (args[:geometry_garage_type_protrusion] > 0) && (args[:geometry_unit_aspect_ratio] < 1) && (args[:geometry_garage_type_width] * args[:geometry_garage_type_depth] > 0) && (args[:geometry_attic_type_roof_type] == Constants::RoofTypeGable)
    errors << 'Cannot handle protruding garage and attic ridge running from front to back.' if error

    error = (args[:geometry_foundation_type_type] == HPXML::FoundationTypeAmbient) && (args[:geometry_garage_type_width] * args[:geometry_garage_type_depth] > 0)
    errors << 'Cannot handle garages with an ambient foundation type.' if error

    return errors
  end

  # Create the closed-form geometry, and then call individual set_xxx methods
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param args [Hash] Map of :argument_name => value
  # @param hpxml_path [String] Path to the created HPXML file
  # @param existing_hpxml_path [String] Path to the existing HPXML file
  # @return [Oga::XML::Element] Root XML element of the updated HPXML document
  def create(runner, model, args, hpxml_path, existing_hpxml_path)
    weather = get_weather_if_needed(runner, args)
    return false if !weather.nil? && !weather

    success = create_geometry_envelope(runner, model, args)
    return false if not success

    @surface_ids = {}

    # Sorting of objects to make the measure deterministic
    sorted_surfaces = model.getSurfaces.sort_by { |s| s.additionalProperties.getFeatureAsInteger('Index').get }
    sorted_subsurfaces = model.getSubSurfaces.sort_by { |ss| ss.additionalProperties.getFeatureAsInteger('Index').get }

    hpxml = HPXML.new(hpxml_path: existing_hpxml_path)

    if not set_header(runner, hpxml, args)
      return false
    end

    hpxml_bldg = add_building(hpxml, args)
    set_site(hpxml_bldg, args)
    set_neighbor_buildings(hpxml_bldg, args)
    set_building_occupancy(hpxml_bldg, args)
    set_building_construction(hpxml_bldg, args)
    set_building_header(hpxml_bldg, args)
    set_climate_and_risk_zones(hpxml_bldg, args)
    set_air_infiltration_measurements(hpxml_bldg, args)
    set_roofs(hpxml_bldg, args, sorted_surfaces)
    set_rim_joists(hpxml_bldg, model, args, sorted_surfaces)
    set_walls(hpxml_bldg, model, args, sorted_surfaces)
    set_foundation_walls(hpxml_bldg, model, args, sorted_surfaces)
    set_floors(hpxml_bldg, args, sorted_surfaces)
    set_slabs(hpxml_bldg, model, args, sorted_surfaces)
    set_windows(hpxml_bldg, model, args, sorted_subsurfaces)
    set_skylights(hpxml_bldg, args, sorted_subsurfaces)
    set_doors(hpxml_bldg, model, args, sorted_subsurfaces)
    set_attics(hpxml_bldg, args)
    set_foundations(hpxml_bldg, args)
    set_heating_systems(hpxml_bldg, args)
    set_cooling_systems(hpxml_bldg, args)
    set_heat_pumps(hpxml_bldg, args)
    set_geothermal_loop(hpxml_bldg, args)
    set_secondary_heating_systems(hpxml_bldg, args)
    set_hvac_distribution(hpxml_bldg, args)
    set_hvac_blower(hpxml_bldg, args)
    set_hvac_control(hpxml, hpxml_bldg, args, weather)
    set_ventilation_fans(hpxml_bldg, args)
    set_water_heating_systems(hpxml_bldg, args)
    set_hot_water_distribution(hpxml_bldg, args)
    set_water_fixtures(hpxml_bldg, args)
    set_solar_thermal(hpxml_bldg, args, weather)
    set_pv_systems(hpxml_bldg, args, weather)
    set_battery(hpxml_bldg, args)
    set_vehicle(hpxml_bldg, args)
    set_lighting(hpxml_bldg, args)
    set_dehumidifier(hpxml_bldg, args)
    set_clothes_washer(hpxml_bldg, args)
    set_clothes_dryer(hpxml_bldg, args)
    set_dishwasher(hpxml_bldg, args)
    set_refrigerator(hpxml_bldg, args)
    set_extra_refrigerator(hpxml_bldg, args)
    set_freezer(hpxml_bldg, args)
    set_cooking_range_oven(hpxml_bldg, args)
    set_ceiling_fans(hpxml_bldg, args)
    set_misc_plug_loads_television(hpxml_bldg, args)
    set_misc_plug_loads_other(hpxml_bldg, args)
    set_misc_plug_loads_vehicle(hpxml_bldg, args)
    set_misc_plug_loads_well_pump(hpxml_bldg, args)
    set_misc_fuel_loads_grill(hpxml_bldg, args)
    set_misc_fuel_loads_lighting(hpxml_bldg, args)
    set_misc_fuel_loads_fireplace(hpxml_bldg, args)
    set_pool(hpxml_bldg, args)
    set_permanent_spa(hpxml_bldg, args)
    set_electric_panel(hpxml_bldg, args)
    collapse_surfaces(hpxml_bldg, args)
    renumber_hpxml_ids(hpxml_bldg)

    hpxml_doc = hpxml.to_doc()
    hpxml.set_unique_hpxml_ids(hpxml_doc, true) if hpxml.buildings.size > 1
    XMLHelper.write_file(hpxml_doc, hpxml_path)

    if args[:apply_defaults]
      # Always check for invalid HPXML file before applying defaults
      if not validate_hpxml(runner, hpxml, hpxml_doc, hpxml_path)
        return false
      end

      Defaults.apply(runner, hpxml, hpxml_bldg, weather)
      hpxml_doc = hpxml.to_doc()
      hpxml.set_unique_hpxml_ids(hpxml_doc, true) if hpxml.buildings.size > 1
      XMLHelper.write_file(hpxml_doc, hpxml_path)
    end

    if args[:apply_validation]
      # Optionally check for invalid HPXML file (with or without defaults applied)
      if not validate_hpxml(runner, hpxml, hpxml_doc, hpxml_path)
        return false
      end
    end

    return hpxml_doc
  end

  # Returns the WeatherFile object if we determine we need it for subsequent processing.
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param args [Hash] Map of :argument_name => value
  # @return [WeatherFile] Weather object containing EPW information
  def get_weather_if_needed(runner, args)
    if (args[:hvac_control_heating_season_period].to_s == Constants::BuildingAmerica) ||
       (args[:hvac_control_cooling_season_period].to_s == Constants::BuildingAmerica) ||
       (args[:dhw_solar_thermal] != 'None' && args[:dhw_solar_thermal_collector_tilt].start_with?('latitude')) ||
       (args[:pv_system_maximum_power_output].to_f > 0 && args[:pv_system_array_tilt].start_with?('latitude')) ||
       (args[:pv_system_2_maximum_power_output].to_f > 0 && args[:pv_system_2_array_tilt].start_with?('latitude')) ||
       (args[:apply_defaults])
      epw_path = args[:location_epw_filepath]
      if epw_path.nil?
        # Get EPW path from zip code
        epw_path = Defaults.lookup_weather_data_from_zipcode(args[:location_zip_code])[:station_filename]
      end

      # Error-checking
      if not File.exist? epw_path
        epw_path = File.join(File.expand_path(File.join(File.dirname(__FILE__), '..', 'weather')), epw_path) # a filename was entered for location_epw_filepath
      end
      if not File.exist? epw_path
        runner.registerError("Could not find EPW file at '#{epw_path}'.")
        return false
      end

      return WeatherFile.new(epw_path: epw_path, runner: nil)
    end

    return
  end

  # Check for errors in hpxml, and validate hpxml_doc against hpxml_path
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param hpxml [HPXML] HPXML object
  # @param hpxml_doc [Oga::XML::Element] Root XML element of the HPXML document
  # @param hpxml_path [String] Path to the created HPXML file
  # @return [Boolean] True if the HPXML is valid
  def validate_hpxml(runner, hpxml, hpxml_doc, hpxml_path)
    # Check for errors in the HPXML object
    errors = []
    hpxml.buildings.each do |hpxml_bldg|
      errors += hpxml_bldg.check_for_errors()
    end
    if errors.size > 0
      fail "ERROR: Invalid HPXML object produced.\n#{errors}"
    end

    is_valid = true

    # Validate input HPXML against schema
    schema_path = File.join(File.dirname(__FILE__), '..', 'HPXMLtoOpenStudio', 'resources', 'hpxml_schema', 'HPXML.xsd')
    schema_validator = XMLValidator.get_xml_validator(schema_path)
    xsd_errors, xsd_warnings = XMLValidator.validate_against_schema(hpxml_path, schema_validator)

    # Validate input HPXML against schematron docs
    schematron_path = File.join(File.dirname(__FILE__), '..', 'HPXMLtoOpenStudio', 'resources', 'hpxml_schematron', 'EPvalidator.sch')
    schematron_validator = XMLValidator.get_xml_validator(schematron_path)
    sct_errors, sct_warnings = XMLValidator.validate_against_schematron(hpxml_path, schematron_validator, hpxml_doc)

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

  # Create 3D geometry (surface, subsurfaces) for a given unit type
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param args [Hash] Map of :argument_name => value
  # @return [Boolean] True if successful
  def create_geometry_envelope(runner, model, args)
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

    args[:geometry_foundation_type_rim_joist_height] = args[:geometry_foundation_type_rim_joist_height].to_f / 12.0

    if args[:geometry_foundation_type_type] == HPXML::FoundationTypeSlab
      args[:geometry_foundation_type_height] = 0.0
      args[:geometry_foundation_type_height_above_grade] = 0.0
      args[:geometry_foundation_type_rim_joist_height] = 0.0
    elsif (args[:geometry_foundation_type_type] == HPXML::FoundationTypeAmbient) || args[:geometry_foundation_type_type].start_with?(HPXML::FoundationTypeBellyAndWing)
      args[:geometry_foundation_type_rim_joist_height] = 0.0
    end

    if model.getSpaces.size > 0
      runner.registerError('Starting model is not empty.')
      return false
    end

    case args[:geometry_unit_type]
    when HPXML::ResidentialTypeSFD
      success = Geometry.create_single_family_detached(runner, model, **args)
    when HPXML::ResidentialTypeSFA
      success = Geometry.create_single_family_attached(model, **args)
    when HPXML::ResidentialTypeApartment
      success = Geometry.create_apartment(model, **args)
    when HPXML::ResidentialTypeManufactured
      success = Geometry.create_single_family_detached(runner, model, **args)
    end
    return false if not success

    success = Geometry.create_doors(runner, model, **args)
    return false if not success

    success = Geometry.create_windows_and_skylights(runner, model, **args)
    return false if not success

    return true
  end

  # Check if unavailable period already exists for given name and begin/end times.
  #
  # @param hpxml [HPXML] HPXML object
  # @param column_name [String] Column name associated with unavailable_periods.csv
  # @param begin_month [Integer] Unavailable period begin month
  # @param begin_day [Integer] Unavailable period begin day
  # @param begin_hour [Integer] Unavailable period begin hour
  # @param end_month [Integer] Unavailable period end month
  # @param end_day [Integer] Unavailable period end day
  # @param end_hour [Integer] Unavailable period end hour
  # @param natvent_availability [String] Natural ventilation availability (HXPML::ScheduleXXX)
  # @return [Boolean] True if the unavailability period already exists
  def unavailable_period_exists(hpxml, column_name, begin_month, begin_day, begin_hour, end_month, end_day, end_hour, natvent_availability = nil)
    natvent_availability = HPXML::ScheduleUnavailable if natvent_availability.nil?

    hpxml.header.unavailable_periods.each do |unavailable_period|
      begin_hour = 0 if begin_hour.nil?
      end_hour = 24 if end_hour.nil?

      next unless (unavailable_period.column_name == column_name) &&
                  (unavailable_period.begin_month == begin_month) &&
                  (unavailable_period.begin_day == begin_day) &&
                  (unavailable_period.begin_hour == begin_hour) &&
                  (unavailable_period.end_month == end_month) &&
                  (unavailable_period.end_day == end_day) &&
                  (unavailable_period.end_hour == end_hour) &&
                  (unavailable_period.natvent_availability == natvent_availability)

      return true
    end
    return false
  end

  # Set header properties, including:
  # - vacancy periods
  # - power outage periods
  # - software info program
  # - simulation control
  # - emissions scenarios
  # - utility bill scenarios
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param hpxml [HPXML] HPXML object
  # @param args [Hash] Map of :argument_name => value
  # @return [Boolean] true if no errors, otherwise false
  def set_header(runner, hpxml, args)
    errors = []

    hpxml.header.xml_type = 'HPXML'
    hpxml.header.xml_generated_by = 'BuildResidentialHPXML'
    hpxml.header.transaction = 'create'
    hpxml.header.whole_sfa_or_mf_building_sim = args[:whole_sfa_or_mf_building_sim]

    if not args[:schedules_unavailable_period_types].nil?
      unavailable_period_types = args[:schedules_unavailable_period_types].split(',').map(&:strip)
      unavailable_period_dates = args[:schedules_unavailable_period_dates].split(',').map(&:strip)
      if !args[:schedules_unavailable_period_window_natvent_availabilities].nil?
        natvent_availabilities = args[:schedules_unavailable_period_window_natvent_availabilities].split(',').map(&:strip)
      else
        natvent_availabilities = [''] * unavailable_period_types.size
      end

      unavailable_periods = unavailable_period_types.zip(unavailable_period_dates,
                                                         natvent_availabilities)

      unavailable_periods.each do |unavailable_period|
        column_name, date_time_range, natvent_availability = unavailable_period
        natvent_availability = nil if natvent_availability.empty?

        begin_month, begin_day, begin_hour, end_month, end_day, end_hour = Calendar.parse_date_time_range(date_time_range)

        if not unavailable_period_exists(hpxml, column_name, begin_month, begin_day, begin_hour, end_month, end_day, end_hour)
          hpxml.header.unavailable_periods.add(column_name: column_name, begin_month: begin_month, begin_day: begin_day, begin_hour: begin_hour, end_month: end_month, end_day: end_day, end_hour: end_hour, natvent_availability: natvent_availability)
        end
      end
    end

    if not args[:software_info_program_used].to_s.empty?
      if (not hpxml.header.software_program_used.nil?) && (hpxml.header.software_program_used != args[:software_info_program_used])
        errors << "'Software Info: Program Used' cannot vary across dwelling units."
      end
      hpxml.header.software_program_used = args[:software_info_program_used]
    end
    if not args[:software_info_program_version].to_s.empty?
      if (not hpxml.header.software_program_version.nil?) && (hpxml.header.software_program_version != args[:software_info_program_version])
        errors << "'Software Info: Program Version' cannot vary across dwelling units."
      end
      hpxml.header.software_program_version = args[:software_info_program_version]
    end

    if args[:simulation_control_timestep] != 60 # 60 is the OS-HPXML default, no need to write it
      if (not hpxml.header.timestep.nil?) && (hpxml.header.timestep != args[:simulation_control_timestep])
        errors << "'Simulation Control: Timestep' cannot vary across dwelling units."
      end
      hpxml.header.timestep = args[:simulation_control_timestep]
    end

    if (not args[:simulation_control_run_period].nil?) && (args[:simulation_control_run_period] != 'Jan 1 - Dec 31') # Jan 1 - Dec 31 is the OS-HPXML default, no need to write it
      begin_month, begin_day, _begin_hour, end_month, end_day, _end_hour = Calendar.parse_date_time_range(args[:simulation_control_run_period])
      if (!hpxml.header.sim_begin_month.nil? && (hpxml.header.sim_begin_month != begin_month)) ||
         (!hpxml.header.sim_begin_day.nil? && (hpxml.header.sim_begin_day != begin_day)) ||
         (!hpxml.header.sim_end_month.nil? && (hpxml.header.sim_end_month != end_month)) ||
         (!hpxml.header.sim_end_day.nil? && (hpxml.header.sim_end_day != end_day))
        errors << "'Simulation Control: Run Period' cannot vary across dwelling units."
      end
      hpxml.header.sim_begin_month = begin_month
      hpxml.header.sim_begin_day = begin_day
      hpxml.header.sim_end_month = end_month
      hpxml.header.sim_end_day = end_day
    end

    tcm = args[:advanced_feature_temperature_capacitance_multiplier]
    tcm = args[:advanced_feature_2_temperature_capacitance_multiplier] if tcm.nil?
    if not tcm.nil?
      if (not hpxml.header.temperature_capacitance_multiplier.nil?) && (hpxml.header.temperature_capacitance_multiplier != tcm)
        errors << "Advanced feature 'Temperature Capacitance Multiplier' cannot vary across dwelling units."
      end
      hpxml.header.temperature_capacitance_multiplier = tcm
    end

    gshp_type = args[:advanced_feature_ground_to_air_heat_pump_model_type]
    gshp_type = args[:advanced_feature_2_ground_to_air_heat_pump_model_type] if gshp_type.nil?
    if not gshp_type.nil?
      if (not hpxml.header.ground_to_air_heat_pump_model_type.nil?) && (hpxml.header.ground_to_air_heat_pump_model_type != gshp_type)
        errors << "Advanced feature 'Ground-to-Air Heat Pump Model Type' cannot vary across dwelling units."
      end
      hpxml.header.ground_to_air_heat_pump_model_type = gshp_type
    end

    onoff_db = args[:advanced_feature_hvac_on_off_thermostat_deadband_temperature]
    onoff_db = args[:advanced_feature_2_hvac_on_off_thermostat_deadband_temperature] if onoff_db.nil?
    if not onoff_db.nil?
      if (not hpxml.header.hvac_onoff_thermostat_deadband.nil?) && (hpxml.header.hvac_onoff_thermostat_deadband != onoff_db)
        errors << "Advanced feature 'HVAC On-Off Thermostat Deadband Temperature' cannot vary across dwelling units."
      end
      hpxml.header.hvac_onoff_thermostat_deadband = onoff_db
    end

    hpbak = args[:advanced_feature_heat_pump_backup_capacity_increment]
    hpbak = args[:advanced_feature_2_heat_pump_backup_capacity_increment] if hpbak.nil?
    if not hpbak.nil?
      if (not hpxml.header.heat_pump_backup_heating_capacity_increment.nil?) && (hpxml.header.heat_pump_backup_heating_capacity_increment != hpbak)
        errors << "Advanced feature 'Heat Pump Backup Heating Capacity Increment' cannot vary across dwelling units."
      end
      hpxml.header.heat_pump_backup_heating_capacity_increment = hpbak
    end

    if not args[:emissions_scenario_names].nil?
      emissions_scenario_names = args[:emissions_scenario_names].split(',').map(&:strip)
      emissions_types = args[:emissions_types].split(',').map(&:strip)
      emissions_electricity_units = args[:emissions_electricity_units].split(',').map(&:strip)
      emissions_electricity_values_or_filepaths = args[:emissions_electricity_values_or_filepaths].split(',').map(&:strip)

      if not args[:emissions_electricity_number_of_header_rows].nil?
        emissions_electricity_number_of_header_rows = args[:emissions_electricity_number_of_header_rows].split(',').map(&:strip)
      else
        emissions_electricity_number_of_header_rows = [nil] * emissions_scenario_names.size
      end
      if not args[:emissions_electricity_column_numbers].nil?
        emissions_electricity_column_numbers = args[:emissions_electricity_column_numbers].split(',').map(&:strip)
      else
        emissions_electricity_column_numbers = [nil] * emissions_scenario_names.size
      end
      if not args[:emissions_fossil_fuel_units].nil?
        fuel_units = args[:emissions_fossil_fuel_units].split(',').map(&:strip)
      else
        fuel_units = [nil] * emissions_scenario_names.size
      end

      fuel_values = {}
      HPXML::fossil_fuels.each do |fossil_fuel|
        underscore_case = OpenStudio::toUnderscoreCase(fossil_fuel)

        if not args["emissions_#{underscore_case}_values".to_sym].nil?
          fuel_values[fossil_fuel] = args["emissions_#{underscore_case}_values".to_sym].split(',').map(&:strip)
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

        emissions_scenario_exists = false
        hpxml.header.emissions_scenarios.each do |es|
          if (es.name != name) || (es.emissions_type != emissions_type)
            next
          end

          if (es.emissions_type != emissions_type) ||
             (!elec_units.nil? && es.elec_units != elec_units) ||
             (!elec_value.nil? && es.elec_value != elec_value) ||
             (!elec_schedule_filepath.nil? && es.elec_schedule_filepath != elec_schedule_filepath) ||
             (!elec_num_headers.nil? && es.elec_schedule_number_of_header_rows != elec_num_headers) ||
             (!elec_column_num.nil? && es.elec_schedule_column_number != elec_column_num) ||
             (!es.natural_gas_units.nil? && !fuel_units.nil? && es.natural_gas_units != fuel_units) ||
             (!natural_gas_value.nil? && es.natural_gas_value != natural_gas_value) ||
             (!es.propane_units.nil? && !fuel_units.nil? && es.propane_units != fuel_units) ||
             (!propane_value.nil? && es.propane_value != propane_value) ||
             (!es.fuel_oil_units.nil? && !fuel_units.nil? && es.fuel_oil_units != fuel_units) ||
             (!fuel_oil_value.nil? && es.fuel_oil_value != fuel_oil_value) ||
             (!es.coal_units.nil? && !fuel_units.nil? && es.coal_units != fuel_units) ||
             (!coal_value.nil? && es.coal_value != coal_value) ||
             (!es.wood_units.nil? && !fuel_units.nil? && es.wood_units != fuel_units) ||
             (!wood_value.nil? && es.wood_value != wood_value) ||
             (!es.wood_pellets_units.nil? && !fuel_units.nil? && es.wood_pellets_units != fuel_units) ||
             (!wood_pellets_value.nil? && es.wood_pellets_value != wood_pellets_value)
            errors << "HPXML header already includes an emissions scenario named '#{name}' with type '#{emissions_type}'."
          else
            emissions_scenario_exists = true
          end
        end

        next if emissions_scenario_exists

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

    for i in 1..3
      ubvar = i == 1 ? 'utility_bill_scenario' : "utility_bill_scenario_#{i}"

      next if args[ubvar.to_sym] == 'None'

      name = args["#{ubvar}_name".to_sym]
      elec_tariff_filepath = args["#{ubvar}_electricity_file_path".to_sym]
      elec_fixed_charge = args["#{ubvar}_electricity_fixed_charge".to_sym]
      elec_marginal_rate = args["#{ubvar}_electricity_marginal_rate".to_sym]
      natural_gas_fixed_charge = args["#{ubvar}_natural_gas_fixed_charge".to_sym]
      natural_gas_marginal_rate = args["#{ubvar}_natural_gas_marginal_rate".to_sym]
      propane_marginal_rate = args["#{ubvar}_propane_marginal_rate".to_sym]
      fuel_oil_marginal_rate = args["#{ubvar}_fuel_oil_marginal_rate".to_sym]
      coal_marginal_rate = args["#{ubvar}_coal_marginal_rate".to_sym]
      wood_marginal_rate = args["#{ubvar}_wood_marginal_rate".to_sym]
      wood_pellets_marginal_rate = args["#{ubvar}_wood_pellets_marginal_rate".to_sym]
      pv_compensation_type = args["#{ubvar}_pv_compensation_type".to_sym]
      pv_net_metering_annual_excess_sellback_rate_type = args["#{ubvar}_pv_net_metering_annual_excess_sellback_rate_type".to_sym]
      pv_net_metering_annual_excess_sellback_rate = args["#{ubvar}_pv_net_metering_annual_excess_sellback_rate".to_sym]
      pv_feed_in_tariff_rate = args[:"#{ubvar}_pv_feed_in_tariff_rate".to_sym]
      pv_monthly_grid_connection_fee = args["#{ubvar}_pv_monthly_grid_connection_fee".to_sym]
      pv_monthly_grid_connection_fee_units = args["#{ubvar}_pv_monthly_grid_connection_fee_units".to_sym]

      pv_monthly_grid_connection_fee_dollars_per_kw = nil
      pv_monthly_grid_connection_fee_dollars = nil
      if pv_monthly_grid_connection_fee_units == HPXML::UnitsDollarsPerkW
        pv_monthly_grid_connection_fee_dollars_per_kw = pv_monthly_grid_connection_fee
      elsif pv_monthly_grid_connection_fee_units == HPXML::UnitsDollars
        pv_monthly_grid_connection_fee_dollars = pv_monthly_grid_connection_fee
      end

      utility_bill_scenario_exists = false
      hpxml.header.utility_bill_scenarios.each do |ubs|
        next if ubs.name != name

        if (!elec_tariff_filepath.nil? && ubs.elec_tariff_filepath != elec_tariff_filepath) ||
           (!elec_fixed_charge.nil? && ubs.elec_fixed_charge != elec_fixed_charge) ||
           (!elec_marginal_rate.nil? && ubs.elec_marginal_rate != elec_marginal_rate) ||
           (!natural_gas_fixed_charge.nil? && ubs.natural_gas_fixed_charge != natural_gas_fixed_charge) ||
           (!natural_gas_marginal_rate.nil? && ubs.natural_gas_marginal_rate != natural_gas_marginal_rate) ||
           (!propane_marginal_rate.nil? && ubs.propane_marginal_rate != propane_marginal_rate) ||
           (!fuel_oil_marginal_rate.nil? && ubs.fuel_oil_marginal_rate != fuel_oil_marginal_rate) ||
           (!coal_marginal_rate.nil? && ubs.coal_marginal_rate != coal_marginal_rate) ||
           (!wood_marginal_rate.nil? && ubs.wood_marginal_rate != wood_marginal_rate) ||
           (!wood_pellets_marginal_rate.nil? && ubs.wood_pellets_marginal_rate != wood_pellets_marginal_rate) ||
           (!pv_compensation_type.nil? && ubs.pv_compensation_type != pv_compensation_type) ||
           (!pv_net_metering_annual_excess_sellback_rate_type.nil? && ubs.pv_net_metering_annual_excess_sellback_rate_type != pv_net_metering_annual_excess_sellback_rate_type) ||
           (!pv_net_metering_annual_excess_sellback_rate.nil? && ubs.pv_net_metering_annual_excess_sellback_rate != pv_net_metering_annual_excess_sellback_rate) ||
           (!pv_feed_in_tariff_rate.nil? && ubs.pv_feed_in_tariff_rate != pv_feed_in_tariff_rate) ||
           (!pv_monthly_grid_connection_fee_dollars_per_kw.nil? && ubs.pv_monthly_grid_connection_fee_dollars_per_kw != pv_monthly_grid_connection_fee_dollars_per_kw) ||
           (!pv_monthly_grid_connection_fee_dollars.nil? && ubs.pv_monthly_grid_connection_fee_dollars != pv_monthly_grid_connection_fee_dollars)
          errors << "HPXML header already includes a utility bill scenario named '#{name}'."
        else
          utility_bill_scenario_exists = true
        end
      end

      next if utility_bill_scenario_exists

      hpxml.header.utility_bill_scenarios.add(name: name,
                                              elec_tariff_filepath: elec_tariff_filepath,
                                              elec_fixed_charge: elec_fixed_charge,
                                              elec_marginal_rate: elec_marginal_rate,
                                              natural_gas_fixed_charge: natural_gas_fixed_charge,
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

    if not args[:electric_panel_service_feeders_load_calculation_types].nil?
      hpxml.header.service_feeders_load_calculation_types = args[:electric_panel_service_feeders_load_calculation_types].split(',').map(&:strip)
    end

    errors.each do |error|
      runner.registerError(error)
    end
    return errors.empty?
  end

  # Add a building (i.e., unit), along with site properties, to the HPXML file.
  # Return the building so we can then set more properties on it.
  #
  # @param hpxml [HPXML] HPXML object
  # @param args [Hash] Map of :argument_name => value
  # @return [HPXML::Building] HPXML Building object representing an individual dwelling unit
  def add_building(hpxml, args)
    hpxml.buildings.add(building_id: 'MyBuilding',
                        site_id: 'SiteID',
                        event_type: 'proposed workscope',
                        zip_code: args[:location_zip_code])
    return hpxml.buildings[-1]
  end

  # Sets the HPXML site properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_site(hpxml_bldg, args)
    hpxml_bldg.site.shielding_of_home = args[:location_site_type_shielding_of_home]
    hpxml_bldg.site.ground_conductivity = args[:location_soil_type_conductivity]
    hpxml_bldg.site.ground_diffusivity = args[:location_soil_type_diffusivity]
    hpxml_bldg.site.soil_type = args[:location_soil_type_soil_type]
    hpxml_bldg.site.moisture_type = args[:location_soil_type_moisture_type]

    hpxml_bldg.site.site_type = args[:location_site_type_type]

    n_walls_attached = [args[:geometry_attached_walls_front_wall_is_adiabatic],
                        args[:geometry_attached_walls_back_wall_is_adiabatic],
                        args[:geometry_attached_walls_left_wall_is_adiabatic],
                        args[:geometry_attached_walls_right_wall_is_adiabatic]].count(true)

    case args[:geometry_unit_type]
    when HPXML::ResidentialTypeSFA, HPXML::ResidentialTypeApartment
      if n_walls_attached == 3
        hpxml_bldg.site.surroundings = HPXML::SurroundingsThreeSides
      elsif n_walls_attached == 2
        hpxml_bldg.site.surroundings = HPXML::SurroundingsTwoSides
      elsif n_walls_attached == 1
        hpxml_bldg.site.surroundings = HPXML::SurroundingsOneSide
      else
        hpxml_bldg.site.surroundings = HPXML::SurroundingsStandAlone
      end
      if args[:geometry_attic_type_attic_type] == HPXML::AtticTypeBelowApartment
        if args[:geometry_foundation_type_type] == HPXML::FoundationTypeAboveApartment
          hpxml_bldg.site.vertical_surroundings = HPXML::VerticalSurroundingsAboveAndBelow
        else
          hpxml_bldg.site.vertical_surroundings = HPXML::VerticalSurroundingsAbove
        end
      else
        if args[:geometry_foundation_type_type] == HPXML::FoundationTypeAboveApartment
          hpxml_bldg.site.vertical_surroundings = HPXML::VerticalSurroundingsBelow
        else
          hpxml_bldg.site.vertical_surroundings = HPXML::VerticalSurroundingsNoAboveOrBelow
        end
      end
    when HPXML::ResidentialTypeSFD, HPXML::ResidentialTypeManufactured
      hpxml_bldg.site.surroundings = HPXML::SurroundingsStandAlone
      hpxml_bldg.site.vertical_surroundings = HPXML::VerticalSurroundingsNoAboveOrBelow
    end

    hpxml_bldg.site.azimuth_of_front_of_home = args[:geometry_unit_orientation]
  end

  # Sets the HPXML neighboring buildings.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_neighbor_buildings(hpxml_bldg, args)
    nbr_map = { Constants::FacadeFront => [args[:geometry_neighbor_buildings_front_distance].to_f, args[:geometry_neighbor_buildings_front_height]],
                Constants::FacadeBack => [args[:geometry_neighbor_buildings_back_distance].to_f, args[:geometry_neighbor_buildings_back_height]],
                Constants::FacadeLeft => [args[:geometry_neighbor_buildings_left_distance].to_f, args[:geometry_neighbor_buildings_left_height]],
                Constants::FacadeRight => [args[:geometry_neighbor_buildings_right_distance].to_f, args[:geometry_neighbor_buildings_right_height]] }

    nbr_map.each do |facade, data|
      distance, neighbor_height = data
      next if distance == 0

      azimuth = Geometry.get_azimuth_from_facade(facade, args[:geometry_unit_orientation])

      if (distance > 0) && (not neighbor_height.nil?)
        height = neighbor_height
      end

      hpxml_bldg.neighbor_buildings.add(azimuth: azimuth,
                                        distance: distance,
                                        height: height)
    end
  end

  # Sets the HPXML building occupancy properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_building_occupancy(hpxml_bldg, args)
    hpxml_bldg.building_occupancy.number_of_residents = args[:geometry_unit_num_occupants]
  end

  # Sets the HPXML building construction properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_building_construction(hpxml_bldg, args)
    if args[:geometry_unit_type] == HPXML::ResidentialTypeApartment
      args[:geometry_unit_num_floors_above_grade] = 1
    end
    number_of_conditioned_floors_above_grade = args[:geometry_unit_num_floors_above_grade]
    number_of_conditioned_floors = number_of_conditioned_floors_above_grade
    if args[:geometry_foundation_type_type] == HPXML::FoundationTypeBasementConditioned
      number_of_conditioned_floors += 1
    end

    hpxml_bldg.building_construction.number_of_conditioned_floors = number_of_conditioned_floors
    hpxml_bldg.building_construction.number_of_conditioned_floors_above_grade = number_of_conditioned_floors_above_grade
    hpxml_bldg.building_construction.number_of_bedrooms = args[:geometry_unit_num_bedrooms]
    hpxml_bldg.building_construction.number_of_bathrooms = args[:geometry_unit_num_bathrooms]
    hpxml_bldg.building_construction.conditioned_floor_area = args[:geometry_unit_cfa]
    hpxml_bldg.building_construction.conditioned_building_volume = args[:geometry_unit_cfa] * args[:geometry_average_ceiling_height]
    hpxml_bldg.building_construction.average_ceiling_height = args[:geometry_average_ceiling_height]
    hpxml_bldg.building_construction.residential_facility_type = args[:geometry_unit_type]
    hpxml_bldg.building_construction.number_of_units_in_building = args[:geometry_building_num_units]
    if args[:building_year_built] != 0
      hpxml_bldg.building_construction.year_built = args[:building_year_built]
    end
    if args[:building_unit_multiplier] != 1 # 1 is the OS-HPXML default, no need to write it
      hpxml_bldg.building_construction.number_of_units = args[:building_unit_multiplier]
    end
  end

  # Sets the HPXML building header properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_building_header(hpxml_bldg, args)
    if not args[:schedules_filepaths].nil?
      hpxml_bldg.header.schedules_filepaths = args[:schedules_filepaths].split(',').map(&:strip)
    end
    hpxml_bldg.header.heat_pump_sizing_methodology = args[:hvac_heat_pump_capacity_autosizing_methodology]
    hpxml_bldg.header.heat_pump_backup_sizing_methodology = args[:hvac_heat_pump_backup_capacity_autosizing_methodology]
    hpxml_bldg.header.natvent_days_per_week = args[:enclosure_window_natural_ventilation_availability]

    hvac_incr = args[:advanced_feature_hvac_allow_increased_fixed_capacities]
    hvac_incr = args[:advanced_feature_2_hvac_allow_increased_fixed_capacities] if hvac_incr.nil?
    if not hvac_incr.nil?
      hpxml_bldg.header.allow_increased_fixed_capacities = hvac_incr
    end

    if not args[:additional_properties].nil?
      extension_properties = {}
      args[:additional_properties].split('|').map(&:strip).each do |additional_property|
        key, value = additional_property.split('=').map(&:strip)
        extension_properties[key] = value
      end
      hpxml_bldg.header.extension_properties = extension_properties
    end

    if not args[:electric_panel_baseline_peak_power].nil?
      hpxml_bldg.header.electric_panel_baseline_peak_power = args[:electric_panel_baseline_peak_power]
    end
  end

  # Sets the HPXML climate and risk zones properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_climate_and_risk_zones(hpxml_bldg, args)
    if not args[:location_epw_filepath].nil?
      hpxml_bldg.climate_and_risk_zones.weather_station_id = 'WeatherStation'
      hpxml_bldg.climate_and_risk_zones.weather_station_name = File.basename(args[:location_epw_filepath]).gsub('.epw', '')
      hpxml_bldg.climate_and_risk_zones.weather_station_epw_filepath = args[:location_epw_filepath]
    end
  end

  # Sets the HPXML air infiltration measurements properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_air_infiltration_measurements(hpxml_bldg, args)
    if args[:enclosure_air_leakage_value]
      if args[:enclosure_air_leakage_units] == HPXML::UnitsELA
        effective_leakage_area = args[:enclosure_air_leakage_value]
      else
        unit_of_measure = args[:enclosure_air_leakage_units]
        air_leakage = args[:enclosure_air_leakage_value]
        if [HPXML::UnitsACH, HPXML::UnitsCFM].include? args[:enclosure_air_leakage_units]
          house_pressure = args[:enclosure_air_leakage_house_pressure]
        end
      end
    else
      leakiness_description = args[:enclosure_air_leakage_leakiness_description]
    end
    if leakiness_description.nil?
      if [HPXML::ResidentialTypeSFA, HPXML::ResidentialTypeApartment].include? args[:geometry_unit_type]
        air_leakage_type = HPXML::InfiltrationTypeUnitExterior
      end
    end
    infiltration_volume = hpxml_bldg.building_construction.conditioned_building_volume

    hpxml_bldg.air_infiltration_measurements.add(id: "AirInfiltrationMeasurement#{hpxml_bldg.air_infiltration_measurements.size + 1}",
                                                 house_pressure: house_pressure,
                                                 unit_of_measure: unit_of_measure,
                                                 air_leakage: air_leakage,
                                                 effective_leakage_area: effective_leakage_area,
                                                 infiltration_volume: infiltration_volume,
                                                 infiltration_type: air_leakage_type,
                                                 leakiness_description: leakiness_description)
  end

  # Sets the HPXML roofs properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @param sorted_surfaces [Array<OpenStudio::Model::Surface>] surfaces sorted by deterministically assigned Index
  # @return [nil]
  def set_roofs(hpxml_bldg, args, sorted_surfaces)
    args[:geometry_roof_pitch] *= 12.0
    if (args[:geometry_attic_type_attic_type] == HPXML::AtticTypeFlatRoof) || (args[:geometry_attic_type_attic_type] == HPXML::AtticTypeBelowApartment)
      args[:geometry_roof_pitch] = 0.0
    end

    sorted_surfaces.each do |surface|
      next if surface.outsideBoundaryCondition != EPlus::BoundaryConditionOutdoors
      next if surface.surfaceType != EPlus::SurfaceTypeRoofCeiling

      interior_adjacent_to = Geometry.get_surface_adjacent_to(surface)
      next if [HPXML::LocationOtherHousingUnit].include? interior_adjacent_to

      if args[:geometry_attic_type_attic_type] == HPXML::AtticTypeFlatRoof
        azimuth = nil
      else
        azimuth = Geometry.get_surface_azimuth(surface, args[:geometry_unit_orientation])
      end

      hpxml_bldg.roofs.add(id: "Roof#{hpxml_bldg.roofs.size + 1}",
                           interior_adjacent_to: Geometry.get_surface_adjacent_to(surface),
                           azimuth: azimuth,
                           area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2'),
                           roof_type: args[:enclosure_roof_material_type],
                           roof_color: args[:enclosure_roof_material_color],
                           solar_absorptance: args[:enclosure_roof_material_solar_absorptance],
                           emittance: args[:enclosure_roof_material_emittance],
                           pitch: args[:geometry_roof_pitch])
      @surface_ids[surface.name.to_s] = hpxml_bldg.roofs[-1].id

      if hpxml_bldg.roofs[-1].is_thermal_boundary
        hpxml_bldg.roofs[-1].insulation_assembly_r_value = args[:enclosure_roof_conditioned_assembly_r_value]
      else
        hpxml_bldg.roofs[-1].insulation_assembly_r_value = args[:enclosure_roof_unconditioned_assembly_r_value]
      end

      next unless [HPXML::RadiantBarrierLocationAtticRoofOnly, HPXML::RadiantBarrierLocationAtticRoofAndGableWalls].include?(args[:enclosure_radiant_barrier_location].to_s)
      next unless [HPXML::LocationAtticUnvented, HPXML::LocationAtticVented].include?(hpxml_bldg.roofs[-1].interior_adjacent_to)

      hpxml_bldg.roofs[-1].radiant_barrier = true
    end
  end

  # Sets the HPXML rim joists properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param args [Hash] Map of :argument_name => value
  # @param sorted_surfaces [Array<OpenStudio::Model::Surface>] surfaces sorted by deterministically assigned Index
  # @return [nil]
  def set_rim_joists(hpxml_bldg, model, args, sorted_surfaces)
    sorted_surfaces.each do |surface|
      next if surface.surfaceType != EPlus::SurfaceTypeWall
      next unless [EPlus::BoundaryConditionOutdoors, EPlus::BoundaryConditionAdiabatic].include? surface.outsideBoundaryCondition
      next unless Geometry.surface_is_rim_joist(surface, args[:geometry_foundation_type_rim_joist_height])

      interior_adjacent_to = Geometry.get_surface_adjacent_to(surface)
      next unless [HPXML::LocationBasementConditioned,
                   HPXML::LocationBasementUnconditioned,
                   HPXML::LocationCrawlspaceUnvented,
                   HPXML::LocationCrawlspaceVented,
                   HPXML::LocationCrawlspaceConditioned].include? interior_adjacent_to

      exterior_adjacent_to = HPXML::LocationOutside
      if surface.outsideBoundaryCondition == EPlus::BoundaryConditionAdiabatic # can be adjacent to foundation space
        adjacent_surface = Geometry.get_adiabatic_adjacent_surface(model, surface)
        if adjacent_surface.nil? # adjacent to a space that is not explicitly in the model
          unless [HPXML::ResidentialTypeSFD].include?(args[:geometry_unit_type])
            exterior_adjacent_to = interior_adjacent_to
            if exterior_adjacent_to == HPXML::LocationConditionedSpace # conditioned space adjacent to conditioned space
              exterior_adjacent_to = HPXML::LocationOtherHousingUnit
            end
          end
        else # adjacent to a space that is explicitly in the model
          exterior_adjacent_to = Geometry.get_surface_adjacent_to(adjacent_surface)
        end
      end

      if exterior_adjacent_to == HPXML::LocationOutside
        siding = args[:enclosure_wall_siding_type]
      end

      if interior_adjacent_to == exterior_adjacent_to
        insulation_assembly_r_value = 4.0 # Uninsulated
      else
        insulation_assembly_r_value = (args[:enclosure_rim_joist_assembly_r_value] + args[:enclosure_wall_continuous_insulation_r_value] + args[:enclosure_wall_siding_r_value]).round(2)
      end

      azimuth = Geometry.get_surface_azimuth(surface, args[:geometry_unit_orientation])

      hpxml_bldg.rim_joists.add(id: "RimJoist#{hpxml_bldg.rim_joists.size + 1}",
                                exterior_adjacent_to: exterior_adjacent_to,
                                interior_adjacent_to: interior_adjacent_to,
                                azimuth: azimuth,
                                area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2'),
                                siding: siding,
                                color: args[:enclosure_wall_siding_color],
                                solar_absorptance: args[:enclosure_wall_siding_solar_absorptance],
                                emittance: args[:enclosure_wall_siding_emittance],
                                insulation_assembly_r_value: insulation_assembly_r_value)
      @surface_ids[surface.name.to_s] = hpxml_bldg.rim_joists[-1].id
    end
  end

  # Sets the HPXML walls properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param args [Hash] Map of :argument_name => value
  # @param sorted_surfaces [Array<OpenStudio::Model::Surface>] surfaces sorted by deterministically assigned Index
  # @return [nil]
  def set_walls(hpxml_bldg, model, args, sorted_surfaces)
    sorted_surfaces.each do |surface|
      next if surface.surfaceType != EPlus::SurfaceTypeWall
      next if Geometry.surface_is_rim_joist(surface, args[:geometry_foundation_type_rim_joist_height])

      interior_adjacent_to = Geometry.get_surface_adjacent_to(surface)
      next unless [HPXML::LocationConditionedSpace, HPXML::LocationAtticUnvented, HPXML::LocationAtticVented, HPXML::LocationGarage].include? interior_adjacent_to

      exterior_adjacent_to = HPXML::LocationOutside
      if surface.adjacentSurface.is_initialized
        exterior_adjacent_to = Geometry.get_surface_adjacent_to(surface.adjacentSurface.get)
      elsif surface.outsideBoundaryCondition == EPlus::BoundaryConditionAdiabatic # can be adjacent to conditioned space, attic
        adjacent_surface = Geometry.get_adiabatic_adjacent_surface(model, surface)
        if adjacent_surface.nil? # adjacent to a space that is not explicitly in the model
          exterior_adjacent_to = interior_adjacent_to
          if exterior_adjacent_to == HPXML::LocationConditionedSpace # conditioned space adjacent to conditioned space
            exterior_adjacent_to = HPXML::LocationOtherHousingUnit
          end
        else # adjacent to a space that is explicitly in the model
          exterior_adjacent_to = Geometry.get_surface_adjacent_to(adjacent_surface)
        end
      end

      next if exterior_adjacent_to == HPXML::LocationConditionedSpace # already captured these surfaces

      attic_locations = [HPXML::LocationAtticUnconditioned, HPXML::LocationAtticUnvented, HPXML::LocationAtticVented]
      attic_wall_type = nil
      if (attic_locations.include? interior_adjacent_to) && (exterior_adjacent_to == HPXML::LocationOutside)
        attic_wall_type = HPXML::AtticWallTypeGable
      end

      wall_type = args[:enclosure_wall_type]
      if attic_locations.include? interior_adjacent_to
        wall_type = HPXML::WallTypeWoodStud
      end

      if exterior_adjacent_to == HPXML::LocationOutside && (not args[:enclosure_wall_siding_type].nil?)
        if (attic_locations.include? interior_adjacent_to) && (args[:enclosure_wall_siding_type] == HPXML::SidingTypeNone)
          siding = nil
        else
          siding = args[:enclosure_wall_siding_type]
        end
      end

      azimuth = Geometry.get_surface_azimuth(surface, args[:geometry_unit_orientation])

      hpxml_bldg.walls.add(id: "Wall#{hpxml_bldg.walls.size + 1}",
                           exterior_adjacent_to: exterior_adjacent_to,
                           interior_adjacent_to: interior_adjacent_to,
                           azimuth: azimuth,
                           wall_type: wall_type,
                           attic_wall_type: attic_wall_type,
                           siding: siding,
                           color: args[:enclosure_wall_siding_color],
                           solar_absorptance: args[:enclosure_wall_siding_solar_absorptance],
                           emittance: args[:enclosure_wall_siding_emittance],
                           area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2'))
      @surface_ids[surface.name.to_s] = hpxml_bldg.walls[-1].id

      is_uncond_attic_roof_insulated = false
      if attic_locations.include? interior_adjacent_to
        hpxml_bldg.roofs.each do |roof|
          next unless (roof.interior_adjacent_to == interior_adjacent_to) && (roof.insulation_assembly_r_value > 4.0)

          is_uncond_attic_roof_insulated = true
        end
      end

      if hpxml_bldg.walls[-1].is_thermal_boundary || is_uncond_attic_roof_insulated # Assume wall is insulated if roof is insulated
        if args[:enclosure_wall].include? 'IECC U-'
          hpxml_bldg.walls[-1].insulation_assembly_r_value = args[:enclosure_wall_assembly_r_value] # Don't add an e.g. siding R-value to the specified assembly U-factor
        else
          hpxml_bldg.walls[-1].insulation_assembly_r_value = (args[:enclosure_wall_assembly_r_value] + args[:enclosure_wall_continuous_insulation_r_value] + args[:enclosure_wall_siding_r_value]).round(2)
        end
      else
        hpxml_bldg.walls[-1].insulation_assembly_r_value = 4.0 # Uninsulated
      end

      next unless hpxml_bldg.walls[-1].attic_wall_type == HPXML::AtticWallTypeGable && args[:enclosure_radiant_barrier_location].to_s == HPXML::RadiantBarrierLocationAtticRoofAndGableWalls
      next unless [HPXML::LocationAtticUnvented, HPXML::LocationAtticVented].include?(hpxml_bldg.walls[-1].interior_adjacent_to)

      hpxml_bldg.walls[-1].radiant_barrier = true
    end
  end

  # Sets the HPXML foundation walls properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param args [Hash] Map of :argument_name => value
  # @param sorted_surfaces [Array<OpenStudio::Model::Surface>] surfaces sorted by deterministically assigned Index
  # @return [nil]
  def set_foundation_walls(hpxml_bldg, model, args, sorted_surfaces)
    sorted_surfaces.each do |surface|
      next if surface.surfaceType != EPlus::SurfaceTypeWall
      next unless [EPlus::BoundaryConditionFoundation, EPlus::BoundaryConditionAdiabatic].include? surface.outsideBoundaryCondition
      next if Geometry.surface_is_rim_joist(surface, args[:geometry_foundation_type_rim_joist_height])

      interior_adjacent_to = Geometry.get_surface_adjacent_to(surface)
      next unless [HPXML::LocationBasementConditioned,
                   HPXML::LocationBasementUnconditioned,
                   HPXML::LocationCrawlspaceUnvented,
                   HPXML::LocationCrawlspaceVented,
                   HPXML::LocationCrawlspaceConditioned].include? interior_adjacent_to

      exterior_adjacent_to = HPXML::LocationGround
      if surface.outsideBoundaryCondition == EPlus::BoundaryConditionAdiabatic # can be adjacent to foundation space
        adjacent_surface = Geometry.get_adiabatic_adjacent_surface(model, surface)
        if adjacent_surface.nil? # adjacent to a space that is not explicitly in the model
          unless [HPXML::ResidentialTypeSFD].include?(args[:geometry_unit_type])
            exterior_adjacent_to = interior_adjacent_to
            if exterior_adjacent_to == HPXML::LocationConditionedSpace # conditioned space adjacent to conditioned space
              exterior_adjacent_to = HPXML::LocationOtherHousingUnit
            end
          end
        else # adjacent to a space that is explicitly in the model
          exterior_adjacent_to = Geometry.get_surface_adjacent_to(adjacent_surface)
        end
      end

      foundation_wall_insulation_location = Constants::LocationExterior # default
      if not args[:enclosure_foundation_wall_insulation_location].nil?
        foundation_wall_insulation_location = args[:enclosure_foundation_wall_insulation_location]
      end

      if args[:enclosure_foundation_wall_assembly_r_value].to_f > 0
        insulation_assembly_r_value = args[:enclosure_foundation_wall_assembly_r_value]
      else
        insulation_interior_r_value = 0
        insulation_exterior_r_value = 0
        if interior_adjacent_to == exterior_adjacent_to # E.g., don't insulate wall between basement and neighbor basement
          # nop
        elsif foundation_wall_insulation_location == Constants::LocationInterior
          insulation_interior_r_value = args[:enclosure_foundation_wall_insulation_nominal_r_value]
          if insulation_interior_r_value > 0
            insulation_interior_distance_to_top = args[:enclosure_foundation_wall_insulation_distance_to_top]
            insulation_interior_distance_to_bottom = args[:enclosure_foundation_wall_insulation_distance_to_bottom]
          end
        elsif foundation_wall_insulation_location == Constants::LocationExterior
          insulation_exterior_r_value = args[:enclosure_foundation_wall_insulation_nominal_r_value]
          if insulation_exterior_r_value > 0
            insulation_exterior_distance_to_top = args[:enclosure_foundation_wall_insulation_distance_to_top]
            insulation_exterior_distance_to_bottom = args[:enclosure_foundation_wall_insulation_distance_to_bottom]
          end
        end
      end

      azimuth = Geometry.get_surface_azimuth(surface, args[:geometry_unit_orientation])

      hpxml_bldg.foundation_walls.add(id: "FoundationWall#{hpxml_bldg.foundation_walls.size + 1}",
                                      exterior_adjacent_to: exterior_adjacent_to,
                                      interior_adjacent_to: interior_adjacent_to,
                                      type: args[:enclosure_foundation_wall_type],
                                      azimuth: azimuth,
                                      height: args[:geometry_foundation_type_height],
                                      area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2'),
                                      thickness: args[:enclosure_foundation_wall_thickness],
                                      depth_below_grade: args[:geometry_foundation_type_height] - args[:geometry_foundation_type_height_above_grade],
                                      insulation_assembly_r_value: insulation_assembly_r_value,
                                      insulation_interior_r_value: insulation_interior_r_value,
                                      insulation_interior_distance_to_top: insulation_interior_distance_to_top,
                                      insulation_interior_distance_to_bottom: insulation_interior_distance_to_bottom,
                                      insulation_exterior_r_value: insulation_exterior_r_value,
                                      insulation_exterior_distance_to_top: insulation_exterior_distance_to_top,
                                      insulation_exterior_distance_to_bottom: insulation_exterior_distance_to_bottom)
      @surface_ids[surface.name.to_s] = hpxml_bldg.foundation_walls[-1].id
    end
  end

  # Sets the HPXML floors properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @param sorted_surfaces [Array<OpenStudio::Model::Surface>] surfaces sorted by deterministically assigned Index
  # @return [nil]
  def set_floors(hpxml_bldg, args, sorted_surfaces)
    sorted_surfaces.each do |surface|
      next if surface.outsideBoundaryCondition == EPlus::BoundaryConditionFoundation
      next unless [EPlus::SurfaceTypeFloor, EPlus::SurfaceTypeRoofCeiling].include? surface.surfaceType

      interior_adjacent_to = Geometry.get_surface_adjacent_to(surface)
      next unless [HPXML::LocationConditionedSpace, HPXML::LocationGarage].include? interior_adjacent_to

      exterior_adjacent_to = HPXML::LocationOutside
      if surface.adjacentSurface.is_initialized
        exterior_adjacent_to = Geometry.get_surface_adjacent_to(surface.adjacentSurface.get)
      elsif surface.outsideBoundaryCondition == EPlus::BoundaryConditionAdiabatic
        exterior_adjacent_to = HPXML::LocationOtherHousingUnit
        if surface.surfaceType == EPlus::SurfaceTypeFloor
          floor_or_ceiling = HPXML::FloorOrCeilingFloor
        elsif surface.surfaceType == EPlus::SurfaceTypeRoofCeiling
          floor_or_ceiling = HPXML::FloorOrCeilingCeiling
        end
      end

      next if interior_adjacent_to == exterior_adjacent_to
      next if (surface.surfaceType == EPlus::SurfaceTypeRoofCeiling) && (exterior_adjacent_to == HPXML::LocationOutside)
      next if [HPXML::LocationConditionedSpace,
               HPXML::LocationBasementConditioned,
               HPXML::LocationCrawlspaceConditioned].include? exterior_adjacent_to

      hpxml_bldg.floors.add(id: "Floor#{hpxml_bldg.floors.size + 1}",
                            exterior_adjacent_to: exterior_adjacent_to,
                            interior_adjacent_to: interior_adjacent_to,
                            floor_type: HPXML::FloorTypeWoodFrame, # May be overridden below
                            area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2'),
                            floor_or_ceiling: floor_or_ceiling)
      if hpxml_bldg.floors[-1].floor_or_ceiling.nil?
        if hpxml_bldg.floors[-1].is_floor
          hpxml_bldg.floors[-1].floor_or_ceiling = HPXML::FloorOrCeilingFloor
        elsif hpxml_bldg.floors[-1].is_ceiling
          hpxml_bldg.floors[-1].floor_or_ceiling = HPXML::FloorOrCeilingCeiling
        end
      end
      @surface_ids[surface.name.to_s] = hpxml_bldg.floors[-1].id

      if hpxml_bldg.floors[-1].is_thermal_boundary
        case exterior_adjacent_to
        when HPXML::LocationAtticUnvented, HPXML::LocationAtticVented
          hpxml_bldg.floors[-1].insulation_assembly_r_value = args[:enclosure_ceiling_assembly_r_value]
        when HPXML::LocationGarage
          hpxml_bldg.floors[-1].insulation_assembly_r_value = args[:enclosure_floor_over_garage_assembly_r_value]
          hpxml_bldg.floors[-1].floor_type = args[:enclosure_floor_over_garage_type]
        else
          hpxml_bldg.floors[-1].insulation_assembly_r_value = args[:enclosure_floor_over_foundation_assembly_r_value]
          hpxml_bldg.floors[-1].floor_type = args[:enclosure_floor_over_foundation_type]
        end
      else
        if floor_or_ceiling == HPXML::FloorOrCeilingFloor
          hpxml_bldg.floors[-1].insulation_assembly_r_value = 5.3 # Matches uninsulated option in enclosure_floor_over_foundation.tsv
        else
          hpxml_bldg.floors[-1].insulation_assembly_r_value = 2.1 # Matches uninsulated option in enclosure_ceiling.tsv
        end
      end

      next unless args[:enclosure_radiant_barrier_location].to_s == HPXML::RadiantBarrierLocationAtticFloor
      next unless [HPXML::LocationAtticUnvented, HPXML::LocationAtticVented].include?(hpxml_bldg.floors[-1].exterior_adjacent_to) && hpxml_bldg.floors[-1].interior_adjacent_to == HPXML::LocationConditionedSpace

      hpxml_bldg.floors[-1].radiant_barrier = true
    end
  end

  # Sets the HPXML slabs properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param args [Hash] Map of :argument_name => value
  # @param sorted_surfaces [Array<OpenStudio::Model::Surface>] surfaces sorted by deterministically assigned Index
  # @return [nil]
  def set_slabs(hpxml_bldg, model, args, sorted_surfaces)
    sorted_surfaces.each do |surface|
      next unless [EPlus::BoundaryConditionFoundation].include? surface.outsideBoundaryCondition
      next if surface.surfaceType != EPlus::SurfaceTypeFloor

      interior_adjacent_to = Geometry.get_surface_adjacent_to(surface)
      next if [HPXML::LocationOutside, HPXML::LocationOtherHousingUnit].include? interior_adjacent_to

      has_foundation_walls = false
      if [HPXML::LocationCrawlspaceVented,
          HPXML::LocationCrawlspaceUnvented,
          HPXML::LocationCrawlspaceConditioned,
          HPXML::LocationBasementUnconditioned,
          HPXML::LocationBasementConditioned].include? interior_adjacent_to
        has_foundation_walls = true
      end
      exposed_perimeter = Geometry.calculate_exposed_perimeter(model, ground_floor_surfaces: [surface], has_foundation_walls: has_foundation_walls).round(1)
      next if exposed_perimeter == 0

      if has_foundation_walls
        exposed_perimeter -= Geometry.get_unexposed_garage_perimeter(**args)
      end

      if args[:enclosure_slab_under_slab_insulation_width].to_f >= 999
        under_slab_insulation_spans_entire_slab = true
      else
        under_slab_insulation_width = args[:enclosure_slab_under_slab_insulation_width]
      end

      hpxml_bldg.slabs.add(id: "Slab#{hpxml_bldg.slabs.size + 1}",
                           interior_adjacent_to: interior_adjacent_to,
                           area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2'),
                           thickness: args[:enclosure_slab_thickness],
                           exposed_perimeter: exposed_perimeter,
                           perimeter_insulation_r_value: args[:enclosure_slab_perimeter_insulation_nominal_r_value],
                           perimeter_insulation_depth: args[:enclosure_slab_perimeter_insulation_depth],
                           exterior_horizontal_insulation_r_value: args[:enclosure_slab_exterior_horizontal_insulation_nominal_r_value],
                           exterior_horizontal_insulation_width: args[:enclosure_slab_exterior_horizontal_insulation_width],
                           exterior_horizontal_insulation_depth_below_grade: args[:enclosure_slab_exterior_horizontal_insulation_depth_below_grade],
                           under_slab_insulation_width: under_slab_insulation_width,
                           under_slab_insulation_r_value: args[:enclosure_slab_under_slab_insulation_nominal_r_value],
                           under_slab_insulation_spans_entire_slab: under_slab_insulation_spans_entire_slab,
                           carpet_fraction: args[:enclosure_slab_carpet_fraction],
                           carpet_r_value: args[:enclosure_slab_carpet_r_value])
      @surface_ids[surface.name.to_s] = hpxml_bldg.slabs[-1].id

      next unless interior_adjacent_to == HPXML::LocationCrawlspaceConditioned

      # Increase Conditioned Building Volume & Infiltration Volume
      conditioned_crawlspace_volume = hpxml_bldg.slabs[-1].area * args[:geometry_foundation_type_height]
      hpxml_bldg.building_construction.conditioned_building_volume += conditioned_crawlspace_volume
      hpxml_bldg.air_infiltration_measurements[0].infiltration_volume += conditioned_crawlspace_volume
    end
  end

  # Sets the HPXML windows properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param args [Hash] Map of :argument_name => value
  # @param sorted_subsurfaces [Array<OpenStudio::Model::SubSurface>] subsurfaces sorted by deterministically assigned Index
  # @return [nil]
  def set_windows(hpxml_bldg, model, args, sorted_subsurfaces)
    sorted_subsurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType != EPlus::SubSurfaceTypeWindow

      surface = sub_surface.surface.get

      sub_surface_height = Geometry.get_surface_height(sub_surface)
      sub_surface_facade = Geometry.get_surface_facade(sub_surface)

      if ((sub_surface_facade == Constants::FacadeFront) && (args[:enclosure_overhangs_front_depth].to_f > 0) ||
          (sub_surface_facade == Constants::FacadeBack) && (args[:enclosure_overhangs_back_depth].to_f > 0) ||
          (sub_surface_facade == Constants::FacadeLeft) && (args[:enclosure_overhangs_left_depth].to_f > 0) ||
          (sub_surface_facade == Constants::FacadeRight) && (args[:enclosure_overhangs_right_depth].to_f > 0))
        # Add window overhangs
        if sub_surface_facade == Constants::FacadeFront
          overhangs_depth = args[:enclosure_overhangs_front_depth]
        elsif sub_surface_facade == Constants::FacadeBack
          overhangs_depth = args[:enclosure_overhangs_back_depth]
        elsif sub_surface_facade == Constants::FacadeLeft
          overhangs_depth = args[:enclosure_overhangs_left_depth]
        elsif sub_surface_facade == Constants::FacadeRight
          overhangs_depth = args[:enclosure_overhangs_right_depth]
        end
        overhangs_distance_to_top_of_window = args[:enclosure_overhangs_distance_to_top_of_window]
        overhangs_distance_to_bottom_of_window = args[:enclosure_overhangs_distance_to_bottom_of_window]
      elsif args[:geometry_eaves_depth] > 0
        # Get max z coordinate of eaves
        eaves_z = args[:geometry_average_ceiling_height] * args[:geometry_unit_num_floors_above_grade] + args[:geometry_foundation_type_rim_joist_height]
        if args[:geometry_attic_type_attic_type] == HPXML::AtticTypeConditioned
          eaves_z += Geometry.get_conditioned_attic_height(model.getSpaces)
        end
        if args[:geometry_foundation_type_type] == HPXML::FoundationTypeAmbient
          eaves_z += args[:geometry_foundation_type_height]
        end

        # Get max z coordinate of this window
        sub_surface_z = Geometry.get_surface_z_values(surfaceArray: [sub_surface]).max + UnitConversions.convert(sub_surface.space.get.zOrigin, 'm', 'ft')

        overhangs_depth = args[:geometry_eaves_depth]
        overhangs_distance_to_top_of_window = eaves_z - sub_surface_z # difference between max z coordinates of eaves and this window
        overhangs_distance_to_bottom_of_window = (overhangs_distance_to_top_of_window + sub_surface_height).round(1)
      end

      azimuth = Geometry.get_azimuth_from_facade(sub_surface_facade, args[:geometry_unit_orientation])

      if args[:enclosure_window_exterior_shading] != 'None' # None is the OS-HPXML default, no need to write it
        exterior_shading_type = args[:enclosure_window_exterior_shading_type]
        exterior_shading_factor_winter = args[:enclosure_window_exterior_shading_winter_coefficient]
        exterior_shading_factor_summer = args[:enclosure_window_exterior_shading_summer_coefficient]
      end

      if args[:enclosure_window_insect_screens] != 'None' # None is the OS-HPXML default, no need to write it
        insect_screen_present = true
        insect_screen_location = args[:enclosure_window_insect_screens_location]
      end

      wall_idref = @surface_ids[surface.name.to_s]
      next if wall_idref.nil?

      hpxml_bldg.windows.add(id: "Window#{hpxml_bldg.windows.size + 1}",
                             area: UnitConversions.convert(sub_surface.grossArea, 'm^2', 'ft^2'),
                             azimuth: azimuth,
                             ufactor: args[:enclosure_window_u_factor],
                             shgc: args[:enclosure_window_shgc],
                             storm_type: args[:enclosure_window_storm_glass_type],
                             overhangs_depth: overhangs_depth,
                             overhangs_distance_to_top_of_window: overhangs_distance_to_top_of_window,
                             overhangs_distance_to_bottom_of_window: overhangs_distance_to_bottom_of_window,
                             interior_shading_type: args[:enclosure_window_interior_shading_type],
                             interior_shading_factor_winter: args[:enclosure_window_interior_shading_winter_coefficient],
                             interior_shading_factor_summer: args[:enclosure_window_interior_shading_summer_coefficient],
                             exterior_shading_type: exterior_shading_type,
                             exterior_shading_factor_winter: exterior_shading_factor_winter,
                             exterior_shading_factor_summer: exterior_shading_factor_summer,
                             insect_screen_present: insect_screen_present,
                             insect_screen_location: insect_screen_location,
                             fraction_operable: args[:enclosure_window_natural_ventilation_fraction_operable],
                             attached_to_wall_idref: wall_idref)
    end
  end

  # Sets the HPXML skylights properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @param sorted_subsurfaces [Array<OpenStudio::Model::SubSurface>] subsurfaces sorted by deterministically assigned Index
  # @return [nil]
  def set_skylights(hpxml_bldg, args, sorted_subsurfaces)
    sorted_subsurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType != 'Skylight'

      surface = sub_surface.surface.get

      sub_surface_facade = Geometry.get_surface_facade(sub_surface)
      azimuth = Geometry.get_azimuth_from_facade(sub_surface_facade, args[:geometry_unit_orientation])

      roof_idref = @surface_ids[surface.name.to_s]
      next if roof_idref.nil?

      roof = hpxml_bldg.roofs.find { |roof| roof.id == roof_idref }
      if roof.interior_adjacent_to != HPXML::LocationConditionedSpace
        # This is the roof of an attic, so the skylight must have a shaft; attach it to the attic floor as well.
        floor = hpxml_bldg.floors.find { |floor| floor.interior_adjacent_to == HPXML::LocationConditionedSpace && floor.exterior_adjacent_to == roof.interior_adjacent_to }
        floor_idref = floor.id
      end

      hpxml_bldg.skylights.add(id: "Skylight#{hpxml_bldg.skylights.size + 1}",
                               area: UnitConversions.convert(sub_surface.grossArea, 'm^2', 'ft^2'),
                               azimuth: azimuth,
                               ufactor: args[:enclosure_skylight_u_factor],
                               shgc: args[:enclosure_skylight_shgc],
                               attached_to_roof_idref: roof_idref,
                               attached_to_floor_idref: floor_idref)
    end
  end

  # Sets the HPXML doors properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param args [Hash] Map of :argument_name => value
  # @param sorted_subsurfaces [Array<OpenStudio::Model::SubSurface>] subsurfaces sorted by deterministically assigned Index
  # @return [nil]
  def set_doors(hpxml_bldg, model, args, sorted_subsurfaces)
    sorted_subsurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType != EPlus::SubSurfaceTypeDoor

      surface = sub_surface.surface.get

      interior_adjacent_to = Geometry.get_surface_adjacent_to(surface)

      if [HPXML::LocationOtherHousingUnit].include?(interior_adjacent_to)
        adjacent_surface = Geometry.get_adiabatic_adjacent_surface(model, surface)
        next if adjacent_surface.nil?
      end

      wall_idref = @surface_ids[surface.name.to_s]
      next if wall_idref.nil?

      hpxml_bldg.doors.add(id: "Door#{hpxml_bldg.doors.size + 1}",
                           attached_to_wall_idref: wall_idref,
                           area: UnitConversions.convert(sub_surface.grossArea, 'm^2', 'ft^2'),
                           azimuth: args[:geometry_unit_orientation],
                           r_value: args[:enclosure_door_r_value])
    end
  end

  # Sets the HPXML attics properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_attics(hpxml_bldg, args)
    surf_ids = { 'roofs' => { 'surfaces' => hpxml_bldg.roofs, 'ids' => [] },
                 'walls' => { 'surfaces' => hpxml_bldg.walls, 'ids' => [] },
                 'floors' => { 'surfaces' => hpxml_bldg.floors, 'ids' => [] } }

    attic_locations = [HPXML::LocationAtticUnconditioned, HPXML::LocationAtticUnvented, HPXML::LocationAtticVented]
    surf_ids.values.each do |surf_hash|
      surf_hash['surfaces'].each do |surface|
        next if (not attic_locations.include? surface.interior_adjacent_to) &&
                (not attic_locations.include? surface.exterior_adjacent_to)

        surf_hash['ids'] << surface.id
      end
    end

    # Add attached roofs for cathedral ceiling
    conditioned_space = HPXML::LocationConditionedSpace
    surf_ids['roofs']['surfaces'].each do |surface|
      next if (conditioned_space != surface.interior_adjacent_to) &&
              (conditioned_space != surface.exterior_adjacent_to)

      surf_ids['roofs']['ids'] << surface.id
    end

    hpxml_bldg.attics.add(id: "Attic#{hpxml_bldg.attics.size + 1}",
                          attic_type: args[:geometry_attic_type_attic_type],
                          attached_to_roof_idrefs: surf_ids['roofs']['ids'],
                          attached_to_wall_idrefs: surf_ids['walls']['ids'],
                          attached_to_floor_idrefs: surf_ids['floors']['ids'])
  end

  # Sets the HPXML foundations properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_foundations(hpxml_bldg, args)
    surf_ids = { 'slabs' => { 'surfaces' => hpxml_bldg.slabs, 'ids' => [] },
                 'floors' => { 'surfaces' => hpxml_bldg.floors, 'ids' => [] },
                 'foundation_walls' => { 'surfaces' => hpxml_bldg.foundation_walls, 'ids' => [] },
                 'walls' => { 'surfaces' => hpxml_bldg.walls, 'ids' => [] },
                 'rim_joists' => { 'surfaces' => hpxml_bldg.rim_joists, 'ids' => [] }, }

    foundation_locations = [HPXML::LocationBasementConditioned,
                            HPXML::LocationBasementUnconditioned,
                            HPXML::LocationCrawlspaceUnvented,
                            HPXML::LocationCrawlspaceVented,
                            HPXML::LocationCrawlspaceConditioned]

    surf_ids.each do |surf_type, surf_hash|
      surf_hash['surfaces'].each do |surface|
        next unless (foundation_locations.include? surface.interior_adjacent_to) ||
                    (foundation_locations.include? surface.exterior_adjacent_to) ||
                    (surf_type == 'slabs' && surface.interior_adjacent_to == HPXML::LocationConditionedSpace) ||
                    (surf_type == 'floors' && [HPXML::LocationOutside, HPXML::LocationManufacturedHomeUnderBelly].include?(surface.exterior_adjacent_to))

        surf_hash['ids'] << surface.id
      end
    end

    if args[:geometry_foundation_type_type].start_with?(HPXML::FoundationTypeBellyAndWing)
      foundation_type = HPXML::FoundationTypeBellyAndWing
      if args[:geometry_foundation_type_type].end_with?('WithSkirt')
        belly_wing_skirt_present = true
      elsif args[:geometry_foundation_type_type].end_with?('NoSkirt')
        belly_wing_skirt_present = false
      else
        fail 'Unepected belly and wing foundation type.'
      end
    else
      foundation_type = args[:geometry_foundation_type_type]
    end

    hpxml_bldg.foundations.add(id: "Foundation#{hpxml_bldg.foundations.size + 1}",
                               foundation_type: foundation_type,
                               attached_to_slab_idrefs: surf_ids['slabs']['ids'],
                               attached_to_floor_idrefs: surf_ids['floors']['ids'],
                               attached_to_foundation_wall_idrefs: surf_ids['foundation_walls']['ids'],
                               attached_to_wall_idrefs: surf_ids['walls']['ids'],
                               attached_to_rim_joist_idrefs: surf_ids['rim_joists']['ids'],
                               belly_wing_skirt_present: belly_wing_skirt_present)
  end

  # Sets the HPXML primary heating systems properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_heating_systems(hpxml_bldg, args)
    return if args[:hvac_heating_system] == 'None'

    heating_system_type = args[:hvac_heating_system_type]

    if [HPXML::HVACTypeElectricResistance].include? heating_system_type
      args[:hvac_heating_system_fuel] = HPXML::FuelTypeElectricity
    end

    if [HPXML::HVACTypeFurnace,
        HPXML::HVACTypeWallFurnace,
        HPXML::HVACTypeFloorFurnace].include?(heating_system_type) || heating_system_type.include?(HPXML::HVACTypeBoiler)
      heating_efficiency_afue = args[:hvac_heating_system_heating_efficiency]
    elsif [HPXML::HVACTypeElectricResistance,
           HPXML::HVACTypeStove,
           HPXML::HVACTypeSpaceHeater,
           HPXML::HVACTypeFireplace].include?(heating_system_type)
      heating_efficiency_percent = args[:hvac_heating_system_heating_efficiency]
    end

    if [HPXML::HVACTypeFurnace].include? heating_system_type
      airflow_defect_ratio = args[:hvac_installation_defects_airflow_defect_ratio]
    end

    if args[:hvac_heating_system_fuel] != HPXML::FuelTypeElectricity
      pilot_light_btuh = args[:hvac_heating_system_pilot_light].to_f
      if pilot_light_btuh > 0
        pilot_light = true
      end
    end

    fraction_heat_load_served = args[:hvac_heating_system_fraction_heat_load_served]

    if heating_system_type.include?('Shared')
      is_shared_system = true
      number_of_units_served = args[:geometry_building_num_units]
      args[:hvac_heating_system_capacity_capacity] = nil
    end

    if heating_system_type.include?(HPXML::HVACTypeBoiler)
      heating_system_type = HPXML::HVACTypeBoiler
    end

    hpxml_bldg.heating_systems.add(id: "HeatingSystem#{hpxml_bldg.heating_systems.size + 1}",
                                   heating_system_type: heating_system_type,
                                   heating_system_fuel: args[:hvac_heating_system_fuel],
                                   heating_capacity: args[:hvac_heating_system_capacity_capacity],
                                   heating_autosizing_factor: args[:hvac_heating_system_capacity_autosizing_factor],
                                   heating_autosizing_limit: args[:hvac_heating_system_capacity_autosizing_limit],
                                   fraction_heat_load_served: fraction_heat_load_served,
                                   heating_efficiency_afue: heating_efficiency_afue,
                                   heating_efficiency_percent: heating_efficiency_percent,
                                   airflow_defect_ratio: airflow_defect_ratio,
                                   pilot_light: pilot_light,
                                   pilot_light_btuh: pilot_light_btuh,
                                   is_shared_system: is_shared_system,
                                   number_of_units_served: number_of_units_served,
                                   primary_system: true)
  end

  # Sets the HPXML primary cooling systems properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_cooling_systems(hpxml_bldg, args)
    return if args[:hvac_cooling_system] == 'None'

    cooling_system_type = args[:hvac_cooling_system_type]

    if [HPXML::HVACTypeCentralAirConditioner, HPXML::HVACTypeMiniSplitAirConditioner].include? cooling_system_type
      compressor_type = args[:hvac_cooling_system_cooling_compressor_type]
    end

    if cooling_system_type != HPXML::HVACTypeEvaporativeCooler
      case args[:hvac_cooling_system_cooling_efficiency_type]
      when HPXML::UnitsSEER
        cooling_efficiency_seer = args[:hvac_cooling_system_cooling_efficiency]
      when HPXML::UnitsSEER2
        cooling_efficiency_seer2 = args[:hvac_cooling_system_cooling_efficiency]
      when HPXML::UnitsEER
        cooling_efficiency_eer = args[:hvac_cooling_system_cooling_efficiency]
      when HPXML::UnitsCEER
        cooling_efficiency_ceer = args[:hvac_cooling_system_cooling_efficiency]
      end
    end

    if [HPXML::HVACTypeCentralAirConditioner].include?(cooling_system_type) || ([HPXML::HVACTypeMiniSplitAirConditioner].include?(cooling_system_type) && (args[:hvac_cooling_system_is_ducted]))
      airflow_defect_ratio = args[:hvac_installation_defects_airflow_defect_ratio]
    end

    if [HPXML::HVACTypeCentralAirConditioner, HPXML::HVACTypeMiniSplitAirConditioner].include?(cooling_system_type)
      charge_defect_ratio = args[:hvac_installation_defects_charge_defect_ratio]
    end

    if [HPXML::HVACTypeCentralAirConditioner, HPXML::HVACTypeMiniSplitAirConditioner, HPXML::HVACTypeRoomAirConditioner, HPXML::HVACTypePTAC].include?(cooling_system_type)
      cooling_system_crankcase_heater_watts = args[:hvac_cooling_system_crankcase_heater_watts]
    end

    if [HPXML::HVACTypePTAC, HPXML::HVACTypeRoomAirConditioner].include?(cooling_system_type) && args[:hvac_cooling_system_integrated_heating_fraction_heat_load_served].to_f > 0
      integrated_heating_system_fuel = args[:hvac_cooling_system_integrated_heating_system_fuel]
      integrated_heating_system_fraction_heat_load_served = args[:hvac_cooling_system_integrated_heating_fraction_heat_load_served]
      integrated_heating_system_capacity = args[:hvac_cooling_system_integrated_heating_capacity_capacity]
      integrated_heating_system_efficiency_percent = args[:hvac_cooling_system_integrated_heating_system_efficiency]
    end

    hpxml_bldg.cooling_systems.add(id: "CoolingSystem#{hpxml_bldg.cooling_systems.size + 1}",
                                   cooling_system_type: cooling_system_type,
                                   cooling_system_fuel: HPXML::FuelTypeElectricity,
                                   cooling_capacity: args[:hvac_cooling_system_capacity_capacity],
                                   cooling_autosizing_factor: args[:hvac_cooling_system_capacity_autosizing_factor],
                                   cooling_autosizing_limit: args[:hvac_cooling_system_capacity_autosizing_limit],
                                   fraction_cool_load_served: args[:hvac_cooling_system_fraction_cool_load_served],
                                   compressor_type: compressor_type,
                                   cooling_efficiency_seer: cooling_efficiency_seer,
                                   cooling_efficiency_seer2: cooling_efficiency_seer2,
                                   cooling_efficiency_eer: cooling_efficiency_eer,
                                   cooling_efficiency_ceer: cooling_efficiency_ceer,
                                   airflow_defect_ratio: airflow_defect_ratio,
                                   charge_defect_ratio: charge_defect_ratio,
                                   crankcase_heater_watts: cooling_system_crankcase_heater_watts,
                                   primary_system: true,
                                   integrated_heating_system_fuel: integrated_heating_system_fuel,
                                   integrated_heating_system_capacity: integrated_heating_system_capacity,
                                   integrated_heating_system_efficiency_percent: integrated_heating_system_efficiency_percent,
                                   integrated_heating_system_fraction_heat_load_served: integrated_heating_system_fraction_heat_load_served)

    # Detailed performance data
    if not [HPXML::HVACTypeCentralAirConditioner, HPXML::HVACTypeMiniSplitAirConditioner].include? cooling_system_type
      return
    end

    if not args[:hvac_cooling_system_detailed_performance_data_cooling_outdoor_temperatures].nil?
      cooling_system_detailed_performance_data_points = args[:hvac_cooling_system_detailed_performance_data_cooling_outdoor_temperatures].to_s.split(',').map(&:strip).zip(
        args[:hvac_cooling_system_detailed_performance_data_cooling_min_speed_capacities].to_s.split(',').map(&:strip),
        args[:hvac_cooling_system_detailed_performance_data_cooling_nom_speed_capacities].to_s.split(',').map(&:strip),
        args[:hvac_cooling_system_detailed_performance_data_cooling_max_speed_capacities].to_s.split(',').map(&:strip),
        args[:hvac_cooling_system_detailed_performance_data_cooling_min_speed_cops].to_s.split(',').map(&:strip),
        args[:hvac_cooling_system_detailed_performance_data_cooling_nom_speed_cops].to_s.split(',').map(&:strip),
        args[:hvac_cooling_system_detailed_performance_data_cooling_max_speed_cops].to_s.split(',').map(&:strip)
      )

      clg_perf_data = hpxml_bldg.cooling_systems[0].cooling_detailed_performance_data
      cooling_system_detailed_performance_data_points.each do |cooling_detailed_performance_data_point|
        outdoor_temperature, min_speed_cap, nom_speed_cap, max_speed_cap, min_speed_cop, nom_speed_cop, max_speed_cop = cooling_detailed_performance_data_point

        case args[:hvac_cooling_system_detailed_performance_data_capacity_type]
        when 'Absolute capacities'
          min_speed_capacity = Float(min_speed_cap) unless min_speed_cap.nil?
          nom_speed_capacity = Float(nom_speed_cap) unless nom_speed_cap.nil?
          max_speed_capacity = Float(max_speed_cap) unless max_speed_cap.nil?
        when 'Normalized capacity fractions'
          min_speed_capacity_fraction_of_nominal = Float(min_speed_cap) unless min_speed_cap.nil?
          nom_speed_capacity_fraction_of_nominal = Float(nom_speed_cap) unless nom_speed_cap.nil?
          max_speed_capacity_fraction_of_nominal = Float(max_speed_cap) unless max_speed_cap.nil?
        end

        if (not min_speed_capacity.nil?) || (not min_speed_capacity_fraction_of_nominal.nil?)
          clg_perf_data.add(outdoor_temperature: Float(outdoor_temperature),
                            capacity: min_speed_capacity,
                            capacity_fraction_of_nominal: min_speed_capacity_fraction_of_nominal,
                            capacity_description: HPXML::CapacityDescriptionMinimum,
                            efficiency_cop: (min_speed_cop.nil? ? nil : Float(min_speed_cop)))
        end
        if (not nom_speed_capacity.nil?) || (not nom_speed_capacity_fraction_of_nominal.nil?)
          clg_perf_data.add(outdoor_temperature: Float(outdoor_temperature),
                            capacity: nom_speed_capacity,
                            capacity_fraction_of_nominal: nom_speed_capacity_fraction_of_nominal,
                            capacity_description: HPXML::CapacityDescriptionNominal,
                            efficiency_cop: (nom_speed_cop.nil? ? nil : Float(nom_speed_cop)))
        end
        next unless (not max_speed_capacity.nil?) || (not max_speed_capacity_fraction_of_nominal.nil?)

        clg_perf_data.add(outdoor_temperature: Float(outdoor_temperature),
                          capacity: max_speed_capacity,
                          capacity_fraction_of_nominal: max_speed_capacity_fraction_of_nominal,
                          capacity_description: HPXML::CapacityDescriptionMaximum,
                          efficiency_cop: (max_speed_cop.nil? ? nil : Float(max_speed_cop)))
      end
      if args[:hvac_cooling_system_detailed_performance_data_capacity_type] == 'Absolute capacities'
        hpxml_bldg.cooling_systems[0].cooling_capacity = nil
      end
    end
  end

  # Sets the HPXML primary heat pumps properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_heat_pumps(hpxml_bldg, args)
    return if args[:hvac_heat_pump] == 'None'

    heat_pump_type = args[:hvac_heat_pump_type]

    case args[:hvac_heat_pump_backup_type]
    when HPXML::HeatPumpBackupTypeIntegrated
      backup_type = args[:hvac_heat_pump_backup_type]
      backup_heating_fuel = args[:hvac_heat_pump_backup_fuel]
      backup_heating_capacity = args[:hvac_heat_pump_backup_capacity_capacity]

      if backup_heating_fuel == HPXML::FuelTypeElectricity
        backup_heating_efficiency_percent = args[:hvac_heat_pump_backup_heating_efficiency]
      else
        backup_heating_efficiency_afue = args[:hvac_heat_pump_backup_heating_efficiency]
      end
    when HPXML::HeatPumpBackupTypeSeparate
      if args[:hvac_heating_system_2] == 'None'
        fail "Heat pump backup type specified as '#{args[:hvac_heat_pump_backup_type]}' but no heating system provided."
      end

      backup_type = args[:hvac_heat_pump_backup_type]
      backup_system_idref = "HeatingSystem#{hpxml_bldg.heating_systems.size + 1}"
    end

    if backup_heating_fuel != HPXML::FuelTypeElectricity
      if (not args[:hvac_heat_pump_temperatures_compressor_lockout].nil?) && (not args[:hvac_heat_pump_temperatures_backup_lockout].nil?) && args[:hvac_heat_pump_temperatures_compressor_lockout] == args[:hvac_heat_pump_temperatures_backup_lockout]
        # Translate to HPXML as switchover temperature instead
        backup_heating_switchover_temp = args[:hvac_heat_pump_temperatures_compressor_lockout]
        args[:hvac_heat_pump_temperatures_compressor_lockout] = nil
        args[:hvac_heat_pump_temperatures_backup_lockout] = nil
      end
    end

    if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpMiniSplit, HPXML::HVACTypeHeatPumpGroundToAir].include? heat_pump_type
      compressor_type = args[:hvac_heat_pump_cooling_compressor_type]
    end

    case args[:hvac_heat_pump_heating_efficiency_type]
    when HPXML::UnitsHSPF
      heating_efficiency_hspf = args[:hvac_heat_pump_heating_efficiency]
    when HPXML::UnitsHSPF2
      heating_efficiency_hspf2 = args[:hvac_heat_pump_heating_efficiency]
    when HPXML::UnitsCOP
      heating_efficiency_cop = args[:hvac_heat_pump_heating_efficiency]
    end

    case args[:hvac_heat_pump_cooling_efficiency_type]
    when HPXML::UnitsSEER
      cooling_efficiency_seer = args[:hvac_heat_pump_cooling_efficiency]
    when HPXML::UnitsSEER2
      cooling_efficiency_seer2 = args[:hvac_heat_pump_cooling_efficiency]
    when HPXML::UnitsEER
      cooling_efficiency_eer = args[:hvac_heat_pump_cooling_efficiency]
    end

    if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpGroundToAir].include?(heat_pump_type) || ([HPXML::HVACTypeHeatPumpMiniSplit].include?(heat_pump_type) && (args[:hvac_heat_pump_is_ducted]))
      airflow_defect_ratio = args[:hvac_installation_defects_airflow_defect_ratio]
    end

    if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpMiniSplit, HPXML::HVACTypeHeatPumpPTHP, HPXML::HVACTypeHeatPumpRoom].include?(heat_pump_type)
      heat_pump_crankcase_heater_watts = args[:hvac_heat_pump_crankcase_heater_watts]
    end

    hpxml_bldg.heat_pumps.add(id: "HeatPump#{hpxml_bldg.heat_pumps.size + 1}",
                              heat_pump_type: heat_pump_type,
                              heat_pump_fuel: HPXML::FuelTypeElectricity,
                              heating_capacity: args[:hvac_heat_pump_capacity_capacity],
                              heating_autosizing_factor: args[:hvac_heat_pump_capacity_autosizing_factor],
                              heating_autosizing_limit: args[:hvac_heat_pump_capacity_autosizing_limit],
                              heating_capacity_fraction_17F: args[:hvac_heat_pump_heating_capacity_fraction_17_f],
                              compressor_type: compressor_type,
                              compressor_lockout_temp: args[:hvac_heat_pump_temperatures_compressor_lockout],
                              cooling_capacity: args[:hvac_heat_pump_capacity_capacity],
                              cooling_autosizing_factor: args[:hvac_heat_pump_capacity_autosizing_factor],
                              cooling_autosizing_limit: args[:hvac_heat_pump_capacity_autosizing_limit],
                              fraction_heat_load_served: args[:hvac_heat_pump_fraction_heat_load_served],
                              fraction_cool_load_served: args[:hvac_heat_pump_fraction_cool_load_served],
                              backup_type: backup_type,
                              backup_system_idref: backup_system_idref,
                              backup_heating_fuel: backup_heating_fuel,
                              backup_heating_capacity: backup_heating_capacity,
                              backup_heating_autosizing_factor: args[:hvac_heat_pump_backup_capacity_autosizing_factor],
                              backup_heating_autosizing_limit: args[:hvac_heat_pump_backup_capacity_autosizing_limit],
                              backup_heating_efficiency_afue: backup_heating_efficiency_afue,
                              backup_heating_efficiency_percent: backup_heating_efficiency_percent,
                              backup_heating_switchover_temp: backup_heating_switchover_temp,
                              backup_heating_lockout_temp: args[:hvac_heat_pump_temperatures_backup_lockout],
                              heating_efficiency_hspf: heating_efficiency_hspf,
                              heating_efficiency_hspf2: heating_efficiency_hspf2,
                              cooling_efficiency_seer: cooling_efficiency_seer,
                              cooling_efficiency_seer2: cooling_efficiency_seer2,
                              heating_efficiency_cop: heating_efficiency_cop,
                              cooling_efficiency_eer: cooling_efficiency_eer,
                              airflow_defect_ratio: airflow_defect_ratio,
                              charge_defect_ratio: args[:hvac_installation_defects_charge_defect_ratio],
                              crankcase_heater_watts: heat_pump_crankcase_heater_watts,
                              primary_heating_system: args[:hvac_heat_pump_fraction_heat_load_served] > 0,
                              primary_cooling_system: args[:hvac_heat_pump_fraction_cool_load_served] > 0)

    # Detailed performance data
    if not [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpMiniSplit].include? heat_pump_type
      return
    end

    if (not args[:hvac_heat_pump_detailed_performance_data_heating_outdoor_temperatures].nil?) && (args[:hvac_heat_pump_fraction_heat_load_served] > 0)
      heating_detailed_performance_data_points = args[:hvac_heat_pump_detailed_performance_data_heating_outdoor_temperatures].to_s.split(',').map(&:strip).zip(
        args[:hvac_heat_pump_detailed_performance_data_heating_min_speed_capacities].to_s.split(',').map(&:strip),
        args[:hvac_heat_pump_detailed_performance_data_heating_nom_speed_capacities].to_s.split(',').map(&:strip),
        args[:hvac_heat_pump_detailed_performance_data_heating_max_speed_capacities].to_s.split(',').map(&:strip),
        args[:hvac_heat_pump_detailed_performance_data_heating_min_speed_cops].to_s.split(',').map(&:strip),
        args[:hvac_heat_pump_detailed_performance_data_heating_nom_speed_cops].to_s.split(',').map(&:strip),
        args[:hvac_heat_pump_detailed_performance_data_heating_max_speed_cops].to_s.split(',').map(&:strip)
      )

      htg_htg_perf_data = hpxml_bldg.heat_pumps[0].heating_detailed_performance_data
      heating_detailed_performance_data_points.each do |heating_detailed_performance_data_point|
        outdoor_temperature, min_speed_cap, nom_speed_cap, max_speed_cap, min_speed_cop, nom_speed_cop, max_speed_cop = heating_detailed_performance_data_point

        case args[:hvac_heat_pump_detailed_performance_data_capacity_type]
        when 'Absolute capacities'
          min_speed_capacity = Float(min_speed_cap) unless min_speed_cap.nil?
          nom_speed_capacity = Float(nom_speed_cap) unless nom_speed_cap.nil?
          max_speed_capacity = Float(max_speed_cap) unless max_speed_cap.nil?
        when 'Normalized capacity fractions'
          min_speed_capacity_fraction_of_nominal = Float(min_speed_cap) unless min_speed_cap.nil?
          nom_speed_capacity_fraction_of_nominal = Float(nom_speed_cap) unless nom_speed_cap.nil?
          max_speed_capacity_fraction_of_nominal = Float(max_speed_cap) unless max_speed_cap.nil?
        end

        if (not min_speed_capacity.nil?) || (not min_speed_capacity_fraction_of_nominal.nil?)
          htg_htg_perf_data.add(outdoor_temperature: Float(outdoor_temperature),
                                capacity: min_speed_capacity,
                                capacity_fraction_of_nominal: min_speed_capacity_fraction_of_nominal,
                                capacity_description: HPXML::CapacityDescriptionMinimum,
                                efficiency_cop: (min_speed_cop.nil? ? nil : Float(min_speed_cop)))
        end
        if (not nom_speed_capacity.nil?) || (not nom_speed_capacity_fraction_of_nominal.nil?)
          htg_htg_perf_data.add(outdoor_temperature: Float(outdoor_temperature),
                                capacity: nom_speed_capacity,
                                capacity_fraction_of_nominal: nom_speed_capacity_fraction_of_nominal,
                                capacity_description: HPXML::CapacityDescriptionNominal,
                                efficiency_cop: (nom_speed_cop.nil? ? nil : Float(nom_speed_cop)))
        end
        next unless (not max_speed_capacity.nil?) || (not max_speed_capacity_fraction_of_nominal.nil?)

        htg_htg_perf_data.add(outdoor_temperature: Float(outdoor_temperature),
                              capacity: max_speed_capacity,
                              capacity_fraction_of_nominal: max_speed_capacity_fraction_of_nominal,
                              capacity_description: HPXML::CapacityDescriptionMaximum,
                              efficiency_cop: (max_speed_cop.nil? ? nil : Float(max_speed_cop)))
      end
      if args[:hvac_heat_pump_detailed_performance_data_capacity_type] == 'Absolute capacities'
        hpxml_bldg.heat_pumps[0].heating_capacity = nil
      end
    end

    if (not args[:hvac_heat_pump_detailed_performance_data_cooling_outdoor_temperatures].nil?) && (args[:hvac_heat_pump_fraction_cool_load_served] > 0)
      hp_cooling_detailed_performance_data_points = args[:hvac_heat_pump_detailed_performance_data_cooling_outdoor_temperatures].to_s.split(',').map(&:strip).zip(
        args[:hvac_heat_pump_detailed_performance_data_cooling_min_speed_capacities].to_s.split(',').map(&:strip),
        args[:hvac_heat_pump_detailed_performance_data_cooling_nom_speed_capacities].to_s.split(',').map(&:strip),
        args[:hvac_heat_pump_detailed_performance_data_cooling_max_speed_capacities].to_s.split(',').map(&:strip),
        args[:hvac_heat_pump_detailed_performance_data_cooling_min_speed_cops].to_s.split(',').map(&:strip),
        args[:hvac_heat_pump_detailed_performance_data_cooling_nom_speed_cops].to_s.split(',').map(&:strip),
        args[:hvac_heat_pump_detailed_performance_data_cooling_max_speed_cops].to_s.split(',').map(&:strip)
      )

      hp_clg_perf_data = hpxml_bldg.heat_pumps[0].cooling_detailed_performance_data
      hp_cooling_detailed_performance_data_points.each do |hp_cooling_detailed_performance_data_point|
        outdoor_temperature, min_speed_cap, nom_speed_cap, max_speed_cap, min_speed_cop, nom_speed_cop, max_speed_cop = hp_cooling_detailed_performance_data_point

        case args[:hvac_heat_pump_detailed_performance_data_capacity_type]
        when 'Absolute capacities'
          min_speed_capacity = Float(min_speed_cap) unless min_speed_cap.nil?
          nom_speed_capacity = Float(nom_speed_cap) unless nom_speed_cap.nil?
          max_speed_capacity = Float(max_speed_cap) unless max_speed_cap.nil?
        when 'Normalized capacity fractions'
          min_speed_capacity_fraction_of_nominal = Float(min_speed_cap) unless min_speed_cap.nil?
          nom_speed_capacity_fraction_of_nominal = Float(nom_speed_cap) unless nom_speed_cap.nil?
          max_speed_capacity_fraction_of_nominal = Float(max_speed_cap) unless max_speed_cap.nil?
        end

        if (not min_speed_capacity.nil?) || (not min_speed_capacity_fraction_of_nominal.nil?)
          hp_clg_perf_data.add(outdoor_temperature: Float(outdoor_temperature),
                               capacity: min_speed_capacity,
                               capacity_fraction_of_nominal: min_speed_capacity_fraction_of_nominal,
                               capacity_description: HPXML::CapacityDescriptionMinimum,
                               efficiency_cop: (min_speed_cop.nil? ? nil : Float(min_speed_cop)))
        end
        if (not nom_speed_capacity.nil?) || (not nom_speed_capacity_fraction_of_nominal.nil?)
          hp_clg_perf_data.add(outdoor_temperature: Float(outdoor_temperature),
                               capacity: nom_speed_capacity,
                               capacity_fraction_of_nominal: nom_speed_capacity_fraction_of_nominal,
                               capacity_description: HPXML::CapacityDescriptionNominal,
                               efficiency_cop: (nom_speed_cop.nil? ? nil : Float(nom_speed_cop)))
        end
        next unless (not max_speed_capacity.nil?) || (not max_speed_capacity_fraction_of_nominal.nil?)

        hp_clg_perf_data.add(outdoor_temperature: Float(outdoor_temperature),
                             capacity: max_speed_capacity,
                             capacity_fraction_of_nominal: max_speed_capacity_fraction_of_nominal,
                             capacity_description: HPXML::CapacityDescriptionMaximum,
                             efficiency_cop: (max_speed_cop.nil? ? nil : Float(max_speed_cop)))
      end
      if args[:hvac_heat_pump_detailed_performance_data_capacity_type] == 'Absolute capacities'
        hpxml_bldg.heat_pumps[0].cooling_capacity = nil
      end
    end
  end

  # Sets the HPXML geothermal loop properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_geothermal_loop(hpxml_bldg, args)
    return if hpxml_bldg.heat_pumps.count { |hp| hp.heat_pump_type == HPXML::HVACTypeHeatPumpGroundToAir } == 0
    return if args[:hvac_geothermal_loop_configuration].nil? || args[:hvac_geothermal_loop] == 'None'

    if not args[:hvac_geothermal_loop_pipe_diameter].nil?
      case args[:hvac_geothermal_loop_pipe_diameter]
      when '3/4" pipe'
        pipe_diameter = 0.75
      when '1" pipe'
        pipe_diameter = 1.0
      when '1-1/4" pipe'
        pipe_diameter = 1.25
      end
    end

    hpxml_bldg.geothermal_loops.add(id: "GeothermalLoop#{hpxml_bldg.geothermal_loops.size + 1}",
                                    loop_configuration: args[:hvac_geothermal_loop_configuration],
                                    loop_flow: args[:hvac_geothermal_loop_loop_flow],
                                    bore_config: args[:hvac_geothermal_loop_borefield_configuration],
                                    num_bore_holes: args[:hvac_geothermal_loop_boreholes_count],
                                    bore_length: args[:hvac_geothermal_loop_boreholes_length],
                                    bore_spacing: args[:hvac_geothermal_loop_boreholes_spacing],
                                    bore_diameter: args[:hvac_geothermal_loop_boreholes_diameter],
                                    grout_type: args[:hvac_geothermal_loop_grout_type],
                                    pipe_type: args[:hvac_geothermal_loop_pipe_type],
                                    pipe_diameter: pipe_diameter,
                                    shank_spacing: args[:hvac_geothermal_loop_pipe_shank_spacing])
    hpxml_bldg.heat_pumps[-1].geothermal_loop_idref = hpxml_bldg.geothermal_loops[-1].id
  end

  # Sets the HPXML secondary heating system properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_secondary_heating_systems(hpxml_bldg, args)
    heating_system_is_heatpump_backup = (args[:hvac_heat_pump] != 'None' && args[:hvac_heat_pump_backup_type] == HPXML::HeatPumpBackupTypeSeparate)

    return if args[:hvac_heating_system_2] == 'None' && (not heating_system_is_heatpump_backup)

    heating_system_type = args[:hvac_heating_system_2_type]

    if args[:hvac_heating_system_2_fuel] == HPXML::HVACTypeElectricResistance
      args[:hvac_heating_system_2_fuel] = HPXML::FuelTypeElectricity
    end

    if [HPXML::HVACTypeFurnace, HPXML::HVACTypeWallFurnace, HPXML::HVACTypeFloorFurnace].include?(heating_system_type) || heating_system_type.include?(HPXML::HVACTypeBoiler)
      heating_efficiency_afue = args[:hvac_heating_system_2_heating_efficiency]
    elsif [HPXML::HVACTypeElectricResistance, HPXML::HVACTypeStove, HPXML::HVACTypeSpaceHeater, HPXML::HVACTypeFireplace].include?(heating_system_type)
      heating_efficiency_percent = args[:hvac_heating_system_2_heating_efficiency]
    end

    if heating_system_type.include?(HPXML::HVACTypeBoiler)
      heating_system_type = HPXML::HVACTypeBoiler
    end

    if not heating_system_is_heatpump_backup
      fraction_heat_load_served = args[:hvac_heating_system_2_fraction_heat_load_served]
    end

    if args[:hvac_heating_system_2_fuel] != HPXML::FuelTypeElectricity
      pilot_light_btuh = args[:hvac_heating_system_2_pilot_light].to_f
      if pilot_light_btuh > 0
        pilot_light = true
      end
    end

    hpxml_bldg.heating_systems.add(id: "HeatingSystem#{hpxml_bldg.heating_systems.size + 1}",
                                   heating_system_type: heating_system_type,
                                   heating_system_fuel: args[:hvac_heating_system_2_fuel],
                                   heating_capacity: args[:hvac_heating_system_2_capacity_capacity],
                                   heating_autosizing_factor: args[:hvac_heating_system_2_capacity_autosizing_factor],
                                   heating_autosizing_limit: args[:hvac_heating_system_2_capacity_autosizing_limit],
                                   fraction_heat_load_served: fraction_heat_load_served,
                                   heating_efficiency_afue: heating_efficiency_afue,
                                   heating_efficiency_percent: heating_efficiency_percent,
                                   pilot_light: pilot_light,
                                   pilot_light_btuh: pilot_light_btuh)
  end

  # Sets the HPXML HVAC distribution properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_hvac_distribution(hpxml_bldg, args)
    # HydronicDistribution?
    hpxml_bldg.heating_systems.each do |heating_system|
      next unless [heating_system.heating_system_type].include?(HPXML::HVACTypeBoiler)
      next if args[:hvac_heating_system_type].include?('Fan Coil')

      hpxml_bldg.hvac_distributions.add(id: "HVACDistribution#{hpxml_bldg.hvac_distributions.size + 1}",
                                        distribution_system_type: HPXML::HVACDistributionTypeHydronic,
                                        hydronic_type: HPXML::HydronicTypeBaseboard)
      heating_system.distribution_system_idref = hpxml_bldg.hvac_distributions[-1].id
    end

    # AirDistribution?
    air_distribution_systems = []
    hpxml_bldg.heating_systems.each do |heating_system|
      case heating_system.heating_system_type
      when HPXML::HVACTypeFurnace
        air_distribution_systems << heating_system
      end
    end
    hpxml_bldg.cooling_systems.each do |cooling_system|
      case cooling_system.cooling_system_type
      when HPXML::HVACTypeCentralAirConditioner
        air_distribution_systems << cooling_system
      when HPXML::HVACTypeEvaporativeCooler, HPXML::HVACTypeMiniSplitAirConditioner
        air_distribution_systems << cooling_system if args[:hvac_cooling_system_is_ducted]
      end
    end
    hpxml_bldg.heat_pumps.each do |heat_pump|
      case heat_pump.heat_pump_type
      when HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpGroundToAir
        air_distribution_systems << heat_pump
      when HPXML::HVACTypeHeatPumpMiniSplit
        air_distribution_systems << heat_pump if args[:hvac_heat_pump_is_ducted]
      end
    end

    # FanCoil?
    fan_coil_distribution_systems = []
    hpxml_bldg.heating_systems.each do |heating_system|
      next unless heating_system.primary_system

      if args[:hvac_heating_system_type].include?('Fan Coil')
        fan_coil_distribution_systems << heating_system
      end
    end

    return if air_distribution_systems.size == 0 && fan_coil_distribution_systems.size == 0

    if [HPXML::HVACTypeEvaporativeCooler].include?(args[:hvac_cooling_system_type]) && hpxml_bldg.heating_systems.size == 0 && hpxml_bldg.heat_pumps.size == 0
      args[:hvac_ducts_number_of_return_registers] = nil
      if args[:hvac_cooling_system_is_ducted]
        args[:hvac_ducts_number_of_return_registers] = 0
      end
    end

    if air_distribution_systems.size > 0
      hpxml_bldg.hvac_distributions.add(id: "HVACDistribution#{hpxml_bldg.hvac_distributions.size + 1}",
                                        distribution_system_type: HPXML::HVACDistributionTypeAir,
                                        air_type: HPXML::AirTypeRegularVelocity,
                                        number_of_return_registers: args[:hvac_ducts_number_of_return_registers])
      air_distribution_systems.each do |hvac_system|
        hvac_system.distribution_system_idref = hpxml_bldg.hvac_distributions[-1].id
      end
      set_duct_leakages(args, hpxml_bldg.hvac_distributions[-1])
      set_ducts(hpxml_bldg, args, hpxml_bldg.hvac_distributions[-1])
    end

    if fan_coil_distribution_systems.size > 0
      hpxml_bldg.hvac_distributions.add(id: "HVACDistribution#{hpxml_bldg.hvac_distributions.size + 1}",
                                        distribution_system_type: HPXML::HVACDistributionTypeAir,
                                        air_type: HPXML::AirTypeFanCoil)
      fan_coil_distribution_systems.each do |hvac_system|
        hvac_system.distribution_system_idref = hpxml_bldg.hvac_distributions[-1].id
      end
    end
  end

  # Sets the HPXML HVAC blower properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_hvac_blower(hpxml_bldg, args)
    # Blower fan W/cfm
    hpxml_bldg.hvac_systems.each do |hvac_system|
      next unless (!hvac_system.distribution_system.nil? && hvac_system.distribution_system.distribution_system_type == HPXML::HVACDistributionTypeAir) ||
                  (hvac_system.is_a?(HPXML::HeatPump) && hvac_system.heat_pump_type == HPXML::HVACTypeHeatPumpMiniSplit)

      fan_watts_per_cfm = args[:hvac_blower_fan_watts_per_cfm]

      if hvac_system.is_a?(HPXML::HeatingSystem)
        if [HPXML::HVACTypeFurnace].include?(hvac_system.heating_system_type)
          hvac_system.fan_watts_per_cfm = fan_watts_per_cfm
        end
      elsif hvac_system.is_a?(HPXML::CoolingSystem)
        if [HPXML::HVACTypeCentralAirConditioner,
            HPXML::HVACTypeMiniSplitAirConditioner].include?(hvac_system.cooling_system_type)
          hvac_system.fan_watts_per_cfm = fan_watts_per_cfm
        end
      elsif hvac_system.is_a?(HPXML::HeatPump)
        if [HPXML::HVACTypeHeatPumpAirToAir,
            HPXML::HVACTypeHeatPumpMiniSplit,
            HPXML::HVACTypeHeatPumpGroundToAir].include?(hvac_system.heat_pump_type)
          hvac_system.fan_watts_per_cfm = fan_watts_per_cfm
        end
      end
    end
  end

  # Calculates the conditioned floor area assumed to be served by the HVAC distribution
  # system.
  #
  # @param args [Hash] Map of :argument_name => value
  # @param hvac_distribution [HPXML::HVACDistribution] HPXML HVAC Distribution object
  # @return [Double] CFA served by the distribution system
  def get_assumed_cfa_served_by_air_distribution(args, hvac_distribution)
    max_fraction_load_served = 0.0
    hvac_distribution.hvac_systems.each do |hvac_system|
      if hvac_system.respond_to?(:fraction_heat_load_served)
        if hvac_system.is_a?(HPXML::HeatingSystem) && hvac_system.is_heat_pump_backup_system
          # HP backup system, use HP fraction heat load served
          fraction_heat_load_served = hvac_system.primary_heat_pump.fraction_heat_load_served
        else
          fraction_heat_load_served = hvac_system.fraction_heat_load_served
        end
        max_fraction_load_served = [max_fraction_load_served, fraction_heat_load_served].max
      end
      if hvac_system.respond_to?(:fraction_cool_load_served)
        max_fraction_load_served = [max_fraction_load_served, hvac_system.fraction_cool_load_served].max
      end
    end
    return args[:geometry_unit_cfa] * max_fraction_load_served
  end

  # Set the duct leakages properties, including:
  # - type
  # - leakage type, units, and value
  #
  # @param args [Hash] Map of :argument_name => value
  # @param hvac_distribution [HPXML::HVACDistribution] HPXML HVAC Distribution object
  # @return [nil]
  def set_duct_leakages(args, hvac_distribution)
    leakage_units = args[:hvac_ducts_leakage_units]
    leakage_value = args[:hvac_ducts_leakage_to_outside_value]
    if ['CFM25 per 100ft2', 'CFM50 per 100ft2'].include? leakage_units
      # Convert from CFMXX per 100ft2 of CFA to CFMXX
      leakage_units = leakage_units.split(' ')[0]
      leakage_value = leakage_value * get_assumed_cfa_served_by_air_distribution(args, hvac_distribution) / 100.0
    end
    supply_leakage_value = (leakage_value * args[:hvac_ducts_supply_leakage_fraction]).round(3)
    return_leakage_value = (leakage_value * (1.0 - args[:hvac_ducts_supply_leakage_fraction])).round(3)

    if hvac_distribution.hvac_systems.any? { |hvac| hvac.is_a?(HPXML::CoolingSystem) && hvac.cooling_system_type == HPXML::HVACTypeEvaporativeCooler }
      # Evaporative cooler, set no return duct leakage
      return_leakage_value = 0.0
    end

    hvac_distribution.duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                    duct_leakage_units: leakage_units,
                                                    duct_leakage_value: supply_leakage_value,
                                                    duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)

    hvac_distribution.duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                    duct_leakage_units: leakage_units,
                                                    duct_leakage_value: return_leakage_value,
                                                    duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
  end

  # Get the specific HPXML foundation or attic location based on general HPXML location and specific HPXML foundation or attic type.
  #
  # @param location [String] the location of interest (HPXML::LocationCrawlspace or HPXML::LocationAttic)
  # @param foundation_type [String] the specific HPXML foundation type (unvented crawlspace, vented crawlspace, conditioned crawlspace)
  # @param attic_type [String] the specific HPXML attic type (unvented attic, vented attic, conditioned attic)
  # @return [nil]
  def get_location(location, foundation_type, attic_type)
    return if location.nil?

    if location == HPXML::LocationCrawlspace
      case foundation_type
      when HPXML::FoundationTypeCrawlspaceUnvented
        return HPXML::LocationCrawlspaceUnvented
      when HPXML::FoundationTypeCrawlspaceVented
        return HPXML::LocationCrawlspaceVented
      when HPXML::FoundationTypeCrawlspaceConditioned
        return HPXML::LocationCrawlspaceConditioned
      else
        fail "Specified '#{location}' but foundation type is '#{foundation_type}'."
      end
    elsif location == HPXML::LocationAttic
      case attic_type
      when HPXML::AtticTypeUnvented
        return HPXML::LocationAtticUnvented
      when HPXML::AtticTypeVented
        return HPXML::LocationAtticVented
      when HPXML::AtticTypeConditioned
        return HPXML::LocationConditionedSpace
      else
        fail "Specified '#{location}' but attic type is '#{attic_type}'."
      end
    end
    return location
  end

  # Set the ducts properties, including:
  # - type
  # - insulation R-value
  # - location
  # - surface area
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @param hvac_distribution [HPXML::HVACDistribution] HPXML HVAC Distribution object
  # @return [nil]
  def set_ducts(hpxml_bldg, args, hvac_distribution)
    ducts_supply_location = get_location(args[:hvac_ducts_supply_location], hpxml_bldg.foundations[-1].foundation_type, hpxml_bldg.attics[-1].attic_type)
    ducts_return_location = get_location(args[:hvac_ducts_return_location], hpxml_bldg.foundations[-1].foundation_type, hpxml_bldg.attics[-1].attic_type)

    if not args[:hvac_ducts_supply_fraction_rectangular].nil?
      ducts_supply_fraction_rectangular = args[:hvac_ducts_supply_fraction_rectangular]
      if ducts_supply_fraction_rectangular == 0
        ducts_supply_fraction_rectangular = nil
        ducts_supply_shape = HPXML::DuctShapeRound
      elsif ducts_supply_fraction_rectangular == 1
        ducts_supply_shape = HPXML::DuctShapeRectangular
        ducts_supply_fraction_rectangular = nil
      end
    end

    ncfl = hpxml_bldg.building_construction.number_of_conditioned_floors
    ncfl_ag = hpxml_bldg.building_construction.number_of_conditioned_floors_above_grade

    if (not ducts_supply_location.nil?) && args[:hvac_ducts_supply_supply_surface_area_fraction].nil?
      # Supply duct location without any area inputs provided; set area fraction
      if ducts_supply_location == HPXML::LocationConditionedSpace
        args[:hvac_ducts_supply_supply_surface_area_fraction] = 1.0
      else
        args[:hvac_ducts_supply_supply_surface_area_fraction] = Defaults.get_duct_primary_fraction(ducts_supply_location, ncfl, ncfl_ag)
      end
    end

    if (not ducts_return_location.nil?) && args[:hvac_ducts_return_surface_area_fraction].nil?
      # Return duct location without any area inputs provided; set area fraction
      if ducts_return_location == HPXML::LocationConditionedSpace
        args[:hvac_ducts_return_surface_area_fraction] = 1.0
      else
        args[:hvac_ducts_return_surface_area_fraction] = Defaults.get_duct_primary_fraction(ducts_return_location, ncfl, ncfl_ag)
      end
    end

    if not args[:hvac_ducts_return_fraction_rectangular].nil?
      ducts_return_fraction_rectangular = args[:hvac_ducts_return_fraction_rectangular]
      if ducts_return_fraction_rectangular == 0
        ducts_return_fraction_rectangular = nil
        ducts_return_shape = HPXML::DuctShapeRound
      elsif ducts_return_fraction_rectangular == 1
        ducts_return_shape = HPXML::DuctShapeRectangular
        ducts_return_fraction_rectangular = nil
      end
    end

    hvac_distribution.ducts.add(id: "Ducts#{hvac_distribution.ducts.size + 1}",
                                duct_type: HPXML::DuctTypeSupply,
                                duct_insulation_r_value: args[:hvac_ducts_supply_insulation_r_value],
                                duct_buried_insulation_level: args[:hvac_ducts_supply_buried_insulation_level],
                                duct_location: ducts_supply_location,
                                duct_fraction_area: args[:hvac_ducts_supply_supply_surface_area_fraction],
                                duct_shape: ducts_supply_shape,
                                duct_fraction_rectangular: ducts_supply_fraction_rectangular)

    if not ([HPXML::HVACTypeEvaporativeCooler].include?(args[:hvac_cooling_system_type]) && args[:hvac_cooling_system_is_ducted])
      hvac_distribution.ducts.add(id: "Ducts#{hvac_distribution.ducts.size + 1}",
                                  duct_type: HPXML::DuctTypeReturn,
                                  duct_insulation_r_value: args[:hvac_ducts_return_insulation_r_value],
                                  duct_buried_insulation_level: args[:hvac_ducts_return_buried_insulation_level],
                                  duct_location: ducts_return_location,
                                  duct_fraction_area: args[:hvac_ducts_return_surface_area_fraction],
                                  duct_shape: ducts_return_shape,
                                  duct_fraction_rectangular: ducts_return_fraction_rectangular)
    end

    if (not args[:hvac_ducts_supply_supply_surface_area_fraction].nil?) && (args[:hvac_ducts_supply_supply_surface_area_fraction] < 1)
      # OS-HPXML needs duct fractions to sum to 1; add remaining ducts in conditioned space.
      hvac_distribution.ducts.add(id: "Ducts#{hvac_distribution.ducts.size + 1}",
                                  duct_type: HPXML::DuctTypeSupply,
                                  duct_insulation_r_value: 0.0,
                                  duct_location: HPXML::LocationConditionedSpace,
                                  duct_fraction_area: 1.0 - args[:hvac_ducts_supply_supply_surface_area_fraction])
    end

    if not hvac_distribution.ducts.find { |d| d.duct_type == HPXML::DuctTypeReturn }.nil?
      if (not args[:hvac_ducts_return_surface_area_fraction].nil?) && (args[:hvac_ducts_return_surface_area_fraction] < 1)
        # OS-HPXML needs duct fractions to sum to 1; add remaining ducts in conditioned space.
        hvac_distribution.ducts.add(id: "Ducts#{hvac_distribution.ducts.size + 1}",
                                    duct_type: HPXML::DuctTypeReturn,
                                    duct_insulation_r_value: 0.0,
                                    duct_location: HPXML::LocationConditionedSpace,
                                    duct_fraction_area: 1.0 - args[:hvac_ducts_return_surface_area_fraction])
      end
    end

    # Set CFA served
    if hvac_distribution.ducts.count { |d| d.duct_surface_area.nil? } > 0
      hvac_distribution.conditioned_floor_area_served = get_assumed_cfa_served_by_air_distribution(args, hvac_distribution)
    end
  end

  # Sets the HPXML HVAC control properties.
  #
  # @param hpxml [HPXML] HPXML object
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @param weather [WeatherFile] Weather object containing EPW information
  # @return [nil]
  def set_hvac_control(hpxml, hpxml_bldg, args, weather)
    return if (args[:hvac_heating_system] == 'None') && (args[:hvac_cooling_system] == 'None') && (args[:hvac_heat_pump] == 'None')

    latitude = Defaults.get_latitude(nil, weather) unless weather.nil?

    # Heating
    if hpxml_bldg.total_fraction_heat_load_served > 0

      if (not args[:hvac_control_heating_weekday_setpoint].nil?) && (not args[:hvac_control_heating_weekend_setpoint].nil?)
        if args[:hvac_control_heating_weekday_setpoint] == args[:hvac_control_heating_weekend_setpoint] && !args[:hvac_control_heating_weekday_setpoint].include?(',')
          heating_setpoint_temp = Float(args[:hvac_control_heating_weekday_setpoint])
        else
          weekday_heating_setpoints = args[:hvac_control_heating_weekday_setpoint]
          weekend_heating_setpoints = args[:hvac_control_heating_weekend_setpoint]
        end
      end

      if (not args[:hvac_control_heating_season_period].nil?) && (args[:hvac_control_heating_season_period] != 'Jan 1 - Dec 31') # Jan 1 - Dec 31 is the OS-HPXML default, no need to write it
        hvac_control_heating_season_period = args[:hvac_control_heating_season_period]
        if hvac_control_heating_season_period == Constants::BuildingAmerica
          heating_months, _cooling_months = HVAC.get_building_america_hvac_seasons(weather, latitude)
          sim_calendar_year = Location.get_sim_calendar_year(hpxml.header.sim_calendar_year, weather)
          begin_month, begin_day, end_month, end_day = Calendar.get_begin_and_end_dates_from_monthly_array(heating_months, sim_calendar_year)
        else
          begin_month, begin_day, _begin_hour, end_month, end_day, _end_hour = Calendar.parse_date_time_range(hvac_control_heating_season_period)
        end
        seasons_heating_begin_month = begin_month
        seasons_heating_begin_day = begin_day
        seasons_heating_end_month = end_month
        seasons_heating_end_day = end_day
      end

    end

    # Cooling
    if hpxml_bldg.total_fraction_cool_load_served > 0

      if (not args[:hvac_control_cooling_weekday_setpoint].nil?) && (not args[:hvac_control_cooling_weekend_setpoint].nil?)
        if args[:hvac_control_cooling_weekday_setpoint] == args[:hvac_control_cooling_weekend_setpoint] && !args[:hvac_control_cooling_weekday_setpoint].include?(',')
          cooling_setpoint_temp = Float(args[:hvac_control_cooling_weekday_setpoint])
        else
          weekday_cooling_setpoints = args[:hvac_control_cooling_weekday_setpoint]
          weekend_cooling_setpoints = args[:hvac_control_cooling_weekend_setpoint]
        end
      end

      if (not args[:hvac_control_cooling_season_period].nil?) && (args[:hvac_control_cooling_season_period] != 'Jan 1 - Dec 31') # Jan 1 - Dec 31 is the OS-HPXML default, no need to write it
        hvac_control_cooling_season_period = args[:hvac_control_cooling_season_period]
        if hvac_control_cooling_season_period == Constants::BuildingAmerica
          _heating_months, cooling_months = HVAC.get_building_america_hvac_seasons(weather, latitude)
          sim_calendar_year = Location.get_sim_calendar_year(hpxml.header.sim_calendar_year, weather)
          begin_month, begin_day, end_month, end_day = Calendar.get_begin_and_end_dates_from_monthly_array(cooling_months, sim_calendar_year)
        else
          begin_month, begin_day, _begin_hour, end_month, end_day, _end_hour = Calendar.parse_date_time_range(hvac_control_cooling_season_period)
        end
        seasons_cooling_begin_month = begin_month
        seasons_cooling_begin_day = begin_day
        seasons_cooling_end_month = end_month
        seasons_cooling_end_day = end_day
      end

    end

    hpxml_bldg.hvac_controls.add(id: "HVACControl#{hpxml_bldg.hvac_controls.size + 1}",
                                 heating_setpoint_temp: heating_setpoint_temp,
                                 cooling_setpoint_temp: cooling_setpoint_temp,
                                 weekday_heating_setpoints: weekday_heating_setpoints,
                                 weekend_heating_setpoints: weekend_heating_setpoints,
                                 weekday_cooling_setpoints: weekday_cooling_setpoints,
                                 weekend_cooling_setpoints: weekend_cooling_setpoints,
                                 ceiling_fan_cooling_setpoint_temp_offset: args[:ceiling_fans_cooling_setpoint_temperature_offset],
                                 seasons_heating_begin_month: seasons_heating_begin_month,
                                 seasons_heating_begin_day: seasons_heating_begin_day,
                                 seasons_heating_end_month: seasons_heating_end_month,
                                 seasons_heating_end_day: seasons_heating_end_day,
                                 seasons_cooling_begin_month: seasons_cooling_begin_month,
                                 seasons_cooling_begin_day: seasons_cooling_begin_day,
                                 seasons_cooling_end_month: seasons_cooling_end_month,
                                 seasons_cooling_end_day: seasons_cooling_end_day)
  end

  # Sets the HPXML ventilation fans properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_ventilation_fans(hpxml_bldg, args)
    if args[:ventilation_mechanical] != 'None'

      distribution_system_idref = nil

      case args[:ventilation_mechanical_fan_type]
      when HPXML::MechVentTypeERV
        total_recovery_efficiency = args[:ventilation_mechanical_total_recovery_efficiency]
        sensible_recovery_efficiency = args[:ventilation_mechanical_sensible_recovery_efficiency]
      when HPXML::MechVentTypeHRV
        sensible_recovery_efficiency = args[:ventilation_mechanical_sensible_recovery_efficiency]
      when HPXML::MechVentTypeCFIS
        hpxml_bldg.hvac_distributions.each do |hvac_distribution|
          next unless hvac_distribution.distribution_system_type == HPXML::HVACDistributionTypeAir
          next if hvac_distribution.air_type != HPXML::AirTypeRegularVelocity

          distribution_system_idref = hvac_distribution.id
        end
        if distribution_system_idref.nil?
          # Allow for PTAC/PTHP by automatically adding a DSE=1 distribution system to attach the CFIS to
          hpxml_bldg.hvac_systems.each do |hvac_system|
            next unless HVAC.is_room_dx_hvac_system(hvac_system)

            hpxml_bldg.hvac_distributions.add(id: "HVACDistribution#{hpxml_bldg.hvac_distributions.size + 1}",
                                              distribution_system_type: HPXML::HVACDistributionTypeDSE,
                                              annual_cooling_dse: 1.0,
                                              annual_heating_dse: 1.0)
            hvac_system.distribution_system_idref = hpxml_bldg.hvac_distributions[-1].id
            distribution_system_idref = hpxml_bldg.hvac_distributions[-1].id
          end
        end

        return if distribution_system_idref.nil? # No distribution system to attach the CFIS to

        cfis_addtl_runtime_operating_mode = HPXML::CFISModeAirHandler
      end

      hpxml_bldg.ventilation_fans.add(id: "VentilationFan#{hpxml_bldg.ventilation_fans.size + 1}",
                                      fan_type: args[:ventilation_mechanical_fan_type],
                                      cfis_addtl_runtime_operating_mode: cfis_addtl_runtime_operating_mode,
                                      rated_flow_rate: args[:ventilation_mechanical_flow_rate],
                                      hours_in_operation: args[:ventilation_mechanical_hours_in_operation],
                                      used_for_whole_building_ventilation: true,
                                      total_recovery_efficiency: total_recovery_efficiency,
                                      sensible_recovery_efficiency: sensible_recovery_efficiency,
                                      fan_power: args[:ventilation_mechanical_fan_power],
                                      distribution_system_idref: distribution_system_idref)
    end

    if args[:ventilation_kitchen] != 'None'
      hpxml_bldg.ventilation_fans.add(id: "VentilationFan#{hpxml_bldg.ventilation_fans.size + 1}",
                                      rated_flow_rate: args[:ventilation_kitchen_flow_rate],
                                      used_for_local_ventilation: true,
                                      hours_in_operation: args[:ventilation_kitchen_hours_in_operation],
                                      fan_location: HPXML::LocationKitchen,
                                      fan_power: args[:ventilation_kitchen_fan_power],
                                      start_hour: args[:ventilation_kitchen_start_hour],
                                      count: args[:ventilation_kitchen_count])
    end

    if args[:ventilation_bathroom] != 'None'
      hpxml_bldg.ventilation_fans.add(id: "VentilationFan#{hpxml_bldg.ventilation_fans.size + 1}",
                                      rated_flow_rate: args[:ventilation_bathroom_flow_rate],
                                      used_for_local_ventilation: true,
                                      hours_in_operation: args[:ventilation_bathroom_hours_in_operation],
                                      fan_location: HPXML::LocationBath,
                                      fan_power: args[:ventilation_bathroom_fan_power],
                                      start_hour: args[:ventilation_bathroom_start_hour],
                                      count: args[:ventilation_bathroom_count])
    end

    if args[:ventilation_whole_house_fan] != 'None'
      hpxml_bldg.ventilation_fans.add(id: "VentilationFan#{hpxml_bldg.ventilation_fans.size + 1}",
                                      rated_flow_rate: args[:ventilation_whole_house_fan_rated_flow_rate],
                                      used_for_seasonal_cooling_load_reduction: true,
                                      fan_power: args[:ventilation_whole_house_fan_power])
    end
  end

  # Sets the HPXML water heating systems properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_water_heating_systems(hpxml_bldg, args)
    return if args[:dhw_water_heater] == 'None'

    water_heater_type = args[:dhw_water_heater_type]
    if water_heater_type == HPXML::WaterHeaterTypeHeatPump
      args[:dhw_water_heater_fuel_type] = HPXML::FuelTypeElectricity
    end

    location = get_location(args[:dhw_water_heater_location], hpxml_bldg.foundations[-1].foundation_type, hpxml_bldg.attics[-1].attic_type)

    if not [HPXML::WaterHeaterTypeCombiStorage, HPXML::WaterHeaterTypeCombiTankless].include? water_heater_type
      case args[:dhw_water_heater_efficiency_type]
      when 'EnergyFactor'
        energy_factor = args[:dhw_water_heater_efficiency]
      when 'UniformEnergyFactor'
        uniform_energy_factor = args[:dhw_water_heater_efficiency]
        if water_heater_type != HPXML::WaterHeaterTypeTankless
          usage_bin = args[:dhw_water_heater_usage_bin]
        end
      end
    end

    if (args[:dhw_water_heater_fuel_type] != HPXML::FuelTypeElectricity) && (water_heater_type == HPXML::WaterHeaterTypeStorage)
      recovery_efficiency = args[:dhw_water_heater_recovery_efficiency]
    end

    if [HPXML::WaterHeaterTypeTankless, HPXML::WaterHeaterTypeCombiTankless].include? water_heater_type
      args[:dhw_water_heater_tank_volume] = nil
    end

    if [HPXML::WaterHeaterTypeTankless].include? water_heater_type
      recovery_efficiency = nil
    elsif [HPXML::WaterHeaterTypeCombiTankless, HPXML::WaterHeaterTypeCombiStorage].include? water_heater_type
      args[:dhw_water_heater_fuel_type] = nil
      energy_factor = nil
      if hpxml_bldg.heating_systems.size > 0
        related_hvac_idref = hpxml_bldg.heating_systems[0].id
      end
    end

    if not [HPXML::WaterHeaterTypeTankless, HPXML::WaterHeaterTypeCombiTankless].include? water_heater_type
      if args[:dhw_water_heater_jacket] != 'None' # None is the OS-HPXML default, no need to write it
        jacket_r_value = args[:dhw_water_heater_jacket_r_value]
      end
    end

    if args[:dhw_water_heater_uses_desuperheater]
      uses_desuperheater = true
    end
    if uses_desuperheater
      related_hvac_idref = nil
      hpxml_bldg.cooling_systems.each do |cooling_system|
        next unless [HPXML::HVACTypeCentralAirConditioner,
                     HPXML::HVACTypeMiniSplitAirConditioner].include? cooling_system.cooling_system_type

        related_hvac_idref = cooling_system.id
      end
      hpxml_bldg.heat_pumps.each do |heat_pump|
        next unless [HPXML::HVACTypeHeatPumpAirToAir,
                     HPXML::HVACTypeHeatPumpMiniSplit,
                     HPXML::HVACTypeHeatPumpGroundToAir].include? heat_pump.heat_pump_type

        related_hvac_idref = heat_pump.id
      end
    end

    hpxml_bldg.water_heating_systems.add(id: "WaterHeatingSystem#{hpxml_bldg.water_heating_systems.size + 1}",
                                         water_heater_type: water_heater_type,
                                         fuel_type: args[:dhw_water_heater_fuel_type],
                                         location: location,
                                         tank_volume: args[:dhw_water_heater_tank_volume],
                                         fraction_dhw_load_served: 1.0,
                                         energy_factor: energy_factor,
                                         uniform_energy_factor: uniform_energy_factor,
                                         usage_bin: usage_bin,
                                         recovery_efficiency: recovery_efficiency,
                                         uses_desuperheater: uses_desuperheater,
                                         related_hvac_idref: related_hvac_idref,
                                         jacket_r_value: jacket_r_value,
                                         temperature: args[:dhw_water_heater_temperature])
  end

  # Sets the HPXML hot water distribution properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_hot_water_distribution(hpxml_bldg, args)
    return if args[:dhw_water_heater] == 'None'

    dwhr_facilities_connected = args[:dhw_drain_water_heat_recovery_facilities_connected]
    dwhr_equal_flow = args[:dhw_drain_water_heat_recovery_equal_flow]
    dwhr_efficiency = args[:dhw_drain_water_heat_recovery_efficiency]

    if args[:dhw_distribution_system_type] == HPXML::DHWDistTypeStandard
      standard_piping_length = args[:dhw_distribution_standard_piping_length]
    else
      recirculation_control_type = args[:dhw_distribution_recirculation_control_type]
      recirculation_piping_loop_length = args[:dhw_distribution_recirculation_piping_loop_length]
      recirculation_branch_piping_length = args[:dhw_distribution_recirculation_branch_piping_length]
      recirculation_pump_power = args[:dhw_distribution_recirculation_pump_power]
    end

    hpxml_bldg.hot_water_distributions.add(id: "HotWaterDistribution#{hpxml_bldg.hot_water_distributions.size + 1}",
                                           system_type: args[:dhw_distribution_system_type],
                                           standard_piping_length: standard_piping_length,
                                           recirculation_control_type: recirculation_control_type,
                                           recirculation_piping_loop_length: recirculation_piping_loop_length,
                                           recirculation_branch_piping_length: recirculation_branch_piping_length,
                                           recirculation_pump_power: recirculation_pump_power,
                                           pipe_r_value: args[:dhw_distribution_pipe_insulation_nominal_r_value],
                                           dwhr_facilities_connected: dwhr_facilities_connected,
                                           dwhr_equal_flow: dwhr_equal_flow,
                                           dwhr_efficiency: dwhr_efficiency)
  end

  # Sets the HPXML water fixtures properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_water_fixtures(hpxml_bldg, args)
    return if args[:dhw_water_heater] == 'None'

    hpxml_bldg.water_fixtures.add(id: "WaterFixture#{hpxml_bldg.water_fixtures.size + 1}",
                                  water_fixture_type: HPXML::WaterFixtureTypeShowerhead,
                                  low_flow: args[:dhw_fixtures_low_flow_showers])

    hpxml_bldg.water_fixtures.add(id: "WaterFixture#{hpxml_bldg.water_fixtures.size + 1}",
                                  water_fixture_type: HPXML::WaterFixtureTypeFaucet,
                                  low_flow: args[:dhw_fixtures_low_flow_sinks])

    hpxml_bldg.water_heating.water_fixtures_usage_multiplier = args[:dhw_water_fixtures_usage_multiplier]
  end

  # Sets the HPXML solar thermal properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @param weather [WeatherFile] Weather object containing EPW information
  # @return [nil]
  def set_solar_thermal(hpxml_bldg, args, weather)
    return if args[:dhw_solar_thermal] == 'None'

    if args[:dhw_solar_thermal_solar_fraction].to_f > 0
      solar_fraction = args[:dhw_solar_thermal_solar_fraction]
    else
      collector_area = args[:dhw_solar_thermal_collector_area]
      collector_loop_type = args[:dhw_solar_thermal_collector_loop_type]
      collector_type = args[:dhw_solar_thermal_collector_type]
      collector_azimuth = args[:dhw_solar_thermal_collector_azimuth]
      latitude = Defaults.get_latitude(nil, weather) unless weather.nil?
      collector_tilt = Geometry.get_absolute_tilt(tilt_str: args[:dhw_solar_thermal_collector_tilt], roof_pitch: args[:geometry_roof_pitch], latitude: latitude)
      collector_rated_optical_efficiency = args[:dhw_solar_thermal_collector_rated_optical_efficiency]
      collector_rated_thermal_losses = args[:dhw_solar_thermal_collector_rated_thermal_losses]
      storage_volume = args[:dhw_solar_thermal_storage_volume]
    end

    if hpxml_bldg.water_heating_systems.size == 0
      fail 'Solar thermal system specified but no water heater found.'
    end

    hpxml_bldg.solar_thermal_systems.add(id: "SolarThermalSystem#{hpxml_bldg.solar_thermal_systems.size + 1}",
                                         system_type: HPXML::SolarThermalSystemTypeHotWater,
                                         collector_area: collector_area,
                                         collector_loop_type: collector_loop_type,
                                         collector_type: collector_type,
                                         collector_azimuth: collector_azimuth,
                                         collector_tilt: collector_tilt,
                                         collector_rated_optical_efficiency: collector_rated_optical_efficiency,
                                         collector_rated_thermal_losses: collector_rated_thermal_losses,
                                         storage_volume: storage_volume,
                                         water_heating_system_idref: hpxml_bldg.water_heating_systems[0].id,
                                         solar_fraction: solar_fraction)
  end

  # Sets the HPXML PV systems properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @param weather [WeatherFile] Weather object containing EPW information
  # @return [nil]
  def set_pv_systems(hpxml_bldg, args, weather)
    return if args[:pv_system] == 'None'

    latitude = Defaults.get_latitude(nil, weather) unless weather.nil?

    hpxml_bldg.pv_systems.add(id: "PVSystem#{hpxml_bldg.pv_systems.size + 1}",
                              location: args[:pv_system_location],
                              module_type: args[:pv_system_module_type],
                              tracking: args[:pv_system_tracking],
                              array_azimuth: args[:pv_system_array_azimuth],
                              array_tilt: Geometry.get_absolute_tilt(tilt_str: args[:pv_system_array_tilt], roof_pitch: args[:geometry_roof_pitch], latitude: latitude),
                              max_power_output: args[:pv_system_maximum_power_output],
                              system_losses_fraction: args[:pv_system_system_losses_fraction])

    if args[:pv_system_2] != 'None'
      hpxml_bldg.pv_systems.add(id: "PVSystem#{hpxml_bldg.pv_systems.size + 1}",
                                location: args[:pv_system_2_location],
                                module_type: args[:pv_system_2_module_type],
                                tracking: args[:pv_system_2_tracking],
                                array_azimuth: args[:pv_system_2_array_azimuth],
                                array_tilt: Geometry.get_absolute_tilt(tilt_str: args[:pv_system_2_array_tilt], roof_pitch: args[:geometry_roof_pitch], latitude: latitude),
                                max_power_output: args[:pv_system_2_maximum_power_output],
                                system_losses_fraction: args[:pv_system_2_system_losses_fraction])
    end

    # Add inverter efficiency; assume a single inverter even if multiple PV arrays
    hpxml_bldg.inverters.add(id: "Inverter#{hpxml_bldg.inverters.size + 1}",
                             inverter_efficiency: args[:pv_system_inverter_efficiency])
    hpxml_bldg.pv_systems.each do |pv_system|
      pv_system.inverter_idref = hpxml_bldg.inverters[-1].id
    end
  end

  # Sets the HPXML electric panel properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_electric_panel(hpxml_bldg, args)
    return if args[:electric_panel_service_feeders_load_calculation_types].nil?

    hpxml_bldg.electric_panels.add(id: "ElectricPanel#{hpxml_bldg.electric_panels.size + 1}",
                                   voltage: args[:electric_panel_service_voltage],
                                   max_current_rating: args[:electric_panel_service_max_current_rating],
                                   headroom_spaces: args[:electric_panel_breaker_spaces_headroom],
                                   rated_total_spaces: args[:electric_panel_breaker_spaces_rated_total])

    electric_panel = hpxml_bldg.electric_panels[0]
    branch_circuits = electric_panel.branch_circuits
    service_feeders = electric_panel.service_feeders

    hpxml_bldg.heating_systems.each do |heating_system|
      next if heating_system.is_shared_system
      next if heating_system.fraction_heat_load_served == 0

      if heating_system.primary_system
        service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                            type: HPXML::ElectricPanelLoadTypeHeating,
                            power: args[:electric_panel_load_heating_system_power_rating],
                            is_new_load: args[:electric_panel_load_heating_system_new_load],
                            component_idrefs: [heating_system.id])
      else
        service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                            type: HPXML::ElectricPanelLoadTypeHeating,
                            power: args[:electric_panel_load_heating_system_2_power_rating],
                            is_new_load: args[:electric_panel_load_heating_system_2_new_load],
                            component_idrefs: [heating_system.id])
      end
    end

    hpxml_bldg.cooling_systems.each do |cooling_system|
      next if cooling_system.is_shared_system
      next if cooling_system.fraction_cool_load_served == 0

      service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                          type: HPXML::ElectricPanelLoadTypeCooling,
                          power: args[:electric_panel_load_cooling_system_power_rating],
                          is_new_load: args[:electric_panel_load_cooling_system_new_load],
                          component_idrefs: [cooling_system.id])
    end

    hpxml_bldg.heat_pumps.each do |heat_pump|
      next if heat_pump.is_shared_system

      if heat_pump.fraction_heat_load_served != 0
        service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                            type: HPXML::ElectricPanelLoadTypeHeating,
                            power: args[:electric_panel_load_heat_pump_power_rating],
                            is_new_load: args[:electric_panel_load_heat_pump_new_load],
                            component_idrefs: [heat_pump.id])
      end
      next unless heat_pump.fraction_cool_load_served != 0

      service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                          type: HPXML::ElectricPanelLoadTypeCooling,
                          power: args[:electric_panel_load_heat_pump_power_rating],
                          is_new_load: args[:electric_panel_load_heat_pump_new_load],
                          component_idrefs: [heat_pump.id])
    end

    hpxml_bldg.water_heating_systems.each do |water_heating_system|
      next if water_heating_system.fuel_type != HPXML::FuelTypeElectricity

      if not args[:electric_panel_load_electric_water_heater_voltage].nil?
        branch_circuits.add(id: "BranchCircuit#{branch_circuits.size + 1}",
                            voltage: args[:electric_panel_load_electric_water_heater_voltage],
                            component_idrefs: [water_heating_system.id])
      end
      service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                          type: HPXML::ElectricPanelLoadTypeWaterHeater,
                          power: args[:electric_panel_load_electric_water_heater_power_rating],
                          is_new_load: args[:electric_panel_load_electric_water_heater_new_load],
                          component_idrefs: [water_heating_system.id])
    end

    hpxml_bldg.clothes_dryers.each do |clothes_dryer|
      next if clothes_dryer.fuel_type != HPXML::FuelTypeElectricity

      if not args[:electric_panel_load_electric_clothes_dryer_voltage].nil?
        branch_circuits.add(id: "BranchCircuit#{branch_circuits.size + 1}",
                            voltage: args[:electric_panel_load_electric_clothes_dryer_voltage],
                            component_idrefs: [clothes_dryer.id])
      end
      service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                          type: HPXML::ElectricPanelLoadTypeClothesDryer,
                          power: args[:electric_panel_load_electric_clothes_dryer_power_rating],
                          is_new_load: args[:electric_panel_load_electric_clothes_dryer_new_load],
                          component_idrefs: [clothes_dryer.id])
    end

    hpxml_bldg.dishwashers.each do |dishwasher|
      service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                          type: HPXML::ElectricPanelLoadTypeDishwasher,
                          power: args[:electric_panel_load_dishwasher_power_rating],
                          is_new_load: args[:electric_panel_load_dishwasher_new_load],
                          component_idrefs: [dishwasher.id])
    end

    hpxml_bldg.cooking_ranges.each do |cooking_range|
      next if cooking_range.fuel_type != HPXML::FuelTypeElectricity

      if not args[:electric_panel_load_electric_cooking_range_voltage].nil?
        branch_circuits.add(id: "BranchCircuit#{branch_circuits.size + 1}",
                            voltage: args[:electric_panel_load_electric_cooking_range_voltage],
                            component_idrefs: [cooking_range.id])
      end
      service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                          type: HPXML::ElectricPanelLoadTypeRangeOven,
                          power: args[:electric_panel_load_electric_cooking_range_power_rating],
                          is_new_load: args[:electric_panel_load_electric_cooking_range_new_load],
                          component_idrefs: [cooking_range.id])
    end

    hpxml_bldg.ventilation_fans.each do |ventilation_fan|
      if ventilation_fan.used_for_whole_building_ventilation # Mechanical Ventilation
        service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                            type: HPXML::ElectricPanelLoadTypeMechVent,
                            power: args[:electric_panel_load_mech_vent_power_rating],
                            is_new_load: args[:electric_panel_load_mech_vent_fan_new_load],
                            component_idrefs: [ventilation_fan.id])
      elsif ventilation_fan.used_for_local_ventilation # Kitchen / Bathroom Fans
        if ventilation_fan.fan_location == HPXML::LocationKitchen
          service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                              type: HPXML::ElectricPanelLoadTypeMechVent,
                              power: args[:electric_panel_load_kitchen_fans_power_rating],
                              is_new_load: args[:electric_panel_load_kitchen_fans_new_load],
                              component_idrefs: [ventilation_fan.id])
        elsif ventilation_fan.fan_location == HPXML::LocationBath
          service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                              type: HPXML::ElectricPanelLoadTypeMechVent,
                              power: args[:electric_panel_load_bathroom_fans_power_rating],
                              is_new_load: args[:electric_panel_load_bathroom_fans_new_load],
                              component_idrefs: [ventilation_fan.id])
        end
      elsif ventilation_fan.used_for_seasonal_cooling_load_reduction # Whole House Fan
        service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                            type: HPXML::ElectricPanelLoadTypeMechVent,
                            power: args[:electric_panel_load_whole_house_fan_power_rating],
                            is_new_load: args[:electric_panel_load_whole_house_fan_new_load],
                            component_idrefs: [ventilation_fan.id])
      end
    end

    hpxml_bldg.permanent_spas.each do |permanent_spa|
      service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                          type: HPXML::ElectricPanelLoadTypePermanentSpaPump,
                          power: args[:electric_panel_load_permanent_spa_pump_power_rating],
                          is_new_load: args[:electric_panel_load_permanent_spa_pump_new_load],
                          component_idrefs: [permanent_spa.pump_id])

      next unless [HPXML::HeaterTypeElectricResistance, HPXML::HeaterTypeHeatPump].include?(permanent_spa.heater_type)

      service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                          type: HPXML::ElectricPanelLoadTypePermanentSpaHeater,
                          power: args[:electric_panel_load_electric_permanent_spa_heater_power_rating],
                          is_new_load: args[:electric_panel_load_electric_permanent_spa_heater_new_load],
                          component_idrefs: [permanent_spa.heater_id])
    end

    hpxml_bldg.pools.each do |pool|
      service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                          type: HPXML::ElectricPanelLoadTypePoolPump,
                          power: args[:electric_panel_load_pool_pump_power_rating],
                          is_new_load: args[:electric_panel_load_pool_pump_new_load],
                          component_idrefs: [pool.pump_id])

      next unless [HPXML::HeaterTypeElectricResistance, HPXML::HeaterTypeHeatPump].include?(pool.heater_type)

      service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                          type: HPXML::ElectricPanelLoadTypePoolHeater,
                          power: args[:electric_panel_load_electric_pool_heater_power_rating],
                          is_new_load: args[:electric_panel_load_electric_pool_heater_new_load],
                          component_idrefs: [pool.heater_id])
    end

    hpxml_bldg.plug_loads.each do |plug_load|
      if plug_load.plug_load_type == HPXML::PlugLoadTypeWellPump
        service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                            type: HPXML::ElectricPanelLoadTypeWellPump,
                            power: args[:electric_panel_load_misc_plug_loads_well_pump_power_rating],
                            is_new_load: args[:electric_panel_load_misc_plug_loads_well_pump_new_load],
                            component_idrefs: [plug_load.id])
      elsif plug_load.plug_load_type == HPXML::PlugLoadTypeElectricVehicleCharging
        if not args[:electric_panel_load_misc_plug_loads_vehicle_voltage].nil?
          branch_circuits.add(id: "BranchCircuit#{branch_circuits.size + 1}",
                              voltage: args[:electric_panel_load_misc_plug_loads_vehicle_voltage],
                              component_idrefs: [plug_load.id])
        end
        service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                            type: HPXML::ElectricPanelLoadTypeElectricVehicleCharging,
                            power: args[:electric_panel_load_misc_plug_loads_vehicle_power_rating],
                            is_new_load: args[:electric_panel_load_misc_plug_loads_vehicle_new_load],
                            component_idrefs: [plug_load.id])
      end
    end

    hpxml_bldg.ev_chargers.each do |ev_charger|
      # The electric panel EV voltage argument takes precedence over the EV charging level.
      if not args[:electric_panel_load_misc_plug_loads_vehicle_voltage].nil?
        voltage = args[:electric_panel_load_misc_plug_loads_vehicle_voltage]
      elsif not ev_charger.charging_level.nil?
        voltage = { 1 => HPXML::ElectricPanelVoltage120,
                    2 => HPXML::ElectricPanelVoltage240,
                    3 => HPXML::ElectricPanelVoltage240 }[ev_charger.charging_level]
      end

      # The electric panel EV power rating argument takes precedence over the EV charging power.
      if not args[:electric_panel_load_misc_plug_loads_vehicle_power_rating].nil?
        power = args[:electric_panel_load_misc_plug_loads_vehicle_power_rating]
      elsif not ev_charger.charging_power.nil?
        power = ev_charger.charging_power
      end

      if not voltage.nil?
        branch_circuits.add(id: "BranchCircuit#{branch_circuits.size + 1}",
                            voltage: voltage,
                            component_idrefs: [ev_charger.id])
      end

      service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                          type: HPXML::ElectricPanelLoadTypeElectricVehicleCharging,
                          power: power,
                          is_new_load: args[:electric_panel_load_misc_plug_loads_vehicle_new_load],
                          component_idrefs: [ev_charger.id])
    end

    if !args[:electric_panel_load_other_power_rating].nil? || !args[:electric_panel_load_other_new_load].nil?
      branch_circuits.add(id: "BranchCircuit#{branch_circuits.size + 1}",
                          occupied_spaces: 1,
                          component_idrefs: [])
      service_feeders.add(id: "ServiceFeeder#{service_feeders.size + 1}",
                          type: HPXML::ElectricPanelLoadTypeOther,
                          power: args[:electric_panel_load_other_power_rating],
                          is_new_load: args[:electric_panel_load_other_new_load],
                          component_idrefs: [])
    end
  end

  # Sets the HPXML battery properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_battery(hpxml_bldg, args)
    return if args[:battery] == 'None'

    location = get_location(args[:battery_location], hpxml_bldg.foundations[-1].foundation_type, hpxml_bldg.attics[-1].attic_type)

    hpxml_bldg.batteries.add(id: "Battery#{hpxml_bldg.batteries.size + 1}",
                             type: HPXML::BatteryTypeLithiumIon,
                             location: location,
                             rated_power_output: args[:battery_rated_power_output],
                             nominal_capacity_kwh: args[:battery_nominal_capacity],
                             usable_capacity_kwh: args[:battery_usable_capacity],
                             round_trip_efficiency: args[:battery_round_trip_efficiency])
  end

  # Sets the HPXML vehicle and electric vehicle charger properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_vehicle(hpxml_bldg, args)
    charger_id = nil
    if args[:electric_vehicle_charger] != 'None'
      charger_id = "EVCharger#{hpxml_bldg.ev_chargers.size + 1}"
      hpxml_bldg.ev_chargers.add(id: charger_id,
                                 charging_level: args[:electric_vehicle_charger_level],
                                 charging_power: args[:electric_vehicle_charger_power])
    end

    if args[:electric_vehicle] != 'None'
      hpxml_bldg.vehicles.add(id: "Vehicle#{hpxml_bldg.vehicles.size + 1}",
                              vehicle_type: args[:electric_vehicle_type],
                              nominal_capacity_kwh: args[:electric_vehicle_nominal_battery_capacity],
                              usable_capacity_kwh: args[:electric_vehicle_usable_battery_capacity],
                              fuel_economy_combined: args[:electric_vehicle_fuel_economy_combined],
                              fuel_economy_units: args[:electric_vehicle_fuel_economy_units],
                              miles_per_year: args[:electric_vehicle_miles_driven_per_year],
                              fraction_charged_home: args[:electric_vehicle_charger_fraction_charged_at_home],
                              ev_charger_idref: charger_id)
    end
  end

  # Sets the HPXML lighting properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_lighting(hpxml_bldg, args)
    return if args[:lighting] == 'None'

    has_garage = (args[:geometry_garage_type_width] * args[:geometry_garage_type_depth] > 0)

    # Interior
    interior_usage_multiplier = args[:lighting_interior_usage_multiplier]
    if interior_usage_multiplier.nil? || interior_usage_multiplier.to_f > 0
      hpxml_bldg.lighting_groups.add(id: "LightingGroup#{hpxml_bldg.lighting_groups.size + 1}",
                                     location: HPXML::LocationInterior,
                                     fraction_of_units_in_location: args[:lighting_interior_fraction_cfl],
                                     lighting_type: HPXML::LightingTypeCFL)
      hpxml_bldg.lighting_groups.add(id: "LightingGroup#{hpxml_bldg.lighting_groups.size + 1}",
                                     location: HPXML::LocationInterior,
                                     fraction_of_units_in_location: args[:lighting_interior_fraction_lfl],
                                     lighting_type: HPXML::LightingTypeLFL)
      hpxml_bldg.lighting_groups.add(id: "LightingGroup#{hpxml_bldg.lighting_groups.size + 1}",
                                     location: HPXML::LocationInterior,
                                     fraction_of_units_in_location: args[:lighting_interior_fraction_led],
                                     lighting_type: HPXML::LightingTypeLED)
      hpxml_bldg.lighting.interior_usage_multiplier = interior_usage_multiplier
    end

    # Exterior
    exterior_usage_multiplier = args[:lighting_exterior_usage_multiplier]
    if exterior_usage_multiplier.nil? || exterior_usage_multiplier.to_f > 0
      hpxml_bldg.lighting_groups.add(id: "LightingGroup#{hpxml_bldg.lighting_groups.size + 1}",
                                     location: HPXML::LocationExterior,
                                     fraction_of_units_in_location: args[:lighting_exterior_fraction_cfl],
                                     lighting_type: HPXML::LightingTypeCFL)
      hpxml_bldg.lighting_groups.add(id: "LightingGroup#{hpxml_bldg.lighting_groups.size + 1}",
                                     location: HPXML::LocationExterior,
                                     fraction_of_units_in_location: args[:lighting_exterior_fraction_lfl],
                                     lighting_type: HPXML::LightingTypeLFL)
      hpxml_bldg.lighting_groups.add(id: "LightingGroup#{hpxml_bldg.lighting_groups.size + 1}",
                                     location: HPXML::LocationExterior,
                                     fraction_of_units_in_location: args[:lighting_exterior_fraction_led],
                                     lighting_type: HPXML::LightingTypeLED)
      hpxml_bldg.lighting.exterior_usage_multiplier = exterior_usage_multiplier
    end

    # Garage
    if has_garage
      garage_usage_multiplier = args[:lighting_garage_usage_multiplier]
      if garage_usage_multiplier.nil? || garage_usage_multiplier.to_f > 0
        hpxml_bldg.lighting_groups.add(id: "LightingGroup#{hpxml_bldg.lighting_groups.size + 1}",
                                       location: HPXML::LocationGarage,
                                       fraction_of_units_in_location: args[:lighting_garage_fraction_cfl],
                                       lighting_type: HPXML::LightingTypeCFL)
        hpxml_bldg.lighting_groups.add(id: "LightingGroup#{hpxml_bldg.lighting_groups.size + 1}",
                                       location: HPXML::LocationGarage,
                                       fraction_of_units_in_location: args[:lighting_garage_fraction_lfl],
                                       lighting_type: HPXML::LightingTypeLFL)
        hpxml_bldg.lighting_groups.add(id: "LightingGroup#{hpxml_bldg.lighting_groups.size + 1}",
                                       location: HPXML::LocationGarage,
                                       fraction_of_units_in_location: args[:lighting_garage_fraction_led],
                                       lighting_type: HPXML::LightingTypeLED)
        hpxml_bldg.lighting.garage_usage_multiplier = garage_usage_multiplier
      end
    end
  end

  # Sets the HPXML dehumidifier properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_dehumidifier(hpxml_bldg, args)
    return if args[:appliance_dehumidifier] == 'None'

    case args[:appliance_dehumidifier_efficiency_type]
    when 'EnergyFactor'
      energy_factor = args[:appliance_dehumidifier_efficiency]
    when 'IntegratedEnergyFactor'
      integrated_energy_factor = args[:appliance_dehumidifier_efficiency]
    end

    hpxml_bldg.dehumidifiers.add(id: "Dehumidifier#{hpxml_bldg.dehumidifiers.size + 1}",
                                 type: args[:appliance_dehumidifier_type],
                                 capacity: args[:appliance_dehumidifier_capacity],
                                 energy_factor: energy_factor,
                                 integrated_energy_factor: integrated_energy_factor,
                                 rh_setpoint: args[:appliance_dehumidifier_rh_setpoint],
                                 fraction_served: 1.0,
                                 location: HPXML::LocationConditionedSpace)
  end

  # Sets the HPXML clothes washer properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_clothes_washer(hpxml_bldg, args)
    return if args[:dhw_water_heater] == 'None'
    return if args[:appliance_clothes_washer] == 'None'

    case args[:appliance_clothes_washer_efficiency_type]
    when 'ModifiedEnergyFactor'
      modified_energy_factor = args[:appliance_clothes_washer_efficiency]
    when 'IntegratedModifiedEnergyFactor'
      integrated_modified_energy_factor = args[:appliance_clothes_washer_efficiency]
    end

    hpxml_bldg.clothes_washers.add(id: "ClothesWasher#{hpxml_bldg.clothes_washers.size + 1}",
                                   location: args[:appliance_clothes_washer_location],
                                   modified_energy_factor: modified_energy_factor,
                                   integrated_modified_energy_factor: integrated_modified_energy_factor,
                                   rated_annual_kwh: args[:appliance_clothes_washer_rated_annual_consumption],
                                   label_electric_rate: args[:appliance_clothes_washer_label_electric_rate],
                                   label_gas_rate: args[:appliance_clothes_washer_label_gas_rate],
                                   label_annual_gas_cost: args[:appliance_clothes_washer_label_annual_gas_cost],
                                   label_usage: args[:appliance_clothes_washer_label_usage],
                                   capacity: args[:appliance_clothes_washer_capacity],
                                   usage_multiplier: args[:appliance_clothes_washer_usage_multiplier])
  end

  # Sets the HPXML clothes dryer properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_clothes_dryer(hpxml_bldg, args)
    return if args[:dhw_water_heater] == 'None'
    return if args[:appliance_clothes_washer] == 'None'
    return if args[:appliance_clothes_dryer] == 'None'

    case args[:appliance_clothes_dryer_efficiency_type]
    when 'EnergyFactor'
      energy_factor = args[:appliance_clothes_dryer_efficiency]
    when 'CombinedEnergyFactor'
      combined_energy_factor = args[:appliance_clothes_dryer_efficiency]
    end

    hpxml_bldg.clothes_dryers.add(id: "ClothesDryer#{hpxml_bldg.clothes_dryers.size + 1}",
                                  location: args[:appliance_clothes_dryer_location],
                                  fuel_type: args[:appliance_clothes_dryer_fuel_type],
                                  drying_method: args[:appliance_clothes_dryer_drying_method],
                                  energy_factor: energy_factor,
                                  combined_energy_factor: combined_energy_factor,
                                  usage_multiplier: args[:appliance_clothes_dryer_usage_multiplier])
  end

  # Sets the HPXML dishwasher properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_dishwasher(hpxml_bldg, args)
    return if args[:dhw_water_heater] == 'None'
    return if args[:appliance_dishwasher] == 'None'

    case args[:appliance_dishwasher_efficiency_type]
    when 'RatedAnnualkWh'
      rated_annual_kwh = args[:appliance_dishwasher_efficiency]
    when 'EnergyFactor'
      energy_factor = args[:appliance_dishwasher_efficiency]
    end

    hpxml_bldg.dishwashers.add(id: "Dishwasher#{hpxml_bldg.dishwashers.size + 1}",
                               location: args[:appliance_dishwasher_location],
                               rated_annual_kwh: rated_annual_kwh,
                               energy_factor: energy_factor,
                               label_electric_rate: args[:appliance_dishwasher_label_electric_rate],
                               label_gas_rate: args[:appliance_dishwasher_label_gas_rate],
                               label_annual_gas_cost: args[:appliance_dishwasher_label_annual_gas_cost],
                               label_usage: args[:appliance_dishwasher_label_usage],
                               place_setting_capacity: args[:appliance_dishwasher_place_setting_capacity],
                               usage_multiplier: args[:appliance_dishwasher_usage_multiplier])
  end

  # Sets the HPXML primary refrigerator properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_refrigerator(hpxml_bldg, args)
    return if args[:appliance_refrigerator] == 'None'

    hpxml_bldg.refrigerators.add(id: "Refrigerator#{hpxml_bldg.refrigerators.size + 1}",
                                 location: args[:appliance_refrigerator_location],
                                 rated_annual_kwh: args[:appliance_refrigerator_rated_annual_consumption],
                                 usage_multiplier: args[:appliance_refrigerator_usage_multiplier])
  end

  # Sets the HPXML extra refrigerator properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_extra_refrigerator(hpxml_bldg, args)
    return if args[:appliance_extra_refrigerator] == 'None'

    hpxml_bldg.refrigerators.add(id: "Refrigerator#{hpxml_bldg.refrigerators.size + 1}",
                                 location: args[:appliance_extra_refrigerator_location],
                                 rated_annual_kwh: args[:appliance_extra_refrigerator_rated_annual_consumption],
                                 usage_multiplier: args[:appliance_extra_refrigerator_usage_multiplier],
                                 primary_indicator: false)
    hpxml_bldg.refrigerators[0].primary_indicator = true
  end

  # Sets the HPXML freezer properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_freezer(hpxml_bldg, args)
    return if args[:appliance_freezer] == 'None'

    hpxml_bldg.freezers.add(id: "Freezer#{hpxml_bldg.freezers.size + 1}",
                            location: args[:appliance_freezer_location],
                            rated_annual_kwh: args[:appliance_freezer_rated_annual_consumption],
                            usage_multiplier: args[:appliance_freezer_usage_multiplier])
  end

  # Sets the HPXML cooking range/oven properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_cooking_range_oven(hpxml_bldg, args)
    return if args[:appliance_cooking_range_oven] == 'None'

    hpxml_bldg.cooking_ranges.add(id: "CookingRange#{hpxml_bldg.cooking_ranges.size + 1}",
                                  location: args[:appliance_cooking_range_oven_location],
                                  fuel_type: args[:appliance_cooking_range_oven_fuel_type],
                                  is_induction: args[:appliance_cooking_range_oven_is_induction],
                                  usage_multiplier: args[:appliance_cooking_range_oven_usage_multiplier])

    hpxml_bldg.ovens.add(id: "Oven#{hpxml_bldg.ovens.size + 1}",
                         is_convection: args[:appliance_cooking_range_oven_is_convection])
  end

  # Sets the HPXML ceiling fans properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_ceiling_fans(hpxml_bldg, args)
    return if args[:ceiling_fans] == 'None'

    hpxml_bldg.ceiling_fans.add(id: "CeilingFan#{hpxml_bldg.ceiling_fans.size + 1}",
                                efficiency: args[:ceiling_fans_efficiency],
                                label_energy_use: args[:ceiling_fans_label_energy_use],
                                count: args[:ceiling_fans_count])
  end

  # Sets the HPXML miscellaneous television plug loads properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_misc_plug_loads_television(hpxml_bldg, args)
    return if args[:misc_television] == 'None'

    hpxml_bldg.plug_loads.add(id: "PlugLoad#{hpxml_bldg.plug_loads.size + 1}",
                              plug_load_type: HPXML::PlugLoadTypeTelevision,
                              kwh_per_year: args[:misc_television_annual_energy_use],
                              usage_multiplier: args[:misc_television_usage_multiplier])
  end

  # Sets the HPXML miscellaneous other plug loads properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_misc_plug_loads_other(hpxml_bldg, args)
    hpxml_bldg.plug_loads.add(id: "PlugLoad#{hpxml_bldg.plug_loads.size + 1}",
                              plug_load_type: HPXML::PlugLoadTypeOther,
                              kwh_per_year: args[:misc_plug_loads_annual_energy_use],
                              frac_sensible: args[:misc_plug_loads_sensible_fraction],
                              frac_latent: args[:misc_plug_loads_latent_fraction],
                              usage_multiplier: args[:misc_plug_loads_usage_multiplier])
  end

  # Sets the HPXML miscellaneous well pump plug loads properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_misc_plug_loads_well_pump(hpxml_bldg, args)
    return if args[:misc_well_pump] == 'None'

    hpxml_bldg.plug_loads.add(id: "PlugLoad#{hpxml_bldg.plug_loads.size + 1}",
                              plug_load_type: HPXML::PlugLoadTypeWellPump,
                              kwh_per_year: args[:misc_well_pump_annual_energy_use],
                              usage_multiplier: args[:misc_well_pump_usage_multiplier])
  end

  # Sets the HPXML miscellaneous vehicle plug loads properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_misc_plug_loads_vehicle(hpxml_bldg, args)
    return if args[:misc_electric_vehicle_charging] == 'None'

    hpxml_bldg.plug_loads.add(id: "PlugLoad#{hpxml_bldg.plug_loads.size + 1}",
                              plug_load_type: HPXML::PlugLoadTypeElectricVehicleCharging,
                              kwh_per_year: args[:misc_electric_vehicle_charging_annual_energy_use],
                              usage_multiplier: args[:misc_electric_vehicle_charging_usage_multiplier])
  end

  # Sets the HPXML miscellaneous grill fuel loads properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_misc_fuel_loads_grill(hpxml_bldg, args)
    return if args[:misc_grill] == 'None'

    hpxml_bldg.fuel_loads.add(id: "FuelLoad#{hpxml_bldg.fuel_loads.size + 1}",
                              fuel_load_type: HPXML::FuelLoadTypeGrill,
                              fuel_type: args[:misc_grill_fuel_type],
                              therm_per_year: args[:misc_grill_annual_energy_use],
                              usage_multiplier: args[:misc_grill_usage_multiplier])
  end

  # Sets the HPXML miscellaneous lighting fuel loads properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_misc_fuel_loads_lighting(hpxml_bldg, args)
    return if args[:misc_gas_lighting] == 'None'

    hpxml_bldg.fuel_loads.add(id: "FuelLoad#{hpxml_bldg.fuel_loads.size + 1}",
                              fuel_load_type: HPXML::FuelLoadTypeLighting,
                              fuel_type: args[:misc_gas_lighting_fuel_type],
                              therm_per_year: args[:misc_gas_lighting_annual_energy_use],
                              usage_multiplier: args[:misc_gas_lighting_usage_multiplier])
  end

  # Sets the HPXML miscellaneous fireplace fuel loads properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_misc_fuel_loads_fireplace(hpxml_bldg, args)
    return if args[:misc_fireplace] == 'None'

    hpxml_bldg.fuel_loads.add(id: "FuelLoad#{hpxml_bldg.fuel_loads.size + 1}",
                              fuel_load_type: HPXML::FuelLoadTypeFireplace,
                              fuel_type: args[:misc_fireplace_fuel_type],
                              therm_per_year: args[:misc_fireplace_annual_energy_use],
                              usage_multiplier: args[:misc_fireplace_usage_multiplier])
  end

  # Sets the HPXML pool properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_pool(hpxml_bldg, args)
    return if args[:misc_pool] == 'None'

    case args[:misc_pool_heater_type]
    when HPXML::HeaterTypeElectricResistance, HPXML::HeaterTypeHeatPump
      if not args[:misc_pool_heater_annual_electricity_use].nil?
        heater_load_units = HPXML::UnitsKwhPerYear
        heater_load_value = args[:misc_pool_heater_annual_electricity_use]
      end
    when HPXML::HeaterTypeGas
      if not args[:misc_pool_heater_annual_natural_gas_use].nil?
        heater_load_units = HPXML::UnitsThermPerYear
        heater_load_value = args[:misc_pool_heater_annual_natural_gas_use]
      end
    end

    hpxml_bldg.pools.add(id: "Pool#{hpxml_bldg.pools.size + 1}",
                         type: HPXML::TypeUnknown,
                         pump_id: "Pool#{hpxml_bldg.pools.size + 1}Pump",
                         pump_type: HPXML::TypeUnknown,
                         pump_kwh_per_year: args[:misc_pool_pump_annual_energy_use],
                         pump_usage_multiplier: args[:misc_pool_pump_usage_multiplier],
                         heater_id: "Pool#{hpxml_bldg.pools.size + 1}Heater",
                         heater_type: args[:misc_pool_heater_type],
                         heater_load_units: heater_load_units,
                         heater_load_value: heater_load_value,
                         heater_usage_multiplier: args[:misc_pool_heater_usage_multiplier])
  end

  # Sets the HPXML permanent spa properties.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def set_permanent_spa(hpxml_bldg, args)
    return if args[:misc_permanent_spa] == 'None'

    case args[:misc_permanent_spa_heater_type]
    when HPXML::HeaterTypeElectricResistance, HPXML::HeaterTypeHeatPump
      if not args[:misc_permanent_spa_heater_annual_electricity_use].nil?
        heater_load_units = HPXML::UnitsKwhPerYear
        heater_load_value = args[:misc_permanent_spa_heater_annual_electricity_use]
      end
    when HPXML::HeaterTypeGas
      if not args[:misc_permanent_spa_heater_annual_natural_gas_use].nil?
        heater_load_units = HPXML::UnitsThermPerYear
        heater_load_value = args[:misc_permanent_spa_heater_annual_natural_gas_use]
      end
    end

    hpxml_bldg.permanent_spas.add(id: "PermanentSpa#{hpxml_bldg.permanent_spas.size + 1}",
                                  type: HPXML::TypeUnknown,
                                  pump_id: "PermanentSpa#{hpxml_bldg.permanent_spas.size + 1}Pump",
                                  pump_type: HPXML::TypeUnknown,
                                  pump_kwh_per_year: args[:misc_permanent_spa_pump_annual_energy_use],
                                  pump_usage_multiplier: args[:misc_permanent_spa_pump_usage_multiplier],
                                  heater_id: "PermanentSpa#{hpxml_bldg.permanent_spas.size + 1}Heater",
                                  heater_type: args[:misc_permanent_spa_heater_type],
                                  heater_load_units: heater_load_units,
                                  heater_load_value: heater_load_value,
                                  heater_usage_multiplier: args[:misc_permanent_spa_heater_usage_multiplier])
  end

  # Combine surfaces to simplify the HPXML file.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param args [Hash] Map of :argument_name => value
  # @return [nil]
  def collapse_surfaces(hpxml_bldg, args)
    if args[:combine_like_surfaces]
      # Collapse some surfaces whose azimuth is a minor effect to simplify HPXMLs.
      (hpxml_bldg.roofs + hpxml_bldg.rim_joists + hpxml_bldg.walls + hpxml_bldg.foundation_walls).each do |surface|
        surface.azimuth = nil
      end
      hpxml_bldg.collapse_enclosure_surfaces()
    else
      # Collapse surfaces so that we don't get, e.g., individual windows
      # or the front wall split because of the door. Exclude foundation walls
      # from the list so we get all 4 foundation walls.
      hpxml_bldg.collapse_enclosure_surfaces([:roofs, :walls, :rim_joists, :floors,
                                              :slabs, :windows, :skylights, :doors])
    end

    # After surfaces are collapsed, round all areas
    (hpxml_bldg.surfaces + hpxml_bldg.subsurfaces).each do |s|
      s.area = s.area.round(1)
    end
  end

  # After having collapsed some surfaces, renumber SystemIdentifier ids and AttachedToXXX idrefs.
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @return [nil]
  def renumber_hpxml_ids(hpxml_bldg)
    # Renumber surfaces
    indexes = {}
    (hpxml_bldg.surfaces + hpxml_bldg.subsurfaces).each do |surf|
      surf_name = surf.class.to_s.gsub('HPXML::', '')
      indexes[surf_name] = 0 if indexes[surf_name].nil?
      indexes[surf_name] += 1
      (hpxml_bldg.attics + hpxml_bldg.foundations).each do |attic_or_fnd|
        if attic_or_fnd.respond_to?(:attached_to_roof_idrefs) && !attic_or_fnd.attached_to_roof_idrefs.nil? && !attic_or_fnd.attached_to_roof_idrefs.delete(surf.id).nil?
          attic_or_fnd.attached_to_roof_idrefs << "#{surf_name}#{indexes[surf_name]}"
        end
        if attic_or_fnd.respond_to?(:attached_to_wall_idrefs) && !attic_or_fnd.attached_to_wall_idrefs.nil? && !attic_or_fnd.attached_to_wall_idrefs.delete(surf.id).nil?
          attic_or_fnd.attached_to_wall_idrefs << "#{surf_name}#{indexes[surf_name]}"
        end
        if attic_or_fnd.respond_to?(:attached_to_rim_joist_idrefs) && !attic_or_fnd.attached_to_rim_joist_idrefs.nil? && !attic_or_fnd.attached_to_rim_joist_idrefs.delete(surf.id).nil?
          attic_or_fnd.attached_to_rim_joist_idrefs << "#{surf_name}#{indexes[surf_name]}"
        end
        if attic_or_fnd.respond_to?(:attached_to_floor_idrefs) && !attic_or_fnd.attached_to_floor_idrefs.nil? && !attic_or_fnd.attached_to_floor_idrefs.delete(surf.id).nil?
          attic_or_fnd.attached_to_floor_idrefs << "#{surf_name}#{indexes[surf_name]}"
        end
        if attic_or_fnd.respond_to?(:attached_to_slab_idrefs) && !attic_or_fnd.attached_to_slab_idrefs.nil? && !attic_or_fnd.attached_to_slab_idrefs.delete(surf.id).nil?
          attic_or_fnd.attached_to_slab_idrefs << "#{surf_name}#{indexes[surf_name]}"
        end
        if attic_or_fnd.respond_to?(:attached_to_foundation_wall_idrefs) && !attic_or_fnd.attached_to_foundation_wall_idrefs.nil? && !attic_or_fnd.attached_to_foundation_wall_idrefs.delete(surf.id).nil?
          attic_or_fnd.attached_to_foundation_wall_idrefs << "#{surf_name}#{indexes[surf_name]}"
        end
      end
      (hpxml_bldg.windows + hpxml_bldg.doors).each do |subsurf|
        if subsurf.respond_to?(:attached_to_wall_idref) && (subsurf.attached_to_wall_idref == surf.id)
          subsurf.attached_to_wall_idref = "#{surf_name}#{indexes[surf_name]}"
        end
      end
      hpxml_bldg.skylights.each do |subsurf|
        if subsurf.respond_to?(:attached_to_roof_idref) && (subsurf.attached_to_roof_idref == surf.id)
          subsurf.attached_to_roof_idref = "#{surf_name}#{indexes[surf_name]}"
        end
      end
      surf.id = "#{surf_name}#{indexes[surf_name]}"
      if surf.respond_to?(:insulation_id) && (not surf.insulation_id.nil?)
        surf.insulation_id = "#{surf_name}#{indexes[surf_name]}Insulation"
      end
      if surf.respond_to?(:perimeter_insulation_id) && (not surf.perimeter_insulation_id.nil?)
        surf.perimeter_insulation_id = "#{surf_name}#{indexes[surf_name]}PerimeterInsulation"
      end
      if surf.respond_to?(:exterior_horizontal_insulation_id) && (not surf.exterior_horizontal_insulation_id.nil?)
        surf.exterior_horizontal_insulation_id = "#{surf_name}#{indexes[surf_name]}ExteriorHorizontalInsulation"
      end
      if surf.respond_to?(:under_slab_insulation_id) && (not surf.under_slab_insulation_id.nil?)
        surf.under_slab_insulation_id = "#{surf_name}#{indexes[surf_name]}UnderSlabInsulation"
      end
    end
  end
end

# register the measure to be used by the application
BuildResidentialHPXML.new.registerWithApplication
