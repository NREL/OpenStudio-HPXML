# frozen_string_literal: true

require_relative '../../HPXMLtoOpenStudio/resources/minitest_helper'
require 'openstudio'
require 'fileutils'
require 'parallel'
require_relative '../../HPXMLtoOpenStudio/measure.rb'
require_relative '../../HPXMLtoOpenStudio/resources/constants'
require_relative '../../HPXMLtoOpenStudio/resources/meta_measure'
require_relative '../../HPXMLtoOpenStudio/resources/unit_conversions'
require_relative '../../HPXMLtoOpenStudio/resources/xmlhelper'

class HPXMLTest < MiniTest::Test
  def setup
    @this_dir = File.dirname(__FILE__)
    @results_dir = File.join(@this_dir, 'results')
    FileUtils.mkdir_p @results_dir
  end

  def test_simulations
    results_out = File.join(@results_dir, 'results.csv')
    File.delete(results_out) if File.exist? results_out
    sizing_out = File.join(@results_dir, 'results_hvac_sizing.csv')
    File.delete(sizing_out) if File.exist? sizing_out
    bills_out = File.join(@results_dir, 'results_bills.csv')
    File.delete(bills_out) if File.exist? bills_out

    xmls = []
    sample_files_dirs = [File.absolute_path(File.join(@this_dir, '..', 'sample_files')),
                         File.absolute_path(File.join(@this_dir, '..', 'real_homes'))]
    sample_files_dirs.each do |sample_files_dir|
      Dir["#{sample_files_dir}/*.xml"].sort.each do |xml|
        next if xml.include? 'base-multiple-buildings.xml' # This is tested in test_multiple_building_ids

        xmls << File.absolute_path(xml)
      end
    end

    # Test simulations
    puts "Running #{xmls.size} HPXML files..."
    all_results = {}
    all_sizing_results = {}
    all_bill_results = {}
    Parallel.map(xmls, in_threads: Parallel.processor_count) do |xml|
      _test_schema_validation(xml)
      xml_name = File.basename(xml)
      all_results[xml_name], all_sizing_results[xml_name], all_bill_results[xml_name] = _run_xml(xml, Parallel.worker_number)
    end

    _write_summary_results(all_results.sort_by { |k, v| k.downcase }.to_h, results_out)
    _write_hvac_sizing_results(all_sizing_results.sort_by { |k, v| k.downcase }.to_h, sizing_out)
    _write_bill_results(all_bill_results.sort_by { |k, v| k.downcase }.to_h, bills_out)
  end

  def test_ashrae_140
    ashrae140_out = File.join(@results_dir, 'results_ashrae_140.csv')
    File.delete(ashrae140_out) if File.exist? ashrae140_out

    xmls = []
    ashrae_140_dir = File.absolute_path(File.join(@this_dir, 'ASHRAE_Standard_140'))
    Dir["#{ashrae_140_dir}/*.xml"].sort.each do |xml|
      xmls << File.absolute_path(xml)
    end

    # Test simulations
    puts "Running #{xmls.size} HPXML files..."
    all_results = {}
    Parallel.map(xmls, in_threads: Parallel.processor_count) do |xml|
      xml_name = File.basename(xml)
      all_results[xml_name], _, _ = _run_xml(xml, Parallel.worker_number)
    end

    _write_ashrae_140_results(all_results.sort_by { |k, v| k.downcase }.to_h, ashrae140_out)
  end

  def test_run_simulation_csv_output
    # Check that the simulation produces CSV outputs if requested
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "#{OpenStudio.getOpenStudioCLI} #{rb_path} -x #{xml} --debug --hourly ALL --add-utility-bills --output-format csv"
    system(command, err: File::NULL)

    # Check for output files
    assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.sql'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_timeseries.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_hpxml.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_bills.csv'))

    # Check for debug files
    osm_path = File.join(File.dirname(xml), 'run', 'in.osm')
    assert(File.exist? osm_path)
    hpxml_defaults_path = File.join(File.dirname(xml), 'run', 'in.xml')
    assert(File.exist? hpxml_defaults_path)
    _test_schema_validation(hpxml_defaults_path)
  end

  def test_run_simulation_json_output
    # Check that the simulation produces JSON outputs (instead of CSV outputs) if requested
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "#{OpenStudio.getOpenStudioCLI} #{rb_path} -x #{xml} --debug --hourly ALL --add-utility-bills --output-format json"
    system(command, err: File::NULL)

    # Check for output files
    assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.sql'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.json'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_timeseries.json'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_hpxml.json'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_bills.json'))

    # Check for debug files
    osm_path = File.join(File.dirname(xml), 'run', 'in.osm')
    assert(File.exist? osm_path)
    hpxml_defaults_path = File.join(File.dirname(xml), 'run', 'in.xml')
    assert(File.exist? hpxml_defaults_path)
    _test_schema_validation(hpxml_defaults_path)
  end

  def test_run_simulation_epjson_input
    # Check that we can run a simulation using epJSON (instead of IDF) if requested
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "#{OpenStudio.getOpenStudioCLI} #{rb_path} -x #{xml} --ep-input-format epjson"
    system(command, err: File::NULL)

    # Check for epjson file
    assert(File.exist? File.join(File.dirname(xml), 'run', 'in.epJSON'))

    # Check for output files
    assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.sql'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_hpxml.csv'))
  end

  def test_run_simulation_idf_input
    # Check that we can run a simulation using IDF (instead of epJSON) if requested
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "#{OpenStudio.getOpenStudioCLI} #{rb_path} -x #{xml} --ep-input-format idf"
    system(command, err: File::NULL)

    # Check for idf file
    assert(File.exist? File.join(File.dirname(xml), 'run', 'in.idf'))

    # Check for output files
    assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.sql'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_hpxml.csv'))
  end

  def test_run_simulation_faster_performance
    # Run w/ --skip-validation and w/o --add-component-loads arguments
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "#{OpenStudio.getOpenStudioCLI} #{rb_path} -x #{xml} --skip-validation"
    system(command, err: File::NULL)

    # Check for output files
    assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.sql'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_hpxml.csv'))

    # Check component loads don't exist
    component_loads = {}
    CSV.read(File.join(File.dirname(xml), 'run', 'results_hpxml.csv'), headers: false).each do |data|
      next unless data[0].to_s.start_with? 'Component Load'

      component_loads[data[0]] = Float(data[1])
    end
    assert_equal(0, component_loads.size)
  end

  def test_run_simulation_detailed_schedules
    # Check that the simulation produces stochastic schedules if requested
    sample_files_path = File.join(File.dirname(__FILE__), '..', 'sample_files')
    tmp_hpxml_path = File.join(sample_files_path, 'tmp.xml')
    hpxml = HPXML.new(hpxml_path: File.join(sample_files_path, 'base.xml'))
    XMLHelper.write_file(hpxml.to_oga, tmp_hpxml_path)

    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.absolute_path(tmp_hpxml_path)
    command = "#{OpenStudio.getOpenStudioCLI} #{rb_path} -x #{xml} --add-detailed-schedule stochastic"
    system(command, err: File::NULL)

    # Check for output files
    assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.sql'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_hpxml.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'stochastic.csv'))

    # Cleanup
    File.delete(tmp_hpxml_path) if File.exist? tmp_hpxml_path
  end

  def test_run_simulation_timeseries_outputs
    # Check that the simulation produces timeseries with requested outputs
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "#{OpenStudio.getOpenStudioCLI} #{rb_path} -x #{xml} --hourly ALL --add-timeseries-time-column DST --add-timeseries-time-column UTC"
    command += " --add-timeseries-output-variable 'Zone People Occupant Count' --add-timeseries-output-variable 'Zone People Total Heating Energy'"
    system(command, err: File::NULL)

    # Check for output files
    assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.sql'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_hpxml.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_timeseries.csv'))

    # Check TimeDST and TimeUTC exist
    timeseries_rows = CSV.read(File.join(File.dirname(xml), 'run', 'results_timeseries.csv'))
    assert_equal(1, timeseries_rows[0].select { |r| r == 'Time' }.size)
    assert_equal(1, timeseries_rows[0].select { |r| r == 'TimeDST' }.size)
    assert_equal(1, timeseries_rows[0].select { |r| r == 'TimeUTC' }.size)
    assert_equal(1, timeseries_rows[0].select { |r| r == 'Zone People Occupant Count: Living Space' }.size)
    assert_equal(1, timeseries_rows[0].select { |r| r == 'Zone People Total Heating Energy: Living Space' }.size)
  end

  def test_template_osw
    # Check that simulation works using template.osw
    require 'json'

    osw_path = File.join(File.dirname(__FILE__), '..', 'template.osw')

    # Create derivative OSW for testing
    osw_path_test = osw_path.gsub('.osw', '_test.osw')
    FileUtils.cp(osw_path, osw_path_test)

    # Turn on debug mode
    json = JSON.parse(File.read(osw_path_test), symbolize_names: true)
    json[:steps][0][:arguments][:debug] = true

    if Dir.exist? File.join(File.dirname(__FILE__), '..', '..', 'project')
      # CI checks out the repo as "project", so update dir name
      json[:steps][0][:measure_dir_name] = 'project'
    end

    File.open(osw_path_test, 'w') do |f|
      f.write(JSON.pretty_generate(json))
    end

    command = "#{OpenStudio.getOpenStudioCLI} run -w \"#{osw_path_test}\""
    system(command, err: File::NULL)

    # Check for output files
    sql_path = File.join(File.dirname(osw_path_test), 'run', 'eplusout.sql')
    assert(File.exist? sql_path)
    csv_output_path = File.join(File.dirname(osw_path_test), 'run', 'results_annual.csv')
    assert(File.exist? csv_output_path)
    csv_output_path = File.join(File.dirname(osw_path_test), 'run', 'results_hpxml.csv')
    assert(File.exist? csv_output_path)

    # Check for debug files
    osm_path = File.join(File.dirname(osw_path_test), 'run', 'in.osm')
    assert(File.exist? osm_path)
    hpxml_defaults_path = File.join(File.dirname(osw_path_test), 'run', 'in.xml')
    assert(File.exist? hpxml_defaults_path)

    # Cleanup
    File.delete(osw_path_test)
  end

  def test_template_osw_with_schedule
    # Check that simulation works using template.osw
    require 'json'

    osw_path = File.join(File.dirname(__FILE__), '..', 'template-stochastic-schedules.osw')

    # Create derivative OSW for testing
    osw_path_test = osw_path.gsub('.osw', '_test.osw')
    FileUtils.cp(osw_path, osw_path_test)

    # Turn on debug mode
    json = JSON.parse(File.read(osw_path_test), symbolize_names: true)
    json[:steps][1][:arguments][:debug] = true

    if Dir.exist? File.join(File.dirname(__FILE__), '..', '..', 'project')
      # CI checks out the repo as "project", so update dir name
      json[:steps][1][:measure_dir_name] = 'project'
    end

    File.open(osw_path_test, 'w') do |f|
      f.write(JSON.pretty_generate(json))
    end

    command = "#{OpenStudio.getOpenStudioCLI} run -w \"#{osw_path_test}\""
    system(command, err: File::NULL)

    # Check for output files
    sql_path = File.join(File.dirname(osw_path_test), 'run', 'eplusout.sql')
    assert(File.exist? sql_path)
    csv_output_path = File.join(File.dirname(osw_path_test), 'run', 'results_annual.csv')
    assert(File.exist? csv_output_path)
    csv_output_path = File.join(File.dirname(osw_path_test), 'run', 'results_hpxml.csv')
    assert(File.exist? csv_output_path)

    # Check for debug files
    osm_path = File.join(File.dirname(osw_path_test), 'run', 'in.osm')
    assert(File.exist? osm_path)
    hpxml_defaults_path = File.join(File.dirname(osw_path_test), 'run', 'in.xml')
    assert(File.exist? hpxml_defaults_path)

    # Cleanup
    File.delete(osw_path_test)
    xml_path_test = File.join(File.dirname(__FILE__), '..', 'base-stochastic-schedules.xml')
    File.delete(xml_path_test)
  end

  def test_template_osw_with_build_hpxml_and_schedule
    # Check that simulation works using template2.osw
    require 'json'

    osw_path = File.join(File.dirname(__FILE__), '..', 'template-build-hpxml-and-stochastic-schedules.osw')

    # Create derivative OSW for testing
    osw_path_test = osw_path.gsub('.osw', '_test.osw')
    FileUtils.cp(osw_path, osw_path_test)

    # Turn on debug mode
    json = JSON.parse(File.read(osw_path_test), symbolize_names: true)
    json[:steps][2][:arguments][:debug] = true

    if Dir.exist? File.join(File.dirname(__FILE__), '..', '..', 'project')
      # CI checks out the repo as "project", so update dir name
      json[:steps][1][:measure_dir_name] = 'project'
    end

    File.open(osw_path_test, 'w') do |f|
      f.write(JSON.pretty_generate(json))
    end

    command = "#{OpenStudio.getOpenStudioCLI} run -w \"#{osw_path_test}\""
    system(command, err: File::NULL)

    # Check for output files
    sql_path = File.join(File.dirname(osw_path_test), 'run', 'eplusout.sql')
    assert(File.exist? sql_path)
    csv_output_path = File.join(File.dirname(osw_path_test), 'run', 'results_annual.csv')
    assert(File.exist? csv_output_path)
    csv_output_path = File.join(File.dirname(osw_path_test), 'run', 'results_hpxml.csv')
    assert(File.exist? csv_output_path)

    # Check for debug files
    osm_path = File.join(File.dirname(osw_path_test), 'run', 'in.osm')
    assert(File.exist? osm_path)
    hpxml_defaults_path = File.join(File.dirname(osw_path_test), 'run', 'in.xml')
    assert(File.exist? hpxml_defaults_path)

    # Cleanup
    File.delete(osw_path_test)
    xml_path_test = File.join(File.dirname(__FILE__), '..', 'built.xml')
    File.delete(xml_path_test)
    xml_path_test = File.join(File.dirname(__FILE__), '..', 'built-stochastic-schedules.xml')
    File.delete(xml_path_test)
  end

  def test_multiple_building_ids
    os_cli = OpenStudio.getOpenStudioCLI
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base-multiple-buildings.xml')
    csv_output_path = File.join(File.dirname(xml), 'run', 'results_annual.csv')
    run_log = File.join(File.dirname(xml), 'run', 'run.log')

    # Check successful simulation when providing correct building ID
    command = "#{OpenStudio.getOpenStudioCLI} #{rb_path} -x #{xml} --building-id MyBuilding"
    system(command, err: File::NULL)
    assert_equal(true, File.exist?(csv_output_path))

    # Check unsuccessful simulation when providing incorrect building ID
    command = "#{OpenStudio.getOpenStudioCLI} #{rb_path} -x #{xml} --building-id MyFoo"
    system(command, err: File::NULL)
    assert_equal(false, File.exist?(csv_output_path))
    assert(File.readlines(run_log).select { |l| l.include? "Could not find Building element with ID 'MyFoo'." }.size > 0)

    # Check unsuccessful simulation when not providing building ID
    command = "#{OpenStudio.getOpenStudioCLI} #{rb_path} -x #{xml}"
    system(command, err: File::NULL)
    assert_equal(false, File.exist?(csv_output_path))
    assert(File.readlines(run_log).select { |l| l.include? 'Multiple Building elements defined in HPXML file; Building ID argument must be provided.' }.size > 0)
  end

  def test_weather_cache
    cache_orig = File.join(@this_dir, '..', '..', 'weather', 'USA_CO_Denver.Intl.AP.725650_TMY3-cache.csv')
    cache_bak = cache_orig + '.bak'
    File.rename(cache_orig, cache_bak)
    _run_xml(File.absolute_path(File.join(@this_dir, '..', 'sample_files', 'base.xml')))
    File.rename(cache_bak, cache_orig) # Put original file back
  end

  def test_release_zips
    # Check release zips successfully created
    top_dir = File.join(@this_dir, '..', '..')
    command = "#{OpenStudio.getOpenStudioCLI} #{File.join(top_dir, 'tasks.rb')} create_release_zips"
    system(command)
    assert_equal(2, Dir["#{top_dir}/*.zip"].size)

    # Check successful running of simulation from release zips
    require 'zip'
    Zip.on_exists_proc = true
    Dir["#{top_dir}/OpenStudio-HPXML*.zip"].each do |zip_path|
      Zip::File.open(zip_path) do |zip_file|
        zip_file.each do |f|
          FileUtils.mkdir_p(File.dirname(f.name)) unless File.exist?(File.dirname(f.name))
          zip_file.extract(f, f.name)
        end
      end

      # Test run_simulation.rb
      command = "#{OpenStudio.getOpenStudioCLI} OpenStudio-HPXML/workflow/run_simulation.rb -x OpenStudio-HPXML/workflow/sample_files/base.xml"
      system(command)
      assert(File.exist? 'OpenStudio-HPXML/workflow/sample_files/run/results_annual.csv')
      assert(File.exist? 'OpenStudio-HPXML/workflow/sample_files/run/results_hpxml.csv')

      File.delete(zip_path)
      rm_path('OpenStudio-HPXML')
    end
  end

  private

  def _run_xml(xml, worker_num = nil)
    print "Testing #{File.basename(xml)}...\n"
    rundir = File.join(@this_dir, "test#{worker_num}")

    # Uses 'monthly' to verify timeseries results match annual results via error-checking
    # inside the ReportSimulationOutput measure.
    cli_path = OpenStudio.getOpenStudioCLI
    command = "\"#{cli_path}\" \"#{File.join(File.dirname(__FILE__), '../run_simulation.rb')}\" -x #{xml} --add-component-loads -o #{rundir} --debug --monthly ALL --add-utility-bills"
    workflow_start = Time.now
    success = system(command)
    workflow_time = Time.now - workflow_start

    rundir = File.join(rundir, 'run')

    # Check results
    assert_equal(true, success)

    # Check for output files
    annual_csv_path = File.join(rundir, 'results_annual.csv')
    timeseries_csv_path = File.join(rundir, 'results_timeseries.csv')
    hpxml_csv_path = File.join(rundir, 'results_hpxml.csv')
    bills_csv_path = File.join(rundir, 'results_bills.csv')
    assert(File.exist? annual_csv_path)
    assert(File.exist? timeseries_csv_path)
    assert(File.exist? hpxml_csv_path)

    # Get results
    results = _get_simulation_results(annual_csv_path, xml)

    # Check outputs
    hpxml_defaults_path = File.join(rundir, 'in.xml')
    stron_paths = [File.join(File.dirname(__FILE__), '..', '..', 'HPXMLtoOpenStudio', 'resources', 'hpxml_schematron', 'EPvalidator.xml')]
    hpxml = HPXML.new(hpxml_path: hpxml_defaults_path, schematron_validators: stron_paths) # Validate in.xml to ensure it can be run back through OS-HPXML
    if not hpxml.errors.empty?
      puts 'ERRORS:'
      hpxml.errors.each do |error|
        puts error
      end
      flunk "EPvalidator.xml error in #{hpxml_defaults_path}."
    end
    sizing_results = _get_hvac_sizing_results(hpxml, xml)
    bill_results = _get_bill_results(bills_csv_path, xml)
    _verify_outputs(rundir, xml, results, hpxml)

    return results, sizing_results, bill_results
  end

  def _get_simulation_results(annual_csv_path, xml)
    # Grab all outputs from reporting measure CSV annual results
    results = {}
    CSV.foreach(annual_csv_path) do |row|
      next if row.nil? || (row.size < 2)

      results[row[0]] = Float(row[1])
    end

    # Check discrepancy between total load and sum of component loads
    if not xml.include? 'ASHRAE_Standard_140'
      sum_component_htg_loads = results.select { |k, v| k.start_with? 'Component Load: Heating:' }.map { |k, v| v }.sum(0.0)
      sum_component_clg_loads = results.select { |k, v| k.start_with? 'Component Load: Cooling:' }.map { |k, v| v }.sum(0.0)
      total_htg_load = results['Load: Heating: Delivered (MBtu)']
      total_clg_load = results['Load: Cooling: Delivered (MBtu)']
      abs_htg_load_delta = (total_htg_load - sum_component_htg_loads).abs
      abs_clg_load_delta = (total_clg_load - sum_component_clg_loads).abs
      avg_htg_load = ([total_htg_load, abs_htg_load_delta].sum / 2.0)
      avg_clg_load = ([total_htg_load, abs_htg_load_delta].sum / 2.0)
      abs_htg_load_frac = abs_htg_load_delta / avg_htg_load
      abs_clg_load_frac = abs_clg_load_delta / avg_clg_load
      # Check that the difference is less than 0.6MBtu or less than 10%
      assert((abs_htg_load_delta < 0.6) || (abs_htg_load_frac < 0.1))
      assert((abs_clg_load_delta < 0.6) || (abs_clg_load_frac < 0.1))
    end

    return results
  end

  def _get_hvac_sizing_results(hpxml, xml)
    results = {}
    return if xml.include? 'ASHRAE_Standard_140'

    # Heating design loads
    hpxml.hvac_plant.class::HDL_ATTRS.each do |attr, element_name|
      results["heating_load_#{attr.to_s.gsub('hdl_', '')} [Btuh]"] = hpxml.hvac_plant.send(attr.to_s)
    end

    # Cooling sensible design loads
    hpxml.hvac_plant.class::CDL_SENS_ATTRS.each do |attr, element_name|
      results["cooling_load_#{attr.to_s.gsub('cdl_', '')} [Btuh]"] = hpxml.hvac_plant.send(attr.to_s)
    end

    # Cooling latent design loads
    hpxml.hvac_plant.class::CDL_LAT_ATTRS.each do |attr, element_name|
      results["cooling_load_#{attr.to_s.gsub('cdl_', '')} [Btuh]"] = hpxml.hvac_plant.send(attr.to_s)
    end

    # Heating capacities/airflows
    results['heating_capacity [Btuh]'] = 0.0
    results['heating_backup_capacity [Btuh]'] = 0.0
    results['heating_airflow [cfm]'] = 0.0
    (hpxml.heating_systems + hpxml.heat_pumps).each do |htg_sys|
      results['heating_capacity [Btuh]'] += htg_sys.heating_capacity
      if htg_sys.is_a? HPXML::HeatPump
        if not htg_sys.backup_heating_capacity.nil?
          results['heating_backup_capacity [Btuh]'] += htg_sys.backup_heating_capacity
        elsif not htg_sys.backup_system.nil?
          results['heating_backup_capacity [Btuh]'] += htg_sys.backup_system.heating_capacity
        end
      end
      results['heating_airflow [cfm]'] += htg_sys.heating_airflow_cfm.to_f
    end

    # Cooling capacity/airflows
    results['cooling_capacity [Btuh]'] = 0.0
    results['cooling_airflow [cfm]'] = 0.0
    (hpxml.cooling_systems + hpxml.heat_pumps).each do |clg_sys|
      results['cooling_capacity [Btuh]'] += clg_sys.cooling_capacity
      results['cooling_airflow [cfm]'] += clg_sys.cooling_airflow_cfm
    end

    assert(!results.empty?)

    if (hpxml.heating_systems + hpxml.heat_pumps).select { |h| h.fraction_heat_load_served.to_f > 0 }.empty?
      # No heating equipment; check for zero heating capacities/airflows/duct loads
      assert_equal(0.0, results['heating_capacity [Btuh]'])
      assert_equal(0.0, results['heating_backup_capacity [Btuh]'])
      assert_equal(0.0, results['heating_airflow [cfm]'])
      assert_equal(0.0, results['heating_load_ducts [Btuh]'])
    end
    if (hpxml.cooling_systems + hpxml.heat_pumps).select { |c| c.fraction_cool_load_served.to_f > 0 }.empty?
      # No cooling equipment; check for zero cooling capacities/airflows/duct loads
      assert_equal(0.0, results['cooling_capacity [Btuh]'])
      assert_equal(0.0, results['cooling_airflow [cfm]'])
      assert_equal(0.0, results['cooling_load_sens_ducts [Btuh]'])
      assert_equal(0.0, results['cooling_load_lat_ducts [Btuh]'])
    end
    if hpxml.hvac_distributions.map { |dist| dist.ducts.size }.empty?
      # No ducts; check for zero duct loads
      assert_equal(0.0, results['heating_load_ducts [Btuh]'])
      assert_equal(0.0, results['cooling_load_sens_ducts [Btuh]'])
      assert_equal(0.0, results['cooling_load_lat_ducts [Btuh]'])
    end

    return results
  end

  def _get_bill_results(bill_csv_path, xml)
    # Grab all outputs from reporting measure CSV bill results
    results = {}
    if File.exist? bill_csv_path
      CSV.foreach(bill_csv_path) do |row|
        next if row.nil? || (row.size < 2)

        results[row[0]] = Float(row[1])
      end
    end

    return results
  end

  def _test_schema_validation(xml)
    # TODO: Remove this when schema validation is included with CLI calls
    schemas_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', 'HPXMLtoOpenStudio', 'resources', 'hpxml_schema'))
    hpxml_doc = XMLHelper.parse_file(xml)
    errors = XMLHelper.validate(hpxml_doc.to_xml, File.join(schemas_dir, 'HPXML.xsd'), nil)
    if errors.size > 0
      puts "#{xml}: #{errors}"
    end
    assert_equal(0, errors.size)
  end

  def _verify_outputs(rundir, hpxml_path, results, hpxml)
    sql_path = File.join(rundir, 'eplusout.sql')
    assert(File.exist? sql_path)

    sqlFile = OpenStudio::SqlFile.new(sql_path, false)

    # Collapse windows further using same logic as measure.rb
    hpxml.windows.each do |window|
      window.fraction_operable = nil
    end
    hpxml.collapse_enclosure_surfaces()

    # Check run.log warnings
    def skip_utility_bill_warning(err_line)
      utility_bill_warnings = ["#{EPlus::FuelTypeElectricity}:Facility".upcase,
                               "#{EPlus::FuelTypeElectricity}Produced:Facility".upcase,
                               "#{EPlus::FuelTypeNaturalGas}:Facility".upcase,
                               "#{EPlus::FuelTypeOil}:Facility".upcase,
                               "#{EPlus::FuelTypePropane}:Facility".upcase,
                               "#{EPlus::FuelTypeWoodCord}:Facility".upcase,
                               "#{EPlus::FuelTypeWoodPellets}:Facility".upcase,
                               "#{EPlus::FuelTypeCoal}:Facility".upcase]
      skip_warning = false
      utility_bill_warnings.each do |utility_bill_warning|
        skip_warning = true if err_line.include? utility_bill_warning
      end
      return skip_warning
    end
    File.readlines(File.join(rundir, 'run.log')).each do |log_line|
      next if log_line.strip.empty?
      next if log_line.include? 'Warning: Could not load nokogiri, no HPXML validation performed.'
      next if log_line.start_with? 'Info: '
      next if log_line.start_with? 'Executing command'
      next if log_line.include? "-cache.csv' could not be found; regenerating it."
      next if log_line.include? 'Could not find state average'

      if hpxml_path.include? 'base-atticroof-conditioned.xml'
        next if log_line.include?('Ducts are entirely within conditioned space but there is moderate leakage to the outside. Leakage to the outside is typically zero or near-zero in these situations, consider revising leakage values. Leakage will be modeled as heat lost to the ambient environment.')
      end
      if hpxml.clothes_washers.empty?
        next if log_line.include? 'No clothes washer specified, the model will not include clothes washer energy use.'
      end
      if hpxml.clothes_dryers.empty?
        next if log_line.include? 'No clothes dryer specified, the model will not include clothes dryer energy use.'
      end
      if hpxml.dishwashers.empty?
        next if log_line.include? 'No dishwasher specified, the model will not include dishwasher energy use.'
      end
      if hpxml.refrigerators.empty?
        next if log_line.include? 'No refrigerator specified, the model will not include refrigerator energy use.'
      end
      if hpxml.cooking_ranges.empty?
        next if log_line.include? 'No cooking range specified, the model will not include cooking range/oven energy use.'
      end
      if hpxml.water_heating_systems.empty?
        next if log_line.include? 'No water heating specified, the model will not include water heating energy use.'
      end
      if (hpxml.heating_systems + hpxml.heat_pumps).select { |h| h.fraction_heat_load_served.to_f > 0 }.empty?
        next if log_line.include? 'No space heating specified, the model will not include space heating energy use.'
      end
      if (hpxml.cooling_systems + hpxml.heat_pumps).select { |c| c.fraction_cool_load_served.to_f > 0 }.empty?
        next if log_line.include? 'No space cooling specified, the model will not include space cooling energy use.'
      end
      if hpxml.plug_loads.select { |p| p.plug_load_type == HPXML::PlugLoadTypeOther }.empty?
        next if log_line.include? "No '#{HPXML::PlugLoadTypeOther}' plug loads specified, the model will not include misc plug load energy use."
      end
      if hpxml.plug_loads.select { |p| p.plug_load_type == HPXML::PlugLoadTypeTelevision }.empty?
        next if log_line.include? "No '#{HPXML::PlugLoadTypeTelevision}' plug loads specified, the model will not include television plug load energy use."
      end
      if hpxml.lighting_groups.empty?
        next if log_line.include? 'No lighting specified, the model will not include lighting energy use.'
      end
      if hpxml.windows.empty?
        next if log_line.include? 'No windows specified, the model will not include window heat transfer.'
      end
      if hpxml.pv_systems.empty? && !hpxml.batteries.empty?
        next if log_line.include? 'Battery without PV specified; battery is assumed to operate as backup and will not be modeled.'
      end
      if hpxml_path.include? 'base-location-capetown-zaf.xml'
        next if log_line.include? 'OS Message: Minutes field (60) on line 9 of EPW file'
        next if log_line.include? 'Could not find a marginal Electricity rate.'
        next if log_line.include? 'Could not find a marginal Natural Gas rate.'
      end
      if !hpxml.hvac_distributions.select { |d| d.distribution_system_type == HPXML::HVACDistributionTypeDSE }.empty?
        next if log_line.include? 'DSE is not currently supported when calculating utility bills.'
      end

      flunk "Unexpected warning found in run.log: #{log_line}"
    end

    # Check for unexpected warnings
    File.readlines(File.join(rundir, 'eplusout.err')).each do |err_line|
      next unless err_line.include? '** Warning **'

      # General
      next if err_line.include? 'Schedule:Constant="ALWAYS ON CONTINUOUS", Blank Schedule Type Limits Name input'
      next if err_line.include? 'Schedule:Constant="ALWAYS OFF DISCRETE", Blank Schedule Type Limits Name input'
      next if err_line.include? 'Entered Zone Volumes differ from calculated zone volume'
      next if err_line.include? 'PerformancePrecisionTradeoffs: Carroll MRT radiant exchange method is selected.'
      next if err_line.include?('CalculateZoneVolume') && err_line.include?('not fully enclosed')
      next if err_line.include? 'do not define an enclosure'
      next if err_line.include? 'Pump nominal power or motor efficiency is set to 0'
      next if err_line.include? 'volume flow rate per watt of rated total cooling capacity is out of range'
      next if err_line.include? 'volume flow rate per watt of rated total heating capacity is out of range'
      next if err_line.include? 'Timestep: Requested number'
      next if err_line.include? 'The Standard Ratings is calculated for'
      next if err_line.include?('WetBulb not converged after') && err_line.include?('iterations(PsyTwbFnTdbWPb)')
      next if err_line.include? 'Inside surface heat balance did not converge with Max Temp Difference'
      next if err_line.include? 'Inside surface heat balance convergence problem continues'
      next if err_line.include? 'Missing temperature setpoint for LeavingSetpointModulated mode' # These warnings are fine, simulation continues with assigning plant loop setpoint to boiler, which is the expected one
      next if err_line.include?('Glycol: Temperature') && err_line.include?('out of range (too low) for fluid')
      next if err_line.include?('Glycol: Temperature') && err_line.include?('out of range (too high) for fluid')
      next if err_line.include? 'Plant loop exceeding upper temperature limit'
      next if err_line.include? 'Plant loop falling below lower temperature limit'
      next if err_line.include?('Foundation:Kiva') && err_line.include?('wall surfaces with more than four vertices') # TODO: Check alternative approach
      next if err_line.include? 'Temperature out of range [-100. to 200.] (PsyPsatFnTemp)'
      next if err_line.include? 'Enthalpy out of range (PsyTsatFnHPb)'
      next if err_line.include? 'Full load outlet air dry-bulb temperature < 2C. This indicates the possibility of coil frost/freeze.'
      next if err_line.include? 'Full load outlet temperature indicates a possibility of frost/freeze error continues.'
      next if err_line.include? 'Air-cooled condenser inlet dry-bulb temperature below 0 C.'
      next if err_line.include? 'Low condenser dry-bulb temperature error continues.'
      next if err_line.include? 'Coil control failed'
      next if err_line.include? 'sensible part-load ratio out of range error continues'
      next if err_line.include? 'Iteration limit exceeded in calculating sensible part-load ratio error continues'
      next if err_line.include?('setupIHGOutputs: Output variables=Zone Other Equipment') && err_line.include?('are not available.')
      next if err_line.include?('setupIHGOutputs: Output variables=Space Other Equipment') && err_line.include?('are not available')
      next if err_line.include? 'Actual air mass flow rate is smaller than 25% of water-to-air heat pump coil rated air flow rate.' # FUTURE: Remove this when https://github.com/NREL/EnergyPlus/issues/9125 is resolved
      next if err_line.include? 'DetailedSkyDiffuseModeling is chosen but not needed as either the shading transmittance for shading devices does not change throughout the year'
      next if err_line.include? 'View factors not complete'

      if err_line.include? 'Output:Meter: invalid Key Name'
        next if skip_utility_bill_warning(err_line)
      end

      # HPWHs
      if hpxml.water_heating_systems.select { |wh| wh.water_heater_type == HPXML::WaterHeaterTypeHeatPump }.size > 0
        next if err_line.include? 'Recovery Efficiency and Energy Factor could not be calculated during the test for standard ratings'
        next if err_line.include? 'SimHVAC: Maximum iterations (20) exceeded for all HVAC loops'
        next if err_line.include? 'Rated air volume flow rate per watt of rated total water heating capacity is out of range'
        next if err_line.include? 'For object = Coil:WaterHeating:AirToWaterHeatPump:Wrapped'
        next if err_line.include? 'Enthalpy out of range (PsyTsatFnHPb)'
      end
      # HP defrost curves
      if hpxml.heat_pumps.select { |hp| [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpMiniSplit, HPXML::HVACTypeHeatPumpPTHP].include? hp.heat_pump_type }.size > 0
        next if err_line.include?('GetDXCoils: Coil:Heating:DX') && err_line.include?('curve values')
      end
      if hpxml.cooling_systems.select { |c| c.cooling_system_type == HPXML::HVACTypeEvaporativeCooler }.size > 0
        # Evap cooler model is not really using Controller:MechanicalVentilation object, so these warnings of ignoring some features are fine.
        # OS requires a Controller:MechanicalVentilation to be attached to the oa controller, however it's not required by E+.
        # Manually removing Controller:MechanicalVentilation from idf eliminates these two warnings.
        # FUTURE: Can we update OS to allow removing it?
        next if err_line.include?('Zone') && err_line.include?('is not accounted for by Controller:MechanicalVentilation object')
        next if err_line.include?('PEOPLE object for zone') && err_line.include?('is not accounted for by Controller:MechanicalVentilation object')
        # "The only valid controller type for an AirLoopHVAC is Controller:WaterCoil.", evap cooler doesn't need one.
        next if err_line.include?('GetAirPathData: AirLoopHVAC') && err_line.include?('has no Controllers')
        # input "Autosize" for Fixed Minimum Air Flow Rate is added by OS translation, now set it to 0 to skip potential sizing process, though no way to prevent this warning.
        next if err_line.include? 'Since Zone Minimum Air Flow Input Method = CONSTANT, input for Fixed Minimum Air Flow Rate will be ignored'
      end
      if hpxml.hvac_distributions.select { |d| d.air_type.to_s == HPXML::AirTypeFanCoil }.size > 0
        next if err_line.include? 'In calculating the design coil UA for Coil:Cooling:Water' # Warning for unused cooling coil for fan coil
      end
      if hpxml_path.include?('ground-to-air-heat-pump-cooling-only.xml') || hpxml_path.include?('ground-to-air-heat-pump-heating-only.xml')
        next if err_line.include? 'COIL:HEATING:WATERTOAIRHEATPUMP:EQUATIONFIT' # heating capacity is > 20% different than cooling capacity; safe to ignore
      end
      if hpxml.solar_thermal_systems.size > 0
        next if err_line.include? 'Supply Side is storing excess heat the majority of the time.'
      end
      if hpxml_path.include?('base-schedules-detailed')
        next if err_line.include?('GetCurrentScheduleValue: Schedule=') && err_line.include?('is a Schedule:File')
      end

      flunk "Unexpected warning found: #{err_line}"
    end

    # Check for unused objects/schedules/constructions warnings
    num_unused_objects = 0
    num_unused_schedules = 0
    num_unused_constructions = 0
    File.readlines(File.join(rundir, 'eplusout.err')).each do |err_line|
      if err_line.include? 'unused objects in input'
        num_unused_objects = Integer(err_line.split(' ')[3])
      elsif err_line.include? 'unused schedules in input'
        num_unused_schedules = Integer(err_line.split(' ')[3])
      elsif err_line.include? 'unused constructions in input'
        num_unused_constructions = Integer(err_line.split(' ')[6])
      end
    end
    assert_equal(0, num_unused_objects)
    assert_equal(0, num_unused_schedules)
    assert_equal(0, num_unused_constructions)

    # Check for Output:Meter and Output:Variable warnings
    num_invalid_output_meters = 0
    num_invalid_output_variables = 0
    File.readlines(File.join(rundir, 'eplusout.err')).each do |err_line|
      if err_line.include? 'Output:Meter: invalid Key Name'
        next if skip_utility_bill_warning(err_line)

        num_invalid_output_meters += 1
      elsif err_line.include?('Key=') && err_line.include?('VarName=')
        num_invalid_output_variables += 1
      end
    end
    assert_equal(0, num_invalid_output_meters)
    assert_equal(0, num_invalid_output_variables)

    # Timestep
    timestep = hpxml.header.timestep
    if timestep.nil?
      timestep = 60
    end
    query = 'SELECT NumTimestepsPerHour FROM Simulations'
    sql_value = sqlFile.execAndReturnFirstDouble(query).get
    assert_equal(60 / timestep, sql_value)

    # Conditioned Floor Area
    if (hpxml.total_fraction_cool_load_served > 0) || (hpxml.total_fraction_heat_load_served > 0) # EnergyPlus will only report conditioned floor area if there is an HVAC system
      hpxml_value = hpxml.building_construction.conditioned_floor_area
      if hpxml.has_location(HPXML::LocationCrawlspaceConditioned)
        hpxml_value += hpxml.slabs.select { |s| s.interior_adjacent_to == HPXML::LocationCrawlspaceConditioned }.map { |s| s.area }.sum
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='InputVerificationandResultsSummary' AND ReportForString='Entire Facility' AND TableName='Zone Summary' AND RowName='Conditioned Total' AND ColumnName='Area' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.1)
    end

    # Enclosure Roofs
    hpxml.roofs.each do |roof|
      roof_id = roof.id.upcase

      # R-value
      hpxml_value = roof.insulation_assembly_r_value
      if hpxml_path.include? 'ASHRAE_Standard_140'
        # Compare R-value w/o film
        hpxml_value -= Material.AirFilmRoofASHRAE140.rvalue
        hpxml_value -= Material.AirFilmOutsideASHRAE140.rvalue
        query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND (RowName='#{roof_id}' OR RowName LIKE '#{roof_id}:%') AND ColumnName='U-Factor no Film' AND Units='W/m2-K'"
      else
        # Compare R-value w/ film
        query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND (RowName='#{roof_id}' OR RowName LIKE '#{roof_id}:%') AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
      end
      sql_value = 1.0 / UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.1)

      # Net area
      hpxml_value = roof.area
      hpxml.skylights.each do |subsurface|
        next if subsurface.roof_idref.upcase != roof_id

        hpxml_value -= subsurface.area
      end
      query = "SELECT SUM(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND (RowName='#{roof_id}' OR RowName LIKE '#{roof_id}:%') AND ColumnName='Net Area' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_operator(sql_value, :>, 0.01)
      assert_in_epsilon(hpxml_value, sql_value, 0.1)

      # Solar absorptance
      hpxml_value = roof.solar_absorptance
      query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND (RowName='#{roof_id}' OR RowName LIKE '#{roof_id}:%') AND ColumnName='Reflectance'"
      sql_value = 1.0 - sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Tilt
      hpxml_value = UnitConversions.convert(Math.atan(roof.pitch / 12.0), 'rad', 'deg')
      query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND (RowName='#{roof_id}' OR RowName LIKE '#{roof_id}:%') AND ColumnName='Tilt' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Azimuth
      next unless (not roof.azimuth.nil?) && (Float(roof.pitch) > 0)

      hpxml_value = roof.azimuth
      query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND (RowName='#{roof_id}' OR RowName LIKE '#{roof_id}:%') AND ColumnName='Azimuth' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end

    # Enclosure Foundations
    # Ensure Kiva instances have perimeter fraction of 1.0 as we explicitly define them to end up this way.
    num_kiva_instances = 0
    File.readlines(File.join(rundir, 'eplusout.eio')).each do |eio_line|
      next unless eio_line.downcase.start_with? 'foundation kiva'

      kiva_perim_frac = Float(eio_line.split(',')[5])
      assert_equal(1.0, kiva_perim_frac)

      num_kiva_instances += 1
    end

    if hpxml_path.include? 'ASHRAE_Standard_140'
      # nop
    elsif hpxml_path.include? 'real_homes'
      # nop
    elsif hpxml_path.include? 'base-bldgtype-multifamily'
      assert_equal(0, num_kiva_instances)                                                # no foundation, above dwelling unit
    else
      num_expected_kiva_instances = { 'base-foundation-ambient.xml' => 0,                # no foundation in contact w/ ground
                                      'base-foundation-multiple.xml' => 2,               # additional instance for 2nd foundation type
                                      'base-enclosure-2stories-garage.xml' => 2,         # additional instance for garage
                                      'base-foundation-basement-garage.xml' => 2,        # additional instance for garage
                                      'base-enclosure-garage.xml' => 2,                  # additional instance for garage
                                      'base-foundation-walkout-basement.xml' => 4,       # 3 foundation walls plus a no-wall exposed perimeter
                                      'base-foundation-complex.xml' => 10,               # lots of foundations for testing
                                      'base-enclosure-split-surfaces2.xml' => 81,        # lots of foundations for testing
                                      'base-pv-battery-garage.xml' => 2 }                # additional instance for garage

      if not num_expected_kiva_instances[File.basename(hpxml_path)].nil?
        assert_equal(num_expected_kiva_instances[File.basename(hpxml_path)], num_kiva_instances)
      else
        assert_equal(1, num_kiva_instances)
      end
    end

    # Enclosure Foundation Slabs
    num_slabs = hpxml.slabs.size
    if (num_slabs <= 1) && (num_kiva_instances <= 1) # The slab surfaces may be combined in these situations, so skip tests
      hpxml.slabs.each do |slab|
        slab_id = slab.id.upcase

        # Exposed Area
        hpxml_value = Float(slab.area)
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{slab_id}' AND ColumnName='Gross Area' AND Units='m2'"
        sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
        assert_operator(sql_value, :>, 0.01)
        assert_in_epsilon(hpxml_value, sql_value, 0.1)

        # Tilt
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{slab_id}' AND ColumnName='Tilt' AND Units='deg'"
        sql_value = sqlFile.execAndReturnFirstDouble(query).get
        assert_in_epsilon(180.0, sql_value, 0.01)
      end
    end

    # Enclosure Walls/RimJoists/FoundationWalls
    (hpxml.walls + hpxml.rim_joists + hpxml.foundation_walls).each do |wall|
      wall_id = wall.id.upcase

      if wall.is_adiabatic
        # Adiabatic surfaces have their "BaseSurfaceIndex" as their "ExtBoundCond" in "Surfaces" table in SQL simulation results
        query_base_surf_idx = "SELECT BaseSurfaceIndex FROM Surfaces WHERE SurfaceName='#{wall_id}'"
        query_ext_bound = "SELECT ExtBoundCond FROM Surfaces WHERE SurfaceName='#{wall_id}'"
        sql_value_base_surf_idx = sqlFile.execAndReturnFirstDouble(query_base_surf_idx).get
        sql_value_ext_bound_cond = sqlFile.execAndReturnFirstDouble(query_ext_bound).get
        assert_equal(sql_value_base_surf_idx, sql_value_ext_bound_cond)
      end

      if wall.is_exterior
        table_name = 'Opaque Exterior'
      else
        table_name = 'Opaque Interior'
      end

      # R-value
      if (not wall.insulation_assembly_r_value.nil?) && (not wall.is_a? HPXML::FoundationWall) # FoundationWalls use Foundation:Kiva for insulation
        hpxml_value = wall.insulation_assembly_r_value
        if hpxml_path.include? 'ASHRAE_Standard_140'
          # Compare R-value w/o film
          hpxml_value -= Material.AirFilmVerticalASHRAE140.rvalue
          if wall.is_exterior
            hpxml_value -= Material.AirFilmOutsideASHRAE140.rvalue
          else
            hpxml_value -= Material.AirFilmVerticalASHRAE140.rvalue
          end
          query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='U-Factor no Film' AND Units='W/m2-K'"
        elsif wall.is_interior
          # Compare R-value w/o film
          hpxml_value -= Material.AirFilmVertical.rvalue
          hpxml_value -= Material.AirFilmVertical.rvalue
          query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='U-Factor no Film' AND Units='W/m2-K'"
        else
          # Compare R-value w/ film
          query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
        end
        sql_value = 1.0 / UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
        assert_in_epsilon(hpxml_value, sql_value, 0.1)
      end

      # Net area
      hpxml_value = wall.area
      (hpxml.windows + hpxml.doors).each do |subsurface|
        next if subsurface.wall_idref.upcase != wall_id

        hpxml_value -= subsurface.area
      end
      if wall.exterior_adjacent_to == HPXML::LocationGround
        # Calculate total length of walls
        wall_total_length = 0
        hpxml.foundation_walls.each do |foundation_wall|
          next unless foundation_wall.exterior_adjacent_to == HPXML::LocationGround
          next unless wall.interior_adjacent_to == foundation_wall.interior_adjacent_to

          wall_total_length += foundation_wall.area / foundation_wall.height
        end

        # Calculate total slab exposed perimeter
        slab_exposed_length = 0
        hpxml.slabs.each do |slab|
          next unless wall.interior_adjacent_to == slab.interior_adjacent_to

          slab_exposed_length += slab.exposed_perimeter
        end

        # Calculate exposed foundation wall area
        if slab_exposed_length < wall_total_length
          hpxml_value *= (slab_exposed_length / wall_total_length)
        end
      end
      if (hpxml.foundation_walls.include? wall) && (not wall.is_exterior)
        # interzonal foundation walls: only above-grade portion modeled
        hpxml_value *= (wall.height - wall.depth_below_grade) / wall.height
      end
      if wall.is_exterior
        query = "SELECT SUM(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%' OR RowName LIKE '#{wall_id} %') AND ColumnName='Net Area' AND Units='m2'"
      else
        query = "SELECT SUM(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='Net Area' AND Units='m2'"
      end
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_operator(sql_value, :>, 0.01)
      assert_in_epsilon(hpxml_value, sql_value, 0.1)

      # Solar absorptance
      if wall.respond_to?(:solar_absorptance) && (not wall.solar_absorptance.nil?)
        hpxml_value = wall.solar_absorptance
        query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='Reflectance'"
        sql_value = 1.0 - sqlFile.execAndReturnFirstDouble(query).get
        assert_in_epsilon(hpxml_value, sql_value, 0.01)
      end

      # Tilt
      query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='Tilt' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(90.0, sql_value, 0.01)

      # Azimuth
      next if wall.azimuth.nil?

      hpxml_value = wall.azimuth
      query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='Azimuth' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end

    # Enclosure FrameFloors
    hpxml.frame_floors.each do |frame_floor|
      frame_floor_id = frame_floor.id.upcase

      if frame_floor.is_adiabatic
        # Adiabatic surfaces have their "BaseSurfaceIndex" as their "ExtBoundCond" in "Surfaces" table in SQL simulation results
        query_base_surf_idx = "SELECT BaseSurfaceIndex FROM Surfaces WHERE SurfaceName='#{frame_floor_id}'"
        query_ext_bound = "SELECT ExtBoundCond FROM Surfaces WHERE SurfaceName='#{frame_floor_id}'"
        sql_value_base_surf_idx = sqlFile.execAndReturnFirstDouble(query_base_surf_idx).get
        sql_value_ext_bound_cond = sqlFile.execAndReturnFirstDouble(query_ext_bound).get
        assert_equal(sql_value_base_surf_idx, sql_value_ext_bound_cond)
      end

      if frame_floor.is_exterior
        table_name = 'Opaque Exterior'
      else
        table_name = 'Opaque Interior'
      end

      # R-value
      hpxml_value = frame_floor.insulation_assembly_r_value
      if hpxml_path.include? 'ASHRAE_Standard_140'
        # Compare R-value w/o film
        if frame_floor.is_exterior # Raised floor
          hpxml_value -= Material.AirFilmFloorASHRAE140.rvalue
          hpxml_value -= Material.AirFilmFloorZeroWindASHRAE140.rvalue
        elsif frame_floor.is_ceiling # Attic floor
          hpxml_value -= Material.AirFilmFloorASHRAE140.rvalue
          hpxml_value -= Material.AirFilmFloorASHRAE140.rvalue
        end
        query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{frame_floor_id}' AND ColumnName='U-Factor no Film' AND Units='W/m2-K'"
      elsif frame_floor.is_interior
        # Compare R-value w/o film
        if frame_floor.is_ceiling
          hpxml_value -= Material.AirFilmFloorAverage.rvalue
          hpxml_value -= Material.AirFilmFloorAverage.rvalue
        else
          hpxml_value -= Material.AirFilmFloorReduced.rvalue
          hpxml_value -= Material.AirFilmFloorReduced.rvalue
        end
        query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{frame_floor_id}' AND ColumnName='U-Factor no Film' AND Units='W/m2-K'"
      else
        # Compare R-value w/ film
        query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{frame_floor_id}' AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
      end
      sql_value = 1.0 / UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.1)

      # Area
      hpxml_value = frame_floor.area
      query = "SELECT SUM(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{frame_floor_id}' AND ColumnName='Net Area' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_operator(sql_value, :>, 0.01)
      assert_in_epsilon(hpxml_value, sql_value, 0.1)

      # Tilt
      if frame_floor.is_ceiling
        hpxml_value = 0
      else
        hpxml_value = 180
      end
      query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{frame_floor_id}' AND ColumnName='Tilt' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end

    # Enclosure Windows/Skylights
    (hpxml.windows + hpxml.skylights).each do |subsurface|
      subsurface_id = subsurface.id.upcase

      if subsurface.is_exterior
        table_name = 'Exterior Fenestration'
      else
        table_name = 'Interior Door'
      end

      # Area
      if subsurface.is_exterior
        col_name = 'Area of Multiplied Openings'
      else
        col_name = 'Gross Area'
      end
      hpxml_value = subsurface.area
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{subsurface_id}' AND ColumnName='#{col_name}' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_operator(sql_value, :>, 0.01)
      assert_in_epsilon(hpxml_value, sql_value, 0.1)

      # U-Factor
      if subsurface.is_exterior
        col_name = 'Glass U-Factor'
      else
        col_name = 'U-Factor no Film'
      end
      hpxml_value = Constructions.get_ufactor_shgc_adjusted_by_storms(subsurface.storm_type, subsurface.ufactor, subsurface.shgc)[0]
      if subsurface.is_interior
        hpxml_value = 1.0 / (1.0 / hpxml_value - Material.AirFilmVertical.rvalue)
        hpxml_value = 1.0 / (1.0 / hpxml_value - Material.AirFilmVertical.rvalue)
      end
      if subsurface.is_a? HPXML::Skylight
        hpxml_value /= 1.2 # converted to the 20-deg slope from the vertical position by multiplying the tested value at vertical
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{subsurface_id}' AND ColumnName='#{col_name}' AND Units='W/m2-K'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.02)

      next unless subsurface.is_exterior

      # SHGC
      hpxml_value = Constructions.get_ufactor_shgc_adjusted_by_storms(subsurface.storm_type, subsurface.ufactor, subsurface.shgc)[1]
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{subsurface_id}' AND ColumnName='Glass SHGC'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_delta(hpxml_value, sql_value, 0.01)

      # Azimuth
      hpxml_value = subsurface.azimuth
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{subsurface_id}' AND ColumnName='Azimuth' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Tilt
      if subsurface.respond_to? :wall_idref
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{subsurface_id}' AND ColumnName='Tilt' AND Units='deg'"
        sql_value = sqlFile.execAndReturnFirstDouble(query).get
        assert_in_epsilon(90.0, sql_value, 0.01)
      elsif subsurface.respond_to? :roof_idref
        hpxml_value = nil
        hpxml.roofs.each do |roof|
          next if roof.id != subsurface.roof_idref

          hpxml_value = UnitConversions.convert(Math.atan(roof.pitch / 12.0), 'rad', 'deg')
        end
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{subsurface_id}' AND ColumnName='Tilt' AND Units='deg'"
        sql_value = sqlFile.execAndReturnFirstDouble(query).get
        assert_in_epsilon(hpxml_value, sql_value, 0.01)
      else
        flunk "Subsurface '#{subsurface_id}' should have either AttachedToWall or AttachedToRoof element."
      end
    end

    # Enclosure Doors
    hpxml.doors.each do |door|
      door_id = door.id.upcase

      if door.wall.is_exterior
        table_name = 'Exterior Door'
      else
        table_name = 'Interior Door'
      end

      # Area
      if not door.area.nil?
        hpxml_value = door.area
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{door_id}' AND ColumnName='Gross Area' AND Units='m2'"
        sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
        assert_operator(sql_value, :>, 0.01)
        assert_in_epsilon(hpxml_value, sql_value, 0.1)
      end

      # R-Value
      next if door.r_value.nil?

      if door.is_exterior
        col_name = 'U-Factor with Film'
      else
        col_name = 'U-Factor no Film'
      end
      hpxml_value = door.r_value
      if door.is_interior
        hpxml_value -= Material.AirFilmVertical.rvalue
        hpxml_value -= Material.AirFilmVertical.rvalue
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{door_id}' AND ColumnName='#{col_name}' AND Units='W/m2-K'"
      sql_value = 1.0 / UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.1)
    end

    # HVAC Load Fractions
    if (not hpxml_path.include? 'location-miami') && (not hpxml_path.include? 'location-honolulu') && (not hpxml_path.include? 'location-phoenix')
      htg_energy = results.select { |k, v| (k.include?(': Heating (MBtu)') || k.include?(': Heating Fans/Pumps (MBtu)')) && !k.include?('Load') }.map { |k, v| v }.sum(0.0)
      assert_equal(hpxml.total_fraction_heat_load_served > 0, htg_energy > 0)
    end
    clg_energy = results.select { |k, v| (k.include?(': Cooling (MBtu)') || k.include?(': Cooling Fans/Pumps (MBtu)')) && !k.include?('Load') }.map { |k, v| v }.sum(0.0)
    assert_equal(hpxml.total_fraction_cool_load_served > 0, clg_energy > 0)

    # Mechanical Ventilation
    fan_cfis = hpxml.ventilation_fans.select { |vent_mech| vent_mech.used_for_whole_building_ventilation && (vent_mech.fan_type == HPXML::MechVentTypeCFIS) }
    fan_sup = hpxml.ventilation_fans.select { |vent_mech| vent_mech.used_for_whole_building_ventilation && (vent_mech.fan_type == HPXML::MechVentTypeSupply) }
    fan_exh = hpxml.ventilation_fans.select { |vent_mech| vent_mech.used_for_whole_building_ventilation && (vent_mech.fan_type == HPXML::MechVentTypeExhaust) }
    fan_bal = hpxml.ventilation_fans.select { |vent_mech| vent_mech.used_for_whole_building_ventilation && [HPXML::MechVentTypeBalanced, HPXML::MechVentTypeERV, HPXML::MechVentTypeHRV].include?(vent_mech.fan_type) }
    vent_fan_kitchen = hpxml.ventilation_fans.select { |vent_mech| vent_mech.used_for_local_ventilation && (vent_mech.fan_location == HPXML::LocationKitchen) }
    vent_fan_bath = hpxml.ventilation_fans.select { |vent_mech| vent_mech.used_for_local_ventilation && (vent_mech.fan_location == HPXML::LocationBath) }

    if not (fan_cfis + fan_sup + fan_exh + fan_bal + vent_fan_kitchen + vent_fan_bath).empty?
      mv_energy = UnitConversions.convert(results['End Use: Electricity: Mech Vent (MBtu)'], 'MBtu', 'GJ')

      if not fan_cfis.empty?
        if (fan_sup + fan_exh + fan_bal + vent_fan_kitchen + vent_fan_bath).empty?
          # CFIS only, check for positive mech vent energy that is less than the energy if it had run 24/7
          fan_gj = fan_cfis.map { |vent_mech| UnitConversions.convert(vent_mech.unit_fan_power * vent_mech.hours_in_operation * 365.0, 'Wh', 'GJ') }.sum(0.0)
          assert_operator(mv_energy, :>, 0)
          assert_operator(mv_energy, :<, fan_gj)
        end
      else
        # Supply, exhaust, ERV, HRV, etc., check for appropriate mech vent energy
        fan_gj = 0
        if not fan_sup.empty?
          fan_gj += fan_sup.map { |vent_mech| UnitConversions.convert(vent_mech.unit_fan_power * vent_mech.hours_in_operation * 365.0, 'Wh', 'GJ') }.sum(0.0)
        end
        if not fan_exh.empty?
          fan_gj += fan_exh.map { |vent_mech| UnitConversions.convert(vent_mech.unit_fan_power * vent_mech.hours_in_operation * 365.0, 'Wh', 'GJ') }.sum(0.0)
        end
        if not fan_bal.empty?
          fan_gj += fan_bal.map { |vent_mech| UnitConversions.convert(vent_mech.unit_fan_power * vent_mech.hours_in_operation * 365.0, 'Wh', 'GJ') }.sum(0.0)
        end
        if not vent_fan_kitchen.empty?
          fan_gj += vent_fan_kitchen.map { |vent_kitchen| UnitConversions.convert(vent_kitchen.unit_fan_power * vent_kitchen.hours_in_operation * vent_kitchen.quantity * 365.0, 'Wh', 'GJ') }.sum(0.0)
        end
        if not vent_fan_bath.empty?
          fan_gj += vent_fan_bath.map { |vent_bath| UnitConversions.convert(vent_bath.unit_fan_power * vent_bath.hours_in_operation * vent_bath.quantity * 365.0, 'Wh', 'GJ') }.sum(0.0)
        end
        # Maximum error that can be caused by rounding
        assert_in_delta(mv_energy, fan_gj, 0.006)
      end
    end

    tabular_map = { HPXML::ClothesWasher => Constants.ObjectNameClothesWasher,
                    HPXML::ClothesDryer => Constants.ObjectNameClothesDryer,
                    HPXML::Refrigerator => Constants.ObjectNameRefrigerator,
                    HPXML::Dishwasher => Constants.ObjectNameDishwasher,
                    HPXML::CookingRange => Constants.ObjectNameCookingRange }

    (hpxml.clothes_washers + hpxml.clothes_dryers + hpxml.refrigerators + hpxml.dishwashers + hpxml.cooking_ranges).each do |appliance|
      next unless hpxml.water_heating_systems.size > 0

      # Location
      hpxml_value = appliance.location
      if hpxml_value.nil? || HPXML::conditioned_locations.include?(hpxml_value) || [HPXML::LocationOtherHeatedSpace, HPXML::LocationOtherMultifamilyBufferSpace, HPXML::LocationOtherNonFreezingSpace].include?(hpxml_value)
        hpxml_value = HPXML::LocationLivingSpace
      end
      tabular_value = tabular_map[appliance.class]
      query = "SELECT Value FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Zone Name' AND RowName=(SELECT RowName FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Name' AND Value='#{tabular_value.upcase}')"
      sql_value = sqlFile.execAndReturnFirstString(query).get
      assert_equal(hpxml_value.upcase, sql_value)
    end

    # Lighting
    ltg_energy = results.select { |k, v| k.include? 'End Use: Electricity: Lighting' }.map { |k, v| v }.sum(0.0)
    assert_equal(hpxml.lighting_groups.size > 0, ltg_energy > 0)

    # Get fuels
    htg_fuels = []
    htg_backup_fuels = []
    wh_fuels = []
    hpxml.heating_systems.each do |heating_system|
      if heating_system.is_heat_pump_backup_system
        htg_backup_fuels << heating_system.heating_system_fuel
      else
        htg_fuels << heating_system.heating_system_fuel
      end
    end
    hpxml.heat_pumps.each do |heat_pump|
      if heat_pump.fraction_heat_load_served > 0
        htg_backup_fuels << heat_pump.backup_heating_fuel
      end
    end
    hpxml.water_heating_systems.each do |water_heating_system|
      related_hvac = water_heating_system.related_hvac_system
      if related_hvac.nil?
        wh_fuels << water_heating_system.fuel_type
      elsif related_hvac.respond_to? :heating_system_fuel
        wh_fuels << related_hvac.heating_system_fuel
      end
    end

    is_warm_climate = false
    if ['USA_FL_Miami.Intl.AP.722020_TMY3.epw',
        'USA_HI_Honolulu.Intl.AP.911820_TMY3.epw',
        'USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw'].include? hpxml.climate_and_risk_zones.weather_station_epw_filepath
      is_warm_climate = true
    end

    # Fuel consumption checks
    [HPXML::FuelTypeNaturalGas,
     HPXML::FuelTypeOil,
     HPXML::FuelTypeKerosene,
     HPXML::FuelTypePropane,
     HPXML::FuelTypeWoodCord,
     HPXML::FuelTypeWoodPellets,
     HPXML::FuelTypeCoal].each do |fuel|
      fuel_name = fuel.split.map(&:capitalize).join(' ')
      fuel_name += ' Cord' if fuel_name == 'Wood'
      energy_htg = results.fetch("End Use: #{fuel_name}: Heating (MBtu)", 0)
      energy_hp_backup = results.fetch("End Use: #{fuel_name}: Heating Heat Pump Backup (MBtu)", 0)
      energy_dhw = results.fetch("End Use: #{fuel_name}: Hot Water (MBtu)", 0)
      energy_cd = results.fetch("End Use: #{fuel_name}: Clothes Dryer (MBtu)", 0)
      energy_cr = results.fetch("End Use: #{fuel_name}: Range/Oven (MBtu)", 0)
      if htg_fuels.include? fuel
        if (not hpxml_path.include? 'autosize') && (not is_warm_climate)
          assert_operator(energy_htg, :>, 0)
        end
      else
        assert_equal(0, energy_htg)
      end
      if htg_backup_fuels.include? fuel
        if (not hpxml_path.include? 'autosize') && (not is_warm_climate)
          assert_operator(energy_hp_backup, :>, 0)
        end
      else
        assert_equal(0, energy_hp_backup)
      end
      if wh_fuels.include? fuel
        assert_operator(energy_dhw, :>, 0)
      else
        assert_equal(0, energy_dhw)
      end
      if (hpxml.clothes_dryers.size > 0) && (hpxml.clothes_dryers[0].fuel_type == fuel)
        assert_operator(energy_cd, :>, 0)
      else
        assert_equal(0, energy_cd)
      end
      if (hpxml.cooking_ranges.size > 0) && (hpxml.cooking_ranges[0].fuel_type == fuel)
        assert_operator(energy_cr, :>, 0)
      else
        assert_equal(0, energy_cr)
      end
    end

    # Check unmet hours
    unmet_hours_htg = results.select { |k, v| k.include? 'Unmet Hours: Heating' }.map { |k, v| v }.sum(0.0)
    unmet_hours_clg = results.select { |k, v| k.include? 'Unmet Hours: Cooling' }.map { |k, v| v }.sum(0.0)
    if hpxml_path.include? 'base-hvac-undersized.xml'
      assert_operator(unmet_hours_htg, :>, 1000)
      assert_operator(unmet_hours_clg, :>, 1000)
    else
      assert_operator(unmet_hours_htg, :<, 350)
      assert_operator(unmet_hours_clg, :<, 350)
    end

    sqlFile.close
  end

  def _write_summary_results(results, csv_out)
    require 'csv'

    output_keys = []
    results.each do |xml, xml_results|
      xml_results.keys.each do |key|
        next if output_keys.include? key

        output_keys << key
      end
    end

    column_headers = ['HPXML']
    output_keys.each do |key|
      column_headers << key
    end

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

    puts "Wrote summary results to #{csv_out}."
  end

  def _write_hvac_sizing_results(all_sizing_results, csv_out)
    require 'csv'

    output_keys = nil
    all_sizing_results.each do |xml, xml_results|
      output_keys = xml_results.keys
      break
    end
    return if output_keys.nil?

    CSV.open(csv_out, 'w') do |csv|
      csv << ['HPXML'] + output_keys
      all_sizing_results.sort.each do |xml, xml_results|
        csv_row = [xml]
        output_keys.each do |key|
          csv_row << xml_results[key]
        end
        csv << csv_row
      end
    end

    puts "Wrote HVAC sizing results to #{csv_out}."
  end

  def _write_bill_results(all_bill_results, csv_out)
    require 'csv'

    output_keys = nil
    all_bill_results.each do |xml, xml_results|
      output_keys = xml_results.keys
      break
    end
    return if output_keys.nil?

    CSV.open(csv_out, 'w') do |csv|
      csv << ['HPXML'] + output_keys
      all_bill_results.sort.each do |xml, xml_results|
        csv_row = [xml]
        output_keys.each do |key|
          csv_row << xml_results[key]
        end
        csv << csv_row
      end
    end

    puts "Wrote utility bill results to #{csv_out}."
  end

  def _write_ashrae_140_results(all_results, csv_out)
    require 'csv'

    htg_loads = {}
    clg_loads = {}
    CSV.open(csv_out, 'w') do |csv|
      csv << ['Test Case', 'Annual Heating Load [MMBtu]', 'Annual Cooling Load [MMBtu]']
      all_results.sort.each do |xml, xml_results|
        next unless xml.include? 'C.xml'

        htg_load = xml_results['Load: Heating: Delivered (MBtu)'].round(2)
        csv << [File.basename(xml), htg_load, 'N/A']
        test_name = File.basename(xml, File.extname(xml))
        htg_loads[test_name] = htg_load
      end
      all_results.sort.each do |xml, xml_results|
        next unless xml.include? 'L.xml'

        clg_load = xml_results['Load: Cooling: Delivered (MBtu)'].round(2)
        csv << [File.basename(xml), 'N/A', clg_load]
        test_name = File.basename(xml, File.extname(xml))
        clg_loads[test_name] = clg_load
      end
    end

    puts "Wrote ASHRAE 140 results to #{csv_out}."
  end
end
