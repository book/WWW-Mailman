use strict;
use warnings;
use Test::More;
use WWW::Mailman;

my %option;

# To run these (hopefully) non-destructive tests against a Mailman account:

# either create a mailman_credentials file, with the following keys:
# - uri
# - email
# - password
# - admin_password
# - moderator_password
#
# The syntax being simply:
# key: value
my $credentials = 'mailman_credentials';
if ( -e $credentials ) {
    open my $fh, $credentials or die "Can't open $credentials: $!";
    /^(\w+):\s*(\S*)/ && ( $option{$1} = $2 ) while <$fh>;
}

# or create environment variables:
# - MAILMAN_URI
# - MAILMAN_EMAIL
# - MAILMAN_PASSWORD
# - MAILMAN_ADMIN_PASSWORD
# - MAILMAN_MODERATOR_PASSWORD
else {
    for my $key qw( uri email password admin_password moderator_password ) {
        my $env_key = uc "mailman_$key";
        $option{$key} = $ENV{$env_key} if exists $ENV{$env_key};
    }
}

plan skip_all => 'No credentials available for live tests'
    if !keys %option;

plan skip_all => 'Need at least a uri parameter for live tests'
    if !exists $option{uri};

plan tests => my $tests;

# some useful variables
my ( $mm, $url, $got, $expected, @subs );

# this is pure lazyness
sub mm {
    my $count = shift;
    exists $option{$_} || skip "Need '$_' for this test", $count for @_;
    WWW::Mailman->new( map { $_ => $option{$_} } 'uri', @_ );
}

# options() fails with no email
$mm = mm();
ok( !eval { $mm->options() }, 'options() fails with no credentials' );
$url = $mm->_uri_for('options');
like( $@, qr/Couldn't login on \Q$url\E/, 'Expected error message' );
BEGIN { $tests += 2 }

# options() fails with no password
$mm = mm();
$mm->email('user@example.com');
ok( !eval { $mm->options() }, 'options() fails with no password' );
$url = $mm->_uri_for( 'options', $mm->email );
like( $@, qr/Couldn't login on \Q$url\E/, 'Expected error message' );
BEGIN { $tests += 2 }

# options() for our user
SKIP: {
    $mm = mm( my $count, qw( email password ) );
    ok( eval { $got = $mm->options() }, 'options() with credentials' );
    is( ref $got, 'HASH', 'options returned as a HASH ref' );
    ok( exists $got->{$_}, "options have key '$_'" ) for my @keys;

    BEGIN {
        @keys = qw( fullname disablemail remind nodupes conceal );
        $tests += $count = @keys + 2;
    }
}

# try changing an option
SKIP: {
    $mm = mm( my $count, qw( email password ) );
    ok( eval { $got = $mm->options() }, 'options()' );
    my $new = ( my $old = $got->{conceal} ) ? '0' : '1';
    ok( eval { $got = $mm->options( { conceal => $new } ) },
        "options( { conceal => $new } ) passes" );
    is( $got->{conceal}, $new, "Changed the value of 'conceal' option" );
    ok( eval { $got = $mm->options( { conceal => $old } ) },
        "options( { conceal => $old } ) passes" );
    is( $got->{conceal}, $old, "Changed back the value of 'conceal' option" );
    BEGIN { $tests += $count = 5 }
}

# check other subscriptions
SKIP: {
    $mm = mm( my $count, qw( email password ) );
    ok( eval { @subs = $mm->othersubs(); 1 }, 'othersubs()' );
    cmp_ok( scalar @subs, '>=', 1, 'At least one subscription' );
    BEGIN { $tests += $count = 2 }
}

# check email resend
SKIP: {
    $mm = mm( my $count, qw( email ) );
    diag "You may receive password reminders for @{[$mm->list]}. Sorry.";
    ok( eval { $mm->emailpw(); 1 }, 'emailpw() without password' );
    BEGIN { $tests += $count = 1 }
}

SKIP: {
    $mm = mm( my $count, qw( email password ) );
    ok( eval { $mm->emailpw(); 1 }, 'emailpw()' );
    BEGIN { $tests += $count = 1 }
}

SKIP: {
    $mm = mm( my $count, qw( email password ) );
    ok( eval { $mm->options(); 1 }, 'login through options()' );
    ok( eval { $mm->emailpw(); 1 }, 'emailpw() when logged in' );
    BEGIN { $tests += $count = 2 }
}

