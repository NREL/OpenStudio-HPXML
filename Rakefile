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
