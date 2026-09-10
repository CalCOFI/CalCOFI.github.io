/* tabs.js — the one tab switcher for every tabbed section on the front door, and the header
   submenus' keyboard escape (plan 2026-09-10 § D7).

   Markup contract (index.html, _layouts/default.html):
     .tabset[id="ts-<section>"]  > .tabrow[role=tablist] > button[role=tab][data-tab=<id>]
                                 > .tabpanel[data-panel=<id>][role=tabpanel]
     a[data-go="<section>:<tab>"]  anywhere (the header submenu) selects that tab

   Rules: aria-selected on the buttons, `hidden` on the panels, arrow keys move and select, the
   selected tab of the FIRST tabset on the page rides in `?tab=` and is restored on load, and
   Escape closes an open header submenu. No dependency, no framework; a page with no .tabset
   still gets the Escape handler and nothing else.

   Progressive enhancement: the panels are rendered with `hidden` already set by Liquid, so the
   first tab is the one that shows with JS off — never a blank section. */
(function () {
  "use strict";

  var PARAM = "tab";

  function tabsOf(ts) { return [].slice.call(ts.querySelectorAll(".tabrow > button")); }

  function select(ts, id, focus) {
    var hit = false;
    tabsOf(ts).forEach(function (b) {
      var on = b.getAttribute("data-tab") === id;
      if (on) hit = true;
      b.setAttribute("aria-selected", on ? "true" : "false");
      b.setAttribute("tabindex", on ? "0" : "-1");
      if (on && focus) b.focus();
    });
    if (!hit) return false;
    [].forEach.call(ts.querySelectorAll(".tabpanel"), function (p) {
      p.hidden = p.getAttribute("data-panel") !== id;
    });
    return true;
  }

  // the selected tab in the URL, so a view is shareable and the browser Back button works
  function remember(ts, id) {
    if (!ts.hasAttribute("data-url-tab")) return;
    try {
      var u = new URL(window.location.href);
      u.searchParams.set(PARAM, id);
      window.history.replaceState(null, "", u.toString());
    } catch (e) { /* an old browser simply does not remember; the tab still switches */ }
  }

  var sets = [].slice.call(document.querySelectorAll(".tabset"));

  sets.forEach(function (ts) {
    var row = ts.querySelector(".tabrow");
    if (!row) return;

    tabsOf(ts).forEach(function (b) {
      b.addEventListener("click", function () {
        var id = b.getAttribute("data-tab");
        if (select(ts, id)) remember(ts, id);
      });
    });

    row.addEventListener("keydown", function (e) {
      var k = e.key, bs = tabsOf(ts), i = bs.indexOf(document.activeElement);
      if (i < 0) return;
      var n = null;
      if (k === "ArrowRight") n = bs[(i + 1) % bs.length];
      else if (k === "ArrowLeft") n = bs[(i + bs.length - 1) % bs.length];
      else if (k === "Home") n = bs[0];
      else if (k === "End") n = bs[bs.length - 1];
      if (!n) return;
      e.preventDefault();
      var id = n.getAttribute("data-tab");
      if (select(ts, id, true)) remember(ts, id);
    });
  });

  // the header submenu's links (and any other deep link) select a tab and jump to its section
  [].forEach.call(document.querySelectorAll("[data-go]"), function (a) {
    a.addEventListener("click", function () {
      var parts = String(a.getAttribute("data-go")).split(":");
      var ts = document.getElementById("ts-" + parts[0]);
      if (ts && select(ts, parts[1])) remember(ts, parts[1]);
      if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
    });
  });

  // restore ?tab= on load — the first tabset that owns a panel of that id wins
  try {
    var want = new URL(window.location.href).searchParams.get(PARAM);
    if (want) {
      for (var i = 0; i < sets.length; i++) {
        if (sets[i].querySelector('.tabpanel[data-panel="' + window.CSS.escape(want) + '"]')) {
          select(sets[i], want);
          break;
        }
      }
    }
  } catch (e) { /* no URL API, or CSS.escape: the first tab stays selected */ }

  // aria-expanded follows what the CSS actually does: the submenu is open while the pointer is
  // over the group or focus is inside it, so the trigger says so rather than lying "false"
  [].forEach.call(document.querySelectorAll(".cc-links .cc-m"), function (m) {
    var trigger = m.querySelector("a[aria-haspopup]");
    if (!trigger) return;
    var say = function (open) { trigger.setAttribute("aria-expanded", open ? "true" : "false"); };
    m.addEventListener("focusin", function () { say(true); });
    m.addEventListener("focusout", function () { say(false); });
    m.addEventListener("mouseenter", function () { say(true); });
    m.addEventListener("mouseleave", function () { if (!m.contains(document.activeElement)) say(false); });
  });

  // Escape closes an open header submenu — the submenu itself is :hover / :focus-within CSS, so
  // blurring the focused link inside it is the whole close (plan D7: never a dropdown library)
  document.addEventListener("keydown", function (e) {
    if (e.key !== "Escape") return;
    var el = document.activeElement;
    if (el && el.closest && el.closest(".cc-links .cc-m")) el.blur();
  });
})();
