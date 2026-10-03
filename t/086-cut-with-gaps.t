#!/usr/bin/perl -w

use strict;
use warnings;

use Cwd 'abs_path';

BEGIN {
	if(exists($ENV{SREVIEWTEST_DB})) {
		$ENV{SREVIEW_WDIR} = abs_path('.');
		open my $fh, '>', 'config.pm' or die "Cannot write config.pm: $!";
		print $fh "\$dbistring='dbi:Pg:dbname=$ENV{SREVIEWTEST_DB}';\n";
		print $fh "\$inputglob='" . abs_path('t/inputdir-gaps') . "/*/*/*';\n";
		print $fh "\$outputdir='" . abs_path('t/outputdir-gaps') . "';\n";
		print $fh "\$pubdir='" . abs_path('t/pubdir-gaps') . "';\n";
		# Filename timestamps must not be interpreted in the machine's
		# local timezone, or the raw files won't line up with the talk.
		print $fh "\$file_timezone='UTC';\n";
		close $fh;
	}
}

use Test::More;
use File::Path qw/make_path remove_tree/;

use DBI;
use Media::Convert::Asset;
use SReview::Config::Common;
use SReview::Db;
use SReview::Talk;
use SReview::Files::Factory;

sub run {
	my @command = @_;
	print "running: '", join("' '", @command), "'\n";
	system(@command) == 0 or die "system @command failed: $?";
}

my $scriptpath;

if(-f "/usr/bin/sreview-detect") {
	$scriptpath = "/usr/bin";
} else {
	$scriptpath = "./scripts/";
}

