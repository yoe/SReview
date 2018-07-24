use SReview::Video::ProfileFactory;
package SReview::Video::Profile::FOSDEM;

use Moose;

extends 'SReview::Video::Profile::mpeg2';

sub _probe_videobitrate {
	return "1800";
}

sub speed {
	return 4;
}

no Moose;

1;
