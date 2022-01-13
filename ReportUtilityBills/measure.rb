# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class ReportUtilityBills < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Utility Bills Report'
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
  def arguments(model = nil)
    args = OpenStudio::Measure::OSArgumentVector.new

    electricity_bill_type_choices = OpenStudio::StringVector.new
    electricity_bill_type_choices << 'Simple'
    electricity_bill_type_choices << 'Detailed'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('electricity_bill_type', electricity_bill_type_choices, true)
    arg.setDisplayName('Electricity: Simple or Detailed')
    arg.setDescription("Choose either 'Simple' or 'Detailed'. If 'Simple' is selected, electric utility bills are calculated based on user-defined fixed charge and marginal rate. If 'Detailed' is selected, electric utility bills are calculated based on either: a tariff from the OpenEI Utility Rate Database (URDB), or a real-time pricing rate.")
    arg.setDefaultValue('Simple')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('electricity_fixed_charge', true)
    arg.setDisplayName('Electricity: Fixed Charge')
    arg.setUnits('$/month')
    arg.setDescription('Monthly fixed charge for electricity.')
    arg.setDefaultValue('12.0')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('electricity_marginal_rate', true)
    arg.setDisplayName('Electricity: Marginal Rate')
    arg.setUnits('$/kWh')
    arg.setDescription("Price per kilowatt-hour for electricity. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg




    arg = OpenStudio::Measure::OSArgument::makeStringArgument('natural_gas_fixed_charge', true)
    arg.setDisplayName('Natural Gas: Fixed Charge')
    arg.setUnits('$/month')
    arg.setDescription('Monthly fixed charge for natural gas.')
    arg.setDefaultValue('8.0')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('natural_gas_marginal_rate', true)
    arg.setDisplayName('Natural Gas: Marginal Rate')
    arg.setUnits('$/therm')
    arg.setDescription("Price per therm for natural gas. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg




    arg = OpenStudio::Measure::OSArgument::makeStringArgument('fuel_oil_marginal_rate', true)
    arg.setDisplayName('Fuel Oil: Marginal Rate')
    arg.setUnits('$/gal')
    arg.setDescription("Price per gallon for fuel oil. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg




    arg = OpenStudio::Measure::OSArgument::makeStringArgument('propane_marginal_rate', true)
    arg.setDisplayName('Propane: Marginal Rate')
    arg.setUnits('$/gal')
    arg.setDescription("Price per gallon for propane. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg




    arg = OpenStudio::Measure::OSArgument::makeStringArgument('wood_marginal_rate', true)
    arg.setDisplayName('Wood: Marginal Rate')
    arg.setUnits('$/gal')
    arg.setDescription("Price per gallon for propane. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg



    arg = OpenStudio::Measure::OSArgument::makeStringArgument('wood_pellets_marginal_rate', true)
    arg.setDisplayName('Wood Pellets: Marginal Rate')
    arg.setUnits('$/gal')
    arg.setDescription("Price per gallon for propane. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg



    arg = OpenStudio::Measure::OSArgument::makeStringArgument('coal_marginal_rate', true)
    arg.setDisplayName('Coal: Marginal Rate')
    arg.setUnits('$/gal')
    arg.setDescription("Price per gallon for propane. Use '#{Constants.Auto} for state-average value from EIA.")
    arg.setDefaultValue(Constants.Auto)
    args << arg



    return args
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find OpenStudio model.')
      return false
    end
    model = model.get

    # use the built-in error checking (need model)
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    args = get_argument_values(runner, arguments(model), user_arguments)
    args = Hash[args.collect { |k, v| [k.to_sym, v] }]

puts args

    return true
  end
end

# register the measure to be used by the application
ReportUtilityBills.new.registerWithApplication
