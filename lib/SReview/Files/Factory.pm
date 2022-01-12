package SReview::Files::Base;

use Moose;

has 'is_collection' => (
	isa => 'Bool',
	is => 'ro',
);

has 'url' => (
	isa => 'Str',
	is => 'ro',
	lazy => 1,
	builder => '_probe_url',
);

no Moose;

package SReview::Files::Access::Base;

use Moose;
use DateTime;
use Carp;

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

has 'create' => (
	is => 'rw',
	traits => ['Bool'],
	isa => 'Bool',
	default => 0,
	required => 1,
	handles => {
		has_data => 'not',
	},
);

has 'is_stored' => (
	is => 'ro',
	isa => 'Bool',
	traits => ['Bool'],
	default => 0,
	handles => {
		auto_save => 'unset',
		no_auto_save => 'set',
		stored => 'set',
	},
);

sub _probe_url {
	my $self = shift;

	return join('/', $self->baseurl, $self->relname);
}

sub DESTROY {
	my $self = shift;
	if($self->create) {
		if(!$self->is_stored) {
			carp "object destructor for '" . $self->url . "' entered without an explicit store, storing now...";
			$self->store_file;
		}
	}
}

no Moose;

package SReview::Files::Access::direct;

use Moose;
use DateTime;
use File::Path qw/make_path/;
use File::Basename qw/dirname/;

extends 'SReview::Files::Access::Base';

sub _get_file {
	my $self = shift;

	if($self->create) {
		make_path(dirname($self->url));
		unlink($self->url);
	}
	return $self->url;
}

sub store_file {
	my $self = shift;
	$self->stored;
	return 1;
}

sub _probe_mtime {
	my $self = shift;
	my @stat = stat($self->filename);

	return DateTime->from_epoch(epoch => $stat[9]);
}

sub delete {
	my $self = shift;

	unlink($self->url);
}

sub valid_path_filename {
	my $self = shift;

	return $self->url;
}

no Moose;

package SReview::Files::Collection::Base;

use Moose;
use Carp;

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
	writer => '_set_baseurl',
	lazy => 1,
	builder => '_probe_baseurl',
);

has 'globpattern' => (
	isa => 'Str',
	is => 'ro',
	predicate => 'has_globpattern',
	lazy => 1,
	builder => '_probe_globpattern',
);

has 'fileclass' => (
	isa => 'Str',
	is => 'ro',
	required => 1,
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

sub _probe_url {
	return shift->baseurl;
}

sub _probe_globpattern {
	my $self = shift;

	if(!$self->has_baseurl) {
		croak("either a globpattern or a baseurl are required!\n");
	}
	return join('/', $self->baseurl, '*');
}

sub _create {
	my $self = shift;
	my %options = @_;

	if(exists($options{fullname})) {
		if(substr($options{fullname}, 0, length($self->baseurl)) ne $self->baseurl) {
			croak($options{fullname} . " is not accessible through this collection");
		}
		$options{relname} = substr($options{fullname}, length($self->baseurl));
		while(substr($options{relname}, 0, 1) eq '/') {
			$options{relname} = substr($options{relname}, 1);
		}
		delete $options{fullname};
	}

	$options{baseurl} = $self->baseurl;

	my $fileclass = $self->fileclass;

	return "$fileclass"->new(%options);
}

sub get_file {
	my $self = shift;
	my %options = @_;

	$options{create} = 0;

	return $self->_create(%options);
}

sub add_file {
	my $self = shift;
	my %options = @_;

	$options{create} = 1;

	return $self->_create(%options);
}

sub has_file {
	my $self = shift;
	my $target = shift;

	return scalar(grep({(!$_->is_collection) && ($_->relname eq $target)} @{$self->children}));
}

sub delete_files {
	my $self = shift;
	my %options = @_;

	my @names;
	if(exists($options{files})) {
		@names = sort(@{$options{files}});
	} elsif(exists($options{relnames})) {
		@names = map({join('/', $self->baseurl, $_)} sort(@{$options{relnames}}));
	} else {
		croak("need list of files, or list of relative names");
	}
	my @ownfiles = sort({$a->url cmp $b->url} @{$self->children});
	my @to_delete = ();

	while(scalar(@names) && scalar(@ownfiles)) {
		if($ownfiles[0]->is_collection) {
			if($names[0] eq $ownfiles[0]->baseurl) {
				push @to_delete, shift @ownfiles;
				shift @names;
			} elsif(substr($names[0], 0, length($ownfiles[0]->baseurl)) eq $ownfiles[0]->baseurl) {
				$ownfiles[0]->delete_files(files => [$names[0]]);
				shift @names;
			}
			shift @ownfiles;
		} elsif($names[0] eq $ownfiles[0]->url) {
			shift @names;
			push @to_delete, shift @ownfiles;
		} elsif($names[0] eq substr($ownfiles[0]->url, 0, length($names[0]))) {
			push @to_delete, shift @ownfiles;
			if((!scalar(@ownfiles)) || $names[0] lt $ownfiles[0]->url) {
				shift @names;
			}
		} elsif ($names[0] gt $ownfiles[0]->url) {
			shift @ownfiles;
		} else {
			carp "${names[0]} is not a member of this collection, ignored";
			shift @names;
		}
	};
	if(scalar(@names)) {
		carp "${names[0]} is not a member of this collection, ignored";
	}
	foreach my $file(@to_delete) {
		$file->delete;
	}
}

sub delete {
	my $self = shift;

	foreach my $child(@{$self->children}) {
		$child->delete;
	}
}

no Moose;

package SReview::Files::Collection::direct;

use Moose;
use File::Basename;
use Carp;

extends 'SReview::Files::Collection::Base';

has '+fileclass' => (
	default => 'SReview::Files::Access::direct',
);

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

sub has_file {
	my ($self, $target) = @_;

	if(-f join('/', $self->baseurl, $target)) {
		return 1;
	}
	return 0;
}

sub delete {
	my $self = shift;

	$self->SUPER::delete;
	rmdir($self->baseurl);
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
	eval "require SReview::Files::Collection::$method;";
	if($@) {
		die "$@: $!";
	}
	if($target eq "input") {
		return "SReview::Files::Collection::$method"->new(globpattern => $relname);
	} else {
		return "SReview::Files::Collection::$method"->new(baseurl => $relname);
	}
}

1;
