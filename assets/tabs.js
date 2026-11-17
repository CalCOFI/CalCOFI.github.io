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

  // restore ?tab= on load — ONLY a .tabset[data-url-tab] may be restored from the URL (today: the
  // front door's first tabset). A second tabset on a page (the ways-in tabset, a methods tabset)
  // never carries data-url-tab, so it is never a candidate here even if one of its own panel ids
  // happens to match the URL's ?tab= value — the memory belongs to one tabset, not to whichever
  // happens to have a matching panel (plan D2; WS-R1's gate).
  try {
    var want = new URL(window.location.href).searchParams.get(PARAM);
    if (want) {
      for (var i = 0; i < sets.length; i++) {
        if (!sets[i].hasAttribute("data-url-tab")) continue;
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

  // The site nav's three menus (_includes/site_nav.html: Data, Map, Learn; front door v2, reconciled 2026-11-17).
  // Each is a button with aria-expanded and a panel. The CSS opens a menu on hover; this opens it on a press
  // (click, tap, Enter, Space: a touch screen has no hover and a keyboard should not open three menus by
  // tabbing past them), keeps aria-expanded true to what is drawn, and closes it on Escape (focus back on the
  // button, and shut even while the pointer is still over it), on a press outside and when focus leaves.
  // In the menu button's column (under NAV_BREAK) every item is already shown, so the buttons do nothing there.
  var menus = [].slice.call(document.querySelectorAll(".cc-links .cc-m2"));
  var inColumn = function () { return window.innerWidth < 1100; };   // = NAV_BREAK below
  var setMenu = function (m, open) {
    var t = m.querySelector(".cc-m2-t");
    m.classList.toggle("open", open);
    if (t) t.setAttribute("aria-expanded", open || inColumn() ? "true" : "false");
  };
  menus.forEach(function (m) {
    var t = m.querySelector(".cc-m2-t");
    if (!t) return;
    t.addEventListener("click", function () {
      if (inColumn()) return;
      var open = !m.classList.contains("open");
      menus.forEach(function (o) { if (o !== m) setMenu(o, false); });
      setMenu(m, open);
      m.classList.toggle("shut", !open);      // pressed shut under the pointer: stay shut until it leaves
    });
    m.addEventListener("mouseenter", function () { if (!inColumn() && !m.classList.contains("shut")) t.setAttribute("aria-expanded", "true"); });
    m.addEventListener("mouseleave", function () { m.classList.remove("shut"); if (!inColumn()) t.setAttribute("aria-expanded", m.classList.contains("open") ? "true" : "false"); });
    m.addEventListener("focusout", function (e) { if (!m.contains(e.relatedTarget) && !inColumn()) setMenu(m, false); });
  });
  if (menus.length) {
    document.addEventListener("keydown", function (e) {
      if (e.key !== "Escape" || inColumn()) return;
      menus.forEach(function (m) {
        var t = m.querySelector(".cc-m2-t"), shown = m.classList.contains("open") || m.matches(":hover");
        if (!shown) return;
        var had = m.contains(document.activeElement);
        setMenu(m, false);
        if (m.matches(":hover")) m.classList.add("shut");
        if (had && t) t.focus();
      });
    });
    document.addEventListener("click", function (e) {
      menus.forEach(function (m) { if (!m.contains(e.target)) setMenu(m, false); });
    });
    var syncMenus = function () { menus.forEach(function (m) { setMenu(m, !inColumn() && m.classList.contains("open")); }); };
    window.addEventListener("resize", syncMenus);
    syncMenus();
  }

  // the menu button (Ben, 2026-09-10; from 2026-11-16 under NAV_BREAK, style.css's breakpoint — the
  // width below which the header's eight items no longer fit one line): the hamburger in the
  // icon cluster toggles one class on the header and the CSS shows the same nav as a column. A tap
  // on any link closes it (the page jumps to the section), Escape closes it and returns focus to
  // the button, and growing past the breakpoint closes it so the desktop header is never stale.
  var NAV_BREAK = 1100;   // = style.css @media (max-width: 1099px) and check_layout.py NAV_BREAK
  var header = document.querySelector(".cc-header");
  var burger = header && header.querySelector(".cc-menu-button");
  if (header && burger) {
    var setNav = function (open) {
      header.classList.toggle("cc-nav-open", open);
      burger.setAttribute("aria-expanded", open ? "true" : "false");
      burger.setAttribute("aria-label", open ? "Close the menu" : "Open the menu");
    };
    burger.addEventListener("click", function () { setNav(!header.classList.contains("cc-nav-open")); });
    header.addEventListener("click", function (e) {
      var a = e.target && e.target.closest && e.target.closest(".cc-links a");
      if (a && header.classList.contains("cc-nav-open")) setNav(false);
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && header.classList.contains("cc-nav-open")) { setNav(false); burger.focus(); }
    });
    window.addEventListener("resize", function () {
      if (window.innerWidth >= NAV_BREAK && header.classList.contains("cc-nav-open")) setNav(false);
    });
  }
})();
