Domestic Hot Water
##################

.. contents:: Table of Contents

Determining the primary water heating system
********************************************

HPXML allows for the specification of several ``WaterHeatingSystem`` elements.
HEScore only allows one to be specified. If there are more than one water
heaters present in the HPXML file, the one that serves the largest fraction of
the the load is selected based on the value of ``FractionDHWLoadServed``. If
not all of the ``WaterHeatingSystem`` elements have ``FractionDHWServed``
subelements (or if none of them do), the first ``WaterHeatingSystem`` is
selected.

Water heater type
*****************

The water heater type is mapped from HPXML to HEScore accordingly:

.. table:: HPXML to HEScore water heater type mapping
   
   +----------------------------------------+---------------------------------+
   |HPXML                                   |HEScore                          |
   +----------------------------------------+----------------+----------------+
   |WaterHeaterType                         |DHW Category    |DHW Type        |
   +========================================+================+================+
   |storage water heater                    |unit            |storage         |
   +----------------------------------------+                |                |
   |dedicated boiler with storage tank      |                |                |
   +----------------------------------------+----------------+----------------+
   |instantaneous water heater              |unit            |tankless        |
   +----------------------------------------+----------------+----------------+
   |heat pump water heater                  |unit            |heat_pump       |
   +----------------------------------------+----------------+----------------+
   |space-heating boiler with storage tank  |combined        |indirect        |
   +----------------------------------------+----------------+----------------+
   |space-heating boiler with tankless coil |combined        |tankless_coil   |
   +----------------------------------------+----------------+----------------+

The fuel type is mapped according to the same mapping used in
:ref:`fuel-mapping`.

Water heating efficiency
************************

If the ``WaterHeating/UniformEnergyFactor`` element exists, that is passed to 
HEScore with an efficiency method of "uef".
Otherwise if the ``WaterHeatingSystem/EnergyFactor`` element exists, that energy factor is
sent to HEScore along with an efficiency method of "user", which tells it that to interpret it
as a traditional energy factor. 
When an energy factor cannot be found, HEScore can accept the
year the equipment was installed and estimate the efficiency based on that. The
year is retrieved from the ``YearInstalled`` element, and if that is not
present the ``ModelYear`` element.

If the DHW type is tankless, only energy factor or unified energy factor could be used to describe efficiency, 
the estimation based on installed year is no longer available.
