Cooling
#######

.. contents:: Table of Contents

Cooling system type
*******************

HPXML provides two difference HVAC system elements that can provide cooling:
``CoolingSystem`` that only provides cooling and ``HeatPump`` which can provide
heating and cooling. 

Heat Pump
=========

The ``HeatPump`` element in HPXML can represent either an air-source heat pump
or ground source heat pump in HEScore. Which is specified in HEScore is
determined by the ``HeatPumpType`` element in HPXML according to the following
mapping.

.. table:: Heat Pump Type mapping

   ============================  ============================
   HPXML Heat Pump Type          HEScore Cooling Type
   ============================  ============================
   water-to-air                  gchp
   water-to-water                gchp
   air-to-air                    heat_pump
   mini-split                    mini_split
   ground-to-air                 gchp
   ============================  ============================

.. note::

   Prior to HEScore v2016 mini-split heat pumps were translated as ducted air-source heat pumps with ducts in conditioned space.
   With the addition of mini split heat pumps in HEScore v2016, they are now categorized appropriately.

If a heat pump has a `FractionHeatlLoadServed` set to zero, the heat pump is
assumed to provide only space cooling. If the heat pump is connected to the
same distribution system as a separate heating system and serves the same
portion of the house, the house will translate but fail in Home Energy Score
because that configuration is not supported.


.. _clg-sys:

Cooling System
==============

The ``CoolingSystem`` element in HPXML is used to describe any system that
provides cooling that is not a heat pump. The ``CoolingSystemType`` subelement
is used to determine what kind of cooling system to specify for HEScore. This
is done according to the following mapping.

.. table:: Cooling System Type mapping

   ===================================  ====================
   HPXML Cooling System Type            HEScore Cooling Type
   ===================================  ====================
   central air conditioner (HPXML V3)   split_dx
   central air conditioning (HPXML V2)  split_dx
   room air conditioner                 packaged_dx
   mini-split                           mini_split
   evaporative cooler                   dec
   other                                *not translated*
   ===================================  ====================

.. warning::
   
   If an HPXML cooling system type maps to *not translated* the translation will fail.

.. note::

   Prior to v2016, HEScore did not have an evaporative cooler type and these were translated as high efficiency ``split_dx`` systems.
   Now that evaporative cooling has been added in HEScore v2016, they are categorized accordingly.

.. note::

   Starting from HPXML version 3.0, the enumeration "central air conditioning" is renamed as "central air conditioner".
   They're equivalent in translation.

Cooling Efficiency
******************

Cooling efficiency can be described in HEScore by either the rated efficiency
(SEER, EER), or if that is unavailable, the year installed/manufactured from
which HEScore estimates the efficiency based on shipment weighted efficiencies
by year. The translator follows this methodology and looks for the rated
efficiency first and if it cannot be found sends the year installed. 
Evaporative coolers do not require an efficiency input in HEScore, and it is therefore omitted.

Rated Efficiency
================

HEScore expects efficiency to be described in different units depending on the
cooling system type. 

.. table:: HEScore cooling type efficiency units

   ===============  ================
   Cooling Type     Efficiency Units
   ===============  ================
   split_dx         SEER
   packaged_dx      EER
   heat_pump        SEER
   mini_split       SEER
   gchp             EER
   ===============  ================

The translator searches the ``CoolingSystem/AnnualCoolingEfficiency`` or
``HeatPump/AnnualCoolEfficiency`` (HPXML v2) or ``HeatPump/AnnualCoolingEfficiency`` (HPXML v3)
elements of the primary cooling system and uses the first one that has the correct units.

.. _clg-shipment-weighted-efficiency:

Shipment Weighted Efficiency
============================

When an appropriate rated efficiency cannot be found, HEScore can accept the
year the equipment was installed and estimate the efficiency based on that. The
year is retrieved from the ``YearInstalled`` element, and if that is not
present the ``ModelYear`` element. 


