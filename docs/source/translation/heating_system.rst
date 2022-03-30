Heating
#######

.. contents:: Table of Contents

Heating system type
*******************

HPXML provides two difference HVAC system elements that can provide heating:
``HeatingSystem`` that only provides heating and ``HeatPump`` which can provide
heating and cooling. 

Heat Pump
=========

The ``HeatPump`` element in HPXML can represent either an air-source heat pump
or ground source heat pump in HEScore. Which is specified in HEScore is
determined by the ``HeatPumpType`` element in HPXML according to the following
mapping.

.. table:: Heat Pump Type mapping

   ============================  ============================
   HPXML Heat Pump Type          HEScore Heating Type
   ============================  ============================
   water-to-air                  gchp
   water-to-water                gchp
   air-to-air                    heat_pump
   mini-split                    mini_split
   ground-to-air                 gchp
   ============================  ============================
   
The primary heating fuel is assumed to be electric.

.. note::

   Prior to HEScore v2016 mini-split heat pumps were translated as ducted air-source heat pumps with ducts in conditioned space.
   With the addition of mini split heat pumps in HEScore v2016, they are now categorized appropriately.

If a heat pump has a `FractionCoolLoadServed` set to zero, the heat pump is
assumed to provide only space heating. If the heat pump is connected to the
same distribution system as a separate cooling system and serves the same
portion of the house, the house will translate but fail in Home Energy Score
because that configuration is not supported.


Heating System
==============

The ``HeatingSystem`` element in HPXML is used to describe any system that
provides heating that is not a heat pump. The ``HeatingSystemType`` subelement
is used to determine what kind of heating system to specify for HEScore. This
is done according to the following mapping.

.. table:: Heating System Type mapping

   =========================  ====================
   HPXML Heating System Type  HEScore Heating Type
   =========================  ====================
   Furnace                    central_furnace
   WallFurnace                wall_furnace
   FloorFurnace               wall_furnace
   Boiler                     boiler
   ElectricResistance         baseboard
   Stove                      wood_stove
   =========================  ====================

.. note::
   
   HPXML supports other values for the ``HeatingSystemType`` element 
   not in the list above, but HEScore does not. Other heating system 
   types will result in a translation error.

A primary heating fuel is selected from the ``HeatingSystemFuel`` subelement of
the primary heating system. The fuel types are mapped as follows.

.. _fuel-mapping:

.. table:: Primary Heating System Fuel mapping

   =====================  ===========
   HPXML                  HEScore
   =====================  ===========
   electricity            electric
   renewable electricity  electric
   natural gas            natural_gas
   renewable natural gas  natural_gas
   fuel oil               fuel_oil
   fuel oil 1             fuel_oil
   fuel oil 2             fuel_oil
   fuel oil 4             fuel_oil
   fuel oil 5/6           fuel_oil
   propane                lpg
   wood                   cord_wood
   wood pellets           pellet_wood
   =====================  ===========

.. warning::

   HPXML supports other fuel types that could not be mapped into 
   existing HEScore fuel types (i.e. coal, wood). Encountering an
   unsupported fuel type will result in a translation error.   

Heating Efficiency
******************

Heating efficiency can be described in HEScore by either the rated efficiency
(AFUE, HSPF, COP), or if that is unavailable, the year installed/manufactured
from which HEScore estimates the efficiency based on shipment weighted
efficiencies by year. The translator follows this methodology and looks for the
rated efficiency first and if it cannot be found sends the year installed.

Wood stoves and electric furnaces and baseboard heating do not use the
efficiency input in HEScore. Therefore, for these heating types an efficiency
is not determined.

Rated Efficiency
================

HEScore expects efficiency to be described in different units depending on the
heating system type. 

.. table:: HEScore heating type efficiency units

   ===============  ================
   Heating Type     Efficiency Units
   ===============  ================
   heat_pump        HSPF
   mini_split       HSPF
   central_furnace  AFUE
   wall_furnace     AFUE
   boiler           AFUE
   gchp             COP
   ===============  ================

The translator searches the ``HeatingSystem/AnnualHeatingEfficiency`` or
``HeatPump/AnnualHeatEfficiency`` (HPXML v2) or ``HeatPump/AnnualHeatingEfficiency`` (HPXML v3)
elements of the primary heating system and uses the first one that has the correct units.

Shipment Weighted Efficiency
============================

When an appropriate rated efficiency cannot be found, HEScore can accept the
year the equipment was installed and estimate the efficiency based on that. The
year is retrieved from the ``YearInstalled`` element, and if that is not
present the ``ModelYear`` element. 


