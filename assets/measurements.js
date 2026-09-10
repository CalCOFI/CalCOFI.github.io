/* measurements.js — the measurements catalog's drawings (plan 2026-09-10 § D5, D6; WS-M4).

   Two pages, one file, no library and no network:

   /measurements/            #mm-data      → the search (?q=), the category chips, the TIMELINE
                                             table (one row per measurement, one bar per series on
                                             a 1949 → release-year axis), the category × dataset
                                             MATRIX and the datasets list
   /measurements/{key}/      #mm-strip-data → the years strip (an <svg>)
                             #mm-depth-data → the depth bars
                             #mm-months-data → the month strip

   Every number is read from one of those four scripts, which _plugins/measurements.rb writes out of
   the release's measurements.json. Nothing here counts anything the record has not already counted,
   and nothing is typed.

   The rules this file keeps (the dataviz skill's non-negotiables, and the site's own):
     · identity is NEVER colour alone — every bar has its dataset's name in its row, the legend
       above names all five, and the tooltip names the dataset first. The environment palette's
       closest pair (bottle ↔ picoplankton, ΔE 7.9 normal / 4.1 protan) is legal only with that
       second cue, and it is always present.
     · one SEQUENTIAL ramp for the matrix (--accent mixed into --bg), never a second hue
     · thin marks (a 7 px bar, an 8 px depth bar), recessive ticks, text in text tokens
     · hover by default, on a tooltip that is also the mark's `title` for a reader without a mouse
     · nothing moves unless motion is welcome (@media prefers-reduced-motion in style.css)
     · the <svg> is hidden until it is DRAWN (.mm-drawn) — an undrawn one is 300 × 150 by the CSS
       default. The class, not `[viewBox]`: an attribute selector is lower-cased in an HTML document
       and never matches SVG's camelCase attribute (the species strip's bug, 2026-09-09).
   Ported from the mockup measurements_mockup_2026-09-10.html. */
