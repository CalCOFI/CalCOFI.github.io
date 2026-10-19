#!/usr/bin/env ruby
# _test/measurements_short_label_test.rb — the short label a measurement's title wears (issue #30,
# D13 A), one rule per assertion, against labels the release actually carries:
#
#     ruby _test/measurements_short_label_test.rb
#
# The registry has no short-label field yet: `short_label` wins where the record carries it, else
# the heading (the label before any "; " tail) is cut at its first comma or colon OUTSIDE
# parentheses, and the full label becomes the sub line under the title.
require "minitest/autorun"
require "json"
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
    def self.logger = (@logger ||= Class.new { def warn(*) = nil; def info(*) = nil }.new)
  end
end
require_relative "../_plugins/datasets"
require_relative "../_plugins/measurements"

class MeasurementsShortLabelTest < Minitest::Test
  FakeSite = Struct.new(:data, :config)
  MR = CalCOFI::MeasurementsRecord

  def mm = MR.new(FakeSite.new({}, { "url" => "https://calcofi.io" }), { "measurements" => [] })
  def m(label, extra = {}) = { "key" => "k", "label" => label, "description" => label }.merge(extra)

  def test_a_label_with_no_comma_is_its_own_short_label
    assert_equal "Nitrate concentration", MR.cut_label("Nitrate concentration")
    assert_nil mm.sub_line(m("Nitrate concentration")), "nothing was cut, so no sub line"
  end

  def test_the_label_is_cut_at_its_first_comma
    l = "Mixed-layer depth, temperature departure of 0.2 degC from 10 m (de Boyer Montegut et al. 2004)"
    assert_equal "Mixed-layer depth", mm.short_label(m(l))
    assert_equal l, mm.sub_line(m(l)), "the full label is the sub line"
  end

  def test_a_colon_cuts_like_a_comma
    assert_equal "Chlorophyll-a at its maximum",
                 MR.cut_label("Chlorophyll-a at its maximum: the 3 m running mean at chl_max_depth")
  end

  def test_a_comma_inside_parentheses_does_not_cut
    assert_equal "Spice (spiciness at 0 dbar, TEOS-10)", mm.short_label(m(
      "Spice (spiciness at 0 dbar, TEOS-10); positive spicy (warm, salty), negative minty"))
    assert_equal "Potential density anomaly (sigma-theta)",
                 MR.cut_label("Potential density anomaly (sigma-theta), sensor-pair average by the provider's flags")
  end

  def test_a_comma_with_no_space_after_it_does_not_cut
    assert_equal "Nitrite+nitrate (NO2,NO3) total", MR.cut_label("Nitrite+nitrate (NO2,NO3) total")
    assert_equal "1,000 m depth", MR.cut_label("1,000 m depth")
  end

  def test_the_records_own_short_label_wins
    l = "Mixed-layer depth, temperature departure of 0.2 degC from 10 m"
    assert_equal "MLD (0.2 °C)", mm.short_label(m(l, "short_label" => "MLD (0.2 °C)"))
    assert_equal "Mixed-layer depth", mm.short_label(m(l, "short_label" => "  ")), "a blank field is no field"
  end

  def test_a_described_key_keeps_its_description_as_the_sub_line
    x = m("Reported Specific Volume Anomaly (pre-QC); WARNING: different parameter/scale than salinity PSS-78")
    assert_equal "Reported Specific Volume Anomaly (pre-QC)", mm.short_label(x)
    assert_equal x["description"], mm.sub_line(x)
  end
end
