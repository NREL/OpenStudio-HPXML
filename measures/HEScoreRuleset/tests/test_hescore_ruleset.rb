require_relative '../../HPXMLtoOpenStudio/tests/minitest_helper'
require_relative '../../HPXMLtoOpenStudio/resources/xmlhelper.rb'
require_relative '../resources/HESruleset.rb'
require_relative '../../HPXMLtoOpenStudio/resources/hpxml.rb'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
require 'rexml/xpath'

class HEScoreRulesetTest < MiniTest::Test
  def test_valid_simulations
    this_dir = File.dirname(__FILE__)

    args_hash = {}

    Dir["#{this_dir}/../../../workflow/sample_files/*.xml"].sort.each do |xml|
      puts "Testing #{File.absolute_path(xml)}..."

      args_hash['hpxml_path'] = File.absolute_path(xml)
      args_hash['hpxml_output_path'] = File.absolute_path(xml).gsub('.xml', '.xml.out')

      _test_schema_validation(this_dir, xml)
      _test_measure(args_hash)
      _test_schema_validation(this_dir, xml.gsub('.xml', '.xml.out'))
      _test_assembly_efective_rvalues(args_hash)

      FileUtils.rm_f(args_hash['hpxml_output_path']) # Cleanup
    end
  end

  def test_neighbors
    this_dir = File.dirname(__FILE__)
    xml = File.absolute_path("#{this_dir}/../../../workflow/sample_files/Base_hpxml.xml")

    args_hash = {
      "hpxml_path" => xml,
      "hpxml_output_path" => xml.gsub('.xml', '.xml.out')
    }

    _test_measure(args_hash)

    hpxml_doc = XMLHelper.parse_file(args_hash["hpxml_output_path"])

    hpxml_doc.elements.each("HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding") do |neighbor_building|
      neighbor_values = HPXML.get_neighbor_building_values(neighbor_building: neighbor_building)
      assert_in_epsilon(neighbor_values[:distance], 20.0, 0.000001)
      assert([90, 270].include?(neighbor_values[:azimuth]))
      assert_in_epsilon(neighbor_values[:height], 12.0, 0.000001)
    end
  end

  def test_infiltration
    # Tests from ResDB.Infiltration.Model.v2.xlsx

    # Version 1, Test #1
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = "average"
    year_built = 1975
    iecc_cz = "3B"
    fnd_types = { "living space" => 1000.0 }
    ducts = [[1.0, 1.0, "attic - unconditioned"]]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(9.7, ach50, 0.01)

    # Version 1, Test #2
    cfa = 1000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = "average"
    year_built = 1975
    iecc_cz = "3B"
    fnd_types = { "living space" => 1000.0 }
    ducts = [[1.0, 1.0, "attic - unconditioned"]]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(11.8, ach50, 0.01)

    # Version 1, Test #3
    cfa = 2000.0
    ncfl_ag = 1
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = "average"
    year_built = 1975
    iecc_cz = "3B"
    fnd_types = { "living space" => 2000.0 }
    ducts = [[1.0, 1.0, "attic - unconditioned"]]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(10.2, ach50, 0.01)

    # Version 1, Test #4
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 12.0
    cvolume = cfa * ceil_height
    desc = "average"
    year_built = 1975
    iecc_cz = "3B"
    fnd_types = { "living space" => 1000.0 }
    ducts = [[1.0, 1.0, "attic - unconditioned"]]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(7.6, ach50, 0.01)

    # Version 1, Test #5
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = "average"
    year_built = 2013
    iecc_cz = "3B"
    fnd_types = { "living space" => 1000.0 }
    ducts = [[1.0, 1.0, "attic - unconditioned"]]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(5.3, ach50, 0.01)

    # Version 1, Test #6
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = "average"
    year_built = 1975
    iecc_cz = "4C"
    fnd_types = { "living space" => 1000.0 }
    ducts = [[1.0, 1.0, "attic - unconditioned"]]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(13.1, ach50, 0.01)

    # Version 1, Test #7
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = "average"
    year_built = 1975
    iecc_cz = "3B"
    fnd_types = { "basement - conditioned" => 1000.0 }
    ducts = [[1.0, 1.0, "attic - unconditioned"]]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(11.2, ach50, 0.01)

    # Version 1, Test #8
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = "average"
    year_built = 1975
    iecc_cz = "3B"
    fnd_types = { "living space" => 1000.0 }
    ducts = [[1.0, 1.0, "living space"]]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(8.0, ach50, 0.01)

    # Version 1, Test #9
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = "tight"
    year_built = 1975
    iecc_cz = "3B"
    fnd_types = { "living space" => 1000.0 }
    ducts = [[1.0, 1.0, "attic - unconditioned"]]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(7.3, ach50, 0.01)

    # Version 2, Test #1
    cfa = 2000.0
    ncfl_ag = 2
    ceil_height = 8.0
    cvolume = cfa * ceil_height
    desc = "average"
    year_built = 1975
    iecc_cz = "3B"
    fnd_types = { "living space" => 600.0,
                  "basement - conditioned" => 400.0 }
    ducts = [[0.75, 0.5, "attic - unconditioned"],
             [0.75, 0.25, "living space"],
             [0.75, 0.25, "crawlspace - vented"],
             [0.25, 0.5, "crawlspace - unvented"],
             [0.25, 0.3, "attic - unconditioned"],
             [0.25, 0.2, "crawlspace - vented"]]
    ach50 = calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
    assert_in_epsilon(10.2, ach50, 0.01)
  end

  def test_foundation_area_lookup
    this_dir = File.dirname(__FILE__)
    xml = File.absolute_path("#{this_dir}/../../../workflow/sample_files/Floor2_conditioned_basement_hpxml.xml")
    hpxml_doc = XMLHelper.parse_file(xml)
    hpxml = hpxml_doc.root
    slab_foundation = hpxml.elements['//Foundation[1]']
    slab_area = get_foundation_area(slab_foundation)
    assert_in_epsilon(slab_area, 600.0, 0.01)
    basement_foundation = hpxml.elements['//Foundation[2]']
    basement_area = get_foundation_area(basement_foundation)
    assert_in_epsilon(basement_area, 400.0, 0.01)
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
    # show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
  end

  def _test_schema_validation(parent_dir, xml)
    # TODO: Remove this when schema validation is included with CLI calls
    schemas_dir = File.absolute_path(File.join(parent_dir, "..", "..", "HPXMLtoOpenStudio", "hpxml_schemas"))
    hpxml_doc = REXML::Document.new(File.read(xml))
    errors = XMLHelper.validate(hpxml_doc.to_s, File.join(schemas_dir, "HPXML.xsd"), nil)
    if errors.size > 0
      puts "#{xml}: #{errors.to_s}"
    end
    assert_equal(0, errors.size)
  end

  def _test_assembly_efective_rvalues(args_hash)
    in_doc = REXML::Document.new(File.read(args_hash['hpxml_path']))
    out_doc = REXML::Document.new(File.read(args_hash['hpxml_output_path']))

    wall_code_by_id = {}
    in_doc.elements.each("HPXML/Building/BuildingDetails/Enclosure/Walls/Wall") do |wall|
      wall_code = XMLHelper.get_value(wall, "extension/hescore_wall_code")
      wallid = wall.elements["SystemIdentifier"].attribute('id').value
      wall_code_by_id[wallid] = wall_code
    end

    out_doc.elements.each("HPXML/Building/BuildingDetails/Enclosure/Walls/Wall") do |wall|
      eff_rvalue = Float(XMLHelper.get_value(wall, "Insulation/AssemblyEffectiveRValue"))
      wallid = wall.elements["SystemIdentifier"].attribute('id').value
      next if wall_code_by_id[wallid].nil?

      assert_in_epsilon(eff_rvalue, get_wall_effective_r_from_doe2code(wall_code_by_id[wallid]), 0.01)
    end

    roof_code_by_id = {}
    in_doc.elements.each("HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof") do |roof|
      roofid = roof.elements["SystemIdentifier"].attribute('id').value
      roof_code_by_id[roofid] = XMLHelper.get_value(roof, "extension/roof_assembly_code")
    end

    out_doc.elements.each("HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof") do |roof|
      roofid = roof.elements["SystemIdentifier"].attribute('id').value
      eff_rvalue = Float(XMLHelper.get_value(roof, "Insulation/AssemblyEffectiveRValue"))
      assert_in_epsilon(eff_rvalue, get_roof_effective_r_from_doe2code(roof_code_by_id[roofid.split('_')[0]]), 0.01)
    end
  end
end
