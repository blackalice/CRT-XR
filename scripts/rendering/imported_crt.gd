extends RefCounted

# Load a user-supplied GLB locally; no model data is embedded in source control.
static func load_cabinet(parent: Node3D) -> Dictionary:
	var path := ProjectSettings.globalize_path("res://build/crt-model/crt_tv.glb")
	if not OS.has_feature("editor"):
		path = OS.get_executable_path().get_base_dir().path_join("assets/crt_tv.glb")
	if not FileAccess.file_exists(path):
		return {}
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		push_warning("Local CRT model could not be loaded; using the procedural cabinet.")
		return {}
	var scene := document.generate_scene(state)
	if scene == null:
		return {}
	var holder := Node3D.new()
	holder.name = "ImportedCabinet"
	parent.add_child(holder)
	holder.add_child(scene)
	holder.rotation.y = PI
	var source: MeshInstance3D
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		if node.get_parent().name == "Screen":
			source = node
			break
	if source == null or source.mesh.get_surface_count() != 1:
		push_warning("Local CRT has no supported screen; using the procedural cabinet.")
		holder.free()
		return {}
	var transform := parent.global_transform.affine_inverse() * source.global_transform
	var bounds: AABB = transform * source.get_aabb()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		holder.free()
		return {}
	holder.scale = Vector3.ONE * (1.32 / bounds.size.x)
	transform = parent.global_transform.affine_inverse() * source.global_transform
	bounds = transform * source.get_aabb()
	var anchor := Vector3(-0.07, 0.035, 0.06)
	holder.position += anchor - Vector3(bounds.get_center().x, bounds.get_center().y, bounds.position.z)
	transform = parent.global_transform.affine_inverse() * source.global_transform
	var arrays := source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i] = transform * vertices[i] - anchor
	arrays[Mesh.ARRAY_VERTEX] = vertices
	source.visible = false
	var bottom := INF
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var local: Transform3D = parent.global_transform.affine_inverse() * node.global_transform
		var part: AABB = local * node.get_aabb()
		bottom = minf(bottom, part.position.y)
	return {"arrays": arrays, "width": bounds.size.x, "height": bounds.size.y,
		"depth": bounds.size.z, "bottom": bottom}

static func screen_mesh(template: Dictionary, curvature: float) -> ArrayMesh:
	var arrays: Array = template.arrays
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in (indices.size() if not indices.is_empty() else vertices.size()):
		var p := vertices[indices[i] if not indices.is_empty() else i]
		var uv := Vector2(p.x / float(template.width) + 0.5, 0.5 - p.y / float(template.height))
		p.z *= curvature / maxf(float(template.depth), 0.00001)
		surface.set_uv(uv)
		surface.add_vertex(p)
	surface.generate_normals()
	return surface.commit()
