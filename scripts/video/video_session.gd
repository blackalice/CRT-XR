extends Node
## Plays one video file into the CRT picture and the TV's sound, through the
## same paths as games. The native VideoDecoder decodes, scales and resamples
## ahead on its own thread; this node feeds the sound to the TV and shows the
## frames that are due. The sound is the clock: pictures follow what is heard.
signal content_changed(texture: Texture2D)
signal frame_presented(image: Image)
signal status_changed(message: String)
signal active_changed(active: bool)
signal finished

const STYLES := ["Letterbox", "14:9", "Fill 4:3", "Stretch"]
const SAMPLE_RATE := 48000.0
## Larger corrections jump; smaller ones are eased in so motion stays smooth.
const RESYNC_SECONDS := 0.15
var decoder: RefCounted
var loaded := false
var paused := false
var ended := false
var path := ""
var info: Dictionary = {}
var clock := 0.0
var lines := 240
## GPU decoding when available; the decoder falls back to software by itself.
var hardware := true
var style := 0
var status := ""
var texture: ImageTexture
var last_frame: Image
var player := AudioStreamPlayer.new()
var playback: AudioStreamGeneratorPlayback
var capacity := 0 # generator frames when empty
var waiting_for_audio := false
## True when this video's sound goes to a real output (false headless or silent).
var audio_output := false
## A seek made while paused still shows its frame, so scrubbing moves the picture.
var preview_pending := false
## The player stays paused until half its buffer is filled, so it never starts
## on an empty buffer; a short or silent stream starts after PRIME_SECONDS.
var priming := 0.0
const PRIME_SECONDS := 0.5
## The game's player: video sound follows its TV bus and game volume.
var audio_source: AudioStreamPlayer

static func available() -> bool:
	return ClassDB.class_exists("VideoDecoder") and bool(ClassDB.class_call_static("VideoDecoder", "available"))

static func unavailable_reason() -> String:
	if not ClassDB.class_exists("VideoDecoder"): return "this build has no video decoder"
	return str(ClassDB.class_call_static("VideoDecoder", "library_error"))

func _ready() -> void:
	player.name = "VideoSound"
	var generator := AudioStreamGenerator.new()
	generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	generator.mix_rate = SAMPLE_RATE
	# Video can afford more buffering than games; the clock allows for it.
	generator.buffer_length = 0.25
	player.stream = generator
	add_child(player)

func report(message: String) -> void:
	status = message
	status_changed.emit(message)

func open(file: String) -> bool:
	stop()
	if not available():
		report("Video playback is unavailable: " + unavailable_reason())
		return false
	decoder = ClassDB.instantiate("VideoDecoder")
	info = decoder.open(ProjectSettings.globalize_path(file), lines, style, hardware)
	if info.is_empty():
		report("Could not play %s: %s" % [file.get_file(), decoder.last_error()])
		decoder = null
		return false
	path = file
	clock = 0.0
	paused = false
	ended = false
	loaded = true
	restart_audio()
	active_changed.emit(true)
	report("Playing / %s (%s, %.3f fps)" % [file.get_file(), info.codec, info.fps])
	return true

func stop() -> void:
	player.stop()
	playback = null
	if decoder != null: decoder.close()
	decoder = null
	# Stopping hands the TV back to the test signal, so the next video must
	# announce a fresh texture even when its frames are the same size.
	texture = null
	last_frame = null
	if loaded:
		loaded = false
		active_changed.emit(false)

## "VA-API", "D3D11VA" or "software", for the latest frame.
func decoding() -> String:
	return str(decoder.decoding()) if decoder != null else ""

## The composite standard follows the source: 25 and 50 fps are PAL; film,
## 30 and 60 fps are NTSC. The picture's auto mode reads a field rate.
func field_rate() -> float:
	var fps := float(info.get("fps", 30.0))
	return 50.0 if absf(fps - 25.0) < 0.5 or absf(fps - 50.0) < 0.5 else 60.0

func set_paused(value: bool) -> void:
	paused = value
	player.stream_paused = paused or priming > 0.0
	if loaded: report(("Paused / " if paused else "Playing / ") + path.get_file())

func seek_by(seconds: float) -> void:
	seek_to(clock + seconds)

func seek_to(seconds: float) -> void:
	if not loaded: return
	clock = clampf(seconds, 0.0, maxf(0.0, float(info.duration) - 0.5))
	decoder.seek(clock)
	preview_pending = true
	restart_audio()
	if ended:
		ended = false
		set_paused(false)

func cycle_style() -> String:
	style = (style + 1) % STYLES.size()
	if decoder != null: decoder.set_style(style)
	return STYLES[style]

