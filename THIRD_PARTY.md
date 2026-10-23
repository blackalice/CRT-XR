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
  Serves Mega Drive, Master System, Game Gear and Sega CD.
  Its custom licence prohibits sale and commercial use; bundled components
  have additional terms reproduced in `cores/Genesis-Plus-GX-LICENSE.txt`.
  Upstream source revision:
  https://github.com/libretro/Genesis-Plus-GX/tree/393f70cd64c7334564c19a424c383f53986c13f4
* Gambatte Libretro (Game Boy / Game Boy Color), GPL version 2 (its file headers grant version 2 only),
  singlam/tch and the Gambatte contributors. Upstream source revision:
  https://github.com/libretro/gambatte-libretro/tree/d9d6cd06382d1ced30de34d56d3609452323dab1
  Full licence: `cores/Gambatte-LICENSE.txt`.
* mGBA (Game Boy Advance), Mozilla Public License 2.0 (individual files keep
  their notices), Jeffrey Pfau and contributors. Upstream source revision:
  https://github.com/libretro/mgba/tree/7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6
  Full licence: `cores/mGBA-LICENSE.txt`.
* Beetle PCE Fast (PC Engine / TurboGrafx-16), GPL version 2 or
  later, the Mednafen team. Upstream source revision:
  https://github.com/libretro/beetle-pce-fast-libretro/tree/3f946f277aef3aa99a95551618bbcd1dd2bda0d9
  Full licence: `cores/Beetle-PCE-FAST-LICENSE.txt`.
* Beetle Lynx (Atari Lynx), GPL version 2 or later with Zlib-licensed
  components, the Mednafen team. Upstream source revision:
  https://github.com/libretro/beetle-lynx-libretro/tree/fcdefcfb3c11d6d2e71be076a5d3df2e88ab73ed
  Full licence: `cores/Beetle-LYNX-LICENSE.txt`.
* Beetle NeoPop (Neo Geo Pocket / Color), GPL version 2 or later, the Mednafen
  team. Upstream source revision:
  https://github.com/libretro/beetle-ngp-libretro/tree/a50d5ac288a81f2104ddf43195a4efdd15c72227
  Full licence: `cores/Beetle-NGP-LICENSE.txt`.
* Stella (Atari 2600), GPL version 2, Bradford W. Mott, Stephen Anthony and
  the Stella team. Upstream source revision:
  https://github.com/libretro/stella/tree/ba52c43b9eda950eb0c0eec69cda9b17dee8c39b
  Full licence: `cores/Stella-LICENSE.txt`.
* vecx (Vectrex), GPL version 3, the vecx and libretro-vecx contributors.
  Upstream source revision:
  https://github.com/libretro/libretro-vecx/tree/dccff5402a16d1ea7c112095a8e42632bf149506
  Full licence: `cores/Vecx-LICENSE.md`.

Release cores are locally compiled from the exact revisions above. `cores/core-builds.json`
records the actual binary/source archive SHA-256 hashes, compiler versions and
build arguments (make, or CMake for mGBA). Complete upstream source snapshots are under `cores/sources/`.
The release also supplies the corresponding application/host/bindings source and
build materials. Earlier buildbot binaries are kept only in ignored local backups.
No bit-for-bit equivalence with Libretro's official builds is claimed. See
`docs/CORE-DISTRIBUTION.md` for the conservative GPL treatment of the NES
in-process combination, component separation and commercial-use restrictions.

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
The current listing was also fetched: its uploaded-version UID
`43f147becf8c4edfada8951d27d34850` and source-file metadata match the archived
2022 listing. The supplied GLB identifies that same model ID; its original
Standard label is preserved unchanged. We rely on the earlier CC BY 4.0 grant
for this unchanged uploaded model, without claiming that converted GLB bytes
are identical across conversion dates. The provenance record includes the
source hash and comparison details.

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

## Video playback (FFmpeg headers)

Video playback uses the operating system's own FFmpeg libraries, loaded at runtime (on SteamOS 3.8, FFmpeg 7.1: libavcodec 61, libavformat 61, libavutil 59, libswscale 8, libswresample 5). CRT XR does not compile, link or ship any FFmpeg code, library or codec; if the libraries are missing, videos are simply not offered. Only FFmpeg 7.1.1's public headers are vendored, for compiling the loader, in `native/emulation/third_party/ffmpeg-61/` under the GNU LGPL 2.1 or later (`COPYING.LGPLv2.1` there; source tarball and SHA-256 in its `README.md`). Codec availability and any codec licensing follow the operating system's FFmpeg build.

## Super Retro Game Console

“Super Retro Game Console” by **ELIZION**, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). [Original model](https://sketchfab.com/3d-models/super-retro-game-console-d672d0ac1d6a4d238314d6675f8f92b2), [creator](https://sketchfab.com/ELIZION).

Modified for CRT XR: controller/buttons and hidden underside fittings removed, remaining console meshes merged, 1K textures mipmapped and compressed, authored occlusion combined into base colour, placement and separate cable meshes added. Creator has not endorsed CRT XR. Original downloads remain unchanged; hashes and preparation details accompany the exported asset.

## Godot engine

Godot Engine 4.5.1, MIT licence, Godot Engine contributors. Official engine licence and third-party copyright notices accompany builds under `licenses/godot/`, copied from `third_party/godot/` (upstream tag 4.5.1-stable). Engine source: https://github.com/godotengine/godot/tree/4.5.1-stable .
