package Vulture::Task;

use Mojo::Base 'Mojolicious::Controller';

use common::sense;
use File::Slurp qw<slurp>;
use Mojo::IOLoop;

sub api_list {
    my ($self) = @_;
    my $tasks = $self->active_tasks($self->param('state'));
    $self->to_api_list($tasks);
}

sub list {
    my ($self) = @_;

    my $state = $self->param('state');
    if ($state eq 'all') {
        $self->stash(states => $self->rs('Task')->search_rs({}, {
            select   => ['state', { count => 'state' }],
            as       => [qw<state number>],
            group_by => 'state',
            order_by => { -desc => \'COUNT(*)' },
        }));
    }
    else {
        $self->stash(tasks => $self->active_tasks($self->param('state')));
    }
    return $self->render(template => 'task/list');
}

# get '/api/task/get' => sub {
sub get {
    my ($self) = @_;

    my $client = $self->client
        or return $self->to_json(
            { error => { slug => 'Bad client' } },
            { delay => 5 },
        );

    # Don't issue new tasks if there are already ones running for this client
    my $existing = $self->rs('ClientTask')->search({
        client_id => $client->id,
        state     => 'running',
    });
    return $self->to_json(
        { running => [ map { {
            id        => $_->id,
            task_id   => $_->task_id,
            client_id => $_->client_id,
        } } $existing->all ] },
        { delay => 3 }
    ) if $existing->count;

    $client->update({ last_seen => time });

    # Wants to be WebSockets, but IE < 10 doesn't support them :(
    # Poll the DB every second to see if there is work.
    # As soon as we find work, or after 60 seconds, return.
    # The client is then expected to re-connect.
    # Mojolicious::Guides::Cookbook#REALTIME_WEB
    my $clienttask;
    my $id;
    my $start  = time;
    my $poll   = $self->config->{long_poll} || 60;
    my $freq   = $self->config->{poll_freq} || 5;
    my $clear  = sub { Mojo::IOLoop->remove($id) };
    my $stream = Mojo::IOLoop->stream($self->tx->connection);

    # If the client kills the connect, we want to kill the recurring timer
    my $abort = 0;
    $stream->on(close => sub { $abort = 1 });

    Mojo::IOLoop->stream($self->tx->connection)->timeout($poll * 2);

    $id = Mojo::IOLoop->recurring($freq => sub {
        my $delta = time - $start;
        my $uid = join ' / ', $client->guid, $client->sessionid;
        warn "$delta : polling db for work for $uid";
        $clienttask = $self->rs('ClientTask')->search({
            client_id => $client->id,
            state     => 'pending',
        }, {
            order_by => { -asc => 'created_at' },
            rows     => 1,
        })->single;

        my $current_client = $self->rsfind(Client => $client->id);
        my $finish = 0;
        $finish = 1
            if !$current_client             # client has gone away
            || !$current_client->active     # client is no longer active
            || $abort                       # stream closed (client disconnect)
            || $clienttask                  # we found work for the client
            || time - $start > $poll;       # we hit a timeout

        if ($finish) {
            $self->on_timer_finish($clienttask);
            $clear->();
        }
    });
}

sub on_timer_finish {
    my ($self, $clienttask) = @_;

    return $self->to_json({ retry => 1 })
        if !$clienttask;
    my $task = $self->rsfind(Task => $clienttask->task_id)
        or return $self->to_json({ retry => 1 });
    my $file = $self->filepath('/tests/' . $task->test_id);

    return $self->render_not_found
        if !-e $file->stringify;

    my $data = {
        state      => 'running',
        started_at => time,
    };
    $task->update($data)
        if $task->state ne 'running';
    $clienttask->update($data);

    my $path = $file->stringify;

    return $self->to_json({ run => { task => {
        id            => $task->id,
        clienttask_id => $clienttask->id,
        test          => scalar $file->slurp,
        test_data     => $self->json->decode( scalar slurp "$path.json" ),
    } } });
}

#get '/api/task/done' => sub {
sub done {
    my ($self) = @_;

    my $clienttask_id = $self->param('clienttask_id')
        or return $self->to_json({ error => { slug => 'missing clienttask id' } });
    my $clienttask = $self->rsfind(ClientTask => $clienttask_id)
        or return $self->to_json({ error => { slug => "cannot find clienttask $clienttask_id" } });

    my $client = $self->client
        or return $self->to_json(
            { error => { slug => 'Bad client' } },
         );

    $clienttask->update({
        state       => 'complete',
        finished_at => time,
    });
    for my $result ($self->param('result[]')) {
        $self->rs('ClientTaskResult')->create({
            client_task_id => $clienttask->id,
            result         => $result,
        });
    }

    # If all clienttasks for the current task are now 'complete'
    # then update $task->state == complete
    my $all_clienttasks = $self->rs('ClientTask')->search({
        task_id => $clienttask->task_id
    });
    my $total = $all_clienttasks->count;
    my $complete = $all_clienttasks->search({ state => 'complete' })->count;
    if ($total == $complete) {
        $clienttask->task->update({
            state => 'complete',
            finished_at => time,
        });
    }

    return $self->to_json({ thankyou => { slug => "clienttask id $clienttask_id marked as complete" } });
};

# get '/api/run/:id' => sub {
sub run {
    my ($self) = @_;

    my $id = $self->param('id');
    return $self->render_not_found
        if $id !~ /\A[0-9]+\z/;

    my $data = {
        test_id    => $id,
        created_at => time,
        state      => 'pending',
    };
    $self->schema->txn_do(sub {
        my $task = $self->rs('Task')->create($data);
        $data->{id} = $task->id;

        # Now create a client_task for each active client
        my $clients = $self->active_clients();
        for my $client ($clients->all) {
            $self->rs('ClientTask')->create({
                task_id    => $task->id,
                client_id  => $client->id,
                created_at => time,
                state      => 'pending',
            });

        }
        # Create a timer event to forcefully mark this client task as 'orphaned'
        my $task_timeout = 30;
        Mojo::IOLoop->timer($task_timeout => sub {
            my $clienttask = $self->rs('ClientTask')->search({
                task_id     => $task->id,
                state       => { '!=' => 'complete' },
            });
            $clienttask->update({
                state       => 'orphaned',
                finished_at => time,
            });
            $_->task->update({
                state       => 'complete',
                finished_at => time,
            }) for $clienttask->all;
        })
    });

    return $self->to_json({ run => $data });
}

1;
