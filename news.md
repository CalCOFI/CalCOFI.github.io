---
layout: default
title: "CalCOFI.io — the ship's log"
description: "Releases of the CalCOFI integrated database, datasets entering it, apps and features as they land — news that mostly writes itself from the release record."
permalink: /news/
---
<section class="cc-band news-page">
  <div class="cc-container">
    <div class="cc-eyebrow">The ship's log · {{ site.data.log | size }} entries</div>
    <h1 class="cc-h1">What's new</h1>
    <p class="blurb">Releases of the integrated database, datasets entering it, apps and features as they land. Most
      entries are generated from data the site already carries — the release history, each dataset's first
      release, the products as they were added — with a hand-written line for a feature or a change to the
      site. Program news — cruises, people, papers — stays on
      <a class="cc-text-link" href="https://calcofi.org/about/news-updates/">calcofi.org ↗</a>.
      <a class="cc-text-link" href="{{ '/feed.xml' | relative_url }}">Atom feed</a>
    </p>
    <h2 class="sr-only">All entries</h2>
    {% include log.html filter=true %}
  </div>
</section>
<script defer src="{{ '/assets/news.js' | relative_url }}"></script>
