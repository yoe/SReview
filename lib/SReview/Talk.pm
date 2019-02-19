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
	is => 'ro',
        trigger => sub {
                my $self = shift;
                my $val = shift;
                my $st = $pg->db->dbh->prepare("SELECT count(*) FROM talks WHERE id = ?");
                $st->execute($val);
                die "Talk does not exist.\n" unless $st->rows == 1;
        },
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

	my $eventdata = $pg->db->dbh->prepare("SELECT events.id AS eventid, events.name AS event, rooms.name AS room, rooms.outputname AS room_output, rooms.id AS room_id, talks.starttime::date AS date, to_char(starttime, 'DD Month yyyy at HH:MI') AS readable_date, to_char(starttime, 'yyyy') AS year, talks.slug, talks.title, talks.subtitle, talks.state, talks.nonce, talks.apologynote FROM talks JOIN events ON talks.event = events.id JOIN rooms ON rooms.id = talks.room WHERE talks.id = ?");
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

has 'apology' => (
        lazy => 1,
        is => 'rw',
        builder => '_load_apology',
        predicate => 'has_apology',
);

sub _load_apology {
        return shift->_get_pathinfo->{raw}{apologynote};
}

has 'comment' => (
        lazy => 1,
        is => 'rw',
        builder => '_load_comment',
        predicate => 'has_comment',
);

sub _load_comment {
        my $self = shift;
        my $st = $pg->db->dbh->prepare("SELECT comments FROM talks WHERE id = ?");
        $st->execute($self->talkid);
        my $row = $st->fetchrow_hashref;
        return $row->{comments};
}

has 'corrected_times' => (
        lazy => 1,
        is => 'ro',
        builder => '_load_corrected_times',
);

sub _load_corrected_times {
        my $self = shift;

        my $times = {};

        my $st = $pg->db->dbh->prepare("SELECT starttime, endtime from talks WHERE id = ?");

        $st->execute($self->talkid);

        die "talk lost" unless $st->rows > 0;

        my $row = $st->fetchrow_hashref();
        $times->{start} = $row->{starttime};
        $times->{end} = $row->{endtime};

        $st = $pg->db->dbh->prepare("SELECT coalesce(talks.starttime + (corrections.property_value || ' seconds')::interval, talks.starttime) AS corrected_time, to_char(coalesce(talks.starttime + (corrections.property_value || ' seconds')::interval, talks.starttime), 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS isotime  FROM talks LEFT JOIN corrections ON talks.id = corrections.talk LEFT JOIN properties ON properties.id = corrections.property AND properties.name = 'offset_start' WHERE talks.id = ?");
        $st->execute($self->talkid);
        if($st->rows > 0) {
                $row = $st->fetchrow_hashref();
                $times->{start} = $row->{corrected_time};
                $times->{start_iso} = $row->{isotime};
        }
        $st = $pg->db->dbh->prepare("SELECT corrected_time, to_char(corrected_time, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS isotime FROM (select ?::timestamptz + (talks.endtime - talks.starttime) + (coalesce(corrections.property_value, '0') || ' seconds')::interval AS corrected_time FROM talks LEFT JOIN corrections ON talks.id = corrections.talk LEFT JOIN properties ON properties.id = corrections.property AND properties.name = 'length_adj' WHERE talks.id = ?) AS sq");
        $st->execute($times->{start}, $self->talkid);
        if($st->rows > 0) {
                $row = $st->fetchrow_hashref();
                $times->{end} = $row->{corrected_time};
                $times->{end_iso} = $row->{isotime};
        }
        return $times;
}

has 'nonce' => (
        is => 'rw',
        builder => '_load_nonce',
        lazy => 1,
);

sub _load_nonce {
        return shift->_get_pathinfo->{raw}{nonce};
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
        traits => ['Hash'],
        isa => 'HashRef[Str]',
	lazy => 1,
	is => 'rw',
	builder => '_load_corrections',
	clearer => '_clear_corrections',
        handles => {
                has_correction => 'exists',
                set_correction => 'set',
                clear_correction => 'delete',
                correction_pairs => 'kv',
        },
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

sub by_nonce {
	my $klass = shift;
	my $nonce = shift;

	my $st = $pg->db->dbh->prepare("SELECT * FROM talks WHERE nonce = ?");
	$st->execute($nonce);
	die "Talk does not exist.\n" unless $st->rows == 1;
	my $row = $st->fetchrow_arrayref;
	my $rv = SReview::Talk->new(talkid => $row->[0], nonce => $nonce);
	return $rv;
}

sub add_correction {
        my $self = shift;
        my $corrname = shift;
        my $value = shift;

        if($self->has_correction($corrname)) {
                $value = $self->corrections->{$corrname} + $value;
        }
        $self->set_correction($corrname, $value);
}

sub done_correcting {
        my $self = shift;

        my $db = $pg->db->dbh;
        my $st = $db->prepare("INSERT INTO corrections(talk, property, property_value) VALUES (?, (SELECT id FROM properties WHERE name = ?), ?)");

        $self->add_correction(serial => 1);
        my $corrs = $self->corrections;
        my $start = $corrs->{offset_start};
        my $end = $corrs->{offset_end};
        $start = 0 unless defined $start;
        $end = 0 unless defined $end;
        $self->set_correction(length_adj => $end - $start);
        foreach my $pair($self->correction_pairs) {
                $st->execute($self->talkid, $pair->[0], $pair->[1]);
        }
        if($self->has_comment) {
                $db->prepare("UPDATE talks SET comments=? WHERE id = ?")->execute($self->comment, $self->talkid);
        }
}

sub set_state {
        my $self = shift;
        my $newstate = shift;

        my $st = $pg->db->dbh->prepare("UPDATE talks SET state=?, progress='waiting' WHERE id=?");
        $st->execute($newstate, $self->talkid);
}

sub state_done {
        my $self = shift;
        my $state = shift;

        my $st = $pg->db->dbh->prepare("UPDATE talks SET progress='done' WHERE state = ? AND id = ?");
        $st->execute($state, $self->talkid);
}

sub reset_corrections {
        my $self = shift;

        $self->add_correction(serial => 1);
        $pg->db->dbh->prepare("DELETE FROM corrections WHERE talk = ? AND property NOT IN (SELECT id FROM properties WHERE name = 'serial')")->execute($self->talkid) or die $!;
}

no Moose;

1;
