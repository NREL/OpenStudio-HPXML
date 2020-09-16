# frozen_string_literal: true

require_relative 'xmlhelper'
require 'oga'

class HPXMLValidator
  def self.create_schematron_schema_validator()
    base_elements_xsd = File.read(File.join(File.dirname(__FILE__), 'BaseElements.xsd'))
    base_elements_xsd_doc = Oga.parse_xml(base_elements_xsd)

    hpxml_data_type_xsd = File.read(File.join(File.dirname(__FILE__), 'HPXMLDataTypes.xsd'))
    hpxml_data_type_xsd_doc = Oga.parse_xml(hpxml_data_type_xsd)

    schema_validator = XMLHelper.create_doc(version = '1.0', encoding = 'UTF-8')
    root = XMLHelper.add_element(schema_validator, 'sch:schema')
    XMLHelper.add_attribute(root, 'xmlns:sch', 'http://purl.oclc.org/dsdl/schematron')
    name_space = XMLHelper.add_element(root, 'sch:ns')
    XMLHelper.add_attribute(name_space, 'uri', 'http://hpxmlonline.com/2019/10')
    XMLHelper.add_attribute(name_space, 'prefix', 'h')
    pattern = XMLHelper.add_element(root, 'sch:pattern')

    base_elements_xsd_doc.xpath('//xs:element').each do |element|
      ancestors = []
      element.each_ancestor do |node|
        # add prefix to element name
        ancestors << ['h:', node.get('name')].join() if not node.get('name').nil?
      end
      parent_element_xpath = ancestors.reverse.join('/').chomp('/')
      child_element_xpath = ['h:', element.get('name')].join() if not element.get('name').nil?
      if ancestors.empty? # To avoid "///foo/bar" xpath
        context_xpath = [parent_element_xpath.prepend('//'), child_element_xpath].join('').chomp('/') # context_xpath = //foo/bar/baz
      else
        context_xpath = [parent_element_xpath.prepend('//'), child_element_xpath].join('/').chomp('/') # context_xpath = //foo/bar/baz
      end

      rule = XMLHelper.add_element(pattern, 'sch:rule')
      XMLHelper.add_attribute(rule, 'context', context_xpath)

      # FIXME: There might be more element way to handle the following IF statement.
      if (not element.get('minOccurs').nil?) && ((not element.get('maxOccurs').nil?) && element.get('maxOccurs') != 'unbounded')
        min_occurs = [' &gt;= ', element.get('minOccurs').to_s].join()
        max_occurs = [' &lt;= ', element.get('maxOccurs').to_s].join()

        assertion = XMLHelper.add_element(rule, 'sch:assert')
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "count(.)#{min_occurs} and count(.)#{max_occurs}")
      elsif not element.get('minOccurs').nil?
        min_occurs = [' &gt;= ', element.get('minOccurs').to_s].join()

        assertion = XMLHelper.add_element(rule, 'sch:assert')
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "count(.)#{min_occurs}")
      elsif (not element.get('maxOccurs').nil?) && element.get('maxOccurs') != 'unbounded'
        max_occurs = [' &lt;= ', element.get('maxOccurs').to_s].join()

        assertion = XMLHelper.add_element(rule, 'sch:assert')
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "count(.)#{max_occurs}")
      end

      next if element.get('type').nil?

      hpxml_data_type_xsd_doc.xpath('//xs:simpleType').each do |simple_type_element|
        next unless simple_type_element.get('name').start_with? element.get('type') # Check if HPXMLDataTypes.xsd has "foo_simple"

        enums = []
        simple_type_element.xpath('xs:restriction/xs:enumeration').each do |enum|
          enums << ['_', enum.get('value'), '_'].join() # in "_foo_" format
        end

        next unless not enums.empty?

        assertion = XMLHelper.add_element(rule, 'sch:assert')
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "contains(\"#{enums.join(' ')}\", concat(\"_\", text(), \"_\"))")
        assertion.inner_text = "Expected \"text()\" for xpath: \"#{enums.join(' or ').gsub!('_', '')}\""
      end
    end

    XMLHelper.write_file(schema_validator, File.join(File.dirname(__FILE__), 'schema_validator.xml'))
  end

  def self.validate_xml(hpxml_doc)
    puts 'Validating xml...'
    errors = Validator.run_validator(hpxml_doc, File.join(File.dirname(__FILE__), 'schema_validator.xml'))

    if not errors.empty?
      errors.each do |error|
        fail "#{error}"
      end
    end
  end
end
