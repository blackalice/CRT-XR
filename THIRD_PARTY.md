# Third-party components

## CRT shaders

* Timothy Lottes' `crt-lottes.glsl`, public domain. The tube shader adapts its
  Gaussian beam reconstruction and neighbouring-row sampling. The shared
  `crt_beam.gdshader` cache uses the same horizontal kernels.
* Viacheslav Slavinsky's `pal-singlepass.glsl`, Copyright 2016, BSD 2-Clause.
  The shared composite shader adapts its carrier modulation/demodulation,
  20-tap FIR filter and colour matrices. NTSC uses the supplied YIQ matrices
  with an NTSC carrier and line phase approximation.

Original sources, full notices and pinned provenance are in `third_party/shaders/`.
The export script copies them into `licenses/shaders/` alongside the application.

## Native dependencies

The app's emulator host dynamically loads an existing Libretro core. No console
BIOS, commercial ROMs or third-party game artwork are supplied.

* Godot C++ bindings, MIT license. Source commit:
  [e83fd090](https://github.com/godotengine/godot-cpp/tree/e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77).
  The bindings license is copied alongside the extension build.
* Snes9x, its own license. Source commit:
  [1bcc369e](https://github.com/snes9xgit/snes9x/tree/1bcc369e89f08243e0a462882fb1f3e42e51de3a).
  The complete license and referenced component licenses are copied into `cores/`
  and into the local Linux package. The source is fetched by a reproducible setup
  script; it is not copied into the application source tree.
* Libretro API header, MIT license, Copyright 2010–2018 The RetroArch team.
  Its full header notice is copied into `cores/libretro-header-LICENSE.txt`.
* Nestopia Libretro, GPL-2.0, Martin Freij, Nestopia UE contributors and
  Rupert Carmichael. Upstream source revision:
  https://github.com/libretro/nestopia/tree/06a8949e0b3cf60e3a38a374b1426bf40fccb9a0
  Full licence: `cores/Nestopia-LICENSE.txt`.
* Genesis Plus GX, Charles MacDonald, Eke-Eke and other credited contributors.
  Its custom licence prohibits sale and commercial use; bundled components
  have additional terms reproduced in `cores/Genesis-Plus-GX-LICENSE.txt`.
  Upstream source revision:
  https://github.com/libretro/Genesis-Plus-GX/tree/393f70cd64c7334564c19a424c383f53986c13f4

The new cores in this local review build are official Libretro buildbot binaries.
`cores/core-builds.json` records download URLs, archive hashes and source revisions;
complete upstream source snapshots are included under `cores/sources/`.
Windows core version strings contain the recorded upstream revision prefixes.
Compiler flags/toolchain details for the official binaries are not independently
reproduced here. `scripts/build-cartridge-cores.sh` provides a source-build route
for the existing compiler container, pending validation after Docker is available.
Retain these sources and notices with the binaries. Review the combined app/core
licensing before a public release; these core licences do not imply that every
component of the application is permissively licensed or commercially usable.

The generated diagnostic cartridges are original, asset-free test programs.
Their source generators, `tests/make_probe_rom.py` and
`tests/make_multicore_probes.py`, are provided under CC0-1.0.
They are generated under ignored `build/` and are not automatically included in exports.

## Optional CRT cabinet

**CRT TV**, by **Timothy Ahene**.
Original model: https://sketchfab.com/3d-models/crt-tv-9ba4baa106e64319a0b540cf0af5aa9e

Historical licence evidence: the creator's listing archived on **29 September
2022 at 23:04:21 UTC** displays **CC Attribution** for that same model ID:
https://web.archive.org/web/20220929230421/https://sketchfab.com/3d-models/crt-tv-9ba4baa106e64319a0b540cf0af5aa9e

The user supplied a screenshot of that archive on 15 October 2026; a local
copy is retained at `build/license-evidence/crt-tv-2022-09-29-listing.png`.
The archive could not be independently fetched by the research tool. The
screenshot does not expose the destination of its licence link, so the exact
CC version remains to be recorded. An older third-party derivative explicitly
credits Timothy Ahene's model as CC BY 4.0:
https://blendswap.com/blend/31310

Modifications in RetroCRT: rescaling/alignment, replacement live screen/glass,
material adjustments, new baked occlusion and grain, reduced and GPU-compressed
textures, prepared Godot resources, hidden rear hardware removal and constrained rear-panel simplification, and
replacement badge using the user's
Phonysonic SVG. No endorsement by the original creator is implied.

This record documents historical licensing evidence; it does not relicense the
asset or assert that later revisions or separately accepted download terms are
covered. Preserve applicable creator notices and identify the licence/version
for the source used in a public release. The model is separate from the app's
source-code licence. See `docs/crt-model-local.md` for asset handling.

## CRT power-on sound

`assets/audio/crt-power-on.wav` is a short edited excerpt from **TV, CRT, turning on off, static, click (2012).wav** by **TRP**, published on [Freesound](https://freesound.org/people/TRP/sounds/616850/) under **CC0 1.0 Universal**. Modification and redistribution, including commercial use, are permitted. Details, source-preview and asset hashes, editing notes, and the licence text are in `third_party/audio/` and included with exported builds under `licenses/audio/`.
