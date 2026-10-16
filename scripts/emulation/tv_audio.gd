extends Node
## One stream and one shared mixer bus, independent of the two eye viewports.
## Native effects process existing audio blocks; no extra generator or delay line
## is introduced into the direct path. Room reflections alone are delayed.
const Showcase = preload("res://scripts/presets/showcase.gd")
const DEFAULTS := Showcase.AUDIO
var mode: int = DEFAULTS.mode
var room_amount: float = DEFAULTS.room_amount
var speaker_character: float = DEFAULTS.speaker_character
var directional_strength: float = DEFAULTS.directional_strength
var preview_player: AudioStreamPlayer
var player: AudioStreamPlayer
var bus_name := ""
var eq := AudioEffectEQ6.new()
var width := AudioEffectStereoEnhance.new()
var panner := AudioEffectPanner.new()
var room := AudioEffectReverb.new()
var current_pan := 0.0
var room_active := false

func setup(source: AudioStreamPlayer) -> void:
	player=source
	preview_player=AudioStreamPlayer.new(); preview_player.name="SoundPreview"
	preview_player.stream=preload("res://assets/audio/crt-power-on.wav")
	preview_player.volume_db=-6.0; add_child(preview_player)
	bus_name="RetroCRT TV "+str(get_instance_id())
	AudioServer.add_bus()
	var index := AudioServer.bus_count-1
	AudioServer.set_bus_name(index,bus_name)
	AudioServer.set_bus_send(index,"Master")
	width.surround=0.0
	width.time_pullout_ms=0.0
	room.dry=1.0
	room.room_size=0.24
	room.damping=0.75
	room.predelay_msec=12.0
	room.predelay_feedback=0.0
	room.spread=0.65
	for effect in [eq,width,panner,room]: AudioServer.add_bus_effect(index,effect)
	apply()

func apply() -> void:
	mode=clampi(mode,0,2)
	room_amount=clampf(room_amount,0.0,0.25)
	speaker_character=clampf(speaker_character,0.0,1.0)
	directional_strength=clampf(directional_strength,0.0,1.0)
	if player==null: return
	var index := AudioServer.get_bus_index(bus_name)
	if index<0: return
	# EQ6 centres: 32, 100, 320, 1000, 3200, 10000 Hz. Cut only.
	var cuts := [-14.0,-6.0,-1.0,0.0,-1.0,-7.0]
	for band in range(eq.get_band_count()): eq.set_band_gain_db(band,cuts[band]*speaker_character)
	width.pan_pullout=lerpf(1.0,0.40,speaker_character)
	room.wet=room_amount if mode==2 else 0.0
	var active := mode==2 and room_amount>0.0
	if active!=room_active:
		clear_tail()
		room_active=active
	for effect in range(4):
		var enabled := false
		if effect<2: enabled=mode!=0 and speaker_character>0.0
		elif mode==2: enabled=directional_strength>0.0 if effect==2 else room_amount>0.0
		AudioServer.set_bus_effect_enabled(index,effect,enabled)
	player.bus="Master" if mode==0 else bus_name
	preview_player.bus=player.bus
	if mode!=2 or directional_strength==0.0:
		current_pan=0.0; panner.pan=0.0

func update_pose(orientation: Quaternion, listener: Vector3, television: Vector3, delta: float) -> void:
	if mode!=2: return
	var local := orientation.inverse()*(television-listener)
	var target := 0.0
	if local.length_squared()>0.000001:
		target=clampf(local.normalized().x,-1.0,1.0)*0.55*directional_strength
	current_pan=lerpf(current_pan,target,1.0-exp(-maxf(delta,0.0)/0.025))
	panner.pan=current_pan

func clear_tail() -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index<0 or AudioServer.get_bus_effect_count(index)!=4: return
	# Recreate the mixer instance so old reflections cannot return after a pause,
	# a core switch, or toggling the room effect off and back on.
	var enabled := AudioServer.is_bus_effect_enabled(index,3)
	AudioServer.remove_bus_effect(index,3)
	AudioServer.add_bus_effect(index,room,3)
	AudioServer.set_bus_effect_enabled(index,3,enabled)

func reset_defaults() -> void:
	for key in DEFAULTS: set(key,DEFAULTS[key])
	apply()

func _exit_tree() -> void:
	if is_instance_valid(player): player.bus="Master"
	var index := AudioServer.get_bus_index(bus_name)
	if index>0: AudioServer.remove_bus(index)

func preview_sample() -> void:
	if preview_player==null or DisplayServer.get_name()=="headless": return
	preview_player.stop(); preview_player.bus=player.bus; preview_player.play()
