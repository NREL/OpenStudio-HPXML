# frozen_string_literal: true

require_relative '../../HPXMLtoOpenStudio/resources/minitest_helper'
require 'rdoc/rdoc'

class WorkflowDocumentationTest < Minitest::Test
  def test_coverage_report
    target_coverage = 100.0

    rdoc = RDoc::RDoc.new

    folders = Dir.glob('*').select { |f| File.directory? f }
    folders.each do |folder|
      rb_files = Dir[File.join(folder, '**/*.rb')]
      next if rb_files.size == 0

      argv = ['--dry-run', folder]
      rdoc.document(argv)
      stats = rdoc.stats
      puts "#{folder}: #{stats.percent_doc.round(2)}%"
      puts
    end

    # Parse files
    argv = ['--dry-run']
    rdoc.document(argv)

    # Check stats
    stats = rdoc.stats
    assert_operator(stats.percent_doc, :>, target_coverage)
  end
end
