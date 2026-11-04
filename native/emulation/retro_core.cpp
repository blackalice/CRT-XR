#include "retro_core.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <algorithm>
#include <cstring>
#include <chrono>
#include <filesystem>
#include <string>
#ifdef _WIN32
#include <process.h>
#define CRT_XR_PID _getpid()
#else
#include <unistd.h>
#define CRT_XR_PID getpid()
#endif

using namespace godot;
namespace {
PackedByteArray pack(const std::vector<std::uint8_t>& bytes) {
    PackedByteArray output;
    output.resize(static_cast<int64_t>(bytes.size()));
    if (!bytes.empty()) std::memcpy(output.ptrw(), bytes.data(), bytes.size());
    return output;
}
}
void RetroCore::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load_core", "path"), &RetroCore::load_core);
    ClassDB::bind_method(D_METHOD("load_game", "path", "saves"), &RetroCore::load_game);
    ClassDB::bind_method(D_METHOD("set_option", "key", "value"), &RetroCore::set_option);
    ClassDB::bind_method(D_METHOD("set_controller", "device"), &RetroCore::set_controller);
    ClassDB::bind_method(D_METHOD("set_hardware_rendering", "enabled"), &RetroCore::set_hardware_rendering);
    ClassDB::bind_method(D_METHOD("vmu_lcd", "index"), &RetroCore::vmu_lcd, DEFVAL(0));
    ClassDB::bind_method(D_METHOD("set_trigger_pressure", "left", "right"), &RetroCore::set_trigger_pressure);
    ClassDB::bind_method(D_METHOD("set_analog", "left_x", "left_y", "right_x", "right_y"), &RetroCore::set_analog);
    ClassDB::bind_method(D_METHOD("disc_info"), &RetroCore::disc_info);
    ClassDB::bind_method(D_METHOD("change_disc", "index"), &RetroCore::change_disc);
    ClassDB::bind_method(D_METHOD("run_frame", "buttons"), &RetroCore::run_frame);
    ClassDB::bind_method(D_METHOD("begin_frame", "buttons", "frames"), &RetroCore::begin_frame, DEFVAL(1));
    ClassDB::bind_method(D_METHOD("poll_frame"), &RetroCore::poll_frame);
    ClassDB::bind_method(D_METHOD("reset"), &RetroCore::reset);
    ClassDB::bind_method(D_METHOD("frame"), &RetroCore::frame);
    ClassDB::bind_method(D_METHOD("info"), &RetroCore::info);
    ClassDB::bind_method(D_METHOD("video_changed"), &RetroCore::video_changed);
    ClassDB::bind_method(D_METHOD("last_error"), &RetroCore::last_error);
    ClassDB::bind_method(D_METHOD("push_audio", "playback"), &RetroCore::push_audio);
    ClassDB::bind_method(D_METHOD("save_state"), &RetroCore::save_state);
    ClassDB::bind_method(D_METHOD("load_state", "state"), &RetroCore::load_state);
    ClassDB::bind_method(D_METHOD("save_ram"), &RetroCore::save_ram);
    ClassDB::bind_method(D_METHOD("load_ram", "ram"), &RetroCore::load_ram);
    ClassDB::bind_method(D_METHOD("close_game"), &RetroCore::close_game);
    ClassDB::bind_method(D_METHOD("close"), &RetroCore::close);
    ClassDB::bind_method(D_METHOD("load_preview", "core_path", "game_path", "directory"), &RetroCore::load_preview);
    ClassDB::bind_method(D_METHOD("run_preview", "buttons", "frames"), &RetroCore::run_preview);
    ClassDB::bind_method(D_METHOD("has_preview"), &RetroCore::has_preview);
    ClassDB::bind_method(D_METHOD("close_preview"), &RetroCore::close_preview);
    ClassDB::bind_method(D_METHOD("start_stream", "reserve_frames", "async_readback"), &RetroCore::start_stream);
    ClassDB::bind_method(D_METHOD("stop_stream"), &RetroCore::stop_stream);
    ClassDB::bind_method(D_METHOD("stream_running"), &RetroCore::stream_running);
    ClassDB::bind_method(D_METHOD("stream_input", "buttons", "left_x", "left_y", "right_x", "right_y", "left_trigger", "right_trigger"), &RetroCore::stream_input);
    ClassDB::bind_method(D_METHOD("stream_audio", "playback", "capacity"), &RetroCore::stream_audio);
    ClassDB::bind_method(D_METHOD("stream_frame"), &RetroCore::stream_frame);
    ClassDB::bind_method(D_METHOD("stream_info"), &RetroCore::stream_info);
    ClassDB::bind_method(D_METHOD("stream_set_reserve", "reserve_frames"), &RetroCore::stream_set_reserve);
    ClassDB::bind_method(D_METHOD("stream_tick", "frames"), &RetroCore::stream_tick);
    ClassDB::bind_method(D_METHOD("stream_vmu", "enabled"), &RetroCore::stream_vmu);
    ClassDB::bind_method(D_METHOD("stream_vmu_lcd"), &RetroCore::stream_vmu_lcd);
}

