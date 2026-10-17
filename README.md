<p align="center">
  <img src="artwork/Logo.png" alt="CRT XR logo" width="260">
</p>

<h1 align="center">CRT XR</h1>

<p align="center">
  A little CRT room for your XR glasses.<br>
  Retro games, head tracking, warm lighting and the radio on in the background.
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#install-on-steam-deck">Install</a> ·
  <a href="docs/GETTING-STARTED.md">Getting started</a> ·
  <a href="THIRD_PARTY.md">Credits</a>
</p>

> [!NOTE]
> CRT XR is an **early public beta**. Testing so far has been on Steam Deck with VITURE Pro 2 glasses. Feedback and compatibility reports are welcome; see the [known limitations and remaining checks](docs/PRE-LAUNCH-CHECKLIST.md).

![CRT XR showing its built-in test signal on a curved CRT television, with a wooden table and carpet](docs/images/crt-xr-preview.png)

*An in-app, single-eye capture of the current scene using the built-in test signal. No game is included.*

## Features

- **A CRT in your space.** A detailed television, wooden table, soft carpet and baked contact shadows. The surroundings fade into black to suit XR glasses rather than filling your view with a whole virtual room.
- **Stereo and head tracking.** Full side-by-side rendering and rotational **3DoF** tracking let you look around an anchored screen. Adjust its distance, height, size and curvature, then recenter with a stick click.
- **A picture you can tune.** Scanlines, phosphor detail, glass reflections, PAL/NTSC-inspired signal effects and colour controls. Screen-fitting options keep the full game image inside the tube.
- **Five classic systems.** SNES, NES, Mega Drive / Genesis, Master System and Game Gear, powered by libretro cores.
- **A library that understands your folders.** Pick your ROM root or SD card and browse supported systems, Recent and Favourites. Unrelated console folders stay out of the way.
- **Your music, in the room.** Play MP3 albums or direct MP3 web radio with positional sound and optional room reverb. Use the pause-menu transport and seek bar, and optionally lower game audio while music plays. The last track and position are restored, ready for you to press Play.
- **Controller-first adjustments.** Organised settings pages, compact visual previews, per-option resets, saved setups and per-game picture preferences. Manual save states, automatic resume points and clean screenshots are built in.

Bring your own games and music. Supported cartridge files are uncompressed SNES, NES and the listed Sega systems; ZIP archives, disc systems and BIOS-based consoles are outside this beta's scope.

## What you need

| Platform | Current use |
|---|---|
| **Steam Deck + VITURE Pro 2** | The tested XR setup, including Gaming Mode mono-to-SBS startup. **Decky Loader and the testing version of XR Gaming must already be installed** for Pro 2 tracking, with a CRT XR-supported driver build. |
| **Steam Deck without glasses** | Mono play. The latest automatic launcher includes this path; final hardware acceptance is still pending. |
| **Windows** | A portable local preview with mono, SBS and simulated tracking. Live glasses tracking currently uses the Linux driver. |

The intended setup is XR glasses with **SBS and 3DoF tracking exposed through a compatible XR Gaming driver**. We expect other compatible glasses to work, but **only VITURE Pro 2 has been tested**. Automatic detection currently recognises VITURE; other models may need manual display/profile setup and a compatible driver. SBS and built-in 3DoF alone do not guarantee that CRT XR can access tracking. See [display setup](docs/display-setup.md) and [Gaming Mode handoff notes](docs/SBS-HANDOFF-TEST.md).

## Install on Steam Deck

1. Download the **complete Linux beta package**, rather than GitHub’s source-code archive, and switch your Deck to **Desktop Mode**. Sign in to Steam at least once.
2. For tracked XR, install **Decky Loader → XR Gaming** and confirm it recognises your glasses. **VITURE Pro 2 currently requires XR Gaming’s testing version**, rather than its stable release. CRT XR setup assumes this prerequisite; it does not install the plugin or replace your driver.
3. Extract the package and run **`Install-CRT-XR.sh`**. Choose **Execute / Run** if prompted. Select the tested VITURE Full SBS profile, or Deck / monitor only.
4. Finish any running game and allow setup to close Steam. It installs CRT XR, adds or updates the shortcut, applies the selected resolution profile and installs the supplied Steam artwork. Existing settings, saves and later custom artwork are preserved.
5. After Steam restarts, **Return to Gaming Mode → Library → Non-Steam → CRT XR**.

