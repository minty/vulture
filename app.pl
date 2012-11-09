#!/usr/bin/env perl

# setup with
#   sqlite3 vulture.sqlite < ./schema.sql
#
# run with
#   morbo -l "https://192.168.58.100:8899" ./app.pl

package VultureDB;
use base 'DBIx::Class::Schema::Loader';

__PACKAGE__->naming('current');
__PACKAGE__->use_namespaces(1);
__PACKAGE__->loader_options();

package main;

use Mojolicious::Lite;
use Text::Xslate::Bridge::TT2;
use JSON::XS;
use Path::Class qw<file>;
use File::Slurp qw<slurp write_file>;

my $json   = JSON::XS->new->utf8->pretty;
my $sql_db = '/home/murray/mojo/vulture/vulture.sqlite';
my $schema = VultureDB->connect("dbi:SQLite:dbname=$sql_db", '', '', {});

app->secret('testers testers testers');

plugin xslate_renderer => {
    template_options => {
        syntax => 'TTerse',
        module => [
            'Text::Xslate::Bridge::TT2',
            'JavaScript::Value::Escape' => [qw(js)],
        ],
        suffix  => 'tx',
    }
};

# These return html pages.
#   /page/client.html      # setup browser as a test client
#   /page/edit.html        # edit a test
#
# These implement a simple key value store, that tests can use.
# The data should be written to a dir under git control
#   /api/get/
#   /api/set/
#
# These are json api hooks
#   # Let a browser join/leave a test pool
#   /api/client/join/
#   /api/client/leave/
#   /api/client/list/
#
#   # schedule a test to be run on all current clients
#   /api/test/run/?test_file
#   # for a client to report back test status
#   /api/test/report/?key
#
# In due course we might also add reporting / stat pages
#  /stats/blah...

get '/api/task/get' => sub {
    my ($self) = @_;

    my ($ua, $ip) = ua_ip($self);
    my $rs = $schema->resultset('Client');
    my $client = $rs->find({
        agent => $ua,
        ip    => $ip,
    });
    return _json($self, { error => { slug => 'unknown client' } })
        if !$client;

    # XXX
    # Check there are no running tasks for this client
    # If so, refuse to issue more work until that task is done.
    # A well behaved client *should* never request more work, but it might.

    my $clienttask = $schema->resultset('ClientTask')->search({
        client_id => $client->id,
        state     => 'pending',
    }, {
        order_by => { -asc => 'created_at' },
        rows     => 1,
    })->single;

    # Mojolicious::Guides::Cookbook
    # http://mojolicio.us/perldoc/Mojolicious/Guides/Cookbook#REALTIME_WEB
    return _json($self, { retry => 1 })
        if !$clienttask;

    my $task = $schema->resultset('Task')->find( $clienttask->task_id )
        or return _json($self, { retry => 1 });

    # XXX
    # Slurp in the javascript from file for task id ...
    # Return that javascript as a string to the client
    return _json($self, { run => { task => $task->id } });
};

get '/api/task/done' => sub {
    my ($self) = @_;

    my ($ua, $ip) = ua_ip($self);
    # Expect a task id
    # and a result string
    my $rs = $schema->resultset('Client');
};

# XXX POST
get '/api/run/:id' => sub {
    my ($self) = @_;

    my $id = $self->param('id');
    return $self->render_not_found
        if $id !~ /\A[0-9]+\z/;

    my $data = {
        test_id    => $id,
        created_at => time,
        state      => 'pending',
    };
    $schema->txn_do(sub {
        my $task = $schema->resultset('Task')->create($data);
        $data->{id} = $task->id;

        # Now create a client_task for each active client
        my $clients = active_clients();
        for my $client ($clients->all) {
            $schema->resultset('ClientTask')->create({
                task_id    => $task->id,
                client_id  => $client->id,
                created_at => time,
                state      => 'pending',
            });
        }
    });

    # my $file = file("/home/murray/mojo/vulture/tests/$id.txt");
    return _json($self, { run => $data });
};
get '/api/task/list/:state' => sub {
    my ($self) = @_;
    my $tasks = active_tasks($self->param('state'));
    api_list($self, $tasks);
};
get '/task/list/:state' => sub {
    my ($self) = @_;
    $self->stash(tasks => active_tasks($self->param('state')));
    return $self->render(template => 'task/list');
};

get '/api/client/list/' => sub {
    my ($self) = @_;
    my $clients = active_clients();
    api_list($self, $clients);
};
get '/client/list/' => sub {
    my ($self) = @_;
    $self->stash(clients => active_clients());
    return $self->render(template => 'client/list');
};

# XXX post
get '/api/client/join/' => sub {
    my ($self) = @_;

    my ($ua, $ip) = ua_ip($self);
    my $rs = $schema->resultset('Client');
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
    return _json($self, { joined => { ip => $ip, agent => $ua } });
};
get '/api/client/leave/' => sub {
    my ($self) = @_;

    my ($ua, $ip) = ua_ip($self);
    my $rs = $schema->resultset('Client');
    my $client = $rs->find({
        agent => $ua,
        ip    => $ip,
    });
    if ($client) {
        $client->update({ active => 0 });
        return _json($self, { left => { ip => $ip, agent => $ua } });
    }
    else {
        return _json($self, { error => { slug => 'unknown client' } });
    }

    # first see if there is an existing client with the current ip/ua
    # if so, make it in-active and return
    # else return an "unknown" error
};

get '/page/:page' => sub {
    my ($self) = @_;

    my $page = $self->param('page');
    return $self->render_not_found
        if $page !~ /\A[0-9a-zA-Z]+\z/;

    my $file = file('/home/murray/mojo/vulture/pages/' . $page . '.txt');
    return $self->render_not_found
        if !-e $file->stringify;

    $self->stash(file_data => slurp $file->stringify);
    return $self->render(template => 'page');
};

get '/list/' => sub {
    my ($self) = @_;

    return $self->render(text => $json->encode({}));
};

post '/reset/' => sub {
    my ($self) = @_;

    my $name  = $self->param('name');
    return $self->render(text => $json->encode({}));
};


# We do this, rather than $self->render(json => $ref)
# so we can pretty-ify the json for human eyes.  It's also shorter.
sub _json {
    my ($self, $ref) = @_;

    $self->res->headers->header('Content-type' => 'application/json; charset=utf-8');
    return $self->render(text => $json->encode( $ref ));
}

sub api_list {
    my ($self, $rs) = @_;
    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    return _json($self, [ map { $_ } $rs->all ]);
}

sub ua_ip {
    my ($self) = @_;

    return ($self->req->headers->user_agent, $self->tx->remote_address);
}

sub active_tasks {
    my ($state) = @_;
    return $schema->resultset('Task')->search_rs({ state => $state });
}

sub active_clients {
    return $schema->resultset('Client')->search_rs({ active => 1 });
}

app->start;
