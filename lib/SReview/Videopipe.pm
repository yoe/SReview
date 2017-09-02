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

sub run {
	my $self = shift;

	my @command = ("ffmpeg", "-y");
	foreach my $input(@{$self->inputs}) {
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

no Moose;

1;
