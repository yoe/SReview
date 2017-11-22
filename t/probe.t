#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 12;
use_ok('SReview::Video');
use_ok('SReview::Videopipe');

my $vid = SReview::Video->new(url => 't/testvids/bbb.mp4');
isa_ok($vid, 'SReview::Video');
ok($vid->duration == 20.024000, 'video duration probed correctly');
ok($vid->video_codec eq 'h264', 'video codec probed correctly');
ok($vid->audio_codec eq 'aac', 'audio codec probed correctly');
ok($vid->video_size eq '854x480', 'video resolution probed correctly');
ok($vid->video_bitrate == 1116207, 'video bitrate probed correctly');
ok($vid->audio_bitrate == 133431, 'audio bitrate probed correctly');
ok($vid->audio_samplerate == 44100, 'audio samplerate probed correctly');
ok($vid->video_framerate eq '24/1', 'video framerate probed correctly');
ok($vid->pix_fmt eq 'yuv420p', 'video pixel format probed correctly');
