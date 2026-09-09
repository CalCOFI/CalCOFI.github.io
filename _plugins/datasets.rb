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
require "net/http"
require "uri"
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

    # 349 M · 316 M · 1.3 M — the ONE rule for a count in millions, so the numbers band, the release
    # strip, the release tile and the log never disagree (Liquid's `divided_by` truncates: 348,657,010
    # read 349 M on the band and 348 M on the strip until this became one rule, 2026-09-07). Rounded,
    # and under 10 M kept to one decimal: 1,258,665 organism observations are 1.3 M, not 1 M.
    def millions(n)
      return nil if n.nil?
      m = n.to_f / 1_000_000.0
      m < 10 ? m.round(1) : m.round
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

    ERDDAP_FORMATS = [%w[csv CSV], %w[json JSON]].freeze

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
              "lenses"   => p["lenses"] || [],
              # the ONE place a product-to-dataset link is written (plan Decision 10)
              "dataset_url" => p["dataset_url"],
              "dataset_url_realm" => p["dataset_url_realm"],
              "dataset_url_env" => p["dataset_url_env"]
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

        # a category first met through a contribution has no realm yet; a record of it does
        cats.each_value do |c|
          next if c["realm"]
          src = (datasets + holdings).find { |r| r.dig("category", "name") == c["name"] }
          c["realm"] = src&.dig("category", "realm")
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

    # the grid's two columns (2026-09-06): Biology left, Environment right — each realm's categories
    # in `category.order`. A category with no realm at all lands in Environment.
    REALMS = [{ "id" => "bio", "title" => "Biology", "icon" => "realm-bio",
                "lede" => "what lives in the water column — counted, measured, identified" },
              { "id" => "env", "title" => "Environment", "icon" => "realm-env",
                "lede" => "the water itself — its physics, chemistry and the air above it" }].freeze
    def realms
      @realms ||= REALMS.map do |r|
        r.merge("categories" => categories.select { |c| (c["realm"] || "env") == r["id"] }
                                           .sort_by { |c| c["name"].to_s.downcase })
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

    # ── the front door's reach (plan 2026-09-07 § D-2, D-3) ─────────────────────
    # One inline JSON for the section drawing, the map and the years strip (index.html writes it
    # once as <script type="application/json" id="reach">), so the browser fetches nothing — not
    # grid.geojson (407 KB) — and the record stays the only source. Everything here is the record,
    # the release's own catalog, or committed cartography; a number the build cannot read is nil
    # and the page draws no tile for it, never a typed value.
    def reach
      @reach ||= begin
        pat = { "standard" => "s", "extended" => "e", "historical" => "h" }
        {
          "release"    => { "version" => release["version"], "date" => release["release_date"] },
          "numbers"    => numbers,
          # the 218 cells: k key · l line · s station · p pattern · x lon · y lat (2 decimals: 1 km)
          "stations"   => @grid.map do |g|
            { "k" => g["key"], "l" => g["line"], "s" => g["station"], "p" => pat[g["pattern"]] || "h",
              "x" => g["lon"].round(2), "y" => g["lat"].round(2) }
          end,
          # the coastline rings (_data/land.geojson, committed cartography), 2 decimals
          "land"       => @land.map { |ring| ring.map { |lon, lat| [lon.round(2), lat.round(2)] } },
          # one row per dataset in the release: its measured years (observed_coverage()), or the
          # asserted `temporal` string where the data cannot be measured by year (region-pooled
          # phytoplankton; samples-only PIC tows) — the strip hatches those and says so
          "datasets"   => datasets.map do |d|
            cov = d["coverage"] || {}
            { "key"      => d["dataset_key"],
              "name"     => d["dataset_name_short"] || d["dataset_name"] || d["dataset_key"],
              "url"      => page_url(d),
              "color"    => dot_color(d),
              # the dataset's HOME category — its glyph and its realm, so the strip can group the
              # rows Biology then Environment and mark each with the same icon the catalog tile wears
              "cat"      => icon_for(d.dig("category", "icon")),
              "cat_name" => Fmt.present(d.dig("category", "name")),
              "realm"    => d.dig("category", "realm") || "env",
              "temporal" => Fmt.present(cov["temporal"]),
              "ymin"     => cov["year_min"], "ymax" => cov["year_max"],
              "years"    => (cov["years"] || []).map { |y| [y["year"], y["n_roots"], y["n_obs"]] } }
          end,
          # the categories in category.order with the release's counts — the drawing's pins read
          # their name, realm and counts from here (the calcofi.org method URLs are constants in
          # assets/section.js, one per glyph)
          "categories" => categories.map do |c|
            { "icon" => c["icon"], "name" => c["name"], "realm" => c["realm"], "order" => c["order"],
              "n" => c["n"], "held" => c["holdings"].size, "contrib" => c["contributions"].size }
          end,
          # the sea floor under Line 90 — _data/line90_floor.json, committed cartography built by
          # scripts/build_line90_floor.R from GEBCO 2025 at 500 m; nil if absent, and the drawing
          # then falls back to its drawn profile and marks it so
          "floor"      => @site.data["line90_floor"]
        }
      end
    end

    # ── the release's OBSERVED taxa (coverage.json → _data/release_coverage.json) ──────────
    # The taxon TABLE's 2,614 rows are not a count of organisms: 1,108 of them are lineage ancestors
    # and dataset vocabulary entries never observed. `taxa[]` is one row per taxon actually observed,
    # with its rank and the datasets it was seen in — the honest count the band and the dataset pages
    # show (plan 2026-09-09 § F4, D3, D4). An older release carries no coverage.json and every number
    # below is nil: the tile collapses, the dataset page keeps saying "taxa", nothing is typed.
    SPECIES_RANK = "Species"

    def coverage_taxa
      @coverage_taxa ||= begin
        cov = @site.data["release_coverage"]
        cov.is_a?(Hash) ? (cov["taxa"] || []) : []
      end
    end

    # species and taxa observed, per dataset_key — the dataset page's glance
    def taxa_by_dataset
      @taxa_by_dataset ||= begin
        out = {}
        coverage_taxa.each do |t|
          sp = t["rank"] == SPECIES_RANK
          (t["datasets"] || []).each do |d|
            k = d["dataset_key"] or next
            row = (out[k] ||= { "species" => 0, "taxa" => 0 })
            row["taxa"] += 1
            row["species"] += 1 if sp
          end
        end
        out
      end
    end

    # A rank's plural by RULE, not a typed list, so a rank the next release introduces still reads:
    # genus → genera, class → classes, species → species, family → families, phylum → phyla,
    # forma → formae, order → orders.
    def rank_plural(rank)
      r = rank.to_s.downcase
      case r
      when /us\z/ then r.sub(/us\z/, "era")
      when /ss\z/ then "#{r}es"
      when /s\z/  then r
      when /y\z/  then r.sub(/y\z/, "ies")
      when /um\z/ then r.sub(/um\z/, "a")
      when /a\z/  then "#{r}e"
      else "#{r}s"
      end
    end

    # "279 genera, 136 families, 19 orders, 14 dataset-local classes, 13 classes, 37 more at other
    # ranks" — the identifications that stopped above species, commonest first. A band tooltip is one
    # line, so the five commonest are named and the rest counted in one phrase; every number is
    # counted from taxa[], none typed. A taxon with no rank is a dataset's own class (the zooscan
    # "eggs", the phytoplankton "other").
    def rank_breakdown(limit = 5)
      counts = coverage_taxa.reject { |t| t["rank"] == SPECIES_RANK }
                            .group_by { |t| Fmt.present(t["rank"]) }
                            .transform_values(&:size)
                            .sort_by { |_, n| -n }
      shown = counts.first(limit).map do |rank, n|
        "#{Fmt.num(n)} #{rank ? rank_plural(rank) : 'dataset-local classes'}"
      end
      rest = counts.drop(limit).sum { |_, n| n }
      shown << "#{Fmt.num(rest)} more at other ranks" if rest.positive?
      shown.join(", ")
    end

    # What a measurement row is, summed for the band's `measurements` (plan 2026-09-09 § D9): the
    # release grain plus the two full-resolution supplementals. The sum is over the tables a release
    # actually carries, so one without the supplementals still renders a number.
    MEASUREMENT_TABLES = %w[obs_env obs_ctd_full obs_mets_full].freeze

    # The six numbers of the band under the hero (plan § D-2, re-cut by 2026-09-09 § D9), every one
    # read here:
    #   years     the release year minus the earliest measured year_min over datasets[]
    #   cruises · ships · stations   reference[].rows for cruise · ship · grid (ships is the hero's
    #             eyebrow now, not a tile)
    #   species   the release's own coverage.json, taxa[] at rank Species — the organisms identified
    #             to species; `taxa` is every taxon observed (1,506 on v2026.09.06, of which 1,008
    #             are species), and `taxon_rows` the taxon table's size, which is neither
    #   organism_obs   the release's own catalog.json, tables[obs_bio].rows — one taxon × one life
    #             stage × one sampling event, with its effort
    #   measurements   tables[obs_env] + [obs_ctd_full] + [obs_mets_full] .rows
    #   obs_dup   the rows of a table catalog.json lists under `views` (obs = obs_bio ∪ obs_env,
    #             still shipped as parquet for compatibility) — counted a SECOND time in total_rows,
    #             which is why the strip's rows cell says so
    #   rows      release.total_rows, with release.version — the release tile and the release strip
    #             keep it: they describe the release object, and total_rows is what the catalog says
    #   taxon_rows   tables[taxon].rows, the size of the taxon table (its 2,614 rows include the
    #             ancestors and the vocabulary entries never observed — NOT a count of organisms)
    # catalog.json reaches the build as _data/release_catalog.json (scripts/fetch_release.sh), and an
    # older release may carry none. A value the build cannot read is nil: the tile collapses rather
    # than rendering a typed number.
    def numbers
      @numbers ||= begin
        ref   = ->(k) { reference.find { |r| r["key"] == k }&.dig("rows") }
        ymins = datasets.filter_map { |d| d.dig("coverage", "year_min") }
        ryear = release["release_date"].to_s[0, 4].to_i
        cat   = @site.data["release_catalog"]
        tbls  = cat.is_a?(Hash) ? (cat["tables"] || []) : []
        views = cat.is_a?(Hash) ? (cat["views"] || {}) : {}
        trows = ->(name) { tbls.find { |t| t["name"] == name }&.dig("rows") }
        taxon_rows = trows.("taxon")
        obs_taxa = coverage_taxa.empty? ? nil : coverage_taxa.size
        species  = coverage_taxa.empty? ? nil : coverage_taxa.count { |t| t["rank"] == SPECIES_RANK }
        org   = trows.("obs_bio")
        parts = MEASUREMENT_TABLES.filter_map { |t| (r = trows.(t)) && [t, r] }
        meas  = parts.empty? ? nil : parts.sum { |_, r| r }
        dups  = tbls.select { |t| views.key?(t["name"]) }
        dup   = dups.empty? ? nil : dups.sum { |t| t["rows"].to_i }
        byp   = @grid.group_by { |g| g["pattern"] }.transform_values(&:size)
        {
          "years"    => (ryear.positive? && ymins.any?) ? ryear - ymins.min : nil,
          "since"    => ymins.min,
          "cruises"  => ref.("cruise"),
          "ships"    => ref.("ship"),
          "stations" => ref.("grid"),
          "grid"     => { "standard" => byp["standard"], "extended" => byp["extended"], "historical" => byp["historical"] },
          "species"     => species,
          "species_fmt" => Fmt.num(species),
          "taxa"        => obs_taxa,
          "taxa_fmt"    => Fmt.num(obs_taxa),
          # the taxa observed that are NOT at species rank — the Life tile's "and 498 more"
          "taxa_more_fmt"  => (obs_taxa && species) ? Fmt.num(obs_taxa - species) : nil,
          "taxon_rows"     => taxon_rows,
          "taxon_rows_fmt" => Fmt.num(taxon_rows),
          # the band's species tile carries the whole qualifier as its title: what "species" counts,
          # what it does not, and where the taxon table's bigger number belongs
          "species_title"  => species && [
            "#{Fmt.num(species)} identified to species",
            "#{Fmt.num(obs_taxa)} taxa observed in all (#{rank_breakdown})",
            taxon_rows && "#{Fmt.num(taxon_rows)} rows in the taxon table with their ancestors"
          ].compact.join(" · "),
          "organism_obs"     => org,
          "organism_obs_m"   => Fmt.millions(org),
          "organism_obs_fmt" => Fmt.num(org),
          "measurements"     => meas,
          "measurements_m"   => Fmt.millions(meas),
          "measurements_fmt" => Fmt.num(meas),
          "obs_dup"      => dup,
          "obs_dup_m"    => Fmt.millions(dup),
          "obs_dup_fmt"  => Fmt.num(dup),
          "obs_dup_name" => dups.map { |t| t["name"] }.join(" · "),
          # the band's dt is one 12 px line in a 170 px tile, so the qualifier lives in the tile's
          # title — the tables that were summed, exactly as the catalog counted them
          "organism_obs_title" => org && "obs_bio #{Fmt.num(org)} rows — one taxon × one life stage × " \
                                         "one sampling event, with its effort",
          "measurements_title" => parts.empty? ? nil :
            parts.map { |t, r| "#{t} #{Fmt.num(r)}#{' at the release grain' if t == 'obs_env'}" }.join(" + "),
          "rows"     => release["total_rows"],
          "rows_m"   => Fmt.millions(release["total_rows"]),
          "tables"   => release["n_tables"],
          "version"  => release["version"],
          "date"     => release["release_date"],
          "doi"      => Fmt.present(release["doi"])
        }
      end
    end

    # The release's own tables, for /datasets/release/ — name · rows · bytes · what it holds, biggest
    # first, straight off catalog.json (fetch_release.sh → _data/release_catalog.json; an older
    # release carries none and the section is not drawn). A table the catalog also lists under
    # `views` is SQL over other tables that the release still ships as parquet for compatibility, so
    # its rows are counted a SECOND time in total_rows — the page says so rather than leaving a
    # reader to add 23 numbers and find 26 M too many (plan 2026-09-09 § D9, F6).
    def release_tables
      @release_tables ||= begin
        cat = @site.data["release_catalog"]
        if cat.is_a?(Hash)
          views = cat["views"] || {}
          (cat["tables"] || []).map do |t|
            { "name" => t["name"], "rows" => t["rows"], "rows_fmt" => Fmt.num(t["rows"]),
              "size" => Fmt.bytes(t["bytes"]), "view" => views.key?(t["name"]),
              "supplemental" => t["supplemental"] == true,
              "about" => TABLE_ABOUT[t["name"]] }
          end.sort_by { |t| -t["rows"].to_i }
        else
          []
        end
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
        format('<rect x="%.1f" y="%.2f" width="%.1f" height="%.2f"%s data-year="%d" data-n="%d"><title>%d · %s obs</title></rect>',
               i * (w + gap), h - bh, w, bh, v.zero? ? ' opacity=".25"' : "", yr, v.to_i, yr, Fmt.num(v.to_i))
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

      # rx matches .cc-map's border-radius so the water's corners ARE the map's corners
      out = +%(<rect class="water" width="#{w.to_i}" height="#{h}" rx="6"/>)

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
      max = sampled.values.map { |v| v["n"] }.max || 1
      dots = +""
      cells.each do |c|
        next unless c["lon"].between?(x0, x1) && c["lat"].between?(y0, y1)
        cx = format("%.1f", px.(c["lon"]))
        cy = format("%.1f", py.(c["lat"]))
        if (v = sampled[c["key"]])
          n = v["n"]
          rr = 1.6 + 4.4 * Math.sqrt(n.to_f / max)
          # the data-* is what assets/coverage.js reads for the tap/hover card; <title> stays as the
          # no-JS hover and the accessible name
          dots << format('<circle class="st st-on" cx="%s" cy="%s" r="%.1f" tabindex="0" data-key="%s" data-n="%d" data-ymin="%s" data-ymax="%s" data-nyr="%d"><title>%s · %s obs · %s–%s</title></circle>',
                         cx, cy, rr, c["key"], n, v["ymin"], v["ymax"], v["nyr"], c["key"], Fmt.num(n), v["ymin"], v["ymax"])
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
      # A label centred on a tick at the frame's edge is half outside the viewBox, and an SVG root
      # clips: `135°W` rendered as `1°W` (measured on swfsc_ichthyo, whose frame starts at -135.3).
      # So a label within a label-width of an edge anchors to that edge instead of straddling it,
      # and a latitude label is kept a line clear of the top and bottom.
      ticks = +""
      (-180..180).step(5) do |lon|
        next unless lon > x0 && lon < x1
        tx = px.(lon)
        anchor, tx = if tx < 26 then ["start", 2.0] elsif tx > w - 26 then ["end", w - 2.0] else ["middle", tx] end
        ticks << format('<text class="tk" x="%.1f" y="%.1f" text-anchor="%s">%d°W</text>',
                        tx, h - 3.0, anchor, lon.abs)
      end
      (-90..90).step(5) do |lat|
        next unless lat > y0 && lat < y1
        ty = [[py.(lat) + 3.5, 11.0].max, h - 4.0].min
        ticks << format('<text class="tk" x="4" y="%.1f">%d°N</text>', ty, lat)
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

    # ── Access: compact rows, one listing per source, no URL in the prose ──
    # Five groups, in the order a reader uses them (UI refresh round 2, 2026-09-06):
    #   Explore · Get the data · Code · Metadata records · Archives & portals
    # What changed from round 1:
    #   · NO URL LINE. Every row's label is the link, its chips and identifier say which endpoint
    #     it is, and the copy button beside it copies the URL. The mono URL under every row was the
    #     busiest thing on the page and said nothing the label did not.
    #   · "Tables from the release" is a TABLE: table · what it holds · scope · size · since · sha256.
    #     They are the release's tables in parquet, not "files".
    #   · Query is folded into Code, AFTER the tables: "DuckDB, anywhere" reads one listed object, and
    #     the lede says why the path carries a hash and how to swap in any other table; db-query's
    #     prefilled shell is the last row, with `__TBL:obs__` explained in one line.
    #   · Explore rows carry the app's LENSES as suffix icons (products.yml `lenses:`) and the chip is
    #     the landing page's group — "Across datasets" / "One dataset" / "Student contribution". The
    #     deep link is used where the product declares a `dataset_url:`; a plain "opens on this
    #     dataset" is the meta, not a chip, so an app that merely opens is never mis-sold.
    #   · Metadata records is a two-up list; Archives & portals is a full-width TABLE — role ·
    #     portal · purpose · status · identifier — with the archive-of-record policy stated above it.
    #   · ERDDAP: CSV · JSON · page · info · graph. The netCDF column is gone — the CF netCDF above it
    #     is the netCDF to take, and two different netCDFs of one table confused.
    #
    # Row keys the includes read: label · label_url · label_title · lenses[] · chips[] · ident ·
    # title_text · meta · url (what the copy button copies) · hash · code · note (+ note_summary) ·
    # issue · about · scope · size · since (the table layout's columns).
    def access_groups(d)
      key    = d["dataset_key"]
      dist   = d["distributions"] || []
      tables = d["tables"] || []
      groups = []

      # ── Explore ──────────────────────────────────────────────────────────────
      rows = products_by_dataset[key]
             .select { |p| %w[explore students].include?(p["section_id"]) }
             .map do |p|
        tmpl = Fmt.present(p["dataset_url"])
        # a template scoped to one realm (db-viz-hex: ?datasets= is taxa-only) is a deep link
        # only for a dataset of that realm; the other realm gets the env template where the
        # product declares one (db-viz-hex: ?env=), else the plain app link
        realm = d.dig("coverage", "realm") || d.dig("category", "realm")
        tmpl = nil if tmpl && Fmt.present(p["dataset_url_realm"]) && p["dataset_url_realm"] != realm
        tmpl = Fmt.present(p["dataset_url_env"]) if tmpl.nil? && realm == "env" 
        link = tmpl ? tmpl.gsub("{key}", key) : p["url"]
        group = p["section_id"] == "students" ? "Student contribution" : p["group"]
        { "label" => p["title"], "label_url" => link, "url" => link,
          "lenses" => p["lenses"] || [],
          "student" => p["section_id"] == "students",
          "chips" => [{ "text" => group, "class" => "cc-chip-quiet",
                        "title" => group == "Student contribution" ? "a capstone or fellowship project" :
                                   group == "One dataset" ? "an app built on this dataset alone" :
                                   "reads every dataset in the release; this one among them" }],
          "meta"  => tmpl ? "opens on this dataset" : nil,
          "label_title" => tmpl ? "the link opens the app with this dataset already selected" :
                                  "the app opens at its own start; pick the dataset there" }
      end
      groups << { "id" => "explore", "title" => "Explore",
                  "lede" => "Apps that read this dataset from the release. The icons after a name are " \
                            "the app’s lenses — the spatial grain it shows the data at.",
                  "blocks" => [{ "rows" => rows }] } unless rows.empty?

      # ── Get the data ─────────────────────────────────────────────────────────
      blocks = []
      objs = (d["objects"] || []).map do |o|
        shared = o["shared"] || o["scope"] == "table"
        { "label" => o["table"], "label_url" => "https://calcofi.io/db-schema/##{o['table']}",
          "label_title" => "#{o['table']} in the schema browser",
          "url"   => o["url"], "shared" => shared,
          "about" => Fmt.present(o["table_description"]) || TABLE_ABOUT[o["table"]],
          "scope" => shared ? "whole table, every dataset" : "this dataset’s rows",
          "size"  => Fmt.bytes(o["bytes"]), "since" => o["since"],
          "hash"  => o["sha256"] }
      end
      if objs.empty?
        objs = dist.select { |x| x["format"] == "parquet" }.map do |x|
          t = x["table"] || x["title"]
          { "label" => t, "label_url" => "https://calcofi.io/db-schema/##{t}", "url" => x["url"],
            "shared" => x["shared"] || x["scope"] == "table",
            "about" => Fmt.present(x["table_description"]) || TABLE_ABOUT[t],
            "scope" => (x["shared"] || x["scope"] == "table") ? "whole table, every dataset" : "this dataset’s rows",
            "size" => Fmt.bytes(x["bytes"]), "since" => x["since"], "hash" => x["sha256"] }
        end
      end
      blocks << { "title" => "Tables from the release (Parquet)",
                  "lede" => "The release’s own tables, as the parquet objects it is frozen from — the " \
                            "same bytes every app and package below reads. A table this dataset " \
                            "shares with others holds every dataset’s rows, so filter on " \
                            "`dataset_key`; a partition holds only this dataset’s. *since* is the " \
                            "release whose rows these are: an unchanged table keeps its object.",
                  "layout" => "table", "rows" => objs } unless objs.empty?

      nc = dist.select { |x| x["format"] == "netcdf" }.map do |x|
        { "label" => Fmt.present(x["title"]) || "CF netCDF",
          "label_url" => x["url"], "url" => x["url"],
          "meta" => Fmt.bytes(x["bytes"]), "hash" => x["sha256"],
          "note" => Fmt.present(x["cf_scope"]), "note_summary" => "how far this file is CF" }
      end
      blocks << { "title" => "CF netCDF",
                  "lede" => "One self-describing file, for a tool that reads netCDF.",
                  "rows" => nc } unless nc.empty?

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
          desc = cur.find { |x| x["grain"] == g && Fmt.present(x["grain_description"]) }&.dig("grain_description")
          { "grain" => g, "desc" => desc || GRAIN_FALLBACK[g] }
        end.select { |g| g["desc"] }
        legacy = dist.select { |x| erddap_row?(x) && x["status"] == "superseded" }.map do |x|
          { "id" => x["id"], "url" => x["url"],
            "note" => x["superseded_by"] ? "replaced by #{x['superseded_by']}" : "superseded",
            "sunset" => ERDDAP_SUNSET }
        end
        blocks << { "title" => "ERDDAP (erddap.calcofi.io)",
                    "lede" => "One ERDDAP dataset per grain. Subset in the browser or query it from a " \
                              "script; for netCDF take the CF file above.",
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
                  "lede" => "Every way to have the bytes, by source. Nothing here asks you to register first.",
                  "blocks" => blocks } unless blocks.empty?

      # ── Code ─────────────────────────────────────────────────────────────────
      # After the tables on purpose: "DuckDB, anywhere" reads one of the objects just listed, and any
      # other row of that table can stand in for it.
      code_blocks = []
      code_blocks << { "title" => "Packages", "layout" => "pair",
                       "lede" => "The whole release, pinned to a version, with the citation one call away.",
                       "rows" => [
        { "label" => "R · calcofi4r", "label_url" => "https://calcofi.io/calcofi4r/", "url" => "https://calcofi.io/calcofi4r/",
          "code" => "con <- calcofi4r::cc_get_db()\ncalcofi4r::cc_cite(\"#{key}\")" },
        { "label" => "Python · calcofi4py", "label_url" => "https://calcofi.io/calcofi4py/", "url" => "https://calcofi.io/calcofi4py/",
          "code" => "con = calcofi4py.cc_get_db()\ncalcofi4py.cite(\"#{key}\")" }] }
      obj = objs.first
      if obj && obj["url"]
        where = obj["shared"] ? "\nWHERE dataset_key = '#{key}'" : ""
        code_blocks << {
          "title" => "DuckDB, anywhere",
          "lede" => "No CalCOFI package needed: each table above is a plain parquet object, readable " \
                    "by any DuckDB (or Arrow, pandas, Spark) from its URL. The path carries a content " \
                    "hash — a table whose rows did not change between releases keeps the same object, " \
                    "so nothing unchanged is stored or downloaded twice. Swap in any table above; one " \
                    "shared with other datasets needs `WHERE dataset_key = '#{key}'`. Every object of " \
                    "every release is listed in [db-schema](https://calcofi.io/db-schema/?v=#{release['version']}).",
          "rows" => [{ "label" => "#{obj['label']} · #{obj['scope']}", "url" => obj["url"],
                       "code" => "SELECT *\nFROM read_parquet('#{obj['url']}')#{where}\nLIMIT 100;" }] }
      end
      unless tables.empty?
        tbl = %w[obs sample].find { |t| tables.include?(t) } || tables.first
        sql = "-- #{key} in the CalCOFI release #{release['version']}\n" \
              "SELECT *\nFROM __TBL:#{tbl}__\nWHERE dataset_key = '#{key}'\nLIMIT 100;"
        saved = SAVED_QUERIES[key]
        shell = query_shell_url(sql)
        rows = [{ "label" => "db-query — the SQL shell, prefilled", "label_url" => shell, "url" => shell,
                  "meta" => "DuckDB-WASM in your browser; nothing downloaded until a query asks for it",
                  "code" => sql }]
        rows.unshift({ "label" => "db-query — the saved query for this dataset",
                       "label_url" => "https://calcofi.io/db-query/##{saved}",
                       "url" => "https://calcofi.io/db-query/##{saved}" }) if saved
        code_blocks << { "title" => "db-query, in the browser",
                         "lede" => "`__TBL:#{tbl}__` is db-query’s name for the pinned release’s `#{tbl}` " \
                                   "object — the hashed path above, resolved for you — so the same SQL " \
                                   "keeps working when a release changes the object.",
                         "rows" => rows }
      end
      groups << { "id" => "code", "title" => "Code",
                  "lede" => "The same release, from a script or a browser SQL shell.",
                  "blocks" => code_blocks }

      # ── Metadata records ─────────────────────────────────────────────────────
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
                     "meta" => "the release’s own entry for this dataset — everything here comes from it" }
      meta_rows << { "label" => "DCAT-US 1.1", "label_url" => abs("/data.json"), "url" => abs("/data.json"),
                     "meta" => "the whole catalog, for data.gov and any CKAN" }
      # the EML document the release writes beside datasets.json (release_database.qmd, calcofi4db
      # >= 4.4 build_eml()) — publish_to-edi.qmd packages it for EDI, it does not create it. Listed
      # only when it answers: the record the site renders may predate the eml/ chunk.
      # # until the record carries a `format: eml` distribution — delete the probe then
      eml = "#{release['url']}eml/#{key}.xml"
      meta_rows << { "label" => "EML 2.2", "label_url" => eml, "url" => eml,
                     "meta" => "the Ecological Metadata Language record the release writes; what an EDI package carries" } if url_ok?(eml)
      # the STAC collection: the record's own address from calcofi4db 4.6.0 (`format: stac`); the
      # browser opens the same document by its path under the catalog root
      stac = dist.find { |x| x["format"] == "stac" }
      stac_json = stac && stac["url"]
      meta_rows << { "label" => "STAC collection", "label_url" => stac_browser_url(key), "url" => stac_json,
                     "label_title" => "open in the STAC browser",
                     "meta" => "one Collection per dataset, an Item per release" } if stac_json
      groups << { "id" => "metadata", "title" => "Metadata records",
                  "lede" => "Records about the data, in the standards each portal harvests.",
                  "blocks" => [{ "layout" => "pair", "rows" => meta_rows }] }

      # ── Archives & portals: a table, with the policy stated above it ─────────
      # One row per portal the record names for this dataset (registrations[] — every portal,
      # whatever its status — plus the curated mirror/archive rows), with the portal's ROLE
      # (archive · aggregator · service · catalog · portal · publisher, from portal.csv through
      # portals[]), its PURPOSE (the registry's one-liner), the STATUS chip, the identifier the
      # portal knows the dataset by, and what is staged for it (a bundle built, not deposited).
      # Above the table: `status.publish_policy` — which portal is the archive of record and why
      # the rest are planned or n/a — so a reader never infers policy from an "n/a".
      # calcofi.io/docs/portals.html carries the same policy, rendered from the same record.
      by_portal = {}
      add_row = lambda do |portal, h|
        key_p = portal.to_s
        by_portal[key_p] ||= { "portal" => key_p, "label" => portal_name(key_p),
                               "role" => portal_kind(key_p), "about" => PORTAL_ABOUT[key_p] || portal_about(key_p),
                               "items" => [] }
        by_portal[key_p].merge!(h.reject { |_, v| v.nil? }.select { |k, _| %w[status status_title ident title_text url issue].include?(k) }) unless h["item"]
        by_portal[key_p]["items"] << h["item"] if h["item"]
      end
      (d["registrations"] || []).each do |g|
        add_row.call(g["portal"], { "status" => g["status"],
                                    "ident" => Fmt.present(g["id"]) || DeriveId.call(g["url"]),
                                    "title_text" => Fmt.present(g["title"]) || Fmt.present(g["note"]),
                                    "url" => Fmt.present(g["url"]),
                                    "issue" => Fmt.present(g["issue"]) || (g["issues"] || []).first })
      end
      dist.select { |x| %w[mirror archive].include?(x["kind"]) || (x["kind"] == "source" && x["portal"] == "edi") }.each do |x|
        ident = Fmt.present(x["id"]) || DeriveId.call(x["url"])
        if by_portal.key?(x["portal"].to_s) && by_portal[x["portal"].to_s]["url"] && by_portal[x["portal"].to_s]["url"] != x["url"]
          # a second endpoint on a portal already listed (CoastWatch's several mirrors): an item
          add_row.call(x["portal"], { "item" => { "label" => ident || x["kind"], "url" => x["url"],
                                                   "title_text" => Fmt.present(x["title"]), "chip" => x["kind"] } })
        else
          add_row.call(x["portal"], { "status" => by_portal.dig(x["portal"].to_s, "status") || x["status"],
                                      "ident" => ident, "title_text" => Fmt.present(x["title"]), "url" => x["url"] })
        end
      end
      # the bundles the publishers stage before a deposit: an item on the portal's own row
      # # until the record carries them (a `bundle` kind on distributions[]) — delete the probes then
      v = release["version"]
      dwca = "https://storage.googleapis.com/calcofi-db/publish/dwca/#{key}/#{key}_#{v}.zip"
      add_row.call("obis", { "item" => { "label" => "Darwin Core Archive #{v}", "url" => dwca, "chip" => "built, not deposited",
                                        "title_text" => "Event core + Occurrence + eMoF + meta.xml + eml.xml, as it would go to the OBIS-USA IPT" } }) if url_ok?(dwca)
      edi_man = "https://storage.googleapis.com/calcofi-db/publish/edi/#{key}/#{key}_#{v}/manifest.json"
      add_row.call("edi", { "item" => { "label" => "EDI data package #{v}", "url" => edi_man, "chip" => "built, not deposited",
                                       "title_text" => "the package manifest; the CSV entities and the EML sit beside it" } }) if url_ok?(edi_man)
      order = %w[archive aggregator publisher service portal catalog]
      rows = by_portal.values.sort_by { |r| [order.index(r["role"]) || 9, r["label"].to_s] }
      rows.each { |r| r["chips"] = [status_chip(r["status"])].compact }
      groups << { "id" => "archives", "title" => "Archives & portals",
                  "lede" => "Where this dataset is registered outside calcofi.io: each portal’s role, " \
                            "what it is for, the dataset’s status there and the identifier it is known by. " \
                            "The policy — which portal is the archive of record and why — is in " \
                            "[Portals](https://calcofi.io/docs/portals.html).",
                  "policy" => Fmt.present(r_policy(d)),
                  "blocks" => [{ "layout" => "portals", "rows" => rows }] } unless rows.empty?
      groups
    end

    # does a URL answer? A ranged GET (EDI answers 405 to HEAD), cached per build, false when the
    # network is off (CALCOFI_SKIP_LINK_CHECK) — a row is drawn only for an address that exists.
    def url_ok?(u)
      return false if ENV["CALCOFI_SKIP_LINK_CHECK"].to_s != ""
      @url_ok ||= {}
      return @url_ok[u] if @url_ok.key?(u)
      uri = URI(u)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 6, read_timeout: 12) do |h|
        h.get(uri.request_uri, { "Range" => "bytes=0-0" })
      end
      @url_ok[u] = %w[200 206].include?(res.code)
    rescue StandardError
      @url_ok[u] = false
    end

    # what each release table holds, for the tables listing — the record's own
    # `objects[].table_description` (schema 1.1) wins; this is the fallback for a record without it.
    # `sample` is the one whose grain a reader cannot guess: it is an adjacency list. Measured at
    # v2026.09.04: bottle → cast (calcofi_bottle, calcofi_dic), net → tow → site (swfsc_ichthyo),
    # subsample → the ichthyo site (cdfw_dungeness-crab); every other dataset's events are roots.
    TABLE_ABOUT = {
      "obs" => "observations — one row per measurement or occurrence, at the event it was taken on",
      "obs_bio" => "biological observations — occurrences with their tow’s gear, effort and densities",
      "obs_env" => "environmental observations — one object per measurement type",
      "sample" => "sampling events — casts, bottles, tows, nets, transects; nested where the source nests them (a bottle under its cast, a net under its tow under its station visit) via parent_sample_key, each with its cruise_key",
      "sample_measurement" => "event-level effort and conditions — volume filtered, tow depth, wind",
      "obs_attribute" => "sub-occurrence detail — size or stage classes, counts, behaviour",
      "obs_ctd_full" => "the full-resolution CTD series, every bin as the instrument recorded it",
      "obs_mets_full" => "the full-resolution underway meteorology series",
      "measurement_type" => "the measurement vocabulary — units, bounds, NERC ids",
      "taxon" => "one row per taxon, keyed to WoRMS or ITIS",
      "dataset_taxon" => "each dataset’s own taxon vocabulary, resolved to taxon",
      "taxon_group" => "functional and reporting groups over taxon",
      "cruise" => "one row per cruise — the designated month, ship and date span",
      "ship" => "the ship registry, by NODC code",
      "grid" => "the CalCOFI station grid",
      "site" => "station occupations",
      "dataset" => "one row per dataset — citation, licence, measured coverage",
      "climatology" => "the 1993–2013 monthly baseline every anomaly subtracts"
    }.freeze

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
          (b["rows"] || []).each do |row|
            shown << row["url"] << row["label_url"]
            (row["items"] || []).each { |it| shown << it["url"] }
          end
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
      groups
    end

    # ── the original input files, on gs://calcofi-files-public ───────────────
    # Twelve ingests archive what they read with `sync_to_gcs(gcs_prefix = "archive/{provider}/
    # {dataset}")`; three read straight from the Drive folder the nightly rclone mirrors to `_sync/`
    # (bottle, CTD casts, ichthyo). METS downloads per cruise into a Drive folder that is not in
    # either. The prefix is per dataset because the two conventions coexist; the listing itself is
    # MEASURED at build through the bucket's anonymous JSON API (never typed), and skipped — folder
    # link only — under CALCOFI_SKIP_LINK_CHECK or when the request fails.
    # # until the record carries sources[] for every dataset (stamp_source_access() — one ingest
    # # stamps today) — delete the map then and read the record
    SOURCE_BUCKET = "calcofi-files-public"
    SOURCE_PREFIX = {
      "calcofi_bottle"   => "_sync/calcofi/bottle/",
      "calcofi_ctd-cast" => "_sync/calcofi/ctd-cast/download/",
      "swfsc_ichthyo"    => "_sync/swfsc/ichthyo/",
      "calcofi_mets"     => nil
    }.freeze
    def source_prefix(key)
      return SOURCE_PREFIX[key] if SOURCE_PREFIX.key?(key)
      pd = key.split("_", 2)
      pd.size == 2 ? "archive/#{pd[0]}/#{pd[1]}/" : nil
    end

    # the objects under a prefix, paginated; nil when the network is off or the request fails
    def list_bucket(prefix)
      return nil if ENV["CALCOFI_SKIP_LINK_CHECK"].to_s != ""
      items, token = [], nil
      loop do
        q = { "prefix" => prefix, "fields" => "nextPageToken,items(name,size,updated)", "maxResults" => "1000" }
        q["pageToken"] = token if token
        uri = URI("https://storage.googleapis.com/storage/v1/b/#{SOURCE_BUCKET}/o?#{URI.encode_www_form(q)}")
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 8, read_timeout: 20) { |h| h.get(uri) }
        return nil unless res.is_a?(Net::HTTPSuccess)
        j = JSON.parse(res.body)
        items.concat(j["items"] || [])
        token = j["nextPageToken"]
        break unless token
      end
      items
    rescue StandardError => e
      Jekyll.logger.warn "datasets:", "source listing #{prefix}: #{e.message}"
      nil
    end

    SOURCE_SHOWN = 12
    # the section: folder link, the count and bytes measured, the files (mono, capped) — nil when
    # the dataset has no registered inputs. `.DS_Store` and the generated index.html are not inputs.
    def source_files(d)
      key = d["dataset_key"]
      prefix = source_prefix(key) or return nil
      folder = "https://storage.calcofi.io/#{SOURCE_BUCKET}/#{prefix}"
      items = list_bucket(prefix)
      files = (items || []).reject { |o| o["name"].end_with?("/", "/index.html", "/.DS_Store") }
                           .map do |o|
        rel = o["name"].sub(prefix, "")
        { "name" => rel, "size" => Fmt.bytes(o["size"].to_i), "bytes" => o["size"].to_i,
          "updated" => o["updated"].to_s[0, 10],
          "url" => "https://storage.googleapis.com/#{SOURCE_BUCKET}/#{o['name'].split('/').map { |x| CGI.escape(x).gsub('+', '%20') }.join('/')}" }
      end.sort_by { |f| f["name"] }
      return nil if items && files.empty?
      {
        "prefix" => prefix, "folder" => folder,
        "kind" => prefix.start_with?("archive/") ? "archived by the ingest" : "mirrored nightly from the shared Drive",
        "measured" => !items.nil?,
        "n" => files.size, "bytes" => Fmt.bytes(files.sum { |f| f["bytes"] }),
        "shown" => files.first(SOURCE_SHOWN), "more" => files.drop(SOURCE_SHOWN)
      }
    end

    # db-query's own saved queries, by the dataset they are about (ids are `category--name`;
    # _queries/datasets/{bottle,ichthyo}.md). Anything else gets the SQL shell, prefilled.
    SAVED_QUERIES = { "calcofi_bottle" => "datasets--bottle",
                      "swfsc_ichthyo"  => "datasets--ichthyo" }.freeze

    def query_shell_url(sql)
      "https://calcofi.io/db-query/?sql=#{CGI.escape(sql)}#sql-shell--shell"
    end

    # The collection in the STAC browser at calcofi.io/stac/ (its hash route is the document's path
    # under the catalog root). The record's own JSON address is what the copy button copies.
    def stac_browser_url(key)
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
    def portal_kind(p)
      (rec["portals"] || []).find { |x| x["portal"] == p }&.dig("kind") || PORTAL_KIND[p]
    end
    def portal_about(p)
      (rec["portals"] || []).find { |x| x["portal"] == p }&.dig("description")
    end
    # the portal's role where the record predates portals[] (schema 1.1 carries it)
    PORTAL_KIND = { "erddap" => "service", "erddap-noaa" => "service", "edi" => "archive", "ncei" => "archive",
                    "obis" => "aggregator", "ipt" => "publisher", "caloos" => "catalog", "datazoo" => "portal",
                    "ucsd-library" => "archive", "zenodo" => "archive", "ncbi" => "archive",
                    "calcofi.org" => "portal", "gcs" => "service" }.freeze

    # the dataset's archive-of-record policy: `status.publish_policy` in the record (calcofi4db
    # 4.6.3); until a promoted release carries it, the registry it comes from, read at build.
    # # until the served record carries status.publish_policy — delete the registry read then
    def r_policy(d)
      pol = d.dig("status", "publish_policy")
      return pol if Fmt.present(pol)
      registry_policy[d["dataset_key"]]
    end
    def registry_policy
      @registry_policy ||= begin
        return {} if ENV["CALCOFI_SKIP_LINK_CHECK"].to_s != ""
        uri = URI("https://raw.githubusercontent.com/CalCOFI/workflows/main/metadata/dataset_status.csv")
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 6, read_timeout: 12) { |h| h.get(uri.request_uri) }
        return {} unless res.is_a?(Net::HTTPSuccess)
        require "csv"
        CSV.parse(res.body.dup.force_encoding("UTF-8"), headers: true).to_h { |row| ["#{row['provider']}_#{row['dataset']}", Fmt.present(row["publish_policy"])] }
      rescue StandardError
        {}
      end
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
        when "iso19115", "stac"
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
        when "stac"
          out << { "@type" => "dcat:Distribution", "title" => x["title"] || "STAC collection",
                   "accessURL" => x["url"], "mediaType" => "application/json", "format" => "STAC" }
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
        "realms"     => cat.realms,
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
        "contact"    => cat.contact,
        # the front door's numbers band (plan 2026-09-07 § D-2); every value read, none typed
        "numbers"    => cat.numbers
      }
      # the inline JSON the front door's drawing, map and years strip read (§ D-3)
      site.data["reach"] = cat.reach

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
          "pattern" => p["pattern"],
          # line and station: the front door's section drawing takes its station axis from the
          # line-90 standard cells, and the map draws each line as a polyline (plan 2026-09-07)
          "line" => p["line"], "station" => p["station"] }
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
        (st["datasets"] || []).each do |d|
          out[d["dataset_key"]][st["grid_key"]] = { "n" => d["n_obs"], "ymin" => d["year_min"], "ymax" => d["year_max"],
                                                    "nyr" => (d["years"] || []).size }
        end
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
        # this dataset's own species count, from the release's coverage.json (plan 2026-09-09 § D3):
        # the taxa it observed that are at species rank, with the full count beside it in the title.
        # nil where the release carries no coverage.json, and the page then says "taxa" as before.
        "n_species"   => cat.taxa_by_dataset.dig(key, "species"),
        "n_cov_taxa"  => cat.taxa_by_dataset.dig(key, "taxa"),
        "objects"     => (r["objects"] || []).map { |o| o.merge("bytes_fmt" => Fmt.bytes(o["bytes"])) },
        "sources"     => is_holding ? nil : cat.source_files(r)
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
        "tables"   => cat.release_tables,
        "numbers"  => cat.numbers,
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
