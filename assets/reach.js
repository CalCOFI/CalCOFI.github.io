/* assets/reach.js — the reach: where and when, measured (plan 2026-09-07 § D-3).
   Two drawings from the inline JSON `#reach` (_plugins/datasets.rb, from the release record):
     · the map — the 218 grid cells by pattern over the coastline, the standard and extended lines as
       polylines. STATIC (Ben, 2026-09-07): the cruise sweep and its year odometer read as one
       station visited a year, so they went;
     · the years strip — one row per dataset in the release, one cell per year, opacity by how much
       was sampled that year (√ of n_roots against the row's max), a hatched bar where the record
       carries only an asserted span, decade rules, a top bar counting datasets with data per year,
       and the release version as a rule at the right edge.
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
    // the stations, historical under extended under standard
    var stdLines = st.filter(function (s) { return s.p === 's'; }).map(function (s) { return +s.l; })
      .filter(function (v, i, a) { return a.indexOf(v) === i; }).sort(function (a, b) { return b - a; });   // north (93.3) to south (76.7)
    ['h', 'e', 's'].forEach(function (pat) {
      st.filter(function (s) { return s.p === pat; }).forEach(function (s) {
        var c = el('circle', { cx: px(s.x).toFixed(1), cy: py(s.y).toFixed(1), r: pat === 's' ? 3 : pat === 'e' ? 2.6 : 2, cls: 'st ' + pat, 'data-key': s.k }, svg);
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
        el('circle', { cx: 14, cy: 596 + i * 14, r: q[2], cls: 'st ' + q[0] }, ky);
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

  /* ── the years strip: one row per dataset in the release × one cell per year ──
     The rows are grouped by the dataset's HOME realm — Biology first, then Environment (2026-09-08) —
     and inside a group they run by start year, earliest at the top, so the strip reads as two
     staircases. Each row carries its category's brand glyph, right-aligned against the year field,
     the same icon the catalog's category tile wears. */
  var STRIP_REALMS = [{ id: 'bio', title: 'Biology', icon: 'realm-bio' },
                      { id: 'env', title: 'Environment', icon: 'realm-env' }];
  function buildStrip(host, reach, opts) {
    opts = opts || {};
    var sprite = opts.sprite || '/brand/v2/icons/calcofi-icons.svg';
    var n = reach.numbers || {};
    var Y0 = n.since || 1949, Y1 = +String((reach.release || {}).date || '').slice(0, 4) || new Date().getFullYear();
    var N = Y1 - Y0 + 1, X0 = 250, X1 = 992, cw = (X1 - X0) / N, RH = 13, TOP = 66;   // the label column runs to X0 − 26: the longest short name in the record is 30 mono characters
    var IW = 11, IX = X0 - 8 - IW, LX = IX - 6, GH = 16;   // the glyph column, the label's right edge, a group heading's height
    var rows = (reach.datasets || []).map(function (d) {
      var ymin = d.ymin, ymax = d.ymax, asserted = false;
      if ((!ymin || !ymax || !(d.years && d.years.length)) && d.temporal) {
        var m = /(\d{4}).*?(\d{4})/.exec(d.temporal);
        if (m) { ymin = +m[1]; ymax = +m[2]; asserted = true; }
      }
      return { key: d.key, name: d.name, url: d.url, color: d.color, temporal: d.temporal, years: d.years || [],
               ymin: ymin, ymax: ymax, asserted: asserted,
               cat: d.cat || 'cat-other', cat_name: d.cat_name, realm: d.realm || 'env' };
    }).filter(function (r) { return r.ymin; });
    // Biology then Environment; inside each, earliest start year first (ties by name)
    var groups = [];
    STRIP_REALMS.forEach(function (g) {
      var gr = rows.filter(function (r) { return r.realm === g.id; })
        .sort(function (a, b) { return (a.ymin - b.ymin) || a.name.localeCompare(b.name); });
      if (gr.length) groups.push({ g: g, rows: gr });
    });
    // a realm the record does not name still draws, under no heading, rather than vanishing
    var known = STRIP_REALMS.map(function (g) { return g.id; });
    var rest = rows.filter(function (r) { return known.indexOf(r.realm) < 0; })
      .sort(function (a, b) { return (a.ymin - b.ymin) || a.name.localeCompare(b.name); });
    if (rest.length) groups.push({ g: null, rows: rest });
    var BOT = TOP + rows.length * RH + groups.filter(function (q) { return q.g; }).length * GH;
    var H = BOT + 22;
    var svg = el('svg', { viewBox: '0 0 1000 ' + H, cls: 'strip', role: 'group',
      'aria-label': 'Which years each of the ' + rows.length + ' datasets covers, ' + Y0 + ' to ' + Y1 +
                    ', grouped as biology then environment; a hatched bar is an asserted span, not a measured one' });
    var deco = el('g', { 'aria-hidden': 'true' }, svg);
    for (var y = Math.ceil(Y0 / 10) * 10; y <= Y1; y += 10) {
      var x = X0 + (y - Y0) * cw;
      el('line', { x1: x, x2: x, y1: TOP - 6, y2: BOT, cls: 'dt' }, deco);
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
    el('text', { x: LX, y: 24, cls: 'sum', 'text-anchor': 'end', text: 'datasets with data' }, deco);
    el('text', { x: LX, y: 36, cls: 'sum', 'text-anchor': 'end', text: 'that year (max ' + mx + ')' }, deco);
    // a glyph from the brand sprite, drawn 11 units square in the column left of the year field
    function glyph(id, x, y, parent, cls) {
      var g = el('svg', { x: x, y: y, width: IW, height: IW, viewBox: '0 0 24 24', cls: cls || 'gi',
        'aria-hidden': 'true', overflow: 'visible' }, parent);
      var use = el('use', {}, g);
      use.setAttribute('href', sprite + '#' + id);
      use.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', sprite + '#' + id);
      return g;
    }
    var cy = TOP;
    groups.forEach(function (grp) {
      if (grp.g) {
        var gh = el('g', { cls: 'gh' }, svg);
        el('text', { x: LX, y: cy + 10, cls: 'gl', 'text-anchor': 'end', text: grp.g.title.toUpperCase() }, gh);
        glyph(grp.g.icon, IX, cy + 1, gh, 'gi gr');
        el('line', { x1: X0, x2: X1, y1: cy + GH - 4, y2: cy + GH - 4, cls: 'gsep' }, gh);
        cy += GH;
      }
      grp.rows.forEach(function (r) { drawRow(r, cy); cy += RH; });
    });
    function drawRow(r, y) {
      var a = el('a', { href: r.url, cls: 'rowlink' }, svg);                          // the row's name is a link to the dataset's page
      el('text', { x: LX, y: y + 10, cls: 'rl', 'text-anchor': 'end', text: r.name }, a);
      glyph(r.cat, IX, y + 1, a, 'gi');
      el('title', { text: r.name + ' · ' + (r.cat_name ? r.cat_name + ' · ' : '') + (r.temporal || (r.ymin + ' to ' + r.ymax)) + (r.asserted ? ' · asserted, not measured' : ' · measured') }, a);
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
    }
    var now = X0 + (Y1 - Y0) * cw + cw;
    el('line', { x1: now, x2: now, y1: TOP - 6, y2: BOT, cls: 'now' }, deco);
    el('text', { x: now, y: BOT + 14, cls: 'dl', 'text-anchor': 'end', text: (reach.release || {}).version || '' }, deco);
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
  var stripHost = document.getElementById('strip-host');
  if (stripHost) buildStrip(stripHost, reach, { sprite: stripHost.getAttribute('data-sprite') });
  window.ccReach = { buildMap: buildMap, buildStrip: buildStrip };
})();
