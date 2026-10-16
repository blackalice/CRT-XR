# Room contact shadows and carpet

The TV/table and table/carpet grounding uses static Cycles ambient-occlusion
maps, rather than high-frequency live shadow maps. This intentionally bakes
contact and soft cavity shading, not a fixed lamp direction. Room controls and
the coloured screen light still update normally.

- The table uses its original UVs. Its 2048-square contact map is combined with
  the original wood colour offline in linear light, then GPU-compressed.
  Compatibility ignores native AO on direct lights; applying contact to colour
  makes the grounding visible under the lamp as well as ambient fill. No decal, projection mesh, extra viewport or additional pass is added.
- The carpet uses a 1024-square AO map across a six-by-five-unit local patch.
  The map is sampled in floor-local coordinates, so moving or scaling the whole
  TV island does not detach the shadows from the feet.
- Existing static TV/table meshes stop casting live shadow maps when a matching
  bake is available. The lamp setting remains available for future dynamic objects.
- The floor contact map is mipmapped single-channel data (about 1.3 MiB).
  The prepared table colour is mipmapped BC7 (about 5.3 MiB), with no extra
  runtime table texture sample. The source table AO remains available for rebakes.
  Missing/mismatched floor layouts fall back without enabling the bake.

The floor uses ambientCG Carpet 012's CC0 colour, OpenGL normal and roughness
maps: https://ambientcg.com/view?id=Carpet012 . Original files are in
assets/carpet; import settings explicitly enable mipmaps and GPU compression.
A warm neutral tint and reduced normal strength give it a subdued bedroom look.
It uses one half-metre tile, low specular, high roughness and fades fine normals
at distance. There are no displaced fibres, fur shells or parallax samples.
The existing brightness control, rug toggle and XR distance/edge fades remain.

## Repeatable bake

Run `scripts/rebake-room.ps1` from the project directory. It starts a separate
background Blender 5.2 process; it does not change an open Blender session.

1. `export-room-bake.gd` builds the real application with isolated preferences
   and exports table receiver geometry, all visible static meshes under
   StationaryTelevision, original table UVs and the actual floor height.
   Self-lit screen/glass meshes are excluded. Set mesh metadata `bake_contact`
   to false to exclude a dynamic prop. Additional static props parented under
   StationaryTelevision participate in subsequent bakes automatically.
2. `bake-room-contacts.py` converts the coordinate system, preserves normals,
   corrects winding and UV orientation, and bakes all occluders together.
   Current settings: 32 Cycles samples, 16 AO samples, fixed seed 1989;
   0.30-unit table and 0.65-unit carpet occlusion distances.
3. `prepare-contact-material.gd` combines the table colour/contact shading,
   using linear-light multiplication, before generating mipmaps and BC7 data.
   Outputs in `build/room-bake`: table_ao.png, floor_ao.png, table_contact_albedo.res, bake.json,
   geometry.json and editable room-contact-bake.blend. The manifest records
   source/geometry/output hashes, Blender version and numeric bake statistics.
4. Export a new Windows/Linux build. Both export scripts copy only the two AO
   maps, prepared table colour, manifest and this guide. The geometry dump and Blender scene are local.

Rebake after changing relative object positions, table proportions, receiver UVs
or adding/removing furniture/props. Changing viewing distance, whole-island scale,
height, lamp colour/intensity or screen content does not require a rebake.
For objects on additional surfaces, add those as receivers in the bake script;
a new occluder alone does not automatically gain its own UV bake.

`tests/room_contacts.gd` checks actual AO-map alignment at the feet and beneath
the CRT numerically, texture filtering, live-shadow exclusion and registration
through placement controls. Its optional image captures only a carpet plane,
never the licensed TV model. No licensed-model renders are used for AI inspection.

`tests/contact_direct_light.gd` renders only synthetic receiver geometry with
the production materials and checks that baked darkening survives direct light
from 0.3 through 8.0 intensity in Compatibility. This catches a renderer bypass
that inspecting AO texture values alone cannot detect.
