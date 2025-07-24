
###### (Automatically generated documentation)

# HPXML Builder

## Description
Builds a residential HPXML file.

The measure handles geometry by 1) translating high-level geometry inputs (conditioned floor area, number of stories, etc.) to 3D closed-form geometry in an OpenStudio model and then 2) mapping the OpenStudio surfaces to HPXML surfaces (using surface type, boundary condition, area, orientation, etc.). Like surfaces are collapsed into a single surface with aggregate surface area. Note: OS-HPXML default values can be found in the documentation or can be seen by using the 'apply_defaults' argument.

## Arguments


**HPXML File Path**

Absolute/relative path of the HPXML file.

- **Name:** ``hpxml_path``
- **Type:** ``String``

- **Required:** ``true``

<br/>

**Existing HPXML File Path**

Absolute/relative path of the existing HPXML file. If not provided, a new HPXML file with one Building element is created. If provided, a new Building element will be appended to this HPXML file (e.g., to create a multifamily HPXML file describing multiple dwelling units).

- **Name:** ``existing_hpxml_path``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Whole SFA/MF Building Simulation?**

If the HPXML file represents a single family-attached/multifamily building with multiple dwelling units defined, specifies whether to run the HPXML file as a single whole building model.

- **Name:** ``whole_sfa_or_mf_building_sim``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Software Info: Program Used**

The name of the software program used.

- **Name:** ``software_info_program_used``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Software Info: Program Version**

The version of the software program used.

- **Name:** ``software_info_program_version``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Schedules: CSV File Paths**

Absolute/relative paths of csv files containing user-specified detailed schedules. If multiple files, use a comma-separated list.

- **Name:** ``schedules_filepaths``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Schedules: Unavailable Period Types**

Specifies the unavailable period types. Possible types are column names defined in unavailable_periods.csv: Vacancy, Power Outage, No Space Heating, No Space Cooling. If multiple periods, use a comma-separated list.

- **Name:** ``schedules_unavailable_period_types``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Schedules: Unavailable Period Dates**

Specifies the unavailable period date ranges. Enter a date range like "Dec 15 - Jan 15". Optionally, can enter hour of the day like "Dec 15 2 - Jan 15 20" (start hour can be 0 through 23 and end hour can be 1 through 24). If multiple periods, use a comma-separated list.

- **Name:** ``schedules_unavailable_period_dates``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Schedules: Unavailable Period Window Natural Ventilation Availabilities**

The availability of the natural ventilation schedule during unavailable periods. Valid choices are: regular schedule, always available, always unavailable. If multiple periods, use a comma-separated list. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-unavailable-periods'>HPXML Unavailable Periods</a>) is used.

- **Name:** ``schedules_unavailable_period_window_natvent_availabilities``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Simulation Control: Timestep**

Value must be a divisor of 60. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-simulation-control'>HPXML Simulation Control</a>) is used.

- **Name:** ``simulation_control_timestep``
- **Type:** ``Integer``

- **Units:** ``min``

- **Required:** ``false``

<br/>

**Simulation Control: Run Period**

Enter a date range like 'Jan 1 - Dec 31'. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-simulation-control'>HPXML Simulation Control</a>) is used.

- **Name:** ``simulation_control_run_period``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Simulation Control: Temperature Capacitance Multiplier**

Affects the transient calculation of indoor air temperatures. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-simulation-control'>HPXML Simulation Control</a>) is used.

- **Name:** ``simulation_control_temperature_capacitance_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Site: Type**

The type of site. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-site'>HPXML Site</a>) is used.

- **Name:** ``site_type``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `suburban`, `urban`, `rural`

<br/>

**Site: Shielding of Home**

Presence of nearby buildings, trees, obstructions for infiltration model. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-site'>HPXML Site</a>) is used.

- **Name:** ``site_shielding_of_home``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `exposed`, `normal`, `well-shielded`

<br/>

**Site: Soil Type**

The soil and moisture type.

- **Name:** ``site_soil_type``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Unknown`, `Clay, Dry`, `Clay, Mixed`, `Clay, Wet`, `Gravel, Dry`, `Gravel, Mixed`, `Gravel, Wet`, `Loam, Dry`, `Loam, Mixed`, `Loam, Wet`, `Sand, Dry`, `Sand, Mixed`, `Sand, Wet`, `Silt, Dry`, `Silt, Mixed`, `Silt, Wet`, `0.5 Conductivity`, `0.8 Conductivity`, `1.1 Conductivity`, `1.4 Conductivity`, `1.7 Conductivity`, `2.0 Conductivity`, `2.3 Conductivity`, `2.6 Conductivity`, `Detailed Example: Sand, Dry, 0.03 Diffusivity`

<br/>

**Site: Zip Code**

Zip code of the home address. Either this or the Weather Station: EnergyPlus Weather (EPW) Filepath input below must be provided.

- **Name:** ``site_zip_code``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Weather Station: EnergyPlus Weather (EPW) Filepath**

Path of the EPW file. Either this or the Site: Zip Code input above must be provided.

- **Name:** ``weather_station_epw_filepath``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Building Construction: Year Built**

The year the building was built.

- **Name:** ``year_built``
- **Type:** ``Integer``

- **Required:** ``false``

<br/>

**Building Construction: Unit Multiplier**

The number of similar dwelling units. EnergyPlus simulation results will be multiplied this value. If not provided, defaults to 1.

- **Name:** ``unit_multiplier``
- **Type:** ``Integer``

- **Required:** ``false``

<br/>

**Geometry: Unit Type**

The type of dwelling unit. Use single-family attached for a dwelling unit with 1 or more stories, attached units to one or both sides, and no units above/below. Use apartment unit for a dwelling unit with 1 story, attached units to one, two, or three sides, and units above and/or below.

- **Name:** ``geometry_unit_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `single-family detached`, `single-family attached`, `apartment unit`, `manufactured home`

<br/>

**Geometry: Unit Attached Walls**

The location of the attached walls if a dwelling unit of type 'single-family attached' or 'apartment unit'.

- **Name:** ``geometry_attached_walls``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `1 Side: Front`, `1 Side: Back`, `1 Side: Left`, `1 Side: Right`, `2 Sides: Front, Left`, `2 Sides: Front, Right`, `2 Sides: Back, Left`, `2 Sides: Back, Right`, `2 Sides: Front, Back`, `2 Sides: Left, Right`, `3 Sides: Front, Back, Left`, `3 Sides: Front, Back, Right`, `3 Sides: Front, Left, Right`, `3 Sides: Back, Left, Right`

<br/>

**Geometry: Unit Number of Floors Above Grade**

The number of floors above grade in the unit. Attic type ConditionedAttic is included. Assumed to be 1 for apartment units.

- **Name:** ``geometry_unit_num_floors_above_grade``
- **Type:** ``Integer``

- **Units:** ``#``

- **Required:** ``true``

<br/>

**Geometry: Unit Conditioned Floor Area**

The total floor area of the unit's conditioned space (including any conditioned basement floor area).

- **Name:** ``geometry_unit_cfa``
- **Type:** ``Double``

- **Units:** ``ft2``

- **Required:** ``true``

<br/>

**Geometry: Unit Aspect Ratio**

The ratio of front/back wall length to left/right wall length for the unit, excluding any protruding garage wall area.

- **Name:** ``geometry_unit_aspect_ratio``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**Geometry: Unit Orientation**

The unit's orientation is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).

- **Name:** ``geometry_unit_orientation``
- **Type:** ``Double``

- **Units:** ``degrees``

- **Required:** ``true``

<br/>

**Geometry: Unit Number of Bedrooms**

The number of bedrooms in the unit.

- **Name:** ``geometry_unit_num_bedrooms``
- **Type:** ``Integer``

- **Units:** ``#``

- **Required:** ``true``

<br/>

**Geometry: Unit Number of Bathrooms**

The number of bathrooms in the unit. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-building-construction'>HPXML Building Construction</a>) is used.

- **Name:** ``geometry_unit_num_bathrooms``
- **Type:** ``Integer``

- **Units:** ``#``

- **Required:** ``false``

<br/>

**Geometry: Unit Number of Occupants**

The number of occupants in the unit. If not provided, an *asset* calculation is performed assuming standard occupancy, in which various end use defaults (e.g., plug loads, appliances, and hot water usage) are calculated based on Number of Bedrooms and Conditioned Floor Area per ANSI/RESNET/ICC 301. If provided, an *operational* calculation is instead performed in which the end use defaults to reflect real-world data (where possible).

- **Name:** ``geometry_unit_num_occupants``
- **Type:** ``Double``

- **Units:** ``#``

- **Required:** ``false``

<br/>

**Geometry: Building Number of Units**

The number of units in the building. Required for single-family attached and apartment units.

- **Name:** ``geometry_building_num_units``
- **Type:** ``Integer``

- **Units:** ``#``

- **Required:** ``false``

<br/>

**Geometry: Average Ceiling Height**

Average distance from the floor to the ceiling.

- **Name:** ``geometry_average_ceiling_height``
- **Type:** ``Double``

- **Units:** ``ft``

- **Required:** ``true``

<br/>

**Geometry: Unit Height Above Grade**

Describes the above-grade height of apartment units on upper floors or homes above ambient or belly-and-wing foundations. It is defined as the height of the lowest conditioned floor above grade and is used to calculate the wind speed for the infiltration model. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-building-construction'>HPXML Building Construction</a>) is used.

- **Name:** ``geometry_unit_height_above_grade``
- **Type:** ``Double``

- **Units:** ``ft``

- **Required:** ``false``

<br/>

**Geometry: Attached Garage**

The type of attached garage. Only applies to single-family detached units.

- **Name:** ``geometry_garage_type``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `1 Car, Left, Fully Inset`, `1 Car, Left, Half Protruding`, `1 Car, Left, Fully Protruding`, `1 Car, Right, Fully Inset`, `1 Car, Right, Half Protruding`, `1 Car, Right, Fully Protruding`, `2 Car, Left, Fully Inset`, `2 Car, Left, Half Protruding`, `2 Car, Left, Fully Protruding`, `2 Car, Right, Fully Inset`, `2 Car, Right, Half Protruding`, `2 Car, Right, Fully Protruding`, `3 Car, Left, Fully Inset`, `3 Car, Left, Half Protruding`, `3 Car, Left, Fully Protruding`, `3 Car, Right, Fully Inset`, `3 Car, Right, Half Protruding`, `3 Car, Right, Fully Protruding`

<br/>

**Geometry: Foundation Type**

The foundation type of the building. Garages are assumed to be over slab-on-grade.

- **Name:** ``geometry_foundation_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `Slab-on-Grade`, `Crawlspace, Vented`, `Crawlspace, Unvented`, `Crawlspace, Conditioned`, `Basement, Unconditioned`, `Basement, Unconditioned, Half Above-Grade`, `Basement, Conditioned`, `Basement, Conditioned, Half Above-Grade`, `Ambient`, `Above Apartment`, `Belly and Wing, With Skirt`, `Belly and Wing, No Skirt`, `Detailed Example: Basement, Unconditioned, 7.25 ft Height, 8 in Above-Grade, 9 in Rim Joists`, `Detailed Example: Basement, Conditioned, 7.25 ft Height, 8 in Above-Grade, 9 in Rim Joists`, `Detailed Example: Basement, Conditioned, 5 ft Height`, `Detailed Example: Crawlspace, Vented, Above-Grade`

<br/>

**Geometry: Attic Type**

The attic/roof type of the building.

- **Name:** ``geometry_attic_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `Flat Roof`, `Attic, Vented, Gable`, `Attic, Vented, Hip`, `Attic, Unvented, Gable`, `Attic, Unvented, Hip`, `Attic, Conditioned, Gable`, `Attic, Conditioned, Hip`, `Below Apartment`

<br/>

**Geometry: Roof Pitch**

The roof pitch of the attic. Ignored if the building has a flat roof.

- **Name:** ``geometry_roof_pitch``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `1:12`, `2:12`, `3:12`, `4:12`, `5:12`, `6:12`, `7:12`, `8:12`, `9:12`, `10:12`, `11:12`, `12:12`

<br/>

**Geometry: Eaves**

The type of eaves extending from the roof.

- **Name:** ``geometry_eaves``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `1 ft`, `2 ft`, `3 ft`, `4 ft`, `5 ft`

<br/>

**Geometry: Neighbor Buildings**

The presence and geometry of neighboring buildings, for shading purposes.

- **Name:** ``geometry_neighbor_buildings``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Left/Right at 5ft`, `Left/Right at 10ft`, `Left/Right at 15ft`, `Left/Right at 20ft`, `Left/Right at 25ft`, `Left at 5ft`, `Left at 10ft`, `Left at 15ft`, `Left at 20ft`, `Left at 25ft`, `Right at 5ft`, `Right at 10ft`, `Right at 15ft`, `Right at 20ft`, `Right at 25ft`, `Detailed Example: Left/Right at 25ft, Front/Back at 80ft, 12ft Height`

<br/>

**Enclosure: Floor Over Foundation**

The type and insulation level of the floor over the foundation (e.g., crawlspace or basement).

- **Name:** ``enclosure_floor_over_foundation``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Wood Frame, Uninsulated`, `Wood Frame, R-11`, `Wood Frame, R-13`, `Wood Frame, R-15`, `Wood Frame, R-19`, `Wood Frame, R-21`, `Wood Frame, R-25`, `Wood Frame, R-30`, `Wood Frame, R-35`, `Wood Frame, R-38`, `Wood Frame, IECC U-0.064`, `Wood Frame, IECC U-0.047`, `Wood Frame, IECC U-0.033`, `Wood Frame, IECC U-0.028`, `Detailed Example: Wood Frame, Uninsulated, 2x6, 24 in o.c., 10% Framing, No Carpet/Subfloor`, `Detailed Example: Wood Frame, R-11, 2x6, 24 in o.c., 13% Framing, No Carpet/Subfloor`, `Detailed Example: Wood Frame, R-11, 2x6, 24 in o.c., 10% Framing, No Carpet/Subfloor`

<br/>

**Enclosure: Floor Over Garage**

The type and insulation level of the floor over the garage.

- **Name:** ``enclosure_floor_over_garage``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Wood Frame, Uninsulated`, `Wood Frame, R-11`, `Wood Frame, R-13`, `Wood Frame, R-15`, `Wood Frame, R-19`, `Wood Frame, R-21`, `Wood Frame, R-25`, `Wood Frame, R-30`, `Wood Frame, R-35`, `Wood Frame, R-38`, `Wood Frame, IECC U-0.064`, `Wood Frame, IECC U-0.047`, `Wood Frame, IECC U-0.033`, `Detailed Example: Wood Frame, Uninsulated, 2x6, 24 in o.c., 10% Framing, No Carpet/Subfloor`, `Detailed Example: Wood Frame, R-11, 2x6, 24 in o.c., 13% Framing, No Carpet/Subfloor`, `Detailed Example: Wood Frame, R-11, 2x6, 24 in o.c., 10% Framing, No Carpet/Subfloor`

