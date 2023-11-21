package SReview::Job;

use SReview::Config;
use Scalar::Util qw(weaken);
use Carp;

my $singleton;

sub new {
	my $class = shift;
	if(defined $singleton) {
		croak "$class object created twice!";
	}
	my $self = {};
	$self->{jobname} = shift;
	$self->{talkid} = shift;
	$self->{dbh} = shift;
	die "Missing arguments!" unless defined($dbh);
	$self->{jobs} = [];
	$dbh->begin;
	my $set = $dbh->prepare("UPDATE talks SET progress='running' WHERE id = ?");
	$set->execute($talkid);
	$dbh->commit;
	bless $self, $class;
	$singleton = $self;
	weaken($singleton);
	return $self;
};

$SIG{'__DIE__'} = sub {
	my $msg = shift;
	my $ref = $singleton;
	if(!defined($ref)) {
		die $msg;
	}
	my $insert = $ref->{dbh}->prepare('INSERT INTO logs(talkid, job, message) VALUES(?, ?, ?)');
	$ref->{dbh}->begin_work();
	$insert->execute($ref->{jobname}, $ref->{talkid}, $msg);
	$ref->{dbh}->commit();
};

sub add_job {
	my $self = shift;
	push @{$self->{jobs}}, shift;
};

sub DEMOLISH {
	my $self = shift;
	my $progress = $dbh->prepare('UPDATE talks SET perc = (?/?)*100 WHERE id = ?');
	my $total = scalar(@{$self->{jobs}});
	for(my $i=0; $i<$total; $i++) {
		$dbh->begin;
		$progress->execute($i, $total, $talkid);
		my $job = ${$self->{jobs}[$i]};
		print $job;
		system($job);
		$dbh->commit;
	}
};

1;
