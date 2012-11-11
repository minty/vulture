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

#get '/agent/show/?agent=...' => sub {
sub show {
    my ($self) = @_;

    my $agent = $self->param('agent')
        or return $self->to_json(
            { error => { slug => 'Missing agent param in querystring' } },
        );

    $self->stash(
        agent => $agent,
        ips => $self->rs('Client')->search_rs({
            agent => $agent,
        }, {
            select   => [ 'ip', { count => 'ip' } ],
            as       => [qw<ip count>],
            group_by => 'ip',
            order_by => { -desc => \'count(ip)' },
        }),
    );
    return $self->render(template => 'agent/show');
}

#get '/agent/ip/show/?agent=...&ip=...' => sub {
sub showip {
    my ($self) = @_;

    my $agent = $self->param('agent')
        or return $self->to_json(
            { error => { slug => 'Missing agent param in querystring' } },
        );
    my $ip = $self->param('ip')
        or return $self->to_json(
            { error => { slug => 'Missing ip param in querystring' } },
        );

    $self->stash(
        agent   => $agent,
        ip      => $ip,
        clients => $self->rs('Client')->search_rs({
            agent => $agent,
            ip    => $ip,
        }, {
            order_by => { -desc => 'last_seen' },
        }),
    );
    return $self->render(template => 'client/list');
}

1;
