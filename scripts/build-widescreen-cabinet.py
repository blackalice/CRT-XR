"""Original CRT XR widescreen cabinet. Run with Blender --background --python.

No reference photographs or downloaded model data are embedded in this asset.
Units: metres; front is Blender -Y; screen centre is the origin in X/Z.
"""
import bpy
import bmesh
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/widescreen-crt'
SOURCE = ROOT / 'artwork/widescreen-crt'
PREVIEW = ROOT / 'build/widescreen-crt'
for path in (OUT, SOURCE, PREVIEW):
    path.mkdir(parents=True, exist_ok=True)
# This script runs in its own factory-startup background process.
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.context.preferences.filepaths.save_version = 0
scene.unit_settings.system = 'METRIC'
asset = bpy.data.collections.new('CRT XR 26 Wide — export')
scene.collection.children.link(asset)
stage = bpy.data.collections.new('Studio — not exported')
scene.collection.children.link(stage)

def move(obj, coll=asset):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    return obj

def mat(name, color, rough=.4, metal=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    return m

silver = mat('Graphite silver moulded plastic', (.16,.18,.21), .43, .08)
dark = mat('Charcoal rear and recess', (.027,.032,.038), .54)
black = mat('Screen gasket and infrared window', (.008,.012,.014), .3)
glass = mat('Screen placeholder — replace with live game', (.023,.038,.043), .21)
lamp = mat('Green power indicator', (.08,.5,.18), .25)

def mesh(name, verts, faces, material, coll=asset):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    ob.data.materials.append(material)
    return ob

def rounded(w,h,r,y,zc=0,n=8,bottom_r=None):
    pts=[]
    rb=r if bottom_r is None else bottom_r
    for cx,cz,start,rad in [(w/2-r,h/2-r,0,r),(-w/2+r,h/2-r,90,r),
                        (-w/2+rb,-h/2+rb,180,rb),(w/2-rb,-h/2+rb,270,rb)]:
        for k in range(n+1):
            a=math.radians(start+k*90/n)
            pts.append((cx+rad*math.cos(a), y, zc+cz+rad*math.sin(a)))
    return pts

def loft(name, sections, material, cap=False, closed=False):
    # Loops run counterclockwise as viewed from the front (-Y).
    verts=[p for section in sections for p in section]
    count=len(sections[0]); faces=[]
    for j in range(len(sections)-1):
        for i in range(count):
            a=j*count+i; b=j*count+(i+1)%count
            faces.append((a,b,b+count,a+count))
    if cap:
        faces.extend([tuple(reversed(range(count))),tuple(range((len(sections)-1)*count,len(verts)))])
    ob=mesh(name,verts,faces,material)
    # Split shading across profile changes. Smooth only around rounded corners,
    # never from the broad planar fascia into the sloping aperture or side wall.
    for e in ob.data.edges:
        e.use_edge_sharp = e.vertices[0]//count == e.vertices[1]//count
    if closed:
        bm=bmesh.new(); bm.from_mesh(ob.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.000001)
        bm.to_mesh(ob.data); bm.free()
    # Recalculate normals for closed shells; ring front surfaces already face -Y.
    bpy.context.view_layer.objects.active=ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    ob.select_set(False)
    for p in ob.data.polygons: p.use_smooth=True
    bpy.context.view_layer.objects.active=ob
    ob.select_set(True)
    mod=ob.modifiers.new('Area weighted moulded normals','WEIGHTED_NORMAL')
    mod.keep_sharp=True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.select_set(False)
    return ob

def box(name, loc, dims, material, bevel=.002):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob=move(bpy.context.object); ob.name=name
    ob.dimensions=dims
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    ob.data.materials.append(material)
    if bevel:
        mod=ob.modifiers.new('Small moulded edge','BEVEL'); mod.width=bevel; mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=ob.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob

# Screen surround and closely fitted lower rail follow separate mould parting lines.
# 26-inch nominal diagonal: viewable opening 576 x 324 mm, exactly 16:9.
back_loop=rounded(.694,.417,.008,.055,bottom_r=.0018)
frame=loft('FrontFrame', [back_loop,
    rounded(.700,.423,.009,-.048,bottom_r=.0018),
    rounded(.699,.422,.0085,-.0505,bottom_r=.0015),
    rounded(.696,.419,.007,-.052,bottom_r=.001),
    # A 9 mm-wide, 6 mm-deep chamfer is part of the fascia itself.
    # This replaces the old straight sleeve and stacked, deeply inset rings.
    rounded(.604,.352,.004,-.052),
    rounded(.586,.334,.003,-.046),
    rounded(.586,.334,.003,.055), back_loop],silver,closed=True)
loft('Tube gasket',[rounded(.586,.334,.003,-.046),
    rounded(.576,.324,.003,-.0447)],black)

# Simple tapered closed tube housing: spend geometry on the visible silhouette.
rear_front=rounded(.694,.468,.008,.054,-.0255,bottom_r=.020)
# Underlap the lower rail at the rear join; avoid intersecting side silhouettes.
rear_front=[(x*(1-.009*max(0,min(1,(-z-.200)/.018))),y,z) for x,y,z in rear_front]
loft('RearShell', [rear_front,
    rounded(.680,.460,.010,.075,-.029), rounded(.540,.369,.018,.325,-.039),
    rounded(.505,.343,.018,.387,-.039), rounded(.501,.339,.016,.393,-.039)],dark,True)

# Preserve the broad front planes after normal calculation.
for p in frame.data.polygons:
    if abs(p.normal.y)>.9999: p.use_smooth=False

# A shallow curved, UV-mapped screen with its own stable semantic parent.
anchor=bpy.data.objects.new('Screen',None); asset.objects.link(anchor)
verts=[]; uv=[]; faces=[]
nx,ny=32,18
for j in range(ny+1):
    v=j/ny
    for i in range(nx+1):
        u=i/nx; x=(u-.5)*.576; z=(v-.5)*.324
        # Near-flat glass: centre 7.5 mm behind the fascia, corners 9 mm.
        y=-.0445 + .0015*((2*u-1)**2*.65+(2*v-1)**2*.35)
        verts.append((x,y,z)); uv.append((u,v))
for j in range(ny):
    for i in range(nx):
        a=j*(nx+1)+i; faces.append((a,a+1,a+nx+2,a+nx+1))
screen=mesh('PictureSurface',verts,faces,glass); screen.parent=anchor
layer=screen.data.uv_layers.new(name='PictureUV')
for poly in screen.data.polygons:
    poly.use_smooth=True
    for li in poly.loop_indices: layer.data[li].uv=uv[screen.data.loops[li].vertex_index]
screen['purpose']='Hide this mesh and replace with the runtime picture/glass; UV 0..1, 16:9.'

# Full-depth internal backing closes the seam without an exposed end block.
box('Internal joint backing',(0,.00475,-.210),(.692,.0995,.008),dark,.0004)
# One shallow closed plinth, tucked beneath the casing on all four sides.
def footprint(w,d,r,z):
    return [(x,v+.004,z) for x,unused,v in rounded(w,d,r,0)]
loft('Single inset base',[
    footprint(.660,.096,.003,-.2590),
    footprint(.660,.096,.003,-.2600),
    footprint(.654,.090,.002,-.2655),
    footprint(.652,.088,.0015,-.2660)],silver,cap=True)
for x in [-.295,.295]:
    box('RecessedFoot', (x,.025,-.267),(.023,.035,.003),dark,.0006)

# One original small repeatable texture, rather than thousands of grille holes.
im=bpy.data.images.new('Original speaker perforations',width=128,height=128)
pixels=[]
for j in range(128):
    for i in range(128):
        x=(i%16)-7.5; y=(j%16)-7.5
        d=math.sqrt(x*x+y*y)
        t=max(0,min(1,(d-3.6)/1.3))
        c=.045+(.47-.045)*t
        pixels.extend((c,c*1.025,c*1.06,1))
im.pixels=pixels
im.filepath_raw=str(OUT/'speaker-perforations.png'); im.file_format='PNG'; im.save(); im.pack()
grille=mat('Speaker mesh — tiled texture',(.25,.27,.29),.55,.15)
nodes=grille.node_tree.nodes; links=grille.node_tree.links
tex=nodes.new('ShaderNodeTexImage'); tex.image=im
links.new(tex.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
# One closed lower moulding with flush grille regions. Horizontal profile rows
# taper and roll the lower corners, and wrap the grille surface onto the ends.
zs=[-.2121,-.2136,-.219,-.229,-.240,-.247,-.252,-.256,-.258,-.2595]
verts=[]; faces=[]; indices=[]
for z in zs:
    t=(-z-.2121)/.0474
    # Lower 14 mm turns inward: a quarter-round plus a modest taper.
    drop=max(0,-z-.2455)
    inset=.014-math.sqrt(max(0,.014**2-drop**2)) if drop else 0
    hw=.349-.003*t-inset
    xs=[-hw,-hw+.0015,-.315,-.300,-.28,-.25,-.21,-.175,-.141,-.140,
        -.096,-.095,-.06,0,.06,.140,.141,.175,.21,.25,.28,.300,.315,hw-.0015,hw]
    for x in xs:
        # Surface only rounds near the ends and very bottom; centre stays flat.
        roll_x=.0035*(abs(x)/.349)**18
        roll_z=.0045*t**8
        verts.append((x,-.051+roll_x+roll_z,z))
cols=len(xs); rows=len(zs); front_count=len(verts)
rear_verts=[]
for j,z in enumerate(zs):
    hw=abs(verts[j*cols][0])
    # Follow the upper shell's 3 mm rise from front to rear at the joint.
    rise=.003*max(0,1-(-z-.2121)/.012)
    rear_verts.extend([(x*(hw-.0025)/hw,.055,z+rise) for x,y,z in verts[j*cols:(j+1)*cols]])
verts += rear_verts
for j in range(rows-1):
    for i in range(cols-1):
        a=j*cols+i
        # Rows descend, so reverse winding for outward (-Y) face normals.
        faces.append((a,a+cols,a+cols+1,a+1))
        xmid=(verts[a][0]+verts[a+1][0])/2
        indices.append(int(0<j<rows-2 and 0<i<cols-2 and abs(xmid)>.141))
        faces.append((a+front_count,a+1+front_count,a+cols+1+front_count,a+cols+front_count)); indices.append(0)
boundary=list(range(cols))+[j*cols+cols-1 for j in range(1,rows)]+list(range((rows-1)*cols+cols-2,(rows-1)*cols-1,-1))+[j*cols for j in range(rows-2,0,-1)]
for k,a in enumerate(boundary):
    b=boundary[(k+1)%len(boundary)]
    faces.append((a,b,b+front_count,a+front_count)); indices.append(0)
rail=mesh('LowerFascia',verts,faces,silver); rail.data.materials.append(grille)
uv_layer=rail.data.uv_layers.new(name='GrilleUV')
for poly,mi in zip(rail.data.polygons,indices):
    poly.material_index=mi
    poly.use_smooth=True
    for li in poly.loop_indices:
        co=rail.data.vertices[rail.data.loops[li].vertex_index].co
        uv_layer.data[li].uv=(co.x/.0144,co.z/.0144)
# Keep the side/back edge crisp while smoothly turning the front surface.
boundary_set=set(boundary)
for e in rail.data.edges:
    a,b=e.vertices
    e.use_edge_sharp=(a in boundary_set and b in boundary_set) or (a>=front_count and b>=front_count)
# Fine seams define a flush control door and a small power-control strip.
for x in [-.1405,-.0955,.1405]:
    box('Fine control panel seam',(x,-.05115,-.233),(.00045,.0003,.034),dark,.0001)
box('Power button',(-.119,-.0515,-.233),(.005,.0012,.003),dark,.0003)
box('IR receiver',(-.107,-.05135,-.233),(.002,.0007,.002),black,.0003)
box('Status LED',(-.103,-.0514,-.233),(.001,.0007,.001),lamp,.0002)
box('Control door grip',(.018,-.05145,-.219),(.013,.0009,.0015),silver,.0003)

# Consolidate opaque cabinet parts by material to keep the game export compact.
# Retain the editable parts in the Blender source; export a temporary copy below.
bpy.ops.object.select_all(action='DESELECT')
for ob in asset.objects: ob.select_set(True)
bpy.context.view_layer.update()
scene['asset_notes']='Original unbranded reference-inspired cabinet, not an exact Toshiba replica. No lettering, logos or photo textures.'

# Studio exists only in the Blender file and previews.
floor_mat=mat('Studio floor',(.043,.051,.065),.65)
floor=box('Studio floor',(0,0,-.2775),(200,200,.018),floor_mat,.0); move(floor,stage)
world=bpy.data.worlds.new('Studio ambient'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.19,.23,.3,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.4; scene.world=world
def light(name, loc, power, size, color):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
    ob=bpy.data.objects.new(name,data); stage.objects.link(ob); ob.location=loc
    ob.rotation_euler=(Vector((0,0,0))-ob.location).to_track_quat('-Z','Y').to_euler()
light('Large soft key',(-1.1,-1.4,1.6),110,1.4,(.83,.9,1))
light('Warm fill',(.9,-.7,.5),35,1,(1,.86,.72))
light('Top edge softbox',(.3,.8,1.4),95,1,(.78,.87,1))
camdata=bpy.data.cameras.new('Presentation'); cam=bpy.data.objects.new('Presentation',camdata); stage.objects.link(cam); scene.camera=cam
camdata.type='ORTHO'; camdata.ortho_scale=.98
def camera(loc,target=(0,.05,-.02)):
    cam.location=loc; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
camera((1,-2,.75))
scene.render.engine='CYCLES'; scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.resolution_x=1400; scene.render.resolution_y=1050; scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
# Frame the model when the source opens.
for screen_ui in bpy.data.screens:
    for area in screen_ui.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=1.15
            area.spaces.active.region_3d.view_location=(0,.05,-.02)
            area.spaces.active.clip_end=100
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'crt-xr-26-wide.blend'))

# Export only asset meshes/empties, with no studio or reference imagery.
# Join duplicates by material on a temporary export collection, leaving source editable.
export_coll=bpy.data.collections.new('Temporary export'); scene.collection.children.link(export_coll)
copies=[]
for ob in list(asset.objects):
    if ob.type=='MESH':
        cp=ob.copy(); cp.data=ob.data.copy(); cp.parent=None; cp.matrix_world=ob.matrix_world.copy()
        export_coll.objects.link(cp); copies.append(cp)
# Split the multi-material lower rail only on export, keeping the source whole.
for cp in copies:
    if len(cp.data.materials)>1:
        bpy.ops.object.select_all(action='DESELECT'); cp.select_set(True)
        bpy.context.view_layer.objects.active=cp
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.separate(type='MATERIAL'); bpy.ops.object.mode_set(mode='OBJECT')
groups={}
for cp in list(export_coll.objects):
    if cp.name.startswith('PictureSurface'): continue
    groups.setdefault(cp.data.materials[0].name,[]).append(cp)
for material, group in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for ob in group: ob.select_set(True)
    bpy.context.view_layer.objects.active=group[0]; bpy.ops.object.join()
    group[0].name=material
pic=next(ob for ob in export_coll.objects if ob.name.startswith('PictureSurface'))
anchor.name='Screen_Source'
screen_root=bpy.data.objects.new('Screen',None); export_coll.objects.link(screen_root); pic.parent=screen_root
bpy.ops.object.select_all(action='DESELECT')
for ob in export_coll.objects: ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'crt-xr-26-wide.glb'),export_format='GLB',use_selection=True,export_apply=True,export_extras=True)
tris=0
for ob in export_coll.objects:
    if ob.type=='MESH': ob.data.calc_loop_triangles(); tris+=len(ob.data.loop_triangles)
