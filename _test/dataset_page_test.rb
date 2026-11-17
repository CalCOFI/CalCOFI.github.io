#!/usr/bin/env ruby
# _test/dataset_page_test.rb — the pure rules of the redesigned dataset page (_plugins/dataset_page.rb,
# module CalCOFI::DatasetPage), each against a small synthetic record so the exact output is asserted:
#
#     ruby _test/dataset_page_test.rb
#
#   form_file   what the download form beside a species or a measurement (assets/download-form.js)
#               knows about its dataset: the name, the page, and the release's default zip exactly as
#               the Download offer gives it (_plugins/downloads.rb) — never a URL built here, never a
#               whole-table ERDDAP CSV, never the release Parquet. No offer: no "zip" key, so the form
#               sends the reader to the dataset page instead of to a file that is not there.
#   pickable?   a measurement's row gets a CSV button (the Query Builder, ?pick=env:<dataset>:<key>) unless
#               the record says it is one value per cast (grain "sample"), which the builder does not read
require "minitest/autorun"

# dataset_page.rb is the DatasetPage module (pure) plus a Jekyll generator at its foot. Only the module
# is under test, so Jekyll is stubbed: this runs as a bare `ruby` in CI, before any bundle.
unless defined?(Jekyll)
  module Jekyll
    class Generator
      def self.safe(*) = nil
      def self.priority(*) = nil
    end
  end
end
require_relative "../_plugins/dataset_page"

class DatasetPageTest < Minitest::Test
  DP = CalCOFI::DatasetPage

  RECORD = { "dataset_key" => "x_larvae", "dataset_name" => "X Larval Fish Survey", "dataset_name_short" => "Larvae" }.freeze
  OFFER = {
    "what"    => "CSV · 32.4 MB",
    "primary" => { "format" => "csv", "url" => "https://e/publish/zip/x_larvae/3872789ed24411383f47ae8a/x_larvae_v1_csv.zip",
                   "file" => "x_larvae_v1_csv.zip", "size" => "32.4 MB" }
  }.freeze

  def test_form_file_carries_the_offers_default_zip_as_given
    f = DP.form_file(RECORD, OFFER, "/datasets/x_larvae/")
    assert_equal({ "name" => "Larvae", "page" => "/datasets/x_larvae/",
                   "zip" => { "url" => "https://e/publish/zip/x_larvae/3872789ed24411383f47ae8a/x_larvae_v1_csv.zip",
                              "file" => "x_larvae_v1_csv.zip", "what" => "CSV · 32.4 MB" } }, f)
  end

  def test_form_file_without_an_offer_has_no_zip
    assert_equal({ "name" => "Larvae", "page" => "/datasets/x_larvae/" }, DP.form_file(RECORD, nil, "/datasets/x_larvae/"))
  end

  def test_form_file_with_an_offer_that_has_no_url_has_no_zip
    f = DP.form_file(RECORD, { "what" => "CSV", "primary" => { "format" => "csv", "url" => nil } }, "/datasets/x_larvae/")
    refute f.key?("zip")
  end

  # regression (2026-11-17): the form offered a CSV built in the browser from the release Parquet, ERDDAP's
  # form, Parquet and NetCDF — a second whole-dataset download beside the zips. Only name, page and zip remain.
  def test_form_file_offers_nothing_but_the_zip
    f = DP.form_file(RECORD, OFFER, "/datasets/x_larvae/")
    assert_equal %w[name page zip], f.keys
    assert_equal %w[file url what], f["zip"].keys.sort
  end

  # regression (2026-11-17, release v2026.11.14): all 13 per-cast measurements of calcofi_ctd-derived
  # (mld_temperature_02, chl_max, nitracline_depth …) drew a CSV button whose pick the builder does not have
  def test_pickable_is_false_for_a_per_cast_series
    refute DP.pickable?({ "key" => "mld_temperature_02", "grain" => "sample" }, { "dataset_key" => "x", "grain" => "sample" })
    refute DP.pickable?({ "key" => "m" }, { "grain" => "sample" }), "the series' grain alone is enough"
    refute DP.pickable?({ "key" => "m", "grain" => "sample" }, { "dataset_key" => "x" }), "the measurement's grain is the fallback"
  end

  def test_pickable_is_true_at_the_release_grain
    assert DP.pickable?({ "key" => "temperature", "grain" => nil }, { "dataset_key" => "x_bottle" })
    assert DP.pickable?({ "key" => "temperature" }, { "dataset_key" => "x_bottle", "grain" => "obs" })
    assert DP.pickable?({ "key" => "temperature", "grain" => "sample" }, { "dataset_key" => "x_bottle", "grain" => "obs" }), "the series' own grain wins"
    assert DP.pickable?(nil, nil)
  end

  def test_form_file_names_the_dataset_by_its_short_name_then_its_name_then_its_key
    assert_equal "X Larval Fish Survey", DP.form_file(RECORD.reject { |k, _| k == "dataset_name_short" }, nil, "/p/")["name"]
    assert_equal "x_larvae", DP.form_file({ "dataset_key" => "x_larvae" }, nil, "/p/")["name"]
  end
end
