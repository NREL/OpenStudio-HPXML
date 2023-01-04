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
    @args_hash['hpxml_output_path'] = @args_hash['hpxml_path']
  end

  def teardown
    File.delete(@tmp_hpxml_path) if File.exist? @tmp_hpxml_path
    FileUtils.rm_rf(@tmp_output_path)
  end

  def test_stochastic
    hpxml = _create_hpxml('base.xml')
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'occupancy-stochastic.csv'))
    model, hpxml, result = _test_measure()

    info_msgs = result.info.map { |x| x.logMessage }
    assert(info_msgs.any? { |info_msg| info_msg.include?('stochastic schedule') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('SimYear=2007') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('MinutesPerStep=60') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('State=CO') })
    assert(!info_msgs.any? { |info_msg| info_msg.include?('RandomSeed') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('GeometryNumOccupants=3.0') })

    sf = SchedulesFile.new(model: model,
                           schedules_paths: hpxml.header.schedules_filepaths,
                           year: 2007)

    assert_in_epsilon(6689, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnOccupants, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(2086, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingInterior, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4090, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingExterior, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4090, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingGarage, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(150, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingExteriorHoliday, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(534, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCookingRange, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(213, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnDishwasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(134, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesWasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(151, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesDryer, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(3250, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCeilingFan, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4840, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsOther, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(298, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterDishwasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(325, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterClothesWasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(887, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterFixtures, schedules: sf.tmp_schedules), 0.1)
    assert(!sf.schedules.keys.include?(SchedulesFile::ColumnSleeping))
  end

  def test_stochastic_subset_of_columns
    hpxml = _create_hpxml('base.xml')
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    columns = [SchedulesFile::ColumnCookingRange,
               SchedulesFile::ColumnDishwasher,
               SchedulesFile::ColumnHotWaterDishwasher,
               SchedulesFile::ColumnClothesWasher,
               SchedulesFile::ColumnHotWaterClothesWasher,
               SchedulesFile::ColumnClothesDryer,
               SchedulesFile::ColumnHotWaterFixtures]

    @args_hash['schedules_type'] = 'stochastic'
    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'occupancy-stochastic.csv'))
    @args_hash['schedules_column_names'] = columns.join(', ')
    model, hpxml, result = _test_measure()

    info_msgs = result.info.map { |x| x.logMessage }
    assert(info_msgs.any? { |info_msg| info_msg.include?('ColumnNames') })

    sf = SchedulesFile.new(model: model,
                           schedules_paths: hpxml.header.schedules_filepaths,
                           year: 2007)

    columns.each do |column|
      assert(sf.schedules.keys.include?(column))
    end
    (SchedulesFile.ColumnNames - columns).each do |column|
      assert(!sf.schedules.keys.include?(column))
    end
  end

  def test_stochastic_subset_of_columns_invalid_name
    hpxml = _create_hpxml('base.xml')
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    @args_hash['schedules_type'] = 'stochastic'
    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'occupancy-stochastic.csv'))
    @args_hash['schedules_column_names'] = "foobar, #{SchedulesFile::ColumnCookingRange}, foobar2"
    _model, _hpxml, result = _test_measure(expect_fail: true)

    error_msgs = result.errors.map { |x| x.logMessage }
    assert(error_msgs.any? { |error_msg| error_msg.include?("Invalid column name specified: 'foobar'.") })
    assert(error_msgs.any? { |error_msg| error_msg.include?("Invalid column name specified: 'foobar2'.") })
  end

  def test_stochastic_debug
    hpxml = _create_hpxml('base.xml')
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'occupancy-stochastic.csv'))
    @args_hash['debug'] = true
    model, hpxml, result = _test_measure()

    info_msgs = result.info.map { |x| x.logMessage }
    assert(info_msgs.any? { |info_msg| info_msg.include?('stochastic schedule') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('SimYear=2007') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('MinutesPerStep=60') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('State=CO') })
    assert(!info_msgs.any? { |info_msg| info_msg.include?('RandomSeed') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('GeometryNumOccupants=3.0') })

    sf = SchedulesFile.new(model: model,
                           schedules_paths: hpxml.header.schedules_filepaths,
                           year: 2007)

    assert_in_epsilon(6689, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnOccupants, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(2086, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingInterior, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4090, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingExterior, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4090, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingGarage, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(150, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingExteriorHoliday, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(534, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCookingRange, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(213, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnDishwasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(134, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesWasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(151, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesDryer, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(3250, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCeilingFan, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4840, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsOther, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(298, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterDishwasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(325, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterClothesWasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(887, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterFixtures, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(3067, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnSleeping, schedules: sf.tmp_schedules), 0.1)
  end

  def test_random_seed
    hpxml = _create_hpxml('base-location-baltimore-md.xml')
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    @args_hash['schedules_random_seed'] = 1
    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'occupancy-stochastic.csv'))
    model, hpxml, result = _test_measure()

    info_msgs = result.info.map { |x| x.logMessage }
    assert(info_msgs.any? { |info_msg| info_msg.include?('stochastic schedule') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('SimYear=2007') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('MinutesPerStep=60') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('State=MD') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('RandomSeed=1') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('GeometryNumOccupants=3.0') })

    sf = SchedulesFile.new(model: model,
                           schedules_paths: hpxml.header.schedules_filepaths,
                           year: 2007)

    assert_in_epsilon(6689, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnOccupants, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(2086, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingInterior, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4090, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingExterior, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4090, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingGarage, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(150, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingExteriorHoliday, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(534, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCookingRange, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(213, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnDishwasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(134, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesWasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(151, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesDryer, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(3250, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCeilingFan, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4840, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsOther, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(298, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterDishwasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(325, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterClothesWasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(898, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterFixtures, schedules: sf.tmp_schedules), 0.1)
    assert(!sf.schedules.keys.include?(SchedulesFile::ColumnSleeping))

    @args_hash['schedules_random_seed'] = 2
    model, hpxml, result = _test_measure()

    info_msgs = result.info.map { |x| x.logMessage }
    assert(info_msgs.any? { |info_msg| info_msg.include?('stochastic schedule') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('SimYear=2007') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('MinutesPerStep=60') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('State=MD') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('RandomSeed=2') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('GeometryNumOccupants=3.0') })

    sf = SchedulesFile.new(model: model,
                           schedules_paths: hpxml.header.schedules_filepaths,
                           year: 2007)

    assert_in_epsilon(6072, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnOccupants, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(1765, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingInterior, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4090, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingExterior, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4090, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingGarage, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(150, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingExteriorHoliday, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(356, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCookingRange, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(165, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnDishwasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(101, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesWasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(166, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesDryer, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(3250, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCeilingFan, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4840, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsOther, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(226, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterDishwasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(244, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterClothesWasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(1077, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterFixtures, schedules: sf.tmp_schedules), 0.1)
    assert(!sf.schedules.keys.include?(SchedulesFile::ColumnSleeping))
  end

  def test_10_min_timestep
    hpxml = _create_hpxml('base-simcontrol-timestep-10-mins.xml')
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'occupancy-stochastic.csv'))
    model, hpxml, result = _test_measure()

    info_msgs = result.info.map { |x| x.logMessage }
    assert(info_msgs.any? { |info_msg| info_msg.include?('stochastic schedule') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('SimYear=2007') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('MinutesPerStep=10') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('State=CO') })
    assert(!info_msgs.any? { |info_msg| info_msg.include?('RandomSeed') })
    assert(info_msgs.any? { |info_msg| info_msg.include?('GeometryNumOccupants=3.0') })

    sf = SchedulesFile.new(model: model,
                           schedules_paths: hpxml.header.schedules_filepaths,
                           year: 2007)

    assert_in_epsilon(6707, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnOccupants, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(2077, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingInterior, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4090, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingExterior, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4090, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingGarage, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(150, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingExteriorHoliday, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(534, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCookingRange, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(213, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnDishwasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(105, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesWasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(151, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesDryer, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(3237, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCeilingFan, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(4845, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsOther, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(146, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterDishwasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(154, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterClothesWasher, schedules: sf.tmp_schedules), 0.1)
    assert_in_epsilon(397, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterFixtures, schedules: sf.tmp_schedules), 0.1)
    assert(!sf.schedules.keys.include?(SchedulesFile::ColumnSleeping))
  end

  def test_non_integer_number_of_occupants
    num_occupants = 3.2

    hpxml = _create_hpxml('base.xml')
    hpxml.building_occupancy.number_of_residents = num_occupants
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'occupancy-stochastic.csv'))
    _model, _hpxml, result = _test_measure()

    info_msgs = result.info.map { |x| x.logMessage }
    assert(info_msgs.any? { |info_msg| info_msg.include?("GeometryNumOccupants=#{Float(Integer(num_occupants))}") })
  end

  def test_zero_occupants
    num_occupants = 0.0

    hpxml = _create_hpxml('base.xml')
    hpxml.building_occupancy.number_of_residents = num_occupants
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    @args_hash['output_csv_path'] = File.absolute_path(File.join(@tmp_output_path, 'occupancy-stochastic.csv'))
    _model, _hpxml, result = _test_measure()

    info_msgs = result.info.map { |x| x.logMessage }
    assert(1, info_msgs.size)
    assert(info_msgs.any? { |info_msg| info_msg.include?('Number of occupants set to zero; skipping generation of stochastic schedules.') })
    assert(!File.exist?(@args_hash['output_csv_path']))
    assert_empty(hpxml.header.schedules_filepaths)
  end

  def _test_measure(expect_fail: false)
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

    # assert that it ran correctly
    if expect_fail
      show_output(result) unless result.value.valueName == 'Fail'
      assert_equal('Fail', result.value.valueName)
    else
      show_output(result) unless result.value.valueName == 'Success'
      assert_equal('Success', result.value.valueName)
    end

    hpxml = HPXML.new(hpxml_path: @tmp_hpxml_path)

    return model, hpxml, result
  end

  def _create_hpxml(hpxml_name)
    return HPXML.new(hpxml_path: File.join(@sample_files_path, hpxml_name))
  end
end
