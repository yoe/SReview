#!/usr/bin/perl -w

use strict;
use warnings;

use Cwd 'abs_path';

BEGIN {
	if(exists($ENV{SREVIEWTEST_DB})) {
		open my $config, ">config.pm";
		print $config '$secret="foo";' . "\n";
		print $config '$dbistring=\'dbi:Pg:dbname=' . $ENV{SREVIEWTEST_DB} . '\';' . "\n";
		print $config '$outputdir="' . abs_path('t/outputdir') . '";' . "\n";
		print $config '$pubdir="' . abs_path('t/pubdir') . '";' . "\n";
		close $config;
	}
}

use Test::More tests => 63;
use Test::Mojo;
use Mojo::File qw/path/;
use DBI;
use SReview::Config::Common;
use SReview::Db;
use SReview::Talk;
use Media::Convert::Asset;
use SReview::Web;

my $cfgname = path()->to_abs->child('config.pm');

SKIP: {
	skip("Need a database to play with", 63) unless (exists($ENV{SREVIEWTEST_DB}) or exists($ENV{SREVIEWTEST_INSTALLED}) or exists($ENV{AUTOPKGTEST_TMP}));

	# Set up a talk with gaps in its recording, so that the /data
	# endpoint is tested with a real gap table:
	#
	#   pre window  16:40:00 - 17:00:00, footage from 16:50:00
	#   talk        17:00:00 - 17:00:10, footage missing 17:00:03 - 17:00:05
	my $config = SReview::Config::Common::setup;
	ok(SReview::Db::init($config), "Initializing the database was successful");
	ok(SReview::Db::selfdestruct(code => 0, init => 0), "Clobbering the database works");
	ok(SReview::Db::init($config), "Re-initializing the database after clobbering it was successful");
	my $dbh = DBI->connect($config->get('dbistring'), '', '', { RaiseError => 1, AutoCommit => 1 });
	$dbh->do("INSERT INTO rooms(id, name, altname, outputname) VALUES (1, 'room1', 'Room1', 'room1')");
	$dbh->do("INSERT INTO events(id, name, outputdir) VALUES(1, 'Test event', NULL)");
	$dbh->do("INSERT INTO tracks(id, name) VALUES(1, 'Track 1')");
	$dbh->do(q{INSERT INTO talks(id, room, slug, starttime, endtime, title, subtitle, description, event, upstreamid, track, state, progress, apologynote, active_stream, extra_data, flags) VALUES(1, 1, 'test-talk', '2017-11-10 17:00:00+00', '2017-11-10 17:00:10+00', 'Test talk', 'Sub', 'Test talk description', 1, 'up1', 1, 'waiting_for_files', 'waiting', NULL, '', '{"foo":"bar"}', '{"a":true}')});
	$dbh->do("INSERT INTO raw_files(id, filename, room, starttime, endtime, stream) VALUES(1, 'room1/raw1.mkv', 1, '2017-11-10 16:50:00+00', '2017-11-10 17:00:03+00', '')");
	$dbh->do("INSERT INTO raw_files(id, filename, room, starttime, endtime, stream) VALUES(2, 'room1/raw2.mkv', 1, '2017-11-10 17:00:05+00', '2017-11-10 17:20:10+00', '')");
	$dbh->disconnect;

	my $script = path(__FILE__);
	$script = $script->dirname->child('..')->child('web')->child('sreview-web')->to_abs;
	if(exists($ENV{SREVIEWTEST_INSTALLED}) or exists($ENV{AUTOPKGTEST_TMP})) {
		$script = "SReview::Web";
	} else {
		symlink "../t", "web/t";
		chdir($script->dirname);
	}
	my $t = Test::Mojo->new($script);

	$t->post_ok("/r/1234567890abcdefghij/update" => form => { foo => "bar" })->status_is(404);

	my $talk = SReview::Talk->new(talkid => 1);

	$t->get_ok('/')->status_is(200)->content_like(qr/SReview/);
	$t->get_ok('/o')->status_is(302)->header_like(Location => qr/overview$/);
	$t->get_ok('/admin')->status_is(302)->header_like(Location => qr/login$/);
	my $talkurl = '/r/' . $talk->nonce;
	$t->get_ok($talkurl)->status_is(200)
	  ->text_is("h1>small" => $talk->eventname . " videos")
	  ->text_like("h1" => "/\\s*" . $talk->title . "\\s*/");
	$t->get_ok("$talkurl/data")->status_is(200)
	  ->json_is("/end" => $talk->corrected_times->{end})
	  ->json_is("/start" => $talk->corrected_times->{start})
	  ->json_is("/end_iso" => $talk->corrected_times->{end_iso})
	  ->json_is("/start_iso" => $talk->corrected_times->{start_iso})
	  ->json_has("/video_gaps")
	  ->json_has("/video_gaps/pre")
	  ->json_has("/video_gaps/main")
	  ->json_has("/video_gaps/post")
	  ->json_is("/video_gaps/pre/0/cumulative_gap" => 600)
	  ->json_is("/video_gaps/main/0/cumulative_gap" => 0)
	  ->json_is("/video_gaps/main/1/video_offset" => 3)
	  ->json_is("/video_gaps/main/1/cumulative_gap" => 2)
	  ->json_is("/pre_window_length" => 1200);

	my $video = Media::Convert::Asset->new(url => $talk->outname . ".mkv");

	$talk->set_state("preview");
	$talk = SReview::Talk->new(talkid => 1);

	$talk->corrections;
	$talk->set_correction(serial => -1);
	$talk->done_correcting;

	$t->post_ok("$talkurl/update" => form => { serial => 0, video_state => "ok" })->status_is(400);

	my $formdata = {
		start_time => "start_time_ok",
		end_time => "end_time_late",
		end_time_corrval => "0.5",
		av_sync => "av_ok",
		serial => $talk->corrections->{serial},
		video_state => "not_ok",
		audio_channel => $talk->corrections->{audio_channel},
	};
	$t->post_ok("$talkurl/update" => form => $formdata)->status_is(200);

	$talk->set_state("preview");
	$talk = SReview::Talk->new(talkid => 1);

	my $expected_end = $talk->corrected_times->{end};
	$expected_end =~ /(.*?)(\+\d{2})$/;
	my $expected_end_base = $1;
	my $expected_end_tz = $2;
	$expected_end_base =~ s/\.\d+$//;
	my $expected_end_base_qm = quotemeta($expected_end_base);
	my $expected_end_tz_qm = quotemeta($expected_end_tz);

	$t->get_ok("$talkurl/data")->status_is(200)
	  ->json_like("/end" => qr/^${expected_end_base_qm}(?:\.5)?${expected_end_tz_qm}$/);

	$formdata->{av_sync} = "av_not_ok_audio";
	$formdata->{av_seconds} = "1";
	$formdata->{end_time} = "end_time_ok";
	$formdata->{serial} = $talk->corrections->{serial};
	delete $formdata->{end_time_corrval};

	$t->post_ok("$talkurl/update" => form => $formdata)->status_is(200);

	$talk->set_state("preview");

	$talk = SReview::Talk->new(talkid => 1);
	ok($talk->corrections->{offset_audio} == 1, "audio delay A/V sync value is set correctly");
	ok($talk->corrections->{serial} == $formdata->{serial} + 1, "updates affect serial");

	$t->post_ok("$talkurl/update" => form => $formdata)->status_is(409);

	$formdata->{av_sync} = "av_not_ok_video";
	$formdata->{serial} = $talk->corrections->{serial};
	$formdata->{comment_text} = "Thanks!";

	$t->post_ok("$talkurl/update" => form => $formdata)->status_is(200);

	$talk->set_state("preview");

	$talk = SReview::Talk->new(talkid => 1);
	ok($talk->corrections->{offset_audio} == 0, "video delay A/V sync value is set correctly");
	like($talk->comment, qr/Thanks!/, "Comments are accepted");

	$t->post_ok("$talkurl/update" => form => {serial => $talk->corrections->{serial}, complete_reset => 1})->status_is(200);

	$talk = SReview::Talk->new(talkid => 1);
	my $corrs = $talk->corrections;
	foreach my $corr(keys %$corrs) {
		if($corrs->{$corr} == 0) {
			delete $corrs->{$corr};
		}
	}
	is_deeply($talk->corrections, {serial => $talk->corrections->{serial}}, "a complete reset only leaves the correction serial");

	$talk->set_state("preview");
	$t->post_ok("$talkurl/update" => form => {serial => $talk->corrections->{serial}, "video_state" => "ok"})->status_is(200);

	$talk = SReview::Talk->new(talkid => 1);

	$t->post_ok("$talkurl/update" => form => {serial => $talk->corrections->{serial}})->status_is(400);

	$talk->set_state("finalreview");

	$t->post_ok("$talkurl/update" => form => $formdata)->status_is(403);

	$formdata = {
		video_state => "ok",
		serial => $talk->corrections->{serial},
	};

	$talkurl = "/f/" . $talk->nonce;

	$t->post_ok("$talkurl/update" => form => $formdata)->status_is(200);
	$talk = SReview::Talk->new(talkid => 1);
	ok($talk->state eq 'finalreview', 'confirmation in final review is handled correctly - state');
	ok($talk->progress eq 'done', 'confirmation in final review is handled correctly - progress');

	chdir("..");
	unlink("web/t");
};

	unlink($cfgname);
