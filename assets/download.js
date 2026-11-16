/* assets/download.js — a dataset page's Download dialog (_layouts/dataset.html, _includes/download_options.html).

   Without this script the head's button is a plain link to the CSV zip and the options are a
   <noscript> section, so nothing here is needed to download. With it:

     · the button opens the native <dialog> (showModal: the page behind is inert, focus moves to the
       CSV link — the dialog's default action — and Esc closes it); Space works as on a button
     · Close, Esc and a click on the backdrop close it, and focus returns to what opened it
     · #download on the URL opens it on load: every catalog row's Download control links here
     · "Every endpoint" closes it, opens the #access fold and moves there
     · each zip link sends one GA4 event, `dataset_download` {dataset_key, format, file_name,
       link_url}, through the gtag the layout loads in production — and, like the layout's own
       config call, never from an automated browser (navigator.webdriver). Not `file_download`: GA4's
       enhanced measurement already sends that for a .zip link, and the same name twice would count
       every download twice.

   No dependency; ~70 lines. */
(function () {
  "use strict";
  var dlg = document.getElementById("dl-dialog");
  var btn = document.getElementById("dl-btn");

  function track(a) {
    if (typeof window.gtag !== "function" || navigator.webdriver) return;
    var href = a.getAttribute("href") || "";
    window.gtag("event", "dataset_download", {
      dataset_key: a.getAttribute("data-dl-key"), format: a.getAttribute("data-dl-format"),
      file_name: href.split("/").pop(), file_extension: "zip", link_url: href
    });
  }
  // every zip link on the page, the button's own modified click (a new tab, a save-as) included
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest("a[data-dl-format]");
    if (a && !e.defaultPrevented) track(a);
  });

  // no <dialog> support: the button stays the plain CSV link it was rendered as
  if (!dlg || !btn || typeof dlg.showModal !== "function") return;

  var opener = null;
  btn.setAttribute("role", "button");
  btn.setAttribute("aria-haspopup", "dialog");
  btn.setAttribute("aria-controls", "dl-dialog");

  function open(from) {
    if (dlg.open) return;
    opener = from || document.activeElement;
    dlg.showModal();
  }
  function plain(e) { return e.button === 0 && !e.metaKey && !e.ctrlKey && !e.shiftKey && !e.altKey; }

  btn.addEventListener("click", function (e) {
    if (!plain(e)) return;            // ctrl/cmd/shift-click: the link itself, as the browser does it
    e.preventDefault();
    open(btn);
  });
  btn.addEventListener("keydown", function (e) {
    if (e.key === " " || e.key === "Spacebar") { e.preventDefault(); open(btn); }
  });

  dlg.addEventListener("close", function () {
    if (location.hash === "#download") history.replaceState(null, "", location.pathname + location.search);
    var to = opener && document.contains(opener) && opener !== document.body ? opener : btn;
    opener = null;
    if (to && to.focus) to.focus();
  });
  // the dialog's own box is .dl-in, so a click whose target is the <dialog> itself is the backdrop
  dlg.addEventListener("click", function (e) { if (e.target === dlg) dlg.close(); });
  [].forEach.call(dlg.querySelectorAll("[data-dl-close]"), function (b) {
    b.addEventListener("click", function () { dlg.close(); });
  });
  [].forEach.call(dlg.querySelectorAll("[data-dl-endpoints]"), function (a) {
    a.addEventListener("click", function (e) {
      var fold = document.getElementById("access");
      if (!fold) return;
      e.preventDefault();
      opener = fold.querySelector("summary");
      dlg.close();
      fold.open = true;
      fold.scrollIntoView({ block: "start" });
      history.replaceState(null, "", "#access");
    });
  });

  function fromHash() { if (location.hash === "#download") open(btn); }
  fromHash();
  window.addEventListener("hashchange", fromHash);
})();
