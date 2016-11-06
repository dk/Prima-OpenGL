#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Prima::Test;
use OpenGL;
use Prima::OpenGL;
use Prima::Application;

plan tests => 30;

my $x = Prima::DeviceBitmap-> new(
	width  => 2,
	height => 2,
);
$x-> gl_begin_paint;

glClearColor(0,0,1,1);
glClear(GL_COLOR_BUFFER_BIT);
glOrtho(-1,1,-1,1,-1,1);

glColor3f(1,0,0);
glBegin(GL_POLYGON);
	glVertex2f( 0,0);
	glVertex2f( 1, 0);
	glVertex2f( 1, -1);
	glVertex2f( 0, -1);
glEnd();
glFinish();

$x-> gl_flush;

# RGB
my $i = $x->gl_read_pixels( format => GL_RGB );
is( $i->pixel(0,0), 0x000000FF, "rgb(0,0)=B");
is( $i->pixel(0,1), 0x000000FF, "rgb(0,1)=B");
is( $i->pixel(1,0), 0x00FF0000, "rgb(1,0)=R");
is( $i->pixel(1,1), 0x000000FF, "rgb(1,1)=B");

# R/G/B
$i = $x->gl_read_pixels( format => GL_BLUE );
is( $i->pixel(0,0), 0xFF, "blue(0,0)=B");
is( $i->pixel(0,1), 0xFF, "blue(0,0)=B");
is( $i->pixel(1,0), 0x00, "blue(0,0)=0");
is( $i->pixel(1,1), 0xFF, "blue(0,0)=B");

$i = $x->gl_read_pixels( format => GL_GREEN );
is( $i->pixel(0,0), 0x00, "green(0,0)=0");
is( $i->pixel(0,1), 0x00, "green(0,0)=0");
is( $i->pixel(1,0), 0x00, "green(0,0)=0");
is( $i->pixel(1,1), 0x00, "green(0,0)=0");

$i = $x->gl_read_pixels( format => GL_RED );
is( $i->pixel(0,0), 0x00, "red(0,0)=0");
is( $i->pixel(0,1), 0x00, "red(0,0)=0");
is( $i->pixel(1,0), 0xFF, "red(0,0)=R");
is( $i->pixel(1,1), 0x00, "red(0,0)=0");

$i = $x->gl_read_pixels( format => GL_RED, type => GL_SHORT );
is( $i->pixel(0,0), 0x00,   "red16(0,0)=0");
ok( $i->pixel(1,0) > 0x7FF0, "red16(0,0)=R16");

$i = $x->gl_read_pixels( format => GL_RED, type => GL_INT );
is( $i->pixel(0,0), 0x00,       "red32(0,0)=0");
ok( $i->pixel(1,0) > 0x7FFF0000, "red32(0,0)=R32");

$i = $x->gl_read_pixels( format => GL_RED, type => GL_FLOAT );
ok( $i->pixel(0,0) < 0.01,       "redf(0,0)=0");
ok( $i->pixel(1,0) > 0.99,       "redf(0,0)=1.0f");

my ( $d, $m ) = $x->gl_read_pixels( format => GL_RGBA )-> split;
is( $d->pixel(0,0), 0x000000FF, "RGBa(0,0)=B");
is( $d->pixel(0,1), 0x000000FF, "RGBa(0,1)=B");
is( $d->pixel(1,0), 0x00FF0000, "RGBa(1,0)=R");
is( $d->pixel(1,1), 0x000000FF, "RGBa(1,1)=B");
is( $m->pixel(0,0), 0x000000FF, "rgbA(0,0)=1");
is( $m->pixel(0,1), 0x000000FF, "rgbA(0,1)=1");
is( $m->pixel(1,0), 0x000000FF, "rgbA(1,0)=1");
is( $m->pixel(1,1), 0x000000FF, "rgbA(1,1)=1");

$x-> gl_end_paint;

