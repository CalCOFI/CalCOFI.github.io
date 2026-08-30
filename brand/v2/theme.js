/* calcofi.io brand — theme.js (v2)
   Contract: https://calcofi.io/brand/v2/

   Resolves the theme, applies it to every attribute a framework on the page might key on, persists an
   EXPLICIT choice across *.calcofi.io, wires the toggle, and tells the page (maps, plots, diagrams) when
   it changes. v1's mechanics with the default flipped and one persistence rule added.

   Resolution:  ?theme=dark|light  →  cookie cc_theme (Domain=.calcofi.io), honoured only beside the
                marker cookie cc_theme_src=user  →  localStorage cc_theme (v2's own key)  →  "light".
   Persists:    ONLY from the toggle, ccTheme.set() or a ?theme= link — never the resolved default. v1
                wrote its resolved theme on every load, so a v1 page seen first would stamp cc_theme=dark
                from v1's default and every v2 page would open dark. The marker is what a v2 page trusts;
                a v1 toggle (which lacks it) is lost across the boundary while the two coexist.
   Applies:     <html data-theme>          (ours; theme.css keys on it)
                <html data-bs-theme>       (Bootstrap 5.3 / bslib / pkgdown / Quarto)
                <html data-md-color-scheme> (mkdocs-material: slate | default)
                color-scheme
                <html data-cc-scale>       from <meta name="cc-scale" content="app">, if the snippet did not
   Notifies:    document event "cc:theme"  detail: {theme, version: "2"}
   API:         window.ccTheme.get() / .set(t) / .toggle() / .version === "2"
   Toggle:      any click on .cc-theme-toggle, [data-cc-theme-toggle] or #theme-toggle; a .cc-theme-toggle's
                🌓 fallback is swapped for the sun / moon-in-sun icons (iconize) and its title says what a click does

   Load it with <script defer>; put head.html's inline snippet in <head> so the first paint is already the
   right colour. */
(function () {
  "use strict";
  var COOKIE = "cc_theme", MARKER = "cc_theme_src", KEY = "cc_theme", KEY_SRC = "cc_theme_src", DEFAULT = "light";
  var root = document.documentElement;

  function fromUrl() {
    var m = /[?&]theme=(dark|light)\b/.exec(location.search);
    return m ? m[1] : null;
  }
  function fromCookie() {
    if (!new RegExp("(?:^|;\\s*)" + MARKER + "=user\\b").test(document.cookie)) return null;
    var m = new RegExp("(?:^|;\\s*)" + COOKIE + "=(dark|light)\\b").exec(document.cookie);
    return m ? m[1] : null;
  }
  function fromStorage() {
    try {
      if (localStorage.getItem(KEY_SRC) !== "user") return null;
      var v = localStorage.getItem(KEY); return v === "dark" || v === "light" ? v : null;
    } catch (e) { return null; }
  }
  function resolve() { return fromUrl() || fromCookie() || fromStorage() || DEFAULT; }

  function persist(t) {
    try { localStorage.setItem(KEY, t); localStorage.setItem(KEY_SRC, "user"); } catch (e) {}
    var h = location.hostname;
    var domain = (h === "calcofi.io" || /\.calcofi\.io$/.test(h)) ? "; Domain=.calcofi.io" : "";
    var tail = domain + "; Path=/; Max-Age=31536000; SameSite=Lax" + (location.protocol === "https:" ? "; Secure" : "");
    document.cookie = COOKIE + "=" + t + tail;
    document.cookie = MARKER + "=user" + tail;
  }
  function scale() {
    if (root.hasAttribute("data-cc-scale")) return;
    var m = document.querySelector('meta[name="cc-scale"]');
    if (m && m.content) root.setAttribute("data-cc-scale", m.content);
  }
  function apply(t) {
    root.dataset.theme = t;
    root.setAttribute("data-bs-theme", t);
    root.setAttribute("data-md-color-scheme", t === "dark" ? "slate" : "default");
    root.style.colorScheme = t;
  }
  function get() { return root.dataset.theme === "dark" ? "dark" : "light"; }
  function set(t) {
    t = t === "dark" ? "dark" : "light";
    apply(t); persist(t);
    iconize();
    document.dispatchEvent(new CustomEvent("cc:theme", { detail: { theme: t, version: "2" } }));
    return t;
  }
  function toggle() { return set(get() === "dark" ? "light" : "dark"); }

  // the toggle's icon is what a click switches TO: the sun while dark, the moon-in-sun while light
  // (Material Design Icons brightness-7 / brightness-4, Apache-2.0). The markup keeps 🌓 as its no-JS
  // fallback; this swaps it for the two <svg>s and theme.css shows one per theme. A page that renders the
  // <svg>s itself (a React shell) is left alone: only the title is refreshed.
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
  scale();
  if (fromUrl()) persist(t);   // a ?theme= link is an explicit choice (v1 Decision 2); the default is not
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", iconize); else iconize();

  document.addEventListener("click", function (e) {
    var el = e.target && e.target.closest &&
      e.target.closest(".cc-theme-toggle, [data-cc-theme-toggle], #theme-toggle");
    if (el) { e.preventDefault(); toggle(); }
  });

  window.ccTheme = { get: get, set: set, toggle: toggle, iconize: iconize, resolve: resolve, version: "2", brand: "v2" };
})();
