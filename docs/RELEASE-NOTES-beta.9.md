# CRT XR 0.1.0-beta.9 — 13 consoles, a furnished room and a simpler install

## Which file do I download?

| You have | Download | Then |
|---|---|---|
| **Steam Deck** | `CRT-XR-0.1.0-beta.9-SteamDeck.tar.gz` | In Desktop Mode, extract it and double-click **Install CRT XR** |
| **Windows PC** | `CRT-XR-0.1.0-beta.9-Windows.zip` | Extract it and double-click **CRT-XR.exe** |

Each download now opens with just what you need and a short **HOW TO INSTALL** / **HOW TO START** file; everything else is tucked into folders. The `…-source-code.tar.gz` file and GitHub's "Source code" links are for rebuilding and licence compliance, not for playing.

**Updating on Steam Deck:** run the new installer; your Steam shortcut, settings and saves are kept. **On Windows:** extract to a new folder; settings and saves live separately and carry over.

## New consoles

Eight more systems join SNES, NES, Mega Drive, Master System and Game Gear, each built from pinned source:

- **Game Boy / Game Boy Color** (Gambatte) and **Game Boy Advance** (mGBA)
- **PC Engine / TurboGrafx-16** (Beetle PCE Fast)
- **Sega CD / Mega-CD** (Genesis Plus GX; `.cue` or `.bin` with the Sega CD header)
- **Atari 2600** (Stella), **Atari Lynx** (Beetle Lynx)
- **Neo Geo Pocket / Color** (Beetle NeoPop; `.ngp`, `.ngpc`, `.ngc`)
- **Vectrex** (vecx)

Sega CD and Lynx need their own BIOS files, which are never included. CRT XR finds them in the `bios` folder next to your `roms` folder (the EmuDeck layout), in `~/Applications/CRT-XR/bios` on the Deck (kept across updates), or next to `CRT-XR.exe` on Windows.

## Play

- **Reduce input delay now works on every console with clean sound.** The preview runs in a separate copy of the emulator, so the game's audio is never rewound; development builds could buzz on Game Boy and Sega games. Measured on the Deck at 0.3–1.9 ms per frame. Option: Controls & XR → Separate preview core.
- **Reset game** in the pause menu, like the console's reset button (battery saves and save states are kept).
- Left/right in game lists jumps ten games and the list scrolls with the selection.

## Picture

- **Your own picture is never lost to a preset:** choosing a preset keeps your custom look, and **Custom** in Quick settings brings it back.
- **Save up to three of your own picture presets** (Picture → Presets), shown by name in Quick settings. Undo is available after applying a preset.
- CRT strength sliders read as a share of their range (100% is the strongest setting).

## Room

- **New floors:** a 90s confetti carpet (default), a wool carpet or wooden floorboards (Room → Materials → Floor). The rug is gone.
- **Props** (Room → Props): a clock radio showing the real time on a dim red display, a full-size VCR on a new shelf under the TV, and a stack of unbranded game boxes. Nothing blinks; each can be switched off. Music now seems to play from the clock radio's side of the room.

## Menus

- **Quick settings** first, on the home and pause menus and in the sidebar: TV position, recenter, picture preset and volumes.
- **Accessibility:** larger menu text, stronger contrast, reduced animation and optional menu sounds (About & Help → Accessibility).
- **Save previews** show a thumbnail and time before you load or overwrite a save.
- **Controller text entry** for setup names, folder paths and radio URLs.
- Full game titles on demand (Y), scroll-edge cues and compact music controls.
- Deck-first controller prompts (L1/R1/L2/R2), clearer labels, reasons shown beside unavailable options, and empty Recent/Favourites shelves hidden until they have games.

## Performance

About half the draw calls and 25 MB less video memory than before, leaving room for heavier consoles and more props: no shadow map when nothing can cast one, cheaper edge fades, signal passes only on new game frames, compressed and right-sized textures, and less main-thread work (faster pixel conversion, no rewriting unchanged battery saves). Sustained slowdowns now pause the input preview for that game instead of dropping game frames.

## Known limits

This is still an early beta. Only VITURE Pro 2 has tested head tracking. PC Engine, Atari 2600, Lynx and Vectrex have only been checked with test programs, not real games. Sega CD needs the BIOS matching the disc's region; a different region's BIOS can produce a generic load error. ZIP/CHD files and PC Engine CD are not supported. No games, BIOS files or music are supplied.

Original CRT XR code is MIT; the emulator cores and assets keep their own licences (several cores are GPL, and Snes9x and Genesis Plus GX forbid commercial use). See `licenses/` in each download and the source archive on this page. Windows binaries are unsigned.

Report issues at https://github.com/blackalice/CRT-XR/issues with your platform, glasses, XR Gaming version and steps to reproduce.
