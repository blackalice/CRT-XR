extends TextureRect
## The CRT XR logo as real 3D: the letters of 'Animated Logo 2' (After
## Effects) rebuilt from their own outlines, each rising out of the logo as a
## solid block and settling flat again, one after another, as in the original.
## Geometry comes from assets/logo/logo-3d.json (scripts/make-logo-3d.py); the
## isometric view, keyframes and easing are After Effects' own. Rendered in
## its own small 3D world, only while it is on screen.
const DATA := "res://assets/logo/logo-3d.json"
## After Effects pixels to metres in this little world.
const UNIT := 0.002
## A rest between waves, so the logo settles before it plays again.
const PAUSE := 1.6
## A slow sway about the vertical, so it reads as solid even in one eye.
const SWAY_DEGREES := 7.0
const SWAY_SECONDS := 9.0
var view := SubViewport.new()
var space := Node3D.new()  # After Effects' layer space, turned as its null
var letters: Array = []  # [face node, side node, data]
var loop_seconds := 2.1667
var elapsed := 0.0
var camera := Camera3D.new()

func _init(render_size := Vector2i(720, 360)) -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.size = render_size
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(view)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	view.add_child(environment)
	var pivot := Node3D.new()
	pivot.name = "Sway"
	view.add_child(pivot)
	pivot.add_child(space)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 0, 10)
	camera.far = 40.0
	view.add_child(camera)
	build()

func _ready() -> void:
	texture = view.get_texture()

## After Effects is y-down with z away from the camera; Godot is y-up with z
## towards it. The null's rotations apply X after Z, as in After Effects.
static func ae_basis(rotation_xyz: Array) -> Basis:
	var x := Basis(Vector3.RIGHT, deg_to_rad(float(rotation_xyz[0])))
	var y := Basis(Vector3.UP, deg_to_rad(float(rotation_xyz[1])))
	var z := Basis(Vector3.BACK, deg_to_rad(float(rotation_xyz[2])))
	var flip := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
	return flip * x * y * z

func build() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not data is Dictionary: return
	loop_seconds = float(data.loop_seconds)
	space.basis = ae_basis(data.null_rotation_xyz).scaled(Vector3.ONE * UNIT)
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.vertex_color_use_as_albedo = true
	flat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bounds := AABB()
	var first := true
	for letter in data.letters:
		var holder := Node3D.new()
		holder.name = str(letter.name)
		space.add_child(holder)
		var face := MeshInstance3D.new()
		face.mesh = face_mesh(letter)
		face.material_override = flat
		holder.add_child(face)
		var sides := MeshInstance3D.new()
		sides.mesh = side_mesh(letter)
		sides.material_override = flat
		holder.add_child(sides)
		holder.position = Vector3(float(letter.position[0]), float(letter.position[1]), 0.0)
		letters.append([holder, sides, letter])
		# The logo's extent, for framing: front faces at rest, and fully raised.
		for depth in [0.0, -105.0]:
			var corners := face.mesh.get_aabb()
			corners.position += holder.position + Vector3(0, 0, depth)
			var world := space.transform * corners
			bounds = world if first else bounds.merge(world)
			first = false
	camera.size = maxf(bounds.size.y, bounds.size.x * float(view.size.y) / float(view.size.x)) * 1.08
	camera.position = Vector3(bounds.get_center().x, bounds.get_center().y, 10)
	show_at(loop_seconds + PAUSE)

## The front: its black outline and its coloured face, flat at the letter's z.
static func face_mesh(letter: Dictionary) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colour := Color(float(letter.colour[0]), float(letter.colour[1]), float(letter.colour[2]))
	for part in [[letter.outline_triangles, Color.BLACK], [letter.face_triangles, colour]]:
		var points: Array = part[0]
		surface.set_color(part[1])
		for i in range(0, points.size(), 2):
			# Slightly ahead of the outline, so the face never fights it for depth.
			surface.add_vertex(Vector3(float(points[i]), float(points[i + 1]), -0.4 if part[1] == colour else 0.0))
	return surface.commit()

## The extruded sides, one unit deep (z 0 to 1, away from the camera), scaled
## to the letter's extrusion. Pure black, as in the original logo.
static func side_mesh(letter: Dictionary) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_color(Color.BLACK)
	for ring in letter.rings:
		var count: int = ring.size() / 2
		for i in range(count):
			var a := Vector2(float(ring[i * 2]), float(ring[i * 2 + 1]))
			var j := (i + 1) % count
			var b := Vector2(float(ring[j * 2]), float(ring[j * 2 + 1]))
			var edge := b - a
			if edge.length() < 0.01: continue
			for corner in [Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(b.x, b.y, 1), Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 1), Vector3(a.x, a.y, 1)]:
				surface.add_vertex(corner)
	return surface.commit()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	show_at(fmod(elapsed, loop_seconds + PAUSE))
	var sway := sin(elapsed / SWAY_SECONDS * TAU) * deg_to_rad(SWAY_DEGREES)
	(view.get_node("Sway") as Node3D).rotation = Vector3(0, sway, 0)

## Each letter's place in the wave at this time.
func show_at(time: float) -> void:
	for entry in letters:
		var letter: Dictionary = entry[2]
		var depth := keyed(letter.extrusion_keys, time)
		entry[0].position.z = keyed(letter.z_keys, time) - 105.0
		# A depth of zero would collapse the sides into a sliver; hide them instead.
		entry[1].visible = depth > 0.5
		entry[1].scale = Vector3(1, 1, maxf(depth, 0.001))

## A keyframed value as After Effects eases it: each segment a cubic Bézier in
## time and value, with zero speed at the keys and the keys' influences.
static func keyed(keys: Array, time: float) -> float:
	if time <= float(keys[0][0]): return float(keys[0][1])
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if time <= float(b[0]):
			var span := float(b[0]) - float(a[0])
			var x := (time - float(a[0])) / span
			return lerpf(float(a[1]), float(b[1]), ease_bezier(x, float(a[3]) / 100.0, float(b[2]) / 100.0))
	return float(keys[-1][1])

## y at x on the curve (0,0) (out,0) (1-in,1) (1,1).
static func ease_bezier(x: float, out_influence: float, in_influence: float) -> float:
	var t := x
	for i in range(8):
		var u := 1.0 - t
		var bx := 3.0 * u * u * t * out_influence + 3.0 * u * t * t * (1.0 - in_influence) + t * t * t
		var dx := 3.0 * u * u * out_influence + 6.0 * u * t * (1.0 - in_influence - out_influence) + 3.0 * t * t * in_influence
		if absf(dx) < 0.00001: break
		t = clampf(t - (bx - x) / dx, 0.0, 1.0)
	var v := 1.0 - t
	return 3.0 * v * t * t + t * t * t
