use SReview::Video::ProfileFactory;
package SReview::Video::Profile::FOSDEM;

use Moose;

extends 'SReview::Video::Profile::Base';

has '+exten' => (
	default => 'mp4'
);

sub _probe_videocodec {
	return "libx264";
}

sub _probe_audiocodec {
	return "libfdk_aac";
}

sub _probe_audiobitrate {
	return "128k";
}

1;
