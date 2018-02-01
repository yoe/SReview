use SReview::Video::ProfileFactory;
package SReview::Video::Profile::FOSDEM;

use Moose;

extends SReview::Video::Profile::mp4;

has '+extra_params' (
	default => { g => "45", "probesize" => "10M", "analyzeduration" => "10M" };
);

no Moose;

1;
