
use warnings;
$^W = 1;
use strict;

use Apache::Test ':withtestmore';
use Test::More;

use Apache::TestConfig;
use Apache::TestRequest qw(GET);
                                                                                
plan tests => 29;

my ($res, $body);

$res = GET "/$main::location/app1.xml";
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/xml', 'The data should be text/xml');
$body = $res->content;
is($body, <<EOF, "GET /$main::location/app1.xml should return 13 and $main::rayapp_env_data");
<?xml version="1.0"?>
<root>
	<id>13</id>
	<data>$main::rayapp_env_data</data>
</root>
EOF

$res = GET "/$main::location/app1.html";
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/html; charset=UTF-8', 'The data should be text/html; charset=UTF-8');
$body = $res->content;
is($body, <<EOF, "GET /$main::location/app1.html should use the stylesheet app1.html.xsl");
<html><body><p>The id is <span id="id">13</span>,
	the data is <span id="data">$main::rayapp_env_data</span>.
</p></body></html>
EOF

$res = GET "/$main::location/";
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/html; charset=UTF-8', 'The data should be text/html; charset=UTF-8');
$body = $res->content;
is($body, <<EOF, "GET /$main::location/ should return that HTML");
<html><body><p>The id is <span id="id">13</span>,
	the data is <span id="data">$main::rayapp_env_data</span>.
</p></body></html>
EOF

$res = GET "/$main::location";
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/html; charset=UTF-8', 'The data should be text/html; charset=UTF-8');
$body = $res->content;
is($body, <<EOF, "And so should GET /$main::location without the trailing slash");
<html><body><p>The id is <span id="id">13</span>,
	the data is <span id="data">$main::rayapp_env_data</span>.
</p></body></html>
EOF

=comment

$res = GET "/$main::location/app2.html?id=5";
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/html; charset=UTF-8', 'The data should be text/html; charset=UTF-8');
$body = $res->content;
is($body, <<EOF, "GET /$main::location/app2.html?id=5 should return that 5");
<html><body><p>The id is <span id="id">5</span>,
	the data is <span id="data">$main::rayapp_env_data</span>.
</p></body></html>
EOF

=cut

$res = GET "/$main::location/app2.html";
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/html; charset=UTF-8', 'The data should be text/html; charset=UTF-8');
$body = $res->content;
is($body, <<EOF, "GET /$main::location/app2.html should use the stylesheet app2.xsl");
<html><body><p>The id is <span id="id">13</span>,
	the data is <span id="data">$main::rayapp_env_data</span>.
</p></body></html>
EOF

$res = GET "/$main::location/text.xml";
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/plain', 'The data should be text/plain');
$body = $res->content;
is($body, <<EOF, "We should have got the output via print");
Output.
EOF

$res = GET "/$main::location/302.xml", redirect_ok => 0;
ok($res, 'Did we get HTTP::Response?');
is($res->code, 302, "Test the response code, redirect");
is($res->header('Content-Type'), 'text/plain', 'The data should be text/plain');
is($res->header('Location'), 'http://perl.apache.org/', 'The redirection target');
$body = $res->content;
is($body, <<EOF, "The 302 response can have text");
Check the mod_perl website, perl.apache.org.
EOF

1;

