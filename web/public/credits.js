Vue.component("talk-preview", {
  template: `
    <div class="col-md-4 text-center">
      <img class="img-responsive" v-bind:src="'/api/v1/nonce/' + talk.nonce + '/' + which + '?force=' + force">
      <button class="btn btn-primary" v-on:click="setForce"><span class="glyphicon glyphicon-refresh"></span></button>
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

function updated(app) {
  if(app.event !== app.last_event) {
    fetch("/api/v1/event/" + app.event + "/overview")
    .then(response => response.json())
    .then((data) => {app.rows = data; app.last_event = app.event})
    .catch(error => console.error(error));
  }
}

var app = new Vue({
  el: '#preview',
  data: {
    title: "",
    rows: [],
    events: [],
    event: undefined,
    last_event: undefined,
  },
  methods: {
    reloadEvent: function() {
      fetch("/api/v1/event/" + this.event + "/overview")
      .then(response => response.json())
      .then((data) => {this.rows = data; this.last_event = this.event})
      .catch(error => console.error(error));
    }
  },
  created: function() {
    fetch("/api/v1/config")
    .then(response => response.json())
    .then(data => {this.event = data.event; updated(this);})
    .catch(error => console.error(error));
    fetch("/api/v1/event/list")
    .then(response => response.json())
    .then(data => {this.events = data})
    .catch(error => console.error(error));
  },
  updated: function() {
    updated(this);
  }
});
