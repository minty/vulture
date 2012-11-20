package Vulture::Schema::Result::Test;

use base 'DBIx::Class::Core';
use utf8;
use common::sense;

# minimally brief, as we store test data in the filesystem.
# it's your code : it wants vcs'ing.
# this table exists to generate unique ids.

__PACKAGE__->table('test');
__PACKAGE__->add_columns(
  id => { data_type => 'int', is_nullable => 0, is_auto_increment => 1 },
);
__PACKAGE__->set_primary_key("id");

1;
