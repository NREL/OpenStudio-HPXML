# frozen_string_literal: true

Dir["#{File.dirname(__FILE__)}/HPXMLtoOpenStudio/resources/*.rb"].each do |resource_file|
  next if resource_file.include? 'minitest_helper.rb'

  require resource_file
end

def create_hpxmls
  this_dir = File.dirname(__FILE__)
  workflow_dir = File.join(this_dir, 'workflow')
  hpxml_inputs_tsv_path = File.join(workflow_dir, 'hpxml_inputs.json')

  require 'json'
  json_inputs = JSON.parse(File.read(hpxml_inputs_tsv_path))
  abs_hpxml_files = []
  dirs = json_inputs.keys.map { |file_path| File.dirname(file_path) }.uniq

  schema_path = File.join(File.dirname(__FILE__), 'HPXMLtoOpenStudio', 'resources', 'hpxml_schema', 'HPXML.xsd')
  schema_validator = XMLValidator.get_schema_validator(schema_path)

  schedules_regenerated = []

  puts "Generating #{json_inputs.size} HPXML files..."

  json_inputs.keys.each_with_index do |hpxml_filename, i|
    puts "[#{i + 1}/#{json_inputs.size}] Generating #{hpxml_filename}..."
    hpxml_path = File.join(workflow_dir, hpxml_filename)
    abs_hpxml_files << File.absolute_path(hpxml_path)

    # Build up json_input from parent_hpxml(s)
    parent_hpxml_filenames = []
    parent_hpxml_filename = json_inputs[hpxml_filename]['parent_hpxml']
    while not parent_hpxml_filename.nil?
      if not json_inputs.keys.include? parent_hpxml_filename
        fail "Could not find parent_hpxml: #{parent_hpxml_filename}."
      end

      parent_hpxml_filenames << parent_hpxml_filename
      parent_hpxml_filename = json_inputs[parent_hpxml_filename]['parent_hpxml']
    end
    json_input = { 'hpxml_path' => hpxml_path }
    for parent_hpxml_filename in parent_hpxml_filenames.reverse
      json_input.merge!(json_inputs[parent_hpxml_filename])
    end
    json_input.merge!(json_inputs[hpxml_filename])
    json_input.delete('parent_hpxml')

    measures = {}
    measures['BuildResidentialHPXML'] = [json_input]

    # Re-generate stochastic schedule CSV?
    csv_path = json_input['schedules_filepaths'].to_s.split(',').map(&:strip).find { |fp| fp.include? 'occupancy-stochastic' }
    if (not csv_path.nil?) && (not schedules_regenerated.include? csv_path)
      sch_args = { 'hpxml_path' => hpxml_path,
                   'output_csv_path' => csv_path,
                   'hpxml_output_path' => hpxml_path }
      measures['BuildResidentialScheduleFile'] = [sch_args]
      schedules_regenerated << csv_path
    end

    measures_dir = File.dirname(__FILE__)
    model = OpenStudio::Model::Model.new
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # Apply measure
    success = apply_measures(measures_dir, measures, runner, model)

    # Report errors
    runner.result.stepErrors.each do |s|
      puts "Error: #{s}"
    end

    if not success
      puts "\nError: Did not successfully generate #{hpxml_file}."
      exit!
    end

    hpxml = HPXML.new(hpxml_path: hpxml_path)
    if hpxml_path.include? 'ASHRAE_Standard_140'
      apply_hpxml_modification_ashrae_140(hpxml)
    else
      apply_hpxml_modification(File.basename(hpxml_path), hpxml)
    end
    hpxml_doc = hpxml.to_oga()

    if hpxml_path.include? 'base-multiple-buildings.xml'
      # HPXML class doesn't support multiple buildings, so we'll stitch together manually.
      hpxml_element = XMLHelper.get_element(hpxml_doc, '/HPXML')
      building_element = XMLHelper.get_element(hpxml_element, 'Building')
      for i in 2..3
        new_building_element = Marshal.load(Marshal.dump(building_element)) # Deep copy

        # Make all IDs unique so the HPXML is valid
        new_building_element.each_node do |node|
          next unless node.is_a?(Oga::XML::Element)

          if not XMLHelper.get_attribute_value(node, 'id').nil?
            XMLHelper.add_attribute(node, 'id', "#{XMLHelper.get_attribute_value(node, 'id')}_#{i}")
          elsif not XMLHelper.get_attribute_value(node, 'idref').nil?
            XMLHelper.add_attribute(node, 'idref', "#{XMLHelper.get_attribute_value(node, 'idref')}_#{i}")
          end
        end

        hpxml_element.children << new_building_element
      end
    end

    XMLHelper.write_file(hpxml_doc, hpxml_path)

    errors, _warnings = XMLValidator.validate_against_schema(hpxml_path, schema_validator)
    next unless errors.size > 0

    puts errors.to_s
    puts "\nError: Did not successfully validate #{hpxml_filename}."
    exit!
  end

  puts "\n"

  # Print warnings about extra files
  dirs.each do |dir|
    Dir["#{workflow_dir}/#{dir}/*.xml"].each do |hpxml|
      next if abs_hpxml_files.include? File.absolute_path(hpxml)

      puts "Warning: Extra HPXML file found at #{File.absolute_path(hpxml)}"
    end
  end
end

def apply_hpxml_modification_ashrae_140(hpxml)
  # Set detailed HPXML values for ASHRAE 140 test files

  # ------------ #
  # HPXML Header #
  # ------------ #

  hpxml.header.xml_generated_by = 'tasks.rb'
  hpxml.header.created_date_and_time = Time.new(2000, 1, 1, 0, 0, 0, '-07:00').strftime('%Y-%m-%dT%H:%M:%S%:z') # Hard-code to prevent diffs
  hpxml.header.apply_ashrae140_assumptions = true

  # --------------------- #
  # HPXML BuildingSummary #
  # --------------------- #

  hpxml.site.azimuth_of_front_of_home = nil
  hpxml.building_construction.average_ceiling_height = nil

  # --------------- #
  # HPXML Enclosure #
  # --------------- #

  hpxml.attics[0].vented_attic_ach = 2.4
  hpxml.foundations.reverse_each do |foundation|
    foundation.delete
  end
  hpxml.roofs.each do |roof|
    if roof.roof_color == HPXML::ColorReflective
      roof.solar_absorptance = 0.2
    else
      roof.solar_absorptance = 0.6
    end
    roof.emittance = 0.9
    roof.roof_color = nil
  end
  (hpxml.walls + hpxml.rim_joists).each do |wall|
    if wall.color == HPXML::ColorReflective
      wall.solar_absorptance = 0.2
    else
      wall.solar_absorptance = 0.6
    end
    wall.emittance = 0.9
    wall.color = nil
    if wall.is_a?(HPXML::Wall)
      if wall.attic_wall_type == HPXML::AtticWallTypeGable
        wall.insulation_assembly_r_value = 2.15
      else
        wall.interior_finish_type = HPXML::InteriorFinishGypsumBoard
        wall.interior_finish_thickness = 0.5
      end
    end
  end
  hpxml.floors.each do |floor|
    next unless floor.is_ceiling

    floor.interior_finish_type = HPXML::InteriorFinishGypsumBoard
    floor.interior_finish_thickness = 0.5
  end
  hpxml.foundation_walls.each do |fwall|
    if fwall.insulation_interior_r_value == 0
      fwall.interior_finish_type = HPXML::InteriorFinishNone
    else
      fwall.interior_finish_type = HPXML::InteriorFinishGypsumBoard
      fwall.interior_finish_thickness = 0.5
    end
  end
  if hpxml.doors.size == 1
    hpxml.doors[0].area /= 2.0
    hpxml.doors << hpxml.doors[0].dup
    hpxml.doors[1].azimuth = 0
    hpxml.doors[1].id = 'Door2'
  end
  hpxml.windows.each do |window|
    next if window.overhangs_depth.nil?

    window.overhangs_distance_to_bottom_of_window = 6.0
  end

  # ---------- #
  # HPXML HVAC #
  # ---------- #

  hpxml.hvac_controls.add(id: "HVACControl#{hpxml.hvac_controls.size + 1}",
                          heating_setpoint_temp: 68.0,
                          cooling_setpoint_temp: 78.0)

  # --------------- #
  # HPXML MiscLoads #
  # --------------- #

  if hpxml.plug_loads[0].kwh_per_year > 0
    hpxml.plug_loads[0].weekday_fractions = '0.0203, 0.0203, 0.0203, 0.0203, 0.0203, 0.0339, 0.0426, 0.0852, 0.0497, 0.0304, 0.0304, 0.0406, 0.0304, 0.0254, 0.0264, 0.0264, 0.0386, 0.0416, 0.0447, 0.0700, 0.0700, 0.0731, 0.0731, 0.0660'
    hpxml.plug_loads[0].weekend_fractions = '0.0203, 0.0203, 0.0203, 0.0203, 0.0203, 0.0339, 0.0426, 0.0852, 0.0497, 0.0304, 0.0304, 0.0406, 0.0304, 0.0254, 0.0264, 0.0264, 0.0386, 0.0416, 0.0447, 0.0700, 0.0700, 0.0731, 0.0731, 0.0660'
    hpxml.plug_loads[0].monthly_multipliers = '1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0'
  end
end

