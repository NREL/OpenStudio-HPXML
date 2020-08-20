# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'
require 'schematron-nokogiri'

class HPXMLtoOpenStudioValidationTest < MiniTest::Test
  def before_setup
    @root_path = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))

    # load the Schematron xml
    @stron_path = File.join(@root_path, 'HPXMLtoOpenStudio', 'resources', 'EPvalidator.xml')
    # make a Schematron object
    @stron_doc = SchematronNokogiri::Schema.new Nokogiri::XML File.open(@stron_path)

    # Load all HPXMLs
    @hpxml_docs = {}
    sample_files_dir = File.absolute_path(File.join(@root_path, 'workflow', 'sample_files'))
    Dir["#{sample_files_dir}/*.xml"].sort.each do |xml|
      @hpxml_docs[File.basename(xml)] = HPXML.new(hpxml_path: File.join(sample_files_dir, File.basename(xml))).to_oga()
    end
  end

  def test_sample_files
    puts "Testing #{@hpxml_docs.size} HPXML files..."
    @hpxml_docs.each do |xml, hpxml_doc|
      print '.'

      # HPXML Schema validation
      _test_schema_validation(hpxml_doc)
      # Ruby validator validation
      _test_ruby_validation(hpxml_doc)
      # Schematron validation
      _test_schematron_validation(@stron_doc, hpxml_doc.to_xml)
    end

    puts
  end

  def test_schematron_asserts
    # build up expected error messages hashes by parsing EPvalidator.xml
    doc = XMLHelper.parse_file(@stron_path)
    expected_error_msgs_by_element_addition = {}
    expected_error_msgs_by_element_deletion = {}
    XMLHelper.get_elements(doc, '/sch:schema/sch:pattern').each do |pattern|
      XMLHelper.get_elements(pattern, 'sch:rule').each do |rule|
        rule_context = XMLHelper.get_attribute_value(rule, 'context')

        XMLHelper.get_values(rule, 'sch:assert').each do |assertion|
          parent_xpath = rule_context.gsub('h:', '').gsub('/*', '')
          element_name = _get_element_name(assertion)
          target_xpath = [parent_xpath, element_name]
          expected_error_message = _get_expected_error_message(parent_xpath, assertion)

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

    n_asserts = expected_error_msgs_by_element_deletion.size
    n_asserts += expected_error_msgs_by_element_addition.size
    puts "Testing #{n_asserts} Schematron asserts..."

    # Tests by element deletion
    expected_error_msgs_by_element_deletion.each do |target_xpath, expected_error_message|
      print '.'
      hpxml_doc = _get_hpxml_doc(target_xpath, 'deletion')
      parent_element = target_xpath[0] == '' ? hpxml_doc : XMLHelper.get_element(hpxml_doc, target_xpath[0])
      child_elements = target_xpath[1]
      child_elements.each do |child_element|
        XMLHelper.delete_element(parent_element, child_element)
      end

      # Ruby validator validation
      _test_ruby_validation(hpxml_doc, expected_error_message)
      # Schematron validation
      _test_schematron_validation(@stron_doc, hpxml_doc.to_xml, expected_error_message)
    end

    # Tests by element addition (i.e. zero_or_one, zero_or_two, etc.)
    expected_error_msgs_by_element_addition.each do |target_xpath, expected_error_message|
      print '.'
      hpxml_doc = _get_hpxml_doc(target_xpath, 'addition')
      parent_element = target_xpath[0] == '' ? hpxml_doc : XMLHelper.get_element(hpxml_doc, target_xpath[0])
      child_elements = target_xpath[1]

      child_elements.each do |child_element|
        # make sure parent elements of the last child element exist in HPXML
        child_element_without_predicates = child_element.gsub(/\[.*?\]|\[|\]/, '') # remove brackets and text within brackets (e.g. [foo or ...])
        child_element_without_predicates_array = child_element_without_predicates.split('/')[0...-1].reject(&:empty?)
        XMLHelper.create_elements_as_needed(parent_element, child_element_without_predicates_array)

        # add child element
        additional_parent_element = child_element.gsub(/\[text().*?\]/, '').split('/')[0...-1].reject(&:empty?).join('/').chomp('/') # remove text that starts with 'text()' within brackets (e.g. [text()=foo or ...]) and select elements from the first to the second last
        mod_parent_element = additional_parent_element.empty? ? parent_element : XMLHelper.get_element(parent_element, additional_parent_element)
        mod_child_name = child_element_without_predicates.split('/')[-1]
        max_number_of_elements_allowed = expected_error_message.gsub(/\[.*?\]|\[|\]/, '').scan(/\d+/).max.to_i # scan numbers outside brackets and then find the maximum
        (max_number_of_elements_allowed + 1).times { XMLHelper.add_element(mod_parent_element, mod_child_name) }

        # add a value to child elements as needed
        child_element_with_value = _get_child_element_with_value(target_xpath, max_number_of_elements_allowed)
        next if child_element_with_value.nil?

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

      # Ruby validator validation
      _test_ruby_validation(hpxml_doc, expected_error_message)
      # Schematron validation
      _test_schematron_validation(@stron_doc, hpxml_doc.to_xml, expected_error_message)
    end

    puts
  end

  private

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

  def _test_schema_validation(hpxml_doc, xml)
    # TODO: Remove this when schema validation is included with CLI calls
    schemas_dir = File.absolute_path(File.join(@root_path, 'HPXMLtoOpenStudio', 'resources'))
    errors = XMLHelper.validate(hpxml_doc.to_xml, File.join(schemas_dir, 'HPXML.xsd'), nil)
    if errors.size > 0
      puts "#{xml}: #{errors}"
    end
    assert_equal(0, errors.size)
  end

  def _get_hpxml_doc(target_xpath, mode)
    @hpxml_docs.values.each do |hpxml_doc|
      parent_element = target_xpath[0] == '' ? hpxml_doc : XMLHelper.get_element(hpxml_doc, target_xpath[0])
      next if parent_element.nil?

      child_elements = target_xpath[1]

      if mode == 'deletion'
        end_index = -1
      elsif mode == 'addition'
        end_index = -2
      end

      found_children = true
      child_elements[0..end_index].each do |child_element|
        next if XMLHelper.has_element(parent_element, child_element)

        found_children = false
        break
      end
      next unless found_children

      return _deep_copy_object(hpxml_doc)
    end

    fail "Could not find HPXML file for target_xpath: #{target_xpath}."
  end

  def _get_element_name(assertion)
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

      # Exceptions
      # FIXME: Is there another way to handle this?
      if assertion.partition(': ').last.include? 'AnnualHeatingDistributionSystemEfficiency'
        # Need to remove both AnnualHeatingDistributionSystemEfficiency and AnnualCoolingDistributionSystemEfficiency
        element_name_additional = assertion.partition(': ').last.partition(' | ').last
        element_names << element_name_additional
      elsif assertion.partition(': ').last.include? 'HousePressure'
        # handle [(HousePressure and BuildingAirLeakage/UnitofMeasure[text()!="ACHnatural"]) or (not(HousePressure) and BuildingAirLeakage/UnitofMeasure[text()="ACHnatural"])]
        element_names[0] = 'HousePressure' # replacing element name with 'HousePressure' for the test (i.e. the test by element deletion).
      end
    end

    return element_names
  end

  def _get_expected_error_message(parent_xpath, assertion)
    if parent_xpath == '' # root element
      return [[assertion.partition(': ').first, parent_xpath].join(': '), assertion.partition(': ').last].join() # return "Expected x element(s) for xpath: foo"
    else
      return [[assertion.partition(': ').first, parent_xpath].join(': '), assertion.partition(': ').last].join(': ') # return "Expected x element(s) for xpath: foo: bar"
    end
  end

  def _get_child_element_with_value(target_xpath, max_number_of_elements_allowed)
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

  def _deep_copy_object(obj)
    return Marshal.load(Marshal.dump(obj))
  end
end
