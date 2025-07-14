
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

**Simulation Control: Run Period Calendar Year**

This numeric field should contain the calendar year that determines the start day of week. If you are running simulations using AMY weather files, the value entered for calendar year will not be used; it will be overridden by the actual year found in the AMY weather file. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-simulation-control'>HPXML Simulation Control</a>) is used.

- **Name:** ``simulation_control_run_period_calendar_year``
- **Type:** ``Integer``

- **Units:** ``year``

- **Required:** ``false``

<br/>

**Simulation Control: Daylight Saving Enabled**

Whether to use daylight saving. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-building-site'>HPXML Building Site</a>) is used.

- **Name:** ``simulation_control_daylight_saving_enabled``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Simulation Control: Daylight Saving Period**

Enter a date range like 'Mar 15 - Dec 15'. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-building-site'>HPXML Building Site</a>) is used.

- **Name:** ``simulation_control_daylight_saving_period``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Simulation Control: Temperature Capacitance Multiplier**

Affects the transient calculation of indoor air temperatures. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-simulation-control'>HPXML Simulation Control</a>) is used.

- **Name:** ``simulation_control_temperature_capacitance_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Simulation Control: Ground-to-Air Heat Pump Model Type**

Research feature to select the type of ground-to-air heat pump model. Use standard for standard ground-to-air heat pump modeling. Use experimental for an improved model that better accounts for coil staging. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-simulation-control'>HPXML Simulation Control</a>) is used.

- **Name:** ``simulation_control_ground_to_air_heat_pump_model_type``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `standard`, `experimental`

<br/>

**Simulation Control: HVAC On-Off Thermostat Deadband**

Research feature to model on-off thermostat deadband and start-up degradation for single or two speed AC/ASHP systems, and realistic time-based staging for two speed AC/ASHP systems. Currently only supported with 1 min timestep.

- **Name:** ``simulation_control_onoff_thermostat_deadband``
- **Type:** ``Double``

- **Units:** ``deg-F``

- **Required:** ``false``

<br/>

**Simulation Control: Heat Pump Backup Heating Capacity Increment**

Research feature to model capacity increment of multi-stage heat pump backup systems with time-based staging. Only applies to air-source heat pumps where Backup Type is 'integrated' and Backup Fuel Type is 'electricity'. Currently only supported with 1 min timestep.

- **Name:** ``simulation_control_heat_pump_backup_heating_capacity_increment``
- **Type:** ``Double``

- **Units:** ``Btu/hr``

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

**Site: IECC Zone**

IECC zone of the home address.

- **Name:** ``site_iecc_zone``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `1A`, `1B`, `1C`, `2A`, `2B`, `2C`, `3A`, `3B`, `3C`, `4A`, `4B`, `4C`, `5A`, `5B`, `5C`, `6A`, `6B`, `6C`, `7`, `8`

<br/>

**Site: City**

City/municipality of the home address.

- **Name:** ``site_city``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Site: State Code**

State code of the home address. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-site'>HPXML Site</a>) is used.

- **Name:** ``site_state_code``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `AK`, `AL`, `AR`, `AZ`, `CA`, `CO`, `CT`, `DC`, `DE`, `FL`, `GA`, `HI`, `IA`, `ID`, `IL`, `IN`, `KS`, `KY`, `LA`, `MA`, `MD`, `ME`, `MI`, `MN`, `MO`, `MS`, `MT`, `NC`, `ND`, `NE`, `NH`, `NJ`, `NM`, `NV`, `NY`, `OH`, `OK`, `OR`, `PA`, `RI`, `SC`, `SD`, `TN`, `TX`, `UT`, `VA`, `VT`, `WA`, `WI`, `WV`, `WY`

<br/>

**Site: Zip Code**

Zip code of the home address. Either this or the Weather Station: EnergyPlus Weather (EPW) Filepath input below must be provided.

- **Name:** ``site_zip_code``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Site: Time Zone UTC Offset**

Time zone UTC offset of the home address. Must be between -12 and 14. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-site'>HPXML Site</a>) is used.

- **Name:** ``site_time_zone_utc_offset``
- **Type:** ``Double``

- **Units:** ``hr``

- **Required:** ``false``

<br/>

**Site: Elevation**

Elevation of the home address. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-site'>HPXML Site</a>) is used.

- **Name:** ``site_elevation``
- **Type:** ``Double``

- **Units:** ``ft``

- **Required:** ``false``

<br/>

**Site: Latitude**

Latitude of the home address. Must be between -90 and 90. Use negative values for southern hemisphere. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-site'>HPXML Site</a>) is used.

- **Name:** ``site_latitude``
- **Type:** ``Double``

- **Units:** ``deg``

- **Required:** ``false``

<br/>

**Site: Longitude**

Longitude of the home address. Must be between -180 and 180. Use negative values for the western hemisphere. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-site'>HPXML Site</a>) is used.

- **Name:** ``site_longitude``
- **Type:** ``Double``

- **Units:** ``deg``

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

**Geometry: Garage Width**

The width of the garage. Enter zero for no garage. Only applies to single-family detached units.

- **Name:** ``geometry_garage_width``
- **Type:** ``Double``

- **Units:** ``ft``

- **Required:** ``true``

<br/>

**Geometry: Garage Depth**

The depth of the garage. Only applies to single-family detached units.

- **Name:** ``geometry_garage_depth``
- **Type:** ``Double``

- **Units:** ``ft``

- **Required:** ``true``

<br/>

**Geometry: Garage Protrusion**

The fraction of the garage that is protruding from the conditioned space. Only applies to single-family detached units.

- **Name:** ``geometry_garage_protrusion``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**Geometry: Garage Position**

The position of the garage. Only applies to single-family detached units.

- **Name:** ``geometry_garage_position``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `Right`, `Left`

<br/>

**Geometry: Foundation Type**

The foundation type of the building. Foundation types ConditionedBasement and ConditionedCrawlspace are not allowed for apartment units.

- **Name:** ``geometry_foundation_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `SlabOnGrade`, `VentedCrawlspace`, `UnventedCrawlspace`, `ConditionedCrawlspace`, `UnconditionedBasement`, `ConditionedBasement`, `Ambient`, `AboveApartment`, `BellyAndWingWithSkirt`, `BellyAndWingNoSkirt`

<br/>

**Geometry: Foundation Height**

The height of the foundation (e.g., 3ft for crawlspace, 8ft for basement). Only applies to basements/crawlspaces.

- **Name:** ``geometry_foundation_height``
- **Type:** ``Double``

- **Units:** ``ft``

- **Required:** ``true``

<br/>

**Geometry: Foundation Height Above Grade**

The depth above grade of the foundation wall. Only applies to basements/crawlspaces.

- **Name:** ``geometry_foundation_height_above_grade``
- **Type:** ``Double``

- **Units:** ``ft``

- **Required:** ``true``

<br/>

**Geometry: Rim Joist Height**

The height of the rim joists. Only applies to basements/crawlspaces.

- **Name:** ``geometry_rim_joist_height``
- **Type:** ``Double``

- **Units:** ``in``

- **Required:** ``false``

<br/>

**Geometry: Attic Type**

The attic type of the building. Attic type ConditionedAttic is not allowed for apartment units.

- **Name:** ``geometry_attic_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `FlatRoof`, `VentedAttic`, `UnventedAttic`, `ConditionedAttic`, `BelowApartment`

<br/>

**Geometry: Roof Type**

The roof type of the building. Ignored if the building has a flat roof.

- **Name:** ``geometry_roof_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `gable`, `hip`

<br/>

**Geometry: Roof Pitch**

The roof pitch of the attic. Ignored if the building has a flat roof.

- **Name:** ``geometry_roof_pitch``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `1:12`, `2:12`, `3:12`, `4:12`, `5:12`, `6:12`, `7:12`, `8:12`, `9:12`, `10:12`, `11:12`, `12:12`

<br/>

**Geometry: Eaves Depth**

The eaves depth of the roof.

- **Name:** ``geometry_eaves_depth``
- **Type:** ``Double``

- **Units:** ``ft``

- **Required:** ``true``

<br/>

**Geometry: Neighbor Buildings**

The presence and geometry of neighboring buildings, for shading purposes.

- **Name:** ``geometry_neighbor_buildings``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Left/Right at 5ft`, `Left/Right at 10ft`, `Left/Right at 15ft`, `Left/Right at 20ft`, `Left/Right at 25ft`, `Left at 5ft`, `Left at 10ft`, `Left at 15ft`, `Left at 20ft`, `Left at 25ft`, `Right at 5ft`, `Right at 10ft`, `Right at 15ft`, `Right at 20ft`, `Right at 25ft`, `Detailed Example: Left/Right at 25ft, Front/Back at 80ft, 12ft Height`

<br/>

**Floor: Over Foundation Assembly R-value**

Assembly R-value for the floor over the foundation. Ignored if the building has a slab-on-grade foundation.

- **Name:** ``floor_over_foundation_assembly_r``
- **Type:** ``Double``

- **Units:** ``F-ft2-hr/Btu``

- **Required:** ``true``

<br/>

**Floor: Over Garage Assembly R-value**

Assembly R-value for the floor over the garage. Ignored unless the building has a garage under conditioned space.

- **Name:** ``floor_over_garage_assembly_r``
- **Type:** ``Double``

- **Units:** ``F-ft2-hr/Btu``

- **Required:** ``true``

<br/>

**Floor: Type**

The type of floors.

- **Name:** ``floor_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `WoodFrame`, `StructuralInsulatedPanel`, `SolidConcrete`, `SteelFrame`

<br/>

**Enclosure: Foundation Wall**

The type of foundation wall.

- **Name:** ``enclosure_foundation_wall``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `Solid Concrete, Uninsulated`, `Solid Concrete, Half Wall, R-5`, `Solid Concrete, Half Wall, R-10`, `Solid Concrete, Half Wall, R-15`, `Solid Concrete, Half Wall, R-20`, `Solid Concrete, Whole Wall, R-5`, `Solid Concrete, Whole Wall, R-10`, `Solid Concrete, Whole Wall, R-10.2, Interior`, `Solid Concrete, Whole Wall, R-15`, `Solid Concrete, Whole Wall, R-20`, `Solid Concrete, Assembly R-10.69`, `Concrete Block Foam Core, Whole Wall, R-18.9`

<br/>

**Rim Joist: Assembly R-value**

Assembly R-value for the rim joists. Only applies to basements/crawlspaces. Required if a rim joist height is provided.

- **Name:** ``rim_joist_assembly_r``
- **Type:** ``Double``

- **Units:** ``F-ft2-hr/Btu``

- **Required:** ``false``

<br/>

**Enclosure: Slab**

The type of slab. Applies to slab-on-grade and basement/crawlspace foundations. Under Slab insulation is placed horizontally from the edge of the slab inward. Perimeter insulation is placed vertically from the top of the slab downward. Whole Slab insulation is placed horizontally below the entire slab area.

- **Name:** ``enclosure_slab``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Uninsulated`, `Under Slab, 2ft, R-5`, `Under Slab, 2ft, R-10`, `Under Slab, 2ft, R-15`, `Under Slab, 2ft, R-20`, `Under Slab, 4ft, R-5`, `Under Slab, 4ft, R-10`, `Under Slab, 4ft, R-15`, `Under Slab, 4ft, R-20`, `Perimeter, 2ft, R-5`, `Perimeter, 2ft, R-10`, `Perimeter, 2ft, R-15`, `Perimeter, 2ft, R-20`, `Perimeter, 4ft, R-5`, `Perimeter, 4ft, R-10`, `Perimeter, 4ft, R-15`, `Perimeter, 4ft, R-20`, `Whole Slab, R-5`, `Whole Slab, R-10`, `Whole Slab, R-15`, `Whole Slab, R-20`, `Whole Slab, R-30`, `Whole Slab, R-40`

