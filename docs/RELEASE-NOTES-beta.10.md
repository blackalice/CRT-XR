# CRT XR 0.1.0-beta.10 — your videos on the CRT, with a VCR

## Which file do I download?

| You have | Download | Then |
|---|---|---|
| **Steam Deck** | `CRT-XR-0.1.0-beta.10-SteamDeck.tar.gz` | In Desktop Mode, extract it and double-click **Install CRT XR** |
| **Windows PC** | `CRT-XR-0.1.0-beta.10-Windows.zip` | Extract it and double-click **CRT-XR.exe** |

The `…-source-code.tar.gz` file and GitHub's "Source code" links are for rebuilding and licence compliance, not for playing.

**Updating on Steam Deck:** run the new installer; your Steam shortcut, settings and saves are kept. **On Windows:** extract to a new folder; settings and saves live separately and carry over.

## Videos

Watch your own MP4, M4V and MKV files on the tube, through the same picture, screen light and TV sound as your games.

- **Opt-in.** In **Game library → Library locations**, choose a video folder. A **Videos** card then appears after your consoles. Without a folder nothing changes.
- **Steam Deck: nothing to install.** CRT XR uses SteamOS's own FFmpeg and decodes on the GPU (VA-API). A DVD-quality episode uses about 5% of one CPU core.
- **Windows: one small download.** **Set up video playback** fetches only FFmpeg's five video libraries (LGPL, about 55 MB) from the public BtbN builds, checks each one and keeps them in CRT XR's own folder. Videos then play straight away, decoded on the GPU (D3D11VA).
- **Made for the tube.** Widescreen videos can be **Letterbox**, **14:9**, **Fill 4:3** or **Stretch** (Y while watching; each video remembers its own). They play at 240 lines by default, so scanlines and the phosphor mask show; 480 is a sharper option. Interlaced recordings use **field motion**, like broadcast TV, or **blend** the fields.
- **Their own picture.** Videos start from **Auto composite**, which picks PAL or NTSC from the frame rate, and keep their own picture settings. You can also give them the same picture as games.
- **Controls.** A pauses, the D-pad left/right skips 10 seconds (hold to scrub), up/down skips a minute, Y changes the picture shape and X the audio track. The Start menu has a timeline you can scrub, plus picture shape, tape look, subtitles and audio track.
- **Subtitles** from the video's own tracks (text, DVD and Blu-ray) or an `.srt` file beside it, drawn into the picture like broadcast subtitles. Each video remembers its choice.
- **Find your place.** Every video resumes where you stopped. **Continue watching** sits at the top of the list and in the library. **Search** covers the whole video folder, with thumbnails in the list.

## The VCR

The recorder under the TV now plays its part:

- **Green on-screen text**: PLAY, PAUSE, FF, REW and STOP in classic VCR lettering, drawn through the CRT.
- **Tape look** (**VHS** or **Worn VHS**): softer detail, smeared colour, wobbling lines and a torn bottom edge, with noise bars rolling through as you fast-forward or rewind. A worn tape adds dropouts and a shaky pause. It's in the Start menu while watching.
- **Mechanism sounds**: clunks for play, pause and stop, and the motor's whir while seeking. They follow the game volume.
- The VCR's display shows the **tape counter** with a play, pause, FF or REW symbol.

Everything is under a new **Videos** settings category with **Picture**, **VCR** and **Playback** tabs, and each part can be switched off.

## Menus

- **Clearer type**: proper Regular, SemiBold and Bold weights for body text, titles and headings.
- **Easier to scan**: the categories sit on their own panel with an amber marker, tabs sit on a baseline with an amber underline, and shortcuts show as key chips.
- **Selectors** show as **‹ value ›** and line up with on/off settings.
- **File screens** share one layout: where you are, this folder's action, its contents with icons, and other places to go.

## Room

The game boxes beside the TV now have printed artwork, lit to match the room.

## Known limits

This is still an early beta.

**Videos:**
- MP4, M4V and MKV only. DVD folders (VIDEO_TS), ISOs, menus and streaming aren't supported.
- Which codecs work depends on the FFmpeg in use. SteamOS's covers H.264, HEVC, AV1, VP9 and MPEG-2.
- Other Linux systems need FFmpeg 7.1 or 8 installed.
- DVD and Blu-ray picture subtitles haven't been checked against real discs' rips yet.

**Games and hardware:**
- Only VITURE Pro 2 has tested head tracking.
- PC Engine, Atari 2600, Lynx and Vectrex have only been checked with test programs, not real games.
- Sega CD needs the BIOS matching the disc's region.
- ZIP/CHD files and PC Engine CD are not supported.
- No games, BIOS files, music or videos are supplied.

Original CRT XR code is MIT; the emulator cores and assets keep their own licences (several cores are GPL, and Snes9x and Genesis Plus GX forbid commercial use). New this release: Open Sans (SIL OFL), VCR OSD Mono (free to use, per its author) and original, CC0 VCR sounds. CRT XR doesn't ship FFmpeg; it uses the system's copy, or the copy you choose to download on Windows. See `licenses/` in each download and the source archive on this page. Windows binaries are unsigned.

Report issues at https://github.com/blackalice/CRT-XR/issues with your platform, glasses, XR Gaming version and steps to reproduce.
