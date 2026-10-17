# Emulation and soft view edges

The local multi-system build uses an in-process Libretro host. Choose a game
in the pause menu; the file determines the core automatically. The new cores
have been tested locally on Windows with original diagnostic cartridges;
Steam Deck deployment and hardware validation follow separately.

| System | Core | Uncompressed cartridge extensions |
|---|---|---|
| SNES | Snes9x | `.sfc`, `.smc`, `.swc`, `.fig` |
| NES | Nestopia | `.nes`, `.unf`, `.unif` |
| Mega Drive / Genesis | Genesis Plus GX | `.md`, `.gen`, `.smd`, `.bin` |
| Master System | Genesis Plus GX | `.sms` |
| Game Gear | Genesis Plus GX | `.gg` |

`.md` and `.bin` require the standard SEGA cartridge header to avoid treating
documents and unrelated binary files as games. Archives, Famicom Disk System,
Sega CD, 32X, light guns, paddles and multiplayer are outside this first pass.
Ordinary supported cartridges need no BIOS. The browser retains SD-card,
default-folder and recent-game behaviour. Game Gear is fitted at 10:9;
the TV consoles retain the existing 4:3 presentation.

## System library

Browse to the main ROM root (for example `Emulation/roms`, containing `snes`,
`megadrive`, `nes`, etc.) and press R1 to save it. **Choose game** then scans
subfolders automatically and shows a system selector with game counts. Empty
or unsupported systems are hidden. Files are classified by supported cartridge
format, so both `genesis` and `megadrive` folders work without renaming anything.

The scan is incremental to keep the menu responsive, handles linked folders
without following cycles, and skips hidden files and common artwork/BIOS/save
directories. Opening Choose game rescans; **Refresh library** picks up changes
while it is open. Missing cards retain the saved root and show reconnect guidance.
Very large roots stop at 200,000 entries with a visible request to choose a more
specific folder. No ROMs are copied, renamed or moved.

Select a system with A, then a game with A. B returns to systems. Lists are
naturally sorted and paged in groups of 50; L1/R1 or Left/Right changes pages.
Each system remembers its current page, selected game and scroll position during
the session. Manual browsing, recent game, SD-card and default-folder shortcuts
remain available. Compressed archives are not indexed in this version.

On Deck/Xbox controllers, NES B/A use the bottom/right buttons; left/top are
turbo B/A. Mega Drive A/B/C use left/bottom/right; X/Y/Z use L1/top/R1 when
the core selects a six-button pad. Back is Mode. Master System/Game Gear
buttons 1/2 use bottom/right, with Start for Pause/Start. All systems keep
the same menu chord and recenter shortcut. Settings → Controls & XR →
Controller shows the current system's layout. Keyboard Z/X/A/S/Q/W retain
the corresponding bottom/right/left/top/L1/R1 positions.

Existing SNES SRAM and states retain their original paths. New systems use
`user://saves/<system>/<core>/`, with SHA-256 ROM names and the same atomic
save/state envelope behaviour. Per-game picture settings remain keyed by ROM
hash. Switching games fully unloads and deinitialises the previous core.

Local dependency setup: run `scripts/setup-emulation.ps1`, followed by
`scripts/fetch-cartridge-cores.ps1` for verified official builds. The hashes in
`third_party/cores/builds.json` deliberately reject changed nightly downloads.
`scripts/build-cartridge-cores.sh all` is an alternative source-build route in
the compiler container; it has not yet been validated because Docker failed
to start during this pass. Exports include core notices, provenance and source
snapshots. Genesis Plus GX prohibits commercial use; see `THIRD_PARTY.md`.

The Linux `crt-xr.x86_64` entry point keeps the system C++ runtime loaded
throughout core switches and starts `crt-xr-engine.x86_64` with the packed
project. This avoids a SteamOS locale-facet crash when returning to Snes9x
after another core. Use the entry point or normal Steam/glasses launchers;
do not launch the engine binary directly. The preload is scoped to this process,
preserves other preload entries, and does not change the emulator cores or saves.

## Run a game on Windows

The native modules and core are already built in this workspace:

```powershell
./scripts/dev.ps1
# Escape opens the menu; choose Choose game.
./scripts/dev.ps1 -Rom 'D:\your-rom-folder\game.sfc'
./scripts/dev.ps1 -Stereo -Rom 'D:\your-rom-folder\game.sfc'
```

Only use ROM files you supply. The cartridge formats above
are selectable; archives and patch application are not implemented. The native
host limits cartridge input to 32 MiB. No console BIOS is needed for ordinary
SNES cartridges; special peripherals and enhancement variants are not tested.

Choose **Soft view edges** in settings to control the fade. The default is 7.5%
of each eye view's width/height; zero disables it. It darkens the entire viewing
window, including at the SBS centre join, rather than the television's UV image.
It leaves the middle of each eye unobscured. Settings are saved explicitly with
**Save settings & close**.

## Controls while a game is loaded

| Action | Keyboard | Deck/gamepad |
|---|---|---|
| SNES B / A / Y / X | Z / X / A / S | Bottom / right / left / top face buttons |
| SNES D-pad | Arrow keys | D-pad or left stick |
| SNES Start / Select | Enter / Tab | Start / Back |
| SNES L / R | Q / W | Left / right shoulder |
| Application menu | Escape | Hold L1 + R1, then press Start |
| Recenter head | R | Right-stick click |
| Pause / resume | Space | Menu |
| Save / load quick state | F5 / F8 | Menu, slot 0 |
| SBS / fullscreen | F2 / F11 | Menu |

