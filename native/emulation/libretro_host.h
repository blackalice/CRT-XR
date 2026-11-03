#pragma once
#define RETRO_IMPORT_SYMBOLS
#include "libretro.h"
#include "gl_context.h"
#include <cstdint>
#include <array>
#include <atomic>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>

namespace crt_xr {

// Runs tasks one at a time on a thread of its own; run() waits for each.
class CoreThread {
public:
    CoreThread();
    ~CoreThread();
    bool is_current() const;
    void run(const std::function<void()>& task);
private:
    struct State;
    std::unique_ptr<State> state;
};
// One Libretro instance, driven from the Godot main thread. Several hosts may
// coexist when each loads its own copy of a core library. Per-instance callback
// functions also reach the correct host from threads owned by the core.
class LibretroHost {
public:
    ~LibretroHost();
    // Cores that draw with the GPU: set before load_core. Every
    // call into the core then runs on a thread of its own, where the core's hidden
    // OpenGL context lives, so Godot's context on the main thread is never touched.
    bool hardware_rendering = false;
    bool load_core(const std::string& path);
    bool load_game(const std::string& path, const std::string& save_directory);
    bool step(std::uint16_t buttons);
    bool reset();
    std::vector<std::uint8_t> vmu_lcd(unsigned index) const;
    void close_game();
    void close();
    std::vector<std::uint8_t> serialize();
    bool serialize_into(std::vector<std::uint8_t>& state); // reuses the buffer's capacity
    bool unserialize(const std::uint8_t* data, std::size_t size);
    std::vector<std::uint8_t> save_ram() const;
    bool set_save_ram(const std::uint8_t* data, std::size_t size);
    // A value for a core option that wins over the core's default. Kept until close().
    void set_option(const std::string& key, const std::string& value);
    void copy_options(const LibretroHost& other) { overrides = other.overrides; }
    // Multi-disc games (an .m3u playlist): the core's disc tray, when it has one.
    unsigned disc_count() const;
    unsigned disc_index() const;
    std::string disc_label(unsigned index) const;
    // Opens the tray, selects the disc and closes the tray a second later, as a
    // player would; games watch the lid to notice the swap.
    bool change_disc(unsigned index);
    bool loaded = false;
    // The controller in port 1, applied by load_game (for example a DualShock).
    unsigned port_device = RETRO_DEVICE_JOYPAD;
    // Left X/Y, right X/Y in Libretro's -32768..32767 range, held for the next step().
    std::int16_t analog[4] = {0, 0, 0, 0};
    std::int16_t trigger_pressure[2] = {0, 0};
    unsigned width = 0, height = 0;
    bool video_changed = false;
    std::uint64_t step_usec = 0, readback_usec = 0; // last frame, for profiling
    // False tells the core its audio is unused (input preview) and drops samples.
    bool want_audio = true;
    double fps = 60.0, sample_rate = 32040.0;
    std::string error, name;
    std::vector<std::uint8_t> rgba;
    std::vector<std::int16_t> pcm;
private:
    // Libretro callbacks have no userdata. A distinct function set per loaded
    // host routes callbacks from core-owned CPU threads without a global owner.
    static constexpr unsigned callback_capacity = 16;
    static std::array<std::atomic<LibretroHost*>, callback_capacity> callback_hosts;
    int callback_slot = -1;
    struct Callbacks {
        retro_environment_t environment;
        retro_video_refresh_t video;
        retro_audio_sample_t audio;
        retro_audio_sample_batch_t audio_batch;
        retro_input_poll_t input_poll;
        retro_input_state_t input;
        retro_hw_get_current_framebuffer_t framebuffer;
    };
    // Set by callback routing as well as direct calls into the core.
    static thread_local LibretroHost* active;
    struct Use {
        LibretroHost* previous;
        explicit Use(const LibretroHost* host) : previous(active) { active = const_cast<LibretroHost*>(host); }
        ~Use() { active = previous; }
    };
    template <std::size_t Slot> static Callbacks callbacks_for() {
        return {
            [](unsigned cmd, void* data) { Use use(callback_hosts[Slot].load()); return environment(cmd, data); },
            [](const void* data, unsigned w, unsigned h, std::size_t pitch) { Use use(callback_hosts[Slot].load()); video(data, w, h, pitch); },
            [](std::int16_t l, std::int16_t r) { Use use(callback_hosts[Slot].load()); audio(l, r); },
            [](const std::int16_t* data, std::size_t frames) { Use use(callback_hosts[Slot].load()); return audio_batch(data, frames); },
            [] { Use use(callback_hosts[Slot].load()); input_poll(); },
            [](unsigned port, unsigned device, unsigned index, unsigned id) { Use use(callback_hosts[Slot].load()); return input(port, device, index, id); },
            [] { Use use(callback_hosts[Slot].load()); return current_framebuffer(); }
        };
    }
    template <std::size_t... Slots> static auto callback_table(std::index_sequence<Slots...>) {
        return std::array<Callbacks, sizeof...(Slots)>{callbacks_for<Slots>()...};
    }
    static const std::array<Callbacks, callback_capacity> callbacks;
    std::atomic<std::uint16_t> input_buttons{0};
    std::atomic<std::int16_t> input_analog[4]{};
    std::atomic<std::int16_t> input_triggers[2]{};
    std::mutex audio_mutex;
    std::vector<std::int16_t> pending_pcm;
    bool audio_overflow = false;
    void* library = nullptr;
    bool initialized = false;
    unsigned controller_ports = 2;
    bool (*fn_vmu_lcd)(unsigned, std::uint8_t*, std::size_t) = nullptr;
    retro_pixel_format pixel_format = RETRO_PIXEL_FORMAT_0RGB1555;
    std::uint16_t buttons = 0;
    std::string system_dir, save_dir;
    std::map<std::string, std::string> options, overrides;
    std::vector<std::uint8_t> rom;
    retro_disk_control_ext_callback disk{};
    int insert_countdown = 0; // frames until the opened tray closes; 0 = none pending
    std::unique_ptr<CoreThread> worker;
    std::unique_ptr<GlContext> gl;
    retro_hw_render_callback hw{};
    bool hw_active = false;
    // A hardware core that is unloaded before it ever ran a frame (Dolphin) is left
    // in a state that crashes the next load; close_game runs one frame first.
    bool ran_frame = false;
    // Runs f on the core's thread when it has one (and is not already there).
    template <class F> auto on_core(F&& f) const -> decltype(f()) {
        if (!worker || worker->is_current()) return f();
        if constexpr (std::is_void_v<decltype(f())>) worker->run([&] { f(); });
        else {
            decltype(f()) result{};
            worker->run([&] { result = f(); });
            return result;
        }
    }
    bool set_hw_render(retro_hw_render_callback& callback);
    static std::uintptr_t current_framebuffer();
    static retro_proc_address_t proc_address(const char* name);
    bool av_info(const retro_system_av_info& info);
    static bool environment(unsigned command, void* data);
    static void video(const void* data, unsigned width, unsigned height, std::size_t pitch);
    static void audio(std::int16_t left, std::int16_t right);
    static std::size_t audio_batch(const std::int16_t* data, std::size_t frames);
    static void input_poll();
    static std::int16_t input(unsigned port, unsigned device, unsigned index, unsigned id);
    static void log(retro_log_level level, const char* format, ...);
#define CORE_API(method) decltype(&retro_##method) fn_##method = nullptr
    CORE_API(api_version); CORE_API(init); CORE_API(deinit);
    CORE_API(set_environment); CORE_API(set_video_refresh);
    CORE_API(set_audio_sample); CORE_API(set_audio_sample_batch);
    CORE_API(set_input_poll); CORE_API(set_input_state);
    CORE_API(get_system_info); CORE_API(get_system_av_info);
    CORE_API(set_controller_port_device); CORE_API(load_game); CORE_API(unload_game); CORE_API(reset);
    CORE_API(run); CORE_API(serialize_size); CORE_API(serialize); CORE_API(unserialize);
    CORE_API(get_memory_data); CORE_API(get_memory_size);
#undef CORE_API
};
}
