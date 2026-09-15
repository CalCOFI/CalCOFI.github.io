/* door-search.js — ONE search over the catalog's three indexes (plan 2026-09-10 § D7 (3); round 2
 * D9/D4/D5, umbrella plan 2026-09-15).
 *
 * The box is #door-q inside #door-search; the three records are named on that element's
 * data-datasets / data-species / data-measurements attributes and fetched ONCE, on the first
 * focus (or on load if ?q= is already on the URL) — never at load otherwise, so the front door's
 * first paint is untouched. A record that 404s (a release with no species or no measurements
 * catalog) simply contributes no group: the search still works over the ones that answered, and
 * nothing is invented.
 *
 * The dropdown listbox (#door-res) stays for keyboard users — four per group, Enter opens the
 * first hit, Escape closes, a click anywhere else closes. Matching is a lower-cased indexOf over
 * each row's prebuilt haystack — the same rule assets/catalog.js and assets/species.js already
 * use, so a reader who learns one box has learned all three.
 *
 * D9: the query ALSO writes into the open tab's own panel — #door-species-results and
 * #door-measurements-results, up to 50 rows sorted by observations, R1's result_row.html shape
 * built here in JS (rowsFrom() already normalises a hit to {n, c, it, m, u}; `o` is the raw
 * observation/value count kept alongside for the sort). Both panels are kept in sync with every
 * keystroke regardless of which tab is showing, so switching tabs never needs a re-render of its
 * own — the panel is already right when it becomes visible. An empty box restores each panel's
 * own head (hidden via a sibling #door-<key>-body wrapper in index.html). The Datasets tab is
 * unchanged: catalog.js reads the same #door-q and filters the grid itself.
 */
