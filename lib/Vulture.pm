package Vulture;

# XXX
# Proxy fetch api
# simple key-value store api
# stats pages

use Mojo::Base 'Mojolicious';
use Mojo::IOLoop;
use Text::Xslate::Bridge::TT2;
use JavaScript::Value::Escape;
use JSON::XS;
use Vulture::Schema;

# setup with
#   sqlite3 vulture.sqlite < ./schema.sql
# run with
#   morbo -l "http://192.168.58.100:8899" script/vulture

# https://github.com/oyvindkinsey/easyXDM#readme

# This method will run once at server start
sub startup {
    my ($self) = @_;

    # config / setup
    $self->plugin(Config => {
        file => 'etc/vulture.conf'
    });
    $self->plugin(xslate_renderer => {
        template_options => {
            syntax  => 'TTerse',
            module  => [
                'Text::Xslate::Bridge::TT2',
                'JavaScript::Value::Escape' => [qw(js)],
            ],
            function => {
                array => sub { return [ shift->all ] },
            },
            verbose => 1,
            suffix  => 'tx',
        }
    });

    my $sql_db = $self->config->{repo_dir} . '/vulture.sqlite';
    $self->helper(schema => sub {
        state $db = Vulture::Schema->connect("dbi:SQLite:dbname=$sql_db");
        return $db;
    });
    $self->helper(rs     => sub { shift->schema->rs(@_) });
    $self->helper(rsfind => sub { shift->schema->rsfind(@_) });

    $self->helper(json => sub {
        state $json = JSON::XS->new->utf8->pretty;
        return $json;
    });

    $self->helper(filepath => sub {
        my ($self, $rel) = @_;
        return Path::Class::File->new(
            $self->config->{repo_dir} . "$rel.txt"
        );
    });

    # We do this, rather than $self->render(json => $ref)
    # so we can pretty-ify the json for human eyes.  It's also shorter.
    $self->helper(to_json => sub {
        my ($self, $ref, $args) = @_;
        $args //= {};
        my $delay = $args->{delay} ? $args->{delay} : 0;
        if ($delay) { Mojo::IOLoop->timer($delay => sub { _to_json($self, $ref) }) }
        else        { _to_json($self, $ref) }
    });

    $self->helper(to_api_list => sub {
        my ($self, $rs) = @_;
        $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
        return $self->to_json([ map { $_ } $rs->all ]);
    });

    $self->helper(active_tasks => sub {
        my ($self, $state) = @_;
        return $self->rs('Task')->search_rs({
            state => $state
        }, {
            order_by => { -desc => 'created_at' },
        });
    });

    $self->helper(active_clients => sub {
        my ($self, $state) = @_;
        return $self->rs('Client')->search_rs({
            active => 1,
        }, {
            order_by => { -desc => 'last_seen' },
        });
    });

    $self->helper(ua_ip => sub {
        my ($self) = @_;
        return ($self->req->headers->user_agent, $self->tx->remote_address);
    });

    $self->helper(client => sub {
        my ($self) = @_;

        my ($ua, $ip) = $self->ua_ip();
        my $guid      = $self->param('guid');
        my $sessionid = $self->param('sessionid');
        if (!$guid || !$sessionid) {
            warn "Missing guid/sessionid";
            return;
        }
        return $self->rsfind(Client => {
            agent     => $ua,
            ip        => $ip,
            guid      => $guid,
            sessionid => $sessionid,
            active    => 1,
        });
    });

    $self->secret('Took a long time to hatch');

    # Auto disconnect any client not seen for 300 seconds.
    # (calling /api/get/task updates last_seen)
    Mojo::IOLoop->recurring(60 => sub {
        my $now     = DateTime->now;
        my $clients = $self->rs('Client')->search({
            active    => 1,
            last_seen => { '<' => time - 300 }
        });
        warn "$now Disconnecting '" . $_->agent . "' " . $_->guid . '/' . $_->sessionid
            for $clients->all;
        $clients->update({ active => 0 });
    });

    my $r = $self->routes;
    $r->get('/task/list/:state')
        ->to(controller => 'task', action => 'list');
    $r->get('/api/task/list/:state')
        ->to(controller => 'task', action => 'api_list');
    $r->get('/api/task/get')
        ->to(controller => 'task', action => 'get');
    $r->get('/api/task/done')
        ->to(controller => 'task', action => 'done');

    $r->get('/api/run/:id')
        ->to(controller => 'task', action => 'run');

    $r->get('/client/list')
        ->to(controller => 'client', action => 'list');
    $r->get('/client/task/:task_id')
        ->to(controller => 'client', action => 'task');
    $r->get('/api/client/list')
        ->to(controller => 'client', action => 'api_list');
    $r->get('/api/client/state')
        ->to(controller => 'client', action => 'state');
    $r->get('/api/client/join')
        ->to(controller => 'client', action => 'join');
    $r->get('/api/client/eject/:client_id')
        ->to(controller => 'client', action => 'eject');
    $r->get('/api/client/leave')
        ->to(controller => 'client', action => 'leave');

    $r->get('/agent/list')
        ->to(controller => 'agent', action => 'list');
    $r->get('/agent/show')
        ->to(controller => 'agent', action => 'show');
    $r->get('/agent/ip/show')
        ->to(controller => 'agent', action => 'showip');

    $r->get('/ip/list')
        ->to(controller => 'ip', action => 'list');
    $r->get('/ip/show')
        ->to(controller => 'ip', action => 'show');

    $r->get('/page/:page')
        ->to(controller => 'page', action => 'page');
}

sub _to_json {
    my ($self, $ref) = @_;
    $self->res->headers->header('Content-type' => 'application/json; charset=utf-8');
    return $self->render(data => $self->json->encode( $ref ));
}

1;
