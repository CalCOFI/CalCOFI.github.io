/* assets/download-form.js — the download form beside one species or one measurement (Betty 2026-11-15;
   named download.js on front-door-v2 — main's dataset-page Download dialog holds that name).

   Nothing downloads without saying what it is. Two choices:
     · Just this species or measurement, from ONE dataset (methods differ — eDNA reads, pumped eggs and
       net tows are not one table): the Query Builder opens with it picked and downloads the CSV
       (explore/builder.html?pick=…&download=1).
     · The whole dataset, as CalCOFI publishes it: the release's zip (main 3add72f, _plugins/downloads.rb:
       CSV tables with how to cite and the licence inside), and a link to the dataset page's Download
       dialog for Excel, Parquet and the rest. Reconciled 2026-11-17: this was a CSV built in the browser
       from the release Parquet (a vendored reader, files up to 30 MB) or ERDDAP's form; the zip is the
       one whole-dataset download on the site, so neither is needed here.

   CCDownload.open(opts) draws the form.
   opts: { name, unit, kind: "species" | "measurement", ds: [[key, y0, y1, n], …],
           files: { key: { name, page, zip: { url, file, what } } },   // zip absent: no zips for it yet
           pick: function (key) → builder URL or null, start: "just" | "whole", dsKey, base }          */
(function () {
  "use strict";
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function big(x) { if (!x) return "0"; if (x >= 1e6) return (x / 1e6).toFixed(1) + "M"; if (x >= 1e4) return Math.round(x / 1e3) + "k"; return Number(x).toLocaleString("en-US"); }
  function yrs(a, b) { return a ? (a === b ? "" + a : a + "–" + b) : ""; }

  var dlg = null, last = null;
  function host() {
    if (dlg) return dlg;
    dlg = document.createElement("div"); dlg.className = "ccd"; dlg.hidden = true; document.body.appendChild(dlg);
    dlg.addEventListener("click", function (e) { if (e.target === dlg) close(); });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape" && !dlg.hidden) close(); });
    return dlg;
  }
  function close() { dlg.hidden = true; if (last) last.focus(); }

  function open(o) {
    host(); last = document.activeElement;
    var st = { what: o.start || "just", ds: o.dsKey || (o.ds[0] && o.ds[0][0]) };
    function f() { return o.files[st.ds] || {}; }
    function sel(name, opts) {
      return '<select name="' + name + '" aria-label="Dataset">' + opts.map(function (p) { return '<option value="' + esc(p[0]) + '"' + (st[name] === p[0] ? " selected" : "") + ">" + esc(p[1]) + "</option>"; }).join("") + "</select>";
    }
    // where the dataset page's own Download dialog opens: #download there (assets/download.js)
    function pageDl(x) { return x.page ? (o.base || "") + x.page + "#download" : null; }
    function plan() {
      var d = o.ds.filter(function (z) { return z[0] === st.ds; })[0] || [st.ds], x = f(), nm = x.name || st.ds;
      if (st.what === "just") {
        var u = o.pick && o.pick(st.ds);
        return { text: "<b>" + esc(o.name) + "</b> only, from <b>" + esc(nm) + "</b>" + (d[1] ? " (" + yrs(d[1], d[2]) + ", " + big(d[3]) + " " + o.unit + ")" : "") + ", as a CSV.",
                 note: "The Query Builder opens with it picked and downloads the CSV. You can then change the rows or years and download again.",
                 go: u ? { label: "Download CSV", href: u, tab: true } : null };
      }
      var what = "The whole <b>" + esc(nm) + "</b> dataset, as CalCOFI publishes it, including every " + (o.kind === "species" ? "species" : "measurement") + " in it, ";
      if (x.zip && x.zip.url) return { text: what + "as one zip.", note: "CSV tables that open in Excel, R or Python, with a readme, how to cite and the licence inside.",
                                       go: { label: "Download " + x.zip.what, href: x.zip.url, file: x.zip.file || "" }, more: pageDl(x) };
      return { text: what + "from its own page.", note: "No zip is published for this dataset yet; its page lists every way to get it.",
               go: x.page ? { label: "Open the dataset page", href: (o.base || "") + x.page } : null };
    }
    function draw() {
      var p = plan();
      var dsOpts = o.ds.map(function (d) { var y = st.what === "just" && d[1] ? " (" + yrs(d[1], d[2]) + ")" : ""; return [d[0], ((o.files[d[0]] || {}).name || d[0]) + y]; });
      dlg.innerHTML = '<div class="ccd-box" role="dialog" aria-modal="true" aria-labelledby="ccd-h"><header><h2 id="ccd-h">Download ' + esc(o.name) + '</h2><button type="button" class="ccd-x" aria-label="Close">✕</button></header>' +
        '<fieldset class="ccd-row"><legend class="ccd-l">What</legend><span class="ccd-c"><label><input type="radio" name="what" value="just"' + (st.what === "just" ? " checked" : "") + ">Just " + esc(o.name) + '</label><label><input type="radio" name="what" value="whole"' + (st.what === "whole" ? " checked" : "") + ">The whole dataset</label></span></fieldset>" +
        (o.ds.length > 1 ? '<div class="ccd-row"><span class="ccd-l">Dataset</span><span class="ccd-c">' + sel("ds", dsOpts) + "</span></div>" : "") +
        '<div class="ccd-sum"><span>You will get</span><p>' + p.text + "</p>" + (p.note ? "<small>" + p.note + "</small>" : "") + "</div>" +
        '<div class="ccd-act">' + (p.go ? '<a class="ccd-go" href="' + esc(p.go.href) + '"' + (p.go.file != null ? ' download="' + esc(p.go.file) + '"' : "") + (p.go.tab ? ' target="_blank" rel="noopener"' : "") + ">" + esc(p.go.label) + "</a>" : "") +
        '<button type="button" class="ccd-cancel">Cancel</button>' + (p.more ? '<a class="ccd-src" href="' + esc(p.more) + '" data-more>Excel, Parquet and other formats</a>' : "") + "</div></div>";
      dlg.hidden = false;
      [].forEach.call(dlg.querySelectorAll("input,select"), function (i) { i.addEventListener("change", function () { st[i.name] = i.value; draw(); }); });
      dlg.querySelector(".ccd-x").onclick = close; dlg.querySelector(".ccd-cancel").onclick = close;
      // "other formats" is the dataset page's own dialog: on that page, this form steps aside for it
      var more = dlg.querySelector("[data-more]");
      if (more) more.addEventListener("click", function () { dlg.hidden = true; });
      (dlg.querySelector("input:checked,select,.ccd-go") || dlg.querySelector(".ccd-x")).focus();
    }
    draw();
  }

  window.CCDownload = { open: open };
})();
