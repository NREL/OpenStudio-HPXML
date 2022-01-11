from future import standard_library
from builtins import map
from builtins import str
from builtins import object
import os
import unittest
import datetime as dt
from lxml import etree, objectify
from lxml.builder import ElementMaker
from hescorehpxml import HPXMLtoHEScoreTranslator, main
from hescorehpxml.exceptions import TranslationError, InputOutOfBounds, ElementNotFoundError
import io
import json
from copy import deepcopy
import uuid
import sys
import tempfile
import jsonschema
import re
standard_library.install_aliases()  # noqa: 402


thisdir = os.path.dirname(os.path.abspath(__file__))
exampledir = os.path.abspath(os.path.join(thisdir, '..', 'examples'))


class ComparatorBase(object):
    def _load_xmlfile(self, filebase):
        xmlfilepath = os.path.join(exampledir, filebase + '.xml')
        self.translator = HPXMLtoHEScoreTranslator(xmlfilepath)
        return self.translator

    def _compare_item(self, x, y, curpath=[]):
        if isinstance(x, dict):
            self.assertEqual(set(x.keys()), set(y.keys()), '{}: dict keys of not equal'.format('.'.join(curpath)))
            for k, xv in x.items():
                self._compare_item(xv, y[k], curpath + [k])
        elif isinstance(x, list):
            self.assertEqual(len(x), len(y), '{}: list lengths not equal'.format('.'.join(curpath)))
            if curpath[-1] == 'zone_wall':
                x.sort(key=lambda k: k.get('side'))
                y.sort(key=lambda k: k.get('side'))
            for i, (xitem, yitem) in enumerate(zip(x, y)):
                self._compare_item(xitem, yitem, curpath + [str(i)])
        elif isinstance(x, float):
            self.assertTrue(isinstance(y, float))
            self.assertAlmostEqual(x, y)
        else:
            self.assertEqual(x, y, '{}: item not equal'.format('.'.join(curpath)))

    def _do_compare(self, filebase, jsonfilebase=None):
        if not jsonfilebase:
            jsonfilebase = filebase
        hescore_trans = self.translator.hpxml_to_hescore()
        jsonfilepath = os.path.join(exampledir, jsonfilebase + '.json')
        with open(os.path.join(exampledir, jsonfilepath)) as f:
            hescore_truth = json.load(f)
        self._compare_item(hescore_trans, hescore_truth)

    def _do_full_compare(self, filebase, jsonfilebase=None):
        self._load_xmlfile(filebase)
        self._do_compare(filebase, jsonfilebase)

    def _write_xml_file(self, filename):
        self.translator.hpxmldoc.write(os.path.join(exampledir, filename))

    def xpath(self, xpathexpr, *args, **kwargs):
        return self.translator.xpath(self.translator.hpxmldoc, xpathexpr, *args, **kwargs)

    def element_maker(self):
        E = ElementMaker(
            namespace=self.translator.ns['h'],
            nsmap=self.translator.ns
        )
        return E


class TestAPIHouses(unittest.TestCase, ComparatorBase):
    def test_house1(self):
        self._do_full_compare('house1')

    def test_house1_v2(self):
        self._do_full_compare('house1-v2', 'house1')

    def test_house1_v2_1(self):
        self._do_full_compare('house1-v2-1', 'house1')

    def test_house2(self):
        self._do_full_compare('house2')

    def test_house3(self):
        self._do_full_compare('house3')

    def test_house4(self):
        self._do_full_compare('house4')

    def test_house5(self):
        self._do_full_compare('house5')

    def test_house6(self):
        self._do_full_compare('house6')

    def test_house7(self):
        self._do_full_compare('house7')

    def test_house8(self):
        self._do_full_compare('house8')

    def test_assembly_rvalue(self):
        self._do_full_compare('hescore_min_assembly_rvalue')


class TestCLI(unittest.TestCase, ComparatorBase):

    def test_cli_pass(self):
        xml_file_path = os.path.abspath(os.path.join(thisdir, '..', 'examples', 'hescore_min.xml'))
        with tempfile.TemporaryDirectory() as tmpdir:
            outfile = os.path.join(tmpdir, 'hescore_min.json')
            main([xml_file_path, '-o', outfile])
            with open(outfile, 'r') as f:
                d1 = json.load(f)
            with open(xml_file_path.replace('.xml', '.json'), 'r') as f:
                d2 = json.load(f)
            self._compare_item(d1, d2)


