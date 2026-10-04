#!/usr/bin/env ruby
# _test/dataset_measurements_test.rb — the rules behind a dataset page's variable list
# (CalCOFI.github.io#26), each against a small synthetic record so the exact output is asserted:
#
#     bundle exec ruby _test/dataset_measurements_test.rb
#
#   variable_groups   a dataset's variables are two groups — profile (obs_env | obs_bio) and per-cast
#                     (sample_measurement) — with the release's counts; a missing or other-release
#                     sidecar leaves the profile group alone
#   per_cast_objects  the shared per-cast table is named in the Access table when the dataset has rows
#                     in it and the record's objects[] lacks it — from the catalog, never a built path
#   shipped_tables    a table the record names but the release does not ship is not drawn
#   successor_note    "this record ends in E; later values are btl_* of dataset C" — derived from the
#                     variables, so it appears for calcofi_bottle and for no dataset that has no twin
require "minitest/autorun"
require "logger"

# The plugin is Catalog (a plain class over a record) plus a Jekyll generator at its foot. Only the
# Catalog is under test, so Jekyll itself is stubbed: this runs as a bare `ruby` in CI, before any
# bundle, exactly as derive_id_test.rb does.
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

class DatasetMeasurementsTest < Minitest::Test
  FakeSite = Struct.new(:data, :config)

  RELEASE = { "version" => "v9.9.9", "release_date" => "2026-10-01" }.freeze

  def derived_record(extra = {})
    { "dataset_key" => "x_derived", "dataset_name_short" => "Derived", "category" => { "realm" => "env" },
      "coverage" => { "realm" => "env", "year_min" => 1993, "year_max" => 2025, "n_obs" => 1_326_183,
                      "variables" => [{ "name" => "sigma_theta_ave", "units" => "kg/m3" },
                                      { "name" => "spiciness0", "units" => "kg/m3" }] },
      "tables" => %w[obs sample_measurement ghost_table measurement_type],
      "objects" => [{ "table" => "obs", "scope" => "partition", "path" => "ducklake/tables/obs/a/data_0.parquet",
                      "url" => "https://store.example/calcofi-db/ducklake/tables/obs/a/data_0.parquet",
                      "bytes" => 10, "since" => "v9.9.9" }] }.merge(extra)
  end

  def per_cast_sidecar(release = "v9.9.9")
    { "schema_version" => "1.0", "release" => release,
      "datasets" => { "x_derived" => { "per_cast" => { "table" => "sample_measurement",
        "n_values" => 63_276, "n_samples" => 9_639,
        "types" => [{ "measurement_type" => "mld_sigma_theta_003", "units" => "m", "description" => "MLD",
                      "n_values" => 9_078, "n_samples" => 9_078, "year_min" => 1993, "year_max" => 2025,
                      "date_min" => "1993-08", "date_max" => "2025-04" },
                    { "measurement_type" => "chl_max", "units" => "ug/L", "description" => nil,
                      "n_values" => 9_008, "n_samples" => 9_008, "year_min" => 1993, "year_max" => 2025,
                      "date_min" => "1993-08", "date_max" => "2025-04" }] } } } }
  end

  # the same record with one per-cast type running on to 2026-07, as mld_temperature_02 does in v2026.10.01
  def per_cast_sidecar_to_2026
    s = per_cast_sidecar
    s["datasets"]["x_derived"]["per_cast"]["types"] << {
      "measurement_type" => "mld_temperature_02", "units" => "m", "description" => nil, "n_values" => 9_419,
      "n_samples" => 9_419, "year_min" => 1993, "year_max" => 2026, "date_min" => "1993-08", "date_max" => "2026-07" }
    s
  end

  def coverage(rows = [])
    { "variables" => [
        { "dataset_key" => "x_derived", "measurement_type" => "sigma_theta_ave", "n_obs" => 663_106,
          "year_min" => 1993, "year_max" => 2025 },
        { "dataset_key" => "x_derived", "measurement_type" => "spiciness0", "n_obs" => 663_077,
          "year_min" => 1993, "year_max" => 2025 }] + rows }
  end

  def catalog_json
    { "tables" => [{ "name" => "obs" }, { "name" => "sample_measurement", "objects" => [
        { "path" => "ducklake/tables/sample_measurement/h/sample_measurement.parquet", "bytes" => 2_553_047,
          "sha256" => "abc", "since" => "v9.9.9" }] }, { "name" => "measurement_type" }] }
  end

  def catalog(records, data = {})
    site = FakeSite.new({ "release_coverage" => coverage, "release_catalog" => catalog_json }.merge(data),
                        { "url" => "https://calcofi.io" })
    CalCOFI::Catalog.new(site, { "release" => RELEASE, "datasets" => records, "holdings" => [] }, [])
  end

  # ── variable_groups ──────────────────────────────────────────────────────
  def test_two_groups_name_both_tables_with_measured_counts
    r = derived_record
    g = catalog([r], "dataset_measurements" => per_cast_sidecar).variable_groups(r)
    assert_equal %w[profile per_cast], g.map { |x| x["id"] }
    assert_equal %w[obs_env sample_measurement], g.map { |x| x["table"] }
    assert_equal %w[sigma_theta_ave spiciness0], g[0]["variables"].map { |v| v["name"] }
    assert_equal [663_106, 663_077], g[0]["variables"].map { |v| v["n_values"] }
    assert_equal %w[mld_sigma_theta_003 chl_max], g[1]["variables"].map { |v| v["name"] }
    assert_equal "9,078", g[1]["variables"][0]["n_fmt"]
    assert_equal "1,326,183", g[0]["n_fmt"]
    assert_equal "63,276", g[1]["n_fmt"]
    assert_equal 4, g.sum { |x| x["variables"].size }, "2 profile + 2 per-cast, summed from the groups"
  end

  def test_the_heading_line_carries_grain_counts_and_years
    r = derived_record
    g = catalog([r], "dataset_measurements" => per_cast_sidecar).variable_groups(r)
    assert_equal "per cast · one value for the whole cast or tow, at no depth · 63,276 values on 9,639 " \
                 "sampling events · 1993–2025 · 2 variables", g[1]["summary"]
    assert_equal "profile · one value at each depth of a cast · 1,326,183 values · 1993–2025 · 2 variables",
                 g[0]["summary"]
  end

  # The measurements catalog now lists the per-cast types too (grain "sample"; calcofi4db ws-1004d), so
  # a per-cast type is in measurements.json AND in the dataset_measurements.json sidecar. The dataset
  # page reads only the record's coverage (the obs grain) and the sidecar, never measurements.json, so
  # each type is listed once, in the group of the table it lives in; the chip links its page because
  # the catalog's type_slugs now has it.
  def test_a_type_the_catalog_lists_as_per_cast_is_listed_once_on_the_dataset_page
    r = derived_record
    mm = { "type_slugs" => { "mld_sigma_theta_003" => "mld_sigma_theta_003", "chl_max" => "chl_max",
                             "sigma_theta_ave" => "sigma_theta" },
           "measurements" => [{ "key" => "chl_max", "grain" => "sample" }] }
    g = catalog([r], "dataset_measurements" => per_cast_sidecar, "measurements" => mm).variable_groups(r)
    names = g.flat_map { |x| x["variables"].map { |v| v["name"] } }
    assert_equal names.uniq, names, "a type appears in one group only"
    assert_equal %w[sigma_theta_ave spiciness0], g[0]["variables"].map { |v| v["name"] }, "profile group = obs_env"
    assert_equal %w[mld_sigma_theta_003 chl_max], g[1]["variables"].map { |v| v["name"] }, "per-cast group = sample_measurement"
    assert(g[1]["variables"].all? { |v| v["grain"] == "per_cast" })
    assert(g[1]["variables"].all? { |v| mm["type_slugs"].key?(v["name"]) }, "every per-cast chip has a page to link")
  end

  def test_no_sidecar_leaves_the_profile_group_alone
    r = derived_record
    g = catalog([r]).variable_groups(r)
    assert_equal ["profile"], g.map { |x| x["id"] }
  end

  def test_a_sidecar_for_another_release_is_ignored
    r = derived_record
    g = catalog([r], "dataset_measurements" => per_cast_sidecar("v0.0.1")).variable_groups(r)
    assert_equal ["profile"], g.map { |x| x["id"] }, "counts from two releases must never share a page"
  end

  def test_a_biological_dataset_names_obs_bio
    r = derived_record("dataset_key" => "x_bio",
                       "coverage" => { "realm" => "bio", "variables" => [{ "name" => "abundance" }], "n_obs" => 5 })
    g = catalog([r]).variable_groups(r)
    assert_equal "obs_bio", g[0]["table"]
  end

  # ── the years cover both grains ──────────────────────────────────────────
  def test_the_span_covers_a_per_cast_type_that_runs_past_the_record
    r = derived_record
    r["coverage"]["temporal"] = "1993-08 to 2025-04"
    c = catalog([r], "dataset_measurements" => per_cast_sidecar_to_2026)
    s = c.span_of(r)
    assert_equal [1993, 2026], [s["year_min"], s["year_max"]]
    assert_equal "1993-08 to 2026-07", s["temporal"]
    assert_equal "1993–2026", c.span_years(r)
  end

  def test_the_span_without_per_cast_rows_is_the_record_exactly
    r = derived_record
    r["coverage"]["temporal"] = "1993-08 to 2025-04"
    c = catalog([r])
    assert_equal "1993–2025", c.span_years(r)
    assert_equal "1993-08 to 2025-04", c.span_of(r)["temporal"]
  end

  def test_a_per_cast_group_inside_the_record_changes_nothing
    r = derived_record
    r["coverage"]["temporal"] = "1993-08 to 2025-04"
    assert_equal "1993–2025", catalog([r], "dataset_measurements" => per_cast_sidecar).span_years(r)
  end

  def test_a_record_with_no_years_keeps_none
    h = { "dataset_key" => "x_hold", "status" => {} }
    assert_nil catalog([h]).span_years(h)
  end

  # ── the tile counts both grains ──────────────────────────────────────────
  def test_the_catalog_tile_counts_profile_and_per_cast_variables
    r = derived_record
    t = catalog([r], "dataset_measurements" => per_cast_sidecar).tile_row(r)
    assert_equal 4, t["n_var"], "2 profile + 2 per-cast"
    assert_equal %w[sigma_theta_ave spiciness0 mld_sigma_theta_003 chl_max], t["var_names"]
    assert_equal 2, catalog([r]).tile_row(r)["n_var"], "no sidecar: the profile variables alone, as before"
  end

  # ── the Code block ───────────────────────────────────────────────────────
  # REGRESSION (2026-10-02): the page printed `calcofi4py.cite("<key>")`; `calcofi4py.cite` is a module,
  # so a reader who copied it got `TypeError: 'module' object is not callable`. The function is cc_cite.
  def test_the_python_snippet_calls_cc_cite_not_the_cite_module
    r = derived_record
    c = catalog([r], "dataset_measurements" => per_cast_sidecar)
    c.define_singleton_method(:url_ok?) { |_u| false }       # the EML probe is a network call
    code = c.access_groups(r).find { |g| g["id"] == "code" }["blocks"].flat_map { |b| b["rows"] }
            .map { |row| row["code"].to_s }.join("\n")
    assert_includes code, 'calcofi4py.cc_cite("x_derived")'
    refute_match(/calcofi4py\.cite\(/, code)
    assert_includes code, 'calcofi4r::cc_cite("x_derived")'
  end

  def test_the_duckdb_block_reads_both_tables_filtered_to_the_dataset
    r = derived_record
    c = catalog([r], "dataset_measurements" => per_cast_sidecar)
    c.define_singleton_method(:url_ok?) { |_u| false }
    rows = c.access_groups(r).find { |g| g["id"] == "code" }["blocks"]
            .find { |b| b["title"] == "DuckDB, anywhere" }["rows"]
    assert_equal ["obs · this dataset’s rows", "sample_measurement · whole table, every dataset"],
                 rows.map { |x| x["label"] }
    assert_match(/sample_measurement\.parquet'\)\nWHERE dataset_key = 'x_derived'/, rows[1]["code"])
    refute_match(/WHERE/, rows[0]["code"], "a partition holds only this dataset's rows")
  end

  def test_the_access_table_names_both_tables
    r = derived_record
    c = catalog([r], "dataset_measurements" => per_cast_sidecar)
    c.define_singleton_method(:url_ok?) { |_u| false }
    tbl = c.access_groups(r).find { |g| g["id"] == "data" }["blocks"].find { |b| b["layout"] == "table" }
    assert_equal %w[obs sample_measurement], tbl["rows"].map { |x| x["label"] }
  end

  # ── per_cast_objects ─────────────────────────────────────────────────────
  def test_the_per_cast_table_is_named_from_the_catalog
    r = derived_record
    o = catalog([r], "dataset_measurements" => per_cast_sidecar).per_cast_objects(r)
    assert_equal 1, o.size
    assert_equal "sample_measurement", o[0]["table"]
    assert_equal true, o[0]["shared"], "a whole table, every dataset: the page says to filter on dataset_key"
    assert_equal "https://store.example/calcofi-db/ducklake/tables/sample_measurement/h/sample_measurement.parquet",
                 o[0]["url"], "the storage root is read off the record's own object urls"
    assert_equal "v9.9.9", o[0]["since"]
  end

  def test_a_per_cast_table_already_in_objects_is_not_listed_twice
    r = derived_record
    r["objects"] << { "table" => "sample_measurement", "scope" => "table", "shared" => true, "url" => "u", "path" => "p" }
    assert_empty catalog([r], "dataset_measurements" => per_cast_sidecar).per_cast_objects(r)
  end

  def test_no_per_cast_rows_means_no_per_cast_object
    r = derived_record
    assert_empty catalog([r]).per_cast_objects(r)
  end

  # ── shipped_tables ───────────────────────────────────────────────────────
  def test_a_table_the_release_does_not_ship_is_dropped
    r = derived_record
    assert_equal %w[obs sample_measurement measurement_type], catalog([r]).shipped_tables(r)
  end

  def test_without_a_readable_catalog_nothing_is_dropped
    r = derived_record
    c = catalog([r], "release_catalog" => nil)
    assert_equal r["tables"], c.shipped_tables(r)
  end

  # ── successor_note ───────────────────────────────────────────────────────
  def bottle_pair
    bottle = { "dataset_key" => "x_bottle", "dataset_name_short" => "Bottle", "category" => { "realm" => "env" },
               "coverage" => { "realm" => "env", "year_min" => 1949, "year_max" => 2021, "variables" => [] } }
    cast = { "dataset_key" => "x_cast", "dataset_name_short" => "Casts", "category" => { "realm" => "env" },
             "coverage" => { "realm" => "env", "year_min" => 1993, "year_max" => 2026, "variables" => [] } }
    rows = [{ "dataset_key" => "x_bottle", "measurement_type" => "nitrate", "year_max" => 2021 },
            { "dataset_key" => "x_bottle", "measurement_type" => "temperature", "year_max" => 2021 },
            { "dataset_key" => "x_bottle", "measurement_type" => "r_depth", "year_max" => 2021 },
            { "dataset_key" => "x_cast", "measurement_type" => "btl_nitrate", "year_max" => 2025 },
            { "dataset_key" => "x_cast", "measurement_type" => "btl_temperature", "year_max" => 2024 },
            { "dataset_key" => "x_cast", "measurement_type" => "btl_depth", "year_max" => 2025 },
            { "dataset_key" => "x_cast", "measurement_type" => "temperature", "year_max" => 2026 }]
    [bottle, cast, { "variables" => rows }]
  end

  def test_a_record_that_ends_names_the_dataset_that_carries_its_twins_on
    bottle, cast, cov = bottle_pair
    c = catalog([bottle, cast], "release_coverage" => cov)
    n = c.successor_note(bottle)
    assert_equal "x_cast", n["key"]
    assert_equal 2021, n["last"]
    assert_equal 2025, n["through"]
    assert_equal %w[nitrate temperature], n["types"], "btl_depth has no depth twin (r_depth is not depth): exact names only"
    assert_equal 2, n["n"]
    assert_equal "/datasets/x_cast/", n["url"]
  end

  def test_the_dataset_that_runs_on_has_no_note
    bottle, cast, cov = bottle_pair
    assert_nil catalog([bottle, cast], "release_coverage" => cov).successor_note(cast)
  end

  def test_a_twin_that_does_not_run_later_is_not_a_successor
    bottle, cast, cov = bottle_pair
    cov["variables"].each { |v| v["year_max"] = 2021 if v["dataset_key"] == "x_cast" }
    assert_nil catalog([bottle, cast], "release_coverage" => cov).successor_note(bottle)
  end

  def test_a_dataset_with_no_twins_has_no_note
    r = derived_record
    assert_nil catalog([r]).successor_note(r)
  end
end
