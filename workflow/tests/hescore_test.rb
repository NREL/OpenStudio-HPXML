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
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), ".."))
    xmldir = "#{parent_dir}/sample_files"
    Dir["#{xmldir}/*.xml"].sort.each do |xml|
      run_and_check(xml, parent_dir, false)
    end
  end

  private

  def run_and_check(xml, parent_dir, expect_error)
    # Check input HPXML is valid
    xml = File.absolute_path(xml)

    # Run energy_rating_index workflow
    cli_path = OpenStudio.getOpenStudioCLI
    command = "\"#{cli_path}\" --no-ssl \"#{File.join(File.dirname(__FILE__), "../run_simulation.rb")}\" -x #{xml}"
    system(command)

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
end
