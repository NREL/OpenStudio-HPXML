import os
import jsonschema
import json
import pathlib
import copy
import glob
import pytest

hescore_examples = [
    'townhouse_walls',
    'house1'
]


def get_example_json(filebase):
    rootdir = pathlib.Path(__file__).resolve().parent.parent
    jsonfilepath = str(rootdir / 'examples' / f'{filebase}.json')
    with open(jsonfilepath) as f:
        js = json.load(f)
    return js


def get_json_schema():
    this_path = os.path.dirname(os.path.abspath(__file__))
    schema_path = os.path.join(os.path.dirname(this_path), 'hescorehpxml', 'schemas', 'hescore_json.schema.json')
    with open(schema_path, 'r') as js:
        schema = json.loads(js.read())
    return schema


def get_error_messages(jsonfile, jsonschema):
    errors = []
    for error in sorted(jsonschema.iter_errors(jsonfile), key=str):
        try:
            errors.append(error.schema["error_msg"])
        except KeyError:
            errors.append(error.message)
    return errors


def test_schema_version_validation():
    schema = get_json_schema()
    error = jsonschema.Draft7Validator.check_schema(schema)
    assert error is None


def test_example_files():
    rootdir = pathlib.Path(__file__).resolve().parent.parent
    examplefiles = str(rootdir / 'examples' / '*.json')
    for examplefile in glob.glob(examplefiles):
        hpxml_filebase = os.path.basename(examplefile).split('.')[0]
        schema = get_json_schema()
        js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
        js = get_example_json(hpxml_filebase)
        errors = get_error_messages(js, js_schema)
        assert len(errors) == 0


@pytest.mark.parametrize('hpxml_filebase', hescore_examples)
def test_invalid_building_about(hpxml_filebase):
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)

    js1 = copy.deepcopy(js)
    js1_about = copy.deepcopy(js['building']['about'])
    del js1['building']['about']
    js1['building']['about'] = []
    js1['building']['about'].append(js1_about)
    js1['building']['about'].append(js1_about)
    errors = get_error_messages(js1, js_schema)
    if hpxml_filebase == 'townhouse_walls':
        assert any(error.startswith("[{'assessment_date': '2014-12-02', 'shape': 'town_house'") and
                   error.endswith("is not of type 'object'") for error in errors)
    elif hpxml_filebase == 'house1':
        assert any(error.startswith("[{'assessment_date': '2014-10-23', 'shape': 'rectangle'") and
                   error.endswith("is not of type 'object'") for error in errors)

    js2 = copy.deepcopy(js)
    if hpxml_filebase == 'townhouse_walls':
        del js2['building']['about']['envelope_leakage']
        errors = get_error_messages(js2, js_schema)
        assert "'envelope_leakage' is a required property" in errors
        assert "'air_sealing_present' is a required property" not in errors
        js2['building']['about']['blower_door_test'] = False
        errors = get_error_messages(js2, js_schema)
        assert "'air_sealing_present' is a required property" in errors
    elif hpxml_filebase == 'house1':
        del js2['building']['about']['air_sealing_present']
        errors = get_error_messages(js2, js_schema)
        assert "'envelope_leakage' is a required property" not in errors
        assert "'air_sealing_present' is a required property" in errors
    del js2['building']['about']['assessment_date']
    del js2['building']['about']['shape']
    del js2['building']['about']['year_built']
    del js2['building']['about']['number_bedrooms']
    del js2['building']['about']['num_floor_above_grade']
    del js2['building']['about']['floor_to_ceiling_height']
    del js2['building']['about']['conditioned_floor_area']
    del js2['building']['about']['orientation']
    del js2['building']['about']['blower_door_test']
    errors = get_error_messages(js2, js_schema)
    assert "'assessment_date' is a required property" in errors
    assert "'shape' is a required property" in errors
    assert "'year_built' is a required property" in errors
    assert "'number_bedrooms' is a required property" in errors
    assert "'num_floor_above_grade' is a required property" in errors
    assert "'floor_to_ceiling_height' is a required property" in errors
    assert "'conditioned_floor_area' is a required property" in errors
    assert "'orientation' is a required property" in errors
    assert "'blower_door_test' is a required property" in errors
    if hpxml_filebase == 'townhouse_walls':
        del js2['building']['about']['town_house_walls']
        errors = get_error_messages(js2, js_schema)
        assert "'town_house_walls' is a required property" in errors

    js3 = copy.deepcopy(js)
    js3['building']['about']['assessment_date'] = '2021'
    errors = get_error_messages(js3, js_schema)
    assert "'2021' is not a 'date'" in errors
    if hpxml_filebase == 'townhouse_walls':
        js3['building']['about']['shape'] = 'rectangle'
        errors = get_error_messages(js3, js_schema)
        assert ("{'required': ['town_house_walls']} is not allowed for {'assessment_date': '2021', "
                "'shape': 'rectangle', 'town_house_walls': 'back_front_left', 'year_built': 1961, "
                "'number_bedrooms': 4, 'num_floor_above_grade': 2, 'floor_to_ceiling_height': 7, "
                "'conditioned_floor_area': 2400, 'orientation': 'north', 'blower_door_test': True, "
                "'envelope_leakage': 1204}") in errors
        js3['building']['about']['air_sealing_present'] = True
        errors = get_error_messages(js3, js_schema)
        assert ("{'required': ['air_sealing_present']} is not allowed for {'assessment_date': '2021', "
                "'shape': 'rectangle', 'town_house_walls': 'back_front_left', 'year_built': 1961, "
                "'number_bedrooms': 4, 'num_floor_above_grade': 2, 'floor_to_ceiling_height': 7, "
                "'conditioned_floor_area': 2400, 'orientation': 'north', 'blower_door_test': True, "
                "'envelope_leakage': 1204, 'air_sealing_present': True}") in errors
    elif hpxml_filebase == 'house1':
        js3['building']['about']['envelope_leakage'] = 1204
        errors = get_error_messages(js3, js_schema)
        assert ("{'required': ['envelope_leakage']} is not allowed for {'assessment_date': '2021', "
                "'shape': 'rectangle', 'year_built': 1953, 'number_bedrooms': 3, 'num_floor_above_grade': 2, "
                "'floor_to_ceiling_height': 11, 'conditioned_floor_area': 1620, 'orientation': 'east', "
                "'blower_door_test': False, 'air_sealing_present': False, 'envelope_leakage': 1204}") in errors


