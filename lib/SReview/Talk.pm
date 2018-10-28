package SReview::Talk;

use Moose;
use Mojo::Pg;
use Mojo::Template;
use SReview::Config::Common;
use SReview::Talk::State;

my $config = SReview::Config::Common::setup;
my $pg = Mojo::Pg->new->dsn($config->get('dbistring')) or die "Cannot connect to database!";

has 'talkid' => (
	required => 1,
	is => 'rw',
);

has 'pathinfo' => (
	lazy => 1,
	is => 'bare',
	builder => '_load_pathinfo',
	reader => '_get_pathinfo',
);

sub _load_pathinfo {
	my $self = shift;

	my $pathinfo = {};

	my $eventdata = $pg->db->dbh->prepare("SELECT events.id AS eventid, events.name AS event, rooms.name AS room, rooms.outputname AS room_output, rooms.id AS room_id, talks.starttime::date AS date, to_char(starttime, 'DD Month yyyy at HH:MI') AS readable_date, to_char(starttime, 'yyyy') AS year, talks.slug, talks.title, talks.subtitle, talks.state FROM talks JOIN events ON talks.event = events.id JOIN rooms ON rooms.id = talks.room WHERE talks.id = ?");
	$eventdata->execute($self->talkid);
	my $row = $eventdata->fetchrow_hashref();

	$pathinfo->{"workdir"} = join('/', $row->{eventid}, $row->{date}, substr($row->{room}, 0, 1));

	my @elements = ($config->get('outputdir'));
	foreach my $element(@{$config->get('output_subdirs')}) {
		push @elements, $row->{$element};
	}
	$pathinfo->{"finaldir"} = join('/', @elements);

        $pathinfo->{"slug"} = $row->{"slug"};

	$pathinfo->{"raw"} = $row;

	return $pathinfo;
}

has 'date' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_date',
);

sub _load_date {
	return shift->_get_pathinfo->{raw}{date};
}

has 'readable_date' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_readable_date',
);

sub _load_readable_date {
	return shift->_get_pathinfo->{raw}{readable_date};
}

has 'eventname' => (
	lazy => 1,
	is => 'ro',
	builder => '_load_eventname',
);

sub _load_eventname {
	my $self = shift;
	return $self->_get_pathinfo->{raw}{event};
}

has 'state' => (
	lazy => 1,
	is => 'rw',
	isa => 'SReview::Talk::State',
	builder => '_load_state',
);

sub _load_state {
	my $self = shift;
	return SReview::Talk::State->new($self->_get_pathinfo->{raw}{state});
}

has 'title' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_title',
);

sub _load_title {
	my $self = shift;
	return $self->_get_pathinfo->{raw}{title};
}

has 'workdir' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_workdir',
);

sub _load_workdir {
	my $self = shift;
	return join('/', $config->get("pubdir"), $self->_get_pathinfo->{"workdir"});
}

has 'relative_name' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_relative_name',
);

sub _load_relative_name {
	my $self = shift;
	return join('/', $self->_get_pathinfo->{"workdir"}, $self->_get_pathinfo->{'slug'});
}

has 'outname' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_outname',
);

sub _load_outname {
	my $self = shift;
	return join('/', $self->workdir, $self->_get_pathinfo->{"slug"});
}

has 'finaldir' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_finaldir',
);

sub _load_finaldir {
	my $self = shift;
	return $self->_get_pathinfo->{"finaldir"};
}

has 'slug' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_slug',
);

sub _load_slug {
	my $self = shift;
	return $self->_get_pathinfo->{"slug"};
}

has 'corrections' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_corrections',
	clearer => '_clear_corrections',
);

sub _load_corrections {
	my $self = shift;

	my $corrections_data = $pg->db->dbh->prepare("SELECT corrections.talk, properties.name AS property, corrections.property_value FROM corrections LEFT JOIN properties ON corrections.property = properties.id WHERE talk = ?");
	$corrections_data->execute($self->talkid);

	my %corrections;

	while(my $row = $corrections_data->fetchrow_hashref()) {
		my $name = $row->{property};
		my $val = $row->{property_value};
		$corrections{$name} = $val;
	}

	foreach my $prop ("offset_start", "length_adj", "offset_audio") {
		if(!exists($corrections{$prop})) {
			$corrections{$prop} = 0;
		}
	}

	if(!exists($corrections{audio_channel})) {
		$corrections{audio_channel} = 0;
	}

	return \%corrections;
}

has 'video_fragments' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_video_fragments',
);

sub _load_video_fragments {
	my $self = shift;
	my $corrections = $self->corrections;

	my $talk_data = $pg->db->dbh->prepare("SELECT talkid, rawid, raw_filename, extract(epoch from fragment_start) AS fragment_start, extract(epoch from raw_length) as raw_length, extract(epoch from raw_length_corrected) as raw_length_corrected FROM adjusted_raw_talks(?, make_interval(secs :=?::numeric), make_interval(secs := ?::numeric)) ORDER BY talk_start, raw_start");
	$talk_data->execute($self->talkid, $corrections->{"offset_start"}, $corrections->{"length_adj"});

	my $rows;
	while(my $row = $talk_data->fetchrow_hashref()) {
		push @$rows, $row;
	}

	return $rows;
}

has 'speakers' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_speakers',
);

sub _load_speakers {
	my $self = shift;

	my $spk = $pg->db->dbh->prepare("SELECT speakerlist(?)");

	$spk->execute($self->talkid);

	my $row = $spk->fetchrow_arrayref;

	return $row->[0];
}

has 'room' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_room',
);

sub _load_room {
	return shift->_get_pathinfo->{raw}{room};
}

has 'roomid' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_roomid',
);

sub _load_roomid {
	return shift->_get_pathinfo->{raw}{room_id}
}

has 'eventurl' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_eventurl',
);

sub _load_eventurl {
	my $self = shift;
	my $mt = Mojo::Template->new;
	if(defined($config->get('eventurl_format'))) {
		return $mt->vars(1)->render($config->get('eventurl_format'), {
			slug => $self->slug,
			room => $self->room,
			date => $self->date,
			year => $self->_get_pathinfo->{raw}{year}});
	}
	return "";
}

has 'preview_exten' => (
	lazy => 1,
	is => 'ro',
	builder => '_load_preview_exten',
);

# TODO: autodetect this, rather than hardcoding it
sub _load_preview_exten {
	return $config->get('preview_exten');
}

sub correct {
	my $self = shift;
	my %corrections = @_;

	my $update = $pg->db->dbh->prepare('INSERT INTO corrections(property_value, talk, property) VALUES(?, ?, (SELECT id FROM properties WHERE name = ?))');
	foreach my $param(keys %corrections) {
		$update->execute($corrections{$param}, $self->talkid, $param);
	}
	$self->_clear_corrections;
}

sub by_nonce {
	my $klass = shift;
	my $nonce = shift;

	my $st = $pg->db->dbh->prepare("SELECT * FROM talks WHERE nonce = ?");
	$st->execute($nonce);
	return undef unless $st->rows == 1;
	my $row = $st->fetchrow_arrayref;
	my $rv = SReview::Talk->new(talkid => $row->[0]);
	return $rv;
}

no Moose;

1;
