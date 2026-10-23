extends RefCounted
## Original procedural props for the table set: a clock radio, a VCR and a stack
## of game boxes. Detail is drawn by each prop's shader in face UV space, with
## supplied print textures on all three game boxes. Every prop is one mesh and one material,
## casts no shadow, and grounds itself with a soft multiply contact patch.
## Sizes are real dimensions times SET_SCALE, matching the oversized TV/table set.
const SET_SCALE := 2.3
const CLOCK_SIZE := Vector3(0.26, 0.085, 0.13)     # 1990s rectangular clock radio
const VCR_SIZE := Vector3(0.43, 0.095, 0.30)      # full-size 1990s VHS deck
const CARTON_SIZE := Vector3(0.185, 0.035, 0.135) # cardboard cartridge box, lying flat
const CLAMSHELL_SIZE := Vector3(0.19, 0.03, 0.27) # plastic clamshell case, lying flat

static func box_into(surface: SurfaceTool, size: Vector3, transform: Transform3D, colour: Color, radius := 0.01) -> void:
	# Bevelled box with per-face 0..1 UVs (x across, y down the face), matching
	# BedroomSet.soft_box; vertex colour carries per-part data for the shader.
	var half := size * 0.5
	var bevel := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.8)
	var inner := half - Vector3.ONE * bevel
	var faces := [
		[Vector3.BACK, Vector3.RIGHT, Vector3.DOWN],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN],
		[Vector3.LEFT, Vector3.BACK, Vector3.DOWN],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD]]
	for index in range(faces.size()):
		var face: Array = faces[index]
		var bx: float = bevel / (face[1] * half).length()
		var by: float = bevel / (face[2] * half).length()
		var xs := [-1.0, -1.0 + bx, 1.0 - bx, 1.0]
		var ys := [-1.0, -1.0 + by, 1.0 - by, 1.0]
		for y in range(ys.size() - 1):
			for x in range(xs.size() - 1):
				for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
					var point := Vector2(xs[x + int(corner.x)], ys[y + int(corner.y)])
					var p: Vector3 = face[0] * half + face[1] * half * point.x + face[2] * half * point.y
					var nearest := p.clamp(-inner, inner)
					var normal := (p - nearest).normalized()
					surface.set_color(colour)
					# UV2.x names the face for the shader: 0 front (+z), 1 back,
					# 2 right, 3 left, 4 top, 5 bottom.
					surface.set_uv2(Vector2(index, 0))
					surface.set_normal(transform.basis * normal)
					surface.set_uv(point * 0.5 + Vector2.ONE * 0.5)
					surface.add_vertex(transform * (nearest + normal * bevel))

static func prop(parent: Node3D, name: String, shader: Shader, mesh: ArrayMesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = shader
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func contact_patch(owner: Node3D, footprint: Vector2, bottom: float, centre := Vector2.ZERO) -> MeshInstance3D:
	# Soft darkening around the prop's footprint, standing in for baked contact AO.
	# A child of the prop, so it moves and hides with it.
	var size := footprint + Vector2.ONE * 0.12
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		surface.set_uv(corner)
		surface.set_color(Color(footprint.x / size.x, footprint.y / size.y, 0))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(centre.x + (corner.x - 0.5) * size.x, bottom + 0.004, centre.y + (corner.y - 0.5) * size.y))
	var node := prop(owner, "ContactShade", preload("res://shaders/prop_contact.gdshader"), surface.commit())
	node.set_meta("contact_patch", true)
	return node

static func clock_radio(parent: Node3D, table_top: float, x: float, z: float) -> Node3D:
	var size := CLOCK_SIZE * SET_SCALE
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	box_into(surface, size, Transform3D.IDENTITY, Color(0, 0, 0), 0.025)
	var angle := deg_to_rad(14.0) # turned slightly towards the viewer
	var node := prop(parent, "ClockRadio", preload("res://shaders/prop_clock_radio.gdshader"), surface.commit())
	node.position = Vector3(x, table_top + size.y * 0.5, z)
	node.rotation.y = angle
	contact_patch(node, Vector2(size.x, size.z), -size.y * 0.5)
	return node

