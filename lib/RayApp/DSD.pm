
package RayApp::DSD;

use strict;
use warnings;

$RayApp::DSD::VERSION = '1.160';

use RayApp::XML;
use base 'RayApp::XML';
use Encode;

sub new {
	my ($class, $xml) = @_;
	my $ret = eval {
		parse_dsd($xml);
	};
	if ($@ or not $ret) {
		$xml->rayapp->errstr($@);
		return;
	}
	return bless $xml, $class;
}

# Parses the content and retrieves the DSD-content
sub parse_dsd {
	my $self = shift;
	my $rayapp = $self->rayapp;
	my $dom = $self->xmldom or return;

	my ($copy_attribs, $translate_attribs) = ( {}, {} );
	tidy_dsd_dom($self, $dom, 0, 0, $copy_attribs, $translate_attribs);
	while ( keys %{ $self->{typerefs} }) {
		my $refpointer = ( keys %{ $self->{typerefs} } )[0];
		my ($node, $id, $ln, $idpointer, $clone,
			$subdsd, $subpointer);
		my %visited;
		while (defined $refpointer) {
			($node, $id, $ln) = @{ $self->{typerefs}{$refpointer} };
			if ($id =~ /^([^#]+)#?(.*)$/s) {
				my ($uri, $remoteid) = ($1, $2);
				if ($self->uri =~ /^md5:/) {
					$uri = URI->new_abs($uri, $rayapp->base);
				} else {
					$uri = URI->new_abs($uri, $self->uri);
				}
				if (defined $rayapp->{parsing}{ $uri }) {
					die "Circular dependency detected at @{[ $self->uri ]}\n";
				}
				$rayapp->{parsing}{ $uri } = 1;
				$subdsd = $rayapp->load_dsd($uri);
				delete $rayapp->{parsing}{ $uri };
				if (not defined $subdsd) {
					die "Error loading DSD $uri referenced from line $ln: ", $rayapp->errstr, "\n";
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
			if (not defined $self->{id}{$id}) {
				die "No local id $id found for reference from line $ln\n";
			}

			my $idpointer = $self->{id}{$id}[1];
			my $newref = $self->{idpointer}{$idpointer}[1];
			if (defined $newref
				and not defined $self->{typerefs}{$newref}) {
				splice @{ $self->{idpointer}{$idpointer} }, 1, 1;
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
			$clone = $self->{id}{$id}[0]->cloneNode(1);
			$subdsd = $self;
			$subpointer = $self->{id}{$id}[1];
		}

		$clone->setNodeName($node->nodeName);
		$node->replaceNode($clone);
		delete $self->{typerefs}{$refpointer};

		for my $ph (keys %{ $subdsd->{placeholders} }) {
			if ($ph eq $subpointer) {
				$self->{placeholders}{$refpointer}{type}
					= $subdsd->{placeholders}{$ph}{type};
				# FIXME: and maybe others
			}
			if ($ph =~ /^$subpointer(:.+)/) {
				my $subid = $1;
				$self->{placeholders}{$refpointer . $subid}
					 = { %{ $subdsd->{placeholders}{$ph} } };
			}
		}
	}

	$self->{is_dsd} = 1;
	return $self;
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
			process_param_element($self, $node, $parent, $ln);
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
			next if $attr->nodeType != 2;
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
					if ($child->nodeType == 1
						and $child->nodeName ne '_param'
						and $child->nodeName ne '_data') {
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
			next if $k =~ /^xml/i;
			die "Unsupported attribute $k at line $ln\n";
		}
	}

	my $i = 0;
	for my $child ($node->childNodes) {
		my $ret = tidy_dsd_dom($self, $child, "$pointer:$i",
			$inside_placeholder,
			$copy_attribs, $translate_attribs);
		if ($ret) {
			$i++;
		} else {
			removeChildNodeNicely($node, $child);
		}
	}
	return 1;
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

sub params {
        return shift->{param};
}
sub param_prefixes {
        return shift->{paramprefix};
}

sub out_content {
	my $self = shift;
	$self->clear_errstr;
	return $self->{xmldom}->toString(1);

	if ($self->{xmldom}->encoding eq ''
		or lc $self->{xmldom}->encoding eq 'utf-8') {
		return Encode::decode('utf8', $self->{xmldom}->toString(1),
							Encode::FB_DEFAULT);
	} else {
		return $self->{xmldom}->toString(1);
	}
}

sub application_name {
	my $self = shift;
	if (not defined $self->{application}) {
		return;
	}
	my $uri = URI->new_abs($self->{application}, $self->uri);
	if (not $uri =~ s/^file://) {
		return;
	}
	return $uri;
}

sub serialize_data {
	my $self = shift;
	my $value = $self->serialize_data_dom(@_);
	if (not defined $value or not ref $value) {
		return;
	}
	return $value->toString(1);
}

sub serialize_data_dom {
	my ($self, $data, $opts) = @_;

	$opts = {} unless defined $opts;
	$opts->{RaiseError} = 1 unless defined $opts->{RaiseError};

	my $dom = $self->xmldom;
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

=comment

	if (defined $opts->{validate} and $opts->{validate}) {
		my $dtd = $self->get_dtd;
		my $ret;
		eval {
			my $parsed_dtd = XML::LibXML::Dtd->parse_string($dtd);
			### print STDERR $cloned->toString;
			my $parser = $self->rayapp->xml_parser;
			$parser->keep_blanks(0);
			my $parsed = $parser->parse_string($cloned->toString);
			$parser->keep_blanks(1);
			$ret = $parsed->validate($parsed_dtd);
		};
		if ($@) {
			$self->{errstr} = $@;
		} elsif (not $ret) {
			$self->{errstr} = "The result is not valid, but no reason given.\n";
		}

	}

=cut

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

sub serialize_data_node {
	my ($self, $dom, $data, $opts, $node, $pointer) = @_;
	if (defined(my $spec = $self->{'placeholders'}{$pointer})) {
		$self->bind_data($dom, $node, $pointer,
			$data->{$spec->{'name'}}, "{$spec->{'name'}}", 0);
		return;
	} elsif (exists $self->{'ifs'}{$pointer}) {
		if ($self->{'ifs'}{$pointer}[0] eq 'if') {
			if (not defined $data->{$self->{'ifs'}{$pointer}[1]}) {
				removeChildNodeNicely($node->parentNode, $node);
				return;
			}
			if (not ref $data->{$self->{'ifs'}{$pointer}[1]}
				and not $data->{$self->{'ifs'}{$pointer}[1]}) {
				removeChildNodeNicely($node->parentNode, $node);
				return;
			}
			if (ref $data->{$self->{'ifs'}{$pointer}[1]} eq 'ARRAY'
				and not @{ $data->{$self->{'ifs'}{$pointer}[1]} }) {
				removeChildNodeNicely($node->parentNode, $node);
				return;
			}
			if (ref $data->{$self->{'ifs'}{$pointer}[1]} eq 'HASH'
				and not keys %{ $data->{$self->{'ifs'}{$pointer}[1]} }) {
				removeChildNodeNicely($node->parentNode, $node);
				return;
			}
		} elsif ($self->{'ifs'}{$pointer}[0] eq 'ifdef'
			and not defined $data->{$self->{'ifs'}{$pointer}[1]}) {
			removeChildNodeNicely($node->parentNode, $node);
			return;
		} elsif ($self->{'ifs'}{$pointer}[0] eq 'ifnot'
			and $data->{$self->{'ifs'}{$pointer}[1]}) {
			removeChildNodeNicely($node->parentNode, $node);
			return;
		} elsif ($self->{'ifs'}{$pointer}[0] eq 'ifnotdef'
			and defined $data->{$self->{'ifs'}{$pointer}[1]}) {
			removeChildNodeNicely($node->parentNode, $node);
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

sub bind_data {
	my ($self, $dom, $node, $pointer, $data, $showname, $inmulti) = @_;
	my $spec = $self->{'placeholders'}{$pointer};
	if (not defined $data) {
		if ($spec->{'mandatory'} eq 'yes') {
			$self->{errstr} .= "No value of $showname for mandatory data element defined at line $spec->{'ln'}\n";
		}
		removeChildNodeNicely($node->parentNode, $node);
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
			removeChildNodeNicely($node->parentNode, $node);
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
		if (@{$data} == 0) {
			removeChildNodeNicely($parent, $node);
		}
		for (my $i = 0; $i < @{$data}; $i++) {
			my $work = $node;
			if ($i < $#{$data}) {
				# $work = $node->cloneNode(1);
				$work = clone_node($node);
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
			removeChildNodeNicely($node->parentNode, $node);
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
		if ($numkeys == 0) {
			removeChildNodeNicely($parent, $node);
		}
		my $i = 0;
		for my $key (sort {
			my $r = 0;
			if ($spec->{'hashorder'} eq 'num') {
				no warnings 'numeric';
				$r = $a <=> $b;
			}
			if ($r == 0 and $spec->{'hashorder'} eq 'string') {
				$r = $a cmp $b;
			}
			return $r;
			} keys %$data) {

			my $work = $node;
			if ($i < $numkeys - 1) {
				# $work = $node->cloneNode(1);
				$work = clone_node($node);
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
			removeChildNodeNicely($node->parentNode, $node);
			return 0;
		} elsif ($spec->{'type'} eq 'int'
			and not $data =~ /^[+-]?\d+$/) {
			$self->{errstr} .= "Value '$data' of $showname is not integer for data element defined at line $spec->{'ln'}\n";
			removeChildNodeNicely($node->parentNode, $node);
			return 0;
		} elsif ($spec->{'type'} eq 'num'
			and not $data =~ /^[+-]?\d*\.?\d+$/) {
			$self->{errstr} .= "Value '$data' of $showname is not numeric for data element defined at line $spec->{'ln'}\n";
			removeChildNodeNicely($node->parentNode, $node);
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
			removeChildNodeNicely($node->parentNode, $node);
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
			if ($arrayi <= $#$data) {
				my $view = $arrayi;
				if ($arrayi < $#$data) {
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
			removeChildNodeNicely($node->parentNode, $node);
			return 0;
		}
	} else {
		die "We shouldn't have got here, " . $node->toString;
	}
	return 1;
}

sub clone_node {
	my $node = shift;
	my $new = $node->cloneNode(0);
	$new->setNodeName($node->nodeName);
	my $child = $node->firstChild;
	while (defined $child) {
		my $new_child = clone_node($child);
		$new->addChild($new_child);
		$child = $child->nextSibling;
	}
	for my $a ($node->attributes) {
		next if not defined $a;
		$new->setAttribute($a->nodeName, $a->getValue);
	}
	return $new;
}

sub validate_parameters {
	my $self = shift;
	$self->{errstr} = '';
	my %params;

	if (defined $_[0] and ref $_[0]) {
		if (eval { $_[0]->can("param") } and not $@) {
			for my $name ($_[0]->param) {
				$params{$name} = [ $_[0]->param($name) ];
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

sub serialize_style {
	my ($self, $data, $opts, @stylesheets) = @_;
	my $dom = $self->serialize_data_dom($data, $opts);
	return $self->style_string($dom, $opts, @stylesheets);
}

1;

