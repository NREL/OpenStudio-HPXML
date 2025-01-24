# frozen_string_literal: true

# Collection of methods for adding vehicle-related OpenStudio objects, built on the Battery class
module Vehicle
  # Adds any HPXML Vehicles to the OpenStudio model.
  # Currently only models electric vehicles.
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @return [nil]
  def self.apply(runner, model, spaces, hpxml_bldg, schedules_file)
    hpxml_bldg.vehicles.each do |vehicle|
      if vehicle.vehicle_type != HPXML::VehicleTypeBEV
        # Warning issued by Schematron validator
        next
      end

      apply_electric_vehicle(runner, model, spaces, hpxml_bldg, vehicle, schedules_file)
    end
  end

  # Generates and returns the EV charging and discharging schedules
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param vehicle [HPXML::Vehicle] Object that defines a single electric vehicle
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @return [OpenStudio::Model::ScheduleFile or MonthWeekdayWeekendSchedule] the charging and discharging schedules
  def self.get_ev_schedules(runner, model, vehicle, schedules_file)
    charging_schedule, discharging_schedule = nil, nil
    charging_col, discharging_col = SchedulesFile::Columns[:ElectricVehicleCharging].name, SchedulesFile::Columns[:ElectricVehicleDischarging].name
    if not schedules_file.nil?
      charging_schedule = schedules_file.create_schedule_file(model, col_name: charging_col)
      discharging_schedule = schedules_file.create_schedule_file(model, col_name: discharging_col)
    end
    if charging_schedule.nil? && discharging_schedule.nil?
      charge_name, discharge_name = "#{vehicle.id} charging schedule", "#{vehicle.id} discharging schedule"
      weekday_charge, weekday_discharge = Schedule.split_signed_charging_schedule(vehicle.ev_weekday_fractions)
      weekend_charge, weekend_discharge = Schedule.split_signed_charging_schedule(vehicle.ev_weekend_fractions)
      charging_schedule = MonthWeekdayWeekendSchedule.new(model, charge_name, weekday_charge, weekend_charge, vehicle.ev_monthly_multipliers, EPlus::ScheduleTypeLimitsFraction)
      discharging_schedule = MonthWeekdayWeekendSchedule.new(model, discharge_name, weekday_discharge, weekend_discharge, vehicle.ev_monthly_multipliers, EPlus::ScheduleTypeLimitsFraction)
    else
      runner.registerWarning("Both schedule file and weekday fractions provided for '#{SchedulesFile::Columns[:ElectricVehicleCharging].name}'; weekday fractions will be ignored.") if !vehicle.ev_weekday_fractions.nil?
      runner.registerWarning("Both schedule file and weekend fractions provided for '#{SchedulesFile::Columns[:ElectricVehicleCharging].name}'; weekend fractions will be ignored.") if !vehicle.ev_weekend_fractions.nil?
      runner.registerWarning("Both schedule file and monthly multipliers provided for '#{SchedulesFile::Columns[:ElectricVehicleCharging].name}'; monthly multipliers will be ignored.") if !vehicle.ev_monthly_multipliers.nil?
    end

    return charging_schedule, discharging_schedule
  end

  # Retrieves EV charging and discharging OpenStudio schedule objects
  #
  # @param charging_schedule [OpenStudio::Model::ScheduleFile or MonthWeekdayWeekendSchedule] EV charging schedule
  # @param discharging_schedule [OpenStudio::Model::ScheduleFile or MonthWeekdayWeekendSchedule] EV discharging schedule
  # @return [Array<OpenStudio::Model::ScheduleXXX>] The charging and discharging schedules, either ScheduleRulesets or ScheduleFiles
  def self.get_ev_OS_schedules(charging_schedule, discharging_schedule)
    os_charging_schedule, os_discharging_schedule = nil, nil
    if charging_schedule.is_a? MonthWeekdayWeekendSchedule
      os_charging_schedule = charging_schedule.schedule
    elsif charging_schedule.is_a? OpenStudio::Model::ScheduleFile
      os_charging_schedule = charging_schedule
    end
    if discharging_schedule.is_a? MonthWeekdayWeekendSchedule
      os_discharging_schedule = discharging_schedule.schedule
    elsif discharging_schedule.is_a? OpenStudio::Model::ScheduleFile
      os_discharging_schedule = discharging_schedule
    end

    return os_charging_schedule, os_discharging_schedule
  end

  # Apply an electric vehicle to the model using the battery.rb Battery class, which assigns OpenStudio ElectricLoadCenterStorageLiIonNMCBattery and ElectricLoadCenterDistribution objects.
  # An EMS program models the effect of ambient temperature on the effective power output, scales power with the fraction charged at home, and calculates the unmet driving hours.
  # Bi-directional charging is not currently implemented
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param vehicle [HPXML::Vehicle] Object that defines a single electric vehicle
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @return [nil]
  def self.apply_electric_vehicle(runner, model, spaces, hpxml_bldg, vehicle, schedules_file)
    if hpxml_bldg.plug_loads.any? { |pl| pl.plug_load_type == HPXML::PlugLoadTypeElectricVehicleCharging }
      # Warning issued by Schematron validator
      return
    end

    # Assign charging and vehicle space
    ev_charger = vehicle.ev_charger
    if ev_charger.nil?
      # Warning issued by Schematron validator
      return
    end

    vehicle.location = ev_charger.location

    # Calculate hours/week and effective discharge power
    charging_schedule, discharging_schedule = get_ev_schedules(runner, model, vehicle, schedules_file)
    ev_annl_energy = vehicle.fuel_economy * vehicle.miles_per_year # kWh/year
    if discharging_schedule.is_a? OpenStudio::Model::ScheduleFile
      eff_discharge_power = schedules_file.calc_design_level_from_daily_kwh(col_name: discharging_schedule.name.to_s, daily_kwh: ev_annl_energy / 365)
    elsif discharging_schedule.is_a? MonthWeekdayWeekendSchedule
      eff_discharge_power = discharging_schedule.calc_design_level_from_daily_kwh(ev_annl_energy / 365)
    end

    # Scale the effective discharge power by 2.25 to assign the rated discharge power. This value reflects the maximum power adjustment allowed in the EMS EV discharge program at -17.8 C.
    vehicle.rated_power_output = eff_discharge_power * 2.25

    # Apply vehicle battery to model
    os_charging_schedule, os_discharging_schedule = get_ev_OS_schedules(charging_schedule, discharging_schedule)
    Battery.apply_battery(runner, model, spaces, hpxml_bldg, vehicle, os_charging_schedule, os_discharging_schedule)

    # Apply EMS program to adjust discharge power based on ambient temperature.
    model.getElectricLoadCenterStorageLiIonNMCBatterys.each do |elcs|
      next unless elcs.name.to_s.include? vehicle.id

      ev_elcd = model.getElectricLoadCenterDistributions.find { |elcd| elcd.name.to_s.include?(vehicle.id) }
      eff_charge_power = ev_elcd.designStorageControlChargePower
      min_soc = ev_elcd.minimumStorageStateofChargeFraction
      discharging_schedule = ev_elcd.storageDischargePowerFractionSchedule.get
      charging_schedule = ev_elcd.storageChargePowerFractionSchedule.get

      discharge_power_act = Model.add_ems_actuator(
        name: 'battery_discharge_power_act',
        model_object: ev_elcd,
        comp_type_and_control: ['Electrical Storage', 'Power Draw Rate']
      )
      charge_power_act = Model.add_ems_actuator(
        name: 'battery_charge_power_act',
        model_object: ev_elcd,
        comp_type_and_control: ['Electrical Storage', 'Power Charge Rate']
      )
      temp_sensor = Model.add_ems_sensor(
        model,
        name: 'site_temp',
        output_var_or_meter_name: 'Site Outdoor Air Drybulb Temperature',
        key_name: 'Environment'
      )
      discharge_sch_sensor = Model.add_ems_sensor(
        model,
        name: 'discharge_sch_sensor',
        output_var_or_meter_name: 'Schedule Value',
        key_name: discharging_schedule.name.to_s
      )
      charge_sch_sensor = Model.add_ems_sensor(
        model,
        name: 'charge_sch_sensor',
        output_var_or_meter_name: 'Schedule Value',
        key_name: charging_schedule.name.to_s
      )
      soc_sensor = Model.add_ems_sensor(
        model,
        name: 'soc_sensor',
        output_var_or_meter_name: 'Electric Storage Charge Fraction',
        key_name: elcs.name.to_s
      )

      ev_discharge_program = Model.add_ems_program(
        model,
        name: 'ev_discharge_program'
      )
      ev_discharge_program.additionalProperties.setFeature('ObjectType', Constants::ObjectTypeBEVDischargeProgram)
      unmet_hr_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, 'unmet_driving_hours')
      unmet_hr_var.setName('unmet_driving_hours')
      unmet_hr_var.setTypeOfDataInVariable('Summed')
      unmet_hr_var.setUpdateFrequency('SystemTimestep')
      unmet_hr_var.setEMSProgramOrSubroutineName(ev_discharge_program)
      unmet_hr_var.setUnits('hr')

      # Power adjustment vs ambient temperature curve; derived from most recent data in Figure 9 of https://www.nrel.gov/docs/fy23osti/83916.pdf
      # This adjustment scales power demand based on ambient temeprature, and encompasses losses due to battery and space conditioning (i.e., discharging losses), as well as charging losses.
      coefs = [1.412768, -3.910397E-02, 9.408235E-04, 8.971560E-06, -7.699244E-07, 1.265614E-08]
      power_curve = ''
      coefs.each_with_index do |coef, i|
        power_curve += "+(#{coef}*(site_temp_adj^#{i}))"
      end
      power_curve = power_curve[1..]
      ev_discharge_program.addLine("  Set power_mult = #{power_curve}")
      ev_discharge_program.addLine("  Set site_temp_adj = #{temp_sensor.name}")
      ev_discharge_program.addLine("  If #{temp_sensor.name} < -17.778")
      ev_discharge_program.addLine('    Set site_temp_adj = -17.778')
      ev_discharge_program.addLine("  ElseIf #{temp_sensor.name} > 37.609")
      ev_discharge_program.addLine('    Set site_temp_adj = 37.609')
      ev_discharge_program.addLine('  EndIf')
      ev_discharge_program.addLine("  If #{discharge_sch_sensor.name} > 0.0")
      ev_discharge_program.addLine("    Set #{discharge_power_act.name} = #{eff_discharge_power} * #{vehicle.fraction_charged_home} * power_mult * #{discharge_sch_sensor.name}")
      ev_discharge_program.addLine("    Set #{charge_power_act.name} = #{eff_charge_power} * #{charge_sch_sensor.name}")
      ev_discharge_program.addLine("    If #{soc_sensor.name} <= #{min_soc}")
      ev_discharge_program.addLine("      Set #{unmet_hr_var.name} = #{discharge_sch_sensor.name}")
      ev_discharge_program.addLine('    Else')
      ev_discharge_program.addLine("      Set #{unmet_hr_var.name} = 0")
      ev_discharge_program.addLine('    EndIf')
      ev_discharge_program.addLine('  Else')
      ev_discharge_program.addLine("    Set #{charge_power_act.name} = #{eff_charge_power} * #{charge_sch_sensor.name}")
      ev_discharge_program.addLine("    Set #{discharge_power_act.name} = 0")
      ev_discharge_program.addLine("    Set #{unmet_hr_var.name} = 0")
      ev_discharge_program.addLine('  EndIf')

      Model.add_ems_program_calling_manager(
        model,
        name: 'ev_discharge_pcm',
        calling_point: 'BeginTimestepBeforePredictor',
        ems_programs: [ev_discharge_program]
      )
    end
  end
end
