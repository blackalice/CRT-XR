#pragma once
// One FFmpeg major version's decoder. This header and video_engine.cpp are
// compiled once per supported major, each into its own namespace (set by
// CRT_XR_FFMPEG_NAMESPACE), because FFmpeg's struct layouts differ between
// majors. Everything outside reaches it through VideoBackend.
#include "video_backend.h"
#include <atomic>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <thread>

#ifndef CRT_XR_FFMPEG_NAMESPACE
#error "Compile video_engine.cpp with CRT_XR_FFMPEG_NAMESPACE set (for example ffmpeg61)"
#endif

namespace crt_xr {
namespace CRT_XR_FFMPEG_NAMESPACE {
// Loads this major's libraries once; reset() forgets a failure so a later
// attempt (after the libraries were installed) can succeed.
bool load(std::string& error);
void reset();
std::string version();
double probe(const std::string& path);
std::unique_ptr<VideoBackend> create();

// Decodes one video file into a fixed 4:3 RGBA frame for the CRT, its sound into
// 48 kHz stereo and its subtitles into cues. A worker thread demuxes, decodes,
// scales and resamples ahead; the caller collects what is due.
class VideoEngine final : public VideoBackend {
public:
    ~VideoEngine() override;
    bool open(const std::string& path, int lines, Style style, bool hardware) override;
    void close() override;
    bool update(double clock) override;
    bool next(int timeout_ms) override;
    void seek(double seconds) override;
    int read_audio(float* out, int frames) override;
    int audio_buffered() const override;
    double audio_time() const override;
    bool has_audio() const override;
    void set_audio_track(int index, double seconds) override;
    void set_subtitle_track(int index, double seconds) override;
    std::vector<Cue> subtitles_at(double clock) override;
    void set_style(Style style) override { requested_style = style; }
    Style style() const override { return requested_style.load(); }
    void set_interlace(Interlace mode) override { interlace_mode = mode; }
    bool interlaced() const override { return last_interlaced.load(); }
    bool finished() const override;
    const Info& info() const override { return details; }
    const Frame& frame() const override { return current; }
    std::string error() const override;
    int dropped() const override { return dropped_frames; }
    std::string decoding() const override;
    // FFmpeg's get_format hook, reached through a typed wrapper in the .cpp.
    static int choose_format(void* context, const int* formats);
private:
    void run();
    bool convert(void* decoded, double time);
    bool scale(void* source, int field, const Layout& place, std::vector<std::uint8_t>& out);
    void queue(Frame& frame);
    void resample(void* decoded);
    void decode_subtitle(void* packet);
    bool open_audio(int track);
    void close_audio();
    bool open_subtitles(int track);
    void close_subtitles();
    void restart(double target);
    bool open_video(bool hardware);
    bool setup_hardware(void* context, const void* decoder);
    void request_software();
    void fail(const std::string& message);
    void* format = nullptr;  // AVFormatContext
    void* codec = nullptr;   // AVCodecContext
    void* scaler = nullptr;  // SwsContext
    void* audio_codec = nullptr; // AVCodecContext
    void* resampler = nullptr;   // SwrContext
    void* subtitle_codec = nullptr; // AVCodecContext
    int stream = -1, audio_stream = -1, subtitle_stream = -1;
    // All streams count from the container's start, so they stay aligned.
    double time_base = 0.0, audio_time_base = 0.0, subtitle_time_base = 0.0, start_time = 0.0;
    int resampler_rate = 0, resampler_format = -1, resampler_channels = 0;
    std::vector<float> samples; // interleaved stereo, read from samples_read
    std::size_t samples_read = 0;
    double samples_time = -1.0; // time of samples[samples_read]
    bool track_pending = false;
    int track_target = -1;
    bool subtitle_pending = false;
    int subtitle_target = -1;
    std::vector<Cue> cues; // sorted by start; guarded by lock
    std::vector<std::uint8_t> blend_scratch;
    const void* video_decoder = nullptr; // AVCodec chosen for the video stream
    void* hardware_device = nullptr; // AVBufferRef
    void* transfer = nullptr;        // AVFrame: GPU frames are copied here once
    int hardware_format = -1;        // AVPixelFormat of GPU frames, -1 when unused
    std::string hardware_name;
    bool software_pending = false;
    bool gpu_open = false; // the current decoder was opened for the GPU
    double last_frame_time = 0.0;
    std::atomic<bool> decoded_on_gpu{false};
    std::atomic<bool> last_interlaced{false};
    std::atomic<Interlace> interlace_mode{FIELDS};
    Info details;
    Frame current;
    std::thread worker;
    mutable std::mutex lock;
    std::condition_variable changed;
    std::deque<Frame> ready, spare;
    std::atomic<bool> running{false};
    std::atomic<Style> requested_style{LETTERBOX};
    bool end_of_file = false;
    bool seek_pending = false;
    double seek_target = 0.0, seek_floor = -1.0;
    int dropped_frames = 0;
    std::string message;
    static constexpr std::size_t AHEAD = 4;
    // Keep decoding past AHEAD video frames while audio is below this, so sound
    // never starves on files that interleave audio late; VIDEO_LIMIT caps memory.
    static constexpr int AUDIO_LOW = SAMPLE_RATE / 2;
    static constexpr std::size_t VIDEO_LIMIT = 24;
};
}
}
