use warnings;
use strict;
use Test::More;

use WWW::Mailman;

my @tests = (
    [   'http://lists.example.com/mailman/admin/example/' => {
            uri    => 'http://lists.example.com/mailman/listinfo/example',
            secure => '',
            server => 'lists.example.com',
            prefix => '',
            list   => 'example',
        }
    ],
    [   'https://lists.example.com/mailman/admin/example/' => {
            uri    => 'https://lists.example.com/mailman/listinfo/example',
            secure => 1,
            server => 'lists.example.com',
            prefix => '',
            list   => 'example',
        }
    ],
    [   'http://lists.example.com/prefix/mailman/admin/example/' => {
            uri => 'http://lists.example.com/prefix/mailman/listinfo/example',
            secure => '',
            server => 'lists.example.com',
            prefix => 'prefix',
            list   => 'example',
        }
    ],
);

my @attr = qw( secure server prefix list );

plan tests => ( @attr + 1 ) * @tests;

for my $test (@tests) {
    my ( $uri, $expected ) = @$test;
    my $m;

    # create from the parts and check the URI
    $m = WWW::Mailman->new();
    $m->$_( $expected->{$_} ) for @attr;
    is( $m->uri, $expected->{uri}, $expected->{uri} );

    # create from the URI and check the parts
    $m = WWW::Mailman->new();
    $m->uri($uri);
    for my $attr (@attr) {
        is( $m->$attr, $expected->{$attr}, "$attr for $uri" );
    }
}
