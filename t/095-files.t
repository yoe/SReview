#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 12;
use SReview::Config::Common;
use Data::Dumper;
use File::Copy;
use Mojo::JSON qw/decode_json/;

my $config = SReview::Config::Common::setup;

$config->set("outputdir", "t/testvids");
$config->set("accessmethods", {input => "direct", output => "direct", intermediate => "direct"});

use_ok("SReview::Files::Factory");

my $coll = SReview::Files::Factory->create("output", "t/testvids");

isa_ok($coll, "SReview::Files::Collection::Base");
isa_ok($coll, "SReview::Files::Collection::direct");
my $children = $coll->children;
isa_ok($children, "ARRAY");
my $child = $children->[0];
isa_ok($child, "SReview::Files::Access::Base");
isa_ok($child, "SReview::Files::Access::direct");
ok(defined($child->filename), "child has a filename");

SKIP: {
	skip("Can't test S3 work unless the s3_access_config configuration is valid", 4) unless (exists($ENV{SREVIEWTEST_BUCKET}) && exists($ENV{SREVIEWTEST_S3_CONFIG}));

	$config->set("s3_access_config", decode_json($ENV{SREVIEWTEST_S3_CONFIG}));
	$config->set("accessmethods", {input => "S3", output => "S3", intermediate => "S3"});
	$config->set("outputdir", $ENV{SREVIEWTEST_BUCKET});
	$coll = SReview::Files::Factory->create("output", $ENV{SREVIEWTEST_BUCKET});

	isa_ok($coll, "SReview::Files::Collection::Base");
	isa_ok($coll, "SReview::Files::Collection::S3");

	my $new = $coll->add_file(relname => $child->relname);
	ok($new->relname eq $child->relname, "creating a file with a relname from another bucket creates the same relname");
	copy($child->filename, $new->filename);
	$new->store_file;
	$children = $coll->children;
	ok($coll->has_file($new->relname), "adding a file creates it in the bucket");
	$new->delete;
	$coll = SReview::Files::Factory->create("output", $ENV{SREVIEWTEST_BUCKET});
	ok(!($coll->has_file($new->relname)), "deleting a file removes it");
}
