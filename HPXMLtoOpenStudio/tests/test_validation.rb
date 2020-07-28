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

    # load the schematron xml
    @stron_path = File.join(@root_path, 'HPXMLtoOpenStudio', 'resources', 'EPvalidator.xml')
    # make a Schematron object
    @stron_doc = SchematronNokogiri::Schema.new Nokogiri::XML File.open(@stron_path)
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
      _test_schematron_validation(@stron_doc, hpxml_doc.to_xml)
    end

    puts
  end

  def test_invalid_files
    # build up expected error messages hashes by parsing EPvalidator.xml
    doc = XMLHelper.parse_file(@stron_path)
    expected_error_msgs_by_element_addition = {}
    expected_error_msgs_by_element_deletion = {}
    XMLHelper.get_elements(doc, '/sch:schema/sch:pattern').each do |pattern|
      XMLHelper.get_elements(pattern, 'sch:rule').each do |rule|
        rule_context = XMLHelper.get_attribute_value(rule, 'context')

        XMLHelper.get_values(rule, 'sch:assert').each do |assertion|
          parent_xpath = rule_context.gsub('h:', '').gsub('/*', '')
          element_name = get_element_name(assertion)
          target_xpath = [parent_xpath, element_name]
          expected_error_message = get_expected_error_message(parent_xpath, assertion)

          if assertion.start_with?('Expected 0') || assertion.partition(': ').last.start_with?('[not') # FIXME: Is there another way to do this?
            next if assertion.start_with?('Expected 0 or more') # no tests needed

            expected_error_msgs_by_element_addition[target_xpath] = expected_error_message
          elsif assertion.start_with?('Expected 1') || assertion.start_with?('Expected 9')
            expected_error_msgs_by_element_deletion[target_xpath] = expected_error_message
          else
            fail 'Invalid expected error message.'
          end
        end
      end
    end

    # Tests by element deletion
    expected_error_msgs_by_element_deletion.each do |target_xpath, expected_error_message|
      print '.'
      hpxml_name = get_hpxml_file_name(target_xpath)
      hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
      hpxml_doc = hpxml.to_oga()
      parent_element = target_xpath[0] == '' ? hpxml_doc : XMLHelper.get_element(hpxml_doc, target_xpath[0])
      child_elements = target_xpath[1]
      child_elements.each do |child_element|
        XMLHelper.delete_element(parent_element, child_element)
      end

      # .rb validator validation
      _test_ruby_validation(hpxml_doc, expected_error_message)
      # Schematron validation
      _test_schematron_validation(@stron_doc, hpxml_doc.to_xml, expected_error_message)
    end

    # Tests by element addition (i.e. zero_or_one, zero_or_two, etc.)
    expected_error_msgs_by_element_addition.each do |target_xpath, expected_error_message|
      print '.'
      hpxml_name = get_hpxml_file_name(target_xpath)
      hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
      hpxml_doc = hpxml.to_oga()
      parent_element = target_xpath[0] == '' ? hpxml_doc : XMLHelper.get_element(hpxml_doc, target_xpath[0])
      child_elements = target_xpath[1]

      child_elements.each do |child_element|
        # make sure parent elements of the last child element exist in HPXML
        child_element_without_predicates = child_element.gsub(/\[.*?\]|\[|\]/, '') # gsub '[...]' or '[' or ']'
        child_element_without_predicates_array = child_element_without_predicates.split('/')[0...-1].reject(&:empty?)
        XMLHelper.create_elements_as_needed(parent_element, child_element_without_predicates_array)

        # add child element
        additional_parent_element = child_element.gsub(/\[text().*?\]/, '').split('/')[0...-1].reject(&:empty?).join('/').chomp('/') # gsub [text()=foo or ...] and select from 0th to the 2nd last element
        mod_parent_element = additional_parent_element.empty? ? parent_element : XMLHelper.get_element(parent_element, additional_parent_element)
        mod_child_name = child_element_without_predicates.split('/')[-1]
        max_number_of_elements_allowed = expected_error_message.gsub(/\[.*?\]|\[|\]/, '').scan(/\d+/).max.to_i # scan numbers outside brackets and then find the maximum
        (max_number_of_elements_allowed + 1).times { XMLHelper.add_element(mod_parent_element, mod_child_name) }

        # add a value to the child element as needed
        child_element_with_value = get_child_element_with_value(target_xpath, max_number_of_elements_allowed)
        next unless not child_element_with_value.nil?

        child_element_with_value.each do |element_with_value|
          this_child_name = element_with_value[:name]
          this_child_value = element_with_value[:value]

          this_parents = []
          if child_element_without_predicates == this_child_name # in case where child_element_without_predicates is foo[text()=bar or ...]
            this_parents << parent_element
          else # in case where child_element_without_predicates is foo/bar[text()=baz or ...]
            this_parents = XMLHelper.get_elements(parent_element, child_element_without_predicates)
          end

          this_parents.each do |e|
            XMLHelper.add_element(e, this_child_name, this_child_value)
          end
        end
      end

      # .rb validator validation
      _test_ruby_validation(hpxml_doc, expected_error_message)
      # Schematron validation
      _test_schematron_validation(@stron_doc, hpxml_doc.to_xml, expected_error_message)
    end

    puts
  end

  def _test_schematron_validation(stron_doc, hpxml, expected_error_msgs = nil)
    # load the xml document you wish to validate
    xml_doc = Nokogiri::XML hpxml
    # validate it
    results = stron_doc.validate xml_doc
    # assertions
    if expected_error_msgs.nil?
      assert_empty(results)
    else
      idx_of_interest = results.index { |i| i[:message].gsub(': ', [': ', i[:context_path].gsub('h:', '').concat(': ').gsub('/*: ', '')].join('')) == expected_error_msgs }
      error_msg_of_interest = results[idx_of_interest][:message].gsub(': ', [': ', results[idx_of_interest][:context_path].gsub('h:', '').concat(': ').gsub('/*: ', '')].join(''))
      assert_equal(expected_error_msgs, error_msg_of_interest)
    end
  end

  def _test_ruby_validation(hpxml_doc, expected_error_msgs = nil)
    # Validate input HPXML against EnergyPlus Use Case
    results = EnergyPlusValidator.run_validator(hpxml_doc)
    if expected_error_msgs.nil?
      assert_empty(results)
    else
      idx_of_interest = results.index { |i| i == expected_error_msgs }
      error_msg_of_interest = results[idx_of_interest]
      assert_equal(expected_error_msgs, error_msg_of_interest)
    end
  end

  def get_hpxml_file_name(target_xpath)
    target_xpath_combined = target_xpath.join('/')

    if target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Appliances/Dehumidifier'
      return 'base-appliances-dehumidifier.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors'
      return 'base-misc-neighbor-shading.xml'
    elsif target_xpath_combined.include? '/HPXML/SoftwareInfo/extension/SimulationControl/DaylightSaving'
      return 'base-simcontrol-daylight-saving-custom.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor[ExteriorAdjacentTo[text()="other housing unit" or text()="other heated space" or text()="other multifamily buffer space" or text()="other non-freezing space"]]/extension/OtherSpaceAboveOrBelow'
      return 'base-enclosure-other-housing-unit.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Enclosure/Foundations'
      return 'base-foundation-vented-crawlspace.xml'
    elsif ['/HPXML/Building/BuildingDetails/Enclosure/Attics',
           '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof[InteriorAdjacentTo="attic - vented"]'].any? { |i| target_xpath_combined.include? i }
      return 'base-atticroof-vented.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall[InteriorAdjacentTo="crawlspace - vented"]'
      return 'base-foundation-vented-crawlspace.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/DepthBelowGrade'
      return 'base-foundation-slab.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/UnderSlabInsulationWidth'
      return 'base-foundation-conditioned-basement-slab-insulation.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Lighting/CeilingFan'
      return 'base-misc-ceiling-fans.xml'
    elsif ['/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/ElectricResistance]',
           '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/HeatingSystemType[ElectricResistance]'].any? { |i| target_xpath_combined.include? i }
      return 'base-hvac-elec-resistance-only.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/WallFurnace]'
      return 'base-hvac-wall-furnace-elec-only.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/FloorFurnace]'
      return 'base-hvac-floor-furnace-propane-only.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/Boiler]'
      return 'base-hvac-boiler-gas-only.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/Stove]'
      return 'base-hvac-stove-oil-only.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/PortableHeater]'
      return 'base-hvac-portable-heater-electric-only.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/FixedHeater]'
      return 'base-hvac-fixed-heater-electric-only.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/Fireplace]'
      return 'base-hvac-fireplace-wood-only.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl'
      return 'base-hvac-programmable-thermostat.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution[DistributionSystemType[Other="DSE"]]'
      return 'base-hvac-dse.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[CoolingSystemType="room air conditioner"]'
      return 'base-hvac-room-ac-only.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[CoolingSystemType="evaporative cooler"]'
      return 'base-hvac-evap-cooler-furnace-gas.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[CoolingSystemType="mini-split"]'
      return 'base-hvac-mini-split-air-conditioner-only-ducted.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[HeatPumpType="mini-split"]'
      return 'base-hvac-mini-split-heat-pump-ducted.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[HeatPumpType="ground-to-air"]'
      return 'base-hvac-ground-to-air-heat-pump.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[BackupSystemFuel]'
      return 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml'
    elsif ['/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump',
           '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[HeatPumpType="air-to-air"]'].any? { |i| target_xpath_combined.include? i }
      return 'base-hvac-air-to-air-heat-pump-1-speed.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true"]'
      return 'base-mechvent-balanced.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true" and FanType="heat recovery ventilator"]'
      return 'base-mechvent-hrv.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true" and FanType="energy recovery ventilator"]'
      return 'base-mechvent-erv.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true" and FanType="central fan integrated supply"]'
      return 'base-mechvent-cfis.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForSeasonalCoolingLoadReduction="true"]'
      return 'base-misc-whole-house-fan.xml'
    elsif ['/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForLocalVentilation="true" and FanLocation="kitchen"]',
           '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForLocalVentilation="true" and FanLocation="bath"]'].any? { |i| target_xpath_combined.include? i }
      return 'base-mechvent-bath-kitchen-fans.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/Overhangs'
      return 'base-enclosure-overhangs.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight'
      return 'base-enclosure-skylights.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="instantaneous water heater"]'
      return 'base-dhw-tankless-electric.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="heat pump water heater"]'
      return 'base-dhw-tank-heat-pump.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="space-heating boiler with storage tank"]'
      return 'base-dhw-indirect.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="space-heating boiler with tankless coil"]/RelatedHVACSystem'
      return 'base-dhw-combi-tankless.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[UsesDesuperheater="true"]'
      return 'base-dhw-desuperheater.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Recirculation'
      return 'base-dhw-recirc-timer.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/DrainWaterHeatRecovery'
      return 'base-dhw-dwhr.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem[SolarFraction]'
      return 'base-dhw-solar-fraction.xml'
    elsif ['/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem',
           '/HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem[CollectorArea]'].any? { |i| target_xpath_combined.include? i }
      return 'base-dhw-solar-direct-flat-plate.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem'
      return 'base-pv.xml'
    elsif ['/HPXML/Building/BuildingDetails/Appliances/Freezer', '/HPXML/Building/BuildingDetails/Pools/Pool',
           '/HPXML/Building/BuildingDetails/HotTubs/HotTub', '/HPXML/Building/BuildingDetails/MiscLoads/FuelLoad'].any? { |i| target_xpath_combined.include? i }
      return 'base-misc-large-uncommon-loads.xml'
    elsif target_xpath_combined.include? '/HPXML/Building/BuildingDetails/Lighting/extension/ExteriorHolidayLighting'
      return 'base-misc-lighting-detailed.xml'
    else
      return 'base.xml'
    end
  end

  def get_element_name(assertion)
    element_names = []
    if assertion.partition(': ').last.start_with?('[not')
      element_names << assertion.partition(': ').last.partition(' | ').last
    else
      element_name = assertion.partition(': ').last.partition(' | ').first
      if element_name.count('[') != element_name.count(']')
        diff = element_name.count('[') - element_name.count(']')
        diff.times { element_name.concat(']') }
      end
      element_names << element_name

      # exception: need to remove both AnnualHeatingDistributionSystemEfficiency and AnnualCoolingDistributionSystemEfficiency
      # FIXME: Is there another way to handle this?
      if assertion.partition(': ').last.include? 'AnnualHeatingDistributionSystemEfficiency'
        add_element_name = assertion.partition(': ').last.partition(' | ').last
        element_names << add_element_name
      end
    end

    return element_names
  end

  def get_expected_error_message(parent_xpath, assertion)
    if parent_xpath == '' # root element
      return [[assertion.partition(': ').first, parent_xpath].join(': '), assertion.partition(': ').last].join()
    else
      return [[assertion.partition(': ').first, parent_xpath].join(': '), assertion.partition(': ').last].join(': ')
    end
  end

  def get_child_element_with_value(target_xpath, max_number_of_elements_allowed)
    element_with_value = []

    child_elements = target_xpath[1]
    child_elements.each do |child_element|
      child_element_last = child_element.split('/')[-1]
      next unless child_element_last.include? 'text()='

      element_name = child_element.split('text()=')[0].gsub(/\[|\]/, '/').chomp('/').split('/')[-1] # pull 'bar' from foo/bar[text()=baz or text()=fum or ...]
      element_value = child_element.split('text()=')[1].gsub(/\[|\]/, '').gsub('" or ', '"').gsub!(/\A"|"\Z/, '') # pull 'baz' from foo/bar[text()=baz or text()=fum or ...]; FIXME: Is there another way to handle this?
      (max_number_of_elements_allowed + 1).times { element_with_value << { name: element_name, value: element_value } }
    end

    return element_with_value
  end
end
