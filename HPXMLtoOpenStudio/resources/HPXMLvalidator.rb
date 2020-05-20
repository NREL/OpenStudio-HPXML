require_relative 'xmlhelper'
require 'oga'

class HPXMLValidator
  @xpath_array = ['/HPXML/XMLTransactionHeaderInformation/XMLType',
                  '/HPXML/XMLTransactionHeaderInformation/XMLGeneratedBy',
                  '/HPXML/XMLTransactionHeaderInformation/CreatedDateAndTime',
                  '/HPXML/XMLTransactionHeaderInformation/Transaction',
                  '/HPXML/SoftwareInfo/extension/SimulationControl',

                  '/HPXML/Building',
                  '/HPXML/Building/BuildingID',
                  '/HPXML/Building/ProjectStatus/EventType',

                  '/HPXML/Building/BuildingDetails/BuildingSummary/Site/SiteType',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/ShelterCoefficient',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingOccupancy/NumberofResidents',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors',

                  '/HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC',
                  '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation',

                  '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/extension/ConstantACHnatural',

                  '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall',
                  '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall',
                  '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window',
                  '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight',
                  '/HPXML/Building/BuildingDetails/Enclosure/Doors/Door',

                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution',

                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterFixture',
                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem',
                  '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem',

                  '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer',
                  '/HPXML/Building/BuildingDetails/Appliances/Dishwasher',
                  '/HPXML/Building/BuildingDetails/Appliances/Refrigerator',
                  '/HPXML/Building/BuildingDetails/Appliances/Dehumidifier',
                  '/HPXML/Building/BuildingDetails/Appliances/CookingRange',

                  '/HPXML/Building/BuildingDetails/Lighting',
                  '/HPXML/Building/BuildingDetails/Lighting/CeilingFan',

                  '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad',

                  '/HPXML/SoftwareInfo/extension/SimulationControl/Timestep',
                  '/HPXML/SoftwareInfo/extension/SimulationControl/BeginMonth',
                  '/HPXML/SoftwareInfo/extension/SimulationControl/BeginDayOfMonth',
                  '/HPXML/SoftwareInfo/extension/SimulationControl/EndMonth',
                  '/HPXML/SoftwareInfo/extension/SimulationControl/EndDayOfMonth',

                  '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloors',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloorsAboveGrade',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofBedrooms',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofBathrooms',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedFloorArea',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedBuildingVolume',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/AverageCeilingHeight',

                  '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding/Azimuth',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding/Distance',
                  '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding/Height',

                  '/HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC/Year',
                  '/HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC/ClimateZone',

                  '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/Name',
                  '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/WMO',
                  '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/extension/EPWFilePath',

                  '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/HousePressure',
                  '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/BuildingAirLeakage',
                  '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/BuildingAirLeakage/UnitofMeasure',
                  '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/BuildingAirLeakage/AirLeakage',
                  '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/InfiltrationVolume',

                  '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/InteriorAdjacentTo',
                  '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Area',
                  '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Azimuth',
                  '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/SolarAbsorptance',
                  '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Emittance',
                  '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Pitch',
                  '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/RadiantBarrier',
                  '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Insulation/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Insulation/AssemblyEffectiveRValue',

                  '/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic/AtticType/Attic/Vented',
                  '/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic/VentilationRate/UnitofMeasure',
                  '/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic/VentilationRate/Value',

                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/ExteriorAdjacentTo',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/InteriorAdjacentTo',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/WoodStud',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/DoubleWoodStud',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/ConcreteMasonryUnit',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/StructurallyInsulatedPanel',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/InsulatedConcreteForms',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/SteelFrame',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/SolidConcrete',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/StructuralBrick',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/StrawBale',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/Stone',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/LogWall',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Area',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Azimuth',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/SolarAbsorptance',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Emittance',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Insulation/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Insulation/AssemblyEffectiveRValue',

                  '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/ExteriorAdjacentTo',
                  '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/InteriorAdjacentTo',
                  '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Area',
                  '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Azimuth',
                  '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/SolarAbsorptance',
                  '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Emittance',
                  '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Insulation/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Insulation/AssemblyEffectiveRValue',

                  '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation/FoundationType/Crawlspace/Vented',
                  '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation/VentilationRate/UnitofMeasure',
                  '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation/VentilationRate/Value',

                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/ExteriorAdjacentTo',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/InteriorAdjacentTo',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Height',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Area',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Azimuth',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Thickness',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/DepthBelowGrade',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/AssemblyEffectiveRValue',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer/InstallationType',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer/NominalRValue',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer/extension/DistanceToTopOfInsulation',
                  '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer/extension/DistanceToBottomOfInsulation',

                  '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/ExteriorAdjacentTo',
                  '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/InteriorAdjacentTo',
                  '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/Area',
                  '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/Insulation/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/Insulation/AssemblyEffectiveRValue',

                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/InteriorAdjacentTo',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/Area',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/Thickness',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/ExposedPerimeter',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/PerimeterInsulationDepth',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulationWidth',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulationSpansEntireSlab',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/DepthBelowGrade',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/PerimeterInsulation/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/PerimeterInsulation/Layer/NominalRValue',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/PerimeterInsulation/Layer/InstallationType',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulation/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulation/Layer/InstallationType',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulation/Layer/NominalRValue',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/extension/CarpetFraction',
                  '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/extension/CarpetRValue',

                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/Area',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/Azimuth',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/UFactor',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/SHGC',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/InteriorShading/SummerShadingCoefficient',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/InteriorShading/WinterShadingCoefficient',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/Overhangs',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/FractionOperable',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/AttachedToWall',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/Overhangs/Depth',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/Overhangs/DistanceToTopOfWindow',
                  '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/Overhangs/DistanceToBottomOfWindow',

                  '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight/Area',
                  '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight/Azimuth',
                  '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight/UFactor',
                  '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight/SHGC',
                  '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight/AttachedToRoof',

                  '/HPXML/Building/BuildingDetails/Enclosure/Doors/Door/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Enclosure/Doors/Door/AttachedToWall',
                  '/HPXML/Building/BuildingDetails/Enclosure/Doors/Door/Area',
                  '/HPXML/Building/BuildingDetails/Enclosure/Doors/Door/Azimuth',
                  '/HPXML/Building/BuildingDetails/Enclosure/Doors/Door/RValue',

                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/HeatingCapacity',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/FractionHeatLoadServed',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/ElectricAuxiliaryEnergy',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/HeatingSystemType/Boiler',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/HeatingSystemType/ElectricResistance',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/HeatingSystemType/Furnace',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/HeatingSystemType/WallFurnace',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/HeatingSystemType/Stove',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/HeatingSystemType/PortableHeater',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/DistributionSystem',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/HeatingSystemFuel',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/AnnualHeatingEfficiency/Units',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/AnnualHeatingEfficiency/Value',

                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem/CoolingCapacity',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem/FractionCoolLoadServed',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem/CoolingSystemType',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem/DistributionSystem',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem/CoolingSystemFuel',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem/AnnualCoolingEfficiency/Units',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem/AnnualCoolingEfficiency/Value',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem/SensibleHeatFraction',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem/CompressorType',

                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/HeatPumpType',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/HeatPumpFuel',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/HeatingCapacity',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/CoolingCapacity',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/CoolingSensibleHeatFraction',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/BackupSystemFuel',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/FractionHeatLoadServed',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/FractionCoolLoadServed',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/DistributionSystem',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/CompressorType',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/AnnualCoolingEfficiency/Units',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/AnnualCoolingEfficiency/Value',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/AnnualHeatingEfficiency/Units',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/AnnualHeatingEfficiency/Value',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/HeatingCapacity17F',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/BackupHeatingSwitchoverTemperature',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/BackupAnnualHeatingEfficiency/Units',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/BackupAnnualHeatingEfficiency/Value',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/BackupHeatingCapacity',

                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl/SetpointTempHeatingSeason',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl/SetbackTempHeatingSeason',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl/SetupTempCoolingSeason',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl/SetpointTempCoolingSeason',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl/extension/CeilingFanSetpointTempCoolingSeasonOffset',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl/extension/SetbackStartHourHeating',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl/TotalSetbackHoursperWeekHeating',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl/TotalSetupHoursperWeekCooling',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl/extension/SetupStartHourCooling',

                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/DuctLeakageMeasurement/DuctLeakage/Units',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/DuctLeakageMeasurement/DuctLeakage/TotalOrToOutside',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/DuctLeakageMeasurement/DuctLeakage/Value',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts/DuctType',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/SystemIdentifier',

                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/Other',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/AnnualHeatingDistributionSystemEfficiency',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/AnnualCoolingDistributionSystemEfficiency',

                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts/DuctInsulationRValue',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts/DuctLocation',
                  '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts/DuctSurfaceArea',

                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/UsedForWholeBuildingVentilation',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/UsedForSeasonalCoolingLoadReduction',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/UsedForLocalVentilation',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/FanType',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/TestedFlowRate',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/RatedFlowRate',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/HoursInOperation',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/FanPower',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/SensibleRecoveryEfficiency',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/AdjustedSensibleRecoveryEfficiency',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/TotalRecoveryEfficiency',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/AdjustedTotalRecoveryEfficiency',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/AttachedToHVACDistributionSystem',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/FanLocation',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/extension/StartHour',
                  '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan/Quantity',

                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/WaterHeaterType',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/Location',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/FractionDHWLoadServed',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/HotWaterTemperature',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/UsesDesuperheater',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/FuelType',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/TankVolume',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/HeatingCapacity',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/EnergyFactor',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/UniformEnergyFactor',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/WaterHeaterInsulation/Jacket/JacketRValue',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/RecoveryEfficiency',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/PerformanceAdjustment',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/RelatedHVACSystem',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/StandbyLoss',

                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Standard',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Recirculation',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/PipeInsulation/PipeRValue',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/DrainWaterHeatRecovery',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Standard/PipingLength',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Recirculation/ControlType',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Recirculation/RecirculationPipingLoopLength',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Recirculation/BranchPipingLoopLength',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Recirculation/PumpPower',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/DrainWaterHeatRecovery/FacilitiesConnected',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/DrainWaterHeatRecovery/EqualFlow',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/DrainWaterHeatRecovery/Efficiency',

                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterFixture/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterFixture/WaterFixtureType',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterFixture/LowFlow',
                  '/HPXML/Building/BuildingDetails/Systems/WaterHeating/extension/WaterFixturesUsageMultiplier',

                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem/SystemType',
                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem/CollectorArea',
                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem/SolarFraction',
                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem/ConnectedTo',
                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem/CollectorLoopType',
                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem/CollectorType',
                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem/CollectorAzimuth',
                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem/CollectorTilt',
                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem/CollectorRatedOpticalEfficiency',
                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem/CollectorRatedThermalLosses',
                  '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem/StorageVolume',

                  '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem/Location',
                  '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem/ModuleType',
                  '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem/Tracking',
                  '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem/ArrayAzimuth',
                  '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem/ArrayTilt',
                  '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem/MaxPowerOutput',
                  '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem/InverterEfficiency',
                  '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem/SystemLossesFraction',
                  '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem/YearModulesManufactured',

                  '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/Location',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/ModifiedEnergyFactor',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/IntegratedModifiedEnergyFactor',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/LabelUsage',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/RatedAnnualkWh',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/LabelElectricRate',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/LabelGasRate',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/LabelAnnualGasCost',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/Capacity',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/extension/UsageMultiplier',

                  '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/Location',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/FuelType',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/EnergyFactor',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/CombinedEnergyFactor',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/ControlType',
                  '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/extension/UsageMultiplier',

                  '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/Location',
                  '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/RatedAnnualkWh',
                  '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/EnergyFactor',
                  '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/LabelElectricRate',
                  '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/LabelGasRate',
                  '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/LabelAnnualGasCost',
                  '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/LabelUsage',
                  '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/PlaceSettingCapacity',
                  '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/extension/UsageMultiplier',

                  '/HPXML/Building/BuildingDetails/Appliances/Refrigerator/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Appliances/Refrigerator/Location',
                  '/HPXML/Building/BuildingDetails/Appliances/Refrigerator/RatedAnnualkWh',
                  '/HPXML/Building/BuildingDetails/Appliances/Refrigerator/extension/AdjustedAnnualkWh',
                  '/HPXML/Building/BuildingDetails/Appliances/Refrigerator/extension/UsageMultiplier',

                  '/HPXML/Building/BuildingDetails/Appliances/Dehumidifier/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Appliances/Dehumidifier/Capacity',
                  '/HPXML/Building/BuildingDetails/Appliances/Dehumidifier/EnergyFactor',
                  '/HPXML/Building/BuildingDetails/Appliances/Dehumidifier/IntegratedEnergyFactor',
                  '/HPXML/Building/BuildingDetails/Appliances/Dehumidifier/DehumidistatSetpoint',
                  '/HPXML/Building/BuildingDetails/Appliances/Dehumidifier/FractionDehumidificationLoadServed',

                  '/HPXML/Building/BuildingDetails/Appliances/CookingRange/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Appliances/CookingRange/Location',
                  '/HPXML/Building/BuildingDetails/Appliances/CookingRange/FuelType',
                  '/HPXML/Building/BuildingDetails/Appliances/CookingRange/IsInduction',
                  '/HPXML/Building/BuildingDetails/Appliances/CookingRange/extension/UsageMultiplier',
                  '/HPXML/Building/BuildingDetails/Appliances/Oven/IsConvection',

                  '/HPXML/Building/BuildingDetails/Lighting/LightingGroup/LightingType/LightEmittingDiode',
                  '/HPXML/Building/BuildingDetails/Lighting/LightingGroup/LightingType/CompactFluorescent',
                  '/HPXML/Building/BuildingDetails/Lighting/LightingGroup/LightingType/FluorescentTube',
                  '/HPXML/Building/BuildingDetails/Lighting/LightingGroup/Location',
                  '/HPXML/Building/BuildingDetails/Lighting/extension/UsageMultiplier',
                  '/HPXML/Building/BuildingDetails/Lighting/LightingGroup/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Lighting/LightingGroup/FractionofUnitsInLocation',

                  '/HPXML/Building/BuildingDetails/Lighting/CeilingFan/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/Lighting/CeilingFan/Airflow/Efficiency',
                  '/HPXML/Building/BuildingDetails/Lighting/CeilingFan/Airflow/FanSpeed',
                  '/HPXML/Building/BuildingDetails/Lighting/CeilingFan/Quantity',

                  '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad/PlugLoadType',
                  '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad/SystemIdentifier',
                  '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad/Load/Value',
                  '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad/Load/Units',
                  '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad/extension/FracSensible',
                  '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad/extension/FracLatent',
                  '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad/extension/UsageMultiplier',
                  '/HPXML/Building/BuildingDetails/MiscLoads/extension/WeekdayScheduleFractions',
                  '/HPXML/Building/BuildingDetails/MiscLoads/extension/WeekendScheduleFractions',
                  '/HPXML/Building/BuildingDetails/MiscLoads/extension/MonthlyScheduleMultipliers']

  def self.get_data_type_req_xml()
    this_dir = File.dirname(__FILE__)
    base_el_xsd_path = this_dir + '/BaseElements.xsd'
    doc_base = XMLHelper.parse_file(base_el_xsd_path)
    dt_type_xsd_path = this_dir + '/HPXMLDataTypes.xsd'
    doc_data = XMLHelper.parse_file(dt_type_xsd_path)

    type_xml = XMLHelper.create_doc(version = '1.0', encoding = 'UTF-8')
    type_map = XMLHelper.add_element(type_xml, 'ElementDataTypeMap')
    hpxml_el = XMLHelper.add_element(type_map, 'HPXML')

    # add top level elements (specified in HPXML.xsd)
    XMLHelper.add_element(hpxml_el, 'XMLTransactionHeaderInformation')
    XMLHelper.add_element(hpxml_el, 'SoftwareInfo')
    XMLHelper.add_attribute(XMLHelper.add_element(hpxml_el, 'Contractor'), 'DataType', 'Contractor')
    XMLHelper.add_attribute(XMLHelper.add_element(hpxml_el, 'Customer'), 'DataType', 'Customer')
    XMLHelper.add_attribute(XMLHelper.add_element(hpxml_el, 'Building'), 'DataType', 'Building')
    XMLHelper.add_attribute(XMLHelper.add_element(hpxml_el, 'Project'), 'DataType', 'Project')
    XMLHelper.add_attribute(XMLHelper.add_element(hpxml_el, 'Utility'), 'DataType', 'Utility')
    XMLHelper.add_attribute(XMLHelper.add_element(hpxml_el, 'Consumption'), 'DataType', 'Consumption')

    @xpath_array.each do |el_path|
      el_array = el_path.split('/').reject { |p| p.empty? }
      type_xml = get_data_type_req(el_array, type_xml, doc_base, doc_data)
    end
    XMLHelper.write_file(type_xml, this_dir + '/schema_validation.xml')
  end

  def self.validate_xml(hpxml_doc)
    puts 'Validating xml...'
    this_dir = File.dirname(__FILE__)
    schema_validation_file_path = this_dir + '/schema_validation.xml'
    doc_val = XMLHelper.parse_file(schema_validation_file_path)

    @xpath_array.each do |el_path|
      elements_in_xml = XMLHelper.get_elements(hpxml_doc, "#{el_path}")
      next if el_path.include? 'extension'
      next unless not elements_in_xml.empty?
      el_type_el = XMLHelper.get_element(doc_val, '/' + el_path)
      min_in = to_float_or_nil(XMLHelper.get_value(el_type_el, 'minInclusive'))
      min_ex = to_float_or_nil(XMLHelper.get_value(el_type_el, 'minExclusive'))
      max_in = to_float_or_nil(XMLHelper.get_value(el_type_el, 'maxInclusive'))
      max_ex = to_float_or_nil(XMLHelper.get_value(el_type_el, 'maxExclusive'))
      enums = []
      XMLHelper.get_elements(el_type_el, 'enumeration').each do |enum|
        enums << enum.text
      end
      elements_in_xml.each do |el|
        next if el.text.nil?
        xml_number = to_float_or_nil(el.text)
        if not xml_number.nil?
          if not max_in.nil?
            if (not xml_number <= max_in)
              fail "#{el_path} value: #{xml_number} out of maximum bound: #{max_in}"
            end
          elsif not max_ex.nil?
            if (not xml_number < max_ex)
              fail "#{el_path} value: #{xml_number} out of maximum bound: #{max_ex}"
            end
          end
          if not min_in.nil?
            if (not xml_number >= min_in)
              fail "#{el_path} value: #{xml_number} out of minimum bound: #{min_in}"
            end
          elsif not min_ex.nil?
            if (not xml_number > min_ex)
              fail "#{el_path} value: #{xml_number} out of minimum bound: #{min_ex}"
            end
          end
        else
          if not enums.empty?
            if not enums.include? el.text
              fail "#{el_path} invalid enumerations: #{el.text}"
            end
          end
        end
      end
    end
    puts 'Validation done!'
  end

  def self.get_data_type_req(el_array, type_xml, doc_base, doc_data)
    # get element data type from BaseElements.xsd using path
    parent_type = nil
    parent_name = nil

    # get element hierarchy and its data type
    el_array.each_with_index do |el_name, i|
      return type_xml if el_name == 'extension'
      next if i == 0
      el_type, el_node = get_element_type(type_xml, el_array, el_name, i, doc_base)
      get_type_requiements(el_type, el_node, doc_data)
    end

    return type_xml
  end

  def self.get_element_type(type_xml, el_array, el_name, i, doc_base)
    root_node = XMLHelper.get_element(type_xml, 'ElementDataTypeMap')

    parent_node = XMLHelper.get_element(root_node, el_array.take(i).join('/'))
    parent_type = XMLHelper.get_attribute_value(parent_node, 'DataType')
    parent_name = parent_node.name

    child_node = XMLHelper.get_element(parent_node, el_name)
    return [XMLHelper.get_attribute_value(child_node, 'DataType'), child_node] if not child_node.nil?

    if parent_type.nil? && parent_name.nil?
      el = XMLHelper.get_element(doc_base, "//xs:element[@name='#{el_name}']")
    else
      if (not parent_name.nil?) && parent_type.nil?
        # search elements under parent element if parent element is not pointing to a complex type
        el = XMLHelper.get_element(doc_base, "//xs:element[@name='#{parent_name}']//xs:element[@name='#{el_name}']")
        group = XMLHelper.get_element(doc_base, "//xs:element[@name='#{parent_name}']//xs:group")

        # if the element is not at first level group, search deeper grouping
        el = get_el_from_group(group, el_name, doc_base) if el.nil?
      else
        # search under parent type element
        el = XMLHelper.get_element(doc_base, "//xs:complexType[@name='#{parent_type}']//xs:element[@name='#{el_name}']")
        base = XMLHelper.get_element(doc_base, "//xs:complexType[@name='#{parent_type}']//xs:extension")
        group = XMLHelper.get_element(doc_base, "//xs:complexType[@name='#{parent_type}']//xs:group")
        if el.nil? && (not base.nil?)
          base_name = XMLHelper.get_attribute_value(base, 'base')
          el = XMLHelper.get_element(doc_base, "//xs:complexType[@name='#{base_name}']//xs:element[@name='#{el_name}']")
          # if base containing group
          base_group = XMLHelper.get_element(doc_base, "//xs:complexType[@name='#{base_name}']//xs:group")
        end

        el = get_el_from_group(group, el_name, doc_base) if el.nil?
        el = get_el_from_group(base_group, el_name, doc_base) if el.nil?
      end
    end
    el_type = XMLHelper.get_attribute_value(el, 'type')
    if not el_type.nil?
      el_node = XMLHelper.add_element(parent_node, el_name)
      XMLHelper.add_attribute(el_node, 'DataType', el_type)
    else
      el_node = XMLHelper.add_element(parent_node, el_name)
    end

    # last element
    if i == (el_array.size() - 1)
      if el_type.nil?
        puts "Warning: No data type parsed for xpath: #{el_array}"
      end
    end

    return el_type, el_node
  end

  def self.get_el_from_group(group, el_name, doc_base)
    return if group.nil?

    group_name = XMLHelper.get_attribute_value(group, 'ref')
    el = XMLHelper.get_element(doc_base, "//xs:group[@name='#{group_name}']//xs:element[@name='#{el_name}']")

    if el.nil?
      group = XMLHelper.get_element(doc_base, "//xs:group[@name='#{group_name}']//xs:group")
      get_el_from_group(group, el_name, doc_base)
    else
      return el
    end
  end

  def self.get_type_requiements(el_type, el_node, doc_data)
    complex_type_el = XMLHelper.get_element(doc_data, "//xs:complexType[@name='#{el_type}']")
    return if complex_type_el.nil?

    simple_type_el = get_base_element_from_extended_element(complex_type_el, doc_data, 'xs:simpleType')
    return if simple_type_el.nil?

    ['enumeration', 'minInclusive', 'minExclusive', 'maxInclusive', 'maxExclusive'].each do |req_name|
      XMLHelper.get_elements(simple_type_el, "xs:restriction/xs:#{req_name}").each do |req_el|
        XMLHelper.add_element(el_node, req_name, XMLHelper.get_attribute_value(req_el, 'value'))
      end
    end
  end

  def self.get_base_element_from_extended_element(extended_el, doc, base_el_name)
    extension = extended_el.at_xpath('xs:simpleContent/xs:extension')
    return if extension.nil?

    base_element_name_attr = XMLHelper.get_attribute_value(extension, 'base')
    return XMLHelper.get_element(doc, "//#{base_el_name}[@name='#{base_element_name_attr}']")
  end

  def self.to_float_or_nil(value)
    return if value.nil?
    begin
      return Float(value)
    rescue ArgumentError
      return
    end
  end
end
