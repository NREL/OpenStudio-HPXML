# frozen_string_literal: true

require_relative '../../../hpxml-measures/HPXMLtoOpenStudio/resources/minitest_helper'
require_relative '../../../hpxml-measures/HPXMLtoOpenStudio/resources/xmlhelper.rb'
require_relative '../../../hpxml-measures/HPXMLtoOpenStudio/resources/hpxml.rb'
require_relative '../resources/HESruleset.rb'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require_relative '../measure.rb'
require 'fileutils'

class HEScoreRulesetTest < MiniTest::Test
  def test_regression_files
    this_dir = File.dirname(__FILE__)

    args_hash = {}

    Dir["#{this_dir}/../../../workflow/regression_files/*.json"].sort.each do |json|
      # next if File.basename(json, ".json") != "Roof2_cathedral_ceiling_kneewall"
      puts "Testing #{File.absolute_path(json)}..."

      args_hash['json_path'] = File.absolute_path(json)
      args_hash['hpxml_output_path'] = File.absolute_path(json).gsub('.json', '.xml.out')

      _test_measure(args_hash)
      _test_schema_validation(this_dir, json.gsub('.json', '.xml.out'))
      _test_assembly_effective_rvalues(args_hash)
      _test_conditioned_building_volume(args_hash)

      FileUtils.rm_f(args_hash['hpxml_output_path']) # Cleanup
    end
  end

  def test_historic_files
    this_dir = File.dirname(__FILE__)

    args_hash = {}

    Dir["#{this_dir}/../../../workflow/historic_files/*.json"].sort.each do |json|
      puts "Testing #{File.absolute_path(json)}..."

      args_hash['json_path'] = File.absolute_path(json)
      args_hash['hpxml_output_path'] = File.absolute_path(json).gsub('.json', '.xml.out')

      _test_measure(args_hash)
      _test_schema_validation(this_dir, json.gsub('.json', '.xml.out'))
      _test_assembly_effective_rvalues(args_hash)
      _test_conditioned_building_volume(args_hash)

      FileUtils.rm_f(args_hash['hpxml_output_path']) # Cleanup
    end
  end

  def test_neighbors
    this_dir = File.dirname(__FILE__)
    json = File.absolute_path("#{this_dir}/../../../workflow/regression_files/Base.json")

    args_hash = {
      'json_path' => json,
      'hpxml_output_path' => json.gsub('.json', '.xml.out')
    }

    _test_measure(args_hash)

    hpxml = HPXML.new(hpxml_path: args_hash['hpxml_output_path'])

    assert_equal(2, hpxml.neighbor_buildings.size)

    hpxml.neighbor_buildings.each do |neighbor_building|
      assert_in_epsilon(neighbor_building.distance, 20.0, 0.000001)
      assert([90, 270].include?(neighbor_building.azimuth))
      assert_in_epsilon(neighbor_building.height, 12.0, 0.000001)
    end

    FileUtils.rm_f(args_hash['hpxml_output_path']) # Cleanup
  end

  def test_ducts
    # Base (No ducts in conditioned space)
    cfa = 2000.0
    ncfl_ag = 2
    sealed = true
    frac_inside = 0.0
    lto_units, lto_s, lto_r, uncond_area_s, uncond_area_r = calc_duct_values(ncfl_ag, cfa, sealed, frac_inside)
    assert_in_epsilon(0.0325, lto_s, 0.00001)
    assert_in_epsilon(0.0500, lto_r, 0.00001)
    assert_in_epsilon(351, uncond_area_s, 0.00001)
    assert_in_epsilon(200, uncond_area_r, 0.00001)
    assert_equal(lto_units, HPXML::UnitsPercent)

    # Base w/ ducts completely in conditioned space
    cfa = 2000.0
    ncfl_ag = 2
    sealed = true
    frac_inside = 1.0
    lto_units, lto_s, lto_r, uncond_area_s, uncond_area_r = calc_duct_values(ncfl_ag, cfa, sealed, frac_inside)
    assert_in_epsilon(0, lto_s, 0.00001)
    assert_in_epsilon(0, lto_r, 0.00001)
    assert_in_epsilon(0, uncond_area_s, 0.00001)
    assert_in_epsilon(0, uncond_area_r, 0.00001)
    assert_equal(lto_units, HPXML::UnitsPercent)

    # Base w/ ducts half in conditioned space
    cfa = 2000.0
    ncfl_ag = 2
    sealed = true
    frac_inside = 0.5
    lto_units, lto_s, lto_r, uncond_area_s, uncond_area_r = calc_duct_values(ncfl_ag, cfa, sealed, frac_inside)
    assert_in_epsilon(0.025, lto_s, 0.00001)
    assert_in_epsilon(0.050, lto_r, 0.00001)
    assert_in_epsilon(270, uncond_area_s, 0.00001)
    assert_in_epsilon(200, uncond_area_r, 0.00001)
    assert_equal(lto_units, HPXML::UnitsPercent)

    # Base w/ unsealed ducts
    cfa = 2000.0
    ncfl_ag = 2
    sealed = false
    frac_inside = 0.0
    lto_units, lto_s, lto_r, uncond_area_s, uncond_area_r = calc_duct_values(ncfl_ag, cfa, sealed, frac_inside)
    assert_in_epsilon(0.08125, lto_s, 0.00001)
    assert_in_epsilon(0.12500, lto_r, 0.00001)
    assert_in_epsilon(351, uncond_area_s, 0.00001)
    assert_in_epsilon(200, uncond_area_r, 0.00001)
    assert_equal(lto_units, HPXML::UnitsPercent)

    # Base w/ 1 story home
    cfa = 2000.0
    ncfl_ag = 1
    sealed = true
    frac_inside = 0.0
    lto_units, lto_s, lto_r, uncond_area_s, uncond_area_r = calc_duct_values(ncfl_ag, cfa, sealed, frac_inside)
    assert_in_epsilon(0.05, lto_s, 0.00001)
    assert_in_epsilon(0.05, lto_r, 0.00001)
    assert_in_epsilon(540, uncond_area_s, 0.00001)
    assert_in_epsilon(100, uncond_area_r, 0.00001)
    assert_equal(lto_units, HPXML::UnitsPercent)

    # Base w/ 20000 sqft
    cfa = 20000.0
    ncfl_ag = 2
    sealed = true
    frac_inside = 0.0
    lto_units, lto_s, lto_r, uncond_area_s, uncond_area_r = calc_duct_values(ncfl_ag, cfa, sealed, frac_inside)
    assert_in_epsilon(0.0325, lto_s, 0.00001)
    assert_in_epsilon(0.0500, lto_r, 0.00001)
    assert_in_epsilon(3510, uncond_area_s, 0.00001)
    assert_in_epsilon(2000, uncond_area_r, 0.00001)
    assert_equal(lto_units, HPXML::UnitsPercent)

    # Base w/ 90 cfm25 supply+return leakage to outside
    cfa = 2000.0
    ncfl_ag = 2
    sealed = true
    frac_inside = 0.0
    lto_units, lto_s, lto_r, uncond_area_s, uncond_area_r = calc_duct_values(ncfl_ag, cfa, sealed, frac_inside, 90.0)
    assert_in_epsilon(45.0, lto_s, 0.00001)
    assert_in_epsilon(45.0, lto_r, 0.00001)
    assert_in_epsilon(351, uncond_area_s, 0.00001)
    assert_in_epsilon(200, uncond_area_r, 0.00001)
    assert_equal(lto_units, HPXML::UnitsCFM25)
  end

  def test_infiltration
    # Tests from ResDB.Infiltration.Model.v2.xlsx

    # Version 1, Test #1
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = HPXML::LeakinessAverage
    year_built = 1975
    iecc_cz = '3B'
    fnd_types = { 'slab_on_grade' => 1000.0 }
    ducts = [[1.0, 1.0, 'uncond_attic']]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(9.7, ach50, 0.01)

    # Version 1, Test #2
    cfa = 1000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = HPXML::LeakinessAverage
    year_built = 1975
    iecc_cz = '3B'
    fnd_types = { 'slab_on_grade' => 1000.0 }
    ducts = [[1.0, 1.0, 'uncond_attic']]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(11.8, ach50, 0.01)

    # Version 1, Test #3
    cfa = 2000.0
    ncfl_ag = 1
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = HPXML::LeakinessAverage
    year_built = 1975
    iecc_cz = '3B'
    fnd_types = { 'slab_on_grade' => 2000.0 }
    ducts = [[1.0, 1.0, 'uncond_attic']]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(10.2, ach50, 0.01)

    # Version 1, Test #4
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 12.0
    cvolume = cfa * ceil_height
    desc = HPXML::LeakinessAverage
    year_built = 1975
    iecc_cz = '3B'
    fnd_types = { 'slab_on_grade' => 1000.0 }
    ducts = [[1.0, 1.0, 'uncond_attic']]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(7.6, ach50, 0.01)

    # Version 1, Test #5
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = HPXML::LeakinessAverage
    year_built = 2013
    iecc_cz = '3B'
    fnd_types = { 'slab_on_grade' => 1000.0 }
    ducts = [[1.0, 1.0, 'uncond_attic']]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(5.3, ach50, 0.01)

    # Version 1, Test #6
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = HPXML::LeakinessAverage
    year_built = 1975
    iecc_cz = '4C'
    fnd_types = { 'slab_on_grade' => 1000.0 }
    ducts = [[1.0, 1.0, 'uncond_attic']]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(13.1, ach50, 0.01)

    # Version 1, Test #7
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = HPXML::LeakinessAverage
    year_built = 1975
    iecc_cz = '3B'
    fnd_types = { 'cond_basement' => 1000.0 }
    ducts = [[1.0, 1.0, 'uncond_attic']]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(11.2, ach50, 0.01)

    # Version 1, Test #8
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = HPXML::LeakinessAverage
    year_built = 1975
    iecc_cz = '3B'
    fnd_types = { 'slab_on_grade' => 1000.0 }
    ducts = [[1.0, 1.0, 'cond_space']]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(8.0, ach50, 0.01)

    # Version 1, Test #9
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = HPXML::LeakinessTight
    year_built = 1975
    iecc_cz = '3B'
    fnd_types = { 'slab_on_grade' => 1000.0 }
    ducts = [[1.0, 1.0, 'uncond_attic']]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(7.3, ach50, 0.01)

    # Version 2, Test #1
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = HPXML::LeakinessAverage
    year_built = 1975
    iecc_cz = '3B'
    fnd_types = { 'slab_on_grade' => 600.0,
                  'cond_basement' => 400.0 }
    ducts = [[0.75, 0.5, 'uncond_attic'],
             [0.75, 0.25, 'cond_space'],
             [0.75, 0.25, 'vented_crawl'],
             [0.25, 0.5, 'unvented_crawl'],
             [0.25, 0.3, 'uncond_attic'],
             [0.25, 0.2, 'vented_crawl']]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(10.2, ach50, 0.01)

    # Add test for ductless == conditioned ducts
    # See https://github.com/NREL/OpenStudio-HEScore/issues/211)
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = HPXML::LeakinessAverage
    year_built = 1975
    iecc_cz = '3B'
    fnd_types = { 'slab_on_grade' => 1000.0 }
    ducts = []
    ach50_ductless = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    ducts = [[1.0, 1.0, 'cond_space']]
    ach50_ducted = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_equal(ach50_ductless, ach50_ducted)

    # Add test for ducted + ductless system ~= average(conditioned ducts, unconditioned ducts)
    # See https://github.com/NREL/OpenStudio-HEScore/issues/211)
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = HPXML::LeakinessAverage
    year_built = 1975
    iecc_cz = '3B'
    fnd_types = { 'slab_on_grade' => 1000.0 }
    ducts = [[0.5, 1.0, 'uncond_attic']] # 50% ducts in attic + 50% ductless
    ach50_mixed = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    ducts = [[1.0, 1.0, 'cond_space']]
    ach50_cond = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    ducts = [[1.0, 1.0, 'uncond_attic']]
    ach50_uncond = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(ach50_mixed, (ach50_cond + ach50_uncond) / 2.0, 0.01)
  end

  def test_foundation_area_lookup
    this_dir = File.dirname(__FILE__)
    json_path = File.absolute_path("#{this_dir}/../../../workflow/regression_files/Floor2_conditioned_basement.json")

    json_file = File.open(json_path)
    json = JSON.parse(json_file.read)
    new_hpxml = HPXML.new()

    HEScoreRuleset.set_summary(json, new_hpxml)
    bldg_length_side = HEScoreRuleset.instance_variable_get(:@bldg_length_side)
    bldg_length_front = HEScoreRuleset.instance_variable_get(:@bldg_length_front)

    slab_foundation = json['building']['zone']['zone_floor'][0]
    slab_area = slab_foundation['floor_area'].to_f
    assert_in_epsilon(slab_area, 600.0, 0.01)
    basement_foundation = json['building']['zone']['zone_floor'][1]
    basement_area = basement_foundation['floor_area'].to_f
    assert_in_epsilon(basement_area, 400.0, 0.01)

    slab_perimeter = HEScoreRuleset.get_foundation_perimeter(json, slab_foundation)
    basement_perimeter = HEScoreRuleset.get_foundation_perimeter(json, basement_foundation)
    total_area = slab_area + basement_area
    slab_area_frac = slab_area / total_area
    bsmt_area_frac = basement_area / total_area
    assert_in_epsilon(slab_perimeter, bldg_length_side + 2 * bldg_length_front * slab_area_frac, 0.01)
    assert_in_epsilon(basement_perimeter, bldg_length_side + 2 * bldg_length_front * bsmt_area_frac, 0.01)
    assert_in_epsilon(slab_perimeter + basement_perimeter, HEScoreRuleset.instance_variable_get(:@bldg_perimeter), 0.01)
  end

  def test_hvac_lookup
    small_number = 0.00000000001
    eff1 = lookup_hvac_efficiency(2010, 'central air conditioner', 'electricity', 'SEER')
    assert_in_epsilon(eff1, 13.76, small_number)

    eff2 = lookup_hvac_efficiency(nil, 'Furnace', 'natural gas', 'AFUE', 'energy_star', 'CO')
    assert_in_epsilon(eff2, 0.95, small_number)

    eff3 = lookup_hvac_efficiency(nil, 'Furnace', 'natural gas', 'AFUE', 'energy_star', 'GA')
    assert_in_epsilon(eff3, 0.9, small_number)

    err4 = assert_raises RuntimeError do
      lookup_hvac_efficiency(nil, 'Furnace', 'natural gas', 'AFUE', 'energy_star')
    end
    assert_match(/state_code required/, err4.message)

    err5 = assert_raises RuntimeError do
      lookup_hvac_efficiency(1997, 'Furnace', 'unicorn tears', 'AFUE')
    end
    assert_match(/Unexpected fuel_type/, err5.message)

    err6 = assert_raises RuntimeError do
      lookup_hvac_efficiency(1997, 'some invalid hvac_type', 'electricity', 'SEER')
    end
    assert_match(/Unexpected hvac_type/, err6.message)

    err7 = assert_raises RuntimeError do
      lookup_hvac_efficiency(2010, 'central air conditioner', 'electricity', 'EER')
    end
    assert_match(/Could not lookup default HVAC efficiency/, err7.message)

    err8 = assert_raises RuntimeError do
      lookup_hvac_efficiency(nil, 'Furnace', 'natural gas', 'AFUE', 'energy_star', 'ON')
    end
    assert_match(/Could not lookup Energy Star furnace region for state/, err8.message)

    eff9 = lookup_hvac_efficiency(nil, 'Boiler', 'natural gas', 'AFUE', 'energy_star')
    assert_in_epsilon(eff9, 0.9, small_number)

    eff10 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'SEER', 'energy_star')
    assert_in_epsilon(eff10, 15.0, small_number)

    eff11 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'HSPF', 'energy_star')
    assert_in_epsilon(eff11, 8.5, small_number)

    err9 = assert_raises RuntimeError do
      lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'SEER', 'cee_tier1', nil, '9')
    end
    assert_match(/Could not lookup CEE region for IECC climate zone/, err9.message)

    eff10 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'SEER', 'cee_tier1', nil, '2A')
    assert_in_epsilon(eff10, 15.0, small_number)

    eff11 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'HSPF', 'cee_tier1', nil, '2A')
    assert_in_epsilon(eff11, 8.5, small_number)

    eff10 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'SEER', 'cee_tier1', nil, '7')
    assert_in_epsilon(eff10, 15.0, small_number)

    eff11 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'HSPF', 'cee_tier1', nil, '7')
    assert_in_epsilon(eff11, 9.0, small_number)

    eff10 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'SEER', 'cee_tier2', nil, '2A')
    assert_in_epsilon(eff10, 16.0, small_number)

    eff11 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'HSPF', 'cee_tier2', nil, '2A')
    assert_in_epsilon(eff11, 9.0, small_number)

    eff10 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'SEER', 'cee_tier2', nil, '7')
    assert_in_epsilon(eff10, 16.0, small_number)

    eff11 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'HSPF', 'cee_tier2', nil, '7')
    assert_in_epsilon(eff11, 9.5, small_number)

    eff10 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'SEER', 'cee_tier3', nil, '2A')
    assert_in_epsilon(eff10, 18.0, small_number)

    eff11 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'HSPF', 'cee_tier3', nil, '2A')
    assert_in_epsilon(eff11, 9.5, small_number)

    eff10 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'SEER', 'cee_tier3', nil, '7')
    assert_in_epsilon(eff10, 18.0, small_number)

    eff11 = lookup_hvac_efficiency(nil, 'air-to-air', 'electricity', 'HSPF', 'cee_tier3', nil, '7')
    assert_in_epsilon(eff11, 10.0, small_number)

    eff10 = lookup_hvac_efficiency(nil, 'mini-split', 'electricity', 'SEER', 'energy_star')
    assert_in_epsilon(eff10, 15.0, small_number)

    eff11 = lookup_hvac_efficiency(nil, 'mini-split', 'electricity', 'HSPF', 'energy_star')
    assert_in_epsilon(eff11, 8.5, small_number)

    eff10 = lookup_hvac_efficiency(nil, 'mini-split', 'electricity', 'SEER', 'cee_tier1')
    assert_in_epsilon(eff10, 18.0, small_number)

    eff11 = lookup_hvac_efficiency(nil, 'mini-split', 'electricity', 'HSPF', 'cee_tier1')
    assert_in_epsilon(eff11, 10.0, small_number)

    eff10 = lookup_hvac_efficiency(nil, 'central air conditioner', 'electricity', 'SEER', 'cee_tier1')
    assert_in_epsilon(eff10, 16.0, small_number)

    eff11 = lookup_hvac_efficiency(nil, 'central air conditioner', 'electricity', 'SEER', 'cee_tier2')
    assert_in_epsilon(eff11, 18.0, small_number)

    err12 = assert_raises RuntimeError do
      lookup_hvac_efficiency(2010, 'central air conditioner', 'electricity', 'SEER', 'bogus_performance_id')
    end
    assert_match(/Invalid performance_id for HVAC lookup/, err12.message)

    err13 = assert_raises RuntimeError do
      lookup_hvac_efficiency(2010, 'mini-split', 'electricity', 'SEER')
    end
    assert_match(/Could not lookup default HVAC efficiency/, err13.message)

    assert_in_epsilon(
      lookup_hvac_efficiency(2010, 'air-to-air', 'electricity', 'SEER'),
      lookup_hvac_efficiency(2011, 'air-to-air', 'electricity', 'SEER'),
      small_number
    )

    assert_in_epsilon(
      lookup_hvac_efficiency(2010, 'Furnace', 'natural gas', 'AFUE'),
      lookup_hvac_efficiency(2020, 'Furnace', 'natural gas', 'AFUE'),
      small_number
    )

    assert_in_epsilon(
      lookup_hvac_efficiency(1969, 'Boiler', 'fuel oil', 'AFUE'),
      lookup_hvac_efficiency(1970, 'Boiler', 'fuel oil', 'AFUE'),
      small_number
    )

    assert_in_epsilon(
      lookup_hvac_efficiency(1955, 'central air conditioner', 'electricity', 'SEER'),
      lookup_hvac_efficiency(1970, 'central air conditioner', 'electricity', 'SEER'),
      small_number
    )
  end

  def test_dhw_lookup
    small_number = 0.00000000001
    eff1 = lookup_water_heater_efficiency(2006, 'electricity')
    assert_in_epsilon(eff1, 0.9, small_number)

    eff2 = lookup_water_heater_efficiency(1998, 'natural gas')
    assert_in_epsilon(eff2, 0.501, small_number)

    eff3 = lookup_water_heater_efficiency(2007, 'propane')
    assert_in_epsilon(eff3, 0.55, small_number)

    eff4 = lookup_water_heater_efficiency(1989, 'fuel oil')
    assert_in_epsilon(eff4, 0.54, small_number)

    eff5 = lookup_water_heater_efficiency(nil, 'natural gas', 'energy_star')
    assert_in_epsilon(eff5, 0.67, small_number)

    eff6 = lookup_water_heater_efficiency(nil, 'propane', 'energy_star')
    assert_in_epsilon(eff6, 0.67, small_number)

    eff7 = lookup_water_heater_efficiency(nil, 'electricity', 'energy_star')
    assert_in_epsilon(eff7, 2.2, small_number)

    err8 = assert_raises RuntimeError do
      lookup_water_heater_efficiency(2006, 'unicorn tears')
    end
    assert_match(/Unexpected fuel_type/, err8.message)

    err9 = assert_raises RuntimeError do
      lookup_water_heater_efficiency(2006, 'electricity', 'bogus performance_id')
    end
    assert_match(/Invalid performance_id/, err9.message)

    err10 = assert_raises RuntimeError do
      lookup_water_heater_efficiency(nil, 'fuel oil', 'energy_star')
    end
    assert_match(/Could not lookup default water heating efficiency/, err10.message)

    ['natural gas', 'electricity', 'propane', 'fuel oil'].each do |fuel_type|
      assert_in_epsilon(
        lookup_water_heater_efficiency(2010, fuel_type),
        lookup_water_heater_efficiency(2011, fuel_type),
        small_number
      )
      assert_in_epsilon(
        lookup_water_heater_efficiency(2010, fuel_type),
        lookup_water_heater_efficiency(2020, fuel_type),
        small_number
      )
      assert_in_epsilon(
        lookup_water_heater_efficiency(1971, fuel_type),
        lookup_water_heater_efficiency(1972, fuel_type),
        small_number
      )
      assert_in_epsilon(
        lookup_water_heater_efficiency(1955, fuel_type),
        lookup_water_heater_efficiency(1972, fuel_type),
        small_number
      )
    end
  end

  def _test_measure(args_hash)
    # create an instance of the measure
    measure = HEScoreMeasure.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    model = OpenStudio::Model::Model.new

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
  end

  def _test_schema_validation(parent_dir, xml)
    # TODO: Remove this when schema validation is included with CLI calls
    schemas_dir = File.absolute_path(File.join(parent_dir, '..', '..', '..', 'hpxml-measures', 'HPXMLtoOpenStudio', 'resources', 'hpxml_schema'))
    hpxml_doc = XMLHelper.parse_file(xml)
    errors = XMLHelper.validate(hpxml_doc.to_xml, File.join(schemas_dir, 'HPXML.xsd'), nil)
    if errors.size > 0
      puts "#{xml}: #{errors}"
    end
    assert_equal(0, errors.size)
  end

  def _test_assembly_effective_rvalues(args_hash)
    json_file = File.open(args_hash['json_path'])
    in_doc = JSON.parse(json_file.read)
    out_doc = XMLHelper.parse_file(args_hash['hpxml_output_path'])

    wall_code_by_id = {}
    in_doc['building']['zone']['zone_wall'].each do |wall|
      wall_code = wall['wall_assembly_code']
      wallid = "#{wall['side']}_wall"
      wall_code_by_id[wallid] = wall_code
    end

    in_doc['building']['zone']['zone_roof'].each do |roof|
      next unless roof.key?('knee_wall')
      knee_wall_code = roof['knee_wall']['assembly_code']
      knee_wall_id = "#{roof['roof_name']}_knee_wall"
      wall_code_by_id[knee_wall_id] = knee_wall_code
    end

    XMLHelper.get_elements(out_doc, 'HPXML/Building/BuildingDetails/Enclosure/Walls/Wall') do |wall|
      eff_rvalue = XMLHelper.get_value(wall, 'Insulation/AssemblyEffectiveRValue', :float)
      wallid = XMLHelper.get_attribute_value(XMLHelper.get_element(wall, 'SystemIdentifier'), 'id')
      next if wall_code_by_id[wallid].nil?
      if wallid.end_with?("_knee_wall")
        assert_in_epsilon(eff_rvalue, get_knee_wall_effective_r_from_doe2code(wall_code_by_id[wallid]), 0.01)
      else
        assert_in_epsilon(eff_rvalue, get_wall_effective_r_from_doe2code(wall_code_by_id[wallid]), 0.01)
      end
    end

    roof_code_by_id = {}
    in_doc['building']['zone']['zone_roof'].each_with_index do |roof, idx|
      roof_code = roof['roof_assembly_code']
      roofid = "#{roof['roof_name']}_#{idx}"
      roof_code_by_id[roofid] = roof_code
    end

    XMLHelper.get_elements(out_doc, 'HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof') do |roof|
      roofid = XMLHelper.get_attribute_value(XMLHelper.get_element(roof, 'SystemIdentifier'), 'id')
      eff_rvalue = XMLHelper.get_value(roof, 'Insulation/AssemblyEffectiveRValue', :float)
      assert_in_epsilon(eff_rvalue, get_roof_effective_r_from_doe2code(roof_code_by_id[roofid.split('_')[0]]), 0.01)
    end
  end

  def _test_conditioned_building_volume(args_hash)
    json_file = File.open(args_hash['json_path'])
    in_doc = JSON.parse(json_file.read)
    out_doc = XMLHelper.parse_file(args_hash['hpxml_output_path'])

    cfa = in_doc['building']['about']['conditioned_floor_area']
    ceil_height = in_doc['building']['about']['floor_to_ceiling_height']
    cbv = XMLHelper.get_value(out_doc, 'HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedBuildingVolume', :float)

    has_cathedral_ceiling = false
    in_doc['building']['zone']['zone_roof'].each do |roof|
      if roof['roof_type'] == 'cath_ceiling'
        has_cathedral_ceiling = true
        break
      end
    end

    if not (has_cathedral_ceiling)
      assert_in_epsilon(cfa * ceil_height, cbv, 0.01)
    elsif has_cathedral_ceiling
      assert(cfa * ceil_height < cbv)
    end
  end
end
