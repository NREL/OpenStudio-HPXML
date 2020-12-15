.. _workflow_outputs:

Workflow Outputs
================

OpenStudio-HPXML generates a variety of annual (and optionally, timeseries) outputs for a residential HPXML-based model.

Annual Outputs
--------------

OpenStudio-HPXML will always generate an annual CSV output file called results_annual.csv, co-located with the EnergyPlus output.
The CSV file includes the following sections of output:

Annual Energy Consumption by Fuel Type
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Current fuel types are: 

   ========================== ===========================
   Type                       Notes
   ========================== ===========================
   Electricity: Total (MBtu)
   Electricity: Net (MBtu)    Excludes any power produced by PV or generators.
   Natural Gas: Total (MBtu)
   Fuel Oil: Total (MBtu)     Includes "fuel oil", "fuel oil 1", "fuel oil 2", "fuel oil 4", "fuel oil 5/6", "kerosene", and "diesel"
   Propane: Total (MBtu)
   Wood: Total (MBtu)
   Wood Pellets: Total (MBtu)
   Coal: Total (MBtu)         Includes "coal", "anthracite coal", "bituminous coal", and "coke".
   ========================== ===========================

Annual Energy Consumption By Fuel Type and End Use
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Current end use/fuel type combinations are:

   ========================================================== ====================================================
   Type                                                       Notes
   ========================================================== ====================================================
   Electricity: Heating (MBtu)
   Electricity: Heating Fans/Pumps (MBtu)
   Electricity: Cooling (MBtu)
   Electricity: Cooling Fans/Pumps (MBtu)
   Electricity: Hot Water (MBtu)
   Electricity: Hot Water Recirc Pump (MBtu)
   Electricity: Hot Water Solar Thermal Pump (MBtu)
   Electricity: Lighting Interior (MBtu)
   Electricity: Lighting Garage (MBtu)
   Electricity: Lighting Exterior (MBtu)
   Electricity: Mech Vent (MBtu)
   Electricity: Mech Vent Preheating (MBtu)
   Electricity: Mech Vent Precooling (MBtu)
   Electricity: Whole House Fan (MBtu)
   Electricity: Refrigerator (MBtu)
   Electricity: Freezer (MBtu)
   Electricity: Dehumidifier (MBtu)
   Electricity: Dishwasher (MBtu)
   Electricity: Clothes Washer (MBtu)
   Electricity: Clothes Dryer (MBtu)
   Electricity: Range/Oven (MBtu)
   Electricity: Ceiling Fan (MBtu)
   Electricity: Television (MBtu)
   Electricity: Plug Loads (MBtu)
   Electricity: Electric Vehicle Charging (MBtu)
   Electricity: Well Pump (MBtu)
   Electricity: Pool Heater (MBtu)
   Electricity: Pool Pump (MBtu)
   Electricity: Hot Tub Heater (MBtu)
   Electricity: Hot Tub Pump (MBtu)
   Electricity: PV (MBtu)                                     Negative value for any power produced
   Electricity: Generator (MBtu)                              Negative value for power produced
   Natural Gas: Heating (MBtu)
   Natural Gas: Hot Water (MBtu)
   Natural Gas: Clothes Dryer (MBtu)
   Natural Gas: Range/Oven (MBtu)
   Natural Gas: Mech Vent Preheating (MBtu)
   Natural Gas: Mech Vent Precooling (MBtu)
   Natural Gas: Pool Heater (MBtu)
   Natural Gas: Hot Tub Heater (MBtu)
   Natural Gas: Grill (MBtu)
   Natural Gas: Lighting (MBtu)
   Natural Gas: Fireplace (MBtu)
   Natural Gas: Generator (MBtu)                              Positive value for any fuel consumed
   Fuel Oil: Heating (MBtu)
   Fuel Oil: Hot Water (MBtu)
   Fuel Oil: Clothes Dryer (MBtu)
   Fuel Oil: Range/Oven (MBtu)
   Fuel Oil: Mech Vent Preheating (MBtu)
   Fuel Oil: Mech Vent Precooling (MBtu)
   Fuel Oil: Grill (MBtu)
   Fuel Oil: Lighting (MBtu)
   Fuel Oil: Fireplace (MBtu)
   Propane: Heating (MBtu)
   Propane: Hot Water (MBtu)
   Propane: Clothes Dryer (MBtu)
   Propane: Range/Oven (MBtu)
   Propane: Mech Vent Preheating (MBtu)
   Propane: Mech Vent Precooling (MBtu)
   Propane: Grill (MBtu)
   Propane: Lighting (MBtu)
   Propane: Fireplace (MBtu)
   Propane: Generator (MBtu)                                  Positive value for any fuel consumed
   Wood Cord: Heating (MBtu)
   Wood Cord: Hot Water (MBtu)
   Wood Cord: Clothes Dryer (MBtu)
   Wood Cord: Range/Oven (MBtu)
   Wood Cord: Mech Vent Preheating (MBtu)
   Wood Cord: Mech Vent Precooling (MBtu)
   Wood Cord: Grill (MBtu)
   Wood Cord: Lighting (MBtu)
   Wood Cord: Fireplace (MBtu)
   Wood Pellets: Heating (MBtu)
   Wood Pellets: Hot Water (MBtu)
   Wood Pellets: Clothes Dryer (MBtu)
   Wood Pellets: Range/Oven (MBtu)
   Wood Pellets: Mech Vent Preheating (MBtu)
   Wood Pellets: Mech Vent Precooling (MBtu)
   Wood Pellets: Grill (MBtu)
   Wood Pellets: Lighting (MBtu)
   Wood Pellets: Fireplace (MBtu)
   Coal: Heating (MBtu)
   Coal: Hot Water (MBtu)
   Coal: Clothes Dryer (MBtu)
   Coal: Range/Oven (MBtu)
   Coal: Mech Vent Preheating (MBtu)
   Coal: Mech Vent Precooling (MBtu)
   Coal: Grill (MBtu)
   Coal: Lighting (MBtu)
   Coal: Fireplace (MBtu)
   ========================================================== ====================================================