<br/>

**Enclosure: Foundation Wall**

The type and insulation level of the foundation walls.

- **Name:** ``enclosure_foundation_wall``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Solid Concrete, Uninsulated`, `Solid Concrete, Half Wall, R-5`, `Solid Concrete, Half Wall, R-10`, `Solid Concrete, Half Wall, R-15`, `Solid Concrete, Half Wall, R-20`, `Solid Concrete, Whole Wall, R-5`, `Solid Concrete, Whole Wall, R-10`, `Solid Concrete, Whole Wall, R-10.2, Interior`, `Solid Concrete, Whole Wall, R-15`, `Solid Concrete, Whole Wall, R-20`, `Solid Concrete, Assembly R-10.69`, `Concrete Block Foam Core, Whole Wall, R-18.9`

<br/>

**Enclosure: Rim Joists**

The type and insulation level of the rim joists.

- **Name:** ``enclosure_rim_joist``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Uninsulated`, `R-7`, `R-11`, `R-13`, `R-15`, `R-19`, `R-21`, `Detailed Example: Uninsulated, Fiberboard Sheathing, Hardboard Siding`, `Detailed Example: R-11, Fiberboard Sheathing, Hardboard Siding`

<br/>

**Enclosure: Slab**

The type and insulation level of the slab. Applies to slab-on-grade as well as basement/crawlspace foundations. Under Slab insulation is placed horizontally from the edge of the slab inward. Perimeter insulation is placed vertically from the top of the slab downward. Whole Slab insulation is placed horizontally below the entire slab area.

- **Name:** ``enclosure_slab``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Uninsulated`, `Under Slab, 2ft, R-5`, `Under Slab, 2ft, R-10`, `Under Slab, 2ft, R-15`, `Under Slab, 2ft, R-20`, `Under Slab, 4ft, R-5`, `Under Slab, 4ft, R-10`, `Under Slab, 4ft, R-15`, `Under Slab, 4ft, R-20`, `Perimeter, 2ft, R-5`, `Perimeter, 2ft, R-10`, `Perimeter, 2ft, R-15`, `Perimeter, 2ft, R-20`, `Perimeter, 4ft, R-5`, `Perimeter, 4ft, R-10`, `Perimeter, 4ft, R-15`, `Perimeter, 4ft, R-20`, `Whole Slab, R-5`, `Whole Slab, R-10`, `Whole Slab, R-15`, `Whole Slab, R-20`, `Whole Slab, R-30`, `Whole Slab, R-40`, `Detailed Example: Uninsulated, No Carpet`, `Detailed Example: Uninsulated, 100% R-2.08 Carpet`, `Detailed Example: Uninsulated, 100% R-2.50 Carpet`, `Detailed Example: Perimeter, 2ft, R-5, 100% R-2.08 Carpet`, `Detailed Example: Whole Slab, R-5, 100% R-2.5 Carpet`

<br/>

**Enclosure: Ceiling**

The type and insulation level of the ceiling (attic floor).

- **Name:** ``enclosure_ceiling``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `Uninsulated`, `R-7`, `R-13`, `R-19`, `R-30`, `R-38`, `R-49`, `R-60`, `IECC U-0.035`, `IECC U-0.030`, `IECC U-0.026`, `IECC U-0.024`, `Detailed Example: R-11, 2x6, 24 in o.c., 10% Framing`, `Detailed Example: R-19, 2x6, 24 in o.c., 10% Framing`, `Detailed Example: R-19 + R-38, 2x6, 24 in o.c., 10% Framing`

<br/>

**Enclosure: Roof**

The type and insulation level of the roof.

- **Name:** ``enclosure_roof``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `Uninsulated`, `R-7`, `R-13`, `R-19`, `R-30`, `R-38`, `R-49`, `IECC U-0.035`, `IECC U-0.030`, `IECC U-0.026`, `IECC U-0.024`, `Detailed Example: Uninsulated, 0.5 in plywood, 0.25 in asphalt shingle`

<br/>

**Enclosure: Roof Material**

The material type and color of the roof. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-roofs'>HPXML Roofs</a>) is used.

- **Name:** ``enclosure_roof_material``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Asphalt/Fiberglass Shingles, Dark`, `Asphalt/Fiberglass Shingles, Medium Dark`, `Asphalt/Fiberglass Shingles, Medium`, `Asphalt/Fiberglass Shingles, Light`, `Asphalt/Fiberglass Shingles, Reflective`, `Tile/Slate, Dark`, `Tile/Slate, Medium Dark`, `Tile/Slate, Medium`, `Tile/Slate, Light`, `Tile/Slate, Reflective`, `Metal, Dark`, `Metal, Medium Dark`, `Metal, Medium`, `Metal, Light`, `Metal, Reflective`, `Wood Shingles/Shakes, Dark`, `Wood Shingles/Shakes, Medium Dark`, `Wood Shingles/Shakes, Medium`, `Wood Shingles/Shakes, Light`, `Wood Shingles/Shakes, Reflective`, `Shingles, Dark`, `Shingles, Medium Dark`, `Shingles, Medium`, `Shingles, Light`, `Shingles, Reflective`, `Synthetic Sheeting, Dark`, `Synthetic Sheeting, Medium Dark`, `Synthetic Sheeting, Medium`, `Synthetic Sheeting, Light`, `Synthetic Sheeting, Reflective`, `EPS Sheathing, Dark`, `EPS Sheathing, Medium Dark`, `EPS Sheathing, Medium`, `EPS Sheathing, Light`, `EPS Sheathing, Reflective`, `Concrete, Dark`, `Concrete, Medium Dark`, `Concrete, Medium`, `Concrete, Light`, `Concrete, Reflective`, `Cool Roof`, `Detailed Example: 0.2 Solar Absorptance`, `Detailed Example: 0.4 Solar Absorptance`, `Detailed Example: 0.6 Solar Absorptance`, `Detailed Example: 0.75 Solar Absorptance`

<br/>

**Enclosure: Radiant Barrier**

The type of radiant barrier in the attic.

- **Name:** ``enclosure_radiant_barrier``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Attic Roof Only`, `Attic Roof and Gable Walls`, `Attic Floor`

<br/>

**Enclosure: Walls**

The type and insulation level of the walls.

- **Name:** ``enclosure_wall``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `Wood Stud, Uninsulated`, `Wood Stud, R-7`, `Wood Stud, R-11`, `Wood Stud, R-13`, `Wood Stud, R-15`, `Wood Stud, R-19`, `Wood Stud, R-21`, `Double Wood Stud, R-33`, `Double Wood Stud, R-39`, `Double Wood Stud, R-45`, `Steel Stud, Uninsulated`, `Steel Stud, R-11`, `Steel Stud, R-13`, `Steel Stud, R-15`, `Steel Stud, R-19`, `Steel Stud, R-21`, `Steel Stud, R-25`, `Concrete Masonry Unit, Hollow or Concrete Filled, Uninsulated`, `Concrete Masonry Unit, Hollow or Concrete Filled, R-7`, `Concrete Masonry Unit, Hollow or Concrete Filled, R-11`, `Concrete Masonry Unit, Hollow or Concrete Filled, R-13`, `Concrete Masonry Unit, Hollow or Concrete Filled, R-15`, `Concrete Masonry Unit, Hollow or Concrete Filled, R-19`, `Concrete Masonry Unit, Perlite Filled, Uninsulated`, `Concrete Masonry Unit, Perlite Filled, R-7`, `Concrete Masonry Unit, Perlite Filled, R-11`, `Concrete Masonry Unit, Perlite Filled, R-13`, `Concrete Masonry Unit, Perlite Filled, R-15`, `Concrete Masonry Unit, Perlite Filled, R-19`, `Structural Insulated Panel, R-17.5`, `Structural Insulated Panel, R-27.5`, `Structural Insulated Panel, R-37.5`, `Structural Insulated Panel, R-47.5`, `Insulated Concrete Forms, R-5 per side`, `Insulated Concrete Forms, R-10 per side`, `Insulated Concrete Forms, R-15 per side`, `Insulated Concrete Forms, R-20 per side`, `Structural Brick, Uninsulated`, `Structural Brick, R-7`, `Structural Brick, R-11`, `Structural Brick, R-15`, `Structural Brick, R-19`, `Wood Stud, IECC U-0.084`, `Wood Stud, IECC U-0.082`, `Wood Stud, IECC U-0.060`, `Wood Stud, IECC U-0.057`, `Wood Stud, IECC U-0.048`, `Wood Stud, IECC U-0.045`, `Detailed Example: Wood Stud, Uninsulated, 2x4, 16 in o.c., 25% Framing`, `Detailed Example: Wood Stud, R-11, 2x4, 16 in o.c., 25% Framing`, `Detailed Example: Wood Stud, R-18, 2x6, 24 in o.c., 25% Framing`

<br/>

**Enclosure: Wall Continuous Insulation**

The insulation level of the wall continuous insulation. The R-value of the continuous insulation will be ignored if a wall option with an IECC U-factor is selected.

- **Name:** ``enclosure_wall_continuous_insulation``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Uninsulated`, `R-5`, `R-6`, `R-7`, `R-10`, `R-12`, `R-14`, `R-15`, `R-18`, `R-20`, `R-21`, `Detailed Example: R-7.2`

<br/>

**Enclosure: Wall Siding**

The type, color, and insulation level of the wall siding. The R-value of the siding will be ignored if a wall option with an IECC U-factor is selected.

- **Name:** ``enclosure_wall_siding``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Aluminum, Dark`, `Aluminum, Medium`, `Aluminum, Medium Dark`, `Aluminum, Light`, `Aluminum, Reflective`, `Brick, Dark`, `Brick, Medium`, `Brick, Medium Dark`, `Brick, Light`, `Brick, Reflective`, `Fiber-Cement, Dark`, `Fiber-Cement, Medium`, `Fiber-Cement, Medium Dark`, `Fiber-Cement, Light`, `Fiber-Cement, Reflective`, `Asbestos, Dark`, `Asbestos, Medium`, `Asbestos, Medium Dark`, `Asbestos, Light`, `Asbestos, Reflective`, `Composition Shingle, Dark`, `Composition Shingle, Medium`, `Composition Shingle, Medium Dark`, `Composition Shingle, Light`, `Composition Shingle, Reflective`, `Stucco, Dark`, `Stucco, Medium`, `Stucco, Medium Dark`, `Stucco, Light`, `Stucco, Reflective`, `Vinyl, Dark`, `Vinyl, Medium`, `Vinyl, Medium Dark`, `Vinyl, Light`, `Vinyl, Reflective`, `Wood, Dark`, `Wood, Medium`, `Wood, Medium Dark`, `Wood, Light`, `Wood, Reflective`, `Synthetic Stucco, Dark`, `Synthetic Stucco, Medium`, `Synthetic Stucco, Medium Dark`, `Synthetic Stucco, Light`, `Synthetic Stucco, Reflective`, `Masonite, Dark`, `Masonite, Medium`, `Masonite, Medium Dark`, `Masonite, Light`, `Masonite, Reflective`, `Detailed Example: 0.2 Solar Absorptance`, `Detailed Example: 0.4 Solar Absorptance`, `Detailed Example: 0.6 Solar Absorptance`, `Detailed Example: 0.75 Solar Absorptance`

<br/>

**Enclosure: Windows**

The type of windows.

- **Name:** ``enclosure_window``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `Single, Clear, Metal`, `Single, Clear, Non-Metal`, `Double, Clear, Metal, Air`, `Double, Clear, Thermal-Break, Air`, `Double, Clear, Non-Metal, Air`, `Double, Low-E, Non-Metal, Air, High Gain`, `Double, Low-E, Non-Metal, Air, Med Gain`, `Double, Low-E, Non-Metal, Air, Low Gain`, `Double, Low-E, Non-Metal, Gas, High Gain`, `Double, Low-E, Non-Metal, Gas, Med Gain`, `Double, Low-E, Non-Metal, Gas, Low Gain`, `Double, Low-E, Insulated, Air, High Gain`, `Double, Low-E, Insulated, Air, Med Gain`, `Double, Low-E, Insulated, Air, Low Gain`, `Double, Low-E, Insulated, Gas, High Gain`, `Double, Low-E, Insulated, Gas, Med Gain`, `Double, Low-E, Insulated, Gas, Low Gain`, `Triple, Low-E, Non-Metal, Air, High Gain`, `Triple, Low-E, Non-Metal, Air, Low Gain`, `Triple, Low-E, Non-Metal, Gas, High Gain`, `Triple, Low-E, Non-Metal, Gas, Low Gain`, `Triple, Low-E, Insulated, Air, High Gain`, `Triple, Low-E, Insulated, Air, Low Gain`, `Triple, Low-E, Insulated, Gas, High Gain`, `Triple, Low-E, Insulated, Gas, Low Gain`, `IECC U-1.20, SHGC=0.40`, `IECC U-1.20, SHGC=0.30`, `IECC U-1.20, SHGC=0.25`, `IECC U-0.75, SHGC=0.40`, `IECC U-0.65, SHGC=0.40`, `IECC U-0.65, SHGC=0.30`, `IECC U-0.50, SHGC=0.30`, `IECC U-0.50, SHGC=0.25`, `IECC U-0.40, SHGC=0.40`, `IECC U-0.40, SHGC=0.25`, `IECC U-0.35, SHGC=0.40`, `IECC U-0.35, SHGC=0.30`, `IECC U-0.35, SHGC=0.25`, `IECC U-0.32, SHGC=0.25`, `IECC U-0.30, SHGC=0.25`, `Detailed Example: Single, Clear, Aluminum w/ Thermal Break`, `Detailed Example: Double, Low-E, Wood, Argon, Insulated Spacer`

<br/>

**Enclosure: Window Front Area or WWR**

The amount of window area on the unit's front facade. Enter a fraction to specify a Window-to-Wall Ratio instead. If the front wall is adiabatic, the value will be ignored.

- **Name:** ``enclosure_window_area_or_wwr_front``
- **Type:** ``Double``

- **Units:** ``ft2 or frac``

- **Required:** ``true``

<br/>

**Enclosure: Window Back Area or WWR**

The amount of window area on the unit's back facade. Enter a fraction to specify a Window-to-Wall Ratio instead. If the back wall is adiabatic, the value will be ignored.

- **Name:** ``enclosure_window_area_or_wwr_back``
- **Type:** ``Double``

- **Units:** ``ft2 or frac``

- **Required:** ``true``

<br/>

**Enclosure: Window Left Area or WWR**

The amount of window area on the unit's left facade (when viewed from the front). Enter a fraction to specify a Window-to-Wall Ratio instead. If the left wall is adiabatic, the value will be ignored.

- **Name:** ``enclosure_window_area_or_wwr_left``
- **Type:** ``Double``

- **Units:** ``ft2 or frac``

- **Required:** ``true``

<br/>

**Enclosure: Window Right Area or WWR**

The amount of window area on the unit's right facade (when viewed from the front). Enter a fraction to specify a Window-to-Wall Ratio instead. If the right wall is adiabatic, the value will be ignored.

- **Name:** ``enclosure_window_area_or_wwr_right``
- **Type:** ``Double``

- **Units:** ``ft2 or frac``

- **Required:** ``true``

<br/>

**Enclosure: Window Natural Ventilation**

The amount of natural ventilation from occupants opening operable windows when outdoor conditions are favorable.

- **Name:** ``enclosure_window_natural_ventilation``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `33% Operable Windows`, `50% Operable Windows`, `67% Operable Windows`, `100% Operable Windows`, `Detailed Example: 67% Operable Windows, 7 Days/Week`

<br/>

**Enclosure: Window Interior Shading**

The type of window interior shading. If shading coefficients are selected, note they indicate the reduction in solar gain (e.g., 0.7 indicates 30% reduction). If not provided, the OS-HPXML default is used.

- **Name:** ``enclosure_window_interior_shading``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Curtains, Light`, `Curtains, Medium`, `Curtains, Dark`, `Shades, Light`, `Shades, Medium`, `Shades, Dark`, `Blinds, Light`, `Blinds, Medium`, `Blinds, Dark`, `Summer=0.5, Winter=0.5`, `Summer=0.5, Winter=0.6`, `Summer=0.5, Winter=0.7`, `Summer=0.5, Winter=0.8`, `Summer=0.5, Winter=0.9`, `Summer=0.6, Winter=0.6`, `Summer=0.6, Winter=0.7`, `Summer=0.6, Winter=0.8`, `Summer=0.6, Winter=0.9`, `Summer=0.7, Winter=0.7`, `Summer=0.7, Winter=0.8`, `Summer=0.7, Winter=0.9`, `Summer=0.8, Winter=0.8`, `Summer=0.8, Winter=0.9`, `Summer=0.9, Winter=0.9`

