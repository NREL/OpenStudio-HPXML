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

In all cases the R-value is summed for all insulation layers and the
nearest discrete R-value from the list of possible R-values for that wall type
is used. For walls with rigid foam sheathing, R-5 is subtracted from the
nominal R-value sum to account for the R-value of the sheathing in the HEScore
construction assembly.

Siding is selected according to the :ref:`siding map <sidingmap>`.

Structural Brick
================

If ``WallType/StructuralBrick`` is found in HPXML, one of the structural brick
codes in HEScore is specified. The nearest R-value to the sum of all the
insulation layer nominal R-values is selected.

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
concrete block construction codes is used in HEScore. The nearest R-value to
the sum of all the insulation layer nominal R-values is selected. The siding is
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

A weighted R-value is calculated by looking up the center-of-cavity
R-value for the wall construction, exterior finish, and nominal R-value for
each ``Wall`` from the following table.

.. table:: Wall center-of-cavity R-values

   +---------+------------------+-------+------+---------+-------------+-----+
   |Exterior |Wood Siding       |Stucco |Vinyl |Aluminum |Brick Veneer |None |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-value  |Effective R-value                                              |
   +=========+==================+=======+======+=========+=============+=====+
   |**Wood Frame**                                                           |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-0      |3.6               |2.3    |2.2   |2.1      |2.9          |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-3      |5.7               |4.4    |4.3   |4.2      |5.0          |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-7      |9.7               |8.4    |8.3   |8.2      |9.0          |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-11     |13.7              |12.4   |12.3  |12.2     |13.0         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-13     |15.7              |14.4   |14.3  |14.2     |15.0         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-15     |17.7              |16.4   |16.3  |16.2     |17.0         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-19     |21.7              |20.4   |20.3  |20.2     |21.0         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-21     |23.7              |22.4   |22.3  |22.2     |23.0         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |**Wood Frame w/insulated sheathing**                                     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-0      |6.1               |5.4    |5.3   |5.2      |6.0          |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-3      |9.1               |8.4    |8.3   |8.2      |9.0          |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-7      |13.1              |12.4   |12.3  |12.2     |13.0         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-11     |17.1              |16.4   |16.3  |16.2     |17.0         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-13     |19.1              |18.4   |18.3  |18.2     |19.0         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-15     |21.1              |20.4   |20.3  |20.2     |21.0         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-19     |25.1              |24.4   |24.3  |24.2     |25.0         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-21     |27.1              |26.4   |26.3  |26.2     |27.0         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |**Optimum Value Engineering**                                            |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-19     |21.0              |20.3   |20.1  |20.1     |20.9         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-21     |23.0              |22.3   |22.1  |22.1     |22.9         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-27     |29.0              |28.3   |28.1  |28.1     |28.9         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-33     |35.0              |34.3   |34.1  |34.1     |34.9         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-38     |40.0              |39.3   |39.1  |39.1     |39.9         |     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |**Structural Brick**                                                     |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-0      |                  |       |      |         |             |2.9  |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-5      |                  |       |      |         |             |7.9  |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-10     |                  |       |      |         |             |12.8 |
   +---------+------------------+-------+------+---------+-------------+-----+
   |**Concrete Block**                                                       |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-0      |                  |4.1    |      |         |5.6          |4.0  |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-3      |                  |5.7    |      |         |7.2          |5.6  |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-6      |                  |8.5    |      |         |10.0         |8.3  |
   +---------+------------------+-------+------+---------+-------------+-----+
   |**Straw Bale**                                                           |
   +---------+------------------+-------+------+---------+-------------+-----+
   |R-0      |                  |58.8   |      |         |             |     |
   +---------+------------------+-------+------+---------+-------------+-----+


Then a weighted average is calculated by weighting the U-values values by area.

.. math::
   :nowrap:

   \begin{align*}
   U_i &= \frac{1}{R_i} \\
   U_{eff,avg} &= \frac{\sum_i{U_i A_i}}{\sum_i A_i} \\
   R_{eff,avg} &= \frac{1}{U_{eff,avg}} \\
   \end{align*}

The R-0 center-of-cavity R-value (:math:`R_{offset}`) is selected for
the highest weighted wall construction type represented in the calculation and
is subtracted from :math:`R_{eff,avg}`. For construction types where there is
no R-0 nominal value, the lowest nominal R-value is subtracted from the
corresponding effective R-value.

.. math::

   R = R_{eff,avg} - R_{offset}

Finally the R-value is rounded to the nearest insulation level in the
enumeration choices for the highest weighted roof construction type included in
the calculation.


