/* assets/section.js — the front door: CalCOFI Line 90 as an oceanographic section.
   Plan: workflows/.claude/plans/2026-09-07 CalCOFI.io landing re-cut … § D-1, D-7, D-9, Appendix A.

   West on the left, the coast on the right (the Explorer's Sections rule), in one inline
   <svg viewBox="0 0 1400 660"> built at page load: the sky, the surface, a five-stop water ramp, the
   sea floor, the ship on the surface with its gear drawn to the depth the sampling protocol takes it,
   and one pin per data category at the depth that kind of measurement lives, each a link to the
   category's method page on calcofi.org. Every colour is a --cc-sec-* token (brand/v2/theme.css), so
   the toggle repaints the drawing and nothing here listens for cc:theme.

   Where every fact comes from (§ D-9):
     · the station axis, the categories' names / realms / counts, and the sea floor are read from the
       inline JSON `#reach` that _plugins/datasets.rb builds from the release record, the release's
       own grid and the committed _data/line90_floor.json (GEBCO 2025 along Line 90 at 500 m);
     · gear depths, the standard bottle depths and the wire angle are constants of the sampling
       protocol, each with a `source:` comment naming the calcofi.org page;
     · a pin's link is the calcofi.org method page — a constant, probed by scripts/check_layout.py.
   Nothing about a dataset is typed here. No framework, no library, no external asset: the glyphs are
   <use> references into the brand sprite (same origin). */
