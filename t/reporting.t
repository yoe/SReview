#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';

use_ok('SReview::Video');
use_ok('SReview::Videopipe');

my $input = SReview::Video->new(url => 't/testvids/7184709189_sd.mp4');
my $output = SReview::Video->new(url => 't/testvids/out.ts');

my $old_perc;
my $ok = 1;

sub progress {
	my $perc = shift;

	if(defined($old_perc) && $perc < $old_perc) {
		$ok = 0;
	}
	$old_perc = $perc;
}

my $pipe = SReview::Videopipe->new(inputs => [$input], output => $output, progress => \&progress);

isa_ok($pipe, 'SReview::Videopipe');

$pipe->run;
ok($ok == 1, "progress information is strictly increasing");
ok($old_perc == 100, "progress stops at 100%");
