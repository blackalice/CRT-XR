#pragma once
#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace crt_xr {
// Decodes one video file into a fixed 4:3 RGBA frame for the CRT, and its sound
// into 48 kHz stereo. FFmpeg is the operating system's copy, loaded at runtime;
// nothing from it is linked or shipped. A worker thread demuxes, decodes, scales
// and resamples ahead; the caller collects frames that are due and audio to play.
class VideoEngine {
public:
    enum Style { LETTERBOX = 0, FOURTEEN_NINE = 1, FILL = 2, STRETCH = 3 };
    static constexpr int SAMPLE_RATE = 48000;
    struct AudioTrack {
        int stream = -1, channels = 0;
        std::string language, title, codec;
    };
    struct Info {
        int width = 0, height = 0;               // output frame, shown at 4:3
        int source_width = 0, source_height = 0; // coded size
        double display_aspect = 4.0 / 3.0;       // including sample aspect ratio
        double fps = 0.0, duration = 0.0;
        std::string codec;
        std::vector<AudioTrack> audio_tracks;
        int audio_track = -1; // index into audio_tracks; -1 when silent
        bool hardware_requested = false;
    };
    struct Frame {
        std::vector<std::uint8_t> rgba;
        double time = 0.0; // seconds from the start of the file
    };
    // Loads the system libraries once per process. False when they are missing or
    // are not the FFmpeg major this build was compiled against.
    static bool load_libraries(std::string& error);
    // Length of a file from its header alone, for listings; -1 when unreadable.
    static double probe_duration(const std::string& path);
    ~VideoEngine();
    // `hardware` tries the GPU decoder (VA-API on Linux, D3D11VA on Windows) and
    // falls back to software, at once or mid-stream, whenever it cannot be used.
    bool open(const std::string& path, int lines, Style style, bool hardware = false);
    // "VA-API", "D3D11VA" or "software": how the latest frame was decoded.
    std::string decoding() const;
    void close();
    // Frames due at or before `clock`; returns true when `current` changed.
    // Late frames are skipped, never shown out of order.
    bool update(double clock);
    // Waits for the next decoded frame regardless of time (tests and seeking).
    bool next(int timeout_ms);
    void seek(double seconds);
    // Interleaved stereo samples; returns how many frames were copied.
    int read_audio(float* out, int frames);
    int audio_buffered() const;
    // Time of the next sample read_audio() returns, or -1 before any audio has
    // been decoded since opening or seeking.
    double audio_time() const;
    bool has_audio() const;
    // Switches tracks and resumes the new one from `seconds`.
    void set_audio_track(int index, double seconds);
    void set_style(Style style);
    Style style() const { return requested_style.load(); }
    bool finished() const;
    const Info& info() const { return details; }
    const Frame& frame() const { return current; }
    std::string error() const;
    int dropped() const { return dropped_frames; }
    // Where the picture sits inside the output frame for a style; the rest is bars.
    struct Layout { int crop_x = 0, crop_y = 0, crop_width = 0, crop_height = 0, x = 0, y = 0, width = 0, height = 0; };
    static Layout layout(int source_width, int source_height, double display_aspect, int width, int height, Style style);
private:
    void run();
    bool convert(void* decoded, Frame& out);
    void resample(void* decoded);
    bool open_audio(int track);
    void close_audio();
    void restart(double target);
    bool open_video(bool hardware);
    bool setup_hardware(void* context, const void* decoder);
    void request_software();
public:
    // FFmpeg's get_format hook, reached through a typed wrapper in the .cpp.
    static int choose_format(void* context, const int* formats);
private:
    void fail(const std::string& message);
    void* format = nullptr;  // AVFormatContext
    void* codec = nullptr;   // AVCodecContext
    void* scaler = nullptr;  // SwsContext
    void* audio_codec = nullptr; // AVCodecContext
    void* resampler = nullptr;   // SwrContext
    int stream = -1, audio_stream = -1;
    // Both streams count from the container's start, so they stay aligned.
    double time_base = 0.0, audio_time_base = 0.0, start_time = 0.0;
    int resampler_rate = 0, resampler_format = -1, resampler_channels = 0;
    std::vector<float> samples; // interleaved stereo, read from samples_read
    std::size_t samples_read = 0;
    double samples_time = -1.0; // time of samples[samples_read]
    bool track_pending = false;
    int track_target = -1;
    const void* video_decoder = nullptr; // AVCodec chosen for the video stream
    void* hardware_device = nullptr; // AVBufferRef
    void* transfer = nullptr;        // AVFrame: GPU frames are copied here once
    int hardware_format = -1;        // AVPixelFormat of GPU frames, -1 when unused
    std::string hardware_name;
    bool software_pending = false;
    bool gpu_open = false; // the current decoder was opened for the GPU
    double last_frame_time = 0.0;
    std::atomic<bool> decoded_on_gpu{false};
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
