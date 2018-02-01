use SReview::Video::ProfileFactory;
use SReview::Video::Profile::mp4;
package SReview::Video::Profile::FOSDEM;

use Moose;

extends SReview::Video::Profile::mp4;

sub _probe_extra_params {
	return { g => "45", "probesize" => "10M", "analyzeduration" => "10M" };
}

no Moose;

1;
