extends SceneTree
const OUT="res://build/room-bake"
func _initialize():call_deferred("run")
func mesh_record(part:MeshInstance3D,root:Node3D) -> Dictionary:
    var transform:=root.global_transform.affine_inverse()*part.global_transform
    var points:Array=[];var normals:Array=[];var uv:Array=[];var indices:Array=[]
    var offset:=0
    for s in range(part.mesh.get_surface_count()):
        var a:=part.mesh.surface_get_arrays(s)
        for v in a[Mesh.ARRAY_VERTEX]:
            var point:Vector3=transform*v
            points.append([point.x,point.y,point.z])
        var matrix:=transform.basis.inverse().transposed()
        for n in a[Mesh.ARRAY_NORMAL]:
            var normal:Vector3=(matrix*n).normalized()
            normals.append([normal.x,normal.y,normal.z])
        if a[Mesh.ARRAY_TEX_UV]!=null:
            for t in a[Mesh.ARRAY_TEX_UV]:uv.append([t.x,t.y])
        if a[Mesh.ARRAY_INDEX]!=null and not a[Mesh.ARRAY_INDEX].is_empty():
            for i in a[Mesh.ARRAY_INDEX]:indices.append(i+offset)
        else:
            for i in range(a[Mesh.ARRAY_VERTEX].size()):indices.append(i+offset)
        offset=points.size()
    return {"name":str(part.name),"points":points,"normals":normals,"uv":uv,"indices":indices}
func run():
    var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
    var world=app.world;var tv:Node3D=world.television
    var receiver:MeshInstance3D=tv.get_node("TelevisionSupport/TopShelf")
    var casters:Array=[]
    for node in tv.find_children("*","MeshInstance3D",true,false):
        if not node.is_visible_in_tree() or node==receiver:continue
        if str(node.name) in ["PhosphorSurface","GlassFaceplate"] or not node.get_meta("bake_contact",true):continue
        casters.append(mesh_record(node,tv))
    var data={"table":mesh_record(receiver,tv),"casters":casters,"floor_y":world.support_floor_y-.01,"floor_rect":[-3.0,-2.5,6.0,5.0],"table_source_sha256":FileAccess.get_sha256("res://build/wood-table-source/wood_drawer__tables_set.glb"),"cabinet_source_sha256":FileAccess.get_sha256("res://build/crt-model/crt_tv.glb")}
    DirAccess.make_dir_recursive_absolute(OUT)
    var file:=FileAccess.open(OUT+"/geometry.json",FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
    print("ROOM BAKE GEOMETRY EXPORTED: ",casters.size()," casters")
    app.free();quit.call_deferred()
