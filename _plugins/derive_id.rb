# _plugins/derive_id.rb — the identifier a portal calls a dataset by, read off its own URL.
#
# Archives & portals lists Portal · Identifier · Title · Status (plan D-6, Decision 8), and the
# identifier is the thing a person actually needs: `edi.109.4`, `gov.noaa.nodc:0301029`,
# `erdCalCOFIlrvcnt`. The record carries it on `distributions[]` (`id`) but NOT on
# `registrations[]` — calcofi4db 4.5.0 adds `registrations[].id` and `.title` (plan D-9, UI-D), and
# derives them with these same rules so the two agree. Until that release renders, this is the
# site's fallback.
#
#   # until the record carries registrations[].id (calcofi4db 4.5.0 / schema 1.1, plan D-9) —
#   # delete this file and its test in the release's hand-back
#
# No Jekyll dependency on purpose: `_test/derive_id_test.rb` requires this file alone, so the rule
# that decides what a portal calls a dataset is unit-tested rather than eyeballed on a page.
module CalCOFI
  module DeriveId
    module_function

    # url → the portal's own identifier, or nil when the URL says nothing (a bare portal home, a
    # search page). nil is rendered as an em dash, never as a guess.
    def call(url)
      return nil if url.nil? || url.to_s.strip.empty?
      u = url.to_s

      # EDI — two URL shapes for the same thing: a packageid, or scope + identifier (+ revision)
      if u.include?("edirepository.org")
        if (m = u[/[?&]packageid=([^&#]+)/, 1])
          return unescape(m)
        end
        scope = u[/[?&]scope=([^&#]+)/, 1]
        ident = u[/[?&]identifier=([^&#]+)/, 1]
        rev   = u[/[?&]revision=([^&#]+)/, 1]
        return [scope, ident, rev].compact.join(".") if scope && ident
        return nil
      end

      # NCEI — the accession id lives in the query string
      return unescape(m) if u.include?("ncei.noaa.gov") && (m = u[/[?&]id=([^&#]+)/, 1])

      # OBIS — /dataset/{uuid}
      return m if (m = u[%r{obis\.org/dataset/([0-9a-fA-F-]{36})}, 1])

      # a GBIF/OBIS IPT resource — ?r={shortname}
      return unescape(m) if u.include?("ipt") && (m = u[/[?&]r=([^&#]+)/, 1])

      # a DOI, wherever it is hosted (Zenodo, Stanford, a publisher)
      return m if (m = u[%r{doi\.org/(10\.[^\s?#]+)}, 1])

      # CalOOS — the uuid after the hash route, which may carry a second, deeper uuid
      return m if (m = u[%r{#module-metadata/([0-9a-fA-F-]{36})}, 1])

      # any ERDDAP: a tabledap/griddap page, an info page, or a metadata document
      return m if (m = u[%r{/(?:tabledap|griddap)/([A-Za-z0-9_.-]+?)(?:\.\w+)?(?:$|[?#])}, 1])
      return m if (m = u[%r{/erddap/info/([A-Za-z0-9_.-]+)/}, 1])
      return m if (m = u[%r{/erddap/metadata/\w+/xml/([A-Za-z0-9_.-]+?)_(?:iso19115|fgdc)\.xml}, 1])

      # DataZoo — /datasets/{n}
      return m if (m = u[%r{datazoo/catalogs/[^/]+/datasets/(\d+)}, 1])

      # NCBI BioProject — /bioproject/{n}
      return "PRJNA#{m}" if (m = u[%r{ncbi\.nlm\.nih\.gov/bioproject/(\d+)}, 1])

      nil
    end

    def unescape(s)
      s.to_s.gsub(/%([0-9a-fA-F]{2})/) { [Regexp.last_match(1).hex].pack("C") }
    end
  end
end
