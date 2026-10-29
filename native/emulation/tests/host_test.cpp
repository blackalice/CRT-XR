#include "libretro_host.h"
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>

void check(bool value, const std::string& message) {
    if (!value) throw std::runtime_error(message);
    std::cout << "PASS: " << message << '\n';
}
int main(int argc, char** argv) {
    if (argc < 5 || argc > 7) return 2;
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
        {
            const auto running = host.serialize();
            check(host.reset() && host.serialize() != running && host.save_ram() == ram, "Reset restarts the console and keeps SRAM");
            check(host.unserialize(running.data(), running.size()), "State restores after a reset");
        }
        {
            host.analog[0] = 0x4000;
            check(host.step(1 << RETRO_DEVICE_ID_JOYPAD_L2) && host.save_ram()[1] == 0x40 && host.save_ram()[2] == 1, "Analog stick and trigger reach the core");
            check(host.save_ram()[4] == 0, "Core option default applies without an override");
            host.set_option("fixture_choice", "second");
            check(host.step(0) && host.save_ram()[4] == 1, "A core option override wins over the default");
            check(host.disc_count() == 2 && host.disc_index() == 0 && host.disc_label(1) == "Disc 2", "Disc tray reports its discs");
            check(host.change_disc(1) && host.step(0) && host.save_ram()[3] == 0x81, "Changing disc opens the tray and selects the disc");
            bool closed = false;
            for (int i = 0; i < 90 && !closed; ++i) closed = host.step(0) && host.save_ram()[3] == 0x01;
            check(closed, "The tray closes again after about a second");
            check(!host.change_disc(5), "A disc the game does not have is refused");
            ram = host.save_ram();
        }
        ram[0] = 73;
        check(host.set_save_ram(ram.data(), ram.size()) && host.save_ram()[0] == 73, "SRAM export and restore work");
        check(!host.set_save_ram(&invalid, 1), "Wrong-sized SRAM is rejected");
        {
            // Input preview runs a renamed copy of the core beside the playing one.
            const std::filesystem::path original(argv[1]);
            const auto copy = std::filesystem::temp_directory_path() / ("crt_xr_mock_preview" + original.extension().string());
            std::filesystem::copy_file(original, copy, std::filesystem::copy_options::overwrite_existing);
            crt_xr::LibretroHost second;
            check(second.load_core(copy.string()) && second.load_game(argv[3], argv[4]), "A renamed core copy loads beside the playing core");
            const auto playing = host.serialize();
            check(second.unserialize(playing.data(), playing.size()) && second.serialize() == playing, "The copy adopts the playing core's state");
            check(second.step(0) && second.step(0) && host.serialize() == playing && second.serialize() != playing, "Running the copy leaves the playing core untouched");
            second.close();
            std::filesystem::remove(copy);
        }
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
        if (argc >= 6) {
            host.close();
            crt_xr::LibretroHost fullpath_host;
            check(fullpath_host.load_core(argv[5]), "Fullpath fixture core dynamically loads");
            const auto image = std::filesystem::temp_directory_path() / "crt_xr_fullpath_probe.bin";
            {
                std::ofstream out(image, std::ios::binary);
                out.seekp(40LL * 1024 * 1024 - 1);
                out.put(0);
            }
            check(fullpath_host.load_game(image.string(), argv[4]), "Fullpath core receives a 40 MiB image without the buffer read");
            check(fullpath_host.step(0) && fullpath_host.width == 2, "Fullpath core executes a frame");
            std::filesystem::remove(image);
        }
        if (argc == 7) {
            // A core that draws with OpenGL, on its own thread with a hidden context.
            crt_xr::LibretroHost refused;
            check(refused.load_core(argv[6]) && !refused.load_game(argv[3], argv[4]), "Without hardware rendering a GPU core is refused cleanly");
            refused.close();
            crt_xr::LibretroHost gpu;
            gpu.hardware_rendering = true;
            check(gpu.load_core(argv[6]), "GPU fixture core loads on its own thread");
            check(gpu.load_game(argv[3], argv[4]), "GPU core gets an OpenGL 3.3 core context: " + gpu.error);
            check(gpu.step(0) && gpu.width == 64 && gpu.height == 48 && gpu.rgba.size() == 64 * 48 * 4, "A GPU frame is read back at its own size");
            const auto top = [&](std::size_t x) { return gpu.rgba.data() + x * 4; };
            const auto bottom = [&](std::size_t x) { return gpu.rgba.data() + (47 * 64 + x) * 4; };
            check(top(5)[0] == 255 && top(5)[1] == 0 && top(5)[2] == 0 && top(5)[3] == 255, "The picture's colour comes through");
            check(bottom(5)[0] == 0 && bottom(5)[1] == 255 && bottom(5)[3] == 255, "Bottom-up GL rows are flipped and made opaque");
            check(gpu.step(1) && top(5)[0] == 0 && top(5)[2] == 255, "Input reaches the GPU core");
            const auto state = gpu.serialize();
            check(!state.empty() && gpu.unserialize(state.data(), state.size()), "GPU core states round-trip on its thread");
            check(gpu.load_game(argv[3], argv[4]) && gpu.step(0) && top(5)[0] == 255, "A second game reuses the context");
            gpu.close();
            check(!gpu.loaded, "The GPU core closes with its context");
        }
    } catch (const std::exception& error) { std::cerr << "FAIL: " << error.what() << '\n'; return 1; }
    return 0;
}
