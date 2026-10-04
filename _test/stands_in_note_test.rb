#!/usr/bin/env ruby
# _test/stands_in_note_test.rb — the stand-in chip's tail (MeasurementsRecord.stands_in_tail), against
# every shape of stands_in_note the registry carries (workflows metadata/measurement_face.csv):
#
#     bundle exec ruby _test/stands_in_note_test.rb
#
# The chip prints "stands in: <label>'s face" itself, so a note that repeats it must be cut to what it adds.
require "minitest/autorun"
require "logger"

unless defined?(Jekyll)
  module Jekyll
    class Generator
      def self.safe(*) = nil
      def self.priority(*) = nil
    end
    module Errors
      class FatalException < StandardError; end
    end
    def self.logger = (@logger ||= Class.new { def warn(*) = nil }.new)
  end
end
require_relative "../_plugins/datasets"
require_relative "../_plugins/measurements"

class StandsInNoteTest < Minitest::Test
  T = CalCOFI::MeasurementsRecord

  CASES = {
    # parenthetical tail
    "stands in: temperature's face (underway sea-surface reading)"           => "underway sea-surface reading",
    "stands in: chlorophyll-a's face (calibrated underway fluorescence)"     => "calibrated underway fluorescence",
    "stands in: sigma-theta's face (sensor-pair average by the provider's flags)" => "sensor-pair average by the provider's flags",
    # a parenthetical that itself holds a comma and a dash
    "stands in: temperature's face (air, not water -- same physical quantity)" => "air, not water -- same physical quantity",
    # comma tail, and a tail that keeps its own parenthesis
    "stands in: nitrate's face, estimated from the ISUS sensor (cruise-corrected)" => "estimated from the ISUS sensor (cruise-corrected)",
    # double-dash tail
    "stands in: DIC's face -- same 14C-bicarbonate tracer, replicate 1"      => "same 14C-bicarbonate tracer, replicate 1",
    # a curly apostrophe
    "stands in: pH’s face (METS underway sensor)"                        => "METS underway sensor",
    # a bare note (the fixture's shape) and a note of another shape pass through
    "estimated from the ISUS sensor"                                         => "estimated from the ISUS sensor",
    "stands in for temperature"                                              => "stands in for temperature",
  }.freeze

  def test_every_registry_shape
    CASES.each { |note, want| assert_equal want, T.stands_in_tail(note), note }
  end

  def test_nothing_left_is_nil
    assert_nil T.stands_in_tail(nil)
    assert_nil T.stands_in_tail("   ")
    assert_nil T.stands_in_tail("stands in: temperature's face")
  end
end
