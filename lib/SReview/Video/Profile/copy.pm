package SReview::Video::Profile::copy;

use SReview::Video::ProfileFactory;
use SReview::CodecMap qw/detect_to_write/;

use Moose;

extends 'SReview::Video::Profile::Base';

sub _probe_exten {
	my $self = shift;
	my $ref = $self->reference;
	my $vid = $ref->video_codec;
	my $aud = $ref->audio_codec;

	if (($vid eq 'vp9' && $aud eq 'opus')
		or ($vid eq 'vp8' && $aud eq 'vorbis')) {
		return 'webm';
	}
	if ($vid eq 'h264' && $aud eq 'aac') {
		return 'mp4';
	}
	die "unknown video format; can't do copy profile";
}

sub _probe_videocodec {
	my $self = shift;

	return "copy";
}

sub _probe_audiocodec {
	return "copy";
}
