require 'rake'
require 'rake/testtask'
require 'ci/reporter/rake/minitest'

desc 'update all measures'
task :update_measures do
  # Apply rubocop
  command = "rubocop --auto-correct --format simple --only Layout"
  puts "Applying rubocop style to measures..."
  system(command)
end

desc 'generate all the hpxml files in the tests dir'
task :update_hpxmls do
  require 'git'
  require_relative "resources/xmlhelper"

  this_dir = File.dirname(__FILE__)

  g = Git.open(this_dir)
  puts g.diff('tests/valid.xml')

  parent_path = "#{this_dir}/tests/valid.xml"
  parent_doc = XMLHelper.parse_file(parent_path)

  tests_dir = "#{this_dir}/tests"
  cfis_dir = File.absolute_path(File.join(tests_dir, "cfis"))
  hvac_dse_dir = File.absolute_path(File.join(tests_dir, "hvac_dse"))
  hvac_multiple_dir = File.absolute_path(File.join(tests_dir, "hvac_multiple"))
  hvac_partial_dir = File.absolute_path(File.join(tests_dir, "hvac_partial"))
  hvac_load_fracs_dir = File.absolute_path(File.join(tests_dir, "hvac_load_fracs"))
  hvac_autosizing_dir = File.absolute_path(File.join(tests_dir, "hvac_autosizing"))

  test_dirs = [tests_dir,
               cfis_dir,
               hvac_dse_dir,
               hvac_multiple_dir,
               hvac_partial_dir,
               hvac_load_fracs_dir,
               hvac_autosizing_dir]

  test_dirs.each do |test_dir|
    Dir["#{test_dir}/valid*.xml*"].sort.each do |derivative_path|
      next if derivative_path.include? "valid.xml"
      derivative_path = File.absolute_path(derivative_path)
      derivative_doc = XMLHelper.parse_file(derivative_path)
    end
  end

end