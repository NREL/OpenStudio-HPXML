from __future__ import division
from builtins import map
from builtins import zip
from builtins import object
from past.utils import old_div
import datetime as dt
import json
import math
from lxml import etree, objectify
from collections import defaultdict, namedtuple
from decimal import Decimal
from collections import OrderedDict
import os
import re
from jsonschema import validate, FormatChecker

from .exceptions import (
    TranslationError,
    ElementNotFoundError,
    InputOutOfBounds,
    RoundOutOfBounds,
)

thisdir = os.path.dirname(os.path.abspath(__file__))
nsre = re.compile(r'([a-zA-Z][a-zA-Z0-9]*):')


def tobool(x):
    if x is None:
        return None
    elif x.lower() == 'true':
        return True
    else:
        assert x.lower() == 'false'
        return False


def convert_to_type(type_, value):
    if value is None:
        return value
    else:
        return type_(value)


def python2round(f):
    if round(f + 1) - round(f) != 1:
        return f + abs(f) / f * 0.5
    return round(f)


def unspin_azimuth(azimuth):
    while azimuth >= 360:
        azimuth -= 360
    while azimuth < 0:
        azimuth += 360
    return azimuth


def round_to_nearest(x, vals, tails_tolerance=None):
    nearest = min(vals, key=lambda y: abs(x - y))
    if tails_tolerance is not None:
        if x < min(vals):
            if abs(x - nearest) > tails_tolerance:
                raise RoundOutOfBounds()
    return nearest


