#pragma once
#include "libretro_host.h"
#include <chrono>
#include <condition_variable>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/audio_stream_generator_playback.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

class RetroCore : public godot::RefCounted {
    GDCLASS(RetroCore, godot::RefCounted)
    crt_xr::LibretroHost host;
    std::unique_ptr<crt_xr::CoreThread> frame_worker;
    bool frame_pending = false, frame_ok = false;
    struct FrameTiming { std::uint64_t wall, step, readback; std::size_t audio; bool video; std::uint64_t at = 0; };
    std::vector<FrameTiming> frame_timings;
    // Streaming: the worker runs frames back to back, paced by the audio the
    // device still has queued, so it never idles waiting for a room update. The
    // caller only exchanges input, audio and the newest picture. Any other call
    // stops the stream first (waiting for the frame in flight).
    struct Stream {
        std::mutex mutex;
        std::condition_variable wake;
        bool stop = false, failed = false;
        std::string error;
        std::vector<std::int16_t> pcm;      // produced, not yet pushed
        std::vector<std::uint8_t> rgba;     // newest picture
        unsigned width = 0, height = 0;
        bool fresh = false;
        std::uint64_t dropped = 0;          // pictures replaced before collection
        // When the newest picture's frame finished emulating, and the delay to
        // each collection (drained by stream_info), for latency measurements.
        std::chrono::steady_clock::time_point picture_base{};
        std::vector<std::uint32_t> ages;
        std::vector<std::uint8_t> vmu;
        bool want_vmu = false;
        std::vector<FrameTiming> timings;   // drained by stream_info
        double fps = 60.0, sample_rate = 48000.0;
        double display_aspect = 0.0;
        int reserve_frames = 8;
        // The device the worker fills directly; null: paced by the wall clock.
        godot::Ref<godot::AudioStreamGeneratorPlayback> playback;
        godot::PackedVector2Array push_scratch;
        double capacity = 0.0;              // the device's total frames
        std::chrono::steady_clock::time_point started{};
        std::uint64_t frames_run = 0;
        bool ticked = false;                // paced by stream_tick grants
        int credit = 0;                     // granted frames not yet started
        std::atomic<std::uint16_t> buttons{0};
        std::atomic<std::int16_t> analog[4]{}, triggers[2]{};
    };
    std::unique_ptr<Stream> stream = std::make_unique<Stream>();
    mutable bool streaming = false;
    std::vector<std::uint8_t> stream_front;
    void stream_loop();
    static void stream_push(Stream& s);
    void discard_stream_output();
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
    // Streaming (see Stream). reserve_frames: emulated frames of audio to keep queued.
    bool start_stream(int reserve_frames, bool async_readback);
    void stop_stream();          // requests a stop; returns at once
    bool stream_running() const; // false once a requested stop has finished
    void stream_input(int buttons, int left_x, int left_y, int right_x, int right_y, int left_trigger, int right_trigger);
    // Pushes produced audio that fits; capacity is the playback's total frames.
    // A null playback drops the audio (no device). Returns frames pushed.
    int stream_audio(const godot::Ref<godot::AudioStreamGeneratorPlayback>& playback, int capacity);
    godot::PackedByteArray stream_frame(); // the newest picture once, else empty
    godot::Dictionary stream_info();       // size, clock, failure and timings since the last call
    void stream_set_reserve(int reserve_frames); // takes effect without stopping
    void stream_tick(int frames);                // display-locked pacing: frames to run now
    void stream_vmu(bool enabled);
    godot::PackedByteArray stream_vmu_lcd();
    bool load_core(const godot::String& path);
    bool load_game(const godot::String& path, const godot::String& saves);
    void set_option(const godot::String& key, const godot::String& value);
    void set_controller(int device);
    void set_hardware_rendering(bool enabled);
    void set_destroy_context_first(bool enabled);
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
