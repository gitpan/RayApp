
package RayApp::CGIWrapper;
use strict;
use RayApp::CGI;

BEGIN {
	if (defined $ENV{'PERL5OPT'}) {
		my $package = __PACKAGE__;
		if ($ENV{'PERL5OPT'} eq "-M$package") {
			delete $ENV{'PERL5OPT'};
			print STDERR "Clearing PERL5OPT\n";
		}
	}

	if (defined $ENV{'SCRIPT_FILENAME'}
		and defined $ENV{'SCRIPT_NAME'}) {
		my ($fnameext) = ($ENV{'SCRIPT_FILENAME'} =~ /\.(.+?)$/);
		my ($nameext) = ($ENV{'SCRIPT_NAME'} =~ /\.(.+?)$/);
		if ($fnameext ne $nameext) {
			$ENV{'SCRIPT_FILENAME'} =~ s/\..+?$/.$nameext/;
		}
	}

	RayApp::CGI::handler();	
}

1;

