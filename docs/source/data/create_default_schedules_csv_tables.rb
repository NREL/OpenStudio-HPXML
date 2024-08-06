# frozen_string_literal: true

require_relative '../../../HPXMLtoOpenStudio/resources/hpxml_defaults.rb'

filename_to_schedule_names = { 'building_occupancy' => ['occupants', 'general_water_use'],
                               'lighting' => ['lighting_interior', 'lighting_exterior', 'lighting_garage'],
                               'holiday_lighting' => ['lighting_exterior_holiday'],
                               'cooking_range' => ['cooking_range'],
                               'refrigerators' => ['refrigerator', 'extra_refrigerator'],
                               'freezers' => ['freezer'],
                               'dishwasher' => ['dishwasher'],
                               'clothes_washer' => ['clothes_washer'],
                               'clothes_dryer' => ['clothes_dryer'],
                               'ceiling_fans' => ['ceiling_fan'],
                               'plug_loads' => ['plug_loads_other', 'plug_loads_tv', 'plug_loads_well_pump', 'plug_loads_vehicle'],
                               'fuel_loads' => ['fuel_loads_grill', 'fuel_loads_fireplace', 'fuel_loads_lighting'],
                               'pool_pump' => ['pool_pump'],
                               'pool_heater' => ['pool_heater'],
                               'permanent_spa_pump' => ['permanent_spa_pump'],
                               'permanent_spa_heater' => ['permanent_spa_heater'],
                               'water_fixtures' => ['hot_water_fixtures'],
                               'recirculation' => ['hot_water_recirculation_pump_without_control', 'hot_water_recirculation_pump_demand_controlled', 'hot_water_recirculation_pump_temperature_controlled', 'hot_water_recirculation_pump'] }

default_schedules_csv_data, default_schedules_data_sources = HPXMLDefaults.get_default_schedules_csv_data()

filename_to_schedule_names.each do |filename, schedule_names|
  CSV.open(File.join(File.dirname(__FILE__), "#{filename}.csv"), 'w') do |csv|
    csv << ['Schedule Name', 'Element', 'Values', 'Data Source']
    schedule_names.each do |schedule_name|
      elements_values = default_schedules_csv_data[schedule_name]
      elements_values.each do |element, values|
        csv << [schedule_name, element, values, default_schedules_data_sources[schedule_name][element]]
      end
    end
  end
end
