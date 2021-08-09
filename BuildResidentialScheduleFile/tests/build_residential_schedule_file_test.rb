# frozen_string_literal: true

require_relative '../../HPXMLtoOpenStudio/resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
# require 'csv'
require_relative '../measure.rb'

class BuildResidentialScheduleFileTest < Minitest::Test
  def setup
    @root_path = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
    @sample_files_path = File.join(@root_path, 'workflow', 'sample_files')
    @tmp_hpxml_path = File.join(@sample_files_path, 'tmp.xml')
    @tmp_output_path = File.join(@sample_files_path, 'tmp_output')
    FileUtils.mkdir_p(@tmp_output_path)

    @args_hash = {}
    @args_hash['hpxml_path'] = File.absolute_path(@tmp_hpxml_path)
  end

  def teardown
    File.delete(@tmp_hpxml_path) if File.exist? @tmp_hpxml_path
    FileUtils.rm_rf(@tmp_output_path)
  end

  def test_smooth
    hpxml = _create_hpxml('base.xml')
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'smooth.csv'))
    model, hpxml = _test_measure()

    schedules_file = SchedulesFile.new(model: model, schedules_path: @args_hash['output_csv_path'], col_names: Constants.ScheduleColNames.keys)

    assert_in_epsilon(6020, schedules_file.annual_equivalent_full_load_hrs(col_name: 'occupants', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3321, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_interior', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2763, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_exterior', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2763, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_garage', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(150, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_exterior_holiday', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2224, schedules_file.annual_equivalent_full_load_hrs(col_name: 'cooking_range', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'refrigerator', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'extra_refrigerator', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'freezer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2994, schedules_file.annual_equivalent_full_load_hrs(col_name: 'dishwasher', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4158, schedules_file.annual_equivalent_full_load_hrs(col_name: 'clothes_washer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4503, schedules_file.annual_equivalent_full_load_hrs(col_name: 'clothes_dryer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6020, schedules_file.annual_equivalent_full_load_hrs(col_name: 'ceiling_fan', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(5468, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_other', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2288, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_tv', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(8760, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_vehicle', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3671, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_well_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2074, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_grill', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3671, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_lighting', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3671, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_fireplace', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2471, schedules_file.annual_equivalent_full_load_hrs(col_name: 'pool_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2471, schedules_file.annual_equivalent_full_load_hrs(col_name: 'pool_heater', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2502, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_tub_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2650, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_tub_heater', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2994, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_dishwasher', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4158, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_clothes_washer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4204, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_fixtures', schedules: schedules_file.tmp_schedules), 0.1)
    assert(!schedules_file.schedules.keys.include?('vacancy'))
  end

  def test_smooth_vacancy
    hpxml = _create_hpxml('base.xml')
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    @args_hash['schedules_vacancy_period'] = 'Dec 1 - Jan 31'
    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'smooth-vacancy.csv'))
    model, hpxml = _test_measure()

    schedules_file = SchedulesFile.new(model: model, schedules_path: @args_hash['output_csv_path'], col_names: Constants.ScheduleColNames.keys)

    assert_in_epsilon(4997, schedules_file.annual_equivalent_full_load_hrs(col_name: 'occupants', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2763, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_interior', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2176, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_exterior', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2176, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_garage', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(19, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_exterior_holiday', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(1810, schedules_file.annual_equivalent_full_load_hrs(col_name: 'cooking_range', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'refrigerator', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'extra_refrigerator', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'freezer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2436, schedules_file.annual_equivalent_full_load_hrs(col_name: 'dishwasher', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3444, schedules_file.annual_equivalent_full_load_hrs(col_name: 'clothes_washer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3738, schedules_file.annual_equivalent_full_load_hrs(col_name: 'clothes_dryer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(5342, schedules_file.annual_equivalent_full_load_hrs(col_name: 'ceiling_fan', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4308, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_other', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(1844, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_tv', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(7272, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_vehicle', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2951, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_well_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(1688, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_grill', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2951, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_lighting', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2951, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_fireplace', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2471, schedules_file.annual_equivalent_full_load_hrs(col_name: 'pool_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2471, schedules_file.annual_equivalent_full_load_hrs(col_name: 'pool_heater', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2502, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_tub_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2650, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_tub_heater', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2436, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_dishwasher', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3444, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_clothes_washer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3490, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_fixtures', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(1488, schedules_file.annual_equivalent_full_load_hrs(col_name: 'vacancy', schedules: schedules_file.tmp_schedules), 0.1)
  end

  def test_stochastic
    hpxml = _create_hpxml('base.xml')
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    @args_hash['schedules_type'] = 'stochastic'
    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'stochastic.csv'))
    model, hpxml = _test_measure()

    schedules_file = SchedulesFile.new(model: model, schedules_path: @args_hash['output_csv_path'], col_names: Constants.ScheduleColNames.keys)

    assert_in_epsilon(6689, schedules_file.annual_equivalent_full_load_hrs(col_name: 'occupants', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2086, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_interior', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4090, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_exterior', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4090, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_garage', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(150, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_exterior_holiday', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(534, schedules_file.annual_equivalent_full_load_hrs(col_name: 'cooking_range', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'refrigerator', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'extra_refrigerator', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'freezer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(213, schedules_file.annual_equivalent_full_load_hrs(col_name: 'dishwasher', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(134, schedules_file.annual_equivalent_full_load_hrs(col_name: 'clothes_washer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(151, schedules_file.annual_equivalent_full_load_hrs(col_name: 'clothes_dryer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3250, schedules_file.annual_equivalent_full_load_hrs(col_name: 'ceiling_fan', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4840, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_other', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2288, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_tv', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(8760, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_vehicle', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3671, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_well_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2074, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_grill', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3671, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_lighting', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3671, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_fireplace', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2471, schedules_file.annual_equivalent_full_load_hrs(col_name: 'pool_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2471, schedules_file.annual_equivalent_full_load_hrs(col_name: 'pool_heater', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2502, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_tub_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2650, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_tub_heater', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(298, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_dishwasher', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(325, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_clothes_washer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(1009, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_fixtures', schedules: schedules_file.tmp_schedules), 0.1)
    assert(!schedules_file.schedules.keys.include?('vacancy'))
  end

  def test_stochastic_vacancy
    hpxml = _create_hpxml('base.xml')
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    @args_hash['schedules_type'] = 'stochastic'
    @args_hash['schedules_vacancy_period'] = 'Dec 1 - Jan 31'
    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'stochastic-vacancy.csv'))
    model, hpxml = _test_measure()

    schedules_file = SchedulesFile.new(model: model, schedules_path: @args_hash['output_csv_path'], col_names: Constants.ScheduleColNames.keys)

    assert_in_epsilon(5548, schedules_file.annual_equivalent_full_load_hrs(col_name: 'occupants', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(1675, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_interior', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3222, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_exterior', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3222, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_garage', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(11, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_exterior_holiday', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(439, schedules_file.annual_equivalent_full_load_hrs(col_name: 'cooking_range', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'refrigerator', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'extra_refrigerator', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'freezer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(179, schedules_file.annual_equivalent_full_load_hrs(col_name: 'dishwasher', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(111, schedules_file.annual_equivalent_full_load_hrs(col_name: 'clothes_washer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(126, schedules_file.annual_equivalent_full_load_hrs(col_name: 'clothes_dryer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2620, schedules_file.annual_equivalent_full_load_hrs(col_name: 'ceiling_fan', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3912, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_other', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(1844, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_tv', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(7272, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_vehicle', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2951, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_well_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(1688, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_grill', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2951, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_lighting', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2951, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_fireplace', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2471, schedules_file.annual_equivalent_full_load_hrs(col_name: 'pool_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2471, schedules_file.annual_equivalent_full_load_hrs(col_name: 'pool_heater', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2502, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_tub_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2650, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_tub_heater', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(264, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_dishwasher', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(273, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_clothes_washer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(832, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_fixtures', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(1488, schedules_file.annual_equivalent_full_load_hrs(col_name: 'vacancy', schedules: schedules_file.tmp_schedules), 0.1)
  end

  def test_random_seed
    hpxml = _create_hpxml('base.xml')
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    @args_hash['schedules_type'] = 'stochastic'
    @args_hash['schedules_random_seed'] = 1
    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'stochastic.csv'))
    model, hpxml = _test_measure()

    schedules_file = SchedulesFile.new(model: model, schedules_path: @args_hash['output_csv_path'], col_names: Constants.ScheduleColNames.keys)

    assert_in_epsilon(6689, schedules_file.annual_equivalent_full_load_hrs(col_name: 'occupants', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2086, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_interior', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4090, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_exterior', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4090, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_garage', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(150, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_exterior_holiday', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(534, schedules_file.annual_equivalent_full_load_hrs(col_name: 'cooking_range', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'refrigerator', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'extra_refrigerator', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'freezer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(213, schedules_file.annual_equivalent_full_load_hrs(col_name: 'dishwasher', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(134, schedules_file.annual_equivalent_full_load_hrs(col_name: 'clothes_washer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(151, schedules_file.annual_equivalent_full_load_hrs(col_name: 'clothes_dryer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3250, schedules_file.annual_equivalent_full_load_hrs(col_name: 'ceiling_fan', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4840, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_other', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2288, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_tv', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(8760, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_vehicle', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3671, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_well_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2074, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_grill', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3671, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_lighting', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3671, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_fireplace', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2471, schedules_file.annual_equivalent_full_load_hrs(col_name: 'pool_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2471, schedules_file.annual_equivalent_full_load_hrs(col_name: 'pool_heater', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2502, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_tub_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2650, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_tub_heater', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(298, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_dishwasher', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(325, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_clothes_washer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(1009, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_fixtures', schedules: schedules_file.tmp_schedules), 0.1)
    assert(!schedules_file.schedules.keys.include?('vacancy'))

    @args_hash['schedules_random_seed'] = 2
    model, hpxml = _test_measure()

    schedules_file = SchedulesFile.new(model: model, schedules_path: @args_hash['output_csv_path'], col_names: Constants.ScheduleColNames.keys)

    assert_in_epsilon(6072, schedules_file.annual_equivalent_full_load_hrs(col_name: 'occupants', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(1765, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_interior', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4090, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_exterior', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4090, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_garage', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(150, schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_exterior_holiday', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(356, schedules_file.annual_equivalent_full_load_hrs(col_name: 'cooking_range', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'refrigerator', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'extra_refrigerator', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(6673, schedules_file.annual_equivalent_full_load_hrs(col_name: 'freezer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(165, schedules_file.annual_equivalent_full_load_hrs(col_name: 'dishwasher', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(101, schedules_file.annual_equivalent_full_load_hrs(col_name: 'clothes_washer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(166, schedules_file.annual_equivalent_full_load_hrs(col_name: 'clothes_dryer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3250, schedules_file.annual_equivalent_full_load_hrs(col_name: 'ceiling_fan', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(4840, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_other', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2288, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_tv', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(8760, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_vehicle', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3671, schedules_file.annual_equivalent_full_load_hrs(col_name: 'plug_loads_well_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2074, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_grill', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3671, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_lighting', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(3671, schedules_file.annual_equivalent_full_load_hrs(col_name: 'fuel_loads_fireplace', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2471, schedules_file.annual_equivalent_full_load_hrs(col_name: 'pool_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2471, schedules_file.annual_equivalent_full_load_hrs(col_name: 'pool_heater', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2502, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_tub_pump', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(2650, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_tub_heater', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(226, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_dishwasher', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(244, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_clothes_washer', schedules: schedules_file.tmp_schedules), 0.1)
    assert_in_epsilon(1126, schedules_file.annual_equivalent_full_load_hrs(col_name: 'hot_water_fixtures', schedules: schedules_file.tmp_schedules), 0.1)
    assert(!schedules_file.schedules.keys.include?('vacancy'))
  end

  def _test_measure()
    # create an instance of the measure
    measure = BuildResidentialScheduleFile.new

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    model = OpenStudio::Model::Model.new

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if @args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(@args_hash[arg.name]))
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

    hpxml = HPXML.new(hpxml_path: @tmp_hpxml_path)

    return model, hpxml
  end

  def _create_hpxml(hpxml_name)
    return HPXML.new(hpxml_path: File.join(@sample_files_path, hpxml_name))
  end
end