class TestOtherHouses(unittest.TestCase, ComparatorBase):
    def test_hescore_min(self):
        self._do_full_compare('hescore_min')

    def test_townhouse_walls(self):
        self._do_full_compare('townhouse_walls')

    def test_townhouse_window_fail(self):
        tr = self._load_xmlfile('townhouse_walls')
        el = self.xpath('//h:Window/h:Orientation[text()="south"]')
        el.text = 'west'
        self.assertRaisesRegex(TranslationError,
                               r'The house has windows on shared walls\.',
                               tr.hpxml_to_hescore)

    def test_townhouse_walls_all_same(self):
        tr = self._load_xmlfile('townhouse_walls')
        # Remove other walls
        for el in self.xpath('//h:Wall[h:SystemIdentifier/@id!="wall1"]'):
            el.getparent().remove(el)
        # Remove the orientation of the first one
        wall1_orientation = self.xpath('//h:Wall[h:SystemIdentifier/@id="wall1"]/h:Orientation')
        wall1_orientation.getparent().remove(wall1_orientation)
        # This means that the interpreter should assume all walls are like the first wall.
        d = tr.hpxml_to_hescore()
        # Check to make sure we're not getting any walls facing directions that are attached to adjacent to other units.
        for wall in d['building']['zone']['zone_wall']:
            self.assertIn(wall['side'], ['front', 'back', 'left'])

    def test_townhouse_window_wall_all_same_fail(self):
        tr = self._load_xmlfile('townhouse_walls')
        # Remove other walls
        for el in self.xpath('//h:Wall[h:SystemIdentifier/@id!="wall1"]'):
            el.getparent().remove(el)
        # Remove the orientation of the first one
        wall1_orientation = self.xpath('//h:Wall[h:SystemIdentifier/@id="wall1"]/h:Orientation')
        wall1_orientation.getparent().remove(wall1_orientation)
        # This means that the interpreter should assume all walls are like the first wall.
        el = self.xpath('//h:Window/h:Orientation[text()="south"]')
        el.text = 'west'
        self.assertRaisesRegex(TranslationError,
                               r'The house has windows on shared walls\.',
                               tr.hpxml_to_hescore)

    def test_townhouse_walls_conflict(self):
        tr = self._load_xmlfile('townhouse_walls')
        # move a wall to the west (attached) side
        el = self.xpath('//h:Wall[1]/h:Orientation')
        el.text = 'west'
        self.assertRaisesRegex(
            TranslationError,
            r'The house has walls defined for sides ((front|right|left|back)(, )?)+ and shared walls on sides ((front|right|left|back)(, )?)+',  # noqa: E501
            tr.hpxml_to_hescore
        )

    def test_townhouse_windows_area_wrong(self):
        tr = self._load_xmlfile('townhouse_walls')
        el = self.xpath('//h:OrientationOfFrontOfHome')
        el.text = 'west'
        for wall in self.xpath('//h:Wall/h:Orientation'):
            if wall.text == 'north':
                wall.text = 'west'
        for i, window in enumerate(self.xpath('//h:Window')):
            if i == 0:
                window.xpath('h:Area', namespaces=tr.ns)[0].text = '20'
                window.xpath('h:Orientation', namespaces=tr.ns)[0].text = 'west'
            elif i == 1:
                window.xpath('h:Area', namespaces=tr.ns)[0].text = '4'
                window.xpath('h:Orientation', namespaces=tr.ns)[0].text = 'south'
            else:
                window.getparent().remove(window)
        hesd = tr.hpxml_to_hescore()
        walls_found = set()
        for wall in hesd['building']['zone']['zone_wall']:
            walls_found.add(wall['side'])
            if wall['side'] == 'front':
                self.assertEqual(wall['zone_window']['window_area'], 20)
            elif wall['side'] == 'right':
                self.assertEqual(wall['zone_window']['window_area'], 4)
            elif wall['side'] == 'back':
                self.assertEqual(wall['zone_window']['window_area'], 0)
        self.assertEqual(set(['front', 'right', 'back']), walls_found)

    def test_missing_siding(self):
        tr = self._load_xmlfile('hescore_min')
        siding = self.xpath('//h:Wall[1]/h:Siding')
        siding.getparent().remove(siding)
        self.assertRaisesRegex(TranslationError,
                               r'Exterior finish information is missing',
                               tr.hpxml_to_hescore)
        tr_v3 = self._load_xmlfile('hescore_min_v3')
        siding = self.xpath('//h:Wall[1]/h:Siding')
        siding.getparent().remove(siding)
        self.assertRaisesRegex(TranslationError,
                               r'Exterior finish information is missing',
                               tr_v3.hpxml_to_hescore)

    def test_siding_fail2(self):
        tr = self._load_xmlfile('hescore_min')
        siding = self.xpath('//h:Wall[1]/h:Siding')
        siding.text = 'other'
        self.assertRaisesRegex(TranslationError,
                               r'There is no HEScore wall siding equivalent for the HPXML option: other',
                               tr.hpxml_to_hescore)
        tr_v3 = self._load_xmlfile('hescore_min_v3')
        siding = self.xpath('//h:Wall[1]/h:Siding')
        siding.text = 'other'
        self.assertRaisesRegex(TranslationError,
                               r'There is no HEScore wall siding equivalent for the HPXML option: other',
                               tr_v3.hpxml_to_hescore)

    def test_siding_cmu_fail(self):
        tr = self._load_xmlfile('hescore_min')
        walltype = self.xpath('//h:Wall[1]/h:WallType')
        walltype.clear()
        etree.SubElement(walltype, tr.addns('h:ConcreteMasonryUnit'))
        siding = self.xpath('//h:Wall[1]/h:Siding')
        siding.text = 'vinyl siding'
        rvalue = self.xpath('//h:Wall[1]/h:Insulation/h:Layer[1]/h:NominalRValue')
        rvalue.text = '3'
        self.assertRaisesRegex(
            TranslationError,
            r'is a CMU and needs a siding of stucco, brick, or none to translate to HEScore. It has a siding type of vinyl siding',  # noqa: E501
            tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        walltype = self.xpath('//h:Wall[1]/h:WallType')
        walltype.clear()
        etree.SubElement(walltype, tr_v3.addns('h:ConcreteMasonryUnit'))
        siding = self.xpath('//h:Wall[1]/h:Siding')
        siding.text = 'vinyl siding'
        rvalue = self.xpath('//h:Wall[1]/h:Insulation/h:Layer[1]/h:NominalRValue')
        rvalue.text = '3'
        self.assertRaisesRegex(
            TranslationError,
            r'is a CMU and needs a siding of stucco, brick, or none to translate to HEScore. It has a siding type of vinyl siding',  # noqa: E501
            tr_v3.hpxml_to_hescore)

    def test_log_wall_fail(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:Wall[1]/h:WallType')
        el.clear()
        etree.SubElement(el, tr.addns('h:LogWall'))
        self.assertRaisesRegex(TranslationError,
                               r'Wall type LogWall not supported',
                               tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:Wall[1]/h:WallType')
        el.clear()
        etree.SubElement(el, tr_v3.addns('h:LogWall'))
        self.assertRaisesRegex(TranslationError,
                               r'Wall type LogWall not supported',
                               tr_v3.hpxml_to_hescore)

    def test_missing_residential_facility_type(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:ResidentialFacilityType')
        el.getparent().remove(el)
        self.assertRaisesRegex(TranslationError,
                               r'ResidentialFacilityType is required in the HPXML document',
                               tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:ResidentialFacilityType')
        el.getparent().remove(el)
        self.assertRaisesRegex(TranslationError,
                               r'ResidentialFacilityType is required in the HPXML document',
                               tr_v3.hpxml_to_hescore)

    def test_invalid_residential_faciliy_type(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:ResidentialFacilityType')
        el.text = 'manufactured home'
        self.assertRaisesRegex(TranslationError,
                               r'Cannot translate HPXML ResidentialFacilityType of .+ into HEScore building shape',
                               tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:ResidentialFacilityType')
        el.text = 'manufactured home'
        self.assertRaisesRegex(TranslationError,
                               r'Cannot translate HPXML ResidentialFacilityType of .+ into HEScore building shape',
                               tr_v3.hpxml_to_hescore)

    def test_missing_surroundings(self):
        tr = self._load_xmlfile('townhouse_walls')
        el = self.xpath('//h:Surroundings')
        el.getparent().remove(el)
        self.assertRaisesRegex(TranslationError,
                               r'Site/Surroundings element is required in the HPXML document for town houses',
                               tr.hpxml_to_hescore)

    def test_invalid_surroundings(self):
        tr = self._load_xmlfile('townhouse_walls')
        el = self.xpath('//h:Surroundings')
        el.text = 'attached on three sides'
        self.assertRaisesRegex(
            TranslationError,
            r'Cannot translate HPXML Site/Surroundings element value of .+ into HEScore town_house_walls',
            tr.hpxml_to_hescore)

    def test_attic_roof_assoc(self):
        tr = self._load_xmlfile('house6')
        el = self.xpath('//h:Attic[1]/h:AttachedToRoof')
        el.getparent().remove(el)
        self.assertRaisesRegex(TranslationError,
                               r'Attic .+ does not have a roof associated with it\.',
                               tr.hpxml_to_hescore)

    def test_invalid_attic_type(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:Attic[1]/h:AtticType')
        el.text = 'other'
        self.assertRaisesRegex(TranslationError,
                               'Attic .+ Cannot translate HPXML AtticType .+ to HEScore rooftype.',
                               tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:Attics/h:Attic[1]/h:AtticType/h:Attic/h:Vented')
        attic_type_el = el.getparent().getparent()
        etree.SubElement(attic_type_el, tr_v3.addns('h:Other'))
        attic_type_el.remove(el.getparent())
        self.assertRaisesRegex(TranslationError,
                               'Attic .+ Cannot translate HPXML AtticType to HEScore rooftype.',
                               tr_v3.hpxml_to_hescore)

    def test_missing_roof_color(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:Roof[1]/h:RoofColor')
        el.getparent().remove(el)
        self.assertRaises(ElementNotFoundError,
                          tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:Roof[1]/h:RoofColor')
        el.getparent().remove(el)
        self.assertRaises(ElementNotFoundError,
                          tr_v3.hpxml_to_hescore)

    def test_invalid_roof_type(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:Roof[1]/h:RoofType')
        el.text = 'no one major type'
        self.assertRaisesRegex(TranslationError,
                               'Attic .+ HEScore does not have an analogy to the HPXML roof type: .+',
                               tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:Roof[1]/h:RoofType')
        el.text = 'no one major type'
        self.assertRaisesRegex(TranslationError,
                               'Attic .+ HEScore does not have an analogy to the HPXML roof type: .+',
                               tr_v3.hpxml_to_hescore)

    def test_missing_roof_type(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:Roof[1]/h:RoofType')
        el.getparent().remove(el)
        self.assertRaisesRegex(TranslationError,
                               'Attic .+ HEScore does not have an analogy to the HPXML roof type: .+',
                               tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:Roof[1]/h:RoofType')
        el.getparent().remove(el)
        self.assertRaisesRegex(TranslationError,
                               'Attic .+ HEScore does not have an analogy to the HPXML roof type: .+',
                               tr_v3.hpxml_to_hescore)

    def test_missing_skylight_area(self):
        tr = self._load_xmlfile('hescore_min')
        area = self.xpath('//h:Skylight[1]/h:Area')
        area.getparent().remove(area)
        self.assertRaisesRegex(TranslationError,
                               r'Every skylight needs an area\.',
                               tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        area = self.xpath('//h:Skylight[1]/h:Area')
        area.getparent().remove(area)
        self.assertRaisesRegex(TranslationError,
                               r'Every skylight needs an area\.',
                               tr_v3.hpxml_to_hescore)

    def test_foundation_walls_on_slab(self):
        tr = self._load_xmlfile('house7')
        fnd = self.xpath('//h:Foundation[name(h:FoundationType/*) = "SlabOnGrade"]')
        for i, el in enumerate(fnd):
            if el.tag.endswith('Slab'):
                break
        fndwall = etree.Element(tr.addns('h:FoundationWall'))
        etree.SubElement(fndwall, tr.addns('h:SystemIdentifier'), attrib={'id': 'asdfjkl12345'})
        fnd.insert(i, fndwall)
        self.assertRaisesRegex(TranslationError,
                               r'The house is a slab on grade foundation, but has foundation walls\.',
                               tr.hpxml_to_hescore)

    def test_slab_missing(self):
        tr = self._load_xmlfile('house3')
        el = self.xpath('//h:Slab')
        el.getparent().remove(el)
        self.assertRaises(
            ElementNotFoundError,
            tr.hpxml_to_hescore
        )

    def test_missing_window_area(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:Window[1]/h:Area')
        el.getparent().remove(el)
        self.assertRaises(ElementNotFoundError,
                          tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:Window[1]/h:Area')
        el.getparent().remove(el)
        self.assertRaises(ElementNotFoundError,
                          tr_v3.hpxml_to_hescore)

    def test_missing_window_orientation(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:Window[1]/h:Orientation')
        el.getparent().remove(el)
        self.assertRaisesRegex(
            TranslationError,
            r'Window\[SystemIdentifier/@id="\w+"\] doesn\'t have Azimuth, Orientation, or AttachedToWall. At least one is required.',  # noqa E501
            tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:Window[1]/h:Orientation')
        el.getparent().remove(el)
        self.assertRaisesRegex(
            TranslationError,
            r'Window\[SystemIdentifier/@id="\w+"\] doesn\'t have Azimuth, Orientation, or AttachedToWall. At least one is required.',  # noqa E501
            tr_v3.hpxml_to_hescore)

    def test_window_only_attached_to_foundation_wall(self):
        tr = self._load_xmlfile('house4')
        window_orientation = self.xpath('//h:Window[1]/h:Orientation')
        window = window_orientation.getparent()
        etree.SubElement(window, tr.addns('h:AttachedToWall'), attrib={'idref': 'crawlwall'})
        self._do_compare('house4')

        window.remove(window_orientation)
        self.assertRaisesRegex(
            TranslationError,
            r'The Window\[SystemIdentifier/@id="\w+"\] has no Azimuth or Orientation, and the .* didn\'t reference a Wall element.',  # noqa E501
            tr.hpxml_to_hescore
        )

    def test_window_attached_to_wall(self):
        filebase = 'house6'
        tr = self._load_xmlfile(filebase)
        # Get the first wall id
        wallid = self.xpath('//h:Wall[1]/h:Orientation/parent::node()/h:SystemIdentifier/@id')
        # get the orientation of the wall
        orientation = self.xpath('//h:Wall[h:SystemIdentifier/@id=$wallid]/h:Orientation/text()', wallid=wallid)
        # get the window orientation element of a window that is facing the same direction as the wall
        window_orientation = self.xpath('//h:Window[h:Orientation=$orientation][1]/h:Orientation',
                                        orientation=orientation)
        # remove the window orientation
        window = window_orientation.getparent()
        window.remove(window_orientation)
        # attach that window to the wall
        etree.SubElement(window, tr.addns('h:AttachedToWall'), attrib={'idref': wallid})
        self._do_compare(filebase)

    def test_impossible_window(self):
        tr = self._load_xmlfile('house1')
        el = self.xpath('//h:Window[h:GlassLayers="single-pane"]/h:FrameType/h:Aluminum')
        etree.SubElement(el, tr.addns('h:ThermalBreak')).text = "true"
        self.assertRaisesRegex(TranslationError,
                               'There is no compatible HEScore window type for',
                               tr.hpxml_to_hescore)

    def test_impossible_triple_pane_window(self):
        tr = self._load_xmlfile('hescore_min')
        frame_type = self.xpath('//h:Window[h:SystemIdentifier/@id="window4"]/h:FrameType')
        frame_type.clear()
        etree.SubElement(frame_type, tr.addns('h:Aluminum'))
        window = frame_type.getparent()
        glass_layers = self.xpath('//h:Window[h:SystemIdentifier/@id="window4"]/h:GlassLayers')
        glass_layers.text = 'triple-pane'
        etree.SubElement(window, tr.addns('h:GlassType')).text = 'low-e'
        etree.SubElement(window, tr.addns('h:GasFill')).text = 'argon'
        self.assertRaisesRegex(TranslationError,
                               'There is no compatible HEScore window type for',
                               tr.hpxml_to_hescore)
        tr_v3 = self._load_xmlfile('hescore_min_v3')
        frame_type = self.xpath('//h:Window[h:SystemIdentifier/@id="window4"]/h:FrameType')
        frame_type.clear()
        etree.SubElement(frame_type, tr_v3.addns('h:Aluminum'))
        window = frame_type.getparent()
        glass_layers = self.xpath('//h:Window[h:SystemIdentifier/@id="window4"]/h:GlassLayers')
        glass_layers.text = 'triple-pane'
        etree.SubElement(window, tr_v3.addns('h:GlassType')).text = 'low-e'
        etree.SubElement(window, tr_v3.addns('h:GasFill')).text = 'argon'
        self.assertRaisesRegex(TranslationError,
                               'There is no compatible HEScore window type for',
                               tr_v3.hpxml_to_hescore)

    def test_impossible_heating_system_type(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:HeatingSystem[1]/h:HeatingSystemType')
        el.clear()
        etree.SubElement(el, tr.addns('h:PortableHeater'))
        self.assertRaisesRegex(TranslationError,
                               'HEScore does not support the HPXML HeatingSystemType',
                               tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:HeatingSystem[1]/h:HeatingSystemType')
        el.clear()
        etree.SubElement(el, tr_v3.addns('h:PortableHeater'))
        self.assertRaisesRegex(TranslationError,
                               'HEScore does not support the HPXML HeatingSystemType',
                               tr_v3.hpxml_to_hescore)

    def test_impossible_cooling_system_type(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:CoolingSystem[1]/h:CoolingSystemType')
        el.text = 'other'
        self.assertRaisesRegex(TranslationError,
                               'HEScore does not support the HPXML CoolingSystemType',
                               tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:CoolingSystem[1]/h:CoolingSystemType')
        el.text = 'other'
        self.assertRaisesRegex(TranslationError,
                               'HEScore does not support the HPXML CoolingSystemType',
                               tr_v3.hpxml_to_hescore)

    def test_evap_cooling_system_type(self):
        tr = self._load_xmlfile('hescore_min')
        clgsystype = self.xpath('//h:CoolingSystem[1]/h:CoolingSystemType')
        clgsystype.text = 'evaporative cooler'
        clgsystype.getparent().remove(
            self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]/h:DistributionSystem'))
        for el in self.xpath('//h:CoolingSystem[1]/h:AnnualCoolingEfficiency', aslist=True):
            el.getparent().remove(el)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['cooling']['type'], 'dec')
        self.assertNotIn('efficiency_method', res['building']['systems']['hvac'][0]['cooling'])
        self.assertNotIn('efficiency', res['building']['systems']['hvac'][0]['cooling'])

        tr_v3 = self._load_xmlfile('hescore_min')
        clgsystype = self.xpath('//h:CoolingSystem[1]/h:CoolingSystemType')
        clgsystype.text = 'evaporative cooler'
        clgsystype.getparent().remove(
            self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]/h:DistributionSystem'))
        for el in self.xpath('//h:CoolingSystem[1]/h:AnnualCoolingEfficiency', aslist=True):
            el.getparent().remove(el)
        res_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['cooling'],
                         res_v3['building']['systems']['hvac'][0]['cooling'])

    def test_missing_heating_weighting_factor(self):
        tr = self._load_xmlfile('house4')
        el = self.xpath('//h:HeatingSystem[1]/h:HeatingCapacity')
        el.getparent().remove(el)
        el = self.xpath('//h:HeatPump[1]/h:FloorAreaServed')
        el.getparent().remove(el)
        self.assertRaisesRegex(TranslationError,
                                'Every heating/cooling system needs to have either FloorAreaServed or FracHeatLoadServed/FracCoolLoadServed',  # noqa E501
                                tr.hpxml_to_hescore)

    def test_missing_cooling_weighting_factor(self):
        tr = self._load_xmlfile('house5')
        el = self.xpath('//h:CoolingSystem[1]/h:CoolingCapacity')
        el.getparent().remove(el)
        el = self.xpath('//h:CoolingSystem[2]/h:FloorAreaServed')
        el.getparent().remove(el)
        self.assertRaisesRegex(TranslationError,
                                'Every heating/cooling system needs to have either FloorAreaServed or FracHeatLoadServed/FracCoolLoadServed',  # noqa E501
                                tr.hpxml_to_hescore)

    def test_bad_duct_location(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:DuctLocation[1]')
        el.text = 'unconditioned basement'
        self.assertRaisesRegex(TranslationError,
                               'HVAC distribution: duct1 location: uncond_basement not exists in zone_roof/floor',
                               tr.hpxml_to_hescore)

        el.text = 'interstitial space'
        self.assertRaisesRegex(TranslationError,
                               'No comparable duct location in HEScore: interstitial space',
                               tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:DuctLocation[1]')
        el.text = 'basement - unconditioned'
        self.assertRaisesRegex(TranslationError,
                               'HVAC distribution: duct1 location: uncond_basement not exists in zone_roof/floor',
                               tr_v3.hpxml_to_hescore)

        el.text = 'interstitial space'
        self.assertRaisesRegex(TranslationError,
                               'No comparable duct location in HEScore: interstitial space',
                               tr_v3.hpxml_to_hescore)

    def test_missing_water_heater(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:WaterHeating')
        el.getparent().remove(el)
        self.assertRaisesRegex(TranslationError,
                               r'No water heating systems found\.',
                               tr.hpxml_to_hescore)

    def test_indirect_dhw_error(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:WaterHeatingSystem[1]/h:WaterHeaterType')
        el.text = 'space-heating boiler with storage tank'
        self.assertRaisesRegex(TranslationError,
                               'Cannot have water heater type indirect if there is no boiler heating system',
                               tr.hpxml_to_hescore)

    def test_tankless_coil_dhw_error(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:WaterHeatingSystem[1]/h:WaterHeaterType')
        el.text = 'space-heating boiler with tankless coil'
        self.assertRaisesRegex(TranslationError,
                               'Cannot have water heater type tankless_coil if there is no boiler heating system',
                               tr.hpxml_to_hescore)

    def test_missing_attached_to_roof(self):
        self._load_xmlfile('hescore_min')
        el = self.xpath('//h:AttachedToRoof')
        el.getparent().remove(el)
        self._do_compare('hescore_min')

    def _wood_stove_setup(self):
        tr = self._load_xmlfile('hescore_min')
        htgsys = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="furnace1"]')
        htgsys.remove(htgsys.find(tr.addns('h:DistributionSystem')))
        htgsystype = htgsys.find(tr.addns('h:HeatingSystemType'))
        htgsystype.clear()
        etree.SubElement(htgsystype, tr.addns('h:Stove'))
        htgsys.find(tr.addns('h:HeatingSystemFuel')).text = 'wood'
        htgsys.remove(htgsys.find(tr.addns('h:AnnualHeatingEfficiency')))
        return htgsys

    def test_wood_stove(self):
        self._wood_stove_setup()
        result_dict = self.translator.hpxml_to_hescore()
        htg_sys = result_dict['building']['systems']['hvac'][0]['heating']
        self.assertEqual(htg_sys['type'], 'wood_stove')
        self.assertEqual(htg_sys['fuel_primary'], 'cord_wood')

    def test_wood_stove_invalid_fuel_type(self):
        htgsys = self._wood_stove_setup()
        htgsys.find(self.translator.addns('h:HeatingSystemFuel')).text = 'natural gas'
        self.assertRaisesRegex(TranslationError,
                               r'Heating system wood_stove cannot be used with fuel natural_gas',
                               self.translator.hpxml_to_hescore)

    def test_too_many_duct_systems(self):
        tr = self._load_xmlfile('house5')
        dist_sys_el = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="backfurnace"]/h:DistributionSystem')
        htg_sys = dist_sys_el.getparent()
        idx = htg_sys.index(dist_sys_el)
        htg_sys.insert(idx, etree.Element(tr.addns('h:DistributionSystem'), idref='frontducts'))
        self.assertRaisesRegex(
            TranslationError,
            r'Each HVAC plant is only allowed to specify one duct system\. .+ references more than one',
            tr.hpxml_to_hescore)

    def test_only_duct_system_per_heating_sys(self):
        tr = self._load_xmlfile('house5')
        dist_sys_el = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="backfurnace"]/h:DistributionSystem')
        dist_sys_el.set('idref', 'frontducts')
        self.assertRaisesRegex(TranslationError,
                               r'Each duct system is only allowed to serve one heating and one cooling system',
                               tr.hpxml_to_hescore)

    def test_dist_sys_idref(self):
        tr = self._load_xmlfile('house5')
        dist_sys_el = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="backfurnace"]/h:DistributionSystem')
        dist_sys_el.set('idref', 'backwindows1')
        self.assertRaisesRegex(TranslationError,
                               r'HVAC plant .+ specifies an HPXML distribution system of .+, which does not exist.',
                               tr.hpxml_to_hescore)

    def test_htg_sys_has_air_dist(self):
        tr = self._load_xmlfile('hescore_min')
        dist_sys_el = self.xpath('//h:HeatingSystem[1]/h:DistributionSystem')
        dist_sys_el.getparent().remove(dist_sys_el)
        self.assertRaisesRegex(TranslationError,
                               r'Heating system .+ is not associated with an air distribution system\.',
                               tr.hpxml_to_hescore)

    def test_clg_sys_has_air_dist(self):
        tr = self._load_xmlfile('hescore_min')
        dist_sys_el = self.xpath('//h:CoolingSystem[1]/h:DistributionSystem')
        dist_sys_el.getparent().remove(dist_sys_el)
        self.assertRaisesRegex(TranslationError,
                               r'Cooling system .+ is not associated with an air distribution system\.',
                               tr.hpxml_to_hescore)

    def test_floor_no_area(self):
        tr = self._load_xmlfile('house8')
        el = self.xpath('//h:Foundation[1]/*/h:Area')
        el.getparent().remove(el)
        self.assertRaisesRegex(
            TranslationError,
            r'If there is more than one foundation, each needs an area specified on either "Slab" or "FrameFloor" '
            r'attached',
            tr.hpxml_to_hescore)

    def test_bldgid_not_found(self):
        tr = self._load_xmlfile('house1')
        self.assertRaises(
            ElementNotFoundError,
            tr.hpxml_to_hescore,
            hpxml_bldg_id='bldgnothere'
        )

    def test_missing_cooling_system(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]')
        el.getparent().remove(el)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['cooling']['type'], 'none')

    def test_missing_heating_system(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="furnace1"]')
        el.getparent().remove(el)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['heating']['type'], 'none')

    def test_wall_same_area_same_side_different_construction(self):
        '''
        Unit test for #37
        '''
        tr = self._load_xmlfile('house6')
        el = self.xpath('//h:Wall[h:SystemIdentifier/@id="wallleft2"]/h:Area')
        el.text = '240'  # making it the same area as wallleft1
        tr.hpxml_to_hescore()

    def test_cooling_system_wrong_efficiency_type(self):
        '''
        Unit test for #39
        '''
        tr = self._load_xmlfile('house7')
        el = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="roomac"]/h:AnnualCoolingEfficiency/h:Units')
        el.text = 'SEER'
        self.assertRaisesRegex(
            TranslationError,
            r'Cooling efficiency could not be determined',
            tr.hpxml_to_hescore
            )

    def test_heating_system_wrong_efficiency_type(self):
        '''
        Another unit test for #39
        '''
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:HeatingSystem/h:AnnualHeatingEfficiency/h:Units')
        el.text = 'Percent'
        self.assertRaisesRegex(
            TranslationError,
            r'Heating efficiency could not be determined',
            tr.hpxml_to_hescore
            )

    def test_hvac_fractions_sum_to_one(self):
        tr = self._load_xmlfile('house6')
        el = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="furnace"]')
        el.remove(el[-1])
        etree.SubElement(el, tr.addns('h:FractionHeatLoadServed')).text = '0.94'
        el = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="baseboard"]')
        el.remove(el[-1])
        etree.SubElement(el, tr.addns('h:FractionHeatLoadServed')).text = '0.06'
        el = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair"]')
        el.getparent().remove(el)
        if sys.version_info[0] == 3:
            f = io.StringIO()
        else:
            f = io.BytesIO()
        tr.hpxml_to_hescore_json(f)
        f.seek(0)
        hesinp = json.load(f)
        self.assertEqual(sum([x['hvac_fraction'] for x in hesinp['building']['systems']['hvac']]), 1)

    def test_extra_roof_sheathing_insulation(self):
        '''
        Unit test for #44
        '''
        tr = self._load_xmlfile('house3')
        attic = self.xpath('//h:Attic[h:SystemIdentifier/@id="attic1"]/h:AtticRoofInsulation')
        lyr = etree.SubElement(attic, tr.addns('h:Layer'))
        etree.SubElement(lyr, tr.addns('h:InstallationType')).text = 'continuous'
        insmat = etree.SubElement(lyr, tr.addns('h:InsulationMaterial'))
        etree.SubElement(insmat, tr.addns('h:Rigid')).text = 'xps'
        etree.SubElement(lyr, tr.addns('h:NominalRValue')).text = '20'
        hesinp = tr.hpxml_to_hescore()
        self.assertEqual(hesinp['building']['zone']['zone_roof'][0]['roof_assembly_code'], 'rfps21rc')

    def test_extra_wall_sheathing_insulation(self):
        '''
        Unit test for #44
        '''
        tr = self._load_xmlfile('house3')
        el = self.xpath(
            '//h:Wall[h:SystemIdentifier/@id="wall1"]/h:Insulation/h:Layer[h:InstallationType="continuous"]/h:NominalRValue'  # noqa: E501
        )
        el.text = '15'
        hesinp = tr.hpxml_to_hescore()
        self.assertEqual(hesinp['building']['zone']['zone_wall'][0]['wall_assembly_code'], 'ewps21al')

    def test_wall_insulation_layer_missing_rvalue(self):
        tr = self._load_xmlfile('house3')
        el = self.xpath('//h:Wall[1]/h:Insulation/h:Layer[1]/h:NominalRValue')
        el.getparent().remove(el)
        self.assertRaisesRegex(
            TranslationError,
            r'Every wall insulation layer needs a NominalRValue',
            tr.hpxml_to_hescore
            )

    def test_attic_knee_wall(self):
        """
        Unit test for #48
        """
        tr = self._load_xmlfile('hescore_min')
        wall1 = self.xpath('//h:Wall[1]')
        E = self.element_maker()
        # new knee wall
        wall2 = E.Wall(
            E.SystemIdentifier(id='wall2'),
            E.ExteriorAdjacentTo('attic'),
            E.WallType(E.WoodStud()),
            E.Area('200'),
            E.Insulation(
                E.SystemIdentifier(id='wall2ins'),
                E.Layer(
                    E.InstallationType('cavity'),
                    E.NominalRValue('11')
                )
            )
        )
        wall1.addnext(wall2)
        # Reference wall in Attic
        attic_type = self.xpath('//h:Attic/h:AtticType')
        attic_type.addprevious(etree.Element(tr.addns('h:AtticKneeWall'), {'idref': 'wall2'}))
        # run translation
        resp = tr.hpxml_to_hescore()
        self.assertEqual(resp['building']['zone']['zone_roof'][0]['ceiling_assembly_code'], 'ecwf49')
        self.assertAlmostEqual(resp['building']['zone']['zone_roof'][0]['roof_area'], 1200.0)

        # HPXML v3
        tr_v3 = self._load_xmlfile('hescore_min_v3')
        wall1 = self.xpath('//h:Wall[1]')
        E = self.element_maker()
        # new knee wall
        wall2 = E.Wall(
            E.SystemIdentifier(id='wall2'),
            E.ExteriorAdjacentTo('attic'),
            E.AtticWallType('knee wall'),
            E.WallType(E.WoodStud()),
            E.Area('200'),
            E.Insulation(
                E.SystemIdentifier(id='wall2ins'),
                E.Layer(
                    E.InstallationType('cavity'),
                    E.NominalRValue('11')
                )
            )
        )
        wall1.addnext(wall2)
        # Reference wall in Attic
        attached_to_roof = self.xpath('//h:Attic/h:AttachedToRoof')
        attached_to_roof.addnext(etree.Element(tr_v3.addns('h:AttachedToWall'), {'idref': 'wall2'}))
        # run translation
        resp_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(resp['building']['zone']['zone_roof'], resp_v3['building']['zone']['zone_roof'])

    def test_radiant_barrier(self):
        tr_v3 = self._load_xmlfile('house2_v3')
        # run translation
        resp_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(resp_v3['building']['zone']['zone_roof'][0]['roof_assembly_code'], 'rfrb00co')
        # roof with radiant barrier (Nominal R-value > 0)
        roof = self.xpath('//h:Roof[1]')
        E = self.element_maker()
        roof_ins = E.Insulation(
            E.SystemIdentifier(id='roof_ins'),
            E.Layer(
                E.InstallationType('cavity'),
                E.NominalRValue('11')
            )
        )
        roof.append(roof_ins)
        # run translation
        resp_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(resp_v3['building']['zone']['zone_roof'][0]['roof_assembly_code'], 'rfwf11co')

        tr_v3 = self._load_xmlfile('house2_v3')
        # roof with radiant barrier (Assembly R-value > 0)
        roof = self.xpath('//h:Roof[1]')
        E = self.element_maker()
        roof_ins = E.Insulation(
            E.SystemIdentifier(id='roof_ins'),
            E.AssemblyEffectiveRValue('11')
        )
        roof.append(roof_ins)
        # run translation
        resp_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(resp_v3['building']['zone']['zone_roof'][0]['roof_assembly_code'], 'rfwf11co')

    def test_attic_knee_wall_zero_rvalue(self):
        tr = self._load_xmlfile('hescore_min')
        # make a copy of the first wall
        wall1 = self.xpath('//h:Wall[1]')
        wall2 = deepcopy(wall1)
        # change the system id
        sysid = wall2.find(tr.addns('h:SystemIdentifier'))
        sysid.attrib['id'] = 'wall2'
        # and the insulation id
        ins_sysid = wall2.xpath('h:Insulation/h:SystemIdentifier', namespaces=tr.ns)[0]
        ins_sysid.attrib['id'] = 'wall2ins'
        # remove the siding
        siding = wall2.find(tr.addns('h:Siding'))
        wall2.remove(siding)
        # add an ExteriorAdjacentTo = attic
        ext_adj_to = etree.Element(tr.addns('h:ExteriorAdjacentTo'))
        ext_adj_to.text = 'attic'
        wall2.insert(1, ext_adj_to)
        # add an area
        area_el = etree.Element(tr.addns('h:Area'))
        area_el.text = '200'
        wall2.find(tr.addns('h:WallType')).addnext(area_el)
        # insert new wall
        walls = self.xpath('//h:Walls')
        walls.append(wall2)
        # Reference wall in Attic
        attic_type = self.xpath('//h:Attic/h:AtticType')
        attic_type.addprevious(etree.Element(tr.addns('h:AtticKneeWall'), {'idref': 'wall2'}))
        # Set R-value to zero
        kneewall_rvalue_el = wall2.xpath('h:Insulation/h:Layer/h:NominalRValue', namespaces=tr.ns)[0]
        kneewall_rvalue_el.text = '0'
        # run translation
        resp = tr.hpxml_to_hescore()
        self.assertEqual(resp['building']['zone']['zone_roof'][0]['ceiling_assembly_code'], 'ecwf49')
        self.assertAlmostEqual(resp['building']['zone']['zone_roof'][0]['roof_area'], 1200.0)
        # Set kneewall R-value to 11 and attic floor R-value to zero
        kneewall_rvalue_el.text = '11'
        attic_floor_rvalue_el = self.xpath('//h:Attic/h:AtticFloorInsulation/h:Layer/h:NominalRValue')
        attic_floor_rvalue_el.text = '0'
        # run translation
        resp = tr.hpxml_to_hescore()
        self.assertEqual(resp['building']['zone']['zone_roof'][0]['ceiling_assembly_code'], 'ecwf00')
        self.assertAlmostEqual(resp['building']['zone']['zone_roof'][0]['roof_area'], 1200.0)

    def test_gable_wall_ignore(self):
        tr = self._load_xmlfile('hescore_min_v3')
        E = self.element_maker()
        wall1 = self.xpath('//h:Wall[1]')
        wall2 = deepcopy(wall1)
        wall1type = wall1.find(tr.addns('h:WallType'))
        wall1type.addnext(E.Area('100'))
        wall2type = wall2.find(tr.addns('h:WallType'))
        wall2type.addnext(E.Area('20'))
        # change the system id
        sysid = wall2.find(tr.addns('h:SystemIdentifier'))
        sysid.attrib['id'] = 'wall2'
        # and the insulation id
        ins_sysid = wall2.xpath('h:Insulation/h:SystemIdentifier', namespaces=tr.ns)[0]
        ins_sysid.attrib['id'] = 'wall2ins'
        wall1.addnext(wall2)
        sysid.addnext(E.InteriorAdjacentTo('attic - vented'))
        sysid.addnext(E.ExteriorAdjacentTo('outside'))
        att_to_roof = self.xpath('//h:Attic/h:AttachedToRoof')
        att_to_roof.addnext(E.AttachedToWall(idref='wall2'))

        resp = tr.hpxml_to_hescore()
        assert resp['building']['zone']['zone_roof'][0]['roof_area'] == 1200

    def test_wall_construction_ps_low_r(self):
        """
        Unit test for #47
        """
        tr = self._load_xmlfile('hescore_min')
        wallins = self.xpath('//h:Wall[1]/h:Insulation')
        wallins.xpath('h:Layer[1]/h:NominalRValue[1]', namespaces=tr.ns)[0].text = '8'
        newlayer = etree.SubElement(wallins, tr.addns('h:Layer'))
        etree.SubElement(newlayer, tr.addns('h:InstallationType')).text = 'continuous'
        insmat = etree.SubElement(newlayer, tr.addns('h:InsulationMaterial'))
        etree.SubElement(insmat, tr.addns('h:Rigid')).text = 'eps'
        etree.SubElement(newlayer, tr.addns('h:NominalRValue')).text = '5'
        b = tr.hpxml_to_hescore()
        self.assertEqual(b['building']['zone']['zone_wall'][0]['wall_assembly_code'], 'ewps07br')

    def test_ove_low_r(self):
        """
        Make sure we pick the lowest construction code for walls
        """
        tr = self._load_xmlfile('hescore_min')
        wood_stud_wall_type = self.xpath('//h:Wall[1]/h:WallType/h:WoodStud')
        etree.SubElement(wood_stud_wall_type, tr.addns('h:OptimumValueEngineering')).text = 'true'
        self.xpath('//h:Wall[1]/h:Insulation/h:Layer[h:InstallationType="cavity"]/h:NominalRValue').text = '0'
        self.assertRaisesRegex(
            TranslationError,
            r'Wall R-value outside HEScore bounds',
            tr.hpxml_to_hescore
            )

    def test_heating_system_no_efficiency(self):
        """
        #50
        Some heating systems should ignore the efficiency value.
        Make sure that's happening.
        """
        tr = self._load_xmlfile('hescore_min')
        htgsys_fuel = self.xpath('//h:HeatingSystem[1]/h:HeatingSystemFuel')
        htgsys_fuel.text = 'electricity'
        annual_heating_eff = self.xpath('//h:HeatingSystem[1]/h:AnnualHeatingEfficiency')
        d = tr.hpxml_to_hescore()
        self.assertNotIn(
            'efficiency',
            d['building']['systems']['hvac'][0]['heating'],
            'Electric furnace should not have an efficiency.'
            )
        annual_heating_eff.getparent().remove(annual_heating_eff)
        d = tr.hpxml_to_hescore()
        self.assertNotIn(
            'efficiency',
            d['building']['systems']['hvac'][0]['heating'],
            'Electric furnace should not have an efficiency.'
            )
        htgsys_fuel.text = 'wood'
        htgsys_type = self.xpath('//h:HeatingSystem[1]/h:HeatingSystemType')
        htgsys_type.clear()
        htgsys_type.getparent().remove(
            self.xpath('//h:HeatingSystem[1]/h:DistributionSystem'))
        etree.SubElement(htgsys_type, tr.addns('h:Stove'))
        d = tr.hpxml_to_hescore()
        self.assertNotIn(
            'efficiency',
            d['building']['systems']['hvac'][0]['heating'],
            'Wood stove should not have an efficiency.'
            )
        htgsys = self.xpath('//h:HeatingSystem[1]')
        htgsys.append(annual_heating_eff)
        d = tr.hpxml_to_hescore()
        self.assertNotIn(
            'efficiency',
            d['building']['systems']['hvac'][0]['heating'],
            'Wood stove should not have an efficiency.'
            )

    def test_zipcode_missing(self):
        """
        #51 Should error out when zipcode is missing.
        :return:
        """
        tr = self._load_xmlfile('hescore_min')
        zipcode_el = self.xpath('//h:Building/h:Site/h:Address[h:AddressType="street"]/h:ZipCode')
        zipcode_el.getparent().remove(zipcode_el)
        self.assertRaises(
            ElementNotFoundError,
            tr.hpxml_to_hescore
        )

    def test_air_source_heat_pump_has_no_ducts(self):
        tr = self._load_xmlfile('house4')
        el = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:HeatPumpType')
        el.text = 'air-to-air'
        self.assertRaisesRegex(
            TranslationError,
            r'(Cooling|Heating) system heatpump1 is not associated with an air distribution system',
            tr.hpxml_to_hescore
            )

    def test_mentor_extension(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:Building/h:ProjectStatus')
        etree.SubElement(etree.SubElement(el, tr.addns('h:extension')), tr.addns('h:HEScoreMentorAssessment'))
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building_address']['assessment_type'], 'mentor')

    def test_window_area_sum_on_angled_front_door(self):
        tr = self._load_xmlfile('house1')
        el = self.xpath('//h:OrientationOfFrontOfHome')
        el.text = 'northeast'
        hpxml_window_area = sum(map(float, self.xpath('//h:Window/h:Area/text()')))
        res = tr.hpxml_to_hescore()
        hes_window_area = sum([wall['zone_window']['window_area'] for wall in res['building']['zone']['zone_wall']])
        self.assertAlmostEqual(hpxml_window_area, hes_window_area)

    def test_external_id_passthru(self):
        tr = self._load_xmlfile('hescore_min')
        bldgidel = self.xpath('//h:Building/h:BuildingID')
        el = etree.SubElement(bldgidel, tr.addns('h:SendingSystemIdentifierValue'))
        myid = uuid.uuid4().hex
        el.text = myid
        res = tr.hpxml_to_hescore()
        self.assertEqual(myid, res['building_address'].get('external_building_id'))

    def test_external_id_extension_passthru(self):
        tr = self._load_xmlfile('hescore_min')
        el = etree.SubElement(
            etree.SubElement(self.xpath('//h:Building'), tr.addns('h:extension')),
            tr.addns('h:HESExternalID')
            )
        myid = uuid.uuid4().hex
        el.text = myid
        el = etree.SubElement(self.xpath('//h:Building/h:BuildingID'), tr.addns('h:SendingSystemIdentifierValue'))
        el.text = uuid.uuid4().hex
        res = tr.hpxml_to_hescore()
        self.assertEqual(myid, res['building_address'].get('external_building_id'))

    def test_preconstruction_event_type(self):
        tr = self._load_xmlfile('hescore_min')
        root = self.xpath('/h:HPXML')
        root.attrib['schemaVersion'] = '2.2.1'
        el = self.xpath('//h:Building/h:ProjectStatus/h:EventType')
        el.text = 'preconstruction'
        res = tr.hpxml_to_hescore()
        self.assertEqual('preconstruction', res['building_address']['assessment_type'])

    def test_heatpump_no_heating(self):
        tr = self._load_xmlfile('house3')
        el = self.xpath('//h:HeatPump')
        frac_load = etree.SubElement(el, tr.addns('h:FractionHeatLoadServed'))
        frac_load.text = '0'
        res = tr.hpxml_to_hescore()
        self.assertEqual(1, len(res['building']['systems']['hvac']))
        self.assertEqual('heat_pump', res['building']['systems']['hvac'][0]['cooling']['type'])
        self.assertEqual('none', res['building']['systems']['hvac'][0]['heating']['type'])

    def test_heatpump_no_cooling(self):
        tr = self._load_xmlfile('house3')
        el = self.xpath('//h:HeatPump')
        frac_load = etree.SubElement(el, tr.addns('h:FractionCoolLoadServed'))
        frac_load.text = '0'
        res = tr.hpxml_to_hescore()
        self.assertEqual(1, len(res['building']['systems']['hvac']))
        self.assertEqual('heat_pump', res['building']['systems']['hvac'][0]['heating']['type'])
        self.assertEqual('none', res['building']['systems']['hvac'][0]['cooling']['type'])

    def test_frac_duct_area_missing(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:Ducts/h:FractionDuctArea')
        el.getparent().remove(el)
        self.assertRaises(ElementNotFoundError, tr.hpxml_to_hescore)

    def test_assembly_rvalues(self):
        tr = self._load_xmlfile('hescore_min_assembly_rvalue')
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['zone']['zone_wall'][0]['wall_assembly_code'], 'ewwf11br')
        self.assertEqual(res['building']['zone']['zone_wall'][1]['wall_assembly_code'], 'ewwf11br')
        self.assertEqual(res['building']['zone']['zone_wall'][2]['wall_assembly_code'], 'ewwf11br')
        self.assertEqual(res['building']['zone']['zone_wall'][3]['wall_assembly_code'], 'ewwf11br')
        self.assertEqual(res['building']['zone']['zone_roof'][0]['roof_assembly_code'], 'rfwf00co')
        self.assertEqual(res['building']['zone']['zone_roof'][0]['ceiling_assembly_code'], 'ecwf38')
        self.assertEqual(res['building']['zone']['zone_floor'][0]['floor_assembly_code'], 'efwf15ca')

        tr = self._load_xmlfile('house9')
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['zone']['zone_wall'][0]['wall_assembly_code'], 'ewwf15wo')
        self.assertEqual(res['building']['zone']['zone_wall'][1]['wall_assembly_code'], 'ewwf13wo')
        self.assertEqual(res['building']['zone']['zone_wall'][2]['wall_assembly_code'], 'ewwf13wo')
        self.assertEqual(res['building']['zone']['zone_wall'][3]['wall_assembly_code'], 'ewwf13wo')
        self.assertEqual(res['building']['zone']['zone_roof'][0]['roof_assembly_code'], 'rfwf00wo')
        self.assertEqual(res['building']['zone']['zone_roof'][0]['ceiling_assembly_code'], 'ecwf25')
        self.assertEqual(res['building']['zone']['zone_floor'][0]['floor_assembly_code'], 'efwf30ca')

        tr = self._load_xmlfile('house9')
        E = self.element_maker()
        fwall_ins_layers = self.xpath('//h:FoundationWalls/h:FoundationWall/h:Insulation/h:Layer')
        fwall_ins = fwall_ins_layers[0].getparent()
        for fwall_ins_layer in fwall_ins_layers:
            fwall_ins_layer.getparent().remove(fwall_ins_layer)
        fwall_ins.append(
            E.AssemblyEffectiveRValue('7.6')
        )
        self.assertRaisesRegex(
            TranslationError,
            'Every foundation wall insulation layer needs a NominalRValue, fwall_id = Surface_13',
            tr.hpxml_to_hescore
        )

        tr = self._load_xmlfile('house3')
        E = self.element_maker()
        slab_perim_ins_layer = self.xpath('//h:Slab/h:PerimeterInsulation/h:Layer')
        slab_perim_ins = slab_perim_ins_layer.getparent()
        slab_perim_ins_layer.getparent().remove(slab_perim_ins_layer)
        slab_perim_ins.append(
            E.AssemblyEffectiveRValue('7.6')
        )
        self.assertRaisesRegex(
            TranslationError,
            'Every slab insulation layer needs a NominalRValue, slab_id = slab1',
            tr.hpxml_to_hescore
        )

    def test_duct_leakage_to_outside(self):
        tr = self._load_xmlfile('house1')
        E = self.element_maker()
        el = self.xpath('//h:DuctLeakageMeasurement')
        el.addprevious(
            E.DuctLeakageMeasurement(
                E.DuctLeakage(
                    E.Units('CFM25'),
                    E.Value('400.0'),
                    E.TotalOrToOutside('to outside')
                )
            )
        )
        el.addprevious(
            E.DuctLeakageMeasurement(
                E.DuctType('supply'),
                E.DuctLeakage(
                    E.Units('CFM25'),
                    E.Value('224.77'),
                    E.TotalOrToOutside('to outside')
                )
            )
        )
        el.addprevious(
            E.DuctLeakageMeasurement(
                E.DuctType('return'),
                E.DuctLeakage(
                    E.Units('CFM25'),
                    E.Value('113.23'),
                    E.TotalOrToOutside('to outside')
                )
            )
        )
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['leakage_method'], 'quantitative')
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['leakage_to_outside'], 400.0)

        tr = self._load_xmlfile('house1')
        E = self.element_maker()
        el = self.xpath('//h:DuctLeakageMeasurement')
        el.addprevious(
            E.DuctLeakageMeasurement(
                E.DuctType('supply'),
                E.DuctLeakage(
                    E.Units('CFM25'),
                    E.Value('224.77'),
                    E.TotalOrToOutside('to outside')
                )
            )
        )
        el.addprevious(
            E.DuctLeakageMeasurement(
                E.DuctType('return'),
                E.DuctLeakage(
                    E.Units('CFM25'),
                    E.Value('113.23'),
                    E.TotalOrToOutside('to outside')
                )
            )
        )
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['leakage_method'], 'quantitative')
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['leakage_to_outside'], 338.0)

        tr = self._load_xmlfile('house1')
        E = self.element_maker()
        el = self.xpath('//h:DuctLeakageMeasurement')
        el.addprevious(
            E.DuctLeakageMeasurement(
                E.DuctType('supply'),
                E.DuctLeakage(
                    E.Units('CFM25'),
                    E.Value('224.77'),
                    E.TotalOrToOutside('to outside')
                )
            )
        )
        el.getparent().remove(el)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['leakage_method'], 'qualitative')
        self.assertNotIn('leakage_to_outside', res['building']['systems']['hvac'][0]['hvac_distribution'])
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['sealed'], False)

        tr = self._load_xmlfile('house1')
        el = self.xpath('//h:DuctLeakageMeasurement')
        el.getparent().remove(el)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['leakage_method'], 'qualitative')
        self.assertNotIn('leakage_to_outside', res['building']['systems']['hvac'][0]['hvac_distribution'])
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['sealed'], False)


class TestInputOutOfBounds(unittest.TestCase, ComparatorBase):

    def test_assessment_date1(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:Building/h:ProjectStatus/h:Date')
        el.text = '2009-12-31'
        self.assertRaisesRegex(InputOutOfBounds,
                               'assessment_date is out of bounds',
                               tr.hpxml_to_hescore)

    def test_assessment_date2(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:Building/h:ProjectStatus/h:Date')
        el.text = (dt.datetime.today().date() + dt.timedelta(1)).isoformat()
        self.assertRaisesRegex(InputOutOfBounds,
                               'assessment_date is out of bounds',
                               tr.hpxml_to_hescore)

    def test_year_built1(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:YearBuilt')
        el.text = '1599'
        self.assertRaisesRegex(InputOutOfBounds,
                               'year_built is out of bounds',
                               tr.hpxml_to_hescore)

    def test_year_built2(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:YearBuilt')
        el.text = str(dt.datetime.today().year + 1)
        self.assertRaisesRegex(InputOutOfBounds,
                               'year_built is out of bounds',
                               tr.hpxml_to_hescore)

    def test_num_floor_above_grade(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:NumberofConditionedFloorsAboveGrade')
        el.text = '5'
        self.assertRaisesRegex(InputOutOfBounds,
                               'num_floor_above_grade is out of bounds',
                               tr.hpxml_to_hescore)

    def test_number_bedrooms(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:NumberofBedrooms')
        el.text = '25'
        self.assertRaisesRegex(InputOutOfBounds,
                               'number_bedrooms is out of bounds',
                               tr.hpxml_to_hescore)

    def test_floor_to_ceiling_height1(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:AverageCeilingHeight')
        el.text = '5'
        self.assertRaisesRegex(InputOutOfBounds,
                               'floor_to_ceiling_height is out of bounds',
                               tr.hpxml_to_hescore)

    def test_floor_to_ceiling_height2(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:AverageCeilingHeight')
        el.text = '13'
        self.assertRaisesRegex(InputOutOfBounds,
                               'floor_to_ceiling_height is out of bounds',
                               tr.hpxml_to_hescore)

    def test_conditioned_floor_area1(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:ConditionedFloorArea')
        el.text = '249'
        self.assertRaisesRegex(InputOutOfBounds,
                               'conditioned_floor_area is out of bounds',
                               tr.hpxml_to_hescore)

    def test_conditioned_floor_area2(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:ConditionedFloorArea')
        el.text = '25001'
        self.assertRaisesRegex(InputOutOfBounds,
                               'conditioned_floor_area is out of bounds',
                               tr.hpxml_to_hescore)

    def test_envelope_leakage(self):
        tr = self._load_xmlfile('hescore_min')
        units_el = self.xpath('//h:BuildingAirLeakage/h:UnitofMeasure')
        leak_el = self.xpath('//h:BuildingAirLeakage/h:AirLeakage')
        units_el.text = 'CFM'
        leak_el.text = '25001'
        self.assertRaisesRegex(InputOutOfBounds,
                               'envelope_leakage is out of bounds',
                               tr.hpxml_to_hescore)

    def test_skylight_area(self):
        tr = self._load_xmlfile('house4')
        el = self.xpath('//h:Skylight/h:Area')
        el.text = '301'
        self.assertRaisesRegex(InputOutOfBounds,
                               'skylight_area is out of bounds',
                               tr.hpxml_to_hescore)

    def test_skylight_u_value(self):
        tr = self._load_xmlfile('house4')
        skylight = self.xpath('//h:Skylight')
        etree.SubElement(skylight, tr.addns('h:UFactor')).text = '0.001'
        etree.SubElement(skylight, tr.addns('h:SHGC')).text = '0.7'
        self.assertRaisesRegex(InputOutOfBounds,
                               'skylight_u_value is out of bounds',
                               tr.hpxml_to_hescore)

    def test_window_area(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:Window[1]/h:Area')
        el.text = '1000'
        self.assertRaisesRegex(InputOutOfBounds,
                               'window_area is out of bounds',
                               tr.hpxml_to_hescore)
        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:Window[1]/h:Area')
        el.text = '1000'
        self.assertRaisesRegex(InputOutOfBounds,
                               'window_area is out of bounds',
                               tr_v3.hpxml_to_hescore)

    def test_window_u_value(self):
        tr = self._load_xmlfile('house2')
        el = self.xpath('//h:Window[1]/h:UFactor')
        el.text = '5.00001'
        self.assertRaisesRegex(InputOutOfBounds,
                               'window_u_value is out of bounds',
                               tr.hpxml_to_hescore)

    def test_heating_efficiency_furnace(self):
        tr = self._load_xmlfile('hescore_min')
        htg_eff_el = self.xpath('//h:HeatingSystem/h:AnnualHeatingEfficiency/h:Value')
        htg_eff_el.text = '1.01'
        self.assertRaisesRegex(InputOutOfBounds,
                               'heating_efficiency is out of bounds',
                               tr.hpxml_to_hescore)
        htg_eff_el.text = '0.59'
        self.assertRaisesRegex(InputOutOfBounds,
                               'heating_efficiency is out of bounds',
                               tr.hpxml_to_hescore)

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        htg_eff_el = self.xpath('//h:HeatingSystem/h:AnnualHeatingEfficiency/h:Value')
        htg_eff_el.text = '1.01'
        self.assertRaisesRegex(InputOutOfBounds,
                               'heating_efficiency is out of bounds',
                               tr_v3.hpxml_to_hescore)
        htg_eff_el.text = '0.59'
        self.assertRaisesRegex(InputOutOfBounds,
                               'heating_efficiency is out of bounds',
                               tr_v3.hpxml_to_hescore)

    def test_heating_efficiency_heat_pump(self):
        tr = self._load_xmlfile('house4')
        htg_eff_el = self.xpath('//h:HeatPump/h:AnnualHeatEfficiency/h:Value')
        htg_eff_el.text = '5.9'
        self.assertRaisesRegex(InputOutOfBounds,
                               'heating_efficiency is out of bounds',
                               tr.hpxml_to_hescore)
        htg_eff_el.text = '20.1'
        self.assertRaisesRegex(InputOutOfBounds,
                               'heating_efficiency is out of bounds',
                               tr.hpxml_to_hescore)

    def test_heating_efficiency_gchp(self):
        tr = self._load_xmlfile('house3')
        self.xpath('//h:HeatPump/h:HeatPumpType').text = 'ground-to-air'
        hp_el = self.xpath('//h:HeatPump')
        eff_el = etree.SubElement(hp_el, tr.addns('h:AnnualHeatEfficiency'))
        etree.SubElement(eff_el, tr.addns('h:Units')).text = 'COP'
        eff_value_el = etree.SubElement(eff_el, tr.addns('h:Value'))
        eff_value_el.text = '1.9'
        self.assertRaisesRegex(InputOutOfBounds,
                               'heating_efficiency is out of bounds',
                               tr.hpxml_to_hescore)
        eff_value_el.text = '5.1'
        self.assertRaisesRegex(InputOutOfBounds,
                               'heating_efficiency is out of bounds',
                               tr.hpxml_to_hescore)

    def test_heating_year(self):
        tr = self._load_xmlfile('house3')
        el = self.xpath('//h:HeatPump/h:YearInstalled')
        el.text = str(dt.datetime.today().year + 1)
        self.assertRaisesRegex(InputOutOfBounds,
                               'heating_year is out of bounds',
                               tr.hpxml_to_hescore)

    def test_cooling_efficiency(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:CoolingSystem/h:AnnualCoolingEfficiency/h:Value')
        el.text = '40.1'
        self.assertRaisesRegex(InputOutOfBounds,
                               'cooling_efficiency is out of bounds',
                               tr.hpxml_to_hescore)
        el.text = '7.9'
        self.assertRaisesRegex(InputOutOfBounds,
                               'cooling_efficiency is out of bounds',
                               tr.hpxml_to_hescore)

    def test_evap_cooler_missing_efficiency(self):
        tr = self._load_xmlfile('hescore_min')
        eff_el = self.xpath('//h:CoolingSystem/h:AnnualCoolingEfficiency')
        self.xpath('//h:CoolingSystem/h:CoolingSystemType').text = 'evaporative cooler'
        eff_el.getparent().remove(
            self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]/h:DistributionSystem'))
        eff_el.getparent().remove(eff_el)
        res = tr.hpxml_to_hescore()
        clg_sys = res['building']['systems']['hvac'][0]['cooling']
        self.assertEqual(clg_sys['type'], 'dec')
        self.assertNotIn('efficiency', list(clg_sys.keys()))
        self.assertNotIn('efficiency_method', list(clg_sys.keys()))

    def test_cooling_year(self):
        tr = self._load_xmlfile('house1')
        eff_el = self.xpath('//h:CoolingSystem/h:AnnualCoolingEfficiency')
        eff_el.getparent().remove(eff_el)
        year_el = self.xpath('//h:CoolingSystem/h:YearInstalled')
        year_el.text = str(dt.datetime.today().year + 1)
        self.assertRaisesRegex(InputOutOfBounds,
                               'cooling_year is out of bounds',
                               tr.hpxml_to_hescore)

    def test_dhw_storage_efficiency(self):
        tr = self._load_xmlfile('house1')
        el = self.xpath('//h:WaterHeatingSystem/h:EnergyFactor')
        el.text = '0.44'
        self.assertRaisesRegex(InputOutOfBounds,
                               'domestic_hot_water_energy_factor is out of bounds',
                               tr.hpxml_to_hescore)
        el.text = '1.1'
        self.assertRaisesRegex(InputOutOfBounds,
                               'domestic_hot_water_energy_factor is out of bounds',
                               tr.hpxml_to_hescore)
        el.text = '1.0'
        res = tr.hpxml_to_hescore()
        dhw = res['building']['systems']['domestic_hot_water']
        self.assertEqual(dhw['efficiency_method'], 'user')
        self.assertEqual(dhw['energy_factor'], 1.0)

    def test_dhw_heat_pump_efficiency(self):
        tr = self._load_xmlfile('hescore_min')
        self.xpath('//h:WaterHeatingSystem/h:FuelType').text = 'electricity'
        self.xpath('//h:WaterHeatingSystem/h:WaterHeaterType').text = 'heat pump water heater'
        year_el = self.xpath('//h:WaterHeatingSystem/h:YearInstalled')
        year_el.getparent().remove(year_el)
        dhw_sys_el = self.xpath('//h:WaterHeatingSystem')
        ef_el = etree.SubElement(dhw_sys_el, tr.addns('h:EnergyFactor'))
        ef_el.text = '0.9'
        self.assertRaisesRegex(InputOutOfBounds,
                               'domestic_hot_water_energy_factor is out of bounds',
                               tr.hpxml_to_hescore)
        ef_el.text = '4.1'
        self.assertRaisesRegex(InputOutOfBounds,
                               'domestic_hot_water_energy_factor is out of bounds',
                               tr.hpxml_to_hescore)
        ef_el.text = '4.0'
        res = tr.hpxml_to_hescore()
        dhw = res['building']['systems']['domestic_hot_water']
        self.assertEqual(dhw['efficiency_method'], 'user')
        self.assertEqual(dhw['energy_factor'], 4.0)

    def test_dhw_year(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:WaterHeatingSystem/h:YearInstalled')
        el.text = str(dt.datetime.today().year + 1)
        self.assertRaisesRegex(InputOutOfBounds,
                               'domestic_hot_water_year is out of bounds',
                               tr.hpxml_to_hescore)

    def test_heating_system_not_requiring_ducts(self):
        tr = self._load_xmlfile('hescore_min')
        E = self.element_maker()
        el = self.xpath('//h:HeatingSystemType')
        el.remove(el.getchildren()[0])
        wallfurnace_el = E.WallFurnace()
        el.append(wallfurnace_el)
        self.assertRaisesRegex(
            TranslationError,
            r'Ducts are not allowed for heating system furnace1.',
            tr.hpxml_to_hescore
        )

    def test_cooling_system_not_requiring_ducts(self):
        tr = self._load_xmlfile('hescore_min')
        el = self.xpath('//h:CoolingSystemType')
        el.text = 'mini-split'
        self.assertRaisesRegex(
            TranslationError,
            r'Ducts are not allowed for cooling system centralair1.',
            tr.hpxml_to_hescore
        )


class TestHVACFractions(unittest.TestCase, ComparatorBase):
    '''
    These are tests for weird HVAC configurations, see issue #45
    '''

    def test_boiler_roomac(self):
        '''
        Whole house heating by boiler, room AC added for one section (30%).
        '''
        tr = self._load_xmlfile('house4')

        # get rid of the heat pump
        el = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]')
        el.getparent().remove(el)

        # Remove floor areas served
        for el in self.xpath('//h:HVACPlant/*/h:FloorAreaServed'):
            el.getparent().remove(el)

        # Set the boiler to 100 of heating load
        boiler = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="boiler1"]')
        etree.SubElement(boiler, tr.addns('h:FractionHeatLoadServed')).text = '1'

        # Convert the central air to a room a/c and set the fraction to 0.3
        aircond = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]')
        el = aircond.xpath('h:CoolingSystemType', namespaces=tr.ns)[0]
        el.text = 'room air conditioner'
        # remove distribution systems
        el = aircond.xpath('h:DistributionSystem', namespaces=tr.ns)[0]
        el.getparent().remove(el)
        el = self.xpath('//h:HVACDistribution[h:SystemIdentifier/@id="aircondducts"]')
        el.getparent().remove(el)
        el = aircond.xpath('h:AnnualCoolingEfficiency/h:Units', namespaces=tr.ns)[0]
        el.text = 'EER'
        el = aircond.xpath('h:AnnualCoolingEfficiency/h:Value', namespaces=tr.ns)[0]
        el.text = '8'
        el = etree.Element(tr.addns('h:FractionCoolLoadServed'))
        el.text = '0.3'
        aircond.insert(-1, el)

        b = self.xpath('h:Building[1]')
        hvac_systems = tr.get_hvac(b, {"conditioned_floor_area": 3213})
        hvac_systems.sort(key=lambda x: x['hvac_fraction'])

        hvac1 = hvac_systems[0]
        self.assertAlmostEqual(hvac1['hvac_fraction'], 0.3, 3)
        self.assertEqual(hvac1['heating']['type'], 'boiler')
        self.assertEqual(hvac1['cooling']['type'], 'packaged_dx')

        hvac2 = hvac_systems[1]
        self.assertAlmostEqual(hvac2['hvac_fraction'], 0.7, 3)
        self.assertEqual(hvac2['heating']['type'], 'boiler')
        self.assertEqual(hvac2['cooling']['type'], 'none')

    def test_furnace_baseboard_centralac(self):
        '''
        Furnace and baseboard each heat a fraction of the house.
        2 identical Central air cools corresponding fractions.
        '''
        tr = self._load_xmlfile('house6')

        # Get total floor area
        total_floor_area = 0
        for htgsys_floor_area in self.xpath('//h:HeatingSystem/h:FloorAreaServed/text()'):
            total_floor_area += float(htgsys_floor_area)

        # Set each equipment to the proper fractions
        furnace_floor_area_el = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="furnace"]/h:FloorAreaServed')
        furnace_floor_area_el.text = str(0.6 * total_floor_area)
        baseboard_floor_area_el = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="baseboard"]/h:FloorAreaServed')
        baseboard_floor_area_el.text = str(0.4 * total_floor_area)

        # Set 1st central air unit
        clgsys_floor_area_el = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair"]/h:FloorAreaServed')
        clgsys_floor_area_el.text = str(0.6 * total_floor_area)

        # Copy central air unit
        clgsys = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair"]')
        clgsys2 = deepcopy(clgsys)
        clgsys.getparent().append(clgsys2)
        tr.xpath(clgsys2, 'h:SystemIdentifier').attrib['id'] = 'centralair2'
        tr.xpath(clgsys2, 'h:FloorAreaServed').text = str(0.4 * total_floor_area)
        tr.xpath(clgsys2, 'h:DistributionSystem').attrib['idref'] = 'ducts2'

        # Copy the ducts
        ducts = self.xpath('//h:HVACDistribution[h:SystemIdentifier/@id="ducts"]')
        ducts2 = deepcopy(ducts)
        ducts.getparent().append(ducts2)
        tr.xpath(ducts2, 'h:SystemIdentifier').attrib['id'] = 'ducts2'

        b = self.xpath('h:Building[1]')
        hvac_systems = tr.get_hvac(b, {"conditioned_floor_area": 2600})
        hvac_systems.sort(key=lambda x: x['hvac_fraction'])

        hvac1 = hvac_systems[0]
        self.assertAlmostEqual(hvac1['hvac_fraction'], 0.4, 3)
        self.assertEqual(hvac1['heating']['type'], 'baseboard')
        self.assertEqual(hvac1['cooling']['type'], 'split_dx')

        hvac2 = hvac_systems[1]
        self.assertAlmostEqual(hvac2['hvac_fraction'], 0.6, 3)
        self.assertEqual(hvac2['heating']['type'], 'central_furnace')
        self.assertEqual(hvac2['cooling']['type'], 'split_dx')

    def test_wall_furnace_baseboard_centralac(self):
        '''
        60% wall furnace
        40% baseboard
        100% central air
        '''
        tr = self._load_xmlfile('house6')

        # Get total floor area
        total_floor_area = 0
        for htgsys_floor_area in self.xpath('//h:HeatingSystem/h:FloorAreaServed/text()'):
            total_floor_area += float(htgsys_floor_area)

        # Set each equipment to the proper fractions
        furnace_floor_area_el = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="furnace"]/h:FloorAreaServed')
        furnace_floor_area_el.text = str(0.6 * total_floor_area)
        baseboard_floor_area_el = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="baseboard"]/h:FloorAreaServed')
        baseboard_floor_area_el.text = str(0.4 * total_floor_area)

        # Change to natural gas wall furnace (no ducts)
        htgsys_type = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="furnace"]/h:HeatingSystemType')
        htgsys_type.clear()
        etree.SubElement(htgsys_type, tr.addns('h:WallFurnace'))
        distsys = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="furnace"]/h:DistributionSystem')
        distsys.getparent().remove(distsys)
        htgsys_fuel = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="furnace"]/h:HeatingSystemFuel')
        htgsys_fuel.text = 'natural gas'

        # Set central air unit
        clgsys_floor_area_el = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair"]/h:FloorAreaServed')
        clgsys_floor_area_el.text = str(total_floor_area)

        b = self.xpath('h:Building[1]')
        hvac_systems = tr.get_hvac(b, {"conditioned_floor_area": 2600})
        hvac_systems.sort(key=lambda x: x['hvac_fraction'])

        hvac1 = hvac_systems[0]
        self.assertAlmostEqual(hvac1['hvac_fraction'], 0.4, 3)
        self.assertEqual(hvac1['heating']['type'], 'baseboard')
        self.assertEqual(hvac1['cooling']['type'], 'split_dx')

        hvac2 = hvac_systems[1]
        self.assertAlmostEqual(hvac2['hvac_fraction'], 0.6, 3)
        self.assertEqual(hvac2['heating']['type'], 'wall_furnace')
        self.assertEqual(hvac2['cooling']['type'], 'split_dx')

    def test_furnace_heat_pump(self):
        '''
        Original house heated by central furnace 70%
        Addition heated and cooled by heat pump
        '''
        tr = self._load_xmlfile('house4')

        # Get total floor area
        total_floor_area = 0
        for htgsys_floor_area in self.xpath(
                '//h:HeatingSystem/h:FloorAreaServed/text()|//h:HeatPump/h:FloorAreaServed/text()'):
            total_floor_area += float(htgsys_floor_area)

        # Turn the boiler into central furnace
        furnace_el = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="boiler1"]')
        sys_type = tr.xpath(furnace_el, 'h:HeatingSystemType')
        sys_type.clear()
        etree.SubElement(sys_type, tr.addns('h:Furnace'))

        # Attach the furnace to the air conditioning ducts
        el = tr.xpath(furnace_el, 'h:DistributionSystem')
        el.attrib['idref'] = 'aircondducts'

        # Set the furnace to be 70% of the area
        furnace_floor_area_el = tr.xpath(furnace_el, 'h:FloorAreaServed')
        furnace_floor_area_el.text = str(0.7 * total_floor_area)

        # Remove the air conditioner
        el = self.xpath('//h:CoolingSystem')
        el.getparent().remove(el)

        # Set the heat pump to 30% of the area
        heat_pump_floor_area_el = self.xpath('//h:HeatPump/h:FloorAreaServed')
        heat_pump_floor_area_el.text = str(0.3 * total_floor_area)

        # Get HEScore inputs and sort by fraction
        b = self.xpath('h:Building[1]')
        hvac_systems = tr.get_hvac(b, {"conditioned_floor_area": 2600})
        hvac_systems.sort(key=lambda x: x['hvac_fraction'])

        hvac1 = hvac_systems[0]
        self.assertAlmostEqual(hvac1['hvac_fraction'], 0.3, 3)
        self.assertEqual(hvac1['heating']['type'], 'mini_split')
        self.assertEqual(hvac1['cooling']['type'], 'mini_split')

        hvac2 = hvac_systems[1]
        self.assertAlmostEqual(hvac2['hvac_fraction'], 0.7, 3)
        self.assertEqual(hvac2['heating']['type'], 'central_furnace')
        self.assertEqual(hvac2['cooling']['type'], 'none')

    def test_allow_5pct_diff(self):
        tr = self._load_xmlfile('hescore_min')
        htg_sys = self.xpath('//h:HeatingSystem')
        frac_heat_load_served = etree.SubElement(htg_sys, tr.addns('h:FractionHeatLoadServed'))
        frac_heat_load_served.text = '0.95'
        clg_sys_eff = self.xpath('//h:CoolingSystem/h:AnnualCoolingEfficiency')
        frac_cool_load_served = etree.Element(tr.addns('h:FractionCoolLoadServed'))
        frac_cool_load_served.text = '1.0'
        clg_sys_eff.addprevious(frac_cool_load_served)
        b = self.xpath('h:Building[1]')
        tr.get_hvac(b, {"conditioned_floor_area": 2400})

    def test_different_weighting_factors(self):
        tr = self._load_xmlfile('hescore_min')
        htg_sys = self.xpath('//h:HeatingSystem')
        frac_heat_load_served = etree.SubElement(htg_sys, tr.addns('h:FractionHeatLoadServed'))
        frac_heat_load_served.text = '1.0'
        heating_floor_area_served = etree.SubElement(htg_sys, tr.addns('h:FloorAreaServed'))
        heating_floor_area_served.text = '2400'
        clg_sys_eff = self.xpath('//h:CoolingSystem/h:AnnualCoolingEfficiency')
        frac_cool_load_served = etree.Element(tr.addns('h:FractionCoolLoadServed'))
        frac_cool_load_served.text = '1.0'
        clg_sys_eff.addprevious(frac_cool_load_served)
        b = self.xpath('h:Building[1]')
        tr.get_hvac(b, {"conditioned_floor_area": 2400})


class TestPhotovoltaics(unittest.TestCase, ComparatorBase):

    def _add_pv(
            self,
            sysid='pv1',
            orientation='south',
            azimuth=180,
            tilt=30,
            capacity=5,
            inverter_year=2015,
            module_year=2013,
            n_panels=None,
            collector_area=None):
        addns = self.translator.addns

        def add_elem(parent, subname, text=None):
            el = etree.SubElement(parent, addns('h:' + subname))
            if text is not None:
                el.text = str(text)
            return el

        pv_container = self.xpath('//h:Photovoltaics')
        if pv_container is None:
            systems_el = self.xpath('//h:Systems')
            pv_container = add_elem(systems_el, 'Photovoltaics')
        pv_system = add_elem(pv_container, 'PVSystem')
        sys_id = add_elem(pv_system, 'SystemIdentifier')
        sys_id.attrib['id'] = sysid
        if orientation is not None:
            add_elem(pv_system, 'ArrayOrientation', orientation)
        if azimuth is not None:
            add_elem(pv_system, 'ArrayAzimuth', azimuth)
        if tilt is not None:
            add_elem(pv_system, 'ArrayTilt', tilt)
        if capacity is not None:
            add_elem(pv_system, 'MaxPowerOutput', capacity * 1000)
        if collector_area is not None:
            add_elem(pv_system, 'CollectorArea', collector_area)
        if n_panels is not None:
            add_elem(pv_system, 'NumberOfPanels', n_panels)
        if inverter_year is not None:
            add_elem(pv_system, 'YearInverterManufactured', inverter_year)
        if module_year is not None:
            add_elem(pv_system, 'YearModulesManufactured', module_year)

    def test_pv(self):
        tr = self._load_xmlfile('hescore_min')
        self._add_pv(orientation='southeast', azimuth=None, tilt=50)
        hesd = tr.hpxml_to_hescore()
        pv = hesd['building']['systems']['generation']['solar_electric']
        self.assertTrue(pv['capacity_known'])
        self.assertNotIn('num_panels', list(pv.keys()))
        self.assertEqual(pv['system_capacity'], 5)
        self.assertEqual(pv['year'], 2015)
        self.assertEqual(pv['array_azimuth'], 'south_east')
        self.assertEqual(pv['array_tilt'], 'steep_slope')

    def test_capacity_missing(self):
        tr = self._load_xmlfile('hescore_min')
        self._add_pv(capacity=None)
        self.assertRaisesRegex(
            TranslationError,
            r'MaxPowerOutput, NumberOfPanels, or CollectorArea is required',
            tr.hpxml_to_hescore
        )

    def test_n_panels(self):
        tr = self._load_xmlfile('hescore_min_v3')
        self._add_pv(
            capacity=None,
            n_panels=12,
            collector_area=1
        )
        hesd = tr.hpxml_to_hescore()
        pv = hesd['building']['systems']['generation']['solar_electric']
        self.assertFalse(pv['capacity_known'])
        self.assertNotIn('system_capacity', list(pv.keys()))
        self.assertEqual(pv['num_panels'], 12)

    def test_collector_area(self):
        tr = self._load_xmlfile('hescore_min')
        self._add_pv(capacity=None, collector_area=176)
        hesd = tr.hpxml_to_hescore()
        pv = hesd['building']['systems']['generation']['solar_electric']
        self.assertFalse(pv['capacity_known'])
        self.assertNotIn('system_capacity', list(pv.keys()))
        self.assertEqual(pv['num_panels'], 10)

    def test_orientation(self):
        tr = self._load_xmlfile('hescore_min')
        self._add_pv(orientation='east', azimuth=None)
        hesd = tr.hpxml_to_hescore()
        pv = hesd['building']['systems']['generation']['solar_electric']
        self.assertEqual(pv['array_azimuth'], 'east')

    def test_azimuth_orientation_missing(self):
        tr = self._load_xmlfile('hescore_min')
        self._add_pv(azimuth=None, orientation=None)
        self.assertRaisesRegex(
            TranslationError,
            r'ArrayAzimuth or ArrayOrientation is required for every PVSystem',
            tr.hpxml_to_hescore
            )

    def test_tilt_missing(self):
        tr = self._load_xmlfile('hescore_min')
        self._add_pv(tilt=None)
        self.assertRaisesRegex(
            TranslationError,
            r'ArrayTilt is required for every PVSystem',
            tr.hpxml_to_hescore
            )

    def test_years_missing(self):
        tr = self._load_xmlfile('hescore_min')
        self._add_pv(module_year=None, inverter_year=None)
        self.assertRaisesRegex(
            TranslationError,
            r'Either YearInverterManufactured or YearModulesManufactured is required for every PVSystem',
            tr.hpxml_to_hescore
            )

    def test_two_sys_avg(self):
        tr = self._load_xmlfile('hescore_min')
        self._add_pv('pv1', azimuth=None, orientation='south', tilt=0, inverter_year=None, module_year=2015)
        self._add_pv('pv2', azimuth=None, orientation='west', tilt=20, inverter_year=None, module_year=2013)
        hesd = tr.hpxml_to_hescore()
        pv = hesd['building']['systems']['generation']['solar_electric']
        self.assertEqual(pv['system_capacity'], 10)
        self.assertEqual(pv['array_azimuth'], 'south_west')
        self.assertEqual(pv['array_tilt'], 'low_slope')
        self.assertEqual(pv['year'], 2014)

    def test_two_sys_different_capacity_error(self):
        tr = self._load_xmlfile('hescore_min')
        self._add_pv('pv1', capacity=5, azimuth=None, orientation='south', inverter_year=None, module_year=2015)
        self._add_pv(
            'pv2',
            capacity=None,
            collector_area=50,
            azimuth=None,
            orientation='west',
            inverter_year=None,
            module_year=2013)
        self.assertRaisesRegex(
            TranslationError,
            r'Either a MaxPowerOutput or NumberOfPanels or CollectorArea must be specified',
            tr.hpxml_to_hescore
            )


class TestDuctLocations(unittest.TestCase, ComparatorBase):
    '''
    These are tests related to allowing additional duct locations
    '''

    def _set_duct_location(self, location):
        el = self.xpath('//h:Ducts/h:DuctLocation')
        el.text = location

    def test_under_slab(self):
        tr = self._load_xmlfile('house3_v3')
        self._set_duct_location('under slab')
        hesd = tr.hpxml_to_hescore()
        duct = hesd['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]
        self.assertEqual(duct['location'], 'under_slab')

    def test_exterior_wall(self):
        tr = self._load_xmlfile('house3_v3')
        self._set_duct_location('exterior wall')
        hesd = tr.hpxml_to_hescore()
        duct = hesd['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]
        self.assertEqual(duct['location'], 'exterior_wall')

    def test_outside(self):
        tr = self._load_xmlfile('house3_v3')
        self._set_duct_location('outside')
        hesd = tr.hpxml_to_hescore()
        duct = hesd['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]
        self.assertEqual(duct['location'], 'outside')

    def test_outside_v2(self):
        tr = self._load_xmlfile('house3')
        self._set_duct_location('outside')
        hesd = tr.hpxml_to_hescore()
        duct = hesd['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]
        self.assertEqual(duct['location'], 'outside')

    def test_roof_deck(self):
        tr = self._load_xmlfile('house3_v3')
        self._set_duct_location('roof deck')
        hesd = tr.hpxml_to_hescore()
        duct = hesd['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]
        self.assertEqual(duct['location'], 'outside')


class TestHPXMLVersion2Point3(unittest.TestCase, ComparatorBase):

    def test_floor_furnace(self):
        tr = self._load_xmlfile('hescore_min')
        htg_sys_type = self.xpath('//h:HeatingSystemType')
        htg_sys_type.clear()
        htg_sys_type.getparent().remove(
            self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="furnace1"]/h:DistributionSystem'))
        etree.SubElement(htg_sys_type, tr.addns('h:FloorFurnace'))
        d = tr.hpxml_to_hescore()
        self.assertEqual(
            d['building']['systems']['hvac'][0]['heating']['type'],
            'wall_furnace'
            )

    def test_medium_dark_roof_color(self):
        tr = self._load_xmlfile('hescore_min')
        roof_color = self.xpath('//h:RoofColor')
        roof_color.text = 'medium dark'
        d = tr.hpxml_to_hescore()
        self.assertEqual(
            d['building']['zone']['zone_roof'][0]['roof_color'],
            'medium_dark'
            )

    def test_roof_absorptance(self):
        tr = self._load_xmlfile('hescore_min')
        roof_color = self.xpath('//h:RoofColor')
        el = etree.Element(tr.addns('h:SolarAbsorptance'))
        el.text = '0.3'
        roof_color.addnext(el)
        d = tr.hpxml_to_hescore()
        roofd = d['building']['zone']['zone_roof'][0]
        self.assertEqual(roofd['roof_color'], 'cool_color')
        self.assertAlmostEqual(roofd['roof_absorptance'], 0.3)


class TestHEScore2019Updates(unittest.TestCase, ComparatorBase):

    def test_window_solar_screens(self):
        tr = self._load_xmlfile('house6')
        window1 = self.xpath('//h:Window[h:SystemIdentifier/@id="frontwindows"]')
        window3 = self.xpath('//h:Window[h:SystemIdentifier/@id="backwindows"]')
        el1 = etree.SubElement(window1, tr.addns('h:Treatments'))
        el2 = etree.SubElement(window3, tr.addns('h:ExteriorShading'))
        el1.text = 'solar screen'
        el2.text = 'solar screens'
        d = tr.hpxml_to_hescore()

        for wall in d['building']['zone']['zone_wall']:
            if wall['side'] == 'front' or wall['side'] == 'back':
                self.assertTrue(wall['zone_window']['solar_screen'])
            else:
                self.assertFalse(wall['zone_window']['solar_screen'])

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        window1 = self.xpath('//h:Window[h:SystemIdentifier/@id="window1"]')
        el = etree.SubElement(window1, tr_v3.addns('h:ExteriorShading'))
        etree.SubElement(el, tr_v3.addns('h:SystemIdentifier'), attrib={'id': 'ext_shading'})
        etree.SubElement(el, tr_v3.addns('h:Type')).text = 'solar screens'
        d_v3 = tr_v3.hpxml_to_hescore()

        for wall in d_v3['building']['zone']['zone_wall']:
            if wall['side'] == 'front':
                self.assertTrue(wall['zone_window']['solar_screen'])
            else:
                self.assertFalse(wall['zone_window']['solar_screen'])

    def test_skylight_solar_screens_treatments(self):
        tr = self._load_xmlfile('house4')
        glasstype = self.xpath('//h:Skylight[h:SystemIdentifier/@id="skylights"]/h:GlassType')
        el = etree.Element(tr.addns('h:Treatments'))
        el.text = 'solar screen'
        glasstype.addnext(el)
        d = tr.hpxml_to_hescore()
        self.assertTrue(d['building']['zone']['zone_roof'][0]['zone_skylight']['solar_screen'])

    def test_skylight_solar_screens_exteriorshading(self):
        tr = self._load_xmlfile('house4')
        glasstype = self.xpath('//h:Skylight[h:SystemIdentifier/@id="skylights"]/h:GlassType')
        el2 = etree.Element(tr.addns('h:ExteriorShading'))
        el2.text = 'solar screens'
        glasstype.addnext(el2)
        d = tr.hpxml_to_hescore()
        self.assertTrue(d['building']['zone']['zone_roof'][0]['zone_skylight']['solar_screen'])

    def test_ducted_hvac_combinations(self):
        '''
        Test if translator allows added heating and cooling system combinations
        '''
        # Lists of tested systems
        htg_sys_test_heating_type = ['h:Furnace']
        clg_sys_test_cooling_type = ['central air conditioning']
        hp_test_type = ['water-to-air', 'water-to-water', 'air-to-air', 'ground-to-air']

        tr = self._load_xmlfile('house4')

        # Replace dhw system to one independent to heating systems
        dhw_new_system = '<WaterHeating xmlns="http://hpxmlonline.com/2014/6">' \
                         '<WaterHeatingSystem>' \
                         '<SystemIdentifier id="dhw"/>' \
                         '<FuelType>electricity</FuelType>' \
                         '<WaterHeaterType>storage water heater</WaterHeaterType>' \
                         '<YearInstalled>1995</YearInstalled>' \
                         '<EnergyFactor>0.8</EnergyFactor>' \
                         '</WaterHeatingSystem>' \
                         '</WaterHeating>'
        dhw_el = etree.XML(dhw_new_system)
        dhw = self.xpath('//h:WaterHeating')
        dhw.addnext(dhw_el)
        dhw.getparent().remove(dhw)

        # System elements
        htg_sys = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="boiler1"]')
        clg_sys = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]')
        hp = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]')

        # system type maps between HPXML and HEScore API
        heat_pump_type_map = {'water-to-air': 'gchp',
                              'water-to-water': 'gchp',
                              'air-to-air': 'heat_pump',
                              'mini-split': 'mini_split',
                              'ground-to-air': 'gchp'}
        htg_system_type_map = {'Furnace': 'central_furnace',
                               'WallFurnace': 'wall_furnace',
                               'FloorFurnace': 'wall_furnace',
                               'Boiler': 'boiler',
                               'ElectricResistance': 'baseboard',
                               'Stove': 'wood_stove'}
        clg_system_map = {'central air conditioning': 'split_dx',
                          'room air conditioner': 'packaged_dx',
                          'evaporative cooler': 'dec'}

        # 1. Orange area test

        # Test the HPXML heating systems + heat pump cooling
        htg_sys_fuel = tr.xpath(htg_sys, 'h:HeatingSystemFuel')
        # most popular fuel type
        htg_sys_fuel.text = "natural gas"
        hvac_air_dist = self.xpath('//h:HVACDistribution[h:SystemIdentifier/@id="aircondducts"]')
        # Get distributions ready for heating and cooling systems, in case of require distribution error
        tr.xpath(hvac_air_dist, 'h:SystemIdentifier').attrib['id'] = "ducts1"
        hp_air_dist = deepcopy(hvac_air_dist)
        tr.xpath(hp_air_dist, 'h:SystemIdentifier').attrib['id'] = "ducts2"
        hvac_air_dist.getparent().append(hp_air_dist)
        tr.xpath(htg_sys, 'h:DistributionSystem').attrib['idref'] = "ducts1"
        hpdist = etree.Element(tr.addns('h:DistributionSystem'))
        hpdist.attrib['idref'] = "ducts2"
        tr.xpath(hp, 'h:YearInstalled').addnext(hpdist)

        # Change the floor area to the total conditioned area
        tr.xpath(htg_sys, 'h:FloorAreaServed').text = "3213"
        # Remove heat pump for heating (3 ways checked)
        clg_capacity = tr.xpath(hp, 'h:CoolingCapacity')

        el = etree.Element(tr.addns('h:FractionHeatLoadServed'))
        el.text = "0"
        clg_capacity.addnext(el)

        # Remove existing cooling system, only heat pump system serves cooling
        clg_sys.getparent().remove(clg_sys)

        for htg_system_type in htg_sys_test_heating_type:
            # change heating types
            htgsys_type = tr.xpath(htg_sys, 'h:HeatingSystemType')
            htgsys_type.clear()
            etree.SubElement(htgsys_type, tr.addns(htg_system_type))
            # change fuel types for specific heating systems
            if htg_system_type == "h:ElectricResistance":
                htg_sys_fuel.text = "electricity"
            elif htg_system_type == "h:Stove":
                htg_sys_fuel.text = "wood"
            for clg_system_type in hp_test_type:
                # change cooling types
                hp_type = tr.xpath(hp, 'h:HeatPumpType')
                hp_type.text = clg_system_type
                tr.xpath(hp, 'h:FloorAreaServed').text = "3213"
                self.assertRaisesRegex(
                    jsonschema.exceptions.ValidationError,
                    re.compile(f"'{heat_pump_type_map[clg_system_type]}' is not one of "
                               "['packaged_dx', 'split_dx', 'mini_split', 'dec', 'none']*"), # noqa E501
                    tr.hpxml_to_hescore
                )

        # Test HPXML cooling system + heat pump for heating
        # restore the cooling system
        clg_restore_system = '<CoolingSystem xmlns="http://hpxmlonline.com/2014/6">' \
                             '<SystemIdentifier id="centralair1"/>' \
                             '<YearInstalled>2005</YearInstalled>' \
                             '<DistributionSystem idref="ducts1"/>' \
                             '<CoolingSystemType>central air conditioning</CoolingSystemType>' \
                             '<CoolingCapacity>48000</CoolingCapacity><!-- 4 ton -->' \
                             '<FloorAreaServed>3213</FloorAreaServed>' \
                             '<AnnualCoolingEfficiency >' \
                             '<Units>SEER</Units>' \
                             '<Value>13</Value>' \
                             '</AnnualCoolingEfficiency>' \
                             '</CoolingSystem>'
        clg_el = etree.XML(clg_restore_system)
        htg_sys.addnext(clg_el)
        clg_sys = self.xpath('//h:CoolingSystem')

        # set cooling fraction as 0, remove previous 0 heating fraction
        hp_heatingfraction = tr.xpath(hp, 'h:FractionHeatLoadServed')
        el = etree.Element(tr.addns('h:FractionCoolLoadServed'))
        el.text = "0"
        hp_heatingfraction.addnext(el)
        hp_heatingfraction.getparent().remove(hp_heatingfraction)

        # remove heating system
        htg_sys.getparent().remove(htg_sys)

        for clg_system_type in clg_sys_test_cooling_type:
            # change cooling types
            clgsys_type = tr.xpath(clg_sys, 'h:CoolingSystemType')
            clgsys_type.text = clg_system_type
            # Change efficiency units in hpxml for different systems
            eff_units = {'split_dx': 'SEER',
                         'packaged_dx': 'EER',
                         'heat_pump': 'SEER',
                         'mini_split': 'SEER',
                         'gchp': 'EER',
                         'dec': None,
                         'iec': None,
                         'idec': None}[clg_system_map[clg_system_type]]
            clgsys_units = tr.xpath(clg_sys, 'h:AnnualCoolingEfficiency/h:Units')
            if eff_units is not None:
                clgsys_units.text = eff_units
            else:
                clgsys_units.getparent().getparent().remove(clgsys_units.getparent())
            for htg_system_type in hp_test_type:
                # change heating types
                hp_type = tr.xpath(hp, 'h:HeatPumpType')
                hp_type.text = htg_system_type
                tr.xpath(hp, 'h:FloorAreaServed').text = "3213"

                self.assertRaisesRegex(
                    jsonschema.exceptions.ValidationError,
                    re.compile(f"'{clg_system_map[clg_system_type]}' is not one of "
                               "['packaged_dx', 'gchp', 'dec', 'none']*"), # noqa E501
                    tr.hpxml_to_hescore
                )

        # 2. Green + red area test

        # Red area( not supported by HEScore): two heat pump systems for individual heating and cooling.
        # Remove the cooling systems in previous HPXML schema
        clg_sys.getparent().remove(clg_sys)
        # Create a new heat pump system "hp2" for cooling only
        hp2 = deepcopy(hp)
        hp.getparent().append(hp2)
        tr.xpath(hp2, 'h:SystemIdentifier').attrib['id'] = 'heatpump2'
        # Used the "ducts1" for "hp2" since the "hp" took the "ducts2"
        tr.xpath(hp2, 'h:DistributionSystem').attrib['idref'] = 'ducts1'
        # Hp2 only for cooling
        htg_fraction_el = etree.Element(tr.addns('h:FractionHeatLoadServed'))
        htg_fraction_el.text = "0"
        hp2_coolingfraction = tr.xpath(hp2, 'h:FractionCoolLoadServed')
        hp2_coolingfraction.addnext(htg_fraction_el)
        hp2_coolingfraction.getparent().remove(hp2_coolingfraction)
        # Loop the system types to separate cooling and heating systems
        for i, htg_hp_type in enumerate(hp_test_type):
            hp_type = tr.xpath(hp, 'h:HeatPumpType')
            hp_type.text = htg_hp_type
            for j, clg_hp_type in enumerate(hp_test_type):
                if j != i and heat_pump_type_map[htg_hp_type] != heat_pump_type_map[clg_hp_type]:
                    hp2_type = tr.xpath(hp2, 'h:HeatPumpType')
                    hp2_type.text = clg_hp_type
                    self.assertRaisesRegex(
                        TranslationError,
                        r'Two different heat pump systems: .+ for heating, and .+ for cooling are not supported in one hvac system.',  # noqa: E501
                        tr.hpxml_to_hescore)

        # Green area: Clg+htg heat pump
        hp2.getparent().remove(hp2)
        hp_coolingfraction = tr.xpath(hp, 'h:FractionCoolLoadServed')
        hp_coolingfraction.getparent().remove(hp_coolingfraction)
        for hp_system_type in hp_test_type:
            hp_type = tr.xpath(hp, 'h:HeatPumpType')
            hp_type.text = hp_system_type
            tr.xpath(hp, 'h:FloorAreaServed').text = "3213"
            d = tr.hpxml_to_hescore()
            # expect tested types correctly load and translated
            self.assertEqual(d['building']['systems']['hvac'][0]['cooling']['type'], heat_pump_type_map[hp_system_type])
            self.assertEqual(d['building']['systems']['hvac'][0]['heating']['type'], heat_pump_type_map[hp_system_type])

        # Green area: Clg + htg systems.
        # Reload HPXML
        tr = self._load_xmlfile('house4')

        # System elements
        htg_sys = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="boiler1"]')
        clg_sys = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]')
        hp = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]')

        # Replace dhw system to one independent to heating systems
        dhw_new_system = '<WaterHeating xmlns="http://hpxmlonline.com/2014/6">' \
                         '<WaterHeatingSystem>' \
                         '<SystemIdentifier id="dhw"/>' \
                         '<FuelType>electricity</FuelType>' \
                         '<WaterHeaterType>storage water heater</WaterHeaterType>' \
                         '<YearInstalled>1995</YearInstalled>' \
                         '<EnergyFactor>0.8</EnergyFactor>' \
                         '</WaterHeatingSystem>' \
                         '</WaterHeating>'
        dhw_el = etree.XML(dhw_new_system)
        dhw = self.xpath('//h:WaterHeating')
        dhw.addnext(dhw_el)
        dhw.getparent().remove(dhw)

        # Remove heat pump system
        hp.getparent().remove(hp)

        htg_sys_fuel = tr.xpath(htg_sys, 'h:HeatingSystemFuel')
        # most popular fuel type
        htg_sys_fuel.text = "natural gas"

        # Set up distribution systems for heating and cooling systems
        hvac_air_dist = self.xpath('//h:HVACDistribution[h:SystemIdentifier/@id="aircondducts"]')
        tr.xpath(hvac_air_dist, 'h:SystemIdentifier').attrib['id'] = "ducts1"
        clg_air_dist = deepcopy(hvac_air_dist)
        tr.xpath(clg_air_dist, 'h:SystemIdentifier').attrib['id'] = "ducts2"
        hvac_air_dist.getparent().append(clg_air_dist)
        tr.xpath(htg_sys, 'h:DistributionSystem').attrib['idref'] = "ducts1"
        tr.xpath(clg_sys, 'h:DistributionSystem').attrib['idref'] = "ducts2"

        for htg_system_type in htg_sys_test_heating_type:
            # change heating types
            htgsys_type = tr.xpath(htg_sys, 'h:HeatingSystemType')
            htgsys_type.clear()
            etree.SubElement(htgsys_type, tr.addns(htg_system_type))
            # change fuel types for specific heating systems
            if htg_system_type == "h:ElectricResistance":
                htg_sys_fuel.text = "electricity"
            elif htg_system_type == "h:Stove":
                htg_sys_fuel.text = "wood"
            for clg_system_type in clg_sys_test_cooling_type:
                # change cooling types
                clgsys_type = tr.xpath(clg_sys, 'h:CoolingSystemType')
                clgsys_type.text = clg_system_type
                # Change efficiency units in hpxml for different systems
                eff_units = {'split_dx': 'SEER',
                             'packaged_dx': 'EER',
                             'heat_pump': 'SEER',
                             'mini_split': 'SEER',
                             'gchp': 'EER',
                             'dec': None,
                             'iec': None,
                             'idec': None}[clg_system_map[clg_system_type]]
                clgsys_units = tr.xpath(clg_sys, 'h:AnnualCoolingEfficiency/h:Units')
                if eff_units is not None:
                    clgsys_units.text = eff_units
                else:
                    clgsys_units.text = 'SEER'  # In case of error, if None, it won't be translated
                d = tr.hpxml_to_hescore()
                # expect tested types correctly load and translated
                self.assertEqual(
                    d['building']['systems']['hvac'][0]['cooling']['type'],
                    clg_system_map[clg_system_type])
                self.assertEqual(d['building']['systems']['hvac'][0]['heating']
                                 ['type'], htg_system_type_map[htg_system_type[2:]])

        # Green area: Single systems.
        # single heating
        clg_sys.getparent().remove(clg_sys)
        htg_sys_fuel.text = "natural gas"
        for htg_system_type in htg_sys_test_heating_type:
            # change heating types
            htgsys_type = tr.xpath(htg_sys, 'h:HeatingSystemType')
            htgsys_type.clear()
            etree.SubElement(htgsys_type, tr.addns(htg_system_type))
            # change fuel types for specific heating systems
            if htg_system_type == "h:ElectricResistance":
                htg_sys_fuel.text = "electricity"
            elif htg_system_type == "h:Stove":
                htg_sys_fuel.text = "wood"
            d = tr.hpxml_to_hescore()
            # expect tested types correctly load and translated
            self.assertEqual(d['building']['systems']['hvac'][0]['cooling']['type'], 'none')
            self.assertEqual(d['building']['systems']['hvac'][0]['heating']['type'],
                             htg_system_type_map[htg_system_type[2:]])

        # single cooling
        # restore clg system
        clg_restore_system = '<CoolingSystem xmlns="http://hpxmlonline.com/2014/6">' \
                             '<SystemIdentifier id="centralair1"/>' \
                             '<YearInstalled>2005</YearInstalled>' \
                             '<DistributionSystem idref="ducts1"/>' \
                             '<CoolingSystemType>central air conditioning</CoolingSystemType>' \
                             '<CoolingCapacity>48000</CoolingCapacity><!-- 4 ton -->' \
                             '<FloorAreaServed>3213</FloorAreaServed>' \
                             '<AnnualCoolingEfficiency >' \
                             '<Units>SEER</Units>' \
                             '<Value>13</Value>' \
                             '</AnnualCoolingEfficiency>' \
                             '</CoolingSystem>'
        clg_el = etree.XML(clg_restore_system)
        htg_sys.addnext(clg_el)
        clg_sys = self.xpath('//h:CoolingSystem')
        htg_sys.getparent().remove(htg_sys)
        for clg_system_type in clg_sys_test_cooling_type:
            # change cooling types
            clgsys_type = tr.xpath(clg_sys, 'h:CoolingSystemType')
            clgsys_type.text = clg_system_type
            # Change efficiency units in hpxml for different systems
            eff_units = {'split_dx': 'SEER',
                         'packaged_dx': 'EER',
                         'heat_pump': 'SEER',
                         'mini_split': 'SEER',
                         'gchp': 'EER',
                         'dec': None,
                         'iec': None,
                         'idec': None}[clg_system_map[clg_system_type]]
            clgsys_units = tr.xpath(clg_sys, 'h:AnnualCoolingEfficiency/h:Units')
            if eff_units is not None:
                clgsys_units.text = eff_units
            else:
                clgsys_units.text = 'SEER'  # In case of error, if None, it won't be translated
            d = tr.hpxml_to_hescore()
            self.assertEqual(d['building']['systems']['hvac'][0]['cooling']['type'], clg_system_map[clg_system_type])
            self.assertEqual(d['building']['systems']['hvac'][0]['heating']['type'], 'none')

    def test_ductless_hvac_combinations(self):
        '''
        Test if translator allows added heating and cooling system combinations
        '''
        # Lists of tested systems
        htg_sys_test_heating_type = [
            'h:WallFurnace',
            'h:FloorFurnace',
            'h:Boiler',
            'h:ElectricResistance',
            'h:Stove']
        clg_sys_test_cooling_type = [
            'room air conditioner',
            'evaporative cooler']
        hp_test_type = ['mini-split']

        tr = self._load_xmlfile('house4')

        # Replace dhw system to one independent to heating systems
        dhw_new_system = '<WaterHeating xmlns="http://hpxmlonline.com/2014/6">' \
                         '<WaterHeatingSystem>' \
                         '<SystemIdentifier id="dhw"/>' \
                         '<FuelType>electricity</FuelType>' \
                         '<WaterHeaterType>storage water heater</WaterHeaterType>' \
                         '<YearInstalled>1995</YearInstalled>' \
                         '<EnergyFactor>0.8</EnergyFactor>' \
                         '</WaterHeatingSystem>' \
                         '</WaterHeating>'
        dhw_el = etree.XML(dhw_new_system)
        dhw = self.xpath('//h:WaterHeating')
        dhw.addnext(dhw_el)
        dhw.getparent().remove(dhw)

        # System elements
        htg_sys = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="boiler1"]')
        clg_sys = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]')
        hp = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]')

        # system type maps between HPXML and HEScore API
        heat_pump_type_map = {'water-to-air': 'gchp',
                              'water-to-water': 'gchp',
                              'air-to-air': 'heat_pump',
                              'mini-split': 'mini_split',
                              'ground-to-air': 'gchp'}
        htg_system_type_map = {'Furnace': 'central_furnace',
                               'WallFurnace': 'wall_furnace',
                               'FloorFurnace': 'wall_furnace',
                               'Boiler': 'boiler',
                               'ElectricResistance': 'baseboard',
                               'Stove': 'wood_stove'}
        clg_system_map = {'central air conditioning': 'split_dx',
                          'room air conditioner': 'packaged_dx',
                          'evaporative cooler': 'dec'}

        # Remove distribution systems
        hvac = self.xpath('//h:HVAC')
        htg_sys_dist_sys = tr.xpath(htg_sys, 'h:DistributionSystem')
        htg_sys_dist_sys.getparent().remove(htg_sys_dist_sys)
        clg_sys_dist_sys = tr.xpath(clg_sys, 'h:DistributionSystem')
        clg_sys_dist_sys.getparent().remove(clg_sys_dist_sys)
        for dist in tr.xpath(hvac, 'h:HVACDistribution'):
            dist.getparent().remove(dist)

        # 1. Orange area test

        # Test the HPXML heating systems + heat pump cooling
        htg_sys_fuel = tr.xpath(htg_sys, 'h:HeatingSystemFuel')
        # most popular fuel type
        htg_sys_fuel.text = "natural gas"

        # Change the floor area to the total conditioned area
        tr.xpath(htg_sys, 'h:FloorAreaServed').text = "3213"
        # Remove heat pump for heating (3 ways checked)
        clg_capacity = tr.xpath(hp, 'h:CoolingCapacity')

        el = etree.Element(tr.addns('h:FractionHeatLoadServed'))
        el.text = "0"
        clg_capacity.addnext(el)

        # Remove existing cooling system, only heat pump system serves cooling
        clg_sys.getparent().remove(clg_sys)

        for htg_system_type in htg_sys_test_heating_type:
            # change heating types
            htgsys_type = tr.xpath(htg_sys, 'h:HeatingSystemType')
            htgsys_type.clear()
            etree.SubElement(htgsys_type, tr.addns(htg_system_type))
            # change fuel types for specific heating systems
            if htg_system_type == "h:ElectricResistance":
                htg_sys_fuel.text = "electricity"
            elif htg_system_type == "h:Stove":
                htg_sys_fuel.text = "wood"
            for clg_system_type in hp_test_type:
                # change cooling types
                hp_type = tr.xpath(hp, 'h:HeatPumpType')
                hp_type.text = clg_system_type
                tr.xpath(hp, 'h:FloorAreaServed').text = "3213"
                d = tr.hpxml_to_hescore()
                # expect tested types correctly load and translated
                self.assertEqual(d['building']['systems']['hvac'][0]['heating']['type'],
                                 htg_system_type_map[htg_system_type[2:]])
                self.assertEqual(d['building']['systems']['hvac'][0]['cooling']['type'],
                                 heat_pump_type_map[clg_system_type])

        # Test HPXML cooling system + heat pump for heating
        # restore the cooling system
        clg_restore_system = '<CoolingSystem xmlns="http://hpxmlonline.com/2014/6">' \
                             '<SystemIdentifier id="centralair1"/>' \
                             '<YearInstalled>2005</YearInstalled>' \
                             '<CoolingSystemType>central air conditioning</CoolingSystemType>' \
                             '<CoolingCapacity>48000</CoolingCapacity><!-- 4 ton -->' \
                             '<FloorAreaServed>3213</FloorAreaServed>' \
                             '<AnnualCoolingEfficiency >' \
                             '<Units>SEER</Units>' \
                             '<Value>13</Value>' \
                             '</AnnualCoolingEfficiency>' \
                             '</CoolingSystem>'
        clg_el = etree.XML(clg_restore_system)
        htg_sys.addnext(clg_el)
        clg_sys = self.xpath('//h:CoolingSystem')

        # set cooling fraction as 0, remove previous 0 heating fraction
        hp_heatingfraction = tr.xpath(hp, 'h:FractionHeatLoadServed')
        el = etree.Element(tr.addns('h:FractionCoolLoadServed'))
        el.text = "0"
        hp_heatingfraction.addnext(el)
        hp_heatingfraction.getparent().remove(hp_heatingfraction)

        # remove heating system
        htg_sys.getparent().remove(htg_sys)

        for clg_system_type in clg_sys_test_cooling_type:
            # change cooling types
            clgsys_type = tr.xpath(clg_sys, 'h:CoolingSystemType')
            clgsys_type.text = clg_system_type
            # Change efficiency units in hpxml for different systems
            eff_units = {'split_dx': 'SEER',
                         'packaged_dx': 'EER',
                         'heat_pump': 'SEER',
                         'mini_split': 'SEER',
                         'gchp': 'EER',
                         'dec': None,
                         'iec': None,
                         'idec': None}[clg_system_map[clg_system_type]]
            clgsys_units = tr.xpath(clg_sys, 'h:AnnualCoolingEfficiency/h:Units')
            if eff_units is not None:
                clgsys_units.text = eff_units
            else:
                clgsys_units.getparent().getparent().remove(clgsys_units.getparent())
            for htg_system_type in hp_test_type:
                # change heating types
                hp_type = tr.xpath(hp, 'h:HeatPumpType')
                hp_type.text = htg_system_type
                tr.xpath(hp, 'h:FloorAreaServed').text = "3213"
                d = tr.hpxml_to_hescore()
                # expect tested types correctly load and translated
                self.assertEqual(d['building']['systems']['hvac'][0]['cooling']['type'],
                                 clg_system_map[clg_system_type])
                self.assertEqual(d['building']['systems']['hvac'][0]['heating']['type'],
                                 heat_pump_type_map[htg_system_type])

        # 2. Green + red area test

        # Red area( not supported by HEScore): two heat pump systems for individual heating and cooling.
        # Remove the cooling systems in previous HPXML schema
        clg_sys.getparent().remove(clg_sys)
        # Create a new heat pump system "hp2" for cooling only
        hp2 = deepcopy(hp)
        hp.getparent().append(hp2)
        tr.xpath(hp2, 'h:SystemIdentifier').attrib['id'] = 'heatpump2'
        # Hp2 only for cooling
        htg_fraction_el = etree.Element(tr.addns('h:FractionHeatLoadServed'))
        htg_fraction_el.text = "0"
        hp2_coolingfraction = tr.xpath(hp2, 'h:FractionCoolLoadServed')
        hp2_coolingfraction.addnext(htg_fraction_el)
        hp2_coolingfraction.getparent().remove(hp2_coolingfraction)
        # Loop the system types to separate cooling and heating systems
        for i, htg_hp_type in enumerate(hp_test_type):
            hp_type = tr.xpath(hp, 'h:HeatPumpType')
            hp_type.text = htg_hp_type
            for j, clg_hp_type in enumerate(hp_test_type):
                if j != i and heat_pump_type_map[htg_hp_type] != heat_pump_type_map[clg_hp_type]:
                    hp2_type = tr.xpath(hp2, 'h:HeatPumpType')
                    hp2_type.text = clg_hp_type
                    self.assertRaisesRegex(
                        TranslationError,
                        r'Two different heat pump systems: .+ for heating, and .+ for cooling are not supported in one hvac system.',  # noqa: E501
                        tr.hpxml_to_hescore)

        # Green area: Clg+htg heat pump
        hp2.getparent().remove(hp2)
        hp_coolingfraction = tr.xpath(hp, 'h:FractionCoolLoadServed')
        hp_coolingfraction.getparent().remove(hp_coolingfraction)
        for hp_system_type in hp_test_type:
            hp_type = tr.xpath(hp, 'h:HeatPumpType')
            hp_type.text = hp_system_type
            tr.xpath(hp, 'h:FloorAreaServed').text = "3213"
            d = tr.hpxml_to_hescore()
            # expect tested types correctly load and translated
            self.assertEqual(d['building']['systems']['hvac'][0]['cooling']['type'], heat_pump_type_map[hp_system_type])
            self.assertEqual(d['building']['systems']['hvac'][0]['heating']['type'], heat_pump_type_map[hp_system_type])

        # Green area: Clg + htg systems.
        # Reload HPXML
        tr = self._load_xmlfile('house4')

        # System elements
        htg_sys = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="boiler1"]')
        clg_sys = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]')
        hp = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]')

        # Replace dhw system to one independent to heating systems
        dhw_new_system = '<WaterHeating xmlns="http://hpxmlonline.com/2014/6">' \
                         '<WaterHeatingSystem>' \
                         '<SystemIdentifier id="dhw"/>' \
                         '<FuelType>electricity</FuelType>' \
                         '<WaterHeaterType>storage water heater</WaterHeaterType>' \
                         '<YearInstalled>1995</YearInstalled>' \
                         '<EnergyFactor>0.8</EnergyFactor>' \
                         '</WaterHeatingSystem>' \
                         '</WaterHeating>'
        dhw_el = etree.XML(dhw_new_system)
        dhw = self.xpath('//h:WaterHeating')
        dhw.addnext(dhw_el)
        dhw.getparent().remove(dhw)

        # Remove heat pump system
        hp.getparent().remove(hp)

        htg_sys_fuel = tr.xpath(htg_sys, 'h:HeatingSystemFuel')
        # most popular fuel type
        htg_sys_fuel.text = "natural gas"

        # Remove distribution systems
        hvac = self.xpath('//h:HVAC')
        htg_sys_dist_sys = tr.xpath(htg_sys, 'h:DistributionSystem')
        htg_sys_dist_sys.getparent().remove(htg_sys_dist_sys)
        clg_sys_dist_sys = tr.xpath(clg_sys, 'h:DistributionSystem')
        clg_sys_dist_sys.getparent().remove(clg_sys_dist_sys)
        for dist in tr.xpath(hvac, 'h:HVACDistribution'):
            dist.getparent().remove(dist)

        for htg_system_type in htg_sys_test_heating_type:
            # change heating types
            htgsys_type = tr.xpath(htg_sys, 'h:HeatingSystemType')
            htgsys_type.clear()
            etree.SubElement(htgsys_type, tr.addns(htg_system_type))
            # change fuel types for specific heating systems
            if htg_system_type == "h:ElectricResistance":
                htg_sys_fuel.text = "electricity"
            elif htg_system_type == "h:Stove":
                htg_sys_fuel.text = "wood"
            for clg_system_type in clg_sys_test_cooling_type:
                # change cooling types
                clgsys_type = tr.xpath(clg_sys, 'h:CoolingSystemType')
                clgsys_type.text = clg_system_type
                # Change efficiency units in hpxml for different systems
                eff_units = {'split_dx': 'SEER',
                             'packaged_dx': 'EER',
                             'heat_pump': 'SEER',
                             'mini_split': 'SEER',
                             'gchp': 'EER',
                             'dec': None,
                             'iec': None,
                             'idec': None}[clg_system_map[clg_system_type]]
                clgsys_units = tr.xpath(clg_sys, 'h:AnnualCoolingEfficiency/h:Units')
                if eff_units is not None:
                    clgsys_units.text = eff_units
                else:
                    clgsys_units.text = 'SEER'  # In case of error, if None, it won't be translated
                d = tr.hpxml_to_hescore()
                # expect tested types correctly load and translated
                self.assertEqual(
                    d['building']['systems']['hvac'][0]['cooling']['type'],
                    clg_system_map[clg_system_type])
                self.assertEqual(d['building']['systems']['hvac'][0]['heating']
                                 ['type'], htg_system_type_map[htg_system_type[2:]])

        # Green area: Single systems.
        # single heating
        clg_sys.getparent().remove(clg_sys)
        htg_sys_fuel.text = "natural gas"
        for htg_system_type in htg_sys_test_heating_type:
            # change heating types
            htgsys_type = tr.xpath(htg_sys, 'h:HeatingSystemType')
            htgsys_type.clear()
            etree.SubElement(htgsys_type, tr.addns(htg_system_type))
            # change fuel types for specific heating systems
            if htg_system_type == "h:ElectricResistance":
                htg_sys_fuel.text = "electricity"
            elif htg_system_type == "h:Stove":
                htg_sys_fuel.text = "wood"
            d = tr.hpxml_to_hescore()
            # expect tested types correctly load and translated
            self.assertEqual(d['building']['systems']['hvac'][0]['cooling']['type'], 'none')
            self.assertEqual(d['building']['systems']['hvac'][0]['heating']['type'],
                             htg_system_type_map[htg_system_type[2:]])

        # single cooling
        # restore clg system
        clg_restore_system = '<CoolingSystem xmlns="http://hpxmlonline.com/2014/6">' \
                             '<SystemIdentifier id="centralair1"/>' \
                             '<YearInstalled>2005</YearInstalled>' \
                             '<CoolingSystemType>central air conditioning</CoolingSystemType>' \
                             '<CoolingCapacity>48000</CoolingCapacity><!-- 4 ton -->' \
                             '<FloorAreaServed>3213</FloorAreaServed>' \
                             '<AnnualCoolingEfficiency >' \
                             '<Units>SEER</Units>' \
                             '<Value>13</Value>' \
                             '</AnnualCoolingEfficiency>' \
                             '</CoolingSystem>'
        clg_el = etree.XML(clg_restore_system)
        htg_sys.addnext(clg_el)
        clg_sys = self.xpath('//h:CoolingSystem')
        htg_sys.getparent().remove(htg_sys)
        for clg_system_type in clg_sys_test_cooling_type:
            # change cooling types
            clgsys_type = tr.xpath(clg_sys, 'h:CoolingSystemType')
            clgsys_type.text = clg_system_type
            # Change efficiency units in hpxml for different systems
            eff_units = {'split_dx': 'SEER',
                         'packaged_dx': 'EER',
                         'heat_pump': 'SEER',
                         'mini_split': 'SEER',
                         'gchp': 'EER',
                         'dec': None,
                         'iec': None,
                         'idec': None}[clg_system_map[clg_system_type]]
            clgsys_units = tr.xpath(clg_sys, 'h:AnnualCoolingEfficiency/h:Units')
            if eff_units is not None:
                clgsys_units.text = eff_units
            else:
                clgsys_units.text = 'SEER'  # In case of error, if None, it won't be translated
            d = tr.hpxml_to_hescore()
            self.assertEqual(d['building']['systems']['hvac'][0]['cooling']['type'], clg_system_map[clg_system_type])
            self.assertEqual(d['building']['systems']['hvac'][0]['heating']['type'], 'none')

        # Red area: No system.
        # If no hvac system existing, should give a error message describing the problem.
        clg_sys.getparent().remove(clg_sys)
        self.assertRaisesRegex(TranslationError,
                               'No hvac system found.',
                               tr.hpxml_to_hescore)

    def test_bldg_about_comment(self):
        tr = self._load_xmlfile('house4')
        project_el = etree.Element(tr.addns('h:Project'))
        building_el = self.xpath('//h:Building')
        building_el.addnext(project_el)
        etree.SubElement(project_el, tr.addns('h:BuildingID'))
        etree.SubElement(
            etree.SubElement(
                project_el,
                tr.addns('h:ProjectDetails')),
            tr.addns('h:ProjectSystemIdentifiers'))
        etree.SubElement(self.xpath('//h:ProjectDetails'), tr.addns('h:Notes')).text = 'Project comment to test'
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['about']['comments'], 'Project comment to test')
        comment = etree.SubElement(etree.SubElement(building_el, tr.addns('h:extension')), tr.addns('h:Comments'))
        comment.text = 'Any comment to test'
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['about']['comments'], 'Any comment to test')

    def test_duct_location_validation(self):
        tr = self._load_xmlfile('house1')
        # duct1:vented crawl duct2:uncond_attic duct3:cond_space
        # two duct type covered, two not
        duct3oc1 = self.xpath(
            '//h:HVACDistribution[h:SystemIdentifier/@id="ductsys1"]/h:DistributionSystemType/h:AirDistribution/h:Ducts/h:DuctLocation'  # noqa: E501
        )[1]
        duct3oc1.text = 'unvented crawlspace'
        rooftype = self.xpath('//h:Attic[h:SystemIdentifier/@id="attic1"]/h:AtticType')
        Crawtype = self.xpath('//h:Foundation[h:SystemIdentifier/@id="crawl1"]/h:FoundationType/h:Crawlspace/h:Vented')
        self.assertRaisesRegex(
            TranslationError,
            'HVAC distribution: duct3 location: unvented_crawl not exists in zone_roof/floor types.',
            tr.hpxml_to_hescore)

        duct3oc1.text = 'unconditioned basement'
        self.assertRaisesRegex(
            TranslationError,
            'HVAC distribution: duct3 location: uncond_basement not exists in zone_roof/floor types.',
            tr.hpxml_to_hescore)

        duct3oc1.text = 'conditioned space'  # set back to cond_space to avoid previous error message
        rooftype.text = 'flat roof'  # change attic type
        self.assertRaisesRegex(TranslationError,
                               'HVAC distribution: duct2 location: uncond_attic not exists in zone_roof/floor types.',
                               tr.hpxml_to_hescore)

        rooftype.text = 'vented attic'  # set back to vented_attic to avoid previous error message
        Crawtype.text = 'false'
        self.assertRaisesRegex(TranslationError,
                               'HVAC distribution: duct1 location: vented_crawl not exists in zone_roof/floor types.',
                               tr.hpxml_to_hescore)

    def test_tankless_energyfactorerror(self):
        tr = self._load_xmlfile('hescore_min')
        WHtype = self.xpath('//h:WaterHeatingSystem[h:SystemIdentifier/@id="dhw1"]/h:WaterHeaterType')
        WHtype.text = 'instantaneous water heater'
        self.assertRaisesRegex(
            TranslationError,
            r'Tankless water heater efficiency cannot be estimated by shipment weighted method\.',
            tr.hpxml_to_hescore)

    def test_tankless(self):
        tr = self._load_xmlfile('house5')
        WHtype = self.xpath('//h:WaterHeatingSystem[h:SystemIdentifier/@id="dhw1"]/h:WaterHeaterType')
        WHtype.text = 'instantaneous water heater'
        d = tr.hpxml_to_hescore()
        system = d['building']['systems']['domestic_hot_water']
        self.assertEqual(system['efficiency_method'], 'user')
        self.assertEqual(system['type'], 'tankless')
        self.assertEqual(system['fuel_primary'], 'lpg')

    # two energy factors
    def test_uef_over_ef(self):
        tr = self._load_xmlfile('house5')
        EF = self.xpath('//h:WaterHeatingSystem[h:SystemIdentifier/@id="dhw1"]/h:EnergyFactor')
        UEF = etree.Element(tr.addns('h:UniformEnergyFactor'))
        UEF.text = '0.7'
        EF.addnext(UEF)
        d = tr.hpxml_to_hescore()
        system = d['building']['systems']['domestic_hot_water']
        self.assertEqual(system['efficiency_method'], 'uef')
        self.assertAlmostEqual(system['energy_factor'], 0.7)

    def test_uef_with_tankless(self):
        tr = self._load_xmlfile('hescore_min')
        WHtype = self.xpath('//h:WaterHeatingSystem[h:SystemIdentifier/@id="dhw1"]/h:WaterHeaterType')
        WHtype.text = 'instantaneous water heater'
        UEF = etree.Element(tr.addns('h:UniformEnergyFactor'))
        UEF.text = '0.7'
        WHtype.getparent().append(UEF)
        d = tr.hpxml_to_hescore()
        system = d['building']['systems']['domestic_hot_water']
        self.assertEqual(system['efficiency_method'], 'uef')
        self.assertEqual(system['type'], 'tankless')
        self.assertEqual(system['fuel_primary'], 'natural_gas')
        self.assertAlmostEqual(system['energy_factor'], 0.7)

    def test_conditioned_attic(self):
        tr = self._load_xmlfile('house4')
        attic = self.xpath('//h:Attic[h:SystemIdentifier/@id="attic1"]')
        attic_type = self.xpath('//h:Attic[h:SystemIdentifier/@id="attic1"]/h:AtticType')
        attic_type.text = 'other'
        self.assertRaisesRegex(
            TranslationError,
            r'Attic attic1: Cannot translate HPXML AtticType other to HEScore rooftype.',
            tr.hpxml_to_hescore
        )
        is_attic_cond = etree.SubElement(etree.SubElement(attic, tr.addns('h:extension')), tr.addns('h:Conditioned'))
        is_attic_cond.text = 'true'
        d = tr.hpxml_to_hescore()
        roof_type = d['building']['zone']['zone_roof'][0]['roof_type']
        self.assertEqual(roof_type, 'cond_attic')
        is_attic_cond.text = 'false'
        self.assertRaisesRegex(
            TranslationError,
            r'Attic \w+: Cannot translate HPXML AtticType other to HEScore rooftype.',
            tr.hpxml_to_hescore
        )
        attic_type.text = 'vented attic'
        is_attic_cond.text = 'true'
        d = tr.hpxml_to_hescore()
        roof_type = d['building']['zone']['zone_roof'][0]['roof_type']
        self.assertEqual(roof_type, 'vented_attic')

    def test_hpwes(self):
        tr = self._load_xmlfile('hescore_min')
        E = self.element_maker()
        building_el = self.xpath('//h:Building')
        hpxml_building_id = self.xpath('h:Building/h:BuildingID/@id')
        project_el = E.Project(
            E.BuildingID(id=str(hpxml_building_id)),
            E.ProjectDetails(
                E.ProjectSystemIdentifiers(),
                E.StartDate('2017-08-20'),
                E.CompleteDateActual('2018-12-14')
            )
        )
        building_el.addnext(project_el)

        # Add the contractor
        contractor_el = E.Contractor(
            E.ContractorDetails(
                E.SystemIdentifier(id='c1'),
                E.BusinessInfo(
                    E.SystemIdentifier(id='business'),
                    E.BusinessName('Contractor Business 1'),
                    E.extension(
                        E.ZipCode('12345')
                    )
                )
            )
        )
        building_el.addprevious(contractor_el)
        res = tr.hpxml_to_hescore()

        # Project not HPwES, nothing passed
        self.assertNotIn('hpwes', res)

        # Change to HPwES project
        objectify.ObjectPath('Project.ProjectDetails.ProjectSystemIdentifiers').\
            find(project_el).\
            addnext(E.ProgramCertificate('Home Performance with Energy Star'))

        res3 = tr.hpxml_to_hescore()

        self.assertEqual(res3['hpwes']['improvement_installation_start_date'], '2017-08-20')
        self.assertEqual(res3['hpwes']['improvement_installation_completion_date'], '2018-12-14')
        self.assertEqual(res3['hpwes']['contractor_business_name'], 'Contractor Business 1')
        self.assertEqual(res3['hpwes']['contractor_zip_code'], '12345')

        contractor_el2 = E.Contractor(
            E.ContractorDetails(
                E.SystemIdentifier(id='c2'),
                E.BusinessInfo(
                    E.SystemIdentifier(id='business2'),
                    E.BusinessName('Contractor Business 2'),
                    E.extension(
                        E.ZipCode('80401')
                    )
                )
            )
        )
        contractor_el.addnext(contractor_el2)
        site_el = self.xpath('//h:Building/h:Site')
        site_el.addnext(
            E.ContractorID(id='c2')
        )

        res4 = tr.hpxml_to_hescore()

        self.assertEqual(res4['hpwes']['improvement_installation_start_date'], '2017-08-20')
        self.assertEqual(res4['hpwes']['improvement_installation_completion_date'], '2018-12-14')
        self.assertEqual(res4['hpwes']['contractor_business_name'], 'Contractor Business 2')
        self.assertEqual(res4['hpwes']['contractor_zip_code'], '80401')

        # HPXML V3
        tr_v3 = self._load_xmlfile('hescore_min_v3')
        E = self.element_maker()
        building_el = self.xpath('//h:Building')
        hpxml_building_id = self.xpath('h:Building/h:BuildingID/@id')
        project_el = E.Project(
            E.ProjectID(id='p1'),
            E.PreBuildingID(id=str(hpxml_building_id)),
            E.PostBuildingID(id=str(hpxml_building_id)),
            E.ProjectDetails(
                E.StartDate('2017-08-20'),
                E.CompleteDateActual('2018-12-14')
            )
        )
        building_el.addnext(project_el)

        # Add the contractor
        contractor_el = E.Contractor(
            E.ContractorDetails(
                E.SystemIdentifier(id='c1'),
                E.BusinessInfo(
                    E.SystemIdentifier(id='business'),
                    E.BusinessName('Contractor Business 1'),
                    E.extension(
                        E.ZipCode('12345')
                    )
                )
            )
        )
        building_el.addprevious(contractor_el)
        res = tr_v3.hpxml_to_hescore()

        # Project not HPwES, nothing passed
        self.assertNotIn('hpwes', res)

        # Change to HPwES under green building verification element
        hpwes_el = E.GreenBuildingVerifications(
            E.GreenBuildingVerification(
                E.SystemIdentifier(id='verification1'),
                E.Type('Home Performance with ENERGY STAR')
            )
        )
        bldg_summary_el = self.xpath('//h:BuildingSummary')
        bldg_summary_el.addnext(hpwes_el)

        res3_v3 = tr_v3.hpxml_to_hescore()

        self.assertEqual(res3['hpwes'], res3_v3['hpwes'])

        contractor_el2 = E.Contractor(
            E.ContractorDetails(
                E.SystemIdentifier(id='c2'),
                E.BusinessInfo(
                    E.SystemIdentifier(id='business2'),
                    E.BusinessName('Contractor Business 2'),
                    E.extension(
                        E.ZipCode('80401')
                    )
                )
            )
        )
        contractor_el.addnext(contractor_el2)
        site_el = self.xpath('//h:Building/h:Site')
        site_el.addnext(
            E.ContractorID(id='c2')
        )

        res4_v3 = tr_v3.hpxml_to_hescore()

        self.assertEqual(res4['hpwes'], res4_v3['hpwes'])

    def test_hpwes_fail(self):
        tr = self._load_xmlfile('hescore_min')
        E = self.element_maker()
        building_el = self.xpath('//h:Building')
        hpxml_building_id = self.xpath('h:Building/h:BuildingID/@id')
        project_el = E.Project(
            E.BuildingID(id=str(hpxml_building_id)),
            E.ProjectDetails(
                E.ProjectSystemIdentifiers(),
                E.ProgramCertificate('Home Performance with Energy Star')
            )
        )
        building_el.addnext(project_el)

        self.assertRaisesRegex(
            TranslationError,
            r'The following elements are required.*StartDate.*CompleteDateActual.*BusinessName.*ZipCode',
            tr.hpxml_to_hescore
        )

    def test_window_code_mappings_aluminum(self):
        tr = self._load_xmlfile('hescore_min')
        E = self.element_maker()

        window2_frametype = self.xpath('//h:Window[h:SystemIdentifier/@id="window2"]/h:FrameType')
        window2_frametype.clear()
        window2_frametype.append(E.Aluminum())
        window2_frametype.getparent().append(E.GlassType('low-e'))

        window3_frametype = self.xpath('//h:Window[h:SystemIdentifier/@id="window3"]/h:FrameType')
        window3_frametype.clear()
        window3_frametype.append(E.Aluminum(E.ThermalBreak("true")))

        window4_frametype = self.xpath('//h:Window[h:SystemIdentifier/@id="window4"]/h:FrameType')
        window4_frametype.clear()
        window4_frametype.append(E.Aluminum(E.ThermalBreak("true")))
        window4_frametype.getparent().append(E.GlassType('low-e'))

        d = tr.hpxml_to_hescore()
        walls = {}
        for wall in d['building']['zone']['zone_wall']:
            walls[wall['side']] = wall
        self.assertEqual(
            walls['left']['zone_window']['window_code'],
            'dseaa'
        )
        self.assertEqual(
            walls['back']['zone_window']['window_code'],
            'dcab'
        )
        self.assertEqual(
            walls['right']['zone_window']['window_code'],
            'dseab'
        )

        tr_v3 = self._load_xmlfile('hescore_min_v3')
        E = self.element_maker()

        window2_frametype = self.xpath('//h:Window[h:SystemIdentifier/@id="window2"]/h:FrameType')
        window2_frametype.clear()
        window2_frametype.append(E.Aluminum())
        window2_frametype.getparent().append(E.GlassType('low-e'))

        window3_frametype = self.xpath('//h:Window[h:SystemIdentifier/@id="window3"]/h:FrameType')
        window3_frametype.clear()
        window3_frametype.append(E.Aluminum(E.ThermalBreak("true")))

        window4_frametype = self.xpath('//h:Window[h:SystemIdentifier/@id="window4"]/h:FrameType')
        window4_frametype.clear()
        window4_frametype.append(E.Aluminum(E.ThermalBreak("true")))
        window4_frametype.getparent().append(E.GlassType('low-e'))

        d_v3 = tr_v3.hpxml_to_hescore()
        walls_v3 = {}
        for wall in d_v3['building']['zone']['zone_wall']:
            walls_v3[wall['side']] = wall
        self.assertEqual(walls_v3, walls)

    def test_mini_split_cooling_only(self):
        tr = self._load_xmlfile('hescore_min')
        E = self.element_maker()

        # cooling system type: mini-split + heating system
        clg_type = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]/h:CoolingSystemType')
        clg_type.getparent().remove(
            self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]/h:DistributionSystem'))
        clg_type.text = 'mini-split'

        d_1 = tr.hpxml_to_hescore()
        self.assertEqual(d_1['building']['systems']['hvac'][0]['cooling']['type'], 'mini_split')
        self.assertEqual(d_1['building']['systems']['hvac'][0]['heating']['type'], 'central_furnace')

        # heatpump system type: mini-split + heating system
        heatpump = E.HeatPump(
            E.SystemIdentifier(id='heatpump1'),
            E.YearInstalled('2005'),
            E.HeatPumpType('mini-split'),
            E.HeatingCapacity('18000'),
            E.CoolingCapacity('18000'),
            E.FractionHeatLoadServed('0'),
            E.FractionCoolLoadServed('1.0'),
            E.AnnualCoolEfficiency(E.Units('SEER'), E.Value('15')),
            E.AnnualHeatEfficiency(E.Units('HSPF'), E.Value('8.2'))
        )
        clg_sys = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]')
        clg_sys.addnext(heatpump)
        clg_sys.getparent().remove(clg_sys)
        # Add fraction to heating system for system weight calculation
        htg_sys = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="furnace1"]')
        htg_sys.append(E.FractionHeatLoadServed('1.0'))
        d_2 = tr.hpxml_to_hescore()
        self.assertEqual(d_2['building']['systems']['hvac'][0]['cooling']['type'], 'mini_split')
        self.assertEqual(d_2['building']['systems']['hvac'][0]['heating']['type'], 'central_furnace')

        # clg system mini-split + heatpump for heating: should give error for two different heat pump systems
        clg_sys = E.CoolingSystem(
            E.SystemIdentifier(id='centralair'),
            E.YearInstalled('2005'),
            E.CoolingSystemType('mini-split'),
            E.FractionCoolLoadServed('1.0'),
            E.AnnualCoolingEfficiency(E.Units('SEER'), E.Value('13')),
        )
        heatpump.addprevious(clg_sys)
        htg_sys.getparent().remove(htg_sys)
        heatpump_fraction_htg = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:FractionHeatLoadServed')
        heatpump_fraction_clg = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:FractionCoolLoadServed')
        heatpump_fraction_htg.text = '1.0'
        heatpump_fraction_clg.text = '0.0'
        heatpump_type = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:HeatPumpType')
        heatpump_type.text = 'air-to-air'
        heatpump_type.addprevious(E.DistributionSystem(idref='hvacd1'))
        self.assertRaisesRegex(
            TranslationError,
            r'Two different heat pump systems: .+ for heating, and .+ for cooling are not supported in one hvac system.', # noqa E501
            tr.hpxml_to_hescore)

        # heatpump system type: mini-split + other cooling system
        clg_sys_type = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair"]/h:CoolingSystemType')
        clg_sys_type.text = 'central air conditioning'
        clg_sys_type.addprevious(E.DistributionSystem(idref='hvacd1'))
        heatpump_type.text = 'mini-split'
        heatpump.remove(self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:DistributionSystem'))
        self.assertRaisesRegex(
            jsonschema.exceptions.ValidationError,
            r"'split_dx' is not one of ['packaged_dx', 'mini_split', 'dec', 'none']*", # noqa E501
            tr.hpxml_to_hescore
        )

        # heatpump system type: mini-split
        clg_sys.getparent().remove(clg_sys)
        heatpump.remove(heatpump_fraction_clg)
        heatpump.remove(heatpump_fraction_htg)
        d_4 = tr.hpxml_to_hescore()
        self.assertEqual(d_4['building']['systems']['hvac'][0]['cooling']['type'], 'mini_split')
        self.assertEqual(d_4['building']['systems']['hvac'][0]['heating']['type'], 'mini_split')

        # HPXML V3
        tr_v3 = self._load_xmlfile('hescore_min_v3')
        E = self.element_maker()

        # cooling system type: mini-split + heating system
        clg_type = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]/h:CoolingSystemType')
        clg_type.getparent().remove(
            self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]/h:DistributionSystem'))
        clg_type.text = 'mini-split'

        d_1_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d_1['building']['systems']['hvac'], d_1_v3['building']['systems']['hvac'])

        # heatpump system type: mini-split + heating system
        heatpump = E.HeatPump(
            E.SystemIdentifier(id='heatpump1'),
            E.YearInstalled('2005'),
            E.HeatPumpType('mini-split'),
            E.HeatingCapacity('18000'),
            E.CoolingCapacity('18000'),
            E.FractionHeatLoadServed('0'),
            E.FractionCoolLoadServed('1.0'),
            E.AnnualCoolingEfficiency(E.Units('SEER'), E.Value('15')),
            E.AnnualHeatingEfficiency(E.Units('HSPF'), E.Value('8.2'))
        )
        clg_sys = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]')
        clg_sys.addnext(heatpump)
        clg_sys.getparent().remove(clg_sys)
        # Add fraction to heating system for system weight calculation
        htg_sys = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="furnace1"]')
        htg_sys.append(E.FractionHeatLoadServed('1.0'))
        d_2_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d_2['building']['systems']['hvac'], d_2_v3['building']['systems']['hvac'])

        # clg system mini-split + heatpump for heating: should give error for two different heat pump systems
        clg_sys = E.CoolingSystem(
            E.SystemIdentifier(id='centralair'),
            E.YearInstalled('2005'),
            E.CoolingSystemType('mini-split'),
            E.FractionCoolLoadServed('1.0'),
            E.AnnualCoolingEfficiency(E.Units('SEER'), E.Value('13')),
        )
        heatpump.addprevious(clg_sys)
        htg_sys.getparent().remove(htg_sys)
        heatpump_fraction_htg = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:FractionHeatLoadServed')
        heatpump_fraction_clg = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:FractionCoolLoadServed')
        heatpump_fraction_htg.text = '1.0'
        heatpump_fraction_clg.text = '0.0'
        heatpump_type = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:HeatPumpType')
        heatpump_type.text = 'air-to-air'
        heatpump_type.addprevious(E.DistributionSystem(idref='hvacd1'))
        self.assertRaisesRegex(
            TranslationError,
            r'Two different heat pump systems: .+ for heating, and .+ for cooling are not supported in one hvac system.', # noqa E501
            tr_v3.hpxml_to_hescore)

        # heatpump system type: mini-split + other cooling system
        clg_sys_type = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair"]/h:CoolingSystemType')
        clg_sys_type.text = 'central air conditioner'
        clg_sys_type.addprevious(E.DistributionSystem(idref='hvacd1'))
        heatpump_type.text = 'mini-split'
        heatpump.remove(self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:DistributionSystem'))
        self.assertRaisesRegex(
            jsonschema.exceptions.ValidationError,
            r"'split_dx' is not one of ['packaged_dx', 'mini_split', 'dec', 'none']*", # noqa E501
            tr_v3.hpxml_to_hescore
        )

        # heatpump system type: mini-split
        clg_sys.getparent().remove(clg_sys)
        heatpump.remove(heatpump_fraction_clg)
        heatpump.remove(heatpump_fraction_htg)
        d_4_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d_4['building']['systems']['hvac'], d_4_v3['building']['systems']['hvac'])


