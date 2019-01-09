
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

  edit_path = "#{this_dir}/tests/valid.xml.edit"
  edit_doc = XMLHelper.parse_file(edit_path)

  if parent_doc.to_s == edit_doc.to_s
    puts "You have not made any edit(s) to 'valid.xml.edit'."
    next
  end

  tests_dir = "#{this_dir}/tests"
  cfis_dir = File.absolute_path(File.join(tests_dir, "cfis"))
  hvac_dse_dir = File.absolute_path(File.join(tests_dir, "hvac_dse"))
  hvac_multiple_dir = File.absolute_path(File.join(tests_dir, "hvac_multiple"))
  hvac_partial_dir = File.absolute_path(File.join(tests_dir, "hvac_partial"))
  hvac_load_fracs_dir = File.absolute_path(File.join(tests_dir, "hvac_load_fracs"))
  autosize_dir = File.absolute_path(File.join(tests_dir, "hvac_autosizing"))

  test_dirs = [tests_dir,
               cfis_dir,
               hvac_dse_dir,
               hvac_multiple_dir,
               hvac_partial_dir,
               hvac_load_fracs_dir,
               autosize_dir]

  original_derivative_docs = {}
  test_dirs.each do |test_dir|
    Dir["#{test_dir}/valid*.xml*"].sort.each do |derivative_path|
      next if derivative_path.include? "valid.xml"
      derivative_path = File.absolute_path(derivative_path)
      original_derivative_docs[derivative_path] = XMLHelper.parse_file(derivative_path)
    end
  end

  derivative_docs = Marshal.load(Marshal.dump(original_derivative_docs))
  parent_doc.elements.each do |parent|
    parent.elements.each do |child1|
      child1.elements.each do |child2|
        if child2.elements.size == 0
          xpath = "/HPXML/#{child1.name}/#{child2.name}"
          derivative_docs = update_derivative_doc(parent_doc, edit_doc, derivative_docs, xpath)
        else
          child2.elements.each do |child3|
            if child3.elements.size == 0
              xpath = "/HPXML/#{child1.name}/#{child2.name}/#{child3.name}"
              derivative_docs = update_derivative_doc(parent_doc, edit_doc, derivative_docs, xpath)
            else
              child3.elements.each do |child4|
                if child4.elements.size == 0
                  xpath = "/HPXML/#{child1.name}/#{child2.name}/#{child3.name}/#{child4.name}"
                  derivative_docs = update_derivative_doc(parent_doc, edit_doc, derivative_docs, xpath)
                else
                  child4.elements.each do |child5|
                    if child5.elements.size == 0
                      xpath = "/HPXML/#{child1.name}/#{child2.name}/#{child3.name}/#{child4.name}/#{child5.name}"
                      derivative_docs = update_derivative_doc(parent_doc, edit_doc, derivative_docs, xpath)
                    else
                      child5.elements.each do |child6|
                        if child6.elements.size == 0
                          xpath = "/HPXML/#{child1.name}/#{child2.name}/#{child3.name}/#{child4.name}/#{child5.name}/#{child6.name}"
                          derivative_docs = update_derivative_doc(parent_doc, edit_doc, derivative_docs, xpath)
                        else
                          child6.elements.each do |child7|
                            if child7.elements.size == 0
                              xpath = "/HPXML/#{child1.name}/#{child2.name}/#{child3.name}/#{child4.name}/#{child5.name}/#{child6.name}/#{child7.name}"
                              derivative_docs = update_derivative_doc(parent_doc, edit_doc, derivative_docs, xpath)
                            else
                              # TODO: wrap this nested if into a recursive method or something
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  derivative_docs.each do |derivative_path, derivative_doc|
    XMLHelper.get_first(derivative_doc, "/HPXML/XMLTransactionHeaderInformation/XMLGeneratedBy").text = "Rakefile"
    if original_derivative_docs[derivative_path].to_s != derivative_doc.to_s
      puts "Updating #{derivative_path}"
      XMLHelper.write_file(derivative_doc, derivative_path)
    end
  end

  XMLHelper.write_file(edit_doc, parent_path) # the edited valid.xml.edit becomes the new valid.xml

end