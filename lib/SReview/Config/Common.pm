package SReview::Config::Common;

use SReview::Config;

sub get_default_cfile() {
	my $dir = $ENV{SREVIEW_WDIR};

	$dir = "." unless defined($dir);
	my $cfile = join('/', $dir, 'config.pm');
	if(!-f $cfile) {
		$cfile = join('/', '', 'etc', 'sreview', 'config.pm');
	}
	return $cfile;
}

sub setup {
	my $cfile = shift;
	if(!defined($cfile)) {
		$cfile = get_default_cfile();
	}
	my $config = SReview::Config->new($cfile);

	# common values
	$config->define('dbistring', 'The DBI connection string used to connect to the database', 'dbi:Pg:dbname=sreview');

	# Values for sreview-web
	$config->define('event', 'The default event to handle in the webinterface. Ignored by all other parts of sreview.');
	$config->define('secret', 'A random secret key, used to encrypt the cookies.', '_INSECURE_DEFAULT_REPLACE_ME_');
	$config->define("vid_prefix", "The URL prefix to be used for video data files", "");
	$config->define("anonreviews", "Set to truthy if anonymous reviews should be allowed, or to falsy if not", 0);

	# Values for encoder scripts
	$config->define('pubdir', 'The directory on the file system where files served by the webinterface should be stored', '/srv/sreview/web/public');
	$config->define('workdir', 'A directory where encoder jobs can create a subdirectory for temporary files', '/tmp');
	$config->define('outputdir', 'The base directory under which SReview should place the final released files', '/srv/sreview/output');
	$config->define('output_subdirs', 'An array of fields to be used to create subdirectories under the output directory.', ['event', 'room', 'startdate']);
	$config->define('script_output', 'The directory to which the output of scripts should be redirected', '/srv/sreview/script-output');
	$config->define('preroll_template', 'An SVG template to be used as opening credits. Should have the same nominal dimensions (in pixels) as the video assets.', undef);
	$config->define('postroll_template', 'An SVG template to be used as closing credits. Should have the same nominal dimensions (in pixels) as the video assets.', undef);
	$config->define('postroll', 'A PNG file to be used as closing credits. Will only be used if no postroll_template was defined. Should have the same dimensions as the video assets.', undef);
	$config->define('apology_template', 'An SVG template to be used as apology template (shown just after the opening credits when technical issues occurred. Should have the same nominal dimensions (in pixels) as the video assets.', undef);
	$config->define('output_profiles', 'An array of profiles, one for each encoding, to be used for output encodings', ['webm']);

	# Values for detection script
	$config->define('inputglob', 'A filename pattern (glob) that tells SReview where to find new files', '/srv/sreview/incoming/*/*/*');
	$config->define('parse_re', 'A regular expression to parse a filename into year, month, day, hour, minute, second, and room', '.*\/(?<room>[^\/]+)\/(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})\/(?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})');
	$config->define('url_re', 'If set, used with parse_re in an s///g command to produce a URL', undef);

	# Values for dispatch script
	$config->define('state_actions', 'An anonymous hash that tells SReview what to do with a talk when it is in a given state. Can use embedded perl.', {
		cutting => 'qsub -V -l input -l output -b y -pe smp 2 -N cut_<%== $talkid %> -o <%== $output_dir %> -e <%== $output_dir %> sreview-cut <%== $talkid %>',
		generating_previews => 'qsub -V -l output -b y -N previews_<%== $talkid %> -o <%== $output_dir %> -e <%== $output_dir %> sreview-previews <%== $talkid %>',
		transcoding => 'qsub -V -l output -b y -N transcode_<%== $talkid %> -o <%== $output_dir %> -e <%== $output_dir %> sreview-transcode <%== $talkid %>',
		uploading => 'qsub -V -l output -b y -N upload_<%== $talkid %> -o <%== $output_dir %> -e <%== $output_dir %> sreview-skip <%== $talkid %>',
		notification => 'qsub -V -l output -b y -N notify_<%== $talkid %> -o <%== $output_dir %> -e <%== $output_dir %> sreview-skip <%== $talkid %>',
	});
	$config->define('query_limit', 'A maximum number of jobs that should be submitted in a single loop in sreview-dispatch. 0 means no limit.', 0);

	return $config;
}

1;
