# _plugins/datasets.rb — the dataset catalog, generated from the release record.
#
# `_data/datasets.json` (calcofi4db::build_dataset_catalog(), schema 1.0; fetched by
# scripts/fetch_release.sh) is the ONLY source of a dataset fact on this site. This generator
# turns it into:
#
#   /datasets/                    the catalog grid, full width
#   /datasets/{key}/              one page per dataset and per holding
#   /datasets/{key}.json          the record for that key, verbatim
#   /datasets/{key}.jsonld        its schema.org/Dataset node
#   /datasets/release/            the integrated database itself (hasPart the datasets)
#   /datasets/sitemap.xml         the pages, lastmod = release_date
#   /datasets/search.json         names · descriptions · variables · taxa, for the filter row
#   /data.json                    DCAT-US 1.1, for data.gov and any CKAN
#
# and hands the landing page `site.data.catalog` (the category tiles, the release strip, the
# reverse product index) so index.html stays Liquid.
#
# Rules that hold here because they hold in the record (plan Appendix A):
#   · `visibility: internal` gets no page, no sitemap row, no data.json row, no search row
#   · null is null — a field the release cannot supply is not rendered, never invented
#   · a products.yml `datasets:` key that is in neither datasets[] nor holdings[] FAILS the build
#
# GitHub Pages builds this site through Actions (.github/workflows/pages.yml), so a custom
# plugin runs; `jekyll build` on a fresh clone runs it too.

require "json"