class HPXMLtoHEScoreTranslatorBase(object):
    SCHEMA_DIR = None

    @staticmethod
    def detect_hpxml_version(hpxmlfilename):
        doc = etree.parse(hpxmlfilename)
        schema_version = list(map(int, doc.getroot().attrib['schemaVersion'].split('.')))
        schema_version.extend((3 - len(schema_version)) * [0])
        return schema_version

    def __init__(self, hpxmlfilename):
        self.hpxmldoc = etree.parse(hpxmlfilename)
        self.schemapath = os.path.join(thisdir, 'schemas', self.SCHEMA_DIR, 'HPXML.xsd')
        self.jsonschemapath = os.path.join(thisdir, 'schemas', 'hescore_json.schema.json')
        schematree = etree.parse(self.schemapath)
        self.schema = etree.XMLSchema(schematree)
        if not self.schema.validate(self.hpxmldoc):
            raise TranslationError(
                'Failed to validate against the following HPXML schema: {}'.format(self.SCHEMA_DIR)
            )
        self.ns = {'xs': 'http://www.w3.org/2001/XMLSchema'}
        self.ns['h'] = schematree.xpath('//xs:schema/@targetNamespace', namespaces=self.ns)[0]

    def xpath(self, el, xpathquery, aslist=False, raise_err=False, **kwargs):
        if isinstance(el, etree._ElementTree):
            el = el.getroot()
        res = el.xpath(xpathquery, namespaces=self.ns, **kwargs)
        if raise_err and isinstance(res, list) and len(res) == 0:
            raise ElementNotFoundError(el, xpathquery, kwargs)
        if aslist:
            return res
        if isinstance(res, list):
            if len(res) == 0:
                return None
            elif len(res) == 1:
                return res[0]
            else:
                return res
        else:
            return res

    def export_scrubbed_hpxml(self, outfile_obj):
        """Export an hpxml file scrubbed of potential PII

        :param outfile_obj: writable filename or file-like object to write the scrubbed xml
        :type outfile_obj: file-like object
        """

        # Make a copy of the original hpxml doc as an objectify tree
        root = objectify.fromstring(etree.tostring(self.hpxmldoc))
        E = objectify.ElementMaker(
            annotate=False,
            namespace=self.ns['h']
        )

        # Clean out the Customer elements
        for customer in root.xpath('h:Customer', namespaces=self.ns):
            customer_id = customer.CustomerDetails.Person.SystemIdentifier.attrib['id']
            root.replace(
                customer,
                E.Customer(
                    E.CustomerDetails(
                        E.Person(
                            E.SystemIdentifier(id=customer_id)
                        )
                    )
                )
            )

        elements_to_remove = [
            '//h:HealthAndSafety',
            '//h:BuildingOccupancy',
            '//h:AnnualEnergyUse',
            'h:Utility',
            'h:Consumption',
            'h:Building/h:CustomerID'
        ]
        for el_name in elements_to_remove:
            for el in root.xpath(el_name, namespaces=self.ns):
                el.getparent().remove(el)

        # Write out the scrubbed doc
        etree.ElementTree(root).write(outfile_obj, pretty_print=True)

    def get_wall_assembly_code(self, hpxmlwall):
        xpath = self.xpath
        ns = self.ns
        wallid = xpath(hpxmlwall, 'h:SystemIdentifier/@id', raise_err=True)

        # siding
        sidingmap = {'wood siding': 'wo',
                     'stucco': 'st',
                     'synthetic stucco': 'st',
                     'vinyl siding': 'vi',
                     'aluminum siding': 'al',
                     'brick veneer': 'br',
                     'asbestos siding': 'wo',
                     'fiber cement siding': 'wo',
                     'composite shingle siding': 'wo',
                     'masonite siding': 'wo',
                     'other': None}

        def wall_round_to_nearest(*args):
            try:
                return round_to_nearest(*args, tails_tolerance=3)
            except RoundOutOfBounds:
                raise TranslationError('Wall R-value outside HEScore bounds, wall id: %s' % wallid)

        # construction type
        wall_type = xpath(hpxmlwall, 'name(h:WallType/*)', raise_err=True)
        for layer in xpath(hpxmlwall, 'h:Insulation/h:Layer', aslist=True):
            if xpath(layer, 'h:NominalRValue') is None:
                raise TranslationError('Every wall insulation layer needs a NominalRValue, (wallid = "%s")' % wallid)
        if wall_type == 'WoodStud':
            wall_rvalue = xpath(hpxmlwall, 'sum(h:Insulation/h:Layer/h:NominalRValue)', raise_err=True)
            has_rigid_ins = xpath(
                hpxmlwall,
                'boolean(h:Insulation/h:Layer[h:NominalRValue > 0][h:InstallationType="continuous"])'
            )
            if tobool(xpath(hpxmlwall, 'h:WallType/h:WoodStud/h:ExpandedPolystyreneSheathing/text()')) or has_rigid_ins:
                wallconstype = 'ps'
                # account for the rigid foam sheathing in the construction code
                wall_rvalue -= 5
                rvalue = wall_round_to_nearest(wall_rvalue, (0, 3, 7, 11, 13, 15, 19, 21))
            elif tobool(xpath(hpxmlwall, 'h:WallType/h:WoodStud/h:OptimumValueEngineering/text()')):
                wallconstype = 'ov'
                rvalue = wall_round_to_nearest(wall_rvalue, (19, 21, 27, 33, 38))
            else:
                wallconstype = 'wf'
                rvalue = wall_round_to_nearest(wall_rvalue, (0, 3, 7, 11, 13, 15, 19, 21))
            hpxmlsiding = xpath(hpxmlwall, 'h:Siding/text()')
            try:
                sidingtype = sidingmap[hpxmlsiding]
            except KeyError:
                raise TranslationError('Wall %s: Exterior finish information is missing' % wallid)
            else:
                if sidingtype is None:
                    raise TranslationError(
                        'Wall %s: There is no HEScore wall siding equivalent for the HPXML option: %s' %
                        (wallid, hpxmlsiding))
        elif wall_type == 'StructuralBrick':
            wallconstype = 'br'
            sidingtype = 'nn'
            rvalue = 0
            for lyr in hpxmlwall.xpath('h:Insulation/h:Layer', namespaces=ns):
                rvalue += float(xpath(lyr, 'h:NominalRValue/text()', raise_err=True))
            rvalue = wall_round_to_nearest(rvalue, (0, 5, 10))
        elif wall_type in ('ConcreteMasonryUnit', 'Stone'):
            wallconstype = 'cb'
            rvalue = 0
            for lyr in hpxmlwall.xpath('h:Insulation/h:Layer', namespaces=ns):
                rvalue += float(xpath(lyr, 'h:NominalRValue/text()'))
            rvalue = wall_round_to_nearest(rvalue, (0, 3, 6))
            hpxmlsiding = xpath(hpxmlwall, 'h:Siding/text()')
            if hpxmlsiding is None:
                sidingtype = 'nn'
            else:
                sidingtype = sidingmap[hpxmlsiding]
                if sidingtype not in ('st', 'br'):
                    raise TranslationError(
                        'Wall {}: is a CMU and needs a siding of stucco, brick, or none to translate to HEScore. '
                        'It has a siding type of {}'.format(wallid, hpxmlsiding)
                    )
        elif wall_type == 'StrawBale':
            wallconstype = 'sb'
            rvalue = 0
            sidingtype = 'st'
        else:
            raise TranslationError('Wall type %s not supported, wall id: %s' % (wall_type, wallid))

        return 'ew%s%02d%s' % (wallconstype, rvalue, sidingtype)

    def get_window_code(self, window):
        # Please review the refactoring for this function
        # HEScore window code mapping
        window_map = {
            'Aluminum': {
                'single-pane': {
                    'clear': 'scna',
                    'tinted': 'stna'
                },
                'double-pane': {
                    'clear': 'dcaa',
                    'tinted': 'dtaa',
                    'solar-control low-e': 'dseaa'
                }
            },
            'Aluminum with Thermal Break': {
                'double-pane': {
                    'clear': 'dcab',
                    'tinted': 'dtab',
                    'insulating low-e argon': 'dpeaab',
                    'solar-control low-e': 'dseab'
                }
            },
            'Wood or Vinyl': {
                'single-pane': {
                    'clear': 'scnw',
                    'tinted': 'stnw'
                },
                'double-pane': {
                    'clear': 'dcaw',
                    'tinted': 'dtaw',
                    'insulating low-e': 'dpeaw',
                    'insulating low-e argon': 'dpeaaw',
                    'solar-control low-e': 'dseaw',
                    'solar-control low-e argon': 'dseaaw'
                },
                'triple-pane': {
                    'insulating low-e argon': 'thmabw'
                }
            }
        }

        xpath = self.xpath

        frame_type = xpath(window, 'name(h:FrameType/*)')
        if frame_type == '':
            frame_type = None
        glass_layers = xpath(window, 'h:GlassLayers/text()')
        glass_type = xpath(window, 'h:GlassType/text()')
        is_hescore_dp = self.check_is_doublepane(window, glass_layers)
        is_storm_lowe = False
        window_frame = None
        window_layer = None
        window_glass_type = None

        if is_hescore_dp:
            # double pane needs more information being analyzed to determine glass type
            window_layer = 'double-pane'
            is_storm_lowe = self.check_is_storm_lowe(window, glass_layers)
        elif glass_layers == 'single-pane':
            window_layer = 'single-pane'
            if glass_type is not None and glass_type in ('tinted', 'low-e', 'tinted/reflective'):
                window_glass_type = 'tinted'
            else:
                window_glass_type = 'clear'
        elif glass_layers == 'triple-pane':
            window_layer = 'triple-pane'
            window_glass_type = 'insulating low-e argon'

        gas_fill = xpath(window, 'h:GasFill/text()')
        argon_filled = False
        # Only double-pane window can be argon filled
        if glass_layers == 'double-pane' and gas_fill == 'argon':
            argon_filled = True

        if frame_type in ('Aluminum', 'Metal'):
            thermal_break = tobool(xpath(window, 'h:FrameType/*/h:ThermalBreak/text()'))
            if thermal_break:
                # Aluminum with Thermal Break
                window_frame = 'Aluminum with Thermal Break'
                if argon_filled and glass_type == 'low-e':
                    window_glass_type = 'insulating low-e argon'
                elif glass_type is not None and glass_type in ('reflective', 'low-e'):
                    # TODO: figure out if 'reflective' is close enough to 'solar-control' low-e
                    window_glass_type = 'solar-control low-e'
                elif glass_type is not None and glass_type.startswith('tinted'):
                    window_glass_type = 'tinted'
                else:
                    window_glass_type = 'clear'
            else:
                # Aluminum
                window_frame = 'Aluminum'
                # For other layer types, the window glass type has been determined
                if is_hescore_dp:
                    if glass_type is not None and glass_type in ('reflective', 'tinted/reflective', 'low-e'):
                        window_glass_type = 'solar-control low-e'
                    elif glass_type is not None and glass_type == 'tinted':
                        window_glass_type = 'tinted'
                    else:
                        window_glass_type = 'clear'
        elif frame_type in ('Vinyl', 'Wood', 'Fiberglass', 'Composite'):
            # Wood or Vinyl
            window_frame = 'Wood or Vinyl'
            # For other layer types, the window glass type has been determined
            if is_hescore_dp:
                if (glass_layers == 'double-pane' and glass_type == 'low-e') or is_storm_lowe:
                    if argon_filled:
                        window_glass_type = 'insulating low-e argon'
                    else:
                        window_glass_type = 'insulating low-e'
                elif glass_type == 'reflective':
                    # TODO: figure out if 'reflective' is close enough to 'solar-control' low-e
                    if argon_filled:
                        window_glass_type = 'solar-control low-e argon'
                    else:
                        window_glass_type = 'solar-control low-e'
                elif glass_type is not None and glass_type.startswith('tinted'):
                    window_glass_type = 'tinted'
                else:
                    window_glass_type = 'clear'

        try:
            window_code = window_map[window_frame][window_layer][window_glass_type]
        except KeyError:
            raise TranslationError(
                'There is no compatible HEScore window type for FrameType="{}", GlassLayers="{}", '
                'GlassType="{}", GasFill="{}"'.format(
                    frame_type, glass_layers, glass_type, gas_fill
                )
            )
        return window_code

    heat_pump_type_map = {'water-to-air': 'gchp',
                          'water-to-water': 'gchp',
                          'air-to-air': 'heat_pump',
                          'air-to-water': 'heat_pump',
                          'mini-split': 'mini_split',
                          'ground-to-air': 'gchp',
                          'ground-to-water': 'gchp'}

    def get_attic_knee_wall_rvalue_and_area(self, attic, b):
        knee_walls = self.get_attic_knee_walls(attic, b)
        if len(knee_walls) == 0:
            return 0, 0
        if len(knee_walls) == 1:
            knee_wall_r = convert_to_type(float, self.xpath(knee_walls[0], 'sum(h:Insulation/h:Layer/h:NominalRValue)'))
            knee_wall_area = convert_to_type(float, self.xpath(knee_walls[0], 'h:Area/text()'))
            return knee_wall_r, knee_wall_area

        knee_wall_dict_ls = []
        for knee_wall in knee_walls:
            wall_area = convert_to_type(float, self.xpath(knee_wall, 'h:Area/text()'))
            if wall_area is None:
                raise TranslationError('All attic knee walls need an Area specified')
            rvalue = self.xpath(knee_wall, 'sum(h:Insulation/h:Layer/h:NominalRValue)')
            knee_wall_dict_ls.append({'area': wall_area, 'rvalue': rvalue})
        # Average
        knee_wall_area = sum(x['area'] for x in knee_wall_dict_ls)
        try:
            knee_wall_r = knee_wall_area / \
                          sum(x['area'] / x['rvalue'] for x in knee_wall_dict_ls)
        except ZeroDivisionError:
            knee_wall_r = 0

        return knee_wall_r, knee_wall_area

    def add_fuel_type(self, fuel_type):
        # Some fuel types are not included in fuel_type_mapping, throw an error if not mapped.
        try:
            return self.fuel_type_mapping[fuel_type]
        except KeyError:
            raise TranslationError('HEScore does not support the HPXML fuel type %s' % fuel_type)

    def get_heating_system_type(self, htgsys):
        xpath = self.xpath
        ns = self.ns

        sys_heating = OrderedDict()
        if htgsys.tag.endswith('HeatPump'):
            # heat pump new fuel type added in v3: https://github.com/hpxmlwg/hpxml/pull/159.
            # Should we also translate fuel type for heat pumps?
            sys_heating['fuel_primary'] = 'electric'
            heat_pump_type = xpath(htgsys, 'h:HeatPumpType/text()')
            if heat_pump_type is None:
                sys_heating['type'] = 'heat_pump'
            else:
                sys_heating['type'] = self.heat_pump_type_map[heat_pump_type]
        else:
            assert htgsys.tag.endswith('HeatingSystem')
            fuel_type = xpath(htgsys, 'h:HeatingSystemFuel/text()', raise_err=True)
            sys_heating['fuel_primary'] = self.add_fuel_type(fuel_type)
            hpxml_heating_type = xpath(htgsys, 'name(h:HeatingSystemType/*)', raise_err=True)
            try:
                sys_heating['type'] = {'Furnace': 'central_furnace',
                                       'WallFurnace': 'wall_furnace',
                                       'FloorFurnace': 'wall_furnace',
                                       'Boiler': 'boiler',
                                       'ElectricResistance': 'baseboard',
                                       'Stove': 'wood_stove'}[hpxml_heating_type]
            except KeyError:
                raise TranslationError('HEScore does not support the HPXML HeatingSystemType %s' % hpxml_heating_type)

        allowed_fuel_types = {'heat_pump': ('electric',),
                              'mini_split': ('electric',),
                              'central_furnace': ('natural_gas', 'lpg', 'fuel_oil', 'electric'),
                              'wall_furnace': ('natural_gas', 'lpg'),
                              'baseboard': ('electric',),
                              'boiler': ('natural_gas', 'lpg', 'fuel_oil'),
                              'gchp': ('electric',),
                              'none': tuple(),
                              'wood_stove': ('cord_wood', 'pellet_wood')}

        if sys_heating['fuel_primary'] not in allowed_fuel_types[sys_heating['type']]:
            raise TranslationError('Heating system %(type)s cannot be used with fuel %(fuel_primary)s' % sys_heating)

        if not ((sys_heating['type'] in ('central_furnace', 'baseboard')
                 and sys_heating['fuel_primary'] == 'electric') or sys_heating['type'] == 'wood_stove'):
            eff_units = {'heat_pump': 'HSPF',
                         'mini_split': 'HSPF',
                         'central_furnace': 'AFUE',
                         'wall_furnace': 'AFUE',
                         'boiler': 'AFUE',
                         'gchp': 'COP'}[sys_heating['type']]
            eff_els = htgsys.xpath(
                '(h:AnnualHeatingEfficiency|h:AnnualHeatEfficiency)[h:Units=$effunits]/h:Value/text()',
                namespaces=ns,
                effunits=eff_units
            )
            if len(eff_els) == 0:
                # Use the year instead
                sys_heating['efficiency_method'] = 'shipment_weighted'
                try:
                    sys_heating['year'] = int(htgsys.xpath('(h:YearInstalled|h:ModelYear)/text()', namespaces=ns)[0])
                except IndexError:
                    raise TranslationError(
                        'Heating efficiency could not be determined. ' +
                        '{} must have a heating efficiency with units of {} '.format(sys_heating['type'], eff_units) +
                        'or YearInstalled or ModelYear.'
                    )
            else:
                # Use the efficiency of the first element found.
                sys_heating['efficiency_method'] = 'user'
                sys_heating['efficiency'] = float(eff_els[0])
        sys_heating['_capacity'] = convert_to_type(float, xpath(htgsys, 'h:HeatingCapacity/text()'))
        sys_heating['_fracload'] = convert_to_type(float, xpath(htgsys, 'h:FractionHeatLoadServed/text()'))
        sys_heating['_floorarea'] = convert_to_type(float, xpath(htgsys, 'h:FloorAreaServed/text()'))
        return sys_heating

    def get_cooling_system_type(self, clgsys):
        xpath = self.xpath
        ns = self.ns

        sys_cooling = OrderedDict()
        if clgsys.tag.endswith('HeatPump'):
            heat_pump_type = xpath(clgsys, 'h:HeatPumpType/text()')
            if heat_pump_type is None:
                sys_cooling['type'] = 'heat_pump'
            else:
                sys_cooling['type'] = self.heat_pump_type_map[heat_pump_type]
        else:
            assert clgsys.tag.endswith('CoolingSystem')
            hpxml_cooling_type = xpath(clgsys, 'h:CoolingSystemType/text()', raise_err=True)
            try:
                sys_cooling['type'] = {'central air conditioning': 'split_dx',  # version 2.*
                                       'central air conditioner': 'split_dx',  # version 3.*
                                       'room air conditioner': 'packaged_dx',
                                       'mini-split': 'mini_split',
                                       'evaporative cooler': 'dec'}[hpxml_cooling_type]
            except KeyError:
                raise TranslationError('HEScore does not support the HPXML CoolingSystemType %s' % hpxml_cooling_type)
        # cooling efficiency
        eff_units = {'split_dx': 'SEER',
                     'packaged_dx': 'EER',
                     'heat_pump': 'SEER',
                     'mini_split': 'SEER',
                     'gchp': 'EER',
                     'dec': None,
                     'iec': None,
                     'idec': None}[sys_cooling['type']]
        if eff_units is not None:
            eff_els = clgsys.xpath(
                '(h:AnnualCoolingEfficiency|h:AnnualCoolEfficiency)[h:Units=$effunits]/h:Value/text()',
                namespaces=ns,
                effunits=eff_units
            )
            if len(eff_els) == 0:
                # Use the year instead
                sys_cooling['efficiency_method'] = 'shipment_weighted'
                try:
                    sys_cooling['year'] = int(clgsys.xpath('(h:YearInstalled|h:ModelYear)/text()', namespaces=ns)[0])
                except IndexError:
                    raise TranslationError(
                        'Cooling efficiency could not be determined. ' +
                        '{} must have a cooling efficiency with units of {} '.format(sys_cooling['type'], eff_units) +
                        'or YearInstalled or ModelYear.'
                    )
            else:
                # Use the efficiency of the first element found.
                sys_cooling['efficiency_method'] = 'user'
                sys_cooling['efficiency'] = float(eff_els[0])

        sys_cooling['_capacity'] = convert_to_type(float, xpath(clgsys, 'h:CoolingCapacity/text()'))
        sys_cooling['_fracload'] = convert_to_type(float, xpath(clgsys, 'h:FractionCoolLoadServed/text()'))
        sys_cooling['_floorarea'] = convert_to_type(float, xpath(clgsys, 'h:FloorAreaServed/text()'))
        return sys_cooling

    def get_hvac_distribution(self, hvacd_el, bldg):
        hvac_distribution = []

        airdist_el = self.xpath(hvacd_el, 'h:DistributionSystemType/h:AirDistribution')
        if isinstance(airdist_el, list):
            # There really shouldn't be more than one
            assert False
        elif airdist_el is None:
            # This isn't a ducted system, return None
            return

        # Determine if the entire system is sealed (best we can do, not available duct by duct)
        is_sealed = \
            self.xpath(airdist_el,
                       '(h:DuctLeakageMeasurement/h:LeakinessObservedVisualInspection="connections sealed w mastic") ' +
                       'or (ancestor::h:HVACDistribution/h:HVACDistributionImprovement/h:DuctSystemSealed="true")')

        duct_fracs_by_hescore_duct_loc = defaultdict(float)
        hescore_duct_loc_has_insulation = defaultdict(bool)
        for duct_el in self.xpath(airdist_el, 'h:Ducts', aslist=True):

            # Duct Location
            hpxml_duct_location = self.xpath(duct_el, 'h:DuctLocation/text()')
            hescore_duct_location = self.get_duct_location(hpxml_duct_location, bldg)

            if hescore_duct_location is None:
                raise TranslationError('No comparable duct location in HEScore: %s' % hpxml_duct_location)

            # Fraction of Duct Area
            frac_duct_area = float(self.xpath(duct_el, 'h:FractionDuctArea/text()', raise_err=True))
            duct_fracs_by_hescore_duct_loc[hescore_duct_location] += frac_duct_area

            # Duct Insulation
            duct_has_ins = self.xpath(duct_el, 'h:DuctInsulationRValue > 0 or h:DuctInsulationThickness > 0 or\
                                      count(h:DuctInsulationMaterial[not(h:None)]) > 0')
            hescore_duct_loc_has_insulation[hescore_duct_location] = \
                hescore_duct_loc_has_insulation[hescore_duct_location] or duct_has_ins

        # Renormalize duct fractions so they add up to one (handles supply/return method if both are specified)
        total_duct_frac = sum(duct_fracs_by_hescore_duct_loc.values())
        duct_fracs_by_hescore_duct_loc = dict([(key, old_div(value, total_duct_frac))
                                               for key, value
                                               in list(duct_fracs_by_hescore_duct_loc.items())])

        # Gather the ducts by type
        hvacd_sortlist = []
        for duct_loc, duct_frac in list(duct_fracs_by_hescore_duct_loc.items()):
            hvacd = {}
            hvacd['location'] = duct_loc
            hvacd['fraction'] = duct_frac
            hvacd_sortlist.append(hvacd)

        # Sort them
        hvacd_sortlist.sort(key=lambda x: (x['fraction'], x['location']), reverse=True)

        # Get the top 3
        sum_of_top_3_fractions = sum([x['fraction'] for x in hvacd_sortlist])
        for i, hvacd in enumerate(hvacd_sortlist[0:3], 1):
            hvacd_out = OrderedDict()
            hvacd_out['name'] = 'duct%d' % i
            hvacd_out['location'] = hvacd['location']
            hvacd_out['fraction'] = hvacd['fraction'] / sum_of_top_3_fractions
            hvacd_out['insulated'] = hescore_duct_loc_has_insulation[hvacd['location']]
            hvacd_out['sealed'] = is_sealed
            hvac_distribution.append(hvacd_out)

        # Make sure the fractions add up to 1
        total_pct = sum([x['fraction'] for x in hvac_distribution])
        pct_remainder = 1 - total_pct
        hvac_distribution[0]['fraction'] += pct_remainder

        return hvac_distribution

    def get_or_create_child(self, parent, childname, insertpos=-1):
        child = parent.find(childname)
        if child is None:
            child = etree.Element(childname)
            parent.insert(insertpos, child)
        return child

    def addns(self, x):
        def repl(m): return ('{%(' + m.group(1) + ')s}') % self.ns

        return nsre.sub(repl, x)

    def insert_element_in_order(self, parent, child, elorder):
        fullelorder = list(map(self.addns, elorder))
        childidx = fullelorder.index(child.tag)
        if len(parent) == 0:
            parent.append(child)
        else:
            for i, el in enumerate(parent):
                try:
                    idx = fullelorder.index(el.tag)
                except ValueError:
                    continue
                if idx > childidx:
                    parent.insert(i, child)
                    return
            if idx < childidx:
                parent.append(child)

    hpxml_orientation_to_azimuth = {
        'north': 0,
        'northeast': 45,
        'east': 90,
        'southeast': 135,
        'south': 180,
        'southwest': 225,
        'west': 270,
        'northwest': 315
    }

    azimuth_to_hescore_orientation = {
        0: 'north',
        45: 'north_east',
        90: 'east',
        135: 'south_east',
        180: 'south',
        225: 'south_west',
        270: 'west',
        315: 'north_west'
    }

    fuel_type_mapping = {'electricity': 'electric',
                         'renewable electricity': 'electric',
                         'natural gas': 'natural_gas',
                         'renewable natural gas': 'natural_gas',
                         'fuel oil': 'fuel_oil',
                         'fuel oil 1': 'fuel_oil',
                         'fuel oil 2': 'fuel_oil',
                         'fuel oil 4': 'fuel_oil',
                         'fuel oil 5/6': 'fuel_oil',
                         'propane': 'lpg',
                         'wood': 'cord_wood',
                         'wood pellets': 'pellet_wood'}

    def get_nearest_azimuth(self, azimuth=None, orientation=None):
        if azimuth is not None:
            return int(python2round(float(azimuth) / 45.)) % 8 * 45
        else:
            if orientation is None:
                raise TranslationError('Either an orientation or azimuth is required.')
            return self.hpxml_orientation_to_azimuth[orientation]

    def get_nearest_tilt(self, tilt):
        if tilt <= 7:
            return 'flat'
        elif tilt <= 22:
            return 'low_slope'
        elif tilt <= 37:
            return 'medium_slope'
        else:
            return 'steep_slope'

    def hpxml_to_hescore_json(self, outfile, *args, **kwargs):
        hescore_bldg = self.hpxml_to_hescore(*args, **kwargs)
        json.dump(hescore_bldg, outfile, indent=2)

    def hpxml_to_hescore(
            self,
            hpxml_bldg_id=None,
            hpxml_project_id=None,
            hpxml_contractor_id=None
    ):
        '''
        Convert a HPXML building file to a python dict with the same structure as the HEScore API

        hpxml_bldg_id (optional) - If there is more than one <Building> element in an HPXML file,
            use this one. Otherwise just use the first one.
        hpxml_project_id (optional) - If there is more than one <Project> element in an HPXML file,
            use this one. Otherwise just use the first one.
        hpxml_contractor_id (optional) - If there is more than one <Contractor> element in an HPXML file,
            use this one. Otherwise just use the first one.
        '''
        xpath = self.xpath

        # Load the xml document into lxml etree
        if hpxml_bldg_id is not None:
            b = xpath(self.hpxmldoc, 'h:Building[h:BuildingID/@id=$bldgid]', raise_err=True, bldgid=hpxml_bldg_id)
        else:
            b = xpath(self.hpxmldoc, 'h:Building[1]', raise_err=True)
            hpxml_bldg_id = xpath(b, 'h:BuildingID/@id', raise_err=True)

        if hpxml_project_id is not None:
            p = xpath(
                self.hpxmldoc,
                'h:Project[h:ProjectID/@id=$projectid]',
                raise_err=True,
                projectid=hpxml_project_id
            )
        else:
            p = xpath(self.hpxmldoc, 'h:Project[1]')

        if hpxml_contractor_id is not None:
            c = xpath(
                self.hpxmldoc,
                'h:ContractorDetails[h:SystemIdentifier/@id=$contractorid]',
                raise_err=True,
                contractorid=hpxml_contractor_id
            )
        else:
            c = xpath(
                self.hpxmldoc,
                'h:Contractor[h:ContractorDetails/h:SystemIdentifier/@id=//h:Building['
                'h:BuildingID/@id=$bldg_id]/h:ContractorID/@id]',
                bldg_id=hpxml_bldg_id
            )
            if c is None:
                c = xpath(self.hpxmldoc, 'h:Contractor[1]')

        self.schema.assertValid(self.hpxmldoc)

        # Create return dict
        hescore_inputs = OrderedDict()
        hescore_inputs['building_address'] = self.get_building_address(b)
        if self.check_hpwes(p, b):
            hescore_inputs['hpwes'] = self.get_hpwes(p, c)

        bldg = OrderedDict()
        hescore_inputs['building'] = bldg
        bldg['about'] = self.get_building_about(b, p)
        bldg['zone'] = OrderedDict()
        bldg['zone']['zone_roof'] = None  # to save the spot in the order
        bldg['zone']['zone_floor'] = self.get_building_zone_floor(b, bldg['about'])
        footprint_area = self.get_footprint_area(bldg)
        bldg['zone']['zone_roof'] = self.get_building_zone_roof(b, footprint_area)
        skylights = self.get_skylights(b, bldg['zone']['zone_roof'])
        for roof_num in range(len(bldg['zone']['zone_roof'])):
            bldg['zone']['zone_roof'][roof_num]['zone_skylight'] = skylights[roof_num]
        bldg['zone']['wall_construction_same'] = False
        bldg['zone']['window_construction_same'] = False
        bldg['zone']['zone_wall'] = self.get_building_zone_wall(b, bldg['about'])
        bldg['systems'] = OrderedDict()
        bldg['systems']['hvac'] = self.get_hvac(b, bldg)
        bldg['systems']['domestic_hot_water'] = self.get_systems_dhw(b)
        generation = self.get_generation(b)
        if generation:
            bldg['systems']['generation'] = generation
        self.remove_hidden_keys(hescore_inputs)

        # Validate
        self.validate_hescore_inputs(hescore_inputs)
        # Validate against JSON schema
        with open(self.jsonschemapath, 'r') as js:
            json_schema = json.loads(js.read())
            js.close()
        validate(hescore_inputs, json_schema, format_checker=FormatChecker())

        return hescore_inputs

    @staticmethod
    def get_footprint_area(bldg):
        floor_area = bldg['about']['conditioned_floor_area']
        stories = bldg['about']['num_floor_above_grade']
        cond_basement_floor_area = 0
        for zone_floor in bldg['zone']['zone_floor']:
            if zone_floor['foundation_type'] == 'cond_basement':
                cond_basement_floor_area += zone_floor['floor_area']
        return int(python2round(old_div((floor_area - cond_basement_floor_area), stories)))

    @classmethod
    def remove_hidden_keys(cls, d):
        if isinstance(d, dict):
            for key, value in list(d.items()):
                if key.startswith('_'):
                    del d[key]
                    continue
                cls.remove_hidden_keys(value)
        elif isinstance(d, (list, tuple)):
            for item in d:
                cls.remove_hidden_keys(item)

    def get_building_address(self, b):
        xpath = self.xpath
        ns = self.ns
        bldgaddr = OrderedDict()
        hpxmladdress = xpath(b, 'h:Site/h:Address[h:AddressType="street"]', raise_err=True)
        bldgaddr['address'] = ' '.join(hpxmladdress.xpath('h:Address1/text() | h:Address2/text()', namespaces=ns))
        if not bldgaddr['address'].strip():
            raise ElementNotFoundError(hpxmladdress, 'h:Address1/text() | h:Address2/text()', {})
        bldgaddr['city'] = xpath(b, 'h:Site/h:Address/h:CityMunicipality/text()', raise_err=True)
        bldgaddr['state'] = xpath(b, 'h:Site/h:Address/h:StateCode/text()', raise_err=True)
        hpxml_zipcode = xpath(b, 'h:Site/h:Address/h:ZipCode/text()', raise_err=True)
        bldgaddr['zip_code'] = re.match(r"([0-9]{5})(-[0-9]{4})?", hpxml_zipcode).group(1)
        transaction_type = xpath(self.hpxmldoc, 'h:XMLTransactionHeaderInformation/h:Transaction/text()')
        is_mentor = xpath(b, 'boolean(h:ProjectStatus/h:extension/h:HEScoreMentorAssessment)')
        if is_mentor:
            bldgaddr['assessment_type'] = 'mentor'
        else:
            if transaction_type == 'create':
                bldgaddr['assessment_type'] = {
                    'audit': 'initial',
                    'proposed workscope': 'alternative',
                    'approved workscope': 'alternative',
                    'construction-period testing/daily test out': 'test',
                    'job completion testing/final inspection': 'final',
                    'quality assurance/monitoring': 'qa',
                    'preconstruction': 'preconstruction'
                }[xpath(b, 'h:ProjectStatus/h:EventType/text()', raise_err=True)]
            else:
                assert transaction_type == 'update'
                bldgaddr['assessment_type'] = 'corrected'

        ext_id_xpath_exprs = (
            'h:extension/h:HESExternalID/text()',
            'h:BuildingID/h:SendingSystemIdentifierValue/text()'
        )
        for ext_id_xpath_expr in ext_id_xpath_exprs:
            external_id_value = xpath(b, ext_id_xpath_expr)
            if external_id_value is not None:
                bldgaddr['external_building_id'] = external_id_value
                break

        return bldgaddr

    def get_hpwes(self, p, c):
        xpath = self.xpath
        hpwes = OrderedDict()

        # project information
        hpwes['improvement_installation_start_date'] = xpath(p, 'h:ProjectDetails/h:StartDate/text()')

        hpwes['improvement_installation_completion_date'] = xpath(p, 'h:ProjectDetails/h:CompleteDateActual/text()')

        # Contractor information
        if c is not None:
            hpwes['contractor_business_name'] = xpath(c, 'h:ContractorDetails/h:BusinessInfo/h:BusinessName/text()')
            hpwes['contractor_zip_code'] = xpath(c, 'h:ContractorDetails/h:BusinessInfo/h:extension/h:ZipCode/text()')
        else:
            hpwes['contractor_business_name'] = None
            hpwes['contractor_zip_code'] = None

        expected_paths = OrderedDict([
            ('improvement_installation_start_date', 'Project/ProjectDetails/StartDate'),
            ('improvement_installation_completion_date', 'Project/ProjectDetails/CompleteDateActual'),
            ('contractor_business_name', 'Contractor/ContractorDetails/BusinessInfo/BusinessName'),
            ('contractor_zip_code', 'Contractor/ContractorDetails/BusinessInfo/extension/ZipCode')
        ])
        missing_paths = []
        for k, v in expected_paths.items():
            if hpwes[k] is None:
                missing_paths.append(v)
        if len(missing_paths) > 0:
            raise TranslationError(
                'The following elements are required for Home Performance with Energy Star, but were not provided: ' +
                ', '.join(missing_paths)
            )
        return hpwes

    def get_building_about(self, b, p):
        xpath = self.xpath
        ns = self.ns
        bldg_about = OrderedDict()

        project_status_date_el = b.find('h:ProjectStatus/h:Date', namespaces=ns)
        if project_status_date_el is None:
            bldg_about['assessment_date'] = dt.date.today()
        else:
            bldg_about['assessment_date'] = dt.datetime.strptime(project_status_date_el.text, '%Y-%m-%d').date()
        bldg_about['assessment_date'] = bldg_about['assessment_date'].isoformat()

        # TODO: See if we can map more of these facility types
        residential_facility_type = xpath(
            b, 'h:BuildingDetails/h:BuildingSummary/h:BuildingConstruction/h:ResidentialFacilityType/text()')
        try:
            bldg_about['shape'] = {'single-family detached': 'rectangle',
                                   'single-family attached': 'town_house',
                                   'manufactured home': None,
                                   '2-4 unit building': None,
                                   '5+ unit building': None,
                                   'multi-family - uncategorized': None,
                                   'multi-family - town homes': 'town_house',
                                   'multi-family - condos': None,
                                   'apartment unit': None,
                                   'studio unit': None,
                                   'other': None,
                                   'unknown': None
                                   }[residential_facility_type]
        except KeyError:
            raise TranslationError('ResidentialFacilityType is required in the HPXML document')
        if bldg_about['shape'] is None:
            raise TranslationError(
                'Cannot translate HPXML ResidentialFacilityType of %s into HEScore building shape' %
                residential_facility_type)
        if bldg_about['shape'] == 'town_house':
            hpxml_surroundings = xpath(b, 'h:BuildingDetails/h:BuildingSummary/h:Site/h:Surroundings/text()')
            try:
                bldg_about['town_house_walls'] = {'stand-alone': None,
                                                  'attached on one side': 'back_right_front',
                                                  'attached on two sides': 'back_front',
                                                  'attached on three sides': None
                                                  }[hpxml_surroundings]
            except KeyError:
                raise TranslationError('Site/Surroundings element is required in the HPXML document for town houses')
            if bldg_about['town_house_walls'] is None:
                raise TranslationError(
                    'Cannot translate HPXML Site/Surroundings element value of %s into HEScore town_house_walls' %
                    hpxml_surroundings)

        bldg_cons_el = xpath(b, 'h:BuildingDetails/h:BuildingSummary/h:BuildingConstruction', raise_err=True)
        bldg_about['year_built'] = int(xpath(bldg_cons_el, 'h:YearBuilt/text()', raise_err=True))
        nbedrooms = int(xpath(bldg_cons_el, 'h:NumberofBedrooms/text()', raise_err=True))
        bldg_about['number_bedrooms'] = nbedrooms
        bldg_about['num_floor_above_grade'] = int(
            math.ceil(float(xpath(bldg_cons_el, 'h:NumberofConditionedFloorsAboveGrade/text()', raise_err=True))))
        avg_ceiling_ht = xpath(bldg_cons_el, 'h:AverageCeilingHeight/text()')
        if avg_ceiling_ht is None:
            try:
                avg_ceiling_ht = float(xpath(bldg_cons_el, 'h:ConditionedBuildingVolume/text()', raise_err=True)) / \
                                 float(xpath(bldg_cons_el, 'h:ConditionedFloorArea/text()', raise_err=True))
            except ElementNotFoundError:
                raise TranslationError(
                    'Either AverageCeilingHeight or both ConditionedBuildingVolume and ConditionedFloorArea are '
                    'required.'
                )
        else:
            avg_ceiling_ht = float(avg_ceiling_ht)
        bldg_about['floor_to_ceiling_height'] = int(python2round(avg_ceiling_ht))
        bldg_about['conditioned_floor_area'] = int(python2round(float(xpath(
            b,
            'h:BuildingDetails/h:BuildingSummary/h:BuildingConstruction/h:ConditionedFloorArea/text()',
            raise_err=True
        ))))

        site_el = xpath(b, 'h:BuildingDetails/h:BuildingSummary/h:Site', raise_err=True)
        try:
            house_azimuth = self.get_nearest_azimuth(xpath(site_el, 'h:AzimuthOfFrontOfHome/text()'),
                                                     xpath(site_el, 'h:OrientationOfFrontOfHome/text()'))
        except TranslationError:
            raise TranslationError('Either AzimuthOfFrontOfHome or OrientationOfFrontOfHome is required.')
        bldg_about['orientation'] = self.azimuth_to_hescore_orientation[house_azimuth]
        self.sidemap = {house_azimuth: 'front', (house_azimuth + 90) % 360: 'left',
                        (house_azimuth + 180) % 360: 'back', (house_azimuth + 270) % 360: 'right'}

        blower_door_test = None
        air_infilt_est = None
        for air_infilt_meas in b.xpath('h:BuildingDetails/h:Enclosure/h:AirInfiltration/h:AirInfiltrationMeasurement',
                                       namespaces=ns):
            # Take the last blower door test that is in CFM50, or if that's not available, ACH50
            if xpath(air_infilt_meas, 'h:TypeOfInfiltrationMeasurement/text()') == 'blower door':
                house_pressure = convert_to_type(int, xpath(air_infilt_meas, 'h:HousePressure/text()'))
                blower_door_test_units = xpath(air_infilt_meas, 'h:BuildingAirLeakage/h:UnitofMeasure/text()')
                if house_pressure == 50 and (blower_door_test_units == 'CFM' or
                                             (blower_door_test_units == 'ACH' and blower_door_test is None)):
                    blower_door_test = air_infilt_meas
            elif xpath(air_infilt_meas, 'h:TypeOfInfiltrationMeasurement/text()') == 'estimate':
                air_infilt_est = air_infilt_meas
        if blower_door_test is not None:
            bldg_about['blower_door_test'] = True
            if xpath(blower_door_test, 'h:BuildingAirLeakage/h:UnitofMeasure/text()') == 'CFM':
                bldg_about['envelope_leakage'] = float(
                    xpath(blower_door_test, 'h:BuildingAirLeakage/h:AirLeakage/text()', raise_err=True))
            elif xpath(blower_door_test, 'h:BuildingAirLeakage/h:UnitofMeasure/text()') == 'ACH':
                bldg_about['envelope_leakage'] = bldg_about['floor_to_ceiling_height'] * bldg_about[
                    'conditioned_floor_area'] * \
                                                 float(xpath(blower_door_test,
                                                             'h:BuildingAirLeakage/h:AirLeakage/text()',
                                                             raise_err=True)) / 60.
            else:
                raise TranslationError('BuildingAirLeakage/UnitofMeasure must be either "CFM" or "ACH"')
            bldg_about['envelope_leakage'] = int(python2round(bldg_about['envelope_leakage']))
        else:
            bldg_about['blower_door_test'] = False
            if b.xpath('count(h:BuildingDetails/h:Enclosure/h:AirInfiltration/h:AirSealing)', namespaces=ns) > 0 or \
                    (air_infilt_est is not None and
                     xpath(air_infilt_est, 'h:LeakinessDescription/text()') in ('tight', 'very tight')):
                bldg_about['air_sealing_present'] = True
            else:
                bldg_about['air_sealing_present'] = False
        # Get comments
        extension_comment = xpath(b, 'h:extension/h:Comments/text()')
        if extension_comment is not None:
            bldg_about['comments'] = extension_comment
        elif p is not None:
            bldg_about['comments'] = xpath(p, 'h:ProjectDetails/h:Notes/text()')
        return bldg_about

    def get_building_zone_roof(self, b, footprint_area):
        xpath = self.xpath

        # building.zone.zone_roof--------------------------------------------------
        attics = xpath(b, 'descendant::h:Attics/h:Attic', aslist=True, raise_err=True)
        roofs = xpath(b, 'descendant::h:Roof', aslist=True, raise_err=True)
        attic_floor_rvalues = (0, 3, 6, 9, 11, 19, 21, 25, 30, 38, 44, 49, 60)
        roof_center_of_cavity_rvalues = \
            {'wf': {'co': dict(zip((0, 11, 13, 15, 19, 21, 27, 30), (2.7, 13.6, 15.6, 17.6, 21.6, 23.6, 29.6, 32.6))),
                    'wo': dict(zip((0, 11, 13, 15, 19, 21, 27, 30), (3.2, 14.1, 16.1, 18.1, 22.1, 24.1, 30.1, 33.1))),
                    'rc': dict(zip((0, 11, 13, 15, 19, 21, 27, 30), (2.2, 13.2, 15.2, 17.2, 21.2, 23.2, 29.2, 32.2))),
                    'lc': dict(zip((0, 11, 13, 15, 19, 21, 27, 30), (2.3, 13.2, 15.2, 17.2, 21.2, 23.2, 29.2, 32.2))),
                    'tg': dict(zip((0, 11, 13, 15, 19, 21, 27, 30), (2.3, 13.2, 15.2, 17.2, 21.2, 23.2, 29.2, 32.2)))},
             'rb': {'co': {0: 5},
                    'wo': {0: 5.5},
                    'rc': {0: 4.5},
                    'lc': {0: 4.6},
                    'tg': {0: 4.6}},
             'ps': {'co': dict(zip((0, 11, 13, 15, 19, 21), (6.8, 17.8, 19.8, 21.8, 25.8, 27.8))),
                    'wo': dict(zip((0, 11, 13, 15, 19, 21), (7.3, 18.3, 20.3, 22.3, 26.3, 28.3))),
                    'rc': dict(zip((0, 11, 13, 15, 19, 21), (6.4, 17.4, 19.4, 21.4, 25.4, 27.4))),
                    'lc': dict(zip((0, 11, 13, 15, 19, 21), (6.4, 17.4, 19.4, 21.4, 25.4, 27.4))),
                    'tg': dict(zip((0, 11, 13, 15, 19, 21), (6.4, 17.4, 19.4, 21.4, 25.4, 27.4)))}}

        atticds = []
        for attic in attics:
            atticid = xpath(attic, 'h:SystemIdentifier/@id', raise_err=True)
            roofids = xpath(attic, 'h:AttachedToRoof/@idref', aslist=True)
            attic_roofs = xpath(b, 'descendant::h:Roof[contains("{}", h:SystemIdentifier/@id)]'.format(roofids),
                                aslist=True)

            if len(attic_roofs) == 0:
                if len(roofs) == 1:
                    attic_roofs = roofs
                else:
                    raise TranslationError(
                        'Attic {} does not have a roof associated with it.'.format(atticid)
                    )

            atticd = {}
            atticds.append(atticd)

            # Attic area
            # Discussion need here: We are using is_one_roof to say, when there's no area specified in HPXML,
            # we can use footprint area.Should we judge is_one_roof here by looking at element amounts of both
            # Attic and Roof elements (to be 1)?
            # I changed it to only look at attic element here because the current logic is more like Attic is
            # on top of Roof, is it allowed to have roofs undefined in attic? I think those roofs not referred by
            # attics should be ignored in our translation, right?
            is_one_roof = (len(attics) == 1)
            atticd['roof_area'] = self.get_attic_area(attic, is_one_roof, footprint_area, attic_roofs, b)

            # Roof type
            atticd['rooftype'] = self.get_attic_type(attic, atticid)

            # Get other roof information from attached Roof nodes.
            attic_roof_ls = []
            # Loop added for hpxml v3 where multiple roofs can be attached to the same attic
            for roof in attic_roofs:
                attic_roofs_d = {}
                attic_roof_ls.append(attic_roofs_d)
                attic_roofs_d['roof_id'] = xpath(roof, 'h:SystemIdentifier/@id', raise_err=True)
                # Roof area
                attic_roofs_d['roof_area'] = self.get_attic_roof_area(roof)
                if attic_roofs_d['roof_area'] is None:
                    if len(attic_roofs) == 1:
                        attic_roofs_d['roof_area'] = atticd['roof_area']
                    else:
                        raise TranslationError(
                            'If there are more than one Roof elements attached to a single attic, each needs an area.')
                else:
                    attic_roofs_d['roof_area'] = convert_to_type(float, attic_roofs_d['roof_area'])

                # Roof color
                solar_absorptance = convert_to_type(float, xpath(roof, 'h:SolarAbsorptance/text()'))
                attic_roofs_d['roof_absorptance'] = solar_absorptance
                if solar_absorptance is not None:
                    attic_roofs_d['roofcolor'] = 'cool_color'
                else:
                    try:
                        attic_roofs_d['roofcolor'] = {
                            'light': 'light',
                            'medium': 'medium',
                            'medium dark': 'medium_dark',
                            'dark': 'dark',
                            'reflective': 'white'
                        }[xpath(roof, 'h:RoofColor/text()', raise_err=True)]
                    except KeyError:
                        raise TranslationError('Attic {}: Invalid or missing RoofColor in Roof: {}'.format(atticid,
                                                                                                           attic_roofs_d['roof_id']))  # noqa: E501

                # Exterior finish
                hpxml_roof_type = xpath(roof, 'h:RoofType/text()')
                try:
                    attic_roofs_d['extfinish'] = {'shingles': 'co',
                                                  'slate or tile shingles': 'rc',
                                                  'wood shingles or shakes': 'wo',
                                                  'asphalt or fiberglass shingles': 'co',
                                                  'metal surfacing': 'co',
                                                  'expanded polystyrene sheathing': None,
                                                  'plastic/rubber/synthetic sheeting': 'tg',
                                                  'concrete': 'lc',
                                                  'cool roof': None,
                                                  'green roof': None,
                                                  'no one major type': None,
                                                  'other': None}[hpxml_roof_type]
                    assert attic_roofs_d['extfinish'] is not None
                except (KeyError, AssertionError):
                    raise TranslationError(
                        'Attic {}: HEScore does not have an analogy to the HPXML roof type: {} for Roof : {}'.format(
                            atticid, hpxml_roof_type, attic_roofs_d['roof_id']))

                # construction type
                has_rigid_sheathing = self.attic_has_rigid_sheathing(attic, roof)
                has_radiant_barrier = xpath(roof, 'h:RadiantBarrier="true"')
                if has_radiant_barrier:
                    attic_roofs_d['roofconstype'] = 'rb'
                elif has_rigid_sheathing:
                    attic_roofs_d['roofconstype'] = 'ps'
                else:
                    attic_roofs_d['roofconstype'] = 'wf'

                # roof center of cavity R-value
                roof_rvalue = self.get_attic_roof_rvalue(attic, roof)
                # subtract the R-value of the rigid sheating in the HEScore construction.
                if attic_roofs_d['roofconstype'] == 'ps':
                    roof_rvalue -= 5
                roof_rvalue, attic_roofs_d['roof_coc_rvalue'] = \
                    min(list(roof_center_of_cavity_rvalues[attic_roofs_d['roofconstype']][
                                 attic_roofs_d['extfinish']].items()),
                        key=lambda x: abs(x[0] - roof_rvalue))

            # Please review this, it is combining properties of multiple roofs attached into one for each attic
            # Determine predominant roof characteristics for attic.
            # Sum of Roof Areas in the same Attic
            attic_roof_area_sum = sum([attic_roofs_dict['roof_area'] for attic_roofs_dict in attic_roof_ls])

            # Roof type, roof color, exterior finish, construction type
            for roof_key in ('roofconstype', 'extfinish', 'roofcolor', 'roof_absorptance'):
                roof_area_by_cat = {}
                for attic_roofs_dict in attic_roof_ls:
                    try:
                        roof_area_by_cat[attic_roofs_dict[roof_key]] += attic_roofs_dict['roof_area']
                    except KeyError:
                        roof_area_by_cat[attic_roofs_dict[roof_key]] = attic_roofs_dict['roof_area']
                atticd[roof_key] = max(roof_area_by_cat, key=lambda x: roof_area_by_cat[x])

            if atticd['roof_absorptance'] is None:
                del atticd['roof_absorptance']

            # ids of hpxml roofs along for the ride
            atticd['_roofid'] = set([attic_roofs_dict['roof_id'] for attic_roofs_dict in attic_roof_ls])

            # Calculate roof area weighted center of cavity R-value for attic,
            # might be combined later by averaging again
            # Please review this, it is taking average of coc r values (already looked up with construction type of
            # each roof) of roofs attached to the same attic.
            # An alternative can be: averaging the roof nominal R value first then look up the table with dominated
            # construction type for coc effective R value at attic level.
            atticd['roof_coc_rvalue'] = \
                attic_roof_area_sum / \
                sum([old_div(attic_roofs_dict['roof_area'], attic_roofs_dict['roof_coc_rvalue']) for attic_roofs_dict in
                     attic_roof_ls])

            # knee walls
            knee_walls = self.get_attic_knee_walls(attic, b)

            # Questions: here we didn't have any input validation of floor attachment based on attic type, should we
            # enhance it? Currently, a building with attic can skip specifying attic floors (0 rvalue passed) while
            # one with cathedral ceiling can have floor specified (though it will be silently ignored in output).
            # attic floor center of cavity R-value
            attic_floor_rvalue = self.get_attic_floor_rvalue(attic, b)
            if knee_walls:
                knee_wall_rvalue, knee_wall_area = self.get_attic_knee_wall_rvalue_and_area(attic, b)
                knee_wall_coc_rvalue = knee_wall_rvalue + 1.8
                knee_wall_ua = knee_wall_area / knee_wall_coc_rvalue

                attic_floor_coc_rvalue = attic_floor_rvalue + 0.5
                attic_floor_adj_ua = knee_wall_ua + atticd['roof_area'] / attic_floor_coc_rvalue
                attic_floor_adj_area = knee_wall_area + atticd['roof_area']
                attic_floor_rvalue = (attic_floor_adj_area / attic_floor_adj_ua) - 0.5
                atticd['roof_area'] = attic_floor_adj_area
            atticd['attic_floor_coc_rvalue'] = attic_floor_rvalue + 0.5

        if len(atticds) == 0:
            raise TranslationError('There are no Attic elements in this building.')
        elif len(atticds) <= 2:
            for atticd in atticds:
                atticd['_roofids'] = atticd['_roofid']
                del atticd['_roofid']
        elif len(atticds) > 2:
            # If there are more than two attics, combine and average by rooftype.
            attics_by_rooftype = {}
            for atticd in atticds:
                try:
                    attics_by_rooftype[atticd['rooftype']].append(atticd)
                except KeyError:
                    attics_by_rooftype[atticd['rooftype']] = [atticd]

            # Determine predominant roof characteristics for each rooftype.
            combined_atticds = []
            for rooftype, atticds in list(attics_by_rooftype.items()):
                combined_atticd = {}

                # Roof Area
                combined_atticd['roof_area'] = sum([atticd['roof_area'] for atticd in atticds])

                # Roof type, roof color, exterior finish, construction type
                for attic_key in ('roofconstype', 'extfinish', 'roofcolor', 'rooftype'):
                    roof_area_by_cat = {}
                    for atticd in atticds:
                        try:
                            roof_area_by_cat[atticd[attic_key]] += atticd['roof_area']
                        except KeyError:
                            roof_area_by_cat[atticd[attic_key]] = atticd['roof_area']
                    combined_atticd[attic_key] = max(roof_area_by_cat, key=lambda x: roof_area_by_cat[x])

                # ids of hpxml roofs along for the ride
                combined_atticd['_roofids'] = set().union(*[atticd['_roofid'] for atticd in atticds])

                # Calculate roof area weighted center of cavity R-value
                combined_atticd['roof_coc_rvalue'] = \
                    combined_atticd['roof_area'] / \
                    sum([old_div(atticd['roof_area'], atticd['roof_coc_rvalue']) for atticd in atticds])

                # Calculate attic floor weighted average center-of-cavity R-value
                combined_atticd['attic_floor_coc_rvalue'] = \
                    sum([atticd['attic_floor_coc_rvalue'] * atticd['roof_area'] for atticd in atticds]) / \
                    combined_atticd['roof_area']
                combined_atticds.append(combined_atticd)

            atticds = combined_atticds
            del combined_atticds
            del attics_by_rooftype

        # Order the attic/roofs from largest to smallest
        atticds.sort(key=lambda x: x['roof_area'], reverse=True)

        # Take the largest two
        zone_roof = []
        for i, atticd in enumerate(atticds[0:2], 1):

            # Get Roof R-value
            roffset = roof_center_of_cavity_rvalues[atticd['roofconstype']][atticd['extfinish']][0]
            roof_rvalue = min(list(roof_center_of_cavity_rvalues[atticd['roofconstype']][atticd['extfinish']].keys()),
                              key=lambda x: abs(atticd['roof_coc_rvalue'] - roffset - x))

            # Get Attic Floor R-value
            attic_floor_rvalue = min(attic_floor_rvalues,
                                     key=lambda x: abs(atticd['attic_floor_coc_rvalue'] - 0.5 - x))

            # store it all
            zone_roof_item = OrderedDict()
            zone_roof_item['roof_name'] = 'roof%d' % i
            zone_roof_item['roof_area'] = atticd['roof_area']
            zone_roof_item['roof_assembly_code'] = 'rf%s%02d%s' % (
                atticd['roofconstype'], roof_rvalue, atticd['extfinish'])
            zone_roof_item['roof_color'] = atticd['roofcolor']
            if 'roof_absorptance' in atticd:
                zone_roof_item['roof_absorptance'] = atticd['roof_absorptance']
            zone_roof_item['roof_type'] = atticd['rooftype']
            zone_roof_item['_roofids'] = atticd['_roofids']
            if atticd['rooftype'] != 'cath_ceiling':
                zone_roof_item['ceiling_assembly_code'] = 'ecwf%02d' % attic_floor_rvalue
            zone_roof.append(zone_roof_item)

        return zone_roof

    def get_skylights(self, b, zone_roof):
        ns = self.ns
        xpath = self.xpath
        skylights = b.xpath('descendant::h:Skylight', namespaces=ns)

        skylight_by_roof_id = {}
        skylight_by_roof_num = {}
        for i in range(len(zone_roof)):
            skylight_by_roof_num[i] = []

        for skylight in skylights:
            if xpath(skylight, 'h:AttachedToRoof/@idref') is None:
                # No roof attached, attach to the first roof
                skylight_by_roof_num[0].append(skylight)
            else:
                try:
                    skylight_by_roof_id[xpath(skylight, 'h:AttachedToRoof/@idref')].append(skylight)
                except KeyError:
                    skylight_by_roof_id[xpath(skylight, 'h:AttachedToRoof/@idref')] = []
                    skylight_by_roof_id[xpath(skylight, 'h:AttachedToRoof/@idref')].append(skylight)

        for roof_id, skylights in list(skylight_by_roof_id.items()):
            # roof_found = False
            for i in range(len(zone_roof)):
                if roof_id in zone_roof[i]['_roofids']:
                    # roof_found = True
                    for skylight in skylights:
                        skylight_by_roof_num[i].append(skylight)
                    break
            # if not roof_found:
                # The roof attached is not simulated, should we: 1. attach to the first roof or 2. discard the skylight?
                # for skylight in skylights:
                #     skylight_by_roof_num[0].append(skylight)

        # combine skylights by roof_num
        zone_skylight = []
        for roof_num, skylights in list(skylight_by_roof_num.items()):
            skylight_d = OrderedDict()
            zone_skylight.append(skylight_d)

            if len(skylights) == 0:
                skylight_d['skylight_area'] = 0
                continue
            # Get areas, u-factors, and shgcs if they exist
            uvalues, shgcs, areas = map(list, zip(*[[xpath(skylight, 'h:%s/text()' % x)
                                                     for x in ('UFactor', 'SHGC', 'Area')]
                                                    for skylight in skylights]))
            if None in areas:
                raise TranslationError('Every skylight needs an area.')
            areas = list(map(float, areas))
            skylight_d['skylight_area'] = sum(areas)

            # Remove skylights from the calculation where a uvalue or shgc isn't set.
            idxstoremove = set()
            for i, uvalue in enumerate(uvalues):
                if uvalue is None:
                    idxstoremove.add(i)
            for i, shgc in enumerate(shgcs):
                if shgc is None:
                    idxstoremove.add(i)
            for i in sorted(idxstoremove, reverse=True):
                uvalues.pop(i)
                shgcs.pop(i)
                areas.pop(i)
            assert len(uvalues) == len(shgcs)
            uvalues = list(map(float, uvalues))
            shgcs = list(map(float, shgcs))

            if len(uvalues) > 0:
                # Use an area weighted average of the uvalues, shgcs
                skylight_d['skylight_method'] = 'custom'
                skylight_d['skylight_u_value'] = old_div(sum(
                    [uvalue * area for (uvalue, area) in zip(uvalues, areas)]), sum(areas))
                skylight_d['skylight_shgc'] = sum([shgc * area for (shgc, area) in zip(shgcs, areas)]) / sum(areas)
            else:
                # use a construction code
                skylight_type_areas = {}
                for skylight in skylights:
                    area = convert_to_type(float, xpath(skylight, 'h:Area/text()', raise_err=True))
                    skylight_code = self.get_window_code(skylight)
                    try:
                        skylight_type_areas[skylight_code] += area
                    except KeyError:
                        skylight_type_areas[skylight_code] = area
                skylight_d['skylight_method'] = 'code'
                skylight_d['skylight_code'] = max(list(skylight_type_areas.items()), key=lambda x: x[1])[0]
            skylight_solarscreen_areas = {}
            for skylight in skylights:
                solar_screen = self.get_solarscreen(skylight)
                area = convert_to_type(float, xpath(skylight, 'h:Area/text()', raise_err=True))
                try:
                    skylight_solarscreen_areas[solar_screen] += area
                except KeyError:
                    skylight_solarscreen_areas[solar_screen] = area

            skylight_d['solar_screen'] = max(list(skylight_solarscreen_areas.items()), key=lambda x: x[1])[0]

        return zone_skylight

    def get_building_zone_floor(self, b, bldg_about):
        ns = self.ns
        xpath = self.xpath
        smallnum = 0.01

        # building.zone.zone_floor-------------------------------------------------
        zone_floors = []

        foundations = b.xpath('descendant::h:Foundations/h:Foundation', namespaces=ns)

        foundations, get_fnd_area = self.sort_foundations(foundations, b)
        areas = list(map(get_fnd_area, foundations))
        if len(areas) > 1:
            for area in areas:
                if abs(area) < smallnum:  # area == 0
                    raise TranslationError(
                        'If there is more than one foundation, each needs an area specified on either "Slab" or '
                        '"FrameFloor" attached.'
                    )
        sum_area_largest_two = sum(areas[0:2])
        sum_area = sum(areas)
        try:
            area_mult = old_div(sum_area, sum_area_largest_two)
        except ZeroDivisionError:
            area_mult = 0

        # Map the top two
        for i, (foundation, area) in enumerate(zip(foundations[0:2], areas[0:2]), 1):
            zone_floor = OrderedDict()

            # Floor name
            zone_floor['floor_name'] = 'floor%d' % i

            # Floor area
            zone_floor['floor_area'] = area * area_mult

            # Foundation type
            hpxml_foundation_type = xpath(foundation, 'name(h:FoundationType/*)', raise_err=True)
            if hpxml_foundation_type == 'Basement':
                bsmtcond = xpath(foundation, 'h:FoundationType/h:Basement/h:Conditioned="true"')
                if bsmtcond:
                    zone_floor['foundation_type'] = 'cond_basement'
                else:
                    # assumed unconditioned basement if h:Conditioned is missing
                    zone_floor['foundation_type'] = 'uncond_basement'
            elif hpxml_foundation_type == 'Crawlspace':
                crawlvented = xpath(foundation, 'h:FoundationType/h:Crawlspace/h:Vented="true"')
                if crawlvented:
                    zone_floor['foundation_type'] = 'vented_crawl'
                else:
                    # assumes unvented crawlspace if h:Vented is missing.
                    zone_floor['foundation_type'] = 'unvented_crawl'
            elif hpxml_foundation_type == 'SlabOnGrade':
                zone_floor['foundation_type'] = 'slab_on_grade'
            elif hpxml_foundation_type == 'Garage':
                zone_floor['foundation_type'] = 'unvented_crawl'
            elif hpxml_foundation_type == 'Ambient':
                zone_floor['foundation_type'] = 'vented_crawl'
            else:
                raise TranslationError(
                    'HEScore does not have a foundation type analogous to: %s' %
                    hpxml_foundation_type)

            # Now that we know the foundation type, we can specify the floor area as the footprint area if there's
            # only one foundation.
            if abs(area) < smallnum:
                assert len(foundations) == 1  # We should only be here if there's only one foundation
                nstories = bldg_about['num_floor_above_grade']
                if zone_floor['foundation_type'] == 'cond_basement':
                    nstories += 1
                zone_floor['floor_area'] = old_div(bldg_about['conditioned_floor_area'], nstories)

            # Foundation Wall insulation R-value
            fwua = 0
            fwtotalarea = 0
            foundationwalls = self.get_foundation_walls(foundation, b)
            fw_eff_rvalues = dict(list(zip((0, 5, 11, 19), (4, 7.9, 11.6, 19.6))))
            if len(foundationwalls) > 0:
                if zone_floor['foundation_type'] == 'slab_on_grade':
                    raise TranslationError('The house is a slab on grade foundation, but has foundation walls.')
                del fw_eff_rvalues[5]  # remove the value for slab insulation
                for fwall in foundationwalls:
                    fwarea, fwlength, fwheight = \
                        [convert_to_type(float, xpath(fwall, 'h:%s/text()' % x)) for x in ('Area', 'Length', 'Height')]
                    if fwarea is None:
                        try:
                            fwarea = fwlength * fwheight
                        except TypeError:
                            if len(foundationwalls) == 1:
                                fwarea = 1.0
                            else:
                                raise TranslationError(
                                    'If there is more than one FoundationWall, an Area is required for each.')
                    fwrvalue = xpath(fwall, 'sum(h:Insulation/h:Layer/h:NominalRValue)')
                    fweffrvalue = fw_eff_rvalues[min(list(fw_eff_rvalues.keys()), key=lambda x: abs(fwrvalue - x))]
                    fwua += old_div(fwarea, fweffrvalue)
                    fwtotalarea += fwarea
                zone_floor['foundation_insulation_level'] = old_div(fwtotalarea, fwua) - 4.0
            elif zone_floor['foundation_type'] == 'slab_on_grade':
                del fw_eff_rvalues[11]  # remove unused values
                del fw_eff_rvalues[19]
                slabs = self.get_foundation_slabs(foundation, b)
                slabua = 0
                slabtotalperimeter = 0
                for slab in slabs:
                    exp_perimeter = convert_to_type(float, xpath(slab, 'h:ExposedPerimeter/text()'))
                    if exp_perimeter is None:
                        if len(slabs) == 1:
                            exp_perimeter = 1.0
                        else:
                            raise TranslationError(
                                'If there is more than one Slab, an ExposedPerimeter is required for each.')
                    slabrvalue = xpath(slab, 'sum(h:PerimeterInsulation/h:Layer/h:NominalRValue)')
                    slabeffrvalue = fw_eff_rvalues[min(list(fw_eff_rvalues.keys()), key=lambda x: abs(slabrvalue - x))]
                    slabua += old_div(exp_perimeter, slabeffrvalue)
                    slabtotalperimeter += exp_perimeter
                zone_floor['foundation_insulation_level'] = old_div(slabtotalperimeter, slabua) - 4.0
            else:
                zone_floor['foundation_insulation_level'] = 0
            zone_floor['foundation_insulation_level'] = min(list(fw_eff_rvalues.keys()), key=lambda x: abs(
                zone_floor['foundation_insulation_level'] - x))

            # floor above foundation insulation
            if zone_floor['foundation_type'] != 'slab_on_grade':
                ffua = 0
                fftotalarea = 0
                framefloors = self.get_foundation_frame_floors(foundation, b)
                floor_eff_rvalues = dict(zip((0, 11, 13, 15, 19, 21, 25, 30, 38),
                                             (4.0, 15.8, 17.8, 19.8, 23.8, 25.8, 31.8, 37.8, 42.8)))
                if len(framefloors) > 0:
                    for framefloor in framefloors:
                        ffarea = convert_to_type(float, xpath(framefloor, 'h:Area/text()'))
                        if ffarea is None:
                            if len(framefloors) == 1:
                                ffarea = 1.0
                            else:
                                raise TranslationError(
                                    'If there is more than one FrameFloor, an Area is required for each.')
                        ffrvalue = xpath(framefloor, 'sum(h:Insulation/h:Layer/h:NominalRValue)')
                        ffeffrvalue = floor_eff_rvalues[min(
                            list(floor_eff_rvalues.keys()),
                            key=lambda x: abs(ffrvalue - x)
                        )]
                        ffua += old_div(ffarea, ffeffrvalue)
                        fftotalarea += ffarea
                    ffrvalue = old_div(fftotalarea, ffua) - 4.0
                    zone_floor['floor_assembly_code'] = 'efwf%02dca' % min(list(floor_eff_rvalues.keys()),
                                                                           key=lambda x: abs(ffrvalue - x))
                else:
                    zone_floor['floor_assembly_code'] = 'efwf00ca'

            zone_floors.append(zone_floor)

        return zone_floors

    def get_building_zone_wall(self, b, bldg_about):
        xpath = self.xpath
        ns = self.ns
        sidemap = self.sidemap

        # building.zone.zone_wall--------------------------------------------------
        zone_wall = []

        hpxmlwalls = dict([(side, []) for side in list(sidemap.values())])
        hpxmlwalls['noside'] = []
        for wall in self.get_hescore_walls(b):
            walld = {'assembly_code': self.get_wall_assembly_code(wall),
                     'area': convert_to_type(float, xpath(wall, 'h:Area/text()')),
                     'id': xpath(wall, 'h:SystemIdentifier/@id', raise_err=True)}

            try:
                wall_azimuth = self.get_nearest_azimuth(xpath(wall, 'h:Azimuth/text()'),
                                                        xpath(wall, 'h:Orientation/text()'))
            except TranslationError:
                # There is no directional information in the HPXML wall
                wall_side = 'noside'
                hpxmlwalls[wall_side].append(walld)
            else:
                try:
                    wall_side = sidemap[wall_azimuth]
                except KeyError:
                    # The direction of the wall is in between sides
                    # split the area between sides
                    walld['area'] /= 2.0
                    hpxmlwalls[sidemap[unspin_azimuth(wall_azimuth + 45)]].append(dict(walld))
                    hpxmlwalls[sidemap[unspin_azimuth(wall_azimuth - 45)]].append(dict(walld))
                else:
                    hpxmlwalls[wall_side].append(walld)

        if len(hpxmlwalls['noside']) > 0 and list(map(len, [hpxmlwalls[key] for key in sidemap.values()])) == ([0] * 4):
            all_walls_same = True
            # if none of the walls have orientation information
            # copy the walls to all sides
            for side in list(sidemap.values()):
                hpxmlwalls[side] = hpxmlwalls['noside']
            del hpxmlwalls['noside']
        else:
            all_walls_same = False
            # make sure all of the walls have an orientation
            if len(hpxmlwalls['noside']) > 0:
                raise TranslationError('Some of the HPXML walls have orientation information and others do not.')

        # Wall effective R-value map
        wall_ext_finish_types = ('wo', 'st', 'vi', 'al', 'br', 'nn')
        wall_eff_rvalues = {}
        wall_eff_rvalues['wf'] = dict(
            list(zip(wall_ext_finish_types[:-1], [dict(list(zip((0, 3, 7, 11, 13, 15, 19, 21), x)))  # noqa: E501
                                                  for x in
                                                  [(3.6, 5.7, 9.7, 13.7, 15.7, 17.7, 21.7, 23.7),
                                                   (2.3, 4.4, 8.4, 12.4, 14.4, 16.4, 20.4, 22.4),
                                                   (2.2, 4.3, 8.3, 12.3, 14.3, 16.3, 20.3, 22.3),
                                                   (2.1, 4.2, 8.2, 12.2, 14.2, 16.2, 20.2, 22.2),
                                                   (2.9, 5.0, 9.0, 13.0, 15.0, 17.0, 21.0, 23.0)]])))  # noqa: E501
        wall_eff_rvalues['ps'] = dict(
            list(zip(wall_ext_finish_types[:-1], [dict(list(zip((0, 3, 7, 11, 13, 15, 19, 21), x)))  # noqa: E501
                                                  for x in
                                                  [(6.1, 9.1, 13.1, 17.1, 19.1, 21.1, 25.1, 27.1),  # noqa: E501
                                                   (5.4, 8.4, 12.4, 16.4, 18.4, 20.4, 24.4, 26.4),  # noqa: E501
                                                   (5.3, 8.3, 12.3, 16.3, 18.3, 20.3, 24.3, 26.3),  # noqa: E501
                                                   (5.2, 8.2, 12.2, 16.2, 18.2, 20.2, 24.2, 26.2),  # noqa: E501
                                                   (6.0, 9.0, 13.0, 17.0, 19.0, 21.0, 25.0, 27.0)]])))  # noqa: E501
        wall_eff_rvalues['ov'] = dict(list(zip(wall_ext_finish_types[:-1], [dict(list(zip((19, 21, 27, 33, 38), x)))
                                                                            for x in [(21.0, 23.0, 29.0, 35.0, 40.0),
                                                                                      (20.3, 22.3, 28.3, 34.3, 39.3),
                                                                                      (20.1, 22.1, 28.1, 34.1, 39.1),
                                                                                      (20.1, 22.1, 28.1, 34.1, 39.1),
                                                                                      (20.9, 22.9, 28.9, 34.9,
                                                                                       39.9)]])))  # noqa: E501
        wall_eff_rvalues['br'] = {'nn': dict(list(zip((0, 5, 10), (2.9, 7.9, 12.8))))}
        wall_eff_rvalues['cb'] = dict(list(zip(('st', 'br', 'nn'), [dict(list(zip((0, 3, 6), x)))
                                                                    for x in [(4.1, 5.7, 8.5),
                                                                              (5.6, 7.2, 10),
                                                                              (4, 5.6, 8.3)]])))
        wall_eff_rvalues['sb'] = {'st': {0: 58.8}}

        # build HEScore walls
        for side in list(sidemap.values()):
            if len(hpxmlwalls[side]) == 0:
                continue
            heswall = OrderedDict()
            heswall['side'] = side
            if len(hpxmlwalls[side]) == 1 and hpxmlwalls[side][0]['area'] is None:
                hpxmlwalls[side][0]['area'] = 1.0
            elif len(hpxmlwalls[side]) > 1 and None in [x['area'] for x in hpxmlwalls[side]]:
                raise TranslationError('The %s side of the house has %d walls and they do not all have areas.' % (
                    side, len(hpxmlwalls[side])))
            if len(hpxmlwalls[side]) == 1:
                heswall['wall_assembly_code'] = hpxmlwalls[side][0]['assembly_code']
            else:
                wall_const_type_ext_finish_areas = defaultdict(float)
                wallua = 0
                walltotalarea = 0
                for walld in hpxmlwalls[side]:
                    const_type = walld['assembly_code'][2:4]
                    ext_finish = walld['assembly_code'][6:8]
                    rvalue = int(walld['assembly_code'][4:6])
                    eff_rvalue = wall_eff_rvalues[const_type][ext_finish][rvalue]
                    wallua += old_div(walld['area'], eff_rvalue)
                    walltotalarea += walld['area']
                    wall_const_type_ext_finish_areas[(const_type, ext_finish)] += walld['area']
                const_type, ext_finish = max(list(wall_const_type_ext_finish_areas.keys()),
                                             key=lambda x: wall_const_type_ext_finish_areas[x])
                try:
                    roffset = wall_eff_rvalues[const_type][ext_finish][0]
                except KeyError:
                    rvalue, eff_rvalue = min(list(wall_eff_rvalues[const_type][ext_finish].items()), key=lambda x: x[0])
                    roffset = eff_rvalue - rvalue
                rvalueavgeff = old_div(walltotalarea, wallua)
                rvalueavgnom = rvalueavgeff - roffset
                comb_rvalue = min(list(wall_eff_rvalues[const_type][ext_finish].keys()),
                                  key=lambda x: abs(rvalueavgnom - x))
                heswall['wall_assembly_code'] = 'ew%s%02d%s' % (const_type, comb_rvalue, ext_finish)
            zone_wall.append(heswall)

        # building.zone.zone_wall.zone_window--------------------------------------
        # Assign each window to a side of the house
        hpxmlwindows = dict([(side, []) for side in list(sidemap.values())])
        for hpxmlwndw in b.xpath('h:BuildingDetails/h:Enclosure/h:Windows/h:Window', namespaces=ns):

            # Get the area, solar screen, uvalue, SHGC, or window_code
            windowd = {'area': convert_to_type(float, xpath(hpxmlwndw, 'h:Area/text()', raise_err=True))}
            windowd['uvalue'] = convert_to_type(float, xpath(hpxmlwndw, 'h:UFactor/text()'))
            windowd['shgc'] = convert_to_type(float, xpath(hpxmlwndw, 'h:SHGC/text()'))
            windowd['solar_screen'] = self.get_solarscreen(hpxmlwndw)
            if windowd['uvalue'] is not None and windowd['shgc'] is not None:
                windowd['window_code'] = None
            else:
                windowd['window_code'] = self.get_window_code(hpxmlwndw)

            # Window side
            window_sides = []
            window_id = xpath(hpxmlwndw, 'h:SystemIdentifier/@id')
            try:
                # Get the aziumuth or orientation if they exist
                wndw_azimuth = self.get_nearest_azimuth(xpath(hpxmlwndw, 'h:Azimuth/text()'),
                                                        xpath(hpxmlwndw, 'h:Orientation/text()'))
            except TranslationError:
                # The window doesn't have orientation/azimuth information, get from wall
                attached_to_wall_id = xpath(hpxmlwndw, 'h:AttachedToWall/@idref')
                if attached_to_wall_id is not None:
                    for side, walls in list(hpxmlwalls.items()):
                        for wall in walls:
                            if attached_to_wall_id == wall['id']:
                                window_sides.append(side)
                                break
                    if not window_sides:
                        raise TranslationError(
                            'The Window[SystemIdentifier/@id="{}"] has no Azimuth or Orientation, '
                            'and the Window/AttachedToWall/@idref of "{}" didn\'t reference a Wall element.'.format(
                                window_id, attached_to_wall_id))
                else:
                    raise TranslationError(
                        'Window[SystemIdentifier/@id="{}"] doesn\'t have Azimuth, Orientation, or AttachedToWall. '
                        'At least one is required.'.format(window_id)  # noqa: E501
                    )
            else:
                # Azimuth found, associate with a side
                try:
                    window_sides = [sidemap[wndw_azimuth]]
                except KeyError:
                    # the direction of the window is between sides, split area
                    window_sides = [sidemap[unspin_azimuth(wndw_azimuth + x)] for x in (-45, 45)]

            # Assign properties and areas to the correct side of the house
            windowd['area'] /= float(len(window_sides))
            for window_side in window_sides:
                hpxmlwindows[window_side].append(dict(windowd))

        def get_shared_wall_sides():
            return set(sidemap.values()) - set(bldg_about['town_house_walls'].split('_'))

        def windows_are_on_shared_walls():
            shared_wall_sides = get_shared_wall_sides()
            for side in shared_wall_sides:
                if len(hpxmlwindows[side]) > 0:
                    return True
            return False

        if bldg_about['shape'] == 'town_house':
            if all_walls_same:
                # Check to make sure the windows aren't on shared walls.
                window_on_shared_wall_fail = windows_are_on_shared_walls()
                if window_on_shared_wall_fail:
                    # Change which walls are shared and check again.
                    if bldg_about['town_house_walls'] == 'back_right_front':
                        bldg_about['town_house_walls'] = 'back_front_left'
                        window_on_shared_wall_fail = windows_are_on_shared_walls()
                if window_on_shared_wall_fail:
                    raise TranslationError('The house has windows on shared walls.')
                # Since there was one wall construction for the whole building,
                # remove the construction for shared walls.
                for side in get_shared_wall_sides():
                    for heswall in zone_wall:
                        if heswall['side'] == side:
                            zone_wall.remove(heswall)
                            break
            else:
                # Make sure that there are walls defined for each side of the house that isn't a shared wall.
                sides_without_heswall = set(self.sidemap.values())
                for heswall in zone_wall:
                    sides_without_heswall.remove(heswall['side'])
                shared_wall_fail = sides_without_heswall != get_shared_wall_sides()
                if shared_wall_fail:
                    # Change which walls are shared and check again.
                    if bldg_about['town_house_walls'] == 'back_right_front':
                        bldg_about['town_house_walls'] = 'back_front_left'
                        shared_wall_fail = sides_without_heswall != get_shared_wall_sides()
                if shared_wall_fail:
                    raise TranslationError(
                        'The house has walls defined for sides {} and shared walls on sides {}.'.format(
                            ', '.join(set(self.sidemap.values()) - sides_without_heswall),
                            ', '.join(get_shared_wall_sides())
                        )
                    )
                if windows_are_on_shared_walls():
                    raise TranslationError('The house has windows on shared walls.')

        # Determine the predominant window characteristics and create HEScore windows
        for side, windows in list(hpxmlwindows.items()):

            # Add to the correct wall
            wall_found = False
            for heswall in zone_wall:
                if heswall['side'] == side:
                    wall_found = True
                    break
            if not wall_found:
                continue

            zone_window = OrderedDict()
            heswall['zone_window'] = zone_window

            # If there are no windows on that side of the house
            if len(windows) == 0:
                zone_window['window_area'] = 0
                zone_window['window_method'] = 'code'
                zone_window['window_code'] = 'scna'
                zone_window['solar_screen'] = False
                continue

            # Get the list of uvalues and shgcs for the windows on this side of the house.
            uvalues, shgcs, areas = map(list,
                                        zip(*[[window[x] for x in ('uvalue', 'shgc', 'area')] for window in windows]))

            zone_window['window_area'] = sum(areas)

            # Remove windows from the calculation where a uvalue or shgc isn't set.
            idxstoremove = set()
            for i, uvalue in enumerate(uvalues):
                if uvalue is None:
                    idxstoremove.add(i)
            for i, shgc in enumerate(shgcs):
                if shgc is None:
                    idxstoremove.add(i)
            for i in sorted(idxstoremove, reverse=True):
                uvalues.pop(i)
                shgcs.pop(i)
                areas.pop(i)
            assert len(uvalues) == len(shgcs)
            if len(uvalues) > 0:
                # Use an area weighted average of the uvalues, shgcs
                zone_window['window_method'] = 'custom'
                zone_window['window_u_value'] = \
                    sum([uvalue * area for (uvalue, area) in zip(uvalues, areas)]) / sum(areas)
                zone_window['window_shgc'] = \
                    sum([shgc * area for (shgc, area) in zip(shgcs, areas)]) / sum(areas)
            else:
                # Use a window construction code
                zone_window['window_method'] = 'code'
                # Use the properties of the largest window on the side
                window_code_areas = {}
                for window in windows:
                    assert window['window_code'] is not None
                    try:
                        window_code_areas[window['window_code']] += window['area']
                    except KeyError:
                        window_code_areas[window['window_code']] = window['area']
                zone_window['window_code'] = max(list(window_code_areas.items()), key=lambda x: x[1])[0]
            window_solarscreen_areas = {}
            for window in windows:
                try:
                    window_solarscreen_areas[window['solar_screen']] += window['area']
                except KeyError:
                    window_solarscreen_areas[window['solar_screen']] = window['area']
            zone_window['solar_screen'] = max(list(window_solarscreen_areas.items()), key=lambda x: x[1])[0]
        return zone_wall

    def get_hvac(self, b, bldg):

        def get_dict_of_hpxml_elements_by_id(xpathexpr):
            return_dict = {}
            for el in self.xpath(b, xpathexpr, aslist=True):
                system_id = self.xpath(el, 'h:SystemIdentifier/@id')
                return_dict[system_id] = el
            return return_dict

        def remove_hp_by_zero_value(test_variable):
            if test_variable is not None:
                test_variable_value = Decimal(test_variable)
                if test_variable_value == Decimal(0):
                    return True

        # Get all heating systems
        hpxml_heating_systems = get_dict_of_hpxml_elements_by_id(
            'descendant::h:HVACPlant/h:HeatingSystem|descendant::h:HVACPlant/h:HeatPump')

        # Remove heating systems that serve 0% of the heating load
        for key, el in list(hpxml_heating_systems.items()):
            frac_load_str = self.xpath(el, 'h:FractionHeatLoadServed/text()')
            htg_capacity_str = self.xpath(el, 'h:HeatingCapacity/text()')
            htg_capacity_17_str = self.xpath(el, 'h:HeatingCapacity17F/text()')
            if remove_hp_by_zero_value(frac_load_str) or remove_hp_by_zero_value(htg_capacity_str) or \
                    remove_hp_by_zero_value(htg_capacity_17_str):
                del hpxml_heating_systems[key]

        # Get all cooling systems
        hpxml_cooling_systems = get_dict_of_hpxml_elements_by_id(
            'descendant::h:HVACPlant/h:CoolingSystem|descendant::h:HVACPlant/h:HeatPump')

        # Remove cooling systems that serve 0% of the cooling load
        for key, el in list(hpxml_cooling_systems.items()):
            frac_load_str = self.xpath(el, 'h:FractionCoolLoadServed/text()')
            clg_capacity_str = self.xpath(el, 'h:CoolingCapacity/text()')
            if remove_hp_by_zero_value(frac_load_str) or remove_hp_by_zero_value(clg_capacity_str):
                del hpxml_cooling_systems[key]

        # Get all the duct systems
        hpxml_distribution_systems = get_dict_of_hpxml_elements_by_id('descendant::h:HVACDistribution')

        # Connect the heating and cooling systems to their associated distribution systems
        def get_duct_mapping(element_list):
            return_dict = {}
            for system_id, el in list(element_list.items()):
                distribution_system_id = self.xpath(el, 'h:DistributionSystem/@idref')
                if distribution_system_id is None:
                    continue
                if isinstance(distribution_system_id, list):
                    raise TranslationError(
                        'Each HVAC plant is only allowed to specify one duct system. %s references more than one.' %
                        system_id)
                if distribution_system_id in return_dict:
                    raise TranslationError(
                        'Each duct system is only allowed to serve one heating and one cooling system. ' +
                        '%s serves more than one.' %
                        distribution_system_id)
                if distribution_system_id not in hpxml_distribution_systems:
                    raise TranslationError(
                        'HVAC plant %s specifies an HPXML distribution system of %s, which does not exist.' %
                        (system_id, distribution_system_id))
                return_dict[distribution_system_id] = system_id
            return return_dict

        dist_heating_map = get_duct_mapping(hpxml_heating_systems)
        dist_cooling_map = get_duct_mapping(hpxml_cooling_systems)

        # Remove distribution systems that aren't referenced by any equipment.
        for dist_sys_id, el in list(hpxml_distribution_systems.items()):
            if not (dist_sys_id in dist_heating_map or dist_sys_id in dist_cooling_map):
                del hpxml_distribution_systems[dist_sys_id]

        # Merge the maps
        # {'duct1': ('furnace1', 'centralair1'), 'duct2': ('furnace2', None), ... }
        dist_heating_cooling_map = {}
        for dist_sys_id in list(hpxml_distribution_systems.keys()):
            dist_heating_cooling_map[dist_sys_id] = tuple(
                [x.get(dist_sys_id) for x in (dist_heating_map, dist_cooling_map)]
            )

        # Find the heating and cooling systems not associated with a distribution system
        singleton_heating_systems = set(hpxml_heating_systems.keys())
        singleton_cooling_systems = set(hpxml_cooling_systems.keys())
        if len(dist_heating_cooling_map) > 0:
            associated_heating_systems, associated_cooling_systems = list(zip(*list(dist_heating_cooling_map.values())))
        else:
            associated_heating_systems = []
            associated_cooling_systems = []
        singleton_heating_systems.difference_update(associated_heating_systems)
        singleton_cooling_systems.difference_update(associated_cooling_systems)

        # Translate each heating system into HEScore inputs
        heating_systems = {}
        for key, el in list(hpxml_heating_systems.items()):
            heating_systems[key] = self.get_heating_system_type(el)

        # Translate each cooling system into HEScore inputs
        cooling_systems = {}
        for key, el in list(hpxml_cooling_systems.items()):
            cooling_systems[key] = self.get_cooling_system_type(el)

        # Translate each duct system into HEScore inputs
        distribution_systems = {}
        for key, el in list(hpxml_distribution_systems.items()):
            distribution_systems[key] = self.get_hvac_distribution(el, bldg)

        # Determine the weighting factors

        # If there's only one heating or cooling system and no weighting elements, fill it in.
        for heating_or_cooling_systems in (heating_systems, cooling_systems):
            if len(heating_or_cooling_systems) == 1:
                for key, hvac_sys in heating_or_cooling_systems.items():
                    if hvac_sys.get('_floorarea') is None and hvac_sys.get('_fracload') is None:
                        hvac_sys['_fracload'] = 1.0
                        hvac_sys['_floorarea'] = bldg['about']['conditioned_floor_area']

        # Choose a weighting factor that all the heating and cooling systems use
        all_systems = []
        all_systems.extend(heating_systems.values())
        all_systems.extend(cooling_systems.values())
        found_weighting_factor = False
        for weighting_factor in ['_floorarea', '_fracload']:
            if None not in [x.get(weighting_factor) for x in all_systems]:
                found_weighting_factor = True
                break
        if not found_weighting_factor:
            raise TranslationError(
                'Every heating/cooling system needs to have either FloorAreaServed or '
                'FracHeatLoadServed/FracCoolLoadServed.'
            )

        # Calculate the sum of the weights (total fraction or floor area)
        weight_sum = max(
            sum([x[weighting_factor] for x in heating_systems.values()]),
            sum([x[weighting_factor] for x in cooling_systems.values()])
        )

        # Ensure that heating and cooling systems attached to the same ducts are within 5% of each other
        # in terms of fraction of the load served.
        for duct_id, (htg_id, clg_id) in list(dist_heating_cooling_map.items()):
            try:
                htg_weight = old_div(heating_systems[htg_id][weighting_factor], weight_sum)
                clg_weight = old_div(cooling_systems[clg_id][weighting_factor], weight_sum)
            except KeyError:
                continue
            if abs(htg_weight - clg_weight) > 0.051:
                raise TranslationError(
                    'Heating system "{}" and cooling system "{}" are attached to the same '
                    'distribution system "{}" need to serve the same '
                    'fraction of the load within 5% but do not.'.format(
                        htg_id, clg_id, duct_id
                    )
                )

        # Check to make sure heating and cooling systems that need a distribution system have them.
        heating_sys_types_requiring_ducts = ('gchp', 'heat_pump', 'central_furnace')
        for htg_sys_id, htg_sys in list(heating_systems.items()):
            if htg_sys['type'] in heating_sys_types_requiring_ducts and htg_sys_id not in dist_heating_map.values():
                raise TranslationError('Heating system %s is not associated with an air distribution system.' %
                                       htg_sys_id)
        cooling_sys_types_requiring_ducts = ('split_dx', 'heat_pump', 'gchp')
        for clg_sys_id, clg_sys in list(cooling_systems.items()):
            if clg_sys['type'] in cooling_sys_types_requiring_ducts and clg_sys_id not in dist_cooling_map.values():
                raise TranslationError('Cooling system %s is not associated with an air distribution system.' %
                                       clg_sys_id)

        # Determine a total weighting factor for each combined heating/cooling/distribution system
        # Create a list of systems including the weights that we can sort
        # hvac_systems_ids = set([('htg_id', 'clg_id', 'dist_id', weight), ...])
        hvac_systems_ids = set()
        IDsAndWeights = namedtuple('IDsAndWeights', ['htg_id', 'clg_id', 'dist_id', 'weight'])
        for dist_sys_id, (htg_sys_id, clg_sys_id) in list(dist_heating_cooling_map.items()):
            weights_to_average = []
            if htg_sys_id is not None:
                weights_to_average.append(old_div(heating_systems[htg_sys_id][weighting_factor], weight_sum))
            if clg_sys_id is not None:
                weights_to_average.append(old_div(cooling_systems[clg_sys_id][weighting_factor], weight_sum))
            avg_sys_weight = old_div(sum(weights_to_average), len(weights_to_average))
            hvac_systems_ids.add(IDsAndWeights(htg_sys_id, clg_sys_id, dist_sys_id, avg_sys_weight))

        singletons_to_combine = singleton_cooling_systems.intersection(singleton_heating_systems)
        singleton_heating_systems -= singletons_to_combine
        singleton_cooling_systems -= singletons_to_combine
        for heatpump_id in singletons_to_combine:
            if heating_systems[heatpump_id]['type'] != 'mini_split' or \
                    cooling_systems[heatpump_id]['type'] != 'mini_split':  # noqa: E501
                continue
            hvac_systems_ids.add(IDsAndWeights(
                heatpump_id,
                heatpump_id,
                None,
                old_div(heating_systems[heatpump_id][weighting_factor], weight_sum)))

        # Add the singletons to the list
        for htg_sys_id in singleton_heating_systems:
            hvac_systems_ids.add(IDsAndWeights(
                htg_sys_id,
                None,
                None,
                old_div(heating_systems[htg_sys_id][weighting_factor], weight_sum)))
        for clg_sys_id in singleton_cooling_systems:
            hvac_systems_ids.add(IDsAndWeights(
                None,
                clg_sys_id,
                None,
                old_div(cooling_systems[clg_sys_id][weighting_factor], weight_sum)))

        # Split and combine systems by fraction as needed #45
        singleton_heating_systems = []
        singleton_cooling_systems = []
        for hvac_ids in hvac_systems_ids:
            if hvac_ids.clg_id is not None and hvac_ids.htg_id is None:
                singleton_cooling_systems.append(hvac_ids)
            elif hvac_ids.htg_id is not None and hvac_ids.clg_id is None:
                singleton_heating_systems.append(hvac_ids)
        hvac_systems_ids.difference_update(singleton_heating_systems)
        hvac_systems_ids.difference_update(singleton_cooling_systems)
        singleton_heating_systems.sort(key=lambda x: x.weight, reverse=True)
        singleton_cooling_systems.sort(key=lambda x: x.weight, reverse=True)
        singleton_heating_systems_iter = iter(singleton_heating_systems)
        singleton_cooling_systems_iter = iter(singleton_cooling_systems)

        def iter_next(_iter):
            try:
                retval = next(_iter)
            except StopIteration:
                retval = None
            return retval

        def choose_dist_system(first_choice_dist_id, second_choice_dist_id):
            if first_choice_dist_id is not None and distribution_systems[first_choice_dist_id] is not None:
                dist_id = first_choice_dist_id
            else:
                dist_id = second_choice_dist_id
            return dist_id

        hvac_htg = iter_next(singleton_heating_systems_iter)
        hvac_clg = iter_next(singleton_cooling_systems_iter)
        while not (hvac_htg is None and hvac_clg is None):
            if hvac_htg is not None and hvac_clg is not None:
                if hvac_htg.weight > hvac_clg.weight:
                    hvac_comb = IDsAndWeights(
                        htg_id=hvac_htg.htg_id,
                        clg_id=hvac_clg.clg_id,
                        dist_id=choose_dist_system(hvac_clg.dist_id, hvac_htg.dist_id),
                        weight=hvac_clg.weight
                    )
                    hvac_systems_ids.add(hvac_comb)
                    hvac_htg = hvac_htg._replace(weight=hvac_htg.weight - hvac_clg.weight)
                    hvac_clg = iter_next(singleton_cooling_systems_iter)
                elif hvac_clg.weight > hvac_htg.weight:
                    hvac_comb = IDsAndWeights(
                        htg_id=hvac_htg.htg_id,
                        clg_id=hvac_clg.clg_id,
                        dist_id=choose_dist_system(hvac_htg.dist_id, hvac_clg.dist_id),
                        weight=hvac_htg.weight
                    )
                    hvac_systems_ids.add(hvac_comb)
                    hvac_clg = hvac_clg._replace(weight=hvac_clg.weight - hvac_htg.weight)
                    hvac_htg = iter_next(singleton_heating_systems_iter)
                else:
                    assert hvac_clg.weight == hvac_htg.weight
                    hvac_comb = IDsAndWeights(
                        htg_id=hvac_htg.htg_id,
                        clg_id=hvac_clg.clg_id,
                        dist_id=choose_dist_system(hvac_htg.dist_id, hvac_clg.dist_id),
                        weight=hvac_htg.weight
                    )
                    hvac_systems_ids.add(hvac_comb)
                    hvac_htg = iter_next(singleton_heating_systems_iter)
                    hvac_clg = iter_next(singleton_cooling_systems_iter)
            elif hvac_clg is None:
                hvac_systems_ids.add(hvac_htg)
                hvac_htg = iter_next(singleton_heating_systems_iter)
            elif hvac_htg is None:
                hvac_systems_ids.add(hvac_clg)
                hvac_clg = iter_next(singleton_cooling_systems_iter)
            else:
                assert False

        # Sort by weights
        hvac_systems_ids = sorted(hvac_systems_ids, key=lambda x: x.weight, reverse=True)

        # Return the first two
        hp_list = ['heat_pump', 'gchp', 'mini_split']
        hvac_systems = []
        hvac_sys_weight_sum = sum([x.weight for x in hvac_systems_ids[0:2]])
        for i, hvac_ids in enumerate(hvac_systems_ids[0:2], 1):
            hvac_sys = OrderedDict()
            hvac_sys['hvac_name'] = 'hvac%d' % i
            hvac_sys['hvac_fraction'] = round(old_div(hvac_ids.weight, hvac_sys_weight_sum), 6)
            if hvac_ids.htg_id is not None:
                hvac_sys['heating'] = heating_systems[hvac_ids.htg_id]
            else:
                hvac_sys['heating'] = {'type': 'none'}
            if hvac_ids.clg_id is not None:
                hvac_sys['cooling'] = cooling_systems[hvac_ids.clg_id]
            else:
                hvac_sys['cooling'] = {'type': 'none'}
            if hvac_ids.dist_id is not None:
                hvac_sys['hvac_distribution'] = distribution_systems[hvac_ids.dist_id]

            # Added a error check for separate cooling and heating heat pump system
            if hvac_sys['heating']['type'] in hp_list and hvac_sys['cooling']['type'] in hp_list and \
                    hvac_sys['heating']['type'] != hvac_sys['cooling']['type']:  # noqa: E501
                raise TranslationError('Two different heat pump systems: %s for heating, and %s for cooling '
                                       'are not supported in one hvac system.'
                                       % (hvac_sys['heating']['type'], hvac_sys['cooling']['type']))
            else:
                hvac_systems.append(hvac_sys)

        # Add two checks for hvac system errors
        if len(hvac_systems) > 0:
            # Ensure they sum to 1
            hvac_systems[-1]['hvac_fraction'] += 1.0 - sum([x['hvac_fraction'] for x in hvac_systems])
        else:
            raise TranslationError('No hvac system found.')

        return hvac_systems

    def get_systems_dhw(self, b):
        xpath = self.xpath

        sys_dhw = OrderedDict()

        water_heating_systems = xpath(b, 'descendant::h:WaterHeatingSystem')
        if isinstance(water_heating_systems, list):
            dhwfracs = [
                None if x is None else float(x)
                for x in [
                    xpath(water_heating_system, 'h:FractionDHWLoadServed/text()')
                    for water_heating_system in water_heating_systems
                ]
            ]
            if None in dhwfracs:
                primarydhw = water_heating_systems[0]
            else:
                primarydhw = max(list(zip(water_heating_systems, dhwfracs)), key=lambda x: x[1])[0]
        elif water_heating_systems is None:
            raise TranslationError('No water heating systems found.')
        else:
            primarydhw = water_heating_systems
        water_heater_type = xpath(primarydhw, 'h:WaterHeaterType/text()', raise_err=True)
        if water_heater_type in ('storage water heater', 'dedicated boiler with storage tank'):
            sys_dhw['category'] = 'unit'
            sys_dhw['type'] = 'storage'
            fuel_type = xpath(primarydhw, 'h:FuelType/text()', raise_err=True)
            sys_dhw['fuel_primary'] = self.add_fuel_type(fuel_type)
        elif water_heater_type == 'space-heating boiler with storage tank':
            sys_dhw['category'] = 'combined'
            sys_dhw['type'] = 'indirect'
        elif water_heater_type == 'space-heating boiler with tankless coil':
            sys_dhw['category'] = 'combined'
            sys_dhw['type'] = 'tankless_coil'
        elif water_heater_type == 'heat pump water heater':
            sys_dhw['category'] = 'unit'
            sys_dhw['type'] = 'heat_pump'
            sys_dhw['fuel_primary'] = 'electric'
        elif water_heater_type == 'instantaneous water heater':
            sys_dhw['category'] = 'unit'
            sys_dhw['type'] = 'tankless'
            fuel_type = xpath(primarydhw, 'h:FuelType/text()', raise_err=True)
            sys_dhw['fuel_primary'] = self.add_fuel_type(fuel_type)
        else:
            raise TranslationError('HEScore cannot model the water heater type: %s' % water_heater_type)

        if not sys_dhw['category'] == 'combined':
            energyfactor = xpath(primarydhw, 'h:EnergyFactor/text()')
            unified_energy_factor = xpath(primarydhw, 'h:UniformEnergyFactor/text()')
            if unified_energy_factor is not None:
                sys_dhw['efficiency_method'] = 'uef'
                sys_dhw['energy_factor'] = float(unified_energy_factor)
            elif energyfactor is not None:
                sys_dhw['efficiency_method'] = 'user'
                sys_dhw['energy_factor'] = float(energyfactor)
            else:
                # Tankless type must use energy factor method
                if sys_dhw['type'] == 'tankless':
                    raise TranslationError(
                        'Tankless water heater efficiency cannot be estimated by shipment weighted method.')
                else:
                    dhwyear = int(xpath(primarydhw, '(h:YearInstalled|h:ModelYear)[1]/text()', raise_err=True))
                    if dhwyear < 1972:
                        dhwyear = 1972
                    sys_dhw['efficiency_method'] = 'shipment_weighted'
                    sys_dhw['year'] = dhwyear
        return sys_dhw

    def get_generation(self, b):
        generation = OrderedDict()
        pvsystems = self.xpath(b, 'descendant::h:PVSystem', aslist=True)
        if not pvsystems:
            return generation

        solar_electric = OrderedDict()
        generation['solar_electric'] = solar_electric

        capacities = []
        collector_areas = []
        years = []
        azimuths = []
        tilts = []
        for pvsystem in pvsystems:

            max_power_output = self.xpath(pvsystem, 'h:MaxPowerOutput/text()')
            if max_power_output:
                capacities.append(float(max_power_output))  # W
                collector_areas.append(None)
            else:
                capacities.append(None)
                collector_area = self.xpath(pvsystem, 'h:CollectorArea/text()')
                if collector_area:
                    collector_areas.append(float(collector_area))
                else:
                    raise TranslationError('MaxPowerOutput or CollectorArea is required for every PVSystem.')

            manufacture_years = list(map(
                int,
                self.xpath(
                    pvsystem,
                    'h:YearInverterManufactured/text()|h:YearModulesManufactured/text()',
                    aslist=True)
            )
            )
            if manufacture_years:
                years.append(max(manufacture_years))  # Use the latest year of manufacture
            else:
                raise TranslationError(
                    'Either YearInverterManufactured or YearModulesManufactured is required for every PVSystem.')

            azimuth = self.xpath(pvsystem, 'h:ArrayAzimuth/text()')
            orientation = self.xpath(pvsystem, 'h:ArrayOrientation/text()')
            if azimuth:
                azimuths.append(int(azimuth))
            elif orientation:
                azimuths.append(self.hpxml_orientation_to_azimuth[orientation])
            else:
                raise TranslationError('ArrayAzimuth or ArrayOrientation is required for every PVSystem.')

            tilt = self.xpath(pvsystem, 'h:ArrayTilt/text()')
            if tilt:
                tilts.append(int(tilt))
            else:
                raise TranslationError('ArrayTilt is required for every PVSystem.')

        if None not in capacities:
            solar_electric['capacity_known'] = True
            total_capacity = sum(capacities)
            solar_electric['system_capacity'] = total_capacity / 1000.
            solar_electric['year'] = int(
                old_div(sum([year * capacity for year, capacity in zip(years, capacities)]), total_capacity))
            wtavg_azimuth = old_div(sum(
                [az * capacity for az, capacity in zip(azimuths, capacities)]), total_capacity)
            wtavg_tilt = sum(t * capacity for t, capacity in zip(tilts, capacities)) / total_capacity
        elif None not in collector_areas:
            solar_electric['capacity_known'] = False
            total_area = sum(collector_areas)
            solar_electric['num_panels'] = int(python2round(total_area / 17.6))
            solar_electric['year'] = int(sum([year * area for year, area in zip(years, collector_areas)]) / total_area)
            wtavg_azimuth = old_div(sum(
                [az * area for az, area in zip(azimuths, collector_areas)]
            ), total_area)
            wtavg_tilt = sum(t * area for t, area in zip(tilts, collector_areas)) / total_area
        else:
            raise TranslationError(
                'Either a MaxPowerOutput must be specified for every PVSystem '
                'or CollectorArea must be specified for every PVSystem.'
            )

        nearest_azimuth = self.get_nearest_azimuth(azimuth=wtavg_azimuth)
        solar_electric['array_azimuth'] = self.azimuth_to_hescore_orientation[nearest_azimuth]
        solar_electric['array_tilt'] = self.get_nearest_tilt(wtavg_tilt)

        return generation

    def validate_hescore_inputs(self, hescore_inputs):

        def do_bounds_check(fieldname, value, minincl, maxincl):
            if value < minincl or value > maxincl:
                raise InputOutOfBounds(fieldname, value)

        this_year = dt.datetime.today().year

        do_bounds_check('assessment_date',
                        dt.datetime.strptime(hescore_inputs['building']['about']['assessment_date'], '%Y-%m-%d').date(),
                        dt.date(2010, 1, 1), dt.datetime.today().date())

        do_bounds_check('year_built',
                        hescore_inputs['building']['about']['year_built'],
                        1600, this_year)

        do_bounds_check('number_bedrooms',
                        hescore_inputs['building']['about']['number_bedrooms'],
                        1, 10)

        do_bounds_check('num_floor_above_grade',
                        hescore_inputs['building']['about']['num_floor_above_grade'],
                        1, 4)

        do_bounds_check('floor_to_ceiling_height',
                        hescore_inputs['building']['about']['floor_to_ceiling_height'],
                        6, 12)

        do_bounds_check('conditioned_floor_area',
                        hescore_inputs['building']['about']['conditioned_floor_area'],
                        250, 25000)

        if hescore_inputs['building']['about']['blower_door_test']:
            do_bounds_check('envelope_leakage',
                            hescore_inputs['building']['about']['envelope_leakage'],
                            0, 25000)

        for zone_roof in hescore_inputs['building']['zone']['zone_roof']:
            zone_skylight = zone_roof['zone_skylight']
            do_bounds_check('skylight_area',
                            zone_skylight['skylight_area'],
                            0, 300)

            if zone_skylight['skylight_area'] > 0 and zone_skylight['skylight_method'] == 'custom':
                do_bounds_check('skylight_u_value',
                                zone_skylight['skylight_u_value'],
                                0.01, 5)
                do_bounds_check('skylight_shgc',
                                zone_skylight['skylight_shgc'],
                                0, 1)

        for zone_floor in hescore_inputs['building']['zone']['zone_floor']:
            do_bounds_check('foundation_insulation_level',
                            zone_floor['foundation_insulation_level'],
                            0, 19)

        for zone_wall in hescore_inputs['building']['zone']['zone_wall']:
            zone_window = zone_wall['zone_window']
            do_bounds_check('window_area',
                            zone_window['window_area'],
                            0, 999)
            if zone_window['window_area'] > 0 and zone_window['window_method'] == 'custom':
                do_bounds_check('window_u_value',
                                zone_window['window_u_value'],
                                0.01, 5)
                do_bounds_check('window_shgc',
                                zone_window['window_shgc'],
                                0, 1)

        for sys_hvac in hescore_inputs['building']['systems']['hvac']:

            sys_heating = sys_hvac['heating']
            if sys_heating['type'] not in ('none', 'baseboard', 'wood_stove'):
                if 'efficiency_method' in sys_heating:
                    if sys_heating['efficiency_method'] == 'user':
                        if sys_heating['type'] in ('central_furnace', 'wall_furnace', 'boiler'):
                            do_bounds_check('heating_efficiency', sys_heating['efficiency'], 0.6, 1)
                        elif sys_heating['type'] in ('heat_pump', 'mini_split'):
                            do_bounds_check('heating_efficiency', sys_heating['efficiency'], 6, 20)
                        else:
                            assert sys_heating['type'] == 'gchp'
                            do_bounds_check('heating_efficiency', sys_heating['efficiency'], 2, 5)
                    else:
                        assert sys_heating['efficiency_method'] == 'shipment_weighted'
                        do_bounds_check('heating_year', sys_heating['year'], 1970, this_year)
                else:
                    if not ((sys_heating['type'] in ('central_furnace', 'baseboard') and
                            sys_heating['fuel_primary'] == 'electric') or sys_heating['type'] == 'wood_stove'):
                        raise TranslationError(
                            'Heating system %(fuel_primary)s %(type)s needs an efficiency value.' %
                            sys_heating)

            sys_cooling = sys_hvac['cooling']
            if sys_cooling['type'] not in ('none', 'dec'):
                assert sys_cooling['type'] in ('packaged_dx', 'split_dx', 'heat_pump', 'gchp', 'mini_split')
                if sys_cooling['efficiency_method'] == 'user':
                    do_bounds_check('cooling_efficiency', sys_cooling['efficiency'], 8, 40)
                else:
                    assert sys_cooling['efficiency_method'] == 'shipment_weighted'
                    do_bounds_check('cooling_year',
                                    sys_cooling['year'],
                                    1970, this_year)

            if 'hvac_distribution' in sys_hvac:
                for hvacd in sys_hvac['hvac_distribution']:
                    do_bounds_check('hvac_distribution_fraction',
                                    hvacd['fraction'],
                                    0, 1)

                    # Test if the duct location exists in roof and floor types
                    duct_location_error = False
                    if hvacd['location'] == 'uncond_basement':
                        duct_location_error = 'uncond_basement' not in [
                            zone_floor['foundation_type']
                            for zone_floor in hescore_inputs['building']['zone']['zone_floor']
                        ]
                    elif hvacd['location'] == 'unvented_crawl':
                        duct_location_error = 'unvented_crawl' not in [
                            zone_floor['foundation_type']
                            for zone_floor in hescore_inputs['building']['zone']['zone_floor']
                        ]
                    elif hvacd['location'] == 'vented_crawl':
                        duct_location_error = 'vented_crawl' not in [
                            zone_floor['foundation_type']
                            for zone_floor in hescore_inputs['building']['zone']['zone_floor']
                        ]
                    elif hvacd['location'] == 'uncond_attic':
                        duct_location_error = 'vented_attic' not in [
                            zone_roof['roof_type'] for zone_roof in
                            hescore_inputs['building']['zone']['zone_roof']
                        ]

                    if duct_location_error:
                        raise TranslationError(
                            'HVAC distribution: %(name)s location: %(location)s not exists in zone_roof/floor types.' %
                            hvacd)

        dhw = hescore_inputs['building']['systems']['domestic_hot_water']
        # check range of uef with the same range as ef, add tankless into "type to check" list
        if dhw['type'] in ('storage', 'heat_pump', 'tankless'):
            if dhw['efficiency_method'] == 'user' or dhw['efficiency_method'] == 'uef':
                if dhw['type'] == 'storage' or dhw['type'] == 'tankless':
                    do_bounds_check('domestic_hot_water_energy_factor', dhw['energy_factor'], 0.45, 1.0)
                else:
                    assert dhw['type'] == 'heat_pump'
                    do_bounds_check('domestic_hot_water_energy_factor', dhw['energy_factor'], 1.0, 4.0)
            else:
                assert dhw['efficiency_method'] == 'shipment_weighted'
                do_bounds_check('domestic_hot_water_year',
                                dhw['year'],
                                1972, this_year)
        elif dhw['category'] == 'combined' and dhw['type'] in ('tankless_coil', 'indirect'):
            found_boiler = False
            for sys_hvac in hescore_inputs['building']['systems']['hvac']:
                if 'heating' not in sys_hvac:
                    continue
                if sys_hvac['heating']['type'] == 'boiler':
                    found_boiler = True
            if not found_boiler:
                raise TranslationError('Cannot have water heater type %(type)s if there is no boiler heating system.' %
                                       dhw)
