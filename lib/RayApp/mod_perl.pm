
package RayApp::mod_perl::TieSTDOUT;

sub TIEHANDLE {
	my ($class, $data) = @_;
	return bless $data, $class;
}
sub PRINT {
	my $self = shift;
	push @$self, @_;
}
sub PRINTF {
	my $self = shift;
	push @$self, sprintf @_;
}


package RayApp::mod_perl;

use RayApp ();
use Apache::Response ();
use Apache::Const -compile => qw(OK SERVER_ERROR DECLINED);
use APR::Table ();
use strict;
                                                                                
sub print_errors (@) {
	my $err_in_browser = pop;
	if ($err_in_browser) {
		print @_;
	}
	print STDERR @_;
}

my $rayapp;
sub handler {
	my $r = shift;

	my $uri;
	if (defined $ENV{'RAYAPP_DIRECTORY'}
		and defined $ENV{'PATH_INFO'}) {
		$uri = $ENV{'RAYAPP_DIRECTORY'} . $ENV{'PATH_INFO'};
	} else {
		$uri = $r->filename();
	}
	if (not defined $uri) {
		$uri = $ENV{'SCRIPT_FILENAME'};
	}
	if ($uri =~ m!/$!  and defined $ENV{'RAYAPP_DIRECTORY_INDEX'}) {
		$uri .= $ENV{'RAYAPP_DIRECTORY_INDEX'};
	}

	my $err_in_browser = ( defined $ENV{'RAYAPP_ERRORS_IN_BROWSER'}
		and $ENV{'RAYAPP_ERRORS_IN_BROWSER'} );

	if ($uri =~ /\.html$/ and -f $uri) {
		$r->filename($uri);
		return Apache::DECLINED;
	}

	$rayapp = new RayApp( 'cache' => 1 ) if not defined $rayapp;

	my @stylesheets;
	my $type;
	if ($uri =~ s/\.(html|txt)$//) {
		$type = $1;
		for my $ext ('.dsd', '.xml') {
			if (-f $uri . $ext) {
				$uri .= $ext;
				last;
			}
		}
		
		if ($type eq 'html'
			and defined $ENV{'RAYAPP_HTML_STYLESHEETS'}) {
			@stylesheets = split /:/, $ENV{'RAYAPP_HTML_STYLESHEETS'};
		} elsif ($type eq 'txt'
			and defined $ENV{'RAYAPP_TXT_STYLESHEETS'}) {
			@stylesheets = split /:/, $ENV{'RAYAPP_TXT_STYLESHEETS'};
		}
		if (not @stylesheets) {
			my $styleuri = $uri;
			$styleuri =~ s/\.[^\.]+$//;
			my @exts = ('.xsl', '.xslt');
			if ($type eq 'txt') {
				@exts = ('.txtxsl', '.txtxslt');
			}
			for my $ext (@exts) {
				if (-f $styleuri . $ext) {
					push @stylesheets, $styleuri . $ext;
					last;
				}
			}
		}
	} elsif ($uri =~ /\.xml$/ and not -f $uri) {
		my $tmpuri = $uri;
		$tmpuri =~ s/\.xml$/.dsd/;
		if (-f $tmpuri) {
			$uri = $tmpuri;
		}
	}

	my $dsd = $rayapp->load_dsd($uri);
	if (not defined $dsd) {
		$r->content_type('text/plain');
		print "Broken RayApp setup, failed to load DSD, sorry.\n";
		print_errors "Loading DSD [$uri] failed: ",
			$rayapp->errstr, "\n", $err_in_browser;
		return Apache::SERVER_ERROR;
	}
	my $application = $dsd->application_name;
	if (not defined $application) {
		my $appuri = $uri;
		$appuri =~ s/\.[^\.]+$//;
		my $ok = 0;
		for my $ext ('.pl', '.mpl', '.xpl') {
			if (-f $appuri . $ext) {
				$application = $appuri . $ext;
				$ok = 1;
				last;
			}
		}
		if (not $ok) {
			$r->content_type('text/plain');
			print "Broken RayApp setup, failed to find application, sorry.\n";
			return Apache::SERVER_ERROR;
		}
	}
	my @params;
	if (defined $ENV{'RAYAPP_INPUT_MODULE'}) {
		eval "use $ENV{'RAYAPP_INPUT_MODULE'};";
		if ($@) {
			$r->content_type('text/plain');
			print "Broken RayApp setup, failed to load input module, sorry.\n";
			print_errors "Error loading [$ENV{'RAYAPP_INPUT_MODULE'}]\n",
				$@, $err_in_browser;
			return Apache::SERVER_ERROR;
		}

		my $handler = "$ENV{'RAYAPP_INPUT_MODULE'}::handler";
		{
		no strict;
		eval { @params = &{ $handler }($dsd, $r); };
		}
		if ($@) {
			$r->content_type('text/plain');
			print "Broken RayApp setup, failed to run input module, sorry.\n";
			print_errors "Error executing [$ENV{'RAYAPP_INPUT_MODULE'}]\n",
				$@, $err_in_browser;
			return Apache::SERVER_ERROR;
		}
	}
	my @style_params;
	if (defined $ENV{'RAYAPP_STYLE_PARAMS_MODULE'}) {
		eval "use $ENV{'RAYAPP_STYLE_PARAMS_MODULE'};";
		if ($@) {
			$r->content_type('text/plain');
			print "Broken RayApp setup, failed to load style params module, sorry.\n";
			print_errors "Error loading [$ENV{'RAYAPP_STYLE_PARAMS_MODULE'}]\n",
				$@, $err_in_browser;
			return Apache::SERVER_ERROR;
		}

		my $handler = "$ENV{'RAYAPP_STYLE_PARAMS_MODULE'}::handler";
		{
		no strict;
		eval { @style_params = &{ $handler }($dsd, @params); };
		}
		if ($@) {
			$r->content_type('text/plain');
			print "Broken RayApp setup, failed to run style params module, sorry.\n";
			print_errors "Error executing [$ENV{'RAYAPP_STYLE_PARAMS_MODULE'}]\n",
				$@, $err_in_browser;
			return Apache::SERVER_ERROR;
		}
	}

	my $tied = tied *STDOUT;
	my @stdout_data;
	my $data;
	my $err;

	{
		local *STDOUT;
		binmode STDOUT, ':bytes';
		tie *STDOUT, 'RayApp::mod_perl::TieSTDOUT', \@stdout_data;

		eval { $data = $rayapp->execute_application_handler_reuse($application, @params) };
		$err = $@;
		if ($tied) {
			tie *STDOUT, $tied;
		} else {
			untie *STDOUT;
		}
	}
	for (@params) {
		if (defined $_ and ref $_ and $_->can('disconnect')) {
			eval { $_->rollback; };
			eval { $_->disconnect; };
		}
	}
	if ($err) {
		$r->content_type('text/plain');
		print "Broken RayApp setup, failed to run the application, sorry.\n";
		print_errors "Error executing [$application]\n",
			$err, $err_in_browser;
		return Apache::SERVER_ERROR;
	}

	if (not ref $data and $data eq '500') {
		$r->content_type('text/plain');
		print "Broken RayApp setup, failed to run the application, sorry.\n";
		print_errors "Error executing [$application]\n",
			$rayapp->errstr, $err_in_browser;
		return Apache::SERVER_ERROR;
	}

	if (not ref $data) {
		# handler already sent the response itself, we've got it
		# in @stdout_data
		$r->status($data);
		$r->send_cgi_header(join '', @stdout_data);
		return Apache::OK;
	}

	$r->headers_out->{'Pragma'} = 'no-cache';
	$r->headers_out->{'Cache-control'} = 'no-cache';

	if (not @stylesheets) {
		my $output = $dsd->serialize_data($data, { RaiseError => 0 });
		if ($dsd->errstr) {
			$r->content_type('text/plain');
			print "Broken RayApp setup, data serialization failed, sorry.\n";
			print_errors "Serialization failed for [$0]: ",
				$dsd->errstr, "\n", $err_in_browser;
			return Apache::SERVER_ERROR;
		}
		$r->content_type('text/xml');
		print $output;
		return Apache::OK;
	} else {
		my ($output, $media, $charset) = $dsd->serialize_style($data,
			{
				'rayapp' => $rayapp,
				( scalar(@style_params)
					? ( style_params => \@style_params )
					: () ),
				RaiseError => 0,
			},
			@stylesheets);

		if ($dsd->errstr or not defined $output) {
			$r->content_type('text/plain');
			print "Broken RayApp setup, failed to serialize and style your data, sorry.\n";
			print_errors
				"Serialization and styling failed for [$0]: ",
				$dsd->errstr, "\n", $err_in_browser;
			return Apache::SERVER_ERROR;
		}
		if (defined $media) {
			if (defined $charset) {
				$media .= "; charset=$charset";
			}
			$r->content_type($media);
		}
		print $output;
		return Apache::OK;
	}
	return Apache::SERVER_ERROR;
}

1;

