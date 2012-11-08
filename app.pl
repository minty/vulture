#!/usr/bin/env perl

# run with
# morbo -l "https://192.168.58.100:8899" ./app.pl

use Mojolicious::Lite;
use Text::Xslate::Bridge::TT2;
use JSON::XS;

my $json = JSON::XS->new->utf8->pretty;

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
#
#   # schedule a test to be run on all current clients
#   /api/test/run/?test_file
#   # for a client to report back test status
#   /api/test/report/?key
#
# In due course we might also add reporting / stat pages
#  /stats/blah...

get '/page/' => sub {
    my ($self) = @_;

    $self->stash(
        name => "murray",
    );
    return $self->render;
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

app->start;
