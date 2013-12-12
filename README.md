pit-script
==========

PIT Script - Scripting language written in PERL aimed to simplify development process of integrational tests

WARNING
-------

A very dirty draft version it is

How to run example
------------------

perl pit.pl example.pit

Syntax
------

### String defenition

"some string"

### Number definition

100500

### Array definition

array ( "element1"; 2; 3 );

### Hash definition

hash ( "key" => "value"; "other_key" => 3; "third key"; 5; );

### Variable definition

let $var;
let $var = "string";
let $var = $other_var;
let $var = hash ();
let $var = array ();
let $var = function();
let $var = true;
let $var = -1;

### Function definition

defun function
(
	"function body";
	"this string will be returned to caller"
);

### Function arguments

defun function_with_args
(
	"simply try to access an argument by name: " + $some_arg;
	"here it is concatenated with some string"
);

function_with_args( let $some_arg = "some string" );

### Array methods

let $var = array ( 1; 2; 3; );

$var.push( let $list = array( 4; 5; 6; ) );
$var.unshift( let $list = array( 0 ) );
$var.size();
let $first_el = $var.shift(); # also removes first element from array
let $last_el = $var.pop(); # also removes last element from array
let $second_el = $var.get( let $idx = 1 );
let $new_value = $var.set( let $idx = 0; let $val = "some new value" );

### Hash methods

let $var = hash ( "key" => "value" );

let $value = $var.get( let $key = "key" );
let $new_value = $var.set( let $key = "key"; let $val = 100500; );
let $array_with_keys = $var.keys();
let $array_with_values = $var.values();
let $bool = $var.exists( let $key = "some key" );
let $value_for_removed_key = $val.delete( "key" );

### Builtin functions

print( let $str = "" );
E( let $str = "" ); # interpolate escape sequences in string
plan( let $tests = 3 ); # define number of tests to be run
agent( let $str = "some UserAgent string" ); # define user agent
open( let $url = "http://domain.tld/" ); # GET an url
submit_form( let $spec = $www_mechanize_compatible_args; let $descr = "what this form is" ); # http://search.cpan.org/~ether/WWW-Mechanize-1.73/lib/WWW/Mechanize.pm#$mech->submit_form(_..._)

