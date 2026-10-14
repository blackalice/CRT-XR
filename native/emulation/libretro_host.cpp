#include "libretro_host.h"
#include <algorithm>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <cmath>
#include <filesystem>
#include <fstream>
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#else
#include <dlfcn.h>
#endif

namespace retrocrt {
LibretroHost* LibretroHost::active = nullptr;
LibretroHost::~LibretroHost() { close(); }
void LibretroHost::close_game() {
    if (loaded) fn_unload_game();
    loaded = false;
    rom.clear(); rgba.clear(); pcm.clear();
    width = height = 0;
    video_changed = false;
}
void LibretroHost::close() {
    close_game();
    if (initialized) fn_deinit();
    initialized = false;
    if (active == this) active = nullptr;
    if (library) {
#ifdef _WIN32
        FreeLibrary(static_cast<HMODULE>(library));
#else
        dlclose(library);
#endif
    }
    library = nullptr;
    options.clear();
}
bool LibretroHost::load_core(const std::string& path) {
    if (active && active != this) { error = "Only one Libretro core may be active"; return false; }
    close();
    error.clear();
#ifdef _WIN32
    library = LoadLibraryW(std::filesystem::u8path(path).wstring().c_str());
    auto symbol = [this](const char* name) { return reinterpret_cast<void*>(GetProcAddress(static_cast<HMODULE>(library), name)); };
#else
    library = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
    auto symbol = [this](const char* name) { return dlsym(library, name); };
#endif
    if (!library) { error = "Cannot load native core or one of its dependencies: " + path; return false; }
#define BIND(method) fn_##method = reinterpret_cast<decltype(fn_##method)>(symbol("retro_" #method)); if (!fn_##method) { error = "Core missing retro_" #method; close(); return false; }
    BIND(api_version); BIND(init); BIND(deinit); BIND(set_environment); BIND(set_video_refresh);
    BIND(set_audio_sample); BIND(set_audio_sample_batch); BIND(set_input_poll); BIND(set_input_state);
    BIND(get_system_info); BIND(get_system_av_info); BIND(set_controller_port_device);
    BIND(load_game); BIND(unload_game); BIND(run); BIND(serialize_size); BIND(serialize); BIND(unserialize);
    BIND(get_memory_data); BIND(get_memory_size);
#undef BIND
    if (fn_api_version() != RETRO_API_VERSION) { error = "Unsupported Libretro API version"; close(); return false; }
    active = this;
    pixel_format = RETRO_PIXEL_FORMAT_0RGB1555;
    fn_set_environment(environment);
    fn_set_video_refresh(video);
    fn_set_audio_sample(audio);
    fn_set_audio_sample_batch(audio_batch);
    fn_set_input_poll(input_poll);
    fn_set_input_state(input);
    retro_system_info info{};
    fn_get_system_info(&info);
    name = info.library_name ? info.library_name : "Libretro";
    if (info.library_version) name += std::string(" ") + info.library_version;
    // init waits until load_game so directory callbacks are already valid.
    return true;
}
bool LibretroHost::load_game(const std::string& path, const std::string& directory) {
    if (!library) { error = "No core loaded"; return false; }
    close_game();
    error.clear();
    save_dir = directory;
    system_dir = directory;
    std::ifstream file(std::filesystem::u8path(path), std::ios::binary | std::ios::ate);
    if (!file) { error = "Cannot open ROM: " + path; return false; }
    const auto size = file.tellg();
    if (size <= 0 || size > 32 * 1024 * 1024) { error = "ROM must contain 1 byte to 32 MiB"; return false; }
    rom.resize(static_cast<std::size_t>(size));
    file.seekg(0);
    if (!file.read(reinterpret_cast<char*>(rom.data()), size)) { error = "Failed reading ROM"; rom.clear(); return false; }
    if (!initialized) { fn_init(); initialized = true; }
    retro_system_info info{};
    fn_get_system_info(&info);
    retro_game_info game{};
    game.path = path.c_str();
    game.data = info.need_fullpath ? nullptr : rom.data();
    game.size = info.need_fullpath ? 0 : rom.size();
    if (!fn_load_game(&game)) { error = "Core rejected ROM"; rom.clear(); return false; }
    loaded = true;
    fn_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
    fn_set_controller_port_device(1, RETRO_DEVICE_NONE);
    retro_system_av_info av{};
    fn_get_system_av_info(&av);
    if (!av_info(av)) { close_game(); return false; }
    return true;
}
bool LibretroHost::av_info(const retro_system_av_info& info) {
    if (!std::isfinite(info.timing.fps) || info.timing.fps < 1 || info.timing.fps > 240 ||
        !std::isfinite(info.timing.sample_rate) || info.timing.sample_rate < 8000 || info.timing.sample_rate > 192000) {
        error = "Core reported unsupported audio/video timing"; return false;
    }
    fps = info.timing.fps;
    sample_rate = info.timing.sample_rate;
    return true;
}
bool LibretroHost::step(std::uint16_t mask) {
    if (!loaded) { error = "No game loaded"; return false; }
    buttons = mask;
    pcm.clear();
    video_changed = false;
    error.clear();
    fn_run();
    return error.empty();
}
bool LibretroHost::environment(unsigned command, void* data) {
    if (!active) return false;
    switch (command) {
    case RETRO_ENVIRONMENT_GET_CAN_DUPE: *static_cast<bool*>(data) = true; return true;
    case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY: *static_cast<const char**>(data) = active->system_dir.c_str(); return true;
    case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY: *static_cast<const char**>(data) = active->save_dir.c_str(); return true;
    case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: static_cast<retro_log_callback*>(data)->log = log; return true;
    case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION: *static_cast<unsigned*>(data) = 0; return true;
    case RETRO_ENVIRONMENT_SET_VARIABLES: {
        const auto* option = static_cast<const retro_variable*>(data);
        for (; option && option->key; ++option) {
            const std::string choices = option->value ? option->value : "";
            const auto separator = choices.find(';');
            if (separator == std::string::npos) continue;
            const auto start = choices.find_first_not_of(' ', separator + 1);
            if (start == std::string::npos) continue;
            active->options[option->key] = choices.substr(start, choices.find('|', start) - start);
        }
        return true;
    }
    case RETRO_ENVIRONMENT_GET_VARIABLE: {
        auto* variable = static_cast<retro_variable*>(data);
        const auto it = active->options.find(variable->key ? variable->key : "");
        variable->value = it == active->options.end() ? nullptr : it->second.c_str();
        return variable->value != nullptr;
    }
    case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: *static_cast<bool*>(data) = false; return true;
    case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
        const auto format = *static_cast<retro_pixel_format*>(data);
        if (format != RETRO_PIXEL_FORMAT_XRGB8888 && format != RETRO_PIXEL_FORMAT_RGB565 && format != RETRO_PIXEL_FORMAT_0RGB1555) return false;
        active->pixel_format = format; return true;
    }
    case RETRO_ENVIRONMENT_SET_GEOMETRY: return true; // actual callback dimensions are authoritative
    case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO: return active->av_info(*static_cast<retro_system_av_info*>(data));
    case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS: return true;
    case RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE: *static_cast<int*>(data) = 3; return true;
    case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
    case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
    case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
    case RETRO_ENVIRONMENT_SET_SUBSYSTEM_INFO: return true;
    default: return false;
    }
}
void LibretroHost::video(const void* data, unsigned w, unsigned h, std::size_t pitch) {
    if (!active || !data) return; // null is a duplicate frame
    const unsigned bytes = active->pixel_format == RETRO_PIXEL_FORMAT_XRGB8888 ? 4 : 2;
    if (data == RETRO_HW_FRAME_BUFFER_VALID || w == 0 || h == 0 || w > 1024 || h > 1024 || pitch < w * bytes) {
        active->error = "Unsupported core video buffer"; return;
    }
    active->rgba.resize(static_cast<std::size_t>(w) * h * 4);
    for (unsigned y = 0; y < h; ++y) {
        const auto* row = static_cast<const std::uint8_t*>(data) + y * pitch;
        for (unsigned x = 0; x < w; ++x) {
            auto* pixel = active->rgba.data() + (static_cast<std::size_t>(y) * w + x) * 4;
            if (bytes == 4) {
                std::uint32_t value; std::memcpy(&value, row + x * 4, 4);
                pixel[0] = (value >> 16) & 255; pixel[1] = (value >> 8) & 255; pixel[2] = value & 255;
            } else {
                std::uint16_t value; std::memcpy(&value, row + x * 2, 2);
                const bool rgb565 = active->pixel_format == RETRO_PIXEL_FORMAT_RGB565;
                pixel[0] = static_cast<std::uint8_t>(((value >> (rgb565 ? 11 : 10)) & 31) * 255 / 31);
                pixel[1] = static_cast<std::uint8_t>(((value >> 5) & (rgb565 ? 63 : 31)) * 255 / (rgb565 ? 63 : 31));
                pixel[2] = static_cast<std::uint8_t>((value & 31) * 255 / 31);
            }
            pixel[3] = 255;
        }
    }
    active->width = w; active->height = h; active->video_changed = true;
}
void LibretroHost::audio(std::int16_t left, std::int16_t right) {
    const std::int16_t pair[] = {left, right};
    audio_batch(pair, 1);
}
std::size_t LibretroHost::audio_batch(const std::int16_t* data, std::size_t frames) {
    if (!active || !data) return 0;
    if (frames > 32768 || active->pcm.size() + frames * 2 > 65536) {
        active->error = "Core audio batch exceeds safety limit"; return 0;
    }
    active->pcm.insert(active->pcm.end(), data, data + frames * 2);
    return frames;
}
void LibretroHost::input_poll() {}
std::int16_t LibretroHost::input(unsigned port, unsigned device, unsigned index, unsigned id) {
    if (!active || port != 0 || index != 0 || (device & RETRO_DEVICE_MASK) != RETRO_DEVICE_JOYPAD) return 0;
    if (id == RETRO_DEVICE_ID_JOYPAD_MASK) return static_cast<std::int16_t>(active->buttons);
    return id < 16 ? (active->buttons >> id) & 1 : 0;
}
void LibretroHost::log(retro_log_level, const char* format, ...) {
    std::fputs("[Libretro] ", stderr);
    va_list arguments; va_start(arguments, format); std::vfprintf(stderr, format, arguments); va_end(arguments);
}
std::vector<std::uint8_t> LibretroHost::serialize() {
    if (!loaded) { error = "No game loaded"; return {}; }
    const auto size = fn_serialize_size();
    if (size == 0 || size > 64 * 1024 * 1024) { error = "Core returned unsupported state size"; return {}; }
    std::vector<std::uint8_t> state(size);
    if (!fn_serialize(state.data(), state.size())) { error = "Core failed to save state"; return {}; }
    return state;
}
bool LibretroHost::unserialize(const std::uint8_t* data, std::size_t size) {
    if (!loaded || size == 0 || size > 64 * 1024 * 1024 || !fn_unserialize(data, size)) { error = "Core rejected save state"; return false; }
    return true;
}
std::vector<std::uint8_t> LibretroHost::save_ram() const {
    if (!loaded) return {};
    const auto size = fn_get_memory_size(RETRO_MEMORY_SAVE_RAM);
    const auto* data = static_cast<const std::uint8_t*>(fn_get_memory_data(RETRO_MEMORY_SAVE_RAM));
    if (!data || size == 0 || size > 16 * 1024 * 1024) return {};
    return {data, data + size};
}
bool LibretroHost::set_save_ram(const std::uint8_t* data, std::size_t size) {
    if (!loaded || size != fn_get_memory_size(RETRO_MEMORY_SAVE_RAM)) { error = "SRAM size does not match this game"; return false; }
    auto* memory = fn_get_memory_data(RETRO_MEMORY_SAVE_RAM);
    if (!memory || !data) return false;
    std::memcpy(memory, data, size); return true;
}
}
