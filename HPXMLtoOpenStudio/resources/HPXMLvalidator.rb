require_relative 'xmlhelper'

class HPXMLValidator
  def self.get_data_type_mapping_xml()
    xpath_array = ['/HPXML/XMLTransactionHeaderInformation/XMLType',
                   '/HPXML/XMLTransactionHeaderInformation/XMLGeneratedBy',
                   '/HPXML/XMLTransactionHeaderInformation/CreatedDateAndTime',
                   '/HPXML/XMLTransactionHeaderInformation/Transaction',
                   '/HPXML/SoftwareInfo/extension/SimulationControl',
                   '/HPXML/Building',
                   '/HPXML/Building/BuildingID',
                   '/HPXML/Building/ProjectStatus/EventType',
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
                   '/HPXML/Building/BuildingDetails/Appliances/CookingRange',
                   '/HPXML/Building/BuildingDetails/Lighting',
                   '/HPXML/Building/BuildingDetails/Lighting/CeilingFan',
                   '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad',
                   '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad',
                   '/HPXML/SoftwareInfo/extension/SimulationControl/Timestep',
                   '/HPXML/SoftwareInfo/extension/SimulationControl/BeginMonth',
                   '/HPXML/SoftwareInfo/extension/SimulationControl/BeginDayOfMonth',
                   '/HPXML/SoftwareInfo/extension/SimulationControl/EndMonth',
                   '/HPXML/SoftwareInfo/extension/SimulationControl/EndDayOfMonth',
                   '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloors',
                   '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloorsAboveGrade',
                   '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofBedrooms',
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
                   '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/extension/EPWFileName',
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
                   '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/SystemIdentifier',
                   '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/ExteriorAdjacentTo',
                   '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/InteriorAdjacentTo',
                   '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Height',
                   '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Area',
                   '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Azimuth',
                   '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Thickness',
                   '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/DepthBelowGrade',
                   '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/SystemIdentifier',
                   '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer/InstallationType',
                   '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/AssemblyEffectiveRValue',
                   '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation/FoundationType/Crawlspace/Vented',
                   '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation/VentilationRate/UnitofMeasure',
                   '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation/VentilationRate/Value',
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
                   '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl',
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
                   '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/Usage',
                   '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/RatedAnnualkWh',
                   '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/LabelElectricRate',
                   '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/LabelGasRate',
                   '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/LabelAnnualGasCost',
                   '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher/Capacity',
                   '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/SystemIdentifier',
                   '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/Location',
                   '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/FuelType',
                   '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/EnergyFactor',
                   '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/CombinedEnergyFactor',
                   '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer/ControlType',
                   '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/SystemIdentifier',
                   '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/RatedAnnualkWh',
                   '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/LabelElectricRate',
                   '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/LabelGasRate',
                   '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/LabelAnnualGasCost',
                   '/HPXML/Building/BuildingDetails/Appliances/Dishwasher/PlaceSettingCapacity',
                   '/HPXML/Building/BuildingDetails/Appliances/Refrigerator/SystemIdentifier',
                   '/HPXML/Building/BuildingDetails/Appliances/Refrigerator/Location',
                   '/HPXML/Building/BuildingDetails/Appliances/Refrigerator/RatedAnnualkWh',
                   '/HPXML/Building/BuildingDetails/Appliances/Refrigerator/extension/AdjustedAnnualkWh',
                   '/HPXML/Building/BuildingDetails/Appliances/CookingRange/SystemIdentifier',
                   '/HPXML/Building/BuildingDetails/Appliances/CookingRange/FuelType',
                   '/HPXML/Building/BuildingDetails/Appliances/CookingRange/IsInduction',
                   '/HPXML/Building/BuildingDetails/Appliances/Oven/IsConvection',
                   '/HPXML/Building/BuildingDetails/Lighting/LightingGroup/ThirdPartyCertification',
                   '/HPXML/Building/BuildingDetails/Lighting/LightingGroup/Location',
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
                   '/HPXML/Building/BuildingDetails/MiscLoads/extension/WeekdayScheduleFractions',
                   '/HPXML/Building/BuildingDetails/MiscLoads/extension/WeekendScheduleFractions',
                   '/HPXML/Building/BuildingDetails/MiscLoads/extension/MonthlyScheduleMultipliers']

    this_dir = File.dirname(__FILE__)
    base_el_xsd_path = this_dir + '/BaseElements.xsd'
    doc_base = XMLHelper.parse_file(base_el_xsd_path)

    type_xml = XMLHelper.create_doc(version = '1.0', encoding = 'UTF-8')
    type_map = XMLHelper.add_element(type_xml, 'ElementDataTypeMap')

    xpath_array.each do |el_path|
      el_array = el_path.split('/').reject { |p| p.empty? }
      puts type_xml
      type_xml = load_or_get_data_type_xsd(el_array, type_xml, doc_base)
    end
    XMLHelper.write_file(type_xml, this_dir + '/element_type.xml')
  end

  def self.generate_xpath_array_from_requirement_hash(ep_validator_requirements)
    xpath_array = []
    ep_validator_requirements.each do |parent, requirement|
      if parent.nil? # Unconditional
        requirement.each do |child, expected_sizes|
          count += 1
          xpath = combine_into_xpath(parent, child)
          xpath.gsub(/(?<reg>(\[([^\]\[]|\g<reg>)*\]))/, '').split(/ [|,or] /).each do |el_path|
            xpath_array << el_path
          end
        end
      else # Conditional based on parent element existence
        parent.gsub(/(?<reg>(\[([^\]\[]|\g<reg>)*\]))/, '').split(/ [|,or] /).each do |parent_path|
          requirement.each do |child, expected_sizes|
            child.gsub(/(?<reg>(\[([^\]\[]|\g<reg>)*\]))/, '').split(/ [|,or] /).each do |child_path|
              count += 1
              el_path = combine_into_xpath(parent_path, child_path)
              next if el_path == parent_path
              xpath_array << el_path
            end
          end
        end
      end
    end
  end

  def self.load_or_get_data_type_xsd(el_array, type_xml, doc_base)
    # get element data type from BaseElements.xsd using path

    # return @type_map[el_array] if not @type_map[el_array].nil?
    puts ''
    puts '----New element validation required!----'

    parent_type = nil
    parent_name = nil

    el_array.each_with_index do |el_name, i|
      next if i < 2
      return type_xml if el_name == 'extension'
      if i == 2
        parent_node = type_xml.root
      else
        parent_node = type_xml.elements['//' + el_array.drop(2).take(i - 2).join('/')]
      end
      puts parent_node
      if not parent_node.nil?
        child_node = type_xml.elements['//' + el_array.drop(2).take(i - 1).join('/')]
        if not child_node.nil?
          parent_type = child_node.attributes['DataType']
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
        el_type = doc_base.elements["//xs:element[@name='#{el_name}']"].attributes['type']
      else
        if (not parent_name.nil?) && parent_type.nil?
          el = doc_base.elements["//xs:element[@name='#{parent_name}']//xs:element[@name='#{el_name}']"]
          if el.nil?
            group_name = doc_base.elements["//xs:element[@name='#{parent_name}']//xs:group"].attributes['ref']
          end
          while el.nil? do
            puts group_name
            el = doc_base.elements["//xs:group[@name='#{group_name}']//xs:element[@name='#{el_name}']"]
            group_name = doc_base.elements["//xs:group[@name='#{group_name}']//xs:group"].attributes['ref'] if el.nil?
          end
        else
          el = doc_base.elements["//xs:complexType[@name='#{parent_type}']//xs:element[@name='#{el_name}']"]
          while el.nil? do
            # this approach can only have one group or one base
            group = doc_base.elements["//xs:complexType[@name='#{parent_type}']//xs:group"]
            base = doc_base.elements["//xs:complexType[@name='#{parent_type}']//xs:extension"]
            if (not base.nil?) && group.nil?
              base_name = base.attributes['base']
              el = doc_base.elements["//xs:complexType[@name='#{base_name}']//xs:element[@name='#{el_name}']"]
              parent_type = base_name
            elsif not group.nil?
              group_name = group.attributes['ref']
              el = doc_base.elements["//xs:group[@name='#{group_name}']//xs:element[@name='#{el_name}']"] unless doc_base.elements["//xs:complexType[@name='#{parent_type}']//xs:group"].nil?
            else
              break
            end
          end
        end
        el_type = el.attributes['type']
      end
      if not el_type.nil?
        el = XMLHelper.add_element(parent_node, el_name)
        XMLHelper.add_attribute(el, 'DataType', el_type)
      else
        el = XMLHelper.add_element(parent_node, el_name)
      end
      parent_type = el_type
      parent_name = el_name
    end

    return type_xml
  end

  def self.combine_into_xpath(parent, child)
    if parent.nil?
      return child
    elsif child.start_with?('[')
      return [parent, child].join('')
    end

    return [parent, child].join('/')
  end

  def self.get_complex_type_name(doc_data, simple_type_name)
    complex_type = doc_data.elements["//xs:complexType[xs:simpleContent[xs:extension[@base='#{simple_type_name}']]]"]
    if complex_type.nil?
      return simple_type_name
    else
      return complex_type.attributes['name']
    end
  end

  def self.get_datatype_requirement()
    # get enums, min/max values from HPXMLDataTypes.xsd
    this_dir = File.dirname(__FILE__)
    dt_type_xsd_path = this_dir + '/HPXMLDataTypes.xsd'
    doc_data = XMLHelper.parse_file(dt_type_xsd_path)

    req_xml = XMLHelper.create_doc(version = '1.0', encoding = 'UTF-8')
    req_root = XMLHelper.add_element(req_xml, 'DataTypeRequirementMap')

    get_individual_requirement(doc_data, 'enumeration', req_root)
    get_individual_requirement(doc_data, 'minInclusive', req_root)
    get_individual_requirement(doc_data, 'minExclusive', req_root)
    get_individual_requirement(doc_data, 'maxInclusive', req_root)
    get_individual_requirement(doc_data, 'maxExclusive', req_root)

    XMLHelper.write_file(req_xml, this_dir + '/type_requiment.xml')
  end

  def self.get_individual_requirement(doc_data, req_name, req_root)
    doc_data.elements.to_a("//xs:#{req_name}").each do |req_el|
      simple_type_name = req_el.parent.parent.attributes['name']
      complex_type_name = get_complex_type_name(doc_data, simple_type_name)
      complex_type_el = req_root.elements["//#{complex_type_name}"]
      if complex_type_el.nil?
        complex_type_el = XMLHelper.add_element(req_root, complex_type_name)
      end
      if not req_el.attributes['value'].nil?
        XMLHelper.add_element(complex_type_el, req_name, req_el.attributes['value'])
      end
    end
  end
end

HPXMLValidator.get_data_type_mapping_xml()
