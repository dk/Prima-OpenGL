#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <GL/gl.h>
#include <win32/win32guts.h>
#include "prima_gl.h"
#include <Component.h>
#include <Drawable.h>

#ifdef __cplusplus
extern "C" {
#endif

#define var (( PComponent) object)
#define img (( PDrawable) object)
#define sys (( PDrawableData) var-> sysData)
#define ctx (( Context*) context)

typedef struct {
	HDC dc;
	HGLRC gl;
} ContextStackEntry;

ContextStackEntry stack[CONTEXT_STACK_SIZE];
int               stack_ptr = 0;


typedef struct {
	HDC   dc;
	HGLRC gl;
	HWND  wnd;
	HBITMAP bm;
	Handle object;
	Bool layered;
} Context;

static char * last_failed_func = 0;
static DWORD  last_error_code  = 0;

#define CLEAR_ERROR  last_failed_func = 0
#define SET_ERROR(s) { last_error_code = GetLastError(); last_failed_func = s; }

static GLRequest ** xx;

HBITMAP
setupDIB(HDC hDC, int w, int h)
{
	BITMAPINFO *bmInfo;
	BITMAPINFOHEADER *bmHeader;
	UINT usage;
	VOID *base;
	int bmiSize;
	int bitsPerPixel;
	HBITMAP bm;

	bmiSize = sizeof(BITMAPINFO);
	bitsPerPixel = GetDeviceCaps(hDC, BITSPIXEL);

	switch (bitsPerPixel) {
	case 8:
		/* bmiColors is 256 WORD palette indices */
		bmiSize += (256 * sizeof(WORD)) - sizeof(RGBQUAD);
		break;
	case 16:
		/* bmiColors is 3 WORD component masks */
		bmiSize += (3 * sizeof(DWORD)) - sizeof(RGBQUAD);
		break;
	case 24:
	case 32:
	default:
		/* bmiColors not used */
		break;
	}
	if ( !( bmInfo = malloc(bmiSize)))
		return NULL;

	bmHeader = &bmInfo->bmiHeader;

	bmHeader->biSize          = sizeof(*bmHeader);
	bmHeader->biWidth         = w;
	bmHeader->biHeight        = h;
	bmHeader->biPlanes        = 1;                  /* must be 1 */
	bmHeader->biBitCount      = bitsPerPixel;
	bmHeader->biXPelsPerMeter = 0;
	bmHeader->biYPelsPerMeter = 0;
	bmHeader->biClrUsed       = 0;                  /* all are used */
	bmHeader->biClrImportant  = 0;                  /* all are important */

	switch (bitsPerPixel) {
	case 8:
		bmHeader->biCompression = BI_RGB;
		bmHeader->biSizeImage = 0;
		usage = DIB_PAL_COLORS;
		/* bmiColors is 256 WORD palette indices */
		{
			WORD i, *palIndex = (WORD *) &bmInfo->bmiColors[0];
			for (i=0; i<256; i++) palIndex[i] = i;
		}
		break;
	case 16:
		bmHeader->biCompression = BI_RGB;
		bmHeader->biSizeImage = 0;
		usage = DIB_RGB_COLORS;
		/* bmiColors is 3 WORD component masks */
		{
			DWORD *compMask = (DWORD *) &bmInfo->bmiColors[0];

			compMask[0] = 0xF800;
			compMask[1] = 0x07E0;
			compMask[2] = 0x001F;
		}
		break;
	case 24:
	case 32:
	default:
		bmHeader->biCompression = BI_RGB;
		bmHeader->biSizeImage = 0;
		usage = DIB_RGB_COLORS;
		/* bmiColors not used */
		break;
	}

	bm = CreateDIBSection(hDC, bmInfo, usage, NULL, NULL, 0);
	SelectObject( hDC, bm);
	free(bmInfo);
	return bm;
}

Handle
gl_context_create( Handle object, GLRequest * request)
{
	int n, pf;
	PIXELFORMATDESCRIPTOR pfd;
	HWND wnd;
	HDC dc;
	HBITMAP glbm;
	HGLRC gl;
	Bool layered;
	Context * ret;

	CLEAR_ERROR;

	ret = NULL;
	
	memset(&pfd, 0, sizeof(pfd));
	pfd.nSize        = sizeof(pfd);
	pfd.nVersion     = 1;
	pfd.dwFlags      = PFD_SUPPORT_OPENGL;

	switch ( request-> target ) {
	case GLREQ_TARGET_BITMAP:
	case GLREQ_TARGET_IMAGE:
	case GLREQ_TARGET_PRINTER:
		pfd.dwFlags |= PFD_DRAW_TO_BITMAP;
		wnd = 0;
		dc   = CreateCompatibleDC(sys-> ps);
		glbm = setupDIB(dc, img-> w, img-> h);
		SelectObject( dc, glbm);
		request-> double_buffer = GLREQ_FALSE;
		layered = false;
		break;
	case GLREQ_TARGET_WINDOW:
		glbm = 0;
		if ( apc_widget_get_layered_request( object )) {
        		const WCHAR wnull = 0;
			wnd = CreateWindowExW(
				WS_EX_TOOLWINDOW, L"Generic", &wnull,
        			WS_VISIBLE | WS_POPUP | WS_CLIPCHILDREN | WS_CLIPSIBLINGS,
        			0,0,1,1,NULL,NULL,NULL, NULL
			);
			ShowWindow(wnd,SW_HIDE);
			if (!wnd) {
				SET_ERROR("CreateWindowExW");
				return (Handle)0;
			}
			layered = true;
		} else {
			wnd = (HWND) var-> handle;
			layered = false;
		}
		dc  = GetDC( wnd );
		pfd.dwFlags |= PFD_DRAW_TO_WINDOW;
		break;
	case GLREQ_TARGET_APPLICATION:
		glbm = 0;
		wnd  = 0;
		dc   = GetDC( 0 );
		pfd.dwFlags |= PFD_DRAW_TO_WINDOW | PFD_SUPPORT_GDI;
		layered = false;
		break;
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
		
	pfd.cColorBits = GetDeviceCaps(dc, BITSPIXEL);
   
	if ( !( pf = ChoosePixelFormat(dc, &pfd))) {
		SET_ERROR("ChoosePixelFormat");
		return (Handle)0;
	}
	if ( !SetPixelFormat(dc, pf, &pfd)) {
		SET_ERROR("SetPixelFormat");
		/* 
		Did you try to recreate a GL context on the same window? 
		Windows doesn't allow that. Source:
                https://www.opengl.org/wiki/Platform_specifics:_Windows#How_many_times_can_I_call_SetPixelFormat.3F
		*/
		return (Handle)0;
	}
	if ( !( gl = wglCreateContext(dc))) {
		SET_ERROR("wglCreateContext");
		return (Handle)0;
	}

	ret = malloc( sizeof( Context ));
	ret-> dc      = dc;
	ret-> gl      = gl;
	ret-> wnd     = wnd;
	ret-> object  = object;
	ret-> bm      = glbm;
	ret-> layered = layered;
	protect_object( object );

	return (Handle) ret;
}

void
gl_context_destroy( Handle context)
{
	CLEAR_ERROR;
	if ( wglGetCurrentContext() == ctx-> gl) 
		wglMakeCurrent( NULL, NULL);
	wglDeleteContext( ctx-> gl );
	if ( ctx-> bm) {
		SelectObject( ctx-> dc, NULL);
		DeleteObject( ctx-> bm);
		DeleteDC( ctx-> dc);
	}
	if ( ctx-> wnd) ReleaseDC( ctx-> wnd, ctx-> dc );
	if ( ctx-> layered) DestroyWindow( ctx-> wnd );
	unprotect_object( ctx-> object );
	free(( void*)  ctx );
}

Bool
gl_context_make_current( Handle context)
{
	Bool ret;
	CLEAR_ERROR;
	if ( context ) {
		if ( ctx-> layered ) {
			RECT r;
			Handle object = ctx-> object;
			GetWindowRect(( HWND ) var-> handle, &r);
			SetWindowPos( ctx-> wnd, 
				NULL, 0, 0, r.right-r.left, r.bottom-r.top, 
				SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);
		}
		ret = wglMakeCurrent( ctx-> dc, ctx-> gl);
	} else {
		ret = wglMakeCurrent( NULL, NULL );
	}
	if ( !ret ) SET_ERROR( "wglMakeCurrent");
	return ret;
}

Bool
gl_flush( Handle context)
{
	Bool ret;
	CLEAR_ERROR;
	if ( ctx-> bm ) {
		Handle object = ctx-> object;
		ret = BitBlt(sys-> ps, 0, 0, img-> w, img-> h, ctx-> dc, 0, 0, SRCCOPY);
		if ( !ret ) SET_ERROR( "BitBlt");
		GdiFlush();
	} else if ( ctx-> layered ) {
		Byte * pixels;
		Point size;
		BITMAPINFO bmi;
		HDC dc, argb_dc;
		HBITMAP bm, bmOld;
		BLENDFUNCTION bf;

		size = apc_widget_get_size( ctx-> object );
		argb_dc = (( PDrawableData)(( PComponent) ctx-> object )-> sysData)->ps;

		/* prepare bitmap storage */
		bmi.bmiHeader.biSize        = sizeof(BITMAPINFOHEADER);
		bmi.bmiHeader.biWidth       = size. x;
		bmi.bmiHeader.biHeight      = size. y;
		bmi.bmiHeader.biPlanes      = 1;
		bmi.bmiHeader.biBitCount    = 32;
		bmi.bmiHeader.biCompression = BI_RGB;
		bmi.bmiHeader.biSizeImage   = size.x * size.y * 4;
		dc = CreateCompatibleDC(argb_dc);
		if ( !( bm = CreateDIBSection(dc, &bmi, DIB_RGB_COLORS, (LPVOID)&pixels, NULL, 0x0))) {
			SET_ERROR("CreateDIBSection");
			return false;
		}
		bmOld = SelectObject(dc, bm);

		/* read pixels from GL */
		glPixelStorei(GL_PACK_ALIGNMENT, 1);
		glReadPixels(0, 0, size.x, size.y, GL_BGRA_EXT, GL_UNSIGNED_BYTE, pixels);

		/* write them to GDI */
		ret = BitBlt(argb_dc, 0, 0, size.x, size.y, dc, 0, 0, SRCCOPY);
		if ( !ret ) SET_ERROR("BitBlt");

		/* cleanup */
		SelectObject(dc, bmOld);
		DeleteObject(bm);
		DeleteDC(dc);
	} else {
		ret = SwapBuffers( ctx->dc );
		if ( !ret ) SET_ERROR( "SwapBuffers");
	}
	
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
	LocalFree( lpMsgBuf);

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

int 
gl_context_push(void)
{
	CLEAR_ERROR;
	if ( stack_ptr >= CONTEXT_STACK_SIZE ) {
		last_error_code  = 1001; /* win32 native error ERROR_STACK_OVERFLOW */
		last_failed_func = "gl_context_push";
		return 0;
	}

	stack[stack_ptr].gl = wglGetCurrentContext();
	stack[stack_ptr].dc = wglGetCurrentDC();
	stack_ptr++;
	return 1;
}

int 
gl_context_pop(void)
{
	CLEAR_ERROR;
	if ( stack_ptr <= 0) {
		last_error_code  = 1001; /* win32 native error ERROR_STACK_OVERFLOW */
		last_failed_func = "gl_context_pop";
		return 0;
	}
	stack_ptr--;
	return wglMakeCurrent( stack[stack_ptr].dc, stack[stack_ptr].gl);
}

Bool
gl_is_direct(Handle context)
{
	CLEAR_ERROR;
	return true;
}

#ifdef __cplusplus
}
#endif

