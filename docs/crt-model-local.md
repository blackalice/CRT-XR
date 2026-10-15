# Locally supplied CRT cabinet

The optional cabinet is **CRT TV by Timothy Ahene**:
https://sketchfab.com/3d-models/crt-tv-9ba4baa106e64319a0b540cf0af5aa9e

The recent user download was labelled Sketchfab Free Standard + NoAI. The user
has since supplied stronger historical evidence: the creator's own listing,
archived on 29 September 2022, shows **CC Attribution** for the exact model ID:
https://web.archive.org/web/20220929230421/https://sketchfab.com/3d-models/crt-tv-9ba4baa106e64319a0b540cf0af5aa9e

The evidence and modification credit are recorded in `THIRD_PARTY.md`; the
screenshot is retained locally in `build/license-evidence/`. Its licence-link
destination/version has not yet been independently retrieved. This supports an
earlier CC grant; do not describe it as a newly granted or verified CC0 licence.
The current file/revision and separately accepted download terms must be
considered when documenting the source for release. Earlier guidance against
standalone redistribution applied to the Standard licence, not to a valid CC BY
grant, which permits redistribution subject to its conditions.

The asset is separate from the application's source-code licence. Original and
prepared model files remain ignored by project policy. Keep source and licence
evidence; preserve notices, credit Timothy Ahene, link the applicable licence,
and identify modifications when redistributing under a verified CC grant.
The project continues to keep model/textures/renders out of generative AI tools.

