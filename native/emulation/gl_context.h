#pragma once
#include <cstdint>
#include <string>
#include <vector>

namespace crt_xr {
// A hidden OpenGL context for cores that draw with the GPU (SET_HW_RENDER).
// It is created on, and only ever current on, the core's own thread, so
// Godot's context is never touched: the core draws into an offscreen
// framebuffer and each frame is read back as RGBA. WGL on Windows; surfaceless
// EGL elsewhere, loaded at run time so the module has no OpenGL link dependency.
class GlContext {
public:
    ~GlContext();
    // Makes a context of at least version major.minor current on this thread.
    bool create(unsigned major, unsigned minor, bool core_profile, std::string& error);
    // The framebuffer the core draws into, at least width x height.
    bool resize(unsigned width, unsigned height, bool depth, bool stencil, std::string& error);
    void destroy_framebuffer();
    void destroy();
    bool ready() const { return context != nullptr; }
    unsigned framebuffer() const { return fbo; }
    unsigned width() const { return fbo_width; }
    unsigned height() const { return fbo_height; }
    // Reads the top-left width x height of the framebuffer as RGBA rows, top
    // first; flip reverses rows drawn bottom-up (OpenGL's own origin).
    bool read(unsigned width, unsigned height, bool flip, std::vector<std::uint8_t>& rgba);
    // OpenGL entry points for the core and for this class, core and 1.x alike.
    static void* proc(const char* name);
private:
    void* context = nullptr;
    unsigned fbo = 0, color = 0, depth_stencil = 0;
    unsigned fbo_width = 0, fbo_height = 0;
    std::vector<std::uint8_t> rows;
#ifdef _WIN32
    void* window = nullptr;
    void* device = nullptr;
#else
    void* display = nullptr;
    void* surface = nullptr;
#endif
};
}
