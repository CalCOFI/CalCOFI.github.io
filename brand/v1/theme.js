/* calcofi.io brand — theme.js (v1)
   Contract: https://calcofi.io/brand/v1/

   Resolves the theme, applies it to every attribute a framework on the page
   might key on, persists it across *.calcofi.io, wires the toggle, and tells
   the page (maps, plots, diagrams) when it changes.

   Resolution:  ?theme=dark|light  →  cookie cc_theme (Domain=.calcofi.io)
                →  localStorage.theme  →  "dark".
   Applies:     <html data-theme>          (ours; theme.css keys on it)
                <html data-bs-theme>       (Bootstrap 5.3 / bslib / pkgdown / Quarto)
                <html data-md-color-scheme> (mkdocs-material: slate | default)
                color-scheme
   Notifies:    document event "cc:theme"  detail: {theme}
   API:         window.ccTheme.get() / .set(t) / .toggle()
   Toggle:      any click on .cc-theme-toggle, [data-cc-theme-toggle] or #theme-toggle;
                a .cc-theme-toggle's 🌓 fallback is swapped for the sun / moon-in-sun
                icons (iconize) and its title says what a click does

   Load it with <script defer>; put head.html's inline snippet in <head> so the
   first paint is already the right colour. */
(function () {
  "use strict";
  var KEY = "theme", COOKIE = "cc_theme";
  var root = document.documentElement;

  function fromUrl() {
    var m = /[?&]theme=(dark|light)\b/.exec(location.search);
    return m ? m[1] : null;
  }
  function fromCookie() {
    var m = new RegExp("(?:^|;\\s*)" + COOKIE + "=(dark|light)").exec(document.cookie);
    return m ? m[1] : null;
  }
  function fromStorage() {
    try { var v = localStorage.getItem(KEY); return v === "dark" || v === "light" ? v : null; }
    catch (e) { return null; }
  }
  function resolve() { return fromUrl() || fromCookie() || fromStorage() || "dark"; }

  function persist(t) {
    try { localStorage.setItem(KEY, t); } catch (e) {}
    var h = location.hostname;
    var domain = (h === "calcofi.io" || /\.calcofi\.io$/.test(h)) ? "; Domain=.calcofi.io" : "";
    var secure = location.protocol === "https:" ? "; Secure" : "";
    document.cookie = COOKIE + "=" + t + domain + "; Path=/; Max-Age=31536000; SameSite=Lax" + secure;
  }
  function apply(t) {
    root.dataset.theme = t;
    root.setAttribute("data-bs-theme", t);
    root.setAttribute("data-md-color-scheme", t === "dark" ? "slate" : "default");
    root.style.colorScheme = t;
  }
  function get() { return root.dataset.theme === "light" ? "light" : "dark"; }
  function set(t) {
    t = t === "light" ? "light" : "dark";
    apply(t); persist(t);
    iconize();
    document.dispatchEvent(new CustomEvent("cc:theme", { detail: { theme: t } }));
    return t;
  }
  function toggle() { return set(get() === "dark" ? "light" : "dark"); }

  // the toggle's icon is what a click switches TO: the sun while dark, the moon-in-sun
  // while light (Material Design Icons brightness-7 / brightness-4, Apache-2.0 — the
  // mkdocs-material pair, adopted 2026-08-29 from calcofi4py). The markup keeps 🌓 as its
  // no-JS fallback; this swaps it for the two <svg>s and theme.css shows one per theme.
  // A page that renders the <svg>s itself (a React shell) is left alone: only the title
  // is refreshed, so the framework keeps owning its nodes.
  var SUN  = "M12 8a4 4 0 0 0-4 4 4 4 0 0 0 4 4 4 4 0 0 0 4-4 4 4 0 0 0-4-4m0 10a6 6 0 0 1-6-6 6 6 0 0 1 6-6 6 6 0 0 1 6 6 6 6 0 0 1-6 6m8-9.31V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69L23.31 12z";
  var MOON = "M12 18c-.89 0-1.74-.2-2.5-.55C11.56 16.5 13 14.42 13 12s-1.44-4.5-3.5-5.45C10.26 6.2 11.11 6 12 6a6 6 0 0 1 6 6 6 6 0 0 1-6 6m8-9.31V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69L23.31 12z";
  function svg(cls, d) {
    return '<svg class="cc-theme-icon ' + cls + '" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="' + d + '"></path></svg>';
  }
  function iconize() {
    var els = document.querySelectorAll(".cc-theme-toggle");
    var title = get() === "dark" ? "Switch to light theme" : "Switch to dark theme";
    for (var i = 0; i < els.length; i++) {
      if (!els[i].querySelector(".cc-theme-icon")) els[i].innerHTML = svg("cc-icon-sun", SUN) + svg("cc-icon-moon", MOON);
      els[i].title = title;
    }
  }

  var t = resolve();
  apply(t);
  persist(t);   // migrates a localStorage-only choice onto the cross-subdomain cookie
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", iconize); else iconize();

  document.addEventListener("click", function (e) {
    var el = e.target && e.target.closest &&
      e.target.closest(".cc-theme-toggle, [data-cc-theme-toggle], #theme-toggle");
    if (el) { e.preventDefault(); toggle(); }
  });

  window.ccTheme = { get: get, set: set, toggle: toggle, iconize: iconize, resolve: resolve, version: "1" };
})();