## "ENG · Main · AAC 5.1" for each audio track, in file order.
func track_names() -> PackedStringArray:
	var names := PackedStringArray()
	var layouts := {1: "mono", 2: "stereo", 6: "5.1", 8: "7.1"}
	for track in info.get("audio_tracks", []):
		var parts := PackedStringArray()
		if not str(track.language).is_empty() and track.language != "und": parts.append(str(track.language).to_upper())
		if not str(track.title).is_empty(): parts.append(track.title)
		parts.append("%s %s" % [str(track.codec).to_upper(), layouts.get(int(track.channels), "%d ch" % track.channels)])
		names.append(" · ".join(parts))
	return names

## Moves to the next audio track; returns its name, or "" with only one track.
func cycle_audio_track() -> String:
	var names := track_names()
	if names.size() < 2: return ""
	var next := (int(info.get("audio_track", 0)) + 1) % names.size()
	select_audio_track(next)
	return names[next]

func select_audio_track(index: int) -> void:
	if not loaded or index < 0 or index >= info.get("audio_tracks", []).size(): return
	decoder.set_audio_track(index, clock)
	info.audio_track = index
	restart_audio()

func restart_audio() -> void:
	# Godot forbids clearing an active generator; a fresh playback starts empty.
	# The headless Dummy driver has no output, so its sound is discarded.
	player.stop()
	playback = null
	priming = 0.0
	audio_output = decoder != null and decoder.has_audio() and DisplayServer.get_name() != "headless"
	waiting_for_audio = audio_output

## The player starts only once decoded sound exists (a GPU decoder can take a
## few frames to begin), so the mixer never runs on an empty buffer.
func start_audio() -> void:
	player.play()
	player.stream_paused = true
	priming = PRIME_SECONDS
	playback = player.get_stream_playback()
	capacity = playback.get_frames_available()

func queued_seconds() -> float:
	return float(capacity - playback.get_frames_available()) / SAMPLE_RATE if playback != null else 0.0

## Position of the sound reaching the speakers, or NAN while none is playing.
func heard_position() -> float:
	var pushed_until: float = decoder.audio_time()
	var queued := queued_seconds()
	if playback == null or priming > 0.0 or pushed_until < 0.0 or queued <= 0.0: return NAN
	return pushed_until - queued - AudioServer.get_output_latency()

func _process(delta: float) -> void:
	if not loaded: return
	if is_instance_valid(audio_source):
		player.bus = audio_source.bus
		player.volume_db = audio_source.volume_db
	if paused:
		if preview_pending and decoder.update(clock + 1.0 / maxf(1.0, float(info.get("fps", 25.0)))):
			preview_pending = false
			present()
		return
	preview_pending = false
	if audio_output and playback == null and decoder.audio_time() >= 0.0: start_audio()
	# Without an output the sound is discarded; before it starts, it is kept.
	if playback != null or not audio_output: decoder.push_audio(playback)
	if priming > 0.0:
		# Capped: opening a GPU decoder can stall one frame, and that long frame
		# must not end priming before any sound has been queued.
		priming -= minf(delta, 0.05)
		if queued_seconds() * SAMPLE_RATE >= capacity * 0.5 or priming <= 0.0:
			priming = 0.0
			player.stream_paused = false
	if not audio_output:
		clock += minf(delta, 0.25)
	else:
		var heard := heard_position()
		if waiting_for_audio:
			# Hold the picture until the sound starts, then start together.
			if is_nan(heard): return
			waiting_for_audio = false
			clock = heard
		else:
			clock += minf(delta, 0.25)
			# Past the end of the sound (or in a gap) the frame clock carries on.
			if not is_nan(heard):
				var error := heard - clock
				clock = heard if absf(error) > RESYNC_SECONDS else clock + error * minf(1.0, delta * 4.0)
	if decoder.update(clock):
		present()
	elif decoder.finished():
		# Hold the last frame on screen, like a tape reaching its end.
		ended = true
		paused = true
		player.stream_paused = true
		report("Finished / " + path.get_file())
		finished.emit()

func present() -> void:
	var bytes: PackedByteArray = decoder.frame()
	var width := int(info.width)
	var height := int(info.height)
	# One Image is refilled each frame instead of allocating a new one.
	if last_frame == null or last_frame.get_width() != width or last_frame.get_height() != height:
		last_frame = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, bytes)
	else:
		last_frame.set_data(width, height, false, Image.FORMAT_RGBA8, bytes)
	if texture == null or texture.get_width() != width or texture.get_height() != height:
		texture = ImageTexture.create_from_image(last_frame)
		content_changed.emit(texture)
	else:
		texture.update(last_frame)
	frame_presented.emit(last_frame)

func _exit_tree() -> void:
	stop()