<br/>

**Enclosure: Slab Carpet**

The amount of slab floor area that is carpeted.

- **Name:** ``enclosure_slab_carpet``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `0% Carpet`, `20% Carpet`, `40% Carpet`, `60% Carpet`, `80% Carpet`, `100% Carpet`, `100% Carpet, R-2.08`, `100% Carpet, R-2.5`

<br/>

**Ceiling: Assembly R-value**

Assembly R-value for the ceiling (attic floor).

- **Name:** ``ceiling_assembly_r``
- **Type:** ``Double``

- **Units:** ``F-ft2-hr/Btu``

- **Required:** ``true``

<br/>

**Enclosure: Roof Material**

The material type/color of the roof. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-roofs'>HPXML Roofs</a>) is used.

- **Name:** ``enclosure_roof_material``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Asphalt/Fiberglass Shingles, Dark`, `Asphalt/Fiberglass Shingles, Medium Dark`, `Asphalt/Fiberglass Shingles, Medium`, `Asphalt/Fiberglass Shingles, Light`, `Asphalt/Fiberglass Shingles, Reflective`, `Tile/Slate, Dark`, `Tile/Slate, Medium Dark`, `Tile/Slate, Medium`, `Tile/Slate, Light`, `Tile/Slate, Reflective`, `Metal, Dark`, `Metal, Medium Dark`, `Metal, Medium`, `Metal, Light`, `Metal, Reflective`, `Wood Shingles/Shakes, Dark`, `Wood Shingles/Shakes, Medium Dark`, `Wood Shingles/Shakes, Medium`, `Wood Shingles/Shakes, Light`, `Wood Shingles/Shakes, Reflective`, `Shingles, Dark`, `Shingles, Medium Dark`, `Shingles, Medium`, `Shingles, Light`, `Shingles, Reflective`, `Synthetic Sheeting, Dark`, `Synthetic Sheeting, Medium Dark`, `Synthetic Sheeting, Medium`, `Synthetic Sheeting, Light`, `Synthetic Sheeting, Reflective`, `EPS Sheathing, Dark`, `EPS Sheathing, Medium Dark`, `EPS Sheathing, Medium`, `EPS Sheathing, Light`, `EPS Sheathing, Reflective`, `Concrete, Dark`, `Concrete, Medium Dark`, `Concrete, Medium`, `Concrete, Light`, `Concrete, Reflective`, `Cool Roof`, `0.2 Solar Absorptance`, `0.4 Solar Absorptance`, `0.6 Solar Absorptance`, `0.75 Solar Absorptance`

<br/>

**Roof: Assembly R-value**

Assembly R-value of the roof.

- **Name:** ``roof_assembly_r``
- **Type:** ``Double``

- **Units:** ``F-ft2-hr/Btu``

- **Required:** ``true``

<br/>

**Attic: Radiant Barrier Location**

The location of the radiant barrier in the attic.

- **Name:** ``radiant_barrier_attic_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `none`, `Attic roof only`, `Attic roof and gable walls`, `Attic floor`

<br/>

**Attic: Radiant Barrier Grade**

The grade of the radiant barrier in the attic. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-roofs'>HPXML Roofs</a>) is used.

- **Name:** ``radiant_barrier_grade``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `1`, `2`, `3`

<br/>

**Wall: Type**

The type of walls.

- **Name:** ``wall_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `WoodStud`, `ConcreteMasonryUnit`, `DoubleWoodStud`, `InsulatedConcreteForms`, `LogWall`, `StructuralInsulatedPanel`, `SolidConcrete`, `SteelFrame`, `Stone`, `StrawBale`, `StructuralBrick`

<br/>

**Enclosure: Wall Siding**

The siding type/color of the walls. Also applies to rim joists. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-walls'>HPXML Walls</a>) is used.

- **Name:** ``enclosure_wall_siding``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `Aluminum, Dark`, `Aluminum, Medium`, `Aluminum, Medium Dark`, `Aluminum, Light`, `Aluminum, Reflective`, `Brick, Dark`, `Brick, Medium`, `Brick, Medium Dark`, `Brick, Light`, `Brick, Reflective`, `Fiber-Cement, Dark`, `Fiber-Cement, Medium`, `Fiber-Cement, Medium Dark`, `Fiber-Cement, Light`, `Fiber-Cement, Reflective`, `Asbestos, Dark`, `Asbestos, Medium`, `Asbestos, Medium Dark`, `Asbestos, Light`, `Asbestos, Reflective`, `Composition Shingle, Dark`, `Composition Shingle, Medium`, `Composition Shingle, Medium Dark`, `Composition Shingle, Light`, `Composition Shingle, Reflective`, `Stucco, Dark`, `Stucco, Medium`, `Stucco, Medium Dark`, `Stucco, Light`, `Stucco, Reflective`, `Vinyl, Dark`, `Vinyl, Medium`, `Vinyl, Medium Dark`, `Vinyl, Light`, `Vinyl, Reflective`, `Wood, Dark`, `Wood, Medium`, `Wood, Medium Dark`, `Wood, Light`, `Wood, Reflective`, `Synthetic Stucco, Dark`, `Synthetic Stucco, Medium`, `Synthetic Stucco, Medium Dark`, `Synthetic Stucco, Light`, `Synthetic Stucco, Reflective`, `Masonite, Dark`, `Masonite, Medium`, `Masonite, Medium Dark`, `Masonite, Light`, `Masonite, Reflective`, `0.2 Solar Absorptance`, `0.4 Solar Absorptance`, `0.6 Solar Absorptance`, `0.75 Solar Absorptance`

<br/>

**Wall: Assembly R-value**

Assembly R-value of the walls.

- **Name:** ``wall_assembly_r``
- **Type:** ``Double``

- **Units:** ``F-ft2-hr/Btu``

- **Required:** ``true``

<br/>

**Windows: Front Window Area or Window-to-Wall Ratio**

The amount of window area on the unit's front facade. Enter a fraction if specifying Front Window-to-Wall Ratio instead. If the front wall is adiabatic, the value will be ignored.

- **Name:** ``window_area_or_wwr_front``
- **Type:** ``Double``

- **Units:** ``ft2 or frac``

- **Required:** ``true``

<br/>

**Windows: Back Window Area or Window-to-Wall Ratio**

The amount of window area on the unit's back facade. Enter a fraction if specifying Back Window-to-Wall Ratio instead. If the back wall is adiabatic, the value will be ignored.

- **Name:** ``window_area_or_wwr_back``
- **Type:** ``Double``

- **Units:** ``ft2 or frac``

- **Required:** ``true``

<br/>

**Windows: Left Window Area or Window-to-Wall Ratio**

The amount of window area on the unit's left facade (when viewed from the front). Enter a fraction if specifying Left Window-to-Wall Ratio instead. If the left wall is adiabatic, the value will be ignored.

- **Name:** ``window_area_or_wwr_left``
- **Type:** ``Double``

- **Units:** ``ft2 or frac``

- **Required:** ``true``

<br/>

**Windows: Right Window Area or Window-to-Wall Ratio**

The amount of window area on the unit's right facade (when viewed from the front). Enter a fraction if specifying Right Window-to-Wall Ratio instead. If the right wall is adiabatic, the value will be ignored.

- **Name:** ``window_area_or_wwr_right``
- **Type:** ``Double``

- **Units:** ``ft2 or frac``

- **Required:** ``true``

<br/>

**Windows: Fraction Operable**

Fraction of windows that are operable. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-windows'>HPXML Windows</a>) is used.

- **Name:** ``window_fraction_operable``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``false``

<br/>

**Windows: Natural Ventilation Availability**

For operable windows, the number of days/week that windows can be opened by occupants for natural ventilation. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-windows'>HPXML Windows</a>) is used.

- **Name:** ``window_natvent_availability``
- **Type:** ``Integer``

- **Units:** ``Days/week``

- **Required:** ``false``

<br/>

**Windows: U-Factor**

Full-assembly NFRC U-factor.

- **Name:** ``window_ufactor``
- **Type:** ``Double``

- **Units:** ``Btu/hr-ft2-R``

- **Required:** ``true``

<br/>

**Windows: SHGC**

Full-assembly NFRC solar heat gain coefficient.

- **Name:** ``window_shgc``
- **Type:** ``Double``

- **Required:** ``true``

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

- **Name:** ``window_insect_screens``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `none`, `exterior`, `interior`

<br/>

**Enclosure: Window Storms**

The type of window storm, if present. If not provided, assumes there is no storm.

- **Name:** ``window_storm_type``
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

**Skylights: Front Roof Area**

The amount of skylight area on the unit's front conditioned roof facade.

- **Name:** ``skylight_area_front``
- **Type:** ``Double``

- **Units:** ``ft2``

- **Required:** ``true``

<br/>

**Skylights: Back Roof Area**

The amount of skylight area on the unit's back conditioned roof facade.

- **Name:** ``skylight_area_back``
- **Type:** ``Double``

- **Units:** ``ft2``

- **Required:** ``true``

<br/>

**Skylights: Left Roof Area**

The amount of skylight area on the unit's left conditioned roof facade (when viewed from the front).

- **Name:** ``skylight_area_left``
- **Type:** ``Double``

- **Units:** ``ft2``

- **Required:** ``true``

<br/>

**Skylights: Right Roof Area**

The amount of skylight area on the unit's right conditioned roof facade (when viewed from the front).

- **Name:** ``skylight_area_right``
- **Type:** ``Double``

- **Units:** ``ft2``

- **Required:** ``true``

<br/>

**Skylights: U-Factor**

Full-assembly NFRC U-factor.

- **Name:** ``skylight_ufactor``
- **Type:** ``Double``

- **Units:** ``Btu/hr-ft2-R``

- **Required:** ``true``

<br/>

**Skylights: SHGC**

Full-assembly NFRC solar heat gain coefficient.

- **Name:** ``skylight_shgc``
- **Type:** ``Double``

- **Required:** ``true``

<br/>

**Skylights: Storm Type**

The type of storm, if present. If not provided, assumes there is no storm.

- **Name:** ``skylight_storm_type``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `clear`, `low-e`

<br/>

**Doors: Area**

The area of the opaque door(s).

- **Name:** ``door_area``
- **Type:** ``Double``

- **Units:** ``ft2``

- **Required:** ``true``

<br/>

**Doors: R-value**

R-value of the opaque door(s).

- **Name:** ``door_rvalue``
- **Type:** ``Double``

- **Units:** ``F-ft2-hr/Btu``

- **Required:** ``true``

<br/>

**Enclosure: Air Leakage**

The amount of air leakage. When a leakiness description is used, the Year Built of the home is also required.

- **Name:** ``enclosure_air_leakage``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Very Tight`, `Tight`, `Average`, `Leaky`, `Very Leaky`, `0.25 ACH50`, `0.5 ACH50`, `0.75 ACH50`, `1 ACH50`, `1.5 ACH50`, `2 ACH50`, `2.25 ACH50`, `3 ACH50`, `3.75 ACH50`, `4 ACH50`, `4.5 ACH50`, `5 ACH50`, `5.25 ACH50`, `6 ACH50`, `7 ACH50`, `7.5 ACH50`, `8 ACH50`, `10 ACH50`, `11.25 ACH50`, `15 ACH50`, `18.5 ACH50`, `20 ACH50`, `25 ACH50`, `30 ACH50`, `40 ACH50`, `50 ACH50`, `2.8 ACH45`, `0.2 nACH`, `0.335 nACH`, `0.67 nACH`, `1.5 nACH`, `Detailed Example: 3.57 ACH50`, `Detailed Example: 12.16 ACH50`, `Detailed Example: 0.375 nACH`, `Detailed Example: 72 nCFM`, `Detailed Example: 79.8 sq. in. ELA`, `Detailed Example: 123 sq. in. ELA`, `Detailed Example: 1080 CFM50`, `Detailed Example: 1010 CFM45`

