# RetroCRT XR

A runnable Godot 4.5.1 prototype of a stationary 3D CRT with an animated test
signal, simulated or XRLinuxDriver 3DoF tracking and parallel off-axis stereo cameras.
Live VITURE Pro 2 tracking works on Steam Deck. A native Snes9x Libretro host now
loads user ROMs, displays gameplay on the CRT, supplies audio and input, and
supports pause, states and SRAM. No commercial ROMs, BIOS or artwork are included.

On the configured Deck, use the **RetroCRT XR Tracking** desktop shortcut.
See [head tracking setup and calibration](docs/head-tracking.md).
The menu, saved setups, per-game picture, CRT shader and startup updates are
installed on the Deck. The current Steam entry uses `performance2-crt-20261014`,
including the two measured [CRT performance passes](docs/crt-performance.md).
See [settings and startup](docs/settings-and-startup.md),
[picture controls](docs/picture-controls.md) and [playing and building](docs/emulation.md).

## Run on Windows

From this folder in PowerShell:

```powershell
./scripts/setup-windows.ps1   # first-time download; already installed in this workspace
./scripts/dev.ps1
./scripts/dev.ps1 -Editor    # or import project.godot in Godot 4.5.1, then press F6/F5
./scripts/dev.ps1 -Stereo
./scripts/dev.ps1 -Test
./scripts/dev.ps1 -Rom 'D:\your-rom-folder\game.sfc'
./scripts/dev.ps1 -EmulationTest
```

