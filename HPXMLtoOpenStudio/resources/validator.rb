# frozen_string_literal: true

class Validator
  def self.run_validator(hpxml_doc, stron_path)
    errors = []
    warnings = []
    abstract_assertions = {}
    doc = XMLHelper.parse_file(stron_path)
    XMLHelper.get_elements(doc, '/sch:schema/sch:pattern/sch:rule').each do |rule|
      if XMLHelper.get_attribute_value(rule, 'abstract')
        # store assertions of the abstract and then move on
        abstract_id = XMLHelper.get_attribute_value(rule, 'id')
        abstract_assertions[abstract_id] = []
        XMLHelper.get_elements(rule, 'sch:assert').each do |assert_element|
          abstract_assertions[abstract_id] << assert_element
        end
        next
      end

      context_xpath = XMLHelper.get_attribute_value(rule, 'context').gsub('h:', '')

      begin
        context_elements = hpxml_doc.xpath(context_xpath)
      rescue
        fail "Invalid xpath: #{context_xpath}"
      end
      next if context_elements.empty? # Skip if context element doesn't exist

      XMLHelper.get_elements(rule, 'sch:assert').each do |assert_element|
        (errors << get_error_or_warning_messages(context_xpath, context_elements, assert_element)).flatten!
      end

      XMLHelper.get_elements(rule, 'sch:report').each do |report_element|
        (warnings << get_error_or_warning_messages(context_xpath, context_elements, report_element)).flatten!
      end

      XMLHelper.get_elements(rule, 'sch:extends').each do |extends_element|
        abstract_id = XMLHelper.get_attribute_value(extends_element, 'rule')
        abstract_assertions[abstract_id].each do |abstract_assertion|
          (errors << get_error_or_warning_messages(context_xpath, context_elements, abstract_assertion)).flatten!
        end
      end
    end

    return errors, warnings
  end

  def self.get_error_or_warning_messages(context_xpath, context_elements, assertion_element)
    messages = []
    assert_test = XMLHelper.get_attribute_value(assertion_element, 'test').gsub('h:', '')

    context_elements.each do |context_element|
      begin
        xpath_result = context_element.xpath(assert_test)
      rescue
        fail "Invalid xpath: #{context_element.name}: #{assert_test}"
      end
      next if xpath_result # check if assert_test is false

      assert_value = assertion_element.children.text # the value of sch:assert
      message = assert_value.gsub(': ', ": #{context_xpath}: ") # insert context xpath into the error message
      messages << message
    end

    return messages
  end
end
