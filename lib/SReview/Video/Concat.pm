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

	if(($self->has_pass && $self->pass < 2) || !$self->has_pass) {
		die "refusing to overwrite file " . $self->url . "!\n" if (-f $self->url);

		my $content = "ffconcat version 1.0\n\n";
		foreach my $component(@{$self->components}) {
			my $input = $component->url;
			$content .= "file '$input'\n";
		}
		print "Writing " . $self->url . " with content:\n$content\n";
		open CONCAT, ">" . $self->url;
		print CONCAT $content;
		close CONCAT;
	}

	return ('-f', 'concat', '-safe', '0', $self->SReview::Video::readopts());
}

sub _build_duration {
	my $self = shift;
	my $rv = 0;
	foreach my $component(@{$self->components}) {
		$rv += $component->duration;
	}
	return $rv;
}

sub _probe {
	my $self = shift;
	return $self->components->[0]->_get_probedata;
}

no Moose;

1;
