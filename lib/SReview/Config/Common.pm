package SReview::Config::Common;

sub setup($) {
	my $config = shift;

	$config->define('dbistring', 'The DBI connection string used to connect to the database', 'dbi:Pg:dbname=sreview');
	$config->define('event', 'The default event to handle in the webinterface. Ignored by all other parts of sreview.');
	$config->define('secret', 'A random secret key, used to encrypt the cookies.', '_INSECURE_DEFAULT_REPLACE_ME_');
	$config->define("vid_prefix", "The URL prefix to be used for video data files", "");
	$config->define("anonreviews", "Set to truthy if anonymous reviews should be allowed, or to falsy if not", 0);
}

1;
