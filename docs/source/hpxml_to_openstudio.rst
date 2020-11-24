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

EnergyPlus simulation controls are entered in ``/HPXML/SoftwareInfo/extension/SimulationControl``.

  ==================================  ========  =======  =============  ========  ===========================  =====================================
  Element                             Type      Units    Constraints    Required  Default                      Description
  ==================================  ========  =======  =============  ========  ===========================  =====================================
  ``Timestep``                        integer   minutes  Divisor of 60  No        60 (1 hour)                  Timestep
  ``BeginMonth``                      integer            1-12 [#]_      No        1 (January)                  Run period start date
  ``BeginDayOfMonth``                 integer            1-31           No        1                            Run period start date
  ``EndMonth``                        integer            1-12           No        12 (December)                Run period end date
  ``EndDayOfMonth``                   integer            1-31           No                                     Run period end date
  ``CalendarYear``                    integer            > 1600         No        2007 (for TMY weather) [#]_  Calendar year (for start day of week)
  ``DaylightSaving/Enabled``          boolean                           No        true                         Daylight savings enabled?
  ==================================  ========  =======  =============  ========  ===========================  =====================================

  .. [#] BeginMonth/BeginDayOfMonth date must occur before EndMonth/EndDayOfMonth date (e.g., a run period from 10/1 to 3/31 is invalid).
  .. [#] CalendarYear only applies to TMY (Typical Meteorological Year) weather. For AMY (Actual Meteorological Year) weather, the AMY year will be used regardless of what is specified.

If daylight saving is enabled, additional information is specified in ``DaylightSaving``.

  ======================================  ========  =====  =============  ========  =============================  ===========
  Element                                 Type      Units  Constraints    Required  Default                        Description
  ======================================  ========  =====  =============  ========  =============================  ===========
  ``BeginMonth`` and ``BeginDayOfMonth``  integer          1-12 and 1-31  No        EPW else 3/12 (March 12) [#]_  Start date
  ``EndMonth`` and ``EndDayOfMonth``      integer          1-12 and 1-31  No        EPW else 11/5 (November 5)     End date
  ======================================  ========  =====  =============  ========  =============================  ===========

  .. [#] Daylight savings dates will be defined according to the EPW weather file header; if not available, fallback default values listed above will be used.

HPXML HVAC Sizing Control
*************************

HVAC equipment sizing controls are entered in ``/HPXML/SoftwareInfo/extension/HVACSizingControl``.

  =================================  ========  =====  ===========  ========  =======  ============================================
  Element                            Type      Units  Constraints  Required  Default  Description
  =================================  ========  =====  ===========  ========  =======  ============================================
  ``AllowIncreasedFixedCapacities``  boolean                       No        false    Logic for fixed capacity HVAC equipment [#]_
  ``UseMaxLoadForHeatPumps``         boolean                       No        true     Logic for autosized heat pumps [#]_
  =================================  ========  =====  ===========  ========  =======  ============================================

  .. [#] If AllowIncreasedFixedCapacities is true, the larger of user-specified fixed capacity and design load will be used (to reduce potential for unmet loads); otherwise user-specified fixed capacity is used.
  .. [#] If UseMaxLoadForHeatPumps is true, autosized heat pumps are sized based on the maximum of heating/cooling design loads; otherwise sized per ACCA Manual J/S based on cooling design loads with some oversizing allowances for heating design loads.

HPXML Building Summary
----------------------

High-level building summary information is entered in ``/HPXML/Building/BuildingDetails/BuildingSummary``. 

HPXML Site
**********

Building site information is entered in ``/HPXML/Building/BuildingDetails/BuildingSummary/Site``.

  ========================================  ========  =====  ===========  ========  ========  ============================================================
  Element                                   Type      Units  Constraints  Required  Default   Notes
  ========================================  ========  =====  ===========  ========  ========  ============================================================
  ``SiteType``                              string           See [#]_     No        suburban  Terrain type for infiltration model
  ``extension/ShelterCoefficient``          double           0-1          No        0.5 [#]_  Nearby buildings, trees, obstructions for infiltration model
  ``extension/Neighbors/NeighborBuilding``  element          >= 0         No        <none>    Neighboring buildings for solar shading
  ========================================  ========  =====  ===========  ========  ========  ============================================================

  .. [#] SiteType choices are "rural", "suburban", or "urban".
  .. [#] | ShelterCoefficient values are described as follows:

         ===================  =========================================================================
         Shelter Coefficient  Description
         ===================  =========================================================================
         1.0                  No obstructions or local shielding
         0.9                  Light local shielding with few obstructions within two building heights
         0.7                  Local shielding with many large obstructions within two building heights
         0.5                  Heavily shielded, many large obstructions within one building height
         0.3                  Complete shielding with large buildings immediately adjacent
         ===================  =========================================================================

For each neighboring building defined, additional information is entered in ``extension/Neighbors/NeighborBuilding``.

  ============  ========  =======  ===========  ========  =======================  =============================================
  Element       Type      Units    Constraints  Required  Default                  Notes
  ============  ========  =======  ===========  ========  =======================  =============================================
  ``Azimuth``   integer   deg      0-359        Yes                                Direction of neighbors (clockwise from North)
  ``Distance``  double    ft       > 0          Yes                                Distance of neighbor from the dwelling unit
  ``Height``    double    ft       > 0          No        <same as dwelling unit>  Height of neighbor
  ============  ========  =======  ===========  ========  =======================  =============================================

HPXML Building Occupancy
************************

Building occupancy is entered in ``/HPXML/Building/BuildingDetails/BuildingSummary/BuildingOccupancy``.

  =====================  ========  =====  ===========  ========  ====================  ========================
  Element                Type      Units  Constraints  Required  Default               Notes
  =====================  ========  =====  ===========  ========  ====================  ========================
  ``NumberofResidents``  integer          >= 0         No        <number of bedrooms>  Number of occupants [#]_
  =====================  ========  =====  ===========  ========  ====================  ========================

  .. [#] NumberofResidents is only used for occupant heat gain. Most occupancy assumptions (e.g., usage of plug loads, appliances, hot water, etc.) are driven by the number of bedrooms, not number of occupants.

HPXML Building Construction
***************************

Building construction is entered in ``/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction``.

  =========================================================  ========  =========  ===========  ========  ========  =======================================================================
  Element                                                    Type      Units      Constraints  Required  Default   Notes
  =========================================================  ========  =========  ===========  ========  ========  =======================================================================
  ``ResidentialFacilityType``                                string               See [#]_     Yes                 Type of dwelling unit
  ``NumberofConditionedFloors``                              integer              > 0          Yes                 Number of conditioned floors (including a basement)
  ``NumberofConditionedFloorsAboveGrade``                    integer              > 0          Yes                 Number of conditioned floors above grade (including a walkout basement)
  ``NumberofBedrooms``                                       integer              > 0          Yes                 Number of bedrooms
  ``NumberofBathrooms``                                      integer              > 0          No        See [#]_  Number of bathrooms
  ``ConditionedFloorArea``                                   double    ft2        > 0          Yes                 Floor area within conditioned space boundary
  ``ConditionedBuildingVolume`` or ``AverageCeilingHeight``  double    ft3 or ft  > 0          Yes       See [#]_  Volume/ceiling height within conditioned space boundary
  ``extension/HasFlueOrChimney``                             boolean                           No        See [#]_  Presence of flue or chimney for infiltration model
  =========================================================  ========  =========  ===========  ========  ========  =======================================================================

  .. [#] ResidentialFacilityType choices are "single-family detached", "single-family attached", "apartment unit", or "manufactured home".
  .. [#] If NumberofBathrooms not provided, calculated as NumberofBedrooms/2 + 0.5 based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.
  .. [#] If ConditionedBuildingVolume not provided, calculated as AverageCeilingHeight * ConditionedFloorArea.
  .. [#] | If HasFlueOrChimney not provided, assumed to be true if any of the following conditions are met: 
         | A) heating system is non-electric Furnace, Boiler, WallFurnace, FloorFurnace, Stove, PortableHeater, or FixedHeater and AFUE/Percent is less than 0.89,
         | B) heating system is non-electric Fireplace, or
         | C) water heater is non-electric with energy factor (or equivalent calculated from uniform energy factor) less than 0.63.

HPXML Weather Station
---------------------

Weather information is entered in ``/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation``.

  =========================  ======  =======  ===========  ========  =======  ==============================================
  Element                    Type    Units    Constraints  Required  Default  Notes
  =========================  ======  =======  ===========  ========  =======  ==============================================
  ``extension/EPWFilePath``  string                        Yes                Path to the EnergyPlus weather file (EPW) [#]_
  =========================  ======  =======  ===========  ========  =======  ==============================================

  .. [#] A full set of U.S. TMY3 weather files can be `downloaded here <https://data.nrel.gov/system/files/128/tmy3s-cache-csv.zip>`_.

HPXML Enclosure
---------------

The dwelling unit's enclosure is entered in ``/HPXML/Building/BuildingDetails/Enclosure``.

All surfaces that bound different space types of the dwelling unit (i.e., not just thermal boundary surfaces) must be specified in the HPXML file.
For example, an attached garage would generally be defined by walls adjacent to conditioned space, walls adjacent to outdoors, a slab, and a roof or ceiling.
For software tools that do not collect sufficient inputs for every required surface, the software developers will need to make assumptions about these surfaces or collect additional input.

Interior partition surfaces (e.g., walls between rooms inside conditioned space, or the floor between two conditioned stories) can be excluded.

For single-family attached (SFA) or multifamily (MF) buildings, surfaces between unconditioned space and the neigboring unit's same unconditioned space should set ``InteriorAdjacentTo`` and ``ExteriorAdjacentTo`` to the same value.
For example, a foundation wall between the unit's vented crawlspace and the neighboring unit's vented crawlspace would use ``InteriorAdjacentTo="crawlspace - vented"`` and ``ExteriorAdjacentTo="crawlspace - vented"``.

.. warning::

  It is the software tool's responsibility to provide the appropriate building surfaces. 
  While some error-checking is in place, it is not possible to know whether some surfaces are incorrectly missing.

Also note that wall and roof surfaces do not require an azimuth to be specified. 
Rather, only the windows/skylights themselves require an azimuth. 
Thus, software tools can choose to use a single wall (or roof) surface to represent multiple wall (or roof) surfaces for the entire building if all their other properties (construction type, interior/exterior adjacency, etc.) are identical.

HPXML Air Infiltration
**********************

Building air leakage is entered in ``/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement``.

  ====================================  ======  =====  ===========  =============  ====================  ========================================================
  Element                               Type    Units  Constraints  Required       Default               Notes
  ====================================  ======  =====  ===========  =============  ====================  ========================================================
  ``BuildingAirLeakage/UnitofMeasure``  string         See [#]_                                          Units for air leakage
  ``HousePressure``                     double  Pa     > 0          Depends [#]_                         House pressure with respect to outside, typically ~50 Pa
  ``BuildingAirLeakage/AirLeakage``     double         > 0          Yes                                  Value for air leakage
  ``InfiltrationVolume``                double  ft3    > 0          No             <conditioned volume>  Volume associated with the air leakage measurement
  ====================================  ======  =====  ===========  =============  ====================  ========================================================

  .. [#] UnitofMeasure choices are "ACH" (air changes per hour at user-specified pressure), "CFM" (cubic feet per minute at user-specified pressure), or "ACHnatural" (natural air changes per hour).
  .. [#] HousePressure required if BuildingAirLeakage/UnitofMeasure is not "ACHnatural".

HPXML Attics
************

If the dwelling unit has a vented attic, attic ventilation information can be optionally entered in ``/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic[AtticType/Attic[Vented="true"]]/VentilationRate``.

  =================  ======  =====  ===========  ========  ==========  ==========================
  Element            Type    Units  Constraints  Required  Default     Notes
  =================  ======  =====  ===========  ========  ==========  ==========================
  ``UnitofMeasure``  string         See [#]_     No                    Units for ventilation rate
  ``Value``          double         > 0          No        1/300 [#]_  Value for ventilation rate
  =================  ======  =====  ===========  ========  ==========  ==========================

  .. [#] UnitofMeasure choices are "SLA" (specific leakage area) or "ACHnatural" (natural air changes per hour).
  .. [#] Value default based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.

HPXML Foundations
*****************

If the dwelling unit has a vented crawlspace, crawlspace ventilation information can be optionally entered in ``/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/Crawlspace[Vented="true"]]/VentilationRate``.

  =================  ======  =====  ===========  ========  ==========  ==========================
  Element            Type    Units  Constraints  Required  Default     Notes
  =================  ======  =====  ===========  ========  ==========  ==========================
  ``UnitofMeasure``  string         See [#]_     No                    Units for ventilation rate
  ``Value``          double         > 0          No        1/150 [#]_  Value for ventilation rate
  =================  ======  =====  ===========  ========  ==========  ==========================

  .. [#] UnitofMeasure only choice is "SLA" (specific leakage area).
  .. [#] Value default based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.

HPXML Roofs
***********

Each pitched or flat roof surface that is exposed to ambient conditions is entered as an ``/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof``.

For a multifamily building where the dwelling unit has another dwelling unit above it, the surface between the two dwelling units should be considered a ``FrameFloor`` and not a ``Roof``.

  ======================================  ================  ============  ===============  =============  ==============================  ==================================
  Element                                 Type              Units         Constraints      Required       Default                         Notes
  ======================================  ================  ============  ===============  =============  ==============================  ==================================
  ``InteriorAdjacentTo``                  string                          See [#]_         Yes                                            Interior adjacent space type
  ``Area``                                double            ft2           > 0              Yes                                            Gross area (including skylights)
  ``Azimuth``                             integer           deg           0-359            No             See [#]_                        Azimuth (clockwise from North)
  ``RoofType``                            string                          See [#]_         No             asphalt or fiberglass shingles  Roof type
  ``SolarAbsorptance`` or ``RoofColor``   double or string                0-1 or See [#]_  Yes            See [#]_                        Solar absorptance or color
  ``Emittance``                           double                          0-1              Yes                                            Emittance
  ``Pitch``                               integer           ?:12          >= 0             Yes                                            Pitch
  ``RadiantBarrier``                      boolean                                          Yes                                            Presence of radiant barrier
  ``RadiantBarrier/RadiantBarrierGrade``  integer                         1-3              Depends [#]_                                   Radiant barrier installation grade
  ``Insulation/AssemblyEffectiveRValue``  double            F-ft2-hr/Btu  > 0              Yes                                            Assembly R-value [#]_
  ======================================  ================  ============  ===============  =============  ==============================  ==================================

  .. [#] InteriorAdjacentTo choices are "living space", "attic - vented", "attic - unvented", or "garage".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] If Azimuth not provided, modeled as four surfaces of equal area facing every direction.
  .. [#] RoofType choices are "asphalt or fiberglass shingles", "wood shingles or shakes", "slate or tile shingles", or "metal surfacing".
  .. [#] RoofColor choices are "light", "medium", "medium dark", "dark", or "reflective".
  .. [#] | If SolarAbsorptance not provided, defaulted based on color/material as shown below:

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

  .. [#] RadiantBarrierGrade required if RadiantBarrier is provided.
  .. [#] AssemblyEffectiveRValue includes all material layers, interior/exterior air films, and insulation installation grade.

HPXML Rim Joists
****************

Each rim joist surface (i.e., the perimeter of floor joists typically found between stories of a building or on top of a foundation wall) are entered as an ``/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist``.

  ======================================  ================  ============  ===============  ========  ===========  ==============================
  Element                                 Type              Units         Constraints      Required  Default      Notes
  ======================================  ================  ============  ===============  ========  ===========  ==============================
  ``ExteriorAdjacentTo``                  string                          See [#]_         Yes                    Exterior adjacent space type
  ``InteriorAdjacentTo``                  string                          See [#]_         Yes                    Interior adjacent space type
  ``Area``                                double            ft2           > 0              Yes                    Gross area
  ``Azimuth``                             integer           deg           0-359            No        See [#]_     Azimuth (clockwise from North)
  ``Siding``                              string                          See [#]_         No        wood siding  Siding material
  ``SolarAbsorptance`` or ``Color``       double or string                0-1 or See [#]_  Yes       See [#]_     Solar absorptance or color
  ``Emittance``                           double                          0-1              Yes                    Emittance
  ``Insulation/AssemblyEffectiveRValue``  double            F-ft2-hr/Btu  > 0              Yes                    Assembly R-value [#]_
  ======================================  ================  ============  ===============  ========  ===========  ==============================

  .. [#] ExteriorAdjacentTo choices are "outside", "attic - vented", "attic - unvented", "basement - conditioned", "basement - unconditioned", "crawlspace - vented", "crawlspace - unvented", "garage", "other housing unit", "other heated space", "other multifamily buffer space", or "other non-freezing space".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] InteriorAdjacentTo choices are "living space", "attic - vented", "attic - unvented", "basement - conditioned", "basement - unconditioned", "crawlspace - vented", "crawlspace - unvented", or "garage".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] If Azimuth not provided, modeled as four surfaces of equal area facing every direction.
  .. [#] Siding choices are "wood siding", "vinyl siding", "stucco", "fiber cement siding", "brick veneer", or "aluminum siding".
  .. [#] Color choices are "light", "medium", "medium dark", "dark", or "reflective".
  .. [#] | If SolarAbsorptance not provided, defaulted based on color as shown below:
          
         =========== ================
         Color       SolarAbsorptance
         =========== ================
         dark        0.95
         medium dark 0.85
         medium      0.70
         light       0.50
         reflective  0.30
         =========== ================

  .. [#] AssemblyEffectiveRValue includes all material layers, interior/exterior air films, and insulation installation grade.

HPXML Walls
***********

Each wall that has no contact with the ground and bounds a space type is entered as an ``/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall``.

  ======================================  ================  ============  ===============  =============  ===========  ====================================
  Element                                 Type              Units         Constraints      Required       Default      Notes
  ======================================  ================  ============  ===============  =============  ===========  ====================================
  ``ExteriorAdjacentTo``                  string                          See [#]_         Yes                         Exterior adjacent space type
  ``InteriorAdjacentTo``                  string                          See [#]_         Yes                         Interior adjacent space type
  ``WallType``                            element                         See [#]_         Yes                         Wall type (for thermal mass)
  ``Area``                                double            ft2           > 0              Yes                         Gross area (including doors/windows)
  ``Azimuth``                             integer           deg           0-359            No             See [#]_     Azimuth (clockwise from North)
  ``Siding``                              string                          See [#]_         No             wood siding  Siding material
  ``SolarAbsorptance`` or ``Color``       double or string                0-1 or See [#]_  Yes            See [#]_     Solar absorptance or color
  ``Emittance``                           double                          0-1              Yes                         Emittance
  ``Insulation/AssemblyEffectiveRValue``  double            F-ft2-hr/Btu  > 0              Yes                         Assembly R-value [#]_
  ======================================  ================  ============  ===============  =============  ===========  ====================================

  .. [#] ExteriorAdjacentTo choices are "outside", "attic - vented", "attic - unvented", "basement - conditioned", "basement - unconditioned", "crawlspace - vented", "crawlspace - unvented", "garage", "other housing unit", "other heated space", "other multifamily buffer space", or "other non-freezing space".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] InteriorAdjacentTo choices are "living space", "attic - vented", "attic - unvented", "basement - conditioned", "basement - unconditioned", "crawlspace - vented", "crawlspace - unvented", or "garage".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] WallType child element choices are ``WoodStud``, ``DoubleWoodStud``, ``ConcreteMasonryUnit``, ``StructurallyInsulatedPanel``, ``InsulatedConcreteForms``, ``SteelFrame``, ``SolidConcrete``, ``StructuralBrick``, ``StrawBale``, ``Stone``, ``LogWall``, or ``Adobe``.
  .. [#] If Azimuth not provided, modeled as four surfaces of equal area facing every direction.
  .. [#] Siding choices are "wood siding", "vinyl siding", "stucco", "fiber cement siding", "brick veneer", or "aluminum siding".
  .. [#] Color choices are "light", "medium", "medium dark", "dark", or "reflective".
  .. [#] | If SolarAbsorptance not provided, defaulted based on color as shown below:
          
         =========== ================
         Color       SolarAbsorptance
         =========== ================
         dark        0.95
         medium dark 0.85
         medium      0.70
         light       0.50
         reflective  0.30
         =========== ================

  .. [#] AssemblyEffectiveRValue includes all material layers, interior/exterior air films, and insulation installation grade.

HPXML Foundation Walls
**********************

Each wall that is in contact with the ground should be specified as an ``/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall``.

Other walls (e.g., wood framed walls) that are connected to a below-grade space but have no contact with the ground should be specified as a ``Wall`` and not a ``FoundationWall``.

  ==============================================================  ========  ============  ===========  =============  ========  ====================================
  Element                                                         Type      Units         Constraints  Required       Default   Notes
  ==============================================================  ========  ============  ===========  =============  ========  ====================================
  ``ExteriorAdjacentTo``                                          string                  See [#]_     Yes                      Exterior adjacent space type [#]_
  ``InteriorAdjacentTo``                                          string                  See [#]_     Yes                      Interior adjacent space type
  ``Height``                                                      double    ft            > 0          Yes                      Total height
  ``Area``                                                        double    ft2           > 0          Yes                      Gross area (including doors/windows)
  ``Azimuth``                                                     integer   deg           0-359        No             See [#]_  Azimuth (clockwise from North)
  ``Thickness``                                                   double    inches        > 0          Yes                      Thickness excluding interior framing
  ``DepthBelowGrade``                                             double    ft            >= 0         Yes                      Depth below grade [#]_
  ``Insulation/Layer[InstallationType="continuous - interior"]``  element                              Depends [#]_             Interior insulation layer
  ``Insulation/Layer[InstallationType="continuous - exterior"]``  element                              Depends [#]_             Exterior insulation layer
  ``Insulation/AssemblyEffectiveRValue``                          double    F-ft2-hr/Btu  > 0          Depends [#]_             Assembly R-value [#]_
  ==============================================================  ========  ============  ===========  =============  ========  ====================================

  .. [#] ExteriorAdjacentTo choices are "ground", "basement - conditioned", "basement - unconditioned", "crawlspace - vented", "crawlspace - unvented", "garage", "other housing unit", "other heated space", "other multifamily buffer space", or "other non-freezing space".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] InteriorAdjacentTo choices are "basement - conditioned", "basement - unconditioned", "crawlspace - vented", "crawlspace - unvented", or "garage".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] Interior foundation walls (e.g., between basement and crawlspace) should **not** use "ground" even if the foundation wall has some contact with the ground due to the difference in below-grade depths of the two adjacent spaces.
  .. [#] If Azimuth not provided, modeled as four surfaces of equal area facing every direction.
  .. [#] For exterior foundation walls, depth below grade is relative to the ground plane.
         For interior foundation walls, depth below grade is the vertical span of foundation wall in contact with the ground.
         For example, an interior foundation wall between an 8 ft conditioned basement and a 3 ft crawlspace has a height of 8 ft and a depth below grade of 5 ft.
         Alternatively, an interior foundation wall between an 8 ft conditioned basement and an 8 ft unconditioned basement has a height of 8 ft and a depth below grade of 0 ft.
  .. [#] Layer[InstallationType="continuous - interior"] required if AssemblyEffectiveRValue is not provided.
  .. [#] Layer[InstallationType="continuous - exterior"] required if AssemblyEffectiveRValue is not provided.
  .. [#] AssemblyEffectiveRValue required if Layer elements are not provided.
  .. [#] AssemblyEffectiveRValue includes all material layers, interior air film, and insulation installation grade.
         R-value should **not** include exterior air film (for any above-grade exposure) or any soil thermal resistance.

If insulation layers are provided, additional information is entered in each ``FoundationWall/Insulation/Layer``.

  ==========================================  ========  ============  ===========  ========  =======  ======================================================================
  Element                                     Type      Units         Constraints  Required  Default  Notes
  ==========================================  ========  ============  ===========  ========  =======  ======================================================================
  ``NominalRValue``                           double    F-ft2-hr/Btu  >= 0         Yes                R-value of the foundatation wall insulation; use zero if no insulation
  ``extension/DistanceToTopOfInsulation``     double    ft            >= 0         Yes                Vertical distance from top of foundation wall to top of insulation
  ``extension/DistanceToBottomOfInsulation``  double    ft            >= 0         Yes                Vertical distance from top of foundation wall to bottom of insulation
  ==========================================  ========  ============  ===========  ========  =======  ======================================================================

HPXML Frame Floors
******************

Each horizontal floor/ceiling surface that is not in contact with the ground (Slab) nor adjacent to ambient conditions above (Roof) is entered as an ``/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor``.

  ======================================  ========  ============  ===========  ========  =======  ============================
  Element                                 Type      Units         Constraints  Required  Default  Notes
  ======================================  ========  ============  ===========  ========  =======  ============================
  ``ExteriorAdjacentTo``                  string                  See [#]_     Yes                Exterior adjacent space type
  ``InteriorAdjacentTo``                  string                  See [#]_     Yes                Interior adjacent space type
  ``Area``                                double    ft2           > 0          Yes                Gross area
  ``Insulation/AssemblyEffectiveRValue``  double    F-ft2-hr/Btu  > 0          Yes                Assembly R-value [#]_
  ======================================  ========  ============  ===========  ========  =======  ============================

  .. [#] ExteriorAdjacentTo choices are "outside", "attic - vented", "attic - unvented", "basement - conditioned", "basement - unconditioned", "crawlspace - vented", "crawlspace - unvented", "garage", "other housing unit", "other heated space", "other multifamily buffer space", or "other non-freezing space".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] InteriorAdjacentTo choices are "living space", "attic - vented", "attic - unvented", "basement - conditioned", "basement - unconditioned", "crawlspace - vented", "crawlspace - unvented", or "garage".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] AssemblyEffectiveRValue includes all material layers, interior/exterior air films, and insulation installation grade.

For frame floors adjacent to "other housing unit", "other heated space", "other multifamily buffer space", or "other non-freezing space", additional information is entered in ``FrameFloor``.

  ======================================  ========  =====  ==============  ========  =======  ==========================================
  Element                                 Type      Units  Constraints     Required  Default  Notes
  ======================================  ========  =====  ==============  ========  =======  ==========================================
  ``extension/OtherSpaceAboveOrBelow``    string           See [#]_        Yes                Specifies if above/below the MF space type
  ======================================  ========  =====  ==============  ========  =======  ==========================================

  .. [#] OtherSpaceAboveOrBelow choices are "above" or "below".

HPXML Slabs
***********

Each space type that borders the ground (i.e., basements, crawlspaces, garages, and slab-on-grade foundations) should have a slab entered as an ``/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab``.

  ===========================================  ========  ============  ===========  =============  =======  ====================================================
  Element                                      Type      Units         Constraints  Required       Default  Notes
  ===========================================  ========  ============  ===========  =============  =======  ====================================================
  ``InteriorAdjacentTo``                       string                  See [#]_     Yes                     Interior adjacent space type
  ``Area``                                     double    ft2           > 0          Yes                     Gross area
  ``Thickness``                                double    inches        >= 0         Yes                     Thickness [#]_
  ``ExposedPerimeter``                         double    ft            > 0          Yes                     Perimeter exposed to ambient conditions [#]_
  ``PerimeterInsulationDepth``                 double    ft            >= 0         Yes                     Depth from grade to bottom of vertical insulation
  ``UnderSlabInsulationWidth``                 double    ft            >= 0         Depends [#]_            Width from slab edge inward of horizontal insulation
  ``UnderSlabInsulationSpansEntireSlab``       boolean                              Depends [#]_            Whether horizontal insulation spans entire slab
  ``DepthBelowGrade``                          double    ft            >= 0         Depends [#]_            Depth from the top of the slab surface to grade
  ``PerimeterInsulation/Layer/NominalRValue``  double    F-ft2-hr/Btu  >= 0         Yes                     R-value of vertical insulation
  ``UnderSlabInsulation/Layer/NominalRValue``  double    F-ft2-hr/Btu  >= 0         Yes                     R-value of horizontal insulation
  ``extension/CarpetFraction``                 double    frac          0-1          Yes                     Fraction of slab covered by carpet
  ``extension/CarpetRValue``                   double    F-ft2-hr/Btu  >= 0         Yes                     Carpet R-value
  ===========================================  ========  ============  ===========  =============  =======  ====================================================

  .. [#] InteriorAdjacentTo choices are "living space", "basement - conditioned", "basement - unconditioned", "crawlspace - vented", "crawlspace - unvented", or "garage".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] For a crawlspace with a dirt floor, use a thickness of zero.
  .. [#] ExposedPerimeter includes any slab length that falls along the perimeter of the building's footprint (i.e., is exposed to ambient conditions).
         So a basement slab edge adjacent to a garage or crawlspace, for example, should not be included.
  .. [#] UnderSlabInsulationWidth required if UnderSlabInsulationSpansEntireSlab=true is not provided.
  .. [#] UnderSlabInsulationSpansEntireSlab=true required if UnderSlabInsulationWidth is not provided.
  .. [#] DepthBelowGrade required if the attached foundation has no ``FoundationWalls``.
         For foundation types with walls, the the slab's position relative to grade is determined by the ``FoundationWall/DepthBelowGrade`` value.

.. _windowinputs:

HPXML Windows
*************

Each window or glass door area is entered as an ``/HPXML/Building/BuildingDetails/Enclosure/Windows/Window``.

  ============================================  ========  ============  ===========  ========  =========  ==============================================
  Element                                       Type      Units         Constraints  Required  Default    Notes
  ============================================  ========  ============  ===========  ========  =========  ==============================================
  ``Area``                                      double    ft2           > 0          Yes                  Total area
  ``Azimuth``                                   integer   deg           0-359        Yes                  Azimuth (clockwise from North)
  ``UFactor``                                   double    Btu/F-ft2-hr  > 0          Yes                  Full-assembly NFRC U-factor
  ``SHGC``                                      double                  0-1          Yes                  Full-assembly NFRC solar heat gain coefficient
  ``InteriorShading/SummerShadingCoefficient``  double    frac          0-1          No        0.70 [#]_  Summer interior shading coefficient
  ``InteriorShading/WinterShadingCoefficient``  double    frac          0-1          No        0.85 [#]_  Winter interior shading coefficient
  ``Overhangs``                                 element                 >= 0         No        <none>     Presence of overhangs (including eaves)
  ``FractionOperable``                          double    frac          0-1          No        0.67       Operable fraction [#]_
  ``AttachedToWall``                            idref                   See [#]_     Yes                  ID of attached wall
  ============================================  ========  ============  ===========  ========  =========  ==============================================

  .. [#] SummerShadingCoefficient default value indicates 30% reduction in solar heat gain, based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.
  .. [#] WinterShadingCoefficient default value indicates 15% reduction in solar heat gain, based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.
  .. [#] FractionOperable reflects whether the windows are operable (can be opened), not how they are used by the occupants.
         If a ``Window`` represents a single window, the value should be 0 or 1.
         If a ``Window`` represents multiple windows (e.g., 4), the value should be between 0 and 1 (e.g., 0, 0.25, 0.5, 0.75, or 1).
         The total open window area for natural ventilation is calculated using A) the operable fraction, B) the assumption that 50% of the area of operable windows can be open, and C) the assumption that 20% of that openable area is actually opened by occupants whenever outdoor conditions are favorable for cooling.
  .. [#] AttachedToWall must reference a ``Wall`` or ``FoundationWall``.

If overhangs are specified, additional information is entered in ``Overhangs``.

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

Each skylight is entered as an ``/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight``.

  ============================================  ========  ============  ===========  ========  =========  ==============================================
  Element                                       Type      Units         Constraints  Required  Default    Notes
  ============================================  ========  ============  ===========  ========  =========  ==============================================
  ``Area``                                      double    ft2           > 0          Yes                  Total area
  ``Azimuth``                                   integer   deg           0-359        Yes                  Azimuth (clockwise from North)
  ``UFactor``                                   double    Btu/F-ft2-hr  > 0          Yes                  Full-assembly NFRC U-factor
  ``SHGC``                                      double                  0-1          Yes                  Full-assembly NFRC solar heat gain coefficient
  ``InteriorShading/SummerShadingCoefficient``  double    frac          0-1          No        1.0 [#]_   Summer interior shading coefficient
  ``InteriorShading/WinterShadingCoefficient``  double    frac          0-1          No        1.0 [#]_   Winter interior shading coefficient
  ``AttachedToRoof``                            idref                   See [#]_     Yes                  ID of attached roof
  ============================================  ========  ============  ===========  ========  =========  ==============================================

  .. [#] SummerShadingCoefficient default value indicates 0% reduction in solar heat gain.
  .. [#] WinterShadingCoefficient default value indicates 0% reduction in solar heat gain.
  .. [#] AttachedToRoof must reference a ``Roof``.

HPXML Doors
***********

Each opaque door is entered as an ``/HPXML/Building/BuildingDetails/Enclosure/Doors/Door``.

  ============================================  ========  ============  ===========  ========  =========  ==============================
  Element                                       Type      Units         Constraints  Required  Default    Notes
  ============================================  ========  ============  ===========  ========  =========  ==============================
  ``AttachedToWall``                            idref                   See [#]_     Yes                  ID of attached wall
  ``Area``                                      double    ft2           > 0          Yes                  Total area
  ``Azimuth``                                   integer   deg           0-359        Yes                  Azimuth (clockwise from North)
  ``RValue``                                    double    F-ft2-hr/Btu  > 0          Yes                  R-value
  ============================================  ========  ============  ===========  ========  =========  ==============================

  .. [#] AttachedToWall must reference a ``Wall`` or ``FoundationWall``.

HPXML Systems
-------------

The dwelling unit's systems are entered in ``/HPXML/Building/BuildingDetails/Systems``.

HPXML Heating Systems
*********************

Each heating system (other than heat pumps) is entered as an ``/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem``.

  =================================  ========  ======  ===========  ========  =========  ====================================
  Element                            Type      Units   Constraints  Required  Default    Notes
  =================================  ========  ======  ===========  ========  =========  ====================================
  ``HeatingSystemType``              element           See [#]_     Yes                  Type of heating system
  ``FractionHeatLoadServed``         double    frac    0-1          Yes                  Fraction of heating load served [#]_
  ``HeatingSystemFuel``              string            See [#]_     Yes                  Fuel type
  ``AnnualHeatingEfficiency/Units``  string            See [#]_     Yes                  Efficiency units
  ``AnnualHeatingEfficiency/Value``  double    frac    0-1          Yes                  Efficiency value
  ``HeatingCapacity``                double    Btu/hr  >= 0         No        autosized  Input heating capacity [#]_
  =================================  ========  ======  ===========  ========  =========  ====================================

  .. [#] HeatingSystemType child element choices are ``ElectricResistance``, ``Furnace``, ``WallFurnace``, ``FloorFurnace``, ``Boiler``, ``Stove``, ``PortableHeater``, ``FixedHeater``, or ``Fireplace``.
  .. [#] The sum of all ``FractionHeatLoadServed`` (across both HeatingSystems and HeatPumps) must be less than or equal to 1.
         For example, the dwelling unit could have a boiler heating system and a heat pump with values of 0.4 (40%) and 0.6 (60%), respectively.
  .. [#] HeatingSystemFuel choices are  "electricity", "natural gas", "fuel oil", "fuel oil 1", "fuel oil 2", "fuel oil 4", "fuel oil 5/6", "diesel", "propane", "kerosene", "coal", "coke", "bituminous coal", "wood", or "wood pellets".
         For ``ElectricResistance``, "electricity" is required.
  .. [#] AnnualHeatingEfficiency/Value "AFUE" required for ``Furnace``, ``WallFurnace``, ``FloorFurnace``, and ``Boiler``.
         "Percent" required for all other systems.
  .. [#] HeatingCapacity not applicable to shared boilers.

Electric Resistance
~~~~~~~~~~~~~~~~~~~

If electric resistance heating is specified, no additional information is entered.

Furnace
~~~~~~~

If a furnace is specified, additional information is entered in ``HeatingSystem``.

  =================================  ========  =====  ===========  ========  =========  ==================================
  Element                            Type      Units  Constraints  Required  Default    Notes
  =================================  ========  =====  ===========  ========  =========  ==================================
  ``DistributionSystem``             idref            See [#]_     Yes                  ID of attached distribution system
  ``extension/FanPowerWattsPerCFM``  double    W/cfm  >= 0         No        See [#]_   Installed fan efficiency
  =================================  ========  =====  ===========  ========  =========  ==================================

  .. [#] HVACDistribution type must be AirDistribution or DSE.
  .. [#] If FanPowerWattsPerCFM not provided, defaulted as 0.5 W/cfm if AFUE <= 0.9, else 0.375 W/cfm.

Wall/Floor Furnace
~~~~~~~~~~~~~~~~~~

If a wall furnace or floor furnace is specified, additional information is entered in ``HeatingSystem``.

  ===========================  ========  =====  ===========  ============  =========  ===================
  Element                      Type      Units  Constraints  Required      Default    Notes
  ===========================  ========  =====  ===========  ============  =========  ===================
  ``extension/FanPowerWatts``  double    W      >= 0         No            0          Installed fan power
  ===========================  ========  =====  ===========  ============  =========  ===================

Boiler
~~~~~~

If a boiler is specified, additional information is entered in ``HeatingSystem``.

  ===========================  ========  ======  ===========  ========  ========  =========================================
  Element                      Type      Units   Constraints  Required  Default   Notes
  ===========================  ========  ======  ===========  ========  ========  =========================================
  ``IsSharedSystem``           boolean                        No        false     Whether it serves multiple dwelling units
  ``DistributionSystem``       idref             See [#]_     Yes                 ID of attached distribution system
  ``ElectricAuxiliaryEnergy``  double    kWh/yr  >= 0         No [#]_   See [#]_  Electric auxiliary energy
  ===========================  ========  ======  ===========  ========  ========  =========================================

  .. [#] HVACDistribution type must be HydronicDistribution or DSE for in-unit boilers and HydronicDistribution or HydronicAndAirDistribution for shared boilers.
  .. [#] | For shared boilers, ElectricAuxiliaryEnergy can alternatively be calculated as follows per `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_:
         | :math:`EAE = (\frac{SP}{N_{dweq}} + aux_{in}) \cdot HLH`
         | where, 
         |   SP = Shared pump power [W], provided as ``extension/SharedLoopWatts``
         |   N_dweq = Number of units served by the shared system, provided as ``NumberofUnitsServed``
         |   aux_in = In-unit fan coil power [W], provided as ``extension/FanCoilWatts``
         |   HLH = Annual heating load hours
  .. [#] | If ElectricAuxiliaryEnergy not provided (or calculated for shared boilers), defaults as follows per `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_:

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

Stove
~~~~~

If a stove is specified, additional information is entered in ``HeatingSystem``.

  ===========================  ========  =====  ===========  ============  =========  ===================
  Element                      Type      Units  Constraints  Required      Default    Notes
  ===========================  ========  =====  ===========  ============  =========  ===================
  ``extension/FanPowerWatts``  double    W      >= 0         No            40         Installed fan power
  ===========================  ========  =====  ===========  ============  =========  ===================

Portable/Fixed Heater
~~~~~~~~~~~~~~~~~~~~~

If a portable heater or fixed heater is specified, additional information is entered in ``HeatingSystem``.

  ===========================  ========  =====  ===========  ============  =========  ===================
  Element                      Type      Units  Constraints  Required      Default    Notes
  ===========================  ========  =====  ===========  ============  =========  ===================
  ``extension/FanPowerWatts``  double    W      >= 0         No            0          Installed fan power
  ===========================  ========  =====  ===========  ============  =========  ===================

Fireplace
~~~~~~~~~

If a fireplace is specified, additional information is entered in ``HeatingSystem``.

  ===========================  ========  =====  ===========  ============  =========  ===================
  Element                      Type      Units  Constraints  Required      Default    Notes
  ===========================  ========  =====  ===========  ============  =========  ===================
  ``extension/FanPowerWatts``  double    W      >= 0         No            0          Installed fan power
  ===========================  ========  =====  ===========  ============  =========  ===================

HPXML Cooling Systems
*********************

Each cooling system (other than heat pumps) is entered as an ``/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem``.

  ==========================  ========  ======  ===========  ========  =======  ====================================
  Element                     Type      Units   Constraints  Required  Default  Notes
  ==========================  ========  ======  ===========  ========  =======  ====================================
  ``CoolingSystemType``       string            See [#]_     Yes                Type of cooling system
  ``CoolingSystemFuel``       string            electricity  Yes                Fuel type
  ``FractionCoolLoadServed``  double    frac    0-1          Yes                Fraction of cooling load served [#]_
  ==========================  ========  ======  ===========  ========  =======  ====================================

  .. [#] CoolingSystemType choices are "central air conditioner", "room air conditioner", "evaporative cooler", "mini-split", "chiller", or "cooling tower".
  .. [#] The sum of all ``FractionCoolLoadServed`` (across both CoolingSystems and HeatPumps) must be less than or equal to 1.
         For example, the dwelling unit could have two room air conditioners with values of 0.1 (10%) and 0.2 (20%), respectively, with the rest of the home (70%) uncooled.

Central Air Conditioner
~~~~~~~~~~~~~~~~~~~~~~~

If a central air conditioner is specified, additional information is entered in ``CoolingSystem``.

  =================================  ========  ======  ===========  ========  =========  ==================================
  Element                            Type      Units   Constraints  Required  Default    Notes
  =================================  ========  ======  ===========  ========  =========  ==================================
  ``DistributionSystem``             idref             See [#]_     Yes                  ID of attached distribution system
  ``AnnualCoolingEfficiency/Units``  string            SEER         Yes                  Efficiency units
  ``AnnualCoolingEfficiency/Value``  double            > 0          Yes                  Efficiency value
  ``CoolingCapacity``                double    Btu/hr  >= 0         No        autosized  Cooling capacity
  ``SensibleHeatFraction``           double    frac    0-1          No        <TODO>     Sensible heat fraction
  ``CompressorType``                 string            See [#]_     No        See [#]_   Type of compressor
  ``extension/FanPowerWattsPerCFM``  double    W/cfm   >= 0         No        See [#]_   Installed fan efficiency
  =================================  ========  ======  ===========  ========  =========  ==================================

  .. [#] HVACDistribution type must be AirDistribution or DSE.
  .. [#] CompressorType choices are "single stage", "two stage", or "variable speed".
  .. [#] If CompressorType not provided, defaults to "single stage" if SEER <= 15, else "two stage" if SEER <= 21, else "variable speed".
  .. [#] If FanPowerWattsPerCFM not provided, defaults to using attached furnace W/cfm if available, else 0.5 W/cfm if SEER <= 13.5, else 0.375 W/cfm.

Room Air Conditioner
~~~~~~~~~~~~~~~~~~~~

If a room air conditioner is specified, additional information is entered in ``CoolingSystem``.

  =================================  ========  ======  ===========  ========  =========  ======================
  Element                            Type      Units   Constraints  Required  Default    Notes
  =================================  ========  ======  ===========  ========  =========  ======================
  ``AnnualCoolingEfficiency/Units``  string            EER          Yes                  Efficiency units
  ``AnnualCoolingEfficiency/Value``  double            > 0          Yes                  Efficiency value
  ``CoolingCapacity``                double    Btu/hr  >= 0         No        autosized  Cooling capacity
  ``SensibleHeatFraction``           double    frac    0-1          No        <TODO>     Sensible heat fraction
  =================================  ========  ======  ===========  ========  =========  ======================

Evaporative Cooler
~~~~~~~~~~~~~~~~~~

If an evaporative cooler is specified, additional information is entered in ``CoolingSystem``.

  =================================  ========  ======  ===========  ========  =========  ==================================
  Element                            Type      Units   Constraints  Required  Default    Notes
  =================================  ========  ======  ===========  ========  =========  ==================================
  ``DistributionSystem``             idref             See [#]_     No                   ID of attached distribution system
  ``extension/FanPowerWattsPerCFM``  double    W/cfm   >= 0         No        See [#]_   Installed fan efficiency
  =================================  ========  ======  ===========  ========  =========  ==================================

  .. [#] HVACDistribution type must be AirDistribution or DSE.
  .. [#] If FanPowerWattsPerCFM not provided, defaults to MIN(2.79 * cfm^-0.29, 0.6) W/cfm.

Mini-Split
~~~~~~~~~~

If a mini-split is specified, additional information is entered in ``CoolingSystem``.

  =================================  ========  ======  ===========  ========  =========  ==================================
  Element                            Type      Units   Constraints  Required  Default    Notes
  =================================  ========  ======  ===========  ========  =========  ==================================
  ``DistributionSystem``             idref             See [#]_     No                   ID of attached distribution system
  ``CoolingCapacity``                double    Btu/hr  >= 0         No        autosized  Cooling capacity
  ``SensibleHeatFraction``           double    frac    0-1          No        <TODO>     Sensible heat fraction
  ``extension/FanPowerWattsPerCFM``  double    W/cfm   >= 0         No        See [#]_   Installed fan efficiency
  =================================  ========  ======  ===========  ========  =========  ==================================

  .. [#] HVACDistribution type must be AirDistribution or DSE.
  .. [#] If FanPowerWattsPerCFM not provided, defaults to 0.07 W/cfm if ductless, else 0.18 W/cfm.

Chiller
~~~~~~~

If a chiller is specified, additional information is entered in ``CoolingSystem``.

  ======================  ========  ======  ===========  ========  =========  =========================================
  Element                 Type      Units   Constraints  Required  Default    Notes
  ======================  ========  ======  ===========  ========  =========  =========================================
  ``IsSharedSystem``      boolean           true         Yes                  Whether it serves multiple dwelling units
  ``DistributionSystem``  idref             See [#]_     Yes                  ID of attached distribution system
  ======================  ========  ======  ===========  ========  =========  =========================================

  .. [#] HVACDistribution type must be HydronicDistribution or HydronicAndAirDistribution.

  Chillers are modeled with a SEER equivalent using the following equation from `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_:

    | :math:`SEER_{eq} = \frac{(Cap - (aux \cdot 3.41)) - (aux_{dweq} \cdot 3.41 \cdot N_{dweq})}{(Input \cdot aux) + (aux_{dweq} \cdot N_{dweq})}`
    | where, 
    |   Cap = Chiller system output [Btu/hour], provided as ``CoolingCapacity``
    |   aux = Total of the pumping and fan power serving the system [W], provided as ``extension/SharedLoopWatts``
    |   aux_dweq = Total of the in-unit cooling equipment power serving the unit; for example, includes all power to run a Water Loop Heat Pump within the unit, not just air handler power [W], provided as ``extension/FanCoilWatts`` for fan coils, or calculated as ``extension/WaterLoopHeatPump/CoolingCapacity`` divided by ``extension/WaterLoopHeatPump/AnnualCoolingEfficiency[Units="EER"]/Value`` for cooling towers, or zero for baseboard/radiators
    |   Input = Chiller system power [W], calculated using ``AnnualCoolingEfficiency[Units="kW/ton"]/Value``
    |   N_dweq = Number of units served by the shared system, provided as ``NumberofUnitsServed``

Cooling Tower
~~~~~~~~~~~~~

If a **cooling tower** is specified, additional information is entered in ``CoolingSystem``.

  ======================  ========  ======  ===========  ========  =========  =========================================
  Element                 Type      Units   Constraints  Required  Default    Notes
  ======================  ========  ======  ===========  ========  =========  =========================================
  ``IsSharedSystem``      boolean           true         Yes                  Whether it serves multiple dwelling units
  ``DistributionSystem``  idref             See [#]_     Yes                  ID of attached distribution system
  ======================  ========  ======  ===========  ========  =========  =========================================

  .. [#] HVACDistribution type must be HydronicAndAirDistribution.

  Cooling towers with water loop heat pumps are modeled with a SEER equivalent using the following equation from `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_:

    | :math:`SEER_{eq} = \frac{WLHP_{cap} - \frac{aux \cdot 3.41}{N_{dweq}}}{Input + \frac{aux}{N_{dweq}}}`
    | where, 
    |   WLHP_cap = WLHP cooling capacity [Btu/hr], provided as ``extension/WaterLoopHeatPump/CoolingCapacity``
    |   aux = Total of the pumping and fan power serving the system [W], provided as ``extension/SharedLoopWatts``
    |   N_dweq = Number of units served by the shared system, provided as ``NumberofUnitsServed``
    |   Input = WLHP system power [W], calculated as ``extension/WaterLoopHeatPump/CoolingCapacity`` divided by ``extension/WaterLoopHeatPump/AnnualCoolingEfficiency[Units="EER"]/Value``

HPXML Heat Pumps
****************

FIXME FIXME FIXME

Each heat pump is entered as a ``Systems/HVAC/HVACPlant/HeatPump``.
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
  |   SP = Shared pump power [W], provided as ``extension/SharedLoopWatts``
  |   N_dweq = Number of units served by the shared system, provided as ``NumberofUnitsServed``

HPXML HVAC Control
******************

If any HVAC systems are specified, a single thermostat is entered as a ``/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl``.
Thermostat setpoints must be entered using either simple inputs or detailed inputs.

In addition to the setpoint inputs below, if there are sufficient ceiling fans present that result in a reduced cooling setpoint, this information can be entered in ``HVACControl``.

  =======================================================  ========  =======  ===========  ========  =========  ===================================
  Element                                                  Type      Units    Constraints  Required  Default    Notes
  =======================================================  ========  =======  ===========  ========  =========  ===================================
  ``extension/CeilingFanSetpointTempCoolingSeasonOffset``  double    deg-F    >= 0         No        0          Cooling setpoint temperature offset
  =======================================================  ========  =======  ===========  ========  =========  ===================================

Simple Inputs
~~~~~~~~~~~~~

To define simple thermostat setpoints, additional information is entered in ``HVACControl``.

  =============================  ========  =======  ===========  ========  =========  ============================
  Element                        Type      Units    Constraints  Required  Default    Notes
  =============================  ========  =======  ===========  ========  =========  ============================
  ``SetpointTempHeatingSeason``  double    deg-F                 Yes                  Heating setpoint temperature
  ``SetpointTempCoolingSeason``  double    deg-F                 Yes                  Cooling setpoint temperature
  =============================  ========  =======  ===========  ========  =========  ============================

If there is a heating temperature setback, additional information is entered in ``HVACControl``.

  =====================================  ========  ========  ===========  ========  =========  =========================================
  Element                                Type      Units     Constraints  Required  Default    Notes
  =====================================  ========  ========  ===========  ========  =========  =========================================
  ``SetbackTempHeatingSeason``           double    deg-F                  Yes                  Heating setback temperature
  ``TotalSetbackHoursperWeekHeating``    integer   hrs/week  > 0          Yes                  Hours/week of heating temperature setback
  ``extension/SetbackStartHourHeating``  integer             0-23         Yes                  Daily setback start hour
  =====================================  ========  ========  ===========  ========  =========  =========================================

If there is a cooling temperature setup, additional information is entered in ``HVACControl``.

  =====================================  ========  ========  ===========  ========  =========  =========================================
  Element                                Type      Units     Constraints  Required  Default    Notes
  =====================================  ========  ========  ===========  ========  =========  =========================================
  ``SetupTempCoolingSeason``             double    deg-F                  Yes                  Cooling setup temperature
  ``TotalSetupHoursperWeekCooling``      integer   hrs/week  > 0          Yes                  Hours/week of cooling temperature setup
  ``extension/SetupStartHourCooling``    integer             0-23         Yes                  Daily setup start hour
  =====================================  ========  ========  ===========  ========  =========  =========================================

Detailed Inputs
~~~~~~~~~~~~~~~

To define detailed thermostat setpoints, additional information is entered in ``HVACControl``.

  ===============================================  =====  =======  ===========  ========  =========  ============================================
  Element                                          Type   Units    Constraints  Required  Default    Notes
  ===============================================  =====  =======  ===========  ========  =========  ============================================
  ``extension/WeekdaySetpointTempsHeatingSeason``  array  deg-F                 Yes                  24 comma-separated weekday heating setpoints
  ``extension/WeekendSetpointTempsHeatingSeason``  array  deg-F                 Yes                  24 comma-separated weekend heating setpoints
  ``extension/WeekdaySetpointTempsCoolingSeason``  array  deg-F                 Yes                  24 comma-separated weekday cooling setpoints
  ``extension/WeekendSetpointTempsCoolingSeason``  array  deg-F                 Yes                  24 comma-separated weekend cooling setpoints
  ===============================================  =====  =======  ===========  ========  =========  ============================================

HPXML HVAC Distribution
***********************

FIXME FIXME FIXME

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

If ``DuctLocation`` is provided, it can be one of "living space", "basement - conditioned", "basement - unconditioned", "crawlspace - unvented", "crawlspace - vented", "attic - unvented", "attic - vented", "garage", "outside", "exterior wall", "under slab", "roof deck", "other housing unit", "other heated space", "other multifamily buffer space", "other non-freezing space".
See :ref:`hpxmllocations` for descriptions.

If ``DuctLocation`` is not provided, it will be chosen based on the presence of spaces and the "Default Priority" indicated below.

==========================  ================
Value                       Default Priority
==========================  ================
"basement - conditioned"    1
"basement - unconditioned"  2
"crawlspace - vented"       3
"crawlspace - unvented"     4
"attic - vented"            5
"attic - unvented"          6
"garage"                    7
"living space"              8
==========================  ================

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

HPXML Ventilation Fans
**********************

Each ventilation fan system is entered as an ``/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan``.

Whole Home Ventilation
~~~~~~~~~~~~~~~~~~~~~~

Each mechanical ventilation systems that provide whole home ventilation is entered as a ``/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan``.

  =======================================  ========  =======  ===========  ========  =========  =========================================
  Element                                  Type      Units    Constraints  Required  Default    Notes
  =======================================  ========  =======  ===========  ========  =========  =========================================
  ``UsedForWholeBuildingVentilation``      boolean            true         Yes                  Must be set to true
  ``IsSharedSystem``                       boolean            See [#]_     No        false      Whether it serves multiple dwelling units
  ``FanType``                              string             See [#]_     Yes                  Type of ventilation system
  ``TestedFlowRate`` or ``RatedFlowRate``  double    cfm      >= 0         Yes                  Flow rate [#]_
  ``HoursInOperation``                     double    hrs/day  0-24         Yes                  Hours per day of operation [#]_
  ``FanPower``                             double    W        >= 0         Yes                  Fan power
  =======================================  ========  =======  ===========  ========  =========  =========================================

  .. [#] For central fan integrated supply systems, IsSharedSystem must be false.
  .. [#] FanType choices are "energy recovery ventilator", "heat recovery ventilator", "exhaust only", "supply only", "balanced", or "central fan integrated supply".
  .. [#] For a central fan integrated supply system, the flow rate should equal the amount of outdoor air provided to the distribution system.
  .. [#] Typically 24 hrs/day (i.e., running continuously) for all system types other than central fan integrated supply (CFIS).
         Typically less than 24 hrs/day (i.e., running intermittently) for CFIS systems.

If a **heat recovery ventilator** system is specified, additional information is entered in ``VentilationFan``.

  ========================================================================  ======  =====  ===========  ========  =======  ============================
  Element                                                                   Type    Units  Constraints  Required  Default  Notes
  ========================================================================  ======  =====  ===========  ========  =======  ============================
  ``SensibleRecoveryEfficiency`` or ``AdjustedSensibleRecoveryEfficiency``  double  frac   0-1          Yes                Sensible recovery efficiency
  ========================================================================  ======  =====  ===========  ========  =======  ============================

If an **energy recovery ventilator** system is specified, additional information is entered in ``VentilationFan``.

  ========================================================================  ======  =====  ===========  ========  =======  ============================
  Element                                                                   Type    Units  Constraints  Required  Default  Notes
  ========================================================================  ======  =====  ===========  ========  =======  ============================
  ``TotalRecoveryEfficiency`` or ``AdjustedTotalRecoveryEfficiency``        double  frac   0-1          Yes                Total recovery efficiency
  ``SensibleRecoveryEfficiency`` or ``AdjustedSensibleRecoveryEfficiency``  double  frac   0-1          Yes                Sensible recovery efficiency
  ========================================================================  ======  =====  ===========  ========  =======  ============================

If a **central fan integrated supply** system is specified, additional information is entered in ``VentilationFan``.

  ====================================  ======  =====  ===========  ========  =======  ==================================
  Element                               Type    Units  Constraints  Required  Default  Notes
  ====================================  ======  =====  ===========  ========  =======  ==================================
  ``AttachedToHVACDistributionSystem``  idref          See [#]_     Yes                ID of attached distribution system
  ====================================  ======  =====  ===========  ========  =======  ==================================

  .. [#] HVACDistribution type cannot be HydronicDistribution.

If a **shared** system is specified, additional information is entered in ``VentilationFan``.

  ============================  =======  =====  ===========  ========  =======  ====================================================
  Element                       Type     Units  Constraints  Required  Default  Notes
  ============================  =======  =====  ===========  ========  =======  ====================================================
  ``FractionRecirculation``     double   frac   0-1          Yes                Fraction of supply air that is recirculated [#]_
  ``extension/InUnitFlowRate``  double   cfm    >= 0         Yes                Total flow rate delivered to the dwelling unit
  ``extension/PreHeating``      element                      No        <none>   Supply air preconditioned by heating equipment? [#]_
  ``extension/PreCooling``      element                      No        <none>   Supply air preconditioned by cooling equipment? [#]_
  ============================  =======  =====  ===========  ========  =======  ====================================================

  .. [#] 1-FractionRecirculation is assumed to be the fraction of supply air that is provided from outside.
         The value must be 0 for exhaust only systems.
  .. [#] PreHeating not allowed for exhaust only systems.
  .. [#] PreCooling not allowed for exhaust only systems.

If a **shared system with preheating** is specified, additional information is entered in ``extension/PreHeating``.

  ==============================================  =======  =====  ===========  ========  =======  ===================================================================
  Element                                         Type     Units  Constraints  Required  Default  Notes
  ==============================================  =======  =====  ===========  ========  =======  ===================================================================
  ``Fuel``                                        string          See [#]_     Yes                Preheating equipment fuel type
  ``AnnualHeatingEfficiency[Units="COP"]/Value``  double          > 0          Yes                Preheating equipment annual COP
  ``FractionVentilationHeatLoadServed``           double   frac   0-1          Yes                Fraction of ventilation heating load served by preheating equipment
  ==============================================  =======  =====  ===========  ========  =======  ===================================================================

  .. [#] Fuel choices are "natural gas", "fuel oil", "fuel oil 1", "fuel oil 2", "fuel oil 4", "fuel oil 5/6", "diesel", "propane", "kerosene", "coal", "coke", "bituminous coal", "anthracite coal", "electricity", "wood", or "wood pellets".

If a **shared system with precooling** is specified, additional information is entered in ``extension/PreCooling``.

  ==============================================  =======  =====  ===========  ========  =======  ===================================================================
  Element                                         Type     Units  Constraints  Required  Default  Notes
  ==============================================  =======  =====  ===========  ========  =======  ===================================================================
  ``Fuel``                                        string          See [#]_     Yes                Precooling equipment fuel type
  ``AnnualCoolingEfficiency[Units="COP"]/Value``  double          > 0          Yes                Precooling equipment annual COP
  ``FractionVentilationCoolLoadServed``           double   frac   0-1          Yes                Fraction of ventilation cooling load served by precooling equipment
  ==============================================  =======  =====  ===========  ========  =======  ===================================================================

  .. [#] Fuel only choice is "electricity".

Local Ventilation
~~~~~~~~~~~~~~~~~

Each kitchen range fan or bathroom fan that provides local ventilation is entered as a ``/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan``.

  ===========================  =======  =======  ===========  ========  ========  =============================
  Element                      Type     Units    Constraints  Required  Default   Notes
  ===========================  =======  =======  ===========  ========  ========  =============================
  ``UsedForLocalVentilation``  boolean           true         Yes                 Must be set to true
  ``Quantity``                 integer           >= 0         No        See [#]_  Number of identical fans
  ``RatedFlowRate``            double   cfm      >= 0         No        See [#]_  Flow rate
  ``HoursInOperation``         double   hrs/day  0-24         No        See [#]_  Hours per day of operation
  ``FanLocation``              string            See [#]_     Yes                 Location of the fan
  ``FanPower``                 double   W        >= 0         No        See [#]_  Fan power
  ``extension/StartHour``      integer           0-23         No        See [#]_  Daily start hour of operation
  ===========================  =======  =======  ===========  ========  ========  =============================

  .. [#] If Quantity not provided, defaults to 1 for kitchen fans and NumberofBathrooms for bath fans based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.
  .. [#] If RatedFlowRate not provided, defaults to 100 cfm for kitchen fans and 50 cfm for bath fans based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.
  .. [#] If HoursInOperation not provided, defaults to 1 based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.
  .. [#] FanLocation choices are "kitchen" or "bath".
  .. [#] If FanPower not provided, defaults to 0.3 W/cfm * RatedFlowRate based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.
  .. [#] If StartHour not provided, defaults to 18 for kitchen fans and 7 for bath fans  based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.

Cooling Load Reduction
~~~~~~~~~~~~~~~~~~~~~~

Each whole house fans that provides cooling load reduction is entered as a ``/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan``.

  =======================================  =======  =======  ===========  ========  ========  ==========================
  Element                                  Type     Units    Constraints  Required  Default   Notes
  =======================================  =======  =======  ===========  ========  ========  ==========================
  ``UsedForSeasonalCoolingLoadReduction``  boolean           true         Yes                 Must be set to true
  ``RatedFlowRate``                        double   cfm      >= 0         Yes                 Flow rate
  ``FanPower``                             double   W        >= 0         Yes                 Fan power
  =======================================  =======  =======  ===========  ========  ========  ==========================

The whole house fan is assumed to operate during hours of favorable outdoor conditions and will take priority over operable windows (natural ventilation).

HPXML Water Heating Systems
***************************

FIXME FIXME FIXME

Each water heater is entered as a ``Systems/WaterHeating/WaterHeatingSystem``.
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

The water heater ``Location`` can be optionally entered as one of: "living space", "basement - conditioned", "basement - unconditioned", "attic - unvented", "attic - vented", "garage", "crawlspace - unvented", "crawlspace - vented", "other exterior", "other housing unit", "other heated space", "other multifamily buffer space", "other non-freezing space".
See :ref:`hpxmllocations` for descriptions.

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

If any water heating systems are provided, a single hot water distribution system is entered as a ``/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution``.

  =================================  =======  ============  ===========  ========  ========  =======================================================================
  Element                            Type     Units         Constraints  Required  Default   Notes
  =================================  =======  ============  ===========  ========  ========  =======================================================================
  ``SystemType``                     element                See [#]_     Yes                 Type of in-unit distribution system serving the dwelling unit
  ``PipeInsulation/PipeRValue``      double   F-ft2-hr/Btu  >= 0         Yes                 Pipe insulation R-value
  ``DrainWaterHeatRecovery``         element                             No        <none>    Presence of drain water heat recovery device
  ``extension/SharedRecirculation``  element                See [#]_     No        <none>    Presence of shared recirculation system serving multiple dwelling units
  =================================  =======  ============  ===========  ========  ========  =======================================================================

  .. [#] SystemType child element choices are ``Standard`` and ``Recirculation``.
  .. [#] If SharedRecirculation is provided, SystemType must be ``Standard``.
         This is because a stacked recirculation system (i.e., shared recirculation loop plus an additional in-unit recirculation system) is more likely to indicate input errors than reflect an actual real-world scenario.

  .. note::

    In attached/multifamily buildings, only the hot water distribution system serving the dwelling unit should be fined.
    The hot water distribution associated with, e.g., a shared laundry room should not be defined.

Standard
~~~~~~~~

If the in-unit distribution system is specified as standard, additional information is entered in ``SystemType/Standard``.

  ================  =======  =====  ===========  ========  ========  =====================
  Element           Type     Units  Constraints  Required  Default   Notes
  ================  =======  =====  ===========  ========  ========  =====================
  ``PipingLength``  double   ft     > 0          No        See [#]_  Length of piping [#]_
  ================  =======  =====  ===========  ========  ========  =====================

  .. [#] | If PipingLength not provided, calculated using the following equation from `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_:
         | :math:`PipeL = 2.0 \cdot (\frac{CFA}{NCfl})^{0.5} + 10.0 \cdot NCfl + 5.0 \cdot Bsmnt`
         | where,
         |   CFA = conditioned floor area [ft2],
         |   NCfl = number of conditioned floor levels number of conditioned floor levels in the residence including conditioned basements,
         |   Bsmnt = presence (1.0) or absence (0.0) of an unconditioned basement in the residence.
  .. [#] PipingLength is the length of hot water piping from the hot water heater (or from a shared recirculation loop serving multiple dwelling units) to the farthest hot water fixture, measured longitudinally from plans, assuming the hot water piping does not run diagonally, plus 10 feet of piping for each floor level, plus 5 feet of piping for unconditioned basements (if any).

Recirculation
~~~~~~~~~~~~~

If the in-unit distribution system is specified as recirculation, additional information is entered in ``SystemType/Recirculation``.

  =================================  =======  =====  ===========  ========  ========  =====================================
  Element                            Type     Units  Constraints  Required  Default   Notes
  =================================  =======  =====  ===========  ========  ========  =====================================
  ``ControlType``                    string          See [#]_     Yes                 Recirculation control type
  ``RecirculationPipingLoopLength``  double   ft     > 0          No        See [#]_  Recirculation piping loop length [#]_
  ``BranchPipingLoopLength``         double   ft     > 0          No        10        Branch piping loop length [#]_
  ``PumpPower``                      double   W      >= 0         No        50 [#]_   Recirculation pump power
  =================================  =======  =====  ===========  ========  ========  =====================================

  .. [#] ControlType choices are "manual demand control", "presence sensor demand control", "temperature", "timer", or "no control".
  .. [#] | If RecirculationPipingLoopLength not provided, calculated using the following equation from `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_:
         | :math:`RecircPipeL = 2.0 \cdot (2.0 \cdot (\frac{CFA}{NCfl})^{0.5} + 10.0 \cdot NCfl + 5.0 \cdot Bsmnt) - 20.0`
         | where,
         |   CFA = conditioned floor area [ft2],
         |   NCfl = number of conditioned floor levels number of conditioned floor levels in the residence including conditioned basements,
         |   Bsmnt = presence (1.0) or absence (0.0) of an unconditioned basement in the residence.
  .. [#] RecirculationPipingLoopLength is the recirculation loop length including both supply and return sides, measured longitudinally from plans, assuming the hot water piping does not run diagonally, plus 20 feet of piping for each floor level greater than one plus 10 feet of piping for unconditioned basements.
  .. [#] BranchPipingLoopLength is the length of the branch hot water piping from the recirculation loop to the farthest hot water fixture from the recirculation loop, measured longitudinally from plans, assuming the branch hot water piping does not run diagonally.
  .. [#] PumpPower default based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.

Shared Recirculation
~~~~~~~~~~~~~~~~~~~~

If a shared recirculation system is specified, additional information is entered in ``extension/SharedRecirculation``.

  =======================  =======  =====  ===========  ========  ========  =================================
  Element                  Type     Units  Constraints  Required  Default   Notes
  =======================  =======  =====  ===========  ========  ========  =================================
  ``NumberofUnitsServed``  integer         > 1          Yes                 Number of dwelling units served
  ``PumpPower``            double   W      >= 0         No        220 [#]_  Shared recirculation pump power
  ``ControlType``          string          See [#]_     Yes                 Shared recirculation control type
  =======================  =======  =====  ===========  ========  ========  =================================

  .. [#] PumpPower default based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_.
  .. [#] ControlType choices are "manual demand control", "presence sensor demand control", "timer", or "no control".

Drain Water Heat Recovery
~~~~~~~~~~~~~~~~~~~~~~~~~

If a drain water heat recovery (DWHR) device is specified, additional information is entered in ``DrainWaterHeatRecovery``.

  =======================  =======  =====  ===========  ========  ========  =========================================
  Element                  Type     Units  Constraints  Required  Default   Notes
  =======================  =======  =====  ===========  ========  ========  =========================================
  ``FacilitiesConnected``  string          See [#]_     Yes                 Specifies which facilities are connected
  ``EqualFlow``            boolean                      Yes                 Specifies how the DHWR is configured [#]_
  ``Efficiency``           double   frac   0-1          Yes                 Efficiency according to CSA 55.1
  =======================  =======  =====  ===========  ========  ========  =========================================

  .. [#] FacilitiesConnected choices are "one" or "all".
         Use "one" if there are multiple showers and only one of them is connected to the DWHR.
         Use "all" if there is one shower and it's connected to the DWHR or there are two or more showers connected to the DWHR.
  .. [#] EqualFlow should be true if the DWHR supplies pre-heated water to both the fixture cold water piping *and* the hot water heater potable supply piping.


HPXML Water Fixtures
********************

Each water fixture is entered as a ``/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterFixture``.

  ====================  =======  =====  ===========  ========  ========  ===============================================
  Element               Type     Units  Constraints  Required  Default   Notes
  ====================  =======  =====  ===========  ========  ========  ===============================================
  ``WaterFixtureType``  string          See [#]_     Yes                 Type of water fixture
  ``LowFlow``           boolean                      Yes                 Whether the fixture is considered low-flow [#]_
  ====================  =======  =====  ===========  ========  ========  ===============================================

  .. [#] WaterFixtureType choices are "shower head" or "faucet".
  .. [#] LowFlow should be true if the fixture's flow rate (gpm) is <= 2.0.

In addition, a ``/HPXML/Building/BuildingDetails/Systems/WaterHeating/extension/WaterFixturesUsageMultiplier`` can be optionally provided that scales hot water usage.
if not provided, it is assumed to be 1.0.

HPXML Solar Thermal
*******************

A single solar hot water system can be entered as a ``/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem``.

  ==============  =======  =====  ===========  ========  ========  ============================
  Element         Type     Units  Constraints  Required  Default   Notes
  ==============  =======  =====  ===========  ========  ========  ============================
  ``SystemType``  string          See [#]_     Yes                 Type of solar thermal system
  ==============  =======  =====  ===========  ========  ========  ============================

  .. [#] SystemType only choice is "hot water".

Solar hot water systems can be described with either simple or detailed inputs.

Simple Inputs
~~~~~~~~~~~~~

To define a simple solar hot water system, additional information is entered in ``SolarThermalSystem``.

  =================  =======  =====  ===========  ========  ========  ======================
  Element            Type     Units  Constraints  Required  Default   Notes
  =================  =======  =====  ===========  ========  ========  ======================
  ``SolarFraction``  double   frac   0-1          Yes                 Solar fraction [#]_
  ``ConnectedTo``    idref           See [#]_     No [#]_   <none>    Connected water heater
  =================  =======  =====  ===========  ========  ========  ======================
  
  .. [#] Portion of total conventional hot water heating load (delivered energy plus tank standby losses).
         Can be obtained from `Directory of SRCC OG-300 Solar Water Heating System Ratings <https://solar-rating.org/programs/og-300-program/>`_ or NREL's `System Advisor Model <https://sam.nrel.gov/>`_ or equivalent.
  .. [#] ConnectedTo must reference a ``WaterHeatingSystem``.
  .. [#] If ConnectedTo not provided, solar fraction will apply to all water heaters in the building.

Detailed Inputs
~~~~~~~~~~~~~~~

To define a detailed solar hot water system, additional information is entered in ``SolarThermalSystem``.

  ===================================  =======  ============  ===========  ========  ========  ==============================
  Element                              Type     Units         Constraints  Required  Default   Notes
  ===================================  =======  ============  ===========  ========  ========  ==============================
  ``CollectorArea``                    double   ft2           > 0          Yes                 Area
  ``CollectorLoopType``                string                 See [#]_     Yes                 Loop type
  ``CollectorType``                    string                 See [#]_     Yes                 System type
  ``CollectorAzimuth``                 integer  deg           0-359        Yes                 Azimuth (clockwise from North)
  ``CollectorTilt``                    double   deg           0-90         Yes                 Tilt relative to horizontal
  ``CollectorRatedOpticalEfficiency``  double   frac          0-1          Yes                 Rated optical efficiency [#]_
  ``CollectorRatedThermalLosses``      double   Btu/hr-ft2-R  > 0          Yes                 Rated thermal losses [#]_
  ``StorageVolume``                    double   gal           > 0          No        See [#]_  Hot water storage volume
  ``ConnectedTo``                      idref                  See [#]_     Yes                 Connected water heater
  ===================================  =======  ============  ===========  ========  ========  ==============================
  
  .. [#] CollectorLoopType choices are "liquid indirect", "liquid direct", or "passive thermosyphon".
  .. [#] CollectorType choices are "single glazing black", "double glazing black", "evacuated tube", or "integrated collector storage".
  .. [#] CollectorRatedOpticalEfficiency is FRTA (y-intercept) from the `Directory of SRCC OG-100 Certified Solar Collector Ratings <https://solar-rating.org/programs/og-100-program/>`_.
  .. [#] CollectorRatedThermalLosses is FRUL (slope) from the `Directory of SRCC OG-100 Certified Solar Collector Ratings <https://solar-rating.org/programs/og-100-program/>`_.
  .. [#] If StorageVolume not provided, calculated as 1.5 gal/ft2 * CollectorArea.
  .. [#] ConnectedTo must reference a ``WaterHeatingSystem`` that is not of type space-heating boiler nor connected to a desuperheater.

HPXML Photovoltaics
*******************

Each solar electric photovoltaic (PV) system is entered as a ``/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem``.

Many of the inputs are adopted from the `PVWatts model <https://pvwatts.nrel.gov>`_.

  =======================================================  =================  =========  =============  ============  ========  ============================================
  Element                                                  Type               Units      Constraints    Required      Default   Notes
  =======================================================  =================  =========  =============  ============  ========  ============================================
  ``IsSharedSystem``                                       boolean                                      No            false     Whether it serves multiple dwelling units
  ``Location``                                             string                        See [#]_       Yes                     Mounting location
  ``ModuleType``                                           string                        See [#]_       Yes                     Type of module
  ``Tracking``                                             string                        See [#]_       Yes                     Type of tracking
  ``ArrayAzimuth``                                         integer            deg        0-359          Yes                     Direction panels face (clockwise from North)
  ``ArrayTilt``                                            double             deg        0-90           Yes                     Tilt relative to horizontal
  ``MaxPowerOutput``                                       double             W          >= 0           Yes                     Peak power
  ``InverterEfficiency``                                   double             frac       0-1            No            0.96      Inverter efficiency
  ``SystemLossesFraction`` or ``YearModulesManufactured``  double or integer  frac or #  0-1 or > 1600  No            0.14      System losses [#]_
  =======================================================  =================  =========  =============  ============  ========  ============================================
  
  .. [#] Location choices are "ground" or "roof" mounted.
  .. [#] ModuleType choices are "standard", "premium", or "thin film".
  .. [#] Tracking choices are "fixed", "1-axis", "1-axis backtracked", or "2-axis".
  .. [#] System losses due to soiling, shading, snow, mismatch, wiring, degradation, etc.
         If YearModulesManufactured provided but not SystemLossesFraction, system losses calculated as:
         SystemLossesFraction = 1.0 - (1.0 - 0.14) * (1.0 - (1.0 - 0.995^(CurrentYear - YearModulesManufactured))).

If a shared system is specified, additional information is entered in ``PVSystem``.

  ====================================  =======  =====  ===========  ========  ========  =========================
  Element                               Type     Units  Constraints  Required  Default   Notes
  ====================================  =======  =====  ===========  ========  ========  =========================
  ``extension/NumberofBedroomsServed``  integer         > 1          Yes                 Number of bedrooms served
  ====================================  =======  =====  ===========  ========  ========  =========================

  PV generation will be apportioned to the dwelling unit using its number of bedrooms divided by the number of bedrooms served by the PV system.

HPXML Appliances
----------------

Appliances entered in ``/HPXML/Building/BuildingDetails/Appliances``.

HPXML Clothes Washer
********************

A single clothes washer can be entered as a ``/HPXML/Building/BuildingDetails/Appliances/ClothesWasher``.

  ==============================================================  =======  =============  ===========  ========  ============  ==============================================
  Element                                                         Type     Units          Constraints  Required  Default       Notes
  ==============================================================  =======  =============  ===========  ========  ============  ==============================================
  ``IsSharedAppliance``                                           boolean                              No        false         Whether it serves multiple dwelling units [#]_
  ``Location``                                                    string                  See [#]_     No        living space  Location
  ``IntegratedModifiedEnergyFactor`` or ``ModifiedEnergyFactor``  double   ft3/kWh/cycle  > 0          No        See [#]_      EnergyGuide label efficiency [#]_
  ``extension/UsageMultiplier``                                   double                  >= 0         No        1.0           Multiplier on energy & hot water usage
  ==============================================================  =======  =============  ===========  ========  ============  ==============================================

  .. [#] For example, a clothes washer in a shared laundry room of a MF building.
  .. [#] Location choices are "living space", "basement - conditioned", "basement - unconditioned", "garage", "other housing unit", "other heated space", "other multifamily buffer space", or "other non-freezing space".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] | If IntegratedModifiedEnergyFactor nor ModifiedEnergyFactor provided, the following default values representing a standard clothes washer from 2006 will be used:
         
         ==============================  =======
         Element                         Default
         ==============================  =======
         IntegratedModifiedEnergyFactor  1.0  
         RatedAnnualkWh                  400  
         LabelElectricRate               0.12  
         LabelGasRate                    1.09  
         LabelAnnualGasCost              27.0  
         LabelUsage                      6  
         Capacity                        3.0  
         ==============================  =======
         
  .. [#] If ModifiedEnergyFactor (MEF) provided instead of IntegratedModifiedEnergyFactor (IMEF), it will be converted using the `Interpretation on ANSI/RESNET 301-2014 Clothes Washer IMEF <https://www.resnet.us/wp-content/uploads/No.-301-2014-08-sECTION-4.2.2.5.2.8-Clothes-Washers-Eq-4.2-6.pdf>`_:
         IMEF = (MEF - 0.503) / 0.95.

If IntegratedModifiedEnergyFactor or ModifiedEnergyFactor is provided, a complete set of EnergyGuide label information is entered in ``ClothesWasher``.

  ======================  =======  =======  ===========  ========  =======  ====================================
  Element                 Type     Units    Constraints  Required  Default  Notes
  ======================  =======  =======  ===========  ========  =======  ====================================
  ``RatedAnnualkWh``      double   kWh/yr   > 0          Yes                EnergyGuide label annual consumption
  ``LabelElectricRate``   double   $/kWh    > 0          Yes                EnergyGuide label electricity rate
  ``LabelGasRate``        double   $/therm  > 0          Yes                EnergyGuide label natural gas rate
  ``LabelAnnualGasCost``  double   $        > 0          Yes                EnergyGuide label annual gas cost
  ``LabelUsage``          double   cyc/wk   > 0          Yes                EnergyGuide label number of cycles
  ``Capacity``            double   ft3      > 0          Yes                Clothes dryer volume
  ======================  =======  =======  ===========  ========  =======  ====================================

If a shared clothes washer is specified, additional information is entered in ``ClothesWasher``.

  ================================  =======  =======  ===========  ========  =======  ===========================
  Element                           Type     Units    Constraints  Required  Default  Notes
  ================================  =======  =======  ===========  ========  =======  ===========================
  ``AttachedToWaterHeatingSystem``  idref             See [#]_     Yes                ID of attached water heater
  ================================  =======  =======  ===========  ========  =======  ===========================

  .. [#] AttachedToWaterHeatingSystem must reference a ``WaterHeatingSystem``.

HPXML Clothes Dryer
*******************

A single clothes dryer can be entered as a ``/HPXML/Building/BuildingDetails/Appliances/ClothesDryer``.

  ============================================  =======  ======  ===========  ========  ============  ==============================================
  Element                                       Type     Units   Constraints  Required  Default       Notes
  ============================================  =======  ======  ===========  ========  ============  ==============================================
  ``IsSharedAppliance``                         boolean                       No        false         Whether it serves multiple dwelling units [#]_
  ``Location``                                  string           See [#]_     No        living space  Location
  ``FuelType``                                  string           See [#]_     Yes                     Fuel type
  ``CombinedEnergyFactor`` or ``EnergyFactor``  double   lb/kWh  > 0          No        See [#]_      EnergyGuide label efficiency [#]_
  ``extension/UsageMultiplier``                 double           >= 0         No        1.0           Multiplier on energy use
  ``extension/IsVented``                        boolean                       No        true          Whether dryer is vented
  ============================================  =======  ======  ===========  ========  ============  ==============================================

  .. [#] For example, a clothes dryer in a shared laundry room of a MF building.
  .. [#] Location choices are "living space", "basement - conditioned", "basement - unconditioned", "garage", "other housing unit", "other heated space", "other multifamily buffer space", or "other non-freezing space".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] FuelType choices are "natural gas", "fuel oil", "fuel oil 1", "fuel oil 2", "fuel oil 4", "fuel oil 5/6", "diesel", "propane", "kerosene", "coal", "coke", "bituminous coal", "anthracite coal", "electricity", "wood", or "wood pellets".
  .. [#] | If CombinedEnergyFactor nor EnergyFactor provided, the following default values representing a standard clothes dryer from 2006 will be used:
         
         ==============================  =======
         Element                         Default
         ==============================  =======
         CombinedEnergyFactor            3.01
         ControlType                     timer
         ==============================  =======
         
  .. [#] If EnergyFactor (EF) provided instead of CombinedEnergyFactor (CEF), it will be converted using the following equation based on the `Interpretation on ANSI/RESNET/ICC 301-2014 Clothes Dryer CEF <https://www.resnet.us/wp-content/uploads/No.-301-2014-10-Section-4.2.2.5.2.8-Clothes-Dryer-CEF-Rating.pdf>`_:
         CEF = EF / 1.15.

If the CombinedEnergyFactor or EnergyFactor is provided, a complete set of EnergyGuide label information is entered in ``ClothesDryer``.

  ===============  =======  =======  ===========  ========  =======  ================
  Element          Type     Units    Constraints  Required  Default  Notes
  ===============  =======  =======  ===========  ========  =======  ================
  ``ControlType``  string            See [#]_     Yes                Type of controls
  ===============  =======  =======  ===========  ========  =======  ================

  .. [#] ControlType choices are "timer" or "moisture".

If a vented dryer is specified, additional information is entered in ``ClothesDryer``.

  ============================  =======  =======  ===========  ========  ========  =================================
  Element                       Type     Units    Constraints  Required  Default   Notes
  ============================  =======  =======  ===========  ========  ========  =================================
  ``extension/VentedFlowRate``  double   cfm      >= 0         No        100 [#]_  Exhust flow rate during operation
  ============================  =======  =======  ===========  ========  ========  =================================
  
  .. [#] VentedFlowRate default based on `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.

HPXML Dishwasher
****************

A single dishwasher can be entered as a ``/HPXML/Building/BuildingDetails/Appliances/Dishwasher``.

  ============================================  =======  ===========  ===========  ========  ============  ==============================================
  Element                                       Type     Units        Constraints  Required  Default       Notes
  ============================================  =======  ===========  ===========  ========  ============  ==============================================
  ``IsSharedAppliance``                         boolean                            No        false         Whether it serves multiple dwelling units [#]_
  ``Location``                                  string                See [#]_     No        living space  Location
  ``RatedAnnualkWh`` or ``EnergyFactor``        double   kWh/yr or #  > 0          No        See [#]_      EnergyGuide label consumption/efficiency [#]_
  ``extension/UsageMultiplier``                 double                >= 0         No        1.0           Multiplier on energy & hot water usage
  ============================================  =======  ===========  ===========  ========  ============  ==============================================

  .. [#] For example, a dishwasher in a shared mechanical room of a MF building.
  .. [#] Location choices are "living space", "basement - conditioned", "basement - unconditioned", "garage", "other housing unit", "other heated space", "other multifamily buffer space", or "other non-freezing space".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] | If RatedAnnualkWh nor EnergyFactor provided, the following default values representing a standard dishwasher from 2006 will be used:

         ====================  =======
         Element               Default
         ====================  =======
         RatedAnnualkWh        467  
         LabelElectricRate     0.12  
         LabelGasRate          1.09  
         LabelAnnualGasCost    33.12  
         LabelUsage            4  
         PlaceSettingCapacity  12  
         ====================  =======

  .. [#] If EnergyFactor (EF) provided instead of RatedAnnualkWh, it will be converted using the following equation based on `ANSI/RESNET/ICC 301-2014 <https://codes.iccsafe.org/content/document/843>`_:
         RatedAnnualkWh = 215.0 / EF.

If the RatedAnnualkWh or EnergyFactor is provided, a complete set of EnergyGuide label information is entered in ``Dishwasher``.

  ========================  =======  =======  ===========  ========  =======  ==================================
  Element                   Type     Units    Constraints  Required  Default  Notes
  ========================  =======  =======  ===========  ========  =======  ==================================
  ``LabelElectricRate``     double   $/kWh    > 0          Yes                EnergyGuide label electricity rate
  ``LabelGasRate``          double   $/therm  > 0          Yes                EnergyGuide label natural gas rate
  ``LabelAnnualGasCost``    double   $        > 0          Yes                EnergyGuide label annual gas cost
  ``LabelUsage``            double   cyc/wk   > 0          Yes                EnergyGuide label number of cycles
  ``PlaceSettingCapacity``  integer  #        > 0          Yes                Number of place settings
  ========================  =======  =======  ===========  ========  =======  ==================================

If a shared dishwasher is specified, additional information is entered in ``Dishwasher``.

  ================================  =======  =======  ===========  ========  =======  ===========================
  Element                           Type     Units    Constraints  Required  Default  Notes
  ================================  =======  =======  ===========  ========  =======  ===========================
  ``AttachedToWaterHeatingSystem``  idref             See [#]_     Yes                ID of attached water heater
  ================================  =======  =======  ===========  ========  =======  ===========================

  .. [#] AttachedToWaterHeatingSystem must reference a ``WaterHeatingSystem``.

HPXML Refrigerators
*******************

Each refrigerator can be entered as a ``/HPXML/Building/BuildingDetails/Appliances/Refrigerator``.

  =====================================================  =======  ======  ===========  ============  ========  ======================================
  Element                                                Type     Units   Constraints  Required      Default   Notes
  =====================================================  =======  ======  ===========  ============  ========  ======================================
  ``Location``                                           string           See [#]_     No            See [#]_  Location
  ``RatedAnnualkWh`` or ``extension/AdjustedAnnualkWh``  double   kWh/yr  > 0          No            See [#]_  Annual consumption
  ``PrimaryIndicator``                                   boolean                       Depends [#]_            Primary refrigerator?
  ``extension/UsageMultiplier``                          double           >= 0         No            1.0       Multiplier on energy use
  ``extension/WeekdayScheduleFractions``                 array                         No            See [#]_  24 comma-separated weekday multipliers
  ``extension/WeekendScheduleFractions``                 array                         No                      24 comma-separated weekend multipliers
  ``extension/MonthlyScheduleMultipliers``               array                         No            See [#]_  12 comma-separated monthly multipliers
  =====================================================  =======  ======  ===========  ============  ========  ======================================

  .. [#] Location choices are "living space", "basement - conditioned", "basement - unconditioned", "garage", "other housing unit", "other heated space", "other multifamily buffer space", or "other non-freezing space".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] | If Location not provided and is the *primary* refrigerator, defaults to "living space".
           If Location not provided and is a *secondary* refrigerator, defaults based on presence of spaces and the Default Priority listed below:
  
         ========================  ================
         Location                  Default Priority
         ========================  ================
         garage                    1
         basement - unconditioned  2
         basement - conditioned    3
         living space              4
         ========================  ================
    
  .. [#] If RatedAnnualkWh nor AdjustedAnnualkWh provided, it will be defaulted to represent a standard refrigerator from 2006 using the following equation based on `ANSI/RESNET/ICC 301-2019 <https://codes.iccsafe.org/content/RESNETICC3012019>`_:
         RatedAnnualkWh = 637.0 + 18.0 * NumberofBedrooms.
  .. [#] If multiple refrigerators are specified, there must be exactly one refrigerator described with PrimaryIndicator=true.
  .. [#] If WeekdayScheduleFractions or WeekendScheduleFractions not provided, default values from Figure 16 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041".
  .. [#] If MonthlyScheduleMultipliers not provided, default values from Figure 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837".

HPXML Freezers
**************

Each standalone freezer can be entered as a ``/HPXML/Building/BuildingDetails/Appliances/Freezer``.

  =====================================================  ======  ======  ===========  ========  ==========  ======================================
  Element                                                Type    Units   Constraints  Required  Default     Notes
  =====================================================  ======  ======  ===========  ========  ==========  ======================================
  ``Location``                                           string          See [#]_     No        See [#]_    Location
  ``RatedAnnualkWh`` or ``extension/AdjustedAnnualkWh``  double  kWh/yr  > 0          No        319.8 [#]_  Annual consumption
  ``extension/UsageMultiplier``                          double          >= 0         No        1.0         Multiplier on energy use
  ``extension/WeekdayScheduleFractions``                 array                        No        See [#]_    24 comma-separated weekday multipliers
  ``extension/WeekendScheduleFractions``                 array                        No                    24 comma-separated weekend multipliers
  ``extension/MonthlyScheduleMultipliers``               array                        No        See [#]_    12 comma-separated monthly multipliers
  =====================================================  ======  ======  ===========  ========  ==========  ======================================

  .. [#] Location choices are "living space", "basement - conditioned", "basement - unconditioned", "garage", "other housing unit", "other heated space", "other multifamily buffer space", or "other non-freezing space".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] | If Location not provided, defaults based on presence of spaces and the Default Priority listed below:
  
         ========================  ================
         Location                  Default Priority
         ========================  ================
         garage                    1
         basement - unconditioned  2
         basement - conditioned    3
         living space              4
         ========================  ================

  .. [#] RatedAnnualkWh default based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_.
  .. [#] If WeekdayScheduleFractions or WeekendScheduleFractions not provided, default values from Figure 16 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041".
  .. [#] If MonthlyScheduleMultipliers not provided, default values from Figure 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837".

HPXML Dehumidifier
******************

A single dehumidifier can be entered as a ``/HPXML/Building/BuildingDetails/Appliances/Dehumidifier``.

  ==============================================  ==========  ==========  ===========  ========  =======  ========================================
  Element                                         Type        Units       Constraints  Required  Default  Notes
  ==============================================  ==========  ==========  ===========  ========  =======  ========================================
  ``Capacity``                                    double      pints/day   > 0          Yes                Dehumidification capacity
  ``IntegratedEnergyFactor`` or ``EnergyFactor``  double      liters/kWh  > 0          Yes                Rated efficiency
  ``DehumidistatSetpoint``                        double      frac        0-1          Yes                Relative humidity setpoint
  ``FractionDehumidificationLoadServed``          double      frac        0-1          Yes                Fraction of dehumidification load served
  ==============================================  ==========  ==========  ===========  ========  =======  ========================================

HPXML Cooking Range/Oven
************************

A single cooking range can be entered as a ``/HPXML/Building/BuildingDetails/Appliances/CookingRange``.

  ========================================  =======  ======  ===========  ========  ============  ======================================
  Element                                   Type     Units   Constraints  Required  Default       Notes
  ========================================  =======  ======  ===========  ========  ============  ======================================
  ``Location``                              string           See [#]_     No        living space  Location
  ``FuelType``                              string           See [#]_     Yes                     Fuel type
  ``IsInduction``                           boolean                       No        false         Induction range?
  ``extension/UsageMultiplier``             double           >= 0         No        1.0           Multiplier on energy use
  ``extension/WeekdayScheduleFractions``    array                         No        See [#]_      24 comma-separated weekday multipliers
  ``extension/WeekendScheduleFractions``    array                         No                      24 comma-separated weekend multipliers
  ``extension/MonthlyScheduleMultipliers``  array                         No        See [#]_      12 comma-separated monthly multipliers
  ========================================  =======  ======  ===========  ========  ============  ======================================

  .. [#] Location choices are "living space", "basement - conditioned", "basement - unconditioned", "garage", "other housing unit", "other heated space", "other multifamily buffer space", or "other non-freezing space".
         See :ref:`hpxmllocations` for descriptions.
  .. [#] FuelType choices are "natural gas", "fuel oil", "fuel oil 1", "fuel oil 2", "fuel oil 4", "fuel oil 5/6", "diesel", "propane", "kerosene", "coal", "coke", "bituminous coal", "anthracite coal", "electricity", "wood", or "wood pellets".
  .. [#] If WeekdayScheduleFractions or WeekendScheduleFractions not provided, default values from Figure 22 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "0.007, 0.007, 0.004, 0.004, 0.007, 0.011, 0.025, 0.042, 0.046, 0.048, 0.042, 0.050, 0.057, 0.046, 0.057, 0.044, 0.092, 0.150, 0.117, 0.060, 0.035, 0.025, 0.016, 0.011".
  .. [#] If MonthlyScheduleMultipliers not provided, default values from Figure 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "1.097, 1.097, 0.991, 0.987, 0.991, 0.890, 0.896, 0.896, 0.890, 1.085, 1.085, 1.097".

If a cooking range is specified, a single oven is also entered as a ``/HPXML/Building/BuildingDetails/Appliances/Oven``.

  ================  =======  ======  ===========  ========  =======  ================
  Element           Type     Units   Constraints  Required  Default  Notes
  ================  =======  ======  ===========  ========  =======  ================
  ``IsConvection``  boolean                       No        false    Convection oven?
  ================  =======  ======  ===========  ========  =======  ================

HPXML Lighting
--------------

Lighting is entered in ``/HPXML/Building/BuildingDetails/Lighting``.

HPXML Lighting Groups
*********************

FIXME FIXME FIXME

The building's lighting is described by nine ``LightingGroup`` elements, each of which is the combination of:

- ``LightingType``: 'LightEmittingDiode', 'CompactFluorescent', and 'FluorescentTube'
- ``Location``: 'interior', 'garage', and 'exterior'

The fraction of lamps of the given type in the given location are provided as the ``LightingGroup/FractionofUnitsInLocation``.
The fractions for a given location cannot sum to greater than 1.
If the fractions sum to less than 1, the remainder is assumed to be incandescent lighting.
Garage lighting values are ignored if the building has no garage.

Optional ``extension/InteriorUsageMultiplier``, ``extension/ExteriorUsageMultiplier``, and ``extension/GarageUsageMultiplier`` can be provided that scales energy use; if not provided, they are assumed to be 1.0.

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

FIXME FIXME FIXME

Each ceiling fan (or set of identical ceiling fans) is entered as a ``CeilingFan``.
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

A single pool can be entered as a ``/HPXML/Building/BuildingDetails/Pools/Pool``.

If a pool is specified, a single pool pump must be entered as a ``Pool/PoolPumps/PoolPump``.

  ========================================  =======  ======  ===========  ========  ============  ======================================
  Element                                   Type     Units   Constraints  Required  Default       Notes
  ========================================  =======  ======  ===========  ========  ============  ======================================
  ``Load[Units="kWh/year"]/Value``          double   kWh/yr  >= 0         No        See [#]_      Pool pump energy use
  ``extension/UsageMultiplier``             double           >= 0         No        1.0           Multiplier on pool pump energy use
  ``extension/WeekdayScheduleFractions``    array                         No        See [#]_      24 comma-separated weekday multipliers
  ``extension/WeekendScheduleFractions``    array                         No                      24 comma-separated weekend multipliers
  ``extension/MonthlyScheduleMultipliers``  array                         No        See [#]_      12 comma-separated monthly multipliers
  ========================================  =======  ======  ===========  ========  ============  ======================================

  .. [#] If Value not provided, defaults based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_: 158.5 / 0.070 * (0.5 + 0.25 * NumberofBedrooms / 3 + 0.35 * ConditionedFloorArea / 1920).
  .. [#] If WeekdayScheduleFractions or WeekendScheduleFractions not provided, default values from Figure 23 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003".
  .. [#] If MonthlyScheduleMultipliers not provided, default values from Figure 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154".

In addition, a pool heater can be entered as a ``Pool/Heater``.

  ======================================================  =======  ==================  ===========  ========  ========  ======================================
  Element                                                 Type     Units               Constraints  Required  Default   Notes
  ======================================================  =======  ==================  ===========  ========  ========  ======================================
  ``Type``                                                string                       See [#]_     Yes                 Pool heater type
  ``Load[Units="kWh/year" or Units="therm/year"]/Value``  double   kWh/yr or therm/yr  >= 0         No        See [#]_  Pool heater energy use
  ``extension/UsageMultiplier``                           double                       >= 0         No        1.0       Multiplier on pool heater energy use
  ``extension/WeekdayScheduleFractions``                  array                                     No        See [#]_  24 comma-separated weekday multipliers
  ``extension/WeekendScheduleFractions``                  array                                     No                  24 comma-separated weekend multipliers
  ``extension/MonthlyScheduleMultipliers``                array                                     No        See [#]_  12 comma-separated monthly multipliers
  ======================================================  =======  ==================  ===========  ========  ========  ======================================

  .. [#] Type choices are "gas fired", "electric resistance", or "heat pump".
  .. [#] | If Value not provided, defaults based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_:
         | gas fired [therm/year] = 3.0 / 0.014 * (0.5 + 0.25 * NumberofBedrooms / 3 + 0.35 * ConditionedFloorArea / 1920)
         | electric resistance [kWh/year] = 8.3 / 0.004 * (0.5 + 0.25 * NumberofBedrooms / 3 + 0.35 * ConditionedFloorArea / 1920)
         | heat pump [kWh/year] = (electric resistance [kWh/year]) / 5.0
  .. [#] If WeekdayScheduleFractions or WeekendScheduleFractions not provided, default values from Figure 23 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003".
  .. [#] If MonthlyScheduleMultipliers not provided, default values from Figure 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154".

HPXML Hot Tub
-------------

A single hot tub can be entered as a ``/HPXML/Building/BuildingDetails/HotTubs/HotTub``.

If a hot tub is specified, a single hot tub pump must be entered as a ``HotTub/HotTubPumps/HotTubPump``.

  ========================================  =======  ======  ===========  ========  ============  ======================================
  Element                                   Type     Units   Constraints  Required  Default       Notes
  ========================================  =======  ======  ===========  ========  ============  ======================================
  ``Load[Units="kWh/year"]/Value``          double   kWh/yr  >= 0         No        See [#]_      Hot tub pump energy use
  ``extension/UsageMultiplier``             double           >= 0         No        1.0           Multiplier on hot tub pump energy use
  ``extension/WeekdayScheduleFractions``    array                         No        See [#]_      24 comma-separated weekday multipliers
  ``extension/WeekendScheduleFractions``    array                         No                      24 comma-separated weekend multipliers
  ``extension/MonthlyScheduleMultipliers``  array                         No        See [#]_      12 comma-separated monthly multipliers
  ========================================  =======  ======  ===========  ========  ============  ======================================

  .. [#] If Value not provided, defaults based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_: 59.5 / 0.059 * (0.5 + 0.25 * NumberofBedrooms / 3 + 0.35 * ConditionedFloorArea / 1920).
  .. [#] If WeekdayScheduleFractions or WeekendScheduleFractions not provided, default values from Figure 23 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024".
  .. [#] If MonthlyScheduleMultipliers not provided, default values from Figure 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "0.921, 0.928, 0.921, 0.915, 0.921, 1.160, 1.158, 1.158, 1.160, 0.921, 0.915, 0.921".

In addition, a pool heater can be entered as a ``Pool/Heater``.

  ======================================================  =======  ==================  ===========  ========  ========  ======================================
  Element                                                 Type     Units               Constraints  Required  Default   Notes
  ======================================================  =======  ==================  ===========  ========  ========  ======================================
  ``Type``                                                string                       See [#]_     Yes                 Pool heater type
  ``Load[Units="kWh/year" or Units="therm/year"]/Value``  double   kWh/yr or therm/yr  >= 0         No        See [#]_  Pool heater energy use
  ``extension/UsageMultiplier``                           double                       >= 0         No        1.0       Multiplier on pool heater energy use
  ``extension/WeekdayScheduleFractions``                  array                                     No        See [#]_  24 comma-separated weekday multipliers
  ``extension/WeekendScheduleFractions``                  array                                     No                  24 comma-separated weekend multipliers
  ``extension/MonthlyScheduleMultipliers``                array                                     No        See [#]_  12 comma-separated monthly multipliers
  ======================================================  =======  ==================  ===========  ========  ========  ======================================

  .. [#] Type choices are "gas fired", "electric resistance", or "heat pump".
  .. [#] | If Value not provided, defaults based on the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_:
         | gas fired [therm/year] = 0.87 / 0.011 * (0.5 + 0.25 * NumberofBedrooms / 3 + 0.35 * ConditionedFloorArea / 1920)
         | electric resistance [kWh/year] = 49.0 / 0.048 * (0.5 + 0.25 * NumberofBedrooms / 3 + 0.35 * ConditionedFloorArea / 1920)
         | heat pump [kWh/year] = (electric resistance [kWh/year]) / 5.0
  .. [#] If WeekdayScheduleFractions or WeekendScheduleFractions not provided, default values from Figure 23 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024".
  .. [#] If MonthlyScheduleMultipliers not provided, default values from Figure 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used: "0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837".

HPXML Misc Loads
----------------

Miscellaneous loads are entered in ``/HPXML/Building/BuildingDetails/MiscLoads``.

HPXML Plug Loads
****************

FIXME FIXME FIXME

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

An ``extension/UsageMultiplier`` can also be optionally provided that scales energy use; if not provided, it is assumed to be 1.0.
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

An ``extension/UsageMultiplier`` can also be optionally provided that scales energy use; if not provided, it is assumed to be 1.0.
Optional ``extension/WeekdayScheduleFractions``, ``extension/WeekendScheduleFractions``, and ``extension/MonthlyScheduleMultipliers`` can be provided; if not provided, values from Figures 23 & 24 of the `Building America House Simulation Protocols <https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/house_simulation.pdf>`_ are used.

.. _hpxmllocations:

HPXML Locations
---------------

The various locations used in an HPXML file are defined as follows:

  ==============================  ===========================================  =======================================  =============
  Value                           Description                                  Temperature                              Building Type
  ==============================  ===========================================  =======================================  =============
  outside                         Ambient environment                          Weather data                             Any
  ground                                                                       EnergyPlus calculation                   Any
  living space                    Above-grade conditioned floor area           EnergyPlus calculation                   Any
  attic - vented                                                               EnergyPlus calculation                   Any
  attic - unvented                                                             EnergyPlus calculation                   Any
  basement - conditioned          Below-grade conditioned floor area           EnergyPlus calculation                   Any
  basement - unconditioned                                                     EnergyPlus calculation                   Any
  crawlspace - vented                                                          EnergyPlus calculation                   Any
  crawlspace - unvented                                                        EnergyPlus calculation                   Any
  garage                          Single-family garage (not shared parking)    EnergyPlus calculation                   Any
  other housing unit              E.g., conditioned adjacent unit or corridor  Same as living space                     SFA/MF only
  other heated space              E.g., shared laundry/equipment space         Avg of living space/outside; min of 68F  SFA/MF only
  other multifamily buffer space  E.g., enclosed unconditioned stairwell       Avg of living space/outside; min of 50F  SFA/MF only
  other non-freezing space        E.g., shared parking garage ceiling          Floats with outside; minimum of 40F      SFA/MF only
  other exterior                  Water heater outside                         Weather data                             Any
  exterior wall                   Ducts in exterior wall                       Avg of living space/outside              Any
  under slab                      Ducts under slab (ground)                    EnergyPlus calculation                   Any
  roof deck                       Ducts on roof deck (outside)                 Weather data                             Any
  ==============================  ===========================================  =======================================  =============

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
