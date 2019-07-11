require_relative 'minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
require 'rexml/document'
require 'rexml/xpath'
require_relative '../resources/constants'
require_relative '../resources/meta_measure'
require_relative '../resources/unit_conversions'
require_relative '../resources/xmlhelper'

class HPXMLTranslatorTest < MiniTest::Test
  def test_simulations
    OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Error)
    # OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Fatal)

    this_dir = File.dirname(__FILE__)
    results_dir = File.join(this_dir, "results")
    _rm_path(results_dir)

    args = {}
    args['weather_dir'] = File.absolute_path(File.join(this_dir, "..", "weather"))
    args['skip_validation'] = false

    @simulation_runtime_key = "Simulation Runtime"
    @workflow_runtime_key = "Workflow Runtime"

    cfis_dir = File.absolute_path(File.join(this_dir, "cfis"))
    hvac_base_dir = File.absolute_path(File.join(this_dir, "hvac_base"))
    hvac_dse_dir = File.absolute_path(File.join(this_dir, "hvac_dse"))
    hvac_multiple_dir = File.absolute_path(File.join(this_dir, "hvac_multiple"))
    hvac_partial_dir = File.absolute_path(File.join(this_dir, "hvac_partial"))
    hvac_load_fracs_dir = File.absolute_path(File.join(this_dir, "hvac_load_fracs"))
    water_heating_multiple_dir = File.absolute_path(File.join(this_dir, "water_heating_multiple"))
    autosize_dir = File.absolute_path(File.join(this_dir, "hvac_autosizing"))

    test_dirs = [this_dir,
                 cfis_dir,
                 hvac_base_dir,
                 hvac_dse_dir,
                 hvac_multiple_dir,
                 hvac_partial_dir,
                 hvac_load_fracs_dir,
                 water_heating_multiple_dir,
                 autosize_dir]

    xmls = []
    test_dirs.each do |test_dir|
      Dir["#{test_dir}/base*.xml"].sort.each do |xml|
        xmls << File.absolute_path(xml)
      end
    end

    # Test simulations
    puts "Running #{xmls.size} HPXML files..."
    all_results = {}
    xmls.each do |xml|
      all_results[xml] = _run_xml(xml, this_dir, args.dup)
    end

    _write_summary_results(results_dir, all_results)

    # Cross simulation tests
    _test_dse(xmls, hvac_dse_dir, hvac_base_dir, all_results)
    _test_multiple_hvac(xmls, hvac_multiple_dir, hvac_base_dir, all_results)
    _test_multiple_water_heaters(xmls, water_heating_multiple_dir, all_results)
    _test_partial_hvac(xmls, hvac_partial_dir, hvac_base_dir, all_results)
  end

  def test_invalid
    this_dir = File.dirname(__FILE__)

    args = {}
    args['weather_dir'] = File.absolute_path(File.join(this_dir, "..", "weather"))
    args['skip_validation'] = false

    expected_error_msgs = { 'bad-wmo.xml' => ["Weather station WMO '999999' could not be found in weather/data.csv."],
                            'bad-site-neighbor-azimuth.xml' => ["A neighbor building has an azimuth (145) not equal to the azimuth of any wall."],
                            'cfis-with-hydronic-distribution.xml' => ["Attached HVAC distribution system 'HVACDistribution' cannot be hydronic for mechanical ventilation 'MechanicalVentilation'."],
                            'clothes-dryer-location.xml' => ["ClothesDryer location is 'garage' but building does not have this location specified."],
                            'clothes-dryer-location-other.xml' => ["Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Appliances/ClothesDryer[Location="],
                            'clothes-washer-location.xml' => ["ClothesWasher location is 'garage' but building does not have this location specified."],
                            'clothes-washer-location-other.xml' => ["Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Appliances/ClothesWasher[Location="],
                            'dhw-frac-load-served.xml' => ["Expected FractionDHWLoadServed to sum to 1, but calculated sum is 1.15."],
                            'duct-location.xml' => ["Duct location is 'garage' but building does not have this location specified."],
                            'duct-location-other.xml' => ["Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts[DuctType='supply' or DuctType='return'][DuctLocation="],
                            'hvac-distribution-multiple-attached-cooling.xml' => ["Multiple cooling systems found attached to distribution system 'HVACDistribution4'."],
                            'hvac-distribution-multiple-attached-heating.xml' => ["Multiple heating systems found attached to distribution system 'HVACDistribution3'."],
                            'hvac-frac-load-served.xml' => ["Expected FractionCoolLoadServed to sum to <= 1, but calculated sum is 1.2.",
                                                            "Expected FractionHeatLoadServed to sum to <= 1, but calculated sum is 1.1."],
                            'missing-elements.xml' => ["Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloors",
                                                       "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedFloorArea"],
                            'missing-surfaces.xml' => ["Thermal zone 'garage' must have at least two floor/roof/ceiling surfaces."],
                            'net-area-negative-wall.xml' => ["Calculated a negative net surface area for Wall 'Wall'."],
                            'net-area-negative-roof.xml' => ["Calculated a negative net surface area for Roof 'Roof'."],
                            'refrigerator-location.xml' => ["Refrigerator location is 'garage' but building does not have this location specified."],
                            'refrigerator-location-other.xml' => ["Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Appliances/Refrigerator[Location="],
                            'unattached-cfis.xml' => ["Attached HVAC distribution system 'foobar' not found for mechanical ventilation 'MechanicalVentilation'."],
                            'unattached-door.xml' => ["Attached wall 'foobar' not found for door 'DoorNorth'."],
                            'unattached-hvac-distribution.xml' => ["Attached HVAC distribution system 'foobar' cannot be found for HVAC system 'HeatingSystem'."],
                            'unattached-skylight.xml' => ["Attached roof 'foobar' not found for skylight 'SkylightNorth'."],
                            'unattached-window.xml' => ["Attached wall 'foobar' not found for window 'WindowNorth'."],
                            'water-heater-location.xml' => ["WaterHeatingSystem location is 'crawlspace - vented' but building does not have this location specified."],
                            'water-heater-location-other.xml' => ["Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[Location="],
                            'invalid-idref-dhw-indirect.xml' => ["RelatedHVACSystem 'HeatingSystem-bad' not found for water heating system 'WaterHeater'"],
                            'two-repeating-idref-dhw-indirect.xml' => ["RelatedHVACSystem 'HeatingSystem' for water heating system 'WaterHeater2' is already attached to another water heating system."] }

    # Test simulations
    Dir["#{this_dir}/invalid_files/*.xml"].sort.each do |xml|
      _run_xml(File.absolute_path(xml), this_dir, args.dup, true, expected_error_msgs[File.basename(xml)])
    end
  end

  def test_generalized_hvac
    # single-speed air conditioner
    seer_to_expected_eer = { 13 => 11.2, 14 => 12.1, 15 => 13.0, 16 => 13.6 }
    seer_to_expected_eer.each do |seer, expected_eer|
      fan_power_rated = HVAC.get_fan_power_rated(seer)
      actual_eer = HVAC.calc_EER_cooling_1spd(seer, fan_power_rated, HVAC.cOOL_EIR_FT_SPEC_AC)
      assert_in_epsilon(expected_eer, actual_eer, 0.01)
    end

    # single-speed air source heat pump
    hspf_to_seer = { 7.7 => 13, 8.2 => 14, 8.5 => 15 }
    seer_to_expected_eer = { 13 => 11.31, 14 => 12.21, 15 => 13.12 }
    seer_to_expected_eer.each do |seer, expected_eer|
      fan_power_rated = HVAC.get_fan_power_rated(seer)
      actual_eer = HVAC.calc_EER_cooling_1spd(seer, fan_power_rated, HVAC.cOOL_EIR_FT_SPEC_ASHP)
      assert_in_epsilon(expected_eer, actual_eer, 0.01)
    end
    hspf_to_expected_cop = { 7.7 => 3.09, 8.2 => 3.35, 8.5 => 3.51 }
    hspf_to_expected_cop.each do |hspf, expected_cop|
      fan_power_rated = HVAC.get_fan_power_rated(hspf_to_seer[hspf])
      actual_cop = HVAC.calc_COP_heating_1spd(hspf, HVAC.get_c_d_heating(1, hspf), fan_power_rated, HVAC.hEAT_EIR_FT_SPEC_ASHP, HVAC.hEAT_CAP_FT_SPEC_ASHP)
      assert_in_epsilon(expected_cop, actual_cop, 0.01)
    end

    # two-speed air conditioner
    seer_to_expected_eers = { 16 => [13.8, 12.7], 17 => [14.7, 13.6], 18 => [15.5, 14.5], 21 => [18.2, 17.2] }
    seer_to_expected_eers.each do |seer, expected_eers|
      fan_power_rated = HVAC.get_fan_power_rated(seer)
      actual_eers = HVAC.calc_EERs_cooling_2spd(nil, seer, HVAC.get_c_d_cooling(2, seer), HVAC.two_speed_capacity_ratios, HVAC.two_speed_fan_speed_ratios_cooling, fan_power_rated, HVAC.cOOL_EIR_FT_SPEC_AC(2), HVAC.cOOL_CAP_FT_SPEC_AC(2))
      expected_eers.zip(actual_eers).each do |expected_eer, actual_eer|
        assert_in_epsilon(expected_eer, actual_eer, 0.01)
      end
    end

    # two-speed air source heat pump
    hspf_to_seer = { 8.6 => 16, 8.7 => 17, 9.3 => 18, 9.5 => 19 }
    seer_to_expected_eers = { 16 => [13.2, 12.2], 17 => [14.1, 13.0], 18 => [14.9, 13.9], 19 => [15.7, 14.7] }
    seer_to_expected_eers.each do |seer, expected_eers|
      fan_power_rated = HVAC.get_fan_power_rated(seer)
      actual_eers = HVAC.calc_EERs_cooling_2spd(nil, seer, HVAC.get_c_d_cooling(2, seer), HVAC.two_speed_capacity_ratios, HVAC.two_speed_fan_speed_ratios_cooling, fan_power_rated, HVAC.cOOL_EIR_FT_SPEC_ASHP(2), HVAC.cOOL_CAP_FT_SPEC_ASHP(2))
      expected_eers.zip(actual_eers).each do |expected_eer, actual_eer|
        assert_in_epsilon(expected_eer, actual_eer, 0.01)
      end
    end
    hspf_to_expected_cops = { 8.6 => [3.85, 3.34], 8.7 => [3.90, 3.41], 9.3 => [4.24, 3.83], 9.5 => [4.35, 3.98] }
    hspf_to_expected_cops.each do |hspf, expected_cops|
      fan_power_rated = HVAC.get_fan_power_rated(hspf_to_seer[hspf])
      actual_cops = HVAC.calc_COPs_heating_2spd(hspf, HVAC.get_c_d_heating(2, hspf), HVAC.two_speed_capacity_ratios, HVAC.two_speed_fan_speed_ratios_heating, fan_power_rated, HVAC.hEAT_EIR_FT_SPEC_ASHP(2), HVAC.hEAT_CAP_FT_SPEC_ASHP(2))
      expected_cops.zip(actual_cops).each do |expected_cop, actual_cop|
        assert_in_epsilon(expected_cop, actual_cop, 0.01)
      end
    end

    # variable-speed air conditioner
    capacity_ratios = HVAC.variable_speed_capacity_ratios_cooling
    fan_speed_ratios = HVAC.variable_speed_fan_speed_ratios_cooling
    cap_ratio_seer = [capacity_ratios[0], capacity_ratios[1], capacity_ratios[3]]
    fan_speed_seer = [fan_speed_ratios[0], fan_speed_ratios[1], fan_speed_ratios[3]]
    seer_to_expected_eers = { 24.5 => [19.5, 20.2, 19.7, 18.3] }
    seer_to_expected_eers.each do |seer, expected_eers|
      fan_power_rated = HVAC.get_fan_power_rated(seer)
      actual_eers = HVAC.calc_EERs_cooling_4spd(nil, seer, HVAC.get_c_d_cooling(4, seer), cap_ratio_seer, fan_speed_seer, fan_power_rated, HVAC.cOOL_EIR_FT_SPEC_AC([0, 1, 4]), HVAC.cOOL_CAP_FT_SPEC_AC([0, 1, 4]))
      expected_eers.zip(actual_eers).each do |expected_eer, actual_eer|
        assert_in_epsilon(expected_eer, actual_eer, 0.01)
      end
    end

    # variable-speed air source heat pump
    capacity_ratios = HVAC.variable_speed_capacity_ratios_cooling
    fan_speed_ratios = HVAC.variable_speed_fan_speed_ratios_cooling
    cap_ratio_seer = [capacity_ratios[0], capacity_ratios[1], capacity_ratios[3]]
    fan_speed_seer = [fan_speed_ratios[0], fan_speed_ratios[1], fan_speed_ratios[3]]
    seer_to_expected_eers = { 22.0 => [17.49, 18.09, 17.64, 16.43], 24.5 => [19.5, 20.2, 19.7, 18.3] }
    seer_to_expected_eers.each do |seer, expected_eers|
      fan_power_rated = HVAC.get_fan_power_rated(seer)
      actual_eers = HVAC.calc_EERs_cooling_4spd(nil, seer, HVAC.get_c_d_cooling(4, seer), cap_ratio_seer, fan_speed_seer, fan_power_rated, HVAC.cOOL_EIR_FT_SPEC_ASHP([0, 1, 4]), HVAC.cOOL_CAP_FT_SPEC_ASHP([0, 1, 4]))
      expected_eers.zip(actual_eers).each do |expected_eer, actual_eer|
        assert_in_epsilon(expected_eer, actual_eer, 0.01)
      end
    end
    capacity_ratios = HVAC.variable_speed_capacity_ratios_heating
    fan_speed_ratios = HVAC.variable_speed_fan_speed_ratios_heating
    hspf_to_expected_cops = { 10.0 => [5.18, 4.48, 3.83, 3.67] }
    hspf_to_expected_cops.each do |hspf, expected_cops|
      fan_power_rated = 0.14
      actual_cops = HVAC.calc_COPs_heating_4spd(nil, hspf, HVAC.get_c_d_heating(4, hspf), capacity_ratios, fan_speed_ratios, fan_power_rated, HVAC.hEAT_EIR_FT_SPEC_ASHP(4), HVAC.hEAT_CAP_FT_SPEC_ASHP(4))
      expected_cops.zip(actual_cops).each do |expected_cop, actual_cop|
        assert_in_epsilon(expected_cop, actual_cop, 0.01)
      end
    end
  end

  def _run_xml(xml, this_dir, args, expect_error = false, expect_error_msgs = nil)
    print "Testing #{File.basename(xml)}...\n"
    rundir = File.join(this_dir, "run")
    args['epw_output_path'] = File.absolute_path(File.join(rundir, "in.epw"))
    args['osm_output_path'] = File.absolute_path(File.join(rundir, "in.osm"))
    args['hpxml_path'] = xml
    args['map_tsv_dir'] = rundir
    _test_schema_validation(this_dir, xml)
    results = _test_simulation(args, this_dir, rundir, expect_error, expect_error_msgs)
    return results
  end

  def _get_results(rundir, sim_time, workflow_time)
    sql_path = File.join(rundir, "eplusout.sql")
    sqlFile = OpenStudio::SqlFile.new(sql_path, false)

    tdws = 'TabularDataWithStrings'
    abups = 'AnnualBuildingUtilityPerformanceSummary'
    ef = 'Entire Facility'
    eubs = 'End Uses By Subcategory'
    s = 'Subcategory'

    # Obtain fueltypes
    query = "SELECT ColumnName FROM #{tdws} WHERE ReportName='#{abups}' AND ReportForString='#{ef}' AND TableName='#{eubs}' and ColumnName!='#{s}'"
    fueltypes = sqlFile.execAndReturnVectorOfString(query).get

    # Obtain units
    query = "SELECT Units FROM #{tdws} WHERE ReportName='#{abups}' AND ReportForString='#{ef}' AND TableName='#{eubs}' and ColumnName!='#{s}'"
    units = sqlFile.execAndReturnVectorOfString(query).get

    # Obtain categories
    query = "SELECT RowName FROM #{tdws} WHERE ReportName='#{abups}' AND ReportForString='#{ef}' AND TableName='#{eubs}' AND ColumnName='#{s}'"
    categories = sqlFile.execAndReturnVectorOfString(query).get
    # Fill in blanks based on previous non-blank value
    full_categories = []
    (0..categories.size - 1).each do |i|
      full_categories << categories[i]
      next if full_categories[i].size > 0

      full_categories[i] = full_categories[i - 1]
    end
    full_categories = full_categories * fueltypes.uniq.size # Expand to size of fueltypes

    # Obtain subcategories
    query = "SELECT Value FROM #{tdws} WHERE ReportName='#{abups}' AND ReportForString='#{ef}' AND TableName='#{eubs}' AND ColumnName='#{s}'"
    subcategories = sqlFile.execAndReturnVectorOfString(query).get
    subcategories = subcategories * fueltypes.uniq.size # Expand to size of fueltypes

    # Obtain starting position of results
    query = "SELECT MIN(TabularDataIndex) FROM #{tdws} WHERE ReportName='#{abups}' AND ReportForString='#{ef}' AND TableName='#{eubs}' AND ColumnName='#{fueltypes[0]}'"
    starting_index = sqlFile.execAndReturnFirstInt(query).get

    # TabularDataWithStrings table is positional, so we access results by position.
    results = {}
    fueltypes.zip(full_categories, subcategories, units).each_with_index do |(fueltype, category, subcategory, fuel_units), index|
      next if ['District Cooling', 'District Heating'].include? fueltype # Exclude ideal loads results

      query = "SELECT Value FROM #{tdws} WHERE ReportName='#{abups}' AND ReportForString='#{ef}' AND TableName='#{eubs}' AND TabularDataIndex='#{starting_index + index}'"
      val = sqlFile.execAndReturnFirstDouble(query).get
      next if val == 0

      results[[fueltype, category, subcategory, fuel_units]] = val
    end

    # Disaggregate any crankcase and defrost energy from results (for DSE tests)
    query = "SELECT SUM(Value)/1000000000 FROM ReportData WHERE ReportDataDictionaryIndex IN (SELECT ReportDataDictionaryIndex FROM ReportDataDictionary WHERE Name='Cooling Coil Crankcase Heater Electric Energy')"
    sql_value = sqlFile.execAndReturnFirstDouble(query)
    if sql_value.is_initialized
      cooling_crankcase = sql_value.get
      if cooling_crankcase > 0
        results[["Electricity", "Cooling", "General", "GJ"]] -= cooling_crankcase
        results[["Electricity", "Cooling", "Crankcase", "GJ"]] = cooling_crankcase
      end
    end
    query = "SELECT SUM(Value)/1000000000 FROM ReportData WHERE ReportDataDictionaryIndex IN (SELECT ReportDataDictionaryIndex FROM ReportDataDictionary WHERE Name='Heating Coil Crankcase Heater Electric Energy')"
    sql_value = sqlFile.execAndReturnFirstDouble(query)
    if sql_value.is_initialized
      heating_crankcase = sql_value.get
      if heating_crankcase > 0
        results[["Electricity", "Heating", "General", "GJ"]] -= heating_crankcase
        results[["Electricity", "Heating", "Crankcase", "GJ"]] = heating_crankcase
      end
    end
    query = "SELECT SUM(Value)/1000000000 FROM ReportData WHERE ReportDataDictionaryIndex IN (SELECT ReportDataDictionaryIndex FROM ReportDataDictionary WHERE Name='Heating Coil Defrost Electric Energy')"
    sql_value = sqlFile.execAndReturnFirstDouble(query)
    if sql_value.is_initialized
      heating_defrost = sql_value.get
      if heating_defrost > 0
        results[["Electricity", "Heating", "General", "GJ"]] -= heating_defrost
        results[["Electricity", "Heating", "Defrost", "GJ"]] = heating_defrost
      end
    end

    # Obtain HVAC capacities
    query = "SELECT SUM(Value) FROM ComponentSizes WHERE (CompType LIKE 'Coil:Heating:%' OR CompType LIKE 'Boiler:%' OR CompType LIKE 'ZONEHVAC:BASEBOARD:%') AND Description LIKE '%User-Specified%Capacity' AND Description NOT LIKE '%Supplemental%' AND Units='W'"
    results[["Capacity", "Heating", "General", "W"]] = sqlFile.execAndReturnFirstDouble(query).get

    query = "SELECT SUM(Value) FROM ComponentSizes WHERE CompType LIKE 'Coil:Cooling:%' AND Description LIKE '%User-Specified%Total%Capacity' AND Units='W'"
    results[["Capacity", "Cooling", "General", "W"]] = sqlFile.execAndReturnFirstDouble(query).get

    sqlFile.close

    results[@simulation_runtime_key] = sim_time
    results[@workflow_runtime_key] = workflow_time

    return results
  end

  def _test_simulation(args, this_dir, rundir, expect_error, expect_error_msgs)
    # Uses meta_measure workflow for faster simulations

    # Setup
    _rm_path(rundir)
    Dir.mkdir(rundir)

    workflow_start = Time.now
    model = OpenStudio::Model::Model.new
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # Add measure to workflow
    measures = {}
    measure_subdir = File.absolute_path(File.join(this_dir, "..")).split('/')[-1]
    update_args_hash(measures, measure_subdir, args)

    # Apply measure
    measures_dir = File.join(this_dir, "../../")
    success = apply_measures(measures_dir, measures, runner, model)

    # Report warnings/errors
    File.open(File.join(rundir, 'run.log'), 'w') do |f|
      runner.result.stepWarnings.each do |s|
        f << "Warning: #{s}\n"
      end
      runner.result.stepErrors.each do |s|
        f << "Error: #{s}\n"
      end
    end

    if expect_error
      assert_equal(false, success)

      if expect_error_msgs.nil?
        flunk "No error message defined for #{File.basename(args['hpxml_path'])}."
      else
        run_log = File.readlines(File.join(rundir, "run.log")).map(&:strip)
        expect_error_msgs.each do |error_msg|
          found_error_msg = false
          run_log.each do |run_line|
            next unless run_line.include? error_msg

            found_error_msg = true
            break
          end
          assert(found_error_msg)
        end
      end

      return
    else
      assert_equal(true, success)
    end

    # Add output variables for crankcase and defrost energy (for DSE tests)
    vars = ["Cooling Coil Crankcase Heater Electric Energy",
            "Heating Coil Crankcase Heater Electric Energy",
            "Heating Coil Defrost Electric Energy"]
    vars.each do |var|
      output_var = OpenStudio::Model::OutputVariable.new(var, model)
      output_var.setReportingFrequency('runperiod')
      output_var.setKeyValue('*')
    end

    # Add output variables for CFIS tests
    @cfis_fan_power_output_var = OpenStudio::Model::OutputVariable.new("#{Constants.ObjectNameMechanicalVentilation} cfis fan power".gsub(" ", "_"), model)
    @cfis_fan_power_output_var.setReportingFrequency('runperiod')
    @cfis_fan_power_output_var.setKeyValue('EMS')

    @cfis_flow_rate_output_var = OpenStudio::Model::OutputVariable.new("#{Constants.ObjectNameMechanicalVentilation} cfis flow rate".gsub(" ", "_"), model)
    @cfis_flow_rate_output_var.setReportingFrequency('runperiod')
    @cfis_flow_rate_output_var.setKeyValue('EMS')

    # Write model to IDF
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    model_idf = forward_translator.translateModel(model)
    File.open(File.join(rundir, "in.idf"), 'w') { |f| f << model_idf.to_s }

    # Run EnergyPlus
    ep_path = File.absolute_path(File.join(OpenStudio.getOpenStudioCLI.to_s, '..', '..', 'EnergyPlus', 'energyplus'))
    command = "cd #{rundir} && #{ep_path} -w in.epw in.idf > stdout-energyplus"
    simulation_start = Time.now
    system(command, :err => File::NULL)
    sim_time = (Time.now - simulation_start).round(1)
    workflow_time = (Time.now - workflow_start).round(1)
    puts "Completed #{File.basename(args['hpxml_path'])} simulation in #{sim_time}, workflow in #{workflow_time}s."

    results = _get_results(rundir, sim_time, workflow_time)

    # Verify simulation outputs
    _verify_simulation_outputs(rundir, args['hpxml_path'], results)

    return results
  end

  def _verify_simulation_outputs(rundir, hpxml_path, results)
    # Check that eplusout.err has no lines that include "Blank Schedule Type Limits Name input"
    File.readlines(File.join(rundir, "eplusout.err")).each do |err_line|
      next if err_line.include? 'Schedule:Constant="ALWAYS ON CONTINUOUS", Blank Schedule Type Limits Name input'
      next if err_line.include? 'Schedule:Constant="ALWAYS OFF DISCRETE", Blank Schedule Type Limits Name input'

      assert_equal(err_line.include?("Blank Schedule Type Limits Name input"), false)
    end

    sql_path = File.join(rundir, "eplusout.sql")
    assert(File.exists? sql_path)

    sqlFile = OpenStudio::SqlFile.new(sql_path, false)
    hpxml_doc = REXML::Document.new(File.read(hpxml_path))

    bldg_details = hpxml_doc.elements['/HPXML/Building/BuildingDetails']

    # Conditioned Floor Area
    sum_hvac_load_frac = (bldg_details.elements['sum(Systems/HVAC/HVACPlant/CoolingSystem/FractionCoolLoadServed)'] +
                          bldg_details.elements['sum(Systems/HVAC/HVACPlant/HeatingSystem/FractionHeatLoadServed)'] +
                          bldg_details.elements['sum(Systems/HVAC/HVACPlant/HeatPump/FractionCoolLoadServed)'] +
                          bldg_details.elements['sum(Systems/HVAC/HVACPlant/HeatPump/FractionHeatLoadServed)'])
    if sum_hvac_load_frac > 0 # EnergyPlus will only report conditioned floor area if there is an HVAC system
      hpxml_value = Float(XMLHelper.get_value(bldg_details, 'BuildingSummary/BuildingConstruction/ConditionedFloorArea'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='InputVerificationandResultsSummary' AND ReportForString='Entire Facility' AND TableName='Zone Summary' AND RowName='Conditioned Total' AND ColumnName='Area' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      # Subtract duct return plenum conditioned floor area
      query = "SELECT SUM(Value) FROM TabularDataWithStrings WHERE ReportName='InputVerificationandResultsSummary' AND ReportForString='Entire Facility' AND TableName='Zone Summary' AND RowName LIKE '%RET AIR ZONE' AND ColumnName='Area' AND Units='m2'"
      sql_value -= UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end

    # Enclosure Roofs
    bldg_details.elements.each('Enclosure/Roofs/Roof') do |roof|
      roof_id = roof.elements["SystemIdentifier"].attributes["id"].upcase

      # R-value
      hpxml_value = Float(XMLHelper.get_value(roof, 'Insulation/AssemblyEffectiveRValue'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{roof_id}' AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
      sql_value = 1.0 / UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.1) # TODO: Higher due to outside air film?

      # Net area
      hpxml_value = Float(XMLHelper.get_value(roof, 'Area'))
      bldg_details.elements.each('Enclosure/Skylights/Skylight') do |subsurface|
        next if subsurface.elements["AttachedToRoof"].attributes["idref"].upcase != roof_id

        hpxml_value -= Float(XMLHelper.get_value(subsurface, 'Area'))
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{roof_id}' AND ColumnName='Net Area' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Solar absorptance
      hpxml_value = Float(XMLHelper.get_value(roof, 'SolarAbsorptance'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{roof_id}' AND ColumnName='Reflectance'"
      sql_value = 1.0 - sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Tilt
      hpxml_value = UnitConversions.convert(Math.atan(Float(XMLHelper.get_value(roof, "Pitch")) / 12.0), "rad", "deg")
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{roof_id}' AND ColumnName='Tilt' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Azimuth
      if XMLHelper.has_element(roof, 'Azimuth') and Float(XMLHelper.get_value(roof, "Pitch")) > 0
        hpxml_value = Float(XMLHelper.get_value(roof, 'Azimuth'))
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{roof_id}' AND ColumnName='Azimuth' AND Units='deg'"
        sql_value = sqlFile.execAndReturnFirstDouble(query).get
        assert_in_epsilon(hpxml_value, sql_value, 0.01)
      end
    end

    # Enclosure Foundation Slabs
    bldg_details.elements.each('Enclosure/Slabs/Slab') do |slab|
      slab_id = slab.elements["SystemIdentifier"].attributes["id"].upcase

      # Exposed Area
      hpxml_value = Float(XMLHelper.get_value(slab, 'Area'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{slab_id}' AND ColumnName='Gross Area' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Tilt
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{slab_id}' AND ColumnName='Tilt' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(180.0, sql_value, 0.01)
    end

    # Enclosure Foundations
    # Ensure Kiva instances have appropriate perimeter fraction
    # TODO: Update for walkout basements, which use multiple Kiva instances per foundation.
    File.readlines(File.join(rundir, "eplusout.eio")).each do |eio_line|
      if eio_line.start_with? "Foundation Kiva"
        kiva_perim_frac = Float(eio_line.split(",")[5])
        assert_equal(1.0, kiva_perim_frac)
      end
    end

    # Enclosure Walls
    bldg_details.elements.each('Enclosure/Walls/Wall[extension[ExteriorAdjacentTo="outside"]]') do |wall|
      wall_id = wall.elements["SystemIdentifier"].attributes["id"].upcase

      # R-value
      hpxml_value = Float(XMLHelper.get_value(wall, 'Insulation/AssemblyEffectiveRValue'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
      sql_value = 1.0 / UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.03)

      # Net area
      hpxml_value = Float(XMLHelper.get_value(wall, 'Area'))
      bldg_details.elements.each('Enclosure/Windows/Window | Enclosure/Doors/Door') do |subsurface|
        next if subsurface.elements["AttachedToWall"].attributes["idref"].upcase != wall_id

        hpxml_value -= Float(XMLHelper.get_value(subsurface, 'Area'))
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='Net Area' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Solar absorptance
      hpxml_value = Float(XMLHelper.get_value(wall, 'SolarAbsorptance'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='Reflectance'"
      sql_value = 1.0 - sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Tilt
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='Tilt' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(90.0, sql_value, 0.01)

      # Azimuth
      if XMLHelper.has_element(wall, 'Azimuth')
        hpxml_value = Float(XMLHelper.get_value(wall, 'Azimuth'))
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{wall_id}' AND ColumnName='Azimuth' AND Units='deg'"
        sql_value = sqlFile.execAndReturnFirstDouble(query).get
        assert_in_epsilon(hpxml_value, sql_value, 0.01)
      end
    end

    # Enclosure Windows/Skylights
    bldg_details.elements.each('Enclosure/Windows/Window | Enclosure/Skylights/Skylight') do |subsurface|
      subsurface_id = subsurface.elements["SystemIdentifier"].attributes["id"].upcase

      # Area
      hpxml_value = Float(XMLHelper.get_value(subsurface, 'Area'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Fenestration' AND RowName='#{subsurface_id}' AND ColumnName='Area of Multiplied Openings' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # U-Factor
      hpxml_value = Float(XMLHelper.get_value(subsurface, 'UFactor'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Fenestration' AND RowName='#{subsurface_id}' AND ColumnName='Glass U-Factor' AND Units='W/m2-K'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # SHGC
      # TODO: Affected by interior shading

      # Azimuth
      hpxml_value = Float(XMLHelper.get_value(subsurface, 'Azimuth'))
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Fenestration' AND RowName='#{subsurface_id}' AND ColumnName='Azimuth' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Tilt
      if XMLHelper.has_element(subsurface, "AttachedToWall")
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Fenestration' AND RowName='#{subsurface_id}' AND ColumnName='Tilt' AND Units='deg'"
        sql_value = sqlFile.execAndReturnFirstDouble(query).get
        assert_in_epsilon(90.0, sql_value, 0.01)
      elsif XMLHelper.has_element(subsurface, "AttachedToRoof")
        hpxml_value = nil
        bldg_details.elements.each('Enclosure/Roofs/Roof') do |roof|
          next if roof.elements["SystemIdentifier"].attributes["id"] != subsurface.elements["AttachedToRoof"].attributes["idref"]

          hpxml_value = UnitConversions.convert(Math.atan(Float(XMLHelper.get_value(roof, "Pitch")) / 12.0), "rad", "deg")
        end
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Fenestration' AND RowName='#{subsurface_id}' AND ColumnName='Tilt' AND Units='deg'"
        sql_value = sqlFile.execAndReturnFirstDouble(query).get
        assert_in_epsilon(hpxml_value, sql_value, 0.01)
      else
        flunk "Subsurface '#{subsurface_id}' should have either AttachedToWall or AttachedToRoof element."
      end
    end

    # Enclosure Doors
    bldg_details.elements.each('Enclosure/Doors/Door') do |door|
      door_id = door.elements["SystemIdentifier"].attributes["id"].upcase

      # Area
      door_area = XMLHelper.get_value(door, 'Area')
      if not door_area.nil?
        hpxml_value = Float(door_area)
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Door' AND RowName='#{door_id}' AND ColumnName='Gross Area' AND Units='m2'"
        sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
        assert_in_epsilon(hpxml_value, sql_value, 0.01)
      end

      # R-Value
      door_rvalue = XMLHelper.get_value(door, 'RValue')
      if not door_rvalue.nil?
        hpxml_value = Float(door_rvalue)
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Exterior Door' AND RowName='#{door_id}' AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
        sql_value = 1.0 / UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
        assert_in_epsilon(hpxml_value, sql_value, 0.01)
      end
    end

    # HVAC Heating Systems
    num_htg_sys = bldg_details.elements['count(Systems/HVAC/HVACPlant/HeatingSystem)']
    bldg_details.elements.each('Systems/HVAC/HVACPlant/HeatingSystem') do |htg_sys|
      htg_sys_type = XMLHelper.get_child_name(htg_sys, 'HeatingSystemType')
      htg_sys_fuel = to_beopt_fuel(XMLHelper.get_value(htg_sys, 'HeatingSystemFuel'))
      htg_dse = XMLHelper.get_value(bldg_details, 'Systems/HVAC/HVACDistribution/AnnualHeatingDistributionSystemEfficiency')
      if htg_dse.nil?
        htg_dse = 1.0
      else
        htg_dse = Float(htg_dse)
      end
      htg_load_frac = Float(XMLHelper.get_value(htg_sys, "FractionHeatLoadServed"))

      if htg_load_frac > 0

        # Electric Auxiliary Energy
        # For now, skip if multiple equipment
        if num_htg_sys == 1 and ['Furnace', 'Boiler', 'WallFurnace', 'Stove'].include? htg_sys_type and htg_sys_fuel != Constants.FuelTypeElectric
          if XMLHelper.has_element(htg_sys, 'ElectricAuxiliaryEnergy')
            hpxml_value = Float(XMLHelper.get_value(htg_sys, 'ElectricAuxiliaryEnergy')) / (2.08 * htg_dse)
          else
            furnace_capacity_kbtuh = nil
            if htg_sys_type == 'Furnace'
              query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Heating Coils' AND RowName LIKE '%#{Constants.ObjectNameFurnace.upcase}%' AND ColumnName='Nominal Total Capacity' AND Units='W'"
              furnace_capacity_kbtuh = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W', 'kBtu/hr')
            end
            frac_load_served = Float(XMLHelper.get_value(htg_sys, "FractionHeatLoadServed"))
            hpxml_value = HVAC.get_default_eae(htg_sys_type, htg_sys_fuel, frac_load_served, furnace_capacity_kbtuh) / (2.08 * htg_dse)
          end

          if htg_sys_type == 'Boiler'
            query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Pumps' AND RowName LIKE '%#{Constants.ObjectNameBoiler.upcase}%' AND ColumnName='Electric Power' AND Units='W'"
            sql_value = sqlFile.execAndReturnFirstDouble(query).get
          elsif htg_sys_type == 'Furnace'

            # Ratio fan power based on heating airflow rate divided by fan airflow rate since the
            # fan is sized based on cooling.
            query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Fans' AND RowName LIKE '%#{Constants.ObjectNameFurnace.upcase}%' AND ColumnName='Rated Electric Power' AND Units='W'"
            query_fan_airflow = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='ComponentSizingSummary' AND ReportForString='Entire Facility' AND TableName='Fan:OnOff' AND RowName LIKE '%#{Constants.ObjectNameFurnace.upcase}%' AND ColumnName='User-Specified Maximum Flow Rate' AND Units='m3/s'"
            query_htg_airflow = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='ComponentSizingSummary' AND ReportForString='Entire Facility' AND TableName='AirLoopHVAC:UnitarySystem' AND RowName LIKE '%#{Constants.ObjectNameFurnace.upcase}%' AND ColumnName='User-Specified Heating Supply Air Flow Rate' AND Units='m3/s'"
            sql_value = sqlFile.execAndReturnFirstDouble(query).get
            sql_value_fan_airflow = sqlFile.execAndReturnFirstDouble(query_fan_airflow).get
            sql_value_htg_airflow = sqlFile.execAndReturnFirstDouble(query_htg_airflow).get
            sql_value *= sql_value_htg_airflow / sql_value_fan_airflow
          elsif htg_sys_type == 'Stove' or htg_sys_type == 'WallFurnace'
            query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Fans' AND RowName LIKE '%#{Constants.ObjectNameUnitHeater.upcase}%' AND ColumnName='Rated Electric Power' AND Units='W'"
            sql_value = sqlFile.execAndReturnFirstDouble(query).get
          else
            flunk "Unexpected heating system type '#{htg_sys_type}'."
          end
          assert_in_epsilon(hpxml_value, sql_value, 0.01)
        end

      end
    end

    # HVAC Capacities
    htg_cap = 0.0
    clg_cap = 0.0
    has_multispeed_dx_heating_coil = false # FIXME: Remove this when https://github.com/NREL/EnergyPlus/issues/7381 is fixed
    has_gshp_coil = false # FIXME: Remove this when https://github.com/NREL/EnergyPlus/issues/7381 is fixed
    bldg_details.elements.each('Systems/HVAC/HVACPlant/HeatingSystem') do |htg_sys|
      htg_sys_cap = Float(XMLHelper.get_value(htg_sys, "HeatingCapacity"))
      htg_cap += htg_sys_cap if htg_sys_cap > 0
    end
    bldg_details.elements.each('Systems/HVAC/HVACPlant/CoolingSystem') do |clg_sys|
      clg_sys_cap = Float(XMLHelper.get_value(clg_sys, "CoolingCapacity"))
      clg_cap += clg_sys_cap if clg_sys_cap > 0
    end
    bldg_details.elements.each('Systems/HVAC/HVACPlant/HeatPump') do |hp|
      hp_type = XMLHelper.get_value(hp, "HeatPumpType")
      hp_cap = Float(XMLHelper.get_value(hp, "CoolingCapacity"))
      if hp_type == "mini-split"
        hp_cap *= 1.20 # TODO: Generalize this
      end
      supp_hp_cap = XMLHelper.get_value(hp, "BackupHeatingCapacity").to_f
      clg_cap += hp_cap if hp_cap > 0
      htg_cap += hp_cap if hp_cap > 0
      htg_cap += supp_hp_cap if supp_hp_cap > 0
      if XMLHelper.get_value(hp, "AnnualCoolingEfficiency[Units='SEER']/Value").to_f > 15 or XMLHelper.get_value(hp, "AnnualHeatingEfficiency[Units='HSPF']/Value").to_f > 8.5
        has_multispeed_dx_heating_coil = true
      end
      if hp_type == "ground-to-air"
        has_gshp_coil = true
      end
    end
    if clg_cap > 0
      hpxml_value = clg_cap
      sql_value = UnitConversions.convert(results[["Capacity", "Cooling", "General", "W"]], 'W', 'Btu/hr')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end
    if htg_cap > 0 and not (has_multispeed_dx_heating_coil or has_gshp_coil)
      hpxml_value = htg_cap
      sql_value = UnitConversions.convert(results[["Capacity", "Heating", "General", "W"]], 'W', 'Btu/hr')
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end

    # HVAC Load Fractions
    htg_load_frac = 0.0
    clg_load_frac = 0.0
    bldg_details.elements.each('Systems/HVAC/HVACPlant/HeatingSystem') do |htg_sys|
      htg_load_frac += Float(XMLHelper.get_value(htg_sys, "FractionHeatLoadServed"))
    end
    bldg_details.elements.each('Systems/HVAC/HVACPlant/CoolingSystem') do |clg_sys|
      clg_load_frac += Float(XMLHelper.get_value(clg_sys, "FractionCoolLoadServed"))
    end
    bldg_details.elements.each('Systems/HVAC/HVACPlant/HeatPump') do |hp|
      htg_load_frac += Float(XMLHelper.get_value(hp, "FractionHeatLoadServed"))
      clg_load_frac += Float(XMLHelper.get_value(hp, "FractionCoolLoadServed"))
    end
    if htg_load_frac == 0
      found_htg_energy = false
      results.keys.each do |k|
        next unless k[1] == 'Heating' and k[0] != 'Capacity'

        found_htg_energy = true
      end
      assert_equal(false, found_htg_energy)
    end
    if clg_load_frac == 0
      found_clg_energy = false
      results.keys.each do |k|
        next unless k[1] == 'Cooling' and k[0] != 'Capacity'

        found_clg_energy = true
      end
      assert_equal(false, found_clg_energy)
    end

    # Water Heater
    wh = bldg_details.elements["Systems/WaterHeating"]

    # Mechanical Ventilation
    mv = bldg_details.elements["Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation='true']"]
    if not mv.nil?
      found_mv_energy = false
      results.keys.each do |k|
        next if k[0] != 'Electricity' or k[1] != 'Interior Equipment' or not k[2].start_with? Constants.ObjectNameMechanicalVentilation

        found_mv_energy = true
        if XMLHelper.has_element(mv, "AttachedToHVACDistributionSystem")
          # CFIS, check for positive mech vent energy that is less than the energy if it had run 24/7
          assert_operator(results[k], :>, 0)
          fan_w = Float(XMLHelper.get_value(mv, "FanPower"))
          hrs_per_day = Float(XMLHelper.get_value(mv, "HoursInOperation"))
          fan_kwhs = UnitConversions.convert(fan_w * hrs_per_day * 365.0, 'Wh', 'GJ')
          assert_operator(results[k], :<, fan_kwhs)
        else
          # Supply, exhaust, ERV, HRV, etc., check for appropriate mech vent energy
          fan_w = Float(XMLHelper.get_value(mv, "FanPower"))
          hrs_per_day = Float(XMLHelper.get_value(mv, "HoursInOperation"))
          fan_kwhs = UnitConversions.convert(fan_w * hrs_per_day * 365.0, 'Wh', 'GJ')
          assert_in_delta(fan_kwhs, results[k], 0.1)
        end
      end
      if not found_mv_energy
        flunk "Could not find mechanical ventilation energy for #{hpxml_path}."
      end

      # CFIS
      if XMLHelper.get_value(mv, "FanType") == "central fan integrated supply"
        # Fan power
        hpxml_value = Float(XMLHelper.get_value(mv, "FanPower"))
        query = "SELECT Value FROM ReportData WHERE ReportDataDictionaryIndex IN (SELECT ReportDataDictionaryIndex FROM ReportDataDictionary WHERE Name= '#{@cfis_fan_power_output_var.variableName}')"
        sql_value = sqlFile.execAndReturnFirstDouble(query).get
        assert_in_delta(hpxml_value, sql_value, 0.001)

        # Flow rate
        hpxml_value = Float(XMLHelper.get_value(mv, "RatedFlowRate")) * Float(XMLHelper.get_value(mv, "HoursInOperation")) / 24.0
        query = "SELECT Value FROM ReportData WHERE ReportDataDictionaryIndex IN (SELECT ReportDataDictionaryIndex FROM ReportDataDictionary WHERE Name= '#{@cfis_flow_rate_output_var.variableName}')"
        sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, "m^3/s", "cfm")
        assert_in_delta(hpxml_value, sql_value, 0.001)
      end

    end

    # Clothes Washer
    cw = bldg_details.elements["Appliances/ClothesWasher"]
    if not cw.nil? and not wh.nil?
      # Location
      location = XMLHelper.get_value(cw, "Location")
      hpxml_value = { nil => Constants.SpaceTypeLiving,
                      'living space' => Constants.SpaceTypeLiving,
                      'basement - conditioned' => Constants.SpaceTypeConditionedBasement,
                      'basement - unconditioned' => Constants.SpaceTypeUnconditionedBasement,
                      'garage' => Constants.SpaceTypeGarage }[location].upcase
      query = "SELECT Value FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Zone Name' AND RowName=(SELECT RowName FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Name' AND Value='#{Constants.ObjectNameClothesWasher.upcase}')"
      sql_value = sqlFile.execAndReturnFirstString(query).get
      assert_equal(hpxml_value, sql_value)
    end

    # Clothes Dryer
    cd = bldg_details.elements["Appliances/ClothesDryer"]
    if not cd.nil? and not wh.nil?
      # Location
      location = XMLHelper.get_value(cd, "Location")
      hpxml_value = { nil => Constants.SpaceTypeLiving,
                      'living space' => Constants.SpaceTypeLiving,
                      'basement - conditioned' => Constants.SpaceTypeConditionedBasement,
                      'basement - unconditioned' => Constants.SpaceTypeUnconditionedBasement,
                      'garage' => Constants.SpaceTypeGarage }[location].upcase
      query = "SELECT Value FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Zone Name' AND RowName=(SELECT RowName FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Name' AND Value='#{Constants.ObjectNameClothesDryer.upcase}')"
      sql_value = sqlFile.execAndReturnFirstString(query).get
      assert_equal(hpxml_value, sql_value)
    end

    # Refrigerator
    refr = bldg_details.elements["Appliances/Refrigerator"]
    if not refr.nil?
      # Location
      location = XMLHelper.get_value(refr, "Location")
      hpxml_value = { nil => Constants.SpaceTypeLiving,
                      'living space' => Constants.SpaceTypeLiving,
                      'basement - conditioned' => Constants.SpaceTypeConditionedBasement,
                      'basement - unconditioned' => Constants.SpaceTypeUnconditionedBasement,
                      'garage' => Constants.SpaceTypeGarage }[location].upcase
      query = "SELECT Value FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Zone Name' AND RowName=(SELECT RowName FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Name' AND Value='#{Constants.ObjectNameRefrigerator.upcase}')"
      sql_value = sqlFile.execAndReturnFirstString(query).get
      assert_equal(hpxml_value, sql_value)
    end

    # Lighting
    found_ltg_energy = false
    results.keys.each do |k|
      next unless k[1].include? 'Lighting'

      found_ltg_energy = true
    end
    assert_equal(bldg_details.elements["Lighting"].nil?, !found_ltg_energy)

    sqlFile.close
  end

  def _write_summary_results(results_dir, results)
    Dir.mkdir(results_dir)
    csv_out = File.join(results_dir, 'results.csv')

    # Get all keys across simulations for output columns
    output_keys = []
    results.each do |xml, xml_results|
      xml_results.keys.each do |key|
        next if not key.is_a? Array
        next if output_keys.include? key

        output_keys << key
      end
    end
    output_keys.sort!

    # Append runtimes at the end
    output_keys << @simulation_runtime_key
    output_keys << @workflow_runtime_key

    column_headers = ['HPXML']
    output_keys.each do |key|
      if key.is_a? Array
        column_headers << "#{key[0]}: #{key[1]}: #{key[2]} [#{key[3]}]"
      else
        column_headers << key
      end
    end

    require 'csv'
    CSV.open(csv_out, 'w') do |csv|
      csv << column_headers
      results.sort.each do |xml, xml_results|
        csv_row = [xml]
        output_keys.each do |key|
          if xml_results[key].nil?
            csv_row << 0
          else
            csv_row << xml_results[key]
          end
        end
        csv << csv_row
      end
    end

    puts "Wrote results to #{csv_out}."
  end

  def _test_schema_validation(this_dir, xml)
    # TODO: Remove this when schema validation is included with CLI calls
    schemas_dir = File.absolute_path(File.join(this_dir, "..", "hpxml_schemas"))
    hpxml_doc = REXML::Document.new(File.read(xml))
    errors = XMLHelper.validate(hpxml_doc.to_s, File.join(schemas_dir, "HPXML.xsd"), nil)
    if errors.size > 0
      puts "#{xml}: #{errors.to_s}"
    end
    assert_equal(0, errors.size)
  end

  def _test_dse(xmls, hvac_dse_dir, hvac_base_dir, all_results)
    # Compare 0.8 DSE heating/cooling results to 1.0 DSE results.
    puts "DSE test results:"
    xmls.sort.each do |xml|
      next if not xml.include? hvac_dse_dir
      next if not xml.include? "-dse-0.8"

      xml_dse80 = File.absolute_path(xml)
      xml_dse100 = xml_dse80.gsub(hvac_dse_dir, hvac_base_dir).gsub("-dse-0.8.xml", "-base.xml")

      results_dse80 = all_results[xml_dse80]
      results_dse100 = all_results[xml_dse100]
      next if results_dse100.nil?

      # Compare results
      results_dse80.keys.each do |k|
        next if not ["Heating", "Cooling"].include? k[1]
        next if not ["General"].include? k[2] # Exclude crankcase/defrost
        next if k[0] == 'Capacity'

        result_dse80 = results_dse80[k].to_f
        result_dse100 = results_dse100[k].to_f
        next if result_dse80 == 0.0 and result_dse100 == 0.0

        dse_actual = result_dse100 / result_dse80
        dse_expect = 0.8
        if File.basename(xml) == "base-hvac-furnace-gas-room-ac-dse-0.8.xml" and k[1] == "Cooling"
          dse_expect = 1.0 # TODO: Generalize this
        end

        _display_result_epsilon(xml, dse_expect, dse_actual, k)
        assert_in_epsilon(dse_expect, dse_actual, 0.05)
      end
    end
  end

  def _test_multiple_hvac(xmls, hvac_multiple_dir, hvac_base_dir, all_results)
    # Compare end use results for three of an HVAC system to results for one HVAC system.
    puts "Multiple HVAC test results:"
    xmls.sort.each do |xml|
      next if not xml.include? hvac_multiple_dir

      xml_x3 = File.absolute_path(xml)
      xml_x1 = File.absolute_path(xml.gsub(hvac_multiple_dir, hvac_base_dir).gsub("-x3.xml", "-base.xml"))

      results_x3 = all_results[xml_x3]
      results_x1 = all_results[xml_x1]
      next if results_x1.nil?

      # Compare results
      results_x3.keys.each do |k|
        next if not ["Heating", "Cooling"].include? k[1]
        next if not ["General"].include? k[2] # Exclude crankcase/defrost

        result_x1 = results_x1[k].to_f
        result_x3 = results_x3[k].to_f
        next if result_x1 == 0.0 and result_x3 == 0.0

        _display_result_epsilon(xml, result_x1, result_x3, k)
        assert_in_epsilon(result_x1, result_x3, 0.12)
      end
    end
  end

  def _test_multiple_water_heaters(xmls, water_heating_multiple_dir, all_results)
    # Compare end use results for three tankless water heaters to results for one tankless water heater.
    puts "Multiple water heater test results:"
    xmls.sort.each do |xml|
      next if not xml.include? water_heating_multiple_dir

      xml_x3 = File.absolute_path(xml)
      xml_x1 = File.absolute_path(File.join(File.dirname(xml), "..", File.basename(xml.gsub("-x3.xml", ".xml"))))

      results_x3 = all_results[xml_x3]
      results_x1 = all_results[xml_x1]
      next if results_x1.nil?

      # Compare results
      results_x3.keys.each do |k|
        next if [@simulation_runtime_key, @workflow_runtime_key].include? k

        result_x1 = results_x1[k].to_f
        result_x3 = results_x3[k].to_f
        next if result_x1 == 0.0 and result_x3 == 0.0

        _display_result_delta(xml, result_x1, result_x3, k)
        assert_in_delta(result_x1, result_x3, 0.1)
      end
    end
  end

  def _test_partial_hvac(xmls, hvac_partial_dir, hvac_base_dir, all_results)
    # Compare end use results for a partial HVAC system to a full HVAC system.
    puts "Partial HVAC test results:"
    xmls.sort.each do |xml|
      next if not xml.include? hvac_partial_dir

      xml_33 = File.absolute_path(xml)
      xml_100 = File.absolute_path(xml.gsub(hvac_partial_dir, hvac_base_dir).gsub("-33percent.xml", "-base.xml"))

      results_33 = all_results[xml_33]
      results_100 = all_results[xml_100]
      next if results_100.nil?

      # Compare results
      results_33.keys.each do |k|
        next if not ["Heating", "Cooling"].include? k[1]
        next if not ["General"].include? k[2] # Exclude crankcase/defrost

        result_33 = results_33[k].to_f
        result_100 = results_100[k].to_f
        next if result_33 == 0.0 and result_100 == 0.0

        _display_result_epsilon(xml, result_33, result_100 / 3.0, k)
        assert_in_epsilon(result_33, result_100 / 3.0, 0.05)
      end
    end
  end

  def _display_result_epsilon(xml, result1, result2, key)
    epsilon = (result1 - result2).abs / [result1, result2].min
    puts "#{xml}: epsilon=#{epsilon.round(5)} [#{key}]"
  end

  def _display_result_delta(xml, result1, result2, key)
    delta = (result1 - result2).abs
    puts "#{xml}: delta=#{delta.round(5)} [#{key}]"
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
