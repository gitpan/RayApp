#!/usr/bin/perl 

no warnings 'once';
$main::location = 'mod_perl1';
$main::rayapp_env_data = 'man5';

if (-d 't') {
	require 't/set1.pl';
} else {
	require 'set1.pl';
}
