package SReview::Schedule::Penta::Talk;

use Moose;
use DateTime;
use DateTime::Format::ISO8601;
use DateTime::Duration;

extends 'SReview::Schedule::Base::Talk';

has 'schedref' => (
	is => 'ro',
	isa => 'Ref',
	required => 1,
);

has 'day' => (
	is => 'ro',
	isa => 'DateTime',
	required => 1,
);

sub _load_slug {
	return shift->schedref->child('slug')->value();
}

sub _load_starttime {
	my $self = shift;
	my $rv = DateTime::Format::ISO8601->parse_datetime($self->day);
	my $time = $self->schedref->child('start')->value();
	my $dur;
	if($time =~ /^([0-9]{2}):([0-9]{2})$/) {
		$dur = DateTime::Duration->new(hours => $1, minutes => $2);
	} else {
		die "Could not parse starttime: <start> attribute of talk \"" . $self->title . "\" does not parse as time";
	}
	$rv->add_duration($dur);
	return $rv;
}

sub _load_length {
	my $self = shift;
	my $time = $self->schedref->child('duration')->value();
	if($time =~ /^([0-9]{2}):([0-9]{2})$/) {
		return DateTime::Duration->new(hours => $1, minutes => $2);
	}
	die "Could not parse duration: <duration> attribute of talk \"" . $self->title . "\" does not parse as time";
}

sub xml_helper($$) {
	my $self = shift;
	my $name = shift;
	my $rv = $self->schedref->child($name);
	return $rv->value if defined($rv);
	return undef;
}

sub _load_title {
	return shift->xml_helper('title');
}

sub _load_upstreamid {
	return shift->schedref->attribute('id');
}

sub _load_subtitle {
	return shift->xml_helper('subtitle');
}

sub _load_track {
	my $track = shift->xml_helper('track');
	return SReview::Schedule::Base::Track->new(name => $track) if defined($track);
	return undef;
}

sub _load_description {
	return shift->xml_helper('description');
}

sub _load_speakers {
	my $self = shift;
	my $rv = [];

	foreach my $person($self->schedref->child('persons')->children('person')) {
		next if $person eq '';
		push @$rv, SReview::Schedule::Base::Speaker->new(name => $person->value(), upstreamid => $person->attribute('id'));
	}
	return $rv;
}

no Moose;

package SReview::Schedule::Penta::Event;

use Moose;
use DateTime::Format::ISO8601;

extends 'SReview::Schedule::Base::Event';

has 'schedref' => (
	is => 'ro',
	isa => 'Ref',
	required => 1,
);

has 'talktype' => (
	is => 'ro',
	isa => 'Str',
	default => 'SReview::Schedule::Penta::Talk',
);

sub _load_name {
	return shift->schedref->child('conference')->child('title')->value();
}

sub _load_talks {
	my $self = shift;
	my $rv = [];
	my %rooms;
	my $talktype = $self->talktype;
	return $rv unless(grep(/^day$/, $self->schedref->children_names));
	foreach my $day($self->schedref->children('day')) {
		my $dt = DateTime::Format::ISO8601->parse_datetime($day->attribute('date'));
		next unless(grep(/^room$/, $day->children_names));
		foreach my $room($day->children('room')) {
			my $roomname = $room->attribute('name');
			if(!exists($rooms{$roomname})) {
				$rooms{$roomname} = SReview::Schedule::Base::Room->new(name => $roomname);
			}
			next unless (grep(/^event$/, $room->children_names) == 1);
			foreach my $talk($room->children('event')) {
				push @$rv, "$talktype"->new(room => $rooms{$roomname}, schedref => $talk, day => $dt);
			}
		}
	}
	return $rv;
}

package SReview::Schedule::Penta;

=head1 NAME

SReview::Schedule::Penta - sreview-import schedule parser for the Pentabarf XML format

=head1 SYNOPSIS

  $schedule_format = "multi";
  $schedule_options = { url => "http://..." };

=head1 DESCRIPTION

This module is a schedule parser for L<sreview-import> that converts a
Pentabarf XML schedule format into the objects expected by
sreview-import.

Note that the Pentabarf XML files as created by the Wafer conference
management tool is subtly different in ways that matter for SReview. To
parse a Wafer file, see SReview::Schedule::Wafer.

=head1 OPTIONS

C<SReview::Schedule::Penta> only supports one option:

=head2 url

The URL where the schedule can be found.

=head1 SEE ALSO

L<SReview::Schedule::Multi>, L<SReview::Schedule::Wafer>

=cut

use Moose;
use XML::SimpleObject;
use SReview::Schedule::Base;

extends 'SReview::Schedule::Base';

has 'talktype' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => '_load_talktype',
);

sub _load_talktype {
	return 'SReview::Schedule::Penta::Talk';
}

has 'eventtype' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => '_load_eventtype',
);

sub _load_eventtype {
	return 'SReview::Schedule::Penta::Event';
}

sub _load_events {
	my $self = shift;
	my $xml = XML::SimpleObject->new(XML => $self->_get_raw);
	my %args = (
		schedref => $xml->child('schedule'),
		talktype => $self->talktype,
	);
	if($self->has_timezone) {
		$args{timezone} = $self->timezone;
	}
	return [$self->eventtype->new(%args)];
}

1;
