# Third-party components

Original CRT XR code uses MIT; see LICENSE and LICENSING.md. The notices below retain their own terms.

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
* Nestopia Libretro, GPL version 2 (the original core file headers permit version 2 or later; preserve individual notices), Martin Freij, Nestopia UE contributors and
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

On 17 October 2026 the archived HTML was independently retrieved. Both its
visible licence link and embedded model metadata identify **Creative Commons
Attribution 4.0 International**: https://creativecommons.org/licenses/by/4.0/ .
The model ID and author match the listing above. Retrieval URL, date and HTML
SHA-256 are recorded in `docs/license-evidence/crt-tv.json`. The original user
screenshot and retrieved HTML are retained locally under `build/license-evidence/`.
This verifies the historical licence version; it does not certify that every
later downloadable GLB is byte-identical to that historical revision.

Modifications in CRT XR: rescaling/alignment, replacement live screen/glass,
material adjustments, new baked occlusion and grain, reduced and GPU-compressed
textures, prepared Godot resources, hidden rear hardware removal and constrained rear-panel simplification, and
replacement badge using the user's
Phonysonic SVG. No endorsement by the original creator is implied.

This record documents historical licensing evidence; it does not relicense the
asset or assert that later revisions or separately accepted download terms are
covered. Preserve the CC BY 4.0 attribution, licence link and modification notice; retain
the provenance of the source revision used in a public release. The model is separate from the app's
source-code licence. See `docs/crt-model-local.md` for asset handling.

## CRT power-on sound

`assets/audio/crt-power-on.wav` is a short edited excerpt from **TV, CRT, turning on off, static, click (2012).wav** by **TRP**, published on [Freesound](https://freesound.org/people/TRP/sounds/616850/) under **CC0 1.0 Universal**. Modification and redistribution, including commercial use, are permitted. Details, source-preview and asset hashes, editing notes, and the licence text are in `third_party/audio/` and included with exported builds under `licenses/audio/`.

## Wide wooden table

"Wood Drawer & Tables Set" by brandon_grey (https://sketchfab.com/brandondmc10),
https://sketchfab.com/3d-models/wood-drawer-tables-set-958db224ef514b2eabd69ac0a4e59ca0
Licensed under Creative Commons Attribution 4.0 International:
https://creativecommons.org/licenses/by/4.0/ .
The supplied GLB embeds this author, source and licence in its asset metadata.
Changes: extracted the fourth, wide table; flattened transforms, regenerated tangents,
prepared mipmapped BC7 textures, and fitted proportions to the application's CRT.
Other pieces from the set are not included. Source and preparation details: docs/wood-table.md.

## Carpet surface

Carpet 012 by ambientCG, https://ambientcg.com/view?id=Carpet012 .
CC0 1.0 Universal: https://creativecommons.org/publicdomain/zero/1.0/ .
Uses the original 1K colour, OpenGL normal and roughness maps. Runtime shading
uses a warm neutral tint, softened normal strength, mip filtering and no displacement.
Download archive SHA-256: f5c459f278a3b50dc5c2bf535b8c3b6fd4bb6fc458c836b64023961b167fe4f6.

## Streaming MP3 decoder

[dr_mp3 0.7.4](https://github.com/mackron/dr_libs/blob/master/dr_mp3.h), David Reid, used under MIT-0 (the selected dual-license option). Vendored source and SHA256 are recorded in `third_party/audio/dr_mp3-LICENSE.txt`; exported builds include the notice in `licenses/audio/`. Based on minimp3 (CC0). No music or station recordings are bundled.

## Super Retro Game Console

“Super Retro Game Console” by **ELIZION**, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). [Original model](https://sketchfab.com/3d-models/super-retro-game-console-d672d0ac1d6a4d238314d6675f8f92b2), [creator](https://sketchfab.com/ELIZION).

Modified for CRT XR: controller/buttons and hidden underside fittings removed, remaining console meshes merged, 1K textures mipmapped and compressed, authored occlusion combined into base colour, placement and separate cable meshes added. Creator has not endorsed CRT XR. Original downloads remain unchanged; hashes and preparation details accompany the exported asset.

## Godot engine

Godot Engine 4.5.1, MIT licence, Godot Engine contributors. Official engine licence and third-party copyright notices accompany builds under `licenses/godot/`, copied from `third_party/godot/` (upstream tag 4.5.1-stable). Engine source: https://github.com/godotengine/godot/tree/4.5.1-stable .
