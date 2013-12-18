use strict;
use utf8;

package PIT::element;

use base 'Dorq::type';

use HTML::Query 'Query';

sub new
{
	$_[ 0 ] -> SUPER::new( { object => \$_[ 1 ] } );
}

sub public
{
	return [
		'find_elements',
		'value_should_be'
	];
}

sub selector
{
	my $self = shift;

	my %attrs = ${ $self -> { 'object' } } -> all_external_attr();

	my ( $id, $class ) = delete @attrs{ 'id', 'class' };

	my $str = '';

	if( $id )
	{
		$str .= sprintf( '#%s', $id );
	}

	if( $class )
	{
		foreach my $_class ( split( /\s+/, $class ) )
		{
			$str .= sprintf( '.%s', $_class );
		}
	}

	foreach my $attr ( sort keys %attrs )
	{
		next unless defined $attr and length $attr;

		next if $attr eq '/';
		next if $attr eq 'style';

		$str .= sprintf( '[%s="%s"]', $attr, $attrs{ $attr } );
	}

	return $str;
}

sub find_elements
{
	my ( $self, $context ) = @_;

	my $q = $context -> get( Dorq::var -> new( \( my $dummy = '$q' ) ) ) -> val() -> cast_string() -> val();

	my @all = Query( ${ $self -> { 'object' } }, $q ) -> get_elements();
	my @all_wrapped = ();

	while( defined( my $el = shift @all ) )
	{
		push @all_wrapped, \PIT::element -> new( $el );
	}

	return Dorq::array -> new( \@all_wrapped );
}

sub value_should_be
{
	my ( $self, $context ) = @_;

	my $str = $context -> get( Dorq::var -> new( \( my $dummy = '$str' ) ) ) -> val() -> cast_string() -> val();

	&Test::More::is( &Dorq::internals::du( ${ $self -> { 'object' } } -> { 'value' } ), &Dorq::internals::du( $str ), sprintf( 'value of %s matches %s', &Dorq::internals::eu( $self -> selector() ), &Dorq::internals::eu( $str ) ) );

	return Dorq::type::undef -> new( \( my $dummy = undef ) );
}

-1;

