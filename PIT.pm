#!/usr/bin/perl

use strict;
use utf8;

package PIT;

require Exporter;

our @ISA = ( 'Exporter' );

our @EXPORT = ( 'run', 'run_many', 'verbose', 'run_dir' );

our $VERSION = 0.01;

use Dorq;
use PIT::All;

use TAP::Harness ();

use Test::More ();

use File::Spec ();


my $VERBOSE = 0;


sub verbose (;$)
{
	$VERBOSE = ( shift or 1 );
}

sub run_many (@)
{
	my @a = @_;

	chomp $_ foreach @a;

	my @cmd = (
		$^X,
		( map{ sprintf( '-I%s', $_ ) } @INC ),
		'-MPIT',
		'-e'
	);

	TAP::Harness
		-> new( {
			( $VERBOSE ? (
				verbosity => $VERBOSE
			) : () ),
			exec => sub
			{
				my ( undef, $file ) = @_;

				return [
					@cmd,
					sprintf( q|run q{%s}|, $file ),
				];
			}
		} )
		-> runtests( @a )
	;
}

sub run_dir ($)
{
	my $dir = shift;

	chomp $dir;

	my @input = ( '.' );
	my @files = ();

	while( defined( my $subpath = shift @input ) )
	{
		my $path = File::Spec -> catfile( $dir, $subpath );

		if( -d $path )
		{
			if( opendir( my $dh, $path ) )
			{
				my @list = readdir( $dh );

				while( defined( my $node = shift @list ) )
				{
					chomp $node;

					next if $node =~ m/^\./;

					push @input, File::Spec -> catfile( $subpath, $node );
				}

				closedir( $dh );
			}

		} elsif( -f $path )
		{
			if( $path =~ m/\.pit$/ )
			{
				push @files, $path;
			}
		}
	}

	return run_many @files;
}

-1;

