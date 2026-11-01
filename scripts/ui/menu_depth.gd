extends Node
## Depth and motion for the menu, drawn per eye through shaders/menu_depth.gdshader.
## Every depth is a real distance in metres, turned into a horizontal shift with
## the same IPD, field of view and convergence as the eye cameras, so the menu
## sits in front of the TV and the selected row comes a little further forward.
## Mono views get no shift; a shadow and a slight scale-up carry the lift. The
## compact preview keeps the room undimmed so the picture can be judged.
const DEPTH_SHADER := preload("res://shaders/menu_depth.gdshader")
const DIM_SHADER := preload("res://shaders/menu_dim.gdshader")
## Nearest and farthest the menu floats; it always stays in front of the TV.
const MENU_DISTANCE := 2.0
const NEAREST := 1.2
## Lifted layers, as a share of the menu's distance.
const LIFT := 0.97
const PAGE_BACK := 1.12
## Curved menu: how much closer the side edges are than the centre, in metres.
const CURVE_DEPTH := 0.06
## The menu's pixel grid: shifts are whole cells of it.
const CELL := 2.0
const OPEN_SECONDS := 0.22
const PAGE_SECONDS := 0.18
const LIFT_SECONDS := 0.14

var host: Node
var menu: Control
var materials: Array[ShaderMaterial] = []
var dims: Array[ShaderMaterial] = []
var dim_nodes: Array[ColorRect] = []
var opening := 1.0
var paging := 1.0
var lifting := 1.0
var dimming := 0.0
var was_open := false
var page_key := ""
var lifted_id := ""

func setup(app: Node, overlays: Array, panels: Array) -> void:
	host = app
	menu = app.menu
	for i in range(overlays.size()):
		var material := ShaderMaterial.new()
		material.shader = DEPTH_SHADER
		material.set_shader_parameter("menu_tex", app.menu_view.get_texture())
		material.set_shader_parameter("tex_size", Vector2(app.menu_view.size))
		overlays[i].material = material
		materials.append(material)
		var dim := ColorRect.new()
		dim.name = "MenuDim"
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var dim_material := ShaderMaterial.new()
		dim_material.shader = DIM_SHADER
		dim.material = dim_material
		panels[i].add_child(dim)
		# Under the menu, over the room.
		panels[i].move_child(dim, overlays[i].get_index())
		dim.visible = false
		dims.append(dim_material)
		dim_nodes.append(dim)

## Progress towards 1, or finished at once when motion is reduced.
func advance(value: float, seconds: float, delta: float) -> float:
	return 1.0 if host.menu_reduced_motion else minf(1.0, value + delta / seconds)

func _process(delta: float) -> void:
	var open: bool = host.settings_panel.visible
	var depth: bool = host.menu_depth
	if not open:
		was_open = false
		dimming = 0.0
		for i in range(dims.size()): set_dim(i, 0.0)
		return
	var layout: Dictionary = menu.depth_layout()
	if not was_open:
		was_open = true
		opening = 0.0 if depth else 1.0
		page_key = str(layout.page_key)
		lifted_id = str(layout.selected)
	opening = advance(opening, OPEN_SECONDS, delta)
	if str(layout.page_key) != page_key:
		page_key = str(layout.page_key)
		paging = 0.0 if depth else 1.0
	paging = advance(paging, PAGE_SECONDS, delta)
	# A newly selected row rises in place; it never slides between rows.
	if str(layout.selected) != lifted_id:
		lifted_id = str(layout.selected)
		lifting = 0.0 if depth else 1.0
	lifting = advance(lifting, LIFT_SECONDS, delta)
	menu.column.modulate.a = lerpf(0.35, 1.0, ease_out(paging))
	# The menu on the TV is the TV's own picture: nothing floats, so nothing dims.
	var want_dim := 1.0 if depth and not menu.preview and not host.tv_menu.active else 0.0
	dimming = move_toward(dimming, want_dim, delta / 0.2) if not host.menu_reduced_motion else want_dim
	for i in range(materials.size()):
		apply_eye(i, layout, depth)
		set_dim(i, dimming * ease_out(opening))

func set_dim(i: int, strength: float) -> void:
	dims[i].set_shader_parameter("strength", strength)
	dim_nodes[i].visible = strength > 0.001

func ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)

func menu_distance() -> float:
	return clampf(minf(MENU_DISTANCE, float(host.distance) * 0.75), NEAREST, MENU_DISTANCE)

## Horizontal shift, in menu texture pixels, that places a layer at `metres`
## for eye `i` (left eye to the right, right eye to the left).
func shift(i: int, metres: float) -> float:
	if not host.stereo: return 0.0
	var panel: Control = host.panels[i]
	var fit := minf(panel.size.x / float(host.menu_view.size.x), panel.size.y / float(host.menu_view.size.y))
	if fit <= 0.0: return 0.0
	var focal := panel.size.y * 0.5 / tan(deg_to_rad(float(host.vertical_fov)) * 0.5)
	var screen := float(host.ipd) * 0.5 * focal * (1.0 / metres - 1.0 / float(host.convergence))
	return (1.0 if i == 0 else -1.0) * screen / fit

static func as_vec4(rect: Rect2) -> Vector4:
	return Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)

func apply_eye(i: int, layout: Dictionary, depth: bool) -> void:
	var material := materials[i]
	if not depth:
		for key in ["base_shift", "page_shift", "lift_shift", "shadow", "curve_shift", "curve_height"]: material.set_shader_parameter(key, 0.0)
		for key in ["page_rect", "lift_rect"]: material.set_shader_parameter(key, Vector4.ZERO)
		material.set_shader_parameter("lift_scale", 1.0)
		material.set_shader_parameter("scale", 1.0)
		material.set_shader_parameter("fade", 1.0)
		return
	var near := menu_distance()
	var open := ease_out(opening)
	# Opening glides in from behind the TV to the menu's place.
	var start := maxf(float(host.convergence), float(host.distance)) + 0.5
	var here := lerpf(start, near, open)
	# The 16-bit menu is one flat plane: no curve, no page step, no lifted row.
	# Each of those resampled the 2-pixel grid differently for each eye, and the
	# mismatch shimmered. Shifting by whole cells keeps both eyes on the grid.
	material.set_shader_parameter("base_shift", roundf(shift(i, here) / CELL) * CELL)
	for key in ["page_shift", "lift_shift", "shadow", "curve_shift", "curve_height"]: material.set_shader_parameter(key, 0.0)
	for key in ["page_rect", "lift_rect"]: material.set_shader_parameter(key, Vector4.ZERO)
	material.set_shader_parameter("lift_scale", 1.0)
	material.set_shader_parameter("scale", lerpf(0.96, 1.0, open) if open < 1.0 else 1.0)
	material.set_shader_parameter("fade", open)
