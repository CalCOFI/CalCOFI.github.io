/* assets/reach.js — the reach: where and when, measured (plan 2026-09-07 § D-3).
   Two drawings from the inline JSON `#reach` (_plugins/datasets.rb, from the release record):
     · the map — the 218 grid cells by pattern over the coastline, the standard and extended lines as
       polylines, a cruise sweep pulsing the standard stations in line order on a 12 s loop with a
       cyan ripple, and a year odometer 1949 → the release year over the same loop;
     · the years strip — one row per dataset in the release, one cell per year, opacity by how much
       was sampled that year (√ of n_roots against the row's max), a hatched bar where the record
       carries only an asserted span, decade rules, a top bar counting datasets with data per year,
       and the release version as a rule at the right edge.
   Every colour is a token (--cc-map-*, --accent, --muted, --cc-stone, --cc-cyan) or the dataset's own
   colour from the record (the same colour the catalog's dot and the Explorer use). Every number is
   the record's. No library, no tile server, no external asset; both animations stop under
   prefers-reduced-motion. */
(function () {
  'use strict';

  var NS = 'http://www.w3.org/2000/svg';
  var rm = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;

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
  /* the sweep runs the six standard lines north to south, alternating direction per line — the way a
     cruise steams the pattern — over one 12 s loop; a station's delay is its place in that order */
  var SWEEP_S = 12, LINE_S = 1.7, STATION_S = 0.07;
  var PLACES = [['San Diego', -117.16, 32.72, 6, 4], ['Pt. Conception', -120.47, 34.45, -6, -6, 'end'],
                ['San Francisco', -122.42, 37.77, 6, -4], ['Cabo San Lucas', -109.9, 22.89, -6, 12, 'end'],
                ['Columbia River', -124.0, 46.25, 8, 4]];   // cartography: the reader's bearings, not data

  function buildMap(host, reach, opts) {
    opts = opts || {};
    var st = reach.stations || [], n = reach.numbers || {}, g = n.grid || {};
    var svg = el('svg', { viewBox: '0 0 ' + MW + ' ' + MH, cls: 'map', role: 'img',
      'aria-label': 'The CalCOFI station grid: ' + (g.standard || 0) + ' standard, ' + (g.extended || 0) + ' extended and ' + (g.historical || 0) +
                    ' historical cells over the coast from the Columbia River to the tip of Baja California' });
    el('rect', { x: 0, y: 0, width: MW, height: MH, cls: 'water' }, svg);
    (reach.land || []).forEach(function (ring) {
      el('path', { d: 'M' + ring.map(function (q) { return px(q[0]).toFixed(1) + ',' + py(q[1]).toFixed(1); }).join('L') + 'Z', cls: 'land' }, svg);
    });
    // the lines: standard solid, extended dashed
    var byLine = {};
    st.forEach(function (s) { if (s.p !== 'h') (byLine[s.p + s.l] = byLine[s.p + s.l] || []).push(s); });
    Object.keys(byLine).forEach(function (k) {
      var arr = byLine[k].slice().sort(function (a, b) { return a.s - b.s; });
      el('polyline', { points: arr.map(function (s) { return px(s.x).toFixed(1) + ',' + py(s.y).toFixed(1); }).join(' '), cls: 'trk ' + arr[0].p }, svg);
    });
    // the stations, historical under extended under standard; the standard ones carry the sweep
    var stdLines = st.filter(function (s) { return s.p === 's'; }).map(function (s) { return +s.l; })
      .filter(function (v, i, a) { return a.indexOf(v) === i; }).sort(function (a, b) { return b - a; });   // north (93.3) to south (76.7)
    ['h', 'e', 's'].forEach(function (pat) {
      st.filter(function (s) { return s.p === pat; }).forEach(function (s) {
        var cx = px(s.x).toFixed(1), cy = py(s.y).toFixed(1), delay = '';
        if (pat === 's') {
          var li = stdLines.indexOf(+s.l);
          var line = st.filter(function (t) { return t.p === 's' && t.l === s.l; }).sort(function (a, b) { return a.s - b.s; });
          var rank = line.indexOf(s); if (li % 2 === 1) rank = line.length - 1 - rank;
          delay = '--d:' + (li * LINE_S + rank * STATION_S).toFixed(2) + 's';
          el('circle', { cx: cx, cy: cy, r: 3, cls: 'ring', style: delay }, svg);
        }
        var c = el('circle', { cx: cx, cy: cy, r: pat === 's' ? 3 : pat === 'e' ? 2.6 : 2, cls: 'st ' + pat, style: delay, 'data-key': s.k }, svg);
        el('title', { text: 'Line ' + s.l + ' · station ' + s.s + ' · ' + PAT[pat] }, c);
      });
    });
    // line labels at the west end of the outermost standard lines and the first extended one
    var labelLines = [];
    if (stdLines.length) labelLines.push([stdLines[0], 's'], [stdLines[stdLines.length - 1], 's']);
    var extLines = st.filter(function (s) { return s.p === 'e'; }).map(function (s) { return +s.l; }).sort(function (a, b) { return b - a; });
    if (extLines.length) labelLines.push([extLines[extLines.length - 1], 'e']);
    labelLines.forEach(function (q) {
      var w = st.filter(function (s) { return +s.l === q[0] && s.p === q[1]; }).sort(function (a, b) { return a.x - b.x; })[0];
      if (w) el('text', { x: px(w.x) - 4, y: py(w.y) + 3, cls: 'ln', 'text-anchor': 'end', text: 'line ' + q[0] }, svg);
    });
    PLACES.forEach(function (q) {
      el('circle', { cx: px(q[1]), cy: py(q[2]), r: 1.8, cls: 'plcd' }, svg);
      el('text', { x: px(q[1]) + q[3], y: py(q[2]) + q[4], cls: 'plc', 'text-anchor': q[5] || 'start', text: q[0] }, svg);
    });
    if (opts.key !== false) {
      var ky = el('g', { cls: 'keyg' }, svg);
      [['s', 'standard · ' + (g.standard || 0), 3], ['e', 'extended · ' + (g.extended || 0), 2.6], ['h', 'historical · ' + (g.historical || 0), 2]].forEach(function (q, i) {
        el('circle', { cx: 14, cy: 596 + i * 14, r: q[2], cls: 'st ' + q[0], style: 'animation:none' }, ky);
        el('text', { x: 24, y: 599 + i * 14, cls: 'key', text: q[1] }, ky);
      });
    }
    if (opts.href) {   // a station click opens the Station Explorer (cut 3 passes the cell)
      svg.addEventListener('click', function (ev) {
        if (ev.target.classList && ev.target.classList.contains('st')) location.href = opts.href;
      });
    }
    host.appendChild(svg);
    return svg;
  }

  /* ── the year odometer: 1949 → the release year over the sweep's 12 s; static under reduced motion */
  function startOdometer(node, y0, y1) {
    if (!node || !y0 || !y1) return;
    if (rm) { node.textContent = y0 + ' – ' + y1; return; }
    var span = y1 - y0 + 1, t0 = performance.now();
    (function tick(t) {
      var p = ((t - t0) / (SWEEP_S * 1000)) % 1;
      node.textContent = String(y0 + Math.floor(p * span));
      requestAnimationFrame(tick);
    })(t0);
  }

  /* ── the years strip: one row per dataset in the release × one cell per year ── */
  function buildStrip(host, reach) {
    var n = reach.numbers || {};
    var Y0 = n.since || 1949, Y1 = +String((reach.release || {}).date || '').slice(0, 4) || new Date().getFullYear();
    var N = Y1 - Y0 + 1, X0 = 250, X1 = 992, cw = (X1 - X0) / N, RH = 13, TOP = 66;   // the label column runs to X0 − 8: the longest short name in the record is 30 mono characters
    var rows = (reach.datasets || []).map(function (d) {
      var ymin = d.ymin, ymax = d.ymax, asserted = false;
      if ((!ymin || !ymax || !(d.years && d.years.length)) && d.temporal) {
        var m = /(\d{4}).*?(\d{4})/.exec(d.temporal);
        if (m) { ymin = +m[1]; ymax = +m[2]; asserted = true; }
      }
      return { key: d.key, name: d.name, url: d.url, color: d.color, temporal: d.temporal, years: d.years || [], ymin: ymin, ymax: ymax, asserted: asserted };
    }).filter(function (r) { return r.ymin; })
      .sort(function (a, b) { return (a.ymin - b.ymin) || a.name.localeCompare(b.name); });
    var H = TOP + rows.length * RH + 22;
    var svg = el('svg', { viewBox: '0 0 1000 ' + H, cls: 'strip', role: 'group',
      'aria-label': 'Which years each of the ' + rows.length + ' datasets covers, ' + Y0 + ' to ' + Y1 + '; a hatched bar is an asserted span, not a measured one' });
    var deco = el('g', { 'aria-hidden': 'true' }, svg);
    for (var y = Math.ceil(Y0 / 10) * 10; y <= Y1; y += 10) {
      var x = X0 + (y - Y0) * cw;
      el('line', { x1: x, x2: x, y1: TOP - 6, y2: TOP + rows.length * RH, cls: 'dt' }, deco);
      el('text', { x: x, y: TOP - 10, cls: 'dl', 'text-anchor': 'middle', text: String(y) }, deco);
    }
    // datasets with data, per year
    var count = []; for (var i = 0; i < N; i++) count.push(0);
    rows.forEach(function (r) {
      if (r.asserted) { for (var yy = r.ymin; yy <= r.ymax; yy++) if (yy >= Y0 && yy <= Y1) count[yy - Y0]++; }
      else r.years.forEach(function (q) { if (q[0] >= Y0 && q[0] <= Y1) count[q[0] - Y0]++; });
    });
    var mx = Math.max.apply(null, count) || 1;
    count.forEach(function (c, i) { if (c) el('rect', { x: X0 + i * cw + 0.5, y: 44 - c / mx * 36, width: cw - 1, height: c / mx * 36, cls: 'bar' }, deco); });
    el('text', { x: X0 - 8, y: 24, cls: 'sum', 'text-anchor': 'end', text: 'datasets with data' }, deco);
    el('text', { x: X0 - 8, y: 36, cls: 'sum', 'text-anchor': 'end', text: 'that year (max ' + mx + ')' }, deco);
    rows.forEach(function (r, i) {
      var y = TOP + i * RH;
      var a = el('a', { href: r.url, cls: 'rowlink' }, svg);                          // the row's name is a link to the dataset's page
      el('text', { x: X0 - 8, y: y + 10, cls: 'rl', 'text-anchor': 'end', text: r.name }, a);
      el('title', { text: r.name + ' · ' + (r.temporal || (r.ymin + ' to ' + r.ymax)) + (r.asserted ? ' · asserted, not measured' : ' · measured') }, a);
      var cells = el('g', { 'aria-hidden': 'true' }, svg);
      if (r.asserted) {
        var bar = el('rect', { x: X0 + (Math.max(r.ymin, Y0) - Y0) * cw + 0.5, y: y + 1, width: (Math.min(r.ymax, Y1) - Math.max(r.ymin, Y0) + 1) * cw - 1, height: RH - 2, fill: r.color, stroke: r.color, cls: 'ass' }, cells);
        el('title', { text: r.name + ' · ' + r.temporal + ' · asserted, not measured' }, bar);
      } else {
        var m = Math.max.apply(null, r.years.map(function (q) { return q[1] || 0; })) || 1;
        r.years.forEach(function (q) {
          if (q[0] < Y0 || q[0] > Y1) return;
          var c = el('rect', { x: X0 + (q[0] - Y0) * cw + 0.5, y: y + 1, width: cw - 1, height: RH - 2, fill: r.color,
            'fill-opacity': (0.3 + 0.7 * Math.sqrt((q[1] || 0) / m)).toFixed(2), cls: 'cell' }, cells);
          el('title', { text: r.name + ' · ' + q[0] + ' · ' + fmt(q[1] || 0) + ' casts or tows · ' + fmt(q[2] || 0) + ' observations' }, c);
        });
      }
    });
    var now = X0 + (Y1 - Y0) * cw + cw;
    el('line', { x1: now, x2: now, y1: TOP - 6, y2: TOP + rows.length * RH, cls: 'now' }, deco);
    el('text', { x: now, y: TOP + rows.length * RH + 14, cls: 'dl', 'text-anchor': 'end', text: (reach.release || {}).version || '' }, deco);
    host.appendChild(svg);
    return svg;
  }

  // ── wiring ──
  var data = document.getElementById('reach');
  if (!data) return;
  var reach;
  try { reach = JSON.parse(data.textContent); } catch (e) { return; }
  var mapHost = document.getElementById('map-host');
  if (mapHost) buildMap(mapHost, reach, { href: mapHost.getAttribute('data-href') });
  var y1 = +String((reach.release || {}).date || '').slice(0, 4);
  Array.prototype.forEach.call(document.querySelectorAll('.odo-n'), function (o) { startOdometer(o, (reach.numbers || {}).since, y1); });
  var stripHost = document.getElementById('strip-host');
  if (stripHost) buildStrip(stripHost, reach);
  window.ccReach = { buildMap: buildMap, buildStrip: buildStrip };
})();
