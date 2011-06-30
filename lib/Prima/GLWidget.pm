package Prima::GLWidget;

use strict;
use warnings;
use Prima;
use OpenGL;
use Prima::OpenGL;

use vars qw(@ISA);
@ISA = qw(Prima::Widget);

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		gl_config => {
			target => 'window',
		},
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub profile_check_in
{
	my ( $self, $p, $default) = @_;
	$self-> SUPER::profile_check_in( $p, $default);
	%{ $p-> {gl_config} } = (%{ $p-> {gl_config} } ,%{ $default-> {gl_config} } )
		if $p-> {gl_config};
}

sub init
{
	my ( $self, %profile) = @_;
	$self-> {gl_config} = {};
	%profile = $self-> SUPER::init( %profile);	
	$self-> gl_config($profile{gl_config});
}	

sub gl_config
{
	return $_[0]-> {gl_config} unless $#_;
	my ( $self, $config ) = @_;

	Prima::OpenGL::context_destroy($self-> {gl_context}) if $self-> {gl_context};
	$self-> {gl_config}  = $config;
	$self-> {gl_context} = Prima::OpenGL::context_create($self, $config);
	warn Prima::OpenGL::last_error unless $self-> {gl_context};
}

sub on_paint
{
	my ( $self, $canvas ) = @_;
	$self-> gl_select;
}

sub on_size
{
	my ( $self, $ox, $oy, $x, $y) = @_;
	$self-> gl_select;
	glViewport(0,0,$x,$y);	
}

sub on_destroy
{
	my $self = shift;
	Prima::OpenGL::context_destroy($self-> {gl_context});
	undef $self-> {gl_context};
}

sub gl_select
{
	my $ctx = shift-> {gl_context};
	Prima::OpenGL::context_make_current($ctx) if $ctx;
}

sub gl_unselect
{
	Prima::OpenGL::context_make_current(undef);
}

sub swap_buffers
{
	my $ctx = shift-> {gl_context};
	Prima::OpenGL::swap_buffers($ctx) if $ctx;
}

1;

__DATA__

=pod

=head1 NAME

Prima::GLWidget - general purpose GL drawing area / widget

=head1 SYNOPSIS

	use OpenGL;
	use Prima qw(Application GLWidget);

	my $window = Prima::MainWindow-> create;
	$window-> insert( GLWidget => 
		pack    => { expand => 1, fill => 'both'},
		onPaint => sub {
			my $self = shift;
			glClearColor(0,0,1,1);
			glClear(GL_COLOR_BUFFER_BIT);
			glOrtho(-1,1,-1,1,-1,1);
			
			glColor3f(1,0,0);
			glBegin(GL_POLYGON);
				glVertex2f(-0.5,-0.5);
				glVertex2f(-0.5, 0.5);
				glVertex2f( 0.5, 0.5);
				glVertex2f( 0.5,-0.5);
			glEnd();
			$self-> swap_buffers;
		}
	);

	run Prima;

=head1 DESCRIPTION

GLWidget class takes care of all internal mechanics needed for interactions between OpenGL and Prima.
The widget is operated as a normal C<Prima::Widget> class, except that all drawing can be done also
using C<gl> OpenGL functions.

=head1 API

=head2 Properties

=over

=item gl_config %HASHREF

C<gl_config> contains requests to GL visual selector. See description of keys
in L<Prima::OpenGL/Selection of a GL visual>.

=back

=head2 Methods

=over

=item gl_select

Associates the widget visual with current GL context, so GL functions can be used on the widget.

=item gl_unselect

Disassociates any GL context.

=item swap_buffers

Copies eventual off-screen GL buffer to the screen. Needs to be always called at the end of paint routine.

=back

=head1 AUTHOR

Dmitry Karasik, E<lt>dmitry@karasik.eu.orgE<gt>.

=head1 SEE ALSO

L<Prima>, L<OpenGL>

=cut
