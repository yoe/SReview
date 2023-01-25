package SReview::Files::Collection::HTTP::nginx::JSON;

use Moose;
use Mojo::UserAgent;
use DateTime::Format::Strptime;

extends 'SReview::Files::Collection::HTTP';

sub _probe_children {
	my $self = shift;
	my $ua = Mojo::UserAgent->new;
	my $baseurl = $self->baseurl;
	my $parser = DateTime::Format::Strptime->new(
		pattern => '%a, %d %b %Y %H:%M:%S %Z',
		locale => 'C',
		on_error => 'croak'
	);
	if(substr($baseurl, -1) ne "/") {
		$baseurl .= "/";
	}
	my $return = [];
	my $res = $ua->get($baseurl)->result;
	if($res->is_success) {
		foreach my $obj(@{$res->json}) {
			my $child;
			my $mtime = $parser->parse_datetime($obj->{mtime});
			if($obj->{type} eq "directory") {
				$child = SReview::Files::Collection::HTTP::nginx::JSON->new(baseurl => join("/", $self->baseurl, $obj->{name}), mtime => $mtime);
			} else {
				$child = SReview::Files::Access::HTTP->new(baseurl => $self->baseurl, relname => $obj->{name}, mtime => $mtime);
			}
			push @$return, $child;
		}
	}

	return $return;
}
