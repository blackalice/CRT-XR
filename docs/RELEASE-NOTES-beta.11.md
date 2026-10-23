# CRT XR 0.1.0-beta.11 — first steps beyond VITURE

## Which file do I download?

| You have | Download | Then |
|---|---|---|
| **Steam Deck** | `CRT-XR-0.1.0-beta.11-SteamDeck.tar.gz` | In Desktop Mode, extract it and double-click **Install CRT XR** |
| **Windows PC** | `CRT-XR-0.1.0-beta.11-Windows.zip` | Extract it and double-click **CRT-XR.exe** |

The `…-source-code.tar.gz` file and GitHub's "Source code" links are for rebuilding and licence compliance, not for playing.

**Updating on Steam Deck:** run the new installer; your Steam shortcut, settings and saves are kept. **On Windows:** extract to a new folder; settings and saves live separately and carry over.

## Other glasses

So far only VITURE Pro 2 has been tested. This release opens the door to other brands. **If you have XREAL, Rokid or RayNeo glasses, please try it and tell us how it goes.**

- **Windows: OpenTrack tracking.** CRT XR can now follow any tool that sends **OpenTrack** head tracking over UDP to this computer (`127.0.0.1`, port `4242`).
  - Examples: [opentrack](https://github.com/opentrack/opentrack) itself, [PhoenixHeadTracker](https://github.com/iVideoGameBoss/PhoenixHeadTracker) for XREAL Air, or VertoXR for Rokid and RayNeo.
  - Start the tool, then choose **Controls & XR → Tracking → Tracking source → OpenTrack**. The status shows *OpenTrack UDP / LIVE 3DoF* once poses arrive.
  - OpenTrack has no agreed direction for each axis. If turning or tilting goes the wrong way, use **Invert yaw/pitch/roll** on the same page.
  - SBS works as before: switch the glasses to their full side-by-side mode and choose their display.
- **Steam Deck: more glasses recognised.**
  - Tracking comes from the XR Gaming plugin, so glasses it supports should already track.
  - CRT XR now also recognises **XREAL, Rokid and RayNeo** displays by name for the Gaming Mode SBS handoff, not just VITURE.
  - A 32:9 desktop monitor with the same resolution isn't mistaken for glasses.

**What we'd like to hear:** your glasses model and platform, the tracking tool you used, whether the view stayed fixed as you turned, and any axis you had to invert. On the Deck, also say whether CRT XR found the glasses' display. Please open an issue at https://github.com/blackalice/CRT-XR/issues.

## Also in this release

- Fixed a shader error logged at startup by the VHS tape look; the picture is unchanged.

Everything from beta.10 is here too: your own videos on the CRT, with VCR on-screen text, a VHS tape look and mechanism sounds. See the [beta.10 notes](https://github.com/blackalice/CRT-XR/releases/tag/v0.1.0-beta.10).

## Known limits

This is still an early beta.

- Other brands' glasses are **untested on real hardware**. On the Deck, only VITURE's display name has been confirmed; XREAL, Rokid and RayNeo are matched by their brand names. On Windows, the OpenTrack source is only as good as the tool sending to it.
- Field of view differs between glasses. If the TV seems to slide as you turn, adjust **Vertical field of view** in Controls & XR.
- Videos: MP4, M4V and MKV only. Which codecs work depends on the FFmpeg in use. DVD and Blu-ray picture subtitles haven't been checked against real rips.
- PC Engine, Atari 2600, Lynx and Vectrex have only been checked with test programs. Sega CD needs the BIOS for the disc's region. ZIP/CHD files and PC Engine CD are not supported.
- No games, BIOS files, music or videos are supplied.

Original CRT XR code is MIT; the emulator cores and assets keep their own licences (several cores are GPL, and Snes9x and Genesis Plus GX forbid commercial use). CRT XR doesn't ship FFmpeg or any tracking tool. See `licenses/` in each download and the source archive on this page. Windows binaries are unsigned.
