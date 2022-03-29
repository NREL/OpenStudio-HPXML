# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'erb'
require 'json'

# start the measure
class ReportResStockHEScore < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'ReportResStockHEScore'
  end

  # human readable description
  def description
    return 'Reports out the HEScore inputs and calculates a score for the simulation.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Reports out the HEScore inputs and calculates a score for the simulation.'
  end

  # define the arguments that the user will input
  def arguments(model = nil)
    args = OpenStudio::Measure::OSArgumentVector.new

    # # bool argument to report report_drybulb_temp
    # report_drybulb_temp = OpenStudio::Measure::OSArgument.makeBoolArgument('report_drybulb_temp', true)
    # report_drybulb_temp.setDisplayName('Add output variables for Drybulb Temperature')
    # report_drybulb_temp.setDescription('Will add drybulb temp and report min/mix value in html.')
    # report_drybulb_temp.setValue(true)
    # args << report_drybulb_temp

    return args
  end

  # # define the outputs that the measure will create
  # def outputs
  #   outs = OpenStudio::Measure::OSOutputVector.new

  #   # this measure does not produce machine readable outputs with registerValue, return an empty list

  #   return outs
  # end

  # # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  # # Warning: Do not change the name of this method to be snake_case. The method must be lowerCamelCase.
  # def energyPlusOutputRequests(runner, user_arguments)
  #   super(runner, user_arguments)

  #   result = OpenStudio::IdfObjectVector.new

  #   # To use the built-in error checking we need the model...
  #   # get the last model and sql file
  #   model = runner.lastOpenStudioModel
  #   if model.empty?
  #     runner.registerError('Cannot find last model.')
  #     return false
  #   end
  #   model = model.get

  #   # use the built-in error checking
  #   if !runner.validateUserArguments(arguments(model), user_arguments)
  #     return false
  #   end

  #   if runner.getBoolArgumentValue('report_drybulb_temp', user_arguments)
  #     request = OpenStudio::IdfObject.load('Output:Variable,,Site Outdoor Air Drybulb Temperature,Hourly;').get
  #     result << request
  #   end

  #   return result
  # end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    # use the built-in error checking (need model)
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # # get measure arguments
    # report_drybulb_temp = runner.getBoolArgumentValue('report_drybulb_temp', user_arguments)

    # load sql file
    sql_file = runner.lastEnergyPlusSqlFile
    if sql_file.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sql_file = sql_file.get
    model.setSqlFile(sql_file)

    output_dir = File.dirname(sql_file.path.to_s)
    hes_json_path = File.join(output_dir, 'hes.json')

    # close the sql file
    sql_file.close()

    # Ensure sql file is immediately freed; otherwise we can get
    # errors on Windows when trying to delete this file.
    GC.start()

    hes_inputs = JSON.parse(File.read(hes_json_path))

    hes_inputs_flat = flatten(hes_inputs)

    hes_inputs_flat.each do |k, v|
      runner.registerValue(k, v)
    end

    return true
  end

  def flatten(obj, prefix=[])
    new_obj = {}
    if obj.is_a?(Hash)
      obj.each do |k, v|
        new_prefix = prefix + [k]
        flatten(v, new_prefix).each do |k2, v2|
          new_obj[k2] = v2
        end
      end
    elsif obj.is_a?(Array)
      obj.each_with_index do |v, i|
        new_prefix = prefix + [i.to_s]
        flatten(v, new_prefix).each do |k2, v2|
          new_obj[k2] = v2
        end
      end
    else
      new_obj[prefix.join('-')] = obj
    end
    return new_obj
  end
end

# register the measure to be used by the application
ReportResStockHEScore.new.registerWithApplication