def apply_hpxml_modification(hpxml_file, hpxml)
  # Set detailed HPXML values for sample files

  # ------------ #
  # HPXML Header #
  # ------------ #

  # General logic for all files
  hpxml.header.xml_generated_by = 'tasks.rb'
  hpxml.header.created_date_and_time = Time.new(2000, 1, 1, 0, 0, 0, '-07:00').strftime('%Y-%m-%dT%H:%M:%S%:z') # Hard-code to prevent diffs

  # Logic that can only be applied based on the file name
  if ['base-hvac-undersized-allow-increased-fixed-capacities.xml'].include? hpxml_file
    hpxml.header.allow_increased_fixed_capacities = true
  elsif ['base-misc-emissions.xml'].include? hpxml_file
    hpxml.header.egrid_region = 'Western'
    hpxml.header.egrid_subregion = 'RMPA'
    hpxml.header.cambium_region_gea = 'RMPAc'
  end

  # --------------------- #
  # HPXML BuildingSummary #
  # --------------------- #

  # General logic for all files
  hpxml.site.fuels = [HPXML::FuelTypeElectricity, HPXML::FuelTypeNaturalGas]

  # Logic that can only be applied based on the file name
  if ['base-schedules-simple.xml',
      'base-schedules-simple-vacancy.xml',
      'base-schedules-simple-vacancy-year-round.xml',
      'base-schedules-simple-power-outage.xml',
      'base-misc-loads-large-uncommon.xml',
      'base-misc-loads-large-uncommon2.xml'].include? hpxml_file
    hpxml.building_occupancy.weekday_fractions = '0.061, 0.061, 0.061, 0.061, 0.061, 0.061, 0.061, 0.053, 0.025, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.018, 0.033, 0.054, 0.054, 0.054, 0.061, 0.061, 0.061'
    hpxml.building_occupancy.weekend_fractions = '0.061, 0.061, 0.061, 0.061, 0.061, 0.061, 0.061, 0.053, 0.025, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.018, 0.033, 0.054, 0.054, 0.054, 0.061, 0.061, 0.061'
    hpxml.building_occupancy.monthly_multipliers = '1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0'
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.building_construction.average_ceiling_height = nil
    hpxml.building_construction.conditioned_building_volume = nil
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors = 2
    hpxml.building_construction.number_of_conditioned_floors_above_grade = 1
    hpxml.building_construction.conditioned_floor_area = 2700
    hpxml.attics[0].attic_type = HPXML::AtticTypeCathedral
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.building_construction.conditioned_building_volume = 23850
    hpxml.air_infiltration_measurements[0].infiltration_volume = hpxml.building_construction.conditioned_building_volume
    hpxml.air_infiltration_measurements[0].infiltration_height = 15.0
  elsif ['base-enclosure-split-level.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors = 1.5
    hpxml.building_construction.number_of_conditioned_floors_above_grade = 1.5
  elsif ['base-foundation-walkout-basement.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors_above_grade = 2
  elsif ['base-foundation-basement-garage.xml'].include? hpxml_file
    hpxml.building_construction.conditioned_floor_area -= 400 * 2
    hpxml.building_construction.conditioned_building_volume -= 400 * 2 * 8
    hpxml.air_infiltration_measurements[0].infiltration_volume = hpxml.building_construction.conditioned_building_volume
  elsif ['base-bldgtype-multifamily-infil-compartmentalization-test.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements[0].a_ext = 0.2
  end

  # --------------- #
  # HPXML Enclosure #
  # --------------- #

  # General logic for all files
  (hpxml.roofs + hpxml.walls + hpxml.rim_joists).each do |surface|
    surface.solar_absorptance = 0.7
    surface.emittance = 0.92
    if surface.is_a? HPXML::Roof
      surface.roof_color = nil
    else
      surface.color = nil
    end
  end
  hpxml.roofs.each do |roof|
    next unless roof.interior_adjacent_to == HPXML::LocationLivingSpace

    roof.interior_finish_type = HPXML::InteriorFinishGypsumBoard
  end
  (hpxml.walls + hpxml.foundation_walls + hpxml.floors).each do |surface|
    if surface.is_a?(HPXML::FoundationWall) && surface.interior_adjacent_to != HPXML::LocationBasementConditioned
      surface.interior_finish_type = HPXML::InteriorFinishNone
    end
    next unless [HPXML::LocationLivingSpace,
                 HPXML::LocationBasementConditioned].include?(surface.interior_adjacent_to) &&
                [HPXML::LocationOutside,
                 HPXML::LocationGround,
                 HPXML::LocationGarage,
                 HPXML::LocationAtticUnvented,
                 HPXML::LocationAtticVented,
                 HPXML::LocationOtherHousingUnit,
                 HPXML::LocationBasementConditioned].include?(surface.exterior_adjacent_to)
    next if surface.is_a?(HPXML::Floor) && surface.is_floor

    surface.interior_finish_type = HPXML::InteriorFinishGypsumBoard
  end
  hpxml.attics.each do |attic|
    if attic.attic_type == HPXML::AtticTypeUnvented
      attic.within_infiltration_volume = false
    elsif attic.attic_type == HPXML::AtticTypeVented
      attic.vented_attic_sla = 0.003
    end
  end
  hpxml.foundations.each do |foundation|
    if foundation.foundation_type == HPXML::FoundationTypeCrawlspaceUnvented
      foundation.within_infiltration_volume = false
    elsif foundation.foundation_type == HPXML::FoundationTypeCrawlspaceVented
      foundation.vented_crawlspace_sla = 0.00667
    end
  end
  hpxml.skylights.each do |skylight|
    skylight.interior_shading_factor_summer = 1.0
    skylight.interior_shading_factor_winter = 1.0
  end

  # Logic that can only be applied based on the file name
  if ['base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml',
      'base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml',
      'base-bldgtype-multifamily-adjacent-to-other-heated-space.xml',
      'base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml'].include? hpxml_file
    if hpxml_file == 'base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml'
      adjacent_to = HPXML::LocationOtherMultifamilyBufferSpace
    elsif hpxml_file == 'base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml'
      adjacent_to = HPXML::LocationOtherNonFreezingSpace
    elsif hpxml_file == 'base-bldgtype-multifamily-adjacent-to-other-heated-space.xml'
      adjacent_to = HPXML::LocationOtherHeatedSpace
    elsif hpxml_file == 'base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml'
      adjacent_to = HPXML::LocationOtherHousingUnit
    end
    wall = hpxml.walls.select { |w|
             w.interior_adjacent_to == HPXML::LocationLivingSpace &&
               w.exterior_adjacent_to == HPXML::LocationOtherHousingUnit
           }[0]
    wall.exterior_adjacent_to = adjacent_to
    hpxml.floors[0].exterior_adjacent_to = adjacent_to
    hpxml.floors[1].exterior_adjacent_to = adjacent_to
    if hpxml_file != 'base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml'
      wall.insulation_assembly_r_value = 23
      hpxml.floors[0].insulation_assembly_r_value = 18.7
      hpxml.floors[1].insulation_assembly_r_value = 18.7
    end
    hpxml.windows.each do |window|
      window.area = (window.area * 0.35).round(1)
    end
    hpxml.doors.add(id: "Door#{hpxml.doors.size + 1}",
                    wall_idref: wall.id,
                    area: 20,
                    azimuth: 0,
                    r_value: 4.4)
    hpxml.hvac_distributions[0].ducts[0].duct_location = adjacent_to
    hpxml.hvac_distributions[0].ducts[1].duct_location = adjacent_to
    hpxml.water_heating_systems[0].location = adjacent_to
    hpxml.clothes_washers[0].location = adjacent_to
    hpxml.clothes_dryers[0].location = adjacent_to
    hpxml.dishwashers[0].location = adjacent_to
    hpxml.refrigerators[0].location = adjacent_to
    hpxml.cooking_ranges[0].location = adjacent_to
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    wall = hpxml.walls.select { |w|
             w.interior_adjacent_to == HPXML::LocationLivingSpace &&
               w.exterior_adjacent_to == HPXML::LocationOtherHousingUnit
           }[0]
    wall.delete
    hpxml.walls.add(id: "Wall#{hpxml.walls.size + 1}",
                    exterior_adjacent_to: HPXML::LocationOtherHeatedSpace,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 100,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23.0)
    hpxml.walls.add(id: "Wall#{hpxml.walls.size + 1}",
                    exterior_adjacent_to: HPXML::LocationOtherMultifamilyBufferSpace,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 100,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23.0)
    hpxml.walls.add(id: "Wall#{hpxml.walls.size + 1}",
                    exterior_adjacent_to: HPXML::LocationOtherNonFreezingSpace,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 100,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23.0)
    hpxml.walls.add(id: "Wall#{hpxml.walls.size + 1}",
                    exterior_adjacent_to: HPXML::LocationOtherHousingUnit,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 100,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 4.0)
    hpxml.floors[0].delete
    hpxml.floors[0].id = 'Floor1'
    hpxml.floors[0].insulation_id = 'Floor1Insulation'
    hpxml.floors.add(id: "Floor#{hpxml.floors.size + 1}",
                     exterior_adjacent_to: HPXML::LocationOtherNonFreezingSpace,
                     interior_adjacent_to: HPXML::LocationLivingSpace,
                     floor_type: HPXML::FloorTypeWoodFrame,
                     area: 550,
                     insulation_assembly_r_value: 18.7,
                     floor_or_ceiling: HPXML::FloorOrCeilingFloor)
    hpxml.floors.add(id: "Floor#{hpxml.floors.size + 1}",
                     exterior_adjacent_to: HPXML::LocationOtherMultifamilyBufferSpace,
                     interior_adjacent_to: HPXML::LocationLivingSpace,
                     floor_type: HPXML::FloorTypeWoodFrame,
                     area: 200,
                     insulation_assembly_r_value: 18.7,
                     floor_or_ceiling: HPXML::FloorOrCeilingFloor)
    hpxml.floors.add(id: "Floor#{hpxml.floors.size + 1}",
                     exterior_adjacent_to: HPXML::LocationOtherHeatedSpace,
                     interior_adjacent_to: HPXML::LocationLivingSpace,
                     floor_type: HPXML::FloorTypeWoodFrame,
                     area: 150,
                     insulation_assembly_r_value: 2.1,
                     floor_or_ceiling: HPXML::FloorOrCeilingFloor)
    wall = hpxml.walls.select { |w|
             w.interior_adjacent_to == HPXML::LocationLivingSpace &&
               w.exterior_adjacent_to == HPXML::LocationOtherMultifamilyBufferSpace
           }[0]
    hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                      area: 50,
                      azimuth: 270,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      wall_idref: wall.id)
    wall = hpxml.walls.select { |w|
             w.interior_adjacent_to == HPXML::LocationLivingSpace &&
               w.exterior_adjacent_to == HPXML::LocationOtherHeatedSpace
           }[0]
    hpxml.doors.add(id: "Door#{hpxml.doors.size + 1}",
                    wall_idref: wall.id,
                    area: 20,
                    azimuth: 0,
                    r_value: 4.4)
    wall = hpxml.walls.select { |w|
             w.interior_adjacent_to == HPXML::LocationLivingSpace &&
               w.exterior_adjacent_to == HPXML::LocationOtherHousingUnit
           }[0]
    hpxml.doors.add(id: "Door#{hpxml.doors.size + 1}",
                    wall_idref: wall.id,
                    area: 20,
                    azimuth: 0,
                    r_value: 4.4)
  elsif ['base-enclosure-orientations.xml'].include? hpxml_file
    hpxml.windows.each do |window|
      window.orientation = { 0 => 'north', 90 => 'east', 180 => 'south', 270 => 'west' }[window.azimuth]
      window.azimuth = nil
    end
    hpxml.doors[0].delete
    hpxml.doors.add(id: "Door#{hpxml.doors.size + 1}",
                    wall_idref: 'Wall1',
                    area: 20,
                    orientation: HPXML::OrientationNorth,
                    r_value: 4.4)
    hpxml.doors.add(id: "Door#{hpxml.doors.size + 1}",
                    wall_idref: 'Wall1',
                    area: 20,
                    orientation: HPXML::OrientationSouth,
                    r_value: 4.4)
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.foundations[0].within_infiltration_volume = false
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.attics.add(id: "Attic#{hpxml.attics.size + 1}",
                     attic_type: HPXML::AtticTypeUnvented,
                     within_infiltration_volume: false)
    hpxml.roofs.each do |roof|
      roof.area = 1006.0 / hpxml.roofs.size
      roof.insulation_assembly_r_value = 25.8
    end
    hpxml.roofs.add(id: "Roof#{hpxml.roofs.size + 1}",
                    interior_adjacent_to: HPXML::LocationAtticUnvented,
                    area: 504,
                    roof_type: HPXML::RoofTypeAsphaltShingles,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    pitch: 6,
                    radiant_barrier: false,
                    insulation_assembly_r_value: 2.3)
    hpxml.rim_joists.each do |rim_joist|
      rim_joist.area = 116.0 / hpxml.rim_joists.size
    end
    hpxml.walls.each do |wall|
      wall.area = 1200.0 / hpxml.walls.size
    end
    hpxml.walls.add(id: "Wall#{hpxml.walls.size + 1}",
                    exterior_adjacent_to: HPXML::LocationAtticUnvented,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 316,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23.0)
    hpxml.walls.add(id: "Wall#{hpxml.walls.size + 1}",
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 240,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 22.3)
    hpxml.walls.add(id: "Wall#{hpxml.walls.size + 1}",
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationAtticUnvented,
                    attic_wall_type: HPXML::AtticWallTypeGable,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 50,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    insulation_assembly_r_value: 4.0)
    hpxml.foundation_walls.each do |foundation_wall|
      foundation_wall.area = 1200.0 / hpxml.foundation_walls.size
    end
    hpxml.floors.add(id: "Floor#{hpxml.floors.size + 1}",
                     exterior_adjacent_to: HPXML::LocationAtticUnvented,
                     interior_adjacent_to: HPXML::LocationLivingSpace,
                     floor_type: HPXML::FloorTypeWoodFrame,
                     area: 450,
                     interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                     insulation_assembly_r_value: 39.3,
                     floor_or_ceiling: HPXML::FloorOrCeilingCeiling)
    hpxml.slabs[0].area = 1350
    hpxml.slabs[0].exposed_perimeter = 150
    hpxml.windows[1].area = 108
    hpxml.windows[3].area = 108
    hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                      area: 12,
                      azimuth: 90,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0,
                      wall_idref: hpxml.walls[-2].id)
    hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                      area: 62,
                      azimuth: 270,
                      ufactor: 0.3,
                      shgc: 0.45,
                      fraction_operable: 0,
                      wall_idref: hpxml.walls[-2].id)
  elsif ['base-foundation-unconditioned-basement-above-grade.xml'].include? hpxml_file
    hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                      area: 20,
                      azimuth: 0,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: hpxml.foundation_walls[0].id)
    hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                      area: 10,
                      azimuth: 90,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: hpxml.foundation_walls[0].id)
    hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                      area: 20,
                      azimuth: 180,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: hpxml.foundation_walls[0].id)
    hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                      area: 10,
                      azimuth: 270,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: hpxml.foundation_walls[0].id)
  elsif ['base-enclosure-skylights-physical-properties.xml'].include? hpxml_file
    hpxml.skylights[0].ufactor = nil
    hpxml.skylights[0].shgc = nil
    hpxml.skylights[0].glass_layers = HPXML::WindowLayersSinglePane
    hpxml.skylights[0].frame_type = HPXML::WindowFrameTypeWood
    hpxml.skylights[0].glass_type = HPXML::WindowGlassTypeTinted
    hpxml.skylights[1].ufactor = nil
    hpxml.skylights[1].shgc = nil
    hpxml.skylights[1].glass_layers = HPXML::WindowLayersDoublePane
    hpxml.skylights[1].frame_type = HPXML::WindowFrameTypeMetal
    hpxml.skylights[1].thermal_break = true
    hpxml.skylights[1].glass_type = HPXML::WindowGlassTypeLowE
    hpxml.skylights[1].gas_fill = HPXML::WindowGasKrypton
  elsif ['base-enclosure-skylights-shading.xml'].include? hpxml_file
    hpxml.skylights[0].exterior_shading_factor_summer = 0.1
    hpxml.skylights[0].exterior_shading_factor_winter = 0.9
    hpxml.skylights[0].interior_shading_factor_summer = 0.01
    hpxml.skylights[0].interior_shading_factor_winter = 0.99
    hpxml.skylights[1].exterior_shading_factor_summer = 0.5
    hpxml.skylights[1].exterior_shading_factor_winter = 0.0
    hpxml.skylights[1].interior_shading_factor_summer = 0.5
    hpxml.skylights[1].interior_shading_factor_winter = 1.0
  elsif ['base-enclosure-windows-physical-properties.xml'].include? hpxml_file
    hpxml.windows[0].ufactor = nil
    hpxml.windows[0].shgc = nil
    hpxml.windows[0].glass_layers = HPXML::WindowLayersSinglePane
    hpxml.windows[0].frame_type = HPXML::WindowFrameTypeWood
    hpxml.windows[0].glass_type = HPXML::WindowGlassTypeTinted
    hpxml.windows[1].ufactor = nil
    hpxml.windows[1].shgc = nil
    hpxml.windows[1].glass_layers = HPXML::WindowLayersDoublePane
    hpxml.windows[1].frame_type = HPXML::WindowFrameTypeVinyl
    hpxml.windows[1].glass_type = HPXML::WindowGlassTypeReflective
    hpxml.windows[1].gas_fill = HPXML::WindowGasAir
    hpxml.windows[2].ufactor = nil
    hpxml.windows[2].shgc = nil
    hpxml.windows[2].glass_layers = HPXML::WindowLayersDoublePane
    hpxml.windows[2].frame_type = HPXML::WindowFrameTypeMetal
    hpxml.windows[2].thermal_break = true
    hpxml.windows[2].glass_type = HPXML::WindowGlassTypeLowE
    hpxml.windows[2].gas_fill = HPXML::WindowGasArgon
    hpxml.windows[3].ufactor = nil
    hpxml.windows[3].shgc = nil
    hpxml.windows[3].glass_layers = HPXML::WindowLayersGlassBlock
  elsif ['base-enclosure-windows-shading.xml'].include? hpxml_file
    hpxml.windows[1].exterior_shading_factor_summer = 0.5
    hpxml.windows[1].exterior_shading_factor_winter = 0.5
    hpxml.windows[1].interior_shading_factor_summer = 0.5
    hpxml.windows[1].interior_shading_factor_winter = 0.5
    hpxml.windows[2].exterior_shading_factor_summer = 0.1
    hpxml.windows[2].exterior_shading_factor_winter = 0.9
    hpxml.windows[2].interior_shading_factor_summer = 0.01
    hpxml.windows[2].interior_shading_factor_winter = 0.99
    hpxml.windows[3].exterior_shading_factor_summer = 0.0
    hpxml.windows[3].exterior_shading_factor_winter = 1.0
    hpxml.windows[3].interior_shading_factor_summer = 0.0
    hpxml.windows[3].interior_shading_factor_winter = 1.0
  elsif ['base-enclosure-thermal-mass.xml'].include? hpxml_file
    hpxml.partition_wall_mass.area_fraction = 0.8
    hpxml.partition_wall_mass.interior_finish_type = HPXML::InteriorFinishGypsumBoard
    hpxml.partition_wall_mass.interior_finish_thickness = 0.25
    hpxml.furniture_mass.area_fraction = 0.8
    hpxml.furniture_mass.type = HPXML::FurnitureMassTypeHeavyWeight
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.attics.reverse_each do |attic|
      attic.delete
    end
    hpxml.foundations.reverse_each do |foundation|
      foundation.delete
    end
    hpxml.air_infiltration_measurements[0].infiltration_volume = nil
    (hpxml.roofs + hpxml.walls + hpxml.rim_joists).each do |surface|
      surface.solar_absorptance = nil
      surface.emittance = nil
      if surface.is_a? HPXML::Roof
        surface.radiant_barrier = nil
      end
    end
    (hpxml.walls + hpxml.foundation_walls).each do |wall|
      wall.interior_finish_type = nil
    end
    hpxml.foundation_walls.each do |fwall|
      fwall.length = fwall.area / fwall.height
      fwall.area = nil
    end
    hpxml.doors[0].azimuth = nil
  elsif ['base-enclosure-2stories.xml',
         'base-enclosure-2stories-garage.xml',
         'base-hvac-ducts-area-fractions.xml'].include? hpxml_file
    hpxml.rim_joists << hpxml.rim_joists[-1].dup
    hpxml.rim_joists[-1].id = "RimJoist#{hpxml.rim_joists.size}"
    hpxml.rim_joists[-1].insulation_id = "RimJoist#{hpxml.rim_joists.size}Insulation"
    hpxml.rim_joists[-1].interior_adjacent_to = HPXML::LocationLivingSpace
    hpxml.rim_joists[-1].area = 116
  elsif ['base-foundation-conditioned-basement-wall-insulation.xml'].include? hpxml_file
    hpxml.foundation_walls.each do |foundation_wall|
      foundation_wall.insulation_interior_r_value = 10
      foundation_wall.insulation_interior_distance_to_top = 1
      foundation_wall.insulation_interior_distance_to_bottom = 8
      foundation_wall.insulation_exterior_r_value = 8.9
      foundation_wall.insulation_exterior_distance_to_top = 1
      foundation_wall.insulation_exterior_distance_to_bottom = 8
    end
  elsif ['base-foundation-walkout-basement.xml'].include? hpxml_file
    hpxml.foundation_walls.reverse_each do |foundation_wall|
      foundation_wall.delete
    end
    hpxml.foundation_walls.add(id: "FoundationWall#{hpxml.foundation_walls.size + 1}",
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 8,
                               area: 480,
                               thickness: 8,
                               depth_below_grade: 7,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 8,
                               insulation_exterior_r_value: 8.9)
    hpxml.foundation_walls.add(id: "FoundationWall#{hpxml.foundation_walls.size + 1}",
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 4,
                               area: 120,
                               thickness: 8,
                               depth_below_grade: 3,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 4,
                               insulation_exterior_r_value: 8.9)
    hpxml.foundation_walls.add(id: "FoundationWall#{hpxml.foundation_walls.size + 1}",
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 2,
                               area: 60,
                               thickness: 8,
                               depth_below_grade: 1,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 2,
                               insulation_exterior_r_value: 8.9)
    hpxml.foundation_walls.each do |foundation_wall|
      hpxml.foundations[0].attached_to_foundation_wall_idrefs << foundation_wall.id
    end
    hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                      area: 20,
                      azimuth: 0,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: hpxml.foundation_walls[-1].id)
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    hpxml.foundations.add(id: "Foundation#{hpxml.foundations.size + 1}",
                          foundation_type: HPXML::FoundationTypeCrawlspaceUnvented,
                          within_infiltration_volume: false)
    hpxml.rim_joists.each do |rim_joist|
      next unless rim_joist.exterior_adjacent_to == HPXML::LocationOutside

      rim_joist.exterior_adjacent_to = HPXML::LocationCrawlspaceUnvented
      rim_joist.siding = nil
    end
    hpxml.rim_joists.add(id: "RimJoist#{hpxml.rim_joists.size + 1}",
                         exterior_adjacent_to: HPXML::LocationOutside,
                         interior_adjacent_to: HPXML::LocationCrawlspaceUnvented,
                         siding: HPXML::SidingTypeWood,
                         area: 81,
                         solar_absorptance: 0.7,
                         emittance: 0.92,
                         insulation_assembly_r_value: 4.0)
    hpxml.foundation_walls.each do |foundation_wall|
      foundation_wall.area /= 2.0
    end
    hpxml.foundation_walls.add(id: "FoundationWall#{hpxml.foundation_walls.size + 1}",
                               exterior_adjacent_to: HPXML::LocationCrawlspaceUnvented,
                               interior_adjacent_to: HPXML::LocationBasementUnconditioned,
                               height: 8,
                               area: 360,
                               thickness: 8,
                               depth_below_grade: 4,
                               insulation_interior_r_value: 0,
                               insulation_exterior_r_value: 0)
    hpxml.foundation_walls.add(id: "FoundationWall#{hpxml.foundation_walls.size + 1}",
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationCrawlspaceUnvented,
                               height: 4,
                               area: 600,
                               thickness: 8,
                               depth_below_grade: 3,
                               insulation_interior_r_value: 0,
                               insulation_exterior_r_value: 0)
    hpxml.floors[0].area = 675
    hpxml.floors.add(id: "Floor#{hpxml.floors.size + 1}",
                     exterior_adjacent_to: HPXML::LocationCrawlspaceUnvented,
                     interior_adjacent_to: HPXML::LocationLivingSpace,
                     floor_type: HPXML::FloorTypeWoodFrame,
                     area: 675,
                     insulation_assembly_r_value: 18.7,
                     floor_or_ceiling: HPXML::FloorOrCeilingFloor)
    hpxml.slabs[0].area = 675
    hpxml.slabs[0].exposed_perimeter = 75
    hpxml.slabs.add(id: "Slab#{hpxml.slabs.size + 1}",
                    interior_adjacent_to: HPXML::LocationCrawlspaceUnvented,
                    area: 675,
                    thickness: 0,
                    exposed_perimeter: 75,
                    perimeter_insulation_depth: 0,
                    under_slab_insulation_width: 0,
                    perimeter_insulation_r_value: 0,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 0,
                    carpet_r_value: 0)
  elsif ['base-foundation-complex.xml'].include? hpxml_file
    hpxml.foundation_walls.reverse_each do |foundation_wall|
      foundation_wall.delete
    end
    hpxml.foundation_walls.add(id: "FoundationWall#{hpxml.foundation_walls.size + 1}",
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 8,
                               area: 160,
                               thickness: 8,
                               depth_below_grade: 7,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_exterior_r_value: 0.0)
    hpxml.foundation_walls.add(id: "FoundationWall#{hpxml.foundation_walls.size + 1}",
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 8,
                               area: 240,
                               thickness: 8,
                               depth_below_grade: 7,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 8,
                               insulation_exterior_r_value: 8.9)
    hpxml.foundation_walls.add(id: "FoundationWall#{hpxml.foundation_walls.size + 1}",
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 4,
                               area: 160,
                               thickness: 8,
                               depth_below_grade: 3,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_exterior_r_value: 0.0)
    hpxml.foundation_walls.add(id: "FoundationWall#{hpxml.foundation_walls.size + 1}",
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 4,
                               area: 200,
                               thickness: 8,
                               depth_below_grade: 3,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 4,
                               insulation_exterior_r_value: 8.9)
    hpxml.foundation_walls.each do |foundation_wall|
      hpxml.foundations[0].attached_to_foundation_wall_idrefs << foundation_wall.id
    end
    hpxml.slabs.reverse_each do |slab|
      slab.delete
    end
    hpxml.slabs.add(id: "Slab#{hpxml.slabs.size + 1}",
                    interior_adjacent_to: HPXML::LocationBasementConditioned,
                    area: 675,
                    thickness: 4,
                    exposed_perimeter: 75,
                    perimeter_insulation_depth: 0,
                    under_slab_insulation_width: 0,
                    perimeter_insulation_r_value: 0,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 0,
                    carpet_r_value: 0)
    hpxml.slabs.add(id: "Slab#{hpxml.slabs.size + 1}",
                    interior_adjacent_to: HPXML::LocationBasementConditioned,
                    area: 675,
                    thickness: 4,
                    exposed_perimeter: 75,
                    perimeter_insulation_depth: 1,
                    under_slab_insulation_width: 0,
                    perimeter_insulation_r_value: 5,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 0,
                    carpet_r_value: 0)
    hpxml.slabs.each do |slab|
      hpxml.foundations[0].attached_to_slab_idrefs << slab.id
    end
  elsif ['base-foundation-basement-garage.xml'].include? hpxml_file
    hpxml.roofs[0].area += 670
    hpxml.walls.add(id: "Wall#{hpxml.walls.size + 1}",
                    exterior_adjacent_to: HPXML::LocationGarage,
                    interior_adjacent_to: HPXML::LocationBasementConditioned,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 320,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23)
    hpxml.foundations[0].attached_to_wall_idrefs << hpxml.walls[-1].id
    hpxml.walls.add(id: "Wall#{hpxml.walls.size + 1}",
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationGarage,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 320,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    insulation_assembly_r_value: 4)
    hpxml.floors.add(id: "Floor#{hpxml.floors.size + 1}",
                     exterior_adjacent_to: HPXML::LocationGarage,
                     interior_adjacent_to: HPXML::LocationLivingSpace,
                     floor_type: HPXML::FloorTypeWoodFrame,
                     area: 400,
                     insulation_assembly_r_value: 39.3,
                     floor_or_ceiling: HPXML::FloorOrCeilingFloor)
    hpxml.slabs[0].area -= 400
    hpxml.slabs[0].exposed_perimeter -= 40
    hpxml.slabs.add(id: "Slab#{hpxml.slabs.size + 1}",
                    interior_adjacent_to: HPXML::LocationGarage,
                    area: 400,
                    thickness: 4,
                    exposed_perimeter: 40,
                    perimeter_insulation_depth: 0,
                    under_slab_insulation_width: 0,
                    depth_below_grade: 0,
                    perimeter_insulation_r_value: 0,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 0,
                    carpet_r_value: 0)
    hpxml.doors.add(id: "Door#{hpxml.doors.size + 1}",
                    wall_idref: hpxml.walls[-3].id,
                    area: 70,
                    azimuth: 180,
                    r_value: 4.4)
    hpxml.doors.add(id: "Door#{hpxml.doors.size + 1}",
                    wall_idref: hpxml.walls[-2].id,
                    area: 4,
                    azimuth: 0,
                    r_value: 4.4)
  elsif ['base-enclosure-ceilingtypes.xml'].include? hpxml_file
    exterior_adjacent_to = hpxml.floors[0].exterior_adjacent_to
    area = hpxml.floors[0].area
    hpxml.floors.reverse_each do |floor|
      floor.delete
    end
    floors_map = { HPXML::FloorTypeSIP => 16.1,
                   HPXML::FloorTypeConcrete => 3.2,
                   HPXML::FloorTypeSteelFrame => 8.1 }
    floors_map.each_with_index do |(floor_type, assembly_r), _i|
      hpxml.floors.add(id: "Floor#{hpxml.floors.size + 1}",
                       exterior_adjacent_to: exterior_adjacent_to,
                       interior_adjacent_to: HPXML::LocationLivingSpace,
                       floor_type: floor_type,
                       area: area / floors_map.size,
                       insulation_assembly_r_value: assembly_r,
                       floor_or_ceiling: HPXML::FloorOrCeilingCeiling)
    end
  elsif ['base-enclosure-floortypes.xml'].include? hpxml_file
    exterior_adjacent_to = hpxml.floors[0].exterior_adjacent_to
    area = hpxml.floors[0].area
    ceiling = hpxml.floors[1].dup
    hpxml.floors.reverse_each do |floor|
      floor.delete
    end
    floors_map = { HPXML::FloorTypeSIP => 16.1,
                   HPXML::FloorTypeConcrete => 3.2,
                   HPXML::FloorTypeSteelFrame => 8.1 }
    floors_map.each_with_index do |(floor_type, assembly_r), _i|
      hpxml.floors.add(id: "Floor#{hpxml.floors.size + 1}",
                       exterior_adjacent_to: exterior_adjacent_to,
                       interior_adjacent_to: HPXML::LocationLivingSpace,
                       floor_type: floor_type,
                       area: area / floors_map.size,
                       insulation_assembly_r_value: assembly_r,
                       floor_or_ceiling: HPXML::FloorOrCeilingFloor)
    end
    hpxml.floors << ceiling
    hpxml.floors[-1].id = "Floor#{hpxml.floors.size}"
    hpxml.floors[-1].insulation_id = "Floor#{hpxml.floors.size}Insulation"
  elsif ['base-enclosure-walltypes.xml'].include? hpxml_file
    hpxml.rim_joists.reverse_each do |rim_joist|
      rim_joist.delete
    end
    siding_types = [[HPXML::SidingTypeAluminum, HPXML::ColorDark],
                    [HPXML::SidingTypeAsbestos, HPXML::ColorMedium],
                    [HPXML::SidingTypeBrick, HPXML::ColorReflective],
                    [HPXML::SidingTypeCompositeShingle, HPXML::ColorDark],
                    [HPXML::SidingTypeFiberCement, HPXML::ColorMediumDark],
                    [HPXML::SidingTypeMasonite, HPXML::ColorLight],
                    [HPXML::SidingTypeStucco, HPXML::ColorMedium],
                    [HPXML::SidingTypeSyntheticStucco, HPXML::ColorMediumDark],
                    [HPXML::SidingTypeVinyl, HPXML::ColorLight],
                    [HPXML::SidingTypeNone, HPXML::ColorMedium]]
    siding_types.each do |siding_type|
      hpxml.rim_joists.add(id: "RimJoist#{hpxml.rim_joists.size + 1}",
                           exterior_adjacent_to: HPXML::LocationOutside,
                           interior_adjacent_to: HPXML::LocationBasementConditioned,
                           siding: siding_type[0],
                           color: siding_type[1],
                           area: 116 / siding_types.size,
                           emittance: 0.92,
                           insulation_assembly_r_value: 23.0)
      hpxml.foundations[0].attached_to_rim_joist_idrefs << hpxml.rim_joists[-1].id
    end
    gable_walls = hpxml.walls.select { |w| w.interior_adjacent_to == HPXML::LocationAtticUnvented }
    hpxml.walls.reverse_each do |wall|
      wall.delete
    end
    walls_map = { HPXML::WallTypeCMU => 12,
                  HPXML::WallTypeDoubleWoodStud => 28.7,
                  HPXML::WallTypeICF => 21,
                  HPXML::WallTypeLog => 7.1,
                  HPXML::WallTypeSIP => 16.1,
                  HPXML::WallTypeConcrete => 1.35,
                  HPXML::WallTypeSteelStud => 8.1,
                  HPXML::WallTypeStone => 5.4,
                  HPXML::WallTypeStrawBale => 58.8,
                  HPXML::WallTypeBrick => 7.9,
                  HPXML::WallTypeAdobe => 5.0 }
    siding_types = [[HPXML::SidingTypeAluminum, HPXML::ColorReflective],
                    [HPXML::SidingTypeAsbestos, HPXML::ColorLight],
                    [HPXML::SidingTypeBrick, HPXML::ColorMediumDark],
                    [HPXML::SidingTypeCompositeShingle, HPXML::ColorReflective],
                    [HPXML::SidingTypeFiberCement, HPXML::ColorMedium],
                    [HPXML::SidingTypeMasonite, HPXML::ColorDark],
                    [HPXML::SidingTypeStucco, HPXML::ColorLight],
                    [HPXML::SidingTypeSyntheticStucco, HPXML::ColorMedium],
                    [HPXML::SidingTypeVinyl, HPXML::ColorDark],
                    [HPXML::SidingTypeNone, HPXML::ColorMedium]]
    int_finish_types = [[HPXML::InteriorFinishGypsumBoard, 0.5],
                        [HPXML::InteriorFinishGypsumBoard, 1.0],
                        [HPXML::InteriorFinishGypsumCompositeBoard, 0.5],
                        [HPXML::InteriorFinishPlaster, 0.5],
                        [HPXML::InteriorFinishWood, 0.5],
                        [HPXML::InteriorFinishNone, nil]]
    walls_map.each_with_index do |(wall_type, assembly_r), i|
      hpxml.walls.add(id: "Wall#{hpxml.walls.size + 1}",
                      exterior_adjacent_to: HPXML::LocationOutside,
                      interior_adjacent_to: HPXML::LocationLivingSpace,
                      wall_type: wall_type,
                      siding: siding_types[i % siding_types.size][0],
                      color: siding_types[i % siding_types.size][1],
                      area: 1200 / walls_map.size,
                      emittance: 0.92,
                      interior_finish_type: int_finish_types[i % int_finish_types.size][0],
                      interior_finish_thickness: int_finish_types[i % int_finish_types.size][1],
                      insulation_assembly_r_value: assembly_r)
    end
    gable_walls.each do |gable_wall|
      hpxml.walls << gable_wall
      hpxml.walls[-1].id = "Wall#{hpxml.walls.size}"
      hpxml.walls[-1].insulation_id = "Wall#{hpxml.walls.size}Insulation"
      hpxml.attics[0].attached_to_wall_idrefs << hpxml.walls[-1].id
    end
    hpxml.windows.reverse_each do |window|
      window.delete
    end
    hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                      area: 108 / 8,
                      azimuth: 0,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      wall_idref: 'Wall1')
    hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                      area: 72 / 8,
                      azimuth: 90,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      wall_idref: 'Wall2')
    hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                      area: 108 / 8,
                      azimuth: 180,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      wall_idref: 'Wall3')
    hpxml.windows.add(id: "Window#{hpxml.windows.size + 1}",
                      area: 72 / 8,
                      azimuth: 270,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      wall_idref: 'Wall4')
    hpxml.doors.reverse_each do |door|
      door.delete
    end
    hpxml.doors.add(id: "Door#{hpxml.doors.size + 1}",
                    wall_idref: 'Wall9',
                    area: 20,
                    azimuth: 0,
                    r_value: 4.4)
    hpxml.doors.add(id: "Door#{hpxml.doors.size + 1}",
                    wall_idref: 'Wall10',
                    area: 20,
                    azimuth: 180,
                    r_value: 4.4)
  elsif ['base-enclosure-rooftypes.xml'].include? hpxml_file
    hpxml.roofs.reverse_each do |roof|
      roof.delete
    end
    roof_types = [[HPXML::RoofTypeClayTile, HPXML::ColorLight],
                  [HPXML::RoofTypeMetal, HPXML::ColorReflective],
                  [HPXML::RoofTypeWoodShingles, HPXML::ColorDark],
                  [HPXML::RoofTypeShingles, HPXML::ColorMediumDark],
                  [HPXML::RoofTypePlasticRubber, HPXML::ColorLight],
                  [HPXML::RoofTypeEPS, HPXML::ColorMedium],
                  [HPXML::RoofTypeConcrete, HPXML::ColorLight],
                  [HPXML::RoofTypeCool, HPXML::ColorReflective]]
    int_finish_types = [[HPXML::InteriorFinishGypsumBoard, 0.5],
                        [HPXML::InteriorFinishPlaster, 0.5],
                        [HPXML::InteriorFinishWood, 0.5]]
    roof_types.each_with_index do |roof_type, i|
      hpxml.roofs.add(id: "Roof#{hpxml.roofs.size + 1}",
                      interior_adjacent_to: HPXML::LocationAtticUnvented,
                      area: 1509.3 / roof_types.size,
                      roof_type: roof_type[0],
                      roof_color: roof_type[1],
                      emittance: 0.92,
                      pitch: 6,
                      radiant_barrier: false,
                      interior_finish_type: int_finish_types[i % int_finish_types.size][0],
                      interior_finish_thickness: int_finish_types[i % int_finish_types.size][1],
                      insulation_assembly_r_value: roof_type[0] == HPXML::RoofTypeEPS ? 7.0 : 2.3)
      hpxml.attics[0].attached_to_roof_idrefs << hpxml.roofs[-1].id
    end
  elsif ['base-enclosure-overhangs.xml'].include? hpxml_file
    # Test relaxed overhangs validation; https://github.com/NREL/OpenStudio-HPXML/issues/866
    hpxml.windows.each do |window|
      next unless window.overhangs_depth.nil?

      window.overhangs_depth = 0.0
      window.overhangs_distance_to_top_of_window = 0.0
      window.overhangs_distance_to_bottom_of_window = 0.0
    end
  end
  if ['base-enclosure-2stories-garage.xml',
      'base-enclosure-garage.xml'].include? hpxml_file
    grg_wall = hpxml.walls.select { |w|
                 w.interior_adjacent_to == HPXML::LocationGarage &&
                   w.exterior_adjacent_to == HPXML::LocationOutside
               }[0]
    hpxml.doors.add(id: "Door#{hpxml.doors.size + 1}",
                    wall_idref: grg_wall.id,
                    area: 70,
                    azimuth: 180,
                    r_value: 4.4)
  end
  if ['base-misc-neighbor-shading-bldgtype-multifamily.xml'].include? hpxml_file
    wall = hpxml.walls.select { |w| w.azimuth == hpxml.neighbor_buildings[0].azimuth }[0]
    wall.exterior_adjacent_to = HPXML::LocationOtherHeatedSpace
  end

  # ---------- #
  # HPXML HVAC #
  # ---------- #

  # General logic
  hpxml.heating_systems.each do |heating_system|
    if heating_system.heating_system_type == HPXML::HVACTypeBoiler &&
       heating_system.heating_system_fuel == HPXML::FuelTypeNaturalGas &&
       !heating_system.is_shared_system
      heating_system.electric_auxiliary_energy = 200
    elsif [HPXML::HVACTypeFloorFurnace,
           HPXML::HVACTypeWallFurnace,
           HPXML::HVACTypeFireplace,
           HPXML::HVACTypeFixedHeater,
           HPXML::HVACTypePortableHeater].include? heating_system.heating_system_type
      heating_system.fan_watts = 0
    elsif [HPXML::HVACTypeStove].include? heating_system.heating_system_type
      heating_system.fan_watts = 40
    end
  end
  hpxml.heat_pumps.each do |heat_pump|
    if heat_pump.heat_pump_type == HPXML::HVACTypeHeatPumpGroundToAir
      heat_pump.pump_watts_per_ton = 30.0
    end
  end

  # Logic that can only be applied based on the file name
  if hpxml_file.include?('chiller') || hpxml_file.include?('cooling-tower')
    # Handle chiller/cooling tower
    if hpxml_file.include? 'chiller'
      hpxml.cooling_systems.add(id: "CoolingSystem#{hpxml.cooling_systems.size + 1}",
                                cooling_system_type: HPXML::HVACTypeChiller,
                                cooling_system_fuel: HPXML::FuelTypeElectricity,
                                is_shared_system: true,
                                number_of_units_served: 6,
                                cooling_capacity: 24000 * 6,
                                cooling_efficiency_kw_per_ton: 0.9,
                                fraction_cool_load_served: 1.0,
                                primary_system: true)
    elsif hpxml_file.include? 'cooling-tower'
      hpxml.cooling_systems.add(id: "CoolingSystem#{hpxml.cooling_systems.size + 1}",
                                cooling_system_type: HPXML::HVACTypeCoolingTower,
                                cooling_system_fuel: HPXML::FuelTypeElectricity,
                                is_shared_system: true,
                                number_of_units_served: 6,
                                fraction_cool_load_served: 1.0,
                                primary_system: true)
    end
    if hpxml_file.include? 'boiler'
      hpxml.hvac_controls[0].cooling_setpoint_temp = 78.0
      hpxml.cooling_systems[-1].distribution_system_idref = hpxml.hvac_distributions[-1].id
    else
      hpxml.hvac_controls.add(id: "HVACControl#{hpxml.hvac_controls.size + 1}",
                              control_type: HPXML::HVACControlTypeManual,
                              cooling_setpoint_temp: 78.0)
      if hpxml_file.include? 'baseboard'
        hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                     distribution_system_type: HPXML::HVACDistributionTypeHydronic,
                                     hydronic_type: HPXML::HydronicTypeBaseboard)
        hpxml.cooling_systems[-1].distribution_system_idref = hpxml.hvac_distributions[-1].id
      end
    end
  end
  if hpxml_file.include?('water-loop-heat-pump') || hpxml_file.include?('fan-coil')
    # Handle WLHP/ducted fan coil
    hpxml.hvac_distributions.reverse_each do |hvac_distribution|
      hvac_distribution.delete
    end
    if hpxml_file.include? 'water-loop-heat-pump'
      hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                   distribution_system_type: HPXML::HVACDistributionTypeHydronic,
                                   hydronic_type: HPXML::HydronicTypeWaterLoop)
      hpxml.heat_pumps.add(id: "HeatPump#{hpxml.heat_pumps.size + 1}",
                           heat_pump_type: HPXML::HVACTypeHeatPumpWaterLoopToAir,
                           heat_pump_fuel: HPXML::FuelTypeElectricity)
      if hpxml_file.include? 'boiler'
        hpxml.heat_pumps[-1].heating_capacity = 24000
        hpxml.heat_pumps[-1].heating_efficiency_cop = 4.4
        hpxml.heating_systems[-1].distribution_system_idref = hpxml.hvac_distributions[-1].id
      end
      if hpxml_file.include?('chiller') || hpxml_file.include?('cooling-tower')
        hpxml.heat_pumps[-1].cooling_capacity = 24000
        hpxml.heat_pumps[-1].cooling_efficiency_eer = 12.8
        hpxml.cooling_systems[-1].distribution_system_idref = hpxml.hvac_distributions[-1].id
      end
      hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                   distribution_system_type: HPXML::HVACDistributionTypeAir,
                                   air_type: HPXML::AirTypeRegularVelocity)
      hpxml.heat_pumps[-1].distribution_system_idref = hpxml.hvac_distributions[-1].id
    elsif hpxml_file.include? 'fan-coil'
      hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                   distribution_system_type: HPXML::HVACDistributionTypeAir,
                                   air_type: HPXML::AirTypeFanCoil)

      if hpxml_file.include? 'boiler'
        hpxml.heating_systems[-1].distribution_system_idref = hpxml.hvac_distributions[-1].id
      end
      if hpxml_file.include?('chiller') || hpxml_file.include?('cooling-tower')
        hpxml.cooling_systems[-1].distribution_system_idref = hpxml.hvac_distributions[-1].id
      end
    end
    if hpxml_file.include?('water-loop-heat-pump') || hpxml_file.include?('fan-coil-ducted')
      hpxml.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                                 duct_leakage_units: HPXML::UnitsCFM25,
                                                                 duct_leakage_value: 15,
                                                                 duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
      hpxml.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                                 duct_leakage_units: HPXML::UnitsCFM25,
                                                                 duct_leakage_value: 10,
                                                                 duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
      hpxml.hvac_distributions[-1].ducts.add(id: "Ducts#{hpxml.hvac_distributions[-1].ducts.size + 1}",
                                             duct_type: HPXML::DuctTypeSupply,
                                             duct_insulation_r_value: 0,
                                             duct_location: HPXML::LocationOtherMultifamilyBufferSpace,
                                             duct_surface_area: 50)
      hpxml.hvac_distributions[-1].ducts.add(id: "Ducts#{hpxml.hvac_distributions[-1].ducts.size + 1}",
                                             duct_type: HPXML::DuctTypeReturn,
                                             duct_insulation_r_value: 0,
                                             duct_location: HPXML::LocationOtherMultifamilyBufferSpace,
                                             duct_surface_area: 20)
    end
  end
  if hpxml_file.include? 'shared-ground-loop'
    hpxml.heating_systems.reverse_each do |heating_system|
      heating_system.delete
    end
    hpxml.cooling_systems.reverse_each do |cooling_system|
      cooling_system.delete
    end
    hpxml.heat_pumps.add(id: "HeatPump#{hpxml.heat_pumps.size + 1}",
                         distribution_system_idref: hpxml.hvac_distributions[-1].id,
                         heat_pump_type: HPXML::HVACTypeHeatPumpGroundToAir,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         backup_type: HPXML::HeatPumpBackupTypeIntegrated,
                         backup_heating_fuel: HPXML::FuelTypeElectricity,
                         is_shared_system: true,
                         number_of_units_served: 6,
                         backup_heating_efficiency_percent: 1.0,
                         fraction_heat_load_served: 1,
                         fraction_cool_load_served: 1,
                         heating_efficiency_cop: 3.6,
                         cooling_efficiency_eer: 16.6,
                         heating_capacity: 12000,
                         cooling_capacity: 12000,
                         backup_heating_capacity: 12000,
                         cooling_shr: 0.73,
                         primary_heating_system: true,
                         primary_cooling_system: true,
                         pump_watts_per_ton: 0.0)

  end
  if hpxml_file.include? 'eae'
    hpxml.heating_systems[0].electric_auxiliary_energy = 500.0
  else
    if hpxml_file.include? 'shared-boiler'
      hpxml.heating_systems[0].shared_loop_watts = 600
    end
    if hpxml_file.include?('chiller') || hpxml_file.include?('cooling-tower')
      hpxml.cooling_systems[0].shared_loop_watts = 600
    end
    if hpxml_file.include? 'shared-ground-loop'
      hpxml.heat_pumps[0].shared_loop_watts = 600
    end
    if hpxml_file.include? 'fan-coil'
      if hpxml_file.include? 'boiler'
        hpxml.heating_systems[0].fan_coil_watts = 150
      end
      if hpxml_file.include? 'chiller'
        hpxml.cooling_systems[0].fan_coil_watts = 150
      end
    end
  end
  if hpxml_file.include? 'install-quality'
    hpxml.hvac_systems.each do |hvac_system|
      hvac_system.fan_watts_per_cfm = 0.365
    end
  elsif ['base-hvac-setpoints-daily-setbacks.xml'].include? hpxml_file
    hpxml.hvac_controls[0].heating_setback_temp = 66
    hpxml.hvac_controls[0].heating_setback_hours_per_week = 7 * 7
    hpxml.hvac_controls[0].heating_setback_start_hour = 23 # 11pm
    hpxml.hvac_controls[0].cooling_setup_temp = 80
    hpxml.hvac_controls[0].cooling_setup_hours_per_week = 6 * 7
    hpxml.hvac_controls[0].cooling_setup_start_hour = 9 # 9am
  elsif ['base-hvac-dse.xml',
         'base-dhw-indirect-dse.xml',
         'base-mechvent-cfis-dse.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].distribution_system_type = HPXML::HVACDistributionTypeDSE
    hpxml.hvac_distributions[0].annual_heating_dse = 0.8
    hpxml.hvac_distributions[0].annual_cooling_dse = 0.7
  elsif ['base-hvac-furnace-x3-dse.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].distribution_system_type = HPXML::HVACDistributionTypeDSE
    hpxml.hvac_distributions[0].annual_heating_dse = 0.8
    hpxml.hvac_distributions[0].annual_cooling_dse = 0.7
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[1].id = "HVACDistribution#{hpxml.hvac_distributions.size}"
    hpxml.hvac_distributions[1].annual_cooling_dse = 1.0
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[2].id = "HVACDistribution#{hpxml.hvac_distributions.size}"
    hpxml.hvac_distributions[2].annual_cooling_dse = 1.0
    hpxml.heating_systems[0].primary_system = false
    hpxml.heating_systems << hpxml.heating_systems[0].dup
    hpxml.heating_systems[1].id = "HeatingSystem#{hpxml.heating_systems.size}"
    hpxml.heating_systems[1].distribution_system_idref = hpxml.hvac_distributions[1].id
    hpxml.heating_systems << hpxml.heating_systems[0].dup
    hpxml.heating_systems[2].id = "HeatingSystem#{hpxml.heating_systems.size}"
    hpxml.heating_systems[2].distribution_system_idref = hpxml.hvac_distributions[2].id
    hpxml.heating_systems[2].primary_system = true
    for i in 0..2
      hpxml.heating_systems[i].heating_capacity /= 3.0
      # Test a file where sum is slightly greater than 1
      if i < 2
        hpxml.heating_systems[i].fraction_heat_load_served = 0.33
      else
        hpxml.heating_systems[i].fraction_heat_load_served = 0.35
      end
    end
  elsif ['base-enclosure-2stories.xml',
         'base-enclosure-2stories-garage.xml',
         'base-hvac-ducts-area-fractions.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts << hpxml.hvac_distributions[0].ducts[0].dup
    hpxml.hvac_distributions[0].ducts[-1].id = "Ducts#{hpxml.hvac_distributions[0].ducts.size}"
    hpxml.hvac_distributions[0].ducts << hpxml.hvac_distributions[0].ducts[1].dup
    hpxml.hvac_distributions[0].ducts[-1].id = "Ducts#{hpxml.hvac_distributions[0].ducts.size}"
    hpxml.hvac_distributions[0].ducts[2].duct_location = HPXML::LocationExteriorWall
    hpxml.hvac_distributions[0].ducts[2].duct_surface_area = 37.5
    hpxml.hvac_distributions[0].ducts[3].duct_location = HPXML::LocationLivingSpace
    hpxml.hvac_distributions[0].ducts[3].duct_surface_area = 12.5
    if hpxml_file == 'base-hvac-ducts-area-fractions.xml'
      hpxml.hvac_distributions[0].ducts[0].duct_surface_area = nil
      hpxml.hvac_distributions[0].ducts[1].duct_surface_area = nil
      hpxml.hvac_distributions[0].ducts[2].duct_surface_area = nil
      hpxml.hvac_distributions[0].ducts[3].duct_surface_area = nil
      hpxml.hvac_distributions[0].ducts[0].duct_fraction_area = 0.75
      hpxml.hvac_distributions[0].ducts[1].duct_fraction_area = 0.75
      hpxml.hvac_distributions[0].ducts[2].duct_fraction_area = 0.25
      hpxml.hvac_distributions[0].ducts[3].duct_fraction_area = 0.25
      hpxml.hvac_distributions[0].conditioned_floor_area_served = 4050.0
      hpxml.hvac_distributions[0].number_of_return_registers = 3
    end
  elsif ['base-hvac-ducts-effective-rvalue.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_insulation_r_value = nil
    hpxml.hvac_distributions[0].ducts[1].duct_insulation_r_value = nil
    hpxml.hvac_distributions[0].ducts[0].duct_effective_r_value = 4.5
    hpxml.hvac_distributions[0].ducts[1].duct_effective_r_value = 1.7
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    hpxml.hvac_distributions.reverse_each do |hvac_distribution|
      hvac_distribution.delete
    end
    hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                 distribution_system_type: HPXML::HVACDistributionTypeAir,
                                 air_type: HPXML::AirTypeRegularVelocity)
    hpxml.hvac_distributions[0].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                              duct_leakage_units: HPXML::UnitsCFM25,
                                                              duct_leakage_value: 75,
                                                              duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
    hpxml.hvac_distributions[0].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                              duct_leakage_units: HPXML::UnitsCFM25,
                                                              duct_leakage_value: 25,
                                                              duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
    hpxml.hvac_distributions[0].ducts.add(id: "Ducts#{hpxml.hvac_distributions[0].ducts.size + 1}",
                                          duct_type: HPXML::DuctTypeSupply,
                                          duct_insulation_r_value: 8,
                                          duct_location: HPXML::LocationAtticUnvented,
                                          duct_surface_area: 75)
    hpxml.hvac_distributions[0].ducts.add(id: "Ducts#{hpxml.hvac_distributions[0].ducts.size + 1}",
                                          duct_type: HPXML::DuctTypeSupply,
                                          duct_insulation_r_value: 8,
                                          duct_location: HPXML::LocationOutside,
                                          duct_surface_area: 75)
    hpxml.hvac_distributions[0].ducts.add(id: "Ducts#{hpxml.hvac_distributions[0].ducts.size + 1}",
                                          duct_type: HPXML::DuctTypeReturn,
                                          duct_insulation_r_value: 4,
                                          duct_location: HPXML::LocationAtticUnvented,
                                          duct_surface_area: 25)
    hpxml.hvac_distributions[0].ducts.add(id: "Ducts#{hpxml.hvac_distributions[0].ducts.size + 1}",
                                          duct_type: HPXML::DuctTypeReturn,
                                          duct_insulation_r_value: 4,
                                          duct_location: HPXML::LocationOutside,
                                          duct_surface_area: 25)
    hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                 distribution_system_type: HPXML::HVACDistributionTypeAir,
                                 air_type: HPXML::AirTypeRegularVelocity)
    hpxml.hvac_distributions[-1].duct_leakage_measurements << hpxml.hvac_distributions[0].duct_leakage_measurements[0].dup
    hpxml.hvac_distributions[-1].duct_leakage_measurements << hpxml.hvac_distributions[0].duct_leakage_measurements[1].dup
    for i in 0..3
      hpxml.hvac_distributions[-1].ducts << hpxml.hvac_distributions[0].ducts[i].dup
      hpxml.hvac_distributions[-1].ducts[-1].id = "Ducts#{hpxml.hvac_distributions[0].ducts.size + i + 1}"
    end
    hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                 distribution_system_type: HPXML::HVACDistributionTypeHydronic,
                                 hydronic_type: HPXML::HydronicTypeBaseboard)
    hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                 distribution_system_type: HPXML::HVACDistributionTypeHydronic,
                                 hydronic_type: HPXML::HydronicTypeBaseboard)
    hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                 distribution_system_type: HPXML::HVACDistributionTypeAir,
                                 air_type: HPXML::AirTypeRegularVelocity)
    hpxml.hvac_distributions[-1].duct_leakage_measurements << hpxml.hvac_distributions[0].duct_leakage_measurements[0].dup
    hpxml.hvac_distributions[-1].duct_leakage_measurements << hpxml.hvac_distributions[0].duct_leakage_measurements[1].dup
    for i in 0..3
      hpxml.hvac_distributions[-1].ducts << hpxml.hvac_distributions[0].ducts[i].dup
      hpxml.hvac_distributions[-1].ducts[-1].id = "Ducts#{hpxml.hvac_distributions[0].ducts.size * 2 + i + 1}"
    end
    hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                 distribution_system_type: HPXML::HVACDistributionTypeAir,
                                 air_type: HPXML::AirTypeRegularVelocity)
    hpxml.hvac_distributions[-1].duct_leakage_measurements << hpxml.hvac_distributions[0].duct_leakage_measurements[0].dup
    hpxml.hvac_distributions[-1].duct_leakage_measurements << hpxml.hvac_distributions[0].duct_leakage_measurements[1].dup
    for i in 0..3
      hpxml.hvac_distributions[-1].ducts << hpxml.hvac_distributions[0].ducts[i].dup
      hpxml.hvac_distributions[-1].ducts[-1].id = "Ducts#{hpxml.hvac_distributions[0].ducts.size * 3 + i + 1}"
    end
    hpxml.heating_systems.reverse_each do |heating_system|
      heating_system.delete
    end
    hpxml.heating_systems.add(id: "HeatingSystem#{hpxml.heating_systems.size + 1}",
                              distribution_system_idref: hpxml.hvac_distributions[0].id,
                              heating_system_type: HPXML::HVACTypeFurnace,
                              heating_system_fuel: HPXML::FuelTypeElectricity,
                              heating_capacity: 6400,
                              heating_efficiency_afue: 1,
                              fraction_heat_load_served: 0.1)
    hpxml.heating_systems.add(id: "HeatingSystem#{hpxml.heating_systems.size + 1}",
                              distribution_system_idref: hpxml.hvac_distributions[1].id,
                              heating_system_type: HPXML::HVACTypeFurnace,
                              heating_system_fuel: HPXML::FuelTypeNaturalGas,
                              heating_capacity: 6400,
                              heating_efficiency_afue: 0.92,
                              fraction_heat_load_served: 0.1)
    hpxml.heating_systems.add(id: "HeatingSystem#{hpxml.heating_systems.size + 1}",
                              distribution_system_idref: hpxml.hvac_distributions[2].id,
                              heating_system_type: HPXML::HVACTypeBoiler,
                              heating_system_fuel: HPXML::FuelTypeElectricity,
                              heating_capacity: 6400,
                              heating_efficiency_afue: 1,
                              fraction_heat_load_served: 0.1)
    hpxml.heating_systems.add(id: "HeatingSystem#{hpxml.heating_systems.size + 1}",
                              distribution_system_idref: hpxml.hvac_distributions[3].id,
                              heating_system_type: HPXML::HVACTypeBoiler,
                              heating_system_fuel: HPXML::FuelTypeNaturalGas,
                              heating_capacity: 6400,
                              heating_efficiency_afue: 0.92,
                              fraction_heat_load_served: 0.1,
                              electric_auxiliary_energy: 200)
    hpxml.heating_systems.add(id: "HeatingSystem#{hpxml.heating_systems.size + 1}",
                              heating_system_type: HPXML::HVACTypeElectricResistance,
                              heating_system_fuel: HPXML::FuelTypeElectricity,
                              heating_capacity: 6400,
                              heating_efficiency_percent: 1,
                              fraction_heat_load_served: 0.1)
    hpxml.heating_systems.add(id: "HeatingSystem#{hpxml.heating_systems.size + 1}",
                              heating_system_type: HPXML::HVACTypeStove,
                              heating_system_fuel: HPXML::FuelTypeOil,
                              heating_capacity: 6400,
                              heating_efficiency_percent: 0.8,
                              fraction_heat_load_served: 0.1,
                              fan_watts: 40.0)
    hpxml.heating_systems.add(id: "HeatingSystem#{hpxml.heating_systems.size + 1}",
                              heating_system_type: HPXML::HVACTypeWallFurnace,
                              heating_system_fuel: HPXML::FuelTypePropane,
                              heating_capacity: 6400,
                              heating_efficiency_afue: 0.8,
                              fraction_heat_load_served: 0.1,
                              fan_watts: 0.0)
    hpxml.cooling_systems[0].distribution_system_idref = hpxml.hvac_distributions[1].id
    hpxml.cooling_systems[0].fraction_cool_load_served = 0.1333
    hpxml.cooling_systems[0].cooling_capacity *= 0.1333
    hpxml.cooling_systems[0].primary_system = false
    hpxml.cooling_systems.add(id: "CoolingSystem#{hpxml.cooling_systems.size + 1}",
                              cooling_system_type: HPXML::HVACTypeRoomAirConditioner,
                              cooling_system_fuel: HPXML::FuelTypeElectricity,
                              cooling_capacity: 9600,
                              fraction_cool_load_served: 0.1333,
                              cooling_efficiency_eer: 8.5,
                              cooling_shr: 0.65)
    hpxml.cooling_systems.add(id: "CoolingSystem#{hpxml.cooling_systems.size + 1}",
                              cooling_system_type: HPXML::HVACTypePTAC,
                              cooling_system_fuel: HPXML::FuelTypeElectricity,
                              cooling_capacity: 9600,
                              fraction_cool_load_served: 0.1333,
                              cooling_efficiency_eer: 10.7,
                              cooling_shr: 0.65)
    hpxml.heat_pumps.add(id: "HeatPump#{hpxml.heat_pumps.size + 1}",
                         distribution_system_idref: hpxml.hvac_distributions[4].id,
                         heat_pump_type: HPXML::HVACTypeHeatPumpAirToAir,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         heating_capacity: 4800,
                         cooling_capacity: 4800,
                         backup_type: HPXML::HeatPumpBackupTypeIntegrated,
                         backup_heating_fuel: HPXML::FuelTypeElectricity,
                         backup_heating_capacity: 3412,
                         backup_heating_efficiency_percent: 1.0,
                         fraction_heat_load_served: 0.1,
                         fraction_cool_load_served: 0.2,
                         heating_efficiency_hspf: 7.7,
                         cooling_efficiency_seer: 13,
                         heating_capacity_17F: 4800 * 0.6,
                         cooling_shr: 0.73,
                         compressor_type: HPXML::HVACCompressorTypeSingleStage)
    hpxml.heat_pumps.add(id: "HeatPump#{hpxml.heat_pumps.size + 1}",
                         distribution_system_idref: hpxml.hvac_distributions[5].id,
                         heat_pump_type: HPXML::HVACTypeHeatPumpGroundToAir,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         heating_capacity: 4800,
                         cooling_capacity: 4800,
                         backup_type: HPXML::HeatPumpBackupTypeIntegrated,
                         backup_heating_fuel: HPXML::FuelTypeElectricity,
                         backup_heating_capacity: 3412,
                         backup_heating_efficiency_percent: 1.0,
                         fraction_heat_load_served: 0.1,
                         fraction_cool_load_served: 0.2,
                         heating_efficiency_cop: 3.6,
                         cooling_efficiency_eer: 16.6,
                         cooling_shr: 0.73,
                         pump_watts_per_ton: 30.0)
    hpxml.heat_pumps.add(id: "HeatPump#{hpxml.heat_pumps.size + 1}",
                         heat_pump_type: HPXML::HVACTypeHeatPumpMiniSplit,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         heating_capacity: 4800,
                         cooling_capacity: 4800,
                         backup_type: HPXML::HeatPumpBackupTypeIntegrated,
                         backup_heating_fuel: HPXML::FuelTypeElectricity,
                         backup_heating_capacity: 3412,
                         backup_heating_efficiency_percent: 1.0,
                         fraction_heat_load_served: 0.1,
                         fraction_cool_load_served: 0.2,
                         heating_efficiency_hspf: 10,
                         cooling_efficiency_seer: 19,
                         heating_capacity_17F: 4800 * 0.6,
                         cooling_shr: 0.73,
                         primary_cooling_system: true,
                         primary_heating_system: true)
  elsif ['base-mechvent-multiple.xml',
         'base-bldgtype-multifamily-shared-mechvent-multiple.xml'].include? hpxml_file
    hpxml.hvac_distributions.add(id: "HVACDistribution#{hpxml.hvac_distributions.size + 1}",
                                 distribution_system_type: HPXML::HVACDistributionTypeAir,
                                 air_type: HPXML::AirTypeRegularVelocity)
    hpxml.hvac_distributions[1].duct_leakage_measurements << hpxml.hvac_distributions[0].duct_leakage_measurements[0].dup
    hpxml.hvac_distributions[1].duct_leakage_measurements << hpxml.hvac_distributions[0].duct_leakage_measurements[1].dup
    hpxml.hvac_distributions[1].ducts << hpxml.hvac_distributions[0].ducts[0].dup
    hpxml.hvac_distributions[1].ducts << hpxml.hvac_distributions[0].ducts[1].dup
    hpxml.hvac_distributions[1].ducts[0].id = "Ducts#{hpxml.hvac_distributions[0].ducts.size + 1}"
    hpxml.hvac_distributions[1].ducts[1].id = "Ducts#{hpxml.hvac_distributions[0].ducts.size + 2}"
    hpxml.heating_systems[0].heating_capacity /= 2.0
    hpxml.heating_systems[0].fraction_heat_load_served /= 2.0
    hpxml.heating_systems[0].primary_system = false
    hpxml.heating_systems << hpxml.heating_systems[0].dup
    hpxml.heating_systems[1].id = "HeatingSystem#{hpxml.heating_systems.size}"
    hpxml.heating_systems[1].distribution_system_idref = hpxml.hvac_distributions[1].id
    hpxml.heating_systems[1].primary_system = true
    hpxml.cooling_systems[0].fraction_cool_load_served /= 2.0
    hpxml.cooling_systems[0].cooling_capacity /= 2.0
    hpxml.cooling_systems[0].primary_system = false
    hpxml.cooling_systems << hpxml.cooling_systems[0].dup
    hpxml.cooling_systems[1].id = "CoolingSystem#{hpxml.cooling_systems.size}"
    hpxml.cooling_systems[1].distribution_system_idref = hpxml.hvac_distributions[1].id
    hpxml.cooling_systems[1].primary_system = true
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationOtherHousingUnit
    hpxml.hvac_distributions[0].ducts.add(id: "Ducts#{hpxml.hvac_distributions[0].ducts.size + 1}",
                                          duct_type: HPXML::DuctTypeSupply,
                                          duct_insulation_r_value: 4,
                                          duct_location: HPXML::LocationRoofDeck,
                                          duct_surface_area: 150)
    hpxml.hvac_distributions[0].ducts.add(id: "Ducts#{hpxml.hvac_distributions[0].ducts.size + 1}",
                                          duct_type: HPXML::DuctTypeReturn,
                                          duct_insulation_r_value: 0,
                                          duct_location: HPXML::LocationRoofDeck,
                                          duct_surface_area: 50)
  elsif ['base-appliances-dehumidifier-multiple.xml'].include? hpxml_file
    hpxml.dehumidifiers[0].fraction_served = 0.5
    hpxml.dehumidifiers.add(id: 'Dehumidifier2',
                            type: HPXML::DehumidifierTypePortable,
                            capacity: 30,
                            energy_factor: 1.6,
                            rh_setpoint: 0.5,
                            fraction_served: 0.25,
                            location: HPXML::LocationLivingSpace)
  end
  if ['base-hvac-air-to-air-heat-pump-var-speed-backup-furnace.xml',
      'base-hvac-autosize-air-to-air-heat-pump-var-speed-backup-furnace.xml'].include? hpxml_file
    # Switch backup boiler with hydronic distribution to backup furnace with air distribution
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeFurnace
    hpxml.hvac_distributions[0].distribution_system_type = HPXML::HVACDistributionTypeAir
    hpxml.hvac_distributions[0].air_type = HPXML::AirTypeRegularVelocity
    hpxml.hvac_distributions[0].duct_leakage_measurements << hpxml.hvac_distributions[1].duct_leakage_measurements[0].dup
    hpxml.hvac_distributions[0].duct_leakage_measurements << hpxml.hvac_distributions[1].duct_leakage_measurements[1].dup
    hpxml.hvac_distributions[0].ducts << hpxml.hvac_distributions[1].ducts[0].dup
    hpxml.hvac_distributions[0].ducts << hpxml.hvac_distributions[1].ducts[1].dup
    hpxml.hvac_distributions[1].ducts[0].id = "Ducts#{hpxml.hvac_distributions[0].ducts.size + 1}"
    hpxml.hvac_distributions[1].ducts[1].id = "Ducts#{hpxml.hvac_distributions[0].ducts.size + 2}"
  end
  if ['base-hvac-ducts-area-multipliers.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_surface_area_multiplier = 0.5
    hpxml.hvac_distributions[0].ducts[1].duct_surface_area_multiplier = 1.5
  end
  if ['base-hvac-autosize-sizing-controls.xml'].include? hpxml_file
    hpxml.header.manualj_heating_design_temp = 0
    hpxml.header.manualj_cooling_design_temp = 100
    hpxml.header.manualj_heating_setpoint = 60
    hpxml.header.manualj_cooling_setpoint = 80
    hpxml.header.manualj_humidity_setpoint = 0.55
    hpxml.header.manualj_internal_loads_sensible = 4000
    hpxml.header.manualj_internal_loads_latent = 200
    hpxml.header.manualj_num_occupants = 5
  end
  if hpxml_file.include? 'heating-capacity-17f'
    hpxml.heat_pumps[0].heating_capacity_17F = hpxml.heat_pumps[0].heating_capacity * hpxml.heat_pumps[0].heating_capacity_retention_fraction
    hpxml.heat_pumps[0].heating_capacity_retention_fraction = nil
    hpxml.heat_pumps[0].heating_capacity_retention_temp = nil
  end

  # ------------------ #
  # HPXML WaterHeating #
  # ------------------ #

  # Logic that can only be applied based on the file name
  if ['base-schedules-simple.xml',
      'base-schedules-simple-vacancy.xml',
      'base-schedules-simple-vacancy-year-round.xml',
      'base-schedules-simple-power-outage.xml',
      'base-misc-loads-large-uncommon.xml',
      'base-misc-loads-large-uncommon2.xml'].include? hpxml_file
    hpxml.water_heating.water_fixtures_weekday_fractions = '0.012, 0.006, 0.004, 0.005, 0.010, 0.034, 0.078, 0.087, 0.080, 0.067, 0.056, 0.047, 0.040, 0.035, 0.033, 0.031, 0.039, 0.051, 0.060, 0.060, 0.055, 0.048, 0.038, 0.026'
    hpxml.water_heating.water_fixtures_weekend_fractions = '0.012, 0.006, 0.004, 0.005, 0.010, 0.034, 0.078, 0.087, 0.080, 0.067, 0.056, 0.047, 0.040, 0.035, 0.033, 0.031, 0.039, 0.051, 0.060, 0.060, 0.055, 0.048, 0.038, 0.026'
    hpxml.water_heating.water_fixtures_monthly_multipliers = '1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0'
  elsif ['base-bldgtype-multifamily-shared-water-heater-recirc.xml'].include? hpxml_file
    hpxml.hot_water_distributions[0].has_shared_recirculation = true
    hpxml.hot_water_distributions[0].shared_recirculation_number_of_units_served = 6
    hpxml.hot_water_distributions[0].shared_recirculation_pump_power = 220
    hpxml.hot_water_distributions[0].shared_recirculation_control_type = HPXML::DHWRecirControlTypeTimer
  elsif ['base-bldgtype-multifamily-shared-laundry-room.xml',
         'base-bldgtype-multifamily-shared-laundry-room-multiple-water-heaters.xml'].include? hpxml_file
    hpxml.water_heating_systems.reverse_each do |water_heating_system|
      water_heating_system.delete
    end
    hpxml.water_heating_systems.add(id: "WaterHeatingSystem#{hpxml.water_heating_systems.size + 1}",
                                    is_shared_system: true,
                                    number_of_units_served: 6,
                                    fuel_type: HPXML::FuelTypeNaturalGas,
                                    water_heater_type: HPXML::WaterHeaterTypeStorage,
                                    location: HPXML::LocationLivingSpace,
                                    tank_volume: 120,
                                    fraction_dhw_load_served: 1.0,
                                    heating_capacity: 40000,
                                    energy_factor: 0.59,
                                    recovery_efficiency: 0.76,
                                    temperature: 125.0)
    if hpxml_file == 'base-bldgtype-multifamily-shared-laundry-room-multiple-water-heaters.xml'
      hpxml.water_heating_systems[0].fraction_dhw_load_served /= 2.0
      hpxml.water_heating_systems[0].tank_volume /= 2.0
      hpxml.water_heating_systems[0].number_of_units_served /= 2.0
      hpxml.water_heating_systems << hpxml.water_heating_systems[0].dup
      hpxml.water_heating_systems[1].id = "WaterHeatingSystem#{hpxml.water_heating_systems.size}"
    end
  elsif ['base-dhw-tank-gas-uef-fhr.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].first_hour_rating = 56.0
    hpxml.water_heating_systems[0].usage_bin = nil
  elsif ['base-dhw-tankless-electric-outside.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].performance_adjustment = 0.92
  elsif ['base-dhw-multiple.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fraction_dhw_load_served = 0.2
    hpxml.water_heating_systems.add(id: "WaterHeatingSystem#{hpxml.water_heating_systems.size + 1}",
                                    fuel_type: HPXML::FuelTypeNaturalGas,
                                    water_heater_type: HPXML::WaterHeaterTypeStorage,
                                    location: HPXML::LocationLivingSpace,
                                    tank_volume: 50,
                                    fraction_dhw_load_served: 0.2,
                                    heating_capacity: 40000,
                                    energy_factor: 0.59,
                                    recovery_efficiency: 0.76,
                                    temperature: 125.0)
    hpxml.water_heating_systems.add(id: "WaterHeatingSystem#{hpxml.water_heating_systems.size + 1}",
                                    fuel_type: HPXML::FuelTypeElectricity,
                                    water_heater_type: HPXML::WaterHeaterTypeHeatPump,
                                    location: HPXML::LocationLivingSpace,
                                    tank_volume: 80,
                                    fraction_dhw_load_served: 0.2,
                                    energy_factor: 2.3,
                                    temperature: 125.0)
    hpxml.water_heating_systems.add(id: "WaterHeatingSystem#{hpxml.water_heating_systems.size + 1}",
                                    fuel_type: HPXML::FuelTypeElectricity,
                                    water_heater_type: HPXML::WaterHeaterTypeTankless,
                                    location: HPXML::LocationLivingSpace,
                                    fraction_dhw_load_served: 0.2,
                                    energy_factor: 0.99,
                                    temperature: 125.0)
    hpxml.water_heating_systems.add(id: "WaterHeatingSystem#{hpxml.water_heating_systems.size + 1}",
                                    fuel_type: HPXML::FuelTypeNaturalGas,
                                    water_heater_type: HPXML::WaterHeaterTypeTankless,
                                    location: HPXML::LocationLivingSpace,
                                    fraction_dhw_load_served: 0.1,
                                    energy_factor: 0.82,
                                    temperature: 125.0)
    hpxml.water_heating_systems.add(id: "WaterHeatingSystem#{hpxml.water_heating_systems.size + 1}",
                                    water_heater_type: HPXML::WaterHeaterTypeCombiStorage,
                                    location: HPXML::LocationLivingSpace,
                                    tank_volume: 50,
                                    fraction_dhw_load_served: 0.1,
                                    related_hvac_idref: 'HeatingSystem1',
                                    temperature: 125.0)
    hpxml.solar_thermal_systems.add(id: "SolarThermalSystem#{hpxml.solar_thermal_systems.size + 1}",
                                    system_type: HPXML::SolarThermalSystemType,
                                    water_heating_system_idref: nil, # Apply to all water heaters
                                    solar_fraction: 0.65)
  end

  # -------------------- #
  # HPXML VentilationFan #
  # -------------------- #

  # Logic that can only be applied based on the file name
  if ['base-bldgtype-multifamily-shared-mechvent-multiple.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeSupply,
                               is_shared_system: true,
                               in_unit_flow_rate: 100,
                               calculated_flow_rate: 1000,
                               hours_in_operation: 24,
                               fan_power: 300,
                               used_for_whole_building_ventilation: true,
                               fraction_recirculation: 0.0,
                               preheating_fuel: HPXML::FuelTypeNaturalGas,
                               preheating_efficiency_cop: 0.92,
                               preheating_fraction_load_served: 0.8,
                               precooling_fuel: HPXML::FuelTypeElectricity,
                               precooling_efficiency_cop: 4.0,
                               precooling_fraction_load_served: 0.8)
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeERV,
                               is_shared_system: true,
                               in_unit_flow_rate: 50,
                               delivered_ventilation: 500,
                               hours_in_operation: 24,
                               total_recovery_efficiency: 0.48,
                               sensible_recovery_efficiency: 0.72,
                               fan_power: 150,
                               used_for_whole_building_ventilation: true,
                               fraction_recirculation: 0.4,
                               preheating_fuel: HPXML::FuelTypeNaturalGas,
                               preheating_efficiency_cop: 0.87,
                               preheating_fraction_load_served: 1.0,
                               precooling_fuel: HPXML::FuelTypeElectricity,
                               precooling_efficiency_cop: 3.5,
                               precooling_fraction_load_served: 1.0)
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeHRV,
                               is_shared_system: true,
                               in_unit_flow_rate: 50,
                               rated_flow_rate: 500,
                               hours_in_operation: 24,
                               sensible_recovery_efficiency: 0.72,
                               fan_power: 150,
                               used_for_whole_building_ventilation: true,
                               fraction_recirculation: 0.3,
                               preheating_fuel: HPXML::FuelTypeElectricity,
                               preheating_efficiency_cop: 4.0,
                               precooling_fuel: HPXML::FuelTypeElectricity,
                               precooling_efficiency_cop: 4.5,
                               preheating_fraction_load_served: 1.0,
                               precooling_fraction_load_served: 1.0)
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeBalanced,
                               is_shared_system: true,
                               in_unit_flow_rate: 30,
                               tested_flow_rate: 300,
                               hours_in_operation: 24,
                               fan_power: 150,
                               used_for_whole_building_ventilation: true,
                               fraction_recirculation: 0.3,
                               preheating_fuel: HPXML::FuelTypeElectricity,
                               preheating_efficiency_cop: 3.5,
                               precooling_fuel: HPXML::FuelTypeElectricity,
                               precooling_efficiency_cop: 4.0,
                               preheating_fraction_load_served: 0.9,
                               precooling_fraction_load_served: 1.0)
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeExhaust,
                               is_shared_system: true,
                               in_unit_flow_rate: 70,
                               rated_flow_rate: 700,
                               hours_in_operation: 8,
                               fan_power: 300,
                               used_for_whole_building_ventilation: true,
                               fraction_recirculation: 0.0)
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeExhaust,
                               tested_flow_rate: 50,
                               hours_in_operation: 14,
                               fan_power: 10,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeCFIS,
                               tested_flow_rate: 160,
                               hours_in_operation: 8,
                               fan_power: 150,
                               used_for_whole_building_ventilation: true,
                               cfis_addtl_runtime_operating_mode: HPXML::CFISModeAirHandler,
                               distribution_system_idref: 'HVACDistribution1')
  elsif ['base-mechvent-multiple.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               rated_flow_rate: 2000,
                               fan_power: 150,
                               used_for_seasonal_cooling_load_reduction: true)
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeSupply,
                               tested_flow_rate: 12.5,
                               hours_in_operation: 14,
                               fan_power: 2.5,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeExhaust,
                               tested_flow_rate: 30.0,
                               fan_power: 7.5,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeBalanced,
                               tested_flow_rate: 27.5,
                               hours_in_operation: 24,
                               fan_power: 15,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeERV,
                               tested_flow_rate: 12.5,
                               hours_in_operation: 24,
                               total_recovery_efficiency: 0.48,
                               sensible_recovery_efficiency: 0.72,
                               fan_power: 6.25,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeHRV,
                               tested_flow_rate: 15,
                               hours_in_operation: 24,
                               sensible_recovery_efficiency: 0.72,
                               fan_power: 7.5,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.reverse_each do |vent_fan|
      vent_fan.fan_power /= 2.0
      vent_fan.rated_flow_rate /= 2.0 unless vent_fan.rated_flow_rate.nil?
      vent_fan.tested_flow_rate /= 2.0 unless vent_fan.tested_flow_rate.nil?
      hpxml.ventilation_fans << vent_fan.dup
      hpxml.ventilation_fans[-1].id = "VentilationFan#{hpxml.ventilation_fans.size}"
      hpxml.ventilation_fans[-1].start_hour = vent_fan.start_hour - 1 unless vent_fan.start_hour.nil?
      hpxml.ventilation_fans[-1].hours_in_operation = vent_fan.hours_in_operation - 1 unless vent_fan.hours_in_operation.nil?
    end
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeCFIS,
                               tested_flow_rate: 40,
                               hours_in_operation: 8,
                               fan_power: 37.5,
                               used_for_whole_building_ventilation: true,
                               cfis_addtl_runtime_operating_mode: HPXML::CFISModeAirHandler,
                               distribution_system_idref: 'HVACDistribution1')
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeCFIS,
                               tested_flow_rate: 42.5,
                               hours_in_operation: 8,
                               fan_power: 37.5,
                               used_for_whole_building_ventilation: true,
                               cfis_addtl_runtime_operating_mode: HPXML::CFISModeSupplementalFan,
                               cfis_supplemental_fan_idref: hpxml.ventilation_fans.find { |f| f.fan_type == HPXML::MechVentTypeExhaust }.id,
                               distribution_system_idref: 'HVACDistribution2')
    # Test ventilation system w/ zero airflow and hours
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeHRV,
                               tested_flow_rate: 0,
                               hours_in_operation: 24,
                               sensible_recovery_efficiency: 0.72,
                               fan_power: 7.5,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               fan_type: HPXML::MechVentTypeHRV,
                               tested_flow_rate: 15,
                               hours_in_operation: 0,
                               sensible_recovery_efficiency: 0.72,
                               fan_power: 7.5,
                               used_for_whole_building_ventilation: true)
  elsif ['base-mechvent-cfis-airflow-fraction-zero.xml'].include? hpxml_file
    hpxml.ventilation_fans[0].cfis_vent_mode_airflow_fraction = 0.0
  elsif ['base-mechvent-cfis-supplemental-fan-exhaust.xml',
         'base-mechvent-cfis-supplemental-fan-supply.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: "VentilationFan#{hpxml.ventilation_fans.size + 1}",
                               tested_flow_rate: 120,
                               fan_power: 30,
                               used_for_whole_building_ventilation: true)
    if hpxml_file == 'base-mechvent-cfis-supplemental-fan-exhaust.xml'
      hpxml.ventilation_fans[-1].fan_type = HPXML::MechVentTypeExhaust
    else
      hpxml.ventilation_fans[-1].fan_type = HPXML::MechVentTypeSupply
    end
    hpxml.ventilation_fans[0].cfis_addtl_runtime_operating_mode = HPXML::CFISModeSupplementalFan
    hpxml.ventilation_fans[0].cfis_supplemental_fan_idref = hpxml.ventilation_fans[1].id
  end

  # ---------------- #
  # HPXML Generation #
  # ---------------- #

  # Logic that can only be applied based on the file name
  if ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.pv_systems[0].year_modules_manufactured = 2015
  elsif ['base-misc-generators.xml',
         'base-misc-generators-battery.xml',
         'base-misc-generators-battery-scheduled.xml',
         'base-pv-generators.xml',
         'base-pv-generators-battery.xml',
         'base-pv-generators-battery-scheduled.xml'].include? hpxml_file
    hpxml.generators.add(id: "Generator#{hpxml.generators.size + 1}",
                         fuel_type: HPXML::FuelTypeNaturalGas,
                         annual_consumption_kbtu: 8500,
                         annual_output_kwh: 1200)
    hpxml.generators.add(id: "Generator#{hpxml.generators.size + 1}",
                         fuel_type: HPXML::FuelTypeOil,
                         annual_consumption_kbtu: 8500,
                         annual_output_kwh: 1200)
  elsif ['base-bldgtype-multifamily-shared-generator.xml'].include? hpxml_file
    hpxml.generators.add(id: "Generator#{hpxml.generators.size + 1}",
                         is_shared_system: true,
                         fuel_type: HPXML::FuelTypePropane,
                         annual_consumption_kbtu: 85000,
                         annual_output_kwh: 12000,
                         number_of_bedrooms_served: 18)
  end

  # ------------- #
  # HPXML Battery #
  # ------------- #

  if ['base-pv-battery-lifetime-model.xml'].include? hpxml_file
    hpxml.batteries[0].lifetime_model = HPXML::BatteryLifetimeModelKandlerSmith
  elsif ['base-pv-battery-ah.xml'].include? hpxml_file
    default_values = Battery.get_battery_default_values()
    hpxml.batteries[0].nominal_capacity_ah = Battery.get_Ah_from_kWh(hpxml.batteries[0].nominal_capacity_kwh,
                                                                     default_values[:nominal_voltage])
    hpxml.batteries[0].usable_capacity_ah = hpxml.batteries[0].nominal_capacity_ah * default_values[:usable_fraction]
    hpxml.batteries[0].nominal_capacity_kwh = nil
    hpxml.batteries[0].usable_capacity_kwh = nil
  end

  # ---------------- #
  # HPXML Appliances #
  # ---------------- #

  # Logic that can only be applied based on the file name
  if ['base-schedules-simple.xml',
      'base-schedules-simple-vacancy.xml',
      'base-schedules-simple-vacancy-year-round.xml',
      'base-schedules-simple-power-outage.xml',
      'base-misc-loads-large-uncommon.xml',
      'base-misc-loads-large-uncommon2.xml'].include? hpxml_file
    hpxml.clothes_washers[0].weekday_fractions = '0.009, 0.007, 0.004, 0.004, 0.007, 0.011, 0.022, 0.049, 0.073, 0.086, 0.084, 0.075, 0.067, 0.060, 0.049, 0.052, 0.050, 0.049, 0.049, 0.049, 0.049, 0.047, 0.032, 0.017'
    hpxml.clothes_washers[0].weekend_fractions = '0.009, 0.007, 0.004, 0.004, 0.007, 0.011, 0.022, 0.049, 0.073, 0.086, 0.084, 0.075, 0.067, 0.060, 0.049, 0.052, 0.050, 0.049, 0.049, 0.049, 0.049, 0.047, 0.032, 0.017'
    hpxml.clothes_washers[0].monthly_multipliers = '1.011, 1.002, 1.022, 1.020, 1.022, 0.996, 0.999, 0.999, 0.996, 0.964, 0.959, 1.011'
    hpxml.clothes_dryers[0].weekday_fractions = '0.010, 0.006, 0.004, 0.002, 0.004, 0.006, 0.016, 0.032, 0.048, 0.068, 0.078, 0.081, 0.074, 0.067, 0.057, 0.061, 0.055, 0.054, 0.051, 0.051, 0.052, 0.054, 0.044, 0.024'
    hpxml.clothes_dryers[0].weekend_fractions = '0.010, 0.006, 0.004, 0.002, 0.004, 0.006, 0.016, 0.032, 0.048, 0.068, 0.078, 0.081, 0.074, 0.067, 0.057, 0.061, 0.055, 0.054, 0.051, 0.051, 0.052, 0.054, 0.044, 0.024'
    hpxml.clothes_dryers[0].monthly_multipliers = '1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0'
    hpxml.dishwashers[0].weekday_fractions = '0.015, 0.007, 0.005, 0.003, 0.003, 0.010, 0.020, 0.031, 0.058, 0.065, 0.056, 0.048, 0.041, 0.046, 0.036, 0.038, 0.038, 0.049, 0.087, 0.111, 0.090, 0.067, 0.044, 0.031'
    hpxml.dishwashers[0].weekend_fractions = '0.015, 0.007, 0.005, 0.003, 0.003, 0.010, 0.020, 0.031, 0.058, 0.065, 0.056, 0.048, 0.041, 0.046, 0.036, 0.038, 0.038, 0.049, 0.087, 0.111, 0.090, 0.067, 0.044, 0.031'
    hpxml.dishwashers[0].monthly_multipliers = '1.097, 1.097, 0.991, 0.987, 0.991, 0.890, 0.896, 0.896, 0.890, 1.085, 1.085, 1.097'
    hpxml.refrigerators[0].weekday_fractions = '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
    hpxml.refrigerators[0].weekend_fractions = '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
    hpxml.refrigerators[0].monthly_multipliers = '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837'
    hpxml.cooking_ranges[0].weekday_fractions = '0.007, 0.007, 0.004, 0.004, 0.007, 0.011, 0.025, 0.042, 0.046, 0.048, 0.042, 0.050, 0.057, 0.046, 0.057, 0.044, 0.092, 0.150, 0.117, 0.060, 0.035, 0.025, 0.016, 0.011'
    hpxml.cooking_ranges[0].weekend_fractions = '0.007, 0.007, 0.004, 0.004, 0.007, 0.011, 0.025, 0.042, 0.046, 0.048, 0.042, 0.050, 0.057, 0.046, 0.057, 0.044, 0.092, 0.150, 0.117, 0.060, 0.035, 0.025, 0.016, 0.011'
    hpxml.cooking_ranges[0].monthly_multipliers = '1.097, 1.097, 0.991, 0.987, 0.991, 0.890, 0.896, 0.896, 0.890, 1.085, 1.085, 1.097'
  end
  if ['base-misc-loads-large-uncommon.xml',
      'base-misc-loads-large-uncommon2.xml',
      'base-misc-usage-multiplier.xml'].include? hpxml_file
    if hpxml_file != 'base-misc-usage-multiplier.xml'
      hpxml.refrigerators.add(id: "Refrigerator#{hpxml.refrigerators.size + 1}",
                              rated_annual_kwh: 800,
                              primary_indicator: false)
    end
    hpxml.freezers.add(id: "Freezer#{hpxml.freezers.size + 1}",
                       location: HPXML::LocationLivingSpace,
                       rated_annual_kwh: 400)
    if hpxml_file == 'base-misc-usage-multiplier.xml'
      hpxml.freezers[-1].usage_multiplier = 0.9
    end
    (hpxml.refrigerators + hpxml.freezers).each do |appliance|
      next if appliance.is_a?(HPXML::Refrigerator) && hpxml_file == 'base-misc-usage-multiplier.xml'

      appliance.weekday_fractions = '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
      appliance.weekend_fractions = '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
      appliance.monthly_multipliers = '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837'
    end
    hpxml.pools[0].pump_weekday_fractions = '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003'
    hpxml.pools[0].pump_weekend_fractions = '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003'
    hpxml.pools[0].pump_monthly_multipliers = '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154'
    hpxml.pools[0].heater_weekday_fractions = '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003'
    hpxml.pools[0].heater_weekend_fractions = '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003'
    hpxml.pools[0].heater_monthly_multipliers = '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154'
    hpxml.hot_tubs[0].pump_weekday_fractions = '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024'
    hpxml.hot_tubs[0].pump_weekend_fractions = '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024'
    hpxml.hot_tubs[0].pump_monthly_multipliers = '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837'
    hpxml.hot_tubs[0].heater_weekday_fractions = '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024'
    hpxml.hot_tubs[0].heater_weekend_fractions = '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024'
    hpxml.hot_tubs[0].heater_monthly_multipliers = '0.921, 0.928, 0.921, 0.915, 0.921, 1.160, 1.158, 1.158, 1.160, 0.921, 0.915, 0.921'
  end
  if ['base-bldgtype-multifamily-shared-laundry-room.xml',
      'base-bldgtype-multifamily-shared-laundry-room-multiple-water-heaters.xml'].include? hpxml_file
    hpxml.clothes_washers[0].is_shared_appliance = true
    hpxml.clothes_washers[0].location = HPXML::LocationOtherHeatedSpace
    hpxml.clothes_dryers[0].location = HPXML::LocationOtherHeatedSpace
    hpxml.clothes_dryers[0].is_shared_appliance = true
    hpxml.dishwashers[0].is_shared_appliance = true
    hpxml.dishwashers[0].location = HPXML::LocationOtherHeatedSpace
    if hpxml_file == 'base-bldgtype-multifamily-shared-laundry-room.xml'
      hpxml.clothes_washers[0].water_heating_system_idref = hpxml.water_heating_systems[0].id
      hpxml.dishwashers[0].water_heating_system_idref = hpxml.water_heating_systems[0].id
    elsif hpxml_file == 'base-bldgtype-multifamily-shared-laundry-room-multiple-water-heaters.xml'
      hpxml.clothes_washers[0].hot_water_distribution_idref = hpxml.hot_water_distributions[0].id
      hpxml.dishwashers[0].hot_water_distribution_idref = hpxml.hot_water_distributions[0].id
    end
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.refrigerators[0].primary_indicator = nil
  end

  # -------------- #
  # HPXML Lighting #
  # -------------- #

  # Logic that can only be applied based on the file name
  if ['base-lighting-ceiling-fans.xml'].include? hpxml_file
    hpxml.ceiling_fans[0].weekday_fractions = '0.057, 0.057, 0.057, 0.057, 0.057, 0.057, 0.057, 0.024, 0.024, 0.024, 0.024, 0.024, 0.024, 0.024, 0.024, 0.024, 0.024, 0.024, 0.057, 0.057, 0.057, 0.057, 0.057, 0.057'
    hpxml.ceiling_fans[0].weekend_fractions = '0.057, 0.057, 0.057, 0.057, 0.057, 0.057, 0.057, 0.024, 0.024, 0.024, 0.024, 0.024, 0.024, 0.024, 0.024, 0.024, 0.024, 0.024, 0.057, 0.057, 0.057, 0.057, 0.057, 0.057'
    hpxml.ceiling_fans[0].monthly_multipliers = '0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0'
  elsif ['base-lighting-holiday.xml'].include? hpxml_file
    hpxml.lighting.holiday_weekday_fractions = '0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.008, 0.098, 0.168, 0.194, 0.284, 0.192, 0.037, 0.019'
    hpxml.lighting.holiday_weekend_fractions = '0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.008, 0.098, 0.168, 0.194, 0.284, 0.192, 0.037, 0.019'
  elsif ['base-schedules-simple.xml',
         'base-schedules-simple-vacancy.xml',
         'base-schedules-simple-vacancy-year-round.xml',
         'base-schedules-simple-power-outage.xml',
         'base-misc-loads-large-uncommon.xml',
         'base-misc-loads-large-uncommon2.xml'].include? hpxml_file
    hpxml.lighting.interior_weekday_fractions = '0.124, 0.074, 0.050, 0.050, 0.053, 0.140, 0.330, 0.420, 0.430, 0.424, 0.411, 0.394, 0.382, 0.378, 0.378, 0.379, 0.386, 0.412, 0.484, 0.619, 0.783, 0.880, 0.597, 0.249'
    hpxml.lighting.interior_weekend_fractions = '0.124, 0.074, 0.050, 0.050, 0.053, 0.140, 0.330, 0.420, 0.430, 0.424, 0.411, 0.394, 0.382, 0.378, 0.378, 0.379, 0.386, 0.412, 0.484, 0.619, 0.783, 0.880, 0.597, 0.249'
    hpxml.lighting.interior_monthly_multipliers = '1.075, 1.064951905, 1.0375, 1.0, 0.9625, 0.935048095, 0.925, 0.935048095, 0.9625, 1.0, 1.0375, 1.064951905'
    hpxml.lighting.exterior_weekday_fractions = '0.046, 0.046, 0.046, 0.046, 0.046, 0.037, 0.035, 0.034, 0.033, 0.028, 0.022, 0.015, 0.012, 0.011, 0.011, 0.012, 0.019, 0.037, 0.049, 0.065, 0.091, 0.105, 0.091, 0.063'
    hpxml.lighting.exterior_weekend_fractions = '0.046, 0.046, 0.045, 0.045, 0.046, 0.045, 0.044, 0.041, 0.036, 0.03, 0.024, 0.016, 0.012, 0.011, 0.011, 0.012, 0.019, 0.038, 0.048, 0.06, 0.083, 0.098, 0.085, 0.059'
    hpxml.lighting.exterior_monthly_multipliers = '1.248, 1.257, 0.993, 0.989, 0.993, 0.827, 0.821, 0.821, 0.827, 0.99, 0.987, 1.248'
    hpxml.lighting.garage_weekday_fractions = '0.046, 0.046, 0.046, 0.046, 0.046, 0.037, 0.035, 0.034, 0.033, 0.028, 0.022, 0.015, 0.012, 0.011, 0.011, 0.012, 0.019, 0.037, 0.049, 0.065, 0.091, 0.105, 0.091, 0.063'
    hpxml.lighting.garage_weekend_fractions = '0.046, 0.046, 0.045, 0.045, 0.046, 0.045, 0.044, 0.041, 0.036, 0.03, 0.024, 0.016, 0.012, 0.011, 0.011, 0.012, 0.019, 0.038, 0.048, 0.06, 0.083, 0.098, 0.085, 0.059'
    hpxml.lighting.garage_monthly_multipliers = '1.248, 1.257, 0.993, 0.989, 0.993, 0.827, 0.821, 0.821, 0.827, 0.99, 0.987, 1.248'
  elsif ['base-lighting-kwh-per-year.xml'].include? hpxml_file
    ltg_kwhs_per_year = { HPXML::LocationInterior => 1500,
                          HPXML::LocationExterior => 150,
                          HPXML::LocationGarage => 0 }
    hpxml.lighting_groups.clear
    ltg_kwhs_per_year.each do |location, kwh_per_year|
      hpxml.lighting_groups.add(id: "LightingGroup#{hpxml.lighting_groups.size + 1}",
                                location: location,
                                kwh_per_year: kwh_per_year)
    end
  elsif ['base-lighting-mixed.xml'].include? hpxml_file
    hpxml.lighting_groups.reverse_each do |lg|
      next unless lg.location == HPXML::LocationExterior

      lg.delete
    end
    hpxml.lighting_groups.each_with_index do |lg, i|
      lg.id = "LightingGroup#{i + 1}"
    end
    hpxml.lighting_groups.add(id: "LightingGroup#{hpxml.lighting_groups.size + 1}",
                              location: HPXML::LocationExterior,
                              kwh_per_year: 150)
  elsif ['base-foundation-basement-garage.xml'].include? hpxml_file
    int_lighting_groups = hpxml.lighting_groups.select { |lg| lg.location == HPXML::LocationInterior }
    int_lighting_groups.each do |lg|
      hpxml.lighting_groups << lg.dup
      hpxml.lighting_groups[-1].location = HPXML::LocationGarage
      hpxml.lighting_groups[-1].id = "LightingGroup#{hpxml.lighting_groups.size}"
    end
  end

  # --------------- #
  # HPXML MiscLoads #
  # --------------- #

  # Logic that can only be applied based on the file name
  if ['base-schedules-simple.xml',
      'base-schedules-simple-vacancy.xml',
      'base-schedules-simple-vacancy-year-round.xml',
      'base-schedules-simple-power-outage.xml',
      'base-misc-loads-large-uncommon.xml',
      'base-misc-loads-large-uncommon2.xml'].include? hpxml_file
    hpxml.plug_loads[0].weekday_fractions = '0.045, 0.019, 0.01, 0.001, 0.001, 0.001, 0.005, 0.009, 0.018, 0.026, 0.032, 0.038, 0.04, 0.041, 0.043, 0.045, 0.05, 0.055, 0.07, 0.085, 0.097, 0.108, 0.089, 0.07'
    hpxml.plug_loads[0].weekend_fractions = '0.045, 0.019, 0.01, 0.001, 0.001, 0.001, 0.005, 0.009, 0.018, 0.026, 0.032, 0.038, 0.04, 0.041, 0.043, 0.045, 0.05, 0.055, 0.07, 0.085, 0.097, 0.108, 0.089, 0.07'
    hpxml.plug_loads[0].monthly_multipliers = '1.137, 1.129, 0.961, 0.969, 0.961, 0.993, 0.996, 0.96, 0.993, 0.867, 0.86, 1.137'
    hpxml.plug_loads[1].weekday_fractions = '0.035, 0.033, 0.032, 0.031, 0.032, 0.033, 0.037, 0.042, 0.043, 0.043, 0.043, 0.044, 0.045, 0.045, 0.044, 0.046, 0.048, 0.052, 0.053, 0.05, 0.047, 0.045, 0.04, 0.036'
    hpxml.plug_loads[1].weekend_fractions = '0.035, 0.033, 0.032, 0.031, 0.032, 0.033, 0.037, 0.042, 0.043, 0.043, 0.043, 0.044, 0.045, 0.045, 0.044, 0.046, 0.048, 0.052, 0.053, 0.05, 0.047, 0.045, 0.04, 0.036'
    hpxml.plug_loads[1].monthly_multipliers = '1.248, 1.257, 0.993, 0.989, 0.993, 0.827, 0.821, 0.821, 0.827, 0.99, 0.987, 1.248'
  end
  if ['base-misc-loads-large-uncommon.xml',
      'base-misc-loads-large-uncommon2.xml',
      'base-misc-usage-multiplier.xml'].include? hpxml_file
    if hpxml_file != 'base-misc-usage-multiplier.xml'
      hpxml.plug_loads[2].weekday_fractions = '0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042'
      hpxml.plug_loads[2].weekend_fractions = '0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042'
      hpxml.plug_loads[2].monthly_multipliers = '1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1'
      hpxml.plug_loads[3].weekday_fractions = '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065'
      hpxml.plug_loads[3].weekend_fractions = '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065'
      hpxml.plug_loads[3].monthly_multipliers = '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154'
    end
    hpxml.fuel_loads[0].weekday_fractions = '0.004, 0.001, 0.001, 0.002, 0.007, 0.012, 0.029, 0.046, 0.044, 0.041, 0.044, 0.046, 0.042, 0.038, 0.049, 0.059, 0.110, 0.161, 0.115, 0.070, 0.044, 0.019, 0.013, 0.007'
    hpxml.fuel_loads[0].weekend_fractions = '0.004, 0.001, 0.001, 0.002, 0.007, 0.012, 0.029, 0.046, 0.044, 0.041, 0.044, 0.046, 0.042, 0.038, 0.049, 0.059, 0.110, 0.161, 0.115, 0.070, 0.044, 0.019, 0.013, 0.007'
    hpxml.fuel_loads[0].monthly_multipliers = '1.097, 1.097, 0.991, 0.987, 0.991, 0.890, 0.896, 0.896, 0.890, 1.085, 1.085, 1.097'
    hpxml.fuel_loads[1].weekday_fractions = '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065'
    hpxml.fuel_loads[1].weekend_fractions = '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065'
    hpxml.fuel_loads[1].monthly_multipliers = '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154'
    hpxml.fuel_loads[2].weekday_fractions = '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065'
    hpxml.fuel_loads[2].weekend_fractions = '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065'
    hpxml.fuel_loads[2].monthly_multipliers = '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154'
  end
