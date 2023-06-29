# frozen_string_literal: true

def process_g_functions(filepath)
  # Downselect jsons found at https://gdr.openei.org/files/1325/g-function_library_1.0.zip
  require 'json'
  require 'zip'

  # downselect criteria
  n_x_m = 40 # for example, upper bound on number of boreholes

  g_functions_path = File.dirname(filepath)
  Dir[File.join(filepath, '*.json')].each do |config_json|
    file = File.open(config_json)
    json = JSON.load(file)

    # downselect the File
    json.keys.each do |n_m|
      n, m = n_m.split('_')
      json.delete(n_m) if (Float(n) * Float(m) > n_x_m)
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
