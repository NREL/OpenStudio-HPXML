Roof and Attic
##############

.. contents:: Table of Contents

HPXML allows the specification of multiple ``Attic`` elements, each of which
relates to one (HPXML v2) or more (HPXML v3) ``Roof`` elements. That relation is
optional in HPXML, but is required for HEScore because it is important to know
which roof relates to each attic space. 

.. _rooftype:

Attic/Roof Type
***************

Each ``Attic`` is considered and the ``AtticType`` is mapped into a HEScore roof
type according to the following mapping.

.. table:: HPXML Attic Type to HEScore Roof type mapping (HPXML v2)

   =====================  ================
   HPXML                  HEScore
   =====================  ================
   cape cod               cath_ceiling
   cathedral ceiling      cath_ceiling
   flat roof              cath_ceiling
   unvented attic         vented_attic
   vented attic           vented_attic
   venting unknown attic  vented_attic
   other                  *see note below*
   =====================  ================

.. table:: HPXML Attic Type to HEScore Roof type mapping (HPXML v3)

   ==========================  ================
   HPXML                       HEScore
   ==========================  ================
   CathedralCeiling            cath_ceiling
   FlatRoof                    cath_ceiling
   Attic/CapeCod = 'true'      cath_ceiling
   Attic/Conditioned = 'true'  cond_attic
   Attic                       vented_attic
   Other                       *not translated*
   ==========================  ================

.. note::
   
   Prior to HPXML v3, there's no existing HPXML element capturing a conditioned attic.
   The only way to model a HEScore ``cond_attic`` is to specify HPXML Attic Type
   to be ``other`` with an extra element ``Attic/extension/Conditioned`` to be
   ``true``.

   Otherwise, HPXML Attic Type ``other`` will not be translated and will
   result in a translation error.

   
HEScore can accept up to two attic/roof constructions. If there are more than
two specified in HPXML, the properties of the ``Attic`` elements with
the same roof type are combined. For variables with a discrete selection the
value that covers the greatest combined area is used. For R-values a
calculation is performed to determine the equivalent overall R-value for the
attic. This is discussed in more detail in :ref:`roof-rvalues`.

.. note::

   Starting from HPXML v3, HPXML allows multiple floors/roofs attached to a
   single attic. The properties of the floors/roofs attached to the same attic
   are combined into a single one.

.. _`attic area`:

Attic and Roof Area
*******************

Home Energy Score needs to know the area of the thermal boundary between the
living space and unconditioned spaces. The areas needed depend on which
:ref:`rooftype` is selected.

It's best practice to provide areas for all roof and attic floor surfaces
regardless of Attic/Roof type. 


Vented Attic
------------

The thermal boundary for a vented attic is at the floor of the attic. In **HPXML
v2** that area is attached to the
``Building/BuildingDetails/Enclosure/AtticAndRoof/Attics/Attic`` element:

.. literalinclude:: ../../../examples/hescore_min.xml
   :lines: 65-82
   :emphasize-lines: 17

In **HPXML v3** that area is retrieved from a referenced ``FrameFloor`` element
from the ``Building/BuildingDetails/Enclosure/Attics/Attic`` element:

.. literalinclude:: ../../../examples/hescore_min_v3.xml
   :lines: 56-65
   :emphasize-lines: 9

.. literalinclude:: ../../../examples/hescore_min_v3.xml
   :lines: 108-117
   :emphasize-lines: 2-3

If there are more than one ``Roof`` elements attached to an attic (HPXML v3
since HPXML v2 only allows one roof to be referenced per ``Attic``), you will
need to provide an area for each one so that the most common roof color and
exterior finishes may be selected.


Cathedral Ceiling
-----------------

The thermal boundary for a cathedral ceiling is the roof deck, so the area of
the roofs attached to the attic are used.

In **HPXML v2** a single ``Roof`` can be referenced by the ``Attic`` and the
area of that roof is used.

.. literalinclude:: ../../../examples/house3.xml
   :lines: 51-73
   :emphasize-lines: 7

In **HPXML v3** multiple ``Roof`` elements can be referenced by the ``Attic``
and the sum of those ares is used. The properties of the roofs will be area
weighted as described below.

.. literalinclude:: ../../../examples/house3_v3.xml
   :lines: 39, 51-59, 69-82, 173
   :emphasize-lines: 14

Roof Color
**********

Roof color in HEScore is mapped from the HPXML ``Roof/RoofColor`` element
according to the following mapping.

