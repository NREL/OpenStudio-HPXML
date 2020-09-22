# frozen_string_literal: true

require_relative 'xmlhelper'
require 'oga'

class HPXMLValidator
  def self.get_elements_from_sample_files()
    root_path = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))

    # Load all HPXMLs
    hpxml_file_dirs = [File.absolute_path(File.join(root_path, 'workflow', 'sample_files')),
                       File.absolute_path(File.join(root_path, 'workflow', 'tests', 'ASHRAE_Standard_140'))]
    hpxml_docs = {}
    hpxml_file_dirs.each do |hpxml_file_dir|
      Dir["#{hpxml_file_dir}/*.xml"].sort.each do |xml|
        hpxml_docs[File.basename(xml)] = HPXML.new(hpxml_path: File.join(hpxml_file_dir, File.basename(xml))).to_oga()
      end
    end

    elements_being_used = []
    hpxml_docs.each do |xml, hpxml_doc|
      root = XMLHelper.get_element(hpxml_doc, '/HPXML')
      root.each_node do |node|
        if node.is_a?(Oga::XML::Element)
          ancestors = []
          node.each_ancestor do |parent_node|
            ancestors << ['h:', parent_node.name].join()
          end
          parent_element_xpath = ancestors.reverse
          child_element_xpath = ['h:', node.name].join()
          element_xpath = [parent_element_xpath, child_element_xpath].join('/')

          next if element_xpath.include? 'extension'

          elements_being_used << element_xpath if not elements_being_used.include? element_xpath
        end
      end
    end

    return elements_being_used
  end

  def self.create_schematron_schema_validator()
    elements_in_sample_files = get_elements_from_sample_files()
    
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
      next if element.get('type').nil? # only checks enumeration values and min/max numerical constraints

      ancestors = []
      element.each_ancestor do |node|
        # add prefix to element name
        ancestors << ['h:', node.get('name')].join() if not node.get('name').nil?
      end
      parent_element_xpath = ancestors.reverse.join('/').chomp('/')
      child_element_xpath = ['h:', element.get('name')].join() if not element.get('name').nil?
      context_xpath = [parent_element_xpath, child_element_xpath].join('/').chomp('/').delete_prefix('/')
      
      next unless elements_in_sample_files.any? { |item| item.include? context_xpath }

      hpxml_data_type_xsd_doc.xpath('//xs:simpleType').each do |simple_type_element|
        hpxml_data_type_name = [element.get('type'), '_simple'].join()
        next unless simple_type_element.get('name') == hpxml_data_type_name # Check if HPXMLDataTypes.xsd has "foo_simple"

        enums = []
        simple_type_element.xpath('xs:restriction/xs:enumeration').each do |enum|
          enums << ['_', enum.get('value'), '_'].join() # in "_foo_" format
        end
        minInclusive_element = simple_type_element.at_xpath('xs:restriction/xs:minInclusive')
        min_inclusive = minInclusive_element.get('value') if not minInclusive_element.nil?
        maxInclusive_element = simple_type_element.at_xpath('xs:restriction/xs:maxInclusive')
        max_inclusive = maxInclusive_element.get('value') if not maxInclusive_element.nil?
        minExclusive_element = simple_type_element.at_xpath('xs:restriction/xs:minExclusive')
        min_exclusive = minExclusive_element.get('value') if not minExclusive_element.nil?
        maxExclusive_element = simple_type_element.at_xpath('xs:restriction/xs:maxExclusive')
        max_exclusive = maxExclusive_element.get('value') if not maxExclusive_element.nil?

        # avoid creating empty rules
        next if enums.empty? && min_inclusive.nil? && max_inclusive.nil? && min_exclusive.nil? && max_exclusive.nil?

        rule = XMLHelper.add_element(pattern, 'sch:rule')
        XMLHelper.add_attribute(rule, 'context', context_xpath.prepend('//'))

        if not enums.empty?
          assertion = XMLHelper.add_element(rule, 'sch:assert')
          XMLHelper.add_attribute(assertion, 'role', 'ERROR')
          XMLHelper.add_attribute(assertion, 'test', "contains(\"#{enums.join(' ')}\", concat(\"_\", text(), \"_\"))")
          assertion.inner_text = "Expected \"text()\" for xpath: \"#{enums.join('" or "').gsub!('_', '')}\""
        end
        if not min_inclusive.nil?
          assertion = XMLHelper.add_element(rule, 'sch:assert')
          XMLHelper.add_attribute(assertion, 'role', 'ERROR')
          XMLHelper.add_attribute(assertion, 'test', "number(.) &gt;= #{min_inclusive}")
          assertion.inner_text = "Expected the value to be greater than or equal to #{min_inclusive} for xpath: "
        end
        if not max_inclusive.nil?
          assertion = XMLHelper.add_element(rule, 'sch:assert')
          XMLHelper.add_attribute(assertion, 'role', 'ERROR')
          XMLHelper.add_attribute(assertion, 'test', "number(.) &lt;= #{max_inclusive}")
          assertion.inner_text = "Expected the value to be less than or equal to #{max_inclusive} for xpath: "
        end
        if not min_exclusive.nil?
          assertion = XMLHelper.add_element(rule, 'sch:assert')
          XMLHelper.add_attribute(assertion, 'role', 'ERROR')
          XMLHelper.add_attribute(assertion, 'test', "number(.) &gt; #{min_exclusive}")
          assertion.inner_text = "Expected the value to be greater than #{min_exclusive} for xpath: "
        end
        if not max_exclusive.nil?
          assertion = XMLHelper.add_element(rule, 'sch:assert')
          XMLHelper.add_attribute(assertion, 'role', 'ERROR')
          XMLHelper.add_attribute(assertion, 'test', "number(.) &lt; #{max_exclusive}")
          assertion.inner_text = "Expected the value to be less than #{max_exclusive} for xpath: "
        end
      end
    end

    XMLHelper.write_file(schema_validator, File.join(File.dirname(__FILE__), 'schema_validator.xml'))
  end
end
