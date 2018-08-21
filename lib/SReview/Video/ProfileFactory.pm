=head1 NAME

SReview::Video::ProfileFactory - Create an output profile from an input video.

=head1 SYNOPSIS

    use SReview::Video;
    use SReview::Videopipe;
    use SReview::Video::ProfileFactory;

    package SReview::Video::Profile::myprofile;
    use Moose;
    extends SReview::Video::Profile::webm;

    has '+audio_samplerate' => (
        builder => '_probe_my_audiorate',
    );

    has '+audio_codec' => (
        default => 'vorbis',
    );

    sub _probe_exten {
        return 'my.webm',
    }

    sub _probe_my_audiorate {
        my $self = shift;
        return $self->reference->audio_samplerate / 2;
    }

    no Moose;

    package main;

    my $input = SReview::Video->new(url => "foo.mp4");
    my $profile = SReview::Video::ProfileFactory->create("myprofile", $input);
    my $output = SReview::Video->new(url => "foo." . $profile->exten, reference => $profile);
    SReview::Videopipe->new(inputs => [$input], output => $output)->run();

=head1 DESCRIPTION

C<SReview::Video::Profile::Base> is a subclass of SReview::Video, but with
a number of the probing methods overridden so that they return values
that are not in line with the reference of the given video.

The C<SReview::Video::ProfileFactory>'s C<create> method is a simple
helper to:

=over

=item *

ensure that the relevant C<SReview::Video::Profile::I<profile>> module
has been loaded

=item *

create an C<SReview::Video> subclass of the right type, with reference
set to the passed input C<SReview::Video> object.

=back

=head1 CREATING NEW PROFILES

It is possible to create a new profile by extending an existing one. The
C<myprofile> profile in the above example shows how to do so. Any
property that is known by L<SReview::Video> can be overridden in the
manner given.

To create a new profile, one can use the C<extra_profiles> configuration
setting; however, profiles created in this manner can only hardcode
values, and cannot vary any parameters based on the input file. To
create a profile that can do so, when the new profile just changes a
minor detail of an existing profile, extend that profile and change the
detail which you want to change. To create a new profile from scratch,
extend the C<Base> profile (see below).

=head1 PRE-EXISTING PROFILES

The following profiles are defined by C<SReview::Video::ProfileFactory>:

=cut

package SReview::Video::Profile::Base;

=head2 Base

This profile serves as a base class for the other profiles. It should
not be used directly.

It adds the extension, and defaults the pixel format to yuv420p.

=cut

use Moose;

extends 'SReview::Video';

has '+reference' => (
	required => 1,
);

has 'exten' => (
	lazy => 1,
	is => 'ro',
	builder => '_probe_exten',
);

has '+pix_fmt' => (
	builder => '_build_pixfmt',
);

sub _build_pixfmt {
	return 'yuv420p';
}

sub _probe_exten {
	return 'IEK - extension not defined';
}

package SReview::Video::Profile::vp9;

=head2 vp9

Produces a video in WebM/VP9 format, using the quality/bitrate settings
recommended by Google on L<https://developers.google.com/media/vp9/>,
and with OPUS audio. Produces files with the C<vp9.webm> extension.

Audio settings are hardcoded to 48KHz sampling rate, 128k bits per
second.

=cut

use Moose;

extends 'SReview::Video::Profile::Base';

sub _probe_exten {
	return 'vp9.webm'
}

my %rates_30 = (
	240 => 150,
	360 => 276,
	480 => 750,
	720 => 1024,
	1080 => 1800,
	1440 => 6000,
	2160 => 12000
);

my %rates_50 = (
	240 => 150,
	360 => 276,
	480 => 750,
	720 => 1800,
	1080 => 3000,
	1440 => 9000,
	2160 => 18000
);

my %quals = (
	240 => 37,
	360 => 36,
	480 => 33,
	720 => 32,
	1080 => 31,
	1440 => 24,
	2160 => 15,
);