<br/>

**Air Leakage: Type**

Type of air leakage if providing a numeric air leakage value. If 'unit total', represents the total infiltration to the unit as measured by a compartmentalization test, in which case the air leakage value will be adjusted by the ratio of exterior envelope surface area to total envelope surface area. Otherwise, if 'unit exterior only', represents the infiltration to the unit from outside only as measured by a guarded test. Required when unit type is single-family attached or apartment unit.

- **Name:** ``air_leakage_type``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `unit total`, `unit exterior only`

<br/>

**Air Leakage: Has Flue or Chimney in Conditioned Space**

Presence of flue or chimney with combustion air from conditioned space; used for infiltration model. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#flue-or-chimney'>Flue or Chimney</a>) is used.

- **Name:** ``air_leakage_has_flue_or_chimney_in_conditioned_space``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**HVAC: Heating System**

The heating system type/efficiency. Use 'None' if there is no heating system or if there is a heat pump serving a heating load.

- **Name:** ``hvac_heating_system``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Electric Resistance`, `Central Furnace, 60% AFUE`, `Central Furnace, 64% AFUE`, `Central Furnace, 68% AFUE`, `Central Furnace, 72% AFUE`, `Central Furnace, 76% AFUE`, `Central Furnace, 78% AFUE`, `Central Furnace, 80% AFUE`, `Central Furnace, 85% AFUE`, `Central Furnace, 90% AFUE`, `Central Furnace, 92% AFUE`, `Central Furnace, 92.5% AFUE`, `Central Furnace, 96% AFUE`, `Central Furnace, 98% AFUE`, `Central Furnace, 100% AFUE`, `Wall Furnace, 60% AFUE`, `Wall Furnace, 68% AFUE`, `Wall Furnace, 82% AFUE`, `Wall Furnace, 98% AFUE`, `Wall Furnace, 100% AFUE`, `Floor Furnace, 60% AFUE`, `Floor Furnace, 70% AFUE`, `Floor Furnace, 80% AFUE`, `Boiler, 60% AFUE`, `Boiler, 72% AFUE`, `Boiler, 76% AFUE`, `Boiler, 80% AFUE`, `Boiler, 82% AFUE`, `Boiler, 85% AFUE`, `Boiler, 90% AFUE`, `Boiler, 92% AFUE`, `Boiler, 92.5% AFUE`, `Boiler, 95% AFUE`, `Boiler, 96% AFUE`, `Boiler, 98% AFUE`, `Boiler, 100% AFUE`, `Shared Boiler w/ Baseboard, 78% AFUE`, `Shared Boiler w/ Baseboard, 92% AFUE`, `Shared Boiler w/ Baseboard, 100% AFUE`, `Shared Boiler w/ Fan Coil, 78% AFUE`, `Shared Boiler w/ Fan Coil, 92% AFUE`, `Shared Boiler w/ Fan Coil, 100% AFUE`, `Stove, 60% Efficiency`, `Stove, 70% Efficiency`, `Stove, 80% Efficiency`, `Space Heater, 60% Efficiency`, `Space Heater, 70% Efficiency`, `Space Heater, 80% Efficiency`, `Space Heater, 92% Efficiency`, `Space Heater, 100% Efficiency`, `Fireplace, 60% Efficiency`, `Fireplace, 70% Efficiency`, `Fireplace, 80% Efficiency`, `Fireplace, 100% Efficiency`, `Detailed Example: Central Furnace, 92% AFUE, 600 Btu/hr Pilot Light`, `Detailed Example: Floor Furnace, 80% AFUE, 600 Btu/hr Pilot Light`, `Detailed Example: Boiler, 92% AFUE, 600 Btu/hr Pilot Light`

<br/>

**HVAC: Heating System Fuel Type**

The fuel type of the heating system. Ignored for ElectricResistance.

- **Name:** ``heating_system_fuel``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `electricity`, `natural gas`, `fuel oil`, `propane`, `wood`, `wood pellets`, `coal`

<br/>

**HVAC: Heating System Capacity**

The output capacity of the heating system.

- **Name:** ``hvac_capacity_heating_system``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Autosize`, `5 kBtu/hr`, `10 kBtu/hr`, `15 kBtu/hr`, `20 kBtu/hr`, `25 kBtu/hr`, `30 kBtu/hr`, `35 kBtu/hr`, `40 kBtu/hr`, `45 kBtu/hr`, `50 kBtu/hr`, `55 kBtu/hr`, `60 kBtu/hr`, `65 kBtu/hr`, `70 kBtu/hr`, `75 kBtu/hr`, `80 kBtu/hr`, `85 kBtu/hr`, `90 kBtu/hr`, `95 kBtu/hr`, `100 kBtu/hr`, `105 kBtu/hr`, `110 kBtu/hr`, `115 kBtu/hr`, `120 kBtu/hr`, `125 kBtu/hr`, `130 kBtu/hr`, `135 kBtu/hr`, `140 kBtu/hr`, `145 kBtu/hr`, `150 kBtu/hr`, `Detailed Example: Autosize, 140% Multiplier`, `Detailed Example: Autosize, 170% Multiplier`, `Detailed Example: Autosize, 140% Multiplier, 45 kBtu/hr Limit`

<br/>

**HVAC: Heating System Fraction Heat Load Served**

The heating load served by the heating system.

- **Name:** ``heating_system_fraction_heat_load_served``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**HVAC: Cooling System**

The cooling system type/efficiency. Use 'None' if there is no cooling system or if there is a heat pump serving a cooling load.

- **Name:** ``hvac_cooling_system``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Central AC, SEER 8`, `Central AC, SEER 10`, `Central AC, SEER 13`, `Central AC, SEER 14`, `Central AC, SEER 15`, `Central AC, SEER 16`, `Central AC, SEER 17`, `Central AC, SEER 18`, `Central AC, SEER 21`, `Central AC, SEER 24`, `Central AC, SEER 24.5`, `Central AC, SEER 27`, `Central AC, SEER2 12.4`, `Mini-Split AC, SEER 13`, `Mini-Split AC, SEER 17`, `Mini-Split AC, SEER 19`, `Mini-Split AC, SEER 19, Ducted`, `Mini-Split AC, SEER 24`, `Mini-Split AC, SEER 25`, `Mini-Split AC, SEER 29.3`, `Mini-Split AC, SEER 33`, `Room AC, EER 8.5`, `Room AC, EER 8.5, Electric Resistance Heating`, `Room AC, EER 9.8`, `Room AC, EER 10.7`, `Room AC, EER 12.0`, `Room AC, CEER 8.4`, `Packaged Terminal AC, EER 10.7`, `Packaged Terminal AC, EER 10.7, Electric Resistance Heating`, `Packaged Terminal AC, EER 10.7, 80% AFUE Gas Heating`, `Evaporative Cooler`, `Evaporative Cooler, Ducted`, `Detailed Example: Central AC, SEER 13, Absolute Detailed Performance`, `Detailed Example: Central AC, SEER 18, Absolute Detailed Performance`, `Detailed Example: Central AC, SEER 17.5, Absolute Detailed Performance`, `Detailed Example: Central AC, SEER 17.5, Normalized Detailed Performance`, `Detailed Example: Mini-Split AC, SEER 17, Absolute Detailed Performance`, `Detailed Example: Mini-Split AC, SEER 17, Normalized Detailed Performance`

<br/>

**HVAC: Cooling System Capacity**

The output capacity of the cooling system.

- **Name:** ``hvac_capacity_cooling_system``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Autosize`, `0.5 tons`, `0.75 tons`, `1.0 tons`, `1.5 tons`, `2.0 tons`, `2.5 tons`, `3.0 tons`, `3.5 tons`, `4.0 tons`, `4.5 tons`, `5.0 tons`, `5.5 tons`, `6.0 tons`, `6.5 tons`, `7.0 tons`, `7.5 tons`, `8.0 tons`, `8.5 tons`, `9.0 tons`, `9.5 tons`, `10.0 tons`, `Detailed Example: Autosize, 140% Multiplier`, `Detailed Example: Autosize, 170% Multiplier`, `Detailed Example: Autosize, 170% Multiplier, 3.0 tons Limit`

<br/>

**HVAC: Cooling System Fraction Cool Load Served**

The cooling load served by the cooling system.

- **Name:** ``cooling_system_fraction_cool_load_served``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**HVAC: Cooling System Integrated Heating Capacity**

The output capacity of the cooling system's integrated heating system. Only used for packaged terminal air conditioner and room air conditioner systems with integrated heating.

