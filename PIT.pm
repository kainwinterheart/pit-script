#!/usr/bin/perl

use strict;
use utf8;

package PIT;

require Exporter;

our @ISA = ( 'Exporter' );

our @EXPORT = ( 'run' );

our $VERSION = 0.01;

use Dorq;
use PIT::All;

-1;

