Windows and Skylights
#####################

.. contents:: Table of Contents

Window Orientation
******************

HEScore requires that a window area be specified for each side of the building.
To determine the window area on each side of the building, each ``Window``
element in HPXML must have an ``Area`` subelement. The ``Area`` subelement is
assumed to mean the sum of the areas of the windows that the ``Window`` element
represents. Each ``Window`` is then assigned to a side of the building in one of
two ways:

   #. By inspecting the azimuth or orientation of the window.
   #. By association with a particular wall.
   
If there is an ``Orientation`` or ``Azimuth`` element, the side is determined
via the one of those elements with preference given to the ``Azimuth`` if
present. If the window falls between two sides of the house, the window area is
divided between the sides of the house evenly. 

If ``Orientation`` or ``Azimuth`` are missing and the HPXML window has the
``AttachedToWall`` element, the id reference in that element is used to find the
associated wall and the side of the building that the window faces is inferred
from the :ref:`wall orientation <wallorientation>`. If the window is attached to
a foundation wall, the orientation/azimuth must be provided on the ``Window``
element because foundation walls do not have orientation or azimuth elements
available.

The areas on each side of the house are summed and the :ref:`window-prop` are
determined independently for each side of the house. Since HPXML requires that
window properties be assigned to each direction, the
``window_construction_same`` option in HEScore will always be false and all
windows will be specified separately. 

Skylights in HEScore do not have an orientation that can be set, therefore
orientation/azimuth information about skylights is ignored. Use `AttachedToRoof`
to specify which HPXML roof each skylight is attached to. If not specified, skylights
will be assigned to the first hescore roof.

.. _window-prop:

Window Properties
*****************

Windows can be specified in one of two different ways in HEScore:

   #. NFRC rated window specifications U-Factor and Solar Heat Gain
      Coefficient (SHGC)
   #. Generic window types defined by the number of panes of glass, frame
      material, and glazing type.

Preference is given to the first choice above if those values are available in
the HPXML document. If U-Factor and SHGC are not available, then one of the
window codes is chosen based on the other properties of the windows. Since
HPXML stores the window properties for each window, the properties for the
windows on each side of the house must be aggregated across all of the windows
on that side. The processes described below are done independently for the
windows on each side of the house.

Defining windows using NFRC specifications
==========================================

When there is at least one window on a side of the house that has U-Factor and
SHGC values available, those are used. The values are aggregated across all the
windows on a particular side of the house by taking an area weighted average
omitting any windows that do not have U-Factor and SHGC values.

Defining windows by selecting a window type
===========================================

When none of the windows on a side of the house have U-Factor and SHGC data
elements, a window code is selected based on other properties of each window.
Then the most predominant window code by area on each side of the house is
selected. 

Unfortunately there is not a 1-to-1 correlation of the HPXML data elements to
HEScore for these selections and it is possible to define windows in HPXML that
are impossible to input into HEScore. In these cases the translation will fail.

Windows are first sorted by frame type. The mapping of HPXML ``FrameType`` to
HEScore frame type is performed thusly.

.. table:: Window frame type mapping

   =============     ================
   HPXML             HEScore
   =============     ================
   Aluminum          Aluminum
   Composite         Wood or Vinyl
   Fiberglass        Wood or Vinyl
   Metal             Aluminum
   Vinyl             Wood or Vinyl
   Wood              Wood or Vinyl
   Other             *not translated*
   =============     ================

.. warning::

   If a ``FrameType`` of ``Other`` is selected in HPXML, the 
   translation will fail. 

Both the ``Aluminum`` and ``Metal`` frame types in HPXML have optional
``ThermalBreak`` subelements that specify whether there is a thermal break in
the frame. If ``ThermalBreak`` is true then the "Aluminum with Thermal Break"
frame type is selected.

Depending on the frame type selected in HEScore, different options become
available for number of panes and glass type. The following sections explain
the logic for each frame type.

Aluminum
--------

The aluminum frame type allows for single- and double-paned windows, but not
more than that. According to the HEScore documentation, single-pane windows
with storm windows should be considered double-pane.

.. _al_mapping:

.. table:: Window pane mapping for Aluminum frame types (HPXML v2)
   
   ==============================  ================
   HPXML Glass Layers              HEScore 
   ==============================  ================
   single-pane                     single-pane
   double-pane                     double-pane
   triple-pane                     *not translated*
   multi-layered                   *not translated*
   single-paned with storms        double-pane
   single-paned with low-e storms  double-pane
   other                           *not translated*
   ==============================  ================

.. table:: Window pane mapping for Aluminum frame types (HPXML v3)

   ==============================  ================
   HPXML Glass Layers              HEScore
   ==============================  ================
   single-pane                     single-pane
   double-pane                     double-pane
   triple-pane                     *not translated*
   multi-layered                   *not translated*
   other                           *not translated*
   ==============================  ================

