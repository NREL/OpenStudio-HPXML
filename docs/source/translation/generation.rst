Generation
##########

Solar Electric
**************

HEScore allows for a single photovoltaic system to be included as of v2016.
In HPXML, multiple ``PVSystem`` elements can be specified to represent the PV systems on the house.
The translator combines multiple systems and generates the appropriate HEScore inputs as follows:

Capacity Known
==============

If each ``PVSystem`` has a ``MaxPowerOutput``, this is true.
If each ``PVSystem`` has a ``CollectorArea``, this is false.
Preference is given to known capacity if both are available.
Either a ``MaxPowerOutput`` must be specified for every ``PVSystem``
or ``CollectorArea`` must be specified for every ``PVSystem``.

DC Capacity
===========

If each ``PVSystem`` has a ``MaxPowerOutput``, the system capacity is known.
The ``system_capacity`` in HEScore is calculated by summing all the ``MaxPowerOutput`` elements in HPXML.

Number of Panels
================

If ``MaxPowerOutput`` is missing from any ``PVSystem``,
``CollectorArea`` is required on every PVSystem and the system capacity is not known.
The number of panels is calculated by summing all the collector area, dividing by 17.6 sq.ft.,
and rounding to the nearest whole number.

Year Installed
==============

For each ``PVSystem`` the ``YearInverterManufactured`` and ``YearModulesManufactured`` element values are retrieved,
and the greater of the two is assumed to be the year that system was installed.
When there are multiple ``PVSystem`` elements, a capacity or area-weighted average of the assumed year installed
is calculated and used.

Panel Orientation (Azimuth)
===========================

For each ``PVSystem`` the ``ArrayAzimuth`` (degrees clockwise from north) is retrieved.
If ``ArrayAzimuth`` is not available, ``ArrayOrientation`` (north, northwest, etc) is converted into an azimuth.
A capacity or area-weighted average azimuth is calculated and converted into the nearest cardinal direction
(north, northwest, etc) for submission into the ``array_azimuth`` HEScore input (which expects a direction,
not a numeric azimuth).

Panel Tilt
==========
For each ``PVSystem`` the ``ArrayTilt`` (in degrees from horizontal) is retrieved.
A capacity or area-weighted average tilt is calculated and submitted to the ``array_tilt`` HEScore input
(which expects an enumeration, not a numeric tilt).
The tilt is mapped to HEScore as follows:

.. table:: Tilt mapping

   =====================  ================
   HPXML                  HEScore 
   =====================  ================
   0 - 7°                 flat
   8 - 22°                low_slope
   23 - 37°               medium_slope
   38 - 90°               steep_slope
   =====================  ================  
