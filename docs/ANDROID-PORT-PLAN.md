# Android port plan

Status, 28 October 2026: groundwork started on the `android-port` branch.

- **Phase 1 done:** `scripts/platform/platform.gd`, all call sites migrated,
  the `check-repository.py` rule, and `tests/platform_paths.gd`.
- **Phase 2 partly done:** `Dockerfile.android`, the Android CMake branch and
  `.gdextension` entry. The extension builds for arm64.
- **Android export preset and a debug APK export** (`scripts/build-android.sh`).

Not yet started: Android cores, the plugin, and anything on a device. See
[development](DEVELOPMENT.md#android-preview-groundwork).

## Goal and scope

Ship an **arm64 Android** build of CRT XR from the same repository, tag and
Godot project as the Steam Deck, Windows and Linux desktop builds, with:

1. Mono play on the device's own screen (games, videos, music, the room).
2. **Side-by-side output** to XR glasses connected by USB-C (DisplayPort Alt Mode).
3. **3DoF head tracking**, through the glasses' own IMU wherever we can reach it.

The Steam Deck stays the lead platform and controller-first stays the design rule.
Android is a peer of Windows: same features where the platform allows, clearly
labelled gaps where it does not, and no Android-only forks of shared code.

**Out of scope for this plan:** standalone OpenXR headsets (Quest, Pico, Android XR
headsets), touch-first phone play, 32-bit ARM, x86 Android, and the Play Store as
the first channel. Each could follow, and nothing below rules them out.

### Reference hardware

Pick one **reference device** before any code is written and treat it the way the
Deck is treated now. The best match for this app's audience is an Android retro
handheld with built-in controls and DisplayPort Alt Mode on its USB-C port
(Retroid Pocket 5 / Mini, AYN Odin 2 / Thor, AYANEO Pocket class: Snapdragon 8 Gen 2
or similar, Adreno GPU). A recent DP-capable phone (Galaxy S or Pixel 8+ class) with
a Bluetooth controller is the second target. The tested glasses remain the
**VITURE Pro 2**.

Minimum Android version: **10 (API 29)**. That gives mature multi-display APIs and
lets the plan assume scoped storage everywhere.

## What the codebase already gives us

| Area | Current state | Android impact |
|---|---|---|
| Engine | Godot 4.5.1, Compatibility (GLES3) renderer, `renderer/rendering_method.mobile` already set to `gl_compatibility` | Godot's Android export supports this renderer directly. |
| Stereo | Two `SubViewport`s sharing one `World3D`, an off-axis `Camera3D` per eye (`scripts/main.gd`) | Portable as is. Needs a half-SBS layout and Android display handling (Phase 4). |
| Tracking | `TrackingProvider` contract: Godot-space quaternion, validity, sample time, angular velocity; prediction, recentring and inversion are already provider-independent | New providers drop in. The 300 ms staleness and freeze-on-loss rules carry over unchanged. |
| Native host | GDExtension `crt_xr_libretro` (libretro host, MP3 radio, FFmpeg video), CMake + godot-cpp, `dlopen`s cores and FFmpeg | Needs an Android NDK build. The `dlopen` design suits Android well. |
| Cores | Ten cores built from pinned sources by `build-release-cores.py`, provenance in `cores/core-builds.json` | Need an `android-arm64` target in the same script. Most of these cores already have upstream Android makefiles. |
| Tracking helpers | Separate processes (`crt-xr-tracking-bridge`, `crt-xr-windows-tracking.exe`) launched with `OS.create_process`, talking over loopback UDP | `OS.create_process` is unavailable on Android, so tracking must run in-process (Phase 5). |
| Paths | About 25 `OS.get_name()` checks and repeated `OS.get_executable_path().get_base_dir()` asset lookups | Android has no executable folder. This is the main refactor (Phase 1). |
| Video | FFmpeg 7.1/8 loaded at runtime (system on Linux, downloaded on Windows) | Android has no system FFmpeg. Bundle an LGPL arm64 build (Phase 6). |
| Textures | `cabinet_brand.gd` compresses to BPTC in the editor | Most mobile GPUs lack BPTC. Enable ETC2/ASTC import. |

## Architecture decisions

### D1. One project, one export preset more

Add `[preset.2] name="Android"` to `export_presets.cfg` with the same
`exclude_filter` as the desktop presets, `arm64-v8a` only, **Gradle build enabled**
(required for the plugin in D2), immersive mode, landscape orientation, keep-screen-on
and the `crt_xr_android` custom feature tag. Godot's Android export templates join
`scripts/setup-export-templates.ps1`, pinned to 4.5.1 like the desktop templates.

### D2. A small Android plugin, not a fork of Godot's template

Create `android/plugin/` as a **Godot Android plugin (v2, AAR)** built by Gradle,
with an `EditorExportPlugin` in `addons/crt_xr_android/` that adds it to the export.
It carries:

- **The libretro cores** as `jniLibs/arm64-v8a/lib<core>_libretro.so`. Packaging
  them as APK native libraries means they are mapped from the APK's library folder,
  follow Android's W^X rules and need no copying at runtime. Cores are never
  downloaded at runtime.
- **The FFmpeg shared libraries** (Phase 6), packaged the same way.
- **Kotlin glue** for what GDScript cannot reach: USB device enumeration and
  permission prompts, the USB file descriptor handoff to native tracking, display
  enumeration, moving the activity to an external display, "All files access"
  settings intents, and the rotation-vector sensor.

Everything performance-sensitive stays in C++. Kotlin only brokers Android APIs and
hands file descriptors or small values to the GDExtension through the plugin's
`@UsedByGodot` methods and signals.

### D3. A platform layer instead of scattered OS checks

Introduce `scripts/platform/platform.gd` (static, `class_name Platform`) that
answers **capability questions**, not OS names:

```gdscript
static func app_asset_dir() -> String         # exe dir, res://build/... in editor, res:// on Android
static func core_library(core: String) -> String  # ".../cores/x_libretro.so|.dll" or "libx_libretro.so"
static func can_spawn_processes() -> bool
static func has_drive_list() -> bool          # Windows only
static func video_backend() -> String         # "system", "downloaded", "bundled"
static func storage_model() -> String         # "posix", "windows", "android_all_files"
static func default_library_roots() -> PackedStringArray
static func sbs_presentation() -> String      # "window_move" (Windows), "gamescope" (Deck), "android_display"
```

Every existing `OS.get_name()` / executable-path call site moves behind it, with no
behaviour change on desktop. `Platform` takes an override (a `--platform-override`
user argument, honoured only in tests and the editor) so Android path and capability
logic is exercised by the existing headless suites on Windows and Linux.

`scripts/check-repository.py` gains a rule: **no `OS.get_name()` and no
`get_executable_path()` outside `scripts/platform/`**. That rule is the main
long-term maintenance guard. Without it, the next desktop feature quietly breaks
Android.

### D4. Tracking runs in-process on Android

Desktop keeps its sidecar helpers. On Android, a native `CrtXrAndroidTracker`
class inside the GDExtension runs a reader thread and exposes the latest sample
(quaternion, driver timestamp, sequence) through a lock-free slot that the GDScript
provider polls each frame. The GDScript side, `scripts/tracking/android_tracking.gd`,
extends `TrackingProvider` and applies the same validation, staleness, reconnect
rebasing and recovery rules as `xr_linux_tracking.gd`. The shared parts move into
a common base so the two do not drift.

### D5. Android-only capabilities degrade visibly, never silently

Where a feature has no Android equivalent (Computer drives, the FFmpeg download,
Gaming Mode SBS handoff, the Windows display picker), its menu entry is hidden or
replaced through `Platform`, and the help text says why. The rule matches how
monitor-only play is handled today.

## Phases

Each phase ends with a usable, testable state and leaves desktop green. The
estimates assume the project's current pace: one developer with AI assistance,
which took the desktop app from first architecture to beta.14 in about two to
three weeks of October 2026. Software-only work scales with that pace;
hardware-dependent work (display output, USB protocols, on-device acceptance)
does not, and dominates the schedule.

### Phase 0 — Feasibility spike (2–3 days, once the device is in hand)

Export the current project to the reference device with emulation stubbed
(extension not loaded) and the room, TV and test signal showing.

- Measure frame time in mono and in SBS at 1920×1080 and 3840×1080 render sizes,
  using the existing `tests/live_crt_performance.gd` scene where possible.
- Note thermals after 30 minutes and any shader compile or precision faults on
  Adreno or Mali (mediump defaults, `highp` needs in the CRT passes).
- Check what the device outputs over USB-C with the VITURE Pro 2 attached:
  mirrored or extended, the resolutions offered, and whether the glasses' SBS
  button produces a 3840×1080 mode or a stretched 1920×1080 one.

**Gate:** 60 fps mono at native resolution and at least a stable 60 fps in SBS
with a reduced render scale. If SBS cannot hold 60 fps, Phase 7's quality tiers move
ahead of Phase 4.

### Phase 1 — Platform layer (2–3 days, desktop only; can start before Phase 0)

- Implement `Platform` (D3) and migrate every call site: `core_registry.gd`,
  `imported_crt.gd`, `imported_table.gd`, `cabinet_plastic.gd`, `console_prop.gd`,
  `room_contacts.gd`, `box_art.gd`, `rom_library.gd`, `rom_locations.gd`,
  `menu_*.gd`, `ffmpeg_installer.gd`, `main.gd` and the tracking providers.
- On Android, prepared models and bakes (cabinet, table, AO, room bake) load from
  `res://` inside the PCK. The Android preset's `include_filter` adds the prepared
  `build/` outputs. Desktop keeps loading them from beside the executable, so
  licensed-asset handling and `check-release-assets.py` stay as they are. Add an
  Android branch to that check.
- Enable `rendering/textures/vram_compression/import_etc2_astc=true`. Make
  `cabinet_brand.gd` pick ASTC/ETC2 when BPTC is unsupported at runtime, not only
  based on the editor feature.
- Add the repository lint rule. Add `tests/platform_paths.gd` covering each
  platform override.

**Exit:** all existing suites pass on Windows and Linux with no visible change.

### Phase 2 — Native toolchain for arm64 (3–5 days; core build failures are the variable)

- **Build image.** Extend `Dockerfile.emulation` (or add `Dockerfile.android`) with
  a pinned Android NDK (r27 LTS or the one matching Godot 4.5.1's templates), CMake,
  JDK 17, the Android SDK command-line tools, and the build-tools/platform matching
  the Play target API. Pin every version in the Dockerfile, as the current images do.
- **Extension.** `native/emulation/CMakeLists.txt` gains an Android branch:
  `OS_NAME android`, arch `arm64`, output
  `extensions/bin/libcrt_xr_libretro.android.arm64.so`, `c++_static`, `-Wl,-z,max-page-size=16384`
  (needed for 16 KB page-size devices). `crt_xr.gdextension` gains
  `android.arm64 = "res://extensions/bin/libcrt_xr_libretro.android.arm64.so"`.
  The Linux-only locale-facet workaround (the separate `crt-xr-engine` process) does
  not apply: Android uses libc++, each core links its own C++ runtime statically,
  and only the C libretro ABI crosses library boundaries.
- **Cores.** `build-release-cores.py` gains an `android-arm64` target that builds
  each pinned commit with its upstream Android route (`jni/Android.mk` via
  `ndk-build`, or `make platform=unix` with the NDK toolchain, or mGBA's CMake).
  It records the source archive, compiler and flags per binary, as it does now, so
  `core-builds.json` and `check-core-sources.py` cover every target. A core whose
  Android build fails blocks only that system: `core_registry.gd` already hides
  systems without a core.
- **libretro host differences.** Audit `libretro_host.cpp` for the environment
  calls that matter on Android: system and save directories become paths under
  the app's internal files dir; `RETRO_ENVIRONMENT_GET_LIBRETRO_PATH` (if any core
  uses it) returns the library name. No core in the set needs a hardware-rendered
  context, which avoids the hardest Android emulator problem.
- **Native tests on device.** Build `crt-xr-host-test` and `crt-xr-video-test` as
  arm64 executables. Run them through `adb push` to `/data/local/tmp` and
  `adb shell`, which allows executables. Add `scripts/test-android-native.py`.

**Exit:** the host test passes on the reference device against all ten Android cores.

### Phase 3 — Android shell and mono play (about 1 week) → first sideload alpha

- **Plugin skeleton** (D2) with the cores in `jniLibs`. `Platform.core_library()`
  returns the bare soname (`libsnes9x_libretro.so`) so `dlopen` resolves it in the
  app's library namespace.
- **Storage.**
  - The ROM, music and video browsers use POSIX paths, so request
    **All files access** (`MANAGE_EXTERNAL_STORAGE`) through the plugin's settings
    intent, with a clear first-run explanation and a re-request path in Library
    locations. This is how Android retro frontends handle large ROM libraries, and
    it keeps `rom_index.gd`'s `DirAccess` scanning, ZIP reading and Sega CD
    cue/CHD logic unchanged.
  - Default roots: `/storage/emulated/0/ROMs` (the ES-DE for Android and handheld
    convention), plus mounted SD cards listed from `/storage/` (the Android
    replacement for Computer drives).
  - Box art: add `<shared storage>/ES-DE/downloaded_media` and the ES-DE Android
    media path to `box_art.gd`'s candidates.
  - BIOS: the existing `bios` folder beside `roms` works unchanged. Add the app's
    external files folder (`Android/data/<id>/files/bios`) as the documented
    fallback.
- **User data.** `user://` lives in internal app storage, and uninstalling the app
  wipes it. Add **Back up saves & settings** and **Restore** actions that write and
  read a single archive in shared storage (`Documents/CRT XR/`). The same action is
  useful on the Deck and Windows, so build it shared. Set `android:allowBackup`
  deliberately, and exclude the shader cache and logs.
- **Lifecycle.** On `NOTIFICATION_APPLICATION_PAUSED`: pause emulation and
  video, write the automatic resume point, stop audio streams and release the
  tracking device. On resume, re-acquire them and recentre on the first fresh pose.
  The Android OS can kill a backgrounded app at any time, so the resume point must
  be written on pause, not only on quit.
- **Input.**
  - Built-in handheld controls and Bluetooth/USB pads arrive as Godot joypads.
    Verify the face-button positional mapping on the reference device, since some
    Android handhelds swap A/B in firmware, and add the device to the controller
    help page.
  - Map the Android **Back** button to the menu's back action and turn off
    `quit_on_go_back`. Keep L1 + R1 + Start as the menu chord.
  - Touch: tapping opens the menu and the menu accepts taps. No on-screen gamepad
    in this plan; a controller is required, as on the Deck.
- **Audio.** Measure the game-audio latency of Godot's Android audio driver on the
  reference device. The existing input-preview (run-ahead) option and
  `tv_audio.gd`'s buffering may need an Android default.
- **Network.** Check that `HTTPClient` radio streams over plain `http://` are
  allowed, and add a network security config permitting cleartext for user-entered
  stream URLs if needed.
- **Packaging.** `package-beta.py` gains an `android` target that produces
  `CRT-XR-<version>-Android.apk` plus `HOW TO INSTALL ANDROID.txt`, and asserts
  the APK contains the extension, all ten cores, the expected permissions and the
  version code. The version code is derived from the version string so it always
  increases, for example `0.1.0-beta.14.1` → `0001014141`; define the scheme
  once in a script, not by hand.
- **Signing.** Generate one release keystore, store it off the build machine and
  in a password manager, and never commit it. Android refuses updates signed with
  a different key, so losing it strands every installed user.

**Exit (alpha):** sideloaded APK on the reference device. Browse an SD card, play
all systems in mono, save and load states, play music, survive pause and resume.

### Phase 4 — SBS output to glasses (about 1 week, mostly on-device testing)

Android does not let an app open a second window on another display the way
Windows does. There are two practical routes, and both should be supported.

**4a. Mirrored output (works on every DP Alt Mode device).** The glasses show the
device's own screen. CRT XR renders SBS into its normal fullscreen window.

- Add a **half-SBS layout**: each eye renders at full height and half the width of
  the output and is horizontally squeezed. Glasses in their 3D mode stretch it back.
  This is a **shared feature**. It also helps Windows/Linux users whose glasses or
  ports only accept 1920×1080, so build it in `main.gd`'s existing viewport layout
  with a `display/sbs_layout` setting (`full`, `half`), not as Android code.
- Detect the active mode from `DisplayServer.screen_get_size()`. A 32:9 surface
  means full SBS. With 16:9, offer half SBS. Do not guess from the panel resolution.
- Handhelds whose panel is not 16:9 (for example 4:3 or 20:9) mirror with
  letterboxing. Render the SBS frame at the external display's aspect, not the panel's.

**4b. Extended output (devices with desktop or extended display support).** Where
Android reports the glasses as a separate `Display` (Samsung DeX, Android 15+
desktop-mode devices, handheld vendor options), the plugin relaunches CRT XR's
activity on that display with `ActivityOptions.setLaunchDisplayId()`. Godot then
renders natively at the glasses' resolution, including 3840×1080 full SBS, and the
device screen is free.

- Reuse the Windows launch flow's ideas: curtain to black, wait for a stable,
  plausible SBS mode, then reveal. `windows_setup.gd` and `startup_status.gd`
  become platform-neutral where possible.
- Moving the activity recreates its surface. Confirm the GL context and
  `SubViewport`s survive or are rebuilt cleanly, and test it repeatedly.

The menu, the SBS prompt and the exit flow (`sbs_prompt.gd`, `sbs_exit.gd`) must
work per-eye on Android, because no desktop monitor is available to fall back on.

**Exit:** the VITURE Pro 2 shows a correct, comfortable full-SBS room through
route 4a or 4b on the reference device, and half SBS on a 1080p-only phone.

### Phase 5 — Head tracking (1–2 weeks to VITURE tracking, staged; the least predictable phase)

Ordered from cheapest to most valuable. Each stage stands alone.

**5a. OpenTrack UDP (about a day).** `opentrack_tracking.gd` already works with Godot's
`PacketPeerUDP`, so enable it on Android unchanged. Any app on the device, or a PC on
the LAN, that sends OpenTrack packets drives the view. Add an explicit opt-in to
bind `0.0.0.0` for LAN sources and keep loopback as the default.

**5b. Device sensors (1–2 days).** A `PhoneSensorTracking` provider uses the
Android **game rotation vector** sensor (through the plugin, since Godot's raw
gyroscope access does not give a fused orientation), remapped for landscape. Its
main uses are a phone in a Cardboard-style viewer and testing the Android tracking
chain without glasses. It cannot track glasses while the device sits in your hands,
so the UI labels it accordingly.

**5c. Glasses IMU over USB (a few days for VITURE through its official SDK;
about 1 week per other vendor protocol).** This is the feature that matters.
Waiting on a vendor's licence answer can take longer than the code.

There are two routes. VITURE glasses go through VITURE's own SDK. Other brands go
through our own USB reader.

**VITURE through the official SDK.** As of October 2026, VITURE publishes an
official C glasses SDK for **Android `arm64-v8a`** (and `armeabi-v7a`), alongside
Windows, Linux and macOS. It ships as `libglasses.so` plus headers, with an Android
integration guide, and handles USB device management and head tracking. VITURE's
model table lists 3DoF for every model, including the **Pro 2**.
See the [VITURE glasses SDK page](https://www.viture.com/en-MY/developer/glasses-sdk/glasses).

- It appears to be the same C SDK family the Windows helper (`native/windows_tracking/bridge.cpp`)
  already uses. Confirm that against the Android package. If it is, reuse the
  Windows helper's device matching, pose-rate selection and verified axis mapping
  (yaw = yaw, pitch = −pitch, roll = −roll, Y·X·Z). Port its callback handling into
  the in-process tracker (D4); the callback must only write the lock-free sample
  slot and never call into the engine, as on Windows.
- Follow the SDK's Android integration guide for USB permission and device
  opening. If it expects the app to supply a `UsbDeviceConnection` file descriptor,
  the plugin's USB code below provides it.
- Ship `libglasses.so` in the plugin's `jniLibs`, **only if VITURE's licence allows
  redistribution in an APK**. The SDK page shows only "Copyright (C) 2026 Viture
  Inc. All rights reserved." and no redistribution terms. Users cannot easily place
  a vendor `.so` beside an Android app as they do on Windows, so a
  "bring your own SDK" route is unrealistic. Ask VITURE for written terms
  **before Phase 2**, and record the answer in `docs/CORE-DISTRIBUTION.md` beside
  the other third-party binaries.
- Keep the SDK's usage reporting off, as the Windows helper does. It is opt-in and
  needs credentials issued by VITURE.
- **SpaceWalker conflict.** VITURE's SpaceWalker app takes over the glasses' motion
  sensor while it is open. The third-party `viture_kit` wrapper documents this.
  It's the same conflict the Windows setup guide already covers. Detect a stalled
  stream and show "Close SpaceWalker" in the tracking status, rather than a generic
  failure.
- If redistribution is refused, fall back to our own decoder for VITURE's HID
  reports through the reader below. That adds about a week, and protocol fixtures
  then matter more.

**Our own USB reader (XREAL, Rokid, RayNeo, and VITURE as a fallback).**

- **USB access.** The plugin lists USB devices from `UsbManager`, matches known
  vendor and product IDs (from a shared table that the desktop name recognition can
  also use), requests permission (one system dialog, which can be remembered through
  a `USB_DEVICE_ATTACHED` intent filter and `device_filter.xml`), opens the device
  and passes its **file descriptor** to native code.
- **Native reader.** Bundle **libusb** (LGPL-2.1, shipped as its own shared library)
  in the GDExtension with `LIBUSB_OPTION_NO_DEVICE_DISCOVERY` and
  `libusb_wrap_sys_device(fd)`, then claim the IMU HID interface and read interrupt
  reports on a thread. This is the documented libusb route for unrooted Android.
- **Protocols, after VITURE:** **XREAL** Air/One, then **Rokid** and **RayNeo**.
  Community drivers document these protocols. Check whether XREAL's SDK offers a
  plain C library like VITURE's before writing a reader; its published SDK has
  been aimed at app frameworks rather than native libraries. XRLinuxDriver and
  other community drivers are not MIT, so check each licence before reading or
  adapting code. To keep CRT XR's own source MIT, write each decoder from protocol
  documentation, or keep an adapted decoder in its own separately licensed library,
  as the Nestopia combination is handled now.
- **Same safety rules as the Deck.** Reject non-finite or near-zero quaternions,
  require advancing timestamps before going LIVE, expire after 300 ms, freeze with
  visible status on loss, rebase on reconnect, and never send vendor recentre or
  mode commands unless deliberately decided and documented. Switching the glasses'
  SBS mode over USB stays out of scope until it is proven safe, as on the Deck.
- **Testing.** Add a fixture-driven decoder test per protocol (recorded HID reports
  → expected quaternions) that runs on desktop. The live chain check from
  `tests/live_tracking.gd` runs on device with prediction disabled, as it does today.

**5d. Later and optional: OpenXR on Android XR or standalone headsets.** This is a
different presentation path (the runtime owns the eyes and the pose). Keep it as a
separate preset with the Godot OpenXR vendors plugin only if there is demand.

**Exit:** VITURE Pro 2 LIVE 3DoF on the reference device, with the TV held still in
space, recentring, reconnect after unplug/replug, and pause/resume.

### Phase 6 — Video playback (2–4 days; mostly the FFmpeg cross-build)

- Cross-compile **FFmpeg 8 (LGPL, shared libraries)** for arm64 with
  `--enable-jni --enable-mediacodec` so H.264/HEVC decode through hardware
  MediaCodec decoders. Ship the libraries in the plugin's `jniLibs` and load them
  through the existing `video_backend.cpp` route (`ffmpeg62`), so the decoder,
  subtitle, interlace and VCR code stays shared.
- Record the FFmpeg source, configure line and build script in the corresponding
  source package, as is done for the cores (LGPL obligations).
- `Platform.video_backend()` returns `bundled`. The Windows download UI stays hidden.
- Fallback if the bundled size is unacceptable: a separate `video_backend`
  implementation over NDK `AMediaExtractor`/`AMediaCodec`. It is smaller, but it
  loses embedded subtitle tracks and duplicates decoding logic, so it is not the
  first choice.

### Phase 7 — Performance, thermals and quality tiers (3–5 days, partly in parallel)

- Add an **Android quality default**: render scale for the eye viewports, cheaper
  contact shadows and glass reflections, and reduced shadow filter quality (currently
  `soft_shadow_filter_quality=4`). These go through the existing picture/room
  settings so they stay user-adjustable and shared.
- Watch the thermal API (`PowerManager.getThermalHeadroom` through the plugin) and
  warn before throttling rather than quietly lowering quality.
- Battery: reuse the Deck's menu-header battery display through the plugin's battery
  status.

### Phase 8 — Release integration (ongoing from Phase 3)

- `docs/ANDROID-SETUP.md` for users (sideloading, All files access, ROM folder,
  glasses connection, tracking), packaged like the other platform guides through
  `package-beta.py`'s `GUIDES` table.
- README: an Android row in *Download the beta* and *What you need*, marked
  **preview** until hardware acceptance, in the same tone as the current
  "only VITURE Pro 2 has been tested" notes.
- `docs/PRE-LAUNCH-CHECKLIST.md` and `docs/validation.md` gain an Android column.
- Distribution: **GitHub Releases APK first.** F-Droid and the Play Store are later
  decisions with their own requirements. Play restricts All files access, which
  would force a Storage Access Framework browser; Play also has target-API rules,
  and the cores' non-commercial clauses (Snes9x, Genesis Plus GX) need a store
  review. Record that review in `docs/CORE-DISTRIBUTION.md` before any store
  submission.

## Maintaining Android alongside the other builds

**Where Android code may live.** Only in `scripts/platform/`,
`scripts/tracking/android_*.gd`, `native/android/` (tracking reader, libusb glue),
`android/plugin/` and `addons/crt_xr_android/`. Everything else is shared, and the
`check-repository.py` rule (D3) enforces it for the two most common leaks.

**One tag, every artefact.** A release builds Deck, Windows, Linux desktop and
Android from the same commit in the same container image. `test-beta.py` gains an
`--android` stage that exports the APK and runs `package-beta.py`'s content checks.
Device tests are a separate, explicit step (they need hardware), recorded in the
release checklist like the current Deck acceptance. An Android build that misses a
release ships later from the same tag, labelled as such. It never holds up the Deck.

**Capabilities, not OS names, in new features.** When a new feature needs a
platform decision, add a `Platform` capability with a desktop default. Android then
gets a deliberate answer rather than an accident. Review checklist item: *does this
change call a desktop-only API (`OS.create_process`, `OS.shell_open` on paths,
window moves, `DisplayServer` multi-window)?*

**Shared tests first.** Most logic (ROM identification, archives, library,
settings, pose prediction, tracking validation, the protocol decoders) runs in the
headless desktop suites with `--platform-override=android`. Device-only tests stay
few: native host/video tests over `adb`, a launch smoke test (start the activity,
wait for `CRT XR ready / ... / Android` in `logcat`), and the live tracking chain.

**Dependency bumps.**

| Bump | Android work |
|---|---|
| Godot | Android templates in `setup-export-templates.ps1`; re-run the Phase 0 performance scene |
| A core | `build-release-cores.py all` builds every target from the one pinned commit; `check-core-sources.py` fails if a target is missing |
| FFmpeg | Rebuild the Android libraries with the same configure line; `crt-xr-video-test` on device |
| NDK / SDK / target API | Pinned in the Dockerfile; bump once a year with the store target-API cycle even while sideload-only |

**Settings compatibility.** Settings and save formats stay identical across
platforms. Platform-specific keys (for example `display/sbs_layout` defaults, the
Android quality default and USB device choice) are namespaced. Desktop and XR FOV
calibration already being stored separately is the model. Then a backup made on the
Deck restores on Android and the other way round.

## Risks and open questions

| Risk | Effect | Mitigation |
|---|---|---|
| The device cannot output 3840×1080, or the glasses misread 1080p in 3D mode | No full SBS on that device | Half-SBS layout (4a); document per-device results in a compatibility table |
| VITURE does not allow bundling `libglasses.so` in an APK (an official Android arm64 SDK exists; its redistribution terms are unstated) | VITURE tracking needs our own decoder, about a week more | Ask VITURE for written terms before Phase 2; our own HID decoder as the fallback; ship OpenTrack and sensors first |
| SpaceWalker holds the glasses' motion sensor | No tracking while it is open | Detect the stalled stream and tell the user to close SpaceWalker, as the Windows guide does |
| Community tracking drivers' licences | Could pull copyleft code into MIT source | Clean-room decoders from protocol documentation, or a separately licensed library |
| GPU cost of two eye viewports and CRT shaders on mobile | Below 60 fps in SBS | Phase 0 gate; render scale and quality tiers |
| All files access is unacceptable to a store | Store distribution blocked | Sideload first; a SAF browser later, behind `Platform.storage_model()` |
| Activity relaunch on an external display tears down GL state | Black screen or crash in 4b | Prove it in Phase 0; 4a always remains available |
| Android kills the app in the background | Lost progress | Write the resume point on pause (Phase 3) |
| A signing key loss | Users cannot update | Key custody procedure before the first public APK |

**Decisions for the owner before Phase 2:**

1. Which reference device to buy and test against.
2. Sideload-only for the preview, or plan for F-Droid or Play from the start
   (changes the storage approach and the licence review).
3. Whether glasses tracking may depend on a vendor binary SDK at all, or must be
   open protocol code. The Windows build already depends on VITURE's SDK, and an
   official Android arm64 build of it exists. So the practical question is whether
   to ship VITURE's library inside the APK, once VITURE confirms that's allowed.

## Suggested order and rough total

Phase 0 → 1 → 2 → 3 (alpha) → 4a → 5a/5b → 5c (VITURE) → 4b → 6 → 7, with 8 running
alongside. At the project's current pace that is roughly **1–2 weeks to the mono
alpha** and **3–6 weeks to a preview with SBS and VITURE tracking**.

The range comes from hardware and outside parties, not from code volume. The work
that sets the schedule:

- **The reference device** arriving. Phases 0, 3, 4 and 5c can't finish without it.
- **What the device outputs to the glasses** (Phase 0). If it can't output full
  SBS, Phase 4 becomes half-SBS work only, and that work is shorter.
- **VITURE's redistribution answer** (5c). The official Android arm64 SDK makes
  VITURE tracking a few days' work if we may bundle it. If not, writing our own
  decoder adds about a week.
- **The three owner decisions** above. A Play Store target from the start would
  add a Storage Access Framework browser and a licence review, about 1–2 weeks.

Phases 1 and the half-SBS part of 4 improve the desktop builds as well and can land
before any Android release.
