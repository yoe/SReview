package SReview::Web::Controller::CreditPreviews;

use Mojo::Base 'Mojolicious::Controller';

use SReview::Talk;
use SReview::Template::SVG qw/process_template/;
use SReview::Files::Factory;

my %valid_suffix = (pre => ["preroll_template"], post => ["postroll_template", "postroll"], sorry => , ["apology_template"]);

sub serve_png {
	my $c = shift->openapi->valid_input or return;;
	my $slug = $c->param("slug");
	my $suffix = $c->stash("suffix");
	my $nonce = $c->param("nonce");
	my $talk;
	if(defined($slug)) {
		$talk = SReview::Talk->by_slug($slug);
	} elsif(defined($nonce)) {
		$talk = SReview::Talk->by_nonce($nonce);
	} else {
		$c->app->log->debug("no slug or nonce, can't generate a preview");
		return $c->reply->not_found;
	}
	if(!defined($talk)) {
		$c->app->log->debug("talk not found");
		return $c->reply->not_found;
	}
	my $input_coll = SReview::Files::Factory->create("intermediate", $c->srconfig->get("pubdir"));
	my $template;
	if(!exists($valid_suffix{$suffix})) {
		$c->app->log->debug("invalid suffix, ignored");
		return $c->reply->not_found;
	}
	if(scalar(@{$valid_suffix{$suffix}}) > 1) {
		$c->app->log->debug("checking if static file exists");
		my $png = $c->srconfig->get($valid_suffix{$suffix}[1]);
		if(defined $png && -f $png) {
			$c->app->log->debug("using prerendered file");
			return $c->reply->file($png);
		}
	}
	$template = $c->srconfig->get($valid_suffix{$suffix}[0]);
	if(!defined $template) {
		$c->app->log->debug("template not configured, ignored");
		return $c->reply->not_found;
	}
	$c->app->log->debug("looking for render of template $template");
	my $relname = $talk->relative_name . "-" . $suffix . ".png";
	my $force = $c->param("force");
	if((defined($force) && $force ne "false") || !($input_coll->has_file($relname))) {
		$c->app->log->debug("file does not exist or force specified, rerendering");
		my $preroll_file = $input_coll->add_file(relname => $relname);
		process_template($template, $preroll_file->filename, $talk, $c->srconfig);
		$preroll_file->store_file;
	}
	$c->app->log->debug("serving rendered file...");
	return $c->reply->file($input_coll->get_file(relname => $relname)->filename);
}

1;
