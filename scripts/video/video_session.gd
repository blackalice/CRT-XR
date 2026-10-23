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
const INTERLACE_MODES := ["Field motion", "Blend"]
const VideoLibrary = preload("res://scripts/video/video_library.gd")
const SubtitleLayer = preload("res://scripts/video/subtitle_layer.gd")
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
## Interlaced video: 0 shows each field in turn (TV motion), 1 blends them.
var interlace := 0
## Embedded subtitle tracks first, then .srt files beside the video; -1 is off.
var subtitle_options: Array = []
var subtitle_choice := -1
var file_cues: Array = []
var subtitle_layer: SubViewport
## Green VCR mode text on the picture: PLAY and seeks show briefly, PAUSE and
## STOP stay. Off when the player has turned it off.
var osd_enabled := true
var osd_steady := ""
var osd_flash := ""
var osd_time := 0.0
const OSD_PLAY := "PLAY ►"
const OSD_FLASH_SECONDS := 3.0
const OSD_SEEK_SECONDS := 1.5
var status := ""
var texture: ImageTexture
## What the TV shows: the video's texture, or the subtitle layer drawn over it.
var output: Texture2D
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
	subtitle_layer = SubtitleLayer.new()
	subtitle_layer.name = "Subtitles"
	add_child(subtitle_layer)

func report(message: String) -> void:
	status = message
	status_changed.emit(message)

func open(file: String) -> bool:
	stop()
	if not available():
		report("Video playback is unavailable: " + unavailable_reason())
		return false
	decoder = ClassDB.instantiate("VideoDecoder")
	decoder.set_interlace(interlace)
	info = decoder.open(ProjectSettings.globalize_path(file), lines, style, hardware)
	if info.is_empty():
		report("Could not play %s: %s" % [file.get_file(), decoder.last_error()])
		decoder = null
		return false
	path = file
	subtitle_options = []
	for index in range(info.get("subtitle_tracks", []).size()): subtitle_options.append({"track": index})
	for subtitle_file in VideoLibrary.subtitle_files(ProjectSettings.globalize_path(file)): subtitle_options.append({"file": subtitle_file})
	subtitle_choice = -1
	file_cues = []
	subtitle_layer.show_cues([])
	clock = 0.0
	paused = false
	ended = false
	loaded = true
	restart_audio()
	osd_steady = ""
	flash_osd(OSD_PLAY, OSD_FLASH_SECONDS)
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
	output = null
	subtitle_choice = -1
	osd_steady = ""; osd_flash = ""; osd_time = 0.0
	subtitle_layer.show_osd("")
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
	if loaded and value != paused:
		osd_steady = "PAUSE" if value else ""
		if value: osd_time = 0.0
		else: flash_osd(OSD_PLAY, OSD_FLASH_SECONDS)
	paused = value
	player.stream_paused = paused or priming > 0.0
	if loaded: report(("Paused / " if paused else "Playing / ") + path.get_file())

func seek_by(seconds: float) -> void:
	if loaded: flash_osd("FF ►►" if seconds > 0.0 else "REW ◄◄", OSD_SEEK_SECONDS)
	seek_to(clock + seconds)

func flash_osd(message: String, seconds: float) -> void:
	osd_flash = message
	osd_time = seconds
	update_osd()

## What the VCR shows now: a recent flash over the steady PAUSE or STOP.
func osd_text() -> String:
	if not osd_enabled or not loaded: return ""
	return osd_flash if osd_time > 0.0 else osd_steady

func update_osd() -> void:
	if not subtitle_layer.show_osd(osd_text()): return
	refresh_output()

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

## "ENG · English · SRT" for embedded tracks, "File · Film.en.srt" for files.
func subtitle_names() -> PackedStringArray:
	var names := PackedStringArray()
	for option in subtitle_options:
		if option.has("file"):
			names.append("File · " + str(option.file).get_file())
			continue
		var track: Dictionary = info.subtitle_tracks[option.track]
		var parts := PackedStringArray()
		if not str(track.language).is_empty() and track.language != "und": parts.append(str(track.language).to_upper())
		if not str(track.title).is_empty(): parts.append(track.title)
		parts.append(("picture" if track.bitmap else str(track.codec).to_upper()) + (" · forced" if track.forced else ""))
		names.append(" · ".join(parts))
	return names

## -1 turns subtitles off; otherwise an index into subtitle_options.
func select_subtitles(index: int) -> void:
	if not loaded or index >= subtitle_options.size(): return
	subtitle_choice = index
	file_cues = []
	var option: Dictionary = subtitle_options[index] if index >= 0 else {}
	if option.has("file"):
		decoder.set_subtitle_track(-1, clock)
		var source := FileAccess.get_file_as_string(option.file)
		file_cues = VideoLibrary.parse_srt(source)
	else:
		decoder.set_subtitle_track(int(option.get("track", -1)), clock)
	subtitle_layer.show_cues([])
	refresh_output()

func set_interlace(mode: int) -> void:
	interlace = clampi(mode, 0, INTERLACE_MODES.size() - 1)
	if decoder != null: decoder.set_interlace(interlace)

func cues_at(time: float) -> Array:
	if subtitle_choice < 0: return []
	if not subtitle_options[subtitle_choice].has("file"): return decoder.subtitles_at(time)
	return file_cues.filter(func(cue): return cue.start <= time and time < cue.end)

## True while subtitles or the VCR text are drawn over the picture.
func layered() -> bool:
	return subtitle_choice >= 0 or not subtitle_layer.osd.text.is_empty()

## Puts the subtitle layer between the video and the TV while it has something to show.
func refresh_output() -> void:
	if texture == null: return
	var wanted: Texture2D = texture
	if layered():
		if subtitle_layer.size != Vector2i(texture.get_width(), texture.get_height()) or subtitle_layer.picture.texture != texture:
			subtitle_layer.setup(texture, texture.get_width(), texture.get_height())
		wanted = subtitle_layer.get_texture()
	if wanted != output:
		output = wanted
		content_changed.emit(output)
	if last_frame != null: frame_presented.emit(last_frame)

func update_subtitles() -> void:
	if subtitle_choice >= 0 and subtitle_layer.show_cues(cues_at(clock)) and last_frame != null:
		# The CRT redraws on new frames; a line appearing on a paused picture needs one.
		frame_presented.emit(last_frame)

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
	if osd_time > 0.0:
		osd_time = maxf(0.0, osd_time - delta)
		if osd_time == 0.0: update_osd()
	if is_instance_valid(audio_source):
		player.bus = audio_source.bus
		player.volume_db = audio_source.volume_db
	if paused:
		if preview_pending and decoder.update(clock + 1.0 / maxf(1.0, float(info.get("fps", 25.0)))):
			preview_pending = false
			present()
		update_subtitles()
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
	var presented: bool = decoder.update(clock)
	if presented: present()
	update_subtitles()
	if not presented and decoder.finished():
		# Hold the last frame on screen, like a tape reaching its end.
		ended = true
		paused = true
		osd_steady = "STOP"; osd_time = 0.0
		update_osd()
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
	else:
		texture.update(last_frame)
	if (output != texture and not layered()) or (layered() and subtitle_layer.picture.texture != texture):
		refresh_output()
		return
	frame_presented.emit(last_frame)

func _exit_tree() -> void:
	stop()
