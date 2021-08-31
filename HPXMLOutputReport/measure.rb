# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require_relative 'resources/constants.rb'

# start the measure
class HPXMLOutputReport < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'HPXML Output Report'
  end

  # human readable description
  def description
    return 'Reports HPXML outputs for residential HPXML-based models'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'TODO'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    format_chs = OpenStudio::StringVector.new
    format_chs << 'csv'
    format_chs << 'json'
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('output_format', format_chs, false)
    arg.setDisplayName('Output Format')
    arg.setDescription('The file format of the annual (and timeseries, if requested) outputs.')
    arg.setDefaultValue('csv')
    args << arg

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    puts 'HERE0'
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find OpenStudio model.')
      return false
    end
    @model = model.get
    puts 'HERE1'
    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    output_format = runner.getStringArgumentValue('output_format', user_arguments)
    puts 'HERE2'
    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError('Cannot find EnergyPlus sql file.')
      return false
    end
    @sqlFile = sqlFile.get
    if not @sqlFile.connectionOpen
      runner.registerError('EnergyPlus simulation failed.')
      return false
    end
    @model.setSqlFile(@sqlFile)
    puts 'HERE3'
    hpxml_defaults_path = @model.getBuilding.additionalProperties.getFeatureAsString('hpxml_defaults_path').get
    @hpxml_defaults_path = HPXML.new(hpxml_path: hpxml_defaults_path)

    # Set paths
    output_dir = File.dirname(@sqlFile.path.to_s)
    annual_output_path = File.join(output_dir, "hpxml_output.#{output_format}")
    puts 'HERE4'
    @sqlFile.close()

    # Ensure sql file is immediately freed; otherwise we can get
    # errors on Windows when trying to delete this file.
    GC.start()

    # Cost Multipliers
    @cost_multipliers = {}
    @cost_multipliers[BS::Fixed] = BaseOutput.new
    @cost_multipliers[BS::WallAreaAboveGradeConditioned] = BaseOutput.new
    @cost_multipliers[BS::WallAreaAboveGradeExterior] = BaseOutput.new
    @cost_multipliers[BS::WallAreaBelowGrade] = BaseOutput.new
    @cost_multipliers[BS::FloorAreaConditioned] = BaseOutput.new
    @cost_multipliers[BS::FloorAreaAttic] = BaseOutput.new
    @cost_multipliers[BS::FloorAreaLighting] = BaseOutput.new
    @cost_multipliers[BS::RoofArea] = BaseOutput.new
    @cost_multipliers[BS::WindowArea] = BaseOutput.new
    @cost_multipliers[BS::DoorArea] = BaseOutput.new
    @cost_multipliers[BS::DuctUnconditionedSurfaceArea] = BaseOutput.new
    @cost_multipliers[BS::SizeHeatingSystem] = BaseOutput.new
    @cost_multipliers[BS::SizeSecondaryHeatingSystem] = BaseOutput.new
    @cost_multipliers[BS::SizeHeatPumpBackup] = BaseOutput.new
    @cost_multipliers[BS::SizeCoolingSystem] = BaseOutput.new
    @cost_multipliers[BS::SizeWaterHeater] = BaseOutput.new
    @cost_multipliers[BS::FlowRateMechanicalVentilation] = BaseOutput.new
    @cost_multipliers[BS::SlabPerimeterExposedConditioned] = BaseOutput.new
    @cost_multipliers[BS::RimJoistAreaAboveGradeExterior] = BaseOutput.new
    puts 'HERE5'
    @cost_multipliers.each do |cost_mult_type, cost_mult|
      cost_mult.name = "Building Summary: #{cost_mult_type}"
      if cost_mult_type.include?('Area')
        cost_mult.annual_units = 'ft^2'
      elsif cost_mult_type.include?('Perimeter')
        cost_mult.annual_units = 'ft'
      elsif cost_mult_type.include?('Size')
        if cost_mult_type.include?('Heating') || cost_mult_type.include?('Cooling') || cost_mult_type.include?('Heat Pump')
          cost_mult.annual_units = 'kBtu/h'
        else
          cost_mult.annual_units = 'gal'
        end
      elsif cost_mult_type.include?('Flow')
        cost_mult.annual_units = 'cfm'
      else
        cost_mult.annual_units = '1'
      end
    end

    # Cost Multipliers
    @cost_multipliers.each do |cost_mult_type, cost_mult|
      cost_mult.annual_output = HPXML::get_cost_multiplier(@hpxml_defaults_path, cost_mult_type)
    end

    # Write/report results
    results_out = []
    @cost_multipliers.each do |key, cost_mult|
      results_out << ["#{cost_mult.name} (#{cost_mult.annual_units})", cost_mult.annual_output.round(2)]
    end
    puts 'HERE6'
    if output_format == 'csv'
      CSV.open(annual_output_path, 'wb') { |csv| results_out.to_a.each { |elem| csv << elem } }
    elsif output_format == 'json'
      h = {}
      results_out.each do |out|
        next if out == [line_break]

        grp, name = out[0].split(':', 2)
        h[grp] = {} if h[grp].nil?
        h[grp][name.strip] = out[1]
      end

      require 'json'
      File.open(annual_output_path, 'w') { |json| json.write(JSON.pretty_generate(h)) }
    end
    runner.registerInfo("Wrote annual output results to #{annual_output_path}.")
    puts 'HERE7'
    return true
  end
end

# register the measure to be used by the application
HPXMLOutputReport.new.registerWithApplication
