#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 6;

use SReview::Db;
use SReview::Config;
use SReview::Config::Common;

use DBI;

SKIP: {
	skip("Can't test database work unless the SREVIEW_TESTDB environment variable points to a database which we may clobber and recreate", 6) unless defined($ENV{SREVIEW_TESTDB});

	my $warn;
	local $SIG{__WARN__} = sub { $warn = shift };

	my $config = SReview::Config->new('config');

	isa_ok($config, 'SReview::Config');

	SReview::Config::Common::setup($config);

	$config->set(dbistring => 'dbi:Pg:dbname=' . $ENV{SREVIEW_TESTDB});

	ok(SReview::Db::init($config), "Initializing the database was successful");
	ok(SReview::Db::selfdestruct(4), "Clobbering and recreating the database works");
	my $db = DBI->connect($config->get('dbistring'), '', '', {AutoCommit => 1});
	ok(defined($db), "connecting to the database was successful");
	my $q = $db->prepare("SELECT * FROM raw_files");
	ok(defined($q), "preparing a query succeeds");
	ok(defined($q->execute), "running a query succeeds, and the tables exist");
}