<br/>

**Enclosure: Window Exterior Shading**

The type of window exterior shading. If shading coefficients are selected, note they indicate the reduction in solar gain (e.g., 0.7 indicates 30% reduction). If not provided, the OS-HPXML default is used.

- **Name:** ``enclosure_window_exterior_shading``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Solar Film`, `Solar Screen`, `Summer=0.25, Winter=0.25`, `Summer=0.25, Winter=0.50`, `Summer=0.25, Winter=0.75`, `Summer=0.25, Winter=1.00`, `Summer=0.50, Winter=0.25`, `Summer=0.50, Winter=0.50`, `Summer=0.50, Winter=0.75`, `Summer=0.50, Winter=1.00`, `Summer=0.75, Winter=0.25`, `Summer=0.75, Winter=0.50`, `Summer=0.75, Winter=0.75`, `Summer=0.75, Winter=1.00`, `Summer=1.00, Winter=0.25`, `Summer=1.00, Winter=0.50`, `Summer=1.00, Winter=0.75`, `Summer=1.00, Winter=1.00`

<br/>

**Enclosure: Window Insect Screens**

The type of window insect screens, if present. If not provided, assumes there are no insect screens.

- **Name:** ``enclosure_window_insect_screens``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `none`, `exterior`, `interior`

<br/>

**Enclosure: Window Storms**

The type of window storm, if present. If not provided, assumes there is no storm.

- **Name:** ``enclosure_window_storm_type``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `clear`, `low-e`

<br/>

**Enclosure: Window Overhangs**

The type of window overhangs.

- **Name:** ``enclosure_overhangs``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `1ft, All Windows`, `2ft, All Windows`, `3ft, All Windows`, `4ft, All Windows`, `5ft, All Windows`, `10ft, All Windows`, `1ft, Front Windows`, `2ft, Front Windows`, `3ft, Front Windows`, `4ft, Front Windows`, `5ft, Front Windows`, `10ft, Front Windows`, `1ft, Back Windows`, `2ft, Back Windows`, `3ft, Back Windows`, `4ft, Back Windows`, `5ft, Back Windows`, `10ft, Back Windows`, `1ft, Left Windows`, `2ft, Left Windows`, `3ft, Left Windows`, `4ft, Left Windows`, `5ft, Left Windows`, `10ft, Left Windows`, `1ft, Right Windows`, `2ft, Right Windows`, `3ft, Right Windows`, `4ft, Right Windows`, `5ft, Right Windows`, `10ft, Right Windows`, `Detailed Example: 1.5ft, Back/Left/Right Windows, 2ft Offset, 4ft Window Height`, `Detailed Example: 2.5ft, Front Windows, 1ft Offset, 5ft Window Height`

<br/>

**Enclosure: Skylights**

The type of skylights.

- **Name:** ``enclosure_skylight``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Single, Clear, Metal`, `Single, Clear, Non-Metal`, `Double, Clear, Metal`, `Double, Clear, Non-Metal`, `Double, Low-E, Metal, High Gain`, `Double, Low-E, Non-Metal, High Gain`, `Double, Low-E, Metal, Med Gain`, `Double, Low-E, Non-Metal, Med Gain`, `Double, Low-E, Metal, Low Gain`, `Double, Low-E, Non-Metal, Low Gain`, `Triple, Clear, Metal`, `Triple, Clear, Non-Metal`, `IECC U-0.75, SHGC=0.40`, `IECC U-0.75, SHGC=0.30`, `IECC U-0.75, SHGC=0.25`, `IECC U-0.65, SHGC=0.40`, `IECC U-0.65, SHGC=0.30`, `IECC U-0.65, SHGC=0.25`, `IECC U-0.60, SHGC=0.40`, `IECC U-0.60, SHGC=0.30`, `IECC U-0.55, SHGC=0.40`, `IECC U-0.55, SHGC=0.25`

<br/>

**Enclosure: Skylight Front Area**

The amount of skylight area on the unit's front conditioned roof.

- **Name:** ``enclosure_skylight_area_front``
- **Type:** ``Double``

- **Units:** ``ft2``

- **Required:** ``false``

<br/>

**Enclosure: Skylight Back Area**

The amount of skylight area on the unit's back conditioned roof.

- **Name:** ``enclosure_skylight_area_back``
- **Type:** ``Double``

- **Units:** ``ft2``

- **Required:** ``false``

<br/>

**Enclosure: Skylight Left Area**

The amount of skylight area on the unit's left conditioned roof (when viewed from the front).

- **Name:** ``enclosure_skylight_area_left``
- **Type:** ``Double``

- **Units:** ``ft2``

- **Required:** ``false``

<br/>

**Enclosure: Skylight Right Area**

The amount of skylight area on the unit's right conditioned roof (when viewed from the front).

- **Name:** ``enclosure_skylight_area_right``
- **Type:** ``Double``

- **Units:** ``ft2``

- **Required:** ``false``

<br/>

**Enclosure: Doors**

The type of doors.

- **Name:** ``enclosure_door``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Solid Wood, R-2`, `Solid Wood, R-3`, `Insulated Fiberglass/Steel, R-4`, `Insulated Fiberglass/Steel, R-5`, `Insulated Fiberglass/Steel, R-6`, `Insulated Fiberglass/Steel, R-7`, `IECC U-1.20`, `IECC U-0.75`, `IECC U-0.65`, `IECC U-0.50`, `IECC U-0.40`, `IECC U-0.35`, `IECC U-0.32`, `IECC U-0.30`, `Detailed Example: Solid Wood, R-3.04`, `Detailed Example: Insulated Fiberglass/Steel, R-4.4`

<br/>

**Enclosure: Doors Area**

The area of the opaque door(s).

- **Name:** ``enclosure_door_area``
- **Type:** ``Double``

- **Units:** ``ft2``

- **Required:** ``true``

<br/>

**Enclosure: Air Leakage**

The amount of air leakage. When a leakiness description is used, the Year Built of the home is also required.

- **Name:** ``enclosure_air_leakage``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Very Tight`, `Tight`, `Average`, `Leaky`, `Very Leaky`, `0.25 ACH50`, `0.5 ACH50`, `0.75 ACH50`, `1 ACH50`, `1.5 ACH50`, `2 ACH50`, `2.25 ACH50`, `3 ACH50`, `3.75 ACH50`, `4 ACH50`, `4.5 ACH50`, `5 ACH50`, `5.25 ACH50`, `6 ACH50`, `7 ACH50`, `7.5 ACH50`, `8 ACH50`, `10 ACH50`, `11.25 ACH50`, `15 ACH50`, `18.5 ACH50`, `20 ACH50`, `25 ACH50`, `30 ACH50`, `40 ACH50`, `50 ACH50`, `2.8 ACH45`, `0.2 nACH`, `0.335 nACH`, `0.67 nACH`, `1.5 nACH`, `Detailed Example: 3.57 ACH50`, `Detailed Example: 12.16 ACH50`, `Detailed Example: 0.375 nACH`, `Detailed Example: 72 nCFM`, `Detailed Example: 79.8 sq. in. ELA`, `Detailed Example: 123 sq. in. ELA`, `Detailed Example: 1080 CFM50`, `Detailed Example: 1010 CFM45`

<br/>

**Enclosure: Air Leakage Type**

Type of air leakage if providing a numeric air leakage value. If 'unit total', represents the total infiltration to the unit as measured by a compartmentalization test, in which case the air leakage value will be adjusted by the ratio of exterior envelope surface area to total envelope surface area. Otherwise, if 'unit exterior only', represents the infiltration to the unit from outside only as measured by a guarded test. Required when unit type is single-family attached or apartment unit.

- **Name:** ``enclosure_air_leakage_type``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `unit total`, `unit exterior only`

<br/>

**Enclosure: Has Flue or Chimney in Conditioned Space**

Presence of flue or chimney with combustion air from conditioned space; used for infiltration model. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#flue-or-chimney'>Flue or Chimney</a>) is used.

- **Name:** ``enclosure_has_flue_or_chimney_in_conditioned_space``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**HVAC: Heating System**

The type and efficiency of the heating system. Use 'None' if there is no heating system or if there is a heat pump serving a heating load.

- **Name:** ``hvac_heating_system``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Electric Resistance`, `Central Furnace, 60% AFUE`, `Central Furnace, 64% AFUE`, `Central Furnace, 68% AFUE`, `Central Furnace, 72% AFUE`, `Central Furnace, 76% AFUE`, `Central Furnace, 78% AFUE`, `Central Furnace, 80% AFUE`, `Central Furnace, 85% AFUE`, `Central Furnace, 90% AFUE`, `Central Furnace, 92% AFUE`, `Central Furnace, 92.5% AFUE`, `Central Furnace, 96% AFUE`, `Central Furnace, 98% AFUE`, `Central Furnace, 100% AFUE`, `Wall Furnace, 60% AFUE`, `Wall Furnace, 68% AFUE`, `Wall Furnace, 82% AFUE`, `Wall Furnace, 98% AFUE`, `Wall Furnace, 100% AFUE`, `Floor Furnace, 60% AFUE`, `Floor Furnace, 70% AFUE`, `Floor Furnace, 80% AFUE`, `Boiler, 60% AFUE`, `Boiler, 72% AFUE`, `Boiler, 76% AFUE`, `Boiler, 80% AFUE`, `Boiler, 82% AFUE`, `Boiler, 85% AFUE`, `Boiler, 90% AFUE`, `Boiler, 92% AFUE`, `Boiler, 92.5% AFUE`, `Boiler, 95% AFUE`, `Boiler, 96% AFUE`, `Boiler, 98% AFUE`, `Boiler, 100% AFUE`, `Shared Boiler w/ Baseboard, 78% AFUE`, `Shared Boiler w/ Baseboard, 92% AFUE`, `Shared Boiler w/ Baseboard, 100% AFUE`, `Shared Boiler w/ Fan Coil, 78% AFUE`, `Shared Boiler w/ Fan Coil, 92% AFUE`, `Shared Boiler w/ Fan Coil, 100% AFUE`, `Stove, 60% Efficiency`, `Stove, 70% Efficiency`, `Stove, 80% Efficiency`, `Space Heater, 60% Efficiency`, `Space Heater, 70% Efficiency`, `Space Heater, 80% Efficiency`, `Space Heater, 92% Efficiency`, `Space Heater, 100% Efficiency`, `Fireplace, 60% Efficiency`, `Fireplace, 70% Efficiency`, `Fireplace, 80% Efficiency`, `Fireplace, 100% Efficiency`, `Detailed Example: Central Furnace, 92% AFUE, 600 Btu/hr Pilot Light`, `Detailed Example: Floor Furnace, 80% AFUE, 600 Btu/hr Pilot Light`, `Detailed Example: Boiler, 92% AFUE, 600 Btu/hr Pilot Light`

<br/>

**HVAC: Heating System Fuel Type**

The fuel type of the heating system. Ignored for ElectricResistance.

- **Name:** ``hvac_heating_system_fuel``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `electricity`, `natural gas`, `fuel oil`, `propane`, `wood`, `wood pellets`, `coal`

<br/>

**HVAC: Heating System Capacity**

The output capacity of the heating system.

- **Name:** ``hvac_heating_system_capacity``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Autosize`, `5 kBtu/hr`, `10 kBtu/hr`, `15 kBtu/hr`, `20 kBtu/hr`, `25 kBtu/hr`, `30 kBtu/hr`, `35 kBtu/hr`, `40 kBtu/hr`, `45 kBtu/hr`, `50 kBtu/hr`, `55 kBtu/hr`, `60 kBtu/hr`, `65 kBtu/hr`, `70 kBtu/hr`, `75 kBtu/hr`, `80 kBtu/hr`, `85 kBtu/hr`, `90 kBtu/hr`, `95 kBtu/hr`, `100 kBtu/hr`, `105 kBtu/hr`, `110 kBtu/hr`, `115 kBtu/hr`, `120 kBtu/hr`, `125 kBtu/hr`, `130 kBtu/hr`, `135 kBtu/hr`, `140 kBtu/hr`, `145 kBtu/hr`, `150 kBtu/hr`, `Detailed Example: Autosize, 140% Multiplier`, `Detailed Example: Autosize, 170% Multiplier`, `Detailed Example: Autosize, 140% Multiplier, 45 kBtu/hr Limit`

