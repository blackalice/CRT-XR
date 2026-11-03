extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var core = ClassDB.instantiate("RetroCore")
	check(core.load_core(ProjectSettings.globalize_path("res://build/emulation-linux/libcrt_xr_mock_core.so")), "fixture loads")
	check(core.load_game(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc"), ProjectSettings.globalize_path("user://")), "fixture game loads")
	var start := Time.get_ticks_msec()
	check(core.begin_frame(0, 4), "batch starts")
	check(not core.begin_frame(0), "second request cannot overwrite pending batch")
	check(core.poll_frame() == 0, "poll returns during controlled stall")
	var ticks := 0
	var result: int = 0
	while result == 0 and Time.get_ticks_msec() - start < 5000:
		await create_timer(0.005).timeout
		ticks += 1
		result = core.poll_frame()
	check(result == 1 and ticks > 10, "scene keeps updating during four 130 ms native stalls")
	var info: Dictionary = core.info()
	check(info.async_steps.size() == 4 and info.audio_frames == 12, "every step and PCM batch retained")
	check(core.poll_frame() == -2, "completion consumed once")
	check(core.begin_frame(0), "next job starts")
	var state: PackedByteArray = core.save_state()
	check(not state.is_empty() and core.poll_frame() == 1, "save joins outstanding work")
	check(core.begin_frame(0) and core.load_state(state), "restore joins outstanding work")
	check(core.poll_frame() == -2, "restore invalidates old completion")
	check(core.begin_frame(0), "start before close")
	core.close()
	check(core.poll_frame() == -2, "close drains and invalidates pending work")
	core = null
	var session = preload("res://scripts/emulation/emulation_session.gd").new()
	root.add_child(session)
	session.set_process(false)
	session.core = ClassDB.instantiate("RetroCore")
	check(session.core.load_core(ProjectSettings.globalize_path("res://build/emulation-linux/libcrt_xr_mock_core.so")), "session fixture loads")
	check(session.core.load_game(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc"), ProjectSettings.globalize_path("user://")), "session fixture game loads")
	session.loaded = true
	session.system_id = "gamecube"
	session.gamepad.menu_active = true # Neutral input; no experimental registry needed.
	session.skip_delta = false
	session._process(0.1)
	check(session.async_pending, "session submits catch-up batch")
	start = Time.get_ticks_msec()
	session._process(0.3)
	check(Time.get_ticks_msec() - start < 30 and session.accumulator > 0.3, "room callback never waits or discards stall time")
	session.vmu_pixels = PackedByteArray([255, 0])
	start = Time.get_ticks_msec()
	check(session.vmu_lcd() == PackedByteArray([255, 0]) and Time.get_ticks_msec() - start < 30, "VMU reads the last snapshot while a native job is stalled")
	session.set_paused(true)
	check(not session.async_pending and session.accumulator == 0.0, "pause joins pending work and resets the wall clock")
	session.stop()
	session.queue_free()
	await process_frame
	print("ASYNC COMPLETE failures=", failures)
	quit(1 if failures else 0)
