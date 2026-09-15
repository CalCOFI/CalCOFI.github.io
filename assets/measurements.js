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

  /* ══ faces (WS-MF5) ══════════════════════════════════════════════════════════════════════
     The figures of the face row and of the What / How / Why sections (plan 2026-09-11
     "Measurement faces …" § D1–D7), all from ONE payload, #mm-face, that
     _plugins/measurements.rb writes out of measurements.json 1.1 and _data/measurements_media.json.

     Ported from the probe's template.html (whatFig, howCards, howCol2, scaleChart, anomalyBands,
     anomalySpark, bjerrum, ionBar, phStrip, beaufortMini, hairFigure), with three changes the real
     page needs:

       · every chart is drawn at its HOST's own measured width, one SVG unit per CSS pixel, so an
         11 px label is 11 px whether the column is 560 px or 1,100 px wide — the mockup could fix a
         1,000-unit viewBox because it owned the whole band; a page column cannot.
       · the structures are already inline in the page (they must be there with JS off), so the
         acid figure CLONES them rather than carrying a second copy of a 32 KB drawing.
       · nothing is typed: every value comes from the payload, and a figure whose payload is absent
         is not drawn and leaves no hole (the .mmf-drawn rule, the [viewBox] trap of 2026-09-09).

     A number IS formatted here (fmtN below) and a colour IS chosen here, both display decisions;
     no figure invents a value, a bound, a band or a date. */
  (function faces() {
    var F = readJSON("mm-face");
    if (!F) return;

    var WARM = "var(--mmf-warm)", COOL = "var(--mmf-cool)";
    var ION = ["var(--mmf-i1)", "var(--mmf-i2)", "var(--mmf-i3)", "var(--mmf-i4)",
               "var(--mmf-i5)", "var(--mmf-i6)", "var(--mmf-i7)", "var(--mmf-i8)", "var(--mmf-i9)"];

    function fmtN(n, d) {
      if (n == null || isNaN(n)) return "—";
      return Number(n).toLocaleString("en-US", { maximumFractionDigits: d == null ? 0 : d });
    }
    /* the host's own width, in CSS pixels, so the chart is drawn one SVG unit per pixel and its
       11 px labels are 11 px. Every host starts `display: none` (the .mmf-drawn rule), and a
       display:none element measures 0 — which drew a 320-unit chart that CSS then stretched to
       540 px, blowing every label up 1.7x and clipping the ends (measured 2026-09-12). So the
       class goes on BEFORE the measurement, never after. */
    function width(host, min) {
      host.classList.add("mmf-drawn");
      return Math.max(Math.round(host.getBoundingClientRect().width) || 0, min || 280);
    }
    function band(name) {
      var a = F.anomaly;
      if (!a) return null;
      var i, bs = a.bands || [];
      for (i = 0; i < bs.length; i++) if (bs[i].band === name) return bs[i];
      return bs[0] || null;
    }
    function bandTxt(b) { return String(b).replace("-", "–"); }
    /* a band's OWN scale: its largest departure, rounded UP to a tenth (never to the observed
       value itself — an axis a reader can hold). Below 0.1 the tenth would be 0.1 for everything,
       so the rounding follows the magnitude and `tdp` writes the matching decimals. */
    function bandTop(b) {
      var mx = 0;
      (b.series || []).forEach(function (r) { mx = Math.max(mx, Math.abs(r[1])); });
      if (!(mx > 0)) return 1;
      var step = Math.pow(10, Math.floor(Math.log10(mx)) - 1);
      return Math.ceil(mx / step) * step;
    }
    function tdp(v) { return v >= 10 ? 0 : v >= 1 ? 1 : v >= 0.1 ? 2 : 3; }
    /* one hover per chart row: the nearest year's own numbers, on the shared .mmf-tip */
    function yearHover(host, b, o) {
      var byYear = {};
      (b.series || []).forEach(function (r) { byYear[r[0]] = r; });
      var rule = svgEl("line", { cls: "mmf-hover", x1: 0, x2: 0, y1: o.top, y2: o.bottom, opacity: 0 }, host);
      var hit = svgEl("rect", { cls: "mmf-hit", x: o.L, y: o.top, width: o.W - o.L - o.R,
                                height: o.bottom - o.top }, host);
      hit.addEventListener("mousemove", function (ev) {
        var svg = host.ownerSVGElement || host, pt = svg.createSVGPoint();
        pt.x = ev.clientX; pt.y = ev.clientY;
        var p = pt.matrixTransform(svg.getScreenCTM().inverse());
        var yr = Math.floor(o.y0 + (p.x - o.L) / (o.W - o.L - o.R) * o.ny), r = byYear[yr];
        rule.setAttribute("x1", o.L + (yr - o.y0) / o.ny * (o.W - o.L - o.R) + o.bw / 2);
        rule.setAttribute("x2", rule.getAttribute("x1"));
        rule.setAttribute("opacity", 1);
        showTip(ev, "<b>" + esc(o.label) + " \u00b7 " + yr + "</b> " + (r
          ? (r[1] > 0 ? "+" : "") + fmtN(r[1], 2) + esc(units()) + " \u00b7 " + r[2] + " cruise" +
            (r[2] === 1 ? "" : "s") + " \u00b7 " + fmt(r[3]) + " values"
          : "no cruise with a normal"));
      });
      hit.addEventListener("mouseleave", function () { rule.setAttribute("opacity", 0); hideFaceTip(); });
    }
    function units() { return F.units ? " " + F.units : ""; }

    /* ── one tooltip for every face figure (round 2, WS-R2 · plan D4) ────────────────────────
       A mark, a window, a spark bar and a history bar all read on the SAME div, appended to the
       body once: a figure that scrolls inside `.mmf-scale-wrap` cannot clip it, and a page with
       no face never creates it. Every hover is ALSO written as a `<title>` on the mark it belongs
       to, so the fact is reachable without a mouse (the rule this file has kept since WS-M4). */
    var TIP = null;
    function tipDiv() {
      if (!TIP) { TIP = el("div", "mmf-tip"); TIP.setAttribute("aria-hidden", "true"); document.body.appendChild(TIP); }
      return TIP;
    }
    function moveTip(ev) {
      var t = tipDiv(), x = ev.clientX + 12, y = ev.clientY - 30;
      if (x + t.offsetWidth > window.innerWidth - 8) x = Math.max(4, ev.clientX - t.offsetWidth - 12);
      t.style.left = x + "px";
      t.style.top = Math.max(4, y) + "px";
    }
    function showTip(ev, html) {
      var t = tipDiv();
      t.innerHTML = html;
      t.style.display = "block";
      moveTip(ev);
    }
    function hideFaceTip() { if (TIP) TIP.style.display = "none"; }
    /* the hover contract: the tip on the move, gone on the leave, and the same words in a title */
    function hoverTip(node, html, plain) {
      if (plain) node.appendChild(svgEl("title", { text: plain }));
      node.addEventListener("mousemove", function (ev) { showTip(ev, html); });
      node.addEventListener("mouseleave", hideFaceTip);
    }

    /* ── the ramps: the Explorer's rule, COPIED VERBATIM ─────────────────────────────────────
       ../explore/src/ramps.ts @ e39e0bcf69a72e8c130b7b8ec1dd8d7757eb0c63 (`RAMPS` and
       `defaultRamp()`; unchanged by the WS-R6 audit, explore `ws-r6` 36f0022, which added
       lensRamp()/seriesRamp() AROUND it and left the per-variable rules alone). cmocean 0.3.2
       (Thyng et al. 2016, MIT) via the R package; viridis from viridisLite. Eleven stops each.

       The rules are the Explorer's, not this file's: a variable is matched on its KEY first and
       then on its label, exactly as the Explorer matches its variable name. Two deliberate
       differences, both of them the plan's (§ D4):
         · an unmatched variable gets NO ramp here (the plain strip), where the Explorer falls
           back to viridis — a map needs a colour, a 16 px strip does not;
         · `ph` keeps the page's own acid→base strip and a Beaufort key keeps its cells, so those
           two dispatches run BEFORE this one is consulted.
       An anomaly is `balance` in the Explorer; the spark and the history draw that ramp's two
       poles as --mmf-warm / --mmf-cool about the zero line, which is what they have always been. */
    var RAMPS = {
      viridis: "#440154,#482576,#414487,#35608D,#2A788E,#21908C,#22A884,#43BF71,#7AD151,#BBDF27,#FDE725",
      thermal: "#042333,#0F326B,#40349F,#684396,#8B538D,#B05F82,#D66C6B,#F2814D,#FCA63C,#F7CF45,#E8FA5B",
      haline:  "#2A186C,#2828A2,#0D4E96,#18668C,#2D7C89,#3B9287,#4AAA81,#64C072,#94D35D,#CFE06C,#FDEF9A",
      solar:   "#331418,#531E22,#732724,#8F341E,#A54A17,#B66313,#C47F15,#CF9B1D,#D8BA2A,#DEDA39,#E1FD4B",
      ice:     "#040613,#1B1B37,#302F5F,#3D4389,#3E5EA9,#427AB7,#5296C1,#6AB0CB,#8CCBD6,#BBE3E6,#EAFDFD",
      deep:    "#FDFECC,#C9EAB1,#92D8A4,#65C2A4,#52A8A3,#488E9E,#407498,#3E5A92,#41407B,#382D51,#281A2C",
      dense:   "#E6F1F1,#BBDBE5,#96C5E2,#7BACE4,#7390E3,#7771D5,#7953BA,#743A98,#682471,#531547,#360E24",
      algae:   "#D7F9D0,#B7E2AB,#96CD8A,#71BA6B,#44A855,#129450,#097C4A,#156641,#1A5034,#183A25,#122414",
      matter:  "#FEEDB0,#FAC98F,#F5A773,#EE835D,#E26253,#CE4356,#B22D5F,#932063,#721A60,#501652,#2F0F3E",
      tempo:   "#FFF6F4,#DBDECF,#B6CBAF,#8BB896,#5DA786,#2B937F,#117C79,#18656E,#1C4D61,#1A3651,#151D44",
      speed:   "#FFFDCD,#EDDE97,#D8C55F,#B7B12D,#8EA20B,#60920B,#317F1F,#0F6B2B,#10542C,#193B23,#172313"
    };
    /* ramps.ts defaultRamp(), rule for rule, in its own order */
    function rampRule(v) {
      v = String(v || "").toLowerCase();
      if (/sigma|dens/.test(v)) return "dense";   // before thermal: sigma_theta is a density (explore ws-r6 beec8cf)
      if (/temp|theta/.test(v)) return "thermal";
      if (/salin|salt/.test(v)) return "haline";
      if (/oxy/.test(v)) return "ice";   // not cmocean's oxy: its breaks assume a fixed 0–10 ml/L
      if (/chl|fluor|phyto|algae|prochl|synech/.test(v)) return "algae";
      if (/nitr|phos|silic|ammon|nutri/.test(v)) return "tempo";
      if (/par\b|light|irrad|rad/.test(v)) return "solar";
      if (/ph\b|alkal|dic|carbon|pco2/.test(v)) return "matter";
      if (/depth|bathy/.test(v)) return "deep";
      if (/wind|speed|current/.test(v) && !/dir/.test(v)) return "speed";   // a direction is not a speed
      return null;
    }
    function RAMP_OF(key, label) { return rampRule(key) || rampRule(label); }

    /* a mark's label on the ramp is short (the full one is the hover); ~12 characters is what the
       narrowest column (375 px) fits without two of them touching */
    function shortLab(s) {
      s = String(s || "").replace(/\s*\(.*?\)\s*/g, " ").trim();
      return s.length > 12 ? s.slice(0, 11).replace(/[\s,;:·-]+$/, "") + "…" : s;
    }

    /* ── the What glyph of a scale kind: the variable's ramp, drawn to its declared bounds ──────
       The GRADIENT is the ramp over the domain; the WINDOW is the record's own 5th–95th, drawn as
       an open frame in the page's ink (never colour alone — § D4's gate); the ENDS are the axis;
       each registry MARK is a rule in the page's ink with a short label, and the full label plus
       its source on hover. Nothing here is typed: the domain is the declared bound, or, where the
       record declares none, the observed minimum to maximum with a title that says so. */
    function ramp(host, o) {
      if (!host || !o || !o.dom || o.dom[0] == null || o.dom[1] == null || o.dom[1] <= o.dom[0]) return false;
      var W = Math.max(Math.round(host.getBoundingClientRect().width) || 0, 220);
      var L = 6, R = 6, y0 = 9, h = 16, rows = 0;
      var gid = "mmf-ramp-" + (o.id || "g");
      var x = function (v) {
        return L + (Math.min(Math.max(v, o.dom[0]), o.dom[1]) - o.dom[0]) / (o.dom[1] - o.dom[0]) * (W - L - R);
      };
      host.innerHTML = "";
      var defs = svgEl("defs", {}, host);
      var lg = svgEl("linearGradient", { id: gid, x1: 0, x2: 1, y1: 0, y2: 0 }, defs);
      /* a stop is a colour (evenly spaced, as the Explorer carries them) or a [colour, percent]
         pair (the pH strip, whose stops are anchored to the pH scale itself) */
      o.stops.forEach(function (c, i) {
        var col = c, off = i / (o.stops.length - 1) * 100;
        if (c && c.length === 2 && typeof c[0] === "string") { col = c[0]; off = c[1]; }
        svgEl("stop", { offset: Number(off).toFixed(2) + "%", "stop-color": col }, lg);
      });
      var bar = svgEl("rect", { x: L, y: y0, width: W - L - R, height: h, rx: 3, fill: "url(#" + gid + ")" }, host);
      if (o.domNote) bar.appendChild(svgEl("title", { text: o.domNote }));
      if (o.win && o.win[0] != null && o.win[1] != null) {
        var wx = x(o.win[0]), ww = Math.max(2, x(o.win[1]) - wx);
        svgEl("rect", { cls: "mmf-win", x: wx.toFixed(1), y: y0 - 3, width: ww.toFixed(1), height: h + 6, rx: 2 }, host);
        var hit = svgEl("rect", { cls: "mmf-hit", x: wx.toFixed(1), y: y0 - 3, width: ww.toFixed(1), height: h + 6 }, host);
        hoverTip(hit, "<b>the record</b> 5th–95th " + esc(o.fmt(o.win[0])) + " – " + esc(o.fmt(o.win[1])) +
                      (o.winsrc ? "<br>" + esc(o.winsrc) : ""),
                 "the record's 5th–95th percentile " + o.fmt(o.win[0]) + " – " + o.fmt(o.win[1]) +
                 (o.winsrc ? " · " + o.winsrc : ""));
      }
      svgEl("text", { cls: "mmf-tick", x: L, y: y0 + h + 13, text: o.fmt(o.dom[0]) }, host);
      svgEl("text", { cls: "mmf-tick", x: W - R, y: y0 + h + 13, "text-anchor": "end", text: o.fmt(o.dom[1]) }, host);
      /* the marks, left to right, staggered onto two rows so no two labels can touch. A label
         near an end ANCHORS to that end rather than being clamped: a centred label at x = 26 has
         half of itself outside the figure, and `.mmf-ramp` overflows visibly, so it painted over
         the axis end beside it (measured at 1470 px on temperature, whose −1.91 °C mark sits 6 px
         from the left edge of a −2 → 40 domain). */
      var mks = (o.marks || []).slice().sort(function (a, b) { return (a.v || 0) - (b.v || 0); });
      mks.forEach(function (m, i) {
        var mx = x(m.v), g = svgEl("g", { cursor: "help" }, host);
        svgEl("line", { cls: "mmf-mk", x1: mx, x2: mx, y1: y0 - 6, y2: y0 + h + 4 }, g);
        svgEl("path", { d: "M" + (mx - 4) + " " + (y0 + h + 4) + "h8l-4 5z", fill: "var(--fg)" }, g);
        var lv = i % 2;
        var anc = mx < W * 0.2 ? "start" : mx > W * 0.8 ? "end" : "middle";
        var lx = anc === "start" ? Math.max(mx - 4, L) : anc === "end" ? Math.min(mx + 4, W - R) : mx;
        rows = Math.max(rows, lv);
        svgEl("text", { cls: "mmf-mklab", x: lx, y: y0 + h + 27 + lv * 13, "text-anchor": anc,
                        text: shortLab(m.label) }, g);
        svgEl("rect", { cls: "mmf-hit", x: mx - 10, y: 0, width: 20, height: y0 + h + 32 }, g);
        hoverTip(g, "<b>" + esc(m.label) + "</b> " + esc(o.fmt(m.v)) + (m.src ? "<br>" + esc(m.src) : ""),
                 m.label + " " + o.fmt(m.v) + (m.src ? " \u00b7 " + m.src : ""));
      });
      host.setAttribute("viewBox", "0 0 " + W + " " + (y0 + h + 32 + rows * 13));
      host.classList.add("mmf-drawn");
      return true;
    }

    /* the ramp's own domain: the DECLARED bound, else the observed minimum to maximum with a
       title that says which it is (§ D7 — a number is in the record or it is not drawn) */
    function rampDomain(sc) {
      var b = sc.bounds || {};
      if (b.valid_min != null && b.valid_max != null && b.valid_max > b.valid_min) {
        return { dom: [b.valid_min, b.valid_max],
                 note: "the declared bounds " + b.valid_min + " to " + b.valid_max + (F.units ? " " + F.units : "") };
      }
      var lo = null, hi = null;
      (sc.series || []).forEach(function (s) {
        var o = s.o || {};
        if (o.min != null) lo = lo == null ? o.min : Math.min(lo, o.min);
        if (o.max != null) hi = hi == null ? o.max : Math.max(hi, o.max);
      });
      if (lo == null || hi == null || hi <= lo) return null;
      return { dom: [lo, hi],
               note: "no declared bound: drawn over the record's own minimum to maximum, " +
                     fmtN(lo, 2) + " to " + fmtN(hi, 2) + (F.units ? " " + F.units : "") };
    }

    /* ── the platform glyphs, on the brand icons' own 24-unit grid ───────────────────────── */
    var PG = {
      bottle: '<rect x="8" y="4" width="8" height="16" rx="2"/><path d="M8 7h8M8 17h8M12 1.5v2.5M12 20v2.5"/>',
      ctd: '<circle cx="12" cy="12" r="9"/><rect x="10.3" y="7" width="3.4" height="10" rx="1"/><path d="M12 1v2M5.2 6.5l1.6 1M18.8 6.5l-1.6 1M5.2 17.5l1.6-1M18.8 17.5l-1.6-1"/>',
      mast: '<path d="M12 22V6M8 22h8M12 6H7M12 6h5"/><circle cx="6" cy="6" r="1.6"/><circle cx="18" cy="6" r="1.6"/><path d="M12 3v3"/>',
      underway: '<path d="M3 17h18M5 17l2-5h10l2 5M9 12V7h6v5"/><path d="M3 21h18" stroke-dasharray="2 3"/>',
      lab: '<path d="M12 2v20"/><path d="M2 12h7M15 12h7" stroke-dasharray="2 2"/><circle cx="12" cy="12" r="2.2"/><circle cx="12" cy="6" r="1.1"/><circle cx="12" cy="17.5" r="1.1"/>',
      net: '<path d="M4 4h16l-4 16H8z"/><path d="M7 8h10M6 12h12M8 16h8M12 4v16"/>'
    };
    [].forEach.call(document.querySelectorAll(".mmf-pg"), function (n) {
      var p = PG[n.getAttribute("data-platform")];
      if (!p) return;
      n.insertAdjacentHTML("afterbegin",
        '<svg viewBox="0 0 24 24" aria-hidden="true">' + p + "</svg>");
    });

    /* ── the spectrum strip: where the method reads, on one visible-light ramp ───────────── */
    [].forEach.call(document.querySelectorAll(".mmf-spec"), function (n) {
      var nm = Number(n.getAttribute("data-nm"));
      if (!nm) return;
      var lo = 300, hi = 850, p = function (v) { return ((v - lo) / (hi - lo) * 100).toFixed(1) + "%"; };
      n.innerHTML = '<i class="mmf-mk" style="left:' + p(nm) + '"><span>' + nm + " nm</span></i>" +
        [[350, "UV"], [450, ""], [550, "visible"], [650, ""], [800, "near-IR"]].map(function (a) {
          return '<span class="mmf-ax" style="left:' + p(a[0]) + '">' + a[0] + (a[1] ? " " + a[1] : "") + "</span>";
        }).join("");
    });

    /* ── the small figures of the face row's What column ─────────────────────────────────── */
    function ionsHTML(small) {
      var c = F.composition;
      /* a composition face whose record carries mass fractions on `chem[]` but no composition
         block draws the same bar from those rows (§ D4: the ion bar is the face row's glyph for
         EVERY composition kind that has shares to draw) */
      if (!c || !c.ions) {
        var ch = (F.chem || []).filter(function (x) { return x.fraction != null; });
        if (ch.length) c = { ions: ch.map(function (x) { return [x.formula || x.name, x.name, x.fraction, x.chebi]; }) };
      }
      if (!c || !c.ions) return "";
      return '<div class="mmf-ions' + (small ? " mmf-ions-sm" : "") + '">' + c.ions.map(function (x, i) {
        var p = x[2] * 100;
        return '<div style="width:' + p + "%;background:" + ION[i % ION.length] + '" title="' +
          esc(x[0] + " " + x[1] + " " + p.toFixed(2) + " %") + '">' +
          (p > 6 ? esc(x[0]) + (small ? "" : " " + p.toFixed(1) + " %") : "") + "</div>";
      }).join("") + "</div>";
    }
    function hairHTML(small) {
      var t = F.taxon;
      if (!t || !t.hair_um || !t.size_um) return "";
      var n = Math.round(t.hair_um / ((t.size_um[0] + t.size_um[1]) / 2));
      /* a size source may give one length rather than a range: say the one it gave */
      var sz = t.size_um[0] === t.size_um[1] ? String(t.size_um[0]) : t.size_um[0] + "–" + t.size_um[1];
      var R = 70, cx = 80, cy = 80, d = (2 * R) / n, dots = "", i;
      for (i = 0; i < n; i++) {
        dots += '<circle cx="' + (cx - R + d / 2 + i * d).toFixed(2) + '" cy="' + cy +
          '" r="' + (d * 0.42).toFixed(2) + '" fill="var(--accent)"/>';
      }
      return '<svg class="mmf-hair" viewBox="0 0 ' + (small ? 160 : 340) + ' 160" role="img" aria-label="' +
        "A hair cut across, with " + n + " cells of " + sz +
        ' µm in a row across it"><circle cx="' + cx + '" cy="' + cy + '" r="' + R +
        '" fill="none" stroke="currentColor" stroke-width="1.5"/>' + dots +
        (small ? "" :
          '<text x="168" y="62" class="mmf-lab">a hair, cut across: ' + t.hair_um + ' µm</text>' +
          '<text x="168" y="86" class="mmf-lab" fill="var(--accent)">' + n + " cells of " +
          sz + ' µm</text>' +
          '<text x="168" y="106" class="mmf-tick">size: ' + esc(t.size_src || "") + "</text>") + "</svg>";
    }
    /* the pH strip and the temperature-like strip: the record's own 5th–95th percentile, boxed on
       the ramp everyone already reads. The ramp is a display choice; the box is measured. */
    function stripHTML(lo, hi, ramp, loLab, hiLab, lead, dp) {
      var o = F.ph;
      if (!o) return "";
      var x = function (v) { return ((Math.min(Math.max(v, lo), hi) - lo) / (hi - lo) * 100).toFixed(2) + "%"; };
      return '<div class="mmf-strip" style="background:' + ramp + '">' +
        '<i style="left:' + x(o.p05) + ";width:calc(" + x(o.p95) + " - " + x(o.p05) + ')"></i></div>' +
        '<div class="mmf-strip-ax"><span>' + esc(loLab) + "</span><span>" + esc(hiLab) + "</span></div>" +
        '<p class="mmf-line">' + esc(lead) + " <b>" + fmtN(o.p05, dp) + "–" + fmtN(o.p95, dp) +
        esc(units()) + "</b> (5th–95th percentile)</p>";
    }
    function beaufortOf(v, rows) {
      var i;
      for (i = rows.length - 1; i >= 0; i--) if (v >= rows[i][1]) return rows[i];
      return rows[0];
    }
    function bandText(b, unit) {
      /* the top band is open in the source ("≥ 32.7 m/s") — say so rather than draw a blank */
      return b[2] == null ? "≥ " + b[1] + " " + unit : b[1] + "–" + b[2] + " " + unit;
    }
    function beaufortHTML() {
      var sc = F.scale, rows = sc && sc.axis && sc.axis.beaufort, o = F.ph;
      if (!rows || !o) return "";
      var kn = sc.axis.beaufort_knots;
      var b50 = beaufortOf(o.p50, rows), b95 = beaufortOf(o.p95, rows);
      /* the cells carry the variable's own ramp (wind → speed by the Explorer's rule, § D4) so
         the row reads as a scale rather than as thirteen boxes; the two the record lands on are
         OUTLINED in the page's ink, never distinguished by colour alone */
      var rid = RAMP_OF(F.key, F.label), stops = RAMPS[rid] ? RAMPS[rid].split(",") : null;
      var h = '<div class="mmf-bf">' + rows.map(function (b, i) {
        var on = b[0] === b50[0] || b[0] === b95[0];
        var c = stops ? stops[Math.round(i / (rows.length - 1) * (stops.length - 1))] : "";
        return '<i class="' + (on ? "on" : "") + '"' + (c ? ' style="background:' + c + '"' : "") +
          ' title="' + esc(b[0] + " " + b[3] + ", " + bandText(b, "m/s")) + '">' + b[0] + "</i>";
      }).join("") + "</div>" +
        '<p class="mmf-line">Read as m/s, Beaufort force at the median <b>' + b50[0] +
        "</b> and the 95th percentile <b>" + b95[0] + "</b>";
      /* the same numbers read as knots: the series is DECLARED m/s and runs high for it, which is
         an open question on the dataset, so the page shows the force under each reading rather
         than deciding which one the values are */
      if (kn && kn.length === rows.length) {
        var k50 = beaufortOf(o.p50, kn), k95 = beaufortOf(o.p95, kn);
        h += "; read as knots, <b>" + k50[0] + "</b> and <b>" + k95[0] + "</b>";
      }
      return h + (sc.axis.beaufort_source
        ? ' <span class="mmf-credit">' + (sc.axis.beaufort_url
            ? '<a href="' + esc(sc.axis.beaufort_url) + '" rel="external">' + esc(sc.axis.beaufort_source) + "</a>"
            : esc(sc.axis.beaufort_source)) + "</span>"
        : "") + "</p>";
    }
    /* the mini scale: the record's 5th–95th on the declared/observed domain, with the two nearest
       marks named under it — a property's face is the scale it is read on (§ D2) */
    function miniHTML() {
      var sc = F.scale, o = F.ph;
      if (!sc || !sc.axis || !o) return "";
      var dm = sc.axis.domain, marks = (sc.marks || []).filter(function (r) { return !r.off && r.v != null; });
      var x = function (v) { return ((Math.min(Math.max(v, dm[0]), dm[1]) - dm[0]) / (dm[1] - dm[0]) * 100).toFixed(2) + "%"; };
      return '<div class="mmf-strip mmf-strip-plain">' +
        '<i style="left:' + x(o.p05) + ";width:calc(" + x(o.p95) + " - " + x(o.p05) + ')"></i>' +
        marks.map(function (r) { return '<u style="left:' + x(r.v) + '" title="' + esc(r.label + " · " + (r.src || "")) + '"></u>'; }).join("") +
        "</div>" +
        '<div class="mmf-strip-ax"><span>' + fmtN(dm[0], 2) + "</span><span>" + fmtN(dm[1], 2) + "</span></div>" +
        '<p class="mmf-line">This measurement’s <b>' + fmtN(o.p05, 2) + "–" + fmtN(o.p95, 2) + esc(units()) +
        "</b> (5th–95th percentile)" + (marks.length ? ", against " + marks.slice(0, 2).map(function (r) { return esc(r.label); }).join(" and ") : "") + "</p>";
    }
    var PH_RAMP = "linear-gradient(90deg,#d7263d 0%,#f46036 14%,#f5b700 29%,#c5d86d 43%,#3fa34d 50%,#1b998b 60%,#2e86ab 72%,#3c4f9c 86%,#5b2a86 100%)";
    /* the same strip as a stop list, so the marks can be drawn ON it (M6: pH already had the
       ramp; its nine registry marks were not on it). The percentages are the pH scale's own. */
    var PH_STOPS = [["#d7263d", 0], ["#f46036", 14], ["#f5b700", 29], ["#c5d86d", 43], ["#3fa34d", 50],
                    ["#1b998b", 60], ["#2e86ab", 72], ["#3c4f9c", 86], ["#5b2a86", 100]];

    /* the line under a ramp: the record's own window, and the two marks nearest it named — the
       plain strip's own sentence, kept word for word so every kind reads the same way */
    function rampLine(marks, dp) {
      var o = F.ph;
      return '<p class="mmf-line">This measurement’s <b>' + fmtN(o.p05, dp) + "–" + fmtN(o.p95, dp) +
        esc(units()) + "</b> (5th–95th percentile)" +
        (marks.length ? ", against " + marks.slice(0, 2).map(function (r) { return esc(r.label); }).join(" and ") : "") +
        "</p>";
    }
    /* draw a ramp into the What column: an <svg> host and the line under it */
    function rampWhat(host, stops, dom, note, dp, aria) {
      var sc = F.scale, o = F.ph;
      if (!sc || !o || o.p05 == null || o.p95 == null || !dom) return false;
      var marks = (sc.marks || []).filter(function (r) {
        return !r.off && r.v != null && r.v >= dom[0] && r.v <= dom[1];
      });
      host.innerHTML = "";
      var svg = svgEl("svg", { cls: "mmf-ramp", role: "img", "aria-label": aria }, host);
      var ok = ramp(svg, { id: F.key, stops: stops, dom: dom, domNote: note,
                           win: [o.p05, o.p95],
                           winsrc: "the release record, 5th–95th percentile",
                           marks: marks,
                           fmt: function (v) { return fmtN(v, dp) + (F.units ? " " + F.units : ""); } });
      if (!ok) return false;
      host.insertAdjacentHTML("beforeend", rampLine(marks, dp));
      return true;
    }

    /* what the face row's What column shows when there is no structure to draw (§ D4: a figure has
       a ramp or an axis, labels on it, and a hover — one rule per face kind, in this order) */
    var mini = document.getElementById("mmf-mini");
    if (mini) {
      var h = "", drew = false;
      if (F.composition || (F.chem || []).some(function (x) { return x.fraction != null; })) h = ionsHTML(true);
      /* an organism's figure needs a measured cell size AND a measured hair; where the species
         media carry neither, the count is still read on its own scale — a face falls back, it
         never leaves the column empty (check_layout, 2026-09-12) */
      else if (F.taxon) h = hairHTML(true) || miniHTML();
      else if (F.scale && F.scale.axis && F.scale.axis.type === "beaufort") h = beaufortHTML();
      else if (F.key === "ph") {
        drew = rampWhat(mini, PH_STOPS, [0, 14], "the pH scale, 0 acid to 14 base", 2,
                        "pH from 0 to 14 with the record’s 5th–95th percentile and its familiar marks");
      } else {
        var rid = F.scale && RAMP_OF(F.key, F.label), dm = F.scale && rampDomain(F.scale);
        if (rid && dm) {
          drew = rampWhat(mini, RAMPS[rid].split(","), dm.dom, dm.note, 2,
                          (F.label || F.key) + " on the cmocean " + rid + " ramp, " +
                          fmtN(dm.dom[0], 2) + " to " + fmtN(dm.dom[1], 2) + (F.units ? " " + F.units : "") +
                          ", with the record’s 5th–95th percentile and its familiar marks");
        }
        if (!drew) h = miniHTML();
      }
      if (h) { mini.innerHTML = h; drew = true; }
      if (drew) mini.classList.add("mmf-drawn");
    }

    /* ── the face row's Why spark: the band with the most values, on ITS OWN scale ──────────
       (round 2, M4.) 100 px rather than 58, drawn to the SPARK BAND's own maximum rather than to
       the page-wide `anomaly.ymax` — at 200–500 m temperature departs by 0.6 °C where the page's
       scale is ±2.2 °C, and the row read as a line. The left axis says which scale it is on
       (+top · 0 · −top), four year ticks put the bars in time, the trend is drawn where the record
       has one, strong El Niño years are shaded, and every year hovers to its own numbers. */
    var SPARK_TOP = null;
    (function spark() {
      var host = document.getElementById("mmf-spark");
      if (!host || !F.anomaly) return;
      var b = band(F.anomaly.spark_band);
      if (!b || !(b.series || []).length) return;
      var W = width(host, 240), H = 100, L = 30, R = 4, Tm = 8, B = 16;
      var y0 = F.y0, y1 = F.y1, ny = y1 - y0 + 1;
      /* the band's own maximum, rounded UP to a tenth: the axis label is a number the reader can
         hold, and no bar is ever clipped by its own scale */
      var top = bandTop(b);
      SPARK_TOP = top;
      var x = function (yr) { return L + (yr - y0) / ny * (W - L - R); }, bw = (W - L - R) / ny;
      var y = function (v) { v = Math.max(-top, Math.min(top, v)); return Tm + (top - v) / (2 * top) * (H - Tm - B); };
      host.setAttribute("viewBox", "0 0 " + W + " " + H);
      host.removeAttribute("preserveAspectRatio");
      host.innerHTML = "";
      (F.oni.strong || []).forEach(function (yr) {
        if (yr < y0 || yr > y1) return;
        svgEl("rect", { cls: "mmf-nino", x: x(yr).toFixed(1), y: Tm, width: bw.toFixed(1), height: H - Tm - B }, host);
      });
      svgEl("line", { cls: "mmf-gr", x1: L, x2: W - R, y1: y(top), y2: y(top) }, host);
      svgEl("line", { cls: "mmf-gr", x1: L, x2: W - R, y1: y(-top), y2: y(-top) }, host);
      b.series.forEach(function (r) {
        svgEl("rect", { x: (x(r[0]) + bw * 0.12).toFixed(1), y: Math.min(y(r[1]), y(0)).toFixed(1),
                        width: Math.max(bw * 0.76, 0.8).toFixed(1),
                        height: Math.max(Math.abs(y(r[1]) - y(0)), 0.8).toFixed(1),
                        fill: r[1] >= 0 ? WARM : COOL, opacity: r[2] >= 2 ? 1 : 0.35 }, host);
      });
      svgEl("line", { cls: "mmf-zero", x1: L, x2: W - R, y1: y(0), y2: y(0) }, host);
      if (b.trend && b.trend.per_decade != null && b.trend.intercept != null) {
        var t = b.trend, f = function (yr) { return t.intercept + (t.per_decade / 10) * yr; };
        svgEl("line", { cls: "mmf-trend", x1: x(t.from) + bw / 2, x2: x(t.to) + bw / 2,
                        y1: y(f(t.from)), y2: y(f(t.to)) }, host);
      }
      /* the axis: the scale this band is drawn to, said in numbers */
      svgEl("text", { cls: "mmf-tick", x: L - 4, y: y(top) + 4, "text-anchor": "end", text: "+" + fmtN(top, tdp(top)) }, host);
      svgEl("text", { cls: "mmf-tick", x: L - 4, y: y(0) + 4, "text-anchor": "end", text: "0" }, host);
      svgEl("text", { cls: "mmf-tick", x: L - 4, y: y(-top) + 4, "text-anchor": "end", text: "\u2212" + fmtN(top, tdp(top)) }, host);
      var yr;
      for (yr = Math.ceil(y0 / 20) * 20; yr <= y1; yr += 20) {
        svgEl("text", { cls: "mmf-tick", x: x(yr) + bw / 2, y: H - 3, "text-anchor": "middle", text: String(yr) }, host);
      }
      yearHover(host, b, { L: L, R: R, W: W, y0: y0, ny: ny, bw: bw, top: Tm, bottom: H - B, label: bandTxt(b.band) + " m" });
      host.classList.add("mmf-drawn");
      var line = document.getElementById("mmf-spark-line");
      if (line) {
        var tr = b.trend, txt;
        if (tr && tr.per_decade != null) {
          txt = "<b>" + (tr.per_decade >= 0 ? "+" : "\u2212") + fmtN(Math.abs(tr.per_decade), 2) + esc(units()) +
            "</b> per decade at " + bandTxt(b.band) + " m since " + tr.from;
        } else if (b.ext) {
          txt = "Highest year at " + bandTxt(b.band) + " m <b>" + b.ext.hi[0] + "</b>, " +
            (b.ext.hi[1] > 0 ? "+" : "") + fmtN(b.ext.hi[1], 2) + esc(units());
        } else { txt = bandTxt(b.band) + " m"; }
        line.innerHTML = txt + ' <span class="cc-muted">\u00b7 drawn to \u00b1' + fmtN(top, tdp(top)) + esc(units()) + "</span>";
      }
    })();

    /* ── What, at length: the composition table, the Bjerrum plot, the hair, the scale ───── */
    (function whatFig() {
      var host = document.getElementById("mmf-what");
      if (!host) return;
      var h = "";
      if (F.composition) {
        var c = F.composition;
        h = ionsHTML(false) + '<table class="mmf-ion-tbl"><tbody>' + c.ions.map(function (x, i) {
          return "<tr><td><i class='mmf-sw' style='background:" + ION[i % ION.length] + "'></i><b>" +
            esc(x[0]) + "</b> " + esc(x[1]) + "</td><td class='n'>" + (x[2] * 100).toFixed(2) + " %</td><td class='n'>" +
            (x[3] ? '<a href="https://www.ebi.ac.uk/chebi/searchId.do?chebiId=' + esc(x[3]) + '">' + esc(x[3]) + "</a>" : "") +
            "</td></tr>";
        }).join("") + '</tbody></table><p class="mmf-credit">' + esc(c.src || "") + "</p>";
      } else if (F.taxon) {
        h = hairHTML(false) || miniHTML();
      } else if (F.key === "ph") {
        h = stripHTML(0, 14, PH_RAMP, "0 acid", "14 base", "This measurement’s", 2);
      } else if (F.scale && F.scale.axis && F.scale.axis.type === "beaufort") {
        h = beaufortHTML();
      }
      if (h) { host.innerHTML = h; host.classList.add("mmf-drawn"); }
      if (F.bjerrum) bjerrum(host);
    })();

    /* the Bjerrum plot: how a pool of inorganic carbon splits by pH, with the record's own CTD pH
       band marked. The curve is computed at release and carried in the payload. */
    function bjerrum(host) {
      var b = F.bjerrum;
      if (!b || !b.curve) return;
      var W = Math.max(Math.round(host.getBoundingClientRect().width) || 0, 320), H = 250, L = 44, R = 16, T = 16, B = 38;
      var x = function (p) { return L + (p - 4) / 7 * (W - L - R); };
      var y = function (f) { return T + (1 - f) * (H - T - B); };
      var line = function (i) {
        return b.curve.map(function (r, j) { return (j ? "L" : "M") + x(r[0]).toFixed(1) + "," + y(r[i]).toFixed(1); }).join("");
      };
      var svg = svgEl("svg", { cls: "mmf-chart mmf-drawn", viewBox: "0 0 " + W + " " + H, role: "img",
                               "aria-label": "Bjerrum plot: the share of dissolved CO2, bicarbonate and carbonate by pH" });
      var p;
      for (p = 4; p <= 11; p++) {
        svgEl("line", { cls: "mmf-gr", x1: x(p), x2: x(p), y1: T, y2: H - B }, svg);
        svgEl("text", { cls: "mmf-tick", x: x(p), y: H - B + 16, "text-anchor": "middle", text: String(p) }, svg);
      }
      [0, 0.5, 1].forEach(function (f) {
        svgEl("text", { cls: "mmf-tick", x: L - 6, y: y(f) + 4, "text-anchor": "end", text: (f * 100) + "%" }, svg);
      });
      if (F.ph) {
        svgEl("rect", { x: x(F.ph.p05), y: T, width: Math.max(1, x(F.ph.p95) - x(F.ph.p05)),
                        height: H - T - B, fill: "var(--accent-bg)" }, svg);
      }
      [[1, "var(--mmf-i4)", "6 0"], [2, "var(--mmf-i1)", "6 0"], [3, "var(--mmf-i2)", "6 4"]].forEach(function (a) {
        svgEl("path", { d: line(a[0]), fill: "none", stroke: a[1], "stroke-width": 2.3, "stroke-dasharray": a[2] }, svg);
      });
      svgEl("line", { x1: x(b.pH), x2: x(b.pH), y1: T, y2: H - B, stroke: "var(--fg)", "stroke-width": 1.5 }, svg);
      /* the labels sit beside the surface-pH rule, and flip to its left where there is no room on
         its right — .mmf-chart may overflow, but its scrolling wrapper still clips */
      var lx = x(b.pH), side = lx > W * 0.55 ? -6 : 6, anc = side < 0 ? "end" : "start";
      svgEl("text", { cls: "mmf-lab", x: lx + side, y: y(0.42), "text-anchor": anc,
                      text: "surface pH " + fmtN(b.pH, 2) }, svg);
      svgEl("text", { cls: "mmf-lab-m", x: lx + side, y: y(0.42) + 15, "text-anchor": anc,
                      text: fmtN(b.hco3, 1) + " % HCO₃⁻, " + fmtN(b.co3, 1) + " % CO₃²⁻" }, svg);
      svgEl("text", { cls: "mmf-lab-m", x: lx + side, y: y(0.42) + 30, "text-anchor": anc,
                      text: fmtN(b.co2, 2) + " % CO₂" }, svg);
      svgEl("line", { cls: "mmf-ax", x1: L, x2: W - R, y1: H - B, y2: H - B }, svg);
      svgEl("text", { cls: "mmf-tick", x: (W + L) / 2, y: H - 4, "text-anchor": "middle", text: "pH" }, svg);
      host.appendChild(svg);
      host.appendChild(el("p", "mmf-credit", esc(b.src || "") +
        (b.omega_arag != null ? " · aragonite saturation Ω " + fmtN(b.omega_arag, 1) : "") +
        (b.pco2 != null ? ", pCO₂ " + fmtN(b.pco2) + " µatm" : "")));
      host.classList.add("mmf-drawn");
    }

    /* ── How: the acid figure, cloned from the structures already on the page ────────────── */
    (function acid() {
      var host = document.getElementById("mmf-acid");
      if (!host) return;
      var mols = document.querySelectorAll(".mmf-molcard");
      if (mols.length < 2) return;
      var a = mols[0].cloneNode(true), b = mols[1].cloneNode(true);
      host.appendChild(el("div", "mmf-arrow", "<b>→</b>acid: H⁺ in, Mg²⁺ out"));
      host.insertBefore(a, host.firstChild);
      host.appendChild(b);
      host.className = "mmf-mols mmf-drawn";
    })();

    /* ── How: where in the water column, one thin bar per series per band ────────────────── */
    (function col() {
      var host = document.getElementById("mmf-col"), D2 = readJSON("mm-depth-data");
      if (!host || !D2 || !D2.rows || !D2.rows.length) return;
      host.innerHTML = "";
      (D2.bands || []).forEach(function (b) {
        host.appendChild(el("div", "mmf-dl", esc(b) + " m"));
        var bars = el("div", "mmf-bars");
        D2.rows.forEach(function (r) {
          var tot = 0, k;
          for (k in (r.b || {})) tot += r.b[k] || 0;
          var n = (r.b || {})[b] || 0, p = tot ? (n / tot) * 100 : 0;
          var bar = el("i", "mmf-bar");
          bar.style.width = Math.max(p, p > 0 ? 0.6 : 0).toFixed(1) + "%";
          bar.style.background = r.c || "var(--muted)";
          bar.title = shortName(r.s) + ": " + fmt(n) + " values, " + p.toFixed(1) + " %";
          bars.appendChild(bar);
        });
        host.appendChild(bars);
      });
      host.classList.add("mmf-drawn");
    })();

    /* ── Why: the familiar scale (§ D7) ──────────────────────────────────────────────────── */
    function ticks(lo, hi, n) {
      var span = hi - lo, step = Math.pow(10, Math.floor(Math.log10(span / n))), err = span / n / step, t = [], v;
      if (err >= 7.5) step *= 10; else if (err >= 3.5) step *= 5; else if (err >= 1.5) step *= 2;
      for (v = Math.ceil(lo / step) * step; v <= hi + 1e-9; v += step) t.push(+v.toFixed(10));
      return t;
    }
    (function scaleChart() {
      var host = document.getElementById("mmf-scale"), sc = F.scale;
      if (!host || !sc || !sc.axis) return;
      var W = width(host, 320), L = 20, R = 20, rows = (sc.series || []).length;
      var top = 30 + rows * 36, axY = top + 6, H = axY + 44;
      var dm = sc.axis.domain, log = sc.axis.type === "log";
      var x = function (v) {
        v = Math.min(Math.max(v, dm[0]), dm[1]);
        return log ? L + (Math.log10(v) - Math.log10(dm[0])) / (Math.log10(dm[1]) - Math.log10(dm[0])) * (W - L - R)
                   : L + (v - dm[0]) / (dm[1] - dm[0]) * (W - L - R);
      };
      host.innerHTML = "";
      var g = svgEl("g", {}, host);
      if (sc.axis.type === "beaufort" && sc.axis.beaufort) {
        sc.axis.beaufort.forEach(function (b, i) {
          var x0 = x(b[1]), x1 = x(i + 1 < sc.axis.beaufort.length ? sc.axis.beaufort[i + 1][1] : dm[1]);
          svgEl("rect", { x: x0, y: axY - 14, width: Math.max(0, x1 - x0), height: 14,
                          fill: i % 2 ? "var(--panel)" : "var(--accent-bg)" }, g);
          svgEl("text", { cls: "mmf-tick", x: (x0 + x1) / 2, y: axY - 3, "text-anchor": "middle", text: String(b[0]) }, g);
        });
      }
      var tk = [], e;
      if (log) { for (e = Math.ceil(Math.log10(dm[0])); e <= Math.log10(dm[1]); e++) tk.push(Math.pow(10, e)); }
      else tk = ticks(dm[0], dm[1], Math.max(4, Math.round(W / 110)));
      tk.forEach(function (v) {
        svgEl("line", { cls: "mmf-gr", x1: x(v), x2: x(v), y1: 16, y2: axY }, g);
        svgEl("text", { cls: "mmf-tick", x: x(v), y: axY + 16, "text-anchor": "middle",
                        text: Math.abs(v) >= 1000 ? fmtN(v) : fmtN(v, 2) }, g);
      });
      svgEl("line", { cls: "mmf-ax", x1: L, x2: W - R, y1: axY, y2: axY }, g);
      [["minimum", sc.bounds.valid_min], ["maximum", sc.bounds.valid_max]].forEach(function (p) {
        if (p[1] == null || p[1] < dm[0] || p[1] > dm[1]) return;
        svgEl("line", { cls: "mmf-bnd", x1: x(p[1]), x2: x(p[1]), y1: 10, y2: axY }, g);
        svgEl("text", { cls: "mmf-lab-m", x: x(p[1]), y: 9,
                        "text-anchor": p[0] === "minimum" ? "start" : "end",
                        text: "declared " + p[0] + " " + p[1] }, g);
      });
      (sc.series || []).forEach(function (s, i) {
        var o = s.o || {}, yy = 34 + i * 36, col = s.c || "var(--muted)";
        if (o.p05 == null || o.p95 == null) return;
        var lo = log ? Math.max(o.p05, dm[0]) : o.p05;
        svgEl("rect", { x: x(lo), y: yy, width: Math.max(2, x(o.p95) - x(lo)), height: 12, rx: 3,
                        fill: col, opacity: 0.85 }, g)
          .appendChild(svgEl("title", { text: shortName(s.s) + " " + s.mt + ": 5th–95th percentile " +
                                              fmtN(o.p05, 2) + "–" + fmtN(o.p95, 2) }));
        if (o.min != null && o.max != null) {
          svgEl("line", { x1: x(log ? Math.max(o.min, dm[0]) : o.min), x2: x(o.max), y1: yy + 6, y2: yy + 6,
                          stroke: col, "stroke-width": 1 }, g);
        }
        if (o.p50 != null) {
          svgEl("circle", { cx: x(o.p50), cy: yy + 6, r: 5, fill: "var(--bg)", stroke: "var(--fg)", "stroke-width": 2 }, g);
        }
        svgEl("text", { cls: "mmf-lab-m", x: Math.min(x(lo), Math.max(L, W - 380)), y: yy - 5,
                        text: shortName(s.s) + " · 5–95 % " + fmtN(o.p05, 2) + "–" + fmtN(o.p95, 2) +
                              ", median " + fmtN(o.p50, 2) }, g);
      });
      /* The marks below the axis, staggered so no two labels can collide. Two passes, because a
         label's width is the FONT's, not the string's: the one-pass estimate (characters x 6.4)
         is right at 1,100 px and wrong at 375 px, where "seawater (S 35) freezes · -1.91" and
         "a human body · 37" both landed on row 0 and overlapped (check_layout.py reads their
         boxes back out of the DOM, 2026-09-12). So: draw every label, measure it, then assign
         rows from the measured widths and move each one to its row. */
      var refs = (sc.marks || []).slice().sort(function (a, b) { return (a.v || 0) - (b.v || 0); });
      var drawn = [], maxLv = 0;
      refs.forEach(function (r) {
        if (r.v == null) return;
        var off = r.off || r.v > dm[1], xv = off ? W - R : x(r.v);
        var lab = r.label + (off ? " " + fmtN(r.v) + " →" : " · " + fmtN(r.v, 2));
        var anchor = xv > W - 140 ? "end" : xv < 140 ? "start" : "middle";
        var col = r.kind === "threshold" ? "var(--warn)" : r.kind === "physical" ? "var(--accent)" : "var(--fg)";
        if (r.lo != null && r.hi != null) {
          svgEl("rect", { x: x(r.lo), y: axY + 2, width: Math.max(2, x(r.hi) - x(r.lo)), height: 6, fill: col, opacity: 0.6 }, g);
        }
        var lead = svgEl("line", { cls: "mmf-lead", x1: xv, x2: xv, y1: axY + 2, y2: axY + 25 }, g);
        svgEl("path", { d: "M" + xv + " " + (axY + 1) + "l-4 7h8z", fill: col }, g);
        var t = svgEl("text", { cls: "mmf-lab mmf-mark", x: xv, y: axY + 36, "text-anchor": anchor,
                                style: "fill:" + col, text: lab }, g);
        if (r.src) t.appendChild(svgEl("title", { text: r.src }));
        drawn.push({ t: t, lead: lead, x: xv, anchor: anchor });
      });
      drawn.forEach(function (o) {
        var w = 0;
        try { w = o.t.getComputedTextLength(); } catch (e) {}
        if (!w) w = (o.t.textContent || "").length * 6.4;     // no layout yet (a headless probe)
        o.lo = o.anchor === "start" ? o.x : o.anchor === "end" ? o.x - w : o.x - w / 2;
        o.hi = o.lo + w;
      });
      drawn.forEach(function (o, i) {
        var lv = 0, j;
        for (;;) {
          var clash = false;
          for (j = 0; j < i; j++) {
            if (drawn[j].lv === lv && o.lo < drawn[j].hi + 8 && drawn[j].lo < o.hi + 8) { clash = true; break; }
          }
          if (!clash) break;
          lv++;
        }
        o.lv = lv;
        maxLv = Math.max(maxLv, lv);
        /* 20, not 17: a 12.5 px label's BOX is ~18 px tall, so 17 left the rows one pixel
           into each other and check_layout.py read that as an overlap (2026-09-12) */
        var ly = axY + 36 + lv * 20;
        o.t.setAttribute("y", ly);
        o.lead.setAttribute("y2", ly - 11);
      });
      (sc.flags || []).forEach(function (f) {
        if (f.v == null) return;
        var fx = f.off || f.v > dm[1] ? W - R : x(f.v);
        svgEl("path", { cls: "mmf-flag", d: "M" + fx + " " + (axY - 1) + "l-5 -9h10z" }, g)
          .appendChild(svgEl("title", { text: f.text }));
      });
      if (sc.axis.zero_pct != null) {
        svgEl("text", { cls: "mmf-lab", x: x(0) + 6, y: 16, style: "fill:var(--warn);font-weight:600",
                        text: sc.axis.zero_pct + " % of values are exactly 0" }, g);
      }
      H = Math.max(H, axY + 50 + maxLv * 20 + (sc.axis.type === "beaufort" ? 12 : 0));
      host.setAttribute("viewBox", "0 0 " + W + " " + H);
      host.classList.add("mmf-drawn");
      var cr = document.getElementById("mmf-scale-credit");
      if (cr) {
        cr.innerHTML = (log ? "Log scale · " : "") +
          "bars: the record’s 5th–95th percentile per series; line: minimum to maximum; ring: median" +
          /* the marks the figure actually DREW: a Beaufort band has no single value and is drawn
             as the strip above the axis, so naming all thirteen here would credit marks the
             reader cannot see */
          (drawn.length ? " · marks: " + refs.filter(function (r) { return r.v != null; })
             .map(function (r) { return esc(r.label) + (r.src ? " (" + esc(r.src) + ")" : ""); }).join("; ") : "") +
          (sc.axis.source ? " · " + esc(sc.axis.source) : "");
      }
    })();

    /* ── Why: the record's own history, one row per depth band (round 2, M10) ───────────────
       OWN SCALE PER ROW by default — the ± is written at the left of each row beside its band and
       its count, so a deep band shows its structure and the axis says how much it was stretched.
       A radio pair above the chart switches every row onto the page-wide `anomaly.ymax`; the
       choice does NOT ride the URL (it is a reading aid, not a state a link should carry). The
       four-line mono legend is now one `.cc-legend1` line; the computation and the depth note
       live in the heading's ⓘ (_includes/measurement_why.html). */
    function drawHistory(shared) {
      var host = document.getElementById("mmf-anom"), a = F.anomaly;
      if (!host || !a || !(a.bands || []).length) return;
      var W = width(host, 340), nb = a.bands.length;
      var L = Math.min(92, Math.max(76, W * 0.13)), R = Math.min(124, Math.max(88, W * 0.17));
      var T = 10, rowH = 46, gap = 10, B = 22;
      var H = T + nb * rowH + (nb - 1) * gap + B, y0 = F.y0, y1 = F.y1, ny = y1 - y0 + 1;
      var x = function (yr) { return L + (yr - y0) / ny * (W - L - R); }, bw = (W - L - R) / ny;
      host.innerHTML = "";
      host.setAttribute("viewBox", "0 0 " + W + " " + H);
      var g = svgEl("g", {}, host);
      (F.oni.strong || []).forEach(function (yr) {
        if (yr < y0 || yr > y1) return;
        svgEl("rect", { cls: "mmf-nino", x: x(yr).toFixed(1), y: T, width: bw.toFixed(1), height: H - T - B }, g);
      });
      a.bands.forEach(function (b, i) {
        var r0 = T + i * (rowH + gap);
        var top = shared ? a.ymax : bandTop(b);
        var y = function (v) { return r0 + (top - Math.max(-top, Math.min(top, v))) / (2 * top) * rowH; };
        svgEl("line", { cls: "mmf-gr", x1: L, x2: W - R, y1: r0, y2: r0 }, g);
        svgEl("line", { cls: "mmf-gr", x1: L, x2: W - R, y1: r0 + rowH, y2: r0 + rowH }, g);
        svgEl("text", { cls: "mmf-lab", x: L - 8, y: r0 + 13, "text-anchor": "end",
                        style: "font-weight:600", text: bandTxt(b.band) + " m" }, g);
        /* the row's own scale, written where the row is read */
        svgEl("text", { cls: "mmf-tick", x: L - 8, y: r0 + 27, "text-anchor": "end",
                        text: "\u00b1" + fmtN(top, tdp(top)) + units() }, g);
        svgEl("text", { cls: "mmf-tick", x: L - 8, y: r0 + 40, "text-anchor": "end", text: fmtK(b.n_values) }, g);
        b.series.forEach(function (r) {
          var v = r[1], clip = Math.abs(v) > top;
          svgEl("rect", { x: (x(r[0]) + bw * 0.12).toFixed(1), y: Math.min(y(v), y(0)).toFixed(1),
                          width: Math.max(bw * 0.76, 0.8).toFixed(1),
                          height: Math.max(Math.abs(y(v) - y(0)), 0.8).toFixed(1),
                          fill: v >= 0 ? WARM : COOL, opacity: r[2] >= 2 ? 1 : 0.35 }, g);
          if (clip) {
            svgEl("path", { d: "M" + (x(r[0]) + bw / 2) + " " + (v > 0 ? r0 - 1 : r0 + rowH + 1) +
                               "l-3 " + (v > 0 ? 5 : -5) + "h6z", fill: "var(--muted)" }, g);
          }
        });
        svgEl("line", { cls: "mmf-zero", x1: L, x2: W - R, y1: y(0), y2: y(0) }, g);
        var tr = b.trend;
        if (tr && tr.per_decade != null && tr.intercept != null) {
          var ty = function (yr) { return y(tr.intercept + (tr.per_decade / 10) * yr); };
          svgEl("line", { cls: "mmf-trend", x1: x(tr.from) + bw / 2, x2: x(tr.to) + bw / 2,
                          y1: ty(tr.from), y2: ty(tr.to) }, g);
          svgEl("text", { cls: "mmf-lab-m", x: W - R + 8, y: r0 + rowH / 2 + 4,
                          text: (tr.per_decade >= 0 ? "+" : "\u2212") +
                                fmtN(Math.abs(tr.per_decade), Math.abs(tr.per_decade) < 0.1 ? 3 : 2) + " / decade" }, g);
        }
        yearHover(g, b, { L: L, R: R, W: W, y0: y0, ny: ny, bw: bw, top: r0, bottom: r0 + rowH,
                          label: bandTxt(b.band) + " m", shared: shared, rowTop: top });
      });
      var yr;
      for (yr = Math.ceil(y0 / 10) * 10; yr <= y1; yr += 10) {
        svgEl("text", { cls: "mmf-tick", x: x(yr) + bw / 2, y: H - 6, "text-anchor": "middle", text: String(yr) }, g);
      }
      host.classList.add("mmf-drawn");
    }

    (function history() {
      var host = document.getElementById("mmf-anom"), a = F.anomaly;
      if (!host || !a || !(a.bands || []).length) return;
      var radios = [].slice.call(document.querySelectorAll('input[name="mmf-hsc"]'));
      var read = function () {
        var on = radios.filter(function (r) { return r.checked; })[0];
        return !!on && on.value === "shared";
      };
      drawHistory(read());
      radios.forEach(function (r) { r.addEventListener("change", function () { drawHistory(read()); }); });

      /* the legend: one line of swatches, and the computation sentence in the heading's ⓘ — both
         written from the payload, never typed (§ D7) */
      var leg = document.getElementById("mmf-anom-legend");
      if (leg) {
        var since = a.bands.reduce(function (m, b) {
          return b.trend && b.trend.from != null ? (m == null ? b.trend.from : Math.min(m, b.trend.from)) : m;
        }, null);
        var o = F.oni.latest;
        leg.innerHTML =
          '<span><i class="sw" style="background:' + WARM + '"></i>above the ' +
            (a.baseline ? esc(a.baseline.join("\u2013")) : "") + " normal</span>" +
          '<span><i class="sw" style="background:' + COOL + '"></i>below</span>' +
          /* `oni.latest` is [season, year, value] \u2014 the WS-MF5 credit read o[3] and printed
             "is undefined" on every page carrying an anomaly (measured 2026-09-15) */
          '<span><i class="sw mmf-sw-nino"></i>strong El Ni\u00f1o (NOAA ONI \u2265 +1.5' +
            (o && o[2] != null ? "; " + esc(o[0]) + " " + o[1] + " is " + (o[2] >= 0 ? "+" : "") + o[2] : "") +
            ")</span>" +
          (since != null ? '<span><i class="ln"></i>trend since ' + since + "</span>" : "");
      }
      var how = document.getElementById("mmf-anom-how");
      if (how) {
        var since2 = a.bands.reduce(function (m, b) {
          return b.trend && b.trend.from != null ? (m == null ? b.trend.from : Math.min(m, b.trend.from)) : m;
        }, null);
        how.innerHTML = "Each year\u2019s departure from the " + (a.baseline ? esc(a.baseline.join("\u2013")) : "") +
          " normal for the same station, month and 10 m depth, from the release\u2019s <code>climatology</code> " +
          "table; per cruise, then per year. A faded bar is one cruise that year" +
          (since2 != null ? "; the dashed line is the least-squares trend over years with two or more cruises, since " +
            since2 : "") + ". A bar off its row\u2019s scale is marked \u25b2 at the row edge.";
      }
    })();
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
