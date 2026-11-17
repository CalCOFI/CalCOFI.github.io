#!/usr/bin/env ruby
# _test/finder_test.rb — the rules of the Species and Measurements finders (/species/finder.json,
# /measurements/finder.json; _plugins/finder.rb, module CalCOFI::Finder), each against a small
# synthetic record so the exact output is asserted:
#
#     ruby _test/finder_test.rb
#
#   species rows   rank Species AND observed as the species itself; most observed first; a row's
#                  datasets core first, newest last; the Explorer link only for a worms: / itis: key
#   groups         the classes with observations, most observed first, with their typed names and
#                  their three commonest species; a species whose lineage names no class is in ONE
#                  group "Other" that is drawn (three sea turtles were in no group)
#   silhouettes    a row's own, else its nearest ancestor's; each outline held once
#   higher taxa    every taxon with a page that is not a row of the list (a genus, a family, a class,
#                  a species seen only as its subspecies, a dataset-local class), most recorded
#                  first, so the search finds "Sardinops"; one seen only in hidden datasets is not named
#   measurements   every measurement, most values first; categories in category.order, each with its
#                  count and the names of its four rows with the most values (a closed category's
#                  one line); units through the site's one display map; the Explorer link only for a
#                  key the Explorer carries
#   visibility     a dataset the catalog does not show (visibility: internal) names no row
#   GROUP_NAMES    every typed group name is for a class the record has (the list is editorial,
#                  pending a decision on moving the names into the taxa record)
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
require_relative "../_plugins/finder"

