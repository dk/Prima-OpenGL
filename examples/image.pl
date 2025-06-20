use strict;
use warnings;
use OpenGL::Modern qw(:all);
use Prima::OpenGL;
use Prima::Application;

my $x = Prima::Image-> new(
	width => 100,
	height => 100,
	type => im::RGB,
);
$x-> begin_paint;
exit unless $x-> gl_begin_paint;

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
glFinish();
$x-> gl_end_paint;
$x-> end_paint;
$x-> save( 'a.png') or die "Cannot save image:$@";
print "a.png saved ok\n";


