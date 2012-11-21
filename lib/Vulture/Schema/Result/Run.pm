package Vulture::Schema::Result::Run;

use base 'DBIx::Class::Core';
use utf8;
use common::sense;

__PACKAGE__->load_components(qw<DateTime::Epoch TimeStamp>);
__PACKAGE__->table('run');
__PACKAGE__->add_columns(
  id          => { data_type => 'int', is_nullable => 0, is_auto_increment => 1 },
  task_id     => { data_type => 'int', is_nullable => 0 },
  created_at  => { data_type => 'bigint', inflate_datetime => 1, set_on_create => 1 },
  started_at  => { data_type => 'bigint', inflate_datetime => 1 },
  finished_at => { data_type => 'bigint', inflate_datetime => 1 },
  state       => { data_type => 'text', is_nullable => 0, default_value => 'pending' },
);
__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many(jobs => 'Vulture::Schema::Result::Job', 'run_id');

1;