No SSH, Steam developer interface or administrator password is needed for CRT XR's app installer. The separately installed XR Gaming prerequisite has its own setup requirements. If the script opens as text, or you have several Steam accounts, follow the [full installation guide](docs/GETTING-STARTED.md).

### First launch with glasses

Connect the glasses in **mono**, then launch CRT XR. At the instructions, release the launch button, **press A**, then switch the glasses to **SBS**. The view stays black during the change and the room appears when ready.

The tested VITURE profile uses an explicit **3840 × 1080** Steam game resolution; **Native alone did not work on our test Deck**. Setup prepares that profile. If the view stays black, X retries; return the glasses to mono before using B / Escape to leave.

Open **Game library → Library locations** to choose your ROM folder or SD card. You can explore the built-in test signal before loading a game.

### Windows preview

Extract the complete Windows package and run **`CRT-XR.exe`**. Keep its neighbouring files and folders together. This is an unsigned portable preview; the Steam Deck installer is for Linux.

## ROM folders

In **Game library → Library locations**, select your **main ROM folder**—the folder containing the console folders. An existing EmuDeck-style layout can stay where it is, including on an SD card:

```text
roms/
├── snes/
│   ├── Game.sfc
│   └── RPGs/
│       └── Another game.smc
├── nes/
│   └── Game.nes
├── megadrive/       # genesis/ also works
│   └── Game.md
├── mastersystem/
│   └── Game.sms
└── gamegear/
    └── Game.gg
```

CRT XR discovers supported games in subfolders and presents them by system; you do not need to move ROMs into the app folder. Common folder aliases such as `genesis`, `superfamicom`, `sms` and `gg` are recognised. Folder names help discovery, while the supported file type/content chooses the emulator core. You can also select a single supported system folder or browse to a game directly.

Known unsupported system folders and artwork/BIOS/save folders are skipped when scanning the main library, so a larger multi-system collection is fine. Only supported, recognised cartridges appear. ROMs must be **uncompressed**; ZIP archives are not scanned as games. No ROMs are supplied.

## Controls

Use Steam's **Gamepad With Joystick Trackpad** layout. You do not need to hold the three-lines button to switch Desktop/gamepad mappings.

| Action | Controller | Keyboard |
|---|---|---|
| Open / close menu | L1 + R1 + Start | Escape |
| Recenter | R3 | R |
| Select / adjust a setting | Up/down / left/right | Arrow keys |
| Activate / go back | A / B | Enter / Backspace |
| Change category / subsection | L1/R1 / L2/R2 | Q/E / Z/C |
| Reset selected option | Y | Y |
| Compact adjustment preview | X | X |
| Move TV closer / farther | Right stick, when enabled | Page Up / Page Down |
| Screenshot | Pause menu | F6 |

Music sits above the usual pause-menu actions without taking the default selection. Left/right selects its transport controls or seeks on the timeline; down returns to the menu below. Game controls follow each supported console's layout.

## Updates, help and feedback

Run the installer from a newer complete package to update the existing Steam entry. Previous program versions are retained, and settings/saves live separately from the application. Old **RetroCRT XR** data is copied on first launch without deleting the originals.

- [Getting started and recovery](docs/GETTING-STARTED.md)
- [Picture controls](docs/picture-controls.md) · [Room and view](docs/room-and-view.md) · [Audio](docs/audio.md)
- [Development and builds](docs/DEVELOPMENT.md)
- [Pre-launch checklist](docs/PRE-LAUNCH-CHECKLIST.md) · [Detailed beta review](docs/BETA-REVIEW.md)

For a bug report, use **General → Copy diagnostics** and include your device, Desktop/Gaming Mode, mono/SBS, and steps to reproduce. Review logs before sharing: they can contain local paths or radio URLs.

## Credits and licensing

Built with **Godot** and **libretro**, with credited third-party models, shaders and audio components. See [THIRD_PARTY.md](THIRD_PARTY.md) for authors, licences and modifications.

The licence for our original source is still [under review](docs/LICENCE-PROPOSAL.md). Bundled emulator cores and assets retain their own terms; the complete package must not be described as wholly permissive. Core distribution/provenance and the remaining release checks need resolving before public downloads are published.
