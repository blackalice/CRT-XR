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

These download the engine/templates and clone pinned godot-cpp/Snes9x/Nestopia/Genesis Plus GX sources into ignored `tools/`. The native build uses CMake, Make and GCC; the compiler image includes the MinGW cross compiler for Windows.

```powershell
docker build -f Dockerfile.emulation -t crt-xr-build .
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/work" crt-xr-build bash scripts/build-emulation.sh all
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/work" crt-xr-build bash scripts/build-cartridge-cores.sh all
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/work" crt-xr-build bash scripts/build-linux.sh
```

This builds both native extension platforms, Snes9x and the additional cartridge cores, then Linux tracking helpers. Use `linux` or `windows` instead of `all` for one platform. If Docker is unavailable, run the same shell scripts in a Linux environment with the packages listed in `Dockerfile.emulation`. Source-build commands are provided, but a fresh-environment rebuild and independent binary provenance acceptance are still outstanding; do not treat them as a certification of existing downloaded binaries. The hash-pinned `scripts/fetch-cartridge-cores.ps1` is an alternative for local development; nightly URLs may change, in which case its hash check deliberately refuses the download.

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
./scripts/rebake-room.ps1
python scripts/check-release-assets.py
```

The console is excluded from launch and does not need preparing. See [TV preparation](crt-model-local.md), [table preparation](wood-table.md) and [contact rebaking](room-contact-bake.md). Bakes must be rerun when static geometry changes. Prepared Godot resources may depend on texture files beside them; retain complete output folders.

A local recovery bundle can be created with `scripts/archive-model-assets.py` when its listed original/prepared inputs are present. Bundles are ignored and are not a public download mechanism. Keep a verified copy off this machine; a local archive alone is not a backup strategy.

## Validation and export

```powershell
python scripts/check-repository.py
python scripts/test-beta.py
python -m unittest discover -s tests -p '*_test.py'
python scripts/check-release-assets.py
./scripts/export-windows.ps1 -OutputDirectory dist/windows-review
./scripts/export-linux.ps1 -OutputDirectory dist/linux-review
```

`test-beta.py` isolates preferences for each suite. Set `GODOT_BIN` to use another Godot 4.5.1 executable; on Linux it also isolates `XDG_DATA_HOME`. Installer transaction checks need Linux and skip on Windows. Exported folders contain native libraries, cores, model resources and notices beside the executable; do not distribute just the EXE. Binary releases still require the [distribution review](../LICENSING.md).

The optional historical A/B GPU benchmark is not a normal regression test. Set `CRT_XR_REFERENCE_SHADERS` to a local folder containing `crt_reference_pass1.gdshader` and `analog_reference.gdshader`, then run `tests/crt_pass2_performance.gd` with graphics enabled and isolated preferences. These old baseline files are not in Git; without them the benchmark exits with instructions instead of using a developer's Deck paths. GPU timing needs hardware and is not meaningful headlessly.

Native C++ identifiers use `crt_xr`; launchers/executables use `crt-xr` (Windows `CRT-XR.exe`). The checkout folder name is independent of the app identity. Do not publish ROMs, music, preferences, logs, SSH known-host files or local recovery bundles. Review Git author identity before publishing history; source checks do not rewrite commit metadata.

## Data and migration

CRT XR uses its own Godot user-data directory. On first launch it copies preferences, saves, favourites, screenshots and music bookmarks from the previous **RetroCRT XR** directory. It never removes the old data or overwrites existing new files. Old logs and shader caches are skipped. Save formats and ROM identities are unchanged. `RETROCRT_CORE` remains a legacy alias for the new `CRT_XR_CORE` environment override.

On Linux, preferences are normally in `~/.local/share/godot/app_userdata/CRT XR/`; logs launched through Steam are under `${XDG_STATE_HOME:-$HOME/.local/state}/crt_xr/`. On Windows they are normally under `%APPDATA%/Godot/app_userdata/CRT XR/`. Development scripts intentionally use isolated `tools/userdata/`.