(function () {
  'use strict';

  var NS = 'http://www.w3.org/2000/svg';
  var XL = 'http://www.w3.org/1999/xlink';

  /* ── the canvas ──────────────────────────────────────────────────────────────────────────────
     1400 × 660 drawing units: sky 0–200, the surface at y = 200, water 200–600, the axis strip
     600–660, the depth axis at x = 80. Depth is a BROKEN axis: 0–500 m linear over 250 units (the
     euphotic zone and the standard cast get the room), then 500 m to the deepest sounding compressed
     into the last 150 units, with a break glyph between the 500 and 1,000 ticks. */
  var W = 1400, SKY = 200, FLOOR_Y = 600, AX_X = 80;
  var DEEP_MAX_M = 4700;                       // the compressed range's floor; Line 90 sounds 4,657 m
  function dy(m) { return m <= 500 ? SKY + m * 0.5 : 450 + (m - 500) * 150 / (DEEP_MAX_M - 500); }
  /* station → x: 12.5 units per station unit (4 nmi), station 120 at x = 130 — offshore left */
  var ST_LEFT = 120, ST_X0 = 130, ST_PX = 12.5;
  function sx(st) { return ST_X0 + (ST_LEFT - st) * ST_PX; }

  /* ── the sampling protocol (constants, not data) ─────────────────────────────────────────────
     Each is a depth or a geometry the method page states; the drawing is only as true as these. */
  var CTD_M       = 515;   // the standard CTD/rosette cast — source: https://calcofi.org/sampling-info/methods/ctd-faq-circa-2020/
  var BOTTLE_M    = [0, 10, 20, 30, 50, 75, 100, 125, 150, 200, 250, 300, 400, 500];   // the standard bottle depths — source: https://calcofi.org/sampling-info/methods/bottle-sampling-methods/
  var BONGO_M     = 210;   // the oblique bongo tow's depth, on a wire held at 45° — source: https://calcofi.org/sampling-info/methods/zooplankton-methods/
  var PAIROVET_M  = 70;    // the PairoVET vertical tow — source: https://calcofi.org/sampling-info/methods/ichthyoplankton-methods/
  var CUFES_M     = 3;     // the CUFES intake, underway — source: https://calcofi.org/sampling-info/methods/ichthyoplankton-methods/
  var MANTA_M     = 0;     // the manta neuston net, at the surface — source: https://calcofi.org/sampling-info/methods/ichthyoplankton-methods/
  var KRILL_DAY_M = 300;   // euphausiids by day, migrating to the surface at night (drawn as a dashed arrow) — source: https://calcofi.org/sampling-info/methods/zooplankton-methods/
  var METS_URL    = 'https://calcofi.org/sampling-info/methods/underway_methods/';   // the meteorological sensors on the mast

  /* ── the pins: one per category in metadata/category.csv (the record carries name, realm,
     order and counts; `#reach` hands them over), at the depth that kind of measurement lives.
     `cat` is the category's glyph id (its record key); `glyph` the sprite symbol drawn — the one
     category drawn twice, Seabirds & Marine Mammals, gets a whale at the surface and a bird in the
     sky. `href` is the calcofi.org method page. `lead` draws a leader line to the wire. */
  var PINS = [
    { cat: 'cat-meteorology',  x: 818,  y: 84,  label: 'METS · wind, air, sea state underway', href: METS_URL },
    { cat: 'cat-physical',     x: 818,  y: 458, label: 'CTD · to ' + CTD_M + ' m', deep: true, side: 'l', href: 'https://calcofi.org/sampling-info/methods/ctd-faq-circa-2020/' },
    { cat: 'cat-productivity', x: 895,  y: 212, label: 'chlorophyll · 10 m', lead: [858, dy(10)], href: 'https://calcofi.org/sampling-info/methods/primary-production-methods/' },
    { cat: 'cat-carbonate',    x: 895,  y: 250, label: 'DIC · 100 m', lead: [858, dy(100)], href: 'https://calcofi.org/sampling-info/methods/dic-methods/' },
    { cat: 'cat-nutrients',    x: 895,  y: 288, label: 'nutrients · 150 m', lead: [858, dy(150)], href: 'https://calcofi.org/sampling-info/methods/bottle-sampling-methods/' },
    { cat: 'cat-genomics',     x: 815,  y: 300, label: 'eDNA · 20 m', lead: [858, dy(20)], side: 'l', href: 'https://calcofi.org/sampling-info/methods/ncog-methods/' },
    { cat: 'cat-zooplankton',  x: 575,  y: 262, label: 'zooplankton · 0–' + BONGO_M + ' m', href: 'https://calcofi.org/sampling-info/methods/zooplankton-methods/' },
    { cat: 'cat-krill',        x: 440,  y: 362, label: 'krill · ' + KRILL_DAY_M + ' m by day, up at night', href: 'https://calcofi.org/sampling-info/methods/zooplankton-methods/' },
    { cat: 'cat-phytoplankton', x: 300, y: 224, label: 'phytoplankton · 0–50 m', href: 'https://calcofi.org/sampling-info/methods/phytoplankton-bacterioplankton-methods/' },
    { cat: 'cat-picoplankton', x: 225,  y: 262, label: 'picoplankton & bacteria · 0–100 m', href: 'https://calcofi.org/sampling-info/methods/phytoplankton-bacterioplankton-methods/' },
    { cat: 'cat-ichthyo',      x: 1040, y: 232, label: 'fish eggs & larvae · 0–' + BONGO_M + ' m', href: 'https://calcofi.org/sampling-info/methods/ichthyoplankton-methods/' },
    { cat: 'cat-fish',         x: 370,  y: 470, label: 'mesopelagic fish · 200–1,000 m', deep: true, href: 'https://calcofi.org/data/marine-ecosystem-data/' },
    { cat: 'cat-birds-mammals', glyph: 'cat-whale', x: 1070, y: 190, label: 'marine mammals · surface', href: 'https://calcofi.org/sampling-info/methods/marine-mammal-methods/' },
    { cat: 'cat-birds-mammals', x: 1060, y: 68,  label: 'seabirds · flying bridge count', href: 'https://calcofi.org/sampling-info/methods/seabird-methods/' }
  ];

  /* the drawn fallback for the sea floor — the mockup's profile, used ONLY if _data/line90_floor.json
     is absent from #reach; the caption then says the floor is drawn, not measured */
  var FLOOR_DRAWN = [[0, 4000], [130, 3950], [330, 3800], [520, 3750], [700, 3500], [820, 2300], [880, 1100], [930, 1500], [990, 1900], [1060, 1500], [1120, 900], [1180, 480], [1220, 180], [1260, 100], [1295, 45], [1312, 0]];

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
  /* Catmull-Rom → cubic Béziers, for the drawn fallback only (the measured profile is sampled every
     500 m — 1,538 points — and is drawn as it is: smoothing it would invent terrain) */
  function smooth(pts) {
    var d = 'M' + pts[0][0] + ',' + pts[0][1];
    for (var i = 0; i < pts.length - 1; i++) {
      var p0 = pts[Math.max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(i + 2, pts.length - 1)];
      var c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
      var c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
      d += ' C' + c1[0].toFixed(1) + ',' + c1[1].toFixed(1) + ' ' + c2[0].toFixed(1) + ',' + c2[1].toFixed(1) + ' ' + p2[0] + ',' + p2[1];
    }
    return d;
  }

  /* ── the floor path ──────────────────────────────────────────────────────────────────────────
     Measured: [station, depth_m] every 500 m from station 130 to the coast (the first on-land
     sample), drawn point for point. Land is clamped to 0 m in the raster, so the headland that
     rises above the surface east of the coast is DRAWN, not measured — a low rise to 29 units above
     the surface, the same shape at any coast position. */
  function floorPath(floor) {
    var measured = floor && floor.profile && floor.profile.length > 2;
    var pts, coastX;
    if (measured) {
      pts = floor.profile.map(function (q) { return [+sx(q[0]).toFixed(1), +dy(q[1]).toFixed(1)]; });
      coastX = pts[pts.length - 1][0];
      var d = 'M0,' + pts[0][1] + ' L' + pts.map(function (p) { return p[0] + ',' + p[1]; }).join(' L');
      d += ' C' + (coastX + 6) + ',' + (SKY - 8) + ' ' + (coastX + 12) + ',' + (SKY - 18) + ' ' + (coastX + 20) + ',' + (SKY - 23);   // the headland: drawn, not measured
      d += ' L' + (coastX + 48) + ',' + (SKY - 27) + ' L' + W + ',' + (SKY - 29) + ' L' + W + ',660 L0,660 Z';
      return { d: d, coastX: coastX, measured: true };
    }
    pts = FLOOR_DRAWN.map(function (q) { return [q[0], +dy(q[1]).toFixed(1)]; });
    coastX = 1312;
    return { d: smooth(pts) + ' C1318,192 1324,182 1332,177 L1360,173 L1400,171 L1400,660 L0,660 Z', coastX: coastX, measured: false };   // drawn, not measured
  }

  /* ── the drawing ─────────────────────────────────────────────────────────────────────────── */
  function buildSection(host, reach, opts) {
    opts = opts || {};
    var sprite = opts.sprite || '/brand/v2/icons/calcofi-icons.svg';
    var byCat = {};
    (reach.categories || []).forEach(function (c) { byCat[c.icon] = c; });
    var stations = (reach.stations || [])
      .filter(function (s) { return s.p === 's' && +s.l === 90; })
      .map(function (s) { return +s.s; })
      .sort(function (a, b) { return b - a; });
    var floor = floorPath(reach.floor);

    /* role="group", not "img": an img subtree is presentational and would hide the thirteen pin
       links from assistive tech. The decorative parts are aria-hidden; the pins carry <title>s. */
    var svg = el('svg', { viewBox: '0 0 ' + W + ' 660', cls: 'sec', role: 'group',
      'aria-label': 'A cross-section of CalCOFI Line 90, west on the left: the ship on the surface, its instruments at the depths they sample, the sea floor from GEBCO, and one link per data category to its methods on calcofi.org' });
    svg.setAttribute('xmlns:xlink', XL);
    var defs = el('defs', {}, svg);
    var g1 = el('linearGradient', { id: 'sec-sky', x1: 0, y1: 0, x2: 0, y2: 1 }, defs);
    el('stop', { offset: '0', style: 'stop-color:var(--cc-sec-sky0)' }, g1);
    el('stop', { offset: '1', style: 'stop-color:var(--cc-sec-sky1)' }, g1);
    var g2 = el('linearGradient', { id: 'sec-water', x1: 0, y1: 0, x2: 0, y2: 1 }, defs);
    [['0', 'w0'], ['.18', 'w1'], ['.45', 'w2'], ['.7', 'w3'], ['1', 'w4']].forEach(function (s) {
      el('stop', { offset: s[0], style: 'stop-color:var(--cc-sec-' + s[1] + ')' }, g2);
    });

    var deco = el('g', { 'aria-hidden': 'true' }, svg);             // everything that is not a link
    el('rect', { x: 0, y: 0, width: W, height: SKY, fill: 'url(#sec-sky)' }, deco);
    el('rect', { x: 0, y: SKY, width: W, height: FLOOR_Y - SKY, fill: 'url(#sec-water)' }, deco);
    el('rect', { x: 0, y: FLOOR_Y, width: W, height: 60, cls: 'axis-ground' }, deco);
    // the faint depth grid
    [100, 200, 300, 400, 500, 1000, 2000, 3000, 4000].forEach(function (m) {
      el('line', { x1: AX_X, x2: W, y1: dy(m), y2: dy(m), cls: 'grid' }, deco);
    });
    el('circle', { cx: 1310, cy: 58, r: 22, cls: 'sun' }, deco);      // the sun; a moon in dark
    el('path', { d: floor.d, cls: 'floor' }, deco);                     // the sea floor + the headland
    el('line', { x1: 0, x2: floor.coastX + 2, y1: SKY, y2: SKY, cls: 'surf' }, deco);   // the surface

    // ── the ship (bow to the right, toward the coast), on the surface at x 680–880 — 80 units right
    // of the mockup, so the one-line lede clears the ship's bounding box at every width ──
    var ship = el('g', { cls: 'ship' }, deco);
    el('path', { d: 'M680,186 L686,214 L850,214 L880,186 Z' }, ship);               // hull
    el('rect', { x: 768, y: 158, width: 64, height: 28 }, ship);                    // bridge block
    el('rect', { x: 780, y: 140, width: 42, height: 18 }, ship);                    // wheelhouse
    el('rect', { x: 836, y: 166, width: 8, height: 20 }, ship);                     // stack
    el('line', { x1: 784, x2: 818, y1: 149, y2: 149, cls: 'win' }, ship);           // window strip
    el('line', { x1: 818, x2: 818, y1: 140, y2: 104, cls: 'wire' }, ship);          // mast
    el('line', { x1: 807, x2: 829, y1: 110, y2: 110, cls: 'wire' }, ship);          // the METS crossbar
    el('circle', { cx: 818, cy: 104, r: 3 }, ship);                                 // the dome
    el('path', { d: 'M690,186 L698,152 L710,152 L718,186', cls: 'wire' }, ship);   // stern A-frame
    el('path', { d: 'M846,186 L846,170 L858,170', cls: 'wire' }, ship);            // CTD davit
    el('circle', { cx: 801, cy: 134, r: 2.6 }, ship); el('circle', { cx: 807, cy: 134, r: 2.6 }, ship);   // the observer's binoculars
    el('line', { x1: 807, x2: 1045, y1: 133, y2: 74, cls: 'thin' }, deco);          // sight line to the bird
    el('line', { x1: 807, x2: 1055, y1: 135, y2: 192, cls: 'thin' }, deco);         // sight line to the whale

    // ── the gear, to its protocol depth ──
    el('line', { x1: 300, x2: 692, y1: dy(CUFES_M), y2: dy(CUFES_M), cls: 'cufes' }, deco);   // CUFES intake, trailing astern
    var WX = 858;                                                                             // the CTD wire's x (from the davit)
    el('line', { x1: WX, x2: WX, y1: 170, y2: dy(CTD_M), cls: 'wire' }, deco);               // the CTD wire
    BOTTLE_M.forEach(function (m) { el('circle', { cx: WX, cy: dy(m), r: 2.6, cls: 'btl' }, deco); });   // the standard depths
    var ros = el('g', { cls: 'rosette' }, deco);                                              // the rosette: a frame and three Niskins, cast on a loop
    el('rect', { x: WX - 10, y: dy(500) - 1, width: 20, height: 20, rx: 2, cls: 'ros' }, ros);
    [WX - 5, WX, WX + 5].forEach(function (x) { el('line', { x1: x, x2: x, y1: dy(500) + 2, y2: dy(500) + 16, cls: 'wire' }, ros); });
    var bx = 704 - (dy(BONGO_M) - 152);                                                       // the bongo: 45° → the run equals the rise
    el('line', { x1: 704, x2: bx, y1: 152, y2: dy(BONGO_M), cls: 'wire' }, deco);
    el('ellipse', { cx: bx - 4, cy: dy(BONGO_M), rx: 5, ry: 10, cls: 'net' }, deco);
    el('ellipse', { cx: bx + 9, cy: dy(BONGO_M), rx: 5, ry: 10, cls: 'net' }, deco);
    el('path', { d: 'M' + (bx - 4) + ',' + (dy(BONGO_M) - 10) + ' L' + (bx - 52) + ',' + (dy(BONGO_M) + 27) + ' L' + (bx - 4) + ',' + (dy(BONGO_M) + 10) +
                    ' M' + (bx + 9) + ',' + (dy(BONGO_M) - 10) + ' L' + (bx - 36) + ',' + (dy(BONGO_M) + 33) + ' L' + (bx + 9) + ',' + (dy(BONGO_M) + 10), cls: 'net' }, deco);
    el('line', { x1: 728, x2: 728, y1: 186, y2: dy(PAIROVET_M), cls: 'wire' }, deco);        // PairoVET, vertical
    el('path', { d: 'M723,' + dy(PAIROVET_M) + ' L733,' + dy(PAIROVET_M) + ' L728,' + (dy(PAIROVET_M) + 13) + ' Z', cls: 'net' }, deco);
    el('path', { d: 'M684,190 L668,197', cls: 'wire' }, deco);                                // the manta, at the surface
    el('path', { d: 'M658,' + (dy(MANTA_M) - 5) + ' h14 v4 h-14 z M658,' + (dy(MANTA_M) - 3) + ' L640,' + (dy(MANTA_M) - 1) + ' L658,' + (dy(MANTA_M) - 1) + ' Z', cls: 'net' }, deco);
    el('path', { d: 'M440,' + (dy(KRILL_DAY_M) - 6) + ' L440,212 M436,218 L440,212 L444,218 M436,' + (dy(KRILL_DAY_M) - 12) + ' L440,' + (dy(KRILL_DAY_M) - 6) + ' L444,' + (dy(KRILL_DAY_M) - 12), cls: 'thin' }, deco);   // krill: diel migration
    // the gear captions
    [[296, dy(CUFES_M) - 8, 'CUFES · ' + CUFES_M + ' m, underway', 'end'], [636, 193, 'manta · surface', 'end'],
     [736, dy(PAIROVET_M) - 6, 'PairoVET · ' + PAIROVET_M + ' m'], [bx - 18, dy(BONGO_M) + 31, 'bongo · ' + BONGO_M + ' m', 'end']].forEach(function (t) {
      el('text', { x: t[0], y: t[1], cls: 'lab', 'text-anchor': t[3] || 'start', text: t[2] }, deco);
    });

    // ── the axes ──
    var ax = el('g', { cls: 'axes' }, deco);
    el('path', { d: 'M' + AX_X + ',' + SKY + ' V456 M76,460 L84,464 M' + AX_X + ',467 V' + FLOOR_Y, cls: 'axl' }, ax);   // the broken depth axis
    [0, 100, 200, 300, 400, 500, 1000, 2000, 3000, 4000].forEach(function (m) {
      el('line', { x1: AX_X - 4, x2: AX_X, y1: dy(m), y2: dy(m), cls: 'axl' }, ax);
      el('text', { x: AX_X - 8, y: dy(m) + 4, cls: 'ax', 'text-anchor': 'end', text: fmt(m) }, ax);
    });
    el('text', { x: 22, y: 400, cls: 'axt', transform: 'rotate(-90 22 400)', 'text-anchor': 'middle', text: 'depth (m)' }, ax);
    el('line', { x1: AX_X, x2: floor.coastX + 2, y1: FLOOR_Y, y2: FLOOR_Y, cls: 'axl' }, ax);
    stations.forEach(function (st) {                                                // the station axis, from the record's line-90 standard cells
      el('line', { x1: sx(st), x2: sx(st), y1: FLOOR_Y, y2: FLOOR_Y + 6, cls: 'axl' }, ax);
      el('text', { x: sx(st), y: FLOOR_Y + 22, cls: 'ax', 'text-anchor': 'middle', text: String(st) }, ax);
    });
    el('text', { x: ST_X0, y: 646, cls: 'axt', text: '← offshore' }, ax);
    el('text', { x: 700, y: 646, cls: 'axt', 'text-anchor': 'middle',
      text: 'Line 90 · station · 4 nmi per unit · sea floor ' + (floor.measured ? 'GEBCO 2025 at 500 m' : 'drawn, not measured') }, ax);
    el('text', { x: 1280, y: 646, cls: 'axt', 'text-anchor': 'end', text: 'coast →' }, ax);

    // ── the pins: real links, one per category, counts from the record ──
    var pins = el('g', { cls: 'pins' }, svg);
    PINS.forEach(function (p) {
      var c = byCat[p.cat] || { name: p.cat, n: 0, held: 0, contrib: 0 };
      var held = !c.n && !c.contrib;                                                // nothing in the release, from any dataset: drawn dashed (a holding)
      var title = c.name + ' — ' + (c.n ? c.n + ' dataset' + (c.n > 1 ? 's' : '') + ' in the release' : 'not yet in the release') +
                  (c.held ? ', ' + c.held + ' held' : '') + (c.contrib ? ', ' + c.contrib + ' contributing' : '') + ' · methods on calcofi.org';
      var a = el('a', { href: p.href, cls: 'pin' + (held ? ' held' : ''), 'data-cat': p.cat }, pins);
      a.setAttributeNS(XL, 'xlink:href', p.href);
      el('title', { text: title }, a);
      if (p.lead) el('line', { x1: p.lead[0], y1: p.lead[1], x2: p.x, y2: p.y, cls: 'lead' }, a);
      el('circle', { cx: p.x, cy: p.y, r: 15 }, a);
      var use = el('use', { x: p.x - 9, y: p.y - 9, width: 18, height: 18 }, a);
      use.setAttribute('href', sprite + '#' + (p.glyph || p.cat));
      use.setAttributeNS(XL, 'xlink:href', sprite + '#' + (p.glyph || p.cat));
      el('text', { x: p.side === 'l' ? p.x - 21 : p.x + 21, y: p.y + 4.5, 'text-anchor': p.side === 'l' ? 'end' : 'start',
        cls: 'lab' + (p.deep ? ' lab-d' : ''), text: p.label + (held ? ' · a holding' : '') }, a);
    });

    host.appendChild(svg);
    return svg;
  }

  // ── wiring ──
  var host = document.getElementById('sec-host');
  var data = document.getElementById('reach');
  if (!host || !data) return;
  var reach;
  try { reach = JSON.parse(data.textContent); } catch (e) { return; }
  buildSection(host, reach, { sprite: host.getAttribute('data-sprite') });
  window.ccSection = { build: buildSection, dy: dy, sx: sx };
})();
