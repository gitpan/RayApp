
use warnings;
$^W = 1;
use strict;

use Apache::Test ':withtestmore';
use Test::More;

use Apache::TestConfig;
use Apache::TestRequest qw(GET POST);
                                                                                
plan tests => 57;

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

$res = GET "/$main::location/xml.xml";
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/xml', 'The data should be text/xml');
$body = $res->content;
is($body, <<EOF, "GET /$main::location/xml.xml should skip the DSD and give us the XML");
<?xml version="1.0"?>
<data>
	Note, this is not DSD, it should be processed as is.
	<_param name="id"/>
	<id/>
</data>
EOF

$res = GET "/$main::location/nonexistent.xml";
ok($res, 'Did we get HTTP::Response?');
is($res->code, 404, "We expect 404 Not found code");
$body = $res->content;
if ($main::location eq 'cgi1') {
	is($res->header('Content-Type'), 'text/plain', 'The plain message');
	is($body, <<EOF, "GET /$main::location/nonexistent.xml should return 404 message");
The requested URL was not found on this server.
EOF
} else {
	is($res->header('Content-Type'), 'text/html; charset=iso-8859-1', 'The HTML message');
	is($body, <<EOF, "GET /$main::location/nonexistent.xml should return 404 message");
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>404 Not Found</title>
</head><body>
<h1>Not Found</h1>
<p>The requested URL /$main::location/nonexistent.xml was not found on this server.</p>
</body></html>
EOF
}

$res = GET "/$main::location/processq.xml";
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/xml', 'The data should be text/xml');
$body = $res->content;
is($body, <<EOF, "GET /$main::location/processq.xml should return empty XML");
<?xml version="1.0"?>
<application>
</application>
EOF

$res = GET "/$main::location/processq.xml?id=123";
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/xml', 'The data should be text/xml');
$body = $res->content;
is($body, <<EOF, "GET /$main::location/processq.xml should return id: 123");
<?xml version="1.0"?>
<application>
	<out_id>123</out_id>
</application>
EOF

$res = GET "/$main::location/processq.xml?value=123;id=jezek";
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/xml', 'The data should be text/xml');
$body = $res->content;
is($body, <<EOF, "GET /$main::location/processq.xml should return id: jezek and value: 123");
<?xml version="1.0"?>
<application>
	<out_id>jezek</out_id>
	<out_value>123</out_value>
</application>
EOF

$res = POST "/$main::location/processq.xml?value=123;id=jezek",
	[ id => 45, value => 'krtek' ];
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/xml', 'The data should be text/xml');
$body = $res->content;
is($body, <<EOF, "GET /$main::location/processq.xml should return POSTed values");
<?xml version="1.0"?>
<application>
	<out_id>45</out_id>
	<out_value>krtek</out_value>
</application>
EOF

my $hostport = Apache::TestRequest::hostport;
my $request = new HTTP::Request
	POST => "http://$hostport/$main::location/processq.xml?value=88";
$request->content_type('text/plain');
$request->content('This is freeform content where a = 1');
my $ua = new LWP::UserAgent;
$res = $ua->request($request);
ok($res, 'Did we get HTTP::Response?');
is($res->code, 200, "Test the response code");
is($res->header('Content-Type'), 'text/xml', 'The data should be text/xml');
$body = $res->content;
is($body, <<EOF, "GET /$main::location/processq.xml should process the body of the request");
<?xml version="1.0"?>
<application>
	<out_value>This is freeform content where a = 1</out_value>
</application>
EOF

1;

