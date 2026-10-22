extends Node
const Showcase = preload("res://scripts/presets/showcase.gd")
## Safe tube fitting + one shared analog decode pass. RGB bypasses the pass.
const FIT_FIELDS := [
	["width", "Picture width limit", 0.5, 1.0, 0.01, 1.0],
	["height", "Picture height limit", 0.5, 1.0, 0.01, 1.0],
	["shift_x", "Horizontal position", -1.0, 1.0, 0.05, 0.0],
	["shift_y", "Vertical position", -1.0, 1.0, 0.05, 0.0],
	["safe_border", "Extra safe border", 0.0, 0.1, 0.005, 0.015]]
const COLOR_FIELDS := [
	["gamma", "Display gamma (lower = lighter)", 1.6, 2.8, 0.05, 2.25],
	["brightness", "Picture brightness", 0.5, 1.5, 0.05, 1.0],
	["contrast", "Picture contrast", 0.6, 1.4, 0.05, 1.0],
	["saturation", "Colour saturation", 0.0, 1.5, 0.05, 1.0],
	["temperature", "Colour warmth", -1.0, 1.0, 0.05, 0.0],
	["hue", "Hue adjustment (degrees)", -30.0, 30.0, 1.0, 0.0],
	["composite_strength", "Composite strength", 0.0, 1.0, 0.05, 0.65],
	["artifact_strength", "Composite artifacts", 0.0, 1.0, 0.05, 0.35],
	["phase_noise", "Chroma phase noise", 0.0, 0.5, 0.01, Showcase.PICTURE.phase_noise],
	["signal_motion", "Moving signal artifacts", 0.0, 1.0, 0.05, Showcase.PICTURE.signal_motion]]
const BEAM_FIELDS := [
	["beam_softness", "Beam sharpness", 1.0, 8.0, 0.25, 3.0],
	["vignette", "Tube edge shading", 0.0, 0.2, 0.01, 0.06]]
const MODES := ["RGB / component", "NTSC composite", "PAL composite", "Auto composite (game rate)"]
var values: Dictionary = {}
var keep_aspect := true
var guides := false
var mode := Showcase.CONNECTION
var source_rate := 60.0
var paused := false
var elapsed := 0.0
var safe_rect := Rect2(0.03, 0.03, 0.94, 0.94)
var tube_aspect := 4.0 / 3.0
var source_aspect := 4.0 / 3.0
var source_size := Vector2(256, 240)
var source_texture: Texture2D
var screen: ShaderMaterial
var decode := SubViewport.new()
var decoder := ShaderMaterial.new()
var was_paused := false
var shared_beam_enabled := true # Reference path retained for measured A/B checks.
var beam := SubViewport.new()
var beam_filter := ShaderMaterial.new()
var beam_active := false
# With an emulator source the shared passes redraw once per new game frame (or
# composite frame index) rather than every display frame: 50 Hz games and
# 72/90/120 Hz displays no longer recompute identical output.
var frame_driven := false
var frame_pending := true
var last_frame_index := -1.0
var decode_active := false

func _init() -> void:
	for field in all_fields(): values[field[0]] = field[5]

func all_fields() -> Array:
	return FIT_FIELDS + COLOR_FIELDS + BEAM_FIELDS

func configure(material: ShaderMaterial, texture: Texture2D, aperture: Rect2, aspect: float) -> void:
	screen = material
	safe_rect = aperture
	tube_aspect = aspect
	decode.name = "SharedAnalogSignal"
	decode.disable_3d = true
	decode.size = Vector2i(1024, 240)
	decode.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(decode)
	decoder.shader = preload("res://shaders/analog_signal.gdshader")
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.material = decoder
	decode.add_child(rect)
	beam.name = "SharedBeamReconstruction"
	beam.disable_3d = true
	beam.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(beam)
	beam_filter.shader = preload("res://shaders/crt_beam.gdshader")
	var beam_rect := ColorRect.new()
	beam_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	beam_rect.material = beam_filter
	beam.add_child(beam_rect)
	screen.set_shader_parameter("beam_texture",beam.get_texture())
	set_source(texture)

func set_source(texture: Texture2D, driven_by_frames := false) -> void:
	frame_driven = driven_by_frames
	frame_pending = true
	source_texture = texture
	source_size = Vector2(texture.get_width(), texture.get_height())
	decode.size = Vector2i(1024, int(source_size.y))
	beam.size = Vector2i(clampi(int(source_size.x)*4,1024,2048),int(source_size.y)*2)
	decoder.set_shader_parameter("source_texture", texture)
	decoder.set_shader_parameter("source_size", source_size)
	refresh()

func set_value(key: String, value: float) -> void:
	for field in all_fields():
		if field[0] == key:
			values[key] = clampf(value, field[2], field[3])
			refresh()
			return

func effective_mode() -> int:
	return (2 if source_rate < 55.0 else 1) if mode == 3 else mode