class TestHEScore2021Updates(unittest.TestCase, ComparatorBase):

    def test_skylight_assignment(self):
        tr = self._load_xmlfile('house4_v3')
        attach_roof = etree.Element(tr.addns('h:AttachedToRoof'))
        attach_roof.attrib['idref'] = "roof2"
        glass_type = self.xpath('//h:Skylight/h:GlassType')
        glass_type.addnext(attach_roof)
        res = tr.hpxml_to_hescore()
        # Skylight attached to the second roof
        self.assertEqual(res['building']['zone']['zone_roof'][1]['zone_skylight']['skylight_area'], 12.0)
        self.assertEqual(res['building']['zone']['zone_roof'][1]['zone_skylight']['skylight_code'], 'dtab')
        self.assertFalse(res['building']['zone']['zone_roof'][1]['zone_skylight']['solar_screen'])

        skylight = self.xpath('//h:Skylight')
        skylight_2 = deepcopy(skylight)
        skylight.addnext(skylight_2)
        tr.xpath(skylight_2, 'h:SystemIdentifier').attrib['id'] = "skylight2"
        tr.xpath(skylight_2, 'h:AttachedToRoof').attrib['idref'] = "roof1"
        tr.xpath(skylight_2, 'h:Area').text = "15"
        res2 = tr.hpxml_to_hescore()
        # Skylight attached to the first and second roof
        self.assertEqual(res2['building']['zone']['zone_roof'][0]['zone_skylight']['skylight_area'], 15.0)
        self.assertEqual(res2['building']['zone']['zone_roof'][0]['zone_skylight']['skylight_code'], 'dtab')
        self.assertFalse(res2['building']['zone']['zone_roof'][0]['zone_skylight']['solar_screen'])
        self.assertEqual(res2['building']['zone']['zone_roof'][1]['zone_skylight']['skylight_area'], 12.0)
        self.assertEqual(res2['building']['zone']['zone_roof'][1]['zone_skylight']['skylight_code'], 'dtab')
        self.assertFalse(res2['building']['zone']['zone_roof'][1]['zone_skylight']['solar_screen'])

        tr.xpath(skylight_2, 'h:AttachedToRoof').attrib['idref'] = "roof2"
        tr.xpath(skylight_2, 'h:Area').text = "10"
        tr.xpath(skylight_2, 'h:GlassType').text = "low-e"
        # skylight1 dominates the properties
        res3 = tr.hpxml_to_hescore()
        self.assertEqual(res3['building']['zone']['zone_roof'][1]['zone_skylight']['skylight_area'], 22.0)
        self.assertEqual(res3['building']['zone']['zone_roof'][1]['zone_skylight']['skylight_code'], 'dtab')
        self.assertFalse(res3['building']['zone']['zone_roof'][1]['zone_skylight']['solar_screen'])

    def test_xps_negative(self):
        tr = self._load_xmlfile('hescore_min_v3')
        wall = self.xpath('//h:Wall[h:SystemIdentifier/@id="wall1"]')
        tr.xpath(wall, 'h:Insulation/h:Layer/h:NominalRValue').text = "0"
        wood_stud = tr.xpath(wall, 'descendant::h:WoodStud')
        xps_el = etree.Element(tr.addns('h:ExpandedPolystyreneSheathing'))
        xps_el.text = 'true'
        wood_stud.append(xps_el)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['zone']['zone_wall'][0]['wall_assembly_code'], 'ewps00br')

    def test_zip_plus4(self):
        tr = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:ZipCode')
        orig_zipcode = str(el.text)
        el.text = el.text + '-1234'
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building_address']['zip_code'], orig_zipcode)


