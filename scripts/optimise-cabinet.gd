extends SceneTree
## Deterministic offline processing of the licensed local asset. No uploads,
## image inspection or source edits. Visible surfaces are preserved.
const Brand = preload("res://scripts/rendering/cabinet_brand.gd")
const SOURCE := "res://build/crt-model/crt_tv.glb"
const OUTPUT := "res://build/crt-model/optimised"
var textures: Dictionary = {}
var records: Array = []
var failed := false
const HIDDEN_HARDWARE := ["Coax_connector", "Screw", "AV_back"]
var geometry: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func triangles(scene: Node) -> int:
	var count := 0
	for part in scene.find_children("*","MeshInstance3D",true,false):
		for surface in range(part.mesh.get_surface_count()): count+=part.mesh.surface_get_array_index_len(surface)/3
	return count

func local_to_root(node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent is Node3D:
		result=parent.transform*result; parent=parent.get_parent()
	return result

func triangle_key(arrays: Array, offset: int) -> String:
	var keys: Array[String] = []
	for index in range(offset,offset+3):
		var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][arrays[Mesh.ARRAY_INDEX][index]]
		keys.append("%d:%d:%d" % [roundi(point.x*1000),roundi(point.y*1000),roundi(point.z*1000)])
	keys.sort()
	return "/".join(keys)

func append_triangle(surface: SurfaceTool, arrays: Array, offset: int) -> void:
	for index in range(offset,offset+3):
		var vertex: int = arrays[Mesh.ARRAY_INDEX][index]
		surface.set_normal(arrays[Mesh.ARRAY_NORMAL][vertex])
		surface.set_uv(arrays[Mesh.ARRAY_TEX_UV][vertex])
		surface.add_vertex(arrays[Mesh.ARRAY_VERTEX][vertex])

func preserve_visible_panel(original: Array, reduced: Array) -> ArrayMesh:
	var protected := {}
	# The exporter round trip introduces a few float ulps. Snap matches back to
	# their original positions before matching protected triangles (offline only).
	var points: PackedVector3Array = reduced[Mesh.ARRAY_VERTEX]
	var reference: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
	for i in range(points.size()):
		for point in reference:
			if points[i].distance_squared_to(point)<.00000001:
				points[i]=point; break
	reduced[Mesh.ARRAY_VERTEX]=points
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for offset in range(0,original[Mesh.ARRAY_INDEX].size(),3):
		var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
		var vertices: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
		var a := indices[offset]; var b := indices[offset+1]; var c := indices[offset+2]
		var normal := (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).normalized()
		var average: Vector3 = original[Mesh.ARRAY_NORMAL][a]+original[Mesh.ARRAY_NORMAL][b]+original[Mesh.ARRAY_NORMAL][c]
		if normal.dot(average)<0: normal=-normal
		if normal.z>=-.95:
			protected[triangle_key(original,offset)]=true
			# Copy visible triangles directly from the original, including their
			# exact UVs and authored normals, avoiding an exporter round trip.
			append_triangle(surface,original,offset)
	var matched := 0
	for offset in range(0,reduced[Mesh.ARRAY_INDEX].size(),3):
		if protected.has(triangle_key(reduced,offset)): matched+=1
		else: append_triangle(surface,reduced,offset)
	if matched!=protected.size():
		print("PROTECTED_TRIANGLES expected=",protected.size()," matched=",matched)
		push_error("Rear export did not preserve every visible triangle"); failed=true
	surface.index(); surface.generate_tangents()
	return surface.commit()