bool RetroCore::start_stream(int reserve_frames, bool async_readback) {
    if (streaming) return true;
    wait_frame(); // a begin_frame batch still in flight
    if (!host.loaded) return false;
    frame_pending = false;
    host.set_async_readback(async_readback);
    {
        std::lock_guard<std::mutex> lock(stream->mutex);
        Stream& s = *stream;
        s.stop = false; s.failed = false; s.error.clear();
        s.fps = host.fps > 1.0 ? host.fps : 60.0;
        s.sample_rate = host.sample_rate > 1.0 ? host.sample_rate : 48000.0;
        s.reserve_frames = std::clamp(reserve_frames, 1, 32);
        s.started = std::chrono::steady_clock::now();
        s.frames_run = 0;
        s.ticked = false; s.credit = 0;
        s.timings.clear();
        for (int i = 0; i < 4; ++i) s.analog[i].store(host.analog[i], std::memory_order_relaxed);
        for (int i = 0; i < 2; ++i) s.triggers[i].store(host.trigger_pressure[i], std::memory_order_relaxed);
    }
    if (!frame_worker) frame_worker = std::make_unique<crt_xr::CoreThread>();
    streaming = true;
    frame_worker->post([this] { stream_loop(); });
    return true;
}

void RetroCore::stream_loop() {
    using clock = std::chrono::steady_clock;
    Stream& s = *stream;
    // Asynchronous readback: the last frame's picture is collected as soon as
    // the GPU finishes it, while waiting for the next frame to be due, rather
    // than one emulated frame later.
    bool poll_read = false;
    clock::time_point previous_end{}, last_end{};
    for (;;) {
        bool run = false;
        {
            std::unique_lock<std::mutex> lock(s.mutex);
            const auto due = [&] {
                if (s.stop) return true;
                const double frame_samples = s.sample_rate / s.fps;
                const double produced = static_cast<double>(s.pcm.size() / 2);
                if (s.ticked) {
                    // Display-locked: frames granted by room updates (stream_tick).
                    // Waits only if the device is full, so audio cannot pile up.
                    if (s.playback.is_valid() && produced > frame_samples * 4) return false;
                    return s.credit >= 1;
                }
                if (s.playback.is_valid()) {
                    // The generator's live fill level: pushed straight after each
                    // frame, so no room-update granularity sits in the reserve.
                    const double queued = std::max(0.0, s.capacity - static_cast<double>(s.playback->get_frames_available()));
                    // The reserve, but never more than the device can hold.
                    double target = frame_samples * s.reserve_frames;
                    if (s.capacity > 0.0) target = std::min(target, s.capacity * 0.9);
                    if (produced > frame_samples * 2) return false; // the device is full
                    return queued + produced < target;
                }
                // No audio device: the wall clock paces the core.
                const double elapsed = std::chrono::duration<double>(clock::now() - s.started).count();
                return static_cast<double>(s.frames_run) < elapsed * s.fps + 1.0;
            };
            for (;;) {
                if (s.stop) return;
                stream_push(s); // anything left over once the device has room
                if (due()) {
                    if (s.ticked) --s.credit;
                    run = true;
                    break;
                }
                if (poll_read) break;
                s.wake.wait_for(lock, std::chrono::milliseconds(1));
            }
        }
        if (!run) {
            const int collected = host.collect_readback();
            if (collected != 0) poll_read = false;
            std::unique_lock<std::mutex> lock(s.mutex);
            if (collected == 1) {
                if (s.fresh) ++s.dropped;
                s.rgba.assign(host.rgba.begin(), host.rgba.end());
                s.width = host.width; s.height = host.height; s.fresh = true;
                s.picture_base = last_end;
            } else if (collected == 0) s.wake.wait_for(lock, std::chrono::microseconds(250));
            continue;
        }
        for (int i = 0; i < 4; ++i) host.analog[i] = s.analog[i].load(std::memory_order_relaxed);
        for (int i = 0; i < 2; ++i) host.trigger_pressure[i] = s.triggers[i].load(std::memory_order_relaxed);
        const auto start = clock::now();
        const bool ok = host.step(s.buttons.load(std::memory_order_relaxed));
        const auto end = clock::now();
        const auto wall = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
        previous_end = last_end;
        last_end = end;
        const bool deferred = host.readback_deferred();
        poll_read = deferred; // a read of this frame may now be in flight
        std::vector<std::uint8_t> vmu;
        if (ok && s.want_vmu) vmu = host.vmu_lcd(0);
        std::lock_guard<std::mutex> lock(s.mutex);
        if (!ok) { s.failed = true; s.error = host.error; return; }
        ++s.frames_run;
        s.pcm.insert(s.pcm.end(), host.pcm.begin(), host.pcm.end());
        stream_push(s);
        if (host.video_changed) {
            if (s.fresh) ++s.dropped;
            s.rgba.assign(host.rgba.begin(), host.rgba.end());
            s.width = host.width; s.height = host.height; s.fresh = true;
            // An asynchronous picture collected inside a frame is the previous frame's.
            s.picture_base = deferred ? previous_end : end;
        }
        if (!vmu.empty()) s.vmu = std::move(vmu);
        if (host.fps > 1.0) s.fps = host.fps;
        if (host.sample_rate > 1.0) s.sample_rate = host.sample_rate;
        if (s.timings.size() < 256)
            s.timings.push_back({static_cast<std::uint64_t>(wall), host.step_usec, host.readback_usec, host.pcm.size() / 2, host.video_changed,
                static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::microseconds>(start.time_since_epoch()).count())});
    }
}

