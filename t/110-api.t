#!/usr/bin/perl -w

use strict;
use warnings;

use Cwd 'abs_path';

use SReview::Db;
use SReview::Config::Common;

BEGIN {
	if(exists($ENV{SREVIEWTEST_DB})) {
		open my $config, ">config.pm";
		print $config '$secret="foo";' . "\n";
		print $config '$dbistring=\'dbi:Pg:dbname=' . $ENV{SREVIEWTEST_DB} . '\';' . "\n";
		print $config '$outputdir="' . abs_path('t/outputdir') . '";' . "\n";
		print $config '$pubdir="' . abs_path('t/pubdir') . '";' . "\n";
		print $config '$api_key="foobarbaz"' . "\n";
		close $config
	}
}

use Test::More;
use Test::Mojo;
use Mojo::File qw/path/;

my $cfgname = path()->to_abs->child('config.pm');
my $do_auth = 0;

SReview::Db::init(SReview::Config::Common::setup());
SReview::Db::selfdestruct(code => 0, init => 0);

SKIP: {
	skip("Need a database to play with", 1) unless exists($ENV{SREVIEWTEST_DB});

	my $script = path(__FILE__);
	$script = $script->dirname->child('..')->child('web')->child('sreview-web')->to_abs;
	symlink "../t", "web/t";
	chdir($script->dirname);
	my $t = Test::Mojo->new($script);

	$t->ua->on(start => sub {
		my ($ua, $tx) = @_;
		if($do_auth) {
			$tx->req->headers->authorization("foobarbaz");
		}
	});

	my $b = '/api/v1';

	# events
	$t->get_ok("$b/")->status_is(200)->json_is("/info/title" => "SReview API");
	$t->get_ok("$b/event/list")->status_is(200)->json_is(""=>[]);
	$t->post_ok("$b/event" => json => {name => 'Test event'})->status_is(401);
	$do_auth = 1;
	$t->post_ok("$b/event" => json => {name => 'Test event'})->status_is(200)->json_is('/name' => "Test event")->json_is('/inputdir' => undef)->json_is('/id' => 1);
	$do_auth = 0;
	$t->get_ok("$b/event/list")->status_is(200)->json_is('/0/name' => 'Test event')->json_is('/0/inputdir' => undef);
	$t->get_ok("$b/event/1")->status_is(200)->json_is('/name' => 'Test event');
	$t->patch_ok("$b/event/1" => json => {inputdir => "foo"})->status_is(401);
	$do_auth = 1;
	$t->patch_ok("$b/event/1" => json => {inputdir => "foo"})->status_is(200)->json_is('/inputdir' => 'foo')->json_is('/name' => 'Test event');
	$t->post_ok("$b/event" => json => {name => 'bad event'})->status_is(200)->json_is('/id' => 2);
	$do_auth = 0;
	$t->delete_ok("$b/event/2")->status_is(401);
	$t->get_ok("$b/event/2")->status_is(200)->json_is('/id' => 2)->json_is('/name' => 'bad event');
	$do_auth = 1;
	$t->delete_ok("$b/event/2")->status_is(200);
	$t->get_ok("$b/event/2")->status_is(404);
	$t->delete_ok("$b/event/2")->status_is(404);

	# rooms
	$t->get_ok("$b/room/list")->status_is(200)->json_is(""=>[]);
	$t->post_ok("$b/room" => json => {name => 'Test room'})->status_is(200)->json_is('/name' => 'Test room')->json_is('/id' => 1);
	$t->get_ok("$b/room/1")->status_is(200)->json_is('/name' => 'Test room')->json_is('/id' => 1);
	$t->get_ok("$b/room/list")->status_is(200)->json_is("/0/name" => 'Test room')->json_is('/0/id' => 1);
	$do_auth = 0;
	$t->post_ok("$b/room" => json => {})->status_is(401);
	$t->get_ok("$b/room/1")->status_is(200)->json_is('/name' => 'Test room')->json_is('/id' => 1);
	$do_auth = 1;
	$t->patch_ok("$b/room/1" => json => { altname => "foo" })->status_is(200)->json_is('/altname' => "foo");
	$t->patch_ok("$b/room/3" => json => { altname => "bar" })->status_is(404);
	$do_auth = 0;
	$t->patch_ok("$b/room/1" => json => { altname => "bar" })->status_is(401);
	$t->get_ok("$b/room/1")->status_is(200)->json_is('/altname' => 'foo')->json_is('/name' => 'Test room');
	$do_auth = 1;
	$t->post_ok("$b/room" => json => {"name" => "deletable"})->status_is(200)->json_is("/id" => 2)->json_is('/name' => 'deletable');
	$t->delete_ok("$b/room/2")->status_is(200);
	$do_auth = 0;
	$t->get_ok("$b/room/2")->status_is(404);
}

unlink($cfgname);

done_testing;
