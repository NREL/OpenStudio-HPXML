require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
require 'json'
require 'rexml/document'
require 'rexml/xpath'
require_relative '../resources/unit_conversions'
require_relative '../resources/xmlhelper'

class HPXMLTranslatorTest < MiniTest::Test
  def test_valid_simulations
    this_dir = File.dirname(__FILE__)

    args_hash = {}
    args_hash['weather_dir'] = File.absolute_path(File.join(this_dir, "..", "weather"))
    args_hash['epw_output_path'] = File.absolute_path(File.join(this_dir, "in.epw"))
    args_hash['osm_output_path'] = File.absolute_path(File.join(this_dir, "in.osm"))

    Dir["#{this_dir}/valid*.xml"].sort.each do |xml|
      puts "Testing #{xml}..."
      args_hash['hpxml_path'] = File.absolute_path(xml)
      _test_schema_validation(this_dir, xml)
      _test_measure(args_hash)
      _test_simulation(args_hash, this_dir)
    end
  end

  def _test_measure(args_hash)
    # create an instance of the measure
    measure = HPXMLTranslator.new

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
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
  end

  def _test_simulation(args_hash, this_dir)
    # Get EPW path
    hpxml_doc = REXML::Document.new(File.read(args_hash['hpxml_path']))
    weather_wmo = XMLHelper.get_value(hpxml_doc, "/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/WMO")
    epw_path = nil
    CSV.foreach(File.join(args_hash['weather_dir'], "data.csv"), headers: true) do |row|
      next if row["wmo"] != weather_wmo

      epw_path = File.absolute_path(File.join(args_hash['weather_dir'], row["filename"]))
      break
    end
    refute_nil(epw_path)

    # Create osw
    osw_path = File.join(this_dir, "in.osw")
    workflow = OpenStudio::WorkflowJSON.new
    workflow.setWeatherFile(epw_path)
    measure_path = File.absolute_path(File.join(this_dir, "..", ".."))
    workflow.addMeasurePath(measure_path)
    steps = OpenStudio::WorkflowStepVector.new
    step = OpenStudio::MeasureStep.new(File.absolute_path(File.join(this_dir, "..")).split('/')[-1])
    args_hash.each do |arg, val|
      step.setArgument(arg, val)
    end
    steps.push(step)
    workflow.setWorkflowSteps(steps)
    workflow.saveAs(osw_path)

    cli_path = OpenStudio.getOpenStudioCLI
    cmd = "\"#{cli_path}\" --no-ssl run -w \"#{osw_path}\""
    puts "Running command: #{cmd}"
    system(cmd)

    # Ensure success
    out_osw = File.join(this_dir, "out.osw")
    assert(File.exists?(out_osw))

    data_hash = JSON.parse(File.read(out_osw))
    assert_equal("Success", data_hash["completed_status"])

    # Verify simulation outputs
    _verify_simulation_outputs(this_dir, args_hash['hpxml_path'])
  end

  def _get_sql_query_result(sqlFile, query)
    result = sqlFile.execAndReturnFirstDouble(query)
    assert(result.is_initialized)
    return result.get
  end

  def _verify_simulation_outputs(this_dir, hpxml_path)
    sql_path = File.join(this_dir, "run", "eplusout.sql")

    sqlFile = OpenStudio::SqlFile.new(sql_path, false)
    hpxml_doc = REXML::Document.new(File.read(hpxml_path))

    # Exterior above-grade wall construction
    hpxml_doc.elements.each('/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall[extension[ExteriorAdjacentTo="ambient"]]') do |wall|
      wall_id = wall.elements["SystemIdentifier"].attributes["id"].upcase

      # R-value
      hpxml_value = Float(XMLHelper.get_value(wall, 'Insulation/AssemblyEffectiveRValue'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
      sql_value = 1.0 / UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.03)

      # Net area
      hpxml_value = Float(XMLHelper.get_value(wall, 'Area'))
      hpxml_doc.elements.each('/HPXML/Building/BuildingDetails/Enclosure/Windows/Window | /HPXML/Building/BuildingDetails/Enclosure/Doors/Door') do |subsystem|
        next if subsystem.elements["AttachedToWall"].attributes["idref"].upcase != wall_id

        hpxml_value -= Float(XMLHelper.get_value(subsystem, 'Area'))
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='Net Area' AND Units='m2'"
      sql_value = UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end

    # Exterior attic wall construction
    hpxml_doc.elements.each('/HPXML/Building/BuildingDetails/Enclosure/AtticAndRoof/Attics/Attic/Walls/Wall[extension[ExteriorAdjacentTo="ambient"]]') do |wall|
      wall_id = wall.elements["SystemIdentifier"].attributes["id"].upcase

      # R-value
      hpxml_value = Float(XMLHelper.get_value(wall, 'Insulation/AssemblyEffectiveRValue'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
      sql_value = 1.0 / UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.03)

      # Net area
      hpxml_value = Float(XMLHelper.get_value(wall, 'Area'))
      hpxml_doc.elements.each('/HPXML/Building/BuildingDetails/Enclosure/Windows/Window | /HPXML/Building/BuildingDetails/Enclosure/Doors/Door') do |subsystem|
        next if subsystem.elements["AttachedToWall"].attributes["idref"].upcase != wall_id

        hpxml_value -= Float(XMLHelper.get_value(subsystem, 'Area'))
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='Net Area' AND Units='m2'"
      sql_value = UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end
  end

  def _test_schema_validation(parent_dir, xml)
    # TODO: Remove this when schema validation is included with CLI calls
    schemas_dir = File.absolute_path(File.join(parent_dir, "..", "hpxml_schemas"))
    hpxml_doc = REXML::Document.new(File.read(xml))
    errors = XMLHelper.validate(hpxml_doc.to_s, File.join(schemas_dir, "HPXML.xsd"), nil)
    if errors.size > 0
      puts "#{xml}: #{errors.to_s}"
    end
    assert_equal(0, errors.size)
  end
end