- **Name:** ``hvac_capacity_cooling_system_integrated_heating``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Autosize`, `5 kBtu/hr`, `10 kBtu/hr`, `15 kBtu/hr`, `20 kBtu/hr`, `25 kBtu/hr`, `30 kBtu/hr`, `35 kBtu/hr`, `40 kBtu/hr`, `45 kBtu/hr`, `50 kBtu/hr`, `55 kBtu/hr`, `60 kBtu/hr`, `65 kBtu/hr`, `70 kBtu/hr`, `75 kBtu/hr`, `80 kBtu/hr`, `85 kBtu/hr`, `90 kBtu/hr`, `95 kBtu/hr`, `100 kBtu/hr`, `105 kBtu/hr`, `110 kBtu/hr`, `115 kBtu/hr`, `120 kBtu/hr`, `125 kBtu/hr`, `130 kBtu/hr`, `135 kBtu/hr`, `140 kBtu/hr`, `145 kBtu/hr`, `150 kBtu/hr`

<br/>

**HVAC: Cooling System Integrated Heating Fraction Heat Load Served**

The heating load served by the heating system integrated into cooling system. Only used for packaged terminal air conditioner and room air conditioner systems with integrated heating.

- **Name:** ``cooling_system_integrated_heating_system_fraction_heat_load_served``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``false``

<br/>

**HVAC: Heat Pump**

The heat pump type/efficiency.

- **Name:** ``hvac_heat_pump``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Central HP, SEER 8, 6.0 HSPF`, `Central HP, SEER 10, 6.2 HSPF`, `Central HP, SEER 10, 6.8 HSPF`, `Central HP, SEER 10.3, 7.0 HSPF`, `Central HP, SEER 11.5, 7.5 HSPF`, `Central HP, SEER 13, 7.7 HSPF`, `Central HP, SEER 13, 8.0 HSPF`, `Central HP, SEER 13, 9.85 HSPF`, `Central HP, SEER 14, 8.2 HSPF`, `Central HP, SEER 14.3, 8.5 HSPF`, `Central HP, SEER 15, 8.5 HSPF`, `Central HP, SEER 15, 9.0 HSPF`, `Central HP, SEER 16, 9.0 HSPF`, `Central HP, SEER 17, 8.7 HSPF`, `Central HP, SEER 18, 9.3 HSPF`, `Central HP, SEER 20, 11 HSPF`, `Central HP, SEER 22, 10 HSPF`, `Central HP, SEER 24, 13 HSPF`, `Mini-Split HP, SEER 14.5, 8.2 HSPF`, `Mini-Split HP, SEER 14.5, 8.2 HSPF, Ducted`, `Mini-Split HP, SEER 16, 9.2 HSPF`, `Mini-Split HP, SEER 17, 9.5 HSPF`, `Mini-Split HP, SEER 17, 9.5 HSPF, Ducted`, `Mini-Split HP, SEER 18.0, 9.6 HSPF`, `Mini-Split HP, SEER 18.0, 9.6 HSPF, Ducted`, `Mini-Split HP, SEER 19, 10 HSPF, Ducted`, `Mini-Split HP, SEER 19, 10 HSPF`, `Mini-Split HP, SEER 20, 11 HSPF`, `Mini-Split HP, SEER 24, 13 HSPF`, `Mini-Split HP, SEER 25, 12.7 HSPF`, `Mini-Split HP, SEER 25, 12.7 HSPF, Ducted`, `Mini-Split HP, SEER 29.3, 14 HSPF`, `Mini-Split HP, SEER 29.3, 14 HSPF, Ducted`, `Mini-Split HP, SEER 33, 13.3 HSPF`, `Mini-Split HP, SEER 33, 13.3 HSPF, Ducted`, `Geothermal HP, EER 16.6, COP 3.6`, `Geothermal HP, EER 18.2, COP 3.7`, `Geothermal HP, EER 19.4, COP 3.8`, `Geothermal HP, EER 20.2, COP 4.2`, `Geothermal HP, EER 20.5, COP 4.0`, `Geothermal HP, EER 30.9, COP 4.4`, `Packaged Terminal HP, EER 11.4, COP 3.6`, `Room AC w/ Reverse Cycle, EER 11.4, COP 3.6`, `Detailed Example: Central HP, SEER2 12.4, HSPF2 6.5`, `Detailed Example: Central HP, SEER 13, 7.7 HSPF, Absolute Detailed Performance`, `Detailed Example: Central HP, SEER 18, 9.3 HSPF, Absolute Detailed Performance`, `Detailed Example: Central HP, SEER 17.5, 9.5 HSPF, Absolute Detailed Performance`, `Detailed Example: Central HP, SEER 17.5, 9.5 HSPF, Normalized Detailed Performance`, `Detailed Example: Mini-Split HP, SEER 16.7, 11.3 HSPF, Absolute Detailed Performance`, `Detailed Example: Mini-Split HP, SEER 16.7, 11.3 HSPF, Normalized Detailed Performance`, `Detailed Example: Mini-Split HP, SEER 17, 10 HSPF, Absolute Detailed Performance`, `Detailed Example: Mini-Split HP, SEER 17, 10 HSPF, Normalized Detailed Performance`

<br/>

**HVAC: Heat Pump Capacity**

The output capacity of the heat pump.

- **Name:** ``hvac_capacity_heat_pump``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Autosize`, `0.5 tons`, `0.75 tons`, `1.0 tons`, `1.5 tons`, `2.0 tons`, `2.5 tons`, `3.0 tons`, `3.5 tons`, `4.0 tons`, `4.5 tons`, `5.0 tons`, `5.5 tons`, `6.0 tons`, `6.5 tons`, `7.0 tons`, `7.5 tons`, `8.0 tons`, `8.5 tons`, `9.0 tons`, `9.5 tons`, `10.0 tons`, `Detailed Example: Autosize, 140% Multiplier`, `Detailed Example: Autosize, 170% Multiplier`, `Detailed Example: Autosize, 170% Multiplier, 3.0 tons Limit`

<br/>

**Heat Pump: Fraction Heat Load Served**

The heating load served by the heat pump.

- **Name:** ``heat_pump_fraction_heat_load_served``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**Heat Pump: Fraction Cool Load Served**

The cooling load served by the heat pump.

- **Name:** ``heat_pump_fraction_cool_load_served``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**HVAC: Heat Pump Backup Type**

The heat pump backup type/efficiency. Use 'None' if there is no backup heating. If Backup Type is Separate Heating System, Heating System 2 is used to specify the backup.

- **Name:** ``hvac_heat_pump_backup``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Integrated, Electricity, 100% Efficiency`, `Integrated, Natural Gas, 60% AFUE`, `Integrated, Natural Gas, 76% AFUE`, `Integrated, Natural Gas, 80% AFUE`, `Integrated, Natural Gas, 92.5% AFUE`, `Integrated, Natural Gas, 95% AFUE`, `Integrated, Fuel Oil, 60% AFUE`, `Integrated, Fuel Oil, 76% AFUE`, `Integrated, Fuel Oil, 80% AFUE`, `Integrated, Fuel Oil, 92.5% AFUE`, `Integrated, Fuel Oil, 95% AFUE`, `Integrated, Propane, 60% AFUE`, `Integrated, Propane, 76% AFUE`, `Integrated, Propane, 80% AFUE`, `Integrated, Propane, 92.5% AFUE`, `Integrated, Propane, 95% AFUE`, `Separate Heating System`

<br/>

**HVAC: Heat Pump Backup Capacity**

The output capacity of the heat pump backup if there is integrated backup heating.

- **Name:** ``hvac_capacity_heat_pump_backup``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Autosize`, `5 kW`, `10 kW`, `15 kW`, `20 kW`, `25 kW`, `5 kBtu/hr`, `10 kBtu/hr`, `15 kBtu/hr`, `20 kBtu/hr`, `25 kBtu/hr`, `30 kBtu/hr`, `35 kBtu/hr`, `40 kBtu/hr`, `45 kBtu/hr`, `50 kBtu/hr`, `55 kBtu/hr`, `60 kBtu/hr`, `65 kBtu/hr`, `70 kBtu/hr`, `75 kBtu/hr`, `80 kBtu/hr`, `85 kBtu/hr`, `90 kBtu/hr`, `95 kBtu/hr`, `100 kBtu/hr`, `105 kBtu/hr`, `110 kBtu/hr`, `115 kBtu/hr`, `120 kBtu/hr`, `125 kBtu/hr`, `130 kBtu/hr`, `135 kBtu/hr`, `140 kBtu/hr`, `145 kBtu/hr`, `150 kBtu/hr`, `Detailed Example: Autosize, 140% Multiplier`, `Detailed Example: Autosize, 170% Multiplier`, `Detailed Example: Autosize, 90% Multiplier, 45 kBtu/hr Limit`

<br/>

**HVAC: Heat Pump Temperatures**

Specifies the minimum compressor temperature and/or maximum HP backup temperature. If both are the same, a binary switchover temperature is used.

- **Name:** ``hvac_heat_pump_temps``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Default`, `-20F Min Compressor Temp`, `-15F Min Compressor Temp`, `-10F Min Compressor Temp`, `-5F Min Compressor Temp`, `0F Min Compressor Temp`, `5F Min Compressor Temp`, `10F Min Compressor Temp`, `15F Min Compressor Temp`, `20F Min Compressor Temp`, `25F Min Compressor Temp`, `30F Min Compressor Temp`, `35F Min Compressor Temp`, `40F Min Compressor Temp`, `30F Min Compressor Temp, 30F Max HP Backup Temp`, `35F Min Compressor Temp, 35F Max HP Backup Temp`, `40F Min Compressor Temp, 40F Max HP Backup Temp`, `Detailed Example: 5F Min Compressor Temp, 35F Max HP Backup Temp`, `Detailed Example: 25F Min Compressor Temp, 45F Max HP Backup Temp`

<br/>

**Heat Pump: Sizing Methodology**

The auto-sizing methodology to use when the heat pump capacity is not provided. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-hvac-sizing-control'>HPXML HVAC Sizing Control</a>) is used.

- **Name:** ``heat_pump_sizing_methodology``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `ACCA`, `HERS`, `MaxLoad`

<br/>

**Heat Pump: Backup Sizing Methodology**

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

The type/efficiency of the second heating system. If a heat pump is specified and the backup type is 'separate', this heating system represents the 'separate' backup heating.

