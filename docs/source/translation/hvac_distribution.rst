HVAC Distribution
#################

.. contents:: Table of Contents

In HPXML multiple ``HVACDistribution`` elements can be associated with a heating
or cooling system. For the purposes of this translator, it is required that only one ``HVACDistribution`` element be linked.
That element can then describe a ducted system, a hydronic
system, or an open ended other system. For the translation to HEScore, only
``HVACDistribution`` elements that are ducted are considered.

.. _ductlocationmapping:

Duct Location Mapping
*********************

For each ``Ducts`` element in each air distribution system, the location of the
duct mapped from HPXML enumerations to HEScore enumerations according to the
following mapping.

.. table:: Duct Location mapping (HPXML v2)

   ======================  ================
   HPXML                   HEScore
   ======================  ================
   conditioned space       cond_space
   unconditioned space     *not translated*
   unconditioned basement  uncond_basement
   unvented crawlspace     unvented_crawl
   vented crawlspace       vented_crawl
   crawlspace              *not translated*
   unconditioned attic     uncond_attic
   interstitial space      *not translated*
   garage                  vented_crawl
   outside                 *not translated*
   ======================  ================

.. table:: Duct Location mapping (HPXML v3)

   ===========================  ================
   HPXML                        HEScore Hierarchy
   ===========================  ================
   living space                 cond_space
   unconditioned space          uncond_basement, vented_crawl, unvented_crawl, uncond_attic
   under slab                   under_slab
   basement                     uncond_basement, cond_space
   basement - unconditioned     uncond_basement
   basement - conditioned       cond_space
   crawlspace - unvented        unvented_crawl
   crawlspace - vented          vented_crawl
   crawlspace - unconditioned   vented_crawl, unvented_crawl
   crawlspace - conditioned     cond_space
   crawlspace                   vented_crawl, unvented_crawl, cond_space
   exterior wall                exterior_wall
   attic                        uncond_attic, cond_space
   attic - unconditioned        uncond_attic
   attic - conditioned          cond_space
   attic - unvented             uncond_attic
   attic - vented               uncond_attic
   interstitial space           *not translated*
   garage                       vented_crawl
   garage - conditioned         cond_space
   garage - unconditioned       vented_crawl
   roof deck                    outside
   outside                      outside
   ===========================  ================

.. warning:: 

   If an HPXML duct location maps to *not translated* above, the 
   translation for the house will fail.

Duct Fractions
**************

For each ``Ducts`` element in an air distribution system the ``FracDuctArea`` is summed by
HEScore :ref:`duct location <ductlocationmapping>`.

Duct Insulation
***************

If the any of the ``Ducts`` elements in a particular
:ref:`location <ductlocationmapping>` have a ``DuctInsulationRValue`` or
``DuctInsulationThickness`` that is greater than zero or have a ``DuctInsulationMaterial`` that is not ``None``, 
all of the ducts in that location are considered insulated.

Duct Sealing
************

Duct leakage measurements are not stored on the individual ``Ducts`` elements in
HEScore, which means they are not directly associated with a duct location.
They are instead associated with an ``AirDistribution`` element, which can have
many ducts in many locations. Duct sealing information is therefore associated
with all ducts in an ``AirDistribution`` element.

To specify that the ducts in an ``AirDistribution`` system are sealed, the
translator expects to find either of the following elements:

* ``DuctLeakageMeasurement/LeakinessObservedVisualInspection`` element with
  the value of "connections sealed w mastic".
* ``HVACDistribution/HVACDistributionImprovement/DuctSystemSealed`` element
  with the value of "true".

The ``DuctLeakageMeasurement`` can hold values for actual measurements of
leakage, but since HEScore cannot do anything with them, they will be ignored.
Therefore the following will result in an "unsealed" designation:

.. code-block:: xml

   <DuctLeakageMeasurement>
      <DuctType>supply</DuctType>
      <!-- All of this is ignored -->
      <DuctLeakageTestMethod>duct leakage tester</DuctLeakageTestMethod>
      <DuctLeakage>
          <Units>CFM25</Units>
          <Value>0.000000001</Value><!-- exceptionally low leakage -->
      </DuctLeakage>
   </DuctLeakageMeasurement>

and the following will result in a "sealed" designation:

.. code-block:: xml
   :emphasize-lines: 3

   <DuctLeakageMeasurement>
      <DuctType>supply</DuctType>
      <LeakinessObservedVisualInspection>connections sealed w mastic</LeakinessObservedVisualInspection>
   </DuctLeakageMeasurement>
