require 'rexml/document'
require 'rexml/xpath'

class XMLHelper
  # Adds the child element with 'element_name' and sets its value. Returns the
  # child element.
  def self.add_element(parent, element_name, value = nil)
    added = nil
    element_name.split('/').each do |name|
      added = REXML::Element.new(name)
      parent << added
      parent = added
    end
    if not value.nil?
      added.text = value
    end
    return added
  end

  # Creates a hierarchy of elements under the parent element based on the supplied
  # list of element names. If a given child element already exists, it is reused.
  # Returns the final element.
  def self.create_elements_as_needed(parent, element_names)
    this_parent = parent
    element_names.each do |element_name|
      if this_parent.elements[element_name].nil?
        XMLHelper.add_element(this_parent, element_name)
      end
      this_parent = this_parent.elements[element_name]
    end
    return this_parent
  end

  # Deletes the child element with element_name. Returns the deleted element.
  def self.delete_element(parent, element_name)
    element = nil
    begin
      last_element = element
      element = parent.elements.delete(element_name)
    end while !element.nil?
    return last_element
  end

  # Returns the value of 'element_name' in the parent element or nil.
  def self.get_value(parent, element_name)
    val = parent.elements[element_name]
    el_path = parent.xpath + '/' + element_name
    validate_val(val, el_path)
    if val.nil?
      return val
    end

    return val.text
  end

  # Returns the value(s) of 'element_name' in the parent element or [].
  def self.get_values(parent, element_name)
    vals = []
    parent.elements.each(element_name) do |val|
      vals << val.text
    end

    return vals
  end

  def self.validate_val(val, el_path)
    el_path = el_path.gsub(/(?<reg>(\[([^\]\[]|\g<reg>)*\]))/, '')
    el_array = el_path.split('/').reject{ |p| p.empty? }
    valid_map = load_or_get_data_type_xsd(el_array)
    enums = valid_map[:enums]
    min = valid_map[:min_value]
    max = valid_map[:max_value]
    puts enums
    puts min
    puts max
  end

  def self.load_or_get_data_type_xsd(el_array)
    if @valid_map.nil?
      @valid_map = {}
    end
    if @type_map.nil?
      @type_map = {}
    end
    return @valid_map[@type_map[el_array]] if not @valid_map[@type_map[el_array]].nil?
    puts ""
    puts "----New element validation required!----"
    if @doc_base.nil?
      puts "base file nil"
      this_dir = File.dirname(__FILE__)
      base_el_xsd_path = this_dir + '/BaseElements.xsd'
      dt_type_xsd_path = this_dir + '/HPXMLDataTypes.xsd'
      @doc_base = REXML::Document.new(File.new(base_el_xsd_path))
      @doc_data = REXML::Document.new(File.new(dt_type_xsd_path))
    end
    parent_type = nil
    parent_name = nil
    # part1: get element data type from BaseElements.xsd using path
    el_array.each_with_index do |el_name, i|
      next if i < 2
      return {} if el_name == 'extension'
      puts "this element name: " + el_name
      if parent_type.nil? and parent_name.nil?
        parent_type = REXML::XPath.first(@doc_base, "//xs:element[@name='#{el_name}']").attributes['type']
      else
        if not parent_name.nil? and parent_type.nil?
        el = REXML::XPath.first(@doc_base, "//xs:element[@name='#{parent_name}']//xs:element[@name='#{el_name}']")
        if el.nil?
          group = REXML::XPath.first(@doc_base, "//xs:element[@name='#{parent_name}']//xs:group").attributes['ref']
          el = REXML::XPath.first(@doc_base, "//xs:group[@name='#{group}']//xs:element[@name='#{el_name}']")
        end
        else
        el = REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{parent_type}']//xs:element[@name='#{el_name}']")
        if el.nil?
          group = REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{parent_type}']//xs:group").attributes['ref'] unless REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{parent_type}']//xs:group").nil?
          el = REXML::XPath.first(@doc_base, "//xs:group[@name='#{group}']//xs:element[@name='#{el_name}']") unless REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{parent_type}']//xs:group").nil?
          base = REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{parent_type}']//xs:extension").attributes['base'] unless REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{parent_type}']//xs:extension").nil?
          el = REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{base}']//xs:element[@name='#{el_name}']") unless REXML::XPath.first(@doc_base, "//xs:complexType[@name='#{parent_type}']//xs:extension").nil?
        end
        end
        el_type = el.attributes['type']
        parent_type = el_type
      end
      parent_name = el_name
    end
    @type_map[el_array] = parent_type
    
    # part2: get enums and min/max values from HPXMLDataType.xsd
    return @valid_map[parent_type] if not @valid_map[parent_type].nil?
    @valid_map[parent_type] = {}
    simple_type_name = parent_name
    simple_type = REXML::XPath.first(@doc_data, "//xs:simpleType[@name='#{simple_type_name}']")
    if simple_type.nil?
      simple_type_name = REXML::XPath.first(@doc_data, "//xs:complexType[@name='#{parent_type}']//xs:extension").attributes['base']
      if simple_type_name.start_with? 'xs:'
        simple_type_name = parent_type
      end
    end
    enum_els = @doc_data.elements.to_a("//xs:simpleType[@name='#{simple_type_name}']//xs:enumeration | //xs:complexType[@name='#{simple_type_name}']//xs:enumeration")
    enums = enum_els.map { |el| el.attributes['value'] } unless enum_els.empty?
    min_el = REXML::XPath.first(@doc_data, "//xs:simpleType[@name='#{simple_type_name}']//xs:minExclusive | //xs:simpleType[@name='#{simple_type_name}']//xs:minInclusive | //xs:complexType[@name='#{simple_type_name}']//xs:minExclusive | //xs:complexType[@name='#{simple_type_name}']//xs:minInclusive")
    if not min_el.nil?
      min_value = min_el.attributes['value']
    end
    max_el = REXML::XPath.first(@doc_data, "//xs:simpleType[@name='#{simple_type_name}']//xs:maxExclusive | //xs:simpleType[@name='#{simple_type_name}']//xs:maxInclusive | //xs:complexType[@name='#{simple_type_name}']//xs:maxExclusive | //xs:complexType[@name='#{simple_type_name}']//xs:maxInclusive")
    if not max_el.nil?
      max_value = max_el.attributes['value']
    end
    @valid_map[parent_type][:enums] = enums
    @valid_map[parent_type][:min_value] = min_value
    @valid_map[parent_type][:max_value] = max_value
    return @valid_map[parent_type]
  end
  
  # Returns the name of the first child element of the 'element_name'
  # element on the parent element.
  def self.get_child_name(parent, element_name)
    begin
      return parent.elements[element_name].elements[1].name
    rescue
    end
    return
  end

  # Returns true if the element exists.
  def self.has_element(parent, element_name)
    element = REXML::XPath.first(parent, element_name)
    return !element.nil?
  end

  # Returns the attribute added
  def self.add_attribute(element, attr_name, attr_val)
    attr_val = valid_attr(attr_val).to_s
    added = element.add_attribute(attr_name, attr_val)
    return added
  end

  def self.valid_attr(attr)
    attr = attr.to_s
    attr = attr.gsub(' ', '_')
    attr = attr.gsub('|', '_')
    return attr
  end

  # Copies the element if it exists
  def self.copy_element(dest, src, element_name, backup_val = nil)
    return if src.nil?

    element = src.elements[element_name]
    if not element.nil?
      dest << element.dup
    elsif not backup_val.nil?
      # Element didn't exist in src, assign backup value instead
      add_element(dest, element_name.split('/')[-1], backup_val)
    end
  end

  # Copies the multiple elements
  def self.copy_elements(dest, src, element_name)
    return if src.nil?

    if not src.elements[element_name].nil?
      src.elements.each(element_name) do |el|
        dest << el.dup
      end
    end
  end

  def self.validate(doc, xsd_path, runner = nil)
    if Gem::Specification::find_all_by_name('nokogiri').any?
      require 'nokogiri'
      xsd = Nokogiri::XML::Schema(File.open(xsd_path))
      doc = Nokogiri::XML(doc)
      return xsd.validate(doc)
    else
      if not runner.nil?
        runner.registerWarning('Could not load nokogiri, no HPXML validation performed.')
      end
      return []
    end
  end

  def self.create_doc(version = nil, encoding = nil, standalone = nil)
    doc = REXML::Document.new
    decl = REXML::XMLDecl.new(version = version, encoding = encoding, standalone = standalone)
    doc << decl
    return doc
  end

  def self.parse_file(hpxml_path)
    file_read = File.read(hpxml_path)
    hpxml_doc = REXML::Document.new(file_read)
    return hpxml_doc
  end

  def self.write_file(doc, out_path)
    # Write XML file
    formatter = REXML::Formatters::Pretty.new(2)
    formatter.compact = true
    formatter.width = 1000
    File.open(out_path, 'w', newline: :crlf) do |f|
      formatter.write(doc, f)
    end
  end
end

def Boolean(val)
  if val.is_a? TrueClass
    return true
  elsif val.is_a? FalseClass
    return false
  elsif (val.downcase.to_s == 'true') || (val == '1')
    return true
  elsif (val.downcase.to_s == 'false') || (val == '0')
    return false
  end

  raise TypeError.new("can't convert '#{val}' to Boolean")
end
