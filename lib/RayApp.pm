
package RayApp;
use strict;
use URI::file ();

$RayApp::VERSION = '1.110';

sub new {
	my $class = shift;
	my $self = bless { @_ }, $class;
	if (not defined $self->{base}) {
		$self->{base} = URI::file->cwd;
	}
	return $self;
}
sub errstr {
	my $self = shift;
	return ( ref $self ? $self->{errstr} : $RayApp::errstr );
}

sub load_dsd {
	my ($self, $uri) = @_;
	$self->{errstr} = undef;
	$uri = URI->new_abs($uri, $self->{base});

	my $ret = eval {
		my $dsd = $self->load_dsd_uri($uri);
		return $self->parse_dsd($dsd);
	};

	if ($@) {
		$self->{errstr} = $@;
		$self->{errstr} =~ s/\n+$//;
		return;
	}
	return $ret;
}

use LWP::UserAgent ();
sub load_user_agent {
	my $self = shift;
	my %uaoptions;
	if (defined $self->{ua_options}) {
		%uaoptions = %{ $self->{ua_options} };
	}
	$self->{ua} = new LWP::UserAgent(%uaoptions)
		or die "Error loading user agent\n";
	return 1;
}

use Digest::MD5 ();
sub load_dsd_uri {
	my ($self, $uri) = @_;
	if (not defined $self->{ua}) {
		$self->load_user_agent();
	}
	my $response = $self->{ua}->get($uri);
	if ($response->is_error) {
		if (defined $response->{_msg}) {
			die $response->{_msg} . "\n";
		}
		die $response->error_as_html() . "\n";
	}
	return {
		'uri' => $uri,
		'content' => $response->content,
		'md5_hex' => Digest::MD5::md5_hex($response->content),
		};
}

sub load_dsd_string {
	my $self = shift;
	$self->{errstr} = undef;
	my $md5_hex = Digest::MD5::md5_hex($_[0]);
	my $ret = eval {
		$self->parse_dsd({
			'uri' => "md5:$md5_hex",
			'content' => $_[0],
			'md5_hex' => $md5_hex,
			});
	};
	if ($@) {
		$self->{errstr} = $@;
		$self->{errstr} =~ s/\n+$//;
		return;
	}
	return $ret;
}

