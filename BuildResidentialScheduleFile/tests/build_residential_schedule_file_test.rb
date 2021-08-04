# frozen_string_literal: true

require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
require_relative '../../HPXMLtoOpenStudio/resources/meta_measure'
require_relative '../../HPXMLtoOpenStudio/resources/hpxml'

class BuildResidentialScheduleFileTest < Minitest::Test
end
