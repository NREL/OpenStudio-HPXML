# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'
require_relative 'util.rb'

class HPXMLtoOpenStudioEnclosureTest < MiniTest::Test
  def setup
    @root_path = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
    @sample_files_path = File.join(@root_path, 'workflow', 'sample_files')
    @tmp_hpxml_path = File.join(@sample_files_path, 'tmp.xml')
    @tmp_output_path = File.join(@sample_files_path, 'tmp_output')
    FileUtils.mkdir_p(@tmp_output_path)
  end

  def teardown
    File.delete(@tmp_hpxml_path) if File.exist? @tmp_hpxml_path
    FileUtils.rm_rf(@tmp_output_path)
  end

  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def test_roofs
    # TODO
  end

  def test_rim_joists
    # TODO
  end

  def test_walls
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(@tmp_hpxml_path)

    air_films = Material.AirFilmOutside.rvalue + Material.AirFilmVertical.rvalue

    # Wood Stud wall
    walls_values = [{ assembly_r: 0.1, layer_names: ['wall stud and cavity'] },
                    { assembly_r: 5.0 + air_films, layer_names: ['osb sheathing', 'wall stud and cavity'] },
                    { assembly_r: 20.0 + air_films, layer_names: ['wall rigid ins', 'osb sheathing', 'wall stud and cavity'] }]

    hpxml = _create_hpxml('base.xml')
    walls_values.each do |wall_values|
      hpxml.walls[0].insulation_assembly_r_value = wall_values[:assembly_r]
      XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
      model, hpxml = _test_measure(args_hash)

      expected_layer_names = wall_values[:layer_names]
      if hpxml.walls[0].siding != HPXML::SidingTypeNone # Add exterior finish
        expected_layer_names = [hpxml.walls[0].siding] + expected_layer_names
      end
      if hpxml.walls[0].interior_finish_type != HPXML::InteriorFinishNone # Add interior finish
        expected_layer_names << hpxml.walls[0].interior_finish_type
      end

      # Check wall properties
      os_wall = model.getSurfaces.select { |w| w.name.to_s.start_with? "#{hpxml.walls[0].id}:" }[0]
      os_construction = os_wall.construction.get.to_LayeredConstruction.get
      _check_layered_construction(hpxml.walls[0], os_construction, expected_layer_names)
    end

    walls_values = [
      # CMU wall
      [{ assembly_r: 0.1, layer_names: ['concrete block'] },
       { assembly_r: 5.0 + air_films, layer_names: ['wall rigid ins', 'concrete block'] },
       { assembly_r: 20.0 + air_films, layer_names: ['wall rigid ins', 'osb sheathing', 'concrete block'] }],
      # Double Stud wall
      [{ assembly_r: 0.1, layer_names: ['wall stud and cavity', 'wall cavity', 'wall stud and cavity'] },
       { assembly_r: 5.0 + air_films, layer_names: ['osb sheathing', 'wall stud and cavity', 'wall cavity', 'wall stud and cavity'] },
       { assembly_r: 20.0 + air_films, layer_names: ['osb sheathing', 'wall stud and cavity', 'wall cavity', 'wall stud and cavity'] }],
      # ICF wall
      [{ assembly_r: 0.1, layer_names: ['wall ins form', 'wall concrete', 'wall ins form'] },
       { assembly_r: 5.0 + air_films, layer_names: ['osb sheathing', 'wall ins form', 'wall concrete', 'wall ins form'] },
       { assembly_r: 20.0 + air_films, layer_names: ['osb sheathing', 'wall ins form', 'wall concrete', 'wall ins form'] }],
      # Log wall
      [{ assembly_r: 0.1, layer_names: ['wall layer'] },
       { assembly_r: 5.0 + air_films, layer_names: ['osb sheathing', 'wall layer'] },
       { assembly_r: 20.0 + air_films, layer_names: ['wall rigid ins', 'osb sheathing', 'wall layer'] }],
      # SIP wall
      [{ assembly_r: 0.1, layer_names: ['wall spline layer', 'wall ins layer', 'wall spline layer', 'osb sheathing'] },
       { assembly_r: 5.0 + air_films, layer_names: ['osb sheathing', 'wall spline layer', 'wall ins layer', 'wall spline layer', 'osb sheathing'] },
       { assembly_r: 20.0 + air_films, layer_names: ['osb sheathing', 'wall spline layer', 'wall ins layer', 'wall spline layer', 'osb sheathing'] }],
      # Solid Concrete wall
      [{ assembly_r: 0.1, layer_names: ['wall layer'] },
       { assembly_r: 5.0 + air_films, layer_names: ['osb sheathing', 'wall layer'] },
       { assembly_r: 20.0 + air_films, layer_names: ['wall rigid ins', 'osb sheathing', 'wall layer'] }],
      # Steel frame wall
      [{ assembly_r: 0.1, layer_names: ['wall stud and cavity'] },
       { assembly_r: 5.0 + air_films, layer_names: ['osb sheathing', 'wall stud and cavity'] },
       { assembly_r: 20.0 + air_films, layer_names: ['wall rigid ins', 'osb sheathing', 'wall stud and cavity'] }],
      # Stone wall
      [{ assembly_r: 0.1, layer_names: ['wall layer'] },
       { assembly_r: 5.0 + air_films, layer_names: ['osb sheathing', 'wall layer'] },
       { assembly_r: 20.0 + air_films, layer_names: ['wall rigid ins', 'osb sheathing', 'wall layer'] }],
      # Straw Bale wall
      [{ assembly_r: 0.1, layer_names: ['wall layer'] },
       { assembly_r: 5.0 + air_films, layer_names: ['osb sheathing', 'wall layer'] },
       { assembly_r: 20.0 + air_films, layer_names: ['wall rigid ins', 'osb sheathing', 'wall layer'] }],
      # Structural Brick wall
      [{ assembly_r: 0.1, layer_names: ['wall layer'] },
       { assembly_r: 5.0 + air_films, layer_names: ['osb sheathing', 'wall layer'] },
       { assembly_r: 20.0 + air_films, layer_names: ['wall rigid ins', 'osb sheathing', 'wall layer'] }],
      # Adobe wall
      [{ assembly_r: 0.1, layer_names: ['wall layer'] },
       { assembly_r: 5.0 + air_films, layer_names: ['osb sheathing', 'wall layer'] },
       { assembly_r: 20.0 + air_films, layer_names: ['wall rigid ins', 'osb sheathing', 'wall layer'] }],

    ]

    hpxml = _create_hpxml('base-enclosure-walltypes.xml')
    for i in 0..hpxml.walls.size - 2
      walls_values[i].each do |wall_values|
        hpxml.walls[i].insulation_assembly_r_value = wall_values[:assembly_r]
        XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
        model, hpxml = _test_measure(args_hash)

        expected_layer_names = wall_values[:layer_names]
        if hpxml.walls[i].siding != HPXML::SidingTypeNone # Add exterior finish
          expected_layer_names = [hpxml.walls[i].siding] + expected_layer_names
        end
        if hpxml.walls[i].interior_finish_type != HPXML::InteriorFinishNone # Add interior finish
          expected_layer_names << hpxml.walls[i].interior_finish_type
        end

        # Check wall properties
        os_wall = model.getSurfaces.select { |w| w.name.to_s.start_with? "#{hpxml.walls[i].id}:" }[0]
        os_construction = os_wall.construction.get.to_LayeredConstruction.get
        _check_layered_construction(hpxml.walls[i], os_construction, expected_layer_names)
      end
    end
  end

  def test_foundation_walls
    # TODO
  end

  def test_frame_floors
    # TODO
  end

  def test_slabs
    # TODO
  end

  def test_windows
    # Window properties
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

    # Window shading
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
      window_actuator = model.getEnergyManagementSystemActuators.select { |w| w.actuatedComponent.get.name.to_s == window.id }[0]
      program_values = get_ems_values(model.getEnergyManagementSystemPrograms, 'fixedwindow view factor to ground program')
      assert_equal(subsurface_view_factor, program_values["#{window_actuator.name.to_s}"][0])
    end
  end

  def test_skylights
    # Skylight properties
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

    # Skylight shading
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
      skylight_actuator = model.getEnergyManagementSystemActuators.select { |w| w.actuatedComponent.get.name.to_s == skylight.id }[0]
      program_values = get_ems_values(model.getEnergyManagementSystemPrograms, 'skylight view factor to ground program')
      assert_equal(subsurface_view_factor, program_values["#{skylight_actuator.name.to_s}"][0])
    end
  end

  def test_doors
    # TODO
  end

  def _check_layered_construction(hpxml_surface, os_construction, expected_layer_names)
    # Check exterior solar absorptance and emittance
    exterior_layer = os_construction.getLayer(0).to_OpaqueMaterial.get
    assert_equal(hpxml_surface.solar_absorptance, exterior_layer.solarAbsorptance)
    assert_equal(hpxml_surface.emittance, exterior_layer.thermalAbsorptance)

    # Check interior finish solar absorptance and emittance
    if hpxml_surface.interior_finish_type != HPXML::InteriorFinishNone
      interior_layer = os_construction.getLayer(os_construction.numLayers - 1).to_OpaqueMaterial.get
      assert_equal(0.6, interior_layer.solarAbsorptance)
      assert_equal(0.9, interior_layer.thermalAbsorptance)
    end

    # Check for appropriate layers
    assert_equal(expected_layer_names.size, os_construction.numLayers)
    for i in 0..os_construction.numLayers - 1
      if not os_construction.getLayer(i).name.to_s.start_with? expected_layer_names[i]
        puts "'#{os_construction.getLayer(i).name}' does not start with '#{expected_layer_names[i]}'"
      end
      assert(os_construction.getLayer(i).name.to_s.start_with? expected_layer_names[i])
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

    hpxml = HPXML.new(hpxml_path: File.join(File.dirname(__FILE__), 'in.xml'))

    File.delete(File.join(File.dirname(__FILE__), 'in.xml'))

    return model, hpxml
  end

  def _create_hpxml(hpxml_name)
    return HPXML.new(hpxml_path: File.join(@sample_files_path, hpxml_name))
  end
end