(function () {
  "use strict";

  var NS = "http://www.w3.org/2000/svg";

  function fmt(n) { return String(n == null ? 0 : n).replace(/\B(?=(\d{3})+(?!\d))/g, ","); }
  function fmtK(n) {
    n = Number(n || 0);
    if (n >= 1e6) return (n / 1e6).toFixed(1).replace(/\.0$/, "") + " M";
    if (n >= 1e4) return fmt(Math.round(n / 1e3)) + " k";
    return fmt(n);
  }
  function esc(s) {
    return String(s == null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;")
      .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }
  function el(tag, cls, html) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    return e;
  }
  function svgEl(tag, attrs, parent) {
    var e = document.createElementNS(NS, tag), k;
    for (k in (attrs || {})) {
      if (k === "text") e.textContent = attrs[k];
      else if (k === "cls") e.setAttribute("class", attrs[k]);
      else e.setAttribute(k, attrs[k]);
    }
    if (parent) parent.appendChild(e);
    return e;
  }
  function tint(pct) { return "color-mix(in srgb, var(--accent) " + pct + "%, var(--bg))"; }
  /* a dataset's SHORT name is the record's; only the parenthetical tail is dropped, so a legend
     row and a 96 px strip gutter still read ("Underway Meteorological (METS)" → "Underway
     Meteorological"). The full name is always in the tooltip and the title. */
  function shortName(s) { return String(s || "").replace(/\s*\(.*\)\s*$/, ""); }
  function depthTxt(d0, d1) {
    if (d0 == null || d1 == null || !isFinite(d0) || !isFinite(d1)) return "—";
    if (d1 === 0) return "surface";
    return fmt(Math.round(d0)) + "–" + fmt(Math.round(d1)) + " m";
  }

  /* ── URLs: one full-width mono line, elided from the middle ─────────────────────────────── */
  function elide() {
    var urls = document.querySelectorAll(".mm-url"), i;
    for (i = 0; i < urls.length; i++) {
      var a = urls[i];
      var full = a.getAttribute("data-full");
      if (full === null) { full = a.textContent; a.setAttribute("data-full", full); }
      a.textContent = full;
      if (a.scrollWidth <= a.clientWidth) continue;
      var n = full.length;
      while (a.scrollWidth > a.clientWidth && n > 12) {
        n -= 2;
        var h = Math.floor(n / 2);
        a.textContent = full.slice(0, h) + "…" + full.slice(full.length - (n - h));
      }
    }
  }
  elide();
  addEventListener("resize", elide);
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(elide);

  /* ══ the measurement page's three figures ════════════════════════════════════════════════ */
  function readJSON(id) {
    var s = document.getElementById(id);
    if (!s) return null;
    try { return JSON.parse(s.textContent); } catch (e) { return null; }
  }
  function rowLabel(r) { return shortName(r.s); }

  /* the years strip: one row per SERIES, one cell per year, opacity by √(n / that row's max) */
  (function strip() {
    var host = document.getElementById("mm-strip"), S = readJSON("mm-strip-data");
    if (!host || !S || !S.rows || !S.rows.length) return;
    /* the mock's geometry, FIXED: a 96 px label gutter, an 8 px year cell, a 22 px row in a
       742-wide viewBox. The <svg> scales to whatever column it lands in, so the cells stay square
       on a phone instead of being recomputed to 3 px against a 96 px gutter. */
    function draw() {
      var years = [], y;
      for (y = S.y0; y <= S.y1; y++) years.push(y);
      var lw = 150, cw = 8, W = lw + years.length * cw + 6;
      var rh = 22, H = S.rows.length * rh + 22;
      host.setAttribute("viewBox", "0 0 " + W + " " + H);
      host.classList.add("mm-drawn");
      host.innerHTML = "";
      S.rows.forEach(function (r, j) {
        var vals = Object.keys(r.y).map(function (k) { return r.y[k]; });
        var max = Math.max.apply(null, vals.concat([1]));
        /* the dot AND the dataset's name: colour is the second cue here, never the only one */
        svgEl("circle", { cx: 6, cy: j * rh + 11, r: 5, fill: r.c || "var(--accent)" }, host);
        /* the label is the dataset's name, cut to the gutter rather than run under the cells —
           the full name is the row's <title> and is written out in "Measured in" above */
        var nm = rowLabel(r), lab = nm.length > 21 ? nm.slice(0, 20) + "…" : nm;
        var t = svgEl("text", { x: 17, y: j * rh + 15, cls: "mm-rl", text: lab }, host);
        svgEl("title", { text: r.s + " · " + r.mt + " · " + fmt(r.n) + " values" }, t);
        years.forEach(function (yy, i) {
          var n = r.y[yy] || 0;
          if (!n) return;
          var rect = svgEl("rect", { x: lw + i * cw, y: j * rh + 3, width: Math.max(cw - 1, 0.6),
                                     height: rh - 6, rx: 1.5, fill: r.c || "var(--accent)",
                                     opacity: (0.18 + 0.82 * Math.sqrt(n / max)).toFixed(2) }, host);
          svgEl("title", { text: r.s + " · " + r.mt + " · " + yy + " · " + fmt(n) + " values" }, rect);
        });
      });
      for (y = 1950; y <= S.y1; y += 10) {
        var x = lw + (y - S.y0) * cw;
        svgEl("line", { x1: x, x2: x, y1: S.rows.length * rh + 1, y2: S.rows.length * rh + 5,
                        stroke: "var(--border)" }, host);
        svgEl("text", { x: x, y: S.rows.length * rh + 18, "text-anchor": "middle", text: y }, host);
      }
    }
    draw();
  })();

  /* by depth: the record's own bands, one thin bar per series, the end label INSIDE the column */
  (function depth() {
    var host = document.getElementById("mm-depth"), D = readJSON("mm-depth-data");
    if (!host || !D || !D.rows || !D.rows.length) return;
    var bands = D.bands || [], max = 0;
    D.rows.forEach(function (r) {
      bands.forEach(function (b) { var n = (r.b || {})[b] || 0; if (n > max) max = n; });
    });
    if (!max) return;
    var lg = document.getElementById("mm-depth-legend");
    if (lg && D.rows.length > 1) {                    /* a legend for two series or more */
      D.rows.forEach(function (r) {
        lg.appendChild(el("span", null, '<i class="mm-dot" style="background:' + esc(r.c) +
                          '"></i>' + esc(r.s) + " · " + esc(r.mt)));
      });
    }
    host.innerHTML = "";
    bands.forEach(function (b) {
      host.appendChild(el("div", "mm-lb", esc(b.replace("-", "–")) + " m"));
      var pair = el("div", "mm-pair");
      D.rows.forEach(function (r) {
        var n = (r.b || {})[b] || 0;
        var bar = el("div", "mm-b", "<span>" + fmtK(n) + "</span>");
        bar.style.width = Math.max(100 * n / max, 0.6).toFixed(1) + "%";
        bar.style.background = r.c || "var(--accent)";
        bar.title = r.s + " · " + r.mt + " · " + b + " m: " + fmt(n) + " values";
        bar.setAttribute("role", "img");            /* a graphic takes a role before a label */
        bar.setAttribute("aria-label", bar.title);
        pair.appendChild(bar);
      });
      host.appendChild(pair);
    });
    host.classList.add("mm-drawn");
  })();

  /* by month: 12 cells per series, the letters below, opacity by that row's own maximum */
  (function months() {
    var host = document.getElementById("mm-months"), M = readJSON("mm-months-data");
    if (!host || !M || !M.rows || !M.rows.length) return;
    var NAMES = ["January", "February", "March", "April", "May", "June", "July", "August",
                 "September", "October", "November", "December"];
    host.innerHTML = "";
    M.rows.forEach(function (r) {
      var ms = r.m || [], max = Math.max.apply(null, ms.concat([1]));
      host.appendChild(el("div", "mm-lb2", '<i class="mm-dot" style="background:' + esc(r.c) +
                          '"></i>' + esc(rowLabel(r))));
      for (var i = 0; i < 12; i++) {
        var n = ms[i] || 0;
        var c = el("div", "mm-c");
        c.style.background = r.c || "var(--accent)";
        c.style.opacity = n ? (0.15 + 0.85 * Math.sqrt(n / max)).toFixed(2) : 0.07;
        c.title = r.s + " · " + r.mt + " · " + NAMES[i] + ": " + fmt(n) + " values";
        host.appendChild(c);
      }
    });
    host.appendChild(el("div"));
    "JFMAMJJASOND".split("").forEach(function (l, i) {
      var c = el("div", "mm-ml", l);
      c.title = NAMES[i];
      host.appendChild(c);
    });
    host.classList.add("mm-drawn");
  })();

  /* ══ the index ═══════════════════════════════════════════════════════════════════════════ */
  var D = readJSON("mm-data");
  if (!D) return;
  var DS = D.ds || [], ROWS = D.rows || [], CATS = (D.cats || []).filter(function (c) {
    return ROWS.some(function (r) { return r.c === c.n; });
  });
  var Y0 = D.y0, Y1 = D.y1, NY = Y1 - Y0 + 1;

  /* ── the tooltip: the same one the species index uses ───────────────────────────────────── */
  var tt = document.getElementById("mm-ttip");
  function place(e) {
    if (!tt) return;
    var host = tt.parentElement.getBoundingClientRect();
    tt.style.display = "block";
    tt.setAttribute("aria-hidden", "false");
    var x = e.clientX - host.left + 14, y = e.clientY - host.top + 14;
    if (x + 330 > host.width) x = Math.max(4, e.clientX - host.left - 330);
    tt.style.left = x + "px";
    tt.style.top = y + "px";
  }
  function hideTip() {
    if (!tt) return;
    tt.style.display = "none";
    tt.setAttribute("aria-hidden", "true");
  }
  /* every tooltip is ALSO the mark's title, so the fact is there without a mouse */
  function tipOn(node, html, plain) {
    node.title = plain;
    if (!tt) return;
    node.addEventListener("mouseenter", function (e) { tt.innerHTML = html; place(e); });
    node.addEventListener("mousemove", place);
    node.addEventListener("mouseleave", hideTip);
  }

  /* ── the legend: all five datasets, named ───────────────────────────────────────────────── */
  var leg = document.getElementById("mm-legend");
  if (leg) {
    DS.forEach(function (d) {
      leg.appendChild(el("span", null, '<i class="mm-dot" style="background:' + esc(d.c) + '"></i>' +
                         esc(d.s)));
    });
  }

  /* ── the timeline table ─────────────────────────────────────────────────────────────────── */
  var tl = document.getElementById("mm-tl");
  var q = document.getElementById("mm-q"), qn = document.getElementById("mm-qn");
  var chips = document.getElementById("mm-chips");
  var curCat = "";

  function hayOf(r) {
    var parts = [r.l, r.k, r.c, r.u, r.ur, r.p];
    (r.se || []).forEach(function (s) {
      var d = DS[s.d] || {};
      parts.push(s.mt, s.sc, s.qc, s.p, s.de, d.s, d.k);
    });
    return parts.filter(Boolean).join(" ").toLowerCase();
  }
  ROWS.forEach(function (r) { r._h = hayOf(r); });

  function seriesOf(r) {
    return (r.se || []).slice().sort(function (a, b) { return a.d - b.d; });   /* the record's dataset order */
  }

  function barTip(r, s) {
    var d = DS[s.d] || {};
    var line = [s.y0 + "–" + s.y1, fmt(s.n) + " values",
                s.rt != null ? fmt(s.rt) + " sampling events" : null,
                s.sm != null ? fmt(s.sm) + " samples" : null,
                depthTxt(s.d0, s.d1),
                s.sc ? "column " + s.sc : null,
                s.qc ? "flag " + s.qc : null,
                s.p ? "P01 " + s.p : null].filter(Boolean).join(" · ");
    return {
      html: "<b>" + esc(d.s) + " · " + esc(s.mt) + "</b>" + (s.de ? esc(s.de) : "") +
            '<span class="mm-d">' + esc(line) + "</span>",
      plain: d.s + " · " + s.mt + (s.de ? " — " + s.de : "") + " · " + line
    };
  }

  function ticks(withLabels) {
    var h = "", y;
    for (y = 1950; y <= Y1; y += 10) {
      var x = ((y - Y0) / NY * 100).toFixed(2);
      h += '<span class="mm-tick' + (y % 50 === 0 ? " mm-maj" : "") + '" style="left:' + x + '%"></span>';
      if (withLabels) h += '<span class="mm-yl" style="left:' + x + '%">' + y + "</span>";
    }
    return h;
  }

  function draw() {
    if (!tl) return;
    var s = (q ? q.value : "").trim().toLowerCase();
    var rows = ROWS.filter(function (r) {
      if (curCat && r.c !== curCat) return false;
      return !s || r._h.indexOf(s) >= 0;
    });
    if (qn) {
      qn.textContent = rows.length === ROWS.length
        ? fmt(ROWS.length) + " measurements"
        : fmt(rows.length) + " of " + fmt(ROWS.length);
    }
    tl.innerHTML = "";
    /* role="table" needs role="row" children and rows need cells, so every row is a wrapper with
       `display: contents` — the CSS grid still lays the cells out as one grid, and the
       accessibility tree gets a real table (Lighthouse's aria-required-children, 2026-09-10). */
    function row(cls) {
      var e = el("div", "mm-trow" + (cls ? " " + cls : ""));
      e.setAttribute("role", "row");
      tl.appendChild(e);
      return e;
    }
    function cell(parent, cls, html, role) {
      var e = el("div", cls, html);
      e.setAttribute("role", role || "cell");
      parent.appendChild(e);
      return e;
    }
    var hr = row("mm-hdr");
    ["measurement", "units", null, "datasets", "values", "depth"].forEach(function (h) {
      var c = cell(hr, "mm-hd", null, "columnheader");
      if (h === null) c.innerHTML = '<div class="mm-track">' + ticks(true) + "</div>";
      else c.textContent = h;
    });
    if (!rows.length) {
      cell(row(), "mm-tl-empty",
           "No measurement matches — try a variable, a series name, a dataset, a unit or a NERC id.");
      return;
    }
    var lastCat = null;
    rows.forEach(function (r) {
      if (r.c !== lastCat) {
        lastCat = r.c;
        var cat = CATS.filter(function (c) { return c.n === r.c; })[0] || {};
        var n = rows.filter(function (x) { return x.c === r.c; }).length;
        cell(row(), "mm-cat",
          "<b>" + esc(r.c) + "</b><span>" + fmt(n) + " measurement" + (n === 1 ? "" : "s") +
          (cat.r === "bio" ? " · a biology category: cell counts, rows of obs_env" : "") + "</span>");
      }
      var tro = row();
      var url = D.base + r.k + "/";
      cell(tro, "mm-nm",
        '<a href="' + esc(url) + '">' + esc(r.l) + "</a>" +
        '<span class="mm-k">' + esc(r.k) +
        ((r.se || []).length > 1 ? " · " + r.se.length + " series" : "") +
        (r.p ? " · " + esc(r.p) : "") + "</span>");
      var uc = cell(tro, "mm-u", esc(r.u || "—"));
      uc.title = r.ur || "no unit in the registry";

      var tr = cell(tro, null, '<div class="mm-track">' + ticks(false) + "</div>");
      var track = tr.firstChild;
      var ms = seriesOf(r);
      ms.forEach(function (m, i) {
        if (m.y0 == null) return;
        var b = el("span", "mm-bar " + (ms.length === 1 ? "mm-b1" : i === 0 ? "mm-b2a" : "mm-b2b"));
        b.style.left = ((m.y0 - Y0) / NY * 100).toFixed(2) + "%";
        b.style.width = Math.max((m.y1 - m.y0 + 1) / NY * 100, 1.3).toFixed(2) + "%";
        b.style.background = (DS[m.d] || {}).c || "var(--accent)";
        var t = barTip(r, m);
        /* a bar is a graphic, so it takes a role before it takes a label: aria-label on a bare
           <span> is prohibited (Lighthouse's aria-prohibited-attr) */
        b.setAttribute("role", "img");
        b.setAttribute("aria-label", t.plain);
        tipOn(b, t.html, t.plain);
        track.appendChild(b);
      });

      var dsc = cell(tro, "mm-ds");
      ms.forEach(function (m) {
        var d = DS[m.d] || {};
        dsc.appendChild(el("span", null, '<i class="mm-dot" style="background:' + esc(d.c) +
                            '"></i>' + esc(shortName(d.s))));
      });
      var v = cell(tro, "mm-v", fmtK(r.t && r.t.n));
      v.title = fmt(r.t && r.t.n) + " values at the release grain";
      cell(tro, "mm-dp", esc(depthTxt(r.t && r.t.d0, r.t && r.t.d1)));
    });
  }

  /* ── the chips: one per category, with its count ────────────────────────────────────────── */
  function writeParam(name, value) {
    if (!history.replaceState) return;
    var u = new URL(location.href);
    if (value) u.searchParams.set(name, value); else u.searchParams.delete(name);
    history.replaceState(null, "", u.toString());
  }
  function chipBtn(label, val, n, title) {
    var b = el("button", null, esc(label) + (n != null ? '<span class="mm-n">' + fmt(n) + "</span>" : ""));
    b.type = "button";
    b.setAttribute("data-cat", val);
    b.setAttribute("aria-pressed", val === curCat ? "true" : "false");
    if (title) b.title = title;
    b.addEventListener("click", function () {
      curCat = val;
      [].forEach.call(chips.querySelectorAll("button"), function (x) {
        x.setAttribute("aria-pressed", x.getAttribute("data-cat") === curCat ? "true" : "false");
      });
      writeParam("cat", curCat);
      draw();
    });
    return b;
  }
  /* the chip's short label is the category name's own head — "Physical Oceanography" reads
     "Physical" on a pill, and the full name is the title and the row heading below */
  function chipLabel(name) { return String(name).split(/ (?:&|and) /)[0].split(" ")[0]; }

  if (chips) {
    chips.appendChild(chipBtn("all", "", ROWS.length, "Every measurement in the release"));
    CATS.forEach(function (c) {
      var n = ROWS.filter(function (r) { return r.c === c.n; }).length;
      chips.appendChild(chipBtn(chipLabel(c.n), c.n, n,
                                c.n + (c.r === "bio" ? " — a biology category: cell counts, rows of obs_env" : "")));
    });
  }

  if (q) {
    q.addEventListener("input", function () { draw(); writeParam("q", q.value.trim()); });
  }
  var params = new URLSearchParams(location.search);
  var q0 = params.get("q"), cat0 = params.get("cat");
  if (cat0 && CATS.some(function (c) { return c.n === cat0; })) {
    curCat = cat0;
    if (chips) {
      [].forEach.call(chips.querySelectorAll("button"), function (x) {
        x.setAttribute("aria-pressed", x.getAttribute("data-cat") === curCat ? "true" : "false");
      });
    }
  }
  if (q0 && q) q.value = q0;
  draw();

  /* ── the matrix: category × dataset, the cell is how many measurements ──────────────────── */
  var mx = document.getElementById("mm-matrix");
  if (mx) {
    var cells = {}, mxMax = 0;
    CATS.forEach(function (c) {
      DS.forEach(function (d, di) {
        var list = ROWS.filter(function (r) {
          return r.c === c.n && (r.se || []).some(function (s) { return s.d === di; });
        });
        cells[c.n + "|" + di] = list;
        if (list.length > mxMax) mxMax = list.length;
      });
    });
    var grid = el("div", "mm-mx");
    grid.style.gridTemplateColumns = "minmax(120px,1.4fr) repeat(" + DS.length + ", minmax(46px,1fr))";
    grid.appendChild(el("div", "mm-mh mm-first",
                        '<span class="mm-hz">category ↓ · dataset →</span>'));
    DS.forEach(function (d) {
      grid.appendChild(el("div", "mm-mh", '<span class="mm-vt">' + esc(shortName(d.s)) +
                          '</span><i style="background:' + esc(d.c) + '"></i>'));
    });
    CATS.forEach(function (c) {
      var tot = ROWS.filter(function (r) { return r.c === c.n; }).length;
      grid.appendChild(el("div", "mm-rl2", esc(c.n) + "<small>" + fmt(tot) + " measurement" +
                          (tot === 1 ? "" : "s") + "</small>"));
      DS.forEach(function (d, di) {
        var list = cells[c.n + "|" + di], n = list.length;
        var cell = el("div", "mm-cell" + (n ? "" : " mm-z"), n ? fmt(n) : "0");
        if (n) {
          /* ONE sequential ramp, capped at 45% of --accent: past that the cell's text has to flip
             to white and white on a mid tint measured 2.64:1 (Lighthouse, 2026-09-10). Capping the
             ramp keeps one text colour, in a text token, at ≥ 4.5:1 in both themes. */
          var pct = Math.round(10 + 35 * n / mxMax);
          cell.style.background = tint(pct);
          var names = list.slice(0, 6).map(function (v) { return v.l; }).join(" · ") +
                      (n > 6 ? " · +" + (n - 6) + " more" : "");
          tipOn(cell, "<b>" + esc(d.s) + " · " + esc(c.n) + "</b>" + fmt(n) + " measurement" +
                      (n === 1 ? "" : "s") + ': <span class="mm-d">' + esc(names) + "</span>",
                d.s + " · " + c.n + ": " + n + " measurements — " + names);
        } else {
          cell.title = d.s + " · " + c.n + ": none";
        }
        grid.appendChild(cell);
      });
    });
    mx.innerHTML = "";
    mx.appendChild(grid);
    mx.appendChild(el("div", "mm-ramp", "<span>fewer</span><i></i><span>more measurements</span>"));
    mx.classList.add("mm-drawn");
  }

  /* ── the datasets: dot · name · category · realm note · series · years · values ─────────── */
  var dl = document.getElementById("mm-dslist");
  if (dl) {
    dl.innerHTML = "";
    DS.forEach(function (d, di) {
      var ser = 0, vals = 0, y0 = null, y1 = null;
      ROWS.forEach(function (r) {
        (r.se || []).forEach(function (s) {
          if (s.d !== di) return;
          ser++;
          vals += s.n || 0;
          if (s.y0 != null && (y0 == null || s.y0 < y0)) y0 = s.y0;
          if (s.y1 != null && (y1 == null || s.y1 > y1)) y1 = s.y1;
        });
      });
      dl.appendChild(el("li", null,
        '<i class="mm-dot" style="background:' + esc(d.c) + '"></i>' +
        '<div><b><a href="' + esc(d.u) + '">' + esc(d.s) + "</a></b> " +
        '<span class="cc-muted mm-dscat">' + (d.cat && d.cat !== d.s ? esc(d.cat) : "") +
        (d.r === "bio" ? " · realm bio, rows in obs_env" : "") + "</span>" +
        '<span class="mm-m">' + fmt(ser) + " series" + (y0 != null ? " · " + y0 + "–" + y1 : "") +
        " · " + fmt(vals) + " values at the release grain" +
        (d.fr ? " · " + fmt(d.fr) + " full-resolution only" : "") + "</span></div>"));
    });
  }
})();
