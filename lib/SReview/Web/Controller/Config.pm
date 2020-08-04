package SReview::Web::Controller::Config;

use Mojo::Base 'Mojolicious::Controller';

sub get_config {
	my $c = shift->openapi->valid_input;

	my $config = { event => $c->eventid };

	return $c->render(openapi => $config);
}

1;
