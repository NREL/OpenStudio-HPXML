HVAC Systems
############

HEScore allows the definition of up to two HVAC systems which can each include a
heating system, cooling system, and duct system. To determine which HPXML
elements are associated, the ``DistributionSystem`` subelement of
``HeatingSystem``, ``CoolingSystem``, ``HeatPump`` is used to find the link to
``HVACDistributionSystem``. Systems that share the same
``HVACDistributionSystem`` are determined to be the same HVAC system for
HEScore.

Sometimes an HVAC system will not share ducts, for instance a central air
conditioner and boiler. In that case, if each of those systems serve a fraction
of the home's load within 5% of each other they will be combined into the same
HVAC system for HEScore. If a ``HeatingSystem`` and ``CoolingSystem`` that are
associated with the same ``HVACDistributionSystem`` serve differing portions of
the house's heating and cooling load, that weight is averaged to find the
combined system weight.

If either a heating or cooling system meets all of the load and two systems of
the opposite (cooling or heating, respectively) are required to meet the same
fraction of the load, the larger system is split into two for input into
HEScore.

To determine the fraction of the home's heating and cooling load each system
serves, each HPXML heating and cooling system is required to have
``FloorAreaServed`` or, alternatively ``FracLoadServed``. The two combined HVAC
systems that serve the greatest portion of the house's load are sent to HEScore.

For details about how each kind of ``HeatingSystem``, ``CoolingSystem``,
``HeatPump``, and ``HVACDistributionSystem`` are translated into HEScore inputs,
see the appropriate subsection:

.. toctree::
   :maxdepth: 1

   heating_system
   cooling_system
   hvac_distribution


