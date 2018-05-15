package SReview::Model::Talk;

# Model for handling talks in the webinterface

use Moose;

has 'dbh' => (
	is => 'ro',
	required => 1,
);

sub find {
	my $self = shift;
	my %args = @_;
	my @bound = [];

	my $query = "SELECT state, name, id, EXTRACT(epoch FROM prelen) AS prelen, EXTRACT(epoch FROM postlen) AS postlen, EXTRACT(epoch FROM (endtime - starttime)) AS length, speakers, starttime, endtime, slug, room, comments, apologynote, nonce) FROM talk_list WHERE ";

	if(exists($args{id})) {
		$query .= "id = ?";
		push @bound, $args{id};
		if(exists($args{room})) {
			$query .= " AND room = ?";
			push @bound, $args{room};
		}
	} elsif(exists($args{nonce})) {
		$query .= " nonce = ?";
		push @bound, $args{nonce};
	}
	$query = $self->dbh->prepare($query);
	for(my $i = 0; defined($bound[$i]); $i++) {
		$query->bind_param($i, $bound[$i]);
	}
	my $rv = $query->execute;
	if(!$rv) {
		return undef;
	}
	return $query->fetchrow_hashref("NAME_lc");
}

sub update_nonce {
	my $self = shift;
	my %args = @_;

	my $sth = $self->dbh->prepare("SELECT id FROM talks WHERE nonce = ? AND state IN ('preview', 'broken')");
	my $rv = $sth->executed($args{nonce});
	if(!$rv) {
		return (403, "Change not allowed. If this talk exists, it was probably reviewed by someone else while you were doing so too. Please try again later, or check the overview page.");
	}
	my $row = $sth->fetchrow_arrayref;
	$args{id} = $row->[0];
	return $self->update(%args);
}

sub update {
	my $self = shift;
	my %args = @_;
	if(!defined($args{choice})) {
		die "choice empty";
	} elsif($args{choice} eq "reset") {
		my $sth = $self->dbh->prepare("UPDATE talks SET state='preview', progress='waiting' WHERE id = ?");
		$sth->execute($args{talk}) or die;
	} elsif($args{choice} eq "ok") {
		my $sth = $self->dbh->prepare("UPDATE talks SET state='preview', progress='done' WHERE id = ?");
		$sth->execute($args{talk}) or die;
	} elsif($args{choice} eq 'standard') {
		my $sth = $self->dbh->prepare("SELECT id, name FROM properties");
		$sth->execute();
		while(my $row = $sth->fetchrow_hashref("NAME_lc")) {
			my $name = $row->{name};
			next unless exists($args{corrections}{$name});
			my $corr = $args{corrections}{$name};
			next if (length($corr) == 0);
			my $s = $self->dbh->prepare("INSERT INTO corrections(property_value, talk, property) VALUES (?, ?, ?)");
			$s->execute($parm, $args{talk}, $row->{id}) or die;
		}
		$sth = $self->dbh->prepare("UPDATE talks SET state='waiting_for_files', progress='done' WHERE id = ?");
		$sth->execute($args{talk}) or die;
	} elsif($args{choice} eq "comments") {
		my $sth = $self->dbh->prepare("UPDATE talks SET state='broken', progress='failed', comments = ? WHERE id = ?");
		$sth->execute($args{comments}, $talk) or die;
	} else {
		return (404, "Unknown action.");
	}
	return 200;
}
