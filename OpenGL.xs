#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <DeviceBitmap.h>
#include <Widget.h>
#include <Image.h>
#include <Icon.h>
#include <Application.h>
#include <Printer.h>
#include <GL/gl.h>
#include "prima_gl.h"

PWidget_vmt CWidget;
PDeviceBitmap_vmt CDeviceBitmap;
PImage_vmt CImage;
PIcon_vmt CIcon;
PApplication_vmt CApplication;
PPrinter_vmt CPrinter;
#define var (( PWidget) widget)

#ifndef GL_BGR
#define GL_BGR 0x80e0
#endif
#ifndef GL_BGRA
#define GL_BGRA 0x80e1
#endif

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

		     PARSE_STR( render,  "direct", "xserver");
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
	PRIMA_VERSION_BOOTCHECK;
	CWidget = (PWidget_vmt)gimme_the_vmt( "Prima::Widget");
	CDeviceBitmap = (PDeviceBitmap_vmt)gimme_the_vmt( "Prima::DeviceBitmap");
	CImage = (PImage_vmt)gimme_the_vmt( "Prima::Image");
	CIcon = (PIcon_vmt)gimme_the_vmt( "Prima::Icon");
	CApplication = (PApplication_vmt)gimme_the_vmt( "Prima::Application");
	CPrinter = (PPrinter_vmt)gimme_the_vmt( "Prima::Printer");
}

PROTOTYPES: ENABLE

SV*
context_create(sv,attributes)
	SV *sv
	HV *attributes
PREINIT:
	Handle object;
	Handle context;
	GLRequest request;
	Bool need_paint_state = 0;
CODE:
	RETVAL = 0;
	
	if ( !(object = gimme_the_mate(sv)))
		croak("not a object");

	parse( &request, attributes);
	if ( kind_of( object, CApplication)) {
		request. target = GLREQ_TARGET_APPLICATION;
		need_paint_state = 1;
	}
	else if ( kind_of( object, CWidget))
		request. target = GLREQ_TARGET_WINDOW;
	else if ( kind_of( object, CDeviceBitmap)) 
		request. target = GLREQ_TARGET_BITMAP;
	else if ( kind_of( object, CImage)) {
		request. target = GLREQ_TARGET_IMAGE;
		need_paint_state = 1;
	}
	else if ( kind_of( object, CPrinter)) {
		request. target = GLREQ_TARGET_PRINTER;
		need_paint_state = 1;
	}
	else
		croak("bad object");

	if ( need_paint_state && !PObject(object)-> options. optInDraw )
		croak("object not in paint state");
	context = gl_context_create(object, &request);

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
OUTPUT:
	RETVAL

int
context_push()
CODE:
	RETVAL = gl_context_push();
OUTPUT:
	RETVAL

int
context_pop()
CODE:
	RETVAL = gl_context_pop();
OUTPUT:
	RETVAL

int
flush(context)
	void *context
CODE:
	RETVAL = context ? gl_flush((Handle) context) : 0;
OUTPUT:
	RETVAL

SV *
last_error()
PREINIT:
	char buf[1024], *ret;
CODE:

	ret = gl_error_string(buf, 1024);
	RETVAL = ret ? newSVpv(ret, 0) : &PL_sv_undef;
OUTPUT:
	RETVAL

void
gl_read_image(x,y,format,type,sv_obj)
	int x
	int y
	int format
	int type
	SV * sv_obj
PREINIT:
	Handle object;
	PImage i;
CODE:
	if ( !(object = gimme_the_mate(sv_obj)) || !kind_of(object, CImage))
		croak("not an image");
	i = PImage(object);

	if ( i-> type == imRGB) {
		if ( format != GL_BGR ) croak("bad format");
	} else {
		if ( format == GL_BGR || format == GL_RGB || format == GL_BGRA || format == GL_RGBA) croak("bad format");

		switch (type) {
		case GL_UNSIGNED_BYTE:
		case GL_BYTE:
			if ( i-> type != imByte ) croak("image is not imByte");
			break;
		case GL_UNSIGNED_SHORT:
		case GL_SHORT:
			if ( i-> type != imShort ) croak("image is not imShort");
			break;
		case GL_UNSIGNED_INT:
		case GL_INT:
			if ( i-> type != imLong ) croak("image is not imLong");
			break;
		case GL_FLOAT:
			if ( i-> type != imFloat ) croak("image is not imFloat");
			break;
		default:
			croak("bad type");
		}
	}
	glPixelStorei(GL_PACK_ROW_LENGTH, 0);
	glPixelStorei(GL_PACK_ALIGNMENT, 4);
	glReadPixels(x,y,i->w,i->h,format,type,i->data);

void
gl_read_icon_mask(x,y,sv_obj)
	int x
	int y
	SV * sv_obj
PREINIT:
	Handle object;
	PIcon i;
CODE:
	if ( !(object = gimme_the_mate(sv_obj)) || !kind_of(object, CIcon) || PIcon(object)->maskType != imbpp8)
		croak("not an 8-bit mask icon");
	i = PIcon(object);
	glPixelStorei(GL_PACK_ROW_LENGTH, 0);
	glPixelStorei(GL_PACK_ALIGNMENT, 4);
	glReadPixels(x,y,i->w,i->h,GL_ALPHA,GL_UNSIGNED_BYTE,i->mask);
