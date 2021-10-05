# frozen_string_literal: true

require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class BuildResidentialHPXMLTest < MiniTest::Test
  def test_workflows
    # Extra buildings that don't correspond with sample files
    hpxmls_files = {
      # Base files to derive from
      'base-sfd.xml' => nil,
      'base-sfa.xml' => 'base-sfd.xml',
      'base-mf.xml' => 'base-sfd.xml',

      # Extra files to test
      'extra-auto.xml' => 'base-sfd.xml',
      'extra-pv-roofpitch.xml' => 'base-sfd.xml',
      'extra-dhw-solar-latitude.xml' => 'base-sfd.xml',
      'extra-second-refrigerator.xml' => 'base-sfd.xml',
      'extra-second-heating-system-portable-heater-to-heating-system.xml' => 'base-sfd.xml',
      'extra-second-heating-system-fireplace-to-heating-system.xml' => 'base-sfd.xml',
      'extra-second-heating-system-boiler-to-heating-system.xml' => 'base-sfd.xml',
      'extra-second-heating-system-portable-heater-to-heat-pump.xml' => 'base-sfd.xml',
      'extra-second-heating-system-fireplace-to-heat-pump.xml' => 'base-sfd.xml',
      'extra-second-heating-system-boiler-to-heat-pump.xml' => 'base-sfd.xml',
      'extra-enclosure-windows-shading.xml' => 'base-sfd.xml',
      'extra-enclosure-garage-partially-protruded.xml' => 'base-sfd.xml',
      'extra-enclosure-garage-atticroof-conditioned.xml' => 'base-sfd.xml',
      'extra-enclosure-atticroof-conditioned-eaves-gable.xml' => 'base-sfd.xml',
      'extra-enclosure-atticroof-conditioned-eaves-hip.xml' => 'extra-enclosure-atticroof-conditioned-eaves-gable.xml',
      'extra-sfa-atticroof-flat.xml' => 'base-sfa.xml',
      'extra-gas-pool-heater-with-zero-kwh.xml' => 'base-sfd.xml',
      'extra-gas-hot-tub-heater-with-zero-kwh.xml' => 'base-sfd.xml',
      'extra-no-rim-joists.xml' => 'base-sfd.xml',
      'extra-state-code-different-than-epw.xml' => 'base-sfd.xml',

      'extra-sfa-atticroof-conditioned-eaves-gable.xml' => 'extra-sfa-slab.xml',
      'extra-sfa-atticroof-conditioned-eaves-hip.xml' => 'extra-sfa-atticroof-conditioned-eaves-gable.xml',
      'extra-mf-eaves.xml' => 'extra-mf-slab.xml',

      'extra-sfa-slab.xml' => 'base-sfa.xml',
      'extra-sfa-vented-crawlspace.xml' => 'base-sfa.xml',
      'extra-sfa-unvented-crawlspace.xml' => 'base-sfa.xml',
      'extra-sfa-unconditioned-basement.xml' => 'base-sfa.xml',

      'extra-sfa-double-loaded-interior.xml' => 'base-sfa.xml',
      'extra-sfa-single-exterior-front.xml' => 'base-sfa.xml',
      'extra-sfa-double-exterior.xml' => 'base-sfa.xml',

      'extra-sfa-slab-middle.xml' => 'extra-sfa-slab.xml',
      'extra-sfa-slab-right.xml' => 'extra-sfa-slab.xml',
      'extra-sfa-vented-crawlspace-middle.xml' => 'extra-sfa-vented-crawlspace.xml',
      'extra-sfa-vented-crawlspace-right.xml' => 'extra-sfa-vented-crawlspace.xml',
      'extra-sfa-unvented-crawlspace-middle.xml' => 'extra-sfa-unvented-crawlspace.xml',
      'extra-sfa-unvented-crawlspace-right.xml' => 'extra-sfa-unvented-crawlspace.xml',
      'extra-sfa-unconditioned-basement-middle.xml' => 'extra-sfa-unconditioned-basement.xml',
      'extra-sfa-unconditioned-basement-right.xml' => 'extra-sfa-unconditioned-basement.xml',

      'extra-mf-slab.xml' => 'base-mf.xml',
      'extra-mf-vented-crawlspace.xml' => 'base-mf.xml',
      'extra-mf-unvented-crawlspace.xml' => 'base-mf.xml',

      'extra-mf-double-loaded-interior.xml' => 'base-mf.xml',
      'extra-mf-single-exterior-front.xml' => 'base-mf.xml',
      'extra-mf-double-exterior.xml' => 'base-mf.xml',

      'extra-mf-slab-left-bottom.xml' => 'extra-mf-slab.xml',
      'extra-mf-slab-left-middle.xml' => 'extra-mf-slab.xml',
      'extra-mf-slab-left-top.xml' => 'extra-mf-slab.xml',
      'extra-mf-slab-middle-bottom.xml' => 'extra-mf-slab.xml',
      'extra-mf-slab-middle-middle.xml' => 'extra-mf-slab.xml',
      'extra-mf-slab-middle-top.xml' => 'extra-mf-slab.xml',
      'extra-mf-slab-right-bottom.xml' => 'extra-mf-slab.xml',
      'extra-mf-slab-right-middle.xml' => 'extra-mf-slab.xml',
      'extra-mf-slab-right-top.xml' => 'extra-mf-slab.xml',
      'extra-mf-vented-crawlspace-left-bottom.xml' => 'extra-mf-vented-crawlspace.xml',
      'extra-mf-vented-crawlspace-left-middle.xml' => 'extra-mf-vented-crawlspace.xml',
      'extra-mf-vented-crawlspace-left-top.xml' => 'extra-mf-vented-crawlspace.xml',
      'extra-mf-vented-crawlspace-middle-bottom.xml' => 'extra-mf-vented-crawlspace.xml',
      'extra-mf-vented-crawlspace-middle-middle.xml' => 'extra-mf-vented-crawlspace.xml',
      'extra-mf-vented-crawlspace-middle-top.xml' => 'extra-mf-vented-crawlspace.xml',
      'extra-mf-vented-crawlspace-right-bottom.xml' => 'extra-mf-vented-crawlspace.xml',
      'extra-mf-vented-crawlspace-right-middle.xml' => 'extra-mf-vented-crawlspace.xml',
      'extra-mf-vented-crawlspace-right-top.xml' => 'extra-mf-vented-crawlspace.xml',
      'extra-mf-unvented-crawlspace-left-bottom.xml' => 'extra-mf-unvented-crawlspace.xml',
      'extra-mf-unvented-crawlspace-left-middle.xml' => 'extra-mf-unvented-crawlspace.xml',
      'extra-mf-unvented-crawlspace-left-top.xml' => 'extra-mf-unvented-crawlspace.xml',
      'extra-mf-unvented-crawlspace-middle-bottom.xml' => 'extra-mf-unvented-crawlspace.xml',
      'extra-mf-unvented-crawlspace-middle-middle.xml' => 'extra-mf-unvented-crawlspace.xml',
      'extra-mf-unvented-crawlspace-middle-top.xml' => 'extra-mf-unvented-crawlspace.xml',
      'extra-mf-unvented-crawlspace-right-bottom.xml' => 'extra-mf-unvented-crawlspace.xml',
      'extra-mf-unvented-crawlspace-right-middle.xml' => 'extra-mf-unvented-crawlspace.xml',
      'extra-mf-unvented-crawlspace-right-top.xml' => 'extra-mf-unvented-crawlspace.xml',

      'extra-mf-slab-double-loaded-interior.xml' => 'extra-mf-slab.xml',
      'extra-mf-vented-crawlspace-double-loaded-interior.xml' => 'extra-mf-vented-crawlspace.xml',
      'extra-mf-unvented-crawlspace-double-loaded-interior.xml' => 'extra-mf-unvented-crawlspace.xml',
      'extra-mf-slab-left-bottom-double-loaded-interior.xml' => 'extra-mf-slab-left-bottom.xml',
      'extra-mf-slab-left-middle-double-loaded-interior.xml' => 'extra-mf-slab-left-middle.xml',
      'extra-mf-slab-left-top-double-loaded-interior.xml' => 'extra-mf-slab-left-top.xml',
      'extra-mf-slab-middle-bottom-double-loaded-interior.xml' => 'extra-mf-slab-middle-bottom.xml',
      'extra-mf-slab-middle-middle-double-loaded-interior.xml' => 'extra-mf-slab-middle-middle.xml',
      'extra-mf-slab-middle-top-double-loaded-interior.xml' => 'extra-mf-slab-middle-top.xml',
      'extra-mf-slab-right-bottom-double-loaded-interior.xml' => 'extra-mf-slab-right-bottom.xml',
      'extra-mf-slab-right-middle-double-loaded-interior.xml' => 'extra-mf-slab-right-middle.xml',
      'extra-mf-slab-right-top-double-loaded-interior.xml' => 'extra-mf-slab-right-top.xml',
      'extra-mf-vented-crawlspace-left-bottom-double-loaded-interior.xml' => 'extra-mf-vented-crawlspace-left-bottom.xml',
      'extra-mf-vented-crawlspace-left-middle-double-loaded-interior.xml' => 'extra-mf-vented-crawlspace-left-middle.xml',
      'extra-mf-vented-crawlspace-left-top-double-loaded-interior.xml' => 'extra-mf-vented-crawlspace-left-top.xml',
      'extra-mf-vented-crawlspace-middle-bottom-double-loaded-interior.xml' => 'extra-mf-vented-crawlspace-middle-bottom.xml',
      'extra-mf-vented-crawlspace-middle-middle-double-loaded-interior.xml' => 'extra-mf-vented-crawlspace-middle-middle.xml',
      'extra-mf-vented-crawlspace-middle-top-double-loaded-interior.xml' => 'extra-mf-vented-crawlspace-middle-top.xml',
      'extra-mf-vented-crawlspace-right-bottom-double-loaded-interior.xml' => 'extra-mf-vented-crawlspace-right-bottom.xml',
      'extra-mf-vented-crawlspace-right-middle-double-loaded-interior.xml' => 'extra-mf-vented-crawlspace-right-middle.xml',
      'extra-mf-vented-crawlspace-right-top-double-loaded-interior.xml' => 'extra-mf-vented-crawlspace-right-top.xml',
      'extra-mf-unvented-crawlspace-left-bottom-double-loaded-interior.xml' => 'extra-mf-unvented-crawlspace-left-bottom.xml',
      'extra-mf-unvented-crawlspace-left-middle-double-loaded-interior.xml' => 'extra-mf-unvented-crawlspace-left-middle.xml',
      'extra-mf-unvented-crawlspace-left-top-double-loaded-interior.xml' => 'extra-mf-unvented-crawlspace-left-top.xml',
      'extra-mf-unvented-crawlspace-middle-bottom-double-loaded-interior.xml' => 'extra-mf-unvented-crawlspace-middle-bottom.xml',
      'extra-mf-unvented-crawlspace-middle-middle-double-loaded-interior.xml' => 'extra-mf-unvented-crawlspace-middle-middle.xml',
      'extra-mf-unvented-crawlspace-middle-top-double-loaded-interior.xml' => 'extra-mf-unvented-crawlspace-middle-top.xml',
      'extra-mf-unvented-crawlspace-right-bottom-double-loaded-interior.xml' => 'extra-mf-unvented-crawlspace-right-bottom.xml',
      'extra-mf-unvented-crawlspace-right-middle-double-loaded-interior.xml' => 'extra-mf-unvented-crawlspace-right-middle.xml',
      'extra-mf-unvented-crawlspace-right-top-double-loaded-interior.xml' => 'extra-mf-unvented-crawlspace-right-top.xml',

      'error-heating-system-and-heat-pump.xml' => 'base-sfd.xml',
      'error-cooling-system-and-heat-pump.xml' => 'base-sfd.xml',
      'error-sfd-finished-basement-zero-foundation-height.xml' => 'base-sfd.xml',
      'error-sfa-ambient.xml' => 'base-sfa.xml',
      'error-mf-bottom-crawlspace-zero-foundation-height.xml' => 'base-mf.xml',
      'error-ducts-location-and-areas-not-same-type.xml' => 'base-sfd.xml',
      'error-second-heating-system-serves-total-heat-load.xml' => 'base-sfd.xml',
      'error-second-heating-system-but-no-primary-heating.xml' => 'base-sfd.xml',
      'error-sfa-no-building-orientation.xml' => 'base-sfa.xml',
      'error-mf-no-building-orientation.xml' => 'base-mf.xml',
      'error-dhw-indirect-without-boiler.xml' => 'base-sfd.xml',
      'error-foundation-wall-insulation-greater-than-height.xml' => 'base-sfd.xml',
      'error-conditioned-attic-with-one-floor-above-grade.xml' => 'base-sfd.xml',
      'error-zero-number-of-bedrooms.xml' => 'base-sfd.xml',
      'error-sfd-with-shared-system.xml' => 'base-sfd.xml',
      'error-rim-joist-height-but-no-assembly-r.xml' => 'base-sfd.xml',
      'error-rim-joist-assembly-r-but-no-height.xml' => 'base-sfd.xml',

      'warning-non-electric-heat-pump-water-heater.xml' => 'base-sfd.xml',
      'warning-sfd-slab-non-zero-foundation-height.xml' => 'base-sfd.xml',
      'warning-mf-bottom-slab-non-zero-foundation-height.xml' => 'base-mf.xml',
      'warning-slab-non-zero-foundation-height-above-grade.xml' => 'base-sfd.xml',
      'warning-second-heating-system-serves-majority-heat.xml' => 'base-sfd.xml',
      'warning-vented-crawlspace-with-wall-and-ceiling-insulation.xml' => 'base-sfd.xml',
      'warning-unvented-crawlspace-with-wall-and-ceiling-insulation.xml' => 'base-sfd.xml',
      'warning-unconditioned-basement-with-wall-and-ceiling-insulation.xml' => 'base-sfd.xml',
      'warning-vented-attic-with-floor-and-roof-insulation.xml' => 'base-sfd.xml',
      'warning-unvented-attic-with-floor-and-roof-insulation.xml' => 'base-sfd.xml',
      'warning-conditioned-basement-with-ceiling-insulation.xml' => 'base-sfd.xml',
      'warning-conditioned-attic-with-floor-insulation.xml' => 'base-sfd.xml',
      'warning-multipliers-without-tv-plug-loads.xml' => 'base-sfd.xml',
      'warning-multipliers-without-other-plug-loads.xml' => 'base-sfd.xml',
      'warning-multipliers-without-well-pump-plug-loads.xml' => 'base-sfd.xml',
      'warning-multipliers-without-vehicle-plug-loads.xml' => 'base-sfd.xml',
      'warning-multipliers-without-fuel-loads.xml' => 'base-sfd.xml',
    }

    expected_errors = {
      'error-heating-system-and-heat-pump.xml' => 'heating_system_type=Furnace and heat_pump_type=air-to-air',
      'error-cooling-system-and-heat-pump.xml' => 'cooling_system_type=central air conditioner and heat_pump_type=air-to-air',
      'error-sfd-finished-basement-zero-foundation-height.xml' => 'geometry_unit_type=single-family detached and geometry_foundation_type=ConditionedBasement and geometry_foundation_height=0.0',
      'error-sfa-ambient.xml' => 'geometry_unit_type=single-family attached and geometry_foundation_type=Ambient',
      'error-mf-bottom-crawlspace-zero-foundation-height.xml' => 'geometry_unit_type=apartment unit and geometry_unit_level=Bottom and geometry_foundation_type=UnventedCrawlspace and geometry_foundation_height=0.0',
      'error-ducts-location-and-areas-not-same-type.xml' => 'ducts_supply_location=not provided and ducts_supply_surface_area=provided and ducts_return_location=provided and ducts_return_surface_area=provided',
      'error-second-heating-system-serves-total-heat-load.xml' => 'heating_system_2_type=Fireplace and heating_system_2_fraction_heat_load_served=1.0',
      'error-second-heating-system-but-no-primary-heating.xml' => 'heating_system_type=none and heat_pump_type=none and heating_system_2_type=Fireplace',
      'error-sfa-no-building-orientation.xml' => 'geometry_unit_type=single-family attached and geometry_building_num_units=not provided and geometry_unit_horizontal_location=not provided',
      'error-mf-no-building-orientation.xml' => 'geometry_unit_type=apartment unit and geometry_building_num_units=not provided and geometry_unit_level=not provided and geometry_unit_horizontal_location=not provided',
      'error-dhw-indirect-without-boiler.xml' => 'water_heater_type=space-heating boiler with storage tank and heating_system_type=Furnace',
      'error-conditioned-attic-with-one-floor-above-grade.xml' => 'geometry_num_floors_above_grade=1 and geometry_attic_type=ConditionedAttic',
      'error-zero-number-of-bedrooms.xml' => 'geometry_unit_num_bedrooms=0',
      'error-sfd-with-shared-system.xml' => 'geometry_unit_type=single-family detached and heating_system_type=Shared Boiler w/ Baseboard',
      'error-rim-joist-height-but-no-assembly-r.xml' => 'geometry_rim_joist_height=9.25 and rim_joist_assembly_r=not provided',
      'error-rim-joist-assembly-r-but-no-height.xml' => 'rim_joist_assembly_r=23.0 and geometry_rim_joist_height=not provided',
    }

    expected_warnings = {
      'warning-non-electric-heat-pump-water-heater.xml' => 'water_heater_type=heat pump water heater and water_heater_fuel_type=natural gas',
      'warning-sfd-slab-non-zero-foundation-height.xml' => 'geometry_unit_type=single-family detached and geometry_foundation_type=SlabOnGrade and geometry_foundation_height=8.0',
      'warning-mf-bottom-slab-non-zero-foundation-height.xml' => 'geometry_unit_type=apartment unit and geometry_unit_level=Bottom and geometry_foundation_type=SlabOnGrade and geometry_foundation_height=8.0',
      'warning-slab-non-zero-foundation-height-above-grade.xml' => 'geometry_foundation_type=SlabOnGrade and geometry_foundation_height_above_grade=1.0',
      'warning-second-heating-system-serves-majority-heat.xml' => 'heating_system_2_type=Fireplace and heating_system_2_fraction_heat_load_served=0.6',
      'warning-vented-crawlspace-with-wall-and-ceiling-insulation.xml' => 'geometry_foundation_type=VentedCrawlspace and foundation_wall_insulation_r=8.9 and foundation_wall_assembly_r=10.0 and floor_over_foundation_assembly_r=10.0',
      'warning-unvented-crawlspace-with-wall-and-ceiling-insulation.xml' => 'geometry_foundation_type=UnventedCrawlspace and foundation_wall_insulation_r=8.9 and foundation_wall_assembly_r=10.0 and floor_over_foundation_assembly_r=10.0',
      'warning-unconditioned-basement-with-wall-and-ceiling-insulation.xml' => 'geometry_foundation_type=UnconditionedBasement and foundation_wall_insulation_r=8.9 and foundation_wall_assembly_r=10.0 and floor_over_foundation_assembly_r=10.0',
      'warning-vented-attic-with-floor-and-roof-insulation.xml' => 'geometry_attic_type=VentedAttic and ceiling_assembly_r=39.3 and roof_assembly_r=10.0',
      'warning-unvented-attic-with-floor-and-roof-insulation.xml' => 'geometry_attic_type=UnventedAttic and ceiling_assembly_r=39.3 and roof_assembly_r=10.0',
      'warning-conditioned-basement-with-ceiling-insulation.xml' => 'geometry_foundation_type=ConditionedBasement and floor_over_foundation_assembly_r=10.0',
      'warning-conditioned-attic-with-floor-insulation.xml' => 'geometry_attic_type=ConditionedAttic and ceiling_assembly_r=39.3',
      'warning-multipliers-without-tv-plug-loads.xml' => 'misc_plug_loads_television_annual_kwh=0.0 and misc_plug_loads_television_usage_multiplier=1.0',
      'warning-multipliers-without-other-plug-loads.xml' => 'misc_plug_loads_other_annual_kwh=0.0 and misc_plug_loads_other_usage_multiplier=1.0',
      'warning-multipliers-without-well-pump-plug-loads.xml' => 'misc_plug_loads_well_pump_annual_kwh=0.0 and misc_plug_loads_well_pump_usage_multiplier=1.0',
      'warning-multipliers-without-vehicle-plug-loads.xml' => 'misc_plug_loads_vehicle_annual_kwh=0.0 and misc_plug_loads_vehicle_usage_multiplier=1.0',
      'warning-multipliers-without-fuel-loads.xml' => 'misc_fuel_loads_grill_present=false and misc_fuel_loads_grill_usage_multiplier=1.0 and misc_fuel_loads_lighting_present=false and misc_fuel_loads_lighting_usage_multiplier=1.0 and misc_fuel_loads_fireplace_present=false and misc_fuel_loads_fireplace_usage_multiplier=1.0',
    }

    hpxmls_files.each_with_index do |(hpxml_file, parent), i|
      puts "[#{i + 1}/#{hpxmls_files.size}] Testing #{hpxml_file}..."

      begin
        all_hpxml_files = [hpxml_file]
        unless parent.nil?
          all_hpxml_files.unshift(parent)
        end
        while not parent.nil?
          next unless hpxmls_files.keys.include? parent

          unless hpxmls_files[parent].nil?
            all_hpxml_files.unshift(hpxmls_files[parent])
          end
          parent = hpxmls_files[parent]
        end

        args = {}
        all_hpxml_files.each do |f|
          _set_measure_argument_values(f, args)
        end

        File.delete(args['hpxml_path']) if File.exist? args['hpxml_path']
        _test_measure(args, expected_errors[hpxml_file], expected_warnings[hpxml_file])
        File.delete(args['hpxml_path']) if File.exist? args['hpxml_path']
      rescue Exception => e
        puts "\n#{e}\n#{e.backtrace.join('\n')}"
        puts "\nError: Did not successfully generate #{hpxml_file}."
        exit!
      end
    end
  end

  private

  def _set_measure_argument_values(hpxml_file, args)
    args['hpxml_path'] = File.absolute_path(File.join(File.dirname(__FILE__), hpxml_file))

    # Base
    if ['base-sfd.xml'].include? hpxml_file
      args['weather_station_epw_filepath'] = 'USA_CO_Denver.Intl.AP.725650_TMY3.epw'
      args['geometry_unit_type'] = HPXML::ResidentialTypeSFD
      args['geometry_unit_cfa'] = 2700.0
      args['geometry_num_floors_above_grade'] = 1
      args['geometry_average_ceiling_height'] = 8.0
      args['geometry_unit_orientation'] = 180.0
      args['geometry_unit_aspect_ratio'] = 1.5
      args['geometry_garage_width'] = 0.0
      args['geometry_foundation_type'] = HPXML::FoundationTypeBasementConditioned
      args['geometry_foundation_height'] = 8.0
      args['geometry_foundation_height_above_grade'] = 1.0
      args['geometry_rim_joist_height'] = 9.25
      args['geometry_roof_type'] = 'gable'
      args['geometry_roof_pitch'] = '6:12'
      args['geometry_attic_type'] = HPXML::AtticTypeUnvented
      args['geometry_eaves_depth'] = 0
      args['geometry_unit_num_bedrooms'] = 3
      args['floor_over_foundation_assembly_r'] = 0
      args['floor_over_garage_assembly_r'] = 0
      args['foundation_wall_insulation_r'] = 8.9
      args['rim_joist_assembly_r'] = 23.0
      args['ceiling_assembly_r'] = 39.3
      args['roof_assembly_r'] = 2.3
      args['wall_assembly_r'] = 23
      args['window_front_area'] = 108.0
      args['window_back_area'] = 108.0
      args['window_left_area'] = 72.0
      args['window_right_area'] = 72.0
      args['window_ufactor'] = 0.33
      args['window_shgc'] = 0.45
      args['door_area'] = 40.0
      args['door_rvalue'] = 4.4
      args['air_leakage_units'] = HPXML::UnitsACH
      args['air_leakage_house_pressure'] = 50
      args['air_leakage_value'] = 3
      args['heating_system_type'] = HPXML::HVACTypeFurnace
      args['heating_system_fuel'] = HPXML::FuelTypeNaturalGas
      args['heating_system_heating_efficiency'] = 0.92
      args['heating_system_heating_capacity'] = 36000.0
      args['cooling_system_type'] = HPXML::HVACTypeCentralAirConditioner
      args['cooling_system_cooling_efficiency_type'] = HPXML::UnitsSEER
      args['cooling_system_cooling_efficiency'] = 13.0
      args['cooling_system_cooling_capacity'] = 24000.0
      args['hvac_control_heating_weekday_setpoint'] = 68
      args['hvac_control_heating_weekend_setpoint'] = 68
      args['hvac_control_cooling_weekday_setpoint'] = 78
      args['hvac_control_cooling_weekend_setpoint'] = 78
      args['ducts_leakage_units'] = HPXML::UnitsCFM25
      args['ducts_supply_leakage_to_outside_value'] = 75.0
      args['ducts_return_leakage_to_outside_value'] = 25.0
      args['ducts_supply_insulation_r'] = 4.0
      args['ducts_return_insulation_r'] = 0.0
      args['ducts_supply_location'] = HPXML::LocationAtticUnvented
      args['ducts_return_location'] = HPXML::LocationAtticUnvented
      args['ducts_supply_surface_area'] = 150.0
      args['ducts_return_surface_area'] = 50.0
      args['water_heater_type'] = HPXML::WaterHeaterTypeStorage
      args['water_heater_fuel_type'] = HPXML::FuelTypeElectricity
      args['water_heater_tank_volume'] = 40
      args['water_heater_efficiency_type'] = 'EnergyFactor'
      args['water_heater_efficiency'] = 0.95
    elsif ['base-sfa.xml'].include? hpxml_file
      args['geometry_unit_type'] = HPXML::ResidentialTypeSFA
      args['geometry_unit_cfa'] = 1800.0
      args['geometry_corridor_position'] = 'None'
      args['geometry_building_num_units'] = 3
      args['geometry_unit_horizontal_location'] = 'Left'
      args['window_front_wwr'] = 0.18
      args['window_back_wwr'] = 0.18
      args['window_left_wwr'] = 0.18
      args['window_right_wwr'] = 0.18
      args['window_front_area'] = 0
      args['window_back_area'] = 0
      args['window_left_area'] = 0
      args['window_right_area'] = 0
    elsif ['base-mf.xml'].include? hpxml_file
      args['geometry_unit_type'] = HPXML::ResidentialTypeApartment
      args['geometry_unit_cfa'] = 900.0
      args['geometry_corridor_position'] = 'None'
      args['geometry_foundation_type'] = HPXML::FoundationTypeBasementUnconditioned
      args['geometry_unit_level'] = 'Middle'
      args['geometry_unit_horizontal_location'] = 'Left'
      args['geometry_building_num_units'] = 6
      args['geometry_building_num_bedrooms'] = 6 * 3
      args['geometry_num_floors_above_grade'] = 3
      args['window_front_wwr'] = 0.18
      args['window_back_wwr'] = 0.18
      args['window_left_wwr'] = 0.18
      args['window_right_wwr'] = 0.18
      args['window_front_area'] = 0
      args['window_back_area'] = 0
      args['window_left_area'] = 0
      args['window_right_area'] = 0
      args['ducts_supply_leakage_to_outside_value'] = 0.0
      args['ducts_return_leakage_to_outside_value'] = 0.0
      args['ducts_supply_location'] = HPXML::LocationLivingSpace
      args['ducts_return_location'] = HPXML::LocationLivingSpace
      args['ducts_supply_insulation_r'] = 0.0
      args['ducts_return_insulation_r'] = 0.0
      args['ducts_number_of_return_registers'] = 1
      args['door_area'] = 20.0
    end

    # Extras
    if ['extra-auto.xml'].include? hpxml_file
      args.delete('geometry_unit_num_occupants')
      args.delete('ducts_supply_location')
      args.delete('ducts_return_location')
      args.delete('ducts_supply_surface_area')
      args.delete('ducts_return_surface_area')
      args.delete('water_heater_location')
      args.delete('water_heater_tank_volume')
      args.delete('hot_water_distribution_standard_piping_length')
      args.delete('clothes_washer_location')
      args.delete('clothes_dryer_location')
      args.delete('refrigerator_location')
    elsif ['extra-pv-roofpitch.xml'].include? hpxml_file
      args['pv_system_module_type'] = HPXML::PVModuleTypeStandard
      args['pv_system_2_module_type'] = HPXML::PVModuleTypeStandard
      args['pv_system_array_tilt'] = 'roofpitch'
      args['pv_system_2_array_tilt'] = 'roofpitch+15'
    elsif ['extra-dhw-solar-latitude.xml'].include? hpxml_file
      args['solar_thermal_system_type'] = HPXML::SolarThermalSystemType
      args['solar_thermal_collector_tilt'] = 'latitude-15'
    elsif ['extra-second-refrigerator.xml'].include? hpxml_file
      args['extra_refrigerator_location'] = HPXML::LocationLivingSpace
    elsif ['extra-second-heating-system-portable-heater-to-heating-system.xml'].include? hpxml_file
      args['heating_system_fuel'] = HPXML::FuelTypeElectricity
      args['heating_system_heating_capacity'] = 48000.0
      args['heating_system_fraction_heat_load_served'] = 0.75
      args['ducts_supply_leakage_to_outside_value'] = 0.0
      args['ducts_return_leakage_to_outside_value'] = 0.0
      args['ducts_supply_location'] = HPXML::LocationLivingSpace
      args['ducts_return_location'] = HPXML::LocationLivingSpace
      args['heating_system_2_type'] = HPXML::HVACTypePortableHeater
      args['heating_system_2_heating_capacity'] = 16000.0
    elsif ['extra-second-heating-system-fireplace-to-heating-system.xml'].include? hpxml_file
      args['heating_system_type'] = HPXML::HVACTypeElectricResistance
      args['heating_system_fuel'] = HPXML::FuelTypeElectricity
      args['heating_system_heating_efficiency'] = 1.0
      args['heating_system_heating_capacity'] = 48000.0
      args['heating_system_fraction_heat_load_served'] = 0.75
      args['cooling_system_type'] = 'none'
      args['heating_system_2_type'] = HPXML::HVACTypeFireplace
      args['heating_system_2_heating_capacity'] = 16000.0
    elsif ['extra-second-heating-system-boiler-to-heating-system.xml'].include? hpxml_file
      args['heating_system_type'] = HPXML::HVACTypeBoiler
      args['heating_system_fraction_heat_load_served'] = 0.75
      args['heating_system_2_type'] = HPXML::HVACTypeBoiler
    elsif ['extra-second-heating-system-portable-heater-to-heat-pump.xml'].include? hpxml_file
      args['heat_pump_type'] = HPXML::HVACTypeHeatPumpAirToAir
      args['heat_pump_heating_efficiency_type'] = HPXML::UnitsHSPF
      args['heat_pump_heating_efficiency'] = 7.7
      args['heat_pump_cooling_efficiency_type'] = HPXML::UnitsSEER
      args['heat_pump_cooling_efficiency'] = 13.0
      args['heat_pump_cooling_compressor_type'] = HPXML::HVACCompressorTypeSingleStage
      args['heat_pump_cooling_sensible_heat_fraction'] = 0.73
      args['heat_pump_heating_capacity'] = 36000.0
      args['heat_pump_heating_capacity_17_f'] = 22680.0
      args['heat_pump_cooling_capacity'] = 36000.0
      args['heat_pump_fraction_heat_load_served'] = 0.75
      args['heat_pump_fraction_cool_load_served'] = 1
      args['heat_pump_backup_fuel'] = HPXML::FuelTypeElectricity
      args['heat_pump_backup_heating_efficiency'] = 1
      args['heat_pump_backup_heating_capacity'] = 48000.0
      args['heating_system_type'] = 'none'
      args['cooling_system_type'] = 'none'
      args['ducts_supply_leakage_to_outside_value'] = 0.0
      args['ducts_return_leakage_to_outside_value'] = 0.0
      args['ducts_supply_location'] = HPXML::LocationLivingSpace
      args['ducts_return_location'] = HPXML::LocationLivingSpace
      args['heating_system_2_type'] = HPXML::HVACTypePortableHeater
      args['heating_system_2_heating_capacity'] = 16000.0
    elsif ['extra-second-heating-system-fireplace-to-heat-pump.xml'].include? hpxml_file
      args['heat_pump_type'] = HPXML::HVACTypeHeatPumpMiniSplit
      args['heat_pump_heating_efficiency_type'] = HPXML::UnitsHSPF
      args['heat_pump_heating_efficiency'] = 10.0
      args['heat_pump_cooling_efficiency_type'] = HPXML::UnitsSEER
      args['heat_pump_cooling_efficiency'] = 19.0
      args['heat_pump_cooling_compressor_type'] = HPXML::HVACCompressorTypeSingleStage
      args['heat_pump_cooling_sensible_heat_fraction'] = 0.73
      args['heat_pump_heating_capacity'] = 48000.0
      args['heat_pump_heating_capacity_17_f'] = Constants.Auto
      args['heat_pump_cooling_capacity'] = 36000.0
      args['heat_pump_fraction_heat_load_served'] = 0.75
      args['heat_pump_fraction_cool_load_served'] = 1
      args['heat_pump_backup_fuel'] = 'none'
      args['heat_pump_backup_heating_efficiency'] = 1
      args['heat_pump_backup_heating_capacity'] = 36000.0
      args['heat_pump_is_ducted'] = true
      args['heating_system_type'] = 'none'
      args['cooling_system_type'] = 'none'
      args['heating_system_2_type'] = HPXML::HVACTypeFireplace
      args['heating_system_2_heating_capacity'] = 16000.0
    elsif ['extra-second-heating-system-boiler-to-heat-pump.xml'].include? hpxml_file
      args['heat_pump_type'] = HPXML::HVACTypeHeatPumpGroundToAir
      args['heat_pump_heating_efficiency_type'] = HPXML::UnitsCOP
      args['heat_pump_heating_efficiency'] = 3.6
      args['heat_pump_cooling_efficiency_type'] = HPXML::UnitsEER
      args['heat_pump_cooling_efficiency'] = 16.6
      args['heat_pump_cooling_compressor_type'] = HPXML::HVACCompressorTypeSingleStage
      args['heat_pump_cooling_sensible_heat_fraction'] = 0.73
      args['heat_pump_heating_capacity'] = 36000.0
      args['heat_pump_heating_capacity_17_f'] = Constants.Auto
      args['heat_pump_cooling_capacity'] = 36000.0
      args['heat_pump_fraction_heat_load_served'] = 0.75
      args['heat_pump_fraction_cool_load_served'] = 1
      args['heat_pump_backup_fuel'] = HPXML::FuelTypeElectricity
      args['heat_pump_backup_heating_efficiency'] = 1
      args['heat_pump_backup_heating_capacity'] = 36000.0
      args['heating_system_type'] = 'none'
      args['cooling_system_type'] = 'none'
      args['heating_system_2_type'] = HPXML::HVACTypeBoiler
    elsif ['extra-enclosure-windows-shading.xml'].include? hpxml_file
      args['window_interior_shading_winter'] = 0.99
      args['window_interior_shading_summer'] = 0.01
      args['window_exterior_shading_winter'] = 0.9
      args['window_exterior_shading_summer'] = 0.1
    elsif ['extra-enclosure-garage-partially-protruded.xml'].include? hpxml_file
      args['geometry_garage_width'] = 12
      args['geometry_garage_protrusion'] = 0.5
    elsif ['extra-enclosure-garage-atticroof-conditioned.xml'].include? hpxml_file
      args['geometry_garage_width'] = 30.0
      args['geometry_garage_protrusion'] = 1.0
      args['window_front_area'] = 12.0
      args['window_aspect_ratio'] = 5.0 / 1.5
      args['geometry_unit_cfa'] = 4500.0
      args['geometry_num_floors_above_grade'] = 2
      args['geometry_attic_type'] = HPXML::AtticTypeConditioned
      args['floor_over_garage_assembly_r'] = 39.3
      args['ducts_supply_location'] = HPXML::LocationGarage
      args['ducts_return_location'] = HPXML::LocationGarage
    elsif ['extra-enclosure-atticroof-conditioned-eaves-gable.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeSlab
      args['geometry_foundation_height'] = 0.0
      args['geometry_foundation_height_above_grade'] = 0.0
      args['geometry_unit_cfa'] = 4500.0
      args['geometry_num_floors_above_grade'] = 2
      args['geometry_attic_type'] = HPXML::AtticTypeConditioned
      args['geometry_eaves_depth'] = 2
      args['ducts_supply_location'] = HPXML::LocationUnderSlab
      args['ducts_return_location'] = HPXML::LocationUnderSlab
    elsif ['extra-enclosure-atticroof-conditioned-eaves-hip.xml'].include? hpxml_file
      args['geometry_roof_type'] = 'hip'
    elsif ['extra-sfa-atticroof-flat.xml'].include? hpxml_file
      args['geometry_roof_type'] = 'flat'
      args['ducts_supply_leakage_to_outside_value'] = 0.0
      args['ducts_return_leakage_to_outside_value'] = 0.0
      args['ducts_supply_location'] = HPXML::LocationBasementConditioned
      args['ducts_return_location'] = HPXML::LocationBasementConditioned
    elsif ['extra-gas-pool-heater-with-zero-kwh.xml'].include? hpxml_file
      args['pool_present'] = true
      args['pool_heater_type'] = HPXML::HeaterTypeGas
      args['pool_heater_annual_kwh'] = 0
    elsif ['extra-gas-hot-tub-heater-with-zero-kwh.xml'].include? hpxml_file
      args['hot_tub_present'] = true
      args['hot_tub_heater_type'] = HPXML::HeaterTypeGas
      args['hot_tub_heater_annual_kwh'] = 0
    elsif ['extra-no-rim-joists.xml'].include? hpxml_file
      args.delete('geometry_rim_joist_height')
      args.delete('rim_joist_assembly_r')
    elsif ['extra-state-code-different-than-epw.xml'].include? hpxml_file
      args['site_state_code'] = 'WY'
    elsif ['extra-sfa-atticroof-conditioned-eaves-gable.xml'].include? hpxml_file
      args['geometry_num_floors_above_grade'] = 2
      args['geometry_attic_type'] = HPXML::AtticTypeConditioned
      args['geometry_eaves_depth'] = 2
      args['ducts_supply_location'] = HPXML::LocationLivingSpace
      args['ducts_return_location'] = HPXML::LocationLivingSpace
    elsif ['extra-sfa-atticroof-conditioned-eaves-hip.xml'].include? hpxml_file
      args['geometry_roof_type'] = 'hip'
    elsif ['extra-mf-eaves.xml'].include? hpxml_file
      args['geometry_eaves_depth'] = 2
    elsif ['extra-sfa-slab.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeSlab
      args['geometry_foundation_height'] = 0.0
      args['geometry_foundation_height_above_grade'] = 0.0
    elsif ['extra-sfa-vented-crawlspace.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceVented
      args['geometry_foundation_height'] = 4.0
      args['floor_over_foundation_assembly_r'] = 18.7
      args['foundation_wall_insulation_distance_to_bottom'] = 4.0
    elsif ['extra-sfa-unvented-crawlspace.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceUnvented
      args['geometry_foundation_height'] = 4.0
      args['floor_over_foundation_assembly_r'] = 18.7
      args['foundation_wall_insulation_distance_to_bottom'] = 4.0
    elsif ['extra-sfa-unconditioned-basement.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeBasementUnconditioned
      args['floor_over_foundation_assembly_r'] = 18.7
      args['foundation_wall_insulation_r'] = 0
      args['foundation_wall_insulation_distance_to_bottom'] = 0.0
    elsif ['extra-sfa-double-loaded-interior.xml'].include? hpxml_file
      args['geometry_building_num_units'] = 4
      args['geometry_corridor_position'] = 'Double-Loaded Interior'
    elsif ['extra-sfa-single-exterior-front.xml'].include? hpxml_file
      args['geometry_corridor_position'] = 'Single Exterior (Front)'
    elsif ['extra-sfa-double-exterior.xml'].include? hpxml_file
      args['geometry_building_num_units'] = 4
      args['geometry_corridor_position'] = 'Double Exterior'
    elsif ['extra-sfa-slab-middle.xml',
           'extra-sfa-vented-crawlspace-middle.xml',
           'extra-sfa-unvented-crawlspace-middle.xml',
           'extra-sfa-unconditioned-basement-middle.xml'].include? hpxml_file
      args['geometry_unit_horizontal_location'] = 'Middle'
    elsif ['extra-sfa-slab-right.xml',
           'extra-sfa-vented-crawlspace-right.xml',
           'extra-sfa-unvented-crawlspace-right.xml',
           'extra-sfa-unconditioned-basement-right.xml'].include? hpxml_file
      args['geometry_unit_horizontal_location'] = 'Right'
    elsif ['extra-mf-slab.xml'].include? hpxml_file
      args['geometry_building_num_units'] = 18
      args['geometry_foundation_type'] = HPXML::FoundationTypeSlab
      args['geometry_foundation_height'] = 0.0
      args['geometry_foundation_height_above_grade'] = 0.0
    elsif ['extra-mf-vented-crawlspace.xml'].include? hpxml_file
      args['geometry_building_num_units'] = 18
      args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceVented
      args['geometry_foundation_height'] = 4.0
      args['floor_over_foundation_assembly_r'] = 18.7
      args['foundation_wall_insulation_distance_to_bottom'] = 4.0
    elsif ['extra-mf-unvented-crawlspace.xml'].include? hpxml_file
      args['geometry_building_num_units'] = 18
      args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceUnvented
      args['geometry_foundation_height'] = 4.0
      args['floor_over_foundation_assembly_r'] = 18.7
      args['foundation_wall_insulation_distance_to_bottom'] = 4.0
    elsif ['extra-mf-double-loaded-interior.xml'].include? hpxml_file
      args['geometry_building_num_units'] = 18
      args['geometry_corridor_position'] = 'Double-Loaded Interior'
    elsif ['extra-mf-single-exterior-front.xml'].include? hpxml_file
      args['geometry_building_num_units'] = 18
      args['geometry_corridor_position'] = 'Single Exterior (Front)'
    elsif ['extra-mf-double-exterior.xml'].include? hpxml_file
      args['geometry_building_num_units'] = 18
      args['geometry_corridor_position'] = 'Double Exterior'
    elsif ['extra-mf-slab-left-bottom.xml',
           'extra-mf-vented-crawlspace-left-bottom.xml',
           'extra-mf-unvented-crawlspace-left-bottom.xml'].include? hpxml_file
      args['geometry_unit_horizontal_location'] = 'Left'
      args['geometry_unit_level'] = 'Bottom'
    elsif ['extra-mf-slab-left-middle.xml',
           'extra-mf-vented-crawlspace-left-middle.xml',
           'extra-mf-unvented-crawlspace-left-middle.xml'].include? hpxml_file
      args['geometry_unit_horizontal_location'] = 'Left'
      args['geometry_unit_level'] = 'Middle'
    elsif ['extra-mf-slab-left-top.xml',
           'extra-mf-vented-crawlspace-left-top.xml',
           'extra-mf-unvented-crawlspace-left-top.xml'].include? hpxml_file
      args['geometry_unit_horizontal_location'] = 'Left'
      args['geometry_unit_level'] = 'Top'
    elsif ['extra-mf-slab-middle-bottom.xml',
           'extra-mf-vented-crawlspace-middle-bottom.xml',
           'extra-mf-unvented-crawlspace-middle-bottom.xml'].include? hpxml_file
      args['geometry_unit_horizontal_location'] = 'Middle'
      args['geometry_unit_level'] = 'Bottom'
    elsif ['extra-mf-slab-middle-middle.xml',
           'extra-mf-vented-crawlspace-middle-middle.xml',
           'extra-mf-unvented-crawlspace-middle-middle.xml'].include? hpxml_file
      args['geometry_unit_horizontal_location'] = 'Middle'
      args['geometry_unit_level'] = 'Middle'
    elsif ['extra-mf-slab-middle-top.xml',
           'extra-mf-vented-crawlspace-middle-top.xml',
           'extra-mf-unvented-crawlspace-middle-top.xml'].include? hpxml_file
      args['geometry_unit_horizontal_location'] = 'Middle'
      args['geometry_unit_level'] = 'Top'
    elsif ['extra-mf-slab-right-bottom.xml',
           'extra-mf-vented-crawlspace-right-bottom.xml',
           'extra-mf-unvented-crawlspace-right-bottom.xml'].include? hpxml_file
      args['geometry_unit_horizontal_location'] = 'Right'
      args['geometry_unit_level'] = 'Bottom'
    elsif ['extra-mf-slab-right-middle.xml',
           'extra-mf-vented-crawlspace-right-middle.xml',
           'extra-mf-unvented-crawlspace-right-middle.xml'].include? hpxml_file
      args['geometry_unit_horizontal_location'] = 'Right'
      args['geometry_unit_level'] = 'Middle'
    elsif ['extra-mf-slab-right-top.xml',
           'extra-mf-vented-crawlspace-right-top.xml',
           'extra-mf-unvented-crawlspace-right-top.xml'].include? hpxml_file
      args['geometry_unit_horizontal_location'] = 'Right'
      args['geometry_unit_level'] = 'Top'
    elsif ['extra-mf-slab-double-loaded-interior.xml',
           'extra-mf-vented-crawlspace-double-loaded-interior.xml',
           'extra-mf-unvented-crawlspace-double-loaded-interior.xml',
           'extra-mf-slab-left-bottom-double-loaded-interior.xml',
           'extra-mf-slab-left-middle-double-loaded-interior.xml',
           'extra-mf-slab-left-top-double-loaded-interior.xml',
           'extra-mf-slab-middle-bottom-double-loaded-interior.xml',
           'extra-mf-slab-middle-middle-double-loaded-interior.xml',
           'extra-mf-slab-middle-top-double-loaded-interior.xml',
           'extra-mf-slab-right-bottom-double-loaded-interior.xml',
           'extra-mf-slab-right-middle-double-loaded-interior.xml',
           'extra-mf-slab-right-top-double-loaded-interior.xml',
           'extra-mf-vented-crawlspace-left-bottom-double-loaded-interior.xml',
           'extra-mf-vented-crawlspace-left-middle-double-loaded-interior.xml',
           'extra-mf-vented-crawlspace-left-top-double-loaded-interior.xml',
           'extra-mf-vented-crawlspace-middle-bottom-double-loaded-interior.xml',
           'extra-mf-vented-crawlspace-middle-middle-double-loaded-interior.xml',
           'extra-mf-vented-crawlspace-middle-top-double-loaded-interior.xml',
           'extra-mf-vented-crawlspace-right-bottom-double-loaded-interior.xml',
           'extra-mf-vented-crawlspace-right-middle-double-loaded-interior.xml',
           'extra-mf-vented-crawlspace-right-top-double-loaded-interior.xml',
           'extra-mf-unvented-crawlspace-left-bottom-double-loaded-interior.xml',
           'extra-mf-unvented-crawlspace-left-middle-double-loaded-interior.xml',
           'extra-mf-unvented-crawlspace-left-top-double-loaded-interior.xml',
           'extra-mf-unvented-crawlspace-middle-bottom-double-loaded-interior.xml',
           'extra-mf-unvented-crawlspace-middle-middle-double-loaded-interior.xml',
           'extra-mf-unvented-crawlspace-middle-top-double-loaded-interior.xml',
           'extra-mf-unvented-crawlspace-right-bottom-double-loaded-interior.xml',
           'extra-mf-unvented-crawlspace-right-middle-double-loaded-interior.xml',
           'extra-mf-unvented-crawlspace-right-top-double-loaded-interior.xml'].include? hpxml_file
      args['geometry_corridor_position'] = 'Double-Loaded Interior'
    end

    # Error
    if ['error-heating-system-and-heat-pump.xml'].include? hpxml_file
      args['cooling_system_type'] = 'none'
      args['heat_pump_type'] = HPXML::HVACTypeHeatPumpAirToAir
    elsif ['error-cooling-system-and-heat-pump.xml'].include? hpxml_file
      args['heating_system_type'] = 'none'
      args['heat_pump_type'] = HPXML::HVACTypeHeatPumpAirToAir
    elsif ['error-sfd-finished-basement-zero-foundation-height.xml'].include? hpxml_file
      args['geometry_foundation_height'] = 0.0
    elsif ['error-sfa-ambient.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeAmbient
      args.delete('geometry_rim_joist_height')
      args.delete('rim_joist_assembly_r')
    elsif ['error-mf-bottom-crawlspace-zero-foundation-height.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceUnvented
      args['geometry_foundation_height'] = 0.0
      args['geometry_unit_level'] = 'Bottom'
    elsif ['error-ducts-location-and-areas-not-same-type.xml'].include? hpxml_file
      args.delete('ducts_supply_location')
    elsif ['error-second-heating-system-serves-total-heat-load.xml'].include? hpxml_file
      args['heating_system_2_type'] = HPXML::HVACTypeFireplace
      args['heating_system_2_fraction_heat_load_served'] = 1.0
    elsif ['error-second-heating-system-but-no-primary-heating.xml'].include? hpxml_file
      args['heating_system_type'] = 'none'
      args['heating_system_2_type'] = HPXML::HVACTypeFireplace
    elsif ['error-sfa-no-building-orientation.xml'].include? hpxml_file
      args.delete('geometry_building_num_units')
      args.delete('geometry_unit_horizontal_location')
    elsif ['error-mf-no-building-orientation.xml'].include? hpxml_file
      args.delete('geometry_building_num_units')
      args.delete('geometry_unit_level')
      args.delete('geometry_unit_horizontal_location')
    elsif ['error-dhw-indirect-without-boiler.xml'].include? hpxml_file
      args['water_heater_type'] = HPXML::WaterHeaterTypeCombiStorage
    elsif ['error-conditioned-attic-with-one-floor-above-grade.xml'].include? hpxml_file
      args['geometry_attic_type'] = HPXML::AtticTypeConditioned
      args['ceiling_assembly_r'] = 0.0
    elsif ['error-zero-number-of-bedrooms.xml'].include? hpxml_file
      args['geometry_unit_num_bedrooms'] = 0
    elsif ['error-sfd-with-shared-system.xml'].include? hpxml_file
      args['heating_system_type'] = "Shared #{HPXML::HVACTypeBoiler} w/ Baseboard"
    elsif ['error-rim-joist-height-but-no-assembly-r.xml'].include? hpxml_file
      args.delete('rim_joist_assembly_r')
    elsif ['error-rim-joist-assembly-r-but-no-height.xml'].include? hpxml_file
      args.delete('geometry_rim_joist_height')
    end

    # Warning
    if ['warning-non-electric-heat-pump-water-heater.xml'].include? hpxml_file
      args['water_heater_type'] = HPXML::WaterHeaterTypeHeatPump
      args['water_heater_fuel_type'] = HPXML::FuelTypeNaturalGas
      args['water_heater_efficiency'] = 2.3
    elsif ['warning-sfd-slab-non-zero-foundation-height.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeSlab
      args['geometry_foundation_height_above_grade'] = 0.0
    elsif ['warning-mf-bottom-slab-non-zero-foundation-height.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeSlab
      args['geometry_foundation_height_above_grade'] = 0.0
      args['geometry_unit_level'] = 'Bottom'
    elsif ['warning-slab-non-zero-foundation-height-above-grade.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeSlab
      args['geometry_foundation_height'] = 0.0
    elsif ['warning-second-heating-system-serves-majority-heat.xml'].include? hpxml_file
      args['heating_system_fraction_heat_load_served'] = 0.4
      args['heating_system_2_type'] = HPXML::HVACTypeFireplace
      args['heating_system_2_fraction_heat_load_served'] = 0.6
    elsif ['warning-vented-crawlspace-with-wall-and-ceiling-insulation.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceVented
      args['geometry_foundation_height'] = 3.0
      args['floor_over_foundation_assembly_r'] = 10
      args['foundation_wall_insulation_distance_to_bottom'] = 0.0
      args['foundation_wall_assembly_r'] = 10
    elsif ['warning-unvented-crawlspace-with-wall-and-ceiling-insulation.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceUnvented
      args['geometry_foundation_height'] = 3.0
      args['floor_over_foundation_assembly_r'] = 10
      args['foundation_wall_insulation_distance_to_bottom'] = 0.0
      args['foundation_wall_assembly_r'] = 10
    elsif ['warning-unconditioned-basement-with-wall-and-ceiling-insulation.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeBasementUnconditioned
      args['floor_over_foundation_assembly_r'] = 10
      args['foundation_wall_assembly_r'] = 10
    elsif ['warning-vented-attic-with-floor-and-roof-insulation.xml'].include? hpxml_file
      args['geometry_attic_type'] = HPXML::AtticTypeVented
      args['roof_assembly_r'] = 10
      args['ducts_supply_location'] = HPXML::LocationAtticVented
      args['ducts_return_location'] = HPXML::LocationAtticVented
    elsif ['warning-unvented-attic-with-floor-and-roof-insulation.xml'].include? hpxml_file
      args['geometry_attic_type'] = HPXML::AtticTypeUnvented
      args['roof_assembly_r'] = 10
    elsif ['warning-conditioned-basement-with-ceiling-insulation.xml'].include? hpxml_file
      args['geometry_foundation_type'] = HPXML::FoundationTypeBasementConditioned
      args['floor_over_foundation_assembly_r'] = 10
    elsif ['warning-conditioned-attic-with-floor-insulation.xml'].include? hpxml_file
      args['geometry_num_floors_above_grade'] = 2
      args['geometry_attic_type'] = HPXML::AtticTypeConditioned
      args['ducts_supply_location'] = HPXML::LocationLivingSpace
      args['ducts_return_location'] = HPXML::LocationLivingSpace
    elsif ['warning-multipliers-without-tv-plug-loads.xml'].include? hpxml_file
      args['misc_plug_loads_television_annual_kwh'] = 0.0
      args['misc_plug_loads_television_usage_multiplier'] = 1.0
    elsif ['warning-multipliers-without-other-plug-loads.xml'].include? hpxml_file
      args['misc_plug_loads_other_annual_kwh'] = 0.0
      args['misc_plug_loads_other_usage_multiplier'] = 1.0
    elsif ['warning-multipliers-without-well-pump-plug-loads.xml'].include? hpxml_file
      args['misc_plug_loads_well_pump_annual_kwh'] = 0.0
      args['misc_plug_loads_well_pump_usage_multiplier'] = 1.0
    elsif ['warning-multipliers-without-vehicle-plug-loads.xml'].include? hpxml_file
      args['misc_plug_loads_vehicle_annual_kwh'] = 0.0
      args['misc_plug_loads_vehicle_usage_multiplier'] = 1.0
    elsif ['warning-multipliers-without-fuel-loads.xml'].include? hpxml_file
      args['misc_fuel_loads_grill_usage_multiplier'] = 1.0
      args['misc_fuel_loads_lighting_usage_multiplier'] = 1.0
      args['misc_fuel_loads_fireplace_usage_multiplier'] = 1.0
    end
  end

  def _test_measure(args_hash, expected_error, expected_warning)
    # create an instance of the measure
    measure = BuildResidentialHPXML.new

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    model = OpenStudio::Model::Model.new

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        retval = temp_arg_var.setValue(args_hash[arg.name])
        if not retval # Try passing as string instead
          assert(temp_arg_var.setValue(args_hash[arg.name].to_s))
        end
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # assert whether it ran correctly
    if expected_error.nil?
      # show the output
      show_output(result) unless result.value.valueName == 'Success'

      assert_equal('Success', result.value.valueName)
      assert(File.exist?(args_hash['hpxml_path']))
    else
      assert_equal('Fail', result.value.valueName)
      assert(!File.exist?(args_hash['hpxml_path']))
    end

    # check warnings/errors
    if not expected_error.nil?
      assert(runner.result.stepErrors.select { |s| s == expected_error }.size > 0)
    end
    if not expected_warning.nil?
      assert(runner.result.stepWarnings.select { |s| s == expected_warning }.size > 0)
    end
  end
end