end

def download_utility_rates
  require_relative 'HPXMLtoOpenStudio/resources/util'
  require_relative 'ReportUtilityBills/resources/util'

  rates_dir = File.join(File.dirname(__FILE__), 'ReportUtilityBills/resources/detailed_rates')
  FileUtils.mkdir(rates_dir) if !File.exist?(rates_dir)
  filepath = File.join(rates_dir, 'usurdb.csv')

  if !File.exist?(filepath)
    require 'tempfile'
    tmpfile = Tempfile.new('rates')

    UrlResolver.fetch('https://openei.org/apps/USURDB/download/usurdb.csv.gz', tmpfile)

    puts 'Extracting utility rates...'
    require 'zlib'
    Zlib::GzipReader.open(tmpfile.path.to_s) do |input_stream|
      File.open(filepath, 'w') do |output_stream|
        IO.copy_stream(input_stream, output_stream)
      end
    end
  end

  num_rates_actual = process_usurdb(filepath)

  puts "#{num_rates_actual} rate files are available in openei_rates.zip."
  puts 'Completed.'
  exit!
end

command_list = [:update_measures, :update_hpxmls, :create_release_zips, :download_utility_rates]

def display_usage(command_list)
  puts "Usage: openstudio #{File.basename(__FILE__)} [COMMAND]\nCommands:\n  " + command_list.join("\n  ")
