extends AudioStreamPlayer
## One quiet, sample-looped stereo bed for the shared menu, independent of albums.
const SOURCE := preload("res://assets/audio/menu-bgm.wav")
const DEFAULT_LEVEL := 0.10
const BOOT_TAIL_START := 4.0
const FADE_SECONDS := 1.5
var enabled := true
var level := DEFAULT_LEVEL
var gain := 0.0

func _ready() -> void:
	var looped: AudioStreamWAV = SOURCE.duplicate()
	looped.loop_begin = 0
	looped.loop_end = roundi(looped.get_length() * looped.mix_rate)
	looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream = looped
	volume_db = -80.0

func apply() -> void:
	level = clampf(level, 0.0, 1.0) if is_finite(level) else DEFAULT_LEVEL
	if not enabled or level <= 0.0: silence()
	else: volume_db = linear_to_db(maxf(0.0001, level * gain))

func silence() -> void:
	stop()
	gain = 0.0
	volume_db = -80.0

func update(delta: float, menu_open: bool, own_music: bool, boot: AudioStreamPlayer, waiting := false) -> void:
	if waiting or not menu_open or not enabled or level <= 0.0 or own_music:
		silence()
		return
	if is_instance_valid(boot) and boot.playing and boot.get_playback_position() < BOOT_TAIL_START:
		return
	if not playing: play()
	gain = move_toward(gain, 1.0, maxf(delta, 0.0) / FADE_SECONDS)
	apply()
