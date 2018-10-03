package SReview::Web::Controller::Review;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Collection 'c';

use SReview::Talk;

sub view {
	my $c = shift;

	my $id = $c->stash("id");
	my $talk;
	if(defined($id)) {
		$talk = SReview::Talk->new(talkid => $id);
	} else {
		$talk = SReview::Talk->by_nonce($c->stash('nonce'));
	}
	$c->stash(layout => 'default');
	$c->stash(talk => $talk);
	$c->stash(stylesheets => ['/review.css']);
	$c->render;
}

1;
