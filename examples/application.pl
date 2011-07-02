use lib '../lib', '../blib/arch';
use lib 'lib', 'blib/arch';
use strict;
use warnings;
use OpenGL;
use Prima::OpenGL;
use Prima::Application;

$::application-> begin_paint;
my $ctx = Prima::OpenGL::context_create($::application, {});
die Prima::OpenGL::last_error unless $ctx;
Prima::OpenGL::context_make_current($ctx);

glViewport(100, 100, 200, 200);
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
Prima::OpenGL::flush($ctx);
$::application-> end_paint;
Prima::OpenGL::context_destroy($ctx);


