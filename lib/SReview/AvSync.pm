package SReview::AvSync;

use Moose;
use SReview::Video;
use SReview::Config::Common;
use SReview::Videopipe;
use SReview::Map;
use File::Temp qw/tempdir/;

has "input" => (
	is => 'rw',
	required => 1,
	isa => 'SReview::Video',
);

has 'output' => (
	is => 'rw',
	required => 1,
	isa => 'SReview::Video',
);

has "value" => (
	is => 'rw',
	required => 1,
);

my $config = SReview::Config::Common::setup();

sub run() {
	my $self = shift;
	my $tempdir = tempdir("avsXXXXXX", DIR => $config->get("workdir"), CLEANUP => 1);
	if($self->value == 0) {
		# Why are we here??
		SReview::Videopipe->new(inputs => [$self->input], output => $self->output)->run();
		return;
	}
	SReview::Videopipe->new(inputs => [$self->input], output => SReview::Video->new(url => "$tempdir/pre.mkv"))->run();
	my $input_audio = SReview::Video->new(url => "$tempdir/pre.mkv", time_offset => $self->value);
	my $input_video = SReview::Video->new(url => "$tempdir/pre.mkv");
	my $sync_video = SReview::Video->new(url => "$tempdir/synced.mkv");
	SReview::Videopipe->new(inputs => [$input_audio, $input_video], map => [SReview::Map->new(input => $input_audio, type => "stream", choice => "audio"), SReview::Map->new(input => $input_video, type => "stream", choice => "video")], output => $sync_video)->run();
	$self->output->fragment_start(abs($self->value));
	SReview::Videopipe->new(inputs => [$sync_video], output => $self->output)->run();
}
