package Vulture::Test;

use Mojo::Base 'Mojolicious::Controller';

use common::sense;
use File::Slurp qw<slurp write_file>;

#get '/test/edit/:id' => sub {
sub edit {
    my ($self) = @_;

    my $test_id = $self->param('test_id')
        or return $self->to_json(
            { error => { slug => 'Missing test_id in url' } },
        );

    my $file = $self->filepath('/tests/' . $test_id);
    return $self->render_not_found
        if !-e $file->stringify;

    $self->stash(
        test => scalar $file->slurp,
    );
    return $self->render(template => 'test/edit');
}

1;