@pytest.mark.parametrize('hpxml_filebase', hescore_examples)
def test_invalid_building_zone(hpxml_filebase):
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)
    zone = copy.deepcopy(js['building']['zone'])
    del js['building']['zone']
    js['building']['zone'] = []
    js['building']['zone'].append(zone)
    js['building']['zone'].append(zone)
    errors = get_error_messages(js, js_schema)
    if hpxml_filebase == 'townhouse_walls':
        assert any(error.startswith("[{'zone_roof': [{'roof_name': 'roof1', 'roof_area': 1200.0") and
                   error.endswith("is not of type 'object'") for error in errors)
    elif hpxml_filebase == 'house1':
        assert any(error.startswith("[{'zone_roof': [{'roof_name': 'roof1', 'roof_area': 810") and
                   error.endswith("is not of type 'object'") for error in errors)


@pytest.mark.parametrize('hpxml_filebase', hescore_examples)
def test_invalid_roof(hpxml_filebase):
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)

    js1 = copy.deepcopy(js)
    del js1['building']['zone']['zone_roof'][0]['roof_assembly_code']
    del js1['building']['zone']['zone_roof'][0]['roof_color']
    del js1['building']['zone']['zone_roof'][0]['roof_type']
    del js1['building']['zone']['zone_roof'][0]['ceiling_assembly_code']
    errors = get_error_messages(js1, js_schema)
    assert "'roof_assembly_code' is a required property" in errors
    assert "'roof_color' is a required property" in errors
    assert "'roof_type' is a required property" in errors
    assert "'ceiling_assembly_code' is a required property" not in errors
    assert "'roof_absorptance' is a required property" not in errors

    js2 = copy.deepcopy(js)
    js2['building']['zone']['zone_roof'][0]['roof_type'] = 'cath_ceiling'
    js2['building']['zone']['zone_roof'][0]['roof_absorptance'] = 0.6
    errors = get_error_messages(js2, js_schema)
    if hpxml_filebase == 'townhouse_walls':
        assert ("{'required': ['ceiling_assembly_code']} is not allowed for {'roof_name': 'roof1', "
                "'roof_area': 1200.0, 'roof_assembly_code': 'rfwf00co', 'roof_color': 'medium', "
                "'roof_type': 'cath_ceiling', 'ceiling_assembly_code': 'ecwf49', "
                "'zone_skylight': {'skylight_area': 11.0, 'skylight_method': 'code', 'skylight_code': 'dcab', "
                "'solar_screen': False}, 'roof_absorptance': 0.6}") in errors
        assert ("{'required': ['roof_absorptance']} is not allowed for {'roof_name': 'roof1', "
                "'roof_area': 1200.0, 'roof_assembly_code': 'rfwf00co', 'roof_color': 'medium', "
                "'roof_type': 'cath_ceiling', 'ceiling_assembly_code': 'ecwf49', "
                "'zone_skylight': {'skylight_area': 11.0, 'skylight_method': 'code', 'skylight_code': 'dcab', "
                "'solar_screen': False}, 'roof_absorptance': 0.6}") in errors
    elif hpxml_filebase == 'house1':
        assert ("{'required': ['ceiling_assembly_code']} is not allowed for {'roof_name': 'roof1', 'roof_area': 810, "
                "'roof_assembly_code': 'rfrb00co', 'roof_color': 'dark', 'roof_type': 'cath_ceiling', "
                "'ceiling_assembly_code': 'ecwf11', 'zone_skylight': {'skylight_area': 0}, "
                "'roof_absorptance': 0.6}") in errors
        assert ("{'required': ['roof_absorptance']} is not allowed for {'roof_name': 'roof1', 'roof_area': 810, "
                "'roof_assembly_code': 'rfrb00co', 'roof_color': 'dark', 'roof_type': 'cath_ceiling', "
                "'ceiling_assembly_code': 'ecwf11', 'zone_skylight': {'skylight_area': 0}, "
                "'roof_absorptance': 0.6}") in errors