.. table:: HPXML to HEScore roof color mapping

   ===========  ===========
   HPXML        HEScore
   ===========  ===========
   light        light
   medium       medium
   medium dark  medium_dark
   dark         dark
   reflective   white
   ===========  ===========

If the ``Roof/SolarAbsorptance`` element is present, the HEScore roof color is
set to "cool_color" and the recorded absorptance will be sent to HEScore under
the "roof_absorptance" element.

.. note::

   Starting from HPXML v3, if there're more than one roof attached to the same
   attic, the roof color of that covers greatest area will be selected.

Exterior Finish
***************

HPXML stores the exterior finish information in the ``Roof/RoofType`` element.
This is translated into the HEScore exterior finish variable according to the
following mapping.

.. table:: HPXML Roof Type to HEScore Exterior Finish mapping

   =================================  ====================
   HPXML                              HEScore
   =================================  ====================
   shingles                           composition shingles
   slate or tile shingles             concrete tile
   wood shingles or shakes            wood shakes
   asphalt or fiberglass shingles     composition shingles
   metal surfacing                    composition shingles
   expanded polystyrene sheathing     *not translated*
   plastic/rubber/synthetic sheeting  tar and gravel
   concrete                           concrete tile
   cool roof                          *not translated*
   green roof                         *not translated*
   no one major type                  *not translated*
   other                              *not translated*
   =================================  ====================
   
.. note::

   Items where the HEScore translation indicates *not translated* above 
   will result in a translation error.

.. _rigid-sheathing:

Rigid Foam Sheathing
********************

If the ``AtticRoofInsulation`` element has a ``Layer`` with the "continuous"
``InstallationType``, ``InsulationMaterial/Rigid``, and a ``NominalRValue``
greater than zero, the roof is determined to have rigid foam sheathing and one
of the construction codes is selected accordingly. Otherwise one of the
standard wood frame construction codes is selected.

HPXML v2
--------

.. code-block:: xml
   :emphasize-lines: 8-12

   <Attic>
       <SystemIdentifier id="attic5"/>
       <AttachedToRoof idref="roof3"/>
       <AtticType>cathedral ceiling</AtticType>
       <AtticRoofInsulation>
           <SystemIdentifier id="attic5roofins"/>
           <Layer>
               <InstallationType>continuous</InstallationType>
               <InsulationMaterial>
                   <Rigid>eps</Rigid>
               </InsulationMaterial>
               <NominalRValue>10</NominalRValue>
           </Layer>
       </AtticRoofInsulation>
       <Area>2500</Area>
   </Attic>

HPXML v3
--------

.. code-block:: xml
   :emphasize-lines: 17-21

   <Atics>
      <Attic>
         <SystemIdentifier id="attic5"/>
         <AtticType>
            <CathedralCeiling/>
         </AtticType>
         <AttachedToRoof idref="roof3"/>
      </Attic>
   </Attics>
   <Roofs>
      <Roof>
         <SystemIdentifier id="roof3"/>
         <Area>2500</Area>
         <Insulation>
              <SystemIdentifier id="attic5roofins"/>
              <Layer>
                  <InstallationType>continuous</InstallationType>
                  <InsulationMaterial>
                      <Rigid>eps</Rigid>
                  </InsulationMaterial>
                  <NominalRValue>10</NominalRValue>
              </Layer>
          </Insulation>
      </Roof>
   <Roofs>

Radiant Barrier
***************

If the ``Roof/RadiantBarrier`` element exists and has a "true" value and roof deck insulation R-value is 0,
the attic is assumed to have a radiant barrier according to the construction codes available in HEScore.
If the ``Roof/RadiantBarrier`` element exists and has a "true" value but roof deck insulation R-value greater than 0,
the roof will be modeled as a roof with no radiant barrier.

.. _roof-rvalues:

Roof R-value
************

The roof R-value can be described by using ``NominalRValue`` or ``AssemblyRValue``.
If a user wishes to use a nominal R-value, ``NominalRValue`` elements for all layers need to be provided.
Otherwise, ``AssemblyRValue`` elements for each layer need to be provided.

If nominal R-value is used, the R-value is summed for all insulation layers. If
the roof construction was determined to have :ref:`rigid-sheathing`, an R-value
of 5 is subtracted from the roof R-value sum to account for the R-value of the
sheathing in the HEScore construction. The nearest discrete R-value from the
list of possible R-values for that roof type is used to determine an assembly
code. Then, the assembly R-value of the corresponding assembly code from the
lookup table is used. The lookup table can be found at
`hescorehpxml\\lookups\\lu_roof_eff_rvalue.csv
<https://github.com/NREL/hescore-hpxml/blob/master/hescorehpxml/lookups/lu_roof_eff_rvalue.csv>`_.

