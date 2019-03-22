require 'rake'
require 'rake/testtask'
require 'ci/reporter/rake/minitest'
require_relative "resources/hpxml"

desc 'update all measures'
task :update_measures do
  # Apply rubocop
  command = "rubocop --auto-correct --format simple --only Layout"
  puts "Applying rubocop style to measures..."
  system(command)

  create_hpxmls
end

def create_hpxmls
  this_dir = File.dirname(__FILE__)
  tests_dir = File.join(this_dir, "tests")

  hpxml_files = [
    'valid.xml',
    'valid-appliances-washer-imef.xml',
  ]

  hpxml_files.each do |hpxml_file|
    hpxml_doc = HPXML.create_hpxml(xml_type: "HPXML",
                                   xml_generated_by: "Rakefile",
                                   transaction: "create",
                                   software_program_used: nil,
                                   software_program_version: nil,
                                   eri_calculation_version: "2014AEG",
                                   building_id: "MyBuilding",
                                   event_type: "proposed workscope")
    hpxml = hpxml_doc.elements["HPXML"]

    site_values = get_hpxml_file_site_values(hpxml_file)
    HPXML.add_site(hpxml: hpxml, **site_values) unless site_values.nil?

    building_construction_values = get_hpxml_file_building_construction_values(hpxml_file)
    HPXML.add_building_construction(hpxml: hpxml, **building_construction_values)

    climate_and_risk_zones_values = get_hpxml_file_climate_and_risk_zones_values(hpxml_file)
    HPXML.add_climate_and_risk_zones(hpxml: hpxml, **climate_and_risk_zones_values)

    air_infiltration_measurement_values = get_hpxml_file_air_infiltration_measurement_values(hpxml_file)
    HPXML.add_air_infiltration_measurement(hpxml: hpxml, **air_infiltration_measurement_values)

    attic_values = get_hpxml_file_attic_values(hpxml_file)
    attic = HPXML.add_attic(hpxml: hpxml, **attic_values)

    attic_roofs_values = get_hpxml_file_attic_roofs_values(hpxml_file)
    attic_roofs_values.each do |attic_roof_values|
      HPXML.add_attic_roof(attic: attic, **attic_roof_values)
    end

    attic_floors_values = get_hpxml_file_attic_floors_values(hpxml_file)
    attic_floors_values.each do |attic_floor_values|
      HPXML.add_attic_floor(attic: attic, **attic_floor_values)
    end

    attic_walls_values = get_hpxml_file_attic_walls_values(hpxml_file)
    attic_walls_values.each do |attic_wall_values|
      HPXML.add_attic_wall(attic: attic, **attic_wall_values)
    end

    foundation_values = get_hpxml_file_foundation_values(hpxml_file)
    foundation = HPXML.add_foundation(hpxml: hpxml, **foundation_values)

    foundation_walls_values = get_hpxml_file_foundation_walls_values(hpxml_file)
    foundation_walls_values.each do |foundation_wall_values|
      HPXML.add_foundation_wall(foundation: foundation, **foundation_wall_values)
    end

    slab_values = get_hpxml_file_slab_values(hpxml_file)
    HPXML.add_slab(foundation: foundation, **slab_values)

    rim_joists_values = get_hpxml_file_rim_joists_values(hpxml_file)
    rim_joists_values.each do |rim_joist_values|
      HPXML.add_rim_joist(hpxml: hpxml, **rim_joist_values)
    end

    walls_values = get_hpxml_file_walls_values(hpxml_file)
    walls_values.each do |wall_values|
      HPXML.add_wall(hpxml: hpxml, **wall_values)
    end

    windows_values = get_hpxml_file_windows_values(hpxml_file)
    windows_values.each do |window_values|
      HPXML.add_window(hpxml: hpxml, **window_values)
    end

    doors_values = get_hpxml_file_doors_values(hpxml_file)
    doors_values.each do |door_values|
      HPXML.add_door(hpxml: hpxml, **door_values)
    end

    heating_systems_values = get_hpxml_file_heating_systems_values(hpxml_file)
    heating_systems_values.each do |heating_system_values|
      HPXML.add_heating_system(hpxml: hpxml, **heating_system_values)
    end

    cooling_systems_values = get_hpxml_file_cooling_systems_values(hpxml_file)
    cooling_systems_values.each do |cooling_system_values|
      HPXML.add_cooling_system(hpxml: hpxml, **cooling_system_values)
    end

    hvac_control_values = get_hpxml_file_hvac_control_values(hpxml_file)
    HPXML.add_hvac_control(hpxml: hpxml, **hvac_control_values)

    hvac_distribution_values = get_hpxml_file_hvac_distribution_values(hpxml_file)
    hvac_distribution = HPXML.add_hvac_distribution(hpxml: hpxml, **hvac_distribution_values)
    air_distribution = hvac_distribution.elements["DistributionSystemType/AirDistribution"]

    duct_leakage_measurements_values = get_hpxml_file_duct_leakage_measurements_values(hpxml_file)
    duct_leakage_measurements_values.each do |duct_leakage_measurement_values|
      HPXML.add_duct_leakage_measurement(air_distribution: air_distribution, **duct_leakage_measurement_values)
    end

    ducts_values = get_hpxml_file_ducts_values(hpxml_file)
    ducts_values.each do |duct_values|
      HPXML.add_ducts(air_distribution: air_distribution, **duct_values)
    end

    water_heating_system_values = get_hpxml_file_water_heating_system_values(hpxml_file)
    HPXML.add_water_heating_system(hpxml: hpxml, **water_heating_system_values)

    hot_water_distribution_values = get_hpxml_file_hot_water_distribution_values(hpxml_file)
    HPXML.add_hot_water_distribution(hpxml: hpxml, **hot_water_distribution_values)

    water_fixtures_values = get_hpxml_file_water_fixtures_values(hpxml_file)
    water_fixtures_values.each do |water_fixture_values|
      HPXML.add_water_fixture(hpxml: hpxml, **water_fixture_values)
    end

    clothes_washer_values = get_hpxml_file_clothes_washer_values(hpxml_file)
    HPXML.add_clothes_washer(hpxml: hpxml, **clothes_washer_values)

    clothes_dryer_values = get_hpxml_file_clothes_dryer_values(hpxml_file)
    HPXML.add_clothes_dryer(hpxml: hpxml, **clothes_dryer_values)

    dishwasher_values = get_hpxml_file_dishwasher_values(hpxml_file)
    HPXML.add_dishwasher(hpxml: hpxml, **dishwasher_values)

    refrigerator_values = get_hpxml_file_refrigerator_values(hpxml_file)
    HPXML.add_refrigerator(hpxml: hpxml, **refrigerator_values)

    cooking_range_values = get_hpxml_file_cooking_range_values(hpxml_file)
    HPXML.add_cooking_range(hpxml: hpxml, **cooking_range_values)

    oven_values = get_hpxml_file_oven_values(hpxml_file)
    HPXML.add_oven(hpxml: hpxml, **oven_values)

    lighting_values = get_hpxml_file_lighting_values(hpxml_file)
    HPXML.add_lighting(hpxml: hpxml, **lighting_values)

    hpxml_path = File.join(tests_dir, hpxml_file)
    XMLHelper.write_file(hpxml_doc, hpxml_path)
  end
