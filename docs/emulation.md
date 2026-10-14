# Emulation and soft view edges

The current build includes an in-process Snes9x Libretro host and an adjustable
fade to black around each eye's view. It is deployed on the Deck under
`~/Applications/RetroCRT/scene-lighting-20261014/`; the main desktop shortcut
targets that build. Physical controller mappings and sustained stereo
performance still need checking through the glasses.

## Run a game on Windows

The native modules and core are already built in this workspace:

```powershell
./scripts/dev.ps1
# Escape or Tab opens settings; choose Open SNES ROM.
./scripts/dev.ps1 -Rom 'D:\your-rom-folder\game.sfc'
./scripts/dev.ps1 -Stereo -Rom 'D:\your-rom-folder\game.sfc'
```

Only use ROM files you supply. Uncompressed `.sfc`, `.smc`, `.swc` and `.fig` files
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
tools/userdata/Godot/app_userdata/RetroCRT XR/saves/
```

In a normal Linux export, Godot's user-data path is generally:

```text
~/.local/share/godot/app_userdata/RetroCRT XR/saves/
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
docker build -f Dockerfile.emulation -t retrocrt-emulation-build .
docker run --rm -v "$PWD:/work" retrocrt-emulation-build
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
