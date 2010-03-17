#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'WWW::Mailman' );
}

diag( "Testing WWW::Mailman $WWW::Mailman::VERSION, Perl $], $^X" );
