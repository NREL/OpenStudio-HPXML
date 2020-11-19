# frozen_string_literal: true

start_time = Time.now

require 'fileutils'
require 'optparse'
require 'pathname'
require_relative '../HPXMLtoOpenStudio/resources/meta_measure'
require_relative '../HPXMLtoOpenStudio/resources/version'

basedir = File.expand_path(File.dirname(__FILE__))

def run_workflow(basedir, rundir, hpxml, debug, timeseries_output_freq, timeseries_outputs)
  measures_dir = File.join(basedir, '..')

  measures = {}

  # Add HPXML translator measure to workflow
  measure_subdir = 'HPXMLtoOpenStudio'
  args = {}
  args['hpxml_path'] = hpxml
  args['output_dir'] = rundir
  args['debug'] = debug
  update_args_hash(measures, measure_subdir, args)

  # Add reporting measure to workflow
  measure_subdir = 'SimulationOutputReport'
  args = {}
  args['timeseries_frequency'] = timeseries_output_freq
  args['include_timeseries_fuel_consumptions'] = timeseries_outputs.include? 'fuels'
  args['include_timeseries_end_use_consumptions'] = timeseries_outputs.include? 'enduses'
  args['include_timeseries_hot_water_uses'] = timeseries_outputs.include? 'hotwater'
  args['include_timeseries_total_loads'] = timeseries_outputs.include? 'loads'
  args['include_timeseries_component_loads'] = timeseries_outputs.include? 'componentloads'
  args['include_timeseries_zone_temperatures'] = timeseries_outputs.include? 'temperatures'
  args['include_timeseries_airflows'] = timeseries_outputs.include? 'airflows'
  args['include_timeseries_weather'] = timeseries_outputs.include? 'weather'
  update_args_hash(measures, measure_subdir, args)

  results = run_hpxml_workflow(rundir, hpxml, measures, measures_dir, debug: debug)

  return results[:success]
end

timeseries_types = ['ALL', 'fuels', 'enduses', 'hotwater', 'loads', 'componentloads', 'temperatures', 'airflows', 'weather']

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} -x building.xml\n e.g., #{File.basename(__FILE__)} -x base.xml\n"

  opts.on('-x', '--xml <FILE>', 'HPXML file') do |t|
    options[:hpxml] = t
  end

  opts.on('-o', '--output-dir <DIR>', 'Output directory') do |t|
    options[:output_dir] = t
  end

  options[:hourly_outputs] = []
  opts.on('--hourly TYPE', timeseries_types, "Request hourly output type (#{timeseries_types[0..4].join(', ')},", "#{timeseries_types[5..-1].join(', ')}); can be called multiple times") do |t|
    options[:hourly_outputs] << t
  end

  options[:daily_outputs] = []
  opts.on('--daily TYPE', timeseries_types, "Request daily output type (#{timeseries_types[0..4].join(', ')},", "#{timeseries_types[5..-1].join(', ')}); can be called multiple times") do |t|
    options[:daily_outputs] << t
  end

  options[:monthly_outputs] = []
  opts.on('--monthly TYPE', timeseries_types, "Request monthly output type (#{timeseries_types[0..4].join(', ')},", "#{timeseries_types[5..-1].join(', ')}); can be called multiple times") do |t|
    options[:monthly_outputs] << t
  end

  options[:timestep_outputs] = []
  opts.on('--timestep TYPE', timeseries_types, "Request timestep output type (#{timeseries_types[0..4].join(', ')},", "#{timeseries_types[5..-1].join(', ')}); can be called multiple times") do |t|
    options[:timestep_outputs] << t
  end

  options[:version] = false
  opts.on('-v', '--version', 'Reports the version') do |t|
    options[:version] = true
  end

  options[:debug] = false
  opts.on('-d', '--debug') do |t|
    options[:debug] = true
  end

  opts.on_tail('-h', '--help', 'Display help') do
    puts opts
    exit!
  end
end.parse!

if options[:version]
  puts "OpenStudio-HPXML v#{Version::OS_HPXML_Version}"
  exit!
end

if not options[:hpxml]
  fail "HPXML argument is required. Call #{File.basename(__FILE__)} -h for usage."
end

timeseries_output_freq = 'none'
timeseries_outputs = []
n_freq = 0
if not options[:hourly_outputs].empty?
  n_freq += 1
  timeseries_output_freq = 'hourly'
  timeseries_outputs = options[:hourly_outputs]
end
if not options[:daily_outputs].empty?
  n_freq += 1
  timeseries_output_freq = 'daily'
  timeseries_outputs = options[:daily_outputs]
end
if not options[:monthly_outputs].empty?
  n_freq += 1
  timeseries_output_freq = 'monthly'
  timeseries_outputs = options[:monthly_outputs]
end
if not options[:timestep_outputs].empty?
  n_freq += 1
  timeseries_output_freq = 'timestep'
  timeseries_outputs = options[:timestep_outputs]
end

if n_freq > 1
  fail 'Multiple timeseries frequencies (hourly, daily, monthly, timestep) are not supported.'
end

if timeseries_outputs.include? 'ALL'
  timeseries_outputs = timeseries_types[1..-1]
end

unless (Pathname.new options[:hpxml]).absolute?
  options[:hpxml] = File.expand_path(options[:hpxml])
end
unless File.exist?(options[:hpxml]) && options[:hpxml].downcase.end_with?('.xml')
  fail "'#{options[:hpxml]}' does not exist or is not an .xml file."
end

if options[:output_dir].nil?
  options[:output_dir] = File.dirname(options[:hpxml]) # default
end
options[:output_dir] = File.expand_path(options[:output_dir])

unless Dir.exist?(options[:output_dir])
  FileUtils.mkdir_p(options[:output_dir])
end

# Create run dir
rundir = File.join(options[:output_dir], 'run')

# Run design
puts "HPXML: #{options[:hpxml]}"
success = run_workflow(basedir, rundir, options[:hpxml], options[:debug], timeseries_output_freq, timeseries_outputs)

if not success
  exit! 1
end

puts "Completed in #{(Time.now - start_time).round(1)} seconds."
