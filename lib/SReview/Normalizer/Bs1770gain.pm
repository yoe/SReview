package SReview::Normalizer::Bs1770gain;

use Moose;
use File::Basename;
use File::Temp qw/tempdir/;
use SReview::CodecMap qw/detect_to_write/;
use SReview::Config::Common;
use SReview::Map;
use SReview::Video;
use SReview::Videopipe;

extends 'SReview::Normalizer';

=head1 NAME

SReview::Normalizer::Bs1770gain - normalize the audio of a video asset using bs1770gain

=head1 SYNOPSIS

  SReview::Normalizer::Bs1770gain->new(input => SReview::Video->new(...), output => SReview::Video->new(...))->run();

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

C<SReview::Normalizer::Bs1770gain> supports all the attributes of
L<SReview::Normalizer>.

=cut

has '_tempdir' => (
	is => 'rw',
	isa => 'Str',
	lazy => 1,
	builder => '_probe_tempdir',
);

sub _probe_tempdir {
	my $self = shift;

	return tempdir("normXXXXXX", DIR => SReview::Config::Common::setup()->get('workdir'), CLEANUP => 1);
}

=head1 METHODS

=head2 run

Performs the normalization.

=cut

sub run {
	my $self = shift;

	my $exten;

	$self->input->url =~ /(.*)\.[^.]+$/;
	my $base = $1;
	if(!defined($self->input->video_codec)) {
		$exten = "flac";
	} else {
		$exten = "mkv";
	}
	my @command = ("bs1770gain", "-a", "-o", $self->_tempdir);
	my $tune = SReview::Config::Common::setup()->get("command_tune");
	if(exists($tune->{bs1770gain}) && $tune->{bs1770gain} ne "0.5") {
		$exten = "mkv";
		push @command, "--suffix=mkv";
	}
	push @command, $self->input->url;
	print "Running: '" . join("' '", @command) . "'\n";
	system(@command);

	my $intermediate = $self->_tempdir . "/" . basename($base) . ".$exten";

	SReview::Videopipe->new(inputs => [SReview::Video->new(url => $intermediate)], output => $self->output, vcopy => 1, acopy => 1)->run();
}

1;
