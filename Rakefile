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
    'valid-addenda-exclude-g.xml',
    'valid-addenda-exclude-g-e.xml',
    'valid-addenda-exclude-g-e-a.xml',
    'valid-appliances-dishwasher-ef.xml',
    'valid-appliances-dryer-cef.xml',
    'valid-appliances-gas.xml',
    'valid-appliances-in-basement.xml',
    'valid-appliances-none.xml',
    'valid-appliances-reference-elec.xml',
    'valid-appliances-reference-gas.xml',
    'valid-appliances-washer-imef.xml',
    'valid-dhw-dwhr.xml',
    'valid-dhw-location-attic.xml',
    'valid-dhw-low-flow-fixtures.xml',
    'valid-dhw-multiple.xml',
    'valid-dhw-none.xml',
    'valid-dhw-recirc-demand.xml',
    'valid-dhw-recirc-manual.xml',
    'valid-dhw-recirc-nocontrol.xml',
    'valid-dhw-recirc-temperature.xml',
    'valid-dhw-recirc-timer.xml',
    'valid-dhw-recirc-timer-reference.xml',
    'valid-dhw-standard-reference.xml',
    'valid-dhw-tank-gas.xml',
    'valid-dhw-tank-heat-pump.xml',
    'valid-dhw-tankless-electric.xml',
    'valid-dhw-tankless-gas.xml',
    'valid-dhw-tankless-oil.xml',
    'valid-dhw-tankless-propane.xml',
    'valid-dhw-tank-oil.xml',
    'valid-dhw-tank-propane.xml',
    'valid-dhw-uef.xml',
    'valid-enclosure-doors-reference.xml',
    'valid-enclosure-multiple-walls.xml',
    'valid-enclosure-no-natural-ventilation.xml',
    'valid-enclosure-orientation-45.xml',
    'valid-enclosure-overhangs.xml',
    'valid-enclosure-skylights.xml',
    'valid-enclosure-walltype-cmu.xml',
    'valid-enclosure-walltype-doublestud.xml',
    'valid-enclosure-walltype-icf.xml',
    'valid-enclosure-walltype-log.xml',
    'valid-enclosure-walltype-sip.xml',
    'valid-enclosure-walltype-solidconcrete.xml',
    'valid-enclosure-walltype-steelstud.xml',
    'valid-enclosure-walltype-stone.xml',
    'valid-enclosure-walltype-strawbale.xml',
    'valid-enclosure-walltype-structuralbrick.xml',
    'valid-enclosure-walltype-woodstud-reference.xml',
    'valid-enclosure-windows-interior-shading.xml',
    'valid-foundation-conditioned-basement-reference.xml',
    'valid-foundation-pier-beam.xml',
    'valid-foundation-pier-beam-reference.xml',
    'valid-foundation-slab.xml',
    'valid-foundation-slab-reference.xml',
    'valid-foundation-unconditioned-basement.xml',
    'valid-foundation-unconditioned-basement-reference.xml',
    'valid-foundation-unvented-crawlspace.xml',
    'valid-foundation-unvented-crawlspace-reference.xml',
    'valid-foundation-vented-crawlspace.xml',
    'valid-foundation-vented-crawlspace-reference.xml'
  ]

  hpxml_files.each do |hpxml_file|
    hpxml_values = get_hpxml_file_hpxml_values(hpxml_file)
    hpxml_doc = HPXML.create_hpxml(**hpxml_values)
    hpxml = hpxml_doc.elements["HPXML"]

    # FIXME: remove this eventually
    old_hpxml_doc = XMLHelper.parse_file(File.join(tests_dir, hpxml_file))
    created_date_and_time = XMLHelper.get_value(old_hpxml_doc.elements["HPXML/XMLTransactionHeaderInformation"], "CreatedDateAndTime")
    hpxml_doc.elements["HPXML/XMLTransactionHeaderInformation/CreatedDateAndTime"].text = created_date_and_time
    ###

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

    frame_floors_values = get_hpxml_file_frame_floor_values(hpxml_file)
    frame_floors_values.each do |frame_floor_values|
      HPXML.add_frame_floor(foundation: foundation, **frame_floor_values)
    end

    unless ['valid-foundation-pier-beam.xml', 'valid-foundation-pier-beam-reference.xml', 'valid-foundation-slab.xml', 'valid-foundation-slab-reference.xml'].include? hpxml_file

      foundation_walls_values = get_hpxml_file_foundation_walls_values(hpxml_file)
      foundation_walls_values.each do |foundation_wall_values|
        HPXML.add_foundation_wall(foundation: foundation, **foundation_wall_values)
      end

    end

    unless ['valid-foundation-pier-beam.xml', 'valid-foundation-pier-beam-reference.xml'].include? hpxml_file

      slab_values = get_hpxml_file_slab_values(hpxml_file)
      HPXML.add_slab(foundation: foundation, **slab_values)

    end

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

    skylights_values = get_hpxml_file_skylights_values(hpxml_file)
    skylights_values.each do |skylight_values|
      HPXML.add_skylight(hpxml: hpxml, **skylight_values)
    end

    doors_values = get_hpxml_file_doors_values(hpxml_file)
    doors_values.each do |door_values|
      HPXML.add_door(hpxml: hpxml, **door_values)
    end

    if hpxml_file == 'valid-enclosure-no-natural-ventilation.xml'
      HPXML.add_extension(parent: hpxml.elements["Building/BuildingDetails/Enclosure"], extensions: { "DisableNaturalVentilation": true })
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

    unless ['valid-dhw-none.xml'].include? hpxml_file

      water_heating_systems_values = get_hpxml_file_water_heating_system_values(hpxml_file)
      water_heating_systems_values.each do |water_heating_system_values|
        HPXML.add_water_heating_system(hpxml: hpxml, **water_heating_system_values)
      end

      hot_water_distribution_values = get_hpxml_file_hot_water_distribution_values(hpxml_file)
      HPXML.add_hot_water_distribution(hpxml: hpxml, **hot_water_distribution_values)

      water_fixtures_values = get_hpxml_file_water_fixtures_values(hpxml_file)
      water_fixtures_values.each do |water_fixture_values|
        HPXML.add_water_fixture(hpxml: hpxml, **water_fixture_values)
      end

    end

    unless ['valid-appliances-none.xml'].include? hpxml_file

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

    end

    lighting_values = get_hpxml_file_lighting_values(hpxml_file)
    HPXML.add_lighting(hpxml: hpxml, **lighting_values)

    hpxml_path = File.join(tests_dir, hpxml_file)
    XMLHelper.write_file(hpxml_doc, hpxml_path)
  end
