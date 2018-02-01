package SReview::Video::PNGGen;

use Moose;
use Carp;

extends 'SReview::Video';

sub readopts {
	my $self = shift;
	my $output = shift;

	if(defined($output->video_size) && ($self->video_size ne $output->video_size)) {
		carp "Video resolution does not match image resolution. Will scale, but the result may be suboptimal...";

	}
	return ('-loop', '1', '-framerate', $output->video_framerate, '-i', $self->url, '-f', 'lavfi', '-i', 'anullsrc=channel_layout=mono,r=' . $self->audio_samplerate);
}

no Moose;

1;
