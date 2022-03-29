# frozen_string_literal: true

require_relative '../../../hpxml-measures/HPXMLtoOpenStudio/resources/minitest_helper'
require_relative '../../../hpxml-measures/HPXMLtoOpenStudio/resources/xmlhelper.rb'
require 'oga'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require_relative '../measure.rb'
require 'fileutils'

class HPXMLtoHEScoreTest < MiniTest::Test
  def test_translation
    this_dir = File.dirname(__FILE__)

    args_hash = {}

    Dir["#{this_dir}/../../../hescore-hpxml/examples/*.xml"].sort.each do |hpxml|
      args_hash['hpxml_path'] = File.absolute_path(hpxml)
      args_hash['output_path'] = File.absolute_path(hpxml).gsub('.xml', '.json.out')
      
      hpxml_doc = XMLHelper.get_element(XMLHelper.parse_file(args_hash['hpxml_path']), '/HPXML')
      software_program = XMLHelper.get_element(XMLHelper.get_element(hpxml_doc, 'SoftwareInfo'), 'SoftwareProgramUsed')
      if not software_program.nil?
        software_program = software_program.inner_text
      end
      next unless software_program == 'ResStock'  # only test resstock-generated xmls

      puts "Testing #{File.absolute_path(hpxml)}..."

      _test_measure(args_hash)
      FileUtils.rm_f(args_hash['output_path']) # Cleanup
    end
  end


  def _test_measure(args_hash)
    # create an instance of the measure
    measure = HPXMLtoHEScore.new

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
    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
  end

end
