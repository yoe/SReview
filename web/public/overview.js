const load_event = function() {
  fetch("/api/v1/event/" + vm.event + "/overview")
  .then(response => response.json())
  .then((data) => {vm.talks = data})
  .catch(error => console.error(error));
};

const search_text = function(search_terms, talk) {
  const needle = search_terms.toLowerCase();
  for (field of ['name', 'speakers']) {
    const value = talk[field];
    if (needle === undefined) {
      continue;
    }
    if (value.toLowerCase().includes(needle)) {
      return true;
    }
  }
  return false;
}

const filter_talks = function() {
  vm.rows = vm.talks.filter(talk => {
    if (vm.search && ! search_text(vm.search, talk)) {
      return false;
    }
    return true;
  });
}

var vm = new Vue({
  el: '#overview',
  data: {
    title: "",
    search: "",
    talks: [],  // unfiltered
    rows: [],   // filtered
    events: [],
    event: undefined,
    expls: []
  },
  methods: {
    reloadEvent: function() {
      load_event(this.event);
    }
  },
  watch: {
    event: load_event,
    search: filter_talks,
    talks: filter_talks,
  },
  created: function() {
    fetch("/api/v1/config")
    .then(response => response.json())
    .then(data => {this.event = data.event})
    .catch(error => console.error(error));
    fetch("/api/v1/event/list")
    .then(response => response.json())
    .then(data => {this.events = data})
    .catch(error => console.error(error));
    fetch("/api/v1/config/legend/")
    .then(response => response.json())
    .then((data) => {vm.expls = data})
    .catch(error => console.error(error));
  }
})