end

def get_hpxml_file_site_values(hpxml_file)
  site_values = { :fuels => ["electricity", "natural gas"] }
  return site_values
end

def get_hpxml_file_building_construction_values(hpxml_file)
  building_construction_values = { :number_of_conditioned_floors => 3,
                                   :number_of_conditioned_floors_above_grade => 2,
                                   :number_of_bedrooms => 4,
                                   :conditioned_floor_area => 7000,
                                   :conditioned_building_volume => 67575,
                                   :garage_present => false }
  return building_construction_values
end

def get_hpxml_file_climate_and_risk_zones_values(hpxml_file)
  climate_and_risk_zones_values = { :iecc2006 => 7,
                                    :iecc2012 => 7,
                                    :weather_station_id => "Weather_Station",
                                    :weather_station_name => "Denver, CO",
                                    :weather_station_wmo => "725650" }
  return climate_and_risk_zones_values
end

def get_hpxml_file_air_infiltration_measurement_values(hpxml_file)
  air_infiltration_measurement_values = { :id => "InfiltMeas64",
                                          :house_pressure => 50,
                                          :unit_of_measure => "ACH",
                                          :air_leakage => 3.0,
                                          :infiltration_volume => 67575 }
  return air_infiltration_measurement_values
end

def get_hpxml_file_attic_values(hpxml_file)
  attic_values = { :id => "Attic_ID1",
                   :attic_type => "UnventedAttic" }
  return attic_values
end

def get_hpxml_file_attic_roofs_values(hpxml_file)
  attic_roofs_values = [{ :id => "attic-roof-1",
                          :area => 4200,
                          :solar_absorptance => 0.75,
                          :emittance => 0.9,
                          :pitch => 6,
                          :radiant_barrier => false,
                          :insulation_id => "Attic_Roof_Ins_ID1",
                          :insulation_assembly_r_value => 2.3 }]
  return attic_roofs_values
end

def get_hpxml_file_attic_floors_values(hpxml_file)
  attic_floors_values = [{ :id => "attic-floor-1",
                           :adjacent_to => "living space",
                           :area => 4200,
                           :insulation_id => "Attic_Floor_Ins_ID1",
                           :insulation_assembly_r_value => 39.3 }]
  return attic_floors_values
end

