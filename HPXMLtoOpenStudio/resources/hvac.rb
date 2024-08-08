# frozen_string_literal: true

# TODO
module HVAC
  AirSourceHeatRatedODB = 47.0 # degF, Rated outdoor drybulb for air-source systems, heating
  AirSourceHeatRatedIDB = 70.0 # degF, Rated indoor drybulb for air-source systems, heating
  AirSourceCoolRatedODB = 95.0 # degF, Rated outdoor drybulb for air-source systems, cooling
  AirSourceCoolRatedIWB = 67.0 # degF, Rated indoor wetbulb for air-source systems, cooling
  CrankcaseHeaterTemp = 50.0 # degF

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param cooling_system [TODO] TODO
  # @param heating_system [TODO] TODO
  # @param sequential_cool_load_fracs [TODO] TODO
  # @param sequential_heat_load_fracs [TODO] TODO
  # @param weather_max_drybulb [TODO] TODO
  # @param weather_min_drybulb [TODO] TODO
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param hvac_unavailable_periods [TODO] TODO
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param hpxml_header [HPXML::Header] HPXML Header object (one per HPXML file)
  # @return [TODO] TODO
  def self.apply_air_source_hvac_systems(model, runner, cooling_system, heating_system,
                                         sequential_cool_load_fracs, sequential_heat_load_fracs,
                                         weather_max_drybulb, weather_min_drybulb,
                                         control_zone, hvac_unavailable_periods, schedules_file, hpxml_bldg,
                                         hpxml_header)
    is_heatpump = false

    if (not cooling_system.nil?)
      is_onoff_thermostat_ddb = hpxml_header.hvac_onoff_thermostat_deadband.to_f > 0.0
      # Error-checking
      if is_onoff_thermostat_ddb
        if not [HPXML::HVACCompressorTypeSingleStage, HPXML::HVACCompressorTypeTwoStage].include? cooling_system.compressor_type
          # Throw error and stop simulation, because the setpoint schedule is already shifted, user will get wrong results otherwise.
          runner.registerError('On-off thermostat deadband currently is only supported for single speed or two speed air source systems.')
        end
        if hpxml_bldg.building_construction.number_of_units > 1
          # Throw error and stop simulation
          runner.registerError('NumberofUnits greater than 1 is not supported for on-off thermostat deadband.')
        end
      end
    else
      is_onoff_thermostat_ddb = false
    end

    if not cooling_system.nil?
      if cooling_system.is_a? HPXML::HeatPump
        is_heatpump = true
        if cooling_system.heat_pump_type == HPXML::HVACTypeHeatPumpAirToAir
          obj_name = Constants.ObjectNameAirSourceHeatPump
        elsif cooling_system.heat_pump_type == HPXML::HVACTypeHeatPumpMiniSplit
          obj_name = Constants.ObjectNameMiniSplitHeatPump
        elsif cooling_system.heat_pump_type == HPXML::HVACTypeHeatPumpPTHP
          obj_name = Constants.ObjectNamePTHP
          fan_watts_per_cfm = 0.0
        elsif cooling_system.heat_pump_type == HPXML::HVACTypeHeatPumpRoom
          obj_name = Constants.ObjectNameRoomHP
          fan_watts_per_cfm = 0.0
        else
          fail "Unexpected heat pump type: #{cooling_system.heat_pump_type}."
        end
      elsif cooling_system.is_a? HPXML::CoolingSystem
        if cooling_system.cooling_system_type == HPXML::HVACTypeCentralAirConditioner
          if heating_system.nil?
            obj_name = Constants.ObjectNameCentralAirConditioner
          else
            obj_name = Constants.ObjectNameCentralAirConditionerAndFurnace
            # error checking for fan power
            if (cooling_system.fan_watts_per_cfm.to_f != heating_system.fan_watts_per_cfm.to_f)
              fail "Fan powers for heating system '#{heating_system.id}' and cooling system '#{cooling_system.id}' are attached to a single distribution system and therefore must be the same."
            end
          end
        elsif [HPXML::HVACTypeRoomAirConditioner, HPXML::HVACTypePTAC].include? cooling_system.cooling_system_type
          fan_watts_per_cfm = 0.0
          if cooling_system.cooling_system_type == HPXML::HVACTypeRoomAirConditioner
            obj_name = Constants.ObjectNameRoomAirConditioner
          else
            obj_name = Constants.ObjectNamePTAC
          end
        elsif cooling_system.cooling_system_type == HPXML::HVACTypeMiniSplitAirConditioner
          obj_name = Constants.ObjectNameMiniSplitAirConditioner
        else
          fail "Unexpected cooling system type: #{cooling_system.cooling_system_type}."
        end
      end
    elsif (heating_system.is_a? HPXML::HeatingSystem) && (heating_system.heating_system_type == HPXML::HVACTypeFurnace)
      obj_name = Constants.ObjectNameFurnace
    else
      fail "Unexpected heating system type: #{heating_system.heating_system_type}, expect central air source hvac systems."
    end
    if fan_watts_per_cfm.nil?
      if (not cooling_system.nil?) && (not cooling_system.fan_watts_per_cfm.nil?)
        fan_watts_per_cfm = cooling_system.fan_watts_per_cfm
      else
        fan_watts_per_cfm = heating_system.fan_watts_per_cfm
      end
    end

    # Calculate max rated cfm
    max_rated_fan_cfm = -9999
    if not cooling_system.nil?
      clg_ap = cooling_system.additional_properties
      if not cooling_system.cooling_detailed_performance_data.empty?
        cooling_system.cooling_detailed_performance_data.select { |dp| dp.capacity_description == HPXML::CapacityDescriptionMaximum }.each do |dp|
          rated_fan_cfm = UnitConversions.convert(dp.capacity, 'Btu/hr', 'ton') * clg_ap.cool_rated_cfm_per_ton[-1]
          max_rated_fan_cfm = rated_fan_cfm if rated_fan_cfm > max_rated_fan_cfm
        end
      else
        rated_fan_cfm = UnitConversions.convert(cooling_system.cooling_capacity * clg_ap.cool_capacity_ratios[-1], 'Btu/hr', 'ton') * clg_ap.cool_rated_cfm_per_ton[-1]
        max_rated_fan_cfm = rated_fan_cfm if rated_fan_cfm > max_rated_fan_cfm
      end
    end
    if not heating_system.nil?
      htg_ap = heating_system.additional_properties
      if not heating_system.heating_detailed_performance_data.empty?
        heating_system.heating_detailed_performance_data.select { |dp| dp.capacity_description == HPXML::CapacityDescriptionMaximum }.each do |dp|
          rated_fan_cfm = UnitConversions.convert(dp.capacity, 'Btu/hr', 'ton') * htg_ap.heat_rated_cfm_per_ton[-1]
          max_rated_fan_cfm = rated_fan_cfm if rated_fan_cfm > max_rated_fan_cfm
        end
      elsif is_heatpump
        rated_fan_cfm = UnitConversions.convert(heating_system.heating_capacity * htg_ap.heat_capacity_ratios[-1], 'Btu/hr', 'ton') * htg_ap.heat_rated_cfm_per_ton[-1]
        max_rated_fan_cfm = rated_fan_cfm if rated_fan_cfm > max_rated_fan_cfm
      end
    end

    fan_cfms = []
    if not cooling_system.nil?
      # Cooling Coil
      clg_coil = create_dx_cooling_coil(model, obj_name, cooling_system, max_rated_fan_cfm, weather_max_drybulb, is_onoff_thermostat_ddb)

      clg_cfm = cooling_system.cooling_airflow_cfm
      clg_ap.cool_fan_speed_ratios.each do |r|
        fan_cfms << clg_cfm * r
      end
      if (cooling_system.is_a? HPXML::CoolingSystem) && cooling_system.has_integrated_heating
        if cooling_system.integrated_heating_system_fuel == HPXML::FuelTypeElectricity
          htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model)
          htg_coil.setEfficiency(cooling_system.integrated_heating_system_efficiency_percent)
        else
          htg_coil = OpenStudio::Model::CoilHeatingGas.new(model)
          htg_coil.setGasBurnerEfficiency(cooling_system.integrated_heating_system_efficiency_percent)
          htg_coil.setOnCycleParasiticElectricLoad(0)
          htg_coil.setOffCycleParasiticGasLoad(0)
          htg_coil.setFuelType(EPlus.fuel_type(cooling_system.integrated_heating_system_fuel))
        end
        htg_coil.setNominalCapacity(UnitConversions.convert(cooling_system.integrated_heating_system_capacity, 'Btu/hr', 'W'))
        htg_coil.setName(obj_name + ' htg coil')
        htg_coil.additionalProperties.setFeature('HPXML_ID', cooling_system.id) # Used by reporting measure
        htg_cfm = cooling_system.integrated_heating_system_airflow_cfm
        fan_cfms << htg_cfm
      end
    end

    if not heating_system.nil?
      htg_cfm = heating_system.heating_airflow_cfm
      if is_heatpump
        supp_max_temp = htg_ap.supp_max_temp

        htg_ap.heat_fan_speed_ratios.each do |r|
          fan_cfms << htg_cfm * r
        end
        # Defrost calculations
        if hpxml_header.defrost_model_type == HPXML::AdvancedResearchDefrostModelTypeAdvanced
          q_dot_defrost, p_dot_defrost = calculate_heat_pump_defrost_load_power_watts(heating_system, hpxml_bldg.building_construction.number_of_units,
                                                                                      fan_cfms.max, htg_cfm * htg_ap.heat_fan_speed_ratios[-1],
                                                                                      fan_watts_per_cfm)
        elsif hpxml_header.defrost_model_type != HPXML::AdvancedResearchDefrostModelTypeStandard
          fail 'unknown defrost model type.'
        end

        # Heating Coil
        htg_coil = create_dx_heating_coil(model, obj_name, heating_system, max_rated_fan_cfm, weather_min_drybulb, hpxml_header.defrost_model_type, p_dot_defrost, is_onoff_thermostat_ddb)

        # Supplemental Heating Coil
        htg_supp_coil = create_supp_heating_coil(model, obj_name, heating_system, hpxml_header, runner, hpxml_bldg)
      else
        # Heating Coil
        fan_cfms << htg_cfm
        if heating_system.heating_system_fuel == HPXML::FuelTypeElectricity
          htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model)
          htg_coil.setEfficiency(heating_system.heating_efficiency_afue)
        else
          htg_coil = OpenStudio::Model::CoilHeatingGas.new(model)
          htg_coil.setGasBurnerEfficiency(heating_system.heating_efficiency_afue)
          htg_coil.setOnCycleParasiticElectricLoad(0)
          htg_coil.setOffCycleParasiticGasLoad(UnitConversions.convert(heating_system.pilot_light_btuh.to_f, 'Btu/hr', 'W'))
          htg_coil.setFuelType(EPlus.fuel_type(heating_system.heating_system_fuel))
        end
        htg_coil.setNominalCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
        htg_coil.setName(obj_name + ' htg coil')
        htg_coil.additionalProperties.setFeature('HPXML_ID', heating_system.id) # Used by reporting measure
        htg_coil.additionalProperties.setFeature('IsHeatPumpBackup', heating_system.is_heat_pump_backup_system) # Used by reporting measure
      end
    end

    # Fan
    fan = create_supply_fan(model, obj_name, fan_watts_per_cfm, fan_cfms)
    if heating_system.is_a?(HPXML::HeatPump) && (not heating_system.backup_system.nil?) && (not htg_ap.hp_min_temp.nil?)
      # Disable blower fan power below compressor lockout temperature if separate backup heating system
      set_fan_power_ems_program(model, fan, htg_ap.hp_min_temp)
    end
    if (not cooling_system.nil?) && (not heating_system.nil?) && (cooling_system == heating_system)
      disaggregate_fan_or_pump(model, fan, htg_coil, clg_coil, htg_supp_coil, cooling_system)
    else
      if not cooling_system.nil?
        if cooling_system.has_integrated_heating
          disaggregate_fan_or_pump(model, fan, htg_coil, clg_coil, nil, cooling_system)
        else
          disaggregate_fan_or_pump(model, fan, nil, clg_coil, nil, cooling_system)
        end
      end
      if not heating_system.nil?
        if heating_system.is_heat_pump_backup_system
          disaggregate_fan_or_pump(model, fan, nil, nil, htg_coil, heating_system)
        else
          disaggregate_fan_or_pump(model, fan, htg_coil, nil, htg_supp_coil, heating_system)
        end
      end
    end

    # Unitary System
    air_loop_unitary = create_air_loop_unitary_system(model, obj_name, fan, htg_coil, clg_coil, htg_supp_coil, htg_cfm, clg_cfm, supp_max_temp)

    # Unitary System Performance
    if (not clg_ap.nil?) && (clg_ap.cool_fan_speed_ratios.size > 1)
      perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
      perf.setSingleModeOperation(false)
      for speed in 1..clg_ap.cool_fan_speed_ratios.size
        if is_heatpump
          f = OpenStudio::Model::SupplyAirflowRatioField.new(htg_ap.heat_fan_speed_ratios[speed - 1], clg_ap.cool_fan_speed_ratios[speed - 1])
        else
          f = OpenStudio::Model::SupplyAirflowRatioField.fromCoolingRatio(clg_ap.cool_fan_speed_ratios[speed - 1])
        end
        perf.addSupplyAirflowRatioField(f)
      end
      air_loop_unitary.setDesignSpecificationMultispeedObject(perf)
    end

    # Air Loop
    air_loop = create_air_loop(model, obj_name, air_loop_unitary, control_zone, sequential_heat_load_fracs, sequential_cool_load_fracs, [htg_cfm.to_f, clg_cfm.to_f].max, heating_system, hvac_unavailable_periods)

    add_backup_staging_EMS(model, air_loop_unitary, htg_supp_coil, control_zone, htg_coil)
    apply_installation_quality(model, heating_system, cooling_system, air_loop_unitary, htg_coil, clg_coil, control_zone)

    # supp coil control in staing EMS
    apply_two_speed_realistic_staging_EMS(model, air_loop_unitary, htg_supp_coil, control_zone, is_onoff_thermostat_ddb, cooling_system)

    apply_supp_coil_EMS_for_ddb_thermostat(model, htg_supp_coil, control_zone, htg_coil, is_onoff_thermostat_ddb, cooling_system)

    apply_max_power_EMS(model, runner, air_loop_unitary, control_zone, heating_system, cooling_system, htg_supp_coil, clg_coil, htg_coil, schedules_file)

    if is_heatpump && hpxml_header.defrost_model_type == HPXML::AdvancedResearchDefrostModelTypeAdvanced
      apply_advanced_defrost(model, htg_coil, air_loop_unitary, control_zone.spaces[0], htg_supp_coil, cooling_system, q_dot_defrost)
    end

    return air_loop
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param cooling_system [TODO] TODO
  # @param sequential_cool_load_fracs [TODO] TODO
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param hvac_unavailable_periods [TODO] TODO
  # @param unit_multiplier [Integer] Number of similar dwelling units
  # @return [TODO] TODO
  def self.apply_evaporative_cooler(model, cooling_system, sequential_cool_load_fracs, control_zone,
                                    hvac_unavailable_periods, unit_multiplier)

    obj_name = Constants.ObjectNameEvaporativeCooler

    clg_ap = cooling_system.additional_properties
    clg_cfm = cooling_system.cooling_airflow_cfm

    # Evap Cooler
    evap_cooler = OpenStudio::Model::EvaporativeCoolerDirectResearchSpecial.new(model, model.alwaysOnDiscreteSchedule)
    evap_cooler.setName(obj_name)
    evap_cooler.setCoolerEffectiveness(clg_ap.effectiveness)
    evap_cooler.setEvaporativeOperationMinimumDrybulbTemperature(0) # relax limitation to open evap cooler for any potential cooling
    evap_cooler.setEvaporativeOperationMaximumLimitWetbulbTemperature(50) # relax limitation to open evap cooler for any potential cooling
    evap_cooler.setEvaporativeOperationMaximumLimitDrybulbTemperature(50) # relax limitation to open evap cooler for any potential cooling
    evap_cooler.setPrimaryAirDesignFlowRate(UnitConversions.convert(clg_cfm, 'cfm', 'm^3/s'))
    evap_cooler.additionalProperties.setFeature('HPXML_ID', cooling_system.id) # Used by reporting measure

    # Air Loop
    air_loop = create_air_loop(model, obj_name, evap_cooler, control_zone, [0], sequential_cool_load_fracs, clg_cfm, nil, hvac_unavailable_periods)

    # Fan
    fan_watts_per_cfm = [2.79 * (clg_cfm / unit_multiplier)**-0.29, 0.6].min # W/cfm; fit of efficacy to air flow from the CEC listed equipment
    fan = create_supply_fan(model, obj_name, fan_watts_per_cfm, [clg_cfm])
    fan.addToNode(air_loop.supplyInletNode)
    disaggregate_fan_or_pump(model, fan, nil, evap_cooler, nil, cooling_system)

    # Outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.resetEconomizerMinimumLimitDryBulbTemperature
    oa_intake_controller.setMinimumFractionofOutdoorAirSchedule(model.alwaysOnDiscreteSchedule)
    oa_intake_controller.setMaximumOutdoorAirFlowRate(UnitConversions.convert(clg_cfm, 'cfm', 'm^3/s'))

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA System")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # air handler controls
    # setpoint follows OAT WetBulb
    evap_stpt_manager = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(model)
    evap_stpt_manager.setName('Follow OATwb')
    evap_stpt_manager.setReferenceTemperatureType('OutdoorAirWetBulb')
    evap_stpt_manager.setOffsetTemperatureDifference(0.0)
    evap_stpt_manager.addToNode(air_loop.supplyOutletNode)

    return air_loop
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param weather [WeatherFile] Weather object containing EPW information
  # @param heat_pump [TODO] TODO
  # @param sequential_heat_load_fracs [TODO] TODO
  # @param sequential_cool_load_fracs [TODO] TODO
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param ground_conductivity [TODO] TODO
  # @param ground_diffusivity [TODO] TODO
  # @param hvac_unavailable_periods [TODO] TODO
  # @param unit_multiplier [Integer] Number of similar dwelling units
  # @return [TODO] TODO
  def self.apply_ground_to_air_heat_pump(model, runner, weather, heat_pump,
                                         sequential_heat_load_fracs, sequential_cool_load_fracs,
                                         control_zone, ground_conductivity, ground_diffusivity,
                                         hvac_unavailable_periods, unit_multiplier)

    if unit_multiplier > 1
      # FUTURE: Figure out how to allow this. If we allow it, update docs and hpxml_translator_test.rb too.
      # https://github.com/NREL/OpenStudio-HPXML/issues/1499
      fail 'NumberofUnits greater than 1 is not supported for ground-to-air heat pumps.'
    end

    obj_name = Constants.ObjectNameGroundSourceHeatPump

    geothermal_loop = heat_pump.geothermal_loop
    hp_ap = heat_pump.additional_properties

    htg_cfm = heat_pump.heating_airflow_cfm
    clg_cfm = heat_pump.cooling_airflow_cfm
    htg_cfm_rated = heat_pump.airflow_defect_ratio.nil? ? htg_cfm : (htg_cfm / (1.0 + heat_pump.airflow_defect_ratio))
    clg_cfm_rated = heat_pump.airflow_defect_ratio.nil? ? clg_cfm : (clg_cfm / (1.0 + heat_pump.airflow_defect_ratio))

    if hp_ap.frac_glycol == 0
      hp_ap.fluid_type = Constants.FluidWater
      runner.registerWarning("Specified #{hp_ap.fluid_type} fluid type and 0 fraction of glycol, so assuming #{Constants.FluidWater} fluid type.")
    end

    # Apply unit multiplier
    geothermal_loop.loop_flow *= unit_multiplier
    geothermal_loop.num_bore_holes *= unit_multiplier

    # Cooling Coil
    clg_total_cap_curve = create_curve_quad_linear(model, hp_ap.cool_cap_curve_spec[0], obj_name + ' clg total cap curve')
    clg_sens_cap_curve = create_curve_quint_linear(model, hp_ap.cool_sh_curve_spec[0], obj_name + ' clg sens cap curve')
    clg_power_curve = create_curve_quad_linear(model, hp_ap.cool_power_curve_spec[0], obj_name + ' clg power curve')
    clg_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(model, clg_total_cap_curve, clg_sens_cap_curve, clg_power_curve)
    clg_coil.setName(obj_name + ' clg coil')
    clg_coil.setRatedCoolingCoefficientofPerformance(hp_ap.cool_rated_cops[0])
    clg_coil.setNominalTimeforCondensateRemovaltoBegin(1000)
    clg_coil.setRatioofInitialMoistureEvaporationRateandSteadyStateLatentCapacity(1.5)
    clg_coil.setRatedAirFlowRate(UnitConversions.convert(clg_cfm_rated, 'cfm', 'm^3/s'))
    clg_coil.setRatedWaterFlowRate(UnitConversions.convert(geothermal_loop.loop_flow, 'gal/min', 'm^3/s'))
    clg_coil.setRatedEnteringWaterTemperature(UnitConversions.convert(80, 'F', 'C'))
    clg_coil.setRatedEnteringAirDryBulbTemperature(UnitConversions.convert(80, 'F', 'C'))
    clg_coil.setRatedEnteringAirWetBulbTemperature(UnitConversions.convert(67, 'F', 'C'))
    clg_coil.setRatedTotalCoolingCapacity(UnitConversions.convert(heat_pump.cooling_capacity, 'Btu/hr', 'W'))
    clg_coil.setRatedSensibleCoolingCapacity(UnitConversions.convert(hp_ap.cooling_capacity_sensible, 'Btu/hr', 'W'))
    clg_coil.additionalProperties.setFeature('HPXML_ID', heat_pump.id) # Used by reporting measure

    # Heating Coil
    htg_cap_curve = create_curve_quad_linear(model, hp_ap.heat_cap_curve_spec[0], obj_name + ' htg cap curve')
    htg_power_curve = create_curve_quad_linear(model, hp_ap.heat_power_curve_spec[0], obj_name + ' htg power curve')
    htg_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(model, htg_cap_curve, htg_power_curve)
    htg_coil.setName(obj_name + ' htg coil')
    htg_coil.setRatedHeatingCoefficientofPerformance(hp_ap.heat_rated_cops[0])
    htg_coil.setRatedAirFlowRate(UnitConversions.convert(htg_cfm_rated, 'cfm', 'm^3/s'))
    htg_coil.setRatedWaterFlowRate(UnitConversions.convert(geothermal_loop.loop_flow, 'gal/min', 'm^3/s'))
    htg_coil.setRatedEnteringWaterTemperature(UnitConversions.convert(60, 'F', 'C'))
    htg_coil.setRatedEnteringAirDryBulbTemperature(UnitConversions.convert(70, 'F', 'C'))
    htg_coil.setRatedHeatingCapacity(UnitConversions.convert(heat_pump.heating_capacity, 'Btu/hr', 'W'))
    htg_coil.additionalProperties.setFeature('HPXML_ID', heat_pump.id) # Used by reporting measure

    # Supplemental Heating Coil
    htg_supp_coil = create_supp_heating_coil(model, obj_name, heat_pump)

    # Site Ground Temperature Undisturbed
    xing = OpenStudio::Model::SiteGroundTemperatureUndisturbedXing.new(model)
    xing.setSoilSurfaceTemperatureAmplitude1(UnitConversions.convert(weather.data.DeepGroundSurfTempAmp1, 'deltaf', 'deltac'))
    xing.setSoilSurfaceTemperatureAmplitude2(UnitConversions.convert(weather.data.DeepGroundSurfTempAmp2, 'deltaf', 'deltac'))
    xing.setPhaseShiftofTemperatureAmplitude1(weather.data.DeepGroundPhaseShiftTempAmp1)
    xing.setPhaseShiftofTemperatureAmplitude2(weather.data.DeepGroundPhaseShiftTempAmp2)

    # Ground Heat Exchanger
    ground_heat_exch_vert = OpenStudio::Model::GroundHeatExchangerVertical.new(model, xing)
    ground_heat_exch_vert.setName(obj_name + ' exchanger')
    ground_heat_exch_vert.setBoreHoleRadius(UnitConversions.convert(geothermal_loop.bore_diameter / 2.0, 'in', 'm'))
    ground_heat_exch_vert.setGroundThermalConductivity(UnitConversions.convert(ground_conductivity, 'Btu/(hr*ft*R)', 'W/(m*K)'))
    ground_heat_exch_vert.setGroundThermalHeatCapacity(UnitConversions.convert(ground_conductivity / ground_diffusivity, 'Btu/(ft^3*F)', 'J/(m^3*K)'))
    ground_heat_exch_vert.setGroundTemperature(UnitConversions.convert(weather.data.DeepGroundAnnualTemp, 'F', 'C'))
    ground_heat_exch_vert.setGroutThermalConductivity(UnitConversions.convert(geothermal_loop.grout_conductivity, 'Btu/(hr*ft*R)', 'W/(m*K)'))
    ground_heat_exch_vert.setPipeThermalConductivity(UnitConversions.convert(geothermal_loop.pipe_conductivity, 'Btu/(hr*ft*R)', 'W/(m*K)'))
    ground_heat_exch_vert.setPipeOutDiameter(UnitConversions.convert(hp_ap.pipe_od, 'in', 'm'))
    ground_heat_exch_vert.setUTubeDistance(UnitConversions.convert(geothermal_loop.shank_spacing, 'in', 'm'))
    ground_heat_exch_vert.setPipeThickness(UnitConversions.convert((hp_ap.pipe_od - hp_ap.pipe_id) / 2.0, 'in', 'm'))
    ground_heat_exch_vert.setMaximumLengthofSimulation(1)
    ground_heat_exch_vert.setDesignFlowRate(UnitConversions.convert(geothermal_loop.loop_flow, 'gal/min', 'm^3/s'))
    ground_heat_exch_vert.setNumberofBoreHoles(geothermal_loop.num_bore_holes)
    ground_heat_exch_vert.setBoreHoleLength(UnitConversions.convert(geothermal_loop.bore_length, 'ft', 'm'))
    ground_heat_exch_vert.setGFunctionReferenceRatio(ground_heat_exch_vert.boreHoleRadius.get / ground_heat_exch_vert.boreHoleLength.get) # ensure this ratio is consistent with rb/H so that g values will be taken as-is
    ground_heat_exch_vert.removeAllGFunctions
    for i in 0..(hp_ap.GSHP_G_Functions[0].size - 1)
      ground_heat_exch_vert.addGFunction(hp_ap.GSHP_G_Functions[0][i], hp_ap.GSHP_G_Functions[1][i])
    end
    xing = ground_heat_exch_vert.undisturbedGroundTemperatureModel.to_SiteGroundTemperatureUndisturbedXing.get
    xing.setSoilThermalConductivity(ground_heat_exch_vert.groundThermalConductivity.get)
    xing.setSoilSpecificHeat(ground_heat_exch_vert.groundThermalHeatCapacity.get / xing.soilDensity)
    xing.setAverageSoilSurfaceTemperature(ground_heat_exch_vert.groundTemperature.get)

    # Plant Loop
    plant_loop = OpenStudio::Model::PlantLoop.new(model)
    plant_loop.setName(obj_name + ' condenser loop')
    if hp_ap.fluid_type == Constants.FluidWater
      plant_loop.setFluidType('Water')
    else
      plant_loop.setFluidType({ Constants.FluidPropyleneGlycol => 'PropyleneGlycol', Constants.FluidEthyleneGlycol => 'EthyleneGlycol' }[hp_ap.fluid_type])
      plant_loop.setGlycolConcentration((hp_ap.frac_glycol * 100).to_i)
    end
    plant_loop.setMaximumLoopTemperature(48.88889)
    plant_loop.setMinimumLoopTemperature(UnitConversions.convert(hp_ap.design_hw, 'F', 'C'))
    plant_loop.setMinimumLoopFlowRate(0)
    plant_loop.setLoadDistributionScheme('SequentialLoad')
    plant_loop.addSupplyBranchForComponent(ground_heat_exch_vert)
    plant_loop.addDemandBranchForComponent(htg_coil)
    plant_loop.addDemandBranchForComponent(clg_coil)
    plant_loop.setMaximumLoopFlowRate(UnitConversions.convert(geothermal_loop.loop_flow, 'gal/min', 'm^3/s'))

    sizing_plant = plant_loop.sizingPlant
    sizing_plant.setLoopType('Condenser')
    sizing_plant.setDesignLoopExitTemperature(UnitConversions.convert(hp_ap.design_chw, 'F', 'C'))
    sizing_plant.setLoopDesignTemperatureDifference(UnitConversions.convert(hp_ap.design_delta_t, 'deltaF', 'deltaC'))

    setpoint_mgr_follow_ground_temp = OpenStudio::Model::SetpointManagerFollowGroundTemperature.new(model)
    setpoint_mgr_follow_ground_temp.setName(obj_name + ' condenser loop temp')
    setpoint_mgr_follow_ground_temp.setControlVariable('Temperature')
    setpoint_mgr_follow_ground_temp.setMaximumSetpointTemperature(48.88889)
    setpoint_mgr_follow_ground_temp.setMinimumSetpointTemperature(UnitConversions.convert(hp_ap.design_hw, 'F', 'C'))
    setpoint_mgr_follow_ground_temp.setReferenceGroundTemperatureObjectType('Site:GroundTemperature:Deep')
    setpoint_mgr_follow_ground_temp.addToNode(plant_loop.supplyOutletNode)

    # Pump
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setName(obj_name + ' pump')
    pump.setMotorEfficiency(0.85)
    pump.setRatedPumpHead(20000)
    pump.setFractionofMotorInefficienciestoFluidStream(0)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(1)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(0)
    pump.setMinimumFlowRate(0)
    pump.setPumpControlType('Intermittent')
    pump.addToNode(plant_loop.supplyInletNode)
    if heat_pump.cooling_capacity > 1.0
      pump_w = heat_pump.pump_watts_per_ton * UnitConversions.convert(heat_pump.cooling_capacity, 'Btu/hr', 'ton')
    else
      pump_w = heat_pump.pump_watts_per_ton * UnitConversions.convert(heat_pump.heating_capacity, 'Btu/hr', 'ton')
    end
    pump_w = [pump_w, 1.0].max # prevent error if zero
    pump.setRatedPowerConsumption(pump_w)
    pump.setRatedFlowRate(calc_pump_rated_flow_rate(0.75, pump_w, pump.ratedPumpHead))
    disaggregate_fan_or_pump(model, pump, htg_coil, clg_coil, htg_supp_coil, heat_pump)

    # Pipes
    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    plant_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    plant_loop.addDemandBranchForComponent(coil_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.addToNode(plant_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.addToNode(plant_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.addToNode(plant_loop.demandOutletNode)

    # Fan
    fan = create_supply_fan(model, obj_name, heat_pump.fan_watts_per_cfm, [htg_cfm, clg_cfm])
    disaggregate_fan_or_pump(model, fan, htg_coil, clg_coil, htg_supp_coil, heat_pump)

    # Unitary System
    air_loop_unitary = create_air_loop_unitary_system(model, obj_name, fan, htg_coil, clg_coil, htg_supp_coil, htg_cfm, clg_cfm, 40.0)
    set_pump_power_ems_program(model, pump_w, pump, air_loop_unitary)

    if heat_pump.is_shared_system
      # Shared pump power per ANSI/RESNET/ICC 301-2019 Section 4.4.5.1 (pump runs 8760)
      shared_pump_w = heat_pump.shared_loop_watts / heat_pump.number_of_units_served.to_f
      equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      equip_def.setName(Constants.ObjectNameGSHPSharedPump)
      equip = OpenStudio::Model::ElectricEquipment.new(equip_def)
      equip.setName(equip_def.name.to_s)
      equip.setSpace(control_zone.spaces[0]) # no heat gain, so assign the equipment to an arbitrary space
      equip_def.setDesignLevel(shared_pump_w)
      equip_def.setFractionRadiant(0)
      equip_def.setFractionLatent(0)
      equip_def.setFractionLost(1)
      equip.setSchedule(model.alwaysOnDiscreteSchedule)
      equip.setEndUseSubcategory(Constants.ObjectNameGSHPSharedPump)
      equip.additionalProperties.setFeature('HPXML_ID', heat_pump.id) # Used by reporting measure
    end

    # Air Loop
    air_loop = create_air_loop(model, obj_name, air_loop_unitary, control_zone, sequential_heat_load_fracs, sequential_cool_load_fracs, [htg_cfm, clg_cfm].max, heat_pump, hvac_unavailable_periods)

    # HVAC Installation Quality
    apply_installation_quality(model, heat_pump, heat_pump, air_loop_unitary, htg_coil, clg_coil, control_zone)

    return air_loop
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param heat_pump [TODO] TODO
  # @param sequential_heat_load_fracs [TODO] TODO
  # @param sequential_cool_load_fracs [TODO] TODO
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param hvac_unavailable_periods [TODO] TODO
  # @return [TODO] TODO
  def self.apply_water_loop_to_air_heat_pump(model, heat_pump,
                                             sequential_heat_load_fracs, sequential_cool_load_fracs,
                                             control_zone, hvac_unavailable_periods)
    if heat_pump.fraction_cool_load_served > 0
      # WLHPs connected to chillers or cooling towers should have already been converted to
      # central air conditioners
      fail 'WLHP model should only be called for central boilers.'
    end

    obj_name = Constants.ObjectNameWaterLoopHeatPump

    htg_cfm = heat_pump.heating_airflow_cfm

    # Cooling Coil (none)
    clg_coil = nil

    # Heating Coil (model w/ constant efficiency)
    constant_biquadratic = create_curve_biquadratic_constant(model)
    constant_quadratic = create_curve_quadratic_constant(model)
    htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule, constant_biquadratic, constant_quadratic, constant_biquadratic, constant_quadratic, constant_quadratic)
    htg_coil.setName(obj_name + ' htg coil')
    htg_coil.setRatedCOP(heat_pump.heating_efficiency_cop)
    htg_coil.setDefrostTimePeriodFraction(0.00001) # Disable defrost; avoid E+ warning w/ value of zero
    htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(-40)
    htg_coil.setRatedTotalHeatingCapacity(UnitConversions.convert(heat_pump.heating_capacity, 'Btu/hr', 'W'))
    htg_coil.setRatedAirFlowRate(htg_cfm)
    htg_coil.additionalProperties.setFeature('HPXML_ID', heat_pump.id) # Used by reporting measure

    # Supplemental Heating Coil
    htg_supp_coil = create_supp_heating_coil(model, obj_name, heat_pump)

    # Fan
    fan_power_installed = 0.0 # Use provided net COP
    fan = create_supply_fan(model, obj_name, fan_power_installed, [htg_cfm])
    disaggregate_fan_or_pump(model, fan, htg_coil, clg_coil, htg_supp_coil, heat_pump)

    # Unitary System
    air_loop_unitary = create_air_loop_unitary_system(model, obj_name, fan, htg_coil, clg_coil, htg_supp_coil, htg_cfm, nil)

    # Air Loop
    air_loop = create_air_loop(model, obj_name, air_loop_unitary, control_zone, sequential_heat_load_fracs, sequential_cool_load_fracs, htg_cfm, heat_pump, hvac_unavailable_periods)

    return air_loop
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param heating_system [TODO] TODO
  # @param sequential_heat_load_fracs [TODO] TODO
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param hvac_unavailable_periods [TODO] TODO
  # @return [TODO] TODO
  def self.apply_boiler(model, runner, heating_system, sequential_heat_load_fracs, control_zone, hvac_unavailable_periods)
    obj_name = Constants.ObjectNameBoiler
    is_condensing = false # FUTURE: Expose as input; default based on AFUE
    oat_reset_enabled = false
    oat_high = nil
    oat_low = nil
    oat_hwst_high = nil
    oat_hwst_low = nil
    design_temp = 180.0 # F

    if oat_reset_enabled
      if oat_high.nil? || oat_low.nil? || oat_hwst_low.nil? || oat_hwst_high.nil?
        runner.registerWarning('Boiler outdoor air temperature (OAT) reset is enabled but no setpoints were specified so OAT reset is being disabled.')
        oat_reset_enabled = false
      end
    end

    # Plant Loop
    plant_loop = OpenStudio::Model::PlantLoop.new(model)
    plant_loop.setName(obj_name + ' hydronic heat loop')
    plant_loop.setFluidType('Water')
    plant_loop.setMaximumLoopTemperature(100)
    plant_loop.setMinimumLoopTemperature(0)
    plant_loop.setMinimumLoopFlowRate(0)
    plant_loop.autocalculatePlantLoopVolume()

    loop_sizing = plant_loop.sizingPlant
    loop_sizing.setLoopType('Heating')
    loop_sizing.setDesignLoopExitTemperature(UnitConversions.convert(design_temp, 'F', 'C'))
    loop_sizing.setLoopDesignTemperatureDifference(UnitConversions.convert(20.0, 'deltaF', 'deltaC'))

    # Pump
    pump_w = heating_system.electric_auxiliary_energy / 2.08
    pump_w = [pump_w, 1.0].max # prevent error if zero
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setName(obj_name + ' hydronic pump')
    pump.setRatedPowerConsumption(pump_w)
    pump.setMotorEfficiency(0.85)
    pump.setRatedPumpHead(20000)
    pump.setRatedFlowRate(calc_pump_rated_flow_rate(0.75, pump_w, pump.ratedPumpHead))
    pump.setFractionofMotorInefficienciestoFluidStream(0)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(1)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(0)
    pump.setPumpControlType('Intermittent')
    pump.addToNode(plant_loop.supplyInletNode)

    # Boiler
    boiler = OpenStudio::Model::BoilerHotWater.new(model)
    boiler.setName(obj_name)
    boiler.setFuelType(EPlus.fuel_type(heating_system.heating_system_fuel))
    if is_condensing
      # Convert Rated Efficiency at 80F and 1.0PLR where the performance curves are derived from to Design condition as input
      boiler_RatedHWRT = UnitConversions.convert(80.0, 'F', 'C')
      plr_Rated = 1.0
      plr_Design = 1.0
      boiler_DesignHWRT = UnitConversions.convert(design_temp - 20.0, 'F', 'C')
      # Efficiency curves are normalized using 80F return water temperature, at 0.254PLR
      condBlr_TE_Coeff = [1.058343061, 0.052650153, 0.0087272, 0.001742217, 0.00000333715, 0.000513723]
      boilerEff_Norm = heating_system.heating_efficiency_afue / (condBlr_TE_Coeff[0] - condBlr_TE_Coeff[1] * plr_Rated - condBlr_TE_Coeff[2] * plr_Rated**2 - condBlr_TE_Coeff[3] * boiler_RatedHWRT + condBlr_TE_Coeff[4] * boiler_RatedHWRT**2 + condBlr_TE_Coeff[5] * boiler_RatedHWRT * plr_Rated)
      boilerEff_Design = boilerEff_Norm * (condBlr_TE_Coeff[0] - condBlr_TE_Coeff[1] * plr_Design - condBlr_TE_Coeff[2] * plr_Design**2 - condBlr_TE_Coeff[3] * boiler_DesignHWRT + condBlr_TE_Coeff[4] * boiler_DesignHWRT**2 + condBlr_TE_Coeff[5] * boiler_DesignHWRT * plr_Design)
      boiler.setNominalThermalEfficiency(boilerEff_Design)
      boiler.setEfficiencyCurveTemperatureEvaluationVariable('EnteringBoiler')
      boiler_eff_curve = create_curve_biquadratic(model, [1.058343061, -0.052650153, -0.0087272, -0.001742217, 0.00000333715, 0.000513723], 'CondensingBoilerEff', 0.2, 1.0, 30.0, 85.0)
    else
      boiler.setNominalThermalEfficiency(heating_system.heating_efficiency_afue)
      boiler.setEfficiencyCurveTemperatureEvaluationVariable('LeavingBoiler')
      boiler_eff_curve = create_curve_bicubic(model, [1.111720116, 0.078614078, -0.400425756, 0.0, -0.000156783, 0.009384599, 0.234257955, 1.32927e-06, -0.004446701, -1.22498e-05], 'NonCondensingBoilerEff', 0.1, 1.0, 20.0, 80.0)
    end
    boiler.setNormalizedBoilerEfficiencyCurve(boiler_eff_curve)
    boiler.setMinimumPartLoadRatio(0.0)
    boiler.setMaximumPartLoadRatio(1.0)
    boiler.setBoilerFlowMode('LeavingSetpointModulated')
    boiler.setOptimumPartLoadRatio(1.0)
    boiler.setWaterOutletUpperTemperatureLimit(99.9)
    boiler.setOnCycleParasiticElectricLoad(0)
    boiler.setNominalCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
    boiler.setOffCycleParasiticFuelLoad(UnitConversions.convert(heating_system.pilot_light_btuh.to_f, 'Btu/hr', 'W'))
    plant_loop.addSupplyBranchForComponent(boiler)
    boiler.additionalProperties.setFeature('HPXML_ID', heating_system.id) # Used by reporting measure
    boiler.additionalProperties.setFeature('IsHeatPumpBackup', heating_system.is_heat_pump_backup_system) # Used by reporting measure
    set_pump_power_ems_program(model, pump_w, pump, boiler)

    if is_condensing && oat_reset_enabled
      setpoint_manager_oar = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
      setpoint_manager_oar.setName(obj_name + ' outdoor reset')
      setpoint_manager_oar.setControlVariable('Temperature')
      setpoint_manager_oar.setSetpointatOutdoorLowTemperature(UnitConversions.convert(oat_hwst_low, 'F', 'C'))
      setpoint_manager_oar.setOutdoorLowTemperature(UnitConversions.convert(oat_low, 'F', 'C'))
      setpoint_manager_oar.setSetpointatOutdoorHighTemperature(UnitConversions.convert(oat_hwst_high, 'F', 'C'))
      setpoint_manager_oar.setOutdoorHighTemperature(UnitConversions.convert(oat_high, 'F', 'C'))
      setpoint_manager_oar.addToNode(plant_loop.supplyOutletNode)
    end

    hydronic_heat_supply_setpoint = OpenStudio::Model::ScheduleConstant.new(model)
    hydronic_heat_supply_setpoint.setName(obj_name + ' hydronic heat supply setpoint')
    hydronic_heat_supply_setpoint.setValue(UnitConversions.convert(design_temp, 'F', 'C'))

    setpoint_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model, hydronic_heat_supply_setpoint)
    setpoint_manager_scheduled.setName(obj_name + ' hydronic heat loop setpoint manager')
    setpoint_manager_scheduled.setControlVariable('Temperature')
    setpoint_manager_scheduled.addToNode(plant_loop.supplyOutletNode)

    pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    plant_loop.addSupplyBranchForComponent(pipe_supply_bypass)
    pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_supply_outlet.addToNode(plant_loop.supplyOutletNode)
    pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    plant_loop.addDemandBranchForComponent(pipe_demand_bypass)
    pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_demand_inlet.addToNode(plant_loop.demandInletNode)
    pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_demand_outlet.addToNode(plant_loop.demandOutletNode)

    bb_ua = UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W') / UnitConversions.convert(UnitConversions.convert(loop_sizing.designLoopExitTemperature, 'C', 'F') - 10.0 - 95.0, 'deltaF', 'deltaC') * 3.0 # W/K
    max_water_flow = UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W') / UnitConversions.convert(20.0, 'deltaF', 'deltaC') / 4.186 / 998.2 / 1000.0 * 2.0 # m^3/s
    fan_cfm = 400.0 * UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'ton') # CFM; assumes 400 cfm/ton

    if heating_system.distribution_system.air_type.to_s == HPXML::AirTypeFanCoil
      # Fan
      fan = create_supply_fan(model, obj_name, 0.0, [fan_cfm]) # fan energy included in above pump via Electric Auxiliary Energy (EAE)

      # Heating Coil
      htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
      htg_coil.setRatedCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
      htg_coil.setUFactorTimesAreaValue(bb_ua)
      htg_coil.setMaximumWaterFlowRate(max_water_flow)
      htg_coil.setPerformanceInputMethod('NominalCapacity')
      htg_coil.setName(obj_name + ' htg coil')
      plant_loop.addDemandBranchForComponent(htg_coil)

      # Cooling Coil (always off)
      clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOffDiscreteSchedule)
      clg_coil.setName(obj_name + ' clg coil')
      clg_coil.setDesignWaterFlowRate(0.0022)
      clg_coil.setDesignAirFlowRate(1.45)
      clg_coil.setDesignInletWaterTemperature(6.1)
      clg_coil.setDesignInletAirTemperature(25.0)
      clg_coil.setDesignOutletAirTemperature(10.0)
      clg_coil.setDesignInletAirHumidityRatio(0.012)
      clg_coil.setDesignOutletAirHumidityRatio(0.008)
      plant_loop.addDemandBranchForComponent(clg_coil)

      # Fan Coil
      zone_hvac = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model, model.alwaysOnDiscreteSchedule, fan, clg_coil, htg_coil)
      zone_hvac.setCapacityControlMethod('CyclingFan')
      zone_hvac.setName(obj_name + ' fan coil')
      zone_hvac.setMaximumSupplyAirTemperatureInHeatingMode(UnitConversions.convert(120.0, 'F', 'C'))
      zone_hvac.setHeatingConvergenceTolerance(0.001)
      zone_hvac.setMinimumSupplyAirTemperatureInCoolingMode(UnitConversions.convert(55.0, 'F', 'C'))
      zone_hvac.setMaximumColdWaterFlowRate(0.0)
      zone_hvac.setCoolingConvergenceTolerance(0.001)
      zone_hvac.setMaximumOutdoorAirFlowRate(0.0)
      zone_hvac.setMaximumSupplyAirFlowRate(UnitConversions.convert(fan_cfm, 'cfm', 'm^3/s'))
      zone_hvac.setMaximumHotWaterFlowRate(max_water_flow)
      zone_hvac.addToThermalZone(control_zone)
      disaggregate_fan_or_pump(model, pump, zone_hvac, nil, nil, heating_system)
    else
      # Heating Coil
      htg_coil = OpenStudio::Model::CoilHeatingWaterBaseboard.new(model)
      htg_coil.setName(obj_name + ' htg coil')
      htg_coil.setConvergenceTolerance(0.001)
      htg_coil.setHeatingDesignCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
      htg_coil.setUFactorTimesAreaValue(bb_ua)
      htg_coil.setMaximumWaterFlowRate(max_water_flow)
      htg_coil.setHeatingDesignCapacityMethod('HeatingDesignCapacity')
      plant_loop.addDemandBranchForComponent(htg_coil)

      # Baseboard
      zone_hvac = OpenStudio::Model::ZoneHVACBaseboardConvectiveWater.new(model, model.alwaysOnDiscreteSchedule, htg_coil)
      zone_hvac.setName(obj_name + ' baseboard')
      zone_hvac.addToThermalZone(control_zone)
      zone_hvac.additionalProperties.setFeature('IsHeatPumpBackup', heating_system.is_heat_pump_backup_system) # Used by reporting measure
      if heating_system.is_heat_pump_backup_system
        disaggregate_fan_or_pump(model, pump, nil, nil, zone_hvac, heating_system)
      else
        disaggregate_fan_or_pump(model, pump, zone_hvac, nil, nil, heating_system)
      end
    end

    set_sequential_load_fractions(model, control_zone, zone_hvac, sequential_heat_load_fracs, nil, hvac_unavailable_periods, heating_system)

    return zone_hvac
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param heating_system [TODO] TODO
  # @param sequential_heat_load_fracs [TODO] TODO
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param hvac_unavailable_periods [TODO] TODO
  # @return [TODO] TODO
  def self.apply_electric_baseboard(model, heating_system,
                                    sequential_heat_load_fracs, control_zone, hvac_unavailable_periods)

    obj_name = Constants.ObjectNameElectricBaseboard

    # Baseboard
    zone_hvac = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
    zone_hvac.setName(obj_name)
    zone_hvac.setEfficiency(heating_system.heating_efficiency_percent)
    zone_hvac.setNominalCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
    zone_hvac.addToThermalZone(control_zone)
    zone_hvac.additionalProperties.setFeature('HPXML_ID', heating_system.id) # Used by reporting measure
    zone_hvac.additionalProperties.setFeature('IsHeatPumpBackup', heating_system.is_heat_pump_backup_system) # Used by reporting measure

    set_sequential_load_fractions(model, control_zone, zone_hvac, sequential_heat_load_fracs, nil, hvac_unavailable_periods, heating_system)
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param heating_system [TODO] TODO
  # @param sequential_heat_load_fracs [TODO] TODO
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param hvac_unavailable_periods [TODO] TODO
  # @return [TODO] TODO
  def self.apply_unit_heater(model, heating_system,
                             sequential_heat_load_fracs, control_zone, hvac_unavailable_periods)

    obj_name = Constants.ObjectNameUnitHeater

    # Heating Coil
    efficiency = heating_system.heating_efficiency_afue
    efficiency = heating_system.heating_efficiency_percent if efficiency.nil?
    if heating_system.heating_system_fuel == HPXML::FuelTypeElectricity
      htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model)
      htg_coil.setEfficiency(efficiency)
    else
      htg_coil = OpenStudio::Model::CoilHeatingGas.new(model)
      htg_coil.setGasBurnerEfficiency(efficiency)
      htg_coil.setOnCycleParasiticElectricLoad(0.0)
      htg_coil.setOffCycleParasiticGasLoad(UnitConversions.convert(heating_system.pilot_light_btuh.to_f, 'Btu/hr', 'W'))
      htg_coil.setFuelType(EPlus.fuel_type(heating_system.heating_system_fuel))
    end
    htg_coil.setNominalCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
    htg_coil.setName(obj_name + ' htg coil')
    htg_coil.additionalProperties.setFeature('HPXML_ID', heating_system.id) # Used by reporting measure
    htg_coil.additionalProperties.setFeature('IsHeatPumpBackup', heating_system.is_heat_pump_backup_system) # Used by reporting measure

    # Fan
    htg_cfm = heating_system.heating_airflow_cfm
    fan_watts_per_cfm = heating_system.fan_watts / htg_cfm
    fan = create_supply_fan(model, obj_name, fan_watts_per_cfm, [htg_cfm])
    disaggregate_fan_or_pump(model, fan, htg_coil, nil, nil, heating_system)

    # Unitary System
    unitary_system = create_air_loop_unitary_system(model, obj_name, fan, htg_coil, nil, nil, htg_cfm, nil)
    unitary_system.setControllingZoneorThermostatLocation(control_zone)
    unitary_system.addToThermalZone(control_zone)

    set_sequential_load_fractions(model, control_zone, unitary_system, sequential_heat_load_fracs, nil, hvac_unavailable_periods, heating_system)
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param sequential_cool_load_fracs [TODO] TODO
  # @param sequential_heat_load_fracs [TODO] TODO
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param hvac_unavailable_periods [TODO] TODO
  # @return [TODO] TODO
  def self.apply_ideal_air_loads(model, sequential_cool_load_fracs,
                                 sequential_heat_load_fracs, control_zone, hvac_unavailable_periods)

    obj_name = Constants.ObjectNameIdealAirSystem

    # Ideal Air System
    ideal_air = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
    ideal_air.setName(obj_name)
    ideal_air.setMaximumHeatingSupplyAirTemperature(50)
    ideal_air.setMinimumCoolingSupplyAirTemperature(10)
    ideal_air.setMaximumHeatingSupplyAirHumidityRatio(0.015)
    ideal_air.setMinimumCoolingSupplyAirHumidityRatio(0.01)
    if sequential_heat_load_fracs.sum > 0
      ideal_air.setHeatingLimit('NoLimit')
    else
      ideal_air.setHeatingLimit('LimitCapacity')
      ideal_air.setMaximumSensibleHeatingCapacity(0)
    end
    if sequential_cool_load_fracs.sum > 0
      ideal_air.setCoolingLimit('NoLimit')
    else
      ideal_air.setCoolingLimit('LimitCapacity')
      ideal_air.setMaximumTotalCoolingCapacity(0)
    end
    ideal_air.setDehumidificationControlType('None')
    ideal_air.setHumidificationControlType('None')
    ideal_air.addToThermalZone(control_zone)

    set_sequential_load_fractions(model, control_zone, ideal_air, sequential_heat_load_fracs, sequential_cool_load_fracs, hvac_unavailable_periods)
  end

  # TODO
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param dehumidifiers [TODO] TODO
  # @param conditioned_space [TODO] TODO
  # @param unavailable_periods [HPXML::UnavailablePeriods] Object that defines periods for, e.g., power outages or vacancies
  # @param unit_multiplier [Integer] Number of similar dwelling units
  # @return [TODO] TODO
  def self.apply_dehumidifiers(runner, model, dehumidifiers, conditioned_space, unavailable_periods, unit_multiplier)
    dehumidifier_id = dehumidifiers[0].id # Syncs with the ReportSimulationOutput measure, which only looks at first dehumidifier ID

    if dehumidifiers.map { |d| d.rh_setpoint }.uniq.size > 1
      fail 'All dehumidifiers must have the same setpoint but multiple setpoints were specified.'
    end

    if unit_multiplier > 1
      # FUTURE: Figure out how to allow this. If we allow it, update docs and hpxml_translator_test.rb too.
      # https://github.com/NREL/OpenStudio-HPXML/issues/1499
      fail 'NumberofUnits greater than 1 is not supported for dehumidifiers.'
    end

    # Dehumidifier coefficients
    # Generic model coefficients from Winkler, Christensen, and Tomerlin (2011)
    w_coeff = [-1.162525707, 0.02271469, -0.000113208, 0.021110538, -0.0000693034, 0.000378843]
    ef_coeff = [-1.902154518, 0.063466565, -0.000622839, 0.039540407, -0.000125637, -0.000176722]
    pl_coeff = [0.90, 0.10, 0.0]

    dehumidifiers.each do |d|
      next unless d.energy_factor.nil?

      # shift inputs tested under IEF test conditions to those under EF test conditions with performance curves
      d.energy_factor, d.capacity = apply_dehumidifier_ief_to_ef_inputs(d.type, w_coeff, ef_coeff, d.integrated_energy_factor, d.capacity)
    end

    # Combine HPXML dehumidifiers into a single EnergyPlus dehumidifier
    total_capacity = dehumidifiers.map { |d| d.capacity }.sum
    avg_energy_factor = dehumidifiers.map { |d| d.energy_factor * d.capacity }.sum / total_capacity
    total_fraction_served = dehumidifiers.map { |d| d.fraction_served }.sum

    # Apply unit multiplier
    total_capacity *= unit_multiplier

    control_zone = conditioned_space.thermalZone.get
    obj_name = Constants.ObjectNameDehumidifier

    rh_setpoint = dehumidifiers[0].rh_setpoint * 100.0 # (EnergyPlus uses 60 for 60% RH)
    relative_humidity_setpoint_sch = OpenStudio::Model::ScheduleConstant.new(model)
    relative_humidity_setpoint_sch.setName("#{obj_name} rh setpoint")
    relative_humidity_setpoint_sch.setValue(rh_setpoint)

    capacity_curve = create_curve_biquadratic(model, w_coeff, 'DXDH-CAP-fT', -100, 100, -100, 100)
    energy_factor_curve = create_curve_biquadratic(model, ef_coeff, 'DXDH-EF-fT', -100, 100, -100, 100)
    part_load_frac_curve = create_curve_quadratic(model, pl_coeff, 'DXDH-PLF-fPLR', 0, 1, 0.7, 1)

    # Calculate air flow rate by assuming 2.75 cfm/pint/day (based on experimental test data)
    air_flow_rate = 2.75 * total_capacity

    # Humidity Setpoint
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
    humidistat.setName(obj_name + ' humidistat')
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(relative_humidity_setpoint_sch)
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(relative_humidity_setpoint_sch)
    control_zone.setZoneControlHumidistat(humidistat)

    # Availability Schedule
    dehum_unavailable_periods = Schedule.get_unavailable_periods(runner, SchedulesFile::Columns[:Dehumidifier].name, unavailable_periods)
    avail_sch = ScheduleConstant.new(model, obj_name + ' schedule', 1.0, Constants.ScheduleTypeLimitsFraction, unavailable_periods: dehum_unavailable_periods)
    avail_sch = avail_sch.schedule

    # Dehumidifier
    zone_hvac = OpenStudio::Model::ZoneHVACDehumidifierDX.new(model, capacity_curve, energy_factor_curve, part_load_frac_curve)
    zone_hvac.setName(obj_name)
    zone_hvac.setAvailabilitySchedule(avail_sch)
    zone_hvac.setRatedWaterRemoval(UnitConversions.convert(total_capacity, 'pint', 'L'))
    zone_hvac.setRatedEnergyFactor(avg_energy_factor / total_fraction_served)
    zone_hvac.setRatedAirFlowRate(UnitConversions.convert(air_flow_rate, 'cfm', 'm^3/s'))
    zone_hvac.setMinimumDryBulbTemperatureforDehumidifierOperation(10)
    zone_hvac.setMaximumDryBulbTemperatureforDehumidifierOperation(40)
    zone_hvac.addToThermalZone(control_zone)
    zone_hvac.additionalProperties.setFeature('HPXML_ID', dehumidifier_id) # Used by reporting measure

    if total_fraction_served < 1.0
      adjust_dehumidifier_load_EMS(total_fraction_served, zone_hvac, model, conditioned_space)
    end
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param weather [WeatherFile] Weather object containing EPW information
  # @param ceiling_fan [TODO] TODO
  # @param conditioned_space [TODO] TODO
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @param unavailable_periods [HPXML::UnavailablePeriods] Object that defines periods for, e.g., power outages or vacancies
  # @return [TODO] TODO
  def self.apply_ceiling_fans(model, runner, weather, ceiling_fan, conditioned_space, schedules_file,
                              unavailable_periods)
    obj_name = Constants.ObjectNameCeilingFan
    hrs_per_day = 10.5 # From ANSI 301-2019
    cfm_per_w = ceiling_fan.efficiency
    label_energy_use = ceiling_fan.label_energy_use
    count = ceiling_fan.count
    if !label_energy_use.nil? # priority if both provided
      annual_kwh = UnitConversions.convert(count * label_energy_use * hrs_per_day * 365.0, 'Wh', 'kWh')
    elsif !cfm_per_w.nil?
      medium_cfm = get_default_ceiling_fan_medium_cfm()
      annual_kwh = UnitConversions.convert(count * medium_cfm / cfm_per_w * hrs_per_day * 365.0, 'Wh', 'kWh')
    end

    # Create schedule
    ceiling_fan_sch = nil
    ceiling_fan_col_name = SchedulesFile::Columns[:CeilingFan].name
    if not schedules_file.nil?
      annual_kwh *= Schedule.CeilingFanMonthlyMultipliers(weather: weather).split(',').map(&:to_f).sum(0.0) / 12.0
      ceiling_fan_design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: ceiling_fan_col_name, annual_kwh: annual_kwh)
      ceiling_fan_sch = schedules_file.create_schedule_file(model, col_name: ceiling_fan_col_name)
    end
    if ceiling_fan_sch.nil?
      ceiling_fan_unavailable_periods = Schedule.get_unavailable_periods(runner, ceiling_fan_col_name, unavailable_periods)
      annual_kwh *= ceiling_fan.monthly_multipliers.split(',').map(&:to_f).sum(0.0) / 12.0
      weekday_sch = ceiling_fan.weekday_fractions
      weekend_sch = ceiling_fan.weekend_fractions
      monthly_sch = ceiling_fan.monthly_multipliers
      ceiling_fan_sch_obj = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', weekday_sch, weekend_sch, monthly_sch, Constants.ScheduleTypeLimitsFraction, unavailable_periods: ceiling_fan_unavailable_periods)
      ceiling_fan_design_level = ceiling_fan_sch_obj.calc_design_level_from_daily_kwh(annual_kwh / 365.0)
      ceiling_fan_sch = ceiling_fan_sch_obj.schedule
    else
      runner.registerWarning("Both '#{ceiling_fan_col_name}' schedule file and weekday fractions provided; the latter will be ignored.") if !ceiling_fan.weekday_fractions.nil?
      runner.registerWarning("Both '#{ceiling_fan_col_name}' schedule file and weekend fractions provided; the latter will be ignored.") if !ceiling_fan.weekend_fractions.nil?
      runner.registerWarning("Both '#{ceiling_fan_col_name}' schedule file and monthly multipliers provided; the latter will be ignored.") if !ceiling_fan.monthly_multipliers.nil?
    end

    equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    equip_def.setName(obj_name)
    equip = OpenStudio::Model::ElectricEquipment.new(equip_def)
    equip.setName(equip_def.name.to_s)
    equip.setSpace(conditioned_space)
    equip_def.setDesignLevel(ceiling_fan_design_level)
    equip_def.setFractionRadiant(0.558)
    equip_def.setFractionLatent(0)
    equip_def.setFractionLost(0)
    equip.setEndUseSubcategory(obj_name)
    equip.setSchedule(ceiling_fan_sch)
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param weather [WeatherFile] Weather object containing EPW information
  # @param hvac_control [TODO] TODO
  # @param conditioned_zone [TODO] TODO
  # @param has_ceiling_fan [TODO] TODO
  # @param heating_days [TODO] TODO
  # @param cooling_days [TODO] TODO
  # @param hpxml_header [HPXML::Header] HPXML Header object (one per HPXML file)
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @return [TODO] TODO
  def self.apply_setpoints(model, runner, weather, hvac_control, conditioned_zone, has_ceiling_fan, heating_days, cooling_days, hpxml_header, schedules_file)
    heating_sch = nil
    cooling_sch = nil
    year = hpxml_header.sim_calendar_year
    onoff_thermostat_ddb = hpxml_header.hvac_onoff_thermostat_deadband.to_f
    if not schedules_file.nil?
      heating_sch = schedules_file.create_schedule_file(model, col_name: SchedulesFile::Columns[:HeatingSetpoint].name)
    end
    if not schedules_file.nil?
      cooling_sch = schedules_file.create_schedule_file(model, col_name: SchedulesFile::Columns[:CoolingSetpoint].name)
    end

    # permit mixing detailed schedules with simple schedules
    if heating_sch.nil?
      htg_weekday_setpoints, htg_weekend_setpoints = get_heating_setpoints(hvac_control, year, onoff_thermostat_ddb)
    else
      runner.registerWarning("Both '#{SchedulesFile::Columns[:HeatingSetpoint].name}' schedule file and heating setpoint temperature provided; the latter will be ignored.") if !hvac_control.heating_setpoint_temp.nil?
    end

    if cooling_sch.nil?
      clg_weekday_setpoints, clg_weekend_setpoints = get_cooling_setpoints(hvac_control, has_ceiling_fan, year, weather, onoff_thermostat_ddb)
    else
      runner.registerWarning("Both '#{SchedulesFile::Columns[:CoolingSetpoint].name}' schedule file and cooling setpoint temperature provided; the latter will be ignored.") if !hvac_control.cooling_setpoint_temp.nil?
    end

    # only deal with deadband issue if both schedules are simple
    if heating_sch.nil? && cooling_sch.nil?
      htg_weekday_setpoints, htg_weekend_setpoints, clg_weekday_setpoints, clg_weekend_setpoints = create_setpoint_schedules(runner, heating_days, cooling_days, htg_weekday_setpoints, htg_weekend_setpoints, clg_weekday_setpoints, clg_weekend_setpoints, year)
    end

    if heating_sch.nil?
      heating_setpoint = HourlyByDaySchedule.new(model, 'heating setpoint', htg_weekday_setpoints, htg_weekend_setpoints, nil, false)
      heating_sch = heating_setpoint.schedule
    end

    if cooling_sch.nil?
      cooling_setpoint = HourlyByDaySchedule.new(model, 'cooling setpoint', clg_weekday_setpoints, clg_weekend_setpoints, nil, false)
      cooling_sch = cooling_setpoint.schedule
    end

    # Set the setpoint schedules
    thermostat_setpoint = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
    thermostat_setpoint.setName("#{conditioned_zone.name} temperature setpoint")
    thermostat_setpoint.setHeatingSetpointTemperatureSchedule(heating_sch)
    thermostat_setpoint.setCoolingSetpointTemperatureSchedule(cooling_sch)
    thermostat_setpoint.setTemperatureDifferenceBetweenCutoutAndSetpoint(UnitConversions.convert(onoff_thermostat_ddb, 'deltaF', 'deltaC'))
    conditioned_zone.setThermostatSetpointDualSetpoint(thermostat_setpoint)
  end

  # TODO
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param heating_days [TODO] TODO
  # @param cooling_days [TODO] TODO
  # @param htg_weekday_setpoints [TODO] TODO
  # @param htg_weekend_setpoints [TODO] TODO
  # @param clg_weekday_setpoints [TODO] TODO
  # @param clg_weekend_setpoints [TODO] TODO
  # @param year [Integer] the calendar year
  # @return [TODO] TODO
  def self.create_setpoint_schedules(runner, heating_days, cooling_days, htg_weekday_setpoints, htg_weekend_setpoints, clg_weekday_setpoints, clg_weekend_setpoints, year)
    # Create setpoint schedules
    # This method ensures that we don't construct a setpoint schedule where the cooling setpoint
    # is less than the heating setpoint, which would result in an E+ error.

    # Note: It's tempting to adjust the setpoints, e.g., outside of the heating/cooling seasons,
    # to prevent unmet hours being reported. This is a dangerous idea. These setpoints are used
    # by natural ventilation, Kiva initialization, and probably other things.

    warning = false
    for i in 0..(Constants.NumDaysInYear(year) - 1)
      if (heating_days[i] == cooling_days[i]) # both (or neither) heating/cooling seasons
        htg_wkdy = htg_weekday_setpoints[i].zip(clg_weekday_setpoints[i]).map { |h, c| c < h ? (h + c) / 2.0 : h }
        htg_wked = htg_weekend_setpoints[i].zip(clg_weekend_setpoints[i]).map { |h, c| c < h ? (h + c) / 2.0 : h }
        clg_wkdy = htg_weekday_setpoints[i].zip(clg_weekday_setpoints[i]).map { |h, c| c < h ? (h + c) / 2.0 : c }
        clg_wked = htg_weekend_setpoints[i].zip(clg_weekend_setpoints[i]).map { |h, c| c < h ? (h + c) / 2.0 : c }
      elsif heating_days[i] == 1 # heating only seasons; cooling has minimum of heating
        htg_wkdy = htg_weekday_setpoints[i]
        htg_wked = htg_weekend_setpoints[i]
        clg_wkdy = htg_weekday_setpoints[i].zip(clg_weekday_setpoints[i]).map { |h, c| c < h ? h : c }
        clg_wked = htg_weekend_setpoints[i].zip(clg_weekend_setpoints[i]).map { |h, c| c < h ? h : c }
      elsif cooling_days[i] == 1 # cooling only seasons; heating has maximum of cooling
        htg_wkdy = clg_weekday_setpoints[i].zip(htg_weekday_setpoints[i]).map { |c, h| c < h ? c : h }
        htg_wked = clg_weekend_setpoints[i].zip(htg_weekend_setpoints[i]).map { |c, h| c < h ? c : h }
        clg_wkdy = clg_weekday_setpoints[i]
        clg_wked = clg_weekend_setpoints[i]
      else
        fail 'HeatingSeason and CoolingSeason, when combined, must span the entire year.'
      end
      if (htg_wkdy != htg_weekday_setpoints[i]) || (htg_wked != htg_weekend_setpoints[i]) || (clg_wkdy != clg_weekday_setpoints[i]) || (clg_wked != clg_weekend_setpoints[i])
        warning = true
      end
      htg_weekday_setpoints[i] = htg_wkdy
      htg_weekend_setpoints[i] = htg_wked
      clg_weekday_setpoints[i] = clg_wkdy
      clg_weekend_setpoints[i] = clg_wked
    end

    if warning
      runner.registerWarning('HVAC setpoints have been automatically adjusted to prevent periods where the heating setpoint is greater than the cooling setpoint.')
    end

    return htg_weekday_setpoints, htg_weekend_setpoints, clg_weekday_setpoints, clg_weekend_setpoints
  end

  # TODO
  #
  # @param hvac_control [TODO] TODO
  # @param year [Integer] the calendar year
  # @param offset_db [Float] On-off thermostat deadband (F)
  # @return [TODO] TODO
  def self.get_heating_setpoints(hvac_control, year, offset_db)
    num_days = Constants.NumDaysInYear(year)

    if hvac_control.weekday_heating_setpoints.nil? || hvac_control.weekend_heating_setpoints.nil?
      # Base heating setpoint
      htg_setpoint = hvac_control.heating_setpoint_temp
      htg_weekday_setpoints = [[htg_setpoint] * 24] * num_days
      # Apply heating setback?
      htg_setback = hvac_control.heating_setback_temp
      if not htg_setback.nil?
        htg_setback_hrs_per_week = hvac_control.heating_setback_hours_per_week
        htg_setback_start_hr = hvac_control.heating_setback_start_hour
        for d in 1..num_days
          for hr in htg_setback_start_hr..htg_setback_start_hr + Integer(htg_setback_hrs_per_week / 7.0) - 1
            htg_weekday_setpoints[d - 1][hr % 24] = htg_setback
          end
        end
      end
      htg_weekend_setpoints = htg_weekday_setpoints.dup
    else
      # 24-hr weekday/weekend heating setpoint schedules
      htg_weekday_setpoints = hvac_control.weekday_heating_setpoints.split(',').map { |i| Float(i) }
      htg_weekday_setpoints = [htg_weekday_setpoints] * num_days
      htg_weekend_setpoints = hvac_control.weekend_heating_setpoints.split(',').map { |i| Float(i) }
      htg_weekend_setpoints = [htg_weekend_setpoints] * num_days
    end
    # Apply thermostat offset due to onoff control
    htg_weekday_setpoints = htg_weekday_setpoints.map { |i| i.map { |j| j - offset_db / 2.0 } }
    htg_weekend_setpoints = htg_weekend_setpoints.map { |i| i.map { |j| j - offset_db / 2.0 } }

    htg_weekday_setpoints = htg_weekday_setpoints.map { |i| i.map { |j| UnitConversions.convert(j, 'F', 'C') } }
    htg_weekend_setpoints = htg_weekend_setpoints.map { |i| i.map { |j| UnitConversions.convert(j, 'F', 'C') } }

    return htg_weekday_setpoints, htg_weekend_setpoints
  end

  # TODO
  #
  # @param hvac_control [TODO] TODO
  # @param has_ceiling_fan [TODO] TODO
  # @param year [Integer] the calendar year
  # @param weather [WeatherFile] Weather object containing EPW information
  # @param offset_db [Float] On-off thermostat deadband (F)
  # @return [TODO] TODO
  def self.get_cooling_setpoints(hvac_control, has_ceiling_fan, year, weather, offset_db)
    num_days = Constants.NumDaysInYear(year)

    if hvac_control.weekday_cooling_setpoints.nil? || hvac_control.weekend_cooling_setpoints.nil?
      # Base cooling setpoint
      clg_setpoint = hvac_control.cooling_setpoint_temp
      clg_weekday_setpoints = [[clg_setpoint] * 24] * num_days
      # Apply cooling setup?
      clg_setup = hvac_control.cooling_setup_temp
      if not clg_setup.nil?
        clg_setup_hrs_per_week = hvac_control.cooling_setup_hours_per_week
        clg_setup_start_hr = hvac_control.cooling_setup_start_hour
        for d in 1..num_days
          for hr in clg_setup_start_hr..clg_setup_start_hr + Integer(clg_setup_hrs_per_week / 7.0) - 1
            clg_weekday_setpoints[d - 1][hr % 24] = clg_setup
          end
        end
      end
      clg_weekend_setpoints = clg_weekday_setpoints.dup
    else
      # 24-hr weekday/weekend cooling setpoint schedules
      clg_weekday_setpoints = hvac_control.weekday_cooling_setpoints.split(',').map { |i| Float(i) }
      clg_weekday_setpoints = [clg_weekday_setpoints] * num_days
      clg_weekend_setpoints = hvac_control.weekend_cooling_setpoints.split(',').map { |i| Float(i) }
      clg_weekend_setpoints = [clg_weekend_setpoints] * num_days
    end
    # Apply cooling setpoint offset due to ceiling fan?
    if has_ceiling_fan
      clg_ceiling_fan_offset = hvac_control.ceiling_fan_cooling_setpoint_temp_offset
      if not clg_ceiling_fan_offset.nil?
        months = get_default_ceiling_fan_months(weather)
        Schedule.months_to_days(year, months).each_with_index do |operation, d|
          next if operation != 1

          clg_weekday_setpoints[d] = [clg_weekday_setpoints[d], Array.new(24, clg_ceiling_fan_offset)].transpose.map { |i| i.reduce(:+) }
          clg_weekend_setpoints[d] = [clg_weekend_setpoints[d], Array.new(24, clg_ceiling_fan_offset)].transpose.map { |i| i.reduce(:+) }
        end
      end
    end

    # Apply thermostat offset due to onoff control
    clg_weekday_setpoints = clg_weekday_setpoints.map { |i| i.map { |j| j + offset_db / 2.0 } }
    clg_weekend_setpoints = clg_weekend_setpoints.map { |i| i.map { |j| j + offset_db / 2.0 } }
    clg_weekday_setpoints = clg_weekday_setpoints.map { |i| i.map { |j| UnitConversions.convert(j, 'F', 'C') } }
    clg_weekend_setpoints = clg_weekend_setpoints.map { |i| i.map { |j| UnitConversions.convert(j, 'F', 'C') } }

    return clg_weekday_setpoints, clg_weekend_setpoints
  end

  # TODO
  #
  # @param control_type [TODO] TODO
  # @param eri_version [String] Version of the ANSI/RESNET/ICC 301 Standard to use for equations/assumptions
  # @return [TODO] TODO
  def self.get_default_heating_setpoint(control_type, eri_version)
    # Per ANSI/RESNET/ICC 301
    htg_weekday_setpoints = '68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68'
    htg_weekend_setpoints = '68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68'
    if control_type == HPXML::HVACControlTypeProgrammable
      if Constants.ERIVersions.index(eri_version) >= Constants.ERIVersions.index('2022')
        htg_weekday_setpoints = '66, 66, 66, 66, 66, 67, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 66'
        htg_weekend_setpoints = '66, 66, 66, 66, 66, 67, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 66'
      else
        htg_weekday_setpoints = '66, 66, 66, 66, 66, 66, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 66'
        htg_weekend_setpoints = '66, 66, 66, 66, 66, 66, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 66'
      end
    elsif control_type != HPXML::HVACControlTypeManual
      fail "Unexpected control type #{control_type}."
    end
    return htg_weekday_setpoints, htg_weekend_setpoints
  end

  # TODO
  #
  # @param control_type [TODO] TODO
  # @param eri_version [String] Version of the ANSI/RESNET/ICC 301 Standard to use for equations/assumptions
  # @return [TODO] TODO
  def self.get_default_cooling_setpoint(control_type, eri_version)
    # Per ANSI/RESNET/ICC 301
    clg_weekday_setpoints = '78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78'
    clg_weekend_setpoints = '78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78'
    if control_type == HPXML::HVACControlTypeProgrammable
      if Constants.ERIVersions.index(eri_version) >= Constants.ERIVersions.index('2022')
        clg_weekday_setpoints = '78, 78, 78, 78, 78, 78, 78, 78, 78, 80, 80, 80, 80, 80, 79, 78, 78, 78, 78, 78, 78, 78, 78, 78'
        clg_weekend_setpoints = '78, 78, 78, 78, 78, 78, 78, 78, 78, 80, 80, 80, 80, 80, 79, 78, 78, 78, 78, 78, 78, 78, 78, 78'
      else
        clg_weekday_setpoints = '78, 78, 78, 78, 78, 78, 78, 78, 78, 80, 80, 80, 80, 80, 80, 78, 78, 78, 78, 78, 78, 78, 78, 78'
        clg_weekend_setpoints = '78, 78, 78, 78, 78, 78, 78, 78, 78, 80, 80, 80, 80, 80, 80, 78, 78, 78, 78, 78, 78, 78, 78, 78'
      end
    elsif control_type != HPXML::HVACControlTypeManual
      fail "Unexpected control type #{control_type}."
    end
    return clg_weekday_setpoints, clg_weekend_setpoints
  end

  # TODO
  #
  # @param compressor_type [TODO] TODO
  # @param hspf [TODO] TODO
  # @return [TODO] TODO
  def self.get_default_heating_capacity_retention(compressor_type, hspf = nil)
    retention_temp = 5.0
    if [HPXML::HVACCompressorTypeSingleStage, HPXML::HVACCompressorTypeTwoStage].include? compressor_type
      retention_fraction = 0.425
    elsif [HPXML::HVACCompressorTypeVariableSpeed].include? compressor_type
      # Default maximum capacity maintenance based on NEEP data for all var speed heat pump types, if not provided
      retention_fraction = (0.0461 * hspf + 0.1594).round(4)
    end
    return retention_temp, retention_fraction
  end

  # TODO
  #
  # @param compressor_type [TODO] TODO
  # @return [TODO] TODO
  def self.get_cool_cap_eir_ft_spec(compressor_type)
    if compressor_type == HPXML::HVACCompressorTypeSingleStage
      cap_ft_spec = [[3.68637657, -0.098352478, 0.000956357, 0.005838141, -0.0000127, -0.000131702]]
      eir_ft_spec = [[-3.437356399, 0.136656369, -0.001049231, -0.0079378, 0.000185435, -0.0001441]]
    elsif compressor_type == HPXML::HVACCompressorTypeTwoStage
      cap_ft_spec = [[3.998418659, -0.108728222, 0.001056818, 0.007512314, -0.0000139, -0.000164716],
                     [3.466810106, -0.091476056, 0.000901205, 0.004163355, -0.00000919, -0.000110829]]
      eir_ft_spec = [[-4.282911381, 0.181023691, -0.001357391, -0.026310378, 0.000333282, -0.000197405],
                     [-3.557757517, 0.112737397, -0.000731381, 0.013184877, 0.000132645, -0.000338716]]
    end
    return cap_ft_spec, eir_ft_spec
  end

  # TODO
  #
  # @param compressor_type [TODO] TODO
  # @return [TODO] TODO
  def self.get_cool_cap_eir_fflow_spec(compressor_type)
    if compressor_type == HPXML::HVACCompressorTypeSingleStage
      # Single stage systems have PSC or constant torque ECM blowers, so the airflow rate is affected by the static pressure losses.
      cap_fflow_spec = [[0.718664047, 0.41797409, -0.136638137]]
      eir_fflow_spec = [[1.143487507, -0.13943972, -0.004047787]]
    elsif compressor_type == HPXML::HVACCompressorTypeTwoStage
      # Most two stage systems have PSC or constant torque ECM blowers, so the airflow rate is affected by the static pressure losses.
      cap_fflow_spec = [[0.655239515, 0.511655216, -0.166894731],
                        [0.618281092, 0.569060264, -0.187341356]]
      eir_fflow_spec = [[1.639108268, -0.998953996, 0.359845728],
                        [1.570774717, -0.914152018, 0.343377302]]
    elsif compressor_type == HPXML::HVACCompressorTypeVariableSpeed
      # Variable speed systems have constant flow ECM blowers, so the air handler can always achieve the design airflow rate by sacrificing blower power.
      # So we assume that there is only one corresponding airflow rate for each compressor speed.
      eir_fflow_spec = [[1, 0, 0]] * 2
      cap_fflow_spec = [[1, 0, 0]] * 2
    end
    return cap_fflow_spec, eir_fflow_spec
  end

  # TODO
  #
  # @param compressor_type [TODO] TODO
  # @param heating_capacity_retention_temp [TODO] TODO
  # @param heating_capacity_retention_fraction [TODO] TODO
  # @return [TODO] TODO
  def self.get_heat_cap_eir_ft_spec(compressor_type, heating_capacity_retention_temp, heating_capacity_retention_fraction)
    cap_ft_spec = calc_heat_cap_ft_spec(compressor_type, heating_capacity_retention_temp, heating_capacity_retention_fraction)
    if compressor_type == HPXML::HVACCompressorTypeSingleStage
      # From "Improved Modeling of Residential Air Conditioners and Heat Pumps for Energy Calculations", Cutler et al
      # https://www.nrel.gov/docs/fy13osti/56354.pdf
      eir_ft_spec = [[0.718398423, 0.003498178, 0.000142202, -0.005724331, 0.00014085, -0.000215321]]
    elsif compressor_type == HPXML::HVACCompressorTypeTwoStage
      # From "Improved Modeling of Residential Air Conditioners and Heat Pumps for Energy Calculations", Cutler et al
      # https://www.nrel.gov/docs/fy13osti/56354.pdf
      eir_ft_spec = [[0.36338171, 0.013523725, 0.000258872, -0.009450269, 0.000439519, -0.000653723],
                     [0.981100941, -0.005158493, 0.000243416, -0.005274352, 0.000230742, -0.000336954]]
    end
    return cap_ft_spec, eir_ft_spec
  end

  # TODO
  #
  # @param compressor_type [TODO] TODO
  # @return [TODO] TODO
  def self.get_heat_cap_eir_fflow_spec(compressor_type)
    if compressor_type == HPXML::HVACCompressorTypeSingleStage
      # Single stage systems have PSC or constant torque ECM blowers, so the airflow rate is affected by the static pressure losses.
      cap_fflow_spec = [[0.694045465, 0.474207981, -0.168253446]]
      eir_fflow_spec = [[2.185418751, -1.942827919, 0.757409168]]
    elsif compressor_type == HPXML::HVACCompressorTypeTwoStage
      # Most two stage systems have PSC or constant torque ECM blowers, so the airflow rate is affected by the static pressure losses.
      cap_fflow_spec = [[0.741466907, 0.378645444, -0.119754733],
                        [0.76634609, 0.32840943, -0.094701495]]
      eir_fflow_spec = [[2.153618211, -1.737190609, 0.584269478],
                        [2.001041353, -1.58869128, 0.587593517]]
    elsif compressor_type == HPXML::HVACCompressorTypeVariableSpeed
      # Variable speed systems have constant flow ECM blowers, so the air handler can always achieve the design airflow rate by sacrificing blower power.
      # So we assume that there is only one corresponding airflow rate for each compressor speed.
      cap_fflow_spec = [[1, 0, 0]] * 3
      eir_fflow_spec = [[1, 0, 0]] * 3
    end
    return cap_fflow_spec, eir_fflow_spec
  end

  # TODO
  #
  # @param cooling_system [TODO] TODO
  # @param use_eer [TODO] TODO
  # @return [TODO] TODO
  def self.set_cool_curves_central_air_source(cooling_system, use_eer = false)
    clg_ap = cooling_system.additional_properties
    clg_ap.cool_rated_cfm_per_ton = get_default_cool_cfm_per_ton(cooling_system.compressor_type, use_eer)
    clg_ap.cool_capacity_ratios = get_cool_capacity_ratios(cooling_system)
    set_cool_c_d(cooling_system)

    seer = cooling_system.cooling_efficiency_seer
    if cooling_system.compressor_type == HPXML::HVACCompressorTypeSingleStage
      clg_ap.cool_cap_ft_spec, clg_ap.cool_eir_ft_spec = get_cool_cap_eir_ft_spec(cooling_system.compressor_type)
      if not use_eer
        clg_ap.cool_rated_airflow_rate = clg_ap.cool_rated_cfm_per_ton[0]
        clg_ap.cool_fan_speed_ratios = calc_fan_speed_ratios(clg_ap.cool_capacity_ratios, clg_ap.cool_rated_cfm_per_ton, clg_ap.cool_rated_airflow_rate)
        clg_ap.cool_cap_fflow_spec, clg_ap.cool_eir_fflow_spec = get_cool_cap_eir_fflow_spec(cooling_system.compressor_type)
        clg_ap.cool_rated_cops = [0.2692 * seer + 0.2706] # Regression based on inverse model
      else
        clg_ap.cool_fan_speed_ratios = [1.0]
        clg_ap.cool_cap_fflow_spec = [[1.0, 0.0, 0.0]]
        clg_ap.cool_eir_fflow_spec = [[1.0, 0.0, 0.0]]
      end

    elsif cooling_system.compressor_type == HPXML::HVACCompressorTypeTwoStage
      clg_ap.cool_rated_airflow_rate = clg_ap.cool_rated_cfm_per_ton[-1]
      clg_ap.cool_fan_speed_ratios = calc_fan_speed_ratios(clg_ap.cool_capacity_ratios, clg_ap.cool_rated_cfm_per_ton, clg_ap.cool_rated_airflow_rate)
      clg_ap.cool_cap_ft_spec, clg_ap.cool_eir_ft_spec = get_cool_cap_eir_ft_spec(cooling_system.compressor_type)
      clg_ap.cool_cap_fflow_spec, clg_ap.cool_eir_fflow_spec = get_cool_cap_eir_fflow_spec(cooling_system.compressor_type)
      clg_ap.cool_rated_cops = [0.2773 * seer - 0.0018] # Regression based on inverse model
      clg_ap.cool_rated_cops << clg_ap.cool_rated_cops[0] * 0.91 # COP ratio based on Dylan's data as seen in BEopt 2.8 options

    elsif cooling_system.compressor_type == HPXML::HVACCompressorTypeVariableSpeed
      clg_ap.cooling_capacity_retention_temperature = 82.0
      clg_ap.cooling_capacity_retention_fraction = 1.033 # From NEEP data
      clg_ap.cool_rated_airflow_rate = clg_ap.cool_rated_cfm_per_ton[-1]
      clg_ap.cool_fan_speed_ratios = calc_fan_speed_ratios(clg_ap.cool_capacity_ratios, clg_ap.cool_rated_cfm_per_ton, clg_ap.cool_rated_airflow_rate)
      clg_ap.cool_cap_fflow_spec, clg_ap.cool_eir_fflow_spec = get_cool_cap_eir_fflow_spec(cooling_system.compressor_type)
    end

    set_cool_rated_shrs_gross(cooling_system)
  end

  # TODO
  #
  # @param hvac_system [TODO] TODO
  # @return [TODO] TODO
  def self.get_cool_capacity_ratios(hvac_system)
    # For each speed, ratio of capacity to nominal capacity
    if hvac_system.compressor_type == HPXML::HVACCompressorTypeSingleStage
      return [1.0]
    elsif hvac_system.compressor_type == HPXML::HVACCompressorTypeTwoStage
      return [0.72, 1.0]
    elsif hvac_system.compressor_type == HPXML::HVACCompressorTypeVariableSpeed
      is_ducted = !hvac_system.distribution_system_idref.nil?
      if is_ducted
        return [0.394, 1.0]
      else
        return [0.255, 1.0]
      end
    end

    fail 'Unable to get cooling capacity ratios.'
  end

  # TODO
  #
  # @param heating_system [TODO] TODO
  # @param use_cop [TODO] TODO
  # @return [TODO] TODO
  def self.set_heat_curves_central_air_source(heating_system, use_cop = false)
    htg_ap = heating_system.additional_properties
    htg_ap.heat_rated_cfm_per_ton = get_default_heat_cfm_per_ton(heating_system.compressor_type, use_cop)
    htg_ap.heat_cap_fflow_spec, htg_ap.heat_eir_fflow_spec = get_heat_cap_eir_fflow_spec(heating_system.compressor_type)
    htg_ap.heat_capacity_ratios = get_heat_capacity_ratios(heating_system)
    set_heat_c_d(heating_system)

    hspf = heating_system.heating_efficiency_hspf
    if heating_system.compressor_type == HPXML::HVACCompressorTypeSingleStage
      heating_capacity_retention_temp, heating_capacity_retention_fraction = get_heating_capacity_retention(heating_system)
      htg_ap.heat_cap_ft_spec, htg_ap.heat_eir_ft_spec = get_heat_cap_eir_ft_spec(heating_system.compressor_type, heating_capacity_retention_temp, heating_capacity_retention_fraction)
      if not use_cop
        htg_ap.heat_rated_cops = [0.0353 * hspf**2 + 0.0331 * hspf + 0.9447] # Regression based on inverse model
        htg_ap.heat_rated_airflow_rate = htg_ap.heat_rated_cfm_per_ton[0]
        htg_ap.heat_fan_speed_ratios = calc_fan_speed_ratios(htg_ap.heat_capacity_ratios, htg_ap.heat_rated_cfm_per_ton, htg_ap.heat_rated_airflow_rate)
      else
        htg_ap.heat_fan_speed_ratios = [1.0]
      end

    elsif heating_system.compressor_type == HPXML::HVACCompressorTypeTwoStage
      heating_capacity_retention_temp, heating_capacity_retention_fraction = get_heating_capacity_retention(heating_system)
      htg_ap.heat_cap_ft_spec, htg_ap.heat_eir_ft_spec = get_heat_cap_eir_ft_spec(heating_system.compressor_type, heating_capacity_retention_temp, heating_capacity_retention_fraction)
      htg_ap.heat_rated_airflow_rate = htg_ap.heat_rated_cfm_per_ton[-1]
      htg_ap.heat_fan_speed_ratios = calc_fan_speed_ratios(htg_ap.heat_capacity_ratios, htg_ap.heat_rated_cfm_per_ton, htg_ap.heat_rated_airflow_rate)
      htg_ap.heat_rated_cops = [0.0426 * hspf**2 - 0.0747 * hspf + 1.5374] # Regression based on inverse model
      htg_ap.heat_rated_cops << htg_ap.heat_rated_cops[0] * 0.87 # COP ratio based on Dylan's data as seen in BEopt 2.8 options

    elsif heating_system.compressor_type == HPXML::HVACCompressorTypeVariableSpeed
      htg_ap.heat_rated_airflow_rate = htg_ap.heat_rated_cfm_per_ton[-1]
      htg_ap.heat_capacity_ratios = get_heat_capacity_ratios(heating_system)
      htg_ap.heat_fan_speed_ratios = calc_fan_speed_ratios(htg_ap.heat_capacity_ratios, htg_ap.heat_rated_cfm_per_ton, htg_ap.heat_rated_airflow_rate)
    end
  end

  # TODO
  #
  # @param heat_pump [TODO] TODO
  # @return [TODO] TODO
  def self.set_heat_detailed_performance_data(heat_pump)
    hp_ap = heat_pump.additional_properties
    is_ducted = !heat_pump.distribution_system_idref.nil?
    hspf = heat_pump.heating_efficiency_hspf

    # Default data inputs based on NEEP data
    detailed_performance_data = heat_pump.heating_detailed_performance_data
    heating_capacity_retention_temp, heating_capacity_retention_fraction = get_heating_capacity_retention(heat_pump)
    max_cap_maint_5 = 1.0 - (1.0 - heating_capacity_retention_fraction) * (HVAC::AirSourceHeatRatedODB - 5.0) /
                            (HVAC::AirSourceHeatRatedODB - heating_capacity_retention_temp)

    if is_ducted
      a, b, c, d, e = 0.4348, 0.008923, 1.090, -0.1861, -0.07564
    else
      a, b, c, d, e = 0.1914, -1.822, 1.364, -0.07783, 2.221
    end
    max_cop_47 = a * hspf + b * max_cap_maint_5 + c * max_cap_maint_5**2 + d * max_cap_maint_5 * hspf + e
    max_capacity_47 = heat_pump.heating_capacity * hp_ap.heat_capacity_ratios[-1]
    min_capacity_47 = max_capacity_47 / hp_ap.heat_capacity_ratios[-1] * hp_ap.heat_capacity_ratios[0]
    min_cop_47 = is_ducted ? max_cop_47 * (-0.0306 * hspf + 1.5385) : max_cop_47 * (-0.01698 * hspf + 1.5907)
    max_capacity_5 = max_capacity_47 * max_cap_maint_5
    max_cop_5 = is_ducted ? max_cop_47 * 0.587 : max_cop_47 * 0.671
    min_capacity_5 = is_ducted ? min_capacity_47 * 1.106 : min_capacity_47 * 0.611
    min_cop_5 = is_ducted ? min_cop_47 * 0.502 : min_cop_47 * 0.538

    # performance data at 47F, maximum speed
    detailed_performance_data.add(capacity: max_capacity_47.round(1),
                                  efficiency_cop: max_cop_47.round(4),
                                  capacity_description: HPXML::CapacityDescriptionMaximum,
                                  outdoor_temperature: 47,
                                  isdefaulted: true)
    # performance data at 47F, minimum speed
    detailed_performance_data.add(capacity: min_capacity_47.round(1),
                                  efficiency_cop: min_cop_47.round(4),
                                  capacity_description: HPXML::CapacityDescriptionMinimum,
                                  outdoor_temperature: 47,
                                  isdefaulted: true)
    # performance data at 5F, maximum speed
    detailed_performance_data.add(capacity: max_capacity_5.round(1),
                                  efficiency_cop: max_cop_5.round(4),
                                  capacity_description: HPXML::CapacityDescriptionMaximum,
                                  outdoor_temperature: 5,
                                  isdefaulted: true)
    # performance data at 5F, minimum speed
    detailed_performance_data.add(capacity: min_capacity_5.round(1),
                                  efficiency_cop: min_cop_5.round(4),
                                  capacity_description: HPXML::CapacityDescriptionMinimum,
                                  outdoor_temperature: 5,
                                  isdefaulted: true)
  end

  # TODO
  #
  # @param heat_pump [TODO] TODO
  # @return [TODO] TODO
  def self.set_cool_detailed_performance_data(heat_pump)
    hp_ap = heat_pump.additional_properties
    is_ducted = !heat_pump.distribution_system_idref.nil?
    seer = heat_pump.cooling_efficiency_seer

    # Default data inputs based on NEEP data
    detailed_performance_data = heat_pump.cooling_detailed_performance_data
    max_cap_maint_82 = 1.0 - (1.0 - hp_ap.cooling_capacity_retention_fraction) * (HVAC::AirSourceCoolRatedODB - 82.0) /
                             (HVAC::AirSourceCoolRatedODB - hp_ap.cooling_capacity_retention_temperature)

    max_cop_95 = is_ducted ? 0.1953 * seer : 0.06635 * seer + 1.8707
    max_capacity_95 = heat_pump.cooling_capacity * hp_ap.cool_capacity_ratios[-1]
    min_capacity_95 = max_capacity_95 / hp_ap.cool_capacity_ratios[-1] * hp_ap.cool_capacity_ratios[0]
    min_cop_95 = is_ducted ? max_cop_95 * 1.231 : max_cop_95 * (0.01377 * seer + 1.13948)
    max_capacity_82 = max_capacity_95 * max_cap_maint_82
    max_cop_82 = is_ducted ? (1.297 * max_cop_95) : (1.300 * max_cop_95)
    min_capacity_82 = min_capacity_95 * 1.099
    min_cop_82 = is_ducted ? (1.402 * min_cop_95) : (1.333 * min_cop_95)

    # performance data at 95F, maximum speed
    detailed_performance_data.add(capacity: max_capacity_95.round(1),
                                  efficiency_cop: max_cop_95.round(4),
                                  capacity_description: HPXML::CapacityDescriptionMaximum,
                                  outdoor_temperature: 95,
                                  isdefaulted: true)
    # performance data at 95F, minimum speed
    detailed_performance_data.add(capacity: min_capacity_95.round(1),
                                  efficiency_cop: min_cop_95.round(4),
                                  capacity_description: HPXML::CapacityDescriptionMinimum,
                                  outdoor_temperature: 95,
                                  isdefaulted: true)
    # performance data at 82F, maximum speed
    detailed_performance_data.add(capacity: max_capacity_82.round(1),
                                  efficiency_cop: max_cop_82.round(4),
                                  capacity_description: HPXML::CapacityDescriptionMaximum,
                                  outdoor_temperature: 82,
                                  isdefaulted: true)
    # performance data at 82F, minimum speed
    detailed_performance_data.add(capacity: min_capacity_82.round(1),
                                  efficiency_cop: min_cop_82.round(4),
                                  capacity_description: HPXML::CapacityDescriptionMinimum,
                                  outdoor_temperature: 82,
                                  isdefaulted: true)
  end

  # TODO
  #
  # @param heat_pump [TODO] TODO
  # @return [TODO] TODO
  def self.get_heat_capacity_ratios(heat_pump)
    # For each speed, ratio of capacity to nominal capacity
    if heat_pump.compressor_type == HPXML::HVACCompressorTypeSingleStage
      return [1.0]
    elsif heat_pump.compressor_type == HPXML::HVACCompressorTypeTwoStage
      return [0.72, 1.0]
    elsif heat_pump.compressor_type == HPXML::HVACCompressorTypeVariableSpeed
      is_ducted = !heat_pump.distribution_system_idref.nil?
      if is_ducted
        nominal_to_max_ratio = 0.972
      else
        nominal_to_max_ratio = 0.812
      end
      if is_ducted && heat_pump.heat_pump_type == HPXML::HVACTypeHeatPumpAirToAir
        # central ducted
        return [0.358 / nominal_to_max_ratio, 1.0, 1.0 / nominal_to_max_ratio]
      elsif !is_ducted
        # wall placement
        return [0.252 / nominal_to_max_ratio, 1.0, 1.0 / nominal_to_max_ratio]
      else
        # ducted minisplit
        return [0.305 / nominal_to_max_ratio, 1.0, 1.0 / nominal_to_max_ratio]
      end
    end

    fail 'Unable to get heating capacity ratios.'
  end

  # TODO
  #
  # @param hvac_system [TODO] TODO
  # @return [TODO] TODO
  def self.drop_intermediate_speeds(hvac_system)
    # For variable-speed systems, we only want to model min/max speeds in E+.
    # Here we drop any intermediate speeds that we may have added for other purposes (e.g. hvac sizing).
    return unless hvac_system.compressor_type == HPXML::HVACCompressorTypeVariableSpeed

    hvac_ap = hvac_system.additional_properties

    while hvac_ap.cool_capacity_ratios.size > 2
      hvac_ap.cool_cap_fflow_spec.delete_at(1)
      hvac_ap.cool_eir_fflow_spec.delete_at(1)
      hvac_ap.cool_plf_fplr_spec.delete_at(1)
      hvac_ap.cool_rated_cfm_per_ton.delete_at(1)
      hvac_ap.cool_capacity_ratios.delete_at(1)
      hvac_ap.cool_fan_speed_ratios.delete_at(1)
    end
    if hvac_system.is_a? HPXML::HeatPump
      while hvac_ap.heat_capacity_ratios.size > 2
        hvac_ap.heat_cap_fflow_spec.delete_at(1)
        hvac_ap.heat_eir_fflow_spec.delete_at(1)
        hvac_ap.heat_plf_fplr_spec.delete_at(1)
        hvac_ap.heat_rated_cfm_per_ton.delete_at(1)
        hvac_ap.heat_capacity_ratios.delete_at(1)
        hvac_ap.heat_fan_speed_ratios.delete_at(1)
      end
    end
  end

  # TODO
  #
  # @param compressor_type [TODO] TODO
  # @param use_eer [TODO] TODO
  # @return [TODO] TODO
  def self.get_default_cool_cfm_per_ton(compressor_type, use_eer = false)
    # cfm/ton of rated capacity
    if compressor_type == HPXML::HVACCompressorTypeSingleStage
      if not use_eer
        return [394.2]
      else
        return [312] # medium speed
      end
    elsif compressor_type == HPXML::HVACCompressorTypeTwoStage
      return [411.0083, 344.1]
    elsif compressor_type == HPXML::HVACCompressorTypeVariableSpeed
      return [400.0, 400.0]
    else
      fail 'Compressor type not supported.'
    end
  end

  # TODO
  #
  # @param compressor_type [TODO] TODO
  # @param use_cop_or_htg_sys [TODO] TODO
  # @return [TODO] TODO
  def self.get_default_heat_cfm_per_ton(compressor_type, use_cop_or_htg_sys = false)
    # cfm/ton of rated capacity
    if compressor_type == HPXML::HVACCompressorTypeSingleStage
      if not use_cop_or_htg_sys
        return [384.1]
      else
        return [350]
      end
    elsif compressor_type == HPXML::HVACCompressorTypeTwoStage
      return [391.3333, 352.2]
    elsif compressor_type == HPXML::HVACCompressorTypeVariableSpeed
      return [400.0, 400.0, 400.0]
    else
      fail 'Compressor type not supported.'
    end
  end

  # TODO
  #
  # @param heat_pump [TODO] TODO
  # @return [TODO] TODO
  def self.set_curves_gshp(heat_pump)
    hp_ap = heat_pump.additional_properties

    # E+ equation fit coil coefficients generated following approach in Tang's thesis:
    # See Appendix B of  https://shareok.org/bitstream/handle/11244/10075/Tang_okstate_0664M_1318.pdf?sequence=1&isAllowed=y
    # Coefficients generated by catalog data: https://files.climatemaster.com/Genesis-GS-Series-Product-Catalog.pdf, p180
    # Data point taken as rated condition:
    # EWT: 80F EAT:80/67F, AFR: 1200cfm, WFR: 4.5gpm

    # Cooling Curves
    hp_ap.cool_cap_curve_spec = [[-5.45013866666657, 7.42301402824225, -1.43760846638838, 0.249103937703341, 0.0378875477019811]]
    hp_ap.cool_power_curve_spec = [[-4.21572180554818, 0.322682268675807, 4.56870615863483, 0.154605773589744, -0.167531037948482]]
    hp_ap.cool_sh_curve_spec = [[0.56143829895505, 18.7079597251858, -19.1482655264078, -0.138154731772664, 0.4823357726442, -0.00164644360129174]]

    hp_ap.cool_rated_shrs_gross = [heat_pump.cooling_shr]

    # E+ equation fit coil coefficients following approach from Tang's thesis:
    # See Appendix B Figure B.3 of  https://shareok.org/bitstream/handle/11244/10075/Tang_okstate_0664M_1318.pdf?sequence=1&isAllowed=y
    # Coefficients generated by catalog data: https://www.climatemaster.com/download/18.274be999165850ccd5b5b73/1535543867815/lc377-climatemaster-commercial-tranquility-20-single-stage-ts-series-water-source-heat-pump-submittal-set.pdf
    # Data point taken as rated condition:
    # EWT: 60F EAT: 70F AFR: 1200 cfm, WFR: 4.5 gpm

    # Heating Curves
    hp_ap.heat_cap_curve_spec = [[-3.75031847962047, -2.18062040443483, 6.8363364819032, 0.188376814356582, 0.0869274802923634]]
    hp_ap.heat_power_curve_spec = [[-8.4754723813072, 8.10952801956388, 1.38771494628738, -0.33766445915032, 0.0223085217874051]]

    # Fan/pump adjustments calculations
    power_f = heat_pump.fan_watts_per_cfm * 400.0 / UnitConversions.convert(1.0, 'ton', 'Btu/hr') * UnitConversions.convert(1.0, 'W', 'kW') # 400 cfm/ton, result is in kW per Btu/hr of capacity
    power_p = heat_pump.pump_watts_per_ton / UnitConversions.convert(1.0, 'ton', 'Btu/hr') * UnitConversions.convert(1.0, 'W', 'kW') # result is in kW per Btu/hr of capacity

    cool_eir = (1 - UnitConversions.convert(power_f, 'Wh', 'Btu')) / UnitConversions.convert(heat_pump.cooling_efficiency_eer, 'Btu', 'Wh') - power_f - power_p
    heat_eir = (1 + UnitConversions.convert(power_f, 'Wh', 'Btu')) / heat_pump.heating_efficiency_cop - power_f - power_p

    hp_ap.cool_rated_cops = [1.0 / cool_eir]
    hp_ap.heat_rated_cops = [1.0 / heat_eir]
  end

  # TODO
  #
  # @param hvac_type [TODO] TODO
  # @param seer [TODO] TODO
  # @return [TODO] TODO
  def self.get_default_compressor_type(hvac_type, seer)
    if [HPXML::HVACTypeCentralAirConditioner,
        HPXML::HVACTypeHeatPumpAirToAir].include? hvac_type
      if seer <= 15
        return HPXML::HVACCompressorTypeSingleStage
      elsif seer <= 21
        return HPXML::HVACCompressorTypeTwoStage
      elsif seer > 21
        return HPXML::HVACCompressorTypeVariableSpeed
      end
    elsif [HPXML::HVACTypeMiniSplitAirConditioner,
           HPXML::HVACTypeHeatPumpMiniSplit].include? hvac_type
      return HPXML::HVACCompressorTypeVariableSpeed
    elsif [HPXML::HVACTypePTAC,
           HPXML::HVACTypeHeatPumpPTHP,
           HPXML::HVACTypeHeatPumpRoom,
           HPXML::HVACTypeRoomAirConditioner].include? hvac_type
      return HPXML::HVACCompressorTypeSingleStage
    end
    return
  end

  # TODO
  #
  # @return [TODO] TODO
  def self.get_default_ceiling_fan_power()
    # Per ANSI/RESNET/ICC 301
    return 42.6 # W
  end

  # TODO
  #
  # @return [TODO] TODO
  def self.get_default_ceiling_fan_medium_cfm()
    # From ANSI 301-2019
    return 3000.0 # cfm
  end

  # TODO
  #
  # @param nbeds [Integer] Number of bedrooms in the dwelling unit
  # @return [TODO] TODO
  def self.get_default_ceiling_fan_quantity(nbeds)
    # Per ANSI/RESNET/ICC 301
    return nbeds + 1
  end

  # TODO
  #
  # @param weather [WeatherFile] Weather object containing EPW information
  # @return [TODO] TODO
  def self.get_default_ceiling_fan_months(weather)
    # Per ANSI/RESNET/ICC 301
    months = [0] * 12
    weather.data.MonthlyAvgDrybulbs.each_with_index do |val, m|
      next unless val > 63.0 # F

      months[m] = 1
    end
    return months
  end

  # TODO
  #
  # @param weather [WeatherFile] Weather object containing EPW information
  # @param latitude [TODO] TODO
  # @return [TODO] TODO
  def self.get_default_heating_and_cooling_seasons(weather, latitude)
    # Calculates heating/cooling seasons from BAHSP definition

    monthly_temps = weather.data.MonthlyAvgDrybulbs
    heat_design_db = weather.design.HeatingDrybulb
    is_southern_hemisphere = (latitude < 0)

    # create basis lists with zero for every month
    cooling_season_temp_basis = Array.new(monthly_temps.length, 0.0)
    heating_season_temp_basis = Array.new(monthly_temps.length, 0.0)

    if is_southern_hemisphere
      override_heating_months = [6, 7] # July, August
      override_cooling_months = [0, 11] # December, January
    else
      override_heating_months = [0, 11] # December, January
      override_cooling_months = [6, 7] # July, August
    end

    monthly_temps.each_with_index do |temp, i|
      if temp < 66.0
        heating_season_temp_basis[i] = 1.0
      elsif temp >= 66.0
        cooling_season_temp_basis[i] = 1.0
      end

      if (override_heating_months.include? i) && (heat_design_db < 59.0)
        heating_season_temp_basis[i] = 1.0
      elsif override_cooling_months.include? i
        cooling_season_temp_basis[i] = 1.0
      end
    end

    cooling_season = Array.new(monthly_temps.length, 0.0)
    heating_season = Array.new(monthly_temps.length, 0.0)

    for i in 0..11
      # Heating overlaps with cooling at beginning of summer
      prevmonth = i - 1

      if ((heating_season_temp_basis[i] == 1.0) || ((cooling_season_temp_basis[prevmonth] == 0.0) && (cooling_season_temp_basis[i] == 1.0)))
        heating_season[i] = 1.0
      else
        heating_season[i] = 0.0
      end

      if ((cooling_season_temp_basis[i] == 1.0) || ((heating_season_temp_basis[prevmonth] == 0.0) && (heating_season_temp_basis[i] == 1.0)))
        cooling_season[i] = 1.0
      else
        cooling_season[i] = 0.0
      end
    end

    # Find the first month of cooling and add one month
    for i in 0..11
      if cooling_season[i] == 1.0
        cooling_season[i - 1] = 1.0
        break
      end
    end

    return heating_season, cooling_season
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param fan [TODO] TODO
  # @param hp_min_temp [TODO] TODO
  # @return [TODO] TODO
  def self.set_fan_power_ems_program(model, fan, hp_min_temp)
    # EMS is used to disable the fan power below the hp_min_temp; the backup heating
    # system will be operating instead.

    # Sensors
    tout_db_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Drybulb Temperature')
    tout_db_sensor.setKeyName('Environment')

    # Actuators
    fan_pressure_rise_act = OpenStudio::Model::EnergyManagementSystemActuator.new(fan, *EPlus::EMSActuatorFanPressureRise)
    fan_pressure_rise_act.setName("#{fan.name} pressure rise act")

    fan_total_efficiency_act = OpenStudio::Model::EnergyManagementSystemActuator.new(fan, *EPlus::EMSActuatorFanTotalEfficiency)
    fan_total_efficiency_act.setName("#{fan.name} total efficiency act")

    # Program
    fan_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    fan_program.setName("#{fan.name} power program")
    fan_program.addLine("If #{tout_db_sensor.name} < #{UnitConversions.convert(hp_min_temp, 'F', 'C').round(2)}")
    fan_program.addLine("  Set #{fan_pressure_rise_act.name} = 0")
    fan_program.addLine("  Set #{fan_total_efficiency_act.name} = 1")
    fan_program.addLine('Else')
    fan_program.addLine("  Set #{fan_pressure_rise_act.name} = NULL")
    fan_program.addLine("  Set #{fan_total_efficiency_act.name} = NULL")
    fan_program.addLine('EndIf')

    # Calling Point
    fan_program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    fan_program_calling_manager.setName("#{fan.name} power program calling manager")
    fan_program_calling_manager.setCallingPoint('AfterPredictorBeforeHVACManagers')
    fan_program_calling_manager.addProgram(fan_program)
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param pump_w [TODO] TODO
  # @param pump [TODO] TODO
  # @param heating_object [TODO] TODO
  # @return [TODO] TODO
  def self.set_pump_power_ems_program(model, pump_w, pump, heating_object)
    # EMS is used to set the pump power.
    # Without EMS, the pump power will vary according to the plant loop part load ratio
    # (based on flow rate) rather than the boiler part load ratio (based on load).

    # Sensors
    if heating_object.is_a? OpenStudio::Model::BoilerHotWater
      heating_plr_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Boiler Part Load Ratio')
      heating_plr_sensor.setName("#{heating_object.name} plr s")
      heating_plr_sensor.setKeyName(heating_object.name.to_s)
    elsif heating_object.is_a? OpenStudio::Model::AirLoopHVACUnitarySystem
      heating_plr_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Unitary System Part Load Ratio')
      heating_plr_sensor.setName("#{heating_object.name} plr s")
      heating_plr_sensor.setKeyName(heating_object.name.to_s)
    end

    pump_mfr_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Pump Mass Flow Rate')
    pump_mfr_sensor.setName("#{pump.name} mfr s")
    pump_mfr_sensor.setKeyName(pump.name.to_s)

    # Internal variable
    pump_rated_mfr_var = OpenStudio::Model::EnergyManagementSystemInternalVariable.new(model, EPlus::EMSIntVarPumpMFR)
    pump_rated_mfr_var.setName("#{pump.name} rated mfr")
    pump_rated_mfr_var.setInternalDataIndexKeyName(pump.name.to_s)

    # Actuator
    pump_pressure_rise_act = OpenStudio::Model::EnergyManagementSystemActuator.new(pump, *EPlus::EMSActuatorPumpPressureRise)
    pump_pressure_rise_act.setName("#{pump.name} pressure rise act")

    # Program
    # See https://bigladdersoftware.com/epx/docs/9-3/ems-application-guide/hvac-systems-001.html#pump
    pump_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    pump_program.setName("#{pump.name} power program")
    pump_program.addLine("Set heating_plr = #{heating_plr_sensor.name}")
    pump_program.addLine("Set pump_total_eff = #{pump_rated_mfr_var.name} / 1000 * #{pump.ratedPumpHead} / #{pump.ratedPowerConsumption.get}")
    pump_program.addLine("Set pump_vfr = #{pump_mfr_sensor.name} / 1000")
    pump_program.addLine('If pump_vfr > 0')
    pump_program.addLine("  Set #{pump_pressure_rise_act.name} = #{pump_w} * heating_plr * pump_total_eff / pump_vfr")
    pump_program.addLine('Else')
    pump_program.addLine("  Set #{pump_pressure_rise_act.name} = 0")
    pump_program.addLine('EndIf')

    # Calling Point
    pump_program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    pump_program_calling_manager.setName("#{pump.name} power program calling manager")
    pump_program_calling_manager.setCallingPoint('EndOfSystemTimestepBeforeHVACReporting')
    pump_program_calling_manager.addProgram(pump_program)
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param fan_or_pump [TODO] TODO
  # @param htg_object [TODO] TODO
  # @param clg_object [TODO] TODO
  # @param backup_htg_object [TODO] TODO
  # @param hpxml_object [TODO] TODO
  # @return [TODO] TODO
  def self.disaggregate_fan_or_pump(model, fan_or_pump, htg_object, clg_object, backup_htg_object, hpxml_object)
    # Disaggregate into heating/cooling output energy use.

    sys_id = hpxml_object.id

    if fan_or_pump.is_a? OpenStudio::Model::FanSystemModel
      fan_or_pump_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Fan #{EPlus::FuelTypeElectricity} Energy")
    elsif fan_or_pump.is_a? OpenStudio::Model::PumpVariableSpeed
      fan_or_pump_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Pump #{EPlus::FuelTypeElectricity} Energy")
    elsif fan_or_pump.is_a? OpenStudio::Model::ElectricEquipment
      fan_or_pump_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Electric Equipment #{EPlus::FuelTypeElectricity} Energy")
    else
      fail "Unexpected fan/pump object '#{fan_or_pump.name}'."
    end
    fan_or_pump_sensor.setName("#{fan_or_pump.name} s")
    fan_or_pump_sensor.setKeyName(fan_or_pump.name.to_s)
    fan_or_pump_var = fan_or_pump.name.to_s.gsub(' ', '_')

    if clg_object.nil?
      clg_object_sensor = nil
    else
      if clg_object.is_a? OpenStudio::Model::EvaporativeCoolerDirectResearchSpecial
        var = 'Evaporative Cooler Water Volume'
      else
        var = 'Cooling Coil Total Cooling Energy'
      end
      clg_object_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
      clg_object_sensor.setName("#{clg_object.name} s")
      clg_object_sensor.setKeyName(clg_object.name.to_s)
    end

    if htg_object.nil?
      htg_object_sensor = nil
    else
      if htg_object.is_a? OpenStudio::Model::ZoneHVACBaseboardConvectiveWater
        var = 'Baseboard Total Heating Energy'
      elsif htg_object.is_a? OpenStudio::Model::ZoneHVACFourPipeFanCoil
        var = 'Fan Coil Heating Energy'
      else
        var = 'Heating Coil Heating Energy'
      end

      htg_object_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
      htg_object_sensor.setName("#{htg_object.name} s")
      htg_object_sensor.setKeyName(htg_object.name.to_s)
    end

    if backup_htg_object.nil?
      backup_htg_object_sensor = nil
    else
      if backup_htg_object.is_a? OpenStudio::Model::ZoneHVACBaseboardConvectiveWater
        var = 'Baseboard Total Heating Energy'
      else
        var = 'Heating Coil Heating Energy'
      end

      backup_htg_object_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
      backup_htg_object_sensor.setName("#{backup_htg_object.name} s")
      backup_htg_object_sensor.setKeyName(backup_htg_object.name.to_s)
    end

    sensors = { 'clg' => clg_object_sensor,
                'primary_htg' => htg_object_sensor,
                'backup_htg' => backup_htg_object_sensor }
    sensors = sensors.select { |_m, s| !s.nil? }

    # Disaggregate electric fan/pump energy
    fan_or_pump_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    fan_or_pump_program.setName("#{fan_or_pump_var} disaggregate program")
    if htg_object.is_a?(OpenStudio::Model::ZoneHVACBaseboardConvectiveWater) || htg_object.is_a?(OpenStudio::Model::ZoneHVACFourPipeFanCoil)
      # Pump may occasionally run when baseboard isn't, so just assign all pump energy here
      mode, _sensor = sensors.first
      if (sensors.size != 1) || (mode != 'primary_htg')
        fail 'Unexpected situation.'
      end

      fan_or_pump_program.addLine("  Set #{fan_or_pump_var}_#{mode} = #{fan_or_pump_sensor.name}")
    else
      sensors.keys.each do |mode|
        fan_or_pump_program.addLine("Set #{fan_or_pump_var}_#{mode} = 0")
      end
      sensors.each_with_index do |(mode, sensor), i|
        if i == 0
          if_else_str = "If #{sensor.name} > 0"
        elsif i == sensors.size - 1
          # Use else for last mode to make sure we don't miss any energy use
          # See https://github.com/NREL/OpenStudio-HPXML/issues/1424
          if_else_str = 'Else'
        else
          if_else_str = "ElseIf #{sensor.name} > 0"
        end
        if mode == 'primary_htg' && sensors.keys[i + 1] == 'backup_htg'
          # HP with both primary and backup heating
          # If both are operating, apportion energy use
          fan_or_pump_program.addLine("#{if_else_str} && (#{sensors.values[i + 1].name} > 0)")
          fan_or_pump_program.addLine("  Set #{fan_or_pump_var}_#{mode} = #{fan_or_pump_sensor.name} * #{sensor.name} / (#{sensor.name} + #{sensors.values[i + 1].name})")
          fan_or_pump_program.addLine("  Set #{fan_or_pump_var}_#{sensors.keys[i + 1]} = #{fan_or_pump_sensor.name} * #{sensors.values[i + 1].name} / (#{sensor.name} + #{sensors.values[i + 1].name})")
          if_else_str = if_else_str.gsub('If', 'ElseIf') if if_else_str.start_with?('If')
        end
        fan_or_pump_program.addLine(if_else_str)
        fan_or_pump_program.addLine("  Set #{fan_or_pump_var}_#{mode} = #{fan_or_pump_sensor.name}")
      end
      fan_or_pump_program.addLine('EndIf')
    end

    fan_or_pump_program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    fan_or_pump_program_calling_manager.setName("#{fan_or_pump.name} disaggregate program calling manager")
    fan_or_pump_program_calling_manager.setCallingPoint('EndOfSystemTimestepBeforeHVACReporting')
    fan_or_pump_program_calling_manager.addProgram(fan_or_pump_program)

    sensors.each do |mode, sensor|
      next if sensor.nil?

      fan_or_pump_ems_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, "#{fan_or_pump_var}_#{mode}")
      object_type = { 'clg' => Constants.ObjectNameFanPumpDisaggregateCool,
                      'primary_htg' => Constants.ObjectNameFanPumpDisaggregatePrimaryHeat,
                      'backup_htg' => Constants.ObjectNameFanPumpDisaggregateBackupHeat }[mode]
      fan_or_pump_ems_output_var.setName("#{fan_or_pump.name} #{object_type}")
      fan_or_pump_ems_output_var.setTypeOfDataInVariable('Summed')
      fan_or_pump_ems_output_var.setUpdateFrequency('SystemTimestep')
      fan_or_pump_ems_output_var.setEMSProgramOrSubroutineName(fan_or_pump_program)
      fan_or_pump_ems_output_var.setUnits('J')
      fan_or_pump_ems_output_var.additionalProperties.setFeature('HPXML_ID', sys_id) # Used by reporting measure
      fan_or_pump_ems_output_var.additionalProperties.setFeature('ObjectType', object_type) # Used by reporting measure
    end
  end

  # TODO
  #
  # @param fraction_served [TODO] TODO
  # @param zone_hvac [TODO] TODO
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param conditioned_space [TODO] TODO
  # @return [TODO] TODO
  def self.adjust_dehumidifier_load_EMS(fraction_served, zone_hvac, model, conditioned_space)
    # adjust hvac load to space when dehumidifier serves less than 100% dehumidification load. (With E+ dehumidifier object, it can only model 100%)

    # sensor
    dehumidifier_sens_htg = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Dehumidifier Sensible Heating Rate')
    dehumidifier_sens_htg.setName("#{zone_hvac.name} sens htg")
    dehumidifier_sens_htg.setKeyName(zone_hvac.name.to_s)
    dehumidifier_power = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Zone Dehumidifier #{EPlus::FuelTypeElectricity} Rate")
    dehumidifier_power.setName("#{zone_hvac.name} power htg")
    dehumidifier_power.setKeyName(zone_hvac.name.to_s)

    # actuator
    dehumidifier_load_adj_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
    dehumidifier_load_adj_def.setName("#{zone_hvac.name} sens htg adj def")
    dehumidifier_load_adj_def.setDesignLevel(0)
    dehumidifier_load_adj_def.setFractionRadiant(0)
    dehumidifier_load_adj_def.setFractionLatent(0)
    dehumidifier_load_adj_def.setFractionLost(0)
    dehumidifier_load_adj = OpenStudio::Model::OtherEquipment.new(dehumidifier_load_adj_def)
    dehumidifier_load_adj.setName("#{zone_hvac.name} sens htg adj")
    dehumidifier_load_adj.setSpace(conditioned_space)
    dehumidifier_load_adj.setSchedule(model.alwaysOnDiscreteSchedule)

    dehumidifier_load_adj_act = OpenStudio::Model::EnergyManagementSystemActuator.new(dehumidifier_load_adj, *EPlus::EMSActuatorOtherEquipmentPower, dehumidifier_load_adj.space.get)
    dehumidifier_load_adj_act.setName("#{zone_hvac.name} sens htg adj act")

    # EMS program
    program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    program.setName("#{zone_hvac.name} load adj program")
    program.addLine("If #{dehumidifier_sens_htg.name} > 0")
    program.addLine("  Set #{dehumidifier_load_adj_act.name} = - (#{dehumidifier_sens_htg.name} - #{dehumidifier_power.name}) * (1 - #{fraction_served})")
    program.addLine('Else')
    program.addLine("  Set #{dehumidifier_load_adj_act.name} = 0")
    program.addLine('EndIf')

    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName(program.name.to_s + 'calling manager')
    program_calling_manager.setCallingPoint('BeginZoneTimestepAfterInitHeatBalance')
    program_calling_manager.addProgram(program)
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param obj_name [String] Name for the OpenStudio object
  # @param heat_pump [TODO] TODO
  # @param hpxml_header [HPXML::Header] HPXML Header object (one per HPXML file)
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @return [TODO] TODO
  def self.create_supp_heating_coil(model, obj_name, heat_pump, hpxml_header = nil, runner = nil, hpxml_bldg = nil)
    fuel = heat_pump.backup_heating_fuel
    capacity = heat_pump.backup_heating_capacity
    efficiency = heat_pump.backup_heating_efficiency_percent
    efficiency = heat_pump.backup_heating_efficiency_afue if efficiency.nil?

    if fuel.nil?
      return
    end

    backup_heating_capacity_increment = hpxml_header.heat_pump_backup_heating_capacity_increment unless hpxml_header.nil?
    backup_heating_capacity_increment = nil unless fuel == HPXML::FuelTypeElectricity
    if not backup_heating_capacity_increment.nil?
      if hpxml_bldg.building_construction.number_of_units > 1
        # Throw error and stop simulation
        runner.registerError('NumberofUnits greater than 1 is not supported for multi-staging backup coil.')
      end
      max_num_stages = 4

      num_stages = [(capacity / backup_heating_capacity_increment).ceil(), max_num_stages].min
      # OpenStudio only supports 4 stages for now
      runner.registerWarning("EnergyPlus only supports #{max_num_stages} stages for multi-stage electric backup coil. Combined the remaining capacities in the last stage.") if (capacity / backup_heating_capacity_increment).ceil() > 4

      htg_supp_coil = OpenStudio::Model::CoilHeatingElectricMultiStage.new(model)
      htg_supp_coil.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      stage_capacity = 0.0

      (1..num_stages).each do |stage_i|
        stage = OpenStudio::Model::CoilHeatingElectricMultiStageStageData.new(model)
        if stage_i == max_num_stages
          increment = (capacity - stage_capacity) # Model remaining capacity anyways
        else
          increment = backup_heating_capacity_increment
        end
        next if increment <= 5 # Tolerance to avoid modeling small capacity stage

        # There're two cases to throw this warning: 1. More stages are needed so that the remaining capacities are combined in last stage. 2. Total capacity is not able to be perfectly divided by increment.
        # For the first case, the above warning of num_stages has already thrown
        runner.registerWarning("Calculated multi-stage backup coil capacity increment for last stage is not equal to user input, actual capacity increment is #{increment} Btu/hr.") if (increment - backup_heating_capacity_increment).abs > 1
        stage_capacity += increment

        stage.setNominalCapacity(UnitConversions.convert(stage_capacity, 'Btu/hr', 'W'))
        stage.setEfficiency(efficiency)
        htg_supp_coil.addStage(stage)
      end
    else
      if fuel == HPXML::FuelTypeElectricity
        htg_supp_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
        htg_supp_coil.setEfficiency(efficiency)
      else
        htg_supp_coil = OpenStudio::Model::CoilHeatingGas.new(model)
        htg_supp_coil.setGasBurnerEfficiency(efficiency)
        htg_supp_coil.setOnCycleParasiticElectricLoad(0)
        htg_supp_coil.setOffCycleParasiticGasLoad(0)
        htg_supp_coil.setFuelType(EPlus.fuel_type(fuel))
      end
      htg_supp_coil.setNominalCapacity(UnitConversions.convert(capacity, 'Btu/hr', 'W'))
    end
    htg_supp_coil.setName(obj_name + ' backup htg coil')
    htg_supp_coil.additionalProperties.setFeature('HPXML_ID', heat_pump.id) # Used by reporting measure
    htg_supp_coil.additionalProperties.setFeature('IsHeatPumpBackup', true) # Used by reporting measure

    return htg_supp_coil
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param obj_name [String] Name for the OpenStudio object
  # @param fan_watts_per_cfm [TODO] TODO
  # @param fan_cfms [TODO] TODO
  # @return [TODO] TODO
  def self.create_supply_fan(model, obj_name, fan_watts_per_cfm, fan_cfms)
    # Note: fan_cfms should include all unique airflow rates (both heating and cooling, at all speeds)
    fan = OpenStudio::Model::FanSystemModel.new(model)
    fan.setSpeedControlMethod('Discrete')
    fan.setDesignPowerSizingMethod('TotalEfficiencyAndPressure')
    fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    set_fan_power(fan, fan_watts_per_cfm)
    fan.setName(obj_name + ' supply fan')
    fan.setEndUseSubcategory('supply fan')
    fan.setMotorEfficiency(1.0)
    fan.setMotorInAirStreamFraction(1.0)
    max_fan_cfm = Float(fan_cfms.max) # Convert to float to prevent integer division below
    fan.setDesignMaximumAirFlowRate(UnitConversions.convert(max_fan_cfm, 'cfm', 'm^3/s'))

    fan_cfms.sort.each do |fan_cfm|
      fan_ratio = fan_cfm / max_fan_cfm
      power_fraction = calculate_fan_power_from_curve(1.0, fan_ratio)
      fan.addSpeed(fan_ratio.round(5), power_fraction.round(5))
    end

    return fan
  end

  # TODO
  #
  # @param max_fan_power [TODO] TODO
  # @param fan_ratio [TODO] TODO
  # @return [TODO] TODO
  def self.calculate_fan_power_from_curve(max_fan_power, fan_ratio)
    # Cubic relationship fan power curve
    return max_fan_power * (fan_ratio**3)
  end

  # TODO
  #
  # @param fan [TODO] TODO
  # @param fan_watts_per_cfm [TODO] TODO
  # @return [TODO] TODO
  def self.set_fan_power(fan, fan_watts_per_cfm)
    if fan_watts_per_cfm > 0
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      pressure_rise = fan_eff * fan_watts_per_cfm / UnitConversions.convert(1.0, 'cfm', 'm^3/s') # Pa
    else
      fan_eff = 1
      pressure_rise = 0.000001
    end
    fan.setFanTotalEfficiency(fan_eff)
    fan.setDesignPressureRise(pressure_rise)
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param obj_name [String] Name for the OpenStudio object
  # @param fan [TODO] TODO
  # @param htg_coil [TODO] TODO
  # @param clg_coil [TODO] TODO
  # @param htg_supp_coil [TODO] TODO
  # @param htg_cfm [TODO] TODO
  # @param clg_cfm [TODO] TODO
  # @param supp_max_temp [TODO] TODO
  # @return [OpenStudio::Model::AirLoopHVACUnitarySystem] OpenStudio Air Loop HVAC Unitary System object
  def self.create_air_loop_unitary_system(model, obj_name, fan, htg_coil, clg_coil, htg_supp_coil, htg_cfm, clg_cfm, supp_max_temp = nil)
    cycle_fan_sch = OpenStudio::Model::ScheduleConstant.new(model)
    cycle_fan_sch.setName(obj_name + ' auto fan schedule')
    Schedule.set_schedule_type_limits(model, cycle_fan_sch, Constants.ScheduleTypeLimitsOnOff)
    cycle_fan_sch.setValue(0) # 0 denotes that fan cycles on and off to meet the load (i.e., AUTO fan) as opposed to continuous operation

    air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
    air_loop_unitary.setName(obj_name + ' unitary system')
    air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    air_loop_unitary.setSupplyFan(fan)
    air_loop_unitary.setFanPlacement('BlowThrough')
    air_loop_unitary.setSupplyAirFanOperatingModeSchedule(cycle_fan_sch)
    if htg_coil.nil?
      air_loop_unitary.setSupplyAirFlowRateDuringHeatingOperation(0.0)
    else
      air_loop_unitary.setHeatingCoil(htg_coil)
      air_loop_unitary.setSupplyAirFlowRateDuringHeatingOperation(UnitConversions.convert(htg_cfm, 'cfm', 'm^3/s'))
    end
    if clg_coil.nil?
      air_loop_unitary.setSupplyAirFlowRateDuringCoolingOperation(0.0)
    else
      air_loop_unitary.setCoolingCoil(clg_coil)
      air_loop_unitary.setSupplyAirFlowRateDuringCoolingOperation(UnitConversions.convert(clg_cfm, 'cfm', 'm^3/s'))
    end
    if htg_supp_coil.nil?
      air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(120.0, 'F', 'C'))
    else
      air_loop_unitary.setSupplementalHeatingCoil(htg_supp_coil)
      air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(200.0, 'F', 'C')) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      if not supp_max_temp.nil?
        air_loop_unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(UnitConversions.convert(supp_max_temp, 'F', 'C'))
      end
    end
    air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)
    return air_loop_unitary
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param obj_name [String] Name for the OpenStudio object
  # @param system [TODO] TODO
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param sequential_heat_load_fracs [TODO] TODO
  # @param sequential_cool_load_fracs [TODO] TODO
  # @param airflow_cfm [TODO] TODO
  # @param heating_system [TODO] TODO
  # @param hvac_unavailable_periods [TODO] TODO
  # @return [TODO] TODO
  def self.create_air_loop(model, obj_name, system, control_zone, sequential_heat_load_fracs, sequential_cool_load_fracs, airflow_cfm, heating_system, hvac_unavailable_periods)
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    air_loop.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    air_loop.setName(obj_name + ' airloop')
    air_loop.zoneSplitter.setName(obj_name + ' zone splitter')
    air_loop.zoneMixer.setName(obj_name + ' zone mixer')
    air_loop.setDesignSupplyAirFlowRate(UnitConversions.convert(airflow_cfm, 'cfm', 'm^3/s'))
    system.addToNode(air_loop.supplyInletNode)

    if system.is_a? OpenStudio::Model::AirLoopHVACUnitarySystem
      air_terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      system.setControllingZoneorThermostatLocation(control_zone)
    else
      air_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule)
      air_terminal.setConstantMinimumAirFlowFraction(0)
      air_terminal.setFixedMinimumAirFlowRate(0)
    end
    air_terminal.setMaximumAirFlowRate(UnitConversions.convert(airflow_cfm, 'cfm', 'm^3/s'))
    air_terminal.setName(obj_name + ' terminal')
    air_loop.multiAddBranchForZone(control_zone, air_terminal)

    set_sequential_load_fractions(model, control_zone, air_terminal, sequential_heat_load_fracs, sequential_cool_load_fracs, hvac_unavailable_periods, heating_system)

    return air_loop
  end

  # TODO
  #
  # @param dh_type [TODO] TODO
  # @param w_coeff [TODO] TODO
  # @param ef_coeff [TODO] TODO
  # @param ief [TODO] TODO
  # @param water_removal_rate [TODO] TODO
  # @return [TODO] TODO
  def self.apply_dehumidifier_ief_to_ef_inputs(dh_type, w_coeff, ef_coeff, ief, water_removal_rate)
    # Shift inputs under IEF test conditions to E+ supported EF test conditions
    # test conditions
    if dh_type == HPXML::DehumidifierTypePortable
      ief_db = UnitConversions.convert(65.0, 'F', 'C') # degree C
    elsif dh_type == HPXML::DehumidifierTypeWholeHome
      ief_db = UnitConversions.convert(73.0, 'F', 'C') # degree C
    end
    rh = 60.0 # for both EF and IEF test conditions, %

    # Independent variables applied to curve equations
    var_array_ief = [1, ief_db, ief_db * ief_db, rh, rh * rh, ief_db * rh]

    # Curved values under EF test conditions
    curve_value_ef = 1 # Curves are normalized to 1.0 under EF test conditions, 80F, 60%
    # Curve values under IEF test conditions
    ef_curve_value_ief = var_array_ief.zip(ef_coeff).map { |var, coeff| var * coeff }.sum(0.0)
    water_removal_curve_value_ief = var_array_ief.zip(w_coeff).map { |var, coeff| var * coeff }.sum(0.0)

    # E+ inputs under EF test conditions
    ef_input = ief / ef_curve_value_ief * curve_value_ef
    water_removal_rate_input = water_removal_rate / water_removal_curve_value_ief * curve_value_ef

    return ef_input, water_removal_rate_input
  end

  # TODO
  #
  # @param heating_system [TODO] TODO
  # @return [TODO] TODO
  def self.get_default_boiler_eae(heating_system)
    if heating_system.heating_system_type != HPXML::HVACTypeBoiler
      return
    end
    if not heating_system.electric_auxiliary_energy.nil?
      return heating_system.electric_auxiliary_energy
    end

    # From ANSI/RESNET/ICC 301-2019 Standard
    fuel = heating_system.heating_system_fuel

    if heating_system.is_shared_system
      distribution_system = heating_system.distribution_system
      distribution_type = distribution_system.distribution_system_type

      if not heating_system.shared_loop_watts.nil?
        sp_kw = UnitConversions.convert(heating_system.shared_loop_watts, 'W', 'kW')
        n_dweq = heating_system.number_of_units_served.to_f
        if distribution_system.air_type == HPXML::AirTypeFanCoil
          aux_in = UnitConversions.convert(heating_system.fan_coil_watts, 'W', 'kW')
        else
          aux_in = 0.0 # ANSI/RESNET/ICC 301-2019 Section 4.4.7.2
        end
        # ANSI/RESNET/ICC 301-2019 Equation 4.4-5
        return (((sp_kw / n_dweq) + aux_in) * 2080.0).round(2) # kWh/yr
      elsif distribution_type == HPXML::HVACDistributionTypeHydronic
        # kWh/yr, per ANSI/RESNET/ICC 301-2019 Table 4.5.2(5)
        if distribution_system.hydronic_type == HPXML::HydronicTypeWaterLoop # Shared boiler w/ WLHP
          return 265.0
        else # Shared boiler w/ baseboard/radiators/etc
          return 220.0
        end
      elsif distribution_type == HPXML::HVACDistributionTypeAir
        if distribution_system.air_type == HPXML::AirTypeFanCoil # Shared boiler w/ fan coil
          return 438.0
        end
      end

    else # In-unit boilers

      if [HPXML::FuelTypeNaturalGas,
          HPXML::FuelTypePropane,
          HPXML::FuelTypeElectricity,
          HPXML::FuelTypeWoodCord,
          HPXML::FuelTypeWoodPellets].include? fuel
        return 170.0 # kWh/yr
      elsif [HPXML::FuelTypeOil,
             HPXML::FuelTypeOil1,
             HPXML::FuelTypeOil2,
             HPXML::FuelTypeOil4,
             HPXML::FuelTypeOil5or6,
             HPXML::FuelTypeDiesel,
             HPXML::FuelTypeKerosene,
             HPXML::FuelTypeCoal,
             HPXML::FuelTypeCoalAnthracite,
             HPXML::FuelTypeCoalBituminous,
             HPXML::FuelTypeCoke].include? fuel
        return 330.0 # kWh/yr
      end
    end
  end

  # TODO
  #
  # @param compressor_type [TODO] TODO
  # @param heating_capacity_retention_temp [TODO] TODO
  # @param heating_capacity_retention_fraction [TODO] TODO
  # @return [TODO] TODO
  def self.calc_heat_cap_ft_spec(compressor_type, heating_capacity_retention_temp, heating_capacity_retention_fraction)
    if compressor_type == HPXML::HVACCompressorTypeSingleStage
      iat_slope = -0.002303414
      iat_intercept = 0.18417308
      num_speeds = 1
    elsif compressor_type == HPXML::HVACCompressorTypeTwoStage
      iat_slope = -0.002947013
      iat_intercept = 0.23168251
      num_speeds = 2
    end

    # Biquadratic: capacity multiplier = a + b*IAT + c*IAT^2 + d*OAT + e*OAT^2 + f*IAT*OAT
    # Derive coefficients from user input for capacity retention at outdoor drybulb temperature X [C].
    x_A = heating_capacity_retention_temp
    y_A = heating_capacity_retention_fraction
    x_B = HVAC::AirSourceHeatRatedODB
    y_B = 1.0

    oat_slope = (y_B - y_A) / (x_B - x_A)
    oat_intercept = y_A - (x_A * oat_slope)

    return [[oat_intercept + iat_intercept, iat_slope, 0, oat_slope, 0, 0]] * num_speeds
  end

  # TODO
  #
  # @param heat_pump [TODO] TODO
  # @return [TODO] TODO
  def self.get_heating_capacity_retention(heat_pump)
    if not heat_pump.heating_capacity_17F.nil?
      heating_capacity_retention_temp = 17.0
      heating_capacity_retention_fraction = heat_pump.heating_capacity == 0.0 ? 0.0 : heat_pump.heating_capacity_17F / heat_pump.heating_capacity
    elsif not heat_pump.heating_capacity_retention_fraction.nil?
      heating_capacity_retention_temp = heat_pump.heating_capacity_retention_temp
      heating_capacity_retention_fraction = heat_pump.heating_capacity_retention_fraction
    else
      fail 'Missing heating capacity retention or 17F heating capacity.'
    end
    return heating_capacity_retention_temp, heating_capacity_retention_fraction
  end

  # TODO
  #
  # @param capacity_ratios [TODO] TODO
  # @param rated_cfm_per_tons [TODO] TODO
  # @param rated_airflow_rate [TODO] TODO
  # @return [TODO] TODO
  def self.calc_fan_speed_ratios(capacity_ratios, rated_cfm_per_tons, rated_airflow_rate)
    fan_speed_ratios = []
    capacity_ratios.each_with_index do |capacity_ratio, i|
      fan_speed_ratios << rated_cfm_per_tons[i] * capacity_ratio / rated_airflow_rate
    end
    return fan_speed_ratios
  end

  # TODO
  #
  # @param coeff [TODO] TODO
  # @return [TODO] TODO
  def self.convert_curve_biquadratic(coeff)
    # Convert IP curves to SI curves
    si_coeff = []
    si_coeff << coeff[0] + 32.0 * (coeff[1] + coeff[3]) + 1024.0 * (coeff[2] + coeff[4] + coeff[5])
    si_coeff << 9.0 / 5.0 * coeff[1] + 576.0 / 5.0 * coeff[2] + 288.0 / 5.0 * coeff[5]
    si_coeff << 81.0 / 25.0 * coeff[2]
    si_coeff << 9.0 / 5.0 * coeff[3] + 576.0 / 5.0 * coeff[4] + 288.0 / 5.0 * coeff[5]
    si_coeff << 81.0 / 25.0 * coeff[4]
    si_coeff << 81.0 / 25.0 * coeff[5]
    return si_coeff
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param name [TODO] TODO
  # @param independent_vars [TODO] TODO
  # @param output_values [TODO] TODO
  # @param output_min [TODO] TODO
  # @param output_max [TODO] TODO
  # @return [TODO] TODO
  def self.create_table_lookup(model, name, independent_vars, output_values, output_min = nil, output_max = nil)
    if (not output_min.nil?) && (output_values.min < output_min)
      fail "Minimum table lookup output value (#{output_values.min}) is less than #{output_min} for #{name}."
    end
    if (not output_max.nil?) && (output_values.max > output_max)
      fail "Maximum table lookup output value (#{output_values.max}) is greater than #{output_max} for #{name}."
    end

    table = OpenStudio::Model::TableLookup.new(model)
    table.setName(name)
    independent_vars.each do |var|
      ind_var = OpenStudio::Model::TableIndependentVariable.new(model)
      ind_var.setName(var[:name])
      ind_var.setMinimumValue(var[:min])
      ind_var.setMaximumValue(var[:max])
      ind_var.setExtrapolationMethod('Constant')
      ind_var.setValues(var[:values])
      table.addIndependentVariable(ind_var)
    end
    table.setMinimumOutput(output_min) unless output_min.nil?
    table.setMaximumOutput(output_max) unless output_max.nil?
    table.setOutputValues(output_values)
    return table
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @return [TODO] TODO
  def self.create_curve_biquadratic_constant(model)
    curve = OpenStudio::Model::CurveBiquadratic.new(model)
    curve.setName('ConstantBiquadratic')
    curve.setCoefficient1Constant(1)
    curve.setCoefficient2x(0)
    curve.setCoefficient3xPOW2(0)
    curve.setCoefficient4y(0)
    curve.setCoefficient5yPOW2(0)
    curve.setCoefficient6xTIMESY(0)
    curve.setMinimumValueofx(-100)
    curve.setMaximumValueofx(100)
    curve.setMinimumValueofy(-100)
    curve.setMaximumValueofy(100)
    return curve
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @return [TODO] TODO
  def self.create_curve_quadratic_constant(model)
    curve = OpenStudio::Model::CurveQuadratic.new(model)
    curve.setName('ConstantQuadratic')
    curve.setCoefficient1Constant(1)
    curve.setCoefficient2x(0)
    curve.setCoefficient3xPOW2(0)
    curve.setMinimumValueofx(-100)
    curve.setMaximumValueofx(100)
    curve.setMinimumCurveOutput(-100)
    curve.setMaximumCurveOutput(100)
    return curve
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param coeff [TODO] TODO
  # @param name [TODO] TODO
  # @param min_x [TODO] TODO
  # @param max_x [TODO] TODO
  # @param min_y [TODO] TODO
  # @param max_y [TODO] TODO
  # @return [TODO] TODO
  def self.create_curve_biquadratic(model, coeff, name, min_x, max_x, min_y, max_y)
    curve = OpenStudio::Model::CurveBiquadratic.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2x(coeff[1])
    curve.setCoefficient3xPOW2(coeff[2])
    curve.setCoefficient4y(coeff[3])
    curve.setCoefficient5yPOW2(coeff[4])
    curve.setCoefficient6xTIMESY(coeff[5])
    curve.setMinimumValueofx(min_x)
    curve.setMaximumValueofx(max_x)
    curve.setMinimumValueofy(min_y)
    curve.setMaximumValueofy(max_y)
    return curve
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param coeff [TODO] TODO
  # @param name [TODO] TODO
  # @param min_x [TODO] TODO
  # @param max_x [TODO] TODO
  # @param min_y [TODO] TODO
  # @param max_y [TODO] TODO
  # @return [TODO] TODO
  def self.create_curve_bicubic(model, coeff, name, min_x, max_x, min_y, max_y)
    curve = OpenStudio::Model::CurveBicubic.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2x(coeff[1])
    curve.setCoefficient3xPOW2(coeff[2])
    curve.setCoefficient4y(coeff[3])
    curve.setCoefficient5yPOW2(coeff[4])
    curve.setCoefficient6xTIMESY(coeff[5])
    curve.setCoefficient7xPOW3(coeff[6])
    curve.setCoefficient8yPOW3(coeff[7])
    curve.setCoefficient9xPOW2TIMESY(coeff[8])
    curve.setCoefficient10xTIMESYPOW2(coeff[9])
    curve.setMinimumValueofx(min_x)
    curve.setMaximumValueofx(max_x)
    curve.setMinimumValueofy(min_y)
    curve.setMaximumValueofy(max_y)
    return curve
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param coeff [TODO] TODO
  # @param name [TODO] TODO
  # @param min_x [TODO] TODO
  # @param max_x [TODO] TODO
  # @param min_y [TODO] TODO
  # @param max_y [TODO] TODO
  # @param is_dimensionless [TODO] TODO
  # @return [TODO] TODO
  def self.create_curve_quadratic(model, coeff, name, min_x, max_x, min_y, max_y, is_dimensionless = false)
    curve = OpenStudio::Model::CurveQuadratic.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2x(coeff[1])
    curve.setCoefficient3xPOW2(coeff[2])
    curve.setMinimumValueofx(min_x)
    curve.setMaximumValueofx(max_x)
    if not min_y.nil?
      curve.setMinimumCurveOutput(min_y)
    end
    if not max_y.nil?
      curve.setMaximumCurveOutput(max_y)
    end
    if is_dimensionless
      curve.setInputUnitTypeforX('Dimensionless')
      curve.setOutputUnitType('Dimensionless')
    end
    return curve
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param coeff [TODO] TODO
  # @param name [TODO] TODO
  # @return [TODO] TODO
  def self.create_curve_quad_linear(model, coeff, name)
    curve = OpenStudio::Model::CurveQuadLinear.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2w(coeff[1])
    curve.setCoefficient3x(coeff[2])
    curve.setCoefficient4y(coeff[3])
    curve.setCoefficient5z(coeff[4])
    return curve
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param coeff [TODO] TODO
  # @param name [TODO] TODO
  # @return [TODO] TODO
  def self.create_curve_quint_linear(model, coeff, name)
    curve = OpenStudio::Model::CurveQuintLinear.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2v(coeff[1])
    curve.setCoefficient3w(coeff[2])
    curve.setCoefficient4x(coeff[3])
    curve.setCoefficient5y(coeff[4])
    curve.setCoefficient6z(coeff[5])
    return curve
  end

  # TODO
  #
  # @param net_cap [TODO] TODO
  # @param fan_power [TODO] TODO
  # @param mode [TODO] TODO
  # @param net_cop [TODO] TODO
  # @return [TODO] TODO
  def self.convert_net_to_gross_capacity_cop(net_cap, fan_power, mode, net_cop = nil)
    net_cap_watts = UnitConversions.convert(net_cap, 'Btu/hr', 'w')
    if mode == :clg
      gross_cap_watts = net_cap_watts + fan_power
    else
      gross_cap_watts = net_cap_watts - fan_power
    end
    if not net_cop.nil?
      net_power = net_cap_watts / net_cop
      gross_power = net_power - fan_power
      gross_cop = gross_cap_watts / gross_power
    end
    gross_cap_btu_hr = UnitConversions.convert(gross_cap_watts, 'w', 'Btu/hr')
    return gross_cap_btu_hr, gross_cop
  end

  # TODO
  #
  # @param detailed_performance_data [TODO] TODO
  # @param hvac_ap [TODO] TODO
  # @param mode [TODO] TODO
  # @param max_rated_fan_cfm [TODO] TODO
  # @param weather_temp [TODO] TODO
  # @param compressor_lockout_temp [TODO] TODO
  # @return [TODO] TODO
  def self.process_neep_detailed_performance(detailed_performance_data, hvac_ap, mode, max_rated_fan_cfm, weather_temp, compressor_lockout_temp = nil)
    data_array = Array.new(2) { Array.new }
    detailed_performance_data.sort_by { |dp| dp.outdoor_temperature }.each do |data_point|
      # Only process min and max capacities at each outdoor drybulb
      next unless [HPXML::CapacityDescriptionMinimum, HPXML::CapacityDescriptionMaximum].include? data_point.capacity_description

      if data_point.capacity_description == HPXML::CapacityDescriptionMinimum
        data_array[0] << data_point
      elsif data_point.capacity_description == HPXML::CapacityDescriptionMaximum
        data_array[1] << data_point
      end
    end

    # convert net to gross, adds more data points for table lookup, etc.
    if mode == :clg
      cfm_per_ton = hvac_ap.cool_rated_cfm_per_ton
      hvac_ap.cooling_performance_data_array = data_array
      hvac_ap.cool_rated_capacities_gross = []
      hvac_ap.cool_rated_capacities_net = []
      hvac_ap.cool_rated_cops = []
    elsif mode == :htg
      cfm_per_ton = hvac_ap.heat_rated_cfm_per_ton
      hvac_ap.heating_performance_data_array = data_array
      hvac_ap.heat_rated_capacities_gross = []
      hvac_ap.heat_rated_capacities_net = []
      hvac_ap.heat_rated_cops = []
    end
    # convert net to gross
    data_array.each_with_index do |data, speed|
      data.each do |dp|
        this_cfm = UnitConversions.convert(dp.capacity, 'Btu/hr', 'ton') * cfm_per_ton[speed]
        fan_ratio = this_cfm / max_rated_fan_cfm
        fan_power = calculate_fan_power_from_curve(hvac_ap.fan_power_rated * max_rated_fan_cfm, fan_ratio)
        dp.gross_capacity, dp.gross_efficiency_cop = convert_net_to_gross_capacity_cop(dp.capacity, fan_power, mode, dp.efficiency_cop)
      end
    end
    # convert to table lookup data
    interpolate_to_odb_table_points(data_array, mode, compressor_lockout_temp, weather_temp)
    add_data_point_adaptive_step_size(data_array, mode)
    correct_ft_cap_eir(data_array, mode)
  end

  # TODO
  #
  # @param data_array [TODO] TODO
  # @param mode [TODO] TODO
  # @param compressor_lockout_temp [TODO] TODO
  # @param weather_temp [TODO] TODO
  # @return [TODO] TODO
  def self.interpolate_to_odb_table_points(data_array, mode, compressor_lockout_temp, weather_temp)
    # Set of data used for table lookup
    data_array.each do |data|
      user_odbs = data.map { |dp| dp.outdoor_temperature }
      # Determine min/max ODB temperatures to cover full range of heat pump operation
      if mode == :clg
        outdoor_dry_bulbs = []
        # Calculate ODB temperature at which COP or capacity is zero
        high_odb_at_zero_cop = calculate_odb_at_zero_cop_or_capacity(data, mode, user_odbs, :gross_efficiency_cop, true)
        high_odb_at_zero_capacity = calculate_odb_at_zero_cop_or_capacity(data, mode, user_odbs, :gross_capacity, true)
        low_odb_at_zero_cop = calculate_odb_at_zero_cop_or_capacity(data, mode, user_odbs, :gross_efficiency_cop, false)
        low_odb_at_zero_capacity = calculate_odb_at_zero_cop_or_capacity(data, mode, user_odbs, :gross_capacity, false)
        outdoor_dry_bulbs << [low_odb_at_zero_cop, low_odb_at_zero_capacity, 55.0].max # Min cooling ODB
        outdoor_dry_bulbs << [high_odb_at_zero_cop, high_odb_at_zero_capacity, weather_temp].min # Max cooling ODB
      else
        outdoor_dry_bulbs = []
        # Calculate ODB temperature at which COP or capacity is zero
        low_odb_at_zero_cop = calculate_odb_at_zero_cop_or_capacity(data, mode, user_odbs, :gross_efficiency_cop, false)
        low_odb_at_zero_capacity = calculate_odb_at_zero_cop_or_capacity(data, mode, user_odbs, :gross_capacity, false)
        high_odb_at_zero_cop = calculate_odb_at_zero_cop_or_capacity(data, mode, user_odbs, :gross_efficiency_cop, true)
        high_odb_at_zero_capacity = calculate_odb_at_zero_cop_or_capacity(data, mode, user_odbs, :gross_capacity, true)
        outdoor_dry_bulbs << [low_odb_at_zero_cop, low_odb_at_zero_capacity, compressor_lockout_temp, weather_temp].max # Min heating ODB
        outdoor_dry_bulbs << [high_odb_at_zero_cop, high_odb_at_zero_capacity, 60.0].min # Max heating ODB
      end
      capacity_description = data[0].capacity_description
      outdoor_dry_bulbs.each do |target_odb|
        next if user_odbs.include? target_odb

        if mode == :clg
          new_dp = HPXML::CoolingPerformanceDataPoint.new(nil)
        else
          new_dp = HPXML::HeatingPerformanceDataPoint.new(nil)
        end
        new_dp.outdoor_temperature = target_odb
        new_dp.gross_capacity = interpolate_to_odb_table_point(data, capacity_description, target_odb, :gross_capacity)
        new_dp.gross_efficiency_cop = interpolate_to_odb_table_point(data, capacity_description, target_odb, :gross_efficiency_cop)
        data << new_dp
      end
    end
  end

  # TODO
  #
  # @param data [TODO] TODO
  # @param _mode [TODO] TODO
  # @param user_odbs [TODO] TODO
  # @param property [TODO] TODO
  # @param find_high [TODO] TODO
  # @return [TODO] TODO
  def self.calculate_odb_at_zero_cop_or_capacity(data, _mode, user_odbs, property, find_high)
    if find_high
      odb_dp1 = data.find { |dp| dp.outdoor_temperature == user_odbs[-1] }
      odb_dp2 = data.find { |dp| dp.outdoor_temperature == user_odbs[-2] }
    else
      odb_dp1 = data.find { |dp| dp.outdoor_temperature == user_odbs[0] }
      odb_dp2 = data.find { |dp| dp.outdoor_temperature == user_odbs[1] }
    end

    slope = (odb_dp1.send(property) - odb_dp2.send(property)) / (odb_dp1.outdoor_temperature - odb_dp2.outdoor_temperature)

    # Datapoints don't trend toward zero COP?
    if (find_high && slope >= 0)
      return 999999.0
    elsif (!find_high && slope <= 0)
      return -999999.0
    end

    intercept = odb_dp2.send(property) - (slope * odb_dp2.outdoor_temperature)
    target_odb = -intercept / slope

    # Return a slightly larger (or smaller, for cooling) ODB so things don't blow up
    delta_odb = 1.0
    if find_high
      return target_odb - delta_odb
    else
      return target_odb + delta_odb
    end
  end

  # TODO
  #
  # @param detailed_performance_data [TODO] TODO
  # @param capacity_description [TODO] TODO
  # @param target_odb [TODO] TODO
  # @param property [TODO] TODO
  # @return [TODO] TODO
  def self.interpolate_to_odb_table_point(detailed_performance_data, capacity_description, target_odb, property)
    data = detailed_performance_data.select { |dp| dp.capacity_description == capacity_description }

    target_dp = data.find { |dp| dp.outdoor_temperature == target_odb }
    if not target_dp.nil?
      return target_dp.send(property)
    end

    # Property can be :capacity, :efficiency_cop, etc.
    user_odbs = data.map { |dp| dp.outdoor_temperature }.uniq.sort

    right_odb = user_odbs.find { |e| e > target_odb }
    left_odb = user_odbs.reverse.find { |e| e < target_odb }
    if right_odb.nil?
      # extrapolation
      right_odb = user_odbs[-1]
      left_odb = user_odbs[-2]
    elsif left_odb.nil?
      # extrapolation
      right_odb = user_odbs[1]
      left_odb = user_odbs[0]
    end
    right_dp = data.find { |dp| dp.outdoor_temperature == right_odb }
    left_dp = data.find { |dp| dp.outdoor_temperature == left_odb }

    slope = (right_dp.send(property) - left_dp.send(property)) / (right_odb - left_odb)
    val = (target_odb - left_odb) * slope + left_dp.send(property)
    return val
  end

  # TODO
  #
  # @param data_array [TODO] TODO
  # @param mode [TODO] TODO
  # @param tol [TODO] TODO
  # @return [TODO] TODO
  def self.add_data_point_adaptive_step_size(data_array, mode, tol = 0.1)
    data_array.each do |data|
      data_sorted = data.sort_by { |dp| dp.outdoor_temperature }
      data_sorted.each_with_index do |dp, i|
        next unless i < (data_sorted.size - 1)

        cap_diff = data_sorted[i + 1].gross_capacity - dp.gross_capacity
        odb_diff = data_sorted[i + 1].outdoor_temperature - dp.outdoor_temperature
        cop_diff = data_sorted[i + 1].gross_efficiency_cop - dp.gross_efficiency_cop
        if mode == :clg
          eir_rated = 1 / data_sorted.find { |dp| dp.outdoor_temperature == HVAC::AirSourceCoolRatedODB }.gross_efficiency_cop
        else
          eir_rated = 1 / data_sorted.find { |dp| dp.outdoor_temperature == HVAC::AirSourceHeatRatedODB }.gross_efficiency_cop
        end
        eir_diff = ((1 / data_sorted[i + 1].gross_efficiency_cop) / eir_rated) - ((1 / dp.gross_efficiency_cop) / eir_rated)
        n_pt = (eir_diff.abs / tol).ceil() - 1
        eir_interval = eir_diff / (n_pt + 1)
        next if n_pt < 1

        for i in 1..n_pt
          if mode == :clg
            new_dp = HPXML::CoolingPerformanceDataPoint.new(nil)
          else
            new_dp = HPXML::HeatingPerformanceDataPoint.new(nil)
          end
          new_eir_normalized = (1 / dp.gross_efficiency_cop) / eir_rated + eir_interval * i
          new_dp.gross_efficiency_cop = (1 / (new_eir_normalized * eir_rated))
          new_dp.outdoor_temperature = odb_diff / cop_diff * (new_dp.gross_efficiency_cop - dp.gross_efficiency_cop) + dp.outdoor_temperature
          new_dp.gross_capacity = cap_diff / odb_diff * (new_dp.outdoor_temperature - dp.outdoor_temperature) + dp.gross_capacity
          data << new_dp
        end
      end
    end
  end

  # TODO
  #
  # @param data_array [TODO] TODO
  # @param mode [TODO] TODO
  # @return [TODO] TODO
  def self.correct_ft_cap_eir(data_array, mode)
    # Add sensitivity to indoor conditions
    # single speed cutler curve coefficients
    if mode == :clg
      cap_ft_spec_ss, eir_ft_spec_ss = get_cool_cap_eir_ft_spec(HPXML::HVACCompressorTypeSingleStage)
      rated_t_i = HVAC::AirSourceCoolRatedIWB
      indoor_t = [50.0, rated_t_i, 80.0]
    else
      # default capacity retention for single speed
      retention_temp, retention_fraction = get_default_heating_capacity_retention(HPXML::HVACCompressorTypeSingleStage)
      cap_ft_spec_ss, eir_ft_spec_ss = get_heat_cap_eir_ft_spec(HPXML::HVACCompressorTypeSingleStage, retention_temp, retention_fraction)
      rated_t_i = HVAC::AirSourceHeatRatedIDB
      indoor_t = [60.0, rated_t_i, 80.0]
    end
    data_array.each do |data|
      data.each do |dp|
        if mode == :clg
          dp.indoor_wetbulb = rated_t_i
        else
          dp.indoor_temperature = rated_t_i
        end
      end
    end
    # table lookup output values
    data_array.each do |data|
      # create a new array to temporarily store expanded data points, to concat after the existing data loop
      array_tmp = Array.new
      indoor_t.each do |t_i|
        # introduce indoor conditions other than rated, expand to rated data points
        next if t_i == rated_t_i

        data_tmp = Array.new
        data.each do |dp|
          dp_new = dp.dup
          data_tmp << dp_new
          if mode == :clg
            dp_new.indoor_wetbulb = t_i
          else
            dp_new.indoor_temperature = t_i
          end
          # capacity FT curve output
          cap_ft_curve_output = MathTools.biquadratic(t_i, dp_new.outdoor_temperature, cap_ft_spec_ss[0])
          cap_ft_curve_output_rated = MathTools.biquadratic(rated_t_i, dp_new.outdoor_temperature, cap_ft_spec_ss[0])
          cap_correction_factor = cap_ft_curve_output / cap_ft_curve_output_rated
          # corrected capacity hash, with two temperature independent variables
          dp_new.gross_capacity *= cap_correction_factor

          # eir FT curve output
          eir_ft_curve_output = MathTools.biquadratic(t_i, dp_new.outdoor_temperature, eir_ft_spec_ss[0])
          eir_ft_curve_output_rated = MathTools.biquadratic(rated_t_i, dp_new.outdoor_temperature, eir_ft_spec_ss[0])
          eir_correction_factor = eir_ft_curve_output / eir_ft_curve_output_rated
          dp_new.gross_efficiency_cop /= eir_correction_factor
        end
        array_tmp << data_tmp
      end
      array_tmp.each do |new_data|
        data.concat(new_data)
      end
    end
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param obj_name [String] Name for the OpenStudio object
  # @param cooling_system [TODO] TODO
  # @param max_rated_fan_cfm [TODO] TODO
  # @param weather_max_drybulb [TODO] TODO
  # @param is_ddb_control [Boolean] Whether to apply on off thermostat deadband
  # @return [TODO] TODO
  def self.create_dx_cooling_coil(model, obj_name, cooling_system, max_rated_fan_cfm, weather_max_drybulb, is_ddb_control = false)
    clg_ap = cooling_system.additional_properties

    if cooling_system.is_a? HPXML::CoolingSystem
      clg_type = cooling_system.cooling_system_type
    elsif cooling_system.is_a? HPXML::HeatPump
      clg_type = cooling_system.heat_pump_type
    end

    if cooling_system.cooling_detailed_performance_data.empty?
      max_clg_cfm = UnitConversions.convert(cooling_system.cooling_capacity * clg_ap.cool_capacity_ratios[-1], 'Btu/hr', 'ton') * clg_ap.cool_rated_cfm_per_ton[-1]
      clg_ap.cool_rated_capacities_gross = []
      clg_ap.cool_rated_capacities_net = []
      clg_ap.cool_capacity_ratios.each_with_index do |capacity_ratio, speed|
        fan_ratio = clg_ap.cool_fan_speed_ratios[speed] * max_clg_cfm / max_rated_fan_cfm
        fan_power = calculate_fan_power_from_curve(clg_ap.fan_power_rated * max_rated_fan_cfm, fan_ratio)
        net_capacity = capacity_ratio * cooling_system.cooling_capacity
        clg_ap.cool_rated_capacities_net << net_capacity
        gross_capacity = convert_net_to_gross_capacity_cop(net_capacity, fan_power, :clg)[0]
        clg_ap.cool_rated_capacities_gross << gross_capacity
      end
    else
      process_neep_detailed_performance(cooling_system.cooling_detailed_performance_data, clg_ap, :clg, max_rated_fan_cfm, weather_max_drybulb)
    end

    clg_coil = nil
    coil_name = obj_name + ' clg coil'
    num_speeds = clg_ap.cool_rated_cfm_per_ton.size
    for i in 0..(num_speeds - 1)
      if not cooling_system.cooling_detailed_performance_data.empty?
        speed_performance_data = clg_ap.cooling_performance_data_array[i].sort_by { |dp| [dp.indoor_wetbulb, dp.outdoor_temperature] }
        var_wb = { name: 'wet_bulb_temp_in', min: -100, max: 100, values: speed_performance_data.map { |dp| UnitConversions.convert(dp.indoor_wetbulb, 'F', 'C') }.uniq }
        var_db = { name: 'dry_bulb_temp_out', min: -100, max: 100, values: speed_performance_data.map { |dp| UnitConversions.convert(dp.outdoor_temperature, 'F', 'C') }.uniq }
        cap_ft_independent_vars = [var_wb, var_db]
        eir_ft_independent_vars = [var_wb, var_db]

        rate_dp = speed_performance_data.find { |dp| (dp.indoor_wetbulb == HVAC::AirSourceCoolRatedIWB) && (dp.outdoor_temperature == HVAC::AirSourceCoolRatedODB) }
        clg_ap.cool_rated_cops << rate_dp.gross_efficiency_cop
        clg_ap.cool_rated_capacities_gross << rate_dp.gross_capacity
        clg_ap.cool_rated_capacities_net << rate_dp.capacity
        cap_ft_output_values = speed_performance_data.map { |dp| dp.gross_capacity / rate_dp.gross_capacity }
        eir_ft_output_values = speed_performance_data.map { |dp| (1.0 / dp.gross_efficiency_cop) / (1.0 / rate_dp.gross_efficiency_cop) }
        cap_ft_curve = create_table_lookup(model, "Cool-CAP-fT#{i + 1}", cap_ft_independent_vars, cap_ft_output_values, 0.0)
        eir_ft_curve = create_table_lookup(model, "Cool-EIR-fT#{i + 1}", eir_ft_independent_vars, eir_ft_output_values, 0.0)
      else
        cap_ft_spec_si = convert_curve_biquadratic(clg_ap.cool_cap_ft_spec[i])
        eir_ft_spec_si = convert_curve_biquadratic(clg_ap.cool_eir_ft_spec[i])
        cap_ft_curve = create_curve_biquadratic(model, cap_ft_spec_si, "Cool-CAP-fT#{i + 1}", -100, 100, -100, 100)
        eir_ft_curve = create_curve_biquadratic(model, eir_ft_spec_si, "Cool-EIR-fT#{i + 1}", -100, 100, -100, 100)
      end
      cap_fff_curve = create_curve_quadratic(model, clg_ap.cool_cap_fflow_spec[i], "Cool-CAP-fFF#{i + 1}", 0, 2, 0, 2)
      eir_fff_curve = create_curve_quadratic(model, clg_ap.cool_eir_fflow_spec[i], "Cool-EIR-fFF#{i + 1}", 0, 2, 0, 2)
      if i == 0
        cap_fff_curve_0 = cap_fff_curve
        eir_fff_curve_0 = eir_fff_curve
      end
      if is_ddb_control
        # Zero out impact of part load ratio
        plf_fplr_curve = create_curve_quadratic(model, [1.0, 0.0, 0.0], "Cool-PLF-fPLR#{i + 1}", 0, 1, 0.7, 1)
      else
        plf_fplr_curve = create_curve_quadratic(model, clg_ap.cool_plf_fplr_spec[i], "Cool-PLF-fPLR#{i + 1}", 0, 1, 0.7, 1)
      end

      if num_speeds == 1
        clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule, cap_ft_curve, cap_fff_curve, eir_ft_curve, eir_fff_curve, plf_fplr_curve)
        # Coil COP calculation based on system type
        if [HPXML::HVACTypeRoomAirConditioner, HPXML::HVACTypePTAC, HPXML::HVACTypeHeatPumpPTHP, HPXML::HVACTypeHeatPumpRoom].include? clg_type
          if cooling_system.cooling_efficiency_ceer.nil?
            ceer = calc_ceer_from_eer(cooling_system)
          else
            ceer = cooling_system.cooling_efficiency_ceer
          end
          clg_coil.setRatedCOP(UnitConversions.convert(ceer, 'Btu/hr', 'W'))
        else
          clg_coil.setRatedCOP(clg_ap.cool_rated_cops[i])
        end
        clg_coil.setMaximumOutdoorDryBulbTemperatureForCrankcaseHeaterOperation(UnitConversions.convert(CrankcaseHeaterTemp, 'F', 'C')) if cooling_system.crankcase_heater_watts.to_f > 0.0 # From RESNET Publication No. 002-2017
        clg_coil.setRatedSensibleHeatRatio(clg_ap.cool_rated_shrs_gross[i])
        clg_coil.setNominalTimeForCondensateRemovalToBegin(1000.0)
        clg_coil.setRatioOfInitialMoistureEvaporationRateAndSteadyStateLatentCapacity(1.5)
        clg_coil.setMaximumCyclingRate(3.0)
        clg_coil.setLatentCapacityTimeConstant(45.0)
        clg_coil.setRatedTotalCoolingCapacity(UnitConversions.convert(clg_ap.cool_rated_capacities_gross[i], 'Btu/hr', 'W'))
        clg_coil.setRatedAirFlowRate(calc_rated_airflow(clg_ap.cool_rated_capacities_net[i], clg_ap.cool_rated_cfm_per_ton[0]))
      else
        if clg_coil.nil?
          clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
          clg_coil.setApplyPartLoadFractiontoSpeedsGreaterthan1(false)
          clg_coil.setApplyLatentDegradationtoSpeedsGreaterthan1(false)
          clg_coil.setFuelType(EPlus::FuelTypeElectricity)
          clg_coil.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
          clg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(UnitConversions.convert(CrankcaseHeaterTemp, 'F', 'C')) if cooling_system.crankcase_heater_watts.to_f > 0.0 # From RESNET Publication No. 002-2017
          constant_biquadratic = create_curve_biquadratic_constant(model)
        end
        stage = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model, cap_ft_curve, cap_fff_curve, eir_ft_curve, eir_fff_curve, plf_fplr_curve, constant_biquadratic)
        stage.setGrossRatedCoolingCOP(clg_ap.cool_rated_cops[i])
        stage.setGrossRatedSensibleHeatRatio(clg_ap.cool_rated_shrs_gross[i])
        stage.setNominalTimeforCondensateRemovaltoBegin(1000)
        stage.setRatioofInitialMoistureEvaporationRateandSteadyStateLatentCapacity(1.5)
        stage.setRatedWasteHeatFractionofPowerInput(0.2)
        stage.setMaximumCyclingRate(3.0)
        stage.setLatentCapacityTimeConstant(45.0)
        stage.setGrossRatedTotalCoolingCapacity(UnitConversions.convert(clg_ap.cool_rated_capacities_gross[i], 'Btu/hr', 'W'))
        stage.setRatedAirFlowRate(calc_rated_airflow(clg_ap.cool_rated_capacities_net[i], clg_ap.cool_rated_cfm_per_ton[i]))
        clg_coil.addStage(stage)
      end
    end

    clg_coil.setName(coil_name)
    clg_coil.setCondenserType('AirCooled')
    clg_coil.setCrankcaseHeaterCapacity(cooling_system.crankcase_heater_watts)
    clg_coil.additionalProperties.setFeature('HPXML_ID', cooling_system.id) # Used by reporting measure
    if is_ddb_control
      # Apply startup capacity degradation
      apply_capacity_degradation_EMS(model, clg_ap, clg_coil.name.get, true, cap_fff_curve_0, eir_fff_curve_0)
    end

    return clg_coil
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param obj_name [String] Name for the OpenStudio object
  # @param heating_system [TODO] TODO
  # @param max_rated_fan_cfm [TODO] TODO
  # @param weather_min_drybulb [TODO] TODO
  # @param defrost_model_type [TODO] TODO
  # @param p_dot_defrost [TODO] TODO
  # @param is_ddb_control [Boolean] Whether to apply on off thermostat deadband
  # @return [TODO] TODO
  def self.create_dx_heating_coil(model, obj_name, heating_system, max_rated_fan_cfm, weather_min_drybulb, defrost_model_type, p_dot_defrost, is_ddb_control = false)
    htg_ap = heating_system.additional_properties

    if heating_system.heating_detailed_performance_data.empty?
      max_htg_cfm = UnitConversions.convert(heating_system.heating_capacity * htg_ap.heat_capacity_ratios[-1], 'Btu/hr', 'ton') * htg_ap.heat_rated_cfm_per_ton[-1]
      htg_ap.heat_rated_capacities_gross = []
      htg_ap.heat_rated_capacities_net = []
      htg_ap.heat_capacity_ratios.each_with_index do |capacity_ratio, speed|
        fan_ratio = htg_ap.heat_fan_speed_ratios[speed] * max_htg_cfm / max_rated_fan_cfm
        fan_power = calculate_fan_power_from_curve(htg_ap.fan_power_rated * max_rated_fan_cfm, fan_ratio)
        net_capacity = capacity_ratio * heating_system.heating_capacity
        htg_ap.heat_rated_capacities_net << net_capacity
        gross_capacity = convert_net_to_gross_capacity_cop(net_capacity, fan_power, :htg)[0]
        htg_ap.heat_rated_capacities_gross << gross_capacity
      end
    else
      process_neep_detailed_performance(heating_system.heating_detailed_performance_data, htg_ap, :htg, max_rated_fan_cfm, weather_min_drybulb, htg_ap.hp_min_temp)
    end

    htg_coil = nil
    coil_name = obj_name + ' htg coil'

    num_speeds = htg_ap.heat_rated_cfm_per_ton.size
    for i in 0..(num_speeds - 1)
      if not heating_system.heating_detailed_performance_data.empty?
        speed_performance_data = htg_ap.heating_performance_data_array[i].sort_by { |dp| [dp.indoor_temperature, dp.outdoor_temperature] }
        var_idb = { name: 'dry_bulb_temp_in', min: -100, max: 100, values: speed_performance_data.map { |dp| UnitConversions.convert(dp.indoor_temperature, 'F', 'C') }.uniq }
        var_odb = { name: 'dry_bulb_temp_out', min: -100, max: 100, values: speed_performance_data.map { |dp| UnitConversions.convert(dp.outdoor_temperature, 'F', 'C') }.uniq }
        cap_ft_independent_vars = [var_idb, var_odb]
        eir_ft_independent_vars = [var_idb, var_odb]

        rate_dp = speed_performance_data.find { |dp| (dp.indoor_temperature == HVAC::AirSourceHeatRatedIDB) && (dp.outdoor_temperature == HVAC::AirSourceHeatRatedODB) }
        htg_ap.heat_rated_cops << rate_dp.gross_efficiency_cop
        htg_ap.heat_rated_capacities_net << rate_dp.capacity
        htg_ap.heat_rated_capacities_gross << rate_dp.gross_capacity
        cap_ft_output_values = speed_performance_data.map { |dp| dp.gross_capacity / rate_dp.gross_capacity }
        eir_ft_output_values = speed_performance_data.map { |dp| (1.0 / dp.gross_efficiency_cop) / (1.0 / rate_dp.gross_efficiency_cop) }
        cap_ft_curve = create_table_lookup(model, "Heat-CAP-fT#{i + 1}", cap_ft_independent_vars, cap_ft_output_values, 0)
        eir_ft_curve = create_table_lookup(model, "Heat-EIR-fT#{i + 1}", eir_ft_independent_vars, eir_ft_output_values, 0)
      else
        cap_ft_spec_si = convert_curve_biquadratic(htg_ap.heat_cap_ft_spec[i])
        eir_ft_spec_si = convert_curve_biquadratic(htg_ap.heat_eir_ft_spec[i])
        cap_ft_curve = create_curve_biquadratic(model, cap_ft_spec_si, "Heat-CAP-fT#{i + 1}", -100, 100, -100, 100)
        eir_ft_curve = create_curve_biquadratic(model, eir_ft_spec_si, "Heat-EIR-fT#{i + 1}", -100, 100, -100, 100)
      end
      cap_fff_curve = create_curve_quadratic(model, htg_ap.heat_cap_fflow_spec[i], "Heat-CAP-fFF#{i + 1}", 0, 2, 0, 2)
      eir_fff_curve = create_curve_quadratic(model, htg_ap.heat_eir_fflow_spec[i], "Heat-EIR-fFF#{i + 1}", 0, 2, 0, 2)
      if i == 0
        cap_fff_curve_0 = cap_fff_curve
        eir_fff_curve_0 = eir_fff_curve
      end
      if is_ddb_control
        # Zero out impact of part load ratio
        plf_fplr_curve = create_curve_quadratic(model, [1.0, 0.0, 0.0], "Heat-PLF-fPLR#{i + 1}", 0, 1, 0.7, 1)
      else
        plf_fplr_curve = create_curve_quadratic(model, htg_ap.heat_plf_fplr_spec[i], "Heat-PLF-fPLR#{i + 1}", 0, 1, 0.7, 1)
      end

      if num_speeds == 1
        htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule, cap_ft_curve, cap_fff_curve, eir_ft_curve, eir_fff_curve, plf_fplr_curve)
        if heating_system.heating_efficiency_cop.nil?
          htg_coil.setRatedCOP(htg_ap.heat_rated_cops[i])
        else # PTHP or room heat pump
          htg_coil.setRatedCOP(heating_system.heating_efficiency_cop)
        end
        htg_coil.setRatedTotalHeatingCapacity(UnitConversions.convert(htg_ap.heat_rated_capacities_gross[i], 'Btu/hr', 'W'))
        htg_coil.setRatedAirFlowRate(calc_rated_airflow(htg_ap.heat_rated_capacities_net[i], htg_ap.heat_rated_cfm_per_ton[0]))
        defrost_time_fraction = 0.1 if defrost_model_type == HPXML::AdvancedResearchDefrostModelTypeAdvanced # 6min/hr
      else
        if htg_coil.nil?
          htg_coil = OpenStudio::Model::CoilHeatingDXMultiSpeed.new(model)
          htg_coil.setFuelType(EPlus::FuelTypeElectricity)
          htg_coil.setApplyPartLoadFractiontoSpeedsGreaterthan1(false)
          htg_coil.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
          constant_biquadratic = create_curve_biquadratic_constant(model)
        end
        stage = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model, cap_ft_curve, cap_fff_curve, eir_ft_curve, eir_fff_curve, plf_fplr_curve, constant_biquadratic)
        stage.setGrossRatedHeatingCOP(htg_ap.heat_rated_cops[i])
        stage.setRatedWasteHeatFractionofPowerInput(0.2)
        stage.setGrossRatedHeatingCapacity(UnitConversions.convert(htg_ap.heat_rated_capacities_gross[i], 'Btu/hr', 'W'))
        stage.setRatedAirFlowRate(calc_rated_airflow(htg_ap.heat_rated_capacities_net[i], htg_ap.heat_rated_cfm_per_ton[i]))
        htg_coil.addStage(stage)
        defrost_time_fraction = 0.06667 if defrost_model_type == HPXML::AdvancedResearchDefrostModelTypeAdvanced # 4min/hr
      end
    end

    htg_coil.setName(coil_name)
    htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(UnitConversions.convert(htg_ap.hp_min_temp, 'F', 'C'))
    htg_coil.setMaximumOutdoorDryBulbTemperatureforDefrostOperation(UnitConversions.convert(40.0, 'F', 'C'))
    htg_coil.setDefrostControl('Timed')
    if defrost_model_type == HPXML::AdvancedResearchDefrostModelTypeAdvanced
      htg_coil.setDefrostStrategy('Resistive')
      htg_coil.setDefrostTimePeriodFraction(defrost_time_fraction)
      htg_coil.setResistiveDefrostHeaterCapacity(p_dot_defrost)
    elsif defrost_model_type == HPXML::AdvancedResearchDefrostModelTypeStandard
      defrost_eir_curve = create_curve_biquadratic(model, [0.1528, 0, 0, 0, 0, 0], 'Defrosteir', -100, 100, -100, 100) # Heating defrost curve for reverse cycle
      htg_coil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(defrost_eir_curve)
      htg_coil.setDefrostStrategy('ReverseCycle')
    else
      fail 'unknown defrost model type.'
    end
    if heating_system.fraction_heat_load_served == 0
      htg_coil.setResistiveDefrostHeaterCapacity(0)
    end
    htg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(UnitConversions.convert(CrankcaseHeaterTemp, 'F', 'C')) if heating_system.crankcase_heater_watts.to_f > 0.0 # From RESNET Publication No. 002-2017
    htg_coil.setCrankcaseHeaterCapacity(heating_system.crankcase_heater_watts)
    htg_coil.additionalProperties.setFeature('HPXML_ID', heating_system.id) # Used by reporting measure
    if is_ddb_control
      # Apply startup capacity degradation
      apply_capacity_degradation_EMS(model, htg_ap, htg_coil.name.get, false, cap_fff_curve_0, eir_fff_curve_0)
    end

    return htg_coil
  end

  # TODO
  #
  # @param cooling_system [TODO] TODO
  # @return [TODO] TODO
  def self.set_cool_rated_shrs_gross(cooling_system)
    clg_ap = cooling_system.additional_properties

    if ((cooling_system.is_a? HPXML::CoolingSystem) && ([HPXML::HVACTypeRoomAirConditioner, HPXML::HVACTypePTAC].include? cooling_system.cooling_system_type)) ||
       ((cooling_system.is_a? HPXML::HeatPump) && ([HPXML::HVACTypeHeatPumpPTHP, HPXML::HVACTypeHeatPumpRoom].include? cooling_system.heat_pump_type))
      clg_ap.cool_rated_shrs_gross = [cooling_system.cooling_shr] # We don't model the fan separately, so set gross == net
    else
      # rated shr gross and fan speed ratios
      dB_rated = 80.0 # F
      win = 0.01118470 # Humidity ratio corresponding to 80F dry bulb/67F wet bulb (from EnergyPlus)

      if cooling_system.compressor_type == HPXML::HVACCompressorTypeSingleStage
        cool_nominal_cfm_per_ton = clg_ap.cool_rated_cfm_per_ton[0]
      else
        cool_nominal_cfm_per_ton = (clg_ap.cool_rated_airflow_rate - clg_ap.cool_rated_cfm_per_ton[0] * clg_ap.cool_capacity_ratios[0]) / (clg_ap.cool_capacity_ratios[-1] - clg_ap.cool_capacity_ratios[0]) * (1.0 - clg_ap.cool_capacity_ratios[0]) + clg_ap.cool_rated_cfm_per_ton[0] * clg_ap.cool_capacity_ratios[0]
      end

      p_atm = UnitConversions.convert(1, 'atm', 'psi')

      ao = Psychrometrics.CoilAoFactor(dB_rated, p_atm, UnitConversions.convert(1, 'ton', 'kBtu/hr'), cool_nominal_cfm_per_ton, cooling_system.cooling_shr, win)

      clg_ap.cool_rated_shrs_gross = []
      clg_ap.cool_capacity_ratios.each_with_index do |capacity_ratio, i|
        # Calculate the SHR for each speed. Use maximum value of 0.98 to prevent E+ bypass factor calculation errors
        clg_ap.cool_rated_shrs_gross << [Psychrometrics.CalculateSHR(dB_rated, p_atm, UnitConversions.convert(capacity_ratio, 'ton', 'kBtu/hr'), clg_ap.cool_rated_cfm_per_ton[i] * capacity_ratio, ao, win), 0.98].min
      end
    end
  end

  # Return the time needed to reach full capacity based on c_d assumption, used for degradation EMS program.
  #
  # @param c_d [Float] Degradation coefficient
  # @return [Float] Time to reach full capacity (minutes)
  def self.calc_time_to_full_cap(c_d)
    # assuming a linear relationship between points we have data for: 2 minutes at 0.08 and 5 minutes at 0.23
    time = (20.0 * c_d + 0.4).round
    time = [time, get_time_to_full_cap_limits[0]].max
    time = [time, get_time_to_full_cap_limits[1]].min
    return time
  end

  # Return min and max limit to time needed to reach full capacity
  #
  # @return [Array<Integer, Integer>] Minimum and maximum time to reach full capacity (minutes)
  def self.get_time_to_full_cap_limits()
    return [2, 5]
  end

  # Return the EMS actuator and EMS global variable for backup coil availability schedule.
  # This is called every time EMS uses this actuator to avoid conflicts across different EMS programs.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param htg_supp_coil [OpenStudio::Model::CoilHeatingElectric or OpenStudio::Model::CoilHeatingElectricMultiStage] OpenStudio Supplemental Heating Coil object
  # @return [Array<OpenStudio::Model::EnergyManagementSystemActuator, OpenStudio::Model::EnergyManagementSystemGlobalVariable>] OpenStudio EMS Actuator and Global Variable objects for supplemental coil availability schedule
  def self.get_supp_coil_avail_sch_actuator(model, htg_supp_coil)
    actuator = model.getEnergyManagementSystemActuators.find { |act| act.name.get.include? htg_supp_coil.availabilitySchedule.name.get.gsub(' ', '_') }
    global_var_supp_avail = model.getEnergyManagementSystemGlobalVariables.find { |var| var.name.get.include? htg_supp_coil.name.get.gsub(' ', '_') }

    return actuator, global_var_supp_avail unless actuator.nil?

    # No actuator for current backup coil availability schedule
    # Create a new schedule for supp availability
    # Make sure only being called once in case of multiple cloning
    supp_avail_sch = htg_supp_coil.availabilitySchedule.clone.to_ScheduleConstant.get
    supp_avail_sch.setName("#{htg_supp_coil.name} avail sch")
    htg_supp_coil.setAvailabilitySchedule(supp_avail_sch)

    supp_coil_avail_act = OpenStudio::Model::EnergyManagementSystemActuator.new(htg_supp_coil.availabilitySchedule, *EPlus::EMSActuatorScheduleConstantValue)
    supp_coil_avail_act.setName(htg_supp_coil.availabilitySchedule.name.get.gsub(' ', '_') + ' act')

    # global variable to integrate different EMS program actuating the same schedule
    global_var_supp_avail = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{htg_supp_coil.name.get.gsub(' ', '_') + '_avail_global'}")
    global_var_supp_avail_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    global_var_supp_avail_program.setName("#{global_var_supp_avail.name} init program")
    global_var_supp_avail_program.addLine("Set #{global_var_supp_avail.name} = 1")
    manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    manager.setName("#{global_var_supp_avail_program.name} calling manager")
    manager.setCallingPoint('BeginZoneTimestepBeforeInitHeatBalance')
    manager.addProgram(global_var_supp_avail_program)
    return supp_coil_avail_act, global_var_supp_avail
  end

  # Apply EMS program to control back up coil behavior when single speed system is modeled with on-off thermostat feature.
  # Back up coil is turned on after 5 mins that heat pump is not able to maintain setpoints.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param htg_supp_coil [OpenStudio::Model::CoilHeatingElectric or OpenStudio::Model::CoilHeatingElectricMultiStage] OpenStudio Supplemental Heating Coil object
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param htg_coil [OpenStudio::Model::CoilHeatingDXSingleSpeed or OpenStudio::Model::CoilHeatingDXMultiSpeed] OpenStudio Heating Coil object
  # @param is_onoff_thermostat_ddb [Boolean] Whether to apply on off thermostat deadband
  # @param cooling_system [HPXML::CoolingSystem or HPXML::HeatPump] HPXML Cooling System or HPXML Heat Pump object
  # @return [void]
  def self.apply_supp_coil_EMS_for_ddb_thermostat(model, htg_supp_coil, control_zone, htg_coil, is_onoff_thermostat_ddb, cooling_system)
    return if htg_supp_coil.nil?
    return unless cooling_system.compressor_type == HPXML::HVACCompressorTypeSingleStage
    return unless is_onoff_thermostat_ddb
    return if htg_supp_coil.is_a? OpenStudio::Model::CoilHeatingElectricMultiStage

    # Sensors
    tin_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Mean Air Temperature')
    tin_sensor.setName('zone air temp')
    tin_sensor.setKeyName(control_zone.name.to_s)

    htg_sch = control_zone.thermostatSetpointDualSetpoint.get.heatingSetpointTemperatureSchedule.get
    htg_sp_ss = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
    htg_sp_ss.setName('htg_setpoint')
    htg_sp_ss.setKeyName(htg_sch.name.to_s)

    supp_coil_energy = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Heating Coil Electricity Energy')
    supp_coil_energy.setName('supp coil electric energy')
    supp_coil_energy.setKeyName(htg_supp_coil.name.get)

    htg_coil_energy = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Heating Coil Electricity Energy')
    htg_coil_energy.setName('hp htg coil electric energy')
    htg_coil_energy.setKeyName(htg_coil.name.get)

    # Trend variable
    supp_energy_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, supp_coil_energy)
    supp_energy_trend.setName("#{supp_coil_energy.name} Trend")
    supp_energy_trend.setNumberOfTimestepsToBeLogged(1)

    # Trend variable
    htg_energy_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, htg_coil_energy)
    htg_energy_trend.setName("#{htg_coil_energy.name} Trend")
    htg_energy_trend.setNumberOfTimestepsToBeLogged(5)

    # Actuators
    supp_coil_avail_act, global_var_supp_avail = get_supp_coil_avail_sch_actuator(model, htg_supp_coil)

    ddb = model.getThermostatSetpointDualSetpoints[0].temperatureDifferenceBetweenCutoutAndSetpoint
    # Program
    supp_coil_avail_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    supp_coil_avail_program.setName("#{htg_supp_coil.name.get} control program")
    supp_coil_avail_program.addLine("If #{global_var_supp_avail.name} == 0") # Other EMS set it to be 0.0, keep the logic
    supp_coil_avail_program.addLine("  Set #{supp_coil_avail_act.name} = 0")
    supp_coil_avail_program.addLine('Else') # global variable = 1
    supp_coil_avail_program.addLine("  Set living_t = #{tin_sensor.name}")
    supp_coil_avail_program.addLine("  Set htg_sp_l = #{htg_sp_ss.name}")
    supp_coil_avail_program.addLine("  Set htg_sp_h = #{htg_sp_ss.name} + #{ddb}")
    supp_coil_avail_program.addLine("  If (@TRENDVALUE #{supp_energy_trend.name} 1) > 0") # backup coil is turned on, keep it on until reaching upper end of ddb in case of high frequency oscillations

    supp_coil_avail_program.addLine('    If living_t > htg_sp_h')
    supp_coil_avail_program.addLine("      Set #{global_var_supp_avail.name} = 0")
    supp_coil_avail_program.addLine("      Set #{supp_coil_avail_act.name} = 0")
    supp_coil_avail_program.addLine('    Else')
    supp_coil_avail_program.addLine("      Set #{supp_coil_avail_act.name} = 1")
    supp_coil_avail_program.addLine('    EndIf')
    supp_coil_avail_program.addLine('  Else') # Only turn on the backup coil when temprature is below lower end of ddb.
    r_s_a = ["#{htg_energy_trend.name} > 0"]
    # Observe 5 mins before turning on supp coil
    for t_i in 1..4
      r_s_a << "(@TrendValue #{htg_energy_trend.name} #{t_i}) > 0"
    end
    supp_coil_avail_program.addLine("    If #{r_s_a.join(' && ')}")
    supp_coil_avail_program.addLine('      If living_t > htg_sp_l')
    supp_coil_avail_program.addLine("        Set #{global_var_supp_avail.name} = 0")
    supp_coil_avail_program.addLine("        Set #{supp_coil_avail_act.name} = 0")
    supp_coil_avail_program.addLine('      Else')
    supp_coil_avail_program.addLine("        Set #{supp_coil_avail_act.name} = 1")
    supp_coil_avail_program.addLine('      EndIf')
    supp_coil_avail_program.addLine('    Else')
    supp_coil_avail_program.addLine("      Set #{global_var_supp_avail.name} = 0")
    supp_coil_avail_program.addLine("      Set #{supp_coil_avail_act.name} = 0")
    supp_coil_avail_program.addLine('    EndIf')
    supp_coil_avail_program.addLine('  EndIf')
    supp_coil_avail_program.addLine('EndIf')

    # ProgramCallingManagers
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName("#{supp_coil_avail_program.name} ProgramManager")
    program_calling_manager.setCallingPoint('InsideHVACSystemIterationLoop')
    program_calling_manager.addProgram(supp_coil_avail_program)
  end

  # Apply capacity degradation EMS to account for realistic start-up losses.
  # Capacity function of airflow rate curve and EIR function of airflow rate curve are actuated to
  # capture the impact of start-up losses.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param system_ap [HPXML::AdditionalProperties] HPXML Cooling System or HPXML Heating System Additional Properties
  # @param coil_name [String] Cooling or heating coil name
  # @param is_cooling [Boolean] True if apply to cooling system
  # @param cap_fff_curve [OpenStudio::Model::CurveQuadratic] OpenStudio CurveQuadratic object for heat pump capacity function of air flow rates
  # @param eir_fff_curve [OpenStudio::Model::CurveQuadratic] OpenStudio CurveQuadratic object for heat pump eir function of air flow rates
  # @return [void]
  def self.apply_capacity_degradation_EMS(model, system_ap, coil_name, is_cooling, cap_fff_curve, eir_fff_curve)
    # Note: Currently only available in 1 min time step
    if is_cooling
      c_d = system_ap.cool_c_d
      cap_fflow_spec = system_ap.cool_cap_fflow_spec[0]
      eir_fflow_spec = system_ap.cool_eir_fflow_spec[0]
      ss_var_name = 'Cooling Coil Electricity Energy'
    else
      c_d = system_ap.heat_c_d
      cap_fflow_spec = system_ap.heat_cap_fflow_spec[0]
      eir_fflow_spec = system_ap.heat_eir_fflow_spec[0]
      ss_var_name = 'Heating Coil Electricity Energy'
    end
    number_of_timestep_logged = calc_time_to_full_cap(c_d)

    # Sensors
    cap_curve_var_in = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 1 Value')
    cap_curve_var_in.setName("#{cap_fff_curve.name.get.gsub('-', '_')} Var")
    cap_curve_var_in.setKeyName(cap_fff_curve.name.get)

    eir_curve_var_in = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 1 Value')
    eir_curve_var_in.setName("#{eir_fff_curve.name.get.gsub('-', '_')} Var")
    eir_curve_var_in.setKeyName(eir_fff_curve.name.get)

    coil_power_ss = OpenStudio::Model::EnergyManagementSystemSensor.new(model, ss_var_name)
    coil_power_ss.setName("#{coil_name} electric energy")
    coil_power_ss.setKeyName(coil_name)
    # Trend variable
    coil_power_ss_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, coil_power_ss)
    coil_power_ss_trend.setName("#{coil_power_ss.name} Trend")
    coil_power_ss_trend.setNumberOfTimestepsToBeLogged(number_of_timestep_logged)

    # Actuators
    cc_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(cap_fff_curve, *EPlus::EMSActuatorCurveResult)
    cc_actuator.setName("#{cap_fff_curve.name.get.gsub('-', '_')} value")
    ec_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(eir_fff_curve, *EPlus::EMSActuatorCurveResult)
    ec_actuator.setName("#{eir_fff_curve.name.get.gsub('-', '_')} value")

    # Program
    cycling_degrad_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    # Check values within min/max limits
    cycling_degrad_program.setName("#{coil_name} cycling degradation program")
    cycling_degrad_program.addLine("If #{cap_curve_var_in.name} < #{cap_fff_curve.minimumValueofx}")
    cycling_degrad_program.addLine("  Set #{cap_curve_var_in.name} = #{cap_fff_curve.minimumValueofx}")
    cycling_degrad_program.addLine("ElseIf #{cap_curve_var_in.name} > #{cap_fff_curve.maximumValueofx}")
    cycling_degrad_program.addLine("  Set #{cap_curve_var_in.name} = #{cap_fff_curve.maximumValueofx}")
    cycling_degrad_program.addLine('EndIf')
    cycling_degrad_program.addLine("If #{eir_curve_var_in.name} < #{eir_fff_curve.minimumValueofx}")
    cycling_degrad_program.addLine("  Set #{eir_curve_var_in.name} = #{eir_fff_curve.minimumValueofx}")
    cycling_degrad_program.addLine("ElseIf #{eir_curve_var_in.name} > #{eir_fff_curve.maximumValueofx}")
    cycling_degrad_program.addLine("  Set #{eir_curve_var_in.name} = #{eir_fff_curve.maximumValueofx}")
    cycling_degrad_program.addLine('EndIf')
    cc_out_calc = []
    ec_out_calc = []
    cap_fflow_spec.each_with_index do |coeff, i|
      c_name = "c_#{i + 1}_cap"
      cycling_degrad_program.addLine("Set #{c_name} = #{coeff}")
      cc_out_calc << c_name + " * (#{cap_curve_var_in.name}^#{i})"
    end
    eir_fflow_spec.each_with_index do |coeff, i|
      c_name = "c_#{i + 1}_eir"
      cycling_degrad_program.addLine("Set #{c_name} = #{coeff}")
      ec_out_calc << c_name + " * (#{eir_curve_var_in.name}^#{i})"
    end
    cycling_degrad_program.addLine("Set cc_out = #{cc_out_calc.join(' + ')}")
    cycling_degrad_program.addLine("Set ec_out = #{ec_out_calc.join(' + ')}")
    (0..number_of_timestep_logged).each do |t_i|
      if t_i == 0
        cycling_degrad_program.addLine("Set cc_now = #{coil_power_ss_trend.name}")
      else
        cycling_degrad_program.addLine("Set cc_#{t_i}_ago = @TrendValue #{coil_power_ss_trend.name} #{t_i}")
      end
    end
    (1..number_of_timestep_logged).each do |t_i|
      if t_i == 1
        cycling_degrad_program.addLine("If cc_#{t_i}_ago == 0 && cc_now > 0") # Coil just turned on
      else
        r_s_a = ['cc_now > 0']
        for i in 1..t_i - 1
          r_s_a << "cc_#{i}_ago > 0"
        end
        r_s = r_s_a.join(' && ')
        cycling_degrad_program.addLine("ElseIf cc_#{t_i}_ago == 0 && #{r_s}")
      end
      # Curve fit from Winkler's thesis, page 200: https://drum.lib.umd.edu/bitstream/handle/1903/9493/Winkler_umd_0117E_10504.pdf?sequence=1&isAllowed=y
      # use average curve value ( ~ at 0.5 min).
      # This curve reached steady state in 2 mins, assume shape for high efficiency units, scale it down based on number_of_timestep_logged
      cycling_degrad_program.addLine("  Set exp = @Exp((-2.19722) * #{get_time_to_full_cap_limits[0]} / #{number_of_timestep_logged} * #{t_i - 0.5})")
      cycling_degrad_program.addLine('  Set cc_mult = (-1.0125 * exp + 1.0125)')
      cycling_degrad_program.addLine('  Set cc_mult = @Min cc_mult 1.0')
    end
    cycling_degrad_program.addLine('Else')
    cycling_degrad_program.addLine('  Set cc_mult = 1.0')
    cycling_degrad_program.addLine('EndIf')
    cycling_degrad_program.addLine("Set #{cc_actuator.name} = cc_mult * cc_out")
    # power is ramped up in less than 1 min, only second level simulation can capture power startup behavior
    cycling_degrad_program.addLine("Set #{ec_actuator.name} = ec_out / cc_mult")

    # ProgramCallingManagers
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName("#{cycling_degrad_program.name} ProgramManager")
    program_calling_manager.setCallingPoint('InsideHVACSystemIterationLoop')
    program_calling_manager.addProgram(cycling_degrad_program)
  end

  # Apply time-based realistic staging EMS program for two speed system.
  # Observe 5 mins before ramping up the speed level, or enable the backup coil.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param unitary_system [OpenStudio::Model::AirLoopHVACUnitarySystem] OpenStudio Air Loop HVAC Unitary System object
  # @param htg_supp_coil [OpenStudio::Model::CoilHeatingElectric or OpenStudio::Model::CoilHeatingElectricMultiStage] OpenStudio Supplemental Heating Coil object
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param is_onoff_thermostat_ddb [Boolean] Whether to apply on off thermostat deadband
  # @param cooling_system [HPXML::CoolingSystem or HPXML::HeatPump] HPXML Cooling System or HPXML Heat Pump object
  # @return [void]
  def self.apply_two_speed_realistic_staging_EMS(model, unitary_system, htg_supp_coil, control_zone, is_onoff_thermostat_ddb, cooling_system)
    # Note: Currently only available in 1 min time step
    return unless is_onoff_thermostat_ddb
    return unless cooling_system.compressor_type == HPXML::HVACCompressorTypeTwoStage

    number_of_timestep_logged = 5 # wait 5 mins to check demand

    is_heatpump = cooling_system.is_a? HPXML::HeatPump

    # Sensors
    if not htg_supp_coil.nil?
      backup_coil_energy = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Heating Coil Heating Energy')
      backup_coil_energy.setName("#{htg_supp_coil.name} heating energy")
      backup_coil_energy.setKeyName(htg_supp_coil.name.get)

      # Trend variable
      backup_energy_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, backup_coil_energy)
      backup_energy_trend.setName("#{backup_coil_energy.name} Trend")
      backup_energy_trend.setNumberOfTimestepsToBeLogged(1)

      supp_coil_avail_act, global_var_supp_avail = get_supp_coil_avail_sch_actuator(model, htg_supp_coil)
    end
    # Sensors
    living_temp_ss = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Air Temperature')
    living_temp_ss.setName("#{control_zone.name} temp")
    living_temp_ss.setKeyName(control_zone.name.to_s)

    htg_sch = control_zone.thermostatSetpointDualSetpoint.get.heatingSetpointTemperatureSchedule.get
    clg_sch = control_zone.thermostatSetpointDualSetpoint.get.coolingSetpointTemperatureSchedule.get

    htg_sp_ss = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
    htg_sp_ss.setName("#{control_zone.name} htg setpoint")
    htg_sp_ss.setKeyName(htg_sch.name.to_s)

    clg_sp_ss = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
    clg_sp_ss.setName("#{control_zone.name} clg setpoint")
    clg_sp_ss.setKeyName(clg_sch.name.to_s)

    unitary_var = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Unitary System DX Coil Speed Level')
    unitary_var.setName(unitary_system.name.get + ' speed level')
    unitary_var.setKeyName(unitary_system.name.get)

    # Actuators
    unitary_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(unitary_system, 'Coil Speed Control', 'Unitary System DX Coil Speed Value')
    unitary_actuator.setName(unitary_system.name.get + ' speed override')

    # Trend variable
    unitary_speed_var_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, unitary_var)
    unitary_speed_var_trend.setName("#{unitary_var.name} Trend")
    unitary_speed_var_trend.setNumberOfTimestepsToBeLogged(number_of_timestep_logged)

    ddb = model.getThermostatSetpointDualSetpoints[0].temperatureDifferenceBetweenCutoutAndSetpoint
    # Program
    realistic_cycling_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    # Check values within min/max limits
    realistic_cycling_program.setName("#{unitary_system.name.get} realistic cycling")
    realistic_cycling_program.addLine("Set living_t = #{living_temp_ss.name}")
    realistic_cycling_program.addLine("Set htg_sp_l = #{htg_sp_ss.name}")
    realistic_cycling_program.addLine("Set htg_sp_h = #{htg_sp_ss.name} + #{ddb}")
    realistic_cycling_program.addLine("Set clg_sp_l = #{clg_sp_ss.name} - #{ddb}")
    realistic_cycling_program.addLine("Set clg_sp_h = #{clg_sp_ss.name}")

    (1..number_of_timestep_logged).each do |t_i|
      realistic_cycling_program.addLine("Set unitary_var_#{t_i}_ago = @TrendValue #{unitary_speed_var_trend.name} #{t_i}")
    end
    s_trend_low = []
    s_trend_high = []
    (1..number_of_timestep_logged).each do |t_i|
      s_trend_low << "(unitary_var_#{t_i}_ago == 1)"
      s_trend_high << "(unitary_var_#{t_i}_ago == 2)"
    end
    # Cooling
    # Setpoint not met and low speed is on for 5 time steps
    realistic_cycling_program.addLine("If (living_t - clg_sp_h > 0.0) && (#{s_trend_low.join(' && ')})")
    # Enable high speed unitary system
    realistic_cycling_program.addLine("  Set #{unitary_actuator.name} = 2")
    # Keep high speed unitary on until setpoint +- deadband is met
    realistic_cycling_program.addLine('ElseIf (unitary_var_1_ago == 2) && ((living_t - clg_sp_l > 0.0))')
    realistic_cycling_program.addLine("  Set #{unitary_actuator.name} = 2")
    realistic_cycling_program.addLine('Else')
    realistic_cycling_program.addLine("  Set #{unitary_actuator.name} = 1")
    realistic_cycling_program.addLine('EndIf')
    if is_heatpump
      # Heating
      realistic_cycling_program.addLine("If (htg_sp_l - living_t > 0.0) && (#{s_trend_low.join(' && ')})")
      # Enable high speed unitary system
      realistic_cycling_program.addLine("  Set #{unitary_actuator.name} = 2")
      # Keep high speed unitary on until setpoint +- deadband is met
      realistic_cycling_program.addLine('ElseIf (unitary_var_1_ago == 2) && (htg_sp_h - living_t > 0.0)')
      realistic_cycling_program.addLine("  Set #{unitary_actuator.name} = 2")
      realistic_cycling_program.addLine('Else')
      realistic_cycling_program.addLine("  Set #{unitary_actuator.name} = 1")
      realistic_cycling_program.addLine('EndIf')
      if (not htg_supp_coil.nil?) && (not (htg_supp_coil.is_a? OpenStudio::Model::CoilHeatingElectricMultiStage))
        realistic_cycling_program.addLine("If #{global_var_supp_avail.name} == 0") # Other EMS set it to be 0.0, keep the logic
        realistic_cycling_program.addLine("  Set #{supp_coil_avail_act.name} = 0")
        realistic_cycling_program.addLine('Else') # global variable = 1
        realistic_cycling_program.addLine("  Set #{supp_coil_avail_act.name} = 1")
        realistic_cycling_program.addLine("  If (htg_sp_l - living_t > 0.0) && (#{s_trend_high.join(' && ')})")
        realistic_cycling_program.addLine("    Set #{supp_coil_avail_act.name} = 1")
        realistic_cycling_program.addLine("  ElseIf ((@TRENDVALUE #{backup_energy_trend.name} 1) > 0) && (htg_sp_h - living_t > 0.0)") # backup coil is turned on, keep it on until reaching upper end of ddb in case of high frequency oscillations
        realistic_cycling_program.addLine("    Set #{supp_coil_avail_act.name} = 1")
        realistic_cycling_program.addLine('  Else')
        realistic_cycling_program.addLine("    Set #{global_var_supp_avail.name} = 0")
        realistic_cycling_program.addLine("    Set #{supp_coil_avail_act.name} = 0")
        realistic_cycling_program.addLine('  EndIf')
        realistic_cycling_program.addLine('EndIf')
      end
    end
    # ProgramCallingManagers
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName("#{realistic_cycling_program.name} Program Manager")
    program_calling_manager.setCallingPoint('InsideHVACSystemIterationLoop')
    program_calling_manager.addProgram(realistic_cycling_program)
  end

  # Apply maximum power ratio schedule for variable speed system.
  # Creates EMS program to determine and control the stage that can reach the maximum power constraint.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param air_loop_unitary [OpenStudio::Model::AirLoopHVACUnitarySystem] Air loop for the HVAC system
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param heating_system [HPXML::HeatingSystem or HPXML::HeatPump] HPXML Heating System or HPXML Heat Pump object
  # @param cooling_system [HPXML::CoolingSystem or HPXML::HeatPump] HPXML Cooling System or HPXML Heat Pump object
  # @param htg_supp_coil [OpenStudio::Model::CoilHeatingElectric or CoilHeatingElectricMultiStage] OpenStudio Supplemental Heating Coil object
  # @param clg_coil [OpenStudio::Model::CoilCoolingDXMultiSpeed] OpenStudio MultiStage Cooling Coil object
  # @param htg_coil [OpenStudio::Model::CoilHeatingDXMultiSpeed] OpenStudio MultiStage Heating Coil object
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @return [void]
  def self.apply_max_power_EMS(model, runner, air_loop_unitary, control_zone, heating_system, cooling_system, htg_supp_coil, clg_coil, htg_coil, schedules_file)
    return if schedules_file.nil?
    return if clg_coil.nil? && htg_coil.nil?

    max_pow_ratio_sch = schedules_file.create_schedule_file(model, col_name: SchedulesFile::Columns[:HVACMaximumPowerRatio].name, schedule_type_limits_name: Constants.ScheduleTypeLimitsFraction)
    return if max_pow_ratio_sch.nil?

    # Check maximum power ratio schedules only used in var speed systems,
    clg_coil = nil unless (cooling_system.compressor_type == HPXML::HVACCompressorTypeVariableSpeed)
    htg_coil = nil unless ((heating_system.is_a? HPXML::HeatPump) && heating_system.compressor_type == HPXML::HVACCompressorTypeVariableSpeed)
    htg_supp_coil = nil unless ((heating_system.is_a? HPXML::HeatPump) && heating_system.compressor_type == HPXML::HVACCompressorTypeVariableSpeed)
    # No variable speed coil
    if clg_coil.nil? && htg_coil.nil?
      runner.registerWarning('Maximum power ratio schedule is only supported for variable speed systems.')
    end

    if (htg_coil.is_a? OpenStudio::Model::CoilHeatingDXMultiSpeed) && (heating_system.backup_type != HPXML::HeatPumpBackupTypeIntegrated)
      htg_coil = nil
      htg_supp_coil = nil
      runner.registerWarning('Maximum power ratio schedule is only supported for integrated backup system. Schedule is ignored for heating.')
    end

    return if (clg_coil.nil? && htg_coil.nil?)

    # sensors
    pow_ratio_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
    pow_ratio_sensor.setName("#{air_loop_unitary.name} power_ratio")
    pow_ratio_sensor.setKeyName(max_pow_ratio_sch.name.to_s)
    indoor_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Air Temperature')
    indoor_temp_sensor.setName("#{control_zone.name} indoor_temp")
    indoor_temp_sensor.setKeyName(control_zone.name.to_s)
    htg_spt_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Thermostat Heating Setpoint Temperature')
    htg_spt_sensor.setName("#{control_zone.name} htg_spt_temp")
    htg_spt_sensor.setKeyName(control_zone.name.to_s)
    clg_spt_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Thermostat Cooling Setpoint Temperature')
    clg_spt_sensor.setName("#{control_zone.name} clg_spt_temp")
    clg_spt_sensor.setKeyName(control_zone.name.to_s)
    load_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Unitary System Predicted Sensible Load to Setpoint Heat Transfer Rate')
    load_sensor.setName("#{air_loop_unitary.name} sens load")
    load_sensor.setKeyName(air_loop_unitary.name.to_s)

    # global variable
    temp_offset_signal = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{air_loop_unitary.name.to_s.gsub(' ', '_')}_temp_offset")

    # Temp offset Initialization Program
    # Temperature offset signal used to see if the hvac is recovering temperature to setpoint.
    # If abs (indoor temperature - setpoint) > offset, then hvac and backup is allowed to operate without cap to recover temperature until it reaches setpoint
    temp_offset_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    temp_offset_program.setName("#{air_loop_unitary.name} temp offset init program")
    temp_offset_program.addLine("Set #{temp_offset_signal.name} = 0")

    # calling managers
    manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    manager.setName("#{temp_offset_program.name} calling manager")
    manager.setCallingPoint('BeginNewEnvironment')
    manager.addProgram(temp_offset_program)
    manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    manager.setName("#{temp_offset_program.name} calling manager2")
    manager.setCallingPoint('AfterNewEnvironmentWarmUpIsComplete')
    manager.addProgram(temp_offset_program)

    # actuator
    coil_speed_act = OpenStudio::Model::EnergyManagementSystemActuator.new(air_loop_unitary, *EPlus::EMSActuatorUnitarySystemCoilSpeedLevel)
    coil_speed_act.setName("#{air_loop_unitary.name} coil speed level")
    if not htg_supp_coil.nil?
      supp_coil_avail_act, global_var_supp_avail = get_supp_coil_avail_sch_actuator(model, htg_supp_coil)
    end

    # EMS program
    program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    program.setName("#{air_loop_unitary.name} max power ratio program")
    program.addLine('Set clg_mode = 0')
    program.addLine('Set htg_mode = 0')
    program.addLine("If #{load_sensor.name} > 0")
    program.addLine('  Set htg_mode = 1')
    program.addLine("  Set setpoint = #{htg_spt_sensor.name}")
    program.addLine("ElseIf #{load_sensor.name} < 0")
    program.addLine('  Set clg_mode = 1')
    program.addLine("  Set setpoint = #{clg_spt_sensor.name}")
    program.addLine('EndIf')
    program.addLine("Set sens_load = @Abs #{load_sensor.name}")
    program.addLine('Set clg_mode = 0') if clg_coil.nil?
    program.addLine('Set htg_mode = 0') if htg_coil.nil?

    [htg_coil, clg_coil].each do |coil|
      next if coil.nil?

      coil_cap_stage_fff_sensors = []
      coil_cap_stage_ft_sensors = []
      coil_eir_stage_fff_sensors = []
      coil_eir_stage_ft_sensors = []
      coil_eir_stage_plf_sensors = []
      # Heating/Cooling specific calculations and names
      if coil.is_a? OpenStudio::Model::CoilHeatingDXMultiSpeed
        cap_fff_curve_name = 'heatingCapacityFunctionofFlowFractionCurve'
        cap_ft_curve_name = 'heatingCapacityFunctionofTemperatureCurve'
        capacity_name = 'grossRatedHeatingCapacity'
        cop_name = 'grossRatedHeatingCOP'
        cap_multiplier = 'htg_frost_multiplier_cap'
        pow_multiplier = 'htg_frost_multiplier_pow'
        mode_s = 'If htg_mode > 0'

        # Outdoor sensors added to calculate defrost adjustment for heating
        outdoor_db_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Drybulb Temperature')
        outdoor_db_sensor.setName('outdoor_db')
        outdoor_w_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Humidity Ratio')
        outdoor_w_sensor.setName('outdoor_w')
        outdoor_bp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Barometric Pressure')
        outdoor_bp_sensor.setName('outdoor_bp')

        # Calculate capacity and eirs for later use of full-load power calculations at each stage
        # Equations from E+ source code
        program.addLine('If htg_mode > 0')
        program.addLine("  If #{outdoor_db_sensor.name} < 4.444444,")
        program.addLine("    Set T_coil_out = 0.82 * #{outdoor_db_sensor.name} - 8.589")
        program.addLine("    Set delta_humidity_ratio = @MAX 0 (#{outdoor_w_sensor.name} - (@WFnTdbRhPb T_coil_out 1.0 #{outdoor_bp_sensor.name}))")
        program.addLine("    Set #{cap_multiplier} = 0.909 - 107.33 * delta_humidity_ratio")
        program.addLine("    Set #{pow_multiplier} = 0.90 - 36.45 * delta_humidity_ratio")
        program.addLine('  Else')
        program.addLine("    Set #{cap_multiplier} = 1.0")
        program.addLine("    Set #{pow_multiplier} = 1.0")
        program.addLine('  EndIf')
        program.addLine('EndIf')
      elsif coil.is_a? OpenStudio::Model::CoilCoolingDXMultiSpeed
        cap_fff_curve_name = 'totalCoolingCapacityFunctionofFlowFractionCurve'
        cap_ft_curve_name = 'totalCoolingCapacityFunctionofTemperatureCurve'
        capacity_name = 'grossRatedTotalCoolingCapacity'
        cop_name = 'grossRatedCoolingCOP'
        cap_multiplier = 'shr'
        pow_multiplier = '1.0'
        mode_s = 'If clg_mode > 0'

        # cooling coil cooling rate sensors to calculate real time SHR
        clg_tot_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Cooling Coil Total Cooling Rate')
        clg_tot_sensor.setName("#{coil.name} total cooling rate")
        clg_tot_sensor.setKeyName(coil.name.to_s)
        clg_sens_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Cooling Coil Sensible Cooling Rate')
        clg_sens_sensor.setName("#{coil.name} sens cooling rate")
        clg_sens_sensor.setKeyName(coil.name.to_s)

        program.addLine('If clg_mode > 0')
        program.addLine("  If #{clg_tot_sensor.name} > 0")
        program.addLine("    Set #{cap_multiplier} = #{clg_sens_sensor.name} / #{clg_tot_sensor.name}")
        program.addLine('  Else')
        program.addLine("    Set #{cap_multiplier} = 0.0")
        program.addLine('  EndIf')
        program.addLine('EndIf')
      end
      # Heating and cooling performance curve sensors that need to be added
      coil.stages.each_with_index do |stage, i|
        stage_cap_fff_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Output Value')
        stage_cap_fff_sensor.setName("#{coil.name} cap stage #{i} fff")
        stage_cap_fff_sensor.setKeyName(stage.send(cap_fff_curve_name).name.to_s)
        coil_cap_stage_fff_sensors << stage_cap_fff_sensor
        stage_cap_ft_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Output Value')
        stage_cap_ft_sensor.setName("#{coil.name} cap stage #{i} ft")
        stage_cap_ft_sensor.setKeyName(stage.send(cap_ft_curve_name).name.to_s)
        coil_cap_stage_ft_sensors << stage_cap_ft_sensor
        stage_eir_fff_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Output Value')
        stage_eir_fff_sensor.setName("#{coil.name} eir stage #{i} fff")
        stage_eir_fff_sensor.setKeyName(stage.energyInputRatioFunctionofFlowFractionCurve.name.to_s)
        coil_eir_stage_fff_sensors << stage_eir_fff_sensor
        stage_eir_ft_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Output Value')
        stage_eir_ft_sensor.setName("#{coil.name} eir stage #{i} ft")
        stage_eir_ft_sensor.setKeyName(stage.energyInputRatioFunctionofTemperatureCurve.name.to_s)
        coil_eir_stage_ft_sensors << stage_eir_ft_sensor
        stage_eir_plf_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Output Value')
        stage_eir_plf_sensor.setName("#{coil.name} eir stage #{i} fplr")
        stage_eir_plf_sensor.setKeyName(stage.partLoadFractionCorrelationCurve.name.to_s)
        coil_eir_stage_plf_sensors << stage_eir_plf_sensor
      end
      # Calculate the target speed ratio that operates at the target power output
      program.addLine(mode_s)
      coil.stages.each_with_index do |stage, i|
        program.addLine("  Set rt_capacity_#{i} = #{stage.send(capacity_name)} * #{coil_cap_stage_fff_sensors[i].name} * #{coil_cap_stage_ft_sensors[i].name}")
        program.addLine("  Set rt_capacity_#{i}_adj = rt_capacity_#{i} * #{cap_multiplier}")
        program.addLine("  Set rated_eir_#{i} = 1 / #{stage.send(cop_name)}")
        program.addLine("  Set plf = #{coil_eir_stage_plf_sensors[i].name}")
        program.addLine("  If #{coil_eir_stage_plf_sensors[i].name} > 0.0")
        program.addLine("    Set rt_eir_#{i} = rated_eir_#{i} * #{coil_eir_stage_ft_sensors[i].name} * #{coil_eir_stage_fff_sensors[i].name} / #{coil_eir_stage_plf_sensors[i].name}")
        program.addLine('  Else')
        program.addLine("    Set rt_eir_#{i} = 0")
        program.addLine('  EndIf')
        program.addLine("  Set rt_power_#{i} = rt_eir_#{i} * rt_capacity_#{i} * #{pow_multiplier}") # use unadjusted capacity value in pow calculations
      end
      program.addLine("  Set target_power = #{coil.stages[-1].send(capacity_name)} * rated_eir_#{coil.stages.size - 1} * #{pow_ratio_sensor.name}")
      (0..coil.stages.size - 1).each do |i|
        if i == 0
          program.addLine("  If target_power < rt_power_#{i}")
          program.addLine("    Set target_speed_ratio = target_power / rt_power_#{i}")
        else
          program.addLine("  ElseIf target_power < rt_power_#{i}")
          program.addLine("    Set target_speed_ratio = (target_power - rt_power_#{i - 1}) / (rt_power_#{i} - rt_power_#{i - 1}) + #{i}")
        end
      end
      program.addLine('  Else')
      program.addLine("    Set target_speed_ratio = #{coil.stages.size}")
      program.addLine('  EndIf')

      # Calculate the current power that needs to meet zone loads
      (0..coil.stages.size - 1).each do |i|
        if i == 0
          program.addLine("  If sens_load <= rt_capacity_#{i}_adj")
          program.addLine("    Set current_power = sens_load / rt_capacity_#{i}_adj * rt_power_#{i}")
        else
          program.addLine("  ElseIf sens_load <= rt_capacity_#{i}_adj")
          program.addLine("    Set hs_speed_ratio = (sens_load - rt_capacity_#{i - 1}_adj) / (rt_capacity_#{i}_adj - rt_capacity_#{i - 1}_adj)")
          program.addLine('    Set ls_speed_ratio = 1 - hs_speed_ratio')
          program.addLine("    Set current_power = hs_speed_ratio * rt_power_#{i} + ls_speed_ratio * rt_power_#{i - 1}")
        end
      end
      program.addLine('  Else')
      program.addLine("    Set current_power = rt_power_#{coil.stages.size - 1}")
      program.addLine('  EndIf')
      program.addLine('EndIf')
    end

    program.addLine("Set #{supp_coil_avail_act.name} = #{global_var_supp_avail.name}") unless htg_supp_coil.nil?
    program.addLine('If htg_mode > 0 || clg_mode > 0')
    program.addLine("  If (#{pow_ratio_sensor.name} == 1) || ((@Abs (#{indoor_temp_sensor.name} - setpoint)) > #{UnitConversions.convert(4, 'deltaF', 'deltaC')}) || #{temp_offset_signal.name} == 1")
    program.addLine("    Set #{coil_speed_act.name} = NULL")
    program.addLine("    If ((@Abs (#{indoor_temp_sensor.name} - setpoint)) > #{UnitConversions.convert(4, 'deltaF', 'deltaC')})")
    program.addLine("      Set #{temp_offset_signal.name} = 1")
    program.addLine("    ElseIf (@Abs (#{indoor_temp_sensor.name} - setpoint)) < 0.001") # Temperature recovered
    program.addLine("      Set #{temp_offset_signal.name} = 0")
    program.addLine('    EndIf')
    program.addLine('  Else')
    # general & critical curtailment, operation refers to AHRI Standard 1380 2019
    program.addLine('    If current_power >= target_power')
    program.addLine("      Set #{coil_speed_act.name} = target_speed_ratio")
    if not htg_supp_coil.nil?
      program.addLine("      Set #{global_var_supp_avail.name} = 0")
      program.addLine("      Set #{supp_coil_avail_act.name} = 0")
    end
    program.addLine('    Else')
    program.addLine("      Set #{coil_speed_act.name} = NULL")
    program.addLine('    EndIf')
    program.addLine('  EndIf')
    program.addLine('EndIf')

    # calling manager
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName(program.name.to_s + ' calling manager')
    program_calling_manager.setCallingPoint('InsideHVACSystemIterationLoop')
    program_calling_manager.addProgram(program)
  end

  # Apply time-based realistic staging EMS program for integrated multi-stage backup system.
  # Observe 5 mins before ramping up the speed level.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param unitary_system [OpenStudio::Model::AirLoopHVACUnitarySystem] OpenStudio Air Loop HVAC Unitary System object
  # @param htg_supp_coil [OpenStudio::Model::CoilHeatingElectric or CoilHeatingElectricMultiStage] OpenStudio Supplemental Heating Coil object
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param htg_coil [OpenStudio::Model::CoilHeatingDXSingleSpeed or OpenStudio::Model::CoilHeatingDXMultiSpeed] OpenStudio Heating Coil object
  # @return [void]
  def self.add_backup_staging_EMS(model, unitary_system, htg_supp_coil, control_zone, htg_coil)
    return unless htg_supp_coil.is_a? OpenStudio::Model::CoilHeatingElectricMultiStage

    # Note: Currently only available in 1 min time step
    number_of_timestep_logged = 5 # wait 5 mins to check demand
    max_htg_coil_stage = (htg_coil.is_a? OpenStudio::Model::CoilHeatingDXSingleSpeed) ? 1 : htg_coil.stages.size
    ddb = model.getThermostatSetpointDualSetpoints[0].temperatureDifferenceBetweenCutoutAndSetpoint

    # Sensors
    living_temp_ss = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Mean Air Temperature')
    living_temp_ss.setName('living temp')
    living_temp_ss.setKeyName(control_zone.name.get)

    htg_sp_ss = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Thermostat Heating Setpoint Temperature')
    htg_sp_ss.setName('htg_setpoint')
    htg_sp_ss.setKeyName(control_zone.name.get)

    backup_coil_htg_rate = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Heating Coil Heating Rate')
    backup_coil_htg_rate.setName('supp coil heating rate')
    backup_coil_htg_rate.setKeyName(htg_supp_coil.name.get)

    # Need to use availability actuator because there's a bug in E+ that didn't handle the speed level = 0 correctly.See: https://github.com/NREL/EnergyPlus/pull/9392#discussion_r1578624175
    supp_coil_avail_act, global_var_supp_avail = get_supp_coil_avail_sch_actuator(model, htg_supp_coil)

    # Trend variable
    zone_temp_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, living_temp_ss)
    zone_temp_trend.setName("#{living_temp_ss.name} Trend")
    zone_temp_trend.setNumberOfTimestepsToBeLogged(number_of_timestep_logged)
    setpoint_temp_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, htg_sp_ss)
    setpoint_temp_trend.setName("#{htg_sp_ss.name} Trend")
    setpoint_temp_trend.setNumberOfTimestepsToBeLogged(number_of_timestep_logged)
    backup_coil_htg_rate_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, backup_coil_htg_rate)
    backup_coil_htg_rate_trend.setName("#{backup_coil_htg_rate.name} Trend")
    backup_coil_htg_rate_trend.setNumberOfTimestepsToBeLogged(number_of_timestep_logged)
    if max_htg_coil_stage > 1
      unitary_var = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Unitary System DX Coil Speed Level')
      unitary_var.setName(unitary_system.name.get + ' speed level')
      unitary_var.setKeyName(unitary_system.name.get)
      unitary_speed_var_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, unitary_var)
      unitary_speed_var_trend.setName("#{unitary_var.name} Trend")
      unitary_speed_var_trend.setNumberOfTimestepsToBeLogged(number_of_timestep_logged)
    end

    # Actuators
    supp_stage_act = OpenStudio::Model::EnergyManagementSystemActuator.new(unitary_system, 'Coil Speed Control', 'Unitary System Supplemental Coil Stage Level')
    supp_stage_act.setName(unitary_system.name.get + ' backup stage level')

    # staging Program
    supp_staging_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    # Check values within min/max limits
    supp_staging_program.setName("#{unitary_system.name.get} backup staging")

    s_trend = []
    (1..number_of_timestep_logged).each do |t_i|
      supp_staging_program.addLine("Set zone_temp_#{t_i}_ago = @TrendValue #{zone_temp_trend.name} #{t_i}")
      supp_staging_program.addLine("Set htg_spt_temp_#{t_i}_ago = @TrendValue #{setpoint_temp_trend.name} #{t_i}")
      supp_staging_program.addLine("Set supp_htg_rate_#{t_i}_ago = @TrendValue #{backup_coil_htg_rate_trend.name} #{t_i}")
      if max_htg_coil_stage > 1
        supp_staging_program.addLine("Set unitary_var_#{t_i}_ago = @TrendValue #{unitary_speed_var_trend.name} #{t_i}")
        s_trend << "((htg_spt_temp_#{t_i}_ago - zone_temp_#{t_i}_ago > 0.01) && (unitary_var_#{t_i}_ago == #{max_htg_coil_stage}))"
      else
        s_trend << "(htg_spt_temp_#{t_i}_ago - zone_temp_#{t_i}_ago > 0.01)"
      end
    end
    # Logic to determine whether to enable backup coil
    supp_staging_program.addLine("If #{global_var_supp_avail.name} == 0") # Other EMS set it to be 0.0, keep the logic
    supp_staging_program.addLine("  Set #{supp_coil_avail_act.name} = 0")
    supp_staging_program.addLine('Else') # global variable = 1
    supp_staging_program.addLine("  Set #{supp_coil_avail_act.name} = 1")
    supp_staging_program.addLine("  If (supp_htg_rate_1_ago > 0) && (#{htg_sp_ss.name} + #{living_temp_ss.name} > 0.01)")
    supp_staging_program.addLine("    Set #{supp_coil_avail_act.name} = 1") # Keep backup coil on until reaching setpoint
    supp_staging_program.addLine("  ElseIf (#{s_trend.join(' && ')})")
    if ddb > 0.0
      supp_staging_program.addLine("    If (#{living_temp_ss.name} >= #{htg_sp_ss.name} - #{ddb})")
      supp_staging_program.addLine("      Set #{global_var_supp_avail.name} = 0")
      supp_staging_program.addLine("      Set #{supp_coil_avail_act.name} = 0")
      supp_staging_program.addLine('    EndIf')
    end
    supp_staging_program.addLine('  Else')
    supp_staging_program.addLine("    Set #{global_var_supp_avail.name} = 0")
    supp_staging_program.addLine("    Set #{supp_coil_avail_act.name} = 0")
    supp_staging_program.addLine('  EndIf')
    supp_staging_program.addLine('EndIf')
    supp_staging_program.addLine("If #{supp_coil_avail_act.name} == 1")
    # Determine the stage
    for i in (1..htg_supp_coil.stages.size)
      s = []
      for t_i in (1..number_of_timestep_logged)
        if i == 1
          # stays at stage 0 for 5 mins
          s << "(supp_htg_rate_#{t_i}_ago < #{htg_supp_coil.stages[i - 1].nominalCapacity.get})"
        else
          # stays at stage i-1 for 5 mins
          s << "(supp_htg_rate_#{t_i}_ago < #{htg_supp_coil.stages[i - 1].nominalCapacity.get}) && (supp_htg_rate_#{t_i}_ago >= #{htg_supp_coil.stages[i - 2].nominalCapacity.get})"
        end
      end
      if i == 1
        supp_staging_program.addLine("  If #{s.join(' && ')}")
      else
        supp_staging_program.addLine("  ElseIf #{s.join(' && ')}")
      end
      supp_staging_program.addLine("    Set #{supp_stage_act.name} = #{i}")
    end
    supp_staging_program.addLine('  EndIf')
    supp_staging_program.addLine('EndIf')
    # ProgramCallingManagers
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName("#{supp_staging_program.name} Program Manager")
    program_calling_manager.setCallingPoint('InsideHVACSystemIterationLoop')
    program_calling_manager.addProgram(supp_staging_program)
  end

  # TODO
  #
  # @param c_d [TODO] TODO
  # @return [TODO] TODO
  def self.calc_plr_coefficients(c_d)
    return [(1.0 - c_d), c_d, 0.0] # Linear part load model
  end

  # TODO
  #
  # @param cooling_system [TODO] TODO
  # @return [TODO] TODO
  def self.set_cool_c_d(cooling_system)
    clg_ap = cooling_system.additional_properties

    # Degradation coefficient for cooling
    if ((cooling_system.is_a? HPXML::CoolingSystem) && ([HPXML::HVACTypeRoomAirConditioner, HPXML::HVACTypePTAC].include? cooling_system.cooling_system_type)) ||
       ((cooling_system.is_a? HPXML::HeatPump) && ([HPXML::HVACTypeHeatPumpPTHP, HPXML::HVACTypeHeatPumpRoom].include? cooling_system.heat_pump_type))
      clg_ap.cool_c_d = 0.22
    elsif cooling_system.compressor_type == HPXML::HVACCompressorTypeSingleStage
      if cooling_system.cooling_efficiency_seer < 13.0
        clg_ap.cool_c_d = 0.20
      else
        clg_ap.cool_c_d = 0.07
      end
    elsif cooling_system.compressor_type == HPXML::HVACCompressorTypeTwoStage
      clg_ap.cool_c_d = 0.11
    elsif cooling_system.compressor_type == HPXML::HVACCompressorTypeVariableSpeed
      clg_ap.cool_c_d = 0.25
    end

    # PLF curve
    num_speeds = clg_ap.cool_capacity_ratios.size
    clg_ap.cool_plf_fplr_spec = [calc_plr_coefficients(clg_ap.cool_c_d)] * num_speeds
  end

  # TODO
  #
  # @param heating_system [TODO] TODO
  # @return [TODO] TODO
  def self.set_heat_c_d(heating_system)
    htg_ap = heating_system.additional_properties

    # Degradation coefficient for heating
    if (heating_system.is_a? HPXML::HeatPump) && ([HPXML::HVACTypeHeatPumpPTHP, HPXML::HVACTypeHeatPumpRoom].include? heating_system.heat_pump_type)
      htg_ap.heat_c_d = 0.22
    elsif heating_system.compressor_type == HPXML::HVACCompressorTypeSingleStage
      if heating_system.heating_efficiency_hspf < 7.0
        htg_ap.heat_c_d =  0.20
      else
        htg_ap.heat_c_d =  0.11
      end
    elsif heating_system.compressor_type == HPXML::HVACCompressorTypeTwoStage
      htg_ap.heat_c_d =  0.11
    elsif heating_system.compressor_type == HPXML::HVACCompressorTypeVariableSpeed
      htg_ap.heat_c_d =  0.25
    end

    # PLF curve
    num_speeds = htg_ap.heat_capacity_ratios.size
    htg_ap.heat_plf_fplr_spec = [calc_plr_coefficients(htg_ap.heat_c_d)] * num_speeds
  end

  # TODO
  #
  # @param cooling_system [TODO] TODO
  # @return [TODO] TODO
  def self.calc_ceer_from_eer(cooling_system)
    # Reference: http://documents.dps.ny.gov/public/Common/ViewDoc.aspx?DocRefId=%7BB6A57FC0-6376-4401-92BD-D66EC1930DCF%7D
    return cooling_system.cooling_efficiency_eer / 1.01
  end

  # TODO
  #
  # @param hvac_system [TODO] TODO
  # @param use_eer_cop [TODO] TODO
  # @return [TODO] TODO
  def self.set_fan_power_rated(hvac_system, use_eer_cop)
    hvac_ap = hvac_system.additional_properties

    if use_eer_cop
      # Fan not separately modeled
      hvac_ap.fan_power_rated = 0.0
    elsif hvac_system.distribution_system.nil?
      # Ductless, installed and rated value should be equal
      hvac_ap.fan_power_rated = hvac_system.fan_watts_per_cfm # W/cfm
    else
      # Based on ASHRAE 1449-RP and recommended by Hugh Henderson
      if hvac_system.cooling_efficiency_seer <= 14
        hvac_ap.fan_power_rated = 0.25 # W/cfm
      elsif hvac_system.cooling_efficiency_seer >= 16
        hvac_ap.fan_power_rated = 0.18 # W/cfm
      else
        hvac_ap.fan_power_rated = 0.25 + (0.18 - 0.25) * (hvac_system.cooling_efficiency_seer - 14.0) / 2.0 # W/cfm
      end
    end
  end

  # TODO
  #
  # @param pump_eff [TODO] TODO
  # @param pump_w [TODO] TODO
  # @param pump_head_pa [TODO] TODO
  # @return [TODO] TODO
  def self.calc_pump_rated_flow_rate(pump_eff, pump_w, pump_head_pa)
    # Calculate needed pump rated flow rate to achieve a given pump power with an assumed
    # efficiency and pump head.
    return pump_eff * pump_w / pump_head_pa # m3/s
  end

  # TODO
  #
  # @param air_loop [TODO] TODO
  # @return [TODO] TODO
  def self.get_unitary_system_from_air_loop_hvac(air_loop)
    # Returns the unitary system or nil
    air_loop.supplyComponents.each do |comp|
      next unless comp.to_AirLoopHVACUnitarySystem.is_initialized

      return comp.to_AirLoopHVACUnitarySystem.get
    end
    return
  end

  # TODO
  #
  # @param heat_pump [TODO] TODO
  # @param weather [WeatherFile] Weather object containing EPW information
  # @return [TODO] TODO
  def self.set_gshp_assumptions(heat_pump, weather)
    hp_ap = heat_pump.additional_properties
    geothermal_loop = heat_pump.geothermal_loop

    hp_ap.design_chw = [85.0, weather.design.CoolingDrybulb - 15.0, weather.data.DeepGroundAnnualTemp + 10.0].max # Temperature of water entering indoor coil, use 85F as lower bound
    hp_ap.design_delta_t = 10.0
    hp_ap.fluid_type = Constants.FluidPropyleneGlycol
    hp_ap.frac_glycol = 0.2 # This was changed from 0.3 to 0.2 -- more typical based on experts/spec sheets
    if hp_ap.fluid_type == Constants.FluidWater
      hp_ap.design_hw = [45.0, weather.design.HeatingDrybulb + 35.0, weather.data.DeepGroundAnnualTemp - 10.0].max # Temperature of fluid entering indoor coil, use 45F as lower bound for water
    else
      hp_ap.design_hw = [35.0, weather.design.HeatingDrybulb + 35.0, weather.data.DeepGroundAnnualTemp - 10.0].min # Temperature of fluid entering indoor coil, use 35F as upper bound
    end
    pipe_diameter = geothermal_loop.pipe_diameter
    # Pipe nominal size conversion to pipe outside diameter and inside diameter,
    # only pipe sizes <= 2" are used here with DR11 (dimension ratio),
    if pipe_diameter == 0.75 # 3/4" pipe
      hp_ap.pipe_od = 1.050 # in
      hp_ap.pipe_id = 0.859 # in
    elsif pipe_diameter == 1.0 # 1" pipe
      hp_ap.pipe_od = 1.315 # in
      hp_ap.pipe_id = 1.076 # in
    elsif pipe_diameter == 1.25 # 1-1/4" pipe
      hp_ap.pipe_od = 1.660 # in
      hp_ap.pipe_id = 1.358 # in
    else
      fail "Unexpected pipe size: #{pipe_diameter}"
    end
    hp_ap.u_tube_spacing_type = 'b'
    # Calculate distance between pipes
    if hp_ap.u_tube_spacing_type == 'as'
      # Two tubes, spaced 1/8” apart at the center of the borehole
      hp_ap.u_tube_spacing = 0.125
    elsif hp_ap.u_tube_spacing_type == 'b'
      # Two tubes equally spaced between the borehole edges
      hp_ap.u_tube_spacing = 0.9661
    elsif hp_ap.u_tube_spacing_type == 'c'
      # Both tubes placed against outer edge of borehole
      hp_ap.u_tube_spacing = geothermal_loop.bore_diameter - 2 * hp_ap.pipe_od
    end
  end

  # TODO
  #
  # @param load_fraction [TODO] TODO
  # @param remaining_fraction [TODO] TODO
  # @param availability_days [TODO] TODO
  # @return [TODO] TODO
  def self.calc_sequential_load_fractions(load_fraction, remaining_fraction, availability_days)
    # Returns the EnergyPlus sequential load fractions for every day of the year
    if remaining_fraction > 0
      sequential_load_frac = load_fraction / remaining_fraction # Fraction of remaining load served by this system
    else
      sequential_load_frac = 0.0
    end
    sequential_load_fracs = availability_days.map { |d| d * sequential_load_frac }

    return sequential_load_fracs
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param fractions [TODO] TODO
  # @param unavailable_periods [HPXML::UnavailablePeriods] Object that defines periods for, e.g., power outages or vacancies
  # @return [TODO] TODO
  def self.get_sequential_load_schedule(model, fractions, unavailable_periods)
    if fractions.nil?
      fractions = [0]
      unavailable_periods = []
    end

    values = fractions.map { |f| f > 1 ? 1.0 : f.round(5) }

    sch_name = 'Sequential Fraction Schedule'
    if values.uniq.length == 1
      s = ScheduleConstant.new(model, sch_name, values[0], Constants.ScheduleTypeLimitsFraction, unavailable_periods: unavailable_periods)
      s = s.schedule
    else
      s = Schedule.create_ruleset_from_daily_season(model, values)
      s.setName(sch_name)
      Schedule.set_unavailable_periods(s, sch_name, unavailable_periods, model.getYearDescription.assumedYear)
      Schedule.set_schedule_type_limits(model, s, Constants.ScheduleTypeLimitsFraction)
    end

    return s
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @param hvac_object [TODO] TODO
  # @param sequential_heat_load_fracs [TODO] TODO
  # @param sequential_cool_load_fracs [TODO] TODO
  # @param hvac_unavailable_periods [TODO] TODO
  # @param heating_system [TODO] TODO
  # @return [TODO] TODO
  def self.set_sequential_load_fractions(model, control_zone, hvac_object, sequential_heat_load_fracs, sequential_cool_load_fracs, hvac_unavailable_periods, heating_system = nil)
    heating_sch = get_sequential_load_schedule(model, sequential_heat_load_fracs, hvac_unavailable_periods)
    cooling_sch = get_sequential_load_schedule(model, sequential_cool_load_fracs, hvac_unavailable_periods)
    control_zone.setSequentialHeatingFractionSchedule(hvac_object, heating_sch)
    control_zone.setSequentialCoolingFractionSchedule(hvac_object, cooling_sch)

    if (not heating_system.nil?) && (heating_system.is_a? HPXML::HeatingSystem) && heating_system.is_heat_pump_backup_system
      # Backup system for a heat pump, and heat pump has been set with
      # backup heating switchover temperature or backup heating lockout temperature.
      # Use EMS to prevent operation of this system above the specified temperature.

      max_heating_temp = heating_system.primary_heat_pump.additional_properties.supp_max_temp

      # Sensor
      tout_db_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Drybulb Temperature')
      tout_db_sensor.setKeyName('Environment')

      # Actuator
      if heating_sch.is_a? OpenStudio::Model::ScheduleConstant
        actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(heating_sch, *EPlus::EMSActuatorScheduleConstantValue)
      elsif heating_sch.is_a? OpenStudio::Model::ScheduleRuleset
        actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(heating_sch, *EPlus::EMSActuatorScheduleYearValue)
      else
        fail "Unexpected heating schedule type: #{heating_sch.class}."
      end
      actuator.setName("#{heating_sch.name.to_s.gsub(' ', '_')}_act")

      # Program
      temp_override_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      temp_override_program.setName("#{heating_sch.name} program")
      temp_override_program.addLine("If #{tout_db_sensor.name} > #{UnitConversions.convert(max_heating_temp, 'F', 'C')}")
      temp_override_program.addLine("  Set #{actuator.name} = 0")
      temp_override_program.addLine('Else')
      temp_override_program.addLine("  Set #{actuator.name} = NULL") # Allow normal operation
      temp_override_program.addLine('EndIf')

      program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      program_calling_manager.setName("#{heating_sch.name} program manager")
      program_calling_manager.setCallingPoint('BeginZoneTimestepAfterInitHeatBalance')
      program_calling_manager.addProgram(temp_override_program)
    end
  end

  # TODO
  #
  # @param heat_pump [TODO] TODO
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @return [TODO] TODO
  def self.set_heat_pump_temperatures(heat_pump, runner = nil)
    hp_ap = heat_pump.additional_properties

    # Sets:
    # 1. Minimum temperature (F) for HP compressor operation
    # 2. Maximum temperature (F) for HP supplemental heating operation
    if not heat_pump.backup_heating_switchover_temp.nil?
      hp_ap.hp_min_temp = heat_pump.backup_heating_switchover_temp
      hp_ap.supp_max_temp = heat_pump.backup_heating_switchover_temp
    else
      hp_ap.hp_min_temp = heat_pump.compressor_lockout_temp
      hp_ap.supp_max_temp = heat_pump.backup_heating_lockout_temp
    end

    # Error-checking
    # Can't do this in Schematron because temperatures can be defaulted
    if heat_pump.backup_type == HPXML::HeatPumpBackupTypeIntegrated
      hp_backup_fuel = heat_pump.backup_heating_fuel
    elsif not heat_pump.backup_system.nil?
      hp_backup_fuel = heat_pump.backup_system.heating_system_fuel
    end
    if (hp_backup_fuel == HPXML::FuelTypeElectricity) && (not runner.nil?)
      if (not hp_ap.hp_min_temp.nil?) && (not hp_ap.supp_max_temp.nil?) && ((hp_ap.hp_min_temp - hp_ap.supp_max_temp).abs < 5)
        if not heat_pump.backup_heating_switchover_temp.nil?
          runner.registerError('Switchover temperature should only be used for a heat pump with fossil fuel backup; use compressor lockout temperature instead.')
        else
          runner.registerError('Similar compressor/backup lockout temperatures should only be used for a heat pump with fossil fuel backup.')
        end
      end
    end
  end

  # TODO
  #
  # @param ncfl_ag [Double] Number of conditioned floors above grade in the dwelling unit
  # @return [TODO] TODO
  def self.get_default_duct_fraction_outside_conditioned_space(ncfl_ag)
    # Equation based on ASHRAE 152
    # https://www.energy.gov/eere/buildings/downloads/ashrae-standard-152-spreadsheet
    f_out = (ncfl_ag <= 1) ? 1.0 : 0.75
    return f_out
  end

  # TODO
  #
  # @param duct_type [TODO] TODO
  # @param ncfl_ag [Double] Number of conditioned floors above grade in the dwelling unit
  # @param cfa_served [TODO] TODO
  # @param n_returns [TODO] TODO
  # @return [TODO] TODO
  def self.get_default_duct_surface_area(duct_type, ncfl_ag, cfa_served, n_returns)
    # Equations based on ASHRAE 152
    # https://www.energy.gov/eere/buildings/downloads/ashrae-standard-152-spreadsheet

    # Fraction of primary ducts (ducts outside conditioned space)
    f_out = get_default_duct_fraction_outside_conditioned_space(ncfl_ag)

    if duct_type == HPXML::DuctTypeSupply
      primary_duct_area = 0.27 * cfa_served * f_out
      secondary_duct_area = 0.27 * cfa_served * (1.0 - f_out)
    elsif duct_type == HPXML::DuctTypeReturn
      b_r = (n_returns < 6) ? (0.05 * n_returns) : 0.25
      primary_duct_area = b_r * cfa_served * f_out
      secondary_duct_area = b_r * cfa_served * (1.0 - f_out)
    end

    return primary_duct_area, secondary_duct_area
  end

  # TODO
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @return [TODO] TODO
  def self.get_default_duct_locations(hpxml_bldg)
    primary_duct_location_hierarchy = [HPXML::LocationBasementConditioned,
                                       HPXML::LocationBasementUnconditioned,
                                       HPXML::LocationCrawlspaceConditioned,
                                       HPXML::LocationCrawlspaceVented,
                                       HPXML::LocationCrawlspaceUnvented,
                                       HPXML::LocationAtticVented,
                                       HPXML::LocationAtticUnvented,
                                       HPXML::LocationGarage]

    primary_duct_location = nil
    primary_duct_location_hierarchy.each do |location|
      if hpxml_bldg.has_location(location)
        primary_duct_location = location
        break
      end
    end
    secondary_duct_location = HPXML::LocationConditionedSpace

    return primary_duct_location, secondary_duct_location
  end

  # TODO
  #
  # @param f_chg [TODO] TODO
  # @return [TODO] TODO
  def self.get_charge_fault_cooling_coeff(f_chg)
    if f_chg <= 0
      qgr_values = [-9.46E-01, 4.93E-02, -1.18E-03, -1.15E+00]
      p_values = [-3.13E-01, 1.15E-02, 2.66E-03, -1.16E-01]
    else
      qgr_values = [-1.63E-01, 1.14E-02, -2.10E-04, -1.40E-01]
      p_values = [2.19E-01, -5.01E-03, 9.89E-04, 2.84E-01]
    end
    ff_chg_values = [26.67, 35.0]
    return qgr_values, p_values, ff_chg_values
  end

  # TODO
  #
  # @param f_chg [TODO] TODO
  # @return [TODO] TODO
  def self.get_charge_fault_heating_coeff(f_chg)
    if f_chg <= 0
      qgr_values = [-0.0338595, 0.0, 0.0202827, -2.6226343] # Add a zero term to combine cooling and heating calculation
      p_values = [0.0615649, 0.0, 0.0044554, -0.2598507] # Add a zero term to combine cooling and heating calculation
    else
      qgr_values = [-0.0029514, 0.0, 0.0007379, -0.0064112] # Add a zero term to combine cooling and heating calculation
      p_values = [-0.0594134, 0.0, 0.0159205, 1.8872153] # Add a zero term to combine cooling and heating calculation
    end
    ff_chg_values = [0.0, 8.33] # Add a zero term to combine cooling and heating calculation
    return qgr_values, p_values, ff_chg_values
  end

  # TODO
  #
  # @param fault_program [TODO] TODO
  # @param tin_sensor [TODO] TODO
  # @param tout_sensor [TODO] TODO
  # @param airflow_rated_defect_ratio [TODO] TODO
  # @param clg_or_htg_coil [TODO] TODO
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param f_chg [TODO] TODO
  # @param obj_name [String] Name for the OpenStudio object
  # @param mode [TODO] TODO
  # @param defect_ratio [TODO] TODO
  # @param hvac_ap [TODO] TODO
  # @return [TODO] TODO
  def self.add_install_quality_calculations(fault_program, tin_sensor, tout_sensor, airflow_rated_defect_ratio, clg_or_htg_coil, model, f_chg, obj_name, mode, defect_ratio, hvac_ap)
    if mode == :clg
      if clg_or_htg_coil.is_a? OpenStudio::Model::CoilCoolingDXSingleSpeed
        num_speeds = 1
        cap_fff_curves = [clg_or_htg_coil.totalCoolingCapacityFunctionOfFlowFractionCurve.to_CurveQuadratic.get]
        eir_pow_fff_curves = [clg_or_htg_coil.energyInputRatioFunctionOfFlowFractionCurve.to_CurveQuadratic.get]
      elsif clg_or_htg_coil.is_a? OpenStudio::Model::CoilCoolingDXMultiSpeed
        num_speeds = clg_or_htg_coil.stages.size
        if clg_or_htg_coil.stages[0].totalCoolingCapacityFunctionofFlowFractionCurve.to_CurveQuadratic.is_initialized
          cap_fff_curves = clg_or_htg_coil.stages.map { |stage| stage.totalCoolingCapacityFunctionofFlowFractionCurve.to_CurveQuadratic.get }
          eir_pow_fff_curves = clg_or_htg_coil.stages.map { |stage| stage.energyInputRatioFunctionofFlowFractionCurve.to_CurveQuadratic.get }
        else
          cap_fff_curves = clg_or_htg_coil.stages.map { |stage| stage.totalCoolingCapacityFunctionofFlowFractionCurve.to_TableLookup.get }
          eir_pow_fff_curves = clg_or_htg_coil.stages.map { |stage| stage.energyInputRatioFunctionofFlowFractionCurve.to_TableLookup.get }
        end
      elsif clg_or_htg_coil.is_a? OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit
        num_speeds = 1
        cap_fff_curves = [clg_or_htg_coil.totalCoolingCapacityCurve.to_CurveQuadLinear.get] # quadlinear curve, only forth term is for airflow
        eir_pow_fff_curves = [clg_or_htg_coil.coolingPowerConsumptionCurve.to_CurveQuadLinear.get] # quadlinear curve, only forth term is for airflow
        # variables are the same for eir and cap curve
        var1_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 1 Value')
        var1_sensor.setName('Cool Cap Curve Var 1')
        var1_sensor.setKeyName(cap_fff_curves[0].name.to_s)
        var2_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 2 Value')
        var2_sensor.setName('Cool Cap Curve Var 2')
        var2_sensor.setKeyName(cap_fff_curves[0].name.to_s)
        var4_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 4 Value')
        var4_sensor.setName('Cool Cap Curve Var 4')
        var4_sensor.setKeyName(cap_fff_curves[0].name.to_s)
      else
        fail 'cooling coil not supported'
      end
    elsif mode == :htg
      if clg_or_htg_coil.is_a? OpenStudio::Model::CoilHeatingDXSingleSpeed
        num_speeds = 1
        cap_fff_curves = [clg_or_htg_coil.totalHeatingCapacityFunctionofFlowFractionCurve.to_CurveQuadratic.get]
        eir_pow_fff_curves = [clg_or_htg_coil.energyInputRatioFunctionofFlowFractionCurve.to_CurveQuadratic.get]
      elsif clg_or_htg_coil.is_a? OpenStudio::Model::CoilHeatingDXMultiSpeed
        num_speeds = clg_or_htg_coil.stages.size
        if clg_or_htg_coil.stages[0].heatingCapacityFunctionofFlowFractionCurve.to_CurveQuadratic.is_initialized
          cap_fff_curves = clg_or_htg_coil.stages.map { |stage| stage.heatingCapacityFunctionofFlowFractionCurve.to_CurveQuadratic.get }
          eir_pow_fff_curves = clg_or_htg_coil.stages.map { |stage| stage.energyInputRatioFunctionofFlowFractionCurve.to_CurveQuadratic.get }
        else
          cap_fff_curves = clg_or_htg_coil.stages.map { |stage| stage.heatingCapacityFunctionofFlowFractionCurve.to_TableLookup.get }
          eir_pow_fff_curves = clg_or_htg_coil.stages.map { |stage| stage.energyInputRatioFunctionofFlowFractionCurve.to_TableLookup.get }
        end
      elsif clg_or_htg_coil.is_a? OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit
        num_speeds = 1
        cap_fff_curves = [clg_or_htg_coil.heatingCapacityCurve.to_CurveQuadLinear.get] # quadlinear curve, only forth term is for airflow
        eir_pow_fff_curves = [clg_or_htg_coil.heatingPowerConsumptionCurve.to_CurveQuadLinear.get] # quadlinear curve, only forth term is for airflow
        # variables are the same for eir and cap curve
        var1_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 1 Value')
        var1_sensor.setName('Heat Cap Curve Var 1')
        var1_sensor.setKeyName(cap_fff_curves[0].name.to_s)
        var2_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 2 Value')
        var2_sensor.setName('Heat Cap Curve Var 2')
        var2_sensor.setKeyName(cap_fff_curves[0].name.to_s)
        var4_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 4 Value')
        var4_sensor.setName('Heat Cap Curve Var 4')
        var4_sensor.setKeyName(cap_fff_curves[0].name.to_s)
      else
        fail 'heating coil not supported'
      end
    end

    # Apply Cutler curve airflow coefficients to later equations
    if mode == :clg
      cap_fflow_spec, eir_fflow_spec = get_cool_cap_eir_fflow_spec(HPXML::HVACCompressorTypeSingleStage)
      qgr_values, p_values, ff_chg_values = get_charge_fault_cooling_coeff(f_chg)
      suffix = 'clg'
    elsif mode == :htg
      cap_fflow_spec, eir_fflow_spec = get_heat_cap_eir_fflow_spec(HPXML::HVACCompressorTypeSingleStage)
      qgr_values, p_values, ff_chg_values = get_charge_fault_heating_coeff(f_chg)
      suffix = 'htg'
    end
    fault_program.addLine("Set a1_AF_Qgr_#{suffix} = #{cap_fflow_spec[0][0]}")
    fault_program.addLine("Set a2_AF_Qgr_#{suffix} = #{cap_fflow_spec[0][1]}")
    fault_program.addLine("Set a3_AF_Qgr_#{suffix} = #{cap_fflow_spec[0][2]}")
    fault_program.addLine("Set a1_AF_EIR_#{suffix} = #{eir_fflow_spec[0][0]}")
    fault_program.addLine("Set a2_AF_EIR_#{suffix} = #{eir_fflow_spec[0][1]}")
    fault_program.addLine("Set a3_AF_EIR_#{suffix} = #{eir_fflow_spec[0][2]}")

    # charge fault coefficients
    fault_program.addLine("Set a1_CH_Qgr_#{suffix} = #{qgr_values[0]}")
    fault_program.addLine("Set a2_CH_Qgr_#{suffix} = #{qgr_values[1]}")
    fault_program.addLine("Set a3_CH_Qgr_#{suffix} = #{qgr_values[2]}")
    fault_program.addLine("Set a4_CH_Qgr_#{suffix} = #{qgr_values[3]}")

    fault_program.addLine("Set a1_CH_P_#{suffix} = #{p_values[0]}")
    fault_program.addLine("Set a2_CH_P_#{suffix} = #{p_values[1]}")
    fault_program.addLine("Set a3_CH_P_#{suffix} = #{p_values[2]}")
    fault_program.addLine("Set a4_CH_P_#{suffix} = #{p_values[3]}")

    fault_program.addLine("Set q0_CH_#{suffix} = a1_CH_Qgr_#{suffix}")
    fault_program.addLine("Set q1_CH_#{suffix} = a2_CH_Qgr_#{suffix}*#{tin_sensor.name}")
    fault_program.addLine("Set q2_CH_#{suffix} = a3_CH_Qgr_#{suffix}*#{tout_sensor.name}")
    fault_program.addLine("Set q3_CH_#{suffix} = a4_CH_Qgr_#{suffix}*F_CH")
    fault_program.addLine("Set Y_CH_Q_#{suffix} = 1 + ((q0_CH_#{suffix}+(q1_CH_#{suffix})+(q2_CH_#{suffix})+(q3_CH_#{suffix}))*F_CH)")

    fault_program.addLine("Set p1_CH_#{suffix} = a1_CH_P_#{suffix}")
    fault_program.addLine("Set p2_CH_#{suffix} = a2_CH_P_#{suffix}*#{tin_sensor.name}")
    fault_program.addLine("Set p3_CH_#{suffix} = a3_CH_P_#{suffix}*#{tout_sensor.name}")
    fault_program.addLine("Set p4_CH_#{suffix} = a4_CH_P_#{suffix}*F_CH")
    fault_program.addLine("Set Y_CH_COP_#{suffix} = Y_CH_Q_#{suffix}/(1 + (p1_CH_#{suffix}+(p2_CH_#{suffix})+(p3_CH_#{suffix})+(p4_CH_#{suffix}))*F_CH)")

    # air flow defect and charge defect combined to modify airflow curve output
    ff_ch = 1.0 / (1.0 + (qgr_values[0] + (qgr_values[1] * ff_chg_values[0]) + (qgr_values[2] * ff_chg_values[1]) + (qgr_values[3] * f_chg)) * f_chg)
    fault_program.addLine("Set FF_CH = #{ff_ch.round(3)}")

    for speed in 0..(num_speeds - 1)
      cap_fff_curve = cap_fff_curves[speed]
      cap_fff_act = OpenStudio::Model::EnergyManagementSystemActuator.new(cap_fff_curve, *EPlus::EMSActuatorCurveResult)
      cap_fff_act.setName("#{obj_name} cap act #{suffix}")

      eir_pow_fff_curve = eir_pow_fff_curves[speed]
      eir_pow_act = OpenStudio::Model::EnergyManagementSystemActuator.new(eir_pow_fff_curve, *EPlus::EMSActuatorCurveResult)
      eir_pow_act.setName("#{obj_name} eir pow act #{suffix}")

      fault_program.addLine("Set FF_AF_#{suffix} = 1.0 + (#{airflow_rated_defect_ratio[speed].round(3)})")
      fault_program.addLine("Set q_AF_CH_#{suffix} = (a1_AF_Qgr_#{suffix}) + ((a2_AF_Qgr_#{suffix})*FF_CH) + ((a3_AF_Qgr_#{suffix})*FF_CH*FF_CH)")
      fault_program.addLine("Set eir_AF_CH_#{suffix} = (a1_AF_EIR_#{suffix}) + ((a2_AF_EIR_#{suffix})*FF_CH) + ((a3_AF_EIR_#{suffix})*FF_CH*FF_CH)")
      fault_program.addLine("Set p_CH_Q_#{suffix} = Y_CH_Q_#{suffix}/q_AF_CH_#{suffix}")
      fault_program.addLine("Set p_CH_COP_#{suffix} = Y_CH_COP_#{suffix}*eir_AF_CH_#{suffix}")
      fault_program.addLine("Set FF_AF_comb_#{suffix} = FF_CH * FF_AF_#{suffix}")
      fault_program.addLine("Set p_AF_Q_#{suffix} = (a1_AF_Qgr_#{suffix}) + ((a2_AF_Qgr_#{suffix})*FF_AF_comb_#{suffix}) + ((a3_AF_Qgr_#{suffix})*FF_AF_comb_#{suffix}*FF_AF_comb_#{suffix})")
      fault_program.addLine("Set p_AF_COP_#{suffix} = 1.0 / ((a1_AF_EIR_#{suffix}) + ((a2_AF_EIR_#{suffix})*FF_AF_comb_#{suffix}) + ((a3_AF_EIR_#{suffix})*FF_AF_comb_#{suffix}*FF_AF_comb_#{suffix}))")
      fault_program.addLine("Set FF_AF_nodef_#{suffix} = FF_AF_#{suffix} / (1 + (#{defect_ratio.round(3)}))")
      fault_program.addLine("Set CAP_Cutler_Curve_Pre_#{suffix} = (a1_AF_Qgr_#{suffix}) + ((a2_AF_Qgr_#{suffix})*FF_AF_nodef_#{suffix}) + ((a3_AF_Qgr_#{suffix})*FF_AF_nodef_#{suffix}*FF_AF_nodef_#{suffix})")
      fault_program.addLine("Set EIR_Cutler_Curve_Pre_#{suffix} = (a1_AF_EIR_#{suffix}) + ((a2_AF_EIR_#{suffix})*FF_AF_nodef_#{suffix}) + ((a3_AF_EIR_#{suffix})*FF_AF_nodef_#{suffix}*FF_AF_nodef_#{suffix})")
      fault_program.addLine("Set CAP_Cutler_Curve_After_#{suffix} = p_CH_Q_#{suffix} * p_AF_Q_#{suffix}")
      fault_program.addLine("Set EIR_Cutler_Curve_After_#{suffix} = (1.0 / (p_CH_COP_#{suffix} * p_AF_COP_#{suffix}))")
      fault_program.addLine("Set CAP_IQ_adj_#{suffix} = CAP_Cutler_Curve_After_#{suffix} / CAP_Cutler_Curve_Pre_#{suffix}")
      fault_program.addLine("Set EIR_IQ_adj_#{suffix} = EIR_Cutler_Curve_After_#{suffix} / EIR_Cutler_Curve_Pre_#{suffix}")
      # NOTE: heat pump (cooling) curves don't exhibit expected trends at extreme faults;
      if (not clg_or_htg_coil.is_a? OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit) && (not clg_or_htg_coil.is_a? OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit)
        cap_fff_specs_coeff = (mode == :clg) ? hvac_ap.cool_cap_fflow_spec[speed] : hvac_ap.heat_cap_fflow_spec[speed]
        eir_fff_specs_coeff = (mode == :clg) ? hvac_ap.cool_eir_fflow_spec[speed] : hvac_ap.heat_eir_fflow_spec[speed]
        fault_program.addLine("Set CAP_c1_#{suffix} = #{cap_fff_specs_coeff[0]}")
        fault_program.addLine("Set CAP_c2_#{suffix} = #{cap_fff_specs_coeff[1]}")
        fault_program.addLine("Set CAP_c3_#{suffix} = #{cap_fff_specs_coeff[2]}")
        fault_program.addLine("Set EIR_c1_#{suffix} = #{eir_fff_specs_coeff[0]}")
        fault_program.addLine("Set EIR_c2_#{suffix} = #{eir_fff_specs_coeff[1]}")
        fault_program.addLine("Set EIR_c3_#{suffix} = #{eir_fff_specs_coeff[2]}")
        fault_program.addLine("Set cap_curve_v_pre_#{suffix} = (CAP_c1_#{suffix}) + ((CAP_c2_#{suffix})*FF_AF_nodef_#{suffix}) + ((CAP_c3_#{suffix})*FF_AF_nodef_#{suffix}*FF_AF_nodef_#{suffix})")
        fault_program.addLine("Set eir_curve_v_pre_#{suffix} = (EIR_c1_#{suffix}) + ((EIR_c2_#{suffix})*FF_AF_nodef_#{suffix}) + ((EIR_c3_#{suffix})*FF_AF_nodef_#{suffix}*FF_AF_nodef_#{suffix})")
        fault_program.addLine("Set #{cap_fff_act.name} = cap_curve_v_pre_#{suffix} * CAP_IQ_adj_#{suffix}")
        fault_program.addLine("Set #{eir_pow_act.name} = eir_curve_v_pre_#{suffix} * EIR_IQ_adj_#{suffix}")
      else
        fault_program.addLine("Set CAP_c1_#{suffix} = #{cap_fff_curve.coefficient1Constant}")
        fault_program.addLine("Set CAP_c2_#{suffix} = #{cap_fff_curve.coefficient2w}")
        fault_program.addLine("Set CAP_c3_#{suffix} = #{cap_fff_curve.coefficient3x}")
        fault_program.addLine("Set CAP_c4_#{suffix} = #{cap_fff_curve.coefficient4y}")
        fault_program.addLine("Set CAP_c5_#{suffix} = #{cap_fff_curve.coefficient5z}")
        fault_program.addLine("Set Pow_c1_#{suffix} = #{eir_pow_fff_curve.coefficient1Constant}")
        fault_program.addLine("Set Pow_c2_#{suffix} = #{eir_pow_fff_curve.coefficient2w}")
        fault_program.addLine("Set Pow_c3_#{suffix} = #{eir_pow_fff_curve.coefficient3x}")
        fault_program.addLine("Set Pow_c4_#{suffix} = #{eir_pow_fff_curve.coefficient4y}")
        fault_program.addLine("Set Pow_c5_#{suffix} = #{eir_pow_fff_curve.coefficient5z}")
        fault_program.addLine("Set cap_curve_v_pre_#{suffix} = CAP_c1_#{suffix} + ((CAP_c2_#{suffix})*#{var1_sensor.name}) + (CAP_c3_#{suffix}*#{var2_sensor.name}) + (CAP_c4_#{suffix}*FF_AF_nodef_#{suffix}) + (CAP_c5_#{suffix}*#{var4_sensor.name})")
        fault_program.addLine("Set pow_curve_v_pre_#{suffix} = Pow_c1_#{suffix} + ((Pow_c2_#{suffix})*#{var1_sensor.name}) + (Pow_c3_#{suffix}*#{var2_sensor.name}) + (Pow_c4_#{suffix}*FF_AF_nodef_#{suffix})+ (Pow_c5_#{suffix}*#{var4_sensor.name})")
        fault_program.addLine("Set #{cap_fff_act.name} = cap_curve_v_pre_#{suffix} * CAP_IQ_adj_#{suffix}")
        fault_program.addLine("Set #{eir_pow_act.name} = pow_curve_v_pre_#{suffix} * EIR_IQ_adj_#{suffix} * CAP_IQ_adj_#{suffix}") # equationfit power curve modifies power instead of cop/eir, should also multiply capacity adjustment
      end
      fault_program.addLine("If #{cap_fff_act.name} < 0.0")
      fault_program.addLine("  Set #{cap_fff_act.name} = 1.0")
      fault_program.addLine('EndIf')
      fault_program.addLine("If #{eir_pow_act.name} < 0.0")
      fault_program.addLine("  Set #{eir_pow_act.name} = 1.0")
      fault_program.addLine('EndIf')
    end
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param heating_system [TODO] TODO
  # @param cooling_system [TODO] TODO
  # @param unitary_system [TODO] TODO
  # @param htg_coil [TODO] TODO
  # @param clg_coil [TODO] TODO
  # @param control_zone [OpenStudio::Model::ThermalZone] Conditioned space thermal zone
  # @return [TODO] TODO
  def self.apply_installation_quality(model, heating_system, cooling_system, unitary_system, htg_coil, clg_coil, control_zone)
    if not cooling_system.nil?
      charge_defect_ratio = cooling_system.charge_defect_ratio
      cool_airflow_defect_ratio = cooling_system.airflow_defect_ratio
      clg_ap = cooling_system.additional_properties
    end
    if not heating_system.nil?
      heat_airflow_defect_ratio = heating_system.airflow_defect_ratio
      htg_ap = heating_system.additional_properties
    end
    return if (charge_defect_ratio.to_f.abs < 0.001) && (cool_airflow_defect_ratio.to_f.abs < 0.001) && (heat_airflow_defect_ratio.to_f.abs < 0.001)

    cool_airflow_rated_defect_ratio = []
    if (not clg_coil.nil?) && (cooling_system.fraction_cool_load_served > 0)
      clg_ap = cooling_system.additional_properties
      clg_cfm = cooling_system.cooling_airflow_cfm
      if clg_coil.to_CoilCoolingDXSingleSpeed.is_initialized || clg_coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
        cool_airflow_rated_defect_ratio = [UnitConversions.convert(clg_cfm, 'cfm', 'm^3/s') / clg_coil.ratedAirFlowRate.get - 1.0]
      elsif clg_coil.to_CoilCoolingDXMultiSpeed.is_initialized
        cool_airflow_rated_defect_ratio = clg_coil.stages.zip(clg_ap.cool_fan_speed_ratios).map { |stage, speed_ratio| UnitConversions.convert(clg_cfm * speed_ratio, 'cfm', 'm^3/s') / stage.ratedAirFlowRate.get - 1.0 }
      end
    end

    heat_airflow_rated_defect_ratio = []
    if (not htg_coil.nil?) && (heating_system.fraction_heat_load_served > 0)
      htg_ap = heating_system.additional_properties
      htg_cfm = heating_system.heating_airflow_cfm
      if htg_coil.to_CoilHeatingDXSingleSpeed.is_initialized || htg_coil.to_CoilHeatingWaterToAirHeatPumpEquationFit.is_initialized
        heat_airflow_rated_defect_ratio = [UnitConversions.convert(htg_cfm, 'cfm', 'm^3/s') / htg_coil.ratedAirFlowRate.get - 1.0]
      elsif htg_coil.to_CoilHeatingDXMultiSpeed.is_initialized
        heat_airflow_rated_defect_ratio = htg_coil.stages.zip(htg_ap.heat_fan_speed_ratios).map { |stage, speed_ratio| UnitConversions.convert(htg_cfm * speed_ratio, 'cfm', 'm^3/s') / stage.ratedAirFlowRate.get - 1.0 }
      end
    end

    return if cool_airflow_rated_defect_ratio.empty? && heat_airflow_rated_defect_ratio.empty?

    obj_name = "#{unitary_system.name} IQ"

    tin_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Mean Air Temperature')
    tin_sensor.setName("#{obj_name} tin s")
    tin_sensor.setKeyName(control_zone.name.to_s)

    tout_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Outdoor Air Drybulb Temperature')
    tout_sensor.setName("#{obj_name} tt s")
    tout_sensor.setKeyName(control_zone.name.to_s)

    fault_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    fault_program.setName("#{obj_name} program")

    f_chg = charge_defect_ratio.to_f
    fault_program.addLine("Set F_CH = #{f_chg.round(3)}")

    if not cool_airflow_rated_defect_ratio.empty?
      add_install_quality_calculations(fault_program, tin_sensor, tout_sensor, cool_airflow_rated_defect_ratio, clg_coil, model, f_chg, obj_name, :clg, cool_airflow_defect_ratio, clg_ap)
    end

    if not heat_airflow_rated_defect_ratio.empty?
      add_install_quality_calculations(fault_program, tin_sensor, tout_sensor, heat_airflow_rated_defect_ratio, htg_coil, model, f_chg, obj_name, :htg, heat_airflow_defect_ratio, htg_ap)
    end
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName("#{obj_name} program manager")
    program_calling_manager.setCallingPoint('BeginZoneTimestepAfterInitHeatBalance')
    program_calling_manager.addProgram(fault_program)
  end

  # TODO
  #
  # @param heat_pump [TODO] TODO
  # @param unit_multiplier [Integer] Number of similar dwelling units
  # @param design_airflow [TODO] TODO
  # @param max_heating_airflow [TODO] TODO
  # @param fan_watts_per_cfm [TODO] TODO
  # @return [TODO] TODO
  def self.calculate_heat_pump_defrost_load_power_watts(heat_pump, unit_multiplier, design_airflow, max_heating_airflow, fan_watts_per_cfm)
    # Calculate q_dot and p_dot
    # q_dot is used for EMS program to account for introduced cooling load and supp coil power consumption by actuating other equipment objects
    # p_dot is used for calculating coil defrost compressor power consumption
    is_ducted = !heat_pump.distribution_system_idref.nil?
    # determine defrost cooling rate and defrost cooling cop based on whether ducted
    if is_ducted
      # 0.45 is from Jon's lab and field data analysis, defrost is too short to reach steady state so using cutler curve is not correct
      # 1.0 is from Jon's lab and field data analysis, defrost is too short to reach steady state so using cutler curve is not correct
      # Transient effect already accounted
      capacity_defrost_multiplier = 0.45
      cop_defrost_multiplier = 1.0
    else
      capacity_defrost_multiplier = 0.1
      cop_defrost_multiplier = 0.08
    end
    nominal_cooling_capacity_1x = heat_pump.cooling_capacity / unit_multiplier
    max_heating_airflow_1x = max_heating_airflow / unit_multiplier
    design_airflow_1x = design_airflow / unit_multiplier
    defrost_flow_fraction = max_heating_airflow_1x / design_airflow_1x
    defrost_power_fraction = defrost_flow_fraction**3
    power_design = fan_watts_per_cfm * design_airflow_1x
    p_dot_blower = power_design * defrost_power_fraction
    # Based on manufacturer data for ~70 systems ranging from 1.5 to 5 tons with varying efficiency levels
    p_dot_odu_fan = 44.348 * UnitConversions.convert(nominal_cooling_capacity_1x, 'Btu/hr', 'ton') + 62.452
    rated_clg_cop = heat_pump.additional_properties.cool_rated_cops[-1]
    q_dot_defrost = UnitConversions.convert(nominal_cooling_capacity_1x, 'Btu/hr', 'W') * capacity_defrost_multiplier
    cop_defrost = rated_clg_cop * cop_defrost_multiplier
    p_dot_defrost = (q_dot_defrost / cop_defrost - p_dot_odu_fan + p_dot_blower) * unit_multiplier # p_dot_defrost is used in coil object, which needs to be scaled up for unit multiplier
    return q_dot_defrost, p_dot_defrost
  end

  # TODO
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param htg_coil [TODO] TODO
  # @param air_loop_unitary [OpenStudio::Model::AirLoopHVACUnitarySystem] Air loop for the HVAC system
  # @param conditioned_space [TODO] TODO
  # @param htg_supp_coil [TODO] TODO
  # @param heat_pump [TODO] TODO
  # @param q_dot_defrost [TODO] TODO
  # @return [TODO] TODO
  def self.apply_advanced_defrost(model, htg_coil, air_loop_unitary, conditioned_space, htg_supp_coil, heat_pump, q_dot_defrost)
    if htg_supp_coil.nil?
      backup_system = heat_pump.backup_system
      if backup_system.nil?
        supp_sys_capacity = 0.0
        supp_sys_power_level = 0.0
        supp_sys_fuel = HPXML::FuelTypeElectricity
      else
        supp_sys_fuel = backup_system.heating_system_fuel
        supp_sys_capacity = UnitConversions.convert(backup_system.heating_capacity, 'Btu/hr', 'W')
        supp_sys_efficiency = backup_system.heating_efficiency_percent
        supp_sys_efficiency = backup_system.heating_efficiency_afue if supp_sys_efficiency.nil?
        supp_sys_power_level = [supp_sys_capacity, q_dot_defrost].min / supp_sys_efficiency # Assume perfect tempering
      end
    else
      supp_sys_fuel = heat_pump.backup_heating_fuel
      is_ducted = !heat_pump.distribution_system_idref.nil?
      if is_ducted
        supp_sys_capacity = UnitConversions.convert(heat_pump.backup_heating_capacity, 'Btu/hr', 'W')
        supp_sys_efficiency = heat_pump.backup_heating_efficiency_percent
        supp_sys_efficiency = heat_pump.backup_heating_efficiency_afue if supp_sys_efficiency.nil?
        supp_sys_power_level = [supp_sys_capacity, q_dot_defrost].min / supp_sys_efficiency # Assume perfect tempering
      else
        # Practically no integrated supplemental system for ductless
        # Sometimes integrated backup systems are added to ductless to avoid unmet loads, so it shouldn't count here to avoid overestimating backup system energy use
        supp_sys_capacity = 0.0
        supp_sys_power_level = 0.0
      end
    end
    # other equipment actuator
    defrost_heat_load_oed = OpenStudio::Model::OtherEquipmentDefinition.new(model)
    defrost_heat_load_oed.setName("#{air_loop_unitary.name} defrost heat load def")
    defrost_heat_load_oed.setDesignLevel(0)
    defrost_heat_load_oed.setFractionRadiant(0)
    defrost_heat_load_oed.setFractionLatent(0)
    defrost_heat_load_oed.setFractionLost(0)
    defrost_heat_load_oe = OpenStudio::Model::OtherEquipment.new(defrost_heat_load_oed)
    defrost_heat_load_oe.setName("#{air_loop_unitary.name} defrost heat load")
    defrost_heat_load_oe.setSpace(conditioned_space)
    defrost_heat_load_oe.setSchedule(model.alwaysOnDiscreteSchedule)

    defrost_heat_load_oe_act = OpenStudio::Model::EnergyManagementSystemActuator.new(defrost_heat_load_oe, *EPlus::EMSActuatorOtherEquipmentPower, defrost_heat_load_oe.space.get)
    defrost_heat_load_oe_act.setName("#{defrost_heat_load_oe.name} act")

    energyplus_fuel = EPlus.fuel_type(supp_sys_fuel)
    defrost_supp_heat_energy_oed = OpenStudio::Model::OtherEquipmentDefinition.new(model)
    defrost_supp_heat_energy_oed.setName("#{air_loop_unitary.name} supp heat energy def")
    defrost_supp_heat_energy_oed.setDesignLevel(0)
    defrost_supp_heat_energy_oed.setFractionRadiant(0)
    defrost_supp_heat_energy_oed.setFractionLatent(0)
    defrost_supp_heat_energy_oed.setFractionLost(1)
    defrost_supp_heat_energy_oe = OpenStudio::Model::OtherEquipment.new(defrost_supp_heat_energy_oed)
    defrost_supp_heat_energy_oe.setName("#{air_loop_unitary.name} defrost supp heat energy")
    defrost_supp_heat_energy_oe.setSpace(conditioned_space)
    defrost_supp_heat_energy_oe.setFuelType(energyplus_fuel)
    defrost_supp_heat_energy_oe.setSchedule(model.alwaysOnDiscreteSchedule)
    defrost_supp_heat_energy_oe.setEndUseSubcategory(Constants.ObjectNameBackupSuppHeat)
    defrost_supp_heat_energy_oe.additionalProperties.setFeature('HPXML_ID', heat_pump.id) # Used by reporting measure
    defrost_supp_heat_energy_oe.additionalProperties.setFeature('IsHeatPumpBackup', true) # Used by reporting measure

    defrost_supp_heat_energy_oe_act = OpenStudio::Model::EnergyManagementSystemActuator.new(defrost_supp_heat_energy_oe, *EPlus::EMSActuatorOtherEquipmentPower, defrost_supp_heat_energy_oe.space.get)
    defrost_supp_heat_energy_oe_act.setName("#{defrost_supp_heat_energy_oe.name} act")

    # Sensors
    tout_db_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Drybulb Temperature')
    tout_db_sensor.setName("#{air_loop_unitary.name} tout s")
    tout_db_sensor.setKeyName('Environment')
    htg_coil_rtf_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Heating Coil Runtime Fraction')
    htg_coil_rtf_sensor.setName("#{htg_coil.name} rtf s")
    htg_coil_rtf_sensor.setKeyName("#{htg_coil.name}")

    # EMS program
    max_oat_defrost = htg_coil.maximumOutdoorDryBulbTemperatureforDefrostOperation
    program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    program.setName("#{air_loop_unitary.name} defrost program")
    program.addLine("If #{tout_db_sensor.name} <= #{max_oat_defrost}")
    program.addLine("  Set hp_defrost_time_fraction = #{htg_coil.defrostTimePeriodFraction}")
    program.addLine("  Set supp_design_level = #{supp_sys_power_level}")
    program.addLine("  Set q_dot_defrost = #{q_dot_defrost}")
    program.addLine("  Set supp_delivered_htg = #{[supp_sys_capacity, q_dot_defrost].min}")
    program.addLine('  Set defrost_load_design_level = supp_delivered_htg - q_dot_defrost')
    program.addLine("  Set fraction_defrost = hp_defrost_time_fraction * #{htg_coil_rtf_sensor.name}")
    program.addLine("  Set #{defrost_heat_load_oe_act.name} = fraction_defrost * defrost_load_design_level")
    program.addLine("  Set #{defrost_supp_heat_energy_oe_act.name} = fraction_defrost * supp_design_level")
    program.addLine('Else')
    program.addLine("  Set #{defrost_heat_load_oe_act.name} = 0")
    program.addLine("  Set #{defrost_supp_heat_energy_oe_act.name} = 0")
    program.addLine('EndIf')

    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName(program.name.to_s + 'calling manager')
    program_calling_manager.setCallingPoint('InsideHVACSystemIterationLoop')
    program_calling_manager.addProgram(program)
  end

  # TODO
  #
  # @return [TODO] TODO
  def self.get_default_gshp_pump_power()
    return 30.0 # W/ton, per ANSI/RESNET/ICC 301-2019 Section 4.4.5 (closed loop)
  end

  # TODO
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @return [TODO] TODO
  def self.apply_shared_systems(hpxml_bldg)
    applied_clg = apply_shared_cooling_systems(hpxml_bldg)
    applied_htg = apply_shared_heating_systems(hpxml_bldg)
    return unless (applied_clg || applied_htg)

    # Remove WLHP if not serving heating nor cooling
    hpxml_bldg.heat_pumps.each do |hp|
      next unless hp.heat_pump_type == HPXML::HVACTypeHeatPumpWaterLoopToAir
      next if hp.fraction_heat_load_served > 0
      next if hp.fraction_cool_load_served > 0

      hp.delete
    end

    # Remove any orphaned HVAC distributions
    hpxml_bldg.hvac_distributions.each do |hvac_distribution|
      hvac_systems = []
      hpxml_bldg.hvac_systems.each do |hvac_system|
        next if hvac_system.distribution_system_idref.nil?
        next unless hvac_system.distribution_system_idref == hvac_distribution.id

        hvac_systems << hvac_system
      end
      next unless hvac_systems.empty?

      hvac_distribution.delete
    end
  end

  # TODO
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @return [TODO] TODO
  def self.apply_shared_cooling_systems(hpxml_bldg)
    applied = false
    hpxml_bldg.cooling_systems.each do |cooling_system|
      next unless cooling_system.is_shared_system

      applied = true
      wlhp = nil
      distribution_system = cooling_system.distribution_system
      distribution_type = distribution_system.distribution_system_type

      # Calculate air conditioner SEER equivalent
      n_dweq = cooling_system.number_of_units_served.to_f
      aux = cooling_system.shared_loop_watts

      if cooling_system.cooling_system_type == HPXML::HVACTypeChiller

        # Chiller w/ baseboard or fan coil or water loop heat pump
        cap = cooling_system.cooling_capacity
        chiller_input = UnitConversions.convert(cooling_system.cooling_efficiency_kw_per_ton * UnitConversions.convert(cap, 'Btu/hr', 'ton'), 'kW', 'W')
        if distribution_type == HPXML::HVACDistributionTypeHydronic
          if distribution_system.hydronic_type == HPXML::HydronicTypeWaterLoop
            wlhp = hpxml_bldg.heat_pumps.find { |hp| hp.heat_pump_type == HPXML::HVACTypeHeatPumpWaterLoopToAir }
            aux_dweq = wlhp.cooling_capacity / wlhp.cooling_efficiency_eer
          else
            aux_dweq = 0.0
          end
        elsif distribution_type == HPXML::HVACDistributionTypeAir
          if distribution_system.air_type == HPXML::AirTypeFanCoil
            aux_dweq = cooling_system.fan_coil_watts
          end
        end
        # ANSI/RESNET/ICC 301-2019 Equation 4.4-2
        seer_eq = (cap - 3.41 * aux - 3.41 * aux_dweq * n_dweq) / (chiller_input + aux + aux_dweq * n_dweq)

      elsif cooling_system.cooling_system_type == HPXML::HVACTypeCoolingTower

        # Cooling tower w/ water loop heat pump
        if distribution_type == HPXML::HVACDistributionTypeHydronic
          if distribution_system.hydronic_type == HPXML::HydronicTypeWaterLoop
            wlhp = hpxml_bldg.heat_pumps.find { |hp| hp.heat_pump_type == HPXML::HVACTypeHeatPumpWaterLoopToAir }
            wlhp_cap = wlhp.cooling_capacity
            wlhp_input = wlhp_cap / wlhp.cooling_efficiency_eer
          end
        end
        # ANSI/RESNET/ICC 301-2019 Equation 4.4-3
        seer_eq = (wlhp_cap - 3.41 * aux / n_dweq) / (wlhp_input + aux / n_dweq)

      else
        fail "Unexpected cooling system type '#{cooling_system.cooling_system_type}'."
      end

      if seer_eq <= 0
        fail "Negative SEER equivalent calculated for cooling system '#{cooling_system.id}', double-check inputs."
      end

      cooling_system.cooling_system_type = HPXML::HVACTypeCentralAirConditioner
      cooling_system.cooling_efficiency_seer = seer_eq.round(2)
      cooling_system.cooling_efficiency_kw_per_ton = nil
      cooling_system.cooling_capacity = nil # Autosize the equipment
      cooling_system.is_shared_system = false
      cooling_system.number_of_units_served = nil
      cooling_system.shared_loop_watts = nil
      cooling_system.shared_loop_motor_efficiency = nil
      cooling_system.fan_coil_watts = nil

      # Assign new distribution system to air conditioner
      if distribution_type == HPXML::HVACDistributionTypeHydronic
        if distribution_system.hydronic_type == HPXML::HydronicTypeWaterLoop
          # Assign WLHP air distribution
          cooling_system.distribution_system_idref = wlhp.distribution_system_idref
          wlhp.fraction_cool_load_served = 0.0
          wlhp.fraction_heat_load_served = 0.0
        else
          # Assign DSE=1
          hpxml_bldg.hvac_distributions.add(id: "#{cooling_system.id}AirDistributionSystem",
                                            distribution_system_type: HPXML::HVACDistributionTypeDSE,
                                            annual_cooling_dse: 1.0,
                                            annual_heating_dse: 1.0)
          cooling_system.distribution_system_idref = hpxml_bldg.hvac_distributions[-1].id
        end
      elsif (distribution_type == HPXML::HVACDistributionTypeAir) && (distribution_system.air_type == HPXML::AirTypeFanCoil)
        # Convert "fan coil" air distribution system to "regular velocity"
        if distribution_system.hvac_systems.size > 1
          # Has attached heating system, so create a copy specifically for the cooling system
          hpxml_bldg.hvac_distributions.add(id: "#{distribution_system.id}_#{cooling_system.id}",
                                            distribution_system_type: distribution_system.distribution_system_type,
                                            air_type: distribution_system.air_type,
                                            number_of_return_registers: distribution_system.number_of_return_registers,
                                            conditioned_floor_area_served: distribution_system.conditioned_floor_area_served)
          distribution_system.duct_leakage_measurements.each do |lm|
            hpxml_bldg.hvac_distributions[-1].duct_leakage_measurements << lm.dup
          end
          distribution_system.ducts.each do |d|
            hpxml_bldg.hvac_distributions[-1].ducts << d.dup
          end
          cooling_system.distribution_system_idref = hpxml_bldg.hvac_distributions[-1].id
        end
        hpxml_bldg.hvac_distributions[-1].air_type = HPXML::AirTypeRegularVelocity
        if hpxml_bldg.hvac_distributions[-1].duct_leakage_measurements.select { |lm| (lm.duct_type == HPXML::DuctTypeSupply) && (lm.duct_leakage_total_or_to_outside == HPXML::DuctLeakageToOutside) }.size == 0
          # Assign zero supply leakage
          hpxml_bldg.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                                          duct_leakage_units: HPXML::UnitsCFM25,
                                                                          duct_leakage_value: 0,
                                                                          duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
        end
        if hpxml_bldg.hvac_distributions[-1].duct_leakage_measurements.select { |lm| (lm.duct_type == HPXML::DuctTypeReturn) && (lm.duct_leakage_total_or_to_outside == HPXML::DuctLeakageToOutside) }.size == 0
          # Assign zero return leakage
          hpxml_bldg.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                                          duct_leakage_units: HPXML::UnitsCFM25,
                                                                          duct_leakage_value: 0,
                                                                          duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
        end
        hpxml_bldg.hvac_distributions[-1].ducts.each do |d|
          d.id = "#{d.id}_#{cooling_system.id}"
        end
      end
    end

    return applied
  end

  # TODO
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @return [TODO] TODO
  def self.apply_shared_heating_systems(hpxml_bldg)
    applied = false
    hpxml_bldg.heating_systems.each do |heating_system|
      next unless heating_system.is_shared_system

      applied = true
      distribution_system = heating_system.distribution_system
      hydronic_type = distribution_system.hydronic_type

      if heating_system.heating_system_type == HPXML::HVACTypeBoiler && hydronic_type.to_s == HPXML::HydronicTypeWaterLoop

        # Shared boiler w/ water loop heat pump
        # Per ANSI/RESNET/ICC 301-2019 Section 4.4.7.2, model as:
        # A) heat pump with constant efficiency and duct losses, fraction heat load served = 1/COP
        # B) boiler, fraction heat load served = 1-1/COP
        fraction_heat_load_served = heating_system.fraction_heat_load_served

        # Heat pump
        # If this approach is ever removed, also remove code in HVACSizing.apply_hvac_loads()
        wlhp = hpxml_bldg.heat_pumps.find { |hp| hp.heat_pump_type == HPXML::HVACTypeHeatPumpWaterLoopToAir }
        wlhp.fraction_heat_load_served = fraction_heat_load_served * (1.0 / wlhp.heating_efficiency_cop)
        wlhp.fraction_cool_load_served = 0.0

        # Boiler
        heating_system.fraction_heat_load_served = fraction_heat_load_served * (1.0 - 1.0 / wlhp.heating_efficiency_cop)
      end

      heating_system.heating_capacity = nil # Autosize the equipment
    end

    return applied
  end

  # TODO
  #
  # @param capacity [TODO] TODO
  # @param rated_cfm_per_ton [TODO] TODO
  # @return [TODO] TODO
  def self.calc_rated_airflow(capacity, rated_cfm_per_ton)
    return UnitConversions.convert(capacity, 'Btu/hr', 'ton') * UnitConversions.convert(rated_cfm_per_ton, 'cfm', 'm^3/s')
  end

  # TODO
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param heating_system [TODO] TODO
  # @param cooling_system [TODO] TODO
  # @return [TODO] TODO
  def self.is_attached_heating_and_cooling_systems(hpxml_bldg, heating_system, cooling_system)
    # Now only allows furnace+AC
    if not ((hpxml_bldg.heating_systems.include? heating_system) && (hpxml_bldg.cooling_systems.include? cooling_system))
      return false
    end
    if not (heating_system.heating_system_type == HPXML::HVACTypeFurnace && cooling_system.cooling_system_type == HPXML::HVACTypeCentralAirConditioner)
      return false
    end

    return true
  end

  # Returns a list of HPXML HVAC (heating/cooling) systems, incorporating whether multiple systems are
  # connected to the same distribution system (e.g., a furnace + central air conditioner w/ the same ducts).
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @return [Array<Hash>] List of HPXML HVAC (heating and/or cooling) systems
  def self.get_hpxml_hvac_systems(hpxml_bldg)
    hvac_systems = []

    hpxml_bldg.cooling_systems.each do |cooling_system|
      heating_system = nil
      if is_attached_heating_and_cooling_systems(hpxml_bldg, cooling_system.attached_heating_system, cooling_system)
        heating_system = cooling_system.attached_heating_system
      end
      hvac_systems << { cooling: cooling_system,
                        heating: heating_system }
    end

    hpxml_bldg.heating_systems.each do |heating_system|
      next if heating_system.is_heat_pump_backup_system # Will be processed later
      if is_attached_heating_and_cooling_systems(hpxml_bldg, heating_system, heating_system.attached_cooling_system)
        next # Already processed with cooling
      end

      hvac_systems << { cooling: nil,
                        heating: heating_system }
    end

    # Heat pump with backup system must be sorted last so that the last two
    # HVAC systems in the EnergyPlus EquipmentList are 1) the heat pump and
    # 2) the heat pump backup system.
    hpxml_bldg.heat_pumps.sort_by { |hp| hp.backup_system_idref.to_s }.each do |heat_pump|
      hvac_systems << { cooling: heat_pump,
                        heating: heat_pump }
    end

    hpxml_bldg.heating_systems.each do |heating_system|
      next unless heating_system.is_heat_pump_backup_system

      hvac_systems << { cooling: nil,
                        heating: heating_system }
    end

    return hvac_systems
  end

  # TODO
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @return [TODO] TODO
  def self.ensure_nonzero_sizing_values(hpxml_bldg)
    min_capacity = 1.0 # Btuh
    min_airflow = 3.0 # cfm; E+ min airflow is 0.001 m3/s
    hpxml_bldg.heating_systems.each do |htg_sys|
      htg_sys.heating_capacity = [htg_sys.heating_capacity, min_capacity].max
      htg_sys.heating_airflow_cfm = [htg_sys.heating_airflow_cfm, min_airflow].max unless htg_sys.heating_airflow_cfm.nil?
    end
    hpxml_bldg.cooling_systems.each do |clg_sys|
      clg_sys.cooling_capacity = [clg_sys.cooling_capacity, min_capacity].max
      clg_sys.cooling_airflow_cfm = [clg_sys.cooling_airflow_cfm, min_airflow].max
      next unless not clg_sys.cooling_detailed_performance_data.empty?

      clg_sys.cooling_detailed_performance_data.each do |dp|
        speed = dp.capacity_description == HPXML::CapacityDescriptionMinimum ? 1 : 2
        dp.capacity = [dp.capacity, min_capacity * speed].max
      end
    end
    hpxml_bldg.heat_pumps.each do |hp_sys|
      hp_sys.cooling_capacity = [hp_sys.cooling_capacity, min_capacity].max
      hp_sys.cooling_airflow_cfm = [hp_sys.cooling_airflow_cfm, min_airflow].max
      hp_sys.additional_properties.cooling_capacity_sensible = [hp_sys.additional_properties.cooling_capacity_sensible, min_capacity].max
      hp_sys.heating_capacity = [hp_sys.heating_capacity, min_capacity].max
      hp_sys.heating_airflow_cfm = [hp_sys.heating_airflow_cfm, min_airflow].max
      hp_sys.heating_capacity_17F = [hp_sys.heating_capacity_17F, min_capacity].max unless hp_sys.heating_capacity_17F.nil?
      hp_sys.backup_heating_capacity = [hp_sys.backup_heating_capacity, min_capacity].max unless hp_sys.backup_heating_capacity.nil?
      if not hp_sys.heating_detailed_performance_data.empty?
        hp_sys.heating_detailed_performance_data.each do |dp|
          next if dp.capacity.nil?

          speed = dp.capacity_description == HPXML::CapacityDescriptionMinimum ? 1 : 2
          dp.capacity = [dp.capacity, min_capacity * speed].max
        end
      end
      next if hp_sys.cooling_detailed_performance_data.empty?

      hp_sys.cooling_detailed_performance_data.each do |dp|
        next if dp.capacity.nil?

        speed = dp.capacity_description == HPXML::CapacityDescriptionMinimum ? 1 : 2
        dp.capacity = [dp.capacity, min_capacity * speed].max
      end
    end
  end

  # TODO
  #
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param hpxml_header [HPXML::Header] HPXML Header object (one per HPXML file)
  # @return [TODO] TODO
  def self.apply_unit_multiplier(hpxml_bldg, hpxml_header)
    # Apply unit multiplier (E+ thermal zone multiplier); E+ sends the
    # multiplied thermal zone load to the HVAC system, so the HVAC system
    # needs to be sized to meet the entire multiplied zone load.
    unit_multiplier = hpxml_bldg.building_construction.number_of_units
    hpxml_bldg.heating_systems.each do |htg_sys|
      htg_sys.heating_capacity *= unit_multiplier
      htg_sys.heating_airflow_cfm *= unit_multiplier unless htg_sys.heating_airflow_cfm.nil?
      htg_sys.pilot_light_btuh *= unit_multiplier unless htg_sys.pilot_light_btuh.nil?
      htg_sys.electric_auxiliary_energy *= unit_multiplier unless htg_sys.electric_auxiliary_energy.nil?
      htg_sys.fan_watts *= unit_multiplier unless htg_sys.fan_watts.nil?
      htg_sys.heating_detailed_performance_data.each do |dp|
        dp.capacity *= unit_multiplier unless dp.capacity.nil?
      end
    end
    hpxml_bldg.cooling_systems.each do |clg_sys|
      clg_sys.cooling_capacity *= unit_multiplier
      clg_sys.cooling_airflow_cfm *= unit_multiplier
      clg_sys.crankcase_heater_watts *= unit_multiplier unless clg_sys.crankcase_heater_watts.nil?
      clg_sys.integrated_heating_system_capacity *= unit_multiplier unless clg_sys.integrated_heating_system_capacity.nil?
      clg_sys.integrated_heating_system_airflow_cfm *= unit_multiplier unless clg_sys.integrated_heating_system_airflow_cfm.nil?
      clg_sys.cooling_detailed_performance_data.each do |dp|
        dp.capacity *= unit_multiplier unless dp.capacity.nil?
      end
    end
    hpxml_bldg.heat_pumps.each do |hp_sys|
      hp_sys.cooling_capacity *= unit_multiplier
      hp_sys.cooling_airflow_cfm *= unit_multiplier
      hp_sys.additional_properties.cooling_capacity_sensible *= unit_multiplier
      hp_sys.heating_capacity *= unit_multiplier
      hp_sys.heating_airflow_cfm *= unit_multiplier
      hp_sys.heating_capacity_17F *= unit_multiplier unless hp_sys.heating_capacity_17F.nil?
      hp_sys.backup_heating_capacity *= unit_multiplier unless hp_sys.backup_heating_capacity.nil?
      hp_sys.crankcase_heater_watts *= unit_multiplier unless hp_sys.crankcase_heater_watts.nil?
      hpxml_header.heat_pump_backup_heating_capacity_increment *= unit_multiplier unless hpxml_header.heat_pump_backup_heating_capacity_increment.nil?
      hp_sys.heating_detailed_performance_data.each do |dp|
        dp.capacity *= unit_multiplier unless dp.capacity.nil?
      end
      hp_sys.cooling_detailed_performance_data.each do |dp|
        dp.capacity *= unit_multiplier unless dp.capacity.nil?
      end
    end
  end

  # TODO
  #
  # @param capacity [TODO] TODO
  # @return [TODO] TODO
  def self.get_dehumidifier_default_values(capacity)
    rh_setpoint = 0.6
    if capacity <= 25.0
      ief = 0.79
    elsif capacity <= 35.0
      ief = 0.95
    elsif capacity <= 54.0
      ief = 1.04
    elsif capacity < 75.0
      ief = 1.20
    else
      ief = 1.82
    end

    return { rh_setpoint: rh_setpoint, ief: ief }
  end

  # TODO
  #
  # @param seer2 [TODO] TODO
  # @param is_ducted [TODO] TODO
  # @return [TODO] TODO
  def self.calc_seer_from_seer2(seer2, is_ducted)
    # ANSI/RESNET/ICC 301 Table 4.4.4.1(1) SEER2/HSPF2 Conversion Factors
    # Note: There are less common system types (packaged, small duct high velocity,
    # and space-constrained) that we don't handle here.
    if is_ducted # Ducted split system
      return seer2 / 0.95
    else # Ductless systems
      return seer2 / 1.00
    end
  end

  # TODO
  #
  # @param hspf2 [TODO] TODO
  # @param is_ducted [TODO] TODO
  # @return [TODO] TODO
  def self.calc_hspf_from_hspf2(hspf2, is_ducted)
    # ANSI/RESNET/ICC 301 Table 4.4.4.1(1) SEER2/HSPF2 Conversion Factors
    # Note: There are less common system types (packaged, small duct high velocity,
    # and space-constrained) that we don't handle here.
    if is_ducted # Ducted split system
      return hspf2 / 0.85
    else # Ductless system
      return hspf2 / 0.90
    end
  end
end
