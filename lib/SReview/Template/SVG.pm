package SReview::Template::SVG;

use SReview::Template;
use Mojo::UserAgent;
use Mojo::Util qw/xml_escape/;
use File::Temp qw/tempdir/;

use Exporter 'import';
our @EXPORT_OK = qw/process_template/;

sub process_template($$$$) {
	my $input = shift;
	my $output = shift;
	my $talk = shift;
	my $config = shift;

	my $tempdir = tempdir('svgXXXXXX', DIR => $config->get("workdir"), CLEANUP => 1);
	my $outputsvg = "$tempdir/tmp.svg";
	my $speakers = xml_escape($talk->speakers);
	my $room = xml_escape($talk->room);
	my $title = xml_escape($talk->title);
	my $subtitle = xml_escape($talk->subtitle);
	my $startdate = xml_escape($talk->date);
	my $apology = xml_escape($talk->apology);
	my $regexvars = {
		'@SPEAKERS@' => $speakers,
                '@ROOM@' => $room,
                '@TITLE@' => $title,
                '@SUBTITLE@' => $subtitle,
                '@DATE@' => $startdate,
                '@APOLOGY@' => $apology,
        };
	my $content = "";
	my $template_engine = SReview::Template->new(talk => $talk, regexvars => $regexvars);

	if($input =~ /^http(s)?:\/\//) {
		my $ua = Mojo::UserAgent->new->connect_timeout(60)->max_redirects(10);
		my $res = $ua->get($input)->result;
		if(!$res->is_success) {
			die "could not download: " . $res->message;
		}
		$content = $res->body;
	} else {
		open INPUT, '<:encoding(UTF-8)', $input;
		while(<INPUT>) {
			$content .= $_;
		}
		close INPUT;
	}
	open my $fh, ">:encoding(UTF-8)", $outputsvg;
	print "creating $output from $input\n";
	print $fh $template_engine->string($content);
	my $inkscape_options = "--batch-process -o $output";
	if($config->get("command_tune")->{inkscape} eq "0.9") {
		$inkscape_options = "--export-png=$output";
	}
	system("inkscape $inkscape_options $outputsvg");
}

1;
