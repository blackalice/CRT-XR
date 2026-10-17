#include "libretro_host.h"
#include <cstdlib>
#include <iostream>
#include <stdexcept>

void check(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
    std::cout << "PASS: " << message << '\n';
}
int main(int argc, char** argv) {
    if (argc != 5) return 2;
    try {
        crt_xr::LibretroHost host;
        check(!host.load_core("/missing/crt_xr-core"), "Missing core fails cleanly");
        check(host.load_core(argv[1]), "Fixture core dynamically loads");
        check(host.load_game(argv[3], argv[4]), "Legacy core option default and ROM loading work");
        check(host.step(0) && host.width == 2 && host.height == 2, "Core framebuffer dimensions captured");
        const auto expected = host.rgba;
        check(expected.size() == 16 && expected[0] == 255 && expected[1] == 0 && expected[8] == 0 && expected[10] == 255, "RGB565 channel conversion respects row pitch");
        check(host.pcm.size() == 6 && host.pcm[0] == 1000 && host.pcm[3] == -32768 && host.pcm[4] == 250, "Batch and single stereo audio callbacks preserve PCM");
        check(host.step(0) && host.rgba == expected, "XRGB8888 conversion respects row pitch");
        check(host.step(0) && host.rgba == expected, "0RGB1555 conversion respects row pitch");
        check(host.step(0) && !host.video_changed && host.rgba == expected, "Duplicate video callbacks retain the previous frame");
        check(host.step(1) && host.rgba[0] == 0 && host.rgba[2] == 255, "Joypad B reaches the core");
        const auto state = host.serialize();
        check(!state.empty() && host.step(0) && host.unserialize(state.data(), state.size()) && host.serialize() == state, "Save state round-trip restores core execution state");
        const std::uint8_t invalid = 1;
        check(!host.unserialize(&invalid, 1), "Core rejects malformed state without crashing");
        auto ram = host.save_ram();
        ram[0] = 73;
        check(host.set_save_ram(ram.data(), ram.size()) && host.save_ram()[0] == 73, "SRAM export and restore work");
        check(!host.set_save_ram(&invalid, 1), "Wrong-sized SRAM is rejected");
        host.close();
        check(host.load_core(argv[2]), "Real Snes9x core dynamically loads");
        check(host.load_game(argv[3], argv[4]), "Real Snes9x loads original diagnostic ROM");
        bool executed = true;
        for (int i = 0; i < 90; ++i) executed = host.step(0) && executed;
        check(executed, "Snes9x executes 90 consecutive console frames");
        check(host.width == 256 && host.height >= 224 && host.height <= 240 && !host.rgba.empty(), "Snes9x supplies a console-sized framebuffer");
        check(host.fps > 60 && host.fps < 61 && host.sample_rate > 32000 && host.sample_rate < 32100, "Core supplies NTSC frame rate and audio timing");
        check(!host.pcm.empty(), "Real Snes9x audio callback supplies stereo frames");
        const auto running = host.serialize();
        check(!running.empty() && host.step(0) && host.unserialize(running.data(), running.size()), "Real Snes9x state round-trip succeeds");
        for (int i = 0; i < 5; ++i) host.step(1);
        const auto red = host.rgba;
        check(red[0] > 240 && red[1] < 8 && red[2] < 8, "Real SNES program responds to joypad B with a red backdrop");
        const auto saved_ram = host.save_ram();
        check(!saved_ram.empty() && saved_ram[0] == 0x5A, "Real SNES program writes the expected SRAM sentinel");
        host.close_game();
        check(!host.step(0), "Frame execution is rejected after unload");
    } catch (const std::exception& error) { std::cerr << "FAIL: " << error.what() << '\n'; return 1; }
    return 0;
}
