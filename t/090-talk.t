#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 11;
use Test::Deep;
use SReview::Config::Common;
use Data::Dumper;

my $config = SReview::Config::Common::setup;

SKIP: {
	skip("Can't test database work unless the SREVIEWTEST_DB environment varialbe points to a database which we may clobber and recreate", 11) unless defined($ENV{SREVIEWTEST_DB});

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

	cmp_deeply($talk->corrections, { offset_start => num(0), length_adj => num(0), offset_audio => num(0), audio_channel => num(0)}, 'Corrections are set correctly');
	cmp_deeply($talk->video_fragments, [
		{ talkid => num(-1), rawid => num(1), raw_filename => 'room1/2017-11-10/17:00:00.mp4', fragment_start => num(0), raw_length => num(20, .025), raw_length_corrected => num(0) },
		{ talkid => num(1), rawid => num(1), raw_filename => 'room1/2017-11-10/17:00:00.mp4', fragment_start => num(0), raw_length => num(20, .025), raw_length_corrected => num(10) },
		{ talkid => num(-2), rawid => num(1), raw_filename => 'room1/2017-11-10/17:00:00.mp4', fragment_start => num(10), raw_length => num(20, .025), raw_length_corrected => num(10, .025) }],
	'Video fragments are found correctly');

	$talk->add_correction(offset_start => 2);
        $talk->done_correcting;
	ok($talk->corrections->{offset_start} == 2, 'Corrections are accepted');

	my $newtalk = SReview::Talk->new(talkid => 1);
	ok($newtalk->corrections->{offset_start} == 2, 'Corrections are written to the database');
	ok($newtalk->corrections->{length_adj} == -2, 'Start offset changes length adjustment');
	ok($newtalk->corrections->{serial} == 1, 'Setting corrections bumps the serial');
}
