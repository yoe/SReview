package SReview::Config::Common;

use SReview::Config;

sub get_default_cfile() {
	my $dir = $ENV{SREVIEW_WDIR};

	dir = "." unless defined($dir);
	my $cfile = join('/', $dir, 'config.pm');
	if(!-f $cfile) {
		$cfile = join('/', '', 'etc', 'sreview', 'config.pm');
	}
	return $cfile;
}

sub setup() {
	my $cfile = shift;
	if(!defined($cfile)) {
		$cfile = get_default_cfile();
	}
	my $config = SReview::Config->new($cfile);
	$config->define('dbistring', 'The DBI connection string used to connect to the database', 'dbi:Pg:dbname=sreview');
	$config->define('event', 'The default event to handle in the webinterface. Ignored by all other parts of sreview.');
	$config->define('secret', 'A random secret key, used to encrypt the cookies.', '_INSECURE_DEFAULT_REPLACE_ME_');
	$config->define("vid_prefix", "The URL prefix to be used for video data files", "");
	$config->define("anonreviews", "Set to truthy if anonymous reviews should be allowed, or to falsy if not", 0);

	return $config;
}

1;
