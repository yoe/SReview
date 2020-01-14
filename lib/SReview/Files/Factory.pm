package SReview::Files::Base;

use Moose;

has 'is_collection' => (
	isa => 'Bool',
	is => 'ro',
);

no Moose;

package SReview::Files::Access::Base;

use Moose;
use DateTime;

extends 'SReview::Files::Base';

has '+is_collection' => (
	default => 0,
);

has 'relname' => (
	is => 'rw',
	isa => 'Str',
	required => 1,
);

has 'filename' => (
	isa => 'Str',
	is => 'ro',
	lazy => 1,
	builder => '_get_file',
);

has 'mtime' => (
	isa => 'DateTime',
	is => 'ro',
	lazy => 1,
	builder => '_probe_mtime',
);

has 'baseurl' => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has 'url' => (
	isa => 'Str',
	is => 'ro',
	lazy => 1,
	builder => '_probe_url',
);

sub _probe_url {
	my $self = shift;

	return join('/', $self->baseurl, $self->relname);
}

no Moose;

package SReview::Files::Access::direct;

use Moose;
use DateTime;

extends 'SReview::Files::Access::Base';

sub _get_file {
	my $self = shift;

	return join('/', $self->baseurl, $self->relname);
}

sub store_file {
	return 1;
}

sub _probe_mtime {
	my $self = shift;
	my @stat = stat($self->filename);

	return DateTime->from_epoch(epoch => $stat[9]);
}

no Moose;

package SReview::Files::Collection::Base;

use Moose;

extends 'SReview::Files::Base';

has '+is_collection' => (
	default => 1,
);

has 'children' => (
	isa => 'ArrayRef[SReview::Files::Base]',
	traits => ['Array'],
	is => "ro",
	lazy => 1,
	handles => {
		sorted_files => 'sort',
	},
	builder => '_probe_children',
);

has 'baseurl' => (
	isa => 'Str',
	is => 'ro',
	predicate => 'has_baseurl',
);

has 'globpattern' => (
	isa => 'Str',
	is => 'ro',
	predicate => 'has_globpattern',
);

has 'fullname' => (
	isa => 'Str',
	is => 'ro',
	lazy => 1,
	builder => '_probe_fullname',
);

no Moose;

package SReview::Files::Collection::direct;

use Moose;
use File::Basename;
use Carp;

extends 'SReview::Files::Collection::Base';

has '+baseurl' => (
	lazy => 1,
	builder => '_probe_baseurl',
);

has '+globpattern' => (
	lazy => 1,
	builder => '_probe_globpattern',
);

sub _probe_baseurl {
	my $self = shift;
	
	if(!$self->has_globpattern) {
		croak("either a globpattern or a baseurl are required!\n");
	}
	@_ = split(/\*/, $self->globpattern);

	my $rv = $_[0];
	while(substr($rv, -1) eq '/') {
		substr($rv, -1) = '';
	}

	return $rv;
}

sub _probe_globpattern {
	my $self = shift;

	if(!$self->has_baseurl) {
		croak("either a globpattern or a baseurl are required!\n");
	}
	return join('/', $self->baseurl, '*');
}

sub _probe_children {
	my $self = shift;
	my @return;

	foreach my $file(glob($self->globpattern)) {
		my $child;
		if(-d $file) {
			$child = SReview::Files::Collection::direct->new(baseurl => join("/", $self->baseurl, basename($file)));
		} else {
			my $basename = substr($file, length($self->baseurl));
			while(substr($basename, 0, 1) eq '/') {
				$basename = substr($basename, 1);
			}
			$child = SReview::Files::Access::direct->new(baseurl => $self->baseurl, relname => $basename);
		}
		push @return, $child;
	}

	return \@return;
}

sub get_by_fullname {
	my $self = shift;
	my $fullname = shift;

	if(substr($fullname, 0, length($self->baseurl)) != $self->baseurl) {
		croak("$fullname is not accessible through this collection");
	}
	my $relname = substr($fullname, length($self->baseurl) + 1);
	while(substr($relname, 0, 1) eq '/') {
		$relname = substr($relname, 1);
	}
	return SReview::Files::Access::direct->new(baseurl => $self->baseurl, relname => $relname);
}

no Moose;

package SReview::Files::Factory;

use SReview::Config::Common;

sub create {
	my $class = shift;
	my $target = shift;
	my $relname = shift;
	my $config = SReview::Config::Common::setup();

	my $methods = $config->get("accessmethods");
	my $method;
	if(!exists($methods->{$target})) {
		die "missing method for $target\n";
	}
	$method = $methods->{$target};
	eval "require SReview::Files::Collection::$method";
	if($target eq "input") {
		return "SReview::Files::Collection::$method"->new(globpattern => $relname);
	} else {
		return "SReview::Files::Collection::$method"->new(baseurl => $relname);
	}
}

1;