(function () {
  "use strict";

  var host = document.getElementById("door-search");
  if (!host) return;
  var box = document.getElementById("door-q"), res = document.getElementById("door-res");
  if (!box || !res) return;

  var PER = 4;
  var GROUPS = [
    { id: "D", key: "datasets", title: "Datasets", all: "/datasets/" },
    { id: "S", key: "species", title: "Species", all: host.getAttribute("data-species-url") || "/species/" },
    { id: "M", key: "measurements", title: "Measurements", all: host.getAttribute("data-measurements-url") || "/measurements/" }
  ];

  var loaded = false, loading = null;

  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  }
  function num(n) { return Number(n || 0).toLocaleString("en-US"); }

  // each record has its own shape; normalise to {n, c, m, u, t} — name, qualifier, meta, url,
  // haystack. The dataset record is /datasets/search.json, already built for catalog.js.
  function rowsFrom(g, body) {
    var raw = (body && body.rows) || [];
    if (g.id === "D") {
      return raw.map(function (r) {
        return { n: r.short || r.name, c: null,
                 m: [r.cat, r.prov].filter(Boolean).join(" · "),
                 u: r.url, t: r.text || "" };
      });
    }
    if (g.id === "S") {
      return raw.map(function (r) {
        return { n: r.n, c: r.c, it: r.r === "Species" || r.r === "Genus",
                 m: [r.r, r.o ? num(r.o) + " obs" : null,
                     r.d ? r.d + (r.d === 1 ? " dataset" : " datasets") : null].filter(Boolean).join(" · "),
                 u: r.u, t: r.t || "", o: r.o || 0 };
      });
    }
    return raw.map(function (r) {
      return { n: r.n, c: null,
               m: [r.c, r.r, r.y0 ? r.y0 + "–" + r.y1 : null,
                   r.o ? num(r.o) + " values" : null].filter(Boolean).join(" · "),
               u: r.u, t: r.t || "", o: r.o || 0 };
    });
  }

  function load() {
    if (loading) return loading;
    loading = Promise.all(GROUPS.map(function (g) {
      var url = host.getAttribute("data-" + g.key);
      if (!url) { g.rows = []; return null; }
      return fetch(url, { credentials: "same-origin" })
        .then(function (r) { return r.ok ? r.json() : null; })
        .then(function (b) { g.rows = b ? rowsFrom(g, b) : []; })
        .catch(function () { g.rows = []; });     // unreachable is not a fact: no group, no error
    })).then(function () { loaded = true; });
    return loading;
  }

  function close() {
    res.classList.remove("open");
    box.setAttribute("aria-expanded", "false");
  }

  // D9: the two panels the front door's Species and Measurements tabs render results into. Each
  // has a sibling "body" element (the tab's own headline/counts/link) that hides while a query is
  // non-empty, so the panel reads as one thing replacing the other, never both at once.
  var RESULT_PANELS = {
    S: { host: document.getElementById("door-species-results"), body: document.getElementById("door-species-body") },
    M: { host: document.getElementById("door-measurements-results"), body: document.getElementById("door-measurements-body") }
  };

  function resultRow(r) {
    var name = r.it ? '<b class="cc-result-n"><i>' + esc(r.n) + "</i></b>" : '<b class="cc-result-n">' + esc(r.n) + "</b>";
    var c = r.c ? ' <span class="cc-result-c">' + esc(r.c) + "</span>" : "";
    return '<a class="cc-result" href="' + esc(r.u) + '">' + name + c +
           '<span class="cc-result-m tab">' + esc(r.m) + "</span></a>";
  }

  function renderPanel(g, q) {
    var slot = RESULT_PANELS[g.id];
    if (!slot || !slot.host) return;
    if (!q) {
      slot.host.hidden = true; slot.host.innerHTML = "";
      if (slot.body) slot.body.hidden = false;
      return;
    }
    var rows = (g.rows || []).filter(function (r) { return r.t.indexOf(q) >= 0; })
                              .sort(function (a, b) { return b.o - a.o; });
    var html = '<p class="cc-eyebrow">' + num(rows.length) + " match" + (rows.length === 1 ? "" : "es") +
               (rows.length ? " · by observations" : "") + "</p>";
    if (rows.length) {
      html += rows.slice(0, 50).map(resultRow).join("");
      var all = g.all + (g.all.indexOf("?") >= 0 ? "&" : "?") + "q=" + encodeURIComponent(box.value);
      html += '<p><a class="cc-text-link" href="' + esc(all) + '">all ' + num(rows.length) + " in " + esc(g.title) + " →</a></p>";
    } else {
      html += '<p class="cc-muted">Nothing named that in ' + esc(g.title) + " — try a common name, a genus or a NERC id.</p>";
    }
    slot.host.innerHTML = html;
    slot.host.hidden = false;
    if (slot.body) slot.body.hidden = true;
  }

  function render() {
    var q = box.value.trim().toLowerCase();
    renderPanel(GROUPS[1], q);   // Species
    renderPanel(GROUPS[2], q);   // Measurements
    if (!q) { res.innerHTML = ""; close(); return; }
    var html = "", any = false;
    GROUPS.forEach(function (g) {
      var rows = g.rows || [];
      if (!rows.length) return;
      var hits = rows.filter(function (r) { return r.t.indexOf(q) >= 0; });
      if (!hits.length) return;
      any = true;
      html += '<div class="dres-g"><span>' + esc(g.title) + "</span><span>" +
              num(hits.length) + " of " + num(rows.length) + "</span></div>";
      hits.slice(0, PER).forEach(function (r) {
        var name = r.it ? '<i class="sci">' + esc(r.n) + "</i>" : esc(r.n);
        html += '<a class="dres-r" role="option" href="' + esc(r.u) + '">' +
                '<span class="dres-k">' + g.id + "</span>" +
                '<span class="dres-n">' + name + (r.c ? "<i>" + esc(r.c) + "</i>" : "") + "</span>" +
                '<span class="dres-m">' + esc(r.m) + "</span></a>";
      });
      if (hits.length > PER) {
        html += '<a class="dres-r dres-all" role="option" href="' + esc(g.all) + '">' +
                '<span class="dres-k">→</span><span class="dres-n cc-muted">all ' +
                num(hits.length) + " in " + esc(g.title) + " …</span><span class=\"dres-m\"></span></a>";
      }
    });
    res.innerHTML = any ? html
      : '<div class="dres-none">Nothing named that in the three indexes — try a common name, a genus, ' +
        "a variable, a NERC id or a dataset.</div>";
    res.classList.add("open");
    box.setAttribute("aria-expanded", "true");
  }

  function open() {
    if (loaded) { render(); return; }
    load().then(render);
  }

  box.addEventListener("focus", open);
  box.addEventListener("input", open);
  box.addEventListener("keydown", function (e) {
    if (e.key === "Escape") { close(); box.blur(); return; }
    if (e.key === "Enter") {
      var first = res.querySelector("a.dres-r");
      if (first) { e.preventDefault(); first.click(); }
      return;
    }
    if (e.key === "ArrowDown") {
      var a = res.querySelector("a.dres-r");
      if (a) { e.preventDefault(); a.focus(); }
    }
  });
  res.addEventListener("keydown", function (e) {
    if (e.key !== "ArrowDown" && e.key !== "ArrowUp" && e.key !== "Escape") return;
    if (e.key === "Escape") { close(); box.focus(); return; }
    var all = [].slice.call(res.querySelectorAll("a.dres-r"));
    var i = all.indexOf(document.activeElement);
    if (i < 0) return;
    e.preventDefault();
    var n = all[e.key === "ArrowDown" ? Math.min(i + 1, all.length - 1) : i - 1];
    (n || box).focus();
  });
  document.addEventListener("click", function (e) {
    if (!e.target.closest || !e.target.closest("#door-search")) close();
  });

  // D9: a shared link — `?q=sardine&tab=species` — lands with the box already filled and the
  // panels already rendered; the tab itself is tabs.js's own ?tab= restore, independent of this.
  try {
    var q0 = new URLSearchParams(location.search).get("q");
    if (q0) { box.value = q0; open(); }
  } catch (e) { /* no URL API: the box starts empty, as before */ }
})();
