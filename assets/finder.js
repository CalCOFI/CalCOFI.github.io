/* The Species and Measurements finders (/species/, /measurements/; Betty 2026-11-15).
   One search band, a list, and a preview beside it, as on Browse datasets. The rows come from
   /species/finder.json or /measurements/finder.json (_plugins/finder.rb). No download here (Betty
   2026-11-16): each dataset in the preview links its page, which has a CSV button per species or
   measurement. The older views (the tree, the matrix, the hierarchy, the timeline) stay as tabs and
   are drawn by species.js / measurements.js as before.

   Measurements, By category (issue #30 D8, back on 2026-11-17): the categories are CLOSED groups, each
   a button saying its name, what is inside and how many; a press opens one, a search opens the ones
   that hold a match and leaves the others out. With nothing chosen the preview says to choose.

   Species, a search (2026-11-17): the list stays species; the taxa with a page that are not species
   rows (a genus, a family, an order …, /species/finder-taxa.json) are listed under it, each a link
   to its page. */
(function () {
  "use strict";
  var root = document.getElementById("cf");
  if (!root) return;
  var KIND = root.getAttribute("data-kind"), SP = KIND === "species";
  // the previews' year axis: the release's own span (data-span, from Catalog#strip_span), else the rows' own first
  // and last years once they load — never a typed year or the reader's clock
  var SPAN = (root.getAttribute("data-span") || "").split(",").map(Number).filter(Boolean);
  var Y0 = SPAN[0] || 0, Y1 = SPAN[1] || 0, W;
  var D = null, q = "", grp = "", sel = null, view = SP ? "groups" : "cat";
  // measurements, By category: the categories the reader opened, the ones they shut during the search
  // in the box now, and whether the row in the preview is one they chose (a row chosen stays in view)
  var open = {}, shutQ = {}, chose = false;
  // species: the taxa that are not rows (finder-taxa.json; loaded second, read only by a search)
  var T = null, HI_MAX = 40;
  /* the search box is #door-q, so species.js and measurements.js fold the tree and the timeline to it too */
  var input = document.getElementById("door-q"), count = document.getElementById("cf-n");
  var TS = document.getElementById(root.getAttribute("data-tabset")), V = SP ? ["groups", "list"] : ["cat", "az"];

  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function n(x) { return Number(x || 0).toLocaleString("en-US"); }
  function big(x) { if (!x) return "0"; if (x >= 1e6) return (x / 1e6).toFixed(1) + "M"; if (x >= 1e4) return Math.round(x / 1e3) + "k"; return n(x); }
  function yrs(a, b) { return a ? (a === b ? "" + a : a + "–" + b) : ""; }
  function strip(ys, cls) {
    var h = '<svg class="' + (cls || "ys") + '" viewBox="0 0 ' + W + ' 10" preserveAspectRatio="none" aria-hidden="true"><rect class="bg" width="' + W + '" height="10"/>';
    (ys || []).forEach(function (y) { if (y >= Y0 && y <= Y1) h += '<rect class="on" x="' + (y - Y0 + 0.1) + '" width=".8" height="10"/>'; });
    return h + "</svg>";
  }
  function axis() {
    var h = '<span style="left:0">' + Y0 + "</span>";
    [1970, 1990, 2010].forEach(function (y) { if (y > Y0 && y < Y1) h += '<span style="left:' + ((y - Y0) / W * 100).toFixed(1) + '%">' + y + "</span>"; });
    return h + '<span style="right:0">' + Y1 + "</span>";
  }
  function sil(i, cls) {
    var s = D.sils && D.sils[i];
    return s ? '<svg class="' + cls + '" viewBox="' + esc(s[0]) + '" preserveAspectRatio="xMidYMid meet" aria-hidden="true">' + s[1] + "</svg>" : '<span class="' + cls + '"></span>';
  }
  function dsName(k) { return (D.files[k] || {}).name || k; }
  function gname(g, c) { return esc(g) + (g !== c ? ' <span class="cf-sci">(' + esc(c) + ")</span>" : ""); }
  var unit = SP ? "records" : "values", base = root.getAttribute("data-base") || "";

  /* ── rows ── */
  function spRow(r, hit) {
    return '<a class="cf-r" href="' + esc(r.url) + '" data-k="' + esc(r.k) + '"><span class="cf-th">' + sil(r.sil, "cf-si") + "</span>" +
      '<span class="cf-nm"><b>' + esc(r.com || r.sci) + "</b><span>" + (r.com ? "<i>" + esc(r.sci) + "</i> · " : "") + esc(r.grp) + "</span></span>" +
      '<span class="cf-ds">' + (hit ? hit : r.ds.length + " dataset" + (r.ds.length > 1 ? "s" : "")) + "<small>" + big(r.n) + " records</small></span>" +
      '<span class="cf-yr"><span>' + (yrs(r.y0, r.y1) || "Years not listed") + "</span>" + strip(r.years) + "</span></a>";
  }
  function msRow(r) {
    return '<a class="cf-r cf-m" href="' + esc(r.url) + '" data-k="' + esc(r.k) + '"><span class="cf-nm"><b>' + esc(r.lab) + "</b><span>" + esc(r.units || "no units") + (r.unified ? " · bottle and CTD combined" : "") + "</span></span>" +
      '<span class="cf-ds">' + esc(r.ds.map(function (d) { return dsName(d[0]); }).join(", ")) + "<small>" + big(r.n) + " values</small></span>" +
      '<span class="cf-yr"><span>' + (yrs(r.y0, r.y1) || "Years not listed") + "</span>" + strip(r.years) + "</span></a>";
  }
  /* a taxon that is not a species row (a genus, a family …): a link to its page, never a preview */
  function hiRow(t) {
    var g = t.g && D.groups.filter(function (x) { return x.cls === t.g; })[0];
    return '<a class="cf-r cf-h" href="' + esc(base + t.u) + '"><span class="cf-nm"><b>' + (t.i ? "<i>" + esc(t.s) + "</i>" : esc(t.s)) + "</b><span>" +
      esc(t.r || "Dataset-local class") + (t.c ? " · " + esc(t.c) : "") + (g && g.grp !== t.s ? " · " + esc(g.grp) : "") + "</span></span>" +
      '<span class="cf-ds">' + (t.sp ? n(t.sp) + " species" : "No species named under it") + "<small>" + big(t.n) + " records</small></span>" +
      '<span class="cf-yr"><span>' + (yrs(t.y0, t.y1) || "Years not listed") + '</span><span class="cf-open">Open its page ›</span></span></a>';
  }
  function has(xs) { return xs.join(" ").toLowerCase().indexOf(q) >= 0; }
  /* the taxa that are not rows, by name; within a chosen group, that group's */
  function higher() {
    if (!SP || !q || !T) return [];
    return T.filter(function (t) { return !(grp && t.g !== grp) && has([t.s, t.c || ""]); });
  }
  function hiBlock(hi) {
    if (!hi.length) return "";
    return '<section class="cf-hi" id="cf-hi" aria-labelledby="cf-hi-h"><h2 class="cf-hih" id="cf-hi-h">Groups and other taxa <span>' + n(hi.length) + "</span></h2>" +
      '<p class="cf-hin">Genera, families and other ranks named “' + esc(q) + "”. Each opens its own page; the list above is species only.</p>" +
      '<div class="cf-card">' + hi.slice(0, HI_MAX).map(hiRow).join("") + "</div>" +
      (hi.length > HI_MAX ? '<p class="cf-more">Showing the ' + HI_MAX + " most recorded of " + n(hi.length) + ". Type more of the name to narrow them.</p>" : "") + "</section>";
  }
  /* a species search matches names first; only when no name matches does it fall back to the group
     ("krill" finds the krill, not every crab in "Crabs, shrimp & krill"; "seabirds" finds the group) */
  function filtered() {
    var rows = D.rows.filter(function (r) { return !(SP && grp && r.cls !== grp); });
    if (!q) return rows;
    // a measurement is found by its names, its unit, its key, its NERC name and code (NTRAZZXX), and the datasets
    // that hold it by key or name ("METS"): what main's one search over this list answered
    if (!SP) return rows.filter(function (r) { return has([r.lab, r.full, r.desc, r.cat, r.units, r.k, r.nerc, r.p01].concat(r.ds.map(function (d) { return d[0] + " " + dsName(d[0]); }))); });
    var byName = rows.filter(function (r) { return has([r.com, r.sci]); });
    return byName.length ? byName : rows.filter(function (r) { return has([r.grp, r.cls]); });
  }

  /* ── the preview ── */
  function dsList(r) {
    /* each row links its dataset page, where a CSV button beside every species or measurement downloads just that one */
    return r.ds.map(function (d) {
      var f = D.files[d[0]] || {}, inner = "<b>" + esc(dsName(d[0])) + '</b><span><em>' + yrs(d[1], d[2]) + "</em> · " + big(d[3]) + " " + unit + "</span>";
      return "<li>" + (f.page ? '<a href="' + esc(base + f.page) + '">' + inner + '<i class="cf-go" aria-hidden="true">›</i></a>' : inner) + "</li>";
    }).join("");
  }
  function preview(r) {
    var name = SP ? r.com || r.sci : r.lab, h = "";
    if (SP) h += '<div class="cf-pic">' + (r.photo ? '<img src="' + esc(r.photo) + '" alt="" loading="lazy" onerror="this.parentNode.classList.add(\'nophoto\');this.remove()">' : "") + sil(r.sil, "cf-pvsi") + (r.photo && r.photo_lic ? '<span class="cf-lic">Photo · ' + esc(r.photo_lic) + "</span>" : "") + "</div>";
    h += '<div class="cf-pb">';
    h += SP ? '<span class="cf-k">' + gname(r.grp, r.cls) + "</span>" : '<span class="cf-k">' + esc(r.cat) + "</span>";
    h += "<h2>" + esc(name) + "</h2>";
    if (SP && r.com) h += '<p class="cf-sub"><i>' + esc(r.sci) + "</i></p>";
    if (!SP && r.full && r.full !== r.lab) h += '<p class="cf-sub">' + esc(r.full) + "</p>";
    if (SP && r.text) h += '<p class="cf-d">' + esc(r.text) + "</p>" + (r.wiki ? '<p class="cf-src">From <a href="' + esc(r.wiki) + '">Wikipedia</a> (CC BY-SA)</p>' : "");
    if (!SP && r.desc && r.desc !== r.full && r.desc !== r.lab) h += '<p class="cf-d">' + esc(r.desc) + "</p>";
    if (!SP && r.defn) h += '<p class="cf-def"><b>Standard definition' + (r.nerc ? " (" + esc(r.nerc) + ")" : "") + "</b>" + esc(r.defn) + "</p>";
    var f = "";
    if (SP) {
      if (r.stages && r.stages.length) f += "<div><dt>Life stages</dt><dd>" + esc(r.stages.join(", ")) + "</dd></div>";
      if (r.size) f += "<div><dt>Max length</dt><dd>" + (r.size >= 1 ? r.size + " m" : Math.round(r.size * 100) + " cm") + "</dd></div>";
    } else {
      f += "<div><dt>Units</dt><dd>" + esc(r.units || "—") + "</dd></div>";
      if (r.dmax != null) f += "<div><dt>Depth</dt><dd>" + (+r.dmax === 0 ? "Surface" : Math.round(r.dmin || 0) + "–" + n(Math.round(r.dmax)) + " m") + "</dd></div>";
    }
    f += "<div><dt>" + (SP ? "Records" : "Values") + "</dt><dd>" + n(r.n) + "</dd></div>";
    h += '<dl class="cf-f">' + f + "</dl>";
    h += '<div class="cf-y"><div><b>Years with data</b><span>' + (yrs(r.y0, r.y1) || "not listed") + "</span></div>" + strip(r.years, "ys big") + '<div class="cf-ax">' + axis() + "</div></div>";
    h += '<div class="cf-dsl"><b>' + (SP ? "Found in " + r.ds.length + " dataset" + (r.ds.length > 1 ? "s" : "") : "Measured in") + "</b><ul>" + dsList(r) + "</ul></div>";
    h += '<div class="cf-act">' + (r.map ? '<a class="cf-b1" href="' + esc(root.getAttribute("data-explore") + r.map) + '">View on map</a>' : "") + '<a class="cf-b3" href="' + esc(r.url) + '">Full page →</a></div>';
    return h + "</div>";
  }
  function pick(k) {
    sel = k;
    [].forEach.call(root.querySelectorAll(".cf-r[data-k]"), function (a) { var on = a.getAttribute("data-k") === k; a.classList.toggle("on", on); a.setAttribute("aria-current", on ? "true" : "false"); });
    var r = D.rows.filter(function (x) { return x.k === k; })[0], pv = document.getElementById("cf-pv");
    if (!r && SP) { pv.hidden = true; return; }
    // measurements with every category closed: no row is in view, so the pane says what to do rather
    // than previewing a row the reader cannot see in the list
    pv.innerHTML = r ? preview(r) : '<div class="cf-pb cf-none"><span class="cf-k">Preview</span><h2>Choose a measurement</h2>' +
      '<p class="cf-d">Open a category, or search by name, unit or dataset. The measurement you choose is shown here: its units, its depths, the years with data and the datasets that hold it.</p></div>';
    pv.hidden = false;
  }

  /* ── the list views ── */
  function draw() {
    if (!D) return;
    var host = document.getElementById("cf-list"), h = "", rows = filtered(), shown = rows, hi = higher();
    if (SP && view === "groups" && !grp) {
      var hold = {}; if (q) rows.forEach(function (r) { hold[r.cls] = (hold[r.cls] || 0) + 1; });
      var gs = q ? D.groups.filter(function (g) { return hold[g.cls]; }) : D.groups;
      if (q) h += gs.length ? '<p class="cf-chip">' + n(rows.length) + " match" + (rows.length === 1 ? "" : "es") + " in " + gs.length + " group" + (gs.length === 1 ? "" : "s") + "</p>" : '<p class="cf-empty">' + none(hi) + "</p>";
      h += '<div class="cf-gg">' + gs.map(function (g) {
        var c = q ? n(hold[g.cls]) + " match" + (hold[g.cls] === 1 ? "" : "es") : g.n_sp ? n(g.n_sp) + " species" : n(g.n_taxa) + " " + (g.n_taxa === 1 ? "taxon" : "taxa") + ", none to species";
        return '<button type="button" class="cf-gc" data-g="' + esc(g.cls) + '"><span class="cf-gs">' + sil(g.sil, "cf-si") + "</span><b>" + gname(g.grp, g.cls) + '</b><span class="cf-gl">' + c + " · " + big(g.n) + " records</span>" + (function (t) { return t.length ? '<span class="cf-gt">' + esc(t.join(", ")) + "</span>" : ""; })(q ? rows.filter(function (r) { return r.cls === g.cls; }).slice(0, 3).map(function (r) { return r.com || r.sci; }) : g.top) + "</button>";
      }).join("") + "</div>";
      shown = q ? rows : [];
      h += hiBlock(hi);
    } else if (SP) {
      var G = grp && D.groups.filter(function (g) { return g.cls === grp; })[0];
      if (G) h += '<p class="cf-chip">Showing ' + gname(G.grp, G.cls) + ' <button type="button" class="cf-lnk" id="cf-all">Show all</button></p>';
      if (G && !G.n_sp) { h += '<p class="cf-empty">None of the ' + n(G.n_taxa) + " " + esc(G.grp.toLowerCase()) + " " + (G.n_taxa === 1 ? "taxon is" : "taxa are") + ' named down to species, so they are not in this list. They are in <button type="button" class="cf-lnk" data-tab-go="tree">the tree</button>, with ' + big(G.n) + " records.</p>"; shown = []; }
      else if (rows.length) {
        var cap = q || grp ? rows : rows.slice(0, 200);
        // a long list of species would bury the other taxa under it: say they are there
        if (hi.length && cap.length > 8) h += '<p class="cf-chip cf-hij"><a class="cf-lnk" href="#cf-hi">' + n(hi.length) + (hi.length === 1 ? " group or other taxon also matches" : " groups and other taxa also match") + " ↓</a></p>";
        h += '<div class="cf-colh"><span></span><span>Species</span><span>Datasets</span><span>Years with data</span></div><div class="cf-card">' + cap.map(function (r) { return spRow(r); }).join("") + "</div>";
        if (cap.length < rows.length) h += '<p class="cf-more">Showing the 200 most recorded of ' + n(rows.length) + ". Search or pick a group to find the rest.</p>";
        shown = cap;
      }
    } else {
      // the column heads sit over rows only: in By category inside each category, so opening one does not
      // move the button that was pressed
      var colh = '<div class="cf-colh cf-m"><span>Measurement</span><span>Measured in</span><span>Years with data</span></div>';
      if (view === "cat") {
        // a row the reader chose stays in view: its category is open when the search is cleared
        var cur = !q && chose && sel && D.rows.filter(function (r) { return r.k === sel; })[0];
        if (cur) open[cur.cat] = true;
        D.cats.forEach(function (c) {
          var rs = rows.filter(function (r) { return r.cat === c.name; });
          if (!rs.length) return; // a search leaves out the categories with no match
          var id = "cat-" + c.name.toLowerCase().replace(/[^a-z0-9]+/g, "-"), on = q ? !shutQ[c.name] : !!open[c.name];
          var all = c.n || rs.length, top = (c.top || []).join(", ") + (all > (c.top || []).length ? " …" : "");
          h += '<section class="cf-grp" id="' + esc(id) + '" data-cat="' + esc(c.name) + '" data-n="' + rs.length + '"><h3 class="cf-gh"><button type="button" class="cf-gb" aria-expanded="' + on + '" aria-controls="' + esc(id) + '-rows">' +
            '<span class="cf-gi"><i class="cc-i cc-i-' + esc(c.icon || "cat-other") + '" aria-hidden="true"></i></span>' +
            '<span class="cf-gx"><span class="cf-gname">' + esc(c.name) + "</span>" + (!q && top ? '<span class="cf-gtop">' + esc(top) + "</span>" : "") + "</span>" +
            '<span class="cf-gn">' + (q ? n(rs.length) + " of " + n(all) : n(all) + " measurement" + (all === 1 ? "" : "s")) + "</span>" +
            '<i class="cc-i cc-i-ui-down cf-chev" aria-hidden="true"></i></button></h3>' +
            '<div class="cf-gbody" id="' + esc(id) + '-rows"' + (on ? "" : " hidden") + ">" + colh + '<div class="cf-card">' + rs.map(msRow).join("") + "</div></div></section>";
        });
      } else {
        h += colh + '<div class="cf-card">' + rows.slice().sort(function (a, b) { return a.lab.localeCompare(b.lab); }).map(msRow).join("") + "</div>";
      }
    }
    if (!shown.length && !(SP && view === "groups") && !(SP && grp)) h += '<p class="cf-empty">' + none(hi) + "</p>";
    if (SP && !(view === "groups" && !grp)) h += hiBlock(hi);
    host.innerHTML = h;
    if (count) count.textContent = q ? n(rows.length) : (SP ? n(D.counts && D.counts.species_observed || rows.length) : n(rows.length));
    [].forEach.call(host.querySelectorAll(".cf-gc"), function (b) { b.onclick = function () { grp = b.getAttribute("data-g"); go("list"); if (TS) TS.scrollIntoView({ block: "start" }); }; });
    var all = document.getElementById("cf-all"); if (all) all.onclick = function () { grp = ""; draw(); };
    [].forEach.call(host.querySelectorAll("[data-tab-go]"), function (b) { b.onclick = function () { go(b.getAttribute("data-tab-go")); }; });
    settle();
    say(rows.length, hi.length);
  }
  function none(hi) {
    if (!hi || !hi.length) return "Nothing matches “" + esc(q) + "”.";
    return "No species is named “" + esc(q) + "”. " + (hi.length === 1 ? "One group or other taxon is:" : n(hi.length) + " groups and other taxa are:");
  }
  /* the rows in view: not the ones inside a closed category */
  function inView() {
    return [].filter.call(document.getElementById("cf-list").querySelectorAll(".cf-r[data-k]"), function (a) { return !a.closest("[hidden]"); });
  }
  /* after a draw, or a category opened or shut: the preview is on a row that is in view — the chosen
     one if it still is, else the first of `from` (the category just opened) or of the list. Species
     with no row in view (Groups) preview the most recorded one; measurements with every category
     closed say to choose. */
  function settle(from) {
    var vis = inView();
    if (sel && vis.some(function (a) { return a.getAttribute("data-k") === sel; })) return pick(sel);
    chose = false;
    var a = (from && from.querySelector(".cf-r[data-k]")) || vis[0];
    pick(a ? a.getAttribute("data-k") : (SP ? D.rows[0] && D.rows[0].k : null));
  }
  // what a screen reader hears after a search: one short line, once the typing pauses. The preview pane itself
  // is not a live region (it was: typing "sardine" queued the whole pane seven times, 5,264 characters)
  var sayEl = document.getElementById("cf-pv-say"), sayT = null;
  function say(count, others) {
    if (!sayEl) return;
    clearTimeout(sayT);
    sayT = setTimeout(function () {
      var pv = document.getElementById("cf-pv"), shown = pv && !pv.hidden && getComputedStyle(pv).display !== "none";
      var r = sel && D.rows.filter(function (x) { return x.k === sel; })[0], name = r && (SP ? r.com || r.sci : r.lab);
      sayEl.textContent = n(count) + " " + (SP ? "species" : (count === 1 ? "measurement" : "measurements")) +
        (others ? " and " + n(others) + (others === 1 ? " other taxon" : " other taxa") : "") + (count && name && shown ? ". Showing " + name + "." : ".");
    }, 500);
  }
  /* the finder's two views are two tabs of the page's tabset (assets/tabs.js owns the switching and
     ?tab=); the finder moves into whichever of its two panels is showing */
  function go(id) { var b = TS && TS.querySelector('.tabrow > button[data-tab="' + id + '"]'); if (b) b.click(); else { view = id; draw(); } }
  function tabNow() { var b = TS && TS.querySelector(".tabrow > button[aria-selected=true]"); return b ? b.getAttribute("data-tab") : V[0]; }
  function sync() {
    var t = tabNow();
    if (V.indexOf(t) < 0) return;
    var p = TS && TS.querySelector('.tabpanel[data-panel="' + t + '"]');
    if (p && root.parentNode !== p) p.appendChild(root);
    if (t !== view) { if (t === V[0]) grp = ""; view = t; if (D) draw(); }
  }

  root.addEventListener("click", function (e) {
    // a category's heading: open or shut it in place (focus stays on the button, which says its state)
    var b = e.target.closest && e.target.closest(".cf-gb");
    if (b) {
      var sec = b.closest(".cf-grp"), c = sec.getAttribute("data-cat"), on = b.getAttribute("aria-expanded") !== "true";
      if (q) shutQ[c] = !on; else open[c] = on;
      b.setAttribute("aria-expanded", String(on));
      sec.querySelector(".cf-gbody").hidden = !on;
      settle(on ? sec : null);
      return;
    }
    var a = e.target.closest && e.target.closest(".cf-r[data-k]");
    if (!a || e.metaKey || e.ctrlKey || e.shiftKey || e.button) return;
    if (getComputedStyle(document.getElementById("cf-pv")).display === "none") return; // a phone: follow the link
    e.preventDefault(); chose = true; pick(a.getAttribute("data-k"));
  });
  if (TS) new MutationObserver(sync).observe(TS.querySelector(".tabrow"), { subtree: true, attributes: true, attributeFilter: ["aria-selected"] });
  if (input) input.addEventListener("input", function () {
    q = input.value.trim().toLowerCase(); shutQ = {};
    // species: a search is answered by the list, so a view that does not answer one (Groups, the matrix,
    // the hierarchy) gives way to it; the tree folds to the search in place (species.js)
    var t = tabNow();
    if (SP && q && t !== "list" && t !== "tree") go("list"); else draw();
  });
  [].forEach.call(document.querySelectorAll(".cf-try [data-q]"), function (b) { b.onclick = function () { input.value = b.getAttribute("data-q"); input.dispatchEvent(new Event("input")); }; });

  fetch(root.getAttribute("data-src")).then(function (r) { return r.json(); }).then(function (d) {
    D = d;
    if (!Y0) Y0 = d.rows.reduce(function (a, r) { return r.y0 ? Math.min(a, r.y0) : a; }, 9999);
    Y1 = Math.max(Y1, d.rows.reduce(function (a, r) { return Math.max(a, r.y1 || 0); }, 0)); W = Y1 - Y0 + 1;
    var p = new URLSearchParams(location.search), q0 = p.get("q"), c0 = p.get("cat"), g0 = p.get("group");
    view = "";
    if (q0 && input) { input.value = q0; q = q0.toLowerCase(); }
    if (SP && g0) grp = g0;
    // ?cat= (a measurement page's crumb links its category): that category is open on arrival
    if (!SP && c0 && d.cats.some(function (c) { return c.name === c0; })) open[c0] = true;
    sync();
    if (SP && (q0 || g0) && view === "groups") go("list");
    var ss = root.getAttribute("data-sils");
    if (ss) fetch(ss).then(function (r) { return r.json(); }).then(function (x) { D.sils = x; if (view) draw(); }).catch(function () {});
    var tt = root.getAttribute("data-taxa");
    if (tt) fetch(tt).then(function (r) { return r.json(); }).then(function (x) { T = x; if (view && q) draw(); }).catch(function () {});
    if (!SP && c0) { var s = document.querySelector('.cf-grp[data-cat="' + CSS.escape(c0) + '"]'); if (s) setTimeout(function () { s.scrollIntoView({ block: "start" }); }, 0); }
  }).catch(function (e) { console.error(e); document.getElementById("cf-list").innerHTML = '<p class="cf-empty">Could not load the list. Reload the page to try again.</p>'; });
})();