func picture_rect() -> Rect2:
	var border := Vector2.ONE * float(values.safe_border)
	var area := Rect2(safe_rect.position + border, safe_rect.size - 2.0 * border)
	var size := area.size * Vector2(values.width, values.height)
	if keep_aspect:
		var available_aspect := tube_aspect * size.x / size.y
		if available_aspect > source_aspect: size.x *= source_aspect/available_aspect
		else: size.y *= available_aspect/source_aspect
	var slack := area.size - size
	var offset := Vector2(values.shift_x, values.shift_y).clamp(Vector2(-1,-1), Vector2.ONE)
	return Rect2(area.position + slack * (Vector2.ONE + offset) * 0.5, size)

func refresh() -> void:
	if screen == null: return
	var area := picture_rect()
	screen.set_shader_parameter("picture_rect", Vector4(area.position.x, area.position.y, area.size.x, area.size.y))
	screen.set_shader_parameter("signal_size", source_size)
	screen.set_shader_parameter("fitting_guides", guides)
	for key in ["gamma", "brightness", "contrast", "saturation", "beam_softness", "vignette"]:
		screen.set_shader_parameter(key, values[key])
	var angle := deg_to_rad(float(values.hue))
	screen.set_shader_parameter("hue_rotation", Vector2(cos(angle), sin(angle)))
	screen.set_shader_parameter("white_balance", Vector3(1.0 + values.temperature*0.08, 1.0, 1.0-values.temperature*0.10))
	var basis := colour_basis_for(values)
	screen.set_shader_parameter("colour_matrix",basis)
	for key in ["composite_strength", "artifact_strength", "phase_noise", "signal_motion"]:
		decoder.set_shader_parameter(key, values[key])
	decoder.set_shader_parameter("signal_standard", effective_mode())
	var active := effective_mode() != 0 and float(values.composite_strength) > 0.0
	decode_active = active
	screen.set_shader_parameter("signal_texture", decode.get_texture() if active else source_texture)
	decode.render_target_update_mode = pass_mode(active)
	beam_filter.set_shader_parameter("signal_texture",decode.get_texture() if active else source_texture)
	beam_filter.set_shader_parameter("signal_size",source_size)
	for key in ["gamma","brightness","contrast","saturation","beam_softness"]:
		beam_filter.set_shader_parameter(key,values[key])
	beam_filter.set_shader_parameter("hue_rotation",Vector2(cos(angle),sin(angle)))
	beam_filter.set_shader_parameter("white_balance",Vector3(1.0+values.temperature*.08,1.0,1.0-values.temperature*.10))
	beam_filter.set_shader_parameter("colour_matrix",basis)
	update_beam_state(true)

static func colour_basis_for(settings: Dictionary) -> Basis:
	var angle := deg_to_rad(float(settings.hue))
	var columns: Array[Vector3] = []
	for rgb in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
		var y: float = rgb.dot(Vector3(.299,.587,.114))
		var i: float = rgb.dot(Vector3(.595716,-.274453,-.321263))
		var q: float = rgb.dot(Vector3(.211456,-.522591,.311135))
		var next_i := (i*cos(angle)-q*sin(angle))*float(settings.saturation)
		var next_q := (i*sin(angle)+q*cos(angle))*float(settings.saturation)
		columns.append(Vector3(y+.9563*next_i+.6210*next_q,y-.2721*next_i-.6474*next_q,y-1.1070*next_i+1.7046*next_q))
	return Basis(columns[0],columns[1],columns[2])

func update_beam_state(force := false) -> void:
	var strength = screen.get_shader_parameter("scanlines")
	var active := shared_beam_enabled and (float(strength) if strength != null else .22) > .001
	if force or active != beam_active:
		beam_active = active
		screen.set_shader_parameter("use_shared_beam",active)
		beam.render_target_update_mode = pass_mode(active)

func pass_mode(active: bool) -> int:
	if not active: return SubViewport.UPDATE_DISABLED
	return SubViewport.UPDATE_ONCE if paused or frame_driven else SubViewport.UPDATE_ALWAYS

func frame_presented(_image: Image = null) -> void:
	frame_pending = true

func _process(delta: float) -> void:
	update_beam_state()
	if not paused: elapsed += delta
	var frame_index := floorf(elapsed * source_rate)
	var index_changed := frame_index != last_frame_index
	if index_changed:
		last_frame_index = frame_index
		decoder.set_shader_parameter("frame_index", frame_index)
	if frame_driven and not paused and (frame_pending or index_changed):
		frame_pending = false
		if decode_active: decode.render_target_update_mode = SubViewport.UPDATE_ONCE
		if beam_active: beam.render_target_update_mode = SubViewport.UPDATE_ONCE
	if paused != was_paused:
		was_paused = paused
		refresh()

func reset_fields(fields: Array) -> void:
	for field in fields: values[field[0]] = field[5]
	refresh()

func preset(name: String) -> void:
	reset_fields(COLOR_FIELDS)
	reset_fields(BEAM_FIELDS)
	mode = 0
	values.phase_noise=0.0; values.signal_motion=0.0
	if name == "pal": mode = 2
	elif name == "ntsc": mode = 1
	elif name == "auto": mode = 3
	if name == "clean":
		values.gamma = 2.2
		values.vignette = 0.0
	elif mode != 0:
		values.gamma = 2.35
		values.saturation = 0.95
		values.temperature = 0.15
		values.phase_noise = 0.25
		values.signal_motion = 0.60
	refresh()
