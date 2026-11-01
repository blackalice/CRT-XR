# CRT XR 0.1.0-beta.15 — 90s menus, more consoles and music visuals

**The ultimate millennial nostalgia experience for your XR glasses**

PlayStation and Nintendo 64 join the CRT room, with new controller layouts, a 90s console-style menu, an animated startup and music visuals on the tube. This release includes every update since beta.14.1, refreshed Steam artwork and the previous screen-glow, tracking-recovery and NES fixes.

## Which file do I download?

| You have | Download | Then |
|---|---|---|
| **Steam Deck** | `CRT-XR-0.1.0-beta.15-SteamDeck.tar.gz` | In Desktop Mode, extract it and double-click **Install CRT XR** |
| **Windows PC** | `CRT-XR-0.1.0-beta.15-Windows.zip` | Extract it and double-click **CRT-XR.exe** |

The `CRT-XR-0.1.0-beta.15-source-code.tar.gz` download and GitHub's automatic "Source code" links are for rebuilding and licence compliance, not for playing. Keep the corresponding-source download with the app packages when redistributing them.

**New here?** Open **Game Library → Library locations** and choose the folder containing your console folders (for EmuDeck, usually `Emulation/roms`). No games are moved or renamed. No glasses? Choose **Play on this screen without glasses** for a fixed view. On Steam Deck, head tracking needs **Decky Loader and XR Gaming with support for your glasses** installed separately; leave XR Gaming's virtual display off. Windows VITURE tracking needs the separately obtained VITURE x86_64 SDK; it is not bundled.

**Updating:** run the new Steam Deck installer to update the existing shortcut and managed artwork, keeping settings, saves and custom artwork. On Windows, extract to a new folder; preferences and saves live separately and carry over.

## Help us test other glasses and systems

XR use has only been tested with **VITURE Pro 2 on Steam Deck and Windows**. If you have **XREAL, Rokid, RayNeo or other side-by-side glasses**, please try the beta and tell us how it went. Reports from other Windows PCs, controllers and Linux desktops are welcome too; a general Linux desktop installer remains a preview, rather than a separately validated download in this release.

