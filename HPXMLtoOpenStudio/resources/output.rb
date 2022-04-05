# frozen_string_literal: true

class TE
  # Total Energy
  Total = 'Total'
  Net = 'Net'
end

class FT
  # Fuel Types
  Elec = 'Electricity'
  Gas = 'Natural Gas'
  Oil = 'Fuel Oil'
  Propane = 'Propane'
  WoodCord = 'Wood Cord'
  WoodPellets = 'Wood Pellets'
  Coal = 'Coal'
end

class EUT
  # End Use Types
  Heating = 'Heating'
  HeatingFanPump = 'Heating Fans/Pumps'
  Cooling = 'Cooling'
  CoolingFanPump = 'Cooling Fans/Pumps'
  HotWater = 'Hot Water'
  HotWaterRecircPump = 'Hot Water Recirc Pump'
  HotWaterSolarThermalPump = 'Hot Water Solar Thermal Pump'
  LightsInterior = 'Lighting Interior'
  LightsGarage = 'Lighting Garage'
  LightsExterior = 'Lighting Exterior'
  MechVent = 'Mech Vent'
  MechVentPreheat = 'Mech Vent Preheating'
  MechVentPrecool = 'Mech Vent Precooling'
  WholeHouseFan = 'Whole House Fan'
  Refrigerator = 'Refrigerator'
  Freezer = 'Freezer'
  Dehumidifier = 'Dehumidifier'
  Dishwasher = 'Dishwasher'
  ClothesWasher = 'Clothes Washer'
  ClothesDryer = 'Clothes Dryer'
  RangeOven = 'Range/Oven'
  CeilingFan = 'Ceiling Fan'
  Television = 'Television'
  PlugLoads = 'Plug Loads'
  Vehicle = 'Electric Vehicle Charging'
  WellPump = 'Well Pump'
  PoolHeater = 'Pool Heater'
  PoolPump = 'Pool Pump'
  HotTubHeater = 'Hot Tub Heater'
  HotTubPump = 'Hot Tub Pump'
  Grill = 'Grill'
  Lighting = 'Lighting'
  Fireplace = 'Fireplace'
  PV = 'PV'
  Generator = 'Generator'
end

class HWT
  # Hot Water Types
  ClothesWasher = 'Clothes Washer'
  Dishwasher = 'Dishwasher'
  Fixtures = 'Fixtures'
  DistributionWaste = 'Distribution Waste'
end

class LT
  # Load Types
  Heating = 'Heating: Delivered'
  Cooling = 'Cooling: Delivered'
  HotWaterDelivered = 'Hot Water: Delivered'
  HotWaterTankLosses = 'Hot Water: Tank Losses'
  HotWaterDesuperheater = 'Hot Water: Desuperheater'
  HotWaterSolarThermal = 'Hot Water: Solar Thermal'
end

class CLT
  # Component Load Types
  Roofs = 'Roofs'
  Ceilings = 'Ceilings'
  Walls = 'Walls'
  RimJoists = 'Rim Joists'
  FoundationWalls = 'Foundation Walls'
  Doors = 'Doors'
  Windows = 'Windows'
  Skylights = 'Skylights'
  Floors = 'Floors'
  Slabs = 'Slabs'
  InternalMass = 'Internal Mass'
  Infiltration = 'Infiltration'
  NaturalVentilation = 'Natural Ventilation'
  MechanicalVentilation = 'Mechanical Ventilation'
  WholeHouseFan = 'Whole House Fan'
  Ducts = 'Ducts'
  InternalGains = 'Internal Gains'
end

class UHT
  # Unmet Hours Types
  Heating = 'Heating'
  Cooling = 'Cooling'
end

class ILT
  # Ideal Load Types
  Heating = 'Heating'
  Cooling = 'Cooling'
end

class PLT
  # Peak Load Types
  Heating = 'Heating: Delivered'
  Cooling = 'Cooling: Delivered'
end

class PFT
  # Peak Fuel Types
  Summer = 'Summer'
  Winter = 'Winter'
end

class AFT
  # Airflow Types
  Infiltration = 'Infiltration'
  MechanicalVentilation = 'Mechanical Ventilation'
  NaturalVentilation = 'Natural Ventilation'
  WholeHouseFan = 'Whole House Fan'
