# CRT XR 0.1.0-beta.14 — a cosier room, and testers with other glasses wanted

CRT XR puts a CRT television in front of you in your XR glasses, in a small room, and plays your own retro games and videos on it. This beta is a good place to start if you're new.

## Which file do I download?

| You have | Download | Then |
|---|---|---|
| **Steam Deck** | `CRT-XR-0.1.0-beta.14-SteamDeck.tar.gz` | In Desktop Mode, extract it and double-click **Install CRT XR** |
| **Windows PC** | `CRT-XR-0.1.0-beta.14-Windows.zip` | Extract it and double-click **CRT-XR.exe** |

The `…-source-code.tar.gz` file and GitHub's "Source code" links are for rebuilding and licence compliance, not for playing.

**New to CRT XR?** After installing, open **Game library → Library locations** and choose your main ROM folder (on a Steam Deck with EmuDeck, that's `Emulation/roms`). Your supported consoles appear automatically and nothing is moved or renamed. **About & Help → Using glasses** walks through connecting your glasses. No glasses? Choose **Play on this screen without glasses** for a fixed view on the Deck or your monitor.

**Updating on Steam Deck:** run the new installer; your Steam shortcut, settings and saves are kept. **On Windows:** extract to a new folder; settings and saves live separately and carry over.

## Help us test other glasses

So far CRT XR has only been tested with **VITURE Pro 2**. If you have **XREAL, Rokid or RayNeo** glasses (or anything else with a side-by-side mode), please give this beta a try and tell us how it went.

- **Steam Deck:** head tracking comes from the XR Gaming plugin, so glasses it supports should track. CRT XR recognises VITURE, XREAL, Rokid and RayNeo displays by name for the Gaming Mode side-by-side handoff. **New:** where the XR Gaming driver can switch your glasses into side-by-side itself, CRT XR now asks it to as it starts, and switches them back to 2D when you leave. The VITURE Pro 2 can't be switched this way (the driver reports so), so we don't yet know which glasses can: please tell us what yours did.
- **Windows:** VITURE glasses track through the VITURE SDK. Other glasses can track through any tool that sends **OpenTrack** UDP to `127.0.0.1` port `4242`, such as [opentrack](https://github.com/opentrack/opentrack), [PhoenixHeadTracker](https://github.com/iVideoGameBoss/PhoenixHeadTracker) (XREAL Air) or VertoXR (Rokid, RayNeo). Choose **Controls & XR → Tracking → Tracking source → OpenTrack**.

**What we'd like to hear:**
- your glasses model, platform (Deck or Windows) and, on Windows, the tracking tool you used;
- whether the TV stayed fixed in place as you turned, and any axis you had to invert;
- on the Deck, whether CRT XR found the glasses' display, and whether the glasses **switched into side-by-side by themselves** or you pressed their button;
- whether the picture looked the right size, or you changed **Vertical field of view** in Controls & XR (and to what).

Please open an issue at https://github.com/blackalice/CRT-XR/issues. A short note is plenty; **About & Help → Copy diagnostics** adds useful details. Reports from first-time users are just as welcome: if something was confusing to set up, we want to know.

## New in this beta

**Getting into 3D, and out again**
- **Nothing to press at the start.** On the Steam Deck, the "Get your glasses ready" screen now just asks you to press your glasses' side-by-side button. It goes dark as they switch, and your room appears by itself. The screen is also about twice the size it was through glasses still in 2D.
- **Back to 2D when you leave.** When you exit, a note in each eye asks you to switch the glasses back to 2D, and CRT XR closes as soon as you do, so Steam isn't left doubled. Glasses the XR driver can switch are put back for you.

**A room that feels lived in** (all optional, in **Room**)
- **Lights off.** A new room mood lit only by the TV: the screen's glow now lights the casing, table and props in the picture's own colours, each side of the set taking the colour of its side of the picture. Five complete moods: Lights off, Late night (the default), Dim XR, Warm bedroom and Bright inspection.
- **A soft bloom** around the bright tube in a dark room, as your eyes see it.
- **Your game on the box.** The top game box on the table shows the playing game's cover, from your existing scrapes.
- **TV moments.** A burst of static and a rolling picture as a game or video starts, a **Degauss** button in Picture → CRT, and the tube collapsing to a dot as CRT XR closes.
- **Room sound.** A quiet room, rain on the window, or rain with a ticking clock, and, for those who remember it, the tube's high whine.
- **Follow the time of day.** The room's light shifts gently with the real clock: brighter and cooler by day, warm in the evening.

**Polish**
- **Help that's easier to read.** Using glasses, Controls and Troubleshooting have headings, numbered steps, button pictures and cards instead of blocks of text.
- **An About page.** Select the version in **About & Help** for an animated 3D CRT XR logo, the version and where to find the project.

**Fixes**
- Long game titles no longer push the menu past its edge (the Deck's battery readout made this worse).
- The space under the table no longer catches the TV's light through the tabletop.

**If you're updating:** your screen glow setting is converted to the new scale once, and the TV now lights the room more than before. Turn it down in **Room → Materials → Screen glow** if you prefer.

Everything from beta.10 to beta.13 is here too: zipped games and Sega CD CHD discs, box art from your scrapes, four save slots, room presets, menu depth in SBS 3D, OpenTrack tracking, and your own videos on the CRT with a VCR.

## Known limits

This is still an early beta.

- **Other glasses are untested on real hardware.** On the Deck, only VITURE's display name is confirmed; XREAL, Rokid and RayNeo are matched by brand name, and automatic side-by-side switching depends on the XR Gaming driver supporting your glasses. On Windows, OpenTrack tracking is only as good as the tool sending it, and its axis directions may need inverting.
- Field of view differs between glasses; adjust **Vertical field of view** if the TV seems to slide as you turn.
- Archives: one cartridge per ZIP, Deflate or stored. 7z, RAR and discs inside ZIPs are not supported.
- A `.chd` is treated as Sega CD only inside a Sega CD folder. PC Engine CD is not supported.
- Box art and the cover on the table need an existing scrape; CRT XR does not scrape or download artwork.
- Videos: MP4, M4V and MKV; codecs depend on the FFmpeg in use.
- PC Engine, Atari 2600, Lynx and Vectrex have only been checked with test programs.
- No games, BIOS files, music, videos or artwork are supplied.

Original CRT XR code is MIT; the emulator cores and assets keep their own licences (several cores are GPL, and Snes9x and Genesis Plus GX forbid commercial use; CHD support adds the libchdr, LZMA SDK, zlib and zstd notices). The TV and room sounds are synthesised by CRT XR's own scripts. CRT XR doesn't ship FFmpeg or any tracking tool. See `licenses/` in each download and the source archive on this page. Windows binaries are unsigned.
