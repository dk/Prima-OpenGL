#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <Widget.h>
#include "prima_gl.h"

PWidget_vmt CWidget;
#define var (( PWidget) widget)

static void
parse_tristate_char( int * target, SV * item, char * key, char * state_for_1, char * state_for_2)
{
	char * value = SvPV_nolen( item );
	if ( strcmp( value, state_for_1) == 0 )
		*target = 1;
	else
	if ( strcmp( value, state_for_2) == 0 )
		*target = 2;
	else
		croak("attribute '%s' must either be '%s' or '%s'", key, state_for_1, state_for_2);
}

static void
parse_bit_depth( int * target, SV * item, char * key)
{
	*target = SvIV( item );
	if ( *target < 1 || *target > 32)
		croak("attribute '%s' must be between 1 and 32", key);
}

#define PARSE_BOOL(s) \
	if ( strcmp( key, # s) == 0 ) \
		r-> s = SvIV(val) ? 1 : 0
#define PARSE_BITS(s) \
	if ( strcmp( key, # s) == 0 ) \
		parse_bit_depth( &r-> s, val, # s)
#define PARSE_STR(s,v1,v2) \
	if ( strcmp( key, # s) == 0 ) \
		parse_tristate_char( &r-> s, val, # s, v1, v2)
#define PARSE_INT(s) \
	if ( strcmp( key, # s) == 0 ) \
		r-> s = SvIV(val)

static void
parse( GLRequest * r, HV * attr)
{
	HE *he;

	memset( r, 0, sizeof(GLRequest));

	hv_iterinit( attr);
	while (( he = hv_iternext( attr)) != nil) {
		char * key = HeKEY( he);
		SV   * val = HeVAL( he);

		if ( !SvOK( val )) continue; /* undef is default */

		     PARSE_STR( target,  "window", "bitmap");
		else PARSE_STR( render,  "direct", "xserver");
		else PARSE_STR( pixels,  "rgba",   "palette");
		else PARSE_INT( layer);
		else PARSE_BOOL( double_buffer);
		else PARSE_BOOL( stereo);
		else PARSE_BITS( color_bits);
		else PARSE_BITS( aux_buffers);
		else PARSE_BITS( red_bits);
		else PARSE_BITS( green_bits);
		else PARSE_BITS( blue_bits);
		else PARSE_BITS( alpha_bits);
		else PARSE_BITS( depth_bits);
		else PARSE_BITS( stencil_bits);
		else PARSE_BITS( accum_red_bits);
		else PARSE_BITS( accum_green_bits);
		else PARSE_BITS( accum_blue_bits);
		else PARSE_BITS( accum_alpha_bits);
		else croak("unknown attribute: '%s'", key);
	}
}


MODULE = Prima::OpenGL      PACKAGE = Prima::OpenGL

BOOT:
{
	CWidget = (PWidget_vmt)gimme_the_vmt( "Prima::Widget");
}

PROTOTYPES: ENABLE

SV*
context_create(sv,attributes)
	SV *sv
	HV *attributes
PREINIT:
	Handle widget;
	Handle context;
	GLRequest request;
CODE:
	RETVAL = 0;
	widget = gimme_the_mate(sv);
	if ( !widget || !kind_of( widget, CWidget))
		croak("not a widget");

	parse( &request, attributes);
	context = gl_context_create(widget, &request);

	RETVAL = newSViv(context);
OUTPUT:
	RETVAL

void
context_destroy(context)
	void *context
CODE:
	if ( context) gl_context_destroy((Handle) context);


int
context_make_current(context)
	void *context
CODE:
	RETVAL = gl_context_make_current((Handle) context);

int
swap_buffers(context)
	void *context
CODE:
	RETVAL = context ? gl_swap_buffers((Handle) context) : 0;

SV *
last_error()
PREINIT:
	char buf[1024], *ret;
CODE:

	ret = gl_error_string(buf, 1024);
	RETVAL = ret ? newSVpv(ret, 0) : &PL_sv_undef;
OUTPUT:
	RETVAL

