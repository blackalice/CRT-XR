extends SceneTree
## Offline extraction. Preserve the supplied set and retain only its wide table.
const SOURCE="res://build/wood-table-source/wood_drawer__tables_set.glb"
const OUTPUT="res://build/wood-table"
const TEXTURE_LIMIT:=1024
func _initialize():call_deferred("run")
func run():
    var hash_before:=FileAccess.get_sha256(SOURCE)
    var doc:=GLTFDocument.new();var state:=GLTFState.new()
    if doc.append_from_file(ProjectSettings.globalize_path(SOURCE),state)!=OK:quit(1);return
    var scene:=doc.generate_scene(state)
    var selected:MeshInstance3D
    for part in scene.find_children("*","MeshInstance3D",true,false):
        if str(part.name).begins_with("SM_WoodenTable_LOD0_"):selected=part
    if selected==null:push_error("Wide table was not found");scene.free();quit(1);return
    var relative:=selected.transform
    var ancestor=selected.get_parent()
    while ancestor is Node3D:
        relative=ancestor.transform*relative;ancestor=ancestor.get_parent()
    var arrays:=selected.mesh.surface_get_arrays(0)
    var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var normal_matrix:=relative.basis.inverse().transposed()
    var bounds:=relative*selected.get_aabb()
    var centre:=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
    for i in vertices.size():
        vertices[i]=relative*vertices[i]-centre
        normals[i]=(normal_matrix*normals[i]).normalized()
    arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
    # Regenerate tangents after flattening the source's transforms.
    arrays[Mesh.ARRAY_TANGENT]=null
    var temporary:=ArrayMesh.new();temporary.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    var surface:=SurfaceTool.new();surface.create_from(temporary,0);surface.generate_tangents()
    var mesh:=surface.commit()
    var material:=selected.get_active_material(0).duplicate() as StandardMaterial3D
    material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    var cache:Dictionary={};var records:Array=[];var total:=0
    for channel in range(BaseMaterial3D.TEXTURE_MAX):
        var texture:=material.get_texture(channel)
        if texture==null:continue
        var id:=texture.get_instance_id()
        if cache.has(id):material.set_texture(channel,cache[id]);continue
        var image:=texture.get_image()
        if image.is_compressed():image.decompress()
        var original:=image.get_size();image.clear_mipmaps()
        # 1024 holds the grain at viewing distance (about 2.2 m wide, seen from
        # ~3 m) for a quarter of the 2048 map's video memory.
        if max(original.x,original.y)>TEXTURE_LIMIT:image.resize(TEXTURE_LIMIT,TEXTURE_LIMIT,Image.INTERPOLATE_LANCZOS)
        image.generate_mipmaps(channel==BaseMaterial3D.TEXTURE_NORMAL)
        image.convert(Image.FORMAT_RGBA8)
        if image.compress(Image.COMPRESS_BPTC)!=OK:push_error("BC7 preparation failed");scene.free();quit(1);return
        var ready:=ImageTexture.create_from_image(image);cache[id]=ready;material.set_texture(channel,ready)
        total+=image.get_data_size();records.append({"channel":channel,"original":[original.x,original.y],"gpu_bytes":image.get_data_size()})
    mesh.surface_set_material(0,material)
    var table:=MeshInstance3D.new();table.name="TopShelf";table.mesh=mesh
    var packed:=PackedScene.new();var error:=packed.pack(table)
    DirAccess.make_dir_recursive_absolute(OUTPUT)
    if error==OK:error=ResourceSaver.save(packed,OUTPUT+"/table.scn",ResourceSaver.FLAG_COMPRESS)
    var manifest={"source_sha256":hash_before,"source_node":str(selected.name),"triangles":mesh.surface_get_array_index_len(0)/3,"source_size":[bounds.size.x,bounds.size.y,bounds.size.z],"surfaces":1,"texture_count":cache.size(),"gpu_texture_bytes_with_mips":total,"textures":records,"author":"brandon_grey","license":"CC-BY-4.0","source_url":"https://sketchfab.com/3d-models/wood-drawer-tables-set-958db224ef514b2eabd69ac0a4e59ca0"}
    var file:=FileAccess.open(OUTPUT+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  "));file.close()
    print("TABLE PREPARED ",JSON.stringify(manifest))
    if hash_before!=FileAccess.get_sha256(SOURCE):error=ERR_FILE_CORRUPT
    table.free();scene.free();quit(0 if error==OK else 1)