func trim_rear(scene: Node) -> void:
	geometry={"before_triangles":triangles(scene),"removed":[]}
	for part in scene.find_children("*","MeshInstance3D",true,false):
		var name: String = part.get_parent().name
		if name in HIDDEN_HARDWARE:
			geometry.removed.append({"part":name,"triangles":part.mesh.surface_get_array_index_len(0)/3})
			part.get_parent().remove_child(part); part.free()
		elif name=="rear_section":
			var path := "res://build/crt-model/rear-detail/rear.glb"
			if not FileAccess.file_exists(path): continue
			var report = JSON.parse_string(FileAccess.get_file_as_string("res://build/crt-model/rear-detail/manifest.json"))
			if report==null or report.source_sha256!=FileAccess.get_sha256(SOURCE) or not report.get("boundary_edges_preserved",false) or report.get("output_sha256","")!=FileAccess.get_sha256(path):
				push_error("Rear intermediate does not match the original GLB"); failed=true; return
			var doc := GLTFDocument.new(); var state := GLTFState.new()
			if doc.append_from_file(ProjectSettings.globalize_path(path),state)!=OK:
				failed=true; return
			var reduced := doc.generate_scene(state)
			var input: MeshInstance3D = reduced.find_children("*","MeshInstance3D",true,false)[0]
			var relative := local_to_root(part).affine_inverse()*local_to_root(input)
			var arrays := input.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var normal_basis := relative.basis.inverse().transposed()
			for i in range(vertices.size()):
				vertices[i]=relative*vertices[i]
				normals[i]=(normal_basis*normals[i]).normalized()
			arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
			# Regenerate tangents from the retained UVs after reconciling the
			# exporter transforms; no runtime conversion is needed.
			var result := preserve_visible_panel(part.mesh.surface_get_arrays(0),arrays)
			result.surface_set_material(0,part.get_active_material(0))
			part.mesh=result
			geometry.rear=report
			reduced.free()
	geometry.after_triangles=triangles(scene)

func prepare(material: BaseMaterial3D, limit: int) -> void:
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for channel in range(BaseMaterial3D.TEXTURE_MAX):
		var source := material.get_texture(channel)
		if source == null: continue
		var key := "%d:%d" % [source.get_instance_id(), limit]
		if textures.has(key):
			material.set_texture(channel, textures[key]); continue
		var image := source.get_image()
		var original_size := image.get_size()
		if image.is_compressed(): image.decompress()
		image.clear_mipmaps()
		image.resize(limit, limit, Image.INTERPOLATE_LANCZOS)
		var normal := channel in [BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_DETAIL_NORMAL]
		image.generate_mipmaps(normal)
		# BC7 keeps all RGB normal channels and fine labels; unlike BC1 it does
		# not rely on a four-colour block palette. Supported by both target GPUs.
		image.convert(Image.FORMAT_RGBA8)
		var error := image.compress(Image.COMPRESS_BPTC)
		if error != OK:
			push_error("BC7 compression unavailable: "+error_string(error)); failed=true; return
		var texture := ImageTexture.create_from_image(image)
		texture.resource_name = material.resource_name+"_"+str(channel)+"_BC7"
		textures[key] = texture
		material.set_texture(channel, texture)
		records.append({"material":material.resource_name,"channel":channel,
			"source_size":[original_size.x,original_size.y],"size":limit,
			"gpu_bytes_with_mips":image.get_data_size(),"format":image.get_format()})

func run() -> void:
	var start := Time.get_ticks_msec()
	var original_hash := FileAccess.get_sha256(SOURCE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(ProjectSettings.globalize_path(SOURCE),state)!=OK:
		quit(1); return
	var scene := document.generate_scene(state)
	Brand.apply(scene)
	trim_rear(scene)
	var materials := {}
	for part in scene.find_children("*","MeshInstance3D",true,false):
		# The source tube mesh is retained as the runtime aperture template,
		# but its old static TV picture and surface maps serve no purpose.
		if str(part.get_parent().name)=="Screen":
			part.mesh.surface_set_material(0,StandardMaterial3D.new())
			continue
		for surface in range(part.mesh.get_surface_count()):
			var material := part.get_active_material(surface) as BaseMaterial3D
			if material==null or materials.has(material.get_instance_id()): continue
			materials[material.get_instance_id()]=true
			prepare(material,1024 if material.resource_name=="TVback" else 2048)
	if failed: scene.free(); quit(1); return
	var packed := PackedScene.new()
	var error := packed.pack(scene)
	if error==OK: error=ResourceSaver.save(packed,OUTPUT+"/cabinet.scn")
	var total := 0
	for record in records: total+=record.gpu_bytes_with_mips
	var report := {"source_sha256":original_hash,"brand":Brand.TEXT,
		"geometry":geometry,
		"badge_svg_sha256":FileAccess.get_sha256("res://Phony.svg"),
		"texture_count":records.size(),"gpu_texture_bytes_with_mips":total,
		"textures":records,"elapsed_ms":Time.get_ticks_msec()-start}
	var file := FileAccess.open(OUTPUT+"/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("OPTIMISED ",JSON.stringify(report))
	if FileAccess.get_sha256(SOURCE)!=original_hash: error=ERR_FILE_CORRUPT
	scene.free(); quit(0 if error==OK else 1)
