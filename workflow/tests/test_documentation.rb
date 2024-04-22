# frozen_string_literal: true

require_relative '../../HPXMLtoOpenStudio/resources/minitest_helper'
require 'rdoc/rdoc'
require 'yard'

class WorkflowDocumentationTest < Minitest::Test
  def setup
    @target_coverage = 100.0
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

  def test_yard
    # FIXME
    YARD.parse('**/*.rb')
    stats = YARD::CLI::Stats.new
    assert_operator(stats.stats_for_files, :>, @target_coverage)
  end
end
