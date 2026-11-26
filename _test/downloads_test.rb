#!/usr/bin/env ruby
# _test/downloads_test.rb — what a dataset's Download button and dialog offer (_plugins/downloads.rb),
# against the small manifest in _test/fixtures/zip_manifest.json and synthetic records:
#
#     ruby _test/downloads_test.rb
#
#   all three   csv · xlsx · parquet written: CSV is the default, Excel second, Parquet under "Other"
#   no xlsx     the manifest's own plain-words reason is carried, and the CSV's "too long" note
#   licence     unstated says no licence is established and never implies open terms; "unknown" is
#               pending; custom links the provider's terms; CC BY and CC0 by name
#   holding     never an offer, even if the manifest names its key
#   absent      no manifest (or a non-1.x one), or nothing written: nil — no button anywhere
#   record      the record's own `bundle` distributions win over the manifest
#   1.1         content-addressed URLs used as given; "verified against" checked_version, "unchanged
#               since" only when `since` is earlier; a higher schema still read
#   catalog     Catalog#downloads, the tile row's #download control, "Download as a zip" first in Get
#               the data, and no whole-table ERDDAP .csv/.json link (ERDDAP answers those 403)
#   browse      Browse datasets' rows (_plugins/browse.rb) carry the same #download control and no
#               second whole-dataset download
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
    def self.logger = (@logger ||= Class.new { def warn(*) = nil }.new)
  end
end
require_relative "../_plugins/datasets"

