package Vulture::Schema::Result::JobResult;

use base 'DBIx::Class::Core';
use utf8;
use common::sense;

__PACKAGE__->load_components(qw<DateTime::Epoch TimeStamp>);
__PACKAGE__->table('job_result');
__PACKAGE__->add_columns(
  id        => { data_type => 'int', is_nullable => 0, is_auto_increment => 1 },
  epoch     => { data_type => 'bigint', is_nullable => 0, inflate_datetime => 1, set_on_create => 1 },
  job_id    => { data_type => 'int', is_nullable => 0 },
  state     => { data_type => 'text', is_nullable => 0 },
  count     => { data_type => 'int',  is_nullable => 0 },
  test_name => { data_type => 'text', is_nullable => 0 },
  result    => { data_type => 'text', is_nullable => 0, default_value => '' },
);
__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(job => 'Vulture::Schema::Result::Job',   'job_id');

1;
