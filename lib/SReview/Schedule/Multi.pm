package SReview::Schedule::Multi::ShadowTalk;

use Moose;
use SReview::Schedule::Base;

extends 'SReview::Schedule::Base::Talk';

has 'parent' => (
	is => 'ro',
	isa => 'SReview::Schedule::Base::Talk',
	required => 1,
);

has 'prefix' => (
	is => 'ro',
	isa => 'Str',
	default => '',
);

has 'suffix' => (
	is => 'ro',
	isa => 'Str',
	default => '',
);

sub _load_room {
	return shift->parent->room;
}

sub _load_slug {
	return shift->parent->slug;
}

sub _load_starttime {
	return shift->parent->starttime;
}

sub _load_endtime {
	return shift->parent->endtime;
}

sub _load_length {
	return shift->parent->length;
}

sub _load_title {
	my $self = shift;
	return $self->prefix . $self->parent->title . $self->suffix;
}

sub _load_upstreamid {
	return shift->parent->upstreamid;
}

sub _load_subtitle {
	return shift->parent->subtitle;
}

sub _load_track {
	return shift->parent->track;
}

sub _load_description {
	return shift->parent->description;
}

sub _load_flags {
	return shift->parent->flags;
}

sub _load_speakers {
	return shift->parent->speakers;
}

sub _load_filtered {
	return shift->parent->filtered;
}

no Moose;

package SReview::Schedule::Multi::ShadowEvent;

use Moose;
use SReview::Schedule::Base;

extends 'SReview::Schedule::Base::Event';

has 'talk_prefix' => (
	is => 'ro',
	isa => 'Str',
);

has 'talk_suffix' => (
	is => 'ro',
	isa => 'Str',
);

has 'parent' => (
	is => 'ro',
	isa => 'SReview::Schedule::Base::Event',
	required => 1,
);

has 'event_prefix' => (
	is => 'ro',
	isa => 'Str',
	default => '',
);

has 'event_suffix' => (
	is => 'ro',
	isa => 'Str',
	default => '',
);

sub _load_talks {
	my $self = shift;
	my $rv = [];
	foreach my $talk(@{$self->parent->talks}) {
		push @$rv, SReview::Schedule::Multi::ShadowTalk->new(parent => $talk, prefix => $self->talk_prefix, suffix => $self->talk_suffix);
	}
	return $rv;
}

sub _load_name {
	my $self = shift;
	return $self->event_prefix . $self->parent->name . $self->event_suffix;
}

package SReview::Schedule::Multi;

use Moose;
use SReview::Schedule::Base;

extends 'SReview::Schedule::Base';

has 'base_type' => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

has 'base_options' => (
	is => 'ro',
	isa => 'HashRef[Any]',
);

has 'shadows' => (
	is => 'ro',
	isa => 'ArrayRef[HashRef[Str]]',
	required => 1,
);

sub _load_events {
	my $self = shift;
	my $rv_type = "SReview::Schedule::" . ucfirst($self->base_type);
	eval "require $rv_type;" or die $!;
	my $opts = $self->base_options;
	$opts = {} unless defined($opts);
	$opts->{url} = $self->url;
	my $base_parser = "$rv_type"->new(%$opts);
	my $rv = [];
	foreach my $event(@{$base_parser->events}) {
		push @$rv, $event;
		foreach my $shadow(@{$self->shadows}) {
			push @$rv, SReview::Schedule::Multi::ShadowEvent->new(parent => $event, %$shadow);
		}
	}
	return $rv;
}

1;
