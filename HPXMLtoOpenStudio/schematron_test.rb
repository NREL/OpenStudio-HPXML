require 'pathname'
require 'schematron-nokogiri'

file_dir = File.dirname(__FILE__)

# load the schematron xml
stron_doc = Nokogiri::XML File.open(File.join(file_dir, 'resources', 'EPvalidator.stron'))  # "/path/to/schema.stron"
# make a schematron object
stron = SchematronNokogiri::Schema.new stron_doc
# load the xml document you wish to validate
xml_doc = Nokogiri::XML File.open(File.join(File.dirname(file_dir), 'workflow', 'sample_files', 'base.xml'))  # "/path/to/xml_document.xml"
# validate it
results = stron.validate xml_doc
# print out the results
results.each do |error|
  puts "#{error[:line]}: #{error[:message]}"
end