end

def get_hpxml_file_hpxml_values(hpxml_file)
  hpxml_values = { :xml_type => "HPXML",
                   #  :xml_generated_by => "Rakefile", # FIXME: uncomment and remove Hand eventually
                   :xml_generated_by => "Hand",
                   :transaction => "create",
                   :software_program_used => nil,
                   :software_program_version => nil,
                   :eri_calculation_version => "2014AEG",
                   :building_id => "MyBuilding",
                   :event_type => "proposed workscope" }
  if hpxml_file == 'valid-addenda-exclude-g.xml'
    hpxml_values[:eri_calculation_version] = "2014AE"
  elsif hpxml_file == 'valid-addenda-exclude-g-e.xml'
    hpxml_values[:eri_calculation_version] = "2014A"
  elsif hpxml_file == 'valid-addenda-exclude-g-e-a.xml'
    hpxml_values[:eri_calculation_version] = "2014"
  end
  return hpxml_values
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
  if ['valid-foundation-pier-beam.xml', 'valid-foundation-pier-beam-reference.xml', 'valid-foundation-slab.xml', 'valid-foundation-slab-reference.xml', 'valid-foundation-unconditioned-basement.xml', 'valid-foundation-unconditioned-basement-reference.xml', 'valid-foundation-unvented-crawlspace.xml', 'valid-foundation-unvented-crawlspace-reference.xml', 'valid-foundation-vented-crawlspace.xml', 'valid-foundation-vented-crawlspace-reference.xml'].include? hpxml_file
    building_construction_values[:number_of_conditioned_floors] = 2
    building_construction_values[:conditioned_floor_area] = 3500
    building_construction_values[:conditioned_building_volume] = 33787.5
  end
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
  if ['valid-foundation-pier-beam.xml', 'valid-foundation-pier-beam-reference.xml', 'valid-foundation-slab.xml', 'valid-foundation-slab-reference.xml', 'valid-foundation-unconditioned-basement.xml', 'valid-foundation-unconditioned-basement-reference.xml', 'valid-foundation-unvented-crawlspace.xml', 'valid-foundation-unvented-crawlspace-reference.xml', 'valid-foundation-vented-crawlspace.xml', 'valid-foundation-vented-crawlspace-reference.xml'].include? hpxml_file
    air_infiltration_measurement_values[:infiltration_volume] = 33787.5
  end
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
  if ['valid-foundation-pier-beam.xml', 'valid-foundation-pier-beam-reference.xml'].include? hpxml_file
    foundation_values[:foundation_type] = "Ambient"
  elsif ['valid-foundation-slab.xml', 'valid-foundation-slab-reference.xml'].include? hpxml_file
    foundation_values[:foundation_type] = "SlabOnGrade"
  elsif ['valid-foundation-unconditioned-basement.xml', 'valid-foundation-unconditioned-basement-reference.xml'].include? hpxml_file
    foundation_values[:foundation_type] = "UnconditionedBasement"
  elsif ['valid-foundation-unvented-crawlspace.xml', 'valid-foundation-unvented-crawlspace-reference.xml'].include? hpxml_file
    foundation_values[:foundation_type] = "UnventedCrawlspace"
  elsif ['valid-foundation-vented-crawlspace.xml', 'valid-foundation-vented-crawlspace-reference.xml'].include? hpxml_file
    foundation_values[:foundation_type] = "VentedCrawlspace"
    foundation_values[:specific_leakage_area] = 0.00667
  end
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
  if hpxml_file == 'valid-foundation-conditioned-basement-reference.xml'
    foundation_walls_values[0][:insulation_assembly_r_value] = nil
  elsif hpxml_file == 'valid-foundation-unconditioned-basement-reference.xml'
    foundation_walls_values[0][:insulation_assembly_r_value] = nil
  elsif ['valid-foundation-unvented-crawlspace.xml', 'valid-foundation-unvented-crawlspace-reference.xml', 'valid-foundation-vented-crawlspace.xml', 'valid-foundation-vented-crawlspace-reference.xml'].include? hpxml_file
    foundation_walls_values[0][:height] = 4
    foundation_walls_values[0][:area] = 960
    foundation_walls_values[0][:depth_below_grade] = 3
  end
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
  if hpxml_file == 'valid-foundation-conditioned-basement-reference.xml'
    slab_values[:perimeter_insulation_r_value] = nil
    slab_values[:under_slab_insulation_r_value] = nil
  elsif hpxml_file == 'valid-foundation-slab.xml'
    slab_values[:id] = "Slab_ID1"
    slab_values[:under_slab_insulation_width] = 2
    slab_values[:depth_below_grade] = 0
    slab_values[:perimeter_insulation_id] = "PerimeterInsulation_ID1"
    slab_values[:under_slab_insulation_id] = "UnderSlabInsulation_ID1"
    slab_values[:under_slab_insulation_r_value] = 5
    slab_values[:carpet_fraction] = 1
    slab_values[:carpet_r_value] = 2.5
  elsif hpxml_file == 'valid-foundation-slab-reference.xml'
    slab_values[:id] = "Slab_ID1"
    slab_values[:depth_below_grade] = 0
    slab_values[:perimeter_insulation_r_value] = nil
    slab_values[:under_slab_insulation_r_value] = nil
    slab_values[:carpet_fraction] = 1
    slab_values[:carpet_r_value] = 2.5
  elsif hpxml_file == 'valid-foundation-unconditioned-basement-reference.xml'
    slab_values[:perimeter_insulation_depth] = nil
    slab_values[:under_slab_insulation_width] = nil
    slab_values[:perimeter_insulation_r_value] = nil
    slab_values[:under_slab_insulation_r_value] = nil
  elsif hpxml_file == 'valid-foundation-unvented-crawlspace.xml'
    slab_values[:id] = "Slab_ID1"
    slab_values[:thickness] = 0
    slab_values[:depth_below_grade] = 3
    slab_values[:perimeter_insulation_id] = "PerimeterInsulation_ID1"
    slab_values[:under_slab_insulation_id] = "UnderSlabInsulation_ID1"
    slab_values[:carpet_r_value] = 2.5
  elsif hpxml_file == 'valid-foundation-unvented-crawlspace-reference.xml'
    slab_values[:id] = "Slab_ID1"
    slab_values[:thickness] = 0
    slab_values[:depth_below_grade] = 3
    slab_values[:perimeter_insulation_id] = "PerimeterInsulation_ID1"
    slab_values[:perimeter_insulation_r_value] = nil
    slab_values[:under_slab_insulation_id] = "UnderSlabInsulation_ID1"
    slab_values[:under_slab_insulation_r_value] = nil
  elsif hpxml_file == 'valid-foundation-vented-crawlspace.xml'
    slab_values[:id] = "Slab_ID1"
    slab_values[:thickness] = 0
    slab_values[:depth_below_grade] = 3
    slab_values[:perimeter_insulation_id] = "PerimeterInsulation_ID1"
    slab_values[:under_slab_insulation_id] = "UnderSlabInsulation_ID1"
  elsif hpxml_file == 'valid-foundation-vented-crawlspace-reference.xml'
    slab_values[:id] = "Slab_ID1"
    slab_values[:thickness] = 0
    slab_values[:depth_below_grade] = 3
    slab_values[:perimeter_insulation_id] = "PerimeterInsulation_ID1"
    slab_values[:perimeter_insulation_r_value] = nil
    slab_values[:under_slab_insulation_id] = "UnderSlabInsulation_ID1"
    slab_values[:under_slab_insulation_r_value] = nil
  end
  return slab_values
