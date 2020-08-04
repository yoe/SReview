function updated(vm) {
  if(vm.event !== vm.last_event) {
    fetch("/api/v1/event/" + vm.event + "/overview")
    .then(response => response.json())
    .then((data) => {vm.rows = data; vm.last_event = vm.event})
    .catch(error => console.error(error));
  }
};

var vm = new Vue({
  el: '#overview',
  data: {
    title: "",
    rows: [],
    events: [],
    event: undefined,
    last_event: undefined,
  },
  created: function() {
    fetch("/api/v1/config")
    .then(response => response.json())
    .then(data => {this.event = data.event; updated(this);})
    .catch(error => console.error(error))
  },
  updated: function() {
    updated(this);
  }
})
