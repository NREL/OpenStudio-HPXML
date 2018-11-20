# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'openstudio'
require 'rexml/document'
require 'rexml/xpath'
require 'pathname'
require "#{File.dirname(__FILE__)}/resources/HESvalidator"
require "#{File.dirname(__FILE__)}/../HPXMLtoOpenStudio/resources/xmlhelper"

# start the measure
class HEScoreRuleset < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Apply Home Energy Score Ruleset'
  end

  # human readable description
  def description
    return 'TODO'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'TODO'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Measure::OSArgument.makeStringArgument("hpxml_path", true)
    arg.setDisplayName("HPXML File Path")
    arg.setDescription("Absolute (or relative) path of the HPXML file.")
    args << arg
    
    arg = OpenStudio::Measure::OSArgument.makeStringArgument("schemas_dir", false)
    arg.setDisplayName("HPXML Schemas Directory")
    arg.setDescription("Absolute path of the hpxml schemas directory.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument("skip_validation", true)
    arg.setDisplayName("Skip HPXML validation")
    arg.setDescription("If true, only checks for and reports HPXML validation issues if an error occurs during processing. Used for faster runtime.")
    arg.setDefaultValue(false)
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
    schemas_dir = runner.getOptionalStringArgumentValue("schemas_dir", user_arguments)
    skip_validation = runner.getBoolArgumentValue("skip_validation", user_arguments)

    unless (Pathname.new hpxml_path).absolute?
      hpxml_path = File.expand_path(File.join(File.dirname(__FILE__), hpxml_path))
    end
    unless File.exists?(hpxml_path) and hpxml_path.downcase.end_with? ".xml"
      runner.registerError("'#{hpxml_path}' does not exist or is not an .xml file.")
      return false
    end

    hpxml_doc = REXML::Document.new(File.read(hpxml_path))
    
    # Check for invalid HPXML file up front?
    if not skip_validation
      if not validate_hpxml(runner, hpxml_path, hpxml_doc, schemas_dir)
        return false
      end
    end
    
    # TODO...

    return true
  end
  
  def validate_hpxml(runner, hpxml_path, hpxml_doc, schemas_dir)
    is_valid = true

    if schemas_dir.is_initialized
      schemas_dir = schemas_dir.get
      unless (Pathname.new schemas_dir).absolute?
        schemas_dir = File.expand_path(File.join(File.dirname(__FILE__), schemas_dir))
      end
      unless Dir.exists?(schemas_dir)
        runner.registerError("'#{schemas_dir}' does not exist.")
        return false
      end
    else
      schemas_dir = nil
    end

    # Validate input HPXML against schema
    if not schemas_dir.nil?
      XMLHelper.validate(hpxml_doc.to_s, File.join(schemas_dir, "HPXML.xsd"), runner).each do |error|
        runner.registerError("#{hpxml_path}: #{error.to_s}")
        is_valid = false
      end
      runner.registerInfo("#{hpxml_path}: Validated against HPXML schema.")
    else
      runner.registerWarning("#{hpxml_path}: No schema dir provided, no HPXML validation performed.")
    end

    # Validate input HPXML against HEScore Use Case
    errors = HEScoreValidator.run_validator(hpxml_doc)
    errors.each do |error|
      runner.registerError("#{hpxml_path}: #{error}")
      is_valid = false
    end
    runner.registerInfo("#{hpxml_path}: Validated against HPXML HEScore Use Case.")

    return is_valid
  end
end

# register the measure to be used by the application
HEScoreRuleset.new.registerWithApplication