end

def get_hpxml_file_frame_floor_values(hpxml_file)
  frame_floors_values = []
  if hpxml_file == 'valid-foundation-pier-beam.xml'
    frame_floors_values << { :id => "Floor_ID1",
                             :adjacent_to => "living space",
                             :area => 3500,
                             :insulation_id => "Floor_Ins_ID1",
                             :insulation_assembly_r_value => 18.7 }
  elsif hpxml_file == 'valid-foundation-pier-beam-reference.xml'
    frame_floors_values << { :id => "Floor_ID1",
                             :adjacent_to => "living space",
                             :area => 3500,
                             :insulation_id => "Floor_Ins_ID1",
                             :insulation_assembly_r_value => nil }
  elsif hpxml_file == 'valid-foundation-unconditioned-basement.xml'
    frame_floors_values << { :id => "Floor_ID1",
                             :adjacent_to => "living space",
                             :area => 3500,
                             :insulation_id => "Floor_Ins_ID1",
                             :insulation_assembly_r_value => 18.7 }
  elsif hpxml_file == 'valid-foundation-unconditioned-basement-reference.xml'
    frame_floors_values << { :id => "Floor_ID1",
                             :adjacent_to => "living space",
                             :area => 3500,
                             :insulation_id => "Floor_Ins_ID1" }
  elsif hpxml_file == 'valid-foundation-unvented-crawlspace.xml'
    frame_floors_values << { :id => "Floor_ID1",
                             :adjacent_to => "living space",
                             :area => 3500,
                             :insulation_id => "Floor_Ins_ID1",
                             :insulation_assembly_r_value => 18.7 }
  elsif hpxml_file == 'valid-foundation-unvented-crawlspace-reference.xml'
    frame_floors_values << { :id => "Floor_ID1",
                             :adjacent_to => "living space",
                             :area => 3500,
                             :insulation_id => "Floor_Ins_ID1" }
  elsif hpxml_file == 'valid-foundation-vented-crawlspace.xml'
    frame_floors_values << { :id => "Floor_ID1",
                             :adjacent_to => "living space",
                             :area => 3500,
                             :insulation_id => "Floor_Ins_ID1",
                             :insulation_assembly_r_value => 18.7 }
  elsif hpxml_file == 'valid-foundation-vented-crawlspace-reference.xml'
    frame_floors_values << { :id => "Floor_ID1",
                             :adjacent_to => "living space",
                             :area => 3500,
                             :insulation_id => "Floor_Ins_ID1" }
  end
  return frame_floors_values
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
  if ['valid-foundation-pier-beam.xml', 'valid-foundation-pier-beam-reference.xml', 'valid-foundation-slab.xml', 'valid-foundation-slab-reference.xml'].include? hpxml_file
    rim_joists_values.delete_at(1)
  elsif ['valid-foundation-unconditioned-basement.xml', 'valid-foundation-unconditioned-basement-reference.xml'].include? hpxml_file
    rim_joists_values[1][:interior_adjacent_to] = "basement - unconditioned"
  elsif ['valid-foundation-unvented-crawlspace.xml', 'valid-foundation-unvented-crawlspace-reference.xml'].include? hpxml_file
    rim_joists_values[1][:interior_adjacent_to] = "crawlspace - unvented"
  elsif ['valid-foundation-vented-crawlspace.xml', 'valid-foundation-vented-crawlspace-reference.xml'].include? hpxml_file
    rim_joists_values[1][:interior_adjacent_to] = "crawlspace - vented"
  end
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
  if hpxml_file == 'valid-enclosure-multiple-walls.xml'
    walls_values[0][:id] = "agwall-small"
    walls_values[0][:area] = 10
    walls_values << { :id => "agwall-medium",
                      :exterior_adjacent_to => "outside",
                      :interior_adjacent_to => "living space",
                      :wall_type => "WoodStud",
                      :area => 300,
                      :solar_absorptance => 0.75,
                      :emittance => 0.9,
                      :insulation_id => "AGW_Ins_ID2",
                      :insulation_assembly_r_value => 23.0 }
    walls_values << { :id => "agwall-large",
                      :exterior_adjacent_to => "outside",
                      :interior_adjacent_to => "living space",
                      :wall_type => "WoodStud",
                      :area => 3486,
                      :solar_absorptance => 0.75,
                      :emittance => 0.9,
                      :insulation_id => "AGW_Ins_ID3",
                      :insulation_assembly_r_value => 23.0 }
  elsif hpxml_file == 'valid-enclosure-walltype-cmu.xml'
    walls_values[0][:wall_type] = "ConcreteMasonryUnit"
    walls_values[0][:insulation_assembly_r_value] = 12
  elsif hpxml_file == 'valid-enclosure-walltype-doublestud.xml'
    walls_values[0][:wall_type] = "DoubleWoodStud"
    walls_values[0][:insulation_assembly_r_value] = 28.7
  elsif hpxml_file == 'valid-enclosure-walltype-icf.xml'
    walls_values[0][:wall_type] = "InsulatedConcreteForms"
    walls_values[0][:insulation_assembly_r_value] = 21
  elsif hpxml_file == 'valid-enclosure-walltype-log.xml'
    walls_values[0][:wall_type] = "LogWall"
    walls_values[0][:insulation_assembly_r_value] = 7.1
  elsif hpxml_file == 'valid-enclosure-walltype-sip.xml'
    walls_values[0][:wall_type] = "StructurallyInsulatedPanel"
    walls_values[0][:insulation_assembly_r_value] = 16.1
  elsif hpxml_file == 'valid-enclosure-walltype-solidconcrete.xml'
    walls_values[0][:wall_type] = "SolidConcrete"
    walls_values[0][:insulation_assembly_r_value] = 1.35
  elsif hpxml_file == 'valid-enclosure-walltype-steelstud.xml'
    walls_values[0][:wall_type] = "SteelFrame"
    walls_values[0][:insulation_assembly_r_value] = 8.1
  elsif hpxml_file == 'valid-enclosure-walltype-stone.xml'
    walls_values[0][:wall_type] = "Stone"
    walls_values[0][:insulation_assembly_r_value] = 5.4
  elsif hpxml_file == 'valid-enclosure-walltype-strawbale.xml'
    walls_values[0][:wall_type] = "StrawBale"
    walls_values[0][:insulation_assembly_r_value] = 58.8
  elsif hpxml_file == 'valid-enclosure-walltype-structuralbrick.xml'
    walls_values[0][:wall_type] = "StructuralBrick"
    walls_values[0][:insulation_assembly_r_value] = 7.9
  elsif hpxml_file == 'valid-enclosure-walltype-woodstud-reference.xml'
    walls_values[0][:insulation_assembly_r_value] = nil
  end
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
  if hpxml_file == 'valid-enclosure-orientation-45.xml'
    windows_values[0][:azimuth] = 225
    windows_values[1][:azimuth] = 45
    windows_values[2][:azimuth] = 135
    windows_values[3][:azimuth] = 315
  elsif hpxml_file == 'valid-enclosure-overhangs.xml'
    windows_values[0][:overhangs_depth] = 2.5
    windows_values[0][:overhangs_distance_to_top_of_window] = 0
    windows_values[0][:overhangs_distance_to_bottom_of_window] = 4
    windows_values[2][:overhangs_depth] = 1.5
    windows_values[2][:overhangs_distance_to_top_of_window] = 2
    windows_values[2][:overhangs_distance_to_bottom_of_window] = 6
    windows_values[3][:overhangs_depth] = 1.5
    windows_values[3][:overhangs_distance_to_top_of_window] = 2
    windows_values[3][:overhangs_distance_to_bottom_of_window] = 7
  elsif hpxml_file == 'valid-enclosure-windows-interior-shading.xml'
    windows_values[0][:interior_shading_factor_summer] = 0.7
    windows_values[0][:interior_shading_factor_winter] = 0.85
    windows_values[1][:interior_shading_factor_summer] = 0.01
    windows_values[1][:interior_shading_factor_winter] = 0.99
    windows_values[2][:interior_shading_factor_summer] = 0.99
    windows_values[2][:interior_shading_factor_winter] = 0.01
    windows_values[3][:interior_shading_factor_summer] = 0.85
    windows_values[3][:interior_shading_factor_winter] = 0.7
  end
  return windows_values
