
package RayApp::CGI;

use RayApp ();
use strict;

sub print_errors (@) {
	my $err_in_browser = pop;
	if ($err_in_browser) {
		print @_;
	}
	print STDERR @_;
}

sub handler {
	my $uri;
	if (@ARGV) {
		$uri = shift @ARGV;
	} elsif (defined $ENV{'RAYAPP_DIRECTORY'}) {
		$uri = $ENV{'RAYAPP_DIRECTORY'};
		$uri .= $ENV{'PATH_INFO'} if defined $ENV{'PATH_INFO'};
		$ENV{'SCRIPT_NAME'} = $ENV{'REQUEST_URI'};
		delete $ENV{'PATH_INFO'};
		$ENV{'PATH_TRANSLATED'} = $uri;
	} else {
		$uri = $ENV{'SCRIPT_FILENAME'};
		if (defined $uri and defined $ENV{'SCRIPT_NAME'}) {
			my ($fnameext) = ($uri =~ /\.(.+?)$/);
			my ($nameext) = ($ENV{'SCRIPT_NAME'} =~ /\.(.+?)$/);
			if ($fnameext ne $nameext) {
				$uri =~ s/\..+?$/.$nameext/;
			}
		}
	}
	if (not defined $uri) {
		$uri = $0;
		if ($uri =~ s/\.(mpl|pl)$//) {
			for my $ext ('.dsd', '.xml') {
				if (-f $uri . $ext) {
					$uri .= $ext;
					last;
				}
			}
		}
	}
        ### if (($uri =~ m!/$! or -d $uri)
        if ($uri =~ m!/$! and defined $ENV{'RAYAPP_DIRECTORY_INDEX'}) {
                ### $uri .= '/' unless $uri =~ m!/$!;
                $uri .= $ENV{'RAYAPP_DIRECTORY_INDEX'};
        }


	# print STDERR "Called RayApp::CGI with uri [$uri]\n";

	my $err_in_browser = ( defined $ENV{'RAYAPP_ERRORS_IN_BROWSER'}
		and $ENV{'RAYAPP_ERRORS_IN_BROWSER'} );

	if ($uri =~ /\.html$/ and -f $uri) {
		local *FILE;
		open FILE, $uri or do {
			print_errors "Error reading [$uri]: $!\n", $err_in_browser;
			print "Status: 404\n\n";
			exit;
		};
		local $/ = undef;
		print "Status: 200\nContent-Type: text/html\n\n";
		print <FILE>;
		close FILE;
		exit;
	}

	my $rayapp = new RayApp;

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
		print "Status: 500\nContent-Type: text/plain\n\nBroken RayApp setup, failed to load DSD, sorry.\n";
		print_errors "Loading DSD [$uri] failed: ",
			$rayapp->errstr, "\n", $err_in_browser;
		exit;
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
			print "Status: 500\nContent-Type: text/plain\n\nBroken RayApp setup, failed to find application, sorry.\n";
			exit;
		}
	}
	my @params;
	if (defined $ENV{'RAYAPP_INPUT_MODULE'}) {
		eval "use $ENV{'RAYAPP_INPUT_MODULE'};";
		if ($@) {
			print "Status: 500\nContent-Type: text/plain\n\nBroken RayApp setup, failed to load input module, sorry.\n";
			print_errors "Error loading [$ENV{'RAYAPP_INPUT_MODULE'}]\n",
				$@, $err_in_browser;
			exit;	
		}

		my $handler = "$ENV{'RAYAPP_INPUT_MODULE'}::handler";
		{
		no strict;
		eval { @params = &{ $handler }($dsd); };
		}
		if ($@) {
			print "Status: 500\nContent-Type: text/plain\n\nBroken RayApp setup, failed to run input module, sorry.\n";
			print_errors "Error executing [$ENV{'RAYAPP_INPUT_MODULE'}]\n",
				$@, $err_in_browser;
			exit;	
		}
	}
	my @style_params;
	if (defined $ENV{'RAYAPP_STYLE_PARAMS_MODULE'}) {
		eval "use $ENV{'RAYAPP_STYLE_PARAMS_MODULE'};";
		if ($@) {
			print "Status: 500\nContent-Type: text/plain\n\nBroken RayApp setup, failed to load style params module, sorry.\n";
			print_errors "Error loading [$ENV{'RAYAPP_STYLE_PARAMS_MODULE'}]\n",
				$@, $err_in_browser;
			exit;	
		}

		my $handler = "$ENV{'RAYAPP_STYLE_PARAMS_MODULE'}::handler";
		{
		no strict;
		eval { @style_params = &{ $handler }($dsd, @params); };
		}
		if ($@) {
			print "Status: 500\nContent-Type: text/plain\n\nBroken RayApp setup, failed to run style params module, sorry.\n";
			print_errors "Error executing [$ENV{'RAYAPP_STYLE_PARAMS_MODULE'}]\n",
				$@, $err_in_browser;
			exit;	
		}
	}

	my $data;
	eval { $data = $rayapp->execute_application_cgi($application, @params) };
	if (@params
		and defined $params[0]
		and ref $params[0]
		and $params[0]->can('disconnect')) {
		eval { $params[0]->rollback; };
		$params[0]->disconnect;
	}
	if ($@) {
		print "Status: 500\nContent-Type: text/plain\n\nBroken RayApp setup, failed to run the application, sorry.\n";
		print_errors "Error executing [$application]\n",
			$@, $err_in_browser;
		exit;	
	}

	if (not ref $data and $data eq '500') {
		print "Status: 500\nContent-Type: text/plain\n\nBroken RayApp setup, failed to run the application, sorry.\n";
		print_errors "Error executing [$application]\n",
			$rayapp->errstr, $err_in_browser;
		exit;	
	}

	if (not ref $data) {
		# handler already sent the response itself
		exit;
	}

	if (not @stylesheets) {
		my $output = $dsd->serialize_data($data, { RaiseError => 0 });
		if ($dsd->errstr) {
			print "Status: 500\nContent-Type: text/plain\n\nBroken RayApp setup, data serialization failed, sorry.\n";
			print_errors "Serialization failed for [$0]: ",
				$dsd->errstr, "\n", $err_in_browser;
			exit;
		}
		print "Status: 200\n";
		print "Pragma: no-cache\nCache-control: no-cache\n";
		print "Content-Type: text/xml\n\n", $output;
	} else {
		my ($output, $media, $charset) = $dsd->serialize_style($data,
			{
				( scalar(@style_params)
					? ( style_params => \@style_params )
					: () ),
				RaiseError => 0,
			},
			@stylesheets);

		if ($dsd->errstr or not defined $output) {
			print "Status: 500\nContent-Type: text/plain\n\nBroken RayApp setup, failed to serialize and style your data, sorry.\n";
			print_errors
				"Serialization and styling failed for [$0]: ",
				$dsd->errstr, "\n", $err_in_browser;
			exit;
		}
		print "Status: 200\n";
		if (defined $media) {
			if (defined $charset) {
				$media .= "; charset=$charset";
			}
			print "Pragma: no-cache\nCache-control: no-cache\n";
			print "Content-Type: $media\n\n";
		}
		print $output;
		exit;
	}
	exit;
}

1;

