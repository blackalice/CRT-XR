#include "video_decoder.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <algorithm>
#include <cstring>

using namespace godot;

void VideoDecoder::_bind_methods() {
    ClassDB::bind_static_method("VideoDecoder", D_METHOD("available"), &VideoDecoder::available);
    ClassDB::bind_static_method("VideoDecoder", D_METHOD("library_error"), &VideoDecoder::library_error);
    ClassDB::bind_static_method("VideoDecoder", D_METHOD("probe_duration", "path"), &VideoDecoder::probe_duration);
    ClassDB::bind_method(D_METHOD("open", "path", "lines", "style", "hardware"), &VideoDecoder::open, DEFVAL(true));
    ClassDB::bind_method(D_METHOD("decoding"), &VideoDecoder::decoding);
    ClassDB::bind_method(D_METHOD("update", "clock"), &VideoDecoder::update);
    ClassDB::bind_method(D_METHOD("frame"), &VideoDecoder::frame);
    ClassDB::bind_method(D_METHOD("frame_time"), &VideoDecoder::frame_time);
    ClassDB::bind_method(D_METHOD("seek", "seconds"), &VideoDecoder::seek);
    ClassDB::bind_method(D_METHOD("push_audio", "playback"), &VideoDecoder::push_audio);
    ClassDB::bind_method(D_METHOD("audio_time"), &VideoDecoder::audio_time);
    ClassDB::bind_method(D_METHOD("has_audio"), &VideoDecoder::has_audio);
    ClassDB::bind_method(D_METHOD("set_audio_track", "index", "seconds"), &VideoDecoder::set_audio_track);
    ClassDB::bind_method(D_METHOD("set_style", "style"), &VideoDecoder::set_style);
    ClassDB::bind_method(D_METHOD("get_style"), &VideoDecoder::get_style);
    ClassDB::bind_method(D_METHOD("finished"), &VideoDecoder::finished);
    ClassDB::bind_method(D_METHOD("dropped"), &VideoDecoder::dropped);
    ClassDB::bind_method(D_METHOD("last_error"), &VideoDecoder::last_error);
    ClassDB::bind_method(D_METHOD("close"), &VideoDecoder::close);
}

bool VideoDecoder::available() {
    std::string error;
    return crt_xr::VideoEngine::load_libraries(error);
}

String VideoDecoder::library_error() {
    std::string error;
    crt_xr::VideoEngine::load_libraries(error);
    return String::utf8(error.c_str());
}

double VideoDecoder::probe_duration(const String& path) { return crt_xr::VideoEngine::probe_duration(path.utf8().get_data()); }

Dictionary VideoDecoder::open(const String& path, int lines, int style, bool hardware) {
    Dictionary result;
    const auto chosen = static_cast<crt_xr::VideoEngine::Style>(std::clamp(style, 0, 3));
    if (!engine.open(path.utf8().get_data(), lines, chosen, hardware)) return result;
    const auto& info = engine.info();
    result["width"] = info.width;
    result["height"] = info.height;
    result["source_width"] = info.source_width;
    result["source_height"] = info.source_height;
    result["display_aspect"] = info.display_aspect;
    result["fps"] = info.fps;
    result["duration"] = info.duration;
    result["codec"] = String::utf8(info.codec.c_str());
    Array tracks;
    for (const auto& track : info.audio_tracks) {
        Dictionary entry;
        entry["language"] = String::utf8(track.language.c_str());
        entry["title"] = String::utf8(track.title.c_str());
        entry["codec"] = String::utf8(track.codec.c_str());
        entry["channels"] = track.channels;
        tracks.append(entry);
    }
    result["audio_tracks"] = tracks;
    result["audio_track"] = info.audio_track;
    result["sample_rate"] = crt_xr::VideoEngine::SAMPLE_RATE;
    return result;
}

// Fills the generator's free space; returns the frames pushed. Without a
// playback (no audio output) the decoded sound is discarded, so it never piles up.
int VideoDecoder::push_audio(const Ref<AudioStreamGeneratorPlayback>& playback) {
    const int space = playback.is_null() ? engine.audio_buffered() : static_cast<int>(playback->get_frames_available());
    const int count = std::min(space, engine.audio_buffered());
    if (count <= 0) return 0;
    scratch.resize(static_cast<std::size_t>(count) * 2);
    const int got = engine.read_audio(scratch.data(), count);
    if (playback.is_null()) return got;
    PackedVector2Array frames;
    frames.resize(got);
    auto* values = frames.ptrw();
    for (int i = 0; i < got; ++i) values[i] = Vector2(scratch[i * 2], scratch[i * 2 + 1]);
    playback->push_buffer(frames);
    return got;
}

String VideoDecoder::decoding() const { return String::utf8(engine.decoding().c_str()); }
double VideoDecoder::audio_time() const { return engine.audio_time(); }
bool VideoDecoder::has_audio() const { return engine.has_audio(); }
void VideoDecoder::set_audio_track(int index, double seconds) { engine.set_audio_track(index, seconds); }

bool VideoDecoder::update(double clock) { return engine.update(clock); }

PackedByteArray VideoDecoder::frame() const {
    PackedByteArray bytes;
    const auto& rgba = engine.frame().rgba;
    bytes.resize(static_cast<int64_t>(rgba.size()));
    if (!rgba.empty()) std::memcpy(bytes.ptrw(), rgba.data(), rgba.size());
    return bytes;
}

double VideoDecoder::frame_time() const { return engine.frame().time; }
void VideoDecoder::seek(double seconds) { engine.seek(seconds); }
void VideoDecoder::set_style(int style) { engine.set_style(static_cast<crt_xr::VideoEngine::Style>(std::clamp(style, 0, 3))); }
int VideoDecoder::get_style() const { return static_cast<int>(engine.style()); }
bool VideoDecoder::finished() const { return engine.finished(); }
int VideoDecoder::dropped() const { return engine.dropped(); }
String VideoDecoder::last_error() const { return String::utf8(engine.error().c_str()); }
void VideoDecoder::close() { engine.close(); }