module CalCOFI
  # ── small formatters ───────────────────────────────────────────────────────
  module Fmt
    module_function

    def num(n)
      return nil if n.nil?
      n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    end

    # 4.0 MB / 226 MB / 2.5 GB — one unit, at most one decimal
    def bytes(b)
      return nil if b.nil?
      b = b.to_f
      %w[B KB MB GB TB].each_with_index do |u, i|
        v = b / (1024.0**i)
        next if v >= 1024 && i < 4
        return format(v >= 100 || i.zero? ? "%.0f %s" : "%.1f %s", v, u)
      end
    end

    def blank?(v)
      v.nil? || (v.respond_to?(:empty?) && v.empty?)
    end

    def present(v)
      blank?(v) ? nil : v
    end

    # A handful of the record's ERDDAP titles carry a LITERAL "—" rather than the em dash it
    # encodes (the ERDDAP title is JSON-escaped once too often upstream — reported to WS-R0). Render
    # the character the record means rather than the escape; this is a display fix, not a fact.
    def unesc(v)
      return v unless v.is_a?(String) && v.include?('\u')
      v.gsub(/\\u([0-9a-fA-F]{4})/) { [Regexp.last_match(1).hex].pack("U") }
    end
  end

  # ── the record, wrapped ────────────────────────────────────────────────────
  class Catalog
    include Fmt
    attr_reader :rec, :site, :grid

    ERDDAP_FORMATS = [%w[csv CSV], %w[nc netCDF], %w[json JSON]].freeze

    def initialize(site, rec, grid)
      @site = site
      @rec  = rec
      @grid = grid
      @base = site.config["url"].to_s.sub(%r{/\z}, "")
      @contact = site.config["contact_email"] || "data@calcofi.io"
    end

    def release      = rec["release"]
    def datasets     = @datasets ||= (rec["datasets"] || []).reject { |d| d["visibility"] == "internal" }
    def holdings     = @holdings ||= (rec["holdings"] || []).reject { |h| h["visibility"] == "internal" }
    def reference    = rec["reference"] || []
    def records      = datasets + holdings
    def holding?(r)  = r.key?("status") && !r.key?("coverage")
    def page_url(r)  = "/datasets/#{r['dataset_key']}/"
    def abs(path)    = "#{@base}#{path}"
    def contact      = @contact

    def by_key = @by_key ||= records.to_h { |r| [r["dataset_key"], r] }

    # ── the reverse index: which products declare which dataset ──────────────
    # products.yml carries `datasets:` per card — a list of keys, or the literal `all`.
    # Any other key that is not in the record fails the build (plan D-2).
    def products_by_dataset
      @products_by_dataset ||= begin
        idx  = Hash.new { |h, k| h[k] = [] }
        bad  = []
        prods = (site.data.dig("products", "products") || [])
        sections = (site.data.dig("products", "sections") || []).to_h { |s| [s["id"], s] }
        # sections[].groups[] gives an eyebrow group its human title ("Across datasets"), so the
        # Access table's Explore rows read as the landing page's groups do
        group_titles = sections.values.flat_map { |s| s["groups"] || [] }
                               .to_h { |g| [g["id"], g["title"]] }
        prods.each do |p|
          want = p["datasets"]
          next if Fmt.blank?(want)
          keys = want == "all" ? datasets.map { |d| d["dataset_key"] } : Array(want)
          keys.each do |k|
            next bad << [p["key"], k] unless by_key.key?(k)
            idx[k] << {
              "key"      => p["key"],
              "title"    => p["title"],
              "url"      => p["live_url"],
              "section"  => sections.dig(p["section"], "title"),
              "group"    => group_titles[p["group"]] || p["group"],
              "section_id" => p["section"]
            }
          end
        end
        unless bad.empty?
          raise Jekyll::Errors::FatalException,
                "products.yml names dataset keys that are in neither datasets[] nor holdings[] of " \
                "#{release['version']}'s datasets.json: " +
                bad.map { |pk, k| "#{pk} → #{k}" }.join(", ")
        end
        idx
      end
    end

    # ── categories: the twelve+1 tiles, in `category.order`, then the reference tile ──
    def categories
      @categories ||= begin
        cats = {}
        put = lambda do |c|
          next if c.nil? || Fmt.blank?(c["name"])
          cats[c["name"]] ||= {
            "name" => c["name"], "realm" => c["realm"], "order" => c["order"],
            "icon" => icon_for(c["icon"]), "datasets" => [], "contributions" => [], "holdings" => []
          }
        end
        datasets.each { |d| put.call(d["category"]) }
        holdings.each { |h| put.call(h["category"]) }
        datasets.each do |d|
          (d.dig("coverage", "contributes_to") || []).each do |ct|
            put.call({ "name" => ct["category"] })
          end
        end

        datasets.each { |d| cats[d.dig("category", "name")]["datasets"] << tile_row(d) if cats[d.dig("category", "name")] }
        holdings.each { |h| cats[h.dig("category", "name")]["holdings"] << holding_row(h) if cats[h.dig("category", "name")] }
        datasets.each do |d|
          (d.dig("coverage", "contributes_to") || []).each do |ct|
            c = cats[ct["category"]] or next
            c["contributions"] << {
              "key"       => d["dataset_key"],
              "name"      => d["dataset_name_short"] || d["dataset_name"] || d["dataset_key"],
              "home"      => d.dig("category", "name"),
              "url"       => page_url(d),
              "variables" => ct["variables"] || []
            }
          end
        end

        list = cats.values.sort_by { |c| [c["order"] || 999, c["name"]] }
        list.each do |c|
          c["datasets"].sort_by! { |t| t["name"].to_s.downcase }
          c["contributions"].sort_by! { |t| t["name"].to_s.downcase }
          c["holdings"].sort_by! { |t| t["name"].to_s.downcase }
          c["n"] = c["datasets"].size
        end
        list
      end
    end

    # `cat-genomics` reached the registry (plan Decision 18) with brand v2's sprite; the icon is
    # added there through explore/scripts/build_icons.mjs. Anything the sprite still lacks draws
    # as `cat-other` rather than as an empty square.
    SPRITE = %w[cat-physical cat-nutrients cat-carbonate cat-productivity cat-meteorology
                cat-phytoplankton cat-picoplankton cat-zooplankton cat-krill cat-ichthyo cat-fish
                cat-birds-mammals cat-whale cat-genomics cat-other lens-stations].freeze
    def icon_for(id) = SPRITE.include?(id) ? id : "cat-other"

    def reference_tile
      @reference_tile ||= begin
        rows = reference.map do |r|
          {
            "key"   => r["key"],
            "kind"  => r["kind"],
            "name"  => r["name"],
            "desc"  => r["description_md"],
            "group" => r["group"],
            "url"   => r["url"],
            "schema_url" => r["schema_url"],
            "count" => r["rows"] || r["n_features"],
            "count_label" => r["rows"] ? "rows" : (r["n_features"] ? "features" : nil),
            "attribution" => r["attribution"]
          }
        end
        {
          "name"  => "Cruises, stations & spatial",
          "realm" => "ref",
          "icon"  => "lens-stations",
          "n"     => rows.size,
          "tables" => rows.select { |r| r["kind"] == "table" },
          "layers" => rows.select { |r| r["kind"] == "layer" },
          "rasters" => rows.select { |r| r["kind"] == "raster" }
        }
      end
    end

    # ── the filter row's options: only values that actually occur ────────────
    def facets
      @facets ||= {
        "categories" => categories.map { |c| c["name"] },
        "providers"  => records.filter_map { |r| r.dig("provider", "short") || r.dig("provider", "key") }.uniq.sort,
        "realms"     => datasets.filter_map { |d| d.dig("coverage", "realm") || d.dig("category", "realm") }.uniq.sort,
        "licenses"   => records.filter_map { |r| Fmt.present(r.dig("attribution", "license")) }.uniq.sort,
        "formats"    => datasets.flat_map { |d| formats(d) }.uniq.sort,
        "stages"     => records.filter_map { |r| Fmt.present(r.dig("status", "stage")) }.uniq.sort
      }
    end

    # ── one dataset as a tile row in the category grid ───────────────────────
    def tile_row(d)
      cov = d["coverage"] || {}
      {
        "key"        => d["dataset_key"],
        "name"       => d["dataset_name_short"] || d["dataset_name"] || d["dataset_key"],
        "full_name"  => d["dataset_name"],
        "url"        => page_url(d),
        "provider"   => d.dig("provider", "short") || d.dig("provider", "key"),
        "realm"      => cov["realm"] || d.dig("category", "realm"),
        "year_min"   => cov["year_min"],
        "year_max"   => cov["year_max"],
        "years"      => year_span(cov),
        "n_obs"      => cov["n_obs"],
        "n_obs_fmt"  => Fmt.num(cov["n_obs"]),
        "license"    => d.dig("attribution", "license"),
        "doi"        => d.dig("attribution", "doi"),
        "formats"    => formats(d),
        "stage"      => d.dig("status", "stage"),
        "years_bar"  => years_bar(cov["years"], cov["year_min"], cov["year_max"])
      }
    end

    def holding_row(h)
      {
        "key"      => h["dataset_key"],
        "name"     => h["dataset_name_short"] || h["dataset_name"] || h["dataset_key"],
        "url"      => page_url(h),
        "provider" => h.dig("provider", "short") || h.dig("provider", "key"),
        "stage"    => h.dig("status", "stage"),
        "link"     => h.dig("links", "data_source")
      }
    end

    def year_span(cov)
      a, b = cov["year_min"], cov["year_max"]
      return nil if a.nil? && b.nil?
      a == b ? a.to_s : "#{a}–#{b}"
    end

    # the format chips on a tile: what this dataset can actually be had as, measured
    def formats(d)
      f = []
      dist = d["distributions"] || []
      f << "parquet" if dist.any? { |x| x["format"] == "parquet" }
      f << "netCDF"  if dist.any? { |x| x["format"] == "netcdf" }
      f << "ERDDAP"  if dist.any? { |x| x["format"] == "erddap" && x["status"] != "superseded" }
      (d["registrations"] || []).each do |r|
        f << r["portal"].upcase if r["status"] == "published" && %w[obis edi ncei].include?(r["portal"])
      end
      f.uniq
    end

    # ── the years sparkline: one bar per year over the full span ─────────────
    def years_bar(years, ymin, ymax)
      return nil if Fmt.blank?(years) || ymin.nil? || ymax.nil?
      by = years.to_h { |y| [y["year"], y["n_obs"].to_f] }
      span = (ymin..ymax).to_a
      max  = by.values.max.to_f
      return nil if max <= 0
      w, h, gap = 3.0, 28.0, 1.0
      bars = span.each_with_index.map do |yr, i|
        v = by[yr] || 0.0
        bh = v.zero? ? 0.8 : [1.0, (v / max) * h].max
        format('<rect x="%.1f" y="%.2f" width="%.1f" height="%.2f"%s/>',
               i * (w + gap), h - bh, w, bh, v.zero? ? ' opacity=".25"' : "")
      end
      vw = span.size * (w + gap)
      %(<svg class="ds-spark" viewBox="0 0 #{format('%.1f', vw)} #{h.to_i}" preserveAspectRatio="none" ) +
        %(role="img" aria-label="Observations per year, #{ymin} to #{ymax}">#{bars.join}</svg>)
    end

    # ── the bbox over the station grid: a static SVG, no map library ─────────
    # equirectangular with a cos(mean latitude) correction on longitude, over the union of the
    # grid's extent and the dataset's bbox, so the box is always in frame.
    def bbox_svg(bbox)
      pts = grid
      return nil if bbox.nil? || bbox.values.any?(&:nil?)
      lons = [bbox["lon_min"], bbox["lon_max"]] + pts.map(&:first)
      lats = [bbox["lat_min"], bbox["lat_max"]] + pts.map(&:last)
      x0, x1 = lons.min, lons.max
      y0, y1 = lats.min, lats.max
      pad_x = [(x1 - x0) * 0.04, 0.5].max
      pad_y = [(y1 - y0) * 0.04, 0.5].max
      x0 -= pad_x; x1 += pad_x; y0 -= pad_y; y1 += pad_y
      k  = Math.cos((y0 + y1) / 2 * Math::PI / 180)
      wl = (x1 - x0) * k
      hl = (y1 - y0)
      w  = 320.0
      h  = [(w * hl / wl), 40.0].max
      px = ->(lon) { (lon - x0) * k / wl * w }
      py = ->(lat) { (y1 - lat) / hl * h }

      dots = pts.map { |lon, lat| format('<circle cx="%.1f" cy="%.1f" r="1.1"/>', px.(lon), py.(lat)) }
      bx = px.(bbox["lon_min"])
      bw = px.(bbox["lon_max"]) - bx
      byy = py.(bbox["lat_max"])
      bh = py.(bbox["lat_min"]) - byy
      label = format("%.1f–%.1f°N, %.1f–%.1f°E", bbox["lat_min"], bbox["lat_max"], bbox["lon_min"], bbox["lon_max"])
      %(<svg class="ds-bbox" viewBox="0 0 #{format('%.0f', w)} #{format('%.0f', h)}" role="img" ) +
        %(aria-label="Extent #{label} over the CalCOFI station grid">) +
        %(<g class="ds-bbox-grid">#{dots.join}</g>) +
        format('<rect class="ds-bbox-box" x="%.1f" y="%.1f" width="%.1f" height="%.1f"/>', bx, byy, bw, bh) +
        "</svg>"
    end

    # ── the Access table, grouped by how (plan D-4 / Decision 4) ─────────────
    def access_groups(d)
      key   = d["dataset_key"]
      dist  = d["distributions"] || []
      tables = d["tables"] || []
      groups = []

      # explore — the APPS that declare this dataset in products.yml (the reverse index). The
      # Access / Build products get their own rows below, so they are not repeated here.
      rows = products_by_dataset[key]
             .select { |p| %w[explore students].include?(p["section_id"]) }
             .map do |p|
        url = p["key"] == "explore" ? "#{p['url']}?datasets=#{key}" : p["url"]
        { "label" => p["title"], "url" => url,
          "meta" => p["section_id"] == "students" ? "student contribution" : p["group"] }
      end
      groups << { "id" => "explore", "title" => "Explore", "rows" => rows } unless rows.empty?

      # query — the browser SQL, with a snippet that resolves this dataset's tables
      unless tables.empty?
        sql = "-- #{key} in the CalCOFI release #{release['version']}\n" \
              "SELECT * FROM obs WHERE dataset_key = '#{key}' LIMIT 100;"
        groups << { "id" => "query", "title" => "Query", "rows" => [
          { "label" => "db-query — SQL in your browser", "url" => "https://calcofi.io/db-query/",
            "meta"  => "DuckDB-WASM over the released parquet" },
          { "label" => "SQL", "code" => sql, "meta" => "tables: #{tables.join(', ')}" }
        ] }
      end

      # code — the two packages, same wording as cc_cite()
      groups << { "id" => "code", "title" => "Code", "rows" => [
        { "label" => "R · calcofi4r", "url" => "https://calcofi.io/calcofi4r/",
          "code" => "con <- calcofi4r::cc_get_db()\ncalcofi4r::cc_cite(\"#{key}\")" },
        { "label" => "Python · calcofi4py", "url" => "https://calcofi.io/calcofi4py/",
          "code" => "con = calcofi4py.cc_get_db()\ncalcofi4py.cite(\"#{key}\")" }
      ] }

      # download — parquet objects, the CF netCDF, ERDDAP's data formats, the source download
      dl = []
      dist.select { |x| x["format"] == "parquet" }.each do |x|
        dl << {
          "label" => x["title"] || x["table"],
          "url"   => x["url"],
          "meta"  => [Fmt.bytes(x["bytes"]), x["since"] ? "since #{x['since']}" : nil].compact.join(" · "),
          "hash"  => x["sha256"]
        }
      end
      dist.select { |x| x["format"] == "netcdf" }.each do |x|
        dl << { "label" => x["title"] || "CF netCDF", "url" => x["url"],
                "meta" => Fmt.bytes(x["bytes"]), "hash" => x["sha256"], "note" => x["cf_scope"] }
      end
      erddap_current(dist).each do |x|
        ERDDAP_FORMATS.each do |ext, name|
          dl << { "label" => "#{x['id']} · #{name}", "url" => x["url"].sub(/\.html\z/, ".#{ext}"),
                  "meta" => x["grain"] }
        end
      end
      dist.select { |x| x["kind"] == "source" && x["portal"] != "edi" }.each do |x|
        dl << { "label" => x["title"] || "source download", "url" => x["url"],
                "meta" => x["portal"], "chip" => x["status"] }
      end
      groups << { "id" => "download", "title" => "Download", "rows" => dl } unless dl.empty?

      # services — the ERDDAP dataset pages, the ISO metadata, a STAC collection when one exists
      sv = []
      erddap_current(dist).each do |x|
        sv << { "label" => x["title"] || x["id"], "url" => x["url"], "meta" => x["grain"],
                "extra" => x["info_url"] ? { "label" => "info", "url" => x["info_url"] } : nil }
      end
      dist.select { |x| x["format"] == "iso19115" }.each do |x|
        sv << { "label" => x["title"] || "ISO 19115-3 metadata", "url" => x["url"], "meta" => "XML" }
      end
      dist.select { |x| x["format"] == "stac" }.each do |x|
        sv << { "label" => x["title"] || "STAC collection", "url" => x["url"], "meta" => "JSON" }
      end
      dist.select { |x| x["format"] == "erddap" && x["status"] == "superseded" }.each do |x|
        sv << { "label" => x["title"] || x["id"], "url" => x["url"], "chip" => "superseded",
                "meta" => x["superseded_by"] ? "replaced by #{x['superseded_by']}" : nil }
      end
      groups << { "id" => "services", "title" => "Services", "rows" => sv } unless sv.empty?

      # archives & portals — the registrations, then every external record of the same rows
      ar = (d["registrations"] || []).map do |r|
        { "label" => portal_name(r["portal"]), "url" => r["url"], "chip" => r["status"],
          "meta" => r["note"], "issue" => r["issue"] || (r["issues"] || []).first }
      end
      dist.select { |x| %w[mirror archive].include?(x["kind"]) || (x["kind"] == "source" && x["portal"] == "edi") }.each do |x|
        ar << { "label" => x["title"] || x["id"] || x["portal"], "url" => x["url"],
                "chip" => x["status"], "meta" => portal_name(x["portal"]), "note" => x["notes"] }
      end
      groups << { "id" => "archives", "title" => "Archives & portals", "rows" => ar } unless ar.empty?

      groups
    end

    def erddap_current(dist)
      dist.select { |x| x["format"] == "erddap" && x["status"] != "superseded" && x["url"].to_s.end_with?(".html") }
    end

    PORTAL_NAMES = {
      "erddap" => "ERDDAP (calcofi.io)", "erddap-calcofi" => "ERDDAP (calcofi.io)",
      "erddap-noaa" => "NOAA CoastWatch ERDDAP", "edi" => "EDI", "ncei" => "NCEI",
      "obis" => "OBIS", "ipt" => "OBIS-USA IPT", "caloos" => "CalOOS", "datazoo" => "DataZoo",
      "ucsd-library" => "UC San Diego Library", "zenodo" => "Zenodo", "ncbi" => "NCBI",
      "calcofi.org" => "CalCOFI.org", "gcs" => "Cloud storage", "other" => "Other"
    }.freeze
    def portal_name(p) = PORTAL_NAMES[p] || p

    # ── cite: the same wording as calcofi4r::cc_cite() ───────────────────────
    def cite_text(r)
      a = r["attribution"] || {}
      lines = []
      lines << (Fmt.present(a["citation_main"]) ||
                "#{r['dataset_name'] || r['dataset_key']} [dataset].")
      if (lic = Fmt.present(a["license"]))
        lines << (lic == "custom" && Fmt.present(a["license_url"]) ?
                  "License: #{lic} (#{a['license_url']})" : "License: #{lic}")
      end
      lines << "DOI: https://doi.org/#{a['doi']}" if Fmt.present(a["doi"])
      lines << "Acknowledgement: #{a['acknowledgement']}" if Fmt.present(a["acknowledgement"])
      lines.join("\n")
    end

    def bibtex(r)
      a = r["attribution"] || {}
      cit = Fmt.present(a["citation_main"])
      note = [
        (Fmt.present(a["license"]) ? (a["license"] == "custom" && Fmt.present(a["license_url"]) ?
          "License: #{a['license']} (#{a['license_url']})" : "License: #{a['license']}") : nil),
        (Fmt.present(a["acknowledgement"]) ? "Acknowledgement: #{a['acknowledgement']}" : nil)
      ].compact.join("; ")
      fields = {
        "title"        => r["dataset_name"] || r["dataset_key"],
        "howpublished" => cit,
        "year"         => cit&.[](/(?:18|19|20)\d{2}/),
        "doi"          => Fmt.present(a["doi"]),
        "url"          => Fmt.present(a["doi"]) ? "https://doi.org/#{a['doi']}" : nil,
        "note"         => Fmt.present(note)
      }.reject { |_, v| Fmt.blank?(v) }
      w = fields.keys.map(&:length).max
      body = fields.map { |k, v| format("  %-*s = {%s}", w, k, v) }.join(",\n")
      "@misc{#{r['dataset_key']},\n#{body}\n}"
    end

    def release_bibtex
      v = release["version"]
      fields = {
        "title"     => "CalCOFI Integrated Database, release #{v}",
        "author"    => "CalCOFI",
        "year"      => release["release_date"].to_s[0, 4],
        "publisher" => "Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife",
        "doi"       => Fmt.present(release["doi"]),
        "url"       => Fmt.present(release["doi"]) ? "https://doi.org/#{release['doi']}" : release["schema_url"]
      }.reject { |_, v2| Fmt.blank?(v2) }
      w = fields.keys.map(&:length).max
      "@misc{calcofi_release_#{v.gsub(/[^A-Za-z0-9]+/, '_')},\n" +
        fields.map { |k, val| format("  %-*s = {%s}", w, k, val) }.join(",\n") + "\n}"
    end

    # ── schema.org/Dataset (plan D-4; ODIS's checklist is @id · identifier ·
    #    includedInDataCatalog · spatialCoverage · provider) ──────────────────
    def jsonld(r)
      a    = r["attribution"] || {}
      cov  = r["coverage"] || {}
      url  = abs(page_url(r))
      node = {
        "@context" => "https://schema.org/",
        "@type"    => "Dataset",
        "@id"      => url,
        "name"     => r["dataset_name"] || r["dataset_key"],
        "alternateName" => r["dataset_key"],
        "url"      => url,
        "includedInDataCatalog" => {
          "@type" => "DataCatalog", "name" => "CalCOFI datasets", "url" => abs("/datasets/")
        }
      }
      node["description"] = plain(r["description_md"]) if Fmt.present(r["description_md"])
      node["identifier"] = if Fmt.present(a["doi"])
        ["https://doi.org/#{a['doi']}",
         { "@type" => "PropertyValue", "propertyID" => "CalCOFI dataset_key", "value" => r["dataset_key"] }]
      else
        [url, { "@type" => "PropertyValue", "propertyID" => "CalCOFI dataset_key", "value" => r["dataset_key"] }]
      end
      kw = (r["keywords"] || []) + [r.dig("category", "name")].compact + (cov["variables"] || [])
      node["keywords"] = kw.uniq unless kw.empty?
      node["license"] = Fmt.present(a["license_url"]) || Fmt.present(a["license"])
      node["citation"] = Fmt.present(a["citation_main"])
      node["creator"] = creators(r)
      node["provider"] = org(r["provider"])
      node["publisher"] = org(r["provider"])
      node["sourceOrganization"] = {
        "@type" => "Organization", "name" => "CalCOFI", "url" => "https://calcofi.org"
      }
      node["contactPoint"] = {
        "@type" => "ContactPoint", "contactType" => "dataset enquiries", "email" => contact
      }
      node["temporalCoverage"] = Fmt.present(cov["temporal"])&.sub(" to ", "/")
      if (b = cov["bbox"]) && b.values.none?(&:nil?)
        node["spatialCoverage"] = {
          "@type" => "Place",
          "geo"   => { "@type" => "GeoShape",
                       "box" => format("%.4f %.4f %.4f %.4f", b["lat_min"], b["lon_min"], b["lat_max"], b["lon_max"]) }
        }
      end
      vars = variables_measured(r)
      node["variableMeasured"] = vars unless vars.empty?
      dists = jsonld_distributions(r)
      node["distribution"] = dists unless dists.empty?
      same = same_as(r)
      node["sameAs"] = same unless same.empty?
      # Google's Rich Results Test parses this nested node as a Dataset of its own, so it needs the
      # fields a Dataset must have (description, url), not just an @id (WS-M2, 2026-09-05)
      node["isPartOf"] = { "@type" => "Dataset", "@id" => abs("/datasets/release/"),
                           "url" => abs("/datasets/release/"),
                           "name" => "CalCOFI Integrated Database, release #{release['version']}",
                           "description" => Fmt.present(release["citation"]) ||
                             "The CalCOFI Integrated Database, release #{release['version']}: every dataset in one schema, published as versioned Parquet." }.compact
      node["version"] = release["version"]
      node["dateModified"] = Fmt.present(release["release_date"])
      node["isAccessibleForFree"] = true
      node.compact
    end

    def creators(r)
      a = r["attribution"] || {}
      people = (a["creators"] || []).map do |c|
        { "@type" => "Person", "name" => c["name"], "affiliation" => c["organization"],
          "identifier" => c["orcid"] ? "https://orcid.org/#{c['orcid']}" : nil }.compact
      end
      people += (a["pi_names"] || []).map { |n| { "@type" => "Person", "name" => n } }
      people = people.uniq { |p| p["name"] }
      people.empty? ? org(r["provider"]) : people
    end

    def org(p)
      return nil if p.nil?
      { "@type" => "Organization", "name" => p["name"] || p["short"] || p["key"], "url" => p["url"] }.compact
    end

    # a variable becomes a PropertyValue; `propertyID` carries the NERC P01 URI where the record
    # has one (measurement_type.uri) and is simply absent otherwise.
    def variables_measured(r)
      (r.dig("coverage", "variables") || []).map do |v|
        v.is_a?(Hash) ?
          { "@type" => "PropertyValue", "name" => v["name"] || v["key"], "unitText" => v["units"],
            "propertyID" => v["uri"] }.compact :
          { "@type" => "PropertyValue", "name" => v }
      end
    end

    MEDIA = { "parquet" => "application/vnd.apache.parquet", "netcdf" => "application/x-netcdf",
              "csv" => "text/csv", "json" => "application/json", "iso19115" => "application/xml",
              "html" => "text/html" }.freeze

    def jsonld_distributions(r)
      out = []
      (r["distributions"] || []).each do |x|
        case x["format"]
        when "parquet", "netcdf"
          out << { "@type" => "DataDownload", "name" => x["title"], "contentUrl" => x["url"],
                   "encodingFormat" => MEDIA[x["format"]], "contentSize" => x["bytes"]&.to_s,
                   "sha256" => x["sha256"] }.compact
        when "erddap"
          next if x["status"] == "superseded"
          out << { "@type" => "DataDownload", "name" => "#{x['title'] || x['id']} (CSV)",
                   "contentUrl" => x["url"].sub(/\.html\z/, ".csv"), "encodingFormat" => "text/csv" }
          out << { "@type" => "DataDownload", "name" => "#{x['title'] || x['id']} (netCDF)",
                   "contentUrl" => x["url"].sub(/\.html\z/, ".nc"), "encodingFormat" => "application/x-netcdf" }
        when "iso19115"
          out << { "@type" => "DataDownload", "name" => x["title"], "contentUrl" => x["url"],
                   "encodingFormat" => "application/xml" }.compact
        end
      end
      out
    end

    def same_as(r)
      urls = (r["distributions"] || [])
             .select { |x| %w[mirror archive source page].include?(x["kind"]) }
             .map { |x| x["url"] }
      urls << r.dig("links", "calcofi_org")
      urls << r.dig("links", "data_source")
      (r["registrations"] || []).each { |g| urls << g["url"] if g["status"] == "published" }
      urls.compact.uniq
    end

    def release_jsonld
      {
        "@context" => "https://schema.org/",
        "@type"    => "Dataset",
        "@id"      => abs("/datasets/release/"),
        "name"     => "CalCOFI Integrated Database, release #{release['version']}",
        "url"      => abs("/datasets/release/"),
        "description" => "Every CalCOFI dataset ingested into one versioned, frozen database — " \
                         "#{release['n_tables']} tables, #{Fmt.num(release['total_rows'])} rows — " \
                         "released as Parquet with a JSON catalog and read by calcofi4r, calcofi4py, " \
                         "the browser SQL playground and every app on calcofi.io.",
        "identifier" => Fmt.present(release["doi"]) ? "https://doi.org/#{release['doi']}" : abs("/datasets/release/"),
        "version"  => release["version"],
        "dateModified" => release["release_date"],
        "citation" => release["citation"],
        "creator"   => { "@type" => "Organization", "name" => "CalCOFI", "url" => "https://calcofi.org" },
        "provider"  => { "@type" => "Organization", "name" => "CalCOFI", "url" => "https://calcofi.org" },
        "publisher" => { "@type" => "Organization", "name" => "CalCOFI", "url" => "https://calcofi.org" },
        "contactPoint" => { "@type" => "ContactPoint", "contactType" => "dataset enquiries", "email" => contact },
        "includedInDataCatalog" => { "@type" => "DataCatalog", "name" => "CalCOFI datasets", "url" => abs("/datasets/") },
        "isAccessibleForFree" => true,
        "distribution" => [
          { "@type" => "DataDownload", "name" => "release catalog (catalog.json)",
            "contentUrl" => release["catalog_url"], "encodingFormat" => "application/json" },
          { "@type" => "DataDownload", "name" => "dataset catalog (datasets.json)",
            "contentUrl" => "#{release['url']}datasets.json", "encodingFormat" => "application/json" }
        ],
        "hasPart" => datasets.map { |d| { "@type" => "Dataset", "@id" => abs(page_url(d)),
                                          "name" => d["dataset_name"] || d["dataset_key"] } }
      }.compact
    end

    # the catalog page's own node: a DataCatalog whose `dataset` names every public record
    def catalog_jsonld
      {
        "@context" => "https://schema.org/",
        "@type"    => "DataCatalog",
        "@id"      => abs("/datasets/"),
        "name"     => "CalCOFI datasets",
        "url"      => abs("/datasets/"),
        "description" => "The CalCOFI dataset catalog — one record per dataset, with every endpoint " \
                         "it can be reached through, its coverage, its licence and how to cite it.",
        "publisher" => { "@type" => "Organization", "name" => "CalCOFI", "url" => "https://calcofi.org" },
        "contactPoint" => { "@type" => "ContactPoint", "contactType" => "dataset enquiries", "email" => contact },
        "dataset" => records.map do |r|
          { "@type" => "Dataset", "@id" => abs(page_url(r)), "name" => r["dataset_name"] || r["dataset_key"] }
        end
      }
    end

    # ── DCAT-US 1.1 (Project Open Data v1.1) ─────────────────────────────────
    def data_json
      {
        "@context" => "https://project-open-data.cio.gov/v1.1/schema/catalog.jsonld",
        "@id"      => abs("/data.json"),
        "@type"    => "dcat:Catalog",
        "conformsTo" => "https://project-open-data.cio.gov/v1.1/schema",
        "describedBy" => "https://project-open-data.cio.gov/v1.1/schema/catalog.json",
        "dataset"  => [release_dcat] + records.map { |r| dcat(r) }
      }
    end

    def dcat_contact
      { "@type" => "vcard:Contact", "fn" => "CalCOFI data team", "hasEmail" => "mailto:#{contact}" }
    end

    def dcat(r)
      a   = r["attribution"] || {}
      cov = r["coverage"] || {}
      out = {
        "@type"       => "dcat:Dataset",
        "identifier"  => abs(page_url(r)),
        "title"       => r["dataset_name"] || r["dataset_key"],
        "description" => plain(r["description_md"]) || (r["dataset_name"] || r["dataset_key"]),
        "keyword"     => ((r["keywords"] || []) + [r.dig("category", "name")].compact).uniq,
        "modified"    => release["release_date"] || Time.now.utc.strftime("%Y-%m-%d"),
        "publisher"   => { "@type" => "org:Organization",
                           "name" => r.dig("provider", "name") || r.dig("provider", "short") || "CalCOFI" },
        "contactPoint" => dcat_contact,
        "accessLevel" => "public",
        "landingPage" => abs(page_url(r)),
        "theme"       => [r.dig("category", "name")].compact,
        "distribution" => dcat_distributions(r)
      }
      out["keyword"] = ["CalCOFI"] if out["keyword"].empty?
      out["license"] = Fmt.present(a["license_url"])
      out["describedBy"] = (r["distributions"] || []).find { |x| x["format"] == "iso19115" }&.dig("url")
      if (b = cov["bbox"]) && b.values.none?(&:nil?)
        out["spatial"] = format("%.4f,%.4f,%.4f,%.4f", b["lon_min"], b["lat_min"], b["lon_max"], b["lat_max"])
      end
      if cov["year_min"] && cov["year_max"]
        out["temporal"] = "#{cov['year_min']}-01-01T00:00:00Z/#{cov['year_max']}-12-31T23:59:59Z"
      end
      out.compact
    end

    def dcat_distributions(r)
      out = []
      (r["distributions"] || []).each do |x|
        next if x["status"] == "superseded"
        case x["format"]
        when "parquet"
          out << { "@type" => "dcat:Distribution", "title" => x["title"] || x["table"],
                   "downloadURL" => x["url"], "mediaType" => MEDIA["parquet"], "format" => "Parquet" }
        when "netcdf"
          out << { "@type" => "dcat:Distribution", "title" => x["title"] || "CF netCDF",
                   "downloadURL" => x["url"], "mediaType" => MEDIA["netcdf"], "format" => "netCDF" }
        when "erddap"
          out << { "@type" => "dcat:Distribution", "title" => "#{x['title'] || x['id']} (CSV)",
                   "downloadURL" => x["url"].sub(/\.html\z/, ".csv"), "mediaType" => "text/csv", "format" => "CSV" }
          out << { "@type" => "dcat:Distribution", "title" => x["title"] || x["id"],
                   "accessURL" => x["url"], "mediaType" => "text/html", "format" => "ERDDAP" }
        when "iso19115"
          out << { "@type" => "dcat:Distribution", "title" => x["title"] || "ISO 19115-3 metadata",
                   "accessURL" => x["url"], "mediaType" => "application/xml", "format" => "ISO-19115" }
        else
          next unless %w[mirror archive source page].include?(x["kind"])
          out << { "@type" => "dcat:Distribution", "title" => x["title"] || x["portal"],
                   "accessURL" => x["url"], "mediaType" => "text/html" }
        end
      end
      out << { "@type" => "dcat:Distribution", "title" => "dataset page",
               "accessURL" => abs(page_url(r)), "mediaType" => "text/html" } if out.empty?
      out
    end

    def release_dcat
      {
        "@type"       => "dcat:Dataset",
        "identifier"  => abs("/datasets/release/"),
        "title"       => "CalCOFI Integrated Database, release #{release['version']}",
        "description" => "The versioned, frozen CalCOFI integrated database — #{release['n_tables']} " \
                         "tables, #{Fmt.num(release['total_rows'])} rows — assembled from every ingested " \
                         "dataset and published as Parquet with a JSON catalog.",
        "keyword"     => ["CalCOFI", "California Current", "ocean observing", "integrated database"],
        "modified"    => release["release_date"] || Time.now.utc.strftime("%Y-%m-%d"),
        "publisher"   => { "@type" => "org:Organization", "name" => "CalCOFI" },
        "contactPoint" => dcat_contact,
        "accessLevel" => "public",
        "landingPage" => abs("/datasets/release/"),
        "distribution" => [
          { "@type" => "dcat:Distribution", "title" => "release catalog (catalog.json)",
            "downloadURL" => release["catalog_url"], "mediaType" => "application/json", "format" => "JSON" },
          { "@type" => "dcat:Distribution", "title" => "dataset catalog (datasets.json)",
            "downloadURL" => "#{release['url']}datasets.json", "mediaType" => "application/json", "format" => "JSON" }
        ]
      }.compact
    end

    # ── search.json: names · descriptions · variables · taxa, one row per record ──
    def search_rows(taxa_by_key)
      records.map do |r|
        cov = r["coverage"] || {}
        {
          "key"   => r["dataset_key"],
          "name"  => r["dataset_name"] || r["dataset_key"],
          "short" => r["dataset_name_short"],
          "cat"   => r.dig("category", "name"),
          "realm" => cov["realm"] || r.dig("category", "realm"),
          "prov"  => r.dig("provider", "short") || r.dig("provider", "key"),
          "lic"   => r.dig("attribution", "license"),
          "fmt"   => holding?(r) ? [] : formats(r),
          "stage" => r.dig("status", "stage"),
          "url"   => page_url(r),
          "text"  => [
            r["dataset_name"], r["dataset_name_short"], r["dataset_key"],
            plain(r["description_md"]), (r["keywords"] || []).join(" "),
            (cov["variables"] || []).map { |v| v.is_a?(Hash) ? v["name"] : v }.join(" "),
            (taxa_by_key[r["dataset_key"]] || []).join(" ")
          ].compact.join(" ").downcase
        }.compact
      end
    end

    # markdown → one line of plain text, for a `description` field that must not carry markup
    def plain(md)
      return nil if Fmt.blank?(md)
      md.to_s.gsub(/\[([^\]]+)\]\([^)]+\)/, '\1').gsub(/[*_`#>]/, "").gsub(/\s+/, " ").strip
    end
  end

  # ── the generator ──────────────────────────────────────────────────────────
  class DatasetCatalog < Jekyll::Generator
    safe false
    priority :high

    def generate(site)
      rec = site.data["datasets"]
      if rec.nil? || rec["datasets"].nil?
        raise Jekyll::Errors::FatalException,
              "_data/datasets.json is missing or unreadable — run scripts/fetch_release.sh " \
              "(or scripts/build.sh, which does both) before jekyll build."
      end
      unless rec["schema_version"] == "1.0"
        Jekyll.logger.warn "datasets:", "record schema #{rec['schema_version'].inspect}, expected \"1.0\""
      end

      rec = deep_unescape(rec)
      cat = Catalog.new(site, rec, read_grid(site))
      cat.products_by_dataset # validate products.yml before anything is written

      site.data["catalog"] = {
        "release"    => cat.release,
        "counts"     => { "datasets" => cat.datasets.size, "holdings" => cat.holdings.size,
                          "reference" => cat.reference.size },
        "categories" => cat.categories,
        "reference"  => cat.reference_tile,
        "facets"     => cat.facets,
        "jsonld"     => JSON.pretty_generate(cat.catalog_jsonld),
        # key → {name, url}: what a product card's `datasets:` chips resolve through
        "index"      => cat.records.to_h do |r|
          [r["dataset_key"],
           { "name" => r["dataset_name_short"] || r["dataset_name"] || r["dataset_key"],
             "url"  => cat.page_url(r) }]
        end,
        "versions"   => (site.data.dig("versions", "versions") || []),
        "contact"    => cat.contact
      }

      pages = []
      cat.records.each do |r|
        pages.concat(record_pages(site, cat, r))
      end
      pages << release_page(site, cat)
      pages << json_page(site, "/datasets/", "sitemap.xml", sitemap(site, cat))
      pages << json_page(site, "/datasets/", "search.json", JSON.pretty_generate(search(site, cat)))
      pages << json_page(site, "/", "data.json", JSON.pretty_generate(cat.data_json))
      site.pages.concat(pages)

      Jekyll.logger.info "datasets:",
                         "#{cat.datasets.size} datasets · #{cat.holdings.size} holdings · " \
                         "#{cat.reference.size} reference rows from #{cat.release['version']}"
    end

    # Some ERDDAP titles reach the record with a literal "—" instead of the em dash it encodes
    # (escaped once too often upstream — reported to WS-R0). Resolving the escape everywhere is the
    # only change this site makes to the record; when R0 fixes it this walk becomes a no-op.
    def deep_unescape(v)
      case v
      when Hash  then v.transform_values { |x| deep_unescape(x) }
      when Array then v.map { |x| deep_unescape(x) }
      when String then Fmt.unesc(v)
      else v
      end
    end

    # the station grid as [[lon, lat], …] — the bbox map's backdrop, read once
    def read_grid(site)
      path = File.join(site.source, "_data", "grid.geojson")
      return [] unless File.exist?(path)
      JSON.parse(File.read(path))["features"].filter_map do |f|
        p = f["properties"]
        [p["lon_ctr"], p["lat_ctr"]] if p["lon_ctr"] && p["lat_ctr"]
      end
    rescue StandardError => e
      Jekyll.logger.warn "datasets:", "could not read _data/grid.geojson (#{e.message})"
      []
    end

    def record_pages(site, cat, r)
      key = r["dataset_key"]
      is_holding = cat.holding?(r)
      cov = r["coverage"] || {}
      jsonld = cat.jsonld(r)

      page = Jekyll::PageWithoutAFile.new(site, site.source, "datasets/#{key}", "index.html")
      page.content = ""
      page.data.merge!(
        "layout"      => "dataset",
        "title"       => "#{r['dataset_name'] || key} · CalCOFI datasets",
        "description" => cat.plain(r["description_md"]) || "CalCOFI dataset #{key}",
        "record"      => r,
        "dataset_key" => key,
        "is_holding"  => is_holding,
        "icon"        => cat.icon_for(r.dig("category", "icon")),
        "years_bar"   => cat.years_bar(cov["years"], cov["year_min"], cov["year_max"]),
        "years_span"  => cat.year_span(cov),
        "bbox_svg"    => cat.bbox_svg(cov["bbox"]),
        "access"      => is_holding ? [] : cat.access_groups(r),
        "formats"     => is_holding ? [] : cat.formats(r),
        "cite_text"   => cat.cite_text(r),
        "bibtex"      => cat.bibtex(r),
        "release_cite" => cat.release["citation"],
        "release_bibtex" => cat.release_bibtex,
        "jsonld"      => JSON.pretty_generate(jsonld),
        "related"     => related(cat, r),
        "n_obs_fmt"   => Fmt.num(cov["n_obs"]),
        "n_roots_fmt" => Fmt.num(cov["n_roots"]),
        "objects"     => (r["objects"] || []).map { |o| o.merge("bytes_fmt" => Fmt.bytes(o["bytes"])) }
      )
      [page,
       json_page(site, "/datasets/", "#{key}.json", JSON.pretty_generate(r)),
       json_page(site, "/datasets/", "#{key}.jsonld", JSON.pretty_generate(jsonld))]
    end

    def related(cat, r)
      cname = r.dig("category", "name")
      same_cat = cat.records.reject { |o| o["dataset_key"] == r["dataset_key"] }
                    .select { |o| o.dig("category", "name") == cname }
                    .map { |o| { "key" => o["dataset_key"], "name" => o["dataset_name_short"] || o["dataset_name"],
                                 "url" => cat.page_url(o) } }
      tables = r["tables"] || []
      shared = tables.empty? ? [] :
        cat.datasets.reject { |o| o["dataset_key"] == r["dataset_key"] }
           .filter_map do |o|
             common = ((o["tables"] || []) & tables) - %w[cruise ship lookup grid taxon]
             next if common.size < 2
             { "key" => o["dataset_key"], "name" => o["dataset_name_short"] || o["dataset_name"],
               "url" => cat.page_url(o), "tables" => common }
           end
      { "category" => same_cat, "tables" => shared.first(8), "category_name" => cname }
    end

    def release_page(site, cat)
      page = Jekyll::PageWithoutAFile.new(site, site.source, "datasets/release", "index.html")
      page.content = ""
      page.data.merge!(
        "layout" => "release",
        "title"  => "CalCOFI Integrated Database #{cat.release['version']} · CalCOFI datasets",
        "description" => "The versioned, frozen CalCOFI integrated database — every ingested dataset " \
                         "in one release, as Parquet with a JSON catalog.",
        "jsonld" => JSON.pretty_generate(cat.release_jsonld),
        "release_bibtex" => cat.release_bibtex,
        "rows_fmt" => Fmt.num(cat.release["total_rows"]),
        "size_fmt" => Fmt.bytes(cat.release["total_size"]),
        "parts"    => cat.datasets.map { |d| cat.tile_row(d) }
      )
      page
    end

    def sitemap(site, cat)
      lastmod = cat.release["release_date"] || Time.now.utc.strftime("%Y-%m-%d")
      urls = [cat.abs("/datasets/"), cat.abs("/datasets/release/")] +
             cat.records.map { |r| cat.abs(cat.page_url(r)) }
      body = urls.map do |u|
        "  <url><loc>#{u}</loc><lastmod>#{lastmod}</lastmod><changefreq>monthly</changefreq></url>"
      end.join("\n")
      %(<?xml version="1.0" encoding="UTF-8"?>\n) +
        %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n#{body}\n</urlset>\n)
    end

    # taxa for the search index: the record carries n_taxa, not the names, so search covers the
    # taxon words that ARE in the record (names, descriptions, keywords, variables). A taxon-name
    # index needs `coverage.taxa[]` — see the hand-back's request to R0.
    def search(site, cat)
      { "release" => cat.release["version"], "rows" => cat.search_rows({}) }
    end

    def json_page(site, dir, name, body)
      page = Jekyll::PageWithoutAFile.new(site, site.source, dir.sub(%r{\A/}, "").sub(%r{/\z}, ""), name)
      # Liquid runs on every page; `raw` hands the payload through untouched
      page.content = "{% raw %}#{body}{% endraw %}"
      page.data["layout"] = nil
      page.data["sitemap"] = false
      page
    end
  end
end