def get_hpxml_file_attic_walls_values(hpxml_file)
  attic_walls_values = [{ :id => "attic-wall-1",
                          :adjacent_to => "living space",
                          :wall_type => "WoodStud",
                          :area => 32,
                          :solar_absorptance => 0.75,
                          :emittance => 0.9,
                          :insulation_id => "Attic_Wall_Ins_ID1",
                          :insulation_assembly_r_value => 4.0 }]
  return attic_walls_values
end

def get_hpxml_file_foundation_values(hpxml_file)
  foundation_values = { :id => "Foundation_ID1",
                        :foundation_type => "ConditionedBasement" }
  return foundation_values
end

def get_hpxml_file_foundation_walls_values(hpxml_file)
  foundation_walls_values = [{ :id => "fndwall-1",
                               :height => 9,
                               :area => 2160,
                               :thickness => 8,
                               :depth_below_grade => 7,
                               :adjacent_to => "ground",
                               :insulation_id => "FWall_Ins_ID1",
                               :insulation_assembly_r_value => 10.69 }]
  return foundation_walls_values
end

def get_hpxml_file_slab_values(hpxml_file)
  slab_values = { :id => "fndslab-1",
                  :area => 3500,
                  :thickness => 4,
                  :exposed_perimeter => 240,
                  :perimeter_insulation_depth => 0,
                  :under_slab_insulation_width => 0,
                  :depth_below_grade => 7,
                  :perimeter_insulation_id => "FSlab_PerimIns_ID1",
                  :perimeter_insulation_r_value => 0,
                  :under_slab_insulation_id => "FSlab_UnderIns_ID1",
                  :under_slab_insulation_r_value => 0,
                  :carpet_fraction => 0,
                  :carpet_r_value => 0 }
  return slab_values
end

def get_hpxml_file_rim_joists_values(hpxml_file)
  rim_joists_values = [{ :id => "rimjoist-1",
                         :exterior_adjacent_to => "outside",
                         :interior_adjacent_to => "living space",
                         :area => 180,
                         :insulation_id => "rimjoist_Ins_ID1",
                         :insulation_assembly_r_value => 23.0 },
                       { :id => "rimjoist-2",
                         :exterior_adjacent_to => "outside",
                         :interior_adjacent_to => "living space",
                         :area => 180,
                         :insulation_id => "rimjoist_Ins_ID2",
                         :insulation_assembly_r_value => 10.69 }]
  return rim_joists_values
end

def get_hpxml_file_walls_values(hpxml_file)
  walls_values = [{ :id => "agwall-1",
                    :exterior_adjacent_to => "outside",
                    :interior_adjacent_to => "living space",
                    :wall_type => "WoodStud",
                    :area => 3796,
                    :solar_absorptance => 0.75,
                    :emittance => 0.9,
                    :insulation_id => "AGW_Ins_ID1",
                    :insulation_assembly_r_value => 23.0 }]
  return walls_values
end

def get_hpxml_file_windows_values(hpxml_file)
  windows_values = [{ :id => "Window_ID1",
                      :area => 240,
                      :azimuth => 180,
                      :ufactor => 0.33,
                      :shgc => 0.45,
                      :wall_idref => "agwall-1" },
                    { :id => "Window_ID2",
                      :area => 120,
                      :azimuth => 0,
                      :ufactor => 0.33,
                      :shgc => 0.45,
                      :wall_idref => "agwall-1" },
                    { :id => "Window_ID3",
                      :area => 120,
                      :azimuth => 90,
                      :ufactor => 0.33,
                      :shgc => 0.45,
                      :wall_idref => "agwall-1" },
                    { :id => "Window_ID4",
                      :area => 120,
                      :azimuth => 270,
                      :ufactor => 0.33,
                      :shgc => 0.45,
                      :wall_idref => "agwall-1" }]
  return windows_values
end

def get_hpxml_file_doors_values(hpxml_file)
  doors_values = [{ :id => "Door_ID1",
                    :wall_idref => "agwall-1",
                    :area => 80,
                    :azimuth => 270,
                    :r_value => 4.4 }]
  return doors_values
end

def get_hpxml_file_heating_systems_values(hpxml_file)
  heating_systems_values = [{ :id => "SpaceHeat_ID1",
                              :distribution_system_idref => "HVAC_Dist_ID1",
                              :heating_system_type => "Furnace",
                              :heating_system_fuel => "natural gas",
                              :heating_capacity => 64000,
                              :heating_efficiency_afue => 0.92,
                              :fraction_heat_load_served => 1 }]
  return heating_systems_values
end

