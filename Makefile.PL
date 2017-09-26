#!/usr/bin/perl -w

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME	=> "SReview",
	VERSION => "0.1",
	PREREQ_PM => {
		'Mojo::JSON' => 0,
		'DBD::Pg' => 0,
		'Moose' => 0,
	},
	TEST_REQUIRES => {
		'Test::More' => 0,
	},
);
