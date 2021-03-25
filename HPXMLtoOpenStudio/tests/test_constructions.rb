# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'

class HPXMLtoOpenStudioConstructionsTest < MiniTest::Test
  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def _get_ems_values(ems_objects, name)
    values = {}
    ems_objects.each do |ems_object|
      next unless ems_object.name.to_s.include? name.gsub(' ', '_')

      ems_object.lines.each do |line|
        next unless line.downcase.start_with? 'set'

        lhs, rhs = line.split('=')
        lhs = lhs.gsub('Set', '').gsub('set', '').strip
        rhs = rhs.gsub(',', '').gsub(';', '').strip
        values[lhs] = [] if values[lhs].nil?
        # eg. "Q = Q + 1.5"
        if rhs.include? '+'
          rhs_els = rhs.split('+')
          rhs = rhs_els.map { |s| s.to_f }.sum(0.0)
        elsif rhs.include? '*'
          rhs_els = rhs.split('*')
          rhs = rhs_els.map { |s| s.to_f }.reject(&:zero?).inject(:*)
        else
          rhs = rhs.to_f
        end
        values[lhs] << rhs
      end
    end
    assert_operator(values.size, :>, 0)
    return values
  end

  def test_windows
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check window properties
    hpxml.windows.each do |window|
      os_window = model.getSubSurfaces.select { |w| w.name.to_s == window.id }[0]
      os_simple_glazing = os_window.construction.get.to_LayeredConstruction.get.getLayer(0).to_SimpleGlazing.get

      assert_equal(window.shgc, os_simple_glazing.solarHeatGainCoefficient)
      assert_in_epsilon(window.ufactor, UnitConversions.convert(os_simple_glazing.uFactor, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)'), 0.001)
    end
  end

  def test_windows_shading
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-enclosure-windows-shading.xml'))
    model, hpxml = _test_measure(args_hash)

    summer_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('June'), 1, model.yearDescription.get.assumedYear)
    winter_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, model.yearDescription.get.assumedYear)

    hpxml.windows.each do |window|
      sf_summer = window.interior_shading_factor_summer
      sf_winter = window.interior_shading_factor_winter
      sf_summer *= window.exterior_shading_factor_summer unless window.exterior_shading_factor_summer.nil?
      sf_winter *= window.exterior_shading_factor_winter unless window.exterior_shading_factor_winter.nil?

      # Check shading transmittance for sky beam and sky diffuse
      os_shading_surface = model.getShadingSurfaces.select { |ss| ss.name.to_s.start_with? window.id }[0]
      if (sf_summer == 1) && (sf_winter == 1)
        assert_nil(os_shading_surface) # No shading
      else
        refute_nil(os_shading_surface) # Shading
        summer_transmittance = os_shading_surface.transmittanceSchedule.get.to_ScheduleRuleset.get.getDaySchedules(summer_date, summer_date).map { |ds| ds.values.sum }.sum
        winter_transmittance = os_shading_surface.transmittanceSchedule.get.to_ScheduleRuleset.get.getDaySchedules(winter_date, winter_date).map { |ds| ds.values.sum }.sum
        assert_equal(sf_summer, summer_transmittance)
        assert_equal(sf_winter, winter_transmittance)
      end

      # Check subsurface view factor to ground
      subsurface_view_factor = 0.5
      os_window = model.getSubSurfaces.select { |w| w.name.to_s == window.id }[0]
      program_values = _get_ems_values(model.getEnergyManagementSystemPrograms, "fixedwindow view factor to ground program")
      assert_equal(subsurface_view_factor, program_values["#{os_window.name.to_s}_actuator"][0])
    end
  end

  def test_skylights
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-enclosure-skylights.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check skylight properties
    hpxml.skylights.each do |skylight|
      os_skylight = model.getSubSurfaces.select { |w| w.name.to_s == skylight.id }[0]
      os_simple_glazing = os_skylight.construction.get.to_LayeredConstruction.get.getLayer(0).to_SimpleGlazing.get

      assert_equal(skylight.shgc, os_simple_glazing.solarHeatGainCoefficient)
      assert_in_epsilon(skylight.ufactor / 1.2, UnitConversions.convert(os_simple_glazing.uFactor, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)'), 0.001)
    end
  end

  def test_skylights_shading
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-enclosure-skylights-shading.xml'))
    model, hpxml = _test_measure(args_hash)

    summer_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('June'), 1, model.yearDescription.get.assumedYear)
    winter_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, model.yearDescription.get.assumedYear)
    
    hpxml.skylights.each do |skylight|
      sf_summer = skylight.interior_shading_factor_summer
      sf_winter = skylight.interior_shading_factor_winter
      sf_summer *= skylight.exterior_shading_factor_summer unless skylight.exterior_shading_factor_summer.nil?
      sf_winter *= skylight.exterior_shading_factor_winter unless skylight.exterior_shading_factor_winter.nil?

      # Check shading transmittance for sky beam and sky diffuse
      os_shading_surface = model.getShadingSurfaces.select { |ss| ss.name.to_s.start_with? skylight.id }[0]
      if (sf_summer == 1) && (sf_winter == 1)
        assert_nil(os_shading_surface) # No shading
      else
        refute_nil(os_shading_surface) # Shading
        summer_transmittance = os_shading_surface.transmittanceSchedule.get.to_ScheduleRuleset.get.getDaySchedules(summer_date, summer_date).map { |ds| ds.values.sum }.sum
        winter_transmittance = os_shading_surface.transmittanceSchedule.get.to_ScheduleRuleset.get.getDaySchedules(winter_date, winter_date).map { |ds| ds.values.sum }.sum
        assert_equal(sf_summer, summer_transmittance)
        assert_equal(sf_winter, winter_transmittance)
      end

      # Check subsurface view factor to ground
      subsurface_view_factor = 0.05 # 6:12 pitch
      os_skylight = model.getSubSurfaces.select { |w| w.name.to_s == skylight.id }[0]
      program_values = _get_ems_values(model.getEnergyManagementSystemPrograms, "skylight view factor to ground program")
      assert_equal(subsurface_view_factor, program_values["#{os_skylight.name.to_s}_actuator"][0])
    end
  end

  def _test_measure(args_hash)
    # create an instance of the measure
    measure = HPXMLtoOpenStudio.new

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    model = OpenStudio::Model::Model.new

    # get arguments
    args_hash['output_dir'] = 'tests'
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
    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)

    hpxml = HPXML.new(hpxml_path: args_hash['hpxml_path'])

    File.delete(File.join(File.dirname(__FILE__), 'in.xml'))

    return model, hpxml
  end
end
