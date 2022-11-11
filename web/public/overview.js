"use strict";

const unique_filter = function(value, index, self) {
  return self.indexOf(value) === index;
}

const load_event = function() {
  fetch("/api/v1/event/" + vm.event + "/overview")
  .then(response => response.json())
  .then(function (data) {
    vm.talks = data;
    vm.days = data.map(event => event.starttime.split(" ")[0])
      .filter(unique_filter);
    vm.rooms = data.map(event => event.room)
      .filter(unique_filter);
    vm.states = data.map(event => event.state)
      .filter(unique_filter);
  })
  .catch(error => console.error(error));
};

const search_text = function(search_terms, talk) {
  const needle = search_terms.toLowerCase();
  for (const field of ['name', 'speakers']) {
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
    if (! vm.selected_dates.includes(talk.starttime.split(" ")[0])) {
      return false;
    }
    if (! vm.selected_rooms.includes(talk.room)) {
      return false;
    }
    if (! vm.selected_states.includes(talk.state)) {
      return false;
    }
    return true;
  });
}

var filter_component = Vue.component('navbar-filter', {
  template: '#navbar-filter-template',
  props: [
    'name',
    'options',
  ],
  data: () => {
    return {
      id: 'no-id-yet',
      checkboxes: [],
    };
  },
  watch: {
    checkboxes: {
      handler: function(val) {
        const selected = val.filter(option => option.checked)
          .map(option => option.name);
        this.$emit('update:selected', selected);
      },
      deep: true,
    },
    options: function(val) {
      this.checkboxes = val.map((option, index) => ({
        id: this.id + '-' + index,
        checked: true,
        name: option,
      }));
    },
  },
  methods: {
    select_all: function() {
      this.checkboxes.map(option => option.checked = true);
    },
    clear_all: function() {
      this.checkboxes.map(option => option.checked = false);
    },
  },
  mounted: function() {
    this.id = 'navbar-filter-' + this._uid;
  },
});

var vm = new Vue({
  el: '#overview',
  data: {
    title: "",
    talks: [],  // unfiltered
    search: "",
    selected_dates: [],
    selected_rooms: [],
    selected_states: [],
    rows: [],   // filtered
    events: [],
    days: [],
    rooms: [],
    states: [],
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
    selected_dates: filter_talks,
    selected_rooms: filter_talks,
    selected_states: filter_talks,
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
