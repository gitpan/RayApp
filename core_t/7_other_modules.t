#!/usr/bin/perl -T
 
use Test::More tests => 1;

use warnings;
$^W = 1;
use strict;

BEGIN { chdir 'core_t' if -d 'core_t'; }
 
sub main::handler {
	return {};
}
 
use_ok( 'RayApp::CGIStorable' );
$ENV{PATH_TRANSLATED} = 'script1.html';
use_ok( 'RayApp::CGIWrapper' );

