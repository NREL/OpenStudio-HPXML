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

desc 'generate all the hpxml files in the tests dir'
task :update_hpxmls do
  require_relative "resources/xmlhelper"
  require_relative "resources/hpxml"

  this_dir = File.dirname(__FILE__)

  parent_doc = XMLHelper.parse_file("#{this_dir}/tests/valid.xml")
  edited_doc = XMLHelper.parse_file("#{this_dir}/tests/valid.xml.edit")

  parent = HPXML.get_hpxml_values(parent_doc)
  edited = HPXML.get_hpxml_values(edited_doc)

  return if parent == edited

  tests_dir = "#{this_dir}/tests"
  test_dirs = get_test_dirs(tests_dir)

  test_dirs.each do |test_dir|
    Dir["#{test_dir}/valid-appliances-dryer-cef.xml*"].sort.each do |derivative_path|
      next if derivative_path.include? "valid.xml"

      # derivative = get_hpxml_values(XMLHelper.parse_file(File.absolute_path(derivative_path)))

      doc = HPXML.create_hpxml(xml_generated_by: "rakefile",
                               transaction: parent[:xml_transaction_header_information][:transaction],
                               software_program_used: parent[:software_info][:software_program_used],
                               software_program_version: parent[:software_info][:software_program_version],
                               eri_calculation_version: parent[:software_info][:eri_calculation_version],
                               building_id: parent[:building][:id],
                               event_type: parent[:project_status][:event_type])
      hpxml = doc.elements["HPXML"]
      building_details = hpxml.elements["Building/BuildingDetails"]
      building_summary = building_details.elements["BuildingSummary"]
      unless parent[:site].nil?
        HPXML.add_site(building_summary: building_summary,
                       fuels: parent[:site][:fuels],
                       shelter_coefficient: parent[:site][:shelter_coefficient])
      end
      unless parent[:building_occupancy].nil?
        HPXML.add_building_occupancy(building_summary: building_summary,
                                     number_of_residents: parent[:building_occupancy][:number_of_residents])
      end
      HPXML.add_building_construction(building_summary: building_summary,
                                      number_of_conditioned_floors: parent[:building_construction][:number_of_conditioned_floors],
                                      number_of_conditioned_floors_above_grade: parent[:building_construction][:number_of_conditioned_floors_above_grade],
                                      number_of_bedrooms: parent[:building_construction][:number_of_bedrooms],
                                      conditioned_floor_area: parent[:building_construction][:conditioned_floor_area],
                                      conditioned_building_volume: parent[:building_construction][:conditioned_building_volume],
                                      garage_present: parent[:building_construction][:garage_present])
      climate_and_risk_zones = XMLHelper.add_element(building_details, "ClimateandRiskZones")
      unless parent[:climate_zone_iecc].empty?
        parent[:climate_zone_iecc].each do |climate_zone_iecc|
          HPXML.add_climate_zone_iecc(climate_and_risk_zones: climate_and_risk_zones,
                                      year: climate_zone_iecc[:year],
                                      climate_zone: climate_zone_iecc[:climate_zone])
        end
      end
      unless parent[:weather_station].nil?
        HPXML.add_weather_station(climate_and_risk_zones: climate_and_risk_zones,
                                  id: parent[:weather_station][:id],
                                  name: parent[:weather_station][:name],
                                  wmo: parent[:weather_station][:wmo])
      end
      enclosure = XMLHelper.add_element(building_details, "Enclosure")
      unless parent[:air_infiltration_measurement].empty?
        air_infiltration = XMLHelper.add_element(enclosure, "AirInfiltration")
        parent[:air_infiltration_measurement].each do |air_infiltration_measurement|
          HPXML.add_air_infiltration_measurement(air_infiltration: air_infiltration,
                                                 id: air_infiltration_measurement[:id],
                                                 house_pressure: air_infiltration_measurement[:house_pressure],
                                                 unit_of_measure: air_infiltration_measurement[:unit_of_measure],
                                                 air_leakage: air_infiltration_measurement[:air_leakage],
                                                 effective_leakage_area: air_infiltration_measurement[:effective_leakage_area])
        end
      end
      # Attics
      # Foundations
      # RimJoists
      # Walls
      # Windows
      # Doors
      # TODO: ...

      formatter = REXML::Formatters::Pretty.new(2)
      formatter.compact = true # This is the magic line that does what you need!
      formatter.write(doc, $stdout)
      # XMLHelper.write_file(hpxml, derivative_path)
    end
  end

  # XMLHelper.write_file(edited_doc, "#{this_dir}/tests/valid.xml") # TODO: uncomment
end
