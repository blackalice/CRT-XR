# Locally supplied CRT cabinet

The optional cabinet is **CRT TV by Timothy Ahene**:
https://sketchfab.com/3d-models/crt-tv-9ba4baa106e64319a0b540cf0af5aa9e

Downloaded by the user under Sketchfab Free Standard, with the NoAI tag.
Keep the original download and applicable license record. See:
https://sketchfab.com/licenses
https://sketchfab.com/blogs/community/restricting-generative-ai-use-of-free-models/

The third-party asset is not covered by the application's source license.
Do not publish the GLB as a standalone asset or commit it to the source repository.
Do not supply the model or its textures to generative AI tools.

For development, place the user-supplied GLB at:
`build/crt-model/crt_tv.glb` (ignored by Git and Godot's editor importer).
The application loads it locally using Godot's glTF runtime loader. Without
the file it uses the existing procedural cabinet.

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

The Linux export script copies the local model to `assets/crt_tv.glb` beside
the executable, along with this credit. This is a local development package;
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
