#!/usr/bin/env ruby
# _test/browse_test.rb — the rules of Browse datasets (/datasets/, _plugins/browse.rb), each against a
# small synthetic record so the exact output is asserted:
#
#     ruby _test/browse_test.rb
#
#   order          core first, newest last: by the release a dataset joined, the larger first within one
#                  release, and two rows equal on both in the order they came (a stable tie)
#   groups/realms  a category sits where its earliest dataset put it; a realm likewise, titled by the
#                  catalog's own REALMS; `solo` for a one-dataset category named like its dataset
#   has            "what's in it": taxa commonest first, common name first, tidied, "unidentified"
#                  skipped, a name said once; else measurements most-observed first, a replicate and a
#                  parenthesis folded into one label
#   has_line       "A, B, C and N more" arithmetic
#   count          the measurement total is the dataset page's count of measurement keys (it said
#                  "and 37 more", 40, where the page said 44 measurements)
#   years_label    the measured span; the record's asserted `temporal` where years cannot be measured
#                  (it read "Years not listed"); nil only when the record says neither
#   depth_label    "Surface", "0–515 m", nil
#   strip/ticks    marks on the RELEASE's own axis; no span, nothing drawn (no typed 1949)
#   visibility     a `visibility: internal` record has no row
#   portal_short   the catalog's short portal name, never a raw key
#   tile_row       the catalog's tile row no longer carries the unused cov_bar / explore fields
require "minitest/autorun"
require "logger"
require "json"

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
require_relative "../_plugins/browse"
require_relative "../_plugins/dataset_page"

