package SReview::API::Helpers;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw/db_query update_with_json add_with_json delete_with_query/;
our @EXPORT_OK = qw/db_query_log/;

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

sub delete_with_query {
	my ($c, $query, @args) = @_;

	my $st = $c->dbh->prepare($query);
	$st->execute(@args);

	if($st->err) {
		$c->res->code(400);
		$c->render(text => 'could not delete:', $st->errmsg);
		return;
	}

	if($st->rows < 1) {
		$c->res->code(404);
		$c->render(text => 'not found');
		return;
	}
	my $row = $st->fetchrow_arrayref;
	$c->render(openapi => $row->[0]);
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

sub add_with_json {
	my ($c, $json, $tablename, $fields) = @_;

	my @args;
	my @inserts;

	if(exists($json->{id})) {
		delete $json->{id};
	}

	while(my @tuple = each %$json) {
		next if($tuple[0] eq "id");
		next unless(exists($fields->{$tuple[0]}));
		push @inserts, $tuple[0];
		push @args, $tuple[1];
	}

	my $inserts = join(', ', @inserts);
	my $fieldlist;
	if(scalar(@inserts) > 0) {
		$fieldlist = "?, " x (scalar(@inserts) - 1) . "?";
	} else {
		$fieldlist = "";
	}
	my $dbh = $c->dbh;
	my $res;
	eval {
		$res = db_query($dbh, "INSERT INTO $tablename($inserts) VALUES($fieldlist) RETURNING row_to_json($tablename.*)", @args);
	};

	if(scalar(@$res) < 1) {
		$c->res->code(400);
		$c->render(text => "failed to add data: " . $dbh->errstr);
		return;
	}

	$c->render(openapi => $res->[0]);
}
