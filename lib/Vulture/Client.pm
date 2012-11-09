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
    my $rs = $self->schema->resultset('Client');
    my $client = $rs->find({
        agent => $ua,
        ip    => $ip,
    });
    if ($client) { $client->update({ active => 1 }) }
    else         {
        $client = $rs->create({
            agent     => $ua,
            ip        => $ip,
            active    => 1,
            joined_at => time,
        });
    }
    return $self->to_json({ joined => { ip => $ip, agent => $ua } });
}

#get '/api/client/leave/' => sub {
sub leave {
    my ($self) = @_;

    my ($ua, $ip) = $self->ua_ip();
    my $rs = $self->schema->resultset('Client');
    my $client = $rs->find({
        agent => $ua,
        ip    => $ip,
    });
    if ($client) {
        $client->update({ active => 0 });
        return $self->to_json({ left => { ip => $ip, agent => $ua } });
    }
    else {
        return $self->to_json({ error => { slug => 'unknown client' } });
    }

    # first see if there is an existing client with the current ip/ua
    # if so, make it in-active and return
    # else return an "unknown" error
}

1;
