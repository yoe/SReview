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
		'Mojolicious::Plugin::OpenAPI' => 0,
		'Moose' => 0,
		'DateTime' => 0,
		'DateTime::Format::ISO8601' => 0,
		'Net::Amazon::S3' => 0,
	},
	TEST_REQUIRES => {
		'Test::More' => 0,
	},
	EXE_FILES => [
		'scripts/sreview-cut',
		'scripts/sreview-config',
		'scripts/sreview-copy',
		'scripts/sreview-detect',
		'scripts/sreview-dispatch',
		'scripts/sreview-skip',
		'scripts/sreview-user',
		'scripts/sreview-encode',
		'scripts/sreview-notify',
		'scripts/sreview-upload',
		'scripts/sreview-transcode',
		'scripts/sreview-previews',
		'scripts/sreview-inject',
		'scripts/sreview-inject-job',
		'web/sreview-web',
	],
	$eud->get_makefile_vars
);
