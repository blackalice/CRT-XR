extends Node
## The VCR prop's mechanism: clunks for play, pause and stop, and the motor's
## whir while fast-forwarding or rewinding.
## The sounds are synthesised by scripts/make-vcr-sounds.py.
const SOUNDS := {
	"play": preload("res://assets/audio/vcr/vcr-play.wav"),
	"resume": preload("res://assets/audio/vcr/vcr-resume.wav"),
	"pause": preload("res://assets/audio/vcr/vcr-pause.wav"),
	"stop": preload("res://assets/audio/vcr/vcr-stop.wav"),
}
const SEARCH := preload("res://assets/audio/vcr/vcr-search.wav")
## A held scrub repeats faster than this, so the whir runs on unbroken.
const SEARCH_HOLD := 0.6
## Quieter than the programme: it is a box on the shelf, not the TV's speaker.
const LEVEL_DB := -8.0
var enabled := true
var volume_db := 0.0
var clunk := AudioStreamPlayer.new()
var whir := AudioStreamPlayer.new()
var search_time := 0.0
var spin: Tween

func _init() -> void:
	name = "VCRSounds"
	for player in [clunk, whir]:
		player.max_polyphony = 2
		add_child(player)
	var loop: AudioStreamWAV = SEARCH.duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	whir.stream = loop
	set_process(false)

## Plays one of the mechanism sounds: play, resume, pause or stop.
func mechanism(event: String) -> void:
	if event == "search":
		search()
		return
	if not enabled or not SOUNDS.has(event): return
	if event in ["stop", "pause"] and whir.playing: end_search(false)
	clunk.stream = SOUNDS[event]
	clunk.volume_db = volume_db + LEVEL_DB
	clunk.play()

## Starts or prolongs the FF/REW whir; it winds down a moment after the last seek.
func search() -> void:
	if not enabled: return
	search_time = SEARCH_HOLD
	set_process(true)
	if whir.playing and (spin == null or not spin.is_running()): return
	if spin != null: spin.kill()
	whir.volume_db = volume_db + LEVEL_DB - 10.0
	if not whir.playing:
		whir.pitch_scale = 0.55
		whir.play()
	spin = create_tween().set_parallel()
	spin.tween_property(whir, "pitch_scale", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	spin.tween_property(whir, "volume_db", volume_db + LEVEL_DB - 3.0, 0.2)

func end_search(then_resume := true) -> void:
	search_time = 0.0
	set_process(false)
	if spin != null: spin.kill()
	spin = create_tween().set_parallel()
	spin.tween_property(whir, "pitch_scale", 0.5, 0.18).set_ease(Tween.EASE_IN)
	spin.tween_property(whir, "volume_db", -60.0, 0.18)
	spin.chain().tween_callback(whir.stop)
	if then_resume: mechanism("resume")

func stop_all() -> void:
	search_time = 0.0
	set_process(false)
	if spin != null: spin.kill()
	whir.stop()
	clunk.stop()

func _process(delta: float) -> void:
	search_time -= delta
	if search_time <= 0.0: end_search()
