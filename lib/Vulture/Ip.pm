package Vulture::Ip;

use Mojo::Base 'Mojolicious::Controller';

use common::sense;

#get '/ip/list/' => sub {
sub list {
    my ($self) = @_;
    $self->stash(
        ips => $self->rs('Client')->search_rs({}, {
            select   => [ 'ip', { count => 'ip' } ],
            as       => [qw<ip count>],
            group_by => 'ip',
            order_by => { -desc => \'count(agent)' },
        }),
    );
    return $self->render(template => 'ip/list');
}

#get '/ip/show/?ip=...' => sub {
sub show {
    my ($self) = @_;

    my $ip = $self->param('ip')
        or return $self->to_json(
            { error => { slug => 'Missing ip param in querystring' } },
        );

    $self->stash(
        ip => $ip,
        agents => $self->rs('Client')->search_rs({
            ip => $ip,
        }, {
            select   => [ 'agent', { count => 'agent' } ],
            as       => [qw<agent count>],
            group_by => 'agent',
            order_by => { -desc => \'count(agent)' },
        }),
    );
    return $self->render(template => 'ip/show');
}

1;
