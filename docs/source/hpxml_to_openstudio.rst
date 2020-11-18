HPXMLtoOpenStudio Measure
=========================

Introduction
------------

The HPXMLtoOpenStudio measure requires a building description in an `HPXML file <https://hpxml.nrel.gov/>`_ format.
HPXML is an open data standard for collecting and transferring home energy data. 
Using HPXML files reduces the complexity and effort for software developers to leverage the EnergyPlus simulation engine.

HPXML Inputs
------------

HPXML is an flexible and extensible format, where nearly all elements in the schema are optional and custom elements can be included.
Because of this, a stricter set of requirements for the HPXML file have been developed for purposes of running EnergyPlus simulations.

HPXML files submitted to OpenStudio-HPXML should undergo a two step validation process:

1. Validation against the HPXML Schema

  The HPXML XSD Schema can be found at ``HPXMLtoOpenStudio/resources/HPXML.xsd``.
  It should be used by the software developer to validate their HPXML file prior to running the simulation.
  XSD Schemas are used to validate what elements/attributes/enumerations are available, data types for elements/attributes, the number/order of children elements, etc.

  OpenStudio-HPXML **does not** validate the HPXML file against the XSD Schema and assumes the file submitted is valid.
  However, OpenStudio-HPXML does automatically check for valid data types (e.g., integer vs string), enumeration choices, and numeric values within min/max.

2. Validation using `Schematron <http://schematron.com/>`_

  The Schematron document for the EnergyPlus use case can be found at ``HPXMLtoOpenStudio/resources/EPvalidator.xml``.
  Schematron is a rule-based validation language, expressed in XML using XPath expressions, for validating the presence or absence of inputs in XML files. 
  As opposed to an XSD Schema, a Schematron document validates constraints and requirements based on conditionals and other logical statements.
  For example, if an element is specified with a particular value, the applicable enumerations of another element may change.
  
  OpenStudio-HPXML **automatically validates** the HPXML file against the Schematron document and reports any validation errors, but software developers may find it beneficial to also integrate Schematron validation into their software.

.. important::

  Usage of both validation approaches (XSD and Schematron) is recommended for developers actively working on creating HPXML files for EnergyPlus simulations:

  - Validation against XSD for general correctness and usage of HPXML
  - Validation against Schematron for understanding XML document requirements specific to running EnergyPlus

Input Defaults
**************

An increasing number of elements in the HPXML file are being made optional with "smart" defaults.
Default values, equations, and logic are described throughout this documentation.

Most defaults can also be seen by using the ``debug`` argument/flag when running the workflow on an actual HPXML file.
This will create a new HPXML file (``in.xml`` in the run directory) where additional fields are populated for inspection.

For example, suppose a HPXML file has a window defined as follows:

.. code-block:: XML

  <Window>
    <SystemIdentifier id='Window'/>
    <Area>108.0</Area>
    <Azimuth>0</Azimuth>
    <UFactor>0.33</UFactor>
    <SHGC>0.45</SHGC>
    <AttachedToWall idref='Wall'/>
  </Window>

In the ``in.xml`` file, the window would have additional elements like so:

.. code-block:: XML

  <Window>
    <SystemIdentifier id='Window'/>
    <Area>108.0</Area>
    <Azimuth>0</Azimuth>
    <UFactor>0.33</UFactor>
    <SHGC>0.45</SHGC>
    <InteriorShading>
      <SystemIdentifier id='WindowInteriorShading'/>
      <SummerShadingCoefficient>0.7</SummerShadingCoefficient>
      <WinterShadingCoefficient>0.85</WinterShadingCoefficient>
    </InteriorShading>
    <FractionOperable>0.67</FractionOperable>
    <AttachedToWall idref='Wall'/>
  </Window>

.. note::

  The OpenStudio-HPXML workflow generally treats missing HPXML objects differently than missing properties.
  For example, if there is a ``Window`` with no ``Overhangs`` object defined, the window will be interpreted as having no overhangs and modeled this way.
  On the other hand, if there is a ``Window`` element with no ``FractionOperable`` property defined, it is assumed that the operable property of the window is unknown and will be defaulted in the model according to :ref:`windowinputs`.

HPXML Software Info
-------------------

High-level simulation inputs are entered in ``/HPXML/SoftwareInfo``.

HPXML Simulation Control
************************

EnergyPlus simulation controls are entered in ``/HPXML/SoftwareInfo/extension/SimulationControl``:

