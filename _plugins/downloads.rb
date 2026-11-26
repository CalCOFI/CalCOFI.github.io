# _plugins/downloads.rb — what a dataset's Download button and its dialog offer.
#
# The release pipeline (workflows publish_to-zip.qmd) builds, per dataset, one zip per format:
# `csv` (every dataset), `xlsx` (only where every table fits an Excel sheet) and `parquet`
# (every dataset). Each zip holds the tables plus README.md, CITATION.md/.bib, LICENSE.txt and
# columns.csv. They are described in two places, read in this order:
#
#   1. the record itself — `distributions[]` rows of kind `bundle` with a format of csv · xlsx ·
#      parquet (calcofi4db, once build_dataset_catalog() carries them)
#   2. the zip manifest, `_data/zip_manifest.json` (scripts/fetch_release.sh, from
#      {calcofi-db}/publish/zip/manifest.json, schema 1.x or later), one entry per dataset with its bundles[]
#
# With neither, `offer` is nil and no Download button, row control or "Download as a zip" block is
# drawn anywhere: that is the state until the zips are first uploaded, so the site is safe to deploy
# before they exist. A holding never has one (it is not in a release).
#
# Every word a reader sees about a FORMAT is written here, once, because it is about the format and
# not about any dataset. Every number (bytes, tables, rows) and every reason a format is not offered
# is read from the record or the manifest, never typed. The licence line follows
# _includes/licence_chip.html's rule on the RECORD's attribution: an unstated licence is said to be
# unstated and never implies open terms; custom terms link the provider's own page.
#
# The contract is read defensively. Since schema 1.1 (2026-11-16) the zips are content-addressed:
# a URL carries a hash directory (…/swfsc_ichthyo/3872789ed24411383f47ae8a/…_csv.zip) and the
# version in a file name is `since`, the release where that content first appeared; each dataset
# entry carries `since`, `checked_version` (the latest release it was verified identical against),
# `content_hash` and `data_hash`. So a file name or URL is NEVER parsed or built here — each
# bundle's `url` is used exactly as given and the suggested download name is that URL's last path
# segment; unknown fields are ignored; any schema_version of major 1 or higher is read. The dialog
# says which release the zip was verified against (`checked_version`, else `version`) and, only
# when `since` differs, that the data are unchanged since then — true however many releases pass.
#
# Pure functions with no Jekyll dependency, so _test/downloads_test.rb pins them on fixtures (the
# 1.0 shape and the live 1.1 shape).
module CalCOFI
  module Downloads
    module_function

    ORDER = %w[csv xlsx parquet].freeze
    # the formats the dialog puts first (the plain ones); everything else is "Other formats"
    MAIN = %w[csv xlsx].freeze

    FORMATS = {
      "csv"     => { "label" => "CSV",
                     "about" => "" },
      "xlsx"    => { "label" => "Excel",
                     "about" => "" },
      "parquet" => { "label" => "Parquet",
                     "about" => "Typed columns for R, Python, DuckDB or Arrow; fastest for big tables." }
    }.freeze

    # what travels with the tables in every zip (the manifest's contract), in plain words
    INSIDE = "a readme, how to cite, the licence and a column dictionary"

    # {dataset_key => manifest entry}; {} for a manifest that is absent, unreadable or older than 1.x.
    # A HIGHER schema_version is read: the fields used here are additive-safe, the rest ignored.
    def index(manifest)
      return {} unless manifest.is_a?(Hash) && schema_ok?(manifest["schema_version"])
      (manifest["datasets"] || []).each_with_object({}) do |d, h|
        h[d["dataset_key"]] = d if d.is_a?(Hash) && d["dataset_key"]
      end
    end

    def schema_ok?(v) = v.to_s.match?(/\A\d+(\.|\z)/) && v.to_s.to_i >= 1

    # The formats the release's zips come in, as a reader says them, in ORDER: the labels of every format written for
    # at least one dataset ("CSV", "Excel", "Parquet"). The front door's Download card names them from here, so a
    # format the release stops writing stops being promised (PR 57 review: the card typed them). [] without a manifest.
    def format_labels(manifest)
      fs = index(manifest).values.flat_map { |d| (d["bundles"] || []).select { |b| b.is_a?(Hash) && b["written"] && present?(b["url"]) }.map { |b| b["format"] } }
      ORDER.select { |f| fs.include?(f) }.map { |f| FORMATS[f]["label"] }
    end

    # ["CSV", "Excel", "Parquet"] → "CSV, Excel or Parquet"; one is itself; none is nil
    def any_of(words)
      words = Array(words)
      return nil if words.empty?
      words.size == 1 ? words[0] : "#{words[0..-2].join(', ')} or #{words[-1]}"
    end

    # the name a browser saves the zip under: the URL's last path segment, as given (never built)
    def file_name(url)
      seg = url.to_s.sub(/[?#].*\z/, "").split("/").last
      present?(seg) ? seg : nil
    end

    # the record's own zips: distributions[] of kind `bundle` in one of the three formats (a DwC-A
    # or EDI bundle is a `bundle` too, and is not a download for a person). nil when it has none.
    def record_bundles(r)
      rows = (r["distributions"] || []).select do |x|
        x["kind"] == "bundle" && ORDER.include?(x["format"]) && x["status"] != "superseded"
      end
      return nil if rows.empty?
      rows.map do |x|
        { "format" => x["format"], "written" => x.key?("written") ? x["written"] : true,
          "url" => x["url"],
          "bytes" => x["bytes"], "sha256" => x["sha256"], "excel_openable" => x["excel_openable"],
          "rows" => x["rows"], "note" => x["note"], "reason" => x["reason"],
          "checked_version" => x["checked_version"], "since" => x["since"], "version" => x["version"] || x["since"] }
      end
    end

    # the bundles to offer for a record:
    # [bundles, "record"|"manifest", checked (verified against), since (content first appeared)]
    # The record's own come first, EXCEPT when the manifest was checked against a later release than
    # the record's rows were. A release is cut before its zips are built, so its record can only list
    # the zips of the release before; publish_to-zip then writes the manifest for the new one. With
    # the record always winning, v2026.11.26's pages kept offering the v2026.11.14 zips after the
    # v2026.11.26 ones were uploaded (2026-11-26).
    def bundles_for(r, entry)
      rb = record_bundles(r)
      rec = rb && [rb, "record", rb.map { |b| b["checked_version"] || b["version"] }.compact.first,
                   rb.map { |b| b["since"] }.compact.first]
      man = entry.is_a?(Hash) && entry["bundles"].is_a?(Array) &&
            [entry["bundles"].select { |b| b.is_a?(Hash) }, "manifest",
             entry["checked_version"] || entry["version"], entry["since"]]
      return [[], nil, nil, nil] unless rec || man
      return rec || man unless rec && man
      later?(man[2], rec[2]) ? man : rec
    end

    # is release `a` later than `b`? Versions are vYYYY.MM.DD[-suffix]; an unreadable one is never later.
    def later?(a, b)
      ka, kb = [a, b].map { |v| v.to_s[/\Av(\d{4})\.(\d{2})\.(\d{2})/] && [$1, $2, $3].map(&:to_i) }
      !ka.nil? && (kb.nil? || (ka <=> kb) == 1)
    end

    # the licence line, from the record's attribution — licence_chip.html's rule in a sentence
    def licence(a, contact = "data@calcofi.io")
      a ||= {}
      lic = a["license"].to_s.strip
      url = a["license_url"].to_s.strip
      url = nil if url.empty?
      ask = "To ask about reusing or redistributing these data, write to #{contact}."
      case lic
      when ""
        { "kind" => "unstated", "label" => "No licence established",
          "text" => "No licence has been established for this dataset yet: its provider has not stated the " \
                    "terms under which these data may be reused, and CalCOFI does not assign one on its " \
                    "behalf. #{ask}", "url" => nil, "contact" => contact }
      when "unknown"
        { "kind" => "pending", "label" => "Licence pending",
          "text" => "The licence is still an open question with the provider, so no reuse terms have been " \
                    "established yet. #{ask}", "url" => nil, "contact" => contact }
      when "custom"
        { "kind" => "custom", "label" => "Provider terms",
          "text" => "The provider’s own terms apply#{url ? '' : ' (the record carries no link to them)'}. " \
                    "Read them before you reuse the data.",
          "url" => url, "url_label" => "Read the provider’s terms" }
      when "CC-BY-4.0"
        { "kind" => "standard", "label" => "CC BY 4.0",
          "text" => "CC BY 4.0: free to reuse with credit.",
          "url" => url, "url_label" => "The licence" }
      when "CC0-1.0"
        { "kind" => "public-domain", "label" => "CC0 · public domain",
          "text" => "CC0, public domain: no conditions. Citing is appreciated.",
          "url" => url, "url_label" => "The dedication" }
      else
        name = a["license_name"].to_s.strip
        name = lic.tr("-", " ") if name.empty?
        { "kind" => "standard", "label" => name,
          "text" => "#{name} — the zip carries the licence text and says how to cite it.",
          "url" => url, "url_label" => "The licence" }
      end
    end

    # One dataset's offer, or nil when there is nothing to download. `part` is where a subset is
    # taken ({label, url}: the Explorer opened on this dataset, else the SQL shell); `bytes` formats
    # a size (Fmt.bytes, injected so the tests need no site).
    def offer(r, entry, part: nil, contact: "data@calcofi.io", holding: false, bytes: ->(b) { b.to_s })
      return nil if holding || r.nil?
      bundles, source, version, since = bundles_for(r, entry)
      by = {}
      bundles.each { |b| by[b["format"]] ||= b if ORDER.include?(b["format"]) }
      written = ORDER.select { |f| by[f] && by[f]["written"] && present?(by[f]["url"]) }
      return nil if written.empty?

      opts = ORDER.filter_map do |f|
        b = by[f] or next
        meta = FORMATS[f]
        if written.include?(f)
          n = (b["rows"] || {}).size
          n = (entry.is_a?(Hash) ? (entry["tables"] || []).size : 0) if n.zero?
          { "format" => f, "label" => meta["label"], "about" => meta["about"], "written" => true,
            "url" => b["url"], "file" => file_name(b["url"]), "bytes" => b["bytes"],
            "checked_version" => b["checked_version"], "since" => b["since"],
            "size" => b["bytes"] ? bytes.call(b["bytes"]) : nil, "sha256" => b["sha256"],
            "n_tables" => n.positive? ? n : nil,
            "tables" => (b["rows"] || {}).keys,
            "inside" => "#{n.positive? ? "#{n} data table#{'s' unless n == 1}" : 'the data tables'}, #{INSIDE}",
            "note" => present?(b["note"]) ? b["note"] : nil }
        else
          { "format" => f, "label" => meta["label"], "about" => meta["about"], "written" => false,
            "reason" => present?(b["reason"]) ? b["reason"] : "Not offered for this dataset." }
        end
      end
      primary = opts.find { |o| o["written"] && o["format"] == "csv" } || opts.find { |o| o["written"] }
      opts.each { |o| o["primary"] = o.equal?(primary) }
      # the release the default zip was verified against, else the dataset entry's; and the release
      # its content first appeared in, said only when it is an earlier one
      version = primary["checked_version"] || version
      since   = primary["since"] || since
      since   = nil if since.to_s.empty? || since == version
      key = r["dataset_key"]
      {
        "key"     => key,
        "name"    => r["dataset_name_short"] || r["dataset_name"] || key,
        "version" => version,
        "since"   => since,
        "source"  => source,
        "primary" => primary,
        # the button names the thing: the default format and its size
        "what"    => [primary["label"], primary["size"]].compact.join(" · "),
        "aria"    => "Download #{primary['label']}#{primary['size'] ? ", #{primary['size']} zip" : ''}, or choose another format",
        "main"    => opts.select { |o| MAIN.include?(o["format"]) },
        "other"   => opts.reject { |o| MAIN.include?(o["format"]) || !o["written"] },
        "formats" => written,
        "inside"  => INSIDE,
        "licence" => licence(r["attribution"], contact),
        "part"    => part
      }
    end

    def present?(v) = !(v.nil? || (v.respond_to?(:empty?) && v.empty?))
  end
end
