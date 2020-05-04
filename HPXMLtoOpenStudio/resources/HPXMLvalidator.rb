require 'json'
require 'tree'
require 'rexml/xpath'
require 'rexml/document'

class HPXMLValidator
  def self.run_validator()
    # A hash of hashes that defines the XML elements used by the EnergyPlus HPXML Use Case.
    #
    # Example:
    #
    # use_case = {
    #     nil => {
    #         'floor_area' => one,            # 1 element required always
    #         'garage_area' => zero_or_one,   # 0 or 1 elements required always
    #         'walls' => one_or_more,         # 1 or more elements required always
    #     },
    #     '/walls' => {
    #         'rvalue' => one,                # 1 element required if /walls element exists (conditional)
    #         'windows' => zero_or_one,       # 0 or 1 elements required if /walls element exists (conditional)
    #         'layers' => one_or_more,        # 1 or more elements required if /walls element exists (conditional)
    #     }
    # }
    #

    zero = [0]
    zero_or_one = [0, 1]
    zero_or_two = [0, 2]
    zero_or_three = [0, 3]
    zero_or_four = [0, 4]
    zero_or_five = [0, 5]
    zero_or_six = [0, 6]
    zero_or_seven = [0, 7]
    zero_or_more = nil
    one = [1]
    one_or_more = []

    requirements = {

      # Root
      nil => {
        '/HPXML/XMLTransactionHeaderInformation/XMLType' => one, # Required by HPXML schema
        '/HPXML/XMLTransactionHeaderInformation/XMLGeneratedBy' => one, # Required by HPXML schema
        '/HPXML/XMLTransactionHeaderInformation/CreatedDateAndTime' => one, # Required by HPXML schema
        '/HPXML/XMLTransactionHeaderInformation/Transaction' => one, # Required by HPXML schema
        '/HPXML/SoftwareInfo/extension/SimulationControl' => zero_or_one, # See [SimulationControl]

        '/HPXML/Building' => one,
        '/HPXML/Building/BuildingID' => one, # Required by HPXML schema
        '/HPXML/Building/ProjectStatus/EventType' => one, # Required by HPXML schema

        '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/ShelterCoefficient' => zero_or_one, # Uses ERI assumption if not provided
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingOccupancy/NumberofResidents' => zero_or_one, # Uses ERI assumption if not provided
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction' => one, # See [BuildingConstruction]
        '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors' => zero_or_one, # See [Neighbors]

        '/HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC' => zero_or_one, # See [ClimateZone]
        '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation' => one, # See [WeatherStation]

        '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/extension/ConstantACHnatural' => one,

        '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof' => zero_or_more, # See [Roof]
        '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall' => one_or_more, # See [Wall]
        '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist' => zero_or_more, # See [RimJoist]
        '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall' => zero_or_more, # See [FoundationWall]
        '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor' => zero_or_more, # See [FrameFloor]
        '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab' => zero_or_more, # See [Slab]
        '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window' => zero_or_more, # See [Window]
        '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight' => zero_or_more, # See [Skylight]
        '/HPXML/Building/BuildingDetails/Enclosure/Doors/Door' => zero_or_more, # See [Door]

        '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem' => zero_or_more, # See [HeatingSystem]
        '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem' => zero_or_more, # See [CoolingSystem]
        '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump' => zero_or_more, # See [HeatPump]
        '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl' => zero_or_one, # See [HVACControl]
        '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution' => zero_or_more, # See [HVACDistribution]

        '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true"]' => zero_or_one, # See [MechanicalVentilation]
        '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForSeasonalCoolingLoadReduction="true"]' => zero_or_one, # See [WholeHouseFan]
        '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem' => zero_or_more, # See [WaterHeatingSystem]
        '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution' => zero_or_one, # See [HotWaterDistribution]
        '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterFixture' => zero_or_more, # See [WaterFixture]
        '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem' => zero_or_one, # See [SolarThermalSystem]
        '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem' => zero_or_more, # See [PVSystem]

        '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher' => zero_or_one, # See [ClothesWasher]
        '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer' => zero_or_one, # See [ClothesDryer]
        '/HPXML/Building/BuildingDetails/Appliances/Dishwasher' => zero_or_one, # See [Dishwasher]
        '/HPXML/Building/BuildingDetails/Appliances/Refrigerator' => zero_or_one, # See [Refrigerator]
        '/HPXML/Building/BuildingDetails/Appliances/CookingRange' => zero_or_one, # See [CookingRange]

        '/HPXML/Building/BuildingDetails/Lighting' => zero_or_one, # See [Lighting]
        '/HPXML/Building/BuildingDetails/Lighting/CeilingFan' => zero_or_one, # See [CeilingFan]

        '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad[PlugLoadType="other"]' => zero_or_one, # See [PlugLoads]
        '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad[PlugLoadType="TV other"]' => zero_or_one, # See [Television]
      },

      # [SimulationControl]
      '/HPXML/SoftwareInfo/extension/SimulationControl' => {
        'Timestep' => zero_or_one, # minutes; must be a divisor of 60
        'BeginMonth | BeginDayOfMonth' => zero_or_two, # integer
        'EndMonth | EndDayOfMonth' => zero_or_two, # integer
      },

      # [BuildingConstruction]
      '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction' => {
        'NumberofConditionedFloors' => one,
        'NumberofConditionedFloorsAboveGrade' => one,
        'NumberofBedrooms' => one,
        'ConditionedFloorArea' => one,
        'ConditionedBuildingVolume | AverageCeilingHeight' => one_or_more,
      },

      # [Neighbors]
      '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors' => {
        'NeighborBuilding' => one_or_more, # See [NeighborBuilding]
      },

      # [NeighborBuilding]
      '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding' => {
        'Azimuth' => one,
        'Distance' => one, # ft
        'Height' => zero_or_one # ft; if omitted, the neighbor is the same height as the main building
      },

      # [ClimateZone]
      '/HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC' => {
        'Year' => one,
        'ClimateZone' => one,
      },

      # [WeatherStation]
      '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Name' => one, # Required by HPXML schema
        'WMO | extension/EPWFileName' => one, # Reference weather/data.csv for the list of acceptable WMO station numbers
      },

      # [AirInfiltration]
      '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'HousePressure' => one, # Required by HPXML schema
        'BuildingAirLeakage' => one, # Required by HPXML schema
        'BuildingAirLeakage/UnitofMeasure' => one, # Required by HPXML schema
        'BuildingAirLeakage/AirLeakage' => one, # Required by HPXML schema
        'InfiltrationVolume' => zero_or_one, # Assumes InfiltrationVolume = ConditionedVolume if not provided
      },

      # [Roof]
      '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'InteriorAdjacentTo' => one, # See [VentedAttic]
        'Area' => one,
        'Azimuth' => zero_or_one,
        'SolarAbsorptance' => one,
        'Emittance' => one,
        'Pitch' => one,
        'RadiantBarrier' => one,
        'Insulation/SystemIdentifier' => one, # Required by HPXML schema
        'Insulation/AssemblyEffectiveRValue' => one,
      },

      ## [VentedAttic]
      '/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic' => {
        'AtticType/Attic/Vented' => zero_or_one,
        'VentilationRate/UnitofMeasure' => zero_or_one,
        'VentilationRate/Value' => zero_or_one,
      },

      # [Wall]
      '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'ExteriorAdjacentTo' => one,
        'InteriorAdjacentTo' => one,
        'WallType/WoodStud' => one,
        'WallType/DoubleWoodStud' => one,
        'WallType/ConcreteMasonryUnit' => one,
        'WallType/StructurallyInsulatedPanel' => one,
        'WallType/InsulatedConcreteForms' => one,
        'WallType/SteelFrame' => one,
        'WallType/SolidConcrete' => one,
        'WallType/StructuralBrick' => one,
        'WallType/StrawBale' => one,
        'WallType/Stone' => one,
        'WallType/LogWall' => one,
        'Area' => one,
        'Azimuth' => zero_or_one,
        'SolarAbsorptance' => one,
        'Emittance' => one,
        'Insulation/SystemIdentifier' => one, # Required by HPXML schema
        'Insulation/AssemblyEffectiveRValue' => one,
      },

      # [RimJoist]
      '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'ExteriorAdjacentTo' => one,
        'InteriorAdjacentTo' => one,
        'Area' => one,
        'Azimuth' => zero_or_one,
        'SolarAbsorptance' => one,
        'Emittance' => one,
        'Insulation/SystemIdentifier' => one, # Required by HPXML schema
        'Insulation/AssemblyEffectiveRValue' => one,
      },

      # [FoundationWall]
      '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'ExteriorAdjacentTo' => one,
        'InteriorAdjacentTo' => one, # See [VentedCrawlspace]
        'Height' => one,
        'Area' => one,
        'Azimuth' => zero_or_one,
        'Thickness' => one,
        'DepthBelowGrade' => one,
        'Insulation/SystemIdentifier' => one, # Required by HPXML schema
        # Insulation: either specify interior and exterior layers OR assembly R-value:
        'Insulation/Layer/InstallationType' => one,
        'Insulation/AssemblyEffectiveRValue' => one, # See [FoundationWallInsLayer]
      },

      ## [VentedCrawlspace]
      '/HPXML/Building/BuildingDetails/Enclosure' => {
        'Foundations/Foundation/FoundationType/Crawlspace/Vented' => zero_or_one,
        'Foundations/Foundation/VentilationRate/UnitofMeasure' => zero_or_one,
        'Foundations/Foundation/VentilationRate/Value' => zero_or_one,
      },

      ## [FoundationWallInsLayer]
      '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer' => {
        'InstallationType' => one,
        'NominalRValue' => one,
        'extension/DistanceToTopOfInsulation' => one, # ft
        'extension/DistanceToBottomOfInsulation' => one, # ft
      },

      # [FrameFloor]
      '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'ExteriorAdjacentTo' => one,
        'InteriorAdjacentTo' => one,
        'Area' => one,
        'Insulation/SystemIdentifier' => one, # Required by HPXML schema
        'Insulation/AssemblyEffectiveRValue' => one,
      },

      # [Slab]
      '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'InteriorAdjacentTo' => one,
        'Area' => one,
        'Thickness' => one, # Use zero for dirt floor
        'ExposedPerimeter' => one,
        'PerimeterInsulationDepth' => one,
        'UnderSlabInsulationWidth | UnderSlabInsulationSpansEntireSlab' => one,
        'DepthBelowGrade' => one_or_more, # DepthBelowGrade only required when InteriorAdjacentTo is 'living space' or 'garage'
        'PerimeterInsulation/SystemIdentifier' => one, # Required by HPXML schema
        'PerimeterInsulation/Layer/NominalRValue' => one,
        'PerimeterInsulation/Layer/InstallationType' => one,
        'UnderSlabInsulation/SystemIdentifier' => one, # Required by HPXML schema
        'UnderSlabInsulation/Layer/InstallationType' => one,
        'UnderSlabInsulation/Layer/NominalRValue' => one,
        'extension/CarpetFraction' => one, # 0 - 1
        'extension/CarpetRValue' => one,
      },

      # [Window]
      '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Area' => one,
        'Azimuth' => one,
        'UFactor' => one,
        'SHGC' => one,
        'InteriorShading/SummerShadingCoefficient' => zero_or_one, # Uses ERI assumption if not provided
        'InteriorShading/WinterShadingCoefficient' => zero_or_one, # Uses ERI assumption if not provided
        'Overhangs' => zero_or_one, # See [WindowOverhang]
        'FractionOperable' => zero_or_one,
        'AttachedToWall' => one,
      },

      ## [WindowOverhang]
      '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/Overhangs' => {
        'Depth' => one,
        'DistanceToTopOfWindow' => one,
        'DistanceToBottomOfWindow' => one,
      },

      # [Skylight]
      '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Area' => one,
        'Azimuth' => one,
        'UFactor' => one,
        'SHGC' => one,
        'AttachedToRoof' => one,
      },

      # [Door]
      '/HPXML/Building/BuildingDetails/Enclosure/Doors/Door' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'AttachedToWall' => one,
        'Area' => one,
        'Azimuth' => one,
        'RValue' => one,
      },

      # [HeatingSystem]
      '/HPXML/Building/BuildingDetails/Systems/HVAC' => {
        'HVACControl' => one, # See [HVACControl]
      },

      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'HeatingCapacity' => one, # Use -1 for autosizing
        'FractionHeatLoadServed' => one, # Must sum to <= 1 across all HeatingSystems and HeatPumps
        'ElectricAuxiliaryEnergy' => zero_or_one, # If not provided, uses 301 defaults for fuel furnace/boiler and zero otherwise
        'HeatingSystemType/Boiler' => one,
        'HeatingSystemType/ElectricResistance' => one,
        'HeatingSystemType/Furnace' => one,
        'HeatingSystemType/WallFurnace' => one,
        'HeatingSystemType/Stove' => one,
        'HeatingSystemType/PortableHeater' => one,
        'DistributionSystem' => one,
        'HeatingSystemFuel' => one, # See [HeatingType=FuelEquipment] if not electricity
        'AnnualHeatingEfficiency/Units' => one,
        'AnnualHeatingEfficiency/Value' => one,
      },

      # [CoolingSystem]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'CoolingCapacity' => one, # Use -1 for autosizing
        'FractionCoolLoadServed' => one, # Must sum to <= 1 across all CoolingSystems and HeatPumps
        'CoolingSystemType' => one,
        'DistributionSystem' => one,
        'CoolingSystemFuel' => one, # See [HeatingType=FuelEquipment] if not electricity
        'AnnualCoolingEfficiency/Units' => one,
        'AnnualCoolingEfficiency/Value' => one,
        'SensibleHeatFraction' => one,
        'CompressorType' => one,
      },

      # [HeatPump]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'HeatPumpType' => one, # See [HeatPumpType=ASHP] or [HeatPumpType=MSHP] or [HeatPumpType=GSHP]
        'HeatPumpFuel' => one,
        'HeatingCapacity' => one, # Use -1 for autosizing
        'CoolingCapacity' => one, # Use -1 for autosizing
        'CoolingSensibleHeatFraction' => zero_or_one,
        'BackupSystemFuel' => one, # See [HeatPumpBackup]
        'FractionHeatLoadServed' => one, # Must sum to <= 1 across all HeatPumps and HeatingSystems
        'FractionCoolLoadServed' => one, # Must sum to <= 1 across all HeatPumps and CoolingSystems
        'DistributionSystem' => one,
        'CompressorType' => one,
        'AnnualCoolingEfficiency/Units' => one,
        'AnnualCoolingEfficiency/Value' => one,
        'AnnualHeatingEfficiency/Units' => one,
        'AnnualHeatingEfficiency/Value' => one,
        'HeatingCapacity17F' => zero_or_one,
        'BackupHeatingSwitchoverTemperature' => zero,
        'BackupAnnualHeatingEfficiency/Units' => one,
        'BackupAnnualHeatingEfficiency/Value' => one,
        'BackupHeatingCapacity' => one, # Use -1 for autosizing,
      },

      # [HVACControl]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'SetpointTempHeatingSeason' => one,
        'SetbackTempHeatingSeason' => zero_or_one, # See [HVACControlType=HeatingSetback]
        'SetupTempCoolingSeason' => zero_or_one, # See [HVACControlType=CoolingSetup]
        'SetpointTempCoolingSeason' => one,
        'extension/CeilingFanSetpointTempCoolingSeasonOffset' => zero_or_one, # deg-F
        'extension/SetbackStartHourHeating' => one, # 0 = midnight. 12 = noon
        'TotalSetbackHoursperWeekHeating' => one,
        'TotalSetupHoursperWeekCooling' => one,
        'extension/SetupStartHourCooling' => one, # 0 = midnight, 12 = noon
      },

      ## [HVACDistType=Air]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution' => {
        'DuctLeakageMeasurement/DuctLeakage/Units' => zero_or_one,
        'DuctLeakageMeasurement/DuctLeakage/TotalOrToOutside' => zero_or_one,
        'DuctLeakageMeasurement/DuctLeakage/Value' => zero_or_one,
        'Ducts/DuctType' => zero_or_more, # See [HVACDuct]
      },

      ## [HVACDistType=DSE]
      ## WARNING: These inputs are unused and EnergyPlus output will NOT reflect the specified DSE. To account for DSE, apply the value to the EnergyPlus output.
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'DistributionSystemType/Other' => zero_or_one,
        'AnnualHeatingDistributionSystemEfficiency | AnnualCoolingDistributionSystemEfficiency' => one_or_more,
      },

      ## [HVACDuct]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts' => {
        'DuctInsulationRValue' => one,
        'DuctLocation' => one,
        'DuctSurfaceArea' => one,
      },

      # [MechanicalVentilation]
      '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan' => {
        'UsedForWholeBuildingVentilation' => one,
        'UsedForSeasonalCoolingLoadReduction' => one,
        'SystemIdentifier' => one, # Required by HPXML schema
        'FanType' => one, # See [MechVentType=HRV] or [MechVentType=ERV] or [MechVentType=CFIS]
        'TestedFlowRate | RatedFlowRate' => one_or_more,
        'HoursInOperation' => one,
        'FanPower' => one,
        'SensibleRecoveryEfficiency | AdjustedSensibleRecoveryEfficiency' => one,
        'TotalRecoveryEfficiency | AdjustedTotalRecoveryEfficiency' => one,
        'AttachedToHVACDistributionSystem' => one,
      },

      # [WaterHeatingSystem]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'WaterHeaterType' => one, # See [WHType=Tank] or [WHType=Tankless] or [WHType=HeatPump] or [WHType=Indirect] or [WHType=CombiTankless]
        'Location' => one,
        'FractionDHWLoadServed' => one,
        'HotWaterTemperature' => zero_or_one,
        'UsesDesuperheater' => zero_or_one, # See [Desuperheater]
        'FuelType' => one,
        'TankVolume' => one,
        'HeatingCapacity' => one,
        'EnergyFactor | UniformEnergyFactor' => one,
        'WaterHeaterInsulation/Jacket/JacketRValue' => zero_or_one, # Capable to model tank wrap insulation
        'RecoveryEfficiency' => one,
        'PerformanceAdjustment' => zero_or_one, # Uses ERI assumption for tankless cycling derate if not provided
        'RelatedHVACSystem' => one, # HeatingSystem (boiler)
        'StandbyLoss' => zero_or_one, # Refer to https://www.ahridirectory.org/NewSearch?programId=28&searchTypeId=3
      },

      # [HotWaterDistribution]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'SystemType/Standard | SystemType/Recirculation' => one, # See [HWDistType=Standard] or [HWDistType=Recirculation]
        'PipeInsulation/PipeRValue' => one,
        'DrainWaterHeatRecovery' => zero_or_one, # See [DrainWaterHeatRecovery]
      },

      ## [HWDistType=Standard]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Standard' => {
        'PipingLength' => zero_or_one,
      },

      ## [HWDistType=Recirculation]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Recirculation' => {
        'ControlType' => one,
        'RecirculationPipingLoopLength' => one,
        'BranchPipingLoopLength' => one,
        'PumpPower' => one,
      },

      ## [DrainWaterHeatRecovery]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/DrainWaterHeatRecovery' => {
        'FacilitiesConnected' => one,
        'EqualFlow' => one,
        'Efficiency' => one,
      },

      # [WaterFixture]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterFixture' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'WaterFixtureType' => one, # Required by HPXML schema
        'LowFlow' => one,
      },

      # [SolarThermalSystem]
      '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'SystemType' => one,
        'CollectorArea | SolarFraction' => one, # See [SolarThermal=Detailed] if CollectorArea provided
        'ConnectedTo' => one, # WaterHeatingSystem (any type but space-heating boiler)
        'CollectorLoopType' => one,
        'CollectorType' => one,
        'CollectorAzimuth' => one,
        'CollectorTilt' => one,
        'CollectorRatedOpticalEfficiency' => one,
        'CollectorRatedThermalLosses' => one,
        'StorageVolume' => one,
      },

      # [PVSystem]
      '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Location' => one,
        'ModuleType' => one,
        'Tracking' => one,
        'ArrayAzimuth' => one,
        'ArrayTilt' => one,
        'MaxPowerOutput' => one,
        'InverterEfficiency' => zero_or_one,
        'SystemLossesFraction | YearModulesManufactured' => zero_or_more,
      },

      # [ClothesWasher]
      '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Location' => one,
        'ModifiedEnergyFactor | IntegratedModifiedEnergyFactor | Usage | RatedAnnualkWh | LabelElectricRate | LabelGasRate | LabelAnnualGasCost | Capacity' => zero_or_seven,
      },

      # [ClothesDryer]
      '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Location' => one,
        'FuelType' => one,
        'EnergyFactor | CombinedEnergyFactor | ControlType' => zero_or_two,
      },

      # [Dishwasher]
      '/HPXML/Building/BuildingDetails/Appliances/Dishwasher' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'RatedAnnualkWh | LabelElectricRate | LabelGasRate | LabelAnnualGasCost | PlaceSettingCapacity' => zero_or_five,
      },

      # [Refrigerator]
      '/HPXML/Building/BuildingDetails/Appliances/Refrigerator' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Location' => one,
        'RatedAnnualkWh | extension/AdjustedAnnualkWh' => zero_or_more,
      },

      # [CookingRange]
      '/HPXML/Building/BuildingDetails/Appliances/CookingRange' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'FuelType' => one,
        'IsInduction' => zero_or_one,
      },

      # [CookingRange]
      '/HPXML/Building/BuildingDetails/Appliances/Oven' => {
        'IsConvection' => zero_or_one,
      },

      ## [LightingGroup]
      '/HPXML/Building/BuildingDetails/Lighting/LightingGroup' => {
        'ThirdPartyCertification' => one,
        'Location' => one,
        'SystemIdentifier' => one, # Required by HPXML schema
        'FractionofUnitsInLocation' => one,
      },

      # [CeilingFan]
      '/HPXML/Building/BuildingDetails/Lighting/CeilingFan' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Airflow/Efficiency' => zero_or_one, # Uses Reference Home if not provided
        'Airflow/FanSpeed' => zero_or_one, # Uses Reference Home if not provided
        'Quantity' => zero_or_one, # Uses Reference Home if not provided
      },

      # [PlugLoads]
      '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad' => {
        'PlugLoadType' => one,
        'SystemIdentifier' => one, # Required by HPXML schema
        'Load/Value' => zero_or_one, # Uses ERI Reference Home if not provided
        'Load/Units' => zero_or_one, # Uses ERI Reference Home if not provided
        'extension/FracSensible' => zero_or_one, # Uses ERI Reference Home if not provided
        'extension/FracLatent' => zero_or_one, # Uses ERI Reference Home if not provided
      },

      # [Television]
      '/HPXML/Building/BuildingDetails/MiscLoads' => {
        'extension/WeekdayScheduleFractions' => zero_or_one, # Uses ERI Reference Home if not provided
        'extension/WeekendScheduleFractions' => zero_or_one, # Uses ERI Reference Home if not provided
        'extension/MonthlyScheduleMultipliers' => zero_or_one, # Uses ERI Reference Home if not provided
      },

    }

    puts 'run validator!'
    errors = []
    if @doc_base.nil?
      this_dir = File.dirname(__FILE__)
      base_el_xsd_path = this_dir + '/BaseElements.xsd'
      @doc_base = REXML::Document.new(File.new(base_el_xsd_path))
    end
    requirements.each do |parent, requirement|
      if parent.nil? # Unconditional
        requirement.each do |child, expected_sizes|
          next if expected_sizes.nil?

          xpath = combine_into_xpath(parent, child)
          xpath.gsub(/(?<reg>(\[([^\]\[]|\g<reg>)*\]))/, '').split(/ [|,or] /).each do |el_path|
            el_array = el_path.split('/').reject { |p| p.empty? }
            load_or_get_data_type_xsd(el_array)
          end
        end
      else # Conditional based on parent element existence
        parent.gsub(/(?<reg>(\[([^\]\[]|\g<reg>)*\]))/, '').split(/ [|,or] /).each do |parent_path|
          requirement.each do |child, expected_sizes|
            next if expected_sizes.nil?

            child.gsub(/(?<reg>(\[([^\]\[]|\g<reg>)*\]))/, '').split(/ [|,or] /).each do |child_path|
              el_path = combine_into_xpath(parent_path, child_path)
              next if el_path == parent_path
              el_array = el_path.split('/').reject { |p| p.empty? }
              load_or_get_data_type_xsd(el_array)
            end
          end
        end
      end
    end

    json_tree = JSON.parse(@type_tree.to_json)
    # remove json_class key pairs from hash
    recursively_remove_property(json_tree, "json_class")
    File.open(this_dir + '/element_type_tree.json','w') do |f|
      f.write(JSON.pretty_generate(json_tree))
    end

    return errors
  end

  def self.recursively_remove_property(target, property)
    target.delete_if do |k, v|
      if k == property
        true
      elsif v.is_a?(Array)
        v.each do |v_h|
        recursively_remove_property(v_h, property)
        end
        false
      end
    end
  end

  def self.load_or_get_data_type_xsd(el_array)
    if @type_tree.nil?
      @type_tree = Tree::TreeNode.new("ROOT", nil)
    end
    #return @type_map[el_array] if not @type_map[el_array].nil?
    puts ''
    puts '----New element validation required!----'

    parent_type = nil
    parent_name = nil
    # part1: get element data type from BaseElements.xsd using path

    el_array.each_with_index do |el_name, i|
      next if i < 2
      return if el_name == 'extension'
      if (i == 2)
        child_node = @type_tree
      else
        child_node = @type_tree
        for index in 2..i-1 do
          child_node = child_node[el_array[index]]
        end
      end
      if not child_node.nil?
      if not child_node[el_name].nil?
        parent_type = child_node[el_name].content
        parent_name = el_name
        next
      end
      end

      puts 'this element name: ' + el_name
      puts 'parent type: ' 
      puts parent_type
      puts 'parent name: '
      puts parent_name
      
      if parent_type.nil? && parent_name.nil?
        parent_type = REXML::XPath.first(@doc_base, "//xs:element[@name='#{el_name}']").attributes['type']
        child_node << Tree::TreeNode.new(el_name, parent_type)
      else
        if (not parent_name.nil?) && parent_type.nil?
          el = REXML::XPath.first(@doc_base, "//xs:element[@name='#{parent_name}']//xs:element[@name='#{el_name}']")
          if el.nil?
            group_name = REXML::XPath.first(@doc_base, "//xs:element[@name='#{parent_name}']//xs:group").attributes['ref']
          end
          while el.nil? do
            puts group_name
            el = REXML::XPath.first(@doc_base, "//xs:group[@name='#{group_name}']//xs:element[@name='#{el_name}']")
            group_name = REXML::XPath.first(@doc_base, "//xs:group[@name='#{group_name}']//xs:group").attributes['ref'] if el.nil?
          end
        else
          el = REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{parent_type}']//xs:element[@name='#{el_name}']")
          while el.nil? do
            # this approach can only have one group or one base
            group = REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{parent_type}']//xs:group")
            base = REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{parent_type}']//xs:extension")
            if not base.nil? and group.nil?
              base_name = base.attributes['base']
              el = REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{base_name}']//xs:element[@name='#{el_name}']")
              parent_type = base_name
            elsif not group.nil?
              group_name = group.attributes['ref']
              el = REXML::XPath.first(@doc_base, "//xs:group[@name='#{group_name}']//xs:element[@name='#{el_name}']") unless REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{parent_type}']//xs:group").nil?
            else
              break
            end
          end
        end
        el_type = el.attributes['type']
        child_node << Tree::TreeNode.new(el_name, el_type)
        parent_type = el_type
      end
      parent_name = el_name
    end
  end

  def self.combine_into_xpath(parent, child)
    if parent.nil?
      return child
    elsif child.start_with?('[')
      return [parent, child].join('')
    end

    return [parent, child].join('/')
  end
end

HPXMLValidator.run_validator()