.. note::

   Starting from HPXML v3, "single-paned with storms" and "single-paned with low-e storms" enumerations
   are removed. Instead, translator searches ``Window/StormWindow`` element for storm existence.
   If the storm window is a low-e window, specify ``Window/StormWindow/GlassType`` to be equal to "low-e".
   ``StormWindow`` is only used when ``single-pane`` window is specified.

   HPXML v2 "single-paned with storms" equivalence(mapped to double-pane) in HPXML v3:
      - ``Window/GlassLayers`` "single-pane" + ``Window/StormWindow``.

   HPXML v2 "single-paned with low-e storms" equivalence(mapped to double-pane) in HPXML v3:
      - ``Window/GlassLayers`` "single-pane" + ``Window/StormWindow/GlassType`` to be "low-e".


.. warning::

   If a window has the "Aluminum" frame type, the ``GlassLayers`` must be
   single-pane, double-pane, or a single-pane with storm windows (or specify
   ``Window/StormWindow`` with "single-pane" in HPXML v3+) or the translation
   will fail.


Single-pane
^^^^^^^^^^^

Single-paned windows can be either tinted or clear. If the ``GlassType`` element
is either "tinted" or "tinted/reflective", "Single-pane, tinted" is selected.
Otherwise, "Single-pane, clear" is selected.

.. table:: Single-pane window mapping for Aluminum frame types

   ========================  ============================
   HPXML Glass Type          HEScore Glazing Type
   ========================  ============================
   low-e                     Single-pane, tinted
   tinted                    Single-pane, tinted
   reflective                Single-pane, clear
   tinted/reflective         Single-pane, tinted
   other                     Single-pane, clear
   *element missing*         Single-pane, clear
   ========================  ============================

Double-pane
^^^^^^^^^^^

Double-paned windows have a solar control low-e option in addition to the tinted
and clear options. 

.. table:: Double-pane window mapping for Aluminum frame types

   ========================  ================================
   HPXML Glass Type          HEScore Glazing Type
   ========================  ================================
   low-e                     Double-pane, solar-control low-E
   tinted                    Double-pane, tinted
   reflective                Double-pane, solar-control low-E
   tinted/reflective         Double-pane, solar-control low-E
   other                     Double-pane, clear
   *element missing*         Double-pane, clear
   ========================  ================================
   
Aluminum with Thermal Break
---------------------------

Only double paned window options are available for the aluminum with thermal
break frame type. According to the HEScore documentation, single-pane windows
with storm windows should be considered double-pane.

.. _althb_mapping:

.. table:: Window pane mapping for Aluminum with Thermal Break frame types (HPXML v2)
   
   ==============================  ================
   HPXML Glass Layers              HEScore 
   ==============================  ================
   single-pane                     *not translated*
   double-pane                     double-pane
   triple-pane                     *not translated*
   multi-layered                   *not translated*
   single-paned with storms        double-pane
   single-paned with low-e storms  double-pane
   other                           *not translated*
   ==============================  ================

.. table:: Window pane mapping for Aluminum with Thermal Break frame types (HPXML v3)

   ==============================  ================
   HPXML Glass Layers              HEScore
   ==============================  ================
   single-pane                     *not translated*
   double-pane                     double-pane
   triple-pane                     *not translated*
   multi-layered                   *not translated*
   other                           *not translated*
   ==============================  ================

.. note::

   Starting from HPXML v3, "single-paned with storms" and "single-paned with low-e storms" enumerations
   are removed. Instead, translator searches ``Window/StormWindow`` element for storm existence.
   If the storm window is a low-e window, specify ``Window/StormWindow/GlassType`` to be equal to "low-e".
   ``StormWindow`` is only used when ``single-pane`` window is specified.

   HPXML v2 "single-paned with storms" equivalence(mapped to double-pane) in HPXML v3:
      - ``Window/GlassLayers`` "single-pane" + ``Window/StormWindow``.

   HPXML v2 "single-paned with low-e storms" equivalence(mapped to double-pane) in HPXML v3:
      - ``Window/GlassLayers`` "single-pane" + ``Window/StormWindow/GlassType`` to be "low-e".


.. warning::

   If a window has the "Aluminum with Thermal Break" frame type, the
   ``GlassLayers`` must be double-pane or single-pane with storms (or specify
   ``Window/StormWindow`` with "single-pane" in HPXML v3+) or the translation
   will fail.

Double-pane
^^^^^^^^^^^

To get the "Double-pane, insulating low-E, argon gas fill" option, you need to
specify the window elements as highlighted below. Storm windows will not work
because it is impossible to have an argon gas fill between the window and the
storm window.

