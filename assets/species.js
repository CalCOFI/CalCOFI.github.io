/* assets/species.js — the species catalog's four drawings, from the inline JSON and nothing else.

   On /species/ (`#sp-data`, built by _plugins/species.rb from the release's taxa.json):
     · the TREE — the display forest: the kingdoms at the top (the WoRMS and the ITIS Animalia are
       one node, as are Chordata, Vertebrata and Gnathostomata), the 14 dataset-local classes under
       one node, lazy children, fold buttons, keyboard navigation, and a search over scientific,
       common and dataset names that expands and highlights every hit (`?q=` in the URL);
     · the MATRIX — class x dataset, the cell the number of taxa observed, ONE sequential tint of
       --accent by √, the count inside, the text switching to --on-accent past mid-tint;
     · the ICICLE — kingdom → phylum → class → order → family, sized by observations or species,
       click to zoom, a breadcrumb to climb out.
   On /species/{slug}/ (`#sp-strip-data`): the YEARS STRIP — one row per dataset, one cell per
   year, opacity by √(n / the row's max), in the dataset's own colour with its NAME in the row
   label. On both: the .sp-url lines are elided from the MIDDLE so the tail (the taxon the tool
   opens on) survives a phone.

   Every colour is a brand v2 token or the record's own dataset colour, which is never the only cue
   — a dot always has its dataset's name beside it and the matrix is one ramp. No library, no
   network, nothing animated but the icicle's zoom, which snaps. Ported from the mockup
   species_catalog_mockup.html (2026-09-09). */
