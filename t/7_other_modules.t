#!/usr/bin/perl -w
 
use Test::More tests => 1;

BEGIN { chdir 't' if -d 't'; }
 
sub main::handler {
	return {};
}
 
use_ok( 'RayApp::CGIStorable' );
$ENV{'SCRIPT_FILENAME'} = 'script1.html';
use_ok( 'RayApp::CGIWrapper' );

