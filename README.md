PIT Script
==========

Scripting language based on [Dorq](https://github.com/kainwinterheart/dorq-dsl) aimed to simplify development process of integrational tests

Prerequisites
-------------

[URI](http://search.cpan.org/~gaas/URI-1.60/URI.pm)

[Test::More](http://search.cpan.org/~rjbs/Test-Simple-1.001002/lib/Test/More.pm)

[WWW::Mechanize](http://search.cpan.org/~ether/WWW-Mechanize-1.73/lib/WWW/Mechanize.pm)

How to run example
------------------

	perl -Idorq-dsl -MPIT -e 'run "example.pit"'

Syntax
------

### Builtin functions

	plan( let $tests = 3 ); # define number of tests to be run
	agent( let $str = "some UserAgent string" ); # define user agent
	open( let $url = "http://domain.tld/" ); # GET an url
	open( let $url = "http://domain.tld/"; let $params = hash ( "key" => "value" ); ); # same as above, but with ?key=value query string
	submit_form( let $spec = $www_mechanize_compatible_args; let $descr = "what this form is" ); # http://search.cpan.org/~ether/WWW-Mechanize-1.73/lib/WWW/Mechanize.pm#$mech->submit_form(_..._)
	content_like( let $re = "some text followed by [0-9]+" )
	content_ilike( let $re = "SoMe TeXt FoLlOweD bY [0-9]+" ) # some as above, but case insensitive
	subtest( let $name = "subtest name"; let $code = lambda ( ... ) ) # run a subtest

