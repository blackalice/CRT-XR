extends SceneTree
## Streaming hardware-core sessions: the native worker runs frames back to back
## while room updates only exchange input, audio and pictures. Run with
## CRT_XR_TEST_FRAME_DELAY_MS=130 so each fixture frame stalls like a shader compile.
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")

func wait_until(condition: Callable, limit_ms := 5000) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < limit_ms:
		if condition.call(): return true # evaluated once per poll: it may consume
		await create_timer(0.005).timeout
	return false

func run() -> void:
	var fixture := ProjectSettings.globalize_path("res://build/emulation-linux/libcrt_xr_mock_core.so")
	var rom := ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")
	var core = ClassDB.instantiate("RetroCore")
	check(core.load_core(fixture) and core.load_game(rom, ProjectSettings.globalize_path("user://")), "fixture loads")
	check(core.start_stream(4, true) and core.stream_running(), "stream starts")
	var start := Time.get_ticks_msec()
	core.stream_input(1, 0, 0, 0, 0, 0, 0)
	core.stream_audio(null, 0)
	core.stream_frame()
	var info: Dictionary = core.stream_info()
	check(Time.get_ticks_msec() - start < 30, "input, audio, picture and info calls never wait for a stalled frame")
	check(await wait_until(func(): return core.stream_info().frames >= 3), "frames keep running back to back without room requests")
	var picture := [] # lambdas capture locals by value; the array is shared
	check(await wait_until(func():
		picture.append(core.stream_frame())
		return not picture.back().is_empty()), "a produced picture is collected")
	var again: PackedByteArray = core.stream_frame()
	check(picture.back().size() == 2 * 2 * 4 and again.is_empty(), "a picture is handed over once (%d, then %d bytes)" % [picture.back().size(), again.size()])
	# Display-locked: once granted by room updates, exactly the granted frames run.
	var before: int = core.stream_info().frames
	core.stream_tick(2)
	check(await wait_until(func(): return core.stream_info().frames >= before + 2), "granted frames run")
	await create_timer(0.5).timeout # a frame already in flight before the grant may finish too
	var settled: int = core.stream_info().frames
	await create_timer(0.5).timeout
	check(core.stream_info().frames == settled and settled <= before + 3, "no frame runs without a grant once the room paces the stream")
	start = Time.get_ticks_msec()
	core.stop_stream()
	check(Time.get_ticks_msec() - start < 30, "a stop request returns at once")
	check(await wait_until(func(): return not core.stream_running()), "the stream ends after its frame in flight")
	# A real generator: the worker pushes audio itself and paces on its fill level.
	var generator := AudioStreamGenerator.new()
	generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	generator.mix_rate = 32000.0
	generator.buffer_length = 0.10
	var player := AudioStreamPlayer.new()
	player.stream = generator
	root.add_child(player)
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var capacity := playback.get_frames_available()
	check(core.start_stream(4, true), "the stream restarts")
	core.stream_audio(playback, capacity)
	check(await wait_until(func(): return capacity - playback.get_frames_available() > 0), "the worker pushes audio straight into the generator")
	start = Time.get_ticks_msec()
	core.stream_audio(playback, capacity)
	check(Time.get_ticks_msec() - start < 30, "handing over the playback never waits for a stalled frame")
	core.stream_audio(null, 0)
	player.queue_free()
	var state: PackedByteArray = core.save_state()
	check(not state.is_empty() and not core.stream_running(), "a save stops the stream and joins its frame")
	check(core.load_state(state), "a restore works after a stream")
	core.close()
	core = null

	var session = preload("res://scripts/emulation/emulation_session.gd").new()
	root.add_child(session)
	session.set_process(false)
	session.streaming_enabled = true
	session.core = ClassDB.instantiate("RetroCore")
	check(session.core.load_core(fixture) and session.core.load_game(rom, ProjectSettings.globalize_path("user://")), "session fixture loads")
	session.loaded = true
	session.system_id = "gamecube"
	session.gamepad.menu_active = true # Neutral input; no experimental registry needed.
	session.skip_delta = false
	start = Time.get_ticks_msec()
	session._process(0.016)
	check(session.async_pending and session.core.stream_running(), "the session starts a stream")
	var worst := 0
	for i in range(40):
		start = Time.get_ticks_msec()
		session._process(0.016)
		worst = maxi(worst, Time.get_ticks_msec() - start)
		await create_timer(0.016).timeout
	check(worst < 30, "room updates never wait for stalled frames (worst %d ms)" % worst)
	check(session.texture != null, "streamed pictures reach the TV texture")
	session.sram_timer = 10.0
	start = Time.get_ticks_msec()
	session._process(0.016)
	check(Time.get_ticks_msec() - start < 30 and session.stream_sram_pending, "the SRAM read stops the stream without waiting")
	check(await wait_until(func():
		session._process(0.016)
		return not session.stream_sram_pending and session.core.stream_running()), "SRAM is read between frames and the stream resumes")
	session.set_stream_reserve(8)
	check(session.stream_reserve == 8 and session.core.stream_info().reserve_frames == 8, "a raised audio reserve reaches the running stream")
	session.stream_calm = session.STREAM_RESERVE_CALM
	session._process(0.016)
	check(session.stream_reserve == 7 and session.core.stream_info().reserve_frames == 7, "a calm spell lowers the reserve one frame at a time")
	session.set_stream_reserve(99)
	session.set_stream_reserve(0)
	check(session.stream_reserve == session.STREAM_RESERVE_MIN, "the reserve stays within its limits")
	start = Time.get_ticks_msec()
	session.set_paused(true)
	check(Time.get_ticks_msec() - start < 30, "pause does not join a stalled frame")
	check(await wait_until(func(): return not session.core.stream_running()), "a paused session stops emulating")
	session.set_paused(false)
	session._process(0.016)
	session._process(0.016)
	check(session.core.stream_running(), "resume restarts the stream")
	session.drain_async()
	check(not session.async_pending and not session.core.stream_running(), "an explicit drain joins the stream")
	session.stop()
	session.queue_free()
	await process_frame
	print("STREAM COMPLETE failures=", failures)
	quit(1 if failures else 0)
