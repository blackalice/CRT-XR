# Emulator distribution review - beta.14.1

Reviewed 17 October 2026 for beta.5 and updated 22 October 2026 for the ten-core
beta.9 collection, against the pinned sources in scripts/build-release-cores.py.
Beta.14.1 rebuilds Nestopia for Linux and Windows from the same pinned revision
with the recorded boot-background initialization patch. The upstream archive,
patch, build recipes and their hashes accompany the binaries and source download.
The beta.10 to beta.12 cores are the same ten builds; beta.13 rebuilds Genesis Plus GX from the same pinned source with CHD support (HAVE_CHD=1) and keeps the other nine; beta.14 ships the same ten builds as beta.13. FFmpeg is not distributed: Linux uses
the system's copy, and on Windows the user chooses to download it (THIRD_PARTY.md).

## In-process copyleft cores

The treatment below was written for Nestopia and applies equally to every
copyleft core in the collection: Nestopia (GPL-2.0-or-later), Gambatte (GPL-2.0
only, per its file headers), Beetle PCE Fast, Beetle Lynx and Beetle NeoPop
(GPL-2.0-or-later; Beetle Lynx also contains zlib-licensed Handy code), Stella
(GPL-2.0), vecx (GPL-3.0), PCSX ReARMed (GPL-2.0-or-later, with its LGPL
Lightrec and GNU Lightning recompiler libraries built in) and Mupen64Plus-Next
(GPL-2.0, with GLideN64). mGBA is MPL-2.0, a file-level copyleft: its source
is supplied unchanged and remains under the MPL. Each copyleft core is combined
in process with the MIT host only, never with another core, so the GPL version
of each core governs its own combination.

### Nestopia (the original review)

CRT XR loads Libretro cores with dlopen/LoadLibrary, resolves retro_* function pointers, and shares video/audio/input callbacks and Libretro structures. This is close in-process integration, not a command-line subprocess boundary. The release therefore follows the conservative GPL combined-program interpretation for the host when distributed for use with Nestopia. Original CRT XR contributions remain available under MIT, which permits GPL-compatible redistribution; the GPL obligations of the NES host/core combination are not removed by that MIT grant.

Release requirements implemented:

- Retain Nestopia's full COPYING and per-file notices. Original Nestopia headers permit GPL version 2 or later; retain those exact notices rather than asserting a different blanket version for every imported file.
- Supply complete corresponding application/host source, native bindings source, exact core source archives, the scripts used to build/install, compiler versions, make arguments and binary/source hashes. Provide the corresponding-source download alongside both executable packages; do not rely solely on a mutable upstream link or a source revision prefix in a binary.
- Retain the MIT permission notices on original code. Do not add a non-commercial restriction to the Nestopia/GPL-covered source or its permitted redistribution. No warranty is offered.
- Do not distribute a proprietary host-only replacement without assessing these obligations.

Primary interpretation: https://www.gnu.org/licenses/gpl-faq.en.html#GPLPlugins and https://www.gnu.org/licenses/gpl-faq.en.html#GPLAndPlugins . GPL v2 source distribution: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html#section3 . This document records a conservative engineering compliance approach, not a court determination.

## Other cores are separately licensed modules

Only one core library type is in use at a time. emulation_session.gd closes/deinitialises the old core before loading another. The optional input preview loads a second, renamed copy of the same core library (into the system temporary folder, removed afterwards) and transfers that core's own save state between the two copies; it never combines different cores. Cores do not link to or call each other. The release is a collection of separately built core libraries, not a single binary linking Nestopia to Genesis Plus GX or Snes9x. The distribution treatment relies on that separation; it must be reassessed if core code is merged or libraries are linked together. Providing all source does not make GPL-incompatible code compatible.

- Snes9x at 1bcc369e89f08243e0a462882fb1f3e42e51de3a permits non-commercial use/copy/modification/distribution with its notices. Do not sell it, include it in a commercial product/promotion, or describe the complete collection as commercially unrestricted. The libretro build uses snes_ntsc; its licence and the other retained upstream notices are packaged. JMA/xBRZ notices are retained conservatively even though the libretro source list does not compile those desktop filter/decompression modules.
- Genesis Plus GX at 393f70cd64c7334564c19a424c383f53986c13f4 prohibits sale/commercial use and requires complete source for modified redistributions. The exact complete tree is supplied. Its embedded Nuked OPN2 component has LGPL-2.1-or-later terms; its source and build scripts are provided for rebuilding/relinking, and no restriction on debugging modifications to that component is imposed by CRT XR. Full upstream component notices are retained. Sega CD images (.cue/.bin and CHD) are supported; physical-drive (cdrom://) access is disabled in this build. CHD support compiles the libchdr (BSD-3-Clause), LZMA SDK 19.00 (public domain), zlib 1.2.11 (zlib licence) and zstd (BSD) sources bundled in the exact upstream tree under `libretro/deps`; their notices ship as `cores/libchdr-LICENSE.txt`, `LZMA-SDK-LICENSE.txt`, `zlib-LICENSE.txt` and `zstd-LICENSE.txt`. The Sega CD and Atari Lynx BIOS files are never distributed: users supply their own.
- libretro.h keeps its MIT notice. Godot/godot-cpp keep their MIT and bundled component notices. The release makes no claim to relicense any core, asset, engine dependency or imported shader.

This collection is offered free of charge. MIT permission for original code is not a promise that the downloaded multi-core package can be sold. If commercial distribution or a monolithic combined-core build is desired, obtain compatible replacements/permissions first.

## Exact source versus official binaries

beta.4's downloaded official core archives are retained only as local backups. beta.5 uses new local builds from pinned git objects. Source archives are created directly with git archive, so working-tree CRLF conversion and local edits cannot silently affect core input. core-builds.json records every actual .dll/.so hash, archive hash, compiler and make arguments. This establishes which sources produced these binaries; it does not claim bit-for-bit reproduction of Libretro's official builds or all future compilers.

Follow docs/DEVELOPMENT.md to build, or run python3 scripts/build-release-cores.py all in the compiler environment. Do not replace a core binary without regenerating its provenance. Source snapshots include the upstream licence texts and dependencies included in the respective git trees. The corresponding-source bundle also includes the host and binding build inputs. Release validation checks source and binary hashes before packaging.

## TV and other assets

The TV source is kept byte-for-byte, SHA-256 6342fcebb5faae40854d3639f97b386b302b11f99a0f2bb6857601b877b9dff5. Its GLB metadata points to the same creator/model ID. The 2022 creator listing explicitly links CC BY 4.0; the current listing exposes the same 2021 upload UID and identical source-file metadata. docs/license-evidence/crt-tv.json records the comparison, retrieval hashes and later Standard label without altering the original GLB. We rely on the historical grant for this unchanged uploaded version. The converted GLB is not represented as byte-identical to a 2022 conversion.

Retain Timothy Ahene's credit, source and CC BY 4.0 link, and the modification notice in THIRD_PARTY.md. The table's CC BY 4.0 attribution and carpet/sound CC0 provenance are retained separately. These artistic assets are not blanket-relicensed under the application's MIT or the NES combination's GPL terms.

The source package additionally contains the pinned godot-cpp tree and Godot 4.5.1 engine source, with the upstream engine/component notices retained. SOURCE-ACCESS.md in each executable package names and hashes the companion source archive. Keep that archive on the same GitHub release/download page.
