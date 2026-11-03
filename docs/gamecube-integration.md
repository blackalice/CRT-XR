# GameCube integration (in development)

The first integration slice is opt-in with `CRT_XR_EXPERIMENTAL_GAMECUBE=1`.
Without it, GameCube discovery and settings remain absent from release builds.
No Dolphin binary or system data is included in the current packages, and no
GameCube gameplay or Steam Deck performance claim has been validated yet.

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

The core supports the host's OpenGL path. The current source requires at least
CMake 3.25 and GCC 12 (or Clang 15), exceeding the existing Ubuntu 22.04 build
image's default toolchain. Its recursive source dependencies must be pinned,
archived and licensed before extending the release-core builder. Keep the
existing release cores on their current toolchain until the Dolphin build is
proven compatible with the Deck and both export targets.

Dolphin expects `<system>/dolphin-emu/Sys` and `<save>/User`. CRT XR currently
supplies the same writable directory for system and save files, so the support
helper stages only Sys into `saves/gamecube/dolphin/dolphin-emu/Sys` and leaves
`saves/gamecube/dolphin/User` alone. Packaged data will come from
`core-data/dolphin-emu/Sys` beside the application. For development only,
`CRT_XR_DOLPHIN_SYS` may point at the pinned checkout's `Data/Sys` directory.
This data includes redistributable replacement fonts and DSP data, whose
licences must accompany the eventual package. A console BIOS is not required.

## Remaining before enabling by default

1. Produce pinned Linux and Windows core builds, complete dependency/source
   archives and licences, and include Sys in exports and package manifests.
2. Boot an original GameCube homebrew probe through the native host. Verify
   callbacks on Dolphin's CPU/GPU threads: the host currently uses a thread-local
   active instance and cannot assume callbacks stay on the calling thread.
3. Verify frame pacing, audio, analog trigger half/full presses, C-stick,
   reset, disc switching, memory-card persistence and save-state round trips.
4. Benchmark real gameplay on the Deck with the CRT room enabled, including
   cold/warm shader cache runs. Compare synchronous and hybrid ubershaders;
   do not trade correctness for a presumed performance gain.
5. Remove the development opt-in only after runtime and packaging checks pass.

Foundation checks: run Godot with `--headless --path . --script tests/gamecube.gd`
once without the environment opt-in and once with it. The tests use generated
header/data fixtures; they do not establish that Dolphin boots or renders.
