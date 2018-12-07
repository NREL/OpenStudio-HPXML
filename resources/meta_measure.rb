# Helper methods related to having a meta-measure

def apply_measures(measures_dir, measures, runner, model, workflow_json = nil, osw_out = nil, show_measure_calls = true)
  require 'openstudio'

  workflow_order = []
  if workflow_json.nil?
    measures.keys.each do |measure_subdir|
      workflow_order << measure_subdir
    end
  else
    # Run measures in the order dictated by the json instead
    JSON.parse(File.read(workflow_json), :symbolize_names => true).each do |group|
      group[:group_steps].each do |step|
        step[:measures].each do |measure_subdir|
          next unless measures.keys.include? measure_subdir

          workflow_order << measure_subdir
        end
      end
    end
    # Tack additional measure not found in workflow_json on the end
    measures.keys.each do |measure_subdir|
      next if workflow_order.include? measure_subdir

      workflow_order << measure_subdir
    end
  end

  if not osw_out.nil?
    # Create a workflow based on the measures we're going to call. Convenient for debugging.
    workflowJSON = OpenStudio::WorkflowJSON.new
    workflowJSON.setOswPath(File.expand_path("../#{osw_out}"))
    workflowJSON.addMeasurePath("measures")
    steps = OpenStudio::WorkflowStepVector.new
    workflow_order.each do |measure_subdir|
      measures[measure_subdir].each do |args|
        step = OpenStudio::MeasureStep.new(measure_subdir)
        args.each do |k, v|
          next if v.nil?

          step.setArgument(k, v)
        end
        steps.push(step)
      end
    end
    workflowJSON.setWorkflowSteps(steps)
    workflowJSON.save
  end

  # Call each measure in the specified order
  workflow_order.each do |measure_subdir|
    # Gather measure arguments and call measure
    full_measure_path = File.join(measures_dir, measure_subdir, "measure.rb")
    check_file_exists(full_measure_path, runner)
    measure_instance = get_measure_instance(full_measure_path)
    measures[measure_subdir].each do |args|
      argument_map = get_argument_map(model, measure_instance, args, nil, measure_subdir, runner)
      if show_measure_calls
        print_measure_call(args, measure_subdir, runner)
      end

      if not run_measure(model, measure_instance, argument_map, runner)
        return false
      end
    end
  end

  return true
end

def print_measure_call(measure_args, measure_dir, runner)
  if measure_args.nil? or measure_dir.nil?
    return
  end

  args_s = hash_to_string(measure_args, delim = " -> ", separator = " \n")
  if args_s.size > 0
    runner.registerInfo("Calling #{measure_dir.to_s} measure with arguments:\n#{args_s}")
  else
    runner.registerInfo("Calling #{measure_dir.to_s} measure with no arguments.")
  end
end

def get_measure_instance(measure_rb_path)
  # Parse XML file for class name
  require 'rexml/document'
  require 'rexml/xpath'
  xmldoc = REXML::Document.new(File.read(measure_rb_path.sub(".rb", ".xml")))
  measure_class = REXML::XPath.first(xmldoc, "//measure/class_name").text
  # Create new instance
  require (File.absolute_path(measure_rb_path))
  measure = eval(measure_class).new
  return measure
end

def validate_measure_args(measure_args, provided_args, lookup_file, measure_name, runner = nil)
  measure_arg_names = measure_args.map { |arg| arg.name }
  lookup_file_str = ""
  if not lookup_file.nil?
    lookup_file_str = " in #{lookup_file.to_s}"
  end
  # Verify all arguments have been provided
  measure_args.each do |arg|
    next if provided_args.keys.include?(arg.name)
    next if not arg.required

    register_error("Required argument '#{arg.name}' not provided#{lookup_file_str} for measure '#{measure_name.to_s}'.", runner)
  end
  provided_args.keys.each do |k|
    next if measure_arg_names.include?(k)

    register_error("Extra argument '#{k}' specified#{lookup_file_str} for measure '#{measure_name.to_s}'.", runner)
  end
  # Check for valid argument values
  measure_args.each do |arg|
    # Get measure provided arg
    if provided_args[arg.name].nil?
      if arg.required
        register_error("Required argument '#{arg.name.to_s}' for measure '#{measure_name.to_s}' must have a value provided.", runner)
      else
        next
      end
    else
      provided_args[arg.name] = provided_args[arg.name].to_s
    end
    case arg.type.valueName.downcase
    when "boolean"
      if not ['true', 'false'].include?(provided_args[arg.name])
        register_error("Value of '#{provided_args[arg.name].to_s}' for argument '#{arg.name.to_s}' and measure '#{measure_name.to_s}' must be 'true' or 'false'.", runner)
      end
    when "double"
      if not provided_args[arg.name].is_number?
        register_error("Value of '#{provided_args[arg.name].to_s}' for argument '#{arg.name.to_s}' and measure '#{measure_name.to_s}' must be a number.", runner)
      end
    when "integer"
      if not provided_args[arg.name].is_integer?
        register_error("Value of '#{provided_args[arg.name].to_s}' for argument '#{arg.name.to_s}' and measure '#{measure_name.to_s}' must be an integer.", runner)
      end
    when "string"
    # no op
    when "choice"
      if not arg.choiceValues.include?(provided_args[arg.name]) and not arg.modelDependent
        register_error("Value of '#{provided_args[arg.name].to_s}' for argument '#{arg.name.to_s}' and measure '#{measure_name.to_s}' must be one of: #{arg.choiceValues.to_s}.", runner)
      end
    end
  end
  return provided_args
