package SReview::Web::Controller::CreditPreviews;

use Mojo::Base 'Mojolicious::Controller';

use SReview::Talk;
use SReview::Template::SVG qw/process_template/;
use SReview::Files::Factory;

sub serve_png {
	my $c = shift->openapi->valid_input;
	my $slug = $c->param("slug");
	my $suffix = $c->stash("suffix");
	my $talk = SReview::Talk->by_slug($slug);
	my $input_coll = SReview::Files::Factory->create("intermediate", $c->srconfig->get("pubdir"));
	my $relname = $talk->relative_name . $suffix;
	if($c->param("force") || !($input_coll->has_file($relname))) {
		my $preroll_file = $input_coll->add_file(relname => $relname);
		process_template($c->srconfig->get('preroll_template'), $preroll_file->filename, $talk, $c->srconfig);
		$preroll_file->store_file;
	}
	return $c->reply->file($input_coll->get_file(relname => $relname)->filename);
}

1;
