Roof and Attic
##############

.. contents:: Table of Contents

HPXML allows the specification of multiple ``Attic`` elements, each of which
relates to one (HPXML v2) or more (HPXML v3) ``Roof`` elements. That relation is
optional in HPXML, but is required for HEScore when there is more than one
``Attic`` or ``Roof`` because it is important to know which roof relates to each
attic space. An area is required for each Attic if there is more than one
``Attic`` element.

.. _`attic area`:

  - In HPXML v2, areas can be specified directly by ``Attic/AtticArea``.
  - In HPXML v3, translator first searches all the ``Area`` of ``FrameFloor`` 
    whose id is the same as what referred in ``Attic/AttachedToFrameFloor``, and
    sums all areas up. Otherwise, the ``Area`` of ``Roof`` whose id is the same
    as what referred in ``Attic/AttachedToRoof`` will be searched and summed for
    each attic.

If there is only one ``Attic`` element, the footprint area of the building is
assumed. If there's only one roof in HPXML, it will be automatically attached to
attic.

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

If nominal R-value is used, the R-value is summed for all insulation layers. If the roof construction 
was determined to have :ref:`rigid-sheathing`, an R-value of 5 is subtracted from the roof R-value sum
to account for the R-value of the sheathing in the HEScore construction.
The nearest discrete R-value from the list of possible R-values for that roof type
is used to determine an assembly code. 
Then, the assembly R-value of the corresponding 
assembly code from the lookup table is used. The lookup table can be found 
at `hescorehpxml\\lookups\\lu_roof_eff_rvalue.csv
<https://github.com/NREL/hescore-hpxml/blob/assembly_eff_r_values/hescorehpxml/lookups/lu_roof_eff_rvalue.csv>`_.

If assembly R-value is used, the discrete R-value nearest to assembly R-value
from the lookup table is used. The lookup table can be found at `hescorehpxml\\lookups\\lu_roof_eff_rvalue.csv
<https://github.com/NREL/hescore-hpxml/blob/assembly_eff_r_values/hescorehpxml/lookups/lu_roof_eff_rvalue.csv>`_.
If the attic has more than one ``Roof`` element, a weighted average assembly R-value is determined
by weighting the U-values by area.
Then the discrete R-value nearest to the weighted average assembly R-value from the lookup table is used.

Starting from HPXML v3, multiple roofs are allowed to be attached to the same attic. 
If the attic has more than one ``Roof`` element with roof insulation,
a weighted average R-value is calculated using assembly R-value for each ``Roof``, 
whether nominal R-value or assembly R-value is used. 
The weighted average is calculated by weighting the U-values by area.

.. math::
   :nowrap:

   \begin{align*}
   U_i &= \frac{1}{R_i} \\
   U_{eff,avg} &= \frac{\sum_i{U_i A_i}}{\sum_i A_i} \\
   R_{eff,avg} &= \frac{1}{U_{eff,avg}} \\
   \end{align*}

Then the nearest discrete R-value to the weighted average R-value from the lookup table is used.
The lookup table can be found at `hescorehpxml\\lookups\\lu_roof_eff_rvalue.csv
<https://github.com/NREL/hescore-hpxml/blob/assembly_eff_r_values/hescorehpxml/lookups/lu_roof_eff_rvalue.csv>`_.

Attic R-value
*************

Determining the attic floor insulation levels uses the same procedure as
:ref:`roof-rvalues` except the lookup table is different. 

If nominal R-value is used, the attic floor center-of-cavity R-values are each R-0.5 greater
than the nominal R-values in the enumeration list.

If assembly R-value is used, the lookup table at `hescorehpxml\\lookups\\lu_ceiling_eff_rvalue.csv
<https://github.com/NREL/hescore-hpxml/blob/assembly_eff_r_values/hescorehpxml/lookups/lu_ceiling_eff_rvalue.csv>`_
is used. 

If the primary roof type is determined to be a cathedral ceiling, then an attic
R-value is not calculated.

.. _knee-walls:

Knee Walls
**********

In HPXML v2, knee walls are specified via the ``Attic/AtticKneeWall`` element.

Starting from HPXML v3, knee walls are specified via wall attachment in
``Attic/AttachedToWall``. The attached wall must have ``AtticWallType`` of "knee
wall". See below an example:

.. code-block:: xml
   :emphasize-lines: 10, 15-30

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
                  <NominalRValue>10</NominalRValue>
              </Layer>
          </Insulation>
      </Wall>
   <Walls>

If an attic has knee walls specified, the area of the knee walls will be added
to the attic floor area.

The knee walls R-value can be described by nominal R-value or assembly R-value.

If nominal R-value is used, the knee walls center-of-cavity R-value will be reflected 
in the area weighted center-of-cavity effective R-value of the attic floor. 
The knee walls center-of-cavity R-value is R-1.8 greater than the nominal R-value.

If assembly R-value is used, the knee walls assembly R-value will be reflected in
the area weighted assembly effective R-value of the attic floor.

The averaged center-of-cavity or assembly effective R value is combined from all knee walls 
and attic floors attached to the same attic. The highest weighted attic floor 
construction type is selected.

