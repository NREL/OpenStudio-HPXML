# frozen_string_literal: true

require_relative '../../HPXMLtoOpenStudio/resources/minitest_helper'
require 'openstudio'
require 'fileutils'
require 'parallel'
require_relative '../../HPXMLtoOpenStudio/measure.rb'
require_relative 'util.rb'

class WorkflowOtherTest < Minitest::Test
  def test_run_simulation_output_formats
    # Check that the simulation produces outputs in the appropriate format
    ['csv', 'json', 'msgpack', 'csv_dview'].each do |output_format|
      rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
      xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
      command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{xml}\" --debug --hourly ALL --output-format #{output_format}"
      system(command, err: File::NULL)

      output_format = 'csv' if output_format == 'csv_dview'

      # Check for output files
      assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.msgpack'))
      assert(File.exist? File.join(File.dirname(xml), 'run', "results_annual.#{output_format}"))
      assert(File.exist? File.join(File.dirname(xml), 'run', "results_timeseries.#{output_format}"))
      assert(File.exist?(File.join(File.dirname(xml), 'run', "results_bills.#{output_format}")))
      assert(File.exist?(File.join(File.dirname(xml), 'run', "results_design_load_details.#{output_format}")))

      # Check for debug files
      osm_path = File.join(File.dirname(xml), 'run', 'in.osm')
      assert(File.exist? osm_path)
      hpxml_defaults_path = File.join(File.dirname(xml), 'run', 'in.xml')
      assert(File.exist? hpxml_defaults_path)

      next unless output_format == 'msgpack'

      # Check timeseries output isn't rounded
      require 'msgpack'
      data = MessagePack.unpack(File.read(File.join(File.dirname(xml), 'run', "results_timeseries.#{output_format}"), mode: 'rb'))
      value = data['Energy Use']['Total (kBtu)'][0]
      assert_operator((value - value.round(8)).abs, :>, 0)
    end
  end

  def test_run_simulation_epjson_input
    # Check that we can run a simulation using epJSON (instead of IDF) if requested
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{xml}\" --ep-input-format epjson"
    system(command, err: File::NULL)

    # Check for epjson file
    assert(File.exist? File.join(File.dirname(xml), 'run', 'in.epJSON'))

    # Check for output files
    assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.msgpack'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))
  end

  def test_run_simulation_idf_input
    # Check that we can run a simulation using IDF (instead of epJSON) if requested
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{xml}\" --ep-input-format idf"
    system(command, err: File::NULL)

    # Check for idf file
    assert(File.exist? File.join(File.dirname(xml), 'run', 'in.idf'))

    # Check for output files
    assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.msgpack'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))
  end

  def test_run_simulation_faster_performance
    # Run w/ --skip-validation and w/o --add-component-loads arguments
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{xml}\" --skip-validation"
    system(command, err: File::NULL)

    # Check for output files
    assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.msgpack'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))

    # Check component loads don't exist
    component_loads = {}
    CSV.read(File.join(File.dirname(xml), 'run', 'results_annual.csv'), headers: false).each do |data|
      next unless data[0].to_s.start_with? 'Component Load'

      component_loads[data[0]] = Float(data[1])
    end
    assert_equal(0, component_loads.size)
  end

  def test_run_simulation_detailed_occupancy_schedules
    [false, true].each do |debug|
      # Check that the simulation produces stochastic schedules if requested
      sample_files_path = File.join(File.dirname(__FILE__), '..', 'sample_files')
      tmp_hpxml_path = File.join(sample_files_path, 'tmp.xml')
      hpxml = HPXML.new(hpxml_path: File.join(sample_files_path, 'base.xml'))
      XMLHelper.write_file(hpxml.to_doc, tmp_hpxml_path)

      rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
      xml = File.absolute_path(tmp_hpxml_path)
      command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{xml}\" --add-stochastic-schedules"
      command += ' -d' if debug
      system(command, err: File::NULL)

      # Check for output files
      assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.msgpack'))
      assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))
      assert(File.exist? File.join(File.dirname(xml), 'run', 'in.schedules.csv'))
      assert(File.exist? File.join(File.dirname(xml), 'run', 'stochastic.csv'))

      # Check stochastic.csv headers
      schedules = CSV.read(File.join(File.dirname(xml), 'run', 'stochastic.csv'), headers: true)
      if debug
        assert(schedules.headers.include?(SchedulesFile::Columns[:Sleeping].name))
      else
        refute(schedules.headers.include?(SchedulesFile::Columns[:Sleeping].name))
      end

      # Cleanup
      File.delete(tmp_hpxml_path) if File.exist? tmp_hpxml_path
    end
  end

  def test_run_simulation_timeseries_outputs
    [true, false].each do |invalid_variable_only|
      # Check that the simulation produces timeseries with requested outputs
      rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
      xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
      command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{xml}\""
      if not invalid_variable_only
        command += ' --hourly ALL'
        command += " --hourly 'Zone People Occupant Count'"
        command += " --hourly 'Zone People Total Heating Energy'"
      end
      command += " --hourly 'Foobar Variable'" # Test invalid output variable request
      system(command, err: File::NULL)

      # Check for output files
      assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.msgpack'))
      assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))

      timeseries_output_path = File.join(File.dirname(xml), 'run', 'results_timeseries.csv')
      if not invalid_variable_only
        assert(File.exist? timeseries_output_path)
        # Check timeseries columns exist
        timeseries_rows = CSV.read(timeseries_output_path)
        assert_equal(1, timeseries_rows[0].select { |r| r == 'Time' }.size)
        assert_equal(1, timeseries_rows[0].select { |r| r == 'Zone People Occupant Count: Conditioned Space' }.size)
        assert_equal(1, timeseries_rows[0].select { |r| r == 'Zone People Total Heating Energy: Conditioned Space' }.size)
      else
        refute(File.exist? timeseries_output_path)
      end

      # Check run.log has warning about missing Foobar Variable
      assert(File.exist? File.join(File.dirname(xml), 'run', 'run.log'))
      log_lines = File.readlines(File.join(File.dirname(xml), 'run', 'run.log')).map(&:strip)
      assert(log_lines.include? "Warning: Request for output variable 'Foobar Variable' returned no key values.")
    end
  end

  def test_run_simulation_mixed_timeseries_frequencies
    # Check that we can correctly skip the EnergyPlus simulation and reporting measures
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{xml}\" --timestep weather --hourly enduses --daily temperatures --monthly ALL --monthly 'Zone People Total Heating Energy'"
    system(command, err: File::NULL)

    # Check for output files
    assert(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.msgpack'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_timeseries_timestep.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_timeseries_hourly.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_timeseries_daily.csv'))
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_timeseries_monthly.csv'))

    # Check timeseries columns exist
    { 'timestep' => ['Weather:'],
      'hourly' => ['End Use:'],
      'daily' => ['Temperature:'],
      'monthly' => ['End Use:', 'Fuel Use:', 'Zone People Total Heating Energy:'] }.each do |freq, col_names|
      timeseries_rows = CSV.read(File.join(File.dirname(xml), 'run', "results_timeseries_#{freq}.csv"))
      assert_equal(1, timeseries_rows[0].select { |r| r == 'Time' }.size)
      col_names.each do |col_name|
        assert(timeseries_rows[0].select { |r| r.start_with? col_name }.size > 0)
      end
    end
  end

  def test_run_simulation_skip_simulation
    # Check that we can correctly skip the EnergyPlus simulation and reporting measures
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{xml}\" --skip-simulation"
    system(command, err: File::NULL)

    # Check for in.xml HPXML file
    assert(File.exist? File.join(File.dirname(xml), 'run', 'in.xml'))

    # Check for annual results (design load/capacities only)
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))

    # Check for no idf or output file
    refute(File.exist? File.join(File.dirname(xml), 'run', 'in.idf'))
    refute(File.exist? File.join(File.dirname(xml), 'run', 'eplusout.msgpack'))
  end

  def test_run_defaulted_in_xml
    # Check that if we simulate the in.xml file (HPXML w/ defaults), we get
    # the same results as the original HPXML.

    # Run base.xml
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{xml}\""
    system(command, err: File::NULL)
    assert(File.exist? File.join(File.dirname(xml), 'run', 'results_annual.csv'))
    base_results = CSV.read(File.join(File.dirname(xml), 'run', 'results_annual.csv'))

    # Run in.xml (generated from base.xml)
    xml2 = File.join(File.dirname(xml), 'run', 'in.xml')
    command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{xml2}\""
    system(command, err: File::NULL)
    assert(File.exist? File.join(File.dirname(xml2), 'run', 'results_annual.csv'))
    default_results = CSV.read(File.join(File.dirname(xml2), 'run', 'results_annual.csv'))

    # Check two output files are identical
    assert_equal(base_results, default_results)
  end

  def test_template_osws
    # Check that simulation works using template-*.osw
    require 'json'

    ['template-run-hpxml.osw',
     'template-run-hpxml-with-stochastic-occupancy.osw',
     'template-run-hpxml-with-stochastic-occupancy-subset.osw',
     'template-build-and-run-hpxml-with-stochastic-occupancy.osw'].each do |osw_name|
      osw_path = File.join(File.dirname(__FILE__), '..', osw_name)

      # Create derivative OSW for testing
      osw_path_test = osw_path.gsub('.osw', '_test.osw')
      FileUtils.cp(osw_path, osw_path_test)

      # Turn on debug mode
      json = JSON.parse(File.read(osw_path_test), symbolize_names: true)
      measure_index = json[:steps].find_index { |m| m[:measure_dir_name] == 'HPXMLtoOpenStudio' }
      json[:steps][measure_index][:arguments][:debug] = true

      if Dir.exist? File.join(File.dirname(__FILE__), '..', '..', 'project')
        # CI checks out the repo as "project", so update dir name
        json[:steps][measure_index][:measure_dir_name] = 'project'
      end

      File.open(osw_path_test, 'w') do |f|
        f.write(JSON.pretty_generate(json))
      end

      command = "\"#{OpenStudio.getOpenStudioCLI}\" run -w \"#{osw_path_test}\""
      system(command, err: File::NULL)

      # Check for output files
      assert(File.exist? File.join(File.dirname(osw_path_test), 'run', 'eplusout.msgpack'))
      assert(File.exist? File.join(File.dirname(osw_path_test), 'run', 'results_annual.csv'))

      # Check for debug files
      assert(File.exist? File.join(File.dirname(osw_path_test), 'run', 'in.osm'))
      hpxml_defaults_path = File.join(File.dirname(osw_path_test), 'run', 'in.xml')
      assert(File.exist? hpxml_defaults_path)

      # Cleanup
      File.delete(osw_path_test)
      xml_path_test = File.join(File.dirname(__FILE__), '..', 'run', 'built.xml')
      File.delete(xml_path_test) if File.exist?(xml_path_test)
      xml_path_test = File.join(File.dirname(__FILE__), '..', 'run', 'built-stochastic-schedules.xml')
      File.delete(xml_path_test) if File.exist?(xml_path_test)
    end
  end

  def test_mf_building_simulations
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    sample_files_path = File.join(File.dirname(__FILE__), '..', 'sample_files')
    csv_output_path = File.join(sample_files_path, 'run', 'results_annual.csv')
    bills_csv_path = File.join(sample_files_path, 'run', 'results_bills.csv')
    run_log = File.join(sample_files_path, 'run', 'run.log')
    dryer_warning_msg = 'Warning: No clothes dryer specified, the model will not include clothes dryer energy use.'

    [true, false].each do |whole_sfa_or_mf_building_sim|
      tmp_hpxml_path = File.join(sample_files_path, 'tmp.xml')
      hpxml = HPXML.new(hpxml_path: File.join(sample_files_path, 'base-bldgtype-mf-whole-building.xml'))
      hpxml.header.whole_sfa_or_mf_building_sim = whole_sfa_or_mf_building_sim
      XMLHelper.write_file(hpxml.to_doc, tmp_hpxml_path)

      # Check for when building-id argument is not provided
      command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{tmp_hpxml_path}\""
      system(command, err: File::NULL)
      if whole_sfa_or_mf_building_sim
        # Simulation should be successful
        assert_equal(true, File.exist?(csv_output_path))
        assert_equal(true, File.exist?(bills_csv_path))

        # Check that we have multiple warnings, one for each Building element
        assert_equal(6, File.readlines(run_log).select { |l| l.include? dryer_warning_msg }.size)
      else
        # Simulation should be unsuccessful (building_id or WholeSFAorMFBuildingSimulation=true is required)
        assert_equal(false, File.exist?(csv_output_path))
        assert_equal(false, File.exist?(bills_csv_path))
        assert_equal(1, File.readlines(run_log).select { |l| l.include? 'Multiple Building elements defined in HPXML file; provide Building ID argument or set WholeSFAorMFBuildingSimulation=true.' }.size)
      end

      # Check for when building-id argument is provided
      command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{tmp_hpxml_path}\" --building-id MyBuilding_2"
      system(command, err: File::NULL)
      if whole_sfa_or_mf_building_sim
        # Simulation should be successful (WholeSFAorMFBuildingSimulation is true, so building-id argument is ignored)
        # Note: We don't want to override WholeSFAorMFBuildingSimulation because we may have Schematron validation based on it, and it would be wrong to
        # validate the HPXML for one use case (whole building model) while running it for a different unit case (individual dwelling unit model).
        assert_equal(true, File.exist?(csv_output_path))
        assert_equal(true, File.exist?(bills_csv_path))
        assert_equal(1, File.readlines(run_log).select { |l| l.include? 'Multiple Building elements defined in HPXML file and WholeSFAorMFBuildingSimulation=true; Building ID argument will be ignored.' }.size)
      else
        # Simulation should be successful
        assert_equal(true, File.exist?(csv_output_path))
        assert_equal(true, File.exist?(bills_csv_path))

        # Check that we have exactly one warning (i.e., check we are only validating a single Building element against schematron)
        assert_equal(1, File.readlines(run_log).select { |l| l.include? dryer_warning_msg }.size)
      end

      next unless not whole_sfa_or_mf_building_sim

      # Check for when building-id argument is invalid (incorrect building ID)
      # Simulation should be unsuccessful
      command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{rb_path}\" -x \"#{tmp_hpxml_path}\" --building-id MyFoo"
      system(command, err: File::NULL)
      assert_equal(false, File.exist?(csv_output_path))
      assert_equal(false, File.exist?(bills_csv_path))
      assert_equal(1, File.readlines(run_log).select { |l| l.include? "Could not find Building element with ID 'MyFoo'." }.size)

      # Cleanup
      File.delete(tmp_hpxml_path) if File.exist? tmp_hpxml_path
    end
  end

  def test_release_zips
    # Check release zips successfully created
    top_dir = File.join(File.dirname(__FILE__), '..', '..')
    command = "\"#{OpenStudio.getOpenStudioCLI}\" \"#{File.join(top_dir, 'tasks.rb')}\" create_release_zips"
    system(command)
    assert_equal(1, Dir["#{top_dir}/*.zip"].size)

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
      command = "\"#{OpenStudio.getOpenStudioCLI}\" OpenStudio-HPXML/workflow/run_simulation.rb -x OpenStudio-HPXML/workflow/sample_files/base.xml"
      system(command)
      assert(File.exist? 'OpenStudio-HPXML/workflow/sample_files/run/results_annual.csv')

      File.delete(zip_path)
      rm_path('OpenStudio-HPXML')
    end
  end
end
