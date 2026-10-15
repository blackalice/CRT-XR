extends RefCounted
## Fit the user's vector artwork to the old badge bounds. Two triangles,
## alpha-tested edges, and normal room lighting; no transparent overlay pass.
const TEXT := "Phonysonic"
const SHADER = preload("res://shaders/cabinet_badge.gdshader")

static func apply(scene: Node) -> void:
	if scene.get_meta("cabinet_brand", "") == TEXT: return
	for part in scene.find_children("*", "MeshInstance3D", true, false):
		if str(part.get_parent().name) != "Logo": continue
		var original: AABB = part.mesh.get_aabb()
		var artwork := load("res://Phony.svg") as Texture2D
		if artwork==null: continue
		var image := artwork.get_image()
		if image.is_compressed(): image.decompress()
		image.clear_mipmaps()
		var aspect := float(image.get_width())/image.get_height()
		image.resize(1024,160,Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		# Compression is done offline. Release fallback can use the small RGBA map.
		if OS.has_feature("editor"): image.compress(Image.COMPRESS_BPTC)
		var width := minf(original.size.x, original.size.y*aspect)
		var quad := QuadMesh.new()
		quad.size = Vector2(width,width/aspect)
		var arrays := quad.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var centre := original.get_center()
		centre.z = original.end.z
		for index in range(vertices.size()): vertices[index] += centre
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material := ShaderMaterial.new()
		material.resource_name = "Phonysonic satin badge"
		material.shader = SHADER
		material.set_shader_parameter("artwork",ImageTexture.create_from_image(image))
		mesh.surface_set_material(0,material)
		part.mesh = mesh
	scene.set_meta("cabinet_brand", TEXT)
