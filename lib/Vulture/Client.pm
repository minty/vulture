package Vulture::Client;

use Mojo::Base 'Mojolicious::Controller';

use common::sense;

#get '/client/list/' => sub {
sub list {
    my ($self) = @_;
    $self->stash(clients => $self->active_clients());
    return $self->render(template => 'client/list');
}

# get '/api/client/list/' => sub {
sub api_list {
    my ($self) = @_;
    my $clients = $self->active_clients();
    $self->to_api_list($clients);
}

# XXX post
# get '/api/client/join/' => sub {
sub join {
    my ($self) = @_;

    my ($ua, $ip) = $self->ua_ip();
    my $guid      = $self->param('guid');
    my $sessionid = $self->param('sessionid');
    return $self->to_json({ error => { slug => 'Missing guid/sessionid' } })
        if !$guid || !$sessionid;
    my $rs = $self->schema->resultset('Client');
    my $client = $rs->find({
        agent     => $ua,
        ip        => $ip,
        guid      => $guid,
        sessionid => $sessionid,
    });
    if ($client) { $client->update({
        active    => 1,
        last_seen => time,
        joined_at => time,
    }) }
    else         {
        $client = $rs->create({
            agent     => $ua,
            ip        => $ip,
            guid      => $guid,
            sessionid => $sessionid,
            active    => 1,
        });
    }
    return $self->to_json({ joined => {
        agent     => $ua,
        ip        => $ip,
        guid      => $guid,
        sessionid => $sessionid,
    } });
}

#get '/api/client/state/' => sub {
sub state {
    my ($self) = @_;

    my ($ua, $ip) = $self->ua_ip();
    my $rs = $self->schema->resultset('Client');
    my $guid      = $self->param('guid');
    my $sessionid = $self->param('sessionid');
    return $self->to_json({ error => { slug => 'Missing guid/sessionid' } })
        if !$guid || !$sessionid;
    my $client = $rs->find({
        agent     => $ua,
        ip        => $ip,
        guid      => $guid,
        sessionid => $sessionid,
        active    => 1,
    });
    return $self->to_json({ active => $client ? 1 : 0 });
}

#get '/api/client/leave/' => sub {
sub leave {
    my ($self) = @_;

    my ($ua, $ip) = $self->ua_ip();
    my $rs = $self->schema->resultset('Client');
    my $guid      = $self->param('guid');
    my $sessionid = $self->param('sessionid');
    return $self->to_json({ error => { slug => 'Missing guid/sessionid' } })
        if !$guid || !$sessionid;
    my $client = $rs->find({
        agent     => $ua,
        ip        => $ip,
        guid      => $guid,
        sessionid => $sessionid,
    });
    if ($client) {
        $client->update({ active => 0 });
        return $self->to_json({ left => {
            ip        => $ip,
            agent     => $ua,
            guid      => $guid,
            sessionid => $sessionid,
        } });
    }
    else {
        return $self->to_json({ error => { slug => 'unknown client' } });
    }

    # first see if there is an existing client with the current ip/ua
    # if so, make it in-active and return
    # else return an "unknown" error
}

1;
