/* assets/catalog.js — the dataset grid's filter row and search. Plain JS, no framework.
   The DOM already carries the facet values as data-* on every row; the free-text search needs the
   descriptions, keywords and variables that are NOT in the DOM, so it fetches /datasets/search.json
   (one small file, 16–33 rows) the first time someone types. Filtering works with the fetch still in
   flight — it just matches on the visible text until the index lands.
   Every filter is reflected in the URL query so a filtered grid is a link you can share.
   The reference frame is a band below the grid (plan D-2), not a tile inside it, so it is outside
   #ds-grid and the filters never see it — which is what they always did, by a special case that is
   now unnecessary. */
(function () {
  "use strict";
  var form = document.getElementById("ds-filters");
  var grid = document.getElementById("ds-grid");
  if (!form || !grid) return;

  var rows   = Array.prototype.slice.call(grid.querySelectorAll(".ds-row[data-key]"));
  var tiles  = Array.prototype.slice.call(grid.querySelectorAll(".ds-tile"));
  var q      = document.getElementById("ds-q");
  var count  = document.getElementById("ds-count");
  var empty  = document.getElementById("ds-empty");
  var selects = Array.prototype.slice.call(form.querySelectorAll("select[data-facet]"));
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
    var s = { q: (q.value || "").trim().toLowerCase() };
    selects.forEach(function (el) { s[el.dataset.facet] = el.value; });
    return s;
  }

  function apply() {
    var state = read(), shown = 0;
    rows.forEach(function (row) {
      var ok = matches(row, state);
      row.hidden = !ok;
      if (ok && row.getAttribute("data-kind") === "dataset") shown++;
    });
    // a tile with nothing left to show goes away, separators with it
    tiles.forEach(function (tile) {
      var any = tile.querySelectorAll(".ds-row[data-key]:not([hidden])").length;
      tile.hidden = !any;
      Array.prototype.forEach.call(tile.querySelectorAll(".ds-rows-sep"), function (sep) {
        var next = sep.nextElementSibling, live = false;
        while (next && next.classList.contains("ds-row")) {
          if (!next.hidden) { live = true; break; }
          next = next.nextElementSibling;
        }
        sep.hidden = !live;
      });
    });
    // "and n more" holds rows too: a filter that matches only those should open it
    Array.prototype.forEach.call(grid.querySelectorAll(".ds-holdings-det"), function (det) {
      var live = det.querySelectorAll(".ds-row[data-key]:not([hidden])").length;
      var filtered = !!(state.q || selects.some(function (el) { return el.value; }));
      det.parentNode.hidden = !live;
      if (filtered && live) det.open = true;
    });
    if (count) count.textContent = shown + " dataset" + (shown === 1 ? "" : "s") + " shown";
    if (empty) empty.hidden = shown > 0;
    sync(state);
    // the grid's spans are wrong the moment a row is hidden — assets/masonry.js listens for this
    document.dispatchEvent(new CustomEvent("ds:filtered"));
  }

  function sync(state) {
    var p = new URLSearchParams();
    Object.keys(state).forEach(function (k) { if (state[k]) p.set(k, state[k]); });
    var qs = p.toString();
    history.replaceState(null, "", qs ? "?" + qs + location.hash : location.pathname + location.hash);
  }

  function restore() {
    var p = new URLSearchParams(location.search);
    if (p.get("q")) q.value = p.get("q");
    selects.forEach(function (el) {
      var v = p.get(el.dataset.facet);
      if (v) el.value = v;
    });
  }

  form.addEventListener("input", function (e) {
    if (e.target === q) { loadIndex().then(apply); return; }
    apply();
  });
  form.addEventListener("change", apply);

  function clear() {
    q.value = "";
    selects.forEach(function (el) { el.value = ""; });
    apply();
  }
  ["ds-clear", "ds-clear2"].forEach(function (id) {
    var b = document.getElementById(id);
    if (b) b.addEventListener("click", clear);
  });

  restore();
  if (q.value) loadIndex().then(apply); else apply();
})();