stats={'triangles':tris,'mesh_objects':sum(o.type=='MESH' for o in export_coll.objects),
       'materials':len({s.material.name for o in export_coll.objects for s in o.material_slots if s.material}),
       'picture_metres':[.576,.324],'nominal_diagonal_inches':26,'front_axis_blender':'-Y',
       'front_axis_gltf':'+Z','cabinet_width_metres':.700,'texture_resolution':[128,128],
       'glass_recess_metres':[.0075,.009],'chamfer_width_metres':.009,
       'chamfer_depth_metres':.006,'branding':False,
       'source':'artwork/widescreen-crt/crt-xr-26-wide.blend','export':'assets/models/widescreen-crt/crt-xr-26-wide.glb'}
(OUT/'model-info.json').write_text(json.dumps(stats,indent=2)+'\n')
for ob in list(export_coll.objects): bpy.data.objects.remove(ob,do_unlink=True)
bpy.data.collections.remove(export_coll)
anchor.name='Screen'
for name,loc in [('three-quarter',(1,-2,.75)),('front',(0,-2,.02)),('side',(2,-.8,.45))]:
    camera(loc); scene.render.filepath=str(PREVIEW/(name+'.png')); bpy.ops.render.render(write_still=True)
scene.render.resolution_x=1600; scene.render.resolution_y=430
camdata.ortho_scale=.77
camera((0,-2,-.17),(0,0,-.214))
scene.render.filepath=str(PREVIEW/'lower-detail.png'); bpy.ops.render.render(write_still=True)
scene.render.resolution_x=1200; scene.render.resolution_y=900
camdata.ortho_scale=.20
for name,loc,target in [
    ('joint-side',(1.0,.00,-.190),(.31,.00,-.220)),
    ('joint-oblique',(.62,-.36,-.18),(.30,.005,-.225)),
    ('base-underside',(.60,-.32,-.37),(.29,.00,-.251))]:
    floor.hide_render=name=='base-underside'
    camera(loc,target); scene.render.filepath=str(PREVIEW/(name+'.png')); bpy.ops.render.render(write_still=True)
print(json.dumps(stats))
