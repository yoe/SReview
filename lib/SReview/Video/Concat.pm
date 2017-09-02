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

sub readopts {
	my $self = shift;

	die "refusing to overwrite file " . $self->url . "!\n" if (-f $self->url);

	open CONCAT, ">" . $self->url;
	foreach my $component(@{$self->components}) {
		my $input = $component->url;
		print CONCAT "file '$input'\n";
	}
	close CONCAT;
	$self->add_custom('-f', 'concat', '-safe', '0');
	return $self->SReview::Video::readopts();
}

no Moose;

1;
