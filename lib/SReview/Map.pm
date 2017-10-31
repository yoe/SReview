package SReview::Map;

use Moose;

has 'input' => (
	required => 1,
	is => 'rw',
	isa => 'SReview::Video',
);

has 'type' => (
	isa => 'Str',
	is => 'rw',
	default => 'audio',
);

has 'choice' => (
	isa => 'Str',
	is => 'rw',
	default => 'left',
);

sub arguments($$) {
	my $self = shift;
	my $index = shift;
	my $stream_id;

	if($self->type eq "audio") {
		if($self->choice eq "both") {
			return ('-ac', '1');
		}
		$stream_id = $self->input->astream_id;
		if($self->choice eq "left") {
			return ('-map_channel', "$index.$stream_id.0");
		} elsif($self->choice eq "right") {
			return ('-map_channel', "$index.$stream_id.1");
		} else {
			# other choices exist?!?
			...
		}
	} else {
		# Not sure whether video mapping will be useful; if so,
		# we'll implement it then.
		...
	}
}

no Moose;

1;
