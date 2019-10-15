#!/usr/bin/perl -w

use strict;
use warnings;

use Mojo::UserAgent;
use Mojo::JSON qw/decode_json/;
use SReview::Talk;
use Data::Dumper;

my $ua = Mojo::UserAgent->new;

my $res = $ua->post(join('/', $ENV{BASEURL}, 'login_post' => form => { email => $ENV{SREVIEW_ADMINUSER}, pass => $ENV{SREVIEW_ADMINPW} }))->result;

$res->is_success or die "error " . $res->code . ": " . $res->message;

my $talk = SReview::Talk->new(talkid => 1);

$res = $ua->get(join('/', $ENV{BASEURL}, $talk->nonce, 'data'))->result;

$res->is_success or die "error " . $res->code . ": " . $res->message;

my $json = decode_json($res->body);

print Dumper($json);
