# frozen_string_literal: true

class Validator
  def self.run_validator(hpxml_doc, stron_path)
    errors = []
    warnings = []
    doc = XMLHelper.parse_file(stron_path)
    XMLHelper.get_elements(doc, '/sch:schema/sch:pattern/sch:rule').each do |rule|
      context_xpath = XMLHelper.get_attribute_value(rule, 'context').gsub('h:', '')

      begin
        context_elements = hpxml_doc.xpath(context_xpath)
      rescue
        fail "Invalid xpath: #{context_xpath}"
      end
      next if context_elements.empty? # Skip if context element doesn't exist

      ['sch:assert', 'sch:report'].each do |element_name|
        elements = XMLHelper.get_elements(rule, element_name)
        elements.each do |element|
          test_attr = XMLHelper.get_attribute_value(element, 'test').gsub('h:', '')

          context_elements.each do |context_element|
            begin
              xpath_result = context_element.xpath(test_attr)
            rescue
              fail "Invalid xpath: #{test_attr}"
            end

            if element_name == 'sch:assert'
              next if xpath_result # check if assert_test is false

              error_message = element.children.text # the value of sch:assert
              extended_error_message = [error_message, "[context: #{context_xpath}]"].join(' ') # add context xpath to the error message
              errors << extended_error_message
            elsif element_name == 'sch:report'
              next unless xpath_result # check if assert_test is true

              warning_message = element.children.text # the value of sch:report
              warnings << warning_message
            end
          end
        end
      end
    end

    return errors, warnings
  end
end