- **Name:** ``hvac_heating_system_2``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Electric Resistance`, `Central Furnace, 60% AFUE`, `Central Furnace, 64% AFUE`, `Central Furnace, 68% AFUE`, `Central Furnace, 72% AFUE`, `Central Furnace, 76% AFUE`, `Central Furnace, 78% AFUE`, `Central Furnace, 80% AFUE`, `Central Furnace, 85% AFUE`, `Central Furnace, 90% AFUE`, `Central Furnace, 92% AFUE`, `Central Furnace, 92.5% AFUE`, `Central Furnace, 96% AFUE`, `Central Furnace, 98% AFUE`, `Central Furnace, 100% AFUE`, `Wall Furnace, 60% AFUE`, `Wall Furnace, 68% AFUE`, `Wall Furnace, 82% AFUE`, `Wall Furnace, 98% AFUE`, `Wall Furnace, 100% AFUE`, `Floor Furnace, 60% AFUE`, `Floor Furnace, 70% AFUE`, `Floor Furnace, 80% AFUE`, `Boiler, 60% AFUE`, `Boiler, 72% AFUE`, `Boiler, 76% AFUE`, `Boiler, 80% AFUE`, `Boiler, 82% AFUE`, `Boiler, 85% AFUE`, `Boiler, 90% AFUE`, `Boiler, 92% AFUE`, `Boiler, 92.5% AFUE`, `Boiler, 95% AFUE`, `Boiler, 96% AFUE`, `Boiler, 98% AFUE`, `Boiler, 100% AFUE`, `Shared Boiler w/ Baseboard, 78% AFUE`, `Shared Boiler w/ Baseboard, 92% AFUE`, `Shared Boiler w/ Baseboard, 100% AFUE`, `Shared Boiler w/ Fan Coil, 78% AFUE`, `Shared Boiler w/ Fan Coil, 92% AFUE`, `Shared Boiler w/ Fan Coil, 100% AFUE`, `Stove, 60% Efficiency`, `Stove, 70% Efficiency`, `Stove, 80% Efficiency`, `Space Heater, 60% Efficiency`, `Space Heater, 70% Efficiency`, `Space Heater, 80% Efficiency`, `Space Heater, 92% Efficiency`, `Space Heater, 100% Efficiency`, `Fireplace, 60% Efficiency`, `Fireplace, 70% Efficiency`, `Fireplace, 80% Efficiency`, `Fireplace, 100% Efficiency`, `Detailed Example: Central Furnace, 92% AFUE, 600 Btu/hr Pilot Light`, `Detailed Example: Floor Furnace, 80% AFUE, 600 Btu/hr Pilot Light`, `Detailed Example: Boiler, 92% AFUE, 600 Btu/hr Pilot Light`

<br/>

**Heating System 2: Fuel Type**

The fuel type of the second heating system. Ignored for ElectricResistance.

- **Name:** ``heating_system_2_fuel``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `electricity`, `natural gas`, `fuel oil`, `propane`, `wood`, `wood pellets`, `coal`

<br/>

**HVAC: Heating System 2 Capacity**

The output capacity of the second heating system.

- **Name:** ``hvac_capacity_heating_system_2``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `Autosize`, `5 kBtu/hr`, `10 kBtu/hr`, `15 kBtu/hr`, `20 kBtu/hr`, `25 kBtu/hr`, `30 kBtu/hr`, `35 kBtu/hr`, `40 kBtu/hr`, `45 kBtu/hr`, `50 kBtu/hr`, `55 kBtu/hr`, `60 kBtu/hr`, `65 kBtu/hr`, `70 kBtu/hr`, `75 kBtu/hr`, `80 kBtu/hr`, `85 kBtu/hr`, `90 kBtu/hr`, `95 kBtu/hr`, `100 kBtu/hr`, `105 kBtu/hr`, `110 kBtu/hr`, `115 kBtu/hr`, `120 kBtu/hr`, `125 kBtu/hr`, `130 kBtu/hr`, `135 kBtu/hr`, `140 kBtu/hr`, `145 kBtu/hr`, `150 kBtu/hr`, `Detailed Example: Autosize, 140% Multiplier`, `Detailed Example: Autosize, 170% Multiplier`, `Detailed Example: Autosize, 90% Multiplier, 45 kBtu/hr Limit`

<br/>

**Heating System 2: Fraction Heat Load Served**

The heat load served fraction of the second heating system. Ignored if this heating system serves as a backup system for a heat pump.

- **Name:** ``heating_system_2_fraction_heat_load_served``
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

- **Name:** ``hvac_install_defects``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `35% Airflow Defect`, `25% Airflow Defect`, `15% Airflow Defect`, `35% Under Charge`, `25% Under Charge`, `15% Under Charge`, `15% Over Charge`, `25% Over Charge`, `35% Over Charge`, `35% Airflow Defect, 35% Under Charge`, `35% Airflow Defect, 25% Under Charge`, `35% Airflow Defect, 15% Under Charge`, `35% Airflow Defect, 15% Over Charge`, `35% Airflow Defect, 25% Over Charge`, `35% Airflow Defect, 35% Over Charge`, `25% Airflow Defect, 35% Under Charge`, `25% Airflow Defect, 25% Under Charge`, `25% Airflow Defect, 15% Under Charge`, `25% Airflow Defect, 15% Over Charge`, `25% Airflow Defect, 25% Over Charge`, `25% Airflow Defect, 35% Over Charge`, `15% Airflow Defect, 35% Under Charge`, `15% Airflow Defect, 25% Under Charge`, `15% Airflow Defect, 15% Under Charge`, `15% Airflow Defect, 15% Over Charge`, `15% Airflow Defect, 25% Over Charge`, `15% Airflow Defect, 35% Over Charge`

<br/>

**HVAC: Ducts**

The supply duct leakage to outside, nominal insulation r-value, buried insulation level, surface area, and fraction rectangular.

- **Name:** ``hvac_ducts``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `0% Leakage, Uninsulated`, `0% Leakage, R-4`, `0% Leakage, R-6`, `0% Leakage, R-8`, `5% Leakage, Uninsulated`, `5% Leakage, R-4`, `5% Leakage, R-6`, `5% Leakage, R-8`, `10% Leakage, Uninsulated`, `10% Leakage, R-4`, `10% Leakage, R-6`, `10% Leakage, R-8`, `15% Leakage, Uninsulated`, `15% Leakage, R-4`, `15% Leakage, R-6`, `15% Leakage, R-8`, `20% Leakage, Uninsulated`, `20% Leakage, R-4`, `20% Leakage, R-6`, `20% Leakage, R-8`, `25% Leakage, Uninsulated`, `25% Leakage, R-4`, `25% Leakage, R-6`, `25% Leakage, R-8`, `30% Leakage, Uninsulated`, `30% Leakage, R-4`, `30% Leakage, R-6`, `30% Leakage, R-8`, `35% Leakage, Uninsulated`, `35% Leakage, R-4`, `35% Leakage, R-6`, `35% Leakage, R-8`, `0 CFM25 per 100ft2, Uninsulated`, `0 CFM25 per 100ft2, R-4`, `0 CFM25 per 100ft2, R-6`, `0 CFM25 per 100ft2, R-8`, `1 CFM25 per 100ft2, Uninsulated`, `1 CFM25 per 100ft2, R-4`, `1 CFM25 per 100ft2, R-6`, `1 CFM25 per 100ft2, R-8`, `2 CFM25 per 100ft2, Uninsulated`, `2 CFM25 per 100ft2, R-4`, `2 CFM25 per 100ft2, R-6`, `2 CFM25 per 100ft2, R-8`, `4 CFM25 per 100ft2, Uninsulated`, `4 CFM25 per 100ft2, R-4`, `4 CFM25 per 100ft2, R-6`, `4 CFM25 per 100ft2, R-8`, `6 CFM25 per 100ft2, Uninsulated`, `6 CFM25 per 100ft2, R-4`, `6 CFM25 per 100ft2, R-6`, `6 CFM25 per 100ft2, R-8`, `8 CFM25 per 100ft2, Uninsulated`, `8 CFM25 per 100ft2, R-4`, `8 CFM25 per 100ft2, R-6`, `8 CFM25 per 100ft2, R-8`, `12 CFM25 per 100ft2, Uninsulated`, `12 CFM25 per 100ft2, R-4`, `12 CFM25 per 100ft2, R-6`, `12 CFM25 per 100ft2, R-8`, `Detailed Example: 4 CFM25 per 100ft2, R-4, Deeply Buried`, `Detailed Example: 4 CFM25 per 100ft2, R-4, 100% Round`, `Detailed Example: 4 CFM25 per 100ft2, R-4, 100% Rectangular`, `Detailed Example: 5 CFM50 per 100ft2, R-4`, `Detailed Example: 250 CFM25, R-6`, `Detailed Example: 400 CFM50, R-6`

<br/>

**Ducts: Supply Location**

The location of the supply ducts. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#air-distribution'>Air Distribution</a>) is used.

- **Name:** ``ducts_supply_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `crawlspace`, `crawlspace - vented`, `crawlspace - unvented`, `crawlspace - conditioned`, `attic`, `attic - vented`, `attic - unvented`, `garage`, `exterior wall`, `under slab`, `roof deck`, `outside`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`, `manufactured home belly`

<br/>

**Ducts: Supply Area Fraction**

The fraction of supply ducts surface area in the given location. Only used if Surface Area is not provided. If the fraction is less than 1, the remaining duct area is assumed to be in conditioned space. If neither Surface Area nor Area Fraction provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#air-distribution'>Air Distribution</a>) is used.

- **Name:** ``ducts_supply_surface_area_fraction``
- **Type:** ``Double``

- **Units:** ``frac``

- **Required:** ``false``

<br/>

**Ducts: Supply Leakage Fraction**

The fraction of duct leakage associated with the supply ducts; the remainder is associated with the return ducts

- **Name:** ``ducts_supply_leakage_fraction``
- **Type:** ``Double``

- **Units:** ``frac``

- **Required:** ``false``

<br/>

**Ducts: Return Location**

The location of the return ducts. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#air-distribution'>Air Distribution</a>) is used.

