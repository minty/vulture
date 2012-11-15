package Vulture::Test;

use Mojo::Base 'Mojolicious::Controller';

use common::sense;
use File::Slurp qw<slurp write_file>;

#get '/test/edit/:id' => sub {
sub edit {
    my ($self) = @_;

    my $test_id = $self->param('test_id')
        or return $self->to_json(
            { error => { slug => 'Missing test_id in url' } },
        );

    my $file = $self->filepath('/tests/' . $test_id);
    return $self->render_not_found
        if !-e $file->stringify;

    $self->stash(
        test => scalar $file->slurp,
        id   => $test_id,
    );
    return $self->render(template => 'test/edit');
}

#get '/api/test/save/:test_id' => sub {
# data should contain 'url' and 'js' params
sub save {
    my ($self) = @_;

    my $test_id = $self->param('test_id')
        or return $self->to_json(
            { error => { slug => 'Missing test_id in url' } },
        );

    my $js = $self->param('test_js')
        or return $self->to_json(
            { error => { slug => 'Missing test js in post data' } },
        );

    my $url = $self->param('url')
        or return $self->to_json(
            { error => { slug => 'Missing test url in post data' } },
        );

    my $file = $self->filepath('/tests/' . $test_id);
    my $path = $file->stringify;
    return $self->render_not_found
        if !-e $path;

    die "Cannot write to $path"
        if !-w $path;

    # Our tests are js code, and we'd like those tracked via git for all the
    # usual reasons.  The url and other meta data is a fundemental part of the
    # test, which we want to be able to load in Perl.  The question is where to
    # store it.
    # (a) in the db.  Bad because you cannot git clone the repo and run tests
    #     without also first "importing" this test meta data into the db.
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
        id  => $test_id,
        url => $url,
    };

    write_file $path, $js;
    write_file "$path.json", $self->json->encode($ref);

    return $self->to_json(
        { saved => { test_id => $test_id } },
    );
}

1;
