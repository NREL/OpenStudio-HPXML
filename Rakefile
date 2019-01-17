require 'rake'
require 'rake/testtask'
require 'ci/reporter/rake/minitest'

desc 'update all measures'
task :update_measures do
  # Apply rubocop
  command = "rubocop --auto-correct --format simple --only Layout"
  puts "Applying rubocop style to measures..."
  system(command)
end

def get_test_dirs(tests_dir)
  cfis_dir = File.absolute_path(File.join(tests_dir, "cfis"))
  hvac_dse_dir = File.absolute_path(File.join(tests_dir, "hvac_dse"))
  hvac_multiple_dir = File.absolute_path(File.join(tests_dir, "hvac_multiple"))
  hvac_partial_dir = File.absolute_path(File.join(tests_dir, "hvac_partial"))
  hvac_load_fracs_dir = File.absolute_path(File.join(tests_dir, "hvac_load_fracs"))
  hvac_autosizing_dir = File.absolute_path(File.join(tests_dir, "hvac_autosizing"))

  test_dirs = [tests_dir,
               cfis_dir,
               hvac_dse_dir,
               hvac_multiple_dir,
               hvac_partial_dir,
               hvac_load_fracs_dir,
               hvac_autosizing_dir]

  return test_dirs
end

def get_hpxml_values(doc)
  hpxml = {}

  # XMLTransactionHeaderInformation
  xml_transaction_header_information = doc.elements["/HPXML/XMLTransactionHeaderInformation"]

  # SoftwareInfo
  software_info = doc.elements["/HPXML/SoftwareInfo"]

  # Building
  building = doc.elements["/HPXML/Building"]

  # ProjectStatus
  project_status = building.elements["ProjectStatus"]

  # BuildingDetails
  building_details = building.elements["BuildingDetails"]
  
  # BuildingSummary
  building_summary = building_details.elements["BuildingSummary"]
  site = building_summary.elements["Site"]
  building_occupancy = building_summary.elements["BuildingOccupancy"]
  building_construction = building_summary.elements["BuildingConstruction"]
  
  # Appliances
  appliances = building_details.elements["Appliances"]
  clothes_dryer = appliances.elements["ClothesDryer"]

  # Get values
  hpxml[:xml_transaction_header_information] = HPXML.get_xml_transaction_header_information_values(xml_transaction_header_information: xml_transaction_header_information)
  hpxml[:software_info] = HPXML.get_software_info(software_info: software_info)
  hpxml[:site] = HPXML.get_site_values(site: site)
  hpxml[:building_occupancy] = HPXML.get_building_occupancy_values(building_occupancy: building_occupancy)
  hpxml[:building_construction] = HPXML.get_building_construction_values(building_construction: building_construction)
  hpxml[:clothes_dryer] = HPXML.get_clothes_dryer_values(clothes_dryer: clothes_dryer)

  return hpxml
end

desc 'generate all the hpxml files in the tests dir'
task :update_hpxmls do
  require_relative "resources/xmlhelper"
  require_relative "resources/hpxml"

  this_dir = File.dirname(__FILE__)

  parent_doc = XMLHelper.parse_file("#{this_dir}/tests/valid.xml")
  edited_doc = XMLHelper.parse_file("#{this_dir}/tests/valid.xml.edit")

  parent = get_hpxml_values(parent_doc)
  edited = get_hpxml_values(edited_doc)

  return if parent == edited

  tests_dir = "#{this_dir}/tests"
  test_dirs = get_test_dirs(tests_dir)

  test_dirs.each do |test_dir|
    Dir["#{test_dir}/valid-appliances-dryer-cef.xml*"].sort.each do |derivative_path|
      next if derivative_path.include? "valid.xml"

      hpxml = parent_doc.elements["/HPXML"]
      XMLHelper.delete_element(hpxml, "XMLTransactionHeaderInformation")
      XMLHelper.delete_element(hpxml, "SoftwareInfo")
      XMLHelper.delete_element(hpxml, "Building")

      # TODO: build up hpxml, using changes between parent and edited and derivative
      derivative = get_hpxml_values(XMLHelper.parse_file(File.absolute_path(derivative_path)))

      HPXML.add_xml_transaction_header_information(hpxml: hpxml,
                                                   xml_type: parent[:xml_transaction_header_information][:xml_type],
                                                   xml_generated_by: "rakefile",
                                                   created_date_and_time: parent[:xml_transaction_header_information][:created_date_and_time],
                                                   transaction: parent[:xml_transaction_header_information][:transaction])
      HPXML.add_software_info(hpxml: hpxml,
                              eri_calculation_version: parent[:software_info][:eri_calculation_version])
      # HPXML.add_building(hpxml: hpxml) # TODO: write this method in hpxml.rb
      # building = hpxml.elements["Building"]
      # HPXML.add_project_status(building: building) # TODO: write this method in hpxml.rb
      # ...
      
      XMLHelper.write_file(hpxml, derivative_path)

    end
  end

  # XMLHelper.write_file(edited_doc, "#{this_dir}/tests/valid.xml") # TODO: uncomment
end