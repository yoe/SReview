#!/usr/bin/perl -w

use strict;
use warnings;

use ExtUtils::MakeMaker;
use ExtUtils::Depends;

my $eud = ExtUtils::Depends->new(qw/Alien::ffmpeg/);

WriteMakefile(
	NAME	=> "SReview",
	VERSION_FROM => "lib/SReview.pm",
	PREREQ_PM => {
		'Mojo::JSON' => 0,
		'Mojo::Pg' => 0,
		'Moose' => 0,
		'Mojolicious::Plugin::OAuth2::Server' => 0,
		'DateTime' => 0,
		'DateTime::Format::ISO8601' => 0,
		'Net::Amazon::S3' => 0,
	},
	TEST_REQUIRES => {
		'Test::More' => 0,
	},
	EXE_FILES => [
		'scripts/cut_talk/sreview-cut',
		'scripts/sreview-config',
		'scripts/sreview-detect',
		'scripts/sreview-dispatch',
		'scripts/sreview-skip',
		'scripts/sreview-user',
		'scripts/sreview-encode',
		'scripts/notify/sreview-notify',
		'scripts/upload/sreview-upload',
		'scripts/transcode/sreview-transcode',
		'scripts/previews/sreview-previews',
		'web/sreview-web',
	],
	$eud->get_makefile_vars
);
