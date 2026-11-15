/* The dataset page (_includes/dataset_page.html; Betty 2026-11-15): the rest of the description,
   finding a species in the list, showing all of it, the CSV buttons and the whole-dataset download
   (both through assets/download.js), and copying the citation. */
(function () {
  "use strict";
  var root = document.getElementById("dp");
  if (!root) return;
  var D = {};
  try { D = JSON.parse(document.getElementById("dp-dl").textContent); } catch (e) { /* no download form then */ }
  var BUILDER = root.getAttribute("data-builder");
  var all = false;

  function toast(t) {
    var el = document.createElement("div"); el.className = "dp-toast"; el.setAttribute("role", "status"); el.textContent = t;
    document.body.appendChild(el); setTimeout(function () { el.remove(); }, 1600);
  }
  function files() { var f = {}; f[D.key] = D.file || {}; return f; }

  // the rest of the record's description
  var more = root.querySelector("[data-more]"), rest = document.getElementById("dp-rest");
  if (more && rest) more.addEventListener("click", function () {
    rest.hidden = !rest.hidden;
    more.setAttribute("aria-expanded", rest.hidden ? "false" : "true");
    more.textContent = rest.hidden ? "More about the record" : "Less";
  });

  // the species list: 8 at first, all on request, or the ones a search finds
  var list = root.querySelector("[data-list]"), find = root.querySelector("[data-find]"), extra = null;
  function esc(x) { return String(x == null ? "" : x).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  // past the first 50 the rows are JSON ([k, sci, com, rank, n, n_raw, url, sil, pct]); drawn once, when needed
  function drawRest() {
    if (extra || !list) return;
    var src = list.querySelector("[data-more-rows]"); extra = true;
    if (!src) return;
    var base = root.getAttribute("data-base") || "", h = "";
    JSON.parse(src.textContent).forEach(function (t) {
      var nm = t[2] ? "<b>" + esc(t[2]) + "</b><span><i>" + esc(t[1]) + "</i></span>" : "<b><i>" + esc(t[1]) + "</i></b>" + (t[3] ? "<span>" + esc(t[3]) + "</span>" : "");
      var name = t[2] || t[1];
      h += '<div class="dp-tr" data-q="' + esc((t[1] + " " + (t[2] || "")).toLowerCase()) + '" data-extra hidden><span>' + (t[7] ? '<svg class="dp-si" aria-hidden="true"><use href="#' + esc(t[7]) + '"/></svg>' : "") + "</span>" +
        '<span class="dp-nm">' + (t[6] ? '<a href="' + esc(base + t[6]) + '">' + nm + "</a>" : nm) + '</span><span class="dp-nb">' + esc(t[4]) + ' records<span class="dp-bar"><i style="width:' + t[8] + '%"></i></span></span>' +
        '<button type="button" class="dp-csv" data-one="bio" data-k="' + esc(t[0]) + '" data-name="' + esc(name) + '" data-n="' + t[5] + '" title="Download just ' + esc(name) + ', from this dataset"><i class="cc-i cc-i-ui-download" aria-hidden="true"></i>CSV</button></div>';
    });
    src.insertAdjacentHTML("beforebegin", h);
  }
  function filter() {
    if (!list) return;
    if (all || (find && find.value.trim())) drawRest();
    var q = find ? find.value.trim().toLowerCase() : "", n = 0, i = 0;
    [].forEach.call(list.querySelectorAll(".dp-tr[data-q]"), function (row) {
      i++;
      var show = q ? row.getAttribute("data-q").indexOf(q) >= 0 : (all || i <= 8);
      row.hidden = !show; if (show) n++;
    });
    var none = list.querySelector("[data-none]"); if (none) none.hidden = n > 0;
    var bar = list.querySelector(".dp-more"); if (bar) bar.hidden = !!q;
    var shown = list.querySelector("[data-shown]"), btn = list.querySelector("[data-all]");
    if (shown && btn) { var tot = btn.getAttribute("data-n"); shown.textContent = all ? "All " + tot : "8 of " + tot; btn.textContent = all ? "Show fewer" : "Show all " + tot; }
  }
  if (find) find.addEventListener("input", filter);
  var allBtn = root.querySelector("[data-all]");
  if (allBtn) allBtn.addEventListener("click", function () { all = !all; filter(); });

  root.addEventListener("click", function (e) {
    var b = e.target.closest && e.target.closest("button");
    if (!b) return;
    // the whole dataset: the form offers CSV, Parquet or NetCDF
    if (b.hasAttribute("data-all-dl") && window.CCDownload) {
      CCDownload.open({ name: D.name, kind: "dataset", files: files(), ds: [[D.key, D.y0, D.y1, D.n]], dsKey: D.key });
    }
    // just one species or measurement, from this dataset (the Query Builder picks it and downloads)
    if (b.hasAttribute("data-one") && window.CCDownload) {
      var bio = b.getAttribute("data-one") === "bio", k = b.getAttribute("data-k");
      var y0 = bio ? D.y0 : +b.getAttribute("data-y0") || D.y0, y1 = bio ? D.y1 : +b.getAttribute("data-y1") || D.y1;
      CCDownload.open({ name: b.getAttribute("data-name"), unit: bio ? "records" : "values", kind: bio ? "species" : "measurement",
        files: files(), ds: [[D.key, y0, y1, +b.getAttribute("data-n")]], dsKey: D.key, start: "just",
        pick: function () { return BUILDER ? BUILDER + "?pick=" + encodeURIComponent((bio ? "bio:" : "env:") + D.key + ":" + k) + "&download=1" : null; } });
    }
    // copy the citation or the BibTeX
    if (b.hasAttribute("data-copy")) {
      var t = b.getAttribute("data-copy");
      (navigator.clipboard ? navigator.clipboard.writeText(t) : Promise.reject()).then(function () { toast("Copied"); }, function () { toast("Could not copy; select the text instead"); });
    }
  });
})();