end

def get_argument_map(model, measure, provided_args, lookup_file, measure_name, runner = nil)
  require 'openstudio'
  measure_args = measure.arguments(model)
  provided_args = validate_measure_args(measure_args, provided_args, lookup_file, measure_name, runner)

  # Convert to argument map needed by OS
  argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(measure_args)
  measure_args.each do |arg|
    temp_arg_var = arg.clone
    if !provided_args[arg.name].nil?
      temp_arg_var.setValue(provided_args[arg.name])
    end
    argument_map[arg.name] = temp_arg_var
  end
  return argument_map
end

def run_measure(model, measure, argument_map, runner)
  require 'openstudio'
  begin
    # run the measure
    runner_child = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    if model.instance_of? OpenStudio::Workspace
      runner_child.setLastOpenStudioModel(runner.lastOpenStudioModel.get)
    end
    measure.run(model, runner_child, argument_map)
    result_child = runner_child.result

    # get initial and final condition
    if result_child.initialCondition.is_initialized
      runner.registerInitialCondition(result_child.initialCondition.get.logMessage)
    end
    if result_child.finalCondition.is_initialized
      runner.registerFinalCondition(result_child.finalCondition.get.logMessage)
    end

    # log messages
    result_child.warnings.each do |warning|
      runner.registerWarning(warning.logMessage)
    end
    result_child.info.each do |info|
      runner.registerInfo(info.logMessage)
    end
    result_child.errors.each do |error|
      runner.registerError(error.logMessage)
    end
    if result_child.errors.size > 0
      return false
    end

    # convert a return false in the measure to a return false and error here.
    if result_child.value.valueName == "Fail"
      runner.registerError("The measure was not successful")
      return false
    end
  rescue => e
    runner.registerError("Measure Failed with Error: #{e.backtrace.join("\n")}")
    return false
  end
  return true
end

def hash_to_string(hash, delim = "=", separator = ",")
  hash_s = ""
  hash.each do |k, v|
    hash_s << "#{k.to_s}#{delim.to_s}#{v.to_s}#{separator.to_s}"
  end
  if hash_s.size > 0
    hash_s = hash_s.chomp(separator.to_s)
  end
  return hash_s
end

def register_error(msg, runner = nil)
  if not runner.nil?
    runner.registerError(msg)
    fail msg # OS 2.0 will handle this more gracefully
  else
    raise "ERROR: #{msg}"
  end
end

def check_file_exists(full_path, runner = nil)
  if not File.exist?(full_path)
    register_error("Cannot find file #{full_path.to_s}.", runner)
  end
end

def check_dir_exists(full_path, runner = nil)
  if not Dir.exist?(full_path)
    register_error("Cannot find directory #{full_path.to_s}.", runner)
  end
end

def update_args_hash(hash, key, args, add_new = true)
  if not hash.keys.include? key
    hash[key] = [args]
  elsif add_new
    hash[key] << args
  else # merge new arguments into existing
    args.each do |k, v|
      hash[key][0][k] = v
    end
  end
end

class String
  def is_number?
    true if Float(self) rescue false
  end

  def is_integer?
    if not self.is_number?
      return false
    end
    if Integer(Float(self)).to_f != Float(self)
      return false
    end

    return true
  end
end
