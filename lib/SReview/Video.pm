package SReview::Video;

use Mojo::JSON qw(decode_json);

use Moose;

has 'url' => (
	is => 'rw',
	required => 1,
);
has 'duration' => (
	is => 'rw',
	builder => '_probe_duration',
	lazy => 1,
);
has 'duration_style' => (
	is => 'rw',
	default => 'seconds',
);
has 'video_codec' => (
	is => 'rw',
	builder => '_probe_videocodec',
	lazy => 1,
);
has 'audio_codec' => (
	is => 'rw',
	builder => '_probe_audiocodec',
	lazy => 1,
);
has 'video_size' => (
	is => 'rw',
	builder => '_probe_videosize',
	lazy => 1,
);
has 'video_bitrate' => (
	is => 'rw',
	builder => '_probe_videobitrate',
	lazy => 1,
);
has 'audio_bitrate' => (
	is => 'rw',
	builder => '_probe_audiobitrate',
	lazy => 1,
);
has 'audio_samplerate' => (
	is => 'rw',
	builder => '_probe_audiorate',
	lazy => 1,
);
has 'video_framerate' => (
	is => 'rw',
	builder => '_probe_framerate',
	lazy => 1,
);
has 'fragment_start' => (
	is => 'rw',
	predicate => 'has_fragment_start',
);
has 'profile' => (
	is => 'rw',
	trigger => \&_profile_set,
);
has 'metadata' => (
	traits => ['Hash'],
	isa => 'HashRef[Str]',
	is => 'ro',
	handles => {
		add_metadata => 'set',
		drop_metadata => 'delete',
	},
	predicate => 'has_metadata',
);
has 'reference' => (
	isa => 'SReview::Video',
	is => 'ro',
	predicate => 'has_reference',
);
has 'pix_fmt' => (
	is => 'rw',
	builder => '_probe_pix_fmt',
	lazy => 1,
);
has 'pass' => (
	is => 'rw',
	predicate => 'has_pass',
	clearer => 'clear_pass',
);

## The below exist to help autodetect sizes, and are not meant for the end user
has 'videodata' => (
	is => 'bare',
	reader => '_get_videodata',
	builder => '_probe_videodata',
	lazy => 1,
);
has 'audiodata' => (
	is => 'bare',
	reader => '_get_audiodata',
	builder => '_probe_audiodata',
	lazy => 1,
);
has 'probedata' => (
	is => 'bare',
	reader => '_get_probedata',
	builder => '_probe',
	clearer => 'clear_probedata',
	lazy => 1,
);

sub readopts {
	my $self = shift;
	my @opts = ();

	push @opts, ("-i", $self->url);
	return @opts;
}

sub writeopts {
	my $self = shift;
	my $pipe = shift;
	my @opts = ();

	if(!$pipe->vcopy) {
		if(defined($self->video_codec)) {
			push @opts, ('-c:v', $self->video_codec);
		}
		if(defined($self->video_bitrate)) {
			push @opts, ('-b:v', $self->video_bitrate . "k", '-minrate', $self->video_bitrate * .5 . "k", '-maxrate', $self->video_bitrate * 1.45 . "k");
		}
		if(defined($self->video_framerate)) {
			push @opts, ('-r:v', $self->video_framerate);
		}
		if($self->has_pass) {
			push @opts, ('-pass', $self->pass, '-passlogfile', $self->url . '-multipass');
		}
	}
	if(!$pipe->acopy) {
		if(defined($self->audio_codec)) {
			push @opts, ('-c:a', $self->audio_codec);
		}
		if(defined($self->audio_bitrate)) {
			push @opts, ('-b:a', $self->audio_bitrate);
		}
		if(defined($self->audio_samplerate)) {
			push @opts, ('-ar', $self->audio_samplerate);
		}
	}
	if($self->has_fragment_start) {
		push @opts, ('-ss', $self->fragment_start);
	}
	if(defined($self->duration)) {
		if($self->duration_style eq 'seconds') {
			push @opts, ('-t', $self->duration);
		} else {
			push @opts, ('-frames:v', $self->duration);
		}
	}
	if(defined($self->pix_fmt)) {
		push @opts, ('-pix_fmt', $self->pix_fmt);
	}
	if($self->has_metadata) {
		foreach my $meta(keys %{$self->metadata}) {
			push @opts, ('-metadata', $meta . '=' . $self->metadata->{$meta});
		}
	}
	push @opts, $self->url;

	return @opts;
}

sub _probe_duration {
	my $self = shift;
	return $self->_get_probedata->{format}{duration};
}

sub _probe_framerate {
	my $self = shift;
	my $framerate = $self->_get_videodata->{r_frame_rate};
	return $framerate;
}

sub _probe_audiorate {
	my $self = shift;
	return $self->_get_audiodata->{sample_rate};
}

sub _probe_videocodec {
	my $self = shift;
	return $self->_get_videodata->{codec_name};
}

sub _probe_audiocodec {
	my $self = shift;
	return $self->_get_audiodata->{codec_name};
}

sub _probe_videosize {
	my $self = shift;
	return $self->_get_videodata->{width} . "x" . $self->_get_videodata->{height};
}

sub _probe_videobitrate {
	my $self = shift;
	return $self->_get_videodata->{bit_rate};
}

sub _probe_audiobitrate {
	my $self = shift;
	return $self->_get_audiodata->{bit_rate};
}

sub _probe_pix_fmt {
	my $self = shift;
	return $self->_get_videodata->{pix_fmt}
}

sub _probe {
	my $self = shift;

	if($self->has_reference) {
		return $self->reference->_get_probedata;
	}
	open JSON, "ffprobe -print_format json -show_format -show_streams '" . $self->url . "' 2>/dev/null|";
	my $json = "";
	while(<JSON>) {
		$json .= $_;
	}
	close JSON;
	return decode_json($json);
}

sub _probe_audiodata {
	my $self = shift;
	if(!exists($self->_get_probedata->{streams})) {
		return {};
	}
	foreach my $stream(@{$self->_get_probedata->{streams}}) {
		if($stream->{codec_type} eq "audio") {
			return $stream;
		}
	}
}

sub _probe_videodata {
	my $self = shift;
	if(!exists($self->_get_probedata->{streams})) {
		return {};
	}
	foreach my $stream(@{$self->_get_probedata->{streams}}) {
		if($stream->{codec_type} eq "video") {
			return $stream;
		}
	}
}

no Moose;

1;
