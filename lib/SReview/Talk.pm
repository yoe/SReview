package SReview::Talk;

use Moose;
use Mojo::Pg;
use SReview::Config::Common;

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

has 'workdir' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_workdir',
);

has 'outname' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_outname',
);

has 'finaldir' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_finaldir',
);

has 'slug' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_slug',
);

has 'corrections' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_corrections',
);

has 'video_fragments' => (
	lazy => 1,
	is => 'rw',
	builder => '_load_video_fragments',
);


sub _load_workdir {
	my $self = shift;
	return $self->_get_pathinfo->{"workdir"};
}

sub _load_outname {
	my $self = shift;
	return join('/', $self->_get_pathinfo->{"workdir"}, $self->_get_pathinfo->{"slug"});
}

sub _load_finaldir {
	my $self = shift;
	return $self->_get_pathinfo->{"finaldir"};
}

sub _load_slug {
	my $self = shift;
	return $self->_get_pathinfo->{"slug"};
}

sub _load_pathinfo {
	my $self = shift;

	my $pathinfo = {};

	my $eventname = $pg->db->dbh->prepare("SELECT events.id AS eventid, events.name AS event, rooms.name AS room, rooms.outputname AS room_output, talks.starttime::date AS date, to_char(starttime, 'yyyy') AS year, talks.slug FROM talks JOIN events ON talks.event = events.id JOIN rooms ON rooms.id = talks.room WHERE talks.id = ?");
	$eventname->execute($self->talkid);
	my $row = $eventname->fetchrow_hashref();

        $pathinfo->{"workdir"} = join('/', $config->get('pubdir'), $row->{eventid}, $row->{date}, substr($row->{room}, 0, 1));

	my @elements = ($config->get('outputdir'));
	foreach my $element(@{$config->get('output_subdirs')}) {
		push @elements, $row->{$element};
	}
	$pathinfo->{"finaldir"} = join('/', @elements);

        $pathinfo->{"slug"} = $row->{"slug"};

	return $pathinfo;
}

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


no Moose;

1;
