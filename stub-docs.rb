debug = false

new_folder = 'documented'
FileUtils.rm_rf(new_folder) if File.exist?(new_folder)

files = []
# files = ['HPXMLtoOpenStudio/resources/hpxml.rb']
['BuildResidentialHPXML', 'BuildResidentialScheduleFile', 'HPXMLtoOpenStudio', 'ReportSimulationOutput', 'ReportUtilityBills'].each do |folder|
  files += Dir[File.join(folder, 'resources/*.rb')]
end

def get_params(lines, idx)
  params = []
  descs = []
  ret = nil
  lines[0..idx - 1].reverse.each_with_index do |line, i|
    if line.include?('# @param')
      l = line.strip.split(' ')
      params << [l[2], l[3], l[4..-1].join(' ')]
    elsif line.include?('# @return')
      l = line.strip.split(' ')
      ret = [l[2], l[3..-1].join(' ')]
    elsif line.strip == '#' # blank line
      # no-op
    elsif line.strip.start_with?('#')
      descs << line.strip
    else
      return params, descs, ret, idx - i
    end
  end
end

def set_params(lines, idx, params, descs, ret, tab, is_method)
  if is_method
    if ret.nil?
      lines.insert(idx, "#{tab}# @return [TODO] TODO")
    else
      lines.insert(idx, "#{tab}# @return #{ret[0]} #{ret[1]}")
    end
    params.each do |param|
      lines.insert(idx, "#{tab}# @param #{param[0]} #{param[1]} #{param[2]}")
    end
    lines.insert(idx, "#{tab}#")
  end
  descs = ['# TODO'] if descs.empty?
  descs.each do |desc|
    lines.insert(idx, "#{tab}#{desc}")
  end

  return lines
end

def common_parameters(param, type, desc)
  params = [['model', '[OpenStudio::Model::Model]', 'model object'],
            ['runner', '[OpenStudio::Measure::OSRunner]', 'runner object'],
            ['hpxml', '[HPXML]', 'hpxml object'],
            ['hpxml_bldg', '[HPXML::Building]', 'individual HPXML Building dwelling unit object'],
            ['weather', '[WeatherProcess]', 'TODO'],
            ['epw_file', '[OpenStudio::EpwFile]', 'TODO'],
            ['space', '[OpenStudio::Model::Space]', 'OpenStudio Space object'],
            ['surface', '[OpenStudio::Model::Surface]', 'OpenStudio Surface object']]
  params.each do |p|
    next if p[0] != param

    type = p[1] if type == '[TODO]'
    desc = p[2] if type == 'TODO'
  end
  return type, desc
end

files.each do |file|
  puts "File: #{file}"

  lines = File.readlines(file)

  new_path = File.join(new_folder, file)
  new_parent_folder = File.dirname(new_path)
  FileUtils.mkdir_p(new_parent_folder) if !File.exist?(new_parent_folder)

  previous_classes = ObjectSpace.each_object(Class).to_a

  require_relative file

  new_classes = ObjectSpace.each_object(Class).to_a - previous_classes
  new_classes.each do |new_class|
    # classes
    class_found = false
    start_idx = nil
    end_idx = nil
    descs = []
    lines.each_with_index do |line, i|
      next if not (line.strip.start_with?('class ') && line.strip.include?("#{new_class} "))

      class_found = true
      end_idx = i
      _params, descs, _ret, start_idx = get_params(lines, end_idx)
    end

    if not end_idx.nil? # class found in file
      (start_idx..end_idx - 1).to_a.reverse.each do |idx|
        lines.delete_at(idx)
      end

      set_params(lines, start_idx, [], descs, nil, '', false)
    end

    # methods
    methods = new_class.methods(false)
    methods.each do |method|
      # next if method.to_s != 'is_adiabatic'

      all_params = []
      new_class.method(method).parameters.each do |req, param|
        next if req == :keyrest

        all_params << param.to_s
      end

      start_idx = nil
      end_idx = nil
      documented_params = []
      new_params = []
      descs = []
      ret = nil
      lines.each_with_index do |line, i|
        next if not (line.strip.start_with?('def ') && (line.strip.include?("#{method}(") || line.strip.end_with?("#{method}")) && class_found)

        class_found = false
        end_idx = i
        documented_params, descs, ret, start_idx = get_params(lines, end_idx)

        if debug
          puts
          puts "Method: #{method}"
          puts "Parameters: #{all_params}"
          puts "@params: #{params1}"
          puts "Description: #{descs}"
        end

        all_params.reverse.each do |param|
          type = '[TODO]'
          desc = 'TODO'
          documented_params.each do |p|
            next if p[0] != param

            type = p[1]
            desc = p[2]
          end
          type, desc = common_parameters(param, type, desc)
          new_params << [param, type, desc]
        end
      end

      next if end_idx.nil? # method not found in file

      (start_idx..end_idx - 1).to_a.reverse.each do |idx|
        lines.delete_at(idx)
      end

      set_params(lines, start_idx, new_params, descs, ret, '  ', true)
    end # end methods
  end # end new_classes

  File.open(new_path, 'w') do |f|
    f.puts(lines)
  end
end # end file
