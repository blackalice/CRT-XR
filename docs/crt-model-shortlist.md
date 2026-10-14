# Existing CRT models to evaluate

Research checked 14 October 2026. This is an asset shortlist, not an import or
Steam Deck performance test. The procedural CRT remains in the application.

## Recommendation

The user's subsequent photo references establish a different target: a black or
charcoal 14-inch domestic television, with a rounded cabinet, curved glass and
controls underneath. The consumer-TV candidates below now take priority. The
studio/computer models remain background alternatives.

### Consumer-TV candidates following the photo references

| Candidate | Publisher information | Assessment / unresolved checks |
| --- | --- | --- |
| [CRT TV 14 Inch with Remote and Wall Stand — Mitrech](https://www.cgtrader.com/3d-models/electronics/video/crt-tv-14-inch-with-remote-and-wall-stand) | Specifically advertised as 14-inch; TV alone 1,182 triangles, set 3,208; 4K PBR textures; Blender, FBX and OBJ offered. Search listing displayed US$35 one-time purchase, subject to checkout. Royalty Free License (no AI) shown by the listing. | First paid candidate to compare with the references. Publisher preview shows a dark grey consumer set. Source geometry, screen separation, curvature and dimensions still need inspection. Separate TV/remote/stand does not establish separate screen/glass meshes. |
| [CRT TV — Timothy Ahene](https://sketchfab.com/3d-models/crt-tv-9ba4baa106e64319a0b540cf0af5aa9e) | Public API reports 15,937 triangles and Free Standard license. The [Blender shader adaptation](https://blendswap.com/blend/31310) identifies the subject as Panasonic CT-20G14A, a 20-inch design. | Panasonic consumer-TV direction, rather than an exact 14-inch reproduction. Current source license differs from the older adaptation's CC BY credit; resolve provenance and applicable terms before integration. Do not assume reuploads establish permission. |
| [Old CRT TV for EEVEE — ghostcat](https://blendswap.com/blend/24857) | CC0; Blender 2.9x, 34.2 MB. Creator says this was a quickly made background object with messy geometry, and later corrected its scale. | Free fallback for adaptation; weaker starting point for a close-up realism target. No verified 14-inch dimensions or geometry count. |

The [Blendkit CRT catalogue](https://www.blendkit.com/?query=tags%3Acrt) also
lists a free Toshiba 13A25. Its individual detail page could not be fetched, so
its license, geometry and appearance have not been verified and it is only a
research lead.

No candidate has been bought, downloaded or imported. Screen size labels are
publisher claims; actual dimensions have not been measured. Scaling a 20-inch
cabinet does not reproduce the control/button proportions of a real 14-inch set.
The cabinet style can be reproduced while retaining a comfortable virtual image
size; physical model scale and viewing distance should be considered together.

Publisher previews:

![Mitrech 14-inch CRT publisher preview](https://img-new.cgtrader.com/items/2647084/25b522b50b/crt-tv-14-inch-with-remote-and-wall-stand-3d-model-low-poly-obj-fbx-stl-blend.jpg)

![Timothy Ahene CRT TV publisher preview](https://media.sketchfab.com/models/9ba4baa106e64319a0b540cf0af5aa9e/thumbnails/fcd9ba980384414b881527691b496295/23ffc638e36c48e3a9ef718479a723aa.jpeg)

### Earlier studio/computer alternatives

Evaluate **Sony PVM-14L2 by Poring** for the realistic studio-monitor look.
Evaluate **CRT Computer Monitor by fizyman** alongside it as a simpler integration
candidate: its author explicitly describes separate shell/glass texture sets and
materials. Both listings are downloadable and declare CC BY 4.0 in the public
Sketchfab model API. Keep **Poly Haven Television 01** as a CC0 alternative if an
older wooden television suits the desired room better.

| Model | Published geometry | Declared license | Useful fit | Still to inspect |
| --- | --- | --- | --- | --- |
| [Sony PVM-14L2 — Poring](https://sketchfab.com/3d-models/sony-pvm-14l2-crt-tv-ab19c2419c2647299ce96d027b3e7f5e) | 12,516 triangles, 6,755 vertices | CC BY 4.0 | Named real monitor; promising direction for a detailed main display | Actual download formats, separate screen/glass meshes, UVs, material count and texture sizes |
| [CRT Computer Monitor — fizyman](https://sketchfab.com/3d-models/crt-computer-monitor-f2ff0013f86e4cd0a2aee183a23bdfee) | 3,742 triangles, 1,939 vertices | CC BY 4.0 | Author describes game-ready UVs, separate shell/glass materials and 4K colour, roughness, metallic, OpenGL normal and AO maps | Material separation does not prove separate meshes; inspect the actual archive, screen aperture and material packing |
| [Television 01 — Gabriel Radić / Poly Haven](https://polyhaven.com/a/Television_01) | Listing rounds to 2K tris; API polycount 1,918 | CC0 | Real-scale wooden tabletop TV with PBR maps; glTF is offered directly | Different visual era; inspect the triangulated export, screen separation and suitability of the worn finish |

Geometry counts are source listings, not measurements of imported Godot assets.
Both Sketchfab model APIs reported `isDownloadable=true`; their metadata did not
expose archive formats. Download availability should be confirmed through the
normal site workflow, including login if requested. No account was used, no
models were downloaded, and no paid asset was purchased during this research.

## Previews from the publishers

### Sony PVM-14L2 — Poring

![Publisher preview of Poring's Sony PVM-14L2](https://media.sketchfab.com/models/ab19c2419c2647299ce96d027b3e7f5e/thumbnails/f7e19463c73c4f6db4c5d4fa2dd6ccd5/9a8c7c29c6a44564bcf213802dc3d5a5.jpeg)

### CRT Computer Monitor — fizyman

![Publisher preview of fizyman's CRT Computer Monitor](https://media.sketchfab.com/models/f2ff0013f86e4cd0a2aee183a23bdfee/thumbnails/2b4555a30b1f405aaa3d5d8a35dd7414/fb674ed8a4284202a75d8c92579b0185.jpeg)

### Television 01 — Poly Haven

![Publisher preview of Poly Haven Television 01](https://cdn.polyhaven.com/asset_img/primary/Television_01.png?height=760&quality=95&v=fd00df78)

These are linked publisher previews, not renders of this project or assets
bundled with it. Use the source-page links above if a publisher's image cannot
be displayed.

## Integration approach after choosing

1. Inspect the source archive in Blender or a glTF viewer: units, orientation,
   materials, texture channels, screen/glass geometry and the actual aperture.
2. Import the cabinet into Godot as glTF/GLB. Preserve bevels, vents, controls,
   stands and useful normal/roughness maps; those should supply much of the
   missing physical detail compared with the current boxes.
3. Fit the existing animated picture and glass meshes to the opening. Remove or
   hide the asset's baked picture and original glass if replacing them, so there
   are no overlapping screen layers. Match curvature to the cabinet rather than
   applying additional barrel distortion to the shader.
4. Start cabinet textures at 2K and inspect at the actual 3.4 m viewing setup.
   Compare material count, transparency overdraw and stereo frame times. Listed
   triangle counts alone do not establish Deck performance; all three are
   plausible candidates for an isolated display, subject to import measurements.
5. Improve room lighting and the support surface next, including contact shadows
   and an environment reflection that fits the room. An imported cabinet rendered
   under the current basic lighting still needs this presentation work.

## Attribution and sources

The Sketchfab metadata declares [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/).
For either asset, retain its creator, model title, source link, license link and
an indication of modifications in the project's credits when actually imported.
Poly Haven's [asset license](https://polyhaven.com/license) declares CC0 and allows
redistribution; an optional author credit would still be useful for provenance.
No third-party asset credit has been added to the shipping app yet because none
of these models has been integrated.

Primary metadata used:

- [fizyman model API](https://api.sketchfab.com/v3/models/f2ff0013f86e4cd0a2aee183a23bdfee)
- [Poring model API](https://api.sketchfab.com/v3/models/ab19c2419c2647299ce96d027b3e7f5e)
- [Poly Haven asset metadata](https://api.polyhaven.com/info/Television_01)

Sketchfab HTML pages were unavailable to the research browser, so their public
metadata API was checked directly. Separate-map descriptions are the authors'
statements; individual model meshes have not been inspected. No asset has yet
been established as a dimensionally exact reproduction of the real hardware.
