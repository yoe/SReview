package SReview::CodecMap;

use Exporter 'import';

our @EXPORT_OK=qw/detect_to_write/;

my %writemap = (
	'vorbis' => 'libvorbis',
);

sub enable_nonfree {
	$writemap{aac} = 'libfdk_aac';
}

sub detect_to_write($) {
	my $detected = shift;
	if(exists($writemap{$detected})) {
		return $writemap{$detected};
	} else {
		return $detected;
	}
}
