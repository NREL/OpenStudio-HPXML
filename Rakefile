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

def update_derivative_doc(parent_doc, edit_doc, derivative_docs, xpath)
  parent_doc_text = XMLHelper.get_first(parent_doc, xpath).text
  edit_doc_text = XMLHelper.get_first(edit_doc, xpath).text
  if parent_doc_text != edit_doc_text
    derivative_docs.each do |derivative_path, derivative_doc|
      derivative_doc_text = XMLHelper.get_first(derivative_doc, xpath).text
      next if parent_doc_text != derivative_doc_text
      XMLHelper.get_first(derivative_doc, xpath).text = edit_doc_text
      derivative_docs[derivative_path] = derivative_doc
    end
  end

  return derivative_docs
end

desc 'generate all the hpxml files in the tests dir'
task :update_hpxmls do
  require_relative "resources/xmlhelper"

  this_dir = File.dirname(__FILE__)

  parent_path = "#{this_dir}/tests/valid.xml"
  parent_doc = XMLHelper.parse_file(parent_path)


end




