# Using CRT XR

Your games, videos and music, and how to drive it all. For glasses setup see [glasses guides](glasses/README.md).

## ROM folders

In **Game Library → Library locations**, select your **main ROM folder**—the folder containing the console folders. An existing EmuDeck-style layout can stay where it is, including on an SD card:

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
├── gamegear/
│   └── Game.gg
├── gb/              # gbc/ and gameboy/ also work
│   └── Game.gb
├── gba/
│   └── Game.gba
├── pcengine/        # tg16/ turbografx16/ also work
│   └── Game.pce
├── segacd/          # megacd/ also works; needs the BIOS files
│   ├── Game.cue
│   └── Game.bin
├── n64/             # nintendo64/ also works
│   └── Game.z64             # .n64 and .v64 too
├── psx/             # ps1/ playstation/ also work; a BIOS is optional
│   ├── Game (USA).zip       # a zipped cue and its tracks
│   ├── Other Game.chd
│   └── Long Game.m3u        # lists each disc, for Change disc
├── atari2600/       # atari/ atarivcs/ also work
│   └── Game.a26
├── atarilynx/       # needs lynxboot.img
│   └── Game.lynx
├── ngpc/            # ngp/ neogeopocket/ also work
│   └── Game.ngpc
└── vectrex/
    └── Game.vec
