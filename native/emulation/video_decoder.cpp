#include "video_decoder.h"
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <algorithm>
#include <cstring>

using namespace godot;
using crt_xr::VideoBackend;

void VideoDecoder::_bind_methods() {
    ClassDB::bind_static_method("VideoDecoder", D_METHOD("available"), &VideoDecoder::available);
    ClassDB::bind_static_method("VideoDecoder", D_METHOD("library_error"), &VideoDecoder::library_error);
    ClassDB::bind_static_method("VideoDecoder", D_METHOD("library_version"), &VideoDecoder::library_version);
    ClassDB::bind_static_method("VideoDecoder", D_METHOD("retry_libraries"), &VideoDecoder::retry_libraries);
    ClassDB::bind_static_method("VideoDecoder", D_METHOD("probe_duration", "path"), &VideoDecoder::probe_duration);
    ClassDB::bind_static_method("VideoDecoder", D_METHOD("crc32", "bytes"), &VideoDecoder::crc32);
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
    ClassDB::bind_method(D_METHOD("set_subtitle_track", "index", "seconds"), &VideoDecoder::set_subtitle_track);
    ClassDB::bind_method(D_METHOD("subtitles_at", "clock"), &VideoDecoder::subtitles_at);
    ClassDB::bind_method(D_METHOD("set_style", "style"), &VideoDecoder::set_style);
    ClassDB::bind_method(D_METHOD("get_style"), &VideoDecoder::get_style);
    ClassDB::bind_method(D_METHOD("set_interlace", "mode"), &VideoDecoder::set_interlace);
    ClassDB::bind_method(D_METHOD("interlaced"), &VideoDecoder::interlaced);
    ClassDB::bind_method(D_METHOD("finished"), &VideoDecoder::finished);
    ClassDB::bind_method(D_METHOD("dropped"), &VideoDecoder::dropped);
    ClassDB::bind_method(D_METHOD("last_error"), &VideoDecoder::last_error);
    ClassDB::bind_method(D_METHOD("close"), &VideoDecoder::close);
}

bool VideoDecoder::available() {
    std::string error;
    return VideoBackend::load_libraries(error);
}

String VideoDecoder::library_error() {
    std::string error;
    VideoBackend::load_libraries(error);
    return String::utf8(error.c_str());
}

String VideoDecoder::library_version() { return String::utf8(VideoBackend::library_version().c_str()); }

bool VideoDecoder::retry_libraries() {
    VideoBackend::retry_libraries();
    return available();
}

double VideoDecoder::probe_duration(const String& path) { return VideoBackend::probe_duration(path.utf8().get_data()); }