<br/>

**HVAC: Heating System Fraction Heat Load Served**

The heating load served by the heating system.

- **Name:** ``hvac_heating_system_fraction_heat_load_served``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**HVAC: Cooling System**

The type and efficiency of the cooling system. Use 'None' if there is no cooling system or if there is a heat pump serving a cooling load.

- **Name:** ``hvac_cooling_system``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Central AC, SEER 8`, `Central AC, SEER 10`, `Central AC, SEER 13`, `Central AC, SEER 14`, `Central AC, SEER 15`, `Central AC, SEER 16`, `Central AC, SEER 17`, `Central AC, SEER 18`, `Central AC, SEER 21`, `Central AC, SEER 24`, `Central AC, SEER 24.5`, `Central AC, SEER 27`, `Central AC, SEER2 12.4`, `Mini-Split AC, SEER 13`, `Mini-Split AC, SEER 17`, `Mini-Split AC, SEER 19`, `Mini-Split AC, SEER 19, Ducted`, `Mini-Split AC, SEER 24`, `Mini-Split AC, SEER 25`, `Mini-Split AC, SEER 29.3`, `Mini-Split AC, SEER 33`, `Room AC, EER 8.5`, `Room AC, EER 8.5, Electric Resistance Heating`, `Room AC, EER 9.8`, `Room AC, EER 10.7`, `Room AC, EER 12.0`, `Room AC, CEER 8.4`, `Packaged Terminal AC, EER 10.7`, `Packaged Terminal AC, EER 10.7, Electric Resistance Heating`, `Packaged Terminal AC, EER 10.7, 80% AFUE Gas Heating`, `Evaporative Cooler`, `Evaporative Cooler, Ducted`, `Detailed Example: Central AC, SEER 13, Absolute Detailed Performance`, `Detailed Example: Central AC, SEER 18, Absolute Detailed Performance`, `Detailed Example: Central AC, SEER 17.5, Absolute Detailed Performance`, `Detailed Example: Central AC, SEER 17.5, Normalized Detailed Performance`, `Detailed Example: Mini-Split AC, SEER 17, Absolute Detailed Performance`, `Detailed Example: Mini-Split AC, SEER 17, Normalized Detailed Performance`

<br/>

**HVAC: Cooling System Capacity**

The output capacity of the cooling system.

- **Name:** ``hvac_cooling_system_capacity``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Autosize`, `0.5 tons`, `0.75 tons`, `1.0 tons`, `1.5 tons`, `2.0 tons`, `2.5 tons`, `3.0 tons`, `3.5 tons`, `4.0 tons`, `4.5 tons`, `5.0 tons`, `5.5 tons`, `6.0 tons`, `6.5 tons`, `7.0 tons`, `7.5 tons`, `8.0 tons`, `8.5 tons`, `9.0 tons`, `9.5 tons`, `10.0 tons`, `Detailed Example: Autosize, 140% Multiplier`, `Detailed Example: Autosize, 170% Multiplier`, `Detailed Example: Autosize, 170% Multiplier, 3.0 tons Limit`

<br/>

**HVAC: Cooling System Fraction Cool Load Served**

The cooling load served by the cooling system.

- **Name:** ``hvac_cooling_system_fraction_cool_load_served``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**HVAC: Cooling System Integrated Heating Capacity**

The output capacity of the cooling system's integrated heating system. Only used for packaged terminal air conditioner and room air conditioner systems with integrated heating.

- **Name:** ``hvac_cooling_system_integrated_heating_capacity``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Autosize`, `5 kBtu/hr`, `10 kBtu/hr`, `15 kBtu/hr`, `20 kBtu/hr`, `25 kBtu/hr`, `30 kBtu/hr`, `35 kBtu/hr`, `40 kBtu/hr`, `45 kBtu/hr`, `50 kBtu/hr`, `55 kBtu/hr`, `60 kBtu/hr`, `65 kBtu/hr`, `70 kBtu/hr`, `75 kBtu/hr`, `80 kBtu/hr`, `85 kBtu/hr`, `90 kBtu/hr`, `95 kBtu/hr`, `100 kBtu/hr`, `105 kBtu/hr`, `110 kBtu/hr`, `115 kBtu/hr`, `120 kBtu/hr`, `125 kBtu/hr`, `130 kBtu/hr`, `135 kBtu/hr`, `140 kBtu/hr`, `145 kBtu/hr`, `150 kBtu/hr`

<br/>

**HVAC: Cooling System Integrated Heating Fraction Heat Load Served**

The heating load served by the heating system integrated into cooling system. Only used for packaged terminal air conditioner and room air conditioner systems with integrated heating.

- **Name:** ``hvac_cooling_system_integrated_heating_fraction_heat_load_served``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``false``

<br/>

**HVAC: Heat Pump**

The type and efficiency of the heat pump.

- **Name:** ``hvac_heat_pump``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Central HP, SEER 8, 6.0 HSPF`, `Central HP, SEER 10, 6.2 HSPF`, `Central HP, SEER 10, 6.8 HSPF`, `Central HP, SEER 10.3, 7.0 HSPF`, `Central HP, SEER 11.5, 7.5 HSPF`, `Central HP, SEER 13, 7.7 HSPF`, `Central HP, SEER 13, 8.0 HSPF`, `Central HP, SEER 13, 9.85 HSPF`, `Central HP, SEER 14, 8.2 HSPF`, `Central HP, SEER 14.3, 8.5 HSPF`, `Central HP, SEER 15, 8.5 HSPF`, `Central HP, SEER 15, 9.0 HSPF`, `Central HP, SEER 16, 9.0 HSPF`, `Central HP, SEER 17, 8.7 HSPF`, `Central HP, SEER 18, 9.3 HSPF`, `Central HP, SEER 20, 11 HSPF`, `Central HP, SEER 22, 10 HSPF`, `Central HP, SEER 24, 13 HSPF`, `Mini-Split HP, SEER 14.5, 8.2 HSPF`, `Mini-Split HP, SEER 14.5, 8.2 HSPF, Ducted`, `Mini-Split HP, SEER 16, 9.2 HSPF`, `Mini-Split HP, SEER 17, 9.5 HSPF`, `Mini-Split HP, SEER 17, 9.5 HSPF, Ducted`, `Mini-Split HP, SEER 18.0, 9.6 HSPF`, `Mini-Split HP, SEER 18.0, 9.6 HSPF, Ducted`, `Mini-Split HP, SEER 19, 10 HSPF, Ducted`, `Mini-Split HP, SEER 19, 10 HSPF`, `Mini-Split HP, SEER 20, 11 HSPF`, `Mini-Split HP, SEER 24, 13 HSPF`, `Mini-Split HP, SEER 25, 12.7 HSPF`, `Mini-Split HP, SEER 25, 12.7 HSPF, Ducted`, `Mini-Split HP, SEER 29.3, 14 HSPF`, `Mini-Split HP, SEER 29.3, 14 HSPF, Ducted`, `Mini-Split HP, SEER 33, 13.3 HSPF`, `Mini-Split HP, SEER 33, 13.3 HSPF, Ducted`, `Geothermal HP, EER 16.6, COP 3.6`, `Geothermal HP, EER 18.2, COP 3.7`, `Geothermal HP, EER 19.4, COP 3.8`, `Geothermal HP, EER 20.2, COP 4.2`, `Geothermal HP, EER 20.5, COP 4.0`, `Geothermal HP, EER 30.9, COP 4.4`, `Packaged Terminal HP, EER 11.4, COP 3.6`, `Room AC w/ Reverse Cycle, EER 11.4, COP 3.6`, `Detailed Example: Central HP, SEER2 12.4, HSPF2 6.5`, `Detailed Example: Central HP, SEER 13, 7.7 HSPF, Absolute Detailed Performance`, `Detailed Example: Central HP, SEER 18, 9.3 HSPF, Absolute Detailed Performance`, `Detailed Example: Central HP, SEER 17.5, 9.5 HSPF, Absolute Detailed Performance`, `Detailed Example: Central HP, SEER 17.5, 9.5 HSPF, Normalized Detailed Performance`, `Detailed Example: Mini-Split HP, SEER 16.7, 11.3 HSPF, Absolute Detailed Performance`, `Detailed Example: Mini-Split HP, SEER 16.7, 11.3 HSPF, Normalized Detailed Performance`, `Detailed Example: Mini-Split HP, SEER 17, 10 HSPF, Absolute Detailed Performance`, `Detailed Example: Mini-Split HP, SEER 17, 10 HSPF, Normalized Detailed Performance`

<br/>

**HVAC: Heat Pump Capacity**

The output capacity of the heat pump.

- **Name:** ``hvac_heat_pump_capacity``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Autosize`, `0.5 tons`, `0.75 tons`, `1.0 tons`, `1.5 tons`, `2.0 tons`, `2.5 tons`, `3.0 tons`, `3.5 tons`, `4.0 tons`, `4.5 tons`, `5.0 tons`, `5.5 tons`, `6.0 tons`, `6.5 tons`, `7.0 tons`, `7.5 tons`, `8.0 tons`, `8.5 tons`, `9.0 tons`, `9.5 tons`, `10.0 tons`, `Detailed Example: Autosize, 140% Multiplier`, `Detailed Example: Autosize, 170% Multiplier`, `Detailed Example: Autosize, 170% Multiplier, 3.0 tons Limit`

<br/>

**HVAC: Heat Pump Sizing Methodology**

The auto-sizing methodology to use when the heat pump capacity is not provided. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-hvac-sizing-control'>HPXML HVAC Sizing Control</a>) is used.

- **Name:** ``heat_pump_sizing_methodology``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `ACCA`, `HERS`, `MaxLoad`

<br/>

**HVAC: Heat Pump Fraction Heat Load Served**

The heating load served by the heat pump.

- **Name:** ``hvac_heat_pump_fraction_heat_load_served``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**HVAC: Heat Pump Fraction Cool Load Served**

The cooling load served by the heat pump.

- **Name:** ``hvac_heat_pump_fraction_cool_load_served``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**HVAC: Heat Pump Temperatures**

Specifies the minimum compressor temperature and/or maximum HP backup temperature. If both are the same, a binary switchover temperature is used.

- **Name:** ``hvac_heat_pump_temperatures``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Default`, `-20F Min Compressor Temp`, `-15F Min Compressor Temp`, `-10F Min Compressor Temp`, `-5F Min Compressor Temp`, `0F Min Compressor Temp`, `5F Min Compressor Temp`, `10F Min Compressor Temp`, `15F Min Compressor Temp`, `20F Min Compressor Temp`, `25F Min Compressor Temp`, `30F Min Compressor Temp`, `35F Min Compressor Temp`, `40F Min Compressor Temp`, `30F Min Compressor Temp, 30F Max HP Backup Temp`, `35F Min Compressor Temp, 35F Max HP Backup Temp`, `40F Min Compressor Temp, 40F Max HP Backup Temp`, `Detailed Example: 5F Min Compressor Temp, 35F Max HP Backup Temp`, `Detailed Example: 25F Min Compressor Temp, 45F Max HP Backup Temp`

<br/>

**HVAC: Heat Pump Backup Type**

The type and efficiency of the heat pump backup. Use 'None' if there is no backup heating. If Backup Type is Separate Heating System, Heating System 2 is used to specify the backup.

- **Name:** ``hvac_heat_pump_backup``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Integrated, Electricity, 100% Efficiency`, `Integrated, Natural Gas, 60% AFUE`, `Integrated, Natural Gas, 76% AFUE`, `Integrated, Natural Gas, 80% AFUE`, `Integrated, Natural Gas, 92.5% AFUE`, `Integrated, Natural Gas, 95% AFUE`, `Integrated, Fuel Oil, 60% AFUE`, `Integrated, Fuel Oil, 76% AFUE`, `Integrated, Fuel Oil, 80% AFUE`, `Integrated, Fuel Oil, 92.5% AFUE`, `Integrated, Fuel Oil, 95% AFUE`, `Integrated, Propane, 60% AFUE`, `Integrated, Propane, 76% AFUE`, `Integrated, Propane, 80% AFUE`, `Integrated, Propane, 92.5% AFUE`, `Integrated, Propane, 95% AFUE`, `Separate Heating System`

<br/>

**HVAC: Heat Pump Backup Capacity**

The output capacity of the heat pump backup if there is integrated backup heating.

- **Name:** ``hvac_heat_pump_backup_capacity``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Autosize`, `5 kW`, `10 kW`, `15 kW`, `20 kW`, `25 kW`, `5 kBtu/hr`, `10 kBtu/hr`, `15 kBtu/hr`, `20 kBtu/hr`, `25 kBtu/hr`, `30 kBtu/hr`, `35 kBtu/hr`, `40 kBtu/hr`, `45 kBtu/hr`, `50 kBtu/hr`, `55 kBtu/hr`, `60 kBtu/hr`, `65 kBtu/hr`, `70 kBtu/hr`, `75 kBtu/hr`, `80 kBtu/hr`, `85 kBtu/hr`, `90 kBtu/hr`, `95 kBtu/hr`, `100 kBtu/hr`, `105 kBtu/hr`, `110 kBtu/hr`, `115 kBtu/hr`, `120 kBtu/hr`, `125 kBtu/hr`, `130 kBtu/hr`, `135 kBtu/hr`, `140 kBtu/hr`, `145 kBtu/hr`, `150 kBtu/hr`, `Detailed Example: Autosize, 140% Multiplier`, `Detailed Example: Autosize, 170% Multiplier`, `Detailed Example: Autosize, 90% Multiplier, 45 kBtu/hr Limit`

