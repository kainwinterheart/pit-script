#!/usr/bin/perl

use strict;
use utf8;

BEGIN
{
	$SIG{ __DIE__ } = sub
	{
		require Carp;

		CORE::die &Carp::longmess( @_ );
	};
};

package pit::internals;

use WWW::Mechanize ();

use Test::More ();

use Scalar::Util 'blessed';

use Encode ( 'is_utf8', 'decode', 'encode' );

use URI ();

sub du
{
	my $s = shift;

	return ( is_utf8( $s ) ? $s : decode( 'UTF-8', $s ) );
}

sub eu
{
	my $s = shift;

	my $rv = is_utf8( $s ) ? encode( 'UTF-8', $s ) : $s;

	if( is_utf8( $rv ) )
	{
		utf8::downgrade( $rv );
	}

	return $rv;
}

sub mech
{
	my $o = &pit::globalstate::get( 'mech' );

	unless( defined $o )
	{
		$o = &pit::globalstate::set( mech => WWW::Mechanize -> new() );
	}

	return $o;
}

sub convert_pit_object_to_native_perl
{
	my $o = shift;

	if( blessed $o )
	{
		if( $o -> isa( 'pit::link' ) )
		{
			$o = $o -> val();
		}

		if( $o -> isa( 'pit::var' ) )
		{
			$o = $o -> val();
		}

		if( $o -> isa( 'pit::hash' ) )
		{
			return &pit::internals::convert_pit_hash_to_native_perl( $o );
		}

		if( $o -> isa( 'pit::array' ) )
		{
			return &pit::internals::convert_pit_array_to_native_perl( $o );
		}

		if( $o -> isa( 'pit::type' ) )
		{
			return $o -> val();
		}
	}

	return $o;
}

sub convert_pit_hash_to_native_perl
{
	my $in = shift;
	my %out = ();

	foreach my $key ( keys %{ $in -> val() } )
	{
		$out{ $key } = &pit::internals::convert_pit_object_to_native_perl( ${ $in -> { 'hash' } -> { $key } } );
	}

	return \%out;
}

sub convert_pit_array_to_native_perl
{
	my $in = shift -> val();
	my @out = ();
	my $cnt = scalar( @$in );

	for( my $i = 0; $i < $cnt; ++$i )
	{
		$out[ $i ] = &pit::internals::convert_pit_object_to_native_perl( ${ $in -> [ $i ] } );
	}

	return \@out;
}

sub clone
{
	my ( $i, $limit ) = @_;

	if( ++$limit > 10000 )
	{
		require Data::Dumper;

		die Data::Dumper::Dumper( $i );
	}

	if( blessed $i )
	{
		if( $i -> isa( 'pit::object' ) )
		{
			return $i -> clone( $limit );
		}

		return $i;
	}

	if( ref( $i ) eq 'HASH' )
	{
		return &pit::internals::clone_hash( $i, $limit );
	}

	if( ref( $i ) eq 'ARRAY' )
	{
		return &pit::internals::clone_array( $i, $limit );
	}

	if( ref( $i ) eq 'SCALAR' )
	{
		return &pit::internals::clone_scalar( $i, $limit );
	}

	return $i;
}

sub clone_hash
{
	my ( $i, $limit ) = @_;
	my %o = ();

	foreach my $key ( %$i )
	{
		$o{ $key } = &pit::internals::clone( $i -> { $key }, $limit );
	}

	return \%o;
}

sub clone_array
{
	my ( $i, $limit ) = @_;
	my @o = ();
	my $c = scalar( @$i );

	for( my $j = 0; $j < $c; ++$j )
	{
		$o[ $j ] = &pit::internals::clone( $i -> [ $j ], $limit );
	}

	return \@o;
}

sub clone_scalar
{
	my ( $i, $limit ) = @_;
	my $o = &pit::internals::clone( $$i, $limit );

	return \$o;
}

package pit::globalstate;

my %storage = ();

sub get
{
	return $storage{ +shift };
}

sub set
{
	my ( $key, $val ) = @_;

	return $storage{ $key } = $val;
}

package pit::object;

use Scalar::Util 'reftype';

sub new
{
	return bless( $_[ 1 ], ( ref( $_[ 0 ] ) or $_[ 0 ] ) );
}

sub clone
{
	my ( $self, $limit ) = @_;
	my $rt = reftype( $self );
	my $new = undef;

	if( $rt eq 'HASH' )
	{
		my %hash = %$self;

		$new = &pit::internals::clone( \%hash, $limit );

	} elsif( $rt eq 'ARRAY' )
	{
		my @array = @$self;

		$new = &pit::internals::clone( \@array, $limit );

	} else
	{
		my $value = $$self;

		$new = &pit::internals::clone( \$value, $limit );
	}

	return bless( $new, ( ref( $self ) or $self ) );
}

sub public { [] }

sub call_public_method
{
	my ( $self, $method, @args ) = @_;

	foreach my $m ( @{ $self -> public() } )
	{
		if( $m eq $method )
		{
			return $self -> $m( @args );
		}
	}

	die sprintf( '%s has no such method: %s', ref( $self ), $method );
}

package pit::context;

use base 'pit::object';

sub new
{
	return $_[ 0 ] -> SUPER::new( { parent => $_[ 1 ] } );
}

sub add
{
	$_[ 0 ] -> { 'data' } -> { $_[ 1 ] -> name() } = \$_[ 1 ];
# print "CADD\n";
#print &Data::Dumper::Dumper( $_[ 0 ] . '' );
	return $_[ 0 ] -> get( $_[ 1 ] );
}

sub has
{
	if( exists $_[ 0 ] -> { 'data' } -> { $_[ 1 ] -> name() } )
	{
		return 1;
	}

	if( my $p = $_[ 0 ] -> { 'parent' } )
	{
		return $p -> has( $_[ 1 ] );
	}
}

sub get
{
	if( exists $_[ 0 ] -> { 'data' } -> { $_[ 1 ] -> name() } )
	{
		return ${ $_[ 0 ] -> { 'data' } -> { $_[ 1 ] -> name() } };
	}

	if( my $p = $_[ 0 ] -> { 'parent' } )
	{
		return $p -> get( $_[ 1 ] );
	}

	die 'Unexistent entity: ' . $_[ 1 ] -> name();
}

sub vars
{
	return map{ pit::var -> new( \$_ ) } keys %{ $_[ 0 ] -> { 'data' } };
}

sub localize
{
	my $self = shift;

	if( defined( my $parent = $self -> { 'parent' } ) )
	{
		$self -> { 'parent' } = undef;

		foreach my $name ( $parent -> vars() )
		{
			unless( $self -> has( $name ) )
			{
				$self -> add( $parent -> get( $name ) );
			}
		}
	}

	return 1;
}

package pit::type;

use base 'pit::object';

sub val
{
	return ${ +shift };
}

package pit::type::undef;

use base 'pit::type';

sub val
{
	return 'undef';
}

package pit::link;

use base 'pit::object';

sub relink
{
	my ( $val, $code ) = @_;

	my @all  = ();
	my %seen = ();

	while( $val -> isa( 'pit::link' ) )
	{
		die 'Loophole' if $seen{ $val } ++;
		push @all, $val;
		$val = $$val -> ();
	}

	foreach my $link ( @all )
	{
		$$link = $$code;
	}

	return 1;
}

sub val
{
	my $val  = shift;
	my %seen = ();

	while( $val -> isa( 'pit::link' ) )
	{
		die 'Loophole' if $seen{ $val } ++;

		$val = $$val -> ();
	}

	return $val;
}

