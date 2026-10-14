#pragma once
#define RETRO_IMPORT_SYMBOLS
#include "libretro.h"
#include <cstdint>
#include <map>
#include <string>
#include <vector>

namespace retrocrt {
// One Libretro instance, used only on the Godot main thread.
class LibretroHost {
public:
    ~LibretroHost();
    bool load_core(const std::string& path);
    bool load_game(const std::string& path, const std::string& save_directory);
    bool step(std::uint16_t buttons);
    void close_game();
    void close();
    std::vector<std::uint8_t> serialize();
    bool unserialize(const std::uint8_t* data, std::size_t size);
    std::vector<std::uint8_t> save_ram() const;
    bool set_save_ram(const std::uint8_t* data, std::size_t size);
    bool loaded = false;
    unsigned width = 0, height = 0;
    bool video_changed = false;
    double fps = 60.0, sample_rate = 32040.0;
    std::string error, name;
    std::vector<std::uint8_t> rgba;
    std::vector<std::int16_t> pcm;
private:
    static LibretroHost* active;
    void* library = nullptr;
    bool initialized = false;
    retro_pixel_format pixel_format = RETRO_PIXEL_FORMAT_0RGB1555;
    std::uint16_t buttons = 0;
    std::string system_dir, save_dir;
    std::map<std::string, std::string> options;
    std::vector<std::uint8_t> rom;
    bool av_info(const retro_system_av_info& info);
    static bool environment(unsigned command, void* data);
    static void video(const void* data, unsigned width, unsigned height, std::size_t pitch);
    static void audio(std::int16_t left, std::int16_t right);
    static std::size_t audio_batch(const std::int16_t* data, std::size_t frames);
    static void input_poll();
    static std::int16_t input(unsigned port, unsigned device, unsigned index, unsigned id);
    static void log(retro_log_level level, const char* format, ...);
#define CORE_API(method) decltype(&retro_##method) fn_##method = nullptr
    CORE_API(api_version); CORE_API(init); CORE_API(deinit);
    CORE_API(set_environment); CORE_API(set_video_refresh);
    CORE_API(set_audio_sample); CORE_API(set_audio_sample_batch);
    CORE_API(set_input_poll); CORE_API(set_input_state);
    CORE_API(get_system_info); CORE_API(get_system_av_info);
    CORE_API(set_controller_port_device); CORE_API(load_game); CORE_API(unload_game);
    CORE_API(run); CORE_API(serialize_size); CORE_API(serialize); CORE_API(unserialize);
    CORE_API(get_memory_data); CORE_API(get_memory_size);
#undef CORE_API
};
}