def test_invalid_skylight():
    hpxml_filebase = 'townhouse_walls'
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)

    js1 = copy.deepcopy(js)
    js1['building']['zone']['zone_roof'][0]['zone_skylight']['skylight_method'] = 'custom'
    errors = get_error_messages(js1, js_schema)
    assert "'skylight_u_value' is a required property" in errors
    assert "'skylight_shgc' is a required property" in errors
    assert ("{'required': ['skylight_code']} is not allowed for {'skylight_area': 11.0, 'skylight_method': 'custom', "
            "'skylight_code': 'dcab', 'solar_screen': False}") in errors
    del js1['building']['zone']['zone_roof'][0]['zone_skylight']['skylight_method']
    del js1['building']['zone']['zone_roof'][0]['zone_skylight']['skylight_code']
    errors = get_error_messages(js1, js_schema)
    assert "'skylight_method' is a required property" in errors
    assert "'skylight_code' is a required property" not in errors
    assert "'skylight_u_value' is a required property" not in errors
    assert "'skylight_shgc' is a required property" not in errors

    js2 = copy.deepcopy(js)
    js2['building']['zone']['zone_roof'][0]['zone_skylight']['skylight_area'] = 0
    del js2['building']['zone']['zone_roof'][0]['zone_skylight']['skylight_method']
    errors = get_error_messages(js2, js_schema)
    assert "'skylight_method' is a required property" not in errors

    js3 = copy.deepcopy(js)
    js3['building']['zone']['zone_roof'][0]['zone_skylight']['skylight_u_value'] = 0.5
    errors = get_error_messages(js3, js_schema)
    assert ("{'required': ['skylight_u_value']} is not allowed for {'skylight_area': 11.0, 'skylight_method': 'code', "
            "'skylight_code': 'dcab', 'solar_screen': False, 'skylight_u_value': 0.5}") in errors


@pytest.mark.parametrize('hpxml_filebase', hescore_examples)
def test_invalid_floor(hpxml_filebase):
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)

    js1 = copy.deepcopy(js)
    del js1['building']['zone']['zone_floor'][0]['foundation_type']
    del js1['building']['zone']['zone_floor'][0]['foundation_insulation_level']
    errors = get_error_messages(js1, js_schema)
    assert "'foundation_type' is a required property" in errors
    assert "'foundation_insulation_level' is a required property" in errors
    del js1['building']['zone']['zone_floor'][0]['floor_area']
    del js1['building']['zone']['zone_floor'][0]['floor_assembly_code']
    errors = get_error_messages(js1, js_schema)
    assert "'floor_area' is a required property" in errors
    assert "'foundation_type' is a required property" not in errors
    assert "'foundation_insulation_level' is a required property" not in errors
    assert "'floor_assembly_code' is a required property" not in errors

    js2 = copy.deepcopy(js)
    js2['building']['zone']['zone_floor'][0]['foundation_type'] = 'slab_on_grade'
    errors = get_error_messages(js2, js_schema)
    if hpxml_filebase == 'townhouse_walls':
        assert ("{'required': ['floor_assembly_code']} is not allowed for {'floor_name': 'floor1', 'floor_area': 800, "
                "'foundation_type': 'slab_on_grade', 'foundation_insulation_level': 0, "
                "'floor_assembly_code': 'efwf00ca'}") in errors
    elif hpxml_filebase == 'house1':
        assert ("{'required': ['floor_assembly_code']} is not allowed for {'floor_name': 'floor1', "
                "'floor_area': 810.0, 'foundation_type': 'slab_on_grade', 'foundation_insulation_level': 0, "
                "'floor_assembly_code': 'efwf00ca'}") in errors


@pytest.mark.parametrize('hpxml_filebase', hescore_examples)
def test_invalid_wall_window_construction_same(hpxml_filebase):
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)
    del js['building']['zone']['wall_construction_same']
    del js['building']['zone']['window_construction_same']
    errors = get_error_messages(js, js_schema)
    assert "'wall_construction_same' is a required property" in errors
    assert "'window_construction_same' is a required property" in errors


