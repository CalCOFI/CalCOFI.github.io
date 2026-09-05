/* assets/copy.js — the copy buttons beside a URL, a code line, a hash or a citation (plan D-8,
   Decision 15). Progressive: with no JS the text is still selectable and every URL is still a
   link, so nothing here is load-bearing. */
(function () {
  "use strict";
  document.addEventListener("click", function (e) {
    var b = e.target.closest && e.target.closest(".cc-copy[data-copy]");
    if (!b || !navigator.clipboard) return;
    if (!b.dataset.label) b.dataset.label = b.getAttribute("aria-label") || "Copy";
    navigator.clipboard.writeText(b.dataset.copy).then(function () {
      b.setAttribute("data-copied", "");
      b.setAttribute("aria-label", "Copied");
      setTimeout(function () {
        b.removeAttribute("data-copied");
        b.setAttribute("aria-label", b.dataset.label);
      }, 1500);
    }, function () {});
  });
})();
