Walls
#####

.. contents:: Table of Contents

.. _wallorientation:

Wall Orientation
****************

The flexibility of HPXML allows specification of any number of walls and windows
facing any direction. HEScore expects only one wall/window specification for
each side of the building (front, back, left, right). 

Each wall in the HPXML document that has an ``ExteriorAdjacentTo='ambient'``
(HPXML v2) or ``ExteriorAdjacentTo='outside'`` (HPXML v3) or is missing the
``ExteriorAdjacentTo`` subelement (assumed to be ambient/outside) is considered
for translation to HEScore. This excludes attic knee walls (see
:ref:`knee-walls`), interior walls, walls between living space and a garage,
etc. since HEScore does not model those walls. The translator then attempts to
assign each wall to the nearest side of the building, which is relative to the
orientation of the front of the building. The wall construction and exterior
finish of the largest wall by area on each side of the building are used to
define the properties sent to HEScore. An area weighted R-value of all the walls
on each side of the building is calculated as well as described in
:ref:`wall-rvalue`. If there is only one wall on any side of the house, the area
is not required for that side. If a wall falls exactly between two sides of the
house the area of the wall is divided by two and half of the wall is assigned to
either side.


HEScore also allows the specification of one wall for all sides of the building.
If none of the walls in HPXML have orientation (or azimuth) data, the wall
construction and exterior finish of the largest wall by area on each side of
the building are used to define the properties sent to HEScore. An area
weighted R-value of all the walls on each side of the building is calculated as
well as described in :ref:`wall-rvalue`. If there is only one wall and no area
specified, that wall is used to determine the wall construction.

.. note::

   The following conditions must be met for the wall translation to succeed:
   
    * If there is more than one wall on each side of the building each wall 
      on that side of the building must have an ``Area`` specified.
    * Either all walls must have an ``Azimuth`` and/or ``Orientation`` or none
      of them must. 

.. _wall-construction:

Wall Construction
*****************

HEScore uses a selection of `construction codes`_ to describe wall construction
type, insulation levels, and siding. HPXML, as usual, uses a more flexible
approach defining wall types: layers of insulation materials that each include
an R-value, thickness, wall cavity information, etc. To translate the inputs
from HPXML to HEScore approximations need to be made to condense the continuous
inputs in HPXML to discrete inputs required for HEScore.

.. _construction codes: https://docs.google.com/spreadsheet/pub?key=0Avk3IqpWXaRkdGR6cXFwdVJ4ZVdYX25keDVEX1pPYXc&output=html

The wall R-value can be described by using nominal R-value or assembly R-value.
If a user wishes to use a nominal R-value, nominal R-value for all layers need to be provided.
Otherwise, assembly R-values for each layer need to be provided.

If nominal R-value is used, the R-value is summed for all insulation layers. If the wall construction 
was determined to have :ref:`rigid-sheathing`, an R-value of 5 is subtracted from the wall R-value sum
to account for the R-value of the sheathing in the HEScore construction. 
The nearest discrete R-value from the list of possible R-values for that wall type
is used to determine an assembly code. Then, the assembly R-value of the corresponding 
assembly code from the lookup table is used. The lookup table can be found 
at `hescorehpxml\\lookups\\lu_wall_eff_rvalue.csv
<https://github.com/NREL/hescore-hpxml/blob/assembly_eff_r_values/hescorehpxml/lookups/lu_wall_eff_rvalue.csv>`_.

If assembly R-value is used, the discrete R-value nearest to assembly R-value
from the lookup table for that wall type is used. The lookup table can be found
at `hescorehpxml\\lookups\\lu_wall_eff_rvalue.csv
<https://github.com/NREL/hescore-hpxml/blob/assembly_eff_r_values/hescorehpxml/lookups/lu_wall_eff_rvalue.csv>`_.

Wood Frame Walls
================

If ``WallType/WoodStud`` is selected in HPXML, each layer of the wall insulation
is parsed and if a continuous layer is found, or if the subelement
``WallType/WoodStud/ExpandedPolyStyreneSheathing`` is found, the wall is
specified in HEScore as "Wood Frame with Rigid Foam Sheathing."

