#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';
use_ok('SReview::Config');

my $val;
local $SIG{__WARN__} = sub { $val = shift; };

my $config = SReview::Config->new('config');
ok($val =~ /^Warning: could not find configuration file config, falling back to defaults at t\/config\.t line \d+\.$/, 'loading nonexisting config produces a warning but succeeds');
isa_ok($config, 'SReview::Config');

$val = '';
$config = SReview::Config->new('t/test.cf');
ok(length($val) == 0, 'loading an existing config file succeeds and prints no warning');
