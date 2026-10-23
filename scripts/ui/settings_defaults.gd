extends RefCounted
const LinuxTracking = preload("res://scripts/tracking/xr_linux_tracking.gd")

const Showcase = preload("res://scripts/presets/showcase.gd")
const VIEW := Showcase.VIEW
const PICTURE := Showcase.CRT
const ROOM := Showcase.ROOM
const SLIDERS := {"TV distance (m)": "distance", "Screen height offset (m)": "height_offset",
	"Distance adjustment speed": "distance_speed", "TV scale": "tv_scale", "IPD (m)": "ipd",
	"Convergence (m)": "convergence", "Soft view edges": "edge_fade", "Smoothing (seconds)": "smoothing",
	"Motion prediction (seconds)": "motion_predict",
	"Scanlines": "scanlines", "Phosphor mask": "phosphor_mask", "Phosphor glow": "phosphor_glow",
	"Glass reflections": "glass_reflections", "Screen curvature (0 = flat)": "screen_curvature"}

static func slider_default(caption: String, app: Node) -> Variant:
	if caption == "Vertical field of view": return 24.0 if app.provider.real else 50.0
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
			app.set_remember_game_picture(Showcase.PER_GAME_PICTURE)
		1:
			for key in VIEW: app.set(key, VIEW[key])
			app.vertical_fov = 24.0 if app.provider.real else 50.0
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
			app.world.picture.mode = Showcase.CONNECTION
			app.world.picture.refresh()
		3:
			for key in ROOM: app.world.set(key, ROOM[key])
			app.world.apply_room_settings()
		4:
			for axis in ["yaw", "pitch", "roll"]: app.provider.set("invert_" + axis, false)
			app.metrics_visible = false
