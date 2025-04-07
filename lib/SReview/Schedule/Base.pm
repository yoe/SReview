package SReview::Schedule::Base::Speaker;

use Moose;

has 'talk_object' => (
	is => 'ro',
	isa => 'SReview::Schedule::Base::Talk',
	weak_ref => 1,
	required => 1,
);

has 'name' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => '_load_name',
);

has 'email' => (
	is => 'ro',
	isa => 'Maybe[Str]',
	lazy => 1,
	builder => '_load_email',
);

sub _load_email {
	return undef;
}

has 'upstreamid' => (
	is => 'ro',
	isa => 'Maybe[Str]',
	lazy => 1,
	builder => '_load_upstreamid',
);

sub _load_upstreamid {
	return undef;
}

no Moose;

package SReview::Schedule::Base::Room;

use Moose;

has 'event_object' => (
	is => 'ro',
	isa => 'SReview::Schedule::Base::Event',
	weak_ref => 1,
	required => 1,
);

has 'name' => (
	is => 'ro',
	isa => 'Maybe[Str]',
	lazy => 1,
	builder => '_load_name',
);

sub _load_name {
	return undef;
}

has 'altname' => (
	is => 'rw',
	isa => 'Maybe[Str]',
	lazy => 1,
	builder => '_load_altname',
);

sub _load_altname {
	return undef;
}

has 'outputname' => (
	is => 'rw',
	isa => 'Maybe[Str]',
	lazy => 1,
	builder => '_load_outputname',
);

sub _load_outputname {
	return undef;
}

package SReview::Schedule::Base::Track;

use Moose;
use Mojo::Util 'slugify';

has 'talk_object' => (
	is => 'ro',
	isa => 'SReview::Schedule::Base::Talk',
	weak_ref => 1,
	required => 1,
);

has 'name' => (
	is => 'ro',
	isa => 'Maybe[Str]',
	lazy => 1,
	builder => '_load_name',
);

sub _load_name {
	return undef;
}

has 'email' => (
	is => 'ro',
	isa => 'Maybe[Str]',
	lazy => 1,
	builder => '_load_email',
);

sub _load_email {
	return undef;
}

has 'upstreamid' => (
	is => 'ro',
	isa => 'Maybe[Str]',
	lazy => 1,
	builder => '_load_upstreamid',
);

sub _load_upstreamid {
	return slugify(shift->name);
}

package SReview::Schedule::Base::Talk;

use Moose;
use Mojo::Util 'slugify';
use DateTime;
use DateTime::Duration;

has 'event_object' => (
	is => 'ro',
	isa => 'SReview::Schedule::Base::Event',
	weak_ref => 1,
	required => 1,
);

has 'room' => (
	is => 'ro',
	isa => 'SReview::Schedule::Base::Room',
	lazy => 1,
	builder => '_load_room',
);

sub _load_room {
	my $self = shift;
	return $self->event_object->root_object->room_type->new(event_object => $self->event_object);
}

has 'slug' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => '_load_slug',
);

sub _load_slug {
	my $self = shift;
	return substr(slugify($self->title), 0, 40);
}

has 'starttime' => (
	is => 'ro',
	isa => 'DateTime',
	lazy => 1,
	builder => '_load_starttime',
);

sub _load_starttime {
	return DateTime->now;
}

has 'endtime' => (
	is => 'ro',
	isa => 'DateTime',
	lazy => 1,
	builder => '_load_endtime',
);

sub _load_endtime {
	my $self = shift;
	my $start = $self->starttime;
	my $tz = $start->time_zone;
	$start->set_time_zone('UTC');
	my $end = $self->starttime + $self->length;
	$start->set_time_zone($tz);
	$end->set_time_zone($tz);
	return $end;
}

has 'length' => (
	is => 'ro',
	isa => 'DateTime::Duration',
	lazy => 1,
	builder => '_load_length',
);

sub _load_length {
	return DateTime::Duration->new(hours => 1);
}

has 'title' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => '_load_title',
);

sub _load_title {
	return "";
}

has 'upstreamid' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => '_load_upstreamid',
);

sub _load_upstreamid {
	return shift->slug;
}

