#pragma once
#include "video_engine.h"
#include <godot_cpp/classes/audio_stream_generator_playback.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

// Plays a video file into the CRT picture and the TV's sound. Frames and audio
// are collected on the main thread; decoding runs ahead on the engine's worker.
class VideoDecoder : public godot::RefCounted {
    GDCLASS(VideoDecoder, godot::RefCounted)
    crt_xr::VideoEngine engine;
    std::vector<float> scratch; // reused between push_audio() calls
protected:
    static void _bind_methods();
public:
    static bool available();
    static godot::String library_error();
    static double probe_duration(const godot::String& path);
    godot::Dictionary open(const godot::String& path, int lines, int style, bool hardware = true);
    godot::String decoding() const;
    bool update(double clock);
    godot::PackedByteArray frame() const;
    double frame_time() const;
    void seek(double seconds);
    int push_audio(const godot::Ref<godot::AudioStreamGeneratorPlayback>& playback);
    double audio_time() const;
    bool has_audio() const;
    void set_audio_track(int index, double seconds);
    void set_style(int style);
    int get_style() const;
    bool finished() const;
    int dropped() const;
    godot::String last_error() const;
    void close();
};
