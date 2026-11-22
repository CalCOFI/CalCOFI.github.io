# frozen_string_literal: true

require "cgi"
require "date"
require "digest"
require "json"

# The dataset page, redesigned (Betty, 2026-11-15; _mockups dataset-page-mockup-8, version 2). Adds
# `page.dp` to every /datasets/{key}/ page that is a dataset (a holding keeps the old page):
#
#   band     the name, the full name and provider on one line, the numbers on the right
#   left     About (the record's first sentence, the rest one click away), when it was sampled
#            (records per year and by month), what is in it (species and/or measurements, each with a
#            CSV button for just that one, from this dataset)
#   right    the map with View on map (Explorer) and See stations (Dataset Finder), Get the data, Cite
#   bottom   About the data: creators (none marked as lead), contact, credit, also archived at
#
# Everything is read from the release record. Taxa, silhouettes and measurement series are read from
# disk (_data/*.json), as finder.rb does: species.rb and measurements.rb replace their site.data keys.
# A page exists only for a dataset the catalog shows (Catalog#visible), so nothing here is drawn for
# a `visibility: internal` record.
require_relative "datasets"
require_relative "dataset_extras"

module CalCOFI
  # Pure rules of the redesigned dataset page, with no Jekyll dependency, so _test/dataset_page_test.rb
  # pins them on fixtures.
  module DatasetPage
    module_function

    # What the download form (assets/download-form.js) knows about one dataset: its name, its page,
    # and — only where the dataset has zips (_plugins/downloads.rb `offer`) — the default zip: the
    # URL exactly as the offer gives it, the name to save it under and the button's words
    # ("CSV · 32.4 MB"). No offer, no "zip" key: the form then sends the reader to the page.
    def form_file(r, offer, page_url)
      out = { "name" => r["dataset_name_short"] || r["dataset_name"] || r["dataset_key"], "page" => page_url }
      pr = offer.is_a?(Hash) ? offer["primary"] : nil
      out["zip"] = { "url" => pr["url"], "file" => pr["file"], "what" => offer["what"] } if pr && pr["url"]
      out
    end

    # Can the Query Builder serve this measurement from this dataset (calcofi.io/query/?pick=env:<dataset>:<key>)?
    # The builder reads the release's observation tables. A series the record marks `grain: "sample"` is one value
    # per cast (the sample_measurement table: mixed-layer depth, chlorophyll maximum …), which the builder does not
    # read, so its row gets no CSV button rather than a button that opens the builder on "not in this release".
    # The series' own grain wins; the measurement's is the fallback.
    def pickable?(measurement, series)
      grain = (series.is_a?(Hash) ? series["grain"] : nil) || (measurement.is_a?(Hash) ? measurement["grain"] : nil)
      grain.to_s != "sample"
    end

    SHOWN = 50 # taxa rows drawn in the page; the rest travel as JSON
    MON = %w[J F M A M J J A S O N D].freeze

    def num(n) = n.nil? ? nil : n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse

    # 9,999 as it is, then 42k, then 1.3M
    def big(n)
      n = n.to_i
      return num(n) if n < 10_000
      n >= 1_000_000 ? format("%.1fM", n / 1e6) : "#{(n / 1000.0).round}k"
    end

    def yrs(a, b) = a.nil? ? nil : (a == b ? a.to_s : "#{a}–#{b}")
    def h(s) = CGI.escapeHTML(s.to_s)

    # About: [the record's first sentence, the rest of its description]. `first` is
    # Catalog#first_sentence's cut, whose " …" (a description with no sentence end in reach) is
    # dropped; the rest is whatever follows it in the plain text, or the whole text when the cut is
    # not its beginning. An empty part is nil.
    def lede_rest(text, first)
      text = text.to_s
      lede = first.to_s.sub(/ …\z/, "")
      rest = text.start_with?(lede) ? text[lede.length..].to_s.strip : text
      [lede.empty? ? nil : lede, rest.empty? ? nil : rest]
    end

    # under the name: the full name where it differs from the short one, then who it is from
    # `from: false` leaves "From <provider>, <PIs>" out: the Analysis line under the title already says who did the work
    def byline(r, from = true)
      full = Fmt.present(r["dataset_name"])
      short = Fmt.present(r["dataset_name_short"])
      prov = r.dig("provider", "short") || r.dig("provider", "name")
      pis = r.dig("attribution", "pi_names") || []
      [full && full != short ? full : nil, prov && from ? "From #{prov}#{pis.empty? ? '' : ", #{pis.join(', ')}"}" : nil].compact.join(" · ")
    end

    # The band's numbers, as [value, label] pairs; a number the record does not carry is not drawn.
    #   Years        the measured span (`years_span`, Catalog#span_years; else the coverage's own)
    #   Dates        where the years cannot be measured, the record's asserted `temporal`
    #                ("1996 to 2022"), as main's page says it — never nothing
    #   Records · Sampling events · Stations
    #   Taxa         for a dataset with taxa (singular for one), else Measurements, else neither
    #   Depth        the page's own depth phrase, "surface" capitalized
    def facts(r, years_span: nil, depth: nil, n_taxa: 0, n_meas: 0)
      cov = r["coverage"] || {}
      out = []
      if cov["year_min"] then out << [years_span || yrs(cov["year_min"], cov["year_max"]), "Years"]
      elsif Fmt.present(years_span) then out << [years_span, "Years"]
      elsif Fmt.present(cov["temporal"]) then out << [cov["temporal"], "Dates"]
      end
      out << [num(cov["n_obs"]), "Records"] if cov["n_obs"].to_i.positive?
      out << [num(cov["n_roots"]), "Sampling events"] if cov["n_roots"].to_i.positive?
      out << [num(cov["n_stations"]), "Stations"] if cov["n_stations"].to_i.positive?
      if n_taxa.to_i.positive? then out << [num(n_taxa), n_taxa == 1 ? "Taxon" : "Taxa"]
      elsif n_meas.to_i.positive? then out << [num(n_meas), n_meas == 1 ? "Measurement" : "Measurements"]
      end
      out << [depth.to_s.sub(/\Asurface\z/, "Surface"), "Depth"] if depth
      out
    end

    # Creators, as one sentence part: the record's creators[] (else its pi_names), no role marked (the
    # first is the lead, which the Credit box leaves implied); one organisation is said once at the end, several beside each name; two names
    # joined by "and", three or more by commas and a final "and". nil when the record names nobody.
    def creators(a, org = nil)
      a ||= {}
      cs = (a["creators"] || []).map { |c| [c["name"], org || Fmt.present(c["organization"])] }
      cs = (a["pi_names"] || []).map { |n| [n, nil] } if cs.empty?
      return nil if cs.empty?
      orgs = cs.map(&:last).compact.uniq
      names = cs.map { |n, o| "#{n}#{orgs.size > 1 && o ? " (#{o})" : ''}" }
      list = names.size > 2 ? "#{names[0..-2].join(', ')} and #{names[-1]}" : names.join(" and ")
      orgs.size == 1 ? "#{list}, #{orgs[0]}" : list
    end

    # Records per year on the RELEASE's own axis (`span`: Catalog#strip_span, [first, last year]), so
    # two pages' charts can be read side by side; with no release span, the dataset's own years. The
    # axis starts where the span starts — no year is typed here (it was forced back to 1949). A year
    # with records is at least 5% tall so it can be seen; a year without draws a 2% stub.
    def years_svg(cov, span)
      ys = (cov || {})["years"] || []
      return nil if ys.empty?
      y0, y1 = span || [ys.map { |y| y["year"].to_i }.min, ys.map { |y| y["year"].to_i }.max]
      by = ys.to_h { |y| [y["year"].to_i, y["n_obs"].to_i] }
      max = [by.values.max.to_i, 1].max
      w = y1 - y0 + 1
      bars = (y0..y1).map do |y|
        v = by[y].to_i
        ht = v.positive? ? [v * 100.0 / max, 5].max : 2
        %(<rect#{v.positive? ? '' : ' class="z"'} x="#{(y - y0) * 10 + 1}" y="#{(100 - ht).round(1)}" width="8" height="#{ht.round(1)}"><title>#{y}: #{num(v)} records</title></rect>)
      end
      ticks = [1960, 1980, 2000].select { |t| t > y0 && t < y1 }
                                .map { |t| %(<span style="left:#{((t - y0) * 100.0 / w).round(1)}%">#{t}</span>) }
      %(<svg class="dp-bars" viewBox="0 0 #{w * 10} 100" preserveAspectRatio="none" aria-hidden="true">#{bars.join}</svg>) +
        %(<div class="dp-ax"><span style="left:0">#{y0}</span>#{ticks.join}<span style="right:0">#{y1}</span></div>)
    end

    # Records by month: {label, html}. The label is "all 12" or "9 of 12"; a month with records is at
    # least 5% tall, a month without is 0. nil unless the record carries twelve months.
    def months_html(cov)
      ms = (cov || {})["months"]
      return nil unless ms.is_a?(Array) && ms.size == 12
      max = [ms.max.to_i, 1].max
      n = ms.count(&:positive?)
      { "label" => n == 12 ? "all 12" : "#{n} of 12",
        "html" => %(<div class="dp-mo">#{ms.each_with_index.map { |v, i| %(<i style="height:#{v.positive? ? [v * 100.0 / max, 5].max.round(1) : 0}%" title="#{MON[i]}: #{num(v)} records"></i>) }.join}</div>) +
                  %(<div class="dp-mol">#{MON.map { |m| "<span>#{m}</span>" }.join}</div>) }
    end

    MONTHS = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec].freeze

    # Records by month as twelve tiles (Betty 2026-11-18): {tiles: [{m, n, pct}], note}. pct is the
    # month's share of the busiest month (0–100), which the page turns into a shade. The note names the
    # busiest and the quietest month with records. nil unless the record carries twelve months.
    def month_tiles(cov)
      ms = (cov || {})["months"]
      return nil unless ms.is_a?(Array) && ms.size == 12
      ms = ms.map(&:to_i)
      max = [ms.max, 1].max
      lo = ms.each_with_index.select { |v, _| v.positive? }.min_by(&:first)
      hi = ms.each_with_index.max_by(&:first)
      note = hi && hi[0].positive? ? "Most in #{Date::MONTHNAMES[hi[1] + 1]}" : nil
      note = "#{note}, fewest in #{Date::MONTHNAMES[lo[1] + 1]}" if note && lo && lo[1] != hi[1]
      { "tiles" => ms.each_with_index.map { |v, i| { "m" => MONTHS[i], "n" => num(v), "pct" => (v * 100.0 / max).round } }, "note" => note }
    end

    # taxa.json → {dataset_key => [[taxon, n_obs in that dataset], …]}: every taxon a dataset observed
    # (the record's coverage lists only the top 50), none with a count of zero
    def observed_by_dataset(taxa)
      out = Hash.new { |hh, k| hh[k] = [] }
      (taxa || []).each do |t|
        (t["datasets"] || []).each { |d| out[d["dataset_key"]] << [t, d["n_obs"].to_i] if d["n_obs"].to_i.positive? }
      end
      out
    end

    # measurements.json → {dataset_key => [[measurement, its series in that dataset], …]}
    def series_by_dataset(measurements)
      out = Hash.new { |hh, k| hh[k] = [] }
      (measurements || []).each do |m|
        (m["series"] || []).each { |s| out[s["dataset_key"]] << [m, s] }
      end
      out
    end

    # A taxon's two names for a row: [the name, the common name or nil]. The name is NEVER empty: it
    # is the species page's own rule (`namer`: Taxa#name_of — the scientific name, else the name or
    # the code its dataset gives it, else the key without its prefix), and for a row that is not in
    # taxa.json the coverage's scientific name, else its common name, else the key. The common name
    # is the record's, else the one the dataset gives a dataset-local class ("eggs" for
    # cce-lter_zooscan:13); it is dropped when it only repeats the name.
    def taxon_names(key, sci, com, taxon, namer)
      name = (taxon && namer ? Fmt.present(namer.call(taxon)) : nil) ||
             Fmt.present(sci.to_s.strip) || Fmt.present(com.to_s.strip) || key.to_s.sub(/\A[^:]+:/, "")
      common = Fmt.present(com.to_s.strip) || (taxon && Fmt.present(taxon.dig("local", "common_name").to_s.strip))
      common = nil if common && common.casecmp?(name)
      [name, common]
    end

    # The taxa of one dataset, most recorded first (ties by name), as {rows:, sprite:}.
    #   observed  [[taxon, n], …] from observed_by_dataset; when empty (no taxa.json) the coverage's
    #             own list (its top 50)
    #   taxa      {taxon_key => taxon}, for the page link, the lineage and the name
    #   media     taxa_media.json's `taxa`: each row wears its own silhouette, else its nearest
    #             ancestor's, drawn ONCE per page as a <symbol> in the sprite. Only the first `shown`
    #             rows add a symbol; a later row wears one only if it is already drawn (992 rows of
    #             outlines would be megabytes).
    # Each row: k, sci, com, rank (nil for a Species), n ("1,234"), n_raw, url, sil, pct (of the
    # largest row, one decimal).
    def taxa_rows(observed, cov, taxa, media, namer: nil, shown: SHOWN)
      taxa ||= {}
      syms = {}
      src = (observed || []).map { |t, n| [t["taxon_key"], t["scientific_name"], t["common_name"], t["rank"], n] }
      src = ((cov || {})["taxa"] || []).map { |t| [t["taxon_key"], t["scientific_name"], t["common_name"], t["rank"], t["n_obs"].to_i] } if src.empty?
      named = src.map do |k, sci, com, rank, n|
        name, common = taxon_names(k, sci, com, taxa[k], namer)
        [k, name, common, rank, n]
      end
      rows = named.sort_by { |x| [-x[4], x[1].to_s] }.each_with_index.map do |(k, sci, com, rank, n), i|
        tx = taxa[k]
        sid = i < shown ? sil_id(k, taxa, media, syms) : sil_id(k, taxa, media, {}).then { |id| syms.key?(id) ? id : nil }
        { "k" => k, "sci" => sci, "com" => com, "rank" => rank == "Species" ? nil : Fmt.present(rank),
          "n" => num(n), "n_raw" => n, "url" => tx && tx["slug"] ? "/species/#{tx['slug']}/" : nil, "sil" => sid }
      end
      max = rows.map { |x| x["n_raw"] }.max.to_i
      rows.each { |x| x["pct"] = max.positive? ? (x["n_raw"] * 100.0 / max).round(1) : 0 }
      sprite = syms.empty? ? nil : %(<svg class="dp-sprite" aria-hidden="true">#{syms.values.join}</svg>)
      { rows: rows, sprite: sprite }
    end

    # the id of a taxon's silhouette (its own, else its nearest ancestor's), adding its <symbol> to
    # `syms` the first time; nil when no ancestor has one. The id is a hash of the outline, so two
    # taxa that share an outline share a symbol.
    def sil_id(key, taxa, media, syms)
      t = taxa[key]
      s = nil
      seen = {}
      while t && s.nil? && !seen[t["taxon_key"]]
        seen[t["taxon_key"]] = true
        s = (media || {}).dig(t["taxon_key"], "silhouette")
        t = s ? t : taxa[t["parent_taxon_key"]]
      end
      return nil unless s && s["svg_inner"]
      id = "sil-#{Digest::MD5.hexdigest(s['svg_inner'])[0, 8]}"
      syms[id] ||= %(<symbol id="#{id}" viewBox="#{h(s['viewBox'])}">#{s['svg_inner']}</symbol>)
      id
    end

    # The measurements one dataset carries ([[measurement, series], …] from series_by_dataset), one
    # row per measurement key (a key with two series in the dataset keeps its first), grouped by the
    # record's category in category.order, most values first within a category. Units are shown
    # through the site's ONE display map (Fmt.units).
    def meas_rows(pairs)
      rows = (pairs || []).map do |m, s|
        { "k" => m["key"], "mt" => Fmt.present(s["measurement_type"]) || m["key"], "lab" => m["short_label"] || m["label"], "units" => Fmt.units(m["units"]) || Fmt.present(s["units"]), "canon" => s["is_canonical"] != false,
          "cat" => m.dig("category", "name") || "Other", "order" => m.dig("category", "order").to_i,
          "n" => big(s["n_values"]), "n_raw" => s["n_values"].to_i, "years" => yrs(s["year_min"], s["year_max"]),
          "y0" => s["year_min"], "y1" => s["year_max"], "url" => "/measurements/#{m['slug']}/", "unified" => !!m["is_unified"],
          # what it is: the dataset's own description of this measurement_type (the one in its measurement_type.csv), else the measurement's, when that says more than the name (Betty 2026-11-20, 2026-11-21)
          "desc" => Fmt.present(s["description"]) || (d = m["description"].to_s.strip; d.empty? || d.casecmp?(m["short_label"].to_s) || d.casecmp?(m["label"].to_s) ? nil : d),
          "pick" => pickable?(m, s) }
      end
      rows.uniq! { |x| x["k"] }
      rows.group_by { |x| [x["order"], x["cat"]] }.sort_by { |(o, _), _| o }
          .map { |(_, c), rs| { "cat" => c, "rows" => rs.sort_by { |x| -x["n_raw"] } } }
    end
  end

  module DatasetPage
    module_function

    # The rows of the Measurements table, one list for every kind of dataset (Betty 2026-11-21: "Measurements" on environmental and
    # biology pages alike, named for the `measurement_type` column). Two sources, so nothing the dataset carries is left out:
    #   * measurements.json (meas_rows): the measurements with values counted in the dataset, which bring the years, the page of
    #     the measurement and a CSV of just that measurement;
    #   * the release's own measurement_types (release_metadata.json): every value `measurement_type` can take in the dataset, with its units
    #     and description. These are the rest of an environmental dataset's (the cast's wind, waves, Secchi depth ... in Bottle) and ALL of a
    #     biology dataset's, which measurements.json does not cover.
    # `measurements:` in _data/dataset_extras.yml (name, desc, units) replaces a row's words, or adds a row the release does not have.
    # The cleaned (QC'd) measurements come first, the "Reported ..." pre-QC ones after them; within each, the ones every dataset shares
    # (temperature, salinity ...), then the record's category order, then most values.
    def table_rows(groups, listed, types = nil, key = nil)
      env = groups.flat_map { |g| g["rows"] }
      has_series = !env.empty?
      rows = env.map { |x| x.merge("env" => true) }
      seen = rows.map { |x| x["mt"] }
      (types.is_a?(Hash) ? types : {}).each do |name, v|
        next unless v.is_a?(Hash) && Array(v["datasets"]).include?(key) && !seen.include?(name)
        rows << { "k" => name, "mt" => name, "lab" => nil, "units" => Fmt.units(v["units"]), "desc" => Fmt.present(v["description"]),
                  "years" => nil, "url" => nil, "pick" => false, "env" => has_series, "canon" => v["is_canonical"] != false,
                  "unified" => false, "order" => 99, "n_raw" => 0 }
        seen << name
      end
      (listed || []).each do |x|
        name = Fmt.present(x["name"]) or next
        units = Fmt.units(x["units"]); desc = Fmt.present(x["desc"])
        if (r = rows.find { |y| y["mt"] == name })
          r["units"] = units if units
          r["desc"] = desc if desc
        else
          rows << { "k" => name, "mt" => name, "lab" => nil, "units" => units, "desc" => desc, "years" => nil, "url" => nil,
                    "pick" => false, "env" => has_series, "canon" => true, "unified" => false, "order" => 99, "n_raw" => 0 }
        end
      end
      rows.each_with_index.sort_by { |x, i| [x["canon"] == false ? 1 : 0, x["unified"] ? 0 : 1, x["order"].to_i, -x["n_raw"].to_i, i] }.map(&:first)
    end
  end

  # The Code tab of "Every endpoint", written for the dataset (Betty 2026-11-21): its name, its tables, its own measurement names, and a working
  # example in R, Python and plain DuckDB, in place of the same two lines for every dataset. The first two measurements are the ones the Measurements
  # table lists first; a dataset with a species table also filters on its most recorded taxon.
  module DatasetCode
    module_function

    def vec(names) = names.size == 1 ? "\"#{names[0]}\"" : "c(#{names.map { |n| "\"#{n}\"" }.join(', ')})"
    def sqlin(names) = names.map { |n| "'#{n}'" }.join(", ")

    # -> the block that replaces "Packages", or nil when the dataset has no obs table
    # (an obs row already carries its date, position and depth, so the examples need no join to `sample`)
    def block(key, tables, mrows, sci, duck_url, release)
      return nil unless tables.include?("obs")
      # only measurements stored in obs: a per-cast value (pick false, with years) is in sample_measurement, so an obs query for it finds nothing
      names = mrows.select { |m| m["pick"] || m["env"] == false }.first(2).map { |m| m["mt"] }.compact
      return nil if names.empty?
      tax = sci && tables.include?("taxon") ? sci : nil
      rin = names.size == 1 ? "\"#{names[0]}\"" : "c(#{names.map { |n| "\"#{n}\"" }.join(', ')})"
      r = +"library(dplyr)\ncon <- calcofi4r::cc_get_db()\ncalcofi4r::cc_cite(\"#{key}\")\n\n"
      r << "tbl(con, \"obs\") |>\n  filter(dataset_key == \"#{key}\",\n         measurement_type %in% #{rin}) |>\n"
      r << "  left_join(tbl(con, \"taxon\"), by = \"taxon_key\") |>\n  filter(scientific_name == \"#{tax}\") |>\n" if tax
      r << "  select(datetime, latitude, longitude, depth_min_m,\n         #{tax ? 'scientific_name, ' : ''}measurement_type, measurement_value) |>\n  collect()"
      py = +"import calcofi4py\ncon = calcofi4py.cc_get_db()\ncalcofi4py.cc_cite(\"#{key}\")\n\ncon.sql(\"\"\"\n"
      py << "  SELECT o.datetime, o.latitude, o.longitude, o.depth_min_m,\n         #{tax ? 't.scientific_name, ' : ''}o.measurement_type, o.measurement_value\n  FROM obs o\n"
      py << "  JOIN taxon t USING (taxon_key)\n" if tax
      py << "  WHERE o.dataset_key = '#{key}'\n    AND o.measurement_type IN (#{sqlin(names)})\n"
      py << "    AND t.scientific_name = '#{tax.to_s.gsub("'", "''")}'\n" if tax
      py << "\"\"\").df()"
      rows = [
        { "label" => "R · calcofi4r", "label_url" => "https://calcofi.io/calcofi4r/", "url" => "https://calcofi.io/calcofi4r/", "code" => r },
        { "label" => "Python · calcofi4py", "label_url" => "https://calcofi.io/calcofi4py/", "url" => "https://calcofi.io/calcofi4py/", "code" => py }
      ]
      if duck_url
        sql = "-- DuckDB, nothing to install: this dataset's rows, read from the table above\n" \
              "SELECT measurement_type, COUNT(*) AS n,\n       MIN(measurement_value) AS min, MAX(measurement_value) AS max\n" \
              "FROM read_parquet('#{duck_url}')\nWHERE measurement_type IN (#{sqlin(names)})\nGROUP BY measurement_type;"
        rows << { "label" => "SQL · DuckDB, no package", "code" => sql }
      end
      all = mrows.map { |m| m["mt"] }.compact
      more = all.size - 8
      { "title" => "Start with this dataset",
        "lede" => "Each `obs` row carries its date, position and depth#{tax ? "; the example keeps one species (#{tax}), so swap in any from Species" : ""}. " \
                  "Filter `measurement_type` on #{all.first(5).map { |m| "`#{m}`" }.join(', ')}#{all.size > 5 ? ", or #{all.size - 5} more in Measurements" : ''}.",
        "rows" => rows }
    end

    # Replaces "Packages" with the dataset's own block, drops the generic "DuckDB, anywhere" block (its
    # example is in ours) and the db-query snippet (the link is prefilled): the tab stays short (Betty 2026-11-21)
    def apply!(access, n_endpoints_was, blk)
      g = (access || []).find { |x| x["id"] == "code" }
      return n_endpoints_was unless g && blk
      i = (g["blocks"] || []).index { |b| b["title"] == "Packages" }
      return n_endpoints_was unless i
      cnt = ->(gr) { gr["blocks"].sum { |b| (b["rows"] || []).size + (b["matrix"] || []).size } }
      was = cnt.call(g)
      g["blocks"][i] = blk
      g["blocks"].reject! { |b| b["title"] == "DuckDB, anywhere" }
      g["blocks"].each do |b|
        next unless b["title"] == "db-query, in the browser"
        b["rows"] = b["rows"].map { |r| r.reject { |k, _| %w[code meta].include?(k) } }
        b["rows"].each { |r| r["label"] = "Open in db-query ↗"; r["meta"] = "SQL in your browser, prefilled for this dataset" if r["label_url"] }
        b.delete("lede")
      end
      g["n"] = cnt.call(g)
      n_endpoints_was.to_i - was + g["n"]
    end
  end

  class DatasetPageData < Jekyll::Generator
    safe false
    priority :lowest # after DatasetCatalog (:high), which builds the pages and the Catalog

    SHOWN = DatasetPage::SHOWN

    def generate(site)
      @site = site
      @cat = BrowseData.catalog
      return unless @cat
      taxa_rec = read("taxa") || {}
      @taxa = taxa_rec["taxa"].to_a.to_h { |t| [t["taxon_key"], t] }
      @media = (read("taxa_media") || {})["taxa"] || {}
      # the species pages' own name rule (species.rb), so a row and its species page agree on a name
      @namer = defined?(Taxa) ? Taxa.new(site, taxa_rec).method(:name_of) : nil
      # every taxon a dataset observed, from taxa.json (the record's coverage lists only the top 50)
      @by_ds = DatasetPage.observed_by_dataset(@taxa.values)
      @series = DatasetPage.series_by_dataset((read("measurements") || {})["measurements"])
      @extras = site.data["dataset_extras"]
      @tiles = site.data.dig("browse", "tiles") || []
      @meta = read("release_metadata")
      site.pages.each do |page|
        next unless page.data["layout"] == "dataset" && !page.data["is_holding"]
        r = page.data["record"] or next
        page.data["dp"] = build(page, r)
      end
    end

    private

    def read(name)
      f = File.join(@site.source, "_data", "#{name}.json")
      File.exist?(f) ? JSON.parse(File.read(f)) : nil
    rescue JSON::ParserError
      nil
    end

    def build(page, r)
      key = r["dataset_key"]
      cov = r["coverage"] || {}
      a = r["attribution"] || {}
      dist = r["distributions"] || []
      lede, rest = DatasetPage.lede_rest(@cat.plain(r["description_md"]), @cat.first_sentence(r["description_md"]))
      # A dataset listed in _data/dataset_extras.yml (Betty 2026-11-20): "More about the record" is only what that file's
      # `more:` gives, and the sentence under the title its `lede:` when the record's first sentence is cut short. Nothing
      # else of the record's description reaches the page, so notes for the data team never do. An unlisted dataset
      # keeps the record's own first sentence and the rest.
      xe = DatasetExtras.for(@extras, key)
      if xe["listed"]
        lede = xe["lede"] || lede
        rest = xe["more"]
      end
      taxa = DatasetPage.taxa_rows(@by_ds[key], cov, @taxa, @media, namer: @namer)
      meas = DatasetPage.meas_rows(@series[key])
      mrows = DatasetPage.table_rows(meas, xe["measurements"], (@meta.is_a?(Hash) ? @meta["measurement_types"] : nil), key)
      n_meas = mrows.size
      # the Code tab written for this dataset: the DuckDB example reads the dataset's own obs table, whose address the tab already lists
      acc = page.data["access"]
      duck = (acc || []).find { |g| g["id"] == "code" }&.dig("blocks")&.find { |b| b["title"] == "DuckDB, anywhere" }&.dig("rows", 0)
      duck_url = duck && duck["label"].to_s.start_with?("obs") ? duck["url"] : nil
      blk = DatasetCode.block(key, (r["tables"] || []).map(&:to_s), mrows, taxa[:rows].first&.dig("sci"), duck_url, nil)
      page.data["n_endpoints"] = DatasetCode.apply!(acc, page.data["n_endpoints"], blk)
      products = @cat.products_by_dataset[key]
      explore = products.find { |p| p["key"] == "explore" && p["dataset_url"] }
      finder = products.find { |p| p["key"] == "db-viz-station" && p["dataset_url"] }
      erd = @cat.erddap_current(dist)
      src = dist.find { |x| x["kind"] == "source" && Fmt.present(x["url"]) }
      {
        "lede" => lede, "rest" => rest,
        "byline" => DatasetPage.byline(r, !(xe["analysis_lab"] || xe["analysis_who"])),
        "facts" => DatasetPage.facts(r, years_span: page.data["years_span"], depth: page.data["depth"],
                                        n_taxa: taxa[:rows].size, n_meas: n_meas),
        "years" => DatasetPage.years_svg(cov, @cat.strip_span), "months" => DatasetPage.months_html(cov),
        "month_tiles" => DatasetPage.month_tiles(cov),
        "n_years" => (cov["years"] || []).count { |y| y["n_obs"].to_i.positive? },
        "taxa" => taxa[:rows].first(SHOWN), "sprite" => taxa[:sprite], "n_taxa" => taxa[:rows].size,
        # the rest, drawn by assets/dataset-page.js on "Show all" or a search (992 rows for Ichthyoplankton)
        "taxa_more" => taxa[:rows].size > SHOWN ? JSON.generate(taxa[:rows].drop(SHOWN).map { |x| x.values_at("k", "sci", "com", "rank", "n", "n_raw", "url", "sil", "pct") }) : nil,
        "mrows" => mrows, "n_meas" => n_meas,
        "stages" => cov["life_stages"] || [],
        # no Explorer link for a record with sampling events and no counted observation yet (as the old page)
        "explore" => explore && !@cat.samples_only?(r) ? explore["dataset_url"].gsub("{key}", key) : nil,
        "samples_only" => @cat.samples_only?(r),
        # the citation as the provider gives it; the page's own cite_text adds licence, DOI and acknowledgement,
        # which sit beside it here
        "cite" => xe["citation_override"] || Fmt.present(a["citation_main"]),
        "finder" => finder && finder["dataset_url"].gsub("{key}", key),
        # `map_note:` in _data/dataset_extras.yml says so where a dataset has no stations (samples pooled into regions) instead of counting them (Betty 2026-11-21)
        "map_cap" => [xe["map_note"] || (cov["n_stations"].to_i.positive? ? "#{DatasetPage.num(cov['n_stations'])} stations sampled" : nil), Fmt.present(cov["spatial"])].compact.join(" · "),
        "erddap_obs" => erd.find { |x| x["url"].end_with?("/#{key}.html") }&.dig("url"),
        "erddap_sample" => erd.find { |x| x["url"].end_with?("/#{key}_sample.html") }&.dig("url"),
        # a portal's short name is the catalog's (Catalog#portal_short), not a second map kept here
        "src" => xe["source_url"] || (src && src["url"]), "src_portal" => xe["source_url"] ? xe["source_label"] : (src && src["portal"] != "other" ? @cat.portal_short(src["portal"]) : nil),
        "archived" => (r["registrations"] || []).select { |x| x["status"] == "published" && !%w[erddap ncei edi obis].include?(x["portal"]) && Fmt.present(x["url"]) } # the box is for the whole release (Zenodo); a portal's record of this one dataset (NCEI, EDI, OBIS) is under Archives & portals (Betty 2026-11-21)
                        .map { |x| { "name" => @cat.portal_short(x["portal"]), "url" => x["url"] } },
        "creators" => DatasetPage.creators(a, xe["creator_org"]),
        "contact" => Fmt.present(a["contact"].to_s.sub(/\Amailto:/, "")),
        "data_provider" => (a["data_provider"].is_a?(Hash) ? a["data_provider"] : nil),
        "funding" => Fmt.present(a["funding"]), "ack" => xe["ack_override"] || Fmt.present(a["acknowledgement"]),
        "ack_only" => !xe["ack_override"].nil?, "licence_note" => xe["licence_note"], "sources_inline" => xe["sources_inline"], "refs" => xe["refs"],
        "agreement_url" => xe["agreement_url"], "agreement_label" => xe["agreement_label"],
        "license" => Fmt.present(a["license_name"]) || Fmt.present(a["license"]), "license_url" => Fmt.present(a["license_url"]),
        "doi" => Fmt.present(a["doi"]),
        # Betty 2026-11-18: the words the record does not carry yet, the tile it sits in (the back link),
        # the NOAA ERDDAP tables it combines, the download's columns, and the first five species
        "extra" => DatasetExtras.for(@extras, key),
        "tile" => DatasetExtras.tile_of(@tiles, key),
        "sources" => DatasetExtras.source_tables(r),
        "fields" => DatasetExtras.fields(@meta, r, bio: taxa[:rows].any?),
        # what assets/dataset-page.js needs for the download form
        "dl" => JSON.generate({
          "key" => key, "name" => r["dataset_name_short"] || r["dataset_name"] || key,
          "y0" => cov["year_min"], "y1" => cov["year_max"], "n" => cov["n_obs"],
          "file" => DatasetPage.form_file(r, page.data["download"], page.url)
        })
      }
    end
  end
end
