import io
from lxml import objectify, etree
import pathlib
import pytest
import tempfile
import re

from hescorehpxml import (
    HPXMLtoHEScoreTranslator,
    main
)

both_hescore_min = [
    'hescore_min_v3',
    'hescore_min'
]


def get_example_xml_tree_elementmaker(filebase):
    rootdir = pathlib.Path(__file__).resolve().parent.parent
    hpxmlfilename = str(rootdir / 'examples' / f'{filebase}.xml')
    tree = objectify.parse(hpxmlfilename)
    root = tree.getroot()
    ns = re.match(r'\{(.+)\}', root.tag).group(1)
    E = objectify.ElementMaker(
        annotate=False,
        namespace=ns
    )
    return tree, E


def scrub_hpxml_doc(doc):
    f_in = io.BytesIO()
    doc.write(f_in)
    f_in.seek(0)
    tr = HPXMLtoHEScoreTranslator(f_in)
    f_out = io.BytesIO()
    tr.export_scrubbed_hpxml(f_out)
    f_out.seek(0)
    scrubbed_doc = objectify.parse(f_out)
    return scrubbed_doc


@pytest.mark.parametrize('hpxml_filebase', both_hescore_min)
def test_remove_customer(hpxml_filebase):
    doc, E = get_example_xml_tree_elementmaker(hpxml_filebase)
    hpxml = doc.getroot()
    hpxml.Building.addprevious(
        E.Customer(
            E.CustomerDetails(
                E.Person(
                    E.SystemIdentifier(
                        E.SendingSystemIdentifierType('some other id'),
                        E.SendingSystemIdentifierValue('1234'),
                        id='customer1'
                    ),
                    E.Name(
                        E.FirstName('John'),
                        E.LastName('Doe')
                    ),
                    E.Telephone(
                        E.TelephoneNumber('555-555-5555')
                    )
                ),
                E.MailingAddress(
                    E.Address1('PO Box 1234'),
                    E.CityMunicipality('Anywhere'),
                    E.StateCode('CO')
                )
            )
        )
    )
    doc2 = scrub_hpxml_doc(doc)
    hpxml2 = doc2.getroot()
    assert len(hpxml2.Customer) == 1
    assert len(hpxml2.Customer.getchildren()) == 1
    assert len(hpxml2.Customer.CustomerDetails.getchildren()) == 1
    assert len(hpxml2.Customer.CustomerDetails.Person.getchildren()) == 1
    assert hpxml2.Customer.CustomerDetails.Person.SystemIdentifier.attrib['id'] == 'customer1'


@pytest.mark.parametrize('hpxml_filebase', both_hescore_min)
def test_remove_health_and_safety(hpxml_filebase):
    doc, E = get_example_xml_tree_elementmaker(hpxml_filebase)
    hpxml = doc.getroot()
    hpxml.Building.BuildingDetails.Systems.addnext(
        E.HealthAndSafety()
    )
    doc2 = scrub_hpxml_doc(doc)
    assert len(doc2.xpath('//h:HealthAndSafety', namespaces={'h': hpxml.nsmap[None]})) == 0


@pytest.mark.parametrize('hpxml_filebase', both_hescore_min)
def test_remove_occupancy(hpxml_filebase):
    doc, E = get_example_xml_tree_elementmaker(hpxml_filebase)
    hpxml = doc.getroot()
    hpxml.Building.BuildingDetails.BuildingSummary.Site.addnext(
        E.BuildingOccupancy(
            E.LowIncome('true')
        )
    )
    doc2 = scrub_hpxml_doc(doc)
    assert len(doc2.xpath('//h:BuildingOccupancy', namespaces={'h': hpxml.nsmap[None]})) == 0


@pytest.mark.parametrize('hpxml_filebase', both_hescore_min)
def test_remove_annual_energy_use(hpxml_filebase):
    doc, E = get_example_xml_tree_elementmaker(hpxml_filebase)
    hpxml = doc.getroot()
    energy_use_el = E.AnnualEnergyUse(
        E.ConsumptionInfo(
            E.UtilityID(
                id='utility01'
            ),
            E.ConsumptionType(
                E.Energy(
                    E.FuelType('electricity'),
                    E.UnitofMeasure('kWh')
                )
            ),
            E.ConsumptionDetail(
                E.Consumption('1.0')
            )
        )
    )
    hpxml.Building.BuildingDetails.BuildingSummary.BuildingConstruction.addnext(energy_use_el)
    hpxml.Building.BuildingDetails.Systems.HVAC.HVACPlant.CoolingSystem.CoolingSystemType.addprevious(energy_use_el)
    doc2 = scrub_hpxml_doc(doc)
    assert len(doc2.xpath('//h:AnnualEnergyUse', namespaces={'h': hpxml.nsmap[None]})) == 0


