package Vulture::Proxy;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::UserAgent;
use common::sense;

my $ua = Mojo::UserAgent->new;
$ua->max_redirects(30);

sub proxy {
    my ($self) = @_;

    # client == the browser using the proxy
    # server == upstream site we're fetching pages from

    my $client_req    = $self->tx->req;
    my $url           = $client_req->url;
    my $method        = $client_req->method;
    my $server_req_tx = $ua->build_tx($method => $url);
    my %forbid        = map { $_ => 1 } qw<Proxy-Connection>;

    warn "Proxying $method $url";

    for my $name (@{ $client_req->headers->names }) {
        next if $forbid{ $name };
        $server_req_tx->req->headers->add(
            $name => $client_req->headers->header( $name )
        );
        #warn "Copying through $name => " . $client_req->headers->header($name);
    }

    my $server_res = $ua->start( $server_req_tx )->res;
    my $client_res = $self->tx->res;

    $client_res->code( $server_res->code );

    # Fudge response http headers
    for my $name (@{ $server_res->headers->names }){
        $client_res->headers->add(
            $name => $server_res->headers->header($name)
        );
        #warn "Copying back $name => " . $server_res->headers->header($name);
    }

    #$client_res->headers->add(
    #    'Access-Control-Allow-Origin' => 'http://www.theregister.co.uk'
    #);

    $self->render(data => $server_res->body);
}

1;
