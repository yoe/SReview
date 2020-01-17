#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 10;
use_ok('SReview::Video');
use_ok('SReview::Videopipe');

my $input = SReview::Video->new(url => 't/testvids/bbb.mp4');
isa_ok($input, 'SReview::Video');
my $output = SReview::Video->new(url => 't/testvids/from10.mp4', fragment_start => 10);
isa_ok($output, 'SReview::Video');
my $pipe = SReview::Videopipe->new(inputs => [$input], output => $output);
isa_ok($pipe, 'SReview::Videopipe');
unlink($output->url);
$pipe->run;
ok(-f $output->url, 'The output file exists');
my $check = SReview::Video->new(url => $output->url);
isa_ok($check, 'SReview::Video');
ok($check->duration > ($input->duration - 10.1) && $check->duration < ($input->duration - 9.9), "The video has (approximately) the correct length");
ok($check->video_codec eq $input->video_codec, 'The video has the same codec as the input video');
ok($check->audio_codec eq $input->audio_codec, 'The audio has the same codec as the input video');
unlink($output->url);
