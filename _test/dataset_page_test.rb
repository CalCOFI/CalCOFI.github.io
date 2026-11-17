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
#   lede_rest   About: the record's first sentence and the rest, the " …" of a cut dropped
#   byline      the full name where it differs from the short one, then who it is from
#   facts       the band's numbers: Years, or Dates where the years are asserted (it showed no year);
#               singular and plural; Taxa or Measurements; nothing the record does not carry
#   creators    the lead marked; one organisation said once, several beside each name; "A, B and C"
#   years_svg   records per year on the release's own axis (no typed 1949), a minimum bar, a stub
#   months_html "9 of 12" / "all 12", a minimum bar; nil without twelve months
#   taxa_rows   every taxon the dataset observed, most recorded first, ties by name; the bar's per
#               cent; a NAMELESS taxon named as its species page names it (16 rows drew blank); the
#               silhouette from the nearest ancestor, each outline drawn once; the coverage's top 50
#               when taxa.json is absent
#   meas_rows   one row per measurement key, by category.order, most values first, units through the
#               site's one display map
#   by dataset  a dataset's lists hold its own taxa and series only
require "minitest/autorun"
require "logger"
require "json"

# dataset_page.rb is the DatasetPage module (pure) plus a Jekyll generator at its foot. Only the module
# is under test, so Jekyll is stubbed: this runs as a bare `ruby` in CI, before any bundle.
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
require_relative "../_plugins/species"
require_relative "../_plugins/browse"
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

  # ── About ────────────────────────────────────────────────────────────────
  def test_lede_rest_splits_the_first_sentence_from_the_rest
    text = "Larvae collected by bongo nets. Sorted at SWFSC. Counts are per 10 m2."
    assert_equal ["Larvae collected by bongo nets.", "Sorted at SWFSC. Counts are per 10 m2."],
                 DP.lede_rest(text, "Larvae collected by bongo nets.")
  end

  def test_lede_rest_drops_the_ellipsis_of_a_cut_and_keeps_the_text_whole
    text = "A description with no sentence end in reach that simply runs on and on"
    assert_equal ["A description with no sentence end in reach", "that simply runs on and on"],
                 DP.lede_rest(text, "A description with no sentence end in reach …")
    assert_equal ["One sentence only.", nil], DP.lede_rest("One sentence only.", "One sentence only.")
    assert_equal [nil, nil], DP.lede_rest(nil, nil)
    assert_equal ["Something else.", "The record's text."], DP.lede_rest("The record's text.", "Something else."),
                 "a cut that is not the text's beginning leaves the text whole"
  end

  def test_lede_rest_agrees_with_the_catalogs_own_first_sentence
    c = CalCOFI::Catalog.new(Struct.new(:data, :config).new({ "products" => { "products" => [] } }, { "url" => "https://calcofi.io" }),
                             { "release" => {}, "datasets" => [], "holdings" => [] }, [])
    md = "**Ichthyoplankton** (fish eggs and larvae) collected by [bongo](https://x) tows. Processed by SWFSC."
    assert_equal ["Ichthyoplankton (fish eggs and larvae) collected by bongo tows.", "Processed by SWFSC."],
                 DP.lede_rest(c.plain(md), c.first_sentence(md))
  end

  def test_byline
    r = { "dataset_name" => "SWFSC Ichthyoplankton", "dataset_name_short" => "Ichthyoplankton",
          "provider" => { "short" => "NOAA SWFSC", "name" => "Southwest Fisheries Science Center" },
          "attribution" => { "pi_names" => ["A. Thompson", "E. Weber"] } }
    assert_equal "SWFSC Ichthyoplankton · From NOAA SWFSC, A. Thompson, E. Weber", DP.byline(r)
    assert_equal "From Southwest Fisheries Science Center",
                 DP.byline({ "dataset_name" => "Same", "dataset_name_short" => "Same", "provider" => { "name" => "Southwest Fisheries Science Center" } })
    assert_equal "Only a name", DP.byline({ "dataset_name" => "Only a name" })
    assert_equal "", DP.byline({})
  end

  # ── the band's numbers ───────────────────────────────────────────────────
  def test_facts_for_a_biology_dataset
    r = { "coverage" => { "year_min" => 1951, "year_max" => 2023, "n_obs" => 487_616, "n_roots" => 53_604, "n_stations" => 215 } }
    assert_equal [["1951–2023", "Years"], ["487,616", "Records"], ["53,604", "Sampling events"], ["215", "Stations"],
                  ["992", "Taxa"], ["0–210 m", "Depth"]],
                 DP.facts(r, years_span: "1951–2023", depth: "0–210 m", n_taxa: 992, n_meas: 6)
  end

  def test_facts_for_an_environment_dataset_singular_and_surface
    r = { "coverage" => { "year_min" => 2020, "year_max" => 2020, "n_obs" => 1, "n_stations" => 1 } }
    assert_equal [["2020", "Years"], ["1", "Records"], ["1", "Stations"], ["1", "Measurement"], ["Surface", "Depth"]],
                 DP.facts(r, depth: "surface", n_meas: 1)
    assert_equal ["1", "Taxon"], DP.facts(r, n_taxa: 1)[3]
    assert_equal ["44", "Measurements"], DP.facts(r, n_meas: 44)[3]
  end

  def test_facts_prefer_the_pages_span_over_the_coverages
    r = { "coverage" => { "year_min" => 1993, "year_max" => 2025 } }
    assert_equal [["1993–2026", "Years"]], DP.facts(r, years_span: "1993–2026"), "the per-cast grain runs past the obs grain"
    assert_equal [["1993–2025", "Years"]], DP.facts(r)
  end

  # regression (2026-11-17, S-24): calcofi_phytoplankton showed no year at all; main's page shows its asserted dates
  def test_facts_show_asserted_dates_where_no_year_is_measured
    r = { "coverage" => { "temporal" => "1996 to 2022", "n_obs" => 155_553, "n_roots" => 409 } }
    assert_equal [["1996 to 2022", "Dates"], ["155,553", "Records"], ["409", "Sampling events"], ["305", "Taxa"], ["Surface", "Depth"]],
                 DP.facts(r, depth: "surface", n_taxa: 305)
  end

  def test_facts_for_a_samples_only_record_are_what_it_carries_and_no_more
    assert_equal [["1939-05 to 2024-04", "Dates"]], DP.facts({ "coverage" => { "temporal" => "1939-05 to 2024-04", "n_obs" => nil } })
    assert_equal [], DP.facts({ "coverage" => {} })
    assert_equal [], DP.facts({})
  end

  # ── creators ─────────────────────────────────────────────────────────────
  def test_creators_one_two_and_three_the_lead_marked
    one = { "pi_names" => ["Ann Lee"], "creators" => [{ "name" => "Ann Lee", "organization" => "SIO" }] }
    assert_equal "Ann Lee (lead), SIO", DP.creators(one)
    two = { "pi_names" => ["Ann Lee"], "creators" => [{ "name" => "Bo Chen", "organization" => "SIO" }, { "name" => "Ann Lee", "organization" => "SIO" }] }
    assert_equal "Bo Chen and Ann Lee (lead), SIO", DP.creators(two)
    three = { "pi_names" => ["Ann Lee"], "creators" => [{ "name" => "Ann Lee", "organization" => "SIO" },
                                                        { "name" => "Bo Chen", "organization" => "NOAA SWFSC" }, { "name" => "Cy Diaz" }] }
    assert_equal "Ann Lee (lead) (SIO), Bo Chen (NOAA SWFSC) and Cy Diaz", DP.creators(three),
                 "two organisations are said beside each name; a creator with none has none"
  end

  def test_creators_fall_back_to_the_pi_names_and_to_nothing
    assert_equal "Ann Lee (lead) and Bo Chen", DP.creators({ "pi_names" => ["Ann Lee", "Bo Chen"] })
    assert_nil DP.creators({})
    assert_nil DP.creators(nil)
    assert_equal "Ann Lee", DP.creators({ "creators" => [{ "name" => "Ann Lee" }] }), "no PI named: no lead marked"
  end

  # ── when it was sampled ──────────────────────────────────────────────────
  def test_years_svg_draws_on_the_releases_axis_with_a_minimum_bar_and_stubs
    cov = { "years" => [{ "year" => 2001, "n_obs" => 1000 }, { "year" => 2003, "n_obs" => 10 }, { "year" => 2004, "n_obs" => 0 }] }
    svg = DP.years_svg(cov, [2000, 2004])
    assert_equal '<svg class="dp-bars" viewBox="0 0 50 100" preserveAspectRatio="none" aria-hidden="true">' \
                 '<rect class="z" x="1" y="98" width="8" height="2"><title>2000: 0 records</title></rect>' \
                 '<rect x="11" y="0.0" width="8" height="100.0"><title>2001: 1,000 records</title></rect>' \
                 '<rect class="z" x="21" y="98" width="8" height="2"><title>2002: 0 records</title></rect>' \
                 '<rect x="31" y="95" width="8" height="5"><title>2003: 10 records</title></rect>' \
                 '<rect class="z" x="41" y="98" width="8" height="2"><title>2004: 0 records</title></rect></svg>' \
                 '<div class="dp-ax"><span style="left:0">2000</span><span style="right:0">2004</span></div>', svg
  end

  # regression (2026-11-17, S-14): the axis was forced back to a typed 1949 whatever the release's span
  def test_years_svg_axis_starts_where_the_span_starts
    cov = { "years" => [{ "year" => 1975, "n_obs" => 4 }] }
    svg = DP.years_svg(cov, [1970, 1990])
    assert_includes svg, '<span style="left:0">1970</span>'
    refute_includes svg, "1949"
    assert_includes svg, 'viewBox="0 0 210 100"'
    assert_includes svg, '<span style="left:47.6%">1980</span>', "a tick only inside the axis"
    refute_includes svg, ">1960<"
    own = DP.years_svg({ "years" => [{ "year" => 1996, "n_obs" => 1 }, { "year" => 1998, "n_obs" => 2 }] }, nil)
    assert_includes own, '<span style="left:0">1996</span>', "with no release span, the dataset's own years"
    assert_includes own, '<span style="right:0">1998</span>'
  end

  def test_years_svg_is_nil_without_years
    assert_nil DP.years_svg({ "years" => [] }, [2000, 2004])
    assert_nil DP.years_svg({}, [2000, 2004])
    assert_nil DP.years_svg(nil, nil)
  end

  def test_months_html_counts_the_months_with_records
    m = DP.months_html({ "months" => [0, 200, 100, 0, 1, 50, 50, 50, 50, 0, 50, 50] })
    assert_equal "9 of 12", m["label"]
    assert_includes m["html"], '<i style="height:0%" title="J: 0 records"></i><i style="height:100.0%" title="F: 200 records"></i><i style="height:50.0%" title="M: 100 records"></i>'
    assert_includes m["html"], '<i style="height:5%" title="M: 1 records"></i>', "a month with records is at least 5% tall"
    assert_includes m["html"], '<div class="dp-mol"><span>J</span><span>F</span><span>M</span><span>A</span><span>M</span><span>J</span><span>J</span><span>A</span><span>S</span><span>O</span><span>N</span><span>D</span></div>'
    assert_equal "all 12", DP.months_html({ "months" => [1] * 12 })["label"]
  end

  def test_months_html_is_nil_without_twelve_months
    assert_nil DP.months_html({ "months" => [1, 2, 3] })
    assert_nil DP.months_html({ "months" => nil })
    assert_nil DP.months_html({})
  end

  # ── what is in it: taxa ──────────────────────────────────────────────────
  TAXA = [
    { "taxon_key" => "worms:1", "slug" => "worms-1", "scientific_name" => "Teleostei", "common_name" => "bony fishes", "rank" => "Class",
      "parent_taxon_key" => nil, "datasets" => [{ "dataset_key" => "x_larvae", "n_obs" => 40 }] },
    { "taxon_key" => "worms:2", "slug" => "worms-2", "scientific_name" => "Sebastes", "common_name" => "SEBASTES", "rank" => "Genus",
      "parent_taxon_key" => "worms:1", "datasets" => [{ "dataset_key" => "x_larvae", "n_obs" => 100 }] },
    { "taxon_key" => "worms:3", "slug" => "worms-3", "scientific_name" => "Sebastes paucispinis", "common_name" => " Bocaccio ", "rank" => "Species",
      "parent_taxon_key" => "worms:2", "datasets" => [{ "dataset_key" => "x_larvae", "n_obs" => 25 }, { "dataset_key" => "x_other", "n_obs" => 7 },
                                                      { "dataset_key" => "x_zero", "n_obs" => 0 }] },
    { "taxon_key" => "worms:4", "slug" => "worms-4", "scientific_name" => "Engraulis mordax", "common_name" => nil, "rank" => "Species",
      "parent_taxon_key" => "worms:9", "datasets" => [{ "dataset_key" => "x_larvae", "n_obs" => 25 }] },
    { "taxon_key" => "x_larvae:13", "slug" => "x_larvae-13", "scientific_name" => nil, "common_name" => nil, "rank" => nil,
      "parent_taxon_key" => nil, "local" => { "dataset_key" => "x_larvae", "name" => nil, "common_name" => "eggs", "code" => "13" },
      "datasets" => [{ "dataset_key" => "x_larvae", "n_obs" => 60 }] },
    { "taxon_key" => "x_larvae:picoeukaryotes", "slug" => "x_larvae-picoeukaryotes", "scientific_name" => nil, "common_name" => nil, "rank" => nil,
      "local" => { "dataset_key" => "x_larvae", "name" => nil, "common_name" => "picoeukaryotes", "code" => "picoeukaryotes" },
      "datasets" => [{ "dataset_key" => "x_larvae", "n_obs" => 50 }] }
  ].freeze
  BY = TAXA.to_h { |t| [t["taxon_key"], t] }
  MEDIA = { "worms:1" => { "silhouette" => { "viewBox" => "0 0 10 10", "svg_inner" => '<path d="M0 0h10"/>' } },
            "worms:3" => { "silhouette" => { "viewBox" => "0 0 4 4", "svg_inner" => '<path d="M1 1h2"/>' } } }.freeze
  NAMER = CalCOFI::Taxa.new(Struct.new(:data, :config).new({}, { "url" => "https://calcofi.io" }), { "taxa" => TAXA }).method(:name_of)

  def rows(**kw) = DP.taxa_rows(DP.observed_by_dataset(TAXA)["x_larvae"], {}, BY, MEDIA, namer: NAMER, **kw)

  def test_observed_by_dataset_keeps_each_datasets_own_taxa_and_no_zero
    by = DP.observed_by_dataset(TAXA)
    assert_equal %w[x_larvae x_other], by.keys.sort
    assert_equal [["worms:3", 7]], by["x_other"].map { |t, n| [t["taxon_key"], n] }
    assert_equal 6, by["x_larvae"].size
    assert_equal [], by["x_absent"], "a dataset no taxon names has an empty list"
  end

  def test_taxa_rows_most_recorded_first_ties_by_name_with_the_bars_per_cent
    r = rows[:rows]
    assert_equal ["worms:2", "x_larvae:13", "x_larvae:picoeukaryotes", "worms:1", "worms:4", "worms:3"], r.map { |x| x["k"] }
    assert_equal [100.0, 60.0, 50.0, 40.0, 25.0, 25.0], r.map { |x| x["pct"] }
    assert_equal({ "k" => "worms:3", "sci" => "Sebastes paucispinis", "com" => "Bocaccio", "rank" => nil, "n" => "25", "n_raw" => 25,
                   "url" => "/species/worms-3/", "sil" => r.last["sil"], "pct" => 25.0 }, r.last)
    assert_equal "Genus", r.first["rank"], "a rank is said unless it is Species"
  end

  def test_the_bar_is_the_rows_share_of_the_largest_to_one_decimal
    obs = [[{ "taxon_key" => "worms:a", "scientific_name" => "Aaa", "rank" => "Species" }, 3],
           [{ "taxon_key" => "worms:b", "scientific_name" => "Bbb", "rank" => "Species" }, 1]]
    assert_equal [100.0, 33.3], DP.taxa_rows(obs, {}, {}, {})[:rows].map { |x| x["pct"] }
    assert_equal ["3", "1"], DP.taxa_rows(obs, {}, {}, {})[:rows].map { |x| x["n"] }
  end

  # regression (2026-11-17, S-11): 16 dataset-local taxa have no scientific name; their rows were an empty link,
  # their search text empty and their button "Download just , from this dataset"
  def test_a_taxon_with_no_scientific_name_is_named_as_its_species_page_names_it
    r = rows[:rows].to_h { |x| [x["k"], x] }
    assert_equal "13", r["x_larvae:13"]["sci"], "the dataset's own code, as Taxa#name_of"
    assert_equal "eggs", r["x_larvae:13"]["com"], "and the name its dataset gives it"
    assert_equal "picoeukaryotes", r["x_larvae:picoeukaryotes"]["sci"]
    assert_nil r["x_larvae:picoeukaryotes"]["com"], "a common name that only repeats the name is not said twice"
    assert_equal NAMER.call(BY["x_larvae:13"]), r["x_larvae:13"]["sci"]
    rows[:rows].each { |x| refute_empty x["sci"].to_s.strip, "#{x['k']} has no name" }
  end

  def test_a_common_name_that_repeats_the_scientific_name_is_dropped
    r = rows[:rows].find { |x| x["k"] == "worms:2" }
    assert_equal "Sebastes", r["sci"]
    assert_nil r["com"]
  end

  def test_the_coverages_top_rows_stand_in_when_taxa_json_is_absent_and_are_never_nameless
    cov = { "taxa" => [{ "taxon_key" => "worms:3", "scientific_name" => "Sebastes paucispinis", "common_name" => "Bocaccio", "rank" => "Species", "n_obs" => 5 },
                       { "taxon_key" => "x_larvae:13", "scientific_name" => nil, "common_name" => "eggs", "rank" => nil, "n_obs" => 9 },
                       { "taxon_key" => "x_larvae:99", "scientific_name" => "", "common_name" => nil, "rank" => nil, "n_obs" => 2 }] }
    r = DP.taxa_rows([], cov, {}, {}, namer: NAMER)[:rows]
    assert_equal [["x_larvae:13", "eggs", nil], ["worms:3", "Sebastes paucispinis", "Bocaccio"], ["x_larvae:99", "99", nil]],
                 r.map { |x| [x["k"], x["sci"], x["com"]] },
                 "the scientific name, else the common name, else the key without its prefix"
    assert_nil r[1]["url"], "no taxa.json, no species page to link"
    assert_nil DP.taxa_rows(nil, nil, nil, nil)[:sprite]
    assert_equal [], DP.taxa_rows(nil, nil, nil, nil)[:rows]
  end

  def test_a_row_wears_its_own_silhouette_else_its_nearest_ancestors_each_drawn_once
    out = rows
    r = out[:rows].to_h { |x| [x["k"], x] }
    assert_equal r["worms:1"]["sil"], r["worms:2"]["sil"], "Sebastes has none of its own: its class's"
    refute_equal r["worms:1"]["sil"], r["worms:3"]["sil"], "Bocaccio has its own"
    assert_nil r["worms:4"]["sil"], "a parent the record does not hold: none"
    assert_nil r["x_larvae:13"]["sil"]
    assert_match(/\Asil-[0-9a-f]{8}\z/, r["worms:1"]["sil"])
    assert_equal 2, out[:sprite].scan("<symbol").size, "two outlines, three rows wearing them"
    assert_includes out[:sprite], %(<symbol id="#{r['worms:3']['sil']}" viewBox="0 0 4 4"><path d="M1 1h2"/></symbol>)
  end

  def test_rows_past_the_shown_ones_add_no_outline_of_their_own
    out = rows(shown: 1) # only Sebastes (its class's outline) is drawn in the page
    r = out[:rows].to_h { |x| [x["k"], x] }
    assert_equal 1, out[:sprite].scan("<symbol").size
    assert_equal r["worms:2"]["sil"], r["worms:1"]["sil"], "a later row reuses an outline already drawn"
    assert_nil r["worms:3"]["sil"], "and does not add its own"
  end

  # ── what is in it: measurements ──────────────────────────────────────────
  MEAS = [
    { "key" => "oxygen_ml_l", "slug" => "oxygen_ml_l", "label" => "Dissolved oxygen", "units" => "ml/L", "is_unified" => false,
      "category" => { "name" => "Nutrients & Chemistry", "order" => 2 },
      "series" => [{ "dataset_key" => "x_bottle", "n_values" => 9_000, "year_min" => 1949, "year_max" => 2021 }] },
    { "key" => "temperature", "slug" => "temperature", "label" => "Temperature, in situ", "short_label" => "Temperature", "units" => "degC", "is_unified" => true,
      "category" => { "name" => "Physical Oceanography", "order" => 1 },
      "series" => [{ "dataset_key" => "x_bottle", "n_values" => 884_383, "year_min" => 1949, "year_max" => 2021 },
                   { "dataset_key" => "x_bottle", "n_values" => 5, "year_min" => 2000, "year_max" => 2000 },
                   { "dataset_key" => "x_ctd", "n_values" => 1_702_356, "year_min" => 1993, "year_max" => 2026 }] },
    { "key" => "salinity", "slug" => "salinity", "label" => "Salinity", "units" => "PSS-78", "category" => { "name" => "Physical Oceanography", "order" => 1 },
      "series" => [{ "dataset_key" => "x_bottle", "n_values" => 900_000, "year_min" => 1950, "year_max" => 1950 }] },
    { "key" => "mld", "slug" => "mld", "label" => "Mixed-layer depth", "units" => nil, "grain" => "sample",
      "series" => [{ "dataset_key" => "x_ctd", "n_values" => 9_649, "year_min" => 1993, "year_max" => 2026, "grain" => "sample" }] }
  ].freeze

  def test_series_by_dataset_keeps_each_datasets_own_series
    by = DP.series_by_dataset(MEAS)
    assert_equal %w[oxygen_ml_l temperature temperature salinity], by["x_bottle"].map { |m, _| m["key"] }
    assert_equal %w[temperature mld], by["x_ctd"].map { |m, _| m["key"] }
    assert_equal [], by["x_absent"]
  end

  def test_meas_rows_by_category_order_most_values_first_one_row_per_key
    g = DP.meas_rows(DP.series_by_dataset(MEAS)["x_bottle"])
    assert_equal ["Physical Oceanography", "Nutrients & Chemistry"], g.map { |x| x["cat"] }
    assert_equal %w[salinity temperature], g[0]["rows"].map { |x| x["k"] }
    assert_equal({ "k" => "temperature", "lab" => "Temperature", "units" => "°C", "cat" => "Physical Oceanography", "order" => 1,
                   "n" => "884k", "n_raw" => 884_383, "years" => "1949–2021", "y0" => 1949, "y1" => 2021,
                   "url" => "/measurements/temperature/", "unified" => true, "pick" => true }, g[0]["rows"][1],
                 "a key with two series in the dataset keeps its first")
    assert_equal "1950", g[0]["rows"][0]["years"]
    assert_equal "9,000", g[1]["rows"][0]["n"]
  end

  # regression (2026-11-17, S-27): a second unit map (finder.rb UNITS) showed °C beside deg_C, ug/L and uE/m2/s;
  # units are shown through datasets.rb's ONE display map
  def test_meas_rows_show_units_through_the_one_display_map
    m = ->(u) { DP.meas_rows([[{ "key" => "k", "slug" => "k", "label" => "K", "units" => u }, { "n_values" => 1 }]])[0]["rows"][0]["units"] }
    assert_equal "°C", m.call("degC")
    assert_equal "°C", m.call("deg_C")
    assert_equal "µg/L", m.call("ug/L")
    assert_equal "µE/m²/s", m.call("uE/m2/s")
    assert_equal "10⁻⁸ m³/kg", m.call("10^-8 m3/kg")
    assert_equal "ml/L", m.call("ml/L")
    assert_nil m.call(nil), "no units: the page says so"
  end

  def test_meas_rows_a_measurement_with_no_category_and_a_per_cast_one
    g = DP.meas_rows(DP.series_by_dataset(MEAS)["x_ctd"])
    assert_equal ["Other", "Physical Oceanography"], g.map { |x| x["cat"] }, "no category sorts first, as order 0"
    assert_equal false, g[0]["rows"][0]["pick"], "per cast: no CSV button"
    assert_equal "1.7M", g[1]["rows"][0]["n"]
    assert_equal [], DP.meas_rows(nil)
  end

  def test_number_words
    assert_equal "9,999", DP.big(9_999)
    assert_equal "42k", DP.big(41_779)
    assert_equal "1.3M", DP.big(1_300_000)
    assert_nil DP.num(nil)
    assert_nil DP.yrs(nil, 2000)
    assert_equal "1996", DP.yrs(1996, 1996)
  end
end
