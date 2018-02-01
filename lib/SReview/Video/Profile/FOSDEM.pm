use SReview::Video::ProfileFactory;
package SReview::Video::Profile::FOSDEM;

use Moose;

extends 'SReview::Video::Profile::mp4';

sub _probe_extra_params {
	return { "g" => "45",
		 "profile" => "main",
		 "preset" => "veryfast" };
}

sub _probe_videobitrate {
	return "512";
}

sub speed {
	return undef;
}

no Moose;

1;
