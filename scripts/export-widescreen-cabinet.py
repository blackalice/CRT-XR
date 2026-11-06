"""Export the artist-edited open .blend; never regenerate or save its geometry."""
import bpy, json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
asset=next(c for c in bpy.context.scene.collection.children if c.name.startswith('CRT XR'))
temp=bpy.data.collections.new('Game export'); bpy.context.scene.collection.children.link(temp)
picture=next(o for o in asset.all_objects if o.parent and o.parent.name=='Screen' and o.type=='MESH')
copies=[]
for ob in asset.all_objects:
    if ob.type!='MESH': continue
    cp=ob.copy(); cp.data=ob.data.copy(); cp.parent=None; cp.matrix_world=ob.matrix_world.copy()
    temp.objects.link(cp); copies.append(cp)
    if ob==picture: cp.name='LivePictureExport'; exported_picture=cp
for ob in copies:
    if len(ob.data.materials)<2: continue
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active=ob
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.separate(type='MATERIAL'); bpy.ops.object.mode_set(mode='OBJECT')
groups={}
for ob in list(temp.objects):
    if ob==exported_picture: continue
    groups.setdefault(ob.data.materials[0].name,[]).append(ob)
for name,parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts: ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join(); parts[0].name=name
# Free up the semantic name only in this temporary background process.
bpy.data.objects['Screen'].name='SourceScreen'
anchor=bpy.data.objects.new('Screen',None); temp.objects.link(anchor); exported_picture.parent=anchor
bpy.ops.object.select_all(action='DESELECT')
for ob in temp.objects: ob.select_set(True)
out=root/'assets/models/widescreen-crt/crt-xr-26-wide.glb'
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_apply=True)
triangles=0
for ob in temp.objects:
    if ob.type=='MESH': ob.data.calc_loop_triangles(); triangles+=len(ob.data.loop_triangles)
info={'triangles':triangles,'mesh_objects':sum(o.type=='MESH' for o in temp.objects),
      'source':str(Path(bpy.data.filepath).relative_to(root)).replace('\\','/'),'export':out.relative_to(root).as_posix(),
      'front_axis_gltf':'+Z','source_preserved':True}
(out.parent/'model-info.json').write_text(json.dumps(info,indent=2)+'\n')
print(json.dumps(info))
