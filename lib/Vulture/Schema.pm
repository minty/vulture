package Vulture::Schema;

use base 'DBIx::Class::Schema';

use utf8;
use common::sense;

__PACKAGE__->load_namespaces;

# You can replace this text with custom code or comments, and it will be
# preserved on regeneration

# sugar
# $db->rs('Photo')
#   === $db->resultset('Photo')
# $db->rs(Photo => { col => 'val' }, { rows => 1 })
#   === $db->resultset('Photo')->search({ col => 'val' }, { rows => 1 })
sub rs {
    my ($self, $resultset_name, @args) = @_;
    my $rs = $self->resultset($resultset_name);
    return @args ? $rs->search_rs(@args) : $rs;
}

# sugar
# $db->rsfind(Photo => 123)
#   === $db->resultset('Photo')->find(123);
# $db->rsfind(Photo => { col => 'val' });
#   === $db->resultset('Photo')->find({ col => 'val' });
sub rsfind {
    my ($self, $resultset_name, $key, $attrs) = @_;
    my $rs = $self->resultset($resultset_name);
    $rs = $rs->search(undef, $attrs) if $attrs;
    return $rs->find($key);
}

1;
