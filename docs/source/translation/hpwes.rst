Home Performance with Energy Star
#################################

Inputs for the Home Energy Score `submit_hpwes`_ API call can be retrieved from
an HPXML file as described below.

.. _submit_hpwes: https://hes-documentation.labworks.org/home/api-definitions/api-methods/submit_hpwes

Identifying HPwES Projects
**************************

To trigger data collection for HPwES project, the following elements need to be
included depending on HPXML version used.

HPXML v2
--------

To translate the HPwES fields, the ``Project/ProgramCertificate`` must be
present and equal to ``Home Performance with Energy Star``. 

HPXML v3
--------

In HPXML v3.0+, ``ProgramCertificate`` no longer exists and a new element of
path
``Building/BuildingDetails/GreenBuildingVerifications/GreenBuildingVerification``
is used. Similarly, ``GreenBuildingVerification`` must be present as 
``Home Performance with ENERGY STAR``.

Project
*******

To get the Home Performance with Energy Star (HPwES) data
from an HPXML file a ``Project`` node needs to be included. 
The following elements are required under the ``Project`` node:

.. code-block:: xml

    <Project>
        <ProjectDetails>
            <ProjectSystemIdentifiers id="projectid"/>
            <!-- HPXML v2 only --><ProgramCertificate>Home Performance with Energy Star</ProgramCertificate>
            <StartDate>2018-08-20</StartDate>
            <CompleteDateActual>2018-12-14</CompleteDateActual>
        </projectDetails>
    </Project>

If more than one ``Project`` element exists, the first one will be used. The
user can override this by passing the ``--projectid`` argument to the translator
command line.

The project fields are mapped as follows:

+---------------------------------------+----------------------------------------------+
|       HPXML ``ProjectDetails``        |          `submit_hpwes`_ API value           |
+=======================================+==============================================+
| ``StartDate``                         | ``improvement_installation_start_date``      |
+---------------------------------------+----------------------------------------------+
| ``CompleteDateActual``                | ``improvement_installation_completion_date`` |
+---------------------------------------+----------------------------------------------+

Contractor
**********

A ``Contractor`` element is also required with at minimum the following
elements:

.. code:: xml

    <Contractor>
        <ContractorDetails>
            <SystemIdentifier id="contractor1"/>
            <BusinessInfo>
                <SystemIdentifier id="contractor1businessinfo"/>
                <BusinessName>My HPwES Contractor Business</BusinessName>
                <extension>
                    <ZipCode>12345</ZipCode>
                </extension>
            </BusinessInfo>
        </ContractorDetails>
    </Contractor>

If there are more than one ``Contractor`` elements, the contractor with the id
passed in the ``--contractorid`` command line argument is used. If no contracter
id is specified by the user, the contractor listed in the
``Building/ContractorID`` will be used. If that element isn't available, the
first ``Contractor`` element will be used.

The contractor fields are mapped as follows:

+------------------------------------------------------+------------------------------+
|                 HPXML ``Contractor``                 |  `submit_hpwes`_ API value   |
+======================================================+==============================+
| ``ContractorDetails/BusinessInfo/BusinessName``      | ``contractor_business_name`` |
+------------------------------------------------------+------------------------------+
| ``ContractorDetails/BusinessInfo/extension/ZipCode`` | ``contractor_zip_code``      |
+------------------------------------------------------+------------------------------+
