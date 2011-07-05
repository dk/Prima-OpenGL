# $Id$
package MY;
use ExtUtils::MakeMaker;
use Config;

my ( $i, $d, $l) = ('','','');
my $severe = grep { $_ eq '--severe' } @ARGV;
@ARGV      = grep { $_ ne '--severe' } @ARGV;
eval { 
	require Prima::Config;
	$d  = $Prima::Config::Config{define};
	$i  = "$Prima::Config::Config{inc} -Iinclude -Iinclude/generic";
	$l  = $Prima::Config::Config{libs};
};
if ( $@) {
	warn "** Prima is required for build\n";
	if ( $severe) {
		unlink 'Makefile';
		exit 1;
	}
	$prima_failed = 1;
}

$prima_failed = 1 if @ARGV;

sub post_initialize
{
	my $self = shift;
	my $t = $self->SUPER::post_initialize(@_);
	$t = <<PRE if $prima_failed;

init_state:
	$^X Makefile.PL --severe
	$Config{make}

PRE
	return $t;
}

my @libs;
my @obj  = ('OpenGL.o');


if ( 
	$^O eq 'MSWin32' or 
	( $^O eq 'cygwin' and $Prima::Config::Config{platform} eq 'win32')
) {
	push @libs, '-L/lib/w32api' if $^O eq 'cygwin';
	push @libs, '-lopengl32 -lgdi32';
	push @obj,  'win32.o';
} else {
	push @libs, '-lGL';
	push @obj,  'x11.o';
}

push @libs, $l;

WriteMakefile(
	NAME              => 'Prima::OpenGL',
	VERSION_FROM      => 'lib/Prima/OpenGL.pm',
	MIN_PERL_VERSION  => '5.008',
	PREREQ_PM         => {
		'Prima'		=> '1.30',
		'OpenGL'	=> 0.64,
	},
	ABSTRACT_FROM     => 'lib/Prima/OpenGL.pm',
	AUTHOR            => 'Dmitry Karasik <dmitry@karasik.eu.org>',
	LIBS              => join(' ', @libs),
	DEFINE            => $d,
	INC               => $i,
	OBJECT            => join(' ', @obj),
);

