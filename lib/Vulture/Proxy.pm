package Vulture::Proxy;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::UserAgent;
use URI;
use List::MoreUtils qw<any>;
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

    # This should be improved.  We want to avoid trying to proxy requests to
    # ourselves.  We can't know what ip/port/domain we're running on, unless we
    # tell ourselves via config.  But is there a better way?  Check the http
    # headers for forwarded-for?  This is a dirty old hack that suffices for me
    # for now.  We should at least be checking port also, and using faster
    # matching.
    my $uri           = URI->new($url);
    my $authority     = $uri->authority;
    return $self->render_not_found
        if any { $authority eq $_ } @{ $self->config->{do_no_proxy} };

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
