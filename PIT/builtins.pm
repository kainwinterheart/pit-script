use strict;
use utf8;

package PIT::builtins;

package Dorq::builtins;

sub agent
{
	return Dorq::code::block::builtin -> new( \sub
	{
		my $o = &Dorq::internals::mech();

		my $agent = $_[ 1 ] -> get( Dorq::var -> new( \(my $dummy = '$str' ) ) ) -> val() -> cast_string();

		$o -> agent( $agent -> val() );

		return $agent;
	} );
}

sub open
{
	return Dorq::code::block::builtin -> new( \sub
	{
		my $o = &Dorq::internals::mech();

		my $u = $_[ 1 ] -> get( Dorq::var -> new( \(my $dummy = '$url' ) ) ) -> val() -> cast_string() -> val();

		my $params_name = Dorq::var -> new( \(my $dummy = '$params' ) );

		if( $_[ 1 ] -> has( $params_name ) )
		{
			my $params = $_[ 1 ] -> get( $params_name ) -> val();

			die '$params should be a hash' unless $params -> isa( 'Dorq::hash' );

			my $uri = URI -> new( $u );

			my %params = $uri -> query_form();

			$params = &Dorq::internals::convert_Dorq_object_to_native_perl( $params );

			foreach my $key ( keys %$params )
			{
				$params{ $key } = $params -> { $key };
			}

			$uri -> query_form( %params );

			$u = $uri -> as_string();
		}

		$o -> get( $u );

		&Test::More::ok( $o -> success(), sprintf( 'get: %s', $u ) );

		return Dorq::type::undef -> new( \( my $dummy = undef ) );
	} );
}

sub plan
{
	return Dorq::code::block::builtin -> new( \sub
	{
		my $o = &Dorq::internals::mech();

		my $tests = $_[ 1 ] -> get( Dorq::var -> new( \(my $dummy = '$tests' ) ) ) -> val() -> cast_num() -> val();

		&Test::More::plan( tests => $tests );

		return Dorq::type::undef -> new( \( my $dummy = undef ) );
	} );
}

sub subtest
{
	return Dorq::code::block::builtin -> new( \sub
	{
		my $o = &Dorq::internals::mech();

		my $ctx = $_[ 1 ];
		my $name = $ctx -> get( Dorq::var -> new( \(my $dummy = '$name' ) ) ) -> val() -> cast_string() -> val();
		my $lambda = $ctx -> get( Dorq::var -> new( \(my $dummy = '$code' ) ) ) -> val();

		die '$code should be a lambda' unless $lambda -> isa( 'Dorq::lambda' );

		&Test::More::subtest( $name => sub{ $lambda -> call( $ctx ) } );

		return Dorq::type::undef -> new( \( my $dummy = undef ) );
	} );
}

sub submit_form
{
	return Dorq::code::block::builtin -> new( \sub
	{
		my $o = &Dorq::internals::mech();

		my $spec = $_[ 1 ] -> get( Dorq::var -> new( \(my $dummy = '$spec' ) ) ) -> val();
		my $desc = $_[ 1 ] -> get( Dorq::var -> new( \(my $dummy = '$descr' ) ) ) -> val() -> cast_string() -> val();

		die '$spec should be a hash' unless $spec -> isa( 'Dorq::hash' );

		my $h = &Dorq::internals::convert_Dorq_object_to_native_perl( $spec );

		$o -> submit_form( %$h );

		&Test::More::ok( $o -> success(), sprintf( 'form is submitted: %s', $desc ) );

		return Dorq::type::undef -> new( \( my $dummy = undef ) );
	} );
}

sub content_like
{
	return Dorq::code::block::builtin -> new( \sub
	{
		my $o = &Dorq::internals::mech();

		my $re = &Dorq::internals::du( $_[ 1 ] -> get( Dorq::var -> new( \(my $dummy = '$re' ) ) ) -> val() -> cast_string() -> val() );

		&Test::More::like( &Dorq::internals::du( $o -> content() ), qr/$re/, sprintf( 'content like: %s', &Dorq::internals::eu( $re ) ) );

		return Dorq::type::undef -> new( \( my $dummy = undef ) );
	} );
}

sub content_ilike
{
	return Dorq::code::block::builtin -> new( \sub
	{
		my $o = &Dorq::internals::mech();

		my $re = &Dorq::internals::du( $_[ 1 ] -> get( Dorq::var -> new( \(my $dummy = '$re' ) ) ) -> val() -> cast_string() -> val() );

		&Test::More::like( &Dorq::internals::du( $o -> content() ), qr/$re/i, sprintf( 'content ilike: %s', &Dorq::internals::eu( $re ) ) );

		return Dorq::type::undef -> new( \( my $dummy = undef ) );
	} );
}

-1;

