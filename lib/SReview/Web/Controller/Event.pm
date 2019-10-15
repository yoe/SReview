package SReview::Web::Controller::Event;

use Mojo::Base 'Mojolicious::Controller';
use SReview::API::Helpers;

sub create {
	my $c = shift;

	my $name = $c->stash("name");
	my $inputdir = $c->stash("inputdir");
	my $outputdir = $c->stash("outputdir");
	my $offset = $c->stash("time_offset");

	if(!$c->auth_scope("api/event/rw")) {
		$c->res->code(403);
		$c->render('Unauthorized');
		return 0;
	}

	$c->render(json => db_query($c->dbh, "INSERT INTO events(name, time_offset, inputdir, outputdir) VALUES(?,?,?,?) RETURNING json_build_object('id', \"id\")", $name, $offset, $inputdir, $outputdir));
}

sub by_title {
	my $c = shift;

	$c->render(json => db_query($c->dbh, "SELECT row_to_json(events.*) FROM events WHERE title = ?", $c->stash("title")));
}

sub by_id {
	my $c = shift;

	$c->render(json => db_query($c->dbh, "SELECT row_to_json(events.*) FROM events WHERE id = ?", $c->stash("id")));
}

sub update {
	my $c = shift;

	if(!$c->auth_scope("api/event/rw")) {
		$c->res->code(403);
		$c->render('Unauthorized');
		return 0;
	}
	$c->render(json => db_query($c->dbh, "UPDATE events SET name = ?, inputdir = ?, outputdir = ?, time_offset = ? WHERE id = ?", $c->stash("name"), $c->stash("inputdir"), $c->stash("outputdir"), $c->stash("time_offset"), $c->stash("id")));
}

sub delete {
	my $c = shift;

	if(!$c->auth_scope("api/event/rw")) {
		$c->res->code(403);
		$c->render('Unauthorized');
		return 0;
	}
	$c->render(json => db_query($c->dbh, "DELETE FROM events WHERE id = ?", $c->stash("id")));
}

sub list {
	my $c = shift;

	$c->render(json => db_query($c->dbh, "SELECT row_to_json(*) FROM events"));
}