static func vcr(parent: Node3D, base_y: float, x: float, z: float) -> Node3D:
	var size := VCR_SIZE * SET_SCALE
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	box_into(surface, size, Transform3D.IDENTITY, Color(0, 0, 0), 0.012)
	var node := prop(parent, "VideoRecorder", preload("res://shaders/prop_vcr.gdshader"), surface.commit())
	(node.material_override as ShaderMaterial).set_shader_parameter("face_size", Vector2(size.x, size.y))
	node.position = Vector3(x, base_y + size.y * 0.5, z)
	contact_patch(node, Vector2(size.x, size.z), -size.y * 0.5)
	return node

static func shelf(parent: Node3D, bounds: AABB, wood: Color) -> MeshInstance3D:
	# A plain board resting on the table's lower rails, between the legs.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	box_into(surface, bounds.size, Transform3D(Basis(), bounds.get_center()), Color(0, 0, 0), 0.01)
	var node := prop(parent, "LowerShelf", preload("res://shaders/prop_shelf.gdshader"), surface.commit())
	(node.material_override as ShaderMaterial).set_shader_parameter("wood", wood)
	return node

static func average_colour(texture: Texture2D) -> Color:
	# One-off at build time: the board borrows the table's average wood tone.
	if texture == null: return Color(0.30, 0.16, 0.09)
	var image := texture.get_image()
	if image.is_compressed(): image.decompress()
	image.clear_mipmaps()
	image.resize(4, 4, Image.INTERPOLATE_BILINEAR)
	var total := Color(0, 0, 0, 0)
	for y in range(4):
		for x in range(4): total += image.get_pixel(x, y)
	return total / 16.0

static func game_boxes(parent: Node3D, table_top: float, x: float, z: float) -> Node3D:
	# A loose stack: one clamshell case between two cardboard cartridge boxes.
	# Vertex colour: g = kind (0 cardboard, 1 clamshell), b = artwork selection.
	# Bottom: cardboard-01; middle: clamshell-01; top: cardboard-02.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Keep the longer clamshell's centre supported by the smaller bottom carton.
	var stack := [[CARTON_SIZE, 0.0, 0.67, -9.0, Vector2(-0.02, 0.02), 0.5],
		[CLAMSHELL_SIZE, 1.0, 0.31, 0.0, Vector2(0.0, 0.0), 0.0],
		[CARTON_SIZE, 0.0, 0.13, 7.0, Vector2(0.03, 0.05), 1.0]]
	var height := 0.0
	for item in stack:
		var size: Vector3 = item[0] * SET_SCALE
		var placed := Transform3D(Basis(Vector3.UP, deg_to_rad(item[3])), Vector3(item[4].x * SET_SCALE, height + size.y * 0.5, item[4].y * SET_SCALE))
		box_into(surface, size, placed, Color(item[2], item[1], item[5]), 0.004 if item[1] < 0.5 else 0.008)
		height += size.y
	var node := prop(parent, "GameBoxes", preload("res://shaders/prop_game_box.gdshader"), surface.commit())
	var material := node.material_override as ShaderMaterial
	material.set_shader_parameter("carton_cover", preload("res://artwork/game-boxes/cardboard-01/cover.png"))
	material.set_shader_parameter("carton_spine", preload("res://artwork/game-boxes/cardboard-01/spine.png"))
	material.set_shader_parameter("carton_edge", preload("res://artwork/game-boxes/cardboard-01/edge.png"))
	material.set_shader_parameter("carton2_cover", preload("res://artwork/game-boxes/cardboard-02/cover.png"))
	material.set_shader_parameter("carton2_spine", preload("res://artwork/game-boxes/cardboard-02/spine.png"))
	material.set_shader_parameter("carton2_edge", preload("res://artwork/game-boxes/cardboard-02/edge.png"))
	material.set_shader_parameter("clamshell_cover", preload("res://artwork/game-boxes/clamshell-01/cover.png"))
	material.set_shader_parameter("clamshell_spine", preload("res://artwork/game-boxes/clamshell-01/spine.png"))
	material.set_shader_parameter("clamshell_edge", preload("res://artwork/game-boxes/clamshell-01/edge.png"))
	node.position = Vector3(x, table_top, z)
	# Only the bottom carton touches the table; the patch follows its turn and offset.
	var base: Array = stack[0]
	var base_size: Vector3 = base[0] * SET_SCALE
	var patch := contact_patch(node, Vector2(base_size.x, base_size.z), 0.0)
	patch.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(base[3])), Vector3(base[4].x * SET_SCALE, 0.0, base[4].y * SET_SCALE))
	return node
