vulture
=======

a Mojolicious project for running javascript based tests in multiple, distributed web browsers with a central (proxy) server acting as a hub controller.

Roughly:

  # clone https://github.com/minty/vulture/
  cd vulture.git
  sqlite3 vulture.sqlite < ./schema.sql
  morbo ./script/vulture

Next, configure your browser to use the server/port as it's HTTP proxy.

Then visit http://example.com/TESTING/client/ in a browser.

* http://example.com/TESTING/client/ to launch a client tester

You join, then click "work".

* http://example.com/TESTING/client/list to list active clients
* http://example.com/TESTING/test/edit to create tests