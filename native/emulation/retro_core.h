#pragma once
#include "libretro_host.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/audio_stream_generator_playback.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

class RetroCore : public godot::RefCounted {
    GDCLASS(RetroCore, godot::RefCounted)
    crt_xr::LibretroHost host;
    std::unique_ptr<crt_xr::CoreThread> frame_worker;
    bool frame_pending = false, frame_ok = false;
    struct FrameTiming { std::uint64_t wall, step, readback; std::size_t audio; bool video; };
    std::vector<FrameTiming> frame_timings;
    void wait_frame() const;
    // Input preview runs in a second copy of the core so the playing instance is
    // never rewound; its audio then stays continuous for every core.
    crt_xr::LibretroHost preview_host;
    std::string preview_library;
    std::vector<std::uint8_t> preview_state; // reused every frame
protected:
    static void _bind_methods();
public:
    ~RetroCore();
    bool begin_frame(int buttons, int frames = 1);
    int poll_frame(); // 0 running, 1 completed, -1 failed, -2 no request
    bool load_core(const godot::String& path);
    bool load_game(const godot::String& path, const godot::String& saves);
    void set_option(const godot::String& key, const godot::String& value);
    void set_controller(int device);
    void set_hardware_rendering(bool enabled);
    void set_trigger_pressure(int left, int right);
    void set_analog(int left_x, int left_y, int right_x, int right_y);
    godot::Dictionary disc_info() const;
    bool change_disc(int index);
    bool run_frame(int buttons);
    bool reset();
    godot::PackedByteArray vmu_lcd(int index = 0) const;
    godot::PackedByteArray frame() const;
    godot::Dictionary info() const;
    bool video_changed() const;
    godot::String last_error() const;
    int push_audio(const godot::Ref<godot::AudioStreamGeneratorPlayback>& playback);
    godot::PackedByteArray save_state();
    bool load_state(const godot::PackedByteArray& state);
    godot::PackedByteArray save_ram() const;
    bool load_ram(const godot::PackedByteArray& ram);
    void close_game();
    void close();
    bool load_preview(const godot::String& core_path, const godot::String& game_path, const godot::String& directory);
    godot::Dictionary run_preview(int buttons, int frames);
    bool has_preview() const;
    void close_preview();
};
