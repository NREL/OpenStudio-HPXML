require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require_relative '../../measures/HPXMLtoOpenStudio/measure'
require_relative '../../measures/HPXMLtoOpenStudio/resources/xmlhelper'
require_relative '../../measures/HPXMLtoOpenStudio/resources/schedules'
require_relative '../../measures/HPXMLtoOpenStudio/resources/constants'
require_relative '../../measures/HPXMLtoOpenStudio/resources/unit_conversions'
require_relative '../../measures/HPXMLtoOpenStudio/resources/hotwater_appliances'

class EnergyRatingIndexTest < Minitest::Unit::TestCase
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

    # Run energy_rating_index workflow
    cli_path = OpenStudio.getOpenStudioCLI
    command = "\"#{cli_path}\" --no-ssl \"#{File.join(File.dirname(__FILE__), "../run_simulation.rb")}\" -s -x #{xml}"
    start_time = Time.now
    system(command)
    runtime = Time.now - start_time

    results_csv = File.join(parent_dir, "results", "Results.csv")
    if expect_error
      assert(!File.exists?(results_csv))
    else
      # Check all output files exist
      hes_hpxml = File.join(parent_dir, "results", "HEScoreDesign.xml")
      assert(File.exists?(hes_hpxml))
      # assert(File.exists?(results_csv))

      # Check HPXMLs are valid
      schemas_dir = File.absolute_path(File.join(parent_dir, "..", "measures", "HEScoreRuleset", "hpxml_schemas"))
      _test_schema_validation(parent_dir, xml, schemas_dir)
      schemas_dir = File.absolute_path(File.join(parent_dir, "..", "measures", "HPXMLtoOpenStudio", "hpxml_schemas"))
      _test_schema_validation(parent_dir, hes_hpxml, schemas_dir)
    end

    return _get_results(parent_dir, runtime)
  end

  def _get_results(parent_dir, runtime)
    sql_path = File.join(parent_dir, "HEScoreDesign", "run", "eplusout.sql")
    sqlFile = OpenStudio::SqlFile.new(sql_path, false)
    enduses = sqlFile.endUses.get
    results = {}
    OpenStudio::EndUses.fuelTypes.each do |fueltype|
      units = OpenStudio::EndUses.getUnitsForFuelType(fueltype)
      OpenStudio::EndUses.categories.each do |category|
        results[[fueltype.valueName, category.valueName, units]] = enduses.getEndUse(fueltype, category)
      end
    end

    sqlFile.close

    results["Runtime"] = runtime

    return results
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
    column_headers << "Runtime"

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
