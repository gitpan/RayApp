
package RayApp;

use strict;
use warnings;
use 5.008001;

$RayApp::VERSION = '2.002';

# print STDERR "RayApp version [$RayApp::VERSION]\n";

use URI::file ();
use XML::LibXML ();
use RayApp::UserAgent ();

# The constructor
sub new {
	my $class = shift;
	my $base = URI::file->cwd;
	my %options;
	my $ua_options = delete $options{ua_options};
	my $ua = new RayApp::UserAgent(
		defined($ua_options) ? %$ua_options : ()
	);
	my $self = bless {
		%options,
		base => $base,
		ua => $ua,
		}, $class;
	return $self;
}
# Errstr is either a class or instance method
sub errstr {
	my $self = shift;
	my $errstr;
	if (@_) {
		if (defined $_[0]) {
			$errstr = join ' ', @_;
			chomp $errstr;
		}
		if (ref $self) {
			$self->{errstr} = $errstr;
		} else {
			$RayApp::errstr = $errstr;
		}
	}
	if (ref $self) {
		return $self->{errstr};
	} else {
		return $RayApp::errstr;
	}
}
sub clear_errstr {
	shift->errstr(undef);
	1;
}

sub base {
	shift->{base};
}

# Loading content by URI
sub load_uri {
	my ($self, $uri, %options) = @_;
	$self->clear_errstr;

	# rewrite the URI to the absolute one
	$uri = URI->new_abs($uri, $self->{base});

	# print STDERR "Loading $uri in pid $$\n";

	# reuse cached file
	my $cached = $self->{uris}{$uri};
	if (defined $cached
		and defined $cached->mtime
		and $uri =~ m!^file:(//)?(/.*)$!) {
		my $filename = $2;

		my $cached_mtime = $cached->mtime;
		my $current_mtime = (stat $filename)[9];
		if ($cached_mtime == $current_mtime) {
			# print STDERR " + Reusing $uri [$cached_mtime] [$current_mtime]\n";
			return $cached;
		}

		# print STDERR " - Will have to reload $uri\n";
	}

	require RayApp::Source;
	my $data = new RayApp::Source(
		%options,
		rayapp => $self,
		uri => $uri,
	) or return;
	$self->{uris}{ $data->uri } = $data;
	return $data;
}

# Loading content by string
sub load_string {
	my ($self, $string, %options) = @_;
	$self->clear_errstr;

	require RayApp::String;
	my $data = new RayApp::String(
		%options,
		rayapp => $self,
		content => $string,
	) or return;
	$self->{uris}{ $data->uri } = $data;
	return $data;
}

# Loading URI expected to be XML
sub load_xml {
	my ($self, $uri, %options) = @_;

	require RayApp::XML;
	my $xml = new RayApp::XML(
		%options,
		rayapp => $self,
		uri => $uri,
	) or return;
	$self->{xmls}{ $xml->uri } = $xml;
	return $xml;
}

# Loading string expected to be XML
sub load_xml_string {
	my ($self, $string, %options) = @_;

	require RayApp::XML;
	my $xml = new RayApp::XML(
		%options,
		rayapp => $self,
		content => $string,
	) or return;
	$self->{xmls}{ $xml->uri } = $xml;
	return $xml;
}

# Loading URI expected to be DSD
sub load_dsd {
	my ($self, $uri) = (shift, shift);

	my $xml = $self->load_xml($uri, @_) or return;
        if ($xml->{is_dsd}) {
		return $xml;
	}

	$xml->parse_as_dsd() or return;
	$xml;
}

# Loading string expected to be DSD
sub load_dsd_string {
	my ($self, $string) = ( shift, shift );

	my $xml = $self->load_xml_string($string, @_) or return;
        if ($xml->{is_dsd}) {
		return $xml;
	}

	$xml->parse_as_dsd() or return;
	$xml;
}

# Using user agent
sub ua { shift->{ua}; }

# Using XML::LibXML parser
sub xml_parser {
	my $self = shift;
	if (not defined $self->{xml_parser}) {
		$self->{xml_parser} = new XML::LibXML;
		if (not defined $self->{xml_parser}) {
			$self->errstr("Error loading the XML::LibXML parser");
			return;
		}
		$self->{xml_parser}->line_numbers(1);
		# $self->{xml_parser}->keep_blanks(0);
	}
	$self->{xml_parser};
}

sub execute_application_cgi {
	my ($self, $application, @params) = @_;
	$self->{errstr} = undef;
	if (ref $application) {
		$application = $application->application_name;
	}       
	my $ret = eval {
		if (not defined $application) {
			die "Application name was not defined\n";
		}
		require $application;
		return &handler(@params);
	};
	if ($@) {
		print STDERR $@;
		my $errstr = $@;
		$errstr =~ s/\n$//;
		$self->{errstr} = $errstr;
		return 500;
	}
	return $ret;
}

sub execute_application_handler {
	my ($self, $application, @params) = @_;
	$self->{errstr} = undef;
	if (ref $application) {
		$application = $application->application_name;
	}       
	my $ret = eval {
		if (not defined $application) {
			die "Application name was not defined\n";
		}
		local *FILE;
		open FILE, $application or die "Error reading `$application': $!\n";
		local $/ = undef;
		my $content = <FILE>;
		close FILE or die "Error reading `$application' during close: $!\n";
		if (${^TAINT}) {
			$content =~ /^(.*)$/s and $content = $1;
		}
		my $max_num = $self->{max_handler_num};
		if (not defined $max_num) {
			$max_num = 0;
		}
		$self->{max_handler_num} = ++$max_num;
		my $appname = $application;
		utf8::decode($appname);
		{
		no warnings 'redefine';
		eval qq!#line 1 "$appname"\npackage RayApp::Root::pkg$max_num; ! 
			. $content
			or die "Compiling `$application' did not return true value\n";
		}
		my $handler = 'RayApp::Root::pkg' . $max_num . '::handler';
		$self->{handlers}{$application} = {
			handler => $handler,
		};
		no strict;
		return &{ $handler }(@params);
	};
	if ($@) {
		$self->errstr($@);
		return 500;
	}
	return $ret;
}

sub execute_application_handler_reuse {
	my ($self, $application, @params) = @_;
	$self->{errstr} = undef;
	if (ref $application) {
		$application = $application->application_name;
	}       
	my $ret = eval {
		if (not defined $application) {
			die "Application name was not defined\n";
		}
		my $handler;
		my $mtime = (stat $application)[9];
		if (defined $self->{handlers}{$application}
			and defined $self->{handlers}{$application}{mtime}
			and $self->{handlers}{$application}{mtime} == $mtime) {
			# print STDERR "Not loading\n";
			$handler = $self->{handlers}{$application}{handler};
		} else {        
			$handler = $application;
			$handler =~ s!([^a-zA-Z0-9])! ($1 eq '/') ? '::' : sprintf("_%02x", ord $1) !ge;
			my $package = 'RayApp::Root::pkn' . $handler;
			$handler = $package . '::handler';
			### print STDERR "Loading\n";

			local *FILE;
			open FILE, $application or die "Error reading `$application': $!\n";
			local $/ = undef;
			my $content = <FILE>;
			close FILE or die "Error reading `$application' during close: $!\n";
			if (${^TAINT}) {
				$content =~ /^(.*)$/s and $content = $1;
			}
			my $max_num = $self->{max_handler_num};
			if (not defined $max_num) {
				$max_num = 0;
			}
			## $content =~ s/(.*)/$1/s;
			$max_num++;
			{
			no warnings 'redefine';
			my $appname = $application;
			utf8::decode($appname);
			eval qq!package $package;\n#line 1 "$appname"\n!
				. $content
				or die "Compiling `$application' did not return true value\n";
			}
			$self->{handlers}{$application} = {
				handler => $handler,
				mtime => $mtime,
			};
		}
		no strict;
		return &{ $handler }(@params);
	};
	if ($@) {
		print STDERR $@;
		my $errstr = $@;
		$errstr =~ s/\n$//;
		$self->{errstr} = $errstr;
		return 500;
	}
	return $ret;
}

1;

