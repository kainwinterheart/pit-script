use strict;
use utf8;

package PIT::content;

use base 'Dorq::type';

use HTML::Query 'Query';
use HTML::TreeBuilder ();

sub new
{
	$_[ 0 ] -> SUPER::new( { content => $_[ 1 ] } );
}

sub public
{
	return [
		'find_elements'
	];
}

sub parsed
{
	my $self = shift;

	unless( exists $self -> { 'parsed' } )
	{
		$self -> { 'parsed' } = HTML::TreeBuilder -> new_from_content( $self -> { 'content' } );
	}

	return $self -> { 'parsed' };
}

sub find_elements
{
	my ( $self, $context ) = @_;

	my $q = $context -> get( Dorq::var -> new( \( my $dummy = '$q' ) ) ) -> val() -> cast_string() -> val();

	my @all = Query( $self -> parsed(), $q ) -> get_elements();
	my @all_wrapped = ();

	while( defined( my $el = shift @all ) )
	{
		push @all_wrapped, \PIT::element -> new( $el );
	}

	return Dorq::array -> new( \@all_wrapped );
}

-1;

