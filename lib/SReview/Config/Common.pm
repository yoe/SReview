package SReview::Config::Common;

sub setup($) {
	my $config = shift;

	$config->define('dbistring', 'The DBI connection string used to connect to the database', 'dbi:Pg:dbname=sreview');
	$config->define('raw_exten', 'The file extension of the raw recorded (untranscoded) file format', 'ts');
	$config->define('workdir_mangle', 'A subroutine that returns an intermediate directory name based on the name of the room (first parameter) and the scheduled day of the talk (second parameter). Default returns just the room name.', sub { return $1; });
	$config->define('workdir', 'The directory below which work-in-progress files are stored', '/srv/sreview');
	$config->define('ffmpeg_a_codec', 'The audio codec (and its configuration) as used by ffmpeg for the raw recordings; needed for reintegrating the normalized audio', '-c:a libfdk_aac -b:a 128k');
	$config->define('pubdir', 'The directory for public assets to be used by the webinterface', '/srv/sreview/web/public');
}

1;
