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
	isa => 'ArrayRef[Str]',
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

has 'multipass' => (
	isa => 'Bool',
	is => 'rw',
	default => 0,
);

sub run {
	my $self = shift;
	my $pass;

	for($pass = 1; $pass <= ($self->multipass ? 2 : 1); $pass++) {
		my @command = ("ffmpeg", "-y");
		foreach my $input(@{$self->inputs}) {
			if($self->multipass) {
				$input->pass($pass);
				$self->output->pass($pass);
			}
			push @command, $input->readopts($self->output);
		}
		foreach my $map(@{$self->map}) {
			push @command, "-map", $map;
		}
		if($self->vcopy) {
			push @command, ('-c:v', 'copy');
		}
		if($self->acopy) {
			push @command, ('-c:a', 'copy');
		}
		push @command, $self->output->writeopts($self);

		print "Running: '" . join ("' '", @command) . "'\n";
		system(@command);
	}
	foreach my $input(@{$self->inputs}) {
		$input->clear_pass;
	}
	$self->output->clear_pass;
}

no Moose;

1;
