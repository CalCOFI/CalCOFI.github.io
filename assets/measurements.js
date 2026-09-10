/* measurements.js — the measurements catalog's drawings.
 *
 * WS-M3 ships the URL elision only, so a measurement page's ".mm-url" rows are one line on a phone
 * from the day the pages exist; WS-M4 REPLACES this file with the index's timeline table, the
 * category × dataset matrix, the datasets list, the search and the page's three figures, drawn
 * from the inline JSON this generator already emits:
 *
 *   #mm-data         the index record (keys, labels, category, units, P01, per-series spans/totals)
 *   #mm-strip-data   the page's years strip   → #mm-strip  (an <svg>)
 *   #mm-depth-data   the page's depth bands   → #mm-depth
 *   #mm-months-data  the page's month strip   → #mm-months
 *
 * Nothing here reads a number that is not in one of those four scripts.
 */
(function () {
  "use strict";

  // a URL is a full-width single mono line: elide it from the MIDDLE, so the tail — the
  // measurement the tool opens on — survives (the same rule assets/species.js uses)
  function elide(a) {
    var full = a.getAttribute("data-full");
    if (full === null) { full = a.textContent; a.setAttribute("data-full", full); }
    a.textContent = full;
    if (a.scrollWidth <= a.clientWidth) return;
    var n = full.length;
    while (a.scrollWidth > a.clientWidth && n > 12) {
      n -= 2;
      var h = Math.floor(n / 2);
      a.textContent = full.slice(0, h) + "…" + full.slice(full.length - (n - h));
    }
  }

  function elideAll() {
    [].forEach.call(document.querySelectorAll("a.mm-url"), elide);
  }

  elideAll();
  window.addEventListener("resize", elideAll);
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(elideAll);
})();
