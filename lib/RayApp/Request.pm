
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
		for ($self->{'request'}->param) {
			$self->{'param'}{$_} = [ $self->{'request'}->param($_) ];
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
		if (defined $self->{'param'}{$name}) {
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
	delete $self->{'param'}{shift};
}
sub request_method {
	shift->{'r'}->method;
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