class BrowseTest < Minitest::Test
  B = CalCOFI::Browse
  FakeSite = Struct.new(:data, :config)

  def setup = ENV["CALCOFI_SKIP_LINK_CHECK"] = "1"

  # ── order ────────────────────────────────────────────────────────────────
  def test_order_is_core_first_newest_last_then_the_larger_first
    rows = [{ "key" => "late",  "since" => "v2026.08.02", "n_obs" => 900 },
            { "key" => "small", "since" => "v2026.05.19", "n_obs" => 10 },
            { "key" => "big",   "since" => "v2026.05.19", "n_obs" => 5000 }]
    assert_equal %w[big small late], B.order(rows).map { |r| r["key"] }
  end

  def test_order_keeps_a_full_tie_in_the_order_it_came
    rows = [{ "key" => "a", "since" => "v1", "n_obs" => 7 }, { "key" => "b", "since" => "v1", "n_obs" => 7 },
            { "key" => "c", "since" => "v1", "n_obs" => 7 }]
    assert_equal %w[a b c], B.order(rows).map { |r| r["key"] }
    assert_equal %w[c b a], B.order(rows.reverse).map { |r| r["key"] }
  end

  def test_order_puts_a_row_with_no_release_or_count_where_the_keys_say
    rows = [{ "key" => "n", "since" => "v2", "n_obs" => nil }, { "key" => "none", "since" => nil, "n_obs" => 1 }]
    assert_equal %w[none n], B.order(rows).map { |r| r["key"] }
  end

  # ── groups and realms ────────────────────────────────────────────────────
  ROWS = [
    { "key" => "bottle", "name" => "Hydrographic Bottle", "cat" => "Physical Oceanography", "icon" => "cat-physical", "realm" => "env", "cat_desc" => "the water" },
    { "key" => "larvae", "name" => "Ichthyoplankton", "cat" => "Fish Eggs & Larvae", "icon" => "cat-ichthyo", "realm" => "bio", "cat_desc" => nil },
    { "key" => "ctd",    "name" => "CTD Cast Files", "cat" => "Physical Oceanography", "icon" => "cat-physical", "realm" => "env", "cat_desc" => "the water" },
    { "key" => "krill",  "name" => "Euphausiids (Krill)", "cat" => "Euphausiids / Krill", "icon" => "cat-krill", "realm" => "bio", "cat_desc" => nil },
    { "key" => "odd",    "name" => "Odd", "cat" => "Odd things", "icon" => "cat-other", "realm" => "air", "cat_desc" => nil }
  ].freeze

  def test_groups_follow_their_earliest_dataset_and_count_their_rows
    g = B.groups(ROWS)
    assert_equal ["Physical Oceanography", "Fish Eggs & Larvae", "Euphausiids / Krill", "Odd things"], g.map { |x| x["cat"] }
    assert_equal [2, 1, 1, 1], g.map { |x| x["n"] }
    assert_equal %w[bottle ctd], g[0]["rows"].map { |r| r["key"] }
    assert_equal({ "cat" => "Physical Oceanography", "icon" => "cat-physical", "realm" => "env", "desc" => "the water" },
                 g[0].slice("cat", "icon", "realm", "desc"))
  end

  def test_solo_is_a_single_dataset_that_carries_its_categorys_name
    g = B.groups(ROWS).to_h { |x| [x["cat"], x["solo"]] }
    assert_equal true,  g["Euphausiids / Krill"], "Euphausiids (Krill) is its category, punctuation aside"
    assert_equal false, g["Fish Eggs & Larvae"], "one dataset, another name"
    assert_equal false, g["Physical Oceanography"], "two datasets"
  end

  def test_realms_follow_their_earliest_category_and_take_the_catalogs_titles
    r = B.realms(B.groups(ROWS), { "bio" => "Biology", "env" => "Environment" })
    assert_equal [%w[env Environment], %w[bio Biology], %w[air Air]], r.map { |x| [x["id"], x["title"]] }
    assert_equal ["Fish Eggs & Larvae", "Euphausiids / Krill"], r[1]["groups"].map { |g| g["cat"] }
  end

  # ── what's in it ─────────────────────────────────────────────────────────
  def test_has_taxa_commonest_first_common_name_first_unidentified_skipped_said_once
    cov = { "n_taxa" => 992, "taxa" => [
      { "scientific_name" => "Teleostei", "common_name" => "Unidentified Teliost", "n_obs" => 900 },
      { "scientific_name" => "Sebastes", "common_name" => "rockfishes", "n_obs" => 300 },
      { "scientific_name" => "Engraulis mordax", "common_name" => "NORTHERN ANCHOVY", "n_obs" => 500 },
      { "scientific_name" => "Vinciguerria lucetia", "common_name" => nil, "n_obs" => 200 },
      { "scientific_name" => "Sebastes sp.", "common_name" => "Rockfishes", "n_obs" => 100 },
      { "scientific_name" => nil, "common_name" => "other", "n_obs" => 50 },
      { "scientific_name" => nil, "common_name" => nil, "n_obs" => 40 }
    ] }
    assert_equal ["Species and groups", ["Northern anchovy", "Rockfishes", "Vinciguerria lucetia"], 992], B.has(cov, {}, {})
  end

  def test_has_taxa_total_is_the_names_count_when_the_record_has_no_n_taxa
    cov = { "taxa" => [{ "scientific_name" => "Aaa", "n_obs" => 2 }, { "scientific_name" => "Bbb", "n_obs" => 1 }] }
    assert_equal ["Species and groups", %w[Aaa Bbb], 2], B.has(cov, {}, {})
  end

  MEAS = [
    { "key" => "temperature", "short_label" => "Temperature", "label" => "Temperature, in situ", "totals" => { "n_values" => 900 },
      "bounds" => { "declared_by" => %w[temperature temperature_ave] },
      "series" => [{ "dataset_key" => "x_ctd" }, { "dataset_key" => "x_bottle" }] },
    { "key" => "c14_rep1", "short_label" => "Carbon-14 uptake, replicate 1", "totals" => { "n_values" => 50 }, "series" => [{ "dataset_key" => "x_bottle" }] },
    { "key" => "c14_rep2", "short_label" => "Carbon-14 uptake, replicate 2", "totals" => { "n_values" => 40 }, "series" => [{ "dataset_key" => "x_bottle" }] },
    { "key" => "oxygen_ml_l", "label" => "Dissolved oxygen (ml/L)", "totals" => { "n_values" => 700 }, "series" => [{ "dataset_key" => "x_bottle" }] },
    { "key" => "oxygen_umol_kg", "label" => "Dissolved oxygen (µmol/kg)", "totals" => { "n_values" => 600 }, "series" => [{ "dataset_key" => "x_bottle" }, { "dataset_key" => "x_bottle" }] },
    { "key" => "mld", "short_label" => "Mixed-layer depth", "grain" => "sample", "totals" => { "n_values" => 5 }, "series" => [{ "dataset_key" => "x_ctd", "grain" => "sample" }] }
  ].freeze

  def test_measurement_labels_know_a_variable_by_its_key_or_a_declared_name
    lab, rank = B.measurement_labels(MEAS)
    assert_equal "Temperature", lab["temperature_ave"]
    assert_equal "Dissolved oxygen (ml/L)", lab["oxygen_ml_l"], "the label when there is no short one"
    assert_equal 900, rank["temperature_ave"]
    assert_equal [{}, {}], B.measurement_labels(nil)
  end

  def test_has_measurements_most_observed_first_replicates_and_parentheses_folded
    lab, rank = B.measurement_labels(MEAS)
    cov = { "variables" => [{ "name" => "c14_rep2" }, { "name" => "oxygen_umol_kg" }, "temperature", { "name" => "c14_rep1" },
                            { "name" => "oxygen_ml_l" }, { "name" => "not_in_the_record" }] }
    assert_equal ["Measurements", ["Temperature", "Dissolved oxygen", "Carbon-14 uptake"], 3], B.has(cov, lab, rank)
  end

  def test_has_is_empty_for_a_dataset_with_neither
    assert_equal [nil, [], 0], B.has({}, {}, {})
    assert_equal [nil, [], 0], B.has({ "variables" => [{ "name" => "unknown" }] }, {}, {})
  end

  def test_has_line_says_how_many_are_not_named
    list = %w[A B C D E]
    assert_equal "A, B, C and 6 more", B.has_line(list, 9, 3)
    assert_equal "A, B, C, D, E and 4 more", B.has_line(list, 9, 6)
    assert_equal "A, B, C, D, E", B.has_line(list, 5, 6)
    assert_equal "A, B and 1,198 more", B.has_line(list, 1200, 2)
    assert_nil B.has_line([], 9, 3)
  end

  # regression (2026-11-17, S-25): Browse counted folded LABELS ("… and 37 more" = 40 for CTD Cast Files) where
  # the dataset page counts measurement KEYS (44). One number now: the page's.
  def test_the_measurement_total_is_the_dataset_pages_count_of_keys
    counts = B.measurement_counts(MEAS)
    assert_equal({ "x_ctd" => 2, "x_bottle" => 5 }, counts)
    lab, rank = B.measurement_labels(MEAS)
    cov = { "variables" => %w[temperature c14_rep1 c14_rep2 oxygen_ml_l oxygen_umol_kg].map { |n| { "name" => n } } }
    label, names, total = B.has(cov, lab, rank, counts["x_bottle"])
    assert_equal "Measurements", label
    assert_equal 3, names.size, "three folded labels"
    assert_equal 5, total, "five measurements"
    assert_equal "Temperature, Dissolved oxygen, Carbon-14 uptake and 2 more", B.has_line(names, total, 3)
    page = CalCOFI::DatasetPage.meas_rows(CalCOFI::DatasetPage.series_by_dataset(MEAS)["x_bottle"])
    assert_equal total, page.sum { |g| g["rows"].size }, "Browse and the dataset page count the same measurements"
    # a per-cast measurement has no coverage variable and still counts, as on the page
    assert_equal 2, B.has({ "variables" => [{ "name" => "temperature" }] }, lab, rank, counts["x_ctd"])[2]
  end

  def test_the_measurement_total_is_never_less_than_the_labels_shown
    lab, rank = B.measurement_labels(MEAS)
    cov = { "variables" => [{ "name" => "temperature" }, { "name" => "oxygen_ml_l" }] }
    assert_equal 2, B.has(cov, lab, rank, nil)[2]
    assert_equal 2, B.has(cov, lab, rank, 1)[2]
  end

  # ── years and depth ──────────────────────────────────────────────────────
  # regression (2026-11-17, S-24): calcofi_phytoplankton (temporal "1996 to 2022", no measured year) read
  # "Years not listed" on Browse; main's tile shows the asserted span.
  def test_years_label_is_the_measured_span_else_the_asserted_one
    assert_equal "1951–2023", B.years_label("1951–2023", "1951-01 to 2023-11")
    assert_equal "1996", B.years_label("1996", nil)
    assert_equal "1996–2022", B.years_label(nil, "1996 to 2022")
    assert_equal "1939–2024", B.years_label("", "1939-05 to 2024-04")
    assert_equal "2012", B.span_of("2012-03 to 2012-11")
    assert_equal "ongoing", B.span_of("ongoing")
    assert_nil B.years_label(nil, nil)
    assert_nil B.years_label(nil, "")
  end

  def test_depth_label
    assert_equal "Surface", B.depth_label({ "depth_min_m" => 0, "depth_max_m" => 0 })
    assert_equal "0–515 m", B.depth_label({ "depth_min_m" => 0, "depth_max_m" => 515.2 })
    assert_equal "1–3,630 m", B.depth_label({ "depth_min_m" => 0.968, "depth_max_m" => 3630 })
    assert_nil B.depth_label({ "depth_min_m" => nil, "depth_max_m" => nil })
    assert_nil B.depth_label({})
  end

  def test_strip_marks_the_years_on_the_releases_axis
    assert_equal '<svg class="ys" viewBox="0 0 5 10" preserveAspectRatio="none" aria-hidden="true"><rect class="bg" width="5" height="10"/>' \
                 '<rect class="on" x="0.1" width=".8" height="10"/><rect class="on" x="3.1" width=".8" height="10"/></svg>',
                 B.strip([2000, 2003, 1990, 2010], [2000, 2004], "ys")
  end

  # regression (2026-11-17, S-14): with no release span the axis was a typed 1949 to this year
  def test_no_span_draws_no_strip_and_no_tick
    assert_nil B.strip([2000], nil, "ys")
    assert_equal [], B.ticks(nil)
    assert_equal [1970, 1990, 2010], B.ticks([1949, 2026])
    assert_equal [1990], B.ticks([1971, 2010])
  end

  # ── the catalog ──────────────────────────────────────────────────────────
  def ds(key, since:, n_obs:, cat: "Physical Oceanography", realm: "env", cov: {}, **extra)
    { "dataset_key" => key, "dataset_name" => "Dataset #{key}", "dataset_name_short" => key.upcase, "since_version" => since,
      "category" => { "name" => cat, "realm" => realm }, "attribution" => {}, "tables" => ["obs"],
      "status" => { "stage" => "published" }, "distributions" => [],
      "coverage" => { "n_obs" => n_obs, "realm" => realm }.merge(cov) }.merge(extra)
  end

  def catalog(datasets, config: {})
    rec = { "release" => { "version" => "v9.9.9" }, "datasets" => datasets, "holdings" => [] }
    CalCOFI::Catalog.new(FakeSite.new({ "products" => { "products" => [] } }, { "url" => "https://calcofi.io" }.merge(config)), rec, [])
  end

  DATASETS = lambda do |t|
    [t.ds("x_late", since: "v2026.08.02", n_obs: 900, cat: "Zooplankton", realm: "bio",
                    cov: { "year_min" => 2001, "year_max" => 2003, "years" => [{ "year" => 2001, "n_obs" => 5 }, { "year" => 2003, "n_obs" => 0 }] }),
     t.ds("x_ctd", since: "v2026.05.19", n_obs: 10,
                   cov: { "year_min" => 1993, "year_max" => 2026, "depth_min_m" => 0, "depth_max_m" => 515,
                          "variables" => [{ "name" => "temperature_ave" }] }),
     t.ds("x_bottle", since: "v2026.05.19", n_obs: 5000,
                      cov: { "year_min" => 1949, "year_max" => 1949, "variables" => %w[temperature c14_rep1 c14_rep2 oxygen_ml_l oxygen_umol_kg].map { |n| { "name" => n } } }),
     t.ds("x_phyto", since: "v2026.06.08", n_obs: 155, cat: "Phytoplankton", realm: "bio",
                     cov: { "temporal" => "1996 to 2022", "depth_min_m" => 0, "depth_max_m" => 0, "n_taxa" => 2,
                            "taxa" => [{ "scientific_name" => "Nitzschia", "n_obs" => 9 }, { "scientific_name" => "Oxytoxum", "n_obs" => 8 }] }),
     t.ds("x_held", since: "v2026.05.19", n_obs: 99_999, "visibility" => "internal")]
  end

  def test_browse_orders_rows_core_first_and_groups_them
    b = catalog(DATASETS.call(self)).browse(MEAS)
    assert_equal %w[x_bottle x_ctd x_phyto x_late], b["rows"].map { |r| r["key"] }
    assert_equal [%w[env Environment], %w[bio Biology]], b["realms"].map { |r| [r["id"], r["title"]] }
    assert_equal [1949, 2026], b["span"]
    assert_equal [1970, 1990, 2010], b["ticks"]
  end

  # regression (2026-11-17, S-28): the generators that read _data/*.json themselves went past this filter
  def test_an_internal_record_has_no_row_unless_the_build_is_a_preview
    refute_includes catalog(DATASETS.call(self)).browse(MEAS)["rows"].map { |r| r["key"] }, "x_held"
    assert_includes catalog(DATASETS.call(self), config: { "preview" => true }).browse(MEAS)["rows"].map { |r| r["key"] }, "x_held"
  end

  def test_browse_row_years_depth_and_what_is_in_it
    rows = catalog(DATASETS.call(self)).browse(MEAS)["rows"].to_h { |r| [r["key"], r] }
    assert_equal "1949", rows["x_bottle"]["years"], "one year alone"
    assert_equal "1993–2026", rows["x_ctd"]["years"]
    assert_equal "1996–2022", rows["x_phyto"]["years"], "asserted, where no year is measured"
    assert_nil rows["x_phyto"]["y0"], "the sort keys stay the measured years"
    assert_equal "Surface", rows["x_phyto"]["depth"]
    assert_equal "0–515 m", rows["x_ctd"]["depth"]
    assert_nil rows["x_late"]["depth"]
    assert_equal "Temperature, Dissolved oxygen, Carbon-14 uptake and 2 more", rows["x_bottle"]["has"]
    assert_equal "Temperature and 1 more", rows["x_ctd"]["has"], "the per-cast measurement counts, as on its page"
    assert_equal "Nitzschia, Oxytoxum", rows["x_phyto"]["has"]
    assert_equal "Species and groups", rows["x_phyto"]["has_label"]
    assert_nil rows["x_late"]["has"]
    assert_includes rows["x_late"]["strip"], 'viewBox="0 0 78 10"', "every strip is on the release's axis, 1949 to 2026"
    assert_equal 1, rows["x_late"]["strip"].scan('class="on"').size, "a year with no observation is not marked"
  end

  def test_with_no_measured_year_anywhere_nothing_is_drawn_on_a_typed_axis
    b = catalog([ds("x_phyto", since: "v1", n_obs: 5, cov: { "temporal" => "1996 to 2022" })]).browse(nil)
    assert_nil b["span"]
    assert_equal [], b["ticks"]
    assert_nil b["rows"][0]["strip"]
    assert_equal "1996–2022", b["rows"][0]["years"]
  end

  # regression (2026-11-17, S-27): the dataset page kept its own shorter portal map, so datazoo,
  # erddap-noaa and ucsd-library showed as raw keys
  def test_portal_short_is_the_catalogs_short_name_then_the_records_then_the_key
    c = catalog([])
    assert_equal "EDI", c.portal_short("edi")
    assert_equal "DataZoo", c.portal_short("datazoo")
    assert_equal "NOAA CoastWatch ERDDAP", c.portal_short("erddap-noaa")
    assert_equal "UC San Diego Library", c.portal_short("ucsd-library")
    assert_equal "somewhere-new", c.portal_short("somewhere-new")
    rec = { "release" => { "version" => "v9" }, "datasets" => [], "holdings" => [],
            "portals" => [{ "portal" => "odis", "name" => "Ocean Data and Information System" }, { "portal" => "edi", "name" => "Environmental Data Initiative" }] }
    c2 = CalCOFI::Catalog.new(FakeSite.new({ "products" => { "products" => [] } }, { "url" => "https://calcofi.io" }), rec, [])
    assert_equal "Ocean Data and Information System", c2.portal_short("odis"), "the record's name where the short map has none"
    assert_equal "EDI", c2.portal_short("edi"), "the short map first"
  end

  # regression (2026-11-17, S-26): computed for every tile and drawn nowhere
  def test_the_tile_row_carries_no_unused_browse_fields
    c = catalog(DATASETS.call(self))
    row = c.tile_row(c.datasets.first)
    refute row.key?("cov_bar")
    refute row.key?("explore")
    refute c.respond_to?(:cov_bar)
  end
end
