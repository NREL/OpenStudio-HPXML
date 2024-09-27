# frozen_string_literal: true

# Collection of methods related to generic OpenStudio Model object operations.
module Model
  # Adds a WaterUseEquipment object to the OpenStudio model.
  #
  # The WaterUseEquipment object is a generalized object for simulating all (hot and cold)
  # water end uses.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param name [String] Name for the OpenStudio object
  # @param end_use [String] Name of the end use subcategory for output processing
  # @param peak_flow_rate [Double] Water peak flow rate (m^3/s)
  # @param flow_rate_schedule [OpenStudio::Model::Schedule] Schedule fraction that applies to the peak flow rate
  # @param water_use_connections [OpenStudio::Model::WaterUseConnections] Grouping of water use equipment objects
  # @param target_temperature_schedule [OpenStudio::Model::Schedule] The target water temperature schedule (F)
  # @return [OpenStudio::Model::WaterUseEquipment] The model object
  def self.add_water_use_equipment(model, name:, end_use:, peak_flow_rate:, flow_rate_schedule:, water_use_connections:, target_temperature_schedule:)
    wu_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
    wu = OpenStudio::Model::WaterUseEquipment.new(wu_def)
    wu.setName(name)
    wu_def.setName(name)
    wu_def.setPeakFlowRate(peak_flow_rate)
    wu_def.setEndUseSubcategory(end_use) unless end_use.nil?
    wu.setFlowRateFractionSchedule(flow_rate_schedule)
    wu_def.setTargetTemperatureSchedule(target_temperature_schedule) unless target_temperature_schedule.nil?
    water_use_connections.addWaterUseEquipment(wu)
    return wu
  end

  # Adds an ElectricEquipment object to the OpenStudio model.
  #
  # The ElectricEquipment object models equipment in a zone that consumes electricity (e.g.,
  # TVs, cooking, etc.). All the energy becomes a heat gain to the zone or is lost (exhausted).
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param name [String] Name for the OpenStudio object
  # @param end_use [String] Name of the end use subcategory for output processing
  # @param space [OpenStudio::Model::Space] The space the object is added to
  # @param design_level [Double] Maximum electrical power (W)
  # @param frac_radiant [Double] Fraction of energy consumption that is long-wave radiant heat to the zone
  # @param frac_latent [Double] Fraction of energy consumption that is latent heat to the zone
  # @param frac_lost [Double] Fraction of energy consumption that is not heat to the zone (for example, vented to the atmosphere)
  # @param schedule [OpenStudio::Model::Schedule] Schedule fraction (or multiplier) that applies to the design level
  # @return [OpenStudio::Model::ElectricEquipment] The model object
  def self.add_electric_equipment(model, name:, end_use:, space:, design_level:, frac_radiant:, frac_latent:, frac_lost:, schedule:)
    ee_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    ee = OpenStudio::Model::ElectricEquipment.new(ee_def)
    ee.setName(name)
    ee.setEndUseSubcategory(end_use) unless end_use.nil?
    ee.setSpace(space)
    ee_def.setName(name)
    ee_def.setDesignLevel(design_level) unless design_level.nil? # EMS-actuated if nil
    ee_def.setFractionRadiant(frac_radiant)
    ee_def.setFractionLatent(frac_latent)
    ee_def.setFractionLost(frac_lost)
    ee.setSchedule(schedule)
    return ee
  end

  # Adds an OtherEquipment object to the OpenStudio model.
  #
  # The OtherEquipment object models a heat gain/loss directly to the zone. Fuel consumption may
  # or may not be associated with the heat.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param name [String] Name for the OpenStudio object
  # @param end_use [String] Name of the end use subcategory for output processing
  # @param space [OpenStudio::Model::Space] The space the object is added to
  # @param design_level [Double] Maximum energy input (W)
  # @param frac_radiant [Double] Fraction of energy consumption that is long-wave radiant heat to the zone
  # @param frac_latent [Double] Fraction of energy consumption that is latent heat to the zone
  # @param frac_lost [Double] Fraction of energy consumption that is not heat to the zone (for example, vented to the atmosphere)
  # @param schedule [OpenStudio::Model::Schedule] Schedule fraction (or multiplier) that applies to the design level
  # @param fuel_type [String] Fuel type if the equipment consumes fuel (HPXML::FuelTypeXXX)
  # @return [OpenStudio::Model::OtherEquipment] The model object
  def self.add_other_equipment(model, name:, end_use:, space:, design_level:, frac_radiant:, frac_latent:, frac_lost:, schedule:, fuel_type:)
    oe_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
    oe = OpenStudio::Model::OtherEquipment.new(oe_def)
    oe.setName(name)
    oe.setEndUseSubcategory(end_use) unless end_use.nil?
    oe.setFuelType(EPlus.fuel_type(fuel_type)) unless fuel_type.nil?
    oe.setSpace(space)
    oe_def.setName(name)
    oe_def.setDesignLevel(design_level) unless design_level.nil? # EMS-actuated if nil
    oe_def.setFractionRadiant(frac_radiant)
    oe_def.setFractionLatent(frac_latent)
    oe_def.setFractionLost(frac_lost)
    oe.setSchedule(schedule)
    return oe
  end

  # Adds a Lights object to the OpenStudio model.
  #
  # The Lights object models electric lighting in a zone.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param name [String] Name for the OpenStudio object
  # @param end_use [String] Name of the end use subcategory for output processing
  # @param space [OpenStudio::Model::Space] The space the object is added to
  # @param design_level [Double] Maximum electrical power input (W)
  # @param schedule [OpenStudio::Model::Schedule] Schedule fraction (or multiplier) that applies to the design level
  # @return [OpenStudio::Model::Lights] The model object
  def self.add_lights(model, name:, end_use:, space:, design_level:, schedule:)
    ltg_def = OpenStudio::Model::LightsDefinition.new(model)
    ltg = OpenStudio::Model::Lights.new(ltg_def)
    ltg.setName(name)
    ltg.setSpace(space)
    ltg.setEndUseSubcategory(end_use)
    ltg_def.setName(name)
    ltg_def.setLightingLevel(design_level)
    ltg_def.setFractionRadiant(0.6)
    ltg_def.setFractionVisible(0.2)
    ltg_def.setReturnAirFraction(0.0)
    ltg.setSchedule(schedule)
    return ltg
  end

  # Adds an ExteriorLights object to the OpenStudio model.
  #
  # The ExteriorLights object models lighting outside the building.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param name [String] Name for the OpenStudio object
  # @param end_use [String] Name of the end use subcategory for output processing
  # @param design_level [Double] Maximum electrical power input (W)
  # @param schedule [OpenStudio::Model::Schedule] Schedule fraction (or multiplier) that applies to the design level
  # @return [OpenStudio::Model::ExteriorLights] The model object
  def self.add_exterior_lights(model, name:, end_use:, design_level:, schedule:)
    ltg_def = OpenStudio::Model::ExteriorLightsDefinition.new(model)
    ltg = OpenStudio::Model::ExteriorLights.new(ltg_def)
    ltg.setName(name)
    ltg.setEndUseSubcategory(end_use)
    ltg_def.setName(name)
    ltg_def.setDesignLevel(design_level)
    ltg.setSchedule(schedule)
    return ltg
  end

  # Adds an EnergyManagementSystemSensor to the OpenStudio model.
  #
  # The EnergyManagementSystemSensor object gets information during the simulation
  # that can be used in custom calculations.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param name [String] Name for the OpenStudio object
  # @param output_var_or_meter_name [String] EnergyPlus Output:Variable or Output:Meter name
  # @param key_name [OpenStudio::Model::XXX] Model object name or 'Environment' or nil
  # @return [OpenStudio::Model::EnergyManagementSystemSensor] The model object
  def self.add_ems_sensor(model, name:, output_var_or_meter_name:, key_name:)
    key_name = key_name.to_s

    # Check for identical sensor and return it if found
    model.getEnergyManagementSystemSensors.each do |sensor|
      next if sensor.outputVariableOrMeterName != output_var_or_meter_name
      next if sensor.keyName.to_s != key_name

      return sensor
    end

    sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, output_var_or_meter_name)
    sensor.setName(ems_friendly_name(name))
    sensor.setKeyName(key_name) unless key_name.nil?
    return sensor
  end

  # Adds an EnergyManagementSystemGlobalVariable to the OpenStudio model.
  #
  # The EnergyManagementSystemGlobalVariable object allows an EMS variable to be
  # global such that it can be used across EMS programs/subroutines.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param var_name [String] Name of the EMS variable
  # @return [OpenStudio::Model::EnergyManagementSystemGlobalVariable] The model object
  def self.add_ems_global_var(model, var_name:)
    return OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, ems_friendly_name(var_name))
  end

  # Adds an EnergyManagementSystemTrendVariable to the OpenStudio model.
  #
  # The EnergyManagementSystemTrendVariable object creates a global EMS variable
  # that stores the recent history of an EMS variable for use in a calculation.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param ems_object [OpenStudio::Model::EnergyManagementSystemXXX] The EMS object to track
  # @param num_timesteps_logged [Integer] How much data to be held in the trend variable
  # @return [OpenStudio::Model::EnergyManagementSystemTrendVariable] The model object
  def self.add_ems_trend_var(model, ems_object:, num_timesteps_logged:)
    tvar = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, ems_object)
    tvar.setName(ems_friendly_name("#{ems_object.name} trend var"))
    tvar.setNumberOfTimestepsToBeLogged(num_timesteps_logged)
    return tvar
  end

  # Adds an EnergyManagementSystemInternalVariable to the OpenStudio model.
  #
  # The EnergyManagementSystemInternalVariable object is used to obtain static data from
  # elsewhere in the model.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param name [String] Name for the OpenStudio object
  # @param model_object [OpenStudio::Model::XXX] The OpenStudio model object to get data from
  # @param type [String] Data type of interest
  # @return [OpenStudio::Model::EnergyManagementSystemInternalVariable] The model object
  def self.add_ems_internal_var(model, name:, model_object:, type:)
    ivar = OpenStudio::Model::EnergyManagementSystemInternalVariable.new(model, type)
    ivar.setName(ems_friendly_name(name))
    ivar.setInternalDataIndexKeyName(model_object.name.to_s)
    return ivar
  end

  # Adds an EnergyManagementSystemActuator to the OpenStudio model.
  #
  # The EnergyManagementSystemActuator object specifies the properties or controls
  # of an EnergyPlus object that is to be overridden during the simulation.
  #
  # @param name [String] Name for the OpenStudio object
  # @param model_object [OpenStudio::Model::XXX] The OpenStudio model object to actuate
  # @param comp_type_and_control [Array<String, String>] The type of component and its control type
  # @return [OpenStudio::Model::EnergyManagementSystemActuator] The model object
  def self.add_ems_actuator(name:, model_object:, comp_type_and_control:)
    if model_object.to_SpaceLoadInstance.is_initialized
      act = OpenStudio::Model::EnergyManagementSystemActuator.new(model_object, *comp_type_and_control, model_object.space.get)
    else
      act = OpenStudio::Model::EnergyManagementSystemActuator.new(model_object, *comp_type_and_control)
    end
    act.setName(ems_friendly_name(name))
    return act
  end

  # Adds an EnergyManagementSystemProgram to the OpenStudio model.
  #
  # The EnergyManagementSystemProgram object allows custom calculations to be
  # performed within the EnergyPlus simulation in order to override the properties
  # or controls of an EnergyPlus object.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param name [String] Name for the OpenStudio object
  # @param lines [Array<String>] The program lines to be executed
  # @return [OpenStudio::Model::EnergyManagementSystemProgram] The model object
  def self.add_ems_program(model, name:, lines: nil)
    prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    prg.setName(ems_friendly_name(name))
    prg.setLines(lines) unless lines.nil?
    return prg
  end

  # Adds an EnergyManagementSystemSubroutine to the OpenStudio model.
  #
  # The EnergyManagementSystemSubroutine object allows EMS code to be reused
  # across multiple EMS programs.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param name [String] Name for the OpenStudio object
  # @param lines [Array<String>] The subroutine lines to be executed
  # @return [OpenStudio::Model::EnergyManagementSystemSubroutine] The model object
  def self.add_ems_subroutine(model, name:, lines: nil)
    sbrt = OpenStudio::Model::EnergyManagementSystemSubroutine.new(model)
    sbrt.setName(ems_friendly_name(name))
    sbrt.setLines(lines) unless lines.nil?
    return sbrt
  end

  # Adds an EnergyManagementSystemProgramCallingManager to the OpenStudio model.
  #
  # The EnergyManagementSystemProgramCallingManager object is used to specify when
  # an EMS program is run during the simulation.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param name [String] Name for the OpenStudio object
  # @param calling_point [String] When the EMS program is called
  # @param ems_programs [Array<OpenStudio::Model::EnergyManagementSystemProgram>] The EMS programs to be managed
  # @return [OpenStudio::Model::EnergyManagementSystemProgramCallingManager] The model object
  def self.add_ems_program_calling_manager(model, name:, calling_point:, ems_programs:)
    pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    pcm.setName(ems_friendly_name(name))
    pcm.setCallingPoint(calling_point)
    ems_programs.each do |ems_program|
      pcm.addProgram(ems_program)
    end
    return pcm
  end

  # Converts existing string to EMS friendly string.
  #
  # Source: openstudio-standards
  #
  # @param name [String] Original name
  # @return [String] The resulting EMS friendly string
  def self.ems_friendly_name(name)
    # replace white space and special characters with underscore
    # \W is equivalent to [^a-zA-Z0-9_]
    return name.to_s.gsub(/\W/, '_')
  end

  # Resets the existing model if it already has objects in it.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param runner [OpenStudio::Measure::OSRunner] Object typically used to display warnings
  # @return [nil]
  def self.reset(model, runner)
    handles = OpenStudio::UUIDVector.new
    model.objects.each do |obj|
      handles << obj.handle
    end
    if !handles.empty?
      runner.registerWarning('The model contains existing objects and is being reset.')
      model.removeObjects(handles)
    end
  end

  # When there are multiple dwelling units, merge all unit models into a single model.
  # First deal with unique objects; look for differences in values across unit models.
  # Then make all unit models "unique" by shifting geometry and prefixing object names.
  # Then bulk add all modified objects to the main OpenStudio Model object.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio Model object
  # @param hpxml_osm_map [Hash] Map of HPXML::Building objects => OpenStudio Model objects for each dwelling unit
  # @return [nil]
  def self.merge_unit_models(model, hpxml_osm_map)
    # Map of OpenStudio IDD objects => OSM class names
    unique_object_map = { 'OS:ConvergenceLimits' => 'ConvergenceLimits',
                          'OS:Foundation:Kiva:Settings' => 'FoundationKivaSettings',
                          'OS:OutputControl:Files' => 'OutputControlFiles',
                          'OS:Output:Diagnostics' => 'OutputDiagnostics',
                          'OS:Output:JSON' => 'OutputJSON',
                          'OS:PerformancePrecisionTradeoffs' => 'PerformancePrecisionTradeoffs',
                          'OS:RunPeriod' => 'RunPeriod',
                          'OS:RunPeriodControl:DaylightSavingTime' => 'RunPeriodControlDaylightSavingTime',
                          'OS:ShadowCalculation' => 'ShadowCalculation',
                          'OS:SimulationControl' => 'SimulationControl',
                          'OS:Site' => 'Site',
                          'OS:Site:GroundTemperature:Deep' => 'SiteGroundTemperatureDeep',
                          'OS:Site:GroundTemperature:Shallow' => 'SiteGroundTemperatureShallow',
                          'OS:Site:WaterMainsTemperature' => 'SiteWaterMainsTemperature',
                          'OS:SurfaceConvectionAlgorithm:Inside' => 'InsideSurfaceConvectionAlgorithm',
                          'OS:SurfaceConvectionAlgorithm:Outside' => 'OutsideSurfaceConvectionAlgorithm',
                          'OS:Timestep' => 'Timestep' }

    # Handle unique objects first: Grab one from the first model we find the
    # object on (may not be the first unit).
    unit_model_objects = []
    unique_handles_to_skip = []
    uuid_regex = /\{(.*?)\}/
    unique_object_map.each do |idd_obj, osm_class|
      first_model_object_by_type = nil
      hpxml_osm_map.values.each do |unit_model|
        next if unit_model.getObjectsByType(idd_obj.to_IddObjectType).empty?

        model_object = unit_model.send("get#{osm_class}")

        if first_model_object_by_type.nil?
          # Retain object for model
          unit_model_objects << model_object
          first_model_object_by_type = model_object
          if idd_obj == 'OS:Site:WaterMainsTemperature' # Handle referenced child object too
            unit_model_objects << unit_model.getObjectsByName(model_object.temperatureSchedule.get.name.to_s)[0]
          end
        else
          # Throw error if different values between this model_object and first_model_object_by_type
          if model_object.to_s.gsub(uuid_regex, '') != first_model_object_by_type.to_s.gsub(uuid_regex, '')
            fail "Unique object (#{idd_obj}) has different values across dwelling units."
          end

          if idd_obj == 'OS:Site:WaterMainsTemperature' # Handle referenced child object too
            if model_object.temperatureSchedule.get.to_s.gsub(uuid_regex, '') != first_model_object_by_type.temperatureSchedule.get.to_s.gsub(uuid_regex, '')
              fail "Unique object (#{idd_obj}) has different values across dwelling units."
            end
          end
        end

        unique_handles_to_skip << model_object.handle.to_s
        if idd_obj == 'OS:Site:WaterMainsTemperature' # Handle referenced child object too
          unique_handles_to_skip << model_object.temperatureSchedule.get.handle.to_s
        end
      end
    end

    hpxml_osm_map.values.each_with_index do |unit_model, unit_number|
      Geometry.shift_surfaces(unit_model, unit_number)
      prefix_object_names(unit_model, unit_number)

      # Handle remaining (non-unique) objects now
      unit_model.objects.each do |obj|
        next if unit_number > 0 && obj.to_Building.is_initialized
        next if unique_handles_to_skip.include? obj.handle.to_s

        unit_model_objects << obj
      end
    end

    model.addObjects(unit_model_objects, true)
  end

  # Prefix all object names using using a provided unit number.
  #
  # @param unit_model [OpenStudio::Model::Model] OpenStudio Model object (corresponding to one of multiple dwelling units)
  # @param unit_number [Integer] index number corresponding to an HPXML Building object
  # @return [nil]
  def self.prefix_object_names(unit_model, unit_number)
    # FUTURE: Create objects with unique names up front so we don't have to do this

    # Create a new OpenStudio object name by prefixing the old with "unit" plus the unit number.
    #
    # @param obj_name [String] the OpenStudio object name
    # @param unit_number [Integer] index number corresponding to an HPXML Building object
    # @return [String] the new OpenStudio object name with unique unit prefix
    def self.make_variable_name(obj_name, unit_number)
      return ems_friendly_name("unit#{unit_number + 1}_#{obj_name}")
    end

    # EMS objects
    ems_map = {}

    unit_model.getEnergyManagementSystemSensors.each do |sensor|
      ems_map[sensor.name.to_s] = make_variable_name(sensor.name, unit_number)
      sensor.setKeyName(make_variable_name(sensor.keyName, unit_number)) unless sensor.keyName.empty? || sensor.keyName.downcase == 'environment'
    end

    unit_model.getEnergyManagementSystemActuators.each do |actuator|
      ems_map[actuator.name.to_s] = make_variable_name(actuator.name, unit_number)
    end

    unit_model.getEnergyManagementSystemInternalVariables.each do |internal_variable|
      ems_map[internal_variable.name.to_s] = make_variable_name(internal_variable.name, unit_number)
      internal_variable.setInternalDataIndexKeyName(make_variable_name(internal_variable.internalDataIndexKeyName, unit_number)) unless internal_variable.internalDataIndexKeyName.empty?
    end

    unit_model.getEnergyManagementSystemGlobalVariables.each do |global_variable|
      ems_map[global_variable.name.to_s] = make_variable_name(global_variable.name, unit_number)
    end

    unit_model.getEnergyManagementSystemOutputVariables.each do |output_variable|
      next if output_variable.emsVariableObject.is_initialized

      new_ems_variable_name = make_variable_name(output_variable.emsVariableName, unit_number)
      ems_map[output_variable.emsVariableName.to_s] = new_ems_variable_name
      output_variable.setEMSVariableName(new_ems_variable_name)
    end

    unit_model.getEnergyManagementSystemSubroutines.each do |subroutine|
      ems_map[subroutine.name.to_s] = make_variable_name(subroutine.name, unit_number)
    end

    # variables in program lines don't get updated automatically
    lhs_characters = [' ', ',', '(', ')', '+', '-', '*', '/', ';']
    rhs_characters = [''] + lhs_characters
    (unit_model.getEnergyManagementSystemPrograms + unit_model.getEnergyManagementSystemSubroutines).each do |program|
      new_lines = []
      program.lines.each do |line|
        ems_map.each do |old_name, new_name|
          next unless line.include?(old_name)

          # old_name between at least 1 character, with the exception of '' on left and ' ' on right
          lhs_characters.each do |lhs|
            next unless line.include?("#{lhs}#{old_name}")

            rhs_characters.each do |rhs|
              next unless line.include?("#{lhs}#{old_name}#{rhs}")
              next if lhs == '' && ['', ' '].include?(rhs)

              line.gsub!("#{lhs}#{old_name}#{rhs}", "#{lhs}#{new_name}#{rhs}")
            end
          end
        end
        new_lines << line
      end
      program.setLines(new_lines)
    end

    # All model objects
    unit_model.objects.each do |model_object|
      next if model_object.name.nil?

      if unit_number == 0
        # OpenStudio is unhappy if these schedules are renamed
        next if model_object.name.to_s == unit_model.alwaysOnContinuousSchedule.name.to_s
        next if model_object.name.to_s == unit_model.alwaysOnDiscreteSchedule.name.to_s
        next if model_object.name.to_s == unit_model.alwaysOffDiscreteSchedule.name.to_s
      end

      model_object.setName(make_variable_name(model_object.name, unit_number))
    end
  end
end
