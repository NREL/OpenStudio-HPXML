# frozen_string_literal: true

def add_n_x_m(json, json2, expected_num_boreholes, n_x_m, key2 = nil)
  if key2.nil?
    actual_num_boreholes = json[n_x_m]['bore_locations'].size
    fail "#{expected_num_boreholes} vs #{actual_num_boreholes}" if expected_num_boreholes != actual_num_boreholes

    json2.update({ n_x_m => json[n_x_m] })  # FIXME: Change all n_x_m to m_x_n
  else
    actual_num_boreholes = json[n_x_m][key2]['bore_locations'].size
    fail "#{expected_num_boreholes} vs #{actual_num_boreholes}" if expected_num_boreholes != actual_num_boreholes

    json2.update({ n_x_m => { key2 => json[n_x_m][key2] } })
  end
end

def process_g_functions(filepath)
  # Downselect jsons found at https://gdr.openei.org/files/1325/g-function_library_1.0.zip
  require 'json'
  require 'zip'

  g_functions_path = File.dirname(filepath)
  Dir[File.join(filepath, '*.json')].each do |config_json|
    file = File.open(config_json)
    config_json = File.basename(config_json)
    puts "Processing #{config_json}..."
    json = JSON.load(file)

    json2 = {}
    case config_json
    when 'rectangle_5m_v1.0.json'
      add_n_x_m(json, json2, 1, '1_1')
      add_n_x_m(json, json2, 2, '1_2')
      add_n_x_m(json, json2, 3, '1_3')
      add_n_x_m(json, json2, 4, '2_2')
      add_n_x_m(json, json2, 5, '1_5')
      add_n_x_m(json, json2, 6, '2_3')
      add_n_x_m(json, json2, 7, '1_7')
      add_n_x_m(json, json2, 8, '2_4')
      add_n_x_m(json, json2, 9, '3_3')
      add_n_x_m(json, json2, 10, '2_5')
      add_n_x_m(json, json2, 40, '5_8') # test case
    when 'L_configurations_5m_v1.0.json'
      add_n_x_m(json, json2, 4, '2_3')
      add_n_x_m(json, json2, 5, '3_3')
      add_n_x_m(json, json2, 6, '3_4')
      add_n_x_m(json, json2, 7, '4_4')
      add_n_x_m(json, json2, 8, '4_5')
      add_n_x_m(json, json2, 9, '5_5')
      add_n_x_m(json, json2, 10, '5_6')
    when 'C_configurations_5m_v1.0.json'
      add_n_x_m(json, json2, 7, '3_3')
      add_n_x_m(json, json2, 9, '3_4')
    when 'LopU_configurations_5m_v1.0.json'
      add_n_x_m(json, json2, 6, '3_3', '1')
      add_n_x_m(json, json2, 7, '3_4', '2')
      add_n_x_m(json, json2, 8, '3_4', '1')
      add_n_x_m(json, json2, 9, '4_4', '1')
      add_n_x_m(json, json2, 10, '3_5', '1')
    when 'Open_configurations_5m_v1.0.json'
      add_n_x_m(json, json2, 8, '3_3')
      add_n_x_m(json, json2, 10, '3_4')
    when 'U_configurations_5m_v1.0.json'
      add_n_x_m(json, json2, 7, '3_3')
      add_n_x_m(json, json2, 9, '3_4')
      add_n_x_m(json, json2, 10, '4_4')
    when 'zoned_rectangle_5m_v1.0.json'
      add_n_x_m(json, json2, 17, '5_5', '1_1')
    else
      fail "Unrecognized config_json: #{config_json}"
    end

    configpath = File.join(g_functions_path, File.basename(config_json))
    File.open(configpath, 'w') do |f|
      json = JSON.pretty_generate(json2)
      f.write(json)
    end
  end

  FileUtils.rm_rf(filepath)

  num_configs_actual = Dir[File.join(g_functions_path, '*.json')].count

  return num_configs_actual
end
