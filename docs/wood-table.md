# Wide wooden CRT table

Source: "Wood Drawer & Tables Set" by brandon_grey
https://sketchfab.com/brandondmc10
https://sketchfab.com/3d-models/wood-drawer-tables-set-958db224ef514b2eabd69ac0a4e59ca0
Licence: CC BY 4.0 International, https://creativecommons.org/licenses/by/4.0/
Author/source/licence are recorded in the original GLB's asset.extras metadata.
Source SHA-256: 551d43371ad5e63815dc7426aa08352dffb829411a75f55904bea59d8a1851e1

Only SM_WoodenTable_LOD0_Table_INST_0 (the fourth, wider table) is used.
The supplied set is preserved byte-for-byte under
build/wood-table-source/wood_drawer__tables_set.glb and excluded from Git and runtime packages.
Run Godot with --headless --path . --script scripts/prepare-wood-table.gd
when the source GLB is present to reproduce build/wood-table/table.scn.

Changes: extract the one table, flatten transforms, regenerate tangent vectors,
and prepare three 2048-square mipmapped BC7 textures. Runtime keeps one mesh,
one PBR material and 3,272 triangles. Texture storage including mipmaps is
16 MiB. No other furniture, books or console props are retained.

The support spans at least 2.2 units left/right, and the CRT footprint plus
0.2 units front/back. Its top meets the casing underside and its feet meet the
existing floor. Uniform scaling preserves the original table proportions. The floor island is
lowered to meet its feet while TV placement and all distance, height and scale
controls remain intact. No second shelf is added.
Existing room lighting, screen light spill and distance fade apply normally.
A procedural fallback is retained when the prepared local asset is unavailable.

Both export scripts copy only the prepared table and this credit into assets/.
The complete credit also appears in the exported THIRD_PARTY.md.
