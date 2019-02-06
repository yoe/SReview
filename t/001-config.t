#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 9;
use File::Temp qw/tempfile/;
use_ok('SReview::Config');

my $val;
local $SIG{__WARN__} = sub { $val = shift; };

my $config = SReview::Config->new('config');
ok($val =~ /^Warning: could not find configuration file config, falling back to defaults at t\/001-config\.t line \d+\.$/, 'loading nonexisting config produces a warning but succeeds');
isa_ok($config, 'SReview::Config');

$val = '';
$config = SReview::Config->new('t/test.cf');
ok(length($val) == 0, 'loading an existing config file succeeds and prints no warning');

$config->define('test', 'testingk', 1);
my $rv = $config->dump();
my @expect = ("# testingk", "#\$test = 1;", "# Do not remove this, perl needs it", "1;");
my $ok = 1;
foreach my $line(split /\n/, $rv) {
	next unless length($line);
	my $expline = shift @expect;
	if($expline ne $line) {
		$ok = 0;
	}
}
ok($ok, "Config dump output is as expected");
ok($config->describe('test') eq 'testingk', "Description of configuration value is as expected");
my ($f, $filename) = tempfile('configtest-XXXXXXXX', UNLINK => 1);
print $f '{';
eval {
	my $config = SReview::Config->new($filename);
};
ok(defined($@), "Trying to parse a syntactically invalid perl script produces an exception");
eval {
	my $val = $config->get('foo');
};
ok(defined($@), "Trying to read a config variable that does not exist produces an exception");
$val = $config->get('test');
ok($val == 1, "Reading data that does not exist yet produces the default");
