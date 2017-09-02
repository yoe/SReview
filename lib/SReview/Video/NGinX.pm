package SReview::Video::NGinX;

use Moose;
use WWW::Curl::Easy;

extends 'SReview::Video';

has 'workfile' => (
	required => 1,
	is => 'rw',
	isa => 'Str',
);

has 'origurl' => (
	is => 'rw',
);

sub readopts {
	my $self = shift;
	my $output = shift;
	my $curl = WWW::Curl::Easy->new;
	my @opts;

	open OUTPUT, ">" . $self->workfile;
	$curl->setop(CURLOPT_WRITEDATA, \*OUTPUT);

	my $url = $self->url;
	my $start = 0;
	if ($self->has_fragment_start) {
		push @opts, 'start=' . $self->fragment_start;
		$start = $self->fragment_start;
	}
	if ($self->has_duration) {
		push @opts, 'end=' . ($start + $self->duration);
	}
	$url .= '?' . join('&', @opts);
	$curl->setopt(CURLOPT_URL, $url);
	my $res = $curl->perform;
	if($res != 0) {
		die "Received HTTP error code $res: " . $curl->strderror($res) . " " . $curl->errbuf;
	}
	close OUTPUT;
	$self->origurl($self->url);
	$self->url = $workfile;
	return $self->SReview::Video::readopts($self, $output);
}

no Moose;

1;
