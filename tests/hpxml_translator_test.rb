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

  def test_multiple_hvac
    # Run HPXML files with 3 of the same HVAC system and compare results to files
    # with one of that HVAC system.
    this_dir = File.dirname(__FILE__)

    args_hash = {}
    args_hash['weather_dir'] = File.absolute_path(File.join(this_dir, "..", "weather"))
    args_hash['epw_output_path'] = File.absolute_path(File.join(this_dir, "in.epw"))
    args_hash['osm_output_path'] = File.absolute_path(File.join(this_dir, "in.osm"))

    Dir["#{this_dir}/multiple_hvac/valid*.xml"].sort.each do |xml|
      puts "Testing #{xml}..."
      args_hash['hpxml_path'] = File.absolute_path(xml)
      _test_schema_validation(this_dir, xml)
      _test_measure(args_hash)
      _test_simulation(args_hash, this_dir)
      results_x3 = _get_results(this_dir)

      # Run complementary file with single HVAC
      xml_x1 = xml.gsub("-x3", "")
      puts "Testing #{xml_x1}..."
      args_hash['hpxml_path'] = File.absolute_path(File.join(File.dirname(xml_x1), "..", File.basename(xml_x1)))
      _test_schema_validation(this_dir, xml)
      _test_measure(args_hash)
      _test_simulation(args_hash, this_dir)
      results_x1 = _get_results(this_dir)

      # Compare results
      puts "\nResults for #{xml}:"
      results_x1.keys.each do |k|
        result_x1 = results_x1[k].to_f
        result_x3 = results_x3[k].to_f
        next if result_x1 == 0.0 and result_x3 == 0.0

        puts "x1, x3: #{result_x1.round(2)}, #{result_x3.round(2)} #{k}"
        assert_in_delta(result_x1, result_x3, 0.1)
      end
      puts "\n"
    end
  end

  def _get_results(this_dir)
    sql_path = File.join(this_dir, "run", "eplusout.sql")
    sqlFile = OpenStudio::SqlFile.new(sql_path, false)
    begin
      enduses = sqlFile.endUses.get
      results = {}
      OpenStudio::EndUses.fuelTypes.each do |fueltype|
        OpenStudio::EndUses.categories.each do |category|
          results[[fueltype.valueName, category.valueName]] = enduses.getEndUse(fueltype, category)
        end
      end
    ensure
      sqlFile.close
    end
    return results
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
    if result.value.valueName != "Success"
      show_output(result)
    end

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

    bldg_details = hpxml_doc.elements['/HPXML/Building/BuildingDetails']

    # Conditioned Floor Area
    if XMLHelper.has_element(bldg_details, "Systems/HVAC") # EnergyPlus will only report conditioned floor area if there is an HVAC system
      hpxml_value = Float(XMLHelper.get_value(bldg_details, 'BuildingSummary/BuildingConstruction/ConditionedFloorArea'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='InputVerificationandResultsSummary' AND ReportForString='Entire Facility' AND TableName='Zone Summary' AND RowName='Conditioned Total' AND ColumnName='Area' AND Units='m2'"
      sql_value = UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end

    # Enclosure Roofs
    bldg_details.elements.each('Enclosure/AtticAndRoof/Attics/Attic/Roofs/Roof') do |roof|
      roof_id = roof.elements["SystemIdentifier"].attributes["id"].upcase

      # R-value
      hpxml_value = Float(XMLHelper.get_value(roof, 'Insulation/AssemblyEffectiveRValue'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{roof_id}' AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
      sql_value = 1.0 / UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.07) # TODO: Higher due to outside air film?

      # Net area
      hpxml_value = Float(XMLHelper.get_value(roof, 'Area'))
      bldg_details.elements.each('Enclosure/Skylights/Skylight') do |subsurface|
        next if subsurface.elements["AttachedToRoof"].attributes["idref"].upcase != roof_id

        hpxml_value -= Float(XMLHelper.get_value(subsurface, 'Area'))
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{roof_id}' AND ColumnName='Net Area' AND Units='m2'"
      sql_value = UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Solar absorptance
      hpxml_value = Float(XMLHelper.get_value(roof, 'SolarAbsorptance'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{roof_id}' AND ColumnName='Reflectance'"
      sql_value = 1.0 - _get_sql_query_result(sqlFile, query)
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Tilt
      hpxml_value = UnitConversions.convert(Math.atan(Float(XMLHelper.get_value(roof, "Pitch")) / 12.0), "rad", "deg")
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{roof_id}' AND ColumnName='Tilt' AND Units='deg'"
      sql_value = _get_sql_query_result(sqlFile, query)
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end

    # Enclosure Foundation Slabs
    bldg_details.elements.each('Enclosure/Foundations/Foundation/Slab') do |slab|
      slab_id = slab.elements["SystemIdentifier"].attributes["id"].upcase

      # Area
      hpxml_value = Float(XMLHelper.get_value(slab, 'Area'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{slab_id}' AND ColumnName='Gross Area' AND Units='m2'"
      sql_value = UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Tilt
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{slab_id}' AND ColumnName='Tilt' AND Units='deg'"
      sql_value = _get_sql_query_result(sqlFile, query)
      assert_in_epsilon(180.0, sql_value, 0.01)
    end

    # Enclosure Walls
    bldg_details.elements.each('Enclosure/Walls/Wall[extension[ExteriorAdjacentTo="ambient"]] | Enclosure/AtticAndRoof/Attics/Attic/Walls/Wall[extension[ExteriorAdjacentTo="ambient"]]') do |wall|
      wall_id = wall.elements["SystemIdentifier"].attributes["id"].upcase

      # R-value
      hpxml_value = Float(XMLHelper.get_value(wall, 'Insulation/AssemblyEffectiveRValue'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
      sql_value = 1.0 / UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.03)

      # Net area
      hpxml_value = Float(XMLHelper.get_value(wall, 'Area'))
      bldg_details.elements.each('Enclosure/Windows/Window | Enclosure/Doors/Door') do |subsurface|
        next if subsurface.elements["AttachedToWall"].attributes["idref"].upcase != wall_id

        hpxml_value -= Float(XMLHelper.get_value(subsurface, 'Area'))
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='Net Area' AND Units='m2'"
      sql_value = UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Solar absorptance
      hpxml_value = Float(XMLHelper.get_value(wall, 'SolarAbsorptance'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='Reflectance'"
      sql_value = 1.0 - _get_sql_query_result(sqlFile, query)
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Tilt
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='Tilt' AND Units='deg'"
      sql_value = _get_sql_query_result(sqlFile, query)
      assert_in_epsilon(90.0, sql_value, 0.01)
    end

    # Enclosure Windows/Skylights
    bldg_details.elements.each('Enclosure/Windows/Window | Enclosure/Skylights/Skylight') do |subsurface|
      subsurface_id = subsurface.elements["SystemIdentifier"].attributes["id"].upcase

      # Area
      hpxml_value = Float(XMLHelper.get_value(subsurface, 'Area'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Fenestration' AND RowName='#{subsurface_id}' AND ColumnName='Area of Multiplied Openings' AND Units='m2'"
      sql_value = UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # U-Factor
      hpxml_value = Float(XMLHelper.get_value(subsurface, 'UFactor'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Fenestration' AND RowName='#{subsurface_id}' AND ColumnName='Glass U-Factor' AND Units='W/m2-K'"
      sql_value = UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # SHGC
      # TODO: Affected by interior shading

      # Azimuth
      hpxml_value = Float(XMLHelper.get_value(subsurface, 'Azimuth'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Fenestration' AND RowName='#{subsurface_id}' AND ColumnName='Azimuth' AND Units='deg'"
      sql_value = _get_sql_query_result(sqlFile, query)
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Tilt
      if XMLHelper.has_element(subsurface, "AttachedToWall")
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Fenestration' AND RowName='#{subsurface_id}' AND ColumnName='Tilt' AND Units='deg'"
        sql_value = _get_sql_query_result(sqlFile, query)
        assert_in_epsilon(90.0, sql_value, 0.01)
      elsif XMLHelper.has_element(subsurface, "AttachedToRoof")
        hpxml_value = nil
        bldg_details.elements.each('Enclosure/AtticAndRoof/Attics/Attic/Roofs/Roof') do |roof|
          next if roof.elements["SystemIdentifier"].attributes["id"] != subsurface.elements["AttachedToRoof"].attributes["idref"]

          hpxml_value = UnitConversions.convert(Math.atan(Float(XMLHelper.get_value(roof, "Pitch")) / 12.0), "rad", "deg")
        end
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Fenestration' AND RowName='#{subsurface_id}' AND ColumnName='Tilt' AND Units='deg'"
        sql_value = _get_sql_query_result(sqlFile, query)
        assert_in_epsilon(hpxml_value, sql_value, 0.01)
      else
        flunk "Subsurface '#{subsurface_id}' should have either AttachedToWall or AttachedToRoof element."
      end
    end

    # Enclosure Doors
    bldg_details.elements.each('Enclosure/Doors/Door') do |door|
      door_id = door.elements["SystemIdentifier"].attributes["id"].upcase

      # Area
      hpxml_value = Float(XMLHelper.get_value(door, 'Area'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Door' AND RowName='#{door_id}' AND ColumnName='Gross Area' AND Units='m2'"
      sql_value = UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # R-Value
      hpxml_value = Float(XMLHelper.get_value(door, 'RValue'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Door' AND RowName='#{door_id}' AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
      sql_value = 1.0 / UnitConversions.convert(_get_sql_query_result(sqlFile, query), 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
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
