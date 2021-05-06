#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use DBI;
use SReview::Talk::State;

SKIP: {
	skip("Can't test database work unless the SREVIEWTEST_DB environment variable points to a database which we may clobber and recreate", 1) unless defined($ENV{SREVIEWTEST_DB});
	my $db = DBI->connect('dbi:Pg:dbname=' . $ENV{SREVIEWTEST_DB});

	my $st = $db->prepare("SELECT enum_range(null::talkstate)");
	$st->execute;
	my $val = $st->fetchrow_arrayref()->[0];
	$val =~ s/(\{|\})//g;
	my @values_db = split /,/, $val;
	my @values_mod = @{SReview::Talk::State->values};
	foreach my $value(@values_db) {
		isa_ok(SReview::Talk::State->new($value), "SReview::Talk::State");
		ok($value eq shift @values_mod, "$value exists in db and module at same location");
	}
}

done_testing;
