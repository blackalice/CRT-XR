extends RefCounted
const LinuxTracking = preload("res://scripts/tracking/xr_linux_tracking.gd")

const VIEW := {"distance": 3.4, "height_offset": 0.0, "tv_scale": 1.0,
	"ipd": 0.064, "convergence": 2.6, "smoothing": 0.0, "motion_predict": 0.03, "edge_fade": 0.075,
	"right_stick_distance": true, "distance_speed": 1.0}
const PICTURE := {"scanlines": 0.22, "phosphor_mask": 0.10,
	"phosphor_glow": 0.12, "glass_reflections": 0.12, "screen_curvature": 0.55}
const ROOM := {"spill_strength": 0.10, "ambient": 0.45, "key_energy": 4.5, "fill_energy": 1.6,
	"warmth": 0.70, "lamp_height": 2.6, "lamp_side": -1.8,
	"fade_begin": 4.5, "fade_end": 9.0, "floor_brightness": 1.15,
	"shadows": true, "shadow_strength": 0.60, "cabinet_ao_strength": 0.70,
	"cabinet_grain_strength": 0.55, "show_rug": true}
const SLIDERS := {"TV distance (m)": "distance", "Screen height offset (m)": "height_offset",
	"Distance adjustment speed": "distance_speed", "TV scale": "tv_scale", "IPD (m)": "ipd",
	"Convergence (m)": "convergence", "Soft view edges": "edge_fade", "Smoothing (seconds)": "smoothing",
	"Motion prediction (seconds)": "motion_predict",
	"Scanlines": "scanlines", "Phosphor mask": "phosphor_mask", "Phosphor glow": "phosphor_glow",
	"Glass reflections": "glass_reflections", "Screen curvature (0 = flat)": "screen_curvature"}

static func slider_default(caption: String, app: Node) -> Variant:
	if caption == "Vertical field of view": return 24.0 if app.provider is LinuxTracking else 50.0
	if SLIDERS.has(caption):
		var key: String = SLIDERS[caption]
		return VIEW[key] if VIEW.has(key) else PICTURE[key]
	for field in app.ROOM_FIELDS:
		if field[1] == caption: return ROOM[field[0]]
	for field in app.world.picture.all_fields():
		if field[1] == caption: return field[5]
	return null

static func apply(app: Node, tab: int) -> void:
	match tab:
		0:
			app.emulator.run_ahead = 1
			app.set_remember_game_picture(true)
		1:
			for key in VIEW: app.set(key, VIEW[key])
			app.vertical_fov = 24.0 if app.provider is LinuxTracking else 50.0
			app.distance_save_delay = -1.0
			app.fade_material.set_shader_parameter("fade_width", app.edge_fade)
		2:
			for key in PICTURE: app.set(key, PICTURE[key])
			app.world.screen_material.set_shader_parameter("scanlines", app.scanlines)
			app.world.screen_material.set_shader_parameter("mask_strength", app.phosphor_mask)
			app.world.screen_material.set_shader_parameter("glow_strength", app.phosphor_glow)
			app.world.glass_material.set_shader_parameter("reflection_strength", app.glass_reflections)
			app.world.set_curvature(app.screen_curvature)
			app.world.picture.reset_fields(app.world.picture.BEAM_FIELDS)
			app.world.picture.reset_fields(app.world.picture.FIT_FIELDS)
			app.world.picture.reset_fields(app.world.picture.COLOR_FIELDS)
			app.world.picture.keep_aspect = true
			app.world.picture.guides = false
			app.world.picture.mode = 0
			app.world.picture.refresh()
		3:
			for key in ROOM: app.world.set(key, ROOM[key])
			app.world.apply_room_settings()
		4:
			for axis in ["yaw", "pitch", "roll"]: app.provider.set("invert_" + axis, false)
			for label in app.diagnostics: label.visible = true
