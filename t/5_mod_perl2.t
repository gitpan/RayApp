#!/usr/bin/perl 

no warnings 'once';
$main::location = 'mod_perl2';
$main::rayapp_env_data = 'mono45';

if (-d 't') {
	require 't/set1.pl';
} else {
	require 'set1.pl';
}
