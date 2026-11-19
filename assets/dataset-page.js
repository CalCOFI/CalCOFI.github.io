/* The dataset page (_includes/dataset_page.html; Betty 2026-11-15): the rest of the description,
   finding a species in the list, showing all of it, the CSV buttons beside each species or measurement
   (assets/download-form.js), and copying the citation. The whole-dataset button is main's Download link
   and dialog (assets/download.js). */
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
  var more = document.querySelector("[data-more]"), rest = document.getElementById("dp-rest");
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
        '<button type="button" class="dp-csv" data-one="bio" data-k="' + esc(t[0]) + '" data-name="' + esc(name) + '" data-n="' + t[5] + '" aria-label="CSV of ' + esc(name) + '" title="Download just ' + esc(name) + ', from this dataset"><i class="cc-i cc-i-ui-download" aria-hidden="true"></i>CSV</button></div>';
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
  // the measurement list: 8 at first, all on request (rows and their category heads carry data-extra)
  var allM = root.querySelector("[data-all-m]");
  if (allM) allM.addEventListener("click", function () {
    var open = allM.getAttribute("aria-expanded") !== "true", tot = allM.getAttribute("data-n");
    [].forEach.call(root.querySelectorAll(".dp-m [data-extra]"), function (el) { el.hidden = !open; });
    allM.setAttribute("aria-expanded", open ? "true" : "false");
    allM.textContent = open ? "Show fewer" : "Show all " + tot;
    var sh = root.querySelector("[data-shown-m]"); if (sh) sh.textContent = open ? "All " + tot : "8 of " + tot;
  });
  var allBtn = root.querySelector("[data-all]");
  if (allBtn) allBtn.addEventListener("click", function () { all = !all; filter(); });

  root.addEventListener("click", function (e) {
    var b = e.target.closest && e.target.closest("button");
    if (!b) return;
    // just one species or measurement, from this dataset (the Query Builder picks it and downloads). The form
    // counts records, so the link asks the builder for one row per sample at every station (&rows=sample&stations=all);
    // the builder's own default is a yearly mean per standard station, which is not what "73k records" promises
    if (b.hasAttribute("data-one") && window.CCDownload) {
      var bio = b.getAttribute("data-one") === "bio", k = b.getAttribute("data-k");
      var y0 = bio ? D.y0 : +b.getAttribute("data-y0") || D.y0, y1 = bio ? D.y1 : +b.getAttribute("data-y1") || D.y1;
      CCDownload.open({ name: b.getAttribute("data-name"), unit: bio ? "records" : "values", kind: bio ? "species" : "measurement",
        files: files(), ds: [[D.key, y0, y1, +b.getAttribute("data-n")]], dsKey: D.key, start: "just", base: root.getAttribute("data-base") || "",
        pick: function () { return BUILDER ? BUILDER + "?pick=" + encodeURIComponent((bio ? "bio:" : "env:") + D.key + ":" + k) + "&rows=sample&stations=all&download=1" : null; } });
    }
    // copy the citation or the BibTeX
    if (b.hasAttribute("data-copy")) {
      var t = b.getAttribute("data-copy");
      (navigator.clipboard ? navigator.clipboard.writeText(t) : Promise.reject()).then(function () { toast("Copied"); }, function () { toast("Could not copy; select the text instead"); });
    }
  });
})();

// the hero's Download button opens the same dialog as the side card's (#dl-btn; assets/download.js), and
// "In code" opens the Every endpoint fold it points to
(function () {
  "use strict";
  document.addEventListener("click", function (e) {
    var t = e.target.closest && e.target.closest("[data-dl-open], [data-open-fold]");
    if (!t) return;
    if (t.hasAttribute("data-dl-open")) { var b = document.getElementById("dl-btn"); if (b) { e.preventDefault(); b.click(); } return; }
    var f = document.querySelector(t.getAttribute("href"));
    if (f && f.tagName === "DETAILS") f.open = true;
  });
})();

// Field list (CSV): every row of the field tables (the shown ones and the "Show more" ones) as one CSV —
// file, field, units, description. Drawn hidden, shown here, so it never sits there doing nothing without JavaScript.
(function () {
  "use strict";
  var b = document.querySelector("[data-fields-csv]");
  if (!b) return;
  b.hidden = false;
  var q = function (v) { v = String(v == null ? "" : v).trim(); return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; };
  b.addEventListener("click", function () {
    var lines = ["file,field,units,description"];
    document.querySelectorAll("#fields .dp-ft tbody tr").forEach(function (tr) {
      var td = tr.children;
      lines.push([tr.getAttribute("data-f"), td[1].textContent, td[2].textContent, td[3].textContent].map(q).join(","));
    });
    var name = (location.pathname.replace(/\/+$/, "").split("/").pop() || "dataset").replace(/\.html$/, "");
    var a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([lines.join("\r\n") + "\r\n"], { type: "text/csv" }));
    a.download = name + "_fields.csv";
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
  });
})();
