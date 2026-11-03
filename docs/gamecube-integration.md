# GameCube integration (in development)

The first integration slice is opt-in with `CRT_XR_EXPERIMENTAL_GAMECUBE=1`.
Without it, GameCube discovery and settings remain absent from release builds.
The Deck test release enables this flag in its launch wrapper and adds a Linux
Dolphin core and system data. Standard cross-platform packages remain unchanged;
there is no Windows Dolphin core yet. This is an experimental gameplay test,
not a claim of full GameCube compatibility or consistent Deck performance.

Implemented: header-based ISO/GCM and RVZ/WIA discovery (including exclusion of
Wii images), M3U grouping, the matching console icon, control stick and C-stick,
proportional L/R triggers, and console/per-game options in the existing menus.
A is on the bottom face button, B on the left, X on the right, Y on the top;
R1 is Z. R3 still recentres the view. Native resolution, JIT64, dual core and
HLE audio are the starting configuration; input preview is disabled.

## Source and runtime contract

Source reviewed: https://github.com/libretro/dolphin at
`b93001ed50c8b34e6ead4eed713c2005a80386e4`. Local development checkout:
`tools/dolphin`. Source references: `DolphinLibretro/Input.cpp`,
`Common/Options.{h,cpp}`, `Boot.cpp`, `Video.cpp`, and `docs/WiaAndRvz.md`.
The [Libretro setup guide](https://docs.libretro.com/library/dolphin/) describes
the required Sys data and the supported rendering interfaces.

The core uses the host's OpenGL path. `Dockerfile.dolphin` keeps the existing
Ubuntu 22.04 baseline, adding GCC 12 and CMake 3.28.4 for this core only.
`scripts/build-dolphin-deck.py` builds the Linux test core, archives the pinned
source and required dependency gitlinks, preserves the licences and Sys data,
and records binary/source/data hashes in `cores/dolphin-test-build.json`.
Existing release cores keep their current toolchain and evidence.
The recorded `dolphin-no-gba-player.patch` guards Game Boy Player configuration
references when the unused mGBA integration is disabled. Its unpatched source
archive and the applied patch are both included in the test package.

The native host assigns distinct callback functions to each loaded core, so
callbacks from Dolphin's CPU thread reach the correct instance. Controller
values are atomic snapshots; an audio queue protected by a mutex separates
CPU-thread audio delivery from presentation. Hardware frames up to 4096 pixels
per dimension are accepted within the framebuffer allocated at load, including
the optional 2x resolution setting. Software framebuffer limits are unchanged.

Dolphin expects `<system>/dolphin-emu/Sys` and `<save>/User`. CRT XR currently
supplies the same writable directory for system and save files, so the support
helper stages only Sys into `saves/gamecube/dolphin/dolphin-emu/Sys` and leaves
`saves/gamecube/dolphin/User` alone. Packaged data will come from
`core-data/dolphin-emu/Sys` beside the application. For development only,
`CRT_XR_DOLPHIN_SYS` may point at the pinned checkout's `Data/Sys` directory.
This data includes redistributable replacement fonts and DSP data, whose
licences must accompany the eventual package. A console BIOS is not required.

## Remaining before enabling by default

1. Add a Windows core build and integrate both targets with standard exports.
   The Deck test release separately carries its source/data/build evidence.
2. Expand the native regression coverage for long-running CPU/GPU interactions
   and core reloads. `tests/gamecube_runtime.gd` accepts a caller-supplied game
   and an isolated save directory for real-core boot/video/audio/state tests.
3. Verify frame pacing, audio, analog trigger half/full presses, C-stick,
   reset, disc switching, memory-card persistence and save-state round trips.
4. Benchmark real gameplay on the Deck with the CRT room enabled, including
   cold/warm shader cache runs. Compare synchronous and hybrid ubershaders;
   do not trade correctness for a presumed performance gain.
5. Remove the development opt-in only after runtime and packaging checks pass.

Foundation checks: run Godot with `--headless --path . --script tests/gamecube.gd`
once without the environment opt-in and once with it. The tests use generated
header/data fixtures; they do not establish that Dolphin boots or renders.

## Deck test results (3 November 2026)

The enabled test release passed 1,200-frame runs with Mario Party 4 (ISO) and
Super Smash Brothers Melee (RVZ), using isolated saves. Both produced changing
video and stereo audio, restored a save state, reset and unloaded successfully.
Mario Party's file-selection screen was visually checked. The states were about
92.7 MB, exceeding the older 64 MiB limit; native states now have a 256 MiB cap
and the file reader allows one additional MiB for the metadata envelope.

These are boot/menu checks, not representative gameplay benchmarks. Melee had
a 311 ms cold-run outlier. Shader compilation and heavier scenes still need
user gameplay testing with the room and headset active.
