# Development

Run these commands from the repository root. For installation and normal use, see [Getting started](GETTING-STARTED.md).

## Prerequisites and a clean checkout

Use Git, Python 3.9+, PowerShell, Godot **4.5.1** with Compatibility rendering, and a Linux x86-64 compiler environment (WSL or Docker Desktop). Docker must be running for the commands below. Blender 5.2 is needed only to regenerate model/contact bakes. Godot does not build the native extension automatically.

On Windows, from the repository root:

```powershell
./scripts/setup-windows.ps1
./scripts/setup-export-templates.ps1
./scripts/setup-emulation.ps1
```

These download the engine/templates and clone pinned godot-cpp and the ten core sources (Snes9x, Nestopia, Genesis Plus GX, Gambatte, mGBA, Beetle PCE Fast, Beetle Lynx, Beetle NeoPop, Stella and vecx) into ignored `tools/`. The native build uses CMake, Make and GCC (mGBA builds with CMake); the compiler image includes the MinGW cross compiler for Windows.

```powershell
docker build -f Dockerfile.emulation -t crt-xr-build .
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/work" crt-xr-build bash scripts/build-emulation.sh all
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/work" crt-xr-build python3 scripts/build-release-cores.py all
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/work" crt-xr-build bash scripts/build-linux.sh
```

This builds both native extension platforms and runs the host test, then all ten release cores from their pinned commits, then the Linux tracking helpers. Use `linux` or `windows` instead of `all` for one platform. If Docker is unavailable, run the same commands in WSL or another Linux environment with the packages listed in `Dockerfile.emulation`. `build-release-cores.py` records every binary's source archive, compiler and arguments in `cores/core-builds.json`, extracts the licence files and also works from the corresponding-source bundle without Git metadata; `python3 scripts/check-core-sources.py` verifies the records. `build-emulation.sh` uses its own Snes9x build only for the host test and does not replace recorded cores. No bit-for-bit equality with Libretro's buildbot binaries is claimed.

```powershell
./scripts/dev.ps1 -Editor
./scripts/dev.ps1
./scripts/dev.ps1 -Rom 'D:\your-rom-folder\game.sfc'
```

Development uses isolated `tools/userdata/`; it does not require a Steam Deck. No commercial ROMs or BIOS files are included. Synthetic probe generators are in `tests/`.

## Models and bakes

A source checkout does not include the downloaded TV/table or generated resources. Runtime has procedural fallbacks, so missing licensed models do not prevent source development once the native extension is built. Release parity requires the separately prepared assets; never copy an entire local `build/`, `tools/` or `archive/` into Git.

1. Obtain the models from their creator links in [assets/model-sources.json](../assets/model-sources.json), retaining the applicable licence evidence. The TV's historical CC BY 4.0 link is verified; retain the downloaded revision's provenance and see [licensing](../LICENSING.md).
2. Place the matching originals at `build/crt-model/crt_tv.glb` and `build/wood-table-source/wood_drawer__tables_set.glb`. Compare their SHA-256 hashes with the manifest; another download/revision is not assumed to be identical.
3. Prepare the TV and wide table, then bake the TV AO:

```powershell
$godot = './tools/godot/Godot_v4.5.1-stable_win64_console.exe'
& $godot --headless --path . --script scripts/optimise-cabinet.gd
& $godot --headless --path . --script scripts/prepare-wood-table.gd
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python scripts/bake-cabinet-ao.py
& $godot --headless --path . --script scripts/prepare-cabinet-ao.gd
./scripts/rebake-room.ps1
python scripts/check-release-assets.py
python scripts/check-core-sources.py
```

The console is excluded from launch and does not need preparing. See [TV preparation](crt-model-local.md), [table preparation](wood-table.md) and [contact rebaking](room-contact-bake.md). Bakes must be rerun when static geometry changes. Prepared Godot resources may depend on texture files beside them; retain complete output folders.

A local recovery bundle can be created with `scripts/archive-model-assets.py` when its listed original/prepared inputs are present. Bundles are ignored and are not a public download mechanism. Keep a verified copy off this machine; a local archive alone is not a backup strategy.

## Validation and export

```powershell
python scripts/check-repository.py
python scripts/test-beta.py
python -m unittest discover -s tests -p '*_test.py'
python scripts/check-release-assets.py
python scripts/check-core-sources.py
./scripts/export-windows.ps1 -OutputDirectory dist/CRT-XR-<version>-Windows
./scripts/export-linux.ps1 -OutputDirectory dist/CRT-XR-<version>-SteamDeck
python scripts/package-corresponding-source.py dist/CRT-XR-<version>-source-code.tar.gz
python scripts/package-beta.py dist/CRT-XR-<version>-Windows windows dist/CRT-XR-<version>-source-code.tar.gz
python scripts/package-beta.py dist/CRT-XR-<version>-SteamDeck linux dist/CRT-XR-<version>-source-code.tar.gz
```

