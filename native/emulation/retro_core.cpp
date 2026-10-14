#include "retro_core.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <algorithm>
#include <cstring>

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
    ClassDB::bind_method(D_METHOD("run_frame", "buttons"), &RetroCore::run_frame);
    ClassDB::bind_method(D_METHOD("frame"), &RetroCore::frame);
    ClassDB::bind_method(D_METHOD("info"), &RetroCore::info);
    ClassDB::bind_method(D_METHOD("last_error"), &RetroCore::last_error);
    ClassDB::bind_method(D_METHOD("push_audio", "playback"), &RetroCore::push_audio);
    ClassDB::bind_method(D_METHOD("save_state"), &RetroCore::save_state);
    ClassDB::bind_method(D_METHOD("load_state", "state"), &RetroCore::load_state);
    ClassDB::bind_method(D_METHOD("save_ram"), &RetroCore::save_ram);
    ClassDB::bind_method(D_METHOD("load_ram", "ram"), &RetroCore::load_ram);
    ClassDB::bind_method(D_METHOD("close_game"), &RetroCore::close_game);
    ClassDB::bind_method(D_METHOD("close"), &RetroCore::close);
}
bool RetroCore::load_core(const String& path) { return host.load_core(path.utf8().get_data()); }
bool RetroCore::load_game(const String& path, const String& saves) { return host.load_game(path.utf8().get_data(), saves.utf8().get_data()); }
bool RetroCore::run_frame(int buttons) { return host.step(static_cast<std::uint16_t>(buttons)); }
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
void RetroCore::close_game() { host.close_game(); }
void RetroCore::close() { host.close(); }
