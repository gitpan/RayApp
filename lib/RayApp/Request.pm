
package RayApp::Request;
use strict;

sub new {
	my ($class, $r) = @_;
	if (defined $r) {
		require RayApp::Request::APR;
		return new RayApp::Request::APR($r);
	} else {
		require RayApp::Request::CGI;
		return new RayApp::Request::CGI;
	}
}

# Parameters for url:
#	base
#	absolute, relative, full
#		path_info
#		query
use URI ();
sub parse_full_uri {
	my ($self, $uri, %opts) = @_;
	for (keys %opts) {
		if (/^-(.+)$/) {
			$opts{$1} = delete $opts{$_};
		}
	}
	# print STDERR "Parsing [$uri]\n";
	my $u = new URI($uri);
	my $base = $u->scheme . '://' . $u->host;
	my $port = $u->_port;
	if (defined $port) {
		$base .= ":$port";
	}
	if ($opts{base}) {
		return $base;
	}
	my $out;
	if ($opts{full}) {
		$out = $u->as_string;
	} elsif ($opts{relative}) {
		$out = $u->rel($u->as_string);
	} else {
		$out = $u->as_string;
		if (substr($out, 0, length($base)) eq $base) {
			$out = substr($out, length($base));
		}
	}
	# print STDERR "parse_full_uri [$uri] -> [$out]\n";
	return $out;
}

1;

