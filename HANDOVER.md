# Current handover: beta.10 (video playback)

Updated 23 October 2026. Beta.10 adds video playback with a VCR, merged from the
`video-playback` branch (PR #1): a native FFmpeg decoder loaded at runtime
(7.1 and 8.x), the optional Windows FFmpeg download, subtitles, interlacing,
library extras, VCR on-screen text, the VHS tape look, synthesised VCR sounds and
a Videos settings category, plus menu typography and contrast work. Design,
Deck findings and status are in `docs/VIDEO-PLAYBACK-PLAN.md`; user-facing
changes in `docs/RELEASE-NOTES-beta.10.md`.

Release candidates are prepared under `dist/release-preparation/v0.1.0-beta.10/`
(START-HERE.md, build record, upload folder). Open items: the owner's long-play
acceptance on the Deck, DVD/Blu-ray picture subtitles from real rips, and
headset readability of the lighter Regular text.

Beta.11 (23 October 2026) adds the OpenTrack UDP tracking source
(`scripts/tracking/opentrack_tracking.gd`, Controls & XR → Tracking source) and
EDID matching for XREAL, Nreal, Rokid and RayNeo on the Deck
(`display-probe.py`). Both await testers with real non-VITURE glasses.

Beta.12 (23 October 2026) adds menu depth and curve in SBS, controller
vibration, two-column pause tiles, a home Continue row, room presets, box art
from existing scrapes (`scripts/content/box_art.gd`), four save slots, a
battery/time status line and a Using glasses guide. Release notes keep the
focus on testers with non-VITURE glasses.

Beta.13 (23 October 2026) ships the work below plus a fix for main-thread
hashing of large discs (CHDs are named by their header; other hashes are cached)
and the Deck battery read. Sonic CD (CHD) was booted on the Deck with the real
BIOS. Release notes keep the glasses-testing focus and welcome new users.

After beta.12: zipped cartridges and Sega CD CHD discs play
(`scripts/content/rom_archive.gd`, `core_registry.gd`; Genesis Plus GX is
rebuilt with `HAVE_CHD=1`; tests in `tests/archives.gd`). A CHD counts as Sega CD
only inside a Sega CD folder; real CHD playback was checked on the Deck with Sonic CD and the US BIOS. `menu_controller.gd` now keeps layout, rendering, navigation and
input; page builders and their actions live in helpers it owns: `menu_games.gd`
(library, browser, lists, launch), `menu_play.gd` (pause/home, save states),
`menu_videos.gd`, `menu_music.gd`, `menu_pictures.gd` (presets) and
`menu_keys.gd` (on-screen keyboard), reached as `menu.games.…` and so on.

The beta.9 notes below are historical.

## Beta.9 release preparation

Updated 22 October 2026 after reviewing the imported Claude Code session
`d518952e-4052-4c26-a94b-c4a2be670600` and the working tree based on `640d405`.

The latest user task is to prepare a GitHub beta and simplify installation on
Steam Deck (the lead platform) and Windows. The session stopped after writing
`docs/RELEASE-NOTES-beta.9.md`, before exporting or validating the new packages.
The older multicore notes below predate the later work and are historical.

## Existing progress preserved

- Thirteen systems and ten pinned cores, BIOS discovery beside an EmuDeck ROM
  tree and in the persistent Deck installation, and `.ngc` recognition.
- Separate preview cores to avoid audio rewind/buzz, game reset, custom picture
  preservation and three saved picture presets, and list paging/scroll fixes.
- Performance improvements, compressed prepared textures and cabinet AO;
  three floors with confetti as default; clock radio, VCR shelf and game boxes.
- Deck-oriented menu labels, accessibility, save previews and controller text entry.
- Beta.9 version, streamlined package arrangement and installation instructions,
  nested Deck installer launcher and Windows `tracking/` helper lookup.

## Continuation work

- Re-exported both platforms into
  `dist/release-preparation/v0.1.0-beta.9/build/` without replacing older builds.
- Refreshed `third_party/cores/release-builds.json` from the twenty verified
  builds; the builder now maintains this evidence and the checker rejects stale
  source-only rebuild records. The previous six-record file could not rebuild
  the new cores from the source archive.
- Added nested-path and file-URI installer launcher coverage and a reusable
  `tests/package_smoke.gd` for exported resources and nine diagnostic systems.
- Corrected source-before-package ordering in the development commands and
  updated the release checklist and source rebuild wording for beta.9.
- Local archives, checksums, validation results and remaining limitations are
  recorded in `dist/release-preparation/v0.1.0-beta.9/START-HERE.md` and
  `upload/BUILD-RECORD.json`. These generated files are ignored by Git.

## Remaining work

- Review the local candidate and the full existing source diff, then commit,
  tag and publish the matching beta.9 snapshot if requested. No Git history,
  remote publication or Steam Deck installation is changed by this continuation.
- Real-game coverage for PC Engine, Atari 2600, Lynx and Vectrex; clean-account
  installation, Windows SDK setup and longer XR/suspend/reconnect testing.
- Sega CD's BIOS gate still accepts any regional BIOS; a disc for another
  region can fail with a generic core rejection. Disclosed in the beta.9 notes.
- Preserve the old core recovery archives until their owner chooses to remove them.

---

# Historical handover: multi-core expansion

Transient working note. Delete once the work lands.

## Goal

Grow CRT XR from 5 systems / 3 libretro cores to 14 systems / 10 cores. Steam Deck (Linux x86_64) is the main target, with Windows as the second. Every core is built locally from a pinned git commit, with its provenance recorded in `cores/core-builds.json`. Everything is uncommitted on the working tree (`git status` shows about 25 modified files).

| System | Core (`cores/<core>_libretro.{so,dll}`) | Status |
|---|---|---|
| SNES / NES / MD / SMS / GG | snes9x / nestopia / genesis_plus_gx | existing |
| Game Boy / Color | gambatte | built |
| Game Boy Advance | mgba (CMake recipe) | built |
| PC Engine / TG-16 | mednafen_pce_fast | built, **`.sgx` claim is false** (see below) |
| Sega CD | genesis_plus_gx (needs `bios_CD_{U,E,J}.bin`) | built |
| Sega 32X | genesis_plus_gx | **false: GPGX has no 32X** (see below) |
| Atari 2600 | stella (artifact `stella2023`) | built |
| Atari Lynx | mednafen_lynx (needs `lynxboot.img`) | built |
| Neo Geo Pocket / Color | mednafen_ngp | built |
| Vectrex | vecx | **build fails** (fix below) |

## Status (2026-10-22, second takeover)

Steps 1-3 of the original handover are **done and verified**. Decisions A and B were answered: **drop 32X, drop `.sgx`**. CRT XR now covers 13 systems with 10 cores.

- `build-release-cores.py all` completes. `check-core-sources.py` verifies all 20 records, and the licence files are extracted.
- vecx builds with `HAS_GPU=0`.
- **Windows static linking was restored.** The earlier refactor had dropped `LDFLAGS=-static…`, so six DLLs imported `libwinpthread-1.dll`, which isn't shipped. The flags are now appended to `CC`/`CXX` for Windows make builds. Every core DLL now imports only system DLLs, and every Linux `.so` needs only libc, libm, libstdc++ and libgcc_s.
- `build-emulation.sh` no longer overwrites recorded cores. It tests against `build/snes9x-<platform>` and only seeds `cores/` when a core is missing.
- The native host test passes 27/27. Two fixes were needed: the mock had lost `retro_get_system_av_info`, and the fullpath check needs the first host closed, because only one core can be active.
- Both GDExtension binaries were rebuilt in WSL. The old Docker CMake caches were moved to `build/emulation-*.docker-cache`.
- `python scripts/test-beta.py` passes 29/29. The fixes were:
  - a valid GBA probe header;
  - `encode_c_string` replaced, because Godot 4 doesn't have it;
  - a replay comparison for Gambatte, whose serialised state contains volatile bytes;
  - a Lynx check that tests the BIOS gate rather than stub rejection;
  - `library_cards` using folders that are still unsupported.
- 32X and SuperGrafx were removed from the registry, aliases, menu, probes, tests and docs. `32x`, `sega32x` and `supergrafx` folders are now in `UNSUPPORTED`. `.md`/`.bin` images whose header reads `SEGA 32X` are rejected rather than booted as Mega Drive games.

## Still open

- Runtime testing on a Steam Deck and in Windows XR with real games. Only probes have been exercised so far.
- `docs/CORE-DISTRIBUTION.md` and `docs/DEVELOPMENT.md` are still stale (see "Known risks" below).
- Check the `THIRD_PARTY.md` licence lines against the extracted `cores/*-LICENSE*` files.
- Prune `archive/cores-before-source-build-*` from 2026-10-22.

## Changes made in this session (Opus takeover)

- `scripts/build-release-cores.py`
  - The GPGX revision was truncated to 39 hex characters, which caused the `rev-parse` assert failure. It is now the full `393f70cd…986c13f4`, and the assert message names the repo.
  - GPGX now uses `HAVE_CDROM=0` (it was `1`). That flag is libretro-common physical-drive `cdrom://` access, not Sega CD emulation. `.cue`/`.bin` loading is unaffected.
  - mGBA is configured with `-DLIBMGBA_ONLY=ON -DBUILD_LIBRETRO=ON`, matching the upstream libretro CI. This disables optional host libraries.
  - CMake provenance now records configure `&&` build. Before, the configure args, including the toolchain and static-link flags, were lost.
- `scripts/emulation/core_registry.gd`
  - `stage_bios(system, destination)` now copies only that system's `bios_any` files and refreshes a staged copy when its SHA-256 differs.
  - Before, it copied **every** file in `bios/`, and never refreshed. That is dangerous if `bios/` points at an EmuDeck tree with GB-sized PS2 or Switch dumps.
  - The caller in `emulation_session.gd` is updated.
- `scripts/setup-emulation.ps1`: added `Fetch-Pinned` for the 7 new repos, with URLs from the actual `tools/*` remotes.
- `scripts/export-linux.ps1`, `scripts/export-windows.ps1` and `scripts/package-beta.py`: the core lists grew from 3 to 10. Before, releases would have shipped without the new cores.
- `scripts/build-linux.sh --export` now copies `cores/*_libretro.so`. It was snes9x-only, which was already stale.

## Done by the previous model (written but not verified by anyone at runtime)

- Registry: 14 systems; `.cue` resolution by the first FILE entry; Sega CD/32X header detection for `.bin`/`.md`; per-system aspect ratios and control strings.
- BIOS gate: `load_rom` refuses Lynx or Sega CD without a BIOS **before** stopping the current game. The status reads "needs its BIOS…". The BIOS source is `<app>/bios` or `CRT_XR_BIOS`.
- Host: `need_fullpath` path, with no 32 MiB cap for disc images.
- Folder aliases, glyphs, menu identity colours, probes (`gb`, `gba`, `pce`, `a26`, `32x`), new `multicore.gd` checks, and docs (README, GETTING-STARTED, QUICKSTART, emulation.md, THIRD_PARTY).

## Known risks and unfinished items

- `docs/CORE-DISTRIBUTION.md` is **not updated**. It still describes beta.5 with 3 cores and says "CD/CHD support is disabled". It needs:
  - Sega CD enabled, CHD and physical-drive access off.
  - The in-process GPL treatment extended to Gambatte, the Beetle cores, Stella and vecx (the GPL version is per core).
  - mGBA under MPL-2.0.
- `docs/DEVELOPMENT.md:17` lists only 4 pinned sources. Line 26 references `build-cartridge-cores.sh` and `third_party/cores/release-builds.json`. Update it for 10 cores, and note that CMake is needed for mGBA (it is already in `Dockerfile.emulation`).
- The `THIRD_PARTY.md` licence and author lines for the new cores were written by the previous model and **not checked** against each `COPYING`. Examples are vecx "GPLv3", Stella "GPLv2" and the Gambatte authors. Verify them after the licences are extracted.
- Sega CD BIOS: `bios_satisfied` accepts **any one** of U/E/J, but GPGX needs the file for the disc's region. A JP disc with only the U BIOS fails with the generic "Core rejected ROM".
- The source-release path (when there is no `.git`) validates against `third_party/cores/release-builds.json`. Check that it covers the new cores.
- No Steam Deck runtime testing has been done for any new core.
