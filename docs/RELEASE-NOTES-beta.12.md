# CRT XR 0.1.0-beta.12 — testers with other glasses wanted

## Which file do I download?

| You have | Download | Then |
|---|---|---|
| **Steam Deck** | `CRT-XR-0.1.0-beta.12-SteamDeck.tar.gz` | In Desktop Mode, extract it and double-click **Install CRT XR** |
| **Windows PC** | `CRT-XR-0.1.0-beta.12-Windows.zip` | Extract it and double-click **CRT-XR.exe** |

The `…-source-code.tar.gz` file and GitHub's "Source code" links are for rebuilding and licence compliance, not for playing.

**Updating on Steam Deck:** run the new installer; your Steam shortcut, settings and saves are kept. **On Windows:** extract to a new folder; settings and saves live separately and carry over.

## Help us test other glasses

So far CRT XR has only been tested with **VITURE Pro 2**. If you have **XREAL, Rokid or RayNeo** glasses (or anything else with a side-by-side mode), please give this beta a try and tell us how it went. In-app, **About & Help → Using glasses** walks through setup for your platform.

- **Steam Deck:** head tracking comes from the XR Gaming plugin, so glasses it supports should track. CRT XR recognises VITURE, XREAL, Rokid and RayNeo displays by name for the Gaming Mode side-by-side handoff.
- **Windows:** VITURE glasses track through the VITURE SDK. Other glasses can track through any tool that sends **OpenTrack** UDP to `127.0.0.1` port `4242`, such as [opentrack](https://github.com/opentrack/opentrack), [PhoenixHeadTracker](https://github.com/iVideoGameBoss/PhoenixHeadTracker) (XREAL Air) or VertoXR (Rokid, RayNeo). Choose **Controls & XR → Tracking → Tracking source → OpenTrack**.

**What we'd like to hear:**
- your glasses model, platform (Deck or Windows) and, on Windows, the tracking tool you used;
- whether the TV stayed fixed in place as you turned, and any axis you had to invert;
- on the Deck, whether CRT XR found the glasses' display and switched into side-by-side;
- whether the picture looked the right size, or you changed **Vertical field of view** in Controls & XR (and to what).

Please open an issue at https://github.com/blackalice/CRT-XR/issues. A short note is plenty; **About & Help → Copy diagnostics** adds useful details.

## New in this beta

**Your library**
- **Box art from your own scrapes.** If you've scraped with EmuDeck, ES-DE or RetroDECK, covers appear beside each game and on the home screen's Continue row, read from your existing `downloaded_media` (or media folders beside your ROMs). Nothing is downloaded.
- **Home greets you with your last game**: its name, console and when you played. Game lists say when each game was last played.

**Playing**
- **Four save-state slots per game**, each with a picture and when it was saved. Loading a save takes you straight back into the game.
- **The resume screen** shows a large picture of where you left off beside Continue and Start fresh.

**The room**
- **Room presets:** save up to three rooms of your own (lighting, shadows, floor and props) under **Room → Presets**, and switch rooms from the pause menu or Quick settings, alongside Warm bedroom, Bright inspection and Dim XR.

**Menus**
- **Depth in side-by-side 3D:** the menu floats just in front of the TV, the selected row lifts slightly and the room dims behind it. **Curved menu** bends it gently towards you. Both are under **About & Help → Accessibility**, with **Controller vibration** and its strength.
- **Pause menus at a glance:** actions sit in a two-column grid of tiles with icons, under a larger Resume; the game pause menu fits on one screen.
- **The time and the Deck's battery** in the menu header.
- Clearer wording throughout: the game or video by name, "Fixed view" instead of an alarming tracking message when you play without glasses, confirmations that ask their question plainly, and "Settings saved" only when something changed.

Everything from beta.10 and beta.11 is here too: your own videos on the CRT with a VCR (on-screen text, a VHS tape look and mechanism sounds), and OpenTrack tracking.

## Known limits

This is still an early beta.

- **Other glasses are untested on real hardware.** On the Deck, only VITURE's display name is confirmed; XREAL, Rokid and RayNeo are matched by brand name. On Windows, OpenTrack tracking is only as good as the tool sending it, and its axis directions may need inverting.
- Field of view differs between glasses; adjust **Vertical field of view** if the TV seems to slide as you turn.
- Box art needs an existing scrape; CRT XR does not scrape or download artwork.
- Videos: MP4, M4V and MKV; codecs depend on the FFmpeg in use.
- PC Engine, Atari 2600, Lynx and Vectrex have only been checked with test programs. Sega CD needs the BIOS for the disc's region. ZIP/CHD files and PC Engine CD are not supported.
- No games, BIOS files, music, videos or artwork are supplied.

Original CRT XR code is MIT; the emulator cores and assets keep their own licences (several cores are GPL, and Snes9x and Genesis Plus GX forbid commercial use). CRT XR doesn't ship FFmpeg or any tracking tool. See `licenses/` in each download and the source archive on this page. Windows binaries are unsigned.
