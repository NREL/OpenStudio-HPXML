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
  # @param hpxml_header [HPXML::Header] HPXML Header object (one per HPXML file)
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @return [nil]
  def self.apply(runner, model, spaces, hpxml_bldg, hpxml_header, schedules_file)
    hpxml_bldg.vehicles.each do |vehicle|
      if vehicle.vehicle_type != HPXML::VehicleTypeBEV
        # Warning issued by Schematron validator
        next
      end

      apply_electric_vehicle(runner, model, spaces, hpxml_bldg, hpxml_header, vehicle, schedules_file)
    end
  end

  # Apply an electric vehicle to the model using the battery.rb Battery class, which assigns OpenStudio ElectricLoadCenterStorageLiIonNMCBattery and ElectricLoadCenterDistribution objects.
  # Bi-directional charging is not currently implemented.
  #
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param spaces [Hash] Map of HPXML locations => OpenStudio Space objects
  # @param hpxml_bldg [HPXML::Building] HPXML Building object representing an individual dwelling unit
  # @param hpxml_header [HPXML::Header] HPXML Header object (one per HPXML file)
  # @param vehicle [HPXML::Vehicle] Object that defines a single electric vehicle
  # @param schedules_file [SchedulesFile] SchedulesFile wrapper class instance of detailed schedule files
  # @return [nil]
  def self.apply_electric_vehicle(runner, model, spaces, hpxml_bldg, hpxml_header, vehicle, schedules_file)
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

    # We don't use the EV/charger location in the HPXML because it doesn't currently affect simulation results.
    # See https://github.com/NREL/OpenStudio-HPXML/pull/1961
    vehicle.additional_properties.location = HPXML::LocationOutside

    if vehicle.fuel_economy_units == HPXML::UnitsKwhPerMile
      kwh_per_mile = vehicle.fuel_economy_combined
    elsif vehicle.fuel_economy_units == HPXML::UnitsMilePerKwh
      kwh_per_mile = 1.0 / vehicle.fuel_economy_combined
    elsif vehicle.fuel_economy_units == HPXML::UnitsMPGe
      kwh_per_mile = 33.705 / vehicle.fuel_economy_combined # Per EPA, one gallon of gasoline is equal to 33.705 kWh
    end
    ev_annl_energy = kwh_per_mile * vehicle.miles_per_year * vehicle.ev_usage_multiplier # kWh/year

    # Create schedule
    charging_schedule, discharging_schedule = nil, nil
    charging_col_name, discharging_col_name = SchedulesFile::Columns[:ElectricVehicleCharging].name, SchedulesFile::Columns[:ElectricVehicleDischarging].name
    if not schedules_file.nil?
      charging_schedule = schedules_file.create_schedule_file(model, col_name: charging_col_name)
      discharging_schedule = schedules_file.create_schedule_file(model, col_name: discharging_col_name)
      if not discharging_schedule.nil?
        eff_discharge_power = schedules_file.calc_design_level_from_daily_kwh(col_name: discharging_schedule.name.to_s, daily_kwh: ev_annl_energy / 365)
      end
    end
    if charging_schedule.nil? && discharging_schedule.nil?
      charging_unavailable_periods = Schedule.get_unavailable_periods(runner, charging_col_name, hpxml_header.unavailable_periods)
      discharging_unavailable_periods = Schedule.get_unavailable_periods(runner, discharging_col_name, hpxml_header.unavailable_periods)
      charge_name, discharge_name = "#{vehicle.id} charging schedule", "#{vehicle.id} discharging schedule"
      weekday_charge, weekday_discharge = Schedule.split_signed_charging_schedule(vehicle.ev_weekday_fractions)
      weekend_charge, weekend_discharge = Schedule.split_signed_charging_schedule(vehicle.ev_weekend_fractions)
      charging_schedule_obj = MonthWeekdayWeekendSchedule.new(model, charge_name, weekday_charge, weekend_charge, vehicle.ev_monthly_multipliers, EPlus::ScheduleTypeLimitsFraction, unavailable_periods: charging_unavailable_periods)
      discharging_schedule_obj = MonthWeekdayWeekendSchedule.new(model, discharge_name, weekday_discharge, weekend_discharge, vehicle.ev_monthly_multipliers, EPlus::ScheduleTypeLimitsFraction, unavailable_periods: discharging_unavailable_periods)
      eff_discharge_power = discharging_schedule_obj.calc_design_level_from_daily_kwh(ev_annl_energy / 365)
      discharging_schedule = discharging_schedule_obj.schedule
      charging_schedule = charging_schedule_obj.schedule
    else
      runner.registerWarning("Both schedule file and weekday fractions provided for '#{SchedulesFile::Columns[:ElectricVehicle].name}'; weekday fractions will be ignored.") if !vehicle.ev_weekday_fractions.nil?
      runner.registerWarning("Both schedule file and weekend fractions provided for '#{SchedulesFile::Columns[:ElectricVehicle].name}'; weekend fractions will be ignored.") if !vehicle.ev_weekend_fractions.nil?
      runner.registerWarning("Both schedule file and monthly multipliers provided for '#{SchedulesFile::Columns[:ElectricVehicle].name}'; monthly multipliers will be ignored.") if !vehicle.ev_monthly_multipliers.nil?
    end

    # Scale the effective discharge power by 2.25 to assign the rated discharge power.
    # This value reflects the maximum power adjustment allowed in the EMS EV discharge program at -17.8 C.
    vehicle.additional_properties.rated_power_output = eff_discharge_power * 2.25
    vehicle.additional_properties.eff_discharge_power = eff_discharge_power

    # Apply vehicle battery to model
    Battery.apply_battery(runner, model, spaces, hpxml_bldg, vehicle, charging_schedule, discharging_schedule)
  end
end
