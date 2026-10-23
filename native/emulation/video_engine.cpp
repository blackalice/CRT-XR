#include "video_engine.h"
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/dict.h>
#include <libavutil/frame.h>
#include <libavutil/hwcontext.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
}
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cstring>
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <filesystem>
#include <windows.h>
#else
#include <dlfcn.h>
#endif

#define CRT_XR_STR_(value) #value
#define CRT_XR_STR(value) CRT_XR_STR_(value)

namespace crt_xr {
namespace {
// Every FFmpeg function used, resolved from the system libraries at runtime.
#define CRT_XR_FFMPEG_FUNCTIONS(X) \
    X(avutil, av_frame_alloc) X(avutil, av_frame_free) X(avutil, av_frame_unref) \
    X(avutil, av_frame_apply_cropping) X(avutil, av_strerror) X(avutil, av_log_set_level) X(avutil, avutil_version) \
    X(avutil, av_channel_layout_default) X(avutil, av_channel_layout_uninit) X(avutil, av_dict_get) \
    X(avutil, av_hwdevice_ctx_create) X(avutil, av_hwframe_transfer_data) X(avutil, av_buffer_ref) \
    X(avutil, av_buffer_unref) X(avutil, av_frame_copy_props) \
    X(avcodec, avcodec_get_hw_config) X(avcodec, avcodec_default_get_format) X(avcodec, avcodec_find_decoder_by_name) \
    X(avcodec, avcodec_find_decoder) X(avcodec, avcodec_alloc_context3) X(avcodec, avcodec_parameters_to_context) \
    X(avcodec, avcodec_open2) X(avcodec, avcodec_send_packet) X(avcodec, avcodec_receive_frame) \
    X(avcodec, avcodec_flush_buffers) X(avcodec, avcodec_free_context) X(avcodec, avcodec_get_name) \
    X(avcodec, av_packet_alloc) X(avcodec, av_packet_free) X(avcodec, av_packet_unref) X(avcodec, avcodec_version) \
    X(avformat, avformat_open_input) X(avformat, avformat_find_stream_info) X(avformat, av_find_best_stream) \
    X(avformat, av_read_frame) X(avformat, av_seek_frame) X(avformat, avformat_close_input) \
    X(avformat, av_guess_sample_aspect_ratio) X(avformat, av_guess_frame_rate) X(avformat, avformat_version) \
    X(swscale, sws_getCachedContext) X(swscale, sws_scale) X(swscale, sws_freeContext) \
    X(swscale, sws_setColorspaceDetails) X(swscale, sws_getCoefficients) X(swscale, swscale_version) \
    X(swresample, swr_alloc_set_opts2) X(swresample, swr_init) X(swresample, swr_convert) \
    X(swresample, swr_get_out_samples) X(swresample, swr_free) X(swresample, swresample_version)

struct Functions {
#define CRT_XR_DECLARE(library, name) decltype(&::name) name = nullptr;
    CRT_XR_FFMPEG_FUNCTIONS(CRT_XR_DECLARE)
#undef CRT_XR_DECLARE
} ff;

// Exact majors: struct layouts differ between FFmpeg majors, so a build only
// accepts the libraries matching the headers it was compiled with.
struct Library { const char* key; const char* linux_name; const char* windows_name; unsigned major; void* handle; };
Library libraries[] = {
    {"avutil", "libavutil.so." CRT_XR_STR(LIBAVUTIL_VERSION_MAJOR), "avutil-" CRT_XR_STR(LIBAVUTIL_VERSION_MAJOR) ".dll", LIBAVUTIL_VERSION_MAJOR, nullptr},
    {"avcodec", "libavcodec.so." CRT_XR_STR(LIBAVCODEC_VERSION_MAJOR), "avcodec-" CRT_XR_STR(LIBAVCODEC_VERSION_MAJOR) ".dll", LIBAVCODEC_VERSION_MAJOR, nullptr},
    {"avformat", "libavformat.so." CRT_XR_STR(LIBAVFORMAT_VERSION_MAJOR), "avformat-" CRT_XR_STR(LIBAVFORMAT_VERSION_MAJOR) ".dll", LIBAVFORMAT_VERSION_MAJOR, nullptr},
    {"swscale", "libswscale.so." CRT_XR_STR(LIBSWSCALE_VERSION_MAJOR), "swscale-" CRT_XR_STR(LIBSWSCALE_VERSION_MAJOR) ".dll", LIBSWSCALE_VERSION_MAJOR, nullptr},
    {"swresample", "libswresample.so." CRT_XR_STR(LIBSWRESAMPLE_VERSION_MAJOR), "swresample-" CRT_XR_STR(LIBSWRESAMPLE_VERSION_MAJOR) ".dll", LIBSWRESAMPLE_VERSION_MAJOR, nullptr},
};

void* open_library(const Library& library) {
    // CRT_XR_FFMPEG_DIR points at a specific copy (development and tests);
    // otherwise the platform's normal library search finds the system copy.
    const char* directory = std::getenv("CRT_XR_FFMPEG_DIR");
#ifdef _WIN32
    if (directory && *directory) {
        auto path = std::filesystem::u8path(directory) / library.windows_name;
        // Resolve the library's own dependencies from the same folder.
        if (HMODULE module = LoadLibraryExW(path.wstring().c_str(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH)) return module;
    }
    return LoadLibraryW(std::filesystem::u8path(library.windows_name).wstring().c_str());
#else
    if (directory && *directory) {
        std::string path = std::string(directory) + "/" + library.linux_name;
        if (void* handle = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL)) return handle;
    }
    return dlopen(library.linux_name, RTLD_NOW | RTLD_LOCAL);
#endif
}

void* find_symbol(const char* key, const char* name) {
    for (const Library& library : libraries) {
        if (std::strcmp(library.key, key) != 0 || !library.handle) continue;
#ifdef _WIN32
        return reinterpret_cast<void*>(GetProcAddress(static_cast<HMODULE>(library.handle), name));
#else
        return dlsym(library.handle, name);
#endif
    }
    return nullptr;
}

std::mutex load_lock;
int load_state = 0; // 0 untried, 1 loaded, -1 failed
std::string load_error;

std::string describe(int code) {
    char text[128] = {};
    ff.av_strerror(code, text, sizeof(text));
    return text;
}

std::string tag(AVDictionary* metadata, const char* key) {
    const AVDictionaryEntry* entry = ff.av_dict_get(metadata, key, nullptr, 0);
    return entry && entry->value ? entry->value : "";
}

int even(double value) { return std::max(2, static_cast<int>(std::lround(value / 2.0)) * 2); }

AVPixelFormat pick_format(AVCodecContext* context, const AVPixelFormat* formats) {
    return static_cast<AVPixelFormat>(VideoEngine::choose_format(context, reinterpret_cast<const int*>(formats)));
}
}

bool VideoEngine::load_libraries(std::string& error) {
    std::lock_guard<std::mutex> guard(load_lock);
    if (load_state == 0) {
        load_state = -1;
        for (Library& library : libraries) {
            library.handle = open_library(library);
            if (!library.handle) { load_error = std::string("FFmpeg library not found: ") + library.linux_name; break; }
        }
        if (load_error.empty()) {
#define CRT_XR_RESOLVE(library, name) \
            ff.name = reinterpret_cast<decltype(ff.name)>(find_symbol(#library, #name)); \
            if (!ff.name && load_error.empty()) load_error = "FFmpeg function missing: " #name;
            CRT_XR_FFMPEG_FUNCTIONS(CRT_XR_RESOLVE)
#undef CRT_XR_RESOLVE
        }
        if (load_error.empty()) {
            const unsigned found[] = {ff.avutil_version() >> 16, ff.avcodec_version() >> 16, ff.avformat_version() >> 16,
                ff.swscale_version() >> 16, ff.swresample_version() >> 16};
            for (int i = 0; i < 5 && load_error.empty(); ++i)
                if (found[i] != libraries[i].major)
                    load_error = std::string("FFmpeg ") + libraries[i].key + " " + std::to_string(found[i]) + " found; this build needs " + std::to_string(libraries[i].major);
        }
        if (load_error.empty()) {
            ff.av_log_set_level(AV_LOG_ERROR);
            load_state = 1;
        }
    }
    error = load_error;
    return load_state == 1;
}

double VideoEngine::probe_duration(const std::string& path) {
    std::string why;
    if (!load_libraries(why)) return -1.0;
    AVFormatContext* input = nullptr;
    if (ff.avformat_open_input(&input, path.c_str(), nullptr, nullptr) < 0) return -1.0;
    // MP4 and MKV headers carry the duration; only unusual files need a stream scan.
    if (input->duration == AV_NOPTS_VALUE) ff.avformat_find_stream_info(input, nullptr);
    const double seconds = input->duration != AV_NOPTS_VALUE ? input->duration / static_cast<double>(AV_TIME_BASE) : -1.0;
    ff.avformat_close_input(&input);
    return seconds;
}

VideoEngine::~VideoEngine() { close(); }

void VideoEngine::fail(const std::string& text) {
    std::lock_guard<std::mutex> guard(lock);
    message = text;
}

std::string VideoEngine::error() const {
    std::lock_guard<std::mutex> guard(lock);
    return message;
}

bool VideoEngine::open(const std::string& path, int lines, Style style, bool hardware) {
    close();
    std::string why;
    if (!load_libraries(why)) { fail(why); return false; }
    AVFormatContext* input = nullptr;
    int result = ff.avformat_open_input(&input, path.c_str(), nullptr, nullptr);
    if (result < 0) { fail("Could not open the file: " + describe(result)); return false; }
    format = input;
    result = ff.avformat_find_stream_info(input, nullptr);
    if (result < 0) { fail("Could not read the file's streams: " + describe(result)); close(); return false; }
    const AVCodec* decoder = nullptr;
    stream = ff.av_find_best_stream(input, AVMEDIA_TYPE_VIDEO, -1, -1, &decoder, 0);
    if (stream < 0 || !decoder) { fail("The file has no playable video stream"); close(); return false; }
    AVStream* video = input->streams[stream];
    video_decoder = decoder;
    if (!open_video(hardware)) { close(); return false; }
    auto* context = static_cast<AVCodecContext*>(codec);
    time_base = av_q2d(video->time_base);
    start_time = input->start_time != AV_NOPTS_VALUE ? input->start_time / static_cast<double>(AV_TIME_BASE) : 0.0;
    AVRational sample = ff.av_guess_sample_aspect_ratio(input, video, nullptr);
    const double sample_aspect = sample.num > 0 && sample.den > 0 ? av_q2d(sample) : 1.0;
    AVRational rate = ff.av_guess_frame_rate(input, video, nullptr);
    details = Info{};
    details.source_width = context->width;
    details.source_height = context->height;
    details.display_aspect = context->height > 0 ? context->width * sample_aspect / context->height : 4.0 / 3.0;
    details.fps = rate.num > 0 && rate.den > 0 ? av_q2d(rate) : 30.0;
    details.duration = input->duration != AV_NOPTS_VALUE ? input->duration / static_cast<double>(AV_TIME_BASE) : 0.0;
    details.codec = ff.avcodec_get_name(context->codec_id);
    details.hardware_requested = hardware;
    // About 240 lines is one broadcast field, the line structure a CRT shows and
    // the scale the scanline and mask effects resolve at. Width stays at least
    // 640 so horizontal detail survives; the 4:3 shape comes from the tube.
    details.height = even(std::clamp(lines, 120, 576));
    details.width = std::max(640, even(details.height * 4.0 / 3.0));
    for (unsigned index = 0; index < input->nb_streams; ++index) {
        AVStream* candidate = input->streams[index];
        if (candidate->codecpar->codec_type != AVMEDIA_TYPE_AUDIO) continue;
        AudioTrack track;
        track.stream = static_cast<int>(index);
        track.channels = candidate->codecpar->ch_layout.nb_channels;
        track.codec = ff.avcodec_get_name(candidate->codecpar->codec_id);
        track.language = tag(candidate->metadata, "language");
        track.title = tag(candidate->metadata, "title");
        details.audio_tracks.push_back(track);
    }
    // FFmpeg's choice honours the file's default flag and the video it belongs to.
    const int best = ff.av_find_best_stream(input, AVMEDIA_TYPE_AUDIO, -1, stream, nullptr, 0);
    for (int track = 0; track < static_cast<int>(details.audio_tracks.size()); ++track)
        if (details.audio_tracks[track].stream == best) open_audio(track);
    requested_style = style;
    current.rgba.assign(static_cast<std::size_t>(details.width) * details.height * 4, 0);
    for (std::size_t i = 3; i < current.rgba.size(); i += 4) current.rgba[i] = 255;
    current.time = -1.0;
    end_of_file = false;
    seek_pending = false;
    track_pending = false;
    seek_floor = -1.0;
    software_pending = false;
    last_frame_time = 0.0;
    dropped_frames = 0;
    samples.clear();
    samples_read = 0;
    samples_time = -1.0;
    message.clear();
    running = true;
    worker = std::thread(&VideoEngine::run, this);
    return true;
}

int VideoEngine::choose_format(void* data, const int* formats) {
    // FFmpeg offers the GPU format first when the stream's profile is supported
    // there; otherwise its own choice is the best software format.
    auto* context = static_cast<AVCodecContext*>(data);
    auto* engine = static_cast<VideoEngine*>(context->opaque);
    for (const int* format = formats; *format != AV_PIX_FMT_NONE; ++format)
        if (*format == engine->hardware_format) return *format;
    engine->hardware_format = -1;
    return ff.avcodec_default_get_format(context, reinterpret_cast<const AVPixelFormat*>(formats));
}

bool VideoEngine::setup_hardware(void* data, const void* codec_definition) {
    auto* context = static_cast<AVCodecContext*>(data);
    const auto* definition = static_cast<const AVCodec*>(codec_definition);
#ifdef _WIN32
    const AVHWDeviceType type = AV_HWDEVICE_TYPE_D3D11VA;
    const char* device = nullptr;
    hardware_name = "D3D11VA";
#else
    const AVHWDeviceType type = AV_HWDEVICE_TYPE_VAAPI;
    const char* device = "/dev/dri/renderD128";
    hardware_name = "VA-API";
#endif
    // A different device node, or "unavailable" to test the software fallback.
    if (const char* override_device = std::getenv("CRT_XR_VIDEO_HW_DEVICE")) {
        if (std::strcmp(override_device, "unavailable") == 0) return false;
        if (*override_device) device = override_device;
    }
    hardware_format = -1;
    for (int index = 0;; ++index) {
        const AVCodecHWConfig* config = ff.avcodec_get_hw_config(definition, index);
        if (!config) return false;
        if ((config->methods & AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX) && config->device_type == type) { hardware_format = config->pix_fmt; break; }
    }
    if (!hardware_device) {
        AVBufferRef* created = nullptr;
        if (ff.av_hwdevice_ctx_create(&created, type, device, nullptr, 0) < 0) { hardware_format = -1; return false; }
        hardware_device = created;
    }
    context->hw_device_ctx = ff.av_buffer_ref(static_cast<AVBufferRef*>(hardware_device));
    context->opaque = this;
    context->get_format = pick_format;
    return true;
}

bool VideoEngine::open_video(bool hardware) {
    auto* input = static_cast<AVFormatContext*>(format);
    const auto* definition = static_cast<const AVCodec*>(video_decoder);
    // FFmpeg's preferred AV1 decoder (dav1d) is software only; its own "av1"
    // decoder is the one with GPU support. It cannot decode without a GPU, so
    // it is used only when the GPU path is set up, and dav1d stays the fallback.
    if (hardware && definition->id == AV_CODEC_ID_AV1 && std::strcmp(definition->name, "av1") != 0)
        if (const AVCodec* native = ff.avcodec_find_decoder_by_name("av1")) definition = native;
    if (codec) { auto* old = static_cast<AVCodecContext*>(codec); ff.avcodec_free_context(&old); codec = nullptr; }
    AVCodecContext* context = ff.avcodec_alloc_context3(definition);
    ff.avcodec_parameters_to_context(context, input->streams[stream]->codecpar);
    const bool gpu = hardware && setup_hardware(context, definition);
    if (!gpu && definition != video_decoder) {
        ff.avcodec_free_context(&context);
        definition = static_cast<const AVCodec*>(video_decoder);
        context = ff.avcodec_alloc_context3(definition);
        ff.avcodec_parameters_to_context(context, input->streams[stream]->codecpar);
    }
    if (gpu) {
        // The GPU does the work; one thread just feeds it.
        context->thread_count = 1;
    } else {
        hardware_format = -1;
        // A few threads keep up with standard definition output and leave the
        // CPU for rendering and tracking.
        context->thread_count = 3;
        context->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;
    }
    const int result = ff.avcodec_open2(context, definition, nullptr);
    if (result < 0) {
        ff.avcodec_free_context(&context);
        if (gpu) return open_video(false);
        fail("Could not start the video decoder: " + describe(result));
        return false;
    }
    codec = context;
    decoded_on_gpu = false;
    gpu_open = gpu;
    return true;
}

void VideoEngine::request_software() {
    // Runs on the worker: reopen in software where the picture had got to.
    std::lock_guard<std::mutex> guard(lock);
    if (!gpu_open) return;
    software_pending = true;
    seek_target = last_frame_time;
}

std::string VideoEngine::decoding() const {
    return decoded_on_gpu ? hardware_name : "software";
}

bool VideoEngine::open_audio(int track) {
    close_audio();
    auto* input = static_cast<AVFormatContext*>(format);
    if (track < 0 || track >= static_cast<int>(details.audio_tracks.size())) return false;
    AVStream* sound = input->streams[details.audio_tracks[track].stream];
    const AVCodec* decoder = ff.avcodec_find_decoder(sound->codecpar->codec_id);
    AVCodecContext* context = decoder ? ff.avcodec_alloc_context3(decoder) : nullptr;
    if (!context || ff.avcodec_parameters_to_context(context, sound->codecpar) < 0 || ff.avcodec_open2(context, decoder, nullptr) < 0) {
        if (context) ff.avcodec_free_context(&context);
        // The picture still plays; the track is reported as silent.
        fail("Audio track " + std::to_string(track + 1) + " (" + details.audio_tracks[track].codec + ") cannot be decoded");
        return false;
    }
    audio_codec = context;
    audio_stream = sound->index;
    audio_time_base = av_q2d(sound->time_base);
    std::lock_guard<std::mutex> guard(lock);
    details.audio_track = track;
    return true;
}

void VideoEngine::close_audio() {
    if (resampler) { auto* context = static_cast<SwrContext*>(resampler); ff.swr_free(&context); resampler = nullptr; }
    if (audio_codec) { auto* context = static_cast<AVCodecContext*>(audio_codec); ff.avcodec_free_context(&context); audio_codec = nullptr; }
    audio_stream = -1;
    resampler_rate = 0;
    std::lock_guard<std::mutex> guard(lock);
    details.audio_track = -1;
}

void VideoEngine::close() {
    if (worker.joinable()) {
        { std::lock_guard<std::mutex> guard(lock); running = false; }
        changed.notify_all();
        worker.join();
    }
    running = false;
    if (format) close_audio();
    if (transfer) { auto* frame = static_cast<AVFrame*>(transfer); ff.av_frame_free(&frame); transfer = nullptr; }
    if (scaler) { ff.sws_freeContext(static_cast<SwsContext*>(scaler)); scaler = nullptr; }
    if (codec) { auto* context = static_cast<AVCodecContext*>(codec); ff.avcodec_free_context(&context); codec = nullptr; }
    if (format) { auto* input = static_cast<AVFormatContext*>(format); ff.avformat_close_input(&input); format = nullptr; }
    if (hardware_device) { auto* device = static_cast<AVBufferRef*>(hardware_device); ff.av_buffer_unref(&device); hardware_device = nullptr; }
    hardware_format = -1;
    decoded_on_gpu = false;
    gpu_open = false;
    std::lock_guard<std::mutex> guard(lock);
    ready.clear();
    spare.clear();
    samples.clear();
    samples_read = 0;
    samples_time = -1.0;
    stream = -1;
}

VideoEngine::Layout VideoEngine::layout(int source_width, int source_height, double aspect, int width, int height, Style style) {
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

bool VideoEngine::convert(void* decoded, Frame& out) {
    auto* frame = static_cast<AVFrame*>(decoded);
    if (hardware_format >= 0 && frame->format == hardware_format) {
        if (!transfer) transfer = ff.av_frame_alloc();
        auto* copy = static_cast<AVFrame*>(transfer);
        ff.av_frame_unref(copy);
        if (ff.av_hwframe_transfer_data(copy, frame, 0) < 0) { request_software(); return false; }
        ff.av_frame_copy_props(copy, frame);
        frame = copy;
        decoded_on_gpu = true;
    } else decoded_on_gpu = false;
    const int width = details.width, height = details.height;
    const std::size_t size = static_cast<std::size_t>(width) * height * 4;
    if (out.rgba.size() != size) out.rgba.assign(size, 0);
    // Standard definition sources without colour tags are BT.601, HD ones BT.709.
    int space = SWS_CS_ITU601;
    if (frame->colorspace == AVCOL_SPC_BT709 || (frame->colorspace == AVCOL_SPC_UNSPECIFIED && frame->height > 576)) space = SWS_CS_ITU709;
    else if (frame->colorspace == AVCOL_SPC_BT2020_NCL || frame->colorspace == AVCOL_SPC_BT2020_CL) space = SWS_CS_BT2020;
    const int full_range = frame->color_range == AVCOL_RANGE_JPEG ? 1 : 0;
    Layout place = layout(frame->width, frame->height, details.display_aspect, width, height, requested_style.load());
    frame->crop_left = static_cast<std::size_t>(place.crop_x);
    frame->crop_top = static_cast<std::size_t>(place.crop_y);
    frame->crop_right = static_cast<std::size_t>(frame->width - place.crop_x - place.crop_width);
    frame->crop_bottom = static_cast<std::size_t>(frame->height - place.crop_y - place.crop_height);
    if (ff.av_frame_apply_cropping(frame, AV_FRAME_CROP_UNALIGNED) < 0) return false;
    auto* context = ff.sws_getCachedContext(static_cast<SwsContext*>(scaler), frame->width, frame->height,
        static_cast<AVPixelFormat>(frame->format), place.width, place.height, AV_PIX_FMT_RGBA, SWS_BICUBIC, nullptr, nullptr, nullptr);
    if (!context) return false;
    scaler = context;
    ff.sws_setColorspaceDetails(context, ff.sws_getCoefficients(space), full_range,
        ff.sws_getCoefficients(SWS_CS_DEFAULT), 1, 0, 1 << 16, 1 << 16);
    // Bars are black in the signal itself, so the composite pass treats their
    // edges like a real letterboxed broadcast.
    std::uint8_t* pixels = out.rgba.data();
    auto black = [&](int x, int y, int span) {
        std::uint8_t* row = pixels + (static_cast<std::size_t>(y) * width + x) * 4;
        for (int i = 0; i < span; ++i, row += 4) { row[0] = row[1] = row[2] = 0; row[3] = 255; }
    };
    for (int y = 0; y < height; ++y) {
        if (y < place.y || y >= place.y + place.height) { black(0, y, width); continue; }
        black(0, y, place.x);
        black(place.x + place.width, y, width - place.x - place.width);
    }
    std::uint8_t* target[4] = {pixels + (static_cast<std::size_t>(place.y) * width + place.x) * 4, nullptr, nullptr, nullptr};
    const int stride[4] = {width * 4, 0, 0, 0};
    ff.sws_scale(context, frame->data, frame->linesize, 0, frame->height, target, stride);
    return true;
}

void VideoEngine::resample(void* decoded) {
    auto* frame = static_cast<AVFrame*>(decoded);
    const int channels = frame->ch_layout.nb_channels;
    if (channels <= 0 || frame->nb_samples <= 0) return;
    if (!resampler || frame->sample_rate != resampler_rate || frame->format != resampler_format || channels != resampler_channels) {
        auto* context = static_cast<SwrContext*>(resampler);
        ff.swr_free(&context);
        resampler = nullptr;
        AVChannelLayout stereo, source;
        ff.av_channel_layout_default(&stereo, 2);
        // Streams that only give a channel count get that count's usual layout,
        // which is what the downmix to stereo needs.
        ff.av_channel_layout_default(&source, channels);
        const AVChannelLayout* input = frame->ch_layout.order == AV_CHANNEL_ORDER_UNSPEC ? &source : &frame->ch_layout;
        const bool ready_to_use = ff.swr_alloc_set_opts2(&context, &stereo, AV_SAMPLE_FMT_FLT, SAMPLE_RATE, input,
            static_cast<AVSampleFormat>(frame->format), frame->sample_rate, 0, nullptr) >= 0 && ff.swr_init(context) >= 0;
        ff.av_channel_layout_uninit(&stereo);
        ff.av_channel_layout_uninit(&source);
        if (!ready_to_use) { ff.swr_free(&context); return; }
        resampler = context;
        resampler_rate = frame->sample_rate;
        resampler_format = frame->format;
        resampler_channels = channels;
    }
    auto* context = static_cast<SwrContext*>(resampler);
    const int capacity = ff.swr_get_out_samples(context, frame->nb_samples);
    if (capacity <= 0) return;
    std::vector<float> converted(static_cast<std::size_t>(capacity) * 2);
    auto* output = reinterpret_cast<std::uint8_t*>(converted.data());
    const int count = ff.swr_convert(context, &output, capacity, const_cast<const std::uint8_t**>(frame->extended_data), frame->nb_samples);
    if (count <= 0) return;
    const std::int64_t stamp = frame->best_effort_timestamp;
    double time = stamp == AV_NOPTS_VALUE ? -1.0 : stamp * audio_time_base - start_time;
    std::lock_guard<std::mutex> guard(lock);
    if (seek_pending || track_pending) return;
    // After a seek, drop the part of the first frames that comes before the target.
    int skip = 0;
    if (time >= 0.0 && time < seek_floor) skip = std::min(count, static_cast<int>(std::lround((seek_floor - time) * SAMPLE_RATE)));
    if (skip >= count) return;
    if (samples_read == samples.size()) {
        samples.clear();
        samples_read = 0;
        if (time >= 0.0) samples_time = time + static_cast<double>(skip) / SAMPLE_RATE;
        else if (samples_time < 0.0) samples_time = std::max(0.0, seek_floor);
    } else if (samples_read > (1u << 16) && samples_read * 2 > samples.size()) {
        samples.erase(samples.begin(), samples.begin() + static_cast<std::ptrdiff_t>(samples_read));
        samples_read = 0;
    }
    samples.insert(samples.end(), converted.begin() + skip * 2, converted.begin() + count * 2);
}

void VideoEngine::restart(double target) {
    // Runs on the worker: both decoders forget the old position and the
    // resampler drops its delay line, so nothing from before the jump plays.
    auto* input = static_cast<AVFormatContext*>(format);
    const auto timestamp = static_cast<std::int64_t>((target + start_time) * AV_TIME_BASE);
    ff.av_seek_frame(input, -1, timestamp, AVSEEK_FLAG_BACKWARD);
    ff.avcodec_flush_buffers(static_cast<AVCodecContext*>(codec));
    if (audio_codec) ff.avcodec_flush_buffers(static_cast<AVCodecContext*>(audio_codec));
    if (resampler) { auto* context = static_cast<SwrContext*>(resampler); ff.swr_free(&context); resampler = nullptr; }
    resampler_rate = 0;
}

void VideoEngine::run() {
    auto* input = static_cast<AVFormatContext*>(format);
    auto* context = static_cast<AVCodecContext*>(codec);
    AVPacket* packet = ff.av_packet_alloc();
    AVFrame* decoded = ff.av_frame_alloc();
    bool draining = false;
    const double half_frame = 0.5 / std::max(1.0, details.fps);
    while (true) {
        {
            std::unique_lock<std::mutex> guard(lock);
            changed.wait(guard, [&] {
                if (!running || seek_pending || track_pending || software_pending) return true;
                if (end_of_file || ready.size() >= VIDEO_LIMIT) return false;
                const bool audio_low = audio_codec && static_cast<int>((samples.size() - samples_read) / 2) < AUDIO_LOW;
                return ready.size() < AHEAD || audio_low;
            });
            if (!running) break;
            if (software_pending) {
                software_pending = false;
                const double target = seek_target;
                for (Frame& frame : ready) spare.push_back(std::move(frame));
                ready.clear();
                // Sound restarts from the same point, so none of it plays twice.
                samples.clear();
                samples_read = 0;
                samples_time = -1.0;
                end_of_file = false;
                draining = false;
                seek_floor = target;
                guard.unlock();
                open_video(false);
                context = static_cast<AVCodecContext*>(codec);
                restart(target);
                continue;
            }
            if (seek_pending || track_pending) {
                const bool switch_track = track_pending;
                const int track = track_target;
                seek_pending = false;
                track_pending = false;
                const double target = seek_target;
                for (Frame& frame : ready) spare.push_back(std::move(frame));
                ready.clear();
                samples.clear();
                samples_read = 0;
                samples_time = -1.0;
                end_of_file = false;
                draining = false;
                seek_floor = target;
                guard.unlock();
                if (switch_track) open_audio(track);
                restart(target);
                continue;
            }
        }
        auto* audio = static_cast<AVCodecContext*>(audio_codec);
        if (!draining) {
            if (ff.av_read_frame(input, packet) < 0) {
                draining = true;
                ff.avcodec_send_packet(context, nullptr);
                if (audio) ff.avcodec_send_packet(audio, nullptr);
            } else {
                if (packet->stream_index == stream) ff.avcodec_send_packet(context, packet);
                else if (audio && packet->stream_index == audio_stream) ff.avcodec_send_packet(audio, packet);
                ff.av_packet_unref(packet);
            }
        }
        // Audio first: when draining, all of it is out before video reports the end.
        while (audio && ff.avcodec_receive_frame(audio, decoded) >= 0) {
            resample(decoded);
            ff.av_frame_unref(decoded);
        }
        while (true) {
            const int result = ff.avcodec_receive_frame(context, decoded);
            if (result == AVERROR(EAGAIN)) break;
            if (result == AVERROR_EOF) {
                { std::lock_guard<std::mutex> guard(lock); end_of_file = true; }
                changed.notify_all();
                break;
            }
            if (result < 0) {
                // A GPU that cannot decode this stream hands over to software;
                // otherwise it is a damaged frame and reading carries on.
                if (gpu_open) request_software();
                break;
            }
            const std::int64_t stamp = decoded->best_effort_timestamp;
            const double time = (stamp == AV_NOPTS_VALUE ? 0.0 : stamp * time_base) - start_time;
            Frame next;
            bool wanted;
            {
                std::lock_guard<std::mutex> guard(lock);
                // After a seek, frames before the target are decoded but not shown.
                wanted = !seek_pending && !track_pending && time >= seek_floor - half_frame;
                if (wanted && !spare.empty()) { next = std::move(spare.front()); spare.pop_front(); }
            }
            if (wanted && convert(decoded, next)) {
                next.time = time;
                last_frame_time = time;
                std::lock_guard<std::mutex> guard(lock);
                (seek_pending || track_pending ? spare : ready).push_back(std::move(next));
            }
            ff.av_frame_unref(decoded);
            changed.notify_all();
        }
    }
    ff.av_frame_free(&decoded);
    ff.av_packet_free(&packet);
}

bool VideoEngine::update(double clock) {
    bool shown = false;
    {
        std::lock_guard<std::mutex> guard(lock);
        while (!ready.empty() && ready.front().time <= clock) {
            if (shown) ++dropped_frames;
            spare.push_back(std::move(current));
            current = std::move(ready.front());
            ready.pop_front();
            shown = true;
        }
    }
    if (shown) changed.notify_all();
    return shown;
}

bool VideoEngine::next(int timeout_ms) {
    {
        std::unique_lock<std::mutex> guard(lock);
        if (!changed.wait_for(guard, std::chrono::milliseconds(timeout_ms), [&] { return !ready.empty() || end_of_file || !running; })) return false;
        if (ready.empty()) return false;
        spare.push_back(std::move(current));
        current = std::move(ready.front());
        ready.pop_front();
    }
    changed.notify_all();
    return true;
}

int VideoEngine::read_audio(float* out, int frames) {
    int count;
    {
        std::lock_guard<std::mutex> guard(lock);
        count = std::min(frames, static_cast<int>((samples.size() - samples_read) / 2));
        if (count <= 0) return 0;
        std::memcpy(out, samples.data() + samples_read, static_cast<std::size_t>(count) * 2 * sizeof(float));
        samples_read += static_cast<std::size_t>(count) * 2;
        if (samples_time >= 0.0) samples_time += static_cast<double>(count) / SAMPLE_RATE;
    }
    changed.notify_all();
    return count;
}

int VideoEngine::audio_buffered() const {
    std::lock_guard<std::mutex> guard(lock);
    return static_cast<int>((samples.size() - samples_read) / 2);
}

double VideoEngine::audio_time() const {
    std::lock_guard<std::mutex> guard(lock);
    return samples_time;
}

bool VideoEngine::has_audio() const {
    std::lock_guard<std::mutex> guard(lock);
    return details.audio_track >= 0;
}

// Queued frames, audio and the end-of-file state belong to the old position;
// drop them at once so callers never see them while the worker catches up.
void VideoEngine::seek(double seconds) {
    {
        std::lock_guard<std::mutex> guard(lock);
        seek_pending = true;
        seek_target = std::max(0.0, details.duration > 0.0 ? std::min(seconds, details.duration) : seconds);
        for (Frame& frame : ready) spare.push_back(std::move(frame));
        ready.clear();
        samples.clear();
        samples_read = 0;
        samples_time = -1.0;
        end_of_file = false;
    }
    changed.notify_all();
}

void VideoEngine::set_audio_track(int index, double seconds) {
    if (index < 0 || index >= static_cast<int>(details.audio_tracks.size())) return;
    {
        std::lock_guard<std::mutex> guard(lock);
        track_pending = true;
        track_target = index;
    }
    seek(seconds);
}

void VideoEngine::set_style(Style value) {
    // Applies from the next decoded frame; frames already queued keep their style.
    requested_style = value;
}

bool VideoEngine::finished() const {
    std::lock_guard<std::mutex> guard(lock);
    return end_of_file && ready.empty() && samples_read == samples.size();
}
}
