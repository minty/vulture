package Vulture::Run;

use Mojo::Base 'Mojolicious::Controller';

use common::sense;
use File::Slurp qw<slurp>;
use Mojo::IOLoop;

sub api_list {
    my ($self) = @_;
    my $runs = $self->active_runs($self->param('state'));
    $self->to_api_list($runs);
}

sub list {
    my ($self) = @_;

    my $state = $self->param('state');
    if ($state eq 'all') {
        $self->stash(states => $self->rs('Run')->search_rs({}, {
            select   => ['state', { count => 'state' }],
            as       => [qw<state number>],
            group_by => 'state',
            order_by => { -desc => \'COUNT(*)' },
        }));
    }
    else {
        $self->stash(runs => $self->active_runs($self->param('state')));
    }
    return $self->render(template => 'run/list');
}

# get '/api/run/get' => sub {
sub get {
    my ($self) = @_;

    my $client = $self->client
        or return $self->to_json(
            { error => { slug => 'Bad client' } },
            { delay => 5 },
        );

    # Don't issue new runs if there are already ones running for this client
    my $existing = $self->rs('Job')->search({
        client_id => $client->id,
        state     => 'running',
    });
    return $self->to_json(
        { running => [ map { {
            id        => $_->id,
            run_id    => $_->run_id,
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
    my $job;
    my $id;
    my $start  = time;
    my $poll   = $self->config->{long_poll} || 60;
    my $freq   = $self->config->{poll_freq} || 5;
    my $clear  = sub { Mojo::IOLoop->remove($id) };
    my $stream = Mojo::IOLoop->stream($self->tx->connection);

    # If the client kills the connect, we want to kill the recurring timer
    my $abort = 0;
    $stream->on(close => sub { $abort = 1 });
    $stream->timeout($poll * 2);

    $id = Mojo::IOLoop->recurring($freq => sub {
        my $delta = time - $start;
        my $uid = join ' / ', $client->app_id, $client->client_id;
        warn "$delta : polling db for work for $uid";
        $job = $self->rs('Job')->search({
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
            || $job                         # we found work for the client
            || $delta > $poll;              # we hit a timeout

        if ($finish) {
            $self->on_timer_finish($job);
            $clear->();
        }
    });
}

sub on_timer_finish {
    my ($self, $job) = @_;

    return $self->to_json({ retry => 1 })
        if !$job;
    my $run = $self->rsfind(Run => $job->run_id)
        or return $self->to_json({ retry => 1 });
    my $file = $self->filepath('/tasks/' . $run->task_id);

    return $self->render_not_found
        if !-e $file->stringify;

    my $data = {
        state      => 'running',
        started_at => time,
    };
    $run->update($data)
        if $run->state ne 'running';
    $job->update($data);

    my $path = $file->stringify;

    return $self->to_json({ run => { run => {
        id        => $run->id,
        job_id    => $job->id,
        task      => scalar $file->slurp,
        task_data => $self->json->decode( scalar slurp "$path.json" ),
    } } });
}

#get '/api/run/done' => sub {
sub done {
    my ($self) = @_;
    $self->log_run('complete');
}
#get '/api/run/update' => sub {
sub update {
    my ($self) = @_;
    $self->log_run('update');
}
sub log_run {
    my ($self, $state) = @_;

    my $job_id = $self->param('job_id')
        or return $self->to_json({ error => { slug => 'missing job id' } });
    my $job = $self->rsfind(Job => $job_id)
        or return $self->to_json({ error => { slug => "cannot find job $job_id" } });

    my $client = $self->client
        or return $self->to_json(
            { error => { slug => 'Bad client' } },
         );

    my $count     = 1;
    my $test_name = '';
    for my $result ($self->param('result[]')) {
        chomp($result);
        my $state = $result =~ /\Aok /     ? 'ok'
                  : $result =~ /\Anot ok / ? 'not ok'
                  : $result =~ /\A# /      ? 'diag'
                  :                          '  ';
        if ($result =~ /\A(ok|not ok) (\d+) (.*)/) {
            $count     = $2;
            $test_name = $3;
        }
        $self->rs('JobResult')->create({
            job_id    => $job->id,
            state     => $state,
            count     => $count,
            test_name => $test_name,
            result    => $result,
        });
    }

    return $self->to_json({ thankyou => { slug => "job id $job_id updated" } })
        if $state ne 'complete';

    $job->update({
        state       => 'complete',
        finished_at => time,
    });

    # If all jobs for the current run are now 'complete'
    # then update $run->state == complete
    my $jobs = $self->rs('Job')->search({
        run_id => $job->run_id
    });
    my $total = $jobs->count;
    my $complete = $jobs->search({ state => 'complete' })->count;
    if ($total == $complete) {
        $job->run->update({
            state => 'complete',
            finished_at => time,
        });
    }

    return $self->to_json({ thankyou => { slug => "job id $job_id marked as complete" } });
};

# get '/api/run/:id' => sub {
sub run {
    my ($self) = @_;

    my $id = $self->param('id');
    return $self->render_not_found
        if $id !~ /\A[0-9]+\z/;

    my $clients = $self->active_clients();

    if (!$clients->count) {
        return $self->render(
            text   => "# No active clients available\n",
            format => 'txt'
        ) if $self->param('tap');
        return $self->to_json({
            error => { clients => 'No active clients available' }
        })
    }

    my $run_timeout = 30;

    my $data = {
        task_id    => $id,
        created_at => time,
        state      => 'pending',
    };
    $self->schema->txn_do(sub {
        my $run = $self->rs('Run')->create($data);
        $data->{id} = $run->id;

        # Now create a job for each active client
        my $clients = $self->active_clients();
        for my $client ($clients->all) {
            $self->rs('Job')->create({
                run_id     => $run->id,
                client_id  => $client->id,
                created_at => time,
                state      => 'pending',
            });

        }
        # Create a timer event to forcefully mark this job as 'orphaned'
        Mojo::IOLoop->timer($run_timeout => sub {
            my $job = $self->rs('Job')->search({
                run_id      => $run->id,
                state       => { '!=' => 'complete' },
            });
            $job->update({
                state       => 'orphaned',
                finished_at => time,
            });
            $_->run->update({
                state       => 'complete',
                finished_at => time,
            }) for $job->all;
        })
    });

    # Return a json response containing the run id, asap.  Then poll:
    #   client/run/$run_id
    #   api/client/run/$run_id
    #
    # If block=1 is appended to the querystring we block until the new run is
    # in some state other than pending or running.
    #
    # And we'll return a rich json response, similar to what
    # api/client/run/$run_id will return.
    #
    # Unless you also append tap=1 to the querystring (this is only possible
    # when you are also using block=1).  In this case, TAP compliant response
    # will be returned.

    return $self->to_json({ run => $data })
        if !$self->param('block');

    my $id;
    my $abort   = 0;
    my $freq    = $self->config->{poll_freq} || 5;
    my $start   = time;
    my $clear   = sub { Mojo::IOLoop->remove($id) };
    my $stream  = Mojo::IOLoop->stream($self->tx->connection);

    # If the client kills the connect, we want to kill the recurring timer
    # Or timeout after a hard period
    $stream->on(close => sub { $abort = 1 });
    $stream->timeout($run_timeout + 5);

    $id = Mojo::IOLoop->recurring($freq => sub {
        my $run   = $self->rs('Run')->find($data->{id})
            or return;
        my $delta = time - $start;
        my %poll  = map { $_ => 1 } qw<pending running>;

        my $finish = 0;
        $finish = 1
            if $abort                    # stream closed (client disconnect)
            || !$poll{ $run->state }     # run completed / failed
            || $delta > $run_timeout;    # we hit a timeout

        if ($finish) {
            $clear->();

            return $self->to_json({ run => $self->run_to_hash($run->id) })
                if !$self->param('tap');

            my $tap = '# Run id ' . $run->id . "\n";
            for my $job ($run->jobs) {
                my $client = $job->client;
                my $ident = join ' ',
                    $client->agent_browser,
                    $client->agent_browser_version,
                    'on',
                    $client->agent_os;
                $tap .= '# Job id ' . $job->id . " : $ident\n";
                for my $result ($job->results) {
                    $tap .= $result->result . "\n";
                }
                $tap .= "1.." . $job->results->search({
                    state => { -in => ['ok', 'not ok'] }
                })->count . "\n";
            }
            return $self->render(text => $tap, format => 'txt');
        }
    });
    return;
}

1;
