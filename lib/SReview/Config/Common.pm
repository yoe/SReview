package SReview::Config::Common;

sub setup($) {
	my $config = shift;

	$config->define('dbistring', 'The DBI connection string used to connect to the database', 'dbi:Pg:dbname=sreview');
}

1;
