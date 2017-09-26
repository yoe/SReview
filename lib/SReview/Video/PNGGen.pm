package SReview::Video::PNGGen;

use Moose;
use Carp;

extends 'SReview::Video';

sub readopts {
	my $self = shift;
	my $output = shift;

	if(defined($output->video_size) && ($self->video_size ne $output->video_size)) {
		croak "Video resolution does not match image resolution";
	}

	return ('-loop', '1', '-framerate', $output->video_framerate, '-i', $self->url, '-f', 'lavfi', '-i', 'anullsrc');
}

no Moose;

1;