has 'subtitle' => (
	is => 'ro',
	isa => 'Maybe[Str]',
	lazy => 1,
	builder => '_load_subtitle',
);

sub _load_subtitle {
	return undef;
}

has 'track' => (
	is => 'ro',
	isa => 'Maybe[SReview::Schedule::Base::Track]',
	lazy => 1,
	builder => '_load_track',
);

sub _load_track {
	return undef;
}

has 'description' => (
	is => 'ro',
	isa => 'Maybe[Str]',
	lazy => 1,
	builder => '_load_description',
);

sub _load_description {
	return undef;
}

has 'flags' => (
	is => 'ro',
	isa => 'Maybe[HashRef[Bool]]',
	lazy => 1,
	builder => '_load_flags',
);

sub _load_flags {
	return undef;
}

has 'speakers' => (
	is => 'ro',
	isa => 'Maybe[ArrayRef[SReview::Schedule::Base::Speaker]]',
	lazy => 1,
	builder => '_load_speakers',
);

sub _load_speakers {
	return [];
}

has 'filtered' => (
	is => 'ro',
	isa => 'Bool',
	lazy => 1,
	builder => '_load_filtered',
);

sub _load_filtered {
	return 0;
}

no Moose;

package SReview::Schedule::Base::Event;

use Moose;
use Moose::Util::TypeConstraints;
use DateTime::TimeZone;

has 'root_object' => (
	isa => 'SReview::Schedule::Base',
	is => 'ro',
	weak_ref => 1,
	required => 1,
);

has 'talks' => (
	is => 'ro',
	lazy => 1,
	isa => 'ArrayRef[SReview::Schedule::Base::Talk]',
	builder => '_load_talks',
);

sub _load_talks {
	return [];
}

has 'name' => (
	is => 'ro',
	lazy => 1,
	isa => 'Str',
	builder => '_load_name',
);

sub _load_name {
	return "";
}

class_type "DateTime::TimeZone";
coerce "DateTime::TimeZone",
        from "Str",
        via  { DateTime::TimeZone->new(name => $_) };

has 'timezone' => (
	is => 'ro',
	isa => 'DateTime::TimeZone',
	lazy => 1,
        coerce => 1,
	builder => '_load_timezone',
);

sub _load_timezone {
	return DateTime::TimeZone->new(name => 'local');
}

package SReview::Schedule::Base;

use Moose;
use Mojo::UserAgent;
use Mojo::URL;

has 'url' => (
	required => 1,
	is => 'ro',
);

has 'timezone' => (
	is => 'ro',
	isa => 'Maybe[Str]',
	predicate => 'has_timezone',
);

has '_raw' => (
	lazy => 1,
	builder => '_load_raw',
	is => 'bare',
	reader => '_get_raw',
);

sub _load_raw {
	my $self = shift;
	my $ua = Mojo::UserAgent->new;
	$ua->proxy->detect;
	my $url = Mojo::URL->new($self->url);
	if($url->scheme eq "file") {
		local $/ = undef;
		open my $f, "<", $url->host . $url->path;
		my $rv = <$f>;
		close $f;
		return $rv;
	}
	my $res = $ua->get($self->url)->result;
	die "Could not access " . $self->url . ": " . $res->code . " " . $res->message unless $res->is_success;
	return $res->body;
}

has 'speaker_type' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => '_load_speaker_type',
);

sub _load_speaker_type {
	return 'SReview::Schedule::Base::Speaker';
}

has 'room_type' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => '_load_room_type',
);

sub _load_room_type {
	return 'SReview::Schedule::Base::Room';
}

has 'track_type' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => '_load_track_type',
);

sub _load_track_type {
	return 'SReview::Schedule::Base::Track';
}

has 'talk_type' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => '_load_talk_type',
);

sub _load_talk_type {
	return 'SReview::Schedule::Base::Talk';
}

has 'event_type' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => '_load_event_type',
);

sub _load_event_type {
	return 'SReview::Schedule::Base::Event';
}

has 'events' => (
	is => 'ro',
	isa => 'ArrayRef[SReview::Schedule::Base::Event]',
	lazy => 1,
	builder => '_load_events',
);

sub _load_events {
	return [];
}

no Moose;
1;