==================================  ========  =======  =============  ========  ===========================  =====================================
Element                             Type      Units    Constraints    Required  Default                      Description
==================================  ========  =======  =============  ========  ===========================  =====================================
``Timestep``                        integer   minutes  Divisor of 60  No        60 (1 hour)                  Timestep
``BeginMonth``                      integer            1-12 [#]_      No        1 (January)                  Run period start date
``BeginDayOfMonth``                 integer            1-31           No        1                            Run period start date
``EndMonth``                        integer            1-12           No        12 (December)                Run period end date
``EndDayOfMonth``                   integer            1-31           No                                     Run period end date
``CalendarYear``                    integer            1600-9999      No        2007 (for TMY weather) [#]_  Calendar year (for start day of week)
``DaylightSaving/Enabled``          boolean                           No        true                         Daylight savings enabled?
``DaylightSaving/BeginMonth``       integer            1-12           No        EPW else 3 (March) [#]_      Daylight savings start date
``DaylightSaving/BeginDayOfMonth``  integer            1-31           No        EPW else 12                  Daylight savings start date
``DaylightSaving/EndMonth``         integer            1-12           No        EPW else 11 (November)       Daylight savings end date
``DaylightSaving/EndDayOfMonth``    integer            1-31           No        EPW else 5                   Daylight savings end date
==================================  ========  =======  =============  ========  ===========================  =====================================

.. [#] Simulation start date must occur before simulation end date (e.g., a run period from 10/1 to 3/31 is invalid).
.. [#] CalendarYear only applies to TMY (Typical Meteorological Year) weather. For AMY (Actual Meteorological Year) weather, the AMY year will be used regardless of what is specified.
.. [#] Daylight savings dates will be defined according to the EPW weather file header; if not available, fallback default values listed above will be used.

HPXML HVAC Sizing Control
*************************

HVAC equipment sizing controls are entered in ``/HPXML/SoftwareInfo/extension/HVACSizingControl``:

=================================  ========  =====  ===========  ========  =======  ============================================
Element                            Type      Units  Constraints  Required  Default  Description
=================================  ========  =====  ===========  ========  =======  ============================================
``AllowIncreasedFixedCapacities``  boolean                       No        false    Logic for fixed capacity HVAC equipment [#]_
``UseMaxLoadForHeatPumps``         boolean                       No        true     Logic for autosized heat pumps [#]_
=================================  ========  =====  ===========  ========  =======  ============================================

.. [#] If true, the larger of user-specified fixed capacity and design load will be used (to reduce potential for unmet loads); otherwise user-specified fixed capacity is used.
.. [#] If true, autosized heat pumps are sized based on the maximum of heating/cooling design loads; otherwise sized per ACCA Manual J/S based on cooling design loads with some oversizing allowances for heating design loads.

HPXML Building Summary
----------------------

High-level building summary information is entered in ``/HPXML/Building/BuildingDetails/BuildingSummary``. 

HPXML Site
**********

Building site information is entered in ``/HPXML/Building/BuildingDetails/BuildingSummary/Site``:

========================================  ========  =====  ===========  ========  ========  ============================================================
Element                                   Type      Units  Constraints  Required  Default   Notes
========================================  ========  =====  ===========  ========  ========  ============================================================
``SiteType``                              string           See [#]_     No        suburban  Terrain type for infiltration model
``extension/ShelterCoefficient``          double           0-1          No        0.5 [#]_  Nearby buildings, trees, obstructions for infiltration model
``extension/Neighbors/NeighborBuilding``  element          >= 0         No        <none>    Neighboring buildings for solar shading
========================================  ========  =====  ===========  ========  ========  ============================================================

.. [#] Choices are "rural", "suburban", or "urban".
.. [#] Shelter coefficients are described as follows:

       ===================  =========================================================================
       Shelter Coefficient  Description
       ===================  =========================================================================
       1.0                  No obstructions or local shielding
       0.9                  Light local shielding with few obstructions within two building heights
       0.7                  Local shielding with many large obstructions within two building heights
       0.5                  Heavily shielded, many large obstructions within one building height
       0.3                  Complete shielding with large buildings immediately adjacent
       ===================  =========================================================================

For each neighboring building defined, additional information is entered in ``extension/Neighbors/NeighborBuilding``:

============  ========  =======  ===========  ========  =======================  ====================================================
Element       Type      Units    Constraints  Required  Default                  Notes
============  ========  =======  ===========  ========  =======================  ====================================================
``Azimuth``   integer   degrees  0-359        Yes                                Direction of neighbors relative to the dwelling unit
``Distance``  double    ft       > 0          Yes                                Distance of neighbor from the dwelling unit
``Height``    double    ft       > 0          No        <same as dwelling unit>  Height of neighbor
============  ========  =======  ===========  ========  =======================  ====================================================


HPXML Building Occupancy
************************

Building occupancy is entered in ``/HPXML/Building/BuildingDetails/BuildingSummary/BuildingOccupancy``:

=====================  ========  =====  ===========  ========  ====================  ========================
Element                Type      Units  Constraints  Required  Default               Notes
=====================  ========  =====  ===========  ========  ====================  ========================
``NumberofResidents``  integer          >= 0         No        <number of bedrooms>  Number of occupants [#]_
=====================  ========  =====  ===========  ========  ====================  ========================

.. [#] Only used for occupant heat gain. Most occupancy assumptions (e.g., usage of plug loads, appliances, hot water, etc.) are drive by the number of bedrooms, not number of occupants.

HPXML Building Construction
***************************

Building construction is entered in ``/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction``:

=======================================  ========  =====  ===========  =============  ========  =======================================================================
Element                                  Type      Units  Constraints  Required       Default   Notes
=======================================  ========  =====  ===========  =============  ========  =======================================================================
``ResidentialFacilityType``              string           See [#]_     Yes                      Type of dwelling unit
``NumberofConditionedFloors``            integer          > 0          Yes                      Number of conditioned floors (including a basement)
``NumberofConditionedFloorsAboveGrade``  integer          > 0          Yes                      Number of conditioned floors above grade (including a walkout basement)
``NumberofBedrooms``                     integer          > 0          Yes                      Number of bedrooms
``NumberofBathrooms``                    integer          > 0          No             See [#]_  Number of bathrooms
``ConditionedFloorArea``                 double    ft2    > 0          Yes                      Floor area within conditioned space boundary
``ConditionedBuildingVolume``            double    ft3    > 0          Depends [#]_   See [#]_  Volume within conditioned space boundary
``AverageCeilingHeight``                 double    ft     > 0          Depends [#]_             Average ceiling height for conditioned floor area
``extension/HasFlueOrChimney``           boolean                       No             See [#]_  Presence of flue or chimney for infiltration model
=======================================  ========  =====  ===========  =============  ========  =======================================================================

.. [#] Choices are "single-family detached", "single-family attached", "apartment unit", or "manufactured home".
.. [#] If not provided, calculated as NumberofBedrooms/2 + 0.5 based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.
.. [#] Required if AverageCeilingHeight is not provided.
.. [#] If not provided, calculated as AverageCeilingHeight * ConditionedFloorArea.
.. [#] Required if ConditionedBuildingVolume is not provided.
.. [#] If not provided, assumed to be true if any of the following conditions are met: 
       A) heating system is non-electric Furnace, Boiler, WallFurnace, FloorFurnace, Stove, PortableHeater, or FixedHeater and AFUE/Percent is less than 0.89,
       B) heating system is non-electric Fireplace, or
       C) water heater is non-electric with energy factor (or equivalent calculated from uniform energy factor) less than 0.63.

HPXML Weather Station
---------------------

Weather information is entered in ``/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation``:

=========================  ======  =======  ===========  ========  =======  ==============================================
Element                    Type    Units    Constraints  Required  Default  Notes
=========================  ======  =======  ===========  ========  =======  ==============================================
``extension/EPWFilePath``  string                        Yes                Path to the EnergyPlus weather file (EPW) [#]_
=========================  ======  =======  ===========  ========  =======  ==============================================

.. [#] A full set of U.S. TMY3 weather files can be `downloaded here <https://data.nrel.gov/system/files/128/tmy3s-cache-csv.zip>`_.

HPXML Enclosure
---------------

The dwelling unit's enclosure is entered in ``/HPXML/Building/BuildingDetails/Enclosure``.

All surfaces that bound different space types in the building (i.e., not just thermal boundary surfaces) must be specified in the HPXML file.
For example, an attached garage would generally be defined by walls adjacent to conditioned space, walls adjacent to outdoors, a slab, and a roof or ceiling.
For software tools that do not collect sufficient inputs for every required surface, the software developers will need to make assumptions about these surfaces or collect additional input.

Interior partition surfaces (e.g., walls between rooms inside conditioned space, or the floor between two conditioned stories) can be excluded.

For Attached/Multifamily buildings, surfaces between unconditioned space and the neigboring unit's same unconditioned space should set ``InteriorAdjacentTo`` and ``ExteriorAdjacentTo`` to the same value.
For example, a foundation wall between the unit's vented crawlspace and the neighboring unit's vented crawlspace would use ``InteriorAdjacentTo="crawlspace - vented"`` and ``ExteriorAdjacentTo="crawlspace - vented"``.

.. warning::

  It is the software tool's responsibility to provide the appropriate building surfaces. 
  While some error-checking is in place, it is not possible to know whether some surfaces are incorrectly missing.

Also note that wall and roof surfaces do not require an azimuth to be specified. 
Rather, only the windows/skylights themselves require an azimuth. 
Thus, software tools can choose to use a single wall (or roof) surface to represent multiple wall (or roof) surfaces for the entire building if all their other properties (construction type, interior/exterior adjacency, etc.) are identical.

.. _spaces:

Space Types
***********

The space types used in the HPXML building description are:

==============================  ================================================  ========================================================  =========================
Space Type                      Description                                       Temperature                                               Building Type
==============================  ================================================  ========================================================  =========================
living space                    Above-grade conditioned floor area                EnergyPlus calculation                                    Any
attic - vented                                                                    EnergyPlus calculation                                    Any
attic - unvented                                                                  EnergyPlus calculation                                    Any
basement - conditioned          Below-grade conditioned floor area                EnergyPlus calculation                                    Any
basement - unconditioned                                                          EnergyPlus calculation                                    Any
crawlspace - vented                                                               EnergyPlus calculation                                    Any
crawlspace - unvented                                                             EnergyPlus calculation                                    Any
garage                          Single-family garage (not shared parking garage)  EnergyPlus calculation                                    Any
other housing unit              E.g., conditioned adjacent unit or corridor       Same as conditioned space                                 Attached/Multifamily only
other heated space              E.g., shared laundry/equipment space              Average of conditioned space and outside; minimum of 68F  Attached/Multifamily only
other multifamily buffer space  E.g., enclosed unconditioned stairwell            Average of conditioned space and outside; minimum of 50F  Attached/Multifamily only
other non-freezing space        E.g., shared parking garage ceiling               Floats with outside; minimum of 40F                       Attached/Multifamily only
==============================  ================================================  ========================================================  =========================

HPXML Air Infiltration
**********************

Building air leakage is entered in ``/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement``:

====================================  ======  =====  ===========  =============  ====================  ========================================================
Element                               Type    Units  Constraints  Required       Default               Notes
====================================  ======  =====  ===========  =============  ====================  ========================================================
``BuildingAirLeakage/UnitofMeasure``  string         See [#]_                                          Units for air leakage
``HousePressure``                     double  Pa     > 0          Depends [#]_                         House pressure with respect to outside, typically ~50 Pa
``BuildingAirLeakage/AirLeakage``     double         > 0          Yes                                  Value for air leakage
``InfiltrationVolume``                double  ft3    > 0          No             <conditioned volume>  Volume associated with the air leakage measurement
====================================  ======  =====  ===========  =============  ====================  ========================================================

.. [#] Choices are "ACH" (air changes per hour at user-specified pressure), "CFM" (cubic feet per minute at user-specified pressure), or "ACHnatural" (natural air changes per hour).
.. [#] Required if BuildingAirLeakage/UnitofMeasure is not "ACHnatural".

HPXML Attics
************

If the dwelling unit has a vented attic, attic ventilation information can be optionally entered in ``/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic[AtticType/Attic[Vented="true"]]/VentilationRate``:

=================  ======  =====  ===========  ========  ========  ==========================
Element            Type    Units  Constraints  Required  Default   Notes
=================  ======  =====  ===========  ========  ========  ==========================
``UnitofMeasure``  string         See [#]_     No                  Units for ventilation rate
``Value``          double         > 0          No        See [#]_  Value for ventilation rate
=================  ======  =====  ===========  ========  ========  ==========================

.. [#] Choices are "SLA" (specific leakage area) or "ACHnatural" (natural air changes per hour).
.. [#] If not provided, calculated as SLA=1/300 based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.

HPXML Foundations
*****************

If the dwelling unit has a vented crawlspace, crawlspace ventilation information can be optionally entered in ``/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/Crawlspace[Vented="true"]]/VentilationRate``:

=================  ======  =====  ===========  ========  ========  ==========================
Element            Type    Units  Constraints  Required  Default   Notes
=================  ======  =====  ===========  ========  ========  ==========================
``UnitofMeasure``  string         See [#]_     No                  Units for ventilation rate
``Value``          double         > 0          No        See [#]_  Value for ventilation rate
=================  ======  =====  ===========  ========  ========  ==========================

.. [#] "SLA" (specific leakage area) is required.
.. [#] If not provided, calculated as SLA=1/150 based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.

HPXML Roofs
***********

Each pitched or flat roof surface that is exposed to ambient conditions should be entered as an ``/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof``.

For a multifamily building where the dwelling unit has another dwelling unit above it, the surface between the two dwelling units should be considered a ``FrameFloor`` and not a ``Roof``.

======================================  ========  ============  ==============  =============  ==============================  ==================================
Element                                 Type      Units         Constraints     Required       Default                         Notes
======================================  ========  ============  ==============  =============  ==============================  ==================================
``InteriorAdjacentTo``                  string                  :ref:`spaces`   Yes                                            Interior adjacent space type
``Area``                                double    ft2           > 0             Yes                                            Gross area (including skylights)
``Azimuth``                             integer   degrees       0-359           No             See [#]_                        Azimuth
``RoofType``                            string                  See [#]_        No             asphalt or fiberglass shingles  Roof type
``SolarAbsorptance``                    double                  0-1             Depends [#]_   See [#]_                        Solar absorptance
``RoofColor``                           string                  See [#]_        Depends [#]_                                   Color
``Emittance``                           double                  0-1             Yes                                            Emittance
``Pitch``                               integer   ?:12          >= 0            Yes                                            Pitch
``RadiantBarrier``                      boolean                                 Yes                                            Presence of radiant barrier
``RadiantBarrier/RadiantBarrierGrade``  integer                 1-3             Depends [#]_                                   Radiant barrier installation grade
``Insulation/AssemblyEffectiveRValue``  double    F-ft2-hr/Btu  > 0             Yes                                            Assembly R-value [#]_
======================================  ========  ============  ==============  =============  ==============================  ==================================

.. [#] If not provided, modeled as four surfaces of equal area facing every direction.
.. [#] Choices are "asphalt or fiberglass shingles", "wood shingles or shakes", "slate or tile shingles", or "metal surfacing".
.. [#] Required if RoofColor is not provided.
.. [#] If not provided, defaulted based on the mapping below:

       ===========  =======================================================  ================
       RoofColor    RoofMaterial                                             SolarAbsorptance
       ===========  =======================================================  ================
       dark         asphalt or fiberglass shingles, wood shingles or shakes  0.92
       medium dark  asphalt or fiberglass shingles, wood shingles or shakes  0.89
       medium       asphalt or fiberglass shingles, wood shingles or shakes  0.85
       light        asphalt or fiberglass shingles, wood shingles or shakes  0.75
       reflective   asphalt or fiberglass shingles, wood shingles or shakes  0.50
       dark         slate or tile shingles, metal surfacing                  0.90
       medium dark  slate or tile shingles, metal surfacing                  0.83
       medium       slate or tile shingles, metal surfacing                  0.75
       light        slate or tile shingles, metal surfacing                  0.60
       reflective   slate or tile shingles, metal surfacing                  0.30
       ===========  =======================================================  ================

.. [#] Choices are "light", "medium", "medium dark", "dark", or "reflective".
.. [#] Required if SolarAbsorptance is not provided.
.. [#] Required if RadiantBarrier is provided.
.. [#] Assembly R-value includes all material layers, interior/exterior air films, and insulation installation grade.

HPXML Rim Joists
****************

Each rim joist surface (i.e., the perimeter of floor joists typically found between stories of a building or on top of a foundation wall) are entered as an ``/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist``.

======================================  ========  ============  ==============  =============  ===========  ============================
Element                                 Type      Units         Constraints     Required       Default      Notes
======================================  ========  ============  ==============  =============  ===========  ============================
``ExteriorAdjacentTo``                  string                  :ref:`spaces`   Yes                         Exterior adjacent space type
``InteriorAdjacentTo``                  string                  :ref:`spaces`   Yes                         Interior adjacent space type
``Area``                                double    ft2           > 0             Yes                         Gross area
``Azimuth``                             integer   degrees       0-359           No             See [#]_     Azimuth
``Siding``                              string                  See [#]_        No             wood siding  Siding material
``SolarAbsorptance``                    double                  0-1             Depends [#]_   See [#]_     Solar absorptance
``Color``                               string                  See [#]_        Depends [#]_                Color
``Emittance``                           double                  0-1             Yes                         Emittance
``Insulation/AssemblyEffectiveRValue``  double    F-ft2-hr/Btu  > 0             Yes                         Assembly R-value [#]_
======================================  ========  ============  ==============  =============  ===========  ============================

.. [#] If not provided, modeled as four surfaces of equal area facing every direction.
.. [#] Choices are "wood siding", "vinyl siding", "stucco", "fiber cement siding", "brick veneer", or "aluminum siding".
.. [#] Required if Color is not provided.
.. [#] If not provided, defaulted based on the mapping below:
        
       =========== ================
       Color       SolarAbsorptance
       =========== ================
       dark        0.95
       medium dark 0.85
       medium      0.70
       light       0.50
       reflective  0.30
       =========== ================

.. [#] Choices are "light", "medium", "medium dark", "dark", or "reflective".
.. [#] Required if SolarAbsorptance is not provided.
.. [#] Assembly R-value includes all material layers, interior/exterior air films, and insulation installation grade.

HPXML Walls
***********

Each wall that has no contact with the ground and bounds a space type should be entered as an ``/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall``.

======================================  ========  ============  ==============  =============  ===========  ====================================
Element                                 Type      Units         Constraints     Required       Default      Notes
======================================  ========  ============  ==============  =============  ===========  ====================================
``ExteriorAdjacentTo``                  string                  :ref:`spaces`   Yes                         Exterior adjacent space type
``InteriorAdjacentTo``                  string                  :ref:`spaces`   Yes                         Interior adjacent space type
``WallType``                            element                 See [#]_        Yes                         Wall type (for thermal mass)
``Area``                                double    ft2           > 0             Yes                         Gross area (including doors/windows)
``Azimuth``                             integer   degrees       0-359           No             See [#]_     Azimuth
``Siding``                              string                  See [#]_        No             wood siding  Siding material
``SolarAbsorptance``                    double                  0-1             Depends [#]_   See [#]_     Solar absorptance
``Color``                               string                  See [#]_        Depends [#]_                Color
``Emittance``                           double                  0-1             Yes                         Emittance
``Insulation/AssemblyEffectiveRValue``  double    F-ft2-hr/Btu  > 0             Yes                         Assembly R-value [#]_
======================================  ========  ============  ==============  =============  ===========  ====================================

.. [#] Child element choices are ``WoodStud``, ``DoubleWoodStud``, ``ConcreteMasonryUnit``, ``StructurallyInsulatedPanel``, ``InsulatedConcreteForms``, ``SteelFrame``, ``SolidConcrete``, ``StructuralBrick``, ``StrawBale``, ``Stone``, ``LogWall``, or ``Adobe``.
.. [#] If not provided, modeled as four surfaces of equal area facing every direction.
.. [#] Choices are "wood siding", "vinyl siding", "stucco", "fiber cement siding", "brick veneer", or "aluminum siding".
.. [#] Required if Color is not provided.
.. [#] If not provided, defaulted based on the mapping below:
        
       =========== ================
       Color       SolarAbsorptance
       =========== ================
       dark        0.95
       medium dark 0.85
       medium      0.70
       light       0.50
       reflective  0.30
       =========== ================

.. [#] Choices are "light", "medium", "medium dark", "dark", or "reflective".
.. [#] Required if SolarAbsorptance is not provided.
.. [#] Assembly R-value includes all material layers, interior/exterior air films, and insulation installation grade.

HPXML Foundation Walls
**********************

Each wall that is in contact with the ground should be specified as an ``/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall``.

Other walls (e.g., wood framed walls) that are connected to a below-grade space but have no contact with the ground should be specified as a ``Wall`` and not a ``FoundationWall``.

==============================================================  ========  ============  ==============  =============  ========  ====================================
Element                                                         Type      Units         Constraints     Required       Default   Notes
==============================================================  ========  ============  ==============  =============  ========  ====================================
``ExteriorAdjacentTo``                                          string                  :ref:`spaces`   Yes                      Exterior adjacent space type [#]_
``InteriorAdjacentTo``                                          string                  :ref:`spaces`   Yes                      Interior adjacent space type
``Height``                                                      double    ft            > 0             Yes                      Total height
``Area``                                                        double    ft2           > 0             Yes                      Gross area (including doors/windows)
``Azimuth``                                                     integer   degrees       0-359           No             See [#]_  Azimuth
``Thickness``                                                   double    inches        > 0             Yes                      Thickness excluding interior framing
``DepthBelowGrade``                                             double    ft            >= 0            Yes                      Depth below grade [#]_
``Insulation/Layer[InstallationType="continuous - interior"]``  element                                 Depends [#]_             Interior insulation layer
``Insulation/Layer[InstallationType="continuous - exterior"]``  element                                 Depends [#]_             Exterior insulation layer
``Insulation/AssemblyEffectiveRValue``                          double    F-ft2-hr/Btu  > 0             Yes                      Assembly R-value [#]_
==============================================================  ========  ============  ==============  =============  ========  ====================================

.. [#] Interior foundation walls (e.g., between basement and crawlspace) should **not** use "ground" even if the foundation wall has some contact with the ground due to the difference in below-grade depths of the two adjacent spaces.
.. [#] If not provided, modeled as four surfaces of equal area facing every direction.
.. [#] For exterior foundation walls, depth below grade is relative to the ground plane.
       For interior foundation walls, depth below grade is the vertical span of foundation wall in contact with the ground.
       For example, an interior foundation wall between an 8 ft conditioned basement and a 3 ft crawlspace has a height of 8 ft and a depth below grade of 5 ft.
       Alternatively, an interior foundation wall between an 8 ft conditioned basement and an 8 ft unconditioned basement has a height of 8 ft and a depth below grade of 0 ft.
.. [#] Required if Insulation/AssemblyEffectiveRValue is not provided.
.. [#] Required if Insulation/AssemblyEffectiveRValue is not provided.
.. [#] Assembly R-value includes all material layers, interior air film, and insulation installation grade.
       R-value should **not** include exterior air film (for any above-grade exposure) or any soil thermal resistance.

If insulation layers are provided, additional information is entered in each ``FoundationWall/Insulation/Layer``:

==========================================  ========  ============  ===========  ========  =======  ======================================================================
Element                                     Type      Units         Constraints  Required  Default  Notes
==========================================  ========  ============  ===========  ========  =======  ======================================================================
``NominalRValue``                           double    F-ft2-hr/Btu  >= 0         Yes                R-value of the foundatation wall insulation; use zero if no insulation
``extension/DistanceToTopOfInsulation``     double    ft            >= 0         Yes                Vertical distance from top of foundation wall to top of insulation
``extension/DistanceToBottomOfInsulation``  double    ft            >= 0         Yes                Vertical distance from top of foundation wall to bottom of insulation
==========================================  ========  ============  ===========  ========  =======  ======================================================================

HPXML Frame Floors
******************

Each horizontal floor/ceiling surface that is not in contact with the ground (Slab) nor adjacent to ambient conditions above (Roof) should be entered as an ``/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor``.

======================================  ========  ============  ==============  ========  =======  ============================
Element                                 Type      Units         Constraints     Required  Default  Notes
======================================  ========  ============  ==============  ========  =======  ============================
``ExteriorAdjacentTo``                  string                  :ref:`spaces`   Yes                Exterior adjacent space type
``InteriorAdjacentTo``                  string                  :ref:`spaces`   Yes                Interior adjacent space type
``Area``                                double    ft2           > 0             Yes                Gross area
``Insulation/AssemblyEffectiveRValue``  double    F-ft2-hr/Btu  > 0             Yes                Assembly R-value [#]_
======================================  ========  ============  ==============  ========  =======  ============================

.. [#] Assembly R-value includes all material layers, interior/exterior air films, and insulation installation grade.

For frame floors adjacent to "other housing unit", "other heated space", "other multifamily buffer space", or "other non-freezing space", additional information is entered in ``FrameFloor``:

======================================  ========  =====  ==============  ========  =======  ==========================================
Element                                 Type      Units  Constraints     Required  Default  Notes
======================================  ========  =====  ==============  ========  =======  ==========================================
``extension/OtherSpaceAboveOrBelow``    string           See [#]_        Yes                Specifies if above/below the MF space type
======================================  ========  =====  ==============  ========  =======  ==========================================

.. [#] Choices are "above" or "below".

HPXML Slabs
***********

Each space type that borders the ground (i.e., basements, crawlspaces, garages, and slab-on-grade foundations) should have a slab entered as an ``/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab``:

===========================================  ========  ============  ==============  =============  =======  ====================================================
Element                                      Type      Units         Constraints     Required       Default  Notes
===========================================  ========  ============  ==============  =============  =======  ====================================================
``InteriorAdjacentTo``                       string                  :ref:`spaces`   Yes                     Interior adjacent space type
``Area``                                     double    ft2           > 0             Yes                     Gross area
``Thickness``                                double    inches        >= 0            Yes                     Thickness [#]_
``ExposedPerimeter``                         double    ft            > 0             Yes                     Perimeter exposed to ambient conditions [#]_
``PerimeterInsulationDepth``                 double    ft            >= 0            Yes                     Depth from grade to bottom of vertical insulation
``UnderSlabInsulationWidth``                 double    ft            >= 0            Depends [#]_            Width from slab edge inward of horizontal insulation
``UnderSlabInsulationSpansEntireSlab``       boolean                                 Depends [#]_            Whether horizontal insulation spans entire slab
``DepthBelowGrade``                          double    ft            >= 0            Depends [#]_            Depth from the top of the slab surface to grade
``PerimeterInsulation/Layer/NominalRValue``  double    F-ft2-hr/Btu  >= 0            Yes                     R-value of vertical insulation
``UnderSlabInsulation/Layer/NominalRValue``  double    F-ft2-hr/Btu  >= 0            Yes                     R-value of horizontal insulation
``extension/CarpetFraction``                 double                  0-1             Yes                     Fraction of slab covered by carpet
``extension/CarpetRValue``                   double    F-ft2-hr/Btu  >= 0            Yes                     Carpet R-value
===========================================  ========  ============  ==============  =============  =======  ====================================================

.. [#] For a crawlspace with a dirt floor, use a thickness of zero.
.. [#] Exposed perimeter should include any slab length that falls along the perimeter of the building's footprint (i.e., is exposed to ambient conditions).
       So a basement slab edge adjacent to a garage or crawlspace, for example, should not be included.
.. [#] Required if UnderSlabInsulationSpansEntireSlab=true is not provided.
.. [#] Required (with a value of true) if UnderSlabInsulationWidth is not provided.
.. [#] Required if the attached foundation has no ``FoundationWalls``.
       For foundation types with walls, the the slab's position relative to grade is determined by the ``FoundationWall/DepthBelowGrade`` value.

.. _windowinputs:

HPXML Windows
*************

Each window or glass door area should be entered as an ``/HPXML/Building/BuildingDetails/Enclosure/Windows/Window``:

============================================  ========  ============  ===========  ========  =========  ==============================================
Element                                       Type      Units         Constraints  Required  Default    Notes
============================================  ========  ============  ===========  ========  =========  ==============================================
``Area``                                      double    ft2           > 0          Yes                  Total area
``Azimuth``                                   integer   degrees       0-359        Yes                  Azimuth
``UFactor``                                   double    Btu/F-ft2-hr  > 0          Yes                  Full-assembly NFRC U-factor
``SHGC``                                      double                  0-1          Yes                  Full-assembly NFRC solar heat gain coefficient
``InteriorShading/SummerShadingCoefficient``  double                  0-1          No        0.70 [#]_  Summer interior shading coefficient
``InteriorShading/WinterShadingCoefficient``  double                  0-1          No        0.85 [#]_  Winter interior shading coefficient
``Overhangs``                                 element                 >= 0         No        <none>     Presence of overhangs (including eaves)
``FractionOperable``                          double                  0-1          No        0.67       Operable fraction [#]_
``AttachedToWall``                            idref                                Yes                  ID of ``Wall`` or ``FoundationWall``
============================================  ========  ============  ===========  ========  =========  ==============================================

.. [#] Default value indicates 30% reduction in solar heat gain, based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.
.. [#] Default value indicates 15% reduction in solar heat gain, based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.
.. [#] Should reflect whether the windows are operable (can be opened), not how they are used by the occupants.
       If a ``Window`` represents a single window, the value should be 0 or 1.
       If a ``Window`` represents multiple windows (e.g., 4), the value should be between 0 and 1 (e.g., 0, 0.25, 0.5, 0.75, or 1).
       The total open window area for natural ventilation is calculated using A) the operable fraction, B) the assumption that 50% of the area of operable windows can be open, and C) the assumption that 20% of that openable area is actually opened by occupants whenever outdoor conditions are favorable for cooling.

If overhangs are specified, additional information is entered in ``Overhangs``:

============================  ========  ======  ===========  ========  =======  ========================================================
Element                       Type      Units   Constraints  Required  Default  Notes
============================  ========  ======  ===========  ========  =======  ========================================================
``Depth``                     double    inches  > 0          Yes                Depth of overhang
``DistanceToTopOfWindow``     double    ft      >= 0         Yes                Vertical distance from overhang to top of window
``DistanceToBottomOfWindow``  double    ft      >= 0         Yes                Vertical distance from overhang to bottom of window [#]_
============================  ========  ======  ===========  ========  =======  ========================================================

.. [#] The difference between DistanceToBottomOfWindow and DistanceToTopOfWindow defines the height of the window.

HPXML Skylights
***************

Each skylight should be entered as an ``/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight``:

============================================  ========  ============  ===========  ========  =========  ==============================================
Element                                       Type      Units         Constraints  Required  Default    Notes
============================================  ========  ============  ===========  ========  =========  ==============================================
``Area``                                      double    ft2           > 0          Yes                  Total area
``Azimuth``                                   integer   degrees       0-359        Yes                  Azimuth
``UFactor``                                   double    Btu/F-ft2-hr  > 0          Yes                  Full-assembly NFRC U-factor
``SHGC``                                      double                  0-1          Yes                  Full-assembly NFRC solar heat gain coefficient
``InteriorShading/SummerShadingCoefficient``  double                  0-1          No        1.0 [#]_   Summer interior shading coefficient
``InteriorShading/WinterShadingCoefficient``  double                  0-1          No        1.0 [#]_   Winter interior shading coefficient
``AttachedToRoof``                            idref                                Yes                  ID of ``Roof``
============================================  ========  ============  ===========  ========  =========  ==============================================

.. [#] Default value indicates 0% reduction in solar heat gain.
.. [#] Default value indicates 0% reduction in solar heat gain.

HPXML Doors
***********

Each opaque door should be entered as an ``/HPXML/Building/BuildingDetails/Enclosure/Doors/Door``:

============================================  ========  ============  ===========  ========  =========  ==============================================
Element                                       Type      Units         Constraints  Required  Default    Notes
============================================  ========  ============  ===========  ========  =========  ==============================================
``AttachedToWall``                            idref                                Yes                  ID of ``Wall`` or ``FoundationWall``
``Area``                                      double    ft2           > 0          Yes                  Total area
``Azimuth``                                   integer   degrees       0-359        Yes                  Azimuth
``RValue``                                    double    F-ft2-hr/Btu  > 0          Yes                  R-value
============================================  ========  ============  ===========  ========  =========  ==============================================

HPXML Systems
-------------

The dwelling unit's systems are entered in ``/HPXML/Building/BuildingDetails/Systems``.

HPXML Heating Systems
*********************

Each heating system (other than heat pumps) should be entered as an ``/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem``:

=================================  ========  ======  ===========  ========  =========  ====================================
Element                            Type      Units   Constraints  Required  Default    Notes
=================================  ========  ======  ===========  ========  =========  ====================================
``HeatingSystemType``              element           See [#]_     Yes                  Type of heating system
``FractionHeatLoadServed``         double            0-1          Yes                  Fraction of heating load served [#]_
``HeatingSystemFuel``              string            See [#]_     Yes                  Fuel type
``AnnualHeatingEfficiency/Units``  string            See [#]_     Yes                  Efficiency units
``AnnualHeatingEfficiency/Value``  double            0-1          Yes                  Efficiency value
``HeatingCapacity``                double    Btu/hr  >= 0         No        autosized  Input heating capacity [#]_
=================================  ========  ======  ===========  ========  =========  ====================================

.. [#] Child element choices are ``ElectricResistance``, ``Furnace``, ``WallFurnace``, ``FloorFurnace``, ``Boiler``, ``Stove``, ``PortableHeater``, ``FixedHeater``, or ``Fireplace``.
.. [#] The sum of all ``FractionHeatLoadServed`` (across both HeatingSystems and HeatPumps) must be less than or equal to 1.
       For example, the dwelling unit could have a boiler heating system and a heat pump with values of 0.4 (40%) and 0.6 (60%), respectively.
.. [#] "electricity" required for ``Resistance`` heating systems.
       Choices for all other systems are  "electricity", "natural gas", "fuel oil", "fuel oil 1", "fuel oil 2", "fuel oil 4", "fuel oil 5/6", "diesel", "propane", "kerosene", "coal", "coke", "bituminous coal", "wood", or "wood pellets".
.. [#] "AFUE" required for ``Furnace``, ``WallFurnace``, ``FloorFurnace``, and ``Boiler``.
       "Percent" required for all other systems.
.. [#] Not applicable to shared boilers.

If a **Furnace** is specified, additional information is entered in ``HeatingSystem``:

=================================  ========  =====  ===========  ========  =========  ==========================
Element                            Type      Units  Constraints  Required  Default    Notes
=================================  ========  =====  ===========  ========  =========  ==========================
``DistributionSystem``             idref            See [#]_     Yes                  ID of ``HVACDistribution``
``extension/FanPowerWattsPerCFM``  double    W/cfm  >= 0         No        See [#]_   Installed fan efficiency
=================================  ========  =====  ===========  ========  =========  ==========================

.. [#] HVACDistribution type must be AirDistribution or DSE.
.. [#] If not provided, defaulted as 0.5 W/cfm if AFUE <= 0.9, else 0.375 W/cfm.

If a **WallFurnace**, **FloorFurnace**, **Stove**, **PortableHeater**, **FixedHeater**, or **Fireplace** is specified, additional information is entered in ``HeatingSystem``:

===========================  ========  =====  ===========  ============  =========  ===================
Element                      Type      Units  Constraints  Required      Default    Notes
===========================  ========  =====  ===========  ============  =========  ===================
``extension/FanPowerWatts``  double    W      >= 0         No            See [#]_   Installed fan power
===========================  ========  =====  ===========  ============  =========  ===================

.. [#] If not provided, defaulted as 40 W for ``Stove`` and 0 W for all other systems.

If a **Boiler** is specified, additional information is entered in ``HeatingSystem``:

===========================  ========  ======  ===========  ========  ========  =========================================
Element                      Type      Units   Constraints  Required  Default   Notes
===========================  ========  ======  ===========  ========  ========  =========================================
``IsSharedSystem``           boolean                        No        false     Whether it serves multiple dwelling units
``DistributionSystem``       idref                          Yes       See [#]_  ID of ``HVACDistribution``
``ElectricAuxiliaryEnergy``  double    kWh/yr  >= 0         No [#]_   See [#]_  Electric auxiliary energy
===========================  ========  ======  ===========  ========  ========  =========================================

.. [#] HVACDistribution type must be HydronicDistribution or DSE for in-unit boilers and HydronicDistribution or HydronicAndAirDistribution for shared boilers.
.. [#] For shared boilers, the electric auxiliary energy can alternatively be calculated as follows per `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_:

       | :math:`EAE = (\frac{SP}{N_{dweq}} + aux_{in}) \cdot HLH`
       | where, 
       |   :math:`SP` = Shared pump power [W], provided as ``extension/SharedLoopWatts``
       |   :math:`N_{dweq}` = Number of units served by the shared system, provided as ``NumberofUnitsServed``
       |   :math:`aux_{in}` = In-unit fan coil power [W], provided as ``extension/FanCoilWatts``
       |   :math:`HLH` = Annual heating load hours

.. [#] If not provided (or calculated for shared boilers), defaults as follows per `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_:

       ============================================  ==============================
       System Type                                   Electric Auxiliary Energy
       ============================================  ==============================
       Oil boiler                                    330
       Gas boiler (in-unit)                          170
       Gas boiler (shared, w/ baseboard)             220
       Gas boiler (shared, w/ water loop heat pump)  265
       Gas boiler (shared, w/ fan coil)              438
       ============================================  ==============================

For shared boilers connected to a water loop heat pump, the heat pump's heating COP must be provided as ``extension/WaterLoopHeatPump/AnnualHeatingEfficiency[Units="COP"]/Value``.

HPXML Cooling Systems
*********************

Each cooling system (other than heat pumps) should be entered as an ``/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem``:

==========================  ========  ======  ===========  ========  =======  ====================================
Element                     Type      Units   Constraints  Required  Default  Notes
==========================  ========  ======  ===========  ========  =======  ====================================
``CoolingSystemType``       string            See [#]_     Yes                Type of cooling system
``CoolingSystemFuel``       string            electricity  Yes                Fuel type
``FractionCoolLoadServed``  double            0-1          Yes                Fraction of cooling load served [#]_
==========================  ========  ======  ===========  ========  =======  ====================================

.. [#] Choices are "central air conditioner", "room air conditioner", "evaporative cooler", "mini-split", "chiller", or "cooling tower".
.. [#] The sum of all ``FractionCoolLoadServed`` (across both CoolingSystems and HeatPumps) must be less than or equal to 1.
       For example, the dwelling unit could have two room air conditioners with values of 0.1 (10%) and 0.2 (20%), respectively, with the rest of the home (70%) uncooled.

If a **central air conditioner** is specified, additional information is entered in ``CoolingSystem``:

=================================  ========  ======  ===========  ========  =========  ==========================
Element                            Type      Units   Constraints  Required  Default    Notes
=================================  ========  ======  ===========  ========  =========  ==========================
``DistributionSystem``             idref             See [#]_     Yes                  ID of ``HVACDistribution``
``AnnualCoolingEfficiency/Units``  string            SEER         Yes                  Efficiency units
``AnnualCoolingEfficiency/Value``  double            > 0          Yes                  Efficiency value
``CoolingCapacity``                double    Btu/hr  >= 0         No        autosized  Cooling capacity
``SensibleHeatFraction``           double            0-1          No        <TODO>     Sensible heat fraction
``CompressorType``                 string            See [#]_     No        See [#]_   Type of compressor
``extension/FanPowerWattsPerCFM``  double    W/cfm   >= 0         No        See [#]_   Installed fan efficiency
=================================  ========  ======  ===========  ========  =========  ==========================

.. [#] HVACDistribution type must be AirDistribution or DSE.
.. [#] Choices are "single stage", "two stage", or "variable speed".
.. [#] If not provided, defaults to "single stage" if SEER <= 15, else "two stage" if SEER <= 21, else "variable speed".
.. [#] If not provided, defaults to using attached furnace W/cfm if available, else 0.5 W/cfm if SEER <= 13.5, else 0.375 W/cfm.

If a **room air conditioner** is specified, additional information is entered in ``CoolingSystem``:

=================================  ========  ======  ===========  ========  =========  ======================
Element                            Type      Units   Constraints  Required  Default    Notes
=================================  ========  ======  ===========  ========  =========  ======================
``AnnualCoolingEfficiency/Units``  string            EER          Yes                  Efficiency units
``AnnualCoolingEfficiency/Value``  double            > 0          Yes                  Efficiency value
``CoolingCapacity``                double    Btu/hr  >= 0         No        autosized  Cooling capacity
``SensibleHeatFraction``           double            0-1          No        <TODO>     Sensible heat fraction
=================================  ========  ======  ===========  ========  =========  ======================

If an **evaporative cooler** is specified, additional information is entered in ``CoolingSystem``:

=================================  ========  ======  ===========  ========  =========  ==========================
Element                            Type      Units   Constraints  Required  Default    Notes
=================================  ========  ======  ===========  ========  =========  ==========================
``DistributionSystem``             idref             See [#]_     No                   ID of ``HVACDistribution``
``extension/FanPowerWattsPerCFM``  double    W/cfm   >= 0         No        See [#]_   Installed fan efficiency
=================================  ========  ======  ===========  ========  =========  ==========================

.. [#] HVACDistribution type must be AirDistribution or DSE.
.. [#] If not provided, defaults to MIN(2.79 * cfm^-0.29, 0.6) W/cfm.

If a **mini-split** is specified, additional information is entered in ``CoolingSystem``:

=================================  ========  ======  ===========  ========  =========  ====================================
Element                            Type      Units   Constraints  Required  Default    Notes
=================================  ========  ======  ===========  ========  =========  ====================================
``DistributionSystem``             idref             See [#]_     No                   ID of ``HVACDistribution``
``CoolingCapacity``                double    Btu/hr  >= 0         No        autosized  Cooling capacity
``SensibleHeatFraction``           double            0-1          No        <TODO>     Sensible heat fraction
``extension/FanPowerWattsPerCFM``  double    W/cfm   >= 0         No        See [#]_   Installed fan efficiency
=================================  ========  ======  ===========  ========  =========  ====================================

.. [#] HVACDistribution type must be AirDistribution or DSE.
.. [#] If not provided, defaults to 0.07 W/cfm if ductless, else 0.18 W/cfm.

If a **chiller** is specified, additional information is entered in ``CoolingSystem``:

=================================  ========  ======  ===========  ========  =========  ====================================
Element                            Type      Units   Constraints  Required  Default    Notes
=================================  ========  ======  ===========  ========  =========  ====================================
``IsSharedSystem``                 boolean           true         Yes                  Whether it serves multiple dwelling units
``DistributionSystem``             idref             See [#]_     Yes                  ID of ``HVACDistribution``
=================================  ========  ======  ===========  ========  =========  ====================================

.. [#] HVACDistribution type must be HydronicDistribution or HydronicAndAirDistribution.

Chillers are modeled with a SEER equivalent using the following equation from `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_:

  | :math:`SEER_{eq} = \frac{(Cap - (aux \cdot 3.41)) - (aux_{dweq} \cdot 3.41 \cdot N_{dweq})}{(Input \cdot aux) + (aux_{dweq} \cdot N_{dweq})}`
  | where, 
  |   :math:`Cap` = Chiller system output [Btu/hour], provided as ``CoolingCapacity``
  |   :math:`aux` = Total of the pumping and fan power serving the system [W], provided as ``extension/SharedLoopWatts``
  |   :math:`aux_{dweq}` = Total of the in-unit cooling equipment power serving the unit; for example, includes all power to run a Water Loop Heat Pump within the unit, not just air handler power [W], provided as ``extension/FanCoilWatts`` for fan coils, or calculated as ``extension/WaterLoopHeatPump/CoolingCapacity`` divided by ``extension/WaterLoopHeatPump/AnnualCoolingEfficiency[Units="EER"]/Value`` for cooling towers, or zero for baseboard/radiators
  |   :math:`Input` = Chiller system power [W], calculated using ``AnnualCoolingEfficiency[Units="kW/ton"]/Value``
  |   :math:`N_{dweq}` = Number of units served by the shared system, provided as ``NumberofUnitsServed``

If a **cooling tower** is specified, additional information is entered in ``CoolingSystem``:

=================================  ========  ======  ===========  ========  =========  ====================================
Element                            Type      Units   Constraints  Required  Default    Notes
=================================  ========  ======  ===========  ========  =========  ====================================
``IsSharedSystem``                 boolean           true         Yes                  Whether it serves multiple dwelling units
``DistributionSystem``             idref             See [#]_     Yes                  ID of ``HVACDistribution``
=================================  ========  ======  ===========  ========  =========  ====================================

.. [#] HVACDistribution type must be HydronicAndAirDistribution.

Cooling towers with water loop heat pumps are modeled with a SEER equivalent using the following equation from `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_:

  | :math:`SEER_{eq} = \frac{WLHP_{cap} - \frac{aux \cdot 3.41}{N_{dweq}}}{Input + \frac{aux}{N_{dweq}}}`
  | where, 
  |   :math:`WLHP_{cap}` = WLHP cooling capacity [Btu/hr], provided as ``extension/WaterLoopHeatPump/CoolingCapacity``
  |   :math:`aux` = Total of the pumping and fan power serving the system [W], provided as ``extension/SharedLoopWatts``
  |   :math:`N_{dweq}` = Number of units served by the shared system, provided as ``NumberofUnitsServed``
  |   :math:`Input` = WLHP system power [W], calculated as ``extension/WaterLoopHeatPump/CoolingCapacity`` divided by ``extension/WaterLoopHeatPump/AnnualCoolingEfficiency[Units="EER"]/Value``

HPXML Heat Pumps
****************

Each heat pump should be entered as a ``Systems/HVAC/HVACPlant/HeatPump``.
Inputs including ``HeatPumpType``, ``FractionHeatLoadServed``, and ``FractionCoolLoadServed`` must be provided.
Note that heat pumps are allowed to provide only heating (``FractionCoolLoadServed`` = 0) or cooling (``FractionHeatLoadServed`` = 0) if appropriate.

Depending on the type of heat pump specified, additional elements are used:

=============  ==============  =================================  ============  =======================  =======================  ===========================  ==================  =============================  ==============================
HeatPumpType   IsSharedSystem  DistributionSystem                 HeatPumpFuel  AnnualCoolingEfficiency  AnnualHeatingEfficiency  CoolingSensibleHeatFraction  HeatingCapacity17F  extension/FanPowerWattsPerCFM  extension/PumpPowerWattsPerTon
=============  ==============  =================================  ============  =======================  =======================  ===========================  ==================  =============================  ==============================
air-to-air                     AirDistribution or DSE             electricity   SEER                     HSPF                     (optional)                   (optional)          (optional)
mini-split                     AirDistribution or DSE (optional)  electricity   SEER                     HSPF                     (optional)                   (optional)          (optional)
ground-to-air  false           AirDistribution or DSE             electricity   EER                      COP                      (optional)                                       (optional)                     (optional)
ground-to-air  true            AirDistribution or DSE             electricity   EER                      COP                      (optional)                                       (optional)                     (optional)
=============  ==============  =================================  ============  =======================  =======================  ===========================  ==================  =============================  ==============================

When ``HeatingCapacity`` and ``CoolingCapacity`` are not provided, the system will be auto-sized via ACCA Manual J/S.

Air-to-air heat pumps can also have the ``CompressorType`` specified; if not provided, it is assumed as follows:

- "single stage": SEER <= 15
- "two stage": 15 < SEER <= 21
- "variable speed": SEER > 21

If the fan power is not provided (``extension/FanPowerWattsPerCFM``), it will be defaulted as follows:

==========================  ==============================
System Type                 Fan Power
==========================  ==============================
air-to-air, ground-to-air   0.5 W/cfm if HSPF <= 8.75 W/cfm, else 0.375 W/cfm
mini-split                  0.07 W/cfm if ductless, else 0.18 W/cfm
==========================  ==============================

If the heat pump has backup heating, it can be specified with ``BackupSystemFuel``, ``BackupAnnualHeatingEfficiency``, and (optionally) ``BackupHeatingCapacity``.
If the heat pump has a switchover temperature (e.g., dual-fuel heat pump) where the heat pump stops operating and the backup heating system starts running, it can be specified with ``BackupHeatingSwitchoverTemperature``.
If ``BackupHeatingSwitchoverTemperature`` is not provided, the backup heating system will operate as needed when the heat pump has insufficient capacity.

If the pump power for ground-to-air heat pumps is not provided (``extension/PumpPowerWattsPerTon``), it will be defaulted as 30 W/ton of cooling capacity per `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_ for a closed loop system

For multiple ground source heat pumps on a shared hydronic circulation loop (``IsSharedSystem="true"``), the loop's annual electric consumption is calculated using the following equation from `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_:

  | :math:`Eae = \frac{SP}{N_{dweq}} \cdot 8.760`
  | where, 
  |   :math:`SP` = Shared pump power [W], provided as ``extension/SharedLoopWatts``
  |   :math:`N_{dweq}` = Number of units served by the shared system, provided as ``NumberofUnitsServed``

HPXML HVAC Control
******************

A ``Systems/HVAC/HVACControl`` must be provided if any HVAC systems are specified.
The heating setpoint (``SetpointTempHeatingSeason``) and cooling setpoint (``SetpointTempCoolingSeason``) are required elements.

If there is a heating setback, it is defined with:

- ``SetbackTempHeatingSeason``: Temperature during heating setback
- ``extension/SetbackStartHourHeating``: The start hour of the heating setback where 0=midnight and 12=noon
- ``TotalSetbackHoursperWeekHeating``: The number of hours of heating setback per week

If there is a cooling setup, it is defined with:

- ``SetupTempCoolingSeason``: Temperature during cooling setup
- ``extension/SetupStartHourCooling``: The start hour of the cooling setup where 0=midnight and 12=noon
- ``TotalSetupHoursperWeekCooling``: The number of hours of cooling setup per week

Finally, if there are sufficient ceiling fans present that result in a reduced cooling setpoint, this offset can be specified with ``extension/CeilingFanSetpointTempCoolingSeasonOffset``.

HPXML HVAC Distribution
***********************

Each separate HVAC distribution system should be specified as a ``Systems/HVAC/HVACDistribution``.
The four types of HVAC distribution systems allowed are ``AirDistribution``, ``HydronicDistribution``, ``HydronicAndAirDistribution``, and ``DSE``.
There should be at most one heating system and one cooling system attached to a distribution system.
See the sections on Heating Systems, Cooling Systems, and Heat Pumps for information on which ``DistributionSystemType`` is allowed for which HVAC system.
Also note that some HVAC systems (e.g., room air conditioners) are not allowed to be attached to a distribution system.

Air Distribution
~~~~~~~~~~~~~~~~

``AirDistribution`` systems are defined by:

- ``ConditionedFloorAreaServed``
- Optional ``NumberofReturnRegisters``. If not provided, one return register per conditioned floor will be assumed.
- Optional supply leakage to the outside in CFM25 or percent of airflow (``DuctLeakageMeasurement[DuctType='supply']/DuctLeakage/Value``)
- Optional return leakage to the outside in CFM25 or percent of airflow (``DuctLeakageMeasurement[DuctType='return']/DuctLeakage/Value``)
- Optional supply ducts (``Ducts[DuctType='supply']``)
- Optional return ducts (``Ducts[DuctType='return']``)

For each duct, ``DuctInsulationRValue`` must be provided.
``DuctSurfaceArea`` and ``DuctLocation`` must both be provided or both not be provided.

If ``DuctSurfaceArea`` is not provided, duct areas will be calculated based on ANSI/ASHRAE Standard 152-2004:

======================  ====================================================================
Duct Type               Default Value
======================  ====================================================================
Primary supply ducts    :math:`0.27 \cdot F_{out} \cdot CFA_{ServedByAirDistribution}`
Secondary supply ducts  :math:`0.27 \cdot (1 - F_{out}) \cdot CFA_{ServedByAirDistribution}`
Primary return ducts    :math:`b_r \cdot F_{out} \cdot CFA_{ServedByAirDistribution}`
Secondary return ducts  :math:`b_r \cdot (1 - F_{out}) \cdot CFA_{ServedByAirDistribution}`
======================  ====================================================================

where F\ :sub:`out` is 1.0 when ``NumberofConditionedFloorsAboveGrade`` <= 1 and 0.75 when ``NumberofConditionedFloorsAboveGrade`` > 1, and b\ :sub:`r` is 0.05 * ``NumberofReturnRegisters`` with a maximum value of 0.25.

If ``DuctLocation`` is provided, it can be one of the following:

==============================  ================================================  =========================================================  =========================  ================
Location                        Description                                       Temperature                                                Building Type              Default Priority
==============================  ================================================  =========================================================  =========================  ================
living space                    Above-grade conditioned floor area                EnergyPlus calculation                                     Any                        8
basement - conditioned          Below-grade conditioned floor area                EnergyPlus calculation                                     Any                        1
basement - unconditioned                                                          EnergyPlus calculation                                     Any                        2
crawlspace - unvented                                                             EnergyPlus calculation                                     Any                        4
crawlspace - vented                                                               EnergyPlus calculation                                     Any                        3
attic - unvented                                                                  EnergyPlus calculation                                     Any                        6
attic - vented                                                                    EnergyPlus calculation                                     Any                        5
garage                          Single-family garage (not shared parking garage)  EnergyPlus calculation                                     Any                        7
outside                                                                           Outside                                                    Any
exterior wall                                                                     Average of conditioned space and outside                   Any
under slab                                                                        Ground                                                     Any
roof deck                                                                         Outside                                                    Any
other housing unit              E.g., conditioned adjacent unit or corridor       Same as conditioned space                                  Attached/Multifamily only
other heated space              E.g., shared laundry/equipment space              Average of conditioned space and outside; minimum of 68F   Attached/Multifamily only
other multifamily buffer space  E.g., enclosed unconditioned stairwell            Average of conditioned space and outside; minimum of 50F   Attached/Multifamily only
other non-freezing space        E.g., shared parking garage ceiling               Floats with outside; minimum of 40F                        Attached/Multifamily only
==============================  ================================================  =========================================================  =========================  ================

If ``DuctLocation`` is not provided, the location for primary ducts will be chosen based on the presence of spaces and the "Default Priority" indicated above.
Any secondary ducts (when ``NumberofConditionedFloorsAboveGrade`` > 1) will always be located in the living space.

Hydronic Distribution
~~~~~~~~~~~~~~~~~~~~~

``HydronicDistribution`` systems are defined by:

- ``HydronicDistributionType``: "radiator" or "baseboard" or "radiant floor" or "radiant ceiling"

Hydronic And Air Distribution
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``HydronicAndAirDistribution`` systems are defined by:

- ``HydronicAndAirDistributionType``: "fan coil" or "water loop heat pump"

as well as all of the elements described above for an ``AirDistribution`` system.

Distribution System Efficiency
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``DSE`` systems are defined by a ``AnnualHeatingDistributionSystemEfficiency`` and ``AnnualCoolingDistributionSystemEfficiency`` elements.

.. warning::

  Specifying a DSE for the HVAC distribution system is reflected in the SimulationOutputReport reporting measure outputs, but is not reflected in the raw EnergyPlus simulation outputs.

HPXML Mechanical Ventilation
****************************

This section describes elements specified in HPXML's ``Systems/MechanicalVentilation``.
``Systems/MechanicalVentilation/VentilationFans/VentilationFan`` elements can be used to specify whole home ventilation, local ventilation, and/or cooling load reduction.

Whole Home Ventilation
~~~~~~~~~~~~~~~~~~~~~~

Mechanical ventilation systems that provide whole home ventilation may each be specified as a ``Systems/MechanicalVentilation/VentilationFans/VentilationFan`` with ``UsedForWholeBuildingVentilation='true'``.
Inputs including ``FanType`` and ``HoursInOperation`` must be provided.

Depending on the type of mechanical ventilation specified, additional elements are required:

====================================  ==========================  =======================  ================================
FanType                               SensibleRecoveryEfficiency  TotalRecoveryEfficiency  AttachedToHVACDistributionSystem
====================================  ==========================  =======================  ================================
energy recovery ventilator            required                    required
heat recovery ventilator              required
exhaust only
supply only
balanced
central fan integrated supply (CFIS)                                                       required
====================================  ==========================  =======================  ================================

Note that ``AdjustedSensibleRecoveryEfficiency`` and ``AdjustedTotalRecoveryEfficiency`` can be provided instead of ``SensibleRecoveryEfficiency`` and ``TotalRecoveryEfficiency``.

The ventilation system may be optionally described as a shared system (i.e., serving multiple dwelling units) using ``IsSharedSystem``.
If not provided, it is assumed to be false.

If the ventilation system is not shared, the following inputs are available:

- ``TestedFlowRate`` or ``RatedFlowRate``: The airflow rate. For a CFIS system, the flow rate should equal the amount of outdoor air provided to the distribution system.
- ``FanPower``: The fan power for the highest airflow setting.

If the ventilation system is shared, the following inputs are available:

- ``TestedFlowRate`` or ``RatedFlowRate``: The airflow rate of the entire system.
- ``FanPower``: The fan power for the entire system at highest airflow setting.
- ``FractionRecirculation``: Fraction of the total supply air that is recirculated, with the remainder assumed to be outdoor air. The value must be 0 for exhaust only systems.
- ``extension/InUnitFlowRate``: The flow rate delivered to the dwelling unit.
- ``extension/PreHeating``: Optional. Element to specify if the supply air is preconditioned by heating equipment. It is not allowed for exhaust only systems. If provided, there are additional child elements required:

  - ``Fuel``: Fuel type of the preconditioning heating equipment.
  - ``AnnualHeatingEfficiency[Units="COP"]/Value``: Efficiency of the preconditioning heating equipment.
  - ``FractionVentilationHeatLoadServed``: Fraction of heating load introduced by the shared ventilation system that is met by the preconditioning heating equipment.

- ``extension/PreCooling``: Optional. Element to specify if the supply air is preconditioned by cooling equipment. It is not allowed for exhaust only systems. If provided, there are additional child elements required:

  - ``Fuel``: Fuel type of the preconditioning cooling equipment.
  - ``AnnualCoolingEfficiency[Units="COP"]/Value``: Efficiency of the preconditioning cooling equipment.
  - ``FractionVentilationCoolLoadServed``: Fraction of cooling load introduced by the shared ventilation system that is met by the preconditioning cooling equipment.

Local Ventilation
~~~~~~~~~~~~~~~~~

Kitchen range fans that provide local ventilation may each be specified as a ``Systems/MechanicalVentilation/VentilationFans/VentilationFan`` with ``FanLocation='kitchen'`` and ``UsedForLocalVentilation='true'``.

Additional fields may be provided per the table below. If not provided, default values will be assumed based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.

=========================== ========================
Element Name                Default Value
=========================== ========================
Quantity [#]                1
RatedFlowRate [cfm]         100
HoursInOperation [hrs/day]  1
FanPower [W]                0.3 * RatedFlowRate
extension/StartHour [0-23]  18
=========================== ========================

Bathroom fans that provide local ventilation may each be specified as a ``Systems/MechanicalVentilation/VentilationFans/VentilationFan`` with ``FanLocation='bath'`` and ``UsedForLocalVentilation='true'``.

Additional fields may be provided per the table below. If not provided, default values will be assumed based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.

=========================== ========================
Element Name                Default Value
=========================== ========================
Quantity [#]                NumberofBathrooms
RatedFlowRate [cfm]         50
HoursInOperation [hrs/day]  1
FanPower [W]                0.3 * RatedFlowRate
extension/StartHour [0-23]  7
=========================== ========================

Cooling Load Reduction
~~~~~~~~~~~~~~~~~~~~~~

Whole house fans that provide cooling load reduction may each be specified as a ``Systems/MechanicalVentilation/VentilationFans/VentilationFan`` with ``UsedForSeasonalCoolingLoadReduction='true'``.
Required elements include ``RatedFlowRate`` and ``FanPower``.

The whole house fan is assumed to operate during hours of favorable outdoor conditions and will take priority over operable windows (natural ventilation).

HPXML Water Heating Systems
***************************

Each water heater should be entered as a ``Systems/WaterHeating/WaterHeatingSystem``.
Inputs including ``WaterHeaterType`` and ``FractionDHWLoadServed`` must be provided.

.. warning::

  ``FractionDHWLoadServed`` represents only the fraction of the hot water load associated with the hot water **fixtures**.
  Additional hot water load from the clothes washer/dishwasher will be automatically assigned to the appropriate water heater(s).

Depending on the type of water heater specified, additional elements are required/available:

========================================  ===================================  ===============  ===========  ==========  ===============  ==================  ===================== =================  =========================================  ==============================
WaterHeaterType                           UniformEnergyFactor or EnergyFactor  FirstHourRating  FuelType     TankVolume  HeatingCapacity  RecoveryEfficiency  PerformanceAdjustment UsesDesuperheater  WaterHeaterInsulation/Jacket/JacketRValue  RelatedHVACSystem
========================================  ===================================  ===============  ===========  ==========  ===============  ==================  ===================== =================  =========================================  ==============================
storage water heater                      required                             required if UEF  <any>        (optional)  (optional)       (optional)                                (optional)         (optional)                                 required if uses desuperheater
instantaneous water heater                required                                              <any>                                                         (optional)            (optional)                                                    required if uses desuperheater
heat pump water heater                    required                             required if UEF  electricity  required                                                               (optional)         (optional)                                 required if uses desuperheater
space-heating boiler with storage tank                                                                       required                                                                                  (optional)                                 required
space-heating boiler with tankless coil                                                                                                                                                                                                           required
========================================  ===================================  ===============  ===========  ==========  ===============  ==================  ===================== =================  =========================================  ==============================

For storage water heaters, the tank volume in gallons, heating capacity in Btuh, and recovery efficiency can be optionally provided.
If not provided, default values for the tank volume and heating capacity will be assumed based on Table 8 in the `2014 Building America House Simulation Protocols <https://www.energy.gov/sites/prod/files/2014/03/f13/house_simulation_protocols_2014.pdf#page=22&zoom=100,93,333>`_ 
and a default recovery efficiency shown in the table below will be assumed based on regression analysis of `AHRI certified water heaters <https://www.ahridirectory.org/NewSearch?programId=24&searchTypeId=3>`_.

============  ======================================
EnergyFactor  RecoveryEfficiency (default)
============  ======================================
>= 0.75       0.778114 * EF + 0.276679
< 0.75        0.252117 * EF + 0.607997
============  ======================================

For tankless water heaters, a performance adjustment due to cycling inefficiencies can be provided.
If not provided, a default value of 0.94 will apply if Uniform Energy Factor (UEF) is provided or 0.92 will apply if Energy Factor (EF) is provided.

For combi boiler systems, the ``RelatedHVACSystem`` must point to a ``HeatingSystem`` of type "Boiler".
For combi boiler systems with a storage tank, the storage tank losses (deg-F/hr) can be entered as ``StandbyLoss``; if not provided, a default value based on the `AHRI Directory of Certified Product Performance <https://www.ahridirectory.org>`_ will be calculated.

For water heaters that are connected to a desuperheater, the ``RelatedHVACSystem`` must either point to a ``HeatPump`` or a ``CoolingSystem``.

The water heater ``Location`` can be optionally entered as one of the following:

==============================  ================================================  =========================================================  =========================
Location                        Description                                       Temperature                                                Building Type
==============================  ================================================  =========================================================  =========================
living space                    Above-grade conditioned floor area                EnergyPlus calculation                                     Any
basement - conditioned          Below-grade conditioned floor area                EnergyPlus calculation                                     Any
basement - unconditioned                                                          EnergyPlus calculation                                     Any
attic - unvented                                                                  EnergyPlus calculation                                     Any
attic - vented                                                                    EnergyPlus calculation                                     Any
garage                          Single-family garage (not shared parking garage)  EnergyPlus calculation                                     Any
crawlspace - unvented                                                             EnergyPlus calculation                                     Any
crawlspace - vented                                                               EnergyPlus calculation                                     Any
other exterior                  Outside                                           EnergyPlus calculation                                     Any
other housing unit              E.g., conditioned adjacent unit or corridor       Same as conditioned space                                  Attached/Multifamily only
other heated space              E.g., shared laundry/equipment space              Average of conditioned space and outside; minimum of 68F   Attached/Multifamily only
other multifamily buffer space  E.g., enclosed unconditioned stairwell            Average of conditioned space and outside; minimum of 50F   Attached/Multifamily only
other non-freezing space        E.g., shared parking garage ceiling               Floats with outside; minimum of 40F                        Attached/Multifamily only
==============================  ================================================  =========================================================  =========================

If the location is not provided, a default water heater location will be assumed based on IECC climate zone:

=================  ============================================================================================
IECC Climate Zone  Location (default)
=================  ============================================================================================
1-3, excluding 3A  garage if present, otherwise living space                                                   
3A, 4-8, unknown   conditioned basement if present, otherwise unconditioned basement if present, otherwise living space
=================  ============================================================================================

The setpoint temperature may be provided as ``HotWaterTemperature``; if not provided, 125F is assumed.

The water heater may be optionally described as a shared system (i.e., serving multiple dwelling units or a shared laundry room) using ``IsSharedSystem``.
If not provided, it is assumed to be false.
If provided and true, ``NumberofUnitsServed`` must also be specified, where the value is the number of dwelling units served either indirectly (e.g., via shared laundry room) or directly.

HPXML Hot Water Distribution
****************************

A single ``Systems/WaterHeating/HotWaterDistribution`` must be provided if any water heating systems are specified.
Inputs including ``SystemType`` and ``PipeInsulation/PipeRValue`` must be provided.
Note: Any hot water distribution associated with a shared laundry room in attached/multifamily buildings should not be defined.

Standard
~~~~~~~~

For a ``SystemType/Standard`` (non-recirculating) system within the dwelling unit, the following element are used:

- ``PipingLength``: Optional. Measured length of hot water piping from the hot water heater (or from a shared recirculation loop serving multiple dwelling units) to the farthest hot water fixture, measured longitudinally from plans, assuming the hot water piping does not run diagonally, plus 10 feet of piping for each floor level, plus 5 feet of piping for unconditioned basements (if any)
  If not provided, a default ``PipingLength`` will be calculated using the following equation from `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.

  .. math:: PipeL = 2.0 \cdot (\frac{CFA}{NCfl})^{0.5} + 10.0 \cdot NCfl + 5.0 \cdot bsmnt

  Where, 
  PipeL = piping length [ft], 
  CFA = conditioned floor area [ft²],
  NCfl = number of conditioned floor levels number of conditioned floor levels in the residence including conditioned basements, 
  bsmnt = presence = 1.0 or absence = 0.0 of an unconditioned basement in the residence.

Recirculation
~~~~~~~~~~~~~

For a ``SystemType/Recirculation`` system within the dwelling unit, the following elements are used:

- ``ControlType``: One of "manual demand control", "presence sensor demand control", "temperature", "timer", or "no control".
- ``RecirculationPipingLoopLength``: Optional. If not provided, the default value will be calculated by using the equation shown in the table below. Measured recirculation loop length including both supply and return sides, measured longitudinally from plans, assuming the hot water piping does not run diagonally, plus 20 feet of piping for each floor level greater than one plus 10 feet of piping for unconditioned basements.
- ``BranchPipingLoopLength``: Optional. If not provided, the default value will be assumed as shown in the table below. Measured length of the branch hot water piping from the recirculation loop to the farthest hot water fixture from the recirculation loop, measured longitudinally from plans, assuming the branch hot water piping does not run diagonally.
- ``PumpPower``: Optional. If not provided, the default value will be assumed as shown in the table below. Pump Power in Watts.

  ==================================  ====================================================================================================
  Element Name                        Default Value
  ==================================  ====================================================================================================
  RecirculationPipingLoopLength [ft]  :math:`2.0 \cdot (2.0 \cdot (\frac{CFA}{NCfl})^{0.5} + 10.0 \cdot NCfl + 5.0 \cdot bsmnt) - 20.0`
  BranchPipingLoopLength [ft]         10 
  Pump Power [W]                      50 
  ==================================  ====================================================================================================

Shared Recirculation
~~~~~~~~~~~~~~~~~~~~

In addition to the hot water distribution systems within the dwelling unit, the pump energy use of a shared recirculation system in an Attached/Multifamily building can also be described using the following elements:

- `extension/SharedRecirculation/NumberofUnitsServed`: Number of dwelling units served by the shared pump.
- `extension/SharedRecirculation/PumpPower`: Optional. If not provided, the default value will be assumed as shown in the table below. Shared pump power in Watts.
- `extension/SharedRecirculation/ControlType`: One of "manual demand control", "presence sensor demand control", "timer", or "no control".

  ==================================  ==========================================
  Element Name                        Default Value
  ==================================  ==========================================
  Pump Power [W]                      220 (0.25 HP pump w/ 85% motor efficiency)
  ==================================  ==========================================

Note that when defining a shared recirculation system, the hot water distribution system type within the dwelling unit must be standard (``SystemType/Standard``).
This is because a stacked recirculation system (i.e., shared recirculation loop plus an additional recirculation system within the dwelling unit) is more likely to indicate input errors than reflect an actual real-world scenario.

Drain Water Heat Recovery
~~~~~~~~~~~~~~~~~~~~~~~~~

In addition, a ``HotWaterDistribution/DrainWaterHeatRecovery`` (DWHR) may be specified.
The DWHR system is defined by:

- ``FacilitiesConnected``: 'one' if there are multiple showers and only one of them is connected to a DWHR; 'all' if there is one shower and it's connected to a DWHR or there are two or more showers connected to a DWHR
- ``EqualFlow``: 'true' if the DWHR supplies pre-heated water to both the fixture cold water piping and the hot water heater potable supply piping
- ``Efficiency``: As rated and labeled in accordance with CSA 55.1

HPXML Water Fixtures
********************

Water fixtures should be entered as ``Systems/WaterHeating/WaterFixture`` elements.
Each fixture must have ``WaterFixtureType`` and ``LowFlow`` elements provided.
Fixtures should be specified as low flow if they are <= 2.0 gpm.

A ``WaterHeating/extension/WaterFixturesUsageMultiplier`` can also be optionally provided that scales hot water usage; if not provided, it is assumed to be 1.0.

HPXML Solar Thermal
*******************

A solar hot water system can be entered as a ``Systems/SolarThermal/SolarThermalSystem``.
The ``SystemType`` element must be 'hot water'.

Solar hot water systems can be described with either simple or detailed inputs.

Simple Model
~~~~~~~~~~~~

If using simple inputs, the following elements are used:

- ``SolarFraction``: Portion of total conventional hot water heating load (delivered energy and tank standby losses). Can be obtained from Directory of SRCC OG-300 Solar Water Heating System Ratings or NREL's `System Advisor Model <https://sam.nrel.gov/>`_ or equivalent.
- ``ConnectedTo``: Optional. If not specified, applies to all water heaters in the building. If specified, must point to a ``WaterHeatingSystem``.

Detailed Model
~~~~~~~~~~~~~~

If using detailed inputs, the following elements are used:

- ``CollectorArea``: in units of ft²
- ``CollectorLoopType``: 'liquid indirect' or 'liquid direct' or 'passive thermosyphon'
- ``CollectorType``: 'single glazing black' or 'double glazing black' or 'evacuated tube' or 'integrated collector storage'
- ``CollectorAzimuth``
- ``CollectorTilt``
- ``CollectorRatedOpticalEfficiency``: FRTA (y-intercept); see Directory of SRCC OG-100 Certified Solar Collector Ratings
- ``CollectorRatedThermalLosses``: FRUL (slope, in units of Btu/hr-ft²-R); see Directory of SRCC OG-100 Certified Solar Collector Ratings
- ``StorageVolume``: Optional. If not provided, the default value in gallons will be calculated as 1.5 * CollectorArea

- ``ConnectedTo``: Must point to a ``WaterHeatingSystem``. The connected water heater cannot be of type space-heating boiler or attached to a desuperheater.

HPXML Photovoltaics
*******************

Each solar electric (photovoltaic) system should be entered as a ``Systems/Photovoltaics/PVSystem``.
The following elements, some adopted from the `PVWatts model <https://pvwatts.nrel.gov>`_, are required for each PV system:

- ``Location``: 'ground' or 'roof' mounted
- ``ModuleType``: 'standard', 'premium', or 'thin film'
- ``Tracking``: 'fixed' or '1-axis' or '1-axis backtracked' or '2-axis'
- ``ArrayAzimuth``
- ``ArrayTilt``
- ``MaxPowerOutput``

Inputs including ``InverterEfficiency``, ``SystemLossesFraction``, and ``YearModulesManufactured`` can be optionally entered.
If ``InverterEfficiency`` is not provided, the default value of 0.96 is assumed.

``SystemLossesFraction`` includes the effects of soiling, shading, snow, mismatch, wiring, degradation, etc.
If neither ``SystemLossesFraction`` or ``YearModulesManufactured`` are provided, a default value of 0.14 will be used.
If ``SystemLossesFraction`` is not provided but ``YearModulesManufactured`` is provided, ``SystemLossesFraction`` will be calculated using the following equation.

.. math:: System Losses Fraction = 1.0 - (1.0 - 0.14) \cdot (1.0 - (1.0 - 0.995^{(CurrentYear - YearModulesManufactured)}))

The PV system may be optionally described as a shared system (i.e., serving multiple dwelling units) using ``IsSharedSystem``.
If not provided, it is assumed to be false.
If provided and true, the total number of bedrooms across all dwelling units served by the system must be entered as ``extension/NumberofBedroomsServed``.
PV generation will be apportioned to the dwelling unit using its number of bedrooms divided by the total number of bedrooms in the building.

HPXML Appliances
----------------

This section describes elements specified in HPXML's ``Appliances``.

The ``Location`` for each appliance can be optionally provided as one of the following:

==============================  ================================================  =========================
Location                        Description                                       Building Type
==============================  ================================================  =========================
living space                    Above-grade conditioned floor area                Any
basement - conditioned          Below-grade conditioned floor area                Any
basement - unconditioned                                                          Any
garage                          Single-family garage (not shared parking garage)  Any
other housing unit              E.g., conditioned adjacent unit or corridor       Attached/Multifamily only
other heated space              E.g., shared laundry/equipment space              Attached/Multifamily only
other multifamily buffer space  E.g., enclosed unconditioned stairwell            Attached/Multifamily only
other non-freezing space        E.g., shared parking garage ceiling               Attached/Multifamily only
==============================  ================================================  =========================

If the location is not specified, the appliance is assumed to be in the living space.

HPXML Clothes Washer
********************

A single ``Appliances/ClothesWasher`` element can be specified; if not provided, a clothes washer will not be modeled.

Several EnergyGuide label inputs describing the efficiency of the appliance can be provided.
If the complete set of efficiency inputs is not provided, the following default values representing a standard clothes washer from 2006 will be used.

=============================================  ==============
Element Name                                   Default Value
=============================================  ==============
IntegratedModifiedEnergyFactor [ft³/kWh-cyc]   1.0  
RatedAnnualkWh [kWh/yr]                        400  
LabelElectricRate [$/kWh]                      0.12  
LabelGasRate [$/therm]                         1.09  
LabelAnnualGasCost [$]                         27.0  
Capacity [ft³]                                 3.0  
LabelUsage [cyc/week]                          6  
=============================================  ==============

If ``ModifiedEnergyFactor`` is provided instead of ``IntegratedModifiedEnergyFactor``, it will be converted using the following equation based on the `Interpretation on ANSI/RESNET 301-2014 Clothes Washer IMEF <https://www.resnet.us/wp-content/uploads/No.-301-2014-08-sECTION-4.2.2.5.2.8-Clothes-Washers-Eq-4.2-6.pdf>`_.

.. math:: IntegratedModifiedEnergyFactor = \frac{ModifiedEnergyFactor - 0.503}{0.95}

An ``extension/UsageMultiplier`` can also be optionally provided that scales energy and hot water usage; if not provided, it is assumed to be 1.0.

The clothes washer may be optionally described as a shared appliance (i.e., in a shared laundry room) using ``IsSharedAppliance``.
If not provided, it is assumed to be false.
If provided and true, ``AttachedToWaterHeatingSystem`` must also be specified and must reference a shared water heater.

HPXML Clothes Dryer
*******************

A single ``Appliances/ClothesDryer`` element can be specified; if not provided, a clothes dryer will not be modeled.
The dryer's ``FuelType`` must be provided.

Several EnergyGuide label inputs describing the efficiency of the appliance can be provided.
If the complete set of efficiency inputs is not provided, the following default values representing a standard clothes dryer from 2006 will be used.

==============================  ==============
Element Name                    Default Value
==============================  ==============
CombinedEnergyFactor [lb/kWh]   3.01  
ControlType                     timer
==============================  ==============

If ``EnergyFactor`` is provided instead of ``CombinedEnergyFactor``, it will be converted into ``CombinedEnergyFactor`` using the following equation based on the `Interpretation on ANSI/RESNET/ICC 301-2014 Clothes Dryer CEF <https://www.resnet.us/wp-content/uploads/No.-301-2014-10-Section-4.2.2.5.2.8-Clothes-Dryer-CEF-Rating.pdf>`_.

.. math:: CombinedEnergyFactor = \frac{EnergyFactor}{1.15}

An ``extension/UsageMultiplier`` can also be optionally provided that scales energy usage; if not provided, it is assumed to be 1.0.

An optional ``extension/IsVented`` element can be used to indicate whether the clothes dryer is vented. If not provided, it is assumed that the clothes dryer is vented.
If the clothes dryer is vented, an optional ``extension/VentedFlowRate`` element can be used to specify the exhaust cfm. If not provided, it is assumed that the clothes dryer vented flow rate is 100 cfm.

The clothes dryer may be optionally described as a shared appliance (i.e., in a shared laundry room) using ``IsSharedAppliance``.
If not provided, it is assumed to be false.

HPXML Dishwasher
****************

A single ``Appliances/Dishwasher`` element can be specified; if not provided, a dishwasher will not be modeled.

Several EnergyGuide label inputs describing the efficiency of the appliance can be provided.
If the complete set of efficiency inputs is not provided, the following default values representing a standard dishwasher from 2006 will be used.

===============================  =================
Element Name                     Default Value
===============================  =================
RatedAnnualkWh [kwh/yr]          467  
LabelElectricRate [$/kWh]        0.12  
LabelGasRate [$/therm]           1.09  
LabelAnnualGasCost [$]           33.12  
PlaceSettingCapacity [#]         12  
LabelUsage [cyc/week]            4  
===============================  =================

If ``EnergyFactor`` is provided instead of ``RatedAnnualkWh``, it will be converted into ``RatedAnnualkWh`` using the following equation based on `ANSI/RESNET/ICC 301-2014 <https://codes.iccsafe.org/content/document/843>`_.

.. math:: RatedAnnualkWh = \frac{215.0}{EnergyFactor}

An ``extension/UsageMultiplier`` can also be optionally provided that scales energy and hot water usage; if not provided, it is assumed to be 1.0.

The dishwasher may be optionally described as a shared appliance (i.e., in a shared laundry room) using ``IsSharedAppliance``.
If not provided, it is assumed to be false.
If provided and true, ``AttachedToWaterHeatingSystem`` must also be specified and must reference a shared water heater.

HPXML Refrigerators
*******************

Multiple ``Appliances/Refrigerator`` elements can be specified; if none are provided, refrigerators will not be modeled.

The efficiency of the refrigerator can be optionally entered as ``RatedAnnualkWh`` or ``extension/AdjustedAnnualkWh``.
If neither are provided, ``RatedAnnualkWh`` will be defaulted to represent a standard refrigerator from 2006 using the following equation based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.

.. math:: RatedAnnualkWh = 637.0 + 18.0 \cdot NumberofBedrooms

Optional ``extension/WeekdayScheduleFractions``, ``extension/WeekendScheduleFractions``, and ``extension/MonthlyScheduleMultipliers`` can be provided; if not provided, values from Figures 16 & 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used.
An ``extension/UsageMultiplier`` can also be optionally provided that scales energy usage; if not provided, it is assumed to be 1.0.

If multiple refrigerators are specified, there must be exactly one refrigerator described with ``PrimaryIndicator='true'``.

The ``Location`` of a primary refrigerator is described in the Appliances section.
If ``Location`` is not provided for a non-primary refrigerator, its location will be chosen based on the presence of spaces and the "Default Priority" indicated below.

========================  ================
Location                  Default Priority
========================  ================
garage                    1
basement - unconditioned  2
basement - conditioned    3
living space              4
========================  ================

HPXML Freezers
**************

Multiple ``Appliances/Freezer`` elements can be provided; if none provided, standalone freezers will not be modeled.

The efficiency of the freezer can be optionally entered as RatedAnnualkWh or extension/AdjustedAnnualkWh. If neither are provided, RatedAnnualkWh will be defaulted to represent a benchmark freezer according to the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ (319.8 kWh/year).

Optional ``extension/WeekdayScheduleFractions``, ``extension/WeekendScheduleFractions``, and ``extension/MonthlyScheduleMultipliers`` can be provided; if not provided, values from Figures 16 & 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used.
An extension/UsageMultiplier can also be optionally provided that scales energy usage; if not provided, it is assumed to be 1.0.

HPXML Cooking Range/Oven
************************

A single pair of ``Appliances/CookingRange`` and ``Appliances/Oven`` elements can be specified; if not provided, a range/oven will not be modeled.
The ``FuelType`` of the range must be provided.

Inputs including ``CookingRange/IsInduction`` and ``Oven/IsConvection`` can be optionally provided.
The following default values will be assumed unless a complete set of the optional variables is provided.

=============  ==============
Element Name   Default Value
=============  ==============
IsInduction    false
IsConvection   false
=============  ==============

Optional ``CookingRange/extension/WeekdayScheduleFractions``, ``CookingRange/extension/WeekendScheduleFractions``, and ``CookingRange/extension/MonthlyScheduleMultipliers`` can be provided; if not provided, values from Figures 22 & 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used.
An ``CookingRange/extension/UsageMultiplier`` can also be optionally provided that scales energy usage; if not provided, it is assumed to be 1.0.

HPXML Dehumidifier
******************

A single ``Appliance/Dehumidifier`` element can be specified; if not provided, a dehumidifier will not be modeled.
The ``Capacity`` (pints/day), ``DehumidistatSetpoint`` (relative humidity as a fraction, 0-1), and ``FractionDehumidificationLoadServed`` (0-1) must be provided.
The efficiency of the dehumidifier can either be entered as an ``IntegratedEnergyFactor`` or ``EnergyFactor``.

HPXML Lighting
--------------

This section describes elements specified in HPXML's ``Lighting``.

HPXML Lighting Groups
*********************

The building's lighting is described by nine ``LightingGroup`` elements, each of which is the combination of:

- ``LightingType``: 'LightEmittingDiode', 'CompactFluorescent', and 'FluorescentTube'
- ``Location``: 'interior', 'garage', and 'exterior'

The fraction of lamps of the given type in the given location are provided as the ``LightingGroup/FractionofUnitsInLocation``.
The fractions for a given location cannot sum to greater than 1.
If the fractions sum to less than 1, the remainder is assumed to be incandescent lighting.
Garage lighting values are ignored if the building has no garage.

Optional ``extension/InteriorUsageMultiplier``, ``extension/ExteriorUsageMultiplier``, and ``extension/GarageUsageMultiplier`` can be provided that scales energy usage; if not provided, they are assumed to be 1.0.

An optional ``extension/ExteriorHolidayLighting`` can also be provided to define additional exterior holiday lighting; if not provided, none will be modeled. 
If provided, child elements ``Load[Units='kWh/day']/Value``, ``PeriodBeginMonth``/``PeriodBeginDayOfMonth``, ``PeriodEndMonth``/``PeriodEndDayOfMonth``, ``WeekdayScheduleFractions``, and ``WeekendScheduleFractions`` can be optionally provided. 
For the child elements not provided, the following default values will be used.

=============================================  ======================================================================================================
Element Name                                   Default Value
=============================================  ======================================================================================================
Load[Units='kWh/day']/Value                    1.1 for single-family detached and 0.55 for others
PeriodBeginMonth/PeriodBeginDayOfMonth         11/24 (November 24) 
PeriodEndMonth/PeriodEndDayOfMonth             1/6 (January 6) 
WeekdayScheduleFractions                       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.008, 0.098, 0.168, 0.194, 0.284, 0.192, 0.037, 0.019
WeekendScheduleFractions                       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.008, 0.098, 0.168, 0.194, 0.284, 0.192, 0.037, 0.019
=============================================  ======================================================================================================

Finally, optional schedules can be defined:

- **Interior**: Optional ``extension/InteriorWeekdayScheduleFractions``, ``extension/InteriorWeekendScheduleFractions``, and ``extension/InteriorMonthlyScheduleMultipliers`` can be provided; if not provided, values will be calculated using Lighting Calculation Option 2 (location-dependent lighting profile) of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.
- **Garage**: Optional ``extension/GarageWeekdayScheduleFractions``, ``extension/GarageWeekendScheduleFractions``, and ``extension/GarageMonthlyScheduleMultipliers`` can be provided; if not provided, values from Appendix C Table 8 of the `Title 24 2016 Residential Alternative Calculation Method Reference Manual <https://ww2.energy.ca.gov/2015publications/CEC-400-2015-024/CEC-400-2015-024-CMF-REV2.pdf>`_ are used.
- **Exterior**: Optional ``extension/ExteriorWeekdayScheduleFractions``, ``extension/ExteriorWeekendScheduleFractions``, and ``extension/ExteriorMonthlyScheduleMultipliers`` can be provided; if not provided, values from Appendix C Table 8 of the `Title 24 2016 Residential Alternative Calculation Method Reference Manual <https://ww2.energy.ca.gov/2015publications/CEC-400-2015-024/CEC-400-2015-024-CMF-REV2.pdf>`_ are used.


HPXML Ceiling Fans
******************

Each ceiling fan (or set of identical ceiling fans) should be entered as a ``CeilingFan``.
The ``Airflow/Efficiency`` (at medium speed) and ``Quantity`` can be provided, otherwise the following default assumptions are used from `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.

==========================  ==================
Element Name                Default Value
==========================  ==================
Airflow/Efficiency [cfm/W]  3000/42.6
Quantity [#]                NumberofBedrooms+1
==========================  ==================

In addition, a reduced cooling setpoint can be specified for summer months when ceiling fans are operating.
See the Thermostat section for more information.

HPXML Pool
----------

A ``Pools/Pool`` element can be specified; if not provided, a pool will not be modeled.

A ``PoolPumps/PoolPump`` element is required.
The annual energy consumption of the pool pump (``Load[Units='kWh/year']/Value``) can be provided, otherwise they will be calculated using the following equation based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.

.. math:: PoolPumpkWhs = 158.5 / 0.070 \cdot (0.5 + 0.25 \cdot NumberofBedrooms / 3 + 0.35 \cdot ConditionedFloorArea / 1920)

A ``Heater`` element can be specified; if not provided, a pool heater will not be modeled.
Currently only pool heaters specified with ``Heater[Type='gas fired' or Type='electric resistance' or Type='heat pump']`` are recognized.
The annual energy consumption (``Load[Units='kWh/year' or Units='therm/year']/Value``) can be provided, otherwise they will be calculated using the following equations from the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.

.. math:: GasFiredTherms = 3.0 / 0.014 \cdot (0.5 + 0.25 \cdot NumberofBedrooms / 3 + 0.35 \cdot ConditionedFloorArea / 1920)
.. math:: ElectricResistancekWhs = 8.3 / 0.004 \cdot (0.5 + 0.25 \cdot NumberofBedrooms / 3 + 0.35 \cdot ConditionedFloorArea / 1920)
.. math:: HeatPumpkWhs = ElectricResistancekWhs / 5.0

A ``PoolPump/extension/UsageMultiplier`` can also be optionally provided that scales pool pump energy usage; if not provided, it is assumed to be 1.0.
A ``Heater/extension/UsageMultiplier`` can also be optionally provided that scales pool heater energy usage; if not provided, it is assumed to be 1.0.
Optional ``extension/WeekdayScheduleFractions``, ``extension/WeekendScheduleFractions``, and ``extension/MonthlyScheduleMultipliers`` can be provided for ``HotTubPump`` and ``Heater``; if not provided, values from Figures 23 & 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used.

HPXML Hot Tub
-------------

A ``HotTubs/HotTub`` element can be specified; if not provided, a hot tub will not be modeled.

A ``HotTubPumps/HotTubPump`` element is required.
The annual energy consumption of the hot tub pump (``Load[Units='kWh/year']/Value``) can be provided, otherwise they will be calculated using the following equation based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.

.. math:: HotTubPumpkWhs = 59.5 / 0.059 \cdot (0.5 + 0.25 \cdot NumberofBedrooms / 3 + 0.35 \cdot ConditionedFloorArea / 1920)

A ``Heater`` element can be specified; if not provided, a hot tub heater will not be modeled.
Currently only hot tub heaters specified with ``Heater[Type='gas fired' or Type='electric resistance' or Type='heat pump']`` are recognized.
The annual energy consumption (``Load[Units='kWh/year' or Units='therm/year']/Value``) can be provided, otherwise they will be calculated using the following equations from the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.

.. math:: GasFiredTherms = 0.87 / 0.011 \cdot (0.5 + 0.25 \cdot NumberofBedrooms / 3 + 0.35 \cdot ConditionedFloorArea / 1920)
.. math:: ElectricResistancekWhs = 49.0 / 0.048 \cdot (0.5 + 0.25 \cdot NumberofBedrooms / 3 + 0.35 \cdot ConditionedFloorArea / 1920)
.. math:: HeatPumpkWhs = ElectricResistancekWhs / 5.0

A ``HotTubPump/extension/UsageMultiplier`` can also be optionally provided that scales hot tub pump energy usage; if not provided, it is assumed to be 1.0.
A ``Heater/extension/UsageMultiplier`` can also be optionally provided that scales hot tub heater energy usage; if not provided, it is assumed to be 1.0.
Optional ``extension/WeekdayScheduleFractions``, ``extension/WeekendScheduleFractions``, and ``extension/MonthlyScheduleMultipliers`` can be provided for ``PoolPump`` and ``Heater``; if not provided, values from Figures 23 & 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used.

HPXML Misc Loads
----------------

This section describes elements specified in HPXML's ``MiscLoads``.

HPXML Plug Loads
****************

Misc electric plug loads can be provided by entering ``PlugLoad`` elements.
Currently only plug loads specified with ``PlugLoadType='other'``, ``PlugLoadType='TV other'``, ``PlugLoadType='electric vehicle charging'``, or ``PlugLoadType='well pump'`` are recognized.
The 'other' and 'TV other' plug loads are required to represent the typical home; the other less common plug loads will only be modeled if provided.

The annual energy consumption (``Load[Units='kWh/year']/Value``), ``Location``, ``extension/FracSensible``, and ``extension/FracLatent`` elements are optional.
If not provided, they will be defaulted as follows.
Annual energy consumption equations are based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_ or the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.

==========================  =============================================  ========  ============  ==========
Plug Load Type              kWh/year                                       Location  FracSensible  FracLatent
==========================  =============================================  ========  ============  ==========
other                       0.91*CFA                                       interior  0.855         0.045
TV other                    413.0 + 69.0*NBr                               interior  1.0           0.0
electric vehicle charging   1666.67                                        exterior  0.0           0.0
well pump                   50.8/0.127*(0.5 + 0.25*NBr/3 + 0.35*CFA/1920)  exterior  0.0           0.0
==========================  =============================================  ========  ============  ==========

where CFA is the conditioned floor area and NBr is the number of bedrooms.

The electric vehicle charging default kWh/year is calculated using:

.. math:: VehiclekWhs = AnnualMiles * kWhPerMile / (EVChargerEfficiency * EVBatteryEfficiency)

where AnnualMiles=4500, kWhPerMile=0.3, EVChargerEfficiency=0.9, and EVBatteryEfficiency=0.9.

An ``extension/UsageMultiplier`` can also be optionally provided that scales energy usage; if not provided, it is assumed to be 1.0.
Optional ``extension/WeekdayScheduleFractions``, ``extension/WeekendScheduleFractions``, and ``extension/MonthlyScheduleMultipliers`` can be provided.
If not provided, values from Figures 23 & 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used for ``PlugLoadType='other'``, ``PlugLoadType='electric vehicle charging'``, and ``PlugLoadType='well pump'``; values from the `American Time Use Survey <https://www.bls.gov/tus>`_ are used for ``PlugLoadType='TV other'``.

HPXML Fuel Loads
****************

Misc fuel loads can be provided by entering ``FuelLoad`` elements.
Currently only fuel loads specified with ``FuelLoadType='grill'``, ``FuelLoadType='lighting'``, or ``FuelLoadType='fireplace'`` are recognized.
These less common fuel loads will only be modeled if provided.

The annual energy consumption (``Load[Units='therm/year']/Value``), ``Location``, ``extension/FracSensible``, and ``extension/FracLatent`` elements are also optional.
If not provided, they will be defaulted as follows.
Annual energy consumption equations are based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.

==========================  =============================================  ========  ============ ==========
Plug Load Type              therm/year                                     Location  FracSensible FracLatent
==========================  =============================================  ========  ============ ==========
grill                       0.87/0.029*(0.5 + 0.25*NBr/3 + 0.35*CFA/1920)  exterior  0.0          0.0
lighting                    0.22/0.012*(0.5 + 0.25*NBr/3 + 0.35*CFA/1920)  exterior  0.0          0.0
fireplace                   1.95/0.032*(0.5 + 0.25*NBr/3 + 0.35*CFA/1920)  interior  0.5          0.1
==========================  =============================================  ========  ============ ==========

where CFA is the conditioned floor area and NBr is the number of bedrooms.

An ``extension/UsageMultiplier`` can also be optionally provided that scales energy usage; if not provided, it is assumed to be 1.0.
Optional ``extension/WeekdayScheduleFractions``, ``extension/WeekendScheduleFractions``, and ``extension/MonthlyScheduleMultipliers`` can be provided; if not provided, values from Figures 23 & 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used.

Validating & Debugging Errors
-----------------------------

When running HPXML files, errors may occur because:

#. An HPXML file provided is invalid (either relative to the HPXML schema or the EnergyPlus Use Case).
#. An unexpected EnergyPlus simulation error occurred.

If an error occurs, first look in the run.log for details.
If there are no errors in that log file, then the error may be in the EnergyPlus simulation -- see eplusout.err.

Contact us if you can't figure out the cause of an error.

Sample Files
------------

Dozens of sample HPXML files are included in the workflow/sample_files directory.
The sample files help to illustrate how different building components are described in HPXML.

Each sample file generally makes one isolated change relative to the base HPXML (base.xml) building.
For example, the base-dhw-dwhr.xml file adds a ``DrainWaterHeatRecovery`` element to the building.

You may find it useful to search through the files for certain HPXML elements or compare (diff) a sample file to the base.xml file.
