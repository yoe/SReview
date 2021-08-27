package SReview::Videopipe;

use Mojo::JSON qw(decode_json);
use Moose;

has 'inputs' => (
	traits => ['Array'],
	is => 'ro',
	isa => 'ArrayRef[SReview::Video]',
	default => sub { [] },
	clearer => 'clear_inputs',
	handles => {
		add_input => 'push',
	},
);

has 'output' => (
	is => 'rw',
	isa => 'SReview::Video',
	required => 1,
);

has 'map' => (
	traits => ['Array'],
	is => 'ro',
	isa => 'ArrayRef[SReview::Map]',
	default => sub {[]},
	clearer => 'clear_map',
	handles => {
		add_map => 'push',
	},
);

has 'vcopy' => (
	isa => 'Bool',
	is => 'rw',
	default => 1,
);

has 'acopy' => (
	isa => 'Bool',
	is => 'rw',
	default => 1,
);

has 'vskip' => (
	isa => 'Bool',
	is => 'rw',
	default => 0,
);

has 'askip' => (
	isa => 'Bool',
	is => 'rw',
	default => 0,
);

has 'multipass' => (
	isa => 'Bool',
	is => 'rw',
	default => 0,
);

has 'progress' => (
	isa => 'CodeRef',
	is => 'ro',
	predicate => 'has_progress',
);

has 'has_run' => (
	isa => 'Bool',
	is => 'rw',
	default => 0,
	traits => ['Bool'],
	handles => {
		run_complete => 'set',
	}
);

sub run_progress {
	my $self = shift;
	my $command = shift;
	my $pass = shift;
	my $multipass = shift;
	my ($in, $out, $err);
	my $running;
	my @lines;
	my $old_perc = -1;
	my %vals;

	my $length = $self->inputs->[0]->duration * 1000000;
	shift @$command;
	unshift @$command, ('ffmpeg', '-progress', '/dev/stdout');
	open my $ffmpeg, "-|", @{$command};
	while(<$ffmpeg>) {
		/^(\w+)=(.*)$/;
		$vals{$1} = $2;
		if($1 eq 'progress') {
			my $perc = int($vals{out_time_ms} / $length * 100);
			if($vals{progress} eq 'end') {
				$perc = 100;
			}
			if($multipass) {
				$perc = int($perc / 2);
			}
			if($pass == 2) {
				$perc += 50;
			}
			if($perc != $old_perc) {
				$old_perc = $perc;
				&{$self->progress}($perc);
			}
		}
	}
	$self->run_complete;
}

sub run {
	my $self = shift;
	my $pass;
	my @attrs = (
		'video_codec' => 'vcopy',
		'video_size' => 'vcopy',
		'video_width' => 'vcopy',
		'video_height' => 'vcopy',
		'video_bitrate' => 'vcopy',
		'video_framerate' => 'vcopy',
		'pix_fmt' => 'vcopy',
		'audio_codec' => 'acopy',
		'audio_bitrate' => 'acopy',
		'audio_samplerate' => 'acopy',
	);
	my @video_attrs = ('video_codec', 'video_size', 'video_width', 'video_height', 'video_bitrate', 'video_framerate', 'pix_fmt');
	my @audio_attrs = ('audio_codec', 'audio_bitrate', 'audio_samplerate');

	for($pass = 1; $pass <= ($self->multipass ? 2 : 1); $pass++) {
		my @command = ("ffmpeg", "-loglevel", "warning", "-y");
		foreach my $input(@{$self->inputs}) {
			if($self->multipass) {
				$input->pass($pass);
				$self->output->pass($pass);
			}
			while(scalar(@attrs) > 0) {
				my $attr = shift @attrs;
				my $target = shift @attrs;
				next unless $self->meta->get_attribute($target)->get_value($self);
				my $oval = $self->output->meta->find_attribute_by_name($attr)->get_value($self->output);
				my $ival = $input->meta->find_attribute_by_name($attr)->get_value($input);
				if(defined($oval) && $ival ne $oval) {
					$self->meta->get_attribute($target)->set_value($self, 0);
				}
			}
			push @command, $input->readopts($self->output);
		}
		if(!$self->vcopy() && !$self->vskip()) {
			my $isize = $self->inputs->[0]->video_size;
			my $osize = $self->output->video_size;
			if(defined($isize) && defined($osize) && $isize ne $osize) {
				push @command, ("-vf", "scale=" . $osize);
			}
		}
		foreach my $map(@{$self->map}) {
			my $in_map = $map->input;
			my $index;
			for(my $i=0; $i<=$#{$self->inputs}; $i++) {
				if($in_map == ${$self->inputs}[$i]) {
					$index = $i;
				}
			}
			push @command, $map->arguments($index);
		}
		if($self->vcopy) {
			push @command, ('-c:v', 'copy');
		}
		if($self->acopy) {
			push @command, ('-c:a', 'copy');
		}
		if($self->vskip) {
			push @command, ('-vn');
		}
		if($self->askip) {
			push @command, ('-an');
		}
		push @command, $self->output->writeopts($self);

		print "Running: '" . join ("' '", @command) . "'\n";
		if($self->has_progress) {
			$self->run_progress(\@command, $pass, $self->multipass);
		} else {
			system(@command);
		}
	}
	foreach my $input(@{$self->inputs}) {
		$input->clear_pass;
	}
	$self->output->clear_pass;
	$self->run_complete;
}

sub DESTROY {
	if(!(shift->has_run)) {
		croak "object destructor for videopipe entered without having seen a run!";
	}
}

no Moose;

1;
