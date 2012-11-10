package Vulture::Schema::Result::ClientTask;

use base 'DBIx::Class::Core';
use utf8;
use common::sense;

__PACKAGE__->load_components(qw<DateTime::Epoch TimeStamp>);
__PACKAGE__->table('client_task');
__PACKAGE__->add_columns(
  id          => { data_type => 'int', is_nullable => 0, is_auto_increment => 1 },
  task_id     => { data_type => 'int', is_nullable => 0 },
  client_id   => { data_type => 'int', is_nullable => 0 },
  created_at  => { data_type => 'bigint', inflate_datetime => 1, set_on_create => 1 },
  started_at  => { data_type => 'bigint', inflate_datetime => 1 },
  finished_at => { data_type => 'bigint', inflate_datetime => 1 },
  state       => { data_type => 'text', is_nullable => 0, default_value => 'pending' },
  result      => { data_type => 'text' },
);
__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(task   => 'Vulture::Schema::Result::Task',   'task_id');
__PACKAGE__->belongs_to(client => 'Vulture::Schema::Result::Client', 'client_id');

1;