- **Name:** ``ducts_return_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `crawlspace`, `crawlspace - vented`, `crawlspace - unvented`, `crawlspace - conditioned`, `attic`, `attic - vented`, `attic - unvented`, `garage`, `exterior wall`, `under slab`, `roof deck`, `outside`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`, `manufactured home belly`

<br/>

**Ducts: Return Area Fraction**

The fraction of return ducts surface area in the given location. Only used if Surface Area is not provided. If the fraction is less than 1, the remaining duct area is assumed to be in conditioned space. If neither Surface Area nor Area Fraction provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#air-distribution'>Air Distribution</a>) is used.

- **Name:** ``ducts_return_surface_area_fraction``
- **Type:** ``Double``

- **Units:** ``frac``

- **Required:** ``false``

<br/>

**Ducts: Number of Return Registers**

The number of return registers of the ducts. Only used to calculate default return duct surface area. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#air-distribution'>Air Distribution</a>) is used.

- **Name:** ``ducts_number_of_return_registers``
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

**Water Heater: Type**

The type of water heater. Use 'none' if there is no water heater.

- **Name:** ``water_heater_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `none`, `storage water heater`, `instantaneous water heater`, `heat pump water heater`, `space-heating boiler with storage tank`, `space-heating boiler with tankless coil`

<br/>

**Water Heater: Fuel Type**

The fuel type of water heater. Ignored for heat pump water heater.

- **Name:** ``water_heater_fuel_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `electricity`, `natural gas`, `fuel oil`, `propane`, `wood`, `coal`

<br/>

**Water Heater: Location**

The location of water heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-water-heating-systems'>HPXML Water Heating Systems</a>) is used.

- **Name:** ``water_heater_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `attic`, `attic - vented`, `attic - unvented`, `crawlspace`, `crawlspace - vented`, `crawlspace - unvented`, `crawlspace - conditioned`, `other exterior`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Water Heater: Tank Volume**

Nominal volume of water heater tank. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#conventional-storage'>Conventional Storage</a>, <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#heat-pump'>Heat Pump</a>, <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#combi-boiler-w-storage'>Combi Boiler w/ Storage</a>) is used.

- **Name:** ``water_heater_tank_volume``
- **Type:** ``Double``

- **Units:** ``gal``

- **Required:** ``false``

<br/>

**Water Heater: Efficiency Type**

The efficiency type of water heater. Does not apply to space-heating boilers.

- **Name:** ``water_heater_efficiency_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `EnergyFactor`, `UniformEnergyFactor`

<br/>

**Water Heater: Efficiency**

Rated Energy Factor or Uniform Energy Factor. Does not apply to space-heating boilers.

- **Name:** ``water_heater_efficiency``
- **Type:** ``Double``

- **Required:** ``true``

<br/>

**Water Heater: Usage Bin**

The usage of the water heater. Only applies if Efficiency Type is UniformEnergyFactor and Type is not instantaneous water heater. Does not apply to space-heating boilers. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#conventional-storage'>Conventional Storage</a>, <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#heat-pump'>Heat Pump</a>) is used.

- **Name:** ``water_heater_usage_bin``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `very small`, `low`, `medium`, `high`

<br/>

**Water Heater: Recovery Efficiency**

Ratio of energy delivered to water heater to the energy content of the fuel consumed by the water heater. Only used for non-electric storage water heaters. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#conventional-storage'>Conventional Storage</a>) is used.

- **Name:** ``water_heater_recovery_efficiency``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``false``

<br/>

**Water Heater: Heating Capacity**

Heating capacity. Only applies to storage water heater and heat pump water heater (compressor). If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#conventional-storage'>Conventional Storage</a>, <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#heat-pump'>Heat Pump</a>) is used.

- **Name:** ``water_heater_heating_capacity``
- **Type:** ``Double``

- **Units:** ``Btu/hr``

- **Required:** ``false``

<br/>

**Water Heater: Backup Heating Capacity**

Backup heating capacity for a heat pump water heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#heat-pump'>Heat Pump</a>) is used.

- **Name:** ``water_heater_backup_heating_capacity``
- **Type:** ``Double``

- **Units:** ``Btu/hr``

- **Required:** ``false``

<br/>

**Water Heater: Standby Loss**

The standby loss of water heater. Only applies to space-heating boilers. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#combi-boiler-w-storage'>Combi Boiler w/ Storage</a>) is used.

- **Name:** ``water_heater_standby_loss``
- **Type:** ``Double``

- **Units:** ``F/hr``

- **Required:** ``false``

<br/>

**Water Heater: Jacket R-value**

The jacket R-value of water heater. Doesn't apply to instantaneous water heater or space-heating boiler with tankless coil. If not provided, defaults to no jacket insulation.

- **Name:** ``water_heater_jacket_rvalue``
- **Type:** ``Double``

- **Units:** ``F-ft2-hr/Btu``

- **Required:** ``false``

<br/>

**Water Heater: Setpoint Temperature**

The setpoint temperature of water heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-water-heating-systems'>HPXML Water Heating Systems</a>) is used.

- **Name:** ``water_heater_setpoint_temperature``
- **Type:** ``Double``

- **Units:** ``F``

- **Required:** ``false``

<br/>

**Water Heater: Number of Bedrooms Served**

Number of bedrooms served (directly or indirectly) by the water heater. Only needed if single-family attached or apartment unit and it is a shared water heater serving multiple dwelling units. Used to apportion water heater tank losses to the unit.

- **Name:** ``water_heater_num_bedrooms_served``
- **Type:** ``Integer``

- **Units:** ``#``

- **Required:** ``false``

<br/>

**Water Heater: Uses Desuperheater**

Requires that the dwelling unit has a air-to-air, mini-split, or ground-to-air heat pump or a central air conditioner or mini-split air conditioner. If not provided, assumes no desuperheater.

- **Name:** ``water_heater_uses_desuperheater``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Water Heater: Tank Type**

Type of tank model to use. The 'stratified' tank generally provide more accurate results, but may significantly increase run time. Applies only to storage water heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#conventional-storage'>Conventional Storage</a>) is used.

- **Name:** ``water_heater_tank_model_type``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `mixed`, `stratified`

<br/>

**Water Heater: Operating Mode**

The water heater operating mode. The 'heat pump only' option only uses the heat pump, while 'hybrid/auto' allows the backup electric resistance to come on in high demand situations. This is ignored if a scheduled operating mode type is selected. Applies only to heat pump water heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#heat-pump'>Heat Pump</a>) is used.

- **Name:** ``water_heater_operating_mode``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `hybrid/auto`, `heat pump only`

<br/>

**Hot Water Distribution: System Type**

The type of the hot water distribution system.

- **Name:** ``hot_water_distribution_system_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `Standard`, `Recirculation`

<br/>

**Hot Water Distribution: Standard Piping Length**

If the distribution system is Standard, the length of the piping. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#standard'>Standard</a>) is used.

- **Name:** ``hot_water_distribution_standard_piping_length``
- **Type:** ``Double``

- **Units:** ``ft``

- **Required:** ``false``

<br/>

**Hot Water Distribution: Recirculation Control Type**

If the distribution system is Recirculation, the type of hot water recirculation control, if any.

- **Name:** ``hot_water_distribution_recirc_control_type``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `no control`, `timer`, `temperature`, `presence sensor demand control`, `manual demand control`

<br/>

**Hot Water Distribution: Recirculation Piping Length**

If the distribution system is Recirculation, the length of the recirculation piping. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#recirculation-in-unit'>Recirculation (In-Unit)</a>) is used.

- **Name:** ``hot_water_distribution_recirc_piping_length``
- **Type:** ``Double``

- **Units:** ``ft``

- **Required:** ``false``

<br/>

**Hot Water Distribution: Recirculation Branch Piping Length**

If the distribution system is Recirculation, the length of the recirculation branch piping. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#recirculation-in-unit'>Recirculation (In-Unit)</a>) is used.

- **Name:** ``hot_water_distribution_recirc_branch_piping_length``
- **Type:** ``Double``

- **Units:** ``ft``

- **Required:** ``false``

<br/>

**Hot Water Distribution: Recirculation Pump Power**

If the distribution system is Recirculation, the recirculation pump power. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#recirculation-in-unit'>Recirculation (In-Unit)</a>) is used.

- **Name:** ``hot_water_distribution_recirc_pump_power``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Hot Water Distribution: Pipe Insulation Nominal R-Value**

Nominal R-value of the pipe insulation. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-hot-water-distribution'>HPXML Hot Water Distribution</a>) is used.

- **Name:** ``hot_water_distribution_pipe_r``
- **Type:** ``Double``

- **Units:** ``F-ft2-hr/Btu``

- **Required:** ``false``

<br/>

**Drain Water Heat Recovery: Facilities Connected**

Which facilities are connected for the drain water heat recovery. Use 'none' if there is no drain water heat recovery system.

- **Name:** ``dwhr_facilities_connected``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `none`, `one`, `all`

<br/>

**Drain Water Heat Recovery: Equal Flow**

Whether the drain water heat recovery has equal flow.

- **Name:** ``dwhr_equal_flow``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Drain Water Heat Recovery: Efficiency**

The efficiency of the drain water heat recovery.

- **Name:** ``dwhr_efficiency``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``false``

<br/>

**Hot Water Fixtures: Is Shower Low Flow**

Whether the shower fixture is low flow.

- **Name:** ``water_fixtures_shower_low_flow``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Hot Water Fixtures: Is Sink Low Flow**

Whether the sink fixture is low flow.

- **Name:** ``water_fixtures_sink_low_flow``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Hot Water Fixtures: Usage Multiplier**

Multiplier on the hot water usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-water-fixtures'>HPXML Water Fixtures</a>) is used.

- **Name:** ``water_fixtures_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**General Water Use: Usage Multiplier**

Multiplier on internal gains from general water use (floor mopping, shower evaporation, water films on showers, tubs & sinks surfaces, plant watering, etc.) that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-building-occupancy'>HPXML Building Occupancy</a>) is used.

- **Name:** ``general_water_use_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Solar Thermal: System Type**

The type of solar thermal system. Use 'none' if there is no solar thermal system.

- **Name:** ``solar_thermal_system_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `none`, `hot water`

<br/>

**Solar Thermal: Collector Area**

The collector area of the solar thermal system.

- **Name:** ``solar_thermal_collector_area``
- **Type:** ``Double``

- **Units:** ``ft2``

- **Required:** ``true``

<br/>

**Solar Thermal: Collector Loop Type**

The collector loop type of the solar thermal system.

- **Name:** ``solar_thermal_collector_loop_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `liquid direct`, `liquid indirect`, `passive thermosyphon`

<br/>

**Solar Thermal: Collector Type**

The collector type of the solar thermal system.

- **Name:** ``solar_thermal_collector_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `evacuated tube`, `single glazing black`, `double glazing black`, `integrated collector storage`

<br/>

**Solar Thermal: Collector Azimuth**

The collector azimuth of the solar thermal system. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).

- **Name:** ``solar_thermal_collector_azimuth``
- **Type:** ``Double``

- **Units:** ``degrees``

- **Required:** ``true``

<br/>

**Solar Thermal: Collector Tilt**

The collector tilt of the solar thermal system. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.

- **Name:** ``solar_thermal_collector_tilt``
- **Type:** ``String``

- **Required:** ``true``

<br/>

**Solar Thermal: Collector Rated Optical Efficiency**

The collector rated optical efficiency of the solar thermal system.

- **Name:** ``solar_thermal_collector_rated_optical_efficiency``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**Solar Thermal: Collector Rated Thermal Losses**

The collector rated thermal losses of the solar thermal system.

- **Name:** ``solar_thermal_collector_rated_thermal_losses``
- **Type:** ``Double``

- **Units:** ``Btu/hr-ft2-R``

- **Required:** ``true``

<br/>

**Solar Thermal: Storage Volume**

The storage volume of the solar thermal system. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#detailed-inputs'>Detailed Inputs</a>) is used.

- **Name:** ``solar_thermal_storage_volume``
- **Type:** ``Double``

- **Units:** ``gal``

- **Required:** ``false``

<br/>

**Solar Thermal: Solar Fraction**

The solar fraction of the solar thermal system. If provided, overrides all other solar thermal inputs.

- **Name:** ``solar_thermal_solar_fraction``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**PV System**

The size and type of PV system.

- **Name:** ``pv_system``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `None`, `0.5 kW`, `1.0 kW`, `1.5 kW`, `1.5 kW, Premium Module`, `1.5 kW, Thin Film Module`, `2.0 kW`, `2.5 kW`, `3.0 kW`, `3.5 kW`, `4.0 kW`, `4.5 kW`, `5.0 kW`, `5.5 kW`, `6.0 kW`, `6.5 kW`, `7.0 kW`, `7.5 kW`, `8.0 kW`, `8.5 kW`, `9.0 kW`, `9.5 kW`, `10.0 kW`, `10.5 kW`, `11.0 kW`, `11.5 kW`, `12.0 kW`

<br/>

**PV System: Array Azimuth**

Array azimuth of the PV system. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).

- **Name:** ``pv_system_array_azimuth``
- **Type:** ``Double``

- **Units:** ``degrees``

- **Required:** ``false``

<br/>

**PV System: Array Tilt**

Array tilt of the PV system. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.

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

Array azimuth of the second PV system. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).

- **Name:** ``pv_system_2_array_azimuth``
- **Type:** ``Double``

- **Units:** ``degrees``

- **Required:** ``false``

<br/>

**PV System 2: Array Tilt**

Array tilt of the second PV system. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.

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

**Vehicle: Type**

The type of vehicle present at the home.

- **Name:** ``vehicle_type``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Vehicle: EV Battery Nominal Battery Capacity**

The nominal capacity of the vehicle battery, only applies to electric vehicles. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-vehicles'>HPXML Vehicles</a>) is used.

- **Name:** ``vehicle_battery_capacity``
- **Type:** ``Double``

- **Units:** ``kWh``

- **Required:** ``false``

<br/>

**Vehicle: EV Battery Usable Capacity**

The usable capacity of the vehicle battery, only applies to electric vehicles. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-vehicles'>HPXML Vehicles</a>) is used.

- **Name:** ``vehicle_battery_usable_capacity``
- **Type:** ``Double``

- **Units:** ``kWh``

- **Required:** ``false``

<br/>

**Vehicle: Combined Fuel Economy Units**

The combined fuel economy units of the vehicle. Only 'kWh/mile', 'mile/kWh', or 'mpge' are allow for electric vehicles. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-vehicles'>HPXML Vehicles</a>) is used.

- **Name:** ``vehicle_fuel_economy_units``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `kWh/mile`, `mile/kWh`, `mpge`, `mpg`

<br/>

**Vehicle: Combined Fuel Economy**

The combined fuel economy of the vehicle. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-vehicles'>HPXML Vehicles</a>) is used.

- **Name:** ``vehicle_fuel_economy_combined``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Vehicle: Miles Driven Per Year**

The annual miles the vehicle is driven. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-vehicles'>HPXML Vehicles</a>) is used.

- **Name:** ``vehicle_miles_driven_per_year``
- **Type:** ``Double``

- **Units:** ``miles``

- **Required:** ``false``

<br/>

**Vehicle: Hours Driven Per Week**

The weekly hours the vehicle is driven. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-vehicles'>HPXML Vehicles</a>) is used.

- **Name:** ``vehicle_hours_driven_per_week``
- **Type:** ``Double``

- **Units:** ``hours``

- **Required:** ``false``

<br/>

**Vehicle: Fraction Charged at Home**

The fraction of charging energy provided by the at-home charger to the vehicle, only applies to electric vehicles. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-vehicles'>HPXML Vehicles</a>) is used.

- **Name:** ``vehicle_fraction_charged_home``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Electric Vehicle Charger: Present**

Whether there is an electric vehicle charger present.

- **Name:** ``ev_charger_present``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Electric Vehicle Charger: Charging Level**

The charging level of the EV charger. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-electric-vehicle-chargers'>HPXML Electric Vehicle Chargers</a>) is used.

- **Name:** ``ev_charger_level``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `1`, `2`, `3`

<br/>

**Electric Vehicle Charger: Rated Charging Power**

The rated power output of the EV charger. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-electric-vehicle-chargers'>HPXML Electric Vehicle Chargers</a>) is used.

- **Name:** ``ev_charger_power``
- **Type:** ``Double``

- **Units:** ``W``

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

**Holiday Lighting: Present**

Whether there is holiday lighting.

- **Name:** ``holiday_lighting_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Holiday Lighting: Daily Consumption**

The daily energy consumption for holiday lighting (exterior). If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-lighting'>HPXML Lighting</a>) is used.

- **Name:** ``holiday_lighting_daily_kwh``
- **Type:** ``Double``

- **Units:** ``kWh/day``

- **Required:** ``false``

<br/>

**Holiday Lighting: Period**

Enter a date range like 'Nov 25 - Jan 5'. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-lighting'>HPXML Lighting</a>) is used.

- **Name:** ``holiday_lighting_period``
- **Type:** ``String``

- **Required:** ``false``

<br/>

**Dehumidifier: Type**

The type of dehumidifier.

- **Name:** ``dehumidifier_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `none`, `portable`, `whole-home`

<br/>

**Dehumidifier: Efficiency Type**

The efficiency type of dehumidifier.

- **Name:** ``dehumidifier_efficiency_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `EnergyFactor`, `IntegratedEnergyFactor`

<br/>

**Dehumidifier: Efficiency**

The efficiency of the dehumidifier.

- **Name:** ``dehumidifier_efficiency``
- **Type:** ``Double``

- **Units:** ``liters/kWh``

- **Required:** ``true``

<br/>

**Dehumidifier: Capacity**

The capacity (water removal rate) of the dehumidifier.

- **Name:** ``dehumidifier_capacity``
- **Type:** ``Double``

- **Units:** ``pint/day``

- **Required:** ``true``

<br/>

**Dehumidifier: Relative Humidity Setpoint**

The relative humidity setpoint of the dehumidifier.

- **Name:** ``dehumidifier_rh_setpoint``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**Dehumidifier: Fraction Dehumidification Load Served**

The dehumidification load served fraction of the dehumidifier.

- **Name:** ``dehumidifier_fraction_dehumidification_load_served``
- **Type:** ``Double``

- **Units:** ``Frac``

- **Required:** ``true``

<br/>

**Clothes Washer: Present**

Whether there is a clothes washer present.

- **Name:** ``clothes_washer_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Clothes Washer: Location**

The space type for the clothes washer location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-washer'>HPXML Clothes Washer</a>) is used.

- **Name:** ``clothes_washer_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Clothes Washer: Efficiency Type**

The efficiency type of the clothes washer.

- **Name:** ``clothes_washer_efficiency_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `ModifiedEnergyFactor`, `IntegratedModifiedEnergyFactor`

<br/>

**Clothes Washer: Efficiency**

The efficiency of the clothes washer. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-washer'>HPXML Clothes Washer</a>) is used.

- **Name:** ``clothes_washer_efficiency``
- **Type:** ``Double``

- **Units:** ``ft3/kWh-cyc``

- **Required:** ``false``

<br/>

**Clothes Washer: Rated Annual Consumption**

The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-washer'>HPXML Clothes Washer</a>) is used.

- **Name:** ``clothes_washer_rated_annual_kwh``
- **Type:** ``Double``

- **Units:** ``kWh/yr``

- **Required:** ``false``

<br/>

**Clothes Washer: Label Electric Rate**

The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-washer'>HPXML Clothes Washer</a>) is used.

- **Name:** ``clothes_washer_label_electric_rate``
- **Type:** ``Double``

- **Units:** ``$/kWh``

- **Required:** ``false``

<br/>

**Clothes Washer: Label Gas Rate**

The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-washer'>HPXML Clothes Washer</a>) is used.

- **Name:** ``clothes_washer_label_gas_rate``
- **Type:** ``Double``

- **Units:** ``$/therm``

- **Required:** ``false``

<br/>

**Clothes Washer: Label Annual Cost with Gas DHW**

The annual cost of using the system under test conditions. Input is obtained from the EnergyGuide label. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-washer'>HPXML Clothes Washer</a>) is used.

- **Name:** ``clothes_washer_label_annual_gas_cost``
- **Type:** ``Double``

- **Units:** ``$``

- **Required:** ``false``

<br/>

**Clothes Washer: Label Usage**

The clothes washer loads per week. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-washer'>HPXML Clothes Washer</a>) is used.

- **Name:** ``clothes_washer_label_usage``
- **Type:** ``Double``

- **Units:** ``cyc/wk``

- **Required:** ``false``

<br/>

**Clothes Washer: Drum Volume**

Volume of the washer drum. Obtained from the EnergyStar website or the manufacturer's literature. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-washer'>HPXML Clothes Washer</a>) is used.

- **Name:** ``clothes_washer_capacity``
- **Type:** ``Double``

- **Units:** ``ft3``

- **Required:** ``false``

<br/>

**Clothes Washer: Usage Multiplier**

Multiplier on the clothes washer energy and hot water usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-washer'>HPXML Clothes Washer</a>) is used.

- **Name:** ``clothes_washer_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Clothes Dryer: Present**

Whether there is a clothes dryer present.

- **Name:** ``clothes_dryer_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Clothes Dryer: Location**

The space type for the clothes dryer location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-dryer'>HPXML Clothes Dryer</a>) is used.

- **Name:** ``clothes_dryer_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Clothes Dryer: Fuel Type**

Type of fuel used by the clothes dryer.

- **Name:** ``clothes_dryer_fuel_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `electricity`, `natural gas`, `fuel oil`, `propane`, `wood`, `coal`

<br/>

**Clothes Dryer: Drying Method**

The method of drying used by the clothes dryer. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-dryer'>HPXML Clothes Dryer</a>) is used.

- **Name:** ``clothes_dryer_drying_method``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conventional`, `condensing`, `heat pump`, `other`

