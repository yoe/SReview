#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 10;
use SReview::Config::Common;
use Data::Dumper;
use Cwd;

my $config = SReview::Config::Common::setup;

SKIP: {
	skip("Can't test database work unless the SREVIEWTEST_DB environment varialbe points to a database which we may clobber and recreate", 10) unless defined($ENV{SREVIEWTEST_DB});

	$config->set(dbistring => 'dbi:Pg:dbname=' . $ENV{SREVIEWTEST_DB});
	$config->set('output_subdirs' => [ 'eventid', 'event', 'room', 'date', 'year' ]);
	$config->set('pubdir' => '/srv/sreview/web/public/video');

	use_ok('SReview::Talk');

	my $talk = SReview::Talk->new(talkid => 1);
	isa_ok($talk, 'SReview::Talk');

	my $relname = join("/", substr($talk->nonce, 0, 1), substr($talk->nonce, 1, 2), substr($talk->nonce, 3), $talk->has_correction("serial") ? $talk->corrections->{serial} : 0);

	ok($talk->workdir eq "/srv/sreview/web/public/video/$relname", 'The workdir resolves to the correct value');

	ok($talk->finaldir eq "/srv/sreview/output/1/Test event/room1/2017-11-10/2017", 'The output directory resolves to the correct value');

	ok($talk->slug eq 'test-talk', 'The talk slug resolves to the correct value');

	is_deeply($talk->corrections, { offset_start => 0, length_adj => 0, offset_audio => 0, audio_channel => 0}, 'Corrections are set correctly');
	is_deeply($talk->video_fragments, [
		{ talkid => -1, rawid => 1, raw_filename => cwd() . '/t/inputdir/room1/2017-11-10/17:00:00.mp4', fragment_start => 0, raw_length => 20.024, raw_length_corrected => 0 },
		{ talkid => 1, rawid => 1, raw_filename => cwd() . '/t/inputdir/room1/2017-11-10/17:00:00.mp4', fragment_start => 0, raw_length => 20.024, raw_length_corrected => 10 },
		{ talkid => -2, rawid => 1, raw_filename => cwd() . '/t/inputdir/room1/2017-11-10/17:00:00.mp4', fragment_start => 10, raw_length => 20.024, raw_length_corrected => 10.024 }],
	'Video fragments are found correctly');

	$talk->add_correction(offset_start => 2);
        $talk->done_correcting;
	ok($talk->corrections->{offset_start} == 2, 'Corrections are accepted');

	my $newtalk = SReview::Talk->new(talkid => 1);
	ok($newtalk->corrections->{offset_start} == 2, 'Corrections are written to the database');
	ok($newtalk->corrections->{length_adj} == -2, 'Start offset changes length adjustment');
}
