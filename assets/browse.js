/* Browse datasets (/datasets/, Betty 2026-11-14): search, type, sort and the preview.
   The rows are drawn by _layouts/datasets.html from site.data.browse; this script only hides,
   reorders and previews them. Each row is a link to its dataset page, so without this script the
   page still works: the click just opens the page instead of the preview. */
(function () {
  "use strict";
  var dataEl = document.getElementById("bd-rows");
  if (!dataEl) return;
  var ROWS = JSON.parse(dataEl.textContent), BY = {};
  ROWS.forEach(function (r, i) { r.order = i; BY[r.key] = r; });

  var q = document.getElementById("bd-q"), qn = document.getElementById("bd-qn");
  var type = document.getElementById("bd-type"), sort = document.getElementById("bd-sort");
  var list = document.getElementById("bd-list"), pv = document.getElementById("bd-pv");
  var empty = document.getElementById("bd-empty");
  var me = document.currentScript || document.querySelector("script[data-maps]");
  var mapsUrl = me && me.getAttribute("data-maps"), maps = null, sel = null;

  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function rowsEls() { return [].slice.call(document.querySelectorAll(".bd-r[data-k]")); }

  // keep each row's "what's in it" so a search can swap in "Has <match>" and put it back
  rowsEls().forEach(function (a) { var w = a.querySelector(".bd-rw"); if (w) w.setAttribute("data-orig", w.innerHTML); });

  function hit(r, v) {
    var hay = [r.name, r.full, r.cat, r.prov, r.prov_name].join(" ").toLowerCase();
    if (hay.indexOf(v) >= 0) return true;
    var t = (r.terms || "").split("|");
    for (var i = 0; i < t.length; i++) if (t[i].toLowerCase().indexOf(v) >= 0) return t[i];
    return false;
  }

  function apply() {
    var v = (q && q.value || "").trim().toLowerCase(), t = type ? type.value : "", n = 0, seen = {};
    rowsEls().forEach(function (a) {
      var r = BY[a.dataset.k], m = v ? hit(r, v) : true, show = !!m && (!t || r.realm === t);
      a.hidden = !show;
      var w = a.querySelector(".bd-rw");
      if (w) w.innerHTML = show && typeof m === "string" ? 'Has <mark>' + esc(m) + "</mark>" : w.getAttribute("data-orig");
      if (show && !seen[r.key]) { seen[r.key] = 1; n++; }
    });
    [].forEach.call(document.querySelectorAll(".bd-grp"), function (g) { g.hidden = !g.querySelector(".bd-r:not([hidden])"); });
    [].forEach.call(document.querySelectorAll(".bd-realm"), function (g) { g.hidden = !g.querySelector(".bd-grp:not([hidden])"); });
    if (qn) qn.textContent = n;
    if (empty) empty.hidden = n > 0;
    if (n && (!sel || !seen[sel])) select(firstVisible());
    say(n);
  }
  // what a screen reader hears after a search: one short line, once the typing pauses. The preview pane itself
  // is not a live region (it was: every keystroke queued the whole pane, thousands of characters)
  var sayEl = document.getElementById("bd-pv-say"), sayT = null;
  function say(n) {
    if (!sayEl) return;
    clearTimeout(sayT);
    sayT = setTimeout(function () {
      var r = sel && BY[sel], shown = pv && !pv.hidden && getComputedStyle(pv).display !== "none";
      sayEl.textContent = n + (n === 1 ? " dataset" : " datasets") + (n && r && shown ? ". Showing " + r.name + "." : ".");
    }, 500);
  }

  function firstVisible() { var a = list && list.querySelector(".bd-r:not([hidden])"); return a ? a.dataset.k : null; }

  var ORDER = {
    core: function (a, b) { return a.order - b.order; },
    az: function (a, b) { return a.name.localeCompare(b.name); },
    long: function (a, b) { return ((b.y0 ? b.y1 - b.y0 : -1) - (a.y0 ? a.y1 - a.y0 : -1)) || a.name.localeCompare(b.name); },
    recent: function (a, b) { return ((b.y1 || 0) - (a.y1 || 0)) || a.name.localeCompare(b.name); },
    cat: function (a, b) { return a.cat.localeCompare(b.cat) || a.order - b.order; }
  };
  function reorder() {
    if (!list) return;
    var f = ORDER[sort && sort.value] || ORDER.core;
    [].slice.call(list.children).sort(function (x, y) { return f(BY[x.dataset.k], BY[y.dataset.k]); }).forEach(function (a) { list.appendChild(a); });
  }

  function preview(r) {
    var m = maps && maps[r.key], f = "";
    if (r.depth) f += "<div><dt>Depth</dt><dd>" + esc(r.depth) + "</dd></div>";
    if (r.stations) f += "<div><dt>Stations</dt><dd>" + esc(r.stations) + "</dd></div>";
    if (r.records) f += "<div><dt>Records</dt><dd>" + esc(r.records) + "</dd></div>";
    return '<div class="bd-pv-map">' + (m && m.svg ? m.svg.replace(/preserveAspectRatio="[^"]*"/, 'preserveAspectRatio="xMidYMid meet"') + (m.n ? '<span class="bd-pv-cap">' + m.n + " station" + (m.n === 1 ? "" : "s") + " sampled</span>" : "")
             : '<span class="bd-pv-nomap">' + (maps ? "No station locations listed" : "") + "</span>") + "</div>" +
      '<div class="bd-pv-b"><span class="bd-pv-cat"><i class="cc-i cc-i-' + esc(r.icon) + '" aria-hidden="true"></i>' + esc(r.cat) + "</span>" +
      "<h2>" + esc(r.name) + "</h2>" + (r.full !== r.name ? '<p class="bd-pv-full">' + esc(r.full) + "</p>" : "") +
      '<p class="bd-pv-by">' + esc(r.prov_name) + "</p>" +
      (r.desc ? '<p class="bd-pv-desc">' + esc(r.desc) + "</p>" : "") +
      (r.has_long ? '<div class="bd-pv-has"><b>' + esc(r.has_label) + "</b>" + esc(r.has_long) + "</div>" : "") +
      '<div class="bd-pv-yr"><div><b>Years with data</b><span>' + esc(r.years || "not listed") + "</span></div>" + r.strip_big +
      '<div class="bd-pv-ax">' + axis() + "</div></div>" +
      (f ? '<dl class="bd-pv-f">' + f + "</dl>" : "") +
      '<div class="bd-pv-act">' + (r.explore ? '<a class="bd-b1" href="' + esc(r.explore) + '">View on map</a>' : "") +
      dlMenu(r) +
      '<a class="bd-b3" href="' + esc(r.url) + '">Full details →</a></div></div>';
  }
  function axis() {
    var w = BSPAN[1] - BSPAN[0] + 1, h = '<span style="left:0">' + BSPAN[0] + "</span>";
    [1970, 1990, 2010].forEach(function (y) { if (y > BSPAN[0] && y < BSPAN[1]) h += '<span style="left:' + ((y - BSPAN[0]) / w * 100).toFixed(1) + '%">' + y + "</span>"; });
    return h + '<span style="right:0">' + BSPAN[1] + "</span>";
  }
  var BSPAN = (function () { var a = ROWS.map(function (r) { return r.y0; }).filter(Boolean); return [Math.min.apply(null, a.concat([1949])), new Date().getFullYear()]; })();

  // Download: the dataset page's Download dialog (#download there: CSV first, Excel where it fits, Parquet, the
  // citation and licence in the zip — main's assets/download.js), named by what the default is ("CSV · 32.4 MB")
  function dlMenu(r) {
    var d = r.download;
    if (!d || !d.url) return "";
    return '<a class="bd-b2" href="' + esc(d.url) + '" aria-label="Download ' + esc(r.name) + ": " + esc(d.what) + ', or another format"><i class="cc-i cc-i-ui-download" aria-hidden="true"></i>Download<small>' + esc(d.what) + "</small></a>";
  }

  function select(key) {
    sel = key;
    rowsEls().forEach(function (a) { a.classList.toggle("on", a.dataset.k === key); a.setAttribute("aria-current", a.dataset.k === key ? "true" : "false"); });
    if (!pv) return;
    if (!key) { pv.hidden = true; return; }
    pv.innerHTML = preview(BY[key]); pv.hidden = false;
  }

  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest(".bd-r[data-k]");
    if (!a || e.metaKey || e.ctrlKey || e.shiftKey || e.button) return;
    if (pv && getComputedStyle(pv).display === "none") return; // a phone: no preview, so follow the link to the page
    e.preventDefault(); select(a.dataset.k);
  });
  [].forEach.call(document.querySelectorAll(".bd-try [data-q]"), function (b) {
    b.addEventListener("click", function () { q.value = b.dataset.q; apply(); q.focus(); });
  });
  var clr = document.getElementById("bd-clear");
  if (clr) clr.addEventListener("click", function () { q.value = ""; if (type) type.value = ""; apply(); });
  if (q) q.addEventListener("input", apply);
  if (type) type.addEventListener("change", apply);
  if (sort) sort.addEventListener("change", function () { reorder(); select(firstVisible()); });

  // a dataset page's breadcrumb links here as ?cat=<category>: open By category at that card
  try {
    var c = new URL(location.href).searchParams.get("cat");
    if (c) {
      var g = [].slice.call(document.querySelectorAll(".bd-grp")).find(function (x) { return x.dataset.cat === c; });
      var tab = document.getElementById("ds-view-tab-grid");
      if (g && tab) { tab.click(); setTimeout(function () { g.scrollIntoView({ block: "start" }); }, 0); }
    }
  } catch (err) { /* an old browser keeps the List */ }

  select(ROWS.length ? ROWS[0].key : null);
  if (mapsUrl && window.fetch) fetch(mapsUrl).then(function (r) { return r.json(); }).then(function (m) { maps = m; if (sel) select(sel); }).catch(function () { maps = {}; if (sel) select(sel); });
})();
