# Input latency update — 14 October 2026

The application now disables input-event accumulation, flushes pending events
immediately before executing the emulated frames and runs emulation after the
ordinary scene/UI callbacks. These changes avoid an unnecessary input queue;
they do not measure physical controller or display latency.

**Reduce input delay** offers **Off, 1 frame (default) or 2 frames** in
settings. After the real game frames and their audio have been processed, the
emulator snapshots its state and SRAM, executes the selected number of
additional frames for the picture, and restores the snapshot and SRAM. The
preview audio is discarded. Game time and saves advance only through real
frames. No preview snapshots are written to disk. This is the
[run-ahead technique](https://docs.libretro.com/guides/runahead/); two frames
costs about twice the preview work. A saved boolean setting migrates to
Off or 1 frame on first start.

A core that cannot serialize disables preview. A failed restoration pauses
emulation and reports that the game needs reloading with preview disabled.
VSync, display refresh, shaders and graphics quality are unchanged by this update.

## Measured results

On the user's Deck with Snes9x 1.63:

| Check | Result |
| --- | --- |
| Deliberately delayed original CC0 diagnostic ROM | Visible response advances from frame 2 to frame 1 |
| Diagnostic and Super Mario World, 100 previews each | Serialized state and SRAM remain byte-identical to the committed frame |
| Preview work per game frame | Diagnostic 1.63 ms average; Mario 2.12 ms average |
| Full stereo baseline, 1920×1080 per eye | 59.98 fps; 95th-percentile frame time 17.00 ms |
| Full stereo with preview | 60.00 fps; 95th-percentile frame time 16.94 ms |
| Both measured 240-frame stereo sections | Zero missed emulation-frame events and zero audio overflows |

One audio overflow occurred during initial startup/warmup before the measured
sections. These are short offscreen stereo comparisons, not a long-session or
optical latency measurement. The PAL Mario copy runs at 50.007 game frames per
second on the 60 Hz presentation loop; one game frame is approximately 20 ms.
The diagnostic verifies the technique's one-frame benefit, not a measured
20 ms improvement from the Deck's physical button to the glasses.

The committed-audio comparison uses two identical baseline runs followed by
480 frames with preview. On Windows and the Deck, all 480 audio batches match
exactly in their respective comparisons.

## Reproduce

Generate the intentionally delayed fixture:
`python tests/make_probe_rom.py build/retrocrt-latency-probe.sfc --input-delay`.
Then run `tests/input_latency.gd` with Godot. For a supplied ROM, use
`-- --rom /absolute/path/game.sfc`; add `--probe` only for the delayed fixture.

`tests/stereo_performance.gd` renders the real scene into a 3840×1080 offscreen
viewport and compares preview off/on. It does not change the monitor layout.
Use isolated `XDG_DATA_HOME` for Deck test runs so production saves are untouched.

`python tests/preview_audio_test.py CORE_LIBRARY ROM SAVE_DIRECTORY` checks
committed audio through the actual Libretro API without external Python packages.

The Steam entry now targets `~/Applications/RetroCRT/latency-20261014/`.
The prior `scene-lighting-20261014` build remains available for rollback.
