#pragma once
#include "video_backend.h"
#include <godot_cpp/classes/audio_stream_generator_playback.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

// Plays a video file into the CRT picture and the TV's sound. Frames, audio and
// subtitles are collected on the main thread; decoding runs ahead on a worker.
// The decoder is built for whichever FFmpeg version the system provides.
class VideoDecoder : public godot::RefCounted {
    GDCLASS(VideoDecoder, godot::RefCounted)
    std::unique_ptr<crt_xr::VideoBackend> engine;
    std::vector<float> scratch; // reused between push_audio() calls
    int interlace = 0; // kept here so it survives the decoder being created later
protected:
    static void _bind_methods();
public:
    static bool available();
    static godot::String library_error();
    static godot::String library_version();
    // Forgets a failed load so newly installed libraries are found.
    static bool retry_libraries();
    static double probe_duration(const godot::String& path);
    // Zip-style CRC-32, for checking downloaded libraries against their archive.
    static int64_t crc32(const godot::PackedByteArray& bytes);
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
    void set_subtitle_track(int index, double seconds);
    godot::Array subtitles_at(double clock);
    void set_style(int style);
    int get_style() const;
    void set_interlace(int mode);
    bool interlaced() const;
    bool finished() const;
    int dropped() const;
    godot::String last_error() const;
    void close();
};
