use SReview::Video::ProfileFactory;
package SReview::Video::Profile::mpeg2;

use Moose;

extends 'SReview::Video::Profile::Base';

sub _probe_exten {
	return 'mpg';
}

sub _probe_videocodec {
	return "mpeg2video";
}

sub _probe_audiocodec {
	return "mp2";
}

1;
