#include "video_backend.h"
#include <algorithm>
#include <cmath>
#include <mutex>

namespace crt_xr {
// One build of the decoder per supported FFmpeg major (video_engine.cpp).
#define CRT_XR_DECLARE_VERSION(name) \
    namespace name { bool load(std::string&); void reset(); std::string version(); \
        double probe(const std::string&); std::unique_ptr<VideoBackend> create(); }
CRT_XR_DECLARE_VERSION(ffmpeg61)
CRT_XR_DECLARE_VERSION(ffmpeg62)
#undef CRT_XR_DECLARE_VERSION

namespace {
struct Version {
    const char* name;
    bool (*load)(std::string&);
    void (*reset)();
    std::string (*version)();
    double (*probe)(const std::string&);
    std::unique_ptr<VideoBackend> (*create)();
};
// Newest first: the system's FFmpeg is whichever of these loads.
const Version versions[] = {
    {"FFmpeg 8 (libavcodec 62)", ffmpeg62::load, ffmpeg62::reset, ffmpeg62::version, ffmpeg62::probe, ffmpeg62::create},
    {"FFmpeg 7.1 (libavcodec 61)", ffmpeg61::load, ffmpeg61::reset, ffmpeg61::version, ffmpeg61::probe, ffmpeg61::create},
};
std::mutex choice_lock;
const Version* chosen = nullptr;

int even(double value) { return std::max(2, static_cast<int>(std::lround(value / 2.0)) * 2); }
}

bool VideoBackend::load_libraries(std::string& error) {
    std::lock_guard<std::mutex> guard(choice_lock);
    if (chosen) { error.clear(); return true; }
    std::string reasons;
    for (const Version& candidate : versions) {
        std::string reason;
        if (candidate.load(reason)) { chosen = &candidate; error.clear(); return true; }
        reasons += (reasons.empty() ? "" : "; ") + std::string(candidate.name) + ": " + reason;
    }
    error = "No supported FFmpeg found (" + reasons + ")";
    return false;
}

void VideoBackend::retry_libraries() {
    std::lock_guard<std::mutex> guard(choice_lock);
    if (chosen) return;
    for (const Version& candidate : versions) candidate.reset();
}

std::string VideoBackend::library_version() {
    std::string error;
    if (!load_libraries(error)) return "";
    return chosen->version();
}

std::unique_ptr<VideoBackend> VideoBackend::create() {
    std::string error;
    return load_libraries(error) ? chosen->create() : nullptr;
}

double VideoBackend::probe_duration(const std::string& path) {
    std::string error;
    return load_libraries(error) ? chosen->probe(path) : -1.0;
}

VideoBackend::Layout VideoBackend::layout(int source_width, int source_height, double aspect, int width, int height, Style style) {
    Layout result{0, 0, source_width, source_height, 0, 0, width, height};
    // The frame always fills a 4:3 tube, whatever its pixel grid (640x240 has
    // tall pixels), so shapes are compared against the tube, not the grid.
    const double tube = 4.0 / 3.0;
    // Fit a picture of `shape` inside the frame; the remainder becomes bars.
    auto fit = [&](double shape) {
        if (shape > tube + 1e-3) { result.height = std::min(height, even(height * tube / shape)); result.y = (height - result.height) / 2; }
        else if (shape < tube - 1e-3) { result.width = std::min(width, even(width * shape / tube)); result.x = (width - result.width) / 2; }
    };
    // Trim the centre of the source to `shape`.
    auto crop = [&](double shape) {
        if (aspect > shape + 1e-3) { result.crop_width = std::min(source_width, even(source_width * shape / aspect)); result.crop_x = ((source_width - result.crop_width) / 2) & ~1; }
        else if (aspect < shape - 1e-3) { result.crop_height = std::min(source_height, even(source_height * aspect / shape)); result.crop_y = ((source_height - result.crop_height) / 2) & ~1; }
    };
    const double fourteen_nine = 14.0 / 9.0;
    switch (style) {
    case LETTERBOX: fit(aspect); break;
    case FOURTEEN_NINE:
        // The broadcast compromise: wider sources lose their sides down to 14:9
        // and keep thin bars; anything narrower is simply letterboxed.
        if (aspect > fourteen_nine) { crop(fourteen_nine); fit(fourteen_nine); }
        else fit(aspect);
        break;
    case FILL: crop(tube); break;
    case STRETCH: break;
    }
    return result;
}
}