.. code-block:: xml
   :emphasize-lines: 10-12

   <Window>
      <SystemIdentifier id="id1"/>
      <Area>30</Area>
      <Orientation>east</Orientation>
      <FrameType>
          <Aluminum><!-- or Metal -->
              <ThermalBreak>true</ThermalBreak>
          </Aluminum>
      </FrameType>
      <GlassLayers>double-pane</GlassLayers>
      <GlassType>low-e</GlassType>
      <GasFill>argon</GasFill>
   </Window>

"Double-pane, solar-control low-E" can be specified as highlighted in the
following code block. Using "reflective" in ``GlassType`` is assumed to be the
same as solar control low-e. 

.. code-block:: xml
   :emphasize-lines: 10-11

   <Window>
      <SystemIdentifier id="id2"/>
      <Area>30</Area>
      <Orientation>east</Orientation>
      <FrameType>
          <Aluminum><!-- or Metal -->
              <ThermalBreak>true</ThermalBreak>
          </Aluminum>
      </FrameType>
      <GlassLayers>double-pane</GlassLayers><!-- or other double-pane mapped options mentioned above -->
      <GlassType>reflective</GlassType>
   </Window>

.. warning::

   Is "reflective" the same as solar control low-e or close enough? I'm running
   on the assumption that low-e means insulating low-e. 

To specify the "Double-pane, tinted" option in HEScore, the ``GlassType`` needs
to be either "tinted" or "tinted/reflective."

.. code-block:: xml
   :emphasize-lines: 10-11

   <Window>
      <SystemIdentifier id="window1"/>
      <Area>30</Area>
      <Orientation>east</Orientation>
      <FrameType>
          <Aluminum>
              <ThermalBreak>true</ThermalBreak>
          </Aluminum>
      </FrameType>
      <GlassLayers>double-pane</GlassLayers><!-- or 'single-paned with storms', 'single-paned with low-e storms' -->
      <GlassType>tinted</GlassType><!-- or tinted/reflective -->
   </Window>

All other :ref:`double-pane <althb_mapping>` windows will be translated as
"Double-pane, clear."

Wood or Vinyl
-------------

In HEScore wood or vinyl framed windows can have 1, 2, or 3 panes. According to
the HEScore documentation, single-pane windows with storm windows should be
considered double-pane. The HPXML ``GlassLayers`` maps into HEScore number of
panes as follows:


.. table:: Window pane mapping for Wood or Vinyl frame types (HPXML v2)
   
   ==============================  ================
   HPXML Glass Layers              HEScore 
   ==============================  ================
   single-pane                     single-pane
   double-pane                     double-pane
   triple-pane                     triple-pane
   multi-layered                   *not translated*
   single-paned with storms        double-pane
   single-paned with low-e storms  double-pane
   other                           *not translated*
   ==============================  ================

.. table:: Window pane mapping for Wood or Vinyl frame types (HPXML v3)

   ==============================  ================
   HPXML Glass Layers              HEScore
   ==============================  ================
   single-pane                     single-pane
   double-pane                     double-pane
   triple-pane                     triple-pane
   multi-layered                   *not translated*
   other                           *not translated*
   ==============================  ================

.. note::

   Starting from HPXML v3, "single-paned with storms" and "single-paned with low-e storms" enumerations
   are removed. Instead, translator searches ``Window/StormWindow`` element for storm existence.
   If the storm window is a low-e window, specify ``Window/StormWindow/GlassType`` to be equal to "low-e".
   ``StormWindow`` is only used when ``single-pane`` window is specified.

   HPXML v2 "single-paned with storms" equivalence(mapped to double-pane) in HPXML v3:
      - ``Window/GlassLayers`` "single-pane" + ``Window/StormWindow``.

   HPXML v2 "single-paned with low-e storms" equivalence(mapped to double-pane) in HPXML v3:
      - ``Window/GlassLayers`` "single-pane" + ``Window/StormWindow/GlassType`` to be "low-e".


Single-pane
^^^^^^^^^^^

Single-pane windows can be either tinted or not. If the ``GlassType`` element is
either "tinted" or "tinted/reflective", "Single-pane, tinted" is selected.
Otherwise, "Single-pane, clear" is selected.

.. table:: Single-pane window mapping for Wood or Vinyl frame types

   ========================  ============================
   HPXML Glass Type          HEScore Glazing Type
   ========================  ============================
   low-e                     Single-pane, tinted
   tinted                    Single-pane, tinted
   reflective                Single-pane, clear
   tinted/reflective         Single-pane, tinted
   other                     Single-pane, clear
   *element missing*         Single-pane, clear
   ========================  ============================

Double-pane
^^^^^^^^^^^
   