```

Windows users can open **Computer drives** directly in the browser, including mapped drives, or use **Open folder or network path…** with a path such as `\\server\share\roms`. Connect protected shares in Windows File Explorer first. Choose **Use this folder for my library** to save the root.

CRT XR discovers supported games in subfolders and presents them by system; you do not need to move ROMs into the app folder. Common folder aliases such as `genesis`, `superfamicom`, `sms` and `gg` are recognised. Folder names help discovery, while the supported file type/content chooses the emulator core. You can also select a single supported system folder or browse to a game directly.

Known unsupported system folders and artwork/BIOS/save folders are skipped when scanning the main library, so a larger multi-system collection is fine. Supported, recognised games appear, including zipped cartridges, Sega CD CHDs and PlayStation discs (cue/bin, CHD, PBP, M3U or zipped). No ROMs are supplied.

PC Engine, Atari 2600, Lynx and Vectrex still need real-game testing beyond diagnostic programs. PC Engine CD, SuperGrafx, Sega 32X, 7z/RAR archives and Sega CD discs inside ZIPs are unsupported. PlayStation has been played on the Steam Deck; a real BIOS (`scph5501.bin` and friends, in the `bios` folder) improves compatibility. Sega CD needs the BIOS matching the disc's region; a different region's BIOS can produce a generic load error. See [supported formats and BIOS setup](emulation.md).

## Videos

In **Video Library**, select **Choose a video folder** and pick the folder holding your videos; subfolders are included. Your videos then appear in **Video Library**. MP4, M4V and MKV files are listed, with any `.srt` subtitles beside them.

- **Steam Deck:** nothing to install; SteamOS's FFmpeg is used and decoding runs on the GPU.
- **Windows:** choose **Set up video playback** in **Video Library**. CRT XR downloads FFmpeg's five LGPL video libraries (about 55 MB) from the public [BtbN builds](https://github.com/BtbN/FFmpeg-Builds), checks them and keeps them in its own user-data folder.
- **Other Linux systems:** install FFmpeg 7.1 or 8 with your package manager.

While watching, **A** pauses, **D-pad left/right** skips 10 seconds (hold to scrub), **up/down** skips a minute, **Y** changes broadcast framing and **X** changes the audio track. The pause menu has a timeline you can scrub. Open **Video settings** from the Video Library or go to **Settings → Videos** for default framing, picture lines, interlacing, VCR effects, subtitles and hardware decoding. See [Videos](emulation.md#videos) for details.

## Music and visualiser

Expand **Music** on the home or pause menu to browse MP3 albums or play direct MP3 web radio. Select **Visualiser**, beside **Browse albums**, to put music visuals on the CRT. It pauses the previous game or video; **B / Escape** opens the menu while the visualiser stays active, and selecting **Visualiser** again returns to it.

While viewing, **A / Space** pauses or plays music, **left/right** selects a preset, **up/down** changes brightness and **Y** toggles automatic preset changes. Automatic mode changes presets every 30 seconds; reduced animation keeps the current preset. **Sound → Music** has the visualiser settings. Preferences are remembered, but playback does not start automatically.

Three original presets are included, and your own `.milk` presets can be added (see Extras below). Steam Deck performance and long-session checks remain pending. See the [music visualiser guide](music-visualiser.md).

## Controls

On Steam Deck, use Steam's **Gamepad With Joystick Trackpad** layout. On Windows, use an Xbox/XInput-compatible controller directly. You do not need to hold the three-lines button to switch Desktop/gamepad mappings.

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

Continue or library setup leads the home screen. Home and game pause menus include a six-tile Quick settings grid for Room, Picture, Game volume, TV position, TV and Fit. Select distance or height to open the compact placement preview. Videos use the same layout with video volume and playback-specific controls. In system game lists, left/right or L1/R1 changes pages of 50 games; **Jump to letter** navigates longer lists. Steam Deck starts with controller glyphs, including in Desktop Mode; pressing a keyboard key switches to keyboard prompts.

**Reset game** is in the pause menu. **Games → Input delay → Use a second emulator copy** controls the separate emulator copy used by **Reduce input delay**. Save and share your own picture looks under **Picture → Looks** (see below). **Plain picture behind menus**, larger text, stronger contrast and reduced animation are under **Menu & access → Accessibility**. **Menu & access → Layout → Menu on the TV** switches between the CRT and floating menu. **Menu depth** places the floating menu in front of the TV and dims the room in side-by-side 3D. The compact preview does not dim the room. **Sound → Menu sounds** controls menu clicks, the boot sound and menu music (its volume is in **Sound → Volumes**); **Menu & access → Vibration** controls controller vibration. Music uses a compact strip when idle or paused and expands its transport and timeline during playback. Left/right selects playback controls or seeks; up/down moves between music and game actions. Game controls follow each supported console's layout.

## Picture looks

**Picture → Looks** has five built-in looks and your own. **New look from this picture** saves the current tube, colour and signal settings as a named look. Open a look to:

- **Use for this game**, or **Use for all *console* games**;
- **Choose games and consoles…** from your library, ticking as many as you like;
- **Edit this look**: every game and console using it changes with it;
- **Copy share code** to share it, or **Add a shared look** to add someone else's from the clipboard.

Looks are linked, not copied. A game's picture is your defaults, then its console's look and changes, then its own look and changes. Fitting (Fit, Fill, Stretch, position) always stays with each game. If one game looks different, **Picture → Looks** says why and offers **Clear this game's own changes**.

## Basic and advanced settings

Settings start with the everyday options. Fine-tuning rows (signal detail, lens calibration, picture position, lamp placement and more) are one press away: select the **advanced settings hidden** row on any page, or turn on **Menu & access → Accessibility → Show advanced settings**. Hidden settings keep working.

## Scenes

**Scenes & help → Scenes** keeps three scenes: a look, a room and your view, saved together.

## Extras

- **Saturday Morning TV** (Video Library): your videos as an always-on channel. Each day has its own running order from 6 am, so you tune in mid-programme. Up and Down change programme.
- **Rewind and fast-forward** (Games → Input delay, off by default): hold L2 to rewind, R2 to fast-forward, on 8- and 16-bit consoles.
- **Surprise me** on the Game Library picks a random game.
- **Box art**: **Get box art** on the Game Library (or **Download missing box art** in Library locations) fetches covers from libretro-thumbnails for games your scrapes don't cover, matched by game name. Art is kept in CRT XR's own folder and shows beside your games, on Continue, when you start a game and on the box on the table. Library locations also has **Show box art** and **Download for new games automatically**.
- **Flat view**: press **Y** on Home or the pause menu to switch between the room and Flat view; the chip beside Exit shows which is in use.
- **Sleep timer** (Sound → Music) and a screensaver that **switches the TV off** (Menu & access → Screensaver → Style).
- **Your own visualiser presets**: put projectM / MilkDrop `.milk` files in a folder called `Visualiser presets` inside your music folder.
- **Menu shortcut**: **Menu & access → Layout → Menu shortcut → Also hold Select** lets you hold Select instead of pressing L1 + R1 + Start.
