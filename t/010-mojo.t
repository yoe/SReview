#!/usr/bin/perl -w

BEGIN {
	if(exists($ENV{SREVIEW_TESTDB})) {
		open my $config, ">config.pm";
		print $config '$secret="foo";' . "\n";
		print $config '$dbistring=\'dbi:Pg:dbname=' . $ENV{SREVIEW_TESTDB} . '\';' . "\n";
		close $config;
	}
}

use strict;
use warnings;

use Test::More;
use Test::Mojo;
use Mojo::File qw/path/;
use SReview::Talk;
use SReview::Video;

my $cfgname = path()->to_abs->child('config.pm');

SKIP: {
	skip("Need a database to play with", 24) unless exists($ENV{SREVIEW_TESTDB});

	my $script = path(__FILE__);
	$script = $script->dirname->child('..')->child('web')->child('sreview-web');
	my $t = Test::Mojo->new($script);
	chdir($script->dirname);

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
	  ->json_is("/start_iso" => $talk->corrected_times->{start_iso});

	my $video = SReview::Video->new(url => $talk->outname . ".mkv");

	$t->post_ok("$talkurl/update" => form => { start_time => "too_early", start_time_corrval => $video->duration - 0.5 })
	  ->status_is(200);

	$video = undef;

	$talk->comment("test");
	$talk->set_state("broken");
	$talk->done_correcting;

	$t->get_ok($talkurl)->status_is(200)->text_is("textarea#comment_text" => "test");
};

unlink($cfgname);

done_testing();