@pytest.mark.parametrize('hpxml_filebase', hescore_examples)
def test_invalid_wall(hpxml_filebase):
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)

    js1 = copy.deepcopy(js)
    del js1['building']['zone']['zone_wall'][0]['side']
    del js1['building']['zone']['zone_wall'][1]['wall_assembly_code']
    errors = get_error_messages(js1, js_schema)
    assert 'zone_wall/side["front"] requires "side" and "wall_assembly_code"' in errors
    assert 'zone_wall/side["left"] requires "side" and "wall_assembly_code"' in errors

    js2 = copy.deepcopy(js)
    js2['building']['zone']['wall_construction_same'] = True
    del js2['building']['zone']['zone_wall'][1]['wall_assembly_code']
    errors = get_error_messages(js2, js_schema)
    if hpxml_filebase == 'townhouse_walls':
        assert '\"wall_assembly_code\" is not allowed for zone_wall/side[\"back\"]' in errors
    elif hpxml_filebase == 'house1':
        assert '\"wall_assembly_code\" is not allowed for zone_wall/side[\"back\"]' in errors
        assert '\"wall_assembly_code\" is not allowed for zone_wall/side[\"right\"]' in errors

    if hpxml_filebase == 'townhouse_walls':
        js3 = copy.deepcopy(js)
        js3['building']['zone']['zone_wall'].append({'side': 'right'})
        errors = get_error_messages(js3, js_schema)
        assert 'zone_wall/side[\"right\"] not allowed' in errors


@pytest.mark.parametrize('hpxml_filebase', hescore_examples)
def test_invalid_window(hpxml_filebase):
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)

    js1 = copy.deepcopy(js)
    if hpxml_filebase == 'townhouse_walls':
        del js1['building']['zone']['zone_wall'][0]['zone_window']['window_u_value']
    del js1['building']['zone']['zone_wall'][0]['zone_window']['window_area']
    del js1['building']['zone']['zone_wall'][2]['zone_window']['window_code']
    errors = get_error_messages(js1, js_schema)
    if hpxml_filebase == 'townhouse_walls':
        assert 'zone_wall/side["front"]/zone_window requires "window_area" and "window_method"' in errors
        assert 'zone_wall/side["back"]/zone_window requires "window_code"' in errors
        assert 'zone_wall/side["front"]/zone_window requires "window_u_value" and "window_shgc"' in errors
    elif hpxml_filebase == 'house1':
        assert 'zone_wall/side["front"]/zone_window requires "window_area" and "window_method"' in errors
        assert 'zone_wall/side["back"]/zone_window requires "window_code"' in errors
    del js1['building']['zone']['zone_wall'][2]['zone_window']['window_method']
    errors = get_error_messages(js1, js_schema)
    assert 'zone_wall/side["back"]/zone_window requires "window_area" and "window_method"' in errors
    js1['building']['zone']['zone_wall'][0]['zone_window']['window_shgc'] = 1
    errors = get_error_messages(js1, js_schema)
    assert '1 is greater than or equal to the maximum of 1' in errors

    js2 = copy.deepcopy(js)
    js2['building']['zone']['zone_wall'][0]['zone_window']['window_u_value'] = 0.5
    errors = get_error_messages(js2, js_schema)
    if hpxml_filebase == 'townhouse_walls':
        assert len(errors) == 0
    elif hpxml_filebase == 'house1':
        assert '"window_u_value" and "window_shgc" are not allowed for zone_wall/side["front"]/zone_window' in errors

    js3 = copy.deepcopy(js)
    js3['building']['zone']['zone_wall'][0]['zone_window']['window_code'] = 'dcaa'
    errors = get_error_messages(js3, js_schema)
    if hpxml_filebase == 'townhouse_walls':
        assert '"window_code" is not allowed for zone_wall/side["front"]/zone_window' in errors
    elif hpxml_filebase == 'house1':
        assert len(errors) == 0


