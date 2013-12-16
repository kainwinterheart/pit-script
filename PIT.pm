#!/usr/bin/perl

use strict;
use utf8;

package PIT;

require Exporter;

our @ISA = ( 'Exporter' );

our @EXPORT = ( 'run', 'run_many', 'verbose' );

our $VERSION = 0.01;

use Dorq;
use PIT::All;

use TAP::Harness ();

use Test::More ();


my $VERBOSE = 0;


sub verbose (;$)
{
	$VERBOSE = ( shift or 1 );
}

sub run_many (@)
{
	my @a = @_;

	chomp $_ foreach @a;

	TAP::Harness
		-> new( {
			( $VERBOSE ? (
				verbosity => $VERBOSE
			) : () ),
			# http://stackoverflow.com/questions/16584001/using-functions-in-tap-harness-instead-of-test-files
			exec => sub
			{
				my ( undef, $file ) = @_;

				my $builder = Test::More -> builder();

				# reset the Test::Builder object for every "file"
				$builder -> reset();
#				$builder -> { 'Indent' } = ''; # may not be needed

				# collect the output into $out
				$builder -> output( \( my $out = '' ) );     # STDOUT
				$builder -> failure_output( \$out ); # STDERR
				$builder -> todo_output( \$out );    # STDOUT

				# run the test
				run( $file );

				# the output ( needs at least one newline )
				return $out;
			}
		} )
		-> runtests( @a )
	;
}

-1;

