# frozen_string_literal: true

require_relative '../../HPXMLtoOpenStudio/resources/minitest_helper'
require 'rdoc/rdoc'

class WorkflowDocumentationTest < Minitest::Test
  def test_coverage_report
    rdoc = RDoc::RDoc.new

    # Parse files
    argv = ['--dry-run']
    rdoc.document(argv)

    # Check stats
    stats = rdoc.stats
    assert_operator(stats.percent_doc, :>, 3.26)
  end
end
