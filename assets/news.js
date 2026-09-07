/* assets/news.js — the /news/ type filter (plan 2026-09-07 § D-5). The chips are buttons; a click
   shows the rows of that type and hides the rest with `el.hidden` — which works only because the
   `[hidden] { display: none !important }` rule is the FIRST rule in style.css (the log rows are
   grid items with their own display). No dependency; the tile needs none of this. */
(function () {
  'use strict';
  var bar = document.getElementById('log-filter'), list = document.getElementById('log-all');
  if (!bar || !list) return;
  var chips = Array.prototype.slice.call(bar.querySelectorAll('[data-f]'));
  var rows = Array.prototype.slice.call(list.querySelectorAll('[data-t]'));
  function apply(f) {
    chips.forEach(function (c) {
      var on = c.getAttribute('data-f') === f;
      c.classList.toggle('on', on);
      c.classList.toggle('cc-chip-accent', on);
      c.classList.toggle('cc-chip-quiet', !on);
      c.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    rows.forEach(function (r) { r.hidden = !(f === 'all' || r.getAttribute('data-t') === f); });
    try { history.replaceState(null, '', f === 'all' ? location.pathname : '?type=' + f); } catch (e) {}
  }
  chips.forEach(function (c) { c.addEventListener('click', function () { apply(c.getAttribute('data-f')); }); });
  var m = /[?&]type=(\w+)/.exec(location.search);
  if (m && chips.some(function (c) { return c.getAttribute('data-f') === m[1]; })) apply(m[1]);
})();
