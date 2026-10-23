# CRT XR 0.1.0-beta.13 — testers with other glasses wanted

CRT XR puts a CRT television in front of you in your XR glasses, in a small room, and plays your own retro games and videos on it. This beta is a good place to start if you're new.

## Which file do I download?

| You have | Download | Then |
|---|---|---|
| **Steam Deck** | `CRT-XR-0.1.0-beta.13-SteamDeck.tar.gz` | In Desktop Mode, extract it and double-click **Install CRT XR** |
| **Windows PC** | `CRT-XR-0.1.0-beta.13-Windows.zip` | Extract it and double-click **CRT-XR.exe** |

The `…-source-code.tar.gz` file and GitHub's "Source code" links are for rebuilding and licence compliance, not for playing.

**New to CRT XR?** After installing, open **Game library → Library locations** and choose your main ROM folder (on a Steam Deck with EmuDeck, that's `Emulation/roms`). Your supported consoles appear automatically and nothing is moved or renamed. **About & Help → Using glasses** walks through connecting your glasses. No glasses? Choose **Play on this screen without glasses** for a fixed view on the Deck or your monitor.

**Updating on Steam Deck:** run the new installer; your Steam shortcut, settings and saves are kept. **On Windows:** extract to a new folder; settings and saves live separately and carry over.

## Help us test other glasses

So far CRT XR has only been tested with **VITURE Pro 2**. If you have **XREAL, Rokid or RayNeo** glasses (or anything else with a side-by-side mode), please give this beta a try and tell us how it went.

- **Steam Deck:** head tracking comes from the XR Gaming plugin, so glasses it supports should track. CRT XR recognises VITURE, XREAL, Rokid and RayNeo displays by name for the Gaming Mode side-by-side handoff.
- **Windows:** VITURE glasses track through the VITURE SDK. Other glasses can track through any tool that sends **OpenTrack** UDP to `127.0.0.1` port `4242`, such as [opentrack](https://github.com/opentrack/opentrack), [PhoenixHeadTracker](https://github.com/iVideoGameBoss/PhoenixHeadTracker) (XREAL Air) or VertoXR (Rokid, RayNeo). Choose **Controls & XR → Tracking → Tracking source → OpenTrack**.

**What we'd like to hear:**
- your glasses model, platform (Deck or Windows) and, on Windows, the tracking tool you used;
- whether the TV stayed fixed in place as you turned, and any axis you had to invert;
- on the Deck, whether CRT XR found the glasses' display and switched into side-by-side;
- whether the picture looked the right size, or you changed **Vertical field of view** in Controls & XR (and to what).

Please open an issue at https://github.com/blackalice/CRT-XR/issues. A short note is plenty; **About & Help → Copy diagnostics** adds useful details. Reports from first-time users are just as welcome: if something was confusing to set up, we want to know.

## New in this beta

**Your games, as you keep them**
- **Zipped games play.** A cartridge on its own in a ZIP shows up in the library under its own name and plays like the plain file. It shares battery saves, save states and its resume point with the same game unzipped, so nothing is lost if you zip or unzip your collection.
- **Sega CD discs as CHD.** Put `.chd` discs in your `segacd` or `megacd` folder (subfolders are fine). Like `.cue`/`.bin` discs, they need the Sega CD BIOS for their region (`bios_CD_U.bin`, `bios_CD_E.bin` or `bios_CD_J.bin`) in the `bios` folder beside your `roms` folder. With EmuDeck, that's `Emulation/bios`.

**Smoother**
- **No more freeze around disc games.** Choosing, starting or leaving a Sega CD game used to stall everything for a couple of seconds while CRT XR read the whole disc; it now takes a few hundredths of a second.

**Fixes**
- **The Steam Deck's battery level now shows** beside the time in the menu header; before, only the time appeared.

Everything from beta.10 to beta.12 is here too: box art from your scrapes, four save slots, room presets, menu depth in SBS 3D, OpenTrack tracking, and your own videos on the CRT with a VCR.

## Known limits

This is still an early beta.

- **Other glasses are untested on real hardware.** On the Deck, only VITURE's display name is confirmed; XREAL, Rokid and RayNeo are matched by brand name. On Windows, OpenTrack tracking is only as good as the tool sending it, and its axis directions may need inverting.
- Field of view differs between glasses; adjust **Vertical field of view** if the TV seems to slide as you turn.
- Archives: one cartridge per ZIP, Deflate or stored. 7z, RAR and discs inside ZIPs are not supported. A large zipped game takes a moment longer to start (about half a second for a 16 MB GBA game on the Deck).
- A `.chd` is treated as Sega CD only inside a Sega CD folder. PC Engine CD is not supported.
- Box art needs an existing scrape; CRT XR does not scrape or download artwork.
- Videos: MP4, M4V and MKV; codecs depend on the FFmpeg in use.
- PC Engine, Atari 2600, Lynx and Vectrex have only been checked with test programs.
- No games, BIOS files, music, videos or artwork are supplied.

Original CRT XR code is MIT; the emulator cores and assets keep their own licences (several cores are GPL, and Snes9x and Genesis Plus GX forbid commercial use; CHD support adds the libchdr, LZMA SDK, zlib and zstd notices). CRT XR doesn't ship FFmpeg or any tracking tool. See `licenses/` in each download and the source archive on this page. Windows binaries are unsigned.
