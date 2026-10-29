#include "retro_core.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <algorithm>
#include <cstring>
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
    ClassDB::bind_method(D_METHOD("set_analog", "left_x", "left_y", "right_x", "right_y"), &RetroCore::set_analog);
    ClassDB::bind_method(D_METHOD("disc_info"), &RetroCore::disc_info);
    ClassDB::bind_method(D_METHOD("change_disc", "index"), &RetroCore::change_disc);
    ClassDB::bind_method(D_METHOD("run_frame", "buttons"), &RetroCore::run_frame);
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
}
bool RetroCore::load_core(const String& path) { return host.load_core(path.utf8().get_data()); }
bool RetroCore::load_game(const String& path, const String& saves) { return host.load_game(path.utf8().get_data(), saves.utf8().get_data()); }
void RetroCore::set_option(const String& key, const String& value) { host.set_option(key.utf8().get_data(), value.utf8().get_data()); }
void RetroCore::set_controller(int device) { host.port_device = static_cast<unsigned>(device); }
void RetroCore::set_analog(int left_x, int left_y, int right_x, int right_y) {
    const int values[] = {left_x, left_y, right_x, right_y};
    for (int i = 0; i < 4; ++i) host.analog[i] = static_cast<std::int16_t>(std::clamp(values[i], -32768, 32767));
}
Dictionary RetroCore::disc_info() const {
    Dictionary result;
    const unsigned count = host.disc_count();
    result["count"] = count;
    result["index"] = host.disc_index();
    PackedStringArray labels;
    for (unsigned i = 0; i < count; ++i) labels.push_back(String::utf8(host.disc_label(i).c_str()));
    result["labels"] = labels;
    return result;
}
bool RetroCore::change_disc(int index) { return index >= 0 && host.change_disc(static_cast<unsigned>(index)); }
bool RetroCore::run_frame(int buttons) { return host.step(static_cast<std::uint16_t>(buttons)); }
bool RetroCore::reset() { return host.reset(); }
PackedByteArray RetroCore::frame() const { return pack(host.rgba); }
Dictionary RetroCore::info() const {
    Dictionary result;
    result["loaded"] = host.loaded;
    result["name"] = String::utf8(host.name.c_str());
    result["width"] = host.width; result["height"] = host.height;
    result["fps"] = host.fps; result["sample_rate"] = host.sample_rate;
    result["video_changed"] = host.video_changed;
    result["audio_frames"] = static_cast<int64_t>(host.pcm.size() / 2);
    return result;
}
// Checked after every emulated frame; cheaper than building info()'s Dictionary.
bool RetroCore::video_changed() const { return host.video_changed; }
String RetroCore::last_error() const { return String::utf8(host.error.c_str()); }
int RetroCore::push_audio(const Ref<AudioStreamGeneratorPlayback>& playback) {
    if (playback.is_null() || host.pcm.empty()) return 0;
    const auto count = static_cast<int64_t>(host.pcm.size() / 2);
    if (playback->get_frames_available() < count) return -1;
    PackedVector2Array frames;
    frames.resize(count);
    auto* values = frames.ptrw();
    for (int64_t i = 0; i < count; ++i) values[i] = Vector2(host.pcm[i * 2] / 32768.0f, host.pcm[i * 2 + 1] / 32768.0f);
    return playback->push_buffer(frames) ? static_cast<int>(count) : -1;
}
PackedByteArray RetroCore::save_state() { return pack(host.serialize()); }
bool RetroCore::load_state(const PackedByteArray& state) { return host.unserialize(state.ptr(), static_cast<std::size_t>(state.size())); }
PackedByteArray RetroCore::save_ram() const { return pack(host.save_ram()); }
bool RetroCore::load_ram(const PackedByteArray& ram) { return host.set_save_ram(ram.ptr(), static_cast<std::size_t>(ram.size())); }
void RetroCore::close_game() { close_preview(); host.close_game(); }
void RetroCore::close() { close_preview(); host.close(); }
bool RetroCore::load_preview(const String& core_path, const String& game_path, const String& directory) {
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
Dictionary RetroCore::run_preview(int buttons, int frames) {
    Dictionary result;
    if (!host.loaded || !preview_host.loaded) return result;
    if (!host.serialize_into(preview_state) || !preview_host.unserialize(preview_state.data(), preview_state.size())) return result;
    // Not every core keeps SRAM in its save state. Genesis Plus GX reports a
    // content-dependent SRAM size, so a mismatch is skipped: the preview only
    // affects the picture, never the playing game.
    const auto ram = host.save_ram();
    if (!ram.empty()) preview_host.set_save_ram(ram.data(), ram.size());
    std::copy(std::begin(host.analog), std::end(host.analog), std::begin(preview_host.analog));
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
