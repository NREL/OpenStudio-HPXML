# frozen_string_literal: true

def process_g_functions(filepath)
  # Downselect jsons found at https://gdr.openei.org/files/1325/g-function_library_1.0.zip
  require 'json'
  require 'zip'

  g_functions_path = File.dirname(filepath)
  Dir[File.join(filepath, '*.json')].each do |config_json|
    file = File.open(config_json)
    json = JSON.load(file)
    # downselect the File for JSON files with 2 layers of keys
    if config_json.include?('zoned_rectangle_5m_v1.0.json') || config_json.include?('C_configurations_5m_v1.0.json') || config_json.include?('LopU_configurations_5m_v1.0.json') || config_json.include?('Open_configurations_5m_v1.0.json') || config_json.include?('U_configurations_5m_v1.0.json')
      json.keys.each do |n_m|
        n, m = n_m.split('_')
        if n_m != '5_8' && (n.to_i > 10 || m.to_i > 10)
          json.delete(n_m)
        else
          json[n_m].keys.each do |sub_key|
            if json[n_m][sub_key].key?('bore_locations') && json[n_m][sub_key]['bore_locations'].length > 10
              json[n_m].delete(sub_key)
            end
          end
        end
      end
    else
      # downselect the File for JSON files with 1 layer of keys
      json.keys.each do |n_m|
        # n, m = n_m.split('_')
        bore_locations = json[n_m]['bore_locations']
        if n_m != '5_8' && (bore_locations && bore_locations.length > 10)
          json.delete(n_m)
        end
      end
    end

    configpath = File.join(g_functions_path, File.basename(config_json))
    File.open(configpath, 'w') do |f|
      json = JSON.pretty_generate(json)
      f.write(json)
    end
  end

  FileUtils.rm_rf(filepath)

  num_configs_actual = Dir[File.join(g_functions_path, '*.json')].count

  return num_configs_actual
end
