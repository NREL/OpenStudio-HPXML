require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class HPXMLTranslatorTest < MiniTest::Test

  def test_valid_simulations
    Dir["#{File.dirname(__FILE__)}/valid*.xml"].sort.each do |xml|
      puts xml
      _test_measure(xml)
    end
  end

  def _test_measure(hpxml_name)
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(File.dirname(__FILE__), hpxml_name))
    args_hash['weather_dir'] = File.join(File.dirname(__FILE__), "..", "weather")
    args_hash['epw_output_path'] = File.join(File.dirname(__FILE__), "in.epw")
    args_hash['osm_output_path'] = File.join(File.dirname(__FILE__), "in.osm")
    
    # create an instance of the measure
    measure = HPXMLTranslator.new
    
    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    model = OpenStudio::Model::Model.new

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # show the output
    # show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)

  end
  
  def _test_simulation
  
  end
  
end