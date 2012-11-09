package Vulture::Task;

use Mojo::Base 'Mojolicious::Controller';

use common::sense;
use Path::Class;
use File::Slurp qw<slurp>;

sub api_list {
    my ($self) = @_;
    my $tasks = $self->active_tasks($self->param('state'));
    $self->to_api_list($tasks);
}

sub list {
    my ($self) = @_;
    $self->stash(tasks => $self->active_tasks($self->param('state')));
    return $self->render(template => 'task/list');
}

# get '/api/task/get' => sub {
sub get {
    my ($self) = @_;

    my ($ua, $ip) = $self->ua_ip();
    my $rs = $self->schema->resultset('Client');
    my $client = $rs->find({
        agent => $ua,
        ip    => $ip,
    });
    return $self->to_json({ error => { slug => 'unknown client' } })
        if !$client;

    # XXX
    # Check there are no running tasks for this client
    # If so, refuse to issue more work until that task is done.
    # A well behaved client *should* never request more work, but it might.

    my $clienttask = $self->schema->resultset('ClientTask')->search({
        client_id => $client->id,
        state     => 'pending',
    }, {
        order_by => { -asc => 'created_at' },
        rows     => 1,
    })->single;

    # Mojolicious::Guides::Cookbook
    # http://mojolicio.us/perldoc/Mojolicious/Guides/Cookbook#REALTIME_WEB
    return $self->to_json({ retry => 1 })
        if !$clienttask;

    my $task = $self->schema->resultset('Task')->find( $clienttask->task_id )
        or return $self->to_json({ retry => 1 });

    my $file = Path::Class::File->new('/home/murray/mojo/vulture/tests/' . $task->test_id . '.txt');

    return $self->render_not_found
        if !-e $file->stringify;

    return $self->to_json({ run => { task => {
        id => $task->id,
        test => scalar $file->slurp,
    } } });

    # build test page
    # have it join the api
    # have it fetch a task
    # have it execute the task
}

#get '/api/task/done' => sub {
sub done {
    my ($self) = @_;

    my ($ua, $ip) = $self->ua_ip();
    # Expect a task id
    # and a result string
    my $rs = $self->schema->resultset('Client');
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

    # my $file = file("/home/murray/mojo/vulture/tests/$id.txt");
    return $self->to_json({ run => $data });
}

1;
