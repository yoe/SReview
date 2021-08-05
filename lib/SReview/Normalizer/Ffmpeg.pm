package SReview::Normalizer::Ffmpeg;

use Moose;

extends 'SReview::Normalizer';

use Mojo::JSON qw/decode_json/;
use Symbol 'gensym';
use IPC::Open3;
use SReview::CodecMap qw/detect_to_write/;

=head1 NAME

SReview::Normalizer::Ffmpeg - normalize the audio of a video asset using the ffmpeg 'loudnorm' filter

=head1 SYNOPSIS

  SReview::Normalizer::Ffmpeg->new(input => SReview::Video->new(...), output => SReview::Video->new(...))->run();

=head1 DESCRIPTION

C<SReview::Normalizer> is a class to normalize the audio of a given
SReview::Video asset. This class is an implementation of the API using
the ffmpeg "loudnorm" filter.

=head1 ATTRIBUTES

C<SReview::Normalizer::Ffmpeg> supports all the attributes of
L<SReview::Normalizer>

=head1 METHODS

=head2 run

Performs the normalization

=cut

sub run {
	my $self = shift;

	my $input = $self->input;

	my @command = ("ffmpeg", "-y", "-i", $input->url, "-af", "loudnorm=i=-23.0:print_format=json", "-f", "null", "-");
	print "Running: '" . join("' '", @command) . "'\n";
	open3 (my $in, my $out, my $ffmpeg = gensym, @command);
	my $json = "";
	my $reading_json = 0;
	while(<$ffmpeg>) {
		if($reading_json) {
			$json .= $_;
			next;
		}
		if(/Parsed_loudnorm/) {
			$reading_json = 1;
		}
	}
	$json = decode_json($json);

	# TODO: abstract filters so they can be applied to an
	# SReview::Videopipe. Not now.
	my $codec = $self->output->audio_codec;
	if(!defined($codec)) {
		$codec = detect_to_write($input->audio_codec);
	}
	@command = ("ffmpeg", "-loglevel", "warning", "-y", "-i", $input->url, "-af", "loudnorm=i=-23.0:dual_mono=true:measured_i=" . $json->{input_i} . ":measured_tp=" . $json->{input_tp} . ":measured_lra=" . $json->{input_lra} . ":measured_thresh=" . $json->{input_thresh}, "-c:v", "copy", "-c:a", $codec, $self->output->url);
	print "Running: '" . join("' '", @command) . "'\n";
	system(@command);
}