@pytest.mark.parametrize('hpxml_filebase', hescore_examples)
def test_invalid_heating(hpxml_filebase):
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)

    js1 = copy.deepcopy(js)
    del js1['building']['systems']['hvac'][0]['hvac_name']
    errors = get_error_messages(js1, js_schema)
    assert "'hvac_name' is a required property" in errors

    js2 = copy.deepcopy(js)
    js2['building']['systems']['hvac'][0]['heating']['type'] = 'none'
    del js2['building']['systems']['hvac'][0]['heating']['fuel_primary']
    del js2['building']['systems']['hvac'][0]['heating']['efficiency_method']
    errors = get_error_messages(js2, js_schema)
    assert len(errors) == 0
    del js2['building']['systems']['hvac'][0]['heating']['type']
    errors = get_error_messages(js2, js_schema)
    assert "'type' is a required property" in errors

    js3 = copy.deepcopy(js)
    # natural gas central furnace
    del js3['building']['systems']['hvac'][0]['heating']['efficiency']
    errors = get_error_messages(js3, js_schema)
    assert "'efficiency' is a required property" in errors
    del js3['building']['systems']['hvac'][0]['heating']['efficiency_method']
    errors = get_error_messages(js3, js_schema)
    assert "'efficiency_method' is a required property" in errors
    js3['building']['systems']['hvac'][0]['heating']['efficiency_method'] = 'shipment_weighted'
    errors = get_error_messages(js3, js_schema)
    assert "'year' is a required property" in errors
    js3['building']['systems']['hvac'][0]['heating']['efficiency'] = 0.5
    errors = get_error_messages(js3, js_schema)
    assert "0.5 is less than the minimum of 0.6" in errors
    assert ("{'required': ['efficiency']} is not allowed for {'fuel_primary': 'natural_gas', 'type': 'central_furnace',"
            " 'efficiency_method': 'shipment_weighted', 'efficiency': 0.5}") in errors
    del js3['building']['systems']['hvac'][0]['heating']['fuel_primary']
    errors = get_error_messages(js3, js_schema)
    assert "'fuel_primary' is a required property" in errors
    # electric central furnace
    js3['building']['systems']['hvac'][0]['heating']['fuel_primary'] = 'electric'
    errors = get_error_messages(js3, js_schema)
    assert len(errors) == 0
    # electric wall furnace
    js3['building']['systems']['hvac'][0]['heating']['type'] = 'wall_furnace'
    del js3['building']['systems']['hvac'][0]['heating']['efficiency']
    errors = get_error_messages(js3, js_schema)
    assert len(errors) == 0
    # electric boiler
    js3['building']['systems']['hvac'][0]['heating']['type'] = 'boiler'
    errors = get_error_messages(js3, js_schema)
    assert len(errors) == 0
    # heat pump
    js3['building']['systems']['hvac'][0]['heating']['type'] = 'heat_pump'
    js3['building']['systems']['hvac'][0]['heating']['efficiency'] = 1.1
    errors = get_error_messages(js3, js_schema)
    assert "1.1 is less than the minimum of 6" in errors
    del js3['building']['systems']['hvac'][0]['heating']['efficiency']
    js3['building']['systems']['hvac'][0]['heating']['efficiency_level'] = 'cee_tier'
    errors = get_error_messages(js3, js_schema)
    assert "'cee_tier' is not one of ['energy_star', 'cee_tier1', 'cee_tier2', 'cee_tier3']" in errors
    del js3['building']['systems']['hvac'][0]['heating']['efficiency_level']
    # mini-split
    js3['building']['systems']['hvac'][0]['heating']['type'] = 'mini_split'
    js3['building']['systems']['hvac'][0]['heating']['efficiency_level'] = 'cee_tier2'
    errors = get_error_messages(js3, js_schema)
    assert "'cee_tier2' is not one of ['energy_star', 'cee_tier1']" in errors
    js3['building']['systems']['hvac'][0]['heating']['efficiency_level'] = 'cee_tier3'
    errors = get_error_messages(js3, js_schema)
    assert "'cee_tier3' is not one of ['energy_star', 'cee_tier1']" in errors
    del js3['building']['systems']['hvac'][0]['heating']['efficiency_level']
    js3['building']['systems']['hvac'][0]['heating']['efficiency'] = 20.1
    errors = get_error_messages(js3, js_schema)
    assert "20.1 is greater than the maximum of 20" in errors
    # gchp
    js3['building']['systems']['hvac'][0]['heating']['type'] = 'gchp'
    errors = get_error_messages(js3, js_schema)
    assert "20.1 is greater than the maximum of 5" in errors
    # electric baseboard
    js3['building']['systems']['hvac'][0]['heating']['type'] = 'baseboard'
    errors = get_error_messages(js3, js_schema)
    assert len(errors) == 0
    # electric wood stove
    js3['building']['systems']['hvac'][0]['heating']['type'] = 'wood_stove'
    errors = get_error_messages(js3, js_schema)
    assert len(errors) == 0
    # natural gas wood stove
    js3['building']['systems']['hvac'][0]['heating']['fuel_primary'] = 'natural_gas'
    errors = get_error_messages(js3, js_schema)
    assert len(errors) == 0

    js4 = copy.deepcopy(js)
    del js4['building']['systems']['hvac'][0]['hvac_fraction']
    errors = get_error_messages(js4, js_schema)
    assert "'hvac_fraction' is a required property" in errors

    js5 = copy.deepcopy(js)
    js5['building']['systems']['hvac'][0]['heating']['year'] = 2021
    errors = get_error_messages(js5, js_schema)
    if hpxml_filebase == 'townhouse_walls':
        assert ("{'required': ['year']} is not allowed for {'fuel_primary': 'natural_gas', 'type': 'central_furnace', "
                "'efficiency_method': 'user', 'efficiency': 0.95, 'year': 2021}") in errors
    elif hpxml_filebase == 'house1':
        assert ("{'required': ['year']} is not allowed for {'fuel_primary': 'natural_gas', 'type': 'central_furnace', "
                "'efficiency_method': 'user', 'efficiency': 0.92, 'year': 2021}") in errors


