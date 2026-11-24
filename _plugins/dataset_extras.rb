# frozen_string_literal: true

# Words for people browsing the datasets, read from the release record (datasets.json schema 1.2: each
# dataset's `display` block, `browse`, and `attribution.associated_parties`): a plain name, how the data
# were collected and analysed, a collection-method picture, ongoing/ended, and the tiles of /datasets/.
# They are authored in workflows (ingest notebooks, sidecars, registries), never here: there is no
# _data/dataset_extras.yml, and _test/dataset_extras_test.rb fails the build if one comes back.
#
# Pure rules, no Jekyll dependency. browse.rb merges them into the rows and builds the tiles;
# dataset_page.rb adds them to page.dp. Anything the record does not give is nil and is not drawn.
module CalCOFI
  module DatasetExtras
    module_function

    def present(s)
      s = s.to_s.strip
      s.empty? ? nil : s
    end

    # The record's own display words, as this module's "extras": { "datasets" => { key => record }, "browse" => … }.
    # Built once from datasets.json (schema 1.2). An older record has no `display` and no `browse`: every word
    # is then nil and the tiles fall back to the record's categories.
    def from_record(rec)
      rec = {} unless rec.is_a?(Hash)
      ds = {}
      (rec["datasets"] || []).each { |r| ds[r["dataset_key"]] = r if r.is_a?(Hash) }
      { "datasets" => ds, "browse" => (rec["browse"].is_a?(Hash) ? rec["browse"] : nil) }
    end

    # The person at the provider who holds the data: the record's associated party whose role says so.
    def data_provider(record)
      ps = record.dig("attribution", "associated_parties")
      p = (ps.is_a?(Array) ? ps : []).find { |x| x.is_a?(Hash) && x["role"].to_s.match?(/data provider/i) && present(x["name"]) }
      p && { "name" => p["name"], "organization" => present(p["organization"]), "email" => present(p["email"]) }
    end

    # one dataset's display words, every key present (nil when the record does not give it)
    def for(extras, key)
      r = (extras.is_a?(Hash) ? extras.dig("datasets", key) : nil) || {}
      e = r["display"].is_a?(Hash) ? r["display"] : {}
      m = e["collection_method"].is_a?(Hash) ? e["collection_method"] : {}
      st = present(e["collection_status"])&.downcase
      refs = e["references"].is_a?(Array) ? e["references"] : []
      notes = e["column_notes"].is_a?(Hash) ? e["column_notes"] : {}
      {
        "plain" => present(e["name_plain"]), "collection" => present(e["collection"]),
        "analysis_method" => present(e["analysis"]), "analysis_lab" => present(e["analysis_org"]),
        "method" => present(m["key"]), "method_label" => present(m["label"]),
        "status" => st, "status_label" => st&.capitalize,
        "blurb" => present(e["description_short"]),
        "browse_group" => present(e["browse_group"]),
        # papers that describe the method, linked at the end of "More about the record": [{label:, url:}]
        "refs" => refs.filter_map { |x| x.is_a?(Hash) && present(x["url"]) ? { "label" => present(x["label"]) || x["url"], "url" => x["url"] } : nil },
        # the map's caption, in place of the station count, for a dataset with no stations
        "map_note" => present(e["spatial_note"]),
        # the sentence under the title and what "More about the record" opens. `listed`: the record gives reader's
        # words, so the rest of its description (which holds notes for the data team) stays off the page
        "lede" => present(e["description_lede"]), "more" => present(e["notes_md"]),
        "listed" => !!(present(e["notes_md"]) || present(e["description_lede"]) || present(e["name_plain"])),
        # a column's words where the all-datasets wording is about other datasets
        "field_notes" => notes.transform_values { |v| present(v) }.compact
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

    # The tiles: the record's `browse` realms and groups in their order, each group holding the rows whose
    # `display.browse_group` names it, in the rows' own (browse) order. A row no group claims falls into a tile of
    # its own record category at the end of its realm, so a new dataset is never lost. A group with
    # no rows is dropped. rows: site.data["browse"]["rows"].
    def tiles(extras, rows)
      rows = rows.to_a
      br = (extras.is_a?(Hash) ? extras["browse"] : nil) || {}
      groups_all = br["groups"].to_a
      claimed = {}
      realms = br["realms"].to_a.map do |rs|
        groups = groups_all.select { |g| g["realm"] == rs["realm"] }.map do |g|
          mine = rows.select { |r| !claimed[r["key"]] && r["browse_group"] == g["key"] }
          mine.each { |r| claimed[r["key"]] = true }
          group(g["name"], present(g["icon"]) || mine.first&.dig("icon"), g["line"], rs["realm"], mine, g["description"])
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

    # The tables a person may know this dataset as elsewhere: the record's NOAA ERDDAP distributions
    # (portal erddap-noaa), each with its `kind`. `source` tables are what the release was built from;
    # `mirror` tables are other places the same data are served (see combined?).
    # A table the record lists without an id or a title (the plain "source" link, as Seabirds & Marine Mammals' observations
    # table) gets its id from the end of its address and, for an _obs table, the title "Observations" (Betty 2026-11-20).
    def source_tables(record)
      (record["distributions"] || []).select { |x| x["portal"] == "erddap-noaa" && present(x["url"]) }.filter_map do |x|
        id = present(x["id"]) || File.basename(x["url"].to_s, ".*")
        t = present(x["title"])
        t = nil if t == "source"
        title = present(t.to_s.sub(/\ACalCOFI (NOAA |SIO )?/, "")) || (id.end_with?("_obs") ? "Observations" : id)
        { "id" => id, "title" => title, "url" => x["url"], "kind" => x["kind"] }
      end
    end

    # true when the release was built from two or more of these tables (kind source), never for mirrors
    def combined?(sources) = sources.to_a.count { |x| x["kind"] == "source" } > 1 && sources.to_a.all? { |x| x["kind"] == "source" }

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