Annual Building Loads
~~~~~~~~~~~~~~~~~~~~~

Current annual building loads are:

   ===================================== ==================================================================
   Type                                  Notes
   ===================================== ==================================================================
   Load: Heating (MBtu)                  Includes HVAC distribution losses.
   Load: Cooling (MBtu)                  Includes HVAC distribution losses.
   Load: Hot Water: Delivered (MBtu)     Includes contributions by desuperheaters or solar thermal systems.
   Load: Hot Water: Tank Losses (MBtu)
   Load: Hot Water: Desuperheater (MBtu) Load served by the desuperheater.
   Load: Hot Water: Solar Thermal (MBtu) Load served by the solar thermal system.
   ===================================== ==================================================================

Annual Unmet Building Loads
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Current annual unmet building loads are:

   ========================== =====
   Type                       Notes
   ========================== =====
   Unmet Load: Heating (MBtu)
   Unmet Load: Cooling (MBtu)
   ========================== =====

These numbers reflect the amount of heating/cooling load that is not met by the HVAC system, indicating the degree to which the HVAC system is undersized.
An HVAC system with sufficient capacity to perfectly maintain the thermostat setpoints will report an unmet load of zero.

Note that if a building has partial (or no) HVAC system, the unserved load will not be included in the unmet load outputs.
For example, if a building has a room air conditioner that meets 33% of the cooling load, the remaining 67% of the load is not included in the unmet load.
Rather, the unmet load is only the amount of load that the room AC *should* be serving but is not.

Peak Building Electricity
~~~~~~~~~~~~~~~~~~~~~~~~~

Current peak building electricity outputs are:

   ================================== =========================================================
   Type                               Notes
   ================================== =========================================================
   Peak Electricity: Winter Total (W) Winter season defined by operation of the heating system.
   Peak Electricity: Summer Total (W) Summer season defined by operation of the cooling system.
   ================================== =========================================================

Peak Building Loads
~~~~~~~~~~~~~~~~~~~

Current peak building loads are:

   ========================== ==================================
   Type                       Notes
   ========================== ==================================
   Peak Load: Heating (kBtu)  Includes HVAC distribution losses.
   Peak Load: Cooling (kBtu)  Includes HVAC distribution losses.
   ========================== ==================================