end

def get_hpxml_file_skylights_values(hpxml_file)
  skylights_values = []
  if hpxml_file == 'valid-enclosure-skylights.xml'
    skylights_values << { :id => "Skylight_ID1",
                          :area => 15,
                          :azimuth => 90,
                          :ufactor => 0.33,
                          :shgc => 0.45,
                          :roof_idref => "attic-roof-1" }
    skylights_values << { :id => "Skylight_ID2",
                          :area => 15,
                          :azimuth => 270,
                          :ufactor => 0.35,
                          :shgc => 0.47,
                          :roof_idref => "attic-roof-1" }
  end
  return skylights_values
end

def get_hpxml_file_doors_values(hpxml_file)
  doors_values = [{ :id => "Door_ID1",
                    :wall_idref => "agwall-1",
                    :area => 80,
                    :azimuth => 270,
                    :r_value => 4.4 }]
  if hpxml_file == 'valid-enclosure-doors-reference.xml'
    doors_values[0][:area] = nil
    doors_values[0][:azimuth] = nil
    doors_values[0][:r_value] = nil
  elsif hpxml_file == 'valid-enclosure-orientation-45.xml'
    doors_values[0][:azimuth] = 315
  end
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
  if hpxml_file == 'valid-foundation-conditioned-basement-reference.xml'
    ducts_values[0][:duct_location] = "basement - conditioned"
    ducts_values[1][:duct_location] = "basement - conditioned"
  elsif ['valid-foundation-unconditioned-basement.xml', 'valid-foundation-unconditioned-basement-reference.xml'].include? hpxml_file
    ducts_values[0][:duct_location] = "basement - unconditioned"
    ducts_values[1][:duct_location] = "basement - unconditioned"
  elsif ['valid-foundation-unvented-crawlspace.xml', 'valid-foundation-unvented-crawlspace-reference.xml'].include? hpxml_file
    ducts_values[0][:duct_location] = "crawlspace - unvented"
    ducts_values[1][:duct_location] = "crawlspace - unvented"
  elsif ['valid-foundation-vented-crawlspace.xml', 'valid-foundation-vented-crawlspace-reference.xml'].include? hpxml_file
    ducts_values[0][:duct_location] = "crawlspace - vented"
    ducts_values[1][:duct_location] = "crawlspace - vented"
  end
  return ducts_values
