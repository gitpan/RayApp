
use 5.6.1;

use ExtUtils::MakeMaker;

use Getopt::Long ();

my $xmllint;
Getopt::Long::GetOptions(
	'xmllint=s' => \$xmllint,
	);

use lib 'core_t';
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

my $WILL_RUN_APACHE_TESTS = 0;
my $tests = 'core_t/*.t';
if (prompt("Would you like me to run tests with your Apache?", "yes") =~ /^y/i) {
	eval q!
		use Apache::TestMM qw( );
		use Apache::Test;
		Apache::TestMM::filter_args();
		Apache::TestMM::generate_script('t/TEST');
	!;
	if ($@) {
		print "\tIt looks like you do not have all the modules needed\n\tto run Apache tests:\n$@\n";
	} else {
		print "\tGood. We will try to run tests using your Apache.\n";
		$WILL_RUN_APACHE_TESTS = 1;
		$tests .= ' t/TEST';
	}
} else {
	print "\tGood. We will only test the core RayApp.\n";
}
	
sub MY::test {
	package MY;
	my $tests = shift->SUPER::test(@_);

	if ($WILL_RUN_APACHE_TESTS) {
		$tests =~ s/.*\n(test_dynamic.+?)\n\n.*/$1/s;
		$tests =~ s!\Q$(TEST_FILES)!core_t/*.t!;
		my $apache_tests = Apache::TestMM->test(@_);
		$apache_tests =~ s/\n(run_tests\s*:\s*test_clean)/\n$tests\n\nrun_tests : test_dynamic test_clean\n/;
		return $apache_tests;
	} else {
		return $tests;
	}
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
		'POSIX' => 0,
		'warnings' => 0,
		'strict' => 0,
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
	test => {
		TESTS => $tests,
	},
);

