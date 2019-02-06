#!/usr/bin/perl -w

BEGIN {
	open my $config, ">config.pm";
	print $config '$secret="foo";' . "\n";
	close $config;
}

use strict;
use warnings;

use Test::More;
use Test::Mojo;
use Mojo::File qw/path/;
use SReview::Talk;

my $cfgname = path()->realpath->child('config.pm');
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
  ->text_like("h1" => "/\s*" . $talk->title . "\s*/");
$t->get_ok("$talkurl/data")->status_is(200)
  ->json_is("/end" => $talk->corrected_times->{end})
  ->json_is("/start" => $talk->corrected_times->{start})
  ->json_is("/end_iso" => $talk->corrected_times->{end_iso})
  ->json_is("/start_iso" => $talk->corrected_times->{start_iso});

$talk->comment("test");
$talk->set_state("broken");
$talk->done_correcting;

$t->get_ok($talkurl)->status_is(200)->text_is("textarea#comment_text" => "test");

unlink($cfgname);

done_testing();
