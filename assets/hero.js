/* the front door's drawing (_includes/front_door_hero.html): the sky, the water, the ship and Line 90's sea floor from
   the committed GEBCO profile (_data/line90_floor.json, inlined as #hero-floor). Offshore on the left, the coast on the
   right, depth exaggerated to fit the screen. With no profile the water is drawn with no floor — never a made-up one. */
(function () {
  'use strict';
  var svg = document.getElementById('hero-sea'), src = document.getElementById('hero-floor');
  if (!svg) return;
  var NS = 'http://www.w3.org/2000/svg', W = 1280, H = 720, SURF = 352, X1 = 1170;
  function el(tag, attrs, parent) { var e = document.createElementNS(NS, tag); for (var k in attrs) e.setAttribute(k, attrs[k]); (parent || svg).appendChild(e); return e; }
  var d = null; try { d = JSON.parse(src.textContent); } catch (e) { d = null; }
  var defs = el('defs', {});
  function grad(id, stops) { var g = el('linearGradient', { id: id, x1: 0, y1: 0, x2: 0, y2: 1 }, defs); stops.forEach(function (s) { el('stop', { offset: s[0], style: 'stop-color:var(' + s[1] + ')' }, g); }); }
  grad('hero-sky', [[0, '--sky1'], [0.72, '--sky2'], [1, '--sky3']]);
  grad('hero-water', [[0, '--w1'], [0.25, '--w2'], [0.7, '--w3'], [1, '--w4']]);
  grad('hero-flr', [[0, '--f1'], [1, '--f2']]);
  el('rect', { width: W, height: SURF, fill: 'url(#hero-sky)' });
  el('rect', { y: SURF, width: W, height: H - SURF, fill: 'url(#hero-water)' });
  if (d && d.profile && d.profile.length) {
    var coast = d.coast_station, dmax = 4700, x0 = d.profile[0][0];
    var X = function (st) { return (x0 - st) / (x0 - coast) * X1; }, Y = function (z) { return SURF + z / dmax * (H - SURF - 40); };
    var pts = [], last = -9;
    d.profile.forEach(function (p) { if (p[0] < coast) return; var x = X(p[0]); if (x - last >= 1.2) { pts.push([x, Y(p[1])]); last = x; } });
    var line = pts.map(function (p, i) { return (i ? 'L' : 'M') + p[0].toFixed(1) + ',' + p[1].toFixed(1); }).join(' ');
    el('path', { d: 'M0,' + H + ' ' + line.replace(/^M/, 'L') + ' L' + X1 + ',' + (SURF - 2) + ' L1205,' + (SURF - 10) + ' L1240,' + (SURF - 18) + ' L1280,' + (SURF - 22) + ' L1280,' + H + ' Z', fill: 'url(#hero-flr)' });
    el('path', { d: line, 'class': 'ridge' });
  }
  el('line', { x1: 0, x2: X1, y1: SURF, y2: SURF, 'class': 'surf' });
  var g = el('g', { transform: 'translate(660,' + SURF + ')', 'class': 'ship' });
  el('path', { d: 'M-30,-1 L30,-1 L24,7 L-25,7 Z' }, g); el('rect', { x: -14, y: -11, width: 22, height: 10 }, g);
  el('rect', { x: -8, y: -18, width: 11, height: 7 }, g); el('rect', { x: -2, y: -30, width: 1.6, height: 12 }, g);
  el('line', { x1: 18, y1: 7, x2: 18, y2: 118, 'class': 'wire', 'stroke-opacity': 0.55, 'stroke-dasharray': '2 3' }, g);
  el('circle', { cx: 18, cy: 121, r: 3.2, 'class': 'wire', 'stroke-opacity': 0.8 }, g);
  el('line', { x1: 28, y1: 2, x2: 90, y2: 64, 'class': 'wire', 'stroke-opacity': 0.45 }, g);
  el('path', { d: 'M90,64 l16,8 l-4,-12 z', 'fill-opacity': 0.6 }, g);
  // the way in to Learn (#learn), beside the ship it explains (Betty, 2026-11-13: option B). Drawn in the picture so it
  // stays by the ship at every window size; the door script opens #learn on the hash
  // no aria-label: the link's name is its two lines of text, so what is read is what is seen
  var a = el('a', { href: '#learn', 'class': 'hero-tag' });
  el('rect', { x: 700, y: SURF + 22, width: 292, height: 50, rx: 8 }, a);
  var t1 = el('text', { x: 712, y: SURF + 42, 'class': 'hero-tag-t' }, a); t1.textContent = 'What is sampled, and how deep';
  var t2 = el('text', { x: 712, y: SURF + 61, 'class': 'hero-tag-s' }, a); t2.textContent = 'The ship, its nets and instruments along Line 90 \u2192';
})();
