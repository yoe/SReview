package SReview::Web::Controller::Review;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Collection 'c';

use SReview::Talk;
use SReview::Access qw/admin_for/;

sub view {
	my $c = shift;

	my $id = $c->stash("id");
	my $talk;
	if(defined($id)) {
		$talk = SReview::Talk->new(talkid => $id);
	} else {
		$talk = SReview::Talk->by_nonce($c->stash('nonce'));
	}
	my $variant;
	if(admin_for($c, $talk) || $talk->state eq 'preview') {
		$variant = undef;
	} elsif($talk->state < 'preview') {
		$variant = 'preparing';
	} elsif($talk->state < 'done') {
		$variant = 'transcode';
	} else {
		$variant = 'done';
	}
		
	$c->stash(layout => 'default');
	$c->stash(talk => $talk);
	$c->stash(stylesheets => ['/review.css']);
	$c->render(variant => $variant);
}

1;