Annual Component Building Loads
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Component loads represent the estimated contribution of different building components to the annual heating/cooling building loads.
The sum of component loads for heating (or cooling) will roughly equal the annual heating (or cooling) building load reported above.
Current component loads disaggregated by Heating/Cooling are:
   
   ================================================= =========================================================================================================
   Type                                              Notes
   ================================================= =========================================================================================================
   Component Load: \*: Roofs (MBtu)                  Heat gain/loss through HPXML ``Roof`` elements adjacent to conditioned space
   Component Load: \*: Ceilings (MBtu)               Heat gain/loss through HPXML ``FrameFloor`` elements (inferred to be ceilings) adjacent to conditioned space
   Component Load: \*: Walls (MBtu)                  Heat gain/loss through HPXML ``Wall`` elements adjacent to conditioned space
   Component Load: \*: Rim Joists (MBtu)             Heat gain/loss through HPXML ``RimJoist`` elements adjacent to conditioned space
   Component Load: \*: Foundation Walls (MBtu)       Heat gain/loss through HPXML ``FoundationWall`` elements adjacent to conditioned space
   Component Load: \*: Doors (MBtu)                  Heat gain/loss through HPXML ``Door`` elements adjacent to conditioned space
   Component Load: \*: Windows (MBtu)                Heat gain/loss through HPXML ``Window`` elements adjacent to conditioned space, including solar
   Component Load: \*: Skylights (MBtu)              Heat gain/loss through HPXML ``Skylight`` elements adjacent to conditioned space, including solar
   Component Load: \*: Floors (MBtu)                 Heat gain/loss through HPXML ``FrameFloor`` elements (inferred to be floors) adjacent to conditioned space
   Component Load: \*: Slabs (MBtu)                  Heat gain/loss through HPXML ``Slab`` elements adjacent to conditioned space
   Component Load: \*: Internal Mass (MBtu)          Heat gain/loss from internal mass (e.g., furniture, interior walls/floors) in conditioned space
   Component Load: \*: Infiltration (MBtu)           Heat gain/loss from airflow induced by stack and wind effects
   Component Load: \*: Natural Ventilation (MBtu)    Heat gain/loss from airflow through operable windows
   Component Load: \*: Mechanical Ventilation (MBtu) Heat gain/loss from airflow/fan energy from mechanical ventilation systems (including clothes dryer exhaust)
   Component Load: \*: Whole House Fan (MBtu)        Heat gain/loss from airflow due to a whole house fan
   Component Load: \*: Ducts (MBtu)                  Heat gain/loss from conduction and leakage losses through supply/return ducts outside conditioned space
   Component Load: \*: Internal Gains (MBtu)         Heat gain/loss from appliances, lighting, plug loads, water heater tank losses, etc. in the conditioned space
   ================================================= =========================================================================================================

Annual Hot Water Uses
~~~~~~~~~~~~~~~~~~~~~

Current annual hot water uses are:

   =================================== ====================
   Type                                Notes
   =================================== ====================
   Hot Water: Clothes Washer (gal)
   Hot Water: Dishwasher (gal)
   Hot Water: Fixtures (gal)           Showers and faucets.
   Hot Water: Distribution Waste (gal) 
   =================================== ====================


Timeseries Outputs
------------------

OpenStudio-HPXML can optionally generate a timeseries CSV output file.
The timeseries output file is called results_timeseries.csv and co-located with the EnergyPlus output.

Depending on the outputs requested, CSV files may include:

   =================================== ==================================================================================================================================
   Type                                Notes
   =================================== ==================================================================================================================================
   Fuel Consumptions                   Energy use for each fuel type (in kBtu for fossil fuels and kWh for electricity).
   End Use Consumptions                Energy use for each end use type (in kBtu for fossil fuels and kWh for electricity).
   Hot Water Uses                      Water use for each end use type (in gallons).
   Total Loads                         Heating, cooling, and hot water loads (in kBtu) for the building.
   Component Loads                     Heating and cooling loads (in kBtu) disaggregated by component (e.g., Walls, Windows, Infiltration, Ducts, etc.).
   Zone Temperatures                   Average temperatures (in deg-F) for each space modeled (e.g., living space, attic, garage, basement, crawlspace, etc.).
   Airflows                            Airflow rates (in cfm) for infiltration, mechanical ventilation (including clothes dryer exhaust), natural ventilation, whole house fans.
   Weather                             Weather file data including outdoor temperatures, relative humidity, wind speed, and solar.
   =================================== ==================================================================================================================================
