/* door-search.js — ONE search over the catalog's three indexes (plan 2026-09-10 § D7 (3)).
 *
 * The box is #door-q inside #door-search; the three records are named on that element's
 * data-datasets / data-species / data-measurements attributes and fetched ONCE, on the first
 * focus — never at load, so the front door's first paint is untouched. A record that 404s (a
 * release with no species or no measurements catalog) simply contributes no group: the search
 * still works over the ones that answered, and nothing is invented.
 *
 * Results are grouped Datasets · Species · Measurements, four per group, with an "all n in …"
 * row that opens the group's own catalog. Enter opens the first hit; Escape closes; a click
 * anywhere else closes. Matching is a lower-cased indexOf over each row's prebuilt haystack —
 * the same rule assets/catalog.js and assets/species.js already use, so a reader who learns one
 * box has learned all three.
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
                 u: r.u, t: r.t || "" };
      });
    }
    return raw.map(function (r) {
      return { n: r.n, c: null,
               m: [r.c, r.r, r.y0 ? r.y0 + "–" + r.y1 : null,
                   r.o ? num(r.o) + " values" : null].filter(Boolean).join(" · "),
               u: r.u, t: r.t || "" };
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

  function render() {
    var q = box.value.trim().toLowerCase();
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
})();
