#!/usr/bin/perl 

no warnings 'once';
$main::location = 'cgi1';
$main::rayapp_env_data = 'mono1';

if (-d 't') {
	require 't/set1.pl';
} else {
	require 'set1.pl';
}
