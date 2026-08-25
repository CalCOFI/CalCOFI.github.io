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
   Toggle:      any click on .cc-theme-toggle, [data-cc-theme-toggle] or #theme-toggle

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
    document.dispatchEvent(new CustomEvent("cc:theme", { detail: { theme: t } }));
    return t;
  }
  function toggle() { return set(get() === "dark" ? "light" : "dark"); }

  var t = resolve();
  apply(t);
  persist(t);   // migrates a localStorage-only choice onto the cross-subdomain cookie

  document.addEventListener("click", function (e) {
    var el = e.target && e.target.closest &&
      e.target.closest(".cc-theme-toggle, [data-cc-theme-toggle], #theme-toggle");
    if (el) { e.preventDefault(); toggle(); }
  });

  window.ccTheme = { get: get, set: set, toggle: toggle, resolve: resolve, version: "1" };
})();
