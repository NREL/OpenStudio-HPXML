require 'fileutils'

require 'rake'
require 'rake/testtask'
require 'ci/reporter/rake/minitest'

require 'pp'
require 'colored'
require 'json'

namespace :test do
  desc 'Run all tests'
  Rake::TestTask.new('all') do |t|
    t.libs << 'test'
    t.test_files = Dir['measures/*/tests/*.rb'] + Dir['workflow/tests/*.rb'] - Dir['measures/HPXMLtoOpenStudio/tests/*.rb'] # HPXMLtoOpenStudio is tested upstream
    t.warning = false
    t.verbose = true
  end
end

desc 'update all measures'
task :update_measures do
  # Prevent NREL error regarding U: drive when not VPNed in
  ENV['HOME'] = 'C:' if !ENV['HOME'].nil? and ENV['HOME'].start_with? 'U:'
  ENV['HOMEDRIVE'] = 'C:\\' if !ENV['HOMEDRIVE'].nil? and ENV['HOMEDRIVE'].start_with? 'U:'

  # Apply rubocop
  command = "rubocop --auto-correct --format simple --only Layout"
  puts "Applying rubocop style to measures..."
  system(command)
end

# FUTURE: Remove everything below when we get updated files from HEScore API

desc 'migrate HPXML v3s'
task :migrate_v3_hpxmls do
  # Convert from old HPXML v3 to new HPXML v3 (for Enclosures change)
  require 'rexml/document'
  require 'rexml/xpath'
  require_relative 'measures/HPXMLtoOpenStudio/resources/xmlhelper.rb'
  require_relative 'measures/HEScoreRuleset/resources/HESvalidator.rb'

  this_dir = File.dirname(__FILE__)
  xsd_path = File.join(this_dir, "measures", "HPXMLtoOpenStudio", "hpxml_schemas", "HPXML.xsd")

  Dir["#{this_dir}/workflow/sample_files/*.xml*"].sort.each do |xml|
    puts xml
    hpxml_doc = REXML::Document.new(File.read(xml))
    enclosure = hpxml_doc.elements["/HPXML/Building/BuildingDetails/Enclosure"]
    walls = enclosure.elements["Walls"]
    windows = enclosure.elements["Windows"]

    # Roofs
    roofs = REXML::Element.new("Roofs")
    enclosure.elements.each("Attics/Attic") do |attic|
      attic.elements.each("Roofs/Roof") do |roof|
        id = roof.elements["SystemIdentifier"].attributes["id"]
        roofs << roof
        attached = XMLHelper.add_element(attic, "AttachedToRoof")
        XMLHelper.add_attribute(attached, "idref", id)
      end
      XMLHelper.delete_element(attic, "Roofs")
    end
    enclosure.insert_before(walls, roofs)

    # Foundation Walls
    fnd_walls = REXML::Element.new("FoundationWalls")
    has_fnd_walls = false
    enclosure.elements.each("Foundations/Foundation") do |foundation|
      foundation.elements.each("FoundationWall") do |fnd_wall|
        has_fnd_walls = true
        id = fnd_wall.elements["SystemIdentifier"].attributes["id"]
        fnd_walls << fnd_wall
        attached = XMLHelper.add_element(foundation, "AttachedToFoundationWall")
        XMLHelper.add_attribute(attached, "idref", id)
      end
      XMLHelper.delete_element(foundation, "FoundationWall")
    end
    enclosure.insert_before(windows, fnd_walls) if has_fnd_walls

    # Floors
    floors = REXML::Element.new("Floors")
    has_floors = false
    enclosure.elements.each("Attics/Attic") do |attic|
      attic.elements.each("Floors/Floor") do |floor|
        has_floors = true
        id = floor.elements["SystemIdentifier"].attributes["id"]
        floors << floor
        attached = XMLHelper.add_element(attic, "AttachedToFloor")
        XMLHelper.add_attribute(attached, "idref", id)
      end
      XMLHelper.delete_element(attic, "Floors")
    end
    enclosure.elements.each("Foundations/Foundation") do |foundation|
      foundation.elements.each("FrameFloor") do |floor|
        has_floors = true
        id = floor.elements["SystemIdentifier"].attributes["id"]
        new_floor = REXML::Element.new("Floor")
        floor.elements.each do |floor_element|
          new_floor << floor_element
        end
        floors << new_floor
        attached = XMLHelper.add_element(foundation, "AttachedToFloor")
        XMLHelper.add_attribute(attached, "idref", id)
      end
      XMLHelper.delete_element(foundation, "FrameFloor")
    end
    enclosure.insert_before(windows, floors) if has_floors

    # Slabs
    slabs = REXML::Element.new("Slabs")
    has_slabs = false
    enclosure.elements.each("Foundations/Foundation") do |foundation|
      foundation.elements.each("Slab") do |slab|
        has_slabs = true
        id = slab.elements["SystemIdentifier"].attributes["id"]
        slabs << slab
        attached = XMLHelper.add_element(foundation, "AttachedToSlab")
        XMLHelper.add_attribute(attached, "idref", id)
      end
      XMLHelper.delete_element(foundation, "Slab")
    end
    enclosure.insert_before(windows, slabs) if has_slabs

    # Validate against schema
    XMLHelper.write_file(hpxml_doc, xml)
    errors = XMLHelper.validate(hpxml_doc.to_s, xsd_path)
    errors.each do |error|
      puts error
    end
    fail if errors.size > 0

    # Validate against HESvalidator
    errors = HEScoreValidator.run_validator(hpxml_doc)
    errors.each do |error|
      puts error
    end
    fail if errors.size > 0
  end
end
