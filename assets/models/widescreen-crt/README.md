# CRT XR 26 Wide

Original Blender-built widescreen cabinet inspired by the user-supplied Toshiba
26HF84A references. This is an approximate original interpretation, not an exact
manufacturer reconstruction. No reference photographs, Toshiba logos, commercial
model geometry or third-party texture assets are included. Original mesh, texture
and generator are covered by the repository's MIT licence.

Editable source: `artwork/widescreen-crt/crt-xr-26-wide-new.blend`.
Decorated copies: `artwork/widescreen-crt/crt-xr-26-wide-silver.blend` and
`artwork/widescreen-crt/crt-xr-26-wide-black.blend`. The artist source is preserved.
Game export: `assets/models/widescreen-crt/crt-xr-26-wide.glb`.
Export the edited source with Blender 5.2:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background artwork/widescreen-crt/crt-xr-26-wide-new.blend --python scripts/export-widescreen-cabinet.py
```

The exporter prints the extracted artwork onto temporary copies of the existing
fascia surfaces, preserving the edited source. The original procedural generator
`scripts/build-widescreen-cabinet.py` is retained for provenance; rerunning it
replaces the authored Blender file and must not be used to export artist edits.
The generator runs in an isolated background process. It does not change an open
Blender scene. It also writes front, side and three-quarter preview renders under
`build/widescreen-crt/`. The Blender source retains individual editable parts and
studio lighting; the GLB excludes the studio and merges cabinet parts by material.
The original 128-square tiled speaker texture and printed silver fascia map are
embedded in the GLB. The black finish swaps opaque colour maps and plastic colours
on the same mesh. Both finishes use mipmaps for the print and speaker pattern.
Perforations are texture detail, not individual holes or transparency.

The screen surround and lower speaker rail are closely fitted closed
mouldings with matching front-to-rear joint slopes and a narrow recessed parting
seam backed throughout its depth. The lower rail curves around its
outer ends and tapers inward at the bottom. Its grille and control-panel regions
share the same surface, with fine divider lines and small flush controls. Profile
edges split the shading so the broad fascia stays planar, with small edge bevels
and restrained corner radii. The opening has an integrated 9 mm-wide, 6 mm-deep
angled chamfer leading into a narrow dark gasket. A single chamfered inset base
and recessed feet support the cabinet; the simple rear shell is tucked behind the
rounded lower corners.

Dimensions are authored in metres: 0.700 m cabinet width, approximately 0.48 m
overall height and 0.45 m depth. Picture opening is 0.576 x 0.324 m (16:9,
approximately 26 inches diagonally). Front is Blender -Y / glTF +Z, with Z up in
Blender / Y up in glTF. This differs from the existing imported cabinet's facing.
The screen centre is X=0, Blender Z=0; the feet bottom is Blender Z=-0.2685 m.

`Screen/PictureSurface` is an opaque placeholder with UVs spanning 0..1. Its
centre is recessed 7.5 mm behind the fascia, with 1.5 mm of curvature towards the
corners (9 mm total recess). These are visual modelling choices from the supplied
references, not measured manufacturer dimensions. Replace/hide it when attaching
the live picture and glass. The rear is a simple closed tapered housing with no
connector bank, vent geometry or labels, since this asset targets front viewing.

See `model-info.json` for measured export counts. The current artist-edited export has 4,914 triangles in eight mesh/material batches,
opaque materials only; no runtime procedural shading. Printing adds no triangles,
material batches or transparent passes. Target hardware performance is unmeasured.

The user-provided `artwork/TV.ai` supplies the DigiPower logo, MEGA WIDE / SBS3D
badges and power symbol. Only vector outlines are extracted; the reference image
embedded in the Illustrator document is excluded. No fonts are required. Ink is
blended into the opaque fascia map at reduced contrast: muted grey on silver and
subdued warm off-white on black. Original vector shapes and placement are retained.
Choose **Room → Materials → Wide TV finish** in the app. This is a saved wide-TV
appearance preference, shared across games and videos, independent of picture fit.

To refresh the artwork after editing the AI file, run these commands from the
repository root, then export the artist source using the command above:

```powershell
python scripts/extract-wide-tv-graphics.py # requires pypdf
& tools/godot/Godot_v4.5.1-stable_win64_console.exe --headless --path . --script scripts/prepare-wide-tv-graphics.gd
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background artwork/widescreen-crt/crt-xr-26-wide-new.blend --python scripts/decorate-widescreen-cabinet.py -- --save-variants
```

The last command creates/replaces the two decorated copies; edit geometry in the
artist source. The extraction coordinates follow the supplied front-view layout.

In the app, open Picture → TV & defaults to choose the TV and the level to edit.
Each platform has a preferred TV under Emulation → Consoles, and individual games
can override it. PS2, GameCube and PSP default to Wide TV (Stretch); all other
platforms, including Wii and Dreamcast, default to 4:3 TV (Fit). Videos default
to wide and can override this per file.
Selecting a cabinet does not enable a game's widescreen mode or emulator hack.

CRT, colour and fitting adjustments are independent for games and videos on each
TV. Games inherit TV defaults, then platform defaults, then individual game
changes. Videos inherit video TV defaults, then individual video changes. Resetting
an option removes that level's override. Fit preserves proportions, Fill crops,
and Stretch changes proportions. Automatic aspect follows the core or video;
4:3/16:9 overrides handle anamorphic games. Menus retain their own full-picture fit.

The versioned `display_profiles/data` settings contain these preferences and sparse
picture overrides. Existing cabinet baselines and enabled legacy game/video files
are imported without rewriting the original files. Distance, height and physical
scale are saved separately for each TV and for fixed/XR viewing. The first wide
view sits farther back when no wide profile exists. Room presets do not switch TVs.

The CRT shader smooths the picture boundary over approximately one final-screen
pixel while retaining the interior reconstruction. Geometry MSAA is optional under
View → Display, applies to both eyes, and defaults off. Deck performance with MSAA
still needs measurement; no post-process blur or higher emulator resolution is added.

The widescreen picture is 1.76 m wide in the virtual room, retaining the standard
picture height. Its table is fitted to the footprint; clock radio and game boxes
are hidden while wide, with their preferences restored on return to standard.
The old cabinet's contact bake is not reused for the wide layout. Authored wide
screen curvature is capped at the mesh's native depth to keep it inside the bezel.
The GLB is imported as a bundled resource and included in Godot exports.

