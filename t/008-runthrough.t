#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 9;

use Cwd 'abs_path';

$ENV{SREVIEW_WDIR} = abs_path('.');

use DBI;
use SReview::Video;
use SReview::Config::Common;
use File::Path qw/make_path remove_tree/;

remove_tree("t/inputdir", "t/outputdir", "t/pubdir");
sub run {
	my @command = @_;

	print "running: '", join("' '", @command), "'\n";
	system(@command) == 0 or die "system @command failed: $?";
}

SKIP: {
	skip("Can't test database work unless the SREVIEWTEST_DB environment variable points to a database which we may clobber and recreate", 9) unless defined($ENV{SREVIEWTEST_DB});

	# Prepare an input directory
	make_path('t/inputdir/room1/2017-11-10');
	symlink('../../../testvids/bbb.mp4', 't/inputdir/room1/2017-11-10/17:00:00.mp4');

	# Prepare the configuration
	run("perl", "-I./blib/lib", "blib/script/sreview-config", "--action", "update", "--set", "dbistring=dbi:Pg:dbname=" . $ENV{SREVIEWTEST_DB}, "--set", "inputglob=" . abs_path("t/inputdir") . "/*/*/*", "--set", "outputdir=" . abs_path('t/outputdir'), "--set", "pubdir=" . abs_path('t/pubdir'), "--set", "preroll_template=" . abs_path("t/testvids/just-title.svg"), "--set", "postroll_template=" . abs_path("t/testvids/just-title.svg"));

	ok(-f 'config.pm', "running sreview-config with -a update creates a config.pm");

	my $config = SReview::Config::Common::setup;
	isa_ok($config, 'SReview::Config');

	$config->set('dbistring' => 'dbi:Pg:dbname=' . $ENV{SREVIEWTEST_DB});

	# Prepare the input database
	my $dbh = DBI->connect($config->get('dbistring'));
	$dbh->prepare("INSERT INTO rooms(id, name, altname) VALUES (1, 'room1', 'Room1')")->execute() or die $!;
	$dbh->prepare("INSERT INTO events(id, name) VALUES(1, 'Test event')")->execute() or die $!;
	$dbh->prepare("INSERT INTO talks(id, room, slug, starttime, endtime, title, event, upstreamid) VALUES(1, 1, 'test-talk', '2017-11-10 17:00:00', '2017-11-10 17:00:10', 'Test talk', 1, '1')")->execute() or die $!;

	# Detect input files
	run("perl", "-I./blib/lib", "blib/script/sreview-detect");

	my $st = $dbh->prepare("SELECT * FROM raw_talks");
	$st->execute();
	ok($st->rows == 1, "sreview-detect detects one file");

	my $row = $st->fetchrow_hashref();

	my $input = SReview::Video->new(url => abs_path("t/testvids/bbb.mp4"));
	# perform cut
	run("perl", "-I./blib/lib", "blib/script/sreview-cut", $row->{talkid});

	my $check = SReview::Video->new(url => abs_path("t/pubdir/1/2017-11-10/r/test-talk.mkv"));
	my $length = $check->duration;
	ok($length > 9.75 && $length < 10.25, "The generated cut video is of approximately the right length");
	ok($check->video_codec eq $input->video_codec, "The input video codec is the same as the pre-cut video codec");
	ok($check->audio_codec eq $input->audio_codec, "The input audio codec is the same as the pre-cut audio codec");

	run("perl", "-I./blib/lib", "blib/script/sreview-previews", $row->{talkid});

	$check = SReview::Video->new(url => abs_path("t/pubdir/1/2017-11-10/r/test-talk.mkv"));
	ok($length == $check->duration, "The preview video is of the right length");

	# perform transcode
	run("perl", "-I./blib/lib", "blib/script/sreview-transcode", $row->{talkid});
	my $final = SReview::Video->new(url => abs_path("t/outputdir/Test event/room1/2017-11-10/test-talk.webm"));
	ok($final->video_codec eq "vp9", "The transcoded video has the right codec");
	ok($final->audio_codec eq "opus", "The transcoded audio has the right codec");
}

unlink("config.pm");
