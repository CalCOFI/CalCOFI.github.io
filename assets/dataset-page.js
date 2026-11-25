/* The dataset page (_includes/dataset_page.html; Betty 2026-11-15): the rest of the description,
   finding a species in the list, showing all of it, the CSV buttons beside each species or measurement
   (assets/download-form.js), the Species · Measurements · Fields tabs' anchors, and copying the citation. The whole-dataset button is main's Download link
   and dialog (assets/download.js). */
(function () {
  "use strict";
  var root = document.getElementById("dp");
  if (!root) return;
  var D = {};
  try { D = JSON.parse(document.getElementById("dp-dl").textContent); } catch (e) { /* no download form then */ }
  // links that leave the site open in a new tab, including those inside the record's own text (Betty 2026-11-20)
  Array.prototype.forEach.call(root.querySelectorAll("a[href]"), function (a) {
    if (/^https?:$/.test(a.protocol) && a.host !== location.host && !a.hasAttribute("download") && !a.target) { a.target = "_blank"; a.rel = "noopener"; }
  });
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

// "In code" opens the Every endpoint fold it points to. (The hero's own Download button is gone: the side card's
// #dl-btn is the page's one Download; PR 57 review.)
(function () {
  "use strict";
  document.addEventListener("click", function (e) {
    var t = e.target.closest && e.target.closest("[data-open-fold]");
    if (!t) return;
    var f = document.querySelector(t.getAttribute("href"));
    if (f && f.tagName === "DETAILS") f.open = true;
    // and on the tab the link is about ("In code" lands on Code, not on Explore) (Betty 2026-11-21)
    var tab = t.getAttribute("data-fold-tab"), tb = tab && document.getElementById("access-tab-" + tab);
    if (tb) tb.click();
  });
})();

// Species · Measurements · Fields is one tabset (assets/tabs.js). The panels keep the page's anchors (#taxa, #variables,
// #fields): arriving on one, or following a link to one, selects its tab first, so the anchor never lands on a hidden panel.
(function () {
  "use strict";
  var set = document.getElementById("ts-dp-lists");
  if (!set) return;
  function show(hash, scroll) {
    var id = String(hash || "").replace(/^#/, "");
    var el = id && document.getElementById(id), panel = el && el.closest && el.closest(".tabpanel");
    if (!panel || !set.contains(panel)) return;
    var tab = set.querySelector('.tabrow > button[data-tab="' + panel.getAttribute("data-panel") + '"]');
    if (tab && tab.getAttribute("aria-selected") !== "true") tab.click();
    if (scroll) set.scrollIntoView({ block: "start" });
  }
  show(location.hash, !!location.hash);
  window.addEventListener("hashchange", function () { show(location.hash, true); });
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest('a[href^="#"]');
    if (a) show(a.getAttribute("href"), false);
  });
})();

// Field list (CSV): every row of the field tables (the shown ones and the "Show more" ones) as one CSV —
// file, field, units, description (units only: the page's "format" text, such as UTC, is not a unit). Drawn hidden, shown here, so it never sits there doing nothing without JavaScript.
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
      lines.push([tr.getAttribute("data-f"), td[1].textContent, td[2].getAttribute("data-u"), td[3].textContent].map(q).join(","));
    });
    var name = (location.pathname.replace(/\/+$/, "").split("/").pop() || "dataset").replace(/\.html$/, "");
    var a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([lines.join("\r\n") + "\r\n"], { type: "text/csv" }));
    a.download = name + "_fields.csv";
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
  });
})();

// Measurements and Fields: the first eight rows show, the rest ([data-rest]) fold behind one button at the END of the table.
// The same pair of words on every list of the page, the species list's too: "Show all N" / "Show fewer" (PR 57 review).
// Closing brings the top of the list back into view. The button is drawn hidden and shown here; without JavaScript every row shows.
(function () {
  "use strict";
  [].forEach.call(document.querySelectorAll("[data-show-all]"), function (b) {
    var panel = b.closest(".dp-panel"); if (!panel) return;
    var rows = panel.querySelectorAll("tr[data-rest]"), n = b.getAttribute("data-n");
    function set(open) {
      [].forEach.call(rows, function (r) { r.hidden = !open; });
      b.setAttribute("aria-expanded", open ? "true" : "false");
      b.textContent = open ? "Show fewer" : "Show all " + n;
    }
    set(false); b.hidden = false;
    b.addEventListener("click", function () {
      var open = b.getAttribute("aria-expanded") !== "true"; set(open);
      if (!open && panel.getBoundingClientRect().top < 0) panel.scrollIntoView({ block: "start" });
    });
  });
})();

// "Measurement list (CSV)" writes every row, shown or folded: measurement_type, units, description (the columns of the
// release's measurement_type.csv). Drawn hidden and shown here, so it never sits there doing nothing without JavaScript.
(function () {
  "use strict";
  var sec = document.getElementById("variables");
  if (!sec) return;
  var rows = sec.querySelectorAll("tbody tr"), csv = sec.querySelector("[data-meas-csv]");
  if (csv) {
    csv.hidden = false;
    var q = function (v) { v = String(v == null ? "" : v).trim(); return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; };
    csv.addEventListener("click", function () {
      var lines = ["measurement_type,units,description"];
      [].forEach.call(rows, function (tr) { var td = tr.children; lines.push([tr.getAttribute("data-k"), td[1].textContent, td[2].textContent].map(q).join(",")); });
      var name = (location.pathname.replace(/\/+$/, "").split("/").pop() || "dataset").replace(/\.html$/, "");
      var a = document.createElement("a");
      a.href = URL.createObjectURL(new Blob([lines.join("\r\n") + "\r\n"], { type: "text/csv" }));
      a.download = name + "_measurements.csv";
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
    });
  }
})();
