#!/usr/bin/perl 

no warnings 'once';
$main::location = 'mod_perl4';
$main::rayapp_env_data = 'mono_lake';

if (-d 't') {
	require 't/set1.pl';
} else {
	require 'set1.pl';
}
