#!perl -w
use strict;
use FindBin qw($Bin);
use Time::HiRes 'time';
use OpenGL::Modern ':all';
use OpenGL::Modern::Helpers qw(
	pack_GLint 
	pack_GLfloat 
	xs_buffer
	iv_ptr 
	glGetShaderInfoLog_p 
	glGetProgramInfoLog_p
	glGetShaderiv_p
	glGetProgramiv_p
	croak_on_gl_error
);
use Prima qw(Application GLWidget);

my (%uniforms, %shaders, $shader_text, $program, $vbo_quad);
my ($gl_initialized, $fullscreen, $xres, $yres, $time, $state, $frames);
my ( $window, $gl_widget);
my $started      = time;
my $frame_second = int time;

=head1 NAME

shadertoy - demonstration of an opengl shader

=head1 DESCRIPTION

This is a cut-down version of app/shadertoy by Corion, to focus on shader demo only.

=cut

my $fragment_header = <<HEADER;
#version 120
uniform vec4      iMouse;
uniform vec3      iResolution;
uniform float     iGlobalTime;
#line 1 // make the error numbers line up nicely
HEADER

my $fragment_footer = <<'FRAGMENT_FOOTER';
void main() {
	vec4 color = vec4(1.0,0.0,0.0,1.0);
	mainImage( color, gl_FragCoord.xy );
	gl_FragColor = color;
}
FRAGMENT_FOOTER

my $default_fragment_shader = <<'FRAGMENT';
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = fragCoord.xy / iResolution.xy;
	fragColor = vec4(uv,0.5+0.5*sin(iGlobalTime),cos(iGlobalTime));
}
FRAGMENT
	
my $default_vertex_shader = <<'VERTEX';
attribute vec2 pos;
void main() {
	gl_Position = vec4(pos,0.0,1.0);
}
VERTEX

sub create_shader
{
	my ( $type, $text ) = @_;
        
        my $id = glCreateShader( $type );
        die "Couldn't create shader" unless $id;
        croak_on_gl_error;
        glShaderSource_p( $id, $text );
        croak_on_gl_error;
        glCompileShader($id);
        croak_on_gl_error;

        if( glGetShaderiv_p( $id, GL_COMPILE_STATUS, 2 ) == GL_FALSE ) {
            my $log = glGetShaderInfoLog_p($id) // 'Compile error';
            die "Bad shader: $log\n";
        }

	return $shaders{$type} = $id;
}

