#!/usr/bin/perl 

no warnings 'once';
$main::location = 'mod_perl3';
$main::rayapp_env_data = 'man53';

if (-d 't') {
	require 't/set1.pl';
} else {
	require 'set1.pl';
}
