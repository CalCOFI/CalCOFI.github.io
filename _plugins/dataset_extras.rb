# frozen_string_literal: true

# Words for people browsing the datasets that the release record does not carry yet
# (_data/dataset_extras.yml; Betty 2026-11-18): a plain name, how the data were collected and
# analysed, a collection-method picture, ongoing/ended, and the category tiles of /datasets/.
#
# Pure rules, no Jekyll dependency, so _test/dataset_extras_test.rb pins them. browse.rb merges them
# into the rows and builds the tiles; dataset_page.rb adds them to page.dp. Anything the file does
# not give is nil and is not drawn: nothing here is guessed.
module CalCOFI
  module DatasetExtras
    module_function

    METHODS = {
      "net" => "Net tow", "pump" => "Ship’s pump", "ctd" => "CTD sensors", "bottle" => "Water samples",
      "ship" => "Underway sensors", "eye" => "Visual survey", "calc" => "Derived"
    }.freeze
    STATUS = { "ongoing" => "Ongoing", "archived" => "Ended" }.freeze

    def present(s)
      s = s.to_s.strip
      s.empty? ? nil : s
    end

    # "Visual microscopy (NOAA SWFSC)" → ["Visual microscopy", "NOAA SWFSC"]; "(SIO)" → [nil, "SIO"];
    # "Flow cytometry" → ["Flow cytometry", nil]. The lab is the LAST bracket, so a method may hold its own.
    def analysis(s)
      s = present(s) or return [nil, nil]
      m = s.match(/\A(.*?)\s*\(([^()]*)\)\s*\z/)
      return [s, nil] unless m
      [present(m[1]), present(m[2])]
    end

    # one dataset's extras, every key present (nil when not given)
    def for(extras, key)
      e = (extras.is_a?(Hash) ? extras.dig("datasets", key) : nil) || {}
      meth, lab = analysis(e["analysis"])
      mk = present(e["method"])
      st = present(e["status"])&.downcase
      {
        "plain" => present(e["plain"]), "collection" => present(e["collection"]),
        "analysis_method" => meth, "analysis_lab" => lab,
        # the people who did the analysis, written in `who:`; shown after the lab and not in bold (Betty 2026-11-20)
        "analysis_who" => present(e["who"]),
        # where "Original data" goes when the release record names no source, or the wrong one (Betty 2026-11-20)
        "source_url" => present(e["source_url"]), "source_label" => present(e["source_label"]),
        "method" => METHODS.key?(mk) ? mk : nil, "method_label" => METHODS[mk],
        "status" => STATUS.key?(st) ? st : nil, "status_label" => STATUS[st],
        "blurb" => present(e["blurb"]),
        # the citation the data's provider wants used; it wins over the release record's citation_main (Betty 2026-11-20)
        "citation_override" => present(e["citation_override"]),
        # the acknowledgement a provider asks for, which replaces the record's funding/acknowledgement line, and the signed
        # data-sharing agreement it comes from (a file under assets/agreements/) (Betty 2026-11-20)
        "ack_override" => present(e["ack_override"]),
        "licence_note" => present(e["licence_note"]),
        # a biology dataset's Measurements table: what each value of `measurement_type` means, [{name:, desc:, units:}] (Betty 2026-11-21);
        # an environmental dataset's comes from measurements.json
        "measurements" => (e["measurements"].is_a?(Array) ? e["measurements"].select { |x| x.is_a?(Hash) } : []),
        # papers that describe the method, linked at the end of "More about the record": [{label:, url:}] (Betty 2026-11-20)
        "refs" => (e["refs"].is_a?(Array) ? e["refs"].filter_map { |x| x.is_a?(Hash) && present(x["url"]) ? { "label" => present(x["label"]) || x["url"], "url" => x["url"] } : nil } : []),
        # true: "Original data" links each source table itself and the "Combined from N source tables" section is left out (Betty 2026-11-20)
        "sources_inline" => e["sources_inline"] == true,
        # the organisation said beside the creators, where the release record's is wrong or too wide (Betty 2026-11-20)
        "creator_org" => present(e["creator_org"]),
        "agreement_url" => present(e["agreement_url"]), "agreement_label" => present(e["agreement_label"]),
        # the dataset page's sentence under the title and what "More about the record" opens (Betty 2026-11-20)
        # the map's caption, in place of the station count, for a dataset with no stations (Betty 2026-11-21)
        "map_note" => present(e["map_note"]),
        "lede" => present(e["lede"]), "more" => present(e["more"]), "listed" => !e.empty?,
        # the Field descriptions table, made fit for this dataset (Betty 2026-11-20): columns that mean nothing for it are left
        # out (`field_hide`), and the release record's all-datasets wording is replaced where it is about other datasets (`field_notes`)
        "field_hide" => (e["field_hide"].is_a?(Array) ? e["field_hide"].map(&:to_s) : []),
        "field_notes" => (e["field_notes"].is_a?(Hash) ? e["field_notes"].transform_values { |v| present(v) }.compact : {})
      }
    end

    # A short description for a dataset's row (Betty 2026-11-18: "desc are unnecessarily long"): the record's
    # first sentence, and the second too when the first is short; without the notes meant for the data team
    # ("(see questions calcofidic01 and calcofidic07)") or a status the row already shows ("(completed)").
    # `blurb:` in _data/dataset_extras.yml replaces it.
    NOTE = /\s*\((?:see\b[^)]*|[^)]*\bquestions?\b[^)]*|completed|ongoing|archived)\)/i
    def short_desc(text)
      s = present(text.to_s.gsub(NOTE, "").gsub(/\s+/, " ").strip) or return nil
      # a sentence ends at . ! or ? before a capital or a number, but not after an initial ("(J. Smith") or a short
      # form ("Nov. 2002", "ca. 5", "e.g. CTD")
      parts = s.split(/(?<=[.!?])\s+(?=[A-Z0-9])/).each_with_object([]) do |p, a|
        if a.any? && a.last.match?(/(?:\b[A-Z]|\b(?:Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sept?|Oct|Nov|Dec|ca|approx|vs|e\.g|i\.e|No|St|Dr|et al))\.\z/)
          a[-1] = "#{a.last} #{p}"
        else
          a << p
        end
      end
      out = parts.shift.to_s
      out += " " + parts.shift if out.length < 90 && parts.any?
      out
    end

    def slug(s) = s.to_s.downcase.gsub(/&/, " and ").gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")

    # The tiles: realms in the file's order, each group holding the rows its `datasets` or
    # `categories` name, in the rows' own (browse) order. A row no group claims falls into a tile of
    # its own record category at the end of its realm, so a new dataset is never lost. A group with
    # no rows is dropped. rows: site.data["browse"]["rows"].
    def tiles(extras, rows)
      rows = rows.to_a
      spec = (extras.is_a?(Hash) ? extras["tiles"] : nil).to_a
      claimed = {}
      realms = spec.map do |rs|
        groups = rs["groups"].to_a.map do |g|
          keys = g["datasets"].to_a
          cats = g["categories"].to_a
          mine = rows.select { |r| !claimed[r["key"]] && (keys.include?(r["key"]) || cats.include?(r["cat"])) }
          mine.each { |r| claimed[r["key"]] = true }
          group(g["name"], g["icon"] || mine.first&.dig("icon"), g["line"], rs["realm"], mine, g["about"])
        end
        { "id" => rs["realm"], "title" => rs["title"], "sub" => rs["sub"], "groups" => groups }
      end
      # anything unclaimed: its own category's tile, in its realm (a new realm goes last)
      rows.reject { |r| claimed[r["key"]] }.group_by { |r| [r["realm"], r["cat"]] }.each do |(realm, cat), rs|
        rl = realms.find { |x| x["id"] == realm } || (realms << { "id" => realm, "title" => realm.to_s.capitalize, "sub" => nil, "groups" => [] }).last
        rl["groups"] << group(cat, rs.first["icon"], rs.first["cat_desc"], realm, rs)
      end
      realms.each { |rl| rl["groups"].reject! { |g| g["n"].zero? } }
      realms.reject { |rl| rl["groups"].empty? }.each do |rl|
        rl["n"] = rl["groups"].sum { |g| g["n"] }
      end
    end

    def group(name, icon, line, realm, rows, about = nil)
      # ongoing datasets first, each half keeping the browse order it had (Betty 2026-11-20)
      rows = rows.each_with_index.sort_by { |r, i| [r["status"] == "ongoing" ? 0 : 1, i] }.map(&:first)
      y0 = rows.map { |r| r["y0"] }.compact.min
      y1 = rows.map { |r| r["y1"] }.compact.max
      years = y0 ? (y0 == y1 ? y0.to_s : "#{y0}–#{y1}") : rows.map { |r| present(r["years"]) }.compact.first
      progs = rows.map { |r| r["prov"] }.compact.uniq
      { "name" => name, "slug" => slug(name), "icon" => icon, "line" => present(line), "about" => present(about), "realm" => realm,
        "rows" => rows, "keys" => rows.map { |r| r["key"] }, "n" => rows.size, "years" => years, "programs" => progs.join(", ") }
    end

    # the tile a dataset sits in (for a page's back link): [name, slug]
    def tile_of(tiles, key)
      tiles.to_a.each { |rl| rl["groups"].each { |g| return [g["name"], g["slug"]] if g["keys"].include?(key) } }
      nil
    end

    # The tables a person may know this dataset as elsewhere: the record's current NOAA ERDDAP
    # mirrors (portal erddap-noaa). A dataset is "combined" only with two or more.
    # A table the record lists without an id or a title (the plain "source" link, as Seabirds & Marine Mammals' observations
    # table) gets its id from the end of its address and, for an _obs table, the title "Observations" (Betty 2026-11-20).
    def source_tables(record)
      (record["distributions"] || []).select { |x| x["portal"] == "erddap-noaa" && present(x["url"]) }.filter_map do |x|
        id = present(x["id"]) || File.basename(x["url"].to_s, ".*")
        t = present(x["title"])
        t = nil if t == "source"
        title = present(t.to_s.sub(/\ACalCOFI (NOAA |SIO )?/, "")) || (id.end_with?("_obs") ? "Observations" : id)
        { "id" => id, "title" => title, "url" => x["url"] }
      end
    end

    # The columns of the download, from the release's own metadata.json (_data/release_metadata.json,
    # scripts/fetch_release.sh): `columns` keyed "table.column" → { description, units, … }. Only the
    # dataset's own tables. One row per column NAME (Betty 2026-11-18: the same cruise_key, latitude … sat in
    # three files and read as repeats), with every file it is in. The database's own plumbing is left out
    # (the event keys that tie the files together, provenance stamps, columns starting "_"); every column is
    # still in columns.csv in the zip. The columns a reader needs first are MAIN, in MAIN's order (when,
    # where, what, how much); the rest are folded. Without the file: [] and the section is not drawn.
    # the rows Field descriptions shows before "Show N more fields": seven for a biology dataset, ending at measurement_type (Betty 2026-11-21:
    # depth, life stage, units, tow type, taxon_key and measurement_value fold with the rest)
    MAIN = %w[datetime latitude longitude cruise_key site_key scientific_name measurement_type].freeze
    SKIP = /\A_|(_uuid|_id|hex\d*|hex_id|geom|_source_row|_source_file)\z|\A(sample_key|parent_sample_key|root_sample_key|
            dataset_key|grid_key|realm|data_stage|order_occ)\z/x

    # (`bio: false`, a dataset with no species, also folds the species columns its files carry empty)
    BIO = %w[scientific_name taxon_key life_stage tow_type].freeze
    # The page's Units column also says how a value is written, where the release gives no units (the CSV keeps only the units) (Betty 2026-11-21: UTC, YYYY-MM-NODC, line station),
    # and the words of a column the release describes too thinly (scientific_name: where its identifiers are).
    FORMATS = { "datetime" => "UTC", "cruise_key" => "YYYY-MM-NODC", "site_key" => "line station" }.freeze
    NOTES = { "scientific_name" => "Accepted scientific name. Its WoRMS and ITIS identifiers are worms_id and itis_id." }.freeze
    def fields(meta, record, bio: true)
      cols = meta.is_a?(Hash) ? meta["columns"] : nil
      return [] unless cols.is_a?(Hash)
      tables = (record["tables"] || []).map(&:to_s)
      by = {}
      tables.each do |t|
        cols.each do |k, v|
          tb, col = k.to_s.split(".", 2)
          next unless tb == t && col && !col.match?(SKIP)
          v = {} unless v.is_a?(Hash)
          d = present(v["description"]) || present(v["description_md"])
          next unless d
          if (row = by[col])
            row["files"] << "#{t}.csv" unless row["files"].include?("#{t}.csv")
            row["units"] ||= present(v["units"])
          else
            by[col] = { "field" => col, "files" => ["#{t}.csv"], "units" => present(v["units"]),
                        "desc" => d.gsub(/`([^`]+)`/, '\1'), "main" => MAIN.include?(col) && (bio || !BIO.include?(col)) }
          end
        end
      end
      rows = by.values
      rows.each do |r|
        r["file"] = r["files"].join(", ")
        r["fmt"] = FORMATS[r["field"]]
        r["desc"] = NOTES[r["field"]] if NOTES.key?(r["field"])
      end
      main = rows.select { |r| r["main"] }.sort_by { |r| MAIN.index(r["field"]) }
      main + rows.reject { |r| r["main"] }
    end
  end
end