class DownloadsTest < Minitest::Test
  D = CalCOFI::Downloads
  MANIFEST = JSON.parse(File.read(File.join(__dir__, "fixtures", "zip_manifest.json")))
  IDX = D.index(MANIFEST)
  BYTES = ->(b) { CalCOFI::Fmt.bytes(b) }

  def record(key, license: nil, license_url: nil, dist: [])
    { "dataset_key" => key, "dataset_name" => "Dataset #{key}", "dataset_name_short" => key.upcase,
      "attribution" => { "license" => license, "license_url" => license_url },
      "distributions" => dist, "coverage" => { "n_obs" => 10 } }
  end

  def offer(key, **kw)
    D.offer(record(key, **kw), IDX[key], bytes: BYTES, part: { "label" => "Explorer", "url" => "https://calcofi.io/explore/?datasets=#{key}", "app" => true })
  end

  # ── all three formats ──────────────────────────────────────────────────────
  # the front door names the formats from the manifest, never from a typed list
  def test_format_labels_are_the_formats_the_release_writes
    assert_equal %w[CSV Excel Parquet], D.format_labels(MANIFEST)
    one = { "schema_version" => "1.0", "datasets" => [{ "dataset_key" => "a", "bundles" => [
      { "format" => "parquet", "written" => true, "url" => "https://x/a_parquet.zip" },
      { "format" => "xlsx", "written" => false, "reason" => "too many rows" },
      { "format" => "csv", "written" => true, "url" => "" }] }] }
    assert_equal %w[Parquet], D.format_labels(one), "a format no dataset is written in, or with no address, is not promised"
    assert_equal [], D.format_labels(nil)
    assert_equal "CSV, Excel or Parquet", D.any_of(%w[CSV Excel Parquet])
    assert_equal "CSV or Parquet", D.any_of(%w[CSV Parquet])
    assert_equal "CSV", D.any_of(%w[CSV])
    assert_nil D.any_of([])
  end

  def test_all_three_formats_csv_first
    o = offer("x_all", license: "CC-BY-4.0", license_url: "https://creativecommons.org/licenses/by/4.0/")
    assert_equal %w[csv xlsx], o["main"].map { |x| x["format"] }
    assert_equal %w[parquet], o["other"].map { |x| x["format"] }
    assert_equal "csv", o["primary"]["format"]
    assert o["main"].first["primary"]
    refute o["main"].last["primary"]
    assert_equal "CSV · 425 KB", o["what"]
    assert_equal "https://storage.googleapis.com/calcofi-db/publish/zip/x_all/x_all_v9.9.9_csv.zip", o["primary"]["url"]
    assert_equal "x_all_v9.9.9_csv.zip", o["primary"]["file"]
    assert_equal "2 data tables, a readme, how to cite, the licence and a column dictionary", o["primary"]["inside"]
    assert_equal "v9.9.9", o["version"]
    assert_equal "manifest", o["source"]
    assert_equal %w[csv xlsx parquet], o["formats"]
    assert_nil o["primary"]["note"]
  end

  # ── Excel not written: the manifest's reason, verbatim ──────────────────────
  def test_xlsx_not_written_carries_the_reason_and_the_csv_note
    o = offer("x_big")
    xl = o["main"].find { |x| x["format"] == "xlsx" }
    refute xl["written"]
    assert_match(/\ANot offered as an Excel workbook: its largest table, obs, has 11,135,334 rows/, xl["reason"])
    assert_nil xl["url"]
    csv = o["main"].first
    assert_equal "csv", csv["format"]
    assert_match(/more rows than a spreadsheet can open/, csv["note"])
    assert_equal "CSV · 171 MB", o["what"]
    refute_includes o["aria"], "Excel"
  end

  # ── the licence, truthfully ─────────────────────────────────────────────────
  def test_unstated_licence_never_implies_open_terms
    l = offer("x_big")["licence"]
    assert_equal "unstated", l["kind"]
    assert_match(/No licence has been established/, l["text"])
    refute_match(/\b(open|free to reuse|CC BY|public domain)\b/i, l["text"])
    assert_nil l["url"]
    assert_equal "data@calcofi.io", l["contact"]
  end

  def test_pending_custom_and_named_licences
    assert_equal "pending", D.licence({ "license" => "unknown" })["kind"]
    refute_match(/free to reuse/, D.licence({ "license" => "unknown" })["text"])
    c = D.licence({ "license" => "custom", "license_url" => "https://portal.edirepository.org/x" })
    assert_equal "custom", c["kind"]
    assert_equal "https://portal.edirepository.org/x", c["url"]
    assert_match(/provider’s own terms/, c["text"])
    assert_match(/no link/, D.licence({ "license" => "custom" })["text"])
    assert_equal "CC BY 4.0", D.licence({ "license" => "CC-BY-4.0" })["label"]
    assert_equal "public-domain", D.licence({ "license" => "CC0-1.0" })["kind"]
    assert_equal "Creative Commons Attribution Share Alike", D.licence({ "license" => "CC-BY-SA-4.0", "license_name" => "Creative Commons Attribution Share Alike" })["label"]
    assert_equal "CC BY NC 4.0", D.licence({ "license" => "CC-BY-NC-4.0" })["label"]
  end

  # the record's licence wins over the manifest's license_kind (the chip and the dialog agree)
  def test_record_licence_wins_over_manifest
    o = offer("x_all", license: "custom", license_url: "https://example.org/terms")
    assert_equal "custom", o["licence"]["kind"]
  end

  # ── nothing to download ─────────────────────────────────────────────────────
  def test_holding_has_no_offer
    assert_nil D.offer(record("x_all"), IDX["x_all"], holding: true)
  end

  def test_manifest_absent_or_foreign_or_unwritten
    assert_equal({}, D.index(nil))
    assert_equal({}, D.index(MANIFEST.merge("schema_version" => "0.9")))
    assert_equal({}, D.index(MANIFEST.merge("schema_version" => nil)))
    assert_nil D.offer(record("x_all"), nil)
    assert_nil D.offer(record("x_all"), D.index(nil)["x_all"])
    assert_nil offer("x_none")
    assert_nil offer("x_not_in_manifest")
  end

  # ── the live 1.1 shape: content-addressed URLs, since / checked_version / hashes ──────────
  M11 = JSON.parse(File.read(File.join(__dir__, "fixtures", "zip_manifest_1_1.json")))

  def test_schema_1_1_content_addressed
    idx = D.index(M11)
    assert_equal %w[x_hash x_new], idx.keys.sort, "1.1 is read, unknown fields ignored"
    o = D.offer(record("x_hash", license: "CC0-1.0"), idx["x_hash"], bytes: BYTES)
    # the URL is used exactly as given (hash directory and all); the name is its last path segment
    assert_equal "https://storage.googleapis.com/calcofi-db/publish/zip/x_hash/3872789ed24411383f47ae8a/x_hash_v9.9.9_csv.zip", o["primary"]["url"]
    assert_equal "x_hash_v9.9.9_csv.zip", o["primary"]["file"]
    xl = o["main"].find { |x| x["format"] == "xlsx" }
    assert_equal "https://storage.googleapis.com/calcofi-db/publish/zip/x_hash/3872789ed24411383f47ae8a/x_hash_v9.9.9_xlsx.zip?generation=1", xl["url"]
    assert_equal "x_hash_v9.9.9_xlsx.zip", xl["file"]
    # verified against the current release; unchanged since the release the content first appeared
    assert_equal "v9.9.12", o["version"]
    assert_equal "v9.9.9", o["since"]
    assert_empty o["other"], "parquet not written, and an unknown format is never offered"
    assert_equal %w[csv xlsx], o["formats"]
  end

  def test_since_said_only_when_it_differs
    o = D.offer(record("x_new"), D.index(M11)["x_new"], bytes: BYTES)
    assert_equal "v9.9.12", o["version"]
    assert_nil o["since"]
  end

  def test_a_higher_schema_is_still_read
    assert_equal %w[x_hash x_new], D.index(M11.merge("schema_version" => "2.0")).keys.sort
  end

  def test_version_prefers_checked_version
    entry = { "dataset_key" => "v", "version" => "v1", "checked_version" => "v3",
              "bundles" => [{ "format" => "csv", "written" => true, "url" => "https://e/a.zip" }] }
    assert_equal "v3", D.offer(record("v"), entry)["version"]
    entry["bundles"][0]["checked_version"] = "v4"
    assert_equal "v4", D.offer(record("v"), entry)["version"]
    entry.delete("checked_version"); entry["bundles"][0].delete("checked_version")
    assert_equal "v1", D.offer(record("v"), entry)["version"]
  end

  # ── the record's own bundles win ───────────────────────────────────────────
  def test_record_bundles_preferred
    dist = [{ "kind" => "bundle", "format" => "csv", "url" => "https://example.org/r_csv.zip", "bytes" => 1024 },
            { "kind" => "bundle", "format" => "dwca", "url" => "https://example.org/r_dwca.zip" },
            { "kind" => "download", "format" => "parquet", "url" => "https://example.org/obs.parquet" }]
    o = D.offer(record("x_all", dist: dist), IDX["x_all"], bytes: BYTES)
    assert_equal "record", o["source"]
    assert_equal %w[csv], o["formats"]
    assert_equal "https://example.org/r_csv.zip", o["primary"]["url"]
    assert_equal "r_csv.zip", o["primary"]["file"]
    assert_empty o["other"]
  end

  # regression 2026-11-26: a release is cut before its zips are built, so its record lists the zips
  # of the release before. Once the manifest has been checked against a later release, it is the truth.
  def test_manifest_checked_against_a_later_release_wins
    dist  = [{ "kind" => "bundle", "format" => "csv", "url" => "https://example.org/old_csv.zip",
               "checked_version" => "v2026.11.14" }]
    entry = { "dataset_key" => "z", "version" => "v2026.11.26", "checked_version" => "v2026.11.26",
              "bundles" => [{ "format" => "csv", "written" => true, "url" => "https://example.org/new_csv.zip" }] }
    o = D.offer(record("z", dist: dist), entry, bytes: BYTES)
    assert_equal "manifest", o["source"]
    assert_equal "https://example.org/new_csv.zip", o["primary"]["url"]
    assert_equal "v2026.11.26", o["version"]
  end

  def test_record_wins_a_tie_and_an_older_or_unreadable_manifest
    dist = [{ "kind" => "bundle", "format" => "csv", "url" => "https://example.org/r_csv.zip",
              "checked_version" => "v2026.11.26" }]
    %w[v2026.11.26 v2026.11.14 nonsense].each do |v|
      entry = { "dataset_key" => "z", "checked_version" => v,
                "bundles" => [{ "format" => "csv", "written" => true, "url" => "https://example.org/m_csv.zip" }] }
      assert_equal "record", D.offer(record("z", dist: dist), entry, bytes: BYTES)["source"], v
    end
  end

  def test_later
    assert D.later?("v2026.11.26", "v2026.11.14")
    assert D.later?("v2026.12.01", "v2026.11.30")
    assert D.later?("v2026.11.26", nil)
    refute D.later?("v2026.11.26", "v2026.11.26")
    refute D.later?(nil, "v2026.11.26")
    refute D.later?("v9.9.12", "v2026.11.26")
  end

  # a dataset whose only written zip is Parquet still gets a button, named for what it is
  def test_primary_falls_back_to_the_first_written
    entry = { "dataset_key" => "p", "bundles" => [{ "format" => "csv", "written" => false, "reason" => "r" },
                                                  { "format" => "parquet", "written" => true, "url" => "https://e/p.zip", "bytes" => 2048 }] }
    o = D.offer(record("p"), entry, bytes: BYTES)
    assert_equal "parquet", o["primary"]["format"]
    assert_equal "Parquet · 2.0 KB", o["what"]
  end

  # ── the catalog wiring ─────────────────────────────────────────────────────
  FakeSite = Struct.new(:data, :config)

  def catalog(manifest)
    data = { "products" => { "products" => [] } }
    data["zip_manifest"] = manifest if manifest
    rec = { "release" => { "version" => "v9.9.9" }, "datasets" => [ds("x_all"), ds("x_big")], "holdings" => [] }
    CalCOFI::Catalog.new(FakeSite.new(data, { "url" => "https://calcofi.io" }), rec, [])
  end

  def ds(key)
    { "dataset_key" => key, "dataset_name" => "Dataset #{key}", "category" => { "name" => "C", "realm" => "env" },
      "attribution" => {}, "coverage" => { "n_obs" => 10 }, "tables" => ["obs"], "status" => { "stage" => "published" },
      "distributions" => [
        { "kind" => "service", "format" => "erddap", "portal" => "erddap", "id" => key, "grain" => "obs",
          "url" => "https://erddap.calcofi.io/erddap/tabledap/#{key}.html" },
        { "kind" => "download", "format" => "netcdf", "url" => "https://example.org/#{key}.nc", "bytes" => 4096 }] }
  end

  def test_catalog_offer_tile_and_get_the_data
    ENV["CALCOFI_SKIP_LINK_CHECK"] = "1"
    c = catalog(MANIFEST)
    r = c.datasets.first
    o = c.downloads(r)
    assert_equal "csv", o["primary"]["format"]
    assert_equal ["ERDDAP subset form", "CF netCDF"], o["endpoints"].map { |e| e["label"] }
    assert_equal "https://erddap.calcofi.io/erddap/tabledap/x_all.html", o["endpoints"].first["url"]
    t = c.tile_row(r)
    assert_equal "/datasets/x_all/#download", t["download"]["url"]
    assert_match(/\ADownload Dataset x_all: CSV · /, t["download"]["aria"])
    data = c.access_groups(r).find { |g| g["id"] == "data" }
    assert_equal "Download as a zip", data["blocks"].first["title"]
    assert_equal ["CSV (zip)", "Excel (zip)", "Parquet (zip)"], data["blocks"].first["rows"].map { |x| x["label"] }
    erd = data["blocks"].find { |b| b["matrix"] }
    urls = erd["matrix"].flat_map { |m| [m["page"], m["info"], m["graph"]] + (m["formats"] || []).map { |f| f["url"] } }.compact
    assert urls.none? { |u| u =~ /\.(csv|json)\z/ }, "no whole-table ERDDAP CSV/JSON link: #{urls}"
  end

  # Browse datasets (_plugins/browse.rb, front door v2): the preview's Download is the same control as a
  # tile row's — the dataset page's dialog — and carries no second whole-dataset download (the form's
  # ERDDAP / Parquet / NetCDF files and the in-browser CSV went on 2026-11-17, reconciling with main)
  def test_browse_row_download_is_the_zip_dialog
    ENV["CALCOFI_SKIP_LINK_CHECK"] = "1"
    require_relative "../_plugins/browse"
    c = catalog(JSON.parse(File.read(File.join(__dir__, "fixtures", "zip_manifest.json"))))
    rows = c.browse(nil)["rows"]
    row = rows.find { |x| x["key"] == "x_all" }
    assert_equal c.tile_row(c.datasets.find { |d| d["dataset_key"] == "x_all" })["download"]["url"], row["download"]["url"]
    assert_match %r{/datasets/x_all/#download\z}, row["download"]["url"]
    assert_equal c.downloads(c.datasets.find { |d| d["dataset_key"] == "x_all" })["what"], row["download"]["what"]
    rows.each { |x| %w[file dl dl_label].each { |k| refute x.key?(k), "browse row carries #{k}" } }
  end

  def test_browse_row_without_a_manifest_has_no_download
    ENV["CALCOFI_SKIP_LINK_CHECK"] = "1"
    require_relative "../_plugins/browse"
    assert(catalog(nil).browse(nil)["rows"].all? { |x| x["download"].nil? })
  end

  def test_catalog_without_a_manifest_draws_nothing
    ENV["CALCOFI_SKIP_LINK_CHECK"] = "1"
    c = catalog(nil)
    r = c.datasets.first
    assert_nil c.downloads(r)
    assert_nil c.tile_row(r)["download"]
    data = c.access_groups(r).find { |g| g["id"] == "data" }
    refute_equal "Download as a zip", data["blocks"].first["title"]
  end
end
