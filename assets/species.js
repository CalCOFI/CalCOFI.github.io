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

/* ── faces (WS-F3) ─────────────────────────────────────────────────────────────────────────────
   "How big is it" on a species page: the log ladder, the beside figure and the developmental
   plate (plan 2026-09-11 § D3, D5). Its own IIFE, so nothing above can reach it and WS-F4's
   index glyphs append cleanly after it.

   Every number this draws is read from the inline #sp-size-data written by _plugins/species.rb —
   the taxon's lengths from _data/taxa_media.json, the six reference objects from
   _data/size_reference.csv. Nothing here is a measurement; the script computes positions, formats
   a length and lays out labels so that no two overlap.

   The face row, the sentence and the glance are NOT here: they are content, composed server-side
   in Liquid, and a page read without JavaScript still has them. */
(function () {
  'use strict';

  var host = document.getElementById('sp-size-data');
  if (!host) return;
  var D;
  try { D = JSON.parse(host.textContent); } catch (e) { return; }

  var ladderEl = document.getElementById('sp-ladder');
  var besideEl = document.getElementById('sp-beside');
  var plateEl = document.getElementById('sp-plate');

  function esc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
                                     .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  /* the same rule _plugins/species.rb writes the glance with: µm below a millimetre, then mm, cm, m */
  function tidy(v) { return Math.abs(v - Math.round(v)) < 0.05 ? String(Math.round(v)) : v.toFixed(1); }
  function fmtLen(m) {
    if (m < 1e-3) return tidy(m * 1e6) + ' µm';
    if (m < 1e-2) return tidy(m * 1e3) + ' mm';
    if (m < 1) return tidy(m * 100) + ' cm';
    return tidy(m) + ' m';
  }
  function fmtMM(lo, hi) { return lo === hi ? lo + ' mm' : lo + '–' + hi + ' mm'; }
  function article(l) { return /^(a |an |the )/i.test(l) ? l : 'the ' + l; }

  var REFS = D.refs || [];
  var FAMILIAR = ['quarter', 'ring', 'person', 'ship'];
  /* the same choice the glance makes server-side: the smallest |log10(organism / reference)|
     among the familiar objects, hair and mesh joining only for something below a couple of mm */
  function nearestRef(m) {
    var pool = REFS.filter(function (r) { return FAMILIAR.indexOf(r.k) >= 0; });
    if (!pool.length || m < 0.002) pool = REFS;
    return pool.reduce(function (best, r) {
      return Math.abs(Math.log10(m / r.m)) < Math.abs(Math.log10(m / best.m)) ? r : best;
    }, pool[0]);
  }

  /* ── the reference glyphs ───────────────────────────────────────────────────────────────────
     Drawn to fit a box of height h, centred on x with its foot at y. They are drawings, not data:
     the LENGTH each one stands for is read from size_reference.csv and never from these paths. */
  function refGlyph(k, x, y, h, cls) {
    cls = cls || 'sp-refg';
    var s, x0, y0, r, w, L;
    if (k === 'hair') {
      return '<line x1="' + x + '" x2="' + x + '" y1="' + (y - h) + '" y2="' + y + '" class="' + cls + '" stroke-width="1.5"/>';
    }
    if (k === 'mesh') {
      s = h * 0.8; x0 = x - s / 2; y0 = y - s;
      var g = '<g class="' + cls + '" style="fill:none" stroke-width="1"><rect x="' + x0 + '" y="' + y0 + '" width="' + s + '" height="' + s + '"/>';
      [1, 2].forEach(function (i) {
        g += '<line x1="' + (x0 + i * s / 3) + '" x2="' + (x0 + i * s / 3) + '" y1="' + y0 + '" y2="' + (y0 + s) + '"/>';
        g += '<line y1="' + (y0 + i * s / 3) + '" y2="' + (y0 + i * s / 3) + '" x1="' + x0 + '" x2="' + (x0 + s) + '"/>';
      });
      return g + '</g>';
    }
    if (k === 'quarter') {
      r = h * 0.42;
      return '<g class="' + cls + '"><circle cx="' + x + '" cy="' + (y - r) + '" r="' + r + '" style="fill:none" stroke-width="' +
             Math.max(1, r * 0.12) + '" stroke-dasharray="' + (r * 0.18).toFixed(2) + ' ' + (r * 0.12).toFixed(2) +
             '"/><circle cx="' + x + '" cy="' + (y - r) + '" r="' + (r * 0.72) + '" style="fill:none" stroke-width="' +
             Math.max(1, r * 0.06) + '"/></g>';
    }
    if (k === 'ring') {
      r = h * 0.46;
      return '<circle cx="' + x + '" cy="' + (y - r) + '" r="' + r + '" style="fill:none" class="' + cls +
             '" stroke-width="' + Math.max(2, r * 0.1) + '"/>';
    }
    if (k === 'person') {
      /* a plain standing figure at roughly human proportions — the head about a seventh of it */
      w = h * 0.26; x0 = x - w / 2;
      var hr = h * 0.072, cy = y - h + hr;
      return '<g class="' + cls + '" stroke="none"><circle cx="' + x + '" cy="' + cy + '" r="' + hr + '"/>' +
             '<path d="M' + x0 + ',' + (y - h * 0.40) + ' L' + x0 + ',' + (y - h * 0.82) +
             ' Q' + x + ',' + (y - h * 0.94) + ' ' + (x0 + w) + ',' + (y - h * 0.82) +
             ' L' + (x0 + w) + ',' + (y - h * 0.40) + ' Z"/>' +
             '<rect x="' + (x - w * 0.40) + '" y="' + (y - h * 0.44) + '" width="' + (w * 0.30) + '" height="' + (h * 0.44) + '"/>' +
             '<rect x="' + (x + w * 0.10) + '" y="' + (y - h * 0.44) + '" width="' + (w * 0.30) + '" height="' + (h * 0.44) + '"/></g>';
    }
    if (k === 'ship') {
      L = h * 3.2; x0 = x - L / 2;
      return '<g class="' + cls + '" stroke="none"><path d="M' + x0 + ',' + (y - h * 0.32) + ' L' + (x0 + L) + ',' + (y - h * 0.32) +
             ' L' + (x0 + L * 0.93) + ',' + y + ' L' + (x0 + L * 0.06) + ',' + y + ' Z"/>' +
             '<path d="M' + (x0 + L * 0.18) + ',' + (y - h * 0.32) + ' L' + (x0 + L * 0.18) + ',' + (y - h * 0.62) +
             ' L' + (x0 + L * 0.56) + ',' + (y - h * 0.62) + ' L' + (x0 + L * 0.56) + ',' + (y - h * 0.85) +
             ' L' + (x0 + L * 0.72) + ',' + (y - h * 0.85) + ' L' + (x0 + L * 0.72) + ',' + (y - h * 0.32) + ' Z"/>' +
             '<rect x="' + (x0 + L * 0.62) + '" y="' + (y - h) + '" width="' + (L * 0.015) + '" height="' + (h * 0.2) + '"/></g>';
    }
    return '';
  }

  function silSvg(x, y, w, h, cls) {
    if (!D.sil || !D.sil.inner) return '';
    return '<svg x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" viewBox="' + D.sil.vb +
           '" preserveAspectRatio="xMidYMid meet" class="' + cls + '">' + D.sil.inner + '</svg>';
  }

  /* greedy row assignment: no two labels share a row while their boxes overlap horizontally */
  function assignRows(items, gap) {
    var ends = [];
    items.sort(function (a, b) { return a.left - b.left; }).forEach(function (o) {
      var r = 0;
      while (ends[r] != null && o.left < ends[r] + gap) r++;
      ends[r] = o.right;
      o.row = r;
    });
    return items;
  }

  function marksOf() {
    var out = (D.early || []).map(function (e) {
      return { label: e.stage, lo: e.mm[0] / 1e3, hi: e.mm[1] / 1e3, src: e.source };
    });
    if (D.size) out.push({ label: 'adult, max', lo: D.size.m, hi: D.size.m, src: D.size.source, adult: true });
    return out;
  }

  /* ── the ladder: 10 µm → 100 m, the references above the axis, the taxon's marks below ────── */
  function drawLadder() {
    if (!ladderEl || !REFS.length) return;
    var W = 1000, x0 = 34, x1 = 966, AX = 122;
    var lx = function (m) { return x0 + (Math.log10(m) + 5) / 7 * (x1 - x0); };
    var refs = assignRows(REFS.map(function (r) {
      var x = lx(r.m), w = Math.max(64, String(r.label).length * 6.6);
      return { r: r, x: x, left: x - w / 2, right: x + w / 2 };
    }), 12);
    var aspect = (D.sil && D.sil.aspect) || 1;
    var marks = assignRows(marksOf().map(function (m) {
      var xa = lx(m.lo), xb = lx(m.hi);
      var val = m.lo === m.hi ? fmtLen(m.lo) : fmtLen(m.lo) + '–' + fmtLen(m.hi);
      var silW = m.adult && D.sil ? 18 * aspect + 6 : 0;
      return { m: m, xa: xa, xb: xb, val: val, silW: silW,
               left: xa - 5, right: xb + 8 + silW + (String(m.label).length + 1) * 6.4 + val.length * 6.3 };
    }), 10);
    var maxRow = marks.reduce(function (a, o) { return Math.max(a, o.row); }, 0);
    var H = AX + 44 + (maxRow + 1) * 22 + 4;
    var s = '<line x1="' + x0 + '" x2="' + x1 + '" y1="' + AX + '" y2="' + AX + '" class="sp-ax"/>';
    for (var e = -5; e <= 2; e++) {
      var x = lx(Math.pow(10, e));
      s += '<line x1="' + x + '" x2="' + x + '" y1="' + (AX - 4) + '" y2="' + (AX + 4) + '" class="sp-ax"/>' +
           '<text x="' + x + '" y="' + (AX + 18) + '" class="sp-tick" text-anchor="middle">' +
           esc(fmtLen(Math.pow(10, e))) + '</text>';
    }
    refs.forEach(function (o) {
      var ly = 16 + o.row * 28;
      // the reference's own note, and its source where that is a citation rather than a bare URL
      // (size_reference.csv carries either; a URL in a <title> tooltip is not clickable)
      var src = o.r.source && !/^https?:\/\//.test(o.r.source) ? ' · ' + o.r.source : '';
      var tip = o.r.label + ': ' + (o.r.note || fmtLen(o.r.m)) + src;
      s += '<g><title>' + esc(tip) + '</title>' + refGlyph(o.r.k, o.x, AX - 12, 40) +
           '<line x1="' + o.x + '" x2="' + o.x + '" y1="' + (AX - 10) + '" y2="' + (AX - 2) + '" class="sp-lead"/>' +
           '<text x="' + o.x + '" y="' + ly + '" text-anchor="middle" class="sp-rlab">' + esc(o.r.label) + '</text>' +
           '<text x="' + o.x + '" y="' + (ly + 13) + '" text-anchor="middle" class="sp-mval">' + esc(fmtLen(o.r.m)) + '</text></g>';
    });
    if (!marks.length) {
      s += '<text x="' + x0 + '" y="' + (AX + 48) + '" class="sp-mlab">No length on record for ' + esc(D.name) +
           ': nothing is marked under the axis.</text>';
    }
    marks.forEach(function (o) {
      var xm = (o.xa + o.xb) / 2, y = AX + 44 + o.row * 22;
      var tip = o.m.label + ': ' + o.val + (o.m.src ? ' · ' + o.m.src : '');
      s += '<g><title>' + esc(tip) + '</title>' +
           '<line x1="' + xm + '" x2="' + xm + '" y1="' + (AX + 2) + '" y2="' + (y - 7) + '" class="sp-lead"/>' +
           (o.xa === o.xb
             ? '<circle cx="' + o.xa + '" cy="' + y + '" r="4.5" class="sp-markdot"/>'
             : '<line x1="' + o.xa + '" x2="' + o.xb + '" y1="' + y + '" y2="' + y + '" class="sp-mark"/>') +
           (o.m.adult ? silSvg(o.xb + 8, y - 9, 18 * aspect, 18, 'sp-org') : '') +
           '<text x="' + (o.xb + 8 + o.silW) + '" y="' + (y + 4) + '" class="sp-mlab">' + esc(o.m.label) +
           ' <tspan class="sp-mval">' + esc(o.val) + '</tspan></text></g>';
    });
    ladderEl.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
    ladderEl.innerHTML = s;
    ladderEl.classList.add('sp-drawn');
  }

  /* ── the beside figure: the silhouette to scale next to the nearest familiar object ───────── */
  function drawBeside() {
    if (!besideEl || !D.size || !D.sil || !D.sil.axis || !REFS.length) return;
    var m = D.size.m, ref = nearestRef(m), aspect = D.sil.aspect || 1;
    var orgW = D.sil.axis === 'w' ? m : m * aspect;
    var orgH = D.sil.axis === 'w' ? m / aspect : m;
    var refW = ref.m, refH = ref.k === 'ship' ? ref.m * 0.31 : ref.m;
    var W = 640, H = 250, pad = 24, gap = 40, base = H - 44;
    var scale = Math.min((W - 2 * pad - gap) / (orgW + refW), (base - 30) / Math.max(orgH, refH));
    var rw = refW * scale, rh = refH * scale, ow = orgW * scale, oh = orgH * scale;
    var xr = pad + rw / 2, xo = pad + rw + gap + ow / 2;
    var ratio = m / ref.m;
    var phrase = ratio >= 1
      ? tidy(ratio) + ' × ' + article(ref.label)
      : Math.round(ref.m / m) + ' of them, ' + (D.sil.axis === 'w' ? 'nose to tail' : 'end to end') +
        ', would span ' + article(ref.label);
    var s = '<line x1="' + pad + '" x2="' + (W - pad) + '" y1="' + base + '" y2="' + base + '" class="sp-base"/>';
    s += refGlyph(ref.k, xr, base, rh, 'sp-refg');
    s += silSvg(xo - ow / 2, base - oh, ow, oh, 'sp-org');
    s += '<text x="' + xr + '" y="' + (base + 18) + '" text-anchor="middle" class="sp-blab">' + esc(ref.label) + '</text>' +
         '<text x="' + xr + '" y="' + (base + 32) + '" text-anchor="middle" class="sp-bval">' + esc(fmtLen(ref.m)) + '</text>' +
         '<text x="' + xo + '" y="' + (base + 18) + '" text-anchor="middle" class="sp-blab">' + esc(D.short) + '</text>' +
         '<text x="' + xo + '" y="' + (base + 32) + '" text-anchor="middle" class="sp-bval">' + esc(fmtLen(m)) +
         (D.size.kind ? ' · ' + esc(D.size.kind) : '') + '</text>' +
         '<text x="' + pad + '" y="16" class="sp-blab">' + esc(phrase) + '</text>';
    besideEl.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
    besideEl.innerHTML = s;
    besideEl.classList.add('sp-drawn');
  }

  /* ── the plate, and the early-life lengths beside it ───────────────────────────────────────
     The plate is the picture of what the ichthyoplankton and CUFES datasets actually record; the
     list is the same lengths the ladder marks, each with the source that measured it. */
  function creditHtml(c) {
    if (!c) return '';
    var out = esc(c.kind || '');
    if (c.by) out += ' · ' + esc(c.by);
    if (c.license) {
      out += ' · ' + (c.license_url
        ? '<a href="' + esc(c.license_url) + '" rel="license external">' + esc(c.license) + '</a>'
        : esc(c.license));
    }
    if (c.via) out += ' · ' + (c.page ? '<a href="' + esc(c.page) + '" rel="external">' + esc(c.via) + '</a>' : esc(c.via));
    if (c.shows) out += ' · ' + esc(c.shows);
    return out;
  }

  function drawPlate() {
    if (!plateEl) return;
    var rows = (D.early || []).map(function (e) {
      return '<li><b>' + esc(e.stage) + '</b><span>' + esc(fmtMM(e.mm[0], e.mm[1])) +
             (e.source ? ' <span class="sp-esrc">' + esc(e.source) + '</span>' : '') + '</span></li>';
    });
    if (D.size) {
      rows.push('<li><b>adult, max</b><span>' + esc(fmtLen(D.size.m)) +
                (D.size.kind ? ' (' + esc(D.size.kind) + ')' : '') +
                (D.size.source ? ' <span class="sp-esrc">' + esc(D.size.source) + '</span>' : '') + '</span></li>');
    }
    var list = rows.length ? '<ul class="sp-early">' + rows.join('') + '</ul>' : '';
    var stages = (D.stages || []).map(function (d) {
      return esc(d.name) + ': ' + esc(d.stages.slice(0, 4).join(', ')) +
             (d.stages.length > 4 ? ' and ' + (d.stages.length - 4) + ' more' : '');
    }).join('; ');
    var note = stages ? '<p class="sp-note">Stages in the datasets · ' + stages + '</p>' : '';

    if (!D.plate) {
      plateEl.innerHTML = (list
        ? '<p class="sp-note">No developmental plate for ' + esc(D.name) +
          ': the NOAA Ichthyoplankton Information System covers north-east Pacific fishes. The lengths still show.</p>' + list
        : '') + note;
      return;
    }
    plateEl.innerHTML =
      '<figure class="sp-plate-fig"><div><div class="sp-plate-img"><img src="' + esc(D.plate.src) +
      '" alt="' + esc(D.plate.alt) + '" loading="lazy" decoding="async"></div>' +
      '<figcaption class="sp-credit">' + creditHtml(D.plate.credit) + '</figcaption></div>' +
      '<div>' + list + note + '</div></figure>';
  }

  drawLadder();
  drawBeside();
  drawPlate();
  addEventListener('resize', function () { drawLadder(); drawBeside(); });
})();
