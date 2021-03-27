package SReview::Schedule::Filtered::FilteredTalk;

use Moose;
use SReview::Schedule::WithParent;

extends 'SReview::Schedule::WithParent::ParentedTalk';

has 'require_match' => (
	is => 'ro',
	isa => 'HashRef[Str]',
	default => sub { {} },
);

has 'forbid_match' => (
	is => 'ro',
	isa => 'HashRef[Str]',
	default => sub { {} },
);

sub _load_filtered {
	my $self = shift;

	foreach my $filter(keys %{$self->require_match}) {
		if($self->meta->find_attribute_by_name($filter)->get_value($self) !~ $self->require_match->{$filter}) {
			return 1;
		}
	}
	foreach my $filter(keys %{$self->forbid_match}) {
		if($self->meta->find_attribute_by_name($filter)->get_value($self) =~ $self->forbid_match->{$filter}) {
			return 1;
		}
	}
	return 0;
}

no Moose;

package SReview::Schedule::Filtered::FilteredEvent;

use Moose;

extends 'SReview::Schedule::WithParent::ParentedEvent';

sub _load_talk_type {
	return 'SReview::Schedule::Filtered::FilteredTalk';
}

package SReview::Schedule::Filtered;

use Moose;
use SReview::Schedule::WithParent;

extends 'SReview::Schedule::WithParent';

sub _load_event_type {
	return 'SReview::Schedule::Filtered::FilteredEvent';
}

no Moose;

1;
