
package RayApp::CGIStorable;
use Storable;

END {
	my $value = main::handler();
	if (ref $value) {
		print "Content-Type: application/x-perl-storable\n\n";
		print Storable::freeze($value);
	}
}
1;