sub _probe_videobitrate {
	my $self = shift;
	if(eval($self->video_framerate) > 30) {
		return $rates_50{$self->video_height};
	} else {
		return $rates_30{$self->video_height};
	}
}

sub _probe_audiorate {
	return "48000";
}

sub _probe_audiobitrate {
	return "128k";
}

sub _probe_quality {
	my $self = shift;
	return $quals{$self->video_height};
}

sub speed {
	my $self = shift;
	if($self->reference->has_pass) {
		if($self->reference->pass == 1 || $self->video_height < 720) {
			return 4;
		}
		return 2;
	}
}

sub _probe_videocodec {
	return "vp9";
}

sub _probe_audiocodec {
	return "opus";
}

no Moose;

package SReview::Video::Profile::vp8;

=head2 vp8

Produces a video in WebM/VP8 format. Since no similar recommendations
for VP8 exist as do for VP9, no explicit quality or bitrate settings are
configured in this profile. The libvpx video codec is selected, and the
libvorbis one for audio.

The audio bitrate is explicitly left to ffmpeg defaults; the extension
is set to C<vp8.webm>

=cut

use Moose;

extends 'SReview::Video::Profile::Base';

sub _probe_exten {
	return 'vp8.webm';
}

sub _probe_videocodec {
	return "vp8";
}

sub _probe_audiocodec {
	return "vorbis";
}

sub _probe_audiobitrate {
	return undef;
}

no Moose;

package SReview::Video::Profile::webm;

=head2 webm

This profile subclasses from the C<vp9> profile, and only changes the
extension to plain C<webm> instead of C<vp9.webm>.

Additionally, if a future version of WebM is ever defined, then when
SReview gains support for that version of WebM, this class will become a
subclass of that class instead.

=cut

use Moose;

extends 'SReview::Video::Profile::vp9';

sub _probe_exten {
	return 'webm',
}

no Moose;

package SReview::Video::Profile::vp8_lq;

=head2 vp8_lq

This profile subclasses from the C<vp8> profile. The extension is set to
C<lq.webm>. In addition to the changes made by the C<vp8> profile, this
profile also rescales the video to a fraction of the original; that is,
the height and width of the video are both divided by 8.

=cut

use Moose;

extends 'SReview::Video::Profile::vp8';

sub _probe_exten {
	return 'lq.webm',
}

sub _probe_height {
	my $self = shift;
	return undef unless defined ($self->reference->video_height);
	return int($self->reference->video_height / 4);
}

sub _probe_width {
	my $self = shift;
	return undef unless defined ($self->reference->video_width);
	return int($self->reference->video_width / 4);
}

sub _probe_videosize {
	my $self = shift;
	my $width = $self->video_width;
	my $height = $self->video_height;
	return undef unless defined($width) && defined($height);
	return undef unless $width && $height;
	return $self->video_width . "x" . $self->video_height;
}

no Moose;

package SReview::Video::ProfileFactory;

use SReview::Config::Common;

sub create {
	my $class = shift;
	my $profile = shift;
	my $ref = shift;
	my $config = shift;
	my $profiles = SReview::Config::Common::setup()->get('extra_profiles');

	if(!exists($profiles->{$profile})) {
		eval "require SReview::Video::Profile::$profile;";

		return "SReview::Video::Profile::$profile"->new(url => '', reference => $ref);
	} else {
		my $parent = $profiles->{$profile}{parent};
		eval "require SReview::Video::Profile::$parent;";
		my $rv = "SReview::Video::Profile::$parent"->new(url => '', reference => $ref);
		foreach my $param(keys %{$profiles->{$profile}{settings}}) {
			next if($param eq 'parent');
			$rv->meta->find_attribute_by_name($param)->set_value($rv, $profiles->{$profile}{settings}{$param});
		}
		return $rv;
	}
	die "Unknown profile $profile requested!";
}

1;

=head1 SEE ALSO

L<SReview::Video>
