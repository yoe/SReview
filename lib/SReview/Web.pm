package SReview::Web;

use Mojo::Base 'Mojolicious';
use Mojo::Collection 'c';
use Mojo::JSON qw(encode_json);
use SReview;
use SReview::Config;
use SReview::Config::Common;
use SReview::Db;

sub startup {
	my $self = shift;

	my $dir = $ENV{SREVIEW_WDIR};

	$self->config(hypnotoad => { pid_file => '/var/run/sreview/sreview.pid' });

	$dir = '.' if (!defined($dir));
	my $cfile = join('/', $dir, 'config.pm');
	if(! -f $cfile) {
		$cfile = join('/', '', 'etc', 'sreview', 'config.pm');
	}
	my $config = SReview::Config->new($cfile);

	SReview::Config::Common::setup($config);
	$config->define("secret", "A random secret key, used to encrypt the cookies. Leaking this will break your security!", "_INSECURE_DEFAULT_REPLACE_ME_");
	$config->define("event", "The default event to handle in the webinterface", undef);
	$config->define("vid_prefix", "The URL prefix to be used for video data files", "");
	$config->define("anonreviews", "Set to truthy if anonymous reviews should be allowed, or to falsy if not", 0);

	die "Need to configure secrets!" if $config->get("secret") eq "_INSECURE_DEFAULT_REPLACE_ME_";
	$self->secrets($config->get("secret"));

	SReview::Db::init($config);

	if($self->mode eq "production") {
		push @{$self->renderer->paths}, "/usr/share/sreview/templates";
		push @{$self->static->paths}, "/usr/share/sreview/public";
	} else {
		push @{$self->static->paths}, "./public";
		push @{$self->renderer->paths}, "./templates";
	}

	$self->helper(dbh => sub {
		state $dbh = DBI->connect_cached($config->get("dbistring"), '', '', {AutoCommit => 1}) or die "Cannot connect to database!";
		return $dbh;
	});

	my $template_dir = join('/', '.', $dir, 'templates');
	push @{$self->renderer->paths}, $template_dir;

	my $eventid = undef;
	my $st = $self->dbh->prepare("SELECT id FROM events WHERE name = ?");
	$st->execute($config->get("event")) or die "Could not find event!\n";
	while(my $row = $st->fetchrow_hashref("NAME_lc")) {
		die if defined($eventid);
		$eventid = $row->{id};
	}
	$self->helper(version => sub {
		state $rv;
		if(defined $rv) {
			return $rv;
		}
		open GIT, "git describe --tags --dirty 2>/dev/null|";
		$rv = <GIT>;
		close GIT;
		if(!defined $rv) {
			return $SReview::VERSION;
		}
		chomp $rv;
		return $rv;
	});

	my $r = $self->routes;
	$r->get('/' => sub {
		my $c = shift;
		$c->render;
	} => 'index');

	$r->get('/login');

	$r->post('/login_post' => sub {
		my $c = shift;

		my $email = $c->param('email');
		my $pass = $c->param('pass');

		my $st = $c->dbh->prepare("SELECT id, isadmin, isvolunteer, name, room FROM users WHERE email=? AND password=crypt(?, password)");
		my $rv;
		if(!($rv = $st->execute($email, $pass))) {
			die "Could not check password: " . $st->errstr;
		}
		if($rv == 0) {
			$c->stash(message => "Incorrect username or password.");
			$c->render('error');
			return undef;
		}
		my $row = $st->fetchrow_arrayref or die "eep?! username query returned nothing\n";
		$c->session->{id} = $row->[0];
		$c->session->{email} = $email;
		$c->session->{admin} = $row->[1];
		$c->session->{volunteer} = $row->[2];
		$c->session->{name} = $row->[3];
		$c->session->{room} = $row->[4];

		if($c->session->{volunteer}) {
			return $c->redirect_to('/volunteer/list');
		} else {
			return $c->redirect_to('/admin');
		}
	});

	$r->get('/review/:nonce' => sub {
		my $c = shift;
		my $stt = $c->dbh->prepare("SELECT state, name, id, extract(epoch from prelen) as prelen, extract(epoch from postlen) as postlen, extract(epoch from (endtime - starttime)) as length, speakers, starttime, endtime, slug, room, comments FROM talk_list WHERE nonce=?");
		my $rv = $stt->execute($c->param("nonce"));
		if($rv == 0) {
			$c->res->code(404);
			$c->render(text => "Invalid URL");
			return undef;
		}
		my $row = $stt->fetchrow_hashref("NAME_lc");
		if($row->{state} ne 'preview' && $row->{state} ne 'broken') {
			$c->stash(message => "The talk <q>" . $row->{name} . "</q> is not currently available for review. It is in the state <tt>" . $row->{state} . "</tt>, whereas we need the <tt>preview</tt> state to do review. For more information, please see <a href='https://yoe.github.io/sreview/'>the documentation</a>");
			$c->stash(title => 'Review finished or not yet available.');
			$c->render('msg');
			return undef;
		}
		my $stp = $c->dbh->prepare("SELECT properties.name, properties.description, properties.helptext, corrections.property_value FROM properties left join corrections on (properties.id = corrections.property AND talk = ?) ORDER BY properties.description");
		$stp->execute($row->{id});
		my $viddata = {};
		$viddata->{corrvals} = {};
		$viddata->{corrdescs} = {};
		$viddata->{corrhelps} = {};
		while(my $corrrow = $stp->fetchrow_hashref) {
			$viddata->{corrdescs}{$corrrow->{name}} = $corrrow->{description};
			$viddata->{corrhelps}{$corrrow->{name}} = $corrrow->{helptext};
			$viddata->{corrvals}{$corrrow->{name}} = $corrrow->{property_value} + 0;
		}

		$viddata->{mainlen} = $row->{length} + 0;
		$viddata->{prelen} = $row->{prelen} + 0;
		$viddata->{postlen} = $row->{postlen} + 0;

		$c->stash(title => 'Review for ' . $row->{name});
		$c->stash(talk_title => $row->{name});
		$c->stash(talk_speakers => $row->{speakers});
		$c->stash(talk_start => $row->{starttime});
		$c->stash(talk_end => $row->{endtime});
		$c->stash(slug => $row->{slug});
		$c->stash(event => $config->get("event"));
		$c->stash(eventid => $eventid);
		$c->stash(room => $row->{room});
		$c->stash(state => $row->{state});
		$c->stash(corrections => $viddata);
		$c->stash(comments => $row->{comments});
		$c->stash(target => "talk_update");
		$c->stash(layout => 'default');
		$c->stash(script_raw => 'sreview_viddata = ' . encode_json($viddata) . ';');
		$c->stash(vid_hostname => $config->get("vid_prefix"));
	} => 'talk');

	$r->get('/released' => sub {
		my $c = shift;
		my $st = $c->dbh->prepare("SELECT slug, upstreamid FROM talks WHERE state='done'");
		$st->execute;
		my @json = ();
		while (my $row = $st->fetchrow_hashref()) {
			my $slug = $row->{slug};
			push @json, { publicurl => "https://ftp.acc.umu.se/pub/debian-meetings/2017/debconf17/$slug.vp8.webm", waferurl => $row->{upstreamid} };
		}
		$c->render(json => \@json);
	});

	$r->get('/overview' => sub {
		my $c = shift;
		my $st;
		if($config->get("anonreviews")) {
			$st = $c->dbh->prepare('SELECT nonce, name, speakers, room, starttime, endtime, state, progress FROM talk_list WHERE eventid = ? AND state IS NOT NULL ORDER BY state, progress, room, starttime');
		} else {
			$st = $c->dbh->prepare('SELECT name, speakers, room, starttime, endtime, state, progress FROM talk_list WHERE eventid = ? AND state IS NOT NULL ORDER BY state, progress, room, starttime');
		}
		my $tot = $c->dbh->prepare('SELECT state, count(*) FROM talks WHERE event = ? GROUP BY state ORDER BY state;');
		my %expls;
		my $tot_results;
		my $totals = [];
		$expls{'waiting_for_files'} = 'Still waiting for content files for these talks';
		$expls{'cutting'} = 'Talk is being cut';
		$expls{'generating_previews'} = 'Talk previews are being generated';
		$expls{'notification'} = 'Sending out notifications';
		$expls{'preview'} = 'Talk ready for review, waiting for reviewer';
		$expls{'transcoding'} = 'High-quality transcodes running';
		$expls{'uploading'} = 'Publishing results';
		$expls{'done'} = 'Videos published, all done';
		$expls{'broken'} = 'Review found problems, administrator required';
		$expls{'needs_work'} = 'Fixable problems exist, manual intervention required';
		$expls{'lost'} = 'Nonfixable problems exist, talk lost';
		$st->execute($eventid) or die;
		$tot->execute($eventid) or die;
		$c->stash(title => 'Video status overview');
		$c->stash(titlerow => [ 'Talk', 'Speakers', 'Room', 'Start time', 'End time', 'State', 'Progress' ]);
		$c->stash(tottitrow => [ 'State', 'Count', 'State meaning']);
		my $rows = $st->fetchall_arrayref;
		if($config->get("anonreviews")) {
			my $newrows = [];
			foreach my $row(@$rows) {
				my $nonce = shift @$row;
				my $name = shift @$row;
				push @$newrows, [ "<a href='/review/$nonce'>$name</a>", @$row ];
			}
			$rows = $newrows;
		}
		$c->stash(rows => $rows);
		$c->stash(header => 'Video status overview');
		$tot_results = $tot->fetchall_arrayref();
		foreach my $row(@{$tot_results}) {
			push @$row, $expls{$row->[0]};
			push @$totals, $row;
		}
		$c->stash(totals => $totals);
		$c->stash(layout => 'default');
		$c->render;
	} => 'table');

	$r->post('/talk_update' => sub {
		my $c = shift;
		my $nonce = $c->param("nonce");
		if(!defined($nonce)) {
			$c->stash(message=>"Unauthorized.");
			$c->res->code(403);
			$c->render('error');
			return undef;
		}
		my $sth = $c->dbh->prepare("SELECT id FROM talks WHERE nonce = ? AND state IN ('preview', 'broken')");
		$sth->execute($nonce);
		my $row = $sth->fetchrow_arrayref;
		if(scalar($row) == 0) {
			$c->stash(message=>"Change not allowed. If this talk exists, it was probably reviewed by someone else while you were doing so too. Please try again later, or check the overview page.");
			$c->res->code(403);
			$c->render('error');
			return undef;
		}
		$c->stash(layout => 'default');
		$c->stash(template => 'talk');
		$c->flash(completion_message => 'Your change has been accepted. Thanks for your help!');
		$c->talk_update($row->[0]);
		$c->redirect_to("/review/$nonce");
	} => 'talk_update');

	my $vol = $r->under('/volunteer' => sub {
		my $c = shift;
		if(!exists($c->session->{id})) {
			$c->redirect_to('/login');
			return 0;
		}
		$c->stash(id => $c->session->{id});
		return 1;
	});

	$vol->get('/list' => sub {
		my $c = shift;
		my @talks;
		$c->dbh->begin_work;
		my $already = $c->dbh->prepare("SELECT nonce, title, id, state FROM talks WHERE reviewer = ? AND state <= 'preview'");
		my $new = $c->dbh->prepare("SELECT nonce, title, id, state FROM talks WHERE reviewer IS NULL AND state = 'preview'::talkstate LIMIT ? FOR UPDATE");
		my $claim = $c->dbh->prepare("UPDATE talks SET reviewer = ? WHERE id = ?");
		$already->execute($c->session->{id});
		my $count = $already->rows;
		if($count < 5) {
			$new->execute(5 - $count);
		}
		for(my $i = 0; $i < $count; $i++) {
			my $row = [ $already->fetchrow_array ];
			push @talks, $row;
		}
		for(my $i = 0; $i < $new->rows; $i++) {
			my $row = [ $new->fetchrow_array ];
			$claim->execute($c->session->{id}, $row->[2]);
			push @talks, $row;
		}
		$c->stash(talks => \@talks);
		$c->stash(layout => 'admin');
		$c->dbh->commit;
	} => 'volunteer/list');

	my $admin = $r->under('/admin' => sub {
		my $c = shift;
		if(!exists($c->session->{id})) {
			$c->res->code(403);
			$c->redirect_to('/login');
			return 0;
		}
		if($c->session->{volunteer}) {
			$c->redirect_to('/volunteer/list');
			return 0;
		}
		$c->stash(layout => "admin");
		$c->stash(admin => $c->session->{admin});
		return 1;
	});

	$admin->get('/' => sub {
		my $c = shift;
		my $st;
		my $talks = ();
		my $room;
		my $lastroom = '';

		if(defined($c->session->{room})) {
			$st = $c->dbh->prepare('SELECT id, room, name, starttime, speakers, state FROM talk_list WHERE eventid = ? AND roomid = ? ORDER BY starttime');
			$st->execute($eventid, $c->session->{room});
		} else {
			$st = $c->dbh->prepare('SELECT id, room, name, starttime, speakers, state FROM talk_list WHERE eventid = ? ORDER BY room, starttime');
			$st->execute($eventid);
		}
		while(my $row = $st->fetchrow_hashref("NAME_lc")) {
			if ($row->{'room'} ne $lastroom) {
				if(defined($room)) {
					push @$talks, c($lastroom => $room);
				}
				$room = [];
			}
			$lastroom = $row->{'room'};
			next unless defined($row->{id});
			push @$room, [$row->{'starttime'} . ': ' . $row->{'name'} . ' by ' . $row->{'speakers'} . ' (' . $row->{'state'} . ')' => $row->{'id'}];
		}
		if(defined($room)) {
			push @$talks, c($lastroom => $room);
		}
		$c->stash(email => $c->session->{email});
		$c->stash(talks => $talks);
		$c->render;
	} => 'admin/main');

	$admin->get('/logout' => sub {
		my $c = shift;
		delete $c->session->{id};
		delete $c->session->{room};
		$c->redirect_to('/');
	});

	$admin->get('/talk' => sub {
		my $c = shift;
		my $id = $c->param("talk");
		my $st;

		if(defined($c->session->{room})) {
			$st = $c->dbh->prepare('SELECT state, name, id, extract(epoch from prelen) as prelen, extract(epoch from postlen) as postlen, extract(epoch from (endtime - starttime)) as length, speakers, starttime, endtime, slug, room, comments, apologynote FROM talk_list WHERE id = ? AND roomid = ?');
			$st->execute($id, $c->session->{room});
		} else {
			$st = $c->dbh->prepare('SELECT state, name, id, extract(epoch from prelen) as prelen, extract(epoch from postlen) as postlen, extract(epoch from (endtime - starttime)) as length, speakers, starttime, endtime, slug, room, comments, apologynote FROM talk_list WHERE id = ?');
			$st->execute($id);
		}
		my $row = $st->fetchrow_hashref("NAME_lc");
		my $stp = $c->dbh->prepare("SELECT properties.name, properties.description, properties.helptext, corrections.property_value FROM properties left join corrections on (properties.id = corrections.property AND corrections.talk = ?) ORDER BY properties.description");
		$stp->execute($id);

		if(!defined($row)) {
			$c->stash(message => "Unknown talk.");
			$c->render('error');
			return undef;
		}
		my $viddata = {};
		$viddata->{corrvals} = {};
		$viddata->{corrdescs} = {};
		$viddata->{corrhelps} = {};
		while(my $corrrow = $stp->fetchrow_hashref) {
			$viddata->{corrdescs}{$corrrow->{name}} = $corrrow->{description};
			$viddata->{corrvals}{$corrrow->{name}} = $corrrow->{property_value} + 0;
			$viddata->{corrhelps}{$corrrow->{name}} = $corrrow->{helptext};
		}
		$viddata->{mainlen} = $row->{length} + 0;
		$viddata->{prelen} = $row->{prelen} + 0;
		$viddata->{postlen} = $row->{postlen} + 0;

		$c->stash(talk_title => $row->{name});
		$c->stash(talk_speakers => $row->{speakers});
		$c->stash(talk_start => $row->{starttime});
		$c->stash(talk_end => $row->{endtime});
		$c->stash(slug => $row->{slug});
		$c->stash(event => $config->get("event"));
		$c->stash(eventid => $eventid);
		$c->stash(room => $row->{room});
		$c->stash(state => $row->{state});
		$c->stash(comments => $row->{comments});
		$c->stash(corrections => $viddata);
		$c->stash(target => "talk_update_admin");
		$c->stash(script_raw => 'sreview_viddata = ' . encode_json($viddata) . ';');
		$c->stash(type => "admin");
		$c->stash(apology => $row->{apologynote});
		$c->stash(vid_hostname => $config->get("vid_prefix"));
		$c->render(template => 'talk');
	} => 'admin_talk');

	$admin->post('/talk_update' => sub {
		my $c = shift;
		my $talk = $c->param("talk");
		if(!defined($talk)) {
			$c->stash(message => "Required parameter talk missing.");
			$c->render("error");
			return undef;
		}
		$c->stash(template => 'talk');
		$c->flash(completion_message => 'Your change has been accepted. Thanks for your help!');
		$c->talk_update($talk);
		$c->redirect_to("/admin/talk?talk=$talk");
	} => 'talk_update_admin');

	$admin->get('/brokens' => sub {
		my $c = shift;
		my $st = $c->dbh->prepare("SELECT talks.id, title, speakeremail(talks.id), tracks.email, comments, state FROM talks JOIN tracks ON talks.track = tracks.id WHERE state>='broken' ORDER BY state,id");
		my $tst = $c->dbh->prepare("SELECT rooms.altname, count(talks.id) FROM talks JOIN rooms ON talks.room = rooms.id WHERE talks.state='broken' GROUP BY rooms.altname");
		my $rows = [];
		$st->execute;
		$tst->execute;
		$c->stash(title => 'Broken talks');
		$c->stash(titlerow => [ 'id', 'Title', 'Speakers', 'Track email', 'Comments', 'State', 'Link' ]);
		$c->stash(tottitrow => [ 'Room', 'Count' ]);
		my $pgrows = $st->fetchall_arrayref;
		foreach my $row(@{$pgrows}) {
			push @$row, "<a href='/admin/talk?talk=" . $row->[0] . "'>review</a>";
			push @$rows, $row;
		}
		$c->stash(rows => $rows);
		$c->stash(totals => $tst->fetchall_arrayref);
		$c->stash(header => 'Broken talks');
		$c->stash(layout => 'admin');
		$c->stash(totals => undef);
		$c->render(template => 'table');
	} => 'broken_table');

	my $sysadmin = $admin->under('/system' => sub {
		my $c = shift;
		if(!exists($c->session->{id})) {
			$c->res->code(403);
			$c->render(text => 'Unauthorized (not logged on)');
			return 0;
		}
		if(!$c->session->{admin}) {
			$c->res->code(403);
			$c->render(text => 'Unauthorized (not admin)');
			return 0;
		}
		$c->stash(layout => "admin");
		$c->stash(admin => $c->session->{admin});
		return 1;
	});

	$sysadmin->get('/' => sub {
		my $c = shift;
		$c->stash(email => $c->session->{email});
		my $st = $c->dbh->prepare("SELECT DISTINCT rooms.id, rooms.name FROM rooms LEFT JOIN talks ON rooms.id = talks.room WHERE talks.event = ?");
		$st->execute($eventid);
		my $rooms = [['All rooms' => '', selected => 'selected']];
		while(my $row = $st->fetchrow_arrayref) {
			push @$rooms, [$row->[1] => $row->[0]];
		}
		$c->stash(rooms => $rooms);
	} => 'admin/dashboard');

	$sysadmin->get('/adduser' => sub {
		my $c = shift;
		open PASSWORD, "pwgen -s 10 -n 1|";
		my $password = <PASSWORD>;
		close(PASSWORD);
		chomp $password;
		my $st = $c->dbh->prepare("INSERT INTO users(email, name, isadmin, isvolunteer, password, room) VALUES(?, ?, ?, ?, crypt(?, gen_salt('bf', 8)), ?)");
		my $room = $c->param('rooms');
		if($room eq "") {
			$room = undef;
		}
		$st->execute($c->param('email'), $c->param('name'), $c->param('isadmin'), $c->param('isvolunteer'), $password, $room) or die;
		$c->dbh->prepare("UPDATE users SET isadmin = false WHERE isadmin is null")->execute;
		$c->flash(msg => "User with email " . $c->param('email') . " created, with password '$password'");
		$c->redirect_to('/admin/system');
	});

	$sysadmin->get('/chpw' => sub {
		my $c = shift;
		my $st = $c->dbh->prepare("SELECT * FROM users WHERE email=?");
		my $email = $c->param("email");
		$st->execute($email);
		if($st->rows != 1) {
			$c->flash(msg => "There is no user with email address " . $c->param('email') . ". Try creating it?");
			$c->redirect_to('/admin/system');
			return;
		}
		open PASSWORD, "pwgen -s 10 -n 1|";
		my $password = <PASSWORD>;
		close(PASSWORD);
		chomp $password;
		$st = $c->dbh->prepare("UPDATE users SET password = crypt(?, gen_salt('bf', 8)) WHERE email = ?");
		$st->execute($password, $email);
		$c->flash(msg => "Password for user $email set to '$password'");
		$c->redirect_to('/admin/system');
	});

	$sysadmin->get('/setpw' => sub {
		my $c = shift;
		my $pw1 = $c->param('password1');
		my $pw2 = $c->param('password2');
		if ($pw1 ne $pw2) {
			$c->flash(msg => "Passwords did not match!");
			$c->redirect_to('/admin/system');
			return;
		}
		my $st = $c->dbh->prepare("UPDATE users SET password = crypt(?, gen_salt('bf', 8)) WHERE email = ?");
		$st->execute($pw1, $c->session->{email});
		$c->flash(msg => "Password changed.");
		$c->redirect_to('/admin/system');
	});

	$r->get('*any' => sub {
		my $c = shift;
		$c->redirect_to('/overview');
	});
}

1;
