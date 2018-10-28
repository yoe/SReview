package SReview::Talk::State;

use overload '<=>' => statecmp, 'cmp' => statecmp, '""' => output;

sub new {
	my $class = shift;
	my $val = shift;
	return bless \$val, $class;
}

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
	broken => 9,
	needs_work => 10,
	lost => 11,
	ignored => 12,
);

sub statecmp {
	my $self = shift;
	my $other = shift;
	my $swapped = shift;

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
