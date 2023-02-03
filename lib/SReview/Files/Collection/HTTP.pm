package SReview::Files::Access::HTTP;

use Moose;
use Carp;
use Mojo::UserAgent;
use File::Temp qw/tempfile tempdir mktemp/;

extends 'SReview::Files::Access::Base';

has '+filename' => (
	predicate => 'has_download',
);

has 'workdir' => (
	is => 'ro',
	lazy => 1,
	builder => '_get_workdir',
);

sub _get_workdir {
	return tempdir(CLEANUP => 1);
}

sub _get_file {
	my $self = shift;
	my @parts = split('\.', $self->relname);
	my $ext = pop(@parts);
	my $dir = $self->workdir;

	if($self->has_data) {
		my ($fh, $file) = tempfile("http-XXXXXX", dir => $dir, SUFFIX => ".$ext");
		my $ua = Mojo::UserAgent->new;
		my $res = $ua->get($self->url)->result;
		if($res->is_success) {
			$res->save_to($file);
			return $file;
		} else {
			croak "could not download file:" . $res->message;
		}
	} else {
		croak "Can't create files with the HTTP access method";
	}
}

sub _probe_basepath {
	return shift->workdir;
}

package SReview::Files::Collection::HTTP;

use Moose;
use Carp;

extends 'SReview::Files::Collection::Base';

has '+fileclass' => (
	default => 'SReview::Files::Access::HTTP',
);

sub add_file {
	croak "Creating files is not supported on an HTTP collection";
}

sub _probe_children {
	croak "Discovering children is not supported on an HTTP collection";
}

1;
