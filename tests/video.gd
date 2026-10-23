extends SceneTree
## Video session against the clips from tests/make_video_fixtures.py.
## Needs FFmpeg: the system copy, or CRT_XR_FFMPEG_DIR for a development copy.
var failures := 0
const FIXTURES := "res://build/video-fixtures/"

func _initialize(): call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

## Real time when the tree drives the session (windowed, real audio); fixed
## steps when headless, where its automatic processing is switched off.
func play_for(session: Node, seconds: float) -> void:
	if session.is_processing():
		await create_timer(seconds).timeout
		return
	var step := 1.0 / 60.0
	for i in range(int(seconds / step)):
		session._process(step)
		await process_frame

## Lets the decoder thread deliver its first frame before the clock runs: a
## GPU decoder can take a moment to start, more so with other suites running.
func wait_for_first_frame(session: Node) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while session.texture == null and Time.get_ticks_msec() < deadline:
		if not session.is_processing(): session._process(0.0)
		await process_frame

## Real audio output, muted: the picture must follow the sound that is heard.
func sync_checks() -> void:
	AudioServer.set_bus_mute(0, true)
	var session: Node = preload("res://scripts/video/video_session.gd").new()
	root.add_child(session)
	check(session.open(FIXTURES + "h264_aac_25.mp4") and session.audio_output, "Sound goes to the audio output")
	await create_timer(1.5).timeout
	check(session.playback != null, "The audio generator starts once sound is decoded")
	var heard: float = session.heard_position()
	check(not session.waiting_for_audio and absf(session.clock - heard) < 0.03,
		"The clock follows the heard sound (clock %.3f, heard %.3f)" % [session.clock, heard])
	check(absf(session.decoder.frame_time() - session.clock) < 0.06, "The shown frame matches the sound (frame %.3f)" % session.decoder.frame_time())
	check(session.playback.get_skips() == 0 and session.decoder.dropped() < 5, "%d audio underruns; %d late frames skipped" % [session.playback.get_skips(), session.decoder.dropped()])
	session.set_paused(true)
	var held: float = session.clock
	await create_timer(0.4).timeout
	check(is_equal_approx(session.clock, held), "Pausing stops the clock")
	session.set_paused(false)
	session.seek_by(-1.0)
	var target: float = session.clock
	await create_timer(0.6).timeout
	check(absf(session.clock - (target + 0.6)) < 0.12 and absf(session.clock - session.heard_position()) < 0.03,
		"After seeking, sound and picture restart together (%.3f from %.3f)" % [session.clock, target])
	session.queue_free()
	AudioServer.set_bus_mute(0, false)

## Needs FFmpeg (the system copy, or CRT_XR_FFMPEG_DIR) and the clips from
## tests/make_video_fixtures.py; without either the suite skips and says why.
func skip_reason() -> String:
	var Session := preload("res://scripts/video/video_session.gd")
	if not Session.available(): return "no FFmpeg: " + Session.unavailable_reason()
	if not FileAccess.file_exists(ProjectSettings.globalize_path("res://build/video-fixtures/library/long_43_25.mp4")):
		return "no clips: run python tests/make_video_fixtures.py <ffmpeg>"
	return ""

