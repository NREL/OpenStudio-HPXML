class Constants
  # Numbers --------------------

  def self.AssumedInsideTemp
    return 73.5 # deg-F
  end

  def self.g
    return 32.174 # gravity (ft/s2)
  end

  def self.MonthNumDays
    return [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  end

  def self.Patm
    return 14.696 # standard atmospheric pressure (psia)
  end

  def self.small
    return 1e-9
  end

  # Strings --------------------

  def self.AirFilm
    return 'AirFilm'
  end

  def self.Auto
    return 'auto'
  end

  def self.ColorWhite
    return 'white'
  end

  def self.ColorLight
    return 'light'
  end

  def self.ColorMedium
    return 'medium'
  end

  def self.ColorDark
    return 'dark'
  end

  def self.BoilerTypeCondensing
    return 'hot water, condensing'
  end

  def self.BoilerTypeNaturalDraft
    return 'hot water, natural draft'
  end

  def self.BoilerTypeForcedDraft
    return 'hot water, forced draft'
  end

  def self.BoilerTypeSteam
    return 'steam'
  end

  def self.BoreConfigSingle
    return 'single'
  end

  def self.BoreConfigLine
    return 'line'
  end

  def self.BoreConfigOpenRectangle
    return 'open-rectangle'
  end

  def self.BoreConfigRectangle
    return 'rectangle'
  end

  def self.BoreConfigLconfig
    return 'l-config'
  end

  def self.BoreConfigL2config
    return 'l2-config'
  end

  def self.BoreConfigUconfig
    return 'u-config'
  end

  def self.BuildingAmericaClimateZone
    return 'Building America'
  end

  def self.CalcTypeERIRatedHome
    return 'ERI Rated Home'
  end

  def self.CalcTypeERIReferenceHome
    return 'ERI Reference Home'
  end

  def self.CalcTypeERIIndexAdjustmentDesign
    return 'ERI Index Adjustment Design'
  end

  def self.CalcTypeERIIndexAdjustmentReferenceHome
    return 'ERI Index Adjustment Reference Home'
  end

  def self.DuctSideReturn
    return 'return'
  end

  def self.DuctSideSupply
    return 'supply'
  end

  def self.FluidWater
    return 'water'
  end

  def self.FluidPropyleneGlycol
    return 'propylene-glycol'
  end

  def self.FluidEthyleneGlycol
    return 'ethylene-glycol'
  end

  def self.FuelTypeElectric
    return 'electric'
  end

  def self.FuelTypeGas
    return 'gas'
  end

  def self.FuelTypePropane
    return 'propane'
  end

  def self.FuelTypeOil
    return 'oil'
  end

  def self.FuelTypeWood
    return 'wood'
  end

  def self.FuelTypeWoodPellets
    return 'pellets'
  end

  def self.MaterialGypcrete
    return 'crete'
  end

  def self.MaterialGypsum
    return 'gyp'
  end

  def self.MaterialOSB
    return 'osb'
  end

  def self.MonthNames
    return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  end

  def self.PVArrayTypeFixedOpenRack
    return 'FixedOpenRack'
  end

  def self.PVArrayTypeFixedRoofMount
    return 'FixedRoofMounted'
  end

  def self.PVArrayTypeFixed1Axis
    return 'OneAxis'
  end

  def self.PVArrayTypeFixed1AxisBacktracked
    return 'OneAxisBacktracking'
  end

  def self.PVArrayTypeFixed2Axis
    return 'TwoAxis'
  end

  def self.PVModuleTypeStandard
    return 'Standard'
  end

  def self.PVModuleTypePremium
    return 'Premium'
  end

  def self.PVModuleTypeThinFilm
    return 'ThinFilm'
  end

  def self.ObjectNameAirflow
    return "airflow"
  end

  def self.ObjectNameAirSourceHeatPump
    return "ashp"
  end

  def self.ObjectNameBackupHeatingCoil
    return "backup htg coil"
  end

  def self.ObjectNameBath
    return "res baths"
  end

  def self.ObjectNameBoiler
    return "boiler"
  end

  def self.ObjectNameCeilingFan
    return "ceiling fan"
  end

  def self.ObjectNameCentralAirConditioner
    return "central ac"
  end

  def self.ObjectNameCentralAirConditionerAndFurnace
    return "central ac and furnace"
  end

  def self.ObjectNameClothesWasher
    return "clothes washer"
  end

  def self.ObjectNameClothesDryer
    return "clothes dryer"
  end

  def self.ObjectNameCookingRange
    return "cooking range"
  end

  def self.ObjectNameCoolingSeason
    return 'cooling season'
  end

  def self.ObjectNameCoolingSetpoint
    return 'cooling setpoint'
  end

  def self.ObjectNameDehumidifier
    return "dehumidifier"
  end

  def self.ObjectNameDishwasher
    return "dishwasher"
  end

  def self.ObjectNameElectricBaseboard
    return "baseboard"
  end

  def self.ObjectNameEvaporativeCooler
    return "evap cooler"
  end

  def self.ObjectNameFanPumpDisaggregateCool(fan_or_pump_name = "")
    return "#{fan_or_pump_name} clg disaggregate"
  end

  def self.ObjectNameFanPumpDisaggregatePrimaryHeat(fan_or_pump_name = "")
    return "#{fan_or_pump_name} htg primary disaggregate"
  end

  def self.ObjectNameFanPumpDisaggregateBackupHeat(fan_or_pump_name = "")
    return "#{fan_or_pump_name} htg backup disaggregate"
  end

  def self.ObjectNameFixtures
    return "dhw fixtures"
  end

  def self.ObjectNameFurnace
    return "furnace"
  end

  def self.ObjectNameFurniture
    return "furniture"
  end

  def self.ObjectNameGroundSourceHeatPump
    return "gshp"
  end

  def self.ObjectNameHeatingSeason
    return 'heating season'
  end

  def self.ObjectNameHeatingSetpoint
    return 'heating setpoint'
  end

  def self.ObjectNameHotWaterRecircPump
    return "dhw recirc pump"
  end

  def self.ObjectNameIdealAirSystem
    return "ideal"
  end

  def self.ObjectNameInfiltration
    return "infil"
  end

  def self.ObjectNameERVHRV
    return "erv or hrv"
  end

  def self.ObjectNameExteriorLighting
    return "exterior lighting"
  end

  def self.ObjectNameGarageLighting
    return "garage lighting"
  end

  def self.ObjectNameInteriorLighting
    return "interior lighting"
  end

  def self.ObjectNameMechanicalVentilation
    return "mech vent"
  end

  def self.ObjectNameMiniSplitHeatPump
    return "mshp"
  end

  def self.ObjectNameMiscPlugLoads
    return "misc plug loads"
  end

  def self.ObjectNameMiscTelevision
    return "misc tv"
  end

  def self.ObjectNameNaturalVentilation
    return "natural vent"
  end

  def self.ObjectNameNeighbors
    return "neighbors"
  end

  def self.ObjectNameOccupants
    return "occupants"
  end

  def self.ObjectNameOverhangs
    return "overhangs"
  end

  def self.ObjectNameRefrigerator
    return "fridge"
  end

  def self.ObjectNameRelativeHumiditySetpoint
    return "rh setpoint"
  end

  def self.ObjectNameRoomAirConditioner
    return "room ac"
  end

  def self.ObjectNameShower
    return "res showers"
  end

  def self.ObjectNameSink
    return "res sinks"
  end

  def self.ObjectNameSolarHotWater
    return "solar hot water"
  end

  def self.ObjectNameUnitHeater
    return "unit heater"
  end

  def self.ObjectNameWaterHeater
    return "water heater"
  end

  def self.ObjectNameWaterHeaterAdjustment(water_heater_name)
    return "#{water_heater_name} EC adjustment"
  end

  def self.ObjectNameDesuperheater(water_heater_name)
    return "#{water_heater_name} Desuperheater"
  end

  def self.ObjectNameDesuperheaterEnergy(water_heater_name)
    return "#{water_heater_name} Desuperheater energy"
  end

  def self.ObjectNameDesuperheaterLoad(water_heater_name)
    return "#{water_heater_name} Desuperheater load"
  end

  def self.ObjectNameTankHX
    return "dhw source hx"
  end

  def self.PlantLoopDomesticWater
    return "dhw loop"
  end

  def self.PlantLoopSolarHotWater
    return "solar hot water loop"
  end

  def self.RecircTypeTimer
    return 'timer'
  end

  def self.RecircTypeDemand
    return 'demand'
  end

  def self.RecircTypeNone
    return 'none'
  end

  def self.RoofMaterialAsphaltShingles
    return 'asphalt shingles'
  end

  def self.RoofMaterialMembrane
    return 'membrane'
  end

  def self.RoofMaterialMetal
    return 'metal'
  end

  def self.RoofMaterialTarGravel
    return 'tar gravel'
  end

  def self.RoofMaterialTile
    return 'tile'
  end

  def self.RoofMaterialWoodShakes
    return 'wood shakes'
  end

  def self.ScheduleTypeLimitsFraction
    return 'Fractional'
  end

  def self.ScheduleTypeLimitsOnOff
    return 'OnOff'
  end

  def self.ScheduleTypeLimitsTemperature
    return 'Temperature'
  end

  def self.SeasonHeating
    return 'Heating'
  end

  def self.SeasonCooling
    return 'Cooling'
  end

  def self.SeasonOverlap
    return 'Overlap'
  end

  def self.SeasonNone
    return 'None'
  end

  def self.SizingAuto
    return 'autosize'
  end

  def self.SolarThermalCollectorTypeEvacuatedTube
    return 'evacuated tube'
  end

  def self.SolarThermalCollectorTypeGlazedFlatPlateSingle
    return 'single glazing black'
  end

  def self.SolarThermalCollectorTypeGlazedFlatPlateDouble
    return 'double glazing black'
  end

  def self.SolarThermalCollectorTypeICS
    return 'integrated collector storage'
  end

  def self.SolarThermalLoopTypeDirect
    return 'liquid direct'
  end

  def self.SolarThermalLoopTypeIndirect
    return 'liquid indirect'
  end

  def self.SolarThermalLoopTypeThermosyphon
    return 'passive thermosyphon'
  end

  def self.SpaceTypeVentedCrawl
    return 'vented crawlspace'
  end

  def self.SpaceTypeUnventedCrawl
    return 'unvented crawlspace'
  end

  def self.SpaceTypeGarage
    return 'garage'
  end

  def self.SpaceTypeLiving
    return 'living'
  end

  def self.SpaceTypeVentedAttic
    return 'vented attic'
  end

  def self.SpaceTypeUnventedAttic
    return 'unvented attic'
  end

  def self.SpaceTypeUnconditionedBasement
    return 'unconditioned basement'
  end

  def self.TerrainOcean
    return 'ocean'
  end

  def self.TerrainPlains
    return 'plains'
  end

  def self.TerrainRural
    return 'rural'
  end

  def self.TerrainSuburban
    return 'suburban'
  end

  def self.TerrainCity
    return 'city'
  end

  def self.VentTypeExhaust
    return 'exhaust'
  end

  def self.VentTypeNone
    return 'none'
  end

  def self.VentTypeSupply
    return 'supply'
  end

  def self.VentTypeBalanced
    return 'balanced'
  end

  def self.VentTypeCFIS
    return 'central fan integrated supply'
  end

  def self.WaterHeaterTypeTankless
    return 'tankless'
  end

  def self.WaterHeaterTypeTank
    return 'tank'
  end

  def self.WaterHeaterTypeHeatPump
    return 'heatpump'
  end
end
