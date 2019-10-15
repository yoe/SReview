package SReview::Web::Controller::Talk;

use Mojo::Base 'Mojolicious::Controller';
use SReview::API::Helpers;
use Text::Dirify qw/dirify/;

sub create {
	my $c = shift;

	if(!$c->auth_scope("api/talk/rw")) {
		$c->res->code(403);
		$c->render('Unauthorized');
		return 0;
	}

	my $slug = $c->stash("slug");
	if(!defined($slug)) {
		$slug = dirify($c->stash("title"));
	}

	$c->render(json => db_query($c->dbh, "INSERT INTO talks(room, slug, starttime, endtime, title, event, upstreamid, subtitle, track, description) VALUES(?,?,?,?,?,?,?,?,?,?)", $c->stash("room"), $slug, $c->stash("starttime"), $c->stash("endtime"), $c->stash("title"), $c->stash("event"), $c->stash("upstreamid"), $c->stash("subtitle"), $c->stash("track"), $c->stash("description")));
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
