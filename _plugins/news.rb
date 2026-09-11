# _plugins/news.rb — the ship's log: news that mostly writes itself (plan 2026-09-07 § D-5).
#
# Four sources, merged and date-sorted into `site.data.log` (newest first; `site.data.news` stays
# the hand-written file), each entry
# {date, type, title, body, url, key}:
#
#   release   _data/versions.json — one entry per promoted release; the title is the first `##`
#             heading of that version's RELEASE_NOTES.md (fetched into _data/release_headings.json
#             by scripts/fetch_release.sh), or the version alone when the notes carry none. It links
#             the RENDERED changelog — never the raw .md — anchored on the version where the page
#             has a heading for it: RELEASES.html#v2026.09.06, the version string verbatim (its own
#             "v" included), which workflows' scripts/render_md_on_storage.R stamps as the heading's
#             id. Which ids the page really carries is READ, not assumed: fetch_release.sh writes
#             them to _data/release_anchors.json, and a version the changelog collapsed into a range
#             section links the page unanchored. scripts/check_news.py holds every fragment the log
#             uses to an id on that page.
#   dataset   datasets[].since_version — "<name> enters the release", dated by that version's
#             release_date; only for versions that exist in versions.json, so a `since_version`
#             that predates the catalog never invents a date
#   app       products.yml `added: YYYY-MM-DD` (back-filled from each product's first commit) —
#             "New: <title>". (Until 2026-09-11 the header's News link wore a dot while any entry was
#             under 30 days old; it could not know what a visitor had read, so it only confused. Gone.)
#   data · site · paper   _data/news.yml rows {date, type, title, body, url} — hand-written
#
# A news.yml row may carry `dataset_key:` or `version:` to OVERRIDE a generated entry of the same key
# (a wrong `since_version`, a notes heading that is not the story) — the generated one is dropped.
#
# It also generates /news/ (every entry with a type filter, assets/news.js) and /feed.xml (Atom,
# written here rather than by jekyll-feed: these entries are not posts or a collection, and any
# feed reader — calcofi.org's WordPress included — reads Atom). Type chips are quiet (.cc-chip-quiet
# / --accent-bg) and NEVER --warn: yellow marks a state that needs attention, not a kind of thing.

require "json"
require "cgi"
require "date"
require "yaml"

