package SReview::Web::Controller::Talk;

use SReview::Model::Talk;

use Mojo::Base 'Mojolicious::Controller';

sub update {
	my $self = shift;

	my $model = SReview::Model::Talk->new(dbh => $self->dbh);

	my $nonce = $self->param("nonce");
	my $choice = $self->param("choice");
	my $id = $self->param("talk");
	my @names = $self->req->params->names;
	my $pp_target;
	my %corrections;
	foreach my $name(@names) {
		if($name =~ /correction_(.*)$/) {
			$corrections{$1} = $self->param("correction_$1");
		}
	}
	my $rv;
	my $message;
	if(defined($nonce)) {
		($rv, $message) = $model->update_nonce(nonce => $nonce, choice => $choice, corrections => \%corrections);
		$pp_target = "/review/$nonce";
	} elsif(defined($id)) {
		($rv, $message) = $model->update(id => $id, choice => $choice, corrections => \%corrections);
		$pp_target = "/admin/talk?talk=$id";
	} else {
		$self->stash(message => $self->stash('notfound_message'));
		$self->res->code($self->stash('notfound_code'));
		$self->render("error");
		return undef;
	}
	if($rv == 200) {
		$self->flash(completion_message => 'Your change has been accepted. Thanks for your help!');
		$self->redirect_to($pp_target);
	} else {
		$self->stash(message => $message);
		$self->res->code($rv);
		$self->render("error");
		return undef;
	}
}
