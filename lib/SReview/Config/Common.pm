package SReview::Config::Common;

use SReview::Config;

use strict;
use warnings;

sub get_default_cfile {
	my $dir = $ENV{SREVIEW_WDIR};
	my $write = shift;

	$dir = "." unless defined($dir);
	my $cfile = join('/', $dir, 'config.pm');
	if(!-f $cfile && !exists($ENV{SREVIEW_WDIR})) {
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
	$config->define('output_subdirs', 'An array of fields to be used to create subdirectories under the output directory.', ['event', 'room', 'date']);
	$config->define('script_output', 'The directory to which the output of scripts should be redirected', '/srv/sreview/script-output');
	$config->define('preroll_template', 'An SVG template to be used as opening credits. Should have the same nominal dimensions (in pixels) as the video assets.', undef);
	$config->define('postroll_template', 'An SVG template to be used as closing credits. Should have the same nominal dimensions (in pixels) as the video assets.', undef);
	$config->define('postroll', 'A PNG file to be used as closing credits. Will only be used if no postroll_template was defined. Should have the same dimensions as the video assets.', undef);
	$config->define('apology_template', 'An SVG template to be used as apology template (shown just after the opening credits when technical issues occurred. Should have the same nominal dimensions (in pixels) as the video assets.', undef);
	$config->define('output_profiles', 'An array of profiles, one for each encoding, to be used for output encodings', ['webm']);

	# Values for detection script
	$config->define('inputglob', 'A filename pattern (glob) that tells SReview where to find new files', '/srv/sreview/incoming/*/*/*');
	$config->define('parse_re', 'A regular expression to parse a filename into year, month, day, hour, minute, second, and room', '.*\/(?<room>[^\/]+)\/(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})\/(?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})');
	$config->define('url_re', 'If set, used with parse_re in an s///g command to produce an input URL', undef);

	# Values for dispatch script
	$config->define('state_actions', 'A hash that tells SReview what to do with a talk when it is in a given state. Mojo::Template is used to transform these.', {
		cutting => 'qsub -V -l input -l output -b y -pe smp 2 -N cut_<%== $talkid %> -o <%== $output_dir %> -e <%== $output_dir %> sreview-cut <%== $talkid %>',
		generating_previews => 'qsub -V -l output -b y -N previews_<%== $talkid %> -o <%== $output_dir %> -e <%== $output_dir %> sreview-previews <%== $talkid %>',
		transcoding => 'qsub -V -l output -b y -N transcode_<%== $talkid %> -o <%== $output_dir %> -e <%== $output_dir %> sreview-transcode <%== $talkid %>',
		uploading => 'qsub -V -l output -b y -N upload_<%== $talkid %> -o <%== $output_dir %> -e <%== $output_dir %> sreview-skip <%== $talkid %>',
		notification => 'qsub -V -l output -b y -N notify_<%== $talkid %> -o <%== $output_dir %> -e <%== $output_dir %> sreview-skip <%== $talkid %>',
	});
	$config->define('query_limit', 'A maximum number of jobs that should be submitted in a single loop in sreview-dispatch. 0 means no limit.', 0);

	# Values for notification script
	$config->define('notify_actions', 'An array of things to do when notifying. Can contain one or more of: email, command.', []);
	$config->define('email_template', 'A filename of a Mojo::Template template to process, returning the email body. Required if notify_actions includes email.', '');
	$config->define('email_from', 'The data for the From: header in the email. Required if notify_actions includes email.', '');
	$config->define('urlbase', 'The URL on which SReview runs. Note that this is used by sreview-notify to generate URLs, not by sreview-web.', '');
	$config->define('notify_commands', 'An array of commands to run. Each component is passed through Mojo::Template before processing. To avoid quoting issues, it is a two-dimensional array, so that no shell will be called to run this.', [['echo', '<%== $title %>', 'is', 'available', 'at', '<%== $url %>']]);

	# Values for upload script
	$config->define('upload_actions', 'An array of commands to run on each file to be uploaded. Each component is passed through Mojo::Template before processing. To avoid quoting issues, it is a two-dimensional array, so that no shell will be called to run this.', [['echo', '<%== $file %>', 'ready for upload']]);

	return $config;
}

1;
