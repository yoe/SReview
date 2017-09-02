package SReview::Video::PNGGen;

use Moose;

extends 'SReview::Video';

has '+reference' => (
	required => 1,
);

sub readopts {
	my $self = shift;
	my $output = shift;

	$output->add_custom('-frames:v', $self->reference->video_framerate * 5, '-ar', $self->reference->audio_samplerate);

	return ('-loop', '1', '-i', $self->url, '-f', 'lavfi', '-i', 'anullsrc');
}

no Moose;

1;
