#!/usr/bin/perl -T

use Test::More tests => 3;
use warnings;
$^W = 1;
use strict;

BEGIN { use_ok( 'RayApp' ) }

my $rayapp = new RayApp;
isa_ok($rayapp, 'RayApp', 'RayApp object');

is($RayApp::VERSION, 1.148, 'Do tests match the version of RayApp?');

