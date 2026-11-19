/* A side pane taller than the window (Betty 2026-11-16: "you have to scroll all the way down the page
   to see the rest of the right pane"). position: sticky pins the pane's TOP, so its lower part is
   only seen at the end of the list. Here the pane's sticky top becomes negative by however much it
   overflows the window: it scrolls with the page until its bottom is in view, then stays. A pane that
   fits keeps its usual top. For every element with [data-stick]; re-measured when it changes size. */
(function () {
  "use strict";
  var GAP = 14;
  function headerH() {
    var h = document.querySelector(".cc-header");
    return h ? h.getBoundingClientRect().height : 72;
  }
  function fit(el) {
    // inside a page drawn at 90% (css zoom), the pane's height and its top are both in its own, unzoomed px
    var z = el.currentCSSZoom || 1;
    var top = headerH() + GAP, room = window.innerHeight - top - GAP, h = el.offsetHeight * z;
    el.style.top = (h > room ? window.innerHeight - h - GAP : top) / z + "px";
  }
  function init() {
    var els = [].slice.call(document.querySelectorAll("[data-stick]"));
    if (!els.length) return;
    var all = function () { els.forEach(fit); };
    if (window.ResizeObserver) { var ro = new ResizeObserver(all); els.forEach(function (el) { ro.observe(el); }); }
    window.addEventListener("resize", all);
    all();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
