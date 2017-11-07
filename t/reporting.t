#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 7;

use_ok('SReview::Video');
use_ok('SReview::Videopipe');

my $input = SReview::Video->new(url => 't/testvids/7184709189_sd.mp4');
my $output = SReview::Video->new(url => 't/testvids/out.ts', video_codec => 'mpeg2video');

my $old_perc;
my $ok = 1;

sub progress {
	my $perc = shift;

	print "progress: $perc\n";
	if(defined($old_perc) && $perc < $old_perc) {
		$ok = 0;
	}
	$old_perc = $perc;
}

my $pipe = SReview::Videopipe->new(inputs => [$input], output => $output, progress => \&progress, vcopy => 0, acopy => 0);

isa_ok($pipe, 'SReview::Videopipe');

$pipe->run;
ok($ok == 1, "progress information is strictly increasing");
ok($old_perc == 100, "progress stops at 100%");

$old_perc = undef;

unlink($output->url);
$output = SReview::Video->new(url => 't/testvids/out.webm', duration => 10, video_codec => 'vp8', audio_codec => 'libvorbis');
$pipe = SReview::Videopipe->new(inputs => [$input], output => $output, progress => \&progress, vcopy => 0, acopy => 0, multipass => 1);
$pipe->run;

ok($ok == 1, "progress information is strictly incresing when doing multipass");
ok($old_perc == 100, "progress stops at 100% when doing multipass");

unlink($output->url);
unlink($output->url . "-multipass-0.log");
