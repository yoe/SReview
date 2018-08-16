package SReview::Config::Common;

use SReview::Config;

use strict;
use warnings;
use feature 'state';

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
	state $config;

	return $config if(defined $config);

	$config = SReview::Config->new($cfile);
	# common values
	$config->define('dbistring', 'The DBI connection string used to connect to the database', 'dbi:Pg:dbname=sreview');

	# Values for sreview-web
	$config->define('event', 'The default event to handle in the webinterface. Ignored by all other parts of SReview.');
	$config->define('secret', 'A random secret key, used to encrypt the cookies.', '_INSECURE_DEFAULT_REPLACE_ME_');
	$config->define("vid_prefix", "The URL prefix to be used for video data files", "");
	$config->define("anonreviews", "Set to truthy if anonymous reviews should be allowed, or to falsy if not", 0);
	$config->define("preview_exten", "The extension used by previews (webm or mp4). Should be autodetected in the future, but...", "webm");
	$config->define("eventurl_format", "A Mojo::Template that generates an event URL. Used by the /released metadata URL", undef);

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
	$config->define('input_profile', 'The profile that is used for input videos.', undef);

	# Values for detection script
	$config->define('inputglob', 'A filename pattern (glob) that tells SReview where to find new files', '/srv/sreview/incoming/*/*/*');
	$config->define('parse_re', 'A regular expression to parse a filename into year, month, day, hour, minute, second, room, and stream', '.*\/(?<stream>[^\/]+)\/(?<room>[^\/]+)\/(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})\/(?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})');
	$config->define('url_re', 'If set, used with parse_re in an s///g command to produce an input URL', undef);

	# Values for dispatch script
	$config->define('state_actions', 'A hash that tells SReview what to do with a talk when it is in a given state. Mojo::Template is used to transform these.', {
		cutting => 'sreview-cut <%== $talkid %> > <%== $output_dir %>/cut.<%== $talkid %>.out 2> <%== $output_dir %>/cut.<%== $talkid %>.err',
		generating_previews => 'sreview-previews <%== $talkid %> > <%== $output_dir %>/preview.<%== $talkid %>.out 2> <%== $output_dir %>/preview.<%== $talkid %>.err',
		transcoding => 'sreview-transcode <%== $talkid %> > <%== $output_dir %>/trans.<%== $talkid %>.out 2> <%== $output_dir%>/trans.<%== $talkid %>.err',
		uploading => 'sreview-skip <%== $talkid %>',
		notification => 'sreview-skip <%== $talkid %>',
		announcing => 'sreview-skip <%== $talkid %>',
	});
	$config->define('query_limit', 'A maximum number of jobs that should be submitted in a single loop in sreview-dispatch. 0 means no limit.', 1);

	# Values for notification script
	$config->define('notify_actions', 'An array of things to do when notifying the readyness of a preview video. Can contain one or more of: email, command.', []);
	$config->define('announce_actions', 'An array of things to do when announcing the completion of a transcode. Can contain one or more of: email, command.', []);
	$config->define('email_template', 'A filename of a Mojo::Template template to process, returning the email body used in notifications or announcements. Can be overridden by announce_email_template or notify_email_template.', undef);
	$config->define('notify_email_template', 'A filename of a Mojo::Template template to process, returning the email body used in notifications. Required, but defaults to the value of email_template', undef);
	$config->define('announce_email_template', 'A filename of a Mojo::Template template to process, returning the email body used in announcements. Required, but defaults to the value of email_template', undef);
	$config->define('email_from', 'The data for the From: header in any email. Required if notify_actions or announce_actions includes email.', undef);
	$config->define('notify_email_subject', 'The data for the Subject: header in the email. Required if notify_actions includes email.', undef);
	$config->define('announce_email_subject', 'The data for the Subject: header in the email. Required if announc_actions includes email.', undef);
	$config->define('urlbase', 'The URL on which SReview runs. Note that this is used by sreview-notify to generate URLs, not by sreview-web.', '');
	$config->define('notify_commands', 'An array of commands to run to perform notifications. Each component is passed through Mojo::Template before processing. To avoid quoting issues, it is a two-dimensional array, so that no shell will be called to run this.', [['echo', '<%== $title %>', 'is', 'available', 'at', '<%== $url %>']]);
	$config->define('announce_commands', 'An array of commands to run to perform announcements. Each component is passed through Mojo::Template before processing. To avoid quoting issues, it is a two-dimensional array, so that no shell will be called to run this.', [['echo', '<%== $title %>', 'is', 'available', 'at', '<%== $url %>']]);

	# Values for upload script
	$config->define('upload_actions', 'An array of commands to run on each file to be uploaded. Each component is passed through Mojo::Template before processing. To avoid quoting issues, it is a two-dimensional array, so that no shell will be called to run this.', [['echo', '<%== $file %>', 'ready for upload']]);
	$config->define('cleanup', 'Whether to remove files after they have been published. Possible values: "all" (removes all files), "previews" (removes the output of sreview-cut, but not that of sreview-transcode), and "output" (removes the output of sreview-transcode, but not the output of sreview-cut). Other values will not remove files', 'none');

	# for sreview-keys
	$config->define('authkeyfile', 'The authorized_keys file that sreview-keys should manage. If set to undef, the default authorized_keys file will be used.');

	# for extending profiles
	$config->define('extra_profiles', 'Any extra custom profiles you want to use. This hash should have two keys: the "parent" should be a name of a profile to subclass from, and the "settings" should contain a hash reference with attributes for the new profile to set', {});

	return $config;
}

1;
