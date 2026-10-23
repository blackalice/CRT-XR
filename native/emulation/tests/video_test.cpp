// Decodes the clips from tests/make_video_fixtures.py with the system (or
// CRT_XR_FFMPEG_DIR) FFmpeg. Usage: crt-xr-video-test <fixture-folder>
#include "video_backend.h"
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

// Tests go through the same loader as the app: whichever FFmpeg the system has.
using VideoEngine = crt_xr::VideoBackend;

void check(bool value, const std::string& message) {
    if (!value) throw std::runtime_error(message);
    std::cout << "PASS: " << message << '\n';
}

struct Measure { int rows = 0, columns = 0; bool green_edge = false; };
// Picture extent along the centre column and centre row; bars are black.
Measure measure(const VideoEngine& video) {
    const auto& rgba = video.frame().rgba;
    const int width = video.info().width, height = video.info().height;
    auto pixel = [&](int x, int y) { return &rgba[(static_cast<std::size_t>(y) * width + x) * 4]; };
    auto lit = [](const std::uint8_t* p) { return p[0] > 60 || p[1] > 60 || p[2] > 60; };
    Measure result;
    for (int y = 0; y < height; ++y) result.rows += lit(pixel(width / 2, y));
    int first = -1;
    for (int x = 0; x < width; ++x) if (lit(pixel(x, height / 2))) { result.columns++; if (first < 0) first = x; }
    if (first >= 0) {
        const std::uint8_t* p = pixel(first + 2, height / 2);
        result.green_edge = p[1] > 100 && p[0] < 90 && p[2] < 90;
    }
    return result;
}

bool near(double value, double expected, double tolerance) { return std::fabs(value - expected) <= tolerance; }

// Pulls up to `seconds` of sound, taking video frames as needed so decoding moves on.
struct Sound { std::vector<float> left, right; double first_time = -1.0; };
Sound collect(VideoEngine& video, double seconds) {
    Sound sound;
    std::vector<float> chunk(4096 * 2);
    const auto wanted = static_cast<std::size_t>(seconds * VideoEngine::SAMPLE_RATE);
    for (int idle = 0; sound.left.size() < wanted && idle < 400;) {
        const double time = video.audio_time();
        const int got = video.read_audio(chunk.data(), static_cast<int>(std::min<std::size_t>(4096, wanted - sound.left.size())));
        if (got > 0) {
            if (sound.first_time < 0.0) sound.first_time = time;
            for (int i = 0; i < got; ++i) { sound.left.push_back(chunk[i * 2]); sound.right.push_back(chunk[i * 2 + 1]); }
            idle = 0;
        } else if (video.finished()) break;
        else if (!video.next(20)) ++idle;
    }
    return sound;
}
double level(const std::vector<float>& channel) {
    double sum = 0.0;
    for (float value : channel) sum += static_cast<double>(value) * value;
    return channel.empty() ? 0.0 : std::sqrt(sum / channel.size());
}
// Full cycles per second over the middle half, away from codec priming and
// end padding; swings must pass a quarter of the peak, so codec noise around
// zero is not counted as extra cycles.
double pitch(const std::vector<float>& channel) {
    const std::size_t begin = channel.size() / 4, end = channel.size() * 3 / 4;
    if (end <= begin) return 0.0;
    float peak = 0.0f;
    for (std::size_t i = begin; i < end; ++i) peak = std::max(peak, std::fabs(channel[i]));
    const float threshold = peak * 0.25f;
    int cycles = 0;
    bool high = false;
    std::size_t first = 0, last = 0;
    for (std::size_t i = begin; i < end; ++i) {
        if (!high && channel[i] > threshold) {
            high = true;
            if (cycles++ == 0) first = i;
            last = i;
        } else if (high && channel[i] < -threshold) high = false;
    }
    // Measured between the first and last rising edges: whole cycles only.
    return cycles < 2 ? 0.0 : (cycles - 1) / (static_cast<double>(last - first) / VideoEngine::SAMPLE_RATE);
}
void discard_audio(VideoEngine& video) {
    std::vector<float> sink(8192 * 2);
    while (video.read_audio(sink.data(), 8192) > 0) {}
}
bool wait_for_audio(VideoEngine& video) {
    for (int i = 0; i < 600; ++i) {
        if (video.audio_buffered() > 0) return true;
        std::this_thread::sleep_for(std::chrono::milliseconds(5));
    }
    return false;
}

