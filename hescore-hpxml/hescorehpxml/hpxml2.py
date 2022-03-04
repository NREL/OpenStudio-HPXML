from .base import HPXMLtoHEScoreTranslatorBase, convert_to_type
from .exceptions import TranslationError


class HPXML2toHEScoreTranslator(HPXMLtoHEScoreTranslatorBase):
    SCHEMA_DIR = 'hpxml-2.3.0'

    def check_hpwes(self, p, v3_b):
        if p is not None:
            return self.xpath(p, 'h:ProjectDetails/h:ProgramCertificate="Home Performance with Energy Star"')

    def sort_foundations(self, fnd, v3_b):
        # Sort the foundations from largest area to smallest
        def get_fnd_area(fnd):
            return max([self.xpath(fnd, 'sum(h:%s/h:Area)' % x) for x in ('Slab', 'FrameFloor')])

        fnd.sort(key=get_fnd_area, reverse=True)
        return fnd, get_fnd_area

    def get_foundation_walls(self, fnd, v3_b):
        foundationwalls = self.xpath(fnd, 'h:FoundationWall', aslist=True)
        return foundationwalls

    def get_foundation_slabs(self, fnd, v3_b):
        slabs = self.xpath(fnd, 'h:Slab', raise_err=True, aslist=True)
        return slabs

    def get_foundation_frame_floors(self, fnd, v3_b):
        frame_floors = self.xpath(fnd, 'h:FrameFloor', aslist=True)
        return frame_floors

    def attic_has_rigid_sheathing(self, attic, v3_roof):
        return self.xpath(attic,
                          'boolean(h:AtticRoofInsulation/h:Layer[h:NominalRValue > 0][h:InstallationType="continuous"][boolean(h:InsulationMaterial/h:Rigid)])'  # noqa: E501
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

    def get_attic_roof_rvalue(self, attic, v3_roof):
        # if there is no nominal R-value, it will return 0
        return self.xpath(attic, 'sum(h:AtticRoofInsulation/h:Layer/h:NominalRValue)')

    def get_attic_roof_assembly_rvalue(self, attic, v3_roof):
        # if there is no assembly effective R-value, it will return None
        return convert_to_type(float, self.xpath(attic, 'h:AtticRoofInsulation/h:AssemblyEffectiveRValue/text()'))

    def every_attic_roof_layer_has_nominal_rvalue(self, attic, v3_roof):
        roof_layers = self.xpath(attic, 'h:AtticRoofInsulation/h:Layer', aslist=True)
        every_layer_has_nominal_rvalue = True  # Considered to have nominal R-value unless assembly R-value is used
        if roof_layers:
            for layer in roof_layers:
                if self.xpath(layer, 'h:NominalRValue') is None:
                    every_layer_has_nominal_rvalue = False
                    break
        elif self.xpath(attic, 'h:AtticRoofInsulation/h:AssemblyEffectiveRValue/text()') is not None:
            every_layer_has_nominal_rvalue = False

        return every_layer_has_nominal_rvalue

    def get_attic_knee_walls(self, attic):
        knee_walls = []
        b = self.xpath(attic, 'ancestor::h:Building')
        for kneewall_idref in self.xpath(attic, 'h:AtticKneeWall/@idref', aslist=True):
            wall = self.xpath(
                b,
                'descendant::h:Wall[h:SystemIdentifier/@id=$kneewallid]',
                raise_err=True,
                kneewallid=kneewall_idref
            )
            knee_walls.append(wall)

        return knee_walls

    def get_attic_type(self, attic, atticid):
        hpxml_attic_type = self.xpath(attic, 'h:AtticType/text()')
        rooftypemap = {'cape cod': 'cath_ceiling',
                       'cathedral ceiling': 'cath_ceiling',
                       'flat roof': 'cath_ceiling',
                       'unvented attic': 'vented_attic',
                       'vented attic': 'vented_attic',
                       'venting unknown attic': 'vented_attic',
                       'other': None}

        if rooftypemap.get(hpxml_attic_type) is None:
            raise TranslationError(
                'Attic {}: Cannot translate HPXML AtticType {} to HEScore rooftype.'.format(atticid,
                                                                                            hpxml_attic_type))
        return rooftypemap[hpxml_attic_type]

    def get_attic_floor_rvalue(self, attic, v3_b):
        return self.xpath(attic, 'sum(h:AtticFloorInsulation/h:Layer/h:NominalRValue)')

    def get_attic_floor_assembly_rvalue(self, attic, v3_b):
        return convert_to_type(float, self.xpath(attic, 'h:AtticFloorInsulation/h:AssemblyEffectiveRValue/text()'))

    def every_attic_floor_layer_has_nominal_rvalue(self, attic, v3_b):
        frame_floor_layers = self.xpath(attic, 'h:AtticFloorInsulation/h:Layer', aslist=True)
        every_layer_has_nominal_rvalue = True  # Considered to have nominal R-value unless assembly R-value is used
        if frame_floor_layers:
            for layer in frame_floor_layers:
                if self.xpath(layer, 'h:NominalRValue') is None:
                    every_layer_has_nominal_rvalue = False
                    break
        elif self.xpath(attic, 'h:AtticFloorInsulation/h:AssemblyEffectiveRValue/text()') is not None:
            every_layer_has_nominal_rvalue = False

        return every_layer_has_nominal_rvalue

    def get_ceiling_area(self, attic):
        return float(self.xpath(attic, 'h:Area/text()', raise_err=True))

    def get_attic_roof_area(self, roof):
        return float(self.xpath(roof, 'h:RoofArea/text()', raise_err=True))

    def get_framefloor_assembly_rvalue(self, framefloor, v3_framefloor):
        return convert_to_type(float, self.xpath(framefloor, 'h:Insulation/h:AssemblyEffectiveRValue/text()'))

    def get_foundation_wall_assembly_rvalue(self, fwall, v3_fwall):
        return convert_to_type(float, self.xpath(fwall, 'h:Insulation/h:AssemblyEffectiveRValue/text()'))

    def get_slab_assembly_rvalue(self, slab, v3_slab):
        return convert_to_type(float, self.xpath(slab, 'h:PerimeterInsulation/h:AssemblyEffectiveRValue/text()'))

    def every_framefloor_layer_has_nominal_rvalue(self, framefloor, v3_framefloor):
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
        return bool(self.xpath(wndw_skylight, 'h:Treatments/text()') == 'solar screen'
                    or self.xpath(wndw_skylight, 'h:ExteriorShading/text()') == 'solar screens')

    def get_hescore_walls(self, b):
        return self.xpath(
            b, 'h:BuildingDetails/h:Enclosure/h:Walls/h:Wall\
                [((h:ExteriorAdjacentTo="ambient" and not(contains(h:ExteriorAdjacentTo, "garage"))) or\
                    not(h:ExteriorAdjacentTo)) and not(contains(h:InteriorAdjacentTo, "attic"))]',  # noqa: E501
            aslist=True)

    def check_is_doublepane(self, v3_window, glass_layers):
        return glass_layers in ('double-pane', 'single-paned with storms', 'single-paned with low-e storms')

    def check_is_storm_lowe(self, window, glass_layers):
        return glass_layers == 'single-paned with low-e storms'

    def get_duct_location(self, hpxml_duct_location, v3_bldg):
        return self.duct_location_map[hpxml_duct_location]

    duct_location_map = {'conditioned space': 'cond_space',
                         'unconditioned space': None,
                         'unconditioned basement': 'uncond_basement',
                         'unvented crawlspace': 'unvented_crawl',
                         'vented crawlspace': 'vented_crawl',
                         'crawlspace': None,
                         'unconditioned attic': 'uncond_attic',
                         'interstitial space': None,
                         'garage': 'vented_crawl',
                         'outside': 'outside'}