For development, place the user-supplied GLB at:
`build/crt-model/crt_tv.glb` (ignored by Git and Godot's editor importer).
The application prefers the prepared `build/crt-model/optimised/cabinet.scn`
when present. Otherwise it uses Godot's glTF runtime loader. Without either
asset it uses the existing procedural cabinet.

Integration uses the cabinet's separate Screen node to locate its aperture.
The source screen is hidden; its outline is used for the live game surface and
the separate glass layer. Source UVs are replaced on these runtime surfaces
with planar game-picture UVs. The model is oriented toward the viewer and
uniformly scaled to retain the existing 1.32 m virtual picture width. This is
not a dimensionally accurate 14-inch reconstruction. The original GLB is not
modified. Curvature, TV scale and distance controls remain available.

The live picture is now centred on the viewing axis rather than using the old
7 cm left offset. The stand centres itself under the casing's measured X/Z
bounds, with 10 cm of support beyond the front and rear and its top aligned to
the cabinet's lowest point. This avoids the earlier rear overhang.

Runtime casing overrides retain the original albedo, normal and packed surface
textures. The front shell/buttons use a satin roughness range of 0.40-0.76; the
rear uses 0.56-0.86, with gentler normal-map strength. They remain dielectrics
with Godot's default specular response. A small amount of authored AO also
affects direct illumination to retain recess depth. The connector, screw and
badge materials are left alone despite sharing the front atlas. This remains
ordinary opaque PBR shading with mipmapped anisotropic sampling: no extra pass,
reflection capture or procedural micro-pattern. See Godot's
[spatial shader reference](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/spatial_shader.html).

The casing now uses its existing baked occlusion instead of receiving dynamic
shadows. This avoids distracting self-shadow patches on the curved base. It
still casts onto the stand/floor and still responds to the room and screen
lights. Recess detail comes from the authored occlusion/normal maps; a moving
object will not cast a shadow onto the plastic. This is an intentional visual
trade-off for a largely static XR scene, not a new full-scene lightmap bake.
`tests/casing_shadow_receiver.gd` verifies receiver exclusion, preserved casting
and baked-occlusion response with original synthetic geometry/textures.

## Blender AO bake

The local `build/crt-model/ao` directory now contains new front/back AO maps,
an editable `crt-ao-bake.blend`, and `bake.json` with source/output hashes and
bake settings. These are derivatives of the licensed asset and remain ignored
along with the original GLB. Do not commit or upload them to generative tools.

Rebuild using Blender 5.2's background Python interface:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python scripts/bake-cabinet-ao.py
```

This imports a fresh copy, normalises the tube to the app's 1.32 m width, and
bakes finite-distance Cycles AO through emission into the existing UV atlas:
2048 square, 192 Cycles samples, 32 AO-node samples, 0.16 m ray distance and
16-pixel extended island margins. Other TV parts participate as occluders.
The original source, UVs and open Blender session remain untouched. The working
copy restores the original material output connections after baking; the AO
images remain available as labelled image nodes for inspection. It is not a
full-room lightmap or a bake of the screen's animated content.

The runtime loads each map as single-channel linear L8 data with mipmaps
(roughly 5.3 MiB each), keeping the 16-bit PNG source bakes on disk. One extra
texture lookup per casing pixel provides stable recess shading. A gentle
albedo multiplier makes this visible under direct lights in Compatibility,
while retaining the original ambient-occlusion map and live room illumination.
Room's expanded controls include **Casing recess shading**, default 0.70,
range 0-1; Y restores the selected default. Missing new maps safely fall back
to the earlier authored AO. Windows and Linux exports copy the maps beside the
GLB; they are not embedded in the application PCK.

`tests/cabinet_presentation.gd` verifies alignment, shelf clearance, surface
registration, material isolation, texture reuse and original-file integrity
through numeric inspection. Synthetic rounded boxes, using original generated
textures, were used to inspect the shader visually. The licensed cabinet and
its textures/renders were not supplied for AI image inspection. Final sheen
and the appearance of baked wear still need human judgement in the glasses;
an artist would be useful if those source textures need repainting.

The export scripts copy the prepared model to `assets/optimised/cabinet.scn`
beside the executable, along with this credit. If no prepared asset exists,
they copy the original GLB to `assets/crt_tv.glb` instead. This is a local development package;
review the asset's distribution terms before publishing a release. The raw
model remains separate from the application PCK and source repository.

Checked locally: GLB loading, aperture width, screen-facing normals, flat
curvature, stereo alignment and stationary tracking. Visual appearance and
Steam Deck performance still require review. The model has now been transferred
to the user's Deck with the scene-lighting build, which passed a short graphics
startup check. This does not establish sustained stereo performance.


## Plastic grain

The casing adds a small original seeded 256x256 texture, shared across its
materials (about 0.33 MiB with mipmaps). A smooth channel varies roughness and
very slightly varies albedo; two fine slope channels provide restrained normal
detail. This is static surface grain, not animation or screen noise. The fine
normal contribution fades with the pixel footprint, while trilinear
anisotropic mip filtering suppresses unresolved detail. Connectors, badges and
the picture retain their previous materials. One extra texture sample is used;
there is no new rendering pass or change to the licensed source textures.

Room's expanded **Plastic grain** control ranges from 0 to 1, default 0.55.
Zero skips the grain lookup; Y resets the selected slider. The approved baked
recess-shading default is now 0.70; existing saved custom values are preserved.
`tests/plastic_grain.gd` uses only original synthetic content to check texture
sharing, close-up detail, static behaviour and stability during minified
subpixel motion. Desktop measured sample variance was 0.0000278 close up and
zero at the tested minified distance. This is a sampling check, not a headset
performance or appearance guarantee.

## Prepared cabinet and Phonysonic badge

Run `Godot_v4.5.1-stable_win64_console.exe --headless --path . --script scripts/optimise-cabinet.gd`
with the local original GLB present to rebuild the ignored prepared asset.
The converter uses the existing opaque cabinet meshes and UVs, reduces TVfront
maps to 2048 square and TVback maps to 1024 square, generates normal-aware
mipmaps, then encodes BC7. Front/rear maps remain shared across hardware and
casing. The unused Screen material becomes texture-free; its mesh remains the
live picture's aperture template. No casing geometry is decimated.

The separate original Logo mesh is replaced using the user's `Phony.svg`
artwork. The replacement is a small two-triangle, alpha-tested satin badge,
with its position, width and orientation derived from the old badge bounds.
It uses a 1024×160 BC7 texture with mipmaps and ordinary lighting; it adds no
screen-space effect or full-screen pass. The original SVG remains untouched.
The prepared scene stores the replacement, avoiding SVG processing at launch.
When falling back to the original GLB, the runtime still substitutes the badge.

The prepared asset is about 20.4 MiB on disk versus 30.1 MiB for the original.
Measured image payload with mipmaps falls from 576 MiB for nine original maps
to 20 MiB for six shared compressed maps, plus about 0.21 MiB for the new badge.
This excludes the unchanged 10.7 MiB of baked AO maps and small shared grain
texture, and is not a measurement of total application VRAM. The cabinet has
14,000 triangles versus 15,937 previously; the reduction comes from the badge.
Frame-rate improvement has not yet been profiled on the Deck.

The packed scene loads precomputed mesh/texture resources instead of parsing
the GLB and generating its mipmaps on each launch. It depends only on the small
badge shader in the application. Exported optimised builds do not also include
the original GLB. Keep the original and earlier asset packages for comparison.
All prepared model resources remain licensed derivatives under the original
terms and stay outside source control and AI image inspection.

The AO bake was repeated with `--omit-logo`, excluding the old raised lettering
so it does not cast its wordmark onto the casing. Previous bakes are retained
locally in `build/crt-model/ao-before-phony`. AO/grain defaults remain 0.70/0.55.

`tests/cabinet_optimisation.gd` checks component/geometry preservation, removed
screen textures, six shared compressed maps, mipmaps, size budget, numeric
compression error, badge geometry, and original-file integrity. The sampled
mean RGB compression error is below 0.0024 across all maps (0–1 scale).
`tests/cabinet_presentation.gd`, smoke and picture-fitting checks also pass.
A standalone render of the user's SVG on a synthetic plate was used for badge
checks; no licensed cabinet images were inspected. Fine lettering and grille
appearance still need the user's local/through-glasses visual judgement.

## Hidden rear detail reduction

The prepared cabinet now has **8,208 triangles**, down from 14,000 after badge
replacement (41.4% fewer), or 15,937 in the untouched download. The reduction
removes the hidden coax connector (3,304 triangles), rear AV sockets (1,104)
and rear screw (592), and simplifies only the rear-facing panel from 4,524 to
3,732 triangles. Three MeshInstance3D submissions are removed. The front ports,
buttons, badge, screen template and front shell are retained.

Build the geometry-only intermediate before running the Godot converter:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/simplify-cabinet-rear.py
```

It writes ignored `build/crt-model/rear-detail/rear.glb` and a manifest. The
original GLB is never overwritten. A separate Blender process is used, leaving
any interactive Blender session alone. The Godot converter verifies the source
and intermediate hashes and rejects intermediates without boundary validation.

The simplifier welds exact seam duplicates, protects every vertex belonging to
side/top/bottom/front-facing shell triangles, preserves boundary loops and
extreme points, and limits collapse to the rear-facing region. UV/normal splits
are restored through export. The converter copies all 3,317 protected triangles
from the original with their original UVs and normal directions, then combines
them with the reduced rear-facing region and regenerates tangents offline.

Geometry tests verify those retained attributes, the identical cabinet bounds,
unchanged front meshes/aperture, and identical panel boundary edges (no new
holes). The rear remains a solid shadow-casting surface; the visible vents and
outer silhouette remain intact. Textures, baked AO and material settings are
unchanged by this pass. Existing baked rear hardware marks are harmless on the
unseen rear; the front bake is retained. This optimisation assumes the current
fixed-position 3DoF use; restore the original hardware for a future walk-around
or rotatable-TV mode.

This is a reduction in geometry and submissions, not a measured Deck frame-rate
claim. Windows graphics startup, stereo/picture fitting and geometry checks are
used for local review before any separate Steam Deck transfer/profiling.
