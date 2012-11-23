use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    PREREQ_PM => {
        'File::Slurp'                  => 0,
        'HTTP::BrowserDetect'          => 0,
        'JSON::XS'                     => 0,
        'JavaScript::Value::Escape'    => 0,
        'List::MoreUtils'              => 0,
        'Mojo::Base'                   => 0,
        'Mojo::IOLoop'                 => 0,
        'Mojo::UserAgent'              => 0,
        'Mojolicious::Commands'        => 0,
        'Path::Class::File'            => 0,
        'Text::Xslate::Bridge::TT2'    => 0,
        'URI'                          => 0,
        'DBIx::Class'                  => 0,
        'DBIx::Class::DateTime::Epoch' => 0,
        'common::sense'                => 0,
    },
);
