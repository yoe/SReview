package SReview::Files::Access::S3;

use Moose;
use File::Temp qw/tempfile tempdir mktemp/;
use File::Path qw/make_path/;
use File::Basename;
use DateTime::Format::ISO8601;

extends 'SReview::Files::Access::Base';

has 's3object' => (
	is => 'ro',
	required => 1,
	isa => 'Net::Amazon::S3::Bucket',
);

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
		my ($fh, $file) = tempfile("s3-XXXXXX", dir => $dir, SUFFIX => ".$ext");
		$self->s3object->get_key_filename($self->relname, "GET", $file);
		return $file;
	} else {
		my $file = join("/", $self->workdir, basename($self->relname));
		return $file;
	}
}

sub _probe_mtime {
	my $self = shift;
	my $meta = $self->s3object->head_key($self->relname);

	return DateTime::Format::ISO8601->parse_datetime($meta->{last_modified});
}

sub store_file {
	my $self = shift;
	return if(!$self->has_download);

	$self->s3object->add_key_filename($self->relname, $self->filename, {}) or croak($self->s3object->errstr);

	$self->stored;
}

sub valid_path_filename {
	my $self = shift;

	my $path = join('/', $self->workdir, $self->relname);
	make_path(dirname($path));
	symlink($self->filename, $path);
	return $path;
}

sub DESTROY {
	my $self = shift;
	$self->SUPER::DESTROY();
	if($self->has_download) {
		unlink($self->filename);
	}
}

no Moose;

package SReview::Files::Collection::S3;

use Moose;
use Net::Amazon::S3;
use DateTime::Format::ISO8601;
use SReview::Config::Common;

extends "SReview::Files::Collection::Base";

has 's3object' => (
	is => 'ro',
	isa => 'Net::Amazon::S3::Bucket',
	lazy => 1,
	builder => '_probe_s3obj',
);

has '+fileclass' => (
	default => 'SReview::Files::Access::S3',
);

sub _probe_s3obj {
	my $self = shift;
	my $config = SReview::Config::Common::setup();
	my $bucket;
	if($self->has_baseurl) {
		$bucket = $self->baseurl;
	} else {
		my @elements = split('\/', $self->globpattern);
		do {
			$bucket = shift(@elements)
		} while(!length($bucket));
		$self->_set_baseurl($bucket);
	}
	my $aconf = $config->get('s3_access_config');
	if(exists($aconf->{$bucket})) {
		$aconf = $aconf->{$bucket};
	} else {
		if(!exists($aconf->{default})) {
			croak("S3 access configuration does not exist for $bucket, and nor does a default exist");
		}
		$aconf = $aconf->{default};
	}
	return Net::Amazon::S3->new($aconf)->bucket($bucket);
}

sub _probe_children {
	my $self = shift;
	my $return = [];
	my $baseurl;

	foreach my $key(@{$self->s3object->list_all->{keys}}) {
		push @$return, SReview::Files::Access::S3->new(
			s3object => $self->s3object,
			baseurl => $self->baseurl,
			mtime => DateTime::Format::ISO8601->parse_datetime($key->{last_modified}),
			relname => $key->{key},
		);
	}
	return $return;
}

sub _create {
	my $self = shift;
	my %options = @_;

	$options{s3object} = $self->s3object;

	return $self->SUPER::_create(%options);
}

no Moose;

1;
