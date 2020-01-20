package SReview::API::Helpers;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw/db_query/;

use SReview::Config::Common;
use Mojo::JSON qw/decode_json/;

sub db_query {
	my ($dbh, $query, @args) = @_;

	my $st = $dbh->prepare($query);
	$st->execute(@args);
	my @results;
	foreach my $row($st->fetchrow_arrayref) {
		if(scalar(@{$row}) == 1) {
			push @results, $row->[0];
		} else {
			push @results, "[" . join(",", @$row) . "]";
		}
	}
	return decode_json("[" . join(",", @results) . "]");
}
