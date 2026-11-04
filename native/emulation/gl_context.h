#pragma once
#include <cstddef>
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
    // Asynchronous readback (pixel-pack buffers and fences), when the driver has it.
    bool async_available() const;
    // Starts reading this frame and returns the previous one: 1 with a picture
    // (its size in out_*), 0 when none was pending yet, -1 on failure.
    int read_async(unsigned width, unsigned height, bool flip, std::vector<std::uint8_t>& rgba,
                   unsigned& out_width, unsigned& out_height);
    // Collects the newest started read, waiting for the GPU if necessary.
    int finish_async(std::vector<std::uint8_t>& rgba, unsigned& out_width, unsigned& out_height);
    // Collects the newest started read only if the GPU has finished it:
    // 1 collected, 0 not finished yet, -1 none pending.
    int poll_async(std::vector<std::uint8_t>& rgba, unsigned& out_width, unsigned& out_height);
    // Drops started reads, for example when switching back to synchronous reads.
    void discard_async();
    // OpenGL entry points for the core and for this class, core and 1.x alike.
    static void* proc(const char* name);
private:
    void* context = nullptr;
    unsigned fbo = 0, color = 0, depth_stencil = 0;
    unsigned fbo_width = 0, fbo_height = 0;
    std::vector<std::uint8_t> rows;
    struct PendingRead { unsigned buffer = 0; std::size_t capacity = 0; void* fence = nullptr; unsigned width = 0, height = 0; bool flip = false; };
    PendingRead pending[2];
    int next_pending = 0;
    int collect(PendingRead& read, std::vector<std::uint8_t>& rgba, unsigned& out_width, unsigned& out_height);
    static void gla_bind_pack(unsigned buffer);
#ifdef _WIN32
    void* window = nullptr;
    void* device = nullptr;
#else
    void* display = nullptr;
    void* surface = nullptr;
#endif
};
}
