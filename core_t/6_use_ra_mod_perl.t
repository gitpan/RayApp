#!/usr/bin/perl -T
 
use Test::More tests => 2;

use warnings;
$^W = 1;
use strict;

use_ok( 'RayApp::mod_perl' );
use_ok( 'RayApp::mod_perl_Storable' );