<br/>

**Clothes Dryer: Efficiency Type**

The efficiency type of the clothes dryer.

- **Name:** ``clothes_dryer_efficiency_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `EnergyFactor`, `CombinedEnergyFactor`

<br/>

**Clothes Dryer: Efficiency**

The efficiency of the clothes dryer. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-dryer'>HPXML Clothes Dryer</a>) is used.

- **Name:** ``clothes_dryer_efficiency``
- **Type:** ``Double``

- **Units:** ``lb/kWh``

- **Required:** ``false``

<br/>

**Clothes Dryer: Usage Multiplier**

Multiplier on the clothes dryer energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-clothes-dryer'>HPXML Clothes Dryer</a>) is used.

- **Name:** ``clothes_dryer_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Dishwasher: Present**

Whether there is a dishwasher present.

- **Name:** ``dishwasher_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Dishwasher: Location**

The space type for the dishwasher location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-dishwasher'>HPXML Dishwasher</a>) is used.

- **Name:** ``dishwasher_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Dishwasher: Efficiency Type**

The efficiency type of dishwasher.

- **Name:** ``dishwasher_efficiency_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `RatedAnnualkWh`, `EnergyFactor`

<br/>

**Dishwasher: Efficiency**

The efficiency of the dishwasher. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-dishwasher'>HPXML Dishwasher</a>) is used.

- **Name:** ``dishwasher_efficiency``
- **Type:** ``Double``

- **Units:** ``RatedAnnualkWh or EnergyFactor``

- **Required:** ``false``

<br/>

**Dishwasher: Label Electric Rate**

The label electric rate of the dishwasher. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-dishwasher'>HPXML Dishwasher</a>) is used.

- **Name:** ``dishwasher_label_electric_rate``
- **Type:** ``Double``

- **Units:** ``$/kWh``

- **Required:** ``false``

<br/>

**Dishwasher: Label Gas Rate**

The label gas rate of the dishwasher. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-dishwasher'>HPXML Dishwasher</a>) is used.

- **Name:** ``dishwasher_label_gas_rate``
- **Type:** ``Double``

- **Units:** ``$/therm``

- **Required:** ``false``

<br/>

**Dishwasher: Label Annual Gas Cost**

The label annual gas cost of the dishwasher. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-dishwasher'>HPXML Dishwasher</a>) is used.

- **Name:** ``dishwasher_label_annual_gas_cost``
- **Type:** ``Double``

- **Units:** ``$``

- **Required:** ``false``

<br/>

**Dishwasher: Label Usage**

The dishwasher loads per week. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-dishwasher'>HPXML Dishwasher</a>) is used.

- **Name:** ``dishwasher_label_usage``
- **Type:** ``Double``

- **Units:** ``cyc/wk``

- **Required:** ``false``

<br/>

**Dishwasher: Number of Place Settings**

The number of place settings for the unit. Data obtained from manufacturer's literature. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-dishwasher'>HPXML Dishwasher</a>) is used.

- **Name:** ``dishwasher_place_setting_capacity``
- **Type:** ``Integer``

- **Units:** ``#``

- **Required:** ``false``

<br/>

**Dishwasher: Usage Multiplier**

Multiplier on the dishwasher energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-dishwasher'>HPXML Dishwasher</a>) is used.

- **Name:** ``dishwasher_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Refrigerator: Present**

Whether there is a refrigerator present.

- **Name:** ``refrigerator_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Refrigerator: Location**

The space type for the refrigerator location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-refrigerators'>HPXML Refrigerators</a>) is used.

- **Name:** ``refrigerator_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Refrigerator: Rated Annual Consumption**

The EnergyGuide rated annual energy consumption for a refrigerator. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-refrigerators'>HPXML Refrigerators</a>) is used.

- **Name:** ``refrigerator_rated_annual_kwh``
- **Type:** ``Double``

- **Units:** ``kWh/yr``

- **Required:** ``false``

<br/>

**Refrigerator: Usage Multiplier**

Multiplier on the refrigerator energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-refrigerators'>HPXML Refrigerators</a>) is used.

- **Name:** ``refrigerator_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Extra Refrigerator: Present**

Whether there is an extra refrigerator present.

- **Name:** ``extra_refrigerator_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Extra Refrigerator: Location**

The space type for the extra refrigerator location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-refrigerators'>HPXML Refrigerators</a>) is used.

- **Name:** ``extra_refrigerator_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Extra Refrigerator: Rated Annual Consumption**

The EnergyGuide rated annual energy consumption for an extra refrigerator. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-refrigerators'>HPXML Refrigerators</a>) is used.

- **Name:** ``extra_refrigerator_rated_annual_kwh``
- **Type:** ``Double``

- **Units:** ``kWh/yr``

- **Required:** ``false``

<br/>

**Extra Refrigerator: Usage Multiplier**

Multiplier on the extra refrigerator energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-refrigerators'>HPXML Refrigerators</a>) is used.

- **Name:** ``extra_refrigerator_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Freezer: Present**

Whether there is a freezer present.

- **Name:** ``freezer_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Freezer: Location**

The space type for the freezer location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-freezers'>HPXML Freezers</a>) is used.

- **Name:** ``freezer_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Freezer: Rated Annual Consumption**

The EnergyGuide rated annual energy consumption for a freezer. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-freezers'>HPXML Freezers</a>) is used.

- **Name:** ``freezer_rated_annual_kwh``
- **Type:** ``Double``

- **Units:** ``kWh/yr``

- **Required:** ``false``

<br/>

**Freezer: Usage Multiplier**

Multiplier on the freezer energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-freezers'>HPXML Freezers</a>) is used.

- **Name:** ``freezer_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Cooking Range/Oven: Present**

