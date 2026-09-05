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
require "cgi"
require_relative "derive_id"

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
    attr_reader :rec, :site, :grid, :land, :coverage_stations

    ERDDAP_FORMATS = [%w[csv CSV], %w[nc netCDF], %w[json JSON]].freeze

    def initialize(site, rec, grid, land = [], coverage = {})
      @site = site
      @rec  = rec
      @grid = grid
      @land = land
      @coverage_stations = coverage
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
              "section_id" => p["section"],
              # the ONE place a product-to-dataset link is written (plan Decision 10)
              "dataset_url" => p["dataset_url"]
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
            # the tile's one-line lede. The record carries it from schema 1.1 (category.csv already
            # has the column, plan D-9); until a release does, this is nil and the tile draws no
            # lede — a category description is a fact, so it is never typed into this site.
            "description" => Fmt.present(c["description"]),
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
            vars = ct["variables"] || []
            c["contributions"] << {
              "key"       => d["dataset_key"],
              "name"      => d["dataset_name_short"] || d["dataset_name"] || d["dataset_key"],
              "home"      => d.dig("category", "name"),
              "url"       => page_url(d),
              "color"     => dot_color(d),
              "n"         => vars.size,
              "variables" => vars
            }
          end
        end

        list = cats.values.sort_by { |c| [c["order"] || 999, c["name"]] }
        list.each do |c|
          c["datasets"].sort_by! { |t| t["name"].to_s.downcase }
          c["contributions"].sort_by! { |t| t["name"].to_s.downcase }
          c["holdings"].sort_by! { |t| t["name"].to_s.downcase }
          c["holdings_shown"] = c["holdings"].first(HOLDINGS_SHOWN)
          c["holdings_more"]  = c["holdings"].drop(HOLDINGS_SHOWN)
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

    # The reference frame is not a category of datasets and it is the tile that doubled the grid's
    # height (25 rows against a median of 3), so it leaves the grid and becomes a full-width band
    # under it — three columns: the tables, the layers by group, the bathymetry (plan D-2,
    # Decision 2). Groups keep the record's own order of first appearance.
    def reference_band
      @reference_band ||= begin
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
            "attribution" => r["attribution"],
            # the raster's downloadable artefacts; the old tile's template looped over these but the
            # row never carried them, so the bathymetry row drew no links at all
            "objects" => r["objects"] || []
          }
        end
        layers = rows.select { |r| r["kind"] == "layer" }
        groups = layers.map { |l| l["group"] }.uniq.map do |g|
          { "name" => g, "rows" => layers.select { |l| l["group"] == g } }
        end
        {
          "name"  => "Cruises, stations & spatial",
          "realm" => "ref",
          "icon"  => "lens-stations",
          "n"     => rows.size,
          "tables" => rows.select { |r| r["kind"] == "table" },
          "layers" => layers,
          "layer_groups" => groups,
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

    # ── coverage.variables[], one shape ──────────────────────────────────────
    # The record carries variables as bare strings in schema 1.0 and as
    # {name, units, uri, category} objects from the next release (calcofi4db main b4eb5062).
    # Everything on this site reads them through here, so the shape change is one method wide
    # rather than one `is_a?(Hash)` per template.
    def normalize_variables(cov)
      (cov && cov["variables"] || []).map do |v|
        if v.is_a?(Hash)
          { "name" => v["name"] || v["key"], "units" => Fmt.present(v["units"]),
            "uri" => Fmt.present(v["uri"]), "category" => Fmt.present(v["category"]) }
        else
          { "name" => v.to_s, "units" => nil, "uri" => nil, "category" => nil }
        end
      end.reject { |v| Fmt.blank?(v["name"]) }
    end

    def variable_names(cov) = normalize_variables(cov).map { |v| v["name"] }

    # rung 1 and 2 of the emphasis ladder carry the dataset's own colour as a 9 px dot — the one
    # visual the Explorer, the Station Explorer and this catalog share. Never as text colour
    # (plan Decision 4); a record with no colour falls back to the accent in CSS.
    def dot_color(d) = Fmt.present(d["color"])

    # the format chips were three chips and a wrap; D-1 makes them one mono phrase
    def formats_phrase(d)
      f = formats(d)
      f.empty? ? nil : f.join(" · ")
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
        "formats_phrase" => formats_phrase(d),
        "color"      => dot_color(d),
        "n_variables" => cov["n_variables"] || normalize_variables(cov).size,
        "stage"      => d.dig("status", "stage"),
        "years_bar"  => years_bar(cov["years"], cov["year_min"], cov["year_max"])
      }
    end

    def holding_row(h)
      {
        "key"       => h["dataset_key"],
        "name"      => h["dataset_name_short"] || h["dataset_name"] || h["dataset_key"],
        "name_full" => h["dataset_name"],
        "url"       => page_url(h),
        "provider"  => h.dig("provider", "short") || h.dig("provider", "key"),
        "stage"     => h.dig("status", "stage"),
        "link"      => h.dig("links", "data_source")
      }
    end

    # rung 3: at most four holdings are drawn before "and n more" (plan D-3, Decision 3). The rest
    # stay in the DOM inside the <details>, so the search box still matches them.
    HOLDINGS_SHOWN = 4

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

    # ── the extent map: where the dataset actually is, over a coast ──────────
    # A static inline SVG drawn here at build time — no library, no tile server, no external asset,
    # every colour a brand token so the theme toggle repaints it (plan D-5, Decisions 5–7).
    #
    # THE FRAME RULE. Not the record's bbox: the standard + extended grid UNION the cells this
    # dataset sampled, padded 6 %. The bbox lies for the ichthyoplankton (0–54° N, 180–77° W from
    # bad upstream coordinates), and the historical lines run to 48° N whether or not a dataset ever
    # sampled them, so framing on either alone draws the wrong ocean. The record's bbox is still
    # drawn — clipped to the frame, dashed, with a corner note when it continues beyond.
    #
    # Projection: equirectangular with a cos(mean latitude) correction on longitude, as bbox_svg
    # used. Width is 360; height follows the frame's aspect.
    MAP_W = 360.0

    def map_svg(r)
      cells = grid
      return nil if cells.empty?
      key     = r && r["dataset_key"]
      sampled = key ? (coverage_stations[key] || {}) : {}

      core = cells.select { |c| %w[standard extended].include?(c["pattern"]) || sampled.key?(c["key"]) }
      core = cells if core.empty?
      x0, x1 = core.map { |c| c["lon"] }.minmax
      y0, y1 = core.map { |c| c["lat"] }.minmax
      padx = [(x1 - x0) * 0.06, 0.4].max
      pady = [(y1 - y0) * 0.06, 0.4].max
      x0 -= padx; x1 += padx; y0 -= pady; y1 += pady

      k  = Math.cos((y0 + y1) / 2 * Math::PI / 180)
      wl = (x1 - x0) * k
      hl = (y1 - y0)
      w  = MAP_W
      h  = (w * hl / wl).round
      px = ->(lon) { (lon - x0) * k / wl * w }
      py = ->(lat) { (y1 - lat) / hl * h }

      out = +%(<rect class="water" width="#{w.to_i}" height="#{h}"/>)

      # the coast, clipped to this frame at draw time (the asset is clipped to the whole region)
      d = land.filter_map do |ring|
        c = clip_ring(ring, x0, x1, y0, y1)
        next if c.size < 3
        "M" + c.map { |lon, lat| format("%.1f %.1f", px.(lon), py.(lat)) }.join(" L") + " Z"
      end.join(" ")
      out << %(<path class="land" d="#{d}"/>) unless d.empty?

      # every cell in frame hollow; the ones this dataset sampled filled, radius proportional to
      # the square root of its observations, and only those carry a <title> — the hovers on 218
      # unsampled cells were two thirds of the file
      max = sampled.values.max || 1
      dots = +""
      cells.each do |c|
        next unless c["lon"].between?(x0, x1) && c["lat"].between?(y0, y1)
        cx = format("%.1f", px.(c["lon"]))
        cy = format("%.1f", py.(c["lat"]))
        if (n = sampled[c["key"]])
          rr = 1.6 + 4.4 * Math.sqrt(n.to_f / max)
          dots << format('<circle class="st st-on" cx="%s" cy="%s" r="%.1f"><title>%s · %s obs</title></circle>',
                         cx, cy, rr, c["key"], Fmt.num(n))
        else
          dots << %(<circle class="st" cx="#{cx}" cy="#{cy}" r="1.3"/>)
        end
      end
      out << %(<g class="stations">#{dots}</g>)

      beyond = false
      if (b = r && r.dig("coverage", "bbox")) && b.values.none?(&:nil?)
        beyond = b["lon_min"] < x0 || b["lon_max"] > x1 || b["lat_min"] < y0 || b["lat_max"] > y1
        bx  = px.([b["lon_min"], x0].max)
        bw  = px.([b["lon_max"], x1].min) - bx
        byy = py.([b["lat_max"], y1].min)
        bh  = py.([b["lat_min"], y0].max) - byy
        out << format('<rect class="bbox" x="%.1f" y="%.1f" width="%.1f" height="%.1f"/>',
                      bx, byy, [bw, 0].max, [bh, 0].max) if bw > 0 && bh > 0
      end

      # a 5° graticule as edge ticks, so the map says where it is without a legend
      ticks = +""
      (-180..180).step(5) do |lon|
        next unless lon > x0 && lon < x1
        ticks << format('<text class="tk" x="%.1f" y="%.1f" text-anchor="middle">%d°W</text>',
                        px.(lon), h - 3.0, lon.abs)
      end
      (-90..90).step(5) do |lat|
        next unless lat > y0 && lat < y1
        ticks << format('<text class="tk" x="4" y="%.1f">%d°N</text>', py.(lat) + 3.5, lat)
      end
      ticks << %(<text class="tk" x="#{(w - 4).to_i}" y="12" text-anchor="end">extent continues beyond the frame</text>) if beyond
      out << %(<g class="ticks">#{ticks}</g>)

      label = if key
        "#{sampled.size} CalCOFI station#{'s' unless sampled.size == 1} sampled by this dataset, " \
        "over the survey grid and the coastline"
      else
        "The CalCOFI station grid over the coastline"
      end
      {
        "svg" => %(<svg class="cc-map" viewBox="0 0 #{w.to_i} #{h}" preserveAspectRatio="xMaxYMin meet" ) +
                 %(role="img" aria-label="#{label}">#{out}</svg>),
        "w" => w.to_i, "h" => h, "aspect" => format("%d / %d", w.to_i, h),
        "n_stations" => sampled.size, "beyond" => beyond,
        "frame" => format("%.1f…%.1f°, %.1f…%.1f°", x0, x1, y0, y1)
      }
    end

    # Sutherland–Hodgman against the frame rectangle — the same clip build_land.py applies once to
    # the whole region, applied again per map because each dataset frames differently
    def clip_ring(ring, x0, x1, y0, y1)
      poly = ring
      [[0, x0, :>=], [0, x1, :<=], [1, y0, :>=], [1, y1, :<=]].each do |axis, val, cmp|
        return [] if poly.empty?
        inside = ->(p) { p[axis].send(cmp, val) }
        out = []
        poly.each_with_index do |p, i|
          q = poly[i - 1]
          if inside.(p)
            out << intersect(q, p, axis, val) unless inside.(q)
            out << p
          elsif inside.(q)
            out << intersect(q, p, axis, val)
          end
        end
        poly = out
      end
      poly
    end

    def intersect(a, b, axis, val)
      return a if (b[axis] - a[axis]).abs < 1e-12
      t = (val - a[axis]) / (b[axis] - a[axis])
      axis.zero? ? [val, a[1] + t * (b[1] - a[1])] : [a[0] + t * (b[0] - a[0]), val]
    end

    # ── Access: full-width rows, one listing per source, the URL always in view ──
    # Six groups (plan D-6, Decisions 8, 9, 18, 19). What changed from the first cut:
    #   · a row is TWO LINES that span the page — label + chips + meta, then the URL on its own
    #     line, middle-elided. URLs in a right-hand table column wrapped to five lines on a phone.
    #   · Download and Services merged into "Get the data", so ERDDAP is listed ONCE, as a matrix
    #     of id x (CSV · netCDF · JSON · page · info · graph). It used to appear in both.
    #   · "Metadata records" is records ABOUT the data, kept apart from the data.
    #   · Archives & portals lists the portal's own identifier, not just the portal's name.
    #
    # Row keys the includes read: label · label_url · chips[] · meta · url · hash · code ·
    # note (+ note_summary) · issue · ident.
    def access_groups(d)
      key    = d["dataset_key"]
      dist   = d["distributions"] || []
      tables = d["tables"] || []
      groups = []

      # ── Explore ──────────────────────────────────────────────────────────────
      # Which app opens on THIS dataset and which merely opens is the first thing a reader wants,
      # so it is a chip, and the deep link comes from the product's own `dataset_url:` template in
      # products.yml — the one place a product-to-dataset link is written (Decision 10).
      rows = products_by_dataset[key]
             .select { |p| %w[explore students].include?(p["section_id"]) }
             .map do |p|
        tmpl = p["dataset_url"]
        deep = Fmt.present(tmpl)
        { "label" => p["title"], "label_url" => deep ? tmpl.gsub("{key}", key) : p["url"],
          "url"   => deep ? tmpl.gsub("{key}", key) : p["url"],
          "chips" => [deep ?
            { "text" => "this dataset", "class" => "cc-chip-accent",
              "title" => "the link opens the app with this dataset already selected" } :
            { "text" => "the app", "class" => "cc-chip-quiet",
              "title" => "this app has no dataset parameter yet — it opens at its own start" }],
          "meta"  => p["section_id"] == "students" ? "student contribution" : p["group"] }
      end
      groups << { "id" => "explore", "title" => "Explore",
                  "lede" => "Apps that read this dataset from the release. A row marked " \
                            "“this dataset” opens with it already selected.",
                  "blocks" => [{ "rows" => rows }] } unless rows.empty?

      # ── Query ────────────────────────────────────────────────────────────────
      # A saved query where db-query has one; otherwise the SQL shell with this dataset's SQL
      # already in the box (?sql=, UI-E). The table is the first of the dataset's own tables that
      # carries dataset_key — `obs`, else `sample`: `FROM obs` was simply wrong for the datasets
      # whose only table is `sample`.
      unless tables.empty?
        tbl = %w[obs sample].find { |t| tables.include?(t) } || tables.first
        sql = "-- #{key} in the CalCOFI release #{release['version']}\n" \
              "SELECT *\nFROM __TBL:#{tbl}__\nWHERE dataset_key = '#{key}'\nLIMIT 100;"
        saved = SAVED_QUERIES[key]
        rows = if saved
          [{ "label" => "db-query — the saved query for this dataset",
             "label_url" => "https://calcofi.io/db-query/##{saved}",
             "url" => "https://calcofi.io/db-query/##{saved}",
             "meta" => "DuckDB-WASM over the released parquet, in your browser" }]
        else
          [{ "label" => "db-query — the SQL shell, prefilled",
             "label_url" => query_shell_url(sql),
             "url" => query_shell_url(sql),
             "meta" => "DuckDB-WASM over the released parquet, in your browser",
             "code" => sql }]
        end
        groups << { "id" => "query", "title" => "Query",
                    "lede" => "SQL against the release itself, in the browser — nothing to install " \
                              "and nothing downloaded until a query asks for it. `__TBL:#{tbl}__` " \
                              "resolves to the pinned release’s parquet.",
                    "blocks" => [{ "rows" => rows }] }
      end

      # ── Code ─────────────────────────────────────────────────────────────────
      obj = (d["objects"] || []).find { |o| o["url"] } || dist.find { |x| x["format"] == "parquet" }
      code_rows = [
        { "label" => "R · calcofi4r", "label_url" => "https://calcofi.io/calcofi4r/",
          "code" => "con <- calcofi4r::cc_get_db()\ncalcofi4r::cc_cite(\"#{key}\")" },
        { "label" => "Python · calcofi4py", "label_url" => "https://calcofi.io/calcofi4py/",
          "code" => "con = calcofi4py.cc_get_db()\ncalcofi4py.cite(\"#{key}\")" }
      ]
      if obj && obj["url"]
        code_rows << { "label" => "DuckDB, anywhere",
                       "meta" => "no CalCOFI package needed — the object is a plain parquet file",
                       "code" => "SELECT * FROM read_parquet('#{obj['url']}') LIMIT 100;" }
      end
      groups << { "id" => "code", "title" => "Code",
                  "lede" => "The same release, from a script.",
                  "blocks" => [{ "rows" => code_rows }] }

      # ── Get the data ─────────────────────────────────────────────────────────
      blocks = []

      objs = (d["objects"] || []).map do |o|
        shared = o["shared"] || o["scope"] == "table"
        { "label" => o["table"],
          "label_url" => o["url"],
          "url"   => o["url"],
          "meta"  => [shared ? "whole table, shared with every dataset in it" : "this dataset’s rows",
                      Fmt.bytes(o["bytes"]),
                      o["since"] ? "since #{o['since']}" : nil,
                      Fmt.present(o["table_description"])].compact.join(" · "),
          "hash"  => o["sha256"] }
      end
      if objs.empty?
        objs = dist.select { |x| x["format"] == "parquet" }.map do |x|
          { "label" => x["table"] || x["title"], "label_url" => x["url"], "url" => x["url"],
            "meta" => [Fmt.bytes(x["bytes"]), x["since"] ? "since #{x['since']}" : nil].compact.join(" · "),
            "hash" => x["sha256"] }
        end
      end
      blocks << { "title" => "Files from the release (Parquet)",
                  "lede" => "The frozen objects this release is made of. A partition holds only " \
                            "this dataset’s rows; a shared table holds every dataset’s, so filter " \
                            "on `dataset_key`.",
                  "rows" => objs } unless objs.empty?

      nc = dist.select { |x| x["format"] == "netcdf" }.map do |x|
        { "label" => Fmt.present(x["title"]) || "CF netCDF",
          "label_url" => x["url"], "url" => x["url"],
          "meta" => Fmt.bytes(x["bytes"]), "hash" => x["sha256"],
          "note" => Fmt.present(x["cf_scope"]), "note_summary" => "how far this file is CF" }
      end
      blocks << { "title" => "CF netCDF",
                  "lede" => "One self-describing file, for a tool that reads netCDF.",
                  "rows" => nc } unless nc.empty?

      # THE one ERDDAP listing: a matrix, so the format links and the service links live together
      cur = erddap_current(dist)
      unless cur.empty?
        matrix = cur.map do |x|
          base = x["url"].sub(/\.html\z/, "")
          { "id" => x["id"], "grain" => x["grain"], "title" => Fmt.present(x["title"]),
            "page" => x["url"], "info" => x["info_url"], "graph" => "#{base}.graph",
            "formats" => ERDDAP_FORMATS.map { |ext, name| { "name" => name, "url" => "#{base}.#{ext}" } } }
        end
        grains = cur.map { |x| x["grain"] }.compact.uniq
        gloss = grains.map do |g|
          # `grain_description` arrives with calcofi4db 4.5.0 / schema 1.1 (plan D-9)
          desc = cur.find { |x| x["grain"] == g && Fmt.present(x["grain_description"]) }&.dig("grain_description")
          { "grain" => g, "desc" => desc || GRAIN_FALLBACK[g] }
        end.select { |g| g["desc"] }
        legacy = dist.select { |x| erddap_row?(x) && x["status"] == "superseded" }.map do |x|
          { "id" => x["id"], "url" => x["url"],
            "note" => x["superseded_by"] ? "replaced by #{x['superseded_by']}" : "superseded",
            "sunset" => ERDDAP_SUNSET }
        end
        blocks << { "title" => "ERDDAP (erddap.calcofi.io)",
                    "lede" => "One ERDDAP dataset per grain, each with its own data formats and " \
                              "its own pages. Subset in the browser or query it from a script.",
                    "matrix" => matrix, "gloss" => gloss, "legacy" => legacy }
      end

      src = dist.select { |x| x["kind"] == "source" && x["portal"] != "edi" }.map do |x|
        { "label" => Fmt.present(x["title"]) || "source download",
          "label_url" => x["url"], "url" => x["url"],
          "meta" => portal_name(x["portal"]),
          "chips" => [status_chip(x["status"])].compact }
      end
      blocks << { "title" => "From the provider",
                  "lede" => "The dataset as its provider publishes it, before CalCOFI ingested it.",
                  "rows" => src } unless src.empty?

      groups << { "id" => "data", "title" => "Get the data",
                  "lede" => "Every way to have the bytes, by source. Nothing here asks you to " \
                            "register first.",
                  "blocks" => blocks } unless blocks.empty?

      # ── Metadata records ─────────────────────────────────────────────────────
      # Records ABOUT the data, kept apart from the data (Decision 19: Services dissolves here).
      meta_rows = []
      dist.select { |x| x["format"] == "iso19115" }.each do |x|
        meta_rows << { "label" => "ISO 19115-3", "label_url" => x["url"], "url" => x["url"],
                       "meta" => "XML, from the ERDDAP WAF" }
      end
      if (primary = (cur || []).find { |x| x["id"] == key } || cur&.first)
        fgdc = "https://erddap.calcofi.io/erddap/metadata/fgdc/xml/#{primary['id']}_fgdc.xml"
        meta_rows << { "label" => "FGDC CSDGM", "label_url" => fgdc, "url" => fgdc, "meta" => "XML" }
      end
      meta_rows << { "label" => "JSON-LD (schema.org/Dataset)",
                     "label_url" => abs("/datasets/#{key}.jsonld"), "url" => abs("/datasets/#{key}.jsonld"),
                     "meta" => "what this page publishes to Google Dataset Search" }
      meta_rows << { "label" => "the record, verbatim",
                     "label_url" => abs("/datasets/#{key}.json"), "url" => abs("/datasets/#{key}.json"),
                     "meta" => "the release’s own entry for this dataset — everything on this page comes from it" }
      meta_rows << { "label" => "DCAT-US 1.1", "label_url" => abs("/data.json"), "url" => abs("/data.json"),
                     "meta" => "the whole catalog, for data.gov and any CKAN" }
      stac = dist.find { |x| x["format"] == "stac" }
      stac_url = stac ? stac["url"] : stac_collection_url(key)
      meta_rows << { "label" => "STAC collection", "label_url" => stac_url, "url" => stac_url,
                     "meta" => "one Collection per dataset, an Item per release" } if stac_url
      groups << { "id" => "metadata", "title" => "Metadata records",
                  "lede" => "Records about the data, in the standards each portal harvests.",
                  "blocks" => [{ "rows" => meta_rows }] }

      # ── Archives & portals ───────────────────────────────────────────────────
      # Portal · identifier · title · status. The identifier is the thing a person needs; the
      # record carries it on distributions[] and, from calcofi4db 4.5.0, on registrations[] too.
      ar = (d["registrations"] || []).map do |g|
        ident = Fmt.present(g["id"]) || DeriveId.call(g["url"])
        issue = Fmt.present(g["issue"]) || (g["issues"] || []).first
        { "label" => portal_name(g["portal"]), "label_url" => Fmt.present(g["url"]),
          "label_title" => PORTAL_ABOUT[g["portal"]],
          "ident" => ident, "title_text" => Fmt.present(g["title"]),
          "chips" => [status_chip(g["status"])].compact,
          "meta"  => Fmt.present(g["note"]), "issue" => issue,
          "url"   => Fmt.present(g["url"]) }
      end
      dist.select { |x| %w[mirror archive].include?(x["kind"]) ||
                        (x["kind"] == "source" && x["portal"] == "edi") }.each do |x|
        ar << { "label" => portal_name(x["portal"]), "label_url" => x["url"],
                "label_title" => PORTAL_ABOUT[x["portal"]],
                "ident" => Fmt.present(x["id"]) || DeriveId.call(x["url"]),
                "title_text" => Fmt.present(x["title"]),
                "chips" => [status_chip(x["status"])].compact,
                "meta" => Fmt.present(x["notes"]), "url" => x["url"] }
      end
      groups << { "id" => "archives", "title" => "Archives & portals",
                  "lede" => "Where this dataset is registered outside calcofi.io, by the " \
                            "identifier each portal knows it as.",
                  "blocks" => [{ "rows" => ar }] } unless ar.empty?

      groups.each { |g| (g["blocks"] || []).each { |b| (b["rows"] || []).each { |row| split_row_url(row) } } }
    end

    def split_row_url(row)
      return row unless (u = Fmt.present(row["url"]))
      row["url_head"], row["url_tail"] = split_url(u)
      row
    end

    # ── nothing lost in the regrouping ──────────────────────────────────────
    # The Access model was rewritten from six flat groups into six grouped ones, and the one way
    # that goes wrong is silently: a distribution whose shape no selector matches simply stops
    # being on the page. (It happened: the two legacy ERDDAP ids carry no `format` key.) So the
    # generator checks its own output — every URL in the record's distributions[] and
    # registrations[] must appear somewhere in the rendered groups.
    def unlisted_endpoints(r, groups)
      shown = []
      groups.each do |g|
        (g["blocks"] || []).each do |b|
          (b["rows"] || []).each { |row| shown << row["url"] << row["label_url"] }
          (b["matrix"] || []).each do |m|
            shown << m["page"] << m["info"] << m["graph"]
            (m["formats"] || []).each { |f| shown << f["url"] }
          end
          (b["legacy"] || []).each { |l| shown << l["url"] }
        end
      end
      shown = shown.compact.map { |u| u.sub(/\.\w+\z/, "") }.uniq
      # `notebook` and `page` are context, not access: the ingest notebook and the calcofi.org page
      # render in Overview's head links (r.links.workflow / r.links.calcofi_org), so they are
      # exempt here rather than duplicated into Access.
      want = ((r["distributions"] || []).reject { |x| %w[notebook page].include?(x["kind"]) } +
              (r["registrations"] || []))
             .filter_map { |x| Fmt.present(x["url"]) }
      want.reject { |u| shown.include?(u.sub(/\.\w+\z/, "")) }
    end

    # ── a holding: where the data live today, and what is holding it up (plan D-7) ──
    # A holding used to get `access = []` and therefore no Access section at all, which made every
    # holding page a dead end — the one thing a reader wants from it is where to get the data now.
    def holding_access(h)
      st = h["status"] || {}
      rows = (h["distributions"] || []).select { |x| %w[source page mirror archive].include?(x["kind"]) }
                                       .map do |x|
        { "label" => portal_name(x["portal"]), "label_url" => x["url"],
          "label_title" => PORTAL_ABOUT[x["portal"]],
          "ident" => Fmt.present(x["id"]) || DeriveId.call(x["url"]),
          "title_text" => Fmt.present(x["title"]) || Fmt.present(x["notes"]),
          "url" => x["url"], "chips" => [status_chip(x["status"])].compact }
      end
      if rows.empty? && (link = h.dig("links", "data_source"))
        rows << { "label" => "source", "label_url" => link, "url" => link,
                  "ident" => DeriveId.call(link) }
      end
      groups = []
      groups << { "id" => "source", "title" => "Where it lives today",
                  "lede" => "CalCOFI has not ingested this dataset, so there is no release table, " \
                            "no parquet and no ERDDAP service for it. This is where it is now.",
                  "blocks" => [{ "rows" => rows }] } unless rows.empty?

      status_rows = []
      if (stage = Fmt.present(st["stage"]))
        status_rows << { "label" => "stage", "chips" => [status_chip(stage)].compact,
                         "meta" => STAGE_MEANING[stage] }
      end
      status_rows << { "label" => "module", "meta" => st["module"] } if Fmt.present(st["module"])
      status_rows << { "label" => "priority (CalOOS)", "meta" => st["priority_caloos"] } if Fmt.present(st["priority_caloos"])
      status_rows << { "label" => "next step", "meta" => st["next_step"] } if Fmt.present(st["next_step"])
      if (iss = Fmt.present(st["gh_issue"]))
        status_rows << { "label" => "tracking", "label_url" => iss, "url" => iss }
      end
      groups << { "id" => "status", "title" => "Status",
                  "lede" => "Where this sits in the ingest queue, and what it is waiting on.",
                  "blocks" => [{ "rows" => status_rows }] } unless status_rows.empty?
      groups.each { |g| (g["blocks"] || []).each { |b| (b["rows"] || []).each { |row| split_row_url(row) } } }
    end

    # db-query's own saved queries, by the dataset they are about (ids are `category--name`;
    # _queries/datasets/{bottle,ichthyo}.md). Anything else gets the SQL shell, prefilled.
    SAVED_QUERIES = { "calcofi_bottle" => "datasets--bottle",
                      "swfsc_ichthyo"  => "datasets--ichthyo" }.freeze

    # ── the URL line, split for display (plan D-6, Decision 18) ──────────────
    # A URL is rendered as head + tail: the head shrinks and elides, the tail never does, so the
    # informative end (`data_0.parquet`, `?datasets=calcofi_ctd-cast`) is still visible at 375 px.
    # The tail is CAPPED: a prefilled SQL statement is a 200-character query string, and an
    # unshrinkable 200 characters would push the line straight through the container — which is the
    # wrap this whole design exists to prevent.
    TAIL_MAX = 46
    def split_url(u)
      u = u.to_s
      i = u.index("?") || u.rindex("/") || 0
      # a URL that ends in "/" would give a one-character tail, so back up one more segment:
      # "…/station/" reads better as "…calcofi.io" + "/station/" than as "…/station" + "/"
      i = (u.rindex("/", i - 1) || i) if i.positive? && i == u.length - 1 && u[i] == "/"
      tail = u[i..] || ""
      tail = u[-TAIL_MAX..] if tail.length > TAIL_MAX
      tail = u if tail.length >= u.length
      [u[0, u.length - tail.length], tail]
    end

    def query_shell_url(sql)
      "https://calcofi.io/db-query/?sql=#{CGI.escape(sql)}#sql-shell--shell"
    end

    # The STAC collection this dataset has in the release's own static catalog. The record carries
    # no `stac` distribution yet.
    # # until the record carries a stac distribution (calcofi4db, plan D-9 / UI-D) — delete then
    def stac_collection_url(key)
      "https://calcofi.io/stac/#/collections/#{key}/collection.json"
    end

    # what an ERDDAP grain means, for a reader who has never met the word.
    # # until the record carries distributions[].grain_description (calcofi4db 4.5.0 / schema 1.1,
    # # plan D-9) — delete this map when that release renders
    GRAIN_FALLBACK = {
      "sampling events" => "one row per cast, tow or transect — when, where and how it was sampled",
      "observations" => "one row per measurement, joined to the event it was taken on",
      "length/stage frequency" => "one row per size or stage class of a specimen",
      "full resolution (pre-thinning)" => "the unthinned series, every bin as the instrument recorded it"
    }.freeze

    # the day the legacy erddap.calcofi.io ids stop answering
    ERDDAP_SUNSET = "2026-12-04"

    # one sentence per pipeline stage, as the chip's title=. Site-side text: the vocabulary is
    # dataset_status.csv's, not any one dataset's, so it is not a dataset fact.
    # # Open question 3 (plan): Ben to supply the wording he wants for each stage
    STAGE_MEANING = {
      "published"  => "in the release and announced — the endpoints below are live",
      "validated"  => "in the release and through the validation gates",
      "ingested"   => "in the release; the record and its endpoints are still being completed",
      "metadata"   => "the record exists; the data are not in the release yet",
      "planned"    => "not started — a tracking issue says what it is waiting on",
      "external"   => "CalCOFI tracks this dataset; it lives with its provider",
      "archived"   => "held for the record; not maintained"
    }.freeze

    # a pipeline stage or a registration status as a chip. --warn is reserved for a state that
    # needs attention (plan D-1, Decision 13): a stage is information, so it is neutral, and
    # `published` gets the ok tint.
    CHIP_CLASS = {
      "published" => "cc-chip-ok", "current" => "cc-chip-ok", "validated" => "cc-chip-ok",
      "planned"   => "cc-chip-warn",
      "n/a"       => "cc-chip-na", "ingested" => "cc-chip-na", "metadata" => "cc-chip-na",
      "external"  => "cc-chip-quiet", "archived" => "cc-chip-quiet",
      "superseded" => "cc-chip-nogo", "retired" => "cc-chip-nogo"
    }.freeze
    def status_chip(v)
      v = Fmt.present(v) or return nil
      { "text" => v, "class" => CHIP_CLASS[v] || "cc-chip-na", "title" => STAGE_MEANING[v] }
    end

    # An ERDDAP row is one the record marks `format: erddap` OR one whose portal is an ERDDAP —
    # the legacy pre-core ids carry `kind: service` + `portal: erddap-calcofi` and no `format` at
    # all, and a format-only test dropped them off the page (measured 2026-09-05: two on
    # calcofi_ctd-cast). The "nothing lost" check below is what caught it.
    def erddap_row?(x)
      x["format"] == "erddap" || x["portal"].to_s.start_with?("erddap")
    end

    # the ERDDAP datasets that are live: the .html tabledap page is what the record lists, and a
    # superseded id keeps its row under the matrix rather than in it
    def erddap_current(dist)
      dist.select { |x| x["format"] == "erddap" && x["status"] != "superseded" && x["url"].to_s.end_with?(".html") }
    end

    # A portal's display name. The record carries a top-level `portals[]` from calcofi4db 4.5.0 /
    # schema 1.1 (plan D-9), read here first; this map is what the site falls back to.
    # # until the record carries portals[] — delete both maps when that release renders
    PORTAL_NAMES = {
      "erddap" => "ERDDAP (calcofi.io)", "erddap-calcofi" => "ERDDAP (calcofi.io)",
      "erddap-noaa" => "NOAA CoastWatch ERDDAP", "edi" => "EDI", "ncei" => "NCEI",
      "obis" => "OBIS", "ipt" => "OBIS-USA IPT", "caloos" => "CalOOS", "datazoo" => "DataZoo",
      "ucsd-library" => "UC San Diego Library", "zenodo" => "Zenodo", "ncbi" => "NCBI",
      "calcofi.org" => "CalCOFI.org", "gcs" => "Cloud storage", "other" => "Other"
    }.freeze
    # one sentence per portal, shown as the link's title= so a reader knows what the place is
    # # until the record carries portals[].description — same deletion
    PORTAL_ABOUT = {
      "erddap" => "CalCOFI's own ERDDAP: every released table as a subsettable service",
      "erddap-calcofi" => "CalCOFI's own ERDDAP: every released table as a subsettable service",
      "erddap-noaa" => "NOAA CoastWatch's ERDDAP, which mirrors several CalCOFI datasets",
      "edi" => "the Environmental Data Initiative repository, which archives LTER data with EML",
      "ncei" => "NOAA's National Centers for Environmental Information, the federal archive",
      "obis" => "the Ocean Biodiversity Information System, the global occurrence aggregator",
      "ipt" => "the OBIS-USA Integrated Publishing Toolkit, which serves the Darwin Core archive",
      "caloos" => "the Central and Southern California Ocean Observing System's data portal",
      "datazoo" => "CCE-LTER's DataZoo catalog at UC San Diego",
      "ucsd-library" => "the UC San Diego Library Digital Collections",
      "zenodo" => "Zenodo, where each CalCOFI release is deposited and gets a DOI",
      "ncbi" => "NCBI, where sequence data are deposited",
      "calcofi.org" => "the CalCOFI program's own site",
      "gcs" => "the release's own cloud storage"
    }.freeze
    def portal_name(p)
      (rec["portals"] || []).find { |x| x["portal"] == p }&.dig("name") || PORTAL_NAMES[p] || p
    end

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
            variable_names(cov).join(" "),
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
      # 1.1 adds fields (category descriptions, grain/table descriptions, registration ids,
      # portals[], coverage.months) — all optional here, so any 1.x renders. A different MAJOR
      # would mean a field this site reads has changed shape: warn.
      unless rec["schema_version"].to_s.start_with?("1.")
        Jekyll.logger.warn "datasets:", "record schema #{rec['schema_version'].inspect}, expected \"1.x\""
      end

      rec = deep_unescape(rec)
      cat = Catalog.new(site, rec, read_grid(site), read_land(site), read_coverage_stations(site))
      cat.products_by_dataset # validate products.yml before anything is written

      site.data["catalog"] = {
        "release"    => cat.release,
        "counts"     => { "datasets" => cat.datasets.size, "holdings" => cat.holdings.size,
                          "reference" => cat.reference.size },
        "categories" => cat.categories,
        "reference"  => cat.reference_band.merge("map" => cat.map_svg(nil)),
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

    # the station grid, read once: the map needs each cell's key and pattern, not only its centre
    # (the frame rule is "standard + extended, union what this dataset sampled").
    def read_grid(site)
      path = File.join(site.source, "_data", "grid.geojson")
      return [] unless File.exist?(path)
      JSON.parse(File.read(path))["features"].filter_map do |f|
        p = f["properties"]
        next unless p["lon_ctr"] && p["lat_ctr"]
        { "key" => p["grid_key"], "lon" => p["lon_ctr"], "lat" => p["lat_ctr"],
          "pattern" => p["pattern"] }
      end
    rescue StandardError => e
      Jekyll.logger.warn "datasets:", "could not read _data/grid.geojson (#{e.message})"
      []
    end

    # the coastline: a COMMITTED asset (scripts/build_land.py, Natural Earth 1:50 m, public domain),
    # not a release sidecar — it is cartography, not a dataset fact (plan Decision 5).
    def read_land(site)
      path = File.join(site.source, "_data", "land.geojson")
      unless File.exist?(path)
        Jekyll.logger.warn "datasets:", "_data/land.geojson missing — maps will draw without a coast " \
                                        "(run scripts/build_land.py once; the file is committed)"
        return []
      end
      JSON.parse(File.read(path))["features"].filter_map do |f|
        ring = f.dig("geometry", "coordinates", 0)
        ring&.map { |lon, lat| [lon, lat] }
      end
    rescue StandardError => e
      Jekyll.logger.warn "datasets:", "could not read _data/land.geojson (#{e.message})"
      []
    end

    # dataset_key → {grid_key => n_obs}: which cells each dataset actually sampled, and how much.
    # ~470 KB beside the record, read here at build time and never shipped to the browser.
    def read_coverage_stations(site)
      path = File.join(site.source, "_data", "coverage_stations.json")
      unless File.exist?(path)
        Jekyll.logger.warn "datasets:", "_data/coverage_stations.json missing — the maps will draw " \
                                        "the grid but no sampled stations (scripts/fetch_release.sh)"
        return {}
      end
      out = Hash.new { |h, k| h[k] = {} }
      JSON.parse(File.read(path))["stations"].each do |st|
        (st["datasets"] || []).each { |d| out[d["dataset_key"]][st["grid_key"]] = d["n_obs"] }
      end
      out
    rescue StandardError => e
      Jekyll.logger.warn "datasets:", "could not read _data/coverage_stations.json (#{e.message})"
      {}
    end

    def record_pages(site, cat, r)
      key = r["dataset_key"]
      is_holding = cat.holding?(r)
      cov = r["coverage"] || {}
      jsonld = cat.jsonld(r)

      # the h1 is the SHORT name when the record has one, and the full name becomes the lede under
      # it (plan D-3). Where the record has no short name — every holding on the served record; all
      # 17 are authored in calcofi4db main and land with the next release — the h1 is a sentence,
      # and the holdings' run 56 to 416 characters. In Teko at 60 px that is six to twelve lines of
      # display caps, so the size is chosen HERE, from the length, rather than guessed in CSS:
      #   > 80 chars   the h2 size, still Teko (the eleven names up to 162 characters)
      #   > 180 chars  the sans face in sentence case — uppercase Teko at any size is unreadable
      #                at 300 characters (the six from cce-lter_poc-pon to calcofi_prodo)
      short = Fmt.present(r["dataset_name_short"])
      full  = Fmt.present(r["dataset_name"])
      h1    = short || full || key
      lede  = (short && full && short != full) ? full : nil
      access = is_holding ? cat.holding_access(r) : cat.access_groups(r)
      if (lost = cat.unlisted_endpoints(r, access)).any?
        Jekyll.logger.warn "datasets:", "#{key}: #{lost.size} endpoint(s) in the record reach no " \
                                        "Access row — #{lost.join(', ')}"
      end

      page = Jekyll::PageWithoutAFile.new(site, site.source, "datasets/#{key}", "index.html")
      page.content = ""
      page.data.merge!(
        "layout"      => "dataset",
        "h1"          => h1,
        "lede"        => lede,
        "title_long"  => lede.nil? && h1.length > 80,
        "title_vlong" => lede.nil? && h1.length > 180,
        "stage_chip"  => cat.status_chip(r.dig("status", "stage")),
        "n_endpoints" => access.sum { |g| (g["blocks"] || []).sum { |b| (b["rows"] || []).size + (b["matrix"] || []).size } },
        "title"       => "#{r['dataset_name'] || key} · CalCOFI datasets",
        "description" => cat.plain(r["description_md"]) || "CalCOFI dataset #{key}",
        "record"      => r,
        "dataset_key" => key,
        "is_holding"  => is_holding,
        "icon"        => cat.icon_for(r.dig("category", "icon")),
        "years_bar"   => cat.years_bar(cov["years"], cov["year_min"], cov["year_max"]),
        "years_span"  => cat.year_span(cov),
        "map"         => is_holding ? nil : cat.map_svg(r),
        "access"      => access,
        "formats"     => is_holding ? [] : cat.formats(r),
        "cite_text"   => cat.cite_text(r),
        "bibtex"      => cat.bibtex(r),
        "release_cite" => cat.release["citation"],
        "release_bibtex" => cat.release_bibtex,
        "jsonld"      => JSON.pretty_generate(jsonld),
        "related"     => related(cat, r),
        # normalised once here so a template never asks whether a variable is a string or an object
        "variables"   => cat.normalize_variables(cov),
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
