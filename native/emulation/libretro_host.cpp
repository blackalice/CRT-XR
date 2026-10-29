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

namespace crt_xr {
LibretroHost* LibretroHost::active = nullptr;
LibretroHost::~LibretroHost() { close(); }
void LibretroHost::close_game() {
    Use use(this);
    if (loaded) fn_unload_game();
    loaded = false;
    rom.clear(); rgba.clear(); pcm.clear();
    width = height = 0;
    video_changed = false;
    insert_countdown = 0;
    std::fill(std::begin(analog), std::end(analog), 0);
}
void LibretroHost::close() {
    close_game();
    Use use(this);
    if (initialized) fn_deinit();
    initialized = false;
    if (library) {
#ifdef _WIN32
        FreeLibrary(static_cast<HMODULE>(library));
#else
        dlclose(library);
#endif
    }
    library = nullptr;
    options.clear();
    overrides.clear();
    disk = {};
}
bool LibretroHost::load_core(const std::string& path) {
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
    BIND(load_game); BIND(unload_game); BIND(reset); BIND(run); BIND(serialize_size); BIND(serialize); BIND(unserialize);
    BIND(get_memory_data); BIND(get_memory_size);
#undef BIND
    if (fn_api_version() != RETRO_API_VERSION) { error = "Unsupported Libretro API version"; close(); return false; }
    Use use(this);
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
    Use use(this);
    error.clear();
    save_dir = directory;
    system_dir = directory;
    std::ifstream file(std::filesystem::u8path(path), std::ios::binary | std::ios::ate);
    if (!file) { error = "Cannot open ROM: " + path; return false; }
    const auto size = file.tellg();
    rom.clear();
    if (!initialized) { fn_init(); initialized = true; }
    retro_system_info info{};
    fn_get_system_info(&info);
    retro_game_info game{};
    game.path = path.c_str();
    if (info.need_fullpath) {
        // Disc images (for example Sega CD .cue/.bin) exceed the cartridge
        // buffer cap; the core opens the path itself.
        if (size <= 0) { error = "ROM file is empty: " + path; return false; }
        game.data = nullptr;
        game.size = 0;
    } else {
        // 64 MiB is the largest Nintendo 64 cartridge.
        if (size <= 0 || size > 64 * 1024 * 1024) { error = "ROM must contain 1 byte to 64 MiB"; return false; }
        rom.resize(static_cast<std::size_t>(size));
        file.seekg(0);
        if (!file.read(reinterpret_cast<char*>(rom.data()), size)) { rom.clear(); error = "Failed reading ROM"; return false; }
        game.data = rom.data();
        game.size = rom.size();
    }
    if (!fn_load_game(&game)) { error = "Core rejected ROM"; rom.clear(); return false; }
    loaded = true;
    fn_set_controller_port_device(0, port_device);
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
    Use use(this);
    buttons = mask;
    pcm.clear();
    video_changed = false;
    error.clear();
    fn_run();
    if (insert_countdown > 0 && --insert_countdown == 0 && disk.set_eject_state) disk.set_eject_state(false);
    return error.empty();
}
bool LibretroHost::reset() {
    if (!loaded) { error = "No game loaded"; return false; }
    Use use(this);
    error.clear();
    fn_reset(); // The console's reset button; cartridge SRAM is kept.
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
        const std::string key = variable->key ? variable->key : "";
        variable->value = nullptr;
        if (const auto chosen = active->overrides.find(key); chosen != active->overrides.end()) variable->value = chosen->second.c_str();
        else if (const auto initial = active->options.find(key); initial != active->options.end()) variable->value = initial->second.c_str();
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
    // Bit 0 video, bit 1 audio. Preview instances skip audio synthesis.
    case RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE: *static_cast<int*>(data) = 1 | (active->want_audio ? 2 : 0); return true;
    case RETRO_ENVIRONMENT_GET_DISK_CONTROL_INTERFACE_VERSION: *static_cast<unsigned*>(data) = 1; return true;
    case RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE: {
        // Null takes the tray away again (Genesis Plus GX does so for cartridges).
        active->disk = {};
        if (!data) return true;
        // The original interface is the extended one's leading fields.
        const auto& basic = *static_cast<const retro_disk_control_callback*>(data);
        active->disk.set_eject_state = basic.set_eject_state; active->disk.get_eject_state = basic.get_eject_state;
        active->disk.get_image_index = basic.get_image_index; active->disk.set_image_index = basic.set_image_index;
        active->disk.get_num_images = basic.get_num_images; active->disk.replace_image_index = basic.replace_image_index;
        active->disk.add_image_index = basic.add_image_index;
        return true;
    }
    case RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE:
        active->disk = data ? *static_cast<const retro_disk_control_ext_callback*>(data) : retro_disk_control_ext_callback{};
        return true;
    case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
    case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
    case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
    case RETRO_ENVIRONMENT_SET_SUBSYSTEM_INFO: return true;
    default: return false;
    }
}
namespace {
// RGBA8 (little-endian bytes R,G,B,A) for every 16-bit pixel value: one table
// read per pixel instead of shifts, multiplies and divides. 256 KiB each.
const std::vector<std::uint32_t>& lookup(bool rgb565) {
    static std::vector<std::uint32_t> tables[2];
    auto& table = tables[rgb565 ? 1 : 0];
    if (table.empty()) {
        table.resize(65536);
        for (std::uint32_t value = 0; value < 65536; ++value) {
            const std::uint32_t r = ((value >> (rgb565 ? 11 : 10)) & 31) * 255 / 31;
            const std::uint32_t g = ((value >> 5) & (rgb565 ? 63 : 31)) * 255 / (rgb565 ? 63 : 31);
            const std::uint32_t b = (value & 31) * 255 / 31;
            table[value] = r | (g << 8) | (b << 16) | 0xFF000000u;
        }
    }
    return table;
}
}
void LibretroHost::video(const void* data, unsigned w, unsigned h, std::size_t pitch) {
    if (!active || !data) return; // null is a duplicate frame
    LibretroHost& host = *active;
    const unsigned bytes = host.pixel_format == RETRO_PIXEL_FORMAT_XRGB8888 ? 4 : 2;
    if (data == RETRO_HW_FRAME_BUFFER_VALID || w == 0 || h == 0 || w > 1024 || h > 1024 || pitch < w * bytes) {
        host.error = "Unsupported core video buffer"; return;
    }
    host.rgba.resize(static_cast<std::size_t>(w) * h * 4);
    // Locals and one 32-bit store per pixel: byte writes through rgba.data()
    // could alias anything, forcing the compiler to reload host state per pixel.
    auto* out = reinterpret_cast<std::uint32_t*>(host.rgba.data());
    const auto* source = static_cast<const std::uint8_t*>(data);
    if (bytes == 4) {
        for (unsigned y = 0; y < h; ++y, out += w) {
            const auto* row = reinterpret_cast<const std::uint32_t*>(source + y * pitch);
            for (unsigned x = 0; x < w; ++x) {
                const std::uint32_t value = row[x];
                out[x] = ((value >> 16) & 0xFF) | (value & 0xFF00) | ((value & 0xFF) << 16) | 0xFF000000u;
            }
        }
    } else {
        const std::uint32_t* table = lookup(host.pixel_format == RETRO_PIXEL_FORMAT_RGB565).data();
        for (unsigned y = 0; y < h; ++y, out += w) {
            const auto* row = reinterpret_cast<const std::uint16_t*>(source + y * pitch);
            for (unsigned x = 0; x < w; ++x) out[x] = table[row[x]];
        }
    }
    host.width = w; host.height = h; host.video_changed = true;
}
void LibretroHost::audio(std::int16_t left, std::int16_t right) {
    const std::int16_t pair[] = {left, right};
    audio_batch(pair, 1);
}
std::size_t LibretroHost::audio_batch(const std::int16_t* data, std::size_t frames) {
    if (!active || !data) return 0;
    if (!active->want_audio) return frames;
    if (frames > 32768 || active->pcm.size() + frames * 2 > 65536) {
        active->error = "Core audio batch exceeds safety limit"; return 0;
    }
    active->pcm.insert(active->pcm.end(), data, data + frames * 2);
    return frames;
}
void LibretroHost::input_poll() {}
std::int16_t LibretroHost::input(unsigned port, unsigned device, unsigned index, unsigned id) {
    if (!active || port != 0) return 0;
    if ((device & RETRO_DEVICE_MASK) == RETRO_DEVICE_ANALOG) {
        if (index == RETRO_DEVICE_INDEX_ANALOG_BUTTON) return id < 16 && (active->buttons >> id) & 1 ? 0x7FFF : 0;
        return index < 2 && id < 2 ? active->analog[index * 2 + id] : 0;
    }
    if (index != 0 || (device & RETRO_DEVICE_MASK) != RETRO_DEVICE_JOYPAD) return 0;
    if (id == RETRO_DEVICE_ID_JOYPAD_MASK) return static_cast<std::int16_t>(active->buttons);
    return id < 16 ? (active->buttons >> id) & 1 : 0;
}
void LibretroHost::log(retro_log_level, const char* format, ...) {
    std::fputs("[Libretro] ", stderr);
    va_list arguments; va_start(arguments, format); std::vfprintf(stderr, format, arguments); va_end(arguments);
}
std::vector<std::uint8_t> LibretroHost::serialize() {
    std::vector<std::uint8_t> state;
    if (!serialize_into(state)) return {};
    return state;
}
bool LibretroHost::serialize_into(std::vector<std::uint8_t>& state) {
    if (!loaded) { error = "No game loaded"; return false; }
    Use use(this);
    const auto size = fn_serialize_size();
    if (size == 0 || size > 64 * 1024 * 1024) { error = "Core returned unsupported state size"; return false; }
    state.resize(size);
    if (!fn_serialize(state.data(), state.size())) { error = "Core failed to save state"; return false; }
    return true;
}
bool LibretroHost::unserialize(const std::uint8_t* data, std::size_t size) {
    Use use(this);
    if (!loaded || size == 0 || size > 64 * 1024 * 1024 || !fn_unserialize(data, size)) { error = "Core rejected save state"; return false; }
    return true;
}
std::vector<std::uint8_t> LibretroHost::save_ram() const {
    if (!loaded) return {};
    Use use(this);
    const auto size = fn_get_memory_size(RETRO_MEMORY_SAVE_RAM);
    const auto* data = static_cast<const std::uint8_t*>(fn_get_memory_data(RETRO_MEMORY_SAVE_RAM));
    if (!data || size == 0 || size > 16 * 1024 * 1024) return {};
    return {data, data + size};
}
bool LibretroHost::set_save_ram(const std::uint8_t* data, std::size_t size) {
    if (!loaded) { error = "SRAM size does not match this game"; return false; }
    Use use(this);
    if (size != fn_get_memory_size(RETRO_MEMORY_SAVE_RAM)) { error = "SRAM size does not match this game"; return false; }
    auto* memory = fn_get_memory_data(RETRO_MEMORY_SAVE_RAM);
    if (!memory || !data) return false;
    std::memcpy(memory, data, size); return true;
}
void LibretroHost::set_option(const std::string& key, const std::string& value) { overrides[key] = value; }
unsigned LibretroHost::disc_count() const {
    if (!loaded || !disk.get_num_images) return 0;
    Use use(this);
    return disk.get_num_images();
}
unsigned LibretroHost::disc_index() const {
    if (!loaded || !disk.get_image_index) return 0;
    Use use(this);
    return disk.get_image_index();
}
std::string LibretroHost::disc_label(unsigned index) const {
    if (!loaded || !disk.get_image_label) return {};
    Use use(this);
    char label[256] = {};
    return disk.get_image_label(index, label, sizeof(label)) ? label : "";
}
bool LibretroHost::change_disc(unsigned index) {
    if (!loaded || !disk.set_eject_state || !disk.set_image_index || index >= disc_count()) { error = "This game has no other disc"; return false; }
    Use use(this);
    if (!disk.set_eject_state(true) || !disk.set_image_index(index)) { error = "The core could not change disc"; return false; }
    insert_countdown = std::max(1, static_cast<int>(std::lround(fps)));
    return true;
}
}