<br/>

**HVAC: Heat Pump Backup Sizing Methodology**

The auto-sizing methodology to use when the heat pump backup capacity is not provided. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-hvac-sizing-control'>HPXML HVAC Sizing Control</a>) is used.

- **Name:** ``heat_pump_backup_sizing_methodology``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `emergency`, `supplemental`

<br/>

**HVAC: Geothermal Loop**

The geothermal loop configuration if there's a ground-to-air heat pump.

- **Name:** ``hvac_geothermal_loop``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Default`, `Vertical Loop, Enhanced Grout`, `Vertical Loop, Enhanced Pipe`, `Detailed Example: Lopsided U Configuration, 10 Boreholes`

<br/>

**HVAC: Heating System 2**

The type and efficiency of the second heating system. If a heat pump is specified and the backup type is 'separate', this heating system represents the 'separate' backup heating.

- **Name:** ``hvac_heating_system_2``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Electric Resistance`, `Central Furnace, 60% AFUE`, `Central Furnace, 64% AFUE`, `Central Furnace, 68% AFUE`, `Central Furnace, 72% AFUE`, `Central Furnace, 76% AFUE`, `Central Furnace, 78% AFUE`, `Central Furnace, 80% AFUE`, `Central Furnace, 85% AFUE`, `Central Furnace, 90% AFUE`, `Central Furnace, 92% AFUE`, `Central Furnace, 92.5% AFUE`, `Central Furnace, 96% AFUE`, `Central Furnace, 98% AFUE`, `Central Furnace, 100% AFUE`, `Wall Furnace, 60% AFUE`, `Wall Furnace, 68% AFUE`, `Wall Furnace, 82% AFUE`, `Wall Furnace, 98% AFUE`, `Wall Furnace, 100% AFUE`, `Floor Furnace, 60% AFUE`, `Floor Furnace, 70% AFUE`, `Floor Furnace, 80% AFUE`, `Boiler, 60% AFUE`, `Boiler, 72% AFUE`, `Boiler, 76% AFUE`, `Boiler, 80% AFUE`, `Boiler, 82% AFUE`, `Boiler, 85% AFUE`, `Boiler, 90% AFUE`, `Boiler, 92% AFUE`, `Boiler, 92.5% AFUE`, `Boiler, 95% AFUE`, `Boiler, 96% AFUE`, `Boiler, 98% AFUE`, `Boiler, 100% AFUE`, `Shared Boiler w/ Baseboard, 78% AFUE`, `Shared Boiler w/ Baseboard, 92% AFUE`, `Shared Boiler w/ Baseboard, 100% AFUE`, `Shared Boiler w/ Fan Coil, 78% AFUE`, `Shared Boiler w/ Fan Coil, 92% AFUE`, `Shared Boiler w/ Fan Coil, 100% AFUE`, `Stove, 60% Efficiency`, `Stove, 70% Efficiency`, `Stove, 80% Efficiency`, `Space Heater, 60% Efficiency`, `Space Heater, 70% Efficiency`, `Space Heater, 80% Efficiency`, `Space Heater, 92% Efficiency`, `Space Heater, 100% Efficiency`, `Fireplace, 60% Efficiency`, `Fireplace, 70% Efficiency`, `Fireplace, 80% Efficiency`, `Fireplace, 100% Efficiency`, `Detailed Example: Central Furnace, 92% AFUE, 600 Btu/hr Pilot Light`, `Detailed Example: Floor Furnace, 80% AFUE, 600 Btu/hr Pilot Light`, `Detailed Example: Boiler, 92% AFUE, 600 Btu/hr Pilot Light`

<br/>

**HVAC: Heating System 2 Fuel Type**

The fuel type of the second heating system. Ignored for ElectricResistance.

- **Name:** ``hvac_heating_system_2_fuel``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `electricity`, `natural gas`, `fuel oil`, `propane`, `wood`, `wood pellets`, `coal`

<br/>

**HVAC: Heating System 2 Capacity**

The output capacity of the second heating system.

- **Name:** ``hvac_heating_system_2_capacity``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Autosize`, `5 kBtu/hr`, `10 kBtu/hr`, `15 kBtu/hr`, `20 kBtu/hr`, `25 kBtu/hr`, `30 kBtu/hr`, `35 kBtu/hr`, `40 kBtu/hr`, `45 kBtu/hr`, `50 kBtu/hr`, `55 kBtu/hr`, `60 kBtu/hr`, `65 kBtu/hr`, `70 kBtu/hr`, `75 kBtu/hr`, `80 kBtu/hr`, `85 kBtu/hr`, `90 kBtu/hr`, `95 kBtu/hr`, `100 kBtu/hr`, `105 kBtu/hr`, `110 kBtu/hr`, `115 kBtu/hr`, `120 kBtu/hr`, `125 kBtu/hr`, `130 kBtu/hr`, `135 kBtu/hr`, `140 kBtu/hr`, `145 kBtu/hr`, `150 kBtu/hr`, `Detailed Example: Autosize, 140% Multiplier`, `Detailed Example: Autosize, 170% Multiplier`, `Detailed Example: Autosize, 90% Multiplier, 45 kBtu/hr Limit`

<br/>

**HVAC: Heating System 2 Fraction Heat Load Served**

The heat load served fraction of the second heating system. Ignored if this heating system serves as a backup system for a heat pump.

- **Name:** ``hvac_heating_system_2_fraction_heat_load_served``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**HVAC Control: Heating Weekday Setpoint Schedule**

Specify the constant or 24-hour comma-separated weekday heating setpoint schedule. Required unless a detailed CSV schedule is provided.

- **Name:** ``hvac_control_heating_weekday_setpoint``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**HVAC Control: Heating Weekend Setpoint Schedule**

Specify the constant or 24-hour comma-separated weekend heating setpoint schedule. Required unless a detailed CSV schedule is provided.

- **Name:** ``hvac_control_heating_weekend_setpoint``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**HVAC Control: Cooling Weekday Setpoint Schedule**

Specify the constant or 24-hour comma-separated weekday cooling setpoint schedule. Required unless a detailed CSV schedule is provided.

- **Name:** ``hvac_control_cooling_weekday_setpoint``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**HVAC Control: Cooling Weekend Setpoint Schedule**

Specify the constant or 24-hour comma-separated weekend cooling setpoint schedule. Required unless a detailed CSV schedule is provided.

- **Name:** ``hvac_control_cooling_weekend_setpoint``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**HVAC Control: Heating Season Period**

Enter a date range like 'Nov 1 - Jun 30'. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-hvac-control'>HPXML HVAC Control</a>) is used. Can also provide 'BuildingAmerica' to use automatic seasons from the Building America House Simulation Protocols.

- **Name:** ``hvac_control_heating_season_period``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**HVAC Control: Cooling Season Period**

Enter a date range like 'Jun 1 - Oct 31'. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-hvac-control'>HPXML HVAC Control</a>) is used. Can also provide 'BuildingAmerica' to use automatic seasons from the Building America House Simulation Protocols.

- **Name:** ``hvac_control_cooling_season_period``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**HVAC Blower: Fan Efficiency**

The blower fan efficiency at maximum fan speed. Applies only to split (not packaged) systems (i.e., applies to ducted systems as well as ductless mini-split systems). If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-heating-systems'>HPXML Heating Systems</a>, <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-cooling-systems'>HPXML Cooling Systems</a>, <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-heat-pumps'>HPXML Heat Pumps</a>) is used.

- **Name:** ``hvac_blower_fan_watts_per_cfm``
- **Type:** ``Double``

- **Units:** ``W/CFM``

- **Required:** ``false``

<br/>

**HVAC Installation Defects**

Specifies whether the HVAC system has airflow and/or refrigerant charge installation defects. Applies to central furnaces and central/mini-split ACs and HPs.

- **Name:** ``hvac_installation_defects``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `35% Airflow Defect`, `25% Airflow Defect`, `15% Airflow Defect`, `35% Under Charge`, `25% Under Charge`, `15% Under Charge`, `15% Over Charge`, `25% Over Charge`, `35% Over Charge`, `35% Airflow Defect, 35% Under Charge`, `35% Airflow Defect, 25% Under Charge`, `35% Airflow Defect, 15% Under Charge`, `35% Airflow Defect, 15% Over Charge`, `35% Airflow Defect, 25% Over Charge`, `35% Airflow Defect, 35% Over Charge`, `25% Airflow Defect, 35% Under Charge`, `25% Airflow Defect, 25% Under Charge`, `25% Airflow Defect, 15% Under Charge`, `25% Airflow Defect, 15% Over Charge`, `25% Airflow Defect, 25% Over Charge`, `25% Airflow Defect, 35% Over Charge`, `15% Airflow Defect, 35% Under Charge`, `15% Airflow Defect, 25% Under Charge`, `15% Airflow Defect, 15% Under Charge`, `15% Airflow Defect, 15% Over Charge`, `15% Airflow Defect, 25% Over Charge`, `15% Airflow Defect, 35% Over Charge`

<br/>

**HVAC Ducts**

The supply duct leakage to outside, nominal insulation r-value, buried insulation level, surface area, and fraction rectangular.

- **Name:** ``hvac_ducts``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `0% Leakage, Uninsulated`, `0% Leakage, R-4`, `0% Leakage, R-6`, `0% Leakage, R-8`, `5% Leakage, Uninsulated`, `5% Leakage, R-4`, `5% Leakage, R-6`, `5% Leakage, R-8`, `10% Leakage, Uninsulated`, `10% Leakage, R-4`, `10% Leakage, R-6`, `10% Leakage, R-8`, `15% Leakage, Uninsulated`, `15% Leakage, R-4`, `15% Leakage, R-6`, `15% Leakage, R-8`, `20% Leakage, Uninsulated`, `20% Leakage, R-4`, `20% Leakage, R-6`, `20% Leakage, R-8`, `25% Leakage, Uninsulated`, `25% Leakage, R-4`, `25% Leakage, R-6`, `25% Leakage, R-8`, `30% Leakage, Uninsulated`, `30% Leakage, R-4`, `30% Leakage, R-6`, `30% Leakage, R-8`, `35% Leakage, Uninsulated`, `35% Leakage, R-4`, `35% Leakage, R-6`, `35% Leakage, R-8`, `0 CFM25 per 100ft2, Uninsulated`, `0 CFM25 per 100ft2, R-4`, `0 CFM25 per 100ft2, R-6`, `0 CFM25 per 100ft2, R-8`, `1 CFM25 per 100ft2, Uninsulated`, `1 CFM25 per 100ft2, R-4`, `1 CFM25 per 100ft2, R-6`, `1 CFM25 per 100ft2, R-8`, `2 CFM25 per 100ft2, Uninsulated`, `2 CFM25 per 100ft2, R-4`, `2 CFM25 per 100ft2, R-6`, `2 CFM25 per 100ft2, R-8`, `4 CFM25 per 100ft2, Uninsulated`, `4 CFM25 per 100ft2, R-4`, `4 CFM25 per 100ft2, R-6`, `4 CFM25 per 100ft2, R-8`, `6 CFM25 per 100ft2, Uninsulated`, `6 CFM25 per 100ft2, R-4`, `6 CFM25 per 100ft2, R-6`, `6 CFM25 per 100ft2, R-8`, `8 CFM25 per 100ft2, Uninsulated`, `8 CFM25 per 100ft2, R-4`, `8 CFM25 per 100ft2, R-6`, `8 CFM25 per 100ft2, R-8`, `12 CFM25 per 100ft2, Uninsulated`, `12 CFM25 per 100ft2, R-4`, `12 CFM25 per 100ft2, R-6`, `12 CFM25 per 100ft2, R-8`, `Detailed Example: 4 CFM25 per 100ft2, R-4, Deeply Buried`, `Detailed Example: 4 CFM25 per 100ft2, R-4, 100% Round`, `Detailed Example: 4 CFM25 per 100ft2, R-4, 100% Rectangular`, `Detailed Example: 5 CFM50 per 100ft2, R-4`, `Detailed Example: 250 CFM25, R-6`, `Detailed Example: 400 CFM50, R-6`

<br/>

**HVAC Ducts: Supply Location**

The location of the supply ducts. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#air-distribution'>Air Distribution</a>) is used.

- **Name:** ``hvac_ducts_supply_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `crawlspace`, `crawlspace - vented`, `crawlspace - unvented`, `crawlspace - conditioned`, `attic`, `attic - vented`, `attic - unvented`, `garage`, `exterior wall`, `under slab`, `roof deck`, `outside`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`, `manufactured home belly`

<br/>

**HVAC Ducts: Supply Area Fraction**

The fraction of supply ducts surface area in the given location. Only used if Surface Area is not provided. If the fraction is less than 1, the remaining duct area is assumed to be in conditioned space. If neither Surface Area nor Area Fraction provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#air-distribution'>Air Distribution</a>) is used.

- **Name:** ``hvac_ducts_supply_surface_area_fraction``
- **Type:** ``Double``

- **Units:** ``frac``

- **Required:** ``false``

<br/>

**HVAC Ducts: Supply Leakage Fraction**

The fraction of duct leakage associated with the supply ducts; the remainder is associated with the return ducts

- **Name:** ``hvac_ducts_supply_leakage_fraction``
- **Type:** ``Double``

- **Units:** ``frac``

- **Required:** ``false``

<br/>

**HVAC Ducts: Return Location**

