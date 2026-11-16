/* assets/reach.js — the reach: where and when, measured (plan 2026-09-07 § D-3).
   Two drawings from the inline JSON `#reach` (_plugins/datasets.rb, from the release record):
     · the map — the grid cells (one per official station, beside the kept historical ones) by pattern over the coastline, the standard and extended lines as
       polylines. STATIC (Ben, 2026-09-07): the cruise sweep and its year odometer read as one
       station visited a year, so they went;
     · the years list — one cell per year in each dataset row of Find's list (the rows and their
       linked names are HTML), opacity by how much was sampled that year (√ of n_roots against the
       row's max), a hatched bar where the record carries only an asserted span, decade rules, the
       release as a rule at the right edge, and a head counting datasets with data per year.
   Every colour is a token (--cc-map-*, --accent, --muted, --cc-stone) or the dataset's own colour
   from the record (the same colour the catalog's dot and the Explorer use). Every number is the
   record's. No library, no tile server, no external asset, no animation. */
(function () {
  'use strict';

  var NS = 'http://www.w3.org/2000/svg';

  function el(tag, attrs, parent) {
    var e = document.createElementNS(NS, tag);
    for (var k in (attrs || {})) {
      if (k === 'text') e.textContent = attrs[k];
      else if (k === 'cls') e.setAttribute('class', attrs[k]);
      else e.setAttribute(k, attrs[k]);
    }
    if (parent) parent.appendChild(e);
    return e;
  }
  function fmt(n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
  var PAT = { s: 'standard', e: 'extended', h: 'historical' };

  /* ── the map: equirectangular over lon −134…−105, lat 19…49 (the land clip), 520 × 640 ──
     x = (lon + 134) / 29 · 520, y = (49 − lat) / 30 · 640 — the aspect is cos 33°, so a degree of
     longitude and of latitude draw at their true ratio at the grid's middle latitude. */
  var LON0 = -134, LON1 = -105, LAT0 = 19, LAT1 = 49, MW = 520, MH = 640;
  function px(lon) { return (lon - LON0) / (LON1 - LON0) * MW; }
  function py(lat) { return (LAT1 - lat) / (LAT1 - LAT0) * MH; }
  var PLACES = [['San Diego', -117.16, 32.72, 6, 4], ['Pt. Conception', -120.47, 34.45, -6, -6, 'end'],
                ['San Francisco', -122.42, 37.77, 6, -4], ['Cabo San Lucas', -109.9, 22.89, -6, 12, 'end'],
                ['Columbia River', -124.0, 46.25, 8, 4]];   // cartography: the reader's bearings, not data

  function buildMap(host, reach, opts) {
    opts = opts || {};
    var st = reach.stations || [], n = reach.numbers || {}, g = n.grid || {};
    // opts.frame [lon0, lon1, lat0, lat1] draws a window of the same map (the front door's Find panel
    // frames the survey's core so the map stays legible at a third of its old height); the cells
    // outside it are still in the drawing, clipped by the viewBox, and the label says so
    var f = opts.frame && opts.frame.length === 4 ? opts.frame : null, vx = 0, vy = 0, vw = MW, vh = MH;
    if (f) { vx = px(f[0]); vw = px(f[1]) - vx; vy = py(f[3]); vh = py(f[2]) - vy; }
    var inFrame = function (x, y) { return x >= vx && x <= vx + vw && y >= vy && y <= vy + vh; };
    var svg = el('svg', { viewBox: [vx, vy, vw, vh].map(function (v) { return +v.toFixed(1); }).join(' '), cls: 'map', role: 'img',
      'aria-label': 'The CalCOFI station grid: ' + (g.standard || 0) + ' standard, ' + (g.extended || 0) + ' extended and ' + (g.historical || 0) +
                    ' historical cells ' + (f ? 'off central and southern California and northern Baja California (the survey\'s core; some historical cells lie outside the frame)'
                                              : 'over the coast from the Columbia River to the tip of Baja California') });
    el('rect', { x: 0, y: 0, width: MW, height: MH, cls: 'water' }, svg);
    (reach.land || []).forEach(function (ring) {
      el('path', { d: 'M' + ring.map(function (q) { return px(q[0]).toFixed(1) + ',' + py(q[1]).toFixed(1); }).join('L') + 'Z', cls: 'land' }, svg);
    });
    // the lines: standard solid, extended dashed
    var byLine = {};
    st.forEach(function (s) { if (s.p !== 'h') (byLine[s.p + s.l] = byLine[s.p + s.l] || []).push(s); });
    Object.keys(byLine).forEach(function (k) {
      var arr = byLine[k].slice().sort(function (a, b) { return a.s - b.s; });
      if (arr.length < 2) return;   // a one-station line (93.4, 91.7, … since the 225-cell grid) is a dot, not a track
      el('polyline', { points: arr.map(function (s) { return px(s.x).toFixed(1) + ',' + py(s.y).toFixed(1); }).join(' '), cls: 'trk ' + arr[0].p }, svg);
    });
    // the stations, historical under extended under standard
    // the lines the map labels are lines of the survey pattern: two or more stations. Line 93.4 holds the one
    // SCCOOS inshore station and sorts north of 93.3, so "the northernmost standard line" read 93.4.
    function linesOf(pat) {
      var n = {};
      st.forEach(function (s) { if (s.p === pat) n[+s.l] = (n[+s.l] || 0) + 1; });
      return Object.keys(n).filter(function (l) { return n[l] > 1; }).map(Number);
    }
    var stdLines = linesOf('s').sort(function (a, b) { return b - a; });   // north (93.3) to south (76.7)
    ['h', 'e', 's'].forEach(function (pat) {
      st.filter(function (s) { return s.p === pat; }).forEach(function (s) {
        var c = el('circle', { cx: px(s.x).toFixed(1), cy: py(s.y).toFixed(1), r: pat === 's' ? 3 : pat === 'e' ? 2.6 : 2, cls: 'st ' + pat, 'data-key': s.k }, svg);
        el('title', { text: 'Line ' + s.l + ' · station ' + s.s + ' · ' + PAT[pat] }, c);
      });
    });
    // line labels at the west end of the outermost standard lines and the first extended one
    var labelLines = [];
    if (stdLines.length) labelLines.push([stdLines[0], 's'], [stdLines[stdLines.length - 1], 's']);
    var extLines = linesOf('e').sort(function (a, b) { return b - a; });
    if (extLines.length) labelLines.push([extLines[extLines.length - 1], 'e']);
    labelLines.forEach(function (q) {
      var w = st.filter(function (s) { return +s.l === q[0] && s.p === q[1]; }).sort(function (a, b) { return a.x - b.x; })[0];
      if (w) el('text', { x: px(w.x) - 4, y: py(w.y) + 3, cls: 'ln', 'text-anchor': 'end', text: 'line ' + q[0] }, svg);
    });
    PLACES.forEach(function (q) {
      if (!inFrame(px(q[1]), py(q[2]))) return;
      el('circle', { cx: px(q[1]), cy: py(q[2]), r: 1.8, cls: 'plcd' }, svg);
      el('text', { x: px(q[1]) + q[3], y: py(q[2]) + q[4], cls: 'plc', 'text-anchor': q[5] || 'start', text: q[0] }, svg);
    });
    if (opts.key !== false) {
      var ky = el('g', { cls: 'keyg' }, svg);
      [['s', 'standard · ' + (g.standard || 0), 3], ['e', 'extended · ' + (g.extended || 0), 2.6], ['h', 'historical · ' + (g.historical || 0), 2]].forEach(function (q, i) {
        var kx = vx + 14, ky0 = vy + vh - 44;   // the bottom-left corner of whatever is drawn
        el('circle', { cx: kx, cy: ky0 + i * 14, r: q[2], cls: 'st ' + q[0] }, ky);
        el('text', { x: kx + 10, y: ky0 + 3 + i * 14, cls: 'key', text: q[1] }, ky);
      });
    }
    if (opts.href) {   // a station click opens the Explorer's station view
      svg.addEventListener('click', function (ev) {
        if (ev.target.classList && ev.target.classList.contains('st')) location.href = opts.href;
      });
    }
    host.appendChild(svg);
    return svg;
  }

  /* ── the years list: the dataset rows are HTML (index.html, Liquid, from the same record) — each
     name an <a> to the dataset's page — and this draws each row's years into its .fd-ycells, plus
     the head's "datasets with data per year" bars and decade labels into .fd-yaxis. Every row's
     drawing has the same viewBox (one unit per year, Y0 … Y1) and fills its column, so the cells,
     the decade rules and the release rule line up down the list at any width. Colours as before:
     the dataset's own colour from the record, opacity by √(n_roots / the row's max); an asserted
     span is a hatched bar. (Until 2026-11-16 this was one 1000-unit SVG whose 11 px mono names
     shrank to ~8 px on the page: Ben, "too small to be legible".) */
  function spanOf(d) {
    var ymin = d.ymin, ymax = d.ymax, asserted = false;
    if ((!ymin || !ymax || !(d.years && d.years.length)) && d.temporal) {
      var m = /(\d{4}).*?(\d{4})/.exec(d.temporal);
      if (m) { ymin = +m[1]; ymax = +m[2]; asserted = true; }
    }
    return { ymin: ymin, ymax: ymax, asserted: asserted };
  }
  function rules(svg, Y0, Y1, H) {
    for (var y = Math.ceil(Y0 / 10) * 10; y <= Y1; y += 10)
      el('line', { x1: y - Y0, x2: y - Y0, y1: 0, y2: H, cls: 'dt' }, svg);
    el('line', { x1: Y1 - Y0 + 1, x2: Y1 - Y0 + 1, y1: 0, y2: H, cls: 'now' }, svg);
  }
  function buildStrip(host, reach) {
    var n = reach.numbers || {};
    var Y0 = n.since || 1949, Y1 = +String((reach.release || {}).date || '').slice(0, 4) || new Date().getFullYear();
    var N = Y1 - Y0 + 1, byKey = {}, count = [];
    for (var i = 0; i < N; i++) count.push(0);
    (reach.datasets || []).forEach(function (d) {
      var sp = spanOf(d);
      byKey[d.key] = { d: d, sp: sp };
      if (sp.asserted) { for (var yy = sp.ymin; yy <= sp.ymax; yy++) if (yy >= Y0 && yy <= Y1) count[yy - Y0]++; }
      else (d.years || []).forEach(function (q) { if (q[0] >= Y0 && q[0] <= Y1) count[q[0] - Y0]++; });
    });
    // the head: datasets with data per year, the decade labels under it (HTML, so the type is not stretched)
    var axis = host.querySelector('.fd-yaxis');
    if (axis) {
      var mx = Math.max.apply(null, count) || 1;
      var bars = el('svg', { viewBox: '0 0 ' + (N + 0.5) + ' 20', preserveAspectRatio: 'none', cls: 'fd-ybars', 'aria-hidden': 'true' });
      el('title', { text: 'Datasets with data each year, ' + Y0 + ' to ' + Y1 + ' (at most ' + mx + ')' }, bars);
      count.forEach(function (c, i) { if (c) el('rect', { x: i + 0.1, y: 20 - c / mx * 18, width: 0.8, height: c / mx * 18, cls: 'bar' }, bars); });
      axis.appendChild(bars);
      var dec = document.createElement('div');
      dec.className = 'fd-ydec';
      for (var y = Math.ceil(Y0 / 10) * 10; y <= Y1; y += 10) {
        var s = document.createElement('span');
        s.textContent = String(y);
        s.style.left = ((y - Y0) / (N + 0.5) * 100).toFixed(3) + '%';
        dec.appendChild(s);
      }
      axis.appendChild(dec);
    }
    var drawn = 0;
    [].forEach.call(host.querySelectorAll('.fd-yrow[data-key]'), function (row) {
      var it = byKey[row.getAttribute('data-key')], box = row.querySelector('.fd-ycells');
      if (!it || !box || !it.sp.ymin) return;
      var d = it.d, sp = it.sp;
      var svg = el('svg', { viewBox: '0 0 ' + (N + 0.5) + ' 10', preserveAspectRatio: 'none', cls: 'fd-ysvg', 'aria-hidden': 'true' });
      rules(svg, Y0, Y1, 10);
      if (sp.asserted) {
        var a0 = Math.max(sp.ymin, Y0), a1 = Math.min(sp.ymax, Y1);
        var bar = el('rect', { x: a0 - Y0 + 0.1, y: 2, width: a1 - a0 + 0.8, height: 6, fill: d.color, stroke: d.color, cls: 'ass' }, svg);
        el('title', { text: d.name + ' · ' + d.temporal + ' · asserted, not measured' }, bar);
      } else {
        var m = Math.max.apply(null, d.years.map(function (q) { return q[1] || 0; })) || 1;
        d.years.forEach(function (q) {
          if (q[0] < Y0 || q[0] > Y1) return;
          var c = el('rect', { x: q[0] - Y0 + 0.1, y: 2, width: 0.8, height: 6, fill: d.color,
            'fill-opacity': (0.3 + 0.7 * Math.sqrt((q[1] || 0) / m)).toFixed(2), cls: 'cell' }, svg);
          el('title', { text: d.name + ' · ' + q[0] + ' · ' + fmt(q[1] || 0) + ' casts or tows · ' + fmt(q[2] || 0) + ' observations' }, c);
        });
      }
      box.appendChild(svg);
      drawn++;
    });
    if (drawn) host.classList.add('fd-ydrawn');
    return drawn;
  }

  // ── wiring ──
  var data = document.getElementById('reach');
  if (!data) return;
  var reach;
  try { reach = JSON.parse(data.textContent); } catch (e) { return; }
  var mapHost = document.getElementById('map-host');
  if (mapHost) buildMap(mapHost, reach, { href: mapHost.getAttribute('data-href'),
    frame: (mapHost.getAttribute('data-frame') || '').split(/\s+/).filter(Boolean).map(Number),
    key: mapHost.getAttribute('data-key') !== 'off' });   // Find's small map keys its marks in the caption instead
  var stripHost = document.getElementById('strip-host');
  if (stripHost) buildStrip(stripHost, reach);
  window.ccReach = { buildMap: buildMap, buildStrip: buildStrip };
})();
