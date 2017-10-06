package SReview::Video::PNGGen;

use Moose;
use Carp;

extends 'SReview::Video';

sub readopts {
	my $self = shift;
	my $output = shift;

	if(defined($output->video_size) && ($self->video_size ne $output->video_size)) {
		carp "Video resolution does not match image resolution. Will scale, but the result may be suboptimal...";

		return ('-loop', '1', '-framerate', $output->video_framerate, '-i', $self->url, '-vf', 'scale=' . $output->video_size, '-f', 'lavfi', '-i', 'anullsrc');
	}
	if(defined($output->aspect_ratio) && ($self->aspect_ratio ne $output->aspect_ratio)) {
		croak "Video aspect ratio does not match image aspect ratio";
	}
	return ('-loop', '1', '-framerate', $output->video_framerate, '-i', $self->url, '-f', 'lavfi', '-i', 'anullsrc');
}

no Moose;

1;
