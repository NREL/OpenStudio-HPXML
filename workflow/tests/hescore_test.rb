# frozen_string_literal: true

require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require 'json'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/measure'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/xmlhelper'
require_relative '../hescore_lib'

class HEScoreTest < Minitest::Unit::TestCase
  def before_setup
    # Prepare results dir for CI storage
    @results_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', 'test_results'))
    Dir.mkdir(@results_dir) unless File.exist? @results_dir
  end

  def test_valid_simulations
    results_zip_path = File.join(@results_dir, 'results_jsons.zip')
    File.delete(results_zip_path) if File.exist? results_zip_path
    results_csv_path = File.join(@results_dir, 'results.csv')
    File.delete(results_csv_path) if File.exist? results_csv_path

    zipfile = OpenStudio::ZipFile.new(OpenStudio::Path.new(results_zip_path), false)

    results = {}
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..'))
    xmldir = "#{parent_dir}/sample_files"
    Dir["#{xmldir}/*.xml"].sort.each do |xml|
      results[File.basename(xml)] = run_and_check(xml, parent_dir, false, zipfile)
    end

    _write_summary_results(results, results_csv_path)
  end

  def test_skip_simulation
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..'))

    cli_path = OpenStudio.getOpenStudioCLI
    xml = File.absolute_path(File.join(parent_dir, 'sample_files', 'Base_hpxml.xml'))
    command = "\"#{cli_path}\" \"#{File.join(File.dirname(__FILE__), '../run_simulation.rb')}\" --skip-simulation -x #{xml}"
    start_time = Time.now
    system(command)

    # Check for output
    hes_hpxml = File.join(parent_dir, 'results', 'HEScoreDesign.xml')
    assert(File.exist?(hes_hpxml))

    # Check that IDF wasn't generated
    idf = File.join(parent_dir, 'HEScoreDesign', 'in.idf')
    assert(!File.exist?(idf))
  end

  private

  def run_and_check(xml, parent_dir, expect_error, zipfile)
    # Check input HPXML is valid
    xml = File.absolute_path(xml)

    # Run workflow
    cli_path = OpenStudio.getOpenStudioCLI
    command = "\"#{cli_path}\" \"#{File.join(File.dirname(__FILE__), '../run_simulation.rb')}\" -x #{xml}"
    start_time = Time.now
    system(command)
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
      schemas_dir = File.absolute_path(File.join(parent_dir, '..', 'hpxml-measures', 'HPXMLtoOpenStudio', 'resources'))
      _test_schema_validation(parent_dir, xml, schemas_dir)
      _test_schema_validation(parent_dir, hes_hpxml, schemas_dir)

      # Add results.json to zip file for storage on CI
      zipfile.addFile(OpenStudio::Path.new(results_json), OpenStudio::Path.new(File.basename(xml.gsub('.xml', '_results.json'))))

      results = _get_results(parent_dir, runtime)
      _test_results(xml, results)
    end

    return results
  end

  def _get_results(parent_dir, runtime)
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

    results['Runtime'] = runtime

    return results
  end

  def _test_results(xml, results)
    hpxml = HPXML.new(hpxml_path: xml)

    fuel_map = { HPXML::FuelTypeElectricity => 'electric',
                 HPXML::FuelTypeNaturalGas => 'natural_gas',
                 HPXML::FuelTypeOil => 'fuel_oil',
                 HPXML::FuelTypePropane => 'lpg',
                 HPXML::FuelTypeWood => 'cord_wood',
                 HPXML::FuelTypeWoodPellets => 'pellet_wood' }

    # Get HPXML values for Building Construction
    cfa = hpxml.building_construction.conditioned_floor_area
    nbr = hpxml.building_construction.number_of_bedrooms

    # Get HPXML values for HVAC
    htg_fuels = []
    hpxml.heating_systems.each do |heating_system|
      next unless heating_system.fraction_heat_load_served > 0
      htg_fuels << fuel_map[heating_system.heating_system_fuel]
      if [HPXML::HVACTypeFurnace, HPXML::HVACTypeBoiler].include? heating_system.heating_system_type
        htg_fuels << fuel_map[HPXML::FuelTypeElectricity] # fan/pump
      end
    end
    hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.fraction_heat_load_served > 0
      htg_fuels << fuel_map[HPXML::FuelTypeElectricity]
    end
    has_clg = (hpxml.cooling_systems.select { |c| c.fraction_cool_load_served > 0 }.size > 0)

    # Get HPXML values for Water Heating
    hw_fuels = []
    hpxml.water_heating_systems.each do |water_heater|
      hw_fuels << fuel_map[water_heater.fuel_type]
      next unless [HPXML::WaterHeaterTypeCombiStorage, HPXML::WaterHeaterTypeCombiTankless].include? water_heater.water_heater_type
      hw_fuels << fuel_map[water_heater.related_hvac_system.heating_system_fuel]
    end

    # Get HPXML values for PV
    has_pv = (hpxml.pv_systems.size > 0)

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
        if xml.include? 'sample_files/Location_CZ09_hpxml.xml'
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
      next if not key.is_a? Array

      column_headers << "#{key[0]}: #{key[1]} [#{key[2]}]"
    end

    # Append runtime at the end
    column_headers << 'Runtime [s]'

    require 'csv'
    CSV.open(results_csv_path, 'w') do |csv|
      csv << column_headers
      results.each do |xml, xml_results|
        csv << [xml] + xml_results.values
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