@pytest.mark.parametrize('hpxml_filebase', both_hescore_min)
def test_remove_utility(hpxml_filebase):
    doc, E = get_example_xml_tree_elementmaker(hpxml_filebase)
    hpxml = doc.getroot()
    hpxml.append(
        E.Utility(
            E.UtilitiesorFuelProviders(
                E.UtilityFuelProvider(
                    E.SystemIdentifier(id='utility01')
                )
            )
        )
    )
    doc2 = scrub_hpxml_doc(doc)
    assert len(doc2.xpath('h:Utility', namespaces={'h': hpxml.nsmap[None]})) == 0


@pytest.mark.parametrize('hpxml_filebase', both_hescore_min)
def test_remove_consumption(hpxml_filebase):
    doc, E = get_example_xml_tree_elementmaker(hpxml_filebase)
    hpxml = doc.getroot()
    hpxml.append(
        E.Consumption(
            E.BuildingID(id='bldg1'),
            E.CustomerID(id='customer1'),
            E.ConsumptionDetails(
                E.ConsumptionInfo(
                    E.UtilityID(
                        id='utility01'
                    ),
                    E.ConsumptionType(
                        E.Energy(
                            E.FuelType('electricity'),
                            E.UnitofMeasure('kWh')
                        )
                    ),
                    E.ConsumptionDetail(
                        E.Consumption('1.0')
                    )
                )
            )
        )
    )
    doc2 = scrub_hpxml_doc(doc)
    assert len(doc2.xpath('h:Consumption', namespaces={'h': hpxml.nsmap[None]})) == 0


@pytest.mark.parametrize('hpxml_filebase', both_hescore_min)
def test_remove_building_customerid(hpxml_filebase):
    doc, E = get_example_xml_tree_elementmaker(hpxml_filebase)
    hpxml = doc.getroot()
    hpxml.Building.BuildingID.addnext(
        E.CustomerID(
            E.SendingSystemIdentifierType('asdf'),
            E.SendingSystemIdentifierValue('jkl')
        )
    )
    doc2 = scrub_hpxml_doc(doc)
    assert len(doc2.xpath('h:Building/h:CustomerID', namespaces={'h': hpxml.nsmap[None]})) == 0


def test_cli_scrubbed():
    root_dir = pathlib.Path(__file__).resolve().parent.parent
    xml_file_path = root_dir / 'examples' / 'hescore_min_v3.xml'
    schema_path = pathlib.Path(root_dir, 'hescorehpxml', 'schemas', 'hpxml-3.0.0', 'HPXML.xsd')
    schema_doc = etree.parse(str(schema_path))
    schema = etree.XMLSchema(schema_doc.getroot())
    parser = etree.XMLParser(schema=schema)
    with tempfile.TemporaryDirectory() as tmpdir:

        # Export a scrubbed hpxml
        outfile = pathlib.Path(tmpdir, 'out.xml')
        main([str(xml_file_path), '--scrubbed-hpxml', str(outfile)])

        # Ensure it validates
        etree.parse(str(outfile), parser)

        # Remove a required element
        tree = etree.parse(str(xml_file_path), parser)
        root = tree.getroot()
        ns = {'h': 'http://hpxmlonline.com/2019/10'}
        el = root.xpath('//h:YearBuilt', namespaces=ns)[0]
        el.getparent().remove(el)
        infile2 = pathlib.Path(tmpdir, 'in2.xml')
        outfile2 = pathlib.Path(tmpdir, 'out2.xml')
        tree.write(str(infile2))

        # Export a scrubbed hpxml, the translation will fail
        with pytest.raises(SystemExit):
            main([str(infile2), '--scrubbed-hpxml', str(outfile2)])
        etree.parse(str(outfile2), parser)

        # Add an invalid element so schema validation fails
        tree = etree.parse(str(xml_file_path), parser)
        root = tree.getroot()
        etree.SubElement(root, 'boguselement')
        infile3 = pathlib.Path(tmpdir, 'in3.xml')
        outfile3 = pathlib.Path(tmpdir, 'out3.xml')
        tree.write(str(infile3))

        # Run export. Schema validation will fail, no file created.
        with pytest.raises(SystemExit):
            main([str(infile3), '--scrubbed-hpxml', str(outfile3)])
        assert not outfile3.exists()
