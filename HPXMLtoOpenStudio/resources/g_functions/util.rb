# frozen_string_literal: true

def process_g_functions(filepath)
  # Downselect jsons found at https://gdr.openei.org/files/1325/g-function_library_1.0.zip
  require 'json'
  require 'zip'

  g_functions_path = File.dirname(filepath)
  Dir[File.join(filepath, '*.json')].each do |config_json|
    file = File.open(config_json)
    json = JSON.load(file)

    json.each do |key_1, value_1|
      if value_1.key?('bore_locations')
        bore_locations = json[key_1]['bore_locations']
        if config_json.include?('rectangle')
          if key_1 != '5_8' && (bore_locations.length > 10)
            json.delete(key_1)
          end
        elsif (bore_locations.length > 10)
          json.delete(key_1)
        elsif config_json.include?('LopU')
          value_1.each do |key_2, value_2|
            bore_locations = value_1[key_2]['bore_locations']
            if (bore_locations.length > 10)
              json.delete(key_1)
            end
          end
        end
      else
        value_1.each do |key_2, value_2|
          bore_locations = value_1[key_2]['bore_locations']
          if (bore_locations.length > 10)
            json.delete(key_1)
          end
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
