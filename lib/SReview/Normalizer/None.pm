package SReview::Normalizer::None;

use SReview::Normalizer;
use Moose;
use File::Copy;

extends 'SReview::Normalizer';

sub run {
	my $self = shift;
	if ($self->input->url ne $self->output->url) {
		copy($self->input->url, $self->output->url);
	}
}