The downloaded engine lives under ignored `tools/`. Set `GODOT_BIN` to use your
own Godot executable. Development scripts keep user data in `tools/userdata/`
and the bundled portable editor keeps its configuration in `tools/godot/editor_data/`.
An editor opened outside these scripts uses its normal user-data location.
The native dependencies are already built in this workspace. A fresh checkout
also needs the [emulation build steps](docs/emulation.md#building-dependencies).

| Action | Keyboard / mouse | Controller |
|---|---|---|
| Simulate head yaw / pitch | Arrow keys or hold right mouse and drag | Mouse / keyboard |
| Move screen closer / farther | Page Up / Page Down | Right stick up / down (optional) |
| Simulate roll | Q / E | Keyboard in this prototype |
| Recenter | R | Right-stick click |
| Pause menu | Escape; Tab when no game is loaded | Hold L1 + R1, then press Start |
| Mono / SBS preview | F2 | Menu |
| Fullscreen | F11 | Settings button |
| Pause test signal | Space | Keyboard in this prototype |
| Pause/resume game | Space | Menu |
| Quick save / load | F5 / F8 | Menu |
| Hide diagnostic overlay | F1 | Keyboard in this prototype |
| Navigate / adjust | Arrows / Enter / Backspace | D-pad / left stick; A select; B back |
| Change category / subsection | Q/E or Tab; Z/C; pointer | L1/R1; L2/R2 |
| Reset selected menu option | Y | Y |
| Compact adjustment preview | X | X; B returns |
| Clean screenshot | F6 | Pause menu → Screenshot |

The TV stays fixed while cameras rotate. This is rotational tracking: it does
not simulate walking around the TV. Settings pause simulated head movement.
Settings and the in-app ROM browser appear in both eyes without leaving SBS.
Use the D-pad and A to navigate, B to cancel, and L1 + R1 + Start / Escape to open settings.
The menu pauses a running game and restores its previous pause state on close.

The pause menu offers Resume, Choose game, states, Screenshot, Settings and Exit.
Settings use **View**, **Picture**, **Room**, **Controls & XR** and **Saved setups**,
with subsections for fitting, colour, signal, materials and calibration. The selected
row has a full amber border and arrow marker. Left/right adjusts immediately;
Y resets just that option; X opens a compact strip for visual adjustments.
Closing the pause menu saves preferences and restores the previous pause state.
Exit, reset-all and overwriting a saved setup require confirmation.
See [menu and startup controls](docs/settings-and-startup.md) and
[room and view controls](docs/room-and-view.md).

Each eye gets its own adjustable edge fade; set
**Soft view edges** to zero to disable it. Source pixels
use filtered sampling on a 4:3 mesh; perspective and curved geometry
prevent strict integer scaling across the whole screen.

## Linux export from Windows

Godot exports a native Linux x86-64 executable directly from Windows:

```powershell
./scripts/setup-export-templates.ps1  # official archive is approximately 1.36 GB
./scripts/export-linux.ps1
```

The template installer extracts only Linux x86-64 templates for the bundled
portable editor. For another Godot install, install its matching 4.5.1 templates
through Editor > Manage Export Templates. Output is `dist/linux/` with a native
ELF executable, `.pck`, Linux GDExtension, core, licenses and launcher.
No Windows DLL is required or packaged.

The native IPC inventory utility and tracking helper are separate executables. Build them in
WSL Ubuntu with `build-essential` and `cmake` installed (development machine only):

```bash
cd /mnt/d/git/XR-CRT
bash scripts/build-linux.sh
# With Linux Godot 4.5.1 and matching templates installed:
GODOT_BIN=/path/to/godot bash scripts/build-linux.sh --export
```

Or use Docker without installing compilers into WSL:

```bash
docker build -f Dockerfile.linux -t retrocrt-build .
docker run --rm -v "$PWD:/work" retrocrt-build
```

This compiles the inventory utility, attach-only tracking helper and isolated
safety tests. The helper uses loopback UDP to keep driver synchronization out of
Godot's rendering process; it needs no Godot C++ ABI dependency. Copy the helper
alongside the exported executable. The app can run simulation without it.
Linux attempts real tracking by default; `-- --simulate` selects simulation.

## Transfer and launch on Steam Deck

Copy the complete contents of `dist/linux/` to `~/Applications/RetroCRT/` on Deck,
using a USB drive or existing SSH access. For SSH, for example:

```powershell
scp -r ./dist/linux deck@YOUR_DECK:~/RetroCRT
```

In SteamOS Desktop Mode, open a terminal in that directory:

```bash
chmod +x retrocrt.x86_64 retrocrt-tracking-bridge launch-deck.sh
bash launch-deck.sh
# Only after the glasses are actually in Full-SBS mode:
bash launch-deck.sh -- --full-sbs
```

Move the window to the glasses before entering fullscreen. The prototype does
not change glasses modes or select a monitor automatically. `--full-sbs` requests
3840x1080 fullscreen; the display server may override it. Confirm the actual
external mode and disable compositor scaling before assessing stereo.

Add `launch-deck.sh` as a non-Steam game, set its Start In to the package folder,
and choose a Steam Input gamepad layout. Desktop Mode rendering and live tracking
data have been tested. The user confirmed SBS depth with the built-in display
disabled, then confirmed the tracking build looks good in SBS. Gaming Mode,
long-session optical calibration and gameplay/audio on the Deck remain pending.
No SteamOS system partition changes are required.

## Troubleshooting

* No TV: use R to recenter, check distance/scale, and start in mono.
* No controller: choose a Steam Input gamepad layout; desktop mouse mappings do
  not supply joystick axes. USB controllers and Deck input still need device testing.
* Double tracking / warped SBS: verify the active XR Gaming/Gamescope effects.
  The app uses OpenGL compatibility to avoid the Breezy Vulkan layer, but that
  does not rule out compositor effects. Do not stack two head transforms.
* No stereo: SBS on a normal monitor shows two images. The glasses must be in
  Full-SBS mode with an actual 3840x1080 output. This app does not unlock plugin features.
* Native utility returns 2: IPC paths or segments are unavailable. This is expected
  without a running compatible driver; it does not prove a hardware fault.
* Linux dependencies: an OpenGL 3.3-capable driver and normal Godot desktop runtime
  libraries are required. Missing-library errors can be inspected with `ldd`.
* Export missing templates: install templates matching the exact engine version.

Deck logs: `${XDG_STATE_HOME:-$HOME/.local/state}/retrocrt/godot.log`.
Windows scripted-development logs: `tools/userdata/Godot/app_userdata/RetroCRT XR/logs/`.
The HUD reports orientation, mode, nominal IPD and measured frame rate.
Use `-- --capture` with the development engine for a rendered snapshot in
`build/preview.png`; it exits after capture. This diagnostic writes to the project
folder and is intended for development, not an installed read-only package.

## Next work

The local CRT now has a separate curved glass faceplate, adjustable reflections
and phosphor glow, and distance-aware scanline/mask filtering. See
[CRT rendering research and implementation](docs/crt-rendering.md) for the
approach, preview and pending optical/performance checks.

1. Transfer the new package when the Deck is available; check soft edges and
   user-supplied games with audio and Steam Input.
2. Validate the new [automatic glasses launcher](docs/display-setup.md): physical
   SBS switch remains manual; resolution, internal-panel management and restore
   are prepared for KDE Desktop Mode.
3. Exercise physical disconnect/reconnect, long-session latency and Gaming Mode.

See [validation](docs/validation.md) for tested scope and remaining acceptance checks.
