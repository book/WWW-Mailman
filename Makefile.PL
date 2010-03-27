use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'WWW::Mailman',
    AUTHOR              => 'Philippe Bruhat (BooK) <book@cpan.org>',
    VERSION_FROM        => 'lib/WWW/Mailman.pm',
    ABSTRACT_FROM       => 'lib/WWW/Mailman.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'WWW::Mechanize' => '1.00',
    },
    META_MERGE => {
        resources => {
            repository => 'http://github.com/book/WWW-Mailman',
        },
    },

    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-Mailman-*' },
);
