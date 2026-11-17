/* calcofi.io brand v3 — header.js (2026-11-17). Contract: https://calcofi.io/brand/v3/

   Two jobs, for any page that wears the v3 header (brand/v3/header.css):

   1. THE WORDS. A product writes  <nav class="cc-links cc-nav" id="cc-nav" data-cc-nav aria-label="Sections"></nav>
      and this script draws the brand's words into it from nav.json beside this file — the ONE list
      (calcofi.io's _data/nav.yml), so every product's header reads the same. calcofi.io itself draws the same
      markup at build time from the same list, so its nav is there with JavaScript off; a nav that already has
      children is left as it is. A product may point somewhere else with data-cc-nav="<url of a nav.json>".

   2. THE BEHAVIOUR, by delegation, so it works on a header a framework mounts later:
      · a word with a menu is a <button class="cc-m2-t" aria-expanded>. The CSS opens its menu on hover; a press
        (click, tap, Enter, Space) opens it too, which is what a touch screen and a keyboard have. Escape closes
        it, even under the pointer, and puts focus back on the button. So do a press outside and focus leaving.
      · the menu button (.cc-menu-button) opens the words as one column: under NAV_BREAK (1100 px, the number
        in header.css), or at every width on a header with class cc-nav-menu. A press on a link closes the
        column, Escape closes it and returns focus to the button, and growing past the breakpoint closes it.
      · in the column the menus are inline and their buttons are headings: aria-expanded says "true".

   window.ccHeader = { version: "3", words: Promise<list>, render(nav, words) }.   No dependency. */
