Usage Instructions
##################

The HPXML to Home Energy Score (HEScore) translator can be run hosted through the :ref:`HEScore API <hescoreapi>` or :ref:`directly on your local machine <stand-alone>`.
Most users will find that the HEScore API is the preferred method since it easily fits into the API workflow and automates the process.
The stand alone method is mostly for developers needing to debug and track down problems in the translation as well as for those who want to make modifications to the translation assumptions and code.

.. _hescoreapi:

Home Energy Score API
*********************

The HEScore API provides the most generally applicable way use HPXML to generate a Home Energy Score.
Generally in the API is used by doing the following steps, calling each API method in order:

#. ``submit_address`` - Creates a new building and assessment date.
#. ``submit_inputs`` - Submit a detailed house description in a format specific to Home Energy Score.
#. ``calculate_base_building`` - Calculates the energy use of the as-described building.
#. ``commit_results`` - Locks the inputs and marks them as being accurate by the Qualified Assessor.
#. ``calculate_package_building`` - Analyzes a set of retrofit upgrades that are screened against standardized costs, and determines the most cost effective ones.
#. ``generate_label`` - Creates a PDF and PNG Home Energy Score label.

There are other options and reports available, but that is the general gist of it.
The HPXML translator is made available through a separate API method: ``submit_hpxml_inputs``.
It replaces the first two steps above, alleviating the need to translate data elements from your data structure into the HEScore data structure.

``submit_hpxml_inputs`` accepts an HPXML file as a `Base64 <http://en.wikipedia.org/wiki/Base64>`_ encoded payload, so you will need to convert it.
An example of how to do this in Python is:

.. code:: python

    import base64

    with open('path/to/hpxmlfile.xml','r') as f:
        hpxml_as_base64 = base64.standard_b64encode(f.read())

Similar libraries and functionality exist in many languages.

Much more information on how to use the HEScore API including the ``submit_hpxml_inputs`` method is available on the `Home Energy Scoring Tool API Documentation site <http://hes-documentation.labworks.org/home>`_.

.. _stand-alone:

Stand Alone
***********

The HPXML to HEScore translator that is used within the :ref:`hescoreapi` can be used independently as well.
It is a Python script that accepts an HPXML file as input and returns a JSON file with HEScore inputs arranged like the HEScore API call ``submit_inputs`` expects.
It it useful to run it this way for debugging a translation of your particular flavor of HPXML file or for development of the translator.

Set Up
======

The program runs using `Python 2.7 <https://www.python.org/>`_. The instructions below will help you set up Python
on your platform and get the translator installed.

Windows
-------

#. `Download Python 2.7.x (not the 3.x version) from python.org <https://www.python.org/downloads/>`_ and Install.
#. Add ``C:\Python27`` to your path.
   `Here's how <http://superuser.com/questions/143119/how-to-add-python-to-the-windows-path>`_.
#. Follow instructions for :ref:`all_platforms_install_instructions`.

Mac OS X
--------

#. Install `Homebrew <http://brew.sh/>`_.
#. Open a terminal.
#. Install Python 2.7 using homebrew: ``brew install python``
#. Follow instructions for :ref:`all_platforms_install_instructions`.

Linux
-----

#. Install Python 2.7 using the package manager for your platform.
#. Follow instructions for :ref:`all_platforms_install_instructions`.

.. _all_platforms_install_instructions:

All Platforms
-------------

Optionally install and activate a virtual environment.
`Instructions here <http://docs.python-guide.org/en/latest/dev/virtualenvs/>`_.

Install the package using ``pip``::

    pip install hescore-hpxml

Alternatively, you can install the latest and greatest directly from GitHub, which is useful if you're going to do some development on the translator.
To do so, get a copy of the `source code from GitHub <https://github.com/NREL/hescore-hpxml>`_, using your preferred method.
If you're not sure, just click "Download ZIP".

Open a terminal and use ``pip`` to install it in developer mode::

    cd path/to/hescore-hpxml
    pip install -e .[dev]

Running the Translator
======================

The best way to figure out how to run the translator is to call it with the ``-h`` flag.

.. code::

    hpxml2hescore -h

