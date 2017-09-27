#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 12;
use_ok('SReview::Video');
use_ok('SReview::Videopipe');

open WFFP, 'which ffprobe|';

my $ffprobe = <WFFP>;

my $vid = SReview::Video->new(url => 't/testvids/7184709189_sd.mp4');
isa_ok($vid, 'SReview::Video');
ok($vid->duration == 22.894867, 'video duration probed correctly');
ok($vid->video_codec eq 'h264', 'video codec probed correctly');
ok($vid->audio_codec eq 'aac', 'audio codec probed correctly');
ok($vid->video_size eq '640x480', 'video resolution probed correctly');
ok($vid->video_bitrate == 713840, 'video bitrate probed correctly');
ok($vid->audio_bitrate == 125627, 'audio bitrate probed correctly');
ok($vid->audio_samplerate == 44100, 'audio samplerate probed correctly');
ok($vid->video_framerate eq '30000/1001', 'video framerate probed correctly');
ok($vid->pix_fmt eq 'yuv420p', 'video pixel format probed correctly');
