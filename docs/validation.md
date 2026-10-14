# Validation — 14 October 2026

## Completed

* Imported and compiled all GDScript in Godot 4.5.1 official (f62fdbde1).
* Started the application headlessly on Windows.
* Started and rendered the application on Windows with OpenGL 3.3 compatibility
  on an NVIDIA RTX 4080. Inspected desktop and side-by-side snapshots.
* All 13 scene checks passed both headlessly and with the Windows GPU renderer:
  physical IPD, parallel axes, convergence plane zero disparity, no vertical
  disparity, near-object disparity sign, simulated camera rotation, stationary
  TV transform, rotated eye separation, recentering, centered mono camera,
  distance adjustment, scale adjustment and animated signal pause.
* Exported a native Linux x86-64 release using official matching Godot templates.
  Output: `dist/linux/retrocrt.x86_64`, `retrocrt.pck`, `launch-deck.sh`.
* Started that exported release headlessly in WSL Ubuntu; it reported
  `RetroCRT ready / Godot 4.5.1-stable (official) / Linux` and exited successfully.
* Validated both Linux shell scripts with `bash -n`, confirmed the exported
  executable is an x86-64 Linux ELF, and started it through the packaged launcher.
* Built the native inventory utility in the Ubuntu 22.04 Docker environment using
  GNU C++ 11.4 and CMake, with warnings treated as errors. Ran it in WSL: it
  reported missing driver resources and returned the expected status 2.
  No driver IPC resources were created.
* Transferred the package to the Steam Deck and verified executable/PCK SHA-256
  hashes. Native startup and graphical rendering succeeded in KDE Desktop Mode
  on SteamOS 3.8.28 using the Deck AMD GPU and Mesa 26.1.2.
* All 13 scene checks also passed against the exported application on the Deck.
  Captured and visually inspected `docs/deck-preview.png` from the Deck renderer.
  This brief capture does not establish sustained frame rate or tracking latency.
* Built and passed 19 native reader safety checks in private test-owned IPC
  resources, including stale timestamps, invalid quaternions, wrong segment
  sizes, missing paths, disabled/reconnected samples, bounded lock contention,
  coordinate conversion and robust-mutex owner death without lock repair.
* With user approval, enabled the existing driver's `disabled` setting to false,
  preserving `external_mode=none`. VITURE Pro 2 reported CALIBRATED.
* Live bridge probe received 999 fresh packets over five seconds (about 200 Hz).
* Live end-to-end Deck check passed: advancing driver sequences reach Godot's
  camera quaternion and the television's world transform stays fixed.
* The tracking build rendered on the Deck and reported LIVE 3DoF. Screenshot:
  `deck-tracking-preview.png`. User reported stereo depth in the original build
  after enabling SBS and disabling the built-in display.
* The user then confirmed the head-tracked build looks great in SBS.
* Built the Libretro GDExtension and actual Snes9x core for Windows and Linux.
  Native host checks passed for pixel formats, padded rows, duplicate frames,
  stereo PCM callbacks, input, state round-trip and SRAM. The actual core runs
  an original diagnostic cartridge and responds to joypad input.
* Windows headless and GPU application checks passed for game loading, framebuffer
  binding to the CRT, pause, quick states, input, SRAM persistence and reloading.
* The exported Linux package passed those application checks headlessly in WSL.
* The Windows GPU fade test passed: all four edges of each eye are black and
  the centre remains visible. Captured `build/edge-fade-preview.png` was inspected.
* The seamless build was installed separately on the Deck. Super Mario World
  runs with live tracking in a verified 3840x1080 SBS window at scale 1. The
  launcher disabled the internal screen and recovered it in a supervised-exit
  test. The user reported that Mario looked amazing through the glasses.
* Two software SBS requests failed in the installed VITURE SDK 2.4.0. The
  desktop shortcut therefore retains the physical-button fallback. Driver/plugin
  binaries and persistent driver settings were preserved.
* The subsequent 3.4 m viewing default and adjustable physical screen/glass
  curvature were implemented and rendered locally after the Deck was switched
  off. Those latest viewing changes have not been deployed.

## Reproduce

```powershell
./scripts/dev.ps1 -Test
./scripts/dev.ps1 -EmulationTest
./scripts/export-linux.ps1
```

For rendered checks, invoke the bundled Godot executable with `--path . --script
res://tests/smoke.gd`. For images, run it with `--path . -- --capture` and optionally
`--sbs`. A snapshot is saved to `build/preview.png`; the app then exits.

## User-supplied game check — 14 October 2026

Super Mario World (Europe, Rev 1), copied from the user's network share into
ignored `build/roms`, booted locally with Snes9x at 50.007 PAL frames/sec and
256x224 output. GPU captures confirmed the title/file menu and new-game intro
on the curved CRT. Injected keyboard Start presses reached file selection and
started a new game. Godot audio playback was active and the core produced 640
audio frames per checked batch; audible sound was not independently assessed.
The approximately 15-second run reported zero slow-frame events and zero audio
overflow batches. This is a short Windows check, not a Deck performance result.
The ROM is excluded from the distributable Linux package.

The CRT/glass update passed the 13 scene checks and 17 Windows GPU emulation
checks. Mono/SBS rendered previews were inspected, including a frozen-frame
glass-off/on comparison. See [CRT rendering](crt-rendering.md). Deck performance,
pattern stability through the glasses and reflection strength still need testing.

## Not yet validated

The local seamless-setup update adds a KDE glasses-session supervisor, per-eye
settings and ROM browser, controller navigation and a last-game shortcut.
Ten mocked display/recovery tests, five SBS-adapter checks and 12 Windows GPU
menu/controller checks pass. The 13 scene checks and 17 GPU emulation checks
remain passing. KScreen output, EDID identity, mode/scaling changes and supervised
exit recovery were exercised on the Deck. Physical-disconnect recovery and the
latest local curvature/default-distance update remain pending. See
[display setup](display-setup.md).

* Steam Input navigation, fullscreen monitor selection, Gaming Mode and
  performance/latency under sustained load.
* VITURE Pro 2 output mode, actual eye ordering, optical FOV, comfort, IPD and
  convergence calibration. Desktop disparity checks cannot establish optical comfort.
* Perceptual axis directions, field-of-view calibration and physical device
  disconnect/reconnect. The inspected binary's consumed layout is pinned;
  other driver versions are rejected until checked.
* Gaming Mode interference from XR Gaming, Gamescope or ReShade. No plugin
  binaries were changed; the driver enable setting was changed with approval.
* Audible game audio, physical Deck controller input and sustained emulation performance.
  The diagnostic cartridge and the user's Super Mario World ROM have been used
  for local emulator testing.

The user has accepted the head-tracked SBS game experience. The latest local
viewing adjustments still require their next hardware test.
