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
    puts "Testing #{hpxmls.size} HPXML files..."
    hpxmls.each do |hpxml_path|
      print '.'

      # .rb validator validation
      hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', File.basename(hpxml_path)))
      hpxml_doc = hpxml.to_oga()
      _test_ruby_validation(hpxml_doc)
      # Schematron validation
      _test_schematron_validation(hpxml_path)
    end

    puts
  end

  def test_invalid_files
    # build up expected error messages hashes by parsing EPvalidator.xml
    stron_xml_epvalidator = File.join(@root_path, 'HPXMLtoOpenStudio', 'resources', 'EPvalidator.xml')
    doc = XMLHelper.parse_file(stron_xml_epvalidator)
    expected_error_msgs_by_element_addition = {}
    expected_error_msgs_by_element_deletion = {}
    XMLHelper.get_elements(doc, '/sch:schema/sch:pattern').each do |pattern|
      XMLHelper.get_elements(pattern, 'sch:rule').each do |rule|
        rule_context = XMLHelper.get_attribute_value(rule, 'context')

        next if rule_context.include?('Other="DSE"') # FIXME: Need to add this test case.  Will need to remove both AnnualHeatingDistributionSystemEfficiency and AnnualCoolingDistributionSystemEfficiency for testing

        # ['/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution[DistributionSystemType[Other="DSE"]]/AnnualHeatingDistributionSystemEfficiency', '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution[DistributionSystemType[Other="DSE"]]/AnnualCoolingDistributionSystemEfficiency'] => 'Expected 1 or more element(s) for xpath: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution[DistributionSystemType[Other="DSE"]]/AnnualHeatingDistributionSystemEfficiency | AnnualCoolingDistributionSystemEfficiency'

        XMLHelper.get_values(rule, 'sch:assert').each do |assertion|
          target_xpath, expected_error_message = get_target_xpath_and_expected_error_message(rule_context, assertion)

          if assertion.start_with?('Expected 0') || assertion.partition(': ').last.start_with?('[not')
            next if assertion.start_with?('Expected 0 or more') # no tests needed

            expected_error_msgs_by_element_addition[target_xpath] = expected_error_message
          else
            expected_error_msgs_by_element_deletion[target_xpath] = expected_error_message
          end
        end
      end
    end

    # Tests by element deletion
    expected_error_msgs_by_element_deletion.each do |key, value|
      hpxml_name = get_hpxml_file_name(key)
      hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
      hpxml_doc = hpxml.to_oga()
      XMLHelper.delete_element(hpxml_doc, key)
      XMLHelper.write_file(hpxml_doc, @tmp_hpxml_path)

      # .rb validator validation
      _test_ruby_validation(hpxml_doc, value)
      # schematron validation
      _test_schematron_validation(@tmp_hpxml_path, value)
    end

    # Tests by element addition (i.e. zero_or_one, zero_or_two, etc.)
    expected_error_msgs_by_element_addition.each do |key, value|
      print '.'
      hpxml_name = get_hpxml_file_name(key)
      elements, child_elements_with_values = get_parent_and_element_with_value(key)
      hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
      hpxml_doc = hpxml.to_oga()
      # create the child element twice
      XMLHelper.create_elements_as_needed(hpxml_doc, elements.gsub(/\[.*?\]/, '').split('/')[1..-1])
      parent = XMLHelper.get_element(hpxml_doc, elements.split('/')[1...-1].join('/'))
      XMLHelper.add_element(parent, elements.gsub(/\[.*?\]/, '').split('/')[-1])

      if not child_elements_with_values.nil?
        child_elements_with_values.split(' and ')
        XMLHelper.get_elements(parent, elements.split('/')[-1]).each do |e|
          child_elements_with_values.split(' and ').each do |element_with_value|
            unless XMLHelper.has_element(e, element_with_value.split('=')[0]) && (XMLHelper.get_value(e, element_with_value.split('=')[0]) == element_with_value.split('=')[1].gsub!(/\A"|"\Z/, ''))
              XMLHelper.add_element(e, element_with_value.split('=')[0], element_with_value.split('=')[1].gsub!(/\A"|"\Z/, ''))
            end
          end
        end
      end
      XMLHelper.write_file(hpxml_doc, @tmp_hpxml_path)

      # .rb validator validation
      _test_ruby_validation(hpxml_doc, value)
      # schematron validation
      _test_schematron_validation(@tmp_hpxml_path, value)
    end

    puts
  end

  def _test_schematron_validation(hpxml_path, expected_error_msgs = nil)
    # load the schematron xml
    stron_doc = Nokogiri::XML File.open(File.join(@root_path, 'HPXMLtoOpenStudio', 'resources', 'EPvalidator.xml'))
    # make a schematron object
    stron = SchematronNokogiri::Schema.new stron_doc
    # load the xml document you wish to validate
    xml_doc = Nokogiri::XML File.open(hpxml_path)
    # validate it
    results = stron.validate xml_doc
    # assertions
    if expected_error_msgs.nil?
      assert_empty(results)
    else
      idx_of_interest = results.index { |i| i[:message].gsub(': ', [' for xpath:', i[:context_path].gsub('h:', '').concat(': ').gsub('/*: ', '')].join(' ')) == expected_error_msgs }
      actual_error_msgs = results[idx_of_interest][:message].gsub(': ', [' for xpath:', results[idx_of_interest][:context_path].gsub('h:', '').concat(': ').gsub('/*: ', '')].join(' '))
      assert_equal(expected_error_msgs, actual_error_msgs)
    end
  end

  def _test_ruby_validation(hpxml_doc, expected_error_msgs = nil)
    # Validate input HPXML against EnergyPlus Use Case
    results = EnergyPlusValidator.run_validator(hpxml_doc)
    if expected_error_msgs.nil?
      assert_empty(results)
    else
      idx_of_interest = results.index { |i| i == expected_error_msgs }
      assert_equal(expected_error_msgs, results[idx_of_interest])
    end
  end

  def get_hpxml_file_name(key)
    if key.include? '/HPXML/Building/BuildingDetails/Appliances/Dehumidifier'
      return 'base-appliances-dehumidifier.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors'
      return 'base-misc-neighbor-shading.xml'
    elsif key.include? '/HPXML/SoftwareInfo/extension/SimulationControl/DaylightSaving'
      return 'base-simcontrol-daylight-saving-custom.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor[ExteriorAdjacentTo[text()="other housing unit" or text()="other heated space" or text()="other multifamily buffer space" or text()="other non-freezing space"]]/extension/OtherSpaceAboveOrBelow'
      return 'base-enclosure-other-housing-unit.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Enclosure/Foundations'
      return 'base-foundation-vented-crawlspace.xml'
    elsif ['/HPXML/Building/BuildingDetails/Enclosure/Attics',
           '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof[InteriorAdjacentTo="attic - vented"]'].any? { |i| key.include? i }
      return 'base-atticroof-vented.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall[InteriorAdjacentTo="crawlspace - vented"]'
      return 'base-foundation-vented-crawlspace.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/DepthBelowGrade'
      return 'base-foundation-slab.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulationWidth'
      return 'base-foundation-conditioned-basement-slab-insulation.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Lighting/CeilingFan'
      return 'base-misc-ceiling-fans.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/ElectricResistance]'
      return 'base-hvac-elec-resistance-only.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/WallFurnace]'
      return 'base-hvac-wall-furnace-elec-only.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/FloorFurnace]'
      return 'base-hvac-floor-furnace-propane-only.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/Boiler]'
      return 'base-hvac-boiler-gas-only.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/Stove]'
      return 'base-hvac-stove-oil-only.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/PortableHeater]'
      return 'base-hvac-portable-heater-electric-only.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/FixedHeater]'
      return 'base-hvac-fixed-heater-electric-only.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/Fireplace]'
      return 'base-hvac-fireplace-wood-only.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl'
      return 'base-hvac-programmable-thermostat.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution[DistributionSystemType[Other="DSE"]]'
      return 'base-hvac-dse.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[CoolingSystemType="room air conditioner"]'
      return 'base-hvac-room-ac-only.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[CoolingSystemType="evaporative cooler"]'
      return 'base-hvac-evap-cooler-furnace-gas.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[CoolingSystemType="mini-split"]'
      return 'base-hvac-mini-split-air-conditioner-only-ducted.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[HeatPumpType="mini-split"]'
      return 'base-hvac-mini-split-heat-pump-ducted.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[HeatPumpType="ground-to-air"]'
      return 'base-hvac-ground-to-air-heat-pump.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[BackupSystemFuel]'
      return 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml'
    elsif ['/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump',
           '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[HeatPumpType="air-to-air"]'].any? { |i| key.include? i }
      return 'base-hvac-air-to-air-heat-pump-1-speed.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true"]'
      return 'base-mechvent-balanced.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true" and FanType="heat recovery ventilator"]'
      return 'base-mechvent-hrv.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true" and FanType="energy recovery ventilator"]'
      return 'base-mechvent-erv.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true" and FanType="central fan integrated supply"]'
      return 'base-mechvent-cfis.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForSeasonalCoolingLoadReduction="true"]'
      return 'base-misc-whole-house-fan.xml'
    elsif ['/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForLocalVentilation="true" and FanLocation="kitchen"]',
           '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForLocalVentilation="true" and FanLocation="bath"]'].any? { |i| key.include? i }
      return 'base-mechvent-bath-kitchen-fans.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/Overhangs'
      return 'base-enclosure-overhangs.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight'
      return 'base-enclosure-skylights.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="instantaneous water heater"]'
      return 'base-dhw-tankless-electric.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="heat pump water heater"]'
      return 'base-dhw-tank-heat-pump.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="space-heating boiler with storage tank"]'
      return 'base-dhw-indirect.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="space-heating boiler with tankless coil"]/RelatedHVACSystem'
      return 'base-dhw-combi-tankless.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[UsesDesuperheater="true"]'
      return 'base-dhw-desuperheater.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Recirculation'
      return 'base-dhw-recirc-timer.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/DrainWaterHeatRecovery'
      return 'base-dhw-dwhr.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem[SolarFraction]'
      return 'base-dhw-solar-fraction.xml'
    elsif ['/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem',
           '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem[CollectorArea]'].any? { |i| key.include? i }
      return 'base-dhw-solar-direct-flat-plate.xml'
    elsif key.include? '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem'
      return 'base-pv.xml'
    elsif ['/HPXML/Building/BuildingDetails/Appliances/Freezer', '/HPXML/Building/BuildingDetails/Pools/Pool',
           '/HPXML/Building/BuildingDetails/HotTubs/HotTub', '/HPXML/Building/BuildingDetails/MiscLoads/FuelLoad'].any? { |i| key.include? i }
      return 'base-misc-large-uncommon-loads.xml'
    else
      return 'base.xml'
    end
  end

  def get_target_xpath_and_expected_error_message(rule_context, assertion)
    if rule_context == '/*'
      target_xpath = [rule_context.gsub('h:', '').gsub('/*', ''), assertion.partition(': ').last].join()
      expected_error_message = [[[assertion.partition(': ').first, ' for xpath: '].join(), rule_context.gsub('h:', '').gsub('/*', '')].join(), assertion.partition(': ').last].join()
    else
      if assertion.partition(': ').last.start_with?('[not')
        element_name = assertion.partition(': ').last.partition(' | ').last
      elsif assertion.include?('SolarAbsorptance')
        element_name = 'SolarAbsorptance'
      elsif assertion.include?('WallType')
        element_name = 'WallType[WoodStud]'
      elsif assertion.include?('HeatingSystemType')
        element_name = 'HeatingSystemType[Furnace]'
      elsif assertion.include?('LightEmittingDiode')
        element_name = 'LightingGroup[LightingType[LightEmittingDiode]]'
      elsif assertion.include?('../../HVACDistribution[DistributionSystemType/AirDistribution')
        element_name = '../../HVACDistribution[DistributionSystemType/AirDistribution]'
      elsif assertion.include?('../../HVACDistribution[DistributionSystemType/HydronicDistribution')
        element_name = '../../HVACDistribution[DistributionSystemType/HydronicDistribution]'
      else
        element_name = assertion.partition(': ').last.partition(' | ').first
      end

      if rule_context.gsub('h:', '').include? 'AirInfiltrationMeasurement[number(HousePressure)=50 and BuildingAirLeakage/UnitofMeasure[text()="ACH" or text()="CFM"]]'
        target_xpath = [rule_context.gsub('h:', '').partition(' | ').first, element_name].join('/')
      else
        target_xpath = [rule_context.gsub('h:', ''), element_name].join('/')
      end
      expected_error_message = [[[assertion.partition(': ').first, ' for xpath: '].join(), rule_context.gsub('h:', '')].join(), assertion.partition(': ').last].join(': ')
    end

    return target_xpath, expected_error_message
  end

  def get_parent_and_element_with_value(target_xpath)
    parent = target_xpath
    element_with_value = nil
    # Set up parent xpaths and elements with value as needed for specific tests
    # TODO: Clean this up
    if target_xpath.include?('[PlugLoadType[text()="other"]]')
      parent = target_xpath.sub(/(?<=\[).*(?=\])/) { |s| s.gsub(/\[.*\]/, '') }
      element_with_value = 'PlugLoadType="other"'
    elsif target_xpath.include?('[PlugLoadType[text()="TV other"]]')
      parent = target_xpath.sub(/(?<=\[).*(?=\])/) { |s| s.gsub(/\[.*\]/, '') }
      element_with_value = 'PlugLoadType="TV other"'
    elsif target_xpath.include?('[PlugLoadType[text()="electric vehicle charging"]]')
      parent = target_xpath.sub(/(?<=\[).*(?=\])/) { |s| s.gsub(/\[.*\]/, '') }
      element_with_value = 'PlugLoadType="electric vehicle charging"'
    elsif target_xpath.include?('[PlugLoadType[text()="well pump"]]')
      parent = target_xpath.sub(/(?<=\[).*(?=\])/) { |s| s.gsub(/\[.*\]/, '') }
      element_with_value = 'PlugLoadType="well pump"'
    elsif ['[PlugLoadType="other" or PlugLoadType="TV other" or PlugLoadType="electric vehicle charging" or PlugLoadType="well pump"]/Location[text()="interior" or text()="exterior"]',
           '[FuelLoadType="grill" or FuelLoadType="lighting" or FuelLoadType="fireplace"]/Location[text()="interior" or text()="exterior"]'].any? { |i| target_xpath.include? i }
      parent = target_xpath.gsub(/\[.*?\]/, '').split('/')[0...-1].join('/')
      element_with_value = 'Location="interior" and Location="exterior"'
    elsif target_xpath.include?('[FuelLoadType="grill"]')
      parent = target_xpath.gsub(/\[.*?\]/, '')
      element_with_value = 'FuelLoadType="grill"'
    elsif target_xpath.include?('[FuelLoadType="lighting"]')
      parent = target_xpath.gsub(/\[.*?\]/, '')
      element_with_value = 'FuelLoadType="lighting"'
    elsif target_xpath.include?('[FuelLoadType="fireplace"]')
      parent = target_xpath.gsub(/\[.*?\]/, '')
      element_with_value = 'FuelLoadType="fireplace"'
    elsif ['WaterHeatingSystem/Location', 'ClothesWasher/Location', 'ClothesDryer/Location',
           'Dishwasher/Location', 'Refrigerator/Location', 'Freezer/Location', 'CookingRange/Location'].any? { |i| target_xpath.include? i }
      parent = target_xpath.gsub(/\[.*?\]/, '').split('/')[0...-1].join('/')
      element_with_value = 'Location="living space" and Location="basement - conditioned"'
    elsif target_xpath.include?('SiteType')
      parent = target_xpath.gsub(/\[.*?\]/, '').split('/')[0...-1].join('/')
      element_with_value = 'SiteType="suburban" and SiteType="rural"'
    elsif target_xpath.include?('RoofType')
      parent = target_xpath.gsub(/\[.*?\]/, '').split('/')[0...-1].join('/')
      element_with_value = 'RoofType="slate or tile shingles" and RoofType="asphalt or fiberglass shingles"'
    elsif target_xpath.include?('Siding')
      parent = target_xpath.gsub(/\[.*?\]/, '').split('/')[0...-1].join('/')
      element_with_value = 'Siding="wood siding" and Siding="stucco"'
    elsif target_xpath.include?('HeatPump/BackupSystemFuel') # exclude HeatPump[BackupSystemFuel]
      parent = target_xpath.gsub(/\[.*?\]/, '').split('/')[0...-1].join('/')
      element_with_value = 'BackupSystemFuel="electricity" and BackupSystemFuel="natural gas"'
    elsif target_xpath.include?('CompressorType')
      parent = target_xpath.gsub(/\[.*?\]/, '').split('/')[0...-1].join('/')
      element_with_value = 'CompressorType="single stage" and CompressorType="two stage"'
    elsif target_xpath.include?('SimulationControl/BeginMonth')
      parent = target_xpath.gsub(/\[.*?\]/, '').split('/')[0...-1].join('/')
      element_with_value = 'BeginMonth="1"'
    elsif target_xpath.include?('SimulationControl/EndMonth')
      parent = target_xpath.gsub(/\[.*?\]/, '').split('/')[0...-1].join('/')
      element_with_value = 'EndMonth="12"'
    elsif ['AirInfiltrationMeasurement[number(HousePressure)=50 and BuildingAirLeakage/UnitofMeasure[text()="ACH" or text()="CFM"]]',
           'Attics/Attic[AtticType/Attic[Vented="true"]]/VentilationRate[UnitofMeasure="SLA" or UnitofMeasure="ACHnatural"]/Value',
           'Foundations/Foundation[FoundationType/Crawlspace[Vented="true"]]/VentilationRate[UnitofMeasure="SLA"]/Value'].any? { |i| target_xpath.include? i }
      parent = target_xpath.sub(/(?<=\[).*(?=\])/) { |s| s.gsub(/\[.*\]/, '') }
    elsif target_xpath.include?('[Units="kWh/year"]')
      parent = target_xpath.gsub(/\[.*?\]/, '')
    end

    return parent, element_with_value
  end
end
