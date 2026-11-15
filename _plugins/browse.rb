# frozen_string_literal: true

# Browse datasets (/datasets/, Betty 2026-11-14) — the rows the page draws and the preview it opens.
#
# Every value here is read from the release record (site.data["datasets"]) or the measurements index
# (site.data["measurements"]); nothing is typed. Two products:
#
#   site.data["browse"]   rows (core first, newest last), realms → categories → rows, the year axis
#   /datasets/browse.json the preview's extra: each dataset's station map (Catalog#map_svg, the same
#                         map its own page draws, without the hover titles)
#
# "Core first, newest last": datasets in the order they joined the database (since_version), and
# within one release the larger first. A dataset added later lands at the bottom on its own, so the
# order needs no list kept by hand. Categories follow their earliest dataset, realms likewise.
module CalCOFI
  class Catalog
    BROWSE_SKIP = /unident|unknown|\Aother\b/i

    def browse(meas)
      @browse ||= begin
        lab, rank = measurement_labels(meas)
        span = strip_span || [1949, Time.now.year]
        rows = datasets.map { |d| browse_row(d, lab, rank, span) }
        core = ->(a, b) { (a["since"].to_s <=> b["since"].to_s).nonzero? || (b["n_obs"].to_i <=> a["n_obs"].to_i) }
        rows.sort!(&core)
        groups = []
        rows.each do |r|
          g = groups.find { |x| x["cat"] == r["cat"] }
          unless g
            g = { "cat" => r["cat"], "icon" => r["icon"], "realm" => r["realm"], "desc" => r["cat_desc"], "rows" => [] }
            groups << g
          end
          g["rows"] << r
        end
        groups.each do |g|
          g["n"] = g["rows"].size
          g["solo"] = g["n"] == 1 && norm(g["rows"][0]["name"]) == norm(g["cat"])
        end
        realm_ids = groups.map { |g| g["realm"] }.uniq
        realms = realm_ids.map do |id|
          { "id" => id, "title" => id == "bio" ? "Biology" : id == "env" ? "Environment" : id.to_s.capitalize,
            "groups" => groups.select { |g| g["realm"] == id } }
        end
        { "rows" => rows, "realms" => realms, "span" => span,
          "ticks" => [1970, 1990, 2010].select { |y| y > span[0] && y < span[1] } }
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

    private

    def norm(s) = s.to_s.downcase.gsub(/[^a-z0-9]/, "")

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

    def tidy_taxon(s)
      s = s.to_s.tr("_", " ").strip
      s = s.capitalize if s == s.upcase
      s.empty? ? s : s[0].upcase + s[1..]
    end

    # what is in it: species and groups commonest first (common name where there is one), or the
    # measurements most-observed first, one label per measurement (replicates fold into one)
    def browse_has(cov, lab, rank)
      taxa = (cov["taxa"] || []).sort_by { |t| -t["n_obs"].to_i }.filter_map do |t|
        n = Fmt.present(t["common_name"]) || Fmt.present(t["scientific_name"])
        next if n.nil? || "#{n} #{t['scientific_name']}".match?(BROWSE_SKIP)
        tidy_taxon(n)
      end.uniq(&:downcase)
      return ["Species and groups", taxa, cov["n_taxa"].to_i.positive? ? cov["n_taxa"].to_i : taxa.size] unless taxa.empty?

      vars = (cov["variables"] || []).map { |v| v.is_a?(Hash) ? v["name"] : v }.select { |v| lab[v] }
      vars = vars.sort_by { |v| -rank[v].to_i }
                 .map { |v| lab[v].sub(/,?\s*replicate \d+/i, "").gsub(/\s*\([^)]*\)/, "").strip }
                 .uniq(&:downcase)
      return ["Measurements", vars, vars.size] unless vars.empty?

      [nil, [], 0]
    end

    def has_line(list, total, k)
      return nil if list.empty?
      shown = list.first(k)
      more = total - shown.size
      shown.join(", ") + (more.positive? ? " and #{Fmt.num(more)} more" : "")
    end

    def browse_strip(years, span, cls)
      y0, y1 = span
      w = y1 - y0 + 1
      out = +%(<svg class="#{cls}" viewBox="0 0 #{w} 10" preserveAspectRatio="none" aria-hidden="true"><rect class="bg" width="#{w}" height="10"/>)
      years.each { |y| out << format('<rect class="on" x="%.1f" width=".8" height="10"/>', y - y0 + 0.1) if y.between?(y0, y1) }
      out << "</svg>"
    end

    def browse_row(d, lab, rank, span)
      cov = d["coverage"] || {}
      label, has, total = browse_has(cov, lab, rank)
      years = (cov["years"] || []).select { |y| y["n_obs"].to_i.positive? }.map { |y| y["year"].to_i }
      dmax = cov["depth_max_m"]
      depth = if dmax.nil? then nil
              elsif dmax.to_f.zero? then "Surface"
              else "#{cov['depth_min_m'].to_f.round}–#{Fmt.num(dmax.to_f.round)} m"
              end
      ymin, ymax = cov["year_min"], cov["year_max"]
      dl = download_of(d)
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
        "has"      => has_line(has, total, 3),
        "has_long" => has_line(has, total, 6),
        "terms"    => terms.compact.uniq.join("|"),
        "years"    => ymin ? (ymin == ymax ? ymin.to_s : "#{ymin}–#{ymax}") : nil,
        "y0"       => ymin, "y1" => ymax,
        "strip"    => browse_strip(years, span, "ys"),
        "strip_big" => browse_strip(years, span, "ys big"),
        "depth"    => depth,
        "stations" => cov["n_stations"].to_i.positive? ? Fmt.num(cov["n_stations"]) : nil,
        "n_obs"    => cov["n_obs"],
        "records"  => Fmt.num(cov["n_obs"]),
        "since"    => d["since_version"],
        "url"      => page_url(d),
        "explore"  => ways(d).find { |w| w["icon"] == "way-explorer" }&.dig("url"),
        "dl"       => dl && dl["url"], "dl_label" => dl && dl["label"]
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
      site.data["browse"] = cat.browse(site.data.dig("measurements", "measurements"))
      page = Jekyll::PageWithoutAFile.new(site, site.source, "datasets", "browse.json")
      page.content = "{% raw %}#{JSON.generate(cat.browse_maps)}{% endraw %}"
      page.data["layout"] = nil
      page.data["sitemap"] = false
      site.pages << page
    end
  end
end
