# $Id$
package Prima::OpenGL;
use strict;
use Prima;
require Exporter;
require DynaLoader;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
@ISA = qw(Exporter DynaLoader);

sub dl_load_flags { 0x01 };

$VERSION = '0.01';
@EXPORT = qw();
@EXPORT_OK = qw();
%EXPORT_TAGS = ();

bootstrap Prima::OpenGL $VERSION;

__END__

=pod

=head1 NAME

Prima::OpenGL - Prima extension for OpenGL drawing

=head1 DESCRIPTION

The module allows for programming GL library together with Prima widgets.
L<OpenGL> module does a similar jobs using freeglut GUI library.

=head1 API

=head2 Selection of a GL visual

Before a GL area is used, a GL visual need to be selected first. Currently this
process is done by system-specific search function, so results differ between
win32 and x11.  Namely, x11 is less forgiving, and may fail with error. Also,
win32 and x11 GL defaults are different.

All attributes are passed to function C<context_create> as a hashref (see
description below).  If an option is not set, or set to undef, system default
is used.

=over

=item target ( "window" or "bitmap" )

Prepares GL area for either on- or off-screen drawing. Might be extended later.

=item render ( "direct" or "xserver" )

Excerpt from C<glXCreateContext>:

Specifies whether rendering is to be done with a direct connection to the
graphics system if possible ("direct") or through the X server ("xserver").  If
direct is True, then a direct rendering context is created if the
implementation supports direct rendering, if the connection is to an X server
that is local, and if a direct rendering context is available. (An
implementation may return an indirect context when direct is True.) If direct
is False, then a rendering context that renders through the X server is always
created.  Direct rendering provides a performance advantage in some
implementations.  However, direct rendering contexts cannot be shared outside a
single process, and they may be unable to render to GLX

Actual for x11 only.

=item pixels ( "rgba" or "paletted" )

Selects either paletted or true-color visual representation.

=item layer INTEGER

x11: Layer zero corresponds to the main frame buffer of the display.  Layer
one is the first overlay frame buffer, level two the second overlay frame
buffer, and so on. Negative buffer levels correspond to underlay frame
buffers.

win32: Provides only three layers, -1, 0, and 1 .

=item double_buffer BOOLEAN

If set, select double buffering.

=item stereo BOOLEAN

If set, select a stereo visual.

=item color_bits INTEGER

Indicates the desired color index buffer size. Usual values are 8, 15, 16, 24, or 32.

=item aux_buffers INTEGER

Indicated the desired number of auxilliary buffers.

=item depth_bits INTEGER 

If this value is zero, visuals with no depth buffer are preferred.  Otherwise,
the largest available depth buffer of at least the minimum size is preferred.

=item stencil_bits INTEGER

Indicates the desired number of stencil bitplanes.  The smallest stencil buffer
of at least the specified size is preferred.  If the desired value is zero,
visuals with no stencil buffer are preferred.

=item red_bits green_bits blue_bits alpha_bits INTEGER

If this value is zero, the smallest available red/green/blue/alpha buffer is
preferred.  Otherwise, the largest available buffer of at least the minimum
size is preferred.
                    
=item accum_red_bits accum_green_bits accum_blue_bits accum_alpha_bits INTEGER

If this value is zero, visuals with no red/green/blue/alpha accumulation buffer
are preferred.  Otherwise, the largest possible accumulation buffer of at least
the minimum size is preferred.

=back

=head2 Methods

=over

=item last_error

Call C<last_error> that returns string representation of the last error, or undef if there was none.
Note that X11 errors are really unspecific due to asynchronous mode X server and clients operate; expect
some generic error strings there.

=back

=head1 AUTHOR

Dmitry Karasik, E<lt>dmitry@karasik.eu.orgE<gt>.

=head1 SEE ALSO

L<Prima>, L<OpenGL>

   git clone git@github.com:dk/Prima-OpenGL.git

=head1 COPYRIGHT

This software is distributed under the BSD License.

=head1 NOTES

Thanks to Chris Marshall for the motivating me writing this module!

=cut
