# frozen_string_literal: true

class Validator
  def self.run_validator(hpxml_doc, stron_path)
    errors = []
    doc = XMLHelper.parse_file(stron_path)
    XMLHelper.get_elements(doc, '/sch:schema/sch:pattern/sch:rule').each do |rule|
      rule_context = XMLHelper.get_attribute_value(rule, 'context')
      if rule_context == '/*' # Root
        parent_xpath = '/HPXML'
      else
        parent_xpath = rule_context.gsub('h:', '')
      end

      begin
        context_elements = hpxml_doc.xpath(parent_xpath)
      rescue
        fail "Invalid xpath: #{parent_xpath}"
      end
      next if context_elements.empty? # Skip if context element doesn't exist

      XMLHelper.get_elements(rule, 'sch:assert').each do |assert_element|
        assert_test = XMLHelper.get_attribute_value(assert_element, 'test').gsub('h:', '')

        context_elements.each do |context_element|
          begin
            xpath_result = context_element.xpath(assert_test)
          rescue
            fail "Invalid xpath: #{assert_test}"
          end
          next if xpath_result # check if assert_test is false

          assert_value = assert_element.children.text # the value of sch:assert
          if rule_context == '/*' # Root
            error_message = assert_value
          else
            error_message = assert_value.gsub(': ', ": #{parent_xpath}: ") # insert parent xpath into the error message
          end
          errors << error_message
        end
      end
    end

    return errors
  end
end
