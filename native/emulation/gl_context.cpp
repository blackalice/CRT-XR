#include "gl_context.h"
#include <cstring>
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#define GL_CALL __stdcall
#else
#include <dlfcn.h>
#define GL_CALL
#endif

namespace crt_xr {
namespace {
// OpenGL enums and entry points used here; values from Khronos glcorearb.h.
using GLenum = unsigned; using GLuint = unsigned; using GLint = int; using GLsizei = int;
constexpr GLenum FRAMEBUFFER = 0x8D40, READ_FRAMEBUFFER = 0x8CA8, RENDERBUFFER = 0x8D41, RGBA8 = 0x8058,
    DEPTH24_STENCIL8 = 0x88F0, DEPTH_COMPONENT24 = 0x81A6, COLOR_ATTACHMENT0 = 0x8CE0, DEPTH_ATTACHMENT = 0x8D00,
    DEPTH_STENCIL_ATTACHMENT = 0x821A, FRAMEBUFFER_COMPLETE = 0x8CD5, RGBA = 0x1908, UNSIGNED_BYTE = 0x1401,
    READ_FRAMEBUFFER_BINDING = 0x8CAA, PIXEL_PACK_BUFFER = 0x88EB, PIXEL_PACK_BUFFER_BINDING = 0x88ED,
    PACK_ALIGNMENT = 0x0D05, PACK_ROW_LENGTH = 0x0D02;
struct Gl {
    void (GL_CALL* GenFramebuffers)(GLsizei, GLuint*);
    void (GL_CALL* DeleteFramebuffers)(GLsizei, const GLuint*);
    void (GL_CALL* BindFramebuffer)(GLenum, GLuint);
    void (GL_CALL* GenRenderbuffers)(GLsizei, GLuint*);
    void (GL_CALL* DeleteRenderbuffers)(GLsizei, const GLuint*);
    void (GL_CALL* BindRenderbuffer)(GLenum, GLuint);
    void (GL_CALL* RenderbufferStorage)(GLenum, GLenum, GLsizei, GLsizei);
    void (GL_CALL* FramebufferRenderbuffer)(GLenum, GLenum, GLenum, GLuint);
    GLenum (GL_CALL* CheckFramebufferStatus)(GLenum);
    void (GL_CALL* ReadPixels)(GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void*);
    void (GL_CALL* GetIntegerv)(GLenum, GLint*);
    void (GL_CALL* PixelStorei)(GLenum, GLint);
    void (GL_CALL* BindBuffer)(GLenum, GLuint);
} gl{};
template <class T> bool bind(T& slot, const char* name) {
    slot = reinterpret_cast<T>(GlContext::proc(name));
    return slot != nullptr;
}
bool load_gl() {
    return bind(gl.GenFramebuffers, "glGenFramebuffers") && bind(gl.DeleteFramebuffers, "glDeleteFramebuffers") &&
        bind(gl.BindFramebuffer, "glBindFramebuffer") && bind(gl.GenRenderbuffers, "glGenRenderbuffers") &&
        bind(gl.DeleteRenderbuffers, "glDeleteRenderbuffers") && bind(gl.BindRenderbuffer, "glBindRenderbuffer") &&
        bind(gl.RenderbufferStorage, "glRenderbufferStorage") && bind(gl.FramebufferRenderbuffer, "glFramebufferRenderbuffer") &&
        bind(gl.CheckFramebufferStatus, "glCheckFramebufferStatus") && bind(gl.ReadPixels, "glReadPixels") &&
        bind(gl.GetIntegerv, "glGetIntegerv") && bind(gl.PixelStorei, "glPixelStorei") && bind(gl.BindBuffer, "glBindBuffer");
}

#ifdef _WIN32
HMODULE opengl32() { static HMODULE library = LoadLibraryW(L"opengl32.dll"); return library; }
template <class T> T wgl(const char* name) { return reinterpret_cast<T>(reinterpret_cast<void*>(GetProcAddress(opengl32(), name))); }
using CreateContext = HGLRC (WINAPI*)(HDC);
using MakeCurrent = BOOL (WINAPI*)(HDC, HGLRC);
using DeleteContext = BOOL (WINAPI*)(HGLRC);
using GetProc = PROC (WINAPI*)(LPCSTR);
using CreateContextAttribs = HGLRC (WINAPI*)(HDC, HGLRC, const int*);
constexpr int CONTEXT_MAJOR = 0x2091, CONTEXT_MINOR = 0x2092, CONTEXT_PROFILE = 0x9126, PROFILE_CORE = 1, PROFILE_COMPATIBILITY = 2;
const wchar_t* window_class() {
    static const wchar_t* name = [] {
        WNDCLASSW type{};
        type.style = CS_OWNDC;
        type.lpfnWndProc = DefWindowProcW;
        type.hInstance = GetModuleHandleW(nullptr);
        type.lpszClassName = L"CrtXrHiddenGl";
        RegisterClassW(&type);
        return type.lpszClassName;
    }();
    return name;
}
#else
// EGL types and enums; values from Khronos egl.h and EGL_MESA_platform_surfaceless.
using EGLDisplay = void*; using EGLConfig = void*; using EGLContext = void*; using EGLSurface = void*;
using EGLint = std::int32_t; using EGLBoolean = unsigned; using EGLenum = unsigned;
constexpr EGLint NONE = 0x3038, SURFACE_TYPE = 0x3033, PBUFFER_BIT = 0x0001, RENDERABLE_TYPE = 0x3040, OPENGL_BIT = 0x0008,
    RED_SIZE = 0x3024, GREEN_SIZE = 0x3023, BLUE_SIZE = 0x3022, WIDTH = 0x3057, HEIGHT = 0x3056,
    CONTEXT_MAJOR = 0x3098, CONTEXT_MINOR = 0x30FB, CONTEXT_PROFILE = 0x30FD, PROFILE_CORE = 1, PROFILE_COMPATIBILITY = 2,
    EXTENSIONS = 0x3055;
constexpr EGLenum OPENGL_API = 0x30A2, PLATFORM_SURFACELESS = 0x31DD;
void* egl_library() { static void* library = dlopen("libEGL.so.1", RTLD_NOW | RTLD_LOCAL); return library; }
template <class T> T egl(const char* name) { return egl_library() ? reinterpret_cast<T>(dlsym(egl_library(), name)) : nullptr; }
#endif
}

GlContext::~GlContext() { destroy(); }

void* GlContext::proc(const char* name) {
#ifdef _WIN32
    // wglGetProcAddress knows only extension and post-1.1 functions; OpenGL 1.1
    // ones (glReadPixels, glClear...) come straight from opengl32.dll.
    static const auto get = wgl<GetProc>("wglGetProcAddress");
    const auto found = get ? reinterpret_cast<std::intptr_t>(get(name)) : 0;
    if (found == 0 || found == 1 || found == 2 || found == 3 || found == -1)
        return reinterpret_cast<void*>(GetProcAddress(opengl32(), name));
    return reinterpret_cast<void*>(found);
#else
    static const auto get = egl<void* (*)(const char*)>("eglGetProcAddress");
    if (void* found = get ? get(name) : nullptr) return found;
    static void* library = [] {
        void* opened = dlopen("libOpenGL.so.0", RTLD_NOW | RTLD_LOCAL);
        return opened ? opened : dlopen("libGL.so.1", RTLD_NOW | RTLD_LOCAL);
    }();
    return library ? dlsym(library, name) : nullptr;
#endif
}

bool GlContext::create(unsigned major, unsigned minor, bool core_profile, std::string& error) {
    if (context) return true;
#ifdef _WIN32
    if (!opengl32()) { error = "OpenGL is not available (opengl32.dll)"; return false; }
    const auto make_current = wgl<MakeCurrent>("wglMakeCurrent");
    const auto delete_context = wgl<DeleteContext>("wglDeleteContext");
    const auto create_context = wgl<CreateContext>("wglCreateContext");
    const auto get_proc = wgl<GetProc>("wglGetProcAddress");
    auto* hwnd = CreateWindowExW(0, window_class(), L"", WS_OVERLAPPEDWINDOW, 0, 0, 16, 16, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
    if (!hwnd) { error = "Could not create the hidden OpenGL window"; return false; }
    window = hwnd;
    HDC dc = GetDC(hwnd);
    device = dc;
    PIXELFORMATDESCRIPTOR format{};
    format.nSize = sizeof(format); format.nVersion = 1;
    format.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    format.iPixelType = PFD_TYPE_RGBA; format.cColorBits = 32; format.cDepthBits = 24; format.cStencilBits = 8;
    const int chosen = ChoosePixelFormat(dc, &format);
    if (!chosen || !SetPixelFormat(dc, chosen, &format)) { error = "No OpenGL pixel format"; destroy(); return false; }
    // A legacy context first, to reach wglCreateContextAttribsARB.
    HGLRC legacy = create_context(dc);
    if (!legacy || !make_current(dc, legacy)) { error = "Could not create an OpenGL context"; if (legacy) delete_context(legacy); destroy(); return false; }
    const auto create_attribs = reinterpret_cast<CreateContextAttribs>(reinterpret_cast<void*>(get_proc("wglCreateContextAttribsARB")));
    const int attributes[] = {CONTEXT_MAJOR, static_cast<int>(major), CONTEXT_MINOR, static_cast<int>(minor),
        CONTEXT_PROFILE, core_profile ? PROFILE_CORE : PROFILE_COMPATIBILITY, 0};
    HGLRC modern = create_attribs ? create_attribs(dc, nullptr, attributes) : nullptr;
    if (modern && make_current(dc, modern)) { delete_context(legacy); context = modern; }
    else if (!core_profile) context = legacy;
    else {
        if (modern) delete_context(modern);
        make_current(nullptr, nullptr); delete_context(legacy);
        error = "The graphics driver has no OpenGL " + std::to_string(major) + "." + std::to_string(minor) + " core context";
        destroy(); return false;
    }
#else
    if (!egl_library()) { error = "OpenGL is not available (libEGL.so.1)"; return false; }
    const auto query = egl<const char* (*)(EGLDisplay, EGLint)>("eglQueryString");
    const auto get_display = egl<EGLDisplay (*)(void*)>("eglGetDisplay");
    const auto initialize = egl<EGLBoolean (*)(EGLDisplay, EGLint*, EGLint*)>("eglInitialize");
    const auto bind_api = egl<EGLBoolean (*)(EGLenum)>("eglBindAPI");
    const auto choose = egl<EGLBoolean (*)(EGLDisplay, const EGLint*, EGLConfig*, EGLint, EGLint*)>("eglChooseConfig");
    const auto create_context = egl<EGLContext (*)(EGLDisplay, EGLConfig, EGLContext, const EGLint*)>("eglCreateContext");
    const auto create_pbuffer = egl<EGLSurface (*)(EGLDisplay, EGLConfig, const EGLint*)>("eglCreatePbufferSurface");
    const auto make_current = egl<EGLBoolean (*)(EGLDisplay, EGLSurface, EGLSurface, EGLContext)>("eglMakeCurrent");
    const auto platform_display = reinterpret_cast<EGLDisplay (*)(EGLenum, void*, const EGLint*)>(proc("eglGetPlatformDisplayEXT"));
    if (!query || !get_display || !initialize || !bind_api || !choose || !create_context || !make_current) { error = "Incomplete EGL library"; return false; }
    // Surfaceless rendering needs no window system: the context works the same
    // in Gaming Mode, on a desktop or without any display.
    const char* client = query(nullptr, EXTENSIONS);
    EGLint version_major = 0, version_minor = 0;
    if (platform_display && client && std::strstr(client, "EGL_MESA_platform_surfaceless")) {
        display = platform_display(PLATFORM_SURFACELESS, nullptr, nullptr);
        if (display && !initialize(display, &version_major, &version_minor)) display = nullptr;
    }
    if (!display) {
        display = get_display(nullptr);
        if (!display || !initialize(display, &version_major, &version_minor)) { display = nullptr; error = "No EGL display for OpenGL"; return false; }
    }
    if (!bind_api(OPENGL_API)) { error = "EGL has no desktop OpenGL"; destroy(); return false; }
    EGLConfig config = nullptr;
    EGLint count = 0;
    const EGLint pbuffer[] = {SURFACE_TYPE, PBUFFER_BIT, RENDERABLE_TYPE, OPENGL_BIT, RED_SIZE, 8, GREEN_SIZE, 8, BLUE_SIZE, 8, NONE};
    const EGLint any[] = {SURFACE_TYPE, 0, RENDERABLE_TYPE, OPENGL_BIT, NONE};
    if (!choose(display, pbuffer, &config, 1, &count) || count == 0) {
        if (!choose(display, any, &config, 1, &count) || count == 0) { error = "No EGL configuration for OpenGL"; destroy(); return false; }
    }
    const EGLint attributes[] = {CONTEXT_MAJOR, static_cast<EGLint>(major), CONTEXT_MINOR, static_cast<EGLint>(minor),
        CONTEXT_PROFILE, core_profile ? PROFILE_CORE : PROFILE_COMPATIBILITY, NONE};
    context = create_context(display, config, nullptr, attributes);
    if (!context) { error = "The graphics driver has no OpenGL " + std::to_string(major) + "." + std::to_string(minor) + " context"; destroy(); return false; }
    // Without EGL_KHR_surfaceless_context a tiny pbuffer stands in for a window.
    if (!make_current(display, nullptr, nullptr, context)) {
        const EGLint size[] = {WIDTH, 16, HEIGHT, 16, NONE};
        surface = create_pbuffer ? create_pbuffer(display, config, size) : nullptr;
        if (!surface || !make_current(display, surface, surface, context)) { error = "Could not make the OpenGL context current"; destroy(); return false; }
    }
#endif
    if (!load_gl()) { error = "The OpenGL driver lacks framebuffer objects"; destroy(); return false; }
    return true;
}

bool GlContext::resize(unsigned width, unsigned height, bool depth, bool stencil, std::string& error) {
    if (!context) { error = "No OpenGL context"; return false; }
    if (fbo && width <= fbo_width && height <= fbo_height) return true;
    destroy_framebuffer();
    gl.GenFramebuffers(1, &fbo);
    gl.BindFramebuffer(FRAMEBUFFER, fbo);
    gl.GenRenderbuffers(1, &color);
    gl.BindRenderbuffer(RENDERBUFFER, color);
    gl.RenderbufferStorage(RENDERBUFFER, RGBA8, static_cast<GLsizei>(width), static_cast<GLsizei>(height));
    gl.FramebufferRenderbuffer(FRAMEBUFFER, COLOR_ATTACHMENT0, RENDERBUFFER, color);
    if (depth || stencil) {
        gl.GenRenderbuffers(1, &depth_stencil);
        gl.BindRenderbuffer(RENDERBUFFER, depth_stencil);
        gl.RenderbufferStorage(RENDERBUFFER, stencil ? DEPTH24_STENCIL8 : DEPTH_COMPONENT24, static_cast<GLsizei>(width), static_cast<GLsizei>(height));
        gl.FramebufferRenderbuffer(FRAMEBUFFER, stencil ? DEPTH_STENCIL_ATTACHMENT : DEPTH_ATTACHMENT, RENDERBUFFER, depth_stencil);
    }
    const bool complete = gl.CheckFramebufferStatus(FRAMEBUFFER) == FRAMEBUFFER_COMPLETE;
    gl.BindRenderbuffer(RENDERBUFFER, 0);
    gl.BindFramebuffer(FRAMEBUFFER, 0);
    if (!complete) { destroy_framebuffer(); error = "The OpenGL framebuffer is incomplete"; return false; }
    fbo_width = width; fbo_height = height;
    return true;
}

bool GlContext::read(unsigned width, unsigned height, bool flip, std::vector<std::uint8_t>& rgba) {
    if (!fbo || width == 0 || height == 0 || width > fbo_width || height > fbo_height) return false;
    // The core's state cache expects its bindings untouched: put them back.
    GLint read_binding = 0, pack_buffer = 0, alignment = 4, row_length = 0;
    gl.GetIntegerv(READ_FRAMEBUFFER_BINDING, &read_binding);
    gl.GetIntegerv(PIXEL_PACK_BUFFER_BINDING, &pack_buffer);
    gl.GetIntegerv(PACK_ALIGNMENT, &alignment);
    gl.GetIntegerv(PACK_ROW_LENGTH, &row_length);
    gl.BindFramebuffer(READ_FRAMEBUFFER, fbo);
    gl.BindBuffer(PIXEL_PACK_BUFFER, 0);
    gl.PixelStorei(PACK_ALIGNMENT, 4);
    gl.PixelStorei(PACK_ROW_LENGTH, 0);
    const std::size_t stride = static_cast<std::size_t>(width) * 4;
    rgba.resize(stride * height);
    std::vector<std::uint8_t>& target = flip ? rows : rgba;
    target.resize(stride * height);
    gl.ReadPixels(0, 0, static_cast<GLsizei>(width), static_cast<GLsizei>(height), RGBA, UNSIGNED_BYTE, target.data());
    gl.BindFramebuffer(READ_FRAMEBUFFER, static_cast<GLuint>(read_binding));
    gl.BindBuffer(PIXEL_PACK_BUFFER, static_cast<GLuint>(pack_buffer));
    gl.PixelStorei(PACK_ALIGNMENT, alignment);
    gl.PixelStorei(PACK_ROW_LENGTH, row_length);
    if (flip)
        for (unsigned y = 0; y < height; ++y) std::memcpy(rgba.data() + y * stride, rows.data() + (height - 1 - y) * stride, stride);
    // The picture is opaque, whatever the core left in alpha.
    for (std::size_t i = 3; i < rgba.size(); i += 4) rgba[i] = 0xFF;
    return true;
}

void GlContext::destroy_framebuffer() {
    if (!context) return;
    if (fbo) gl.DeleteFramebuffers(1, &fbo);
    if (color) gl.DeleteRenderbuffers(1, &color);
    if (depth_stencil) gl.DeleteRenderbuffers(1, &depth_stencil);
    fbo = color = depth_stencil = 0;
    fbo_width = fbo_height = 0;
}

void GlContext::destroy() {
    destroy_framebuffer();
#ifdef _WIN32
    if (context) {
        wgl<MakeCurrent>("wglMakeCurrent")(nullptr, nullptr);
        wgl<DeleteContext>("wglDeleteContext")(static_cast<HGLRC>(context));
    }
    if (device) ReleaseDC(static_cast<HWND>(window), static_cast<HDC>(device));
    if (window) DestroyWindow(static_cast<HWND>(window));
    window = device = nullptr;
#else
    if (display) {
        const auto make_current = egl<EGLBoolean (*)(EGLDisplay, EGLSurface, EGLSurface, EGLContext)>("eglMakeCurrent");
        if (make_current) make_current(display, nullptr, nullptr, nullptr);
        if (context) egl<EGLBoolean (*)(EGLDisplay, EGLContext)>("eglDestroyContext")(display, context);
        if (surface) egl<EGLBoolean (*)(EGLDisplay, EGLSurface)>("eglDestroySurface")(display, surface);
        // eglTerminate would also end other EGL users of this display (Godot's).
    }
    display = surface = nullptr;
#endif
    context = nullptr;
}
}
