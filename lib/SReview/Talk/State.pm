package SReview::Talk::State;

use overload '<=>' => 'statecmp', 'cmp' => 'statecmp', '""' => 'output';

use Carp;

my %states = (
	waiting_for_files => 0,
	cutting => 1,
	generating_previews => 2,
	notification => 3,
	preview => 4,
	transcoding => 5,
	uploading => 6,
	announcing => 7,
	done => 8,
	injecting => 9,
	broken => 10,
	needs_work => 11,
	lost => 12,
	ignored => 13,
);

sub new {
	my $class = shift;
	my $val = shift;
        croak "Unknown talk state value: $val" unless exists($states{$val});
	return bless \$val, $class;
}

sub statecmp {
	my $self = shift;
	my $other = shift;
	my $swapped = shift;

        croak "Unknown talk state value: $other" unless exists($states{$other});

	if($swapped) {
		return $states{$other} <=> $states{$$self};
	} else {
		return $states{$$self} <=> $states{$other};
	}
}

sub output {
	my $self = shift;
	return $$self;
}
