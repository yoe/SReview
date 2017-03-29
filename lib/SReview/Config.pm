use strict;
use warnings;

package SReview::Config;

use Data::Dumper;

sub new {
	my $self = {defs => {}};
	my $class = shift;

	bless $self, $class;

	my $cfile = shift;

	if (! -f $cfile) {
		warn("Warning: could not find configuration file $cfile. Using defaults.\n");
	} else {
		package SReview::Config::_private;
		my $rc = do($cfile);
		if($@) {
			die "could not compile config file $cfile: $@";
		} elsif(!defined($rc)) {
			die "could not read config file $cfile: $!";
		} elsif(!$rc) {
			die "could not process config file $cfile";
		}
	}
	return $self;
};

sub define {
	my $self = shift;
	my $name = shift;
	my $doc = shift;
	my $default = shift;
	$self->{defs}{$name}{doc} = $doc;
	$self->{defs}{$name}{default} = $default;
};

sub get {
	my $self = shift;
	my $name = shift;
	if(!exists($self->{defs}{$name})) {
		die "e: definition for config file item $name does not exist!";
	}
	if(exists($SReview::Config::_private::{$name})) {
		return ${$SReview::Config::_private::{$name}};
	} else {
		return $self->{defs}{$name}{default};
	}
};

sub dump {
	my $self = shift;
	foreach my $conf(keys %{$self->{defs}}) {
		print "# " . $self->{defs}{$conf}{doc} . "\n";
		print "#" . Data::Dumper->Dump([$self->{defs}{$conf}{default}], [$conf]) . "\n";
	}
	print "# Do not remove this, perl needs it\n1;\n";
};

1;
