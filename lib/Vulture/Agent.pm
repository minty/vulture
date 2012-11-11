package Vulture::Agent;

use Mojo::Base 'Mojolicious::Controller';

use common::sense;

#get '/agent/list/' => sub {
sub list {
    my ($self) = @_;
    $self->stash(
        agents => $self->rs('Client')->search_rs({}, {
            select   => [ 'agent', { count => 'agent' } ],
            as       => [qw<agent count>],
            group_by => 'agent',
            order_by => { -desc => \'count(agent)' },
        }),
    );
    return $self->render(template => 'agent/list');
}

1;
