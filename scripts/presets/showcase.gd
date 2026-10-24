extends RefCounted
## User-tuned Deck setup captured on 2026-10-15. Paths, tracking-axis flags
## and platform field of view are excluded; values rounded to six decimals.
## Prediction defaults to zero after updated-driver Gaming Mode acceptance.
const VIEW := {
	"right_stick_distance": true,
	"distance_speed": 1.0,
	"distance": 3.284008,
	"height_offset": -0.15,
	"ipd": 0.064,
	"convergence": 3.5,
	"edge_fade": 0.03,
	"smoothing": 0.0,
	"motion_predict": 0.0,
	"tv_scale": 1.0
}
const CRT := {
	"scanlines": 0.7,
	"phosphor_mask": 0.5,
	"phosphor_glow": 0.4,
	"glass_reflections": 0.4,
	"screen_curvature": 0.7
}
const ROOM := {
	"spill_strength": 0.5,
	"screen_bloom": 0.5,
	"ambient": 0.05,
	"key_energy": 0.3,
	"fill_energy": 0.1,
	"warmth": 0.7,
	"shadow_strength": 0.6,
	"cabinet_ao_strength": 0.7,
	"cabinet_grain_strength": 0.5,
	"lamp_height": 2.6,
	"lamp_side": -1.8,
	"floor_brightness": 1.15,
	"fade_begin": 3.5,
	"fade_end": 7.0,
	"shadows": true,
	"floor_style": 0,
	"show_clock_radio": true,
	"clock_24_hour": false,
	"show_vcr": true,
	"show_game_boxes": true,
	"show_game_cover": true,
	"follow_clock": false,
	"ambience": 0,
	"ambience_level": 0.5,
	"crt_whine": false
}
const PICTURE := {
	"width": 1.0,
	"height": 1.0,
	"shift_x": 0.0,
	"shift_y": 0.0,
	"safe_border": 0.015,
	"gamma": 2.25,
	"brightness": 1.0,
	"contrast": 1.0,
	"saturation": 1.0,
	"temperature": 0.0,
	"hue": 0.0,
	"composite_strength": 0.65,
	"artifact_strength": 0.35,
	"phase_noise": 0.38,
	"signal_motion": 0.95,
	"beam_softness": 3.0,
	"vignette": 0.06
}
const AUDIO := {
	"mode": 2,
	"room_amount": 0.18,
	"speaker_character": 0.15,
	"directional_strength": 0.8
}
const ATMOSPHERE := {
	"power_on": true,
	"power_sound": 0.6,
	"channel_change": true,
	"power_off": true
}
const CONNECTION := 2
const PER_GAME_PICTURE := false

static func config() -> ConfigFile:
	var result := ConfigFile.new()
	for key in VIEW: result.set_value("view","scale" if key=="tv_scale" else key,VIEW[key])
	for key in ROOM: result.set_value("room",key,ROOM[key])
	result.set_value("room","lighting_version",2)
	var names := {"phosphor_mask":"mask","phosphor_glow":"glow","glass_reflections":"glass","screen_curvature":"curvature"}
	for key in CRT: result.set_value("crt",names.get(key,key),CRT[key])
	for key in PICTURE: result.set_value("picture",key,PICTURE[key])
	result.set_value("picture","connection",CONNECTION)
	result.set_value("picture","keep_aspect",true)
	for key in AUDIO: result.set_value("audio",key,AUDIO[key])
	for key in ATMOSPHERE: result.set_value("atmosphere",key,ATMOSPHERE[key])
	result.set_value("preferences","per_game_picture",PER_GAME_PICTURE)
	result.set_value("preferences","metrics_visible",false)
	result.set_value("emulation","run_ahead",1)
	return result
