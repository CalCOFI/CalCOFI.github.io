#!/usr/bin/env ruby
# _test/dataset_extras_test.rb — the pure rules of _plugins/dataset_extras.rb:
#
#     ruby _test/dataset_extras_test.rb
#
#   analysis       "Method (Lab)" split at the LAST bracket; a lab alone; a method alone
#   for            every key present, nil when not given; an unknown method or status is dropped
#   tiles          groups by datasets or categories, in the rows' order; Environment first as the
#                  file says; an unclaimed row gets its own category's tile; empty groups dropped;
#                  years and programs from the rows
#   tile_of        the tile a dataset sits in
#   source_tables  only current NOAA ERDDAP mirrors with an id and a url
#   fields         one row per column of the dataset's tables, main ones first; database plumbing skipped;
#                  MAIN columns marked; no metadata → []
require "minitest/autorun"
require "yaml"
require_relative "../_plugins/dataset_extras"

class DatasetExtrasTest < Minitest::Test
  X = CalCOFI::DatasetExtras
  EXTRAS = {
    "tiles" => [
      { "realm" => "env", "title" => "Environment", "groups" => [
        { "name" => "CTD & Bottle", "icon" => "cat-physical", "line" => "By depth", "datasets" => %w[ctd bottle] },
        { "name" => "Empty", "datasets" => %w[nothing] }] },
      { "realm" => "bio", "title" => "Biology", "groups" => [
        { "name" => "Fish Eggs & Larvae", "line" => "Eggs", "categories" => ["Fish Eggs & Larvae"] }] }
    ],
    "datasets" => {
      "ichthyo" => { "plain" => "Fish Egg and Larva Counts", "analysis" => "Visual microscopy (NOAA SWFSC)", "method" => "net", "status" => "Ongoing" },
      "odd" => { "method" => "submarine", "status" => "maybe" }
    }
  }.freeze
  ROWS = [
    { "key" => "ctd", "cat" => "Physical Oceanography", "realm" => "env", "icon" => "cat-physical", "prov" => "CalCOFI", "y0" => 1993, "y1" => 2026 },
    { "key" => "ichthyo", "cat" => "Fish Eggs & Larvae", "realm" => "bio", "icon" => "cat-ichthyo", "prov" => "NOAA SWFSC", "y0" => 1951, "y1" => 2023 },
    { "key" => "bottle", "cat" => "Physical Oceanography", "realm" => "env", "icon" => "cat-physical", "prov" => "CalCOFI", "y0" => 1949, "y1" => 2021 },
    { "key" => "cufes", "cat" => "Fish Eggs & Larvae", "realm" => "bio", "icon" => "cat-ichthyo", "prov" => "NOAA SWFSC", "y0" => 1996, "y1" => 2022 },
    { "key" => "mets", "cat" => "Meteorology & Sea State", "realm" => "env", "icon" => "cat-meteorology", "prov" => "CalCOFI", "cat_desc" => "Wind", "y0" => 2004, "y1" => 2022 },
    { "key" => "phyto", "cat" => "Phytoplankton", "realm" => "bio", "icon" => "cat-phytoplankton", "prov" => "CalCOFI", "years" => "1996 to 2022" }
  ].freeze

  def test_analysis
    assert_equal ["Visual microscopy", "NOAA SWFSC"], X.analysis("Visual microscopy (NOAA SWFSC)")
    assert_equal [nil, "SIO"], X.analysis("(SIO)")
    assert_equal ["Flow cytometry", nil], X.analysis("Flow cytometry")
    assert_equal ["Microscopy (by hand)", "Ohman Lab"], X.analysis("Microscopy (by hand) (Ohman Lab)")
    assert_equal [nil, nil], X.analysis(nil)
  end

  def test_for
    e = X.for(EXTRAS, "ichthyo")
    assert_equal "Fish Egg and Larva Counts", e["plain"]
    assert_equal "Visual microscopy", e["analysis_method"]
    assert_equal "NOAA SWFSC", e["analysis_lab"]
    assert_equal ["net", "Net tow"], [e["method"], e["method_label"]]
    assert_equal ["ongoing", "Ongoing"], [e["status"], e["status_label"]]
    assert_nil e["collection"]
    odd = X.for(EXTRAS, "odd")
    assert_nil odd["method"]
    assert_nil odd["status"]
    assert_nil X.for(nil, "x")["plain"]
  end

  def test_tiles
    t = X.tiles(EXTRAS, ROWS)
    assert_equal %w[env bio], t.map { |r| r["id"] }
    env = t[0]["groups"]
    assert_equal ["CTD & Bottle", "Meteorology & Sea State"], env.map { |g| g["name"] }, "Empty dropped, mets gets its own tile"
    assert_equal %w[ctd bottle], env[0]["keys"], "the rows' order"
    assert_equal "1949–2026", env[0]["years"]
    assert_equal "CalCOFI", env[0]["programs"]
    assert_equal "ctd-and-bottle", env[0]["slug"]
    assert_equal "Wind", env[1]["line"], "an unclaimed tile's line is its category's description"
    bio = t[1]["groups"]
    assert_equal ["Fish Eggs & Larvae", "Phytoplankton"], bio.map { |g| g["name"] }
    assert_equal "1951–2023", bio[0]["years"]
    assert_equal "1996 to 2022", bio[1]["years"], "no y0: the row's own years label"
    assert_equal "cat-ichthyo", bio[0]["icon"], "no icon in the file: the first row's"
    assert_equal 3, t[0]["n"]
    assert_equal ["CTD & Bottle", "ctd-and-bottle"], X.tile_of(t, "bottle")
    assert_nil X.tile_of(t, "nope")
  end

  def test_source_tables
    r = { "distributions" => [
      { "portal" => "erddap-noaa", "id" => "erdCalCOFIlrvcnt", "title" => "CalCOFI NOAA Fish Larvae Counts", "url" => "https://x/erdCalCOFIlrvcnt.html" },
      { "portal" => "erddap-noaa", "id" => nil, "url" => "https://x/source" },
      { "portal" => "obis", "id" => "o", "url" => "https://obis" }] }
    assert_equal [{ "id" => "erdCalCOFIlrvcnt", "title" => "Fish Larvae Counts", "url" => "https://x/erdCalCOFIlrvcnt.html" },
                  { "id" => "source", "title" => "source", "url" => "https://x/source" }], X.source_tables(r),
                 "a table with no id or title keeps its address's end as the id (Betty 2026-11-20)"
  end

  def test_fields
    meta = { "columns" => {
      "obs.datetime" => { "description_md" => "Observation time (UTC)." },
      "obs.latitude" => { "units" => "decimal degrees", "description_md" => "Observation latitude (WGS84)." },
      "sample.latitude" => { "units" => "decimal degrees", "description_md" => "Event latitude." },
      "obs.obs_id" => { "description_md" => "Surrogate key." },
      "obs.hex_id" => { "description_md" => "H3 cell." },
      "obs.sample_key" => { "description_md" => "Event key." },
      "measurement_type._source_column" => { "description_md" => "Plumbing." },
      "sample.tow_type" => { "description_md" => "Net gear code, `C1`." },
      "taxon.rank" => { "description_md" => "Taxonomic rank." },
      "other.x" => { "description_md" => "Not this dataset's." } } }
    f = X.fields(meta, { "tables" => %w[sample obs measurement_type] })
    assert_equal %w[datetime latitude tow_type], f.map { |x| x["field"] }, "main first in MAIN's order; keys, cells, plumbing and other tables out"
    assert_equal "sample.csv, obs.csv", f[1]["file"], "one row per column, every file it is in"
    assert_equal "Event latitude.", f[1]["desc"], "the first file's description"
    assert_equal "Net gear code, C1.", f[2]["desc"], "backticks dropped"
    assert_equal [true, true, false], f.map { |x| x["main"] }, "tow_type folds with the rest (Betty 2026-11-21)"
    assert_equal [], X.fields(nil, { "tables" => %w[obs] })
  end

  # the real file parses and every dataset key in it names a known method and status
  def test_the_file
    y = YAML.safe_load(File.read(File.join(__dir__, "..", "_data", "dataset_extras.yml")))
    y["datasets"].each do |k, v|
      assert(v["method"].nil? || X::METHODS.key?(v["method"]), "#{k}: method #{v['method']}")
      assert(v["status"].nil? || X::STATUS.key?(v["status"]), "#{k}: status #{v['status']}")
    end
    assert_equal %w[env bio], y["tiles"].map { |r| r["realm"] }
  end
  def test_short_desc
    e = CalCOFI::DatasetExtras
    assert_equal "Discrete DIC from CalCOFI Niskin bottles, quality-controlled using WOCE flagging, at every station.",
      e.short_desc("Discrete DIC from CalCOFI Niskin bottles, quality-controlled using WOCE flagging, at every station. Values on a bottle are published once (see questions calcofidic01 and calcofidic07).")
    assert_equal "Dissolved iron from CalCOFI cruises, Nov. 2002 - July 2004.", e.short_desc("Dissolved iron from CalCOFI cruises, Nov. 2002 - July 2004 (completed). Surface samples.").sub(/ Surface samples\.\z/, "")
    assert_equal "CTD profiles at standard depths. 1 m-binned data come from the archive (J. Smith).",
      e.short_desc("CTD profiles at standard depths. 1 m-binned data come from the archive (J. Smith). More text here.")
    assert_nil e.short_desc("  ")
  end
end
