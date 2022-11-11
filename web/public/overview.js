const load_event = function() {
  fetch("/api/v1/event/" + vm.event + "/overview")
  .then(response => response.json())
  .then((data) => {vm.talks = data})
  .catch(error => console.error(error));
};

var vm = new Vue({
  el: '#overview',
  data: {
    title: "",
    rows: [],
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
