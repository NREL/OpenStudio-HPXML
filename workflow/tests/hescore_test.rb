# frozen_string_literal: true

require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require 'json'
require 'parallel'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/measure'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/xmlhelper'
require_relative '../hescore_lib'

class HEScoreTest < MiniTest::Test
  def setup
    # Prepare results dir for CI storage
    @results_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', 'test_results'))
    FileUtils.mkdir_p @results_dir
  end

  def test_regression_files
    results_zip_path = File.join(@results_dir, 'results_regression_jsons.zip')
    File.delete(results_zip_path) if File.exist? results_zip_path
    results_csv_path = File.join(@results_dir, 'results_regression.csv')
    File.delete(results_csv_path) if File.exist? results_csv_path

    zipfile = OpenStudio::ZipFile.new(OpenStudio::Path.new(results_zip_path), false)

    results = {}
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..'))
    Parallel.map(Dir["#{parent_dir}/regression_files/*.json"].sort, in_threads: Parallel.processor_count) do |json|
      next unless json

      out_dir = File.join(parent_dir, "run#{Parallel.worker_number}")
      results[File.basename(json)] = run_and_check(json, out_dir, false, zipfile)
    end

    _write_summary_results(results.sort_by { |k, v| k.downcase }.to_h, results_csv_path)
  end

  def test_historic_files
    results_zip_path = File.join(@results_dir, 'results_historic_jsons.zip')
    File.delete(results_zip_path) if File.exist? results_zip_path
    results_csv_path = File.join(@results_dir, 'results_historic.csv')
    File.delete(results_csv_path) if File.exist? results_csv_path

    zipfile = OpenStudio::ZipFile.new(OpenStudio::Path.new(results_zip_path), false)

    results = {}
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..'))
    Parallel.map(Dir["#{parent_dir}/historic_files/*.json"].sort, in_threads: Parallel.processor_count) do |json|
      next unless json

      out_dir = File.join(parent_dir, "run#{Parallel.worker_number}")
      results[File.basename(json)] = run_and_check(json, out_dir, false, zipfile)
    end

    _write_summary_results(results.sort_by { |k, v| k.downcase }.to_h, results_csv_path)
  end

  def test_hescore_hpxml_example_files
    results_zip_path = File.join(@results_dir, 'results_hescore-hpxml_example_jsons.zip')
    File.delete(results_zip_path) if File.exist? results_zip_path
    results_csv_path = File.join(@results_dir, 'results_hescore-hpxml_example.csv')
    File.delete(results_csv_path) if File.exist? results_csv_path

    zipfile = OpenStudio::ZipFile.new(OpenStudio::Path.new(results_zip_path), false)

    results = {}
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..'))
    root_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
    Parallel.map(Dir["#{root_dir}/hescore-hpxml/examples/*.json"].sort, in_threads: Parallel.processor_count) do |json|
      next unless json

      out_dir = File.join(parent_dir, "run#{Parallel.worker_number}")
      results[File.basename(json)] = run_and_check(json, out_dir, false, zipfile)
    end

    _write_summary_results(results.sort_by { |k, v| k.downcase }.to_h, results_csv_path)
  end

  def test_skip_simulation
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..'))

    cli_path = OpenStudio.getOpenStudioCLI
    json = File.absolute_path(File.join(parent_dir, 'regression_files', 'Base.json'))
    command = "\"#{cli_path}\" \"#{File.join(File.dirname(__FILE__), '../run_simulation.rb')}\" --skip-simulation -j #{json}"
    success = system(command)
    assert_equal(true, success)

    # Check for output
    hes_hpxml = File.join(parent_dir, 'results', 'HEScoreDesign.xml')
    assert(File.exist?(hes_hpxml))

    # Check that IDF wasn't generated
    idf = File.join(parent_dir, 'HEScoreDesign', 'in.idf')
    assert(!File.exist?(idf))
  end

  def test_hourly_output
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..'))

    cli_path = OpenStudio.getOpenStudioCLI
    json = File.absolute_path(File.join(parent_dir, 'regression_files', 'Base.json'))
    command = "\"#{cli_path}\" \"#{File.join(File.dirname(__FILE__), '../run_simulation.rb')}\" --hourly -j #{json}"
    success = system(command)
    assert_equal(true, success)

    # Check for hourly output CSV
    hourly_output_csv = File.join(parent_dir, 'HEScoreDesign', 'results_hourly.csv')
    assert(File.exist?(hourly_output_csv))
  end

  def test_invalid_simulation
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..'))

    cli_path = OpenStudio.getOpenStudioCLI
    json = File.absolute_path(File.join(parent_dir, 'regression_files', 'Missing.json'))
    command = "\"#{cli_path}\" \"#{File.join(File.dirname(__FILE__), '../run_simulation.rb')}\" -j #{json}"
    success = system(command)
    assert_equal(false, success)
  end

  def test_floor_areas
    # Run modified HES HPXML w/ sum of conditioned floor areas' > CFA.
    # This file would normally generate errors in OS-HPXML, but the ruleset
    # now handles it. Check for successful run.
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..'))

    cli_path = OpenStudio.getOpenStudioCLI
    json_path = File.absolute_path(File.join(parent_dir, 'regression_files', 'Floors_1.json'))

    # Create derivative file
    json_file = File.open(json_path)
    json = JSON.parse(json_file.read)
    bldg_const = json['building']['about']['conditioned_floor_area']
    json['building']['about']['conditioned_floor_area'] = bldg_const - 5.0 # ft2
    json_path.gsub!('.json', '_floor_area_test.json')
    File.open(json_path, 'w') do |f|
      f.write(json.to_json)
    end

    # Run derivative file
    command = "\"#{cli_path}\" \"#{File.join(File.dirname(__FILE__), '../run_simulation.rb')}\" -j #{json_path}"
    success = system(command)

    # Check for success
    assert_equal(true, success)
    assert(File.exist?(File.join(parent_dir, 'results', 'HEScoreDesign.xml')))

    # Cleanup
    File.delete(json_path)
  end

  private

  def run_and_check(json, parent_dir, expect_error, zipfile)
    json_path = File.absolute_path(json)
    json_file = File.open(json_path)
    json = JSON.parse(json_file.read)

    # Run workflow
    cli_path = OpenStudio.getOpenStudioCLI
    command = "\"#{cli_path}\" \"#{File.join(File.dirname(__FILE__), '../run_simulation.rb')}\" -j #{json_path} -o #{parent_dir} --debug"
    start_time = Time.now
    success = system(command)
    assert_equal(true, success)
    runtime = Time.now - start_time

    results_json = File.join(parent_dir, 'results', 'results.json')
    results = nil
    if expect_error
      assert(!File.exist?(results_json))
    else
      # Check all output files exist
      hes_hpxml = File.join(parent_dir, 'results', 'HEScoreDesign.xml')
      assert(File.exist?(hes_hpxml))
      assert(File.exist?(results_json))

      # Check HPXMLs are valid
      schemas_dir = File.absolute_path(File.join(parent_dir, '..', '..', 'hpxml-measures', 'HPXMLtoOpenStudio', 'resources'))
      _test_schema_validation(parent_dir, hes_hpxml, schemas_dir)

      # Check run.log for messages
      File.readlines(File.join(parent_dir, 'HEScoreDesign', 'run.log')).each do |log_line|
        next if log_line.strip.empty?
        next if log_line.start_with? 'Info: '
        next if log_line.start_with? 'Executing command'

        next if log_line.include? 'Warning: Could not load nokogiri, no HPXML validation performed.'

        # FIXME: Remove this warning when https://github.com/NREL/OpenStudio-HPXML/issues/638 is resolved
        next if log_line.include?('Glazing U-factor') && log_line.include?('above maximum expected value. U-factor decreased')

        # Files w/o cooling systems
        no_spc_clg = false
        json['building']['systems']['hvac'].each do |hvac|
          if hvac['cooling'].nil? || hvac['cooling']['type'] == 'none'
            no_spc_clg = true
          end
        end
        next if no_spc_clg && log_line.include?('No space cooling specified, the model will not include space cooling energy use.')

        # Files w/o heating systems
        no_spc_htg = false
        json['building']['systems']['hvac'].each do |hvac|
          if hvac['heating'].nil? || hvac['heating']['type'] == 'none'
            no_spc_htg = true
          end
        end
        next if no_spc_htg && log_line.include?('No space heating specified, the model will not include space heating energy use.')

        # Files w/o windows
        if json['building']['zone']['zone_wall'].map { |w| w.key?('zone_window') ? w['zone_window']['window_area'] : 0 }.sum(0.0) <= 1.0
          next if log_line.include?('No windows specified, the model will not include window heat transfer.')
        end

        flunk "Unexpected warning found in run.log: #{log_line}"
      end

      # Add results.json to zip file for storage on CI
      zipfile.addFile(OpenStudio::Path.new(results_json), OpenStudio::Path.new(File.basename(json_path.gsub('.json', '_results.json'))))

      results = _get_results(parent_dir)
      _test_results(json_path, json, results)
    end

    return results
  end

  def _get_results(parent_dir)
    # Retrieve results from results.json
    json_path = File.join(parent_dir, 'results', 'results.json')
    data = JSON.parse(File.read(json_path))

    results = {}

    # Fill in missing results with zeros
    get_output_map.values.uniq.each do |hes_key|
      end_use = hes_key[0]
      resource_type = hes_key[1]
      units = get_units_map[resource_type]
      key = [resource_type.to_s, end_use.to_s, units]

      found_in_results = false
      data['end_use'].each do |result|
        resource_type = result['resource_type']
        end_use = result['end_use']
        units = result['units']
        results_key = [resource_type, end_use, units]
        next if results_key != key

        if results[key].nil?
          results[key] = 0.0
        end
        results[key] += Float(result['quantity']) # Just store annual results
        found_in_results = true
      end

      if not found_in_results
        results[key] = 0.0
      end
    end

    return results
  end

  def _test_results(json_path, json, results)
    # Get HPXML values for Building Construction
    cfa = json['building']['about']['conditioned_floor_area']
    nbr = json['building']['about']['number_bedrooms']

    # Get HPXML values for HVAC
    htg_fuels = []
    json['building']['systems']['hvac'].each do |hvac|
      next if hvac['heating'].nil?
      next if hvac['heating']['type'] == 'none'
      next unless hvac['hvac_fraction'] > 0

      htg_fuels << hvac['heating']['fuel_primary']
      if ['central_furnace', 'boiler', 'wood_stove'].include? hvac['heating']['type']
        htg_fuels << 'electric' # fan/pump
      end
    end
    json['building']['systems']['hvac'].each do |hvac|
      next unless ['heat_pump', 'mini_split', 'gchp'].include? hvac['heating']
      next unless hvac['hvac_fraction'] > 0

      htg_fuels << 'electric'
    end
    has_clg = false
    json['building']['systems']['hvac'].each do |hvac|
      next if hvac['cooling'].nil?
      next if hvac['cooling']['type'] == 'none'
      next unless hvac['hvac_fraction'] > 0

      has_clg = true
    end
    json['building']['systems']['hvac'].each do |hvac|
      next unless ['heat_pump', 'mini_split', 'gchp'].include? hvac['cooling']
      next unless hvac['hvac_fraction'] > 0

      has_clg = true
    end

    # Get HPXML values for Water Heating
    if json['building']['systems'].key? ('domestic_hot_water')
      hw_fuels = []
      water_heater = json['building']['systems']['domestic_hot_water']
      hw_fuels << water_heater['fuel_primary']

      if ['indirect', 'tankless_coil'].include? water_heater['type']
        json['building']['systems']['hvac'].each do |hvac|
          if hvac['heating']['type'] == 'boiler'
            hw_fuels << hvac['heating']['fuel_primary']
          end
        end
      end
    end

    # Get HPXML values for PV
    if json['building']['systems'].key?('generation')
      if json['building']['systems']['generation'].key?('solar_electric')
        has_pv = true
      end
    end

    tested_end_uses = []
    results.each do |key, value|
      resource_type, end_use, units = key

      # Check lighting end use matches ERI calculation
      if (end_use == 'lighting') && (resource_type == 'electric') && (units == 'kWh')
        eri_int_ltg = 455.0 + 0.80 * cfa
        eri_ext_ltg = 100.0 + 0.05 * cfa
        eri_ltg = eri_int_ltg + eri_ext_ltg
        assert_in_epsilon(eri_ltg, value, 0.01)
        tested_end_uses << end_use
      end

      # Check large_appliance end use matches ERI calculation
      if (end_use == 'large_appliance') && (resource_type == 'electric') && (units == 'kWh')
        eri_fridge = 637.0 + 18.0 * nbr
        eri_clothes_dryer = 398.0 + 113.0 * nbr
        eri_clothes_washer = 53.53 + 15.18 * nbr
        eri_dishwasher = 60.0 + 24.0 * nbr
        eri_large_appl = eri_fridge + eri_clothes_dryer + eri_clothes_washer + eri_dishwasher
        assert_in_epsilon(eri_large_appl, value, 0.01)
        tested_end_uses << end_use
      end

      # Check small_appliance end use matches ERI calculation
      if (end_use == 'small_appliance') && (resource_type == 'electric') && (units == 'kWh')
        eri_mels = 0.91 * cfa
        eri_tv = 413.0 + 69.0 * nbr
        eri_range_oven = 331.0 + 39.0 * nbr
        eri_small_appl = eri_mels + eri_tv + eri_range_oven
        assert_in_epsilon(eri_small_appl, value, 0.01)
        tested_end_uses << end_use
      end

      # Check heating end use by fuel reflects presence of system
      if end_use == 'heating'
        if json.include? 'regression_files/Location_CZ09.json'
          # skip test: hot climate so potentially no heating energy
        elsif htg_fuels.include? resource_type
          assert_operator(value, :>, 0)
        else
          assert_operator(value, :<, 0.5)
        end
        tested_end_uses << end_use
      end

      # Check cooling end use reflects presence of cooling system
      if (end_use == 'cooling') && (resource_type == 'electric')
        if has_clg
          assert_operator(value, :>, 0)
        else
          assert_operator(value, :<, 0.5)
        end
        tested_end_uses << end_use
      end

      # Check hot_water end use by fuel reflects presence of system
      if (end_use == 'hot_water') && (resource_type != 'hot_water')
        if hw_fuels.include? resource_type
          assert_operator(value, :>, 0)
        else
          assert_operator(value, :<, 0.5)
        end
        tested_end_uses << end_use
      end

      # Check hot water use > 0
      if (end_use == 'hot_water') && (resource_type == 'hot_water')
        assert_operator(value, :>, 0)
      end

      # Check generation end use reflects presence of PV system
      next unless (end_use == 'generation') && (resource_type == 'electric')

      if has_pv
        assert_operator(value, :>, 0)
      else
        assert_operator(value, :<, 0.5)
      end
      tested_end_uses << end_use
    end

    # Check we actually tested the right number of categories
    assert_equal(7, tested_end_uses.uniq.size)
  end

  def _write_summary_results(results, results_csv_path)
    # Writes summary end use results to CSV file.

    column_headers = ['HPXML']
    results[results.keys[0]].keys.each do |key|
      column_headers << "#{key[0]}: #{key[1]} [#{key[2]}]"
    end

    require 'csv'
    CSV.open(results_csv_path, 'w') do |csv|
      csv << column_headers
      results.sort.each do |json, json_results|
        csv << [json] + json_results.values.map { |v| v.round(2) }
      end
    end

    puts "Wrote results to #{results_csv_path}."
  end

  def _test_schema_validation(parent_dir, xml, schemas_dir)
    # TODO: Remove this when schema validation is included with CLI calls
    hpxml_doc = XMLHelper.parse_file(xml)
    errors = XMLHelper.validate(hpxml_doc.to_xml, File.join(schemas_dir, 'HPXML.xsd'), nil)
    if errors.size > 0
      puts "#{xml}: #{errors}"
    end
    assert_equal(0, errors.size)
  end

  def _rm_path(path)
    if Dir.exist?(path)
      FileUtils.rm_r(path)
    end
    while true
      break if not Dir.exist?(path)

      sleep(0.01)
    end
  end
end
