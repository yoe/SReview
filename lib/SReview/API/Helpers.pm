package SReview::API::Helpers;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw/db_query db_query_log update_with_json/;

use SReview::Config::Common;
use Mojo::JSON qw/decode_json/;

sub db_query_log {
	my ($app, $dbh, $query, @args) = @_;
	my $st = $dbh->prepare($query);
	$st->execute(@args);
	my @results;
	while(my $row = $st->fetchrow_arrayref) {
		if(defined($app)) {
			$app->log->debug('found row with first column: ' . $row->[0]);
		}
		if(scalar(@{$row}) == 1) {
			push @results, $row->[0];
		} else {
			push @results, "[" . join(",", @$row) . "]";
		}
	}
	return decode_json("[" . join(",", @results) . "]");
}

sub db_query {
	my ($dbh, $query, @args) = @_;

	return db_query_log(undef, $dbh, $query, @args);
}

sub update_with_json {
	my ($c, $json, $tablename, $fields) = @_;

	my @args;

	if(!exists($json->{id})) {
		$c->res->code(400);
		$c->render(text => 'id required');
		return;
	}

	my @updates;

	while(my @tuple = each %$json) {
		next if($tuple[0] eq "id");
		next unless(exists($fields->{$tuple[0]}));
		my $update = "${tuple[0]} = ?";
		push @updates, $update;
		push @args, $tuple[1];
	}
	my $updates = join(', ', @updates);
	my $res = db_query($c->dbh, "UPDATE $tablename SET $updates WHERE id = ? RETURNING row_to_json($tablename.*)", @args, $json->{id});

	if(scalar(@$res) < 1) {
		$c->res->code(404);
		$c->render(text => "not found");
		return;
	}

	$c->render(openapi => $res->[0]);
}
