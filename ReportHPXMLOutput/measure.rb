# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'msgpack'
require_relative 'resources/constants.rb'

# start the measure
class ReportHPXMLOutput < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'HPXML Output Report'
  end

  # human readable description
  def description
    return 'Reports HPXML outputs for residential HPXML-based models.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Parses the HPXML file and reports pre-defined outputs.'
  end

  # define the arguments that the user will input
  def arguments(model) # rubocop:disable Lint/UnusedMethodArgument
    args = OpenStudio::Measure::OSArgumentVector.new

    format_chs = OpenStudio::StringVector.new
    format_chs << 'csv'
    format_chs << 'json'
    format_chs << 'msgpack'
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('output_format', format_chs, false)
    arg.setDisplayName('Output Format')
    arg.setDescription('The file format of the annual (and timeseries, if requested) outputs.')
    arg.setDefaultValue('csv')
    args << arg

    return args
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find OpenStudio model.')
      return false
    end
    model = model.get

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    output_format = runner.getStringArgumentValue('output_format', user_arguments)
    output_dir = File.dirname(runner.lastEpwFilePath.get.to_s)

    if not File.exist? File.join(output_dir, 'eplusout.msgpack')
      runner.registerError('Cannot find eplusout.msgpack.')
      return false
    end
    @msgpackData = MessagePack.unpack(File.read(File.join(output_dir, 'eplusout.msgpack'), mode: 'rb'))

    hpxml_defaults_path = model.getBuilding.additionalProperties.getFeatureAsString('hpxml_defaults_path').get
    hpxml = HPXML.new(hpxml_path: hpxml_defaults_path)

    # Set paths
    output_path = File.join(output_dir, "results_hpxml.#{output_format}")

    # Initialize
    cost_multipliers = {}
    cost_multipliers[BS::EnclosureWallAreaThermalBoundary] = BaseOutput.new
    cost_multipliers[BS::EnclosureWallAreaExterior] = BaseOutput.new
    cost_multipliers[BS::EnclosureFoundationWallAreaExterior] = BaseOutput.new
    cost_multipliers[BS::EnclosureFloorAreaConditioned] = BaseOutput.new
    cost_multipliers[BS::EnclosureFloorAreaLighting] = BaseOutput.new
    cost_multipliers[BS::EnclosureFloorAreaFoundation] = BaseOutput.new
    cost_multipliers[BS::EnclosureCeilingAreaThermalBoundary] = BaseOutput.new
    cost_multipliers[BS::EnclosureRoofArea] = BaseOutput.new
    cost_multipliers[BS::EnclosureWindowArea] = BaseOutput.new
    cost_multipliers[BS::EnclosureDoorArea] = BaseOutput.new
    cost_multipliers[BS::EnclosureDuctAreaUnconditioned] = BaseOutput.new
    cost_multipliers[BS::EnclosureRimJoistAreaExterior] = BaseOutput.new
    cost_multipliers[BS::EnclosureSlabExposedPerimeterThermalBoundary] = BaseOutput.new
    cost_multipliers[BS::SystemsCoolingCapacity] = BaseOutput.new
    cost_multipliers[BS::SystemsHeatingCapacity] = BaseOutput.new
    cost_multipliers[BS::SystemsHeatPumpBackupCapacity] = BaseOutput.new
    cost_multipliers[BS::SystemsWaterHeaterVolume] = BaseOutput.new
    cost_multipliers[BS::SystemsMechanicalVentilationFlowRate] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsHeatingTotal] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsHeatingDucts] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsHeatingWindows] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsHeatingSkylights] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsHeatingDoors] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsHeatingWalls] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsHeatingRoofs] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsHeatingFloors] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsHeatingSlabs] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsHeatingCeilings] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsHeatingInfilVent] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingSensibleTotal] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingSensibleDucts] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingSensibleWindows] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingSensibleSkylights] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingSensibleDoors] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingSensibleWalls] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingSensibleRoofs] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingSensibleFloors] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingSensibleSlabs] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingSensibleCeilings] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingSensibleInfilVent] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingSensibleIntGains] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingLatentTotal] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingLatentDucts] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingLatentInfilVent] = BaseOutput.new
    cost_multipliers[BS::DesignLoadsCoolingLatentIntGains] = BaseOutput.new

    # Cost multipliers
    cost_multipliers.each do |cost_mult_type, cost_mult|
      cost_mult.output = get_cost_multiplier(hpxml, cost_mult_type)
    end

    # Primary and Secondary
    if hpxml.primary_hvac_systems.size > 0
      assign_primary_and_secondary(hpxml, cost_multipliers)
    end

    # Units
    cost_multipliers.each do |cost_mult_type, cost_mult|
      cost_mult.units = BS.get_units(cost_mult_type)
    end

    # Report results
    cost_multipliers.each do |cost_mult_type, cost_mult|
      cost_mult_type_str = OpenStudio::toUnderscoreCase("#{cost_mult_type} #{cost_mult.units}")
      cost_mult = cost_mult.output.round(2)
      runner.registerValue(cost_mult_type_str, cost_mult)
      runner.registerInfo("Registering #{cost_mult} for #{cost_mult_type_str}.")
    end

    # Write results
    write_output(runner, cost_multipliers, output_format, output_path)

    return true
  end

  def write_output(runner, cost_multipliers, output_format, output_path)
    line_break = nil

    segment, _ = cost_multipliers.keys[0].split(':', 2)
    segment = segment.strip
    results_out = []
    cost_multipliers.each do |key, cost_mult|
      new_segment, _ = key.split(':', 2)
      new_segment = new_segment.strip
      if new_segment != segment
        results_out << [line_break]
        segment = new_segment
      end
      results_out << ["#{key} (#{cost_mult.units})", cost_mult.output.round(2)]
    end

    if ['csv'].include? output_format
      CSV.open(output_path, 'wb') { |csv| results_out.to_a.each { |elem| csv << elem } }
    elsif ['json', 'msgpack'].include? output_format
      h = {}
      results_out.each do |out|
        next if out == [line_break]

        grp, name = out[0].split(':', 2)
        h[grp] = {} if h[grp].nil?
        h[grp][name.strip] = out[1]
      end

      if output_format == 'json'
        require 'json'
        File.open(output_path, 'w') { |json| json.write(JSON.pretty_generate(h)) }
      elsif output_format == 'msgpack'
        File.open(output_path, 'w') { |json| h.to_msgpack(json) }
      end
    end
    runner.registerInfo("Wrote hpxml output to #{output_path}.")
  end

  class BaseOutput
    def initialize()
      @output = 0.0
    end
    attr_accessor(:output, :units)
  end

  def get_cost_multiplier(hpxml, cost_mult_type)
    cost_mult = 0.0
    if cost_mult_type == BS::EnclosureWallAreaThermalBoundary
      hpxml.walls.each do |wall|
        next unless wall.is_thermal_boundary

        cost_mult += wall.area
      end
    elsif cost_mult_type == BS::EnclosureWallAreaExterior
      hpxml.walls.each do |wall|
        next unless wall.is_exterior

        cost_mult += wall.area
      end
    elsif cost_mult_type == BS::EnclosureFoundationWallAreaExterior
      hpxml.foundation_walls.each do |foundation_wall|
        next unless foundation_wall.is_exterior

        cost_mult += foundation_wall.area
      end
    elsif cost_mult_type == BS::EnclosureFloorAreaConditioned
      cost_mult += hpxml.building_construction.conditioned_floor_area
    elsif cost_mult_type == BS::EnclosureFloorAreaLighting
      if hpxml.lighting.interior_usage_multiplier.to_f != 0
        cost_mult += hpxml.building_construction.conditioned_floor_area
      end
      hpxml.slabs.each do |slab|
        next unless [HPXML::LocationGarage].include?(slab.interior_adjacent_to)
        next if hpxml.lighting.garage_usage_multiplier.to_f == 0

        cost_mult += slab.area
      end
    elsif cost_mult_type == BS::EnclosureFloorAreaFoundation
      hpxml.slabs.each do |slab|
        next if slab.interior_adjacent_to == HPXML::LocationGarage

        cost_mult += slab.area
      end
    elsif cost_mult_type == BS::EnclosureCeilingAreaThermalBoundary
      hpxml.frame_floors.each do |frame_floor|
        next unless frame_floor.is_thermal_boundary
        next unless frame_floor.is_interior
        next unless frame_floor.is_ceiling
        next unless [HPXML::LocationAtticVented,
                     HPXML::LocationAtticUnvented].include?(frame_floor.exterior_adjacent_to)

        cost_mult += frame_floor.area
      end
    elsif cost_mult_type == BS::EnclosureRoofArea
      hpxml.roofs.each do |roof|
        cost_mult += roof.area
      end
    elsif cost_mult_type == BS::EnclosureWindowArea
      hpxml.windows.each do |window|
        cost_mult += window.area
      end
    elsif cost_mult_type == BS::EnclosureDoorArea
      hpxml.doors.each do |door|
        cost_mult += door.area
      end
    elsif cost_mult_type == BS::EnclosureDuctAreaUnconditioned
      hpxml.hvac_distributions.each do |hvac_distribution|
        hvac_distribution.ducts.each do |duct|
          next if [HPXML::LocationLivingSpace,
                   HPXML::LocationBasementConditioned].include?(duct.duct_location)

          cost_mult += duct.duct_surface_area
        end
      end
    elsif cost_mult_type == BS::EnclosureRimJoistAreaExterior
      hpxml.rim_joists.each do |rim_joist|
        cost_mult += rim_joist.area
      end
    elsif cost_mult_type == BS::EnclosureSlabExposedPerimeterThermalBoundary
      hpxml.slabs.each do |slab|
        next unless slab.is_exterior_thermal_boundary

        cost_mult += slab.exposed_perimeter
      end
    elsif cost_mult_type == BS::SystemsHeatingCapacity
      hpxml.heating_systems.each do |heating_system|
        next if heating_system.is_heat_pump_backup_system

        cost_mult += heating_system.heating_capacity
      end

      hpxml.heat_pumps.each do |heat_pump|
        cost_mult += heat_pump.heating_capacity
      end
    elsif cost_mult_type == BS::SystemsCoolingCapacity
      hpxml.cooling_systems.each do |cooling_system|
        cost_mult += cooling_system.cooling_capacity
      end

      hpxml.heat_pumps.each do |heat_pump|
        cost_mult += heat_pump.cooling_capacity
      end
    elsif cost_mult_type == BS::SystemsHeatPumpBackupCapacity
      hpxml.heat_pumps.each do |heat_pump|
        if not heat_pump.backup_heating_capacity.nil?
          cost_mult += heat_pump.backup_heating_capacity
        elsif not heat_pump.backup_system.nil?
          cost_mult += heat_pump.backup_system.heating_capacity
        end
      end
    elsif cost_mult_type == BS::SystemsWaterHeaterVolume
      hpxml.water_heating_systems.each do |water_heating_system|
        cost_mult += water_heating_system.tank_volume.to_f
      end
    elsif cost_mult_type == BS::SystemsMechanicalVentilationFlowRate
      hpxml.ventilation_fans.each do |ventilation_fan|
        next unless ventilation_fan.used_for_whole_building_ventilation

        cost_mult += ventilation_fan.flow_rate.to_f
      end
    elsif cost_mult_type == BS::DesignLoadsHeatingTotal
      cost_mult += hpxml.hvac_plant.hdl_total
    elsif cost_mult_type == BS::DesignLoadsHeatingDucts
      cost_mult += hpxml.hvac_plant.hdl_ducts
    elsif cost_mult_type == BS::DesignLoadsHeatingWindows
      cost_mult += hpxml.hvac_plant.hdl_windows
    elsif cost_mult_type == BS::DesignLoadsHeatingSkylights
      cost_mult += hpxml.hvac_plant.hdl_skylights
    elsif cost_mult_type == BS::DesignLoadsHeatingDoors
      cost_mult += hpxml.hvac_plant.hdl_doors
    elsif cost_mult_type == BS::DesignLoadsHeatingWalls
      cost_mult += hpxml.hvac_plant.hdl_walls
    elsif cost_mult_type == BS::DesignLoadsHeatingRoofs
      cost_mult += hpxml.hvac_plant.hdl_roofs
    elsif cost_mult_type == BS::DesignLoadsHeatingFloors
      cost_mult += hpxml.hvac_plant.hdl_floors
    elsif cost_mult_type == BS::DesignLoadsHeatingSlabs
      cost_mult += hpxml.hvac_plant.hdl_slabs
    elsif cost_mult_type == BS::DesignLoadsHeatingCeilings
      cost_mult += hpxml.hvac_plant.hdl_ceilings
    elsif cost_mult_type == BS::DesignLoadsHeatingInfilVent
      cost_mult += hpxml.hvac_plant.hdl_infilvent
    elsif cost_mult_type == BS::DesignLoadsCoolingSensibleTotal
      cost_mult += hpxml.hvac_plant.cdl_sens_total
    elsif cost_mult_type == BS::DesignLoadsCoolingSensibleDucts
      cost_mult += hpxml.hvac_plant.cdl_sens_ducts
    elsif cost_mult_type == BS::DesignLoadsCoolingSensibleWindows
      cost_mult += hpxml.hvac_plant.cdl_sens_windows
    elsif cost_mult_type == BS::DesignLoadsCoolingSensibleSkylights
      cost_mult += hpxml.hvac_plant.cdl_sens_skylights
    elsif cost_mult_type == BS::DesignLoadsCoolingSensibleDoors
      cost_mult += hpxml.hvac_plant.cdl_sens_doors
    elsif cost_mult_type == BS::DesignLoadsCoolingSensibleWalls
      cost_mult += hpxml.hvac_plant.cdl_sens_walls
    elsif cost_mult_type == BS::DesignLoadsCoolingSensibleRoofs
      cost_mult += hpxml.hvac_plant.cdl_sens_roofs
    elsif cost_mult_type == BS::DesignLoadsCoolingSensibleFloors
      cost_mult += hpxml.hvac_plant.cdl_sens_floors
    elsif cost_mult_type == BS::DesignLoadsCoolingSensibleSlabs
      cost_mult += hpxml.hvac_plant.cdl_sens_slabs
    elsif cost_mult_type == BS::DesignLoadsCoolingSensibleCeilings
      cost_mult += hpxml.hvac_plant.cdl_sens_ceilings
    elsif cost_mult_type == BS::DesignLoadsCoolingSensibleInfilVent
      cost_mult += hpxml.hvac_plant.cdl_sens_infilvent
    elsif cost_mult_type == BS::DesignLoadsCoolingSensibleIntGains
      cost_mult += hpxml.hvac_plant.cdl_sens_intgains
    elsif cost_mult_type == BS::DesignLoadsCoolingLatentTotal
      cost_mult += hpxml.hvac_plant.cdl_lat_total
    elsif cost_mult_type == BS::DesignLoadsCoolingLatentDucts
      cost_mult += hpxml.hvac_plant.cdl_lat_ducts
    elsif cost_mult_type == BS::DesignLoadsCoolingLatentInfilVent
      cost_mult += hpxml.hvac_plant.cdl_lat_infilvent
    elsif cost_mult_type == BS::DesignLoadsCoolingLatentIntGains
      cost_mult += hpxml.hvac_plant.cdl_lat_intgains
    end
    return cost_mult
  end

  def assign_primary_and_secondary(hpxml, cost_multipliers)
    # Determine if we have primary/secondary systems
    has_primary_cooling_system = false
    has_secondary_cooling_system = false
    hpxml.cooling_systems.each do |cooling_system|
      has_primary_cooling_system = true if cooling_system.primary_system
      has_secondary_cooling_system = true if !cooling_system.primary_system
    end
    hpxml.heat_pumps.each do |heat_pump|
      has_primary_cooling_system = true if heat_pump.primary_cooling_system
      has_secondary_cooling_system = true if !heat_pump.primary_cooling_system
    end
    has_secondary_cooling_system = false unless has_primary_cooling_system

    has_primary_heating_system = false
    has_secondary_heating_system = false
    hpxml.heating_systems.each do |heating_system|
      next if heating_system.is_heat_pump_backup_system

      has_primary_heating_system = true if heating_system.primary_system
      has_secondary_heating_system = true if !heating_system.primary_system
    end
    hpxml.heat_pumps.each do |heat_pump|
      has_primary_heating_system = true if heat_pump.primary_heating_system
      has_secondary_heating_system = true if !heat_pump.primary_heating_system
    end
    has_secondary_heating_system = false unless has_primary_heating_system

    # Set up order of outputs
    if has_primary_cooling_system
      cost_multipliers["Primary #{BS::SystemsCoolingCapacity}"] = BaseOutput.new
    end

    if has_primary_heating_system
      cost_multipliers["Primary #{BS::SystemsHeatingCapacity}"] = BaseOutput.new
      cost_multipliers["Primary #{BS::SystemsHeatPumpBackupCapacity}"] = BaseOutput.new
    end

    if has_secondary_cooling_system
      cost_multipliers["Secondary #{BS::SystemsCoolingCapacity}"] = BaseOutput.new
    end

    if has_secondary_heating_system
      cost_multipliers["Secondary #{BS::SystemsHeatingCapacity}"] = BaseOutput.new
      cost_multipliers["Secondary #{BS::SystemsHeatPumpBackupCapacity}"] = BaseOutput.new
    end

    # Obtain values
    if has_primary_cooling_system || has_secondary_cooling_system
      hpxml.cooling_systems.each do |cooling_system|
        prefix = cooling_system.primary_system ? 'Primary' : 'Secondary'
        cost_multipliers["#{prefix} #{BS::SystemsCoolingCapacity}"].output += cooling_system.cooling_capacity
      end
      hpxml.heat_pumps.each do |heat_pump|
        prefix = heat_pump.primary_cooling_system ? 'Primary' : 'Secondary'
        cost_multipliers["#{prefix} #{BS::SystemsCoolingCapacity}"].output += heat_pump.cooling_capacity
      end
    end

    if has_primary_heating_system || has_secondary_heating_system
      hpxml.heating_systems.each do |heating_system|
        next if heating_system.is_heat_pump_backup_system

        prefix = heating_system.primary_system ? 'Primary' : 'Secondary'
        cost_multipliers["#{prefix} #{BS::SystemsHeatingCapacity}"].output += heating_system.heating_capacity
      end
      hpxml.heat_pumps.each do |heat_pump|
        prefix = heat_pump.primary_heating_system ? 'Primary' : 'Secondary'
        cost_multipliers["#{prefix} #{BS::SystemsHeatingCapacity}"].output += heat_pump.heating_capacity
        if not heat_pump.backup_heating_capacity.nil?
          cost_multipliers["#{prefix} #{BS::SystemsHeatPumpBackupCapacity}"].output += heat_pump.backup_heating_capacity
        elsif not heat_pump.backup_system.nil?
          cost_multipliers["#{prefix} #{BS::SystemsHeatPumpBackupCapacity}"].output += heat_pump.backup_system.heating_capacity
        end
      end
    end
  end
end

# register the measure to be used by the application
ReportHPXMLOutput.new.registerWithApplication