SKIP: {
	skip("Can't test cut-with-gaps unless the SREVIEWTEST_DB environment variable points to a database which we may clobber and recreate", 1)
		unless defined($ENV{SREVIEWTEST_DB});

	my $inputdir = abs_path('t/inputdir-gaps');
	my $outputdir = abs_path('t/outputdir-gaps');
	my $pubdir = abs_path('t/pubdir-gaps');

	# Prepare input directory with two raw files and a 3-second gap.
	# bbb.mp4 is 20 seconds long.
	#
	# Raw file 1: 16:59:50 to 17:00:10 (20s)
	# Raw file 2: 17:00:13 to 17:00:33 (20s)
	# Gap:        17:00:10 to 17:00:13 (3s)
	#
	# Talk:       17:00:00 to 17:00:20 (20s scheduled)
	#
	# Main coverage:
	#   raw1: 17:00:00 - 17:00:10 = 10s
	#   raw2: 17:00:13 - 17:00:20 =  7s
	#   total video:                17s (3s gap excluded)
	make_path("$inputdir/room1/2017-11-10");
	symlink('../../../testvids/bbb.mp4', "$inputdir/room1/2017-11-10/16:59:50.mp4")
		unless -e "$inputdir/room1/2017-11-10/16:59:50.mp4";
	symlink('../../../testvids/bbb.mp4', "$inputdir/room1/2017-11-10/17:00:13.mp4")
		unless -e "$inputdir/room1/2017-11-10/17:00:13.mp4";

	my $config = SReview::Config::Common::setup;

	# Clean database
	ok(SReview::Db::init($config), "Database initialized");
	ok(SReview::Db::selfdestruct(code => 0, init => 0), "Database clobbered");
	ok(SReview::Db::init($config), "Database re-initialized");

	my $dbh = DBI->connect($config->get('dbistring'), '', '', { RaiseError => 1, AutoCommit => 1 });
	$dbh->do("INSERT INTO rooms(id, name, altname) VALUES (1, 'room1', 'Room1')");
	$dbh->do("INSERT INTO events(id, name) VALUES(1, 'Test event')");

	my $st = $dbh->prepare(
		"INSERT INTO talks(id, room, slug, starttime, endtime, title, description, event, upstreamid) " .
		"VALUES(1, 1, 'test-talk-gaps', '2017-11-10 17:00:00+00', '2017-11-10 17:00:20+00', " .
		"'Test talk with gaps', 'Description', 1, '1') RETURNING nonce"
	);
	$st->execute();
	my $nonce = $st->fetchrow_arrayref->[0];
	my $relname = join("/", substr($nonce, 0, 1), substr($nonce, 1, 2), substr($nonce, 3));

	# Detect input files
	run($^X, "-I", $INC[0], "$scriptpath/sreview-detect");

	$st = $dbh->prepare("SELECT COUNT(*) FROM raw_files");
	$st->execute();
	my ($raw_count) = $st->fetchrow_array();
	cmp_ok($raw_count, '==', 2, "sreview-detect finds two raw files");

	# Verify gap detection via video_gaps()
	my $talk = SReview::Talk->new(talkid => 1);
	my $gaps = $talk->video_gaps;
	cmp_ok(scalar(@{$gaps->{main}}), '==', 2, "video_gaps: main has 2 fragments");
	cmp_ok($gaps->{main}[0]{cumulative_gap}, '==', 0, "video_gaps: first fragment has no gap");
	cmp_ok($gaps->{main}[1]{cumulative_gap}, '>', 2, "video_gaps: second fragment gap > 2s");
	cmp_ok($gaps->{main}[1]{cumulative_gap}, '<', 4, "video_gaps: second fragment gap < 4s");

	# --- Cut with no corrections ---
	$dbh->do("UPDATE talks SET state='cutting', progress='waiting' WHERE id=1");
	run($^X, "-I", $INC[0], "$scriptpath/sreview-cut", "1");

	my $coll = SReview::Files::Factory->create("intermediate", $config->get("pubdir"));
	ok($coll->has_file("$relname/0/main.mkv"), "main.mkv created (no corrections)");
	my $main_file = $coll->get_file(relname => "$relname/0/main.mkv");
	my $main_asset = Media::Convert::Asset->new(url => $main_file->filename);
	my $duration_no_corr = $main_asset->duration;

	# Main should be ~17s (10s + 7s), NOT 20s (scheduled length ignoring gap)
	cmp_ok($duration_no_corr, '>', 16, "main duration > 16s (no corrections)");
	cmp_ok($duration_no_corr, '<', 18, "main duration < 18s (gap correctly excluded)");

	# --- Cut with length_adj = -5 ---
	# Simulates a reviewer trimming 5 seconds from the end of the talk.
	# offset_start shifts the entire window (both start and end), so it
	# doesn't change total duration.  length_adj actually shortens the
	# talk window, producing a measurably shorter output.
	#
	# Expected main:
	#   raw1: 17:00:00 - 17:00:10 = 10s
	#   raw2: 17:00:13 - 17:00:15 =  2s
	#   total:                      12s
	$dbh->do("DELETE FROM corrections WHERE talk = 1");
	$dbh->do("INSERT INTO corrections (talk, property, property_value) VALUES (1, (SELECT id FROM properties WHERE name = 'length_adj'), '-5')");
	$dbh->do("UPDATE talks SET state='cutting', progress='waiting' WHERE id=1");

	$coll->delete_files(relnames => [$relname]);

	run($^X, "-I", $INC[0], "$scriptpath/sreview-cut", "1");

	ok($coll->has_file("$relname/0/main.mkv"), "main.mkv created (with length_adj)");
	$main_file = $coll->get_file(relname => "$relname/0/main.mkv");
	$main_asset = Media::Convert::Asset->new(url => $main_file->filename);
	my $duration_corrected = $main_asset->duration;

	cmp_ok($duration_corrected, '>', 11, "corrected main duration > 11s");
	cmp_ok($duration_corrected, '<', 13, "corrected main duration < 13s");

	# length_adj=-5 should reduce duration by ~5s (from ~17s to ~12s)
	my $reduction = $duration_no_corr - $duration_corrected;
	cmp_ok($reduction, '>', 4, "length_adj reduced duration by ~5s (> 4s)");
	cmp_ok($reduction, '<', 6, "length_adj reduced duration by ~5s (< 6s)");
}

done_testing;

unlink("config.pm");
remove_tree("t/inputdir-gaps", "t/outputdir-gaps", "t/pubdir-gaps");
