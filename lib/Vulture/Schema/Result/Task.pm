package Vulture::Schema::Result::Task;

use base 'DBIx::Class::Core';
use utf8;
use common::sense;

# minimally brief, as we store task data in the filesystem.
# it's your code : it wants vcs'ing.
# this table exists to generate unique ids.

__PACKAGE__->table('task');
__PACKAGE__->add_columns(
  id => { data_type => 'int', is_nullable => 0, is_auto_increment => 1 },
  # These are denormal cols.  The files on disk are authorative.
  # These are meant for indexing etc.
  name => { data_type => 'text', is_nullable => 0 },
  url  => { data_type => 'text', is_nullable => 0 },

);
__PACKAGE__->set_primary_key("id");

1;
