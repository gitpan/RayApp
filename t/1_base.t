#!/usr/bin/perl 

use warnings;
$^W = 1;
use strict;

use Apache::Test ':withtestmore';
use Test::More;

use Apache::TestConfig;
use Apache::TestRequest qw(GET);

plan tests => 5;

my ($res, $body);

$res = GET '/dir/';
$body = $res->content;
is($body, <<EOF, "GET /dir/ should give us the /dir/index.html");
<html>
<body>
<p>Body of the index.html.</p>
</body>
</html>
EOF

$res = GET '/dir/index.html';
$body = $res->content;
is($body, <<EOF, "So should /dir/index.html");
<html>
<body>
<p>Body of the index.html.</p>
</body>
</html>
EOF

$res = GET '/dir';
$body = $res->content;
is($body, <<EOF, "And /dir without trailing slash");
<html>
<body>
<p>Body of the index.html.</p>
</body>
</html>
EOF

$res = GET '/my.html';
$body = $res->content;
is($body, <<EOF, "The same result for GET /my.html");
<html>
<body>
<p>Paragraph.</p>
</body>
</html>
EOF

$res = GET '/file';
$body = $res->content;
is($body, "Krtek.\n", "GET /file should give us the text file.");


