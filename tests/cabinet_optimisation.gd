extends SceneTree
const Cabinet = preload("res://scripts/rendering/imported_crt.gd")
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if ok: print("PASS: ",message)
	else: push_error(message); failures+=1
func parts(scene: Node) -> Dictionary:
	var result := {}
	for part in scene.find_children("*","MeshInstance3D",true,false): result[str(part.get_parent().name)]=part
	return result
func point_key(point: Vector3) -> String:
	return "%d:%d:%d" % [roundi(point.x*100000),roundi(point.y*100000),roundi(point.z*100000)]
func boundaries(arrays: Array) -> Dictionary:
	var counts := {}; var result := {}
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for offset in range(0,indices.size(),3):
		for edge in [[0,1],[1,2],[2,0]]:
			var keys := [point_key(arrays[Mesh.ARRAY_VERTEX][indices[offset+edge[0]]]),point_key(arrays[Mesh.ARRAY_VERTEX][indices[offset+edge[1]]])]
			keys.sort(); var key: String = keys[0]+"/"+keys[1]
			counts[key]=counts.get(key,0)+1
	for key in counts:
		if counts[key]==1: result[key]=true
	return result
func triangle_key(arrays: Array, offset: int) -> String:
	var keys: Array[String] = []
	for step in range(3):
		var index: int = arrays[Mesh.ARRAY_INDEX][offset+step]
		keys.append(point_key(arrays[Mesh.ARRAY_VERTEX][index]))
	keys.sort(); return "|".join(keys)
func run():
	var source := "res://build/crt-model/crt_tv.glb"
	var original_hash := FileAccess.get_sha256(source)
	var document := GLTFDocument.new(); var state := GLTFState.new()
	check(document.append_from_file(ProjectSettings.globalize_path(source),state)==OK,"Original cabinet remains readable")
	var original := document.generate_scene(state)
	var prepared := (load("res://build/crt-model/optimised/cabinet.scn") as PackedScene).instantiate()
	var before := parts(original); var after := parts(prepared)
	check(before.size()-3==after.size() and not after.has("Coax_connector") and not after.has("Screw") and not after.has("AV_back"),"Three hidden rear hardware meshes are removed")
	var same := true
	for key in before:
		if key in ["Logo","rear_section","Coax_connector","Screw","AV_back"]: continue
		same = same and before[key].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==after[key].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(same,"Front casing, buttons, ports and source aperture remain unchanged")
	var rear_original: Array = before.rear_section.mesh.surface_get_arrays(0)
	var rear_reduced: Array = after.rear_section.mesh.surface_get_arrays(0)
	var keys := {}; var preserved := 0; var max_uv_error := 0.0; var min_normal_dot := 1.0
	for offset in range(0,rear_reduced[Mesh.ARRAY_INDEX].size(),3): keys[triangle_key(rear_reduced,offset)]=offset
	for offset in range(0,rear_original[Mesh.ARRAY_INDEX].size(),3):
		var indices: PackedInt32Array = rear_original[Mesh.ARRAY_INDEX]
		var a: Vector3 = rear_original[Mesh.ARRAY_VERTEX][indices[offset]]
		var b: Vector3 = rear_original[Mesh.ARRAY_VERTEX][indices[offset+1]]
		var c: Vector3 = rear_original[Mesh.ARRAY_VERTEX][indices[offset+2]]
		var normal := (b-a).cross(c-a).normalized()
		var average: Vector3 = rear_original[Mesh.ARRAY_NORMAL][indices[offset]]+rear_original[Mesh.ARRAY_NORMAL][indices[offset+1]]+rear_original[Mesh.ARRAY_NORMAL][indices[offset+2]]
		if normal.dot(average)<0: normal=-normal
		if normal.z>=-.95 and keys.has(triangle_key(rear_original,offset)):
			preserved+=1
			var target: int = keys[triangle_key(rear_original,offset)]
			for step in range(3):
				var src: int = indices[offset+step]
				for other in range(3):
					var dst: int = rear_reduced[Mesh.ARRAY_INDEX][target+other]
					if point_key(rear_original[Mesh.ARRAY_VERTEX][src])!=point_key(rear_reduced[Mesh.ARRAY_VERTEX][dst]): continue
					var uv: Vector2 = rear_original[Mesh.ARRAY_TEX_UV][src]
					max_uv_error=maxf(max_uv_error,uv.distance_to(rear_reduced[Mesh.ARRAY_TEX_UV][dst]))
					var n: Vector3 = rear_original[Mesh.ARRAY_NORMAL][src]
					min_normal_dot=minf(min_normal_dot,n.normalized().dot(rear_reduced[Mesh.ARRAY_NORMAL][dst].normalized()))
	print("VISIBLE_PANEL_ATTRIBUTES triangles=",preserved," uv_error=",max_uv_error," normal_dot=",min_normal_dot)
	check(preserved==3317 and max_uv_error<.00001 and min_normal_dot>.99999,"All 3,317 side/top/bottom/neck triangles preserve positions, UVs and authored normal directions")
	check(boundaries(rear_original)==boundaries(rear_reduced),"Rear simplification does not introduce openings or change panel boundaries")
	var old_box: AABB = before.rear_section.mesh.get_aabb()
	var new_box: AABB = after.rear_section.mesh.get_aabb()
	check(old_box.position.is_equal_approx(new_box.position) and old_box.size.is_equal_approx(new_box.size),"Cabinet dimensions and support bounds are preserved")
	check(after.Screen.mesh.surface_get_material(0).albedo_texture==null,"Unused original screen images are removed")
	check(after.Logo.mesh.surface_get_array_index_len(0)==6 and prepared.get_meta("cabinet_brand")=="Phonysonic","Separate raised Panasonic geometry is replaced by the user's two-triangle badge")
	var checked := {}; var errors: Array = []; var total := 0
	for key in after:
		if key in ["Screen","Logo"]: continue
		var mat: BaseMaterial3D = after[key].get_active_material(0)
		var reference: BaseMaterial3D = before[key].get_active_material(0)
		for channel in range(BaseMaterial3D.TEXTURE_MAX):
			var texture := mat.get_texture(channel)
			if texture==null or checked.has(texture.get_instance_id()): continue
			checked[texture.get_instance_id()]=true
			var image := texture.get_image()
			total+=image.get_data_size()
			check(image.get_format()==Image.FORMAT_BPTC_RGBA and image.has_mipmaps(),"Map uses GPU-native BC7 and precomputed mipmaps")
			check(image.get_width()==(1024 if key=="rear_section" else 2048),"Texture resolution follows visible front / rear detail")
			var ref := reference.get_texture(channel).get_image()
			ref.resize(image.get_width(),image.get_height(),Image.INTERPOLATE_LANCZOS)
			image.decompress()
			var error := 0.0
			for y in range(32):
				for x in range(32):
					var px := (x*image.get_width()/32)+7; var py := (y*image.get_height()/32)+3
					var delta := ref.get_pixel(px,py)-image.get_pixel(px,py)
					error+=(absf(delta.r)+absf(delta.g)+absf(delta.b))/(32*32*3)
			errors.append(error)
	check(checked.size()==6 and total<21*1024*1024,"Only six shared cabinet maps remain, within a 21 MiB budget")
	print("COMPRESSION_MEAN_ERRORS ",errors)
	check(errors.max()<.025,"Compression preserves sampled colour and normal data within a small average error")
	check(FileAccess.get_sha256(source)==original_hash,"Original downloaded GLB is untouched")
	original.free();prepared.free();quit(1 if failures else 0)
