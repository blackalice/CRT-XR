extends Node
## Short TV moments on the tube: static and a picture roll when a game or video
## starts (a channel change), a degauss on request, and the power-off as CRT XR
## closes. Each drives uniforms in crt.gdshader and plays a sound synthesised by
## scripts/make-tv-sounds.py. One moment at a time; a new one replaces it.
signal finished(effect: String)
const SOUNDS := {
	"channel": preload("res://assets/audio/tv/channel.wav"),
	"degauss": preload("res://assets/audio/tv/degauss.wav"),
	"power_off": preload("res://assets/audio/tv/power-off.wav"),
}
const DURATION := {"channel": 0.45, "degauss": 1.6, "power_off": 0.75}
var channel_change := true
var power_off_effect := true
var reduced_motion := false
## The power-on node: its sound level is the level for all the TV's own sounds.
var power_on: Node
var material: ShaderMaterial
var screen_light: Node3D
var tv_audio: Node
var cue := AudioStreamPlayer.new()
var effect := ""
var elapsed := 0.0

func setup(screen: ShaderMaterial, light: Node3D, audio: Node) -> void:
	material = screen; screen_light = light; tv_audio = audio
	add_child(cue)
	set_process(false)

## Starts a moment; false when it is switched off and nothing will happen.
func play(name: String) -> bool:
	if name == "channel" and not channel_change: return false
	# Closing with no screen (headless runs) has nothing to show.
	if name == "power_off" and (not power_off_effect or reduced_motion or DisplayServer.get_name() == "headless"): return false
	if not DURATION.has(name) or material == null: return false
	if not effect.is_empty(): clear()
	effect = name
	elapsed = 0.0
	cue.stream = SOUNDS[name]
	cue.bus = tv_audio.player.bus
	var level: float = power_on.sound_level if power_on != null else 0.6
	cue.volume_db = linear_to_db(maxf(level, 0.00001)) - 6.0
	if level > 0.0 and DisplayServer.get_name() != "headless": cue.play()
	material.set_shader_parameter("degauss_wobble", not reduced_motion)
	set_process(true)
	_show(0.0)
	return true

func _process(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	var t := elapsed / float(DURATION[effect])
	if t < 1.0:
		_show(t)
		return
	var done := effect
	# The power-off leaves the tube dark until the app closes.
	if done == "power_off": _show(1.0); set_process(false); effect = ""
	else: clear()
	finished.emit(done)

func _show(t: float) -> void:
	match effect:
		"channel":
			material.set_shader_parameter("channel_static", 1.0 - smoothstep(0.30, 1.0, t))
			material.set_shader_parameter("picture_roll", 0.0 if reduced_motion else pow(1.0 - t, 2.0) * 0.55)
		"degauss":
			material.set_shader_parameter("degauss", pow(1.0 - t, 1.5) * (0.5 if reduced_motion else 1.0))
		"power_off":
			material.set_shader_parameter("power_off", t)
			if is_instance_valid(screen_light): screen_light.power_level = 1.0 - smoothstep(0.0, 0.5, t)

## Back to a steady picture straight away.
func clear() -> void:
	effect = ""
	set_process(false)
	cue.stop()
	if material == null: return
	for uniform in ["channel_static", "picture_roll", "degauss", "power_off"]:
		material.set_shader_parameter(uniform, 0.0)
