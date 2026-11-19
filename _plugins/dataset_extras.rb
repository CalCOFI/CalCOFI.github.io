# frozen_string_literal: true

# Words for people browsing the datasets that the release record does not carry yet
# (_data/dataset_extras.yml; Betty 2026-11-18): a plain name, how the data were collected and
# analysed, a collection-method picture, ongoing/archived, and the category tiles of /datasets/.
#
# Pure rules, no Jekyll dependency, so _test/dataset_extras_test.rb pins them. browse.rb merges them
# into the rows and builds the tiles; dataset_page.rb adds them to page.dp. Anything the file does
# not give is nil and is not drawn: nothing here is guessed.
module CalCOFI
  module DatasetExtras
    module_function

    METHODS = {
      "net" => "Net tow", "pump" => "Ship’s pump", "ctd" => "CTD sensors", "bottle" => "Water samples",
      "ship" => "Underway sensors", "eye" => "Visual survey", "calc" => "Calculated"
    }.freeze
    STATUS = { "ongoing" => "Ongoing", "archived" => "Archived" }.freeze

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
        "method" => METHODS.key?(mk) ? mk : nil, "method_label" => METHODS[mk],
        "status" => STATUS.key?(st) ? st : nil, "status_label" => STATUS[st],
        "blurb" => present(e["blurb"])
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
          group(g["name"], g["icon"] || mine.first&.dig("icon"), g["line"], rs["realm"], mine)
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

    def group(name, icon, line, realm, rows)
      y0 = rows.map { |r| r["y0"] }.compact.min
      y1 = rows.map { |r| r["y1"] }.compact.max
      years = y0 ? (y0 == y1 ? y0.to_s : "#{y0}–#{y1}") : rows.map { |r| present(r["years"]) }.compact.first
      progs = rows.map { |r| r["prov"] }.compact.uniq
      { "name" => name, "slug" => slug(name), "icon" => icon, "line" => present(line), "realm" => realm,
        "rows" => rows, "keys" => rows.map { |r| r["key"] }, "n" => rows.size, "years" => years, "programs" => progs.join(", ") }
    end

    # the tile a dataset sits in (for a page's back link): [name, slug]
    def tile_of(tiles, key)
      tiles.to_a.each { |rl| rl["groups"].each { |g| return [g["name"], g["slug"]] if g["keys"].include?(key) } }
      nil
    end

    # The tables a person may know this dataset as elsewhere: the record's current NOAA ERDDAP
    # mirrors (portal erddap-noaa). A dataset is "combined" only with two or more.
    def source_tables(record)
      (record["distributions"] || []).select { |x| x["portal"] == "erddap-noaa" && present(x["id"]) && present(x["url"]) }
                                     .map { |x| { "id" => x["id"], "title" => present(x["title"].to_s.sub(/\ACalCOFI (NOAA |SIO )?/, "")) || x["id"], "url" => x["url"] } }
    end

    # The columns of the download, from the release's own metadata.json (_data/release_metadata.json,
    # scripts/fetch_release.sh): `columns` keyed "table.column" → { description, units, … }. Only the
    # dataset's own tables. One row per column NAME (Betty 2026-11-18: the same cruise_key, latitude … sat in
    # three files and read as repeats), with every file it is in. The database's own plumbing is left out
    # (the event keys that tie the files together, provenance stamps, columns starting "_"); every column is
    # still in columns.csv in the zip. The columns a reader needs first are MAIN, in MAIN's order (when,
    # where, what, how much); the rest are folded. Without the file: [] and the section is not drawn.
    MAIN = %w[datetime latitude longitude cruise_key site_key depth_min_m depth_max_m scientific_name taxon_key life_stage
              measurement_type measurement_value units tow_type].freeze
    SKIP = /\A_|(_uuid|_id|hex\d*|hex_id|geom|_source_row|_source_file)\z|\A(sample_key|parent_sample_key|root_sample_key|
            dataset_key|grid_key|realm|data_stage|order_occ)\z/x

    # (`bio: false`, a dataset with no species, also folds the species columns its files carry empty)
    BIO = %w[scientific_name taxon_key life_stage tow_type].freeze
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
      rows.each { |r| r["file"] = r["files"].join(", ") }
      main = rows.select { |r| r["main"] }.sort_by { |r| MAIN.index(r["field"]) }
      main + rows.reject { |r| r["main"] }
    end
  end
end