class TestHEScoreV3(unittest.TestCase, ComparatorBase):

    def test_attic_with_multiple_roofs(self):
        tr = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:Attic/h:AttachedToRoof')
        roof = self.xpath('//h:Roof')
        roof_area = etree.Element(tr.addns('h:Area'))
        roof_area.text = '600'
        self.xpath('//h:Roof/h:SystemIdentifier').addnext(roof_area)
        self.xpath('//h:Roof/h:Insulation/h:Layer/h:NominalRValue').text = '2'
        roof_2 = deepcopy(roof)
        tr.xpath(roof_2, 'h:SystemIdentifier').attrib['id'] = "roof2"
        tr.xpath(roof_2, 'h:Insulation/h:SystemIdentifier').attrib['id'] = "attic1roofins2"
        tr.xpath(roof_2, 'h:Insulation/h:Layer/h:NominalRValue').text = '6'
        roof.addnext(roof_2)
        el_2 = deepcopy(el)
        el_2.attrib['idref'] = "roof2"
        el.addnext(el_2)
        res = tr.hpxml_to_hescore()
        # Currently, roofs attached to the same attic are combined.
        self.assertEqual(res['building']['zone']['zone_roof'][0]['roof_assembly_code'], 'rfwf00co')
        self.xpath('//h:Roof[1]/h:Insulation/h:Layer/h:NominalRValue').text = '19'
        self.xpath('//h:Roof[2]/h:Insulation/h:Layer/h:NominalRValue').text = '27'
        res2 = tr.hpxml_to_hescore()
        self.assertEqual(res2['building']['zone']['zone_roof'][0]['roof_assembly_code'], 'rfwf21co')

    def test_attic_with_multiple_frame_floors(self):
        tr = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:Attic/h:AttachedToFrameFloor')
        ff = self.xpath('//h:FrameFloor')
        ff_area = tr.xpath(ff, 'h:Area')
        ff_area.text = '600'
        ff_2 = deepcopy(ff)
        tr.xpath(ff_2, 'h:SystemIdentifier').attrib['id'] = "framefloor2"
        tr.xpath(ff_2, 'h:Insulation/h:SystemIdentifier').attrib['id'] = "attic1flins2"
        tr.xpath(ff_2, 'h:Insulation/h:Layer/h:NominalRValue').text = '15'
        ff.addnext(ff_2)
        el_2 = deepcopy(el)
        el_2.attrib['idref'] = "framefloor2"
        el.addnext(el_2)
        res = tr.hpxml_to_hescore()
        # Currently, framefloor attached to the same attic are combined.
        self.assertEqual(res['building']['zone']['zone_roof'][0]['ceiling_assembly_code'], 'ecwf21')

    def test_attic_type(self):
        tr = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:Attics/h:Attic/h:AtticType/h:Attic/h:Vented')
        attic_type_el = el.getparent().getparent()
        flatroof = etree.SubElement(attic_type_el, tr.addns('h:FlatRoof'))
        attic_type_el.remove(el.getparent())
        d = tr.hpxml_to_hescore()
        self.assertEqual(d['building']['zone']['zone_roof'][0]['roof_type'], 'cath_ceiling')
        type_attic = etree.SubElement(attic_type_el, tr.addns('h:Attic'))
        etree.SubElement(type_attic, tr.addns('h:Vented')).text = "true"
        attic_type_el.remove(flatroof)
        d = tr.hpxml_to_hescore()
        self.assertEqual(d['building']['zone']['zone_roof'][0]['roof_type'], 'vented_attic')
        type_attic.remove(type_attic[0])
        etree.SubElement(type_attic, tr.addns('h:Conditioned')).text = "true"
        d = tr.hpxml_to_hescore()
        self.assertEqual(d['building']['zone']['zone_roof'][0]['roof_type'], 'cond_attic')

    def test_mini_split_cooling_only(self):
        tr = self._load_xmlfile('hescore_min_v3')
        E = self.element_maker()

        # cooling system type: mini-split + heating system
        clg_type = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]/h:CoolingSystemType')
        clg_type.getparent().remove(
            self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]/h:DistributionSystem'))
        clg_type.text = 'mini-split'

        d = tr.hpxml_to_hescore()
        self.assertEqual(d['building']['systems']['hvac'][0]['cooling']['type'], 'mini_split')
        self.assertEqual(d['building']['systems']['hvac'][0]['heating']['type'], 'central_furnace')

        # heatpump system type: mini-split + heating system
        heatpump = E.HeatPump(
            E.SystemIdentifier(id='heatpump1'),
            E.YearInstalled('2005'),
            E.HeatPumpType('mini-split'),
            E.HeatingCapacity('18000'),
            E.CoolingCapacity('18000'),
            E.FractionHeatLoadServed('0'),
            E.FractionCoolLoadServed('1.0'),
            E.AnnualCoolingEfficiency(E.Units('SEER'), E.Value('15')),
            E.AnnualHeatingEfficiency(E.Units('HSPF'), E.Value('8.2'))
        )
        clg_sys = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair1"]')
        clg_sys.addnext(heatpump)
        clg_sys.getparent().remove(clg_sys)
        # Add fraction to heating system for system weight calculation
        htg_sys = self.xpath('//h:HeatingSystem[h:SystemIdentifier/@id="furnace1"]')
        htg_sys.append(E.FractionHeatLoadServed('1.0'))
        d = tr.hpxml_to_hescore()
        self.assertEqual(d['building']['systems']['hvac'][0]['cooling']['type'], 'mini_split')
        self.assertEqual(d['building']['systems']['hvac'][0]['heating']['type'], 'central_furnace')

        # clg system mini-split + heatpump for heating: should give error for two different heat pump systems
        clg_sys = E.CoolingSystem(
            E.SystemIdentifier(id='centralair'),
            E.YearInstalled('2005'),
            E.CoolingSystemType('mini-split'),
            E.FractionCoolLoadServed('1.0'),
            E.AnnualCoolingEfficiency(E.Units('SEER'), E.Value('13')),
        )
        heatpump.addprevious(clg_sys)
        htg_sys.getparent().remove(htg_sys)
        heatpump_fraction_htg = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:FractionHeatLoadServed')
        heatpump_fraction_clg = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:FractionCoolLoadServed')
        heatpump_fraction_htg.text = '1.0'
        heatpump_fraction_clg.text = '0.0'
        heatpump_type = self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:HeatPumpType')
        heatpump_type.text = 'air-to-air'
        heatpump_type.addprevious(E.DistributionSystem(idref='hvacd1'))
        self.assertRaisesRegex(
            TranslationError,
            r'Two different heat pump systems: .+ for heating, and .+ for cooling are not supported in one hvac system.', # noqa E501
            tr.hpxml_to_hescore)

        # heatpump system type: mini-split + other cooling system
        clg_sys_type = self.xpath('//h:CoolingSystem[h:SystemIdentifier/@id="centralair"]/h:CoolingSystemType')
        clg_sys_type.text = 'central air conditioner'
        clg_sys_type.addprevious(E.DistributionSystem(idref='hvacd1'))
        heatpump_type.text = 'mini-split'
        heatpump.remove(self.xpath('//h:HeatPump[h:SystemIdentifier/@id="heatpump1"]/h:DistributionSystem'))
        self.assertRaisesRegex(
            jsonschema.exceptions.ValidationError,
            r"'split_dx' is not one of ['packaged_dx', 'mini_split', 'dec', 'none']*", # noqa E501
            tr.hpxml_to_hescore
        )

        # heatpump system type: mini-split
        clg_sys.getparent().remove(clg_sys)
        heatpump.remove(heatpump_fraction_clg)
        heatpump.remove(heatpump_fraction_htg)
        d = tr.hpxml_to_hescore()
        self.assertEqual(d['building']['systems']['hvac'][0]['cooling']['type'], 'mini_split')
        self.assertEqual(d['building']['systems']['hvac'][0]['heating']['type'], 'mini_split')

    def test_attic_roof_unattached(self):
        tr = self._load_xmlfile('hescore_min_v3')
        # two attics, two frame floors, lacking frame floor area for attic area
        roof = self.xpath('//h:Roofs/h:Roof')
        frame_floor = self.xpath('//h:FrameFloors/h:FrameFloor')
        frame_floor.remove(self.xpath('//h:FrameFloors/h:FrameFloor/h:Area'))
        attic = self.xpath('//h:Attics/h:Attic')
        attic2 = deepcopy(attic)
        tr.xpath(attic2, 'h:SystemIdentifier').attrib['id'] = 'attic2'
        tr.xpath(attic2, 'h:AttachedToRoof').attrib['idref'] = "roof2"
        tr.xpath(attic2, 'h:AttachedToFrameFloor').attrib['idref'] = "framefloor2"
        attic.addnext(attic2)
        roof2 = deepcopy(roof)
        roof.addnext(roof2)
        frame_floor2 = deepcopy(frame_floor)
        frame_floor.addnext(frame_floor2)
        tr.xpath(roof2, 'h:SystemIdentifier').attrib['id'] = "roof2"
        tr.xpath(roof2, 'h:Insulation/h:SystemIdentifier').attrib['id'] = "attic1roofins2"
        tr.xpath(frame_floor2, 'h:SystemIdentifier').attrib['id'] = "framefloor2"
        tr.xpath(frame_floor2, 'h:Insulation/h:SystemIdentifier').attrib['id'] = "attic1flrins2"
        self.assertRaisesRegex(
            TranslationError,
            r'If there are more than one Attic elements, each needs an area. '
            r'Please specify under its attached FrameFloor/Roof element.',
            tr.hpxml_to_hescore)

        # two frame floors, one attic, lacking frame floor areas for attic area
        attic2.getparent().remove(attic2)
        attached_to_ff = self.xpath('//h:Attics/h:Attic/h:AttachedToFrameFloor')
        attached_to_ff2 = deepcopy(attached_to_ff)
        attached_to_ff2.attrib['idref'] = "framefloor2"
        attached_to_ff.addnext(attached_to_ff2)
        self.assertRaisesRegex(
            TranslationError,
            r'If there are more than one FrameFloor elements attached to attic, each needs an area.',
            tr.hpxml_to_hescore)

        # two roofs, one attic, lacking roof areas for roof area (attic use footprint area)
        attached_to_ff2.getparent().remove(attached_to_ff2)
        attached_to_roof = self.xpath('//h:Attics/h:Attic/h:AttachedToRoof')
        attached_to_roof2 = deepcopy(attached_to_roof)
        attached_to_roof2.attrib['idref'] = "roof2"
        attached_to_roof.addnext(attached_to_roof2)
        self.assertRaisesRegex(
            TranslationError,
            r'If there are more than one Roof elements attached to a single attic, each needs an area.',
            tr.hpxml_to_hescore)

        # Two roofs, but both unattached.
        # One roof unattached: attach the only existing one
        # 0 roof, will error out during xpath execution
        attached_to_roof2.getparent().remove(attached_to_roof2)
        attached_to_roof.attrib['idref'] = 'no_roof'
        self.assertRaisesRegex(
            TranslationError,
            r'Attic attic1 does not have a roof associated with it.',
            tr.hpxml_to_hescore)

        # one roof, attach existing roof to attic
        attached_to_roof.getparent().remove(attached_to_roof)
        roof2.getparent().remove(roof2)
        d = tr.hpxml_to_hescore()
        self.assertEqual(len(d['building']['zone']['zone_roof']), 1)

    def test_hescore_min_translation(self):
        tr = self._load_xmlfile('hescore_min')
        tr_v3 = self._load_xmlfile('hescore_min_v3')
        d = tr.hpxml_to_hescore()
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d, d_v3)

    def test_house1_translation(self):
        tr = self._load_xmlfile('house1')
        tr_v3 = self._load_xmlfile('house1_v3')
        d = tr.hpxml_to_hescore()
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d, d_v3)

    def test_house2_translation(self):
        tr = self._load_xmlfile('house2')
        tr_v3 = self._load_xmlfile('house2_v3')
        d = tr.hpxml_to_hescore()
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d, d_v3)

    def test_house3_translation(self):
        tr = self._load_xmlfile('house3')
        tr_v3 = self._load_xmlfile('house3_v3')
        d = tr.hpxml_to_hescore()
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d, d_v3)

    def test_house4_translation(self):
        tr = self._load_xmlfile('house4')
        tr_v3 = self._load_xmlfile('house4_v3')
        d = tr.hpxml_to_hescore()
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d, d_v3)

    def test_house5_translation(self):
        tr = self._load_xmlfile('house5')
        tr_v3 = self._load_xmlfile('house5_v3')
        d = tr.hpxml_to_hescore()
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d, d_v3)

    def test_house6_translation(self):
        tr = self._load_xmlfile('house6')
        tr_v3 = self._load_xmlfile('house6_v3')
        d = tr.hpxml_to_hescore()
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d, d_v3)

    def test_house7_translation(self):
        tr = self._load_xmlfile('house7')
        tr_v3 = self._load_xmlfile('house7_v3')
        d = tr.hpxml_to_hescore()
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d, d_v3)

    def test_house8_translation(self):
        tr = self._load_xmlfile('house8')
        tr_v3 = self._load_xmlfile('house8_v3')
        d = tr.hpxml_to_hescore()
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d, d_v3)

    def test_townhouse_walls_translation(self):
        tr = self._load_xmlfile('townhouse_walls')
        tr_v3 = self._load_xmlfile('townhouse_walls_v3')
        d = tr.hpxml_to_hescore()
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d_v3['building']['zone']['zone_roof'][0]['roof_area'], 1200)
        self.assertEqual(d, d_v3)

    def test_v3_duct_location(self):
        tr_v3 = self._load_xmlfile('hescore_min_v3')
        el = self.xpath('//h:DuctLocation[1]')
        el.text = 'unconditioned space'
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d_v3['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['location'],
                         'uncond_attic')

        el.text = 'basement'
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d_v3['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['location'],
                         'cond_space')

        el.text = 'basement - conditioned'
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d_v3['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['location'],
                         'cond_space')

        el.text = 'attic'
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d_v3['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['location'],
                         'uncond_attic')

        # Is this reasonable?
        el.text = 'crawlspace'
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d_v3['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['location'],
                         'cond_space')

        el.text = 'garage'
        fnd_type_el = self.xpath('//h:FoundationType[1]/h:Basement')
        etree.SubElement(fnd_type_el.getparent(), tr_v3.addns('h:Garage'))
        fnd_type_el.getparent().remove(fnd_type_el)
        d_v3 = tr_v3.hpxml_to_hescore()
        self.assertEqual(d_v3['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['location'],
                         'unvented_crawl')

    def test_v3_duct_insulation(self):
        tr = self._load_xmlfile('hescore_min_v3')
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['insulated'], False)

        E = self.element_maker()
        el = self.xpath('//h:Ducts/h:DuctLocation')
        duct_ins_mat = E.DuctInsulationMaterial(
            E.Batt('unknown')
        )
        el.addprevious(duct_ins_mat)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['insulated'], True)
        el.getparent().remove(duct_ins_mat)

        duct_ins_mat = E.DuctInsulationMaterial(
            E.LooseFill('unknown')
        )
        el.addprevious(duct_ins_mat)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['insulated'], True)
        el.getparent().remove(duct_ins_mat)

        duct_ins_mat = E.DuctInsulationMaterial(
            E.Rigid('unknown')
        )
        el.addprevious(duct_ins_mat)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['insulated'], True)
        el.getparent().remove(duct_ins_mat)

        duct_ins_mat = E.DuctInsulationMaterial(
            E.SprayFoam('unknown')
        )
        el.addprevious(duct_ins_mat)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['insulated'], True)
        el.getparent().remove(duct_ins_mat)

        duct_ins_mat = E.DuctInsulationMaterial(
            E.Other()
        )
        el.addprevious(duct_ins_mat)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['insulated'], True)
        el.getparent().remove(duct_ins_mat)

        none_type = getattr(E, 'None')
        duct_ins_mat = E.DuctInsulationMaterial(
            none_type
        )
        el.addprevious(duct_ins_mat)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['insulated'], False)
        el.getparent().remove(duct_ins_mat)

        duct_ins_mat = E.DuctInsulationMaterial(
            E.Unknown()
        )
        el.addprevious(duct_ins_mat)
        res = tr.hpxml_to_hescore()
        self.assertEqual(res['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['insulated'], True)
        el.getparent().remove(duct_ins_mat)


if __name__ == "__main__":
    unittest.main()