@pytest.mark.parametrize('hpxml_filebase', hescore_examples)
def test_invalid_cooling(hpxml_filebase):
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)

    js1 = copy.deepcopy(js)
    del js1['building']['systems']['hvac'][0]['hvac_name']
    js1['building']['systems']['hvac'][0]['cooling']['year'] = 2021
    errors = get_error_messages(js1, js_schema)
    assert "'hvac_name' is a required property" in errors
    assert ("{'required': ['year']} is not allowed for {'type': 'split_dx', 'efficiency_method': 'user', "
            "'efficiency': 13.0, 'year': 2021}") in errors

    js2 = copy.deepcopy(js)
    js2['building']['systems']['hvac'][0]['cooling']['type'] = 'none'
    del js2['building']['systems']['hvac'][0]['cooling']['efficiency_method']
    errors = get_error_messages(js2, js_schema)
    assert len(errors) == 0
    del js2['building']['systems']['hvac'][0]['cooling']['type']
    errors = get_error_messages(js2, js_schema)
    assert "'type' is a required property" in errors

    js3 = copy.deepcopy(js)
    # split dx
    del js3['building']['systems']['hvac'][0]['cooling']['efficiency']
    errors = get_error_messages(js3, js_schema)
    assert "'efficiency' is a required property" in errors
    del js3['building']['systems']['hvac'][0]['cooling']['efficiency_method']
    errors = get_error_messages(js3, js_schema)
    assert "'efficiency_method' is a required property" in errors
    js3['building']['systems']['hvac'][0]['cooling']['efficiency_level'] = 'cee_tier3'
    errors = get_error_messages(js3, js_schema)
    assert "'cee_tier3' is not one of ['energy_star', 'cee_tier1', 'cee_tier2']" in errors
    del js3['building']['systems']['hvac'][0]['cooling']['efficiency_level']
    js3['building']['systems']['hvac'][0]['cooling']['efficiency_method'] = 'shipment_weighted'
    errors = get_error_messages(js3, js_schema)
    assert "'year' is a required property" in errors
    js3['building']['systems']['hvac'][0]['cooling']['efficiency'] = 7.9
    errors = get_error_messages(js3, js_schema)
    assert "7.9 is less than the minimum of 8" in errors
    assert ("{'required': ['efficiency']} is not allowed for {'type': 'split_dx', "
            "'efficiency_method': 'shipment_weighted', 'efficiency': 7.9}") in errors
    # heat pump
    js3['building']['systems']['hvac'][0]['cooling']['type'] = 'heat_pump'
    errors = get_error_messages(js3, js_schema)
    assert "7.9 is less than the minimum of 8" in errors
    del js3['building']['systems']['hvac'][0]['cooling']['efficiency']
    js3['building']['systems']['hvac'][0]['cooling']['efficiency_level'] = 'cee_tier'
    errors = get_error_messages(js3, js_schema)
    assert "'cee_tier' is not one of ['energy_star', 'cee_tier1', 'cee_tier2', 'cee_tier3']" in errors
    del js3['building']['systems']['hvac'][0]['cooling']['efficiency_level']
    # packaged dx
    js3['building']['systems']['hvac'][0]['cooling']['type'] = 'packaged_dx'
    js3['building']['systems']['hvac'][0]['cooling']['efficiency'] = 40.1
    errors = get_error_messages(js3, js_schema)
    assert "40.1 is greater than the maximum of 40" in errors
    # mini-split
    js3['building']['systems']['hvac'][0]['cooling']['type'] = 'mini_split'
    errors = get_error_messages(js3, js_schema)
    assert "40.1 is greater than the maximum of 40" in errors
    del js3['building']['systems']['hvac'][0]['cooling']['efficiency']
    js3['building']['systems']['hvac'][0]['cooling']['efficiency_level'] = 'cee_tier2'
    errors = get_error_messages(js3, js_schema)
    assert "'cee_tier2' is not one of ['energy_star', 'cee_tier1']" in errors
    js3['building']['systems']['hvac'][0]['cooling']['efficiency_level'] = 'cee_tier3'
    errors = get_error_messages(js3, js_schema)
    assert "'cee_tier3' is not one of ['energy_star', 'cee_tier1']" in errors
    del js3['building']['systems']['hvac'][0]['cooling']['efficiency_level']
    # gchp
    js3['building']['systems']['hvac'][0]['cooling']['efficiency'] = 40.1
    js3['building']['systems']['hvac'][0]['cooling']['type'] = 'gchp'
    errors = get_error_messages(js3, js_schema)
    assert "40.1 is greater than the maximum of 40" in errors
    # dec
    js3['building']['systems']['hvac'][0]['cooling']['type'] = 'dec'
    errors = get_error_messages(js3, js_schema)
    assert len(errors) == 0


