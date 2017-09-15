package SReview::Video::PNGGen;

use Moose;

extends 'SReview::Video';

sub readopts {
	my $self = shift;
	my $output = shift;

	my $frames_per_sec = eval $output->video_framerate;

	$output->add_custom('-frames:v', int($frames_per_sec * $self->duration), '-ar', $output->audio_samplerate);

	return ('-loop', '1', '-framerate', $output->video_framerate, '-i', $self->url, '-f', 'lavfi', '-i', 'anullsrc');
}

no Moose;

1;
