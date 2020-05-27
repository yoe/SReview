package SReview::Web::Controller::Event;

use Mojo::Base 'Mojolicious::Controller';
use SReview::API::Helpers qw/db_query update_with_json/;
use Data::Dumper;

my %fields = (
	"id" => 1,
	"name" => 1,
	"time_offset" => 1,
	"inputdir" => 1,
	"outputdir" => 1,
);
sub add {
	my $c = shift->openapi->valid_input or return;

	my $event = $c->req->body;

	$c->app->log->debug("adding event");

	$c->render(openapi => db_query($c->dbh, "INSERT INTO events(select * FROM json_populate_record(null::events, ?)) RETURNING id", $event));
}

sub update {
	my $c = shift->openapi->valid_input or return;

	my $event = $c->req->json;

	return update_with_json($c, $event, "events", \%fields);
}

sub getById {
	my $c = shift->openapi->valid_input or return;

	my $eventId = $c->param("eventId");

	my $event = db_query($c->dbh, "SELECT row_to_json(events.*) FROM events WHERE id = ?", $eventId);

	if(scalar(@$event) < 1) {
		$c->res->code(404);
		$c->render(text => "not found");
		return;
	}

	$c->render(openapi => $event->[0]);
}

sub list {
	my $c = shift->openapi->valid_input or return;

	$c->app->log->debug(Dumper($c->openapi->spec));

	my $events = db_query($c->dbh, "SELECT row_to_json(events.*) FROM events");

	$c->render(openapi => $events);
}

1;
