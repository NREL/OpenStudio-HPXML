start_time = Time.now

require 'optparse'
require 'pathname'
require_relative "../measures/HPXMLtoOpenStudio/resources/meta_measure"

# TODO: Add error-checking
# TODO: Add standardized reporting of errors

basedir = File.expand_path(File.dirname(__FILE__))

def rm_path(path)
  if Dir.exists?(path)
    FileUtils.rm_r(path)
  end
  while true
    break if not Dir.exists?(path)

    sleep(0.01)
  end
end

def get_designdir(basedir, design)
  return File.join(basedir, design.gsub(' ', ''))
end

def get_output_hpxml_path(resultsdir, designdir)
  return File.join(resultsdir, File.basename(designdir) + ".xml")
end

def run_design(basedir, design, resultsdir, hpxml, debug, skip_validation)
  # Use print instead of puts in here (see https://stackoverflow.com/a/5044669)
  print "Creating input...\n"
  output_hpxml_path, rundir = create_idf(design, basedir, resultsdir, hpxml, debug, skip_validation)

  print "Running simulation...\n"
  run_energyplus(design, rundir)

  return output_hpxml_path
end

def create_idf(design, basedir, resultsdir, hpxml, debug, skip_validation)
  designdir = get_designdir(basedir, design)
  Dir.mkdir(designdir)

  rundir = File.join(designdir, "run")
  Dir.mkdir(rundir)

  OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Fatal)

  output_hpxml_path = get_output_hpxml_path(resultsdir, designdir)

  model = OpenStudio::Model::Model.new
  runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
  measures_dir = File.join(File.dirname(__FILE__), "../measures")

  measures = {}

  # Add HEScore measure to workflow
  measure_subdir = "HEScoreRuleset"
  args = {}
  args['hpxml_path'] = hpxml
  # args['weather_dir'] = File.absolute_path(File.join(basedir, "..", "weather"))
  # args['schemas_dir'] = File.absolute_path(File.join(basedir, "..", "hpxml_schemas"))
  args['hpxml_output_path'] = output_hpxml_path
  args['skip_validation'] = skip_validation
  update_args_hash(measures, measure_subdir, args)

  # Add HPXML translator measure to workflow
  measure_subdir = "HPXMLtoOpenStudio"
  args = {}
  args['hpxml_path'] = output_hpxml_path
  args['weather_dir'] = File.absolute_path(File.join(basedir, "..", "weather"))
  # args['schemas_dir'] = File.absolute_path(File.join(basedir, "..", "hpxml_schemas"))
  args['epw_output_path'] = File.join(rundir, "in.epw")
  if debug
    args['osm_output_path'] = File.join(rundir, "in.osm")
  end
  args['skip_validation'] = skip_validation
  update_args_hash(measures, measure_subdir, args)

  # Apply measures
  success = apply_measures(measures_dir, measures, runner, model, nil, nil, true)

  # Report warnings/errors
  File.open(File.join(designdir, 'run.log'), 'w') do |f|
    if debug
      runner.result.stepInfo.each do |s|
        f << "Info: #{s}\n"
      end
    end
    runner.result.stepWarnings.each do |s|
      f << "Warning: #{s}\n"
    end
    runner.result.stepErrors.each do |s|
      f << "Error: #{s}\n"
    end
  end

  if not success
    fail "Simulation unsuccessful for #{design}."
  end

  # Write model to IDF
  forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
  model_idf = forward_translator.translateModel(model)
  File.open(File.join(rundir, "in.idf"), 'w') { |f| f << model_idf.to_s }

  return output_hpxml_path, rundir
end

def run_energyplus(design, rundir)
  # getEnergyPlusDirectory can be unreliable, using getOpenStudioCLI instead
  ep_path = File.absolute_path(File.join(OpenStudio.getOpenStudioCLI.to_s, '..', '..', 'EnergyPlus', 'energyplus'))
  command = "cd #{rundir} && #{ep_path} -w in.epw in.idf > stdout-energyplus"
  system(command, :err => File::NULL)
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} -x building.xml\n e.g., #{File.basename(__FILE__)} -s -x sample_files/valid.xml\n"

  opts.on('-x', '--xml <FILE>', 'HPXML file') do |t|
    options[:hpxml] = t
  end

  options[:debug] = false
  opts.on('-d', '--debug') do |t|
    options[:debug] = true
  end

  options[:skip_validation] = false
  opts.on('-s', '--skip-validation') do |t|
    options[:skip_validation] = true
  end

  opts.on_tail('-h', '--help', 'Display help') do
    puts opts
    exit!
  end
end.parse!

if not options[:hpxml]
  fail "HPXML argument is required. Call #{File.basename(__FILE__)} -h for usage."
end

unless (Pathname.new options[:hpxml]).absolute?
  options[:hpxml] = File.expand_path(options[:hpxml])
end
unless File.exists?(options[:hpxml]) and options[:hpxml].downcase.end_with? ".xml"
  fail "'#{options[:hpxml]}' does not exist or is not an .xml file."
end

# Check for correct versions of OS
os_version = "2.7.0"
if OpenStudio.openStudioVersion != os_version
  fail "OpenStudio version #{os_version} is required."
end

# Create results dir
resultsdir = File.join(basedir, "results")
rm_path(resultsdir)
Dir.mkdir(resultsdir)

# Run design
puts "HPXML: #{options[:hpxml]}"
design = "HEScoreDesign"
designdir = get_designdir(basedir, design)
rm_path(designdir)
output_hpxml_path = run_design(basedir, design, resultsdir, options[:hpxml], options[:debug], options[:skip_validation])

# TODO: Output...

puts "Completed in #{(Time.now - start_time).round(1)} seconds."
