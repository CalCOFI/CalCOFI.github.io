/* the front door's drawing (_includes/front_door_hero.html): the sky, the water, the ship and Line 90's sea floor from
   the committed GEBCO profile (_data/line90_floor.json, inlined as #hero-floor). Offshore on the left, the coast on the
   right, depth exaggerated to fit the screen. With no profile the water is drawn with no floor — never a made-up one. */
(function () {
  'use strict';
  var svg = document.getElementById('hero-sea'), src = document.getElementById('hero-floor');
  if (!svg) return;
  var NS = 'http://www.w3.org/2000/svg', W = 1280, H = 720, SURF = 300, X1 = 1170;
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
  el('path', { d: 'M-42,-1 L38,-1 L31,7 L-35,7 Z' }, g); el('rect', { x: -14, y: -11, width: 22, height: 10 }, g);
  el('rect', { x: -8, y: -18, width: 11, height: 7 }, g); el('rect', { x: -2, y: -30, width: 1.6, height: 12 }, g);
  // the CTD (Betty 2026-11-20): its wire, 50 units shorter than it was so the cards do not cover it, down to a rosette, a frame
  // of water bottles. It hangs aft of the middle of the (longer) hull and is a link to #learn, like the label on the right.
  // (A manta, a bongo and the PairoVET were drawn here for a while, then taken out: the picture is fine as it was.)
  var ctd = el('a', { href: '#learn', 'class': 'hero-gear-link', 'aria-label': 'CTD: how CalCOFI samples the ocean' }, g);
  el('rect', { x: 4, y: 60, width: 36, height: 22, fill: 'transparent', stroke: 'none', 'class': 'hero-gear-hit' }, ctd);
  el('line', { x1: 20, y1: 7, x2: 20, y2: 62, 'class': 'wire', 'stroke-opacity': 0.55, 'stroke-dasharray': '2 3' }, ctd);
  el('rect', { x: 14, y: 62, width: 12, height: 15, rx: 2, 'class': 'wire', 'stroke-opacity': 0.85 }, ctd);
  [17.5, 20, 22.5].forEach(function (x) { el('line', { x1: x, y1: 65, x2: x, y2: 74, 'class': 'wire', 'stroke-opacity': 0.6, 'stroke-width': 1.4 }, ctd); });
  // the way in to Learn (#learn), beside the ship it explains (Betty, 2026-11-13: option B). Drawn in the picture so it
  // stays by the ship at every window size; the door script opens #learn on the hash
  // no aria-label: the link's name is its two lines of text, so what is read is what is seen
  var a = el('a', { href: '#learn', 'class': 'hero-tag' });
  el('rect', { x: 740, y: SURF + 22, width: 292, height: 50, rx: 8 }, a);
  var t1 = el('text', { x: 752, y: SURF + 42, 'class': 'hero-tag-t' }, a); t1.textContent = 'What is sampled, and how deep';
  var t2 = el('text', { x: 752, y: SURF + 61, 'class': 'hero-tag-s' }, a); t2.textContent = 'The ship, its nets and instruments along Line 90 \u2192';
  // fill the window (Betty, 2026-11-19): the hero's min-height is the window less where the hero starts, measured
  // here rather than assumed, so no white strip of footer shows under it on any screen (assets/hero.css --hero-top)
  var hero = svg.closest('.hero');
  if (hero) {
    // and the words and cards fit inside it (Betty, 2026-11-19): assets/hero.css picks the hero's scale (--hs, which
    // every length of the text layer is written in) for the window's size; where that still pushes the cards past
    // the window's bottom edge, the scale is brought down until they fit (never below .75), and the header's column
    // follows the same scale (--hz) so the logo stays over the words
    var head = document.querySelector('.cc-header');
    var fit = function () {
      var top = Math.round(hero.getBoundingClientRect().top + window.scrollY);
      hero.style.setProperty('--hero-top', top + 'px');
      hero.style.removeProperty('--hs');
      if (head) head.style.removeProperty('--hz');
      if (window.innerWidth < 901) return;
      var z = parseFloat(getComputedStyle(hero).getPropertyValue('--hs')) || 1, z0 = z, room = window.innerHeight - top;
      for (var n = 0; n < 6 && hero.offsetHeight > room + 1 && z > 0.75; n++) {
        z = Math.max(0.75, Math.floor(z * Math.min(0.98, room / hero.offsetHeight) * 100) / 100);
        hero.style.setProperty('--hs', z);
      }
      if (head && z !== z0) head.style.setProperty('--hz', z);
    };
    fit(); window.addEventListener('resize', fit); window.addEventListener('load', fit);
  }
})();
