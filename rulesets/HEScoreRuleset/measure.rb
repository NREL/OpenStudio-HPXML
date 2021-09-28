# frozen_string_literal: true

require 'pathname'
require 'csv'
require 'oga'
require 'json'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/airflow'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/constants'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/constructions'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/geometry'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/hpxml'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/hpxml_defaults'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/hotwater_appliances'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/hvac'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/hvac_sizing'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/lighting'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/materials'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/misc_loads'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/psychrometrics'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/pv'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/schedules'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/unit_conversions'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/util'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/waterheater'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/weather'
require_relative '../../hpxml-measures/HPXMLtoOpenStudio/resources/xmlhelper'
require_relative 'resources/HESruleset'

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

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('json_path', true)
    arg.setDisplayName('JSON File Path')
    arg.setDescription('Absolute (or relative) path of the JSON file.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hpxml_output_path', false)
    arg.setDisplayName('HPXML Output File Path')
    arg.setDescription('Absolute (or relative) path of the output HPXML file.')
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
    json_path = runner.getStringArgumentValue('json_path', user_arguments)
    hpxml_output_path = runner.getOptionalStringArgumentValue('hpxml_output_path', user_arguments)

    unless (Pathname.new json_path).absolute?
      json_path = File.expand_path(File.join(File.dirname(__FILE__), json_path))
    end
    unless File.exist?(json_path) && json_path.downcase.end_with?('.json')
      runner.registerError("'#{json_path}' does not exist or is not an .json file.")
      return false
    end

    # Parse the JSON file
    json_file = File.open(json_path)
    json = JSON.parse(json_file.read)

    # Look up zipcode info
    zipcode_row = nil
    zipcode = json['building_address']['zip_code']
    zip_distance = 99999
    CSV.foreach(File.join(File.dirname(__FILE__), 'resources', 'zipcodes_wx.csv'), headers: true) do |row|
      zip3_of_interest = zipcode[0, 3]
      next unless row['postal_code'].start_with?(zip3_of_interest)

      distance = (Integer(Float(row['postal_code'])) - Integer(Float(zipcode))).abs()
      if distance < zip_distance
        zip_distance = distance
        zipcode_row = row
      end
      if distance == 0
        break # Exact match
      end
    end
    if zipcode_row.nil?
      fail "Zip code #{zipcode} could not be found in #{File.join(File.dirname(__FILE__), 'resources', 'zipcodes_wx.csv')}"
    end

    # Look up EPW path from WMO
    epw_path = nil
    weather_wmo = zipcode_row['nearest_weather_station']
    weather_dir = File.join(File.dirname(__FILE__), '..', '..', 'weather')
    CSV.foreach(File.join(weather_dir, 'data.csv'), headers: true) do |row|
      next if row['wmo'] != weather_wmo

      epw_path = File.join(weather_dir, row['filename'])
      if not File.exist?(epw_path)
        fail "'#{epw_path}' could not be found."
      end

      break
    end
    if epw_path.nil?
      fail "Weather station WMO '#{weather_wmo}' could not be found in #{File.join(weather_dir, 'data.csv')}."
    end

    cache_path = epw_path.gsub('.epw', '-cache.csv')
    if not File.exist?(cache_path)
      runner.registerError("'#{cache_path}' could not be found.")
      return false
    end

    # Obtain weather object
    weather = WeatherProcess.new(nil, nil, cache_path)

    begin
      new_hpxml = HEScoreRuleset.apply_ruleset(json, weather, zipcode_row)
    rescue Exception => e
      runner.registerError("#{e.message}\n#{e.backtrace.join("\n")}")
      return false
    end

    # Write new HPXML file
    if hpxml_output_path.is_initialized
      XMLHelper.write_file(new_hpxml.to_oga, hpxml_output_path.get)
      runner.registerInfo("Wrote file: #{hpxml_output_path.get}")
    end

    return true
  end
end

# register the measure to be used by the application
HEScoreMeasure.new.registerWithApplication
