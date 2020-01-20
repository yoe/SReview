package SReview::Map;

use Moose;
use Carp;

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
	} elsif($self->type eq "astream") {
		my $choice = $self->choice;
		if($choice > $self->input->astream_count) {
			croak("Invalid audio stream, not supported by input video");
		}
		if($choice == -1) {
			my $ids = $self->input->astream_ids;
			my $id1 = $ids->[0];
			my $id2 = $ids->[1];
			return ('-filter_complex', "[$index:$id1][$index:$id2]amix=inputs=2:duration=first");
		}
		return ('-map', "$index:a:$choice");
	} else {
		...
	}
}

no Moose;

1;
