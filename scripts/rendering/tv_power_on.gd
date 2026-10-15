extends Node
## One short tube-only reveal. No extra viewport, overlay or 3D pass.
const DURATION := 0.70
const SOUND = preload("res://assets/audio/crt-power-on.wav")
var enabled := true
var sound_level := 0.60
var started := false
var elapsed := 0.0
var progress := 1.0
var material: ShaderMaterial
var screen_light: Node3D
var tv_audio: Node
var cue := AudioStreamPlayer.new()

func setup(screen: ShaderMaterial, light: Node3D, audio: Node) -> void:
	material=screen; screen_light=light
	tv_audio=audio
	add_child(cue)
	cue.stream=SOUND
	set_process(false)
	set_progress(0.0)

func apply() -> void:
	sound_level=clampf(sound_level,0.0,1.0)
	cue.volume_db=linear_to_db(maxf(sound_level,0.00001))-6.0
	if not enabled:
		cue.stop(); set_progress(1.0); set_process(false)
	elif not started: set_progress(0.0)
	if sound_level==0.0: cue.stop()

func begin(force := false) -> void:
	if started and not force: return
	started=true
	cue.stop()
	if not enabled:
		set_progress(1.0); return
	elapsed=0.0
	set_progress(0.0)
	cue.bus=tv_audio.player.bus
	if sound_level>0.0 and DisplayServer.get_name()!="headless": cue.play()
	set_process(true)

func set_progress(value: float) -> void:
	progress=clampf(value,0.0,1.0)
	if material!=null: material.set_shader_parameter("power_progress",progress)
	if is_instance_valid(screen_light): screen_light.power_level=smoothstep(0.12,1.0,progress)

func _process(delta: float) -> void:
	elapsed+=maxf(delta,0.0)
	set_progress(elapsed/DURATION)
	if progress>=1.0: set_process(false)
