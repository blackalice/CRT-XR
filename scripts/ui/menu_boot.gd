extends Control
## One shared native sequence: AE diamond pulses and logo flip, then UI rows.
const DURATION := 3.8
const REVEAL := 2.95
const LOGO := preload("res://assets/branding/logo/boot-logo.svg")
const DIAMONDS := [preload("res://assets/branding/logo/boot-diamond-0.svg"), preload("res://assets/branding/logo/boot-diamond-1.svg"), preload("res://assets/branding/logo/boot-diamond-2.svg")]
const MOTION_PATH := "res://assets/branding/logo/boot-motion.json"
var menu: PanelContainer
var elapsed := 0.0
var active := true
var prepared := false
var targets: Array = []
var mark: TextureRect
var diamonds: Array[TextureRect] = []
var frames: Array = []
var material_space: ShaderMaterial
var material_logo: ShaderMaterial
var layout: Control
var layout_colour: Color
var prepare_frames := 3

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	material_space = menu.backdrop.material
	frames = JSON.parse_string(FileAccess.get_file_as_string(MOTION_PATH)).frames
	layout = menu.heading.get_parent().get_parent()
	layout_colour = layout.modulate
	layout.modulate.a = 0.0
	material_logo = ShaderMaterial.new()
	material_logo.shader = preload("res://shaders/boot_logo.gdshader")
	mark = make_mark(LOGO)
	add_child(mark)
	for texture in DIAMONDS:
		var diamond := make_mark(texture)
		mark.add_child(diamond)
		diamond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		diamonds.append(diamond)
	seek(0.0)
	get_tree().process_frame.connect(prepare_step)

func prepare_step() -> void:
	prepare_frames -= 1
	if prepare_frames > 0: return
	get_tree().process_frame.disconnect(prepare_step)
	prepare()

func make_mark(texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.material = material_logo
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func prepare() -> void:
	# Wrapped titles and the resume card must settle before grouping visual rows.
	if not active: return
	for child in layout.get_children():
		var at := REVEAL
		if child == menu.body: at = REVEAL
		elif child == menu.help_frame: at = REVEAL + 0.62
		elif child == menu.hints.get_parent(): at = REVEAL + 0.70
		targets.append([child, child.modulate, at])
	var content: Array[Control] = []
	collect_rows(menu.column, content)
	content.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	var last_y := -10000.0
	var visual_row := -1
	for child in content:
		if absf(child.global_position.y - last_y) > 4.0:
			visual_row += 1
			last_y = child.global_position.y
		targets.append([child, child.modulate, REVEAL + 0.08 + minf(visual_row * 0.055, 0.44)])
	prepared = true
	seek(elapsed)
	layout.modulate = layout_colour

func collect_rows(parent: Control, content: Array[Control]) -> void:
	for child in parent.get_children():
		if not child is Control or not child.visible: continue
		if child in menu.rows:
			content.append(child)
		elif child is BoxContainer or child is GridContainer:
			collect_rows(child, content)
		else:
			content.append(child)

func _process(delta: float) -> void:
	if not menu.visible or menu.host.menu_reduced_motion or menu.host.menu_high_contrast:
		finish()
		return
	if prepared: seek(elapsed + minf(delta, 0.05))

## Explicit time also lets visual checks sample the real sequence deterministically.
func seek(seconds: float) -> void:
	if not active: return
	elapsed = seconds
	# Values sampled at 60 Hz from Comp 7, including Shapes 3 time remapping.
	var frame_at := clampf(elapsed * 60.0, 0.0, frames.size() - 1.0)
	var a: Array = frames[int(frame_at)]
	var b: Array = frames[mini(int(frame_at) + 1, frames.size() - 1)]
	var blend := frame_at - floorf(frame_at)
	mark.modulate.a = lerpf(a[4], b[4], blend)
	material_logo.set_shader_parameter("angle", lerpf(a[5], b[5], blend))
	material_space.set_shader_parameter("boot_settle", lerpf(a[6], b[6], blend))
	var squeeze := lerpf(a[3], b[3], blend)
	mark.size = Vector2(348, 400) * squeeze
	mark.position = ((size - mark.size) * 0.5).snapped(Vector2(2, 2))
	for i in range(3): diamonds[i].modulate.a = lerpf(a[i], b[i], blend)
	for target in targets:
		if is_instance_valid(target[0]):
			var colour: Color = target[1]
			colour.a *= floorf(clampf((elapsed - target[2]) / 0.065, 0.0, 1.0) * 4.0) / 4.0
			target[0].modulate = colour
	if elapsed >= DURATION: finish(false)

func handle(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventMouseButton and event.pressed):
		# Reveal the menu on input, but let the boot cue finish unless cancelled.
		finish(cancel_pressed(event))

static func cancel_pressed(event: InputEvent) -> bool:
	return (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B) or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE,KEY_BACKSPACE])

func finish(interrupted := true) -> void:
	if not active: return
	active = false
	if interrupted:
		menu.host.menu_boot_pending = false
		menu.host.stop_boot_sound()
	if get_tree().process_frame.is_connected(prepare_step):
		get_tree().process_frame.disconnect(prepare_step)
	material_space.set_shader_parameter("boot_settle", 1.0)
	layout.modulate = layout_colour
	for target in targets:
		if is_instance_valid(target[0]): target[0].modulate = target[1]
	menu.clear_input()
	queue_free()
