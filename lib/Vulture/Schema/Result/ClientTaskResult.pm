package Vulture::Schema::Result::ClientTaskResult;

use base 'DBIx::Class::Core';
use utf8;
use common::sense;

__PACKAGE__->load_components(qw<>);
__PACKAGE__->table('client_task_result');
__PACKAGE__->add_columns(
  id             => { data_type => 'int', is_nullable => 0, is_auto_increment => 1 },
  client_task_id => { data_type => 'int', is_nullable => 0 },
  result         => { data_type => 'text', is_nullable => 0, default_value => '' },
);
__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(client_task => 'Vulture::Schema::Result::ClientTask',   'client_task_id');

1;
