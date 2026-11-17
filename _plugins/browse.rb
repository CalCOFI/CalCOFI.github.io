# frozen_string_literal: true

# Browse datasets (/datasets/, Betty 2026-11-14) — the rows the page draws and the preview it opens.
#
# Every value here is read from the release record (site.data["datasets"]) or the measurements index
# (site.data["measurements"]); nothing is typed. The rules are the plain functions of CalCOFI::Browse
# (tested in _test/browse_test.rb); the Catalog methods below wire them to the record. Two products:
#
#   site.data["browse"]   rows (core first, newest last), realms → categories → rows, the year axis
#   /datasets/browse.json the preview's extra: each dataset's station map (Catalog#map_svg, the same
#                         map its own page draws, without the hover titles)
#
# "Core first, newest last": datasets in the order they joined the database (since_version), and
# within one release the larger first. A dataset added later lands at the bottom on its own, so the
# order needs no list kept by hand. Categories follow their earliest dataset, realms likewise.
require_relative "datasets"

module CalCOFI
  # The rules of Browse datasets, as plain functions with no Jekyll dependency, so
  # _test/browse_test.rb pins each on a small fixture. Catalog#browse (below) only wires them to the
  # record.
  module Browse
    module_function

    # a taxon that says nothing about what is in a dataset: left out of "what's in it"
    SKIP = /unident|unknown|\Aother\b/i

    def norm(s) = s.to_s.downcase.gsub(/[^a-z0-9]/, "")

    # Core first, newest last: by the release a dataset joined (`since`, ascending, as a string), and
    # within one release the larger first (`n_obs`, descending). The sort is stable, so two datasets
    # equal on both keep the order they came in.
    def order(rows)
      rows.each_with_index
          .sort_by { |r, i| [r["since"].to_s, -r["n_obs"].to_i, i] }
          .map(&:first)
    end

    # the rows as categories, each category where its earliest dataset put it. `solo` marks a
    # category of one dataset that carries the category's own name (the page then uses the
    # dataset's full name, so the name is not said twice).
    def groups(rows)
      out = []
      rows.each do |r|
        g = out.find { |x| x["cat"] == r["cat"] }
        unless g
          g = { "cat" => r["cat"], "icon" => r["icon"], "realm" => r["realm"], "desc" => r["cat_desc"], "rows" => [] }
          out << g
        end
        g["rows"] << r
      end
      out.each do |g|
        g["n"] = g["rows"].size
        g["solo"] = g["n"] == 1 && norm(g["rows"][0]["name"]) == norm(g["cat"])
      end
      out
    end

    # the categories as realms, each realm where its earliest category put it. `titles` is the
    # catalog's own {id => title} (Catalog::REALMS); a realm it does not name is its id, capitalized.
    def realms(groups, titles = {})
      groups.map { |g| g["realm"] }.uniq.map do |id|
        { "id" => id, "title" => titles[id] || id.to_s.capitalize, "groups" => groups.select { |g| g["realm"] == id } }
      end
    end

    # measurements.json → [{variable name => the measurement's short label}, {name => its value count}].
    # A variable is known by the measurement's own key or by any name in bounds.declared_by
    # (temperature_ave is the unified `temperature`); the first measurement to claim a name keeps it.
    def measurement_labels(meas)
      lab = {}
      rank = {}
      (meas || []).each do |m|
        ([m["key"]] + (m.dig("bounds", "declared_by") || [])).each do |k|
          lab[k] ||= m["short_label"] || m["label"]
          rank[k] ||= m.dig("totals", "n_values").to_i
        end
      end
      [lab, rank]
    end

    # measurements.json → {dataset_key => how many measurements it carries}: the measurement KEYS
    # with a series in that dataset — the number the dataset page counts (DatasetPage.meas_rows), so
    # Browse's "and N more" and the page's "N measurements" are one number.
    def measurement_counts(meas)
      keys = Hash.new { |h, k| h[k] = [] }
      (meas || []).each do |m|
        (m["series"] || []).each { |s| keys[s["dataset_key"]] << m["key"] }
      end
      keys.transform_values { |v| v.uniq.size }
    end

    def tidy_taxon(s)
      s = s.to_s.tr("_", " ").strip
      s = s.capitalize if s == s.upcase
      s.empty? ? s : s[0].upcase + s[1..]
    end

    # What is in a dataset: [label, names, total].
    #   taxa          commonest first, the common name where there is one, tidied; an unidentified /
    #                 unknown / "other" taxon is skipped; a name said twice is said once. The total is
    #                 the record's n_taxa (the coverage lists only the top 50), else the names' count.
    #   measurements  (a dataset with no taxa) most-observed first, one label per measurement: a
    #                 replicate and a parenthesis fold into the label they qualify. The total is
    #                 `n_meas` — the dataset's count of measurement keys (measurement_counts) — and
    #                 never less than the labels' own count (which is all there is to go on where
    #                 the measurements record has no series for the dataset).
    def has(cov, lab, rank, n_meas = nil)
      taxa = (cov["taxa"] || []).sort_by { |t| -t["n_obs"].to_i }.filter_map do |t|
        n = Fmt.present(t["common_name"]) || Fmt.present(t["scientific_name"])
        next if n.nil? || "#{n} #{t['scientific_name']}".match?(SKIP)
        tidy_taxon(n)
      end.uniq(&:downcase)
      return ["Species and groups", taxa, cov["n_taxa"].to_i.positive? ? cov["n_taxa"].to_i : taxa.size] unless taxa.empty?

      vars = (cov["variables"] || []).map { |v| v.is_a?(Hash) ? v["name"] : v }.select { |v| lab[v] }
      vars = vars.sort_by { |v| -rank[v].to_i }
                 .map { |v| lab[v].sub(/,?\s*replicate \d+/i, "").gsub(/\s*\([^)]*\)/, "").strip }
                 .uniq(&:downcase)
      return ["Measurements", vars, [n_meas.to_i, vars.size].max] unless vars.empty?

      [nil, [], 0]
    end

    # "A, B, C and 6 more": the first k names, then how many of the total are not named
    def has_line(list, total, k)
      return nil if list.empty?
      shown = list.first(k)
      more = total - shown.size
      shown.join(", ") + (more.positive? ? " and #{Fmt.num(more)} more" : "")
    end

    # A row's years, as main's tiles say them: the measured span ("1951–2023", one year alone as
    # "1996"); where the years cannot be measured, the record's asserted `temporal` ("1996 to 2022");
    # nil only when the record says neither (the page then reads "Years not listed").
    def years_label(span_years, temporal)
      Fmt.present(span_years) || Fmt.present(temporal)
    end

    # "Surface" for a dataset taken at the surface, "0–515 m" otherwise, nil when no depth is recorded
    def depth_label(cov)
      dmax = cov["depth_max_m"]
      return nil if dmax.nil?
      return "Surface" if dmax.to_f.zero?
      "#{cov['depth_min_m'].to_f.round}–#{Fmt.num(dmax.to_f.round)} m"
    end

    # the years with data as marks on the release's own axis (`span`: [first year, last year]), so
    # every row's strip lines up with every other's. No span (no dataset has a measured year): nil —
    # the axis is the release's own or it is not drawn; no year is typed here.
    def strip(years, span, cls)
      return nil unless span
      y0, y1 = span
      w = y1 - y0 + 1
      out = +%(<svg class="#{cls}" viewBox="0 0 #{w} 10" preserveAspectRatio="none" aria-hidden="true"><rect class="bg" width="#{w}" height="10"/>)
      years.each { |y| out << format('<rect class="on" x="%.1f" width=".8" height="10"/>', y - y0 + 0.1) if y.between?(y0, y1) }
      out << "</svg>"
    end

    def ticks(span)
      return [] unless span
      [1970, 1990, 2010].select { |y| y > span[0] && y < span[1] }
    end
  end

  class Catalog
    BROWSE_SKIP = Browse::SKIP

    def browse(meas)
      @browse ||= begin
        lab, rank = Browse.measurement_labels(meas)
        n_meas = Browse.measurement_counts(meas)
        span = strip_span
        rows = Browse.order(datasets.map { |d| browse_row(d, lab, rank, span, n_meas[d["dataset_key"]]) })
        groups = Browse.groups(rows)
        { "rows" => rows, "realms" => Browse.realms(groups, REALMS.to_h { |r| [r["id"], r["title"]] }),
          "span" => span, "ticks" => Browse.ticks(span) }
      end
    end

    # key → the preview's map (the dataset page's own map, lighter: no hover titles or data-*)
    def browse_maps
      datasets.to_h do |d|
        m = map_svg(d)
        svg = m && m["svg"].gsub(%r{<title>.*?</title>}m, "").gsub(/ (?:data-\w+|tabindex)="[^"]*"/, "")
        [d["dataset_key"], { "svg" => svg, "n" => m && m["n_stations"] }]
      end
    end

    # A portal's SHORT name, for a line of them ("Also archived at EDI, Zenodo and OBIS"): the
    # catalog's own short map first, then the record's portals[] name, then the key — the order
    # source_name already uses. The redesigned dataset page carried a second, shorter map of its own
    # (which left `datazoo`, `erddap-noaa` and `ucsd-library` showing as raw keys).
    def portal_short(p) = PORTAL_NAMES[p] || portal_name(p)

    def browse_row(d, lab, rank, span, n_meas = nil)
      cov = d["coverage"] || {}
      label, has, total = Browse.has(cov, lab, rank, n_meas)
      years = (cov["years"] || []).select { |y| y["n_obs"].to_i.positive? }.map { |y| y["year"].to_i }
      ymin, ymax = cov["year_min"], cov["year_max"]
      offer = downloads(d)
      terms = (cov["taxa"] || []).flat_map { |t| [t["common_name"], t["scientific_name"]] } +
              (cov["variables"] || []).map { |v| lab[v.is_a?(Hash) ? v["name"] : v] }
      {
        "key"      => d["dataset_key"],
        "name"     => d["dataset_name_short"] || d["dataset_name"] || d["dataset_key"],
        "full"     => d["dataset_name"] || d["dataset_name_short"] || d["dataset_key"],
        "cat"      => d.dig("category", "name"),
        "cat_desc" => Fmt.present(d.dig("category", "description")),
        "icon"     => icon_for(d.dig("category", "icon")),
        "realm"    => cov["realm"] || d.dig("category", "realm"),
        "prov"     => d.dig("provider", "short") || d.dig("provider", "key"),
        "prov_name" => d.dig("provider", "name") || d.dig("provider", "short"),
        "desc"     => plain(d["description_md"]),
        "has_label" => label,
        "has"      => Browse.has_line(has, total, 3),
        "has_long" => Browse.has_line(has, total, 6),
        "terms"    => terms.compact.uniq.join("|"),
        "years"    => Browse.years_label(span_years(d), cov["temporal"]),
        "y0"       => ymin, "y1" => ymax,
        "strip"    => Browse.strip(years, span, "ys"),
        "strip_big" => Browse.strip(years, span, "ys big"),
        "depth"    => Browse.depth_label(cov),
        "stations" => cov["n_stations"].to_i.positive? ? Fmt.num(cov["n_stations"]) : nil,
        "n_obs"    => cov["n_obs"],
        "records"  => Fmt.num(cov["n_obs"]),
        "since"    => d["since_version"],
        "url"      => page_url(d),
        "explore"  => ways(d).find { |w| w["icon"] == "way-explorer" }&.dig("url"),
        # Download: the dataset page's dialog (#download there; main 3add72f, _plugins/downloads.rb), with the
        # default zip's words ("CSV · 32.4 MB"). nil — no Download in the preview — until the dataset has zips.
        "download" => offer && { "url" => "#{page_url(d)}#download", "what" => offer["what"] }
      }
    end
  end

  class BrowseData < Jekyll::Generator
    safe false
    priority :normal # after DatasetCatalog (:high), which builds the Catalog this reads

    class << self
      attr_accessor :catalog
    end

    def generate(site)
      cat = self.class.catalog
      return unless cat
      site.data["browse"] = cat.browse(raw_measurements(site))
      page = Jekyll::PageWithoutAFile.new(site, site.source, "datasets", "browse.json")
      page.content = "{% raw %}#{JSON.generate(cat.browse_maps)}{% endraw %}"
      page.data["layout"] = nil
      page.data["sitemap"] = false
      site.pages << page
    end

    # the measurements record as it is on disk. measurements.rb (also :normal) replaces
    # site.data["measurements"] with its own summary, and which of the two generators runs first
    # depends on the order the platform lists _plugins/ (it differs on Windows), so this reads the
    # record's own list either way: from site.data while it is still the record, else from the file
    def raw_measurements(site)
      m = site.data.dig("measurements", "measurements")
      return m if m.is_a?(Array)
      f = File.join(site.source, "_data", "measurements.json")
      File.exist?(f) ? (JSON.parse(File.read(f))["measurements"] rescue nil) : nil
    end
  end
end
