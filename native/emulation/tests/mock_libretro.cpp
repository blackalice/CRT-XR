#include "libretro.h"
#include <cstdint>
#include <cstring>

namespace {
retro_environment_t environment;
retro_video_refresh_t video;
retro_audio_sample_t audio;
retro_audio_sample_batch_t audio_batch;
retro_input_poll_t poll;
retro_input_state_t input;
std::uint64_t counter;
std::uint8_t ram[16];
}
extern "C" {
RETRO_API void retro_set_environment(retro_environment_t cb) { environment = cb; }
RETRO_API void retro_set_video_refresh(retro_video_refresh_t cb) { video = cb; }
RETRO_API void retro_set_audio_sample(retro_audio_sample_t cb) { audio = cb; }
RETRO_API void retro_set_audio_sample_batch(retro_audio_sample_batch_t cb) { audio_batch = cb; }
RETRO_API void retro_set_input_poll(retro_input_poll_t cb) { poll = cb; }
RETRO_API void retro_set_input_state(retro_input_state_t cb) { input = cb; }
RETRO_API unsigned retro_api_version() { return RETRO_API_VERSION; }
RETRO_API void retro_init() {
    retro_variable options[] = {{"fixture_option", "Fixture; default|other"}, {nullptr, nullptr}};
    environment(RETRO_ENVIRONMENT_SET_VARIABLES, options);
}
RETRO_API void retro_deinit() {}
RETRO_API void retro_get_system_info(retro_system_info* info) { *info = {"CRT XR test fixture", "1", "sfc",
#ifdef MOCK_NEED_FULLPATH
    true
#else
    false
#endif
    , false}; }
RETRO_API void retro_get_system_av_info(retro_system_av_info* info) { *info = {{2, 2, 2, 2, 1}, {60, 32000}}; }
RETRO_API void retro_set_controller_port_device(unsigned, unsigned) {}
RETRO_API bool retro_load_game(const retro_game_info* game) {
    counter = 0;
#ifdef MOCK_NEED_FULLPATH
    const bool supplied = game && game->path && !game->data;
#else
    const bool supplied = game && game->data;
#endif
    retro_variable option{"fixture_option", nullptr};
    return supplied && environment(RETRO_ENVIRONMENT_GET_VARIABLE, &option) && std::strcmp(option.value, "default") == 0;
}
RETRO_API void retro_unload_game() {}
RETRO_API void retro_reset() { counter = 0; }
RETRO_API void retro_run() {
    ++counter;
    poll();
    const bool pressed = input(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B);
    if (counter % 4 == 1) {
        auto format = RETRO_PIXEL_FORMAT_RGB565;
        environment(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &format);
        const std::uint16_t pixels[] = {static_cast<std::uint16_t>(pressed ? 0x001F : 0xF800), 0x07E0, 0, 0, 0x001F, 0xFFFF, 0, 0};
        video(pixels, 2, 2, 8);
    } else if (counter % 4 == 2) {
        auto format = RETRO_PIXEL_FORMAT_XRGB8888;
        environment(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &format);
        const std::uint32_t pixels[] = {pressed ? 0x000000FFu : 0x00FF0000u, 0x0000FF00, 0, 0, 0x000000FF, 0x00FFFFFF, 0, 0};
        video(pixels, 2, 2, 16);
    } else if (counter % 4 == 3) {
        auto format = RETRO_PIXEL_FORMAT_0RGB1555;
        environment(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &format);
        const std::uint16_t pixels[] = {static_cast<std::uint16_t>(pressed ? 0x001F : 0x7C00), 0x03E0, 0, 0, 0x001F, 0x7FFF, 0, 0};
        video(pixels, 2, 2, 8);
    } else video(nullptr, 2, 2, 0);
    const std::int16_t samples[] = {1000, -1000, 32767, -32768};
    audio_batch(samples, 2);
    audio(250, -250);
    ram[0] = static_cast<std::uint8_t>(counter);
}
RETRO_API std::size_t retro_serialize_size() { return sizeof(counter); }
RETRO_API bool retro_serialize(void* data, std::size_t size) { if (size != sizeof(counter)) return false; std::memcpy(data, &counter, size); return true; }
RETRO_API bool retro_unserialize(const void* data, std::size_t size) { if (size != sizeof(counter)) return false; std::memcpy(&counter, data, size); return true; }
RETRO_API void* retro_get_memory_data(unsigned id) { return id == RETRO_MEMORY_SAVE_RAM ? ram : nullptr; }
RETRO_API std::size_t retro_get_memory_size(unsigned id) { return id == RETRO_MEMORY_SAVE_RAM ? sizeof(ram) : 0; }
}
