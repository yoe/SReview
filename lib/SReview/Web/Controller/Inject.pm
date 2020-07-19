package SReview::Web::Controller::Inject;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Collection 'c';
use Data::Dumper;

use SReview::Access qw/admin_for/;
use SReview::Files::Factory;
use SReview::Talk;

sub view {
	my $c = shift;

	my $talk;
	my $id = $c->stash("id");
	eval {
		if(defined($id)) {
			$talk = SReview::Talk->new(talkid => $id);
		} else {
			$talk = SReview::Talk->by_nonce($c->stash("nonce"));
		}
	};
	if($@) {
		$c->stash(error => $@);
		$c->stash(short_error => "Exception occurred");
		$c->render(variant => 'error');
		return;
	}

	my $nonce = $talk->nonce;
	my $variant;
	$c->stash(adminspecial => 0);
	if ($talk->state <= 'preview') {
		$variant = undef;
	} elsif(admin_for($c, $talk)) {
		$variant = undef;
		$c->stash(adminspecial => 1);
	} elsif(!$talk->get_flag("can_inject")) {
		$variant = 'error';
		$c->stash(short_error => "Injection not allowed for this talk");
		$c->stash(error => "Talks can only be injected when an administrator enables the option for that talk. Please talk to the administrators of the review system and ask them to enable this option for this talk.");
	} else  {
		$variant = 'done';
	}

	my $vid_prefix = $c->srconfig->get('vid_prefix');
	$vid_prefix = '' unless defined($vid_prefix);
	$c->stash(vid_prefix => $vid_prefix);

	$c->stash(talk => $talk);
	$c->stash(stylesheets => ['/review.css']);
	$c->stash(variant => $variant);
}

sub update {
	my $c = shift;
	my $id = $c->stash("id");
	my $talk;

	$c->stash(stylesheets => ['/review.css']);
	if(defined($id)) {
		$talk = SReview::Talk->new(talkid => $id);
	} else {
		eval {
			$talk = SReview::Talk->by_nonce($c->stash('nonce'));
		};
		if($@) {
			$c->stash(error => $@);
			$c->stash(short_error => 'Exception occurred');
			$c->render(variant => 'error');
			return;
		}
	}
	$c->stash(talk => $talk);
	if(!admin_for($c, $talk) && $talk->state > 'preview') {
		$c->stash(short_error => 'Not available');
		$c->stash(error => 'This talk is not currently available for data injection. Please try again later!');
		return;
	}
	foreach my $upload(@{$c->req->uploads}) {
		if($upload->name eq "video_asset") {
			$c->app->log->debug("coying video asset " . $upload->filename);
			my @parts = split /\./, $upload->filename;
			my $ext = pop @parts;
			my $fn = join('.', $talk->slug, $ext);
			my $coll = SReview::Files::Factory->create("input", $c->srconfig->get("inputglob"), $c->srconfig);
			my $file = $coll->add_file(relname => join("/", "injected", $fn));
			my $st = $c->dbh->prepare("INSERT INTO raw_files(filename, room, starttime, stream) VALUES(?,?,?,'injected')");
			$st->execute($file->url, $talk->roomid, $talk->corrected_times->{start});
			$upload->move_to($file->filename);
			$file->store_file;
			$talk->active_stream("injected");
			$talk->set_state("injecting");
			$talk->done_correcting;
		} elsif($upload->name eq "other_asset") {
			$c->app->log->debug("copying other asset " . $upload->filename);
			my $coll = SReview::Files::Factory->create("upload", $c->srconfig->get("extra_collections")->{upload}, $c->srconfig);
			my $file = $coll->add_file(relname => join("/", $talk->slug, $upload->filename));
			$upload->move_to($file->filename);
			$file->store_file;
		}
		$c->app->log->debug($upload->filename . " done");
	}
	$c->render(text => "ok");
}

1;
