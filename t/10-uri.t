use warnings;
use strict;
use Test::More;

use WWW::Mailman;

# generate all possible combinations
my @tests = map {
    my $u1 = my $u2
        = ( $_->{secure} ? 'https' : 'http' ) . '://'
        . $_->{userinfo}
        . ( $_->{userinfo} ? '@' : '' )
        . $_->{server}
        . ( $_->{prefix} ? '/' : '' )
        . $_->{prefix}
        . '/mailman';
    $u1 .= '/admin/' . $_->{list};
    $u2 .= '/listinfo/' . $_->{list};
    [ $u1 => { %$_, uri => $u2 } ]
    }
    map { ( { %$_, secure   => '' }, { %$_, secure   => 1 } ) }
    map { ( { %$_, prefix   => '' }, { %$_, prefix   => 'prefix' } ) }
    map { ( { %$_, userinfo => '' }, { %$_, userinfo => 'user:s3kr3t' } ) }
    { server => 'lists.example.com', list => 'example' };

my @fails = (
    [   'http://lists.example.com/' =>
            q{^Invalid URL !uri: no 'mailman' segment }
    ],
    [   'http://lists.example.com/mailman/' =>
            q{^Invalid URL !uri: no action }
    ],
);

my @attr = qw( secure server userinfo prefix list );

plan tests => ( @attr + 1 ) * @tests + 2 * @fails;

for my $test (@tests) {
    my ( $uri, $expected ) = @$test;
    my $m;

    # create from the parts and check the URI
    $m = WWW::Mailman->new();
    $m->$_( $expected->{$_} ) for grep { $expected->{$_} } @attr;
    is( $m->uri, $expected->{uri}, $expected->{uri} );

    # create from the URI and check the parts
    $m = WWW::Mailman->new();
    $m->uri($uri);
    for my $attr (@attr) {
        is( $m->$attr, $expected->{$attr}, "$attr for $uri" );
    }
}

for my $fail (@fails) {
    my ( $uri, $regexp ) = @$fail;
    $regexp =~ s/!uri/\Q$uri\E/;
    ok( !eval { WWW::Mailman->new( uri => $uri ); }, "new() fails for $uri" );
    like( $@, qr/$regexp/, 'Expected error message' );
}

