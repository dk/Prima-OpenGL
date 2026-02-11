Prima extension for OpenGL
==========================

Works on win32, cygwin, and x11

Dependencies
------------

Ubuntu: apt-get install libgl-dev

Strawberry perl, if freeglut is not included (5.38): http://prima.eu.org/download/freeglut-win64.zip

Optional dependencies
---------------------

cpan OpenGL::Modern

Howto
-----

    perl Makefile.PL
    make
    make test
    make install
    perl examples/icosahedron.pl

Where
-----

http://github.com/dk/Prima-OpenGL

MacOSX
------

OpenGL on MacOS can be used in two unrelated configurations - either with
native OpenGL support, or via XQuartz/GLX.

Prima::OpenGL would only work with XQuartz/GLX, while by default OpenGL::Modern
uses native OpenGL.

There is currently no way to compile OpenGL::Modern with XQuartz/GLX, however
I've filed a PR that allows configuring it as `env WITH_XQUARTZ=1 perl Makefile.PL`.
For now, you would need to add the following lines to the OpenGL::Modern's Makefile.PL 
after line 17:

 $define .= " -DGLEW\_APPLE\_GLX -I/opt/X11/include";
 $libs = '-L/opt/X11/lib -lglut';

Author
------

Dmitry Karasik, 2026
