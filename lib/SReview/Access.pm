package SReview::Access;

use Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw(admin_for);

sub admin_for($$) {
	my $c = shift;
	my $talk = shift;

	if($c->session->{admin}) {
		return 1;
	}
	if($c->session->{id}) {
		my $st = $c->dbh->prepare("SELECT room FROM users WHERE id = ?");
		$st->execute($c->session->{id});
		my $row = $st->fetchrow_hashref;
		if($talk->roomid = $row->{room}) {
			return 1;
		}
	}
}
