package MY;
use strict;
use ExtUtils::MakeMaker;
use Config;
use Prima::Config;

my @libs;
my @obj  = ('OpenGL.o');

if (
	$^O eq 'MSWin32' or
	( $^O eq 'cygwin' and $Prima::Config::Config{platform} eq 'win32')
) {
	push @libs, '-L/lib/w32api' if $^O eq 'cygwin';
	push @libs, '-lopengl32 -lmsimg32';
	push @libs, map { "-l$_" } @{$Prima::Config::Config{ldlibs} };
	push @obj,  'win32.o';
} elsif ( $^O eq 'darwin') {
	push @libs, map { "-L$_" } @{$Prima::Config::Config{ldpaths} };
	push @obj,  'x11.o';
	push @libs, '-lGL';
} else {
	push @obj,  'x11.o';
	push @libs, '-lGL';
}

push @libs, qq{"$Prima::Config::Config{libs}"} if $Prima::Config::Config{libs};

WriteMakefile(
	NAME               => 'Prima::OpenGL',
	VERSION_FROM       => 'lib/Prima/OpenGL.pm',
	MIN_PERL_VERSION   => '5.012',
	PREREQ_PM          => {
		'Prima'		=> 1.74,
	},
	CONFIGURE_REQUIRES => {
		'Prima'		=> 0,
	},
	ABSTRACT_FROM      => 'lib/Prima/OpenGL.pm',
	AUTHOR             => 'Dmitry Karasik <dmitry@karasik.eu.org>',
	LIBS               => [qq{:nosearch @libs}],
	DEFINE             => $Prima::Config::Config{define},
	INC                => "$Prima::Config::Config{inc} -Iinclude",
	OBJECT             => "@obj",
	META_MERGE        => {
		resources => {
			repository => 'http://github.com/dk/Prima-OpenGL',
		},
	},
);