@pytest.mark.parametrize('hpxml_filebase', hescore_examples)
def test_invalid_hvac_distribution(hpxml_filebase):
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)

    js1 = copy.deepcopy(js)
    js1['building']['systems']['hvac'][0]['heating']['type'] = 'wall_furnace'
    js1['building']['systems']['hvac'][0]['cooling']['type'] = 'packaged_dx'
    del js1['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['location']
    del js1['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['insulated']
    errors = get_error_messages(js1, js_schema)
    if hpxml_filebase == 'townhouse_walls':
        assert ("{'required': ['hvac_distribution']} is not allowed for {'hvac_name': 'hvac1', 'hvac_fraction': 1.0, "
                "'heating': {'fuel_primary': 'natural_gas', 'type': 'wall_furnace', 'efficiency_method': 'user', "
                "'efficiency': 0.95}, 'cooling': {'type': 'packaged_dx', 'efficiency_method': 'user', "
                "'efficiency': 13.0}, 'hvac_distribution': {'leakage_method': 'qualitative', 'sealed': False, "
                "'duct': [{'name': 'duct1', 'fraction': 1.0}]}}") in errors
    elif hpxml_filebase == 'house1':
        assert ("{'required': ['hvac_distribution']} is not allowed for {'hvac_name': 'hvac1', 'hvac_fraction': 1.0, "
                "'heating': {'fuel_primary': 'natural_gas', 'type': 'wall_furnace', 'efficiency_method': 'user', "
                "'efficiency': 0.92}, 'cooling': {'type': 'packaged_dx', 'efficiency_method': 'user', "
                "'efficiency': 13.0}, 'hvac_distribution': {'leakage_method': 'qualitative', 'sealed': False, "
                "'duct': [{'name': 'duct1', 'fraction': 0.5}, {'name': 'duct2', 'location': 'uncond_attic', "
                "'fraction': 0.35, 'insulated': True}, {'name': 'duct3', 'location': 'cond_space', 'fraction': 0.15, "
                "'insulated': False}]}}") in errors

    js2 = copy.deepcopy(js)
    del js2['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['name']
    del js2['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['location']
    del js2['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['insulated']
    errors = get_error_messages(js2, js_schema)
    assert "'name' is a required property" in errors
    assert "'location' is a required property" in errors
    assert "'insulated' is a required property" in errors
    del js2['building']['systems']['hvac'][0]['hvac_distribution']['duct'][0]['fraction']
    errors = get_error_messages(js2, js_schema)
    assert "'fraction' is a required property" in errors
    assert "'location' is a required property" not in errors
    assert "'insulated' is a required property" not in errors

    js3 = copy.deepcopy(js)
    del js3['building']['systems']['hvac'][0]['hvac_distribution']
    errors = get_error_messages(js3, js_schema)
    assert "'hvac_distribution' is a required property" in errors
    js3['building']['systems']['hvac'][0]['hvac_fraction'] = 0
    errors = get_error_messages(js3, js_schema)
    assert "'hvac_distribution' is a required property" in errors
    js3['building']['systems']['hvac'][0]['hvac_fraction'] = 1
    js3['building']['systems']['hvac'][0]['heating']['type'] = 'mini_split'
    js3['building']['systems']['hvac'][0]['heating']['efficiency'] = 6
    js3['building']['systems']['hvac'][0]['cooling']['type'] = 'packaged_dx'
    errors = get_error_messages(js3, js_schema)
    assert len(errors) == 0

    js4 = copy.deepcopy(js)
    del js4['building']['systems']['hvac'][0]['hvac_distribution']['leakage_method']
    errors = get_error_messages(js4, js_schema)
    assert "'leakage_method' is a required property" in errors
    js4['building']['systems']['hvac'][0]['hvac_distribution']['leakage_method'] = 'quantitative'
    errors = get_error_messages(js4, js_schema)
    assert "'leakage_to_outside' is a required property" in errors
    if hpxml_filebase == 'townhouse_walls':
        assert ("{'required': ['sealed']} is not allowed for {'sealed': False, 'duct': [{'name': 'duct1', "
                "'location': 'cond_space', 'fraction': 1.0, 'insulated': False}], "
                "'leakage_method': 'quantitative'}") in errors
    elif hpxml_filebase == 'house1':
        assert ("{'required': ['sealed']} is not allowed for {'sealed': False, 'duct': [{'name': 'duct1', "
                "'location': 'vented_crawl', 'fraction': 0.5, 'insulated': True}, {'name': 'duct2', "
                "'location': 'uncond_attic', 'fraction': 0.35, 'insulated': True}, {'name': 'duct3', "
                "'location': 'cond_space', 'fraction': 0.15, 'insulated': False}], "
                "'leakage_method': 'quantitative'}") in errors

    js5 = copy.deepcopy(js)
    del js5['building']['systems']['hvac'][0]['hvac_distribution']['sealed']
    errors = get_error_messages(js5, js_schema)
    assert "'sealed' is a required property" in errors


@pytest.mark.parametrize('hpxml_filebase', hescore_examples)
def test_invalid_domestic_hot_water(hpxml_filebase):
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)

    js1 = copy.deepcopy(js)
    del js1['building']['systems']['domestic_hot_water']['category']
    del js1['building']['systems']['domestic_hot_water']['efficiency_method']
    errors = get_error_messages(js1, js_schema)
    assert "'category' is a required property" in errors
    assert "'efficiency_method' is a required property" not in errors

    js2 = copy.deepcopy(js)
    del js2['building']['systems']['domestic_hot_water']['efficiency_method']
    errors = get_error_messages(js2, js_schema)
    assert "'efficiency_method' is a required property" in errors

    js3 = copy.deepcopy(js)
    del js3['building']['systems']['domestic_hot_water']['type']
    del js3['building']['systems']['domestic_hot_water']['fuel_primary']
    errors = get_error_messages(js3, js_schema)
    assert "'type' is a required property" in errors
    assert "'fuel_primary' is a required property" in errors
    if hpxml_filebase == 'townhouse_walls':
        del js3['building']['systems']['domestic_hot_water']['year']
        errors = get_error_messages(js3, js_schema)
        assert "'year' is a required property" in errors
    elif hpxml_filebase == 'house1':
        del js3['building']['systems']['domestic_hot_water']['energy_factor']
        errors = get_error_messages(js3, js_schema)
        assert "'energy_factor' is a required property" in errors
        js3['building']['systems']['domestic_hot_water']['category'] = 'combined'
        errors = get_error_messages(js3, js_schema)
        assert ("The category element can only be set to \"combined\" if the heating/type is \"boiler\""
                " and the boiler provides the domestic hot water") in errors
        js3['building']['systems']['hvac'][0]['heating']['type'] = 'boiler'
        errors = get_error_messages(js3, js_schema)
        assert ("The category element can only be set to \"combined\" if the heating/type is \"boiler\""
                " and the boiler provides the domestic hot water") not in errors

    js4 = copy.deepcopy(js)
    js4['building']['systems']['domestic_hot_water']['energy_factor'] = 0.44
    errors = get_error_messages(js4, js_schema)
    assert "0.44 is less than the minimum of 0.45" in errors
    js4['building']['systems']['domestic_hot_water']['type'] = 'tankless'
    errors = get_error_messages(js4, js_schema)
    if hpxml_filebase == 'townhouse_walls':
        assert "0.44 is less than the minimum of 0.45" not in errors
    elif hpxml_filebase == 'house1':
        assert "0.44 is less than the minimum of 0.45" in errors
    js4['building']['systems']['domestic_hot_water']['type'] = 'heat_pump'
    js4['building']['systems']['domestic_hot_water']['energy_factor'] = 4.1
    errors = get_error_messages(js4, js_schema)
    if hpxml_filebase == 'townhouse_walls':
        assert "4.1 is greater than the maximum of 4.0" not in errors
    elif hpxml_filebase == 'house1':
        assert "4.1 is greater than the maximum of 4.0" in errors
    js4['building']['systems']['domestic_hot_water']['type'] = 'indirect'
    errors = get_error_messages(js4, js_schema)
    assert "'combined' was expected" in errors

    js5 = copy.deepcopy(js)
    if hpxml_filebase == 'townhouse_walls':
        js5['building']['systems']['domestic_hot_water']['energy_factor'] = 0.6
        errors = get_error_messages(js5, js_schema)
        assert ("{'required': ['energy_factor']} is not allowed for {'category': 'unit', 'type': 'storage', "
                "'fuel_primary': 'natural_gas', 'efficiency_method': 'shipment_weighted', 'year': 2010, "
                "'energy_factor': 0.6}") in errors
    elif hpxml_filebase == 'house1':
        js5['building']['systems']['domestic_hot_water']['year'] = 2021
        errors = get_error_messages(js5, js_schema)
        assert ("{'required': ['year']} is not allowed for {'category': 'unit', 'type': 'storage', "
                "'fuel_primary': 'electric', 'efficiency_method': 'user', 'energy_factor': 0.8, "
                "'year': 2021}") in errors


@pytest.mark.parametrize('hpxml_filebase', hescore_examples)
def test_invalid_solar_electric(hpxml_filebase):
    schema = get_json_schema()
    js_schema = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
    js = get_example_json(hpxml_filebase)

    js1 = copy.deepcopy(js)
    js1['building']['systems'] = {'generation': {'solar_electric': {'capacity_known': False, 'system_capacity': 50}}}
    errors = get_error_messages(js1, js_schema)
    assert "'num_panels' is a required property" in errors
    assert "'year' is a required property" in errors
    assert "'array_azimuth' is a required property" in errors
    assert "'array_tilt' is a required property" in errors
    assert ("{'required': ['system_capacity']} is not allowed for {'capacity_known': False, "
            "'system_capacity': 50}") in errors

    js2 = copy.deepcopy(js)
    js2['building']['systems'] = {'generation': {'solar_electric': {'capacity_known': True, 'num_panels': 5}}}
    errors = get_error_messages(js2, js_schema)
    assert "'system_capacity' is a required property" in errors
    assert "'year' is a required property" in errors
    assert "'array_azimuth' is a required property" in errors
    assert "'array_tilt' is a required property" in errors
    assert ("{'required': ['num_panels']} is not allowed for {'capacity_known': True, 'num_panels': 5}") in errors

    js3 = copy.deepcopy(js)
    js3['building']['systems'] = {'generation': {'solar_electric': {'year': 2021}}}
    errors = get_error_messages(js3, js_schema)
    assert "'capacity_known' is a required property" in errors
    assert "'array_azimuth' is a required property" in errors
    assert "'array_tilt' is a required property" in errors
    assert "'num_panels' is a required property" not in errors
    assert "'system_capacity' is a required property" not in errors
