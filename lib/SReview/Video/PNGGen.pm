package SReview::Video::PNGGen;

use Moose;

extends 'SReview::Video';

sub readopts {
	my $self = shift;
	my $output = shift;

	$output->add_custom('-frames:v', $output->video_framerate * $output->duration, '-ar', $output->audio_samplerate);

	return ('-loop', '1', '-i', $self->url, '-f', 'lavfi', '-i', 'anullsrc');
}

no Moose;

1;
