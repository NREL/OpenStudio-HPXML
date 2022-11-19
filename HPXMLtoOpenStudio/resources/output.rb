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
  HeatingHeatPumpBackup = 'Heating Heat Pump Backup'
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
  Battery = 'Battery'
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

class OutputMethods
  def self.get_timestamps(msgpackData, hpxml, use_timestamp_start_convention, add_dst_column = false, add_utc_column = false,
                          use_dview_format = false, timeseries_frequency = nil)
    return if msgpackData.nil?

    if msgpackData.keys.include? 'MeterData'
      # Get data for ReportUtilityBills measure
      ep_timestamps = msgpackData['MeterData']['Monthly']['Rows'].map { |r| r.keys[0] }
    else
      # Get data for other reporting measures
      ep_timestamps = msgpackData['Rows'].map { |r| r.keys[0] }
    end

    if add_dst_column || use_dview_format
      dst_start_ts = Time.utc(hpxml.header.sim_calendar_year, hpxml.header.dst_begin_month, hpxml.header.dst_begin_day, 2)
      dst_end_ts = Time.utc(hpxml.header.sim_calendar_year, hpxml.header.dst_end_month, hpxml.header.dst_end_day, 1)
    end
    if add_utc_column
      utc_offset = hpxml.header.time_zone_utc_offset
      utc_offset *= 3600 # seconds
    end

    timestamps = []
    timestamps_dst = [] if add_dst_column || use_dview_format
    timestamps_utc = [] if add_utc_column
    year = hpxml.header.sim_calendar_year
    ep_timestamps.each do |ep_timestamp|
      month_day, hour_minute = ep_timestamp.split(' ')
      month, day = month_day.split('/').map(&:to_i)
      hour, minute, _ = hour_minute.split(':').map(&:to_i)

      # Convert from EnergyPlus default (end-of-timestep) to start-of-timestep convention
      if use_timestamp_start_convention
        if timeseries_frequency == 'timestep'
          ts_offset = hpxml.header.timestep * 60 # seconds
        elsif timeseries_frequency == 'hourly'
          ts_offset = 60 * 60 # seconds
        elsif timeseries_frequency == 'daily'
          ts_offset = 60 * 60 * 24 # seconds
        elsif timeseries_frequency == 'monthly'
          ts_offset = Constants.NumDaysInMonths(year)[month - 1] * 60 * 60 * 24 # seconds
        else
          fail 'Unexpected timeseries_frequency/'
        end
      end

      ts = Time.utc(year, month, day, hour, minute)
      ts -= ts_offset unless ts_offset.nil?

      timestamps << ts.iso8601.delete('Z')

      if add_dst_column || use_dview_format
        if (ts >= dst_start_ts) && (ts < dst_end_ts)
          ts_dst = ts + 3600 # 1 hr shift forward
        else
          ts_dst = ts
        end
        timestamps_dst << ts_dst.iso8601.delete('Z')
      end

      if add_utc_column
        ts_utc = ts - utc_offset
        timestamps_utc << ts_utc.iso8601
      end
    end

    return timestamps, timestamps_dst, timestamps_utc
  end

  def self.msgpack_frequency_map
    return {
      'timestep' => 'TimeStep',
      'hourly' => 'Hourly',
      'daily' => 'Daily',
      'monthly' => 'Monthly',
    }
  end

  def self.get_dst_start_end_indexes(timestamps, timestamps_dst)
    dst_start_ix = nil
    dst_end_ix = nil
    timestamps.zip(timestamps_dst).each_with_index do |ts, i|
      dst_start_ix = i if ts[0] != ts[1] && dst_start_ix.nil?
      dst_end_ix = i if ts[0] == ts[1] && dst_end_ix.nil? && !dst_start_ix.nil?
    end

    dst_end_ix = timestamps.size - 1 if dst_end_ix.nil? # run period ends before DST ends

    return dst_start_ix, dst_end_ix
  end
end
