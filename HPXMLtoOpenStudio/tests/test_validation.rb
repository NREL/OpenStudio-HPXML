# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'
require 'schematron-nokogiri'

class HPXMLtoOpenStudioSchematronTest < MiniTest::Test
  def before_setup
    @root_path = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
    @tmp_output_path = File.join(@root_path, 'workflow', 'sample_files', 'tmp_output')
    FileUtils.mkdir_p(@tmp_output_path)
    @tmp_hpxml_path = File.join(@tmp_output_path, 'tmp.xml')
  end
  
  def after_teardown
    FileUtils.rm_rf(@tmp_output_path)
  end

  def test_valid_sample_files
    sample_files_dir = File.absolute_path(File.join(@root_path, 'workflow', 'sample_files'))
    hpxmls = []
    Dir["#{sample_files_dir}/*.xml"].sort.each do |xml|
      hpxmls << File.absolute_path(xml)
    end
    hpxmls.each do |hpxml|
      _test_schematron_validation(hpxml)
    end
  end

  def test_invalid_files_schematron_validation
    # TODO: Need to add more test cases
    expected_error_msgs = { '/HPXML/XMLTransactionHeaderInformation/XMLType' => "element 'XMLTransactionHeaderInformation/XMLType' is REQUIRED",
                            '/HPXML/XMLTransactionHeaderInformation/XMLGeneratedBy' => "element 'XMLTransactionHeaderInformation/XMLGeneratedBy' is REQUIRED",
                            '/HPXML/XMLTransactionHeaderInformation/CreatedDateAndTime' => "element 'XMLTransactionHeaderInformation/CreatedDateAndTime' is REQUIRED",
                            '/HPXML/XMLTransactionHeaderInformation/Transaction' => "element 'XMLTransactionHeaderInformation/Transaction' is REQUIRED",
                            '/HPXML/Building' => "element 'HPXML/Building' is REQUIRED",
                            '/HPXML/Building/BuildingID' => "element 'HPXML/Building/BuildingID' is REQUIRED",
                            '/HPXML/Building/ProjectStatus/EventType' => "element 'HPXML/Building/ProjectStatus/EventType' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction' => "element 'BuildingSummary/BuildingConstruction' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation' => "element 'ClimateandRiskZones/WeatherStation' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/HousePressure' => "Air leakage must be provided in one of three ways: (a) nACH (natural air changes per hour), (b) ACH50 (air changes per hour at 50Pa), or (c) CFM50 (cubic feet per minute at 50Pa)",
                            '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/BuildingAirLeakage/UnitofMeasure' => "Air leakage must be provided in one of three ways: (a) nACH (natural air changes per hour), (b) ACH50 (air changes per hour at 50Pa), or (c) CFM50 (cubic feet per minute at 50Pa)",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall' => "the number of element 'Enclosure/Walls/Wall' MUST be greater than or equal to 1",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloors' => "element 'BuildingConstruction/NumberofConditionedFloors' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloorsAboveGrade' => "element 'BuildingConstruction/NumberofConditionedFloorsAboveGrade' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofBedrooms' => "element 'BuildingConstruction/NumberofBedrooms' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedFloorArea' => "element 'BuildingConstruction/ConditionedFloorArea' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedBuildingVolume' => "either element 'BuildingConstruction/ConditionedBuildingVolume' or element 'BuildingConstruction/AverageCeilingHeight' must be provided",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding' => "element 'Neighbors/NeighborBuilding' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding/Azimuth' => "element 'NeighborBuilding/Azimuth' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding/Distance' => "element 'NeighborBuilding/Distance' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC/Year' => "element 'ClimateZoneIECC/Year' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC/ClimateZone' => "element 'ClimateZoneIECC/ClimateZone' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/SystemIdentifier' => "element 'WeatherStation/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/Name' => "element 'WeatherStation/Name' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/WMO' => "either element 'WeatherStation/WMO' or element 'WeatherStation/extension/EPWFilePath' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[number(HousePressure)=50 and BuildingAirLeakage/UnitofMeasure[text()="ACH" or text()="CFM"]]/SystemIdentifier' => "element 'AirInfiltrationMeasurement/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[number(HousePressure)=50 and BuildingAirLeakage/UnitofMeasure[text()="ACH" or text()="CFM"]]/BuildingAirLeakage/AirLeakage' => "element 'AirInfiltrationMeasurement/BuildingAirLeakage/AirLeakage' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/SystemIdentifier' => "element 'Roof/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/InteriorAdjacentTo' => "element 'Roof/InteriorAdjacentTo' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Area' => "element 'Roof/Area' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/SolarAbsorptance' => "element 'Roof/SolarAbsorptance' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Emittance' => "element 'Roof/Emittance' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Pitch' => "element 'Roof/Pitch' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/RadiantBarrier' => "element 'Roof/RadiantBarrier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Insulation/SystemIdentifier' => "element 'Roof/Insulation/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Insulation/AssemblyEffectiveRValue' => "element 'Roof/Insulation/AssemblyEffectiveRValue' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/SystemIdentifier' => "element 'Wall/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/ExteriorAdjacentTo' => "element 'Wall/ExteriorAdjacentTo' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/InteriorAdjacentTo' => "element 'Wall/InteriorAdjacentTo' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/WoodStud' => "element 'Wall/WallType' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Area' => "element 'Wall/Area' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/SolarAbsorptance' => "element 'Wall/SolarAbsorptance' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Emittance' => "element 'Wall/Emittance' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Insulation/SystemIdentifier' => "element 'Wall/Insulation/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Insulation/AssemblyEffectiveRValue' => "element 'Wall/Insulation/AssemblyEffectiveRValue' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/SystemIdentifier' => "element 'RimJoist/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/ExteriorAdjacentTo' => "element 'RimJoist/ExteriorAdjacentTo' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/InteriorAdjacentTo' => "element 'RimJoist/InteriorAdjacentTo' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Area' => "element 'RimJoist/Area' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/SolarAbsorptance' => "element 'RimJoist/SolarAbsorptance' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Emittance' => "element 'RimJoist/Emittance' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Insulation/SystemIdentifier' => "element 'RimJoist/Insulation/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Insulation/AssemblyEffectiveRValue' => "element 'RimJoist/Insulation/AssemblyEffectiveRValue' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/SystemIdentifier' => "element 'FoundationWall/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/ExteriorAdjacentTo' => "element 'FoundationWall/ExteriorAdjacentTo' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/InteriorAdjacentTo' => "element 'FoundationWall/InteriorAdjacentTo' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Height' => "element 'FoundationWall/Height' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Area' => "element 'FoundationWall/Area' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Thickness' => "element 'FoundationWall/Thickness' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/DepthBelowGrade' => "element 'FoundationWall/DepthBelowGrade' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/SystemIdentifier' => "element 'FoundationWall/Insulation/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - interior"]' => "element 'FoundationWall/Insulation/Layer[InstallationType='continuous - interior']' or 'FoundationWall/Insulation/AssemblyEffectiveRValue' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - exterior"]' => "element 'FoundationWall/Insulation/Layer[InstallationType='continuous - exterior']' or 'FoundationWall/Insulation/AssemblyEffectiveRValue' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - interior"]/NominalRValue' => "element 'Layer/NominalRValue' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - interior"]/extension/DistanceToTopOfInsulation' => "element 'Layer/extension/DistanceToTopOfInsulation' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - interior"]/extension/DistanceToBottomOfInsulation' => "element 'Layer/extension/DistanceToBottomOfInsulation' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - exterior"]/NominalRValue' => "element 'Layer/NominalRValue' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - exterior"]/extension/DistanceToTopOfInsulation' => "element 'Layer/extension/DistanceToTopOfInsulation' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - exterior"]/extension/DistanceToBottomOfInsulation' => "element 'Layer/extension/DistanceToBottomOfInsulation' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/SystemIdentifier' => "element 'FrameFloor/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/ExteriorAdjacentTo' => "element 'FrameFloor/ExteriorAdjacentTo' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/InteriorAdjacentTo' => "element 'FrameFloor/InteriorAdjacentTo' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/Area' => "element 'FrameFloor/Area' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/Insulation/SystemIdentifier' => "element 'FrameFloor/Insulation/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/Insulation/AssemblyEffectiveRValue' => "element 'FrameFloor/Insulation/AssemblyEffectiveRValue' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor[ExteriorAdjacentTo[text()="other housing unit"]]/extension/OtherSpaceAboveOrBelow' => "element 'FrameFloor/extension/OtherSpaceAboveOrBelow' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/SystemIdentifier' => "element 'Slab/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/InteriorAdjacentTo' => "element 'Slab/InteriorAdjacentTo' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/Area' => "element 'Slab/Area' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/Thickness' => "element 'Slab/Thickness' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/ExposedPerimeter' => "element 'Slab/ExposedPerimeter' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/PerimeterInsulationDepth' => "element 'Slab/PerimeterInsulationDepth' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulationWidth' => "element 'Slab/UnderSlabInsulationWidth' or 'Slab/UnderSlabInsulationSpansEntireSlab[text()=\"true\"]' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/PerimeterInsulation/SystemIdentifier' => "element 'Slab/PerimeterInsulation/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/PerimeterInsulation/Layer[InstallationType="continuous"]/NominalRValue' => "element 'Slab/PerimeterInsulation/Layer[InstallationType=\"continuous\"]/NominalRValue' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulation/SystemIdentifier' => "element 'Slab/UnderSlabInsulation/SystemIdentifier' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulation/Layer[InstallationType="continuous"]/NominalRValue' => "element 'Slab/UnderSlabInsulation/Layer[InstallationType=\"continuous\"]/NominalRValue' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/extension/CarpetFraction' => "element 'Slab/extension/CarpetFraction' is REQUIRED",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/extension/CarpetRValue' => "element 'Slab/extension/CarpetRValue' is REQUIRED",
                          }
    
    expected_error_msgs.each do |key, value|
      if ['/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding',
          '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding/Azimuth',
          '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding/Distance'].include? key
        hpxml_name = 'base-misc-neighbor-shading.xml'
      elsif key == '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor[ExteriorAdjacentTo[text()="other housing unit"]]/extension/OtherSpaceAboveOrBelow'
        hpxml_name = 'base-enclosure-other-housing-unit.xml'
      else
        hpxml_name = 'base.xml'
      end
      
      hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
      hpxml_doc = hpxml.to_oga()
      XMLHelper.delete_element(hpxml_doc, key)
      XMLHelper.write_file(hpxml_doc, @tmp_hpxml_path)
      _test_schematron_validation(@tmp_hpxml_path, value)
    end
  end

  def test_invalid_files_validator_validation
    # TODO: Need to add more test cases
    expected_error_msgs = { '/HPXML/XMLTransactionHeaderInformation/XMLType' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/XMLTransactionHeaderInformation/XMLType",
                            '/HPXML/XMLTransactionHeaderInformation/XMLGeneratedBy' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/XMLTransactionHeaderInformation/XMLGeneratedBy",
                            '/HPXML/XMLTransactionHeaderInformation/CreatedDateAndTime' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/XMLTransactionHeaderInformation/CreatedDateAndTime",
                            '/HPXML/XMLTransactionHeaderInformation/Transaction' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/XMLTransactionHeaderInformation/Transaction",
                            '/HPXML/Building' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building",
                            '/HPXML/Building/BuildingID' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingID",
                            '/HPXML/Building/ProjectStatus/EventType' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/ProjectStatus/EventType",
                            '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation",
                            '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/HousePressure' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[number(HousePressure)=50 and BuildingAirLeakage/UnitofMeasure[text()=\"ACH\" or text()=\"CFM\"]] | /HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[BuildingAirLeakage/UnitofMeasure[text()=\"ACHnatural\"]]",
                            '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/BuildingAirLeakage/UnitofMeasure' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[number(HousePressure)=50 and BuildingAirLeakage/UnitofMeasure[text()=\"ACH\" or text()=\"CFM\"]] | /HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[BuildingAirLeakage/UnitofMeasure[text()=\"ACHnatural\"]]",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall' => "Expected 1 or more element(s) but found 0 elements for xpath: /HPXML/Building/BuildingDetails/Enclosure/Walls/Wall",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloors' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction: NumberofConditionedFloors",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloorsAboveGrade' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction: NumberofConditionedFloorsAboveGrade",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofBedrooms' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction: NumberofBedrooms",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedFloorArea' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction: ConditionedFloorArea",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedBuildingVolume' => "Expected 1 or more element(s) but found 0 elements for xpath: /HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction: ConditionedBuildingVolume | AverageCeilingHeight",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding' => "Expected 1 or more element(s) but found 0 elements for xpath: /HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors: NeighborBuilding",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding/Azimuth' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding: Azimuth",
                            '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding/Distance' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding: Distance",
                            '/HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC/Year' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC: Year",
                            '/HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC/ClimateZone' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC: ClimateZone[text()=\"1A\" or text()=\"1B\" or text()=\"1C\" or text()=\"2A\" or text()=\"2B\" or text()=\"2C\" or text()=\"3A\" or text()=\"3B\" or text()=\"3C\" or text()=\"4A\" or text()=\"4B\" or text()=\"4C\" or text()=\"5A\" or text()=\"5B\" or text()=\"5C\" or text()=\"6A\" or text()=\"6B\" or text()=\"6C\" or text()=\"7\" or text()=\"8\"]",
                            '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation: SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/Name' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation: Name",
                            '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation/WMO' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation: WMO | extension/EPWFilePath",
                            '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[number(HousePressure)=50 and BuildingAirLeakage/UnitofMeasure[text()="ACH" or text()="CFM"]]/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[number(HousePressure)=50 and BuildingAirLeakage/UnitofMeasure[text()=\"ACH\" or text()=\"CFM\"]] | /HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[BuildingAirLeakage/UnitofMeasure[text()=\"ACHnatural\"]]: SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[number(HousePressure)=50 and BuildingAirLeakage/UnitofMeasure[text()="ACH" or text()="CFM"]]/BuildingAirLeakage/AirLeakage' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[number(HousePressure)=50 and BuildingAirLeakage/UnitofMeasure[text()=\"ACH\" or text()=\"CFM\"]] | /HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[BuildingAirLeakage/UnitofMeasure[text()=\"ACHnatural\"]]: BuildingAirLeakage/AirLeakage",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof: SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/InteriorAdjacentTo' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof: InteriorAdjacentTo[text()=\"attic - vented\" or text()=\"attic - unvented\" or text()=\"living space\" or text()=\"garage\"]",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Area' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof: Area",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/SolarAbsorptance' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof: SolarAbsorptance",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Emittance' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof: Emittance",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Pitch' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof: Pitch",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/RadiantBarrier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof: RadiantBarrier",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Insulation/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof: Insulation/SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/Insulation/AssemblyEffectiveRValue' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof: Insulation/AssemblyEffectiveRValue",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Walls/Wall: SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/ExteriorAdjacentTo' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Walls/Wall: ExteriorAdjacentTo[text()=\"outside\" or text()=\"attic - vented\" or text()=\"attic - unvented\" or text()=\"basement - conditioned\" or text()=\"basement - unconditioned\" or text()=\"crawlspace - vented\" or text()=\"crawlspace - unvented\" or text()=\"garage\" or text()=\"other housing unit\" or text()=\"other heated space\" or text()=\"other multifamily buffer space\" or text()=\"other non-freezing space\"]",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/InteriorAdjacentTo' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Walls/Wall: InteriorAdjacentTo[text()=\"living space\" or text()=\"attic - vented\" or text()=\"attic - unvented\" or text()=\"basement - conditioned\" or text()=\"basement - unconditioned\" or text()=\"crawlspace - vented\" or text()=\"crawlspace - unvented\" or text()=\"garage\"]",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/WallType/WoodStud' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Walls/Wall: WallType[WoodStud | DoubleWoodStud | ConcreteMasonryUnit | StructurallyInsulatedPanel | InsulatedConcreteForms | SteelFrame | SolidConcrete | StructuralBrick | StrawBale | Stone | LogWall]",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Area' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Walls/Wall: Area",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/SolarAbsorptance' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Walls/Wall: SolarAbsorptance",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Emittance' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Walls/Wall: Emittance",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Insulation/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Walls/Wall: Insulation/SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Insulation/AssemblyEffectiveRValue' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Walls/Wall: Insulation/AssemblyEffectiveRValue",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist: SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/ExteriorAdjacentTo' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist: ExteriorAdjacentTo[text()=\"outside\" or text()=\"attic - vented\" or text()=\"attic - unvented\" or text()=\"basement - conditioned\" or text()=\"basement - unconditioned\" or text()=\"crawlspace - vented\" or text()=\"crawlspace - unvented\" or text()=\"garage\" or text()=\"other housing unit\" or text()=\"other heated space\" or text()=\"other multifamily buffer space\" or text()=\"other non-freezing space\"]",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/InteriorAdjacentTo' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist: InteriorAdjacentTo[text()=\"living space\" or text()=\"attic - vented\" or text()=\"attic - unvented\" or text()=\"basement - conditioned\" or text()=\"basement - unconditioned\" or text()=\"crawlspace - vented\" or text()=\"crawlspace - unvented\" or text()=\"garage\"]",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Area' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist: Area",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/SolarAbsorptance' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist: SolarAbsorptance",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Emittance' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist: Emittance",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Insulation/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist: Insulation/SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist/Insulation/AssemblyEffectiveRValue' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist: Insulation/AssemblyEffectiveRValue",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall: SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/ExteriorAdjacentTo' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall: ExteriorAdjacentTo[text()=\"ground\" or text()=\"basement - conditioned\" or text()=\"basement - unconditioned\" or text()=\"crawlspace - vented\" or text()=\"crawlspace - unvented\" or text()=\"garage\" or text()=\"other housing unit\" or text()=\"other heated space\" or text()=\"other multifamily buffer space\" or text()=\"other non-freezing space\"]",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/InteriorAdjacentTo' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall: InteriorAdjacentTo[text()=\"basement - conditioned\" or text()=\"basement - unconditioned\" or text()=\"crawlspace - vented\" or text()=\"crawlspace - unvented\" or text()=\"garage\"]",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Height' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall: Height",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Area' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall: Area",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Thickness' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall: Thickness",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/DepthBelowGrade' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall: DepthBelowGrade",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall: Insulation/SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - interior"]' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall: Insulation/Layer[InstallationType=\"continuous - interior\"] | Insulation/AssemblyEffectiveRValue",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - exterior"]' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall: Insulation/Layer[InstallationType=\"continuous - exterior\"] | Insulation/AssemblyEffectiveRValue",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - interior"]/NominalRValue' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType=\"continuous - exterior\" or InstallationType=\"continuous - interior\"]: NominalRValue",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - interior"]/extension/DistanceToTopOfInsulation' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType=\"continuous - exterior\" or InstallationType=\"continuous - interior\"]: extension/DistanceToTopOfInsulation",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - interior"]/extension/DistanceToBottomOfInsulation' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType=\"continuous - exterior\" or InstallationType=\"continuous - interior\"]: extension/DistanceToBottomOfInsulation",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - exterior"]/NominalRValue' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType=\"continuous - exterior\" or InstallationType=\"continuous - interior\"]: NominalRValue",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - exterior"]/extension/DistanceToTopOfInsulation' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType=\"continuous - exterior\" or InstallationType=\"continuous - interior\"]: extension/DistanceToTopOfInsulation",
                            '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - exterior"]/extension/DistanceToBottomOfInsulation' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType=\"continuous - exterior\" or InstallationType=\"continuous - interior\"]: extension/DistanceToBottomOfInsulation",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor: SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/ExteriorAdjacentTo' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor: ExteriorAdjacentTo[text()=\"outside\" or text()=\"attic - vented\" or text()=\"attic - unvented\" or text()=\"basement - conditioned\" or text()=\"basement - unconditioned\" or text()=\"crawlspace - vented\" or text()=\"crawlspace - unvented\" or text()=\"garage\" or text()=\"other housing unit\" or text()=\"other heated space\" or text()=\"other multifamily buffer space\" or text()=\"other non-freezing space\"]",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/InteriorAdjacentTo' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor: InteriorAdjacentTo[text()=\"living space\" or text()=\"attic - vented\" or text()=\"attic - unvented\" or text()=\"basement - conditioned\" or text()=\"basement - unconditioned\" or text()=\"crawlspace - vented\" or text()=\"crawlspace - unvented\" or text()=\"garage\"]",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/Area' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor: Area",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/Insulation/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor: Insulation/SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor/Insulation/AssemblyEffectiveRValue' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor: Insulation/AssemblyEffectiveRValue",
                            '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor[ExteriorAdjacentTo[text()="other housing unit"]]/extension/OtherSpaceAboveOrBelow' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor[ExteriorAdjacentTo[text()=\"other housing unit\" or text()=\"other heated space\" or text()=\"other multifamily buffer space\" or text()=\"other non-freezing space\"]]: extension/OtherSpaceAboveOrBelow[text()=\"above\" or text()=\"below\"]",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/InteriorAdjacentTo' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: InteriorAdjacentTo[text()=\"living space\" or text()=\"basement - conditioned\" or text()=\"basement - unconditioned\" or text()=\"crawlspace - vented\" or text()=\"crawlspace - unvented\" or text()=\"garage\"]",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/Area' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: Area",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/Thickness' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: Thickness",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/ExposedPerimeter' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: ExposedPerimeter",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/PerimeterInsulationDepth' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: PerimeterInsulationDepth",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulationWidth' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: UnderSlabInsulationWidth | UnderSlabInsulationSpansEntireSlab[text()=\"true\"]",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/PerimeterInsulation/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: PerimeterInsulation/SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/PerimeterInsulation/Layer[InstallationType="continuous"]/NominalRValue' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: PerimeterInsulation/Layer[InstallationType=\"continuous\"]/NominalRValue",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulation/SystemIdentifier' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: UnderSlabInsulation/SystemIdentifier",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulation/Layer[InstallationType="continuous"]/NominalRValue' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: UnderSlabInsulation/Layer[InstallationType=\"continuous\"]/NominalRValue",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/extension/CarpetFraction' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: extension/CarpetFraction",
                            '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/extension/CarpetRValue' => "Expected [1] element(s) but found 0 element(s) for xpath: /HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab: extension/CarpetRValue",
                          }
    
    expected_error_msgs.each do |key, value|
      if ['/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding',
          '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding/Azimuth',
          '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding/Distance'].include? key
        hpxml_name = 'base-misc-neighbor-shading.xml'
      elsif key == '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor[ExteriorAdjacentTo[text()="other housing unit"]]/extension/OtherSpaceAboveOrBelow'
        hpxml_name = 'base-enclosure-other-housing-unit.xml'
      else
        hpxml_name = 'base.xml'
      end
      
      hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
      hpxml_doc = hpxml.to_oga()
      XMLHelper.delete_element(hpxml_doc, key)
      XMLHelper.write_file(hpxml_doc, @tmp_hpxml_path)
      _test_ruby_validation(hpxml_doc, value)
    end
  end

  def _test_schematron_validation(hpxml_path, expected_error_msgs = nil)
    # load the schematron xml
    stron_doc = Nokogiri::XML File.open(File.join(@root_path, 'HPXMLtoOpenStudio', 'resources', 'EPvalidator.xml'))  # "/path/to/schema.stron"
    # make a schematron object
    stron = SchematronNokogiri::Schema.new stron_doc
    # load the xml document you wish to validate
    xml_doc = Nokogiri::XML File.open(hpxml_path)  # "/path/to/xml_document.xml"
    # validate it
    results = stron.validate xml_doc
    # assertions
    if results.empty?
      assert_empty(results)
    else
      assert_equal(expected_error_msgs, results[0][:message])
    end
  end

  def _test_ruby_validation(hpxml_doc, expected_error_msgs = nil)
    # Validate input HPXML against EnergyPlus Use Case
    results = EnergyPlusValidator.run_validator(hpxml_doc)
    if results.empty?
      assert_empty(results)
    else
      assert_equal(expected_error_msgs, results[0])
    end
  end
end