end

def get_hpxml_file_water_heating_system_values(hpxml_file)
  water_heating_systems_values = [{ :id => "DHW_ID1",
                                    :fuel_type => "electricity",
                                    :water_heater_type => "storage water heater",
                                    :location => "living space",
                                    :tank_volume => 40,
                                    :fraction_dhw_load_served => 1,
                                    :heating_capacity => 18767,
                                    :energy_factor => 0.95 }]
  if hpxml_file == 'valid-dhw-location-attic.xml'
    water_heating_systems_values[0][:location] = "attic - unvented"
  elsif hpxml_file == 'valid-dhw-multiple.xml'
    water_heating_systems_values[0][:fraction_dhw_load_served] = 0.2
    water_heating_systems_values << { :id => "DHW_ID2",
                                      :fuel_type => "natural gas",
                                      :water_heater_type => "storage water heater",
                                      :location => "living space",
                                      :tank_volume => 50,
                                      :fraction_dhw_load_served => 0.2,
                                      :heating_capacity => 4500,
                                      :energy_factor => 0.59,
                                      :recovery_efficiency => 0.76 }
    water_heating_systems_values << { :id => "DHW_ID3",
                                      :fuel_type => "electricity",
                                      :water_heater_type => "heat pump water heater",
                                      :location => "living space",
                                      :tank_volume => 80,
                                      :fraction_dhw_load_served => 0.2,
                                      :energy_factor => 2.3 }
    water_heating_systems_values << { :id => "DHW_ID4",
                                      :fuel_type => "electricity",
                                      :water_heater_type => "instantaneous water heater",
                                      :location => "living space",
                                      :fraction_dhw_load_served => 0.2,
                                      :energy_factor => 0.99 }
    water_heating_systems_values << { :id => "DHW_ID5",
                                      :fuel_type => "natural gas",
                                      :water_heater_type => "instantaneous water heater",
                                      :location => "living space",
                                      :fraction_dhw_load_served => 0.2,
                                      :energy_factor => 0.82 }
  elsif hpxml_file == 'valid-dhw-tank-gas.xml'
    water_heating_systems_values[0][:fuel_type] = "natural gas"
    water_heating_systems_values[0][:tank_volume] = 50
    water_heating_systems_values[0][:heating_capacity] = 4500
    water_heating_systems_values[0][:energy_factor] = 0.59
    water_heating_systems_values[0][:recovery_efficiency] = 0.76
  elsif hpxml_file == 'valid-dhw-tank-heat-pump.xml'
    water_heating_systems_values[0][:water_heater_type] = "heat pump water heater"
    water_heating_systems_values[0][:tank_volume] = 80
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 2.3
  elsif hpxml_file == 'valid-dhw-tankless-electric.xml'
    water_heating_systems_values[0][:water_heater_type] = "instantaneous water heater"
    water_heating_systems_values[0][:tank_volume] = nil
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 0.99
  elsif hpxml_file == 'valid-dhw-tankless-gas.xml'
    water_heating_systems_values[0][:fuel_type] = "natural gas"
    water_heating_systems_values[0][:water_heater_type] = "instantaneous water heater"
    water_heating_systems_values[0][:tank_volume] = nil
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 0.82
  elsif hpxml_file == 'valid-dhw-tankless-oil.xml'
    water_heating_systems_values[0][:fuel_type] = "fuel oil"
    water_heating_systems_values[0][:water_heater_type] = "instantaneous water heater"
    water_heating_systems_values[0][:tank_volume] = nil
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 0.82
  elsif hpxml_file == 'valid-dhw-tankless-propane.xml'
    water_heating_systems_values[0][:fuel_type] = "propane"
    water_heating_systems_values[0][:water_heater_type] = "instantaneous water heater"
    water_heating_systems_values[0][:tank_volume] = nil
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 0.82
  elsif hpxml_file == 'valid-dhw-tank-oil.xml'
    water_heating_systems_values[0][:fuel_type] = "fuel oil"
    water_heating_systems_values[0][:tank_volume] = 50
    water_heating_systems_values[0][:heating_capacity] = 4500
    water_heating_systems_values[0][:energy_factor] = 0.59
    water_heating_systems_values[0][:recovery_efficiency] = 0.76
  elsif hpxml_file == 'valid-dhw-tank-propane.xml'
    water_heating_systems_values[0][:fuel_type] = "propane"
    water_heating_systems_values[0][:tank_volume] = 50
    water_heating_systems_values[0][:heating_capacity] = 4500
    water_heating_systems_values[0][:energy_factor] = 0.59
    water_heating_systems_values[0][:recovery_efficiency] = 0.76
  elsif hpxml_file == 'valid-dhw-uef.xml'
    water_heating_systems_values[0][:energy_factor] = nil
    water_heating_systems_values[0][:uniform_energy_factor] = 0.93
  elsif hpxml_file == 'valid-foundation-conditioned-basement-reference.xml'
    water_heating_systems_values[0][:location] = "basement - conditioned"
  elsif ['valid-foundation-unconditioned-basement.xml', 'valid-foundation-unconditioned-basement-reference.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "basement - unconditioned"
  elsif ['valid-foundation-unvented-crawlspace.xml', 'valid-foundation-unvented-crawlspace-reference.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "crawlspace - unvented"
  elsif ['valid-foundation-vented-crawlspace.xml', 'valid-foundation-vented-crawlspace-reference.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "crawlspace - vented"
  end
  return water_heating_systems_values
end

def get_hpxml_file_hot_water_distribution_values(hpxml_file)
  hot_water_distribution_values = { :id => "HWDist_ID1",
                                    :system_type => "Standard",
                                    :standard_piping_length => 30,
                                    :pipe_r_value => 0.0 }
  if hpxml_file == 'valid-dhw-dwhr.xml'
    hot_water_distribution_values[:dwhr_facilities_connected] = "all"
    hot_water_distribution_values[:dwhr_equal_flow] = true
    hot_water_distribution_values[:dwhr_efficiency] = 0.55
  elsif hpxml_file == 'valid-dhw-recirc-demand.xml'
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "presence sensor demand control"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
    hot_water_distribution_values[:pipe_r_value] = 3
  elsif hpxml_file == 'valid-dhw-recirc-manual.xml'
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "manual demand control"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
    hot_water_distribution_values[:pipe_r_value] = 3
  elsif hpxml_file == 'valid-dhw-recirc-nocontrol.xml'
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "no control"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
  elsif hpxml_file == 'valid-dhw-recirc-temperature.xml'
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "temperature"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
  elsif hpxml_file == 'valid-dhw-recirc-timer.xml'
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "timer"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
  elsif hpxml_file == 'valid-dhw-recirc-timer-reference.xml'
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "timer"
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
  elsif hpxml_file == 'valid-dhw-standard-reference.xml'
    hot_water_distribution_values[:standard_piping_length] = nil
  end
  return hot_water_distribution_values
end

def get_hpxml_file_water_fixtures_values(hpxml_file)
  water_fixtures_values = [{ :id => "WF_ID1",
                             :water_fixture_type => "shower head",
                             :low_flow => true },
                           { :id => "WF_ID2",
                             :water_fixture_type => "faucet",
                             :low_flow => false }]
  if hpxml_file == 'valid-dhw-low-flow-fixtures.xml'
    water_fixtures_values[1][:low_flow] = true
  end
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
  elsif hpxml_file == 'valid-appliances-in-basement.xml'
    clothes_washer_values[:location] = "basement - conditioned"
  elsif ['valid-appliances-reference-elec.xml', 'valid-appliances-reference-gas.xml'].include? hpxml_file
    clothes_washer_values[:modified_energy_factor] = nil
    clothes_washer_values[:rated_annual_kwh] = nil
    clothes_washer_values[:label_electric_rate] = nil
    clothes_washer_values[:label_gas_rate] = nil
    clothes_washer_values[:label_annual_gas_cost] = nil
    clothes_washer_values[:capacity] = nil
  end
  return clothes_washer_values
end

def get_hpxml_file_clothes_dryer_values(hpxml_file)
  clothes_dryer_values = { :id => "ClothesDryer",
                           :location => "living space",
                           :fuel_type => "electricity",
                           :energy_factor => 3.01,
                           :control_type => "timer" }
  if hpxml_file == 'valid-appliances-dryer-cef.xml'
    clothes_dryer_values[:energy_factor] = nil
    clothes_dryer_values[:combined_energy_factor] = 2.62
    clothes_dryer_values[:control_type] = "moisture"
  elsif hpxml_file == 'valid-appliances-gas.xml'
    clothes_dryer_values[:fuel_type] = "natural gas"
    clothes_dryer_values[:energy_factor] = 2.67
    clothes_dryer_values[:control_type] = "moisture"
  elsif hpxml_file == 'valid-appliances-in-basement.xml'
    clothes_dryer_values[:location] = "basement - conditioned"
  elsif hpxml_file == 'valid-appliances-reference-elec.xml'
    clothes_dryer_values[:energy_factor] = nil
    clothes_dryer_values[:control_type] = nil
  elsif hpxml_file == 'valid-appliances-reference-gas.xml'
    clothes_dryer_values[:fuel_type] = "natural gas"
    clothes_dryer_values[:energy_factor] = nil
    clothes_dryer_values[:control_type] = nil
  end
  return clothes_dryer_values
end

def get_hpxml_file_dishwasher_values(hpxml_file)
  dishwasher_values = { :id => "Dishwasher_ID1",
                        :rated_annual_kwh => 100,
                        :place_setting_capacity => 12 }
  if hpxml_file == 'valid-appliances-dishwasher-ef.xml'
    dishwasher_values[:rated_annual_kwh] = nil
    dishwasher_values[:energy_factor] = 0.5
    dishwasher_values[:place_setting_capacity] = 8
  elsif ['valid-appliances-reference-elec.xml', 'valid-appliances-reference-gas.xml'].include? hpxml_file
    dishwasher_values[:rated_annual_kwh] = nil
    dishwasher_values[:place_setting_capacity] = nil
  end
  return dishwasher_values
end

def get_hpxml_file_refrigerator_values(hpxml_file)
  refrigerator_values = { :id => "Refrigerator",
                          :location => "living space",
                          :rated_annual_kwh => 609 }
  if hpxml_file == 'valid-appliances-in-basement.xml'
    refrigerator_values[:location] = "basement - conditioned"
  elsif ['valid-appliances-reference-elec.xml', 'valid-appliances-reference-gas.xml'].include? hpxml_file
    refrigerator_values[:rated_annual_kwh] = nil
  end
  return refrigerator_values
end

def get_hpxml_file_cooking_range_values(hpxml_file)
  cooking_range_values = { :id => "Range_ID1",
                           :fuel_type => "electricity",
                           :is_induction => true }
  if hpxml_file == 'valid-appliances-gas.xml'
    cooking_range_values[:fuel_type] = "natural gas"
    cooking_range_values[:is_induction] = false
  elsif hpxml_file == 'valid-appliances-reference-elec.xml'
    cooking_range_values[:is_induction] = nil
  elsif hpxml_file == 'valid-appliances-reference-gas.xml'
    cooking_range_values[:fuel_type] = "natural gas"
    cooking_range_values[:is_induction] = nil
  end
  return cooking_range_values
end

def get_hpxml_file_oven_values(hpxml_file)
  oven_values = { :id => "Oven_ID1",
                  :is_convection => true }
  if ['valid-appliances-reference-elec.xml', 'valid-appliances-reference-gas.xml'].include? hpxml_file
    oven_values[:is_convection] = nil
  end
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