func run() -> void:
	var reason := skip_reason()
	if not reason.is_empty():
		print("CHECKS SKIPPED: " + reason)
		quit(0)
		return
	var Session := preload("res://scripts/video/video_session.gd")
	check(Session.available(), "Video decoder is available (" + Session.unavailable_reason() + ")")
	var session: Node = Session.new()
	root.add_child(session)
	session.set_process(DisplayServer.get_name() != "headless")
	# The VCR text is checked on its own below; it would otherwise layer the picture.
	session.osd_enabled = false
	var events: Array = []
	session.active_changed.connect(func(active): events.append(active))
	var textures: Array = []
	session.content_changed.connect(func(texture): textures.append(texture))
	check(not session.open(FIXTURES + "missing.mp4") and session.status.begins_with("Could not play missing.mp4"), "A missing file is reported by name")
	check(session.open(FIXTURES + "h264_aac_25.mp4") and events == [true], "Opening a video activates it")
	check(is_equal_approx(session.field_rate(), 50.0), "25 fps video uses the PAL field rate")
	await wait_for_first_frame(session)
	await play_for(session, 0.5)
	check(textures.size() == 1 and textures[0].get_width() == 640 and textures[0].get_height() == 240, "Frames arrive as one reused 640x240 texture (one field, CRT scale)")
	# With real audio output the picture waits for the sound to start, so check
	# the shown frame is the latest one due rather than a fixed time.
	var shown: float = session.decoder.frame_time()
	check(session.clock > 0.1 and shown <= session.clock and session.clock - shown < 0.08, "Shown frames follow the clock (frame %.3f, clock %.3f)" % [shown, session.clock])
	check(session.cycle_style() == "14:9" and session.decoder.get_style() == 1, "Style cycling reaches the decoder")
	session.seek_by(10.0)
	check(session.clock <= 3.5, "Seeking clamps inside the file")
	await play_for(session, 1.5)
	check(session.ended and session.paused and session.status.begins_with("Finished"), "The last frame holds when the video ends")
	session.seek_by(-2.0)
	check(not session.ended and not session.paused, "Seeking back after the end resumes")
	check(session.open(FIXTURES + "hevc_ac3_23976.mkv") and is_equal_approx(session.field_rate(), 60.0), "Film-rate video uses the NTSC field rate")
	await play_for(session, 0.3)
	check(session.decoding() in ["VA-API", "D3D11VA", "software"], "Hardware decoding is on by default (%s)" % session.decoding())
	session.hardware = false
	check(session.open(FIXTURES + "hevc_ac3_23976.mkv"), "Reopens with hardware decoding off")
	await play_for(session, 0.3)
	check(session.decoding() == "software", "Hardware decoding can be switched off")
	session.hardware = true
	check(session.open(FIXTURES + "two_tracks_25.mkv") and session.track_names() == PackedStringArray(["ENG · Main · AAC mono", "FRA · Commentary · AAC mono"]) and int(session.info.audio_track) == 0,
		"Audio tracks are named by language, title and format: %s" % [session.track_names()])
	session.select_audio_track(1)
	check(int(session.info.audio_track) == 1 and session.decoder.has_audio(), "Selecting the second audio track")
	# Subtitles: drawn into the picture through the subtitle layer.
	var outputs: Array = []
	session.content_changed.connect(func(texture): outputs.append(texture))
	check(session.open(FIXTURES + "subtitles_srt.mkv") and session.subtitle_names() == PackedStringArray(["ENG · English · SUBRIP"]) and session.subtitle_choice == -1,
		"Subtitle tracks are named and start off: %s" % [session.subtitle_names()])
	session.select_subtitles(0)
	session.seek_to(1.0)
	await play_for(session, 0.3)
	check(session.subtitle_layer.text.text == "Hello CRT" and session.output == session.subtitle_layer.get_texture() and outputs.back() == session.subtitle_layer.get_texture(),
		"The subtitle is drawn over the picture the TV shows (%s)" % session.subtitle_layer.text.text)
	session.seek_to(2.2)
	await play_for(session, 0.4)
	check(session.subtitle_layer.text.text == "Second line\nbreaks here", "Later cues follow the clock")
	session.select_subtitles(-1)
	await play_for(session, 0.1)
	check(session.output == session.texture and session.subtitle_layer.text.text == "", "Turning subtitles off returns the plain picture")
	check(session.open(FIXTURES + "library/Episode 2.mkv") and session.subtitle_names() == PackedStringArray(["File · Episode 2.en.srt"]), "A subtitle file beside the video is offered")
	session.select_subtitles(0)
	session.seek_to(0.9)
	await play_for(session, 0.2)
	check(session.subtitle_layer.text.text == "Hello CRT", "Subtitles from a file show at their time")
	session.interlace = 1
	check(session.open(FIXTURES + "interlaced_576i_25.mkv"), "An interlaced video opens")
	await play_for(session, 0.3)
	check(session.decoder.interlaced(), "Interlaced video is recognised")
	session.interlace = 0
	check(session.open(FIXTURES + "silent_169_30.mp4") and not session.decoder.has_audio() and session.playback == null, "A silent file plays on the frame clock")
	var before: float = session.clock
	await play_for(session, 0.2)
	check(session.clock > before, "The frame clock runs without sound")
	# The VCR's green mode text, drawn into the picture like subtitles.
	session.osd_enabled = true
	var mechanism: Array = []
	session.mechanism.connect(func(event): mechanism.append(event))
	check(session.open(FIXTURES + "h264_aac_25.mp4") and session.osd_text() == "PLAY ►", "Opening a video shows PLAY")
	await play_for(session, 0.3)
	check(session.subtitle_layer.osd.text == "PLAY ►" and session.output == session.subtitle_layer.get_texture(), "The VCR text is drawn over the picture the TV shows")
	session.set_paused(true)
	check(session.osd_text() == "PAUSE", "Pausing shows PAUSE")
	session.seek_by(1.0)
	check(session.osd_text() == "FF ►►", "Seeking forward shows FF")
	session.seek_by(-1.0)
	check(session.osd_text() == "REW ◄◄", "Seeking back shows REW")
	session._process(session.OSD_SEEK_SECONDS + 0.1)
	check(session.osd_text() == "PAUSE", "After a seek, a paused tape shows PAUSE again")
	session.set_paused(false)
	check(session.osd_text() == "PLAY ►", "Resuming shows PLAY")
	session._process(session.OSD_FLASH_SECONDS + 0.1)
	check(session.osd_text() == "" and session.subtitle_layer.osd.text == "" and session.output == session.texture, "The text clears and the plain picture returns")
	session.osd_enabled = false
	session.set_paused(true)
	check(session.osd_text() == "" and session.output == session.texture, "With the VCR text off, nothing is drawn")
	check(mechanism == ["play", "pause", "search", "search", "resume", "pause"], "The VCR mechanism follows play, pause, search and resume: %s" % [mechanism])
	var sounds: Node = preload("res://scripts/video/vcr_sounds.gd").new()
	root.add_child(sounds)
	sounds.mechanism("search")
	check(sounds.whir.playing and sounds.whir.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Searching starts the looping motor whir")
	sounds.mechanism("search")
	sounds._process(sounds.SEARCH_HOLD - 0.1)
	check(sounds.search_time > 0.0, "Repeated seeks keep the whir running")
	sounds._process(0.2)
	check(sounds.search_time <= 0.0 and sounds.clunk.stream == sounds.SOUNDS.resume, "The whir winds down a moment after the last seek, back into play")
	sounds.enabled = false
	sounds.stop_all()
	sounds.mechanism("play")
	check(not sounds.clunk.playing and not sounds.whir.playing, "VCR sounds can be turned off")
	sounds.free()
	# The VHS tape look plays the picture through the tape shader; off is direct.
	session.set_tape(2)
	check(session.output == session.subtitle_layer.get_texture() and session.subtitle_layer.picture.material == session.subtitle_layer.tape
		and is_equal_approx(float(session.subtitle_layer.tape.get_shader_parameter("wear")), 1.0), "Worn VHS plays the picture through a worn tape")
	session.seek_by(-1.0)
	session._process(0.05)
	check(float(session.subtitle_layer.tape.get_shader_parameter("search")) > 0.0 and float(session.subtitle_layer.tape.get_shader_parameter("search_direction")) < 0.0
		and float(session.subtitle_layer.tape.get_shader_parameter("still")) == 1.0, "Rewinding a paused tape rolls noise bars upward over a still frame")
	session._process(session.OSD_SEEK_SECONDS + 0.1)
	check(float(session.subtitle_layer.tape.get_shader_parameter("search")) == 0.0, "The noise bars stop after the search")
	session.set_tape(0)
	check(session.output == session.texture and session.subtitle_layer.picture.material == null, "With the tape look off, the picture is direct")
	mechanism.clear()
	session.stop()
	check(events.back() == false and session.decoder == null and mechanism == ["stop"], "Stopping deactivates the video, with the stop clunk")
	session.free()

	# In the real scene: the TV shows the video instead of the test signal.
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for i in range(4): await process_frame
	check(app.video.open(FIXTURES + "classic_43_30.mp4"), "The scene opens a video")
	await play_for(app.video, 0.3)
	check(app.world.picture.source_texture == app.video.output and app.video.output != null and not app.pattern.visible, "The CRT picture shows the video, not the test signal")
	check(is_equal_approx(app.world.picture.source_rate, 60.0) and is_equal_approx(app.world.picture.source_aspect, 4.0 / 3.0), "The picture gets the video's field rate and 4:3 frame")
	var vcr: ShaderMaterial = app.world.video_recorder.material_override
	app.video.seek_to(3.0)
	await play_for(app.video, 0.2)
	app._process(0.0)
	app.world._update_prop_clocks(0.0)
	check(int(vcr.get_shader_parameter("hours")) == 0 and int(vcr.get_shader_parameter("minutes")) == int(app.video.clock) and not vcr.get_shader_parameter("twelve_hour"),
		"The VCR shows the tape counter while a video plays (00:%02d)" % int(vcr.get_shader_parameter("minutes")))
	app.world._show_tape_counter(3725)
	check(int(vcr.get_shader_parameter("hours")) == 1 and int(vcr.get_shader_parameter("minutes")) == 2, "Past an hour the counter shows hours and minutes")
	check(app.video.player.bus == app.emulator.player.bus and is_equal_approx(app.video.player.volume_db, app.emulator.player.volume_db), "Video sound uses the TV bus and game volume")
	# Going straight from one video to another must keep the picture on the TV.
	check(app.video.open(FIXTURES + "h264_aac_25.mp4"), "A second video opens over the first")
	await play_for(app.video, 0.3)
	check(app.world.picture.source_texture == app.video.output and app.video.texture != null and not app.pattern.visible,
		"The TV shows the second video, not the test signal")
	app.video.stop()
	check(app.pattern.visible and app.world.picture.source_texture == app.signal_view.get_texture(), "Stopping returns the TV to the test signal")
	app._process(0.0)
	app.world._update_prop_clocks(1.0)
	var now := Time.get_time_dict_from_system()
	var vcr_after: ShaderMaterial = app.world.video_recorder.material_override
	check(int(vcr_after.get_shader_parameter("hours")) == int(now.hour) and int(vcr_after.get_shader_parameter("minutes")) == int(now.minute), "After the video the VCR shows the time again")
	app.free()
	if DisplayServer.get_name() != "headless": await sync_checks()
	print("VIDEO CHECKS COMPLETE: %d failures" % failures)
	quit(1 if failures else 0)