end

if ARGV.size == 0
  puts 'ERROR: Missing command.'
  display_usage(command_list)
  exit!
elsif ARGV.size > 1
  puts 'ERROR: Too many commands.'
  display_usage(command_list)
  exit!
elsif not command_list.include? ARGV[0].to_sym
  puts "ERROR: Invalid command '#{ARGV[0]}'."
  display_usage(command_list)
  exit!
end

if ARGV[0].to_sym == :update_measures
  # Prevent NREL error regarding U: drive when not VPNed in
  ENV['HOME'] = 'C:' if !ENV['HOME'].nil? && ENV['HOME'].start_with?('U:')
  ENV['HOMEDRIVE'] = 'C:\\' if !ENV['HOMEDRIVE'].nil? && ENV['HOMEDRIVE'].start_with?('U:')

  # Apply rubocop
  cops = ['Layout',
          'Lint/DeprecatedClassMethods',
          'Lint/DuplicateElsifCondition',
          'Lint/DuplicateHashKey',
          'Lint/DuplicateMethods',
          'Lint/InterpolationCheck',
          'Lint/LiteralAsCondition',
          'Lint/RedundantStringCoercion',
          'Lint/SelfAssignment',
          'Lint/UnderscorePrefixedVariableName',
          'Lint/UnusedBlockArgument',
          'Lint/UnusedMethodArgument',
          'Lint/UselessAssignment',
          'Style/AndOr',
          'Style/FrozenStringLiteralComment',
          'Style/HashSyntax',
          'Style/Next',
          'Style/NilComparison',
          'Style/RedundantParentheses',
          'Style/RedundantSelf',
          'Style/ReturnNil',
          'Style/SelfAssignment',
          'Style/StringLiterals',
          'Style/StringLiteralsInInterpolation']
  commands = ["\"require 'rubocop/rake_task' \"",
              "\"RuboCop::RakeTask.new(:rubocop) do |t| t.options = ['--auto-correct', '--format', 'simple', '--only', '#{cops.join(',')}'] end\"",
              '"Rake.application[:rubocop].invoke"']
  command = "#{OpenStudio.getOpenStudioCLI} -e #{commands.join(' -e ')}"
  puts 'Applying rubocop auto-correct to measures...'
  system(command)

  # Update measures XMLs
  puts 'Updating measure.xmls...'
  require 'oga'
  Dir['**/measure.xml'].each do |measure_xml|
    for n_attempt in 1..5 # For some reason CLI randomly generates errors, so try multiple times
      measure_dir = File.dirname(measure_xml)
      command = "#{OpenStudio.getOpenStudioCLI} measure -u '#{measure_dir}'"
      system(command, [:out, :err] => File::NULL)

      # Check for error
      xml_doc = XMLHelper.parse_file(measure_xml)
      err_val = XMLHelper.get_value(xml_doc, '/measure/error', :string)
      if err_val.nil?
        err_val = XMLHelper.get_value(xml_doc, '/error', :string)
      end
      if err_val.nil?
        break # Successfully updated
      else
        if n_attempt == 5
          fail "#{measure_xml}: #{err_val}" # Error generated all 5 times, fail
        else
          # Remove error from measure XML, try again
          orig_lines = File.readlines(measure_xml)
          new_lines = []
          inside_error = false
          orig_lines.each do |l|
            if l.include? '<error>'
              inside_error = true
            end
            if l.include? '</error>'
              inside_error = false
              next
            end
            next if inside_error

            new_lines << l
          end
          File.open(measure_xml, 'w') do |file|
            file.puts new_lines
          end
        end
      end
    end
  end

  puts 'Done.'
