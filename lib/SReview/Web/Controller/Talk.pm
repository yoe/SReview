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

	return delete_with_query($c, 'DELETE FROM talks WHERE id = ? AND event = ?', $talkId, $eventId);
}

sub setSpeakers {
	my $c = shift->openapi->valid_input or return;

	my $eventId = $c->param('eventId');
	my $talkId = $c->param('talkId');

	my $event = db_query($c->dbh, "SELECT id FROM talks WHERE id = ? AND event = ?", $talkId, $eventId);

	if(scalar(@$event) < 1) {
		$c->res->code(404);
		$c->render(text => 'Event or talk not found');
		return;
	}

	my $speakers = $c->req->json;
	my $dbh = $c->dbh;

	$dbh->begin_work();

	db_query($dbh, 'DELETE FROM speakers_talks WHERE talk = ?', $talkId);

	if(scalar(@$speakers) < 1) {
		$c->render(openapi => []);
		$dbh->commit;
		return;
	}

	foreach my $speakerId(@$speakers) {
		my $speaker = db_query($dbh, 'SELECT id FROM speakers WHERE id = ?', $speakerId);
		if(scalar(@$speaker) < 1) {
			$c->res->code(404);
			$c->render(text => 'Speaker not found');
			$dbh->rollback;
			return;
		}
		db_query($dbh, 'INSERT INTO speakers_talks(speaker, talk) VALUES(?, ?)', $speakerId, $talkId);
		if($dbh->err) {
			$c->res->code(400);
			$c->render(text => 'Could not add speaker:' . $dbh->errmsg);
			$dbh->rollback;
			return;
		}
	}

	$dbh->commit;

	my $speakers = db_query($dbh, "SELECT speaker FROM speakers_talks WHERE talk = ?", $talkId);

	return $c->render(openapi => $speakers);
}

sub addSpeakers {
	my $c = shift->openapi->valid_input or return;

	my $eventId = $c->param('eventId');
	my $talkId = $c->param('talkId');

	my $event = db_query($c->dbh, "SELECT id FROM talks WHERE event = ? AND id = ?", $eventId, $talkId);

	if(scalar(@$event) < 1) {
		$c->res->code(404);
		$c->render(text => 'Event or talk not found');
		return;
	}

	my $speakers = $c->req->json;

	if(scalar(@$speakers) < 1) {
		$c->res->code(400);
		$c->render(text => 'at least one speaker is required');
		return;
	}
	my $dbh = $c->dbh;

	$dbh->begin_work;

	foreach my $speakerId(@$speakers) {
		my $speaker = db_query($dbh, 'SELECT id FROM speakers WHERE id = ?', $speakerId);
		if(scalar(@$speaker) < 1) {
			$c->res->code(404);
			$c->render(text => 'Speaker not found');
			$dbh->rollback;
			return;
		}
		db_query($dbh, 'INSERT INTO speakers_talks(speaker, talk) VALUES(?, ?)', $speakerId, $talkId);
		if($dbh->err) {
			$c->res->code(400);
			$c->render(text => 'Could not add speaker:' . $dbh->errmsg);
			$dbh->rollback;
			return;
		}
	}

	$dbh->commit;

	my $speakers = db_query($dbh, "SELECT speaker FROM speakers_talks WHERE talk = ?", $talkId);

	return $c->render(openapi => $speakers);
}

sub getById {
	my $c = shift->openapi->valid_input or return;

	my $eventId = $c->param("eventId");
	my $talkId = $c->param("talkId");

	my $talk = db_query("SELECT row_to_json(talks.*) FROM talks WHERE event = ? AND talk = ?", $eventId, $talkId);

	if(scalar(@$talk) < 1) {
		$c->res->code(404);
		$c->render(text => "Event or talk not found");
		return;
	}

	$c->render(openapi => $talk);
}

sub getByNonce {
	my $c = shift->openapi->valid_input or return;

	my $nonce = $c->param("nonce");

	my $talk = db_query("SELECT row_to_json(talks.*) FROM talks WHERE nonce = ?", $nonce);

	if(scalar(@$talk) < 1) {
		$c->res->code(404);
		$c->render(text => "not found");
		return;
	}

	$c->render(openapi => $talk);
}

1;
