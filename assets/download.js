/* The one download flow (Betty 2026-11-15) for Browse datasets, Species and Measurements.

   Nothing downloads without saying what it is. Two kinds of download:
     · Just one species or measurement, from ONE dataset (methods differ — eDNA reads, pumped eggs and
       net tows are not one table): the Query Builder opens with it picked and downloads the CSV
       (explore/builder.html?pick=…&download=1).
     · The whole dataset, as CalCOFI publishes it: CSV, Parquet or NetCDF. CSV of a whole dataset is
       made in the browser from the release Parquet when the file is small enough (ERDDAP refuses a
       whole-table CSV); a larger one offers ERDDAP's form instead, or the Parquet / NetCDF file.

   CCDownload.open(opts) draws the form; CCDownload.csv(url, name) is the in-browser CSV.
   opts: { name, unit, kind: "species" | "measurement" | "dataset", ds: [[key, y0, y1, n], …],
           files: { key: { name, erddap, pq: [url, size], pq_bytes, nc: [url, size], src, page } },
           pick: function (key) → builder URL or null, start: "just" | "whole", dsKey }            */
(function () {
  "use strict";
  var CSV_MAX = 30 * 1024 * 1024; // Parquet bytes above which the browser does not build the CSV
  var VENDOR = (document.currentScript && document.currentScript.src.replace(/download\.js.*$/, "")) + "lib/hyparquet-1.33.0.min.js";

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
    var whole = o.kind === "dataset";
    var st = { what: whole ? "whole" : (o.start || "just"), ds: o.dsKey || (o.ds[0] && o.ds[0][0]), fmt: null };
    function f() { return o.files[st.ds] || {}; }
    function fmts() {
      var x = f(), out = [];
      var small = x.pq && x.pq_bytes && x.pq_bytes <= CSV_MAX;
      if (small) out.push(["csv", "CSV · the whole dataset, one file"]);
      else if (x.erddap) out.push(["erddap", "CSV · choose columns and years on ERDDAP"]);
      if (x.pq) out.push(["pq", "Parquet · whole file · " + x.pq[1]]);
      if (x.nc) out.push(["nc", "NetCDF · whole file · " + x.nc[1]]);
      return out;
    }
    function sel(name, opts) {
      return '<select name="' + name + '">' + opts.map(function (p) { return '<option value="' + esc(p[0]) + '"' + (st[name] === p[0] ? " selected" : "") + ">" + esc(p[1]) + "</option>"; }).join("") + "</select>";
    }
    function plan() {
      var d = o.ds.filter(function (z) { return z[0] === st.ds; })[0] || [st.ds], x = f(), nm = x.name || st.ds;
      if (st.what === "just") {
        var u = o.pick && o.pick(st.ds);
        return { text: "<b>" + esc(o.name) + "</b> only, from <b>" + esc(nm) + "</b>" + (d[1] ? " (" + yrs(d[1], d[2]) + ", " + big(d[3]) + " " + o.unit + ")" : "") + ", as a CSV.",
                 note: "The Query Builder opens with it picked and downloads the CSV. You can then change the rows or years and download again.",
                 go: u ? ["Download CSV", u, false] : null };
      }
      var fm = fmts(), cur = fm.filter(function (p) { return p[0] === st.fmt; })[0] ? st.fmt : (fm[0] && fm[0][0]);
      st.fmt = cur;
      var what = "The whole <b>" + esc(nm) + "</b> dataset, as CalCOFI publishes it" + (whole ? "" : ", including every " + (o.kind === "species" ? "species" : "measurement") + " in it") + ", ";
      if (cur === "csv") return { text: what + "as one CSV.", note: "Made in your browser from the release Parquet file (" + x.pq[1] + "), so it can take a few seconds.", go: ["Download CSV", x.pq[0], "csv"] };
      if (cur === "erddap") return { text: what + "as CSV, from ERDDAP.", note: "This dataset is too large for one CSV, so ERDDAP opens to choose the columns and years; it builds the CSV.", go: ["Open ERDDAP", x.erddap, false] };
      if (cur === "pq") return { text: what + "as Parquet (" + x.pq[1] + ").", note: "Starts the download right away. Parquet opens in R (arrow), Python (pandas) or DuckDB.", go: ["Download Parquet", x.pq[0], true] };
      if (cur === "nc") return { text: what + "as NetCDF (" + x.nc[1] + ").", note: "Starts the download right away.", go: ["Download NetCDF", x.nc[0], true] };
      return { text: what + "but no download file is listed for it yet.", note: "", go: null };
    }
    function draw() {
      var x = f(), p = plan();
      var dsOpts = o.ds.map(function (d) { var y = st.what === "just" && d[1] ? " (" + yrs(d[1], d[2]) + ")" : ""; return [d[0], ((o.files[d[0]] || {}).name || d[0]) + y]; });
      dlg.innerHTML = '<div class="ccd-box" role="dialog" aria-modal="true" aria-labelledby="ccd-h"><header><h2 id="ccd-h">Download ' + esc(o.name) + '</h2><button type="button" class="ccd-x" aria-label="Close">✕</button></header>' +
        (whole ? "" : '<div class="ccd-row"><span class="ccd-l">What</span><span class="ccd-c"><label><input type="radio" name="what" value="just"' + (st.what === "just" ? " checked" : "") + ">Just " + esc(o.name) + '</label><label><input type="radio" name="what" value="whole"' + (st.what === "whole" ? " checked" : "") + ">The whole dataset</label></span></div>") +
        (o.ds.length > 1 ? '<div class="ccd-row"><span class="ccd-l">Dataset</span><span class="ccd-c">' + sel("ds", dsOpts) + "</span></div>" : "") +
        (st.what === "whole" && fmts().length > 1 ? '<div class="ccd-row"><span class="ccd-l">File</span><span class="ccd-c">' + sel("fmt", fmts()) + "</span></div>" : "") +
        '<div class="ccd-sum"><span>You will get</span><p>' + p.text + "</p>" + (p.note ? "<small>" + p.note + "</small>" : "") + "</div>" +
        '<div class="ccd-act">' + (p.go ? '<a class="ccd-go" href="' + esc(p.go[1]) + '"' + (p.go[2] === true ? " download" : "") + (p.go[2] === false ? ' target="_blank" rel="noopener"' : "") + ">" + esc(p.go[0]) + "</a>" : "") +
        '<button type="button" class="ccd-cancel">Cancel</button>' + (st.what === "whole" && x.src ? '<a class="ccd-src" href="' + esc(x.src) + '" target="_blank" rel="noopener">Original files from the provider ↗</a>' : "") + "</div>" +
        '<p class="ccd-msg" role="status" hidden></p></div>';
      dlg.hidden = false;
      [].forEach.call(dlg.querySelectorAll("input,select"), function (i) { i.addEventListener("change", function () { st[i.name] = i.value; draw(); }); });
      dlg.querySelector(".ccd-x").onclick = close; dlg.querySelector(".ccd-cancel").onclick = close;
      var go = dlg.querySelector(".ccd-go");
      if (go && p.go[2] === "csv") go.addEventListener("click", function (e) {
        e.preventDefault(); var m = dlg.querySelector(".ccd-msg"); m.hidden = false; m.textContent = "Making the CSV…";
        csv(p.go[1], (x.name || st.ds)).then(function () { m.textContent = "Downloaded."; }).catch(function (err) {
          console.error(err); m.innerHTML = 'Could not make the CSV here. <a href="' + esc(x.pq[0]) + '" download>Download the Parquet file</a> instead.';
        });
      });
      (dlg.querySelector("input:checked,select,.ccd-go") || dlg.querySelector(".ccd-x")).focus();
    }
    draw();
  }

  // the whole release Parquet file → one CSV, in the browser
  function csv(url, name) {
    return import(VENDOR).then(function (h) {
      return h.asyncBufferFromUrl({ url: url }).then(function (file) {
        return h.parquetReadObjects({ file: file, compressors: h.compressors });
      });
    }).then(function (rows) {
      if (!rows.length) throw new Error("no rows");
      var cols = Object.keys(rows[0]);
      var cell = function (v) {
        if (v == null) return "";
        if (v instanceof Date) v = v.toISOString();
        else if (typeof v === "bigint") v = v.toString();
        else if (typeof v === "object") v = JSON.stringify(v, function (k, x) { return typeof x === "bigint" ? x.toString() : x; });
        v = String(v);
        return /[",\n\r]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v;
      };
      var out = [cols.join(",")];
      for (var i = 0; i < rows.length; i++) out.push(cols.map(function (c) { return cell(rows[i][c]); }).join(","));
      var blob = new Blob([out.join("\n") + "\n"], { type: "text/csv" });
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = String(name).toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "") + ".csv";
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(function () { URL.revokeObjectURL(a.href); }, 4000);
    });
  }

  window.CCDownload = { open: open, csv: csv };
})();