// After a restore, reset or game change, the stream's unshown picture and
// unplayed audio belong to the old moment.
void RetroCore::discard_stream_output() {
    std::lock_guard<std::mutex> lock(stream->mutex);
    stream->pcm.clear();
    stream->fresh = false;
    stream->picture_base = {};
}

void RetroCore::stop_stream() {
    if (!streaming) return;
    std::lock_guard<std::mutex> lock(stream->mutex);
    stream->stop = true;
    stream->wake.notify_all();
}

bool RetroCore::stream_running() const {
    if (!streaming) return false;
    if (frame_worker && !frame_worker->ready()) return true;
    streaming = false; // the loop ended: stopped or failed
    return false;
}

void RetroCore::stream_input(int buttons, int left_x, int left_y, int right_x, int right_y, int left_trigger, int right_trigger) {
    Stream& s = *stream;
    s.buttons.store(static_cast<std::uint16_t>(buttons), std::memory_order_relaxed);
    const int values[] = {left_x, left_y, right_x, right_y};
    for (int i = 0; i < 4; ++i) s.analog[i].store(static_cast<std::int16_t>(std::clamp(values[i], -32768, 32767)), std::memory_order_relaxed);
    s.triggers[0].store(static_cast<std::int16_t>(std::clamp(left_trigger, 0, 32767)), std::memory_order_relaxed);
    s.triggers[1].store(static_cast<std::int16_t>(std::clamp(right_trigger, 0, 32767)), std::memory_order_relaxed);
}

// The generator's ring buffer has one producer (this worker) and one consumer
// (the mixer), so frames are pushed from the worker as soon as they exist.
// Called with the stream locked; keeps whatever does not fit yet.
void RetroCore::stream_push(Stream& s) {
    if (s.playback.is_null() || s.pcm.empty()) return;
    const auto count = std::min<int64_t>(s.playback->get_frames_available(), static_cast<int64_t>(s.pcm.size() / 2));
    if (count <= 0) return;
    PackedVector2Array& frames = s.push_scratch;
    frames.resize(count);
    auto* values = frames.ptrw();
    for (int64_t i = 0; i < count; ++i) values[i] = Vector2(s.pcm[i * 2] / 32768.0f, s.pcm[i * 2 + 1] / 32768.0f);
    s.playback->push_buffer(frames);
    s.pcm.erase(s.pcm.begin(), s.pcm.begin() + count * 2);
}

