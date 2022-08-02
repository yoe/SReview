var vm = new Vue({
  el: '#overview',
  data: {
    title: "",
    rows: [],
    events: [],
    event: undefined,
    last_event: undefined,
    expls: []
  },
  methods: {
    reloadEvent: function() {
      fetch("/api/v1/event/" + vm.event + "/overview")
      .then(response => response.json())
      .then((data) => {vm.rows = data; vm.last_event = vm.event})
      .catch(error => console.error(error));
      fetch("/api/v1/config/legend/")
      .then(response => response.json())
      .then((data) => {vm.expls = data})
      .catch(error => console.error(error));
    }
  },
  updated: function() {
    if(this.event !== this.last_event) {
      fetch("/api/v1/event/" + this.event + "/overview")
      .then(response => response.json())
      .then((data) => {this.rows = data; this.last_event = this.event})
      .catch(error => console.error(error));
    }
  },
  created: function() {
    fetch("/api/v1/config")
    .then(response => response.json())
    .then(data => {this.event = data.event; this.updated;})
    .catch(error => console.error(error));
    fetch("/api/v1/event/list")
    .then(response => response.json())
    .then(data => {this.events = data;})
    .catch(error => console.error(error));
  }
})
