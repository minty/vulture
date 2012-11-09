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

sub active_clients {
    return $schema->resultset('Client')->search_rs({ active => 1 });
}
get '/api/client/list/' => sub {
    my ($self) = @_;
    return _json($self, [ map { $_->agent } active_clients()->all ]);
};
get '/client/list/' => sub {
    my ($self) = @_;
    $self->stash(clients => active_clients());
    return $self->render(template => 'client/list');
};

sub ua_ip {
    my ($self) = @_;

    return ($self->req->headers->user_agent, $self->tx->remote_address);
}
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

app->start;
