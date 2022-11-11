Vue.component("talk-preview", {
  template: `
    <div class="col-md-4 text-center">
      <img class="img-fluid" v-bind:src="'/api/v1/nonce/' + talk.nonce + '/' + which + '?force=' + force">
      <button class="btn btn-primary" v-on:click="setForce"><i class="fa fa-regular fa-rotate-right"></i></button>
    </div>`,
  props: ["talk", "which"],
  methods: {
    setForce: function() {
      this.force = Date.now();
    }
  },
  data: function() {
    return {
      force: false
    }
  },
})

const load_event = function() {
  fetch("/api/v1/event/" + app.event + "/overview")
  .then(response => response.json())
  .then((data) => {app.rows = data.filter((row) => row.state !== "ignored")})
  .catch(error => console.error(error));
};

var app = new Vue({
  el: '#preview',
  data: {
    title: "",
    rows: [],
    events: [],
    event: undefined,
  },
  methods: {
    reloadEvent: load_event,
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
  },
});
