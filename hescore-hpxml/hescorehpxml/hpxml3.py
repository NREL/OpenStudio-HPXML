from .base import HPXMLtoHEScoreTranslatorBase
from collections import OrderedDict
from .exceptions import TranslationError


def convert_to_type(type_, value):
    if value is None:
        return value
    else:
        return type_(value)


class HPXML3toHEScoreTranslator(HPXMLtoHEScoreTranslatorBase):
    SCHEMA_DIR = 'hpxml-3.0.0'

    def check_hpwes(self, v2_p, b):
        # multiple verification nodes?
        return self.xpath(b, 'h:BuildingDetails/h:GreenBuildingVerifications/h:GreenBuildingVerification/h:Type="Home '
                             'Performance with ENERGY STAR"')

    def sort_foundations(self, fnd, b):
        # Sort the foundations from largest area to smallest
        def get_fnd_area(fnd):
            attached_ids = OrderedDict()
            attached_ids['Slab'] = self.xpath(fnd, 'h:AttachedToSlab/@idref')
            attached_ids['FrameFloor'] = self.xpath(fnd, 'h:AttachedToFrameFloor/@idref')
            return max(
                [self.xpath(b, 'sum(//h:{}[contains("{}", h:SystemIdentifier/@id)]/h:Area)'.format(key, value)) for
                 key, value in attached_ids.items()])

        fnd.sort(key=get_fnd_area, reverse=True)
        return fnd, get_fnd_area

    def get_foundation_walls(self, fnd, b):
        attached_ids = self.xpath(fnd, 'h:AttachedToFoundationWall/@idref')
        foundationwalls = self.xpath(b, '//h:FoundationWall[contains("{}", h:SystemIdentifier/@id)]'.
                                     format(attached_ids), aslist=True)
        return foundationwalls

    def get_foundation_slabs(self, fnd, b):
        attached_ids = self.xpath(fnd, 'h:AttachedToSlab/@idref')
        slabs = self.xpath(b, '//h:Slab[contains("{}", h:SystemIdentifier/@id)]'.format(attached_ids), raise_err=True,
                           aslist=True)
        return slabs

    def get_foundation_frame_floors(self, fnd, b):
        attached_ids = self.xpath(fnd, 'h:AttachedToFrameFloor/@idref')
        frame_floors = self.xpath(b, '//h:FrameFloor[contains("{}",h:SystemIdentifier/@id)]'.format(attached_ids),
                                  aslist=True)
        return frame_floors

    def attic_has_rigid_sheathing(self, v2_attic, roof):
        return self.xpath(roof,
                          'boolean(h:Insulation/h:Layer[h:NominalRValue > 0][h:InstallationType="continuous"]['
                          'boolean(h:InsulationMaterial/h:Rigid)])'
                          # noqa: E501
                          )

    def get_attic_roof_rvalue(self, v2_attic, roof):
        return self.xpath(roof,
                          'sum(h:Insulation/h:Layer/h:NominalRValue)')

    def get_attic_knee_walls(self, attic, b):
        knee_walls = []
        for kneewall_idref in self.xpath(attic, 'h:AttachedToWall/@idref', aslist=True):
            wall = self.xpath(
                b,
                '//h:Wall[h:SystemIdentifier/@id=$kneewallid][h:AtticWallType="knee wall"]',
                raise_err=False,
                kneewallid=kneewall_idref
            )
            if wall is not None:
                knee_walls.append(wall)

        return knee_walls

    def get_attic_type(self, attic, atticid):
        if self.xpath(attic,
                      'h:AtticType/h:Attic/h:CapeCod or boolean(h:AtticType/h:FlatRoof) or boolean('
                      'h:AtticType/h:CathedralCeiling)'):  # noqa: E501
            return 'cath_ceiling'
        elif self.xpath(attic, 'boolean(h:AtticType/h:Attic/h:Conditioned)'):
            return 'cond_attic'
        elif self.xpath(attic, 'boolean(h:AtticType/h:Attic)'):
            return 'vented_attic'
        else:
            raise TranslationError(
                'Attic {}: Cannot translate HPXML AtticType to HEScore rooftype.'.format(atticid))

    def get_attic_floor_rvalue(self, attic, b):
        frame_floors = self.get_attic_floors(attic, b)
        if len(frame_floors) == 0:
            return 0
        if len(frame_floors) == 1:
            return convert_to_type(float, self.xpath(frame_floors[0], 'sum(h:Insulation/h:Layer/h:NominalRValue)'))

        frame_floor_dict_ls = []
        for frame_floor in frame_floors:
            # already confirmed in get_attic_floors that floors are all good with area information
            floor_area = convert_to_type(float, self.xpath(frame_floor, 'h:Area/text()'))
            rvalue = self.xpath(frame_floor, 'sum(h:Insulation/h:Layer/h:NominalRValue)')
            frame_floor_dict_ls.append({'area': floor_area, 'rvalue': rvalue})
        # Average
        try:
            floor_r = sum(x['area'] for x in frame_floor_dict_ls) / \
                      sum(x['area'] / x['rvalue'] for x in frame_floor_dict_ls)
        except ZeroDivisionError:
            floor_r = 0

        return floor_r

    def get_attic_floors(self, attic, b):
        floor_idref = self.xpath(attic, 'h:AttachedToFrameFloor/@idref')
        # No frame floor attached
        if floor_idref is None:
            return []
        frame_floors = self.xpath(b, '//h:FrameFloor[contains("{}",h:SystemIdentifier/@id)]'.format(floor_idref),
                                  aslist=True, raise_err=True)

        return frame_floors

    def get_attic_area(self, attic, is_one_roof, footprint_area, roofs, b):
        # If frame floor specified, look at frame floor for areas, otherwise, roofs. If frame floor is referred
        # without area, will error out no matter if roof is there if there's more than one attics(area for each
        # required).
        # (Should we do in this way?)
        frame_floors = self.get_attic_floors(attic, b)
        if len(frame_floors) > 1:
            # sum frame floor areas if there're more than one frame floors attached
            try:
                return sum(map(lambda x: convert_to_type(float, self.xpath(x, 'h:Area/text()')), frame_floors))
            except TypeError:
                raise TranslationError('If there are more than one FrameFloor elements attached to attic, '
                                       'each needs an area.')
        elif len(frame_floors) == 1:
            # return frame floor area if there's only one frame floor area
            area = convert_to_type(float, self.xpath(frame_floors[0], 'h:Area/text()'))

        # no frame floor attached
        else:
            # Otherwise, get area from roof element
            if len(roofs) > 1:
                try:
                    return sum(map(lambda x: convert_to_type(float, self.xpath(x, 'h:Area/text()')), roofs))
                except TypeError:
                    raise TranslationError('If there are more than one Roof elements attached to attic, '
                                           'each needs an area.')
            else:
                area = convert_to_type(float, self.xpath(roofs[0], 'h:Area/text()'))

        if area is None:
            if is_one_roof:
                return footprint_area
            else:
                raise TranslationError('If there are more than one Attic elements, each needs an area. Please '
                                       'specify under its attached FrameFloor/Roof element.')
        else:
            return area

    def get_attic_roof_area(self, roof):
        return self.xpath(roof, 'h:Area/text()')

    def get_solarscreen(self, wndw_skylight):
        return bool(self.xpath(wndw_skylight, 'h:ExteriorShading/h:Type/text()') == 'solar screens')

    def get_hescore_walls(self, b):
        return self.xpath(b,
                          'h:BuildingDetails/h:Enclosure/h:Walls/h:Wall[h:ExteriorAdjacentTo="outside" or not('
                          'h:ExteriorAdjacentTo)]',
                          # noqa: E501
                          aslist=True)

    def check_is_doublepane(self, window, glass_layers):
        return (self.xpath(window, 'h:StormWindow') is not None and glass_layers == 'single-pane') or \
               glass_layers == 'double-pane'

    def check_is_storm_lowe(self, window, glass_layers):
        storm_type = self.xpath(window, 'h:StormWindow/h:GlassType/text()')
        if storm_type is not None:
            return storm_type == 'low-e' and glass_layers == 'single-pane'
        return False

    def get_duct_location(self, hpxml_duct_location, bldg):
        loc_hierarchy = self.duct_location_map[hpxml_duct_location]
        if loc_hierarchy is None:
            return
        for loc in loc_hierarchy:
            if loc == 'uncond_attic':
                check_loc = 'vented_attic'
            else:
                check_loc = loc
            if check_loc not in [zone_floor['foundation_type'] for zone_floor in bldg['zone']['zone_floor']] and \
                    check_loc not in [zone_roof['roof_type'] for zone_roof in bldg['zone']['zone_roof']]:
                if check_loc != 'cond_space':
                    continue
            return loc

        # Even though going here means duct location is not existing in neither roof type nor floor type,
        # this duct is still likely to be discarded(due to not become the major 3 ducts, not connected to hvac, etc),
        # it's also likely that its corresponding roof/floor type is already discarded, so keep it going until
        # 'validate_hescore_inputs' error checking
        return loc_hierarchy[0]

    # Please review the new location mapping.
    duct_location_map = {'living space': ['cond_space'],
                         'unconditioned space': ['uncond_basement', 'vented_crawl', 'unvented_crawl', 'uncond_attic'],
                         'under slab': ['vented_crawl'],
                         'basement': ['uncond_basement', 'cond_space'],
                         'basement - unconditioned': ['uncond_basement'],
                         'basement - conditioned': ['cond_space'],
                         'crawlspace - unvented': ['unvented_crawl'],
                         'crawlspace - vented': ['vented_crawl'],
                         'crawlspace - unconditioned': ['vented_crawl', 'unvented_crawl'],
                         'crawlspace - conditioned': ['cond_space'],
                         'crawlspace': ['vented_crawl', 'unvented_crawl', 'cond_space'],
                         'exterior wall': None,
                         'interstitial space': None,
                         'garage - conditioned': ['cond_space'],
                         'garage - unconditioned': ['unvented_crawl'],
                         'garage': ['unvented_crawl'],
                         'roof deck': ['vented_crawl'],
                         'outside': ['vented_crawl'],
                         'attic': ['uncond_attic', 'cond_space'],
                         'attic - unconditioned': ['uncond_attic'],
                         'attic - conditioned': ['cond_space'],
                         'attic - unvented': ['uncond_attic'],
                         'attic - vented': ['uncond_attic']}
