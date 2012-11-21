vulture
=======

a Mojolicious project for running javascript based tests in multiple, 
distributed web browsers with a central (proxy) server acting as a hub
controller.

Roughly:

    # clone https://github.com/minty/vulture/
    cd vulture
    cpanm --installdeps .
    # review/edit/tweak etc/vulture.conf
    sqlite3 vulture.sqlite < ./schema.sql
    morbo ./script/vulture

Next, configure your browser to use the server/port as it's HTTP proxy.  We are
using a proxy to bypass XSS browser limitations.

Because our test pages are intercepted by the proxy, and thus can be served
on any domain, you can run the tests from the same domain you're testing, and
thus side-step the cross domain security limitations.

Then visit http://example.com/TESTING/client/ in a browser to launch a client tester.

You join, then click "Start working" (or press the 's' key).

* http://example.com/TESTING/client/list to list active clients
* http://example.com/TESTING/test/edit to create tests

## Documentation

* [Vocabulary](https://github.com/minty/vulture/wiki/Vocabulary)
* [Roadmap](https://github.com/minty/vulture/wiki/Roadmap)