The location of the return ducts. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#air-distribution'>Air Distribution</a>) is used.

- **Name:** ``hvac_ducts_return_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `crawlspace`, `crawlspace - vented`, `crawlspace - unvented`, `crawlspace - conditioned`, `attic`, `attic - vented`, `attic - unvented`, `garage`, `exterior wall`, `under slab`, `roof deck`, `outside`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`, `manufactured home belly`

<br/>

**HVAC Ducts: Return Area Fraction**

The fraction of return ducts surface area in the given location. Only used if Surface Area is not provided. If the fraction is less than 1, the remaining duct area is assumed to be in conditioned space. If neither Surface Area nor Area Fraction provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#air-distribution'>Air Distribution</a>) is used.

- **Name:** ``hvac_ducts_return_surface_area_fraction``
- **Type:** ``Double``

- **Units:** ``frac``

- **Required:** ``false``

<br/>

**HVAC Ducts: Number of Return Registers**

The number of return registers of the ducts. Only used to calculate default return duct surface area. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#air-distribution'>Air Distribution</a>) is used.

- **Name:** ``hvac_ducts_number_of_return_registers``
- **Type:** ``Integer``

- **Units:** ``#``

- **Required:** ``false``

<br/>

**Ventilation Fans: Whole-Home Mechanical**

The type of whole-home mechanical ventilation system.

- **Name:** ``ventilation_fans_mechanical``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Exhaust Only`, `Supply Only`, `Balanced`, `CFIS`, `HRV, 55%`, `HRV, 60%`, `HRV, 65%`, `HRV, 70%`, `HRV, 75%`, `HRV, 80%`, `HRV, 85%`, `ERV, 55%`, `ERV, 60%`, `ERV, 65%`, `ERV, 70%`, `ERV, 75%`, `ERV, 80%`, `ERV, 85%`

<br/>

**Ventilation Fans: Kitchen**

The type of kitchen ventilation fans.

- **Name:** ``ventilation_fans_kitchen``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Default`, `100 cfm, 1 hr/day`, `100 cfm, 2 hrs/day`, `200 cfm, 1 hr/day`, `200 cfm, 2 hrs/day`, `300 cfm, 1 hr/day`, `300 cfm, 2 hrs/day`, `Detailed Example: 100 cfm, 1.5 hrs/day @ 6pm, 30 W`

<br/>

**Ventilation Fans: Bathroom**

The type of bathroom ventilation fans.

- **Name:** ``ventilation_fans_bathroom``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Default`, `50 cfm/bathroom, 1 hr/day`, `50 cfm/bathroom, 2 hrs/day`, `80 cfm/bathroom, 1 hr/day`, `80 cfm/bathroom, 2 hrs/day`, `100 cfm/bathroom, 1 hr/day`, `100 cfm/bathroom, 2 hrs/day`, `Detailed Example: 50 cfm/bathroom, 1.5 hrs/day @ 7am, 15 W`

<br/>

**Whole House Fan: Present**

Whether there is a whole house fan.

- **Name:** ``whole_house_fan_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Whole House Fan: Flow Rate**

The flow rate of the whole house fan. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-whole-house-fans'>HPXML Whole House Fans</a>) is used.

- **Name:** ``whole_house_fan_flow_rate``
- **Type:** ``Double``

- **Units:** ``CFM``

- **Required:** ``false``

<br/>

**Whole House Fan: Fan Power**

The fan power of the whole house fan. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-whole-house-fans'>HPXML Whole House Fans</a>) is used.

- **Name:** ``whole_house_fan_power``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**DHW: Water Heater**

The type and efficiency of the water heater.

- **Name:** ``dhw_water_heater``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Electricity, Tank, UEF=0.90`, `Electricity, Tank, UEF=0.92`, `Electricity, Tank, UEF=0.94`, `Electricity, Tankless, UEF=0.94`, `Electricity, Tankless, UEF=0.98`, `Electricity, Heat Pump, UEF=3.50`, `Electricity, Heat Pump, UEF=3.75`, `Electricity, Heat Pump, UEF=4.00`, `Natural Gas, Tank, UEF=0.57`, `Natural Gas, Tank, UEF=0.60`, `Natural Gas, Tank, UEF=0.64`, `Natural Gas, Tank, UEF=0.67`, `Natural Gas, Tank, UEF=0.70`, `Natural Gas, Tank, UEF=0.80`, `Natural Gas, Tankless, UEF=0.82`, `Natural Gas, Tankless, UEF=0.93`, `Natural Gas, Tankless, UEF=0.96`, `Fuel Oil, Tank, UEF=0.61`, `Fuel Oil, Tank, UEF=0.64`, `Fuel Oil, Tank, UEF=0.67`, `Propane, Tank, UEF=0.57`, `Propane, Tank, UEF=0.60`, `Propane, Tank, UEF=0.64`, `Propane, Tank, UEF=0.67`, `Propane, Tank, UEF=0.70`, `Propane, Tank, UEF=0.80`, `Propane, Tankless, UEF=0.82`, `Propane, Tankless, UEF=0.93`, `Propane, Tankless, UEF=0.96`, `Space-Heating Boiler w/ Storage Tank`, `Space-Heating Boiler w/ Tankless Coil`, `Detailed Example: Electricity, Tank, 40 gal, EF=0.93`, `Detailed Example: Electricity, Tankless, EF=0.96`, `Detailed Example: Electricity, Heat Pump, 80 gal, EF=3.1`, `Detailed Example: Natural Gas, Tank, 40 gal, EF=0.56, RE=0.78`, `Detailed Example: Natural Gas, Tank, 40 gal, EF=0.62, RE=0.78`, `Detailed Example: Natural Gas, Tank, 50 gal, EF=0.59, RE=0.76`, `Detailed Example: Natural Gas, Tankless, EF=0.95`

<br/>

**DHW: Water Heater Location**

The location of water heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-water-heating-systems'>HPXML Water Heating Systems</a>) is used.

- **Name:** ``dhw_water_heater_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `attic`, `attic - vented`, `attic - unvented`, `crawlspace`, `crawlspace - vented`, `crawlspace - unvented`, `crawlspace - conditioned`, `other exterior`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**DHW: Water Heater Jacket R-value**

The jacket R-value of water heater. Doesn't apply to instantaneous water heater or space-heating boiler with tankless coil. If not provided, defaults to no jacket insulation.

- **Name:** ``dhw_water_heater_jacket_rvalue``
- **Type:** ``Double``

- **Units:** ``F-ft2-hr/Btu``

- **Required:** ``false``

<br/>

**DHW: Water Heater Setpoint Temperature**

The setpoint temperature of water heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-water-heating-systems'>HPXML Water Heating Systems</a>) is used.

- **Name:** ``dhw_water_heater_setpoint_temperature``
- **Type:** ``Double``

- **Units:** ``F``

- **Required:** ``false``

<br/>

**DHW: Water Heater Uses Desuperheater**

Requires that the dwelling unit has a air-to-air, mini-split, or ground-to-air heat pump or a central air conditioner or mini-split air conditioner. If not provided, assumes no desuperheater.

- **Name:** ``dhw_water_heater_uses_desuperheater``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**DHW: Hot Water Distribution**

The type of domestic hot water distrubtion.

- **Name:** ``dhw_distribution``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Uninsulated, Standard`, `Uninsulated, Recirc, Uncontrolled`, `Uninsulated, Recirc, Timer Control`, `Uninsulated, Recirc, Temperature Control`, `Uninsulated, Recirc, Presence Sensor Demand Control`, `Uninsulated, Recirc, Manual Demand Control`, `Insulated, Standard`, `Insulated, Recirc, Uncontrolled`, `Insulated, Recirc, Timer Control`, `Insulated, Recirc, Temperature Control`, `Insulated, Recirc, Presence Sensor Demand Control`, `Insulated, Recirc, Manual Demand Control`, `Detailed Example: Insulated, Recirc, Uncontrolled, 156.9ft Loop, 10ft Branch, 50 W`, `Detailed Example: Insulated, Recirc, Manual Demand Control, 156.9ft Loop, 10ft Branch, 50 W`

<br/>

**DHW: Hot Water Fixtures**

The type of domestic hot water fixtures.

- **Name:** ``dhw_fixtures``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Standard`, `Low Flow`

<br/>

**DHW: Drain Water Heat Reovery**

The type of drain water heater recovery.

- **Name:** ``dhw_drain_water_heat_recovery``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `25% Efficient, Preheats Hot Only, All Showers`, `25% Efficient, Preheats Hot Only, 1 Shower`, `25% Efficient, Preheats Hot and Cold, All Showers`, `25% Efficient, Preheats Hot and Cold, 1 Shower`, `35% Efficient, Preheats Hot Only, All Showers`, `35% Efficient, Preheats Hot Only, 1 Shower`, `35% Efficient, Preheats Hot and Cold, All Showers`, `35% Efficient, Preheats Hot and Cold, 1 Shower`, `45% Efficient, Preheats Hot Only, All Showers`, `45% Efficient, Preheats Hot Only, 1 Shower`, `45% Efficient, Preheats Hot and Cold, All Showers`, `45% Efficient, Preheats Hot and Cold, 1 Shower`, `55% Efficient, Preheats Hot Only, All Showers`, `55% Efficient, Preheats Hot Only, 1 Shower`, `55% Efficient, Preheats Hot and Cold, All Showers`, `55% Efficient, Preheats Hot and Cold, 1 Shower`, `Detailed Example: 54% Efficient, Preheats Hot and Cold, All Showers`

<br/>

**DHW: Hot Water Fixtures Usage Multiplier**

Multiplier on the hot water usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-water-fixtures'>HPXML Water Fixtures</a>) is used.

- **Name:** ``dhw_water_fixtures_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**DHW: Solar Thermal**

The size and type of solar thermal system for domestic hot water.

- **Name:** ``dhw_solar_thermal``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Indirect, Flat Plate, 40 sqft`, `Indirect, Flat Plate, 64 sqft`, `Direct, Flat Plate, 40 sqft`, `Direct. Flat Plate, 64 sqft`, `Direct, Integrated Collector Storage, 40 sqft`, `Direct, Integrated Collector Storage, 64 sqft`, `Direct, Evacuated Tube, 40 sqft`, `Direct, Evacuated Tube, 64 sqft`, `Thermosyphon, Flat Plate, 40 sqft`, `Thermosyphon, Flat Plate, 64 sqft`, `60% Solar Fraction`, `65% Solar Fraction`, `70% Solar Fraction`, `75% Solar Fraction`, `80% Solar Fraction`, `85% Solar Fraction`, `90% Solar Fraction`, `95% Solar Fraction`

<br/>

**DHW: Solar Thermal Collector Azimuth**

The azimuth of the solar thermal system collectors. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).

- **Name:** ``dhw_solar_thermal_collector_azimuth``
- **Type:** ``Double``

- **Units:** ``degrees``

- **Required:** ``false``

<br/>

**DHW: Solar Thermal Collector Tilt**

The tilt of the solar thermal system collectors. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.

- **Name:** ``dhw_solar_thermal_collector_tilt``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**PV System**

The size and type of PV system.

- **Name:** ``pv_system``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `0.5 kW`, `1.0 kW`, `1.5 kW`, `1.5 kW, Premium Module`, `1.5 kW, Thin Film Module`, `2.0 kW`, `2.5 kW`, `3.0 kW`, `3.5 kW`, `4.0 kW`, `4.5 kW`, `5.0 kW`, `5.5 kW`, `6.0 kW`, `6.5 kW`, `7.0 kW`, `7.5 kW`, `8.0 kW`, `8.5 kW`, `9.0 kW`, `9.5 kW`, `10.0 kW`, `10.5 kW`, `11.0 kW`, `11.5 kW`, `12.0 kW`

<br/>

**PV System: Array Azimuth**

The azimuth of the PV system array. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).

- **Name:** ``pv_system_array_azimuth``
- **Type:** ``Double``

- **Units:** ``degrees``

- **Required:** ``false``

<br/>

**PV System: Array Tilt**

The tilt of the PV system array. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.

- **Name:** ``pv_system_array_tilt``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**PV System 2**

The size and type of the second PV system.

- **Name:** ``pv_system_2``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `0.5 kW`, `1.0 kW`, `1.5 kW`, `1.5 kW, Premium Module`, `1.5 kW, Thin Film Module`, `2.0 kW`, `2.5 kW`, `3.0 kW`, `3.5 kW`, `4.0 kW`, `4.5 kW`, `5.0 kW`, `5.5 kW`, `6.0 kW`, `6.5 kW`, `7.0 kW`, `7.5 kW`, `8.0 kW`, `8.5 kW`, `9.0 kW`, `9.5 kW`, `10.0 kW`, `10.5 kW`, `11.0 kW`, `11.5 kW`, `12.0 kW`

<br/>

**PV System 2: Array Azimuth**

The azimuth of the second PV system array. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).

- **Name:** ``pv_system_2_array_azimuth``
- **Type:** ``Double``

- **Units:** ``degrees``

- **Required:** ``false``

<br/>

**PV System 2: Array Tilt**

The tilt of the second PV system array. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.

- **Name:** ``pv_system_2_array_tilt``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Electric Panel: Service/Feeders Load Calculation Types**

Types of electric panel service/feeder load calculations. These calculations are experimental research features. Possible types are: 2023 Existing Dwelling Load-Based, 2023 Existing Dwelling Meter-Based. If multiple types, use a comma-separated list. If not provided, no electric panel loads are calculated.

- **Name:** ``electric_panel_service_feeders_load_calculation_types``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Electric Panel: Baseline Peak Power**

Specifies the baseline peak power. Used for 2023 Existing Dwelling Meter-Based. If not provided, assumed to be zero.

- **Name:** ``electric_panel_baseline_peak_power``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Service Voltage**

The service voltage of the electric panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-electric-panels'>HPXML Electric Panels</a>) is used.

- **Name:** ``electric_panel_service_voltage``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `120`, `240`

<br/>

**Electric Panel: Service Max Current Rating**

The service max current rating of the electric panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-electric-panels'>HPXML Electric Panels</a>) is used.

- **Name:** ``electric_panel_service_max_current_rating``
- **Type:** ``Double``

- **Units:** ``A``

- **Required:** ``false``

