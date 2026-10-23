#pragma once
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace crt_xr {
// Video decoding behind one interface. Each supported FFmpeg major version has
// its own build of VideoEngine (struct layouts differ between majors); the
// static functions here pick whichever version the system provides.
class VideoBackend {
public:
    enum Style { LETTERBOX = 0, FOURTEEN_NINE = 1, FILL = 2, STRETCH = 3 };
    // How interlaced sources are shown: each field in turn at the field rate
    // (smooth TV motion), or both fields blended into one picture.
    enum Interlace { FIELDS = 0, BLEND = 1 };
    static constexpr int SAMPLE_RATE = 48000;
    struct AudioTrack {
        int stream = -1, channels = 0;
        std::string language, title, codec;
    };
    struct SubtitleTrack {
        int stream = -1;
        bool bitmap = false, forced = false;
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
        std::vector<SubtitleTrack> subtitle_tracks;
        bool hardware_requested = false;
    };
    struct Frame {
        std::vector<std::uint8_t> rgba;
        double time = 0.0; // seconds from the start of the file
    };
    // One subtitle, shown from `start` until `end`. Text cues carry plain text
    // (styling removed); picture cues carry RGBA of image_width x image_height,
    // drawn at x, y, width, height (source pixels when decoded, output frame
    // pixels from subtitles_at()).
    struct Cue {
        double start = 0.0, end = 0.0;
        std::string text;
        std::vector<std::uint8_t> rgba;
        int image_width = 0, image_height = 0;
        int x = 0, y = 0, width = 0, height = 0;
    };
    struct Layout { int crop_x = 0, crop_y = 0, crop_width = 0, crop_height = 0, x = 0, y = 0, width = 0, height = 0; };

    // Loads the newest supported FFmpeg the system has. False, with a reason,
    // when none loads. retry_libraries() forgets a failure (after a download).
    static bool load_libraries(std::string& error);
    static void retry_libraries();
    static std::string library_version();
    static std::unique_ptr<VideoBackend> create();
    // Length of a file from its header alone, for listings; -1 when unreadable.
    static double probe_duration(const std::string& path);
    // Where the picture sits inside the output frame for a style; the rest is bars.
    static Layout layout(int source_width, int source_height, double display_aspect, int width, int height, Style style);

    virtual ~VideoBackend() = default;
    // `hardware` tries the GPU decoder (VA-API on Linux, D3D11VA on Windows) and
    // falls back to software, at once or mid-stream, whenever it cannot be used.
    virtual bool open(const std::string& path, int lines, Style style, bool hardware = false) = 0;
    virtual void close() = 0;
    // Frames due at or before `clock`; returns true when `current` changed.
    // Late frames are skipped, never shown out of order.
    virtual bool update(double clock) = 0;
    // Waits for the next decoded frame regardless of time (tests and seeking).
    virtual bool next(int timeout_ms) = 0;
    virtual void seek(double seconds) = 0;
    // Interleaved stereo samples; returns how many frames were copied.
    virtual int read_audio(float* out, int frames) = 0;
    virtual int audio_buffered() const = 0;
    // Time of the next sample read_audio() returns, or -1 before any audio has
    // been decoded since opening or seeking.
    virtual double audio_time() const = 0;
    virtual bool has_audio() const = 0;
    // Switches tracks and resumes the new one from `seconds`.
    virtual void set_audio_track(int index, double seconds) = 0;
    // -1 turns subtitles off; cues decoded so far for other tracks are dropped.
    virtual void set_subtitle_track(int index, double seconds) = 0;
    // Cues showing at `clock` (normally none or one).
    virtual std::vector<Cue> subtitles_at(double clock) = 0;
    virtual void set_style(Style style) = 0;
    virtual Style style() const = 0;
    virtual void set_interlace(Interlace mode) = 0;
    virtual bool interlaced() const = 0; // the latest frame was interlaced
    virtual bool finished() const = 0;
    virtual const Info& info() const = 0;
    virtual const Frame& frame() const = 0;
    virtual std::string error() const = 0;
    virtual int dropped() const = 0;
    // "VA-API", "D3D11VA" or "software": how the latest frame was decoded.
    virtual std::string decoding() const = 0;
};
}
