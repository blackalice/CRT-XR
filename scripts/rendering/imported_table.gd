extends RefCounted
## The extracted fourth table. Keeps the original procedural stand as a fallback.
static func build(parent: Node3D, top: float, cabinet: AABB) -> Node3D:
    var path:=ProjectSettings.globalize_path("res://build/wood-table/table.scn") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("assets/wood-table/table.scn")
    if not FileAccess.file_exists(path):return null
    var packed:=load(path) as PackedScene
    if packed==null:return null
    var table:=packed.instantiate() as MeshInstance3D
    if table==null:return null
    var bounds:=table.get_aabb()
    if not bounds.has_volume():table.free();return null
    var width:=maxf(2.2,cabinet.size.x+0.40)
    var depth:=maxf(1.02,cabinet.size.z+0.20)
    var uniform_scale:=maxf(width/bounds.size.x,depth/bounds.size.z)
    var floor_y:=top-bounds.size.y*uniform_scale
    var stand:=Node3D.new();stand.name="TelevisionSupport"
    parent.add_child(stand);stand.add_child(table)
    stand.position=Vector3(cabinet.get_center().x,floor_y,cabinet.get_center().z)
    table.name="TopShelf"
    table.scale=Vector3.ONE*uniform_scale
    table.position=-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*table.scale
    stand.set_meta("floor_y",floor_y)
    stand.set_meta("source","Wood Drawer & Tables Set / wide table")
    return stand