end

class WT
  # Weather Types
  DrybulbTemp = 'Drybulb Temperature'
  WetbulbTemp = 'Wetbulb Temperature'
  RelativeHumidity = 'Relative Humidity'
  WindSpeed = 'Wind Speed'
  DiffuseSolar = 'Diffuse Solar Radiation'
  DirectSolar = 'Direct Solar Radiation'
end

def get_timestamps(timeseries_frequency, sqlFile, hpxml, timestamps_local_time = nil)
  if timeseries_frequency == 'hourly'
    interval_type = 1
  elsif timeseries_frequency == 'daily'
    interval_type = 2
  elsif timeseries_frequency == 'monthly'
    interval_type = 3
  elsif timeseries_frequency == 'timestep'
    interval_type = -1
  end

  query = "SELECT Year || ' ' || Month || ' ' || Day || ' ' || Hour || ' ' || Minute As Timestamp FROM Time WHERE IntervalType='#{interval_type}'"
  values = sqlFile.execAndReturnVectorOfString(query)
  fail "Query error: #{query}" unless values.is_initialized

  if timestamps_local_time == 'DST'
    dst_start_ts = Time.utc(hpxml.header.sim_calendar_year, hpxml.header.dst_begin_month, hpxml.header.dst_begin_day, 2)
    dst_end_ts = Time.utc(hpxml.header.sim_calendar_year, hpxml.header.dst_end_month, hpxml.header.dst_end_day, 1)
  elsif timestamps_local_time == 'UTC'
    utc_offset = hpxml.header.time_zone_utc_offset
    utc_offset *= 3600 # seconds
  end

  timestamps = []
  values.get.each do |value|
    year, month, day, hour, minute = value.split(' ')
    ts = Time.utc(year, month, day, hour, minute)

    if timestamps_local_time == 'DST'
      if (ts >= dst_start_ts) && (ts < dst_end_ts)
        ts += 3600 # 1 hr shift forward
      end
    elsif timestamps_local_time == 'UTC'
      ts -= utc_offset
    end

    ts_iso8601 = ts.iso8601
    ts_iso8601 = ts_iso8601.delete('Z') if timestamps_local_time != 'UTC'
    timestamps << ts_iso8601
  end

  return timestamps
end

def teardown(sqlFile)
  sqlFile.close()

  # Ensure sql file is immediately freed; otherwise we can get
  # errors on Windows when trying to delete this file.
  GC.start()
end

def create_all_object_variables_by_key
  @object_variables_by_key = {}
  return if @model.nil?

  @model.getModelObjects.each do |object|
    next if object.to_AdditionalProperties.is_initialized

    [EUT, HWT, LT, ILT].each do |class_name|
      vars_by_key = get_object_output_variables_by_key(@model, object, class_name)
      next if vars_by_key.size == 0

      sys_id = object.additionalProperties.getFeatureAsString('HPXML_ID')
      if sys_id.is_initialized
        sys_id = sys_id.get
      else
        sys_id = nil
      end

      vars_by_key.each do |key, output_vars|
        output_vars.each do |output_var|
          if object.to_EnergyManagementSystemOutputVariable.is_initialized
            varkey = 'EMS'
          else
            varkey = object.name.to_s.upcase
          end
          hash_key = [class_name, key]
          @object_variables_by_key[hash_key] = [] if @object_variables_by_key[hash_key].nil?
          next if @object_variables_by_key[hash_key].include? [sys_id, varkey, output_var]

          @object_variables_by_key[hash_key] << [sys_id, varkey, output_var]
        end
      end
    end
  end
end

def get_object_variables(class_name, key)
  hash_key = [class_name, key]
  vars = @object_variables_by_key[hash_key]
  vars = [] if vars.nil?
  return vars
end

