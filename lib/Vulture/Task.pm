package Vulture::Task;

use Mojo::Base 'Mojolicious::Controller';

use common::sense;
use Path::Class;
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
        $self->stash(states => $self->schema->resultset('Task')->search_rs({}, {
            select   => ['state', { count => 'state' }],
            as       => [qw<state number>],
            group_by => 'state'
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

    my ($ua, $ip) = $self->ua_ip();
    my $rs = $self->schema->resultset('Client');
    my $client = $rs->find({
        agent  => $ua,
        ip     => $ip,
        active => 1,
    });
    return $self->to_json({ error => { slug => 'unknown (inactive) client' } })
        if !$client;

    # Don't issue new tasks if there are already ones running for this client
    my $existing = $self->schema->resultset('ClientTask')->search({
        client_id => $client->id,
        state     => 'running',
    });
    return $self->to_json({ running => [ map { {
        id        => $_->id,
        task_id   => $_->task_id,
        client_id => $_->client_id,
    } } $existing->all ] })
        if $existing->count;

    # Wants to be WebSockets, but IE < 10 doesn't support them :(
    # Poll the DB every second to see if there is work.
    # As soon as we find work, or after 60 seconds, return.
    # The client is then expected to re-connect.
    # Mojolicious::Guides::Cookbook#REALTIME_WEB
    my $clienttask;
    my $id;
    my $start = time;
    my $poll  = $self->config->{long_poll} || 60;
    my $freq  = $self->config->{poll_freq} || 5;
    my $clear = sub { Mojo::IOLoop->remove($id) };

    Mojo::IOLoop->stream($self->tx->connection)->timeout($poll * 2);

    $id = Mojo::IOLoop->recurring($freq => sub {

        my $delta = time - $start;
        warn "$delta : polling db for work";
        $clienttask = $self->schema->resultset('ClientTask')->search({
            client_id => $client->id,
            state     => 'pending',
        }, {
            order_by => { -asc => 'created_at' },
            rows     => 1,
        })->single;
        if ($clienttask || time - $start > $poll) {
            $self->on_timer_finish($clienttask);
            $clear->();
        }
    });
}

sub on_timer_finish {
    my ($self, $clienttask) = @_;

    return $self->to_json({ retry => 1 })
        if !$clienttask;
    my $task = $self->schema->resultset('Task')->find( $clienttask->task_id )
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

    return $self->to_json({ run => { task => {
        id            => $task->id,
        clienttask_id => $clienttask->id,
        test          => scalar $file->slurp,
    } } });
}

#get '/api/task/done' => sub {
sub done {
    my ($self) = @_;

    my $clienttask_id = $self->param('clienttask_id')
        or return $self->to_json({ error => { slug => 'missing clienttask id' } });
    my $clienttask = $self->schema->resultset('ClientTask')->find($clienttask_id)
        or return $self->to_json({ error => { slug => "cannot find clienttask $clienttask_id" } });

    my ($ua, $ip) = $self->ua_ip();
    my $rs = $self->schema->resultset('Client');
    my $client = $rs->find({
        agent  => $ua,
        ip     => $ip,
        active => 1,
    });
    return $self->to_json({ error => { slug => 'unknown (inactive) client' } })
        if !$client;

    $clienttask->update({
        state       => 'complete',
        finished_at => time,
        result      => $self->param('result') || '' }
    );

    # If all clienttasks for the current task are now 'complete'
    # then update $task->state == complete
    my $all_clienttasks = $self->schema->resultset('ClientTask')->search({
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
        my $task = $self->schema->resultset('Task')->create($data);
        $data->{id} = $task->id;

        # Now create a client_task for each active client
        my $clients = $self->active_clients();
        for my $client ($clients->all) {
            $self->schema->resultset('ClientTask')->create({
                task_id    => $task->id,
                client_id  => $client->id,
                created_at => time,
                state      => 'pending',
            });
        }
    });

    return $self->to_json({ run => $data });
}

1;