sub init_shader
{
#	create_shader( GL_VERTEX_SHADER, $default_vertex_shader );
	create_shader( GL_FRAGMENT_SHADER, 
		$fragment_header . 
		($shader_text // $default_fragment_shader). 
		$fragment_footer );

	$program = glCreateProgram;
	die "Couldn't create shader program: " . glGetError . "\n" unless $program;
	my $log = glGetProgramInfoLog_p($program);
	die $log if $log;
	for my $shader ( sort keys %shaders ) {
		glAttachShader( $program, $shaders{$shader} );
		my $err = glGetError;
		warn glGetProgramInfoLog_p($program) if $err;
	}
	glLinkProgram($program);
	my $err = glGetError;
	if( glGetProgramiv_p( $program, GL_LINK_STATUS, 2) != GL_TRUE ) {
		my $log = glGetProgramInfoLog_p($program) // 'Link error';
		die "Link shader to program: $log\n";
	}

	my $count = glGetProgramiv_p( $program, GL_ACTIVE_UNIFORMS, 2);
	for my $index ( 0 .. $count-1 ) {
		xs_buffer( my $length, 8 );
		xs_buffer( my $size,   8 );
		xs_buffer( my $type,   8 );
	        # Names are maximum 16 chars:
		xs_buffer( my $name, 16);
	        glGetActiveUniform_c( $program, $index, 16, iv_ptr($length), iv_ptr($size), iv_ptr($type), $name);
		$length = unpack 'I', $length;
		$name = substr $name, 0, $length;
		$uniforms{ $name } = glGetUniformLocation_c( $program, $name);
	}
}

# We want static memory here
# A 2x2 flat-screen set of coordinates for the triangles
my @vertices = ( 
	-1.0, -1.0,   1.0, -1.0,    -1.0,  1.0,
	1.0, -1.0,   1.0,  1.0,    -1.0,  1.0
);
my $vertices = pack_GLfloat(@vertices);

# create a 2D quad Vertex Buffer
sub create_unit_quad
{
	glGenVertexArrays_c( 1, iv_ptr( my $buffer, 8 ));
	my $vao = (unpack 'I', $buffer)[0];
	glBindVertexArray($vao);
	glObjectLabel_c(GL_VERTEX_ARRAY, $vao, length("myVAO"), "myVAO");
	croak_on_gl_error;
	
	glGenBuffers_c( 1, iv_ptr($buffer, 8));
	croak_on_gl_error;
	$vbo_quad = (unpack 'I', $buffer)[0];
	
	glBindBuffer( GL_ARRAY_BUFFER, $vbo_quad );
	glBufferData_c(GL_ARRAY_BUFFER, length($vertices), iv_ptr($vertices), GL_DYNAMIC_DRAW);
	glObjectLabel_c(GL_BUFFER, $vbo_quad, length("my triangles"), "my triangles");
	croak_on_gl_error;
}

sub use_quad
{
	my $vpos = glGetAttribLocation_c($program, 'pos');
        die "Couldn't get shader attribute 'pos'\n" unless $vpos;
	glEnableVertexAttribArray( $vpos );
	glVertexAttribPointer_c( $vpos, 2, GL_FLOAT, GL_FALSE, 0, 0 );
	glBindBuffer(GL_ARRAY_BUFFER, $vbo_quad);
}

sub update_uniforms
{
	$time = time - $started;
	glProgramUniform1f( $program, $uniforms{iGlobalTime}, $time)             if $uniforms{iGlobalTime};
	glProgramUniform3f( $program, $uniforms{iResolution}, $xres, $yres, 1.0) if $uniforms{iResolution};
	if ( $state->{grab} && $uniforms{iMouse} ) {
		#my $iMouse = pack_GLfloat($gl_widget->pointerPos,0,0);
		my ($x, $y) = $gl_widget->pointerPos;
		#glProgramUniform4fv_c( $program, $uniforms{"iMouse"}, length($iMouse) / (4*4), iv_ptr($iMouse));
		glProgramUniform4f( $program, $uniforms{iMouse},$x,$y,0,0) if $uniforms{iMouse};
	}
}

$window = Prima::MainWindow->create(
	size => [ 640, 480 ],
	menuItems => [['~Options' => [
		[ ( $fullscreen ? '*' : '') . 'fullscreen', '~Fullscreen', 'Alt+Enter', km::Alt|kb::Enter, sub {
			my ( $window, $menu ) = @_;
			$fullscreen = $window->menu->toggle($menu);
			recreate_gl_widget();
		} ],
		[ 'pause' => '~Play/Pause' => 'Space' => kb::Space => sub {
			my ( $window, $menu ) = @_;
			if ( $window->menu->toggle($menu) ) {
				$window->Timer->stop;
			} else {
				$window->Timer->start;
			}
		} ],
		[],
		[ 'E~xit' => 'Alt+X' => '@X' => sub { shift-> close }],
	]]],
);

sub leave_fullscreen
{
    $fullscreen = 0;
    $window->menu->uncheck('fullscreen');
    recreate_gl_widget();
}

sub create_gl_widget
{
	my %param;
	if ( $fullscreen ) {
		my $primary = $::application->get_monitor_rects->[0];
		%param = (
			clipOwner  => 0,
			origin     => [@{$primary}[0,1]],
			size       => [@{$primary}[2,3]],
			onLeave    => \&leave_fullscreen,
		);
	} else {
		%param = (
			growMode   => gm::Client,
			rect       => [0, $window->font->height + 4, $window->width, $window->height],
		);
	}

	$gl_widget = $window->insert( GLWidget =>
		pack    => { expand => 1, fill => 'both'},
		onPaint => sub {
		my $self = shift;

		unless( $gl_initialized ) {
			my $err = OpenGL::Modern::glewInit;
			die "Couldn't initialize Glew: ".glewGetErrorString($err) unless $err == GLEW_OK;
			init_shader;
                	create_unit_quad;
			$gl_initialized = 1;
                }
			
		use_quad;

		glClearColor(0,0,0,1);
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
		
		glUseProgram( $program );
		update_uniforms;
		glBegin(GL_POLYGON);
			glVertex2f(-1,-1);
			glVertex2f(-1, 1);
			glVertex2f( 1, 1);
			glVertex2f( 1,-1);
		glEnd();
		glUseProgram( 0 );
		glFlush;
        },
        onMouseDown  => sub { $state->{grab} = 1 },
        onMouseUp    => sub { $state->{grab} = 0 },
        onSize       => sub { ( $xres,$yres ) = shift->size },
        onClose      => sub {
		glUseProgram(0);
		glDetachShader( $program, $_ ) for values %shaders;
		glDeleteProgram( $program );
		glDeleteShader( $_ ) for values %shaders;
        },
    );

    $gl_widget->focus if $fullscreen;
}

sub recreate_gl_widget
{
	$gl_widget->destroy;
	undef $vbo_quad;
	create_gl_widget();
}

create_gl_widget();

$window->insert( Timer =>
	timeout => 10,
	name    => 'Timer',
	onTick  => sub { $gl_widget->repaint }
)->start;

if ( $ARGV[0] ) {
	local $/;
	if ( open F, '<', $ARGV[0]) {
		$shader_text = <F>;
		close F;
	}
}

run Prima;
