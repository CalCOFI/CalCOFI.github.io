#!/usr/bin/env ruby
# _test/measurements_grain_test.rb — what a measurement page does with `grain: "sample"`, each rule
# against a small fixture record of each grain:
#
#     bundle exec ruby _test/measurements_grain_test.rb
#
# calcofi4db's catalog (ws-1004d) lists the per-cast types of `sample_measurement` (the mixed-layer
# depths, the chlorophyll maximum and integral): key and series carry `grain: "sample"`, the series
# carry depth bands that are all zero and no depth, there is no `anomaly`, and `counts` gains
# `sample_measurement_rows`. A record WITHOUT `grain` is a depth observation of obs_env and every rule
# below returns what it returned before the field existed.
#
#   fixtures/measurements_grain.json     temperature (obs_env, no grain) + mld_sigma_theta_002 (sample)
#   fixtures/measurements_nograin.json   the same temperature entry in a record from before `grain`
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

class MeasurementsGrainTest < Minitest::Test
  FakeSite = Struct.new(:data, :config)
  DIR = File.join(__dir__, "fixtures")

  def mm_of(file)
    rec = JSON.parse(File.read(File.join(DIR, file)))
    CalCOFI::MeasurementsRecord.new(FakeSite.new({}, { "url" => "https://calcofi.io" }), rec)
  end

  def setup
    @mm   = mm_of("measurements_grain.json")
    @obs  = @mm.by_key["temperature"]
    @cast = @mm.by_key["mld_sigma_theta_002"]
  end

  # ── which grain is which ───────────────────────────────────────────────
  def test_the_two_grains_are_told_apart
    refute @mm.per_cast?(@obs)
    assert @mm.per_cast?(@cast)
    assert_equal "obs_env", @mm.grain_table(@obs)
    assert_equal "sample_measurement", @mm.grain_table(@cast)
    assert_nil @mm.grain_note(@obs)
    assert_match(/\AOne value per cast\./, @mm.grain_note(@cast))
  end

  def test_a_key_whose_series_are_all_per_cast_is_per_cast_even_without_the_key_level_field
    m = JSON.parse(JSON.generate(@cast))
    m.delete("grain")
    assert @mm.per_cast?(m), "every series says sample"
    m["series"] << JSON.parse(JSON.generate(@obs["series"][0]))
    refute @mm.per_cast?(m), "one obs_env series makes the key a depth observation"
  end

  # ── the numbers and the words ────────────────────────────────────────
  def test_the_stat_band_counts_rows_of_sample_measurement_and_has_no_depth
    rows = @mm.stat_rows(@cast)
    v = rows.find { |r| r["dt"] == "values" }
    assert_equal "9,000", v["dd"]
    assert_match(/sample_measurement — one value per cast/, v["title"])
    assert_nil rows.find { |r| r["dt"] == "depth" }, "a per-cast value has no depth, not 'surface'"
    assert_equal "9,000", rows.find { |r| r["dt"] == "sampling events" }["dd"]
    assert_equal "1993–2025", rows.find { |r| r["dt"] == "years" }["dd"]
    assert_equal "Feb · May · Aug · Nov", rows.find { |r| r["dt"] == "seasons" }["dd"]
    # the obs key keeps its obs_env wording and its depth
    ov = @mm.stat_rows(@obs)
    assert_match(/rows of obs_env/, ov.find { |r| r["dt"] == "values" }["title"])
    refute_nil ov.find { |r| r["dt"] == "depth" }
  end

  def test_a_per_cast_sentence_never_says_surface
    s = @mm.rec_sentence(@cast)
    assert_match(/9,000 values of it from 9,000 sampling events in one dataset, 1993–2025, one per cast\.\z/, s)
    refute_match(/surface/, s)
    assert_match(/from the surface to [\d,]+ m\./, @mm.rec_sentence(@obs))
  end

  # ── the figures ─────────────────────────────────────────────────────────
  def test_no_depth_figure_for_a_per_cast_key
    refute @mm.has_depth?(@cast)
    assert_equal [], @mm.depth_json(@cast)["rows"]
    assert_equal [], @mm.depth_json(@cast)["bands"]
    assert @mm.has_depth?(@obs)
    assert_equal ["calcofi_ctd-cast"], @mm.depth_json(@obs)["rows"].map { |r| r["k"] }
  end

  def test_the_years_and_months_strips_still_draw_a_per_cast_key
    assert_equal({ "1993" => 200, "2010" => 300, "2025" => 100 }, @mm.strip_json(@cast)["rows"][0]["y"])
    assert_equal [0, 2100, 0, 0, 2500, 0, 0, 2200, 0, 0, 2200, 0], @mm.months_json(@cast)["rows"][0]["m"]
  end

  def test_no_anomaly_panel_input_for_a_per_cast_key
    assert_nil @cast["anomaly"]
    f = @mm.face_of(@cast)
    assert_nil f["anomaly_bands"], "the face draws the anomaly spark only where the record carries bands"
    assert_equal({}, JSON.parse(f["json"]).slice("anomaly"))
  end

  # ── the series row and the ways in ──────────────────────────────────────
  def test_the_series_row_wears_a_per_cast_chip_and_the_record_counts
    r = @mm.dataset_rows(@cast)[0]
    assert_equal "one value per cast", r["chips"][0]["label"]
    assert_equal "per_cast", r["chips"][0]["flag"]
    assert_match(/9,000 values · 9,000 sampling events · 1993–2025 · 70 grid cells · 120 cruises\z/, r["meta"])
    refute_match(/ m\b/, r["meta"], "no depth range")
    assert_empty @mm.dataset_rows(@obs)[0]["chips"].select { |c| c["flag"] == "per_cast" }
  end

  def test_the_ways_in_read_sample_measurement_for_a_per_cast_key
    w = @mm.ways_rows(@cast)
    sql = w.find { |x| x["name"] == "db-query" }["sql"]
    assert_equal "SELECT * FROM __TBL:sample_measurement__ WHERE measurement_type = 'mld_sigma_theta_002' LIMIT 100;", sql
    assert_match(/tbl\(con, "sample_measurement"\)/, w.find { |x| x["name"] == "R" }["code"])
    assert_match(/FROM sample_measurement WHERE/, w.find { |x| x["name"] == "Python" }["code"])
    assert_match(/table = 'sample_measurement'/, w.find { |x| x["name"] == "Parquet" }["code"])
    refute_match(/obs_env/, w.map { |x| x["code"].to_s + x["sql"].to_s }.join)
    assert_empty w.select { |x| x["group"] == "erddap" }, "ERDDAP's tables are depth observations"
    refute w.any? { |x| x["name"].to_s.include?("depth section") }, "no climatology, no section vs normal"
    # the obs key is untouched
    ow = @mm.ways_rows(@obs)
    assert_match(/__TBL:obs_env__/, ow.find { |x| x["name"] == "db-query" }["sql"])
    assert_match(/tbl\(con, "obs_env"\)/, ow.find { |x| x["name"] == "R" }["code"])
  end

  def test_the_page_description_says_one_per_cast
    gen = CalCOFI::MeasurementsCatalog.new
    assert_match(/9,000 values, one per cast, in 1 CalCOFI dataset/, gen.page_description(@mm, @cast))
    assert_match(/\d values in 1 CalCOFI dataset/, gen.page_description(@mm, @obs))
    refute_match(/one per cast/, gen.page_description(@mm, @obs))
  end

  # ── a record from before `grain` ────────────────────────────────────────
  def test_a_record_without_grain_behaves_as_it_did
    old = mm_of("measurements_nograin.json")
    t = old.by_key["temperature"]
    refute old.per_cast?(t)
    assert_nil old.grain_note(t)
    assert old.has_depth?(t)
    assert_nil old.counts["sample_measurement_rows"]
    # the obs entry is the same entry in both records, so every page-facing output matches
    assert_equal old.stat_rows(t), @mm.stat_rows(@obs)
    assert_equal old.dataset_rows(t), @mm.dataset_rows(@obs)
    assert_equal old.ways_rows(t), @mm.ways_rows(@obs)
    assert_equal old.depth_json(t), @mm.depth_json(@obs)
  end
end
