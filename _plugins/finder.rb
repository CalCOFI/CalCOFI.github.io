# frozen_string_literal: true

require "cgi"
require "json"

# The Species and Measurements finders (/species/, /measurements/; Betty 2026-11-15): the same shape as
# Browse datasets — a search band, a list, a preview beside it — and one download flow for all three.
#
# Writes two JSON files the pages read (assets/finder.js):
#   /species/finder.json       groups (the 22 classes), rows (every species), silhouettes, datasets
#   /measurements/finder.json  rows (every measurement), categories, datasets
#
# Every value is read from the release record (taxa.json, taxa_media.json, measurements.json,
# measurements_media.json, datasets.json), from disk: species.rb and measurements.rb replace their
# site.data keys with their own summaries, in an order that differs between platforms.
#
# The group names ("Bony fishes", "Seabirds" …) are the one thing typed here: the record names classes
# only scientifically. GROUP_NAMES is a draft for Ben / Erin to confirm; a class missing from it shows
# its scientific name.
module CalCOFI
  class FinderData < Jekyll::Generator
    safe false
    priority :low # after DatasetCatalog (:high), which builds the Catalog whose downloads this reuses

    GROUP_NAMES = {
      "Teleostei" => "Bony fishes", "Malacostraca" => "Crabs, shrimp & krill", "Cephalopoda" => "Squid & octopus",
      "Bacillariophyceae" => "Diatoms", "Aves" => "Seabirds", "Dinophyceae" => "Dinoflagellates",
      "Copepoda" => "Copepods", "Cyanophyceae" => "Cyanobacteria", "Coccolithophyceae" => "Coccolithophores",
      "Thaliacea" => "Salps", "Gastropoda" => "Snails & sea butterflies", "Appendicularia" => "Larvaceans",
      "Ostracoda" => "Seed shrimp", "Polychaeta" => "Bristle worms", "Mammalia" => "Marine mammals",
      "Pyramimonadophyceae" => "Green algae", "Hydrozoa" => "Hydrozoans", "Dictyochophyceae" => "Silicoflagellates",
      "Haptophyta incertae sedis" => "Other haptophytes", "Insecta" => "Insects",
      "Cryptophyta incertae sedis" => "Cryptophytes", "Xanthophyceae" => "Yellow-green algae"
    }.freeze
    UNITS = { "degC" => "°C", "kg/m3" => "kg/m³", "umol/kg" => "µmol/kg", "umol/L" => "µmol/L",
              "ml/L" => "mL/L", "mg/m3" => "mg/m³" }.freeze
    MEDIA_BASE = "https://storage.googleapis.com/calcofi-files-public/"

    def generate(site)
      @site = site
      ds = read("datasets")
      return unless ds && ds["datasets"]
      @cat = BrowseData.catalog
      @datasets = ds["datasets"].to_h { |d| [d["dataset_key"], d] }
      sp = species
      ms = measurements
      if sp
        # the silhouettes are most of the bytes (potrace paths), so they load second and fill in
        write(site, "species", JSON.generate(sp.except("sils")))
        write(site, "species", JSON.generate(sp["sils"]), "finder-sils.json")
      end
      write(site, "measurements", JSON.generate(ms)) if ms
      site.data["finder"] = { "species_groups" => sp && sp["groups"].size, "measurement_cats" => ms && ms["cats"].size,
                              "measurements" => ms && ms["rows"].size }
    end

    private

    def read(name)
      f = File.join(@site.source, "_data", "#{name}.json")
      File.exist?(f) ? JSON.parse(File.read(f)) : nil
    rescue JSON::ParserError
      nil
    end

    def write(site, dir, body, name = "finder.json")
      page = Jekyll::PageWithoutAFile.new(site, site.source, dir, name)
      page.content = "{% raw %}#{body}{% endraw %}"
      page.data["layout"] = nil
      page.data["sitemap"] = false
      site.pages << page
    end

    def since(k) = @datasets.dig(k, "since_version").to_s
    def ds_name(k) = @datasets.dig(k, "dataset_name_short") || @datasets.dig(k, "dataset_name") || k

    # core first, newest last — the same order as the Browse datasets list
    def core_sort(list, n_key)
      list.sort_by { |x| [since(x["dataset_key"]), -x[n_key].to_i] }
    end

    def years_of(h)
      (h || {}).select { |_, v| v.to_i.positive? }.keys.map(&:to_i).sort
    end

    # each dataset a finder row names: its short name and its page (the preview links the page, where a
    # CSV button beside every species or measurement downloads just that one)
    def files_for(keys)
      keys.uniq.to_h { |k| [k, { "name" => ds_name(k), "page" => "/datasets/#{k}/" }] }
    end

    def species
      rec = read("taxa")
      return nil unless rec && rec["taxa"]
      media = read("taxa_media") || {}
      mt = media["taxa"] || {}
      base = media["base"] || MEDIA_BASE
      tx = rec["taxa"]
      by = tx.to_h { |t| [t["taxon_key"], t] }
      sils = []
      sidx = {}
      sil_of = lambda do |key|
        t = by[key]
        s = nil
        while t && s.nil?
          s = mt.dig(t["taxon_key"], "silhouette")
          t = s ? t : by[t["parent_taxon_key"]]
        end
        next nil unless s && s["svg_inner"]
        sidx[s["svg_inner"]] ||= (sils << [s["viewBox"], s["svg_inner"]]).size - 1
      end
      # the species the record counts (`species_observed`): observed as the species itself, not only below it
      rows = tx.select { |t| t["rank"] == "Species" && t.dig("direct", "n_obs").to_i.positive? }.map do |t|
        f = mt[t["taxon_key"]] || {}
        ph = f["photo"]
        photo = ph && (Fmt.present(ph["cached"]) ? "#{base}#{ph['cached']}" : Fmt.present(ph["url"]))
        txt = f["text"] || {}
        cls = t.dig("lineage", "class") || "Other"
        dsl = core_sort(t["datasets"] || [], "n_obs").map do |d|
          [d["dataset_key"], d["year_min"], d["year_max"], d["n_obs"]]
        end
        {
          "k" => t["taxon_key"], "url" => "/species/#{t['slug']}/", "sci" => t["scientific_name"],
          "com" => Fmt.present(t["common_name"].to_s.strip), "cls" => cls, "grp" => GROUP_NAMES[cls] || cls,
          "n" => t.dig("rollup", "n_obs"), "y0" => t.dig("rollup", "year_min"), "y1" => t.dig("rollup", "year_max"),
          "years" => (t["datasets"] || []).flat_map { |d| years_of(d["years"]) }.uniq.sort,
          "ds" => dsl, "stages" => t.dig("direct", "life_stages") || [],
          "photo" => photo, "photo_lic" => ph && Fmt.present(ph["license"]),
          "sil" => sil_of.(t["taxon_key"]),
          "text" => Fmt.present(txt["extract"].to_s[0, 420]), "wiki" => Fmt.present(txt["url"]),
          "size" => f.dig("size", "m"),
          # the Explorer opens prefilled only for an authority key (species.rb `ways`, the same rule)
          "map" => (t["taxon_key"].start_with?("worms:", "itis:") ? "?taxon=#{t['taxon_key']}" : nil)
        }
      end
      rows.sort_by! { |r| -r["n"].to_i }
      groups = tx.select { |t| t["rank"] == "Class" && t.dig("rollup", "n_obs").to_i.positive? }
                 .sort_by { |t| -t.dig("rollup", "n_obs").to_i }.map do |t|
        c = t["scientific_name"]
        top = rows.select { |r| r["cls"] == c }.first(3).map { |r| r["com"] || r["sci"] }
        first = rows.find { |r| r["cls"] == c }
        { "cls" => c, "grp" => GROUP_NAMES[c] || c, "n_sp" => t.dig("rollup", "n_species").to_i,
          "n_taxa" => t.dig("rollup", "n_taxa").to_i, "n" => t.dig("rollup", "n_obs"),
          "top" => top, "sil" => sil_of.(t["taxon_key"]) || (first && first["sil"]) }
      end
      { "release" => rec.dig("release", "version"), "counts" => rec["counts"], "groups" => groups, "rows" => rows,
        "sils" => sils, "files" => files_for(rows.flat_map { |r| r["ds"].map(&:first) }) }
    end

    def measurements
      rec = read("measurements")
      return nil unless rec && rec["measurements"]
      med = (read("measurements_media") || {})["sources"] || {}
      cov = read("release_coverage")
      ekeys = (cov.is_a?(Hash) ? cov["variables"] || [] : []).select { |v| v["realm"] == "env" }
                .filter_map { |v| Fmt.present(v["variable"]) || Fmt.present(v["measurement_type"]) }
      cats = []
      rows = rec["measurements"].map do |m|
        tt = m["totals"] || {}
        nerc = med.dig(m["key"], "nerc") || {}
        se = core_sort(m["series"] || [], "n_values")
        c = m["category"] || {}
        cats << { "name" => c["name"], "icon" => c["icon"], "order" => c["order"] } unless cats.any? { |x| x["name"] == c["name"] }
        {
          "k" => m["key"], "url" => "/measurements/#{m['slug']}/", "lab" => m["short_label"] || m["label"],
          "full" => m["label"], "desc" => Fmt.present(m["description"]), "units" => UNITS[m["units"]] || m["units"],
          "cat" => c["name"], "unified" => !!m["is_unified"],
          "n" => tt["n_values"], "y0" => tt["year_min"], "y1" => tt["year_max"],
          "dmin" => tt["depth_min_m"], "dmax" => tt["depth_max_m"],
          "years" => se.flat_map { |s| years_of(s["years"]) }.uniq.sort,
          "ds" => se.map { |s| [s["dataset_key"], s["year_min"], s["year_max"], s["n_values"]] },
          "defn" => Fmt.present(nerc["definition"].to_s[0, 380]), "nerc" => Fmt.present(nerc["pref"]),
          # only a key the Explorer's picker carries (measurements.rb `explorer_keys`, the same rule)
          "map" => (ekeys.include?(m["key"]) ? "?var=#{CGI.escape(m['key'])}" : nil)
        }
      end
      rows.sort_by! { |r| -r["n"].to_i }
      { "release" => rec.dig("release", "version"), "counts" => rec["counts"], "rows" => rows,
        "cats" => cats.sort_by { |c| c["order"].to_i }, "files" => files_for(rows.flat_map { |r| r["ds"].map(&:first) }) }
    end
  end
end
