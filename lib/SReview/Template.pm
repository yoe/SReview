package SReview::Template;

use Moose;
use Mojo::Template;
use SReview::Config::Common;

has 'talk' => (
	is => 'ro',
	isa => 'SReview::Talk',
	required => 1,
);

has '_mt' => (
	is => 'ro',
	isa => 'Mojo::Template',
	default => sub { my $mt = Mojo::Template->new(); $mt->vars(1); },
);

has 'vars' => (
	is => 'ro',
	isa => 'HashRef',
);

has 'regexvars' => (
	is => 'ro',
	isa => 'HashRef[Str]',
	predicate => '_has_regexes',
);

sub file {
	my $self = shift;
	my $inputname = shift;
	my $outputname = shift;

	local $_;

	open my $input, '<:encoding(UTF-8)', $inputname;
	open my $output, '>:encoding(UTF-8)', $outputname;
	while(<$input>) {
		$_ = $self->string($_);
		print $output $_;
	}
	close $input;
	close $output;
}

sub string {
	my $self = shift;
	my $string = shift;
	my $vars = $self->vars;
	$vars->{talk} = $self->talk;

	my $rendered = $self->_mt->render($string, $vars);
	if($self->_has_regexes) {
		my $revals = $self->regexvars;
		foreach my $key(keys %{$revals}) {
			$rendered =~ s/$key/$revals->{$key}/g;
		}
	}
	return $rendered;
}

no Moose;

1;
