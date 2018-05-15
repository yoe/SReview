package SReview::Web;

use Mojo::Base 'Mojolicious';
use Mojo::Collection 'c';
use Mojo::JSON qw(encode_json);
use Mojo::Pg;
use SReview;
use SReview::Config;
use SReview::Config::Common;
use SReview::Db;
use SReview::Video;
use SReview::Video::ProfileFactory;

sub startup {
	my $self = shift;

	my $dir = $ENV{SREVIEW_WDIR};

	$self->config(hypnotoad => { pid_file => '/var/run/sreview/sreview-web.pid' });

	my $config = SReview::Config::Common::setup;

	die "Need to configure secrets!" if $config->get("secret") eq "_INSECURE_DEFAULT_REPLACE_ME_";
	$self->secrets([$config->get("secret")]);

	SReview::Db::init($config);

	if($self->mode eq "production") {
		push @{$self->renderer->paths}, "/usr/share/sreview/templates";
		push @{$self->static->paths}, "/usr/share/sreview/public";
		push @{$self->static->paths}, "/usr/share/javascript";
	} else {
		push @{$self->static->paths}, "./public";
		push @{$self->renderer->paths}, "./templates";
	}
	if(defined($config->get("pubdir"))) {
		push @{$self->static->paths}, $config->get("pubdir");
	}

	$self->hook(before_dispatch => sub {
		my $c = shift;
		my $vpr = $config->get('vid_prefix');
		my $media = "media-src 'self'";
		if(defined($vpr) && length($vpr) > 0) {
			$media = "media-src $vpr;";
		}
		$c->res->headers->content_security_policy("default-src 'none'; script-src 'self' 'unsafe-inline'; font-src 'self'; style-src 'self'; img-src 'self'; frame-ancestors 'none'; $media");
	});

	$self->helper(dbh => sub {
		state $pg = Mojo::Pg->new->dsn($config->get('dbistring'));
		return $pg->db->dbh;
	});
	
	$self->helper(talk_update => sub {
		my $c = shift;
		my $talk = shift;
		my $choice = $c->param('choice');
		if(!defined($choice)) {
			die "choice empty";
		} elsif($choice eq "reset") {
			my $sth = $c->dbh->prepare("UPDATE talks SET state='preview', progress='waiting' WHERE id = ?");
			$sth->execute($talk) or die;
		} elsif($choice eq "ok") {
			my $sth = $c->dbh->prepare("UPDATE talks SET state='preview', progress='done' WHERE id = ?");
			$sth->execute($talk) or die;
		} elsif($choice eq 'standard') {
			my $sth = $c->dbh->prepare("SELECT id, name FROM properties");
			$sth->execute();
			while(my $row = $sth->fetchrow_hashref("NAME_lc")) {
				my $name = $row->{name};
				my $parm = $c->param("correction_${name}");
				next unless defined($parm);
				next if (length($parm) == 0);
				my $s = $c->dbh->prepare("INSERT INTO corrections(property_value, talk, property) VALUES (?, ?, ?)");
				$s->execute($parm, $talk, $row->{id}) or die;
			}
			$sth = $c->dbh->prepare("UPDATE talks SET state='waiting_for_files', progress='done' WHERE id = ?");
			$sth->execute($talk) or die;
		} elsif($choice eq "comments") {
			my $sth = $c->dbh->prepare("UPDATE talks SET state='broken', progress='failed', comments = ? WHERE id = ?");
			my $comments = $c->param("comment_text");
			$sth->execute($comments, $talk) or die;
		} else {
			$c->stash(message => "Unknown action.");
			$c->render("error");
			return undef;
		}
		$c->stash(message => 'Update successful.');
	});

	my $eventid = undef;
	my $st = $self->dbh->prepare("SELECT id FROM events WHERE name = ?");
	$st->execute($config->get("event")) or die "Could not find event!\n";
	while(my $row = $st->fetchrow_hashref("NAME_lc")) {
		die if defined($eventid);
		$eventid = $row->{id};
	}
	$self->helper(eventid => sub {
		return $eventid;
	});

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
		$c->stash(talk_nonce => $c->param("nonce"));
		$c->stash(slug => $row->{slug});
		$c->stash(event => $config->get("event"));
		$c->stash(eventid => $c->eventid);
		$c->stash(room => $row->{room});
		$c->stash(state => $row->{state});
		$c->stash(corrections => $viddata);
		$c->stash(comments => $row->{comments});
		$c->stash(target => "talk_update");
		$c->stash(layout => 'default');
		$c->stash(scripts_raw => ['sreview_viddata = ' . encode_json($viddata) . ';']);
		$c->stash(scripts_extra => ['/mangler.js']);
		$c->stash(exten => $config->get('preview_exten'));
		$c->stash(vid_hostname => $config->get("vid_prefix"));
	} => 'talk');

	$r->get('/released' => sub {
		my $c = shift;
		my $st;
		my $conference = {};
		my $videos = [];
		my %json;
		my %formats;
		my $have_default = 0;
		$st = $c->dbh->prepare("SELECT MIN(starttime::date), MAX(endtime::date) FROM talks WHERE event = ?");
		$st->execute($c->eventid);
		$conference->{title} = $config->get("event");
		my $row = $st->fetchrow_hashref();
		$conference->{date} = [ $row->{min}, $row->{max} ];
		$conference->{video_formats} = [];
		$st = $c->dbh->prepare("SELECT filename FROM raw_files JOIN talks ON raw_files.room = talks.room WHERE talks.event = ? LIMIT 1");
		$st->execute($c->eventid);
		if($st->rows < 1) {
			$c->render(json => {});
			return;
		}
		$row = $st->fetchrow_hashref;
		my $vid = SReview::Video->new(url => $row->{filename});
		foreach my $format(@{$config->get("output_profiles")}) {
			my $nf;
			$self->log->debug("profile $format");
			my $prof = SReview::Video::ProfileFactory->create($format, $vid);
			if(!$have_default) {
				$nf = "default";
				$have_default = 1;
			} else {
				$nf = $format;
			}
			push @{$conference->{video_formats}}, { $nf => { vcodec => $prof->video_codec, acodec => $prof->audio_codec, resolution => $prof->video_size, bitrate => $prof->video_bitrate } };
			$formats{$nf} = $prof;
		}
		$json{conference} = $conference;
		$st = $c->dbh->prepare("SELECT title, subtitle, speakerlist(talks.id), description, starttime, starttime::date AS date, to_char(starttime, 'yyyy') AS year, endtime, rooms.name AS room, rooms.outputname AS room_output, upstreamid, events.name AS event, slug FROM talks JOIN rooms ON talks.room = rooms.id JOIN events ON talks.event = events.id WHERE state='done' AND event = ?");
		$st->execute($c->eventid);
		if($st->rows < 1) {
			$c->render(json => {});
			return;
		}
		my $mt = Mojo::Template->new;
		$mt->vars(1);
		while (my $row = $st->fetchrow_hashref()) {
			my $video = {};
			my $subtitle = defined($row->{subtitle}) ? " " . $row->{subtitle} : "";
			$video->{title} = $row->{title} . $subtitle;
			$video->{speakers} = [ $row->{speakerlist} ];
			$video->{description} = $row->{description};
			$video->{start} = $row->{starttime};
			$video->{end} = $row->{endtime};
			$video->{room} = $row->{room};
			$video->{eventid} = $row->{upstreamid};
			my @outputdirs;
			foreach my $subdir(@{$config->get('output_subdirs')}) {
				push @outputdirs, $row->{$subdir};
			}
			my $outputdir = join('/', @outputdirs);
			if(defined($config->get('eventurl_format'))) {
				$video->{details_url} = $mt->render($config->get('eventurl_format'), {
					slug => $row->{slug},
					room => $row->{room},
					date => $row->{date},
					year => $row->{year} });
			}
			$video->{video} = join('/',$outputdir, $row->{slug}) . "." . $formats{default}->exten;
			push @$videos, $video;
		}
		$json{videos} = $videos;
		$c->render(json => \%json);
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
		$expls{'ignored'} = 'Talk will not be/was not recorded, ignored for review';
		$expls{'needs_work'} = 'Fixable problems exist, manual intervention required';
		$expls{'lost'} = 'Nonfixable problems exist, talk lost';
		$st->execute($c->eventid) or die;
		$tot->execute($c->eventid) or die;
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

	$vol->get('/list')->to('volunteer#list');

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

	$admin->any('/schedule/list')->to(controller => 'schedule', action => 'talks');
	$admin->any('/schedule/talk/')->to(controller => 'schedule', action => 'mod_talk');
	$admin->any('/schedule/')->to(controller => 'schedule', action => 'index');

	$admin->get('/')->to('admin#main');

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
			$st = $c->dbh->prepare('SELECT state, name, id, extract(epoch from prelen) as prelen, extract(epoch from postlen) as postlen, extract(epoch from (endtime - starttime)) as length, speakers, starttime, endtime, slug, room, comments, apologynote, nonce FROM talk_list WHERE id = ? AND roomid = ?');
			$st->execute($id, $c->session->{room});
		} else {
			$st = $c->dbh->prepare('SELECT state, name, id, extract(epoch from prelen) as prelen, extract(epoch from postlen) as postlen, extract(epoch from (endtime - starttime)) as length, speakers, starttime, endtime, slug, room, comments, apologynote, nonce FROM talk_list WHERE id = ?');
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
		$c->stash(talk_nonce => $row->{nonce});
		$c->stash(slug => $row->{slug});
		$c->stash(event => $config->get("event"));
		$c->stash(eventid => $c->eventid);
		$c->stash(room => $row->{room});
		$c->stash(state => $row->{state});
		$c->stash(comments => $row->{comments});
		$c->stash(corrections => $viddata);
		$c->stash(target => "talk_update_admin");
		$c->stash(scripts_raw => ['sreview_viddata = ' . encode_json($viddata) . ';']);
		$c->stash(scripts_extra => ['/mangler.js']);
		$c->stash(type => "admin");
		$c->stash(apology => $row->{apologynote});
		$c->stash(vid_hostname => $config->get("vid_prefix"));
		$c->stash(exten => $config->get('preview_exten'));
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
		$st->execute($c->eventid);
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