int main(int argc, char** argv) {
    if (argc != 2) return 2;
    const std::string folder = std::string(argv[1]) + "/";
    try {
        std::string error;
        check(VideoEngine::load_libraries(error), "FFmpeg libraries load: " + (error.empty() ? VideoEngine::library_version() : error));
        auto missing_owner = VideoEngine::create();
        VideoEngine& missing = *missing_owner;
        check(!missing.open(folder + "missing.mp4", 480, VideoEngine::LETTERBOX) && !missing.error().empty(), "A missing file fails cleanly with a message");
        check(near(VideoEngine::probe_duration(folder + "two_tracks_25.mkv"), 4.0, 0.05) && VideoEngine::probe_duration(folder + "missing.mp4") < 0.0,
            "Listings read a file's length from its header");

        struct Clip { const char* name; double aspect, fps; };
        const Clip clips[] = {
            {"h264_aac_25.mp4", 16.0 / 9.0, 25.0}, {"hevc_ac3_23976.mkv", 16.0 / 9.0, 24000.0 / 1001.0},
            {"av1_opus_2997.mkv", 16.0 / 9.0, 30000.0 / 1001.0}, {"anamorphic_169_25.mkv", 16.0 / 9.0, 25.0},
            {"scope_239_24.mp4", 1920.0 / 804.0, 24.0}, {"classic_43_30.mp4", 4.0 / 3.0, 30.0},
            {"silent_169_30.mp4", 16.0 / 9.0, 30.0}, {"surround_51_25.mkv", 16.0 / 9.0, 25.0},
            {"two_tracks_25.mkv", 16.0 / 9.0, 25.0}};
        for (const Clip& clip : clips) {
            auto video_owner = VideoEngine::create();
            VideoEngine& video = *video_owner;
            check(video.open(folder + clip.name, 480, VideoEngine::LETTERBOX), std::string(clip.name) + " opens " + video.error());
            const auto& info = video.info();
            check(info.width == 640 && info.height == 480, std::string(clip.name) + " outputs a 640x480 frame");
            check(near(info.display_aspect, clip.aspect, 0.01) && near(info.fps, clip.fps, 0.01) && near(info.duration, 4.0, 0.15),
                std::string(clip.name) + " reports aspect " + std::to_string(info.display_aspect) + ", " + std::to_string(info.fps) + " fps, " + std::to_string(info.duration) + " s (" + info.codec + ")");
            int frames = 0;
            double last = -1.0;
            bool ordered = true;
            while (video.next(3000)) { ordered = ordered && video.frame().time > last; last = video.frame().time; ++frames; }
            discard_audio(video);
            const int expected = static_cast<int>(std::lround(clip.fps * 4.0));
            check(video.finished() && std::abs(frames - expected) <= 2 && ordered,
                std::string(clip.name) + " decodes " + std::to_string(frames) + " of ~" + std::to_string(expected) + " frames in order");
        }

        // Display styles: measured bars and side crops against the layout rules.
        struct Expect { const char* name; VideoEngine::Style style; int rows, columns; bool green; };
        const Expect styles[] = {
            {"h264_aac_25.mp4", VideoEngine::LETTERBOX, 360, 640, true},
            {"h264_aac_25.mp4", VideoEngine::FOURTEEN_NINE, 412, 640, false},
            {"h264_aac_25.mp4", VideoEngine::FILL, 480, 640, false},
            {"h264_aac_25.mp4", VideoEngine::STRETCH, 480, 640, true},
            {"anamorphic_169_25.mkv", VideoEngine::LETTERBOX, 360, 640, true},
            {"scope_239_24.mp4", VideoEngine::LETTERBOX, 268, 640, true},
            {"scope_239_24.mp4", VideoEngine::FOURTEEN_NINE, 412, 640, false},
            {"classic_43_30.mp4", VideoEngine::LETTERBOX, 480, 640, true},
            {"classic_43_30.mp4", VideoEngine::FILL, 480, 640, true},
        };
        const char* names[] = {"letterbox", "14:9", "fill 4:3", "stretch"};
        for (const Expect& expect : styles) {
            auto video_owner = VideoEngine::create();
            VideoEngine& video = *video_owner;
            video.open(folder + expect.name, 480, expect.style);
            check(video.next(3000), std::string(expect.name) + " " + names[expect.style] + " produces a frame");
            const Measure seen = measure(video);
            check(std::abs(seen.rows - expect.rows) <= 2 && std::abs(seen.columns - expect.columns) <= 2 && seen.green_edge == expect.green,
                std::string(expect.name) + " " + names[expect.style] + ": " + std::to_string(seen.rows) + " rows, " + std::to_string(seen.columns) +
                " columns, side bands " + (seen.green_edge ? "kept" : "cropped"));
        }
        check(VideoEngine::layout(1280, 720, 16.0 / 9.0, 640, 240, VideoEngine::LETTERBOX).height == 180 &&
            VideoEngine::layout(1280, 720, 16.0 / 9.0, 640, 240, VideoEngine::LETTERBOX).width == 640, "240-line letterbox keeps the 16:9 shape on the tall-pixel grid");
        {
            auto field_owner = VideoEngine::create();
            VideoEngine& field = *field_owner;
            field.open(folder + "h264_aac_25.mp4", 240, VideoEngine::LETTERBOX);
            check(field.info().width == 640 && field.info().height == 240 && field.next(3000) && measure(field).rows == 180 && measure(field).columns == 640,
                "240-line video keeps 640 columns and letterboxes 16:9 to 180 lines");
        }

        // GPU decoding: same picture as software; falls back when it cannot run.
        {
            const char* names[] = {"h264_aac_25.mp4", "hevc_ac3_23976.mkv", "av1_opus_2997.mkv"};
            for (const char* name : names) {
                auto software_owner = VideoEngine::create(), gpu_owner = VideoEngine::create();
                VideoEngine& software = *software_owner;
                VideoEngine& gpu = *gpu_owner;
                software.open(folder + name, 480, VideoEngine::LETTERBOX, false);
                gpu.open(folder + name, 480, VideoEngine::LETTERBOX, true);
                for (int i = 0; i < 10; ++i) { software.next(3000); gpu.next(3000); }
                const auto& a = software.frame().rgba;
                const auto& b = gpu.frame().rgba;
                double difference = 0.0;
                for (std::size_t i = 0; i < a.size() && i < b.size(); ++i) difference += std::abs(int(a[i]) - int(b[i]));
                difference /= std::max<std::size_t>(1, a.size());
                check(software.decoding() == "software" && a.size() == b.size() && difference < 2.0 && near(gpu.frame().time, software.frame().time, 0.001),
                    std::string(name) + " decodes on " + gpu.decoding() + " with the software picture (mean difference " + std::to_string(difference) + ")");
            }
#ifdef _WIN32
            _putenv_s("CRT_XR_VIDEO_HW_DEVICE", "unavailable");
#else
            setenv("CRT_XR_VIDEO_HW_DEVICE", "unavailable", 1);
#endif
            for (const char* name : {"h264_aac_25.mp4", "av1_opus_2997.mkv"}) {
                auto fallback_owner = VideoEngine::create();
                VideoEngine& fallback = *fallback_owner;
                const bool opened = fallback.open(folder + name, 480, VideoEngine::LETTERBOX, true);
                int frames = 0;
                while (frames < 20 && fallback.next(3000)) ++frames;
                check(frames == 20 && fallback.decoding() == "software",
                    std::string("Without a usable GPU, ") + name + " decodes in software (opened " + std::to_string(opened) + ", " + std::to_string(frames) + " frames, " + fallback.decoding() + ")");
            }
#ifdef _WIN32
            _putenv_s("CRT_XR_VIDEO_HW_DEVICE", "");
#else
            unsetenv("CRT_XR_VIDEO_HW_DEVICE");
#endif
        }

        // Interlaced video: each field in turn at the field rate, or blended.
        {
            auto average = [](const VideoEngine& video) {
                const auto& rgba = video.frame().rgba;
                double sum[3] = {};
                const std::size_t pixels = rgba.size() / 4;
                for (std::size_t i = 0; i < pixels; ++i) for (int c = 0; c < 3; ++c) sum[c] += rgba[i * 4 + c];
                return std::vector<double>{sum[0] / pixels, sum[1] / pixels, sum[2] / pixels};
            };
            auto fields_owner = VideoEngine::create();
            VideoEngine& fields = *fields_owner;
            fields.open(folder + "interlaced_576i_25.mkv", 240, VideoEngine::STRETCH, false);
            std::vector<double> times;
            std::vector<std::vector<double>> colours;
            for (int i = 0; i < 6 && fields.next(3000); ++i) { times.push_back(fields.frame().time); colours.push_back(average(fields)); }
            check(fields.interlaced() && times.size() == 6 && near(times[1] - times[0], 0.02, 0.002) && near(times[2] - times[0], 0.04, 0.002),
                "Interlaced video shows each field in turn, 50 a second (" + std::to_string(times.size() > 1 ? times[1] - times[0] : 0.0) + " s apart)");
            check(colours.size() == 6 && colours[0][1] > 200 && colours[1][1] < 40 && colours[2][1] > 200,
                "The top field comes first, then the bottom (white " + std::to_string(colours.empty() ? 0.0 : colours[0][1]) + ", then black " + std::to_string(colours.size() > 1 ? colours[1][1] : 0.0) + ")");
            auto blend_owner = VideoEngine::create();
            VideoEngine& blend = *blend_owner;
            blend.set_interlace(VideoEngine::BLEND);
            blend.open(folder + "interlaced_576i_25.mkv", 240, VideoEngine::STRETCH, false);
            std::vector<double> blended;
            for (int i = 0; i < 3 && blend.next(3000); ++i) blended.push_back(blend.frame().time);
            const auto mixed = average(blend);
            check(blended.size() == 3 && near(blended[1] - blended[0], 0.04, 0.002) && mixed[1] > 100 && mixed[1] < 155,
                "Blend mode mixes both fields at the frame rate (grey " + std::to_string(mixed[1]) + ")");
            auto progressive_owner = VideoEngine::create();
            VideoEngine& progressive = *progressive_owner;
            progressive.open(folder + "h264_aac_25.mp4", 240, VideoEngine::LETTERBOX, false);
            progressive.next(3000);
            const double first = progressive.frame().time;
            progressive.next(3000);
            check(!progressive.interlaced() && near(progressive.frame().time - first, 0.04, 0.002), "Progressive video is untouched");
        }

        // Subtitles: embedded text tracks, timed to the picture.
        {
            auto run_to = [](VideoEngine& video, double seconds) {
                while (video.frame().time < seconds && video.next(3000)) {}
            };
            auto owner = VideoEngine::create();
            VideoEngine& video = *owner;
            video.open(folder + "subtitles_srt.mkv", 240, VideoEngine::LETTERBOX, false);
            const auto& tracks = video.info().subtitle_tracks;
            check(tracks.size() == 1 && tracks[0].codec == "subrip" && tracks[0].language == "eng" && tracks[0].title == "English" && !tracks[0].bitmap,
                "Subtitle tracks are listed with language, title and format");
            check(video.subtitles_at(1.0).empty(), "Subtitles are off until a track is chosen");
            video.set_subtitle_track(0, 0.0);
            run_to(video, 3.5);
            const auto first = video.subtitles_at(1.0);
            const auto second = video.subtitles_at(2.5);
            check(first.size() == 1 && first[0].text == "Hello CRT" && video.subtitles_at(1.7).empty() && video.subtitles_at(3.2).empty(),
                "A subtitle shows only during its cue");
            check(second.size() == 1 && second[0].text == "Second line\nbreaks here", "Styling is removed and line breaks kept (" + (second.empty() ? std::string("none") : second[0].text) + ")");
            video.seek(2.2);
            video.next(3000); // the first picture after the seek
            run_to(video, 2.6);
            check(video.subtitles_at(2.5).size() == 1, "Subtitles come back after a seek");
            video.set_subtitle_track(-1, 2.5);
            check(video.subtitles_at(2.5).empty(), "Turning subtitles off clears them at once");
            auto mp4_owner = VideoEngine::create();
            VideoEngine& mp4 = *mp4_owner;
            mp4.open(folder + "subtitles_movtext.mp4", 240, VideoEngine::LETTERBOX, false);
            mp4.set_subtitle_track(0, 0.0);
            run_to(mp4, 1.6);
            const auto mp4_cue = mp4.subtitles_at(1.0);
            check(mp4.info().subtitle_tracks.size() == 1 && mp4.info().subtitle_tracks[0].codec == "mov_text" && mp4_cue.size() == 1 && mp4_cue[0].text == "Hello CRT",
                "MP4 text subtitles work the same way");
        }

        // Sound: 48 kHz stereo whatever the source, aligned with the picture.
        struct Tone { const char* name; const char* codec; };
        const Tone tones[] = {{"h264_aac_25.mp4", "aac"}, {"hevc_ac3_23976.mkv", "ac3"}, {"av1_opus_2997.mkv", "opus"}, {"anamorphic_169_25.mkv", "aac"}};
        for (const Tone& tone : tones) {
            auto video_owner = VideoEngine::create();
            VideoEngine& video = *video_owner;
            video.open(folder + tone.name, 480, VideoEngine::LETTERBOX);
            const auto& tracks = video.info().audio_tracks;
            check(video.has_audio() && tracks.size() == 1 && tracks[0].codec == tone.codec, std::string(tone.name) + " has one " + tone.codec + " track");
            const Sound sound = collect(video, 10.0);
            const double seconds = static_cast<double>(sound.left.size()) / VideoEngine::SAMPLE_RATE;
            check(near(seconds, 4.0, 0.06) && near(sound.first_time, 0.0, 0.03),
                std::string(tone.name) + " plays " + std::to_string(seconds) + " s of sound from " + std::to_string(sound.first_time) + " s");
            check(near(pitch(sound.left), 440.0, 3.0) && level(sound.left) > 0.03 && near(level(sound.left), level(sound.right), 0.01),
                std::string(tone.name) + " keeps the 440 Hz tone at 48 kHz (" + std::to_string(pitch(sound.left)) + " Hz) in both channels");
            check(video.finished(), std::string(tone.name) + " finishes once picture and sound are both used up");
        }
        {
            auto video_owner = VideoEngine::create();
            VideoEngine& video = *video_owner;
            video.open(folder + "surround_51_25.mkv", 480, VideoEngine::LETTERBOX);
            const Sound sound = collect(video, 1.0);
            check(video.info().audio_tracks[0].channels == 6 && level(sound.left) > 0.05 && level(sound.right) < level(sound.left) / 20.0,
                "5.1 sound downmixes to stereo with front left on the left (" + std::to_string(level(sound.left)) + " / " + std::to_string(level(sound.right)) + ")");
        }
        {
            auto video_owner = VideoEngine::create();
            VideoEngine& video = *video_owner;
            video.open(folder + "silent_169_30.mp4", 480, VideoEngine::LETTERBOX);
            check(!video.has_audio() && video.info().audio_tracks.empty() && video.next(3000) && video.audio_time() < 0.0, "A file without sound plays its picture silently");
        }
        {
            auto video_owner = VideoEngine::create();
            VideoEngine& video = *video_owner;
            video.open(folder + "two_tracks_25.mkv", 480, VideoEngine::LETTERBOX);
            const auto& tracks = video.info().audio_tracks;
            check(tracks.size() == 2 && tracks[0].language == "eng" && tracks[0].title == "Main" && tracks[1].language == "fra" && tracks[1].title == "Commentary" && video.info().audio_track == 0,
                "Audio tracks are listed with language and title, the first by default");
            check(near(pitch(collect(video, 0.5).left), 440.0, 3.0), "The default track plays");
            video.set_audio_track(1, 1.0);
            const bool arrived = wait_for_audio(video);
            const double start = video.audio_time();
            check(arrived && near(start, 1.0, 0.002), "Switching tracks resumes at the requested time (" + std::to_string(start) + " s)");
            check(near(pitch(collect(video, 0.5).left), 880.0, 3.0) && video.info().audio_track == 1, "The second track plays after switching");
        }
        {
            auto video_owner = VideoEngine::create();
            VideoEngine& video = *video_owner;
            video.open(folder + "h264_aac_25.mp4", 480, VideoEngine::LETTERBOX);
            collect(video, 0.2);
            video.seek(2.0);
            check(video.audio_time() < 0.0 && video.audio_buffered() == 0, "Seeking discards queued sound at once");
            const bool arrived = wait_for_audio(video);
            const double start = video.audio_time();
            check(arrived && near(start, 2.0, 0.002), "Sound resumes on the seek target to the sample (" + std::to_string(start) + " s)");
        }

        auto video_owner = VideoEngine::create();

        VideoEngine& video = *video_owner;
        video.open(folder + "h264_aac_25.mp4", 480, VideoEngine::LETTERBOX);
        // update() only collects what the worker has decoded so far; poll as the
        // game loop would.
        auto settle = [&](double clock) {
            for (int i = 0; i < 400 && video.frame().time < clock - 0.041; ++i) {
                video.update(clock);
                std::this_thread::sleep_for(std::chrono::milliseconds(5));
            }
        };
        settle(0.0);
        check(near(video.frame().time, 0.0, 0.001), "The first frame is due at time zero");
        check(!video.update(0.0), "No new frame until the clock reaches the next one");
        settle(1.0);
        check(near(video.frame().time, 1.0, 0.041) && video.dropped() > 0, "update() shows the latest due frame and skips late ones (" + std::to_string(video.frame().time) + " s)");
        video.set_style(VideoEngine::STRETCH);
        for (int i = 0; i < 8; ++i) video.next(3000);
        check(measure(video).rows == 480, "A style change applies to later frames without reopening");
        // Fetch before checking: argument evaluation order is unspecified, so the
        // message must not race the call that changes the frame.
        video.seek(2.5);
        bool got = video.next(3000);
        check(got && near(video.frame().time, 2.5, 0.041), "Seeking forward lands on the target frame (" + std::to_string(video.frame().time) + " s)");
        while (video.next(3000)) {}
        discard_audio(video);
        check(video.finished(), "Playback reaches the end");
        video.seek(0.6);
        got = video.next(3000);
        check(got && near(video.frame().time, 0.6, 0.041) && !video.finished(), "Seeking back after the end restarts decoding (" + std::to_string(video.frame().time) + " s)");
        video.close();
        check(!video.next(10), "A closed video yields no frames");
    } catch (const std::exception& failure) {
        std::cerr << "FAIL: " << failure.what() << '\n';
        return 1;
    }
    std::cout << "VIDEO DECODER CHECKS COMPLETE\n";
    return 0;
}
