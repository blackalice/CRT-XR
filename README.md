# CRT XR

CRT XR places your games on a curved 3D CRT television, with head tracking and side-by-side stereo for VITURE glasses on Steam Deck. **0.1.0-beta.1 is a release candidate under review**, not a public release approval.

Supported cartridges: SNES, NES, Mega Drive, Master System and Game Gear. Bring your own uncompressed ROMs; no commercial games or BIOS files are supplied. Windows provides a local simulation/mono/SBS preview. Live glasses tracking currently requires Linux and the supported XRLinuxDriver installation.

Start with [Beta quickstart](docs/BETA-QUICKSTART.md). See [release review and remaining gates](docs/BETA-REVIEW.md), [third-party credits](THIRD_PARTY.md), [emulation/building](docs/emulation.md), [display setup](docs/display-setup.md) and [audio](docs/audio.md).

## Controls

| Action | Gamepad | Keyboard |
|---|---|---|
| Menu | L1 + R1 + Start | Escape |
| Recenter | R3 | R |
| Select / adjust setting | Up/down / left/right | Arrows |
| Activate / back | A / B | Enter / Backspace |
| Category / subsection | L1/R1 / L2/R2 | Q/E / Z/C |
| Reset selected option | Y | Y |
| Compact visual preview | X | X |
| Move TV closer/farther | Right stick (optional) | Page Up/Down |
| Screenshot | Pause menu | F6 |

The settings categories are View, Picture, Audio, Room, Controls & XR, Saved setups and General. Left/right adjusts values immediately. The menu renders once at 960×720 and is shared between both eyes. It pauses the game and restores its prior pause state when closed. The music player keeps its own playback state; left/right selects transport icons or seeks on the timeline, while down leaves the icon group.

## Development

Use Godot **4.5.1** with Compatibility rendering. On Windows:

```powershell
./scripts/setup-windows.ps1
./scripts/dev.ps1
./scripts/dev.ps1 -Editor
./scripts/dev.ps1 -Rom 'D:\your-rom-folder\game.sfc'
```

A fresh checkout needs the native emulator dependencies and model assets prepared separately; see the build and asset documents. Downloaded engines, native binaries, cores, models, builds and local archives are ignored by Git. `assets/model-sources.json` records source hashes and attribution. `scripts/check-release-assets.py` verifies the required assets. A local verified recovery bundle is stored under `archive/`; keep a copy off this machine. `scripts/archive-model-assets.py` recreates it from the original/prepared assets.

```powershell
python scripts/test-beta.py
python scripts/check-release-assets.py
./scripts/export-windows.ps1 -OutputDirectory dist/windows-review
./scripts/export-linux.ps1 -OutputDirectory dist/linux-review
```

The Linux tracking helpers must be built before exporting. Native C++ identifiers use `crt_xr`; launchers/executables use `crt-xr` (Windows `CRT-XR.exe`). The local checkout may still be named `XR-CRT`; that filesystem path is independent of the app/Git project identity. There is no hosted Git remote configured yet.

## Upgrading and data

CRT XR uses its own Godot user-data directory. On first launch it copies preferences, saves, favourites, screenshots and music bookmarks from the previous **RetroCRT XR** directory. It never removes the old data or overwrites existing new files. Old logs and shader caches are skipped. Save formats and ROM identities are unchanged. `RETROCRT_CORE` remains a legacy alias for the new `CRT_XR_CORE` environment override.

On Linux, preferences are normally in `~/.local/share/godot/app_userdata/CRT XR/`; logs launched through Steam are under `${XDG_STATE_HOME:-$HOME/.local/state}/crt_xr/`. On Windows they are normally under `%APPDATA%/Godot/app_userdata/CRT XR/`. Development scripts intentionally use isolated `tools/userdata/`.

## Release status

The code, packaged assets and bundled emulator cores have different licensing requirements. The app's own source licence has not yet been selected. Snes9x and Genesis Plus GX restrict commercial use; Nestopia is GPL-2.0. Included core source snapshots/credits are not a blanket licence for the app. Resolve the distribution/licensing decisions in the release review before publishing downloads. User ROMs, music and private data must never be included.
