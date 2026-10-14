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

The Linux export script copies the local model to `assets/crt_tv.glb` beside
the executable, along with this credit. This is a local development package;
review the asset's distribution terms before publishing a release. The raw
model remains separate from the application PCK and source repository.

Checked locally: GLB loading, aperture width, screen-facing normals, flat
curvature, stereo alignment and stationary tracking. Visual appearance and
Steam Deck performance still require review. The model has now been transferred
to the user's Deck with the scene-lighting build, which passed a short graphics
startup check. This does not establish sustained stereo performance.
