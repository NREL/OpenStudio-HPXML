# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'

class HPXMLtoOpenStudioElectricPanelTest < Minitest::Test
  def setup
    @root_path = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
    @sample_files_path = File.join(@root_path, 'workflow', 'sample_files')
    @tmp_hpxml_path = File.join(@sample_files_path, 'tmp.xml')
  end

  def teardown
    # File.delete(@tmp_hpxml_path) if File.exist? @tmp_hpxml_path
    File.delete(File.join(File.dirname(__FILE__), 'results_annual.csv')) if File.exist? File.join(File.dirname(__FILE__), 'results_annual.csv')
    File.delete(File.join(File.dirname(__FILE__), 'results_panel.csv')) if File.exist? File.join(File.dirname(__FILE__), 'results_panel.csv')
    File.delete(File.join(File.dirname(__FILE__), 'results_design_load_details.csv')) if File.exist? File.join(File.dirname(__FILE__), 'results_design_load_details.csv')
  end

  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def test_upgrade
    args_hash = { 'hpxml_path' => File.absolute_path(@tmp_hpxml_path) }
    hpxml, _hpxml_bldg = _create_hpxml('base-detailed-electric-panel.xml')
    XMLHelper.write_file(hpxml.to_doc(), @tmp_hpxml_path)
    _model, hpxml, hpxml_bldg = _test_measure(args_hash)
    electric_panel = hpxml_bldg.electric_panels[0]

    assert_in_epsilon(9762, electric_panel.capacity_total_watts[0], 0.01)
    assert_in_epsilon(9762 / Float(HPXML::ElectricPanelVoltage240), electric_panel.capacity_total_amps[0], 0.01)
    assert_in_epsilon(electric_panel.max_current_rating - 9762 / Float(HPXML::ElectricPanelVoltage240), electric_panel.capacity_headroom_amps[0], 0.01)
    assert_equal(11, electric_panel.breaker_spaces_total)
    assert_equal(6, electric_panel.breaker_spaces_occupied)
    assert_equal(11 - 6, electric_panel.breaker_spaces_headroom)

    # Upgrade
    electric_panel.headroom_breaker_spaces = nil
    electric_panel.total_breaker_spaces = 12
    panel_loads = electric_panel.panel_loads
    pl = panel_loads.find { |pl| pl.type == HPXML::ElectricPanelLoadTypeHeating }
    pl.power = 17942
    pl.addition = true
    pl = panel_loads.find { |pl| pl.type == HPXML::ElectricPanelLoadTypeCooling }
    pl.power = 17942
    pl.addition = true
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeWaterHeater,
                    power: 4500,
                    voltage: HPXML::ElectricPanelVoltage240,
                    breaker_spaces: 2,
                    addition: true,
                    system_idrefs: [hpxml_bldg.water_heating_systems[0].id])
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeClothesDryer,
                    power: 5760,
                    voltage: HPXML::ElectricPanelVoltage120,
                    breaker_spaces: 2,
                    addition: true,
                    system_idrefs: [hpxml_bldg.clothes_dryers[0].id])
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeRangeOven,
                    power: 12000,
                    voltage: HPXML::ElectricPanelVoltage240,
                    breaker_spaces: 2,
                    addition: true,
                    system_idrefs: [hpxml_bldg.cooking_ranges[0].id])
    hpxml_bldg.plug_loads.add(id: "PlugLoad#{hpxml_bldg.plug_loads.size + 1}",
                              plug_load_type: HPXML::PlugLoadTypeElectricVehicleCharging)
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeElectricVehicleCharging,
                    power: 1650,
                    voltage: HPXML::ElectricPanelVoltage120,
                    breaker_spaces: 1,
                    addition: true,
                    system_idrefs: [hpxml_bldg.plug_loads[-1].id])
    XMLHelper.write_file(hpxml.to_doc(), @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)
    electric_panel = hpxml_bldg.electric_panels[0]

    assert_in_epsilon(35851, electric_panel.capacity_total_watts[0], 0.01)
    assert_in_epsilon(35851 / Float(HPXML::ElectricPanelVoltage240), electric_panel.capacity_total_amps[0], 0.01)
    assert_in_epsilon(electric_panel.max_current_rating - 35851 / Float(HPXML::ElectricPanelVoltage240), electric_panel.capacity_headroom_amps[0], 0.01)
    assert_equal(12, electric_panel.breaker_spaces_total)
    assert_equal(13, electric_panel.breaker_spaces_occupied)
    assert_equal(12 - 13, electric_panel.breaker_spaces_headroom)
  end

  def test_low_load
    args_hash = { 'hpxml_path' => File.absolute_path(@tmp_hpxml_path) }
    hpxml, hpxml_bldg = _create_hpxml('base.xml')

    hpxml.header.panel_calculation_types = [HPXML::ElectricPanelLoadCalculationType2023LoadBased]
    panel_loads = hpxml_bldg.electric_panels[0].panel_loads
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeHeating, power: 0, system_idrefs: [hpxml_bldg.heating_systems[0].id])
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeCooling, power: 0, system_idrefs: [hpxml_bldg.cooling_systems[0].id])
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeWaterHeater, power: 0, system_idrefs: [hpxml_bldg.water_heating_systems[0].id])
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeClothesDryer, power: 0, system_idrefs: [hpxml_bldg.clothes_dryers[0].id])
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeDishwasher, power: 0, system_idrefs: [hpxml_bldg.dishwashers[0].id])
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeRangeOven, power: 0, system_idrefs: [hpxml_bldg.cooking_ranges[0].id])
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeLighting, power: 500)
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeKitchen, power: 1000)
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeLaundry, power: 1500) # +1 breaker space
    panel_loads.add(type: HPXML::ElectricPanelLoadTypeOther, power: 2000) # +1 breaker space

    XMLHelper.write_file(hpxml.to_doc(), @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)
    electric_panel = hpxml_bldg.electric_panels[0]

    assert_in_epsilon(5000, electric_panel.capacity_total_watts[0], 0.01)
    assert_in_epsilon(5000 / Float(HPXML::ElectricPanelVoltage240), electric_panel.capacity_total_amps[0], 0.01)
    assert_in_epsilon(electric_panel.max_current_rating - 5000 / Float(HPXML::ElectricPanelVoltage240), electric_panel.capacity_headroom_amps[0], 0.01)
    assert_equal(2, electric_panel.breaker_spaces_total)
    assert_equal(2, electric_panel.breaker_spaces_occupied)
    assert_equal(0, electric_panel.breaker_spaces_headroom)
  end

  def test_hvac_configurations
    args_hash = { 'hpxml_path' => File.absolute_path(@tmp_hpxml_path),
                  'skip_validation' => true }

    test_name = 'Gas furnace only'
    hpxml, _hpxml_bldg = _create_hpxml('base-hvac-furnace-gas-only.xml', test_name)
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 295, 1)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 0, 0)

    test_name = 'Electric furnace only'
    hpxml, _hpxml_bldg = _create_hpxml('base-hvac-furnace-elec-only.xml', test_name)
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 295 + 10766, 2)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 0, 0)

    test_name = 'Large electric furnace only'
    hpxml, hpxml_bldg = _create_hpxml('base-hvac-furnace-elec-only.xml', test_name)
    hpxml_bldg.heating_systems[0].heating_capacity = 48000
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 393 + 14355, 4)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 0, 0)

    test_name = 'Gas furnace + central air conditioner'
    hpxml, _hpxml_bldg = _create_hpxml('base.xml', test_name)
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 295, 1)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 300 + 3998, 2)

    test_name = 'Electric furnace + central air conditioner'
    hpxml, _hpxml_bldg = _create_hpxml('base-hvac-furnace-elec-central-ac-1-speed.xml', test_name)
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 295 + 10551, 2)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 300 + 3998, 2)

    test_name = 'Large electric furnace + central air conditioner'
    hpxml, hpxml_bldg = _create_hpxml('base-hvac-furnace-elec-central-ac-1-speed.xml', test_name)
    hpxml_bldg.heating_systems[0].heating_capacity = 48000
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 393 + 14067, 4)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 300 + 3998, 2)

    test_name = 'Central air conditioner only'
    hpxml, _hpxml_bldg = _create_hpxml('base-hvac-central-ac-only-1-speed.xml', test_name)
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 0, 0)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 400 + 3998, 2)

    test_name = 'Large central air conditioner only'
    hpxml, hpxml_bldg = _create_hpxml('base-hvac-central-ac-only-1-speed.xml', test_name)
    hpxml_bldg.cooling_systems[0].cooling_capacity = 48000
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 0, 0)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 800 + 7604, 2)

    test_name = 'Gas boiler only'
    hpxml, _hpxml_bldg = _create_hpxml('base-hvac-boiler-gas-only.xml', test_name)
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 96, 1)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 0, 0)

    test_name = 'Electric boiler only'
    hpxml, _hpxml_bldg = _create_hpxml('base-hvac-boiler-elec-only.xml', test_name)
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 82 + 10766, 2)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 0, 0)

    test_name = 'Large electric boiler only'
    hpxml, hpxml_bldg = _create_hpxml('base-hvac-boiler-elec-only.xml', test_name)
    hpxml_bldg.heating_systems[0].heating_capacity = 48000
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 82 + 14355, 4)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 0, 0)

    test_name = 'Gas boiler + central air conditioner'
    hpxml, _hpxml_bldg = _create_hpxml('base-hvac-boiler-gas-central-ac-1-speed.xml', test_name)
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 96, 1)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 400 + 3998, 2)

    test_name = 'Electric boiler + central air conditioner'
    hpxml, hpxml_bldg = _create_hpxml('base-hvac-boiler-gas-central-ac-1-speed.xml', test_name)
    hpxml_bldg.heating_systems[0].heating_system_fuel = HPXML::FuelTypeElectricity
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 96 + 11468, 2)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 400 + 3998, 2)

    test_name = 'Large electric boiler + central air conditioner'
    hpxml, hpxml_bldg = _create_hpxml('base-hvac-boiler-gas-central-ac-1-speed.xml', test_name)
    hpxml_bldg.heating_systems[0].heating_capacity = 48000
    hpxml_bldg.heating_systems[0].heating_system_fuel = HPXML::FuelTypeElectricity
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 96 + 15291, 4)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 400 + 3998, 2)

    test_name = 'ASHP w/out backup'
    hpxml, hpxml_bldg = _create_hpxml('base-hvac-air-to-air-heat-pump-1-speed.xml', test_name)
    hpxml_bldg.heat_pumps[0].backup_heating_capacity = 0
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeHeating, 561 + 5801, 4)
    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeCooling, 600 + 5801, 0)

    # ASHP w/integrated backup

    # ASHP w/integrated switchover

    # ASHP w/separate backup

    # ASHP w/separate switchover

    # Ducted MSHP w/out backup

    # Ducted MSHP w/integrated backup

    # Ducted MSHP w/integrated switchover

    # Ducted MSHP w/separate backup

    # Ducted MSHP w/separate switchover

    # Ductless MSHP w/out backup

    # Ductless MSHP w/integrated backup

    # Ductless MSHP w/integrated switchover

    # Ductless MSHP w/separate backup

    # Ductless MSHP w/separate switchover
  end

  def test_wh_configurations
    args_hash = { 'hpxml_path' => File.absolute_path(@tmp_hpxml_path),
                  'skip_validation' => true }

    test_name = 'Electric storage'
    hpxml, _hpxml_bldg = _create_hpxml('base.xml', test_name)
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeWaterHeater, 5500, 2)

    test_name = 'Electric tankless'
    hpxml, _hpxml_bldg = _create_hpxml('base-dhw-tankless-electric.xml', test_name)
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeWaterHeater, 24000, 2)

    test_name = 'HPWH w/backup'
    hpxml, _hpxml_bldg = _create_hpxml('base-dhw-tank-heat-pump.xml', test_name)
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeWaterHeater, 4500, 2)

    test_name = 'HPWH w/out backup'
    hpxml, _hpxml_bldg = _create_hpxml('base-dhw-tank-heat-pump-capacities.xml', test_name)
    XMLHelper.write_file(hpxml.to_doc, @tmp_hpxml_path)
    _model, _hpxml, hpxml_bldg = _test_measure(args_hash)

    _test_panel_load_power_and_breaker_spaces(hpxml_bldg, HPXML::ElectricPanelLoadTypeWaterHeater, 1064, 2)
  end

  def _test_panel_load_power_and_breaker_spaces(hpxml_bldg, type, power, breaker_spaces)
    panel_loads = hpxml_bldg.electric_panels[0].panel_loads
    pl = panel_loads.select { |pl| pl.type == type }

    assert_in_epsilon(power, pl.map { |pl| pl.power }.sum(0.0), 0.001)
    assert_equal(breaker_spaces, pl.map { |pl| pl.breaker_spaces }.sum(0.0))
  end

  def _create_hpxml(hpxml_name, test_name)
    puts "Testing #{test_name}..."
    hpxml = HPXML.new(hpxml_path: File.join(@sample_files_path, hpxml_name))
    hpxml_bldg = hpxml.buildings[0]
    if hpxml_bldg.electric_panels.size == 0
      hpxml_bldg.electric_panels.add(id: 'ElectricPanel')
    end
    return hpxml, hpxml_bldg
  end

  def _test_measure(args_hash)
    # create an instance of the measure
    measure = HPXMLtoOpenStudio.new

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    model = OpenStudio::Model::Model.new

    # get arguments
    args_hash['output_dir'] = File.dirname(__FILE__)
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

    return model, hpxml, hpxml.buildings[0]
  end
end
