# frozen_string_literal: true

require_relative 'xmlhelper'
require 'oga'

class HPXMLValidator
  def self.get_elements_from_sample_files()
    puts 'Identifying elements being used in sample files...'

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
        next unless node.is_a?(Oga::XML::Element)

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

    return elements_being_used
  end

  def self.create_schematron_schema_validator()
    elements_in_sample_files = get_elements_from_sample_files()

    base_elements_xsd = File.read(File.join(File.dirname(__FILE__), 'BaseElements.xsd'))
    base_elements_xsd_doc = Oga.parse_xml(base_elements_xsd)

    # construct dictionary for enumerations and min/max values of HPXML data types
    hpxml_data_types_xsd = File.read(File.join(File.dirname(__FILE__), 'HPXMLDataTypes.xsd'))
    hpxml_data_types_xsd_doc = Oga.parse_xml(hpxml_data_types_xsd)
    hpxml_data_types_dict = {}
    hpxml_data_types_xsd_doc.xpath('//xs:simpleType').each do |simple_type_element|
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

      simple_type_element_name = simple_type_element.get('name')
      hpxml_data_types_dict[simple_type_element_name] = {}
      hpxml_data_types_dict[simple_type_element_name][:enums] = enums
      hpxml_data_types_dict[simple_type_element_name][:min_inclusive] = min_inclusive
      hpxml_data_types_dict[simple_type_element_name][:max_inclusive] = max_inclusive
      hpxml_data_types_dict[simple_type_element_name][:min_exclusive] = min_exclusive
      hpxml_data_types_dict[simple_type_element_name][:max_exclusive] = max_exclusive
    end

    # construct schema_validator.xml
    puts 'Constructing schema_validator.xml...'

    schema_validator = XMLHelper.create_doc(version = '1.0', encoding = 'UTF-8')
    root = XMLHelper.add_element(schema_validator, 'sch:schema')
    XMLHelper.add_attribute(root, 'xmlns:sch', 'http://purl.oclc.org/dsdl/schematron')
    name_space = XMLHelper.add_element(root, 'sch:ns')
    XMLHelper.add_attribute(name_space, 'uri', 'http://hpxmlonline.com/2019/10')
    XMLHelper.add_attribute(name_space, 'prefix', 'h')
    pattern = XMLHelper.add_element(root, 'sch:pattern')

    element_xpaths = {}
    complex_type_or_group_dict = {}
    # construct complexType and group elements dictionary
    [{ _xpath: '//xs:element', _type: '//xs:complexType', _attr: 'type' },
     { _xpath: '//xs:group', _type: '//xs:group', _attr: 'ref' }].each do |param|
      base_elements_xsd_doc.xpath(param[:_type]).each do |param_type|
        next if param_type.get('name').nil?

        param_type_name = param_type.get('name')
        complex_type_or_group_dict[param_type_name] = {}

        param_type_only = deep_copy_object(param_type)
        param_type_only.each_node do |element|
          next unless element.is_a?(Oga::XML::Element)
          next unless element.name == 'element'

          ancestors = []
          element.each_ancestor do |node|
            next if node.get('name').nil?
            next if node.get('name') == param_type_only.get('name') # exclude complexType name from elements' xpath

            ancestors << node.get('name')
          end

          parent_element_names = ancestors
          child_element_name = element.get('name')
          element_xpath = parent_element_names.unshift(child_element_name) # push the element to the front
          element_type = element.get('type')
          complex_type_or_group_dict[param_type_name][element_xpath] = element_type
        end
      end

      # expand elements by adding elements based on type/ref
      base_elements_xsd_doc.xpath(param[:_xpath]).each do |element|
        next if element.get(param[:_attr]).nil?

        ancestors = []
        element.each_ancestor do |node|
          next if node.get('name').nil?
          next if node.get('name') == element.get('name') # exclude complexType name from elements' xpath

          ancestors << node.get('name')
        end

        parent_element_names = ancestors
        child_element_name = element.get('name')
        if param[:_xpath] == '//xs:element'
          element_xpath = parent_element_names.unshift(child_element_name) # push the element to the front
        else
          element_xpath = parent_element_names
        end
        element_type = element.get(param[:_attr])

        # Skip element xpaths not being used in sample files
        element_xpath_with_prefix = element_xpath.reverse.map { |e| "h:#{e}" }
        context_xpath = element_xpath_with_prefix.join('/').chomp('/')
        next unless elements_in_sample_files.any? { |item| item.include? context_xpath }

        has_complex_type_or_group_dict = complex_type_or_group_dict[element_type]
        if has_complex_type_or_group_dict
          get_expanded_elements(element_xpaths, complex_type_or_group_dict, element_xpath, element_type)
        else
          element_xpaths[element_xpath] = element_type
        end
      end
    end

    # Add enumeration and min/max numeric values
    puts 'Adding enumeration and min/max numeric values...'

    element_xpaths.each do |element_xpath, element_type|
      # exclude duplicated xpaths
      result = element_xpaths.keys.select { |k| (element_xpath != k) && (k.each_cons(element_xpath.size).include? element_xpath) } # check if an array contains another array in particular order
      next unless result.empty?

      # Skip element xpaths not being used in sample files
      element_xpath_with_prefix = element_xpath.reverse.map { |e| "h:#{e}" }
      context_xpath = element_xpath_with_prefix.join('/').chomp('/')
      next unless elements_in_sample_files.any? { |item| item.include? context_xpath }

      hpxml_data_type_name = [element_type, '_simple'].join()
      hpxml_data_type = hpxml_data_types_dict[hpxml_data_type_name]
      next if hpxml_data_type.nil?

      rule = XMLHelper.add_element(pattern, 'sch:rule')
      XMLHelper.add_attribute(rule, 'context', context_xpath.prepend('//'))

      if not hpxml_data_type[:enums].empty?
        assertion = XMLHelper.add_element(rule, 'sch:assert')
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "contains(\"#{hpxml_data_type[:enums].join(' ')}\", concat(\"_\", text(), \"_\"))")
        assertion.inner_text = "Expected value to be: \"#{hpxml_data_type[:enums].join('" or "').gsub!('_', '')}\""
      end
      if hpxml_data_type[:min_inclusive]
        assertion = XMLHelper.add_element(rule, 'sch:assert')
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "number(.) &gt;= #{hpxml_data_type[:min_inclusive]}")
        assertion.inner_text = "Expected value to be greater than or equal to #{hpxml_data_type[:min_inclusive]} for xpath: "
      end
      if hpxml_data_type[:max_inclusive]
        assertion = XMLHelper.add_element(rule, 'sch:assert')
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "number(.) &lt;= #{hpxml_data_type[:max_inclusive]}")
        assertion.inner_text = "Expected value to be less than or equal to #{hpxml_data_type[:max_inclusive]} for xpath: "
      end
      if hpxml_data_type[:min_exclusive]
        assertion = XMLHelper.add_element(rule, 'sch:assert')
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "number(.) &gt; #{hpxml_data_type[:min_exclusive]}")
        assertion.inner_text = "Expected value to be greater than #{hpxml_data_type[:min_exclusive]} for xpath: "
      end
      if hpxml_data_type[:max_exclusive]
        assertion = XMLHelper.add_element(rule, 'sch:assert')
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "number(.) &lt; #{hpxml_data_type[:max_exclusive]}")
        assertion.inner_text = "Expected value to be less than #{hpxml_data_type[:max_exclusive]} for xpath: "
      end
    end

    XMLHelper.write_file(schema_validator, File.join(File.dirname(__FILE__), 'schema_validator.xml'))
  end

  def self.get_expanded_elements(element_xpaths, complex_type_or_group_dict, element_xpath, element_type)
    if complex_type_or_group_dict[element_type].nil?
      return element_xpaths[element_xpath] = element_type
    else
      expanded_elements = deep_copy_object(complex_type_or_group_dict[element_type])
      expanded_elements.each do |k, v|
        k.push(element_xpath).flatten!
        if complex_type_or_group_dict[v].nil?
          element_xpaths[k] = v
          next
        end

        get_expanded_elements(element_xpaths, complex_type_or_group_dict, k, v)
      end
    end
  end

  def self.deep_copy_object(obj)
    return Marshal.load(Marshal.dump(obj))
  end
end
