
use 5.6.1;

use ExtUtils::MakeMaker;

use Getopt::Long ();

my $xmllint;
Getopt::Long::GetOptions(
	'xmllint=s' => \$xmllint,
	);

use lib 't';
use Getfile;

if (not defined $xmlint) {
	my $tmp;
	local *LINT;
	local $/ = undef;
	open LINT, "xmllint --version 2>&1 |" and $tmp = <LINT> and close LINT;
	if ($tmp =~ /^xmllint: using libxml version/) {
		$xmllint = 'xmllint';
	}
}
if (not defined $xmllint) {
	$xmllint = prompt 'Please enter location of xmllint:', _getfile('xmllint');
}

open FILE, '> xmllint' and print FILE $xmllint and close FILE;

WriteMakefile(
	NAME => 'RayApp',
	VERSION_FROM => 'lib/RayApp.pm',
	PREREQ_PM => {
		'XML::LibXML' => 0,
		'XML::LibXSLT' => 0,
		'CGI' => 0,
		'Test::More' => 0,
	},
	PREREQ_FATAL => 1,
	PL_FILES => { 'bin/rayapp_cgi_wrapper.PL' => 'bin/rayapp_cgi_wrapper', },
        EXE_FILES => [ 'bin/rayapp_cgi_wrapper' ],
	dist => {
		POSTOP => 'mv $(DISTNAME)-$(VERSION).tar.gz ..',
	},
	clean => {
		FILES => 'xmllint bin/rayapp_cgi_wrapper',
	},
);

