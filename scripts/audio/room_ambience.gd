extends Node
## Quiet sound for the room around the TV: still air, rain on the window, or
## rain with a ticking clock; and, for those who remember it, the tube's high
## whine. All synthesised by scripts/make-tv-sounds.py, all off by default.
const CHOICES := ["Off", "Quiet room", "Rain on the window", "Rain and a ticking clock"]
const BEDS := [null, preload("res://assets/audio/tv/ambience-room.wav"), preload("res://assets/audio/tv/ambience-rain.wav"), preload("res://assets/audio/tv/ambience-rain.wav")]
const TICK := preload("res://assets/audio/tv/clock-tick.wav")
const TOCK := preload("res://assets/audio/tv/clock-tock.wav")
const WHINE := preload("res://assets/audio/tv/crt-whine.wav")
## Room sound sits well under the programme; the whine is barely there.
const BED_DB := -14.0
const TICK_DB := -20.0
const WHINE_DB := -38.0
var ambience := 0
var level := 0.5
var whine := false
var bed := AudioStreamPlayer.new()
var clock := AudioStreamPlayer.new()
var tube := AudioStreamPlayer.new()
var shown_second := -1
var tock := false

func _init() -> void:
	name = "RoomAmbience"
	for player in [bed, clock, tube]: add_child(player)
	tube.stream = looped(WHINE)
	set_process(false)

static func looped(sound: AudioStreamWAV) -> AudioStreamWAV:
	var loop: AudioStreamWAV = sound.duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	return loop

## Starts, changes or stops the sounds to match the settings.
func apply() -> void:
	ambience = clampi(ambience, 0, CHOICES.size() - 1)
	level = clampf(level, 0.0, 1.0)
	var audible := level > 0.0 and DisplayServer.get_name() != "headless"
	var gain := linear_to_db(maxf(level, 0.00001))
	if ambience == 0 or not audible: bed.stop()
	else:
		var stream: AudioStreamWAV = BEDS[ambience]
		if bed.stream == null or bed.stream.resource_name != stream.resource_path:
			bed.stream = looped(stream)
			bed.stream.resource_name = stream.resource_path
		bed.volume_db = gain + BED_DB
		if not bed.playing: bed.play()
	clock.volume_db = gain + TICK_DB
	set_process(ambience == 3 and audible)
	tube.volume_db = WHINE_DB
	if whine and DisplayServer.get_name() != "headless":
		if not tube.playing: tube.play()
	else: tube.stop()

## The clock ticks on the real second, alternating tick and tock.
func _process(_delta: float) -> void:
	var second := int(Time.get_unix_time_from_system())
	if second == shown_second: return
	shown_second = second
	tock = not tock
	clock.stream = TOCK if tock else TICK
	clock.play()
