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
   under slab                   vented_crawl
   basement                     uncond_basement, cond_space
   basement - unconditioned     uncond_basement
   basement - conditioned       cond_space
   crawlspace - unvented        unvented_crawl
   crawlspace - vented          vented_crawl
   crawlspace - unconditioned   vented_crawl, unvented_crawl
   crawlspace - conditioned     cond_space
   crawlspace                   vented_crawl, unvented_crawl, cond_space
   exterior wall                *not translated*
   attic                        uncond_attic, cond_space
   attic - unconditioned        uncond_attic
   attic - conditioned          cond_space
   attic - unvented             uncond_attic
   attic - vented               uncond_attic
   interstitial space           *not translated*
   garage                       vented_crawl
   garage - conditioned         cond_space
   garage - unconditioned       vented_crawl
   roof deck                    vented_crawl
   outside                      vented_crawl
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

Duct Leakage Measurements
*************************

Duct leakage measurements are associated with an ``AirDistribution`` element.
It can be specified qualitatively or quantatatively.

To qualitatively specify that an ``AirDistribution`` system is sealed, the
translator expects to find either of the following elements:

* ``DuctLeakageMeasurement/LeakinessObservedVisualInspection`` element with
  the value of "connections sealed w mastic".
* ``HVACDistribution/HVACDistributionImprovement/DuctSystemSealed`` element
  with the value of "true".

To quantitatively specify the duct leakage to outside in CFM25 of an ``AirDistribution`` system, 
the translator expects to find the following element:

* ``DuctLeakageMeasurement/DuctLeakage[TotalOrToOutside="to outside"]/Value`` element 
  with the numeric value

If neither of elements above is specified, it will result in an "unsealed" designation.
