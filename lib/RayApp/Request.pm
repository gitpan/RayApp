
use strict;
package RayApp::Request::CGI;
sub new {
	my $class = shift;
	eval 'use CGI ()';
	return bless { q => CGI->new }, $class;
}
sub user {
	return shift->remote_user;
}
sub remote_user {
	return shift->{'q'}->remote_user;
}
sub param {
	my $self = shift;
	my $name = shift;
	if (not defined $name) {
		return $self->{'q'}->param;
	}
	if (@_) {
		if (not defined $_[0]) {
			$self->{'q'}->delete($name);
			return;
		} elsif (ref $_[0] and ref $_[0] eq 'ARRAY') {
			$self->{'q'}->param($name, @{ $_[0] });
			return @{ $_[0] };
		} else {
			$self->{'q'}->param($name, @_);
			return @_;
		}
	}
	return $self->{'q'}->param($name);
}
sub delete {
	shift->{'q'}->delete(shift);
}
sub request_method {
	shift->{'q'}->request_method;
}
sub referer {
	shift->{'q'}->referer;
}
sub url {
	my $q = shift;
	my %opts = @_;
	for (keys %opts) {
		if (not /^-/) {
			$opts{'-' . $_} = delete $opts{$_};
		}
	}
	$q->{'q'}->url(%opts);
}

package RayApp::Request::APR;
sub new {
	my ($class, $r) = @_;
	eval 'use Apache::Request ()';
	return bless { r => $r, request => Apache::Request->new($r) }, $class;
}
sub user {
	return shift->{'r'}->user;
}
sub remote_user {
	return shift->{'r'}->user;
}
sub _init_param {
	my $self = shift;
	if (not defined $self->{'param'}) {
		$self->{'param'} = {};
		if ($self->{'r'}->method eq 'POST') {
			for ($self->{'request'}->param) {
				# a hack for bug in Apache::Request which was giving
				# us each value twice
				my %u;
				$self->{'param'}{$_} = [
					grep { not $u{$_}++ }
					$self->{'request'}->body($_)
				];
			}
		} else {
			for ($self->{'request'}->args) {
				# a hack for bug in Apache::Request which was giving
				# us each value twice
				my %u;
				$self->{'param'}{$_} = [
					grep { not $u{$_}++ }
					$self->{'request'}->args($_)
				];
			}
		}
	}
}
sub param {
	my $self = shift;
	if (not defined $self->{'param'}) {
		$self->_init_param;
	}
	my $name = shift;
	if (not defined $name) {
		return keys %{ $self->{'param'} };
	}
	if (@_) {
		if (not defined $_[0]) {
			delete $self->{'param'}{$name};
			return;
		} elsif (ref $_[0] and ref $_[0] eq 'ARRAY') {
			$self->{'param'}{$name} = [ @{ $_[0] } ];
			return @{ $_[0] };
		} else {
			$self->{'param'}{$name} = [ @_ ];
			return @_;
		}
	}
	if (wantarray) {
		if (defined $self->{'param'}{$name}) {
			return @{ $self->{'param'}{$name} };
		}
		return;
	} else {
		if (defined $self->{'param'}{$name}
			and @{ $self->{'param'}{$name} }) {
			return $self->{'param'}{$name}[0];
		}
		return;
	}
}
sub delete {
	my $self = shift;
	if (not defined $self->{'param'}) {
		$self->_init_param;
	}
	my $param = shift;
	delete $self->{'param'}{$param};
}
sub request_method {
	shift->{'r'}->method;
}
sub referer {
	shift->{'r'}->headers_in->{'Referer'};
}
use Apache::Connection ();
use APR::SockAddr ();
sub url {
	my $r = shift->{'r'};
	my %opts = @_;
	for (keys %opts) {
		if (/^-/) {
			my $updated = $_;
			$updated =~ s/^-//;
			$opts{$updated} = delete $opts{$_};
		}
	}

	my $uri = '';

	if (not keys %opts) {
		$opts{'full'} = 1;
	}
	my $protocol = 'http';
	my $c = $r->connection;
	my ($port) = $c->local_addr->port if defined $c;
	if ($port eq '443') {
		$protocol = 'https';
	}

	if ($opts{'full'} or $opts{'base'}) {
		$uri = $protocol . '://' .  $r->hostname;
		if ($protocol eq 'http' and $port ne 80) {
			$uri .= ':' . $port;
		}
		return $uri if $opts{'base'};
	}

	if ($opts{'full'} or $opts{'absolute'}) {
		$uri .= $r->uri;
	} elsif ($opts{'relative'}) {
		$uri = $r->uri;
		if ($uri =~ m!/$!) {
			$uri = './';
		} else {
			$uri =~ s!^.*/!!;
		}
	}
	if ($opts{'path'} or $opts{'path_info'}) {
		$uri .= $r->path_info;
	}

	if (defined $opts{'query'}) {
		my $query = $r->args;
		if (defined $query and $query ne '') {
			$uri .= '?' . $query;
		}
	}
	return $uri;
}

package RayApp::Request;

sub new {
	my ($class, $r) = @_;
	if (defined $r) {
		return new RayApp::Request::APR($r);
	} else {
		return new RayApp::Request::CGI;
	}
}

1;

