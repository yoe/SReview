package SReview::Schedule::Wafer::Talk;

use Moose;
use Mojo::Util 'slugify';

extends 'SReview::Schedule::Penta::Talk';

has 'conf_url' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => '_load_conf_url',
);

sub _load_conf_url {
	return shift->xml_helper('conf_url');
}

sub _load_upstreamid {
	my $rv = [split(/-/, shift->slug)];
	return $rv->[0];
}

sub _load_slug {
	my $self = shift;
	my $rv = [split('/', $self->conf_url)];
	if(scalar(@$rv) > 2) {
		return $rv->[2];
	}
	return slugify($self->conf_url);
}

sub _load_speakers {
	my $self = shift;

	return [] if (grep(/^persons$/, $self->schedref->children_names) == 0);
	return $self->SUPER::_load_speakers;
}

sub _load_filtered {
	my $self = shift;

	my @elems = split('/', $self->conf_url);
	return 1 if scalar(@elems) < 3;

	return 0;
}

no Moose;

package SReview::Schedule::Wafer;

use Moose;
use SReview::Schedule::Penta;

extends 'SReview::Schedule::Penta';

sub _load_talktype {
	return 'SReview::Schedule::Wafer::Talk';
}

no Moose;

1;
