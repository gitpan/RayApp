
package RayApp::Source;

use strict;
use warnings;

$RayApp::Source::VERSION = '1.160';
		
use Digest::MD5 ();
use HTTP::Request ();

sub new {
	my $class = shift;
	my %opts = @_;

	my $rayapp = $opts{rayapp} or die "RayApp::Source called without RayApp specified";

	my $method = $opts{method} || 'GET';
	my $request = new HTTP::Request($method, $opts{uri}, [], $opts{post_body});
	if (defined $opts{post_content_type}) {
		$request->header(Content_Type => $opts{post_content_type});
	}
	if (defined $opts{frontend_ext}) {
		$request->header('X-RayApp-Frontend-Ext', $opts{frontend_ext});
	}
	if (defined $opts{frontend_uri}) {
		$request->header('X-RayApp-Frontend-URI', $opts{frontend_uri});
	}
	my $response = $rayapp->ua->request( $request );

	if ($response->is_error) {
		if ($opts{want_404}	# catch 404 Not exists
			and $response->code eq '404') {
			return bless {
				uri => $opts{uri},
				content => undef,
				content_type => undef,
				md5_hex => undef,
				rayapp => $rayapp,
				code => $response->code,
			}, $class;
		}
		if (defined $response->{_msg}) {
			$rayapp->errstr($response->{_msg});
		} else {
			$rayapp->errstr($response->error_as_HTML());
		}
		return;
	}

	my @stylesheet_params;
	my $i = 1;
	while (1) {
		my $val = $response->header("X-RayApp-Style-Param-$i");
		last unless defined $val;
		# print STDERR "Value [$val]\n";
		$val =~ s/&#x([0-9a-f]+);/ '"\x{' . $1 . '}"' /geei;
		# print STDERR "  -> decoded [$val]\n";
		push @stylesheet_params, split /:/, $val, 2;
		$i++;
	}

	return bless {
		uri => $opts{uri},
		content => scalar( $response->content ),
		content_type => scalar( $response->content_type ),
		md5_hex => Digest::MD5::md5_hex($response->content),
		mtime => scalar( $response->last_modified ),
		rayapp => $rayapp,
		code => scalar( $response->code ),
		redirect_location => scalar( $response->header('Location') ),
		( @stylesheet_params
			? ( stylesheet_params => \@stylesheet_params )
			: () ),

	}, $class;
}

sub uri { shift->{uri}; }
sub mtime { shift->{mtime}; }
sub content { shift->{content}; }
sub content_type { shift->{content_type}; }
sub rayapp { shift->{rayapp}; }
sub md5_hex { shift->{md5_hex}; }

sub errstr {
	my $self = shift;
	if (@_) {
		$self->{errstr} = shift;
		chomp $self->{errstr} if defined $self->{errstr};
	}
	return $self->{errstr};
}
sub clear_errstr {
	shift->errstr(undef);
	1;
}
sub find_stylesheets {
	return;
}
sub code {
	shift->{code} || return 200;
}
*status = \&code;
sub redirect_location {
	shift->{redirect_location};
}
sub stylesheet_params {
	my $self = shift;
	if (defined $self->{stylesheet_params}) {
		return @{ $self->{stylesheet_params} };
	}
	return;
}

1;

