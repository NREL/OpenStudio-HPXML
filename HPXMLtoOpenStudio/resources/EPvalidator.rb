# frozen_string_literal: true

class EnergyPlusValidator
  def self.run_validator(hpxml_doc)
    # root path
    root_path = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
    # load the Schematron xml
    stron_path = File.join(root_path, 'HPXMLtoOpenStudio', 'resources', 'EPvalidator.xml')

    errors = []
    doc = XMLHelper.parse_file(stron_path)
    XMLHelper.get_elements(doc, '/sch:schema/sch:pattern').each do |pattern|
      XMLHelper.get_elements(pattern, 'sch:rule').each do |rule|
        rule_context = XMLHelper.get_attribute_value(rule, 'context')
        if rule_context == '/*' # Root
          parent_xpath = '/HPXML'
        else
          parent_xpath = rule_context.gsub('h:', '')
        end

        next if hpxml_doc.xpath(parent_xpath).empty? # Skip if parent element doesn't exist

        XMLHelper.get_elements(rule, 'sch:assert').each do |assert_element|
          assert_test = XMLHelper.get_attribute_value(assert_element, 'test').gsub('h:', '')

          hpxml_doc.xpath(parent_xpath).each do |context_element|
            next unless not context_element.xpath(assert_test) # check if assert_test is false

            assert_value = assert_element.children.text # the value of sch:assert
            if rule_context == '/*' # Root
              error_message = assert_value
            else
              error_message = assert_value.gsub(': ', [': ', parent_xpath, ': '].join('')) # insert parent xpath into the error message
            end
            errors << error_message
          end
        end
      end
    end

    return errors
  end
end
