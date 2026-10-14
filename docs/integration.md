# Integration decisions — 14 October 2026

## Smallest working architecture

Godot 4.5.1 compatibility renderer, GDScript world construction, two SubViewports
sharing one World3D, and a Camera3D in each. Cameras use parallel axes and
opposite near-plane shifts. Eye positions rotate with the head; the television
does not. Convergence is independently adjustable. A 256x240 animated content
viewport supplies the curved 4:3 screen through a nearest-filtered shader.

Tracking is isolated behind `TrackingProvider`: normalized Godot local-to-world
quaternion, validity, receipt time and diagnostic status. Simulation works on
both desktop platforms. `xr_linux_tracking.gd` now launches an attach-only native
helper and consumes Godot-space quaternions over loopback UDP. It checks the
installed driver's SHA-256 against the inspected binary. See the
[current tracking implementation](head-tracking.md) for tested scope.

## Upstream inspection and installed-version gate

The following upstream files were inspected for this pass. Their branches are
moving references; none establishes the version actually installed on the Deck.
No source from these projects is vendored in this prototype.

* [XRLinuxDriver ipc.h](https://github.com/wheaney/XRLinuxDriver/blob/main/include/ipc.h)
  and [ipc.c](https://github.com/wheaney/XRLinuxDriver/blob/main/src/ipc.c): System V
  segments use `ftok(path, 0)` under `/tmp/shader_runtime_`. Orientation allocates
  16 floats; its mutex is a separate process-shared robust pthread object.
  Setup can destroy/reinitialize the mutex and create/delete segments. Never
  call that setup from the reader.
* [outputs.c](https://github.com/wheaney/XRLinuxDriver/blob/main/src/outputs.c):
  writes orientation under that mutex; keepalive uses a calendar float4, not a
  monotonic sample timestamp. Data begins with quaternion x/y/z/w but contains
  buffered history and timestamps. It must not be treated as a 4x4 pose matrix.
* [XR Gaming index.tsx](https://github.com/wheaney/decky-XRGaming/blob/main/src/index.tsx)
  exposes SBS content/stretch settings and feature/state checks.
  [main.py](https://github.com/wheaney/decky-XRGaming/blob/main/main.py) checks a
  Breezy manifest checksum and installed plugin version. Those are useful
  identifiers to record on the Deck; the app must not invoke install/reset methods.
* [Breezy submodules](https://github.com/wheaney/breezy-desktop/blob/main/.gitmodules)
  identify the XRLinuxDriver and vkBasalt runtime-uniform dependencies.
  Its [README](https://github.com/wheaney/breezy-desktop) describes the Vulkan
  presentation path. Detailed installed compositor behavior still requires Deck inspection.
* [godot-cpp-template registration](https://github.com/godotengine/godot-cpp-template/blob/main/src/register_types.cpp)
  and [CMake](https://github.com/godotengine/godot-cpp-template/blob/main/CMakeLists.txt)
  provide the scene-level class-registration pattern for a future bridge. No
  GDExtension dependency is needed for Milestone 1.
* [Snes9x Libretro implementation](https://github.com/snes9xgit/snes9x/blob/master/libretro/libretro.cpp)
  exposes `retro_run` with input polling and frame execution. A native in-process
  host now implements those callbacks, framebuffer conversion, audio, core
  lifecycle, SRAM and serialization; see [emulation notes](emulation.md).

## Reader safety requirements and installed profile

The [Deck inspection](steamdeck-inspection.md) records the installed plugin
version, Breezy manifest checksum and driver binary hash. A matching source
commit was not available; the installed shader and producer disassembly
established the consumed layout for this pinned binary profile. On Deck,
inspect those files through existing user access without changing installation
state. The inventory utility can establish segment presence and sizes, not ABI
compatibility. Its output includes the locally compiled pthread mutex size.

The bridge must use `stat`, `ftok`, `shmget` without IPC_CREAT, `shmctl(IPC_STAT)`
for exact expected sizes/ownership, and `shmat`. Orientation can map read-only;
mutex acquisition requires a writable mapping. Bound the wait via trylock or
timedlock, copy to private storage under lock, then unlock. Never initialize,
destroy, remove or repair driver resources. On owner death, stop sampling and
detach rather than attempting recovery; robust-mutex failure handling must be
designed explicitly to avoid damaging the producer's lock state.

Reject nonfinite/near-zero quaternions, validate normalization and clock rules,
and expire samples using locally observed sample-sequence/timestamp progress.
Do not classify an unmoving orientation as stale. Keepalive alone is insufficient.
Handle producer restart/segment replacement, permission failure and disconnect
with explicit status and bounded reconnection. Freeze the last valid pose with
a visible warning, then offer simulation; do not silently jump between providers.

Do not infer axis conversion from variable names. Compare identity and positive
yaw/pitch/roll against the installed producer and apply a verified basis change
to Godot (+X right, +Y up, forward -Z). Recenter remains a local quaternion offset;
do not send a global driver recenter command. Smoothing is optional and defaults off.

## Presentation comparison

| Path | Ownership | Decision |
|---|---|---|
| Direct Full-SBS | Godot owns both eye cameras and tracking orientation | Primary path; no OpenXR runtime required |
| XR Gaming Content is 3D | Plugin can place an SBS image within its tracked virtual display | Possible alternative if the app's pose is disabled; adds another presentation transform |

The plugin's [documented SBS controls](https://github.com/wheaney/decky-XRGaming#decky-controls)
include feature restrictions. Availability in the installed testing build is
unknown. Direct output does not depend on those controls, but a supported method
of putting the glasses into Full-SBS mode is still required. No feature bypass
or direct hardware access is implemented.

OpenGL avoids application-level Vulkan injection, but Gamescope/ReShade or input
translation may still apply. Verify one orientation owner on Deck. Disabling a
plugin mode can also affect IPC production, so do not prescribe a global driver
disable before checking that build. The launcher changes no plugin configuration.
