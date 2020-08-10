package SReview::Web::Controller::Event;

use Mojo::Base 'Mojolicious::Controller';
use SReview::API::Helpers;
use Data::Dumper;

sub add {
	my $c = shift->openapi->valid_input or return;

	return add_with_json($c, $c->req->json, "events", $c->openapi->spec('/components/schemas/Event/properties'));
}

sub update {
	my $c = shift->openapi->valid_input or return;

	my $eventId = $c->param("eventId");

	my $event = $c->req->json;

	$event->{id} = $eventId;

	return update_with_json($c, $event, "events",  $c->openapi->spec('/components/schemas/Event/properties'));
}

sub delete {
	my $c = shift->openapi->valid_input or return;

	my $eventId = $c->param('eventId');
	my $query = "DELETE FROM events WHERE id = ? RETURNING id";

	return delete_with_query($c, $query, $eventId);
}

sub getById {
	my $c = shift->openapi->valid_input or return;

	my $eventId = $c->param("eventId");
	my $event = db_query($c->dbh, "SELECT events.* FROM events WHERE id = ?", $eventId);

	if(scalar(@$event) < 1) {
		return $c->render(openapi => {errors => [{message => "not found"}]}, status => 404);
	}

	$c->render(openapi => $event->[0]);
}

sub list {
	my $c = shift->openapi->valid_input or return;

	my $events = db_query($c->dbh, "SELECT events.* FROM events");

	$c->render(openapi => $events);
}

sub overview {
	my $c = shift->openapi->valid_input or return;

	my $eventId = $c->param("eventId");
	my $query;
	my $st = $c->dbh->prepare("SELECT id FROM events WHERE id = ?");
	$st->execute($eventId);
	if($st->rows < 1) {
		return $c->render(openapi => {errors => [{message => "not found"}]}, status => 404);
	}

	if($c->srconfig->get("anonreviews")) {
		$query = "SELECT '/r/' || nonce AS reviewurl, name, speakers, room, starttime::timestamp, endtime::timestamp, state, progress FROM talk_list WHERE eventid = ? AND state IS NOT NULL ORDER BY state, progress, room, starttime";
	} else {
		$query = "SELECT name, speakers, room, starttime::timestamp, endtime::timestamp, state, progress FROM talk_list WHERE eventid = ? AND state IS NOT NULL ORDER BY state, progress, room, starttime";
	}

	my $res = db_query($c->dbh, $query, $eventId);

	$c->render(openapi => $res);
}

1;
