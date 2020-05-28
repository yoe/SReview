package SReview::Web::Controller::Talk;

use Mojo::Base 'Mojolicious::Controller';
use SReview::API::Helpers qw/db_query update_with_json add_with_json/;
use Mojo::Util;

sub listByEvent {
	my $c = shift->openapi->valid_input or return;

	my $eventId = $c->param("eventId");

	my $event = db_query($c->dbh, "SELECT id FROM events WHERE id = ?", $eventId);

	if(scalar(@$event) < 1) {
		$c->res->code(404);
		$c->render(text => "not found");
		return;
	}

	$c->render(openapi => db_query($c->dbh, "SELECT row_to_json(talks.*) FROM talks WHERE event = ?", $eventId));
}

sub add {
	my $c = shift->openapi->valid_input or return;

	my $eventId = $c->param("eventId");

	my $event = db_query($c->dbh, "SELECT id FROM events WHERE id = ?", $eventId);

	if(scalar(@$event) < 1) {
		$c->res->code(404);
		$c->render(text => "Event not found");
		return;
	}

	my $talk = $c->req->json;
	$talk->{event} = $event->[0];

	return add_with_json($c, $talk, "talks", $c->openapi->spec('/components/schemas/Talk/properties'));
}

sub update {
	my $c = shift->openapi->valid_input or return;

	my $eventId = $c->param('eventId');

	my $event = db_query($c->dbh, "SELECT id FROM events WHERE id = ?", $eventId);

	if(scalar(@$event) < 1) {
		$c->res->code(404);
		$c->render(text => 'Event not found');
		return;
	}

	my $talk = $c->req->json;

	return update_with_json($c, $talk, "talks", $c->openapi->spec('/components/schemas/Talk/properties'));
}

sub delete {
	my $c = shift->openapi->valid_input or return;

	my $eventId = $c->param('eventId');
	my $talkId = $c->param('talkId');

	my $event = db_query($c->dbh, "SELECT id FROM events WHERE id = ?", $eventId);

	if(scalar(@$event) < 1) {
		$c->res->code(404);
		$c->render(text => 'Event not found');
		return;
	}

	return db_query($c->dbh, 'DELETE FROM talks WHERE id = ? AND event = ?', $talkId, $eventId);
}

sub by_title {
	my $c = shift;
	$c->render(json => db_query($c->dbh, "SELECT row_to_json(talks.*) FROM talks WHERE title = ? AND event = ?", $c->stash("title"), $c->stash("event")));
}

sub by_id {
	my $c = shift;
	$c->render(json => db_query($c->dbh, "SELECT row_to_json(talks.*) FROM talks WHERE id = ? AND event = ?", $c->stash("id"), $c->stash("event")));
}

sub by_nonce {
	my $c = shift;
	$c->render(json => db_query($c->dbh, "SELECT row_to_json(talks.*) FROM talks WHERE nonce = ? AND event = ?", $c->stash("nonce"), $c->stash("event")));
}

sub list {
	my $c = shift;
	$c->render(json => db_query($c->dbh, "SELECT row_to_json(talks.*) FROM talks WHERE event = ?", $c->stash("event")));
}

sub delete {
	my $c = shift;
	$c->render(json => db_query($c->dbh, "DELETE FROM talks WHERE id = ? AND event = ?", $c->stash("id"), $c->stash("event")));
}

1;