// Hands the worker the playback to fill (null: no device, audio is dropped).
// The caller may replace it at any time, for example after restarting audio.
int RetroCore::stream_audio(const Ref<AudioStreamGeneratorPlayback>& playback, int capacity) {
    Stream& s = *stream;
    {
        std::lock_guard<std::mutex> lock(s.mutex);
        if (playback.is_null()) {
            s.playback.unref();
            s.pcm.clear();
            return 0;
        }
        if (s.playback != playback) s.playback = playback;
        s.capacity = static_cast<double>(capacity);
        if (!streaming) stream_push(s); // left over after a stop
    }
    s.wake.notify_all();
    return 0;
}

PackedByteArray RetroCore::stream_frame() {
    {
        std::lock_guard<std::mutex> lock(stream->mutex);
        if (!stream->fresh) return PackedByteArray();
        std::swap(stream->rgba, stream_front);
        stream->fresh = false;
        if (stream->picture_base.time_since_epoch().count() != 0 && stream->ages.size() < 256)
            stream->ages.push_back(static_cast<std::uint32_t>(std::chrono::duration_cast<std::chrono::microseconds>(
                std::chrono::steady_clock::now() - stream->picture_base).count()));
    }
    return pack(stream_front);
}

Dictionary RetroCore::stream_info() {
    Dictionary result;
    Array timings;
    std::lock_guard<std::mutex> lock(stream->mutex);
    Stream& s = *stream;
    for (const auto& t : s.timings) {
        Dictionary timing;
        timing["wall_us"] = static_cast<int64_t>(t.wall);
        timing["core_us"] = static_cast<int64_t>(t.step);
        timing["readback_us"] = static_cast<int64_t>(t.readback);
        timing["audio_frames"] = static_cast<int64_t>(t.audio);
        timing["video_changed"] = t.video;
        timing["at_us"] = static_cast<int64_t>(t.at);
        timings.push_back(timing);
    }
    s.timings.clear();
    result["steps"] = timings;
    PackedInt32Array ages;
    for (const auto age : s.ages) ages.push_back(static_cast<int32_t>(age));
    s.ages.clear();
    result["picture_ages_us"] = ages;
    result["reserve_frames"] = s.reserve_frames;
    result["dropped"] = static_cast<int64_t>(s.dropped);
    result["width"] = s.width; result["height"] = s.height;
    result["fps"] = s.fps; result["sample_rate"] = s.sample_rate;
    result["failed"] = s.failed;
    result["error"] = String::utf8(s.error.c_str());
    result["frames"] = static_cast<int64_t>(s.frames_run);
    result["pending_audio"] = static_cast<int64_t>(s.pcm.size() / 2);
    return result;
}

// Grants frames from a room update: the worker starts them at once, with the
// input just handed over. Once used, the stream is paced by these grants.
void RetroCore::stream_tick(int frames) {
    {
        std::lock_guard<std::mutex> lock(stream->mutex);
        stream->ticked = true;
        stream->credit = std::min(stream->credit + std::max(frames, 0), 8);
    }
    stream->wake.notify_all();
}

void RetroCore::stream_set_reserve(int reserve_frames) {
    {
        std::lock_guard<std::mutex> lock(stream->mutex);
        stream->reserve_frames = std::clamp(reserve_frames, 1, 32);
    }
    stream->wake.notify_all();
}

void RetroCore::stream_vmu(bool enabled) {
    std::lock_guard<std::mutex> lock(stream->mutex);
    stream->want_vmu = enabled;
}

