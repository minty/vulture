#!/usr/bin/env perl

# setup with
#   sqlite3 vulture.sqlite < ./schema.sql
#
# run with
#   morbo -l "https://192.168.58.100:8899" script/vulture

package main;

# Goal:
#   - via cmd line perl, make http request to morbo server to run a task
#   - task js is defined in a git-committed file
#   - js is run on all subscribed clients
#
# XXX Convert it into a proper Mojo class, with DBIx schemas
# XXX Convert /get/task to be blocking
# XXX Proxy fetch api
# XXX simple key-value store api
#
# These return html pages.
#   /page/client.html      # setup browser as a test client
#   /page/edit.html        # edit a test
#
# These implement a simple key value store, that tests can use.
# The data should be written to a dir under git control
#   /api/get/
#   /api/set/
#
# In due course we might also add reporting / stat pages
#  /stats/blah...

