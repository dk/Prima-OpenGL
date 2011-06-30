#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <GL/gl.h>
#include <win32/win32guts.h>
#include "prima_gl.h"
#include <Component.h>

#ifdef __cplusplus
extern "C" {
#endif

#define var (( PComponent) widget)
#define ctx (( Context*) context)

typedef struct {
	HDC   dc;
	HGLRC gl;
	HWND  wnd;
} Context;

static char * last_failed_func = 0;
static DWORD  last_error_code  = 0;

#define CLEAR_ERROR  last_failed_func = 0
#define SET_ERROR(s) { last_error_code = GetLastError(); last_failed_func = s; }

Handle
gl_context_create( Handle widget, GLRequest * request)
{
	int n, pf;
	PIXELFORMATDESCRIPTOR pfd;
	HWND wnd;
	HDC dc;
	HGLRC gl;
	Context * ret;

	CLEAR_ERROR;

	ret = nilHandle;
	wnd = (HWND) var-> handle;
	dc  = GetDC( wnd );
	
	memset(&pfd, 0, sizeof(pfd));
	pfd.nSize        = sizeof(pfd);
	pfd.nVersion     = 1;
	pfd.dwFlags      = PFD_SUPPORT_OPENGL | PFD_SUPPORT_GDI;

	switch ( request-> target ) {
	case GLREQ_TARGET_BITMAP:
		pfd.dwFlags |= PFD_DRAW_TO_BITMAP;
		break;
	case GLREQ_TARGET_WINDOW:
	default:
		pfd.dwFlags |= PFD_DRAW_TO_WINDOW;
	}
	
	if ( request-> layer > 0)
		pfd.iLayerType = PFD_OVERLAY_PLANE;
	else if ( request-> layer < 0)
		pfd.iLayerType = PFD_UNDERLAY_PLANE;
	
	switch ( request-> pixels ) {
	case GLREQ_PIXEL_RGBA:
		pfd.iPixelType = PFD_TYPE_RGBA;
		break;
	case GLREQ_PIXEL_PALETTE:
		pfd.iLayerType = PFD_TYPE_COLORINDEX;
		break;
	}
	
	if ( request-> double_buffer == GLREQ_TRUE) {
          	pfd.dwFlags |= PFD_DOUBLEBUFFER;
	  	pfd.dwFlags &= ~PFD_SUPPORT_GDI;
	}
	if ( request-> stereo == GLREQ_TRUE)
          	pfd.dwFlags |= PFD_STEREO;

	pfd.cColorBits      = request-> color_bits;
	pfd.cAuxBuffers     = request-> aux_buffers;
	pfd.cRedBits        = request-> red_bits;
	pfd.cGreenBits      = request-> green_bits;
	pfd.cBlueBits       = request-> blue_bits;
	pfd.cAlphaBits      = request-> alpha_bits;
	pfd.cDepthBits      = request-> depth_bits;
	pfd.cStencilBits    = request-> stencil_bits;
	pfd.cAccumRedBits   = request-> accum_red_bits;
	pfd.cAccumGreenBits = request-> accum_green_bits;
	pfd.cAccumBlueBits  = request-> accum_blue_bits;
	pfd.cAccumAlphaBits = request-> accum_alpha_bits;

	if ( pfd.cColorBits == 0) 
		pfd.cColorBits = pfd.cRedBits + pfd.cGreenBits + pfd.cBlueBits;
	pfd.cAccumBits = pfd.cAccumRedBits + pfd.cAccumGreenBits + pfd.cAccumBlueBits + pfd.cAccumAlphaBits;
   
	if ( !( pf = ChoosePixelFormat(dc, &pfd))) {
		SET_ERROR("ChoosePixelFormat");
		goto RET;
	}
	if ( !SetPixelFormat(dc, pf, &pfd)) {
		SET_ERROR("SetPixelFormat");
		goto RET;
	}		
	if ( !( gl = wglCreateContext(dc))) {
		SET_ERROR("wglCreateContext");
		goto RET;
	}

	ret = malloc( sizeof( Context ));
	ret-> dc  = dc;
	ret-> gl  = gl;
	ret-> wnd = wnd;
RET:

	return (Handle) ret;
}

void
gl_context_destroy( Handle context)
{
	CLEAR_ERROR;
	if ( wglGetCurrentContext() == ctx-> gl) 
		wglMakeCurrent( NULL, NULL);
	wglDeleteContext( ctx-> gl );
	ReleaseDC( ctx-> wnd, ctx-> dc );
	free(( void*)  ctx );
}

Bool
gl_context_make_current( Handle context)
{
	Bool ret;
	CLEAR_ERROR;
	if ( context ) {
		ret = wglMakeCurrent( ctx-> dc, ctx-> gl);
	} else {
		ret = wglMakeCurrent( NULL, NULL );
	}
	if ( !ret ) SET_ERROR( "wglMakeCurrent");
	return ret;
}

Bool
gl_swap_buffers( Handle context)
{
	Bool ret;
	CLEAR_ERROR;
	ret = SwapBuffers( ctx-> dc );
	if ( !ret ) SET_ERROR( "SwapBuffers");
	return ret;
}

char *
gl_error_string(char * buf, int len)
{
   	LPVOID lpMsgBuf;
	char localbuf[1024];
	int i;
	if ( !last_failed_func ) return NULL;

	FormatMessage(
		FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM, 
		NULL, last_error_code,
      		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
      		( LPTSTR) &lpMsgBuf, 0, NULL
	);
      	strncpy( localbuf, lpMsgBuf ? ( const char *) lpMsgBuf : "unknown", 1024);

	/* chomp! */
	i = strlen(localbuf);
	while ( i > 0) {
		i--;
		if ( localbuf[i] != '\xD' && localbuf[i] != '\xA' && localbuf[i] != '.')
			break;
		localbuf[i] = 0;
	}		
	
	snprintf( buf, len, "%s error: %s", last_failed_func, localbuf);
	return buf;
}

#ifdef __cplusplus
}
#endif