end

if ARGV[0].to_sym == :update_hpxmls
  # Prevent NREL error regarding U: drive when not VPNed in
  ENV['HOME'] = 'C:' if !ENV['HOME'].nil? && ENV['HOME'].start_with?('U:')
  ENV['HOMEDRIVE'] = 'C:\\' if !ENV['HOMEDRIVE'].nil? && ENV['HOMEDRIVE'].start_with?('U:')

  # Create sample/test HPXMLs
  OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Fatal)
  t = Time.now
  create_hpxmls()
  puts "Completed in #{(Time.now - t).round(1)}s"
end

if ARGV[0].to_sym == :download_utility_rates
  download_utility_rates
end

if ARGV[0].to_sym == :create_release_zips
  if ENV['CI']
    # CI doesn't have git, so default to everything
    git_files = Dir['**/*.*']
  else
    # Only include files under git version control
    command = 'git ls-files'
    begin
      git_files = `#{command}`
    rescue
      puts "Command failed: '#{command}'. Perhaps git needs to be installed?"
      exit!
    end
  end

  files = ['Changelog.md',
           'LICENSE.md',
           'BuildResidentialHPXML/measure.*',
           'BuildResidentialHPXML/resources/**/*.*',
           'BuildResidentialScheduleFile/measure.*',
           'BuildResidentialScheduleFile/resources/**/*.*',
           'HPXMLtoOpenStudio/measure.*',
           'HPXMLtoOpenStudio/resources/**/*.*',
           'ReportSimulationOutput/measure.*',
           'ReportSimulationOutput/resources/**/*.*',
           'ReportUtilityBills/measure.*',
           'ReportUtilityBills/resources/**/*.*',
           'weather/*.*',
           'workflow/*.*',
           'workflow/real_homes/*.xml',
           'workflow/sample_files/*.xml',
           'workflow/tests/*test*.rb',
           'workflow/tests/**/*.xml',
           'workflow/tests/**/*.csv',
           'documentation/index.html',
           'documentation/_static/**/*.*']

  if not ENV['CI']
    # Generate documentation
    puts 'Generating documentation...'
    command = 'sphinx-build -b singlehtml docs/source documentation'
    begin
      `#{command}`
      if not File.exist? File.join(File.dirname(__FILE__), 'documentation', 'index.html')
        puts 'Documentation was not successfully generated. Aborting...'
        exit!
      end
    rescue
      puts "Command failed: '#{command}'. Perhaps sphinx needs to be installed?"
      exit!
    end

    fonts_dir = File.join(File.dirname(__FILE__), 'documentation', '_static', 'fonts')
    if Dir.exist? fonts_dir
      FileUtils.rm_r(fonts_dir)
    end
  end

  # Create zip files
  require 'zip'
  zip_path = File.join(File.dirname(__FILE__), "OpenStudio-HPXML-v#{Version::OS_HPXML_Version}.zip")
  File.delete(zip_path) if File.exist? zip_path
  puts "Creating #{zip_path}..."
  Zip::File.open(zip_path, create: true) do |zipfile|
    files.each do |f|
      Dir[f].each do |file|
        if file.start_with? 'documentation'
          # always include
        else
          if not git_files.include? file
            next
          end
        end
        zipfile.add(File.join('OpenStudio-HPXML', file), file)
      end
    end
  end
  puts "Wrote file at #{zip_path}."

  # Cleanup
  if not ENV['CI']
    FileUtils.rm_r(File.join(File.dirname(__FILE__), 'documentation'))
  end

  puts 'Done.'
end