.. code-block:: xml
   :emphasize-lines: 6,12,14

   <Wall>
      <SystemIdentifier id="wall1"/>
      <WallType>
          <WoodStud>
              <!-- Either this element needs to be here or continuous insulation below -->
              <ExpandedPolystyreneSheathing>true</ExpandedPolystyreneSheathing>
          </WoodStud>
      </WallType>
      <Insulation>
          <SystemIdentifier id="wall1ins"/>
          <Layer>
              <InstallationType>continuous</InstallationType>
              <NominalRValue>5</NominalRValue>
          </Layer>
          ...
      </Insulation>
   </Wall>

Otherwise, if the ``OptimumValueEngineering`` boolean element is set to
``true``, the "Wood Frame with Optimal Value Engineering" wall type in HEScore
is selected. 

.. code-block:: xml
   :emphasize-lines: 5
   
   <Wall>
      <SystemIdentifier id="wall2"/>
      <WallType>
          <WoodStud>
              <OptimumValueEngineering>true</OptimumValueEngineering>
          </WoodStud>
          <Insulation>
              ...
          </Insulation>
      </WallType>
   </Wall>


.. note::

   The ``OptimumValueEngineering`` flag needs to be set in HPXML to
   translate to this wall type. The translator will not infer this from stud
   spacing.

Finally, if neither of the above conditions are met, the wall is specified as
simply "Wood Frame" in HEScore. 

Siding is selected according to the :ref:`siding map <sidingmap>`.

Structural Brick
================

If ``WallType/StructuralBrick`` is found in HPXML, one of the structural brick
codes in HEScore is specified.

.. code-block:: xml
   :emphasize-lines: 4,9,12

   <Wall>
      <SystemIdentifier id="wall3"/>
      <WallType>
          <StructuralBrick/>
      </WallType>
      <Insulation>
          <SystemIdentifier id="wall3ins"/>
          <Layer>
              <NominalRValue>5</NominalRValue>
          </Layer>
          <Layer>
              <NominalRValue>5</NominalRValue>
          </Layer>
          <!-- This would have a summed R-value of 10 -->
      </Insulation>
   </Wall>


Concrete Block or Stone
=======================

If ``WallType/ConcreteMasonryUnit`` or ``WallType/Stone`` is found, one of the
concrete block construction codes is used in HEScore. The siding is
translated using the :ref:`same assumptions as wood stud walls <sidingmap>`
with the exception that vinyl, wood, or aluminum siding is not available and if
those are specified in the HPXML an error will result.

Straw Bale
==========

If ``WallType/StrawBale`` is found in the HPXML wall, the straw bale wall
assembly code in HEScore is selected.

.. _sidingmap:

Exterior Finish
===============

Siding mapping is done from the ``Wall/Siding`` element in HPXML. Siding is
specified as the last two characters of the construction code in HEScore.

.. table:: Siding type mapping

   ========================  ================
   HPXML                     HEScore 
   ========================  ================
   wood siding               wo
   stucco                    st
   synthetic stucco          st
   vinyl siding              vi
   aluminum siding           al
   brick veneer              br
   asbestos siding           wo
   fiber cement siding       wo
   composite shingle siding  wo
   masonite siding           wo
   other                     *not translated*
   ========================  ================   

.. note::

   *not translated* means the translation will fail for that house.


.. _wall-rvalue:

Area Weighted Wall R-value
**************************

When more than one HPXML ``Wall`` element must be combined into one wall
construction for HEScore, the wall construction code is determined for each
HPXMl ``Wall`` as described in :ref:`wall-construction`. The wall construction
and exterior finish that represent the largest combined area are used to
represent the side of the house. 

Whether nominal R-value or assembly R-value is used, a weighted average R-value is calculated
using assembly R-value for each ``Wall``. 
The weighted average is calculated by weighting the U-values by area.

.. math::
   :nowrap:

   \begin{align*}
   U_i &= \frac{1}{R_i} \\
   U_{eff,avg} &= \frac{\sum_i{U_i A_i}}{\sum_i A_i} \\
   R_{eff,avg} &= \frac{1}{U_{eff,avg}} \\
   \end{align*}

Then the nearest discrete R-value to the weighted average R-value from the lookup table is used.
The lookup table can be found at `hescorehpxml\\lookups\\lu_wall_eff_rvalue.csv
<https://github.com/NREL/hescore-hpxml/blob/assembly_eff_r_values/hescorehpxml/lookups/lu_wall_eff_rvalue.csv>`_.