use XML::LibXML ();
sub parse_dsd {
	my ($self, $dsd) = @_;
	if (not defined $self->{parser}) {
		$self->{parser} = new XML::LibXML;
		if (not defined $self->{parser}) {
			die "Error loading the XML::LibXML parser\n";
		}
		$self->{parser}->line_numbers(1);
		# $self->{parser}->keep_blanks(0);
	}

	my $dom = $dsd->{dom} = $self->{parser}->parse_string($dsd->{content});
	if ($dom->encoding) {
		$dom->setEncoding('UTF-8');
	}

	bless $dsd, 'RayApp::DSD';
	my ($copy_attribs, $translate_attribs) = ( {}, {} );
	$dsd->tidy_dsd_dom($dom, 0, 0, $copy_attribs, $translate_attribs);
	while ( keys %{ $dsd->{typerefs} }) {
		my $refpointer = ( keys %{ $dsd->{typerefs} } )[0];
		my ($node, $id, $ln, $idpointer, $clone,
			$subdsd, $subpointer);
		my %visited;
		while (defined $refpointer) {
			($node, $id, $ln) = @{ $dsd->{typerefs}{$refpointer} };
			if ($id =~ /^([^#]+)#?(.*)$/s) {
				my ($uri, $remoteid) = ($1, $2);
				if ($dsd->{'uri'} =~ /^md5:/) {
					$uri = URI->new_abs($uri, $self->{base});
				} else {
					$uri = URI->new_abs($uri, $dsd->{uri});
				}
				if (defined $self->{'parsing'}{ $dsd->{'uri'} }) {
					die "Circular dependency detected at $dsd->{'uri'}\n";
				}
				$self->{'parsing'}{ $dsd->{'uri'} } = 1;
				$subdsd = $self->load_dsd($uri);
				delete $self->{parsing}{ $dsd->{uri} };
				if (not defined $subdsd) {
					die "Error loading DSD $uri referenced from line $ln: $self->{'errstr'}\n";
				}

				my $subnode;
				if (defined $remoteid and $remoteid ne '') {
					if (not defined $subdsd->{id}{$remoteid}) {
						die "Remote DSD $uri does not provide id $remoteid referenced from line $ln\n";
					}
					($subnode, $subpointer) =
						@{ $subdsd->{id}{$remoteid} };
				} else {
					($subnode, $subpointer) =
						@{ $subdsd->{rootelement} };
				}

				$clone = $subnode->cloneNode(1);

				$id = undef;
				last;
			}
			$id =~ s/^#//;
			if (not defined $dsd->{id}{$id}) {
				die "No local id $id found for reference from line $ln\n";
			}

			my $idpointer = $dsd->{id}{$id}[1];
			my $newref = $dsd->{idpointer}{$idpointer}[1];
			if (defined $newref
				and not defined $dsd->{typerefs}{$newref}) {
				splice @{ $dsd->{idpointer}{$idpointer} }, 1, 1;
				redo;
			}
			if (not defined $newref) {
				last;
			}
			$refpointer = $newref;

			if (defined $visited{$id}) {
				die "Loop detected while expanding typeref $id from line $ln\n";
			}
			$visited{$id} = 1;
		}

		if (defined $id) {
			$clone = $dsd->{id}{$id}[0]->cloneNode(1);
			$subdsd = $dsd;
			$subpointer = $dsd->{id}{$id}[1];
		}

		$clone->setNodeName($node->nodeName);
		$node->replaceNode($clone);
		delete $dsd->{typerefs}{$refpointer};

		for my $ph (keys %{ $subdsd->{placeholders} }) {
			if ($ph eq $subpointer) {
				$dsd->{placeholders}{$refpointer}{type}
					= $subdsd->{placeholders}{$ph}{type};
				# FIXME: and maybe others
			}
			if ($ph =~ /^$subpointer(:.+)/) {
				my $subid = $1;
				$dsd->{placeholders}{$refpointer . $subid}
					 = { %{ $subdsd->{placeholders}{$ph} } };
			}
		}
	}

	return $self->{uris}{$dsd->{uri}} = $dsd;
}

my %DATA_ATTRIBUTES = (
	'type' => {
		'int' => 'int',
		'integer' => 'int',
		'num' => 'num',
		'number' => 'num',
		'string' => 'string',
		'hash' => 'hash',
		'struct' => 'hash',
		'' => 'string',
	},
	'mandatory' => {
		'yes' => 'yes',
		'no' => 'no',
		'' => 'no',
	},
	'multiple' => {
		'list' => 'list',
		'listelement' => 'listelement',
		'hash' => 'hash',
		'hashelement' => 'hashelement',
		'' => 'no',
	},
	'hashorder' => {
		'num' => 'num',
		'string' => 'string',
		'natural' => 'natural',
		'' => 'natural',
	},
	'cdata' => {
		'yes' => 'yes',
		'no' => 'no',
		'' => 'no',
	},
);


my %PARAM_ATTRIBUTES = (
	'type' => $DATA_ATTRIBUTES{'type'},
	'multiple' => {
		'yes' => 'yes',
		'no' => 'no',
		'' => 'no',
	},
);

sub removeChildNodeNicely {
	my ($node, $child) = @_;
	my $o = $child;
	while (defined($o = $o->previousSibling)) {
		last if $o->nodeType != 3;
		my $value = $o->nodeValue;
		$value =~ s/(\n[ \t]*)+$//g
			and $o->setData($value);
	}
	$o = $child;
	while (defined($o = $o->nextSibling)) {
		last if $o->nodeType != 3;
		my $value = $o->nodeValue;
		$value =~ s/\s+(\n[ \t]*)$/$1/
			and $o->setData($value);
	}

	$node->removeChild($child);
}

sub execute_application_handler {
	my ($self, $application) = @_;
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
		my $max_num = $self->{max_handler_num};
		if (not defined $max_num) {
			$max_num = 0;
		}
		## $content =~ s/(.*)/$1/s;
		$self->{max_handler_num} = ++$max_num;
		eval "package RayApp::Root::pkg$max_num; " . $content
			or die "Compiling `$application' did not return true value\n";
		my $handler = 'RayApp::Root::pkg' . $max_num . '::handler';
		$self->{handlers}{$application} = {
			handler => $handler,
		};
		no strict;
		return &{ $handler };
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

sub execute_application_handler_reuse {
	my $self = shift;
	$self->{errstr} = undef;
	my $application = shift;
	if (ref $application) {
		$application = $application->application_name;
	}       
	my $ret = eval {
		if (not defined $application) {
			die "Application name was not defined\n";
		}
		my $handler;
		if (defined $self->{handlers}{$application}) {
			### print STDERR "Not loading\n";
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
			my $max_num = $self->{max_handler_num};
			if (not defined $max_num) {
				$max_num = 0;
			}
			## $content =~ s/(.*)/$1/s;
			$max_num++;
			eval "package $package; " . $content
				or die "Compiling `$application' did not return true value\n";
			$self->{handlers}{$application} = {
				handler => $handler,
			};
		}
		no strict;
		return &{ $handler };
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

sub execute_application_process_storable {
	my $self = shift;
	$self->{errstr} = undef;
	my $application = shift;
	if (ref $application) {
		$application = $application->application_name;
	}       
	my $ret = eval {
		if (not defined $application) {
			die "Application name was not defined\n";
		}
		require Storable;
		my $inc = join ' ', map "-I$_", @INC;   
		my $value = `$^X $inc -MRayApp::CGIStorable $application`;
		if ($value =~ s!^Content-Type: application/x-perl-storable\n\n!!) {
			my $data = Storable::thaw($value);
			return $data;
		}
		return;
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

package RayApp::DSD;

sub process_param_element {
	my ($self, $node, $parent, $ln) = @_;
	my %attributes = ();
	for my $attr ( $node->attributes ) {
		$attributes{ $attr->nodeName } = $attr->getValue;
	}
	my %o = ( ln => $ln );
	my $myname;
	if (defined $attributes{'prefix'}) {
		$o{'prefix'} = delete $attributes{'prefix'};
		$myname = "with prefix $o{'prefix'}";
	} elsif (defined $attributes{'name'}) {
		$o{'name'} = delete $attributes{'name'};
		$myname = $o{'name'};
	} else {
		die "Parameter specification lacks attribute name at line $ln\n";
	}
	
	if (defined $attributes{'name'}) {
		die "Exactly one of attributes prefix or name is allowed for param at line $ln\n";
	}
	for my $key (keys %PARAM_ATTRIBUTES) {
		my $at = delete $attributes{$key};
		if (defined $at and not exists $PARAM_ATTRIBUTES{$key}{$at}) {
			die "Unknown $key $at for parameter $myname at line $ln\n";
		}
		if (not defined $at) {
			$at = '';
		}
		$o{$key} = $PARAM_ATTRIBUTES{$key}{$at};
	}
	if (keys %attributes) {
		die "Unsupported attribute"
			. ( keys %attributes > 1 ? 's ' : ' ' )
			. join(', ', sort keys %attributes)
			. " in parameter $myname at line $ln\n";
	}

	if (defined $o{'prefix'}) {
		if (defined $self->{'paramprefix'}{$o{'prefix'}}) {
			die "Duplicate prefix $o{'prefix'} param specification at line $ln\n";
		}
		$self->{'paramprefix'}{$o{'prefix'}} = { %o };
	} elsif (defined $o{'name'}) {
		if (defined $self->{'param'}{$o{'name'}}) {
			die "Duplicate specification of parameter $o{'name'} at line $ln, previous at line $self->{'param'}{$o{'name'}}{'ln'}\n";
		}
		$self->{'param'}{$o{'name'}} = { %o };
	}
	return;
}

sub remove_children_from_leaf {
	my $node = shift;
	my $child = $node->firstChild;
	while (defined $child) {
		if ($child->nodeType != 3) {	# text nodes have type 3
			return 0;
		}
		$child = $child->nextSibling;
	}
	$node->removeChildNodes;
	return 1;
}

sub tidy_dsd_dom {
	my ($self, $node, $pointer, $inside_placeholder,
		$copy_attribs_in, $translate_attribs_in) = @_;

	my $copy_attribs = { %{ $copy_attribs_in } };
	my $translate_attribs = { %{ $translate_attribs_in } };

	my $type = $node->nodeType;
	my $name;
	if ($type == 1) {
		$name = $node->nodeName;
	}
	my $parent = $node->parentNode();
	my $ln = $node->line_number;

	if ($type == 1) {			# elements have type 1
		my $is_root = 0;
		if (not exists $self->{'application'}) {
			$is_root = 1;
			$self->{'application'} = $node->getAttribute('application');
			$self->{'rootelement'} = [ $node, $pointer ];
		}

		my $is_leaf = remove_children_from_leaf($node);
		if ($name eq '_param') {	# process and remove params
			if ($is_root) {
				die "Root element cannot be parameter element at line $ln\n";
			}
			$self->process_param_element($node, $parent, $ln);
			return 0;
		}
		if ($name eq '_data') {
			my $nameattr = $node->getAttributeNode('name');
			if (not defined $nameattr) {
				die "Data specification lacks attribute name at line $ln\n";
			}
			$node->removeAttribute('name');
			$node->setNodeName($name = $nameattr->getValue);
		}

		my %attributes = ();
		for my $attr ( $node->attributes ) {
			$attributes{ $attr->nodeName } = $attr->getValue;
		}

		if (defined $attributes{'attrs'}) {
			for my $n (split /\s+/, $attributes{'attrs'}) {
				next if $n eq '';
				$copy_attribs->{$n} = 1;
			}
		}
		if (defined $attributes{'xattrs'}) {
			my $name = undef;
			my $i = 0;
			for my $v (split /\s+/, $attributes{'xattrs'}) {
				next if ($i == 0 and $v eq '');
				if ($i == 0) {
					$name = $v;
					$i++;
				} else {
					$translate_attribs->{$name} = $v;
					$i = 0;
				}
			}
			if ($i) {
				die "Specify even number of values in xattrs at line $ln\n";
			}
		}

		if ($is_leaf and defined $attributes{'typeref'}) {
			$self->{typerefs}{$pointer} = [ $node, $attributes{'typeref'}, $ln ];
			my @ptrs = split /:/, $pointer;
			for my $i (0 .. $#ptrs) {
				my $parpointer = join ':', @ptrs[0 .. $i];
				if (defined $self->{idpointer}{$parpointer}) {
					push @{$self->{idpointer}{$parpointer}},
						$pointer;

				}
			}
		}
		if (defined $attributes{'id'}) {
			$self->{id}{$attributes{'id'}} = [ $node, $pointer ];
			$self->{idpointer}{$pointer} = [ $attributes{'id'} ];
		}

		if (defined( my $id = $attributes{'id'} )) {
			if (defined $self->{'ids'}{$id}) {
				die "Duplicate id specification at line $ln, previous at line $self->{'ids'}{$id}[2]\n";
			}
			$self->{'ids'}{$id} = [ $node, $pointer, $ln ];
		}

		for my $n (keys %attributes) {
			if (not defined $copy_attribs->{$n}) {
				$node->removeAttribute($n);
			}
		}
		for my $n (keys %{ $translate_attribs }) {
			if (exists $attributes{$n}) {
				$node->setAttribute($translate_attribs->{$n},
					$attributes{ $n });	
			}
		}

		if ($inside_placeholder
			or $name eq '_data'
			or defined $attributes{'type'}
			or defined $attributes{'multiple'}
			or $is_leaf) {		# process placeholders

			my %o = ();

			for my $key (keys %DATA_ATTRIBUTES) {
				my $at = $attributes{$key};
				if (defined $at
					and not exists $DATA_ATTRIBUTES{$key}{$at}) {
					die "Unknown $key $at for data value at line $ln\n";
				}
				if (not defined $at) {
					$at = '';
				}
				$o{$key} = $DATA_ATTRIBUTES{$key}{$at};
			}
			if ($is_root) {
				if ($o{'multiple'} eq 'list'
					or $o{'multiple'} eq 'hash') {
					die "Root element cannot be $o{'multiple'} without listelement at line $ln\n";
				}
			}
			if (defined $attributes{'if'}) {
				die "Unsupported attribute if in data $name at line $ln\n";
			}
			if (defined $attributes{'idattr'}) {
				if ($o{'multiple'} ne 'hash'
					and $o{'multiple'} ne 'hashelement') {
					die "Attribute idattr is invalid for data which is not multiple hash at line $ln\n";
				}
				$o{'idattr'} = $attributes{'idattr'};
			} else {
				$o{'idattr'} = 'id';
			}

			if (not defined $attributes{'type'}) {
				if (not $is_leaf) {
					$o{'type'} = 'hash';
				}
			}
			$self->{'placeholders'}{$pointer} = {
				%o,
				'name' => $name,
				'ln' => $ln
			};

			if (not $inside_placeholder) {
				push @{ $self->{'toplevelph'}{$name} }, $pointer;
			}

			$inside_placeholder = 1;

			if ($o{'multiple'} eq 'listelement') {
				for my $child ($node->childNodes) {
					if ($child->nodeType == 1) {
						$child->setAttribute('multiple',
							'list');
					}
				}
			} elsif ($o{'multiple'} eq 'hashelement') {
				for my $child ($node->childNodes) {
					if ($child->nodeType == 1) {
						$child->setAttribute('multiple',
							'hash');
						$child->setAttribute('hashorder',
							$o{'hashorder'});
						$child->setAttribute('idattr',
							$o{'idattr'});
					}
				}
			}
		} else {
			for my $i ('if', 'ifdef', 'ifnot', 'ifnotdef') {
				if (defined $attributes{$i}) {
					if ($is_root) {
						die "Root element cannot be conditional at line $ln\n";
					}
					if (defined $self->{'ifs'}{$pointer}) {
						die "Multiple conditions are not supported at line $ln\n";
					}
					$self->{'ifs'}{$pointer} = [ $i, $attributes{$i} ];
					push @{ $self->{'toplevelph'}{$attributes{$i}} }, $pointer;
					delete $attributes{$i};
				}
			}
		}

		for my $k (keys %attributes) {
			next if defined $translate_attribs->{$k};
			next if defined $copy_attribs->{$k};
			next if defined $DATA_ATTRIBUTES{$k};
			next if $k eq 'attrs' or $k eq 'xattrs';
			next if $k eq 'id';
			next if $k eq 'idattr' and $inside_placeholder;
			next if $is_root and $k eq 'application';
			next if $is_leaf and $k eq 'typeref';
			die "Unsupported attribute $k at line $ln\n";
		}
	}

	my $i = 0;
	for my $child ($node->childNodes) {
		my $ret = $self->tidy_dsd_dom($child, "$pointer:$i",
			$inside_placeholder,
			$copy_attribs, $translate_attribs);
		if ($ret) {
			$i++;
		} else {
			RayApp::removeChildNodeNicely($node, $child);
		}
	}
	return 1;
}

sub errstr {
	return shift->{errstr};
}

sub uri {
	return shift->{uri};
}

sub md5_hex {
	return shift->{md5_hex};
}

sub params {
        return shift->{param};
}

sub param_prefixes {
        return shift->{paramprefix};
}

sub application_name {
	my $self = shift;
	my $uri = URI->new_abs($self->{application}, $self->{uri});
	if (not $uri =~ s/^file://) {
		return;
	}
	return $uri;
}

sub out_content {
	my $self = shift;
	$self->{errstr} = undef;
	return $self->{dom}->toString;
}

sub serialize_data {
	my $self = shift;
	my $value = $self->serialize_data_dom(@_);
	if (not defined $value or not ref $value) {
		return;
	}
	return $value->toString;
}

sub serialize_data_dom {
	my ($self, $data, $opts) = @_;
	$opts = {} unless defined $opts;
	$opts->{RaiseError} = 1 unless defined $opts->{RaiseError};

	my $dom = $self->{dom};
	my $cloned = $dom->cloneNode(1);

	$self->{'errstr'} = '';
	$self->serialize_data_node($cloned, $data, $opts, $cloned, '0');
	for my $k (sort keys %$data) {
		if (not exists $self->{toplevelph}{$k}) {
			$self->{errstr} .= "Data {$k} does not match data structure description\n";
		}
	}

	if (defined $opts->{'doctype'} or defined $opts->{'doctype_ext'}) {
		my $uri = $opts->{'doctype'};
		if (not defined $uri) {
			$uri = URI->new($self->{'uri'})->rel($self->{'uri'});
			$opts->{'doctype_ext'} =~ s/^([^.])/.$1/;
			$uri =~ s/\.[^.]+$/$opts->{'doctype_ext'}/;
		}

		my $root = $self->{'rootelement'}[0]->nodeName;
		my $dtd = $cloned->createInternalSubset($root, undef, $uri);
		### print STDERR "Adding DTD [@{[ $dtd->toString ]}] for [$uri]\n";
	}

	if (defined $opts->{validate} and $opts->{validate}) {
		my $dtd = $self->get_dtd;
		my $ret;
		eval {
			my $parsed_dtd = XML::LibXML::Dtd->parse_string($dtd);
			### print STDERR $cloned->toString;
			my $parser = new XML::LibXML;
			$parser->keep_blanks(0);
			my $parsed = $parser->parse_string($cloned->toString);
			$ret = $parsed->validate($parsed_dtd);
		};
		if ($@) {
			$self->{errstr} = $@;
		} elsif (not $ret) {
			$self->{errstr} = "The result is not valid, but no reason given.\n";
		}
	}

	if ($self->{'errstr'} eq '') {	# FIXME, remove the zero
		$self->{'errstr'} = undef;
	} else {
		my $errstr = $self->{'errstr'};
		if (not $self->{'errstr'} =~ /\n./) {
			$self->{'errstr'} =~ s/\n$//;
		}
		if ($opts->{RaiseError}) {
			die $errstr;
		}
	}

	return $cloned;
}

sub bind_data {
	my ($self, $dom, $node, $pointer, $data, $showname, $inmulti) = @_;
	my $spec = $self->{'placeholders'}{$pointer};
	if (not defined $data) {
		if ($spec->{'mandatory'} eq 'yes') {
			$self->{errstr} .= "No value of $showname for mandatory data element defined at line $spec->{'ln'}\n";
		}
		RayApp::removeChildNodeNicely($node->parentNode, $node);
		return 0;
	} elsif ($spec->{'multiple'} eq 'listelement'
			or $spec->{'multiple'} eq 'hashelement') {
		my $i = 0;
		for my $child ($node->childNodes) {
			if ($child->nodeType == 1) {
				$self->bind_data($dom, $child, "$pointer:$i",
					$data, $showname, 0);
			}
			$i++;
		}
	} elsif ($inmulti == 0 and $spec->{'multiple'} eq 'list') {
		if (not ref $data or ref $data ne 'ARRAY') {
			$self->{errstr} .= "Data '@{[ ref $data || $data ]}' found where array reference expected for $showname at line $spec->{'ln'}\n";
			RayApp::removeChildNodeNicely($node->parentNode, $node);
			return 0;
		}
		my $parent = $node->parentNode;
		my $prev = $node->previousSibling;
		my $indent;
		if (defined $prev and $prev->nodeType == 3) {
			my $v = $prev->nodeValue;
			if (defined $v and $v =~ /(\n[ \t]+)/) {
				$indent = $1;
			}
		}
		for (my $i = 0; $i < @{$data}; $i++) {
			my $work = $node;
			if ($i < $#{$data}) {
				$work = $node->cloneNode(1);
				$parent->insertBefore($work, $node);
				if (defined $indent) {
					$parent->insertBefore(
						$dom->createTextNode($indent),
						$node);
				}
			}
			$self->bind_data($dom, $work, $pointer,
				$data->[$i], $showname . "[$i]", 1);
		}
	} elsif ($inmulti == 0 and $spec->{'multiple'} eq 'hash') {
		if (not ref $data or ref $data ne 'HASH') {
			$self->{errstr} .= "Data '@{[ ref $data || $data ]}' found where hash reference expected for $showname at line $spec->{'ln'}\n";
			RayApp::removeChildNodeNicely($node->parentNode, $node);
			return 0;
		}
		my $parent = $node->parentNode;
		my $prev = $node->previousSibling;
		my $indent;
		if (defined $prev and $prev->nodeType == 3) {
			my $v = $prev->nodeValue;
			if (defined $v and $v =~ /(\n[ \t]+)/) {
				$indent = $1;
			}
		}
		my $numkeys = keys %$data;
		my $i = 0;
		for my $key (sort {
			my $r = 0;
			if ($spec->{'hashorder'} eq 'num') {
				local $^W = 0;
				$r = $a <=> $b;
			}
			if ($r == 0 and $spec->{'hashorder'} eq 'string') {
				$r = $a cmp $b;
			}
			return $r;
			} keys %$data) {
			my $work = $node;
			if ($i < $numkeys - 1) {
				$work = $node->cloneNode(1);
				$parent->insertBefore($work, $node);
				if (defined $indent) {
					$parent->insertBefore(
						$dom->createTextNode($indent),
						$node);
				}
			}
			$i++;
			$work->setAttribute($spec->{'idattr'}, $key);
			$self->bind_data($dom, $work, $pointer,
				$data->{$key}, $showname . "{$key}", 1);
		}
	} elsif ($spec->{'type'} ne 'hash') {
		if (ref $data) {
			$self->{errstr} .= "Scalar expected for $showname defined at line $spec->{'ln'}, got @{[ ref $data ]}\n";
			RayApp::removeChildNodeNicely($node->parentNode, $node);
			return 0;
		} elsif ($spec->{'type'} eq 'int'
			and not $data =~ /^[+-]?\d+$/) {
			$self->{errstr} .= "Value '$data' of $showname is not integer for data element defined at line $spec->{'ln'}\n";
			RayApp::removeChildNodeNicely($node->parentNode, $node);
			return 0;
		} elsif ($spec->{'type'} eq 'num'
			and not $data =~ /^[+-]?\d*\.?\d+$/) {
			$self->{errstr} .= "Value '$data' of $showname is not numeric for data element defined at line $spec->{'ln'}\n";
			RayApp::removeChildNodeNicely($node->parentNode, $node);
			return 0;
		}
		if ($spec->{'cdata'} eq 'yes') {
			while ($data =~ s/^(.*\])(?=\]>)//sg) {
				$node->appendChild($dom->createCDATASection($1));
			}
			$node->appendChild($dom->createCDATASection($data));
		} else {
			$node->appendText($data);
		}
		return 1;
	} elsif ($spec->{'type'} eq 'hash') {
		if (not ref $data) {
			$self->{errstr} .= "Scalar data '$data' found where structure expected for $showname at line $spec->{'ln'}\n";
			RayApp::removeChildNodeNicely($node->parentNode, $node);
			return 0;
		}
		my %done = ();
		my $total = 0;
		my $i = 0;
		my $arrayi = 0;
		for my $child ($node->childNodes) {
			my $newpointer = "$pointer:$i";
			$i++;
			next if not defined $self->{'placeholders'}{$newpointer};
			if (ref $data eq 'ARRAY') {
				$total += $self->bind_data($dom, $child,
					$newpointer, $data->[ $arrayi ],
					$showname . "[$arrayi]", 0);
				$arrayi++;
			} else {
				my $newname = $self->{'placeholders'}{$newpointer}{'name'};
				$total += $self->bind_data($dom, $child,
					$newpointer, $data->{ $newname },
					$showname . "{$newname}", 0);
				$done{$newname} = 1;
			}
		}
		if (ref $data eq 'HASH') {
			for my $k (sort keys %$data) {
				if (not exists $done{$k}) {
					$self->{errstr} .= "Data $showname\{$k} does not match data structure description\n";
				}
			}
		} elsif (ref $data eq 'ARRAY') {
			if ($i <= $#$data) {
				my $view = $i;
				if ($i < $#$data) {
					$view .= "..$#$data";
				}
				$self->{errstr} .= "Data $showname\[$view] does not match data structure description\n";
			}
		} else {
			die "We shouldn't have got here";
		}
		if ($total or $inmulti) {
			return 1;
		} else {
			RayApp::removeChildNodeNicely($node->parentNode, $node);
			return 0;
		}
	} else {
		die "We shouldn't have got here, " . $node->toString;
	}
}

sub serialize_data_node {
	my ($self, $dom, $data, $opts, $node, $pointer) = @_;
	if (defined(my $spec = $self->{'placeholders'}{$pointer})) {
		$self->bind_data($dom, $node, $pointer,
			$data->{$spec->{'name'}}, "{$spec->{'name'}}", 0);
		return;
	} elsif (exists $self->{'ifs'}{$pointer}) {
		if ($self->{'ifs'}{$pointer}[0] eq 'if'
			and not $data->{$self->{'ifs'}{$pointer}[1]}) {
			RayApp::removeChildNodeNicely($node->parentNode, $node);
			return;
		} elsif ($self->{'ifs'}{$pointer}[0] eq 'ifdef'
			and not defined $data->{$self->{'ifs'}{$pointer}[1]}) {
			RayApp::removeChildNodeNicely($node->parentNode, $node);
			return;
		} elsif ($self->{'ifs'}{$pointer}[0] eq 'ifnot'
			and $data->{$self->{'ifs'}{$pointer}[1]}) {
			RayApp::removeChildNodeNicely($node->parentNode, $node);
			return;
		} elsif ($self->{'ifs'}{$pointer}[0] eq 'ifnotdef'
			and defined $data->{$self->{'ifs'}{$pointer}[1]}) {
			RayApp::removeChildNodeNicely($node->parentNode, $node);
			return;
		}
	}

	my $i = 0;
	for my $child ($node->childNodes) {
		$self->serialize_data_node($dom, $data,
			$opts, $child, "$pointer:$i");
		$i++;
	}
	return;
}

use XML::LibXSLT ();
sub serialize_style_dom {
	my ($self, $data, $opts) = ( shift, shift, shift );

	my $outdom = eval { $self->serialize_data_dom($data, $opts) };
	if ($@) {
		return;
	}

	my $rayapp = $self->{rayapp};

	for my $stylesheet (@_) {
		my $style = $rayapp->{stylesheets}{$stylesheet};
		if (not defined $style) {
			my $xslt = $rayapp->{xsltparser};
			if (not defined $xslt) {
				$xslt = $rayapp->{xsltparser} = new XML::LibXSLT;
			}
			$style = $rayapp->{stylesheets}{$stylesheet} = $xslt->parse_stylesheet_file($stylesheet);
		}
		$outdom = $style->transform($outdom);
	}
	return $outdom;
}

sub serialize_style {
	my $self = shift;
	my $outdom = $self->serialize_style_dom(@_);
	return $outdom->toString;
}

sub validate_parameters {
	my $self = shift;
	$self->{errstr} = '';
	my %params;
	if (defined $_[0] and ref $_[0]) {
		if (eval { $_[0]->isa("param") } and not $@) {
			for my $name ($_[0]->param) {
				$params{$name} = $_[0]->param($name);
			}
		} else {
			%params = %{ $_[0] };
		}
	} else {
		while (@_) {
			my ($k, $v) = (shift, shift);
			push @{ $params{$k} }, $v;
		}
	}

	for my $k (sort keys %params) {
		my $check = $self->{param}{$k};
		if (not defined $check) {
			my @prefixes;
			for my $i ( 1 .. length($k) ) {
				push @prefixes, substr $k, 0, $i;	
			}
			for my $pfx (reverse @prefixes) {
				if (defined $self->{paramprefix}{$pfx}) {
					$check = $self->{paramprefix}{$pfx};
					last if defined $check;
				}
			}
		}
		my $showname = 'undef';
		if (defined $params{$k}) {
			if (@{ $params{$k} } > 1) {
				$showname = '['
					. join(', ', map {
						defined $_
						? "'$_'"
						: 'undef' } @{ $params{$k} })
					. ']';
			} else {
				$showname = ( defined $params{$k}[0]
						? "'$params{$k}[0]'"
						: 'undef' );
			}
		}
		if (not defined $check) {
			$self->{errstr} .= "Unknown parameter '$k'=$showname\n";
		} elsif (@{ $params{$k} } > 1 and $check->{'multiple'} ne 'yes') {
			$self->{errstr} .= "Parameter '$k' has multiple values $showname\n";
		} elsif (defined $params{$k} and @{ $params{$k} }) {
			if ($check->{'type'} eq 'int') {
				my @bad = grep {
					defined $_ and not /^[+-]?\d+$/
					} @{ $params{$k} };
				if (@bad) {
					my $showname = '['
						. join(', ', map "'$_'", @bad)
						. ']';
					$self->{errstr} .= "Parameter '$k' has non-integer value $showname\n";
				}
			} elsif ($check->{'type'} eq 'num') {
				my @bad = grep {
					defined $_ and not /^[+-]?\d*\.\d+$/
					} @{ $params{$k} };
				if (@bad) {
					my $showname = '['
						. join(', ', map "'$_'", @bad)
						. ']';
					$self->{errstr} .= "Parameter '$k' has non-numeric value $showname\n";
				}
			}
		}
	}
	if ($self->{errstr} eq '') {
		$self->{errstr} = undef;
		return 1;
	}
	if (not $self->{errstr} =~ /\n./) {
		$self->{errstr} =~ s/\n$//;
	}
	return;
}

sub get_dtd {
	my $self = shift;
	return $self->{dtd} if defined $self->{dtd};
	my $data = { elements => {}, attributes => {} };
	$self->get_dtd_node($self->{'dom'}, 0, $data);

	my $txt = '';
	for my $element (keys %{ $data->{elements} }) {
		$txt .= "<!ELEMENT $element ("
			. join '|', @{ $data->{elements}{$element} };
		if (grep { $_ eq '#PCDATA' } @{ $data->{elements}{$element} }) {
			$txt .= ")*>\n";
		} else {
			$txt .= ")>\n";
		}
		if (defined $data->{attributes}{$element}) {
			$txt .= "<!ATTLIST $element ";
			my $i = 0;
			for my $v (keys %{ $data->{attributes}{$element} }) {
				if ($i++) {
					$txt .= "\n\t";
				}
				$txt .= "$v CDATA #REQUIRED";
			}
			$txt .= ">\n";
		}
	}
	return $self->{dtd} = $txt;
}

sub get_dtd_node {
	my ($self, $node, $pointer, $data) = @_;

	my $name;
	if ($node->nodeType == 1) {
		$name = $node->nodeName;
	}
	my $eltxt = '';
	my $more = 0;
	my $i = 0;
	for my $child ($node->childNodes) {
		my $newpointer = "$pointer:$i";
		$i++;
		$self->get_dtd_node($child, $newpointer, $data);
		next if $child->nodeType != 1;
		my $childname = $child->nodeName;
		if ($eltxt ne '') {
			$eltxt .= ', ';
			$more = 1;
		}
		$eltxt .= $childname;
		if (not defined $self->{placeholders}
			or not defined $self->{placeholders}{$newpointer}) {
			if (exists $self->{ifs}{$newpointer}) {
				$eltxt .= '?';
			}
			next;
		}
		if ($self->{placeholders}{$newpointer}{multiple} eq 'hash') {
			$data->{attributes}{$childname}{
				$self->{placeholders}{$newpointer}{idattr}
				} = 1;
		}

		if ($self->{placeholders}{$newpointer}{multiple} eq 'list'
			or $self->{placeholders}{$newpointer}{multiple} eq 'hash') {
			if (defined $self->{placeholders}{$newpointer}{mandatory}
				and $self->{placeholders}{$newpointer}{mandatory} eq 'yes') {
				$eltxt .= '+';
			} else {
				$eltxt .= '*';
			}
		} elsif ($self->{placeholders}{$newpointer}{mandatory} ne 'yes') {
			$eltxt .= '?';
		}
	}
	if (defined $name) {
		if ($eltxt eq '') {
			$eltxt = '#PCDATA';
		} elsif ($more) {
			$eltxt = "($eltxt)";
		}
		if ($eltxt ne ''
			and (not defined $data->{elements}{$name}
			or not grep { $eltxt eq $_ } @{$data->{elements}{$name}})) {
			push @{$data->{elements}{$name}}, $eltxt;
		}

		for my $attr ($node->attributes) {
			$data->{attributes}{$name}{ $attr->nodeName } = 1;
		}
	}
}

1;

=head1 NAME

RayApp - Framework for data-centric Web applications

=head1 SYNOPSIS

	use RayApp;
	my $rayapp = new RayApp;
	my $dsd = $rayapp->load_dsd('structure.xml');
	print $dsd->serialize_data( $data );

=head1 INTRODUCTION

The B<RayApp> provides a framework for data-centric Web applications.
Instead of writing Perl code that prints HTML, or embedding the code
inside of HTML markup, the applications only process and return Perl
data. No markup handling is done in the code of individual
application, inside of the business logic.

The data output is then serialized to XML, and postprocessed by XSLT
to desired output format, which may be HTML, XHTML, WML or anything
else. In order to provide all parties involved (application
programmers, Web designers, ...) with a common specification of the
data format, data structure description (DSD) file is a mandatory part
of the applications. The data returned by the Perl code is fitted into
the data structure, creating XML file with agreed-on elements.

This way, application programmer knows what data is expected from
their application, and Web designer knows what XMLs the
prostprocessing stage will be dealing with. In addition, application
code can be tested separately from the presentation part, and tests
for both application and presentation part can be written
independently, in parallel.

Of course, the data structure description can change if necessary, it
is not written in stone. Both application programmer and Web designer
can use the old DSD file and regression tests to easily migrate to the
new structure. This change in DSD leads to change in the DOCTYPE of
the resulting XML and is thus easily detected by the external parties.
The system will never produce unexpected data output, since the data
output is based on DSD which is known in advance.

=head1 DESCRIPTION

=head2 RayApp object

To work with B<RayApp> and have it process data structure description
files, application data and transformation, you need a B<RayApp> object
first. Use contructor B<new> to create one:

	use RayApp;
	my $rayapp = new RayApp;

The constructor takes a couple of parameters that affect its
behaviour:

=over 4

=item base

The base URI, used for all URI resolutions.

=item ua_options

Options that will be send to LWP::UserAgent constructor. See LWP
documentation for exact list.

=back

A constructor call might look like

	my $rayapp = new RayApp (
		base => 'file:///path/sub/',
		ua_options => {
			env_proxy => 1,
			timeout => 30,
			},
	);

Should the B<new> call fail, error message can be found in the
B<$RayApp::errstr> variable.

Once you have the B<RayApp> object, use B<load_dsd> or
B<load_dsd_string> methods to load a document structure description
(DSD). These methods give you a B<RayApp::DSD> object which accept
further method calls.

Parameters of these calls are as follows.

=over 4

=item load_dsd

The only parameter is URL of the DSD file. If you specify a relative
URL, it will be resolved relative to the base URI of the B<RayApp>
object.

	my $dsd = $rayapp->load_dsd('invoice.dsd');
	my $dsd = $rayapp->load_dsd('file:///path/to/invoice.dsd');

=item load_dsd_string

For B<load_dsd_string>, the DSD is specified as the sole parameter of
the method call:

	my $dsd = $rayapp->load_dsd_string('<?xml version="1.0"?>
		<invoice>
			<num type="int"/>
			<data typeref="invoice_data.dsd"/>
		</invoice>
	')

=back

If the B<load_dsd> or B<load_dsd_string> call fails for whatever
reason, it returns undef and the error message can be retrieved
using B<errstr> method of B<RayApp>:

	my $dsd = $ra->load_dsd('data.xml')
		or die $ra->errstr;

=head2 RayApp::DSD object

The incoming parameters of the CGI request can be checked
against the B<_param> specification included in the DSD, using the
B<validate_parameters>. It is designed to seamlessly accept hash
(array) of parameters or a CGI/Apache::Request-compatible object, and
fetch the parameters from it. The method returns true when all
parameters match the DSD, false otherwise. On error, B<errstr> method
of the B<RayApp::DSD> object gives the reason.

	my $q = new CGI;
	if (not $dsd->validate_parameters($q)) {
		# ... $dsd->errstr
	}
	
	$dsd->validate_parameters('id' => 1, 'id' => 2,
		'name' => 'PC', 'search' => 'Search')
		or # ...

From the DSD, the document type definition (DTD) can be derived,
providing DOCTYPE of the resulting data. Use method B<get_dtd> to
receive DTD as a string.

	my $dtdstring = $dsd->get_dtd;

The most important action that can be done with a B<RayApp::DSD>
object is serialization of data returned by the application,
according to the DSD. Method B<serialize_data> accepts hash with data
as its first argument, and optionally secont argument with options
driving the serialization. The method returns the output XML string.

	my $xml = $dsd->serialize_data({
		id => 14,
		name => 'Peter'
		});

Alternatively, a method B<serialize_data_dom> can be used which
behaves identically, only returning the DOM instead of the string.
That may be benefitial if the result is immediatelly postprocessed
using Perl tools, saving one parse call.

The supported serialization options are:

=over 4

=item RaiseError

By default it is true (1), resulting in an exception whenever
a serialization error occurs. This behavior may be switched off by
setting the parameter to zero. In that case the result is returned
even if the data did not match the DSD exactly (which may lead to the
output XML not matching its DOCTYPE). Use B<errstr> to verify that the
serialization was without errors.

	my $dom = $dsd->serialize_data_dom({
		people => [ { id => 2, name => 'Bob' },
			{ id => 31, name => 'Alice' } ]
		}, { RaiseError => 0 });

=item doctype

This value will be used as a SYSTEM identifier of the DOCTYPE.

=item doctype_ext

The SYSTEM identifier will be derived from the URI of the DSD bych
changing extension to this string.

	my $xml = $dsd->serialize_data({}, { doctype_ext => '.dtd' });

The DOCTYPE will be included in the resulting XML only if one of the
B<doctype> or B<doctype_ext> options are used.

=item validate

The resulting XML is serialized to XML and parsed back while being
validated against the DTD derived from the DSD. Set this option to
true to enable this extra safe bahaviour.

	my $dom = $dsd->serialize_data_dom({
		numbers => [ 13.4, 3, 45 ],
		rows => $dbh->selectall_arrayref($sth)
		}, { validate => 1 });

=back

Serialized data (the resulting XML) can be immediatelly postprocessed
with B<serialize_style> or B<serialize_style_dom> methods. They take
the same arguments as B<serialize_data>, but each additional argument
is considered to be a URI of a XSLT stylesheet. The stylesheets will
be applied to the output XML in the order in which they are specified.

	my $html = $dsd->serliaze_style({
		found => { 1 => 'x', 45 => 67 }
		}, { RaiseError => 0 },
		'generic.xslt',
		'finetune.xslt',
		);

=head2 Executing application handlers

The B<RayApp> object, besides access to the B<load_dsd*> methods,
provides methods of executing application handlers, either using the
B<Apache::Registry> style inside of the calling Perl/mod_perl
environment, or using external CGI scripts.

Method B<execute_application_handler> (and its reusing companion
B<execute_application_handler_reuse>) of B<RayApp> object take 
a single parameter with a file/URL of the Perl handler, or
a B<RayApp::DSD> object. The application code is loaded (or reused)
and a method B<handler> is invoked.
The data then can be passed directly to the B<serialize*> methods
of B<RayApp::DSD> object.

	$dsd = $rayapp->load_dsd($uri);
	my $data = $rayapp->execute_application_handler($dsd);
	# my $data = $rayapp->execute_application_handler('script.pm');
	$dsd->serialize_style($data, {}, 'stylesheet.xsl');

When the B<RayApp::DSD> is passed as an argument, the application name
is derived the standard way, from the B<application> attribute of the
root element of the DSD.

The application can also be invoked in a separate process, using
B<execute_application_process_storable> method. The data of the
application is then stored using B<RayApp::CGIStorable> module and
transferred back to B<RayApp> using application's standard output
handle.

=head1 The DSD

The data structure description file is a XML file. Its elements either
form the skeleton of the output XML and are copied to the output, or
specify placeholders for application data, or input parameters that
the application accepts.

=head2 Parameters

Parameters are denoted by the B<_param> elements. They take the
following attributes:

=over 4

=item name

Name of the parameter. For example,

	<_param name="id"/>

specifies parameter B<id>.

=item prefix

Prefix of the parameter. All parameters with this prefix will be
allowed. Element

	<_param prefix="search-"/>

allows both B<search-23> and B<search-xx> parameters.

=item multiple

By default, only one parameter of each name is allowed. However,
specifying B<multiple="yes"> makes it possible to call the application
with multiple parameters of the same name:

	<_param name="id" multiple="yes"/>
	application.cgi?id=34;id=45

=item type

A simple type checking is possible. Available types are B<int>,
B<integer> for integer values, B<num> and B<number> for numerical
values, and the default B<string> for generic string values.

Note that the type on parameters should only be used for input data
that will never be directly enterred by the application, either for
machine-to-machine communication, or for values in HTML forms that
come from menus or checkboxes.

=back

=head2 Typerefs

Any child element with an attribute B<typeref> is replaced by document
fragment specified by this attribute. Absolute or relative URL is
allowed, with possibly fragment information after a B<#> (hash)
character. For example:

	<root>
		<invoice typeref="invoice.dsd#inv"/>
		<adress typeref="address.xml"/>
	</root>

=head2 Data placeholders

Any child element, element with attributes B<type>, B<multiple> or with
name B<_data> are data placeholders that will have the application
data binded to them. The allowed attributes of placeholders are:

=over 4

=item type

Type of the placeholder. Except the scalar types which are the same as
for input parameters, B<hash> or B<struct> value can be used to denote
nested structure.

=item mandatory

By default, no data needs to be returned by the application for the
placeholder. When set to B<yes>, the value will be required.

=item id

An element can be assigned a unique identification which can be then
referenced by B<typeref> from other parts of the same DSD or from
remote DSD's.

=item multiple

When this attribute is specified, the value is expected to be an
aggregate and either the currect DSD element or its child is repeated
for each value.

=over 4

=item list

An array is expected as the value. The placeholder element
will be repeated.

=item listelement

An array is expected, the child of the placeholder will be repeated
for each of the array's element.

=item hash

An associative array is expected and placeholder element will
be repeated for all values of the array. The key of individual values
will be in an attribute B<id> or in an attribute named in DSD with
attribute B<idattr>.

=item hashelement

The same as B<hash>, except that the child of the placeholder will be
repeated.

=back

=item idattr

Specifies the name of attribute which will hold keys of
individual values for multiple values B<hash> and B<hashelement>,
the default is B<id>.

=item hashorder

Order of elements for values binded using multiple values B<hash> or
B<hashelement>. Possible values are B<num>, B<string>, and
(the default) B<natural>.

=item cdata

When set to yes, the scalar content of this element will be
output as a CDATA section.

=back

=head2 Conditions

The non-placeholder elements can have one of the B<if>, B<ifdef>,
B<ifnot> or B<ifnotdef> attributes that specify a top-level value
(from the data hash) that will be checked for presence or its value.
If the condition is not matched, this element with all its children
will be removed from the output stream.

=head2 Attributes

By default, only the special DSD attributes are allowed. However, with
an attribute B<attrs> a list of space separated attribute names can be
specified. These will be preserved on output.

With attribute B<xattrs>, a rename of attributes is possible. The
value is space separated list of space separated pairs of attribute
names.

=head2 Application name

The root element of the DSD can hold an B<application> attribute with
a URL (file name) of the application which should provide the data for
the DSD.

=head1 SEE ALSO

LWP::UserAgent(3), XML::LibXML(3)

=head1 AUTHOR

Copyright (c) Jan Pazdziora 2001--2003

=head1 VERSION

This documentation is believed to describe accurately B<RayApp>
version 1.110.


