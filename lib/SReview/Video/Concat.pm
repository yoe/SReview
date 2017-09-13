package SReview::Video::Concat;

use Moose;

extends 'SReview::Video';

has 'components' => (
	traits => ['Array'],
	isa => 'ArrayRef[SReview::Video]',
	required => 1,
	is => 'rw',
	handles => {
		add_component => 'push',
	},
);

has '+duration' => (
	builder => '_build_duration',
);

sub readopts {
	my $self = shift;

	if($self->has_pass && $self->pass < 2) {
		die "refusing to overwrite file " . $self->url . "!\n" if (-f $self->url);

		open CONCAT, ">" . $self->url;
		foreach my $component(@{$self->components}) {
			my $input = $component->url;
			print CONCAT "file '$input'\n";
		}
		close CONCAT;
		$self->add_custom('-f', 'concat', '-safe', '0');
	}
	return $self->SReview::Video::readopts();
}

sub _build_duration {
	my $self = shift;
	my $rv = 0;
	foreach my $component(@{$self->components}) {
		$rv += $component->duration;
	}
	return $rv;
}

no Moose;

1;