Whether there is a cooking range/oven present.

- **Name:** ``cooking_range_oven_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Cooking Range/Oven: Location**

The space type for the cooking range/oven location. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-cooking-range-oven'>HPXML Cooking Range/Oven</a>) is used.

- **Name:** ``cooking_range_oven_location``
- **Type:** ``Choice``

- **Required:** ``false``

- **Choices:** `conditioned space`, `basement - conditioned`, `basement - unconditioned`, `garage`, `other housing unit`, `other heated space`, `other multifamily buffer space`, `other non-freezing space`

<br/>

**Cooking Range/Oven: Fuel Type**

Type of fuel used by the cooking range/oven.

- **Name:** ``cooking_range_oven_fuel_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `electricity`, `natural gas`, `fuel oil`, `propane`, `wood`, `coal`

<br/>

**Cooking Range/Oven: Is Induction**

Whether the cooking range is induction. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-cooking-range-oven'>HPXML Cooking Range/Oven</a>) is used.

- **Name:** ``cooking_range_oven_is_induction``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Cooking Range/Oven: Is Convection**

Whether the oven is convection. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-cooking-range-oven'>HPXML Cooking Range/Oven</a>) is used.

- **Name:** ``cooking_range_oven_is_convection``
- **Type:** ``Boolean``

- **Required:** ``false``

<br/>

**Cooking Range/Oven: Usage Multiplier**

Multiplier on the cooking range/oven energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-cooking-range-oven'>HPXML Cooking Range/Oven</a>) is used.

- **Name:** ``cooking_range_oven_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Ceiling Fan: Present**

Whether there are any ceiling fans.

- **Name:** ``ceiling_fan_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Ceiling Fan: Label Energy Use**

The label average energy use of the ceiling fan(s). If neither Efficiency nor Label Energy Use provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-ceiling-fans'>HPXML Ceiling Fans</a>) is used.

- **Name:** ``ceiling_fan_label_energy_use``
- **Type:** ``Double``

- **Units:** ``W``

- **Required:** ``false``

<br/>

**Ceiling Fan: Efficiency**

The efficiency rating of the ceiling fan(s) at medium speed. Only used if Label Energy Use not provided. If neither Efficiency nor Label Energy Use provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-ceiling-fans'>HPXML Ceiling Fans</a>) is used.

- **Name:** ``ceiling_fan_efficiency``
- **Type:** ``Double``

- **Units:** ``CFM/W``

- **Required:** ``false``

<br/>

**Ceiling Fan: Count**

Total number of ceiling fans. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-ceiling-fans'>HPXML Ceiling Fans</a>) is used.

- **Name:** ``ceiling_fan_count``
- **Type:** ``Integer``

- **Units:** ``#``

- **Required:** ``false``

<br/>

**Ceiling Fan: Cooling Setpoint Temperature Offset**

The cooling setpoint temperature offset during months when the ceiling fans are operating. Only applies if ceiling fan count is greater than zero. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-ceiling-fans'>HPXML Ceiling Fans</a>) is used.

- **Name:** ``ceiling_fan_cooling_setpoint_temp_offset``
- **Type:** ``Double``

- **Units:** ``F``

- **Required:** ``false``

<br/>

**Misc: Television**

The amount of television usage, relative to the national average.

- **Name:** ``misc_television``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `25%`, `33%`, `50%`, `75%`, `80%`, `90%`, `100%`, `110%`, `125%`, `150%`, `200%`, `300%`, `400%`, `Detailed Example: 620 kWh/yr`

<br/>

**Misc: Plug Loads**

The amount of additional plug load usage, relative to the national average.

- **Name:** ``misc_plug_loads``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `25%`, `33%`, `50%`, `75%`, `80%`, `90%`, `100%`, `110%`, `125%`, `150%`, `200%`, `300%`, `400%`, `Detailed Example: 2457 kWh/yr, 85.5% Sensible, 4.5% Latent`, `Detailed Example: 7302 kWh/yr, 82.2% Sensible, 17.8% Latent`

<br/>

**Misc: Well Pump**

The amount of well pump usage, relative to the national average.

- **Name:** ``misc_well_pump``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Typical Efficiency`, `High Efficiency`, `Detailed Example: 475 kWh/yr`

<br/>

**Misc Plug Loads: Vehicle Present**

Whether there is an electric vehicle.

- **Name:** ``misc_plug_loads_vehicle_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Misc Plug Loads: Vehicle Annual kWh**

The annual energy consumption of the electric vehicle plug loads. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-plug-loads'>HPXML Plug Loads</a>) is used.

- **Name:** ``misc_plug_loads_vehicle_annual_kwh``
- **Type:** ``Double``

- **Units:** ``kWh/yr``

- **Required:** ``false``

<br/>

**Misc Plug Loads: Vehicle Usage Multiplier**

Multiplier on the electric vehicle energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#hpxml-plug-loads'>HPXML Plug Loads</a>) is used.

- **Name:** ``misc_plug_loads_vehicle_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Misc: Gas Grill**

The amount of outdoor gas grill usage, relative to the national average.

- **Name:** ``misc_grill``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Natural Gas, 25%`, `Natural Gas, 33%`, `Natural Gas, 50%`, `Natural Gas, 67%`, `Natural Gas, 90%`, `Natural Gas, 100%`, `Natural Gas, 110%`, `Natural Gas, 150%`, `Natural Gas, 200%`, `Natural Gas, 300%`, `Natural Gas, 400%`, `Propane, 25%`, `Propane, 33%`, `Propane, 50%`, `Propane, 67%`, `Propane, 90%`, `Propane, 100%`, `Propane, 110%`, `Propane, 150%`, `Propane, 200%`, `Propane, 300%`, `Propane, 400%`, `Detailed Example: Propane, 25 therm/yr`

<br/>

**Misc: Gas Lighting**

The amount of gas lighting usage, relative to the national average.

- **Name:** ``misc_lighting``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Natural Gas, 25%`, `Natural Gas, 33%`, `Natural Gas, 50%`, `Natural Gas, 67%`, `Natural Gas, 90%`, `Natural Gas, 100%`, `Natural Gas, 110%`, `Natural Gas, 150%`, `Natural Gas, 200%`, `Natural Gas, 300%`, `Natural Gas, 400%`, `Detailed Example: Natural Gas, 28 therm/yr`

<br/>

**Misc: Fireplace**

The amount of fireplace usage, relative to the national average. Fireplaces can also be specified as heating systems that meet a portion of the heating load.

- **Name:** ``misc_fireplace``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `None`, `Natural Gas, 25%`, `Natural Gas, 33%`, `Natural Gas, 50%`, `Natural Gas, 67%`, `Natural Gas, 90%`, `Natural Gas, 100%`, `Natural Gas, 110%`, `Natural Gas, 150%`, `Natural Gas, 200%`, `Natural Gas, 300%`, `Natural Gas, 400%`, `Propane, 25%`, `Propane, 33%`, `Propane, 50%`, `Propane, 67%`, `Propane, 90%`, `Propane, 100%`, `Propane, 110%`, `Propane, 150%`, `Propane, 200%`, `Propane, 300%`, `Propane, 400%`, `Wood, 25%`, `Wood, 33%`, `Wood, 50%`, `Wood, 67%`, `Wood, 90%`, `Wood, 100%`, `Wood, 110%`, `Wood, 150%`, `Wood, 200%`, `Wood, 300%`, `Wood, 400%`, `Electric, 25%`, `Electric, 33%`, `Electric, 50%`, `Electric, 67%`, `Electric, 90%`, `Electric, 100%`, `Electric, 110%`, `Electric, 150%`, `Electric, 200%`, `Electric, 300%`, `Electric, 400%`, `Detailed Example: Wood, 55 therm/yr`

<br/>

**Pool: Present**

Whether there is a pool.

- **Name:** ``pool_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Pool: Pump Annual kWh**

The annual energy consumption of the pool pump. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#pool-pump'>Pool Pump</a>) is used.

- **Name:** ``pool_pump_annual_kwh``
- **Type:** ``Double``

- **Units:** ``kWh/yr``

- **Required:** ``false``

<br/>

**Pool: Pump Usage Multiplier**

Multiplier on the pool pump energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#pool-pump'>Pool Pump</a>) is used.

- **Name:** ``pool_pump_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Pool: Heater Type**

The type of pool heater. Use 'none' if there is no pool heater.

- **Name:** ``pool_heater_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `none`, `electric resistance`, `gas fired`, `heat pump`

<br/>

**Pool: Heater Annual kWh**

The annual energy consumption of the electric resistance pool heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#pool-heater'>Pool Heater</a>) is used.

- **Name:** ``pool_heater_annual_kwh``
- **Type:** ``Double``

- **Units:** ``kWh/yr``

- **Required:** ``false``

<br/>

**Pool: Heater Annual therm**

The annual energy consumption of the gas fired pool heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#pool-heater'>Pool Heater</a>) is used.

- **Name:** ``pool_heater_annual_therm``
- **Type:** ``Double``

- **Units:** ``therm/yr``

- **Required:** ``false``

<br/>

**Pool: Heater Usage Multiplier**

Multiplier on the pool heater energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#pool-heater'>Pool Heater</a>) is used.

- **Name:** ``pool_heater_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Permanent Spa: Present**

Whether there is a permanent spa.

- **Name:** ``permanent_spa_present``
- **Type:** ``Boolean``

- **Required:** ``true``

<br/>

**Permanent Spa: Pump Annual kWh**

The annual energy consumption of the permanent spa pump. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#permanent-spa-pump'>Permanent Spa Pump</a>) is used.

- **Name:** ``permanent_spa_pump_annual_kwh``
- **Type:** ``Double``

- **Units:** ``kWh/yr``

- **Required:** ``false``

<br/>

**Permanent Spa: Pump Usage Multiplier**

Multiplier on the permanent spa pump energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#permanent-spa-pump'>Permanent Spa Pump</a>) is used.

- **Name:** ``permanent_spa_pump_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

<br/>

**Permanent Spa: Heater Type**

The type of permanent spa heater. Use 'none' if there is no permanent spa heater.

- **Name:** ``permanent_spa_heater_type``
- **Type:** ``Choice``

- **Required:** ``true``

- **Choices:** `none`, `electric resistance`, `gas fired`, `heat pump`

<br/>

**Permanent Spa: Heater Annual kWh**

The annual energy consumption of the electric resistance permanent spa heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#permanent-spa-heater'>Permanent Spa Heater</a>) is used.

- **Name:** ``permanent_spa_heater_annual_kwh``
- **Type:** ``Double``

- **Units:** ``kWh/yr``

- **Required:** ``false``

<br/>

**Permanent Spa: Heater Annual therm**

The annual energy consumption of the gas fired permanent spa heater. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#permanent-spa-heater'>Permanent Spa Heater</a>) is used.

- **Name:** ``permanent_spa_heater_annual_therm``
- **Type:** ``Double``

- **Units:** ``therm/yr``

- **Required:** ``false``

<br/>

**Permanent Spa: Heater Usage Multiplier**

Multiplier on the permanent spa heater energy usage that can reflect, e.g., high/low usage occupants. If not provided, the OS-HPXML default (see <a href='https://openstudio-hpxml.readthedocs.io/en/v1.11.0/workflow_inputs.html#permanent-spa-heater'>Permanent Spa Heater</a>) is used.

- **Name:** ``permanent_spa_heater_usage_multiplier``
- **Type:** ``Double``

- **Required:** ``false``

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