Double-pane windows can be either clear, tinted, insulating low-E with or
without argon gas fill, and solar control low-E with or without argon gas fill.
According to the HEScore documentation, single-pane windows with storm windows
should be considered double-pane. The double-pane mapping is a bit more
complicated as it needs to use multiple elements to determine the glazing type
for HEScore. We will address each possible HEScore combination and how it is
expected to be represented in HPXML.

To get a insulating low-E double-pane wood or vinyl framed window,
``GlassLayers`` needs to be "double-pane" and the ``GlassType`` needs to be
"low-e" or ``GlassLayers`` needs to be "single-paned with low-e storms" (or
GlassLayers "single-pane" + ``Window/StormWindow/GlassType`` equal to "low-e" in
HPXML v3+). If ``GasFill`` is argon, it will be argon filled. For instance, to
get a double-pane low-E with argon fill, the HPXML window element would look
like:

.. code-block:: xml
   :emphasize-lines: 8-10

   <Window>
      <SystemIdentifier id="window1"/>
      <Area>30</Area>
      <Orientation>east</Orientation>
      <FrameType>
          <Vinyl/>
      </FrameType>
      <GlassLayers>double-pane</GlassLayers>
      <GlassType>low-e</GlassType>
      <GasFill>argon</GasFill>
   </Window>

Translating a Single-pane window with a low-E storm window into the HEScore type
of double-pane with insulating low-E the HPXML window element would look like:

- HPXML v2:

.. code-block:: xml
   :emphasize-lines: 8

   <Window>
      <SystemIdentifier id="window53"/>
      <Area>30</Area>
      <Orientation>east</Orientation>
      <FrameType>
          <Vinyl/>
      </FrameType>
      <GlassLayers>single-paned with low-e storms</GlassLayers>
   </Window>

- HPXML v3:

.. code-block:: xml
   :emphasize-lines: 8-12

   <Window>
      <SystemIdentifier id="window53"/>
      <Area>30</Area>
      <Orientation>east</Orientation>
      <FrameType>
          <Vinyl/>
      </FrameType>
      <GlassLayers>single-pane</GlassLayers>
      <StormWindow>
         <SystemIdentifier id="windowstorm"/>
         <GlassType>low-e</GlassType>
      </StormWindow>
   </Window>

Note the missing ``GlassType`` element. It is ignored when it's a single-paned
window with low-e storms. The translation will also ignore ``GasFill`` for
single-paned window because it's impossible to have argon between a single pane
window and storm window.

To specify a solar-control low-E double-pane wood or vinyl framed window a
``GlassType`` of "reflective" must be specified. Setting ``GasFill`` as "argon"
or not indicates whether the argon gas fill type is chosen in HEScore.

.. warning::

   The HPXML ``GlassType`` of reflective is assumed to mean solar
   control low-E when translated into HEScore parlance. 

For instance, to get a "Double-pane, solar-control low-E" glazing type, the
HPXML window element would look like:

.. code-block:: xml
   :emphasize-lines: 8-9

   <Window>
      <SystemIdentifier id="window53"/>
      <Area>30</Area>
      <Orientation>east</Orientation>
      <FrameType>
          <Wood/>
      </FrameType>
      <GlassLayers>double-pane</GlassLayers>
      <GlassType>reflective</GlassType>
   </Window>

For argon filled, you would add ``<GasFill>argon</GasFill>`` before the
``</Window>``.
  
If the ``GlassType`` is "tinted" or "tinted/reflective" the "Double-pane,
tinted" HEScore glazing type is selected. 

Finally, if the window is double-pane (or single-pane with storm window) and
doesn't meet the above criteria, then the "Double-pane, clear" glazing type is
chosen for HEScore. 

Triple-pane
^^^^^^^^^^^

If the ``GlassLayers`` in HPXML specifies a "triple-paned" window, the HEScore
"Triple-pane, insulating low-E, argon gas fill" glazing type is selected. The
``GlassType`` and ``GasFill`` elements are not considered since this is the
only triple-pane glazing option in HEScore.

Solar Screens
*************

For each side of the house in HEScore, solar screens may be present.
To determine if solar screens should be specified, the translator looks for either
of the following subelements of ``Window`` or ``Skylight``:

HPXML v2:

- ``<ExteriorShading>solar screens</ExteriorShading>``
- ``<Treatments>solar screen</Treatments>`` 

HPXML v3:

- ``<ExteriorShading><Type>solar screens</Type></ExteriorShading>``

If the majority of the window area on a side of the house (or skylights facing upwards)
meet that criteria, that side of the house will have solar screens in the HEScore model. 
This determination is made independent of whether the other window properties were set 
using NFRC specifications or inferred based on window type.
