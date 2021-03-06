package Vulture::Task;

use Mojo::Base 'Mojolicious::Controller';

use common::sense;
use File::Slurp qw<slurp write_file>;

#get '/task/edit/:id' => sub {
sub edit {
    my ($self) = @_;

    my $task_id = $self->param('task_id');
    if (!$task_id) {
        $task_id = $self->rs('Task')->create({})->id;
        return $self->redirect_to("/TESTING/task/edit/$task_id");
    }

    my $file = $self->filepath('/tasks/' . $task_id);
    my $path = $file->stringify;

    my ($task, $task_data) = ('', {});
    if (-e $path) {
        $task = $file->slurp;
        $task_data = $self->json->decode( scalar slurp "$path.json" );
    }

    $self->stash(
        task      => $task,
        task_data => $task_data,
        id        => $task_id,
    );
    return $self->render(template => 'task/edit');
}

#get '/api/task/save/:task_id' => sub {
# data should contain 'url' and 'js' params
sub save {
    my ($self) = @_;

    my $task_id = $self->param('task_id')
        || return $self->to_json(
            { error => { slug => 'Missing task_id in url' } },
        );
    return $self->to_json(
        { error => { slug => 'invalid task id' } },
    ) if $task_id !~ /\A\d+\z/;

    my $js = $self->param('task_js')
        || return $self->to_json(
            { error => { slug => 'Missing task js in post data' } },
        );

    my $url = $self->param('url')
        || return $self->to_json(
            { error => { slug => 'Missing task url in post data' } },
        );

    my $file = $self->filepath('/tasks/' . $task_id);
    my $path = $file->stringify;

    # Our tasks are js code, and we'd like those tracked via git for all the
    # usual reasons.  The url and other meta data is a fundemental part of the
    # task, which we want to be able to load in Perl.  The question is where to
    # store it.
    # (a) in the db.  Bad because you cannot git clone the repo and run tasks
    #     without also first "importing" this task meta data into the db.
    # (b) Embedded into the js, say as a comment on the first line:
    #     // url = 'blah'
    #     Hugely icky.
    # (c) Store the meta data seperately, in parallel, using json.
    # The problem with storing the actual js inside json is that once encoded
    # into json, the code has newlines replaced with \n, and this makes them
    # ickier to track in git -- the diffs aren't as clean.
    # So for now, we're storing the js in it's own txt file, as-is, and the
    # associated meta data in a seperate but parallel .json file.

    my $ref = {
        id   => $task_id,
        url  => $url,
        name => $self->param('name') || '',
    };

    write_file $path, $js;
    write_file "$path.json", $self->json->encode($ref);

    $self->rs('Task')->update_or_create($ref);

    return $self->to_json(
        { saved => { task_id => $task_id } },
    );
}

sub list {
    my ($self) = @_;

    my $conds = {};
    my %filters = map { $_ => scalar $self->param($_) || '' } qw<name url>;
    for my $field (qw<name url>) {
        $conds->{ $field } = { -like => '%' . $self->param( $field ) . '%' }
            if $self->param( $field );
    }

    my $page = $self->param('page');
    $page = 1
        if $page !~ /\A\d+\z/;

    my $args = {
        rows => 20,
        page => $page,
    };

    $self->stash(
        tasks   => $self->rs('Task')->search_rs($conds, $args),
        filters => \%filters,
    );
    return $self->render(template => 'task/list');
}

1;
