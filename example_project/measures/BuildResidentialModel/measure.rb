# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'openstudio'

# require gem for merge measures
# was able to harvest measure paths from primary osw for meta osw. Remove this once confirm that works
#require 'openstudio-model-articulation'
#require 'measures/merge_spaces_from_external_file/measure.rb'

resources_dir = File.absolute_path(File.join(File.dirname(__FILE__), 'resources'))
meta_measure_file = File.join(resources_dir, 'meta_measure.rb')
require File.join(File.dirname(meta_measure_file), File.basename(meta_measure_file, File.extname(meta_measure_file)))

# start the measure
class BuildResidentialModel < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Build Residential Model'
  end

  # human readable description
  def description
    return 'Builds the OpenStudio Model for an existing residential building.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Builds the residential OpenStudio Model using the geojson feature file, which contains the specified parameters for each existing building.'
  end

  # define the arguments that the user will input
  def arguments(model)
    measures_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/hpxml-measures'))
    measure_subdir = 'BuildResidentialHPXML'
    full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
    measure = get_measure_instance(full_measure_path)

    args = OpenStudio::Measure::OSArgumentVector.new
    measure.arguments(model).each do |arg|
      next if ['hpxml_path', 'weather_dir'].include? arg.name
      args << arg
    end

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
    measures_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/hpxml-measures'))
    measure_subdir = 'BuildResidentialHPXML'
    full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
    check_file_exists(full_measure_path, runner)
    measure = get_measure_instance(full_measure_path)
    args = measure.get_argument_values(runner, user_arguments)

    # optionals: get or remove
    args.keys.each do |arg|
      begin # TODO: how to check if arg is an optional or not?
        if args[arg].is_initialized
          args[arg] = args[arg].get
        else
          args.delete(arg)
        end
      rescue
      end
    end

    # apply whole building create geometry measures
    measures_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../../measures'))
    check_dir_exists(measures_dir, runner)

    if args[:geometry_unit_type] == 'single-family detached'
      measure_subdir = 'ResidentialGeometryCreateSingleFamilyDetached'
    elsif args[:geometry_unit_type] == 'single-family attached'
      measure_subdir = 'ResidentialGeometryCreateSingleFamilyAttached'
    elsif args[:geometry_unit_type] == 'apartment unit'
      measure_subdir = 'ResidentialGeometryCreateMultifamily'
    end

    full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
    check_file_exists(full_measure_path, runner)
    measure = get_measure_instance(full_measure_path)

    measure_args = {}
    whole_building_model = OpenStudio::Model::Model.new
    get_measure_args_default_values(whole_building_model, measure_args, measure)

    measures = {}
    measures[measure_subdir] = []
    if ['ResidentialGeometryCreateSingleFamilyAttached', 'ResidentialGeometryCreateMultifamily'].include? measure_subdir
      measure_args[:unit_ffa] = args[:geometry_cfa]
      measure_args[:num_floors] = args[:geometry_num_floors_above_grade]
      measure_args[:num_units] = args[:geometry_num_units]
    end
    measure_args = Hash[measure_args.collect{ |k, v| [k.to_s, v] }]
    measures[measure_subdir] << measure_args

    if not apply_measures(measures_dir, measures, runner, whole_building_model, nil, nil, true)
      return false
    end

    # get file/dir paths
    resources_dir = File.absolute_path(File.join(File.dirname(__FILE__), 'resources'))
    workflow_json = File.join(resources_dir, 'measure-info.json')

    # apply HPXML measures
    measures_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/hpxml-measures'))
    check_dir_exists(measures_dir, runner)

    whole_building_model.getBuildingUnits.each_with_index do |unit, num_unit|
      unit_model = OpenStudio::Model::Model.new

      # BuildResidentialHPXML
      measure_subdir = 'BuildResidentialHPXML'

      # fill the measure args hash with default values
      measure_args = args

      measures = {}
      measures[measure_subdir] = []
      measure_args[:hpxml_path] = File.expand_path('../out.xml')
      measure_args[:weather_dir] = File.expand_path('../../../../weather')
      measure_args[:software_program_used] = 'URBANopt'
      measure_args[:software_program_version] = '0.3.1'
      if unit.additionalProperties.getFeatureAsString('GeometryLevel').is_initialized
        measure_args[:geometry_level] = unit.additionalProperties.getFeatureAsString('GeometryLevel').get
      end
      if unit.additionalProperties.getFeatureAsString('GeometryHorizontalLocation').is_initialized
        measure_args[:geometry_horizontal_location] = unit.additionalProperties.getFeatureAsString('GeometryHorizontalLocation').get
      end
      measure_args = Hash[measure_args.collect{ |k, v| [k.to_s, v] }]
      measures[measure_subdir] << measure_args

      # HPXMLtoOpenStudio
      measure_subdir = 'HPXMLtoOpenStudio'
      full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
      check_file_exists(full_measure_path, runner)

      # fill the measure args hash with default values
      measure_args = {}

      measures[measure_subdir] = []
      measure_args[:hpxml_path] = File.expand_path('../out.xml')
      measure_args[:weather_dir] = File.expand_path('../../../../weather')
      measure_args[:output_dir] = File.expand_path('..')
      measure_args[:debug] = true
      measure_args = Hash[measure_args.collect{ |k, v| [k.to_s, v] }]
      measures[measure_subdir] << measure_args

      if not apply_measures(measures_dir, measures, runner, unit_model, workflow_json, 'out.osw', true)
        return false
      end

      unit_dir = File.expand_path("../unit #{num_unit+1}")
      Dir.mkdir(unit_dir)
      FileUtils.cp(File.expand_path('../out.xml'), unit_dir) # this is the raw hpxml file
      FileUtils.cp(File.expand_path('../out.osw'), unit_dir) # this has hpxml measure arguments in it
      FileUtils.cp(File.expand_path('../in.osm'), unit_dir) # this is osm translated from hpxml

      if whole_building_model.getBuildingUnits.length == 1
        model.getBuilding.remove
        model.getShadowCalculation.remove
        model.getSimulationControl.remove
        model.getSite.remove
        model.getTimestep.remove

        model.addObjects(unit_model.objects, true)
        next
      end

      # create building unit object to assign to spaces
      building_unit = OpenStudio::Model::BuildingUnit.new(unit_model)
      building_unit.setName("building_unit_#{num_unit}")

      # save modified copy of model for use with merge
      unit_model.getSpaces.sort.each do |space|
        space.setYOrigin(60 * (num_unit-1)) # meters
        space.setBuildingUnit(building_unit)
      end

      # prefix all objects with name using unit number. May be cleaner if source models are setup with unique names
      unit_model.objects.each do |model_object|
        next if model_object.name.nil?
        model_object.setName("unit_#{num_unit} #{model_object.name.to_s}")
      end

      moodified_unit_path = File.join(unit_dir, 'modified_unit.osm')
      unit_model.save(moodified_unit_path, true)

      # run merge merge_spaces_from_external_file to add this unit to original model
      merge_measures_dir = nil
      osw_measure_paths = runner.workflow.measurePaths
      osw_measure_paths.each do |orig_measure_path|
        next if not orig_measure_path.to_s.include?('gems/openstudio-model-articulation')
        merge_measures_dir = orig_measure_path.to_s
        break
      end
      merge_measure_subdir = 'merge_spaces_from_external_file'
      merge_measures = {}
      merge_measure_args = {}
      merge_measures[merge_measure_subdir] = []
      merge_measure_args[:external_model_name] = moodified_unit_path
      merge_measure_args[:merge_geometry] = true
      merge_measure_args[:merge_loads] = true
      merge_measure_args[:merge_attribute_names] = true
      merge_measure_args[:add_spaces] = true
      merge_measure_args[:remove_spaces] = false
      merge_measure_args[:merge_schedules] = true
      merge_measure_args[:compact_to_ruleset] = false
      merge_measure_args[:merge_zones] = true
      merge_measure_args[:merge_air_loops] = true
      merge_measure_args[:merge_plant_loops] = true
      merge_measure_args[:merge_swh] = true
      merge_measure_args = Hash[merge_measure_args.collect{ |k, v| [k.to_s, v] }]
      merge_measures[merge_measure_subdir] << merge_measure_args

      # for this instance pass in original model and not unit_model. unit_model path witll be an argument
      if not apply_measures(merge_measures_dir, merge_measures, runner, model, workflow_json, 'out.osw', true)
        return false
      end

    end

    # TODO: add surface intersection and matching (is don't in measure now but would be better to do once at end, make bool to skip in merge measure)

    return true
  end

  def get_measure_args_default_values(model, args, measure)
    measure.arguments(model).each do |arg|
      next unless arg.hasDefaultValue

      case arg.type.valueName.downcase
      when "boolean"
        args[arg.name] = arg.defaultValueAsBool
      when "double"
        args[arg.name] = arg.defaultValueAsDouble
      when "integer"
        args[arg.name] = arg.defaultValueAsInteger
      when "string"
        args[arg.name] = arg.defaultValueAsString
      when "choice"
        args[arg.name] = arg.defaultValueAsString
      end
    end
  end
end

# register the measure to be used by the application
BuildResidentialModel.new.registerWithApplication
