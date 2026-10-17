"""Repeatable Cycles contact bake, using exact exported runtime geometry.
Run scripts/rebake-room.ps1. Background Blender never changes an open session.
No model images are uploaded or inspected; receivers use existing table UVs.
"""
from pathlib import Path
import bpy,json,hashlib,time
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/room-bake';START=time.monotonic()
data=json.loads((OUT/'geometry.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.seed=1989
scene.render.bake.margin=16;scene.render.bake.margin_type='EXTEND';scene.render.bake.use_clear=False
scene.cycles.use_denoising=False
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
    for device in prefs.devices:device.use=device.type=='OPTIX'
    if any(d.use for d in prefs.devices):scene.cycles.device='GPU'
except (RuntimeError,TypeError):pass

def xyz(p):return (p[0],-p[2],p[1])
def create(record):
    vertices=[xyz(p)for p in record['points']];normals=[Vector(xyz(n))for n in record['normals']]
    faces=[]
    for i in range(0,len(record['indices']),3):
        a,b,c=record['indices'][i:i+3]
        face=(a,b,c)
        if (Vector(vertices[b])-Vector(vertices[a])).cross(Vector(vertices[c])-Vector(vertices[a])).dot(normals[a]+normals[b]+normals[c])<0:face=(a,c,b)
        faces.append(face)
    mesh=bpy.data.meshes.new(record['name']);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(record['name'],mesh);scene.collection.objects.link(obj)
    if record.get('uv'):
        layer=mesh.uv_layers.new(name='ReceiverUV')
        for loop in mesh.loops:
            u,v=record['uv'][loop.vertex_index];layer.data[loop.index].uv=(u,1-v)
    for poly in mesh.polygons:poly.use_smooth=True
    mesh.normals_split_custom_set_from_vertices(normals)
    return obj
for caster in data['casters']:create(caster)
table=create(data['table'])
x,z,w,d=data['floor_rect'];y=data['floor_y']
floor=create({'name':'CarpetReceiver','points':[[x,y,z],[x+w,y,z],[x+w,y,z+d],[x,y,z+d]],'normals':[[0,1,0]]*4,'uv':[[0,0],[1,0],[1,1],[0,1]],'indices':[0,1,2,0,2,3]})
records=[]
for obj,size,distance,filename in [(table,2048,.30,'table_ao.png'),(floor,1024,.65,'floor_ao.png')]:
    mat=bpy.data.materials.new(obj.name+'_Bake');mat.use_nodes=True;obj.data.materials.clear();obj.data.materials.append(mat)
    nodes=mat.node_tree.nodes;nodes.clear();links=mat.node_tree.links
    output=nodes.new('ShaderNodeOutputMaterial');ao=nodes.new('ShaderNodeAmbientOcclusion');ao.samples=16;ao.only_local=False;ao.inputs['Distance'].default_value=distance
    emit=nodes.new('ShaderNodeEmission');links.new(ao.outputs['AO'],emit.inputs['Color']);links.new(emit.outputs[0],output.inputs['Surface'])
    image=bpy.data.images.new(filename,width=size,height=size,alpha=False,float_buffer=True);image.generated_color=(1,1,1,1);image.colorspace_settings.name='Non-Color'
    target=nodes.new('ShaderNodeTexImage');target.image=image
    for node in nodes:node.select=False
    target.select=True;nodes.active=target
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    print('CONTACT_BAKE_START',filename,flush=True)
    bpy.ops.object.bake(type='EMIT',use_clear=False,margin=16)
    image.filepath_raw=str(OUT/filename);image.file_format='PNG';image.save()
    pixels=np.empty(size*size*4,dtype=np.float32);image.pixels.foreach_get(pixels);values=pixels.reshape(-1,4)[:,0]
    stats={'min':float(values.min()),'mean':float(values.mean()),'dark_fraction':float((values<.85).mean())}
    if not np.isfinite(values).all() or stats['dark_fraction']<.001:raise RuntimeError('Blank/invalid contact bake: '+filename)
    records.append({'file':filename,'size':size,'distance':distance,'statistics':stats,'sha256':hashlib.sha256((OUT/filename).read_bytes()).hexdigest()})
    print('CONTACT_BAKE_DONE',records[-1],flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'room-contact-bake.blend'))
manifest={'console_present':data.get('console_present',False),'geometry_sha256':hashlib.sha256((OUT/'geometry.json').read_bytes()).hexdigest(),'table_source_sha256':data['table_source_sha256'],'cabinet_source_sha256':data['cabinet_source_sha256'],'floor_rect':data['floor_rect'],'floor_y':y,'samples':32,'ao_samples':16,'seed':1989,'records':records,'seconds':time.monotonic()-START,'blender':bpy.app.version_string}
(OUT/'bake.json').write_text(json.dumps(manifest,indent=2));print('CONTACT_BAKE_COMPLETE',json.dumps(manifest),flush=True)
