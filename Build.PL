use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'WWW::Mailman',
    license             => 'perl',
    dist_author         => 'Philippe Bruhat (BooK) <book@cpan.org>',
    dist_version_from   => 'lib/WWW/Mailman.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'WWW::Mechanize' => '1.52',
    },
    meta_merge => {
        resources => {
            repository => 'http://github.com/book/WWW-Mailman',
        },
    },
    add_to_cleanup      => [ 'WWW-Mailman-*' ],
);

$builder->create_build_script();
