package SReview::Normalizer;

use Moose;
use File::Basename;
use File::Temp qw/tempdir/;
use SReview::CodecMap qw/detect_to_write/;
use SReview::Config::Common;
use SReview::Video;
use SReview::Videopipe;

=head1 NAME

SReview::Normalizer - normalize the audio of a video asset using bs1770gain

=head1 SYNOPSIS

  SReview::Normalizer->new(input => SReview::Video->new(...), output => SReview::Video->new(...))->run();

=head1 DESCRIPTION

C<SReview::Normalizer> is a class to normalize the audio of
a given SReview::Video asset, using bs1770gain at its default settings.

It looks at the C<command_tune> configuration parameter to decide
whether to pass the C<--suffix> option to bs1770gain: if the installed
version of C<bs1770gain> is at 0.5 or below, set the C<bs1770gain> key
of C<command_tune> to 0.5 to remove the C<--suffix> parameter from the
command line (which is required for 0.6 or above, but not supported by
0.5 or below).

=head1 ATTRIBUTES

The following attributes are supported by
SReview::Normalizer.

=head2 input

An L<SReview::Video> object for which the audio should be normalized.

Required.

=cut

has 'input' => (
	is => 'rw',
	isa => 'SReview::Video',
	required => 1,
);

=head2 output

An L<SReview::Video> object that the normalized audio should be written
to, together with the video from the input file.

Required.

=cut

has 'output' => (
	is => 'rw',
	isa => 'SReview::Video',
	required => 1,
);

has '_tempdir' => (
	is => 'rw',
	isa => 'String',
	lazy => 1,
	builder => '_probe_tempdir',
);

sub _probe_tempdir {
	my $self = shift;

	return tempdir("normXXXXXX", DIR => SReview::Config::Common::setup()->get('workdir'), CLEANUP => 1);
}

=head2 audio

Pre-extracted audio from the input file. Use this if the video and audio
assets are already in separate files. Optional; if it is not provided,
then the audio stream will be extracted from the input object.

If provided, this MUST be in audio file in a C<.wav> container.

=cut

has 'audio' => (
	is => 'rw',
	isa => 'SReview::Video',
	lazy => 1,
	builder => '_probe_audiofile',
);

sub _probe_audiofile {
	my $self = shift;

	my $audio = SReview::Video->new

	my $dir = $self->_tempdir;

	my $rv = SReview::Video->new(url => "$dir/audio.wav");

	SReview::Videopipe->new(inputs => [$self->input], output => $rv, acopy => 0, vskip => 1)->run();

	return $rv;
}

=head2 audio_codec

The codec to which to encode. Use if the input video object does not
have an audio stream. Otherwise, defaults to the audio codec on the
input video object.

=cut

has 'audio_codec' => (
	is => 'rw',
	isa => 'String',
	lazy => 1,
	builder => '_probe_audio_codec',
);

sub _probe_audio_codec {
	return detect_to_write(shift->input->audio_codec);
}

=head1 METHODS

=head2 run

Performs the normalization.

=cut

sub run {
	my @command = ("bs1770gain", "-a", "-o", $self->tempdir);
	if(SReview::Config::Common::setup()->get("command_tune")->{bs1770gain} ne "0.5") {
		push @command, "--suffix=flac";
	}
	push @command, $self->audio->url;
	print "Running: '" . join("' '", @command) . "'\n";
	system(@command);
	my $audio_in = SReview::Video->new(url => join('/', $self->tempdir, basename($fullname, [ ".wav" ])) . ".flac");
	my $map_v = SReview::Map->new(input => $self->input, type => "stream", choice => "video");
	my $map_a = SReview::Map->new(input => $audio_in, type => "stream", choice => "audio");
	$self->output->audio_codec($self->audio_codec);

	SReview::Videopipe->new(inputs => [$self->input, $audio_in], "map" => [$map_a, $map_v], vcopy => 1, acopy => 0)->run();
}
