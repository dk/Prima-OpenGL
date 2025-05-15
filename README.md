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

Compile Prima as `perl Makefile.PL WITH_HOMEBREW=0`. This is a horrible hack.

OpenGL on MacOS can be used in two unrelated configurations - either native or
Mesa/homebrew. The native supports Metal fine, but it requires compilation with
X11 libs found in /opt/X11 . If compiling with homebrew X11 libs, then the
native layer cannot be used, only Mesa software emulation can.

Prima::OpenGL would only work if both Prima and OpenGL::Modern are compiled
with either native or Mesa. By default though, OpenGL::Modern uses native
OpenGL, while Prima uses Mesa (if found), because native X11 libs come without
support of modern libraries like harfbuzz and gtk. This module's Makefile.PL
tries to detect if these two are compiled in different modes, and warn about
it.

To compile Prima with the native X11 libs, configure it as `perl Makefile.PL
WITH_HOMEBREW=0`.  This will though disable some libraries and will degrade the
toolkit.

There is currently no way to compile OpenGL::Modern with Mesa, however I've
filed a PR that allows configuring it as `env WITH_HOMEBREW=1 perl
Makefile.PL`.

There is neither a way to configure OpenGL (pogl) perl module with Mesa.

Author
------

Dmitry Karasik, 2024
