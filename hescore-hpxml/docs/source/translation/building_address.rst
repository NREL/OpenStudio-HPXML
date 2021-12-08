Address and Requesting a New Session
####################################

.. contents:: Table of Contents

The first step in starting a HEScore transaction is to call the
``submit_address`` :term:`API` call.

Address
*******

The building address is found in HPXML under the ``Building/Site/Address``
element. The sub elements there easily translate into the expected address
format for HEScore. 

.. code-block:: xml

   <HPXML>
      ...
      <Building>
         <Site>
            <SiteID id="id1"/>
            <Address>
               <Address1>123 Main St.</Address1>
               <Address2></Address2>
               <CityMunicipality>Anywhere</CityMunicipality>
               <StateCode>CA</StateCode>
               <ZipCode>90000</ZipCode>
            </Address>
         </Site>      
      </Building>
   </HPXML>

HPXML allows for two lines of address elements. If both are used, the lines will
be concatenated with a space between for submission to the HEScore
``building_address.address`` field. All of the HPXML elements shown in the above
code snippet are required with the exception of ``Address2``. Additionally, if a
zip plus 4 code is entered in HPXML, it will be trimmed to just the 5 digit zip
code before being passed to HEScore.

.. _assessment-type-mapping:

Assessment Type
***************

To begin a HEScore session an assessment type must be selected. The assessment type
is determined from HPXML via the
``XMLTransactionHeaderInformation/Transaction`` and
``Building/ProjectStatus/EventType`` element using the following mapping: 

.. table:: Assessment Type mapping

   +---------------------+-------------------------------------------+------------------------+
   |XML Transaction Type |HPXML Event Type                           |HEScore Assessment Type |
   +=====================+===========================================+========================+
   |create               |audit                                      |initial                 |
   +                     +-------------------------------------------+------------------------+
   |                     |proposed workscope                         |alternative             |
   +                     +-------------------------------------------+------------------------+
   |                     |approved workscope                         |alternative             |
   +                     +-------------------------------------------+------------------------+
   |                     |construction-period testing/daily test out |test                    |
   +                     +-------------------------------------------+------------------------+
   |                     |job completion testing/final inspection    |final                   |
   +                     +-------------------------------------------+------------------------+
   |                     |quality assurance/monitoring               |qa                      |
   +                     +-------------------------------------------+------------------------+
   |                     |preconstruction                            |preconstruction         |
   +---------------------+-------------------------------------------+------------------------+
   |update               |*any*                                      |corrected               |
   +---------------------+-------------------------------------------+------------------------+

Mentor Assessment Type
======================

In v2015 HEScore introduced a new assessment type called "mentor".
It is used for new assessors in training when an assessment is supervised by a
more qualified assessor.
There is no equivalent way to communicate this scenario in HPXML.
To work around this issue, the translator will look for a specifically named
element in the ``extension`` of ``Building/ProjectStatus``:

.. code-block:: xml
    :emphasize-lines: 5

    <ProjectStatus>
        <EventType>audit</EventType>
        <Date>2014-12-18</Date>
        <extension>
            <HEScoreMentorAssessment/>
        </extension>
    </ProjectStatus>

Upon finding this ``HEScoreMentorAssessment`` element, the HEScore assessment
type will be set to "mentor" regardless of the mapping :ref:`above <assessment-type-mapping>`.

External Building ID
********************

The value of ``Building/extension/HESExternalID`` or
``Building/BuildingID/SendingSystemIdentifierValue``, if present, is copied into the
``building_address.external_building_id`` field in HEScore.
Preference is given to the `extension` element if both are present.
This is optional, but may be useful for those wanting to pass an additional building identifier for their own tracking purposes.