Face buttons, Start and Select are reserved for the game during gameplay.
Deck/Xbox A (bottom) maps to SNES B; B (right) to SNES A; X (left) to SNES Y;
Y (top) to SNES X. L1/R1 map to SNES L/R. Back/View is Select. Triggers and L3
are unassigned; R3 recentres. No face button changes display mode or recentres.

Game input follows the controller receiving input instead of always polling the
first enumerated device. Left-stick directions use a 25% deadzone. The settings
chord is latched until all three buttons are released; hold both shoulders before
pressing Start to avoid sending a standalone Start press first. Menu actions are
blocked from the game until released. Focus loss and disconnection clear held
buttons. In menus, A confirms and B cancels regardless of the SNES face mapping.

Use Steam Input's **Gamepad** layout for the non-Steam shortcut. A desktop mouse
or keyboard layout can hide the face buttons from the app; in-app mapping cannot
recover buttons Steam never forwards. Settings show the detected controller or
a prompt to select a Gamepad layout. Physical Deck input still needs a hardware
check after deploying this update.

Simulation keyboard movement is disabled while playing to keep arrow keys and
Q available to the game; real glasses tracking continues normally.

Settings and the in-app file browser stay inside SBS, with synchronized copies
in both eyes. D-pad navigates, A opens a game or folder, and B cancels. The last
loaded path is remembered by **Play last game**. Opening the menu pauses
the game; closing it restores its prior pause state. **Stop game / return to test
signal** unloads the cartridge and restores the animated test pattern.

## Audio and saves

The core supplies console frame rate and sample rate. NTSC and PAL use those
values rather than an assumed 60 Hz. Video is uploaded as RGBA with nearest
sampling on the existing 4:3 curved mesh. Scanline/mask density follows source
dimensions. The host handles RGB565, 0RGB1555, XRGB8888, padded rows and duplicate
frames. Core execution and state operations happen on one main thread.

Stereo PCM is fed to Godot's generator in native C++; the generator has a 100 ms
capacity. Actual queued latency depends on pacing and the device's output path.
Pause and load-state operations recreate playback to discard old queued samples.
Catch-up is bounded; console lag and audio overflow produce warnings instead of
silently accumulating an unlimited backlog. Headless checks skip the audio output
queue while still testing the core's audio callback data.

SRAM is saved every ten seconds, on game switching and on normal exit. Save
files are stored under `user://saves/`, keyed by full ROM SHA-256 so identical
filenames cannot mix cartridge data. File replacement uses a temporary write and
rename. Slot-0 states carry the ROM hash and core identity; mismatches are rejected.
States can be core-version dependent. An existing state file can be overwritten
by an explicit quick save, as expected.

In scripted Windows development, this directory is:

```text
tools/userdata/Godot/app_userdata/CRT XR/saves/
```

In a normal Linux export, Godot's user-data path is generally:

```text
~/.local/share/godot/app_userdata/CRT XR/saves/
```

## Building dependencies

Sources are pinned; the setup script refuses to switch a dependency checkout
with local changes:

```powershell
./scripts/setup-emulation.ps1
```

Then in WSL, with Docker running:

```bash
cd /mnt/d/git/XR-CRT
docker build -f Dockerfile.emulation -t crt_xr-emulation-build .
docker run --rm -v "$PWD:/work" crt_xr-emulation-build
```

The container builds the Godot C++ extension and Snes9x core for Linux x86-64 and
Windows x86-64, runs native Linux host tests, and generates an original test ROM
under ignored `build/`. For one target, append `bash scripts/build-emulation.sh
linux` or `windows` to the `docker run` command. On this machine's WSL rootless
Docker setup, `systemctl --user start docker` may be needed after a cold start.

Artifacts are in `extensions/bin/` and `cores/`. Windows C++ runtime libraries are
linked statically; the Windows DLL is not used by Linux. Dependency licenses are
copied alongside the builds; see [third-party sources](../THIRD_PARTY.md).

To export the Linux application from Windows afterward:

```powershell
./scripts/export-linux.ps1
```

It packages the matching Linux extension, core, launcher and licenses into
`dist/linux/`. The existing head-tracking helper must also be built with
`scripts/build-linux.sh` as described in the main README. Transfer the **whole
folder**, including `cores/` and the extension `.so`, when the Deck is available.

## Verification and remaining work

Native host tests cover pixel formats/pitch, duplicate frames, both PCM callback
forms, input, legacy core options, state round-trip, invalid state and SRAM size.
They also execute the actual Snes9x core against an original 128 KiB diagnostic
ROM: the backdrop animates, holding B turns it red, and SRAM receives a known
byte. This program contains no third-party assets and is generated from the
CC0 source at `tests/make_probe_rom.py`.

Application tests run on Windows headlessly and with the GPU, and on the exported
Linux application in WSL. They cover texture binding to the CRT, pacing metadata,
pause, states, keyboard input, SRAM and reloading. The Windows rendered edge test
checks black borders in **each** eye and an unobscured centre.

Deck gameplay, audible sound with a supplied game, controller mapping and
sustained performance remain hardware tests. The diagnostic ROM intentionally
does not synthesize a tone. No commercial cartridge compatibility is claimed
from this limited diagnostic program. Per-eye menus pass local GPU/controller
checks; the automatic KDE display launcher is prepared but needs a hardware
check. Audio-clock tuning and Gaming Mode remain further work. See
[display setup](display-setup.md).
