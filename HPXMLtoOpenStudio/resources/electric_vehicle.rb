# frozen_string_literal: true

require_relative 'battery'

class ElectricVehicle
  def self.apply(runner, model, electric_vehicle, ev_charger, schedules_file, unit_multiplier)
    if ev_charger.nil?
      runner.registerWarning('Electric vehicle specified with no charger provided; battery will not be modeled.')
      return
    end
    Battery.apply(runner, model, nil, nil, electric_vehicle, schedules_file, unit_multiplier, is_ev: true, ev_charger: ev_charger)
  end

  def self.get_ev_battery_default_values
    return { lifetime_model: HPXML::BatteryLifetimeModelNone,
             nominal_capacity_kwh: 100.0,
             nominal_voltage: 50.0,
             round_trip_efficiency: 0.925,
             usable_fraction: 0.8 } # Fraction of usable capacity to nominal capacity
  end

  def self.get_ev_charger_default_values(has_garage = false)
    if has_garage
      location = HPXML::LocationGarage
    else
      location = HPXML::LocationOutside
    end

    return { location: location,
             charging_power: 7200,
             charging_level: 2 }
  end
end
