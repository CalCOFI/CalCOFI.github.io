/* Browse datasets: the head's Type select drives catalog.js's realm facet; Sort reorders the list. */
(function () {
  "use strict";
  var type = document.getElementById("bd-type"), realm = document.getElementById("ds-realm");
  if (type && realm) {
    type.value = realm.value || "";
    type.addEventListener("change", function () { realm.value = type.value; realm.dispatchEvent(new Event("change", { bubbles: true })); });
  }
  var sort = document.getElementById("bd-sort"), list = document.getElementById("ds-list");
  if (!sort || !list) return;
  var rows = [].slice.call(list.querySelectorAll(".bd-row"));
  var by = {
    az: function (a, b) { return a.dataset.name.localeCompare(b.dataset.name); },
    long: function (a, b) { return (+a.dataset.y0 - +b.dataset.y0) || (+b.dataset.y1 - +a.dataset.y1); },
    recent: function (a, b) { return (+b.dataset.y1 - +a.dataset.y1) || by.az(a, b); },
    cat: function (a, b) { return (+a.dataset.order - +b.dataset.order) || by.az(a, b); }
  };
  sort.addEventListener("change", function () { rows.slice().sort(by[sort.value] || by.az).forEach(function (r) { list.appendChild(r); }); });
})();
