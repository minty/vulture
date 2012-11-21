package Vulture::Schema::Result::Client;

use base 'DBIx::Class::Core';
use utf8;
use common::sense;

__PACKAGE__->load_components(qw<DateTime::Epoch TimeStamp>);
__PACKAGE__->table('client');
__PACKAGE__->add_columns(
  id                    => { data_type => 'int', is_nullable => 0, is_auto_increment => 1 },
  agent                 => { data_type => 'text', is_nullable => 0 },
  agent_device          => { data_type => 'text', is_nullable => 0, default_value => '' },
  agent_os              => { data_type => 'text', is_nullable => 0, default_value => '' },
  agent_browser         => { data_type => 'text', is_nullable => 0, default_value => '' },
  agent_browser_version => { data_type => 'text', is_nullable => 0, default_value => '' },
  agent_engine          => { data_type => 'text', is_nullable => 0, default_value => '' },
  ip                    => { data_type => 'text', is_nullable => 0 },
  app_id                => { data_type => 'text', is_nullable => 0 },
  client_id             => { data_type => 'text', is_nullable => 0 },
  joined_at             => { data_type => 'bigint', is_nullable => 0, inflate_datetime => 1, set_on_create => 1 },
  last_seen             => { data_type => 'bigint', is_nullable => 0, inflate_datetime => 1, set_on_create => 1 },
  active                => { data_type => 'char', size => 1, is_nullable => 0, default_value => 0 },
);
__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many(tasks => 'Vulture::Schema::Result::ClientTask', 'client_id');

1;