def get_hpxml_file_cooling_systems_values(hpxml_file)
  cooling_systems_values = [{ :id => "SpaceCool_ID1",
                              :distribution_system_idref => "HVAC_Dist_ID1",
                              :cooling_system_type => "central air conditioning",
                              :cooling_system_fuel => "electricity",
                              :cooling_capacity => 48000,
                              :fraction_cool_load_served => 1,
                              :cooling_efficiency_seer => 13 }]
  return cooling_systems_values
end

def get_hpxml_file_hvac_control_values(hpxml_file)
  hvac_control_values = { :id => "HVAC_Ctrl_ID1",
                          :control_type => "manual thermostat" }
  return hvac_control_values
end

def get_hpxml_file_hvac_distribution_values(pxml_file)
  hvac_distribution_values = { :id => "HVAC_Dist_ID1",
                               :distribution_system_type => "AirDistribution" }
  return hvac_distribution_values
end

def get_hpxml_file_duct_leakage_measurements_values(hpxml_file)
  duct_leakage_measurements_values = [{ :duct_type => "supply",
                                        :duct_leakage_value => 75.0 },
                                      { :duct_type => "return",
                                        :duct_leakage_value => 25.0 }]
  return duct_leakage_measurements_values
end

def get_hpxml_file_ducts_values(hpxml_file)
  ducts_values = [{ :duct_type => "supply",
                    :duct_insulation_r_value => 4.0,
                    :duct_location => "attic - unvented",
                    :duct_surface_area => 150.0 },
                  { :duct_type => "return",
                    :duct_insulation_r_value => 0.0,
                    :duct_location => "attic - unvented",
                    :duct_surface_area => 50.0 }]
  return ducts_values
end

def get_hpxml_file_water_heating_system_values(hpxml_file)
  water_heating_system_values = { :id => "DHW_ID1",
                                  :fuel_type => "electricity",
                                  :water_heater_type => "storage water heater",
                                  :location => "living space",
                                  :tank_volume => 40,
                                  :fraction_dhw_load_served => 1,
                                  :heating_capacity => 18767,
                                  :energy_factor => 0.95 }
  return water_heating_system_values
end

def get_hpxml_file_hot_water_distribution_values(hpxml_file)
  hot_water_distribution_values = { :id => "HWDist_ID1",
                                    :system_type => "Standard",
                                    :standard_piping_length => 30,
                                    :pipe_r_value => 0.0 }
  return hot_water_distribution_values
end

def get_hpxml_file_water_fixtures_values(hpxml_file)
  water_fixtures_values = [{ :id => "WF_ID1",
                             :water_fixture_type => "shower head",
                             :low_flow => true },
                           { :id => "WF_ID2",
                             :water_fixture_type => "faucet",
                             :low_flow => false }]
  return water_fixtures_values
end

def get_hpxml_file_clothes_washer_values(hpxml_file)
  clothes_washer_values = { :id => "ClothesWasher",
                            :location => "living space",
                            :modified_energy_factor => 1.2,
                            :rated_annual_kwh => 387.0,
                            :label_electric_rate => 0.127,
                            :label_gas_rate => 1.003,
                            :label_annual_gas_cost => 24.0,
                            :capacity => 3.5 }
  if hpxml_file == 'valid-appliances-washer-imef.xml'
    clothes_washer_values[:modified_energy_factor] = nil
    clothes_washer_values[:integrated_modified_energy_factor] = 0.73
  end
  return clothes_washer_values
end

def get_hpxml_file_clothes_dryer_values(hpxml_file)
  clothes_dryer_values = { :id => "ClothesDryer",
                           :location => "living space",
                           :fuel_type => "electricity",
                           :energy_factor => 3.01,
                           :control_type => "timer" }
  return clothes_dryer_values
end

def get_hpxml_file_dishwasher_values(hpxml_file)
  dishwasher_values = { :id => "Dishwasher_ID1",
                        :rated_annual_kwh => 100,
                        :place_setting_capacity => 12 }
  return dishwasher_values
end

def get_hpxml_file_refrigerator_values(hpxml_file)
  refrigerator_values = { :id => "Refrigerator",
                          :location => "living space",
                          :rated_annual_kwh => 609 }
  return refrigerator_values
end

def get_hpxml_file_cooking_range_values(hpxml_file)
  cooking_range_values = { :id => "Range_ID1",
                           :fuel_type => "electricity",
                           :is_induction => true }
  return cooking_range_values
end

def get_hpxml_file_oven_values(hpxml_file)
  oven_values = { :id => "Oven_ID1",
                  :is_convection => true }
  return oven_values
end

def get_hpxml_file_lighting_values(hpxml_file)
  lighting_values = { :fraction_tier_i_interior => 0.5,
                      :fraction_tier_i_exterior => 0.5,
                      :fraction_tier_i_garage => 0.5,
                      :fraction_tier_ii_interior => 0.25,
                      :fraction_tier_ii_exterior => 0.25,
                      :fraction_tier_ii_garage => 0.25 }
  return lighting_values
end
