use SReview::Video::ProfileFactory;
package SReview::Video::Profile::mp4;

use Moose;

extends 'SReview::Video::Profile::Base';

sub _probe_exten {
	return 'mp4';
}

sub _probe_videocodec {
	return "h264";
}

sub _probe_audiocodec {
	return "aac";
}

1;
