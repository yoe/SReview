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

has 'talk_opts' => (
	is => 'ro',
	isa => 'HashRef',
	default => sub { {} },
);

sub _load_talks {
	my $self = shift;
	my $rv = [];
	my $opts = $self->talk_opts;
	foreach my $talk(@{$self->parent->talks}) {
		push @$rv, SReview::Schedule::Multi::ShadowTalk->new(parent => $talk, prefix => $self->talk_prefix, suffix => $self->talk_suffix, %$opts);
	}
	return $rv;
}

sub _load_name {
	my $self = shift;
	return $self->event_prefix . $self->parent->name . $self->event_suffix;
}

package SReview::Schedule::Multi;

=head1 NAME

SReview::Schedule::Multi - system to duplicate event parsing into a main and a shadow one.

=head1 SYNOPSIS

  $schedule_format = "multi";
  $schedule_options = { url => "http://...", base_type => "penta", base_options => {},
      shadows => [{ talk_prefix => "Video for talk '", talk_suffix => "'",
                    event_prefix => "Videos for event '", event_suffix => "'", talk_opts => {} }]};

=head1 DESCRIPTION

SReview::Schedule::Multi is a schedule parser for L<sreview-import> that
creates "shadow" events based on a base event. This can be used in case
multiple events are required in SReview for an upstream event (e.g., one
for preprocessing, and one for postprocessing).

=head1 OPTIONS

SReview::Schedule::Multi takes the following options:

=head2 base_type

The type of the parser of the base event. Must be another
C<SReview::Schedule::> parser. Required.

=head2 base_options

Any options, other than the C<url> option, to be passed to the base
parser to configure it. Optional.

=head2 url

The URL of the schedule. Passed on, unmodified, to the base parser.

=head2 shadows

An array of hashes, one for each shadow event that is to be created.

Each hash can have the following options:

=head3 event_prefix

A string that will be prepended to the event's name.

=head3 event_suffix

A string that will be appended to the event's name.

=head3 talk_prefix

A string that will be prepended to each and every talk's title.

=head3 talk_suffix

A string that will be appended to each and every talk's title.

=head3 talk_opts

Extra properties to be sent to the SReview::Schedule::<base_type>::Talk
object at creation time. This can be used to override certain properties
of the talk, e.g., the flags.

=head1 SEE ALSO

L<SReview::Schedule::Penta>, L<SReview::Schedule::Wafer>

=cut

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
	isa => 'ArrayRef[HashRef[Any]]',
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
