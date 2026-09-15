/* assets/info.js — the pill + ⓘ idiom (plan D1). One <details class="cc-info"> open at a time,
   closed by a click outside it or by Escape; under 640 px the pop is a bottom sheet (CSS only,
   style.css). No dependency; loaded `defer` on every page from _layouts/default.html. */
(function () {
  "use strict";

  function closeAllBut(keep) {
    [].forEach.call(document.querySelectorAll("details.cc-info[open]"), function (d) {
      if (d !== keep) d.removeAttribute("open");
    });
  }

  document.addEventListener("click", function (e) {
    // a click on a ⓘ summary — close every OTHER open pop; the native <details> toggle handles
    // this one (open <-> closed) on its own, after listeners run
    var trigger = e.target.closest && e.target.closest("details.cc-info > summary");
    if (trigger) { closeAllBut(trigger.closest("details.cc-info")); return; }
    // a click anywhere else outside an open pop closes every one
    var inside = e.target.closest && e.target.closest("details.cc-info");
    if (!inside) closeAllBut(null);
  });

  document.addEventListener("keydown", function (e) {
    if (e.key !== "Escape") return;
    var open = document.querySelector("details.cc-info[open]");
    if (!open) return;
    var summary = open.querySelector("summary");
    open.removeAttribute("open");
    if (summary && summary.focus) summary.focus();
  });
})();
