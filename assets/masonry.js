/* assets/masonry.js — pack the dataset grid (plan D-2, Decision 1). Plain JS, no framework.
   A CSS grid stretches every tile to the tallest in its row: 2,838 px of the measured 4,910 px
   grid was that stretch. `align-items: start` (style.css) stops the stretching but not the rows,
   so each tile gets a `grid-row-end: span n` from its own measured height over an 8 px row and a
   zero row-gap (the 24 px gap is folded into the span). Reading order is unchanged — the tiles
   stay in DOM order; masonry only fills the vertical. */
(function () {
  "use strict";
  var grid = document.getElementById("ds-grid");
  if (!grid) return;

  // when CSS masonry is available, say so and stop
  if (window.CSS && CSS.supports && CSS.supports("grid-template-rows", "masonry")) {
    grid.style.gridTemplateRows = "masonry";
    return;
  }

  var ROW = 8, GAP = 24, raf = 0;

  function pack() {
    raf = 0;
    // one column: the spans would do nothing and the 8 px rows would round the gap away
    if (getComputedStyle(grid).gridTemplateColumns.split(" ").length < 2) {
      grid.classList.remove("is-masonry");
      return;
    }
    grid.classList.add("is-masonry");
    Array.prototype.forEach.call(grid.children, function (tile) {
      if (tile.hidden) { tile.style.gridRowEnd = ""; return; }
      tile.style.gridRowEnd = "";                       // measure natural, then span
      tile.style.gridRowEnd = "span " + Math.ceil((tile.getBoundingClientRect().height + GAP) / ROW);
    });
  }

  function schedule() { if (!raf) raf = requestAnimationFrame(pack); }

  schedule();
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(schedule);
  window.addEventListener("resize", schedule);
  document.addEventListener("ds:filtered", schedule);   // catalog.js dispatches this after apply()
})();
