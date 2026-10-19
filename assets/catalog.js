/* assets/catalog.js — the dataset catalog's filter and search. Plain JS, no framework.
   The DOM already carries the facet values as data-* on every row; the free-text search needs the
   descriptions, keywords and variables that are NOT in the DOM, so it fetches /datasets/search.json
   (one small file, 16–33 rows) the first time someone types. Filtering works with the fetch still in
   flight — it just matches on the visible text until the index lands.
   Every filter is reflected in the URL query so a filtered catalog is a link you can share; the
   URL's other parameters (the view tab's ?tab=) are kept.

   Rows live in up to three places, and one filter drives them all:
     #ds-list      /datasets/'s calm list (issue #30): details.ds-item rows in two realm groups
     #ds-grid      the category tiles — /datasets/'s "By category" view, and the front door's grid
     #ds-holdings  /datasets/'s holdings fold (rung 3 rows, outside both)
   The query comes from the one search box (#door-q, _includes/one_search.html, D10 B), which lives
   OUTSIDE the facet form; `qState` is the fallback when there is no #door-q, so a shared `?q=` link
   still filters once on load. On /datasets/ the facets sit behind a "Filter" button (#ds-filter-btn);
   a link that arrives with a facet set opens them, so the reader sees why rows are missing. */
(function () {
  "use strict";
  var form = document.getElementById("ds-filters");
  var list = document.getElementById("ds-list");
  var grid = document.getElementById("ds-grid");
  var held = document.getElementById("ds-holdings");
  if (!form || !(list || grid)) return;

  var scopes = [list, grid, held].filter(Boolean);
  var rows   = [];
  scopes.forEach(function (s) { rows = rows.concat([].slice.call(s.querySelectorAll("[data-key][data-kind]"))); });
  var tiles  = grid ? [].slice.call(grid.querySelectorAll(".ds-tile")) : [];
  var q      = document.getElementById("door-q");
  var qState = "";
  var count  = document.getElementById("ds-count");
  var hint   = document.querySelector("#door-search .dsearch-k");
  var empty  = document.getElementById("ds-empty");
  var btn    = document.getElementById("ds-filter-btn");
  var selects = [].slice.call(form.querySelectorAll("select[data-facet]"));
  var KEYS   = ["q"].concat(selects.map(function (el) { return el.dataset.facet; }));
  var index  = null;            // key -> haystack, from search.json
  var src    = (document.currentScript && document.currentScript.dataset.search) || "/datasets/search.json";

  function loadIndex() {
    if (index) return Promise.resolve(index);
    return fetch(src, { credentials: "same-origin" })
      .then(function (r) { return r.ok ? r.json() : { rows: [] }; })
      .then(function (d) {
        index = {};
        (d.rows || []).forEach(function (r) { index[r.key] = r.text || ""; });
        return index;
      })
      .catch(function () { index = {}; return index; });
  }

  // the query text, wherever it lives: #door-q's value when the element exists, else the state
  // read from ?q= on load (restore())
  function currentQ() { return q ? q.value.trim().toLowerCase() : qState; }

  // a row matches when every set filter matches; data-fmt is space-separated
  function matches(row, state) {
    for (var i = 0; i < selects.length; i++) {
      var f = selects[i].dataset.facet, want = state[f];
      if (!want) continue;
      var have = row.getAttribute("data-" + f) || "";
      if (f === "fmt") { if (have.split(" ").indexOf(want) < 0) return false; }
      else if (have !== want) return false;
    }
    if (state.q) {
      var key = row.getAttribute("data-key");
      var hay = (row.textContent + " " + key + " " + ((index && index[key]) || "")).toLowerCase();
      if (hay.indexOf(state.q) < 0) return false;
    }
    return true;
  }

  function read() {
    var s = { q: currentQ() };
    selects.forEach(function (el) { s[el.dataset.facet] = el.value; });
    return s;
  }

  function each(root, sel, fn) { if (root) [].forEach.call(root.querySelectorAll(sel), fn); }

  function apply() {
    var state = read(), seen = {};
    var filtered = !!(state.q || selects.some(function (el) { return el.value; }));
    rows.forEach(function (row) {
      var ok = matches(row, state);
      row.hidden = !ok;
      if (ok && row.getAttribute("data-kind") === "dataset") seen[row.getAttribute("data-key")] = 1;
    });
    var shown = Object.keys(seen).length;
    // the list: a realm group with nothing left to show goes away with its heading
    each(list, ".ds-realm-grp", function (g) { g.hidden = !g.querySelector("[data-key]:not([hidden])"); });
    // the grid: a tile, then a realm column, with nothing left to show goes away
    tiles.forEach(function (tile) { tile.hidden = !tile.querySelector(".ds-row[data-key]:not([hidden])"); });
    each(grid, ".ds-realm", function (col) { col.hidden = !col.querySelector(".ds-tile:not([hidden])"); });
    // the holdings are collapsed: a filter that matches only those should open the block, and a
    // block with nothing left in it goes away with its summary (one-way: never force-closed)
    each(grid, ".ds-holdings-det", function (det) {
      var live = det.querySelectorAll(".ds-row[data-key]:not([hidden])").length;
      det.parentNode.hidden = !live;
      if (filtered && live) det.open = true;
    });
    if (held) {
      var liveH = held.querySelectorAll("[data-key]:not([hidden])").length;
      held.hidden = filtered && !liveH;
      if (filtered && liveH && !shown) held.open = true;
    }
    // D3: a search hit inside a grid row's own variables/taxa expander opens it — the names stay
    // in the DOM whether the <details> is open or closed, so the hit is real; this only ever opens
    if (state.q) {
      each(grid, ".ds-vars", function (det) {
        if (det.textContent.toLowerCase().indexOf(state.q) >= 0) det.open = true;
      });
    }
    if (count) count.textContent = shown + " dataset" + (shown === 1 ? "" : "s") + " shown";
    if (hint) hint.textContent = String(shown);
    if (empty) empty.hidden = shown > 0;
    sync(state);
    // the front door's grid packing listens for this
    document.dispatchEvent(new CustomEvent("ds:filtered"));
  }

  // only this script's own keys are written; anything else on the URL (?tab=) stays
  function sync(state) {
    var p = new URLSearchParams(location.search);
    KEYS.forEach(function (k) { if (state[k]) p.set(k, state[k]); else p.delete(k); });
    var qs = p.toString();
    history.replaceState(null, "", qs ? "?" + qs + location.hash : location.pathname + location.hash);
  }

  function restore() {
    var p = new URLSearchParams(location.search), any = false;
    var got = p.get("q");
    if (got) { if (q) q.value = got; else qState = got.trim().toLowerCase(); }
    selects.forEach(function (el) {
      var v = p.get(el.dataset.facet);
      if (v) { el.value = v; any = any || !!el.value; }
    });
    if (any) showFacets(true);
  }

  function showFacets(on) {
    if (!btn) return;
    form.hidden = !on;
    btn.setAttribute("aria-expanded", on ? "true" : "false");
  }
  if (btn) btn.addEventListener("click", function () {
    var on = form.hidden;
    showFacets(on);
    if (on) { var s = form.querySelector("select"); if (s) s.focus(); }
  });

  // the selects live in this form; #door-q (when present) does not — it is outside #ds-filters,
  // shared with assets/door-search.js, so it gets its own listener rather than relying on bubbling
  form.addEventListener("input", apply);
  form.addEventListener("change", apply);
  if (q) q.addEventListener("input", function () { loadIndex().then(apply); });

  function clear() {
    if (q) q.value = ""; else qState = "";
    selects.forEach(function (el) { el.value = ""; });
    apply();
  }
  ["ds-clear", "ds-clear2"].forEach(function (id) {
    var b = document.getElementById(id);
    if (b) b.addEventListener("click", clear);
  });

  restore();
  if (currentQ()) loadIndex().then(apply); else apply();
})();