If assembly R-value is used, the discrete R-value nearest to assembly R-value
from the lookup table is used. The lookup table can be found at `hescorehpxml\\lookups\\lu_roof_eff_rvalue.csv
<https://github.com/NREL/hescore-hpxml/blob/master/hescorehpxml/lookups/lu_roof_eff_rvalue.csv>`_.

If the attic has more than one ``Roof`` element and/or if multiple attics of the
same type and their associated roofs are to be combined, a weighted average
assembly R-value is determined by weighting the U-values by area. Then the
discrete R-value nearest to the weighted average assembly R-value from the
lookup table is used.

.. math::
   :nowrap:

   \begin{align*}
   U_i &= \frac{1}{R_i} \\
   U_{eff,avg} &= \frac{\sum_i{U_i A_i}}{\sum_i A_i} \\
   R_{eff,avg} &= \frac{1}{U_{eff,avg}} \\
   \end{align*}

Then the nearest discrete R-value to the weighted average R-value from the lookup table is used.
The lookup table can be found at `hescorehpxml\\lookups\\lu_roof_eff_rvalue.csv
<https://github.com/NREL/hescore-hpxml/blob/master/hescorehpxml/lookups/lu_roof_eff_rvalue.csv>`_.

Attic R-value
*************

Determining the attic floor insulation levels uses the same procedure as
:ref:`roof-rvalues` except the lookup table is different. 

If nominal R-value is used, the attic floor center-of-cavity R-values are each R-0.5 greater
than the nominal R-values in the enumeration list.

If assembly R-value is used, the lookup table at `hescorehpxml\\lookups\\lu_ceiling_eff_rvalue.csv
<https://github.com/NREL/hescore-hpxml/blob/master/hescorehpxml/lookups/lu_ceiling_eff_rvalue.csv>`_
is used. 

If the primary roof type is determined to be a cathedral ceiling, then an attic
R-value is not calculated.

.. _knee-walls:

Knee Walls
**********

The Home Energy Score Q1 2022 release includes the ability to directly model
knee walls. As such, the workaround of adding knee wall area to attic floor area
is no longer used. Knee walls are now directly translated and passed to Home
Energy Score as follows:

In **HPXML v2**, knee walls are specified via the ``Attic/AtticKneeWall`` element.

In **HPXML v3**, knee walls are specified via wall attachment in
``Attic/AttachedToWall``. The attached wall must have ``AtticWallType`` of "knee
wall". See below an example:

.. code-block:: xml
   :emphasize-lines: 10, 16, 18, 22, 26-27

   <Attics>
      <Attic>
         <SystemIdentifier id="attic5"/>
         <AtticType>
            <Attic>
               <Vented>true</Vented>
            </Attic>
         </AtticType>
         <AttachedToRoof idref="roof3"/>
         <AttachedToWall idref="kneewall"/>
         <AttachedToFrameFloor idref="framefloor"/>
      </Attic>
   </Attics>
   <Walls>
      <Wall>
         <SystemIdentifier id="kneewall"/>
         <ExteriorAdjacentTo>attic</ExteriorAdjacentTo>
         <AtticWallType>knee wall</AtticWallType>
         <WallType>
            <WoodStud/>
         </WallType>
         <Area>200</Area>
         <Insulation>
              <SystemIdentifier id="kneewallins"/>
              <Layer>
                  <InstallationType>cavity</InstallationType>
                  <NominalRValue>11</NominalRValue>
              </Layer>
          </Insulation>
      </Wall>
   <Walls>

The knee walls R-value can be described by nominal R-value or assembly R-value.

If nominal R-value is used, the nearest assembly code by R-value *in the code* is
selected and the assembly R-value is looked up for that code.

If assembly R-value is used, the nearest assembly code *by assembly R-value* is
looked up from that table. 

.. csv-table:: Knee Wall Assembly Codes and R-values
   :header-rows: 1
   :file: ../../../hescorehpxml/lookups/lu_knee_wall_eff_rvalue.csv

If an attic has more than one knee wall and/or if multiple attics of the same
type need to be combined, the area weighted average assembly effective R-value
is calculated from all the associated knee walls. The areas of all the knee
walls are summed. The assembly code with the nearest assembly effective R-value
is chosed to represent the knee walls.

