package SReview::Web::Controller::User;

use Mojo::Base 'Mojolicious::Controller';
use SReview::API::Helpers;

sub add {
	my $c = shift->openapi->valid_input or return;

	my $user = $c->req->json;

	return add_with_json($c, $user, "users", $c->openapi->spec('/components/schemas/User/properties');
}

sub update {
	my $c = shift->openapi->valid_input or return;

	my $userId = $c->param("userId");
	my $user = $c->req->json;

	$user->{id} = $userId;

	return update_with_json($c, $user, "users", $c->openapi->spec('/components/schemas/User/properties');
}

sub getById {
	my $c = shift->openapi->valid_input or return;

	my $userId = $c->param('userId');

	my $user = db_query($c->dbh, "SELECT row_to_json(users.*) FROM users WHERE id = ?", $userId);

	if(scalar(@$user) < 1) {
		$c->res->code(404);
		$c->render(text => "not found");
		return;
	}

	$c->render(openapi => $user->[0]);
}

sub delete {
	my $c = shift->openapi->valid_input or return;

	my $userId = $c->param('userId');

	return delete_with_query($c, "DELETE FROM users WHERE id = ?", $userId);
}

sub list {
	my $c = shift->openapi->valid_input or return;

	$c->render(openapi => db_query($c->dbh, "SELECT row_to_json(users.*) FROM users");
}

1;
