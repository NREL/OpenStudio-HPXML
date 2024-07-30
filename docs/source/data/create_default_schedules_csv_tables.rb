# frozen_string_literal: true

require_relative '../../../HPXMLtoOpenStudio/resources/hpxml_defaults.rb'

@default_schedules_csv_data = HPXMLDefaults.get_default_schedules_csv_data()

@default_schedules_csv_data.each do |schedule_name, elements_values|
  CSV.open(File.join(File.dirname(__FILE__), "#{schedule_name}.csv"), 'w') do |csv|
    csv << ['Schedule Name', 'Element', 'Values']
    elements_values.each do |element, values|
      csv << [schedule_name, element, values]
    end
  end
end
