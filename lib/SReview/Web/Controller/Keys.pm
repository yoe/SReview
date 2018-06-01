package SReview::Web::Controller::Keys;

use Net::SSH::AuthorizedKeysFile;
use Net::SSH::AuthorizedKey;
use File::Basename qw(dirname);
use SReview::Config::C

use Mojo::Base 'Mojolicious::Controller';

has 'event';
has 'dbh';

sub eventpath {
	my $self = shift;
	my $st = $self->dbh->prepare('SELECT pathname FROM event WHERE name = ?');
	$st->execute($self->event);
	if($st->rows == 0) {
		return undef;
	}
	my $row = $st->fetchrow_hashref;
	return $row->{pathname};
}

sub add {
	my $self = shift;
	my $key = shift;

	my $keysfile = Net::SSH::AuthorizedKeysFile->new();
	if (! -f $keysfile->path_locate()) {
		open KEYS, ">>", $keysfile->path_locate();
		close KEYS;
	}
	$keysfile->read();
	$key = Net::SSH::AuthorizedKey->parse($key);
	my $add = 1;
	foreach my $rkey($keysfile->keys()) {
		if($key->fingerprint() eq $rkey->fingerprint()) {
			$key = $rkey;
			$add = 0;
			last;
		}
	}
	my $rrsync = join('/', $ENV{HOME}, "bin", "rrsync");
	if(! -f $rrsync) {
		mkdir(join('/', $ENV{HOME}, "bin"));
		system("gunzip -c /usr/share/doc/rsync/scripts/rrsync.gz > $rrsync");
		chmod 0755, $rrsync;
	}
	$key->options->{command} = "$rrsync -wo " . $self->eventpath;
	if($add) {
		$keys
	}
	$keys->save();
}

sub list {
	my $self = shift;

	my $keysfile = Net::SSH::AuthorizedKeysFile->new();
	if(! -f $keysfile->path_locate()) {
		return ();
	}
	$keysfile->read();
}