(function () {
  'use strict';

  var NS = 'http://www.w3.org/2000/svg';

  function fmt(n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
  function fmtK(n) {
    if (n >= 1e6) return (n / 1e6).toFixed(1) + ' M';
    if (n >= 1e4) return fmt(Math.round(n / 1e3)) + ' k';
    return fmt(n);
  }
  function svgEl(tag, attrs, parent) {
    var e = document.createElementNS(NS, tag), k;
    for (k in (attrs || {})) {
      if (k === 'text') e.textContent = attrs[k];
      else if (k === 'cls') e.setAttribute('class', attrs[k]);
      else e.setAttribute(k, attrs[k]);
    }
    if (parent) parent.appendChild(e);
    return e;
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  /* the record's slug rule, applied here rather than carried 2,403 times: the key with its ":"
     written "-" (the reverse split is on the last dash before the trailing digits) */
  function slugOf(k) { return k.replace(':', '-'); }
  function tint(pct) { return 'color-mix(in srgb, var(--accent) ' + pct + '%, var(--bg))'; }

  /* ── URLs: one full-width mono line, elided from the middle ─────────────────────────────── */
  function elide() {
    var urls = document.querySelectorAll('.sp-url'), i;
    for (i = 0; i < urls.length; i++) {
      var a = urls[i];
      var full = a.getAttribute('data-full');
      if (full === null) { full = a.textContent; a.setAttribute('data-full', full); }
      a.textContent = full;
      if (a.scrollWidth <= a.clientWidth) continue;
      var n = full.length;
      while (a.scrollWidth > a.clientWidth && n > 12) {
        n -= 2;
        var h = Math.floor(n / 2);
        a.textContent = full.slice(0, h) + '…' + full.slice(full.length - (n - h));
      }
    }
  }
  elide();
  addEventListener('resize', elide);

  /* ── the years strip on a species page ──────────────────────────────────────────────────── */
  var stripHost = document.getElementById('sp-strip');
  var stripSrc = document.getElementById('sp-strip-data');
  if (stripHost && stripSrc) {
    var S = JSON.parse(stripSrc.textContent);
    var drawStrip = function () {
      var years = [], y;
      for (y = S.y0; y <= S.y1; y++) years.push(y);
      var lw = 140, W = Math.max(420, stripHost.clientWidth || 560);
      var cw = (W - lw) / years.length, rh = 22, H = S.rows.length * rh + 22;
      stripHost.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
      stripHost.classList.add('sp-drawn');   /* the CSS hides it until there is something in it */
      stripHost.innerHTML = '';
      years.forEach(function (yy, i) {
        if (yy % 10) return;
        svgEl('text', { x: lw + i * cw + 1, y: H - 6, text: yy }, stripHost);
      });
      S.rows.forEach(function (r, j) {
        var vals = Object.keys(r.y).map(function (k) { return r.y[k]; });
        var max = Math.max.apply(null, vals.concat([1]));
        /* the dataset's NAME in the row label: the colour is a second cue, never the only one */
        svgEl('text', { x: 0, y: j * rh + 15, text: r.s.replace(/ \(.*\)$/, ''),
                        style: 'fill:var(--fg);font-family:var(--sans);font-size:12px' }, stripHost);
        years.forEach(function (yy, i) {
          var n = r.y[yy] || 0;
          if (!n) return;
          var rect = svgEl('rect', { x: lw + i * cw, y: j * rh + 3, width: Math.max(cw - 1, 0.6),
                                     height: rh - 6, rx: 1.5, fill: r.c || 'var(--accent)',
                                     opacity: (0.18 + 0.82 * Math.sqrt(n / max)).toFixed(2) }, stripHost);
          svgEl('title', { text: r.s + ' · ' + yy + ' · ' + fmt(n) + ' observations' }, rect);
        });
      });
    };
    drawStrip();
    addEventListener('resize', drawStrip);
  }

  /* ── the index ──────────────────────────────────────────────────────────────────────────── */
  var src = document.getElementById('sp-data');
  if (!src) return;
  var D = JSON.parse(src.textContent);
  var DS = D.ds, BASE = D.base;
  var tt = document.getElementById('sp-ttip');

  /* nodes, children, and the rollup every count on the tree is read from */
  var N = {}, C = {}, R = {};
  D.nodes.forEach(function (n) { N[n.k] = n; C[n.k] = C[n.k] || []; });
  D.nodes.forEach(function (n) { if (n.p) (C[n.p] = C[n.p] || []).push(n.k); });
  var depth = function (k) { var d = 0, p = N[k].p; while (p && N[p]) { d++; p = N[p].p; } return d; };
  Object.keys(N).map(function (k) { return [depth(k), k]; })
        .sort(function (a, b) { return b[0] - a[0]; })
        .forEach(function (x) {
          var k = x[1], n = N[k], r = { o: n.o || 0, t: n.o > 0 ? 1 : 0, sp: (n.r === 'Species' && n.o > 0) ? 1 : 0, d: {} };
          (n.d || []).forEach(function (p) { r.d[p[0]] = (r.d[p[0]] || 0) + p[1]; });
          (C[k] || []).forEach(function (c) {
            var rc = R[c]; r.o += rc.o; r.t += rc.t; r.sp += rc.sp;
            for (var i in rc.d) r.d[i] = (r.d[i] || 0) + rc.d[i];
          });
          R[k] = r;
        });
  Object.keys(C).forEach(function (k) {
    C[k].sort(function (x, y) { return R[y].o - R[x].o || String(N[x].n || N[x].l || '').localeCompare(String(N[y].n || N[y].l || '')); });
  });
  /* the kingdoms first, most observed first; the dataset-local classes last, as the record's
     own root order has them */
  var roots = D.nodes.filter(function (n) { return !n.p; }).map(function (n) { return n.k; })
                     .sort(function (a, b) {
                       var la = a.charAt(0) === '_' ? 1 : 0, lb = b.charAt(0) === '_' ? 1 : 0;
                       return la - lb || R[b].o - R[a].o;
                     });
  var dsOf = function (k) {
    return Object.keys(R[k].d).map(Number).sort(function (a, b) { return R[k].d[b] - R[k].d[a]; });
  };
  var nameOf = function (n) { return n.n || n.l || n.k.replace(/^[^:]+:/, ''); };

  var RK = { Superdomain: 'BIO', Domain: 'D', Kingdom: 'K', Subkingdom: 'sK', Infrakingdom: 'iK',
    Phylum: 'P', 'Phylum (Division)': 'P', Subphylum: 'sP', 'Subphylum (Subdivision)': 'sP',
    Infraphylum: 'iP', Parvphylum: 'pP', Gigaclass: 'gC', Megaclass: 'mC', Superclass: 'SC',
    Class: 'C', Subclass: 'sC', Infraclass: 'iC', Subterclass: 'stC', Superorder: 'SO', Order: 'O',
    Suborder: 'sO', Infraorder: 'iO', Section: 'sec', Subsection: 'ssec', Superfamily: 'SF',
    Family: 'F', Subfamily: 'sF', Tribe: 'T', Genus: 'G', Species: 'sp', Subspecies: 'ssp',
    Forma: 'f', Variety: 'var' };
  var RANKS = ['Kingdom', 'Phylum', 'Class', 'Order', 'Family', 'Genus', 'Species'];
  var rankLevel = function (r) {
    if (!r) return 99;
    for (var i = 0; i < RANKS.length; i++) if (r.indexOf(RANKS[i]) === 0) return i;
    return 99;
  };
  var ITALIC = { Genus: 1, Species: 1, Subspecies: 1, Variety: 1, Forma: 1 };

  /* ── which ranks the tree shows: the major ranks by default, every rank on request ──────────
     A WoRMS lineage carries Subphylum · Infraphylum · Parvphylum · Gigaclass · Superclass ·
     Subclass … between the ranks people name, so a species sat twelve indents deep with no room
     for its name (Ben, 2026-09-09). A node of a minor rank is folded out of the DISPLAY unless
     something was observed at it (a suborder or subfamily identification is a real taxon with
     data); its shown descendants attach to the nearest shown ancestor. Counts are untouched —
     every rollup is over the full tree. `?ranks=all` (and the "all ranks" button) shows everything. */
  var MAJOR = { Kingdom: 1, Phylum: 1, 'Phylum (Division)': 1, Class: 1, Order: 1, Family: 1, Genus: 1,
                Species: 1, Subspecies: 1, Variety: 1, Forma: 1 };
  var allRanks = new URLSearchParams(location.search).get('ranks') === 'all';
  function shown(k) { var n = N[k]; return allRanks || !n.r || MAJOR[n.r] === 1 || (n.o || 0) > 0; }
  var CD = {};
  function kidsOf(k) {
    if (allRanks) return C[k] || [];
    if (CD[k]) return CD[k];
    var out = [];
    (C[k] || []).forEach(function (c) { if (shown(c)) out.push(c); else out = out.concat(kidsOf(c)); });
    out.sort(function (x, y) { return R[y].o - R[x].o || String(N[x].n || N[x].l || '').localeCompare(String(N[y].n || N[y].l || '')); });
    CD[k] = out;
    return out;
  }

  /* ── the tooltip ─────────────────────────────────────────────────────────────────────────── */
  function place(e) {
    var host = tt.parentElement.getBoundingClientRect();
    tt.style.display = 'block';
    tt.setAttribute('aria-hidden', 'false');
    var x = e.clientX - host.left + 14, y = e.clientY - host.top + 14;
    if (x + 310 > host.width) x = Math.max(4, e.clientX - host.left - 310);
    tt.style.left = x + 'px';
    tt.style.top = y + 'px';
  }
  function hideTip() { tt.style.display = 'none'; tt.setAttribute('aria-hidden', 'true'); }
  function dsLine(idx, counts) {
    return idx.map(function (i) {
      return '<i class="sp-dot" style="background:' + esc(DS[i].c) + '"></i> ' + esc(DS[i].s) +
             (counts ? ' ' + fmtK(counts[i]) : '');
    }).join(' · ');
  }

  /* ── the tree ────────────────────────────────────────────────────────────────────────────── */
  var tree = document.getElementById('sp-tree');
  var qn = document.getElementById('sp-qn');

  function dots(k, max) {
    max = max || 4;
    var ds = dsOf(k);
    return ds.slice(0, max).map(function (i) {
      return '<i class="sp-dot" style="background:' + esc(DS[i].c) + '" title="' + esc(DS[i].s) + '"></i>';
    }).join('') + (ds.length > max ? '<i class="sp-ct">+' + (ds.length - max) + '</i>' : '');
  }

  function rowEl(k) {
    var n = N[k], r = R[k], kids = kidsOf(k), it = ITALIC[n.r];
    var li = document.createElement('li');
    li.dataset.k = k;
    li.setAttribute('role', 'treeitem');
    if (kids.length) li.setAttribute('aria-expanded', 'false');
    var label = nameOf(n);
    var sub = (r.sp ? fmt(r.sp) + ' sp · ' : '') + fmtK(r.o) + ' obs';
    /* the synthetic "Dataset-local classes" node is a display node, not a taxon: no page */
    var href = k.charAt(0) === '_' ? null : BASE + slugOf(k) + '/';
    li.innerHTML =
      '<div class="sp-tr">' +
      '<button class="sp-tw" type="button" tabindex="-1" aria-label="Expand ' + esc(label) + '"' + (kids.length ? '' : ' disabled') + '>' + (kids.length ? '▸' : '·') + '</button>' +
      '<span class="sp-rk' + (n.r === 'Species' ? ' sp-rk-s' : '') + '" title="' + esc(n.r || 'dataset-local class') + '">' + esc(n.r ? (RK[n.r] || n.r.slice(0, 3)) : (k.charAt(0) === '_' ? '—' : 'loc')) + '</span>' +
      (href ? '<a class="sp-nm' + (it ? ' sp-it' : '') + '" href="' + href + '" title="' + esc(label) + (n.c ? ' — ' + esc(n.c) : '') + '">' + esc(label) + (n.c ? '<small>' + esc(n.c) + '</small>' : '') + '</a>'
            : '<span class="sp-nm sp-nm-plain">' + esc(label) + (n.c ? '<small>' + esc(n.c) + '</small>' : '') + '</span>') +
      '<span class="sp-ct">' + (k.charAt(0) === '_' ? '' : sub) + '</span>' +
      '<span class="sp-dots">' + dots(k) + '</span>' +
      '</div>';
    var tw = li.querySelector('.sp-tw');
    tw.addEventListener('click', function () { toggle(li); });
    var tr = li.querySelector('.sp-tr');
    tr.addEventListener('mousemove', function (e) { tip(e, k); });
    tr.addEventListener('mouseleave', hideTip);
    return li;
  }

  function expand(li) {
    var ul = li.querySelector(':scope > ul');
    if (ul) ul.hidden = false;
    else {
      ul = document.createElement('ul');
      ul.setAttribute('role', 'group');
      kidsOf(li.dataset.k).forEach(function (c) { ul.appendChild(rowEl(c)); });
      li.appendChild(ul);
    }
    li.setAttribute('aria-expanded', 'true');
    var tw = li.querySelector(':scope > .sp-tr > .sp-tw');
    tw.setAttribute('aria-expanded', 'true');
    tw.setAttribute('aria-label', 'Collapse ' + nameOf(N[li.dataset.k]));
  }
  function collapse(li) {
    var ul = li.querySelector(':scope > ul');
    if (ul) ul.hidden = true;
    if (!li.hasAttribute('aria-expanded')) return;
    li.setAttribute('aria-expanded', 'false');
    var tw = li.querySelector(':scope > .sp-tr > .sp-tw');
    tw.setAttribute('aria-expanded', 'false');
    tw.setAttribute('aria-label', 'Expand ' + nameOf(N[li.dataset.k]));
  }
  function toggle(li) { li.getAttribute('aria-expanded') === 'true' ? collapse(li) : expand(li); }

  var rootUl = document.createElement('ul');
  rootUl.setAttribute('role', 'group');
  roots.forEach(function (k) { rootUl.appendChild(rowEl(k)); });
  tree.appendChild(rootUl);

  function foldTo(rank) {
    var lvl = rankLevel(rank);
    var walk = function (li) {
      var k = li.dataset.k, myLvl = rankLevel(N[k].r);
      if (myLvl < lvl && kidsOf(k).length) {
        expand(li);
        li.querySelectorAll(':scope > ul > li').forEach(walk);
      } else collapse(li);
    };
    tree.querySelectorAll(':scope > ul > li').forEach(walk);
  }
  foldTo('Phylum');

  document.querySelectorAll('.sp-rankf button[data-fold]').forEach(function (b) {
    b.addEventListener('click', function () {
      document.querySelectorAll('.sp-rankf button[data-fold]').forEach(function (x) { x.setAttribute('aria-pressed', String(x === b)); });
      q.value = '';
      writeQ('');
      clearHits();
      foldTo(b.dataset.fold);
    });
  });

  function tip(e, k) {
    var n = N[k], r = R[k], ds = dsOf(k);
    tt.innerHTML = '<b>' + esc(nameOf(n)) + (n.c ? ' · ' + esc(n.c) : '') + '</b>' +
      '<span class="sp-d">' + esc(n.r || 'dataset-local class') + ' · ' + fmt(r.o) + ' observations' +
      (r.sp ? ' · ' + fmt(r.sp) + ' species' : '') + (r.t > 1 ? ' · ' + fmt(r.t) + ' taxa' : '') +
      (n.m ? ' · one node for ' + n.m + ' authority keys' : '') + '</span>' +
      (ds.length ? '<span class="sp-d">' + dsLine(ds, r.d) + '</span>' : '');
    place(e);
  }

  /* ── search: scientific, common and dataset names; the ancestors of every hit open ────────── */
  var q = document.getElementById('sp-q');
  var IDX = D.nodes.map(function (n) {
    return { k: n.k, s: [n.n, n.c, n.l].concat(dsOf(n.k).map(function (i) { return DS[i].s + ' ' + DS[i].k; }))
                       .filter(Boolean).join(' ').toLowerCase() };
  });
  function clearHits() {
    tree.querySelectorAll('.sp-tr.sp-hit').forEach(function (el) { el.classList.remove('sp-hit'); });
    qn.textContent = fmt(D.counts.tree) + ' in the tree';
  }
  /* the ancestors the tree SHOWS — a folded minor rank is not a row to open */
  function ancestorsOf(k) { var a = [], p = N[k].p; while (p) { if (shown(p)) a.unshift(p); p = N[p].p; } return a; }
  function reveal(k) {
    var ul = rootUl, chain = ancestorsOf(k).concat([k]), i, li;
    for (i = 0; i < chain.length; i++) {
      li = null;
      for (var j = 0; j < ul.children.length; j++) if (ul.children[j].dataset.k === chain[i]) li = ul.children[j];
      if (!li) return null;
      if (i < chain.length - 1) { expand(li); ul = li.querySelector(':scope > ul'); }
      else return li;
    }
    return null;
  }
  function runSearch(s, scroll) {
    clearHits();
    s = (s || '').trim().toLowerCase();
    if (s.length < 2) return;
    var found = IDX.filter(function (x) { return x.s.indexOf(s) >= 0; }).map(function (x) { return x.k; });
    var hits = found.filter(shown).sort(function (a, b) { return R[b].o - R[a].o; }).slice(0, 250);
    var folded = found.length - found.filter(shown).length;
    tree.querySelectorAll(':scope > ul > li').forEach(collapse);
    var first = null;
    hits.forEach(function (k) {
      var li = reveal(k);
      if (!li) return;
      li.querySelector(':scope > .sp-tr').classList.add('sp-hit');
      if (!first) first = li;
    });
    qn.textContent = fmt(hits.length) + (hits.length === 250 ? '+ matches' : ' match' + (hits.length === 1 ? '' : 'es')) +
                     (folded ? ' · ' + fmt(folded) + ' at intermediate ranks (all ranks)' : '');
    /* the tree the hits are in must be showing (the matrix may have been expanded over it) */
    if (hits.length && two && two.getAttribute('data-panes') === 'matrix') setPanes('both');
    if (first && scroll !== false) first.scrollIntoView({ block: 'center', behavior: 'instant' });
  }
  function writeQ(s) {
    if (!history.replaceState) return;
    var u = new URL(location.href);
    if (s) u.searchParams.set('q', s); else u.searchParams.delete('q');
    history.replaceState(null, '', u.toString());
  }
  clearHits();
  q.addEventListener('input', function () { runSearch(q.value); writeQ(q.value.trim()); });

  /* the "all ranks" switch rebuilds the tree in the other display, keeping the fold and the search */
  function rebuildTree() {
    CD = {};
    rootUl.innerHTML = '';
    roots.forEach(function (k) { rootUl.appendChild(rowEl(k)); });
    var f = document.querySelector('.sp-rankf button[data-fold][aria-pressed="true"]');
    foldTo(f ? f.dataset.fold : 'Phylum');
    if (q.value.trim()) runSearch(q.value, false); else clearHits();
  }
  var rankAll = document.querySelector('.sp-rankf button[data-ranks="all"]');
  if (rankAll) {
    rankAll.setAttribute('aria-pressed', String(allRanks));
    rankAll.addEventListener('click', function () {
      allRanks = !allRanks;
      rankAll.setAttribute('aria-pressed', String(allRanks));
      if (history.replaceState) {
        var u = new URL(location.href);
        if (allRanks) u.searchParams.set('ranks', 'all'); else u.searchParams.delete('ranks');
        history.replaceState(null, '', u.toString());
      }
      rebuildTree();
    });
  }
  var q0 = new URLSearchParams(location.search).get('q');
  if (q0) { q.value = q0; runSearch(q0); }

  /* ── keyboard: the arrow keys walk the tree, as a tree widget should ──────────────────────── */
  function rows() { return [].slice.call(tree.querySelectorAll('li[role="treeitem"]')).filter(function (li) { return li.offsetParent !== null; }); }
  function focusRow(li) {
    var a = li.querySelector(':scope > .sp-tr > .sp-nm');
    (a && a.tagName === 'A' ? a : li.querySelector(':scope > .sp-tr > .sp-tw')).focus();
  }
  tree.addEventListener('keydown', function (e) {
    var li = e.target.closest && e.target.closest('li[role="treeitem"]');
    if (!li) return;
    var all = rows(), i = all.indexOf(li);
    if (e.key === 'ArrowDown' && i < all.length - 1) { focusRow(all[i + 1]); e.preventDefault(); }
    else if (e.key === 'ArrowUp' && i > 0) { focusRow(all[i - 1]); e.preventDefault(); }
    else if (e.key === 'ArrowRight') {
      if (li.getAttribute('aria-expanded') === 'false') expand(li);
      else if (li.getAttribute('aria-expanded') === 'true') { var k = li.querySelector(':scope > ul > li'); if (k) focusRow(k); }
      e.preventDefault();
    } else if (e.key === 'ArrowLeft') {
      if (li.getAttribute('aria-expanded') === 'true') collapse(li);
      else { var p = li.parentElement.closest('li[role="treeitem"]'); if (p) focusRow(p); }
      e.preventDefault();
    } else if (e.key === 'Home' && all.length) { focusRow(all[0]); e.preventDefault(); }
    else if (e.key === 'End' && all.length) { focusRow(all[all.length - 1]); e.preventDefault(); }
  });

  /* ── the matrix: class x dataset, one sequential ramp ─────────────────────────────────────── */
  var mwrap = document.getElementById('sp-matrix');
  var MX = D.mx, cols = MX.cols, mrows = MX.rows;
  var maxN = 1;
  mrows.forEach(function (r) { r.c.forEach(function (c) { if (c && c.n > maxN) maxN = c.n; }); });
  var mx = document.createElement('div');
  mx.className = 'sp-mx';
  mx.style.gridTemplateColumns = 'minmax(140px,1.6fr) repeat(' + cols.length + ', minmax(34px,1fr))';
  mx.setAttribute('role', 'img');
  mx.setAttribute('aria-label', mrows.length + ' classes by ' + cols.length + ' datasets; each cell is the number of taxa observed');
  var head = '<div class="sp-mh sp-mh-first">class · phylum</div>' + cols.map(function (i) {
    return '<div class="sp-mh"><span class="sp-vt">' + esc(DS[i].s.replace(/ \(.*\)$/, '')) + '</span>' +
           '<i style="background:' + esc(DS[i].c) + '"></i></div>';
  }).join('');
  mx.innerHTML = head;
  mrows.forEach(function (r, ri) {
    var lab = document.createElement('div');
    lab.className = 'sp-rl';
    lab.innerHTML = (r.u ? '<a href="' + esc(r.u) + '">' + esc(r.n) + '</a>' : '<span>' + esc(r.n) + '</span>') +
                    '<small>' + (r.ph ? esc(r.ph) + ' · ' : '') + fmt(r.t) + ' taxa</small>';
    mx.appendChild(lab);
    r.c.forEach(function (c, ci) {
      var el = document.createElement('div');
      var v = c ? c.n : 0;
      var a = v ? 0.08 + 0.82 * Math.sqrt(v / maxN) : 0;
      el.className = 'sp-c' + (v ? (a > 0.5 ? ' sp-c-on' : '') : ' sp-c-z');
      el.textContent = v ? String(v) : '';
      if (v) {
        el.style.background = tint(Math.round(a * 100));
        el.setAttribute('tabindex', '0');
        el.setAttribute('role', 'button');
        el.setAttribute('aria-label', r.n + ' × ' + DS[cols[ci]].s + ': ' + v + ' taxa, ' + fmt(c.o) + ' observations');
        el.title = r.n + ' × ' + DS[cols[ci]].s + ' — ' + v + ' taxa, ' + fmt(c.o) + ' observations';
        el.addEventListener('mousemove', function (e) {
          tt.innerHTML = '<b>' + esc(r.n) + ' × ' + esc(DS[cols[ci]].s) + '</b>' +
            '<span class="sp-d">' + fmt(v) + ' taxa · ' + fmt(c.o) + ' observations</span>' +
            '<span class="sp-d">' + esc(c.t.join(', ')) + '</span>';
          place(e);
        });
        el.addEventListener('mouseleave', hideTip);
        var open = function () { openClass(r); };
        el.addEventListener('click', open);
        el.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { open(); e.preventDefault(); } });
      }
      mx.appendChild(el);
    });
  });
  mwrap.appendChild(mx);
  mwrap.insertAdjacentHTML('beforeend',
    '<p class="sp-legend">taxa observed <span class="sp-ramp"></span> 1 → ' + fmt(maxN) +
    ' · hover a cell for its top three · click one to open that class in the tree</p>');

  /* a cell's click opens its class in the tree — the row label carries the class's own page link */
  function openClass(r) {
    var key = null;
    if (r.u) { var m = /\/species\/([^/]+)\//.exec(r.u); if (m) key = m[1].replace(/-(\d+)$/, ':$1'); }
    if (!key || !N[key]) { q.value = r.n; runSearch(r.n); writeQ(r.n); return; }
    q.value = '';
    writeQ('');
    clearHits();
    tree.querySelectorAll(':scope > ul > li').forEach(collapse);
    var li = reveal(key);
    if (!li) return;
    expand(li);
    li.querySelector(':scope > .sp-tr').classList.add('sp-hit');
    qn.textContent = r.n + ' · ' + fmt(r.t) + ' taxa';
    li.scrollIntoView({ block: 'center', behavior: 'instant' });
    focusRow(li);
  }

  /* the tree pane is exactly as tall as the matrix pane beside it — no unbounded text beside a
     fixed-height figure (the mockup's syncTree) */
  var two = document.querySelector('.sp-two');
  function syncTree() {
    if ((two.getAttribute('data-panes') || 'both') === 'both' && innerWidth > 1000) {
      var mp = mwrap.parentElement, ph = tree.parentElement.querySelector('.sp-pane-h');
      tree.style.height = Math.max(420, mp.offsetHeight - ph.offsetHeight - 2) + 'px';
    } else tree.style.height = '';
  }
  addEventListener('resize', syncTree);
  /* the matrix's height is not final until its vertical headers and the display face have laid
     out, so measure again after a frame and after the fonts land rather than once at t = 0 */
  requestAnimationFrame(function () { requestAnimationFrame(syncTree); });
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(syncTree);
  setTimeout(syncTree, 400);

  /* ── the panes: expand the tree or the matrix to the full width, or show both (Ben, 2026-09-09:
     "trouble clicking into a species because of crowding") — `?panes=tree|matrix` in the URL and
     nowhere else: the choice was remembered per viewer until 2026-09-10, when an expanded matrix
     followed Ben across visits with the tree gone and a search counting matches nobody could see.
     The collapsed pane is never gone: it folds into a vertical pill beside the expanded one (the
     Explorer's collapsed-panel idiom), and the pill is the button that shows both again. ─────── */
  function setPanes(mode, write) {
    mode = (mode === 'tree' || mode === 'matrix') ? mode : 'both';
    two.setAttribute('data-panes', mode);
    document.querySelectorAll('.sp-pane-max').forEach(function (b) {
      var own = b.dataset.pane, alone = mode === own, label = alone ? 'Show both panes' : 'Expand the ' + own + ' to the full width';
      b.textContent = alone ? '⤡' : '⤢';
      b.setAttribute('aria-label', label);
      b.title = label;
    });
    document.querySelectorAll('.sp-pane-pill').forEach(function (p) {
      p.hidden = !(mode !== 'both' && mode !== p.dataset.pane);
    });
    if (write !== false && history.replaceState) {
      var u = new URL(location.href);
      if (mode === 'both') u.searchParams.delete('panes'); else u.searchParams.set('panes', mode);
      history.replaceState(null, '', u.toString());
    }
    syncTree();
  }
  document.querySelectorAll('.sp-pane-max').forEach(function (b) {
    b.addEventListener('click', function () {
      setPanes(two.getAttribute('data-panes') === b.dataset.pane ? 'both' : b.dataset.pane);
    });
  });
  document.querySelectorAll('.sp-pane-pill').forEach(function (p) {
    p.addEventListener('click', function () { setPanes('both'); });
  });
  try { localStorage.removeItem('cc_species_panes'); } catch (e) {}   /* the pre-2026-09-10 memory */
  setPanes(new URLSearchParams(location.search).get('panes') || 'both', false);
  /* a search that found something shows the tree it found it in — `?panes=matrix&q=…` is a
     contradiction the match resolves */
  if (tree.querySelector('.sp-hit') && two.getAttribute('data-panes') === 'matrix') setPanes('both');

  /* ── the icicle ──────────────────────────────────────────────────────────────────────────── */
  var LEV = ['Kingdom', 'Phylum', 'Class', 'Order', 'Family'];
  var MIX = [82, 62, 44, 28, 16];
  var svg = document.getElementById('sp-ice'), crumb = document.getElementById('sp-crumb');
  var by = 'o', zoom = [D.ice];

  function drawIce() {
    var W = svg.clientWidth || 1100, H = 340;
    svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
    svg.innerHTML = '';
    var cur = zoom[zoom.length - 1], d0 = zoom.length - 1;
    var nlev = Math.max(1, LEV.length - d0), cw = W / nlev, top = 18;
    LEV.slice(d0).forEach(function (L, i) {
      svgEl('text', { x: i * cw + 6, y: 12, cls: 'sp-lvl', text: L }, svg);
    });
    var total = cur[by] || 1;
    var rec = function (node, lvl, y0, y1) {
      var kids = (node.kids || []).filter(function (k) { return k[by] > 0; })
                                  .sort(function (a, b) { return b[by] - a[by]; });
      var y = y0;
      kids.forEach(function (kid) {
        var h = (y1 - y0) * kid[by] / (node[by] || 1);
        if (h < 0.5) return;
        var x = lvl * cw, mix = MIX[lvl + d0] || 16;
        var g = svgEl('g', {}, svg);
        svgEl('rect', { x: x, y: y, width: cw, height: Math.max(h, 1), fill: tint(mix) }, g);
        if (h >= 14) {
          var label = kid.name, room = Math.max(3, Math.floor((cw - 12) / 7));
          svgEl('text', { x: x + 6, y: y + Math.min(h / 2 + 4.5, 16), fill: mix > 50 ? 'var(--on-accent)' : 'var(--fg)',
                          text: label.length > room ? label.slice(0, room) + '…' : label }, g);
          if (h >= 30) {
            svgEl('text', { x: x + 6, y: y + Math.min(h / 2 + 4.5, 16) + 14, fill: mix > 50 ? 'var(--on-accent)' : 'var(--muted)',
                            style: 'font-size:11px',
                            text: by === 'o' ? fmtK(kid.o) + ' obs' : fmt(kid.sp) + ' sp' }, g);
          }
        }
        g.addEventListener('click', function () { zoom = zoom.slice(0, lvl + d0 + 1); zoom.push(kid); drawIce(); });
        g.addEventListener('mousemove', function (e) {
          var ds = (kid.d || []).slice().sort(function (a, b) { return b[1] - a[1]; }).map(function (p) { return p[0]; });
          tt.innerHTML = '<b>' + esc(kid.name) + '</b><span class="sp-d">' + esc(LEV[lvl + d0] || '') + ' · ' +
            fmt(kid.o) + ' observations · ' + fmt(kid.sp) + ' species · ' +
            Math.round(100 * kid[by] / total) + ' % of ' + esc(cur.name) + '</span>' +
            (ds.length ? '<span class="sp-d">' + dsLine(ds) + '</span>' : '');
          place(e);
        });
        g.addEventListener('mouseleave', hideTip);
        rec(kid, lvl + 1, y, y + h);
        y += h;
      });
    };
    rec(cur, 0, top, H);
    crumb.innerHTML = zoom.map(function (z, i) {
      return '<button type="button" data-i="' + i + '">' + esc(z.name) + '</button>';
    }).join('<span class="sp-sep" aria-hidden="true">›</span>');
    crumb.querySelectorAll('button').forEach(function (b) {
      b.addEventListener('click', function () { zoom = zoom.slice(0, +b.dataset.i + 1); drawIce(); });
    });
  }
  document.querySelectorAll('.sp-seg button').forEach(function (b) {
    b.addEventListener('click', function () {
      document.querySelectorAll('.sp-seg button').forEach(function (x) { x.setAttribute('aria-pressed', String(x === b)); });
      by = b.dataset.by;
      svg.setAttribute('aria-label', 'Icicle of the taxonomic hierarchy, sized by ' + (by === 'o' ? 'observations' : 'species'));
      drawIce();
    });
  });
  drawIce();
  addEventListener('resize', drawIce);
})();

// ── index glyphs (WS-F4) ───────────────────────────────────────────────────────────────────────
// A phylum or class tree row draws its taxon's silhouette before the name — 18 px tall, width from
// its aspect, `fill: currentColor` baked into the markup so it takes the row's own colour (a link's
// accent, a plain label's --fg). `_plugins/species.rb` puts `sil: { inner, vb, aspect }` on a tree
// node's JSON only when the rank is Phylum/Class AND `_data/taxa_media.json` (WS-F2a's fetch; ten
// taxa in the WS-F4 fixture, so almost every row here has none yet) carries that taxon's silhouette
// — so this reads #sp-data again rather than touching the tree code above, and a MutationObserver
// decorates rows the tree builds lazily (search reveal, fold, "all ranks") as well as the ones it
// draws up front. A row with no "sil" is untouched: no glyph, no change to its height.
(function () {
  var dataEl = document.getElementById('sp-data');
  var tree = document.getElementById('sp-tree');
  if (!dataEl || !tree) return;
  var sil = {};
  try {
    (JSON.parse(dataEl.textContent).nodes || []).forEach(function (n) { if (n.sil) sil[n.k] = n.sil; });
  } catch (e) { return; }
  if (!Object.keys(sil).length) return; // the fixture's correct empty state — nothing to draw

  function attrEsc(s) { return String(s).replace(/"/g, '&quot;'); }
  function glyphHtml(s) {
    var w = Math.round(18 * (s.aspect || 1) * 100) / 100;
    return '<svg class="sp-sil" width="' + w + '" height="18" viewBox="' + attrEsc(s.vb) +
           '" aria-hidden="true" focusable="false">' + s.inner + '</svg>';
  }

  function decorate(li) {
    var k = li.dataset && li.dataset.k, s = k && sil[k];
    if (!s) return;
    var nm = li.querySelector(':scope > .sp-tr > .sp-nm');
    if (!nm || nm.querySelector(':scope > .sp-sil')) return;
    nm.insertAdjacentHTML('afterbegin', glyphHtml(s));
  }

  tree.querySelectorAll('li[data-k]').forEach(decorate);
  new MutationObserver(function (muts) {
    muts.forEach(function (m) {
      m.addedNodes.forEach(function (node) {
        if (node.nodeType !== 1) return;
        if (node.matches && node.matches('li[data-k]')) decorate(node);
        if (node.querySelectorAll) node.querySelectorAll('li[data-k]').forEach(decorate);
      });
    });
  }).observe(tree, { childList: true, subtree: true });
})();
