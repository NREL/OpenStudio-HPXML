require 'fileutils'

require 'rake'
require 'rake/testtask'
require 'ci/reporter/rake/minitest'

require 'pp'
require 'colored'
require 'json'

namespace :test do
  desc 'Run all tests'
  Rake::TestTask.new('all') do |t|
    t.libs << 'test'
    t.test_files = Dir['measures/*/tests/*.rb'] + Dir['workflow/tests/*.rb'] - Dir['measures/HPXMLtoOpenStudio/tests/*.rb'] # HPXMLtoOpenStudio is tested upstream
    t.warning = false
    t.verbose = true
  end
end

desc 'update all measures'
task :update_measures do
  require 'openstudio'
  measures_dir = File.expand_path("../measures/", __FILE__)

  # Apply rubocop
  command = "rubocop --auto-correct --format simple --only Layout"
  puts "Applying rubocop style to measures..."
  system(command)
end
