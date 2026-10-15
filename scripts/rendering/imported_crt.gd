extends RefCounted

const SCREEN_ANCHOR := Vector3(0.0, 0.035, 0.06)
const Plastic = preload("res://scripts/rendering/cabinet_plastic.gd")

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
	filter_cabinet_materials(scene)
	Plastic.apply(scene)
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
	var anchor := SCREEN_ANCHOR
	holder.position += anchor - Vector3(bounds.get_center().x, bounds.get_center().y, bounds.position.z)
	transform = parent.global_transform.affine_inverse() * source.global_transform
	var arrays := source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i] = transform * vertices[i] - anchor
	arrays[Mesh.ARRAY_VERTEX] = vertices
	source.visible = false
	var bottom := INF
	var cabinet_bounds := AABB()
	var first := true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		if not node.visible: continue
		var local: Transform3D = parent.global_transform.affine_inverse() * node.global_transform
		var part: AABB = local * node.get_aabb()
		bottom = minf(bottom, part.position.y)
		cabinet_bounds = part if first else cabinet_bounds.merge(part)
		first = false
	return {"arrays": arrays, "width": bounds.size.x, "height": bounds.size.y,
		"depth": bounds.size.z, "bottom": bottom, "cabinet_bounds": cabinet_bounds}

static func filter_cabinet_materials(scene: Node) -> void:
	# Embedded images from the runtime GLB loader do not have mipmaps. Merely
	# selecting mip filtering cannot suppress subpixel speaker-grille patterns.
	# Update shared runtime images once; the original GLB remains untouched.
	var prepared := {}
	for part in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in range(part.mesh.get_surface_count()):
			var material := part.get_active_material(surface) as BaseMaterial3D
			if material == null: continue
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			for channel in range(BaseMaterial3D.TEXTURE_MAX):
				var texture := material.get_texture(channel)
				if texture == null: continue
				var texture_id := texture.get_instance_id()
				if prepared.has(texture_id):
					material.set_texture(channel, prepared[texture_id])
					continue
				prepared[texture_id] = texture
				var image := texture.get_image()
				if image == null or image.has_mipmaps(): continue
				if image.is_compressed() and image.decompress() != OK: continue
				var normal_map := channel in [BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_DETAIL_NORMAL]
				if image.generate_mipmaps(normal_map) != OK: continue
				if texture is ImageTexture:
					texture.set_image(image)
				else:
					var filtered := ImageTexture.create_from_image(image)
					prepared[texture_id] = filtered
					material.set_texture(channel, filtered)

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

static func safe_picture_rect(template: Dictionary) -> Rect2:
	# The rounded aperture does not cover every corner of its bounding box.
	# Find an inscribed rectangle in its convex outline, then allow bezel margin.
	var points := PackedVector2Array()
	for vertex in template.arrays[Mesh.ARRAY_VERTEX]:
		points.append(Vector2(vertex.x / float(template.width) + 0.5, 0.5 - vertex.y / float(template.height)))
	var outline := Geometry2D.convex_hull(points)
	var inset := 0.20
	for step in range(81):
		var trial := float(step) / 400.0
		var fits := true
		for corner in [Vector2(trial, trial), Vector2(1.0-trial, trial), Vector2(trial, 1.0-trial), Vector2(1.0-trial, 1.0-trial)]:
			if not Geometry2D.is_point_in_polygon(corner, outline): fits = false
		if fits:
			inset = trial
			break
	inset = minf(inset + 0.025, 0.25)
	return Rect2(Vector2.ONE * inset, Vector2.ONE * (1.0 - 2.0 * inset))
