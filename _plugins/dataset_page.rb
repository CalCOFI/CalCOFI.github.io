# frozen_string_literal: true

require "cgi"
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
#   bottom   About the data: creators (the lead marked), contact, credit, also archived at
#
# Everything is read from the release record. Taxa, silhouettes and measurement series are read from
# disk (_data/*.json), as finder.rb does: species.rb and measurements.rb replace their site.data keys.
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

    # Can the Query Builder serve this measurement from this dataset (explore/builder.html?pick=env:<dataset>:<key>)?
    # The builder reads the release's observation tables. A series the record marks `grain: "sample"` is one value
    # per cast (the sample_measurement table: mixed-layer depth, chlorophyll maximum …), which the builder does not
    # read, so its row gets no CSV button rather than a button that opens the builder on "not in this release".
    # The series' own grain wins; the measurement's is the fallback.
    def pickable?(measurement, series)
      grain = (series.is_a?(Hash) ? series["grain"] : nil) || (measurement.is_a?(Hash) ? measurement["grain"] : nil)
      grain.to_s != "sample"
    end
  end

  class DatasetPageData < Jekyll::Generator
    safe false
    priority :lowest # after DatasetCatalog (:high), which builds the pages and the Catalog

    SHOWN = 50 # rows drawn in the page; the rest come from JSON
    MON = %w[J F M A M J J A S O N D].freeze
    PORTAL = { "edi" => "EDI", "zenodo" => "Zenodo", "obis" => "OBIS", "ncei" => "NCEI", "caloos" => "CalOOS",
               "gbif" => "GBIF", "calcofi.org" => "calcofi.org" }.freeze

    def generate(site)
      @site = site
      @cat = BrowseData.catalog
      return unless @cat
      @taxa = (read("taxa") || {})["taxa"].to_a.to_h { |t| [t["taxon_key"], t] }
      @media = (read("taxa_media") || {})["taxa"] || {}
      # every taxon a dataset observed, from taxa.json (the record's coverage lists only the top 50)
      @by_ds = Hash.new { |h, k| h[k] = [] }
      @taxa.each_value do |t|
        (t["datasets"] || []).each { |d| @by_ds[d["dataset_key"]] << [t, d["n_obs"].to_i] if d["n_obs"].to_i.positive? }
      end
      @series = Hash.new { |h, k| h[k] = [] }
      ((read("measurements") || {})["measurements"] || []).each do |m|
        (m["series"] || []).each { |s| @series[s["dataset_key"]] << [m, s] }
      end
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

    def num(n) = n.nil? ? nil : n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    def big(n)
      n = n.to_i
      return num(n) if n < 10_000
      n >= 1_000_000 ? format("%.1fM", n / 1e6) : "#{(n / 1000.0).round}k"
    end
    def yrs(a, b) = a.nil? ? nil : (a == b ? a.to_s : "#{a}–#{b}")
    def h(s) = CGI.escapeHTML(s.to_s)

    def build(page, r)
      key = r["dataset_key"]
      cov = r["coverage"] || {}
      a = r["attribution"] || {}
      dist = r["distributions"] || []
      text = @cat.plain(r["description_md"]).to_s
      lede = @cat.first_sentence(r["description_md"]).to_s.sub(/ …\z/, "")
      rest = text.start_with?(lede) ? text[lede.length..].to_s.strip : text
      taxa = taxa_rows(key, cov)
      meas = meas_rows(key)
      products = @cat.products_by_dataset[key]
      explore = products.find { |p| p["key"] == "explore" && p["dataset_url"] }
      finder = products.find { |p| p["key"] == "db-viz-station" && p["dataset_url"] }
      erd = @cat.send(:erddap_current, dist)
      src = dist.find { |x| x["kind"] == "source" && Fmt.present(x["url"]) }
      {
        "lede" => lede.empty? ? nil : lede, "rest" => rest.empty? ? nil : rest,
        "byline" => byline(r),
        "facts" => facts(page, r, cov, taxa, meas),
        "years" => years_svg(cov), "months" => months_html(cov),
        "n_years" => (cov["years"] || []).count { |y| y["n_obs"].to_i.positive? },
        "taxa" => taxa[:rows].first(SHOWN), "sprite" => taxa[:sprite], "n_taxa" => taxa[:rows].size,
        # the rest, drawn by assets/dataset-page.js on "Show all" or a search (992 rows for Ichthyoplankton)
        "taxa_more" => taxa[:rows].size > SHOWN ? JSON.generate(taxa[:rows].drop(SHOWN).map { |x| x.values_at("k", "sci", "com", "rank", "n", "n_raw", "url", "sil", "pct") }) : nil,
        "meas" => meas, "n_meas" => meas.sum { |g| g["rows"].size },
        "stages" => cov["life_stages"] || [],
        # no Explorer link for a record with sampling events and no counted observation yet (as the old page)
        "explore" => explore && !@cat.samples_only?(r) ? explore["dataset_url"].gsub("{key}", key) : nil,
        "samples_only" => @cat.samples_only?(r),
        # the citation as the provider gives it; the page's own cite_text adds licence, DOI and acknowledgement,
        # which sit beside it here
        "cite" => Fmt.present(a["citation_main"]),
        "finder" => finder && finder["dataset_url"].gsub("{key}", key),
        "map_cap" => [cov["n_stations"].to_i.positive? ? "#{num(cov['n_stations'])} stations sampled" : nil, Fmt.present(cov["spatial"])].compact.join(" · "),
        "erddap_obs" => erd.find { |x| x["url"].end_with?("/#{key}.html") }&.dig("url"),
        "erddap_sample" => erd.find { |x| x["url"].end_with?("/#{key}_sample.html") }&.dig("url"),
        "event_word" => event_word(r),
        "src" => src && src["url"], "src_portal" => src && src["portal"] != "other" ? (PORTAL[src["portal"]] || src["portal"]) : nil,
        "archived" => (r["registrations"] || []).select { |x| x["status"] == "published" && x["portal"] != "erddap" && Fmt.present(x["url"]) }
                        .map { |x| { "name" => PORTAL[x["portal"]] || x["portal"], "url" => x["url"] } },
        "creators" => creators(a),
        "contact" => Fmt.present(a["contact"].to_s.sub(/\Amailto:/, "")),
        "funding" => Fmt.present(a["funding"]), "ack" => Fmt.present(a["acknowledgement"]),
        "license" => Fmt.present(a["license_name"]) || Fmt.present(a["license"]), "license_url" => Fmt.present(a["license_url"]),
        "doi" => Fmt.present(a["doi"]),
        # what assets/dataset-page.js needs for the download form
        "dl" => JSON.generate({
          "key" => key, "name" => r["dataset_name_short"] || r["dataset_name"] || key,
          "y0" => cov["year_min"], "y1" => cov["year_max"], "n" => cov["n_obs"],
          "file" => DatasetPage.form_file(r, page.data["download"], page.url)
        })
      }
    end

    def byline(r)
      full = Fmt.present(r["dataset_name"])
      short = Fmt.present(r["dataset_name_short"])
      prov = r.dig("provider", "short") || r.dig("provider", "name")
      pis = r.dig("attribution", "pi_names") || []
      [full && full != short ? full : nil, prov ? "From #{prov}#{pis.empty? ? '' : ", #{pis.join(', ')}"}" : nil].compact.join(" · ")
    end

    def facts(page, r, cov, taxa, meas)
      out = []
      out << [page.data["years_span"] || yrs(cov["year_min"], cov["year_max"]), "Years"] if cov["year_min"]
      out << [num(cov["n_obs"]), "Records"] if cov["n_obs"].to_i.positive?
      out << [num(cov["n_roots"]), "Sampling events"] if cov["n_roots"].to_i.positive?
      out << [num(cov["n_stations"]), "Stations"] if cov["n_stations"].to_i.positive?
      if taxa[:rows].any? then out << [num(taxa[:rows].size), taxa[:rows].size == 1 ? "Taxon" : "Taxa"]
      elsif meas.any? then n = meas.sum { |g| g["rows"].size }; out << [num(n), n == 1 ? "Measurement" : "Measurements"]
      end
      out << [page.data["depth"].to_s.sub(/\Asurface\z/, "Surface"), "Depth"] if page.data["depth"]
      out
    end

    # the word for one sampling event, from the record's own words where it is plain; else the generic
    def event_word(r)
      cat = r.dig("category", "name").to_s
      return "casts" if r["dataset_key"].to_s.match?(/bottle|ctd/)
      return "net tows" if cat.match?(/Krill|Zooplankton|Phyllosoma|Eggs/i) && r["dataset_name"].to_s !~ /CUFES|eDNA/i
      "sampling events"
    end

    def creators(a)
      lead = (a["pi_names"] || []).first
      cs = (a["creators"] || []).map { |c| [c["name"], Fmt.present(c["organization"])] }
      cs = (a["pi_names"] || []).map { |n| [n, nil] } if cs.empty?
      return nil if cs.empty?
      orgs = cs.map(&:last).compact.uniq
      names = cs.map { |n, o| "#{n}#{n == lead ? ' (lead)' : ''}#{orgs.size > 1 && o ? " (#{o})" : ''}" }
      list = names.size > 2 ? "#{names[0..-2].join(', ')} and #{names[-1]}" : names.join(" and ")
      orgs.size == 1 ? "#{list}, #{orgs[0]}" : list
    end

    # records per year on the release's own axis, and by month (the mockup's two charts)
    def years_svg(cov)
      ys = cov["years"] || []
      return nil if ys.empty?
      y0, y1 = @cat.strip_span || [ys.map { |y| y["year"] }.min, ys.map { |y| y["year"] }.max]
      y0 = [y0, 1949].min
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

    def months_html(cov)
      ms = cov["months"]
      return nil unless ms.is_a?(Array) && ms.size == 12
      max = [ms.max.to_i, 1].max
      n = ms.count(&:positive?)
      { "label" => n == 12 ? "all 12" : "#{n} of 12",
        "html" => %(<div class="dp-mo">#{ms.each_with_index.map { |v, i| %(<i style="height:#{v.positive? ? [v * 100.0 / max, 5].max.round(1) : 0}%" title="#{MON[i]}: #{num(v)} records"></i>) }.join}</div>) +
                  %(<div class="dp-mol">#{MON.map { |m| "<span>#{m}</span>" }.join}</div>) }
    end

    # the taxa, most recorded first, each with its silhouette (its own, else the nearest ancestor's)
    # drawn once per page as a <symbol>
    def taxa_rows(key, cov)
      syms = {}
      src = @by_ds[key].map { |t, n| [t["taxon_key"], t["scientific_name"], t["common_name"], t["rank"], n] }
      src = (cov["taxa"] || []).map { |t| [t["taxon_key"], t["scientific_name"], t["common_name"], t["rank"], t["n_obs"].to_i] } if src.empty?
      # silhouettes for the rows drawn in the page; a later row reuses one only if it is already drawn
      # (Ichthyoplankton's 992 would otherwise carry megabytes of outlines)
      rows = src.sort_by { |x| [-x[4], x[1].to_s] }.each_with_index.map do |(k, sci, com, rank, n), i|
        tx = @taxa[k]
        sid = i < SHOWN ? sil_id(k, syms) : sil_id(k, {}).then { |id| syms.key?(id) ? id : nil }
        { "k" => k, "sci" => sci, "com" => Fmt.present(com.to_s.strip), "rank" => rank == "Species" ? nil : Fmt.present(rank),
          "n" => num(n), "n_raw" => n, "url" => tx && tx["slug"] ? "/species/#{tx['slug']}/" : nil, "sil" => sid }
      end
      max = rows.map { |x| x["n_raw"] }.max.to_i
      rows.each { |x| x["pct"] = max.positive? ? (x["n_raw"] * 100.0 / max).round(1) : 0 }
      sprite = syms.empty? ? nil : %(<svg class="dp-sprite" aria-hidden="true">#{syms.values.join}</svg>)
      { rows: rows, sprite: sprite }
    end

    def sil_id(key, syms)
      t = @taxa[key]
      s = nil
      while t && s.nil?
        s = @media.dig(t["taxon_key"], "silhouette")
        t = s ? t : @taxa[t["parent_taxon_key"]]
      end
      return nil unless s && s["svg_inner"]
      id = "sil-#{Digest::MD5.hexdigest(s['svg_inner'])[0, 8]}"
      syms[id] ||= %(<symbol id="#{id}" viewBox="#{h(s['viewBox'])}">#{s['svg_inner']}</symbol>)
      id
    end

    # the measurements this dataset carries, grouped by category, most values first
    def meas_rows(key)
      rows = @series[key].map do |m, s|
        { "k" => m["key"], "lab" => m["short_label"] || m["label"], "units" => units(m["units"]),
          "cat" => m.dig("category", "name") || "Other", "order" => m.dig("category", "order").to_i,
          "n" => big(s["n_values"]), "n_raw" => s["n_values"].to_i, "years" => yrs(s["year_min"], s["year_max"]),
          "y0" => s["year_min"], "y1" => s["year_max"], "url" => "/measurements/#{m['slug']}/", "unified" => !!m["is_unified"],
          "pick" => DatasetPage.pickable?(m, s) }
      end
      rows.uniq! { |x| x["k"] }
      rows.group_by { |x| [x["order"], x["cat"]] }.sort_by { |(o, _), _| o }
          .map { |(_, c), rs| { "cat" => c, "rows" => rs.sort_by { |x| -x["n_raw"] } } }
    end

    def units(u) = FinderData::UNITS[u] || u
  end
end
