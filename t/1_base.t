#!/usr/bin/perl -Tw

use Test::More tests => 2;

BEGIN { use_ok( 'RayApp' ); }

my $rayapp = new RayApp;
isa_ok($rayapp, 'RayApp');