class FinderTest < Minitest::Test
  F = CalCOFI::Finder

  # the catalog's datasets (the visible ones): x_held is in the taxa and measurement records, not here
  DATASETS = {
    "x_larvae" => { "dataset_key" => "x_larvae", "dataset_name" => "X Larval Fish Survey", "dataset_name_short" => "Larvae", "since_version" => "v2026.05.19" },
    "x_birds"  => { "dataset_key" => "x_birds", "dataset_name" => "X Seabirds", "since_version" => "v2026.08.02" },
    "x_eggs"   => { "dataset_key" => "x_eggs", "since_version" => "v2026.05.19" }
  }.freeze

  def taxon(key, sci, rank, cls: nil, parent: nil, com: nil, direct: 0, rollup: nil, n_sp: 0, n_taxa: 1, ds: [], stages: [])
    { "taxon_key" => key, "slug" => key.tr(":", "-"), "scientific_name" => sci, "common_name" => com, "rank" => rank,
      "parent_taxon_key" => parent, "lineage" => { "class" => cls },
      "direct" => { "n_obs" => direct, "life_stages" => stages },
      "rollup" => { "n_obs" => rollup || direct, "n_species" => n_sp, "n_taxa" => n_taxa, "year_min" => 1951, "year_max" => 2023 },
      "datasets" => ds }
  end

  def seen(key, n, y0 = 2000, y1 = 2001, years = nil)
    { "dataset_key" => key, "n_obs" => n, "year_min" => y0, "year_max" => y1, "years" => years || { y0.to_s => n, y1.to_s => 0 } }
  end

  def taxa
    [
      taxon("worms:10", "Teleostei", "Class", rollup: 700, n_sp: 3, n_taxa: 5),
      taxon("worms:11", "Sebastes", "Genus", cls: "Teleostei", parent: "worms:10", direct: 300, ds: [seen("x_larvae", 300)]),
      taxon("worms:12", "Sebastes paucispinis", "Species", cls: "Teleostei", parent: "worms:11", com: " Bocaccio ", direct: 120, stages: %w[larva],
            ds: [seen("x_eggs", 20, 1996, 1997), seen("x_larvae", 90, 1951, 2023, { "1951" => 50, "1960" => 0, "2023" => 40 }), seen("x_held", 10, 2020, 2020)]),
      taxon("worms:13", "Engraulis mordax", "Species", cls: "Teleostei", parent: "worms:10", com: "Northern anchovy", direct: 500, ds: [seen("x_larvae", 500)]),
      taxon("worms:14", "Sardinops sagax", "Species", cls: "Teleostei", parent: "worms:10", direct: 0, rollup: 30, ds: [seen("x_larvae", 30)]),
      taxon("worms:15", "Merluccius productus", "Species", cls: "Teleostei", parent: "worms:10", com: "Pacific hake", direct: 80, ds: [seen("x_larvae", 80)]),
      taxon("worms:16", "Citharichthys sordidus", "Species", cls: "Teleostei", parent: "worms:10", direct: 60, ds: [seen("x_larvae", 60)]),
      taxon("itis:20", "Aves", "Class", rollup: 61, n_sp: 1, n_taxa: 1),
      taxon("itis:21", "Larus brachyrhynchus", "Species", cls: "Aves", parent: "itis:20", com: "Mew Gull", direct: 61, ds: [seen("x_birds", 61)]),
      taxon("worms:30", "Copepoda", "Class", rollup: 900, n_sp: 0, n_taxa: 4),
      taxon("worms:31", "Hexanauplia", "Class", rollup: 0),
      taxon("worms:40", "Caretta caretta", "Species", cls: nil, com: "Loggerhead Turtle", direct: 9, ds: [seen("x_birds", 9)]),
      taxon("x_larvae:13", nil, "Species", cls: nil, direct: 4, ds: [seen("x_larvae", 4)]),
      taxon("worms:50", "Secretus absconditus", "Species", cls: "Teleostei", parent: "worms:10", direct: 1000, ds: [seen("x_held", 1000)])
    ]
  end

  MEDIA = { "base" => "https://media.example/", "taxa" => {
    "worms:10" => { "silhouette" => { "viewBox" => "0 0 10 10", "svg_inner" => "<path d='fish'/>" } },
    "worms:12" => { "silhouette" => { "viewBox" => "0 0 4 4", "svg_inner" => "<path d='bocaccio'/>" },
                    "photo" => { "cached" => "photos/bocaccio.jpg", "url" => "https://elsewhere/b.jpg", "license" => "CC BY" },
                    "text" => { "extract" => "A rockfish. " * 60, "url" => "https://en.wikipedia.org/wiki/Bocaccio" }, "size" => { "m" => 0.9 } },
    "worms:13" => { "photo" => { "cached" => "", "url" => "https://elsewhere/anchovy.jpg" } }
  } }.freeze

  def species = F.species({ "release" => { "version" => "v9.9.9" }, "counts" => { "species_observed" => 6 }, "taxa" => taxa }, MEDIA, DATASETS)

  # ── species ──────────────────────────────────────────────────────────────
  def test_species_rows_are_species_observed_as_themselves_most_observed_first
    assert_equal ["worms:13", "worms:12", "worms:15", "itis:21", "worms:16", "worms:40", "x_larvae:13"], species["rows"].map { |r| r["k"] },
                 "a genus, a class, a species seen only below itself and a species seen only in a hidden dataset have no row"
  end

  def test_a_species_row
    r = species["rows"].find { |x| x["k"] == "worms:12" }
    assert_equal "/species/worms-12/", r["url"]
    assert_equal ["Sebastes paucispinis", "Bocaccio", "Teleostei", "Bony fishes"], r.values_at("sci", "com", "cls", "grp")
    assert_equal [120, 1951, 2023], r.values_at("n", "y0", "y1")
    assert_equal [["x_larvae", 1951, 2023, 90], ["x_eggs", 1996, 1997, 20]], r["ds"],
                 "its datasets core first (the same release: the larger first); the hidden dataset is not named"
    assert_equal [1951, 1996, 2023], r["years"], "the years with a count, over its datasets, once each"
    assert_equal %w[larva], r["stages"]
    assert_equal "https://media.example/photos/bocaccio.jpg", r["photo"], "the cached photo under the sidecar's base"
    assert_equal "CC BY", r["photo_lic"]
    assert_equal 420, r["text"].length, "the extract, cut"
    assert_equal "https://en.wikipedia.org/wiki/Bocaccio", r["wiki"]
    assert_equal 0.9, r["size"]
    assert_equal "?taxon=worms:12", r["map"]
  end

  def test_a_photo_with_no_cached_copy_is_its_own_url_and_no_photo_is_nil
    rows = species["rows"].to_h { |r| [r["k"], r] }
    assert_equal "https://elsewhere/anchovy.jpg", rows["worms:13"]["photo"]
    assert_nil rows["worms:15"]["photo"]
    assert_nil rows["worms:15"]["text"]
  end

  def test_the_explorer_link_is_only_for_an_authority_key
    assert_equal "?taxon=worms:217452", F.taxon_param("worms:217452")
    assert_equal "?taxon=itis:176817", F.taxon_param("itis:176817")
    assert_nil F.taxon_param("calcofi_phytoplankton:218"), "a dataset-local key is not one the Explorer keys by"
    assert_nil F.taxon_param(nil)
    rows = species["rows"].to_h { |r| [r["k"], r] }
    assert_equal "?taxon=itis:21", rows["itis:21"]["map"]
    assert_nil rows["x_larvae:13"]["map"]
  end

  def test_groups_are_the_classes_with_observations_most_observed_first
    g = species["groups"]
    assert_equal %w[Copepoda Teleostei Aves Other], g.map { |x| x["cls"] }, "a class with no observation is not a group"
    assert_equal ["Copepods", "Bony fishes", "Seabirds", "Other"], g.map { |x| x["grp"] }
    fish = g[1]
    assert_equal({ "cls" => "Teleostei", "grp" => "Bony fishes", "n_sp" => 3, "n_taxa" => 5, "n" => 700,
                   "top" => ["Northern anchovy", "Bocaccio", "Pacific hake"], "sil" => fish["sil"] }, fish)
    assert_equal [], g[0]["top"], "a class with no species row names none"
    assert_equal 0, g[0]["n_sp"]
  end

  # regression (2026-11-17, S-31): three sea turtles (lineage.class null in v2026.11.14) were in All species
  # and in no group. The rule: one group "Other", drawn last, holds every row no class group holds.
  def test_a_species_with_no_class_is_in_the_group_other_which_is_drawn
    s = species
    other = s["groups"].last
    assert_equal({ "cls" => "Other", "grp" => "Other", "n_sp" => 2, "n_taxa" => 2, "n" => 13,
                   "top" => ["Loggerhead Turtle", nil], "sil" => nil }, other)
    assert_equal ["worms:40", "x_larvae:13"], s["rows"].select { |r| r["cls"] == "Other" }.map { |r| r["k"] }
    drawn = s["groups"].map { |g| g["cls"] }
    s["rows"].each { |r| assert_includes drawn, r["cls"], "#{r['k']} is in no group" }
    assert_equal s["rows"].size, s["groups"].sum { |g| s["rows"].count { |r| r["cls"] == g["cls"] } }
  end

  def test_no_other_group_when_every_species_has_a_class
    with_class = taxa.reject { |t| %w[worms:40 x_larvae:13].include?(t["taxon_key"]) }
    g = F.species({ "taxa" => with_class }, MEDIA, DATASETS)["groups"]
    assert_equal %w[Copepoda Teleostei Aves], g.map { |x| x["cls"] }
  end

  def test_silhouettes_own_else_nearest_ancestors_each_held_once
    s = species
    rows = s["rows"].to_h { |r| [r["k"], r] }
    assert_equal [["0 0 4 4", "<path d='bocaccio'/>"], ["0 0 10 10", "<path d='fish'/>"]].sort, s["sils"].sort
    assert_equal ["0 0 4 4", "<path d='bocaccio'/>"], s["sils"][rows["worms:12"]["sil"]], "its own"
    assert_equal ["0 0 10 10", "<path d='fish'/>"], s["sils"][rows["worms:13"]["sil"]], "its class's"
    assert_equal rows["worms:13"]["sil"], rows["worms:15"]["sil"], "one outline, one index"
    assert_nil rows["itis:21"]["sil"], "no ancestor has one"
    assert_equal rows["worms:13"]["sil"], s["groups"][1]["sil"], "the class's own outline"
  end

  def test_the_files_name_each_dataset_a_row_names_and_no_other
    assert_equal({ "x_larvae" => { "name" => "Larvae", "page" => "/datasets/x_larvae/" },
                   "x_eggs" => { "name" => "x_eggs", "page" => "/datasets/x_eggs/" },
                   "x_birds" => { "name" => "X Seabirds", "page" => "/datasets/x_birds/" } }, species["files"])
  end

  def test_species_carries_the_releases_version_and_counts_and_is_nil_without_a_record
    assert_equal "v9.9.9", species["release"]
    assert_equal({ "species_observed" => 6 }, species["counts"])
    assert_nil F.species(nil, MEDIA, DATASETS)
    assert_nil F.species({}, MEDIA, DATASETS)
    assert_equal 7, F.species({ "taxa" => taxa }, nil, DATASETS)["rows"].size, "no media sidecar: the rows, with no faces"
  end

  # ── the taxa that are not rows (/species/finder-taxa.json) ───────────────
  def test_higher_taxa_are_the_taxa_with_a_page_that_are_not_rows_most_recorded_first
    hi = species["taxa"]
    # not the seven rows; not Secretus absconditus, seen only in a dataset the catalog does not show
    assert_equal ["Copepoda", "Teleostei", "Sebastes", "Aves", "Sardinops sagax", "Hexanauplia"], hi.map { |t| t["s"] }
    assert_empty hi.map { |t| t["u"] } & species["rows"].map { |r| r["url"] }, "a row of the list is not also a higher taxon"
    assert_equal species["rows"].size + hi.size + 1, taxa.size, "every taxon is a row, a higher taxon, or the hidden one"
  end

  def test_a_higher_taxon
    genus = species["taxa"].find { |t| t["s"] == "Sebastes" }
    assert_equal({ "u" => "/species/worms-11/", "s" => "Sebastes", "r" => "Genus", "g" => "Teleostei", "sp" => 0, "n" => 300,
                   "y0" => 1951, "y1" => 2023, "i" => true }, genus, "no common name: no key; a genus is in italics")
    cls = species["taxa"].find { |t| t["s"] == "Teleostei" }
    assert_equal ["Class", "Teleostei", 3, 700, nil], cls.values_at("r", "g", "sp", "n", "i"), "a class is its own group; not in italics"
  end

  def test_a_species_seen_only_as_its_subspecies_is_a_higher_taxon_not_a_row
    refute_includes species["rows"].map { |r| r["sci"] }, "Sardinops sagax"
    assert_equal ["Species", 30], species["taxa"].find { |t| t["s"] == "Sardinops sagax" }.values_at("r", "n")
  end

  def test_a_higher_taxon_seen_only_in_hidden_datasets_is_not_named_and_one_with_a_shown_descendant_is
    tx = [
      taxon("worms:1", "Clupeidae", "Family", rollup: 50, n_sp: 2, com: " herrings "),
      taxon("worms:2", "Sardinops", "Genus", parent: "worms:1", direct: 2, rollup: 32, n_sp: 1, ds: [seen("x_held", 2)]),
      taxon("worms:3", "Sardinops sagax", "Species", parent: "worms:2", direct: 30, ds: [seen("x_larvae", 30)]),
      taxon("worms:4", "Occultus", "Genus", parent: "worms:1", direct: 3, rollup: 18, n_sp: 1, ds: [seen("x_held", 3)]),
      taxon("worms:5", "Occultus latens", "Species", parent: "worms:4", direct: 15, ds: [seen("x_held", 15)]),
      taxon("worms:6", "Ignotidae", "Family", rollup: 0)
    ]
    hi = F.higher_taxa(tx, DATASETS, ["worms:3"])
    assert_equal %w[Clupeidae Sardinops Ignotidae], hi.map { |t| t["s"] },
                 "Sardinops is itself seen only in a hidden dataset but its species is in a shown one; Occultus and its " \
                 "species are only in the hidden one; a taxon under which no dataset is named at all stays"
    assert_equal "herrings", hi.first["c"], "the common name, trimmed"
  end

  def test_a_dataset_local_class_is_named_as_its_page_is
    loc = taxon("x_larvae:218", nil, nil, direct: 7, ds: [seen("x_larvae", 7)]).merge("local" => { "name" => nil, "code" => "218", "common_name" => "other" })
    assert_equal [{ "u" => "/species/x_larvae-218/", "s" => "218", "c" => "other", "sp" => 0, "n" => 7, "y0" => 1951, "y1" => 2023 }],
                 F.higher_taxa([loc], DATASETS, []), "no rank and no class: neither key is written"
    assert_equal "Clio", F.taxon_name("scientific_name" => "Clio", "local" => { "name" => "x" })
    assert_equal "x", F.taxon_name("scientific_name" => "", "local" => { "name" => "x", "code" => "9" })
    assert_equal "77", F.taxon_name("taxon_key" => "x_larvae:77")
  end

  def test_higher_taxa_of_no_record_and_a_parent_loop
    assert_empty F.higher_taxa(nil, DATASETS, [])
    loop_ = [taxon("a:1", "A", "Genus", parent: "a:2", ds: [seen("x_larvae", 1)]), taxon("a:2", "B", "Family", parent: "a:1")]
    assert_equal %w[A B], F.higher_taxa(loop_, DATASETS, []).map { |t| t["s"] }.sort, "a loop in the lineage ends"
  end

  def test_every_page_of_the_fetched_record_is_a_row_or_a_higher_taxon
    f = File.expand_path("../_data/taxa.json", __dir__)
    skip "no _data/taxa.json (run scripts/fetch_release.sh)" unless File.exist?(f)
    rec = JSON.parse(File.read(f))
    all = rec["taxa"].flat_map { |t| (t["datasets"] || []).map { |d| d["dataset_key"] } }.uniq.to_h { |k| [k, { "dataset_key" => k }] }
    sp = F.species(rec, nil, all)
    assert_equal rec["taxa"].size, sp["rows"].size + sp["taxa"].size, "with every dataset shown, no page is left unfindable"
  end

  # ── the typed group names ────────────────────────────────────────────────
  def test_group_name_is_the_typed_one_else_the_class
    assert_equal "Bony fishes", F.group_name("Teleostei")
    assert_equal "Hexanauplia", F.group_name("Hexanauplia")
  end

  def test_stale_group_names_are_the_typed_keys_the_record_has_no_class_for
    names = { "Teleostei" => "Bony fishes", "Aves" => "Seabirds", "Reptilia" => "Sea turtles", "Sebastes" => "Rockfishes" }
    assert_equal %w[Reptilia Sebastes], F.stale_group_names(taxa, names), "a genus is not a class"
    assert_equal [], F.stale_group_names(taxa, names.slice("Teleostei", "Aves"))
    assert_equal names.keys, F.stale_group_names(nil, names)
  end

  # the guard on the committed list, against the release this checkout last fetched (skipped on a fresh
  # clone, where _data/taxa.json is absent): every typed name is for a class the record has
  def test_every_typed_group_name_is_a_class_in_the_fetched_record
    f = File.join(__dir__, "..", "_data", "taxa.json")
    skip "no _data/taxa.json (run scripts/fetch_release.sh)" unless File.exist?(f)
    assert_equal [], F.stale_group_names(JSON.parse(File.read(f))["taxa"])
  end

  # ── helpers ──────────────────────────────────────────────────────────────
  def test_core_sort_is_by_the_release_joined_then_the_larger
    since = { "a" => "v2", "b" => "v1", "c" => "v1", "d" => "v1" }
    list = [{ "dataset_key" => "a", "n" => 9 }, { "dataset_key" => "b", "n" => 1 }, { "dataset_key" => "c", "n" => 5 }, { "dataset_key" => "d", "n" => 5 }]
    assert_equal %w[c d b a], F.core_sort(list, "n", since).map { |x| x["dataset_key"] }
    assert_equal [], F.core_sort([], "n", since)
  end

  def test_years_of
    assert_equal [1987, 1993], F.years_of({ "1993" => 2, "1988" => 0, "1987" => 1, "1990" => nil })
    assert_equal [], F.years_of(nil)
  end

  # ── measurements ─────────────────────────────────────────────────────────
  def meas(key, n, cat, order, units: nil, short: nil, unified: false, series: [], **extra)
    { "key" => key, "slug" => key, "label" => "#{key} (long)", "short_label" => short, "description" => "About #{key}.", "units" => units,
      "is_unified" => unified, "category" => { "name" => cat, "icon" => "cat-x", "order" => order },
      "totals" => { "n_values" => n, "year_min" => 1949, "year_max" => 2026, "depth_min_m" => 0, "depth_max_m" => 5351 },
      "series" => series }.merge(extra)
  end

  def ser(key, n, y0 = 2000, y1 = 2001) = { "dataset_key" => key, "n_values" => n, "year_min" => y0, "year_max" => y1, "years" => { y0.to_s => n } }

  def measurements_rec
    { "release" => { "version" => "v9.9.9" }, "counts" => { "measurements" => 4 }, "measurements" => [
      meas("nitrate", 300, "Nutrients & Chemistry", 2, units: "umol/L", series: [ser("x_eggs", 300)]),
      meas("temperature", 900, "Physical Oceanography", 1, units: "degC", short: "Temperature", unified: true, "nerc_p01" => "TEMPPR01",
           series: [ser("x_birds", 100, 2010, 2011), ser("x_larvae", 700, 1949, 2021), ser("x_held", 100)]),
      meas("mystery", 5000, "Physical Oceanography", 1, series: [ser("x_held", 5000)]),
      meas("wind", 20, "Meteorology", 3, units: "m/s", series: [])
    ] }
  end

  COVERAGE = { "variables" => [{ "realm" => "env", "variable" => "temperature" }, { "realm" => "env", "measurement_type" => "nitrate" },
                               { "realm" => "bio", "variable" => "wind" }] }.freeze
  SOURCES = { "temperature" => { "nerc" => { "definition" => "The degree of hotness. " * 30, "pref" => "Temperature of the water body" } } }.freeze

  def measurements = F.measurements(measurements_rec, SOURCES, COVERAGE, DATASETS)

  def test_measurement_rows_most_values_first_and_categories_in_order
    m = measurements
    assert_equal %w[temperature nitrate wind], m["rows"].map { |r| r["k"] }
    assert_equal [["Physical Oceanography", 1], ["Nutrients & Chemistry", 2], ["Meteorology", 3]], m["cats"].map { |c| [c["name"], c["order"]] }
    assert_equal "v9.9.9", m["release"]
  end

  # a closed category says how many measurements it holds and names the ones with the most values
  def test_a_category_counts_its_rows_and_names_the_ones_with_the_most_values
    m = measurements
    assert_equal [1, 1, 1], m["cats"].map { |c| c["n"] }, "the hidden dataset's row (mystery) is not counted"
    assert_equal [["Temperature"], ["nitrate (long)"], ["wind (long)"]].map(&:size), m["cats"].map { |c| c["top"].size }
    assert_equal ["Temperature"], m["cats"].first["top"], "the short label, as the row is headed"
    many = { "measurements" => (1..6).map { |i| meas("m#{i}", i * 10, "Physical Oceanography", 1, short: "M#{i}", series: [ser("x_eggs", i * 10)]) } }
    c = F.measurements(many, SOURCES, COVERAGE, DATASETS)["cats"].first
    assert_equal 6, c["n"]
    assert_equal %w[M6 M5 M4 M3], c["top"], "the #{F::CAT_TOP} with the most values, most first"
  end

  def test_a_measurement_row
    r = measurements["rows"].first
    assert_equal({ "k" => "temperature", "url" => "/measurements/temperature/", "lab" => "Temperature", "full" => "temperature (long)",
                   "desc" => "About temperature.", "units" => "°C", "cat" => "Physical Oceanography", "unified" => true,
                   "n" => 900, "y0" => 1949, "y1" => 2026, "dmin" => 0, "dmax" => 5351, "years" => [1949, 2010],
                   "ds" => [["x_larvae", 1949, 2021, 700], ["x_birds", 2010, 2011, 100]],
                   "defn" => r["defn"], "nerc" => "Temperature of the water body", "p01" => "TEMPPR01", "map" => "?var=temperature" }, r)
    assert_equal 380, r["defn"].length, "the definition, cut"
  end

  def test_units_are_shown_through_the_one_display_map
    rows = measurements["rows"].to_h { |r| [r["k"], r] }
    assert_equal "µmol/L", rows["nitrate"]["units"]
    assert_equal "m/s", rows["wind"]["units"]
    refute CalCOFI::FinderData.const_defined?(:UNITS, false), "the second unit map is gone"
  end

  def test_the_explorer_link_is_only_for_a_key_the_explorer_carries
    rows = measurements["rows"].to_h { |r| [r["k"], r] }
    assert_equal "?var=nitrate", rows["nitrate"]["map"], "known by its measurement_type where the coverage sets no variable"
    assert_nil rows["wind"]["map"], "an env key only: the coverage lists wind under bio"
    none = F.measurements(measurements_rec, SOURCES, nil, DATASETS)["rows"]
    assert(none.all? { |r| r["map"].nil? }, "no coverage file: no prefilled link at all")
  end

  # regression (2026-11-17, S-28): the finders read datasets.json from disk, past Catalog#visible
  def test_a_hidden_dataset_names_no_row_and_no_series
    m = measurements
    refute_includes m["rows"].map { |r| r["k"] }, "mystery", "carried only by a hidden dataset"
    assert_equal %w[x_birds x_eggs x_larvae], m["files"].keys.sort
    m["rows"].each { |r| refute_includes r["ds"].map(&:first), "x_held" }
    s = species
    refute_includes s["rows"].map { |r| r["k"] }, "worms:50"
    refute_includes s["files"].keys, "x_held"
    s["rows"].each { |r| refute_includes r["ds"].map(&:first), "x_held" }
    shown = F.species({ "taxa" => taxa }, MEDIA, DATASETS.merge("x_held" => { "dataset_key" => "x_held", "since_version" => "v2026.09.01" }))
    assert_includes shown["rows"].map { |r| r["k"] }, "worms:50", "a preview build, where the catalog shows it, lists it"
  end

  def test_a_measurement_with_no_series_at_all_keeps_its_row
    assert_equal [], measurements["rows"].find { |r| r["k"] == "wind" }["ds"]
  end

  # regression (2026-11-17): main's one search found a measurement by its NERC P01 code (check_layout searches
  # "NTRAZZXX"); the finder's rows did not carry the code, so the search could not. A row carries it when the
  # record does, and nil when it does not.
  def test_a_measurement_row_carries_its_nerc_code_for_the_search
    by = measurements["rows"].to_h { |r| [r["k"], r["p01"]] }
    assert_equal "TEMPPR01", by["temperature"]
    assert_nil by["nitrate"]
  end

  def test_measurements_is_nil_without_a_record
    assert_nil F.measurements(nil, SOURCES, COVERAGE, DATASETS)
    assert_nil F.measurements({}, SOURCES, COVERAGE, DATASETS)
  end
end
