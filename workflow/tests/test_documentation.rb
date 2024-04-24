# frozen_string_literal: true

require_relative '../../HPXMLtoOpenStudio/resources/minitest_helper'
require 'rdoc/rdoc'

class WorkflowDocumentationTest < Minitest::Test
  def setup
    @target_coverage = 0.0
  end

  def test_rdoc
    folder_excludes = []
    check_all = true

    rdoc = RDoc::RDoc.new

    folders = Dir.glob('*').select { |f| File.directory? f }
    folders.each do |folder|
      next if folder_excludes.any? { |f| f.include?(folder) }

      rb_files = Dir[File.join(folder, '**/*.rb')]
      next if rb_files.size == 0

      argv = ['--dry-run', folder]
      rdoc.document(argv)
      stats = rdoc.stats
      puts "#{folder}: #{stats.percent_doc.round(2)}%"
      puts
    end

    if check_all
      # Parse files
      argv = ['--dry-run']
      rdoc.document(argv)

      # Check stats
      stats = rdoc.stats
      assert_operator(stats.percent_doc, :>, @target_coverage)
    end
  end
end
