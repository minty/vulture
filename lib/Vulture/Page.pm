package Vulture::Page;

use Mojo::Base 'Mojolicious::Controller';

use common::sense;
use Path::Class;
use File::Slurp qw<slurp write_file>;

sub page {
    my ($self) = @_;

    my $page = $self->param('page');
    return $self->render_not_found
        if $page !~ /\A[0-9a-zA-Z]+\z/;

    my $file = $self->filepath("/pages/$page");

    return $self->render_not_found
        if !-e $file->stringify;

    $self->stash(file_data => scalar slurp $file->stringify);
    return $self->render(template => 'page');
}

1;
