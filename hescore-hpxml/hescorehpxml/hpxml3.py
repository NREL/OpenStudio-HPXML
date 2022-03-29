from .base import HPXMLtoHEScoreTranslatorBase, convert_to_type
from collections import OrderedDict
from .exceptions import TranslationError


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

    def every_wall_layer_has_nominal_rvalue(self, wall):
        # This variable will be true if every wall layer has a NominalRValue *or*
        # if there are no insulation layers
        wall_layers = self.xpath(wall, 'h:Insulation/h:Layer', aslist=True)
        every_layer_has_nominal_rvalue = True  # Considered to have nominal R-value unless assembly R-value is used
        if wall_layers:
            for layer in wall_layers:
                if self.xpath(layer, 'h:NominalRValue') is None:
                    every_layer_has_nominal_rvalue = False
                    break
        elif self.xpath(wall, 'h:Insulation/h:AssemblyEffectiveRValue/text()') is not None:
            every_layer_has_nominal_rvalue = False

        return every_layer_has_nominal_rvalue

    def get_attic_roof_rvalue(self, v2_attic, roof):
        # if there is no nominal R-value, it will return 0
        return self.xpath(roof, 'sum(h:Insulation/h:Layer/h:NominalRValue)')

    def get_attic_roof_assembly_rvalue(self, v2_attic, roof):
        # if there is no assembly effective R-value, it will return None
        return convert_to_type(float, self.xpath(roof, 'h:Insulation/h:AssemblyEffectiveRValue/text()'))

    def every_attic_roof_layer_has_nominal_rvalue(self, v2_attic, roof):
        roof_layers = self.xpath(roof, 'h:Insulation/h:Layer', aslist=True)
        every_layer_has_nominal_rvalue = True  # Considered to have nominal R-value unless assembly R-value is used
        if roof_layers:
            for layer in roof_layers:
                if self.xpath(layer, 'h:NominalRValue') is None:
                    every_layer_has_nominal_rvalue = False
                    break
        elif self.xpath(roof, 'h:Insulation/h:AssemblyEffectiveRValue/text()') is not None:
            every_layer_has_nominal_rvalue = False

        return every_layer_has_nominal_rvalue

    def get_attic_knee_walls(self, attic):
        knee_walls = []
        b = self.xpath(attic, 'ancestor::h:Building')
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
                      'h:AtticType/h:Attic/h:CapeCod or boolean(h:AtticType/h:FlatRoof) or '
                      'boolean(h:AtticType/h:CathedralCeiling) or boolean(h:AtticType/h:Attic/h:Conditioned)'):
            return 'cath_ceiling'
        elif self.xpath(attic, 'boolean(h:AtticType/h:Attic)'):
            return 'vented_attic'
        else:
            raise TranslationError(
                'Attic {}: Cannot translate HPXML AtticType to HEScore rooftype.'.format(atticid))

    def get_attic_floor_rvalue(self, attic, b):
        frame_floors = self.get_attic_floors(attic)
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

    def get_attic_floor_assembly_rvalue(self, attic, b):
        frame_floors = self.get_attic_floors(attic)
        if len(frame_floors) == 0:
            return None

        frame_floor_dict_ls = []
        for frame_floor in frame_floors:
            floor_area = convert_to_type(float, self.xpath(frame_floor, 'h:Area/text()'))
            assembly_rvalue = convert_to_type(
                float, self.xpath(frame_floor, 'h:Insulation/h:AssemblyEffectiveRValue/text()'))
            if assembly_rvalue is None:
                return
            frame_floor_dict_ls.append({'area': floor_area, 'rvalue': assembly_rvalue})
        # Average
        try:
            floor_r = sum(x['area'] for x in frame_floor_dict_ls) / \
                      sum(x['area'] / x['rvalue'] for x in frame_floor_dict_ls)
        except ZeroDivisionError:
            floor_r = None

        return convert_to_type(float, floor_r)

    def every_attic_floor_layer_has_nominal_rvalue(self, attic, b):
        frame_floors = self.get_attic_floors(attic)
        every_layer_has_nominal_rvalue = True  # Considered to have nominal R-value unless assembly R-value is used
        for frame_floor in frame_floors:
            for layer in self.xpath(frame_floor, 'h:Insulation/h:Layer', aslist=True):
                if self.xpath(layer, 'h:NominalRValue') is None:
                    every_layer_has_nominal_rvalue = False
                    break
            if self.xpath(frame_floor, 'h:Insulation/h:AssemblyEffectiveRValue/text()') is not None:
                every_layer_has_nominal_rvalue = False
                break

        return every_layer_has_nominal_rvalue

    def get_attic_floors(self, attic):
        floor_idref = self.xpath(attic, 'h:AttachedToFrameFloor/@idref', aslist=True)
        # No frame floor attached
        if not floor_idref:
            return []
        b = self.xpath(attic, 'ancestor::h:Building')
        frame_floors = self.xpath(b, '//h:FrameFloor[contains("{}",h:SystemIdentifier/@id)]'.format(floor_idref),
                                  aslist=True, raise_err=True)

        return frame_floors

    def get_ceiling_area(self, attic):
        frame_floors = self.get_attic_floors(attic)
        if len(frame_floors) >= 1:
            return sum(float(self.xpath(x, 'h:Area/text()', raise_err=True)) for x in frame_floors)
        else:
            raise TranslationError('For vented attics, a FrameFloor needs to be referenced to determine ceiling_area.')

    def get_attic_roof_area(self, roof):
        return float(self.xpath(roof, 'h:Area/text()', raise_err=True))

    def get_framefloor_assembly_rvalue(self, v2_framefloor, framefloor):
        return convert_to_type(float, self.xpath(framefloor, 'h:Insulation/h:AssemblyEffectiveRValue/text()'))

    def get_foundation_wall_assembly_rvalue(self, v2_fwall, fwall):
        return convert_to_type(float, self.xpath(fwall, 'h:Insulation/h:AssemblyEffectiveRValue/text()'))

    def get_slab_assembly_rvalue(self, v2_slab, slab):
        return convert_to_type(float, self.xpath(slab, 'h:PerimeterInsulation/h:AssemblyEffectiveRValue/text()'))

    def every_framefloor_layer_has_nominal_rvalue(self, v2_framefloor, framefloor):
        framefloor_layers = self.xpath(framefloor, 'h:Insulation/h:Layer', aslist=True)
        every_layer_has_nominal_rvalue = True  # Considered to have nominal R-value unless assembly R-value is used
        if framefloor_layers:
            for layer in framefloor_layers:
                if self.xpath(layer, 'h:NominalRValue') is None:
                    every_layer_has_nominal_rvalue = False
                    break
        elif self.xpath(framefloor, 'h:Insulation/h:AssemblyEffectiveRValue/text()') is not None:
            every_layer_has_nominal_rvalue = False

        return every_layer_has_nominal_rvalue

    def get_solarscreen(self, wndw_skylight):
        return bool(self.xpath(wndw_skylight, 'h:ExteriorShading/h:Type/text()') == 'solar screens')

    def get_hescore_walls(self, b):
        return self.xpath(
            b, 'h:BuildingDetails/h:Enclosure/h:Walls/h:Wall\
                [((h:ExteriorAdjacentTo="outside" and not(contains(h:ExteriorAdjacentTo, "garage"))) or\
                    not(h:ExteriorAdjacentTo)) and not(contains(h:InteriorAdjacentTo, "attic"))]',  # noqa: E501
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
        try:
            loc_hierarchy = self.duct_location_map[hpxml_duct_location]
            if loc_hierarchy is None:
                return
        except TypeError:
            raise TranslationError('Invalid duct location specified')
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

    duct_location_map = {'living space': ['cond_space'],
                         'unconditioned space': ['uncond_basement', 'vented_crawl', 'unvented_crawl', 'uncond_attic'],
                         'under slab': ['under_slab'],
                         'basement': ['uncond_basement', 'cond_space'],
                         'basement - unconditioned': ['uncond_basement'],
                         'basement - conditioned': ['cond_space'],
                         'crawlspace - unvented': ['unvented_crawl'],
                         'crawlspace - vented': ['vented_crawl'],
                         'crawlspace - unconditioned': ['vented_crawl', 'unvented_crawl'],
                         'crawlspace - conditioned': ['cond_space'],
                         'crawlspace': ['vented_crawl', 'unvented_crawl', 'cond_space'],
                         'exterior wall': ['exterior_wall'],
                         'interstitial space': None,
                         'garage - conditioned': ['cond_space'],
                         'garage - unconditioned': ['unvented_crawl'],
                         'garage': ['unvented_crawl'],
                         'roof deck': ['outside'],
                         'outside': ['outside'],
                         'attic': ['uncond_attic', 'cond_space'],
                         'attic - unconditioned': ['uncond_attic'],
                         'attic - conditioned': ['cond_space'],
                         'attic - unvented': ['uncond_attic'],
                         'attic - vented': ['uncond_attic']}
