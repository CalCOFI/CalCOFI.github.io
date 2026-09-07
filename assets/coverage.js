/* assets/coverage.js — the hover / tap card over a dataset page's two figures (2026-09-07):
   the observations-per-year bars (year · n) and the extent map's sampled stations (station · n ·
   the years it was sampled · obs per sampled year). Hover on a pointer, tap on a phone (a second
   tap or a tap elsewhere closes it), focus + arrow keys on the map's stations. Plain JS; without it
   the SVG <title>s still answer a hover. */
(function () {
  "use strict";
  var num = function (n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ","); };
  function card(host) {
    var t = host.querySelector(".ds-tip");
    if (!t) { t = document.createElement("div"); t.className = "ds-tip"; t.hidden = true; host.appendChild(t); }
    return t;
  }
  function place(tip, host, el) {
    var r = el.getBoundingClientRect(), h = host.getBoundingClientRect();
    var x = r.left - h.left + r.width / 2, y = r.top - h.top;
    tip.hidden = false;
    var w = tip.offsetWidth, hh = tip.offsetHeight;
    x = Math.max(4, Math.min(h.width - w - 4, x - w / 2));
    tip.style.left = x + "px";
    tip.style.top = Math.max(0, y - hh - 8) + "px";
  }
  function wire(host, sel, text) {
    var tip = card(host), on = null;
    function show(el) {
      if (on) on.classList.remove("is-on");
      on = el; el.classList.add("is-on");
      tip.innerHTML = text(el); place(tip, host, el);
    }
    function hide() { if (on) on.classList.remove("is-on"); on = null; tip.hidden = true; }
    host.addEventListener("pointerover", function (e) {
      var el = e.target.closest(sel); if (el && e.pointerType !== "touch") show(el);
    });
    host.addEventListener("pointerout", function (e) {
      if (e.pointerType !== "touch" && e.target.closest(sel)) hide();
    });
    host.addEventListener("click", function (e) {
      var el = e.target.closest(sel);
      if (!el) return hide();
      if (on === el) hide(); else show(el);
    });
    host.addEventListener("focusin", function (e) { var el = e.target.closest(sel); if (el) show(el); });
    host.addEventListener("focusout", hide);
    document.addEventListener("click", function (e) { if (!host.contains(e.target)) hide(); });
  }
  var fig = document.querySelector(".ds-spark-fig");
  if (fig) wire(fig, "rect[data-year]", function (el) {
    return "<b>" + el.dataset.year + "</b> · " + num(el.dataset.n) + " obs";
  });
  var map = document.querySelector(".ds-mapwrap");
  if (map) wire(map, ".st-on[data-key]", function (el) {
    var d = el.dataset, per = d.nyr > 0 ? Math.round(d.n / d.nyr) : d.n;
    return "<b>" + d.key + "</b> · " + num(d.n) + " obs<br>" + d.ymin + "–" + d.ymax + " · " +
           d.nyr + " year" + (d.nyr === "1" ? "" : "s") + " sampled · " + num(per) + " obs / year";
  });
})();