package pit::code;

use base 'pit::type';

use Scalar::Util 'blessed';

sub exec
{
	my $tokens  = shift -> val();
	return unless scalar ( @$tokens ) > 0;
	my $context = shift;
#	$context = $$context if ref $context and not blessed $context;
# print "CTX: $context\n";
#	my @output  = ();
#die &Data::Dumper::Dumper($tokens) if scalar @$tokens > 2;

	my $highest_op_lvl = 0;
	my $has_ops        = 0;

# print &Data::Dumper::Dumper($tokens);
	for( my $i = 0; $i < scalar( @$tokens ); ++$i )
	{
		my $token = $tokens -> [ $i ];

#		unless( $token )
#		{
#			$tokens -> [ $i ] = $token = pit::type::undef -> new( \( my $dummy = undef ) );
#		}

# print &Data::Dumper::Dumper($tokens)."\n";
		if( $token -> isa( 'pit::code' ) )
		{
			$tokens -> [ $i ] = $token -> exec( $context );

		} elsif( $token -> isa( 'pit::decl' ) )
		{
			$tokens -> [ $i ] = $token -> exec( $i, $tokens, $context );

		} elsif( $token -> isa( 'pit::var' ) )
		{
			$tokens -> [ $i ] = $context -> get( $token );

		} elsif( $token -> isa( 'pit::function' ) )
		{
			$tokens -> [ $i ] = $token -> exec( $i, $tokens, $context );

		} elsif( $token -> isa( 'pit::op' ) )
		{
			$has_ops = 1;

			if( $highest_op_lvl < ( my $prio = $token -> prio() ) )
			{
				$highest_op_lvl = $prio;
			}
		}
	}

	my $highest_op_lvl_is_set = 1;

#die &Data::Dumper::Dumper($tokens) if scalar @$tokens > 2;
#	print &Data::Dumper::Dumper( [ 'mid result', $tokens ] ) . "\n";
# print &Data::Dumper::Dumper($tokens)."\n";
	while( $has_ops )
	{
		$has_ops = 0;

		for( my $i = 0; $i < scalar( @$tokens ); ++$i )
		{
			my $token = $tokens -> [ $i ];

#			unless( $token )
#			{
#				$tokens -> [ $i ] = $token = pit::type::undef -> new( \( my $dummy = undef ) );
#die &Data::Dumper::Dumper($tokens)."\n";
#			}

# print &Data::Dumper::Dumper($tokens)."\n";
			if( $token -> isa( 'pit::op' ) )
			{
				$has_ops = 1;

				if( $highest_op_lvl_is_set )
				{
					if( $token -> prio() == $highest_op_lvl )
					{
						# print &Data::Dumper::Dumper( [ 'exec', $tokens, $token ] ) . "\n";
						$tokens -> [ $i ] = $token -> exec( $i, $tokens, $context );
					}
					else
					{
						# print &Data::Dumper::Dumper( [ 'skip', $tokens, $token ] ) . "\n";
					}
				} else
				{
						# print &Data::Dumper::Dumper( [ 'scan', $tokens, $token ] ) . "\n";
					if( $highest_op_lvl < ( my $prio = $token -> prio() ) )
					{
						$highest_op_lvl = $prio;
						# print &Data::Dumper::Dumper( [ 'scan ok', $tokens, $token ] ) . "\n";
					}
				}
			}
		}

		unless( $highest_op_lvl_is_set = not $highest_op_lvl_is_set )
		{
			$highest_op_lvl = 0;
		}
	}
	# print &Data::Dumper::Dumper( [ 'result', $tokens ] ) . "\n";
# die &Data::Dumper::Dumper($tokens) if scalar @$tokens > 2;
# die &Data::Dumper::Dumper($context) if scalar @$tokens > 2;
	return $tokens -> [ $#$tokens ];
#print &Data::Dumper::Dumper( \@output )."\n";
# print &Data::Dumper::Dumper( $tokens )."\n";
#print &Data::Dumper::Dumper($context)."\n";
#die &Data::Dumper::Dumper($tokens) if scalar @$tokens > 2;
#	return ( ( scalar( @output ) > 1 ) ? pit::code -> new( \\@output ) -> exec( $context ) : ( ( scalar( @output ) == 1 ) ? shift( @output ) : pop( @$tokens ) ) );
}

sub make_recompillable
{
	my $codes = shift -> val();
	my @codes = ();

	foreach my $token ( @$codes )
	{
		my $new_token = $token;

		if( $new_token -> isa( 'pit::code' ) and not $new_token -> isa( 'pit::code::recompillable' ) )
		{
			$new_token = $new_token -> make_recompillable();
		}

		push @codes, $new_token;
	}

	return pit::code::recompillable -> new( \\@codes );
}

package pit::code::recompillable;

use base 'pit::code';

sub make_recompillable
{
	return shift;
}

sub exec
{
	my ( $self, @rest ) = @_;

	my $tokens = &pit::internals::clone( $self -> val() );

	return pit::code -> new( \$tokens ) -> exec( @rest );
}

package pit::code::block;

use base 'pit::code';

sub make_recompillable
{
	my $self  = shift;
	my $codes = $self -> val();

	foreach my $token ( @$codes )
	{
		if( $token -> isa( 'pit::code' ) and not $token -> isa( 'pit::code::recompillable' ) )
		{
			$token = $token -> make_recompillable();
		}
	}

	return $self;
}

sub exec
{
	my $codes   = shift -> val();
	my $context = shift;
	my $do_not_swap_context = shift;
	my @output  = ();

	$context = pit::context -> new( $context ) unless $do_not_swap_context;

	foreach my $code ( @$codes )
	{
#print &Data::Dumper::Dumper($code,$r)."\n";
		push @output, $code -> exec( $context );
	}
return pop @output;
#	return ( ( scalar( @output ) > 1 ) ? pit::code::block -> new( \\@output ) -> exec( $context ) : shift( @output ) );
}

package pit::code::block::hash_initializer;

use base 'pit::code::block';

use Scalar::Util 'refaddr';

sub exec
{
	my $codes   = shift -> val();
	my $context = shift;
	my $do_not_swap_context = shift;
	my @output  = ();

	$context = pit::context -> new( $context ) unless $do_not_swap_context;

	foreach my $code ( @$codes )
	{
#print &Data::Dumper::Dumper($code,$r)."\n";
		push @output, $code -> exec( $context );
	}

	my @dereferenced_output = ();
	my %seen = ();

	my $cnt = 0;

	while( defined( my $node = shift @output ) )
	{
		next if $seen{ refaddr( $node ) } ++;

		if( $node -> isa( 'pit::link' ) )
		{
			$node = $node -> val();

			next if $seen{ refaddr( $node ) } ++;
		}

		if( ( $cnt % 2 ) == 0 )
		{
			$node = $node -> cast_string() -> val();

		} else
		{
			$node = \( my $dummy = $node );
		}

		push @dereferenced_output, $node;

		++$cnt;
	}

	if( ( $cnt % 2 ) == 0 )
	{
		return pit::hash -> new( { @dereferenced_output } );
	}

	die 'even number of elements in hash initializer';
}

package pit::code::block::array_initializer;

use base 'pit::code::block';

use Scalar::Util 'refaddr';

sub exec
{
	my $codes   = shift -> val();
	my $context = shift;
	my $do_not_swap_context = shift;
	my @output  = ();

	$context = pit::context -> new( $context ) unless $do_not_swap_context;

	foreach my $code ( @$codes )
	{
#print &Data::Dumper::Dumper($code,$r)."\n";
		push @output, $code -> exec( $context );
	}

	my @dereferenced_output = ();
	my %seen = ();

	while( defined( my $node = shift @output ) )
	{
		next if $seen{ refaddr( $node ) } ++;

		if( $node -> isa( 'pit::link' ) )
		{
			$node = $node -> val();

			next if $seen{ refaddr( $node ) } ++;
		}

		push @dereferenced_output, \$node;
	}

	return pit::array -> new( \@dereferenced_output );
}

package pit::parens::open;

use base 'pit::object';

package pit::parens::close;

use base 'pit::object';

package pit::builtins;

sub print
{
	return pit::code::block::builtin -> new( \sub
	{
		print $_[ 1 ] -> get( pit::var -> new( \(my $dummy = '$str' ) ) ) -> val() -> cast_string() -> val();

		return pit::type::undef -> new( \( my $dummy = undef ) );
	} );
}

sub E
{
	return pit::code::block::builtin -> new( \sub
	{
		return pit::type::string -> new( \( my $dummy = eval( 'qq{' . $_[ 1 ] -> get( pit::var -> new( \(my $dummy = '$str' ) ) ) -> val() -> cast_string() -> val() .'}' ) ) );
	} );
}

sub Dump
{
	return pit::code::block::builtin -> new( \sub
	{
		require Data::Dumper;

		print Data::Dumper::Dumper( $_[ 1 ] -> get( pit::var -> new( \(my $dummy = '$val' ) ) ) -> val() ), "\n";

		return pit::type::undef -> new( \( my $dummy = undef ) );
	} );
}

sub agent
{
	return pit::code::block::builtin -> new( \sub
	{
		my $o = &pit::internals::mech();

		my $agent = $_[ 1 ] -> get( pit::var -> new( \(my $dummy = '$str' ) ) ) -> val() -> cast_string();

		$o -> agent( $agent -> val() );

		return $agent;
	} );
}

sub open
{
	return pit::code::block::builtin -> new( \sub
	{
		my $o = &pit::internals::mech();

		my $u = $_[ 1 ] -> get( pit::var -> new( \(my $dummy = '$url' ) ) ) -> val() -> cast_string() -> val();

		my $params_name = pit::var -> new( \(my $dummy = '$params' ) );

		if( $_[ 1 ] -> has( $params_name ) )
		{
			my $params = $_[ 1 ] -> get( $params_name ) -> val();

			die '$params should be a hash' unless $params -> isa( 'pit::hash' );

			my $uri = URI -> new( $u );

			my %params = $uri -> query_form();

			$params = &pit::internals::convert_pit_object_to_native_perl( $params );

			foreach my $key ( keys %$params )
			{
				$params{ $key } = $params -> { $key };
			}

			$uri -> query_form( %params );

			$u = $uri -> as_string();
		}

		$o -> get( $u );

		&Test::More::ok( $o -> success(), sprintf( 'get: %s', $u ) );

		return pit::type::undef -> new( \( my $dummy = undef ) );
	} );
}

sub plan
{
	return pit::code::block::builtin -> new( \sub
	{
		my $o = &pit::internals::mech();

		my $tests = $_[ 1 ] -> get( pit::var -> new( \(my $dummy = '$tests' ) ) ) -> val() -> cast_num() -> val();

		&Test::More::plan( tests => $tests );

		return pit::type::undef -> new( \( my $dummy = undef ) );
	} );
}

sub subtest
{
	return pit::code::block::builtin -> new( \sub
	{
		my $o = &pit::internals::mech();

		my $ctx = $_[ 1 ];
		my $name = $ctx -> get( pit::var -> new( \(my $dummy = '$name' ) ) ) -> val() -> cast_string() -> val();
		my $lambda = $ctx -> get( pit::var -> new( \(my $dummy = '$code' ) ) ) -> val();

		die '$code should be a lambda' unless $lambda -> isa( 'pit::lambda' );

		&Test::More::subtest( $name => sub{ $lambda -> call( $ctx ) } );

		return pit::type::undef -> new( \( my $dummy = undef ) );
	} );
}

sub submit_form
{
	return pit::code::block::builtin -> new( \sub
	{
		my $o = &pit::internals::mech();

		my $spec = $_[ 1 ] -> get( pit::var -> new( \(my $dummy = '$spec' ) ) ) -> val();
		my $desc = $_[ 1 ] -> get( pit::var -> new( \(my $dummy = '$descr' ) ) ) -> val() -> cast_string() -> val();

		die '$spec should be a hash' unless $spec -> isa( 'pit::hash' );

		my $h = &pit::internals::convert_pit_object_to_native_perl( $spec );

		$o -> submit_form( %$h );

		&Test::More::ok( $o -> success(), sprintf( 'form is submitted: %s', $desc ) );

		return pit::type::undef -> new( \( my $dummy = undef ) );
	} );
}

sub content_like
{
	return pit::code::block::builtin -> new( \sub
	{
		my $o = &pit::internals::mech();

		my $re = &pit::internals::du( $_[ 1 ] -> get( pit::var -> new( \(my $dummy = '$re' ) ) ) -> val() -> cast_string() -> val() );

		&Test::More::like( &pit::internals::du( $o -> content() ), qr/$re/, sprintf( 'content like: %s', &pit::internals::eu( $re ) ) );

		return pit::type::undef -> new( \( my $dummy = undef ) );
	} );
}

sub content_ilike
{
	return pit::code::block::builtin -> new( \sub
	{
		my $o = &pit::internals::mech();

		my $re = &pit::internals::du( $_[ 1 ] -> get( pit::var -> new( \(my $dummy = '$re' ) ) ) -> val() -> cast_string() -> val() );

		&Test::More::like( &pit::internals::du( $o -> content() ), qr/$re/i, sprintf( 'content ilike: %s', &pit::internals::eu( $re ) ) );

		return pit::type::undef -> new( \( my $dummy = undef ) );
	} );
}

package pit::code::block::builtin;

use base 'pit::code::block';

sub exec
{
	return shift -> val() -> ( @_ );
}

package pit::code::block::custom;

use base 'pit::code::block';

sub new
{
	return $_[ 0 ] -> SUPER::new( { name => $_[ 1 ], value => $_[ 2 ] } );
}

sub val
{
	return ${ $_[ 0 ] -> { 'value' } };
}

sub name
{
	return $_[ 0 ] -> { 'name' };
}

sub exec
{
	return shift -> val() -> ( @_ );
}

package pit::function;

use base 'pit::object';

sub name
{
	return ${ +shift };
}

sub exec
{
	my $pos     = $_[ 1 ];
	my $tokens  = $_[ 2 ];
	my $context = $_[ 3 ];

	my $var = $tokens -> [ $pos + 1 ];

	my $body = ( $context -> has( $_[ 0 ] ) ? $context -> get( $_[ 0 ] ) : do{ my $n = 'pit::builtins::' . $_[ 0 ] -> name(); ( \&$n ) -> (); } );

	if( $var -> isa( 'pit::code' ) and $body -> isa( 'pit::code::block' ) )
	{
		my $context = pit::context -> new( $context );

# die &Data::Dumper::Dumper( $var );
# print &Data::Dumper::Dumper( $context );
		$var -> exec( $context, ( $var -> isa( 'pit::code::block' ) ? 1 : () ) );
# die &Data::Dumper::Dumper( $context );
#		$context -> localize();
# print &Data::Dumper::Dumper( $context );

		my $result = $body -> exec( $context );

		$tokens -> [ $pos + 1 ] = pit::link -> new( \sub{ $tokens -> [ $pos ] } );

		return $tokens -> [ $pos ] = pit::link -> new( \sub{ $result } );
	}

	die sprintf( 'Ivalid function call: %s( %s )', $body, $var );
}

package pit::method::call;

use base 'pit::function';

sub exec
{
	substr( ( my $name = $_[ 0 ] -> name() ), 0, 1 ) = "";

	my $pos     = $_[ 1 ];
	my $tokens  = $_[ 2 ];
	my $context = $_[ 3 ];

	my $obj = $tokens -> [ $pos - 1 ];
	my $var = $tokens -> [ $pos + 1 ];

	if( $obj -> isa( 'pit::link' ) )
	{
		my $ovar = $obj;
		$obj = $obj -> val();
		$ovar -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

	if( $obj -> isa( 'pit::var' ) )
	{
		$obj = $obj -> val();
	}

	if( $var -> isa( 'pit::link' ) )
	{
		my $ovar = $var;
		$var = $var -> val();
		$ovar -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

	if( $obj -> isa( 'pit::object' ) and $var -> isa( 'pit::code::block' ) )
	{
		$context = pit::context -> new( $context );

		$var -> exec( $context, 1 );

		$tokens -> [ $pos - 1 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos - 1 ] -> isa( 'pit::link' );
		$tokens -> [ $pos + 1 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos + 1 ] -> isa( 'pit::link' );

		my $result = $obj -> call_public_method( $name, $context );

		return $tokens -> [ $pos ] = pit::link -> new( \sub{ $result } );
	}

	die sprintf( 'Cannot exucute method: invalid token sequence ( %s.%s(%s) )', $obj, $name, $var );
}

package pit::var;

use base 'pit::object';

use Scalar::Util 'blessed';

sub new
{
	return $_[ 0 ] -> SUPER::new( { name => $_[ 1 ] } );
}

sub name
{
	return ${ $_[ 0 ] -> { 'name' } };
}

sub val
{
	unless( exists $_[ 0 ] -> { 'value' } )
	{
		$_[ 0 ] -> { 'value' } = \( my $dummy2 = pit::type::undef -> new( \( my $dummy = undef ) ) );
	}
#require Carp;
#&Carp::cluck( &Data::Dumper::Dumper( $_[ 0 ] ) );
	return ${ $_[ 0 ] -> { 'value' } };
}

sub set_val
{
	die 'Unknown value: ' . $_[ 1 ] unless blessed( $_[ 1 ] ) and $_[ 1 ] -> isa( 'pit::object' );

	$_[ 0 ] -> { 'value' } = \$_[ 1 ];

	return $_[ 0 ] -> val();
}

sub op_assign
{
	return $_[ 0 ] -> set_val( $_[ 1 ] );
}

package pit::lambda;

use base 'pit::type';

use Scalar::Util 'blessed';

sub new
{
	return $_[ 0 ] -> SUPER::new( { code => ( $_[ 1 ] || sub{} ) } );
}

sub public
{
	return [
		'call'
	];
}

sub val
{
	return shift -> { 'code' };
}

sub call
{
	my ( $self, $context ) = @_;

	return $self -> val() -> ( $context );
}

package pit::hash;

use base 'pit::type';

use Scalar::Util 'blessed';

sub new
{
	return $_[ 0 ] -> SUPER::new( { hash => ( $_[ 1 ] || {} ) } );
}

sub public
{
	return [
		'get',
		'set',
		'keys',
		'values',
		'exists',
		'delete'
	];
}

sub val
{
	return shift -> { 'hash' };
}

sub keys
{
	my $self = shift;

	my @out = ();

	foreach my $key ( CORE::keys %{ $self -> { 'hash' } } )
	{
		push @out, \( my $dummy = pit::type::string -> new( \$key ) );
	}

	return pit::array -> new( \@out );
}

sub values
{
	my $self = shift;

	return pit::array -> new( [ CORE::values %{ $self -> { 'hash' } } ] );
}

sub set
{
	my ( $self, $context ) = @_;

	my $ikey = $context -> get( pit::var -> new( \(my $dummy = '$key' ) ) ) -> val() -> cast_string();
	my $ival = $context -> get( pit::var -> new( \(my $dummy = '$val' ) ) ) -> val();

	die sprintf( 'unknown key: %s', $ikey ) unless $ikey -> isa( 'pit::type::string' );
	die sprintf( 'unknown val: %s', $ival ) unless $ival -> isa( 'pit::object' );

	return ${ $self -> { 'hash' } -> { $ikey -> val() } = \$ival };
}

sub exists
{
	my ( $self, $context ) = @_;

	my $ikey = $context -> get( pit::var -> new( \(my $dummy = '$key' ) ) ) -> val() -> cast_string();

	die sprintf( 'unknown key: %s', $ikey ) unless $ikey -> isa( 'pit::type::string' );

	return pit::type::bool -> new( \( my $dummy = ( CORE::exists $self -> { 'hash' } -> { $ikey -> val() } ) ) );
}

sub get
{
	my ( $self, $context ) = @_;

	my $ikey = $context -> get( pit::var -> new( \(my $dummy = '$key' ) ) ) -> val() -> cast_string();

	die sprintf( 'unknown key: %s', $ikey ) unless $ikey -> isa( 'pit::type::string' );

	my $key_str = $ikey -> val();

	if( CORE::exists $self -> { 'hash' } -> { $key_str } )
	{
		return ${ $self -> { 'hash' } -> { $key_str } };
	}

	die sprintf( 'key does not exists: %s', $key_str );
}

sub delete
{
	my ( $self, $context ) = @_;

	my $ikey = $context -> get( pit::var -> new( \(my $dummy = '$key' ) ) ) -> val() -> cast_string();

	die sprintf( 'unknown key: %s', $ikey ) unless $ikey -> isa( 'pit::type::string' );

	my $key_str = $ikey -> val();

	if( CORE::exists $self -> { 'hash' } -> { $key_str } )
	{
		return ${ delete $self -> { 'hash' } -> { $key_str } };
	}

	die sprintf( 'key does not exists: %s', $key_str );
}

package pit::array;

use base 'pit::type';

use Scalar::Util 'blessed';

sub new
{
	return $_[ 0 ] -> SUPER::new( { list => ( $_[ 1 ] || [] ) } );
}

sub public
{
	return [
		'push',
		'unshift',
		'size',
		'shift',
		'pop',
		'get',
		'set',
		'each'
	];
}

sub val
{
	return shift -> { 'list' };
}

sub push
{
	my ( $self, $context ) = @_;

	my @els   = ();
	my $input = $context -> get( pit::var -> new( \(my $dummy = '$list' ) ) ) -> val();

	die 'input should be an array' unless $input -> isa( 'pit::array' );

	foreach( @{ $input -> { 'list' } } )
	{
		die 'Unknown value: ' . ${ $_ } unless blessed( ${ $_ } ) and ${ $_ } -> isa( 'pit::object' );

		CORE::push @els, $_;
	}

	CORE::push @{ $self -> { 'list' } }, @els;

	return;
}

sub unshift
{
	my ( $self, $context ) = @_;

	my @els   = ();
	my $input = $context -> get( pit::var -> new( \(my $dummy = '$list' ) ) ) -> val();

	die 'input should be an array' unless $input -> isa( 'pit::array' );

	foreach( @{ $input -> { 'list' } } )
	{
		die 'Unknown value: ' . ${ $_ } unless blessed( ${ $_ } ) and ${ $_ } -> isa( 'pit::object' );

		CORE::push @els, $_;
	}

	CORE::unshift @{ $self -> { 'list' } }, @els;

	return;
}

sub size
{
	return scalar( @{ $_[ 0 ] -> { 'list' } } );
}

sub shift
{
	my $self = shift;

	if( $self -> size() > 0 )
	{
		return ${ CORE::shift @{ $self -> { 'list' } } };
	}

	return pit::type::undef -> new( \( my $dummy = undef ) );
}

sub pop
{
	my $self = shift;

	if( $self -> size() > 0 )
	{
		return ${ CORE::pop @{ $self -> { 'list' } } };
	}

	return pit::type::undef -> new( \( my $dummy = undef ) );
}

sub set
{
	my ( $self, $context ) = @_;

	my $iidx = $context -> get( pit::var -> new( \(my $dummy = '$idx' ) ) ) -> val() -> cast_num();
	my $ival = $context -> get( pit::var -> new( \(my $dummy = '$val' ) ) ) -> val();

	die sprintf( 'unknown index: %s', $iidx ) unless $iidx -> isa( 'pit::type::num' );
	die sprintf( 'unknown value: %s', $ival ) unless $ival -> isa( 'pit::object' );

	return ${ $self -> { 'list' } -> [ $iidx -> val() ] = \$ival };
}

sub get
{
	my ( $self, $context ) = @_;

	my $iidx = $context -> get( pit::var -> new( \(my $dummy = '$idx' ) ) ) -> val() -> cast_num();

	die sprintf( 'unknown index: %s', $iidx ) unless $iidx -> isa( 'pit::type::num' );

	my $idx_num = $iidx -> val();
	my $size    = $self -> size();

	if(
		(
			( $idx_num >= 0 ) and
			( $idx_num < $size )
		) or
		(
			( $idx_num < 0 ) and
			( $idx_num >= ( $size * -1 ) )
		)
	)
	{
		return ${ $self -> { 'list' } -> [ $idx_num ] };
	}

	die sprintf( 'invalid index: %d', $idx_num );
}

sub each
{
	my ( $self, $context ) = @_;

	my $ilambda = $context -> get( pit::var -> new( \(my $dummy = '$code' ) ) ) -> val();

	die sprintf( 'unknown code: %s', $ilambda ) unless $ilambda -> isa( 'pit::lambda' );

	my $local_context = pit::context -> new( $context );

	foreach my $_el ( @{ $self -> { 'list' } } )
	{
		my $el = pit::var -> new( \( my $dummy = '$element' ) );

		$el -> set_val( ${ $_el } );

		$local_context -> add( $el );

		$ilambda -> call( $local_context );
	}

	return;
}

package pit::decl;

use base 'pit::object';

package pit::decl::var;

use base 'pit::decl';

sub new
{
	my $val = $_[ 0 ] -> SUPER::new( $_[ 1 ] );

#	use Data::Dumper 'Dumper';
#	print Dumper( $val ) . "\n";

	return $val;
}

sub exec
{
	my $pos     = $_[ 1 ];
	my $tokens  = $_[ 2 ];
	my $context = $_[ 3 ];

	my $var = $tokens -> [ $pos + 1 ];

	if( $var -> isa( 'pit::link' ) )
	{
		my $ovar = $var;
		$var = $var -> val();
		$ovar -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

	if( $var -> isa( 'pit::var' ) )
	{
		$context -> add( $var );

		$tokens -> [ $pos + 1 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos + 1 ] -> isa( 'pit::link' );

		return $tokens -> [ $pos ] = pit::link -> new( \sub{ $context -> get( $var ) } );
	}

	die 'Cannot add to context: ' . $var;
}

package pit::decl::lambda;

use base 'pit::decl';

sub new
{
	my $val = $_[ 0 ] -> SUPER::new( $_[ 1 ] );

#	use Data::Dumper 'Dumper';
#	print Dumper( $val ) . "\n";

	return $val;
}

sub exec
{
	my $pos     = $_[ 1 ];
	my $tokens  = $_[ 2 ];
	my $context = $_[ 3 ];

	my $var = $tokens -> [ $pos + 1 ];

	if( $var -> isa( 'pit::link' ) )
	{
		my $ovar = $var;
		$var = $var -> val();
		$ovar -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

	if( $var -> isa( 'pit::code::block' ) )
	{
		$var -> make_recompillable();

		$tokens -> [ $pos + 1 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos + 1 ] -> isa( 'pit::link' );

#		my $outer_def = pit::code::block::custom -> new( 'outer', \sub{ $context -> get( pit::var -> new( \( $_[ 1 ] -> get( pit::var -> new( \(my $dummy = '$name' ) ) ) -> val() -> cast_string() -> val() ) ) ) -> val() } );

		my $o = pit::lambda -> new( sub
		{
			my $local_context = pit::context -> new( shift @_ );

#			$local_context -> add( $outer_def );

# use Data::Dumper 'Dumper';
# print Dumper( $var ), "\n";

			return $var -> exec( $local_context, 1 );
		} );

		return $tokens -> [ $pos ] = pit::link -> new( \sub{ $o } );
	}

	die 'Cannot initialize array: ' . $var;
}

package pit::decl::hash;

use base 'pit::decl';

sub new
{
	my $val = $_[ 0 ] -> SUPER::new( $_[ 1 ] );

#	use Data::Dumper 'Dumper';
#	print Dumper( $val ) . "\n";

	return $val;
}

sub exec
{
	my $pos     = $_[ 1 ];
	my $tokens  = $_[ 2 ];
	my $context = $_[ 3 ];

	my $var = $tokens -> [ $pos + 1 ];

	if( $var -> isa( 'pit::link' ) )
	{
		my $ovar = $var;
		$var = $var -> val();
		$ovar -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

	if( $var -> isa( 'pit::code::block' ) and not $var -> isa( 'pit::code::block::hash_initializer' ) )
	{
		$var = pit::code::block::hash_initializer -> new(
			\( $var -> val() )
		);
	}

	if( $var -> isa( 'pit::code::block::hash_initializer' ) )
	{
		$var = $var -> exec( $context, 1 );
	}

	if( $var -> isa( 'pit::hash' ) )
	{
		$tokens -> [ $pos + 1 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos + 1 ] -> isa( 'pit::link' );

		return $tokens -> [ $pos ] = pit::link -> new( \sub{ $var } );
	}

	die 'Cannot initialize array: ' . $var;
}

package pit::decl::array;

use base 'pit::decl';

sub new
{
	my $val = $_[ 0 ] -> SUPER::new( $_[ 1 ] );

#	use Data::Dumper 'Dumper';
#	print Dumper( $val ) . "\n";

	return $val;
}

sub exec
{
	my $pos     = $_[ 1 ];
	my $tokens  = $_[ 2 ];
	my $context = $_[ 3 ];

	my $var = $tokens -> [ $pos + 1 ];

	if( $var -> isa( 'pit::link' ) )
	{
		my $ovar = $var;
		$var = $var -> val();
		$ovar -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

	if( $var -> isa( 'pit::code::block' ) and not $var -> isa( 'pit::code::block::array_initializer' ) )
	{
		$var = pit::code::block::array_initializer -> new(
			\( $var -> val() )
		);
	}

	if( $var -> isa( 'pit::code::block::array_initializer' ) )
	{
		$var = $var -> exec( $context, 1 );

	}

	if( $var -> isa( 'pit::array' ) )
	{
		$tokens -> [ $pos + 1 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos + 1 ] -> isa( 'pit::link' );

		return $tokens -> [ $pos ] = pit::link -> new( \sub{ $var } );
	}

	die 'Cannot initialize array: ' . $var;
}

package pit::decl::fun;

use base 'pit::decl';

sub new
{
	my $val = $_[ 0 ] -> SUPER::new( $_[ 1 ] );

#	use Data::Dumper 'Dumper';
#	print Dumper( $val ) . "\n";

	return $val;
}

sub exec
{
	my $pos     = $_[ 1 ];
	my $tokens  = $_[ 2 ];
	my $context = $_[ 3 ];

	my $name = $tokens -> [ $pos + 1 ];
	my $code = $tokens -> [ $pos + 2 ];

	if( $name -> isa( 'pit::link' ) )
	{
		my $oname = $name;
		$name = $name -> val();
		$oname -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

	if( $code -> isa( 'pit::link' ) )
	{
		my $ocode = $code;
		$code = $code -> val();
		$ocode -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

	if( $name -> isa( 'pit::function' ) and $code -> isa( 'pit::code::block' ) )
	{
		my $var = $code;

		unless( $var -> isa( 'pit::code::block::custom' ) )
		{
			$var -> make_recompillable();

			$var = pit::code::block::custom -> new( $name -> name(), \sub{ shift; $code -> exec( @_ ) } );
		}

		$context -> add( $var );

		$tokens -> [ $pos + 1 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos + 1 ] -> isa( 'pit::link' );
		$tokens -> [ $pos + 2 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos + 2 ] -> isa( 'pit::link' );

		return $tokens -> [ $pos ] = pit::link -> new( \sub{ $context -> get( $var ) } );
	}

	die 'Cannot add to context: ' . $name . ' + ' . $code;
}

package pit::separator;

use base 'pit::object';

package pit::separator2;

use base 'pit::object';

package pit::op;

use base 'pit::object';

package pit::op::binary;

use base 'pit::op';

sub prio { 0 }

sub exec
{
	my $ref     = ( ref( $_[ 0 ] ) or $_[ 0 ] );
	my $pos     = $_[ 1 ];
	my $tokens  = $_[ 2 ];
	my $context = $_[ 3 ];

	$ref =~ s/^.*\:\://;
	$ref = 'op_' . $ref;

#	my $after = sub{ 1 };

	my $a = $tokens -> [ $pos - 1 ];
	my $b = $tokens -> [ $pos + 1 ];

	if( $a -> isa( 'pit::code' ) )
	{
		$a = $a -> exec( $context );
		$tokens -> [ $pos - 1 ] = $a;

	} elsif( $a -> isa( 'pit::link' ) )
	{
		my $oa = $a;
		$a = $a -> val();
		$oa -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

	if( $b -> isa( 'pit::code' ) )
	{
		$b = $b -> exec( $context );
		$tokens -> [ $pos + 1 ] = $b;

	} elsif( $b -> isa( 'pit::link' ) )
	{
		my $ob = $b;
		$b = $b -> val();
		$ob -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

#	print &Data::Dumper::Dumper( [ $a, $b ] ) . "\n";

	if( $a -> isa( 'pit::var' ) )
	{
		$a = $context -> get( $a ) -> val();
	}

	if( $b -> isa( 'pit::var' ) )
	{
		$b = $context -> get( $b ) -> val();
	}

# require Carp;
# &Carp::cluck( &Data::Dumper::Dumper( [ $a, $b ] ) );

#	print &Data::Dumper::Dumper( [ $a, $b ] ) . "\n";

	if( $a -> isa( 'pit::type' ) and $b -> isa( 'pit::type' ) )
	{
		my $val = $a -> $ref( $b );

		$tokens -> [ $pos - 1 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos - 1 ] -> isa( 'pit::link' );
		$tokens -> [ $pos + 1 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos + 1 ] -> isa( 'pit::link' );

		# $after -> ();

		return $tokens -> [ $pos ] = pit::link -> new( \sub{ $val } );
	}

	die sprintf( 'Unknown operation: %s -> %s( %s )', ( ref( $a ) or $a ), $ref, ( ref( $b ) or $b ) );
}

package pit::op::comma;

use base 'pit::op::binary';

sub prio { 2 }

sub exec
{
	my $pos     = $_[ 1 ];
	my $tokens  = $_[ 2 ];
	my $context = $_[ 3 ];

	my $token = $tokens -> [ $pos + 1 ];

	if( $token -> isa( 'pit::code' ) )
	{
		$token = $token -> exec( $context );
		$tokens -> [ $pos + 1 ] = $token;

	} elsif( $token -> isa( 'pit::link' ) )
	{
		my $otoken = $token;
		$token = $token -> val();
		$otoken -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

	$tokens -> [ $pos + 1 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos + 1 ] -> isa( 'pit::link' );
	return $tokens -> [ $pos ] = pit::link -> new( \sub{ $token } );

# require Carp;
# &Carp::cluck( &Data::Dumper::Dumper( [ $token ] ) );

	# return $token;
}

package pit::op::assign;

use base 'pit::op::binary';

sub prio { 1 }

sub exec
{
	my $ref     = ( ref( $_[ 0 ] ) or $_[ 0 ] );
	my $pos     = $_[ 1 ];
	my $tokens  = $_[ 2 ];
	my $context = $_[ 3 ];

	$ref =~ s/^.*\:\://;
	$ref = 'op_' . $ref;

	my $a = $tokens -> [ $pos - 1 ];
	my $b = $tokens -> [ $pos + 1 ];

	if( $b -> isa( 'pit::code' ) )
	{
		$b = $b -> exec( $context );
		$tokens -> [ $pos + 1 ] = $b;

	} elsif( $b -> isa( 'pit::link' ) )
	{
		my $ob = $b;
		$b = $b -> val();
		$ob -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

	if( $b -> isa( 'pit::var' ) )
	{
		$b = $context -> get( $b ) -> val();
	}

	if( $a -> isa( 'pit::code' ) )
	{
		$a = $a -> exec( $context );
		$tokens -> [ $pos - 1 ] = $a;

	} elsif( $a -> isa( 'pit::link' ) )
	{
		my $oa = $a;
		$a = $a -> val();
		$oa -> relink( \sub{ return $tokens -> [ $pos ] } );
	}

	if( $a -> isa( 'pit::var' ) )
	{
		$a = $context -> get( $a );
	}

#	print &Data::Dumper::Dumper( [ $a, $b ] ) . "\n";

# require Carp;
# &Carp::cluck( &Data::Dumper::Dumper( [ $token ] ) );

	if( $a -> isa( 'pit::var' ) and $b -> isa( 'pit::type' ) )
	{
		$a -> $ref( $b );

		$tokens -> [ $pos - 1 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos - 1 ] -> isa( 'pit::link' );
		$tokens -> [ $pos + 1 ] = pit::link -> new( \sub{ return $tokens -> [ $pos ] } ) unless $tokens -> [ $pos + 1 ] -> isa( 'pit::link' );

		return $tokens -> [ $pos ] = pit::link -> new( \sub{ $context -> get( $a ) } );
	}

	die sprintf( 'Unknown operation: %s -> %s( %s )', ( ref( $a ) or $a ), $ref, ( ref( $b ) or $b ) );
}

package pit::op::add;

use base 'pit::op::binary';

sub prio { 3 }

package pit::op::mul;

use base 'pit::op::binary';

sub prio { 4 }

package pit::op::subtr;

use base 'pit::op::binary';

sub prio { 3 }

package pit::op::div;

use base 'pit::op::binary';

sub prio { 4 }

package pit::op::mod;

use base 'pit::op::binary';

package pit::op::eq;

use base 'pit::op::binary';

package pit::op::gt;

use base 'pit::op::binary';

package pit::op::lt;

use base 'pit::op::binary';

package pit::op::gte;

use base 'pit::op::binary';

package pit::op::lte;

use base 'pit::op::binary';

package pit::type::string;

use base 'pit::type';

sub public
{
	return [
		'split'
	];
}

sub split
{
	my ( $self, $context ) = @_;

	my $re = &pit::internals::du( $_[ 1 ] -> get( pit::var -> new( \(my $dummy = '$re' ) ) ) -> val() -> cast_string() -> val() );

	my @list = map{

		\( my $dummy2 = pit::type::string -> new( \( my $dummy = &pit::internals::eu( $_ ) ) ) )

	} split( /$re/, &pit::internals::du( $self -> val() ) );

	return pit::array -> new( \@list );
}

sub cast_string
{
	return shift;
}

sub cast_num
{
	return pit::type::num -> new( \int( $_[ 0 ] -> val() ) );
}

sub op_add
{
        return $_[ 0 ] -> new( \( $_[ 0 ] -> val() . $_[ 1 ] -> cast_string() -> val() ) );
}

sub op_eq
{
        return pit::type::bool -> new( \( my $dummy = ( $_[ 0 ] -> val() eq $_[ 1 ] -> cast_string() -> val() ) ) );
}

sub op_gt
{
        return pit::type::bool -> new( \( my $dummy = ( $_[ 0 ] -> val() gt $_[ 1 ] -> cast_string() -> val() ) ) );
}

sub op_lt
{
        return pit::type::bool -> new( \( my $dummy = ( $_[ 0 ] -> val() lt $_[ 1 ] -> cast_string() -> val() ) ) );
}

sub op_gte
{
        return pit::type::bool -> new( \( my $dummy = ( $_[ 0 ] -> val() ge $_[ 1 ] -> cast_string() -> val() ) ) );
}

sub op_lte
{
        return pit::type::bool -> new( \( my $dummy = ( $_[ 0 ] -> val() le $_[ 1 ] -> cast_string() -> val() ) ) );
}

package pit::type::bool;

use base 'pit::type';

sub val
{
	return ( $_[ 0 ] -> SUPER::val() ? 'true' : 'false' );
}

package pit::type::num;

use base 'pit::type';

sub public
{
	return [
		'times'
	];
}

sub times
{
	my ( $self, $context ) = @_;

	my $ilambda = $context -> get( pit::var -> new( \(my $dummy = '$code' ) ) ) -> val();

	die sprintf( 'unknown code: %s', $ilambda ) unless $ilambda -> isa( 'pit::lambda' );

	my $local_context = pit::context -> new( $context );

	my $limit = abs( $self -> val() );

	for( my $i = 0; $i < $limit; ++$i )
	{
		my $el = pit::var -> new( \( my $dummy = '$element' ) );

		$el -> set_val( pit::type::num -> new( \( my $dummy = $i ) ) );

		$local_context -> add( $el );

		$ilambda -> call( $local_context );
	}

	return;
}

sub cast_num
{
	return shift;
}

sub cast_string
{
	return pit::type::string -> new( \$_[ 0 ] -> val() );
}

sub op_add
{
	return $_[ 0 ] -> new( \( $_[ 0 ] -> val() + $_[ 1 ] -> cast_num() -> val() ) );
}

sub op_mul
{
	return $_[ 0 ] -> new( \( $_[ 0 ] -> val() * $_[ 1 ] -> cast_num() -> val() ) );
}

sub op_div
{
	return $_[ 0 ] -> new( \( $_[ 0 ] -> val() / $_[ 1 ] -> cast_num() -> val() ) );
}

sub op_subtr
{
	return $_[ 0 ] -> new( \( $_[ 0 ] -> val() - $_[ 1 ] -> cast_num() -> val() ) );
}

sub op_mod
{
	return $_[ 0 ] -> new( \( $_[ 0 ] -> val() % $_[ 1 ] -> cast_num() -> val() ) );
}

sub op_eq
{
	return pit::type::bool -> new( \( my $dummy = ( $_[ 0 ] -> val() == $_[ 1 ] -> cast_num() -> val() ) ) );
}

sub op_gt
{
	return pit::type::bool -> new( \( my $dummy = ( $_[ 0 ] -> val() > $_[ 1 ] -> cast_num() -> val() ) ) );
}

sub op_lt
{
	return pit::type::bool -> new( \( my $dummy = ( $_[ 0 ] -> val() < $_[ 1 ] -> cast_num() -> val() ) ) );
}

sub op_gte
{
	return pit::type::bool -> new( \( my $dummy = ( $_[ 0 ] -> val() >= $_[ 1 ] -> cast_num() -> val() ) ) );
}

sub op_lte
{
	return pit::type::bool -> new( \( my $dummy = ( $_[ 0 ] -> val() <= $_[ 1 ] -> cast_num() -> val() ) ) );
}

package pit;

use Perl6::Slurp '&slurp';

my @tokens = ();
my $iname  = $ARGV[ 0 ];
chomp $iname;
my $string = &slurp( $iname );
my %table  = (
	op_assign    => qr/^\=(?!(\s))$/,
	op_add       => qr/^\+(?!(\s))$/,
	op_mul       => qr/^\*(?!(\s))$/,
	op_div       => qr/^\/(?!(\s))$/,
	op_subtr     => qr/^\-(?!(\s))$/,
	op_mod       => qr/^\%(?!(\s))$/,
	op_eq        => qr/^\=\=(?!(\s))$/,
	op_gt        => qr/^\>(?!(\s))$/,
	op_lt        => qr/^\<(?!(\s))$/,
	op_gte       => qr/^\>\=(?!(\s))$/,
	op_lte       => qr/^\<\=(?!(\s))$/,
	comment	     => qr/\#.+?[\n]?$/,
	type_string  => {
		from_re  => qr/^\"./,
		to_re    => qr/[^\\]+\"(?!(\s))$/,
		trans_to => sub
		{
			my $s = shift;

			$s =~ s/(\\\\)+//g;

			return $s;
		}
	},
	var          => qr/^\$[a-z_][a-z0-9_]*(?!(\s))$/i,
	decl_lambda  => {
		from_re       => qr/^lambda(?=((\s|\()$))/,
		to_re         => qr/^lambda(?=((\s|\()$))/,
		after         => sub
		{
			my ( $word, $chars ) = @_;

			unshift @$chars, chop $word;
		}
	},
	decl_hash    => {
		from_re       => qr/^hash(?=((\s|\()$))/,
		to_re         => qr/^hash(?=((\s|\()$))/,
		after         => sub
		{
			my ( $word, $chars ) = @_;

			unshift @$chars, chop $word;
		}
	},
	decl_array   => {
		from_re       => qr/^array(?=((\s|\()$))/,
		to_re         => qr/^array(?=((\s|\()$))/,
		after         => sub
		{
			my ( $word, $chars ) = @_;

			unshift @$chars, chop $word;
		}
	},
	decl_var     => {
		from_re       => qr/^let(?=((\s|\$)$))/,
		to_re         => qr/^let(?=((\s|\$)$))/,
		after         => sub
		{
			my ( $word, $chars ) = @_;

			unshift @$chars, chop $word;
		}
	},
	decl_fun     => {
		from_re       => qr/^defun(?=((\s|\$)$))/,
		to_re         => qr/^defun(?=((\s|\$)$))/,
		after         => sub
		{
			my ( $word, $chars ) = @_;

			unshift @$chars, chop $word;
		}
	},
	type_num     => qr/^[-]?[0-9]+(?!(\s))$/,
	separator    => qr/^\;(?!(\s))$/,
	separator2   => qr/^\=\>(?!(\s))$/,
	op_comma     => qr/^\,(?!(\s))$/,
	parens_open  => qr/^\((?!(\s))$/,
	parens_close => qr/^\)(?!(\s))$/,
	method_call  => qr/^\.[a-z_][a-z0-9_]*(?!(\s))$/i,
	function     => qr/^[a-z_][a-z0-9_]*(?!(\s))$/i,
);

my @chars = split( //, $string );

while( defined( my $first_char = shift @chars ) )
{
	my $word = $first_char;
	my $id   = &get_category( $word, \@chars );

#	warn sprintf( '"%s":"%s"', $word, $id );
	while( defined( my $next_char = shift @chars ) )
	{
		if( my $next_id = &get_category( ( my $next_word = ( $word . $next_char ) ), \@chars ) )
		{
#			warn sprintf( '"%s":"%s"', $next_word, $next_id );
			$id   = $next_id;
			$word = $next_word;
		} else
		{
			# warn sprintf( '"%s":"%s"', $next_word, $next_id );
			unshift @chars, $next_char;
			last;
		}
	}

	if( length( $word ) )
	{
		if( $id )
		{
#		warn sprintf( 'adding => "%s":"%s"', $word, $id );
			unless( $id eq 'comment' )
			{
				push @tokens, { $id => $word };
			}

		} elsif( $word !~ m/^\s+$/ )
		{
			die 'Lexemme is unknown: ' . $word;
		}
	}
}

print '-'x37 . 'input:' . '-'x37 . "\n";
print $string . "\n";
print '-'x36 . 'output:' . '-'x37 . "\n";

my @phrases = ();
{
@phrases = &make_phrases(\@tokens);
# use Data::Dumper 'Dumper';
# print Dumper( \@phrases );
sub make_phrases
{
my $tokens = shift;
my @output = ();
my @phrase = ();
my @container = ();
my $parens = 0;
# print Dumper( $tokens );
for( my $i = 0; $i < scalar( @$tokens ); ++$i )
{
#	unless( ref( $tokens -> [ $i ] ) eq 'HASH' )
#	{
#		use Data::Dumper 'Dumper';
#		print Dumper( $tokens );
#		print $tokens -> [ $i ] . "\n";
#	}

	my ( $type, $value ) = %{ $tokens -> [ $i ] };

	if( $type eq 'parens_open' )
	{
		++$parens;
		push @container, $tokens -> [ $i ] if $parens > 1;
		next;

	} elsif( $type eq 'parens_close' )
	{
		push @container, $tokens -> [ $i ] if $parens > 1;
		--$parens;

		if( $parens == 0 )
		{
#		use Data::Dumper 'Dumper';
#		print Dumper( \@container );
#		print Dumper( &make_phrases( \@container ) );
		push @container, { separator => ';' };
			push @phrase, &make_phrases( \@container );
			@container = ();
		}

		next;
	}

	if( $parens > 0 )
	{
		push @container, $tokens -> [ $i ];

	} elsif( $parens == 0 )
	{
		my $pkg = sprintf( 'pit::%s', join( '::', split( /_/, $type ) ) );

		if( $type eq 'type_string' )
		{
			$value =~ s/^\"|\"$//g;
		}

		push @phrase, $pkg -> new( \$value );

	} else
	{
		die 'Unmatched parenthesis';
	}

	if( ( $parens == 0 ) and ( ( $type eq 'separator' ) or ( $type eq 'separator2' ) ) )
	{
		pop @phrase;

		my $pkg = 'pit::code';

		push @output, $pkg -> new( \( my $dummy = [ @phrase ] ) );# if scalar( @phrase ) > 0;
		@phrase = ();
	}
}
die 'Unmatched parenthesis' unless $parens == 0;
{
		my $pkg = 'pit::code::block';

return $pkg -> new( \\@output );
}
}
}
@tokens = ();

# use Data::Dumper 'Dumper';

# $Data::Dumper::Deparse = 1;
# $Data::Dumper::Terse   = 1;
# $Data::Dumper::Indent  = 0;

foreach my $phrase ( @phrases )
{
	$phrase -> exec();
#	print Dumper( $phrase -> exec() );
#	if( my $r = $phrase -> exec() )
#	{
#		if( $r -> isa( 'pit::link' ) )
#		{
#			$r = $r -> val();
#		}

#		print $r -> val() . "\n";
#	}
}

exit 0;

sub get_category
{
	my ( $word, $chars ) = @_;
	my @ids = ();

SCAN_CATEGORIES_TABLE:
	foreach my $id ( keys %table )
	{
		my $sref = ref( my $spec = $table{ $id } );

		if( $sref eq 'Regexp' )
		{
			if( $word =~ m/$spec/ )
			{
#			warn $word, $id;
				push @ids, $id;
				last;
			}

		} elsif( $sref eq 'HASH' )
		{
			my ( $from_re, $to_re ) = @$spec{ 'from_re', 'to_re' };

			if( ( ref( $from_re ) eq 'Regexp' ) and ( ref( $to_re ) eq 'Regexp' ) )
			{
				my ( $trans_from, $trans_to ) = map{ ( ( ref( $_ ) eq 'CODE' ) ? $_ : sub{ return shift } ) } @$spec{ 'trans_from', 'trans_to' };

				my $word = $word;

				$word = $trans_from -> ( $word );
# warn $id . ':' . $word . ':' . $from_re if $word =~ m/^let/;
				if( $word =~ m/$from_re/ )
				{
					my $lword = $word;

					unless( $spec -> { 'no_extra_stop' } )
					{
						my $cword = $word;

						chop $cword;

						next SCAN_CATEGORIES_TABLE if $trans_to -> ( $cword ) =~ m/$to_re/;
					}

#					unless( $trans_to -> ( $lword ) =~ m/$to_re/ )
					{
						my $flag = 0;

						for( my $i = 0; $i < scalar( @$chars ); $lword .= $chars -> [ $i ], ++$i )
						{
							if( $trans_to -> ( $lword ) =~ m/$to_re/ )
							{
								$flag = 1;
#								warn 'FLAG: ' . $lword;

							} elsif( $flag )
							{
								chop $lword;
#								warn 'K: ' . $lword;
								last;
							}
							# warn $id . ':' .  $lword . ':' . $to_re if $lword =~ m/^let/;
							# $lword .= $chars -> [ $i ];
						}
					}

					if( ref( my $after = $spec -> { 'after' } ) eq 'CODE' )
					{
						$after -> ( $lword, $chars );
					}

#warn $id . ':' . $lword . ':' . $to_re if $lword =~ m/^let/;
					if( $trans_to -> ( $lword ) =~ m/$to_re/ )
					{
						push @ids, $id;
						last;
					}
				}
			}
		}
	}
# warn join(',',@ids) if scalar( @ids ) > 1;
# warn join(',',@ids), $word;
	return ( ( scalar( @ids ) == 1 ) ? shift( @ids ) : undef );
}