<br/>

**Electric Panel: Breaker Spaces Headroom**

The unoccupied number of breaker spaces on the electric panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-electric-panels'>HPXML Electric Panels</a>) is used.

- **Name:** ``electric_panel_breaker_spaces_headroom``
- **Type:** ``Integer``

- **Units:** ``#``

- **Required:** ``false``

<br/>

**Electric Panel: Breaker Spaces Rated Total**

The rated total number of breaker spaces on the electric panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-electric-panels'>HPXML Electric Panels</a>) is used.

- **Name:** ``electric_panel_breaker_spaces_rated_total``
- **Type:** ``Integer``

- **Units:** ``#``

- **Required:** ``false``

<br/>

**Electric Panel: Heating System Power Rating**

Specifies the panel load heating system power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_heating_system_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Heating System New Load**

Whether the heating system is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_heating_system_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Cooling System Power Rating**

Specifies the panel load cooling system power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_cooling_system_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Cooling System New Load**

Whether the cooling system is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_cooling_system_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Heat Pump Power Rating**

Specifies the panel load heat pump power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_heat_pump_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Heat Pump New Load**

Whether the heat pump is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_heat_pump_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Heating System 2 Power Rating**

Specifies the panel load second heating system power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_heating_system_2_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Heating System 2 New Load**

Whether the second heating system is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_heating_system_2_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Mechanical Ventilation Power Rating**

Specifies the panel load mechanical ventilation power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_mech_vent_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Mechanical Ventilation New Load**

Whether the mechanical ventilation is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_mech_vent_fan_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Whole House Fan Power Rating**

Specifies the panel load whole house fan power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_whole_house_fan_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Whole House Fan New Load**

Whether the whole house fan is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_whole_house_fan_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Kitchen Fans Power Rating**

Specifies the panel load kitchen fans power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_kitchen_fans_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Kitchen Fans New Load**

Whether the kitchen fans is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_kitchen_fans_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Bathroom Fans Power Rating**

Specifies the panel load bathroom fans power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_bathroom_fans_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Bathroom Fans New Load**

Whether the bathroom fans is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_bathroom_fans_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Electric Water Heater Power Rating**

Specifies the panel load water heater power rating. Only applies to electric water heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_water_heater_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Electric Water Heater Voltage**

Specifies the panel load water heater voltage. Only applies to electric water heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_water_heater_voltage``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `120`, `240`

<br/>

**Electric Panel: Electric Water Heater New Load**

Whether the water heater is a new panel load addition to an existing service panel. Only applies to electric water heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_water_heater_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Electric Clothes Dryer Power Rating**

Specifies the panel load clothes dryer power rating. Only applies to electric clothes dryer. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_clothes_dryer_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Electric Clothes Dryer Voltage**

Specifies the panel load clothes dryer voltage. Only applies to electric clothes dryer. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_clothes_dryer_voltage``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `120`, `240`

<br/>

**Electric Panel: Electric Clothes Dryer New Load**

Whether the clothes dryer is a new panel load addition to an existing service panel. Only applies to electric clothes dryer. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_clothes_dryer_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Dishwasher Power Rating**

Specifies the panel load dishwasher power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_dishwasher_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Dishwasher New Load**

Whether the dishwasher is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_dishwasher_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Electric Cooking Range/Oven Power Rating**

Specifies the panel load cooking range/oven power rating. Only applies to electric cooking range/oven. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_cooking_range_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Electric Cooking Range/Oven Voltage**

Specifies the panel load cooking range/oven voltage. Only applies to electric cooking range/oven. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_cooking_range_voltage``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `120`, `240`

<br/>

**Electric Panel: Electric Cooking Range/Oven New Load**

Whether the cooking range is a new panel load addition to an existing service panel. Only applies to electric cooking range/oven. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_cooking_range_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Misc Plug Loads Well Pump Power Rating**

Specifies the panel load well pump power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_misc_plug_loads_well_pump_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Misc Plug Loads Well Pump New Load**

Whether the well pump is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_misc_plug_loads_well_pump_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Misc Plug Loads Vehicle Power Rating**

Specifies the panel load electric vehicle power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_misc_plug_loads_vehicle_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Misc Plug Loads Vehicle Voltage**

Specifies the panel load electric vehicle voltage. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_misc_plug_loads_vehicle_voltage``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `120`, `240`

<br/>

**Electric Panel: Misc Plug Loads Vehicle New Load**

Whether the electric vehicle is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_misc_plug_loads_vehicle_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Pool Pump Power Rating**

Specifies the panel load pool pump power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_pool_pump_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Pool Pump New Load**

Whether the pool pump is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_pool_pump_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Electric Pool Heater Power Rating**

Specifies the panel load pool heater power rating. Only applies to electric pool heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_pool_heater_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Electric Pool Heater New Load**

Whether the pool heater is a new panel load addition to an existing service panel. Only applies to electric pool heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_pool_heater_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Permanent Spa Pump Power Rating**

Specifies the panel load permanent spa pump power rating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_permanent_spa_pump_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Permanent Spa Pump New Load**

Whether the spa pump is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_permanent_spa_pump_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Electric Permanent Spa Heater Power Rating**

Specifies the panel load permanent spa heater power rating. Only applies to electric permanent spa heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_permanent_spa_heater_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Electric Permanent Spa Heater New Load**

Whether the spa heater is a new panel load addition to an existing service panel. Only applies to electric permanent spa heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_electric_permanent_spa_heater_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Panel: Other Power Rating**

Specifies the panel load other power rating. This represents the total of all other electric loads that are fastened in place, permanently connected, or located on a specific circuit. For example, garbage disposal, built-in microwave. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_other_power_rating``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Electric Panel: Other New Load**

Whether the other load is a new panel load addition to an existing service panel. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#service-feeders'>Service Feeders</a>) is used.

- **Name:** ``electric_panel_load_other_new_load``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Battery**

The size and type of battery storage.

- **Name:** ``battery``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `5.0 kWh`, `7.5 kWh`, `10.0 kWh`, `12.5 kWh`, `15.0 kWh`, `17.5 kWh`, `20.0 kWh`, `Detailed Example: 20.0 kWh, 6 kW, Garage`, `Detailed Example: 20.0 kWh, 6 kW, Outside`, `Detailed Example: 20.0 kWh, 6 kW, Outside, 80% Efficiency`

<br/>

**Electric Vehicle**

The type of battery electric vehicle.

- **Name:** ``electric_vehicle``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Compact, 200 mile range`, `Compact, 300 mile range`, `Midsize, 200 mile range`, `Midsize, 300 mile range`, `Pickup, 200 mile range`, `Pickup, 300 mile range`, `SUV, 200 mile range`, `SUV, 300 mile range`, `Detailed Example: 100 kWh battery, 0.25 kWh/mile`, `Detailed Example: 100 kWh battery, 4.0 miles/kWh`, `Detailed Example: 100 kWh battery, 135.0 mpge`

<br/>

**Electric Vehicle: Miles Driven Per Year**

The annual miles the vehicle is driven. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-vehicles'>HPXML Vehicles</a>) is used.

- **Name:** ``electric_vehicle_miles_driven_per_year``
- **Type:** ``Double``

- **Units:** ``miles``

- **Required:** ``false``

<br/>

**Electric Vehicle: Charger**

The type and usage of electric vehicle charger.

- **Name:** ``electric_vehicle_charger``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Level 1, 10% Charging at Home`, `Level 1, 30% Charging at Home`, `Level 1, 50% Charging at Home`, `Level 1, 70% Charging at Home`, `Level 1, 90% Charging at Home`, `Level 1, 100% Charging at Home`, `Level 2, 10% Charging at Home`, `Level 2, 30% Charging at Home`, `Level 2, 50% Charging at Home`, `Level 2, 70% Charging at Home`, `Level 2, 90% Charging at Home`, `Level 2, 100% Charging at Home`, `Detailed Example: Level 2, 7000 W, 75% Charging at Home`

<br/>

**Appliances: Clothes Washer**

The type of clothes washer.

- **Name:** ``appliance_clothes_washer``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Standard, 2008-2017`, `Standard, 2018-present`, `EnergyStar, 2006-2017`, `EnergyStar, 2018-present`, `CEE Tier II 2018`, `Detailed Example: ERI Reference 2006`, `Detailed Example: MEF=1.65`

<br/>

**Appliances: Clothes Washer Location**

The space type for the clothes washer location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-washer'>HPXML Clothes Washer</a>) is used.

- **Name:** ``appliance_clothes_washer_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Appliances: Clothes Washer Usage Multiplier**

Multiplier on the clothes washer energy and hot water usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-washer'>HPXML Clothes Washer</a>) is used.

- **Name:** ``appliance_clothes_washer_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Appliances: Clothes Dryer**

The type of clothes dryer.

- **Name:** ``appliance_clothes_dryer``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Electricity, Standard`, `Electricity, Premium`, `Electricity, Heat Pump`, `Natural Gas, Standard`, `Natural Gas, Premium`, `Propane, Standard`, `Detailed Example: Electricity, ERI Reference 2006`, `Detailed Example: Natural Gas, ERI Reference 2006`, `Detailed Example: Electricity, EF=4.29`

<br/>

**Appliances: Clothes Dryer Location**

The space type for the clothes dryer location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-dryer'>HPXML Clothes Dryer</a>) is used.

- **Name:** ``appliance_clothes_dryer_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Appliances: Clothes Dryer Usage Multiplier**

Multiplier on the clothes dryer energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-dryer'>HPXML Clothes Dryer</a>) is used.

- **Name:** ``appliance_clothes_dryer_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Appliances: Dishwasher**

The type of dishwasher.

- **Name:** ``appliance_dishwasher``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Federal Minimum, Standard`, `EnergyStar, Standard`, `EnergyStar, Compact`, `Detailed Example: ERI Reference 2006`, `Detailed Example: EF=0.7, Compact`

<br/>

**Appliances: Dishwasher Location**

The space type for the dishwasher location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-dishwasher'>HPXML Dishwasher</a>) is used.

- **Name:** ``appliance_dishwasher_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Appliances: Dishwasher Usage Multiplier**

Multiplier on the dishwasher energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-dishwasher'>HPXML Dishwasher</a>) is used.

- **Name:** ``appliance_dishwasher_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Appliances: Refrigerator**

The type of refrigerator.

- **Name:** ``appliance_refrigerator``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `1139 kWh/yr`, `748 kWh/yr`, `650 kWh/yr`, `574 kWh/yr`, `547 kWh/yr`, `480 kWh/yr`, `458 kWh/yr`, `434 kWh/yr`, `384 kWh/yr`, `348 kWh/yr`, `Detailed Example: ERI Reference 2006, 2-Bedroom Home`, `Detailed Example: ERI Reference 2006, 3-Bedroom Home`, `Detailed Example: ERI Reference 2006, 4-Bedroom Home`

<br/>

**Appliances: Refrigerator Location**

The space type for the refrigerator location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-refrigerators'>HPXML Refrigerators</a>) is used.

- **Name:** ``appliance_refrigerator_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Appliances: Refrigerator Usage Multiplier**

Multiplier on the refrigerator energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-refrigerators'>HPXML Refrigerators</a>) is used.

- **Name:** ``appliance_refrigerator_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Appliances: Extra Refrigerator**

The type of extra refrigerator.

- **Name:** ``appliance_extra_refrigerator``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `1139 kWh/yr`, `748 kWh/yr`, `650 kWh/yr`, `574 kWh/yr`, `547 kWh/yr`, `480 kWh/yr`, `458 kWh/yr`, `434 kWh/yr`, `384 kWh/yr`, `348 kWh/yr`

<br/>

**Appliances: Extra Refrigerator Location**

The space type for the extra refrigerator location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-refrigerators'>HPXML Refrigerators</a>) is used.

- **Name:** ``appliance_extra_refrigerator_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Appliances: Extra Refrigerator Usage Multiplier**

Multiplier on the extra refrigerator energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-refrigerators'>HPXML Refrigerators</a>) is used.

- **Name:** ``appliance_extra_refrigerator_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Appliances: Freezer**

The type of freezer.

- **Name:** ``appliance_freezer``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `935 kWh/yr`, `712 kWh/yr`, `641 kWh/yr`, `568 kWh/yr`, `417 kWh/yr`, `375 kWh/yr`, `354 kWh/yr`

<br/>

**Appliances: Freezer Location**

The space type for the freezer location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-freezers'>HPXML Freezers</a>) is used.

- **Name:** ``appliance_freezer_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Appliances: Freezer Usage Multiplier**

Multiplier on the freezer energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-freezers'>HPXML Freezers</a>) is used.

- **Name:** ``appliance_freezer_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Appliances: Cooking Range/Oven**

The type of cooking range/oven.

- **Name:** ``appliance_cooking_range_oven``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Electricity, Standard, Non-Convection Oven`, `Electricity, Standard, Convection Oven`, `Electricity, Induction, Non-Convection Oven`, `Electricity, Induction, Convection Oven`, `Natural Gas, Non-Convection Oven`, `Natural Gas, Convection Oven`, `Propane, Non-Convection Oven`, `Propane, Convection Oven`

<br/>

**Appliances: Cooking Range/Oven Location**

The space type for the cooking range/oven location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-cooking-range-oven'>HPXML Cooking Range/Oven</a>) is used.

- **Name:** ``appliance_cooking_range_oven_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Appliances: Cooking Range/Oven Usage Multiplier**

Multiplier on the cooking range/oven energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-cooking-range-oven'>HPXML Cooking Range/Oven</a>) is used.

- **Name:** ``appliance_cooking_range_oven_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Appliances: Dehumidifier**

The type of dehumidifier.

