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
    var hay = [r.plain, r.name, r.full, r.cat, r.prov, r.prov_name].join(" ").toLowerCase();
    if (hay.indexOf(v) >= 0) return true;
    var t = (r.terms || "").split("|");
    for (var i = 0; i < t.length; i++) if (t[i].toLowerCase().indexOf(v) >= 0) return t[i];
    return false;
  }

  function apply() {
    var v = (q && q.value || "").trim().toLowerCase(), t = type ? type.value : "", n = 0, seen = {};
    // a search, a "Try" word or a type reads the whole list: on the tiles or an open category the hits were out of
    // sight, so the search seemed not to work (Betty 2026-11-18). Only the List's rows are filtered.
    if (t && listTab && listTab.getAttribute("aria-selected") !== "true") toList();
    [].slice.call(document.querySelectorAll("#bd-list .bd-r[data-k]")).forEach(function (a) {
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
    return '<div class="bd-pv-map">' + (m && m.svg ? m.svg.replace(/preserveAspectRatio="[^"]*"/, 'preserveAspectRatio="xMaxYMid meet"') + (m.n ? '<span class="bd-pv-cap">' + m.n + " station" + (m.n === 1 ? "" : "s") + " sampled</span>" : "")
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
  // the preview's year axis: the release's own span (data-span on the list, from Catalog#strip_span), else the rows'
  // own first and last years — never a typed year or the reader's clock
  var BSPAN = (function () {
    var s = ((list && list.getAttribute("data-span")) || "").split(",").map(Number).filter(Boolean);
    if (s.length === 2) return s;
    var a = ROWS.map(function (r) { return r.y0; }).filter(Boolean), b = ROWS.map(function (r) { return r.y1; }).filter(Boolean);
    return [Math.min.apply(null, a), Math.max.apply(null, b)];
  })();

  // Download: the dataset page's Download dialog (#download there: CSV first, Excel where it fits, Parquet, the
  // citation and licence in the zip — main's assets/download.js). The button reads "Download", so the three
  // actions stay on one line inside the 380 px preview (with the size written in it, "Full details" stuck 20 px
  // outside the card); what the default is ("CSV · 32.4 MB") is in its title and its accessible name
  function dlMenu(r) {
    var d = r.download;
    if (!d || !d.url) return "";
    return '<a class="bd-b2" href="' + esc(d.url) + '" aria-label="Download ' + esc(r.name) + ": " + esc(d.what) + ', or another format" title="' + esc(d.what) + ' · and other formats"><i class="cc-i cc-i-ui-download" aria-hidden="true"></i>Download</a>';
  }

  function select(key) {
    sel = key;
    rowsEls().forEach(function (a) { a.classList.toggle("on", a.dataset.k === key); a.setAttribute("aria-current", a.dataset.k === key ? "true" : "false"); });
    if (!pv) return;
    if (!key) { pv.hidden = true; return; }
    pv.innerHTML = preview(BY[key]); pv.hidden = false;
  }

  document.addEventListener("click", function (e) {
    // a category tile, a rail link, "All categories" (Betty 2026-11-18): open it in place
    var t = e.target.closest && e.target.closest(".bt-tile[data-cat], .bt-rail a[data-cat], [data-home]");
    if (t && !(e.metaKey || e.ctrlKey || e.shiftKey || e.button)) {
      e.preventDefault();
      if (t.hasAttribute("data-home")) showHome(true); else showCat(t.getAttribute("data-cat"), true);
      return;
    }
    // the ERDDAP fold in a row and its links are not "show this row"
    if (e.target.closest && e.target.closest("details, .bt-ext")) return;
    var a = e.target.closest && e.target.closest(".bd-r[data-k]");
    if (!a || e.metaKey || e.ctrlKey || e.shiftKey || e.button) return;
    if (pv && getComputedStyle(pv).display === "none") {
      // no preview (a phone, or a category's rows): a click anywhere on a row opens the dataset's page
      var go = !e.target.closest("a") && a.querySelector("a.bt-rn");
      if (go) location.href = go.href;
      return;
    }
    e.preventDefault(); select(a.dataset.k);
  });
  [].forEach.call(document.querySelectorAll(".bd-try [data-q]"), function (b) {
    b.addEventListener("click", function () { q.value = b.dataset.q; apply(); q.focus(); drop(); });
  });
  var clr = document.getElementById("bd-clear");
  if (clr) clr.addEventListener("click", function () { q.value = ""; if (type) type.value = ""; apply(); });
  if (q) q.addEventListener("input", function () { apply(); drop(); });

  // ── the dropdown under the search (Betty 2026-11-18): the datasets the words match, as they are typed ──
  var dd = document.getElementById("bd-dd"), ddAt = -1;
  function toList() { if (listTab && listTab.getAttribute("aria-selected") !== "true") listTab.click(); }
  function ddItems() { return dd ? [].slice.call(dd.querySelectorAll("[data-dd]")) : []; }
  function ddClose() { if (!dd) return; dd.hidden = true; ddAt = -1; if (q) q.setAttribute("aria-expanded", "false"); }
  function ddMark(i) {
    var it = ddItems(); ddAt = Math.max(-1, Math.min(i, it.length - 1));
    it.forEach(function (el, j) { el.classList.toggle("on", j === ddAt); el.setAttribute("aria-selected", j === ddAt ? "true" : "false"); });
    if (ddAt >= 0) it[ddAt].scrollIntoView({ block: "nearest" });
  }
  function drop() {
    if (!dd || !q) return;
    var v = q.value.trim().toLowerCase();
    if (!v) return ddClose();
    var hits = [];
    ROWS.forEach(function (r) {
      var m = hit(r, v);
      if (m) hits.push({ r: r, m: m, rank: m === true ? ((r.name || "").toLowerCase().indexOf(v) === 0 || (r.plain || "").toLowerCase().indexOf(v) === 0 ? 0 : 1) : 2 });
    });
    hits.sort(function (a, b) { return a.rank - b.rank || a.r.order - b.r.order; });
    var w = esc(q.value.trim()), h = "";
    if (hits.length) {
      h += '<div class="bd-dd-g">Datasets<span>' + hits.length + "</span></div>";
      hits.slice(0, 7).forEach(function (x) {
        var r = x.r, why = typeof x.m === "string" ? 'Has <mark>' + esc(x.m) + "</mark>" : esc(r.cat || "");
        h += '<a class="bd-dd-r" role="option" data-dd="' + esc(r.key) + '" href="' + esc(r.url || "#") + '">' +
          '<i class="cc-i cc-i-' + esc(r.icon || "cat-other") + '" aria-hidden="true"></i>' +
          '<span class="bd-dd-n"><b>' + esc(r.name) + (r.plain ? " <em>" + esc(r.plain) + "</em>" : "") + "</b><small>" + why + (r.years ? " · " + esc(r.years) : "") + "</small></span></a>";
      });
      h += '<button type="button" class="bd-dd-all" data-dd="all">See all ' + hits.length + ' in the list <span aria-hidden="true">↵</span></button>';
    } else {
      h += '<p class="bd-dd-none">No dataset matches &#8220;' + w + '&#8221;</p>';
    }
    var enc = encodeURIComponent(q.value.trim());
    h += '<div class="bd-dd-o"><a href="' + esc(dd.getAttribute("data-species")) + "?q=" + enc + '">Species named &#8220;' + w + '&#8221; →</a>' +
         '<a href="' + esc(dd.getAttribute("data-measurements")) + "?q=" + enc + '">Measurements named &#8220;' + w + '&#8221; →</a></div>';
    dd.innerHTML = h; dd.hidden = false; ddAt = -1; q.setAttribute("aria-expanded", "true");
  }
  function ddPick(el) {
    var k = el.getAttribute("data-dd");
    ddClose(); toList();
    if (k !== "all") { select(k); var row = document.querySelector('#bd-list .bd-r[data-k="' + k + '"]'); if (row) row.scrollIntoView({ block: "nearest" }); }
    else select(firstVisible());
    var v = document.getElementById("ts-ds-views"); if (v) v.scrollIntoView({ block: "start", behavior: "smooth" });
  }
  if (dd && q) {
    dd.addEventListener("click", function (e) {
      var el = e.target.closest("[data-dd]");
      if (!el || e.metaKey || e.ctrlKey || e.shiftKey || e.button) return; // a modified click opens the page itself
      e.preventDefault(); ddPick(el);
    });
    q.addEventListener("keydown", function (e) {
      if (e.key === "ArrowDown") { if (dd.hidden) drop(); e.preventDefault(); ddMark(ddAt + 1); }
      else if (e.key === "ArrowUp") { e.preventDefault(); ddMark(ddAt - 1); }
      else if (e.key === "Escape") ddClose();
      else if (e.key === "Enter") { e.preventDefault(); var it = ddItems(); ddPick(ddAt >= 0 ? it[ddAt] : (dd.querySelector('[data-dd="all"]') || { getAttribute: function () { return "all"; } })); }
    });
    q.addEventListener("focus", function () { if (q.value.trim()) drop(); });
    document.addEventListener("click", function (e) { if (!e.target.closest(".bd-qw") && !e.target.closest(".bd-try")) ddClose(); });
  }
  if (type) type.addEventListener("change", apply);
  if (sort) sort.addEventListener("change", function () { reorder(); select(firstVisible()); });

  // By category (Betty 2026-11-18): the tiles, or one category open with the preview beside it. Without
  // JavaScript every category is drawn under the tiles and each tile links to it.
  var find = document.getElementById("bd-find"), home = document.getElementById("bt-home");
  var cats = [].slice.call(document.querySelectorAll(".bt-cat"));
  var gridTab = document.getElementById("ds-view-tab-grid"), listTab = document.getElementById("ds-view-tab-list");
  function setUrl(slug) {
    try { var u = new URL(location.href); if (slug) u.searchParams.set("cat", slug); else u.searchParams.delete("cat"); u.hash = ""; history.replaceState(null, "", u.toString()); } catch (err) { /* an old browser keeps its URL */ }
  }
  function toTop() { var v = document.getElementById("ts-ds-views"); if (v && v.getBoundingClientRect().top < 0) v.scrollIntoView({ block: "start" }); }
  function showHome(user) {
    if (!home) return;
    home.hidden = false; cats.forEach(function (c) { c.hidden = true; });
    if (find) find.classList.add("bt-home-on");
    if (user) { setUrl(null); toTop(); }
  }
  function showCat(slug, user) {
    var sec = cats.filter(function (c) { return c.getAttribute("data-cat") === slug; })[0];
    if (!sec) return showHome(user);
    if (gridTab && gridTab.getAttribute("aria-selected") !== "true") gridTab.click();
    if (home) home.hidden = true;
    cats.forEach(function (c) { c.hidden = c !== sec; });
    if (find) find.classList.remove("bt-home-on");
    var first = sec.querySelector(".bd-r[data-k]");
    if (first) select(first.getAttribute("data-k"));
    if (user) { setUrl(slug); toTop(); }
  }
  // the List shows the preview; the tiles do not
  if (listTab) listTab.addEventListener("click", function () { if (find) find.classList.remove("bt-home-on"); });
  if (gridTab) gridTab.addEventListener("click", function () { if (find && home && !home.hidden) find.classList.add("bt-home-on"); });
  // ?cat= : a tile's slug, or a record category's name (a dataset page's breadcrumb)
  try {
    var c = new URL(location.href).searchParams.get("cat");
    var cm = c && cats.filter(function (x) { return x.getAttribute("data-cat") === c || (x.getAttribute("data-cats") || "").split("|").indexOf(c) >= 0; })[0];
    if (cm) showCat(cm.getAttribute("data-cat")); else showHome();
  } catch (err) { showHome(); }

  if (!sel) select(ROWS.length ? ROWS[0].key : null);
  if (mapsUrl && window.fetch) fetch(mapsUrl).then(function (r) { return r.json(); }).then(function (m) { maps = m; if (sel) select(sel); }).catch(function () { maps = {}; if (sel) select(sel); });
})();
