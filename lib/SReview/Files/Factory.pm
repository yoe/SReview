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
			$child = SReview::Files::Collection::direct->new(baseurl => join("/", $self->baseurl, basename($file)), download_verbose => $self->download_verbose);
		} else {
			my $basename = substr($file, length($self->baseurl));
			while(substr($basename, 0, 1) eq '/') {
				$basename = substr($basename, 1);
			}
			$child = SReview::Files::Access::direct->new(baseurl => $self->baseurl, relname => $basename, download_verbose => $self->download_verbose);
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
		return "SReview::Files::Collection::$method"->new(globpattern => $relname, collection_name => $target);
	} else {
		return "SReview::Files::Collection::$method"->new(baseurl => $relname, collection_name => $target);
	}
}

1;

__END__

=head1 NAME

SReview::Files::Factory

=head1 SYNOPSIS

  my $config = SReview::Config::Common::setup();
  my $collection = SReview::Files::Factory->create("input", $config->get("inputglob"), $config);
  my $contents = $collection->children;

  NAME:
  foreach my $name(@$contents) {
        next NAME if($name->is_collection);
        print $name->url . "\n";
  }

=head1 DESCRIPTION

This module is used internally by SReview to abstract access to files.

The C<Factory> class contains an implementation for direct (i.e.,
through the filesystem) access to files. Alternative implementations
exist for other access methods (through HTTP, S3, SSH, etc.) as separate
modules.


