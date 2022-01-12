package SReview::Normalizer;

use Moose;
use SReview::Config::Common;

=head1 NAME

SReview::Normalizer - normalize the audio of a video asset.

=head1 SYNOPSIS

  SReview::Normalizer->new(input => SReview::Video->new(...), output => SReview::Video->new(...))->run();

=head1 DESCRIPTION

C<SReview::Normalizer> is a class to normalize the audio of
a given SReview::Video asset, using ffmpeg at its default settings.

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

Required. Must point to a .mkv file.

=cut

has 'output' => (
	is => 'rw',
	isa => 'SReview::Video',
	required => 1,
);

=head1 METHODS

=head2 run

Performs the normalization.

=cut

sub run {
	my $self = shift;
	my $config = SReview::Config::Common::setup();
	my $pkg = "SReview::Normalizer::" . ucfirst($config->get("normalizer"));
	eval "require $pkg;";
	if($@) {
		die "$@: $!";
	}
	return $pkg->new(input => $self->input, output => $self->output)->run();
}

1;
