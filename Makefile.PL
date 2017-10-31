#!/usr/bin/perl -w

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME	=> "SReview",
	VERSION_FROM => "lib/SReview.pm",
	PREREQ_PM => {
		'Mojo::JSON' => 0,
		'Mojo::Pg' => 0,
		'Moose' => 0,
	},
	TEST_REQUIRES => {
		'Test::More' => 0,
	},
);
