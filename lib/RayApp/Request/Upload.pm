
package RayApp::Request::Upload;

sub new {
	my $class = shift;
	return bless { @_ }, $class;
}
sub filename {
	shift->{filename};
}
# sub filehandle {
#	shift->{filehandle};
# }
sub size {
	my $self = shift;
	length($self->{content});
}
sub content_type {
	shift->{content_type};
}
sub content {
	shift->{content};
}

1;

