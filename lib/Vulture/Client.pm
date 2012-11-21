package Vulture::Client;

use Mojo::Base 'Mojolicious::Controller';
use HTTP::BrowserDetect;
use common::sense;

#get '/client/' => sub {
sub hq {
    my ($self) = @_;
    $self->stash(
    );
    return $self->render(template => 'hq');
}

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
    my $app_id    = $self->param('app_id');
    my $client_id = $self->param('client_id');
    return $self->to_json({ error => { slug => 'Missing app/client id' } })
        if !$app_id || !$client_id;
    my $rs = $self->rs('Client');
    my $client = $rs->find({
        agent     => $ua,
        ip        => $ip,
        app_id    => $app_id,
        client_id => $client_id,
    });
    if ($client) { $client->update({
        active    => 1,
        last_seen => time,
        joined_at => time,
    }) }
    else         {
        my $browser = HTTP::BrowserDetect->new($ua);

        $client = $rs->create({
            agent                 => $ua,
            agent_device          => $browser->device_name    || '',
            agent_os              => $browser->os_string      || '',
            agent_browser         => $browser->browser_string || '',
            agent_browser_version => $browser->public_version || '',
            agent_engine          => $browser->engine_string  || '',
            ip                    => $ip,
            app_id                => $app_id,
            client_id             => $client_id,
            active                => 1,
        });
    }
    return $self->to_json({ joined => {
        agent     => $ua,
        ip        => $ip,
        app_id    => $app_id,
        client_id => $client_id,
    } });
}

#get '/api/client/state/' => sub {
sub state {
    my ($self) = @_;

    my $client = $self->client
        or return $self->to_json({ error => { slug => 'Bad client' } });
    return $self->to_json({ active => $client ? 1 : 0 });
}

sub client_hash {
    my ($self, $client) = @_;
    return {
        id        => $client->id,
        ip        => $client->ip,
        agent     => $client->agent,
        app_id    => $client->app_id,
        client_id => $client->client_id,
        active    => $client->active,
    };
}

#get '/api/client/leave/' => sub {
sub leave {
    my ($self) = @_;

    my $client = $self->client
        or return $self->to_json({ error => { slug => 'Bad client' } });
    if ($client) {
        $client->update({ active => 0 });
        return $self->to_json({ left => $self->client_hash($client) });
    }
    else {
        return $self->to_json({ error => { slug => 'unknown client' } });
    }

    # first see if there is an existing client with the current ip/ua
    # if so, make it in-active and return
    # else return an "unknown" error
}

# 'leave' is meant for a client to disconnect itself.
# 'eject' lets one client forcefully disconnect another.
sub eject {
    my ($self) = @_;
    my $client_id = $self->param('client_id')
        or return $self->to_json({ error => { slug => 'No client id' } });
    my $client = $self->rsfind(Client => $client_id)
        or return $self->to_json({ error => { slug => 'Bad client id' } });
    $client->update({ active => 0 });
    return $self->to_json({ left => $self->client_hash($client) });
}

sub task {
    my ($self) = @_;

    my $task_id = $self->param('task_id')
        or return $self->to_json({ error => { slug => 'No task id' } });
    my $task = $self->rsfind(Task => $task_id)
        or return $self->to_json({ error => { slug => 'Bad task id' } });
    $self->stash(
        task => $task,
    );
    return $self->render(template => 'client/task');
}

1;