(function () {
  "use strict";
  var NAV_BREAK = 1100;   // = header.css @media (max-width: 1099px), and calcofi.io's scripts/check_layout.py
  var me = document.currentScript;
  var BASE = me && me.src ? me.src.replace(/[^/]*$/, "") : "https://calcofi.io/brand/v3/";

  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function header(el) { return el && el.closest ? el.closest(".cc-header") : null; }
  function column(h) { return !!h && (h.classList.contains("cc-nav-menu") || window.innerWidth < NAV_BREAK); }
  function menus(root) { return [].slice.call((root || document).querySelectorAll(".cc-header .cc-links .cc-m2")); }

  // ── 1 · the words ──
  var CAR = '<svg class="cc-car" viewBox="0 0 24 24" aria-hidden="true"><path d="M7 9l5 6 5-6z"/></svg>';
  function icons() { return !!document.querySelector('link[href*="icons.css"]'); }
  // a word's address as this page would resolve it, without query or fragment: nav.json holds full URLs on calcofi.io
  // and bare paths on a preview, and a string compare with location.href never matched the paths
  function abs(u) { try { return new URL(u, location.href).href.replace(/[?#].*$/, ""); } catch (e) { return u; } }
  function render(nav, words) {
    var withI = icons(), here = location.href.replace(/[?#].*$/, ""), h = "";
    (words || []).forEach(function (w) {
      if (w.menu) {
        var two = w.menu.length > 1;
        h += '<div class="cc-m2" data-word="' + esc(w.id) + '"><button type="button" class="cc-m2-t" aria-expanded="false" aria-controls="cc-dd-' + esc(w.id) + '">' + esc(w.title) + CAR + "</button>" +
          '<div class="cc-dd' + (two ? " cc-dd-2" : "") + (w.align === "right" ? " cc-dd-r" : "") + '" id="cc-dd-' + esc(w.id) + '">';
        w.menu.forEach(function (c) {
          if (two) h += "<div>" + (c.title ? "<h5>" + esc(c.title) + "</h5>" : "");
          c.items.forEach(function (i) {
            if (i.rule) { h += "<hr>"; return; }
            h += '<a href="' + esc(i.url) + '"' + (withI && i.icon ? "" : ' class="cc-dd-noi"') + ">" + (withI && i.icon ? '<i class="cc-i cc-i-' + esc(i.icon) + '" aria-hidden="true"></i>' : "") +
              "<span><b>" + esc(i.title) + "</b>" + (i.small ? "<small>" + esc(i.small) + "</small>" : "") + "</span></a>";
          });
          if (two) h += "</div>";
        });
        h += "</div></div>";
      } else {
        h += "<a" + (w.ext ? ' class="cc-ext"' : "") + ' data-word="' + esc(w.id) + '" href="' + esc(w.url) + '"' + (abs(w.url) === here ? ' aria-current="page"' : "") + ">" + esc(w.title) + "</a>";
      }
    });
    nav.innerHTML = h;
    nav.classList.add("cc-links", "cc-nav");
    sync();
  }
  var cache = {};
  function words(url) {
    url = url || BASE + "nav.json";
    return cache[url] || (cache[url] = fetch(url).then(function (r) { if (!r.ok) throw new Error("nav.json " + r.status); return r.json(); }).then(function (j) { return j.words || []; }));
  }
  function fill(nav) {
    if (!nav || nav.children.length || nav.getAttribute("data-cc-nav-state")) return;
    nav.setAttribute("data-cc-nav-state", "loading");
    var src = nav.getAttribute("data-cc-nav");
    words(src && src !== "true" ? src : null).then(function (w) { render(nav, w); nav.setAttribute("data-cc-nav-state", "ready"); })
      .catch(function (e) { nav.setAttribute("data-cc-nav-state", "failed"); if (window.console) console.warn("brand v3 header: the words could not be loaded", e); });
  }
  function fillAll() { [].forEach.call(document.querySelectorAll("nav[data-cc-nav]"), fill); }

  // ── 2 · the behaviour ──
  function setMenu(m, open) {
    var t = m.querySelector(".cc-m2-t");
    m.classList.toggle("open", open);
    if (t) t.setAttribute("aria-expanded", open || column(header(m)) ? "true" : "false");
  }
  function setNav(h, open) {
    var b = h.querySelector(".cc-menu-button");
    h.classList.toggle("cc-nav-open", open);
    if (b) { b.setAttribute("aria-expanded", open ? "true" : "false"); b.setAttribute("aria-label", open ? "Close the menu" : "Open the menu"); }
    sync();
  }
  // aria-expanded true to what is drawn, after anything that changes it (a resize, the column opening, a new nav)
  function sync() { menus().forEach(function (m) { setMenu(m, !column(header(m)) && m.classList.contains("open")); }); }

  document.addEventListener("click", function (e) {
    var t = e.target && e.target.closest ? e.target : null;
    if (!t) return;
    var burger = t.closest(".cc-header .cc-menu-button");
    if (burger) { var hb = header(burger); setNav(hb, !hb.classList.contains("cc-nav-open")); return; }
    var trig = t.closest(".cc-header .cc-m2-t"), all = menus();
    if (trig) {
      var m = trig.parentNode;
      if (column(header(m))) return;
      var open = !m.classList.contains("open");
      all.forEach(function (o) { if (o !== m) setMenu(o, false); });
      setMenu(m, open);
      m.classList.toggle("shut", !open);      // pressed shut under the pointer: stay shut until it leaves
      return;
    }
    all.forEach(function (o) { if (!o.contains(t)) setMenu(o, false); });
    // a line of a menu was followed: its menu shuts (it stayed open over whatever the line opened on the same page),
    // even under the pointer, and focus goes to the menu's word, not to a line that is now hidden
    var line = t.closest(".cc-header .cc-dd a"), lm = line && line.closest(".cc-m2");
    if (lm && !column(header(lm))) {
      setMenu(lm, false);
      if (lm.matches(":hover")) lm.classList.add("shut");
      var lt = lm.querySelector(".cc-m2-t"); if (lt) lt.focus();
    }
    var a = t.closest(".cc-header .cc-links a"), h = header(a);
    if (a && h && h.classList.contains("cc-nav-open")) setNav(h, false);
  });
  // hover says so on the button; leaving forgets a press-shut
  document.addEventListener("mouseover", function (e) {
    var m = e.target && e.target.closest ? e.target.closest(".cc-header .cc-m2") : null;
    if (!m || m.contains(e.relatedTarget) || column(header(m)) || m.classList.contains("shut")) return;
    var t = m.querySelector(".cc-m2-t"); if (t) t.setAttribute("aria-expanded", "true");
  });
  document.addEventListener("mouseout", function (e) {
    var m = e.target && e.target.closest ? e.target.closest(".cc-header .cc-m2") : null;
    if (!m || m.contains(e.relatedTarget)) return;
    m.classList.remove("shut");
    var t = m.querySelector(".cc-m2-t");
    if (t && !column(header(m))) t.setAttribute("aria-expanded", m.classList.contains("open") ? "true" : "false");
  });
  document.addEventListener("focusout", function (e) {
    var m = e.target && e.target.closest ? e.target.closest(".cc-header .cc-m2") : null;
    if (m && !m.contains(e.relatedTarget) && !column(header(m))) setMenu(m, false);
  });
  document.addEventListener("keydown", function (e) {
    if (e.key !== "Escape") return;
    var done = false;
    menus().forEach(function (m) {
      if (column(header(m))) return;
      var shown = m.classList.contains("open") || m.matches(":hover");
      if (!shown) return;
      var had = m.contains(document.activeElement), t = m.querySelector(".cc-m2-t");
      setMenu(m, false);
      if (m.matches(":hover")) m.classList.add("shut");
      if (had && t) t.focus();
      done = true;
    });
    if (done) return;
    [].forEach.call(document.querySelectorAll(".cc-header.cc-nav-open"), function (h) {
      setNav(h, false);
      var b = h.querySelector(".cc-menu-button"); if (b) b.focus();
    });
  });
  window.addEventListener("resize", function () {
    [].forEach.call(document.querySelectorAll(".cc-header.cc-nav-open"), function (h) { if (!column(h)) setNav(h, false); });
    sync();
  });

  function start() {
    fillAll(); sync();
    // a header a framework mounts later (React, Shiny): draw its words when it appears
    if (window.MutationObserver) new MutationObserver(function () { fillAll(); }).observe(document.documentElement, { childList: true, subtree: true });
  }
  window.ccHeader = { version: "3", words: words, render: render, navBreak: NAV_BREAK };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start); else start();
})();