module CalCOFI
  module News
    TYPES    = %w[release dataset app data site paper].freeze
    # the rendered changelog every release entry opens (storage.calcofi.io, not the raw .md on
    # googleapis); the two hand-written `data` rows of news.yml link their own `##` section of it
    RELEASES = "https://storage.calcofi.io/calcofi-db/ducklake/releases/RELEASES.html"

    module_function

    def build(site)
      versions = (site.data.dig("versions", "versions") || []).select { |v| v["version"] && v["release_date"] }
      by_v     = versions.to_h { |v| [v["version"], v] }
      headings = site.data["release_headings"] || {}
      rec      = site.data["datasets"] || {}
      cat_idx  = site.data.dig("catalog", "index") || {}
      hand     = (site.data["news"] || []).select { |r| r.is_a?(Hash) && r["date"] && r["title"] }
      # the version headings RELEASES.html really carries (fetch_release.sh reads them off the page);
      # absent or unreadable, every release entry links the changelog unanchored
      anchors  = site.data["release_anchors"].is_a?(Array) ? site.data["release_anchors"] : []
      over_ds  = hand.filter_map { |r| r["dataset_key"] }
      over_v   = hand.filter_map { |r| r["version"] }
      entries  = []

      versions.each do |v|
        next if over_v.include?(v["version"])
        h = headings[v["version"]]
        entries << {
          "date"  => v["release_date"], "type" => "release", "key" => v["version"],
          "title" => h ? "#{v['version']} — #{h}" : v["version"],
          "body"  => [v["tables"] && "#{v['tables']} tables", v["total_rows"] && "#{(v['total_rows'] / 1_000_000.0).round} M rows",
                      v["doi"] && "DOI #{v['doi']}"].compact.join(" · "),
          "url"   => anchors.include?(v["version"]) ? "#{RELEASES}##{v['version']}" : RELEASES
        }
      end

      (rec["datasets"] || []).each do |d|
        v = by_v[d["since_version"]] or next          # a version the history does not carry gets no date, so no entry
        next if over_ds.include?(d["dataset_key"])
        name = d["dataset_name_short"] || d["dataset_name"] || d["dataset_key"]
        entries << {
          "date"  => v["release_date"], "type" => "dataset", "key" => d["dataset_key"],
          "title" => "#{name} enters the release",
          "body"  => [d.dig("provider", "short") || d.dig("provider", "key"), d.dig("coverage", "temporal"),
                      d.dig("category", "name")].compact.join(" · "),
          "url"   => cat_idx.dig(d["dataset_key"], "url") || "/datasets/#{d['dataset_key']}/"
        }
      end

      (site.data.dig("products", "products") || []).each do |p|
        next unless p["added"]
        entries << {
          "date"  => p["added"].to_s, "type" => "app", "key" => p["key"],
          "title" => "New: #{p['title']}",
          "body"  => p["description"].to_s.split(/(?<=\.)\s/).first.to_s,
          "url"   => p["live_url"]
        }
      end

      hand.each do |r|
        t = TYPES.include?(r["type"]) ? r["type"] : "site"
        entries << { "date" => r["date"].to_s, "type" => t, "key" => r["key"] || r["dataset_key"] || r["version"],
                     "title" => r["title"], "body" => r["body"].to_s, "url" => r["url"] }
      end

      entries.each { |e| e["date"] = e["date"].to_s[0, 10] }
      entries.sort_by { |e| [e["date"], TYPES.index(e["type"]) || 9] }.reverse
    end

    def atom(site, entries)
      base = site.config["url"].to_s.sub(%r{/\z}, "")
      updated = entries.first ? "#{entries.first['date']}T00:00:00Z" : Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      items = entries.first(50).map do |e|
        url = e["url"].to_s.start_with?("http") ? e["url"] : "#{base}#{e['url']}"
        <<~XML
          <entry>
            <title>#{CGI.escapeHTML(e['title'].to_s)}</title>
            <link href="#{CGI.escapeHTML(url)}"/>
            <id>#{base}/news/##{CGI.escapeHTML("#{e['type']}-#{e['date']}-#{e['key']}")}</id>
            <updated>#{e['date']}T00:00:00Z</updated>
            <category term="#{e['type']}"/>
            <summary>#{CGI.escapeHTML(e['body'].to_s)}</summary>
          </entry>
        XML
      end.join
      <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <title>CalCOFI.io — the ship's log</title>
          <subtitle>Releases of the integrated database, datasets entering it, apps and features as they land.</subtitle>
          <link href="#{base}/feed.xml" rel="self"/>
          <link href="#{base}/news/"/>
          <id>#{base}/news/</id>
          <updated>#{updated}</updated>
        #{items}</feed>
      XML
    end
  end

  class NewsPage < Jekyll::Page
    def initialize(site, dir, name, data, content = "")
      @site = site; @base = site.source; @dir = dir; @name = name
      process(@name)
      self.data = data
      self.content = content
    end
  end

  class NewsGenerator < Jekyll::Generator
    safe true
    priority :low       # after datasets.rb (site.data.catalog.index resolves a dataset's page URL)

    def generate(site)
      entries = News.build(site)
      site.data["log"] = entries
      site.pages << NewsPage.new(site, "/", "feed.xml", { "layout" => nil, "sitemap" => false }, News.atom(site, entries))
      Jekyll.logger.info "news:", "#{entries.size} entries (#{News::TYPES.map { |t| "#{entries.count { |e| e['type'] == t }} #{t}" }.join(' · ')})"
    end
  end
end
