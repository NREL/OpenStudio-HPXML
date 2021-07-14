# frozen_string_literal: true

command_list = [:update_measures]

def display_usage(command_list)
  puts "Usage: openstudio #{File.basename(__FILE__)} [COMMAND]\nCommands:\n  " + command_list.join("\n  ")
end

if ARGV.size == 0
  puts 'ERROR: Missing command.'
  display_usage(command_list)
  exit!
elsif ARGV.size > 1
  puts 'ERROR: Too many commands.'
  display_usage(command_list)
  exit!
elsif not command_list.include? ARGV[0].to_sym
  puts "ERROR: Invalid command '#{ARGV[0]}'."
  display_usage(command_list)
  exit!
end

if ARGV[0].to_sym == :update_measures
  # Prevent NREL error regarding U: drive when not VPNed in
  ENV['HOME'] = 'C:' if !ENV['HOME'].nil? && ENV['HOME'].start_with?('U:')
  ENV['HOMEDRIVE'] = 'C:\\' if !ENV['HOMEDRIVE'].nil? && ENV['HOMEDRIVE'].start_with?('U:')

  # Apply rubocop
  cops = ['Layout',
          'Lint/DeprecatedClassMethods',
          # 'Lint/RedundantStringCoercion', # Enable when rubocop is upgraded
          'Style/AndOr',
          'Style/FrozenStringLiteralComment',
          'Style/HashSyntax',
          'Style/Next',
          'Style/NilComparison',
          'Style/RedundantParentheses',
          'Style/RedundantSelf',
          'Style/ReturnNil',
          'Style/SelfAssignment',
          'Style/StringLiterals',
          'Style/StringLiteralsInInterpolation']
  commands = ["\"require 'rubocop/rake_task'\"",
              "\"RuboCop::RakeTask.new(:rubocop) do |t| t.options = ['--auto-correct', '--format', 'simple', '--only', '#{cops.join(',')}'] end\"",
              '"Rake.application[:rubocop].invoke"']
  command = "#{OpenStudio.getOpenStudioCLI} -e #{commands.join(' -e ')}"
  puts 'Applying rubocop auto-correct to measures...'
  system(command)

  # Update measures XMLs
  require 'oga'
  require_relative 'hpxml-measures/HPXMLtoOpenStudio/resources/xmlhelper'
  puts 'Updating measure.xmls...'
  Dir['**/measure.xml'].each do |measure_xml|
    for n_attempt in 1..5 # For some reason CLI randomly generates errors, so try multiple times; FIXME: Fix CLI so this doesn't happen
      measure_dir = File.dirname(measure_xml)
      command = "#{OpenStudio.getOpenStudioCLI} measure -u '#{measure_dir}'"
      system(command, [:out, :err] => File::NULL)

      # Check for error
      xml_doc = XMLHelper.parse_file(measure_xml)
      err_val = XMLHelper.get_value(xml_doc, '/measure/error', :string)
      if err_val.nil?
        err_val = XMLHelper.get_value(xml_doc, '/error', :string)
      end
      if err_val.nil?
        break # Successfully updated
      else
        if n_attempt == 5
          fail "#{measure_xml}: #{err_val}" # Error generated all 5 times, fail
        else
          # Remove error from measure XML, try again
          new_lines = File.readlines(measure_xml).select { |l| !l.include?('<error>') }
          File.open(measure_xml, 'w') do |file|
            file.puts new_lines
          end
        end
      end
    end
  end

  puts 'Done.'
end
