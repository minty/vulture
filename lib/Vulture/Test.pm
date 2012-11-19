package Vulture::Test;

use Mojo::Base 'Mojolicious::Controller';

use common::sense;
use File::Slurp qw<slurp write_file>;

#get '/test/edit/:id' => sub {
sub edit {
    my ($self) = @_;

    my $test_id = $self->param('test_id');
    if (!$test_id) {
        $test_id = $self->rs('Test')->create({})->id;
        return $self->redirect_to("/TESTING/test/edit/$test_id");
    }

    my $file = $self->filepath('/tests/' . $test_id);
    my $path = $file->stringify;

    my ($test, $test_data) = ('', {});
    if (-e $path) {
        $test = $file->slurp;
        $test_data = $self->json->decode( scalar slurp "$path.json" );
    }

    $self->stash(
        test      => $test,
        test_data => $test_data,
        id        => $test_id,
    );
    return $self->render(template => 'test/edit');
}

#get '/api/test/save/:test_id' => sub {
# data should contain 'url' and 'js' params
sub save {
    my ($self) = @_;

    my $test_id = $self->param('test_id')
        || return $self->to_json(
            { error => { slug => 'Missing test_id in url' } },
        );
    return $self->to_json(
        { error => { slug => 'invalid test id' } },
    ) if $test_id !~ /\A\d+\z/;

    my $js = $self->param('test_js')
        || return $self->to_json(
            { error => { slug => 'Missing test js in post data' } },
        );

    my $url = $self->param('url')
        || return $self->to_json(
            { error => { slug => 'Missing test url in post data' } },
        );

    my $file = $self->filepath('/tests/' . $test_id);
    my $path = $file->stringify;

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
