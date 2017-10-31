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
	default => 'channel',
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

	if($self->type eq "channel") {
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
	} elsif($self->type eq "stream") {
		if($self->choice eq 'audio') {
			return ('-map', "$index:a");
		} elsif($self->choice eq 'video') {
			return ('-map', "$index:v");
		} else {
			...
		}
	}
}

no Moose;

1;
