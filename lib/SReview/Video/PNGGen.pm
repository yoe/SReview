package SReview::Video::PNGGen;

use Moose;

extends 'SReview::Video';

sub readopts {
	my $self = shift;
	my $output = shift;


	return ('-loop', '1', '-framerate', $output->video_framerate, '-i', $self->url, '-f', 'lavfi', '-i', 'anullsrc');
}

no Moose;

1;