PackedByteArray RetroCore::stream_vmu_lcd() {
    std::lock_guard<std::mutex> lock(stream->mutex);
    return pack(stream->vmu);
}
// The dispatch thread only calls the native host. Godot objects, audio and
// textures stay on the caller. The host still owns its persistent GL thread.
RetroCore::~RetroCore() { wait_frame(); close_preview(); }
void RetroCore::wait_frame() const {
    if (streaming) {
        {
            std::lock_guard<std::mutex> lock(stream->mutex);
            stream->stop = true;
        }
        stream->wake.notify_all();
        streaming = false;
    }
    if (frame_worker) frame_worker->wait();
}
bool RetroCore::begin_frame(int buttons, int frames) {
    if (streaming) wait_frame();
    if (frame_pending || !host.loaded) return false;
    if (!frame_worker) frame_worker = std::make_unique<crt_xr::CoreThread>();
    frame_pending = true;
    frame_worker->post([this, buttons, frames] {
        std::vector<std::int16_t> audio;
        bool changed = false;
        frame_timings.clear();
        frame_ok = true;
        for (int i = 0; i < std::clamp(frames, 1, 4); ++i) {
            const auto start = std::chrono::steady_clock::now();
            if (!host.step(static_cast<std::uint16_t>(buttons))) { frame_ok = false; break; }
            const auto wall = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - start).count();
            frame_timings.push_back({static_cast<std::uint64_t>(wall), host.step_usec, host.readback_usec, host.pcm.size() / 2, host.video_changed});
            audio.insert(audio.end(), host.pcm.begin(), host.pcm.end());
            changed = changed || host.video_changed;
        }
        host.pcm = std::move(audio);
        host.video_changed = changed;
    });
    return true;
}
int RetroCore::poll_frame() {
    if (!frame_pending) return -2;
    if (!frame_worker->ready()) return 0;
    frame_pending = false;
    return frame_ok ? 1 : -1;
}
bool RetroCore::load_core(const String& path) { wait_frame(); frame_pending = false; return host.load_core(path.utf8().get_data()); }
bool RetroCore::load_game(const String& path, const String& saves) { wait_frame(); frame_pending = false; discard_stream_output(); return host.load_game(path.utf8().get_data(), saves.utf8().get_data()); }
void RetroCore::set_option(const String& key, const String& value) { wait_frame(); host.set_option(key.utf8().get_data(), value.utf8().get_data()); }
void RetroCore::set_controller(int device) { wait_frame(); host.port_device = static_cast<unsigned>(device); }
// Before load_core: the core then runs on its own thread with a hidden OpenGL context.
void RetroCore::set_hardware_rendering(bool enabled) { wait_frame(); host.hardware_rendering = enabled; }
void RetroCore::set_trigger_pressure(int left, int right) { wait_frame();
    host.trigger_pressure[0] = static_cast<std::int16_t>(std::clamp(left, 0, 32767));
    host.trigger_pressure[1] = static_cast<std::int16_t>(std::clamp(right, 0, 32767));
}
void RetroCore::set_analog(int left_x, int left_y, int right_x, int right_y) { wait_frame();
    const int values[] = {left_x, left_y, right_x, right_y};
    for (int i = 0; i < 4; ++i) host.analog[i] = static_cast<std::int16_t>(std::clamp(values[i], -32768, 32767));
}
Dictionary RetroCore::disc_info() const { wait_frame();
    Dictionary result;
    const unsigned count = host.disc_count();
    result["count"] = count;
    result["index"] = host.disc_index();
    PackedStringArray labels;
    for (unsigned i = 0; i < count; ++i) labels.push_back(String::utf8(host.disc_label(i).c_str()));
    result["labels"] = labels;
    return result;
}
bool RetroCore::change_disc(int index) { wait_frame(); return index >= 0 && host.change_disc(static_cast<unsigned>(index)); }
bool RetroCore::run_frame(int buttons) { wait_frame(); return host.step(static_cast<std::uint16_t>(buttons)); }
PackedByteArray RetroCore::vmu_lcd(int index) const { wait_frame(); return index >= 0 ? pack(host.vmu_lcd(static_cast<unsigned>(index))) : PackedByteArray(); }
bool RetroCore::reset() { wait_frame(); frame_pending = false; discard_stream_output(); return host.reset(); }
PackedByteArray RetroCore::frame() const { wait_frame(); return pack(host.rgba); }
Dictionary RetroCore::info() const { wait_frame();
    Dictionary result;
    Array timings;
    for (const auto& t : frame_timings) {
        Dictionary timing;
        timing["wall_us"] = static_cast<int64_t>(t.wall);
        timing["core_us"] = static_cast<int64_t>(t.step);
        timing["readback_us"] = static_cast<int64_t>(t.readback);
        timing["audio_frames"] = static_cast<int64_t>(t.audio);
        timing["video_changed"] = t.video;
        timings.push_back(timing);
    }
    result["async_steps"] = timings;
    result["loaded"] = host.loaded;
    result["name"] = String::utf8(host.name.c_str());
    result["width"] = host.width; result["height"] = host.height;
    result["fps"] = host.fps; result["sample_rate"] = host.sample_rate;
    result["step_usec"] = static_cast<int64_t>(host.step_usec);
    result["readback_usec"] = static_cast<int64_t>(host.readback_usec);
    result["video_changed"] = host.video_changed;
    result["audio_frames"] = static_cast<int64_t>(host.pcm.size() / 2);
    return result;
}
// Checked after every emulated frame; cheaper than building info()'s Dictionary.
bool RetroCore::video_changed() const { wait_frame(); return host.video_changed; }
String RetroCore::last_error() const { wait_frame(); return String::utf8(host.error.c_str()); }
int RetroCore::push_audio(const Ref<AudioStreamGeneratorPlayback>& playback) { wait_frame();
    if (playback.is_null() || host.pcm.empty()) return 0;
    const auto count = static_cast<int64_t>(host.pcm.size() / 2);
    if (playback->get_frames_available() < count) return -1;
    PackedVector2Array frames;
    frames.resize(count);
    auto* values = frames.ptrw();
    for (int64_t i = 0; i < count; ++i) values[i] = Vector2(host.pcm[i * 2] / 32768.0f, host.pcm[i * 2 + 1] / 32768.0f);
    return playback->push_buffer(frames) ? static_cast<int>(count) : -1;
}
PackedByteArray RetroCore::save_state() { wait_frame(); return pack(host.serialize()); }
bool RetroCore::load_state(const PackedByteArray& state) { wait_frame(); frame_pending = false; discard_stream_output(); return host.unserialize(state.ptr(), static_cast<std::size_t>(state.size())); }
PackedByteArray RetroCore::save_ram() const { wait_frame(); return pack(host.save_ram()); }
bool RetroCore::load_ram(const PackedByteArray& ram) { wait_frame(); return host.set_save_ram(ram.ptr(), static_cast<std::size_t>(ram.size())); }
void RetroCore::close_game() { wait_frame(); frame_pending = false; discard_stream_output(); close_preview(); host.close_game(); }
void RetroCore::close() { wait_frame(); frame_pending = false; discard_stream_output(); close_preview(); host.close(); }
bool RetroCore::load_preview(const String& core_path, const String& game_path, const String& directory) { wait_frame();
    close_preview();
    // Loading the same library path again would share the playing core's globals;
    // a renamed private copy gets its own.
    namespace fs = std::filesystem;
    std::error_code ignored;
    const fs::path source = fs::u8path(core_path.utf8().get_data());
    const fs::path folder = fs::temp_directory_path(ignored) / ("crt-xr-preview-" + std::to_string(CRT_XR_PID));
    fs::create_directories(folder, ignored);
    const fs::path copy = folder / (source.stem().string() + "_preview" + source.extension().string());
    if (!fs::copy_file(source, copy, fs::copy_options::overwrite_existing, ignored)) return false;
    preview_library = copy.u8string();
    preview_host.want_audio = false; // its frames are shown, never heard
    preview_host.port_device = host.port_device;
    if (preview_host.load_core(preview_library)) {
        preview_host.copy_options(host); // load_core clears them; the game reads them at load
        if (preview_host.load_game(game_path.utf8().get_data(), directory.utf8().get_data())) return true;
    }
    close_preview();
    return false;
}
Dictionary RetroCore::run_preview(int buttons, int frames) { wait_frame();
    Dictionary result;
    if (!host.loaded || !preview_host.loaded) return result;
    if (!host.serialize_into(preview_state) || !preview_host.unserialize(preview_state.data(), preview_state.size())) return result;
    // Not every core keeps SRAM in its save state. Genesis Plus GX reports a
    // content-dependent SRAM size, so a mismatch is skipped: the preview only
    // affects the picture, never the playing game.
    const auto ram = host.save_ram();
    if (!ram.empty()) preview_host.set_save_ram(ram.data(), ram.size());
    std::copy(std::begin(host.analog), std::end(host.analog), std::begin(preview_host.analog));
    std::copy(std::begin(host.trigger_pressure), std::end(host.trigger_pressure), std::begin(preview_host.trigger_pressure));
    for (int i = 0; i < std::max(frames, 1); ++i)
        if (!preview_host.step(static_cast<std::uint16_t>(buttons))) return result;
    if (preview_host.width == 0) return result;
    result["bytes"] = pack(preview_host.rgba);
    result["width"] = preview_host.width; result["height"] = preview_host.height;
    return result;
}
bool RetroCore::has_preview() const { return preview_host.loaded; }
void RetroCore::close_preview() {
    preview_host.close();
    if (preview_library.empty()) return;
    std::error_code ignored;
    const auto copy = std::filesystem::u8path(preview_library);
    std::filesystem::remove(copy, ignored);
    std::filesystem::remove(copy.parent_path(), ignored); // only when empty
    preview_library.clear();
}