- **Steam Deck:** tracking comes from XR Gaming, so glasses supported by that plugin should track. CRT XR recognises VITURE, XREAL, Rokid and RayNeo displays by name, but only VITURE's handoff has been confirmed on hardware. Where the driver supports it, CRT XR requests automatic side-by-side switching on entry and a return to 2D on exit. VITURE Pro 2 still needs its physical SBS button; please tell us what your glasses do.
- **Windows:** VITURE uses its SDK. Other glasses can use a tool sending **OpenTrack UDP to `127.0.0.1:4242`**, such as [opentrack](https://github.com/opentrack/opentrack), [PhoenixHeadTracker](https://github.com/iVideoGameBoss/PhoenixHeadTracker) for XREAL Air, or VertoXR for Rokid and RayNeo. Select **View → Tracking → Tracking source → OpenTrack**. This path still needs real non-VITURE hardware reports; invert individual axes on the same page if needed.

**Please include:**

- Your glasses model, computer/OS, controller and tracking tool or XR Gaming version.
- Whether the TV stays anchored as you turn, and any axes you inverted.
- Whether the correct display was found and SBS switched automatically or needed a button press.
- Whether you changed **View → Advanced calibration → Vertical field of view**, and to what value.
- Any setup confusion, reconnect/suspend trouble, performance issues or longer-session problems—especially with Nintendo 64 or music visuals.

Open a report at [GitHub Issues](https://github.com/blackalice/CRT-XR/issues). **About & Help → Copy diagnostics** provides useful details; review it before sharing because local paths and radio URLs can appear. First-time setup reports are welcome.

## New since beta.14.1

### PlayStation, Nintendo 64 and console controls

- **PlayStation**, powered by PCSX ReARMed: cue/bin, CHD, PBP, M3U multi-disc lists and zipped discs. ZIPs unpack in the background behind a spinning-disc loading screen. **Change disc** is available for multi-disc games. A real PlayStation BIOS is optional but improves compatibility.
- **Nintendo 64**, powered by Mupen64Plus-Next with GPU rendering at 320×240 through the same CRT picture. The core is pinned to the 2.8 line to avoid the save-state crashes encountered with 3.0. N64 controller handling, right-stick TV adjustment conflicts and resume behaviour have been corrected.
- **Controller layouts:** pick a console layout and press the control you want to assign. Keep console defaults or save a layout for an individual game, with N64 presets including Smash Bros. and twin-stick shooting.
- **Emulation → Consoles / This game:** supported core options now have console defaults and game overrides. Changes apply the next time the game loads; Y restores inheritance. **Info** shows the current core/frame rate and detected BIOS files; **Performance** groups input-delay controls.

### A 90s menu on the CRT

- A new pixel-style console interface with a moving planet, stars, tiles, segmented controls and consistent controller glyphs. Menus appear on the TV by default and retain your tuned picture, including CRT and signal effects. **Menu → Accessibility → Clean menu feed** offers a clearer reading picture; floating placement is still available.
- Animated three-diamond startup, synchronised with tube warm-up, with a boot sound and an optional menu background loop. **Menu → Audio & vibration** controls boot sound, menu sounds, music and vibration separately; menu music has its own volume.
- Shared game/video pause-menu navigation, library shortcuts and Settings/Screenshot/Recenter actions. Video playback keeps its timeline, start-over, stop, tape, shape, subtitle and audio controls.
- A six-tile quick-settings grid on Home and game pause: Room, Picture, Game volume, TV distance, Screen height offset and Music volume. TV placement opens a compact live preview. Video pause uses video volume and playback-specific controls.
- Settings use clearer categories, subsections, icons and contextual help. Long game lists use pages of 50 and **Jump to letter**. Continue shows its saved-frame preview. Steam Deck starts with controller prompts even in Desktop Mode; keyboard input switches prompts.
- Updated three-diamond branding and Steam library artwork. The test signal and disc-loading screen now use a 240-line CRT raster.

### Music visuals on the tube

- Expand **Music** and choose **Visualiser**, beside **Browse albums**, for projectM visuals driven by your MP3 albums or direct MP3 radio. Three original presets are bundled.
- **A / Space** plays/pauses music, **left/right** selects a preset, **up/down** changes brightness and **Y** toggles automatic changes. Automatic mode changes every 30 seconds; reduced animation holds the current preset.
- **B / Escape** opens the menu without stopping music or visuals. Select Visualiser again to return; **Audio → Visualiser → Stop visualiser** restores the previous game/video. Preferences persist without starting playback automatically.
- projectM ships as a replaceable shared library, with its notices, patched source and build materials. User preset import is not yet available.

## Release checks

The release passed 56 isolated Godot regression suites on Windows, including video playback with FFmpeg, controller layouts, core settings, tracking and music visuals. All 73 Python checks passed on Linux; Windows passed its applicable Python checks, with 18 Linux-specific checks skipped. Native components and projectM were rebuilt for both platforms. Music visuals produced visible output on Windows and Linux; Linux rendering used software OpenGL, so this is not a Steam Deck performance result. Exported-package and source-integrity checks are recorded in the attached `BUILD-RECORD.json`.

## Known limits and feedback areas

This remains an early public beta. Other glasses, general Linux desktops, extended suspend/reconnect behaviour and long-session visualiser performance still need user testing. Prior hardware checks do not establish compatibility with every device.

- Nintendo 64 and PlayStation do not support the separate input-preview core. Game compatibility varies; the selected emulator core's save states should not be assumed interchangeable with another core or version.
- PC Engine, Atari 2600, Lynx and Vectrex still need real-game testing beyond diagnostic programs. PC Engine CD, SuperGrafx and Sega 32X are unsupported.
- Cartridges can be alone in a stored/Deflate ZIP. 7z, RAR and Sega CD discs inside ZIPs are unsupported. Sega CD CHDs must be inside a recognised Sega CD folder; Sega CD and Atari Lynx need their BIOS/boot ROM files.
- Box art comes from your existing scrape; CRT XR does not download it. Video formats are MP4, M4V and MKV, with codec support determined by FFmpeg. Windows video-library setup downloads FFmpeg on request; Steam Deck uses SteamOS's libraries.
- Glasses differ in field of view; adjust **View → Advanced calibration** if the TV appears to slide as you turn. SBS alone does not guarantee an accessible tracking source.
- Windows packages remain unsigned. Proprietary VITURE SDK files and tracking tools are not bundled. No commercial games, BIOS files or personal media are included.

Original CRT XR code is MIT; emulator cores, projectM and other components retain their own licences. Several cores use the GPL; Snes9x and Genesis Plus GX restrict commercial use. Preserve the `licenses/` notices and corresponding source supplied with the release. The original visualiser presets are MIT. See [licensing scope](https://github.com/blackalice/CRT-XR/blob/main/LICENSING.md) and [distribution notes](https://github.com/blackalice/CRT-XR/blob/main/docs/CORE-DISTRIBUTION.md).