`package-beta.py` arranges each download so the first thing people see is what to open: the Steam Deck archive holds **Install CRT XR**, **HOW TO INSTALL.txt** and a `CRT XR files` folder; the Windows ZIP holds **CRT-XR.exe** (with the pack and extension it needs beside it), **HOW TO START.txt** and `cores`, `assets`, `tracking`, `docs` and `licenses` folders. Only the getting-started, game and platform setup guides are packaged; these developer notes stay on GitHub. The instructions files are `scripts/installer/HOW TO INSTALL.txt` and `HOW TO START.txt`.

`test-beta.py` isolates preferences for each suite. Set `GODOT_BIN` to use another Godot 4.5.1 executable; on Linux it also isolates `XDG_DATA_HOME`. Installer transaction checks need Linux and skip on Windows. Exported folders contain native libraries, cores, model resources and notices beside the executable; do not distribute just the EXE. Binary releases still require the [distribution review](../LICENSING.md).

The optional historical A/B GPU benchmark is not a normal regression test. Set `CRT_XR_REFERENCE_SHADERS` to a local folder containing `crt_reference_pass1.gdshader` and `analog_reference.gdshader`, then run `tests/crt_pass2_performance.gd` with graphics enabled and isolated preferences. These old baseline files are not in Git; without them the benchmark exits with instructions instead of using a developer's Deck paths. GPU timing needs hardware and is not meaningful headlessly.

Native C++ identifiers use `crt_xr`; launchers/executables use `crt-xr` (Windows `CRT-XR.exe`). The checkout folder name is independent of the app identity. Do not publish ROMs, music, preferences, logs, SSH known-host files or local recovery bundles. Review Git author identity before publishing history; source checks do not rewrite commit metadata.

## Data and migration

CRT XR uses its own Godot user-data directory. On first launch it copies preferences, saves, favourites, screenshots and music bookmarks from the previous **RetroCRT XR** directory. It never removes the old data or overwrites existing new files. Old logs and shader caches are skipped. Save formats and ROM identities are unchanged. `RETROCRT_CORE` remains a legacy alias for the new `CRT_XR_CORE` environment override.

On Linux, preferences are normally in `~/.local/share/godot/app_userdata/CRT XR/`; logs launched through Steam are under `${XDG_STATE_HOME:-$HOME/.local/state}/crt_xr/`. On Windows they are normally under `%APPDATA%/Godot/app_userdata/CRT XR/`. Development scripts intentionally use isolated `tools/userdata/`.


## Windows XR release builds

Run `scripts/build-windows-tracking.ps1` (WSL Ubuntu with the MinGW POSIX compiler), then `scripts/export-windows.ps1`. Windows export requires Python and applies the per-monitor DPI manifest after export with a separate PCK. Keep that PCK with the EXE. The VITURE SDK under ignored `sdk/` is for local testing only; public packages exclude proprietary SDK files. End users follow [Windows setup](WINDOWS-SETUP.md). Use the exported EXE for mixed-DPI hardware checks; the unmodified editor executable retains system DPI awareness.

## Android (preview groundwork)

The Android port follows the [Android port plan](ANDROID-PORT-PLAN.md). It builds in its own image with the NDK, SDK and JDK versions Godot 4.5.1's Android template expects (NDK 28.1.13356709, platform 35, build-tools 35.0.0, Java 17). First run `scripts/setup-emulation.ps1` so `tools/godot-cpp` and `tools/snes9x` exist, and `scripts/setup-export-templates.ps1` so `tools/export_templates.zip` exists. Then:

```powershell
docker build -f Dockerfile.android -t crt-xr-android .
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/work" crt-xr-android bash scripts/build-android.sh all
```

`extension` builds `extensions/bin/libcrt_xr_libretro.android.arm64.so` and the native test executables in `build/emulation-android/`. `export` fetches the pinned Linux Godot editor into `tools/godot-linux/` (self-contained, with its own Android templates, settings and a development-only debug keystore), stages the prepared models and bakes into the ignored `android_assets/`, and writes `dist/android/CRT-XR-debug.apk`. `all` does both. The export checks that the Android preset's `version/name` and `version/code` follow `config/version`, so bump them with each release. The container's Godot cannot load the desktop Linux extension (it needs a newer glibc) and says so; that does not affect the Android export.

Cores and FFmpeg are not built for Android yet, so the APK can show the room but not play games or videos. Nothing has run on a device yet. The prebuilt template keeps Godot's minimum of API 24 while the extension targets API 29 (Android 10); the APK's minimum is raised with the Gradle build in Phase 3. Platform differences belong in `scripts/platform/platform.gd`; `check-repository.py` rejects `OS.get_name()` and `OS.get_executable_path()` elsewhere in `scripts/`, and `tests/platform_paths.gd` checks the answers for each platform from the desktop editor.

## The animated logo

The About page's 3D logo is rebuilt from the After Effects composition
'Animated Logo 2'. `assets/logo/animated-logo-2.json` is its export: each
letter's shape paths, fills, transforms and keyframes with their easing, and
the null's rotation. `python scripts/make-logo-3d.py` (needs shapely 2.1 or
later) triangulates the outlines into `assets/logo/logo-3d.json`, which
`scripts/ui/logo_3d.gd` turns into meshes and animates with After Effects'
own Bézier easing. The export presets ship that JSON alongside
`THIRD_PARTY.md`. Re-export the source JSON after changing the composition.