int64_t VideoDecoder::crc32(const PackedByteArray& bytes) {
    static std::uint32_t table[256] = {};
    if (!table[1])
        for (std::uint32_t n = 0; n < 256; ++n) {
            std::uint32_t c = n;
            for (int k = 0; k < 8; ++k) c = c & 1 ? 0xEDB88320u ^ (c >> 1) : c >> 1;
            table[n] = c;
        }
    std::uint32_t crc = 0xFFFFFFFFu;
    const std::uint8_t* data = bytes.ptr();
    for (int64_t i = 0; i < bytes.size(); ++i) crc = table[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
    return static_cast<int64_t>(crc ^ 0xFFFFFFFFu);
}

Dictionary VideoDecoder::open(const String& path, int lines, int style, bool hardware) {
    Dictionary result;
    if (!engine) engine = VideoBackend::create();
    if (!engine) return result;
    engine->set_interlace(interlace == 1 ? VideoBackend::BLEND : VideoBackend::FIELDS);
    const auto chosen = static_cast<VideoBackend::Style>(std::clamp(style, 0, 3));
    if (!engine->open(path.utf8().get_data(), lines, chosen, hardware)) return result;
    const auto& info = engine->info();
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
    Array subtitles;
    for (const auto& track : info.subtitle_tracks) {
        Dictionary entry;
        entry["language"] = String::utf8(track.language.c_str());
        entry["title"] = String::utf8(track.title.c_str());
        entry["codec"] = String::utf8(track.codec.c_str());
        entry["bitmap"] = track.bitmap;
        entry["forced"] = track.forced;
        subtitles.append(entry);
    }
    result["subtitle_tracks"] = subtitles;
    result["sample_rate"] = VideoBackend::SAMPLE_RATE;
    return result;
}

String VideoDecoder::decoding() const { return engine ? String::utf8(engine->decoding().c_str()) : String(); }
bool VideoDecoder::update(double clock) { return engine && engine->update(clock); }

PackedByteArray VideoDecoder::frame() const {
    PackedByteArray bytes;
    if (!engine) return bytes;
    const auto& rgba = engine->frame().rgba;
    bytes.resize(static_cast<int64_t>(rgba.size()));
    if (!rgba.empty()) std::memcpy(bytes.ptrw(), rgba.data(), rgba.size());
    return bytes;
}

double VideoDecoder::frame_time() const { return engine ? engine->frame().time : -1.0; }
void VideoDecoder::seek(double seconds) { if (engine) engine->seek(seconds); }

// Fills the generator's free space; returns the frames pushed. Without a
// playback (no audio output) the decoded sound is discarded, so it never piles up.
int VideoDecoder::push_audio(const Ref<AudioStreamGeneratorPlayback>& playback) {
    if (!engine) return 0;
    const int space = playback.is_null() ? engine->audio_buffered() : static_cast<int>(playback->get_frames_available());
    const int count = std::min(space, engine->audio_buffered());
    if (count <= 0) return 0;
    scratch.resize(static_cast<std::size_t>(count) * 2);
    const int got = engine->read_audio(scratch.data(), count);
    if (playback.is_null()) return got;
    PackedVector2Array frames;
    frames.resize(got);
    auto* values = frames.ptrw();
    for (int i = 0; i < got; ++i) values[i] = Vector2(scratch[i * 2], scratch[i * 2 + 1]);
    playback->push_buffer(frames);
    return got;
}

double VideoDecoder::audio_time() const { return engine ? engine->audio_time() : -1.0; }
bool VideoDecoder::has_audio() const { return engine && engine->has_audio(); }
void VideoDecoder::set_audio_track(int index, double seconds) { if (engine) engine->set_audio_track(index, seconds); }
void VideoDecoder::set_subtitle_track(int index, double seconds) { if (engine) engine->set_subtitle_track(index, seconds); }

// Cues showing now: {text} for text subtitles, {image, x, y, width, height} for
// picture subtitles placed on the output frame.
Array VideoDecoder::subtitles_at(double clock) {
    Array showing;
    if (!engine) return showing;
    for (const auto& cue : engine->subtitles_at(clock)) {
        Dictionary entry;
        entry["start"] = cue.start;
        entry["end"] = cue.end;
        entry["text"] = String::utf8(cue.text.c_str());
        if (!cue.rgba.empty()) {
            PackedByteArray pixels;
            pixels.resize(static_cast<int64_t>(cue.rgba.size()));
            std::memcpy(pixels.ptrw(), cue.rgba.data(), cue.rgba.size());
            entry["image"] = Image::create_from_data(cue.image_width, cue.image_height, false, Image::FORMAT_RGBA8, pixels);
            entry["x"] = cue.x; entry["y"] = cue.y; entry["width"] = cue.width; entry["height"] = cue.height;
        }
        showing.append(entry);
    }
    return showing;
}

void VideoDecoder::set_style(int style) { if (engine) engine->set_style(static_cast<VideoBackend::Style>(std::clamp(style, 0, 3))); }
int VideoDecoder::get_style() const { return engine ? static_cast<int>(engine->style()) : 0; }
void VideoDecoder::set_interlace(int mode) {
    interlace = mode == 1 ? 1 : 0;
    if (engine) engine->set_interlace(interlace == 1 ? VideoBackend::BLEND : VideoBackend::FIELDS);
}
bool VideoDecoder::interlaced() const { return engine && engine->interlaced(); }
bool VideoDecoder::finished() const { return engine && engine->finished(); }
int VideoDecoder::dropped() const { return engine ? engine->dropped() : 0; }

String VideoDecoder::last_error() const {
    if (!engine) return library_error();
    return String::utf8(engine->error().c_str());
}

void VideoDecoder::close() { if (engine) engine->close(); }