def get_object_output_variables_by_key(model, object, class_name)
  to_ft = { EPlus::FuelTypeElectricity => FT::Elec,
            EPlus::FuelTypeNaturalGas => FT::Gas,
            EPlus::FuelTypeOil => FT::Oil,
            EPlus::FuelTypePropane => FT::Propane,
            EPlus::FuelTypeWoodCord => FT::WoodCord,
            EPlus::FuelTypeWoodPellets => FT::WoodPellets,
            EPlus::FuelTypeCoal => FT::Coal }

  # For a given object, returns the output variables to be requested and associates
  # them with the appropriate keys (e.g., [FT::Elec, EUT::Heating]).

  if class_name == EUT

    # End uses

    if object.to_CoilHeatingDXSingleSpeed.is_initialized || object.to_CoilHeatingDXMultiSpeed.is_initialized
      return { [FT::Elec, EUT::Heating] => ["Heating Coil #{EPlus::FuelTypeElectricity} Energy", "Heating Coil Crankcase Heater #{EPlus::FuelTypeElectricity} Energy", "Heating Coil Defrost #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_CoilHeatingElectric.is_initialized
      return { [FT::Elec, EUT::Heating] => ["Heating Coil #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_CoilHeatingGas.is_initialized
      fuel = object.to_CoilHeatingGas.get.fuelType
      return { [to_ft[fuel], EUT::Heating] => ["Heating Coil #{fuel} Energy"] }

    elsif object.to_CoilHeatingWaterToAirHeatPumpEquationFit.is_initialized
      return { [FT::Elec, EUT::Heating] => ["Heating Coil #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_ZoneHVACBaseboardConvectiveElectric.is_initialized
      return { [FT::Elec, EUT::Heating] => ["Baseboard #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_BoilerHotWater.is_initialized
      is_combi_boiler = false
      if object.additionalProperties.getFeatureAsBoolean('IsCombiBoiler').is_initialized
        is_combi_boiler = object.additionalProperties.getFeatureAsBoolean('IsCombiBoiler').get
      end
      if not is_combi_boiler # Exclude combi boiler, whose heating & dhw energy is handled separately via EMS
        fuel = object.to_BoilerHotWater.get.fuelType
        return { [to_ft[fuel], EUT::Heating] => ["Boiler #{fuel} Energy"] }
      end

    elsif object.to_CoilCoolingDXSingleSpeed.is_initialized || object.to_CoilCoolingDXMultiSpeed.is_initialized
      vars = { [FT::Elec, EUT::Cooling] => ["Cooling Coil #{EPlus::FuelTypeElectricity} Energy"] }
      parent = model.getAirLoopHVACUnitarySystems.select { |u| u.coolingCoil.is_initialized && u.coolingCoil.get.handle.to_s == object.handle.to_s }
      if (not parent.empty?) && parent[0].heatingCoil.is_initialized
        htg_coil = parent[0].heatingCoil.get
      end
      if parent.empty?
        parent = model.getZoneHVACPackagedTerminalAirConditioners.select { |u| u.coolingCoil.handle.to_s == object.handle.to_s }
        if not parent.empty?
          htg_coil = parent[0].heatingCoil
        end
      end
      if parent.empty?
        fail 'Could not find parent object.'
      end

      if htg_coil.nil? || (not (htg_coil.to_CoilHeatingDXSingleSpeed.is_initialized || htg_coil.to_CoilHeatingDXMultiSpeed.is_initialized))
        # Crankcase variable only available if no DX heating coil on parent
        vars[[FT::Elec, EUT::Cooling]] << "Cooling Coil Crankcase Heater #{EPlus::FuelTypeElectricity} Energy"
      end
      return vars

    elsif object.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
      return { [FT::Elec, EUT::Cooling] => ["Cooling Coil #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_EvaporativeCoolerDirectResearchSpecial.is_initialized
      return { [FT::Elec, EUT::Cooling] => ["Evaporative Cooler #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_CoilWaterHeatingAirToWaterHeatPumpWrapped.is_initialized
      return { [FT::Elec, EUT::HotWater] => ["Cooling Coil Water Heating #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_FanSystemModel.is_initialized
      if object.name.to_s.start_with? Constants.ObjectNameWaterHeater
        return { [FT::Elec, EUT::HotWater] => ["Fan #{EPlus::FuelTypeElectricity} Energy"] }
      end

    elsif object.to_PumpConstantSpeed.is_initialized
      if object.name.to_s.start_with? Constants.ObjectNameSolarHotWater
        return { [FT::Elec, EUT::HotWaterSolarThermalPump] => ["Pump #{EPlus::FuelTypeElectricity} Energy"] }
      end

    elsif object.to_WaterHeaterMixed.is_initialized
      fuel = object.to_WaterHeaterMixed.get.heaterFuelType
      return { [to_ft[fuel], EUT::HotWater] => ["Water Heater #{fuel} Energy", "Water Heater Off Cycle Parasitic #{EPlus::FuelTypeElectricity} Energy", "Water Heater On Cycle Parasitic #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_WaterHeaterStratified.is_initialized
      fuel = object.to_WaterHeaterStratified.get.heaterFuelType
      return { [to_ft[fuel], EUT::HotWater] => ["Water Heater #{fuel} Energy", "Water Heater Off Cycle Parasitic #{EPlus::FuelTypeElectricity} Energy", "Water Heater On Cycle Parasitic #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_ExteriorLights.is_initialized
      return { [FT::Elec, EUT::LightsExterior] => ["Exterior Lights #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_Lights.is_initialized
      end_use = { Constants.ObjectNameInteriorLighting => EUT::LightsInterior,
                  Constants.ObjectNameGarageLighting => EUT::LightsGarage }[object.to_Lights.get.endUseSubcategory]
      return { [FT::Elec, end_use] => ["Lights #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_ElectricLoadCenterInverterPVWatts.is_initialized
      return { [FT::Elec, EUT::PV] => ["Inverter AC Output #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_GeneratorMicroTurbine.is_initialized
      fuel = object.to_GeneratorMicroTurbine.get.fuelType
      return { [FT::Elec, EUT::Generator] => ["Generator Produced AC #{EPlus::FuelTypeElectricity} Energy"],
               [to_ft[fuel], EUT::Generator] => ["Generator #{fuel} HHV Basis Energy"] }

    elsif object.to_ElectricEquipment.is_initialized
      end_use = { Constants.ObjectNameHotWaterRecircPump => EUT::HotWaterRecircPump,
                  Constants.ObjectNameClothesWasher => EUT::ClothesWasher,
                  Constants.ObjectNameClothesDryer => EUT::ClothesDryer,
                  Constants.ObjectNameDishwasher => EUT::Dishwasher,
                  Constants.ObjectNameRefrigerator => EUT::Refrigerator,
                  Constants.ObjectNameFreezer => EUT::Freezer,
                  Constants.ObjectNameCookingRange => EUT::RangeOven,
                  Constants.ObjectNameCeilingFan => EUT::CeilingFan,
                  Constants.ObjectNameWholeHouseFan => EUT::WholeHouseFan,
                  Constants.ObjectNameMechanicalVentilation => EUT::MechVent,
                  Constants.ObjectNameMiscPlugLoads => EUT::PlugLoads,
                  Constants.ObjectNameMiscTelevision => EUT::Television,
                  Constants.ObjectNameMiscPoolHeater => EUT::PoolHeater,
                  Constants.ObjectNameMiscPoolPump => EUT::PoolPump,
                  Constants.ObjectNameMiscHotTubHeater => EUT::HotTubHeater,
                  Constants.ObjectNameMiscHotTubPump => EUT::HotTubPump,
                  Constants.ObjectNameMiscElectricVehicleCharging => EUT::Vehicle,
                  Constants.ObjectNameMiscWellPump => EUT::WellPump }[object.to_ElectricEquipment.get.endUseSubcategory]
      if not end_use.nil?
        return { [FT::Elec, end_use] => ["Electric Equipment #{EPlus::FuelTypeElectricity} Energy"] }
      end

    elsif object.to_OtherEquipment.is_initialized
      fuel = object.to_OtherEquipment.get.fuelType
      end_use = { Constants.ObjectNameClothesDryer => EUT::ClothesDryer,
                  Constants.ObjectNameCookingRange => EUT::RangeOven,
                  Constants.ObjectNameMiscGrill => EUT::Grill,
                  Constants.ObjectNameMiscLighting => EUT::Lighting,
                  Constants.ObjectNameMiscFireplace => EUT::Fireplace,
                  Constants.ObjectNameMiscPoolHeater => EUT::PoolHeater,
                  Constants.ObjectNameMiscHotTubHeater => EUT::HotTubHeater,
                  Constants.ObjectNameMechanicalVentilationPreheating => EUT::MechVentPreheat,
                  Constants.ObjectNameMechanicalVentilationPrecooling => EUT::MechVentPrecool }[object.to_OtherEquipment.get.endUseSubcategory]
      if not end_use.nil?
        return { [to_ft[fuel], end_use] => ["Other Equipment #{fuel} Energy"] }
      end

    elsif object.to_ZoneHVACDehumidifierDX.is_initialized
      return { [FT::Elec, EUT::Dehumidifier] => ["Zone Dehumidifier #{EPlus::FuelTypeElectricity} Energy"] }

    elsif object.to_EnergyManagementSystemOutputVariable.is_initialized
      if object.name.to_s.end_with? Constants.ObjectNameFanPumpDisaggregatePrimaryHeat
        return { [FT::Elec, EUT::HeatingFanPump] => [object.name.to_s] }
      elsif object.name.to_s.end_with? Constants.ObjectNameFanPumpDisaggregateBackupHeat
        return { [FT::Elec, EUT::HeatingFanPump] => [object.name.to_s] }
      elsif object.name.to_s.end_with? Constants.ObjectNameFanPumpDisaggregateCool
        return { [FT::Elec, EUT::CoolingFanPump] => [object.name.to_s] }
      elsif object.name.to_s.include? Constants.ObjectNameWaterHeaterAdjustment(nil)
        fuel = object.additionalProperties.getFeatureAsString('FuelType').get
        return { [to_ft[fuel], EUT::HotWater] => [object.name.to_s] }
      elsif object.name.to_s.include? Constants.ObjectNameCombiWaterHeatingEnergy(nil)
        fuel = object.additionalProperties.getFeatureAsString('FuelType').get
        return { [to_ft[fuel], EUT::HotWater] => [object.name.to_s] }
      elsif object.name.to_s.include? Constants.ObjectNameCombiSpaceHeatingEnergy(nil)
        fuel = object.additionalProperties.getFeatureAsString('FuelType').get
        return { [to_ft[fuel], EUT::Heating] => [object.name.to_s] }
      else
        return { ems: [object.name.to_s] }
      end

    end

  elsif class_name == HWT

    # Hot Water Use

    if object.to_WaterUseEquipment.is_initialized
      hot_water_use = { Constants.ObjectNameFixtures => HWT::Fixtures,
                        Constants.ObjectNameDistributionWaste => HWT::DistributionWaste,
                        Constants.ObjectNameClothesWasher => HWT::ClothesWasher,
                        Constants.ObjectNameDishwasher => HWT::Dishwasher }[object.to_WaterUseEquipment.get.waterUseEquipmentDefinition.endUseSubcategory]
      return { hot_water_use => ['Water Use Equipment Hot Water Volume'] }

    end

  elsif class_name == LT

    # Load

    if object.to_WaterHeaterMixed.is_initialized || object.to_WaterHeaterStratified.is_initialized
      if object.to_WaterHeaterMixed.is_initialized
        capacity = object.to_WaterHeaterMixed.get.heaterMaximumCapacity.get
      else
        capacity = object.to_WaterHeaterStratified.get.heater1Capacity.get
      end
      is_combi_boiler = false
      if object.additionalProperties.getFeatureAsBoolean('IsCombiBoiler').is_initialized
        is_combi_boiler = object.additionalProperties.getFeatureAsBoolean('IsCombiBoiler').get
      end
      if capacity == 0 && object.name.to_s.include?(Constants.ObjectNameSolarHotWater)
        return { LT::HotWaterSolarThermal => ['Water Heater Use Side Heat Transfer Energy'] }
      elsif capacity > 0 || is_combi_boiler # Active water heater only (e.g., exclude desuperheater and solar thermal storage tanks)
        return { LT::HotWaterTankLosses => ['Water Heater Heat Loss Energy'] }
      end

    elsif object.to_WaterUseConnections.is_initialized
      return { LT::HotWaterDelivered => ['Water Use Connections Plant Hot Water Energy'] }

    elsif object.to_CoilWaterHeatingDesuperheater.is_initialized
      return { LT::HotWaterDesuperheater => ['Water Heater Heating Energy'] }

    elsif object.to_CoilHeatingDXSingleSpeed.is_initialized || object.to_CoilHeatingDXMultiSpeed.is_initialized || object.to_CoilHeatingGas.is_initialized
      # Needed to apportion heating loads for dual-fuel heat pumps
      return { LT::Heating => ['Heating Coil Heating Energy'] }

    end

  elsif class_name == ILT

    # Ideal Load

    if object.to_ZoneHVACIdealLoadsAirSystem.is_initialized
      if object.name.to_s == Constants.ObjectNameIdealAirSystem
        return { ILT::Heating => ['Zone Ideal Loads Zone Sensible Heating Energy'],
                 ILT::Cooling => ['Zone Ideal Loads Zone Sensible Cooling Energy'] }
      end

    end

  end

  return {}
end

def get_end_uses()
  end_uses = {}
  end_uses[[FT::Elec, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Heating]))
  end_uses[[FT::Elec, EUT::HeatingFanPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HeatingFanPump]))
  end_uses[[FT::Elec, EUT::Cooling]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Cooling]))
  end_uses[[FT::Elec, EUT::CoolingFanPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::CoolingFanPump]))
  end_uses[[FT::Elec, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HotWater]))
  end_uses[[FT::Elec, EUT::HotWaterRecircPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HotWaterRecircPump]))
  end_uses[[FT::Elec, EUT::HotWaterSolarThermalPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HotWaterSolarThermalPump]))
  end_uses[[FT::Elec, EUT::LightsInterior]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::LightsInterior]))
  end_uses[[FT::Elec, EUT::LightsGarage]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::LightsGarage]))
  end_uses[[FT::Elec, EUT::LightsExterior]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::LightsExterior]))
  end_uses[[FT::Elec, EUT::MechVent]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::MechVent]))
  end_uses[[FT::Elec, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::MechVentPreheat]))
  end_uses[[FT::Elec, EUT::MechVentPrecool]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::MechVentPrecool]))
  end_uses[[FT::Elec, EUT::WholeHouseFan]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::WholeHouseFan]))
  end_uses[[FT::Elec, EUT::Refrigerator]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Refrigerator]))
  end_uses[[FT::Elec, EUT::Freezer]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Freezer]))
  end_uses[[FT::Elec, EUT::Dehumidifier]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Dehumidifier]))
  end_uses[[FT::Elec, EUT::Dishwasher]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Dishwasher]))
  end_uses[[FT::Elec, EUT::ClothesWasher]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::ClothesWasher]))
  end_uses[[FT::Elec, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::ClothesDryer]))
  end_uses[[FT::Elec, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::RangeOven]))
  end_uses[[FT::Elec, EUT::CeilingFan]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::CeilingFan]))
  end_uses[[FT::Elec, EUT::Television]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Television]))
  end_uses[[FT::Elec, EUT::PlugLoads]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::PlugLoads]))
  end_uses[[FT::Elec, EUT::Vehicle]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Vehicle]))
  end_uses[[FT::Elec, EUT::WellPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::WellPump]))
  end_uses[[FT::Elec, EUT::PoolHeater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::PoolHeater]))
  end_uses[[FT::Elec, EUT::PoolPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::PoolPump]))
  end_uses[[FT::Elec, EUT::HotTubHeater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HotTubHeater]))
  end_uses[[FT::Elec, EUT::HotTubPump]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::HotTubPump]))
  end_uses[[FT::Elec, EUT::PV]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::PV]),
                                             is_negative: true)
  end_uses[[FT::Elec, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::Elec, EUT::Generator]),
                                                    is_negative: true)
  end_uses[[FT::Gas, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::Heating]))
  end_uses[[FT::Gas, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::HotWater]))
  end_uses[[FT::Gas, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::ClothesDryer]))
  end_uses[[FT::Gas, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::RangeOven]))
  end_uses[[FT::Gas, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::MechVentPreheat]))
  end_uses[[FT::Gas, EUT::PoolHeater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::PoolHeater]))
  end_uses[[FT::Gas, EUT::HotTubHeater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::HotTubHeater]))
  end_uses[[FT::Gas, EUT::Grill]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::Grill]))
  end_uses[[FT::Gas, EUT::Lighting]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::Lighting]))
  end_uses[[FT::Gas, EUT::Fireplace]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::Fireplace]))
  end_uses[[FT::Gas, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::Gas, EUT::Generator]))
  end_uses[[FT::Oil, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::Heating]))
  end_uses[[FT::Oil, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::HotWater]))
  end_uses[[FT::Oil, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::ClothesDryer]))
  end_uses[[FT::Oil, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::RangeOven]))
  end_uses[[FT::Oil, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::MechVentPreheat]))
  end_uses[[FT::Oil, EUT::Grill]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::Grill]))
  end_uses[[FT::Oil, EUT::Lighting]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::Lighting]))
  end_uses[[FT::Oil, EUT::Fireplace]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::Fireplace]))
  end_uses[[FT::Oil, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::Oil, EUT::Generator]))
  end_uses[[FT::Propane, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::Heating]))
  end_uses[[FT::Propane, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::HotWater]))
  end_uses[[FT::Propane, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::ClothesDryer]))
  end_uses[[FT::Propane, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::RangeOven]))
  end_uses[[FT::Propane, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::MechVentPreheat]))
  end_uses[[FT::Propane, EUT::Grill]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::Grill]))
  end_uses[[FT::Propane, EUT::Lighting]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::Lighting]))
  end_uses[[FT::Propane, EUT::Fireplace]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::Fireplace]))
  end_uses[[FT::Propane, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::Propane, EUT::Generator]))
  end_uses[[FT::WoodCord, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::Heating]))
  end_uses[[FT::WoodCord, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::HotWater]))
  end_uses[[FT::WoodCord, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::ClothesDryer]))
  end_uses[[FT::WoodCord, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::RangeOven]))
  end_uses[[FT::WoodCord, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::MechVentPreheat]))
  end_uses[[FT::WoodCord, EUT::Grill]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::Grill]))
  end_uses[[FT::WoodCord, EUT::Lighting]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::Lighting]))
  end_uses[[FT::WoodCord, EUT::Fireplace]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::Fireplace]))
  end_uses[[FT::WoodCord, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodCord, EUT::Generator]))
  end_uses[[FT::WoodPellets, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::Heating]))
  end_uses[[FT::WoodPellets, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::HotWater]))
  end_uses[[FT::WoodPellets, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::ClothesDryer]))
  end_uses[[FT::WoodPellets, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::RangeOven]))
  end_uses[[FT::WoodPellets, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::MechVentPreheat]))
  end_uses[[FT::WoodPellets, EUT::Grill]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::Grill]))
  end_uses[[FT::WoodPellets, EUT::Lighting]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::Lighting]))
  end_uses[[FT::WoodPellets, EUT::Fireplace]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::Fireplace]))
  end_uses[[FT::WoodPellets, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::WoodPellets, EUT::Generator]))
  end_uses[[FT::Coal, EUT::Heating]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::Heating]))
  end_uses[[FT::Coal, EUT::HotWater]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::HotWater]))
  end_uses[[FT::Coal, EUT::ClothesDryer]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::ClothesDryer]))
  end_uses[[FT::Coal, EUT::RangeOven]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::RangeOven]))
  end_uses[[FT::Coal, EUT::MechVentPreheat]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::MechVentPreheat]))
  end_uses[[FT::Coal, EUT::Grill]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::Grill]))
  end_uses[[FT::Coal, EUT::Lighting]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::Lighting]))
  end_uses[[FT::Coal, EUT::Fireplace]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::Fireplace]))
  end_uses[[FT::Coal, EUT::Generator]] = EndUse.new(variables: get_object_variables(EUT, [FT::Coal, EUT::Generator]))
  return end_uses
end

class BaseOutput
  def initialize()
    @timeseries_output = []
  end
  attr_accessor(:name, :annual_output, :timeseries_output, :annual_units, :timeseries_units)
end

class EndUse < BaseOutput
  def initialize(variables: [], is_negative: false)
    super()
    @variables = variables
    @is_negative = is_negative
    @timeseries_output_by_system = {}
    @annual_output_by_system = {}
    # These outputs used to apply Cambium hourly electricity factors
    @hourly_output = []
    @hourly_output_by_system = {}
  end
  attr_accessor(:variables, :is_negative, :annual_output_by_system, :timeseries_output_by_system,
                :hourly_output, :hourly_output_by_system)
end
