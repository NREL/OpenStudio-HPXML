require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require 'json'
require_relative '../../measures/HPXMLtoOpenStudio/measure'
require_relative '../../measures/HPXMLtoOpenStudio/resources/xmlhelper'
require_relative '../../measures/HPXMLtoOpenStudio/resources/schedules'
require_relative '../../measures/HPXMLtoOpenStudio/resources/constants'
require_relative '../../measures/HPXMLtoOpenStudio/resources/unit_conversions'
require_relative '../../measures/HPXMLtoOpenStudio/resources/hotwater_appliances'

class HEScoreTest < Minitest::Unit::TestCase
  def before_setup
    # Download weather files
    this_dir = File.absolute_path(File.join(File.dirname(__FILE__), ".."))
    cli_path = OpenStudio.getOpenStudioCLI
    command = "\"#{cli_path}\" --no-ssl \"#{File.join(File.dirname(__FILE__), "..", "run_simulation.rb")}\" --download-weather"
    system(command)

    num_epws_expected = File.readlines(File.join(this_dir, "..", "weather", "data.csv")).size - 1
    num_epws_actual = Dir[File.join(this_dir, "..", "weather", "*.epw")].count
    assert_equal(num_epws_expected, num_epws_actual)

    num_cache_expected = File.readlines(File.join(this_dir, "..", "weather", "data.csv")).size - 1
    num_cache_actual = Dir[File.join(this_dir, "..", "weather", "*.cache")].count
    assert_equal(num_cache_expected, num_cache_actual)
  end

  def test_valid_simulations
    results = {}
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), ".."))
    xmldir = "#{parent_dir}/sample_files"
    Dir["#{xmldir}/*.xml"].sort.each do |xml|
      results[File.basename(xml)] = run_and_check(xml, parent_dir, false)
    end

    _write_summary_results(parent_dir, results)
  end

  private

  def run_and_check(xml, parent_dir, expect_error)
    # Check input HPXML is valid
    xml = File.absolute_path(xml)

    # Run workflow
    cli_path = OpenStudio.getOpenStudioCLI
    command = "\"#{cli_path}\" --no-ssl \"#{File.join(File.dirname(__FILE__), "../run_simulation.rb")}\" -x #{xml}"
    start_time = Time.now
    system(command)
    runtime = Time.now - start_time

    results_json = File.join(parent_dir, "results", "results.json")
    results = nil
    if expect_error
      assert(!File.exists?(results_json))
    else
      # Check all output files exist
      hes_hpxml = File.join(parent_dir, "results", "HEScoreDesign.xml")
      assert(File.exists?(hes_hpxml))
      assert(File.exists?(results_json))

      # Check HPXMLs are valid
      schemas_dir = File.absolute_path(File.join(parent_dir, "..", "measures", "HEScoreRuleset", "hpxml_schemas"))
      _test_schema_validation(parent_dir, xml, schemas_dir)
      schemas_dir = File.absolute_path(File.join(parent_dir, "..", "measures", "HPXMLtoOpenStudio", "hpxml_schemas"))
      _test_schema_validation(parent_dir, hes_hpxml, schemas_dir)

      results = _get_results(parent_dir, runtime)
      _test_results(xml, results)
    end

    return results
  end

  def _get_results(parent_dir, runtime)
    json_path = File.join(parent_dir, "results", "results.json")
    data = JSON.parse(File.read(json_path))

    results = {}
    data["end_use"].each do |result|
      fuel = result["resource_type"]
      category = result["end_use"]
      units = result["units"]
      key = [fuel, category, units]
      if results[key].nil?
        results[key] = 0.0
      end
      results[key] += Float(result["quantity"]) # Just store annual results
    end
    results["Runtime"] = runtime

    return results
  end

  def _test_results(xml, results)
    hpxml_doc = REXML::Document.new(File.read(xml))

    fuel_map = { "electricity" => "electric",
                 "natural gas" => "natural_gas",
                 "fuel oil" => "fuel_oil",
                 "propane" => "lpg",
                 "wood" => "cord_wood",
                 "wood pellets" => "pellet_wood" }

    # Get HPXML values for Building Summary
    cfa = Float(XMLHelper.get_value(hpxml_doc, "/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedFloorArea"))
    nbr = Float(XMLHelper.get_value(hpxml_doc, "/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofBedrooms"))

    # Get HPXML values for HVAC
    hvac_plant = hpxml_doc.elements["/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant"]
    htg_fuels = []
    hvac_plant.elements.each("HeatingSystem[FractionHeatLoadServed>0]") do |htg_sys|
      htg_fuels << fuel_map[XMLHelper.get_value(htg_sys, "HeatingSystemFuel")]
    end
    hvac_plant.elements.each("HeatPump[FractionHeatLoadServed>0]") do |hp|
      htg_fuels << fuel_map["electricity"]
    end
    has_clg = !hvac_plant.elements["CoolingSystem[FractionCoolLoadServed>0] | HeatPump[FractionCoolLoadServed>0]"].nil?

    # Get HPXML values for Water Heating
    hw_fuels = []
    hpxml_doc.elements.each("/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem") do |hw_sys|
      hw_fuels << fuel_map[XMLHelper.get_value(hw_sys, "FuelType")]
    end

    # Get HPXML values for PV
    has_pv = !hpxml_doc.elements["/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem"].nil?

    tested_categories = []
    results.each do |key, value|
      fuel, category, units = key

      # Check lighting end use matches ERI calculation
      if category == "lighting" and fuel == "electric" and units == "kWh"
        eri_int_ltg = 455.0 + 0.80 * cfa
        eri_ext_ltg = 100.0 + 0.05 * cfa
        eri_ltg = eri_int_ltg + eri_ext_ltg
        assert_in_epsilon(eri_ltg, value, 0.01)
        tested_categories << category
      end

      # Check large_appliance end use matches ERI calculation
      if category == "large_appliance" and fuel == "electric" and units == "kWh"
        eri_fridge = 637.0 + 18.0 * nbr
        eri_range_oven = 331.0 + 39.0 * nbr
        eri_clothes_dryer = 524.0 + 149.0 * nbr
        eri_clothes_washer = 38.0 + 10.0 * nbr
        eri_dishwasher = 78.0 + 31.0 * nbr
        eri_large_appl = eri_fridge + eri_range_oven + eri_clothes_dryer + eri_clothes_washer + eri_dishwasher
        assert_in_epsilon(eri_large_appl, value, 0.01)
        tested_categories << category
      end

      # Check small_appliance end use matches ERI calculation
      if category == "small_appliance" and fuel == "electric" and units == "kWh"
        eri_mels = 0.91 * cfa
        eri_tv = 413.0 + 69.0 * nbr
        eri_small_appl = eri_mels + eri_tv
        assert_in_epsilon(eri_small_appl, value, 0.01)
        tested_categories << category
      end

      # Check heating end use by fuel reflects presence of system
      if category == "heating"
        if xml.include? "sample_files/Location_CZ09_hpxml.xml"
          # skip test: hot climate so potentially no heating energy
        elsif htg_fuels.include? fuel
          assert_operator(value, :>, 0)
        else
          assert_equal(0, value)
        end
        tested_categories << category
      end

      # Check cooling end use reflects presence of cooling system
      if category == "cooling" and fuel == "electric"
        if has_clg
          assert_operator(value, :>, 0)
        else
          assert_equal(0, value)
        end
        tested_categories << category
      end

      # Check hot_water end use by fuel reflects presence of system
      if category == "hot_water"
        if hw_fuels.include? fuel
          assert_operator(value, :>, 0)
        else
          assert_equal(0, value)
        end
        tested_categories << category
      end

      # Check generation end use reflects presence of PV system
      if category == "generation" and fuel == "electric"
        if has_pv
          assert_operator(value, :>, 0)
        else
          assert_equal(0, value)
        end
        tested_categories << category
      end
    end

    # Check we actually tested the right number of categories
    assert_equal(tested_categories.uniq.size, 7)
  end

  def _write_summary_results(parent_dir, results)
    csv_out = File.join(parent_dir, 'test_results', 'results.csv')
    _rm_path(File.dirname(csv_out))
    Dir.mkdir(File.dirname(csv_out))

    column_headers = ['HPXML']
    results[results.keys[0]].keys.each do |key|
      next if not key.is_a? Array

      column_headers << "#{key[0]}: #{key[1]} [#{key[2]}]"
    end

    # Append runtime at the end
    column_headers << "Runtime [s]"

    require 'csv'
    CSV.open(csv_out, 'w') do |csv|
      csv << column_headers
      results.each do |xml, xml_results|
        csv << [xml] + xml_results.values
      end
    end

    puts "Wrote results to #{csv_out}."
  end

  def _test_schema_validation(parent_dir, xml, schemas_dir)
    # TODO: Remove this when schema validation is included with CLI calls
    hpxml_doc = REXML::Document.new(File.read(xml))
    errors = XMLHelper.validate(hpxml_doc.to_s, File.join(schemas_dir, "HPXML.xsd"), nil)
    if errors.size > 0
      puts "#{xml}: #{errors.to_s}"
    end
    assert_equal(0, errors.size)
  end

  def _rm_path(path)
    if Dir.exists?(path)
      FileUtils.rm_r(path)
    end
    while true
      break if not Dir.exists?(path)

      sleep(0.01)
    end
  end
end
