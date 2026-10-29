#include "libretro.h"
#include <cstdint>
#include <cstdio>
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
// A two-disc tray: the host must open it, choose and close it again.
bool tray_open;
unsigned disc;
bool set_eject(bool open) { tray_open = open; return true; }
bool get_eject() { return tray_open; }
unsigned get_index() { return disc; }
bool set_index(unsigned index) { if (!tray_open || index > 1) return false; disc = index; return true; }
unsigned get_count() { return 2; }
bool no_replace(unsigned, const retro_game_info*) { return false; }
bool no_add() { return false; }
#ifdef MOCK_HW_RENDER
// Draws with OpenGL like a Nintendo 64 core: a 3.3 core context from the host,
// cleared to a colour, with a green strip along the bottom (bottom-left origin).
retro_hw_render_callback hw;
bool context_ready;
using Clear = void (*)(unsigned);
using ClearColor = void (*)(float, float, float, float);
using BindFramebuffer = void (*)(unsigned, unsigned);
using Rectangle = void (*)(int, int, int, int);
using Toggle = void (*)(unsigned);
struct { Clear clear; ClearColor clear_color; BindFramebuffer bind; Rectangle viewport, scissor; Toggle enable, disable; } gl;
void reset_context() {
    gl.clear = reinterpret_cast<Clear>(hw.get_proc_address("glClear"));
    gl.clear_color = reinterpret_cast<ClearColor>(hw.get_proc_address("glClearColor"));
    gl.bind = reinterpret_cast<BindFramebuffer>(hw.get_proc_address("glBindFramebuffer"));
    gl.viewport = reinterpret_cast<Rectangle>(hw.get_proc_address("glViewport"));
    gl.scissor = reinterpret_cast<Rectangle>(hw.get_proc_address("glScissor"));
    gl.enable = reinterpret_cast<Toggle>(hw.get_proc_address("glEnable"));
    gl.disable = reinterpret_cast<Toggle>(hw.get_proc_address("glDisable"));
    context_ready = gl.clear && gl.clear_color && gl.bind && gl.viewport && gl.scissor && gl.enable && gl.disable;
}
void destroy_context() { context_ready = false; }
void draw(bool pressed) {
    if (!context_ready) return;
    gl.bind(0x8D40, static_cast<unsigned>(hw.get_current_framebuffer())); // GL_FRAMEBUFFER
    gl.viewport(0, 0, 64, 48);
    gl.clear_color(pressed ? 0.0f : 1.0f, 0.0f, pressed ? 1.0f : 0.0f, 1.0f);
    gl.clear(0x4000 | 0x100); // colour and depth
    gl.enable(0x0C11); // GL_SCISSOR_TEST: the bottom eight rows, counted bottom-up
    gl.scissor(0, 0, 64, 8);
    gl.clear_color(0.0f, 1.0f, 0.0f, 0.0f);
    gl.clear(0x4000);
    gl.disable(0x0C11);
    video(RETRO_HW_FRAME_BUFFER_VALID, 64, 48, 0);
}
#endif
bool get_label(unsigned index, char* text, std::size_t size) { return std::snprintf(text, size, "Disc %u", index + 1) > 0; }
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
    retro_variable options[] = {{"fixture_option", "Fixture; default|other"}, {"fixture_choice", "Choice; first|second"}, {nullptr, nullptr}};
    environment(RETRO_ENVIRONMENT_SET_VARIABLES, options);
    retro_disk_control_ext_callback tray{set_eject, get_eject, get_index, set_index, get_count, no_replace, no_add, nullptr, nullptr, get_label};
    environment(RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE, &tray);
}
RETRO_API void retro_deinit() {}
RETRO_API void retro_get_system_info(retro_system_info* info) { *info = {"CRT XR test fixture", "1", "sfc",
#ifdef MOCK_NEED_FULLPATH
    true
#else
    false
#endif
    , false}; }
#ifdef MOCK_HW_RENDER
RETRO_API void retro_get_system_av_info(retro_system_av_info* info) { *info = {{64, 48, 64, 48, 4.0f / 3.0f}, {60, 32000}}; }
#else
RETRO_API void retro_get_system_av_info(retro_system_av_info* info) { *info = {{2, 2, 2, 2, 1}, {60, 32000}}; }
#endif
RETRO_API void retro_set_controller_port_device(unsigned, unsigned) {}
RETRO_API bool retro_load_game(const retro_game_info* game) {
    counter = 0;
    tray_open = false; disc = 0;
#ifdef MOCK_HW_RENDER
    hw = {};
    hw.context_type = RETRO_HW_CONTEXT_OPENGL_CORE;
    hw.version_major = 3; hw.version_minor = 3;
    hw.context_reset = reset_context; hw.context_destroy = destroy_context;
    hw.depth = true; hw.bottom_left_origin = true;
    if (!environment(RETRO_ENVIRONMENT_SET_HW_RENDER, &hw)) return false;
#endif
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
#ifdef MOCK_HW_RENDER
    draw(pressed);
#else
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
#endif
    const std::int16_t samples[] = {1000, -1000, 32767, -32768};
    audio_batch(samples, 2);
    audio(250, -250);
    ram[0] = static_cast<std::uint8_t>(counter);
    // Exposed for the host test: the left stick, an analog trigger, the disc and an option.
    ram[1] = static_cast<std::uint8_t>(input(0, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_X) >> 8);
    ram[2] = input(0, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_BUTTON, RETRO_DEVICE_ID_JOYPAD_L2) == 0x7FFF;
    ram[3] = static_cast<std::uint8_t>(disc | (tray_open ? 0x80 : 0));
    retro_variable choice{"fixture_choice", nullptr};
    ram[4] = environment(RETRO_ENVIRONMENT_GET_VARIABLE, &choice) && std::strcmp(choice.value, "second") == 0;
}
RETRO_API std::size_t retro_serialize_size() { return sizeof(counter); }
RETRO_API bool retro_serialize(void* data, std::size_t size) { if (size != sizeof(counter)) return false; std::memcpy(data, &counter, size); return true; }
RETRO_API bool retro_unserialize(const void* data, std::size_t size) { if (size != sizeof(counter)) return false; std::memcpy(&counter, data, size); return true; }
RETRO_API void* retro_get_memory_data(unsigned id) { return id == RETRO_MEMORY_SAVE_RAM ? ram : nullptr; }
RETRO_API std::size_t retro_get_memory_size(unsigned id) { return id == RETRO_MEMORY_SAVE_RAM ? sizeof(ram) : 0; }
}
