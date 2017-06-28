package Prima::OpenGL::Modern;

use strict;
use warnings;
use Prima;
use Prima::OpenGL;
use OpenGL::Modern qw(glewInit glewGetErrorString GLEW_OK);

sub Prima::Application::glew_init
{
	my $self = shift;
	my $ret = undef;
	$self->begin_paint_info or return 0;
	unless ($self->gl_begin_paint) {
		$self->end_paint_info;
		return Prima::OpenGL::last_error();
	}
	my $err = glewInit;
	$ret = glewGetErrorString($err) unless $err == GLEW_OK;
	$self->gl_destroy;
	$self->end_paint_info;
	return $ret;
}

1;

=pod

=head1 NAME

Prima::OpenGL::Modern - Prima support for GLEW library

=head1 DESCRIPTION

Warning: OpenGL::Modern is highly experimental between versions, and might not work with this code.

It is therefore the module is not a prerequisite, so if you need it you need to install it yourself.
It exports a single function C<glew_init> into C<Prima::Application> space, because GLEW needs a
GL context to get initialized properly.

=head1 SYNOPSIS

   use Prima qw(Application OpenGL::Modern);
   my $err = $::application->glew_init;
   die $err if $err;

=head1 AUTHOR

Dmitry Karasik, E<lt>dmitry@karasik.eu.orgE<gt>.

=head1 SEE ALSO

L<OpenGL::Modern>

=head1 LICENSE

This software is distributed under the BSD License.

=cut