- **Name:** ``appliance_dehumidifier``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Portable, 15 pints/day`, `Portable, 20 pints/day`, `Portable, 30 pints/day`, `Portable, 40 pints/day`, `Whole-Home, 60 pints/day`, `Whole-Home, 75 pints/day`, `Whole-Home, 95 pints/day`, `Whole-Home, 125 pints/day`, `Detailed Example: Portable, 40 pints/day, EF=1.8`

<br/>

**Appliances: Dehumidifier Relative Humidity Setpoint**

The dehumidifier's relative humidity setpoint.

- **Name:** ``appliance_dehumidifier_rh_setpoint``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``false``

<br/>

**Lighting**

The type of lighting.

- **Name:** ``lighting``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `100% Incandescent`, `10% CFL`, `20% CFL`, `30% CFL`, `40% CFL`, `50% CFL`, `60% CFL`, `70% CFL`, `80% CFL`, `90% CFL`, `100% CFL`, `10% LED`, `20% LED`, `30% LED`, `40% LED`, `50% LED`, `60% LED`, `70% LED`, `80% LED`, `90% LED`, `100% LED`, `Detailed Example: 40% CFL, 10% LFL, 25% LED`

<br/>

**Lighting: Interior Usage Multiplier**

Multiplier on the lighting energy usage (interior) that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-lighting'>HPXML Lighting</a>) is used.

- **Name:** ``lighting_interior_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Lighting: Exterior Usage Multiplier**

Multiplier on the lighting energy usage (exterior) that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-lighting'>HPXML Lighting</a>) is used.

- **Name:** ``lighting_exterior_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Lighting: Garage Usage Multiplier**

Multiplier on the lighting energy usage (garage) that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-lighting'>HPXML Lighting</a>) is used.

- **Name:** ``lighting_garage_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Ceiling Fans**

The type of ceiling fans.

- **Name:** ``ceiling_fans``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `#Bedrooms+1 Fans, 45 W`, `#Bedrooms+1 Fans, 30 W`, `#Bedrooms+1 Fans, 15 W`, `1 Fan, 45 W`, `1 Fan, 30 W`, `1 Fan, 15 W`, `2 Fans, 45 W`, `2 Fans, 30 W`, `2 Fans, 15 W`, `3 Fans, 45 W`, `3 Fans, 30 W`, `3 Fans, 15 W`, `4 Fans, 45 W`, `4 Fans, 30 W`, `4 Fans, 15 W`, `5 Fans, 45 W`, `5 Fans, 30 W`, `5 Fans, 15 W`, `Detailed Example: 4 Fans, 39 W, 0.5 deg-F Setpoint Offset`, `Detailed Example: 4 Fans, 100 cfm/W, 0.5 deg-F Setpoint Offset`

<br/>

**Misc: Television**

The amount of television usage, relative to the national average.

- **Name:** ``misc_television``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `25%`, `33%`, `50%`, `75%`, `80%`, `90%`, `100%`, `110%`, `125%`, `150%`, `200%`, `300%`, `400%`, `Detailed Example: 620 kWh/yr`

<br/>

**Misc: Plug Loads**

The amount of additional plug load usage, relative to the national average.

- **Name:** ``misc_plug_loads``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `25%`, `33%`, `50%`, `75%`, `80%`, `90%`, `100%`, `110%`, `125%`, `150%`, `200%`, `300%`, `400%`, `Detailed Example: 2457 kWh/yr, 85.5% Sensible, 4.5% Latent`, `Detailed Example: 7302 kWh/yr, 82.2% Sensible, 17.8% Latent`

<br/>

**Misc: Well Pump**

The amount of well pump usage, relative to the national average.

- **Name:** ``misc_well_pump``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Typical Efficiency`, `High Efficiency`, `Detailed Example: 475 kWh/yr`

<br/>

**Misc: Electric Vehicle Charging**

The amount of EV charging usage, relative to the national average. Only use this if a detailed EV & EV charger were not otherwise specified.

- **Name:** ``misc_electric_vehicle_charging``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `25%`, `33%`, `50%`, `75%`, `80%`, `90%`, `100%`, `110%`, `125%`, `150%`, `200%`, `300%`, `400%`, `Detailed Example: 1500 kWh/yr`, `Detailed Example: 3000 kWh/yr`

<br/>

**Misc: Gas Grill**

The amount of outdoor gas grill usage, relative to the national average.

- **Name:** ``misc_grill``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Natural Gas, 25%`, `Natural Gas, 33%`, `Natural Gas, 50%`, `Natural Gas, 67%`, `Natural Gas, 90%`, `Natural Gas, 100%`, `Natural Gas, 110%`, `Natural Gas, 150%`, `Natural Gas, 200%`, `Natural Gas, 300%`, `Natural Gas, 400%`, `Propane, 25%`, `Propane, 33%`, `Propane, 50%`, `Propane, 67%`, `Propane, 90%`, `Propane, 100%`, `Propane, 110%`, `Propane, 150%`, `Propane, 200%`, `Propane, 300%`, `Propane, 400%`, `Detailed Example: Propane, 25 therm/yr`

<br/>

**Misc: Gas Lighting**

The amount of gas lighting usage, relative to the national average.

- **Name:** ``misc_gas_lighting``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Natural Gas, 25%`, `Natural Gas, 33%`, `Natural Gas, 50%`, `Natural Gas, 67%`, `Natural Gas, 90%`, `Natural Gas, 100%`, `Natural Gas, 110%`, `Natural Gas, 150%`, `Natural Gas, 200%`, `Natural Gas, 300%`, `Natural Gas, 400%`, `Detailed Example: Natural Gas, 28 therm/yr`

<br/>

**Misc: Fireplace**

The amount of fireplace usage, relative to the national average. Fireplaces can also be specified as heating systems that meet a portion of the heating load.

- **Name:** ``misc_fireplace``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Natural Gas, 25%`, `Natural Gas, 33%`, `Natural Gas, 50%`, `Natural Gas, 67%`, `Natural Gas, 90%`, `Natural Gas, 100%`, `Natural Gas, 110%`, `Natural Gas, 150%`, `Natural Gas, 200%`, `Natural Gas, 300%`, `Natural Gas, 400%`, `Propane, 25%`, `Propane, 33%`, `Propane, 50%`, `Propane, 67%`, `Propane, 90%`, `Propane, 100%`, `Propane, 110%`, `Propane, 150%`, `Propane, 200%`, `Propane, 300%`, `Propane, 400%`, `Wood, 25%`, `Wood, 33%`, `Wood, 50%`, `Wood, 67%`, `Wood, 90%`, `Wood, 100%`, `Wood, 110%`, `Wood, 150%`, `Wood, 200%`, `Wood, 300%`, `Wood, 400%`, `Electric, 25%`, `Electric, 33%`, `Electric, 50%`, `Electric, 67%`, `Electric, 90%`, `Electric, 100%`, `Electric, 110%`, `Electric, 150%`, `Electric, 200%`, `Electric, 300%`, `Electric, 400%`, `Detailed Example: Wood, 55 therm/yr`

<br/>

**Misc: Pool**

The type of pool (pump & heater).

- **Name:** ``misc_pool``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Pool, Unheated`, `Pool, Electric Resistance Heater`, `Pool, Heat Pump Heater`, `Pool, Natural Gas Heater`, `Detailed Example: Pool, Natural Gas Heater, 90% Usage Multiplier`, `Detailed Example: Pool, 2700 kWh/yr Pump, Unheated`, `Detailed Example: Pool, 2700 kWh/yr Pump, 500 therms/yr Natural Gas Heater`

<br/>

**Misc: Permanent Spa**

The type of permanent spa (pump & heater).

- **Name:** ``misc_permanent_spa``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Spa, Unheated`, `Spa, Electric Resistance Heater`, `Spa, Heat Pump Heater`, `Spa, Natural Gas Heater`, `Detailed Example: Spa, 1000 kWh/yr Pump, 1300 kWh/yr Electric Resistance Heater`, `Detailed Example: Spa, 1000 kWh/yr Pump, 1300 kWh/yr Electric Resistance Heater, 90% Usage Multiplier`, `Detailed Example: Spa, 1000 kWh/yr Pump, 260 kWh/yr Heat Pump Heater`

<br/>

**Emissions: Scenario Names**

Names of emissions scenarios. If multiple scenarios, use a comma-separated list. If not provided, no emissions scenarios are calculated.

- **Name:** ``emissions_scenario_names``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Emissions: Types**

Types of emissions (e.g., CO2e, NOx, etc.). If multiple scenarios, use a comma-separated list.

- **Name:** ``emissions_types``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Emissions: Electricity Units**

Electricity emissions factors units. If multiple scenarios, use a comma-separated list. Only lb/MWh and kg/MWh are allowed.

- **Name:** ``emissions_electricity_units``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Emissions: Electricity Values or File Paths**

Electricity emissions factors values, specified as either an annual factor or an absolute/relative path to a file with hourly factors. If multiple scenarios, use a comma-separated list.

- **Name:** ``emissions_electricity_values_or_filepaths``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Emissions: Electricity Files Number of Header Rows**

The number of header rows in the electricity emissions factor file. Only applies when an electricity filepath is used. If multiple scenarios, use a comma-separated list.

- **Name:** ``emissions_electricity_number_of_header_rows``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Emissions: Electricity Files Column Numbers**

The column number in the electricity emissions factor file. Only applies when an electricity filepath is used. If multiple scenarios, use a comma-separated list.

- **Name:** ``emissions_electricity_column_numbers``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Emissions: Fossil Fuel Units**

Fossil fuel emissions factors units. If multiple scenarios, use a comma-separated list. Only lb/MBtu and kg/MBtu are allowed.

- **Name:** ``emissions_fossil_fuel_units``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Emissions: Natural Gas Values**

Natural gas emissions factors values, specified as an annual factor. If multiple scenarios, use a comma-separated list.

- **Name:** ``emissions_natural_gas_values``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Emissions: Propane Values**

Propane emissions factors values, specified as an annual factor. If multiple scenarios, use a comma-separated list.

- **Name:** ``emissions_propane_values``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Emissions: Fuel Oil Values**

Fuel oil emissions factors values, specified as an annual factor. If multiple scenarios, use a comma-separated list.

- **Name:** ``emissions_fuel_oil_values``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Emissions: Coal Values**

Coal emissions factors values, specified as an annual factor. If multiple scenarios, use a comma-separated list.

- **Name:** ``emissions_coal_values``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Emissions: Wood Values**

Wood emissions factors values, specified as an annual factor. If multiple scenarios, use a comma-separated list.

- **Name:** ``emissions_wood_values``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Emissions: Wood Pellets Values**

Wood pellets emissions factors values, specified as an annual factor. If multiple scenarios, use a comma-separated list.

- **Name:** ``emissions_wood_pellets_values``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Scenario Names**

Names of utility bill scenarios. If multiple scenarios, use a comma-separated list. If not provided, no utility bills scenarios are calculated.

- **Name:** ``utility_bill_scenario_names``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Electricity File Paths**

Electricity tariff file specified as an absolute/relative path to a file with utility rate structure information. Tariff file must be formatted to OpenEI API version 7. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_electricity_filepaths``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Electricity Fixed Charges**

Electricity utility bill monthly fixed charges. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_electricity_fixed_charges``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Natural Gas Fixed Charges**

Natural gas utility bill monthly fixed charges. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_natural_gas_fixed_charges``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Propane Fixed Charges**

Propane utility bill monthly fixed charges. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_propane_fixed_charges``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Fuel Oil Fixed Charges**

Fuel oil utility bill monthly fixed charges. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_fuel_oil_fixed_charges``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Coal Fixed Charges**

Coal utility bill monthly fixed charges. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_coal_fixed_charges``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Wood Fixed Charges**

Wood utility bill monthly fixed charges. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_wood_fixed_charges``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Wood Pellets Fixed Charges**

Wood pellets utility bill monthly fixed charges. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_wood_pellets_fixed_charges``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Electricity Marginal Rates**

Electricity utility bill marginal rates. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_electricity_marginal_rates``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Natural Gas Marginal Rates**

Natural gas utility bill marginal rates. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_natural_gas_marginal_rates``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Propane Marginal Rates**

Propane utility bill marginal rates. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_propane_marginal_rates``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Fuel Oil Marginal Rates**

Fuel oil utility bill marginal rates. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_fuel_oil_marginal_rates``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Coal Marginal Rates**

Coal utility bill marginal rates. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_coal_marginal_rates``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Wood Marginal Rates**

Wood utility bill marginal rates. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_wood_marginal_rates``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: Wood Pellets Marginal Rates**

Wood pellets utility bill marginal rates. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_wood_pellets_marginal_rates``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: PV Compensation Types**

Utility bill PV compensation types. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_pv_compensation_types``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: PV Net Metering Annual Excess Sellback Rate Types**

Utility bill PV net metering annual excess sellback rate types. Only applies if the PV compensation type is 'NetMetering'. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_pv_net_metering_annual_excess_sellback_rate_types``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: PV Net Metering Annual Excess Sellback Rates**

Utility bill PV net metering annual excess sellback rates. Only applies if the PV compensation type is 'NetMetering' and the PV annual excess sellback rate type is 'User-Specified'. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_pv_net_metering_annual_excess_sellback_rates``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: PV Feed-In Tariff Rates**

Utility bill PV annual full/gross feed-in tariff rates. Only applies if the PV compensation type is 'FeedInTariff'. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_pv_feed_in_tariff_rates``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: PV Monthly Grid Connection Fee Units**

Utility bill PV monthly grid connection fee units. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_pv_monthly_grid_connection_fee_units``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Utility Bills: PV Monthly Grid Connection Fees**

Utility bill PV monthly grid connection fees. If multiple scenarios, use a comma-separated list.

- **Name:** ``utility_bill_pv_monthly_grid_connection_fees``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Additional Properties**

Additional properties specified as key-value pairs (i.e., key=value). If multiple additional properties, use a |-separated list. For example, 'LowIncome=false|Remodeled|Description=2-story home in Denver'. These properties will be stored in the HPXML file under /HPXML/SoftwareInfo/extension/AdditionalProperties.

- **Name:** ``additional_properties``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Combine like surfaces?**

If true, combines like surfaces to simplify the HPXML file generated.

- **Name:** ``combine_like_surfaces``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Apply Default Values?**

If true, applies OS-HPXML default values to the HPXML output file. Setting to true will also force validation of the HPXML output file before applying OS-HPXML default values.

- **Name:** ``apply_defaults``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Apply Validation?**

If true, validates the HPXML output file. Set to false for faster performance. Note that validation is not needed if the HPXML file will be validated downstream (e.g., via the HPXMLtoOpenStudio measure).

- **Name:** ``apply_validation``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>





