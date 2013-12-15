use strict;
use utf8;

package PIT::internals;

package Dorq::internals;

use WWW::Mechanize ();

use Test::More ();

use URI ();

sub mech
{
	my $o = &Dorq::globalstate::get( 'mech' );

	unless( defined $o )
	{
		$o = &Dorq::globalstate::set( mech => WWW::Mechanize -> new() );
	}

	return $o;
}

-1;

