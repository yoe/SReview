package SReview::Files::Access::SFTP;

use Moose;
use Carp;
use Fcntl;
use File::Basename;
use File::Temp qw/tempfile/;

use SReview::Files::Collection::Net;

extends 'SReview::Files::Access::Net';

has 'basepath' => (
        is => 'ro',
        isa => 'Str',
        lazy => 1,
        builder => '_probe_basepath',
);

sub _probe_basepath {
        my $self = shift;

        my $url = Mojo::URL->new($self->baseurl);
        my $path = $url->path;
        return "$path";
}

has 'sftpobject' => (
        is => 'ro',
        required => 1,
        isa => 'Net::SSH2::SFTP',
);

has 'onhost_pathname' => (
        is => 'ro',
        isa => 'Str',
        lazy => 1,
        builder => '_probe_onhost_pathname',
);

sub _probe_onhost_pathname {
        my $self = shift;

        return join('/', $self->basepath, $self->relname);
}

sub _get_file {
        my $self = shift;
        my @parts = split('\.', $self->relname);
        my $ext = pop(@parts);
        my $dir = $self->workdir;

        if($self->has_data) {
                if($self->download_verbose) {
                        print "downloading " . $self->relname . " to " . $self->filename . "\n";
                }
                my ($fh, $file) = tempfile("sftp-XXXXXX", dir => $dir, SUFFIX => ".$ext");
                my $size = $self->sftpobject->stat($self->onhost_pathname)->{size};
                my $source = $self->sftpobject->open($self->onhost_pathname, O_RDONLY);
                while($size > 0) {
                        my $buf;
                        my $read = $source->read($buf, 32*1024);
                        syswrite($fh, $buf, $read);
                        $size -= $read;
                }
                return $file;
        } else {
                my $file = join("/", $self->workdir, basename($self->relname));
                return $file;
        }
}

sub _probe_mtime {
        my $self = shift;
        my $mtime = $self->sftpobject->stat($self->onhost_pathname)->{mtime};
        return $mtime;
}

sub store_file {
        my $self = shift;
        return if(!$self->has_download);

        # auto flush
        local $| = 1;

        # Copy the file to the server. Algorithm taken straight from the
        # Net::SSH2::File documentation, so see there to understand what and
        # why.
        if($self->download_verbose) {
                print "uploading " . $self->filename . " to " . $self->onhost_pathname . " via sftp\n";
        }
        open my $fh, "<", $self->filename;
        my $dir = dirname($self->onhost_pathname);
        my @dirs;
        while(!$self->sftpobject->stat($dir)) {
                unshift @dirs, $dir;
                $dir = dirname($dir);
        }
        foreach $dir(@dirs) {
                $self->sftpobject->mkdir($dir);
        }
        my $sf = $self->sftpobject->open($self->onhost_pathname, O_WRONLY | O_CREAT | O_TRUNC);

        my $buf;
        while(sysread($fh, $buf, 32*1024)) {
                while(length($buf)) {
                        my $rc = $sf->write($buf);
                        if(!defined($rc)) {
                                $self->sftpobject->die_with_error('write error');
                        }
                        substr($buf, 0, $rc) = '';
                }
                print ".";
        }
        return $self->SUPER::store_file;
}

sub delete {
        my $self = shift;
        $self->sftpobject->unlink($self->onhost_pathname);
}

no Moose;

package SReview::Files::Collection::SFTP;

use Moose;
use Net::SSH2;
use Mojo::URL;
use Carp;
use Fcntl ':mode';

extends 'SReview::Files::Collection::Net';

has 'sftpobject' => (
        is => 'ro',
        isa => 'Net::SSH2::SFTP',
        lazy => 1,
        builder => '_probe_sftpobj',
);

has '+fileclass' => (
        default => 'SReview::Files::Access::SFTP',
);

has 'basepath' => (
        is => 'ro',
        isa => 'Str',
        lazy => 1,
        builder => '_probe_basepath',
);

sub _probe_basepath {
        my $self = shift;

        my $url = Mojo::URL->new($self->baseurl);
        my $path = $url->path;
        return "$path";
}

sub _probe_sftpobj {
        my $self = shift;
        my $ssh = Net::SSH2->new();
        my $config = SReview::Config::Common::setup();

        my $url = Mojo::URL->new($self->baseurl);
        $ssh->connect($url->host);
        my $sshconf = $config->get('sftp_access_config');
        croak("SFTP access method requires sftp_access_config to be set!") unless defined $sshconf;
        if(exists($sshconf->{$url->host})) {
                $ssh->auth(%{$sshconf->{$url->host}});
        } elsif(exists($sshconf->{default})) {
                $ssh->auth(%{$sshconf->{default}});
        } else {
                croak('SFTP access method requires authentication configuration to be set in $sftp_access_config->{' . $url->host . "}!");
        }
        if(!$ssh->auth_ok) {
                croak("Couild not manage files using SFTP: authentication failure");
        }
        return $ssh->sftp();
}

sub _probe_children {
        my $self = shift;
        my $return = [];
        my $baseurl;

        eval {
                my $dir = $self->sftpobject->opendir($self->basepath);
                while(my $file = $dir->read) {
                        next if($file->{name} eq '.');
                        next if($file->{name} eq '..');
                        if(S_ISDIR($file->{mode})) {
                                eval {
                                        push @$return, @{SReview::Files::Collection::SFTP->new(baseurl => $self->baseurl . "/" . $file->{name}, sftpobject => $self->sftpobject, download_verbose => $self->download_verbose)->children};
                                };
                                if($@) {
                                        if($@->isa("Moose::Exception::ValidationFailedForInlineTypeConstraint")) {
                                                next;
                                        }
                                        die $@;
                                }
                        } else {
                                push @$return, SReview::Files::Access::SFTP->new(baseurl => $self->baseurl, relname => $file->{name}, sftpobject => $self->sftpobject, download_verbose => $self->download_verbose);
                        }
                }
        };
        if($@) {
                croak("Could not read directory " . $self->basepath . ": $@");
        }
        return $return;
}

sub has_file {
        my ($self, $target) = @_;
        return defined($self->sftpobject->stat(join('/', $self->basepath, $target)));
}

sub _create {
        my $self = shift;
        my %options = @_;

        $options{sftpobject} = $self->sftpobject;

        return $self->SUPER::_create(%options);
}

no Moose;

1;
