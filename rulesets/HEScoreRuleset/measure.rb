# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'openstudio'
require 'rexml/document'
require 'rexml/xpath'
require 'pathname'
require_relative "resources/HESruleset"
require_relative "../../hpxml-measures/HPXMLtoOpenStudio/resources/xmlhelper"

# start the measure
class HEScoreMeasure < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Apply Home Energy Score Ruleset'
  end

  # human readable description
  def description
    return ''
  end

  # human readable description of modeling approach
  def modeler_description
    return ''
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Measure::OSArgument.makeStringArgument("hpxml_path", true)
    arg.setDisplayName("HPXML File Path")
    arg.setDescription("Absolute (or relative) path of the HPXML file.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument("hpxml_output_path", false)
    arg.setDisplayName("HPXML Output File Path")
    arg.setDescription("Absolute (or relative) path of the output HPXML file.")
    args << arg

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    hpxml_path = runner.getStringArgumentValue("hpxml_path", user_arguments)
    hpxml_output_path = runner.getOptionalStringArgumentValue("hpxml_output_path", user_arguments)

    unless (Pathname.new hpxml_path).absolute?
      hpxml_path = File.expand_path(File.join(File.dirname(__FILE__), hpxml_path))
    end
    unless File.exists?(hpxml_path) and hpxml_path.downcase.end_with? ".xml"
      runner.registerError("'#{hpxml_path}' does not exist or is not an .xml file.")
      return false
    end

    hpxml_doc = REXML::Document.new(File.read(hpxml_path))

    begin
      new_hpxml_doc = HEScoreRuleset.apply_ruleset(hpxml_doc)
    rescue Exception => e
      runner.registerError("#{e.message}\n#{e.backtrace.join("\n")}")
      return false
    end

    # Write new HPXML file
    if hpxml_output_path.is_initialized
      XMLHelper.write_file(new_hpxml_doc, hpxml_output_path.get)
      runner.registerInfo("Wrote file: #{hpxml_output_path.get}")
    end

    return true
  end
end

# register the measure to be used by the application
HEScoreMeasure.new.registerWithApplication
