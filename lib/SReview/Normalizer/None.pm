package SReview::Normalizer::None;

use SReview::Normalizer;
use Moose;
use File::Copy;

extends 'SReview::Normalizer';

sub run {
	my $self = shift;
	if ($self->input->filename ne $self->output->filename) {
		copy($self->input->filename, $self->output->filename);
	}
}
